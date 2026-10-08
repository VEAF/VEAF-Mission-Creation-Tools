"""Assault convoys sent by the campaign in flight (FEAT-OPPOSITION-SCALES-WITH-PLAYERS ticket 04).

The mission records each convoy it sent: what left, what is still alive, what became a zone's garrison.
Between missions its dead are campaign losses, charged to its side and told in the debriefing, and its
survivors still on the road go back to the reserve.
"""

from __future__ import annotations

import copy
from pathlib import Path
from typing import Any

from campaign_fixture import VALID
from campaign_manager.campaign_manager import initial_state, parse_campaign
from campaign_manager.debriefing import debriefing_text
from campaign_manager.models import CampaignDefinition, CampaignState
from campaign_manager.next_mission import mission_data
from campaign_manager.turn_manager import describe_change, merge_state_file, read_state_file
from lua_runner import run_lua
from veaf_libs.i18n import language

REPO = Path(__file__).resolve().parents[3]


def _campaign(**rules: Any) -> CampaignDefinition:
    raw = copy.deepcopy(VALID)
    if rules:
        raw["rules"] = {**(raw.get("rules") or {}), **rules}
    campaign, issues = parse_campaign(raw)
    assert campaign is not None, issues
    return campaign


def _convoy(**changes: Any) -> dict[str, Any]:
    convoy: dict[str, Any] = {
        "name": "Senaki - Poti assault",
        "side": "red",
        "from": "Senaki",
        "to": "Kobuleti",
        "sent": ["BMP-2", "T-72B", "T-72B", "Ural-375"],
        "alive": ["T-72B", "Ural-375"],
        "absorbed": [],
    }
    convoy.update(changes)
    return convoy


def _flown(current: CampaignState, *convoys: dict[str, Any]) -> CampaignState:
    flown = copy.deepcopy(current)
    flown.mission = current.mission + 1
    flown.convoys = list(convoys)
    return flown


class TestTheRules:
    def test_on_by_default_ten_minutes(self) -> None:
        rules = _campaign().rules
        assert (rules.assault_convoys, rules.assault_seconds) == (True, 600)

    def test_the_campaign_sets_them(self) -> None:
        rules = _campaign(assault_convoys=False, assault_seconds=300).rules
        assert (rules.assault_convoys, rules.assault_seconds) == (False, 300)

    def test_a_wrong_value_is_an_error(self) -> None:
        raw = copy.deepcopy(VALID)
        raw["rules"] = {"assault_seconds": -5}
        campaign, issues = parse_campaign(raw)
        assert campaign is None
        assert any("assault_seconds" in issue.message for issue in issues)

    def test_the_mission_reads_them(self) -> None:
        campaign = _campaign(assault_convoys=False, assault_seconds=300)
        data = mission_data(campaign, initial_state(campaign))
        assert (data["assault_convoys"], data["assault_seconds"]) == (False, 300)


class TestTheStateFile:
    def test_the_mission_writes_its_convoys_and_the_tools_read_them(self, tmp_path: Path) -> None:
        src = (REPO / "src" / "scripts" / "veaf").as_posix()
        mocks = (REPO / "test" / "lua").as_posix()
        target = (tmp_path / "mission-01.state").as_posix()
        chunk = f"""
dofile("{mocks}/dcs_mocks.lua")
for _, m in ipairs({{"veaf","veafI18n","veafScheduler","veafMath","veafGeo","veafMissionDb","veafDcsSpawner",
  "dcsUnits","veafUnits","veafCasMission","veafEventHandler","veafCampaign"}}) do dofile("{src}/" .. m .. ".lua") end
veafCampaign.data = {{ format_version = 1, campaign = "Caucasus Front", mission = 1, assault_convoys = false,
  sides = {{ blue = {{ reserve = {{}} }}, red = {{ reserve = {{}} }} }},
  zones = {{ {{ name = "Poti", x = 0, z = 0, owner = "neutral" }} }} }}
veafCampaign.initialize()
veafCampaign.convoys = {{ {{ name = "c", side = "red", from = "Senaki", to = "Poti", ended = true,
  sent = {{ "T-72B", "BMP-2" }}, alive = {{}}, absorbed = {{ "T-72B" }} }} }}
local f = assert(io.open("{target}", "w"))
f:write("return " .. veafCampaign.serialize(veafCampaign.stateTable()) .. "\\n")
f:close()
"""
        result = run_lua(chunk)
        assert result.returncode == 0, result.stderr
        state, issues = read_state_file(tmp_path / "mission-01.state")
        assert issues == []
        assert state is not None
        # an empty Lua table is a dict to luadata: lists come back as lists
        assert state.convoys == [
            {
                "name": "c",
                "side": "red",
                "from": "Senaki",
                "to": "Poti",
                "sent": ["T-72B", "BMP-2"],
                "alive": [],
                "absorbed": ["T-72B"],
            }
        ]


class TestMerging:
    def test_the_dead_are_campaign_losses(self) -> None:
        current = initial_state(_campaign())
        _, changes = merge_state_file(current, _flown(current, _convoy()))
        losses = [change for change in changes if change["kind"] == "losses"]
        assert len(losses) == 1
        assert losses[0]["side"] == "red"
        assert (losses[0]["lost"], losses[0]["types"]) == (2, {"BMP-2": 1, "T-72B": 1})

    def test_the_survivors_on_the_road_go_back_to_the_reserve(self) -> None:
        current = initial_state(_campaign())
        flown = _flown(current, _convoy())
        flown.sides["red"].reserve = {"armor": 1, "air_defense": 0, "transport": 0}
        merged, changes = merge_state_file(current, flown)
        assert merged.sides["red"].reserve == {"armor": 2, "air_defense": 0, "transport": 1}
        assert {"kind": "convoy_returned", "side": "red", "from": "Senaki", "to": "Kobuleti", "units": 2} in changes

    def test_a_convoy_that_became_a_garrison_lost_only_its_dead_and_returns_nothing(self) -> None:
        current = initial_state(_campaign())
        convoy = _convoy(alive=[], absorbed=["T-72B", "T-72B", "Ural-375"])
        merged, changes = merge_state_file(current, _flown(current, convoy))
        losses = [change for change in changes if change["kind"] == "losses"]
        assert (losses[0]["lost"], losses[0]["types"]) == (1, {"BMP-2": 1})
        assert not [change for change in changes if change["kind"] == "convoy_returned"]

    def test_the_merged_state_keeps_no_convoy(self) -> None:
        current = initial_state(_campaign())
        merged, _ = merge_state_file(current, _flown(current, _convoy()))
        assert merged.convoys == []

    def test_the_debriefing_tells_the_convoy(self) -> None:
        campaign = _campaign()
        current = initial_state(campaign)
        merged, changes = merge_state_file(current, _flown(current, _convoy()))
        with language("en"):
            text = debriefing_text(campaign, merged, changes, [])
            returned = describe_change(next(c for c in changes if c["kind"] == "convoy_returned"))
        assert "Senaki" in text and "Kobuleti" in text
        assert returned in text


class TestTheMissionBriefing:
    def _line(self, campaign: CampaignDefinition, state: CampaignState) -> str | None:
        from campaign_manager.mission_deck import _counter_attack_line

        with language("fr"):
            return _counter_attack_line(campaign, state)

    def test_a_neutral_zone_the_enemy_borders_is_an_expected_counter_attack(self) -> None:
        campaign = _campaign()
        state = initial_state(campaign)
        neutral = next(zone.name for zone in campaign.zones if any(zone.name in c for c in campaign.connections))
        state.zones[neutral].owner = "neutral"
        for connection in campaign.connections:
            if neutral in connection:
                other = connection[0] if connection[1] == neutral else connection[1]
                state.zones[other].owner = "red"
        line = self._line(campaign, state)
        assert line is not None
        assert neutral in line
        assert not any(character.isdigit() for character in line.replace(neutral, ""))

    def test_nothing_to_say_without_a_target(self) -> None:
        campaign = _campaign()
        state = initial_state(campaign)
        for zone in state.zones.values():
            zone.owner = "blue" if zone.owner == "neutral" else zone.owner
        assert self._line(campaign, state) is None

    def test_nothing_to_say_when_the_rule_is_off(self) -> None:
        campaign = _campaign(assault_convoys=False)
        state = initial_state(campaign)
        for zone in state.zones.values():
            zone.owner = "neutral"
        assert self._line(campaign, state) is None
