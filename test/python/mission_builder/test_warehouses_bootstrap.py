"""A mission whose `warehouses.airports` is empty has no usable airfield.

Measured in game on 2026-08-16: a player slot parked at Deir ez-Zor could be selected but never
took — the pilot stayed a spectator — while an air start on the same mission was fine. Diffing our
`.miz` against the same mission opened and saved by the DCS Mission Editor showed the cause was not
in the groups at all: our `warehouses` member was **69 bytes** (`airports = {}`) against the
editor's **179 992**, one entry per airfield of the theatre.

Nothing reported it: `validate` was clean, the build said nothing, and the existing warehouses
injector *configures* airports it finds rather than creating them — it logs "0 airports configured"
and returns, which reads like a mission that simply declared none.
"""

from __future__ import annotations

from typing import Any

from mission_builder.warehouses_bootstrap import DEFAULT_AIRPORT, ensure_airports_populated


def _mission(theatre: str = "Syria", warehouses: dict[str, Any] | None = None) -> dict[str, Any]:
    return {"theatre": theatre, "warehouses": warehouses if warehouses is not None else {"airports": {}}}


class TestPopulatesAnEmptyTable:
    def test_every_airfield_of_the_theatre_gets_an_entry(self) -> None:
        warehouses: dict[str, Any] = {"airports": {}, "warehouses": {}, "weapons": {}}
        added = ensure_airports_populated(warehouses, theatre="Syria")
        assert added == len(warehouses["airports"])
        assert added > 200, "Syria has 224 airfields in the bundled table"

    def test_entries_are_keyed_by_the_numeric_airdrome_id(self) -> None:
        warehouses: dict[str, Any] = {"airports": {}}
        ensure_airports_populated(warehouses, theatre="Syria")
        # 42 is Deir ez-Zor — the field the in-game measurement was made on.
        assert 42 in warehouses["airports"]
        assert all(isinstance(key, int) for key in warehouses["airports"])

    def test_an_entry_carries_the_shape_the_editor_writes(self) -> None:
        # The keys were read off a mission the DCS Mission Editor saved; a partial entry is the kind
        # of thing DCS accepts silently and then behaves oddly about.
        warehouses: dict[str, Any] = {"airports": {}}
        ensure_airports_populated(warehouses, theatre="Syria")
        entry = warehouses["airports"][42]
        assert set(entry) == set(DEFAULT_AIRPORT)
        assert entry["coalition"] == "NEUTRAL"
        assert entry["unlimitedAircrafts"] is True
        assert entry["dynamicSpawn"] is False

    def test_each_airfield_gets_its_own_entry_object(self) -> None:
        # A shared dict would make set_airbase_coalition turn every airfield of the theatre.
        warehouses: dict[str, Any] = {"airports": {}}
        ensure_airports_populated(warehouses, theatre="Syria")
        warehouses["airports"][42]["coalition"] = "BLUE"
        others = [a for aid, a in warehouses["airports"].items() if aid != 42]
        assert all(a["coalition"] == "NEUTRAL" for a in others)


class TestCompletesAPartialTable:
    """A partial table must be COMPLETED, not left alone (FIX-WAREHOUSES-INCREMENTAL).

    The all-or-nothing rule this replaces had a hole the size of the defect it fixed: the moment a
    mission maker assigns one airfield to a coalition — which the MCP's `set_airbase_coalition`
    does, and which is the documented way to own a base — the table stops being empty. The build
    then added nothing, leaving a mission with **1 airfield out of 225** and every other one
    unusable again.
    """

    def test_the_missing_airfields_are_added_beside_an_existing_one(self) -> None:
        warehouses: dict[str, Any] = {"airports": {42: {"coalition": "BLUE", "dynamicSpawn": True}}}
        added = ensure_airports_populated(warehouses, theatre="Syria")
        assert added > 200
        assert len(warehouses["airports"]) == added + 1

    def test_a_partial_entry_gains_the_keys_it_lacks(self) -> None:
        # What set_airbase_coalition leaves behind is FIVE keys, not twenty. DCS cannot work an
        # airfield described that thinly: measured in game, its parked slots stay unusable and its
        # dynamic-slot catalogue shows zero aircraft of every type. "The entry exists" is not
        # "the entry is complete".
        partial: dict[str, Any] = {"coalition": "BLUE", "dynamicSpawn": True}
        warehouses: dict[str, Any] = {"airports": {42: partial}}
        ensure_airports_populated(warehouses, theatre="Syria")
        entry = warehouses["airports"][42]
        assert set(entry) == set(DEFAULT_AIRPORT)
        assert entry["unlimitedAircrafts"] is True

    def test_completing_a_partial_entry_keeps_its_own_values(self) -> None:
        partial: dict[str, Any] = {"coalition": "BLUE", "dynamicSpawn": True, "size": 42}
        warehouses: dict[str, Any] = {"airports": {42: partial}}
        ensure_airports_populated(warehouses, theatre="Syria")
        entry = warehouses["airports"][42]
        assert entry["coalition"] == "BLUE"
        assert entry["dynamicSpawn"] is True
        assert entry["size"] == 42, "a value the mission set must survive completion"

    def test_an_existing_entry_is_never_overwritten(self) -> None:
        # It carries the mission maker's own ownership and stock settings; a default would erase them.
        mine = {"coalition": "BLUE", "dynamicSpawn": True, "aircrafts": {"helicopters": {"UH-1H": {}}}}
        warehouses: dict[str, Any] = {"airports": {42: mine}}
        ensure_airports_populated(warehouses, theatre="Syria")
        assert warehouses["airports"][42] is mine
        assert warehouses["airports"][42]["coalition"] == "BLUE"

    def test_a_complete_table_gains_nothing(self) -> None:
        warehouses: dict[str, Any] = {"airports": {}}
        ensure_airports_populated(warehouses, theatre="Syria")
        assert ensure_airports_populated(warehouses, theatre="Syria") == 0

    def test_a_theatre_with_no_bundled_table_is_a_no_op(self) -> None:
        # An uncaptured or misspelt theatre must not raise mid-build; it simply adds nothing.
        warehouses: dict[str, Any] = {"airports": {}}
        assert ensure_airports_populated(warehouses, theatre="NoSuchTheatre") == 0
        assert warehouses["airports"] == {}

    def test_a_missing_airports_key_is_created(self) -> None:
        warehouses: dict[str, Any] = {}
        assert ensure_airports_populated(warehouses, theatre="Syria") > 0
        assert isinstance(warehouses["airports"], dict)

    def test_no_theatre_is_a_no_op(self) -> None:
        warehouses: dict[str, Any] = {"airports": {}}
        assert ensure_airports_populated(warehouses, theatre="") == 0
