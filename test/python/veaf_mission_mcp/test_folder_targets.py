"""Tests that the editing actions accept a mission folder, not only a `.miz`.

`FIX-MCP-AUTHORING-GAPS` 03. `add_group` / `add_air_group` / `add_player_slot` always took either, so
a group could be **created** durably but not **edited** durably: `edit_route` pointed at the exploded
folder failed with `[Errno 13] Permission denied`, reading a directory as a zip. That is why
`verify-mission-c`'s tanker and escort routes were hand-written into `src/mission/mission` — the hand
edits every corrupted build of that session came from.
"""

from __future__ import annotations

from pathlib import Path
from typing import Any

import pytest
from mission_tools.miz_tools import read_mission_folder
from veaf_mission_mcp.add_trigger_zone import add_trigger_zone
from veaf_mission_mcp.edit_route import edit_route
from veaf_mission_mcp.edit_zone import edit_zone
from veaf_mission_mcp.map_drawings import add_map_drawing
from veaf_mission_mcp.set_group_properties import set_group_properties
from veaf_mission_mcp.set_unit_properties import set_unit_properties

_MISSION = """mission = {
    ["theatre"] = "Caucasus",
    ["triggers"] = { ["zones"] = { [1] = { ["name"] = "ZoneA", ["x"] = 10, ["y"] = 20, ["radius"] = 500,
        ["type"] = 0, ["color"] = { [1] = 1, [2] = 1, [3] = 1, [4] = 0.15 }, ["properties"] = { },
        ["zoneId"] = 1, ["hidden"] = false, } } },
    ["coalition"] = { ["blue"] = { ["country"] = { [1] = { ["id"] = 2, ["name"] = "USA",
        ["plane"] = { ["group"] = { [1] = {
            ["name"] = "Texaco", ["groupId"] = 1, ["task"] = "Refueling", ["x"] = 0, ["y"] = 0,
            ["units"] = { [1] = { ["name"] = "Texaco-1", ["unitId"] = 1, ["type"] = "KC-135",
                ["x"] = 0, ["y"] = 0, ["alt"] = 6000, ["heading"] = 0, ["skill"] = "High",
                ["payload"] = { ["fuel"] = 90700, ["flare"] = 0, ["chaff"] = 0, ["gun"] = 100,
                    ["pylons"] = { } }, } },
            ["route"] = { ["points"] = { [1] = { ["x"] = 0, ["y"] = 0, ["alt"] = 6000,
                ["type"] = "Turning Point", ["action"] = "Turning Point", ["speed"] = 200,
                ["ETA"] = 0, ["ETA_locked"] = true, ["speed_locked"] = true,
                ["task"] = { ["id"] = "ComboTask", ["params"] = { ["tasks"] = { } } }, } } },
        } } },
    } } }, ["red"] = { ["country"] = { } } },
    ["coalitions"] = { ["blue"] = { [1] = 2 }, ["red"] = { } },
}
"""


@pytest.fixture
def folder(tmp_path: Path) -> Path:
    """A mission folder shaped like the ones the MCP actually edits (`src/mission/mission`)."""
    exploded = tmp_path / "src" / "mission"
    exploded.mkdir(parents=True)
    (exploded / "mission").write_text(_MISSION, encoding="utf-8")
    return tmp_path


def _content(folder: Path) -> dict[str, Any]:
    return read_mission_folder(folder).mission_content or {}


def _group(folder: Path, name: str) -> dict[str, Any]:
    for coalition in _content(folder).get("coalition", {}).values():
        countries = coalition.get("country", {})
        for country in countries.values() if isinstance(countries, dict) else (countries or []):
            groups = (country.get("plane") or {}).get("group") or {}
            for group in groups.values() if isinstance(groups, dict) else groups:
                if group.get("name") == name:
                    return group
    raise AssertionError(f"group {name!r} not found")


def _waypoints(folder: Path, name: str) -> list[dict[str, Any]]:
    points = _group(folder, name)["route"]["points"]
    return list(points.values()) if isinstance(points, dict) else points


class TestEditRouteThroughAFolder:
    """The action the ticket was written from: the tanker track that had to be hand-written."""

    def test_a_waypoint_lands_in_the_folder_source(self, folder: Path) -> None:
        result = edit_route(
            folder,
            group_name="Texaco",
            operation="add",
            position={"x": 5000.0, "y": 6000.0},
            altitude_ft=20000,
            speed_kt=250,
        )
        assert result["durable"] is True
        assert len(_waypoints(folder, "Texaco")) == 2

    def test_the_edit_is_written_to_src_mission_mission(self, folder: Path) -> None:
        # Durable means one specific file on disk, not merely "the action returned success".
        mission_file = folder / "src" / "mission" / "mission"
        before = mission_file.read_text(encoding="utf-8")
        edit_route(
            folder,
            group_name="Texaco",
            operation="add",
            position={"x": 5000.0, "y": 6000.0},
            altitude_ft=20000,
            speed_kt=250,
        )
        assert mission_file.read_text(encoding="utf-8") != before

    def test_a_backup_is_taken_first(self, folder: Path) -> None:
        edit_route(
            folder,
            group_name="Texaco",
            operation="add",
            position={"x": 5000.0, "y": 6000.0},
            altitude_ft=20000,
            speed_kt=250,
        )
        # A file beside `mission` that was not there before the edit: the timestamped backup.
        others = [p.name for p in (folder / "src" / "mission").iterdir() if p.name != "mission"]
        assert others, "no backup written beside the mission file"

    def test_three_waypoints_can_be_built_up(self, folder: Path) -> None:
        # `veafMove._getTankerRouteData` refuses a route shorter than three points, which is the whole
        # reason this route was written by hand.
        for i in range(2):
            edit_route(
                folder,
                group_name="Texaco",
                operation="add",
                position={"x": 5000.0 * (i + 1), "y": 6000.0},
                altitude_ft=20000,
                speed_kt=250,
            )
        assert len(_waypoints(folder, "Texaco")) == 3


class TestTheOtherEditingActions:
    def test_set_group_properties(self, folder: Path) -> None:
        result = set_group_properties(folder, group_name="Texaco", frequency_mhz=133.0)
        assert result["durable"] is True
        assert _group(folder, "Texaco")["frequency"] == 133.0

    def test_set_unit_properties(self, folder: Path) -> None:
        result = set_unit_properties(folder, group_name="Texaco", unit_name="Texaco-1", skill="Excellent")
        assert result["durable"] is True

    def test_edit_zone(self, folder: Path) -> None:
        result = edit_zone(folder, zone_name="ZoneA", radius=1234)
        assert result["durable"] is True

    def test_add_trigger_zone(self, folder: Path) -> None:
        result = add_trigger_zone(folder, name="ZoneB", position={"x": 1.0, "y": 2.0}, radius=750)
        assert result["durable"] is True

    def test_add_map_drawing(self, folder: Path) -> None:
        result = add_map_drawing(
            folder, layer="Blue", shape="line", name="Route", points=[{"x": 0.0, "y": 0.0}, {"x": 10.0, "y": 10.0}]
        )
        assert result["durable"] is True


class TestRefusals:
    def test_a_directory_that_is_not_a_mission_folder_says_so(self, tmp_path: Path) -> None:
        # The failure this replaces was `[Errno 13] Permission denied`, which names neither the cause
        # nor the fix.
        empty = tmp_path / "not-a-mission"
        empty.mkdir()
        with pytest.raises(ValueError, match="not a mission folder"):
            edit_zone(empty, zone_name="ZoneA", radius=100)

    def test_a_missing_path_says_so(self, tmp_path: Path) -> None:
        with pytest.raises(ValueError, match="No such mission"):
            edit_zone(tmp_path / "nope.miz", zone_name="ZoneA", radius=100)
