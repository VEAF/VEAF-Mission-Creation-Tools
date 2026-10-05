"""Every QRA key of mission.yaml reaches the generated Lua (FIX-QRA-COMMANDS-AND-OFFSET).

`respawn_default_offset` was accepted under a QRA definition and never emitted: the session mission
of 2026-09-01 carried `:setRespawnDefaultOffset(4000, -7000)` for its wave zone and nothing for the
QRA beside it. And convert-v5 wrote `start: false` for a QRA whose v5 `:start()` was commented out,
which the generator did not read either: that QRA was armed at mission start.

The keys are enumerated from `QRA_DEFINITION_KEYS`, not sampled: a key added there without a sample
value here fails the sweep.
"""

from __future__ import annotations

from typing import Any

import pytest
from veaf_libs.lua_config_generator import (
    QRA_DEFINITION_KEYS,
    _emit_airwave_zone,
    _emit_qra_definition,
    generate_config_lua,
)

_BASE: dict[str, Any] = {"name": "QRA-Nord", "coalition": "RED"}

#: A value for each key that changes what is emitted, compared with _BASE alone.
_SAMPLES: dict[str, Any] = {
    "name": "QRA-Sud",
    "coalition": "BLUE",
    "enemy_coalitions": ["BLUE"],
    "trigger_zone": "ZONE-QRA",
    "zone_radius": 30000,
    "simple_groups": ["MiG-29 QRA"],
    "groups_by_enemy_count": [{"enemy_count": 2, "groups": ["Duo-1"], "random_pick": 1}],
    "delay_before_rearming": 30,
    "delay_before_activating": 20,
    "react_on_helicopters": True,
    "airport_link": "Batumi",
    "respawn_default_offset": [0, 3000],
    "active_at_start": False,
    "start": False,
    "radio_menu": True,
    "radio_menu_restrict_to_group": "MM Ctrl",
    "radio_menu_secured": True,
    "follow_unit": "CVN-74",
    "links": ["Batumi", "SA-10 site"],
    "logistics": {"groups_available": 4},
}


def _lua(definition: dict[str, Any]) -> str:
    return generate_config_lua(
        {"mission": {"name": "T"}, "lua_modules": {"QRA": {}}, "qra": {"definitions": [definition]}}
    )


def test_every_key_has_a_sample() -> None:
    assert set(_SAMPLES) == set(QRA_DEFINITION_KEYS)


@pytest.mark.parametrize("key", sorted(QRA_DEFINITION_KEYS))
def test_the_key_changes_the_lua(key: str) -> None:
    definition = {**_BASE, key: _SAMPLES[key]}
    if key == "radio_menu_secured":
        definition["radio_menu"] = True
        definition["radio_menu_restrict_to_group"] = "MM Ctrl"
        baseline = {**_BASE, "radio_menu": True, "radio_menu_restrict_to_group": "MM Ctrl"}
    elif key == "radio_menu_restrict_to_group":
        definition["radio_menu"] = True
        baseline = {**_BASE, "radio_menu": True}
    else:
        baseline = _BASE
    assert _lua(definition) != _lua(baseline), f"{key} is accepted and emits nothing"


def test_the_offset_is_emitted_on_the_qra_chain() -> None:
    lines = _emit_qra_definition({**_BASE, "respawn_default_offset": [0, 3000]})
    assert ":setRespawnDefaultOffset(0, 3000)" in [line.strip() for line in lines]


def test_a_converted_start_false_leaves_the_qra_unarmed() -> None:
    assert not any(":start()" in line for line in _emit_qra_definition({**_BASE, "start": False}))


def test_active_at_start_wins_over_the_converted_key() -> None:
    lines = _emit_qra_definition({**_BASE, "start": False, "active_at_start": True})
    assert any(":start()" in line for line in lines)


def test_a_list_of_wave_groups_is_a_lua_table() -> None:
    """A YAML list was emitted through str(): the runtime got the single group "['a', 'b']"."""
    lines = _emit_airwave_zone({"name": "Z", "waves": [{"groups": ["su27-a", "su27-b"]}, {"groups": "solo"}]})
    waves = [line.strip() for line in lines if "addWave" in line]
    assert waves == [':addWave({groups = {"su27-a", "su27-b"}})', ':addWave({groups = "solo"})']


def test_a_zone_that_follows_a_unit_and_its_links() -> None:
    """FEAT-AIRWAVES-QRA-MERGE #186 and #183, on the QRA chain."""
    lines = [
        line.strip()
        for line in _emit_qra_definition({**_BASE, "follow_unit": "CVN-74", "links": ["Batumi", "SA-10 site"]})
    ]
    assert ':setFollowUnit("CVN-74")' in lines
    assert ':addLink("Batumi")' in lines
    assert ':addLink("SA-10 site")' in lines


def test_logistics_emits_every_setter() -> None:
    """Ticket 08: the stock and resupply chain, reachable from mission.yaml."""
    logistics = {
        "groups_available": 4,
        "max_ready": 2,
        "resupply_delay": 600,
        "resupply_amount": 1,
        "max_resupplies": 3,
        "resupply_below": 2,
    }
    lines = [line.strip() for line in _emit_qra_definition({**_BASE, "logistics": logistics})]
    for call in (
        ":setQRAcount(4)",
        ":setQRAmaxCount(2)",
        ":setQRAresupplyDelay(600)",
        ":setResupplyAmount(1)",
        ":setQRAmaxResupplyCount(3)",
        ":setQRAminCountforResupply(2)",
    ):
        assert call in lines, call


def test_logistics_comes_before_the_start() -> None:
    lines = [line.strip() for line in _emit_qra_definition({**_BASE, "logistics": {"groups_available": 4}})]
    assert lines.index(":setQRAcount(4)") < lines.index(":start()")


def test_a_zero_in_logistics_is_written() -> None:
    """`groups_available: 0` is a QRA that starts empty — not an absent setting."""
    lines = [line.strip() for line in _emit_qra_definition({**_BASE, "logistics": {"groups_available": 0}})]
    assert ":setQRAcount(0)" in lines


def test_the_new_wave_zone_keys_are_emitted() -> None:
    zone = {
        "name": "Z",
        "follow_unit": "CVN-74",
        "links": ["Maykop"],
        "closed_once_active": True,
        "max_seconds_outside_players": 40,
        "waves": [{"groups": "Bandits", "friendly_groups": ["Tanker"], "support_groups": "AWACS"}],
    }
    lines = [line.strip() for line in _emit_airwave_zone(zone)]
    assert ':setFollowUnit("CVN-74")' in lines
    assert ':addLink("Maykop")' in lines
    assert ":setClosedOnceActive(true)" in lines
    assert ":setMaxSecondsOutsideOfZonePlayers(40)" in lines
    assert ':addWave({groups = "Bandits", friendlyGroups = {"Tanker"}, supportGroups = "AWACS"})' in lines


def test_a_logistics_that_is_not_a_mapping_does_not_break_the_build() -> None:
    lines = _emit_qra_definition({**_BASE, "logistics": 4})
    assert not any("setQRAcount" in line for line in lines)
