"""DCS World's static-weather wind model, and the inversions that set the wind a pilot will meet.

DCS does not fly the wind the Mission Editor shows. Its three settings (``atGround``, ``at2000``,
``at8000``) are levels at 0, 2,000 and 8,000 m above **sea level**, the 0 m one multiplied by
``45^0.2`` (2.141); between two levels the wind vector blends with the weight ``exp(-s^4)``, and
under 500 m above the ground it is multiplied by ``(h / 500)^p``, ``p`` depending on the altitude.
So the editor's "ground wind" is the 10 m wind only at the sea shore: 1.34 times the setting on an
airfield at 250 m, 1.87 times at 1,000 m, and about 2.1 times between 300 and 600 m above the ground.

The model was decoded from ``Weather.dll`` (``StaticAtmosphere::getBaseWind_w``) and checked in game:
five runs of 5,392 points each, every one within 0.0003 m/s. It is written up in the whitepaper
``docs/whitepapers/dcs-wind-model.en.md`` of VEAF-Mission-Creation-Tools, for DCS
:data:`MODEL_DCS_VERSION`; ``veaf-tools dcs mission-check --measure-wind`` is how a later DCS is
checked against it.

**This file is shared.** The VEAF fork of DCSServerBot copies it as is, to correct the ``atGround``
DCS Real Weather writes on the servers, and both repositories replay ``dcs_wind_vectors.json``
beside it so a copy that drifts fails. Hence a contract: standard library only, Python 3.10 or
later, no I/O and no logging — a doubtful result comes back as data (``reliable``, a weight) — and
every place, cap and METAR stays with the caller.

Conventions are DCS's: ``x`` points north, ``z`` east, an altitude is above sea level, a height above
the ground. A setting is the ``.miz``'s ``weather.wind`` table, whose ``dir`` is where the wind blows
**to** (``dir`` 90 is a wind from 270); a :class:`WindVector` converts to "from" degrees true and
knots, the way a METAR says it.
"""

from __future__ import annotations

import cmath
import math
from collections.abc import Mapping, Sequence
from dataclasses import dataclass
from typing import Any

MODEL_DCS_VERSION = "2.9.31.29434"
"""The DCS version whose ``Weather.dll`` the model was decoded from and measured against."""

KNOTS_PER_MPS = 3600.0 / 1852.0
"""Knots in one m/s."""

GROUND_REFERENCE_FACTOR = 45.0**0.2
"""What the 0 m level carries per m/s of ``atGround`` (``StaticAtmosphere::addPointGroundWind_w``)."""

LEVEL_ALTITUDES_M = (0.0, 2000.0, 8000.0)
"""Altitudes above sea level of ``atGround``, ``at2000`` and ``at8000``."""

_LEVEL_KEYS = ("atGround", "at2000", "at8000")

SURFACE_HEIGHT_M = 10.0
"""The height a METAR or an ATIS reports the wind at."""

RELIABLE_GROUND_WEIGHT = 0.5
"""Below this weight of the 0 m level at the reference point, an inversion with a given ``at2000`` is
flagged unreliable: it amplifies any gap between ``at2000`` and the wanted wind (16 times at 1,500 m)."""

MAX_VEER_DEG = 30.0
"""The largest veer between the surface and 2,000 m the inversion accepts: past it, the blend of two
vectors at an angle dips in the middle of the layer (1.3 kt at 45°, 6 kt at 90°)."""

GUST_PER_SETTING = 0.62
"""METAR gust gap at 10 m per m/s of ``groundTurbulence`` (in-game measurement of 2026-10-31,
whitepaper ``dcs-turbulence``, section 3.4; 0.55 to 0.68 depending on the 10-minute window)."""

GUST_TURBULENCE_CAP_MPS = 3.0
"""The largest turbulence a gust sets, in m/s (whitepaper ``dcs-turbulence``, section 4: 3 m/s
recommended, to be confirmed in flight by the helicopter pilots of the servers' missions)."""

_MPS_PER_KNOT = 1.0 / KNOTS_PER_MPS
_BAND_STEP_M = 10.0
_BISECTION_STEPS = 50


@dataclass(frozen=True)
class WindVector:
    """A horizontal wind, in DCS's axes.

    Attributes:
        x: Component towards the north, m/s.
        z: Component towards the east, m/s.
    """

    x: float
    z: float

    @property
    def speed(self) -> float:
        """The speed, m/s."""
        return math.hypot(self.x, self.z)

    @property
    def knots(self) -> float:
        """The speed, knots."""
        return self.speed * KNOTS_PER_MPS

    @property
    def from_deg(self) -> float:
        """Where the wind comes from, degrees true in ``[0, 360)``, the way a METAR says it."""
        return (math.degrees(math.atan2(self.z, self.x)) + 180.0) % 360.0


@dataclass(frozen=True)
class LayerWind:
    """The base wind at one height above a place.

    Attributes:
        height_agl: Height above the ground, m.
        altitude_msl: Altitude above sea level, m.
        wind: The wind DCS simulates there.
    """

    height_agl: float
    altitude_msl: float
    wind: WindVector


@dataclass(frozen=True)
class Inversion:
    """A setting computed for a wanted surface wind.

    Attributes:
        setting: The ``weather.wind`` table to write (``atGround``, ``at2000``, ``at8000``, each
            ``{speed, dir}`` with ``dir`` where the wind blows to).
        ground_weight: Weight ``1 - w`` of the 0 m level at the reference point, 1 at sea level.
        reliable: False when ``ground_weight`` is under :data:`RELIABLE_GROUND_WEIGHT`: the 2,000 m
            level dominates there and the caller decides what to do with the result.
    """

    setting: dict[str, dict[str, float]]
    ground_weight: float
    reliable: bool


@dataclass(frozen=True)
class BandCap:
    """A setting reduced so a band of heights stays under a cap.

    Attributes:
        setting: The setting, reduced or as given.
        reduced: Whether anything was reduced.
        at2000_reduced: Whether ``at2000`` (and ``at8000`` with it) had to be reduced too: the terrain
            is high enough for the 2,000 m level to hold the band above the cap on its own.
    """

    setting: dict[str, dict[str, float]]
    reduced: bool
    at2000_reduced: bool


def _vector(layer: Mapping[str, Any]) -> complex:
    """A ``{speed, dir}`` layer as ``x + i z``, ``dir`` being where the wind blows to."""
    return cmath.rect(float(layer.get("speed", 0.0)), math.radians(float(layer.get("dir", 0.0))))


def _layer(vector: complex) -> dict[str, float]:
    """``x + i z`` back to a ``{speed, dir}`` layer."""
    return {"speed": abs(vector), "dir": math.degrees(cmath.phase(vector)) % 360.0 if vector else 0.0}


def _ground_factor(altitude_msl: float, height_agl: float) -> float:
    """``IAtmosphere::getWindGroundFactor``: the reduction of the wind near the ground.

    Args:
        altitude_msl: The point's altitude above sea level, m.
        height_agl: The point's height above the ground, m.

    Returns:
        ``(h / 500)^p``, 1 from 500 m up and 0 at the ground.
    """
    if height_agl >= 500.0:
        return 1.0
    if height_agl <= 0.0:
        return 0.0
    a = min(max(altitude_msl, 0.0), 1500.0)
    p = 0.2 * (0.9957 - 0.001844 * a + 1.379e-06 * a * a - 3.592e-10 * a * a * a)
    return float((height_agl / 500.0) ** p)


def _blend_weight(altitude_msl: float, lower: float, upper: float) -> float:
    """The weight ``w = exp(-s^4)`` of the upper level, between two level altitudes."""
    s = (altitude_msl - upper) / ((upper - lower) * 0.5)
    return math.exp(-(s**4))


def base_wind(setting: Mapping[str, Any], altitude_msl: float, height_agl: float) -> WindVector:
    """The base wind DCS simulates at a point (``StaticAtmosphere::getBaseWind_w``), turbulence aside.

    Args:
        setting: The ``.miz``'s ``weather.wind`` table.
        altitude_msl: The point's altitude above sea level, m.
        height_agl: The point's height above the ground, m.

    Returns:
        The wind there.
    """
    levels = [_vector(setting.get(key) or {}) for key in _LEVEL_KEYS]
    levels[0] *= GROUND_REFERENCE_FACTOR
    if height_agl < 0:
        return WindVector(0.0, 0.0)
    factor = _ground_factor(altitude_msl, height_agl)
    if altitude_msl <= LEVEL_ALTITUDES_M[0]:
        wind = levels[0] * factor
    elif altitude_msl >= LEVEL_ALTITUDES_M[2]:
        wind = levels[2]
    else:
        i = 0 if altitude_msl < LEVEL_ALTITUDES_M[1] else 1
        w = _blend_weight(altitude_msl, LEVEL_ALTITUDES_M[i], LEVEL_ALTITUDES_M[i + 1])
        wind = (levels[i] + (levels[i + 1] - levels[i]) * w) * factor
    return WindVector(wind.real, wind.imag)


def surface_wind(setting: Mapping[str, Any], ground_msl: float) -> WindVector:
    """The wind 10 m above the ground, what a METAR or an ATIS reports.

    Args:
        setting: The ``.miz``'s ``weather.wind`` table.
        ground_msl: The ground's altitude above sea level, m.

    Returns:
        The wind 10 m above that ground.
    """
    return base_wind(setting, ground_msl + SURFACE_HEIGHT_M, SURFACE_HEIGHT_M)


def wind_profile(setting: Mapping[str, Any], ground_msl: float, heights_agl: Sequence[float]) -> list[LayerWind]:
    """The base wind at several heights above a place.

    Args:
        setting: The ``.miz``'s ``weather.wind`` table.
        ground_msl: The ground's altitude above sea level, m.
        heights_agl: Heights above that ground, m.

    Returns:
        One :class:`LayerWind` per height, in the order given.
    """
    return [
        LayerWind(height, ground_msl + height, base_wind(setting, ground_msl + height, height))
        for height in heights_agl
    ]


def max_wind_between(
    setting: Mapping[str, Any], ground_msl: float, bottom_agl: float, top_agl: float, step_m: float = _BAND_STEP_M
) -> LayerWind:
    """The strongest base wind between two heights above a place, and where it blows.

    Args:
        setting: The ``.miz``'s ``weather.wind`` table.
        ground_msl: The ground's altitude above sea level, m.
        bottom_agl: The band's bottom above the ground, m.
        top_agl: The band's top above the ground, m (sampled too).
        step_m: Sampling step, m.

    Returns:
        The strongest :class:`LayerWind` of the band (the lowest one on a tie).

    Raises:
        ValueError: If the band is empty or the step not positive.
    """
    if top_agl < bottom_agl or step_m <= 0:
        raise ValueError(f"empty band {bottom_agl}-{top_agl} m, or step {step_m} m")
    count = int((top_agl - bottom_agl) // step_m)
    heights = [bottom_agl + i * step_m for i in range(count + 1)]
    if heights[-1] < top_agl:
        heights.append(top_agl)
    return max(wind_profile(setting, ground_msl, heights), key=lambda layer: layer.wind.speed)


def _wanted_vector(wanted_from_deg: float, wanted_knots: float) -> complex:
    """A METAR-style wind ("from", knots) as ``x + i z`` in m/s."""
    return cmath.rect(wanted_knots * _MPS_PER_KNOT, math.radians((wanted_from_deg + 180.0) % 360.0))


def _surface_terms(ground_msl: float) -> tuple[float, float]:
    """The ground factor and the weight ``w`` of the 2,000 m level at 10 m above a ground.

    Raises:
        ValueError: At 2,000 m and above, where the 0 m level weighs nothing.
    """
    altitude = ground_msl + SURFACE_HEIGHT_M
    if altitude >= LEVEL_ALTITUDES_M[1]:
        raise ValueError(
            f"the reference point is at {altitude:.0f} m, at or above 2000 m: the ground setting no longer"
            " acts there, no atGround gives the wanted wind"
        )
    factor = _ground_factor(altitude, SURFACE_HEIGHT_M)
    w = 0.0 if altitude <= LEVEL_ALTITUDES_M[0] else _blend_weight(altitude, LEVEL_ALTITUDES_M[0], LEVEL_ALTITUDES_M[1])
    return factor, w


def setting_for_surface_wind(
    wanted_from_deg: float,
    wanted_knots: float,
    ground_msl: float,
    *,
    at2000_ratio: float = 2.2,
    veer_deg: float = 20.0,
    at8000_offset_mps: float = 3.0,
) -> Inversion:
    """The setting that makes DCS simulate a wanted wind 10 m above a ground, ``at2000`` proportional.

    ``at2000`` is ``at2000_ratio`` times ``atGround``, veered ``veer_deg`` to the right; ``at8000`` is
    ``at2000`` plus ``at8000_offset_mps``, same direction. The 10 m wind is then linear in ``atGround``,
    so the inversion is one complex division.

    Args:
        wanted_from_deg: Where the wanted wind comes from, degrees true.
        wanted_knots: The wanted speed, knots.
        ground_msl: The reference ground's altitude above sea level, m.
        at2000_ratio: ``at2000`` over ``atGround``. At 2.2, just above the 2.141 the 0 m level carries,
            the wind only grows with height.
        veer_deg: How far the wind turns clockwise from the surface to 2,000 m, 0 to 30°.
        at8000_offset_mps: ``at8000`` minus ``at2000``, m/s.

    Returns:
        The :class:`Inversion`.

    Raises:
        ValueError: If the veer is outside 0-30° (the dip of two vectors at an angle), the ratio under
            2.141 (a jet in the low layer), or the reference point at 2,000 m or above.
    """
    if not 0.0 <= veer_deg <= MAX_VEER_DEG:
        raise ValueError(
            f"veer {veer_deg}° outside 0-{MAX_VEER_DEG:.0f}°: two layers further apart make the wind dip between them"
        )
    if at2000_ratio < GROUND_REFERENCE_FACTOR:
        raise ValueError(
            f"at2000 ratio {at2000_ratio} under {GROUND_REFERENCE_FACTOR:.3f}: the 0 m level would be stronger than"
            " 2000 m, a jet in the low layer that peaks 300-600 m above the ground"
        )
    factor, w = _surface_terms(ground_msl)
    turn = cmath.rect(at2000_ratio, math.radians(veer_deg))
    ground = _wanted_vector(wanted_from_deg, wanted_knots) / (factor * (GROUND_REFERENCE_FACTOR * (1.0 - w) + turn * w))
    at2000 = ground * turn
    at8000 = at2000 + cmath.rect(at8000_offset_mps, cmath.phase(at2000)) if at2000 else complex(at8000_offset_mps, 0)
    setting = {"atGround": _layer(ground), "at2000": _layer(at2000), "at8000": _layer(at8000)}
    if not at2000:
        # A calm: keep the veer in the directions, so the setting still reads as intended.
        setting["at2000"]["dir"] = setting["at8000"]["dir"] = veer_deg % 360.0
    return Inversion(setting, 1.0 - w, 1.0 - w >= RELIABLE_GROUND_WEIGHT)


def ground_setting_for_surface_wind(
    wanted_from_deg: float,
    wanted_knots: float,
    ground_msl: float,
    at2000: Mapping[str, Any],
    at8000: Mapping[str, Any] | None = None,
    *,
    at8000_offset_mps: float = 3.0,
) -> Inversion:
    """The ``atGround`` that makes DCS simulate a wanted wind 10 m above a ground, ``at2000`` given.

    Solved as ``G = (W / F - A w) / (2.141 (1 - w))``: the real wind aloft the servers take from
    open-meteo, or one the author set.

    Args:
        wanted_from_deg: Where the wanted wind comes from, degrees true.
        wanted_knots: The wanted speed, knots.
        ground_msl: The reference ground's altitude above sea level, m.
        at2000: The ``at2000`` layer, ``{speed, dir}`` with ``dir`` where it blows to.
        at8000: The ``at8000`` layer; ``None`` puts it at ``at2000`` plus ``at8000_offset_mps``.
        at8000_offset_mps: ``at8000`` minus ``at2000`` when ``at8000`` is not given, m/s.

    Returns:
        The :class:`Inversion`; ``reliable`` is False when the 2,000 m level dominates the reference
        point, where the result can be absurd, even opposed to the wanted wind.

    Raises:
        ValueError: If the reference point is at 2,000 m or above.
    """
    factor, w = _surface_terms(ground_msl)
    upper = _vector(at2000)
    ground = (_wanted_vector(wanted_from_deg, wanted_knots) / factor - upper * w) / (
        GROUND_REFERENCE_FACTOR * (1.0 - w)
    )
    if at8000 is None:
        top = upper + cmath.rect(at8000_offset_mps, cmath.phase(upper)) if upper else complex(at8000_offset_mps, 0)
        top_layer = _layer(top)
    else:
        top_layer = {"speed": float(at8000.get("speed", 0.0)), "dir": float(at8000.get("dir", 0.0))}
    setting = {
        "atGround": _layer(ground),
        "at2000": {"speed": float(at2000.get("speed", 0.0)), "dir": float(at2000.get("dir", 0.0))},
        "at8000": top_layer,
    }
    return Inversion(setting, 1.0 - w, 1.0 - w >= RELIABLE_GROUND_WEIGHT)


def _scaled(setting: Mapping[str, Any], ground: float, upper: float) -> dict[str, dict[str, float]]:
    """A copy of a setting with ``atGround`` scaled by ``ground`` and the upper levels by ``upper``."""
    result: dict[str, dict[str, float]] = {}
    for key in _LEVEL_KEYS:
        layer = setting.get(key) or {}
        scale = ground if key == "atGround" else upper
        result[key] = {"speed": float(layer.get("speed", 0.0)) * scale, "dir": float(layer.get("dir", 0.0))}
    return result


def _bisect(fits: Any) -> float:
    """The largest factor in ``[0, 1]`` for which ``fits(factor)`` holds, ``fits`` being monotonic."""
    low, high = 0.0, 1.0
    for _ in range(_BISECTION_STEPS):
        middle = (low + high) / 2
        if fits(middle):
            low = middle
        else:
            high = middle
    return low


def cap_setting_for_band(setting: Mapping[str, Any], ground_msl: float, max_knots: float, top_agl: float) -> BandCap:
    """Reduce a setting so the strongest wind 10 m to ``top_agl`` above a ground stays under a cap.

    ``atGround`` is scaled down first (by bisection: the band's maximum grows with it, with no closed
    form once ``at2000`` is fixed); only when the band is still above the cap with no ground wind at
    all — terrain high enough for ``at2000`` to dominate — are ``at2000`` and ``at8000`` scaled too.

    Args:
        setting: The ``.miz``'s ``weather.wind`` table.
        ground_msl: The ground's altitude above sea level, m.
        max_knots: The cap, knots.
        top_agl: The band's top above the ground, m.

    Returns:
        The :class:`BandCap`.
    """

    def band_knots(candidate: Mapping[str, Any]) -> float:
        """The strongest wind of the band under a candidate setting, knots."""
        return max_wind_between(candidate, ground_msl, SURFACE_HEIGHT_M, top_agl).wind.knots

    original = _scaled(setting, 1.0, 1.0)
    if band_knots(original) <= max_knots:
        return BandCap(original, False, False)
    if band_knots(_scaled(setting, 0.0, 1.0)) <= max_knots:
        factor = _bisect(lambda f: band_knots(_scaled(setting, f, 1.0)) <= max_knots)
        return BandCap(_scaled(setting, factor, 1.0), True, False)
    factor = _bisect(lambda f: band_knots(_scaled(setting, 0.0, f)) <= max_knots)
    return BandCap(_scaled(setting, 0.0, factor), True, True)


def turbulence_for_gust(mean_knots: float, gust_knots: float | None) -> float:
    """The turbulence that reproduces a METAR's gust, in m/s (``groundTurbulence`` is ten times it).

    Measured in game on 2026-10-31 (whitepaper ``dcs-turbulence``, section 3.4): a turbulence of S m/s
    gives a METAR gust gap of :data:`GUST_PER_SETTING` × S at 10 m. The gap is the gust minus the mean
    wind — not the peak gust, which DCS Real Weather writes — and the result is capped at
    :data:`GUST_TURBULENCE_CAP_MPS`.

    Args:
        mean_knots: The METAR's mean wind, knots.
        gust_knots: The METAR's gust, knots; ``None`` or 0 when none is reported.

    Returns:
        The turbulence, m/s; 0 without a gust or when the gust does not exceed the mean.
    """
    if not gust_knots or gust_knots <= mean_knots:
        return 0.0
    gap_mps = (gust_knots - mean_knots) * _MPS_PER_KNOT
    return min(gap_mps / GUST_PER_SETTING, GUST_TURBULENCE_CAP_MPS)
