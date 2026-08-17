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

import luadata
from mission_builder.warehouses_bootstrap import DEFAULT_AIRPORT, ensure_airports_populated
from veaf_libs.dcs_airdromes import airdromes_for_theatre


def _through_luadata(airports: dict[int, dict[str, Any]]) -> Any:
    """Return ``airports`` as the build actually receives it, via a real Lua round-trip.

    Every other test in this file hands `ensure_airports_populated` a dict literal, which is what
    let FIX-WAREHOUSES-LIST-FORM ship: a table read from a `.miz` does not always arrive as a dict.
    Building the fixture through the same serializer/parser pair the build uses is the only way to
    exercise the shape a mission really has.
    """
    text = luadata.serialize(
        {"airports": airports}, indent="  ", indent_level=0, always_provide_keyname=True, sort=True
    )
    return luadata.unserialize(text)["airports"]


def _mission(theatre: str = "Syria", warehouses: dict[str, Any] | None = None) -> dict[str, Any]:
    return {"theatre": theatre, "warehouses": warehouses if warehouses is not None else {"airports": {}}}


class TestPopulatesAnEmptyTable:
    def test_every_airfield_of_the_theatre_gets_an_entry(self) -> None:
        # Counted from the bundled table rather than hard-coded: the number moves when a theatre is
        # re-captured, and what matters is "every airfield", not "225 of them".
        expected = len(set(airdromes_for_theatre("Syria").values()))
        warehouses: dict[str, Any] = {"airports": {}, "warehouses": {}, "weapons": {}}
        added = ensure_airports_populated(warehouses, theatre="Syria")
        assert added == expected
        assert set(warehouses["airports"]) == set(airdromes_for_theatre("Syria").values())

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
        all_ids = set(airdromes_for_theatre("Syria").values())
        warehouses: dict[str, Any] = {"airports": {42: {"coalition": "BLUE", "dynamicSpawn": True}}}
        added = ensure_airports_populated(warehouses, theatre="Syria")
        assert added == len(all_ids) - 1, "every airfield but the one already there"
        assert set(warehouses["airports"]) == all_ids

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
        # The first call is what makes the table complete; the second is the one under test. Both
        # are needed — asserting idempotency on a table nothing has populated proves nothing.
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


class TestATableThatCameFromAMissionFile:
    """A complete mission's airfield table arrives as a **list**, and used to be thrown away.

    Reported by Tripack on 2026-08-17: every base neutral in a mission built with 6.14.2, where the
    same source built with 6.14.0 was fine. Measured on his two `.miz`: the `warehouses` member went
    from 261 KB to 141.7 KB, and its 29 airfields (26 RED, 1 BLUE, 2 NEUTRAL, three carrying an
    aircraft stock) came out as 30 NEUTRAL entries with no stock at all.

    The cause is that `luadata` renders a Lua table whose keys are a contiguous ``1..N`` as a Python
    **list** — which is exactly the shape of a mission declaring every airfield of its theatre. The
    guard here read `not isinstance(airports, dict)` as "absent or malformed" and replaced the
    mission's own table with an empty dict before repopulating it with NEUTRAL defaults.

    Nothing caught it because every test above builds the table as a dict literal, and both in-game
    verifications started from a mission built from scratch — where the table really is empty.
    """

    def test_contiguous_keys_arrive_as_a_list(self) -> None:
        # Not an assertion about our code but about luadata, and the premise of everything below:
        # if this ever stops being true the tests that follow stop testing what they claim to.
        airports = _through_luadata({1: {"coalition": "RED"}, 2: {"coalition": "BLUE"}})
        assert isinstance(airports, list)

    def test_sparse_keys_still_arrive_as_a_dict(self) -> None:
        # The counter-case: a table with a hole keeps its keys, which is why a mission that owns a
        # single airfield never triggered the defect.
        airports = _through_luadata({1: {"coalition": "RED"}, 7: {"coalition": "BLUE"}})
        assert isinstance(airports, dict)

    def test_a_list_shaped_table_keeps_its_coalitions(self) -> None:
        warehouses: dict[str, Any] = {
            "airports": _through_luadata(
                {1: {"coalition": "RED"}, 2: {"coalition": "BLUE"}, 3: {"coalition": "NEUTRAL"}}
            )
        }
        ensure_airports_populated(warehouses, theatre="Syria")
        airports = warehouses["airports"]
        assert airports[1]["coalition"] == "RED", "the mission's own ownership must survive the build"
        assert airports[2]["coalition"] == "BLUE"
        assert airports[3]["coalition"] == "NEUTRAL"

    def test_a_list_shaped_table_keeps_its_stock(self) -> None:
        # Three of Tripack's airfields carried an aircraft stock; all three came back empty.
        stock = {"helicopters": {"UH-1H": {"amount": 10}}}
        warehouses: dict[str, Any] = {
            "airports": _through_luadata({1: {"coalition": "RED", "aircrafts": stock}, 2: {"coalition": "BLUE"}})
        }
        ensure_airports_populated(warehouses, theatre="Syria")
        assert warehouses["airports"][1]["aircrafts"] == stock

    def test_a_list_shaped_table_is_normalised_to_a_dict_keyed_by_id(self) -> None:
        # Keyed by airdrome id is what DCS means and what every other caller assumes; the list is a
        # rendering accident, so it must not survive into the rest of the build.
        warehouses: dict[str, Any] = {"airports": _through_luadata({1: {"coalition": "RED"}})}
        ensure_airports_populated(warehouses, theatre="Syria")
        assert isinstance(warehouses["airports"], dict)
        assert all(isinstance(key, int) for key in warehouses["airports"])

    def test_the_missing_airfields_are_still_added_to_a_list_shaped_table(self) -> None:
        all_ids = set(airdromes_for_theatre("Syria").values())
        warehouses: dict[str, Any] = {"airports": _through_luadata({1: {"coalition": "RED"}})}
        ensure_airports_populated(warehouses, theatre="Syria")
        assert all_ids <= set(warehouses["airports"]), "completion must still happen"

    def test_a_list_shaped_table_survives_a_full_round_trip(self) -> None:
        # The end-to-end guarantee, in the terms of the bug report: serialize what the build would
        # write and read the coalitions back out of the text.
        warehouses: dict[str, Any] = {"airports": _through_luadata({1: {"coalition": "RED"}, 2: {"coalition": "BLUE"}})}
        ensure_airports_populated(warehouses, theatre="Syria")
        text = luadata.serialize(warehouses, indent="  ", indent_level=0, always_provide_keyname=True, sort=True)
        assert 'coalition = "RED"' in text
        assert 'coalition = "BLUE"' in text
