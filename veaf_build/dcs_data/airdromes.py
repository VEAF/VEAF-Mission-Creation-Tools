"""Generate the airdrome name->id table from a DCS installation.

Unlike the country/units tables (datamine-sourced), the airdrome name<->id
mapping is **terrain-specific** and lives only in the DCS install, in each map's
``Mods/terrains/<Theatre>/Beacons.lua`` — each airfield beacon carries a
``display_name`` and a ``beaconId = 'airfield<ID>_<n>'`` whose ``<ID>`` is the
DCS airdrome id (the same id used as the key in a mission's ``warehouses``
``airports[<id>]`` table). The datamine does **not** carry this data (it only
dumps the global ``_G`` tables), so this generator reads the install directly.

It needs a DCS install path (``--dcs-path``) and is therefore install-dependent:
the committed artifact is **not** CI-guarded (a CI runner has no DCS install).
Parsing is a plain text read — DCS does not need to be running.

Run via ``veaf-build update-dcs-data --airdromes --dcs-path "C:/Program Files/.../DCS World"``.
"""

from __future__ import annotations

import re
from pathlib import Path

import yaml

# Committed artifact consumed at design time to resolve airdrome names to ids.
DEFAULT_OUTPUT = Path(__file__).parent.parent.parent / "src/python/veaf-tools/veaf_libs/data/airdromes.yaml"

_TERRAINS_SUBDIR = "Mods/terrains"
_BEACONS_FILE = "Beacons.lua"

# display_name = _('Batumi');  ... beaconId = 'airfield22_0';
_AIRFIELD_RE = re.compile(r"display_name\s*=\s*_\('([^']+)'\)\s*;\s*beaconId\s*=\s*'airfield(\d+)_")


def parse_beacons(text: str) -> dict[str, int]:
    """Parse one terrain ``Beacons.lua`` into a ``{airfield name: id}`` map.

    Args:
        text: Raw contents of a terrain ``Beacons.lua``.

    Returns:
        Airfield name -> DCS airdrome id (first id wins per name; sorted by name).
    """
    by_name: dict[str, int] = {}
    for name, id_str in _AIRFIELD_RE.findall(text):
        by_name.setdefault(name, int(id_str))
    return dict(sorted(by_name.items()))


def extract_all_airdromes(dcs_path: Path) -> dict[str, dict[str, int]]:
    """Parse every installed terrain's ``Beacons.lua`` under a DCS install.

    Args:
        dcs_path: Root of a DCS World installation.

    Returns:
        Theatre name -> {airfield name -> id}. Terrains whose ``Beacons.lua`` has
        no airfield beacons (e.g. Normandy) map to an empty dict.

    Raises:
        FileNotFoundError: If the ``Mods/terrains`` directory is missing.
    """
    terrains_dir = dcs_path / _TERRAINS_SUBDIR
    if not terrains_dir.is_dir():
        raise FileNotFoundError(f"DCS terrains directory not found: {terrains_dir}")
    result: dict[str, dict[str, int]] = {}
    for terrain_dir in sorted(p for p in terrains_dir.iterdir() if p.is_dir()):
        beacons = terrain_dir / _BEACONS_FILE
        if not beacons.is_file():
            continue
        result[terrain_dir.name] = parse_beacons(beacons.read_text(encoding="utf-8", errors="ignore"))
    return result


def write_airdromes_yaml(theatres: dict[str, dict[str, int]], output: Path) -> None:
    """Write the airdrome table as a committed YAML artifact.

    Args:
        theatres: Theatre -> {name -> id} mapping.
        output: Destination YAML path (parent directories are created).
    """
    output.parent.mkdir(parents=True, exist_ok=True)
    data = {"theatres": {theatre: airfields for theatre, airfields in sorted(theatres.items())}}
    with open(output, "w", encoding="utf-8", newline="\n") as f:
        f.write("# DCS airdrome name -> id table, per theatre.\n")
        f.write("# Generated from a DCS install's Mods/terrains/<Theatre>/Beacons.lua.\n")
        f.write("# Install-dependent (terrain files), so NOT CI-guarded and may grow as\n")
        f.write("# maps are installed. Re-run `veaf-build update-dcs-data --airdromes --dcs-path <DCS>`.\n")
        f.write("# Used at build time to resolve airdrome names in warehouses.yaml.\n\n")
        yaml.dump(data, f, allow_unicode=True, sort_keys=False, default_flow_style=False)


def generate(dcs_path: Path, output: Path | None = None) -> int:
    """Parse a DCS install's terrains and write the airdrome table.

    Args:
        dcs_path: Root of a DCS World installation.
        output: Destination YAML path. Defaults to the committed :data:`DEFAULT_OUTPUT`.

    Returns:
        The total number of airfields written across all theatres.
    """
    if output is None:
        output = DEFAULT_OUTPUT
    theatres = extract_all_airdromes(dcs_path)
    write_airdromes_yaml(theatres, output)
    return sum(len(a) for a in theatres.values())
