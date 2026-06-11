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

    def test_roster_valid_country_created(self) -> None:
        """The placeholder is attached to its roster-valid template country."""
        mission = _mission(blue_units=False, red_units=False)
        ensure_coalitions_populated(mission)
        blue_ids = {c["id"] for c in mission["coalition"]["blue"]["country"]}
        red_ids = {c["id"] for c in mission["coalition"]["red"]["country"]}
        self.assertIn(2, blue_ids)  # USA
        self.assertIn(0, red_ids)  # Russia


if __name__ == "__main__":
    unittest.main()
