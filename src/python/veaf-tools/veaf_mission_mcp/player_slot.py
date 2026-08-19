"""`add_player_slot` — create an aircraft group a human can fly.

`add_group` inserts ground groups; nothing else here creates the one thing a from-scratch mission
needs to be flyable at all — a player slot. Writing one by hand is not a workaround: an aircraft
group's first waypoint carries a `type`/`action` **pair**, a slot must clear `dynSpawnTemplate` (the
flag that made the 2026-08-14 slot un-takeable — it marked the group as a dynamic-spawn template,
which needs an airfield configured for it), and a ground start needs a real parking id DCS refuses to
guess.

Three start modes:

- **air** — position, altitude, speed, heading. Needs no runtime data; the first waypoint is a plain
  ``Turning Point``.
- **ground-cold** / **ground-hot** — the caller supplies the parking spot (``parking`` /
  ``parking_id`` / ``airdrome_id``), and the first waypoint is the matching ``TakeOffParking`` /
  ``TakeOffParkingHot`` pair. This action does **not** resolve airfield parking (that is
  ``FEAT-MCP-MUTATION-ACTIONS`` ticket 09's captured data); a ground start with no spot is refused
  rather than guessed.

The units carry ``skill: "Client"`` — the multiplayer slot skill, which is playable in single-player
too. This action does not touch an existing unit's skill; ``set_unit_properties`` refuses that on
purpose and this is not a back door to it.
"""

import math
from pathlib import Path
from typing import Any

from mission_tools.group_insertion import add_group as insert_group
from mission_tools.group_insertion import air_category_for_type_verbose
from mission_tools.miz_backup import backup_before_write
from mission_tools.miz_tools import read_miz, write_miz

from veaf_mission_mcp.aircraft_payload import build_aircraft_payload
from veaf_mission_mcp.mission_folder import load_folder_mission, save_folder_mission

#: Unit conversions (mission file stores metres and m/s; the caller speaks feet and knots).
_M_PER_FT = 0.3048
_MPS_PER_KT = 0.514444

#: DCS default aircraft-group task for a slot whose AI behaviour does not matter.
_DEFAULT_TASK = "Nothing"

#: The `type`/`action` pair DCS stores per start mode. Writing one without the other is the silent
#: failure this action exists to prevent.
_START_WAYPOINT: dict[str, tuple[str, str]] = {
    "air": ("Turning Point", "Turning Point"),
    "ground-cold": ("TakeOffParking", "From Parking Area"),
    "ground-hot": ("TakeOffParkingHot", "From Parking Area Hot"),
}
_GROUND_MODES = ("ground-cold", "ground-hot")


def add_player_slot(
    target: Path,
    *,
    coalition: str,
    country_id: int,
    country_name: str,
    name: str,
    unit_type: str,
    position: dict[str, float],
    start: str = "air",
    altitude_ft: float = 15000.0,
    speed_kt: float = 250.0,
    heading_deg: float = 0.0,
    parking: str | None = None,
    parking_id: str | None = None,
    airdrome_id: int | None = None,
    frequency_mhz: float = 251.0,
    onboard_num: str = "010",
    task: str = _DEFAULT_TASK,
    fuel: float | None = None,
    fuel_fraction: float | None = None,
) -> dict[str, Any]:
    """Create a flyable player slot in a mission, in place, backed up first.

    Args:
        target: The mission **folder** (durable, exploded ``src/mission/``) or a **`.miz`** (transient).
        coalition: ``"blue"``, ``"red"`` or ``"neutral"``.
        country_id: The DCS numeric country id.
        country_name: The DCS country name (used only if the country is absent in this coalition).
        name: The group's name.
        unit_type: The DCS aircraft type (e.g. ``"A-10C_2"``) — the caller's decision.
        position: The group/unit anchor, ``{"x": ..., "y": ...}``.
        start: ``"air"``, ``"ground-cold"`` or ``"ground-hot"``.
        altitude_ft: Air-start altitude in feet (ignored for a ground start).
        speed_kt: Cruise/first-leg speed in knots.
        heading_deg: Unit heading in degrees (mainly meaningful on the ground).
        parking: The parking-spot number (ground start only), as text so a leading zero survives.
        parking_id: The parking id — its `Term_Index` (ground start only), as text.
        airdrome_id: The airfield id the parking belongs to (ground start only).
        frequency_mhz: The group's radio frequency in MHz — written rather than inherited, since an
            inherited ``communication = false`` was the second defect of the 2026-08-14 slot.
        onboard_num: The tail number, as text so a leading zero survives.
        task: The aircraft-group task (default ``"Nothing"``).
        fuel: Explicit fuel load in KILOGRAMS. Defaults to the type's full internal fuel, read
            from the shipped units database — an air-start slot written with none falls out of
            the sky, and a ground start only hides it because the airfield fuels the aircraft.
        fuel_fraction: Fraction of internal capacity, in ]0, 1] — an alternative to ``fuel``.

    Returns:
        ``{"group_id": <int>, "name": <str>, "durable": <bool>, "start": <str>}``.

    Raises:
        ValueError: If the target is not a valid mission, `start` is unknown, a ground start is
            asked for without a full parking spot, or the fuel load cannot be resolved for this type.
    """
    if start not in _START_WAYPOINT:
        raise ValueError(f"Unknown start {start!r} (expected one of {tuple(_START_WAYPOINT)})")
    if start in _GROUND_MODES and (parking is None or parking_id is None or airdrome_id is None):
        raise ValueError(
            f"A {start} start needs a parking spot: parking, parking_id and airdrome_id. This action does "
            "not resolve airfield parking — that is FEAT-MCP-MUTATION-ACTIONS ticket 09's captured data. "
            "Use an 'air' start, or supply the spot."
        )

    is_folder = target.is_dir()
    mission = load_folder_mission(target) if is_folder else read_miz(target)
    if mission.mission_content is None:
        raise ValueError(f"Not a valid DCS mission (missing 'mission' content): {target}")

    payload, fuel_warning = build_aircraft_payload(unit_type, fuel=fuel, fuel_fraction=fuel_fraction)

    group = _build_slot_group(
        name=name,
        unit_type=unit_type,
        position=position,
        start=start,
        altitude_ft=altitude_ft,
        speed_kt=speed_kt,
        heading_deg=heading_deg,
        parking=parking,
        parking_id=parking_id,
        airdrome_id=airdrome_id,
        frequency_mhz=frequency_mhz,
        onboard_num=onboard_num,
        task=task,
        payload=payload,
    )
    # The category comes from the type, never from a default: a helicopter filed under `plane`
    # is a slot DCS shows with its type in red and refuses to fly, and the mission file gives no
    # sign of it (FIX-MCP-AIRCRAFT-CATEGORY).
    category, category_warning = air_category_for_type_verbose(unit_type)
    group_id = insert_group(
        mission.mission_content,
        coalition=coalition,
        country_id=country_id,
        country_name=country_name,
        category=category,
        group=group,
    )

    if is_folder:
        save_folder_mission(mission, target)
    else:
        backup_before_write(target)
        write_miz(mission, target)

    result: dict[str, Any] = {
        "group_id": group_id,
        "name": name,
        "durable": is_folder,
        "start": start,
        "category": category,
    }
    warnings = [w for w in (category_warning, fuel_warning) if w]
    if warnings:
        result["warnings"] = warnings
    return result


def _build_slot_group(
    *,
    name: str,
    unit_type: str,
    position: dict[str, float],
    start: str,
    altitude_ft: float,
    speed_kt: float,
    heading_deg: float,
    parking: str | None,
    parking_id: str | None,
    airdrome_id: int | None,
    frequency_mhz: float,
    onboard_num: str,
    task: str,
    payload: dict[str, Any],
) -> dict[str, Any]:
    """Build the aircraft group dict for a player slot (ids are assigned by the shared writer)."""
    is_ground = start in _GROUND_MODES
    alt_m = 0.0 if is_ground else float(altitude_ft) * _M_PER_FT
    speed_mps = float(speed_kt) * _MPS_PER_KT
    heading_rad = math.radians(float(heading_deg) % 360)

    unit: dict[str, Any] = {
        "name": f"{name}-1",
        "type": unit_type,
        "x": position["x"],
        "y": position["y"],
        "alt": alt_m,
        "alt_type": "BARO",
        "heading": heading_rad,
        "speed": speed_mps,
        "skill": "Client",
        "onboard_num": onboard_num,
        "payload": payload,
    }
    if is_ground:
        unit["parking"] = parking
        unit["parking_id"] = parking_id

    return {
        "name": name,
        "x": position["x"],
        "y": position["y"],
        "task": task,
        "communication": True,
        "frequency": frequency_mhz,
        "modulation": 0,
        "radioSet": True,
        # The flag that broke the 2026-08-14 slot: true marks a dynamic-spawn template, absent from
        # the slot list unless the airfield is configured for it. A slot is never a template.
        "dynSpawnTemplate": False,
        "hidden": False,
        "uncontrolled": False,
        "uncontrollable": False,
        "start_time": 0,
        "units": [unit],
        "route": {"points": [_build_first_waypoint(position, start, alt_m, speed_mps, airdrome_id)]},
    }


def _build_first_waypoint(
    position: dict[str, float], start: str, alt_m: float, speed_mps: float, airdrome_id: int | None
) -> dict[str, Any]:
    """Build the first waypoint, whose `type`/`action` pair DCS stores together."""
    wp_type, wp_action = _START_WAYPOINT[start]
    waypoint: dict[str, Any] = {
        "x": position["x"],
        "y": position["y"],
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
    if start in _GROUND_MODES:
        waypoint["airdromeId"] = airdrome_id
    return waypoint
