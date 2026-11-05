"""The wind of a mission as pilots meet it (FEAT-MISSION-WIND-CHECK tickets 03 and 04).

The *Marteau du Golan* setting (Syria, 2026-10-31): 9 / 11 / 14 m/s from 270, players departing Rosh
Pina. Measured in game, 24 kt at 10 m above Rosh Pina and 36 kt at 1,000 ft above it; the briefing
announced 17 kt.
"""

from __future__ import annotations

import shutil
from datetime import date
from pathlib import Path
from typing import Any

import pytest
from campaign_manager.mission_pages import weather_lines
from campaign_manager.mission_picture import MissionPicture, _weather, simulated_winds
from mission_tools.miz_tools import read_miz, write_miz
from veaf_libs import mission_wind
from veaf_libs.dcs_airdromes import airdrome_id_for_name
from veaf_libs.i18n import language
from veaf_libs.mission_wind import (
    HelicopterPlace,
    first_player_departure,
    has_helicopter_slot,
    helicopter_breaches,
    helicopter_places,
    layer_winds,
    resolve_reference_airfield,
    station_airfield,
)
from veaf_mission_mcp.inspect_built import inspect_built_mission

_MARTEAU = {"atGround": {"speed": 9, "dir": 90}, "at2000": {"speed": 11, "dir": 90}, "at8000": {"speed": 14, "dir": 90}}
_ROSH_PINA = airdrome_id_for_name("Syria", "Rosh Pina")
_BUILT = Path(__file__).resolve().parents[2] / "veaf-tools" / "demo-mission" / "veaf-demo-mission.miz"


def _content(category: str = "helicopter", wind: dict[str, Any] | None = None, skill: str = "Client") -> dict[str, Any]:
    group = {
        "name": "Hind-1",
        "units": {1: {"skill": skill, "type": "Mi-24P"}},
        "route": {"points": {1: {"airdromeId": _ROSH_PINA, "x": 0, "y": 0}, 2: {"x": 1000.0, "y": 2000.0}}},
    }
    return {
        "date": {"Year": 2026, "Month": 10, "Day": 31},
        "start_time": 36000,
        "weather": {"wind": wind or _MARTEAU, "visibility": {"distance": 80000}, "clouds": {"density": 0}},
        "coalition": {
            "blue": {"country": {1: {"name": "CJTF Blue", category: {"group": {1: group}}}}},
            "red": {"country": {}},
        },
    }


# --- the reference airfield --------------------------------------------------------------------------


def test_the_first_player_departure_is_read_from_the_route() -> None:
    assert first_player_departure(_content(), "Syria") == "Rosh Pina"
    assert first_player_departure(_content(skill="High"), "Syria") is None


def test_a_metar_station_on_the_map_is_its_airfield() -> None:
    assert station_airfield("Syria", "LLIB")["name"] == "Rosh Pina"
    assert station_airfield("Syria", "EGLL") is None
    assert station_airfield("Syria", "ZZZZ") is None
    assert station_airfield(None, "LLIB") is None


def test_the_station_wins_over_a_named_airfield() -> None:
    reference, warnings = resolve_reference_airfield("Syria", station="LLIB", reference_airfield="Khalkhalah")
    assert (reference.name, reference.source, warnings) == ("Rosh Pina", "metar_station", [])
    assert reference.as_dict() == {"name": "Rosh Pina", "elevation_m": 265, "source": "metar_station"}


# --- the layers -------------------------------------------------------------------------------------


def test_marteau_du_golan_simulates_24_kt_at_the_surface_and_36_at_1000_ft() -> None:
    surface, agl1000, *_ = layer_winds(_MARTEAU, 264.6)
    assert surface["knots"] == pytest.approx(24, abs=1)
    assert agl1000["knots"] == pytest.approx(36, abs=1)
    assert surface["from_deg_true"] == 270


def test_a_flight_level_close_to_the_ground_is_left_out() -> None:
    assert [row["layer"] for row in layer_winds(_MARTEAU, 2700.0)] == [
        "surface",
        "1000 ft AGL",
        "3000 ft AGL",
        "FL250",
    ]


def test_the_deck_says_the_simulated_wind_above_the_departure_magnetic() -> None:
    content = _content()
    weather = _weather(content["weather"], content, "Syria", date(2026, 10, 31))
    assert weather.wind_reference == "Rosh Pina"
    surface, agl1000 = weather.simulated[:2]
    assert surface.knots == pytest.approx(24, abs=1) and agl1000.knots == pytest.approx(36, abs=1)
    # About 5° east on the Golan: 270 true reads 265 magnetic.
    assert surface.origin == pytest.approx(265, abs=1)
    picture = MissionPicture(theatre="Syria", date=date(2026, 10, 31), start_time=0, weather=weather, bullseye=(0, 0))
    with language("fr"):
        line = weather_lines(picture)[1]
    assert line.startswith("Vent au-dessus de Rosh Pina : sol 265°M / 24 kt, 1 000 ft 265°M / 36 kt"), line


def test_the_deck_names_sea_level_in_the_reader_s_language() -> None:
    content = _content(skill="High")
    _, layers = simulated_winds(content, "Syria", date(2026, 10, 31))
    weather = _weather(content["weather"], content, "Syria", date(2026, 10, 31))
    assert weather.wind_reference == mission_wind.SEA_LEVEL and layers
    picture = MissionPicture(theatre="Syria", date=date(2026, 10, 31), start_time=0, weather=weather, bullseye=(0, 0))
    with language("fr"):
        assert weather_lines(picture)[1].startswith("Vent au-dessus de la mer : sol")


def test_inspect_built_mission_gives_the_simulated_wind_then_the_setting(tmp_path: Path) -> None:
    miz = tmp_path / "marteau.miz"
    shutil.copy2(_BUILT, miz)
    mission = read_miz(miz)
    mission.mission_content = _content()
    mission.theatre_content = "Syria"
    write_miz(mission, miz)
    lines = inspect_built_mission(miz)["weather"]
    simulated = next(line for line in lines if "wind DCS simulates above Rosh Pina" in line)
    assert "surface 265°M/24 kt" in simulated and "1000 ft AGL 265°M/36 kt" in simulated
    assert any(line.startswith("main: set (not the wind pilots meet): ground 270°T/17 kt") for line in lines), lines
    assert any("helicopters at Rosh Pina" in line for line in lines), lines


# --- the helicopter rule ----------------------------------------------------------------------------


def test_the_helicopter_rule_breaks_on_marteau_and_not_on_a_calm() -> None:
    places = [HelicopterPlace("Rosh Pina", 264.6)]
    (breach,) = helicopter_breaches(_MARTEAU, places)
    assert breach.peak.wind.knots > 30
    assert "helicopters at Rosh Pina" in breach.message() and "20 kt" in breach.message()
    calm = {key: {"speed": 2, "dir": 90} for key in ("atGround", "at2000", "at8000")}
    assert helicopter_breaches(calm, places) == []


def test_the_helicopter_places_are_departures_and_route_points_whose_ground_is_known() -> None:
    content = _content()
    assert has_helicopter_slot(content)
    assert not has_helicopter_slot(_content("plane"))
    assert [place.name for place in helicopter_places(content, "Syria")] == ["Rosh Pina (airfield of Hind-1)"]
    places = helicopter_places(content, "Syria", lambda x, y: 300.0)
    assert [(place.name, place.ground_msl) for place in places][1] == ("Hind-1 waypoint 1", 300.0)
