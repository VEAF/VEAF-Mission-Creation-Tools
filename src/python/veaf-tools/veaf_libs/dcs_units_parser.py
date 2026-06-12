"""DCS World units database parser.

Reads the canonical ``dcsUnits.yaml`` (generated from the datamine by
``veaf-build update-dcs-data --units``) and produces a Markdown reference
document listing all known unit types, organized by category.

Typical usage by ``build-and-release.py``:

    from veaf_libs.dcs_units_parser import generate_dcs_units_doc

    count = generate_dcs_units_doc(
        output_path=build_dir / "dcs-units-reference.md",
        yaml_path=src_dir / "python/veaf-tools/veaf_libs/data/dcsUnits.yaml",
    )
"""

import re
from dataclasses import dataclass, field
from datetime import date
from pathlib import Path

import yaml

# ---------------------------------------------------------------------------
# Data model
# ---------------------------------------------------------------------------


@dataclass
class DcsUnit:
    """A single unit entry from the DCS units database."""

    type_id: str
    """The DCS internal type identifier (used in mission files and VEAF markers)."""

    name: str
    """Human-readable display name."""

    category: str
    """Top-level category (Plane, Helicopter, Armor, Ship, …)."""

    description: str
    """DCS description string (may duplicate name)."""

    kind: str = ""
    """Coarse VEAF kind: ``air`` / ``naval`` / ``infantry`` / ``vehicle`` / ``static``."""

    attributes: list[str] = field(default_factory=list)
    """Named DCS attribute flags (tactical role identifiers)."""


# ---------------------------------------------------------------------------
# Attributes that carry no useful tactical information
# ---------------------------------------------------------------------------

_GENERIC_ATTRIBUTES: frozenset[str] = frozenset(
    {
        "All",
        "Air",
        "Vehicles",
        "Ground Units",
        "Ground vehicles",
        "NonArmoredUnits",
        "NonAndLightArmoredUnits",
        "LightArmoredUnits",
        "Planes",
        "Helicopters",
        "Ships",
        "Infantry",
        "Static objects",
        "Ground Objects",
    }
)


def _is_meaningful_attribute(attr: str) -> bool:
    """Return True for attribute names that carry tactical information."""
    return attr not in _GENERIC_ATTRIBUTES and not attr.isdigit()


# ---------------------------------------------------------------------------
# Parsing
# ---------------------------------------------------------------------------


def parse_dcs_units(yaml_path: Path) -> list[DcsUnit]:
    """Parse the units YAML and return the list of :class:`DcsUnit` entries.

    Args:
        yaml_path: Path to the committed ``dcsUnits.yaml``.

    Returns:
        The parsed units (empty if the file has no ``units`` list).
    """
    data = yaml.safe_load(yaml_path.read_text(encoding="utf-8")) or {}
    units: list[DcsUnit] = []
    for entry in data.get("units") or []:
        units.append(
            DcsUnit(
                type_id=entry.get("type", ""),
                name=entry.get("name", ""),
                category=entry.get("category", ""),
                description=entry.get("description", ""),
                kind=entry.get("kind", ""),
                attributes=list(entry.get("attributes") or []),
            )
        )
    return units


def _read_db_version(yaml_path: Path) -> str:
    """Extract the datamine provenance ref from the YAML header comment, if present."""
    for line in yaml_path.read_text(encoding="utf-8").splitlines():
        m = re.match(r"#\s*Source ref:\s*(\S+)", line)
        if m:
            return f"datamine-{m.group(1)[:8]}"
    return ""


# ---------------------------------------------------------------------------
# Markdown generation
# ---------------------------------------------------------------------------


def _escape_md(text: str) -> str:
    """Escape characters that break Markdown table cells."""
    return text.replace("|", "\\|")


def generate_reference_markdown(units: list[DcsUnit], db_version: str = "") -> str:
    """Return a Markdown reference document for *units*.

    The document contains:
    * A table of contents with unit counts per category.
    * One section per category with a table of type IDs, names, and
      meaningful tactical attributes.
    """
    by_category: dict[str, list[DcsUnit]] = {}
    for unit in units:
        cat = unit.category or "Unknown"
        by_category.setdefault(cat, []).append(unit)

    lines: list[str] = []

    # Header
    lines += [
        "# DCS World Units Reference",
        "",
        f"*Generated on {date.today().isoformat()}*  ",
    ]
    if db_version:
        lines.append(f"*DCS Units database version: {db_version}*  ")
    lines += [
        f"*{len(units)} units across {len(by_category)} categories*",
        "",
    ]

    # Table of contents
    lines += ["## Categories", ""]
    for cat in sorted(by_category):
        count = len(by_category[cat])
        anchor = cat.lower().replace(" ", "-").replace("/", "")
        lines.append(f"- [{cat}](#{anchor}) ({count} units)")
    lines.append("")

    # One section per category
    for cat in sorted(by_category):
        lines += [f"## {cat}", ""]
        cat_units = sorted(by_category[cat], key=lambda u: u.type_id.lower())
        lines += ["| Type ID | Name | Attributes |", "|---------|------|------------|"]

        for unit in cat_units:
            type_id = _escape_md(unit.type_id)
            name = _escape_md(unit.name or unit.description)
            meaningful = [a for a in unit.attributes if _is_meaningful_attribute(a)]
            attrs = _escape_md(", ".join(meaningful))
            lines.append(f"| `{type_id}` | {name} | {attrs} |")

        lines.append("")

    return "\n".join(lines)


# ---------------------------------------------------------------------------
# Build-time entry point
# ---------------------------------------------------------------------------


def generate_dcs_units_doc(output_path: Path, yaml_path: Path) -> int:
    """Parse *yaml_path* and write the Markdown reference to *output_path*.

    Called by ``build-and-release.py`` after the DCS data is generated.

    Args:
        output_path: Destination Markdown file.
        yaml_path: Source ``dcsUnits.yaml``.

    Returns:
        Number of units documented.
    """
    units = parse_dcs_units(yaml_path)
    db_version = _read_db_version(yaml_path)
    md = generate_reference_markdown(units, db_version)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(md, encoding="utf-8")
    return len(units)
