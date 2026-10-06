"""The written half of the campaign briefing: `briefing.yaml` (FEAT-CAMPAIGN-BRIEFING-DECK ticket 03)."""

from __future__ import annotations

import copy
from pathlib import Path
from typing import Any

import yaml
from campaign_fixture import VALID
from campaign_manager.briefing_prose import PROSE_FILE, load_prose, parse_prose
from campaign_manager.campaign_worker import CAMPAIGN_FILE, CampaignWorker
from veaf_libs.i18n import t
from veaf_libs.mission_validator import ERROR, WARNING

#: A complete prose file, the shape the Kolkhida prototype was written in.
PROSE: dict[str, Any] = {
    "operation": "Kolkhida",
    "subtitle": "Briefing de situation — campagne",
    "situation": {
        "political": ["Les forces rouges ont franchi l'Inguri.", "Une négociation s'ouvre."],
        "economic": "Le port de Poti ne tourne plus.",
        "enemy_course_of_action": "Tenir Senaki, puis reprendre l'offensive.",
    },
    "mission": "Reprendre Senaki et détruire le dépôt de Khobi.",
    "intent": {"purpose": "Briser l'offensive.", "end_state": "Senaki tenue."},
    "objectives": {"political": ["Rétablir l'autorité du gouvernement."], "military": ["Reprendre Senaki."]},
    "concept": {
        "phases": [{"title": "Phase 1 — la porte de Poti", "text": "Prendre Poti."}],
        "attention": ["Zugdidi n'est pas un objectif."],
    },
    "rules_of_engagement": {"targeting": ["Identification positive avant le tir."]},
    "missions": {1: {"title": "La porte de Poti", "tasks": [{"title": "Prendre Poti", "text": "Sécuriser le port."}]}},
}


def _messages(raw: Any, missions: int = 3, coming: int = 1, level: str = ERROR) -> list[str]:
    return [issue.message for issue in parse_prose(raw, missions, coming)[1] if issue.level == level]


class TestReadingTheProse:
    def test_a_complete_file_is_read_section_by_section(self) -> None:
        prose, issues = parse_prose(copy.deepcopy(PROSE), missions=3, coming=1)
        assert issues == []
        assert prose is not None
        assert (prose.operation, prose.subtitle) == ("Kolkhida", "Briefing de situation — campagne")
        assert prose.text("situation", "political") == ("Les forces rouges ont franchi l'Inguri.", "Une négociation s'ouvre.")
        assert prose.text("situation", "economic") == ("Le port de Poti ne tourne plus.",)
        assert prose.text("mission", "mission") == ("Reprendre Senaki et détruire le dépôt de Khobi.",)
        assert prose.text("intent", "method") == ()
        assert prose.phases[0].title == "Phase 1 — la porte de Poti"
        assert prose.text("concept", "attention") == ("Zugdidi n'est pas un objectif.",)
        assert prose.missions[1].tasks[0].text == ("Sécuriser le port.",)

    def test_an_unknown_key_is_reported_with_what_is_expected(self) -> None:
        raw = copy.deepcopy(PROSE)
        raw["intent"]["goal"] = "x"
        known = "purpose, main_effect, method, end_state"
        assert t("campaign.issue.prose.unknown_key", section="intent", key_name="goal", known=known) in _messages(raw)

    def test_a_text_that_is_not_text_is_reported_by_section(self) -> None:
        raw = copy.deepcopy(PROSE)
        raw["situation"]["economic"] = 12
        assert t("campaign.issue.prose.not_text", section="situation.economic") in _messages(raw)

    def test_a_phase_or_task_without_a_title_is_reported(self) -> None:
        raw = copy.deepcopy(PROSE)
        raw["concept"]["phases"].append({"text": "sans titre"})
        assert t("campaign.issue.prose.not_titled", section="concept.phases[2]") in _messages(raw)

    def test_more_phases_than_missions_is_reported(self) -> None:
        raw = copy.deepcopy(PROSE)
        raw["concept"]["phases"] = [{"title": f"Phase {n}", "text": "x"} for n in range(1, 5)]
        assert t("campaign.issue.prose.too_many_phases", count=4, missions=3) in _messages(raw)

    def test_a_page_for_a_mission_the_campaign_does_not_have_is_reported(self) -> None:
        raw = copy.deepcopy(PROSE)
        raw["missions"][4] = {"title": "Trop loin", "tasks": []}
        assert t("campaign.issue.prose.mission_out_of_range", mission=4, missions=3) in _messages(raw)

    def test_the_coming_missions_page_missing_is_a_warning_not_an_error(self) -> None:
        prose, issues = parse_prose(copy.deepcopy(PROSE), missions=3, coming=2)
        assert prose is not None
        assert [issue.level for issue in issues] == [WARNING]
        assert issues[0].message == t("campaign.issue.prose.no_mission_page", mission=2)


class TestTheFile:
    def test_no_file_is_no_prose_and_no_issue(self, tmp_path: Path) -> None:
        assert load_prose(tmp_path, 3, 1) == (None, [])

    def test_campaign_validate_checks_it(self, tmp_path: Path) -> None:
        (tmp_path / CAMPAIGN_FILE).write_text(yaml.safe_dump(copy.deepcopy(VALID)), encoding="utf-8")
        raw = copy.deepcopy(PROSE)
        raw["situation"]["economic"] = 12
        (tmp_path / PROSE_FILE).write_text(yaml.safe_dump(raw, allow_unicode=True), encoding="utf-8")
        messages = [issue.message for issue in CampaignWorker(tmp_path).validate()]
        assert t("campaign.issue.prose.not_text", section="situation.economic") in messages
