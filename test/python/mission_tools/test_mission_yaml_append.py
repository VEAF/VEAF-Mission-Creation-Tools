"""Tests for appending to a `mission.yaml` list without stepping over its trailing comments.

`FIX-MCP-AUTHORING-GAPS` 01. Every assertion here is on **line order**, deliberately: the defect
parses perfectly — `yaml.safe_load` returns all three zones under `combat_zones` because comments do
not interrupt a sequence — so a parse-only assertion passes on the broken code and would not have
caught it. What breaks is the person reading the file, which only the layout shows.
"""

from __future__ import annotations

from pathlib import Path

import pytest
from mission_tools.mission_yaml_editor import append_to_sequence, load_yaml, save_yaml

_WITH_TRAILING_COMMENTS = """modules:
  COMBATZONE:
    enabled: true
    combat_zones:
      - type: zone
        zone_name: alpha
      - type: zone
        zone_name: beta

# ── Community scripts (off by default …) ─────
STTS: false
"""

_NO_TRAILING_COMMENT = """modules:
  COMBATZONE:
    enabled: true
    combat_zones:
      - type: zone
        zone_name: alpha
STTS: false
"""

_SCALAR_LIST = """items:
  - alpha
  - beta

# trailing block
other: 1
"""


def _write(tmp_path: Path, text: str) -> Path:
    path = tmp_path / "mission.yaml"
    path.write_text(text, encoding="utf-8", newline="\n")
    return path


def _line_of(path: Path, needle: str) -> int:
    lines = path.read_text(encoding="utf-8").splitlines()
    for index, line in enumerate(lines):
        if needle in line:
            return index
    raise AssertionError(f"{needle!r} not found in\n{chr(10).join(lines)}")


class TestTrailingCommentBlock:
    def test_the_new_entry_lands_above_the_comment_block(self, tmp_path: Path) -> None:
        path = _write(tmp_path, _WITH_TRAILING_COMMENTS)
        data = load_yaml(path)
        append_to_sequence(data["modules"]["COMBATZONE"]["combat_zones"], {"type": "zone", "zone_name": "gamma"})
        save_yaml(path, data)
        assert _line_of(path, "gamma") < _line_of(path, "Community scripts")

    def test_it_lands_immediately_after_the_last_real_item(self, tmp_path: Path) -> None:
        path = _write(tmp_path, _WITH_TRAILING_COMMENTS)
        data = load_yaml(path)
        append_to_sequence(data["modules"]["COMBATZONE"]["combat_zones"], {"type": "zone", "zone_name": "gamma"})
        save_yaml(path, data)
        # `beta`'s own two lines, then the new entry's `type` line: nothing wedged in between.
        assert _line_of(path, "gamma") == _line_of(path, "beta") + 2

    def test_the_comment_block_survives_and_stays_last(self, tmp_path: Path) -> None:
        path = _write(tmp_path, _WITH_TRAILING_COMMENTS)
        data = load_yaml(path)
        append_to_sequence(data["modules"]["COMBATZONE"]["combat_zones"], {"type": "zone", "zone_name": "gamma"})
        save_yaml(path, data)
        assert _line_of(path, "Community scripts") < _line_of(path, "STTS")

    def test_every_zone_is_still_read_back(self, tmp_path: Path) -> None:
        # The parse-level assertion the broken code also passed — kept so a layout fix cannot quietly
        # cost a zone.
        path = _write(tmp_path, _WITH_TRAILING_COMMENTS)
        data = load_yaml(path)
        append_to_sequence(data["modules"]["COMBATZONE"]["combat_zones"], {"type": "zone", "zone_name": "gamma"})
        save_yaml(path, data)
        zones = load_yaml(path)["modules"]["COMBATZONE"]["combat_zones"]
        assert [z["zone_name"] for z in zones] == ["alpha", "beta", "gamma"]

    def test_two_appends_in_a_row_both_stay_above_the_comment(self, tmp_path: Path) -> None:
        # The real case: `verify-mission-c` created two zones, and the second must not land below
        # the comment the first one just carried down.
        path = _write(tmp_path, _WITH_TRAILING_COMMENTS)
        for name in ("gamma", "delta"):
            data = load_yaml(path)
            append_to_sequence(data["modules"]["COMBATZONE"]["combat_zones"], {"type": "zone", "zone_name": name})
            save_yaml(path, data)
        comment = _line_of(path, "Community scripts")
        assert _line_of(path, "gamma") < comment
        assert _line_of(path, "delta") < comment


class TestOtherShapes:
    def test_a_list_with_no_trailing_comment_is_unaffected(self, tmp_path: Path) -> None:
        path = _write(tmp_path, _NO_TRAILING_COMMENT)
        data = load_yaml(path)
        append_to_sequence(data["modules"]["COMBATZONE"]["combat_zones"], {"type": "zone", "zone_name": "beta"})
        save_yaml(path, data)
        # +2: the appended entry writes its own `type:` line before `zone_name:`.
        assert _line_of(path, "beta") == _line_of(path, "alpha") + 2
        assert _line_of(path, "STTS") > _line_of(path, "beta")

    def test_a_scalar_list_keeps_its_trailing_comment_last(self, tmp_path: Path) -> None:
        path = _write(tmp_path, _SCALAR_LIST)
        data = load_yaml(path)
        append_to_sequence(data["items"], "gamma")
        save_yaml(path, data)
        assert _line_of(path, "gamma") < _line_of(path, "trailing block")
        assert load_yaml(path)["items"] == ["alpha", "beta", "gamma"]

    def test_a_freshly_created_plain_list_is_appended_to(self, tmp_path: Path) -> None:
        # The branch the three callers hit when the key does not exist yet: no comment bookkeeping.
        path = _write(tmp_path, _NO_TRAILING_COMMENT)
        data = load_yaml(path)
        fresh: list = []
        data["modules"]["COMBATZONE"]["new_list"] = fresh
        append_to_sequence(fresh, {"a": 1})
        save_yaml(path, data)
        assert load_yaml(path)["modules"]["COMBATZONE"]["new_list"] == [{"a": 1}]

    def test_an_empty_round_trip_list_is_appended_to(self, tmp_path: Path) -> None:
        path = _write(tmp_path, "items: []\n\n# trailing\nother: 1\n")
        data = load_yaml(path)
        append_to_sequence(data["items"], "alpha")
        save_yaml(path, data)
        assert load_yaml(path)["items"] == ["alpha"]


class TestThroughCreateCombatZone:
    """The end-to-end path the ticket measured, exercised through the action itself."""

    def test_the_action_writes_inside_the_list(self, tmp_path: Path) -> None:
        pytest.importorskip("veaf_mission_mcp.composites")
        from veaf_mission_mcp.composites import _append_combat_zone

        path = _write(tmp_path, _WITH_TRAILING_COMMENTS)
        _append_combat_zone(path, "gamma", None)
        assert _line_of(path, "gamma") < _line_of(path, "Community scripts")
