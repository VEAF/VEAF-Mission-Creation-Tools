"""A one-shot mission's briefing maps: the overview, and one zoom per objective (FEAT-MCP-MISSION-BRIEFING ticket 03).

The prompt's §4.6, drawn from the built mission instead of a script: departure, route and numbered
waypoints, objectives, known threats with their engagement circle (plain) and detection circle
(dashed), support, carrier, QRA, bullseye, scale and the tiles' credit. Only what intelligence knows:
a threat is drawn because the assistant names it, a range because it gives one, with its source.
Labels never overlap (`veaf_libs/map_labels.py`); without tiles the map stands on a plain background.

The overview (FEAT-OBJECTIVE-BRIEFING-QUALITY 02) is framed on the theatre the players fly — the route,
the departures, the objectives, the threats where they stand, the tankers and the AWACS, the QRA zones'
centres, the front line — and not on the threats' full reach, and carries its own key, so that the slide
gives it its whole width. Given a ``width``, it is turned when that holds it tighter (a north arrow says
where north is) and drawn at that width with every symbol in proportion. A zoom given an ``inset``
carries the overview in a corner, its own place marked on it.

As "Marteau du Golan"'s hand-made maps did (FIX-BRIEFING-PARITY-MARTEAU 02): the large zones are
outlined, not filled — the QRA zones dashed in orange, a long-range SAM's reach a plain line on a faint
tint —; an objective is named as the flight plan names it; the helicopters' route is green and dashed;
the combat-area map adds the friendly ground units, the JTAC, the ground axes, and a threat's range on
its label.
"""

from __future__ import annotations

import math
import re
from dataclasses import dataclass, replace
from pathlib import Path

from campaign_manager.map_canvas import (
    _AWACS_ORBIT,
    BLACK,
    Box,
    Label,
    MapCanvas,
    TacticalMapReport,
    best_rotation,
    draw_mission,
    waypoint_numbers,
)
from campaign_manager.mission_picture import NM, MissionPicture
from campaign_manager.strategic_map import OWNER_COLOURS
from PIL import Image
from veaf_libs.coordinates import xy_to_latlon
from veaf_libs.i18n import t
from veaf_libs.map_tiles import OSM, Fetch, TileSource

from mission_briefing.models import GroundPicture, MapLine, Objective, ObjectiveArea, Threat

#: The overview map, in `docs/maps/`.
OVERVIEW_FILE = "overview.png"

#: The combat-area map, in `docs/maps/` (FEAT-OBJECTIVE-MISSION-V2 02).
COMBAT_AREA_FILE = "combat-area.png"

#: Margin around what the overview holds, in metres.
_OVERVIEW_MARGIN = 15_000

#: Margin around the objectives and threats the combat-area map holds, in metres.
_COMBAT_MARGIN = 6_000

#: A zoom shows its zone and this much of its radius around it…
_ZOOM_MARGIN = 2.2

#: …and never less than this around its centre, metres: a road or a relief must serve as a landmark.
_ZOOM_MIN = 3_000

#: The scale bars a map may carry, nautical miles for the overview, kilometres for a zoom.
_NM_BARS = (5, 10, 20, 50, 100)
_KM_BARS = (1, 2, 5)

#: The inset's width, as a share of the zoom's.
_INSET_SHARE = 0.3

_ROUTE = (60, 60, 60, 220)

#: The helicopters' route, green and dashed, and the QRA zones, orange and dashed: the hand-made maps' colours.
_HELICOPTER = (0, 130, 60)
_QRA = (230, 120, 0)

#: How opaque a zone is filled on the overview and the combat map: a tint that leaves the map readable.
_ZONE_FILL = 40
_REACH_FILL = 14

#: A waypoint's prefix in the labels, by plan category: ``W1 PUSH``, ``H1 MASADA``.
_PREFIX = {"plane": "W", "helicopter": "H"}


@dataclass(frozen=True)
class Inset:
    """The overview, to show in a corner of a zoom: the image, and where the zoom's centre stands on it."""

    image: Path
    centre: tuple[float, float]
    """Pixels on the overview."""
    radius: float
    """The zoom's half width, in the overview's pixels."""


def attack_axis_rotation(origin: tuple[float, float] | None, targets: list[tuple[float, float]]) -> float | None:
    """The turn, degrees anticlockwise, that puts the attack axis up: from ``origin`` to the targets' centre.

    A kneeboard map is read in the cockpit along the way in: Marteau du Golan's were turned by hand so
    that the axis from Ramat David to the Golan pointed up (FEAT-OBJECTIVE-MISSION-V2 03). The bearing is
    true, taken on ``(lat, lon)``: the maps are drawn true north up, and a bearing on the mission's grid
    is off by the meridian convergence (6 degrees at Kobuleti, measured by the test).

    Args:
        origin: Where the players come from, ``(lat, lon)``; ``None`` when unknown.
        targets: The objectives, ``(lat, lon)``.

    Returns:
        A turn in ``(-180, 180]``, or ``None`` when there is no axis (no origin, no target, or on it).
    """
    if origin is None or not targets:
        return None
    lat = sum(p[0] for p in targets) / len(targets)
    lon = sum(p[1] for p in targets) / len(targets)
    north = lat - origin[0]
    east = (lon - origin[1]) * math.cos(math.radians((lat + origin[0]) / 2))
    if math.hypot(north, east) < 1e-5:
        return None
    bearing = math.degrees(math.atan2(east, north)) % 360
    return bearing - 360 if bearing > 180 else bearing


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


def _diamond(canvas: MapCanvas, centre: tuple[float, float], half: int, colour: tuple[int, ...]) -> None:
    cx, cy = centre
    canvas.draw.polygon([(cx, cy - half), (cx + half, cy), (cx, cy + half), (cx - half, cy)], fill=colour)


def threat_label(threat: Threat) -> str:
    """A threat's label, its engagement range after its name when known: ``SA-6 de Sa'sa' (13 nm)``."""
    return f"{threat.name} ({threat.engagement_nm:g} nm)" if threat.engagement_nm else threat.name


def _threat(
    canvas: MapCanvas,
    threat: Threat,
    position: tuple[float, float],
    enemy: tuple[int, int, int],
    fill: int = 70,
) -> Label:
    """Draw a threat's circles and its diamond; return its label."""
    centre = canvas.at_xy(*position)
    for metres, dashed in threat_circles(threat):
        width = canvas.px(2) if dashed else canvas.px(3)
        canvas.circle(centre, canvas.pixels(metres), enemy, dashed=dashed, width=width, fill=fill)
    _diamond(canvas, centre, canvas.px(9), (*enemy, 255))
    return (canvas.mark(threat.name, centre, canvas.px(9)), threat_label(threat), canvas.small, (*enemy, 255))


def _objective(
    canvas: MapCanvas,
    area: ObjectiveArea,
    enemy: tuple[int, int, int],
    *,
    focus: bool,
    text: str | None = None,
    fill: int = 70,
) -> Label:
    """Draw an objective's zone; return its label, set on the circle: ``text``, or the objective's name."""
    cx, cy = canvas.at_xy(area.x, area.y)
    radius = max(canvas.pixels(area.radius), canvas.px(8))
    canvas.circle((cx, cy), radius, enemy, dashed=False, width=canvas.px(4 if focus else 3), fill=fill)
    canvas.mark(area.zone, (cx, cy), min(radius, canvas.px(6)))
    return ((cx - radius, cy - radius, cx + radius, cy + radius), text or area.name, canvas.big, (*enemy, 255))


#: How far from an objective or a threat a friendly unit still frames the combat map, metres.
_FIGHT_REACH = 30_000


def _near(spots: list[tuple[float, float]], x: float, y: float) -> bool:
    return any(math.dist(spot, (x, y)) <= _FIGHT_REACH for spot in spots)


#: How close to a route every point of a drawn line lies when it only retraces that route, metres.
_RETRACED = 3_000


def _to_segment(point: tuple[float, float], a: tuple[float, float], b: tuple[float, float]) -> float:
    """The distance from a point to a segment, metres."""
    (px, py), (ax, ay), (bx, by) = point, a, b
    length = (bx - ax) ** 2 + (by - ay) ** 2
    share = 0.0 if not length else max(0.0, min(1.0, ((px - ax) * (bx - ax) + (py - ay) * (by - ay)) / length))
    return math.dist(point, (ax + share * (bx - ax), ay + share * (by - ay)))


def retraces(line: MapLine, routes: list[list[tuple[float, float]]]) -> bool:
    """Whether a drawn line only retraces a route the map already draws: every point near one of its legs.

    "Marteau du Golan" drew its helicopters' route by hand, and the overview showed it twice, blue and
    green, with two rows in the key (FIX-BRIEFING-PARITY-MARTEAU-2 01).
    """
    for route in routes:
        legs = list(zip(route, route[1:], strict=False))
        if legs and all(min(_to_segment(point, a, b) for a, b in legs) <= _RETRACED for point in line.points):
            return True
    return False


def _dashed(
    canvas: MapCanvas, points: list[tuple[float, float]], colour: tuple[int, ...], width: int, dash: int = 18
) -> None:
    """A polyline in dashes of ``dash`` pixels (at the reference width), as long gaps."""
    on, off = canvas.px(dash), canvas.px(dash * 0.7)
    for (ax, ay), (bx, by) in zip(points, points[1:], strict=False):
        length = math.hypot(bx - ax, by - ay)
        if not length:
            continue
        ux, uy = (bx - ax) / length, (by - ay) / length
        done = 0.0
        while done < length:
            end = min(done + on, length)
            canvas.draw.line((ax + ux * done, ay + uy * done, ax + ux * end, ay + uy * end), fill=colour, width=width)
            done = end + off


def _drawn_line(canvas: MapCanvas, line: MapLine) -> None:
    """A line the author drew, in its colour and style."""
    pixels = [canvas.at_xy(x, y) for x, y in line.points]
    width = canvas.px(max(2, line.width))
    if line.dashed:
        _dashed(canvas, pixels, (*line.colour, 255), width)
    else:
        canvas.draw.line(pixels, fill=(*line.colour, 255), width=width, joint="curve")


def _ground(
    canvas: MapCanvas, ground: GroundPicture, side: str, friend: tuple[int, int, int], enemy: tuple[int, int, int]
) -> list[Label]:
    """The axes, the friendly units and the JTACs; return the JTACs' labels."""
    for coalition, points in ground.axes:
        colour = friend if coalition == side else enemy
        _dashed(canvas, [canvas.at_xy(x, y) for x, y in points], (*colour, 230), canvas.px(4))
    half = canvas.px(5)
    for x, y in ground.friendlies:
        fx, fy = canvas.at_xy(x, y)
        canvas.draw.rectangle(
            (fx - half, fy - half, fx + half, fy + half), fill=(*friend, 255), outline=(255, 255, 255, 255)
        )
        canvas.mark(f"friendly {x:.0f} {y:.0f}", (fx, fy), half)
    labels: list[Label] = []
    for name, x, y in ground.jtacs:
        jx, jy = canvas.at_xy(x, y)
        size = canvas.px(10)
        canvas.draw.polygon(
            [(jx, jy - size), (jx - size, jy + size * 0.8), (jx + size, jy + size * 0.8)], fill=(*friend, 255)
        )
        labels.append((canvas.mark(name, (jx, jy), size), name, canvas.small, (*friend, 255)))
    return labels


def _waypoints(canvas: MapCanvas, picture: MissionPicture, named: set[str]) -> list[Label]:
    """Every point of the players' routes, a dot and ``W3 KHAN`` / ``H1 MASADA``; just the numbers on an objective."""
    found: dict[tuple[float, float], tuple[list[str], str, bool]] = {}
    for plan in picture.flight_plans:
        prefix = _PREFIX.get(plan.category, "W")
        for index, waypoint in enumerate(plan.waypoints, 1):
            numbers, _, plane = found.setdefault((waypoint.x, waypoint.y), ([], waypoint.name, False))
            if f"{prefix}{index}" not in numbers:
                numbers.append(f"{prefix}{index}")
            found[(waypoint.x, waypoint.y)] = (numbers, waypoint.name, plane or plan.category != "helicopter")
    labels: list[Label] = []
    dot = canvas.px(5)
    for (x, y), (numbers, name, plane) in found.items():
        if (x, y) == picture.bullseye:  # the bullseye has its own symbol
            continue
        wx, wy = canvas.at_xy(x, y)
        colour = BLACK if plane else (*_HELICOPTER, 255)
        canvas.draw.ellipse(
            (wx - dot, wy - dot, wx + dot, wy + dot), fill=colour, outline=(255, 255, 255, 255), width=canvas.px(2)
        )
        text = "/".join(numbers) if name.lower() in named else f"{'/'.join(numbers)} {name}"
        labels.append((canvas.mark(f"waypoint {text}", (wx, wy), canvas.px(6)), text, canvas.number, colour))
    return labels


def _sides(side: str) -> tuple[tuple[int, int, int], tuple[int, int, int]]:
    return OWNER_COLOURS[side], OWNER_COLOURS["red" if side == "blue" else "blue"]


def _in_frame(canvas: MapCanvas, x: float, y: float, reach: float = 0.0) -> bool:
    """Whether a mission point, or a circle of ``reach`` metres about it, shows on the saved map."""
    px, py = canvas.turned(canvas.at_xy(x, y))
    width, height = canvas.frame_size
    gap = canvas.pixels(reach)
    return -gap <= px <= width + gap and -gap <= py <= height + gap


def _key_rows(
    canvas: MapCanvas,
    picture: MissionPicture,
    objectives: list[tuple[Objective, ObjectiveArea]],
    threats: list[tuple[Threat, tuple[float, float]]],
    departures: list[tuple[str, float, float]],
    ground: GroundPicture | None = None,
    side: str = "blue",
) -> list[str]:
    """What the overview's key explains, in its order: only what the map shows.

    The frame leaves the tankers' tracks and the QRA zones out when they stand away from the route: the key
    says them only when they are in it. A line the author drew is a row ``line <n>``, its name the text.
    """
    ranges = [circle for threat, _ in threats for circle in threat_circles(threat)]
    roles = {
        support.role
        for support in picture.support
        if support.route and _in_frame(canvas, *support.route[0], _AWACS_ORBIT if support.role == "awacs" else 0)
    }
    qra = any(_in_frame(canvas, zone.x, zone.y, zone.radius) for zone in picture.qra_zones)
    carriers = any(_in_frame(canvas, carrier.x, carrier.y) for carrier in picture.carriers)
    rows = ["objective"] if objectives else []
    rows += ["threat"] if threats else []
    rows += ["engagement"] if any(not dashed for _, dashed in ranges) else []
    rows += ["detection"] if any(dashed for _, dashed in ranges) else []
    rows += ["departure"] if departures else []
    if ground is not None and any(_in_frame(canvas, x, y) for _, x, y in ground.enemy_bases):
        rows.append("enemy_base")
    rows += ["route"] if any(plan.category != "helicopter" for plan in picture.flight_plans) else []
    rows += ["helicopter_route"] if any(plan.category == "helicopter" for plan in picture.flight_plans) else []
    if ground is not None:
        rows += ["friendly"] if any(_in_frame(canvas, x, y) for x, y in ground.friendlies) else []
        rows += ["jtac"] if any(_in_frame(canvas, x, y) for _, x, y in ground.jtacs) else []
        shown = {
            "friend" if coalition == side else "enemy"
            for coalition, points in ground.axes
            if any(_in_frame(canvas, x, y) for x, y in points)
        }
        rows += [f"axis_{who}" for who in ("friend", "enemy") if who in shown]
        rows += [
            f"line {n}"
            for n, line in enumerate(ground.lines)
            if line.name and any(_in_frame(canvas, x, y) for x, y in line.points)
        ]
    rows += ["qra"] if qra else []
    rows += ["carrier"] if carriers else []
    rows += ["awacs"] if "awacs" in roles else []
    rows += ["tanker"] if roles - {"awacs"} else []
    return [*rows, "bullseye"]


def _key_symbol(
    canvas: MapCanvas,
    row: str,
    centre: tuple[float, float],
    friend: tuple[int, int, int],
    enemy: tuple[int, int, int],
    ground: GroundPicture | None = None,
) -> None:
    """One row's symbol, drawn as the map draws it, in a cell ``px(30)`` wide."""
    px, draw = canvas.px, canvas.draw
    cx, cy = centre
    half = px(11)
    if row.startswith("line ") and ground is not None:
        line = ground.lines[int(row.split()[1])]
        stub = MapLine(line.name, line.colour, line.width, line.dashed, ())
        points = [(cx - px(14), cy), (cx + px(14), cy)]
        if stub.dashed:
            _dashed(canvas, points, (*stub.colour, 255), px(max(2, stub.width)), dash=8)
        else:
            draw.line((*points[0], *points[1]), fill=(*stub.colour, 255), width=px(max(2, stub.width)))
    elif row == "qra":
        canvas.circle(centre, half, _QRA, dashed=True, width=px(2))
    elif row == "helicopter_route":
        _dashed(canvas, [(cx - px(14), cy), (cx + px(14), cy)], (*_HELICOPTER, 255), px(3), dash=8)
    elif row == "enemy_base":
        draw.rectangle((cx - px(7), cy - px(7), cx + px(7), cy + px(7)), fill=(*enemy, 255))
    elif row == "friendly":
        draw.rectangle((cx - px(5), cy - px(5), cx + px(5), cy + px(5)), fill=(*friend, 255))
    elif row == "jtac":
        draw.polygon([(cx, cy - px(10)), (cx - px(10), cy + px(8)), (cx + px(10), cy + px(8))], fill=(*friend, 255))
    elif row.startswith("axis_"):
        colour = friend if row == "axis_friend" else enemy
        _dashed(canvas, [(cx - px(14), cy), (cx + px(14), cy)], (*colour, 255), px(4), dash=8)
    elif row == "objective":
        canvas.circle(centre, half, enemy, dashed=False, width=px(3))
    elif row == "threat":
        _diamond(canvas, centre, px(9), (*enemy, 255))
    elif row in ("engagement", "detection"):
        canvas.circle(centre, half, enemy, dashed=row != "engagement", width=px(2))
    elif row == "departure":
        draw.rectangle((cx - px(7), cy - px(7), cx + px(7), cy + px(7)), fill=(*friend, 255))
    elif row == "route":
        draw.line((cx - px(14), cy, cx + px(14), cy), fill=_ROUTE, width=px(3))
        draw.ellipse((cx - px(5), cy - px(5), cx + px(5), cy + px(5)), fill=BLACK, outline=(255, 255, 255, 255))
    elif row == "carrier":
        draw.polygon([(cx, cy - px(11)), (cx - px(9), cy + px(9)), (cx + px(9), cy + px(9))], fill=(*friend, 255))
    elif row == "awacs":
        canvas.circle(centre, half, friend, dashed=True, width=px(2))
    elif row == "tanker":
        draw.line((cx - px(14), cy, cx + px(14), cy), fill=(*friend, 255), width=px(5))
    else:  # bullseye
        for r in (px(5), px(10)):
            draw.ellipse((cx - r, cy - r, cx + r, cy + r), outline=BLACK, width=px(2))
        draw.line((cx - px(14), cy, cx + px(14), cy), fill=BLACK, width=px(2))
        draw.line((cx, cy - px(14), cx, cy + px(14)), fill=BLACK, width=px(2))


def _draw_key(
    canvas: MapCanvas,
    rows: list[str],
    friend: tuple[int, int, int],
    enemy: tuple[int, int, int],
    ground: GroundPicture | None = None,
    avoid: list[Box] | None = None,
) -> None:
    """The map's key, one symbol and a few words a row, in the corner the fewest symbols and labels stand in.

    Taller than 40 % of the map, it takes two columns: on "Marteau du Golan" a 15-row key took three quarters
    of the overview's height and hid a departure base; on the combat map it covered SA11 and W8, the labels
    still to set being nowhere in the corner's count (FIX-BRIEFING-PARITY-MARTEAU-2 01, 02).
    """
    texts = [
        ground.lines[int(row.split()[1])].name
        if row.startswith("line ") and ground is not None
        else t(f"mission_briefing.key.{row}")
        for row in rows
    ]
    font, px = canvas.small, canvas.px
    line = px(28)
    columns = 2 if px(12) + line * len(rows) > 0.4 * canvas.background.size[1] else 1
    per_column = math.ceil(len(rows) / columns)
    cell = px(16) + px(30) + px(8) + max(canvas.draw.textlength(text, font=font) for text in texts)
    width, height = cell * columns, px(12) + line * per_column
    left, top, right, bottom = canvas.free_corner((width, height), avoid or [])
    canvas.draw.rectangle((left, top, right, bottom), fill=(255, 255, 255, 225), outline=(*BLACK[:3], 120))
    for index, (row, text) in enumerate(zip(rows, texts, strict=True)):
        column, place = divmod(index, per_column)
        x0 = left + column * cell
        cy = top + px(6) + line * place + line / 2
        _key_symbol(canvas, row, (x0 + px(8) + px(15), cy), friend, enemy, ground)
        canvas.draw.text((x0 + px(8) + px(30) + px(8), cy), text, font=font, fill=BLACK, anchor="lm")
        canvas.symbols[f"key {row}"] = (x0 + px(23), cy)
    canvas.symbols["key"] = ((left + right) / 2, (top + bottom) / 2)


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
    aspect: float | None = None,
    width: int | None = None,
    combat_area: bool = False,
    rotation: float | None = None,
    ground: GroundPicture | None = None,
) -> TacticalMapReport:
    """Render the mission's overview, framed on the theatre: the routes, the departures, the objectives, the
    threats, the tankers and the AWACS, the QRA zones' centres, the drawn lines.

    With ``combat_area``, the same map framed on the objectives, the threats and the friendly ground units
    within 30 km of them:
    the fighting takes a quarter of an overview that holds the departures and the tankers
    (FEAT-OBJECTIVE-MISSION-V2 02); its objectives carry their titles, the overview's the flight plan's names.

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
        aspect: The frame's width over its height (a kneeboard page's 2:3); ``None`` frames the content.
        width: The map's width at least, pixels: framed, turned when that holds it tighter, a north arrow.
            ``None`` fits the frame north up in 1400 pixels.
        combat_area: Frame the objectives, the threats and the friendly units at the fight.
        rotation: The turn, degrees anticlockwise (:func:`attack_axis_rotation`); ``None`` lets a framed map
            find the tightest. Needs ``width``.
        ground: The friendly units, JTACs, axes and drawn lines (:func:`ground_picture`); the combat map shows
            them all, the overview the drawn lines.

    Returns:
        Where the map is, and where its symbols and labels went.
    """
    theatre = picture.theatre
    friend, enemy = _sides(side)
    numbers = waypoint_numbers(picture)
    ground = ground or GroundPicture()
    routes = []
    for plan in picture.flight_plans:
        route = [(wp.x, wp.y) for wp in plan.waypoints]
        if departures and route:  # the route leaves from its own departure, or the one nearest its first point
            named = [(x, y) for name, x, y in departures if name == plan.departure]
            route.insert(
                0,
                named[0] if named else min(((x, y) for _, x, y in departures), key=lambda xy: math.dist(xy, route[0])),
            )
        routes.append((plan, route))
    ground = replace(ground, lines=tuple(line for line in ground.lines if not retraces(line, [r for _, r in routes])))
    if combat_area:  # the QRA watch the theatre, not the fight: their arcs only cut the combat map up
        picture = replace(picture, qra_zones=[])
    spots = [(area.x, area.y) for _, area in objectives] + [position for _, position in threats]
    if combat_area and spots:
        # the friendlies at the fight, not a FARP's statics 150 nm away (pr-code-review of #1210)
        fight = list(spots)
        near = [(x, y) for x, y in [*ground.friendlies, *((x, y) for _, x, y in ground.jtacs)] if _near(fight, x, y)]
        spots += near
    else:
        spots += [(c.x, c.y) for c in picture.carriers] + [(x, y) for _, x, y in departures]
        spots += list(numbers) + [picture.bullseye]
        # the theatre, not only the route: where the tankers and the AWACS fly, where the QRA wait, the front
        spots += [point for support in picture.support for point in support.route[:2]]
        spots += [(zone.x, zone.y) for zone in picture.qra_zones]
        spots += [(x, y) for _, x, y in ground.enemy_bases]
        spots += [point for line in ground.lines for point in line.points]
    margin = _COMBAT_MARGIN if combat_area else _OVERVIEW_MARGIN
    points = [xy_to_latlon(theatre, x, y) for x, y in spots]
    if rotation is None or width is None:
        rotation = best_rotation(points, margin, aspect) if width is not None and aspect else 0.0
    canvas = MapCanvas(theatre, points, margin, cache_dir, fetch, source, aspect, width=width, rotation=rotation)

    # every symbol first, so that no label is set on one drawn after it
    # named as the flight plan names them on both maps: the titles were long and ran into one another
    labels = [_objective(canvas, area, enemy, focus=False, fill=_ZONE_FILL) for _, area in objectives]
    labels += [_threat(canvas, threat, position, enemy, fill=_REACH_FILL) for threat, position in threats]
    # after the filled circles: a fill drawn later replaces the overlay's pixels, it does not blend
    for line in ground.lines:
        _drawn_line(canvas, line)
    if combat_area:
        labels += _ground(canvas, ground, side, friend, enemy)
    # the helicopters' dashes first: where both routes share a leg, the planes' line stays whole
    for plan, route in sorted(routes, key=lambda item: item[0].category != "helicopter"):
        pixels = [canvas.at_xy(x, y) for x, y in route]
        if plan.category == "helicopter":
            _dashed(canvas, pixels, (*_HELICOPTER, 255), canvas.px(4))
            continue
        for a, b in zip(pixels, pixels[1:], strict=False):
            canvas.draw.line((*a, *b), fill=_ROUTE, width=canvas.px(3))
    for bases, tint in ((departures, friend), ([] if combat_area else ground.enemy_bases, enemy)):
        for name, x, y in bases:
            dx, dy = canvas.at_xy(x, y)
            half = canvas.px(7)
            canvas.draw.rectangle((dx - half, dy - half, dx + half, dy + half), fill=(*tint, 255))
            labels.append((canvas.mark(name, (dx, dy), half), name, canvas.small, (*tint, 255)))
    labels += draw_mission(canvas, picture, friend, enemy, {}, qra_colour=_QRA)
    labels += _waypoints(canvas, picture, {area.label.lower() for _, area in objectives if area.label})
    canvas.turn()
    bar = _bar(canvas, NM, _NM_BARS)
    canvas.scale(bar * NM, f"{bar} nm")
    shown = replace(ground, enemy_bases=()) if combat_area else replace(ground, friendlies=(), jtacs=(), axes=())
    rows = _key_rows(canvas, picture, objectives, threats, departures, shown, side)
    _draw_key(canvas, rows, friend, enemy, ground, [canvas.turned_box(box) for box, _, _, _ in labels])
    if width is not None:
        canvas.north_arrow()
    for box, text, font, colour in labels:
        canvas.label(box, text, font, colour)
    return canvas.save(out)


def _paste_inset(canvas: MapCanvas, inset: Inset) -> None:
    """The overview, shrunk into the corner the fewest symbols stand in, the zoom's place circled on it."""
    width = canvas.background.size[0] * _INSET_SHARE
    with Image.open(inset.image) as opened:
        scale = width / opened.width
        thumb = opened.convert("RGBA").resize((round(opened.width * scale), round(opened.height * scale)))
    left, top, right, bottom = canvas.free_corner(thumb.size)
    canvas.overlay.paste(thumb, (round(left), round(top)))
    border = canvas.px(2)
    canvas.draw.rectangle((left, top, left + thumb.width, top + thumb.height), outline=BLACK, width=border)
    cx, cy = left + inset.centre[0] * scale, top + inset.centre[1] * scale
    radius = max(inset.radius * scale, canvas.px(6))
    red = (*OWNER_COLOURS["red"], 255)
    canvas.draw.ellipse((cx - radius, cy - radius, cx + radius, cy + radius), outline=red, width=canvas.px(3))
    canvas.symbols["inset"] = ((left + right) / 2, (top + bottom) / 2)


def zoom_half(area: ObjectiveArea) -> float:
    """How far a zoom shows around its zone's centre, metres, before its frame is widened to an aspect."""
    return max(area.radius * _ZOOM_MARGIN, _ZOOM_MIN)


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
    aspect: float | None = None,
    width: int | None = None,
    inset: Inset | None = None,
    rotation: float = 0.0,
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
        aspect: The frame's width over its height (a kneeboard page's 2:3); ``None`` frames the content.
        width: The map's width at least, pixels, every symbol in proportion; ``None`` fits 1400 pixels.
        inset: The overview to show in a corner, the zoom's place marked on it.
        rotation: The turn, degrees anticlockwise; a turned zoom carries a north arrow.

    Returns:
        Where the map is, and where its symbols and labels went.
    """
    _, enemy = _sides(side)
    half = zoom_half(area)
    spots = [(area.x, area.y)] + [(target.x, target.y) for target in area.targets]
    canvas = MapCanvas(
        theatre,
        [xy_to_latlon(theatre, x, y) for x, y in spots],
        half,
        cache_dir,
        fetch,
        source,
        aspect,
        width=width,
        rotation=rotation,
    )
    labels = [_objective(canvas, area, enemy, focus=True)]
    for threat, position in threats:
        x, y = canvas.turned(canvas.at_xy(*position))
        frame_w, frame_h = canvas.frame_size
        if 0 <= x < frame_w and 0 <= y < frame_h:
            # a SAM's reach covers the whole zoom: a tint, or the zoom is pink (FIX-BRIEFING-PARITY-MARTEAU 02)
            labels.append(_threat(canvas, threat, position, enemy, fill=_REACH_FILL))
    for target in area.targets:
        tx, ty = canvas.at_xy(target.x, target.y)
        size = canvas.px(5)
        canvas.draw.rectangle(
            (tx - size, ty - size, tx + size, ty + size), fill=(*enemy, 255), outline=(255, 255, 255, 255)
        )
        labels.append((canvas.mark(f"target {target.name}", (tx, ty), canvas.px(6)), target.name, canvas.small, BLACK))
    canvas.turn()
    bar = _bar(canvas, 1000, _KM_BARS)
    canvas.scale(bar * 1000, f"{bar} km")
    if inset is not None:
        _paste_inset(canvas, inset)
    if rotation:
        canvas.north_arrow()
    for box, text, font, colour in labels:
        canvas.label(box, text, font, colour)
    return canvas.save(out)
