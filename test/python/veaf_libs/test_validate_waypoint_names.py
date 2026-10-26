"""Tests that `validate` warns about a flight plan listing two waypoints with one cockpit name.

FIX-COWORK-SESSION-FINDINGS ticket 02: COAST out and COAST back, two keys with `name: "COAST"`, and the
injector kept only the second — W6 vanished from the route with nothing said. The injector keeps both
now; what is left is two points nobody can tell apart by name, hence a warning.
"""

from __future__ import annotations

from pathlib import Path

import yaml
from veaf_libs.mission_validator import WARNING, validate_mission_folder


def _folder(tmp_path: Path, waypoints: dict) -> Path:
    (tmp_path / "mission.yaml").write_text("theatre: Caucasus\n", encoding="utf-8")
    (tmp_path / "src").mkdir()
    (tmp_path / "src" / "waypoints.yaml").write_text(yaml.safe_dump(waypoints), encoding="utf-8")
    return tmp_path


def _duplicates(tmp_path: Path, waypoints: dict) -> list[str]:
    issues = validate_mission_folder(_folder(tmp_path, waypoints))
    return [issue.message for issue in issues if issue.level == WARNING and "COAST" in issue.message]


def test_two_points_named_coast_are_warned(tmp_path: Path) -> None:
    messages = _duplicates(
        tmp_path,
        {
            "waypoints": {"COAST_OUT": {"alt": 0, "name": "COAST"}, "COAST_IN": {"alt": 0, "name": "COAST"}},
            "settings": {"blue": {"coalition": "blue", "waypoints": ["COAST_OUT", "COAST_IN"]}},
        },
    )
    assert len(messages) == 1
    assert "COAST_OUT" in messages[0] and "COAST_IN" in messages[0] and "blue" in messages[0]


def test_distinct_names_pass(tmp_path: Path) -> None:
    messages = _duplicates(
        tmp_path,
        {
            "waypoints": {"COAST_OUT": {"alt": 0, "name": "FEET WET"}, "COAST_IN": {"alt": 0, "name": "COAST"}},
            "settings": {"blue": {"waypoints": ["COAST_OUT", "COAST_IN"]}},
        },
    )
    assert messages == []
