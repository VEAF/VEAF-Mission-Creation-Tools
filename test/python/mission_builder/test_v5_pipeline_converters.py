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
    _dedicated_matches_packed,
    _detect_radio_block_source,
    _extract_lua_table_text,
    _normalize_date,
    _parse_custom_preset_table,
    _parse_preset_table,
    _parse_radio_settings_entries,
    convert_aircraft_groups,
    convert_pipeline_file,
    convert_presets,
    convert_waypoints,
    convert_weather,
)
from presets_injector.presets_manager import Channel, PresetDefinition, RadioDefinition
from veaf_libs.i18n import t


def _load_faithful(v6_path: Path) -> dict:
    """Load the faithful presets file (``presets.v5.yaml`` when it exists, else ``presets.yaml``).

    FEAT-CONVERTV5-PLAN-PRESETS: ``convert_presets`` writes a lean plan
    (``presets.yaml``) plus a faithful copy (``presets.v5.yaml``) whenever a
    shared channel list exists. Assertions on the full per-aircraft output
    target the faithful copy.
    """
    faithful = v6_path.with_name(f"{v6_path.stem}.v5{v6_path.suffix}")
    target = faithful if faithful.exists() else v6_path
    return yaml.safe_load(target.read_text())


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
        # The warning names the version and the TODO to replace (language-agnostic).
        self.assertTrue(any("Clear" in w and "TODO" in w for w in warnings), warnings)

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
        data = _load_faithful(v6)
        self.assertIn("radios_collection", data)
        self.assertIn("blue_radios", data["radios_collection"])

    def test_blue_and_red_both_generated(self) -> None:
        lua = 'radioPresetsBlue = { ["##RADIO1_01##"] = 251.0 }\nradioPresetsRed  = { ["##RADIO1_01##"] = 250.0 }'
        v5 = self._write_lua(lua)
        v6 = self.tmp / "presets.yaml"
        convert_presets(v5, v6)
        data = _load_faithful(v6)
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


class TestDetectRadioBlockSource(unittest.TestCase):
    def test_uhf_detected(self) -> None:
        block = '{ ["channels"] = { [1] = radioPresetsBlue["##RADIO1_01##"] } }'
        self.assertEqual(_detect_radio_block_source(block), "uhf")

    def test_vhf_detected(self) -> None:
        block = '{ ["channels"] = { [1] = radioPresetsBlue["##RADIO2_01##"] } }'
        self.assertEqual(_detect_radio_block_source(block), "vhf")

    def test_fm_detected(self) -> None:
        block = '{ ["channels"] = { [1] = radioPresetsBlue["##RADIO3_01##"] } }'
        self.assertEqual(_detect_radio_block_source(block), "fm")

    def test_warbird_detected(self) -> None:
        block = '{ ["channels"] = { [1] = radioPresetsWarbirdBlue["##RADIO_FuG16_01##"] } }'
        self.assertEqual(_detect_radio_block_source(block), "warbird")

    def test_hardcoded_returns_none(self) -> None:
        block = '{ ["channels"] = { [1] = 284.000, [2] = 251.0 } }'
        self.assertIsNone(_detect_radio_block_source(block))

    def test_red_coalition_uhf_detected(self) -> None:
        block = '{ ["channels"] = { [1] = radioPresetsRed["##RADIO1_01##"] } }'
        self.assertEqual(_detect_radio_block_source(block), "uhf")


class TestParseRadioSettingsEntries(unittest.TestCase):
    _LUA_STANDARD = """
radioSettings = {
    ["blue F-16C"] = {
        type = "F-16C_50",
        coalition = "blue",
        country = nil,
        ["Radio"] = {
            [1] = { ["channels"] = { [1] = radioPresetsBlue["##RADIO1_01##"] } },
            [2] = { ["channels"] = { [1] = radioPresetsBlue["##RADIO2_01##"] } },
            [3] = { ["channels"] = { [1] = radioPresetsBlue["##RADIO3_01##"] } },
        },
    },
}
"""

    _LUA_WARBIRD = """
radioSettings = {
    ["blue Bf-109K-4"] = {
        type = "Bf-109K-4",
        coalition = "blue",
        country = nil,
        ["Radio"] = {
            [1] = { ["channels"] = { [1] = radioPresetsWarbirdBlue["##RADIO_FuG16_01##"] } },
        },
    },
}
"""

    _LUA_VHF_PRIMARY = """
radioSettings = {
    ["blue I-16"] = {
        type = "I-16",
        coalition = "blue",
        country = nil,
        ["Radio"] = {
            [1] = { ["channels"] = { [1] = radioPresetsBlue["##RADIO2_01##"] } },
        },
    },
}
"""

    _LUA_TYPE_PATTERN = """
radioSettings = {
    ["blue FW-190s"] = {
        typePattern = "FW[-]190.*",
        coalition = "blue",
        country = nil,
        ["Radio"] = {
            [1] = { ["channels"] = { [1] = radioPresetsWarbirdBlue["##RADIO_FuG16_01##"] } },
        },
    },
}
"""

    _LUA_HARDCODED = """
radioSettings = {
    ["blue AJS37"] = {
        type = "AJS37",
        coalition = "blue",
        country = nil,
        ["Radio"] = {
            [1] = { ["channels"] = { [1] = 284.000, [2] = 271.500 } },
        },
    },
}
"""

    def test_standard_entry_parsed(self) -> None:
        entries = _parse_radio_settings_entries(self._LUA_STANDARD)
        self.assertEqual(len(entries), 1)
        e = entries[0]
        self.assertEqual(e.aircraft, "F-16C_50")
        self.assertFalse(e.is_pattern)
        self.assertEqual(e.coalition, "blue")
        self.assertEqual(e.radio_sources[1], "uhf")
        self.assertEqual(e.radio_sources[2], "vhf")
        self.assertEqual(e.radio_sources[3], "fm")

    def test_warbird_entry_parsed(self) -> None:
        entries = _parse_radio_settings_entries(self._LUA_WARBIRD)
        self.assertEqual(len(entries), 1)
        e = entries[0]
        self.assertEqual(e.aircraft, "Bf-109K-4")
        self.assertEqual(e.radio_sources[1], "warbird")

    def test_vhf_primary_entry_parsed(self) -> None:
        entries = _parse_radio_settings_entries(self._LUA_VHF_PRIMARY)
        self.assertEqual(len(entries), 1)
        e = entries[0]
        self.assertEqual(e.aircraft, "I-16")
        self.assertEqual(e.radio_sources[1], "vhf")

    def test_type_pattern_entry_parsed(self) -> None:
        entries = _parse_radio_settings_entries(self._LUA_TYPE_PATTERN)
        self.assertEqual(len(entries), 1)
        e = entries[0]
        self.assertTrue(e.is_pattern)
        self.assertEqual(e.aircraft, "FW[-]190.*")
        self.assertEqual(e.radio_sources[1], "warbird")

    def test_hardcoded_entry_radio_source_is_none(self) -> None:
        entries = _parse_radio_settings_entries(self._LUA_HARDCODED)
        self.assertEqual(len(entries), 1)
        self.assertIsNone(entries[0].radio_sources.get(1))

    def test_no_radio_settings_returns_empty(self) -> None:
        entries = _parse_radio_settings_entries("x = 1")
        self.assertEqual(entries, [])


class TestConvertPresetsPerAircraftAssignments(unittest.TestCase):
    """convert_presets must generate per-aircraft assignments for non-standard radio layouts."""

    def setUp(self) -> None:
        self._tmp_dir = tempfile.TemporaryDirectory()
        self.tmp = Path(self._tmp_dir.name)

    def tearDown(self) -> None:
        self._tmp_dir.cleanup()

    def _write_lua(self, content: str) -> Path:
        p = self.tmp / "radioSettings.lua"
        p.write_text(content, encoding="utf-8")
        return p

    def _lua(self, extra_settings: str = "") -> str:
        return (
            'radioPresetsBlue = { ["##RADIO1_01##"] = 284.0, ["##RADIO2_01##"] = 134.0 }\n'
            'radioPresetsWarbirdBlue = { ["##RADIO_FuG16_01##"] = 38.4 }\n' + extra_settings
        )

    def test_warbird_aircraft_assigned_warbird_preset(self) -> None:
        lua = self._lua("""
radioSettings = {
    ["blue Bf109"] = { type = "Bf-109K-4", coalition = "blue", country = nil,
        ["Radio"] = { [1] = { ["channels"] = { [1] = radioPresetsWarbirdBlue["##RADIO_FuG16_01##"] } } }
    },
}
""")
        v5 = self._write_lua(lua)
        v6 = self.tmp / "presets.yaml"
        convert_presets(v5, v6)
        data = _load_faithful(v6)
        self.assertEqual(data["presets_assignments"]["blue"]["plane"].get("Bf-109K-4"), "blue_warbird")
        self.assertNotIn("Bf-109K-4", data["presets_assignments"]["blue"]["helicopter"])

    def test_vhf_primary_aircraft_gets_vhf_primary_preset(self) -> None:
        lua = self._lua("""
radioSettings = {
    ["blue I16"] = { type = "I-16", coalition = "blue", country = nil,
        ["Radio"] = { [1] = { ["channels"] = { [1] = radioPresetsBlue["##RADIO2_01##"] } } }
    },
}
""")
        v5 = self._write_lua(lua)
        v6 = self.tmp / "presets.yaml"
        convert_presets(v5, v6)
        data = _load_faithful(v6)
        assignments = data["presets_assignments"]["blue"]["plane"]
        self.assertEqual(assignments.get("I-16"), "blue_vhf_primary")
        # Preset must also be created
        self.assertIn("blue_vhf_primary", data["presets_collection"]["blue_presets"])

    def test_vhf_primary_preset_uses_vhf_radio(self) -> None:
        lua = self._lua("""
radioSettings = {
    ["blue I16"] = { type = "I-16", coalition = "blue", country = nil,
        ["Radio"] = { [1] = { ["channels"] = { [1] = radioPresetsBlue["##RADIO2_01##"] } } }
    },
}
""")
        v5 = self._write_lua(lua)
        v6 = self.tmp / "presets.yaml"
        convert_presets(v5, v6)
        data = _load_faithful(v6)
        preset = data["presets_collection"]["blue_presets"]["blue_vhf_primary"]
        self.assertEqual(preset["radios"]["radio_1"], "radio_vhf_blue")

    def test_standard_aircraft_not_duplicated_in_assignments(self) -> None:
        lua = self._lua("""
radioSettings = {
    ["blue F16"] = { type = "F-16C_50", coalition = "blue", country = nil,
        ["Radio"] = {
            [1] = { ["channels"] = { [1] = radioPresetsBlue["##RADIO1_01##"] } },
            [2] = { ["channels"] = { [1] = radioPresetsBlue["##RADIO2_01##"] } },
        }
    },
}
""")
        v5 = self._write_lua(lua)
        v6 = self.tmp / "presets.yaml"
        convert_presets(v5, v6)
        data = _load_faithful(v6)
        assignments = data["presets_assignments"]["blue"]["plane"]
        # F-16C_50 starts with UHF radio → covered by "all", no explicit entry needed
        self.assertNotIn("F-16C_50", assignments)

    def test_type_pattern_entry_assigned(self) -> None:
        lua = self._lua("""
radioSettings = {
    ["blue FW190s"] = { typePattern = "FW[-]190.*", coalition = "blue", country = nil,
        ["Radio"] = { [1] = { ["channels"] = { [1] = radioPresetsWarbirdBlue["##RADIO_FuG16_01##"] } } }
    },
}
""")
        v5 = self._write_lua(lua)
        v6 = self.tmp / "presets.yaml"
        convert_presets(v5, v6)
        data = _load_faithful(v6)
        assignments = data["presets_assignments"]["blue"]["plane"]
        self.assertEqual(assignments.get("FW[-]190.*"), "blue_warbird")
        self.assertNotIn("FW[-]190.*", data["presets_assignments"]["blue"]["helicopter"])

    def test_helicopter_aircraft_assigned_to_helicopter_category(self) -> None:
        lua = self._lua("""
radioSettings = {
    ["blue Mi8"] = { type = "Mi-8MT", coalition = "blue", country = nil,
        ["Radio"] = {
            [1] = { ["channels"] = { [1] = radioPresetsBlue["##RADIO2_01##"] } },
        }
    },
}
""")
        v5 = self._write_lua(lua)
        v6 = self.tmp / "presets.yaml"
        convert_presets(v5, v6)
        data = _load_faithful(v6)
        self.assertEqual(data["presets_assignments"]["blue"]["helicopter"].get("Mi-8MT"), "blue_vhf_primary")
        self.assertNotIn("Mi-8MT", data["presets_assignments"]["blue"]["plane"])

    def test_hardcoded_entry_gets_dedicated_preset(self) -> None:
        # A hardcoded literal is bespoke → reproduced verbatim in a dedicated preset.
        lua = self._lua("""
radioSettings = {
    ["blue AJS37"] = { type = "AJS37", coalition = "blue", country = nil,
        ["Radio"] = { [1] = { ["channels"] = { [1] = 284.000 } } }
    },
}
""")
        v5 = self._write_lua(lua)
        v6 = self.tmp / "presets.yaml"
        convert_presets(v5, v6)
        data = _load_faithful(v6)
        self.assertEqual(data["presets_assignments"]["blue"]["plane"].get("AJS37"), "blue_ajs37")
        radio = data["radios_collection"]["blue_radios"]["radio_blue_ajs37_1"]
        self.assertEqual(radio["channels"][1], 284.0)

    def test_type_pattern_vhf_primary_assigned(self) -> None:
        lua = self._lua("""
radioSettings = {
    ["blue VHF types"] = { typePattern = "F16.*", coalition = "blue", country = nil,
        ["Radio"] = { [1] = { ["channels"] = { [1] = radioPresetsBlue["##RADIO2_01##"] } } }
    },
}
""")
        v5 = self._write_lua(lua)
        v6 = self.tmp / "presets.yaml"
        convert_presets(v5, v6)
        data = _load_faithful(v6)
        self.assertEqual(data["presets_assignments"]["blue"]["plane"].get("F16.*"), "blue_vhf_primary")
        self.assertIn("blue_vhf_primary", data["presets_collection"]["blue_presets"])

    def test_fm_primary_aircraft_assigned_fm_primary_preset(self) -> None:
        lua = (
            'radioPresetsBlue = { ["##RADIO1_01##"] = 284.0, ["##RADIO2_01##"] = 134.0, ["##RADIO3_01##"] = 30.5 }\n'
            'radioPresetsWarbirdBlue = { ["##RADIO_FuG16_01##"] = 38.4 }\n'
            """
radioSettings = {
    ["blue Gazelles"] = { typePattern = "SA342.+", coalition = "blue", country = nil,
        ["Radio"] = { [1] = { ["channels"] = { [1] = radioPresetsBlue["##RADIO3_01##"] } } }
    },
}
"""
        )
        v5 = self._write_lua(lua)
        v6 = self.tmp / "presets.yaml"
        convert_presets(v5, v6)
        data = _load_faithful(v6)
        heli = data["presets_assignments"]["blue"]["helicopter"]
        self.assertEqual(heli.get("SA342.+"), "blue_fm_primary")
        self.assertIn("blue_fm_primary", data["presets_collection"]["blue_presets"])
        preset = data["presets_collection"]["blue_presets"]["blue_fm_primary"]
        self.assertEqual(preset["radios"]["radio_1"], "radio_fm_blue")

    def test_red_coalition_warbird_assigned(self) -> None:
        lua = (
            'radioPresetsRed = { ["##RADIO1_01##"] = 251.0, ["##RADIO2_01##"] = 127.0 }\n'
            'radioPresetsWarbirdRed = { ["##RADIO_FuG16_01##"] = 38.4 }\n'
            """
radioSettings = {
    ["red Bf109"] = { type = "Bf-109K-4", coalition = "red", country = nil,
        ["Radio"] = { [1] = { ["channels"] = { [1] = radioPresetsWarbirdRed["##RADIO_FuG16_01##"] } } }
    },
}
"""
        )
        v5 = self._write_lua(lua)
        v6 = self.tmp / "presets.yaml"
        convert_presets(v5, v6)
        data = _load_faithful(v6)
        self.assertEqual(data["presets_assignments"]["red"]["plane"].get("Bf-109K-4"), "red_warbird")


class TestConvertPresetsPlanGeneration(unittest.TestCase):
    """FEAT-RADIO-PRESET-PROJECTION-08 (ADR 0010): convert_presets emits a
    ``channel_lists`` preset plan by default from the v5 ``radioPresets*`` tables.
    """

    def setUp(self) -> None:
        self._tmp_dir = tempfile.TemporaryDirectory()
        self.tmp = Path(self._tmp_dir.name)

    def tearDown(self) -> None:
        self._tmp_dir.cleanup()

    def _write_lua(self, content: str) -> Path:
        p = self.tmp / "radioSettings.lua"
        p.write_text(content, encoding="utf-8")
        return p

    def test_no_shared_preset_table_yields_no_channel_lists(self) -> None:
        # No radioPresets{Blue,Red} table at all → nothing to factor; the output
        # must stay 100% legacy (pre-ticket-08 status quo), zero channel_lists.
        v5 = self._write_lua("x = 1")
        v6 = self.tmp / "presets.yaml"
        convert_presets(v5, v6)
        self.assertFalse(v6.exists())

    def test_shared_table_yields_channel_lists_by_default(self) -> None:
        lua = 'radioPresetsBlue = { ["##RADIO1_01##"] = 251.0, ["##RADIO2_01##"] = 131.0 }'
        v5 = self._write_lua(lua)
        v6 = self.tmp / "presets.yaml"
        convert_presets(v5, v6)
        data = yaml.safe_load(v6.read_text())
        self.assertIn("channel_lists", data)
        self.assertEqual(data["channel_lists"]["blue"]["primary_1"]["01"], 251.0)
        self.assertEqual(data["channel_lists"]["blue"]["primary_2"]["01"], 131.0)

    def test_radio3_maps_to_fm_supplement_role(self) -> None:
        lua = 'radioPresetsBlue = { ["##RADIO3_01##"] = 30.5 }'
        v5 = self._write_lua(lua)
        v6 = self.tmp / "presets.yaml"
        convert_presets(v5, v6)
        data = yaml.safe_load(v6.read_text())
        self.assertEqual(data["channel_lists"]["blue"]["fm_supplement"]["01"], 30.5)

    def test_fm_substitute_and_fm_supplement_are_independent_dicts(self) -> None:
        # RADIO3_* is exposed under both FM roles from the same source data, but
        # each role must get its own dict copy — mutating one must not silently
        # corrupt the other (Sourcery review: aliasing risk if a future caller
        # mutates one role's channel mapping, e.g. an override merge).
        lua = 'radioPresetsBlue = { ["##RADIO3_01##"] = 30.5 }'
        v5 = self._write_lua(lua)
        v6 = self.tmp / "presets.yaml"
        convert_presets(v5, v6)
        data = yaml.safe_load(v6.read_text())
        blue = data["channel_lists"]["blue"]
        self.assertIsNot(blue["fm_substitute"], blue["fm_supplement"])
        blue["fm_substitute"]["01"] = 999.0
        self.assertEqual(blue["fm_supplement"]["01"], 30.5)

    def test_channel_names_are_not_included_in_the_plan_literal_values(self) -> None:
        # ##RADIOx_NAME_yy## title entries must not leak into the plan as channels.
        lua = 'radioPresetsBlue = { ["##RADIO1_01##"] = 251.0, ["##RADIO1_NAME_01##"] = "Overlord" }'
        v5 = self._write_lua(lua)
        v6 = self.tmp / "presets.yaml"
        convert_presets(v5, v6)
        data = yaml.safe_load(v6.read_text())
        self.assertEqual(data["channel_lists"]["blue"]["primary_1"], {"01": 251.0})

    def test_standard_aircraft_covered_by_plan_gets_no_override(self) -> None:
        # A clean 1:1 layout is already reproduced by the packer's band-based
        # default from channel_lists alone — same "no duplicate assignment"
        # guarantee the legacy-only path already gave "all"-fallback aircraft.
        lua = self._lua_with_settings(
            """
radioSettings = {
    ["blue F16"] = { type = "F-16C_50", coalition = "blue", country = nil,
        ["Radio"] = {
            [1] = { ["channels"] = { [1] = radioPresetsBlue["##RADIO1_01##"] } },
            [2] = { ["channels"] = { [1] = radioPresetsBlue["##RADIO2_01##"] } },
        }
    },
}
"""
        )
        v5 = self._write_lua(lua)
        v6 = self.tmp / "presets.yaml"
        convert_presets(v5, v6)
        data = yaml.safe_load(v6.read_text())
        self.assertNotIn("F-16C_50", data.get("presets_assignments", {}).get("blue", {}).get("plane", {}))
        self.assertIn("channel_lists", data)

    def test_bespoke_aircraft_reproduced_by_packer_gets_no_override(self) -> None:
        # Mi-24P's real Radio layout entry (rotate_last_to_head) reproduces this
        # aircraft's rotation exactly from the plan alone -> no dedicated preset.
        lua = self._lua_with_settings(
            """
radioSettings = {
    ["blue Mi24"] = { type = "Mi-24P", coalition = "blue", country = nil,
        ["Radio"] = {
            [1] = {
                ["channels"] = {
                    [1] = radioPresetsBlue["##RADIO1_20##"],
                    [2] = radioPresetsBlue["##RADIO1_01##"],
                    [3] = radioPresetsBlue["##RADIO1_02##"],
                    [4] = radioPresetsBlue["##RADIO1_03##"],
                    [5] = radioPresetsBlue["##RADIO1_04##"],
                    [6] = radioPresetsBlue["##RADIO1_05##"],
                    [7] = radioPresetsBlue["##RADIO1_06##"],
                    [8] = radioPresetsBlue["##RADIO1_07##"],
                    [9] = radioPresetsBlue["##RADIO1_08##"],
                    [10] = radioPresetsBlue["##RADIO1_09##"],
                    [11] = radioPresetsBlue["##RADIO1_10##"],
                    [12] = radioPresetsBlue["##RADIO1_11##"],
                    [13] = radioPresetsBlue["##RADIO1_12##"],
                    [14] = radioPresetsBlue["##RADIO1_13##"],
                    [15] = radioPresetsBlue["##RADIO1_14##"],
                    [16] = radioPresetsBlue["##RADIO1_15##"],
                    [17] = radioPresetsBlue["##RADIO1_16##"],
                    [18] = radioPresetsBlue["##RADIO1_17##"],
                    [19] = radioPresetsBlue["##RADIO1_18##"],
                    [20] = radioPresetsBlue["##RADIO1_19##"],
                }
            },
        }
    },
}
""",
            radios="".join(f'["##RADIO1_{i:02d}##"] = {280.0 + i},\n' for i in range(1, 21)),
        )
        v5 = self._write_lua(lua)
        v6 = self.tmp / "presets.yaml"
        convert_presets(v5, v6)
        data = yaml.safe_load(v6.read_text())
        self.assertNotIn("Mi-24P", data.get("presets_assignments", {}).get("blue", {}).get("helicopter", {}))

    def test_divergent_aircraft_falls_back_with_warning(self) -> None:
        # A bespoke layout the packer's Radio layout does not reproduce
        # (OH58D's real-world head-slot fill diverges from the populated
        # `reserved_head_slots` primitive, see test_presets_fidelity.py) must
        # fall back to the legacy dedicated preset, with a warning naming it.
        lua = self._lua_with_settings(
            """
radioSettings = {
    ["blue OH58"] = { type = "OH58D", coalition = "blue", country = nil,
        ["Radio"] = {
            [1] = {
                ["channels"] = {
                    [1] = radioPresetsBlue["##RADIO1_01##"],
                    [2] = radioPresetsBlue["##RADIO1_01##"],
                    [3] = radioPresetsBlue["##RADIO1_02##"],
                }
            },
        }
    },
}
""",
            radios='["##RADIO1_01##"] = 300.0, ["##RADIO1_02##"] = 301.0,\n',
        )
        v5 = self._write_lua(lua)
        v6 = self.tmp / "presets.yaml"
        warnings = convert_presets(v5, v6)
        # OH58D is projectable at best effort → dropped from the plan, kept in the faithful copy.
        data = _load_faithful(v6)
        self.assertEqual(data["presets_assignments"]["blue"]["helicopter"].get("OH58D"), "blue_oh58d")
        self.assertTrue(any("OH58D" in w for w in warnings))

    @staticmethod
    def _lua_with_settings(settings: str, radios: str = "") -> str:
        return f'radioPresetsBlue = {{ ["##RADIO1_01##"] = 284.0, ["##RADIO2_01##"] = 134.0, {radios} }}\n' + settings


class TestDedicatedMatchesPackedStableKey(unittest.TestCase):
    """FEAT-RADIO-PRESET-PROJECTION-08 (Sourcery review): _dedicated_matches_packed
    must compare radios by a stable key (physical slot index), not by relying on
    ``packed_preset.radios.values()`` and ``sorted(dedicated_slots.items())``
    happening to iterate in the same order.
    """

    @staticmethod
    def _radio(name: str, number_freq_pairs: list[tuple[int, float]]) -> RadioDefinition:
        radio = RadioDefinition(name=name, radio_type="uhf")
        for number, freq in number_freq_pairs:
            radio.add_channel(Channel(name_or_number=number, freq=freq))
        return radio

    def test_matches_when_packed_radios_are_out_of_slot_order(self) -> None:
        # Two dedicated slots (1 and 2) with distinct content each. The packed
        # preset's internal dict inserts them in the OPPOSITE order (slot 2's
        # radio_2 first, slot 1's radio_1 second) -- a positional zip against
        # sorted(dedicated_slots.items()) would compare radio_1's content
        # against radio_2 and vice versa, and wrongly report a mismatch.
        dedicated_slots = {1: {1: 100.0}, 2: {1: 200.0}}
        packed = PresetDefinition(name="packed")
        packed.add_radio(self._radio("radio_2", [(1, 200.0)]))  # inserted first
        packed.add_radio(self._radio("radio_1", [(1, 100.0)]))  # inserted second
        self.assertTrue(_dedicated_matches_packed(dedicated_slots, packed))

    def test_mismatch_when_named_slot_missing(self) -> None:
        # Same radio COUNT as dedicated_slots (a pure positional zip would only
        # ever catch a COUNT mismatch), but the packed preset's radios are named
        # radio_1/radio_3 instead of radio_1/radio_2 -- slot 2 has no matching
        # named radio, so this must be reported as a mismatch, not silently
        # compared against whatever happens to be in the wrong position.
        dedicated_slots = {1: {1: 100.0}, 2: {1: 200.0}}
        packed = PresetDefinition(name="packed")
        packed.add_radio(self._radio("radio_1", [(1, 100.0)]))
        packed.add_radio(self._radio("radio_3", [(1, 999.0)]))
        self.assertFalse(_dedicated_matches_packed(dedicated_slots, packed))


class TestConvertAircraftGroups(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp_dir = tempfile.TemporaryDirectory()
        self.tmp = Path(self._tmp_dir.name)

    def tearDown(self) -> None:
        self._tmp_dir.cleanup()

    # A spawnable plane (B), a dynamic-slot template plane (C), a spawnable heli (B),
    # and an ordinary group (ignored).
    _SETTINGS_LUA = """
settings = {
    categories = {
        plane = {
            coalitions = {
                BLUE = {
                    countries = {
                        USA = {
                            groups = {
                                ["veafSpawn-CAP1"] = { groupId = 100, name = "veafSpawn-CAP1" },
                                ["F-15 Template"] = { groupId = 101, name = "F-15 Template", dynSpawnTemplate = true },
                                ["Ordinary CAS"] = { groupId = 102, name = "Ordinary CAS" }
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
                                ["veafSpawn-SAR1"] = { groupId = 200, name = "veafSpawn-SAR1" }
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

    def _convert(self) -> tuple[dict, dict]:
        v5 = self._write_settings(self._SETTINGS_LUA)
        spawnables = self.tmp / "spawnables.yaml"
        convert_aircraft_groups(v5, spawnables)
        dynamic = self.tmp / "dynamic-slot-templates.yaml"
        self.assertTrue(spawnables.exists())
        self.assertTrue(dynamic.exists())
        return yaml.safe_load(spawnables.read_text()), yaml.safe_load(dynamic.read_text())

    def test_spawnables_get_prefixed_groups(self) -> None:
        spawnables, _ = self._convert()
        planes = spawnables["airplanes"]["coalitions"]
        self.assertIn("veafSpawn-CAP1", planes["BLUE"]["USA"])
        self.assertNotIn("F-15 Template", planes["BLUE"]["USA"])  # dynSpawnTemplate → other file
        self.assertNotIn("Ordinary CAS", planes["BLUE"]["USA"])  # ignored

    def test_spawnable_helicopters_routed(self) -> None:
        spawnables, _ = self._convert()
        self.assertIn("veafSpawn-SAR1", spawnables["helicopters"]["coalitions"]["BLUE"]["USA"])

    def test_dynamic_templates_get_flagged_groups(self) -> None:
        _, dynamic = self._convert()
        planes = dynamic["airplanes"]["coalitions"]
        self.assertIn("F-15 Template", planes["BLUE"]["USA"])
        self.assertNotIn("veafSpawn-CAP1", planes["BLUE"]["USA"])  # spawnable → other file

    def test_review_warning_appended(self) -> None:
        v5 = self._write_settings(self._SETTINGS_LUA)
        warns = convert_aircraft_groups(v5, self.tmp / "spawnables.yaml")
        self.assertTrue(any(v5.name in w for w in warns))

    def test_invalid_lua_returns_warning(self) -> None:
        p = self.tmp / "bad.lua"
        p.write_text("this is not lua @@@", encoding="utf-8")
        warns = convert_aircraft_groups(p, self.tmp / "out.yaml")
        self.assertTrue(len(warns) >= 1)

    # The other real v5 export layout (older editor generation): flat named
    # collections, scalar coalition/country/category, groups keyed by numeric index
    # with the name *inside* the group (FIX-CONVERT-SPAWNABLES-FLAT-FORMAT).
    _SETTINGS_LUA_FLAT = """
settings =
{
    ["red planes"] =
    {
        coalition = "red",
        country = "russia",
        category = "plane",
        groups = {
            [01] = { ["groupId"] = 100, ["name"] = "veafSpawn-Mig21-Fox1" },
            [02] = { ["groupId"] = 101, ["name"] = "F-15 Template", ["dynSpawnTemplate"] = true },
            [03] = { ["groupId"] = 102, ["name"] = "Ordinary CAP" },
        },
    },
    ["blue helicopters"] =
    {
        coalition = "blue",
        country = "usa",
        category = "helicopter",
        groups = {
            [01] = { ["groupId"] = 200, ["name"] = "veafSpawn-SAR1" },
        },
    },
}
"""

    def _convert_flat(self) -> tuple[dict, dict]:
        p = self.tmp / "settings.lua"
        p.write_text(self._SETTINGS_LUA_FLAT, encoding="utf-8")
        spawnables = self.tmp / "spawnables.yaml"
        convert_aircraft_groups(p, spawnables)
        dynamic = self.tmp / "dynamic-slot-templates.yaml"
        return yaml.safe_load(spawnables.read_text()), yaml.safe_load(dynamic.read_text())

    def test_flat_spawnable_plane_extracted(self) -> None:
        spawnables, _ = self._convert_flat()
        planes = spawnables["airplanes"]["coalitions"]
        self.assertIn("veafSpawn-Mig21-Fox1", planes["red"]["russia"])
        self.assertNotIn("F-15 Template", planes["red"]["russia"])  # dynSpawnTemplate → other file
        self.assertNotIn("Ordinary CAP", planes["red"]["russia"])  # ignored

    def test_flat_spawnable_helicopter_routed(self) -> None:
        spawnables, _ = self._convert_flat()
        self.assertIn("veafSpawn-SAR1", spawnables["helicopters"]["coalitions"]["blue"]["usa"])

    def test_flat_dynamic_template_split(self) -> None:
        _, dynamic = self._convert_flat()
        self.assertIn("F-15 Template", dynamic["airplanes"]["coalitions"]["red"]["russia"])
        self.assertNotIn("veafSpawn-Mig21-Fox1", dynamic["airplanes"]["coalitions"]["red"]["russia"])


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
