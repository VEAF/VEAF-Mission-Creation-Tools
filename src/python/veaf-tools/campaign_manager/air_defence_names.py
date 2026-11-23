"""An air defence as a pilot names it, for the briefings (David, 2026-11-17).

The theatre dossier listed our defences by their template aliases — "hawk, generateAirDefenseGroup-BLUE-3,
avenger_squad, stinger_squad" — words of the mission maker's tools, not of a briefing. Here a named system is its
name and its reach ("Hawk (SAM moyenne portée)"), and a generated defence its level and what it holds, read from
`veaf-units.yaml` ("défense rapprochée de niveau 3 sur 5 (Gepard, Linebacker, Avenger)"). The runtime rolls a
generated defence one level up or down, so the level is the one asked for.
"""

from __future__ import annotations

import functools
import re

import yaml
from veaf_libs.bundled_data import read_bundled_text
from veaf_libs.i18n import t

#: A named system's group aliases: its name and its reach (`short`, `medium`, `long`, `manpads`).
_SYSTEMS: dict[str, tuple[str, str]] = {
    "hawk": ("Hawk", "medium"),
    "patriot": ("Patriot", "long"),
    "nasams": ("NASAMS", "medium"),
    "nasams_c": ("NASAMS", "medium"),
    "roland": ("Roland", "short"),
    "avenger_squad": ("Avenger", "short"),
    "stinger_squad": ("Stinger", "manpads"),
    "sa2": ("SA-2", "long"),
    "sa3": ("SA-3", "medium"),
    "sa5": ("SA-5", "long"),
    "sa6": ("SA-6", "medium"),
    "sa10": ("SA-10", "long"),
    "sa11": ("SA-11", "medium"),
    "sa15": ("SA-15", "short"),
    "sa19": ("SA-19", "short"),
    "sa15m2_squad": ("SA-15 Tor M2", "short"),
    "sa22_squad": ("SA-22 Pantsir", "short"),
    # FEAT-CAMPAIGN-AIR-DEFENCE-VARIETY 03; `iris-t` is looked up without its hyphen
    "iristslm": ("IRIS-T SLM", "medium"),
    "irist": ("IRIS-T SLM", "medium"),
    "rapier_radar": ("Rapier", "short"),
    "rapier_optical": ("Rapier", "short"),
}

#: The air-defence vehicles a generated defence holds, by DCS type, as pilots call them; trucks, radars and
#: command posts are left out.
_VEHICLES: dict[str, str] = {
    "Gepard": "Gepard",
    "M6 Linebacker": "Linebacker",
    "M1097 Avenger": "Avenger",
    "Vulcan": "Vulcan",
    "M48 Chaparral": "Chaparral",
    "Roland ADS": "Roland",
    "Hawk ln": "Hawk",
    "AAV7": "AAV7",
    "2S6 Tunguska": "SA-19 Tunguska",
    "Tor 9A331": "SA-15",
    "CHAP_TorM2": "SA-15 Tor M2",
    "CHAP_PantsirS1": "SA-22 Pantsir",
    "Osa 9A33 ln": "SA-8",
    "Strela-10M3": "SA-13",
    "Strela-1 9P31": "SA-9",
    "ZSU-23-4 Shilka": "Shilka",
    "ZSU_57_2": "ZSU-57",
    "S-60_Type59_Artillery": "S-60",
    "Ural-375 ZU-23": "ZU-23",
}

_GENERATED = re.compile(r"generateAirDefenseGroup-(?:BLUE|RED)(?:-[A-Z0-9_]+)?-(\d)$")


@functools.lru_cache(maxsize=1)
def _units_by_alias() -> dict[str, tuple[str, ...]]:
    """Every group alias of `veaf-units.yaml` with the DCS types of its units, in order."""
    raw = yaml.safe_load(read_bundled_text("veaf_libs", "data", "veaf-units.yaml")) or {}
    found: dict[str, tuple[str, ...]] = {}
    for group in raw.get("groups") or []:
        types = tuple(str(unit.get("type")) for unit in group.get("units") or [])
        for alias in group.get("aliases") or []:
            found[str(alias)] = types
    return found


def _holds(entry: str) -> list[str]:
    """The air-defence vehicles of a group, each once, in the order they come."""
    names: list[str] = []
    for unit_type in _units_by_alias().get(entry, ()):
        name = _VEHICLES.get(unit_type)
        if name and name not in names:
            names.append(name)
    return names


def describe_garrison_entry(entry: str) -> str:
    """Say what a garrison entry of `campaign.yaml` is, in the current language.

    Args:
        entry: The entry as written: a group alias of `veaf-units.yaml` or a generated defence.

    Returns:
        A named system with its reach, a generated defence with its level and what it holds, or the entry as
        written when it is none of these.
    """
    key = entry.lower().replace("-", "")
    if key in _SYSTEMS:
        name, reach = _SYSTEMS[key]
        return t("campaign.air_defence.system", name=name, reach=t(f"campaign.air_defence.reach.{reach}"))
    generated = _GENERATED.match(entry)
    if generated:
        holds = _holds(entry)
        level = generated.group(1)
        if holds:
            return t("campaign.air_defence.generated", level=level, holds=", ".join(holds))
        return t("campaign.air_defence.generated_bare", level=level)
    return entry
