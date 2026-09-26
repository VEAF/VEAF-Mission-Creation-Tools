"""`add_group` / `create_combat_zone` with `category="static"` or `"ship"` write the editor's shape.

FIX-SCRATCH-MISSION-FINDINGS ticket 06: both went through the ground-vehicle builder. A static got
`task = "Ground Nothing"`, an "Off Road" route, `playerCanDrive`, a skill — and **no `category`** on
its unit, which is what tells DCS what kind of object it is; a ship got "Ground Nothing", an "Off Road"
first point and `playerCanDrive`. GermanyCW-v6 had 23 statics and 2 ship groups patched by hand.

The expected shapes are measured, not assumed: 583 static and 53 ship groups of the missions under
`test/`, and the static categories over 401 missions under `D:\\dev\\_VEAF` (2026-09-24).
"""

from typing import Any

import pytest
from veaf_mission_mcp.add_group import insert_group_into_content


def _content() -> dict[str, Any]:
    return {"coalition": {"blue": {"country": {}}, "red": {"country": {}}}}


def _insert(content: dict[str, Any], category: str, units: list[dict[str, Any]], **extra: Any) -> dict[str, Any]:
    insert_group_into_content(
        content,
        coalition="red",
        country_id=0,
        country_name="Russia",
        category=category,
        name="CZ_Range-target",
        position={"x": 100.0, "y": 200.0},
        units=units,
        **extra,
    )
    countries = content["coalition"]["red"]["country"]
    country = next(iter(countries.values())) if isinstance(countries, dict) else countries[0]
    groups = country[category]["group"]
    return next(iter(groups.values())) if isinstance(groups, dict) else groups[0]


def _units(group: dict[str, Any]) -> list[dict[str, Any]]:
    units = group["units"]
    return list(units.values()) if isinstance(units, dict) else list(units)


def _points(group: dict[str, Any]) -> list[dict[str, Any]]:
    points = group["route"]["points"]
    return list(points.values()) if isinstance(points, dict) else list(points)


class TestStatic:
    def test_the_group_has_the_static_shape(self) -> None:
        group = _insert(_content(), "static", [{"type": "T-55"}])
        assert "task" not in group
        assert group["dead"] is False
        point = _points(group)[0]
        assert (point["type"], point["action"], point["speed"]) == ("", "", 0)

    def test_the_unit_carries_its_category(self) -> None:
        expected = {"T-55": "Armor", "MiG-21Bis": "Planes", ".Command Center": "Fortifications", "Tank": "Warehouses"}
        for unit_type, category in expected.items():
            unit = _units(_insert(_content(), "static", [{"type": unit_type}]))[0]
            assert unit.get("category") == category, unit_type

    def test_the_unit_has_no_vehicle_keys(self) -> None:
        unit = _units(_insert(_content(), "static", [{"type": "T-55"}]))[0]
        for key in ("playerCanDrive", "coldAtStart", "skill"):
            assert key not in unit

    def test_the_unit_is_named_like_its_group(self) -> None:
        """The combat-zone prefix rule reads the static's own name."""
        group = _insert(_content(), "static", [{"type": "T-55"}])
        assert _units(group)[0]["name"] == group["name"]

    def test_an_explicit_unit_name_is_kept(self) -> None:
        group = _insert(_content(), "static", [{"type": "T-55", "name": "CZ_Range-T55 wreck"}])
        assert _units(group)[0]["name"] == "CZ_Range-T55 wreck"

    def test_a_static_is_one_object(self) -> None:
        with pytest.raises(ValueError, match="one object"):
            _insert(_content(), "static", [{"type": "T-55", "count": 2}])

    def test_an_unknown_type_is_reported(self) -> None:
        warnings: list[str] = []
        unit = _units(_insert(_content(), "static", [{"type": "Some-Mod-Crate"}], warnings=warnings))[0]
        assert "category" not in unit
        assert any("Some-Mod-Crate" in w for w in warnings)


class TestShip:
    def test_the_group_has_no_ground_task(self) -> None:
        group = _insert(_content(), "ship", [{"type": "ELNYA"}])
        assert "task" not in group
        assert group["tasks"] == {}

    def test_the_first_point_is_a_turning_point(self) -> None:
        point = _points(_insert(_content(), "ship", [{"type": "ELNYA"}]))[0]
        assert (point["type"], point["action"]) == ("Turning Point", "Turning Point")

    def test_the_units_have_no_vehicle_keys(self) -> None:
        unit = _units(_insert(_content(), "ship", [{"type": "ELNYA"}]))[0]
        for key in ("playerCanDrive", "coldAtStart"):
            assert key not in unit

    def test_late_activation_is_kept(self) -> None:
        """Caught in review: the ship builder hard-coded it off, a carrier activated later spawned at start."""
        group = _insert(_content(), "ship", [{"type": "ELNYA"}], late_activation=True)
        assert group["lateActivation"] is True

    def test_a_patrol_loops_back(self) -> None:
        group = _insert(
            _content(),
            "ship",
            [{"type": "ELNYA"}],
            route=[{"x": 100.0, "y": 200.0}, {"x": 5000.0, "y": 200.0}],
            patrol=True,
        )
        last = _points(group)[-1]
        tasks = last["task"]["params"]["tasks"]
        task = next(iter(tasks.values())) if isinstance(tasks, dict) else tasks[0]
        assert task["id"] == "GoToWaypoint"

    def test_ships_are_not_placed_on_top_of_each_other(self) -> None:
        """Ticket 16: four hulls of 100+ m came out 20 m apart and collided as they spawned."""
        units = _units(_insert(_content(), "ship", [{"type": "Dry-cargo ship-1", "count": 4}]))
        xs = sorted(unit["x"] for unit in units)
        assert min(b - a for a, b in zip(xs, xs[1:], strict=False)) >= 600


class TestVehicleUnchanged:
    def test_vehicles_keep_their_20_metre_spacing(self) -> None:
        units = _units(_insert(_content(), "vehicle", [{"type": "T-55", "count": 3}]))
        assert [unit["x"] for unit in units] == [100.0, 120.0, 140.0]

    def test_a_vehicle_keeps_the_ground_shape(self) -> None:
        group = _insert(_content(), "vehicle", [{"type": "T-55"}])
        assert group["task"] == "Ground Nothing"
        assert _points(group)[0]["action"] == "Off Road"
        assert _units(group)[0]["playerCanDrive"] is True
