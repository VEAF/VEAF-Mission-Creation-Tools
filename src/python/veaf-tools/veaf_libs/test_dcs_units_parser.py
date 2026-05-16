"""Tests for veaf_libs.dcs_units_parser."""

import textwrap
from pathlib import Path

import pytest

from veaf_libs.dcs_units_parser import (
    DcsUnit,
    _is_meaningful_attribute,
    _parse_units,
    generate_dcs_units_doc,
    generate_reference_markdown,
    parse_dcs_units,
)

# ---------------------------------------------------------------------------
# Synthetic Lua fixture
# ---------------------------------------------------------------------------

_LUA_SNIPPET = textwrap.dedent(
    """\
    dcsUnits = {}
    dcsUnits.Version = "2025.01.01"
    dcsUnits.DcsUnitsDatabase =
    {
    \t[1] =\t
    \t{
    \t\t["type"] = "2S6 Tunguska",
    \t\t["name"] = "SAM Tunguska",
    \t\t["category"] = "Air Defence",
    \t\t["description"] = "SAM SA-19",
    \t\t["vehicle"] = true,
    \t\t["attribute"] =\t
    \t\t{
    \t\t\t[1] = true,
    \t\t\t["All"] = true,
    \t\t\t["SAM TR"] = true,
    \t\t\t["Air Defence"] = true,
    \t\t\t["Vehicles"] = true,
    \t\t}, -- end of ["attribute"]
    \t\t["aliases"] =\t
    \t\t{
    \t\t\t[1] = "SA-19",
    \t\t}, -- end of ["aliases"]
    \t}, -- end of [1]
    \t[2] =\t
    \t{
    \t\t["type"] = "F-16C_50",
    \t\t["name"] = "F-16C Viper",
    \t\t["category"] = "Plane",
    \t\t["description"] = "F-16C",
    \t\t["attribute"] =\t
    \t\t{
    \t\t\t["Planes"] = true,
    \t\t\t["Air"] = true,
    \t\t\t["Fighters"] = true,
    \t\t}, -- end of ["attribute"]
    \t\t["aliases"] =\t
    \t\t{
    \t\t}, -- end of ["aliases"]
    \t}, -- end of [2]
    \t[3] =\t
    \t{
    \t\t["type"] = "T-80UD",
    \t\t["name"] = "T-80",
    \t\t["category"] = "Armor",
    \t\t["description"] = "Tank T-80",
    \t\t["attribute"] =\t
    \t\t{
    \t\t\t["Armored vehicles"] = true,
    \t\t\t["NonAndLightArmoredUnits"] = true,
    \t\t}, -- end of ["attribute"]
    \t\t["aliases"] =\t
    \t\t{
    \t\t}, -- end of ["aliases"]
    \t}, -- end of [3]
    } -- end of dcsUnits.DcsUnitsDatabase
    """
)


# ---------------------------------------------------------------------------
# Tests: _parse_units
# ---------------------------------------------------------------------------


class TestParseUnits:
    def test_returns_correct_count(self) -> None:
        units = _parse_units(_LUA_SNIPPET)
        assert len(units) == 3

    def test_first_unit_fields(self) -> None:
        unit = _parse_units(_LUA_SNIPPET)[0]
        assert unit.type_id == "2S6 Tunguska"
        assert unit.name == "SAM Tunguska"
        assert unit.category == "Air Defence"
        assert unit.description == "SAM SA-19"

    def test_aliases_extracted(self) -> None:
        unit = _parse_units(_LUA_SNIPPET)[0]
        assert unit.aliases == ["SA-19"]

    def test_empty_aliases(self) -> None:
        unit = _parse_units(_LUA_SNIPPET)[1]
        assert unit.aliases == []

    def test_attributes_extracted_string_keys_only(self) -> None:
        unit = _parse_units(_LUA_SNIPPET)[0]
        # Numeric [1] = true must NOT appear; string keys must
        assert "SAM TR" in unit.attributes
        assert "Air Defence" in unit.attributes
        # The numeric index should not appear
        assert "" not in unit.attributes
        assert "1" not in unit.attributes

    def test_empty_database_returns_empty_list(self) -> None:
        assert _parse_units("") == []

    def test_no_database_section_returns_empty_list(self) -> None:
        assert _parse_units("-- just a comment\n") == []

    def test_unit_with_only_type_and_category(self) -> None:
        lua = textwrap.dedent(
            """\
            dcsUnits.DcsUnitsDatabase =
            {
            \t[1] =\t
            \t{
            \t\t["type"] = "Minimal",
            \t\t["category"] = "Ship",
            \t\t["attribute"] =\t
            \t\t{
            \t\t}, -- end of ["attribute"]
            \t\t["aliases"] =\t
            \t\t{
            \t\t}, -- end of ["aliases"]
            \t}, -- end of [1]
            }
            """
        )
        units = _parse_units(lua)
        assert len(units) == 1
        assert units[0].type_id == "Minimal"
        assert units[0].name == ""
        assert units[0].category == "Ship"


# ---------------------------------------------------------------------------
# Shared fixture
# ---------------------------------------------------------------------------


@pytest.fixture()
def lua_file(tmp_path: Path) -> Path:
    """Write ``_LUA_SNIPPET`` to a temp file and return its path."""
    f = tmp_path / "dcsUnits.lua"
    f.write_text(_LUA_SNIPPET, encoding="utf-8")
    return f


# ---------------------------------------------------------------------------
# Tests: parse_dcs_units (file-based)
# ---------------------------------------------------------------------------


class TestParseDcsUnits:
    def test_reads_lua_file(self, lua_file: Path) -> None:
        units = parse_dcs_units(lua_file)
        assert len(units) == 3

    def test_encoding_errors_ignored(self, tmp_path: Path) -> None:
        """Non-UTF-8 bytes in the file should not raise an exception."""
        f = tmp_path / "dcsUnits.lua"
        f.write_bytes(b"dcsUnits.DcsUnitsDatabase =\n{\n}\n\xff\xfe")
        units = parse_dcs_units(f)
        assert isinstance(units, list)


# ---------------------------------------------------------------------------
# Tests: _is_meaningful_attribute
# ---------------------------------------------------------------------------


class TestIsMeaningfulAttribute:
    @pytest.mark.parametrize("attr", ["SAM TR", "Fighters", "EWR", "MANPADS"])
    def test_tactical_attributes_are_meaningful(self, attr: str) -> None:
        assert _is_meaningful_attribute(attr) is True

    @pytest.mark.parametrize("attr", ["All", "Vehicles", "Air", "Ground Units", "Helicopters"])
    def test_generic_attributes_are_not_meaningful(self, attr: str) -> None:
        assert _is_meaningful_attribute(attr) is False

    def test_digit_string_is_not_meaningful(self) -> None:
        assert _is_meaningful_attribute("42") is False


# ---------------------------------------------------------------------------
# Tests: generate_reference_markdown
# ---------------------------------------------------------------------------


class TestGenerateReferenceMarkdown:
    def setup_method(self) -> None:
        self.units = _parse_units(_LUA_SNIPPET)
        self.md = generate_reference_markdown(self.units)

    def test_contains_title(self) -> None:
        assert "# DCS World Units Reference" in self.md

    def test_contains_all_categories(self) -> None:
        assert "## Air Defence" in self.md
        assert "## Plane" in self.md
        assert "## Armor" in self.md

    def test_contains_type_id_as_code(self) -> None:
        assert "`2S6 Tunguska`" in self.md
        assert "`F-16C_50`" in self.md

    def test_contains_db_version_when_provided(self) -> None:
        md = generate_reference_markdown(self.units, db_version="2025.01.01")
        assert "2025.01.01" in md

    def test_no_version_line_when_empty(self) -> None:
        assert "DCS Units database version" not in self.md

    def test_generic_attributes_excluded_from_table(self) -> None:
        for line in self.md.splitlines():
            if line.startswith("|") and "`2S6 Tunguska`" in line:
                assert "Vehicles" not in line
                assert "All" not in line
                assert "SAM TR" in line

    def test_meaningful_attributes_included(self) -> None:
        assert "SAM TR" in self.md
        assert "Fighters" in self.md

    def test_empty_units_list(self) -> None:
        md = generate_reference_markdown([])
        assert "# DCS World Units Reference" in md
        assert "0 units" in md


# ---------------------------------------------------------------------------
# Tests: generate_dcs_units_doc
# ---------------------------------------------------------------------------


class TestGenerateDcsUnitsDoc:
    def _make_doc(self, lua_file: Path, tmp_path: Path, subpath: str = "ref.md") -> tuple[Path, int]:
        """Generate the reference doc and return (output_path, unit_count)."""
        out_path = tmp_path / subpath
        count = generate_dcs_units_doc(out_path, lua_file)
        return out_path, count

    def test_creates_output_file(self, lua_file: Path, tmp_path: Path) -> None:
        out_path = tmp_path / "docs" / "dcs-units-reference.md"
        count = generate_dcs_units_doc(out_path, lua_file)
        assert out_path.exists()
        assert count == 3

    def test_creates_parent_directory(self, lua_file: Path, tmp_path: Path) -> None:
        out_path = tmp_path / "nested" / "deep" / "ref.md"
        generate_dcs_units_doc(out_path, lua_file)
        assert out_path.exists()

    def test_markdown_content_and_version(self, lua_file: Path, tmp_path: Path) -> None:
        out_path, _ = self._make_doc(lua_file, tmp_path)
        content = out_path.read_text(encoding="utf-8")
        assert "# DCS World Units Reference" in content
        assert "`2S6 Tunguska`" in content
        assert "2025.01.01" in content
