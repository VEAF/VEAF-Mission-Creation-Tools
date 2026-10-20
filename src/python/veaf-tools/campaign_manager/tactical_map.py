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
from veaf_libs.i18n import t
from veaf_libs.map_labels import Box
from veaf_libs.map_tiles import Fetch

from campaign_manager.map_canvas import BLACK, MapCanvas, TacticalMapReport
from campaign_manager.mission_picture import NM, MissionPicture
from campaign_manager.models import CampaignDefinition, CampaignState, CampaignZone
from campaign_manager.strategic_map import OWNER_COLOURS, _dashed, zone_position

#: The tactical map, in the mission's sub-folder (`missions/mission-NN/`).
TACTICAL_MAP_FILE = "carte-tactique.png"

#: How wide the AWACS orbit is drawn, in metres: its first waypoint is where it circles.
_AWACS_ORBIT = 25_000

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
    # where the players' waypoints stand, and the numbers each one carries in the navigation plan
    numbers: dict[tuple[float, float], list[str]] = {}
    for plan in picture.flight_plans:
        for index, waypoint in enumerate(plan.waypoints, 1):
            listed = numbers.setdefault((waypoint.x, waypoint.y), [])
            if str(index) not in listed:
                listed.append(str(index))
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
    qra_boxes = []
    for qra in picture.qra_zones:
        centre = canvas.at_xy(qra.x, qra.y)
        radius = canvas.pixels(qra.radius)
        canvas.circle(centre, radius, enemy, dashed=True)
        # labelled on its rim, at the north-west, clear of the zones inside it
        rim = (centre[0] - 0.707 * radius, centre[1] - 0.707 * radius)
        qra_boxes.append((rim[0] - 2, rim[1] - 2, rim[0] + 2, rim[1] + 2))
    carrier_boxes = []
    for carrier in picture.carriers:
        cx, cy = canvas.at_xy(carrier.x, carrier.y)
        canvas.draw.polygon([(cx, cy - 12), (cx - 9, cy + 9), (cx + 9, cy + 9)], fill=(*blue, 255))
        carrier_boxes.append((carrier, canvas.mark("carrier", (cx, cy), 12)))
    support_boxes = []
    for support in picture.support:
        if not support.route:
            continue
        start = canvas.at_xy(*support.route[0])
        if support.role == "awacs":
            canvas.circle(start, canvas.pixels(_AWACS_ORBIT), blue, dashed=True)
        elif len(support.route) > 1:
            canvas.draw.line((*start, *canvas.at_xy(*support.route[1])), fill=(*blue, 255), width=5)
        canvas.draw.ellipse((start[0] - 5, start[1] - 5, start[0] + 5, start[1] + 5), fill=(*blue, 255))
        support_boxes.append((support, canvas.mark(support.callsign, start, 6)))
    bx, by = canvas.at_xy(*picture.bullseye)
    for r in (8, 16):
        canvas.draw.ellipse((bx - r, by - r, bx + r, by + r), outline=BLACK, width=2)
    canvas.draw.line((bx - 22, by, bx + 22, by), fill=BLACK, width=2)
    canvas.draw.line((bx, by - 22, bx, by + 22), fill=BLACK, width=2)
    bullseye_box = canvas.mark("bullseye", (bx, by), 22)
    waypoint_boxes = []
    for (x, y), listed in numbers.items():
        wx, wy = canvas.at_xy(x, y)
        if (x, y) != picture.bullseye:  # the bullseye has its own symbol
            canvas.draw.ellipse((wx - 5, wy - 5, wx + 5, wy + 5), fill=BLACK, outline=(255, 255, 255, 255), width=2)
        waypoint_boxes.append(("/".join(listed), canvas.mark(f"waypoint {'/'.join(listed)}", (wx, wy), 6)))
    canvas.scale(20 * NM, "20 nm")

    for zone, box in zone_boxes:
        canvas.label(box, zone.label, canvas.big, (*OWNER_COLOURS[state.zones[zone.name].owner], 255))
    for box in qra_boxes:
        canvas.label(box, t("campaign.mission_deck.map.qra"), canvas.small, (*enemy, 255))
    for carrier, box in carrier_boxes:
        canvas.label(box, carrier.name, canvas.small, (*blue, 255))
    for support, box in support_boxes:
        canvas.label(box, support.callsign, canvas.small, (*blue, 255))
    canvas.label(bullseye_box, "Bullseye", canvas.small, BLACK)
    for text, box in waypoint_boxes:
        canvas.label(box, text, canvas.number, BLACK)
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
