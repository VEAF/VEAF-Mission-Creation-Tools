"""Tests for veaf_libs.dcs_units_parser (YAML-sourced DCS units database)."""

from pathlib import Path

from veaf_libs.dcs_units_parser import (
    DcsUnit,
    _is_meaningful_attribute,
    generate_dcs_units_doc,
    generate_reference_markdown,
    parse_dcs_units,
)

# ---------------------------------------------------------------------------
# Synthetic YAML fixture
# ---------------------------------------------------------------------------

_YAML = """\
# DCS units database (type, kind, category, attributes).
# Source ref: dc7d15e8e34150441b109346eea4ca18eb0104a7
units:
- type: "2S6 Tunguska"
  name: SAM Tunguska
  kind: vehicle
  category: Air Defence
  description: SAM Tunguska
  attributes:
  - SAM SR
  - Vehicles
- type: A-10A
  name: A-10A Warthog
  kind: air
  category: Plane
  description: A-10A Warthog
  attributes: []
naval_statics:
- Oil platform
"""


def _write_yaml(tmp_path: Path) -> Path:
    p = tmp_path / "dcsUnits.yaml"
    p.write_text(_YAML, encoding="utf-8")
    return p


def test_parse_returns_units(tmp_path: Path) -> None:
    units = parse_dcs_units(_write_yaml(tmp_path))
    assert len(units) == 2
    tunguska = next(u for u in units if u.type_id == "2S6 Tunguska")
    assert tunguska.name == "SAM Tunguska"
    assert tunguska.category == "Air Defence"
    assert tunguska.kind == "vehicle"
    assert "SAM SR" in tunguska.attributes


def test_parse_empty_file(tmp_path: Path) -> None:
    p = tmp_path / "empty.yaml"
    p.write_text("units: []\n", encoding="utf-8")
    assert parse_dcs_units(p) == []


def test_meaningful_attribute_filter() -> None:
    assert _is_meaningful_attribute("SAM SR")
    assert not _is_meaningful_attribute("All")
    assert not _is_meaningful_attribute("Vehicles")
    assert not _is_meaningful_attribute("123")


def test_markdown_groups_by_category() -> None:
    units = [
        DcsUnit("A-10A", "A-10A", "Plane", "A-10A", kind="air"),
        DcsUnit("2S6 Tunguska", "SAM", "Air Defence", "SAM", kind="vehicle", attributes=["SAM SR", "All"]),
    ]
    md = generate_reference_markdown(units, db_version="datamine-dc7d15e8")
    assert "# DCS World Units Reference" in md
    assert "## Plane" in md
    assert "## Air Defence" in md
    assert "datamine-dc7d15e8" in md
    # Generic attributes are filtered out, meaningful ones kept.
    assert "SAM SR" in md
    assert "| All |" not in md


def test_generate_doc_writes_file(tmp_path: Path) -> None:
    out = tmp_path / "ref.md"
    count = generate_dcs_units_doc(out, _write_yaml(tmp_path))
    assert count == 2
    text = out.read_text(encoding="utf-8")
    assert "A-10A" in text
    # db version read from the YAML header comment
    assert "datamine-dc7d15e8" in text


def test_committed_yaml_parses() -> None:
    """The real committed dcsUnits.yaml parses into a substantial unit list."""
    yaml_path = (
        Path(__file__).parents[3] / "src" / "python" / "veaf-tools" / "veaf_libs" / "data" / "dcsUnits.yaml"
    )
    units = parse_dcs_units(yaml_path)
    assert len(units) > 600
    assert all(u.type_id for u in units)
