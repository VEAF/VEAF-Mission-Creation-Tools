"""DCS weather conversion from METAR data."""

import json
import re
import traceback
from dataclasses import dataclass, field
from functools import lru_cache
from typing import Any

from veaf_libs.dcs_wind import (
    GROUND_REFERENCE_FACTOR,
    KNOTS_PER_MPS,
    LEVEL_ALTITUDES_M,
    MAX_VEER_DEG,
    RELIABLE_GROUND_WEIGHT,
    SURFACE_HEIGHT_M,
    ground_setting_for_surface_wind,
    setting_for_surface_wind,
    surface_wind,
    turbulence_for_gust,
)
from veaf_libs.i18n import t
from veaf_libs.logger import logger
from veaf_libs.mission_wind import ReferenceAirfield, layer_winds, resolve_reference_airfield

try:
    from avwx.current.metar import Metar

    AVWX_AVAILABLE = True
except ImportError:
    AVWX_AVAILABLE = False

#: DCS cloud presets per coverage, in order of preference, with the cloud-base range in metres DCS
#: accepts for each: ``presetAltMin`` / ``presetAltMax`` in ``Config/Effects/clouds.lua`` of the DCS
#: install. The coverage lists follow the METAR each preset declares in its ``readableName`` there.
#: v5 picked one at random from similar lists; a build must be reproducible, so the first preset whose
#: range holds the base wins.
_PRESETS_BY_COVERAGE: dict[int, list[tuple[str, float, float]]] = {
    1: [("Preset1", 840, 4200), ("Preset2", 1260, 2520)],  # FEW
    2: [("Preset3", 840, 2520), ("Preset4", 1260, 2520), ("Preset5", 1260, 4620), ("Preset8", 3780, 5460)],  # SCT
    3: [("Preset13", 1680, 3360), ("Preset15", 840, 5040), ("Preset16", 1260, 4200), ("Preset17", 0, 2520)],  # BKN
    4: [("Preset21", 1260, 4200), ("Preset22", 420, 4200), ("Preset19", 0, 2940)],  # OVC
}
_RAINY_PRESETS: list[tuple[str, float, float]] = [("RainyPreset1", 420, 2940), ("RainyPreset2", 840, 2520)]

#: 15 kt: the wind cap of ``clearsky: true``.
_CLEARSKY_MAX_WIND_MPS = 7.72

#: METAR present-weather groups that make DCS rain: rain, drizzle, hail, unknown precipitation, and
#: a thunderstorm. Snow is left out on purpose: no DCS preset is a snow preset, and what DCS does
#: with a rainy preset below zero has not been checked.
_PRECIPITATION = re.compile(r"[-+]?(?:VC)?(?:TS|SH|FZ)?(?:RA|DZ|GR|GS|UP)+|[-+]?(?:VC)?TS")
#: Fog groups (``FG``, ``MIFG``, ``BCFG``, ``PRFG``, ``FZFG``).
_FOG = re.compile(r"(?:MI|BC|PR|FZ)?FG")


def _select_cloud_preset(cloud_type: int, base: float, precipitation: bool) -> tuple[str | None, float]:
    """Pick the DCS cloud preset for a coverage and base, and the base DCS will accept with it.

    Args:
        cloud_type: Coverage, 0 (clear) to 4 (overcast) as in ``DCSWeatherConverter.CLOUD_TYPES``.
        base: Wanted cloud base in metres.
        precipitation: Whether it rains, which only the rainy presets render.

    Returns:
        The preset name (None for a clear sky) and the base, moved into the preset's range if needed.
    """
    candidates = _RAINY_PRESETS if precipitation else _PRESETS_BY_COVERAGE.get(cloud_type)
    if not candidates:
        return None, base
    for name, low, high in candidates:
        if low <= base <= high:
            return name, base
    name, low, high = min(candidates, key=lambda c: max(c[1] - base, base - c[2]))
    return name, min(max(base, low), high)


class DCSWeatherConverter:
    """Convert METAR strings to DCS weather table format."""

    # DCS weather cloud types
    CLOUD_TYPES = {
        "clear": 0,
        "few": 1,
        "scattered": 2,
        "broken": 3,
        "overcast": 4,
    }

    @staticmethod
    def to_dcs_lua_table(**kwargs: Any) -> dict[str, Any]:
        """The fields of the DCS mission ``weather`` table for a weather: :meth:`convert`, table only.

        Args:
            **kwargs: The arguments of :meth:`convert`.

        Returns:
            Dictionary of DCS ``weather`` table fields.
        """
        return DCSWeatherConverter.convert(**kwargs).weather

    @staticmethod
    def convert(
        metar_string: str = "",
        airport_icao: str = "",
        temperature_celsius: float | None = None,
        wind_speed_mps: float | None = None,
        wind_direction_degrees: float | None = None,
        visibility_meters: float | None = None,
        cloud_coverage: str | None = None,
        cloud_height_meters: float | None = None,
        precipitation: bool | None = None,
        fog_enabled: bool = False,
        fog_thickness_meters: float = 200.0,
        clearsky: bool = False,
        *,
        theatre: str | None = None,
        reference_airfield: str | None = None,
        departure_airfield: str | None = None,
        wind_gust_mps: float | None = None,
        turbulence_mps: float | None = None,
        wind_veer: float | None = None,
        wind_speed_2000: float | None = None,
        wind_direction_2000: float | None = None,
        wind_speed_8000: float | None = None,
        wind_direction_8000: float | None = None,
    ) -> "WeatherConversion":
        """
        Convert weather parameters to the fields of the DCS mission ``weather`` table.

        Supports three weather input methods:
        1. metar_string: User-provided METAR string (parsed with regex)
        2. airport_icao: Airport code to fetch live METAR from avwx-engine
        3. Individual parameters: Manual weather values

        Priority: metar_string > airport_icao > individual parameters > defaults

        The result holds the keys DCS reads (``season``, ``wind``, ``visibility``, ``clouds``, ``qnh``,
        ``enable_fog``, ``fog``, ``atmosphere_type``, and ``groundTurbulence`` when a METAR, a gust or a
        turbulence decides it) and is merged into the mission's table, so the keys it does not set
        (``cyclones``, dust...) keep the base mission's values. It used to return an ``atmosphere`` table
        DCS does not know, so every variant flew the base mission's sky (FIX-SCRATCH-MISSION-FINDINGS
        ticket 01).

        **The wind is the wind wanted 10 m above a reference airfield**, as a METAR says it, not a DCS
        setting (FEAT-MISSION-WIND-CHECK): DCS multiplies its ground setting by 2.14 at sea level and by
        less near the ground, so the setting written is the one :mod:`veaf_libs.dcs_wind` computes for
        that airfield's altitude. ``at2000`` is 2.2 times ``atGround`` veered ``wind_veer`` (20° by
        default) and ``at8000`` is ``at2000`` plus 3 m/s, unless given.

        Args:
            metar_string: METAR weather string (provided manually)
            airport_icao: Airport ICAO code to fetch live METAR from avwx
            temperature_celsius: Temperature override
            wind_speed_mps: Wanted surface wind speed in m/s, 10 m above the reference airfield
            wind_direction_degrees: Wind direction override, where the wind comes FROM as in a METAR
            visibility_meters: Visibility in meters override
            cloud_coverage: Cloud type ("clear", "few", "scattered", "broken", "overcast")
            cloud_height_meters: Cloud base altitude in meters
            precipitation: Rain override; a METAR's rain groups set it otherwise
            fog_enabled: Enable fog effect (a METAR's fog group enables it too)
            fog_thickness_meters: Fog vertical thickness
            clearsky: Cap to VFR-friendly conditions: clouds at most FEW, a surface wind of 15 kt at most
                at the reference airfield, visibility 10 km or more, no rain, no fog, no gust
            theatre: The mission's theatre, to find the reference airfield and its altitude.
            reference_airfield: The airfield the wind is wanted at, when no METAR station of the map says.
            departure_airfield: The mission's first player departure airfield, the next fallback.
            wind_gust_mps: The gust, m/s; a METAR's ``G`` group sets it otherwise.
            turbulence_mps: The turbulence, m/s as the editor shows it; wins over the gust.
            wind_veer: How far the wind turns clockwise from the surface to 2,000 m, 0-30°.
            wind_speed_2000: ``at2000``'s speed, m/s, to set it by hand.
            wind_direction_2000: Where the 2,000 m wind comes FROM; the surface's plus the veer by default.
            wind_speed_8000: ``at8000``'s speed, m/s, to set it by hand.
            wind_direction_8000: Where the 8,000 m wind comes FROM; the 2,000 m one by default.

        Returns:
            The :class:`WeatherConversion`.

        Raises:
            ValueError: If the veer is outside 0-30°.
        """
        try:
            weather: dict[str, Any] = {}

            # Priority 1: Use provided METAR string
            if metar_string:
                weather = _extract_metar_values(metar_string)
            # Priority 2: Fetch live weather from avwx if airport code provided
            elif airport_icao:
                # A copy: the fetch is memoised and returns its dict by reference.
                weather = dict(_fetch_live_metar(airport_icao))
            from_metar = bool(weather)

            # Apply parameter overrides
            if temperature_celsius is not None:
                weather["temperature"] = temperature_celsius
            if wind_speed_mps is not None:
                weather["wind_speed"] = wind_speed_mps
            if wind_direction_degrees is not None:
                weather["wind_direction"] = wind_direction_degrees
            if wind_gust_mps is not None:
                weather["wind_gust"] = wind_gust_mps
            if visibility_meters is not None:
                weather["visibility"] = visibility_meters
            if cloud_coverage:
                weather["cloud_type"] = DCSWeatherConverter.CLOUD_TYPES.get(cloud_coverage.lower(), 0)
            if cloud_height_meters is not None:
                weather["cloud_height"] = cloud_height_meters
            if precipitation is not None:
                weather["precipitation"] = precipitation
            fog = fog_enabled or bool(weather.get("fog"))

            if clearsky:
                weather = cap_clearsky(weather)
                fog = False
                logger.debug(t("weather.clearsky_applied"))

            preset, base = _select_cloud_preset(
                weather.get("cloud_type", 0), weather.get("cloud_height", 2000.0), bool(weather.get("precipitation"))
            )
            clouds: dict[str, Any] = {"thickness": 200, "density": 0, "base": round(base), "iprecptns": 0}
            if preset:
                clouds["preset"] = preset

            # A METAR gives where the wind comes FROM, the mission file where it blows TO (v5 did the
            # same, `convertFromTo`). The setting is the one that gives the wanted wind 10 m above the
            # reference airfield; v5's "ground + 2 / + 5 m/s" aloft made a jet in the low layer.
            station = _metar_station(metar_string) if metar_string else (airport_icao or None)
            reference, warnings = resolve_reference_airfield(
                theatre, station=station, reference_airfield=reference_airfield, departure_airfield=departure_airfield
            )
            speed = float(weather.get("wind_speed", 5.0))
            wind, wind_warnings = _wind_setting(
                float(weather.get("wind_direction", 0.0)),
                speed,
                reference,
                veer=20.0 if wind_veer is None else float(wind_veer),
                at2000=(wind_speed_2000, wind_direction_2000),
                at8000=(wind_speed_8000, wind_direction_8000),
            )
            warnings += wind_warnings
            visibility = weather.get("visibility", 10000.0)

            dcs_weather: dict[str, Any] = {
                "atmosphere_type": 0,  # static weather: with dynamic weather DCS ignores the fields below
                "season": {"temperature": weather.get("temperature", 15.0)},
                "wind": wind,
                # A METAR's 9999 means "10 km or more"; v5 flew it as DCS's 80 km.
                "visibility": {"distance": 80000 if visibility >= 9000 else round(visibility)},
                "clouds": clouds,
                "enable_fog": fog,
                # v5's fog: 800-1000 m visibility, 100-300 m thick; the middle, for reproducibility.
                "fog": {"visibility": 900 if fog else 0, "thickness": round(fog_thickness_meters) if fog else 0},
            }
            # Only a pressure actually reported: otherwise the base mission's QNH stays.
            if weather.get("qnh_hpa"):
                dcs_weather["qnh"] = round(weather["qnh_hpa"] * 0.750062, 1)  # DCS stores mmHg
            # The turbulence: given, else the gust's gap (measured mapping, capped), else none for a METAR
            # without a gust. A manual weather with neither keeps the base mission's.
            gust = weather.get("wind_gust")
            if turbulence_mps is not None:
                dcs_weather["groundTurbulence"] = round(10 * float(turbulence_mps))
            elif gust or from_metar:
                gust_knots = float(gust) * KNOTS_PER_MPS if gust else None
                dcs_weather["groundTurbulence"] = round(10 * turbulence_for_gust(speed * KNOTS_PER_MPS, gust_knots))

            logger.debug(f"Converted weather: {json.dumps(dcs_weather, indent=2)}")
            return WeatherConversion(
                weather=dcs_weather,
                reference=reference,
                layers=layer_winds(wind, reference.elevation),
                warnings=warnings,
            )

        except ValueError:
            # A wind that cannot be set (a veer past 30°): the caller's input to
            # report, not a crash to log — `logger.error` would abort the whole command.
            raise
        except Exception as e:
            logger.error(t("weather.converter.convert_failed", error=str(e)))
            raise


@dataclass
class WeatherConversion:
    """What :meth:`DCSWeatherConverter.convert` answers.

    Attributes:
        weather: The fields of the DCS mission ``weather`` table.
        reference: The airfield the wind was set for.
        layers: The wind DCS will simulate above it, by the layers of a briefing (true directions).
        warnings: What the author should know: sea level used, a jet in the low layer, an unreliable
            inversion.
    """

    weather: dict[str, Any]
    reference: ReferenceAirfield
    layers: list[dict[str, Any]]
    warnings: list[str] = field(default_factory=list)


def _metar_station(metar: str) -> str | None:
    """The ICAO station a METAR starts with, ``METAR`` / ``SPECI`` aside, or None."""
    match = re.match(r"(?:(?:METAR|SPECI)\s+)?([A-Z]{4})\b", metar.strip())
    return match.group(1) if match else None


def _to_dir(from_deg: float) -> float:
    """A METAR "from" direction as the ``.miz``'s "to" one."""
    return (from_deg + 180.0) % 360.0


def _wind_setting(
    from_deg: float,
    speed_mps: float,
    reference: ReferenceAirfield,
    *,
    veer: float,
    at2000: tuple[float | None, float | None],
    at8000: tuple[float | None, float | None],
) -> tuple[dict[str, dict[str, float]], list[str]]:
    """The ``weather.wind`` table that makes DCS simulate a wanted wind at the reference airfield.

    Args:
        from_deg: Where the wanted surface wind comes from.
        speed_mps: Its speed, m/s.
        reference: The airfield it is wanted at.
        veer: Turn of the wind from the surface to 2,000 m, clockwise, 0-30°.
        at2000: ``(speed m/s, from deg)`` set by hand, or ``(None, ...)``.
        at8000: ``(speed m/s, from deg)`` set by hand, or ``(None, ...)``.

    Returns:
        The table, rounded as written, and the warnings it calls for.

    Raises:
        ValueError: If the veer is outside 0-30°.
    """
    knots = speed_mps * KNOTS_PER_MPS
    warnings: list[str] = []
    if not 0.0 <= veer <= MAX_VEER_DEG:
        raise ValueError(f"wind_veer {veer}° outside 0-{MAX_VEER_DEG:.0f}°")
    ground_weight: float | None = None
    if reference.elevation + SURFACE_HEIGHT_M >= LEVEL_ALTITUDES_M[1]:
        # At 2,000 m and above the ground setting does not act (Bamyan 2,590 m, Gardez 2,373 m): the
        # wanted wind goes on `at2000`, with `at8000` at the same speed so the blend between them is flat
        # there; `atGround` keeps the 2.2 ratio below it. A hand-set `at2000` is written as given.
        if at2000[0] is None:
            unit = {"speed": 1.0, "dir": 0.0}
            flat = {"atGround": {"speed": 0.0, "dir": 0.0}, "at2000": unit, "at8000": unit}
            factor = surface_wind(flat, reference.elevation).speed
            upper = {"speed": speed_mps / factor if factor else 0.0, "dir": _to_dir(from_deg)}
        else:
            upper_from = from_deg + veer if at2000[1] is None else float(at2000[1])
            upper = {"speed": float(at2000[0]), "dir": _to_dir(upper_from)}
        setting = {
            "atGround": {"speed": upper["speed"] / 2.2, "dir": (upper["dir"] - veer) % 360.0},
            "at2000": upper,
            "at8000": dict(upper),
        }
        ground_weight = 0.0
    elif at2000[0] is None:
        inversion = setting_for_surface_wind(from_deg, knots, reference.elevation, veer_deg=veer)
        setting, ground_weight = inversion.setting, inversion.ground_weight
    else:
        upper_from = from_deg + veer if at2000[1] is None else float(at2000[1])
        upper = {"speed": float(at2000[0]), "dir": _to_dir(upper_from)}
        inversion = ground_setting_for_surface_wind(from_deg, knots, reference.elevation, upper)
        setting, ground_weight = inversion.setting, inversion.ground_weight
    if at8000[0] is not None:
        top_from = (float(setting["at2000"]["dir"]) + 180.0) % 360.0 if at8000[1] is None else float(at8000[1])
        setting["at8000"] = {"speed": float(at8000[0]), "dir": _to_dir(top_from)}
    wind = {
        key: {"speed": round(float(layer["speed"]), 2), "dir": round(float(layer["dir"]), 1) % 360.0}
        for key, layer in setting.items()
    }
    if wind["at2000"]["speed"] < GROUND_REFERENCE_FACTOR * wind["atGround"]["speed"] - 0.01:
        warnings.append(
            t(
                "wind.low_layer_jet",
                at2000=f"{wind['at2000']['speed']:.1f}",
                factor=f"{GROUND_REFERENCE_FACTOR:.2f}",
                ground=f"{wind['atGround']['speed']:.1f}",
            )
        )
    if ground_weight < RELIABLE_GROUND_WEIGHT:
        warnings.append(
            t(
                "wind.unreliable_inversion",
                airfield=reference.name,
                elevation=round(reference.elevation),
                weight=round(100 * (1 - ground_weight)),
            )
        )
    return wind, warnings


def cap_clearsky(values: dict[str, Any]) -> dict[str, Any]:
    """Cap weather values to the VFR-friendly conditions of ``clearsky: true``.

    The one place the caps live: the injected weather table and the briefing's ``${METAR}`` both go
    through it, so the pilot reads the sky DCS is given (FIX-CLEARSKY-METAR — the METAR of an
    ``airport_icao`` variant used to announce the uncapped report).

    Args:
        values: Weather values in this module's form — ``cloud_type`` 0 (clear) to 4 (overcast),
            ``wind_speed`` in m/s, ``visibility`` in m, ``precipitation`` and ``fog``; each optional.

    The wind capped is the **wanted** wind, which the converter makes the simulated surface wind at the
    reference airfield (FEAT-MISSION-WIND-CHECK): the 15 kt hold where pilots read them, not on a DCS
    setting that blows 20 kt and more over any inland airfield.

    Returns:
        A capped copy: clouds at most FEW, wind under 15 kt, no gust, visibility 10 km or more, no rain,
        no fog. A missing wind or cloud stays missing; the input is left untouched.
    """
    capped = dict(values)
    capped.pop("wind_gust", None)
    if capped.get("cloud_type") is not None:
        capped["cloud_type"] = min(capped["cloud_type"], DCSWeatherConverter.CLOUD_TYPES["few"])
    if capped.get("wind_speed") is not None:
        capped["wind_speed"] = min(float(capped["wind_speed"]), _CLEARSKY_MAX_WIND_MPS)
    capped["visibility"] = max(float(capped.get("visibility") or 10000.0), 9999.0)
    capped["precipitation"] = False
    capped["fog"] = False
    return capped


def fetch_metar_string(airport_icao: str) -> str:
    """The raw METAR text for *airport_icao*, for showing to a pilot.

    Args:
        airport_icao: Airport ICAO code.

    Returns:
        The METAR as the station published it, or ``""`` when it cannot be had.

    Derived from the **same** fetch that builds the DCS weather table, not a second request. That matters
    twice over (caught in review, Sourcery PR #786): a station publishing a new report between two
    requests would put a METAR in the briefing that contradicts the weather actually injected, and a
    second request is a second chance to be rate-limited or to fail.

    ``${METAR}`` in a briefing wants what a pilot would read, so this is the published text rather than a
    reconstruction of it from the parsed values.
    """
    return str(_fetch_live_metar(airport_icao).get("raw", "") or "")


def clear_metar_cache() -> None:
    """Forget the fetched reports.

    For tests, and for a caller that deliberately wants a fresh look at the weather.
    """
    _fetch_live_metar.cache_clear()


@lru_cache(maxsize=32)
def _fetch_live_metar(airport_icao: str) -> dict[str, Any]:
    """
    Fetch live METAR data from avwx-engine by airport ICAO code.

    Args:
        airport_icao: Airport ICAO code (e.g., "OSDI", "KJFK")

    Returns:
        Dictionary with keys: temperature, wind_speed, wind_direction,
        visibility, cloud_type, cloud_height, qnh_hpa, precipitation, fog, and ``raw`` — the published text.

    **Memoised per ICAO**, so a station is asked once per process however many places want it. Two
    consumers exist — the weather table and the briefing's ``${METAR}`` — and they must agree: a station
    publishing between two requests would otherwise have the briefing contradict the weather the mission
    was actually built with (Sourcery, PR #786). It also keeps seven variants sharing one ICAO down to a
    single request instead of seven.

    The cached dict is returned by reference and callers only read it. :func:`clear_metar_cache` exists
    for tests and for a caller that wants a deliberately fresh look.
    """
    result: dict[str, Any] = {
        "temperature": 15.0,  # Default
        "wind_speed": 5.0,  # m/s
        "wind_direction": 0.0,  # degrees
        "visibility": 10000.0,  # meters
        "cloud_type": 0,  # Clear
        "cloud_height": 2000.0,  # meters
        "qnh_hpa": None,  # hPa, only when reported
        "precipitation": False,
        "fog": False,
        "raw": "",  # the published text, for a briefing to show
    }

    if not airport_icao or not AVWX_AVAILABLE:
        if not AVWX_AVAILABLE:
            logger.warning(t("weather.converter.avwx_unavailable"))
        return result

    try:
        logger.debug(f"Fetching live METAR for airport {airport_icao} from avwx-engine")
        metar = Metar(airport_icao)

        # VMR-006: `Metar(icao)` only *constructs* — `.update()` is what fetches. Without it
        # the published text is empty, so the function returned its canned defaults while
        # logging "Successfully fetched", and a mission asking for live weather quietly got
        # invented weather. The return value matters too: avwx reports a failed fetch by
        # returning False rather than raising, so ignoring it reinstates the same silence.
        if not metar.update():  # type: ignore[attr-defined]
            logger.warning(t("weather.converter.metar_fetch_empty", icao=airport_icao))
            return result

        result["raw"] = str(getattr(metar, "raw", "") or "")

        # The published text goes through the same parser as a METAR written in versions.yaml. This
        # used to read `metar.temperature`, `metar.clouds[i][0]`... — attributes the avwx `Metar` does
        # not have (its values live under `.data`), so every live fetch died on AttributeError and flew
        # the defaults; the tests passed on a fake shaped like that invented API
        # (FIX-SCRATCH-MISSION-FINDINGS ticket 01). One parser also gives both paths the pressure, the
        # rain and the fog.
        result = _fallback_metar_parsing(result["raw"], result)

        logger.debug(f"Successfully fetched METAR for {airport_icao}: {result}")
    except Exception as e:
        # Kept broad on purpose: this is a network call to a third-party library, and a build must
        # not die because a weather service is down. But naming the exception type is what makes a
        # programming error tellable from an outage (SECREV-2 / VMR-069) — an AttributeError from an
        # avwx API change used to read exactly like a failed request, and the traceback was lost
        # entirely. The mission then flies the default weather, so the warning has to be legible.
        logger.warning(t("weather.converter.metar_fetch_failed", icao=airport_icao, error=f"{type(e).__name__}: {e}"))
        logger.debug(f"METAR fetch traceback for {airport_icao}:\n{traceback.format_exc()}")

    return result


def _extract_metar_values(metar_string: str) -> dict[str, Any]:
    """
    Extract weather values from METAR string using regex-based parsing.

    Args:
        metar_string: METAR weather string (e.g., "OSDI 151420Z 27015G25KT 9999 SKC 15/10 Q1018")

    Returns:
        Dictionary with keys: temperature, wind_speed, wind_direction,
        visibility, cloud_type, cloud_height, qnh_hpa, precipitation, fog
    """
    result: dict[str, Any] = {
        "temperature": 15.0,  # Default
        "wind_speed": 5.0,  # m/s
        "wind_direction": 0.0,  # degrees
        "visibility": 10000.0,  # meters
        "cloud_type": 0,  # Clear
        "cloud_height": 2000.0,  # meters
        "qnh_hpa": None,  # hPa, only when reported
        "precipitation": False,
        "fog": False,
    }

    if not metar_string:
        return result

    # Use fallback regex-based parsing for provided METAR strings
    result = _fallback_metar_parsing(metar_string, result)

    return result


def _fallback_metar_parsing(metar_string: str, defaults: dict[str, Any]) -> dict[str, Any]:
    """
    Fallback regex-based METAR parsing for common patterns.

    Used when avwx-engine is not available or parsing fails.
    Extracts basic values from standard METAR format.

    Args:
        metar_string: METAR weather string
        defaults: Default values to use

    Returns:
        Dictionary with extracted weather values
    """
    result = defaults.copy()

    if not metar_string:
        return result

    parts = metar_string.split()

    # Everything from the first of these words on describes a *forecast* or free-text remarks, not
    # the current observation (SECREV-2 / VMR-070). The loop used to read straight through them, and
    # since the visibility branch has no `break`, the last four-digit group won: a report ending in
    # `TEMPO 3000` was flown at 3000 m even though it was observed at 9999.
    _NOT_OBSERVED_FROM = ("TEMPO", "BECMG", "NOSIG", "RMK", "PROB30", "PROB40", "FM")
    for cut, part in enumerate(parts):
        if part.upper().startswith(_NOT_OBSERVED_FROM):
            parts = parts[:cut]
            break

    #: Which single-valued groups have already been read, so a later token cannot overwrite them.
    seen: set[str] = set()

    for i, part in enumerate(parts):
        # Temperature/Dewpoint: "15/10" format
        if "/" in part and i > 0:
            with_temp = part.split("/")[0]
            # VMR-016: a METAR marks a negative temperature with an `M` prefix, not a minus
            # sign — `M05/M10` is -5 °C with a -10 °C dewpoint. Testing `lstrip("-").isdigit()`
            # therefore rejected every sub-zero reading and left the default in place
            # **silently**, so a winter mission quietly flew at whatever temperature happened to
            # be configured. Both spellings are accepted now; the `-` form is not valid METAR but
            # was already tolerated here, and removing tolerance would be a second change.
            if with_temp.upper().startswith("M"):
                with_temp = "-" + with_temp[1:]
            if with_temp.lstrip("-").isdigit():
                try:
                    result["temperature"] = float(with_temp)
                except ValueError:
                    pass

        # Wind: "27015G25KT" or "27015KT" format (direction speed[gust]KT/MPS)
        if "KT" in part or "MPS" in part:
            # A variable wind (`VRB02KT`) has no direction: it keeps the default. Both used to be
            # read as knots, and a VRB group not at all — harmless while the weather never reached
            # DCS, wrong since it does (URSS, feeding Caucasus v6, reports in MPS).
            match = re.match(r"(\d{3}|VRB)(\d{2})(?:G(\d{2}))?(KT|MPS)", part)
            if match:
                try:
                    if match.group(1) != "VRB":
                        result["wind_direction"] = float(match.group(1))
                    speed = float(match.group(2))
                    # Convert knots to m/s (1 knot = 0.51444 m/s)
                    to_mps = 1.0 if match.group(4) == "MPS" else 0.51444
                    result["wind_speed"] = speed * to_mps
                    # The gust feeds the turbulence (FEAT-MISSION-WIND-CHECK); it used to be dropped.
                    result["wind_gust"] = float(match.group(3)) * to_mps if match.group(3) else None
                except ValueError:
                    pass

        # Visibility: "9999" format (meters) or "10SM" (statute miles).
        # First one only: a METAR carries at most one prevailing visibility, and taking the last
        # four-digit group let a later one overwrite it (SECREV-2 / VMR-070).
        if part.isdigit() and len(part) == 4 and "visibility" not in seen:
            result["visibility"] = float(part)
            seen.add("visibility")

        # Pressure: "Q1018" (hPa) or "A2992" (inches of mercury, hundredths)
        pressure = re.fullmatch(r"([QA])(\d{4})", part)
        if pressure and "qnh" not in seen:
            value = float(pressure.group(2))
            result["qnh_hpa"] = value if pressure.group(1) == "Q" else value / 100 * 33.8639
            seen.add("qnh")

        # Present weather: rain, drizzle, thunderstorm... and fog
        if _PRECIPITATION.fullmatch(part):
            result["precipitation"] = True
        if _FOG.fullmatch(part):
            result["fog"] = True

        # Cloud coverage groups: "FEW010", "SCT025", "BKN040", "OVC100"
        cloud_match = re.match(r"(SKC|CLR|FEW|SCT|BKN|OVC)(\d{3})?", part)
        if cloud_match:
            coverage = cloud_match.group(1)
            altitude = cloud_match.group(2)

            if coverage in ["SKC", "CLR"]:
                result["cloud_type"] = 0
            elif coverage == "FEW":
                result["cloud_type"] = 1
            elif coverage == "SCT":
                result["cloud_type"] = 2
            elif coverage == "BKN":
                result["cloud_type"] = 3
            elif coverage == "OVC":
                result["cloud_type"] = 4

            if altitude:
                try:
                    # Altitude in METAR is in hundreds of feet
                    result["cloud_height"] = float(altitude) * 100 * 0.3048  # Convert to meters
                except ValueError:
                    pass

    return result
