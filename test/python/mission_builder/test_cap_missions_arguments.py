"""`cap_missions[]` keys land on the `addCapMission` parameters the doc now names.

FIX-SCRATCH-MISSION-FINDINGS ticket 21: the doc said `default` = "start as an active mission" and
`activated` = "activate at mission start". The generator passes them as the 4th and 5th arguments of
`veafCombatMission.addCapMission(missionName, description, briefing, secured, radioMenuEnabled)`, so
`default` is **secured** and `activated` is **radioMenuEnabled**. This pins that mapping: a change to
it changes what the documentation says, and must go with it.
"""

import pytest
from veaf_libs.lua_config_generator import generate_config_lua


def _cap_call(cap: dict) -> str:
    lua = generate_config_lua({"lua_modules": {"COMBATMISSION": {}}, "cap_missions": [cap]})
    return next(line.strip() for line in lua.splitlines() if ".addCapMission(" in line)


@pytest.mark.parametrize(
    ("cap", "secured", "radio_menu_enabled"),
    [
        ({}, "false", "true"),
        ({"default": True}, "true", "true"),
        ({"activated": False}, "false", "false"),
    ],
)
def test_default_is_secured_and_activated_is_the_radio_menu(cap: dict, secured: str, radio_menu_enabled: str) -> None:
    call = _cap_call({"group_name": "CAP-North", "menu_name": "North", "briefing": "b", **cap})
    assert call.endswith(f", {secured}, {radio_menu_enabled})")
