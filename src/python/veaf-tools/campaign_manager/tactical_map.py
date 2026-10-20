"""The mission briefing's maps: the tactical situation, and one zoom per objective (ticket 03).

On the OpenStreetMap base of `veaf_libs/map_tiles.py`: the zones in their owner's colour, the axes,
the enemy's QRA zones dashed, the carrier, the AWACS orbit, the tanker track, the bullseye, the players'
waypoints numbered as the navigation plan numbers them, a scale.
Labels never overlap one another or a symbol (`veaf_libs/map_labels.py`). Nothing the intelligence
does not know is drawn: no garrison unit — a garrison is drawn when the mission starts.
"""

from __future__ import annotations

import re
from pathlib import Path

from veaf_libs.coordinates import xy_to_latlon
from veaf_libs.map_labels import Box
from veaf_libs.map_tiles import Fetch

from campaign_manager.map_canvas import MapCanvas, TacticalMapReport, draw_mission, waypoint_numbers
from campaign_manager.mission_picture import NM, MissionPicture
from campaign_manager.models import CampaignDefinition, CampaignState, CampaignZone
from campaign_manager.strategic_map import OWNER_COLOURS, _dashed, zone_position

#: The tactical map, in the mission's sub-folder (`missions/mission-NN/`).
TACTICAL_MAP_FILE = "carte-tactique.png"

#: Margin around what the tactical map holds, in metres.
_TACTICAL_MARGIN = 30_000

#: A zoom shows its zone and this much of its radius around it.
_ZOOM_MARGIN = 2.2


def zoom_file(zone: CampaignZone) -> str:
    """The file of an objective's zoom: ``zoom-khobi-depot.png``.

    Args:
        zone: The objective's zone.

    Returns:
        The file name.
    """
    return f"zoom-{re.sub(r'[^a-z0-9]+', '-', zone.name.lower()).strip('-')}.png"


def _zone(
    canvas: MapCanvas, campaign: CampaignDefinition, state: CampaignState, zone: CampaignZone, *, focus: bool
) -> Box:
    """Draw a zone's circle, keep its centre clear; return the circle's box for its label."""
    cx, cy = canvas.at(*zone_position(campaign, zone))
    radius = canvas.pixels(zone.radius)
    canvas.circle((cx, cy), radius, OWNER_COLOURS[state.zones[zone.name].owner], dashed=False, width=4 if focus else 3)
    canvas.mark(zone.name, (cx, cy), min(radius, 6))
    return (cx - radius, cy - radius, cx + radius, cy + radius)


def render_tactical_map(
    campaign: CampaignDefinition,
    state: CampaignState,
    picture: MissionPicture,
    out: Path,
    *,
    cache_dir: Path | None = None,
    fetch: Fetch | None = None,
) -> TacticalMapReport:
    """Render the tactical situation of the coming mission, framed to hold the support orbits.

    Args:
        campaign: The validated campaign.
        state: The campaign state the mission starts from.
        picture: What the built mission says.
        out: Where the PNG is written.
        cache_dir: Where map tiles are kept between runs.
        fetch: How a tile is downloaded (tests pass their own).

    Returns:
        Where the map is, and where its symbols and labels went.
    """
    theatre = campaign.theatre
    points = [zone_position(campaign, zone) for zone in campaign.zones]
    points += [xy_to_latlon(theatre, carrier.x, carrier.y) for carrier in picture.carriers]
    points += [xy_to_latlon(theatre, *support.route[0]) for support in picture.support if support.route]
    numbers = waypoint_numbers(picture)
    points += [xy_to_latlon(theatre, x, y) for x, y in numbers]
    canvas = MapCanvas(theatre, points, _TACTICAL_MARGIN, cache_dir, fetch)
    blue = OWNER_COLOURS[campaign.player_side]
    enemy = OWNER_COLOURS["red" if campaign.player_side == "blue" else "blue"]

    for a, b in campaign.connections:
        _dashed(
            canvas.draw,
            canvas.at(*zone_position(campaign, campaign.zone(a))),
            canvas.at(*zone_position(campaign, campaign.zone(b))),
        )
    # every symbol first, so that no label is set on one drawn after it
    zone_boxes = [(zone, _zone(canvas, campaign, state, zone, focus=False)) for zone in campaign.zones]
    labels = draw_mission(canvas, picture, blue, enemy, numbers)
    canvas.scale(20 * NM, "20 nm")

    for zone, box in zone_boxes:
        canvas.label(box, zone.label, canvas.big, (*OWNER_COLOURS[state.zones[zone.name].owner], 255))
    for box, text, font, colour in labels:
        canvas.label(box, text, font, colour)
    return canvas.save(out)


def render_objective_map(
    campaign: CampaignDefinition,
    state: CampaignState,
    zone: CampaignZone,
    out: Path,
    *,
    cache_dir: Path | None = None,
    fetch: Fetch | None = None,
) -> TacticalMapReport:
    """Render one objective: its zone at its radius, a scale in kilometres.

    Args:
        campaign: The validated campaign.
        state: The campaign state the mission starts from.
        zone: The objective's zone.
        out: Where the PNG is written.
        cache_dir: Where map tiles are kept between runs.
        fetch: How a tile is downloaded (tests pass their own).

    Returns:
        Where the map is, and where its zone and label went.
    """
    canvas = MapCanvas(campaign.theatre, [zone_position(campaign, zone)], zone.radius * _ZOOM_MARGIN, cache_dir, fetch)
    box = _zone(canvas, campaign, state, zone, focus=True)
    kilometres = 1 if zone.radius < 2000 else 2
    canvas.scale(kilometres * 1000, f"{kilometres} km")
    canvas.label(box, zone.label, canvas.big, (*OWNER_COLOURS[state.zones[zone.name].owner], 255))
    return canvas.save(out)
