"""The debriefing `campaign apply` writes after a mission (FEAT-MULTI-MISSION-CAMPAIGN ticket 12)."""

from __future__ import annotations

import copy
from typing import Any

from campaign_fixture import VALID
from campaign_manager.campaign_manager import initial_state, parse_campaign
from campaign_manager.debriefing import debriefing_text
from campaign_manager.models import CampaignDefinition
from veaf_libs.i18n import language


def _campaign() -> CampaignDefinition:
    campaign, issues = parse_campaign(copy.deepcopy(VALID))
    assert campaign is not None, issues
    return campaign


FLIGHT: list[dict[str, Any]] = [
    {"kind": "owner", "zone": "Senaki", "from": "red", "to": "neutral"},
    {"kind": "losses", "zone": "Senaki", "side": "red", "lost": 7, "types": {"T-72B": 5, "Kub 2P25 ln": 2}},
    {"kind": "losses", "zone": "Gudauta depot", "side": "red", "lost": 1, "types": {"Ural-375": 1}},
    {"kind": "losses", "zone": "Kobuleti", "side": "blue", "lost": 1, "types": {"M-1 Abrams": 1}},
    {"kind": "scenery", "destroyed": 2},
]
TURN: list[dict[str, Any]] = [
    {
        "kind": "logistics",
        "zone": "Gudauta depot",
        "side": "red",
        "added": {"armor": 2, "air_defense": 1, "transport": 0},
    },
]


def _text(lang: str, flight: list[dict[str, Any]] = FLIGHT, turn: list[dict[str, Any]] = TURN) -> list[str]:
    campaign = _campaign()
    state = initial_state(campaign)
    state.mission = 1
    state.zones["Senaki"].owner = "neutral"
    with language(lang):
        return debriefing_text(campaign, state, flight, turn).splitlines()


def test_the_whole_debriefing_in_english() -> None:
    assert _text("en") == [
        "DEBRIEFING — Caucasus Front, mission 1 of 8",
        "",
        "Ground changing hands:",
        "- Senaki: red → neutral",
        "",
        "Losses:",
        "- blue: 1 unit(s)",
        "  - Kobuleti: 1 — 1 × M-1 Abrams",
        "- red: 8 unit(s)",
        "  - Senaki: 7 — 5 × T-72B, 2 × Kub 2P25 ln",
        "  - Gudauta depot: 1 — 1 × Ural-375",
        "Scenery destroyed: 2 object(s).",
        "",
        "Between missions:",
        "- Gudauta depot feeds the red reserve: armour +2, air defence +1",
        "",
        "Campaign objectives:",
        "[ ] capture Senaki",
        "[ ] destroy Gudauta depot",
        "7 mission(s) planned left.",
    ]


def test_it_is_written_in_french_too() -> None:
    text = _text("fr")
    assert text[0] == "DÉBRIEFING — Caucasus Front, mission 1 sur 8"
    assert "- Senaki : rouge → neutre" in text
    assert "- rouge : 8 unité(s)" in text
    assert "  - Senaki : 7 — 5 × T-72B, 2 × Kub 2P25 ln" in text


def test_a_quiet_mission_says_so_rather_than_leaving_sections_empty() -> None:
    text = _text("en", flight=[], turn=[])
    assert "- no zone changed hands" in text
    assert "- no loss on either side" in text
    assert "- nothing" in text
    assert not any(line.startswith("Scenery") for line in text)


def test_the_players_side_comes_first() -> None:
    campaign = _campaign()
    campaign = type(campaign)(**{**campaign.__dict__, "player_side": "red"})
    state = initial_state(campaign)
    with language("en"):
        text = debriefing_text(campaign, state, FLIGHT, TURN).splitlines()
    assert text.index("- red: 8 unit(s)") < text.index("- blue: 1 unit(s)")


def test_a_side_with_no_loss_is_left_out_of_the_losses() -> None:
    flight = [c for c in FLIGHT if c.get("side") != "blue"]
    assert not any(line.startswith("- blue") for line in _text("en", flight=flight))
