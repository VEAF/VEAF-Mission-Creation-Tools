"""Place a complete FARP: the heliport, its radio, and the warehouse that lets it serve.

`add_group` in category `static` placed the object alone — no heliport frequency, no callsign, no
warehouse entry — so no helicopter could rearm or refuel there, and GermanyCW-v6 fell back on
`#veafInterpreter["-farp <name>"]`, a runtime spawn (FIX-SCRATCH-MISSION-FINDINGS ticket 19).

Every value below is measured on the 372 heliports of the missions under D:\\dev\\_VEAF (2026-09-24),
not assumed: see the constants.
"""

from pathlib import Path
from typing import Any

from mission_tools.group_insertion import add_group as insert_group
from mission_tools.group_insertion import max_ids

from veaf_mission_mcp.mission_folder import commit_mission, open_mission

#: Heliport type -> the `shape_name` the editor writes with it (135, 128, 52, 8 and 2 occurrences).
_SHAPES: dict[str, str] = {
    "FARP": "FARPS",
    "Invisible FARP": "invisiblefarp",
    "SINGLE_HELIPAD": "FARP",
    "FARP_SINGLE_01": "FARP_SINGLE_01",
    "FARP_T": "FARP_T",
}

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

    Returns:
        ``{farp, group_id, unit_id, durable}``.

    Raises:
        ValueError: On an unknown type or modulation, an incomplete position, or a mission with no
            ``warehouses`` table to register the FARP in.
    """
    if farp_type not in _SHAPES:
        raise ValueError(f"farp_type must be one of {', '.join(_SHAPES)}, got {farp_type!r}")
    if modulation.upper() not in _MODULATIONS:
        raise ValueError(f"modulation must be AM or FM, got {modulation!r}")
    if position.get("x") is None or position.get("y") is None:
        raise ValueError("position must be a complete {x, y}")

    mission, content = open_mission(target)
    warehouses = mission.warehouses_content
    if not isinstance(warehouses, dict):
        raise ValueError(f"the mission has no warehouses table to register the FARP in: {target}")

    x, y = float(position["x"]), float(position["y"])
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

    durable = commit_mission(mission, target)["durable"]
    return {"farp": name, "group_id": group_id, "unit_id": unit_id, "durable": durable}


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
