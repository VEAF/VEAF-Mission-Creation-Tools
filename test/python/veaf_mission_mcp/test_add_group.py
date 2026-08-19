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
        result = add_group(
            sample_miz,
            coalition="red",
            country_id=0,
            country_name="Russia",
            category="vehicle",
            name="Red Armor Patrol",
            position={"x": 1000.0, "y": 2000.0},
            units=[{"type": "T-72B", "count": 2}],
        )
        assert result["durable"] is False  # a .miz is the built world (transient)

        described = describe_mission(sample_miz)
        names = {g["name"] for g in described["groups"]}
        assert "Red Armor Patrol" in names

    def test_adds_a_group_durably_to_a_mission_folder(self, tmp_path: Path) -> None:
        # Targeting the exploded src/mission/ writes into the recipe (survives a rebuild) — the way
        # to place a permanent SAM (a `#veafInterpreter["-samLR"]` unit) that isn't lost on build.
        from mission_tools.miz_tools import read_mission_folder

        exploded = tmp_path / "src" / "mission"
        exploded.mkdir(parents=True)
        (exploded / "mission").write_text(
            'mission =\n{\n  ["coalition"] =\n  {\n    ["red"] =\n    {\n'
            '      ["country"] =\n      {\n      },\n    },\n  },\n}\n',
            encoding="utf-8",
        )

        result = add_group(
            tmp_path,  # the mission FOLDER, not a .miz
            coalition="red",
            country_id=0,
            country_name="Russia",
            category="vehicle",
            name="PermanentSAM",
            position={"x": 1.0, "y": 2.0},
            units=[{"type": "T-72B", "count": 1}],
        )
        assert result["durable"] is True

        content = read_mission_folder(tmp_path).mission_content or {}
        assert _find_group(content, "PermanentSAM")  # persisted into src/mission/

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
        # The task list is a list: DCS keys it [1], and the loader iterates it numerically. It used
        # to be written as {"1": ...}, i.e. ["1"] in Lua, which `#tasks` reads as empty.
        last_task = points[-1]["task"]["params"]["tasks"][0]
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
        # An empty list, not an empty dict: the load-time sequence normalisation gives every task
        # table one shape. Both serialise to the same `tasks = {},` (measured), so the mission
        # file is unchanged either way.
        assert group["route"]["points"][-1]["task"]["params"]["tasks"] == []

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

        with pytest.raises(ValueError, match="Not a valid DCS mission"):
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
