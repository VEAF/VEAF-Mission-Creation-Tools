"""`set_weather` sets the wind wanted at a reference airfield and says the wind DCS will simulate.

FEAT-MISSION-WIND-CHECK tickets 03 and 04 c: *Marteau du Golan* (Syria, 2026-10-31) set 9 m/s on the
ground and announced 17 kt; DCS flew 24 kt at 10 m above Rosh Pina and 36 kt at 1,000 ft, and the
helicopter pilots met it with no warning.
"""

from __future__ import annotations

from pathlib import Path

import pytest
from mission_tools.miz_tools import read_mission_folder
from veaf_libs.dcs_airdromes import airdrome_id_for_name
from veaf_libs.dcs_wind import surface_wind
from veaf_mission_mcp.mission_settings import set_weather

_ROSH_PINA = airdrome_id_for_name("Syria", "Rosh Pina")


def _mission(category: str) -> str:
    return f"""\
mission =
{{
  ["weather"] = {{["groundTurbulence"] = 0}},
  ["coalition"] =
  {{
    ["blue"] = {{["country"] = {{[1] = {{["name"] = "CJTF Blue", ["{category}"] = {{["group"] = {{
      [1] = {{
        ["name"] = "Player-1",
        ["units"] = {{[1] = {{["skill"] = "Client", ["type"] = "UH-1H"}}}},
        ["route"] = {{["points"] = {{[1] = {{["airdromeId"] = {_ROSH_PINA}, ["x"] = 0, ["y"] = 0}}}}}},
      }},
    }}}}}}}}}},
    ["red"] = {{["country"] = {{}}}},
  }},
}}
"""


def _folder(tmp_path: Path, category: str = "helicopter") -> Path:
    exploded = tmp_path / "src" / "mission"
    exploded.mkdir(parents=True)
    (exploded / "mission").write_text(_mission(category), encoding="utf-8")
    (exploded / "theatre").write_text("Syria", encoding="utf-8")
    (tmp_path / "mission.yaml").write_text("modules: {}\n", encoding="utf-8")
    return tmp_path


def test_the_wind_is_set_for_the_player_departure_airfield(tmp_path: Path) -> None:
    folder = _folder(tmp_path, "plane")
    result = set_weather(folder, wind_speed=5, wind_direction=270)
    assert result["reference_airfield"]["name"] == "Rosh Pina"
    assert result["reference_airfield"]["source"] == "departure"
    wind = (read_mission_folder(folder).mission_content or {})["weather"]["wind"]
    simulated = surface_wind(wind, 264.6)
    assert simulated.speed == pytest.approx(5.0, abs=0.02)
    assert simulated.from_deg == pytest.approx(270.0, abs=0.5)
    assert result["simulated_wind"][0] == {
        "layer": "surface",
        "height_agl_m": 10,
        "altitude_msl_m": 275,
        "from_deg_true": 270,
        "knots": 10,
    }
    assert "warnings" not in result


def test_a_named_reference_airfield_wins_over_the_departure(tmp_path: Path) -> None:
    result = set_weather(_folder(tmp_path, "plane"), wind_speed=5, reference_airfield="Khalkhalah")
    assert result["reference_airfield"]["name"] == "Khalkhalah"


def test_the_default_for_10_kt_does_not_warn_the_helicopters(tmp_path: Path) -> None:
    result = set_weather(_folder(tmp_path), wind_speed=10 / 1.943844, wind_direction=270)
    assert "warnings" not in result


def test_the_marteau_du_golan_setting_warns_the_helicopters(tmp_path: Path) -> None:
    # The original setting, 9 / 11 / 14 m/s from 270, set by hand: 24 kt at the surface, 36 at 1,000 ft.
    folder = _folder(tmp_path)
    surface_knots = surface_wind(
        {"atGround": {"speed": 9, "dir": 90}, "at2000": {"speed": 11, "dir": 90}, "at8000": {"speed": 14, "dir": 90}},
        264.6,
    ).knots
    result = set_weather(
        folder,
        wind_speed=surface_knots / 1.943844,
        wind_direction=270,
        wind_speed_2000=11,
        wind_direction_2000=270,
        wind_speed_8000=14,
        wind_direction_8000=270,
    )
    assert result["weather"]["wind"]["atGround"]["speed"] == pytest.approx(9, abs=0.05)
    warnings = result["warnings"]
    assert any("helicopters at Rosh Pina" in warning and "20 kt" in warning for warning in warnings), warnings
    assert any("jet in the low layer" in warning for warning in warnings), warnings


def test_a_gust_and_a_veer_reach_the_mission(tmp_path: Path) -> None:
    folder = _folder(tmp_path, "plane")
    set_weather(folder, wind_speed=5, wind_direction=270, wind_gust=8, wind_veer=10)
    weather = (read_mission_folder(folder).mission_content or {})["weather"]
    assert weather["groundTurbulence"] > 0
    turn = (weather["wind"]["at2000"]["dir"] - weather["wind"]["atGround"]["dir"]) % 360
    assert turn == pytest.approx(10, abs=0.2)


def test_a_veer_past_30_is_refused(tmp_path: Path) -> None:
    with pytest.raises(ValueError, match="veer"):
        set_weather(_folder(tmp_path, "plane"), wind_speed=5, wind_veer=60)
