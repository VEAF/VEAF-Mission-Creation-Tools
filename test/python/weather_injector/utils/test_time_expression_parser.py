"""Tests for TimeExpressionParser — all branches including eval edge cases.

Covers:
- HH:MM clock format (valid, invalid hours, invalid minutes)
- sunrise / sunset keyword substitution
- sunrise/sunset without solar times → ValueError
- Mathematical expressions with solar references
- Direct numeric strings
- Clamping: values > 86400 → 86400, < 0 → 0
- Invalid expressions → ValueError
- Restricted eval: __builtins__ blocked
"""

from __future__ import annotations

import unittest

from weather_injector.utils.time_expression_parser import TimeExpressionParser


class TestHHMMFormat(unittest.TestCase):
    """HH:MM clock format parsing."""

    def test_midnight(self) -> None:
        self.assertEqual(TimeExpressionParser.parse("00:00"), 0)

    def test_two_hours(self) -> None:
        self.assertEqual(TimeExpressionParser.parse("02:00"), 7200)

    def test_end_of_day(self) -> None:
        self.assertEqual(TimeExpressionParser.parse("23:59"), 23 * 3600 + 59 * 60)

    def test_noon(self) -> None:
        self.assertEqual(TimeExpressionParser.parse("12:30"), 12 * 3600 + 30 * 60)

    def test_invalid_hours_raises(self) -> None:
        with self.assertRaises(ValueError):
            TimeExpressionParser.parse("25:00")

    def test_invalid_minutes_raises(self) -> None:
        with self.assertRaises(ValueError):
            TimeExpressionParser.parse("12:60")

    def test_whitespace_stripped(self) -> None:
        self.assertEqual(TimeExpressionParser.parse("  06:00  "), 6 * 3600)


class TestSolarKeywords(unittest.TestCase):
    """sunrise / sunset keyword substitution."""

    def test_sunrise_keyword_exact(self) -> None:
        self.assertEqual(TimeExpressionParser.parse("sunrise", sunrise_seconds=21600), 21600)

    def test_sunset_keyword_exact(self) -> None:
        self.assertEqual(TimeExpressionParser.parse("sunset", sunset_seconds=72000), 72000)

    def test_sunrise_without_solar_times_raises(self) -> None:
        with self.assertRaises(ValueError):
            TimeExpressionParser.parse("sunrise")

    def test_sunset_without_solar_times_raises(self) -> None:
        with self.assertRaises(ValueError):
            TimeExpressionParser.parse("sunset")

    def test_sunrise_in_expression_requires_solar(self) -> None:
        with self.assertRaises(ValueError):
            TimeExpressionParser.parse("sunrise+3600")


class TestMathExpressions(unittest.TestCase):
    """Mathematical expressions evaluated with restricted builtins."""

    def test_direct_integer_string(self) -> None:
        self.assertEqual(TimeExpressionParser.parse("54000"), 54000)

    def test_sunrise_plus_30_minutes(self) -> None:
        result = TimeExpressionParser.parse("sunrise+30*60", sunrise_seconds=21600)
        self.assertEqual(result, 21600 + 1800)

    def test_sunset_minus_30_minutes(self) -> None:
        result = TimeExpressionParser.parse("sunset-30*60", sunset_seconds=72000)
        self.assertEqual(result, 72000 - 1800)

    def test_both_sunrise_and_sunset_in_expression(self) -> None:
        # midpoint between sunrise and sunset
        result = TimeExpressionParser.parse(
            "(sunrise+sunset)//2",
            sunrise_seconds=21600,
            sunset_seconds=72000,
        )
        self.assertEqual(result, (21600 + 72000) // 2)


class TestClamping(unittest.TestCase):
    """Values outside [0, 86400] must be clamped."""

    def test_large_value_clamped_to_86400(self) -> None:
        self.assertEqual(TimeExpressionParser.parse("90000+10000"), 86400)

    def test_negative_value_clamped_to_zero(self) -> None:
        result = TimeExpressionParser.parse("sunrise-100000", sunrise_seconds=1000)
        self.assertEqual(result, 0)

    def test_exactly_86400_not_clamped(self) -> None:
        self.assertEqual(TimeExpressionParser.parse("86400"), 86400)

    def test_exactly_zero_not_clamped(self) -> None:
        self.assertEqual(TimeExpressionParser.parse("0"), 0)


class TestInvalidExpressions(unittest.TestCase):
    """Invalid expressions must raise ValueError."""

    def test_plain_text_raises(self) -> None:
        with self.assertRaises(ValueError):
            TimeExpressionParser.parse("not_a_valid_expression")

    def test_builtin_access_blocked(self) -> None:
        # __builtins__ is {} in the restricted eval namespace
        with self.assertRaises(ValueError):
            TimeExpressionParser.parse("__import__('os').getpid()")

    def test_empty_string_raises(self) -> None:
        with self.assertRaises((ValueError, SyntaxError)):
            TimeExpressionParser.parse("")


class TestSafeEvaluator(unittest.TestCase):
    """SECREV-003 — the arithmetic evaluator must not execute arbitrary code."""

    def test_power_operator_rejected_dos_guard(self) -> None:
        # Exponentiation can produce gigantic numbers (DoS); it is not allowed.
        with self.assertRaises(ValueError):
            TimeExpressionParser.parse("2**100000000")

    def test_function_call_rejected(self) -> None:
        with self.assertRaises(ValueError):
            TimeExpressionParser.parse("pow(2, 3)")

    def test_attribute_access_rejected(self) -> None:
        with self.assertRaises(ValueError):
            TimeExpressionParser.parse("(1).__class__")

    def test_bare_name_rejected(self) -> None:
        with self.assertRaises(ValueError):
            TimeExpressionParser.parse("foo+1")

    def test_division_by_zero_raises_value_error(self) -> None:
        with self.assertRaises(ValueError):
            TimeExpressionParser.parse("3600//0")

    def test_parentheses_and_precedence(self) -> None:
        self.assertEqual(TimeExpressionParser.parse("(1+2)*1000"), 3000)


if __name__ == "__main__":
    unittest.main()
