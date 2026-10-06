"""What the players know of each zone (FEAT-CAMPAIGN-BRIEFING-DECK ticket 02).

The enemy stays uneven intelligence: never a count, neither of a garrison nor of a reserve, each item
with the reliability of its source. The one exception is a fixed site — the long-range SAM of a zone —
named once the campaign state records it: a garrison is drawn when its mission starts, so before the
first mission nobody knows the battery's type, and from the second one on its units are in the state.
The friendly side's positions and reserves are known, and said.
"""

from __future__ import annotations

import functools
import re
from dataclasses import dataclass
from typing import Any

import yaml
from veaf_libs.bundled_data import read_bundled_text
from veaf_libs.i18n import t

from campaign_manager.models import RESERVE_CATEGORIES, CampaignDefinition, CampaignState, CampaignZone

#: The suffix `veafCampaign` gives the long-range SAM group of a garrison (`veafCampaign.lua`).
LONG_RANGE_SAM_SUFFIX = " long-range SAM"

#: An alias that is a NATO SAM designation, `sa10` or `sa-10`.
_NATO_ALIAS = re.compile(r"^sa-?(\d+)$", re.IGNORECASE)


@dataclass(frozen=True)
class FixedSite:
    """A long-range SAM the campaign state records in a zone."""

    system: str | None
    """Its name for the players (``SA-10``, ``Patriot``), or ``None`` for a battery no group names."""
    destroyed: bool


@functools.lru_cache(maxsize=1)
def _group_types() -> tuple[tuple[str, frozenset[str]], ...]:
    """Every named group of `veaf-units.yaml` with the DCS types it is made of."""
    raw = yaml.safe_load(read_bundled_text("veaf_libs", "data", "veaf-units.yaml")) or {}
    groups = []
    for group in raw.get("groups") or []:
        if group.get("hidden") or not group.get("aliases"):
            continue
        types = frozenset(str(unit.get("type")) for unit in group.get("units") or [] if unit.get("type"))
        if types:
            groups.append((_system_name([str(alias) for alias in group["aliases"]]), types))
    return tuple(groups)


def _system_name(aliases: list[str]) -> str:
    """The players' name of a group: its NATO designation when an alias is one, else its first alias."""
    for alias in aliases:
        match = _NATO_ALIAS.match(alias)
        if match:
            return f"SA-{match.group(1)}"
    return aliases[0][:1].upper() + aliases[0][1:]


def identify_system(types: set[str]) -> str | None:
    """Name the SAM system a set of DCS unit types belongs to.

    Args:
        types: The types of the battery's units, as the state records them.

    Returns:
        The name of the group of `veaf-units.yaml` sharing the most types with it, or ``None``
        when none shares any.
    """
    best, shared = None, 0
    for name, group_types in _group_types():
        overlap = len(types & group_types)
        if overlap > shared:
            best, shared = name, overlap
    return best


def fixed_site(garrison: list[dict[str, Any]] | None) -> FixedSite | None:
    """Return the long-range SAM a recorded garrison holds, if it holds one.

    Args:
        garrison: The zone's garrison as the state records it, or ``None`` before it is drawn.

    Returns:
        The site, destroyed when none of its units is alive; ``None`` when there is none to know of.
    """
    for group in garrison or []:
        if str(group.get("name", "")).endswith(LONG_RANGE_SAM_SUFFIX):
            units = group.get("units") or []
            if not units:
                return None
            system = identify_system({str(unit.get("type")) for unit in units})
            return FixedSite(system=system, destroyed=not any(unit.get("alive") for unit in units))
    return None


def _category(campaign: CampaignDefinition, zone: CampaignZone) -> str:
    """``logistics``, ``main`` (a size class with a long-range SAM) or ``outpost``."""
    if zone.kind == "logistics":
        return "logistics"
    size = campaign.size_classes.get(zone.size)
    return "main" if size is not None and size.long_range_sam else "outpost"


def _air_defence(campaign: CampaignDefinition, state: CampaignState, zone: CampaignZone) -> str | None:
    """What is said of a zone's long-range air defence, or ``None`` when it has none."""
    size = campaign.size_classes.get(zone.size)
    if size is None or not size.long_range_sam:
        return None
    site = fixed_site(state.zones[zone.name].garrison)
    if site is None:
        return t("campaign.intel.long_range.suspected")
    system = site.system or t("campaign.intel.long_range.unnamed")
    if site.destroyed:
        return t("campaign.intel.long_range.destroyed", system=system)
    return t("campaign.intel.long_range.confirmed", system=system)


def enemy_picture(campaign: CampaignDefinition, state: CampaignState, zone: CampaignZone) -> str:
    """What the intelligence says of a zone the enemy holds, in the current language.

    Args:
        campaign: The validated campaign.
        state: The campaign state the coming mission starts from.
        zone: A zone the enemy holds.

    Returns:
        One sentence or two, never a figure, ending with the reliability of the source.
    """
    category = _category(campaign, zone)
    parts = [zone.intel or t(f"campaign.intel.enemy.{category}")]
    air_defence = _air_defence(campaign, state, zone)
    if air_defence:
        parts.append(air_defence)
    return t("campaign.intel.line", text=" ".join(parts), source=t(f"campaign.intel.source.{category}"))


def friendly_picture(campaign: CampaignDefinition, zone: CampaignZone) -> str:
    """What a zone the players' side holds is, in the current language."""
    return t(f"campaign.intel.own.{_category(campaign, zone)}")


def reserve_text(reserve: dict[str, int]) -> str:
    """A friendly reserve, said in words, in the current language."""
    return t("campaign.intel.reserve", **{category: reserve.get(category, 0) for category in RESERVE_CATEGORIES})
