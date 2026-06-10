"""Automatic mission-era detection (ERA-AUTODETECT).

Infers the VEAF era (``WW2`` / ``COLD_WAR`` / ``MODERN``) from a parsed ``.miz``
mission, using a **combined heuristic**: the DCS mission year *and* the presence
of WW2-era unit/aircraft types.

Priority rule (a manual ``mission.yaml`` ``era`` always wins — that is enforced
by the caller, not here):

1. **WW2** when any WW2-era unit/aircraft type is present, **or** the mission
   year is 1945 or earlier (the unit signal is the strongest indicator and wins
   even if the year was left at a modern default).
2. Otherwise, year-based: **COLD_WAR** up to 1991, **MODERN** from 1992 on.
3. When neither a year nor WW2 units are available, default to **MODERN**.
"""

from __future__ import annotations

from collections.abc import Iterator

#: Era identifiers — must match ``veaf.ERA`` in ``veaf.lua``.
ERA_WW2 = "WW2"
ERA_COLD_WAR = "COLD_WAR"
ERA_MODERN = "MODERN"

#: Inclusive upper year bounds for each era.
_WW2_MAX_YEAR = 1945
_COLD_WAR_MAX_YEAR = 1991

#: WW2-era DCS unit/aircraft type ids (reference table — maintained here).
#: Aircraft are the strongest signal; iconic ground units and flak are included.
WW2_UNIT_TYPES: frozenset[str] = frozenset(
    {
        # ── Aircraft ──
        "SpitfireLFMkIX",
        "SpitfireLFMkIXCW",
        "P-51D",
        "P-51D-30-NA",
        "TF-51D",
        "P-47D-30",
        "P-47D-30bl1",
        "P-47D-40",
        "Bf-109K-4",
        "FW-190D9",
        "FW-190A8",
        "MosquitoFBMkVI",
        "A-20G",
        "B-17G",
        "Ju-88A4",
        "I-16",
        # ── Tanks / armour ──
        "Tiger_I",
        "Tiger_II",
        "Pz_IV_H",
        "Stug_III",
        "Stug_IV",
        "SturmpanzerIV",
        "Sd_Kfz_251",
        "Sd_Kfz_184",
        "Elefant_SdKfz_184",
        "M4_Sherman",
        "M2A1_halftrack",
        "M8_Greyhound",
        "M30_CC",
        "Churchill_VII",
        "Cromwell_IV",
        "Daimler_AC",
        # ── Trucks / cars ──
        "Sd_Kfz_2",
        "Sd_Kfz_7",
        "Kubelwagen_82",
        "Horch_901_typ_40_kfz_21",
        "Blitz_36-6700A",
        "Bedford_MWD",
        "CCKW_353",
        # ── AAA / flak ──
        "Flak18",
        "Flak30",
        "Flak36",
        "Flak37",
        "Flak38",
        "Flak41",
        "KDO_Mod40",
        "Maschinensatz_33",
        "Bofors40",
    }
)


def _iter_unit_types(mission_content: dict) -> Iterator[str]:
    """Yield every unit ``type`` string found in the mission.

    Tolerates both list- and dict-shaped DCS tables (``country``/``group``/
    ``units`` are usually 1-based and decode to lists).

    Args:
        mission_content: The parsed ``mission`` table from the ``.miz``.

    Yields:
        Each unit's ``type`` id.
    """

    def _values(node: object) -> Iterator:
        if isinstance(node, dict):
            yield from node.values()
        elif isinstance(node, list):
            yield from node

    coalition = mission_content.get("coalition")
    if not isinstance(coalition, dict):
        return
    for side in coalition.values():
        if not isinstance(side, dict):
            continue
        for country in _values(side.get("country")):
            if not isinstance(country, dict):
                continue
            for category in ("plane", "helicopter", "vehicle", "ship", "static"):
                cat = country.get(category)
                if not isinstance(cat, dict):
                    continue
                for group in _values(cat.get("group")):
                    if not isinstance(group, dict):
                        continue
                    for unit in _values(group.get("units")):
                        if isinstance(unit, dict) and (unit_type := unit.get("type")):
                            yield unit_type


def detect_era(mission_content: dict) -> str:
    """Infer the mission era from its content (see module docstring for the rule).

    Args:
        mission_content: The parsed ``mission`` table from the ``.miz``.

    Returns:
        One of ``"WW2"``, ``"COLD_WAR"`` or ``"MODERN"``.
    """
    has_ww2_units = any(unit_type in WW2_UNIT_TYPES for unit_type in _iter_unit_types(mission_content))

    year = None
    date = mission_content.get("date")
    if isinstance(date, dict) and isinstance(date.get("Year"), int):
        year = date["Year"]

    if has_ww2_units or (year is not None and year <= _WW2_MAX_YEAR):
        return ERA_WW2
    if year is not None:
        return ERA_COLD_WAR if year <= _COLD_WAR_MAX_YEAR else ERA_MODERN
    return ERA_MODERN
