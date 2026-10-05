"""`veafCombatMission.initialize()` is emitted after the missions it builds the radio menu from.

FIX-COMBATMISSION-MENU-MISSING: `initialize()` calls `buildRadioMenu()`, which builds nothing while no
mission is registered, and nothing rebuilds the menu afterwards. Emitted before the `addCapMission` /
`AddMissionsWithSkillAndScale` calls, it left every mission declaring missions without its F10 MISSIONS
menu.
"""

from veaf_libs.lua_config_generator import generate_config_lua

_INITIALIZE = "veafCombatMission.initialize()"


def _lines(mission: dict) -> list[str]:
    return [line.strip() for line in generate_config_lua(mission).splitlines()]


def test_initialize_comes_after_every_mission() -> None:
    lines = _lines(
        {
            "lua_modules": {"COMBATMISSION": {}},
            "cap_missions": [{"group_name": "CAP-North", "menu_name": "North", "briefing": "b"}],
            "combat_missions": [{"name": "Raid", "elements": [{"name": "Strike", "groups": ["Raid-1"]}]}],
        }
    )
    mission_lines = [
        i for i, line in enumerate(lines) if ".addCapMission(" in line or ".AddMissionsWithSkillAndScale(" in line
    ]
    assert len(mission_lines) == 2
    assert lines.index(_INITIALIZE) > max(mission_lines)


def test_initialize_is_emitted_without_any_mission() -> None:
    assert _INITIALIZE in _lines({"lua_modules": {"COMBATMISSION": {}}})
