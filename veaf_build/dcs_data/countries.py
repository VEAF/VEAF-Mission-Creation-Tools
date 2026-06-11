"""Generate the DCS country name-to-id table from the datamine.

Each ``_G/db/Countries/<name>.lua`` file in the datamine carries the country's
identity at the top level: ``Name``, ``WorldID`` (the numeric DCS country id),
``ShortName`` and ``InternationalName``. We extract those four fields per
country and emit a committed YAML table consumed at design time by
:func:`veaf_libs.dcs_countries.country_id_for_name` (used by the aircraft
injector to stamp a valid ``country.id`` and avoid the DCS Mission Editor
``fixCountriesNames`` nil-index crash).

Run via ``veaf-build update-dcs-data --countries``.
"""

from __future__ import annotations

import re
import tempfile
from dataclasses import dataclass
from pathlib import Path

import yaml

from veaf_build.dcs_data.datamine import DATAMINE_REF, clone_datamine

_COUNTRIES_SUBTREE = "_G/db/Countries"

# Top-level fields are indented with a single tab; nested fields (Units, Awards,
# ...) use two or more, so anchoring on a single leading tab is unambiguous.
_NAME_RE = re.compile(r'^\tName\s*=\s*"([^"]*)"', re.MULTILINE)
_WORLD_ID_RE = re.compile(r"^\tWorldID\s*=\s*(\d+)", re.MULTILINE)
_SHORT_NAME_RE = re.compile(r'^\tShortName\s*=\s*"([^"]*)"', re.MULTILINE)
_INTERNATIONAL_NAME_RE = re.compile(r'^\tInternationalName\s*=\s*"([^"]*)"', re.MULTILINE)


@dataclass(frozen=True)
class CountryEntry:
    """Identity of a single DCS country."""

    id: int
    """DCS numeric country id (``WorldID``)."""
    name: str
    """Canonical English name as stored in mission files (e.g. ``France``)."""
    short_name: str
    """Short code (e.g. ``FRA``)."""
    international_name: str
    """Display name used by the Mission Editor (e.g. ``CJTF Blue``)."""


def parse_country_file(text: str) -> CountryEntry | None:
    """Parse one datamine country file into a :class:`CountryEntry`.

    Args:
        text: Raw contents of a ``_G/db/Countries/<name>.lua`` file.

    Returns:
        The parsed entry, or ``None`` if the file lacks a top-level ``Name`` or
        ``WorldID`` (i.e. it is not a country identity file).
    """
    name_match = _NAME_RE.search(text)
    world_id_match = _WORLD_ID_RE.search(text)
    if not name_match or not world_id_match:
        return None
    short_match = _SHORT_NAME_RE.search(text)
    international_match = _INTERNATIONAL_NAME_RE.search(text)
    return CountryEntry(
        id=int(world_id_match.group(1)),
        name=name_match.group(1),
        short_name=short_match.group(1) if short_match else "",
        international_name=international_match.group(1) if international_match else "",
    )


def extract_all_countries(clone_root: Path) -> list[CountryEntry]:
    """Parse every country file under the datamine clone.

    Args:
        clone_root: Root of a datamine checkout containing ``_G/db/Countries``.

    Returns:
        Parsed entries sorted by country id.

    Raises:
        FileNotFoundError: If the ``Countries`` subtree is missing from the clone.
    """
    countries_dir = clone_root / _COUNTRIES_SUBTREE
    if not countries_dir.is_dir():
        raise FileNotFoundError(f"Countries subtree not found in clone: {countries_dir}")
    entries: list[CountryEntry] = []
    for lua_file in sorted(countries_dir.glob("*.lua")):
        entry = parse_country_file(lua_file.read_text(encoding="utf-8", errors="ignore"))
        if entry is not None:
            entries.append(entry)
    return sorted(entries, key=lambda e: e.id)


def write_countries_yaml(entries: list[CountryEntry], output: Path, ref: str = DATAMINE_REF) -> None:
    """Write the country table as a committed YAML artifact.

    Args:
        entries: Country entries to serialize.
        output: Destination YAML path (parent directories are created).
        ref: Upstream datamine ref the data was generated from, stamped into the
            header for provenance.
    """
    output.parent.mkdir(parents=True, exist_ok=True)
    data = {
        "countries": [
            {
                "id": e.id,
                "name": e.name,
                "short": e.short_name,
                "international": e.international_name,
            }
            for e in entries
        ]
    }
    with open(output, "w", encoding="utf-8") as f:
        f.write("# DCS country name -> id table.\n")
        f.write("# Generated from https://github.com/Quaggles/dcs-lua-datamine\n")
        f.write(f"# Source ref: {ref}\n")
        f.write("# Re-run `veaf-build update-dcs-data --countries` to regenerate after a pin bump.\n")
        f.write("# DO NOT EDIT BY HAND — CI fails if this file drifts from the generator output.\n\n")
        yaml.dump(data, f, allow_unicode=True, sort_keys=False, default_flow_style=False)


def generate(output: Path, ref: str = DATAMINE_REF) -> int:
    """Clone the datamine at *ref*, extract countries, and write the YAML table.

    Args:
        output: Destination YAML path for the country table.
        ref: Upstream datamine ref to generate from. Defaults to the pinned
            :data:`DATAMINE_REF`.

    Returns:
        The number of countries written.
    """
    with tempfile.TemporaryDirectory() as tmp:
        clone_root = Path(tmp) / "dcs-lua-datamine"
        clone_datamine(clone_root, [_COUNTRIES_SUBTREE], ref)
        entries = extract_all_countries(clone_root)
    write_countries_yaml(entries, output, ref)
    return len(entries)
