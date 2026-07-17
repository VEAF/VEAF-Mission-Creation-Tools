"""Optional explicit unit name — enables the `#command` combat-zone idiom (FEAT-MCP-MISSION-EDITOR-037)."""

from pathlib import Path
from typing import Any

from mission_tools.miz_tools import read_miz
from veaf_mission_mcp.add_group import _build_units, add_group


def _all_string_values(node: Any) -> list[str]:
    """Recursively collect every string leaf in a parsed mission structure."""
    if isinstance(node, str):
        return [node]
    if isinstance(node, dict):
        return [s for v in node.values() for s in _all_string_values(v)]
    if isinstance(node, list):
        return [s for v in node for s in _all_string_values(v)]
    return []


class TestBuildUnitsName:
    def test_explicit_name_honoured_for_single_unit(self) -> None:
        units = _build_units(
            [{"type": "Soldier M4", "name": '#command="-armor, spawnRadius 200"'}],
            position={"x": 0.0, "y": 0.0},
            group_name="G",
        )
        assert len(units) == 1
        assert units[0]["name"] == '#command="-armor, spawnRadius 200"'

    def test_explicit_name_suffixed_when_count_gt_1(self) -> None:
        units = _build_units(
            [{"type": "BTR-80", "count": 2, "name": "Scout"}],
            position={"x": 0.0, "y": 0.0},
            group_name="G",
        )
        assert [u["name"] for u in units] == ["Scout #01", "Scout #02"]

    def test_auto_name_when_no_explicit_name(self) -> None:
        units = _build_units([{"type": "BTR-80"}], position={"x": 0.0, "y": 0.0}, group_name="Red Armor")
        assert units[0]["name"] == "Red Armor Unit #001"


class TestAddGroupCommandMarker:
    def test_command_marker_round_trips_through_the_miz(self, sample_miz: Path) -> None:
        marker = '#command="-armor, spawnRadius 300"'
        add_group(
            sample_miz,
            coalition="red",
            country_id=0,
            country_name="Russia",
            category="vehicle",
            name="CZ_North spawner",
            position={"x": 100.0, "y": 200.0},
            units=[{"type": "Soldier M4", "name": marker}],
        )
        # The marker lives on the unit name; luadata escapes the inner quotes in the serialized
        # text, so assert on the parsed structure (un-escaped) rather than raw bytes.
        mission = read_miz(sample_miz)
        assert marker in _all_string_values(mission.mission_content)
