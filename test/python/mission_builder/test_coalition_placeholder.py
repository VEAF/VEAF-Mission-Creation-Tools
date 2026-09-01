"""Tests for coalition_placeholder.ensure_coalitions_populated."""

from __future__ import annotations

import unittest

from mission_builder.coalition_placeholder import ensure_coalitions_populated


def _unit(unit_id: int) -> dict:
    return {"name": f"u{unit_id}", "unitId": unit_id, "type": "M-1 Abrams"}


def _populated_country(group_id: int, unit_id: int) -> dict:
    return {
        "id": 2,
        "name": "USA",
        "vehicle": {"group": [{"name": "g", "groupId": group_id, "units": [_unit(unit_id)]}]},
    }


def _mission(blue_units: bool, red_units: bool) -> dict:
    blue: dict = {"bullseye": {"x": 11.0, "y": 22.0}, "country": []}
    red: dict = {"bullseye": {"x": 33.0, "y": 44.0}, "country": []}
    if blue_units:
        blue["country"].append(_populated_country(100, 200))
    if red_units:
        red["country"].append(
            {"id": 0, "name": "Russia", "vehicle": {"group": [{"groupId": 101, "units": [_unit(201)]}]}}
        )
    return {"coalition": {"blue": blue, "red": red}}


def _placeholder_group(mission: dict, side: str) -> dict | None:
    for country in mission["coalition"][side]["country"]:
        for group in country.get("vehicle", {}).get("group", []):
            if group.get("name") == f"VEAF-placeholder-{side}":
                return group
    return None


class TestEnsureCoalitionsPopulated(unittest.TestCase):
    def test_empty_coalitions_get_placeholders(self) -> None:
        """Both empty sides receive a hidden placeholder; the call reports them."""
        mission = _mission(blue_units=False, red_units=False)
        injected = ensure_coalitions_populated(mission)
        self.assertEqual(sorted(injected), ["blue", "red"])
        for side in ("blue", "red"):
            group = _placeholder_group(mission, side)
            self.assertIsNotNone(group)
            assert group is not None
            self.assertTrue(group["hidden"])
            self.assertEqual(len(group["units"]), 1)

    def test_placeholder_uses_bullseye_position(self) -> None:
        """The placeholder unit and its route sit on the coalition bullseye."""
        mission = _mission(blue_units=False, red_units=True)
        ensure_coalitions_populated(mission)
        group = _placeholder_group(mission, "blue")
        assert group is not None
        self.assertEqual((group["units"][0]["x"], group["units"][0]["y"]), (11.0, 22.0))
        for point in group.get("route", {}).get("points", []):
            self.assertEqual((point["x"], point["y"]), (11.0, 22.0))

    def test_populated_coalition_untouched(self) -> None:
        """A coalition that already has a unit is left alone."""
        mission = _mission(blue_units=True, red_units=True)
        injected = ensure_coalitions_populated(mission)
        self.assertEqual(injected, [])
        self.assertIsNone(_placeholder_group(mission, "blue"))
        self.assertIsNone(_placeholder_group(mission, "red"))

    def test_injected_ids_are_unique(self) -> None:
        """Placeholder group/unit ids do not collide with existing ones."""
        mission = _mission(blue_units=True, red_units=False)  # blue uses 100/200
        ensure_coalitions_populated(mission)
        group = _placeholder_group(mission, "red")
        assert group is not None
        self.assertGreater(group["groupId"], 100)
        self.assertGreater(group["units"][0]["unitId"], 200)

    def test_empty_dict_country_is_coerced(self) -> None:
        """An empty side whose ``country`` is ``{}`` (luadata all_is_dict) must not crash.

        DCS empty Lua tables (`country = {}`) deserialize to a dict, not a list, so
        the placeholder injection used to crash with `'dict' object has no attribute
        'append'`. The country container is coerced to a list.
        """
        mission = {
            "coalition": {
                "blue": {"bullseye": {"x": 1.0, "y": 2.0}, "country": {}},
                "red": {"bullseye": {"x": 3.0, "y": 4.0}, "country": {}},
            }
        }
        injected = ensure_coalitions_populated(mission)
        self.assertEqual(sorted(injected), ["blue", "red"])
        self.assertIsInstance(mission["coalition"]["blue"]["country"], list)
        self.assertIsNotNone(_placeholder_group(mission, "blue"))

    def test_unexpected_country_type_is_handled(self) -> None:
        """A malformed non-list/non-dict ``country`` is coerced to an empty list (with a warning)."""
        mission = {"coalition": {"blue": {"bullseye": {"x": 1.0, "y": 2.0}, "country": "oops"}}}
        injected = ensure_coalitions_populated(mission)
        self.assertEqual(injected, ["blue"])
        self.assertIsInstance(mission["coalition"]["blue"]["country"], list)
        self.assertIsNotNone(_placeholder_group(mission, "blue"))

    def test_roster_valid_country_created(self) -> None:
        """The placeholder is attached to its roster-valid template country."""
        mission = _mission(blue_units=False, red_units=False)
        ensure_coalitions_populated(mission)
        blue_ids = {c["id"] for c in mission["coalition"]["blue"]["country"]}
        red_ids = {c["id"] for c in mission["coalition"]["red"]["country"]}
        self.assertIn(2, blue_ids)  # USA
        self.assertIn(0, red_ids)  # Russia

    def test_placeholder_country_is_assigned_to_its_side(self) -> None:
        """The placeholder's country is also listed in ``coalitions.<side>``.

        FIX-PREPARE-THEATRE-COALITIONS: registering the coalition is the whole point of the
        placeholder, and a country that owns units without appearing in ``coalitions.<side>``
        registers nothing — DCS opens CHANGING COALITIONS and refuses the mission. A blank mission
        (``prepare --theatre``) ships ``coalitions = {blue = {}, red = {}}``, so this is the only
        thing that fills it.
        """
        mission = _mission(blue_units=False, red_units=False)
        mission["coalitions"] = {"blue": {}, "red": {}}
        ensure_coalitions_populated(mission)
        self.assertEqual(mission["coalitions"]["blue"], [2])  # USA
        self.assertEqual(mission["coalitions"]["red"], [0])  # Russia


if __name__ == "__main__":
    unittest.main()


# --------------------------------------------------------------------------------------------
# SECREV-2 / VMR-047 — a Lua sequence reaches Python as a list only while its keys are 1..n with
# no gap. Delete a country or a group in the Mission Editor and the same field comes back as a
# dict keyed by the surviving indexes; iterating that yields the *keys*, so `country.get(...)`
# was called on a string and raised AttributeError.
#
# (The finding also names `_max_ids`, which no longer exists in the module.)
# --------------------------------------------------------------------------------------------


def test_an_indexed_country_table_is_counted_not_crashed_on() -> None:
    from mission_builder.coalition_placeholder import _coalition_unit_count

    coalition = {
        "country": {
            "2": {"vehicle": {"group": [{"units": [{"name": "a"}, {"name": "b"}]}]}},
        }
    }

    assert _coalition_unit_count(coalition) == 2


def test_indexed_group_and_unit_tables_are_counted_too() -> None:
    from mission_builder.coalition_placeholder import _coalition_unit_count

    coalition = {
        "country": {"1": {"vehicle": {"group": {"3": {"units": {"1": {"name": "a"}}}}}}},
    }

    assert _coalition_unit_count(coalition) == 1


def test_a_plain_list_still_works() -> None:
    from mission_builder.coalition_placeholder import _coalition_unit_count

    coalition = {"country": [{"vehicle": {"group": [{"units": [{"name": "a"}]}]}}]}

    assert _coalition_unit_count(coalition) == 1


def test_junk_in_the_tree_counts_as_empty_rather_than_raising() -> None:
    from mission_builder.coalition_placeholder import _coalition_unit_count

    for coalition in ({"country": "not a table"}, {"country": ["a string"]}, {}, {"country": None}):
        assert _coalition_unit_count(coalition) == 0, coalition
