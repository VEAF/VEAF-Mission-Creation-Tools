"""Which era a VEAF spawn shortcut (``-samLR``, ``-sa6``, ``-freya``…) is correct for.

``mission.era`` changes what a few shortcuts spawn — ``-aaa``, ``-samSR``, ``-samLR``, ``-samVLR``, ``-armor``,
``-infantry``, ``-transport``, ``-combat``, ``-convoy`` draw their units from tables keyed by era — and does
nothing to the others: ``-ewr`` is a 1L13 whatever the date, ``-arty`` an M-109. An agent building the Normandy
1944 Open Training had to find out by experiment which was which (FIX-OPEN-TRAINING-NORMANDY-FINDINGS ticket 05).

The era of a shortcut is read from what it runs, never typed beside it, so a new alias cannot be left unlabelled:

- the five ``_spawn`` kinds that go through ``veafCasMission.generate*`` (and ``convoy``) **follow the era**;
- a ``_spawn unit`` or ``_spawn group`` of equipment that all existed by 1945 is **WW2**, any other **post-WW2**;
- a command that spawns no equipment of its own (a marker, a radio call, a smoke) is **era-free**;
- the rest (``_spawn jtac``, ``afac``, ``cargo``…) is **unknown**: not measured, so not claimed.
"""

from __future__ import annotations

import re
from functools import lru_cache
from typing import Any

import yaml

from veaf_libs.bundled_data import read_bundled_text
from veaf_libs.veaf_shortcuts_scanner import get_shortcuts

#: The answers.
FOLLOWS_ERA = "follows_era"
WW2 = "ww2"
POST_WW2 = "post_ww2"
ERA_FREE = "era_free"
UNKNOWN = "unknown"

#: ``_spawn`` kinds whose units come from tables keyed by ``veaf.config.era`` (veafCasMission.generate*).
_FOLLOWING_KINDS = frozenset(
    {"samgroup", "longrangesam", "armorgroup", "infantrygroup", "transportgroup", "combatgroup", "convoy"}
)
#: ``_spawn`` kinds that place no equipment.
_ERA_FREE_KINDS = frozenset({"flare", "smoke"})
#: Commands (the word before the first comma) that place no equipment.
_ERA_FREE_COMMANDS = frozenset({"_name", "_destroy", "_radio", "_gc", "_move"})
#: Commands that run a CAS mission, whose groups come from the same era-keyed tables.
_FOLLOWING_COMMANDS = frozenset({"_cas"})

#: Equipment of 1944-45 the shortcuts spawn, besides the types ``mission_builder.era_detector`` already lists.
_EXTRA_WW2_EQUIPMENT = (
    "FuMG-401",
    "FuSe-65",
    "Flakscheinwerfer_37",
    "LeFH_18-40-105",
    "Pak40",
    "Wespe124",
    "M2A1-105",
    "M12_GMC",
    "QF_37_AA",
    "M45_Quadmount",
    "M1_37mm",
)


@lru_cache(maxsize=1)
def ww2_equipment() -> frozenset[str]:
    """Return the DCS types of 1944-45 a shortcut may spawn, lower-cased: the era detector's list and a few more.

    One list, not two: a type missing from a second copy classed the ``generateAirDefenseGroup-*-WW2-*`` groups
    as post-WW2. Imported here and not at module level, since ``mission_builder`` imports this package.

    Returns:
        The types, compared case-insensitively (the detector spells ``Flak18`` what DCS calls ``flak18``).
    """
    from mission_builder.era_detector import WW2_UNIT_TYPES  # noqa: PLC0415

    return frozenset(name.lower() for name in (*WW2_UNIT_TYPES, *_EXTRA_WW2_EQUIPMENT))


_NAME = re.compile(r"\bname\s+([^,]+)")


@lru_cache(maxsize=1)
def _spawn_data() -> tuple[dict[str, str], dict[str, list[str]]]:
    """Load the unit aliases (alias -> DCS type) and the group aliases (alias -> its unit types)."""
    data: dict[str, Any] = yaml.safe_load(read_bundled_text("veaf_libs", "data", "veaf-units.yaml")) or {}
    units = {
        str(alias).lower(): str(entry["unitType"])
        for entry in data.get("units") or []
        for alias in entry.get("aliases") or []
    }
    groups = {
        str(alias).lower(): [str(unit["type"]) for unit in entry.get("units") or [] if "type" in unit]
        for entry in data.get("groups") or []
        for alias in entry.get("aliases") or []
    }
    return units, groups


def equipment_era(unit_types: list[str]) -> str:
    """Return the era of a set of DCS unit types.

    Args:
        unit_types: The types a unit alias or a group alias spawns.

    Returns:
        :data:`WW2` when every type is of the era, :data:`POST_WW2` when one is not, :data:`UNKNOWN` with no type.
    """
    if not unit_types:
        return UNKNOWN
    return WW2 if all(t.lower() in ww2_equipment() for t in unit_types) else POST_WW2


def era_of_command(veaf_command: str) -> str:
    """Return the era a ``veafCommand`` is correct for.

    Args:
        veaf_command: The command a shortcut runs, e.g. ``_spawn samgroup, skynet true`` (``""`` for a batch alias).

    Returns:
        :data:`FOLLOWS_ERA`, :data:`WW2`, :data:`POST_WW2`, :data:`ERA_FREE` or :data:`UNKNOWN`.
    """
    parts = [part.strip() for part in veaf_command.split(",")]
    head = parts[0].split()
    if not head:
        return ERA_FREE  # a batch alias runs other shortcuts, which carry their own era
    if head[0] in _FOLLOWING_COMMANDS:
        return FOLLOWS_ERA
    if head[0] in _ERA_FREE_COMMANDS:
        return ERA_FREE
    if head[0] != "_spawn" or len(head) < 2:
        return UNKNOWN
    kind = head[1]
    if kind in _FOLLOWING_KINDS:
        return FOLLOWS_ERA
    if kind in _ERA_FREE_KINDS:
        return ERA_FREE
    if kind not in ("unit", "group"):
        return UNKNOWN
    wanted = next((m.group(1).strip().lower() for part in parts if (m := _NAME.search(part))), "")
    units, groups = _spawn_data()
    if kind == "unit":
        return equipment_era([units[wanted]] if wanted in units else [wanted] if wanted else [])
    return equipment_era(groups.get(wanted, []))


@lru_cache(maxsize=1)
def command_eras() -> dict[str, str]:
    """Return the era of every shortcut command, keyed by lowercase alias (leading ``-`` kept)."""
    return {
        alias.lower(): era_of_command(entry["veafCommand"]) for entry in get_shortcuts() for alias in entry["aliases"]
    }


def era_of_alias(alias: str) -> str | None:
    """Return the era of a shortcut by its marker name, or ``None`` for one the scanner does not know.

    Args:
        alias: The alias, with or without its leading ``-``.

    Returns:
        The era (see :func:`era_of_command`), or ``None``.
    """
    key = alias.strip().lower()
    return command_eras().get(key if key.startswith("-") else f"-{key}")


def fits_era(era_of: str, mission_era: str) -> bool:
    """Whether a shortcut of era ``era_of`` is worth offering in a mission of ``mission_era``.

    Args:
        era_of: The shortcut's era (see :func:`era_of_command`).
        mission_era: ``WW2``, ``COLD_WAR`` or ``MODERN``.

    Returns:
        ``True`` for a shortcut that follows the era or is era-free, in any mission. A WW2 one is offered only in a
        WW2 mission, and a post-WW2 or unknown one in every other.
    """
    if era_of in (FOLLOWS_ERA, ERA_FREE):
        return True
    if mission_era == "WW2":
        return era_of == WW2
    return era_of != WW2
