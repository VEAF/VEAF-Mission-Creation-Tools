"""The network map of a persistent campaign: the central page of its theatre dossier and of its kneeboard.

Each zone in its owner's colour with one symbol per kind (an airfield a square, an outpost a circle, a factory a
triangle, a depot a diamond), its waypoint number before its name, the connections, the territory tinted by owner
— each point of the map in the colour of its nearest zone, as the F10 map tints it — and the front between two
colours. Optional reach circles show the long-range air defences.
"""

from __future__ import annotations

import math
from collections.abc import Mapping, Sequence
from dataclasses import dataclass
from pathlib import Path

from PIL import Image, ImageDraw
from veaf_libs.map_labels import Box, LabelPlacer
from veaf_libs.map_tiles import CREDIT, Fetch, metres_per_pixel, render_base_map

from campaign_manager.models import CampaignDefinition, CampaignZone
from campaign_manager.strategic_map import OWNER_COLOURS, MapReport, _boxed_text, _dashed, _font, zone_position

#: Degrees of margin around the zones.
_MARGIN_LAT, _MARGIN_LON = 0.2, 0.3

#: The side of a cell of the territory tint, pixels.
_CELL = 6

#: The symbol's half size, pixels.
_SYMBOL = 13

_SCALE_KM = 20


@dataclass(frozen=True)
class ReachCircle:
    """A long-range air defence's reach, drawn as an outline."""

    lat: float
    lon: float
    radius_m: float
    colour: tuple[int, int, int]
    label: str


def kind_of(zone: CampaignZone) -> str:
    """``airfield``, ``factory``, ``depot`` or ``outpost``: what the symbol shows."""
    if zone.kind in ("factory", "depot"):
        return str(zone.kind)
    return "airfield" if zone.location.airfield else "outpost"


def _symbol(draw: ImageDraw.ImageDraw, kind: str, cx: float, cy: float, colour: tuple[int, int, int]) -> None:
    s = _SYMBOL
    fill, outline = (*colour, 255), (255, 255, 255, 255)
    if kind == "airfield":
        draw.rectangle((cx - s, cy - s, cx + s, cy + s), fill=fill, outline=outline, width=3)
    elif kind == "factory":
        draw.polygon([(cx, cy - s - 3), (cx + s + 3, cy + s), (cx - s - 3, cy + s)], fill=fill, outline=outline)
    elif kind == "depot":
        draw.polygon([(cx, cy - s - 3), (cx + s + 3, cy), (cx, cy + s + 3), (cx - s - 3, cy)], fill=fill, outline=outline)
    else:
        draw.ellipse((cx - s, cy - s, cx + s, cy + s), fill=fill, outline=outline, width=3)


def _box(points: Sequence[tuple[float, float]], aspect: float | None) -> tuple[float, float, float, float]:
    """North, west, south, east around the points, widened to an aspect (width over height) when given."""
    lats = [lat for lat, _ in points]
    lons = [lon for _, lon in points]
    north, south = max(lats) + _MARGIN_LAT, min(lats) - _MARGIN_LAT
    west, east = min(lons) - _MARGIN_LON, max(lons) + _MARGIN_LON
    if aspect:
        scale = math.cos(math.radians((north + south) / 2))
        width, height = (east - west) * scale, north - south
        if width / height < aspect:
            grow = (height * aspect - width) / scale / 2
            west, east = west - grow, east + grow
        else:
            grow = (width / aspect - height) / 2
            north, south = north + grow, south - grow
    return north, west, south, east


def render_network_map(
    campaign: CampaignDefinition,
    owners: Mapping[str, str],
    out: Path,
    *,
    numbers: Mapping[str, int] | None = None,
    circles: Sequence[ReachCircle] = (),
    aspect: float | None = None,
    cache_dir: Path | None = None,
    fetch: Fetch | None = None,
) -> MapReport:
    """Render the network map to a PNG.

    Args:
        campaign: The validated campaign.
        owners: Each zone's owner.
        out: Where the PNG is written.
        numbers: Each zone's waypoint number, shown before its name.
        circles: Reach circles to draw.
        aspect: The picture's width over height (a kneeboard page's 2:3), or ``None`` to fit the zones.
        cache_dir: Where map tiles are kept between runs.
        fetch: How a tile is downloaded (tests pass their own).

    Returns:
        Where the map is, and whether it had to do without tiles.
    """
    numbers = numbers or {}
    points = {zone.name: zone_position(campaign, zone) for zone in campaign.zones}
    north, west, south, east = _box(list(points.values()), aspect)
    base = render_base_map(north, west, south, east, cache_dir=cache_dir, fetch=fetch)
    background = Image.blend(base.image, Image.new("RGB", base.image.size, (255, 255, 255)), 0.4).convert("RGBA")
    width, height = background.size
    centres = {name: base.pixel(*points[name]) for name in points}

    # the territory: each cell in its nearest zone's colour, a dark edge where two owners meet
    columns, rows = width // _CELL + 1, height // _CELL + 1
    nearest: list[list[str]] = []
    for row in range(rows):
        line = []
        for column in range(columns):
            x, y = column * _CELL + _CELL / 2, row * _CELL + _CELL / 2
            line.append(min(centres, key=lambda name: (centres[name][0] - x) ** 2 + (centres[name][1] - y) ** 2))
        nearest.append(line)
    tint = Image.new("RGBA", background.size, (0, 0, 0, 0))
    tint_draw = ImageDraw.Draw(tint)
    for row in range(rows):
        for column in range(columns):
            owner = owners.get(nearest[row][column], "neutral")
            box = (column * _CELL, row * _CELL, column * _CELL + _CELL, row * _CELL + _CELL)
            tint_draw.rectangle(box, fill=(*OWNER_COLOURS[owner], 40))
            right = column + 1 < columns and owners.get(nearest[row][column + 1], "neutral") != owner
            below = row + 1 < rows and owners.get(nearest[row + 1][column], "neutral") != owner
            if right or below:
                tint_draw.rectangle(box, fill=(30, 30, 30, 150))
    background = Image.alpha_composite(background, tint)

    overlay = Image.new("RGBA", background.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    label_font, small_font = _font(22, bold=True), _font(16)
    for circle in circles:
        cx, cy = base.pixel(circle.lat, circle.lon)
        radius = circle.radius_m / metres_per_pixel(circle.lat, base.zoom)
        draw.ellipse((cx - radius, cy - radius, cx + radius, cy + radius), outline=(*circle.colour, 230), width=4)
        _boxed_text(draw, (cx - 40, cy - radius - 26), circle.label, small_font, (*circle.colour, 255))
    for a, b in campaign.connections:
        _dashed(draw, centres[a], centres[b])

    bar = _SCALE_KM * 1000 / metres_per_pixel((north + south) / 2, base.zoom)
    x, y = 20, height - 50
    credit_box = draw.textbbox((0, 0), CREDIT, font=small_font)
    placer = LabelPlacer(width, height)
    placer.reserve((x - 6, y - 26, x + bar + 60, y + 14))
    placer.reserve((width - credit_box[2] - 14, height - credit_box[3] - 10, width, height))
    symbols: dict[str, Box] = {}
    for zone in campaign.zones:
        cx, cy = centres[zone.name]
        symbols[zone.name] = (cx - _SYMBOL - 4, cy - _SYMBOL - 4, cx + _SYMBOL + 4, cy + _SYMBOL + 4)
        placer.reserve(symbols[zone.name])
    labels: list[Box] = []
    for zone in campaign.zones:
        colour = OWNER_COLOURS[owners.get(zone.name, "neutral")]
        _symbol(draw, kind_of(zone), *centres[zone.name], colour)
        text = f"{numbers[zone.name]} {zone.label}" if zone.name in numbers else zone.label
        bbox = draw.textbbox((0, 0), text, font=label_font)
        size = (bbox[2] - bbox[0] + 8, bbox[3] - bbox[1] + 4)
        left, top = placer.place(symbols[zone.name], size)
        _boxed_text(draw, (left + 4 - bbox[0], top + 2 - bbox[1]), text, label_font, (*colour, 255))
        labels.append((left, top, left + size[0], top + size[1]))

    draw.rectangle((x - 6, y - 26, x + bar + 60, y + 14), fill=(255, 255, 255, 220))
    draw.line((x, y, x + bar, y), fill=(0, 0, 0, 255), width=4)
    draw.text((x + bar + 8, y - 10), f"{_SCALE_KM} km", font=small_font, fill=(0, 0, 0, 255))
    draw.text((x, y - 26), f"≈ {_SCALE_KM / 1.852:.0f} nm", font=small_font, fill=(0, 0, 0, 255))
    _boxed_text(draw, (width - credit_box[2] - 10, height - credit_box[3] - 8), CREDIT, small_font, (0, 0, 0, 255))

    out.parent.mkdir(parents=True, exist_ok=True)
    Image.alpha_composite(background, overlay).convert("RGB").save(out)
    return MapReport(path=out, offline=base.offline, labels=labels)
