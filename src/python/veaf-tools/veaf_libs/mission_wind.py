"""The wind of a mission, as pilots will meet it: reference airfield, layers, helicopter rule.

:mod:`veaf_libs.dcs_wind` is DCS's model, shared as is with the servers. This module is the VMCT side
of it (FEAT-MISSION-WIND-CHECK): where a mission's wind is set for, which layers a briefing describes,
and the thresholds the helicopter rule and ``mission-check`` apply — named constants in one place,
quoted by every line that applies them.

The wanted wind is the surface wind at a **reference airfield**, 10 m above its ground, as a METAR or
an ATIS says it. That airfield is, in order: the METAR's station when it is an airfield of the
mission's map; otherwise an explicit ``reference_airfield``; otherwise the mission's first player
departure airfield; otherwise sea level, with a warning.
"""

from __future__ import annotations

import math
from collections.abc import Callable, Iterator, Mapping
from dataclasses import dataclass
from typing import Any

from veaf_libs.dcs_airdromes import airfields_for_theatre
from veaf_libs.dcs_wind import LayerWind, base_wind, max_wind_between, surface_wind

FEET = 0.3048
"""Metres in one foot."""

#: The layers a briefing describes, by name: (height above the ground, m) or (altitude above sea
#: level, m) — the layers a helicopter, a low-level run and a jet each need (PRD D5).
SURFACE_LAYER = "surface"
LAYERS_AGL: tuple[tuple[str, float], ...] = (
    (SURFACE_LAYER, 10.0),
    ("1000 ft AGL", 1000 * FEET),
    ("3000 ft AGL", 3000 * FEET),
)
LAYERS_MSL: tuple[tuple[str, float], ...] = (
    ("FL100", 10000 * FEET),
    ("FL250", 25000 * FEET),
)

HELICOPTER_BAND_TOP_M = 600.0
"""The top of the band the helicopter rule watches, above the ground (PRD D6)."""

HELICOPTER_MAX_KNOTS = 20.0
"""The helicopter rule's speed: the simulated wind 0-600 m above a helicopter place over this warns.
Source: *Marteau du Golan* (36 kt at 1,000 ft, 24 at the surface) was not flyable on 2026-10-31 — one
bad point and one target, to revise after the next evening with helicopters."""

HELICOPTER_MAX_SHEAR_KNOTS = 15.0
"""The helicopter rule's gap: a wind 0-600 m above a helicopter place stronger than the surface wind
there by more than this warns (same source as :data:`HELICOPTER_MAX_KNOTS`)."""

BRIEFING_SPEED_TOLERANCE_KNOTS = 5.0
"""How far an announced speed may be from the simulated range at the layer it names (PRD D7)."""

BRIEFING_DIRECTION_TOLERANCE_DEG = 30.0
"""How far an announced direction may be from the simulated one (PRD D7)."""

MEASURE_TOLERANCE_KNOTS = 0.5
"""How far DCS may be from the model before ``mission-check --measure-wind`` says DCS has changed."""

#: How far a METAR's station may be from a DCS airfield to be that airfield, m.
_STATION_MATCH_M = 5000.0

#: The sources of a reference airfield, in the order they are tried.
SOURCE_STATION = "metar_station"
SOURCE_EXPLICIT = "reference_airfield"
SOURCE_DEPARTURE = "departure"
SOURCE_SEA_LEVEL = "sea_level"

_PLAYER_SKILLS = ("client", "player")


@dataclass(frozen=True)
class ReferenceAirfield:
    """The place a mission's wind is set for.

    Attributes:
        name: The airfield's DCS name, or ``"sea level"``.
        elevation: Its altitude above sea level, m.
        source: How it was chosen (``metar_station``, ``reference_airfield``, ``departure``, ``sea_level``).
    """

    name: str
    elevation: float
    source: str

    def as_dict(self) -> dict[str, Any]:
        """The airfield as an answer or a log shows it."""
        return {"name": self.name, "elevation_m": round(self.elevation), "source": self.source}


@dataclass(frozen=True)
class HelicopterPlace:
    """A place a helicopter flies from or through.

    Attributes:
        name: What the place is, as a warning names it (``"Rosh Pina (departure of Hind-1)"``).
        ground_msl: The ground's altitude there, m.
    """

    name: str
    ground_msl: float


@dataclass(frozen=True)
class HelicopterBreach:
    """One breach of the helicopter rule.

    Attributes:
        place: Where.
        peak: The strongest wind 0-600 m above the ground there.
        surface: The surface wind there.
    """

    place: HelicopterPlace
    peak: LayerWind
    surface_knots: float

    def message(self) -> str:
        """The breach in words, with the rule's thresholds."""
        return (
            f"helicopters at {self.place.name}: {self.peak.wind.knots:.0f} kt from {self.peak.wind.from_deg:03.0f}"
            f" at {self.peak.height_agl / FEET:.0f} ft above the ground (surface {self.surface_knots:.0f} kt);"
            f" the rule warns past {HELICOPTER_MAX_KNOTS:.0f} kt or {HELICOPTER_MAX_SHEAR_KNOTS:.0f} kt over the"
            f" surface, 0-{HELICOPTER_BAND_TOP_M:.0f} m above the ground"
        )


def _distance_m(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Great-circle distance, m."""
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dp, dl = p2 - p1, math.radians(lon2 - lon1)
    a = math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return 6371000.0 * 2 * math.asin(math.sqrt(a))


def _station_position(icao: str) -> tuple[float, float] | None:
    """Where an ICAO station is, from avwx's bundled station list (no network)."""
    try:
        from avwx import Station  # noqa: PLC0415

        station = Station.from_icao(icao.strip().upper())
    except Exception:  # noqa: BLE001 — avwx missing or an unknown station: not on the map either way
        return None
    if station.latitude is None or station.longitude is None:
        return None
    return float(station.latitude), float(station.longitude)


def _airfield(theatre: str | None, name: str) -> dict[str, Any] | None:
    """A theatre's airfield by name (case-insensitive), with its elevation, or None."""
    wanted = name.strip().lower()
    for airfield in airfields_for_theatre(theatre or ""):
        if airfield["name"].lower() == wanted and airfield.get("elevation") is not None:
            return airfield
    return None


def station_airfield(theatre: str | None, icao: str | None) -> dict[str, Any] | None:
    """The airfield of the map a METAR's station is, if it is one.

    Args:
        theatre: The mission's theatre.
        icao: The METAR's station.

    Returns:
        The airfield (``airfields_for_theatre`` record) within 5 km of the station, or None.
    """
    if not theatre or not icao:
        return None
    position = _station_position(icao)
    if position is None:
        return None
    best: tuple[float, dict[str, Any]] | None = None
    for airfield in airfields_for_theatre(theatre):
        if airfield.get("elevation") is None:
            continue
        distance = _distance_m(position[0], position[1], float(airfield["lat"]), float(airfield["lon"]))
        if distance <= _STATION_MATCH_M and (best is None or distance < best[0]):
            best = (distance, airfield)
    return best[1] if best else None


def resolve_reference_airfield(
    theatre: str | None,
    *,
    station: str | None = None,
    reference_airfield: str | None = None,
    departure_airfield: str | None = None,
) -> tuple[ReferenceAirfield, list[str]]:
    """Choose the place a mission's wind is set for (PRD D2).

    Args:
        theatre: The mission's theatre.
        station: The METAR's station, if the wind comes from one.
        reference_airfield: The airfield the author named.
        departure_airfield: The mission's first player departure airfield.

    Returns:
        The airfield, and warnings: a named airfield not found on the map, or sea level used.
    """
    warnings: list[str] = []
    found = station_airfield(theatre, station)
    if found:
        return ReferenceAirfield(found["name"], float(found["elevation"]), SOURCE_STATION), warnings
    if reference_airfield:
        found = _airfield(theatre, reference_airfield)
        if found:
            return ReferenceAirfield(found["name"], float(found["elevation"]), SOURCE_EXPLICIT), warnings
        warnings.append(f"reference_airfield {reference_airfield!r} is not an airfield of {theatre or 'the map'}")
    if departure_airfield:
        found = _airfield(theatre, departure_airfield)
        if found:
            return ReferenceAirfield(found["name"], float(found["elevation"]), SOURCE_DEPARTURE), warnings
    warnings.append(
        "no reference airfield (METAR station on the map, reference_airfield, or player departure): the wind"
        " is set for sea level, and blows stronger over any inland airfield"
    )
    return ReferenceAirfield("sea level", 0.0, SOURCE_SEA_LEVEL), warnings


def _groups(content: Mapping[str, Any], categories: tuple[str, ...]) -> Iterator[dict[str, Any]]:
    """Every group of the given categories (``plane``, ``helicopter``...) of a mission table."""
    for side in (content.get("coalition") or {}).values():
        if not isinstance(side, Mapping):
            continue
        countries = side.get("country") or []
        for country in countries.values() if isinstance(countries, Mapping) else countries:
            if not isinstance(country, Mapping):
                continue
            for category in categories:
                groups = (country.get(category) or {}).get("group") or []
                for group in groups.values() if isinstance(groups, Mapping) else groups:
                    if isinstance(group, Mapping):
                        yield dict(group)


def _listed(table: Any) -> list[Any]:
    """A Lua array read as a dict or a list, as a list in key order."""
    if isinstance(table, Mapping):
        return [table[key] for key in sorted(table, key=lambda k: int(k) if str(k).isdigit() else 0)]
    return list(table or [])


def _is_player_group(group: Mapping[str, Any]) -> bool:
    return any(str(unit.get("skill", "")).lower() in _PLAYER_SKILLS for unit in _listed(group.get("units")))


def _airdrome_name(theatre: str | None, airdrome_id: Any) -> str | None:
    for airfield in airfields_for_theatre(theatre or ""):
        if airfield["id"] == airdrome_id:
            return str(airfield["name"])
    return None


def first_player_departure(content: Mapping[str, Any], theatre: str | None) -> str | None:
    """The airfield the mission's first player group departs from.

    Args:
        content: The mission table.
        theatre: Its theatre.

    Returns:
        The airfield's DCS name, or None when no player group starts on an airfield.
    """
    for group in _groups(content, ("plane", "helicopter")):
        if not _is_player_group(group):
            continue
        points = _listed((group.get("route") or {}).get("points"))
        if points and points[0].get("airdromeId") is not None:
            name = _airdrome_name(theatre, int(points[0]["airdromeId"]))
            if name:
                return name
    return None


def has_helicopter_slot(content: Mapping[str, Any]) -> bool:
    """Whether a player can fly a helicopter in the mission."""
    return any(_is_player_group(group) for group in _groups(content, ("helicopter",)))


def helicopter_places(
    content: Mapping[str, Any],
    theatre: str | None,
    ground_at: Callable[[float, float], float | None] | None = None,
) -> list[HelicopterPlace]:
    """Where the mission's player helicopters fly: their departure airfields and their route points.

    Args:
        content: The mission table.
        theatre: Its theatre.
        ground_at: The ground's altitude at a mission ``(x, y)``, or None when unknown; a route point
            whose ground is unknown is left out (its departure airfield is still there).

    Returns:
        The places, de-duplicated by name.
    """
    places: dict[str, HelicopterPlace] = {}
    for group in _groups(content, ("helicopter",)):
        if not _is_player_group(group):
            continue
        name = str(group.get("name", "?"))
        for index, point in enumerate(_listed((group.get("route") or {}).get("points"))):
            if point.get("airdromeId") is not None:
                airfield = _airdrome_name(theatre, int(point["airdromeId"]))
                found = _airfield(theatre, airfield) if airfield else None
                if found:
                    label = f"{found['name']} (airfield of {name})"
                    places.setdefault(label, HelicopterPlace(label, float(found["elevation"])))
                    continue
            if ground_at is not None and point.get("x") is not None and point.get("y") is not None:
                ground = ground_at(float(point["x"]), float(point["y"]))
                if ground is not None:
                    label = f"{name} waypoint {index}"
                    places.setdefault(label, HelicopterPlace(label, float(ground)))
    return list(places.values())


def layer_winds(setting: Mapping[str, Any], ground_msl: float) -> list[dict[str, Any]]:
    """The simulated wind by the layers of a briefing, above a place.

    Args:
        setting: The ``.miz``'s ``weather.wind`` table.
        ground_msl: The place's ground altitude, m.

    Returns:
        ``[{layer, height_agl_m, altitude_msl_m, from_deg_true, knots}]``; a flight level under 500 m
        above that ground is left out.
    """
    rows: list[dict[str, Any]] = []
    for name, height in LAYERS_AGL:
        wind = (
            surface_wind(setting, ground_msl)
            if name == SURFACE_LAYER
            else base_wind(setting, ground_msl + height, height)
        )
        rows.append(_row(name, height, ground_msl + height, wind.from_deg, wind.knots))
    for name, altitude in LAYERS_MSL:
        if altitude - ground_msl < 500.0:
            continue
        wind = base_wind(setting, altitude, altitude - ground_msl)
        rows.append(_row(name, altitude - ground_msl, altitude, wind.from_deg, wind.knots))
    return rows


def _row(name: str, height: float, altitude: float, from_deg: float, knots: float) -> dict[str, Any]:
    return {
        "layer": name,
        "height_agl_m": round(height),
        "altitude_msl_m": round(altitude),
        "from_deg_true": round(from_deg) % 360,
        "knots": round(knots),
    }


def helicopter_breaches(setting: Mapping[str, Any], places: list[HelicopterPlace]) -> list[HelicopterBreach]:
    """Apply the helicopter rule (PRD D6) above each place.

    Args:
        setting: The ``.miz``'s ``weather.wind`` table.
        places: Where helicopters fly.

    Returns:
        One breach per place where the wind 0-600 m above the ground exceeds
        :data:`HELICOPTER_MAX_KNOTS`, or the surface wind there by more than
        :data:`HELICOPTER_MAX_SHEAR_KNOTS`.
    """
    breaches: list[HelicopterBreach] = []
    for place in places:
        peak = max_wind_between(setting, place.ground_msl, 0.0, HELICOPTER_BAND_TOP_M)
        surface = surface_wind(setting, place.ground_msl).knots
        if peak.wind.knots > HELICOPTER_MAX_KNOTS or peak.wind.knots - surface > HELICOPTER_MAX_SHEAR_KNOTS:
            breaches.append(HelicopterBreach(place, peak, surface))
    return breaches
