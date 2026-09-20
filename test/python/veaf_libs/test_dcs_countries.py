"""Tests for the DCS country name -> id lookup (veaf_libs.dcs_countries)."""

from __future__ import annotations

import unittest

from veaf_libs.dcs_countries import all_country_ids, country_id_for_name, country_name_for_id


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


class TestCountryNameForId(unittest.TestCase):
    """country_name_for_id turns an id back into something a mission maker recognises.

    A validator that prints a bare `[68]` sends the reader hunting for a table the documentation does
    not carry — which is exactly what happened to the mission maker who reported this.
    """

    def test_a_known_id_resolves_to_its_name(self) -> None:
        """The id that started this lot must read as a country."""
        self.assertEqual(country_name_for_id(68), "USSR")

    def test_the_name_is_the_canonical_one(self) -> None:
        """Not the short code, not the international display name."""
        self.assertEqual(country_name_for_id(5), "France")

    def test_an_unknown_id_returns_none(self) -> None:
        """DCS has no country at 14, and none past the end of the table."""
        self.assertIsNone(country_name_for_id(14))
        self.assertIsNone(country_name_for_id(9999))

    def test_it_round_trips_with_the_forward_lookup(self) -> None:
        """Every id the tools may meet resolves to a name that resolves back to the same id."""
        for country_id in all_country_ids():
            name = country_name_for_id(country_id)
            self.assertIsNotNone(name, f"id {country_id} has no name")
            self.assertEqual(country_id_for_name(name or ""), country_id)


if __name__ == "__main__":
    unittest.main()
