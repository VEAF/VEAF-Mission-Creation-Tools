"""Look up an airfield's parking stands at design time.

Backed by the slimmed, bundled ``data/parking/<Theatre>.json`` files the dev tool
``veaf-build update-dcs-data --parking`` generates from runtime captures (see
``veaf_build/dcs_data/parking.py``). Each stand carries what placing an aircraft on a ramp needs: the
stand number (``parking``, the runtime ``Term_Index``), its mission position and altitude, its terminal
type, and its distance to the runway.

Two facts, both measured in game on 2026-08-15, are baked into how callers use this:

- A unit is placed at the stand's exact ``x``/``y``/``alt`` with ``parking`` = the stand number.
- ``parking_id`` is not stored and is not load-bearing: a caller sets it equal to ``parking``.

A theatre not captured yet simply has no file, and the lookups return empty.
"""

from __future__ import annotations

import functools
import json
from dataclasses import dataclass

from veaf_libs.bundled_data import read_bundled_text


@dataclass(frozen=True)
class ParkingStand:
    """One parking stand at an airfield, in mission coordinates."""

    parking: str
    x: float
    y: float
    alt: float
    term_type: str
    dist_to_runway: float


@functools.lru_cache(maxsize=8)
def _theatre_table(theatre_key: str) -> dict[str, list[ParkingStand]]:
    """Load (and cache) ``{airbase_id: [ParkingStand, ...]}`` for a theatre, or empty if uncaptured."""
    try:
        raw = json.loads(read_bundled_text("veaf_libs", "data", "parking", f"{theatre_key}.json"))
    except (FileNotFoundError, OSError):
        return {}
    table: dict[str, list[ParkingStand]] = {}
    for airbase_id, stands in (raw.get("by_airbase") or {}).items():
        table[str(airbase_id)] = [
            ParkingStand(
                parking=str(s["p"]),
                x=float(s["x"]),
                y=float(s["y"]),
                alt=float(s["alt"]),
                term_type=str(s["t"]),
                dist_to_runway=float(s["d"]),
            )
            for s in stands
        ]
    return table


def _resolve_theatre_file(theatre: str) -> str | None:
    """Return the bundled file stem matching ``theatre`` (case-insensitive), or None if none ships."""
    import contextlib

    from veaf_libs.bundled_data import bundled_dir

    with contextlib.suppress(FileNotFoundError, OSError):
        for path in bundled_dir("veaf_libs", "data", "parking").glob("*.json"):
            if path.stem.lower() == theatre.strip().lower():
                return path.stem
    return None


def has_theatre(theatre: str) -> bool:
    """Return whether parking data ships for ``theatre`` (case-insensitive)."""
    return bool(theatre) and _resolve_theatre_file(theatre) is not None


def stands_for_airbase(theatre: str, airbase_id: int | str) -> list[ParkingStand]:
    """Return every parking stand at an airbase, nearest-to-runway first.

    Args:
        theatre: The DCS theatre/map name (case-insensitive).
        airbase_id: The DCS numeric airdrome id.

    Returns:
        The stands, sorted by ascending distance to the runway (empty if the theatre or airbase is
        not in the bundled data).
    """
    stem = _resolve_theatre_file(theatre) if theatre else None
    if stem is None:
        return []
    stands = _theatre_table(stem).get(str(airbase_id), [])
    return sorted(stands, key=lambda s: s.dist_to_runway)
