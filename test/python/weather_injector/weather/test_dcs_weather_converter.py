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
    """to_dcs_lua_table() with no parameters → the defaults, written in the fields DCS reads.

    FIX-SCRATCH-MISSION-FINDINGS ticket 01: the converter used to return an ``atmosphere`` table and a
    ``fog`` table of its own invention; DCS ignored both, so every variant flew the base mission's sky.
    """

    def setUp(self) -> None:
        self.result = DCSWeatherConverter.to_dcs_lua_table()

    def test_returns_dict(self) -> None:
        self.assertIsInstance(self.result, dict)

    def test_writes_no_invented_key(self) -> None:
        self.assertNotIn("atmosphere", self.result)
        self.assertNotIn("enabled", self.result["fog"])

    def test_static_weather(self) -> None:
        # Dynamic weather (atmosphere_type 1) would make DCS ignore every static field below
        self.assertEqual(self.result["atmosphere_type"], 0)

    def test_default_temperature(self) -> None:
        self.assertEqual(self.result["season"]["temperature"], 15.0)

    def test_default_ground_wind(self) -> None:
        self.assertEqual(self.result["wind"]["atGround"]["speed"], 5.0)

    def test_default_visibility_is_unlimited(self) -> None:
        # >= 9000 m reads as "10 km or more" in a METAR; v5 flew it as DCS's 80 km
        self.assertEqual(self.result["visibility"]["distance"], 80000)

    def test_clear_sky_has_no_preset(self) -> None:
        self.assertNotIn("preset", self.result["clouds"])

    def test_fog_off(self) -> None:
        self.assertFalse(self.result["enable_fog"])
        self.assertEqual(self.result["fog"], {"visibility": 0, "thickness": 0})

    def test_qnh_not_invented(self) -> None:
        """No pressure was given, so the base mission's stays."""
        self.assertNotIn("qnh", self.result)


class TestDCSWeatherConverterParameterOverrides(unittest.TestCase):
    """Individual parameter overrides reach the DCS fields."""

    def test_temperature_override(self) -> None:
        result = DCSWeatherConverter.to_dcs_lua_table(temperature_celsius=25.0)
        self.assertEqual(result["season"]["temperature"], 25.0)

    def test_wind_speed_override(self) -> None:
        result = DCSWeatherConverter.to_dcs_lua_table(wind_speed_mps=10.0)
        self.assertEqual(result["wind"]["atGround"]["speed"], 10.0)

    def test_wind_is_stronger_aloft(self) -> None:
        result = DCSWeatherConverter.to_dcs_lua_table(wind_speed_mps=10.0)
        self.assertGreater(result["wind"]["at2000"]["speed"], 10.0)
        self.assertGreater(result["wind"]["at8000"]["speed"], result["wind"]["at2000"]["speed"])

    def test_wind_direction_is_turned_to_where_it_blows(self) -> None:
        """A METAR gives where the wind comes FROM; the mission file stores where it goes TO (v5 did
        the same conversion, ``convertFromTo``)."""
        result = DCSWeatherConverter.to_dcs_lua_table(wind_direction_degrees=270.0)
        self.assertEqual(result["wind"]["atGround"]["dir"], 90)

    def test_visibility_override(self) -> None:
        result = DCSWeatherConverter.to_dcs_lua_table(visibility_meters=5000.0)
        self.assertEqual(result["visibility"]["distance"], 5000)

    def test_cloud_coverage_picks_a_preset_of_that_coverage(self) -> None:
        expected = {"few": "Preset1", "scattered": "Preset3", "broken": "Preset13", "overcast": "Preset21"}
        for coverage, preset in expected.items():
            with self.subTest(coverage=coverage):
                result = DCSWeatherConverter.to_dcs_lua_table(cloud_coverage=coverage, cloud_height_meters=2000.0)
                self.assertEqual(result["clouds"]["preset"], preset)

    def test_cloud_coverage_case_insensitive(self) -> None:
        result = DCSWeatherConverter.to_dcs_lua_table(cloud_coverage="FEW", cloud_height_meters=2000.0)
        self.assertEqual(result["clouds"]["preset"], "Preset1")

    def test_unknown_coverage_is_clear(self) -> None:
        result = DCSWeatherConverter.to_dcs_lua_table(cloud_coverage="unknown_value")
        self.assertNotIn("preset", result["clouds"])

    def test_cloud_base_inside_the_preset_range_is_kept(self) -> None:
        result = DCSWeatherConverter.to_dcs_lua_table(cloud_coverage="few", cloud_height_meters=1500.0)
        self.assertEqual(result["clouds"]["base"], 1500)

    def test_low_base_picks_a_preset_that_allows_it(self) -> None:
        """Preset21 starts at 1260 m; an overcast at 300 m needs a low-level preset instead."""
        result = DCSWeatherConverter.to_dcs_lua_table(cloud_coverage="overcast", cloud_height_meters=300.0)
        self.assertEqual(result["clouds"]["preset"], "Preset19")
        self.assertEqual(result["clouds"]["base"], 300)

    def test_base_outside_every_range_is_clamped(self) -> None:
        """DCS accepts a preset's base only inside presetAltMin/presetAltMax (Config/Effects/clouds.lua)."""
        result = DCSWeatherConverter.to_dcs_lua_table(cloud_coverage="few", cloud_height_meters=100.0)
        self.assertEqual(result["clouds"]["preset"], "Preset1")
        self.assertEqual(result["clouds"]["base"], 840)

    def test_precipitation_picks_a_rainy_preset(self) -> None:
        result = DCSWeatherConverter.to_dcs_lua_table(
            cloud_coverage="overcast", cloud_height_meters=1000.0, precipitation=True
        )
        self.assertEqual(result["clouds"]["preset"], "RainyPreset1")

    def test_fog_enabled(self) -> None:
        result = DCSWeatherConverter.to_dcs_lua_table(fog_enabled=True, fog_thickness_meters=400.0)
        self.assertTrue(result["enable_fog"])
        self.assertEqual(result["fog"]["thickness"], 400)
        self.assertGreater(result["fog"]["visibility"], 0)


class TestDCSWeatherConverterMetarString(unittest.TestCase):
    """to_dcs_lua_table() with a real METAR string."""

    METAR = "OSDI 151420Z 27015G25KT 9999 SKC 15/10 Q1018"

    def setUp(self) -> None:
        self.result = DCSWeatherConverter.to_dcs_lua_table(metar_string=self.METAR)

    def test_wind_direction_from_metar(self) -> None:
        self.assertEqual(self.result["wind"]["atGround"]["dir"], 90)

    def test_wind_speed_from_metar(self) -> None:
        # 15 kt * 0.51444 = 7.7166 m/s
        self.assertAlmostEqual(self.result["wind"]["atGround"]["speed"], 15 * 0.51444, places=3)

    def test_visibility_from_metar(self) -> None:
        self.assertEqual(self.result["visibility"]["distance"], 80000)

    def test_cloud_skc(self) -> None:
        self.assertNotIn("preset", self.result["clouds"])

    def test_temperature_from_metar(self) -> None:
        self.assertAlmostEqual(self.result["season"]["temperature"], 15.0)

    def test_qnh_from_metar_in_mmhg(self) -> None:
        # 1018 hPa = 763.6 mmHg
        self.assertAlmostEqual(self.result["qnh"], 1018 * 0.750062, places=1)

    def test_qnh_in_inches(self) -> None:
        result = DCSWeatherConverter.to_dcs_lua_table(metar_string="KLSV 151420Z 27015KT 10SM CLR 30/05 A2992")
        self.assertAlmostEqual(result["qnh"], 29.92 * 25.4, places=1)

    def test_metar_override_still_works(self) -> None:
        """Parameter overrides apply on top of METAR values."""
        result = DCSWeatherConverter.to_dcs_lua_table(metar_string=self.METAR, temperature_celsius=30.0)
        self.assertEqual(result["season"]["temperature"], 30.0)

    def test_rain_in_the_metar_reaches_dcs(self) -> None:
        result = DCSWeatherConverter.to_dcs_lua_table(metar_string="ETAR 011150Z 26002KT 6000 -RA OVC028 16/14 Q1012")
        self.assertEqual(result["clouds"]["preset"], "RainyPreset1")

    def test_fog_in_the_metar_reaches_dcs(self) -> None:
        result = DCSWeatherConverter.to_dcs_lua_table(metar_string="ETAR 010550Z 00000KT 0400 FG VV001 08/08 Q1020")
        self.assertTrue(result["enable_fog"])


class TestTwoVariantsDifferWhereDcsReads(unittest.TestCase):
    """The ticket's own "Done when": two METARs, different values in the DCS fields.

    Caucasus v6 ``dawn-broken`` and ``dawn-overcast-rain`` both flew Preset2 / 2500 m / 20 °C / calm,
    because only the ignored ``atmosphere`` table differed.
    """

    def test_broken_and_overcast_rain_differ(self) -> None:
        broken = DCSWeatherConverter.to_dcs_lua_table(metar_string="UGKO 290400Z 09004KT 9999 BKN110 23/12 Q1014")
        rain = DCSWeatherConverter.to_dcs_lua_table(metar_string="UGKO 290400Z 27012KT 5000 RA OVC095 16/14 Q1008")
        self.assertNotEqual(broken["clouds"]["preset"], rain["clouds"]["preset"])
        self.assertNotEqual(broken["season"]["temperature"], rain["season"]["temperature"])
        self.assertNotEqual(broken["wind"]["atGround"], rain["wind"]["atGround"])
        self.assertNotEqual(broken["qnh"], rain["qnh"])


class TestClearsky(unittest.TestCase):
    """``clearsky: true`` caps a real weather to VFR-friendly conditions, in the DCS fields."""

    def test_caps_clouds_to_few(self) -> None:
        result = DCSWeatherConverter.to_dcs_lua_table(
            metar_string="ETAR 011150Z 26002KT 6000 -RA OVC028 16/14 Q1012", clearsky=True
        )
        self.assertEqual(result["clouds"]["preset"], "Preset1")

    def test_caps_wind(self) -> None:
        result = DCSWeatherConverter.to_dcs_lua_table(
            metar_string="EGLL 010850Z 09035KT CAVOK 15/08 Q1018", clearsky=True
        )
        self.assertLessEqual(result["wind"]["atGround"]["speed"], 7.72)

    def test_raises_visibility(self) -> None:
        result = DCSWeatherConverter.to_dcs_lua_table(visibility_meters=3000.0, clearsky=True)
        self.assertEqual(result["visibility"]["distance"], 80000)

    def test_removes_fog(self) -> None:
        result = DCSWeatherConverter.to_dcs_lua_table(fog_enabled=True, clearsky=True)
        self.assertFalse(result["enable_fog"])


class TestFetchLiveMetar(unittest.TestCase):
    """_fetch_live_metar() when avwx is not available."""

    def test_empty_icao_returns_defaults(self) -> None:
        result = _fetch_live_metar("")
        self.assertEqual(result["temperature"], 15.0)
        self.assertEqual(result["wind_speed"], 5.0)

    def test_unavailable_icao_returns_defaults(self) -> None:
        # With no network (CI) or invalid ICAO, _fetch_live_metar should return safe defaults
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

    def test_wind_in_metres_per_second_is_not_converted(self) -> None:
        """Russian stations report MPS — URSS feeds Caucasus v6's live variants. It was read as knots."""
        r = self._parse("URSS 290400Z 27008MPS 9999 SCT040 23/12 Q1014")
        self.assertAlmostEqual(r["wind_direction"], 270.0)
        self.assertAlmostEqual(r["wind_speed"], 8.0)

    def test_variable_wind_is_read(self) -> None:
        """`VRB02KT` kept the 5 m/s default, and a near calm flew with 5 m/s."""
        r = self._parse("ETAR 240555Z VRB02KT 9999 BKN065 09/07 A3019")
        self.assertAlmostEqual(r["wind_speed"], 2 * 0.51444, places=3)

    def test_calm_wind_is_zero(self) -> None:
        r = self._parse("ETAR 240555Z 00000KT 9999 BKN065 09/07 A3019")
        self.assertAlmostEqual(r["wind_speed"], 0.0)

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

    def test_temperature_negative_M_prefix_is_parsed(self) -> None:
        """SECREV-2 / VMR-016: this test used to pin the bug rather than the behaviour.

        It asserted that `M05/M10` left the default of 15.0 in place, and its comment even
        explained the mechanism — `"M05".lstrip("-")` is not a digit string — as though that
        were the intended outcome. `M` is how a METAR spells a minus sign, so the reading was
        being dropped silently, and a winter mission flew at whatever default was configured.
        """
        r = self._parse("AAAA M05/M10")
        self.assertAlmostEqual(r["temperature"], -5.0)

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


class TestForecastGroupsDoNotOverrideTheObservation(unittest.TestCase):
    """SECREV-2 / VMR-070 — the loop read past TEMPO/BECMG, and visibility had no `break`.

    A METAR describes what is observed *now*; everything from TEMPO, BECMG, PROB or RMK onwards is a
    forecast or free text. Reading straight through them meant the **last** four-digit group won, so a
    report observed at 9999 was flown at the trend's 3000.
    """

    @staticmethod
    def _parse(metar: str) -> dict:
        from weather_injector.weather.dcs_weather_converter import _fallback_metar_parsing

        return _fallback_metar_parsing(
            metar,
            {
                "temperature": 20.0,
                "wind_speed": 5.0,
                "wind_direction": 0.0,
                "visibility": 10000.0,
                "cloud_type": 0,
                "cloud_height": 2000.0,
            },
        )

    def test_a_tempo_visibility_does_not_replace_the_observed_one(self) -> None:
        r = self._parse("LFPG 121200Z 27015KT 9999 SCT040 12/08 Q1013 TEMPO 3000")

        self.assertAlmostEqual(r["visibility"], 9999.0, msg="the observation must win over the trend")

    def test_a_becmg_group_is_ignored_too(self) -> None:
        r = self._parse("LFPG 121200Z 27015KT 9999 SCT040 12/08 Q1013 BECMG 0800")

        self.assertAlmostEqual(r["visibility"], 9999.0)

    def test_remarks_cannot_inject_a_visibility(self) -> None:
        r = self._parse("LFPG 121200Z 27015KT 0800 SCT040 12/08 Q1013 RMK 9999")

        self.assertAlmostEqual(r["visibility"], 800.0, msg="a number in RMK is free text, not weather")

    def test_the_observed_visibility_is_still_read_without_any_trend(self) -> None:
        r = self._parse("LFPG 121200Z 27015KT 4000 SCT040 12/08 Q1013")

        self.assertAlmostEqual(r["visibility"], 4000.0)

    def test_the_wind_before_a_trend_is_still_read(self) -> None:
        # Truncating at TEMPO must not throw away the groups that came before it.
        r = self._parse("LFPG 121200Z 27015KT 9999 SCT040 12/08 Q1013 TEMPO 31025G40KT")

        self.assertAlmostEqual(r["wind_direction"], 270.0)
        self.assertAlmostEqual(r["wind_speed"], 15 * 0.51444, places=4)
