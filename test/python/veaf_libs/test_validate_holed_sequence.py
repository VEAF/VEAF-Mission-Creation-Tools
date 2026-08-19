"""Tests that `validate` names a holed mission table instead of letting the build die on it.

`FIX-GROUP-CONTAINER-SHAPE` ticket 02. On 2026-08-18 three holed tables surfaced at three unrelated
subsystems — a group container, a `units` list, and a `route.points` list — and the message
(`AttributeError: 'int' object has no attribute 'get'`) named none of them. Three debugging rounds.

Closing a hole is the right outcome and the build does it, but it *changes the file*, so it is reported
rather than repaired in silence.
"""

from __future__ import annotations

from pathlib import Path

from veaf_libs.mission_validator import WARNING, validate_mission_folder

_YAML = """theatre: Caucasus
modules:
  COMBATZONE:
    enabled: false
"""

_HOLED_MISSION = """mission = {
    ["theatre"] = "Caucasus",
    ["coalition"] = { ["blue"] = { ["country"] = { [1] = { ["id"] = 2, ["name"] = "USA",
        ["plane"] = { ["group"] = {
            [1] = { ["name"] = "Alpha", ["groupId"] = 1, ["units"] = { [3] = {
                ["name"] = "Alpha-1", ["type"] = "F-16C_50", ["skill"] = "Client", } } },
            [3] = { ["name"] = "Charlie", ["groupId"] = 3, ["units"] = { [1] = {
                ["name"] = "Charlie-1", ["type"] = "F-16C_50", ["skill"] = "Client", } } },
        } },
    } } }, ["red"] = { ["country"] = { } } },
    ["coalitions"] = { ["blue"] = { [1] = 2 }, ["red"] = { } },
}
"""

_CLEAN_MISSION = """mission = {
    ["theatre"] = "Caucasus",
    ["coalition"] = { ["blue"] = { ["country"] = { [1] = { ["id"] = 2, ["name"] = "USA",
        ["plane"] = { ["group"] = {
            [1] = { ["name"] = "Alpha", ["groupId"] = 1, ["units"] = { [1] = {
                ["name"] = "Alpha-1", ["type"] = "F-16C_50", ["skill"] = "Client", } } },
        } },
    } } }, ["red"] = { ["country"] = { } } },
    ["coalitions"] = { ["blue"] = { [1] = 2 }, ["red"] = { } },
}
"""


def _folder(tmp_path: Path, mission_lua: str) -> Path:
    (tmp_path / "mission.yaml").write_text(_YAML, encoding="utf-8", newline="\n")
    exploded = tmp_path / "src" / "mission"
    exploded.mkdir(parents=True)
    (exploded / "mission").write_text(mission_lua, encoding="utf-8", newline="\n")
    return tmp_path


def _hole_warnings(issues: list) -> list[str]:
    return [issue.message for issue in issues if issue.level == WARNING and "numbered" in issue.message]


class TestAHoleIsNamed:
    def test_the_group_container_is_reported_by_path(self, tmp_path: Path) -> None:
        messages = _hole_warnings(validate_mission_folder(_folder(tmp_path, _HOLED_MISSION)))
        assert any("coalition.blue.country[1].plane.group" in m for m in messages), messages

    def test_the_units_list_inside_it_is_reported_too(self, tmp_path: Path) -> None:
        # The one that had nothing to do with the edit that caused it.
        messages = _hole_warnings(validate_mission_folder(_folder(tmp_path, _HOLED_MISSION)))
        assert any("units" in m for m in messages), messages

    def test_the_message_says_the_keys_and_what_they_become(self, tmp_path: Path) -> None:
        messages = _hole_warnings(validate_mission_folder(_folder(tmp_path, _HOLED_MISSION)))
        group = next(m for m in messages if m.endswith(".") and "plane.group" in m)
        assert "1, 3" in group
        assert "1..2" in group

    def test_it_is_a_warning_not_an_error(self, tmp_path: Path) -> None:
        # The build closes the hole and carries on; a mission maker may well have meant the deletion.
        issues = validate_mission_folder(_folder(tmp_path, _HOLED_MISSION))
        assert all(issue.level == WARNING for issue in issues if "numbered" in issue.message)


class TestAWellFormedMissionIsQuiet:
    def test_nothing_is_reported(self, tmp_path: Path) -> None:
        # No noise on the nominal path, or the warnings become the ones nobody reads.
        assert _hole_warnings(validate_mission_folder(_folder(tmp_path, _CLEAN_MISSION))) == []
