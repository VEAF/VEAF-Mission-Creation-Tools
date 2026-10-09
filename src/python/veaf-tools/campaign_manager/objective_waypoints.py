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

from campaign_manager.briefing_prose import MissionPage
from campaign_manager.mission_deck import objective_zones
from campaign_manager.models import CampaignDefinition, CampaignZone
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


def _ascii_capitals(text: str) -> str:
    """``Dépôt d'Ochamchire`` → ``DEPOT_D_OCHAMCHIRE``: what a cockpit display can show."""
    folded = unicodedata.normalize("NFKD", text).encode("ascii", "ignore").decode("ascii")
    return re.sub(r"[^A-Z0-9]+", "_", folded.upper()).strip("_")


def waypoint_keys(zones: list[CampaignZone]) -> dict[str, str]:
    """The waypoint key of each zone: its name's first word, or its whole name when two zones share it.

    Args:
        zones: The zones to name.

    Returns:
        The key by zone name: ``Khobi depot`` → ``KHOBI``.
    """
    first = {zone.name: _ascii_capitals(zone.name).split("_")[0] for zone in zones}
    shared = {key for key in first.values() if list(first.values()).count(key) > 1}
    return {name: _ascii_capitals(name) if key in shared else key for name, key in first.items()}


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


def objective_waypoints(campaign: CampaignDefinition, page: MissionPage | None) -> dict[str, Any]:
    """The `waypoints.yaml` of the coming mission, as data.

    Args:
        campaign: The validated campaign.
        page: The coming mission's page of `briefing.yaml`, or ``None``.

    Returns:
        ``waypoints`` and ``settings``: a plan for the players' planes and one for their helicopters.
    """
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
    campaign: CampaignDefinition, page: MissionPage | None, mission_folder: Path, *, created: bool
) -> bool:
    """Write the mission folder's `src/waypoints.yaml`, unless it was edited since `campaign next` wrote it.

    Args:
        campaign: The validated campaign.
        page: The coming mission's page of `briefing.yaml`, or ``None``.
        mission_folder: The mission folder.
        created: Whether the folder was copied from the template now: its file is then the template's.

    Returns:
        Whether the file was written; ``False`` when an edited one was kept.
    """
    path = mission_folder / WAYPOINTS_FILE
    if not created and path.is_file() and not _untouched(path.read_text(encoding="utf-8")):
        return False
    body = yaml.safe_dump(objective_waypoints(campaign, page), allow_unicode=True, sort_keys=False)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(f"{_HEADER}{_FINGERPRINT}{_fingerprint(body)}\n{body}", encoding="utf-8")
    return True
