"""Generate the airdrome name->id table from DCS runtime airbase dumps.

The airdrome name<->id mapping is **terrain-specific** and, crucially, the only
authoritative source for the *exact* name a mission uses (the value ``airport_link``
or ``Airbase.getByName`` expects) is the DCS runtime itself: ``Airbase:getName()``.
Terrain files (``Beacons.lua``/``Radio.lua``) carry beacon/ATC callsigns that differ
from the real airbase name (e.g. ``Abu_Ad_Duhur`` vs ``Abu al-Duhur``), so this
generator is fed by **runtime dumps** instead.

Each dump is a committed ``airbase_dumps/<Theatre>.json`` file — the richer artifact
captured with ``veaf-tools capture-map`` (``{id, name, lat, lon, coalition}`` per
airbase, real airfields and terrain helipads alike). This generator only consumes the
``name -> id`` projection to (re)build the flat ``airdromes.yaml`` the build/validation
read; the JSON keeps the geo data for other uses.

``generate`` **merges** the available dumps into ``airdromes.yaml``: a theatre with a
dump is fully replaced from it, a theatre without one is left untouched (theatres are
migrated to runtime dumps lot-by-lot). Runtime-dependent, so the committed artifact is
**not** CI-guarded. Run via ``veaf-build update-dcs-data --airdromes``.
"""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

import yaml

# Committed artifact consumed at design time to resolve airdrome names to ids.
DEFAULT_OUTPUT = Path(__file__).parent.parent.parent / "src/python/veaf-tools/veaf_libs/data/airdromes.yaml"

# Committed runtime dumps, one <Theatre>.json per captured theatre.
DUMPS_DIR = Path(__file__).parent / "airbase_dumps"

#: Legacy theatre keys left over from the retired ``Beacons.lua`` scraper, which named
#: theatres after the **terrain folder** instead of the DCS ``mission.theatre`` string.
#: They hold beacon labels (not airbase names) and are superseded once the canonical
#: theatre is captured, so they are dropped to avoid a stale duplicate.
#: Mirrors ``veaf_libs.blank_mission._THEATRE_ALIASES`` (alias -> canonical).
LEGACY_THEATRE_ALIASES: dict[str, str] = {"Sinai": "SinaiMap", "GermanyColdWar": "GermanyCW"}


def names_to_ids(airbases: list[dict[str, Any]]) -> dict[str, int]:
    """Project a dump's airbase records to a sorted ``{name: id}`` map.

    Args:
        airbases: Records with at least ``name`` and ``id`` keys.

    Returns:
        Airbase name -> id (sorted by name; first id wins on a duplicate name).
    """
    by_name: dict[str, int] = {}
    for ab in airbases:
        name = str(ab.get("name", "")).strip()
        if name and "id" in ab:
            by_name.setdefault(name, int(ab["id"]))
    return dict(sorted(by_name.items()))


def load_dumps(dumps_dir: Path = DUMPS_DIR) -> dict[str, dict[str, int]]:
    """Parse every committed ``<Theatre>.json`` dump into ``{theatre: {name: id}}``.

    Args:
        dumps_dir: Directory holding the per-theatre ``.json`` dumps.

    Returns:
        Theatre name -> {airbase name -> id}.
    """
    result: dict[str, dict[str, int]] = {}
    if not dumps_dir.is_dir():
        return result
    for dump in sorted(dumps_dir.glob("*.json")):
        doc = json.loads(dump.read_text(encoding="utf-8"))
        theatre = str(doc.get("theatre") or dump.stem)
        result[theatre] = names_to_ids(doc.get("airbases") or [])
    return result


def _load_existing_theatres(output: Path) -> dict[str, dict[str, int]]:
    """Return the ``theatres`` table already committed in *output* (empty if absent)."""
    if not output.is_file():
        return {}
    data = yaml.safe_load(output.read_text(encoding="utf-8")) or {}
    theatres = data.get("theatres") or {}
    return {str(t): dict(a or {}) for t, a in theatres.items()}


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
        f.write("# Generated from runtime airbase dumps — see veaf_build/dcs_data/airbase_dumps/<Theatre>.json.\n")
        f.write("# Names are exact Airbase:getName() values (what airport_link / Airbase.getByName expects).\n")
        f.write("# Runtime-dependent, so NOT CI-guarded. Re-run `veaf-build update-dcs-data --airdromes`.\n")
        f.write(
            "# Used at build time to resolve airdrome names in warehouses.yaml and to validate QRA airport_link.\n\n"
        )
        yaml.dump(data, f, allow_unicode=True, sort_keys=False, default_flow_style=False)


def generate(dumps_dir: Path = DUMPS_DIR, output: Path | None = None) -> int:
    """Merge the committed runtime dumps into the airdrome table.

    A theatre that has a dump is fully (re)generated from it; a theatre without a
    dump is preserved as already committed in *output* (progressive migration).
    A legacy folder-named duplicate (see :data:`LEGACY_THEATRE_ALIASES`) is dropped
    once its canonical theatre has been captured.

    Args:
        dumps_dir: Directory holding the per-theatre ``.json`` dumps.
        output: Destination YAML path. Defaults to the committed :data:`DEFAULT_OUTPUT`.

    Returns:
        The total number of airfields written across all theatres.
    """
    if output is None:
        output = DEFAULT_OUTPUT
    merged = _load_existing_theatres(output)
    dumped = load_dumps(dumps_dir)
    merged.update(dumped)
    for legacy, canonical in LEGACY_THEATRE_ALIASES.items():
        if canonical in dumped:
            merged.pop(legacy, None)
    write_airdromes_yaml(merged, output)
    return sum(len(a) for a in merged.values())
