"""`add_air_group` — put a flight on the ramp, resolving its parking from the captured stand data.

`add_player_slot` places one aircraft when the caller already knows the parking spot; this places a
**flight** (one or more aircraft) and **resolves the stands itself** from an airfield name — the
*"put a two-ship of F-16s on the ramp at Incirlik"* case. It reads the bundled parking capture
(``veaf_libs.dcs_parking``), picks free stands the mission does not already occupy, and places each
aircraft at its stand's exact position.

Settled in game on 2026-08-15: a stand's ``parking`` is the capture's ``Term_Index`` and the aircraft
seats correctly from the exact position, with ``parking_id`` set equal to ``parking`` (the editor's own
``parking_id`` is not in the capture and is not load-bearing). Real Caucasus missions park aircraft
only on terminal types **104** and **68**, so those are the stands offered; an airfield with none is
refused rather than seating an aircraft on a runway threshold.

Start types:

- **parking-cold / parking-hot** — resolved stands at ``airfield``; the headline case.
- **runway** — ``TakeOff`` from ``airfield``'s runway; no stand needed, anchored at the field.
- **air** — airborne at ``position``; needs no airfield data at all.
"""

import math
from pathlib import Path
from typing import Any

from mission_tools.group_insertion import add_group as insert_group
from mission_tools.miz_backup import backup_before_write
from mission_tools.miz_tools import read_miz, write_miz
from veaf_libs.dcs_airdromes import airdrome_id_for_name
from veaf_libs.dcs_parking import ParkingStand, aircraft_stands_for_airbase, has_theatre, stands_for_airbase
from veaf_libs.mission_table import indexed

from veaf_mission_mcp.mission_folder import load_folder_mission, save_folder_mission

#: Unit conversions (mission file stores metres and m/s; the caller speaks feet and knots).
_M_PER_FT = 0.3048
_MPS_PER_KT = 0.514444
#: Lateral spacing between airborne units of one flight, in metres.
_AIR_SPACING_M = 60.0

#: The `type`/`action` pair DCS stores per start mode.
_START_WAYPOINT: dict[str, tuple[str, str]] = {
    "air": ("Turning Point", "Turning Point"),
    "runway": ("TakeOff", "From Runway"),
    "parking-cold": ("TakeOffParking", "From Parking Area"),
    "parking-hot": ("TakeOffParkingHot", "From Parking Area Hot"),
}
_PARKING_MODES = ("parking-cold", "parking-hot")


def add_air_group(
    target: Path,
    *,
    coalition: str,
    country_id: int,
    country_name: str,
    name: str,
    unit_type: str,
    count: int = 1,
    start: str = "parking-cold",
    airfield: str | None = None,
    position: dict[str, float] | None = None,
    altitude_ft: float = 15000.0,
    speed_kt: float = 250.0,
    heading_deg: float = 0.0,
    skill: str = "High",
    frequency_mhz: float = 251.0,
    task: str = "CAS",
    parking: list[str] | None = None,
) -> dict[str, Any]:
    """Insert an aircraft flight into a mission, resolving its parking, in place, backed up first.

    Args:
        target: The mission **folder** (durable) or a **`.miz`** (transient).
        coalition: ``"blue"``, ``"red"`` or ``"neutral"``.
        country_id: The DCS numeric country id.
        country_name: The DCS country name (used only if the country is absent in this coalition).
        name: The group's name.
        unit_type: The DCS aircraft type (e.g. ``"F-16C_50"``) — the caller's decision.
        count: How many aircraft in the flight (each gets its own stand for a parking start).
        start: ``"parking-cold"``, ``"parking-hot"``, ``"runway"`` or ``"air"``.
        airfield: The airfield **name** (e.g. ``"Incirlik"``) — required for a parking or runway start;
            resolved to its airdrome id, and to free stands for a parking start.
        position: ``{"x", "y"}`` for an air start.
        altitude_ft: Air-start altitude in feet (ignored on the ground).
        speed_kt: First-leg speed in knots.
        heading_deg: Unit heading in degrees.
        skill: AI level (``"Average"``…``"Excellent"``/``"Random"``), or ``"Client"``/``"Player"`` for
            human slots. Defaults to ``"High"`` — a flight on the ramp is AI unless asked otherwise.
        frequency_mhz: The group's radio frequency in MHz.
        task: The aircraft-group task (default ``"CAS"``).
        parking: Optional explicit stand numbers (one per aircraft) overriding automatic selection.
            When given, it also **sets the flight size** — one aircraft per stand — so it can never
            disagree with ``count``.

    Returns:
        ``{"group_id", "name", "durable", "start", "stands": [...], "airdrome_id"}``.

    Raises:
        ValueError: unknown start; missing airfield/position; unknown airfield or uncaptured theatre;
            not enough free stands; or a requested stand already occupied.
    """
    if start not in _START_WAYPOINT:
        raise ValueError(f"Unknown start {start!r} (expected one of {tuple(_START_WAYPOINT)})")
    if count < 1:
        raise ValueError(f"count must be at least 1, got {count}")

    is_folder = target.is_dir()
    mission = load_folder_mission(target) if is_folder else read_miz(target)
    if mission.mission_content is None:
        raise ValueError(f"Not a valid DCS mission (missing 'mission' content): {target}")
    content = mission.mission_content

    # An explicit parking list is the authority on the flight size, so `count` and the number of
    # stands can never disagree (a mismatch would index past the chosen stands when building units).
    if parking is not None:
        count = len(parking)
        if count < 1:
            raise ValueError("parking list is empty — give at least one stand, or omit it")

    airdrome_id: int | None = None
    stands: list[ParkingStand] = []
    if start in _PARKING_MODES or start == "runway":
        airdrome_id = _resolve_airfield(content, airfield)
        if start in _PARKING_MODES:
            stands = _select_stands(content, airfield, airdrome_id, count, parking)
        else:  # runway: anchor on the field without occupying a stand
            position = _runway_anchor(content, airfield, airdrome_id)

    if start == "air" and (position is None or "x" not in position or "y" not in position):
        raise ValueError("an air start needs a position {x, y}")

    group = _build_air_group(
        name=name,
        unit_type=unit_type,
        count=count,
        start=start,
        stands=stands,
        airdrome_id=airdrome_id,
        position=position,
        altitude_ft=altitude_ft,
        speed_kt=speed_kt,
        heading_deg=heading_deg,
        skill=skill,
        frequency_mhz=frequency_mhz,
        task=task,
    )
    group_id = insert_group(
        content,
        coalition=coalition,
        country_id=country_id,
        country_name=country_name,
        category="plane",
        group=group,
    )

    if is_folder:
        save_folder_mission(mission, target)
    else:
        backup_before_write(target)
        write_miz(mission, target)

    return {
        "group_id": group_id,
        "name": name,
        "durable": is_folder,
        "start": start,
        "airdrome_id": airdrome_id,
        "stands": [s.parking for s in stands],
    }


def _resolve_airfield(content: dict[str, Any], airfield: str | None) -> int:
    """Resolve an airfield name to its airdrome id, raising with the theatre named on failure."""
    if not airfield:
        raise ValueError("a parking or runway start needs an 'airfield' name")
    theatre = str(content.get("theatre") or "")
    airdrome_id = airdrome_id_for_name(theatre, airfield)
    if airdrome_id is None:
        raise ValueError(f"unknown airfield {airfield!r} on theatre {theatre!r} (no id in the airdrome table)")
    return airdrome_id


def _runway_anchor(content: dict[str, Any], airfield: str | None, airdrome_id: int) -> dict[str, float]:
    """Return a position on the field to anchor a runway start (the nearest stand), or raise.

    A runway start does not occupy a stand, but the group still needs a position; the nearest
    aircraft stand is on the field and close to the runway.
    """
    theatre = str(content.get("theatre") or "")
    if not has_theatre(theatre):
        raise ValueError(
            f"no parking data captured for theatre {theatre!r} — a runway start needs the field "
            "position; capture it with 'veaf-tools dcs capture-map --parking'"
        )
    stands = stands_for_airbase(theatre, airdrome_id)
    if not stands:
        raise ValueError(f"airfield {airfield!r} (id {airdrome_id}) has no stands in the capture to anchor on")
    return {"x": stands[0].x, "y": stands[0].y}


def _select_stands(
    content: dict[str, Any], airfield: str | None, airdrome_id: int, count: int, requested: list[str] | None
) -> list[ParkingStand]:
    """Pick `count` aircraft stands at the airbase, avoiding those the mission already occupies.

    Args:
        content: The parsed mission table (to read occupied stands).
        airfield: The airfield name, for error messages.
        airdrome_id: The resolved airdrome id.
        count: How many stands are needed.
        requested: Optional explicit stand numbers to use instead of auto-selection.

    Returns:
        The chosen stands.

    Raises:
        ValueError: uncaptured theatre; no aircraft stands; a requested stand unknown or occupied; or
            not enough free stands for the flight.
    """
    theatre = str(content.get("theatre") or "")
    if not has_theatre(theatre):
        raise ValueError(
            f"no parking data captured for theatre {theatre!r} — capture it with "
            "'veaf-tools dcs capture-map --parking' (see FEAT-MCP-MUTATION-ACTIONS ticket 08)"
        )
    all_stands = aircraft_stands_for_airbase(theatre, airdrome_id)
    if not all_stands:
        raise ValueError(f"airfield {airfield!r} (id {airdrome_id}) has no aircraft parking stands in the capture")
    occupied = _occupied_stands(content, airdrome_id)
    by_number = {s.parking: s for s in all_stands}

    if requested is not None:
        chosen: list[ParkingStand] = []
        for number in requested:
            stand = by_number.get(str(number))
            if stand is None:
                raise ValueError(f"stand {number!r} is not an aircraft parking stand at {airfield!r}")
            if str(number) in occupied:
                raise ValueError(f"stand {number!r} at {airfield!r} is already occupied by {occupied[str(number)]!r}")
            chosen.append(stand)
        return chosen

    free = [s for s in all_stands if s.parking not in occupied]
    if len(free) < count:
        raise ValueError(
            f"airfield {airfield!r} has {len(free)} free aircraft stand(s), fewer than the {count} asked for"
        )
    return free[:count]


def _occupied_stands(content: dict[str, Any], airdrome_id: int) -> dict[str, str]:
    """Return ``{stand number: group name}`` for stands already used at this airbase.

    A stand is occupied when an aircraft group's first waypoint targets this airdrome and one of its
    units declares that ``parking``. Placing a second aircraft there merges them into one another.
    """
    occupied: dict[str, str] = {}
    for coalition in (content.get("coalition") or {}).values():
        if not isinstance(coalition, dict):
            continue
        for country in indexed(coalition.get("country")):
            if not isinstance(country, dict):
                continue
            for category in ("plane", "helicopter"):
                for group in indexed((country.get(category) or {}).get("group")):
                    points = indexed((group.get("route") or {}).get("points"))
                    if not points or points[0].get("airdromeId") != airdrome_id:
                        continue
                    for unit in indexed(group.get("units")):
                        spot = unit.get("parking")
                        if spot is not None:
                            occupied[str(spot)] = str(group.get("name", ""))
    return occupied


def _build_air_group(
    *,
    name: str,
    unit_type: str,
    count: int,
    start: str,
    stands: list[ParkingStand],
    airdrome_id: int | None,
    position: dict[str, float] | None,
    altitude_ft: float,
    speed_kt: float,
    heading_deg: float,
    skill: str,
    frequency_mhz: float,
    task: str,
) -> dict[str, Any]:
    """Build the aircraft group dict (ids are assigned by the shared writer)."""
    speed_mps = float(speed_kt) * _MPS_PER_KT
    heading_rad = math.radians(float(heading_deg) % 360)
    is_parking = start in _PARKING_MODES

    if is_parking:
        anchor = {"x": stands[0].x, "y": stands[0].y}
        alt_m = stands[0].alt
    elif start == "runway":
        # `position` was set to a field anchor by `_runway_anchor`; the aircraft take off from the runway.
        anchor = {"x": position["x"], "y": position["y"]}  # type: ignore[index]
        alt_m = 0.0
    else:  # air
        anchor = {"x": position["x"], "y": position["y"]}  # type: ignore[index]
        alt_m = float(altitude_ft) * _M_PER_FT

    units: list[dict[str, Any]] = []
    for i in range(count):
        if is_parking:
            stand = stands[i]
            ux, uy, ualt = stand.x, stand.y, stand.alt
        else:
            ux, uy, ualt = anchor["x"] + i * _AIR_SPACING_M, anchor["y"], alt_m
        unit: dict[str, Any] = {
            "name": f"{name}-{i + 1}",
            "type": unit_type,
            "x": ux,
            "y": uy,
            "alt": ualt,
            "alt_type": "BARO",
            "heading": heading_rad,
            "speed": speed_mps,
            "skill": skill,
            "onboard_num": f"{10 + i:02d}",
            "payload": {"fuel": 0, "flare": 0, "chaff": 0, "gun": 100, "pylons": {}},
        }
        if is_parking:
            # parking_id equals parking: the editor's own value is not in the capture and, measured
            # 2026-08-15, is not load-bearing given the exact position.
            unit["parking"] = stands[i].parking
            unit["parking_id"] = stands[i].parking
        units.append(unit)

    return {
        "name": name,
        "x": anchor["x"],
        "y": anchor["y"],
        "task": task,
        "communication": True,
        "frequency": frequency_mhz,
        "modulation": 0,
        "radioSet": True,
        "dynSpawnTemplate": False,
        "hidden": False,
        "uncontrolled": False,
        "uncontrollable": False,
        "start_time": 0,
        "units": units,
        "route": {"points": [_build_first_waypoint(anchor, start, alt_m, speed_mps, airdrome_id)]},
    }


def _build_first_waypoint(
    anchor: dict[str, float], start: str, alt_m: float, speed_mps: float, airdrome_id: int | None
) -> dict[str, Any]:
    """Build the first waypoint, whose `type`/`action` pair DCS stores together, ETA locked."""
    wp_type, wp_action = _START_WAYPOINT[start]
    waypoint: dict[str, Any] = {
        "x": anchor["x"],
        "y": anchor["y"],
        "alt": alt_m,
        "alt_type": "BARO",
        "type": wp_type,
        "action": wp_action,
        "speed": speed_mps,
        "ETA": 0,
        "ETA_locked": True,
        "speed_locked": True,
        "formation_template": "",
        "name": "",
        "task": {"id": "ComboTask", "params": {"tasks": {}}},
    }
    if start in _PARKING_MODES or start == "runway":
        waypoint["airdromeId"] = airdrome_id
    return waypoint
