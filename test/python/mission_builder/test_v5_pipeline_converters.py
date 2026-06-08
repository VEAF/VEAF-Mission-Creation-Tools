"""Tests for v5_pipeline_converters — brace extraction and data conversion.

Covers:
- _extract_lua_table_text: simple, nested braces, strings with braces, not found
- _normalize_date: 12-digit DCS format → ISO, ISO passthrough
- convert_waypoints: speed_locked→speed_type:TAS, speed_locked false, no tables warning
- convert_weather: realweather→TODO+warning, ICAO callback, metar, moment resolution,
  date normalization, position remapping
"""

from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

import luadata
import yaml
from mission_builder.v5_pipeline_converters import (
    _extract_lua_table_text,
    _normalize_date,
    _parse_custom_preset_table,
    _parse_preset_table,
    convert_aircraft_groups,
    convert_pipeline_file,
    convert_presets,
    convert_waypoints,
    convert_weather,
)
from veaf_libs.i18n import t


class TestExtractLuaTableText(unittest.TestCase):
    """_extract_lua_table_text must correctly extract named tables from Lua source."""

    def test_simple_table(self) -> None:
        content = "waypoints = {a=1, b=2}"
        self.assertEqual(_extract_lua_table_text(content, "waypoints"), "{a=1, b=2}")

    def test_nested_braces(self) -> None:
        content = "settings = {outer = {inner = {deep = 1}}}"
        self.assertEqual(_extract_lua_table_text(content, "settings"), "{outer = {inner = {deep = 1}}}")

    def test_string_containing_braces_not_confused(self) -> None:
        # Braces inside a string literal must not count towards depth
        content = 'myTable = {name = "foo{bar}"}'
        self.assertEqual(_extract_lua_table_text(content, "myTable"), '{name = "foo{bar}"}')

    def test_table_not_found_returns_none(self) -> None:
        self.assertIsNone(_extract_lua_table_text("-- nothing here\n", "waypoints"))

    def test_newline_before_table_found(self) -> None:
        content = "\nwaypoints = {x=1}\n"
        self.assertEqual(_extract_lua_table_text(content, "waypoints"), "{x=1}")

    def test_single_quoted_string_braces(self) -> None:
        content = "t = {label = 'open{close}'}"
        self.assertEqual(_extract_lua_table_text(content, "t"), "{label = 'open{close}'}")


class TestNormalizeDate(unittest.TestCase):
    """_normalize_date converts DCS 12-digit dates to ISO 8601."""

    def test_dcs_12digit_to_iso(self) -> None:
        self.assertEqual(_normalize_date("202206290710"), "2022-06-29")

    def test_already_iso_passes_through(self) -> None:
        self.assertEqual(_normalize_date("2022-06-29"), "2022-06-29")

    def test_arbitrary_string_passes_through(self) -> None:
        self.assertEqual(_normalize_date("unknown"), "unknown")

    def test_different_valid_date(self) -> None:
        self.assertEqual(_normalize_date("202312251530"), "2023-12-25")


class TestConvertWaypoints(unittest.TestCase):
    """convert_waypoints must transform v5 Lua waypoint files to v6 YAML."""

    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.tmp = Path(self._tmp.name)

    def tearDown(self) -> None:
        self._tmp.cleanup()

    def _v5(self, text: str) -> Path:
        p = self.tmp / "waypointsSettings.lua"
        p.write_text(text, encoding="utf-8")
        return p

    def test_speed_locked_true_becomes_speed_type_tas(self) -> None:
        v5 = self._v5(
            'waypoints = {["WP01"] = {["type"]="Turning Point", ["action"]="Turning Point",'
            ' ["alt"]=1000, ["speed_locked"]=true}}'
        )
        v6 = self.tmp / "waypoints.yaml"
        convert_waypoints(v5, v6)
        self.assertTrue(v6.exists())
        wp = yaml.safe_load(v6.read_text())["waypoints"]["WP01"]
        self.assertEqual(wp.get("speed_type"), "TAS")
        self.assertNotIn("speed_locked", wp)

    def test_speed_locked_false_no_speed_type_added(self) -> None:
        v5 = self._v5(
            'waypoints = {["WP01"] = {["type"]="Turning Point", ["action"]="Turning Point",'
            ' ["alt"]=500, ["speed_locked"]=false}}'
        )
        v6 = self.tmp / "waypoints.yaml"
        convert_waypoints(v5, v6)
        wp = yaml.safe_load(v6.read_text())["waypoints"]["WP01"]
        self.assertNotIn("speed_type", wp)
        self.assertNotIn("speed_locked", wp)

    def test_settings_section_preserved(self) -> None:
        v5 = self._v5(
            'waypoints = {["WP01"] = {["type"]="Turning Point", ["alt"]=300}}\n'
            'settings = {["plan1"] = {["category"]="plane", ["waypoints"]={["WP01"]={}}}}\n'
        )
        v6 = self.tmp / "waypoints.yaml"
        convert_waypoints(v5, v6)
        data = yaml.safe_load(v6.read_text())
        self.assertIn("settings", data)
        self.assertIn("plan1", data["settings"])

    def test_no_tables_returns_warning_and_no_file(self) -> None:
        v5 = self._v5("-- empty file\n")
        v6 = self.tmp / "waypoints.yaml"
        warnings = convert_waypoints(v5, v6)
        self.assertTrue(len(warnings) > 0)
        self.assertFalse(v6.exists())


class TestConvertWeather(unittest.TestCase):
    """convert_weather must transform v5 JSON weather files to v6 YAML."""

    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.tmp = Path(self._tmp.name)

    def tearDown(self) -> None:
        self._tmp.cleanup()

    def _write_json(self, data: dict) -> Path:
        p = self.tmp / "versions.json"
        p.write_text(json.dumps(data), encoding="utf-8")
        return p

    def test_realweather_produces_todo_icao_and_warning(self) -> None:
        v5 = self._write_json({"targets": [{"version": "Clear", "realweather": True}]})
        v6 = self.tmp / "versions.yaml"
        warnings = convert_weather(v5, v6)
        self.assertTrue(v6.exists())
        data = yaml.safe_load(v6.read_text())
        self.assertEqual(data["versions"][0]["airport_icao"], "TODO")
        self.assertTrue(len(warnings) > 0)

    def test_realweather_icao_callback_used(self) -> None:
        v5 = self._write_json({"targets": [{"version": "Storm", "realweather": True}]})
        v6 = self.tmp / "versions.yaml"
        convert_weather(v5, v6, icao_callback=lambda _: "UGKO")
        data = yaml.safe_load(v6.read_text())
        self.assertEqual(data["versions"][0]["airport_icao"], "UGKO")

    def test_metar_preserved(self) -> None:
        metar = "METAR UGKO 130600Z 21010KT CAVOK"
        v5 = self._write_json({"targets": [{"version": "Nice", "weather": metar}]})
        v6 = self.tmp / "versions.yaml"
        convert_weather(v5, v6)
        data = yaml.safe_load(v6.read_text())
        self.assertEqual(data["versions"][0]["metar"], metar)

    def test_moment_reference_resolved(self) -> None:
        v5 = self._write_json(
            {
                "moments": {"dawn": "06:00"},
                "targets": [{"version": "Dawn", "moment": "dawn"}],
            }
        )
        v6 = self.tmp / "versions.yaml"
        convert_weather(v5, v6)
        data = yaml.safe_load(v6.read_text())
        self.assertEqual(data["versions"][0]["time"], "06:00")

    def test_date_normalized_from_dcs_format(self) -> None:
        v5 = self._write_json({"targets": [{"version": "Test", "date": "202206290710"}]})
        v6 = self.tmp / "versions.yaml"
        convert_weather(v5, v6)
        data = yaml.safe_load(v6.read_text())
        self.assertEqual(data["versions"][0]["date"], "2022-06-29")

    def test_position_lat_lon_remapped(self) -> None:
        v5 = self._write_json(
            {
                "position": {"lat": 41.8, "lon": 43.8, "tz": "Asia/Tbilisi"},
                "targets": [],
            }
        )
        v6 = self.tmp / "versions.yaml"
        convert_weather(v5, v6)
        data = yaml.safe_load(v6.read_text())
        pos = data["position"]
        self.assertEqual(pos["latitude"], 41.8)
        self.assertEqual(pos["longitude"], 43.8)
        self.assertEqual(pos["timezone"], "Asia/Tbilisi")

    def test_version_name_from_version_key(self) -> None:
        v5 = self._write_json({"targets": [{"version": "AutumnStorm"}]})
        v6 = self.tmp / "versions.yaml"
        convert_weather(v5, v6)
        data = yaml.safe_load(v6.read_text())
        self.assertEqual(data["versions"][0]["name"], "AutumnStorm")

    def test_version_name_fallback_to_name_key(self) -> None:
        v5 = self._write_json({"targets": [{"name": "SpringDay"}]})
        v6 = self.tmp / "versions.yaml"
        convert_weather(v5, v6)
        data = yaml.safe_load(v6.read_text())
        self.assertEqual(data["versions"][0]["name"], "SpringDay")


class TestParsePresetTable(unittest.TestCase):
    def test_parses_freq_keys(self) -> None:
        lua = 'radioPresetsBlue = { ["##RADIO1_01##"] = 251.0, ["##RADIO2_01##"] = 118.0 }'
        result = _parse_preset_table(lua, "radioPresetsBlue")
        self.assertEqual(result[1][1]["freq"], 251.0)
        self.assertEqual(result[2][1]["freq"], 118.0)

    def test_parses_name_keys(self) -> None:
        lua = 'radioPresetsBlue = { ["##RADIO1_01##"] = 251.0, ["##RADIO1_NAME_01##"] = "AWACS" }'
        result = _parse_preset_table(lua, "radioPresetsBlue")
        self.assertEqual(result[1][1]["title"], "AWACS")
        self.assertEqual(result[1][1]["freq"], 251.0)

    def test_missing_table_returns_empty(self) -> None:
        result = _parse_preset_table("x = 1", "radioPresetsBlue")
        self.assertEqual(result, {})

    def test_multiple_channels_ordered(self) -> None:
        lua = 'radioPresetsBlue = { ["##RADIO1_02##"] = 252.0, ["##RADIO1_01##"] = 251.0}'
        result = _parse_preset_table(lua, "radioPresetsBlue")
        self.assertIn(1, result[1])
        self.assertIn(2, result[1])


class TestParseCustomPresetTable(unittest.TestCase):
    def test_parses_warbird_freqs(self) -> None:
        lua = 'radioPresetsWarbirdBlue = { ["##RADIO_FuG16_01##"] = 38.4, ["##RADIO_FuG16_02##"] = 40.0}'
        result = _parse_custom_preset_table(lua, "radioPresetsWarbirdBlue")
        self.assertEqual(len(result), 2)
        self.assertIn(38.4, result)
        self.assertIn(40.0, result)

    def test_skips_name_and_base_keys(self) -> None:
        lua = (
            "radioPresetsWarbirdBlue = {"
            ' ["##RADIO_FuG16_01##"] = 38.4,'
            ' ["##RADIO_FuG16_NAME_01##"] = "Channel1",'
            ' ["##RADIO_FuG16_BASE##"] = 38.0'
            "}"
        )
        result = _parse_custom_preset_table(lua, "radioPresetsWarbirdBlue")
        self.assertEqual(len(result), 1)
        self.assertEqual(result[0], 38.4)

    def test_missing_table_returns_empty(self) -> None:
        result = _parse_custom_preset_table("x = 1", "radioPresetsWarbirdBlue")
        self.assertEqual(result, [])


class TestConvertPresets(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp_dir = tempfile.TemporaryDirectory()
        self.tmp = Path(self._tmp_dir.name)

    def tearDown(self) -> None:
        self._tmp_dir.cleanup()

    def _write_lua(self, content: str) -> Path:
        p = self.tmp / "radioSettings.lua"
        p.write_text(content, encoding="utf-8")
        return p

    def test_no_presets_warning(self) -> None:
        v5 = self._write_lua("x = 1")
        v6 = self.tmp / "presets.yaml"
        warns = convert_presets(v5, v6)
        self.assertTrue(any(t("convert_v5.warn.no_preset_tables", filename=v5.name) in w for w in warns))
        self.assertFalse(v6.exists())

    def test_blue_preset_generated(self) -> None:
        lua = 'radioPresetsBlue = { ["##RADIO1_01##"] = 251.0, ["##RADIO1_02##"] = 252.0}'
        v5 = self._write_lua(lua)
        v6 = self.tmp / "presets.yaml"
        convert_presets(v5, v6)
        self.assertTrue(v6.exists())
        data = yaml.safe_load(v6.read_text())
        self.assertIn("radios_collection", data)
        self.assertIn("blue_radios", data["radios_collection"])

    def test_blue_and_red_both_generated(self) -> None:
        lua = 'radioPresetsBlue = { ["##RADIO1_01##"] = 251.0 }\nradioPresetsRed  = { ["##RADIO1_01##"] = 250.0 }'
        v5 = self._write_lua(lua)
        v6 = self.tmp / "presets.yaml"
        convert_presets(v5, v6)
        data = yaml.safe_load(v6.read_text())
        self.assertIn("blue_radios", data["radios_collection"])
        self.assertIn("red_radios", data["radios_collection"])

    def test_warbird_preset_generates_warning(self) -> None:
        lua = (
            'radioPresetsBlue = { ["##RADIO1_01##"] = 251.0 }\n'
            'radioPresetsWarbirdBlue = { ["##RADIO_FuG16_01##"] = 38.4 }'
        )
        v5 = self._write_lua(lua)
        v6 = self.tmp / "presets.yaml"
        warns = convert_presets(v5, v6)
        self.assertTrue(any("blue_warbird" in w for w in warns))

    def test_review_warning_always_appended(self) -> None:
        lua = 'radioPresetsBlue = { ["##RADIO1_01##"] = 251.0 }'
        v5 = self._write_lua(lua)
        v6 = self.tmp / "presets.yaml"
        warns = convert_presets(v5, v6)
        self.assertTrue(any(v6.name in w for w in warns))


class TestConvertAircraftGroups(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp_dir = tempfile.TemporaryDirectory()
        self.tmp = Path(self._tmp_dir.name)

    def tearDown(self) -> None:
        self._tmp_dir.cleanup()

    _SETTINGS_LUA = """
settings = {
    categories = {
        plane = {
            coalitions = {
                BLUE = {
                    countries = {
                        USA = {
                            groups = {
                                CAP1 = { groupId = 100, name = "CAP1" },
                                CAS1 = { groupId = 101, name = "CAS1" }
                            }
                        }
                    }
                }
            }
        },
        helicopter = {
            coalitions = {
                BLUE = {
                    countries = {
                        USA = {
                            groups = {
                                SAR1 = { groupId = 200, name = "SAR1" }
                            }
                        }
                    }
                }
            }
        }
    }
}
"""

    def _write_settings(self, content: str) -> Path:
        p = self.tmp / "settings.lua"
        p.write_text(content, encoding="utf-8")
        return p

    def test_planes_structure(self) -> None:
        v5 = self._write_settings(self._SETTINGS_LUA)
        v6 = self.tmp / "templates.yaml"
        convert_aircraft_groups(v5, v6)
        self.assertTrue(v6.exists())
        data = yaml.safe_load(v6.read_text())
        self.assertIn("airplanes", data)
        self.assertIn("BLUE", data["airplanes"]["coalitions"])
        self.assertIn("USA", data["airplanes"]["coalitions"]["BLUE"])
        self.assertIn("CAP1", data["airplanes"]["coalitions"]["BLUE"]["USA"])

    def test_helicopters_structure(self) -> None:
        v5 = self._write_settings(self._SETTINGS_LUA)
        v6 = self.tmp / "templates.yaml"
        convert_aircraft_groups(v5, v6)
        data = yaml.safe_load(v6.read_text())
        self.assertIn("helicopters", data)
        self.assertIn("BLUE", data["helicopters"]["coalitions"])

    def test_review_warning_appended(self) -> None:
        v5 = self._write_settings(self._SETTINGS_LUA)
        v6 = self.tmp / "templates.yaml"
        warns = convert_aircraft_groups(v5, v6)
        self.assertTrue(any(v5.name in w for w in warns))

    def test_invalid_lua_returns_warning(self) -> None:
        p = self.tmp / "bad.lua"
        p.write_text("this is not lua @@@", encoding="utf-8")
        warns = convert_aircraft_groups(p, self.tmp / "out.yaml")
        self.assertTrue(len(warns) >= 1)


class TestConvertPipelineFileDispatch(unittest.TestCase):
    def test_unknown_step_returns_warning(self) -> None:
        warns = convert_pipeline_file("unknown_step", Path("x"), Path("y"))
        self.assertEqual(len(warns), 1)
        self.assertIn("unknown_step", warns[0])

    def test_dispatches_waypoints(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            base = Path(td)
            v5 = base / "waypointsSettings.lua"
            # Must have actual waypoint data to trigger file write
            v5.write_text(
                'waypoints = { WP1 = { name = "Alpha", x = 1000, y = 2000 } }',
                encoding="utf-8",
            )
            v6 = base / "waypoints.yaml"
            convert_pipeline_file("waypoints", v5, v6)
            self.assertTrue(v6.exists())

    def test_dispatches_presets(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            base = Path(td)
            v5 = base / "radioSettings.lua"
            v5.write_text("x = 1", encoding="utf-8")
            v6 = base / "presets.yaml"
            warns = convert_pipeline_file("presets", v5, v6)
            self.assertTrue(any(v5.name in w for w in warns))


if __name__ == "__main__":
    unittest.main()
