"""VEAF radio-channel alias catalog + frequency→alias reverse-lookup.

Used by convert-v5 (FEAT-CONVERTV5-FREQ-ALIASING) to replace hardcoded preset
frequencies with readable aliases. Two alias sources:

- A **maintained generic VEAF catalog** (tactical + flight channels: Guard, Magic,
  Archer… — VEAF conventions, absent from DCS), defined here as data.
- **Per-theatre airfield ATC frequencies** (Gudauta…), loaded from the bundled
  ``airfield-frequencies.yaml`` (FEAT-AIRFIELD-FREQS-DATA).

A ``channels_collection`` entry is ``{alias: {"title": str, "freqs": {band: MHz}}}``,
the same shape used in ``presets.yaml``. The reverse index maps ``(band, MHz)`` to an
alias so a converted frequency can be swapped for its name.
"""

from __future__ import annotations

from typing import Any

import yaml
from veaf_libs.bundled_data import read_bundled_text

_BANDS = ("uhf", "vhf", "fm")

#: Maintained generic VEAF channel aliases (VEAF conventions, not DCS data).
#: Values mirror the shipped default presets.yaml channels_collection.
VEAF_GENERIC_CATALOG: dict[str, dict[str, Any]] = {
    # Tactical / carriers / tankers
    "Guard": {"title": "Guard", "freqs": {"uhf": 243.0, "vhf": 121.5}},
    "Stennis": {"title": "Stennis / 10X", "freqs": {"uhf": 225.0}},
    "Tarawa": {"title": "Tarawa / 11X", "freqs": {"uhf": 226.0}},
    "Roosevelt": {"title": "Roosevelt / 12X", "freqs": {"uhf": 227.0}},
    "Forrestal": {"title": "Forrestal / 13X", "freqs": {"uhf": 228.0}},
    "Magic": {"title": "Magic", "freqs": {"uhf": 282.2}},
    "Package01": {"title": "Package 01", "freqs": {"uhf": 291.0}},
    "Texaco-1": {"title": "Texaco-1/BS/60Y", "freqs": {"uhf": 290.1}},
    "Shell-1": {"title": "Shell-1/BS/62Y", "freqs": {"uhf": 290.3}},
    "Shell-2": {"title": "Shell-2/BM/63Y", "freqs": {"uhf": 290.4}},
    "Arco-1": {"title": "Arco-1/BM/64Y", "freqs": {"uhf": 290.5}},
    "Range-KOBULETI": {"title": "Range KOBULETI", "freqs": {"uhf": 305.1}},
    # Flights (VHF + UHF pairs)
    "Archer": {"title": "Archer", "freqs": {"vhf": 120.0, "uhf": 390.0}},
    "Arctic": {"title": "Arctic", "freqs": {"vhf": 120.1, "uhf": 390.1}},
    "Astro": {"title": "Astro", "freqs": {"vhf": 120.2, "uhf": 390.2}},
    "Nickel": {"title": "Nickel", "freqs": {"vhf": 120.3, "uhf": 390.3}},
    "Nitro": {"title": "Nitro", "freqs": {"vhf": 120.4, "uhf": 390.4}},
    "Ninja": {"title": "Ninja", "freqs": {"vhf": 120.5, "uhf": 390.5}},
    "Pinder": {"title": "Pinder", "freqs": {"vhf": 120.6, "uhf": 390.6}},
    "Bengal": {"title": "Bengal", "freqs": {"vhf": 120.7, "uhf": 390.7}},
    "Blade": {"title": "Blade", "freqs": {"vhf": 120.8, "uhf": 390.8}},
    "Gordon": {"title": "Gordon", "freqs": {"vhf": 120.9, "uhf": 390.9}},
    "Gypsy": {"title": "Gypsy", "freqs": {"vhf": 121.1, "uhf": 391.1}},
    "Gunstar": {"title": "Gunstar", "freqs": {"vhf": 121.2, "uhf": 391.2}},
    "Leica": {"title": "Leica", "freqs": {"vhf": 121.3, "uhf": 391.3}},
    "Lucid": {"title": "Lucid", "freqs": {"vhf": 121.4, "uhf": 391.4}},
    "Lusty": {"title": "Lusty", "freqs": {"vhf": 121.6, "uhf": 391.6}},
    "Lion": {"title": "Lion", "freqs": {"vhf": 121.7, "uhf": 391.7}},
}


def load_airfield_catalog(theatre: str | None) -> dict[str, dict[str, Any]]:
    """Load the airfield alias entries for *theatre* from the bundled data.

    Args:
        theatre: DCS theatre name (e.g. ``"Caucasus"``); ``None`` → no airfields.

    Returns:
        ``{airfield name: {"title", "freqs": {band: MHz}}}`` (empty if the theatre or
        the bundled file is absent).
    """
    if not theatre:
        return {}
    try:
        raw = read_bundled_text("veaf_libs", "data", "airfield-frequencies.yaml")
    except (FileNotFoundError, OSError):
        return {}
    data = yaml.safe_load(raw) or {}
    airfields = (data.get("theatres") or {}).get(theatre) or {}
    return {
        name: {"title": name, "freqs": {b: v for b, v in bands.items() if b in _BANDS}}
        for name, bands in airfields.items()
    }


def build_catalog(theatre: str | None) -> dict[str, dict[str, Any]]:
    """Merge the generic VEAF catalog with *theatre*'s airfields.

    The generic catalog wins on an alias-name clash (VEAF conventions are canonical).
    """
    catalog = dict(load_airfield_catalog(theatre))
    catalog.update(VEAF_GENERIC_CATALOG)
    return catalog


def build_reverse_index(catalog: dict[str, dict[str, Any]]) -> dict[tuple[str, float], str]:
    """Return ``{(band, MHz): alias}`` from a channels-collection-shaped *catalog*.

    Generic VEAF aliases take precedence over airfields on a ``(band, freq)`` clash
    (they are inserted last here so :meth:`dict.setdefault` keeps the first seen —
    airfields first, then generic overrides). Frequencies are rounded to 3 decimals.
    """
    index: dict[tuple[str, float], str] = {}
    # Airfields first, generic last so generic overrides an airfield clash.
    ordered = [(n, e) for n, e in catalog.items() if n not in VEAF_GENERIC_CATALOG]
    ordered += [(n, VEAF_GENERIC_CATALOG[n]) for n in VEAF_GENERIC_CATALOG if n in catalog]
    for alias, entry in ordered:
        for band, freq in (entry.get("freqs") or {}).items():
            index[(band, round(float(freq), 3))] = alias
    return index


def alias_for(reverse_index: dict[tuple[str, float], str], band: str, freq: float) -> str | None:
    """Return the alias for a ``(band, freq)`` pair, or ``None`` if unmatched."""
    return reverse_index.get((band, round(float(freq), 3)))


#: Radio role -> frequency band, used to alias channel_lists entries.
_ROLE_BAND: dict[str, str] = {
    "primary_1": "uhf",
    "primary_2": "vhf",
    "fm_substitute": "fm",
    "fm_supplement": "fm",
    "fm_secondary": "fm",
}


def _alias_channels(
    channels: dict[Any, Any],
    band: str | None,
    index: dict[tuple[str, float], str],
    used: set[str],
) -> dict[Any, Any]:
    """Return *channels* with each matched frequency replaced by its alias name.

    A channel value is a plain frequency or a ``{"freq":, "title":, ...}`` dict.
    On a match the value becomes the alias string (a channels_collection reference);
    otherwise it is left as-is. ``band`` ``None`` disables aliasing (unknown role).
    """
    if not band:
        return channels
    result: dict[Any, Any] = {}
    for ch, val in channels.items():
        freq = val.get("freq") if isinstance(val, dict) else val
        alias = alias_for(index, band, freq) if isinstance(freq, (int, float)) else None
        if alias:
            used.add(alias)
            result[ch] = alias
        else:
            result[ch] = val
    return result


def apply_aliasing(output: dict[str, Any], theatre: str | None) -> dict[str, Any]:
    """Alias hardcoded frequencies in *output* in place and return the channels_collection.

    Walks ``radios_collection`` (band from each radio's ``type``) and ``channel_lists``
    (band from the role) and replaces matched frequencies with alias names. Aliases
    actually used are gathered into a single ``channels_collection`` group, set on
    *output* and returned so the caller can also attach it to the plan file. Returns
    an empty dict when nothing matched (nothing is inserted).

    Args:
        output: The faithful preset dict (mutated in place).
        theatre: DCS theatre name for airfield aliases, or ``None`` for generic only.

    Returns:
        The ``channels_collection`` mapping for the aliases used (``{}`` if none).
    """
    catalog = build_catalog(theatre)
    index = build_reverse_index(catalog)
    used: set[str] = set()

    for coll in (output.get("radios_collection") or {}).values():
        for radio in coll.values():
            radio["channels"] = _alias_channels(radio.get("channels") or {}, radio.get("type"), index, used)

    for roles in (output.get("channel_lists") or {}).values():
        for role in list(roles.keys()):
            roles[role] = _alias_channels(roles[role], _ROLE_BAND.get(role), index, used)

    if not used:
        return {}
    channels_collection = {"aliases": {alias: catalog[alias] for alias in sorted(used)}}
    output["channels_collection"] = channels_collection
    return channels_collection
