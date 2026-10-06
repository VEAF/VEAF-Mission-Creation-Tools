"""The campaign state: created from `campaign.yaml`, saved, read back, checked against it (ticket 01)."""

from __future__ import annotations

import copy
from pathlib import Path

import yaml
from campaign_fixture import VALID
from campaign_manager.campaign_manager import (
    initial_state,
    load_state,
    parse_campaign,
    save_state,
    validate_state,
)
from campaign_manager.models import STATE_FORMAT_VERSION, CampaignDefinition, CampaignState
from veaf_libs.i18n import t
from veaf_libs.mission_validator import ERROR


def _campaign() -> CampaignDefinition:
    campaign, issues = parse_campaign(copy.deepcopy(VALID))
    assert campaign is not None, issues
    return campaign


def _errors(campaign: CampaignDefinition, state: CampaignState) -> list[str]:
    return [issue.message for issue in validate_state(campaign, state) if issue.level == ERROR]


class TestTheInitialState:
    def test_every_zone_starts_with_its_declared_owner_and_no_garrison_drawn(self) -> None:
        state = initial_state(_campaign())
        assert {name: zone.owner for name, zone in state.zones.items()} == {
            "Kobuleti": "blue",
            "Senaki": "red",
            "Gudauta depot": "red",
        }
        assert all(zone.garrison is None for zone in state.zones.values())
        assert all(zone.capture is None for zone in state.zones.values())

    def test_it_carries_the_format_version_the_campaign_and_mission_zero(self) -> None:
        state = initial_state(_campaign())
        assert state.format_version == STATE_FORMAT_VERSION
        assert state.campaign == "Caucasus Front"
        assert state.mission == 0

    def test_both_coalitions_start_with_their_declared_reserve_and_no_scenery_is_destroyed(self) -> None:
        raw = copy.deepcopy(VALID)
        raw["sides"] = {"red": {"reserve": {"armor": 8}}}
        campaign, _ = parse_campaign(raw)
        assert campaign is not None
        state = initial_state(campaign)
        assert state.sides["red"].reserve == {"armor": 8, "air_defense": 0, "transport": 0}
        assert state.sides["blue"].reserve == {"armor": 0, "air_defense": 0, "transport": 0}
        assert state.scenery_destroyed == []
        assert state.history == []

    def test_a_fresh_state_validates_against_its_campaign(self) -> None:
        campaign = _campaign()
        assert validate_state(campaign, initial_state(campaign)) == []


class TestSavingAndReading:
    def test_a_state_reads_back_identical(self, tmp_path: Path) -> None:
        state = initial_state(_campaign())
        state.zones["Senaki"].garrison = [{"name": "g1", "units": [{"type": "T-72B", "alive": True}]}]
        state.zones["Senaki"].capture = {"side": "blue", "seconds": 40}
        state.sides["red"].reserve = {"armor": 12}
        state.scenery_destroyed = [{"id": 1234, "x": 1.5, "z": -2.5}]
        state.mission = 3
        path = tmp_path / "campaign-state.yaml"
        save_state(state, path)
        loaded, issues = load_state(path)
        assert issues == []
        assert loaded == state

    def test_the_saved_file_is_plain_yaml_keyed_by_zone_name(self, tmp_path: Path) -> None:
        path = tmp_path / "campaign-state.yaml"
        save_state(initial_state(_campaign()), path)
        raw = yaml.safe_load(path.read_text(encoding="utf-8"))
        assert raw["format_version"] == STATE_FORMAT_VERSION
        assert raw["zones"]["Gudauta depot"]["owner"] == "red"

    def test_saving_leaves_no_temporary_file_behind(self, tmp_path: Path) -> None:
        path = tmp_path / "campaign-state.yaml"
        save_state(initial_state(_campaign()), path)
        save_state(initial_state(_campaign()), path)
        assert [p.name for p in tmp_path.iterdir()] == ["campaign-state.yaml"]

    def test_a_file_that_is_not_yaml_is_reported_not_raised(self, tmp_path: Path) -> None:
        path = tmp_path / "campaign-state.yaml"
        path.write_text("zones: [unclosed", encoding="utf-8")
        state, issues = load_state(path)
        assert state is None
        assert [issue.message for issue in issues] == [t("campaign.issue.state_unreadable", path=path)]

    def test_a_file_whose_shape_is_wrong_is_reported_not_raised(self, tmp_path: Path) -> None:
        path = tmp_path / "campaign-state.yaml"
        path.write_text("zones: 3\n", encoding="utf-8")
        state, issues = load_state(path)
        assert state is None
        assert [issue.message for issue in issues] == [t("campaign.issue.state_malformed", path=path)]


class TestTheStateAgainstItsCampaign:
    def test_another_format_version_is_reported(self) -> None:
        campaign = _campaign()
        state = initial_state(campaign)
        state.format_version = STATE_FORMAT_VERSION + 1
        assert _errors(campaign, state) == [
            t("campaign.issue.state_version", found=STATE_FORMAT_VERSION + 1, expected=STATE_FORMAT_VERSION)
        ]

    def test_a_state_of_another_campaign_is_reported(self) -> None:
        campaign = _campaign()
        state = initial_state(campaign)
        state.campaign = "Syria Front"
        assert _errors(campaign, state) == [
            t("campaign.issue.state_other_campaign", found="Syria Front", expected="Caucasus Front")
        ]

    def test_a_zone_removed_or_renamed_in_the_campaign_is_reported_never_dropped(self) -> None:
        raw = copy.deepcopy(VALID)
        raw["zones"][2]["name"] = "Gudauta fuel depot"
        raw["connections"][1] = ["Senaki", "Gudauta fuel depot"]
        raw["campaign"]["objectives"] = []
        renamed, _ = parse_campaign(raw)
        assert renamed is not None
        state = initial_state(_campaign())
        errors = _errors(renamed, state)
        assert t("campaign.issue.state_zone_not_in_campaign", zone="Gudauta depot") in errors
        assert t("campaign.issue.state_zone_missing", zone="Gudauta fuel depot") in errors
        assert "Gudauta depot" in state.zones

    def test_an_owner_that_is_not_a_side_is_reported(self) -> None:
        campaign = _campaign()
        state = initial_state(campaign)
        state.zones["Senaki"].owner = "purple"
        assert _errors(campaign, state) == [t("campaign.issue.unknown_side", zone="Senaki", side="purple")]
