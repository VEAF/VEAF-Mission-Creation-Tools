"""Look up a DCS unit type's category and fuel capacity at design time.

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
from typing import Any

import yaml

from veaf_libs.bundled_data import read_bundled_text


@functools.lru_cache(maxsize=1)
def _categories() -> dict[str, str]:
    """Load (and cache) the ``{type_lower: category}`` table from ``dcsUnits.yaml``."""
    raw = yaml.safe_load(read_bundled_text("veaf_libs", "data", "dcsUnits.yaml"))
    # A malformed or reshaped file yields an empty table rather than an AttributeError mid-build:
    # every caller already handles "type not found", and that is the safer of the two failures.
    units = raw.get("units") if isinstance(raw, dict) else None
    table: dict[str, str] = {}
    for entry in units or []:
        if not isinstance(entry, dict):
            continue
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


def get_unit_types_in_category(category: str) -> list[str]:
    """Return every unit type of one DCS category, spelled as DCS spells it, in database order.

    The spelling matters to a caller that writes the types into Lua: the runtime looks a type up by
    the exact name a unit reports, and the other lookups here are keyed lower-case.

    Args:
        category: The category as the database spells it (``"Helicopter"``, ``"Plane"``…).

    Returns:
        The type names, e.g. ``["AH-1W", "AH-64A", …]``; empty for an unknown category.
    """
    return [str(entry["type"]).strip() for entry in _entries().values() if entry.get("category") == category]


@functools.lru_cache(maxsize=1)
def _fuel_capacities() -> dict[str, float]:
    """Load (and cache) the ``{type_lower: fuel_capacity}`` table from ``dcsUnits.yaml``."""
    raw = yaml.safe_load(read_bundled_text("veaf_libs", "data", "dcsUnits.yaml"))
    units = raw.get("units") if isinstance(raw, dict) else None
    table: dict[str, float] = {}
    for entry in units or []:
        if not isinstance(entry, dict):
            continue
        unit_type = str(entry.get("type") or "").strip()
        capacity = entry.get("fuel_capacity")
        if unit_type and isinstance(capacity, (int, float)) and not isinstance(capacity, bool):
            table[unit_type.lower()] = float(capacity)
    return table


def get_unit_fuel_capacity(unit_type: str) -> float | None:
    """Return a unit type's maximum internal fuel in kg, or ``None`` when unknown.

    Only air units carry one — the database holds a capacity for every stock plane and helicopter
    and for nothing else, so ``None`` means either a ground unit or a type the database does not
    know at all (a third-party mod). Both are normal outcomes rather than errors; it is the caller
    who decides whether it can proceed without the value.

    Args:
        unit_type: The DCS type name (e.g. ``"F-15C"``), case-insensitive.

    Returns:
        The capacity in kg, or ``None``.
    """
    if not unit_type:
        return None
    return _fuel_capacities().get(unit_type.strip().lower())


@functools.lru_cache(maxsize=1)
def _entries() -> dict[str, dict[str, Any]]:
    """Load (and cache) the raw ``{type_lower: entry}`` table from ``dcsUnits.yaml``."""
    raw = yaml.safe_load(read_bundled_text("veaf_libs", "data", "dcsUnits.yaml"))
    units = raw.get("units") if isinstance(raw, dict) else None
    return {
        str(entry["type"]).strip().lower(): entry
        for entry in units or []
        if isinstance(entry, dict) and str(entry.get("type") or "").strip()
    }


def get_unit_shape_name(unit_type: str) -> str | None:
    """Return the `shape_name` the Mission Editor writes on a static of this type.

    DCS resolves many static types without it, not all: a `.Command Center` or an
    `.Ammunition depot` placed without one is refused at mission load (measured 2026-09-28).

    Args:
        unit_type: The DCS type name (e.g. ``".Command Center"``), case-insensitive.

    Returns:
        The shape (``"ComCenter"``), or ``None`` for a type that is not a static with a shape in
        the database — air and ground types included, and third-party mods.
    """
    entry = _entries().get((unit_type or "").strip().lower())
    shape = entry.get("shape_name") if entry else None
    return str(shape) if shape else None


def get_unit_countermeasures(unit_type: str) -> tuple[int, int] | None:
    """Return the ``(chaff, flare)`` load the Mission Editor gives a newly placed aircraft.

    Read from the datamine's ``passivCounterm`` defaults (``F-14B``: 140 / 60, ``UH-1H``: 0 / 60),
    so an aircraft built by the tooling starts with what the editor would have given it.

    Args:
        unit_type: The DCS type name, case-insensitive.

    Returns:
        ``(chaff, flare)``, a missing half read as 0; ``None`` for a type with no dispenser at all
        (a warbird, a tanker) and for a type the database does not know.
    """
    entry = _entries().get((unit_type or "").strip().lower())
    if entry is None or ("chaff" not in entry and "flare" not in entry):
        return None
    return int(entry.get("chaff") or 0), int(entry.get("flare") or 0)


def get_unit_deck_categories(unit_type: str) -> tuple[frozenset[str], frozenset[str]] | None:
    """Return the ship attributes an aircraft can take off from and land on.

    DCS matches these names (``TakeOffRWCategories`` / ``LandRWCategories``) against a ship's own
    attributes: an F-14B takes off from an ``AircraftCarrier With Catapult`` and lands on any
    ``AircraftCarrier``; a Su-33 needs ``With Tramplin`` to take off.

    Args:
        unit_type: The DCS type name, case-insensitive.

    Returns:
        ``(takeoff, landing)``; ``None`` for a type the database does not know. A known type that
        can use no deck gets two empty sets.
    """
    entry = _entries().get((unit_type or "").strip().lower())
    if entry is None:
        return None
    return (
        frozenset(entry.get("takeoff_categories") or []),
        frozenset(entry.get("landing_categories") or []),
    )


def get_unit_attributes(unit_type: str) -> frozenset[str]:
    """Return a unit type's DCS attributes (``AircraftCarrier With Catapult``, ``Fighters``...).

    Args:
        unit_type: The DCS type name, case-insensitive.

    Returns:
        The attributes; empty for a type the database does not know.
    """
    entry = _entries().get((unit_type or "").strip().lower())
    return frozenset(entry.get("attributes") or []) if entry is not None else frozenset()
