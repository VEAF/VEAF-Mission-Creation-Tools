"""Generate the DCS units database (``dcsUnits.yaml``) from the datamine.

This replaces the old in-DCS export (``dcsDataExport.lua``): every unit lives in
the datamine as ``_G/db/Units/<Folder>/<Sub>/<unit>.lua`` carrying a top-level
``type``, ``DisplayName``/``Name``, an optional ``category`` and an ``attribute``
list. We parse those, derive the single ``kind`` the VEAF runtime needs
(``air`` / ``naval`` / ``infantry`` / ``vehicle`` / ``static``) from the DCS
attribute flags, and emit a clean committed YAML — the single source of truth
from which :mod:`veaf_build.dcs_data.units_lua` renders ``dcsUnits.lua``.

Run via ``veaf-build update-dcs-data --units``.
"""

from __future__ import annotations

import re
import tempfile
from dataclasses import dataclass, field
from pathlib import Path

import yaml

from veaf_build.dcs_data.datamine import DATAMINE_REF, clone_datamine

_UNITS_SUBTREE = "_G/db/Units"

# Committed canonical artifact. The Lua runtime file is rendered from this.
DEFAULT_OUTPUT = Path(__file__).parent.parent.parent / "src/python/veaf-tools/veaf_libs/data/dcsUnits.yaml"

# Sanity floor: the DCS units DB is in the hundreds; a much smaller parse means
# the datamine table format changed and the regexes silently matched nothing.
_MIN_EXPECTED_UNITS = 600

# Offshore statics that DCS places on water. The datamine has no reliable flag
# for these (``isPutToWater`` is false even for the offshore wind turbine), so
# this short list is curated here and carried into the YAML. Add to it if DCS
# ships new offshore statics that VEAF must treat as naval.
NAVAL_STATICS: tuple[str, ...] = (
    "offshore WindTurbine",
    "offshore WindTurbine2",
    "Oil platform",
    "Orca",
    "Gas platform",
    "Oil rig",
    "M1 barrage balloon",
)

# Top-level fields are indented with a single tab (nested table fields use more),
# so anchoring on one leading tab avoids matching nested entries.
_TYPE_RE = re.compile(r'^\ttype\s*=\s*"([^"]*)"', re.MULTILINE)
_DISPLAY_NAME_RE = re.compile(r'^\tDisplayName\s*=\s*"([^"]*)"', re.MULTILINE)
_NAME_RE = re.compile(r'^\tName\s*=\s*"([^"]*)"', re.MULTILINE)
_CATEGORY_RE = re.compile(r'^\tcategory\s*=\s*"([^"]*)"', re.MULTILINE)
_ATTRIBUTE_BLOCK_RE = re.compile(r"^\tattribute\s*=\s*\{(.*?)\}", re.MULTILINE | re.DOTALL)
# Maximum internal fuel in kg. Present on every air unit (144 planes + 26 helicopters at the
# pinned ref) and on no ground, naval or static one, so its absence is the honest signal that
# a type carries no fuel load of its own.
_FUEL_MAX_RE = re.compile(r"^\tM_fuel_max\s*=\s*([0-9.]+)", re.MULTILINE)
_QUOTED_RE = re.compile(r'"([^"]+)"')

# Attribute flags that map a unit to its VEAF "kind", in priority order.
_AIR_ATTR = "Air"
_NAVAL_ATTRS = ("Naval", "Ships")
_INFANTRY_ATTR = "Infantry"
# "GroundUnits"/"RailwayUnits" (no space) catch rail stock (locomotives, wagons),
# which the old export classified as vehicles; infantry is matched first above.
_VEHICLE_ATTRS = ("Ground vehicles", "Vehicles", "GroundUnits", "RailwayUnits")

# DCS display category for the folders that carry no top-level ``category`` field.
_FOLDER_CATEGORY = {"Planes": "Plane", "Ships": "Ship", "Helicopters": "Helicopter"}

# Noise attribute dropped from the emitted list (carries no semantic meaning).
_DROP_ATTR = "Redacted"


@dataclass(frozen=True)
class UnitEntry:
    """One DCS unit as consumed by the VEAF runtime."""

    type: str
    """DCS type id, the database key (e.g. ``A-10A``)."""
    name: str
    """Display name (e.g. ``A-10A Warthog``)."""
    kind: str
    """One of ``air`` / ``naval`` / ``infantry`` / ``vehicle`` / ``static``."""
    category: str
    """DCS display category (e.g. ``Plane``, ``Armor``); for the reference doc."""
    description: str
    """Human description (mirrors the display name when DCS has no separate one)."""
    attributes: list[str] = field(default_factory=list)
    """DCS attribute flags (Skynet keys on ``SAM SR`` / ``EWR``)."""
    fuel_capacity: float | int | None = None
    """Maximum internal fuel in kg (air units only); ``None`` when the type carries no fuel."""


# Units present in the old in-DCS export but absent from the datamine (map
# statics). Carried over verbatim so the migration never regresses; revisit if
# the datamine starts shipping them.
CARRIED_UNITS: tuple[UnitEntry, ...] = (
    UnitEntry("Container_20ft", "M92 Container 20ft", "static", "Fortification", "M92 Container 20ft"),
    UnitEntry("Container_40ft", "M92 Container 40ft", "static", "Fortification", "M92 Container 40ft"),
)


def _derive_kind(attributes: list[str]) -> str:
    """Map a unit's DCS attribute flags to its single VEAF ``kind``.

    Priority air → naval → infantry → vehicle → static mirrors the mutually
    exclusive booleans the old export produced (exactly one, or none for statics).

    Args:
        attributes: The unit's DCS attribute flags.

    Returns:
        The kind string.
    """
    attrs = set(attributes)
    if _AIR_ATTR in attrs:
        return "air"
    if attrs.intersection(_NAVAL_ATTRS):
        return "naval"
    if _INFANTRY_ATTR in attrs:
        return "infantry"
    if attrs.intersection(_VEHICLE_ATTRS):
        return "vehicle"
    return "static"


def _parse_fuel_capacity(text: str) -> float | int | None:
    """Read a unit's maximum internal fuel from its datamine file.

    Args:
        text: Raw contents of a ``_G/db/Units/.../<unit>.lua`` file.

    Returns:
        The capacity in kg, as an ``int`` when the value is whole and a ``float`` otherwise — the
        form a mission file uses (``6103``, ``3054.592``) — or ``None`` for a unit carrying no fuel.
    """
    match = _FUEL_MAX_RE.search(text)
    if not match:
        return None
    value = float(match.group(1))
    return int(value) if value.is_integer() else value


def parse_unit_file(text: str, folder: str) -> UnitEntry | None:
    """Parse one datamine unit file into a :class:`UnitEntry`.

    Args:
        text: Raw contents of a ``_G/db/Units/.../<unit>.lua`` file.
        folder: The top-level folder name (e.g. ``Planes``), used to recover the
            display category when the file has no top-level ``category`` field.

    Returns:
        The parsed entry, or ``None`` if the file has no top-level ``type`` (i.e.
        it is not a unit definition).
    """
    type_match = _TYPE_RE.search(text)
    if not type_match:
        return None
    type_id = type_match.group(1)

    display_match = _DISPLAY_NAME_RE.search(text) or _NAME_RE.search(text)
    name = display_match.group(1) if display_match else type_id

    category_match = _CATEGORY_RE.search(text)
    category = category_match.group(1) if category_match else _FOLDER_CATEGORY.get(folder, folder)

    attr_block = _ATTRIBUTE_BLOCK_RE.search(text)
    attributes = [a for a in _QUOTED_RE.findall(attr_block.group(1)) if a != _DROP_ATTR] if attr_block else []

    return UnitEntry(
        type=type_id,
        name=name,
        kind=_derive_kind(attributes),
        category=category,
        description=name,
        attributes=attributes,
        fuel_capacity=_parse_fuel_capacity(text),
    )


def extract_all_units(clone_root: Path) -> list[UnitEntry]:
    """Parse every unit file under the datamine clone.

    Args:
        clone_root: Root of a datamine checkout containing ``_G/db/Units``.

    Returns:
        Parsed entries, de-duplicated by type, sorted by type.

    Raises:
        FileNotFoundError: If the ``Units`` subtree is missing from the clone.
    """
    units_dir = clone_root / _UNITS_SUBTREE
    if not units_dir.is_dir():
        raise FileNotFoundError(f"Units subtree not found in clone: {units_dir}")
    by_type: dict[str, UnitEntry] = {}
    for lua_file in sorted(units_dir.rglob("*.lua")):
        folder = lua_file.relative_to(units_dir).parts[0]
        entry = parse_unit_file(lua_file.read_text(encoding="utf-8", errors="ignore"), folder)
        if entry is not None and entry.type not in by_type:
            by_type[entry.type] = entry
    # Carry over units the datamine lacks (without overriding a datamine entry).
    for carried in CARRIED_UNITS:
        by_type.setdefault(carried.type, carried)
    return sorted(by_type.values(), key=lambda e: e.type.lower())


def write_units_yaml(
    entries: list[UnitEntry],
    naval_statics: tuple[str, ...],
    output: Path,
    ref: str = DATAMINE_REF,
) -> None:
    """Write the units database as a committed YAML artifact.

    Args:
        entries: Unit entries to serialize.
        naval_statics: Offshore static type ids to treat as naval.
        output: Destination YAML path (parent directories are created).
        ref: Upstream datamine ref, stamped into the header for provenance.
    """
    output.parent.mkdir(parents=True, exist_ok=True)
    data = {
        "units": [
            {
                "type": e.type,
                "name": e.name,
                "kind": e.kind,
                "category": e.category,
                "description": e.description,
                "attributes": e.attributes,
                # Emitted only where DCS has one, so the artifact does not carry a thousand nulls.
                **({"fuel_capacity": e.fuel_capacity} if e.fuel_capacity is not None else {}),
            }
            for e in entries
        ],
        "naval_statics": sorted(naval_statics),
    }
    with open(output, "w", encoding="utf-8", newline="\n") as f:
        f.write("# DCS units database (type, kind, category, attributes, fuel capacity).\n")
        f.write("# Generated from https://github.com/Quaggles/dcs-lua-datamine\n")
        f.write(f"# Source ref: {ref}\n")
        f.write("# Canonical source for src/scripts/veaf/dcsUnits.lua (rendered by veaf-build).\n")
        f.write("# Re-run `veaf-build update-dcs-data --units` to regenerate after a pin bump.\n")
        f.write("# DO NOT EDIT BY HAND — CI fails if this file drifts from the generator output.\n\n")
        yaml.dump(data, f, allow_unicode=True, sort_keys=False, default_flow_style=False)


def generate(output: Path | None = None, ref: str = DATAMINE_REF) -> int:
    """Clone the datamine at *ref*, extract units, and write the YAML database.

    Args:
        output: Destination YAML path. Defaults to the committed :data:`DEFAULT_OUTPUT`.
        ref: Upstream datamine ref. Defaults to the pinned :data:`DATAMINE_REF`.

    Returns:
        The number of units written.

    Raises:
        RuntimeError: If far fewer units than expected were parsed.
    """
    if output is None:
        output = DEFAULT_OUTPUT
    with tempfile.TemporaryDirectory() as tmp:
        clone_root = Path(tmp) / "dcs-lua-datamine"
        clone_datamine(clone_root, [_UNITS_SUBTREE], ref)
        entries = extract_all_units(clone_root)
    if len(entries) < _MIN_EXPECTED_UNITS:
        raise RuntimeError(
            f"Parsed only {len(entries)} units (< {_MIN_EXPECTED_UNITS}) at ref {ref} — "
            "the datamine unit-file format may have changed; update the parser."
        )
    write_units_yaml(entries, NAVAL_STATICS, output, ref)
    return len(entries)
