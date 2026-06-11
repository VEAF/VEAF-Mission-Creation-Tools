"""Tests for the DCS country name -> id lookup (veaf_libs.dcs_countries)."""

from __future__ import annotations

import unittest

from veaf_libs.dcs_countries import country_id_for_name


class TestCountryIdForName(unittest.TestCase):
    """country_id_for_name resolves names against the generated DCS table."""

    def test_canonical_name(self) -> None:
        """A canonical country name resolves to its DCS id."""
        self.assertEqual(country_id_for_name("France"), 5)
        self.assertEqual(country_id_for_name("Russia"), 0)
        self.assertEqual(country_id_for_name("USA"), 2)

    def test_case_insensitive(self) -> None:
        """Matching ignores case and surrounding whitespace."""
        self.assertEqual(country_id_for_name("france"), 5)
        self.assertEqual(country_id_for_name("  FRANCE  "), 5)

    def test_international_display_name(self) -> None:
        """The Mission Editor display name (InternationalName) resolves too."""
        # File Name is "Combined Joint Task Forces Blue"; missions use "CJTF Blue".
        self.assertEqual(country_id_for_name("CJTF Blue"), 80)

    def test_short_code(self) -> None:
        """The short code resolves to the same id as the canonical name."""
        self.assertEqual(country_id_for_name("FRA"), country_id_for_name("France"))

    def test_unknown_name_returns_none(self) -> None:
        """An unknown name yields None rather than raising."""
        self.assertIsNone(country_id_for_name("Wakanda"))

    def test_empty_name_returns_none(self) -> None:
        """An empty name yields None."""
        self.assertIsNone(country_id_for_name(""))


if __name__ == "__main__":
    unittest.main()
