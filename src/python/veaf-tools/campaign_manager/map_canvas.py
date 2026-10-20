"""A briefing map: an OpenStreetMap background, its overlay and its labels (FEAT-MCP-MISSION-BRIEFING ticket 01).

Taken out of `tactical_map.py` so that a one-shot mission's maps (`mission_briefing/`) draw on the same
canvas as a campaign mission's: labels never overlap one another or a symbol (`veaf_libs/map_labels.py`),
the scale and the tiles' credit sit at the bottom.
"""

from __future__ import annotations

import math
from dataclasses import dataclass, field
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont
from veaf_libs.coordinates import xy_to_latlon
from veaf_libs.i18n import t
from veaf_libs.map_labels import Box, LabelPlacer
from veaf_libs.map_tiles import OSM, BaseMap, Fetch, TileSource, metres_per_pixel, render_base_map

from campaign_manager.mission_picture import MissionPicture
from campaign_manager.strategic_map import _font

BLACK = (0, 0, 0, 255)

#: How wide the AWACS orbit is drawn, in metres: its first waypoint is where it circles.
_AWACS_ORBIT = 25_000

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
    ) -> None:
        lats = [p[0] for p in points]
        lons = [p[1] for p in points]
        dlat = margin / 111_000
        dlon = margin / (111_000 * math.cos(math.radians(sum(lats) / len(lats))))
        self.theatre = theatre
        self.lat = sum(lats) / len(lats)
        self.base: BaseMap = render_base_map(
            max(lats) + dlat,
            min(lons) - dlon,
            min(lats) - dlat,
            max(lons) + dlon,
            cache_dir=cache_dir,
            fetch=fetch,
            source=source,
        )
        self.background = Image.blend(self.base.image, Image.new("RGB", self.base.image.size, (255, 255, 255)), 0.3)
        self.overlay = Image.new("RGBA", self.background.size, (0, 0, 0, 0))
        self.draw = ImageDraw.Draw(self.overlay)
        self.placer = LabelPlacer(*self.background.size)
        self.symbols: dict[str, tuple[float, float]] = {}
        self.big, self.small, self.number = _font(22, bold=True), _font(16), _font(18, bold=True)

    def at(self, lat: float, lon: float) -> tuple[float, float]:
        return self.base.pixel(lat, lon)

    def at_xy(self, x: float, y: float) -> tuple[float, float]:
        return self.base.pixel(*xy_to_latlon(self.theatre, x, y))

    def pixels(self, metres: float) -> float:
        return metres / metres_per_pixel(self.lat, self.base.zoom)

    def label(
        self, anchor: Box, text: str, font: ImageFont.FreeTypeFont | ImageFont.ImageFont, colour: tuple[int, ...]
    ) -> None:
        left, top, right, bottom = self.draw.textbbox((0, 0), text, font=font)
        x, y = self.placer.place(anchor, (right - left + 8, bottom - top + 4))
        self.draw.rectangle((x, y, x + right - left + 8, y + bottom - top + 4), fill=(255, 255, 255, 220))
        self.draw.text((x + 4 - left, y + 2 - top), text, font=font, fill=colour)

    def mark(self, name: str, centre: tuple[float, float], half: float) -> Box:
        """Record a symbol's place, keep it clear of labels, and return its box."""
        self.symbols[name] = centre
        box = (centre[0] - half, centre[1] - half, centre[0] + half, centre[1] + half)
        self.placer.reserve(box)
        return box

    def circle(
        self, centre: tuple[float, float], radius: float, colour: tuple[int, int, int], *, dashed: bool, width: int = 3
    ) -> None:
        cx, cy = centre
        if not dashed:
            self.draw.ellipse(
                (cx - radius, cy - radius, cx + radius, cy + radius),
                fill=(*colour, 70),
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
        x0, y0 = 20, height - 40
        self.draw.rectangle((x0 - 6, y0 - 16, x0 + bar + 80, y0 + 14), fill=(255, 255, 255, 220))
        self.draw.line((x0, y0, x0 + bar, y0), fill=BLACK, width=4)
        self.draw.text((x0 + bar + 8, y0 - 10), text, font=self.small, fill=BLACK)
        self.placer.reserve((x0 - 6, y0 - 16, x0 + bar + 80, y0 + 14))
        box = self.draw.textbbox((0, 0), self.base.credit, font=self.small)
        at = (width - box[2] - 10, height - box[3] - 8)
        self.draw.rectangle((at[0] - 4, at[1] - 2, at[0] + box[2] + 4, at[1] + box[3] + 2), fill=(255, 255, 255, 220))
        self.draw.text(at, self.base.credit, font=self.small, fill=BLACK)
        self.placer.reserve((at[0] - 4, at[1] - 2, at[0] + box[2] + 4, at[1] + box[3] + 2))

    def save(self, out: Path) -> TacticalMapReport:
        out.parent.mkdir(parents=True, exist_ok=True)
        Image.alpha_composite(self.background.convert("RGBA"), self.overlay).convert("RGB").save(out)
        return TacticalMapReport(out, self.base.offline, dict(self.symbols), list(self.placer.labels))


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
) -> list[Label]:
    """Draw what the built mission holds — QRA zones, carriers, support, bullseye, numbered waypoints.

    Args:
        canvas: The map.
        picture: What the built mission says.
        friend: The players' colour.
        enemy: The enemy's colour.
        numbers: :func:`waypoint_numbers` of the picture.

    Returns:
        Their labels, to set once every symbol of the map is drawn.
    """
    labels: list[Label] = []
    for qra in picture.qra_zones:
        centre = canvas.at_xy(qra.x, qra.y)
        radius = canvas.pixels(qra.radius)
        canvas.circle(centre, radius, enemy, dashed=True)
        # labelled on its rim, at the north-west, clear of the zones inside it
        rim = (centre[0] - 0.707 * radius, centre[1] - 0.707 * radius)
        labels.append(
            (
                (rim[0] - 2, rim[1] - 2, rim[0] + 2, rim[1] + 2),
                t("campaign.mission_deck.map.qra"),
                canvas.small,
                (*enemy, 255),
            )
        )
    carriers: list[Label] = []
    for carrier in picture.carriers:
        cx, cy = canvas.at_xy(carrier.x, carrier.y)
        canvas.draw.polygon([(cx, cy - 12), (cx - 9, cy + 9), (cx + 9, cy + 9)], fill=(*friend, 255))
        carriers.append((canvas.mark("carrier", (cx, cy), 12), carrier.name, canvas.small, (*friend, 255)))
    labels += carriers
    for support in picture.support:
        if not support.route:
            continue
        start = canvas.at_xy(*support.route[0])
        if support.role == "awacs":
            canvas.circle(start, canvas.pixels(_AWACS_ORBIT), friend, dashed=True)
        elif len(support.route) > 1:
            canvas.draw.line((*start, *canvas.at_xy(*support.route[1])), fill=(*friend, 255), width=5)
        canvas.draw.ellipse((start[0] - 5, start[1] - 5, start[0] + 5, start[1] + 5), fill=(*friend, 255))
        labels.append((canvas.mark(support.callsign, start, 6), support.callsign, canvas.small, (*friend, 255)))
    bx, by = canvas.at_xy(*picture.bullseye)
    for r in (8, 16):
        canvas.draw.ellipse((bx - r, by - r, bx + r, by + r), outline=BLACK, width=2)
    canvas.draw.line((bx - 22, by, bx + 22, by), fill=BLACK, width=2)
    canvas.draw.line((bx, by - 22, bx, by + 22), fill=BLACK, width=2)
    labels.append((canvas.mark("bullseye", (bx, by), 22), "Bullseye", canvas.small, BLACK))
    for (x, y), listed in numbers.items():
        wx, wy = canvas.at_xy(x, y)
        if (x, y) != picture.bullseye:  # the bullseye has its own symbol
            canvas.draw.ellipse((wx - 5, wy - 5, wx + 5, wy + 5), fill=BLACK, outline=(255, 255, 255, 255), width=2)
        text = "/".join(listed)
        labels.append((canvas.mark(f"waypoint {text}", (wx, wy), 6), text, canvas.number, BLACK))
    return labels
