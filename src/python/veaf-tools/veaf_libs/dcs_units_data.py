"""Look up a DCS unit type's category at design time.

A mission table files aircraft under **two different keys** — ``plane`` and ``helicopter`` — and
they are not interchangeable: a helicopter written under ``plane`` opens in the Mission Editor as an
AIRPLANE GROUP with its type shown in red, and the slot cannot be flown. Nothing in the mission
file marks it as wrong, because the category is structural rather than a validated field.

Backed by the generated ``data/dcsUnits.yaml`` — the same database the build ships and the MCP
oracle's ``list_unit_types`` serves — so a caller's notion of "is this a helicopter" cannot drift
from what the tooling actually knows about (see ``veaf-build update-dcs-data``).
"""

from __future__ import annotations

import functools

import yaml

from veaf_libs.bundled_data import read_bundled_text


@functools.lru_cache(maxsize=1)
def _categories() -> dict[str, str]:
    """Load (and cache) the ``{type_lower: category}`` table from ``dcsUnits.yaml``."""
    raw = yaml.safe_load(read_bundled_text("veaf_libs", "data", "dcsUnits.yaml")) or {}
    table: dict[str, str] = {}
    for entry in raw.get("units") or []:
        unit_type = str(entry.get("type") or "").strip()
        category = str(entry.get("category") or "").strip()
        if unit_type and category:
            table[unit_type.lower()] = category
    return table


def get_unit_category(unit_type: str) -> str | None:
    """Return a unit type's DCS category, or ``None`` when the type is unknown.

    Args:
        unit_type: The DCS type name (e.g. ``"UH-1H"``), case-insensitive.

    Returns:
        The category as the database spells it (``"Helicopter"``, ``"Plane"``, ``"Armor"``, …), or
        ``None`` for a type the database does not carry — which includes third-party mods, so an
        unknown type is a normal outcome and not an error.
    """
    if not unit_type:
        return None
    return _categories().get(unit_type.strip().lower())
