"""`set_weather` — the base mission's weather, FIX-SCRATCH-MISSION-FINDINGS ticket 19.

The blank mission `prepare --theatre` lays down has `clouds.preset = "Preset1"` with `base = 0`, and no
action wrote `weather`: GermanyCW-v6 patched it through a script on the Lua table. The action goes
through the converter the build's weather variants use, so it writes the same fields DCS reads (ticket
01 found the variants had written a table DCS ignores).
"""

from pathlib import Path

import pytest
from mission_tools.miz_tools import read_mission_folder
from veaf_mission_mcp.mission_settings import set_weather

_MISSION = """\
mission =
{
  ["weather"] =
  {
    ["clouds"] = {["preset"] = "Preset1", ["base"] = 0, ["thickness"] = 200, ["density"] = 0, ["iprecptns"] = 0},
    ["groundTurbulence"] = 0,
    ["cyclones"] = {},
    ["atmosphere"] = {["temperature"] = 20},
  },
  ["coalition"] = {["blue"] = {["country"] = {}}, ["red"] = {["country"] = {}}},
}
"""


def _folder(tmp_path: Path) -> Path:
    exploded = tmp_path / "src" / "mission"
    exploded.mkdir(parents=True)
    (exploded / "mission").write_text(_MISSION, encoding="utf-8")
    (tmp_path / "mission.yaml").write_text("modules: {}\n", encoding="utf-8")
    return tmp_path


def _weather(folder: Path) -> dict:
    return (read_mission_folder(folder).mission_content or {})["weather"]


class TestSetWeather:
    def test_the_cloud_base_is_no_longer_on_the_ground(self, tmp_path: Path) -> None:
        folder = _folder(tmp_path)
        set_weather(folder, cloud_type="broken", cloud_height=1500, temperature=12)
        weather = _weather(folder)
        assert weather["clouds"]["base"] > 0
        assert weather["clouds"]["preset"] != "Preset1"
        assert weather["season"]["temperature"] == 12

    def test_the_fields_dcs_ignores_are_dropped_and_the_others_kept(self, tmp_path: Path) -> None:
        folder = _folder(tmp_path)
        set_weather(folder, wind_speed=5, wind_direction=270)
        weather = _weather(folder)
        assert "atmosphere" not in weather
        assert weather["groundTurbulence"] == 0
        # A METAR-style "from" direction; the mission file stores where the wind blows to.
        assert weather["wind"]["atGround"] == {"speed": 5, "dir": 90}

    def test_a_metar_is_read(self, tmp_path: Path) -> None:
        folder = _folder(tmp_path)
        set_weather(folder, metar="EDDF 011200Z 27010KT 9999 SCT030 18/10 Q1015")
        weather = _weather(folder)
        assert weather["season"]["temperature"] == 18
        assert weather["qnh"] == pytest.approx(1015 * 0.750062, abs=0.1)

    def test_the_result_says_what_was_written(self, tmp_path: Path) -> None:
        result = set_weather(_folder(tmp_path), cloud_type="clear")
        assert "clouds" in result["weather"]
        assert result["durable"] is True

    def test_nothing_given_is_refused(self, tmp_path: Path) -> None:
        with pytest.raises(ValueError, match="no weather given"):
            set_weather(_folder(tmp_path))

    def test_an_unknown_cloud_type_is_refused(self, tmp_path: Path) -> None:
        with pytest.raises(ValueError, match="cloud_type"):
            set_weather(_folder(tmp_path), cloud_type="cumulonimbus")
