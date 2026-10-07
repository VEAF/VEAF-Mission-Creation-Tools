"""The mission briefing's maps: the tactical situation, and one zoom per objective (ticket 03).

On the OpenStreetMap base of `veaf_libs/map_tiles.py`: the zones in their owner's colour, the axes,
the enemy's QRA zones dashed, the carrier, the AWACS orbit, the tanker track, the bullseye, a scale.
Labels never overlap one another or a symbol (`veaf_libs/map_labels.py`). Nothing the intelligence
does not know is drawn: no garrison unit — a garrison is drawn when the mission starts.
"""

from __future__ import annotations

import math
import re
from dataclasses import dataclass, field
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont
from veaf_libs.coordinates import xy_to_latlon
from veaf_libs.i18n import t
from veaf_libs.map_labels import Box, LabelPlacer
from veaf_libs.map_tiles import CREDIT, BaseMap, Fetch, metres_per_pixel, render_base_map

from campaign_manager.mission_picture import NM, MissionPicture
from campaign_manager.models import CampaignDefinition, CampaignState, CampaignZone
from campaign_manager.strategic_map import OWNER_COLOURS, _dashed, _font, zone_position

#: The tactical map, in the mission's sub-folder (`missions/mission-NN/`).
TACTICAL_MAP_FILE = "carte-tactique.png"

#: How wide the AWACS orbit is drawn, in metres: its first waypoint is where it circles.
_AWACS_ORBIT = 25_000

#: Margin around what the tactical map holds, in metres.
_TACTICAL_MARGIN = 30_000

#: A zoom shows its zone and this much of its radius around it.
_ZOOM_MARGIN = 2.2

_BLACK = (0, 0, 0, 255)


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


def zoom_file(zone: CampaignZone) -> str:
    """The file of an objective's zoom: ``zoom-khobi-depot.png``.

    Args:
        zone: The objective's zone.

    Returns:
        The file name.
    """
    return f"zoom-{re.sub(r'[^a-z0-9]+', '-', zone.name.lower()).strip('-')}.png"


class _Canvas:
    """A base map and the overlay drawn on it, with the labels' placer."""

    def __init__(
        self,
        theatre: str,
        points: list[tuple[float, float]],
        margin: float,
        cache_dir: Path | None,
        fetch: Fetch | None,
    ) -> None:
        lats = [p[0] for p in points]
        lons = [p[1] for p in points]
        dlat = margin / 111_000
        dlon = margin / (111_000 * math.cos(math.radians(sum(lats) / len(lats))))
        self.theatre = theatre
        self.lat = sum(lats) / len(lats)
        self.base: BaseMap = render_base_map(
            max(lats) + dlat, min(lons) - dlon, min(lats) - dlat, max(lons) + dlon, cache_dir=cache_dir, fetch=fetch
        )
        self.background = Image.blend(self.base.image, Image.new("RGB", self.base.image.size, (255, 255, 255)), 0.3)
        self.overlay = Image.new("RGBA", self.background.size, (0, 0, 0, 0))
        self.draw = ImageDraw.Draw(self.overlay)
        self.placer = LabelPlacer(*self.background.size)
        self.symbols: dict[str, tuple[float, float]] = {}
        self.big, self.small = _font(22, bold=True), _font(16)

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
        self.draw.line((x0, y0, x0 + bar, y0), fill=_BLACK, width=4)
        self.draw.text((x0 + bar + 8, y0 - 10), text, font=self.small, fill=_BLACK)
        self.placer.reserve((x0 - 6, y0 - 16, x0 + bar + 80, y0 + 14))
        box = self.draw.textbbox((0, 0), CREDIT, font=self.small)
        at = (width - box[2] - 10, height - box[3] - 8)
        self.draw.rectangle((at[0] - 4, at[1] - 2, at[0] + box[2] + 4, at[1] + box[3] + 2), fill=(255, 255, 255, 220))
        self.draw.text(at, CREDIT, font=self.small, fill=_BLACK)
        self.placer.reserve((at[0] - 4, at[1] - 2, at[0] + box[2] + 4, at[1] + box[3] + 2))

    def save(self, out: Path) -> TacticalMapReport:
        out.parent.mkdir(parents=True, exist_ok=True)
        Image.alpha_composite(self.background.convert("RGBA"), self.overlay).convert("RGB").save(out)
        return TacticalMapReport(out, self.base.offline, dict(self.symbols), list(self.placer.labels))


def _zone(
    canvas: _Canvas, campaign: CampaignDefinition, state: CampaignState, zone: CampaignZone, *, focus: bool
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
    canvas = _Canvas(theatre, points, _TACTICAL_MARGIN, cache_dir, fetch)
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
        canvas.draw.ellipse((bx - r, by - r, bx + r, by + r), outline=_BLACK, width=2)
    canvas.draw.line((bx - 22, by, bx + 22, by), fill=_BLACK, width=2)
    canvas.draw.line((bx, by - 22, bx, by + 22), fill=_BLACK, width=2)
    bullseye_box = canvas.mark("bullseye", (bx, by), 22)
    canvas.scale(20 * NM, "20 nm")

    for zone, box in zone_boxes:
        canvas.label(box, zone.label, canvas.big, (*OWNER_COLOURS[state.zones[zone.name].owner], 255))
    for box in qra_boxes:
        canvas.label(box, t("campaign.mission_deck.map.qra"), canvas.small, (*enemy, 255))
    for carrier, box in carrier_boxes:
        canvas.label(box, carrier.name, canvas.small, (*blue, 255))
    for support, box in support_boxes:
        canvas.label(box, support.callsign, canvas.small, (*blue, 255))
    canvas.label(bullseye_box, "Bullseye", canvas.small, _BLACK)
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
    canvas = _Canvas(campaign.theatre, [zone_position(campaign, zone)], zone.radius * _ZOOM_MARGIN, cache_dir, fetch)
    box = _zone(canvas, campaign, state, zone, focus=True)
    kilometres = 1 if zone.radius < 2000 else 2
    canvas.scale(kilometres * 1000, f"{kilometres} km")
    canvas.label(box, zone.label, canvas.big, (*OWNER_COLOURS[state.zones[zone.name].owner], 255))
    return canvas.save(out)
