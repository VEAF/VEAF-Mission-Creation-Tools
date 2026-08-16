"""Give a mission the airfield warehouse entries DCS expects (FIX-EMPTY-WAREHOUSES).

A `.miz` carries a `warehouses` table with **one entry per airfield of the theatre**, keyed by
numeric airdrome id. That is where an airfield's coalition and its stock live — not in
`mission.coalition`, which only holds countries and their groups.

A mission built from a blank or scratch-made source has `airports = {}`, and DCS then has no usable
airfield: a player slot parked on a ramp can be selected but never taken (the pilot stays a
spectator), while an air start on the same mission is fine. Measured in game on 2026-08-16, and
invisible everywhere else — `validate` was clean and the build said nothing. Opening the mission in
the DCS Mission Editor and saving it repairs the file, which is why the same mission "works when
launched from the editor": the editor writes the 224 entries the build never did.

This module writes them at build time instead, so a mission that never meets the editor is playable
too. The existing `warehouses_injector` is a different job: it *configures* airports (coalition,
stock, dynamic-slot templates) and skips a mission whose table is empty.
"""

from __future__ import annotations

import copy
from typing import Any

from veaf_libs.dcs_airdromes import airdromes_for_theatre

#: One airfield entry, as the DCS Mission Editor writes it — read off a mission it had just saved
#: (Syria, 224 airfields, every one of them identical to this).
#:
#: `coalition` is **NEUTRAL** for all of them, including fields a mission's units sit on: ownership
#: is decided at runtime, and a mission whose airfields are all neutral flies correctly (the in-game
#: check that closed this defect ran on exactly that). A mission maker who wants a field owned at
#: start declares it in `warehouses.yaml`, or the MCP's `set_airbase_coalition` writes it.
DEFAULT_AIRPORT: dict[str, Any] = {
    "coalition": "NEUTRAL",
    "size": 100,
    "speed": 16.666666,
    "periodicity": 30,
    "suppliers": {},
    "aircrafts": {},
    "weapons": {},
    "unlimitedAircrafts": True,
    "unlimitedFuel": True,
    "unlimitedMunitions": True,
    "dynamicCargo": True,
    "dynamicSpawn": False,
    "allowHotStart": False,
    "OperatingLevel_Air": 10,
    "OperatingLevel_Eqp": 10,
    "OperatingLevel_Fuel": 10,
    "gasoline": {"InitFuel": 100},
    "diesel": {"InitFuel": 100},
    "jet_fuel": {"InitFuel": 100},
    "methanol_mixture": {"InitFuel": 100},
}


def ensure_airports_populated(warehouses_content: dict[str, Any], *, theatre: str) -> int:
    """Fill an empty ``warehouses.airports`` with one entry per airfield of the theatre.

    A table that already holds entries is left completely alone: the mission (or a previous build
    step) knows better than a default, and rewriting it would discard a mission maker's ownership
    and stock settings.

    Args:
        warehouses_content: The mission's parsed ``warehouses`` table, mutated in place. A missing
            ``airports`` key is created.
        theatre: The mission's theatre name (e.g. ``"Syria"``), case-insensitive.

    Returns:
        How many airfield entries were added — ``0`` when the table was already populated, the
        theatre is unknown to the bundled table, or no theatre was given.
    """
    if not theatre:
        return 0

    airports = warehouses_content.get("airports")
    if not isinstance(airports, dict):
        airports = {}
        warehouses_content["airports"] = airports
    if airports:
        return 0

    # Each airfield gets its own copy: a shared dict would make a later coalition change on one
    # field silently turn every field of the theatre.
    for airdrome_id in sorted(airdromes_for_theatre(theatre).values()):
        airports[airdrome_id] = copy.deepcopy(DEFAULT_AIRPORT)
    return len(airports)
