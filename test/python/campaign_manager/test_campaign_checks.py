"""What `campaign validate` warns about after the first server flight (FEAT-DYNAMIC-CAMPAIGN ticket 20)."""

from __future__ import annotations

import copy
from pathlib import Path
from typing import Any

from campaign_fixture import VALID
from campaign_manager.campaign_checks import persistent_support, template_presets, zones_beside_airfields
from campaign_manager.campaign_manager import parse_campaign
from campaign_manager.models import CampaignDefinition
from veaf_libs.i18n import t


def _campaign(head: dict[str, Any] | None = None, **changes: Any) -> CampaignDefinition:
    raw = copy.deepcopy(VALID)
    raw["campaign"].update(head or {})
    raw.update(changes)
    campaign, issues = parse_campaign(raw)
    assert campaign is not None, issues
    return campaign


def _messages(issues: list[Any]) -> list[str]:
    return [issue.message for issue in issues]


class TestAZoneBesideItsAirfield:
    def test_a_zone_set_next_to_an_airfield_is_warned_about(self) -> None:
        # 2026-11-16: Menagh, 2.3 km from Minakh's airfield, which DCS gave to blue on its own; the fixture's
        # Gudauta depot stands 1.8 km from Gudauta's, and is a plain outpost once it loses its kind
        raw = copy.deepcopy(VALID)
        del raw["zones"][2]["kind"]
        raw["campaign"]["objectives"] = [{"capture": ["Senaki"]}]
        campaign, _ = parse_campaign(raw)
        assert campaign is not None
        messages = _messages(zones_beside_airfields(campaign))
        assert len(messages) == 1
        assert "`Gudauta depot`" in messages[0] and "Gudauta" in messages[0]

    def test_a_zone_on_its_airfield_or_a_depot_beside_one_is_not(self) -> None:
        assert zones_beside_airfields(_campaign()) == []


class TestAPersistentCampaignsSupport:
    def test_no_awacs_nor_tanker_is_warned_about(self, tmp_path: Path) -> None:
        campaign = _campaign({"mode": "persistent", "objectives": []})
        assert _messages(persistent_support(campaign, tmp_path)) == [
            t("campaign.issue.no_support_assets"),
            t("campaign.issue.no_shop_tanker"),
        ]

    def test_named_assets_are_not(self, tmp_path: Path) -> None:
        campaign = _campaign(
            {"mode": "persistent", "objectives": []},
            dynamic={"support": {"assets": ["AWACS Magic"]}, "economy": {"tanker": "Tanker Texaco"}},
        )
        assert persistent_support(campaign, tmp_path) == []

    def test_a_multi_mission_campaign_is_not_concerned(self, tmp_path: Path) -> None:
        assert persistent_support(_campaign(), tmp_path) == []


class TestTheTemplatesRadioPlan:
    def test_a_channel_of_another_theatre_is_warned_about(self, tmp_path: Path) -> None:
        # 2026-11-16: the Syria campaign flew with the Caucasus plan; here a Caucasus campaign names Incirlik
        campaign = _campaign()
        presets = tmp_path / campaign.mission_template / "src" / "presets.yaml"
        presets.parent.mkdir(parents=True)
        plan = "channel_lists:\n  blue:\n    primary_2:\n      01: Incirlik\n      02: Batumi\n"
        presets.write_text(plan, encoding="utf-8")
        messages = _messages(template_presets(campaign, tmp_path))
        assert messages == [
            t("campaign.issue.foreign_airfield_preset", channel="Incirlik", other="Syria", theatre="Caucasus")
        ]


class TestTheTwoTankers:
    """David, 2026-11-17: a boom and a basket, not Texaco alone."""

    def _warnings(self, tmp_path: Path, monkeypatch: Any, types: dict[str, str]) -> list[str]:
        from campaign_manager import campaign_checks

        (tmp_path / "template" / "src" / "mission").mkdir(parents=True)
        monkeypatch.setattr(campaign_checks, "_group_types", lambda _template: types)
        campaign = _campaign(
            {"mode": "persistent", "objectives": []},
            dynamic={"support": {"assets": list(types)}, "economy": {"tanker": [n for n in types if "Tanker" in n]}},
        )
        return _messages(persistent_support(campaign, tmp_path))

    def test_a_boom_alone_is_warned_about(self, tmp_path: Path, monkeypatch: Any) -> None:
        types = {"AWACS Magic": "E-3A", "Tanker Texaco": "KC-135"}
        assert self._warnings(tmp_path, monkeypatch, types) == [t("campaign.issue.no_basket_tanker")]

    def test_a_boom_and_a_basket_are_not(self, tmp_path: Path, monkeypatch: Any) -> None:
        types = {"AWACS Magic": "E-3A", "Tanker Texaco": "KC-135", "Tanker Arco": "KC135MPRS"}
        assert self._warnings(tmp_path, monkeypatch, types) == []
