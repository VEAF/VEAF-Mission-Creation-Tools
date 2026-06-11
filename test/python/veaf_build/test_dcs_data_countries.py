"""Tests for the DCS country-table provider (veaf_build.dcs_data.countries)."""

from __future__ import annotations

import unittest
from pathlib import Path
from tempfile import TemporaryDirectory

import yaml

from veaf_build.dcs_data.countries import (
    CountryEntry,
    extract_all_countries,
    parse_country_file,
    write_countries_yaml,
)

_FRANCE = """_G["db"]["Countries"]["#Index"] = {
\tInternationalName = "France",
\tName = "France",
\tOldID = "France",
\tShortName = "FRA",
\tUnits = {
\t\t\t\t\tName = "Ski Ramp",
\t},
\tWorldID = 5,
}
"""

_CJTF_BLUE = """_G["db"]["Countries"]["#Index"] = {
\tInternationalName = "CJTF Blue",
\tName = "Combined Joint Task Forces Blue",
\tShortName = "BLUE",
\tWorldID = 80,
}
"""


class TestParseCountryFile(unittest.TestCase):
    """parse_country_file extracts the top-level identity fields only."""

    def test_extracts_top_level_fields(self) -> None:
        """Name/WorldID/ShortName/InternationalName are read from the top level."""
        entry = parse_country_file(_FRANCE)
        self.assertEqual(entry, CountryEntry(5, "France", "FRA", "France"))

    def test_ignores_nested_name(self) -> None:
        """A deeply-indented nested ``Name`` does not shadow the top-level one."""
        entry = parse_country_file(_FRANCE)
        assert entry is not None
        self.assertEqual(entry.name, "France")  # not "Ski Ramp"

    def test_international_name_differs_from_name(self) -> None:
        """CJTF display name is captured separately from the canonical name."""
        entry = parse_country_file(_CJTF_BLUE)
        assert entry is not None
        self.assertEqual(entry.name, "Combined Joint Task Forces Blue")
        self.assertEqual(entry.international_name, "CJTF Blue")
        self.assertEqual(entry.id, 80)

    def test_missing_required_field_returns_none(self) -> None:
        """A file without a top-level Name/WorldID is not a country file."""
        self.assertIsNone(parse_country_file("\tShortName = \"X\"\n"))


class TestExtractAllCountries(unittest.TestCase):
    """extract_all_countries walks the Countries subtree and sorts by id."""

    def test_sorted_by_id(self) -> None:
        """Entries are returned sorted by their DCS id."""
        with TemporaryDirectory() as tmp:
            countries_dir = Path(tmp) / "_G" / "db" / "Countries"
            countries_dir.mkdir(parents=True)
            (countries_dir / "France.lua").write_text(_FRANCE, encoding="utf-8")
            (countries_dir / "CJTF Blue.lua").write_text(_CJTF_BLUE, encoding="utf-8")

            entries = extract_all_countries(Path(tmp))

        self.assertEqual([e.id for e in entries], [5, 80])

    def test_missing_subtree_raises(self) -> None:
        """A clone without the Countries subtree raises FileNotFoundError."""
        with TemporaryDirectory() as tmp:
            with self.assertRaises(FileNotFoundError):
                extract_all_countries(Path(tmp))


class TestWriteCountriesYaml(unittest.TestCase):
    """write_countries_yaml emits a provenance header and parseable data."""

    def test_roundtrip(self) -> None:
        """The written YAML carries the ref header and the country rows."""
        entries = [CountryEntry(5, "France", "FRA", "France")]
        with TemporaryDirectory() as tmp:
            out = Path(tmp) / "dcs-countries.yaml"
            write_countries_yaml(entries, out, ref="abc123")

            text = out.read_text(encoding="utf-8")
            self.assertIn("Source ref: abc123", text)
            data = yaml.safe_load(text)

        self.assertEqual(
            data["countries"],
            [{"id": 5, "name": "France", "short": "FRA", "international": "France"}],
        )


if __name__ == "__main__":
    unittest.main()
