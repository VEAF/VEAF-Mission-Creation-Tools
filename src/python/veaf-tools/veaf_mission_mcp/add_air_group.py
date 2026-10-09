"""`add_air_group` — put a flight on the ramp, resolving its parking from the captured stand data.

`add_player_slot` places one aircraft when the caller already knows the parking spot; this places a
**flight** (one or more aircraft) and **resolves the stands itself** from an airfield name — the
*"put a two-ship of F-16s on the ramp at Incirlik"* case. It reads the bundled parking capture
(``veaf_libs.dcs_parking``), picks free stands the mission does not already occupy, and places each
aircraft at its stand's exact position.

Settled in game on 2026-08-15: a stand's ``parking`` is the capture's ``Term_Index`` and the aircraft
seats correctly from the exact position, with ``parking_id`` set equal to ``parking`` (the editor's own
``parking_id`` is not in the capture and is not load-bearing). The stands offered are
``veaf_libs.dcs_parking.AIRCRAFT_STAND_TYPES`` — **68**, **72** and **104**, DCS's own
``FighterAircraft`` mask; an airfield with none of them is refused rather than seating an aircraft on
a runway threshold or a helipad.

Start types:

- **parking-cold / parking-hot** — resolved stands at ``airfield``; the headline case.
- **runway** — ``TakeOff`` from ``airfield``'s runway; no stand needed, anchored at the field.
- **air** — airborne at ``position``; needs no airfield data at all.
- **deck-cold / deck-hot** — on the deck of the ship unit named ``carrier``: the first point is linked
  to it (``linkUnit`` = ``helipadId`` = its unit id, as the 1 817 deck slots of the missions under
  ``D:\\dev\\_VEAF`` carry it) and each aircraft takes the next deck spot number. An aircraft that
  cannot both take off from and land on that deck, by DCS's own declaration, is refused
  (FIX-OPEN-TRAINING-PROMPT-FINDINGS ticket 02).
"""

import math
from pathlib import Path
from typing import Any

from mission_tools.group_insertion import add_group as insert_group
from mission_tools.group_insertion import air_category_for_type_verbose
from mission_tools.miz_backup import backup_before_write
from mission_tools.miz_tools import read_miz, write_miz
from veaf_libs.dcs_airdromes import airdrome_id_for_name
from veaf_libs.dcs_parking import ParkingStand, aircraft_stands_for_airbase, has_theatre, stands_for_airbase
from veaf_libs.dcs_units_data import get_unit_attributes, get_unit_deck_categories
from veaf_libs.mission_table import indexed

from veaf_mission_mcp.aircraft_identity import assign_identities
from veaf_mission_mcp.aircraft_payload import build_aircraft_payload, normalize_pylons, resolve_loadout
from veaf_mission_mcp.edit_route import _build_orbit, _build_set_unlimited_fuel
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
    "deck-cold": ("TakeOffParking", "From Parking Area"),
    "deck-hot": ("TakeOffParkingHot", "From Parking Area Hot"),
}
#: The tasks that need weapons to do anything.
FIGHTING_TASKS: frozenset[str] = frozenset(
    {
        "Escort",
        "CAP",
        "Intercept",
        "Fighter Sweep",
        "CAS",
        "Ground Attack",
        "SEAD",
        "Antiship Strike",
        "Pinpoint Strike",
        "Runway Attack",
    }
)
_PARKING_MODES = ("parking-cold", "parking-hot")
_DECK_MODES = ("deck-cold", "deck-hot")


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
    fuel: float | None = None,
    fuel_fraction: float | None = None,
    late_activation: bool = False,
    pylons: dict[Any, Any] | None = None,
    payload: str | None = None,
    chaff: int | None = None,
    flare: int | None = None,
    carrier: str | None = None,
) -> dict[str, Any]:
    """Insert an aircraft flight into a mission, resolving its parking, in place, backed up first.

    Each aircraft gets the type's default chaff and flare, a callsign and a tail number no other
    aircraft of the mission carries (see :mod:`veaf_mission_mcp.aircraft_identity`).

    Args:
        target: The mission **folder** (durable) or a **`.miz`** (transient).
        coalition: ``"blue"``, ``"red"`` or ``"neutral"``.
        country_id: The DCS numeric country id.
        country_name: The DCS country name (used only if the country is absent in this coalition).
        name: The group's name.
        unit_type: The DCS aircraft type (e.g. ``"F-16C_50"``) — the caller's decision.
        count: How many aircraft in the flight (each gets its own stand for a parking start).
        start: ``"parking-cold"``, ``"parking-hot"``, ``"runway"``, ``"air"``, ``"deck-cold"`` or
            ``"deck-hot"``.
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
        fuel: Explicit fuel load in KILOGRAMS. Defaults to the type's full internal fuel, read from
            the shipped units database.
        fuel_fraction: Fraction of internal capacity, in ]0, 1] — an alternative to ``fuel``.
        late_activation: Mark the group late-activation (a QRA interceptor, an on-demand template);
            it used to take a second call to ``set_group_properties``.
        pylons: The loadout, ``{station: {"CLSID": ...}}`` as the mission file stores it.
        payload: A DCS loadout by the name the Mission Editor lists (``list_payloads``) — an
            alternative to ``pylons``, refused when both are given.
        chaff: Chaff count per aircraft; defaults to the type's Mission Editor default.
        flare: Flare count per aircraft; defaults to the type's Mission Editor default.
        carrier: The ship **unit** name a deck start takes off from.

    Returns:
        ``{"group_id", "name", "durable", "start", "stands": [...], "airdrome_id"}`` — for a deck
        start, ``stands`` are the deck spot numbers.

    Raises:
        ValueError: unknown start; missing airfield/position; unknown airfield or uncaptured theatre;
            not enough free stands; a requested stand already occupied; or a fuel load that cannot
            be resolved for this type.
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
    deck: tuple[dict[str, Any], list[str]] | None = None
    if start in _DECK_MODES:
        if parking is not None:
            raise ValueError("a deck start numbers its spots itself: omit 'parking' and give 'count'")
        deck = _resolve_deck(content, carrier, unit_type, count)
        position = {"x": float(deck[0]["x"]), "y": float(deck[0]["y"])}
    elif start in _PARKING_MODES or start == "runway":
        airdrome_id = _resolve_airfield(content, airfield)
        if start in _PARKING_MODES:
            stands = _select_stands(content, airfield, airdrome_id, count, parking)
        else:  # runway: anchor on the field without occupying a stand
            position = _runway_anchor(content, airfield, airdrome_id)

    if start == "air" and (position is None or "x" not in position or "y" not in position):
        raise ValueError("an air start needs a position {x, y}")

    # Resolved once for the flight -- every aircraft is the same type -- and before the stands are
    # committed, so a bad explicit value fails without having half-written the mission.
    aircraft_payload, fuel_warning = build_aircraft_payload(
        unit_type, fuel=fuel, fuel_fraction=fuel_fraction, chaff=chaff, flare=flare
    )
    loadout = resolve_loadout(unit_type, pylons, payload)
    if loadout:
        aircraft_payload["pylons"] = normalize_pylons(loadout)

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
        payload=aircraft_payload,
        late_activation=late_activation,
    )
    if deck is not None:
        _seat_on_deck(group, *deck)
    afac_note: str | None = None
    if task == "AFAC" and start == "air":
        _make_laser_drone(group, altitude_ft=altitude_ft, speed_kt=speed_kt)
    elif task == "AFAC":
        # The orbit is on the first point: on the ground, that is the airfield the drone leaves.
        afac_note = (
            f"group {name!r} has task AFAC on a {start!r} start: no orbit was written, since the first "
            "point is where it takes off; a laser drone is an air start over its zone"
        )
    callsign_note = assign_identities(content, group, country_id=country_id, task=task)
    # The category comes from the type, never from a default: a helicopter filed under `plane`
    # is a slot DCS shows with its type in red and refuses to fly, and the mission file gives no
    # sign of it (FIX-MCP-AIRCRAFT-CATEGORY).
    category, category_warning = air_category_for_type_verbose(unit_type)
    group_id = insert_group(
        content,
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
        "airdrome_id": airdrome_id,
        "stands": deck[1] if deck is not None else [s.parking for s in stands],
    }
    unarmed = unarmed_warning(name, task, skill, aircraft_payload)
    warnings = [w for w in (category_warning, fuel_warning, callsign_note, unarmed, afac_note) if w]
    if warnings:
        result["warnings"] = warnings
    return result


def unarmed_warning(name: str, task: str, skill: str, payload: dict[str, Any]) -> str | None:
    """Warn about an AI flight given a fighting task and no weapons.

    Eight Syria escort pairs were created with an empty ``pylons`` table and escorted nothing
    (FIX-OPEN-TRAINING-SYRIA-FINDINGS ticket 01). Not a refusal, and silent for a ``Client`` or
    ``Player`` slot: a player arms the aircraft on the ramp.

    Args:
        name: The group's name.
        task: The group's task.
        skill: The group's skill.
        payload: The payload the units carry.

    Returns:
        The warning, or ``None``.
    """
    if task not in FIGHTING_TASKS or skill in ("Client", "Player") or payload.get("pylons"):
        return None
    warning = f"group {name!r} has task {task!r} and no weapons: it will not fight without a loadout"
    return warning


def _make_laser_drone(group: dict[str, Any], *, altitude_ft: float, speed_kt: float) -> None:
    """Give an ``AFAC`` flight the first point of GermanyCW-v6's laser drones, in place.

    Measured in that mission's file (Reaper 1 and 2, 2026-10-02): ``SetUnlimitedFuel``, then a
    ``Circle`` orbit at the group's altitude and speed. The lasing itself is CTLD's, from the drone's
    ``modules.ASSETS`` entry (``jtac``, ``freq``, ``mod``); checked in game on 2026-09-28
    (FIX-OPEN-TRAINING-SYRIA-FINDINGS ticket 06).

    Args:
        group: The flight.
        altitude_ft: The orbit altitude, in feet (CTLD moves the drone to its own altitude anyway).
        speed_kt: The orbit speed, in knots.
    """
    tasks = [
        _build_set_unlimited_fuel({}),
        _build_orbit({"pattern": "Circle", "altitude_ft": altitude_ft, "speed_kt": speed_kt}),
    ]
    entries: dict[int, dict[str, Any]] = {}
    for number, task in enumerate(tasks, start=1):
        task.update({"auto": False, "enabled": True, "number": number})
        entries[number] = task
    # Integer keys: `luadata` renders a string key as ["1"], a different Lua entry DCS ignores.
    group["route"]["points"][0]["task"] = {"id": "ComboTask", "params": {"tasks": entries}}


def _cap_engage_task() -> dict[str, Any]:
    """The `EngageTargets` task the Mission Editor adds to a CAP group, in its own shape.

    Measured on 3 691 CAP groups of the missions under D:\\dev\\_VEAF (2026-09-24): 1 139 of the
    1 147 `EngageTargets` they carry are exactly this, always numbered 1. `auto = true` is what marks
    it as the editor's own, which it is.

    Returns:
        The task entry, without its `number`.
    """
    return {
        "id": "EngageTargets",
        "key": "CAP",
        "enabled": True,
        "auto": True,
        "params": {"targetTypes": {1: "Air"}, "priority": 0},
    }


def insert_air_group_into_content(
    content: dict[str, Any],
    *,
    coalition: str,
    country_id: int,
    country_name: str,
    name: str,
    unit_type: str,
    count: int,
    position: dict[str, float],
    altitude_ft: float = 15000.0,
    speed_kt: float = 350.0,
    skill: str = "High",
    task: str = "CAP",
    late_activation: bool = False,
    pylons: dict[Any, Any] | None = None,
    route: list[dict[str, float]] | None = None,
    start: str = "air",
    airfield: str | None = None,
) -> tuple[int, list[str]]:
    """Insert a flight into a parsed mission table, airborne or on a runway; the composites' aircraft builder.

    `create_qra` and `create_cap_mission` used to build their aircraft with `add_group`'s
    ground-vehicle builder — ``Ground Nothing``, an ``Off Road`` point at altitude 0, 20 km/h, no
    payload, no fuel (FIX-SCRATCH-MISSION-FINDINGS ticket 06). This is the air-start path of
    :func:`add_air_group`, without the I/O.

    Args:
        content: The parsed ``mission`` table to mutate.
        coalition: ``"blue"``, ``"red"`` or ``"neutral"``.
        country_id: The DCS numeric country id.
        country_name: The DCS country name (used only if the country is absent in this coalition).
        name: The group's name.
        unit_type: The DCS aircraft type.
        count: How many aircraft in the flight.
        position: ``{"x", "y"}`` of the air start.
        altitude_ft: Altitude in feet.
        speed_kt: Speed in knots.
        skill: AI level.
        task: The aircraft-group task.
        late_activation: Mark the group late-activation.
        pylons: The loadout, ``{station: {"CLSID": ...}}``.
        route: Further points ``{"x", "y", "altitude_ft"?}``. With one or more, the first point
            carries a race-track orbit towards the second, so a CAP template patrols a line.
        start: ``"air"`` at ``position``, or ``"runway"``: a take-off from ``airfield``'s runway, and
            ``position`` is then ignored (a QRA's default since FIX-CAMPAIGN-MISSION-1-FINDINGS ticket 04).
        airfield: The airfield **name** a runway start takes off from.

    Returns:
        ``(group_id, warnings)``.

    Raises:
        ValueError: an unknown start, or a runway start whose airfield is missing, unknown, or on a
            theatre with no captured parking data — raised before the mission is touched.
    """
    airdrome_id: int | None = None
    if start == "runway":
        airdrome_id = _resolve_airfield(content, airfield)
        position = _runway_anchor(content, airfield, airdrome_id)
    elif start != "air":
        raise ValueError(f"Unknown start {start!r} for this builder (expected 'air' or 'runway')")
    payload, fuel_warning = build_aircraft_payload(unit_type)
    if pylons:
        payload["pylons"] = normalize_pylons(pylons)
    group = _build_air_group(
        name=name,
        unit_type=unit_type,
        count=count,
        start=start,
        stands=[],
        airdrome_id=airdrome_id,
        position=position,
        altitude_ft=altitude_ft,
        speed_kt=speed_kt,
        heading_deg=0.0,
        skill=skill,
        frequency_mhz=251.0,
        task=task,
        payload=payload,
        late_activation=late_activation,
    )
    points = group["route"]["points"]
    first_tasks: list[dict[str, Any]] = []
    if task == "CAP":
        # The editor's CAP task adds this one on its own; without it the template patrols and never
        # engages (ticket 17). First, because a task numbered after an endless orbit is never reached.
        first_tasks.append(_cap_engage_task())
    if route:
        alt_m = float(altitude_ft) * _M_PER_FT
        speed_mps = float(speed_kt) * _MPS_PER_KT
        for point in route:
            leg = _build_first_waypoint({"x": float(point["x"]), "y": float(point["y"])}, "air", alt_m, speed_mps, None)
            if "altitude_ft" in point:
                leg["alt"] = float(point["altitude_ft"]) * _M_PER_FT
            leg["ETA_locked"] = False
            points.append(leg)
        orbit = _build_orbit({"pattern": "Race-Track", "altitude_ft": altitude_ft, "speed_kt": speed_kt})
        orbit.update({"enabled": True, "auto": False})
        first_tasks.append(orbit)
    if first_tasks:
        for number, entry in enumerate(first_tasks, start=1):
            entry["number"] = number
        # Integer keys: `luadata` renders a string key as ["1"], a different Lua entry DCS ignores.
        points[0]["task"] = {
            "id": "ComboTask",
            "params": {"tasks": {number: entry for number, entry in enumerate(first_tasks, start=1)}},
        }
    callsign_note = assign_identities(content, group, country_id=country_id, task=task)
    category, category_warning = air_category_for_type_verbose(unit_type)
    group_id = insert_group(
        content,
        coalition=coalition,
        country_id=country_id,
        country_name=country_name,
        category=category,
        group=group,
    )
    unarmed = unarmed_warning(name, task, skill, payload)
    return group_id, [w for w in (category_warning, fuel_warning, callsign_note, unarmed) if w]


def _mission_groups(content: dict[str, Any], category: str) -> list[dict[str, Any]]:
    """Return every group of one category, both coalitions, every country."""
    groups: list[dict[str, Any]] = []
    for coalition in (content.get("coalition") or {}).values():
        if not isinstance(coalition, dict):
            continue
        for country in indexed(coalition.get("country")):
            if isinstance(country, dict):
                groups.extend(g for g in indexed((country.get(category) or {}).get("group")) if isinstance(g, dict))
    return groups


def _resolve_deck(
    content: dict[str, Any], carrier: str | None, unit_type: str, count: int
) -> tuple[dict[str, Any], list[str]]:
    """Find the ship a deck start takes off from, check the aircraft fits it, and pick deck spots.

    Args:
        content: The parsed mission table.
        carrier: The ship unit's exact name.
        unit_type: The aircraft type.
        count: How many aircraft.

    Returns:
        ``(ship unit, deck spot numbers)`` — the spots continue after the highest one the mission's
        other deck groups of that ship already hold.

    Raises:
        ValueError: No carrier named; no ship unit of that name; or a deck this aircraft cannot both
            take off from and land on.
    """
    if not carrier:
        raise ValueError("a deck start needs 'carrier', the ship unit's name")
    ships = [u for g in _mission_groups(content, "ship") for u in indexed(g.get("units")) if isinstance(u, dict)]
    ship = next((u for u in ships if u.get("name") == carrier), None)
    if ship is None:
        raise ValueError(f"no ship unit named {carrier!r} in the mission (a deck start names the ship's UNIT)")
    attributes = get_unit_attributes(str(ship.get("type", "")))
    takeoff, landing = get_unit_deck_categories(unit_type) or (frozenset(), frozenset())
    if not (takeoff & attributes and landing & attributes):
        raise ValueError(
            f"a {unit_type} cannot use the deck of a {ship.get('type')}: DCS lets it take off from "
            f"{sorted(takeoff) or 'no ship'} and land on {sorted(landing) or 'no ship'}"
        )
    taken = [
        int(unit["parking"])
        for category in ("plane", "helicopter")
        for group in _mission_groups(content, category)
        if (indexed((group.get("route") or {}).get("points")) or [{}])[0].get("linkUnit") == ship.get("unitId")
        for unit in indexed(group.get("units"))
        if str(unit.get("parking", "")).isdigit()
    ]
    first = max(taken, default=0) + 1
    return ship, [str(first + i) for i in range(count)]


def _seat_on_deck(group: dict[str, Any], ship: dict[str, Any], spots: list[str]) -> None:
    """Link a flight built at its ship's position to the ship's deck, in place.

    Args:
        group: The flight.
        ship: The ship unit.
        spots: One deck spot number per aircraft.
    """
    x, y = float(ship["x"]), float(ship["y"])
    group["route"]["points"][0].update(
        {"x": x, "y": y, "alt": 0, "linkUnit": ship.get("unitId"), "helipadId": ship.get("unitId")}
    )
    group.update({"x": x, "y": y})
    for unit, spot in zip(group["units"], spots, strict=True):
        unit.update({"x": x, "y": y, "alt": 0, "parking": spot, "parking_id": spot, "heading": ship.get("heading", 0)})


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
    payload: dict[str, Any],
    late_activation: bool = False,
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
            "payload": dict(payload),
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
        "lateActivation": late_activation,
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
