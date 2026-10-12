"""Place a complete FARP: the heliport, its radio, and the warehouse that lets it serve.

`add_group` in category `static` placed the object alone — no heliport frequency, no callsign, no
warehouse entry — so no helicopter could rearm or refuel there, and GermanyCW-v6 fell back on
`#veafInterpreter["-farp <name>"]`, a runtime spawn (FIX-SCRATCH-MISSION-FINDINGS ticket 19).

Every value below is measured on the 372 heliports of the missions under D:\\dev\\_VEAF (2026-09-24),
not assumed: see the constants.
"""

import math
from pathlib import Path
from typing import Any

from mission_tools.group_insertion import add_group as insert_group
from mission_tools.group_insertion import max_ids
from veaf_libs.clear_ground_placement import occupied_by, place_on_clear_ground

from veaf_mission_mcp.add_group import insert_group_into_content
from veaf_mission_mcp.add_startup_script_trigger import apply_scenery_removal_trigger
from veaf_mission_mcp.add_trigger_zone import insert_trigger_zone
from veaf_mission_mcp.mission_folder import commit_mission, open_mission
from veaf_mission_mcp.surface import PAD_MAX_DROP_METERS, PAD_RING_METERS, pad_drop, surface_warnings

#: Heliport type -> the `shape_name` the editor writes with it (135, 128, 52, 8 and 2 occurrences).
_SHAPES: dict[str, str] = {
    "FARP": "FARPS",
    "Invisible FARP": "invisiblefarp",
    "SINGLE_HELIPAD": "FARP",
    "FARP_SINGLE_01": "FARP_SINGLE_01",
    "FARP_T": "FARP_T",
}

#: The ammunition dump CTLD takes as a logistic point (`manage_logistics`), and how far east of the
#: pad it goes: 120 m, as GermanyCW-v6 placed it beside each FARP and checked it in game (2026-09-28).
_AMMO_DUMP_TYPE = "FARP Ammo Dump Coating"
_AMMO_DUMP_OFFSET_M = 120.0

#: DCS radio modulation codes.
_MODULATIONS: dict[str, int] = {"AM": 0, "FM": 1}


def add_farp(
    target: Path,
    *,
    name: str,
    position: dict[str, float],
    coalition: str,
    country_id: int,
    country_name: str,
    farp_type: str = "FARP",
    frequency_mhz: float = 127.5,
    modulation: str = "AM",
    callsign_id: int = 1,
    ammo_dump: bool = True,
    keep_position: bool = False,
    clear_scenery_radius: float | None = None,
) -> dict[str, Any]:
    """Place a heliport with its radio and a warehouse entry, backed up first.

    The warehouse is stocked the way the editor's default is (every fuel at 100 %, unlimited fuel,
    munitions and aircraft); `warehouses.yaml`'s ``farps:`` then configures it at build like any other.

    Args:
        target: The mission folder (durable) or a ``.miz``.
        name: The FARP's name — the group's and the heliport's.
        position: ``{"x", "y"}`` in DCS local metres.
        coalition: ``"blue"``, ``"red"`` or ``"neutral"``.
        country_id: The DCS numeric country id.
        country_name: The DCS country name.
        farp_type: One of ``FARP`` (four pads), ``Invisible FARP``, ``SINGLE_HELIPAD``,
            ``FARP_SINGLE_01``, ``FARP_T``.
        frequency_mhz: The heliport's radio, in MHz (127.5, the editor's default, in 288 of 369).
        modulation: ``AM`` or ``FM``.
        callsign_id: The heliport's callsign index, 1-based as the editor lists them.
        ammo_dump: Place a ``FARP Ammo Dump Coating`` static named ``<name> - Ammo``, 120 m east of
            the pad, same coalition and country — CTLD's loading point. Each Syria FARP needed a
            separate call for it (FIX-OPEN-TRAINING-SYRIA-FINDINGS ticket 05).
        keep_position: The position is the mission maker's own: never move the pad. By default a pad
            the clear-ground catalogue finds in trees or buildings is moved, with its dump, onto the
            nearest clear ground within 1 km (FIX-FARP-PLACEMENT ticket 01); kept, it is only warned
            about.
        clear_scenery_radius: Remove the trees within this many metres of the pad, one second after
            mission start: a zone ``<name> - Clear`` and a once-trigger, as the Marianas v5 cleared its
            Tinian FARP (FIX-FARP-PLACEMENT ticket 02). ``None`` (the default) touches no scenery.

    Returns:
        ``{farp, group_id, unit_id, position, durable, ammo_dump?, clear_scenery?, warnings?}`` —
        ``position`` is where the pad went; ``clear_scenery`` is ``{zone, trigger_index}`` when the
        option is set; ``warnings`` when the pad was moved off scenery, stands in it, is on a slope, is in
        the sea, or when the trees or the slope could not be checked.

    Raises:
        ValueError: On an unknown type or modulation, an incomplete position, a radius to clear that
            is not positive, or a mission with no ``warehouses`` table to register the FARP in.
    """
    if farp_type not in _SHAPES:
        raise ValueError(f"farp_type must be one of {', '.join(_SHAPES)}, got {farp_type!r}")
    if modulation.upper() not in _MODULATIONS:
        raise ValueError(f"modulation must be AM or FM, got {modulation!r}")
    if position.get("x") is None or position.get("y") is None:
        raise ValueError("position must be a complete {x, y}")
    if clear_scenery_radius is not None and clear_scenery_radius <= 0:
        raise ValueError(f"clear_scenery_radius must be positive, got {clear_scenery_radius!r}")

    mission, content = open_mission(target)
    warehouses = mission.warehouses_content
    if not isinstance(warehouses, dict):
        raise ValueError(f"the mission has no warehouses table to register the FARP in: {target}")

    x, y = float(position["x"]), float(position["y"])
    theatre = content.get("theatre") or mission.theatre_content
    dump_name = f"{name} - Ammo"
    warnings, (x, y) = _check_pad(content, theatre, name, dump_name if ammo_dump else None, x, y, keep_position)
    unit: dict[str, Any] = {
        "type": farp_type,
        "category": "Heliports",
        "shape_name": _SHAPES[farp_type],
        "name": name,
        "x": x,
        "y": y,
        "heading": 0,
        # A string in the editor's file, "127.5", not a number.
        "heliport_frequency": f"{float(frequency_mhz):g}",
        "heliport_modulation": _MODULATIONS[modulation.upper()],
        "heliport_callsign_id": int(callsign_id),
    }
    group: dict[str, Any] = {
        "name": name,
        "x": x,
        "y": y,
        "heading": 0,
        "dead": False,
        "hidden": False,
        "route": {
            "points": [
                {"x": x, "y": y, "alt": 0, "type": "", "action": "", "speed": 0, "name": "", "formation_template": ""}
            ]
        },
        "units": [unit],
    }
    # `insert_group` works on a copy and numbers its unit max + 1, as computed here.
    unit_id = max_ids(content)[1] + 1
    group_id = insert_group(
        content,
        coalition=coalition.lower(),
        country_id=country_id,
        country_name=country_name,
        category="static",
        group=group,
    )

    table = warehouses.get("warehouses")
    if not isinstance(table, dict):
        table = dict(enumerate(table, start=1)) if isinstance(table, list) else {}
        warehouses["warehouses"] = table
    table[unit_id] = _default_warehouse(coalition.lower())

    warnings += surface_warnings(theatre, [unit], afloat=False)
    if ammo_dump:
        insert_group_into_content(
            content,
            coalition=coalition.lower(),
            country_id=country_id,
            country_name=country_name,
            category="static",
            name=dump_name,
            position={"x": x, "y": y + _AMMO_DUMP_OFFSET_M},
            units=[{"type": _AMMO_DUMP_TYPE, "count": 1}],
            warnings=warnings,
        )
    clear_scenery: dict[str, Any] | None = None
    if clear_scenery_radius is not None:
        zone = f"{name} - Clear"
        zone_id = insert_trigger_zone(content, name=zone, position={"x": x, "y": y}, radius=clear_scenery_radius)
        index = apply_scenery_removal_trigger(content, zone_id=zone_id, comment=f"Clear {name}")
        clear_scenery = {"zone": zone, "trigger_index": index}
    durable = commit_mission(mission, target)["durable"]
    result: dict[str, Any] = {
        "farp": name,
        "group_id": group_id,
        "unit_id": unit_id,
        "position": {"x": x, "y": y},
        "durable": durable,
    }
    if ammo_dump:
        result["ammo_dump"] = dump_name
    if clear_scenery:
        result["clear_scenery"] = clear_scenery
    if warnings:
        # The pad and its dump share a surface verdict when the theatre has no grid: said once.
        result["warnings"] = list(dict.fromkeys(warnings))
    return result


def _check_pad(
    content: dict[str, Any],
    theatre: str | None,
    name: str,
    dump_name: str | None,
    x: float,
    y: float,
    keep_position: bool,
) -> tuple[list[str], tuple[float, float]]:
    """Check a pad for trees and slope, and move it off scenery unless its position is kept.

    « FARP Merizo » went into the Marianas jungle, on a slope, with a warning about the sea only
    (FIX-FARP-PLACEMENT ticket 01).

    Args:
        content: The parsed ``mission`` table, before the FARP is inserted.
        theatre: The mission's theatre.
        name: The FARP's name.
        dump_name: Its ammunition dump's name, or ``None`` when there is none.
        x: Mission ``x`` asked for the pad.
        y: Mission ``y`` asked for the pad.
        keep_position: Never move the pad.

    Returns:
        The warnings, and where the pad goes.
    """
    footprint = [{"x": x, "y": y, "name": name}]
    if dump_name:
        footprint.append({"x": x, "y": y + _AMMO_DUMP_OFFSET_M, "name": dump_name})
    # The coalition only decides what a `#command` marker may draw, and a FARP carries none.
    placement = place_on_clear_ground(theatre, footprint, coalition="neutral", occupied=occupied_by(content))
    warnings: list[str] = []
    unchecked: list[str] = []
    if not placement.covered:
        unchecked.append("trees (no clear-ground catalogue covers this place)")
    elif (placement.dx or placement.dy) and keep_position:
        warnings.append(
            f"'{name}' stands in trees or buildings: the clear-ground catalogue of {theatre} has clear ground "
            f"{math.hypot(placement.dx, placement.dy):.0f} m away; kept where asked (keep_position)"
        )
    elif placement.message:
        x, y = x + placement.dx, y + placement.dy
        warnings.append(
            f"'{name}' {placement.message}" if placement.dx or placement.dy else f"'{name}': {placement.message}"
        )
    spot = f"'.\\veaf-tools.exe dcs farp-spot {theatre} --at {x:.0f},{y:.0f}'"
    drop = pad_drop(theatre, x, y)
    if drop is None:
        unchecked.append(f"slope (no elevation grid for {theatre or 'this theatre'})")
    elif drop > PAD_MAX_DROP_METERS:
        warnings.append(
            f"'{name}' is on a slope: the ground varies by {drop:.1f} m within {PAD_RING_METERS:.0f} m of the pad, "
            f"more than {PAD_MAX_DROP_METERS:.0f} m; find a flat, clear spot in game with {spot}"
        )
    if unchecked:
        warnings.append(
            f"{' and '.join(unchecked)} not checked for '{name}'; find a flat, clear spot in game with {spot}"
        )
    return warnings, (x, y)


def _default_warehouse(coalition: str) -> dict[str, Any]:
    """The warehouse entry the editor writes for a new heliport, measured on 300 of them.

    Args:
        coalition: The coalition, lower case as the editor writes it (292 of 300).

    Returns:
        The entry.
    """
    return {
        "coalition": coalition,
        "unlimitedAircrafts": True,
        "unlimitedFuel": True,
        "unlimitedMunitions": True,
        "dynamicSpawn": False,
        "dynamicCargo": False,
        "allowHotStart": False,
        "OperatingLevel_Air": 10,
        "OperatingLevel_Eqp": 10,
        "OperatingLevel_Fuel": 10,
        "periodicity": 30,
        "size": 100,
        "speed": 16.666666,
        "suppliers": {},
        "jet_fuel": {"InitFuel": 100},
        "gasoline": {"InitFuel": 100},
        "diesel": {"InitFuel": 100},
        "methanol_mixture": {"InitFuel": 100},
        "aircrafts": {},
        "weapons": {},
    }
