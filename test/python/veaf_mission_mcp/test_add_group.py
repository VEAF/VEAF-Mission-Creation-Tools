from pathlib import Path

import pytest
from mission_tools.miz_tools import read_miz
from veaf_mission_mcp.add_group import add_group
from veaf_mission_mcp.describe_mission import describe_mission


def _find_group(mission_content: dict, name: str) -> dict:
    countries = mission_content["coalition"]["red"]["country"]
    for country in countries:
        for group in country.get("vehicle", {}).get("group", []):
            if group["name"] == name:
                return group
    raise AssertionError(f"Group {name!r} not found")


class TestAddGroup:
    def test_adds_a_group_visible_after_reload(self, sample_miz: Path) -> None:
        add_group(
            sample_miz,
            coalition="red",
            country_id=0,
            country_name="Russia",
            category="vehicle",
            name="Red Armor Patrol",
            position={"x": 1000.0, "y": 2000.0},
            units=[{"type": "T-72B", "count": 2}],
        )

        described = describe_mission(sample_miz)
        names = {g["name"] for g in described["groups"]}
        assert "Red Armor Patrol" in names

    def test_expands_unit_type_count_pairs_into_individual_units(self, sample_miz: Path) -> None:
        add_group(
            sample_miz,
            coalition="red",
            country_id=0,
            country_name="Russia",
            category="vehicle",
            name="Red Armor Patrol",
            position={"x": 1000.0, "y": 2000.0},
            units=[{"type": "T-72B", "count": 2}, {"type": "BTR-80", "count": 1}],
        )

        group = _find_group(read_miz(sample_miz).mission_content, "Red Armor Patrol")
        types = [unit["type"] for unit in group["units"]]
        assert types == ["T-72B", "T-72B", "BTR-80"]

    def test_patrol_loops_the_last_waypoint_back_to_the_first(self, sample_miz: Path) -> None:
        add_group(
            sample_miz,
            coalition="red",
            country_id=0,
            country_name="Russia",
            category="vehicle",
            name="Patrol Group",
            position={"x": 0.0, "y": 0.0},
            units=[{"type": "BTR-80"}],
            route=[{"x": 0.0, "y": 0.0}, {"x": 100.0, "y": 0.0}, {"x": 100.0, "y": 100.0}],
            patrol=True,
        )

        group = _find_group(read_miz(sample_miz).mission_content, "Patrol Group")
        points = group["route"]["points"]
        assert len(points) == 3
        last_task = points[-1]["task"]["params"]["tasks"]["1"]
        assert last_task["id"] == "GoToWaypoint"
        assert last_task["params"] == {"fromWaypoint": 3, "nWaypoint": 1}

    def test_without_patrol_the_route_has_no_loop_task(self, sample_miz: Path) -> None:
        add_group(
            sample_miz,
            coalition="red",
            country_id=0,
            country_name="Russia",
            category="vehicle",
            name="One Way Group",
            position={"x": 0.0, "y": 0.0},
            units=[{"type": "BTR-80"}],
            route=[{"x": 0.0, "y": 0.0}, {"x": 100.0, "y": 0.0}],
        )

        group = _find_group(read_miz(sample_miz).mission_content, "One Way Group")
        assert group["route"]["points"][-1]["task"]["params"]["tasks"] == {}

    def test_backs_up_before_every_write(self, sample_miz: Path) -> None:
        assert list(sample_miz.parent.glob("mission.*.miz")) == []

        add_group(
            sample_miz,
            coalition="red",
            country_id=0,
            country_name="Russia",
            category="vehicle",
            name="Any Group",
            position={"x": 0.0, "y": 0.0},
            units=[{"type": "BTR-80"}],
        )

        assert len(list(sample_miz.parent.glob("mission.*.miz"))) == 1

    def test_calling_twice_creates_two_distinct_groups(self, sample_miz: Path) -> None:
        first = add_group(
            sample_miz,
            coalition="red",
            country_id=0,
            country_name="Russia",
            category="vehicle",
            name="Repeated Group",
            position={"x": 0.0, "y": 0.0},
            units=[{"type": "BTR-80"}],
        )
        second = add_group(
            sample_miz,
            coalition="red",
            country_id=0,
            country_name="Russia",
            category="vehicle",
            name="Repeated Group",
            position={"x": 0.0, "y": 0.0},
            units=[{"type": "BTR-80"}],
        )

        assert first["group_id"] != second["group_id"]
        described = describe_mission(sample_miz)
        matching = [g for g in described["groups"] if g["name"] == "Repeated Group"]
        assert len(matching) == 2

    def test_raises_a_clear_error_when_mission_file_is_missing(self, tmp_path: Path) -> None:
        import zipfile

        miz_path = tmp_path / "empty.miz"
        with zipfile.ZipFile(miz_path, "w") as zf:
            zf.writestr("options", b"options = {\n}\n")

        with pytest.raises(ValueError, match="Not a valid DCS mission archive"):
            add_group(
                miz_path,
                coalition="red",
                country_id=0,
                country_name="Russia",
                category="vehicle",
                name="X",
                position={"x": 0.0, "y": 0.0},
                units=[{"type": "BTR-80"}],
            )
