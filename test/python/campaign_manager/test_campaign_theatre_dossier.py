"""A persistent campaign's theatre dossier, in place of its two decks (FEAT-DYNAMIC-CAMPAIGN ticket 20)."""

from __future__ import annotations

import copy
import re
from datetime import date
from pathlib import Path

from campaign_fixture import PROSE, VALID
from campaign_manager.briefing_prose import parse_prose
from campaign_manager.campaign_manager import initial_state, parse_campaign
from campaign_manager.models import CampaignDefinition
from campaign_manager.theatre_dossier import REWARDS, SHOP_PRICES, UPGRADE_PRICES, guide_blocks, shop_lines, theatre_dossier
from deck_pdf_check import assert_pdf_matches_deck
from pptx import Presentation
from veaf_libs.i18n import language

_REPO = Path(__file__).resolve().parents[3]


def _campaign() -> CampaignDefinition:
    raw = copy.deepcopy(VALID)
    raw["campaign"].update({"mode": "persistent", "objectives": []})
    raw["zones"][2]["kind"] = "factory"
    campaign, issues = parse_campaign(raw)
    assert campaign is not None, issues
    return campaign


def _slides(path: Path) -> list[str]:
    deck = Presentation(str(path))
    texts = []
    for slide in deck.slides:
        texts.append("\n".join(shape.text_frame.text for shape in slide.shapes if shape.has_text_frame))
    return texts


class TestTheDossier:
    def test_its_pages_and_nothing_of_a_mission_of_the_day(self, tmp_path: Path) -> None:
        campaign = _campaign()
        raw = copy.deepcopy(PROSE)
        raw["axes"] = [{"title": "Couper Senaki de son usine", "text": "Prendre le nœud."}]
        prose, issues = parse_prose(raw, campaign.missions, 1)
        assert prose is not None, issues
        with language("fr"):
            report = theatre_dossier(
                campaign,
                initial_state(campaign),
                prose,
                tmp_path,
                {"Kobuleti": 1, "Senaki": 2},
                day=date(2026, 11, 17),
                cache_dir=tmp_path,
                fetch=lambda _url: None,
            )
            slides = _slides(report.path)
        whole = "\n".join(slides)
        assert report.path.name == "Kolkhida_dossier-de-theatre.pptx"
        assert "État au 17/11/2026" in slides[0]
        assert "campagne persistante" in slides[0]
        for title in (
            "2. Situation stratégique",
            "3. Carte du réseau",
            "4. Le réseau ennemi",
            "5. Défenses aériennes connues",
            "6. Axes d'effort",
            "7. Nos moyens",
            "8. Plan radio",
            "9. Guide du joueur",
        ):
            assert title in whole, title
        assert "1. Couper Senaki de son usine" in whole
        assert "adaptez-vous" in whole
        # the red factory feeds Senaki, named with its waypoint
        assert "Gudauta depot alimente Senaki (WP 2)." in whole
        assert "Senaki (WP 2)" in whole
        for absent in ("Mission 1", "ATO", "Météo", "Plan de navigation"):
            assert absent not in whole, absent

    def test_the_shop_prices_are_the_runtime_s(self) -> None:
        lua = (_REPO / "src/scripts/veaf/veafCampaignEconomy.lua").read_text(encoding="utf-8")
        block = lua[
            lua.index("veafCampaignEconomy.PRICES = {") : lua.index("}", lua.index("veafCampaignEconomy.PRICES = {"))
        ]
        assert dict((k, int(v)) for k, v in re.findall(r"(\w+) = (\d+)", block)) == SHOP_PRICES

    def test_the_rewards_and_the_fixed_upgrade_prices_are_the_runtime_s(self) -> None:
        # FIX-CAMPAIGN-ECONOMY-BALANCE: the guide quotes the rewards and the prices the game pays and asks
        campaign_lua = (_REPO / "src/scripts/veaf/veafCampaign.lua").read_text(encoding="utf-8")
        start = campaign_lua.index("  economy = {")
        block = campaign_lua[start : campaign_lua.index("\n  },", start)]
        defaults = {k: int(v) for k, v in re.findall(r"^\s+(\w+) = (\d+),", block, re.MULTILINE)}
        assert {key: defaults[key] for key in REWARDS} == REWARDS
        economy_lua = (_REPO / "src/scripts/veaf/veafCampaignEconomy.lua").read_text(encoding="utf-8")
        fixed = dict(re.findall(r'\{ id = "(\w+)",[^\n]*price = (\d+)', economy_lua))
        assert {key: int(value) for key, value in fixed.items()} == UPGRADE_PRICES

    def test_the_guide_gives_the_rewards_and_the_battery_prices(self) -> None:
        campaign = _campaign()
        with language("en"):
            whole = "\n".join(line for block in guide_blocks(campaign) for line in block.paragraphs)
            assert "SAM 30" in whole
            assert "aircraft 50" in whole
            assert "building of an enemy zone 100" in whole
            assert "brought back to the MASH 200" in whole
            assert "NASAMS 2000" in whole and "Patriot 5000" in whole
            economy = campaign.dynamic.setdefault("economy", {})
            economy["kill_sam"] = 45
            economy["prices"] = {"patriot": 6000}
            whole = "\n".join(line for block in guide_blocks(campaign) for line in block.paragraphs)
            assert "SAM 45" in whole
            assert "Patriot 6000" in whole

    def test_the_shop_lists_the_flights_and_the_zone_upgrades(self) -> None:
        # FEAT-CAMPAIGN-SHOP-UPGRADES: the upgrades' prices are drawn in game, the guide gives their rule and limit
        campaign = _campaign()
        with language("fr"):
            lines = shop_lines(campaign)
            assert "Vol CAS : 500 crédits" in lines
            assert "Vol SEAD : 600 crédits" in lines
            assert any(line.startswith("Renforcer une zone") and "2 par zone" in line for line in lines)
            campaign.dynamic.setdefault("economy", {})["upgrades_per_zone"] = 3
            assert any("3 par zone" in line for line in shop_lines(campaign))


class TestTheKneeboard:
    def test_four_kinds_of_pages_written_and_rewritten_without_doubles(self, tmp_path: Path) -> None:
        from campaign_manager.theatre_kneeboard import KNEEBOARD_DIR, kneeboard_pages, write_kneeboard, zone_rows

        campaign = _campaign()
        numbers = {"Kobuleti": 1, "Senaki": 2}
        rows = zone_rows(campaign, numbers, elevation=lambda _x, _y: 30.48)
        assert [row[0] for row in rows] == ["1", "2", "—"]
        assert rows[0][3] == "100 ft"
        assert "N" in rows[0][2] and rows[0][4] != "—", "an airfield carries its frequencies"
        with language("fr"):
            pages = kneeboard_pages(
                campaign,
                initial_state(campaign),
                tmp_path,
                numbers,
                elevation=lambda _x, _y: None,
                cache_dir=tmp_path,
                fetch=lambda _url: None,
            )
        assert list(pages)[0] == "01-briefing-campaign-network.jpg"
        assert any("campaign-zones" in name for name in pages)
        assert any("campaign-cheat-sheet" in name for name in pages)
        stale = tmp_path / KNEEBOARD_DIR / "09-briefing-campaign-old.jpg"
        stale.parent.mkdir(parents=True)
        stale.write_bytes(b"x")
        mine = tmp_path / KNEEBOARD_DIR / "00-veaf-calibration.png"
        mine.write_bytes(b"x")
        write_kneeboard(tmp_path, pages)
        assert not stale.exists()
        assert mine.exists(), "a page of another tool is left alone"


def test_a_pdf_of_the_same_pages_beside_the_dossier(tmp_path: Path) -> None:
    """David, 2026-11-17: every briefing written as a PowerPoint is written as a PDF too."""
    campaign = _campaign()
    with language("fr"):
        report = theatre_dossier(
            campaign,
            initial_state(campaign),
            None,
            tmp_path,
            {"Kobuleti": 1},
            day=date(2026, 11, 17),
            cache_dir=tmp_path,
            fetch=lambda _url: None,
        )
    assert_pdf_matches_deck(report.path, report.pdf)
