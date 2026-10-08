"""The `opposition:` block of mission.yaml reaches the generated Lua (FEAT-OPPOSITION-SCALES-WITH-PLAYERS).

The level is configured before the modules initialize, so a combat mission building its radio menu
knows there is a level to offer; the marker and the radio menu are set up after them, once the radio
and the command dispatcher exist.
"""

from __future__ import annotations

from pathlib import Path
from typing import Any

import pytest
from veaf_libs.lua_config_generator import _emit_qra_definition, emit_opposition_block, generate_config_lua

_MODULES: dict[str, Any] = {"QRA": {}, "COMBATMISSION": {}}


def _lua(mission: dict[str, Any]) -> str:
    return generate_config_lua({"mission": {"name": "T"}, "lua_modules": _MODULES, **mission})


def test_no_block_no_opposition() -> None:
    assert "veafOpposition" not in _lua({})


def test_the_level_is_configured_before_the_modules_and_initialized_after() -> None:
    lua = _lua({"opposition": {"level": 6}})
    configure = lua.index("veafOpposition.configure(")
    initialize = lua.index("veafOpposition.initialize()")
    assert configure < lua.index("veafCombatMission.initialize") < initialize
    assert "level = 6" in lua


def test_every_key() -> None:
    configure, _ = emit_opposition_block(
        {"level": 4, "follow": "airborne", "lower_after": 600, "players_coalition": "RED"}
    )
    text = "\n".join(configure)
    assert 'follow = "airborne"' in text
    assert "lowerAfter = 600" in text
    assert "playersCoalition = coalition.side.RED" in text


def test_an_empty_block_still_offers_the_command() -> None:
    configure, initialize = emit_opposition_block({})
    assert any("veafOpposition.configure({})" in line for line in configure)
    assert any("veafOpposition.initialize()" in line for line in initialize)


@pytest.mark.parametrize(
    ("block", "message"),
    [
        ({"level": -1}, "level"),
        ({"level": "six"}, "level"),
        ({"follow": "everybody"}, "follow"),
        ({"lower_after": 0}, "lower_after"),
        ({"players_coalition": "GREEN"}, "players_coalition"),
        ({"levle": 6}, "levle"),
    ],
)
def test_a_wrong_value_is_refused(block: dict[str, Any], message: str) -> None:
    with pytest.raises(ValueError, match=message):
        emit_opposition_block(block)


@pytest.mark.parametrize("block", [6, "players", ["level", 6]])
def test_a_block_that_is_not_a_mapping_is_refused(block: object) -> None:
    with pytest.raises(ValueError, match="block of keys"):
        _lua({"opposition": block})


def test_validate_reports_what_the_build_would_refuse(tmp_path: Path) -> None:
    from veaf_libs.mission_validator import ERROR, validate_mission_folder

    (tmp_path / "mission.yaml").write_text("opposition:\n  follow: everybody\n", encoding="utf-8")
    issues = validate_mission_folder(tmp_path)
    assert any(issue.level == ERROR and "follow" in issue.message for issue in issues)


def test_validate_accepts_a_right_block(tmp_path: Path) -> None:
    from veaf_libs.mission_validator import validate_mission_folder

    (tmp_path / "mission.yaml").write_text("opposition:\n  level: 6\n", encoding="utf-8")
    assert not any("opposition" in issue.message for issue in validate_mission_folder(tmp_path))


def test_a_qra_scaling_with_the_opposition() -> None:
    lines = _emit_qra_definition({"name": "Q", "coalition": "RED", "scale_with_opposition": True})
    assert ":setScaleWithOpposition()" in [line.strip() for line in lines]
