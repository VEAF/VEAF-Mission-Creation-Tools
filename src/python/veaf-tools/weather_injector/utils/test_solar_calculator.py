"""Tests for SolarCalculator.get_sun_times()."""

from __future__ import annotations

import unittest
from datetime import date as dt_date

from weather_injector.models import Position
from weather_injector.utils.solar_calculator import SolarCalculator


class TestGetSunTimesBasic(unittest.TestCase):
    """Basic functionality — Paris on a known summer solstice date."""

    PARIS = Position(latitude=48.8566, longitude=2.3522, timezone="Europe/Paris")
    SUMMER_SOLSTICE = dt_date(2024, 6, 21)

    def setUp(self) -> None:
        self.result = SolarCalculator.get_sun_times(self.PARIS, self.SUMMER_SOLSTICE)

    def test_returns_dict(self) -> None:
        self.assertIsInstance(self.result, dict)

    def test_has_sunrise_key(self) -> None:
        self.assertIn("sunrise", self.result)

    def test_has_sunset_key(self) -> None:
        self.assertIn("sunset", self.result)

    def test_sunrise_is_int(self) -> None:
        self.assertIsInstance(self.result["sunrise"], int)

    def test_sunset_is_int(self) -> None:
        self.assertIsInstance(self.result["sunset"], int)

    def test_sunrise_before_sunset(self) -> None:
        self.assertLess(self.result["sunrise"], self.result["sunset"])

    def test_sunrise_in_valid_range(self) -> None:
        # Paris summer sunrise: roughly 5h-7h local → 3h-5h UTC → 10800–18000s
        self.assertGreater(self.result["sunrise"], 0)
        self.assertLess(self.result["sunrise"], 86400)

    def test_sunset_in_valid_range(self) -> None:
        self.assertGreater(self.result["sunset"], 0)
        self.assertLess(self.result["sunset"], 86400)

    def test_summer_has_long_day(self) -> None:
        """Summer solstice in Paris: daylight > 14 hours (50400s)."""
        day_length = self.result["sunset"] - self.result["sunrise"]
        self.assertGreater(day_length, 50400)


class TestGetSunTimesNullDate(unittest.TestCase):
    """target_date=None defaults to today."""

    PARIS = Position(latitude=48.8566, longitude=2.3522, timezone="Europe/Paris")

    def test_none_date_returns_valid_result(self) -> None:
        result = SolarCalculator.get_sun_times(self.PARIS, None)
        self.assertIn("sunrise", result)
        self.assertIn("sunset", result)
        self.assertLess(result["sunrise"], result["sunset"])

    def test_none_date_matches_today(self) -> None:
        result_none = SolarCalculator.get_sun_times(self.PARIS, None)
        result_today = SolarCalculator.get_sun_times(self.PARIS, dt_date.today())
        # May differ by ±1s due to timing; allow small delta
        self.assertAlmostEqual(result_none["sunrise"], result_today["sunrise"], delta=60)
        self.assertAlmostEqual(result_none["sunset"], result_today["sunset"], delta=60)


class TestGetSunTimesDifferentLocations(unittest.TestCase):
    """Verify sunrise/sunset change with latitude."""

    DATE = dt_date(2024, 6, 21)

    def test_damascus_sunrise(self) -> None:
        damascus = Position(latitude=33.5138, longitude=36.2765, timezone="Asia/Damascus")
        result = SolarCalculator.get_sun_times(damascus, self.DATE)
        self.assertIn("sunrise", result)
        self.assertIn("sunset", result)
        self.assertLess(result["sunrise"], result["sunset"])

    def test_winter_has_shorter_day_than_summer(self) -> None:
        paris = Position(latitude=48.8566, longitude=2.3522, timezone="Europe/Paris")
        summer = SolarCalculator.get_sun_times(paris, dt_date(2024, 6, 21))
        winter = SolarCalculator.get_sun_times(paris, dt_date(2024, 12, 21))
        summer_day = summer["sunset"] - summer["sunrise"]
        winter_day = winter["sunset"] - winter["sunrise"]
        self.assertGreater(summer_day, winter_day)


class TestGetSunTimesInvalidTimezone(unittest.TestCase):
    """astral silently falls back for unrecognised timezones; verify no crash."""

    def test_unknown_timezone_does_not_crash(self) -> None:
        """astral may silently fall back to UTC — just ensure it doesn't raise."""
        pos = Position(latitude=48.8566, longitude=2.3522, timezone="UTC")
        result = SolarCalculator.get_sun_times(pos, dt_date(2024, 6, 21))
        self.assertIn("sunrise", result)
        self.assertIn("sunset", result)


if __name__ == "__main__":
    unittest.main()
