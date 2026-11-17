"""The mission's objectives as the players' waypoints (FEAT-CAMPAIGN-OBJECTIVE-WAYPOINTS ticket 01).

`campaign next` writes the mission folder's `src/waypoints.yaml` from the campaign: one waypoint per zone
the mission's tasks name (else the campaign's objectives), at the zone's centre, in the tasks' order, for
the players' side, on the ground for planes and helicopters alike. Until then the folder carried the
template's example, whose steerpoints pointed nowhere near the theatre.

The file is the mission maker's once edited: it carries a fingerprint of what was written, and a second
`campaign next` rewrites it only while the fingerprint still matches.
"""

from __future__ import annotations

import hashlib
import re
import unicodedata
from pathlib import Path
from typing import Any

import yaml
from veaf_libs.coordinates import latlon_to_xy
from veaf_libs.magnetic import ground_distance_m

from campaign_manager.briefing_prose import MissionPage
from campaign_manager.mission_deck import objective_zones
from campaign_manager.models import CampaignDefinition, CampaignState, CampaignZone
from campaign_manager.strategic_map import zone_position

#: The waypoints file, in the mission folder.
WAYPOINTS_FILE = "src/waypoints.yaml"

#: Every objective waypoint sits on the ground, 0 m above it: the objective is there, and so is where a
#: targeting pod or a weapon slaved to the steerpoint looks (David, 2026-10-08, FIX-CAMPAIGN-MISSION-1-FINDINGS
#: ticket 06). Planes and helicopters share the waypoint; no altitude is kept for navigation.
GROUND_ALTITUDE = 0

#: True airspeed, m/s: about 350 kt. A player's steerpoint ignores it; DCS wants one.
SPEED = 180

#: The header line holding the fingerprint of what `campaign next` wrote.
_FINGERPRINT = "# campaign-next-fingerprint: "

_HEADER = (
    "# Written by `campaign next` from the mission's objectives: the zones its tasks name in briefing.yaml\n"
    "# (else the campaign's objectives), at their centres, in the tasks' order, for the players' side.\n"
    "# Edit it freely: once edited, `campaign next` leaves it alone. The build adds BULLSEYE.\n"
)


_PERSISTENT_HEADER = (
    "# Written by `campaign next`: a waypoint per zone of the campaign, at its centre, the most strategic first\n"
    "# (the front, then the airfields, factories and depots, nearest our zones first): an aircraft that holds few\n"
    "# steerpoints keeps the first ones. Their numbers show on the F10 map and in the campaign's messages.\n"
    "# Edit it freely: once edited, `campaign next` leaves it alone. The build adds BULLSEYE.\n"
)


def _ascii_capitals(text: str) -> str:
    """``Dépôt d'Ochamchire`` → ``DEPOT_D_OCHAMCHIRE``: what a cockpit display can show."""
    folded = unicodedata.normalize("NFKD", text).encode("ascii", "ignore").decode("ascii")
    return re.sub(r"[^A-Z0-9]+", "_", folded.upper()).strip("_")


def _first_word(name: str) -> str:
    """The first word of a name longer than two letters, an article skipped: ``Al-Safira`` → ``SAFIRA``.

    Args:
        name: The zone's name.

    Returns:
        The word, in capitals and without accents; the first one when none is longer than two letters.
    """
    words = _ascii_capitals(name).split("_")
    return next((word for word in words if len(word) > 2), words[0])


def waypoint_keys(zones: list[CampaignZone]) -> dict[str, str]:
    """The waypoint key of each zone: its name's first word, or its whole name when two zones share it.

    A leading article (`Al-`, `Le`, any word of one or two letters) is skipped: `Al-Safira` is `SAFIRA`.

    Args:
        zones: The zones to name.

    Returns:
        The key by zone name: ``Khobi depot`` → ``KHOBI``.
    """
    first = {zone.name: _first_word(zone.name) for zone in zones}
    shared = {key for key in first.values() if list(first.values()).count(key) > 1}
    return {name: _ascii_capitals(name) if key in shared else key for name, key in first.items()}


def strategic_zones(campaign: CampaignDefinition, state: CampaignState) -> list[CampaignZone]:
    """Every zone of a persistent campaign, the most strategic first: the order of its waypoints.

    David, 2026-11-16: "the waypoint numbers, everywhere, as in Foothold", and "choose the most strategic points:
    some aircraft take few". A module that holds fewer steerpoints than there are zones keeps the first ones, so
    the order is the rule: the zones on the front (connected to a zone of another owner), then the airfields, the
    factories, the depots and the rest, each by distance to the players' nearest zone.

    Args:
        campaign: The validated campaign.
        state: The state the mission starts from: who holds what.

    Returns:
        The zones, in waypoint order.
    """
    owner = {name: zone_state.owner for name, zone_state in state.zones.items()}
    position = {zone.name: zone_position(campaign, zone) for zone in campaign.zones}
    ours = [zone.name for zone in campaign.zones if owner.get(zone.name) == campaign.player_side]

    def front(zone: CampaignZone) -> bool:
        return any(owner.get(other) != owner.get(zone.name) for other in campaign.neighbours(zone.name))

    def kind(zone: CampaignZone) -> int:
        if zone.location.airfield:
            return 0
        return {"factory": 1, "depot": 2}.get(zone.kind or "", 3)

    def distance(zone: CampaignZone) -> float:
        here = position[zone.name]
        return min((ground_distance_m(*here, *position[name]) for name in ours), default=0.0)

    return sorted(campaign.zones, key=lambda zone: (not front(zone), kind(zone), distance(zone), zone.name))


def zone_waypoint_numbers(campaign: CampaignDefinition, state: CampaignState) -> dict[str, int]:
    """The waypoint number of each zone in the players' flight plan: 1 for the first after the departure.

    Args:
        campaign: The validated campaign.
        state: The state the mission starts from.

    Returns:
        Zone name -> number; empty for a multi-mission campaign, whose waypoints are its tasks' zones.
    """
    if campaign.mode != "persistent":
        return {}
    return {zone.name: index for index, zone in enumerate(strategic_zones(campaign, state), start=1)}


def _waypoint(name: str, xy: tuple[float, float], alt: int, alt_type: str, speed: int) -> dict[str, Any]:
    return {
        "type": "Turning Point",
        "action": "Turning Point",
        "alt": alt,
        "alt_type": alt_type,
        "speed": speed,
        "speed_type": "TAS",
        "x": round(xy[0]),
        "y": round(xy[1]),
        "name": name,
    }


def objective_waypoints(
    campaign: CampaignDefinition, page: MissionPage | None, state: CampaignState | None = None
) -> dict[str, Any]:
    """The `waypoints.yaml` of the coming mission, as data.

    A persistent campaign, with its state, gets a waypoint per zone, the most strategic first
    (`strategic_zones`); a multi-mission one the zones its tasks name.

    Args:
        campaign: The validated campaign.
        page: The coming mission's page of `briefing.yaml`, or ``None``.
        state: The state the mission starts from, for a persistent campaign.

    Returns:
        ``waypoints`` and ``settings``: a plan for the players' planes and one for their helicopters.
    """
    if campaign.mode == "persistent" and state is not None:
        zones = strategic_zones(campaign, state)
    else:
        zones = objective_zones(campaign, page)
    keys = waypoint_keys(zones)
    waypoints: dict[str, Any] = {}
    for zone in zones:
        xy = latlon_to_xy(campaign.theatre, *zone_position(campaign, zone))
        waypoints[keys[zone.name]] = _waypoint(keys[zone.name], xy, GROUND_ALTITUDE, "RADIO", SPEED)
    side = campaign.player_side
    route = [keys[z.name] for z in zones]
    return {
        "waypoints": waypoints,
        "settings": {
            f"{side}_planes": {"category": "plane", "coalition": side, "waypoints": route},
            f"{side}_helicopters": {"category": "helicopter", "coalition": side, "waypoints": list(route)},
        },
    }


def _fingerprint(body: str) -> str:
    return hashlib.sha256(body.encode("utf-8")).hexdigest()[:16]


def _untouched(text: str) -> bool:
    """Whether a waypoints file is still what `campaign next` wrote: its fingerprint matches its body."""
    lines = text.splitlines(keepends=True)
    for index, line in enumerate(lines):
        if line.startswith(_FINGERPRINT):
            return line[len(_FINGERPRINT) :].strip() == _fingerprint("".join(lines[index + 1 :]))
    return False


def write_objective_waypoints(
    campaign: CampaignDefinition,
    page: MissionPage | None,
    mission_folder: Path,
    *,
    created: bool,
    state: CampaignState | None = None,
) -> bool:
    """Write the mission folder's `src/waypoints.yaml`, unless it was edited since `campaign next` wrote it.

    Args:
        campaign: The validated campaign.
        page: The coming mission's page of `briefing.yaml`, or ``None``.
        mission_folder: The mission folder.
        created: Whether the folder was copied from the template now: its file is then the template's.
        state: The state the mission starts from: a persistent campaign's waypoints are every zone.

    Returns:
        Whether the file was written; ``False`` when an edited one was kept.
    """
    path = mission_folder / WAYPOINTS_FILE
    if not created and path.is_file() and not _untouched(path.read_text(encoding="utf-8")):
        return False
    body = yaml.safe_dump(objective_waypoints(campaign, page, state), allow_unicode=True, sort_keys=False)
    header = _PERSISTENT_HEADER if campaign.mode == "persistent" and state is not None else _HEADER
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(f"{header}{_FINGERPRINT}{_fingerprint(body)}\n{body}", encoding="utf-8")
    return True
