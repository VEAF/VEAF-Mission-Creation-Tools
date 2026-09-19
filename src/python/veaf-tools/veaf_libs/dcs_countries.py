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

import yaml

from veaf_libs.bundled_data import read_bundled_text


@functools.lru_cache(maxsize=1)
def _name_to_id() -> dict[str, int]:
    """Build (and cache) the case-insensitive name/alias -> id mapping."""
    raw = yaml.safe_load(read_bundled_text("veaf_libs", "data", "dcs-countries.yaml"))
    mapping: dict[str, int] = {}
    for entry in raw.get("countries", []):
        country_id = int(entry["id"])
        # Canonical name wins over aliases on the rare short-code collision.
        for alias_key in ("name", "international", "short"):
            alias = entry.get(alias_key)
            if alias:
                mapping.setdefault(alias.strip().lower(), country_id)
    return mapping


@functools.lru_cache(maxsize=1)
def all_country_ids() -> frozenset[int]:
    """Return every country id DCS knows about.

    Used when a build tool needs a country the mission does *not* contain — the CTLD/CSAR sound
    declaration plays each sound to an unused country so nobody hears it. The candidate has to come
    from this table: an id DCS does not know makes the Mission Editor crash on load, the same
    failure ``country_id_for_name`` exists to avoid.

    Returns:
        The frozen set of known ``country.id`` values.
    """
    raw = yaml.safe_load(read_bundled_text("veaf_libs", "data", "dcs-countries.yaml"))
    return frozenset(int(entry["id"]) for entry in raw.get("countries", []))


@functools.lru_cache(maxsize=1)
def _id_to_name() -> dict[int, str]:
    """Build (and cache) the id -> canonical name mapping."""
    raw = yaml.safe_load(read_bundled_text("veaf_libs", "data", "dcs-countries.yaml"))
    return {int(entry["id"]): entry["name"] for entry in raw.get("countries", []) if entry.get("name")}


def country_name_for_id(country_id: int) -> str | None:
    """Return the canonical DCS country name for an id, or ``None`` if unknown.

    The inverse of :func:`country_id_for_name`, and it exists for the reader rather than for the
    code: a validator reporting a bare ``[68]`` sends a mission maker looking for a table neither the
    Mission Editor nor the documentation shows them, while ``68 (USSR)`` is actionable on sight.

    Args:
        country_id: A DCS ``country.id``.

    Returns:
        The canonical country name, or ``None`` if DCS has no country with that id (the table has a
        hole at 14, so an unknown id is a real possibility rather than a defensive afterthought).
    """
    return _id_to_name().get(country_id)


def describe_country_id(country_id: int) -> str:
    """Render an id as ``68 (USSR)``, falling back to the bare id when it is unknown.

    Args:
        country_id: A DCS ``country.id``.

    Returns:
        The id followed by the country name in parentheses, or the id alone if it resolves to
        nothing — an unknown id is itself worth showing, since it is a defect in the mission.
    """
    name = country_name_for_id(country_id)
    return f"{country_id} ({name})" if name else str(country_id)


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
