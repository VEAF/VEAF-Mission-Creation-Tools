"""Look up DCS country ids by name at design time.

DCS missions reference a country by name, but the Mission Editor stores (and,
on load, dereferences) a numeric ``country.id``. When a build tool synthesizes
a country that is absent from the source ``.miz`` it must stamp the correct id,
otherwise the Mission Editor crashes on load (``me_mission.lua`` →
``fixCountriesNames`` → ``attempt to index field '?' (a nil value)``).

The lookup is backed by ``data/dcs-countries.yaml``, generated from the
``Quaggles/dcs-lua-datamine`` dump (see ``veaf-build update-dcs-data
--countries``). Names are matched case-insensitively against the canonical
name, the Mission Editor display name and the short code, so callers can pass
any of the spellings a mission may use (e.g. ``France``, ``CJTF Blue``).
"""

from __future__ import annotations

import functools
import importlib.resources
import sys
from pathlib import Path

import yaml


def _read_data_file() -> str:
    """Read the country table, whether running from source or a PyInstaller bundle."""
    bundle_path = Path(getattr(sys, "_MEIPASS", "")) / "veaf_libs" / "data" / "dcs-countries.yaml"
    if bundle_path.exists():
        return bundle_path.read_text(encoding="utf-8")
    pkg = importlib.resources.files("veaf_libs") / "data"
    return (pkg / "dcs-countries.yaml").read_text(encoding="utf-8")


@functools.lru_cache(maxsize=1)
def _name_to_id() -> dict[str, int]:
    """Build (and cache) the case-insensitive name/alias -> id mapping."""
    raw = yaml.safe_load(_read_data_file())
    mapping: dict[str, int] = {}
    for entry in raw.get("countries", []):
        country_id = int(entry["id"])
        # Canonical name wins over aliases on the rare short-code collision.
        for alias_key in ("name", "international", "short"):
            alias = entry.get(alias_key)
            if alias:
                mapping.setdefault(alias.strip().lower(), country_id)
    return mapping


def country_id_for_name(name: str) -> int | None:
    """Return the DCS numeric id for a country name, or ``None`` if unknown.

    Args:
        name: A country name, Mission Editor display name, or short code
            (case-insensitive), e.g. ``"France"``, ``"CJTF Blue"``, ``"FRA"``.

    Returns:
        The DCS ``country.id``, or ``None`` if the name is not in the table.
    """
    if not name:
        return None
    return _name_to_id().get(name.strip().lower())
