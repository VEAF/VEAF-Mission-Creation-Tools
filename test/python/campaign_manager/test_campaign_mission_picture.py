"""What the built mission says: flights, support, carrier, QRA, airfields (FEAT-CAMPAIGN-MISSION-BRIEFING ticket 02)."""

from __future__ import annotations

import os
from pathlib import Path

from campaign_fixture import built_mission
from campaign_manager.mission_picture import (
    MissionPicture,
    callsign,
    find_built_mission,
    megahertz,
    read_mission_picture,
)


def _picture(tmp_path: Path) -> MissionPicture:
    return read_mission_picture(built_mission(tmp_path / "mission"), "blue", tmp_path / "mission")


class TestTheFlights:
    def test_client_flights_without_the_templates(self, tmp_path: Path) -> None:
        flights = _picture(tmp_path).flights
        assert [(f.name, f.callsign, f.aircraft, f.count, f.base) for f in flights] == [
            ("Stennis Hornet", "Uzi 1", "FA-18C_hornet", 4, "Stennis"),
            ("Kobuleti Viper", "Colt 1", "F-16C_50", 2, "Kobuleti"),
        ]


class TestTheSupport:
    def test_each_support_aircraft_once_by_its_task(self, tmp_path: Path) -> None:
        support = _picture(tmp_path).support
        assert [(s.callsign, s.role, s.frequency, s.tacan) for s in support] == [
            ("Overlord 1-1", "awacs", 251.0, None),
            ("Arco 1-1", "tanker", 252.0, "52X"),
            ("Texaco 1-1", "carrier_tanker", 290.0, "64Y"),
        ]
        assert support[1].route == ((-345000.0, 555000.0), (-345000.0, 525000.0))

    def test_the_carrier_tower_is_vhf_with_its_tacan_icls_and_link4(self, tmp_path: Path) -> None:
        picture = _picture(tmp_path)
        (carrier,) = picture.carriers
        assert (carrier.name, carrier.tower, carrier.tacan, carrier.icls, carrier.link4) == (
            "Stennis",
            127.5,
            "74X",
            1,
            336.0,
        )
        assert carrier.tower is not None and 118 <= carrier.tower < 137  # the VHF airband
        assert carrier.heading == 270
        assert picture.plane_guard

    def test_the_airfields_of_the_players_side_with_dynamic_slots(self, tmp_path: Path) -> None:
        (kobuleti,) = _picture(tmp_path).airfields
        assert (kobuleti.name, kobuleti.uhf, kobuleti.vhf, kobuleti.tacan) == ("Kobuleti", 262.0, 133.0, "67X")


class TestTheRest:
    def test_the_wind_is_said_from_where_it_comes(self, tmp_path: Path) -> None:
        winds = _picture(tmp_path).weather.winds
        assert (winds["ground"].origin, winds["ground"].knots) == (270, 16)
        assert winds["8000"].origin == 270

    def test_the_clouds_cover_comes_from_the_preset(self, tmp_path: Path) -> None:
        weather = _picture(tmp_path).weather
        assert (weather.cover, weather.cloud_base, weather.rain) == ("scattered", 2500.0, False)

    def test_the_enemy_qra_zone_the_mission_declares(self, tmp_path: Path) -> None:
        picture = _picture(tmp_path)
        assert [(z.name, z.radius) for z in picture.qra_zones] == [("QRA Senaki", 45000.0)]
        assert picture.csar
        assert picture.bullseye == (-291014.0, 617414.0)

    def test_without_the_folder_the_miz_alone_is_read(self, tmp_path: Path) -> None:
        picture = read_mission_picture(built_mission(tmp_path / "mission"), "blue")
        assert (picture.qra_zones, picture.csar) == ([], False)
        assert len(picture.flights) == 2


def test_the_most_recent_build_is_found(tmp_path: Path) -> None:
    assert find_built_mission(tmp_path) is None
    old = tmp_path / "build" / "old.miz"
    old.parent.mkdir()
    old.write_bytes(b"x")
    os.utime(old, (1, 1))
    new = tmp_path / "Mission_20261007.miz"
    new.write_bytes(b"x")
    assert find_built_mission(tmp_path) == new


def test_frequencies_and_callsigns() -> None:
    assert (megahertz(127500000), megahertz(251), megahertz(None)) == (127.5, 251.0, None)
    assert callsign({"callsign": {"name": "Uzi11"}}) == "Uzi 1-1"
    assert callsign({"callsign": 101}) == "101"
