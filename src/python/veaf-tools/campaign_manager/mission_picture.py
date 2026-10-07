"""What the built mission says, for its briefing (FEAT-CAMPAIGN-MISSION-BRIEFING ticket 02).

The briefing states what the squadron will find in the mission — flights, support, carrier, QRA,
airfields, date, time, weather, bullseye — read from the **built** `.miz`, after presets and the rest
of the pipeline, never typed. What the prototype got wrong first, and this does not:

- dynamic-slot templates are not flights (`dynSpawnTemplate`), nor are the VEAF spawn templates;
- a support aircraft is listed once, by its task;
- the carrier's tower is VHF;
- DCS stores where the wind blows TO, pilots read where it comes FROM.
"""

from __future__ import annotations

import math
from dataclasses import dataclass, field
from datetime import date
from pathlib import Path
from typing import Any

from mission_tools.mission_yaml_editor import load_yaml
from mission_tools.miz_tools import read_miz
from presets_injector.airfield_channels_manager import list_candidates, load_reference
from veaf_libs.mission_table import indexed
from weather_injector.weather.dcs_weather_converter import _PRESETS_BY_COVERAGE, _RAINY_PRESETS

#: Metres per nautical mile.
NM = 1852.0

#: Knots per metre per second.
KNOTS = 1.943844

#: The cloud covers, by the DCS preset that draws them.
_COVER_OF_PRESET: dict[str, str] = {
    name: cover
    for coverage, cover in ((1, "few"), (2, "scattered"), (3, "broken"), (4, "overcast"))
    for name, _, _ in _PRESETS_BY_COVERAGE[coverage]
}

#: The tankers that fly from a carrier's deck.
_CARRIER_TANKERS = frozenset({"S-3B Tanker"})

#: A group name the VEAF spawn module keeps as a template, never flown as is.
_SPAWN_TEMPLATE_PREFIX = "veafSpawn"

#: How far from its carrier a helicopter's first waypoint makes it the carrier's plane guard, metres.
_PLANE_GUARD_RANGE = 5000.0


@dataclass(frozen=True)
class Flight:
    """A flight the players fly."""

    name: str
    callsign: str
    aircraft: str
    count: int
    base: str | None
    """The carrier or airfield it starts from, ``None`` for an air start."""


@dataclass(frozen=True)
class Support:
    """An AWACS or a tanker."""

    callsign: str
    role: str
    """``awacs``, ``tanker`` or ``carrier_tanker``."""
    aircraft: str
    frequency: float
    """MHz."""
    tacan: str | None
    route: tuple[tuple[float, float], ...]
    """The route's points, mission ``x``/``y``."""


@dataclass(frozen=True)
class Carrier:
    """A carrier of the players' side, with what its pilots need."""

    name: str
    x: float
    y: float
    heading: int
    """Degrees true."""
    tower: float | None
    """VHF, MHz."""
    tacan: str | None
    icls: int | None
    link4: float | None
    """MHz."""


@dataclass(frozen=True)
class Airfield:
    """An airfield of the players' side offering dynamic slots, with DCS's frequencies."""

    name: str
    uhf: float | None
    vhf: float | None
    fm: float | None
    tacan: str | None


@dataclass(frozen=True)
class QraZone:
    """A zone the enemy's interception alert watches."""

    name: str
    x: float
    y: float
    radius: float


@dataclass(frozen=True)
class Wind:
    """One wind layer, as pilots read it."""

    origin: int
    """Where it comes FROM, degrees true, 1 to 360."""
    knots: int


@dataclass(frozen=True)
class Weather:
    """The mission's weather, as a briefing states it."""

    cover: str
    """``clear``, ``few``, ``scattered``, ``broken`` or ``overcast``."""
    cloud_base: float
    """Metres."""
    visibility: float
    """Metres."""
    temperature: float
    qnh: float
    """mmHg, as DCS stores it."""
    winds: dict[str, Wind]
    """By layer: ``ground``, ``2000``, ``8000`` (metres)."""
    rain: bool = False
    fog: bool = False


@dataclass(frozen=True)
class MissionPicture:
    """What the built mission says."""

    theatre: str
    date: date
    start_time: int
    """Seconds since midnight, on the theatre's clock."""
    weather: Weather
    bullseye: tuple[float, float]
    flights: list[Flight] = field(default_factory=list)
    support: list[Support] = field(default_factory=list)
    carriers: list[Carrier] = field(default_factory=list)
    airfields: list[Airfield] = field(default_factory=list)
    qra_zones: list[QraZone] = field(default_factory=list)
    plane_guard: bool = False
    """Whether a carrier has its rescue helicopter."""
    csar: bool = False
    """Whether the mission runs the CSAR module, which rescues ejected pilots."""


def find_built_mission(folder: Path) -> Path | None:
    """The most recently built `.miz` of a mission folder, at its root or in `build/`.

    Args:
        folder: The mission folder.

    Returns:
        The archive, or ``None`` when the mission has not been built.
    """
    found = [*folder.glob("*.miz"), *(folder / "build").glob("*.miz")]
    return max(found, key=lambda path: path.stat().st_mtime) if found else None


def megahertz(value: Any) -> float | None:
    """A DCS frequency in MHz: the mission stores Hz for units and MHz for groups.

    Args:
        value: The stored value.

    Returns:
        MHz, or ``None`` when there is none.
    """
    if not value:
        return None
    number = float(value)
    return round(number / 1e6, 3) if number > 1e5 else number


def callsign(unit: dict[str, Any]) -> str:
    """A unit's callsign as said on the radio: ``Uzi11`` → ``Uzi 1-1``.

    Args:
        unit: The unit's table.

    Returns:
        The callsign, its number split; a numeric callsign as is.
    """
    value = unit.get("callsign")
    if isinstance(value, dict):
        name = str(value.get("name", ""))
        if len(name) > 2 and name[-2:].isdigit():
            return f"{name[:-2]} {name[-2]}-{name[-1]}"
        return name
    return str(value or "")


def _actions(group: dict[str, Any]) -> list[dict[str, Any]]:
    """Every waypoint action of a group's route: beacons, ICLS, Link 4…"""
    found = []
    for point in indexed((group.get("route") or {}).get("points")):
        for task in indexed(((point.get("task") or {}).get("params") or {}).get("tasks")):
            action = (task.get("params") or {}).get("action")
            if isinstance(action, dict):
                found.append(action)
    return found


def _action(group: dict[str, Any], kind: str) -> dict[str, Any] | None:
    for action in _actions(group):
        if action.get("id") == kind:
            return dict(action.get("params") or {})
    return None


def _tacan(group: dict[str, Any]) -> str | None:
    beacon = _action(group, "ActivateBeacon")
    if beacon is None or "channel" not in beacon:
        return None
    return f"{beacon['channel']}{beacon.get('modeChannel', 'X')}"


def _groups(content: dict[str, Any], side: str) -> list[tuple[str, dict[str, Any]]]:
    """Every group of a side that the mission flies as placed, by category."""
    found = []
    for country in indexed(((content.get("coalition") or {}).get(side) or {}).get("country")):
        for category in ("plane", "helicopter", "ship"):
            for group in indexed((country.get(category) or {}).get("group")):
                if group.get("dynSpawnTemplate") or str(group.get("name", "")).startswith(_SPAWN_TEMPLATE_PREFIX):
                    continue
                if indexed(group.get("units")):
                    found.append((category, group))
    return found


def _route(group: dict[str, Any]) -> tuple[tuple[float, float], ...]:
    return tuple((float(p["x"]), float(p["y"])) for p in indexed((group.get("route") or {}).get("points")))


def _weather(raw: dict[str, Any]) -> Weather:
    clouds = raw.get("clouds") or {}
    preset = clouds.get("preset")
    rain = preset in {name for name, _, _ in _RAINY_PRESETS} or bool(clouds.get("iprecptns"))
    if preset:
        cover = _COVER_OF_PRESET.get(str(preset), "overcast")
    else:  # a sky set by density, before the presets
        density = int(clouds.get("density") or 0)
        cover = "clear" if density == 0 else "few" if density <= 2 else "scattered" if density <= 5 else "broken"
    wind = raw.get("wind") or {}
    winds = {}
    for layer, key in (("ground", "atGround"), ("2000", "at2000"), ("8000", "at8000")):
        values = wind.get(key) or {}
        # DCS stores where the wind blows to
        origin = round(float(values.get("dir", 0)) + 180) % 360 or 360
        winds[layer] = Wind(origin=origin, knots=round(float(values.get("speed", 0)) * KNOTS))
    return Weather(
        cover=cover,
        cloud_base=float(clouds.get("base") or 0),
        visibility=float((raw.get("visibility") or {}).get("distance", 0)),
        temperature=float((raw.get("season") or {}).get("temperature", 15)),
        qnh=float(raw.get("qnh", 760)),
        winds=winds,
        rain=rain,
        fog=bool(raw.get("enable_fog")),
    )


def _folder_modules(folder: Path | None) -> dict[str, Any]:
    """The `modules` block of the mission folder's `mission.yaml`, empty without one."""
    if folder is None or not (folder / "mission.yaml").is_file():
        return {}
    modules = load_yaml(folder / "mission.yaml").get("modules")
    return dict(modules) if isinstance(modules, dict) else {}


def _enabled(entry: Any) -> bool:
    """Whether a `modules` entry turns its module on: ``true``, or a block not saying ``enabled: false``."""
    if isinstance(entry, dict):
        return entry.get("enabled", entry.get("enable", True)) is not False
    return bool(entry)


def _qra_zones(content: dict[str, Any], modules: dict[str, Any], player_side: str) -> list[QraZone]:
    """The trigger zones of the enemy's QRA definitions, where the mission has them."""
    qra = modules.get("QRA")
    if not isinstance(qra, dict) or not _enabled(qra):
        return []
    zones = {str(zone.get("name")): zone for zone in indexed((content.get("triggers") or {}).get("zones"))}
    found = []
    for definition in qra.get("definitions") or []:
        if not isinstance(definition, dict) or str(definition.get("coalition", "")).lower() == player_side:
            continue
        zone = zones.get(str(definition.get("trigger_zone")))
        if zone is not None:
            radius = float(definition.get("zone_radius") or zone.get("radius") or 0)
            found.append(QraZone(str(zone["name"]), float(zone["x"]), float(zone["y"]), radius))
    return found


def read_mission_picture(miz: Path, player_side: str, folder: Path | None = None) -> MissionPicture:
    """Read what a built mission says, for its briefing.

    Args:
        miz: The built mission.
        player_side: ``blue`` or ``red``.
        folder: The mission folder, for its QRA definitions and modules; ``None`` to read the `.miz` alone.

    Returns:
        The mission's picture.
    """
    mission = read_miz(miz)
    content = mission.mission_content or {}
    theatre = mission.theatre_content or ""
    reference = load_reference(theatre)
    names = {airdrome_id: str(entry["name"]) for airdrome_id, entry in reference.items()}
    groups = _groups(content, player_side)

    carriers: list[Carrier] = []
    unit_names: dict[int, str] = {}
    for category, group in groups:
        if category != "ship":
            continue
        unit = indexed(group["units"])[0]
        unit_names[int(unit.get("unitId", 0))] = str(unit["name"])
        icls = _action(group, "ActivateICLS")
        link4 = _action(group, "ActivateLink4")
        if _tacan(group) is None and icls is None:
            continue  # an escort, not a carrier
        carriers.append(
            Carrier(
                name=str(unit["name"]),
                x=float(unit["x"]),
                y=float(unit["y"]),
                heading=round(math.degrees(float(unit.get("heading", 0)))) % 360,
                tower=megahertz(unit.get("frequency")),
                tacan=_tacan(group),
                icls=int(icls["channel"]) if icls and "channel" in icls else None,
                link4=megahertz(link4.get("frequency")) if link4 else None,
            )
        )

    flights: list[Flight] = []
    support: list[Support] = []
    plane_guard = False
    for category, group in groups:
        if category == "ship":
            continue
        units = indexed(group["units"])
        first = units[0]
        start = (indexed((group.get("route") or {}).get("points")) or [{}])[0]
        if any(unit.get("skill") in ("Client", "Player") for unit in units):
            if start.get("linkUnit") is not None:
                base: str | None = unit_names.get(int(start["linkUnit"]), None)
            else:
                base = names.get(int(start["airdromeId"])) if start.get("airdromeId") is not None else None
            flights.append(
                Flight(str(group["name"]), callsign(first).rsplit("-", 1)[0], str(first["type"]), len(units), base)
            )
        elif group.get("lateActivation"):
            continue
        elif category == "plane" and group.get("task") in ("AWACS", "Refueling"):
            role = "awacs" if group["task"] == "AWACS" else "tanker"
            if role == "tanker" and first["type"] in _CARRIER_TANKERS:
                role = "carrier_tanker"
            support.append(
                Support(
                    callsign=callsign(first),
                    role=role,
                    aircraft=str(first["type"]),
                    frequency=megahertz(group.get("frequency")) or 0.0,
                    tacan=_tacan(group),
                    route=_route(group),
                )
            )
        elif category == "helicopter" and start and carriers:
            plane_guard = plane_guard or any(
                math.hypot(float(start["x"]) - c.x, float(start["y"]) - c.y) < _PLANE_GUARD_RANGE for c in carriers
            )

    airfields = [
        Airfield(c.name, c.freqs.get("uhf"), c.freqs.get("vhf"), c.freqs.get("fm"), c.tacan)
        for c in list_candidates(mission, {}, {}, reference)
        if c.coalition == player_side and c.dynamic_slots
    ]
    stored = content.get("date") or {}
    bullseye = ((content.get("coalition") or {}).get(player_side) or {}).get("bullseye") or {}
    modules = _folder_modules(folder)
    return MissionPicture(
        theatre=theatre,
        date=date(int(stored.get("Year", 2016)), int(stored.get("Month", 6)), int(stored.get("Day", 1))),
        start_time=int(content.get("start_time") or 0),
        weather=_weather(content.get("weather") or {}),
        bullseye=(float(bullseye.get("x", 0)), float(bullseye.get("y", 0))),
        flights=flights,
        support=support,
        carriers=carriers,
        airfields=sorted(airfields, key=lambda a: a.name),
        qra_zones=_qra_zones(content, modules, player_side),
        plane_guard=plane_guard,
        csar=_enabled(modules.get("CSAR")),
    )
