"""Assign a DCS airfield to a coalition in a mission folder (wave 12).

An airfield's coalition lives in the **warehouses** table — `warehouses.airports[<id>].coalition`
(`"BLUE"`/`"RED"`/`"NEUTRAL"`), *not* in `mission.coalition` (which only holds countries and their
groups). Placing a blue unit near a base therefore never turns the base blue. This module edits the
durable warehouses side of a mission folder so a later build produces a `.miz` with the base on the
right side, and turns on its Dynamic Spawn slots at the same time (the build's warehouses injector
then stocks it — see `src/warehouses.yaml`). See `.backlog/FEAT-MCP-AIRBASES-WAREHOUSES/PRD.md`.
"""

import copy
from pathlib import Path
from typing import Any

from mission_builder.warehouses_bootstrap import DEFAULT_AIRPORT
from mission_tools.miz_tools import DcsMission, normalize_warehouses_airports
from veaf_libs.dcs_airdromes import airdrome_id_for_name

from veaf_mission_mcp.mission_folder import load_folder_mission, save_folder_mission

#: Coalition name (lower-case) → the upper-case token DCS stores in `warehouses.airports[id]`.
_COALITIONS: dict[str, str] = {"blue": "BLUE", "red": "RED", "neutral": "NEUTRAL"}


def _airbase_entry(mission: DcsMission, name: str) -> tuple[int, dict[str, Any]]:
    """Lazily resolve/create the `warehouses.airports[<id>]` entry for a named airfield.

    The airfield name is resolved to a numeric airdrome id via the mission's theatre. The
    `warehouses.airports` table is keyed by **int** id (matching the build's warehouses injector);
    a missing entry is created empty (lazy) so a blank mission — whose `airports` is `{}` — works.

    Args:
        mission: The loaded mission (its `theatre_content` drives name resolution).
        name: The airfield display name (e.g. ``"Mezzeh"``), case-insensitive.

    Returns:
        ``(airdrome_id, entry)`` — the resolved id and the (possibly newly-created) airport entry.

    Raises:
        ValueError: when the airfield name is unknown for the mission's theatre.
    """
    theatre = mission.theatre_content or ""
    airdrome_id = airdrome_id_for_name(theatre, name)
    if airdrome_id is None:
        raise ValueError(f"Unknown airfield '{name}' for theatre '{theatre or '?'}'.")

    warehouses = mission.warehouses_content
    if warehouses is None:
        warehouses = {"airports": {}, "warehouses": {}, "weapons": {}}
        mission.warehouses_content = warehouses
    # A mission whose airfields are keyed 1..N hands the table back as a list, and everything below
    # indexes it by airdrome id — `.get()` on a list raises (FIX-WAREHOUSES-LIST-FORM). Loading
    # through `miz_tools` already normalises; this covers a caller that assembled the mission itself.
    normalize_warehouses_airports(warehouses)
    airports: dict[Any, Any] = warehouses.setdefault("airports", {})

    entry = airports.get(airdrome_id)
    if entry is None:
        # The full airfield shape, not just the two keys this action sets: an entry holding only
        # `coalition` and `dynamicSpawn` leaves the airfield unusable — measured in game, its
        # parked slots cannot be taken and its dynamic-slot catalogue shows zero aircraft of every
        # type, fifteen keys being absent (FIX-WAREHOUSES-INCREMENTAL).
        entry = copy.deepcopy(DEFAULT_AIRPORT)
        airports[airdrome_id] = entry
    return airdrome_id, entry


def set_airbase_coalition(folder_path: Path, *, name: str, coalition: str) -> dict[str, Any]:
    """Assign an airfield to a coalition in a mission folder, durably, and enable its dyn slots.

    Writes `warehouses.airports[<id>].coalition` and turns on `dynamicSpawn` for the base (the
    build's warehouses injector then stocks it with the coalition's dynamic templates). Edits the
    exploded `src/mission/` warehouses table in place, backed up first.

    Args:
        folder_path: The mission folder (holds `mission.yaml` + `src/mission/`).
        name: The airfield display name (e.g. ``"Mezzeh"``).
        coalition: ``"blue"``, ``"red"`` or ``"neutral"``.

    Returns:
        ``{airbase, airdrome_id, coalition, dynamic_spawn, durable}``.

    Raises:
        ValueError: when `coalition` is not one of blue/red/neutral, or the airfield is unknown.
        FileNotFoundError: when the folder has no mission.
    """
    key = coalition.strip().lower()
    if key not in _COALITIONS:
        raise ValueError(f"coalition must be one of {sorted(_COALITIONS)}, got '{coalition}'.")

    mission = load_folder_mission(folder_path)
    airdrome_id, entry = _airbase_entry(mission, name)
    entry["coalition"] = _COALITIONS[key]
    entry["dynamicSpawn"] = True
    save_folder_mission(mission, folder_path)

    return {
        "airbase": name,
        "airdrome_id": airdrome_id,
        "coalition": _COALITIONS[key],
        "dynamic_spawn": True,
        "durable": True,
    }
