"""A side's supply network, read for the players: what each factory feeds, and where to cut it.

A persistent campaign has no mission objectives: the network guides the effort (David, 2026-11-17). A factory
feeds the zones it reaches hop by hop through its own side's zones, as the runtime's supply network does
(`veafCampaignLogistics`); a **critical node** is a zone whose capture leaves some of the side's zones with no
factory left to reach them — "taking Saraqib isolates Idlib and Taftanaz from the factory".
"""

from __future__ import annotations

from collections.abc import Iterable, Mapping
from dataclasses import dataclass

from campaign_manager.models import CampaignDefinition


@dataclass(frozen=True)
class CriticalNode:
    """A zone whose capture cuts part of its side's network off its factories."""

    zone: str
    isolated: tuple[str, ...]
    """The side's zones no factory reaches once it is taken, in declaration order."""


@dataclass(frozen=True)
class NetworkPicture:
    """A side's network as its owners stand."""

    factories: dict[str, tuple[str, ...]]
    """Each factory of the side, and the side's zones it reaches (itself excepted)."""
    depots: dict[str, tuple[str, ...]]
    """Each depot of the side, and the side's zones connected to it."""
    cut_off: tuple[str, ...]
    """The side's zones no factory reaches already."""
    critical: tuple[CriticalNode, ...]
    """The critical nodes, the ones isolating the most zones first."""


def _reach(
    campaign: CampaignDefinition, owners: Mapping[str, str], side: str, sources: Iterable[str], removed: str | None
) -> set[str]:
    """The side's zones reached from the sources through the side's zones, one zone left out."""
    held = {name for name, owner in owners.items() if owner == side and name != removed}
    seen = {source for source in sources if source in held}
    frontier = list(seen)
    while frontier:
        current = frontier.pop()
        for neighbour in campaign.neighbours(current):
            if neighbour in held and neighbour not in seen:
                seen.add(neighbour)
                frontier.append(neighbour)
    return seen


def network_picture(campaign: CampaignDefinition, owners: Mapping[str, str], side: str) -> NetworkPicture:
    """Read a side's network: what its factories and depots feed, what is cut off, and its critical nodes.

    Args:
        campaign: The validated campaign.
        owners: Each zone's owner.
        side: ``blue`` or ``red``.

    Returns:
        The picture.
    """
    order = [zone.name for zone in campaign.zones]
    ours = [zone for zone in campaign.zones if owners.get(zone.name) == side]
    factories = [zone.name for zone in ours if zone.kind == "factory"]
    fed: dict[str, tuple[str, ...]] = {}
    for factory in factories:
        reached = _reach(campaign, owners, side, [factory], None) - {factory}
        fed[factory] = tuple(name for name in order if name in reached)
    depots = {
        zone.name: tuple(n for n in campaign.neighbours(zone.name) if owners.get(n) == side)
        for zone in ours
        if zone.kind == "depot"
    }
    reached_now = _reach(campaign, owners, side, factories, None)
    cut_off = tuple(zone.name for zone in ours if zone.name not in reached_now)
    critical = []
    for zone in ours:
        after = _reach(campaign, owners, side, factories, zone.name)
        isolated = tuple(name for name in order if name in reached_now and name not in after and name != zone.name)
        if isolated:
            critical.append(CriticalNode(zone.name, isolated))
    critical.sort(key=lambda node: (-len(node.isolated), order.index(node.zone)))
    return NetworkPicture(factories=fed, depots=depots, cut_off=cut_off, critical=tuple(critical))
