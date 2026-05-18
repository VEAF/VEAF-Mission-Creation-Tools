"""DCS World units database parser.

Parses ``dcsUnits.lua`` (the VEAF-maintained copy of the DCS unit database)
and generates a Markdown reference document listing all known unit types,
organized by category.

Typical usage by ``build-and-release.py``:

    from veaf_libs.dcs_units_parser import generate_dcs_units_doc

    count = generate_dcs_units_doc(
        output_path=build_dir / "dcs-units-reference.md",
        lua_path=build_dir / "dcsUnits.lua",
    )
"""

import re
from dataclasses import dataclass, field
from datetime import date
from pathlib import Path

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

    aliases: list[str] = field(default_factory=list)
    """Alternative identifiers recognised by VEAF spawning commands."""

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

_RE_ENTRY_START = re.compile(r"^\[\d+\]\s*=\s*\{?\s*(--.*)?$")
# Closing-brace pattern: matches `}`, `},`, or `}, -- any comment`.
# The state machine knows which block we are in, so a single loose pattern
# serves for entry ends, attribute sub-table ends, and aliases sub-table ends.
_RE_CLOSE = re.compile(r"^\},?\s*(--.*)?$")
_RE_ATTR_OPEN = re.compile(r'^\["attribute"\]\s*=\s*\{?\s*(--.*)?$')
_RE_ALIAS_OPEN = re.compile(r'^\["aliases"\]\s*=\s*\{?\s*(--.*)?$')
_RE_STRING_FLAG = re.compile(r'^\["([^"]+)"\]\s*=\s*true\s*,?$')
_RE_ALIAS_VALUE = re.compile(r'^\[\d+\]\s*=\s*"([^"]+)"\s*,?$')
_RE_FIELD = re.compile(r'^\["([^"]+)"\]\s*=\s*"([^"]*)"\s*,?$')


def _parse_units(content: str) -> list[DcsUnit]:
    """Extract all unit entries from the raw text of ``dcsUnits.lua``."""
    units: list[DcsUnit] = []
    current: dict[str, str] | None = None
    attrs: list[str] = []
    aliases: list[str] = []
    in_database = False
    in_attribute = False
    in_aliases = False

    for raw_line in content.splitlines():
        line = raw_line.strip()

        # ── locate the database table ────────────────────────────────────────
        if not in_database:
            if "dcsUnits.DcsUnitsDatabase" in line:
                in_database = True
            continue

        # ── end of the whole database ────────────────────────────────────────
        # The outer closing brace ends the table; stop parsing.
        if line == "}" and current is None:
            break

        # ── inside an attribute sub-table ────────────────────────────────────
        if in_attribute:
            if _RE_CLOSE.match(line):
                in_attribute = False
            elif m := _RE_STRING_FLAG.match(line):
                attrs.append(m.group(1))
            continue

        # ── inside an aliases sub-table ──────────────────────────────────────
        if in_aliases:
            if _RE_CLOSE.match(line):
                in_aliases = False
            elif m := _RE_ALIAS_VALUE.match(line):
                aliases.append(m.group(1))
            continue

        # ── between entries ──────────────────────────────────────────────────
        if current is None:
            if _RE_ENTRY_START.match(line):
                current = {}
                attrs = []
                aliases = []
            continue

        # ── inside an entry ──────────────────────────────────────────────────
        if _RE_CLOSE.match(line):
            units.append(
                DcsUnit(
                    type_id=current.get("type", ""),
                    name=current.get("name", ""),
                    category=current.get("category", ""),
                    description=current.get("description", ""),
                    aliases=list(aliases),
                    attributes=list(attrs),
                )
            )
            current = None
            in_attribute = False
            in_aliases = False
            continue

        if _RE_ATTR_OPEN.match(line):
            in_attribute = True
            continue

        if _RE_ALIAS_OPEN.match(line):
            in_aliases = True
            continue

        if m := _RE_FIELD.match(line):
            fname, fval = m.group(1), m.group(2)
            if fname in {"type", "name", "category", "description"}:
                current[fname] = fval

    return units


def parse_dcs_units(lua_path: Path) -> list[DcsUnit]:
    """Parse *lua_path* and return the list of :class:`DcsUnit` entries."""
    content = lua_path.read_text(encoding="utf-8", errors="ignore")
    return _parse_units(content)


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


def generate_dcs_units_doc(output_path: Path, lua_path: Path) -> int:
    """Parse *lua_path* and write the Markdown reference to *output_path*.

    Called by ``build-and-release.py`` after the Lua scripts are built.

    Returns:
        Number of units documented.
    """
    content = lua_path.read_text(encoding="utf-8", errors="ignore")
    units = _parse_units(content)

    ver_match = re.search(r'dcsUnits\.Version\s*=\s*"([^"]+)"', content)
    db_version = ver_match.group(1) if ver_match else ""

    md = generate_reference_markdown(units, db_version)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(md, encoding="utf-8")
    return len(units)
