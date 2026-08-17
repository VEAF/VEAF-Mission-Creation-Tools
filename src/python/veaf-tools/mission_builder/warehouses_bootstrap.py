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

from mission_tools.miz_tools import normalize_warehouses_airports
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
    """Add a ``warehouses.airports`` entry for every airfield of the theatre that has none.

    **Completes** the table rather than filling it only when empty. The difference is not academic:
    a mission maker who assigns one airfield to a coalition — what the MCP's `set_airbase_coalition`
    does, and the documented way to own a base — leaves a table with a single entry. An
    "only when empty" rule would then add nothing and ship a mission with 1 airfield out of 225,
    which is the very defect this module exists to prevent.

    An entry that already exists is **never** touched: it carries the mission's own ownership and
    stock settings, and a default would erase them.

    Args:
        warehouses_content: The mission's parsed ``warehouses`` table, mutated in place. A missing
            ``airports`` key is created.
        theatre: The mission's theatre name (e.g. ``"Syria"``), case-insensitive.

    Returns:
        How many airfield entries were added — ``0`` when every airfield already has one, the
        theatre is unknown to the bundled table, or no theatre was given.
    """
    if not theatre:
        return 0

    # A table read from a mission does not always arrive as a dict: `luadata` renders contiguous
    # `1..N` keys as a list, which is what a mission declaring every airfield of its theatre has.
    # Normalising it here rather than treating it as malformed is the whole of FIX-WAREHOUSES-LIST-FORM
    # — the previous `not isinstance(..., dict)` branch discarded the mission's own airfields, their
    # coalitions and their stock. Callers loading through `miz_tools` are normalised already; this
    # keeps a caller that builds the table by hand from re-earning the same bug.
    normalize_warehouses_airports(warehouses_content)

    airports = warehouses_content.get("airports")
    if not isinstance(airports, dict):
        airports = {}
        warehouses_content["airports"] = airports

    # Each airfield gets its own copy: a shared dict would make a later coalition change on one
    # field silently turn every field of the theatre.
    added = 0
    for airdrome_id in sorted(airdromes_for_theatre(theatre).values()):
        entry = airports.get(airdrome_id)
        if entry is None:
            airports[airdrome_id] = copy.deepcopy(DEFAULT_AIRPORT)
            added += 1
        elif isinstance(entry, dict):
            # An entry can exist and still be unusable. `set_airbase_coalition` writes five keys,
            # not twenty, and DCS cannot work an airfield described that thinly: measured in game,
            # its parked slots stay unusable and its dynamic-slot catalogue shows zero aircraft.
            # So a partial entry is completed key by key — never overwritten, since what it does
            # carry is the mission's own decision.
            for key, value in DEFAULT_AIRPORT.items():
                if key not in entry:
                    entry[key] = copy.deepcopy(value)
    return added
