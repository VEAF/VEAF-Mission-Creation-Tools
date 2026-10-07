"""A campaign mission's date, time and weather, fixed and moving on (FEAT-CAMPAIGN-MISSION-BRIEFING ticket 01)."""

from __future__ import annotations

import copy
import dataclasses
from datetime import date
from pathlib import Path

import pytest
import yaml
from campaign_fixture import VALID, mission_template
from campaign_manager.campaign_manager import initial_state, parse_campaign
from campaign_manager.campaign_worker import CampaignWorker
from campaign_manager.mission_conditions import (
    MIN_VISIBILITY,
    draw_weather,
    ground_visible,
    mission_date,
    mission_start,
    single_variant,
    start_seconds,
)
from campaign_manager.models import CampaignDefinition
from campaign_manager.next_mission import prepare_next_mission
from veaf_mission_mcp.mission_folder import open_mission
from veaf_mission_mcp.mission_settings import set_mission_date, set_weather
from weather_injector.weather.dcs_weather_converter import DCSWeatherConverter


def _campaign(**head: object) -> CampaignDefinition:
    raw = copy.deepcopy(VALID)
    raw["campaign"].update(head)
    campaign, issues = parse_campaign(raw)
    assert campaign is not None, issues
    return campaign


def _weather_table(weather: dict) -> dict:
    """The weather table DCS reads, as `set_weather` writes it."""
    return DCSWeatherConverter.to_dcs_lua_table(
        temperature_celsius=weather["temperature"],
        wind_speed_mps=weather["wind_speed"],
        wind_direction_degrees=weather["wind_direction"],
        visibility_meters=weather["visibility"],
        cloud_coverage=weather["cloud_type"],
        cloud_height_meters=weather["cloud_height"],
        precipitation=weather["precipitation"],
        fog_enabled=weather["fog_enabled"],
    )


class TestCampaignYaml:
    def test_a_start_date_and_a_start_time_are_read(self) -> None:
        campaign = _campaign(start_date="2016-06-01", start_time="sunset-45*60")
        assert (campaign.start_date, campaign.start_time) == (date(2016, 6, 1), "sunset-45*60")

    def test_yaml_may_have_made_the_date_a_date_already(self) -> None:
        raw = yaml.safe_load("campaign: {start_date: 2016-06-01}")
        assert _campaign(**raw["campaign"]).start_date == date(2016, 6, 1)

    def test_without_them_the_template_date_and_half_an_hour_after_sunrise(self) -> None:
        campaign = _campaign()
        assert (campaign.start_date, campaign.start_time) == (None, "sunrise+30*60")

    @pytest.mark.parametrize(
        ("key", "value"), [("start_date", "June 1st"), ("start_time", "dawn"), ("start_time", "25:00")]
    )
    def test_a_bad_value_is_an_error(self, key: str, value: str) -> None:
        raw = copy.deepcopy(VALID)
        raw["campaign"][key] = value
        campaign, issues = parse_campaign(raw)
        assert campaign is None
        assert any(key in issue.message for issue in issues)


class TestTheDate:
    def test_the_first_mission_takes_the_start_date_or_the_templates(self) -> None:
        state = initial_state(_campaign())
        assert mission_date(_campaign(start_date="2016-06-01"), state, date(2011, 1, 1)) == date(2016, 6, 1)
        assert mission_date(_campaign(), state, date(2011, 1, 1)) == date(2011, 1, 1)

    def test_each_mission_comes_the_day_after_the_last_one_flown(self) -> None:
        campaign = _campaign(start_date="2016-06-01")
        state = initial_state(campaign)
        state.mission = 2
        state.history = [{"mission": 1, "date": "2016-06-01"}, {"mission": 2, "date": "2016-06-05"}]
        assert mission_date(campaign, state, date(2011, 1, 1)) == date(2016, 6, 6)

    def test_a_state_that_recorded_no_date_counts_from_the_first(self) -> None:
        campaign = _campaign(start_date="2016-06-01")
        state = initial_state(campaign)
        state.mission = 2
        state.history = [{"mission": 1}, {"mission": 2}]
        assert mission_date(campaign, state, date(2011, 1, 1)) == date(2016, 6, 3)


class TestTheTime:
    def test_a_clock_time_and_a_solar_expression(self) -> None:
        assert start_seconds("06:30", 20000, 70000) == 6 * 3600 + 30 * 60
        assert start_seconds("sunrise+30*60", 20000, 70000) == 21800
        assert start_seconds("sunset-45*60", 20000, 70000) == 67300

    def test_sunrise_is_computed_on_the_campaigns_ground_not_at_damascus(self) -> None:
        # Kolkhida mission 1, 2016-06-01: sunrise 05:39 at Kobuleti, start 06:09 (22 140 s in the .miz)
        campaign = _campaign()
        kobuleti = dataclasses.replace(campaign, zones=(campaign.zone("Kobuleti"),))
        assert abs(mission_start(kobuleti, date(2016, 6, 1)) - 22140) <= 60
        # the shipped versions.yaml's Damascus (33.5, 35.5) on the Caucasus clock: 06:59, fifty minutes off
        damascus = dataclasses.replace(
            kobuleti,
            zones=(
                dataclasses.replace(
                    kobuleti.zones[0],
                    location=dataclasses.replace(kobuleti.zones[0].location, airfield=None, lat=33.5, lon=35.5),
                ),
            ),
        )
        assert abs(mission_start(kobuleti, date(2016, 6, 1)) - mission_start(damascus, date(2016, 6, 1))) > 15 * 60


class TestTheWeather:
    def test_every_drawn_weather_leaves_the_ground_visible(self) -> None:
        for name in ("Kolkhida", "Caucasus Front", "Western Georgia", "Falklands"):
            campaign = dataclasses.replace(_campaign(), name=name)
            for mission in range(1, 51):
                weather = draw_weather(campaign, mission, date(2016, 6, 1))
                assert ground_visible(_weather_table(weather)), (name, mission, weather)

    @pytest.mark.parametrize(
        ("cloud_type", "visibility", "fog", "rain"),
        [
            ("broken", 10000, False, False),
            ("overcast", 10000, False, False),
            ("few", MIN_VISIBILITY - 1000, False, False),
            ("few", 10000, True, False),
            ("few", 10000, False, True),
        ],
    )
    def test_the_check_refuses_what_hides_the_ground(
        self, cloud_type: str, visibility: int, fog: bool, rain: bool
    ) -> None:
        table = DCSWeatherConverter.to_dcs_lua_table(
            cloud_coverage=cloud_type,
            cloud_height_meters=2000,
            visibility_meters=visibility,
            fog_enabled=fog,
            precipitation=rain,
        )
        assert not ground_visible(table)

    def test_the_same_mission_draws_the_same_sky_and_the_next_one_another(self) -> None:
        campaign = _campaign()
        first = draw_weather(campaign, 1, date(2016, 6, 1))
        assert draw_weather(campaign, 1, date(2016, 6, 1)) == first
        assert any(draw_weather(campaign, n, date(2016, 6, 1)) != first for n in range(2, 5))

    def test_june_is_warmer_than_january(self) -> None:
        campaign = _campaign()
        assert (
            draw_weather(campaign, 1, date(2016, 6, 1))["temperature"]
            > draw_weather(campaign, 1, date(2016, 1, 1))["temperature"]
        )


class TestTheMissionFolder:
    def test_a_created_folder_carries_its_date_time_and_weather(self, tmp_path: Path) -> None:
        mission_template(tmp_path)
        campaign = _campaign(start_date="2016-06-01")
        report = prepare_next_mission(campaign, initial_state(campaign), tmp_path, tmp_path / "m1")
        assert report.conditions is not None
        _, content = open_mission(tmp_path / "m1")
        assert content["date"] == {"Day": 1, "Month": 6, "Year": 2016}
        assert content["start_time"] == report.conditions.start_time
        assert ground_visible(content["weather"])
        assert (
            content["weather"]["wind"]["atGround"]["dir"] == (report.conditions.weather["wind_direction"] + 180) % 360
        )

    def test_it_builds_one_mission_and_no_variant(self, tmp_path: Path) -> None:
        mission_template(tmp_path)
        assert (tmp_path / "template" / "src" / "versions.yaml").is_file()
        prepare_next_mission(_campaign(), initial_state(_campaign()), tmp_path, tmp_path / "m1")
        assert not (tmp_path / "m1" / "src" / "versions.yaml").exists()
        mission_yaml = yaml.safe_load((tmp_path / "m1" / "mission.yaml").read_text(encoding="utf-8"))
        assert mission_yaml["pipeline"] == {"weather": False}
        assert list(mission_yaml)[-1] == "pipeline"

    def test_the_pipeline_block_goes_last_and_swallows_no_module(self, tmp_path: Path) -> None:
        (tmp_path / "mission.yaml").write_text(
            "mission:\n  name: m\npipeline:\n  presets: true\nmodules:\n  UNITS: true\n  QRA: true\n"
            "  # pipeline:\n  #   weather: true\n  CAMPAIGN:\n    enable: true\n",
            encoding="utf-8",
        )
        single_variant(tmp_path)
        text = (tmp_path / "mission.yaml").read_text(encoding="utf-8")
        data = yaml.safe_load(text)
        assert data["pipeline"] == {"presets": True, "weather": False}
        assert list(data["modules"]) == ["UNITS", "QRA", "CAMPAIGN"]
        assert text.rstrip().endswith("weather: false")

    def test_a_refresh_keeps_what_was_set_since(self, tmp_path: Path) -> None:
        mission_template(tmp_path)
        campaign = _campaign(start_date="2016-06-01")
        prepare_next_mission(campaign, initial_state(campaign), tmp_path, tmp_path / "m1")
        set_mission_date(tmp_path / "m1", date="2016-06-03", start_time="14:00")
        set_weather(tmp_path / "m1", cloud_type="scattered", cloud_height=3000)
        _, before = open_mission(tmp_path / "m1")
        report = prepare_next_mission(campaign, initial_state(campaign), tmp_path, tmp_path / "m1")
        assert report.conditions is None
        _, after = open_mission(tmp_path / "m1")
        assert (after["date"], after["start_time"], after["weather"]) == (
            before["date"],
            before["start_time"],
            before["weather"],
        )


def test_applying_a_mission_records_the_date_it_was_flown_on(tmp_path: Path) -> None:
    folder = tmp_path / "campaign"
    folder.mkdir()
    raw = copy.deepcopy(VALID)
    raw["campaign"]["start_date"] = "2016-06-01"
    (folder / "campaign.yaml").write_text(yaml.safe_dump(raw), encoding="utf-8")
    mission_template(folder)
    worker = CampaignWorker(folder)
    worker.init()
    worker.next()
    set_mission_date(worker.mission_folder(1) / "mission", date="2016-06-02")
    state = yaml.safe_load((folder / "campaign-state.yaml").read_text(encoding="utf-8"))
    state["mission"] = 1
    for zone in state["zones"].values():
        for key in [k for k, v in zone.items() if v is None]:
            del zone[key]
    from luadata.io.write import write

    write(str(folder / "mission-01.state"), state, prefix="return ")
    issues, report = worker.apply(folder / "mission-01.state")
    assert report is not None, issues
    history = yaml.safe_load((folder / "campaign-state.yaml").read_text(encoding="utf-8"))["history"]
    assert history[-1]["date"] == "2016-06-02"
    _, report_next = worker.next()
    assert report_next is not None and report_next.conditions is not None
    assert report_next.conditions.date == date(2016, 6, 3)
