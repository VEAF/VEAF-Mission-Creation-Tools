"""Look up DCS airdrome ids by name at design time.

A mission's ``warehouses`` table keys airbases by numeric **airdrome id**
(``airports[<id>]``), but those ids are terrain-specific and not human-friendly.
This module resolves an airfield **name** (as shown in the Mission Editor) to its
id for a given theatre, so build tools (e.g. the Dynamic-Slot warehouse wiring)
can let users name airbases instead of guessing ids.

Backed by ``data/airdromes.yaml`` (generated from a DCS install's terrain
``Beacons.lua`` — see ``veaf-build update-dcs-data --airdromes``). The table is
install-dependent: a theatre absent from the install (or a beacon-less WW2 map
like Normandy) simply has no entries, and the lookup returns ``None``.
"""

from __future__ import annotations

import functools

import yaml

from veaf_libs.bundled_data import read_bundled_text


@functools.lru_cache(maxsize=1)
def _table() -> dict[str, dict[str, int]]:
    """Load (and cache) the ``{theatre_lower: {name_lower: id}}`` table."""
    raw = yaml.safe_load(read_bundled_text("veaf_libs", "data", "airdromes.yaml")) or {}
    table: dict[str, dict[str, int]] = {}
    for theatre, airfields in (raw.get("theatres") or {}).items():
        table[theatre.strip().lower()] = {
            str(name).strip().lower(): int(airfield_id) for name, airfield_id in (airfields or {}).items()
        }
    return table


def airdrome_id_for_name(theatre: str, name: str) -> int | None:
    """Return the DCS airdrome id for an airfield name on a theatre, or ``None``.

    Args:
        theatre: The DCS theatre/map name (e.g. ``"Caucasus"``), case-insensitive.
        name: The airfield display name (e.g. ``"Batumi"``), case-insensitive.

    Returns:
        The numeric airdrome id, or ``None`` if the theatre or name is unknown.
    """
    if not theatre or not name:
        return None
    return _table().get(theatre.strip().lower(), {}).get(name.strip().lower())


def airdromes_for_theatre(theatre: str) -> dict[str, int]:
    """Return the ``{name: id}`` map for a theatre (empty if unknown).

    Args:
        theatre: The DCS theatre/map name (case-insensitive).

    Returns:
        A copy of the airfield name -> id mapping for that theatre.
    """
    if not theatre:
        return {}
    return dict(_table().get(theatre.strip().lower(), {}))
