"""Generate the airdrome name->id table from the DCS reference data and runtime airbase dumps.

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
read, and writes the positions beside it in ``airdrome-positions.yaml`` for the MCP
``list_airfields`` action — the dumps themselves are not shipped with the tools.

Since FEAT-DCS-REFERENCE-DATA, the ``dcs-world-schema`` reference database (see
:mod:`veaf_build.dcs_data.reference`) is the first source: it carries the same names and ids as
the dumps for every theatre it knows (798 of 798 identical, measured 2026-10-08), read offline.
Its position is the terrain's reference point, which sits on the runways' centre (median 0 m on
13 theatres), where ``Airbase:getPoint()`` — what the dumps hold — lands about a kilometre away.
A dump is used only for a theatre the reference lacks (TheChannel at ``v0.5.0``).

``generate`` **merges** those sources into ``airdromes.yaml``: a theatre found in the
reference or a dump is fully replaced from it, a theatre in neither is left untouched.
Both sources are pinned or committed, so the artifacts are CI-guarded. Run via
``veaf-build update-dcs-data --airdromes``.
"""

from __future__ import annotations

import json
import sqlite3
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


def positions(airbases: list[dict[str, Any]]) -> list[dict[str, Any]]:
    """Project a dump's airbase records to ``[{name, id, lat, lon}]``, sorted by name.

    Args:
        airbases: Records with ``name``, ``id``, ``lat`` and ``lon`` keys; one missing any is left out.

    Returns:
        The airbases that carry a position (first record wins on a duplicate name).
    """
    by_name: dict[str, dict[str, Any]] = {}
    for ab in airbases:
        name = str(ab.get("name", "")).strip()
        if name and "id" in ab and ab.get("lat") is not None and ab.get("lon") is not None:
            by_name.setdefault(name, {"name": name, "id": int(ab["id"]), "lat": ab["lat"], "lon": ab["lon"]})
    return [by_name[name] for name in sorted(by_name)]


def reference_airbases(connection: sqlite3.Connection) -> dict[str, list[dict[str, Any]]]:
    """Read every airbase of the reference database, in the shape of a dump's records.

    Args:
        connection: An open reference database (see :func:`veaf_build.dcs_data.reference.open_reference`).

    Returns:
        Theatre -> ``[{id, name, lat, lon}]``, the position being the airbase's reference point
        rounded to six decimals like the dumps.
    """
    result: dict[str, list[dict[str, Any]]] = {}
    query = "select theatre, airdromeId, name, referencePoint from airbases order by theatre, name"
    for theatre, airdrome_id, name, reference_point in connection.execute(query):
        point = json.loads(reference_point) if reference_point else {}
        record: dict[str, Any] = {"id": int(airdrome_id), "name": str(name)}
        if point.get("latitude") is not None and point.get("longitude") is not None:
            record["lat"] = round(float(point["latitude"]), 6)
            record["lon"] = round(float(point["longitude"]), 6)
        result.setdefault(str(theatre), []).append(record)
    return result


def _load_dump_records(dumps_dir: Path) -> dict[str, list[dict[str, Any]]]:
    """Return each committed dump's airbase records, keyed by theatre."""
    result: dict[str, list[dict[str, Any]]] = {}
    if not dumps_dir.is_dir():
        return result
    for dump in sorted(dumps_dir.glob("*.json")):
        doc = json.loads(dump.read_text(encoding="utf-8"))
        result[str(doc.get("theatre") or dump.stem)] = list(doc.get("airbases") or [])
    return result


def write_positions_yaml(theatres: dict[str, list[dict[str, Any]]], output: Path) -> None:
    """Write the airbase positions as a committed YAML artifact.

    Args:
        theatres: Theatre -> positioned airbases.
        output: Destination YAML path (parent directories are created).
    """
    output.parent.mkdir(parents=True, exist_ok=True)
    data = {"theatres": dict(sorted(theatres.items()))}
    with open(output, "w", encoding="utf-8", newline="\n") as f:
        f.write("# DCS airbase positions (lat/lon of the reference point, the runways' centre), per theatre.\n")
        f.write("# Generated with airdromes.yaml from the dcs-world-schema reference data, and from\n")
        f.write("# veaf_build/dcs_data/airbase_dumps/<Theatre>.json for a theatre it lacks.\n")
        f.write("# DO NOT EDIT BY HAND — CI fails if it drifts. Re-run `veaf-build update-dcs-data --airdromes`.\n")
        f.write("# Read by the MCP list_airfields action.\n\n")
        yaml.dump(data, f, allow_unicode=True, sort_keys=False, default_flow_style=False)


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
        f.write("# Generated from the dcs-world-schema reference data, and from the runtime airbase dumps\n")
        f.write("# (veaf_build/dcs_data/airbase_dumps/<Theatre>.json) for a theatre it lacks.\n")
        f.write("# Names are exact Airbase:getName() values (what airport_link / Airbase.getByName expects).\n")
        f.write("# DO NOT EDIT BY HAND — CI fails if it drifts. Re-run `veaf-build update-dcs-data --airdromes`.\n")
        f.write(
            "# Used at build time to resolve airdrome names in warehouses.yaml and to validate QRA airport_link.\n\n"
        )
        yaml.dump(data, f, allow_unicode=True, sort_keys=False, default_flow_style=False)


def generate(
    dumps_dir: Path = DUMPS_DIR,
    output: Path | None = None,
    reference: dict[str, list[dict[str, Any]]] | None = None,
) -> int:
    """Merge the reference airbases and the committed runtime dumps into the airdrome table.

    A theatre found in *reference* is fully (re)generated from it; otherwise a theatre that has
    a dump is generated from the dump; a theatre in neither is preserved as already committed in
    *output*. A legacy folder-named duplicate (see :data:`LEGACY_THEATRE_ALIASES`) is dropped
    once its canonical theatre has a source. The positions are written beside *output*, as
    ``airdrome-positions.yaml``, from the same sources: a theatre in neither has no position.

    Args:
        dumps_dir: Directory holding the per-theatre ``.json`` dumps.
        output: Destination YAML path. Defaults to the committed :data:`DEFAULT_OUTPUT`.
        reference: Theatre -> airbase records read by :func:`reference_airbases`; ``None`` uses
            the dumps alone.

    Returns:
        The total number of airfields written across all theatres.
    """
    if output is None:
        output = DEFAULT_OUTPUT
    sources = {**_load_dump_records(dumps_dir), **(reference or {})}
    merged = _load_existing_theatres(output)
    merged.update({theatre: names_to_ids(records) for theatre, records in sources.items()})
    for legacy, canonical in LEGACY_THEATRE_ALIASES.items():
        if canonical in sources:
            merged.pop(legacy, None)
    write_airdromes_yaml(merged, output)
    write_positions_yaml(
        {theatre: positions(records) for theatre, records in sources.items()},
        output.with_name("airdrome-positions.yaml"),
    )
    return sum(len(a) for a in merged.values())
