"""Tests for DCSWeatherConverter and its helper functions."""

from __future__ import annotations

import unittest

from weather_injector.weather.dcs_weather_converter import (
    DCSWeatherConverter,
    _extract_metar_values,
    _fallback_metar_parsing,
    _fetch_live_metar,
)


class TestDCSWeatherConverterDefaults(unittest.TestCase):
    """to_dcs_lua_table() with no parameters → all defaults."""

    def setUp(self) -> None:
        self.result = DCSWeatherConverter.to_dcs_lua_table()

    def test_returns_dict(self) -> None:
        self.assertIsInstance(self.result, dict)

    def test_has_atmosphere_key(self) -> None:
        self.assertIn("atmosphere", self.result)

    def test_has_fog_key(self) -> None:
        self.assertIn("fog", self.result)

    def test_default_temperature(self) -> None:
        self.assertEqual(self.result["atmosphere"]["temperature_celsius"], 15.0)

    def test_default_wind_speed(self) -> None:
        self.assertEqual(self.result["atmosphere"]["wind"]["speed_mps"], 5.0)

    def test_default_wind_direction(self) -> None:
        self.assertEqual(self.result["atmosphere"]["wind"]["direction_degrees"], 0.0)

    def test_default_visibility(self) -> None:
        self.assertEqual(self.result["atmosphere"]["visibility_meters"], 10000.0)

    def test_default_cloud_type(self) -> None:
        self.assertEqual(self.result["atmosphere"]["clouds"]["type"], 0)

    def test_default_cloud_base(self) -> None:
        self.assertEqual(self.result["atmosphere"]["clouds"]["base_altitude_meters"], 2000.0)

    def test_fog_disabled_by_default(self) -> None:
        self.assertFalse(self.result["fog"]["enabled"])

    def test_fog_density_zero_by_default(self) -> None:
        self.assertEqual(self.result["fog"]["density"], 0.0)

    def test_fog_thickness_default(self) -> None:
        self.assertEqual(self.result["fog"]["thickness_meters"], 200.0)


class TestDCSWeatherConverterParameterOverrides(unittest.TestCase):
    """Individual parameter overrides are applied correctly."""

    def test_temperature_override(self) -> None:
        result = DCSWeatherConverter.to_dcs_lua_table(temperature_celsius=25.0)
        self.assertEqual(result["atmosphere"]["temperature_celsius"], 25.0)

    def test_wind_speed_override(self) -> None:
        result = DCSWeatherConverter.to_dcs_lua_table(wind_speed_mps=10.0)
        self.assertEqual(result["atmosphere"]["wind"]["speed_mps"], 10.0)

    def test_wind_direction_override(self) -> None:
        result = DCSWeatherConverter.to_dcs_lua_table(wind_direction_degrees=180.0)
        self.assertEqual(result["atmosphere"]["wind"]["direction_degrees"], 180.0)

    def test_visibility_override(self) -> None:
        result = DCSWeatherConverter.to_dcs_lua_table(visibility_meters=5000.0)
        self.assertEqual(result["atmosphere"]["visibility_meters"], 5000.0)

    def test_cloud_coverage_few(self) -> None:
        result = DCSWeatherConverter.to_dcs_lua_table(cloud_coverage="few")
        self.assertEqual(result["atmosphere"]["clouds"]["type"], 1)

    def test_cloud_coverage_scattered(self) -> None:
        result = DCSWeatherConverter.to_dcs_lua_table(cloud_coverage="scattered")
        self.assertEqual(result["atmosphere"]["clouds"]["type"], 2)

    def test_cloud_coverage_broken(self) -> None:
        result = DCSWeatherConverter.to_dcs_lua_table(cloud_coverage="broken")
        self.assertEqual(result["atmosphere"]["clouds"]["type"], 3)

    def test_cloud_coverage_overcast(self) -> None:
        result = DCSWeatherConverter.to_dcs_lua_table(cloud_coverage="overcast")
        self.assertEqual(result["atmosphere"]["clouds"]["type"], 4)

    def test_cloud_coverage_unknown_defaults_to_zero(self) -> None:
        result = DCSWeatherConverter.to_dcs_lua_table(cloud_coverage="unknown_value")
        self.assertEqual(result["atmosphere"]["clouds"]["type"], 0)

    def test_cloud_coverage_case_insensitive(self) -> None:
        result = DCSWeatherConverter.to_dcs_lua_table(cloud_coverage="FEW")
        self.assertEqual(result["atmosphere"]["clouds"]["type"], 1)

    def test_cloud_height_override(self) -> None:
        result = DCSWeatherConverter.to_dcs_lua_table(cloud_height_meters=1500.0)
        self.assertEqual(result["atmosphere"]["clouds"]["base_altitude_meters"], 1500.0)

    def test_fog_enabled(self) -> None:
        result = DCSWeatherConverter.to_dcs_lua_table(fog_enabled=True, fog_density=0.5)
        self.assertTrue(result["fog"]["enabled"])
        self.assertEqual(result["fog"]["density"], 0.5)

    def test_fog_thickness_override(self) -> None:
        result = DCSWeatherConverter.to_dcs_lua_table(fog_enabled=True, fog_thickness_meters=400.0)
        self.assertEqual(result["fog"]["thickness_meters"], 400.0)


class TestDCSWeatherConverterMetarString(unittest.TestCase):
    """to_dcs_lua_table() with a real METAR string."""

    METAR = "OSDI 151420Z 27015G25KT 9999 SKC 15/10 Q1018"

    def setUp(self) -> None:
        self.result = DCSWeatherConverter.to_dcs_lua_table(metar_string=self.METAR)

    def test_wind_direction_from_metar(self) -> None:
        self.assertAlmostEqual(self.result["atmosphere"]["wind"]["direction_degrees"], 270.0)

    def test_wind_speed_from_metar(self) -> None:
        # 15 kt * 0.51444 = 7.7166 m/s
        self.assertAlmostEqual(self.result["atmosphere"]["wind"]["speed_mps"], 15 * 0.51444, places=3)

    def test_visibility_from_metar(self) -> None:
        self.assertAlmostEqual(self.result["atmosphere"]["visibility_meters"], 9999.0)

    def test_cloud_type_skc(self) -> None:
        self.assertEqual(self.result["atmosphere"]["clouds"]["type"], 0)

    def test_temperature_from_metar(self) -> None:
        self.assertAlmostEqual(self.result["atmosphere"]["temperature_celsius"], 15.0)

    def test_metar_override_still_works(self) -> None:
        """Parameter overrides apply on top of METAR values."""
        result = DCSWeatherConverter.to_dcs_lua_table(metar_string=self.METAR, temperature_celsius=30.0)
        self.assertEqual(result["atmosphere"]["temperature_celsius"], 30.0)


class TestFetchLiveMetar(unittest.TestCase):
    """_fetch_live_metar() when avwx is not available."""

    def test_empty_icao_returns_defaults(self) -> None:
        result = _fetch_live_metar("")
        self.assertEqual(result["temperature"], 15.0)
        self.assertEqual(result["wind_speed"], 5.0)

    def test_no_avwx_returns_defaults(self) -> None:
        # avwx is not installed in test env
        result = _fetch_live_metar("OSDI")
        self.assertIn("temperature", result)
        self.assertIn("wind_speed", result)
        self.assertIn("wind_direction", result)
        self.assertIn("visibility", result)
        self.assertIn("cloud_type", result)
        self.assertIn("cloud_height", result)


class TestExtractMetarValues(unittest.TestCase):
    """_extract_metar_values() delegates to regex parsing."""

    def test_empty_string_returns_defaults(self) -> None:
        result = _extract_metar_values("")
        self.assertEqual(result["temperature"], 15.0)

    def test_full_metar(self) -> None:
        result = _extract_metar_values("OSDI 151420Z 27015G25KT 9999 SKC 15/10 Q1018")
        self.assertAlmostEqual(result["wind_direction"], 270.0)
        self.assertAlmostEqual(result["visibility"], 9999.0)
        self.assertEqual(result["cloud_type"], 0)
        self.assertAlmostEqual(result["temperature"], 15.0)


class TestFallbackMetarParsing(unittest.TestCase):
    """_fallback_metar_parsing() — exhaustive coverage of all branches."""

    DEFAULTS: dict = {
        "temperature": 15.0,
        "wind_speed": 5.0,
        "wind_direction": 0.0,
        "visibility": 10000.0,
        "cloud_type": 0,
        "cloud_height": 2000.0,
    }

    def _parse(self, metar: str) -> dict:
        return _fallback_metar_parsing(metar, self.DEFAULTS.copy())

    # Wind parsing
    def test_wind_direction_270_speed_15kt(self) -> None:
        r = self._parse("OSDI 151420Z 27015KT 9999 SKC 15/10 Q1018")
        self.assertAlmostEqual(r["wind_direction"], 270.0)
        self.assertAlmostEqual(r["wind_speed"], 15 * 0.51444, places=3)

    def test_wind_with_gust(self) -> None:
        r = self._parse("27015G25KT")
        self.assertAlmostEqual(r["wind_direction"], 270.0)
        # Speed is 15 kt, gust is ignored
        self.assertAlmostEqual(r["wind_speed"], 15 * 0.51444, places=3)

    def test_wind_direction_000(self) -> None:
        r = self._parse("00010KT")
        self.assertAlmostEqual(r["wind_direction"], 0.0)

    # Temperature parsing
    def test_temperature_positive(self) -> None:
        r = self._parse("AAAA 15/10")
        self.assertAlmostEqual(r["temperature"], 15.0)

    def test_temperature_zero(self) -> None:
        r = self._parse("AAAA 0/M02")
        self.assertAlmostEqual(r["temperature"], 0.0)

    def test_temperature_negative_M_prefix_not_parsed(self) -> None:
        # "M05/M10" — with_temp = "M05", "M05".lstrip("-") = "M05", not isdigit
        r = self._parse("AAAA M05/M10")
        self.assertAlmostEqual(r["temperature"], 15.0)  # unchanged default

    # Visibility parsing
    def test_visibility_9999(self) -> None:
        r = self._parse("9999")
        self.assertAlmostEqual(r["visibility"], 9999.0)

    def test_visibility_0500(self) -> None:
        r = self._parse("0500")
        self.assertAlmostEqual(r["visibility"], 500.0)

    def test_non_4digit_string_not_parsed_as_visibility(self) -> None:
        r = self._parse("999")
        self.assertAlmostEqual(r["visibility"], 10000.0)  # unchanged

    # Cloud coverage
    def test_skc(self) -> None:
        r = self._parse("SKC")
        self.assertEqual(r["cloud_type"], 0)

    def test_clr(self) -> None:
        r = self._parse("CLR")
        self.assertEqual(r["cloud_type"], 0)

    def test_few(self) -> None:
        r = self._parse("FEW010")
        self.assertEqual(r["cloud_type"], 1)
        self.assertAlmostEqual(r["cloud_height"], 10 * 100 * 0.3048, places=2)

    def test_sct(self) -> None:
        r = self._parse("SCT025")
        self.assertEqual(r["cloud_type"], 2)
        self.assertAlmostEqual(r["cloud_height"], 25 * 100 * 0.3048, places=2)

    def test_bkn(self) -> None:
        r = self._parse("BKN040")
        self.assertEqual(r["cloud_type"], 3)
        self.assertAlmostEqual(r["cloud_height"], 40 * 100 * 0.3048, places=2)

    def test_ovc(self) -> None:
        r = self._parse("OVC100")
        self.assertEqual(r["cloud_type"], 4)
        self.assertAlmostEqual(r["cloud_height"], 100 * 100 * 0.3048, places=2)

    def test_cloud_without_altitude(self) -> None:
        r = self._parse("SKC")
        self.assertEqual(r["cloud_type"], 0)
        # Height unchanged (no altitude group)
        self.assertAlmostEqual(r["cloud_height"], 2000.0)

    def test_empty_string_returns_defaults(self) -> None:
        r = self._parse("")
        self.assertEqual(r, self.DEFAULTS)

    def test_full_metar_integration(self) -> None:
        r = self._parse("OSDI 151420Z 27015G25KT 9999 SKC 15/10 Q1018")
        self.assertAlmostEqual(r["wind_direction"], 270.0)
        self.assertAlmostEqual(r["wind_speed"], 15 * 0.51444, places=3)
        self.assertAlmostEqual(r["visibility"], 9999.0)
        self.assertEqual(r["cloud_type"], 0)
        self.assertAlmostEqual(r["temperature"], 15.0)


class TestCloudTypesConstant(unittest.TestCase):
    """DCSWeatherConverter.CLOUD_TYPES constant values."""

    def test_clear_is_zero(self) -> None:
        self.assertEqual(DCSWeatherConverter.CLOUD_TYPES["clear"], 0)

    def test_few_is_one(self) -> None:
        self.assertEqual(DCSWeatherConverter.CLOUD_TYPES["few"], 1)

    def test_scattered_is_two(self) -> None:
        self.assertEqual(DCSWeatherConverter.CLOUD_TYPES["scattered"], 2)

    def test_broken_is_three(self) -> None:
        self.assertEqual(DCSWeatherConverter.CLOUD_TYPES["broken"], 3)

    def test_overcast_is_four(self) -> None:
        self.assertEqual(DCSWeatherConverter.CLOUD_TYPES["overcast"], 4)


if __name__ == "__main__":
    unittest.main()
