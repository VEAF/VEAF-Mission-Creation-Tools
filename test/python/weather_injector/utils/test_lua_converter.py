"""Tests for LuaToYamlConverter — static parsing helpers and _parse_lua_config."""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

import typer
from weather_injector.utils.lua_converter import LuaToYamlConverter


class TestGetString(unittest.TestCase):
    def test_double_quoted(self) -> None:
        self.assertEqual(LuaToYamlConverter._get_string('tz = "Asia/Damascus"', "tz"), "Asia/Damascus")

    def test_single_quoted(self) -> None:
        self.assertEqual(LuaToYamlConverter._get_string("tz = 'Europe/Moscow'", "tz"), "Europe/Moscow")

    def test_not_found_returns_none(self) -> None:
        self.assertIsNone(LuaToYamlConverter._get_string("x = 42", "tz"))

    def test_key_with_spaces(self) -> None:
        self.assertEqual(LuaToYamlConverter._get_string('version  =  "dawn"', "version"), "dawn")

    def test_first_occurrence(self) -> None:
        self.assertEqual(
            LuaToYamlConverter._get_string('a = "first"\na = "second"', "a"),
            "first",
        )


class TestGetNumber(unittest.TestCase):
    def test_integer(self) -> None:
        result = LuaToYamlConverter._get_number("lat = 33", "lat")
        self.assertEqual(result, 33)

    def test_float(self) -> None:
        result = LuaToYamlConverter._get_number("lat = 33.5", "lat")
        assert result is not None
        self.assertAlmostEqual(result, 33.5)

    def test_negative(self) -> None:
        result = LuaToYamlConverter._get_number("lon = -35.5", "lon")
        assert result is not None
        self.assertAlmostEqual(result, -35.5)

    def test_not_found_returns_none(self) -> None:
        self.assertIsNone(LuaToYamlConverter._get_number("x = 1", "lat"))


class TestGetBoolean(unittest.TestCase):
    def test_true(self) -> None:
        self.assertTrue(LuaToYamlConverter._get_boolean("clearsky = true", "clearsky"))

    def test_false(self) -> None:
        self.assertFalse(LuaToYamlConverter._get_boolean("clearsky = false", "clearsky"))

    def test_not_found_returns_false(self) -> None:
        self.assertFalse(LuaToYamlConverter._get_boolean("x = 1", "clearsky"))


class TestExtractTable(unittest.TestCase):
    def test_simple_table(self) -> None:
        content = 'position = { lat = 33.5, lon = 35.5, tz = "UTC" }'
        result = LuaToYamlConverter._extract_table(content, "position")
        self.assertIsNotNone(result)
        assert result is not None
        self.assertIn("lat", result)

    def test_nested_table(self) -> None:
        content = "a = { b = { c = 1 } }"
        result = LuaToYamlConverter._extract_table(content, "a")
        self.assertIsNotNone(result)
        assert result is not None
        self.assertIn("b", result)

    def test_not_found_returns_none(self) -> None:
        self.assertIsNone(LuaToYamlConverter._extract_table("x = 1", "position"))


class TestExtractList(unittest.TestCase):
    def test_list_of_tables(self) -> None:
        content = "targets = { { version = 'dawn' }, { version = 'dusk' } }"
        result = LuaToYamlConverter._extract_list(content, "targets")
        self.assertEqual(len(result), 2)

    def test_empty_list(self) -> None:
        # No "targets" key → returns empty
        result = LuaToYamlConverter._extract_list("x = {}", "targets")
        self.assertEqual(result, [])

    def test_not_found_returns_empty(self) -> None:
        result = LuaToYamlConverter._extract_list("x = {}", "targets")
        self.assertEqual(result, [])


class TestParseStringTable(unittest.TestCase):
    def test_parses_key_value_pairs(self) -> None:
        content = 'dawn = "sunrise+30*60", noon = "12:00"'
        result = LuaToYamlConverter._parse_string_table(content)
        self.assertEqual(result["dawn"], "sunrise+30*60")
        self.assertEqual(result["noon"], "12:00")

    def test_empty_table(self) -> None:
        result = LuaToYamlConverter._parse_string_table("{}")
        self.assertEqual(result, {})


class TestParseLuaConfig(unittest.TestCase):
    """Full _parse_lua_config with a realistic Lua snippet."""

    LUA_CONTENT = """
weatherAndTime = {
  position = {
    lat = 33.5,
    lon = 35.5,
    tz = "Asia/Damascus"
  },
  moments = {
    dawn = "sunrise+30*60",
    noon = "12:00",
    dusk = "sunset-10*60"
  },
  variableForMetar = "METAR",
  targets = {
    {
      version = "dawn",
      moment = "dawn",
      weather = "METAR OSDI 151420Z ...",
      dontSetToday = false,
      dontSetTodayYear = false,
      clearsky = false
    },
    {
      version = "dusk",
      moment = "dusk"
    }
  }
}
"""

    def test_parses_position(self) -> None:
        result = LuaToYamlConverter._parse_lua_config(self.LUA_CONTENT)
        self.assertIsNotNone(result)
        assert result is not None
        self.assertIn("position", result)
        self.assertAlmostEqual(result["position"]["latitude"], 33.5)
        self.assertAlmostEqual(result["position"]["longitude"], 35.5)
        self.assertEqual(result["position"]["timezone"], "Asia/Damascus")

    def test_parses_moments(self) -> None:
        result = LuaToYamlConverter._parse_lua_config(self.LUA_CONTENT)
        assert result is not None
        self.assertIn("moments", result)
        self.assertIn("dawn", result["moments"])

    def test_parses_variable_for_metar(self) -> None:
        result = LuaToYamlConverter._parse_lua_config(self.LUA_CONTENT)
        assert result is not None
        self.assertEqual(result["variableForMetar"], "METAR")

    def test_parses_versions(self) -> None:
        result = LuaToYamlConverter._parse_lua_config(self.LUA_CONTENT)
        assert result is not None
        self.assertIn("versions", result)
        self.assertEqual(len(result["versions"]), 2)
        self.assertEqual(result["versions"][0]["name"], "dawn")

    def test_version_with_weather_metar(self) -> None:
        result = LuaToYamlConverter._parse_lua_config(self.LUA_CONTENT)
        assert result is not None
        dawn = result["versions"][0]
        self.assertIn("weather", dawn)

    def test_empty_content_returns_none(self) -> None:
        result = LuaToYamlConverter._parse_lua_config("-- empty")
        self.assertIsNone(result)

    def test_convert_file_missing_raises(self) -> None:
        with self.assertRaises((typer.Abort, SystemExit, FileNotFoundError, OSError)):
            LuaToYamlConverter.convert_file(Path("/nonexistent/file.lua"))

    def test_convert_file_valid(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            lua_file = Path(td) / "config.lua"
            yaml_file = Path(td) / "config.yaml"
            lua_file.write_text(self.LUA_CONTENT, encoding="utf-8")
            result = LuaToYamlConverter.convert_file(lua_file, yaml_file)
            self.assertIsNotNone(result)
            self.assertTrue(yaml_file.exists())


if __name__ == "__main__":
    unittest.main()


class TestVersionTimeIsAString:
    """SECREV-2 / VMR-015 — the converter emitted a numeric `time`, which the parser cannot read.

    `versions[].time` is consumed by `TimeExpressionParser.parse`, whose first act is
    `expression.strip()`. A number therefore raises `AttributeError: 'int' object has no
    attribute 'strip'` — and the shipped `versions.yaml` confirms the intended shape is a
    string (`time: "sunrise"`, `time: "08:30"`).
    """

    @staticmethod
    def _convert(lua: str) -> dict:
        from weather_injector.utils.lua_converter import LuaToYamlConverter

        return LuaToYamlConverter._parse_lua_config(lua)

    def test_numeric_time_becomes_hh_mm(self) -> None:
        lua = 'targets = { { version = "noon", time = 43200 } }'
        config = self._convert(lua)
        version = config["versions"][0]
        assert version["time"] == "12:00"
        assert isinstance(version["time"], str)

    def test_midnight_is_kept_rather_than_dropped(self) -> None:
        """0 is falsy in Python: a naive `if time:` would silently lose midnight."""
        lua = 'targets = { { version = "midnight", time = 0 } }'
        config = self._convert(lua)
        assert config["versions"][0]["time"] == "00:00"

    def test_odd_minutes_survive(self) -> None:
        lua = 'targets = { { version = "dawn", time = 23460 } }'  # 06:31
        config = self._convert(lua)
        assert config["versions"][0]["time"] == "06:31"

    def test_a_version_without_time_has_no_time_key(self) -> None:
        lua = 'targets = { { version = "any" } }'
        config = self._convert(lua)
        assert "time" not in config["versions"][0]

    def test_the_result_is_parseable_by_the_consumer(self) -> None:
        """The point of the fix: what comes out must go into the parser without raising."""
        from weather_injector.utils.time_expression_parser import TimeExpressionParser

        lua = 'targets = { { version = "noon", time = 43200 } }'
        emitted = self._convert(lua)["versions"][0]["time"]
        assert TimeExpressionParser.parse(emitted) == 43200
