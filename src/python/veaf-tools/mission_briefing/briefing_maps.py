"""A one-shot mission's briefing maps: the overview, and one zoom per objective (FEAT-MCP-MISSION-BRIEFING ticket 03).

The prompt's §4.6, drawn from the built mission instead of a script: departure, route and numbered
waypoints, objectives, known threats with their engagement circle (plain) and detection circle
(dashed), support, carrier, QRA, bullseye, scale and the tiles' credit. Only what intelligence knows:
a threat is drawn because the assistant names it, a range because it gives one, with its source.
Labels never overlap (`veaf_libs/map_labels.py`); without tiles the map stands on a plain background.
"""

from __future__ import annotations

import re
from pathlib import Path

from campaign_manager.map_canvas import BLACK, Label, MapCanvas, TacticalMapReport, draw_mission, waypoint_numbers
from campaign_manager.mission_picture import NM, MissionPicture
from campaign_manager.strategic_map import OWNER_COLOURS
from veaf_libs.coordinates import xy_to_latlon
from veaf_libs.map_tiles import OSM, Fetch, TileSource

from mission_briefing.models import Objective, ObjectiveArea, Threat

#: The overview map, in `docs/maps/`.
OVERVIEW_FILE = "overview.png"

#: Margin around what the overview holds, in metres.
_OVERVIEW_MARGIN = 15_000

#: A zoom shows its zone and this much of its radius around it…
_ZOOM_MARGIN = 2.2

#: …and never less than this around its centre, metres: a road or a relief must serve as a landmark.
_ZOOM_MIN = 3_000

#: The scale bars a map may carry, nautical miles for the overview, kilometres for a zoom.
_NM_BARS = (5, 10, 20, 50, 100)
_KM_BARS = (1, 2, 5)


def zoom_file(zone: str) -> str:
    """The file of an objective's zoom: ``objective-khobi.png``."""
    return f"objective-{re.sub(r'[^a-z0-9]+', '-', zone.lower()).strip('-')}.png"


def threat_circles(threat: Threat) -> list[tuple[float, bool]]:
    """The circles a threat is drawn with: ``(metres, dashed)``, engagement plain, detection dashed.

    Args:
        threat: The threat, as the assistant states it.

    Returns:
        One circle per range given; none without a range.
    """
    circles = [(threat.engagement_nm * NM, False)] if threat.engagement_nm else []
    return circles + ([(threat.detection_nm * NM, True)] if threat.detection_nm else [])


def _bar(canvas: MapCanvas, unit: float, bars: tuple[int, ...]) -> int:
    """The longest bar of ``bars`` (in ``unit`` metres) that fits a quarter of the map's width."""
    width = canvas.background.size[0] / canvas.pixels(1)
    fitting = [bar for bar in bars if bar * unit <= width / 4]
    return fitting[-1] if fitting else bars[0]


def _threat(canvas: MapCanvas, threat: Threat, position: tuple[float, float], enemy: tuple[int, int, int]) -> Label:
    """Draw a threat's circles and its diamond; return its label."""
    centre = canvas.at_xy(*position)
    for metres, dashed in threat_circles(threat):
        canvas.circle(centre, canvas.pixels(metres), enemy, dashed=dashed, width=2 if dashed else 3)
    cx, cy = centre
    canvas.draw.polygon([(cx, cy - 9), (cx + 9, cy), (cx, cy + 9), (cx - 9, cy)], fill=(*enemy, 255))
    return (canvas.mark(threat.name, centre, 9), threat.name, canvas.small, (*enemy, 255))


def _objective(canvas: MapCanvas, area: ObjectiveArea, enemy: tuple[int, int, int], *, focus: bool) -> Label:
    """Draw an objective's zone; return its label, set on the circle."""
    cx, cy = canvas.at_xy(area.x, area.y)
    radius = max(canvas.pixels(area.radius), 8)
    canvas.circle((cx, cy), radius, enemy, dashed=False, width=4 if focus else 3)
    canvas.mark(area.zone, (cx, cy), min(radius, 6))
    return ((cx - radius, cy - radius, cx + radius, cy + radius), area.zone, canvas.big, (*enemy, 255))


def _sides(side: str) -> tuple[tuple[int, int, int], tuple[int, int, int]]:
    return OWNER_COLOURS[side], OWNER_COLOURS["red" if side == "blue" else "blue"]


def render_overview_map(
    picture: MissionPicture,
    objectives: list[tuple[Objective, ObjectiveArea]],
    threats: list[tuple[Threat, tuple[float, float]]],
    departures: list[tuple[str, float, float]],
    out: Path,
    *,
    side: str = "blue",
    cache_dir: Path | None = None,
    fetch: Fetch | None = None,
    source: TileSource = OSM,
) -> TacticalMapReport:
    """Render the mission's overview, framed to hold everything it shows and the threats' engagement.

    Args:
        picture: What the built mission says.
        objectives: Each objective and its zone, read from the mission.
        threats: Each known threat and where its group stands.
        departures: The airfields the players take off from, ``(name, x, y)``.
        out: Where the PNG is written.
        side: The players' side.
        cache_dir: Where map tiles are kept between runs.
        fetch: How a tile is downloaded (tests pass their own).
        source: Where the tiles come from.

    Returns:
        Where the map is, and where its symbols and labels went.
    """
    theatre = picture.theatre
    friend, enemy = _sides(side)
    numbers = waypoint_numbers(picture)
    spots = [(area.x, area.y) for _, area in objectives]
    for threat, (x, y) in threats:
        reach = max((metres for metres, dashed in threat_circles(threat) if not dashed), default=0.0)
        spots += [(x + reach, y), (x - reach, y), (x, y + reach), (x, y - reach)]
    spots += [(c.x, c.y) for c in picture.carriers] + [s.route[0] for s in picture.support if s.route]
    spots += [(x, y) for _, x, y in departures] + list(numbers) + [picture.bullseye]
    canvas = MapCanvas(
        theatre, [xy_to_latlon(theatre, x, y) for x, y in spots], _OVERVIEW_MARGIN, cache_dir, fetch, source
    )

    for plan in picture.flight_plans:
        route = [canvas.at_xy(wp.x, wp.y) for wp in plan.waypoints]
        for a, b in zip(route, route[1:], strict=False):
            canvas.draw.line((*a, *b), fill=(*BLACK[:3], 140), width=2)
    # every symbol first, so that no label is set on one drawn after it
    labels = [_objective(canvas, area, enemy, focus=False) for _, area in objectives]
    labels += [_threat(canvas, threat, position, enemy) for threat, position in threats]
    for name, x, y in departures:
        dx, dy = canvas.at_xy(x, y)
        canvas.draw.rectangle((dx - 7, dy - 7, dx + 7, dy + 7), fill=(*friend, 255))
        labels.append((canvas.mark(name, (dx, dy), 7), name, canvas.small, (*friend, 255)))
    labels += draw_mission(canvas, picture, friend, enemy, numbers)
    bar = _bar(canvas, NM, _NM_BARS)
    canvas.scale(bar * NM, f"{bar} nm")
    for box, text, font, colour in labels:
        canvas.label(box, text, font, colour)
    return canvas.save(out)


def render_objective_zoom(
    theatre: str,
    objective: Objective,
    area: ObjectiveArea,
    threats: list[tuple[Threat, tuple[float, float]]],
    out: Path,
    *,
    side: str = "blue",
    cache_dir: Path | None = None,
    fetch: Fetch | None = None,
    source: TileSource = OSM,
) -> TacticalMapReport:
    """Render one objective: its zone, each of its targets, the threats that stand in the frame.

    Args:
        theatre: The mission's theatre.
        objective: The objective, as the assistant states it.
        area: Its zone and targets, read from the mission.
        threats: The known threats and where they stand; those outside the frame are left out.
        out: Where the PNG is written.
        side: The players' side.
        cache_dir: Where map tiles are kept between runs.
        fetch: How a tile is downloaded (tests pass their own).
        source: Where the tiles come from.

    Returns:
        Where the map is, and where its symbols and labels went.
    """
    _, enemy = _sides(side)
    half = max(area.radius * _ZOOM_MARGIN, _ZOOM_MIN)
    spots = [(area.x, area.y)] + [(target.x, target.y) for target in area.targets]
    canvas = MapCanvas(theatre, [xy_to_latlon(theatre, x, y) for x, y in spots], half, cache_dir, fetch, source)
    labels = [_objective(canvas, area, enemy, focus=True)]
    width, height = canvas.background.size
    for threat, position in threats:
        x, y = canvas.at_xy(*position)
        if 0 <= x < width and 0 <= y < height:
            labels.append(_threat(canvas, threat, position, enemy))
    for target in area.targets:
        tx, ty = canvas.at_xy(target.x, target.y)
        canvas.draw.rectangle((tx - 5, ty - 5, tx + 5, ty + 5), fill=(*enemy, 255), outline=(255, 255, 255, 255))
        labels.append((canvas.mark(f"target {target.name}", (tx, ty), 6), target.name, canvas.small, BLACK))
    bar = _bar(canvas, 1000, _KM_BARS)
    canvas.scale(bar * 1000, f"{bar} km")
    for box, text, font, colour in labels:
        canvas.label(box, text, font, colour)
    return canvas.save(out)
