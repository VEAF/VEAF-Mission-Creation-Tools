"""Tests for DCSWeatherConverter and its helper functions."""

from __future__ import annotations

import unittest

from veaf_libs.dcs_wind import surface_wind, turbulence_for_gust, wind_profile
from weather_injector.weather.dcs_weather_converter import (
    DCSWeatherConverter,
    _extract_metar_values,
    _fallback_metar_parsing,
    _fetch_live_metar,
    cap_clearsky,
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
        # 5 m/s wanted 10 m above sea level, the reference when nothing names one.
        self.assertAlmostEqual(surface_wind(self.result["wind"], 0.0).speed, 5.0, places=1)

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
        self.assertAlmostEqual(surface_wind(result["wind"], 0.0).speed, 10.0, places=1)

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
        # 15 kt simulated 10 m above sea level: no theatre given, so no airfield to set it for.
        self.assertAlmostEqual(surface_wind(self.result["wind"], 0.0).knots, 15.0, delta=0.1)

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
        self.assertLessEqual(surface_wind(result["wind"], 0.0).speed, 7.72 + 0.01)

    def test_raises_visibility(self) -> None:
        result = DCSWeatherConverter.to_dcs_lua_table(visibility_meters=3000.0, clearsky=True)
        self.assertEqual(result["visibility"]["distance"], 80000)

    def test_removes_fog(self) -> None:
        result = DCSWeatherConverter.to_dcs_lua_table(fog_enabled=True, clearsky=True)
        self.assertFalse(result["enable_fog"])


class TestCapClearsky(unittest.TestCase):
    """``cap_clearsky``: the one place the caps live, for the injected table and the briefing's METAR."""

    def test_caps_every_value_and_leaves_the_rest(self) -> None:
        observed = _extract_metar_values("LTAG 021820Z 35030KT 3000 +TSRA BR BKN090 19/16 Q1015")
        observed["fog"] = True
        capped = cap_clearsky(observed)
        self.assertEqual(capped["cloud_type"], 1)
        self.assertAlmostEqual(capped["wind_speed"], 7.72)
        self.assertEqual(capped["visibility"], 9999.0)
        self.assertFalse(capped["precipitation"])
        self.assertFalse(capped["fog"])
        for kept in ("temperature", "wind_direction", "cloud_height", "qnh_hpa"):
            self.assertEqual(capped[kept], observed[kept], kept)

    def test_does_not_touch_its_input(self) -> None:
        # The live fetch is memoised and its dict shared: capping it in place would cap the real variant too.
        observed = _extract_metar_values("LTAG 021820Z 35030KT 3000 BKN090 19/16 Q1015")
        cap_clearsky(observed)
        self.assertEqual(observed["cloud_type"], 3)

    def test_adds_no_wind_or_cloud_that_was_not_given(self) -> None:
        self.assertEqual(cap_clearsky({}), {"visibility": 10000.0, "precipitation": False, "fog": False})


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


class TestTheWantedWind(unittest.TestCase):
    """FEAT-MISSION-WIND-CHECK ticket 03: the wind written is the setting that gives the wanted wind."""

    METAR = "LLIB 311200Z 27015KT 9999 SKC 20/10 Q1015"

    def test_a_station_of_the_map_gives_back_its_metar_wind(self) -> None:
        conversion = DCSWeatherConverter.convert(metar_string=self.METAR, theatre="Syria")
        self.assertEqual(conversion.reference.name, "Rosh Pina")
        self.assertEqual(conversion.reference.source, "metar_station")
        wind = surface_wind(conversion.weather["wind"], conversion.reference.elevation)
        self.assertAlmostEqual(wind.knots, 15.0, delta=0.1)
        self.assertAlmostEqual(wind.from_deg, 270.0, delta=0.5)
        self.assertEqual(conversion.layers[0]["layer"], "surface")
        self.assertEqual(conversion.layers[0]["knots"], 15)

    def test_the_same_wind_writes_different_settings_at_different_altitudes(self) -> None:
        low = DCSWeatherConverter.convert(wind_speed_mps=7.7, theatre="Syria", reference_airfield="Bassel Al-Assad")
        high = DCSWeatherConverter.convert(wind_speed_mps=7.7, theatre="Syria", reference_airfield="Khalkhalah")
        self.assertLess(low.reference.elevation, 100)
        self.assertGreater(high.reference.elevation, 600)
        self.assertGreater(low.weather["wind"]["atGround"]["speed"], high.weather["wind"]["atGround"]["speed"])

    def test_a_station_off_the_map_falls_back_to_the_departure_then_to_sea_level(self) -> None:
        metar = "EGLL 010850Z 27015KT CAVOK 15/08 Q1018"
        departure = DCSWeatherConverter.convert(metar_string=metar, theatre="Syria", departure_airfield="Rosh Pina")
        self.assertEqual((departure.reference.name, departure.reference.source), ("Rosh Pina", "departure"))
        self.assertEqual(departure.warnings, [])
        sea = DCSWeatherConverter.convert(metar_string=metar, theatre="Syria")
        self.assertEqual(sea.reference.source, "sea_level")
        self.assertTrue(any("sea level" in warning for warning in sea.warnings))

    def test_an_unknown_reference_airfield_is_said(self) -> None:
        conversion = DCSWeatherConverter.convert(wind_speed_mps=5, theatre="Syria", reference_airfield="Atlantis")
        self.assertTrue(any("Atlantis" in warning for warning in conversion.warnings))

    def test_clearsky_caps_the_simulated_wind_at_the_reference_airfield(self) -> None:
        conversion = DCSWeatherConverter.convert(
            metar_string="LLIB 311200Z 27025G35KT 9999 SKC 20/10 Q1015", theatre="Syria", clearsky=True
        )
        wind = surface_wind(conversion.weather["wind"], conversion.reference.elevation)
        self.assertAlmostEqual(wind.knots, 15.0, delta=0.1)
        self.assertEqual(conversion.weather["groundTurbulence"], 0)

    def test_at2000_defaults_to_2_2_times_the_ground_veered_20(self) -> None:
        wind = DCSWeatherConverter.to_dcs_lua_table(wind_speed_mps=5, wind_direction_degrees=270)["wind"]
        self.assertAlmostEqual(wind["at2000"]["speed"], 2.2 * wind["atGround"]["speed"], delta=0.02)
        self.assertAlmostEqual((wind["at2000"]["dir"] - wind["atGround"]["dir"]) % 360, 20.0, delta=0.2)
        self.assertAlmostEqual(wind["at8000"]["speed"], wind["at2000"]["speed"] + 3.0, delta=0.02)

    def test_the_veer_is_a_parameter_and_refused_past_30(self) -> None:
        wind = DCSWeatherConverter.to_dcs_lua_table(wind_speed_mps=5, wind_veer=0)["wind"]
        self.assertAlmostEqual(wind["at2000"]["dir"], wind["atGround"]["dir"], delta=0.2)
        with self.assertRaises(ValueError):
            DCSWeatherConverter.to_dcs_lua_table(wind_speed_mps=5, wind_veer=45)

    def test_explicit_upper_layers_are_written_as_given_with_the_jet_warned(self) -> None:
        conversion = DCSWeatherConverter.convert(
            wind_speed_mps=10,
            wind_direction_degrees=270,
            wind_speed_2000=7,
            wind_direction_2000=280,
            wind_speed_8000=20,
            wind_direction_8000=300,
        )
        wind = conversion.weather["wind"]
        self.assertEqual(wind["at2000"], {"speed": 7.0, "dir": 100.0})
        self.assertEqual(wind["at8000"], {"speed": 20.0, "dir": 120.0})
        self.assertAlmostEqual(surface_wind(wind, 0.0).speed, 10.0, delta=0.05)
        self.assertTrue(any("jet" in warning for warning in conversion.warnings))

    def test_an_explicit_at2000_above_2_14_times_is_not_warned(self) -> None:
        conversion = DCSWeatherConverter.convert(
            wind_speed_mps=5, wind_speed_2000=12, theatre="Syria", reference_airfield="Rosh Pina"
        )
        self.assertEqual(conversion.warnings, [])

    def test_a_high_reference_airfield_with_a_given_at2000_is_warned(self) -> None:
        conversion = DCSWeatherConverter.convert(
            wind_speed_mps=5, wind_speed_2000=20, theatre="Afghanistan", reference_airfield="Kabul"
        )
        self.assertGreater(conversion.reference.elevation, 1700)
        self.assertTrue(any("2,000 m wind weighs" in warning for warning in conversion.warnings))

    def test_the_layers_say_the_simulated_wind_above_the_reference(self) -> None:
        conversion = DCSWeatherConverter.convert(wind_speed_mps=5, theatre="Syria", reference_airfield="Rosh Pina")
        names = [layer["layer"] for layer in conversion.layers]
        self.assertEqual(names, ["surface", "1000 ft AGL", "3000 ft AGL", "FL100", "FL250"])
        expected = wind_profile(conversion.weather["wind"], conversion.reference.elevation, [1000 * 0.3048])[0]
        self.assertEqual(conversion.layers[1]["knots"], round(expected.wind.knots))


class TestGusts(unittest.TestCase):
    """FEAT-MISSION-WIND-CHECK ticket 03 d: the METAR's gust feeds ``groundTurbulence``."""

    def test_a_gust_writes_its_turbulence(self) -> None:
        result = DCSWeatherConverter.to_dcs_lua_table(metar_string="OSDI 151420Z 27015G25KT 9999 SKC 15/10 Q1018")
        # A 10 kt gap is 8.3 m/s of turbulence by the measured mapping, capped at 3 m/s.
        self.assertEqual(result["groundTurbulence"], 30)

    def test_a_metar_without_gust_writes_no_turbulence(self) -> None:
        result = DCSWeatherConverter.to_dcs_lua_table(metar_string="OSDI 151420Z 27015KT 9999 SKC 15/10 Q1018")
        self.assertEqual(result["groundTurbulence"], 0)

    def test_a_manual_weather_without_gust_keeps_the_base_turbulence(self) -> None:
        self.assertNotIn("groundTurbulence", DCSWeatherConverter.to_dcs_lua_table(wind_speed_mps=5))

    def test_a_manual_gust_and_an_explicit_turbulence(self) -> None:
        gusty = DCSWeatherConverter.to_dcs_lua_table(wind_speed_mps=5, wind_gust_mps=6)
        self.assertEqual(gusty["groundTurbulence"], round(10 * turbulence_for_gust(5 * 1.943844, 6 * 1.943844)))
        explicit = DCSWeatherConverter.to_dcs_lua_table(wind_speed_mps=5, wind_gust_mps=10, turbulence_mps=1.5)
        self.assertEqual(explicit["groundTurbulence"], 15)

    def test_the_gust_is_parsed(self) -> None:
        values = _extract_metar_values("OSDI 151420Z 27015G25KT 9999")
        self.assertAlmostEqual(values["wind_gust"], 25 * 0.51444)
        self.assertIsNone(_extract_metar_values("OSDI 151420Z 27015KT 9999")["wind_gust"])

    def test_clearsky_drops_the_gust(self) -> None:
        self.assertNotIn("wind_gust", cap_clearsky({"wind_speed": 5, "wind_gust": 9}))
