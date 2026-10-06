"""What the players know of each zone (FEAT-CAMPAIGN-BRIEFING-DECK ticket 02)."""

from __future__ import annotations

import copy
import re
from typing import Any

import pytest
from campaign_fixture import VALID
from campaign_manager.campaign_manager import initial_state, parse_campaign
from campaign_manager.intelligence import (
    enemy_picture,
    fixed_site,
    friendly_picture,
    identify_system,
    reserve_text,
)
from campaign_manager.models import CampaignDefinition
from veaf_libs.i18n import language

SA10 = ["S-300PS 40B6MD sr", "S-300PS 40B6M tr", "S-300PS 5P85C ln", "S-300PS 5P85D ln"]


def _campaign(**zone_overrides: Any) -> CampaignDefinition:
    raw = copy.deepcopy(VALID)
    raw["zones"][1].update(zone_overrides)
    campaign, issues = parse_campaign(raw)
    assert campaign is not None, issues
    return campaign


def _garrison(lr_types: list[str], alive: bool = True) -> list[dict[str, Any]]:
    return [
        {"name": "Senaki garrison", "units": [{"type": "T-72B", "alive": True}]},
        {"name": "Senaki long-range SAM", "units": [{"type": kind, "alive": alive} for kind in lr_types]},
    ]


class TestTheFixedSite:
    @pytest.mark.parametrize(
        ("types", "system"),
        [
            (SA10, "SA-10"),
            (["S-200_Launcher", "RPC_5N62V"], "SA-5"),
            (["Patriot ln", "Patriot str"], "Patriot"),
            (["no such type"], None),
        ],
    )
    def test_a_battery_is_named_from_its_unit_types(self, types: list[str], system: str | None) -> None:
        assert identify_system(set(types)) == system

    def test_a_garrison_not_yet_drawn_holds_no_known_site(self) -> None:
        assert fixed_site(None) is None

    def test_a_garrison_without_a_long_range_battery_holds_none(self) -> None:
        assert fixed_site([{"name": "Senaki garrison", "units": [{"type": "T-72B", "alive": True}]}]) is None

    def test_a_recorded_battery_is_named_and_said_alive_or_destroyed(self) -> None:
        assert fixed_site(_garrison(SA10)) == fixed_site(_garrison(SA10, alive=True))
        site = fixed_site(_garrison(SA10, alive=False))
        assert site is not None
        assert (site.system, site.destroyed) == ("SA-10", True)


class TestTheEnemyPicture:
    def test_before_the_first_mission_the_long_range_sam_is_only_suspected(self) -> None:
        campaign = _campaign()
        state = initial_state(campaign)
        with language("fr"):
            text = enemy_picture(campaign, state, campaign.zone("Senaki"))
        assert "Défense aérienne longue portée probable, type non confirmé." in text
        assert "SA-" not in text
        assert text.endswith("Source : imagerie, plutôt fiable.")

    def test_once_recorded_the_battery_is_named(self) -> None:
        campaign = _campaign()
        state = initial_state(campaign)
        state.zones["Senaki"].garrison = _garrison(SA10)
        with language("fr"):
            assert "Batterie SA-10 confirmée sur la position." in enemy_picture(campaign, state, campaign.zone("Senaki"))
        state.zones["Senaki"].garrison = _garrison(SA10, alive=False)
        with language("fr"):
            assert "Batterie SA-10 détruite." in enemy_picture(campaign, state, campaign.zone("Senaki"))

    def test_a_logistics_zone_and_an_outpost_have_their_own_text_and_source(self) -> None:
        campaign = _campaign()
        state = initial_state(campaign)
        with language("fr"):
            depot = enemy_picture(campaign, state, campaign.zone("Gudauta depot"))
        assert depot.startswith("Centre logistique actif")
        assert depot.endswith("Source : renseignement humain local, non recoupé.")
        assert "longue portée" not in depot

    def test_the_campaign_can_say_what_the_intelligence_says(self) -> None:
        campaign = _campaign(intel="Aérodrome fortifié, piste intacte.")
        with language("fr"):
            text = enemy_picture(campaign, initial_state(campaign), campaign.zone("Senaki"))
        assert text.startswith("Aérodrome fortifié, piste intacte. Défense aérienne longue portée probable")

    def test_no_enemy_figure_is_ever_given(self) -> None:
        campaign = _campaign()
        state = initial_state(campaign)
        state.zones["Senaki"].garrison = _garrison(SA10)
        for lang in ("fr", "en"):
            with language(lang):
                for name in ("Senaki", "Gudauta depot"):
                    text = enemy_picture(campaign, state, campaign.zone(name)).replace("SA-10", "")
                    assert not re.search(r"\d", text), text


class TestTheFriendlyPicture:
    def test_our_positions_and_reserve_are_known(self) -> None:
        campaign = _campaign()
        with language("fr"):
            assert friendly_picture(campaign, campaign.zone("Kobuleti")).startswith("base défendue")
            assert reserve_text({"armor": 4, "air_defense": 2, "transport": 3}) == (
                "4 unités blindées, 2 de défense aérienne, 3 de transport"
            )
