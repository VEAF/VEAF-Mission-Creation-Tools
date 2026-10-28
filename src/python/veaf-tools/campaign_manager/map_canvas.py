"""A briefing map: an OpenStreetMap background, its overlay and its labels (FEAT-MCP-MISSION-BRIEFING ticket 01).

Taken out of `tactical_map.py` so that a one-shot mission's maps (`mission_briefing/`) draw on the same
canvas as a campaign mission's: labels never overlap one another or a symbol (`veaf_libs/map_labels.py`),
the scale and the tiles' credit sit at the bottom.

A canvas given a ``width`` is a **framed** one (FEAT-OBJECTIVE-BRIEFING-QUALITY 02): the frame is at least
that many pixels wide, every symbol and font grows with it, and it may be turned so that what it holds fits
tighter — the symbols are drawn north up, then :meth:`MapCanvas.turn` turns the picture, and the labels,
set afterwards, stay level. A turned map carries a north arrow.
"""

from __future__ import annotations

import math
from collections.abc import Callable
from dataclasses import dataclass, field
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont
from veaf_libs.coordinates import xy_to_latlon
from veaf_libs.i18n import t
from veaf_libs.map_labels import Box, LabelPlacer
from veaf_libs.map_tiles import OSM, PLAIN, BaseMap, Fetch, TileSource, metres_per_pixel, render_base_map

from campaign_manager.mission_picture import MissionPicture
from campaign_manager.strategic_map import _font

BLACK = (0, 0, 0, 255)

#: How wide the AWACS orbit is drawn, in metres: its first waypoint is where it circles.
_AWACS_ORBIT = 25_000

#: The frame width the symbols' sizes are written for: a framed map wider than this draws them larger.
_REFERENCE_WIDTH = 1000

#: The highest tile zoom a framed map asks for: a closer one only multiplies the downloads.
_MAX_ZOOM = 15

#: Metres per degree of latitude, for the flat frame a canvas is planned in.
_DEGREE = 111_000

#: A label to set once every symbol is drawn: what it names, its text, its font, its colour.
Label = tuple[Box, str, ImageFont.FreeTypeFont | ImageFont.ImageFont, tuple[int, ...]]


@dataclass(frozen=True)
class TacticalMapReport:
    """What rendering a map produced."""

    path: Path
    offline: bool
    """Whether tiles were missing and the map stands on a plain background."""
    symbols: dict[str, tuple[float, float]] = field(default_factory=dict)
    """Where each thing named was drawn, in pixels: zones by name, ``carrier``, ``bullseye``…"""
    labels: list[Box] = field(default_factory=list)
    """Every label's box, in pixels."""
    metres_per_pixel: float = 0.0
    """The ground one pixel of the map covers."""
    locate: Callable[[float, float], tuple[float, float]] | None = field(default=None, compare=False, repr=False)
    """The pixel of a mission point ``(x, y)`` on the saved map."""


def _flat(points: list[tuple[float, float]]) -> tuple[float, float, Callable[..., tuple[float, float]]]:
    """The centre of ``(lat, lon)`` points, and the inverse of the flat projection about it (metres east, north)."""
    lat0 = sum(p[0] for p in points) / len(points)
    lon0 = sum(p[1] for p in points) / len(points)
    cos_lat = math.cos(math.radians(lat0))

    def back(x: float, y: float) -> tuple[float, float]:
        return lat0 + y / _DEGREE, lon0 + x / (_DEGREE * cos_lat)

    return lat0, lon0, back


def _rotated(points: list[tuple[float, float]], degrees: float) -> list[tuple[float, float]]:
    """``(lat, lon)`` points in metres east and north of their centre, turned anticlockwise by ``degrees``."""
    lat0, lon0, _ = _flat(points)
    cos_lat = math.cos(math.radians(lat0))
    cos, sin = math.cos(math.radians(degrees)), math.sin(math.radians(degrees))
    out = []
    for lat, lon in points:
        x, y = (lon - lon0) * _DEGREE * cos_lat, (lat - lat0) * _DEGREE
        out.append((x * cos - y * sin, x * sin + y * cos))
    return out


def _frame_size(points: list[tuple[float, float]], margin: float, aspect: float | None) -> tuple[float, float]:
    """The width and height, metres, of the frame holding flat points with ``margin`` around, at ``aspect``."""
    xs, ys = [p[0] for p in points], [p[1] for p in points]
    width, height = max(xs) - min(xs) + 2 * margin, max(ys) - min(ys) + 2 * margin
    if aspect:
        width, height = max(width, height * aspect), max(height, width / aspect)
    return width, height


def best_rotation(
    points: list[tuple[float, float]], margin: float, aspect: float, *, keep_north: float = 0.85
) -> float:
    """The turn, degrees anticlockwise, that holds the points in the smallest frame of that aspect.

    A route that runs from south-west to north-east fills a 2:1 frame badly north up: turned, the same
    frame shows it larger. North up is kept unless a turn shrinks the frame below ``keep_north`` of its area.

    Args:
        points: The ``(lat, lon)`` points the frame must hold.
        margin: Metres around them.
        aspect: The frame's width over its height.
        keep_north: The share of north-up's area a turn must beat.

    Returns:
        A turn from -90 to 90 degrees, 0 for north up.
    """

    def area(degrees: float) -> float:
        width, height = _frame_size(_rotated(points, degrees), margin, aspect)
        return width * height

    best = min(range(-90, 91, 5), key=lambda degrees: (area(degrees), abs(degrees)))
    return 0.0 if area(best) >= keep_north * area(0) else float(best)


class MapCanvas:
    """A base map and the overlay drawn on it, with the labels' placer."""

    def __init__(
        self,
        theatre: str,
        points: list[tuple[float, float]],
        margin: float,
        cache_dir: Path | None,
        fetch: Fetch | None,
        source: TileSource = OSM,
        aspect: float | None = None,
        *,
        width: int | None = None,
        rotation: float = 0.0,
    ) -> None:
        self.theatre = theatre
        self.rotation = rotation
        self.k = 1.0
        """How much larger than at :data:`_REFERENCE_WIDTH` the symbols and fonts are drawn."""
        self._frame: tuple[float, float, int, int] | None = None
        """A framed canvas's frame: its centre on the background, its width and height, pixels."""
        self._turned = False
        self._reserved: list[Box] = []
        self._corners: list[Box] = []
        if width is None and not rotation:
            self.lat, self.base = self._fitted(points, margin, aspect, cache_dir, fetch, source)
        else:
            self.lat, self.base = self._framed(points, margin, aspect, width, cache_dir, fetch, source)
        self.background = Image.blend(self.base.image, Image.new("RGB", self.base.image.size, (255, 255, 255)), 0.3)
        self.overlay = Image.new("RGBA", self.background.size, (0, 0, 0, 0))
        self.draw = ImageDraw.Draw(self.overlay)
        self.placer = LabelPlacer(*self.background.size)
        self.symbols: dict[str, tuple[float, float]] = {}
        self.big, self.small, self.number = (
            _font(self.px(22), bold=True),
            _font(self.px(16)),
            _font(self.px(18), bold=True),
        )

    def _fitted(
        self,
        points: list[tuple[float, float]],
        margin: float,
        aspect: float | None,
        cache_dir: Path | None,
        fetch: Fetch | None,
        source: TileSource,
    ) -> tuple[float, BaseMap]:
        """The background of the box holding the points, north up, at the zoom that fits 1400 pixels."""
        lats = [p[0] for p in points]
        lons = [p[1] for p in points]
        cos_lat = math.cos(math.radians(sum(lats) / len(lats)))
        dlat = margin / _DEGREE
        dlon = margin / (_DEGREE * cos_lat)
        north, south = max(lats) + dlat, min(lats) - dlat
        west, east = min(lons) - dlon, max(lons) + dlon
        if aspect:
            # widen the short side so the frame is `aspect` wide for 1 high: a kneeboard page is 2:3
            width, height = (east - west) * cos_lat, north - south
            if width / height < aspect:
                grow = (height * aspect / cos_lat - (east - west)) / 2
                west, east = west - grow, east + grow
            else:
                grow = (width / aspect - height) / 2
                north, south = north + grow, south - grow
        base = render_base_map(north, west, south, east, cache_dir=cache_dir, fetch=fetch, source=source)
        return sum(lats) / len(lats), base

    def _framed(
        self,
        points: list[tuple[float, float]],
        margin: float,
        aspect: float | None,
        width: int | None,
        cache_dir: Path | None,
        fetch: Fetch | None,
        source: TileSource,
    ) -> tuple[float, BaseMap]:
        """The background of a frame turned by :attr:`rotation`, wide enough to cut that frame out of."""
        lat0, _, back = _flat(points)
        turned = _rotated(points, self.rotation)
        frame_w, frame_h = _frame_size(turned, margin, aspect)
        xs, ys = [p[0] for p in turned], [p[1] for p in turned]
        cx, cy = (max(xs) + min(xs)) / 2, (max(ys) + min(ys)) / 2
        cos, sin = math.cos(math.radians(self.rotation)), math.sin(math.radians(self.rotation))

        def unturned(x: float, y: float) -> tuple[float, float]:
            return x * cos + y * sin, -x * sin + y * cos

        corners = [back(*unturned(cx + dx * frame_w / 2, cy + dy * frame_h / 2)) for dx in (-1, 1) for dy in (-1, 1)]
        north, south = max(c[0] for c in corners), min(c[0] for c in corners)
        west, east = min(c[1] for c in corners), max(c[1] for c in corners)
        zoom = None
        if width is not None:
            zoom = next((z for z in range(3, _MAX_ZOOM + 1) if frame_w / metres_per_pixel(lat0, z) >= width), _MAX_ZOOM)
        base = render_base_map(north, west, south, east, cache_dir=cache_dir, fetch=fetch, source=source, zoom=zoom)
        scale = metres_per_pixel(lat0, base.zoom)
        centre = base.pixel(*back(*unturned(cx, cy)))
        self._frame = (centre[0], centre[1], round(frame_w / scale), round(frame_h / scale))
        if width is not None:
            self.k = self._frame[2] / _REFERENCE_WIDTH
        return lat0, base

    @property
    def frame_size(self) -> tuple[int, int]:
        """The saved map's width and height, pixels: the frame's on a framed canvas."""
        return (self._frame[2], self._frame[3]) if self._frame else self.background.size

    def px(self, size: float) -> int:
        """A size written for :data:`_REFERENCE_WIDTH`, in this map's pixels."""
        return max(1, round(size * self.k))

    def at(self, lat: float, lon: float) -> tuple[float, float]:
        return self.base.pixel(lat, lon)

    def at_xy(self, x: float, y: float) -> tuple[float, float]:
        return self.base.pixel(*xy_to_latlon(self.theatre, x, y))

    def pixels(self, metres: float) -> float:
        return metres / metres_per_pixel(self.lat, self.base.zoom)

    def turned(self, point: tuple[float, float]) -> tuple[float, float]:
        """Where a point of the background drawn north up stands on the framed, turned map."""
        if self._frame is None:
            return point
        cx, cy, width, height = self._frame
        cos, sin = math.cos(math.radians(self.rotation)), math.sin(math.radians(self.rotation))
        dx, dy = point[0] - cx, point[1] - cy
        return dx * cos + dy * sin + width / 2, -dx * sin + dy * cos + height / 2

    def _turned_box(self, box: Box) -> Box:
        corners = [self.turned((x, y)) for x in (box[0], box[2]) for y in (box[1], box[3])]
        xs, ys = [c[0] for c in corners], [c[1] for c in corners]
        return (min(xs), min(ys), max(xs), max(ys))

    def turn(self) -> None:
        """Cut the frame out of the background, turned: call it once every symbol is drawn, before the labels.

        Does nothing on a canvas that is not framed. The symbols' places and the boxes kept clear of
        labels move with the picture.
        """
        if self._frame is None or self._turned:
            return
        cx, cy, width, height = self._frame
        whole = Image.alpha_composite(self.background.convert("RGBA"), self.overlay)
        if self.rotation:
            # turned steeply, the frame is longer than the background is wide (a north-south route turned by
            # 70 degrees cut 19 % black, pr-code-review of #1206): turn it on a board that holds the frame
            reach = math.hypot(width, height) / 2
            board_w = math.ceil(2 * max(cx, whole.width - cx, reach))
            board_h = math.ceil(2 * max(cy, whole.height - cy, reach))
            board = Image.new("RGBA", (board_w, board_h), (*PLAIN, 255))
            shift = (round(board_w / 2 - cx), round(board_h / 2 - cy))
            board.paste(whole, shift)
            # the same turn about the same point, moved with the board: `turned` keeps the background's pixels
            cx, cy = cx + shift[0], cy + shift[1]
            whole = board.rotate(
                self.rotation, resample=Image.Resampling.BICUBIC, center=(cx, cy), fillcolor=(*PLAIN, 255)
            )
        left, top = round(cx - width / 2), round(cy - height / 2)
        self.background = whole.crop((left, top, left + width, top + height)).convert("RGB")
        self.overlay = Image.new("RGBA", self.background.size, (0, 0, 0, 0))
        self.draw = ImageDraw.Draw(self.overlay)
        reserved = [self._turned_box(box) for box in self._reserved]
        self.symbols = {name: self.turned(centre) for name, centre in self.symbols.items()}
        self._turned = True
        self.placer = LabelPlacer(*self.background.size)
        self._reserved = []
        for box in reserved:
            self.reserve(box)

    def reserve(self, box: Box) -> None:
        """Keep a box of the map clear of labels."""
        self._reserved.append(box)
        self.placer.reserve(box)

    def free_corner(self, size: tuple[float, float]) -> Box:
        """The corner box of that size the fewest symbols stand in: where a key or an inset goes.

        Args:
            size: Its width and height, pixels.

        Returns:
            The box, ``(left, top, right, bottom)``, kept clear of labels from now on.
        """
        width, height = self.background.size
        gap = self.px(12)
        w, h = size
        corners = [
            (gap, gap, gap + w, gap + h),
            (width - gap - w, gap, width - gap, gap + h),
            (gap, height - gap - h, gap + w, height - gap),
            (width - gap - w, height - gap - h, width - gap, height - gap),
        ]

        def crowding(box: Box) -> int:
            return sum(1 for r in self._reserved if r[0] < box[2] and box[0] < r[2] and r[1] < box[3] and box[1] < r[3])

        # a corner handed out once is never handed out again: the north arrow landed on the key on a tie
        best = min((c for c in corners if c not in self._corners), key=crowding)
        self._corners.append(best)
        self.reserve(best)
        return best

    def label(
        self, anchor: Box, text: str, font: ImageFont.FreeTypeFont | ImageFont.ImageFont, colour: tuple[int, ...]
    ) -> None:
        if self._turned:  # every anchor was taken north up, before the turn
            anchor = self._turned_box(anchor)
            width, height = self.background.size
            if anchor[2] < 0 or anchor[3] < 0 or anchor[0] > width or anchor[1] > height:
                return  # its symbol is out of the frame
        pad_x, pad_y = self.px(8), self.px(4)
        left, top, right, bottom = self.draw.textbbox((0, 0), text, font=font)
        x, y = self.placer.place(anchor, (right - left + pad_x, bottom - top + pad_y))
        self.draw.rectangle((x, y, x + right - left + pad_x, y + bottom - top + pad_y), fill=(255, 255, 255, 220))
        self.draw.text((x + pad_x // 2 - left, y + pad_y // 2 - top), text, font=font, fill=colour)

    def mark(self, name: str, centre: tuple[float, float], half: float) -> Box:
        """Record a symbol's place, keep it clear of labels, and return its box."""
        self.symbols[name] = centre
        box = (centre[0] - half, centre[1] - half, centre[0] + half, centre[1] + half)
        self.reserve(box)
        return box

    def circle(
        self,
        centre: tuple[float, float],
        radius: float,
        colour: tuple[int, int, int],
        *,
        dashed: bool,
        width: int = 3,
        fill: int = 70,
    ) -> None:
        """A circle, plain and filled at ``fill`` opacity (0 to 255), or dashed and empty."""
        cx, cy = centre
        if not dashed:
            self.draw.ellipse(
                (cx - radius, cy - radius, cx + radius, cy + radius),
                fill=(*colour, fill),
                outline=(*colour, 255),
                width=width,
            )
            return
        for step in range(0, 72, 2):
            a0, a1 = math.radians(step * 5), math.radians((step + 1) * 5)
            self.draw.line(
                (
                    cx + radius * math.sin(a0),
                    cy - radius * math.cos(a0),
                    cx + radius * math.sin(a1),
                    cy - radius * math.cos(a1),
                ),
                fill=(*colour, 230),
                width=width,
            )

    def scale(self, metres: float, text: str) -> None:
        width, height = self.background.size
        bar = self.pixels(metres)
        x0, y0 = self.px(20), height - self.px(40)
        box = (x0 - self.px(6), y0 - self.px(16), x0 + bar + self.px(80), y0 + self.px(14))
        self.draw.rectangle(box, fill=(255, 255, 255, 220))
        self.draw.line((x0, y0, x0 + bar, y0), fill=BLACK, width=self.px(4))
        self.draw.text((x0 + bar + self.px(8), y0 - self.px(10)), text, font=self.small, fill=BLACK)
        self.reserve(box)
        credit = self.draw.textbbox((0, 0), self.base.credit, font=self.small)
        at = (width - credit[2] - self.px(10), height - credit[3] - self.px(8))
        credit_box = (
            at[0] - self.px(4),
            at[1] - self.px(2),
            at[0] + credit[2] + self.px(4),
            at[1] + credit[3] + self.px(2),
        )
        self.draw.rectangle(credit_box, fill=(255, 255, 255, 220))
        self.draw.text(at, self.base.credit, font=self.small, fill=BLACK)
        self.reserve(credit_box)

    def north_arrow(self) -> None:
        """An arrow pointing north, with its N, in the corner the fewest symbols stand in."""
        size = self.px(70)
        left, top, right, bottom = self.free_corner((size, size))
        cx, cy = (left + right) / 2, (top + bottom) / 2 + self.px(6)
        angle = math.radians(self.rotation)
        ux, uy = -math.sin(angle), -math.cos(angle)  # north, on the turned picture
        length = self.px(24)
        tip = (cx + ux * length, cy + uy * length)
        tail = (cx - ux * length, cy - uy * length)
        side = (-uy * self.px(9), ux * self.px(9))
        self.draw.ellipse((left, top, right, bottom), fill=(255, 255, 255, 220))
        left_tail, right_tail = (tail[0] + side[0], tail[1] + side[1]), (tail[0] - side[0], tail[1] - side[1])
        self.draw.polygon([tip, left_tail, (cx, cy), right_tail], fill=BLACK)
        letter = (cx + ux * (length + self.px(4)), cy + uy * (length + self.px(4)))
        self.draw.text(letter, "N", font=self.number, fill=BLACK, anchor="mm")
        self.symbols["north"] = (cx, cy)

    def save(self, out: Path) -> TacticalMapReport:
        out.parent.mkdir(parents=True, exist_ok=True)
        Image.alpha_composite(self.background.convert("RGBA"), self.overlay).convert("RGB").save(out)

        def locate(x: float, y: float) -> tuple[float, float]:
            point = self.at_xy(x, y)
            return self.turned(point) if self._turned else point

        return TacticalMapReport(
            out,
            self.base.offline,
            dict(self.symbols),
            list(self.placer.labels),
            metres_per_pixel(self.lat, self.base.zoom),
            locate,
        )


def flight_level(metres: float) -> str:
    """``FL185``: an altitude in metres as a flight level, to the nearest five levels (500 ft)."""
    return f"FL{round(metres / 0.3048 / 500) * 5:03d}"


def waypoint_numbers(picture: MissionPicture) -> dict[tuple[float, float], list[str]]:
    """Where the players' waypoints stand, and the numbers each one carries in the flight plan."""
    numbers: dict[tuple[float, float], list[str]] = {}
    for plan in picture.flight_plans:
        for index, waypoint in enumerate(plan.waypoints, 1):
            listed = numbers.setdefault((waypoint.x, waypoint.y), [])
            if str(index) not in listed:
                listed.append(str(index))
    return numbers


def draw_mission(
    canvas: MapCanvas,
    picture: MissionPicture,
    friend: tuple[int, int, int],
    enemy: tuple[int, int, int],
    numbers: dict[tuple[float, float], list[str]],
    *,
    qra_colour: tuple[int, int, int] | None = None,
) -> list[Label]:
    """Draw what the built mission holds — QRA zones, carriers, support, bullseye, numbered waypoints.

    Args:
        canvas: The map.
        picture: What the built mission says.
        friend: The players' colour.
        enemy: The enemy's colour.
        numbers: :func:`waypoint_numbers` of the picture; empty when the caller labels the waypoints itself.
        qra_colour: The QRA zones' colour, each labelled by its name; the enemy's, labelled "QRA", without it.

    Returns:
        Their labels, to set once every symbol of the map is drawn.
    """
    px = canvas.px
    labels: list[Label] = []
    for qra in picture.qra_zones:
        centre = canvas.at_xy(qra.x, qra.y)
        radius = canvas.pixels(qra.radius)
        colour = qra_colour or enemy
        canvas.circle(centre, radius, colour, dashed=True, width=px(3))
        # labelled on its rim, at the north-west, clear of the zones inside it
        rim = (centre[0] - 0.707 * radius, centre[1] - 0.707 * radius)
        labels.append(
            (
                (rim[0] - 2, rim[1] - 2, rim[0] + 2, rim[1] + 2),
                qra.name if qra_colour else t("campaign.mission_deck.map.qra"),
                canvas.small,
                (*colour, 255),
            )
        )
    carriers: list[Label] = []
    for carrier in picture.carriers:
        cx, cy = canvas.at_xy(carrier.x, carrier.y)
        canvas.draw.polygon(
            [(cx, cy - px(12)), (cx - px(9), cy + px(9)), (cx + px(9), cy + px(9))], fill=(*friend, 255)
        )
        carriers.append((canvas.mark("carrier", (cx, cy), px(12)), carrier.name, canvas.small, (*friend, 255)))
    labels += carriers
    for support in picture.support:
        if not support.route:
            continue
        start = canvas.at_xy(*support.route[0])
        if support.role == "awacs":
            canvas.circle(start, canvas.pixels(_AWACS_ORBIT), friend, dashed=True, width=px(3))
        elif len(support.route) > 1:
            canvas.draw.line((*start, *canvas.at_xy(*support.route[1])), fill=(*friend, 255), width=px(5))
        dot = px(5)
        canvas.draw.ellipse((start[0] - dot, start[1] - dot, start[0] + dot, start[1] + dot), fill=(*friend, 255))
        # a tanker's level beside its callsign: what a receiver climbs to (FIX-BRIEFING-PARITY-MARTEAU-2 01)
        text = f"{support.callsign} {flight_level(support.altitude)}" if support.altitude > 0 else support.callsign
        labels.append((canvas.mark(support.callsign, start, px(6)), text, canvas.small, (*friend, 255)))
    bx, by = canvas.at_xy(*picture.bullseye)
    for r in (px(8), px(16)):
        canvas.draw.ellipse((bx - r, by - r, bx + r, by + r), outline=BLACK, width=px(2))
    canvas.draw.line((bx - px(22), by, bx + px(22), by), fill=BLACK, width=px(2))
    canvas.draw.line((bx, by - px(22), bx, by + px(22)), fill=BLACK, width=px(2))
    labels.append((canvas.mark("bullseye", (bx, by), px(22)), "Bullseye", canvas.small, BLACK))
    for (x, y), listed in numbers.items():
        wx, wy = canvas.at_xy(x, y)
        if (x, y) != picture.bullseye:  # the bullseye has its own symbol
            dot = px(5)
            canvas.draw.ellipse(
                (wx - dot, wy - dot, wx + dot, wy + dot), fill=BLACK, outline=(255, 255, 255, 255), width=px(2)
            )
        text = "/".join(listed)
        labels.append((canvas.mark(f"waypoint {text}", (wx, wy), px(6)), text, canvas.number, BLACK))
    return labels
