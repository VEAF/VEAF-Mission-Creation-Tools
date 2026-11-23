"""A persistent campaign's radio plan, David's of 2026-11-17 (FEAT-DYNAMIC-CAMPAIGN ticket 20)."""

from __future__ import annotations

import copy
from pathlib import Path
from typing import Any

import yaml
from campaign_fixture import VALID
from campaign_manager.campaign_manager import parse_campaign
from campaign_manager.models import CampaignDefinition
from campaign_manager.radio_plan import HOME_BASE, campaign_radio_plan, write_campaign_radio_plan

_PLAN = """channel_lists:
  blue:
    primary_1: # first V/UHF radio
      01: Archer
      09: Stennis

    primary_2: # second V/UHF radio
      01: Batumi
      02: Tbilisi-Lochini

    fm_supplement:
      01: 30

channels_collection:
    tactical:
      Stennis:
        title: Stennis
        freqs: { uhf: 225 }
    flights:
      Archer:
        title: Archer
        freqs: { uhf: 390, vhf: 120 }
      Astro:
        title: Astro
        freqs: { uhf: 391 }
      Arctic:
        title: Arctic
        freqs: { uhf: 391.5, vhf: 133.0 }
    airports-caucasus:
      Batumi:
        title: Batumi / 16X
        freqs: { uhf: 260.0, vhf: 131.0 }
      Kobuleti:
        title: Kobuleti / 67X
        freqs: { uhf: 262.0, vhf: 133.0 }
"""


def _campaign(**dynamic: Any) -> CampaignDefinition:
    raw = copy.deepcopy(VALID)
    raw["campaign"].update({"mode": "persistent", "objectives": []})
    raw["dynamic"] = dynamic
    campaign, issues = parse_campaign(raw)
    assert campaign is not None, issues
    return campaign


class TestThePlan:
    def test_vhf_home_base_our_airfields_then_flights_uhf_support_air_to_ground_then_flights(self) -> None:
        support = {"AWACS-Magic": {"title": "AWACS Magic", "freqs": {"uhf": 282.2}}}
        lists = campaign_radio_plan(_campaign(), yaml.safe_load(_PLAN), support)
        # blue holds Kobuleti; Senaki is red's. David, 2026-11-17: then the flights that have a VHF frequency, so a
        # flight on a tanker's UHF still talks on the VHF
        # Arctic's VHF is Kobuleti's: left off that radio, where it would double a channel (review of PR #1293)
        assert lists["primary_2"] == ["Home-Base", "Kobuleti", "Archer"]
        assert lists["primary_1"] == ["AWACS-Magic", "Air-Sol", "Archer", "Arctic", "Astro"]

    def test_home_base_is_a_frequency_no_airfield_uses(self) -> None:
        reference = (
            Path(__file__).resolve().parents[3] / "src/python/veaf-tools/veaf_libs/data/airfield-frequencies.yaml"
        )
        theatres = yaml.safe_load(reference.read_text(encoding="utf-8"))["theatres"]
        used = {
            (band, float(entry[band]))
            for airfields in theatres.values()
            for entry in airfields.values()
            for band in ("uhf", "vhf")
            if band in entry
        }
        assert not {(band, value) for band, value in HOME_BASE["freqs"].items()} & used


class TestTheFile:
    def test_written_into_the_folder_nothing_of_the_caucasus_left_on_the_radios(self, tmp_path: Path) -> None:
        presets = tmp_path / "src" / "presets.yaml"
        presets.parent.mkdir()
        presets.write_text(_PLAN, encoding="utf-8")
        assert write_campaign_radio_plan(_campaign(), tmp_path)
        written = yaml.safe_load(presets.read_text(encoding="utf-8"))
        radios = written["channel_lists"]["blue"]
        assert radios["primary_2"] == {1: "Home-Base", 2: "Kobuleti", 3: "Archer"}
        assert radios["primary_1"] == {1: "Air-Sol", 2: "Archer", 3: "Arctic", 4: "Astro"}
        assert radios["fm_supplement"] == {1: 30}
        assert written["channels_collection"]["campaign"]["Home-Base"]["title"] == "Home Base"
        # run again: the same file, the campaign collection not doubled
        before = presets.read_text(encoding="utf-8")
        assert not write_campaign_radio_plan(_campaign(), tmp_path)
        assert presets.read_text(encoding="utf-8") == before
