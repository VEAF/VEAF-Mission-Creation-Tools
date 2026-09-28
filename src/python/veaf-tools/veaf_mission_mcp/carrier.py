"""`add_carrier_group` — place a carrier group ready for flight operations.

Nothing placed a working carrier (FIX-OPEN-TRAINING-PROMPT-FINDINGS ticket 02): `edit_route` had no
ICLS, Link 4 nor ACLS, no aircraft could start on a deck, and nothing wrote a ship's warehouse, so
the GermanyCW-v6 mission copied the Caucasus v5 `CSG-74 Stennis`, its tanker, its rescue helicopter
and its warehouse entry by script.

Every shape below is the one the missions under ``D:\\dev\\_VEAF`` carry (measured 2026-09-28):

- the ATC actions of 218 carrier groups: ``ActivateBeacon`` (TACAN, ``system`` 3 on a ship),
  ``ActivateICLS`` (``type`` 131584), ``ActivateLink4`` (frequency in hertz) and ``ActivateACLS``,
  each naming the carrier's ``unitId``;
- **where** they are stored is split: 120 groups keep them in the group's own ``tasks`` table, 55 on
  the first route point, 43 in both. ``veafCarrierOperations`` reads the group's ``tasks`` (for the
  ATC information it gives pilots) and the first route point is where the Mission Editor puts them
  today. Which of the two DCS itself runs has not been measured, so both are written;
- the tower frequency is the carrier **unit's** ``frequency`` (hertz) and ``modulation``;
- ``veafCarrierOperations`` looks for a group **and** unit named ``<carrier unit> S3B-Tanker`` and
  ``<carrier unit> Pedro`` (``veafCarrierOperations.lua``); it destroys them at start and respawns
  them on its own route when operations begin, so their placement here only has to be valid.

Deck slots are ``add_air_group`` with ``start: deck-cold`` or ``deck-hot``.
"""

import math
from pathlib import Path
from typing import Any

from mission_tools.group_insertion import add_group as insert_group
from mission_tools.group_insertion import max_ids
from veaf_libs.dcs_units_data import get_unit_attributes

from veaf_mission_mcp.add_air_group import insert_air_group_into_content
from veaf_mission_mcp.add_farp import _default_warehouse
from veaf_mission_mcp.edit_route import (
    _TACAN_SYSTEM_AIR,
    _TACAN_SYSTEM_SHIP,
    _build_tanker,
    _tacan_frequency_hz,
    _wrapped,
)
from veaf_mission_mcp.mission_folder import commit_mission, open_mission
from veaf_mission_mcp.mission_table import find_group, indexed, unit_names

#: The carrier types `veafCarrierOperations.AllCarriers` knows — the only ones it runs operations for.
CARRIER_TYPES: tuple[str, ...] = (
    "Stennis",
    "CVN_71",
    "CVN_72",
    "CVN_73",
    "CVN_75",
    "Forrestal",
    "LHA_Tarawa",
    "KUZNECOW",
    "CV_1143_5",
)

#: `ActivateICLS`'s `type`, as all 99 of them carry it.
_ICLS_TYPE = 131584

#: A ship attribute meaning an arrested-landing deck, where Link 4 and ACLS serve.
_ARRESTED_DECK = "AircraftCarrier With Arresting Gear"

_M_PER_NM = 1852.0
_MPS_PER_KT = 0.514444
#: How far the group's second waypoint lies ahead, so it sails on its heading.
_LEG_NM = 50.0
#: Escorts ride this far from the carrier, one after another on its beam.
_ESCORT_SPACING_M = 1500.0


def add_carrier_group(
    target: Path,
    *,
    coalition: str,
    country_id: int,
    country_name: str,
    name: str,
    position: dict[str, float],
    heading_deg: float = 0.0,
    speed_kt: float = 15.0,
    carrier_type: str = "Stennis",
    carrier_name: str | None = None,
    escorts: list[str] | None = None,
    tower_mhz: float = 127.5,
    tacan_channel: int = 74,
    tacan_callsign: str = "CVN",
    icls_channel: int | None = 1,
    link4_mhz: float | None = 336.0,
    recovery_tanker: bool = True,
    tanker_tacan_channel: int = 64,
    tanker_tacan_callsign: str = "SHL",
    tanker_frequency_mhz: float = 290.0,
    rescue_helicopter: bool = True,
) -> dict[str, Any]:
    """Place a carrier group with its ATC, tanker, rescue helicopter and warehouse, backed up first.

    Args:
        target: The mission folder (durable) or a ``.miz``.
        coalition: ``"blue"``, ``"red"`` or ``"neutral"``.
        country_id: The DCS numeric country id.
        country_name: The DCS country name.
        name: The ship group's name (``"CSG-74 Stennis"``).
        position: ``{"x", "y"}`` of the carrier, DCS local metres, at sea.
        heading_deg: The course the group steams on, true degrees.
        speed_kt: Its speed in knots.
        carrier_type: One of :data:`CARRIER_TYPES`.
        carrier_name: The carrier **unit**'s name, which the tanker and helicopter names derive from;
            the group's name when omitted.
        escorts: Ship types riding with it (``["TICONDEROG", "USS_Arleigh_Burke_IIa"]``).
        tower_mhz: The carrier's radio (AM), in MHz.
        tacan_channel: The carrier's TACAN channel, X mode, 1-126.
        tacan_callsign: Its TACAN Morse identifier, 1-3 letters or digits.
        icls_channel: The ICLS channel, 1-20; ``None`` for none.
        link4_mhz: The Link 4 frequency in MHz, with ACLS, on an arrested-landing deck; ``None`` for
            none. Ignored, with a warning, on a deck with no arresting gear.
        recovery_tanker: Add the ``<carrier> S3B-Tanker`` group.
        tanker_tacan_channel: The tanker's TACAN channel, Y mode.
        tanker_tacan_callsign: Its TACAN identifier.
        tanker_frequency_mhz: Its radio, in MHz.
        rescue_helicopter: Add the ``<carrier> Pedro`` group.

    Returns:
        ``{group, group_id, carrier, carrier_unit_id, tanker, pedro, durable, warnings}``.

    Raises:
        ValueError: On an unknown carrier type, a channel or callsign DCS would refuse, an incomplete
            position, a name already used, or a mission with no warehouses table.
    """
    if carrier_type not in CARRIER_TYPES:
        raise ValueError(f"carrier_type must be one of {', '.join(CARRIER_TYPES)}, got {carrier_type!r}")
    if position.get("x") is None or position.get("y") is None:
        raise ValueError("position must be a complete {x, y}")
    _check_tacan(tacan_channel, tacan_callsign)
    if recovery_tanker:
        _check_tacan(tanker_tacan_channel, tanker_tacan_callsign)
    if icls_channel is not None and not 1 <= icls_channel <= 20:
        raise ValueError(f"ICLS channel must be in 1-20, got {icls_channel}")

    mission, content = open_mission(target)
    warehouses = mission.warehouses_content
    if not isinstance(warehouses, dict):
        raise ValueError(f"the mission has no warehouses table to register the carrier in: {target}")
    unit_name = carrier_name or name
    support = [f"{unit_name} S3B-Tanker"] if recovery_tanker else []
    support += [f"{unit_name} Pedro"] if rescue_helicopter else []
    for taken in (name, *support):
        try:
            find_group(content, taken)
        except ValueError:
            continue
        raise ValueError(f"a group named {taken!r} already exists")
    new_units = [unit_name, *(f"{name} escort {i}" for i in range(1, len(escorts or []) + 1)), *support]
    clashes = sorted(set(new_units) & set(unit_names(content)))
    if clashes:
        raise ValueError(f"unit name(s) already used in the mission: {', '.join(clashes)} — DCS unit names are unique")

    warnings: list[str] = []
    arrested = _ARRESTED_DECK in get_unit_attributes(carrier_type)
    if link4_mhz is not None and not arrested:
        warnings.append(f"a {carrier_type} has no arresting gear: Link 4 and ACLS were not written")
        link4_mhz = None

    x, y = float(position["x"]), float(position["y"])
    heading = math.radians(float(heading_deg) % 360)
    speed_mps = float(speed_kt) * _MPS_PER_KT
    carrier_unit_id = max_ids(content)[1] + 1  # `insert_group` numbers the first unit max + 1
    tasks = _atc_tasks(carrier_unit_id, tacan_channel, tacan_callsign.upper(), icls_channel, link4_mhz)

    units: list[dict[str, Any]] = [
        _ship_unit(carrier_type, unit_name, x, y, heading, tower_mhz),
        *(
            _ship_unit(
                escort_type,
                f"{name} escort {index}",
                x - math.sin(heading) * _ESCORT_SPACING_M * index,
                y + math.cos(heading) * _ESCORT_SPACING_M * index,
                heading,
                tower_mhz,
            )
            for index, escort_type in enumerate(escorts or [], start=1)
        ),
    ]
    leg = _LEG_NM * _M_PER_NM
    group: dict[str, Any] = {
        "name": name,
        "x": x,
        "y": y,
        "visible": False,
        "hidden": False,
        "uncontrollable": False,
        "start_time": 0,
        "tasks": dict(enumerate(tasks, start=1)),
        "units": units,
        "route": {
            "points": [
                _ship_point(x, y, speed_mps, 0.0, True, tasks),
                _ship_point(
                    x + math.cos(heading) * leg,
                    y + math.sin(heading) * leg,
                    speed_mps,
                    # A group held on station (speed 0) never reaches it; its time is then left at 0.
                    leg / speed_mps if speed_mps > 0 else 0.0,
                    False,
                    [],
                ),
            ]
        },
    }
    group_id = insert_group(
        content,
        coalition=coalition.lower(),
        country_id=country_id,
        country_name=country_name,
        category="ship",
        group=group,
    )

    table = warehouses.get("warehouses")
    if not isinstance(table, dict):
        table = dict(enumerate(table, start=1)) if isinstance(table, list) else {}
        warehouses["warehouses"] = table
    table[carrier_unit_id] = _default_warehouse(coalition.lower())

    tanker_name = pedro_name = None
    if recovery_tanker:
        tanker_name = f"{unit_name} S3B-Tanker"
        aft = {"x": x - math.cos(heading) * 5 * _M_PER_NM, "y": y - math.sin(heading) * 5 * _M_PER_NM}
        _add_support(
            content,
            tanker_name,
            "S-3B Tanker",
            aft,
            8000.0,
            250.0,
            "Refueling",
            coalition,
            country_id,
            country_name,
            warnings,
        )
        tanker = find_group(content, tanker_name)
        tanker["frequency"] = float(tanker_frequency_mhz)
        tanker_unit_id = indexed(tanker["units"])[0]["unitId"]
        points = indexed(tanker["route"]["points"])
        points[0]["task"] = {
            "id": "ComboTask",
            "params": {
                "tasks": {
                    1: {**_build_tanker({}), "number": 1, "enabled": True, "auto": False},
                    2: {
                        **_air_tacan(tanker_unit_id, tanker_tacan_channel, tanker_tacan_callsign.upper()),
                        "number": 2,
                        "enabled": True,
                        "auto": False,
                    },
                }
            },
        }
    if rescue_helicopter:
        pedro_name = f"{unit_name} Pedro"
        beam = {"x": x - math.sin(heading) * _M_PER_NM, "y": y + math.cos(heading) * _M_PER_NM}
        _add_support(
            content,
            pedro_name,
            "SH-60B",
            beam,
            250.0,
            100.0,
            "Transport",
            coalition,
            country_id,
            country_name,
            warnings,
        )

    durable = commit_mission(mission, target)["durable"]
    return {
        "group": name,
        "group_id": group_id,
        "carrier": unit_name,
        "carrier_unit_id": carrier_unit_id,
        "tanker": tanker_name,
        "pedro": pedro_name,
        "durable": durable,
        "warnings": warnings,
    }


def _check_tacan(channel: int, callsign: str) -> None:
    """Refuse a TACAN channel or identifier DCS would not accept."""
    if not isinstance(channel, int) or not 1 <= channel <= 126:
        raise ValueError(f"TACAN channel must be an integer in 1-126, got {channel!r}")
    if not 1 <= len(callsign) <= 3 or not callsign.isalnum():
        raise ValueError(f"TACAN callsign must be 1 to 3 letters or digits, got {callsign!r}")


def _atc_tasks(
    unit_id: int, tacan_channel: int, tacan_callsign: str, icls_channel: int | None, link4_mhz: float | None
) -> list[dict[str, Any]]:
    """The carrier's ATC actions, wrapped and numbered, in the order the editor writes them."""
    actions: list[dict[str, Any]] = [
        {
            "id": "ActivateBeacon",
            "params": {
                "type": 4,
                "system": _TACAN_SYSTEM_SHIP,
                "AA": False,
                "unitId": unit_id,
                "modeChannel": "X",
                "channel": tacan_channel,
                "callsign": tacan_callsign,
                "bearing": True,
                "frequency": _tacan_frequency_hz(tacan_channel, "X"),
            },
        }
    ]
    if icls_channel is not None:
        actions.append(
            {"id": "ActivateICLS", "params": {"type": _ICLS_TYPE, "unitId": unit_id, "channel": icls_channel}}
        )
    if link4_mhz is not None:
        actions.append(
            {"id": "ActivateLink4", "params": {"frequency": int(round(link4_mhz * 1_000_000)), "unitId": unit_id}}
        )
        actions.append({"id": "ActivateACLS", "params": {"unitId": unit_id}})
    return [
        {**_wrapped(action), "number": number, "enabled": True, "auto": False}
        for number, action in enumerate(actions, start=1)
    ]


def _air_tacan(unit_id: int, channel: int, callsign: str) -> dict[str, Any]:
    """An airborne TACAN in Y mode, the tanker's, wrapped."""
    return _wrapped(
        {
            "id": "ActivateBeacon",
            "params": {
                "type": 4,
                "system": _TACAN_SYSTEM_AIR["Y"],
                "AA": False,
                "unitId": unit_id,
                "modeChannel": "Y",
                "channel": channel,
                "callsign": callsign,
                "bearing": True,
                "frequency": _tacan_frequency_hz(channel, "Y"),
            },
        }
    )


def _ship_unit(unit_type: str, name: str, x: float, y: float, heading: float, tower_mhz: float) -> dict[str, Any]:
    """One ship unit; its radio in hertz, AM, as the editor stores it."""
    return {
        "type": unit_type,
        "name": name,
        "x": x,
        "y": y,
        "heading": heading,
        "frequency": int(round(tower_mhz * 1_000_000)),
        "modulation": 0,
    }


def _ship_point(
    x: float, y: float, speed_mps: float, eta: float, first: bool, tasks: list[dict[str, Any]]
) -> dict[str, Any]:
    """One ship waypoint, the first carrying the ATC tasks and the locked time."""
    return {
        "x": x,
        "y": y,
        "alt": 0,
        "alt_type": "BARO",
        "type": "Turning Point",
        "action": "Turning Point",
        "speed": speed_mps,
        "ETA": eta,
        "ETA_locked": first,
        "speed_locked": True,
        "formation_template": "",
        "task": {"id": "ComboTask", "params": {"tasks": dict(enumerate(tasks, start=1))}},
    }


def _add_support(
    content: dict[str, Any],
    name: str,
    unit_type: str,
    position: dict[str, float],
    altitude_ft: float,
    speed_kt: float,
    task: str,
    coalition: str,
    country_id: int,
    country_name: str,
    warnings: list[str],
) -> None:
    """Add a one-aircraft support group whose group and unit share `name`, as the script requires."""
    _, extra = insert_air_group_into_content(
        content,
        coalition=coalition.lower(),
        country_id=country_id,
        country_name=country_name,
        name=name,
        unit_type=unit_type,
        count=1,
        position=position,
        altitude_ft=altitude_ft,
        speed_kt=speed_kt,
        task=task,
    )
    warnings.extend(extra)
    indexed(find_group(content, name)["units"])[0]["name"] = name
