"""Tests for `add_player_slot` — the action that makes a from-scratch mission flyable.

The assertions here are the three that would have caught the 2026-08-14 slot David could not take:
`skill: Client`, `dynSpawnTemplate` cleared, and a group frequency rather than an inherited silence.
"""

from pathlib import Path

import pytest
from mission_tools.miz_tools import read_miz
from veaf_mission_mcp.describe_units import describe_units
from veaf_mission_mcp.player_slot import add_player_slot


def _slot_group(mission_content: dict, name: str) -> dict:
    for country in mission_content["coalition"]["blue"]["country"]:
        for group in country.get("plane", {}).get("group", []):
            if group["name"] == name:
                return group
    raise AssertionError(f"Slot {name!r} not found")


def _common(**over: object) -> dict:
    params: dict = {
        "coalition": "blue",
        "country_id": 2,
        "country_name": "USA",
        "name": "Player Viper",
        "unit_type": "F-16C_50",
        "position": {"x": 1000.0, "y": 2000.0},
    }
    params.update(over)
    return params


class TestAirStart:
    def test_creates_a_takeable_slot(self, sample_miz: Path) -> None:
        result = add_player_slot(sample_miz, **_common())
        assert result["start"] == "air"

        group = _slot_group(read_miz(sample_miz).mission_content, "Player Viper")
        unit = group["units"][0]
        # The three assertions that would have caught the 2026-08-14 defect:
        assert unit["skill"] == "Client"
        assert group["dynSpawnTemplate"] is False
        assert group["communication"] is True and group["frequency"] == 251.0

    def test_the_slot_shows_up_in_describe_units(self, sample_miz: Path) -> None:
        add_player_slot(sample_miz, **_common())
        described = describe_units(sample_miz, group_name="Player Viper")
        names = {g["name"] for g in described["groups"]}
        assert "Player Viper" in names

    def test_the_first_waypoint_is_a_turning_point(self, sample_miz: Path) -> None:
        add_player_slot(sample_miz, **_common())
        wp = _slot_group(read_miz(sample_miz).mission_content, "Player Viper")["route"]["points"][0]
        assert (wp["type"], wp["action"]) == ("Turning Point", "Turning Point")
        assert "airdromeId" not in wp  # an air start references no airfield

    def test_altitude_and_speed_are_converted(self, sample_miz: Path) -> None:
        add_player_slot(sample_miz, **_common(altitude_ft=10000, speed_kt=300))
        unit = _slot_group(read_miz(sample_miz).mission_content, "Player Viper")["units"][0]
        assert unit["alt"] == pytest.approx(3048.0)  # 10000 ft
        assert unit["speed"] == pytest.approx(154.3332)  # 300 kt


class TestGroundStart:
    def test_cold_writes_the_cold_waypoint_pair(self, sample_miz: Path) -> None:
        add_player_slot(sample_miz, **_common(start="ground-cold", parking="43", parking_id="16", airdrome_id=24))
        group = _slot_group(read_miz(sample_miz).mission_content, "Player Viper")
        wp = group["route"]["points"][0]
        assert (wp["type"], wp["action"]) == ("TakeOffParking", "From Parking Area")
        assert wp["airdromeId"] == 24
        assert (group["units"][0]["parking"], group["units"][0]["parking_id"]) == ("43", "16")

    def test_hot_writes_the_hot_waypoint_pair(self, sample_miz: Path) -> None:
        add_player_slot(sample_miz, **_common(start="ground-hot", parking="43", parking_id="16", airdrome_id=24))
        wp = _slot_group(read_miz(sample_miz).mission_content, "Player Viper")["route"]["points"][0]
        assert (wp["type"], wp["action"]) == ("TakeOffParkingHot", "From Parking Area Hot")

    def test_a_ground_start_without_a_spot_is_refused_naming_ticket_09(self, sample_miz: Path) -> None:
        with pytest.raises(ValueError, match="ticket 09"):
            add_player_slot(sample_miz, **_common(start="ground-cold"))

    def test_an_unknown_start_is_refused(self, sample_miz: Path) -> None:
        with pytest.raises(ValueError, match="Unknown start"):
            add_player_slot(sample_miz, **_common(start="carrier"))


class TestCoalitionsAndCopyPath:
    def test_the_country_lands_in_coalitions(self, sample_miz: Path) -> None:
        # Exercises ticket 01's writer from this path: a slot's country must be assigned to its side.
        add_player_slot(sample_miz, **_common())
        assert read_miz(sample_miz).mission_content["coalitions"]["blue"] == [2]

    def test_two_slots_same_country_list_it_once(self, sample_miz: Path) -> None:
        add_player_slot(sample_miz, **_common(name="Viper 1"))
        add_player_slot(sample_miz, **_common(name="Viper 2"))
        assert read_miz(sample_miz).mission_content["coalitions"]["blue"] == [2]
