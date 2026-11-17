"""The network map of a persistent campaign: the central page of its theatre dossier and of its kneeboard.

Each zone in its owner's colour with one symbol per kind (an airfield a square, an outpost a circle, a factory a
triangle, a depot a diamond), its waypoint number before its name, the connections, the territory tinted by owner
drawn as the F10 map draws it — a faint fill in its nearest zone's colour, the front a thin dark line with
short hatches on each side in that side's colour. Optional reach circles show the long-range air defences.
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

# The territory as the F10 map draws it (`veafCampaign.drawTerritory`, David, 2026-11-17): a faint fill per owner, a
# dark front, and along the front, on each side, short strokes slanted at 45° in that side's colour.

#: The fill's opacity, out of 255 (the F10 map's 0.07, a little stronger over the paler base map).
_FILL_ALPHA = 40

#: The front: its width, pixels, and colour (`veafCampaign.FRONT_COLOR`).
_FRONT_WIDTH, _FRONT_COLOUR = 3, (25, 25, 25, 204)

#: The front's hatches: every so many metres, so long (`territory.hatch_spacing`, `territory.hatch_length`), and
#: their width, pixels; neutral has none (`veafCampaign.HATCH_COLORS`).
_HATCH_SPACING_M, _HATCH_LENGTH_M, _HATCH_WIDTH = 3000, 2500, 2
_HATCH_ALPHA = 230

Point = tuple[float, float]
Cell = list[tuple[Point, str | None]]
"""A territory cell: its corners, each with what lies across the side that starts there (a zone's name, or
``None`` for the picture's edge)."""

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
        draw.polygon(
            [(cx, cy - s - 3), (cx + s + 3, cy), (cx, cy + s + 3), (cx - s - 3, cy)], fill=fill, outline=outline
        )
    else:
        draw.ellipse((cx - s, cy - s, cx + s, cy + s), fill=fill, outline=outline, width=3)


def _clip(cell: Cell, a: Point, b: Point, other: str) -> Cell:
    """Keep the part of a cell nearer to ``a`` than to ``b``; the new side, on the bisector, faces ``other``."""

    def nearer(point: Point) -> float:
        # negative on a's side of the bisector
        return (point[0] - (a[0] + b[0]) / 2) * (b[0] - a[0]) + (point[1] - (a[1] + b[1]) / 2) * (b[1] - a[1])

    def crossing(p: Point, q: Point) -> Point:
        fp, fq = nearer(p), nearer(q)
        ratio = fp / (fp - fq)
        return (p[0] + (q[0] - p[0]) * ratio, p[1] + (q[1] - p[1]) * ratio)

    kept: Cell = []
    for index, (p, side) in enumerate(cell):
        q = cell[(index + 1) % len(cell)][0]
        p_in, q_in = nearer(p) <= 0, nearer(q) <= 0
        if p_in:
            kept.append((p, side))
            if not q_in:
                kept.append((crossing(p, q), other))
        elif q_in:
            kept.append((crossing(p, q), side))
    return kept


def territory_cells(centres: Mapping[str, Point], width: int, height: int) -> dict[str, Cell]:
    """Each zone's territory on the picture: what is nearer to it than to any other zone, as the F10 map tints it.

    Args:
        centres: Each zone's centre, pixels.
        width: The picture's width.
        height: The picture's height.

    Returns:
        Each zone's cell, a convex polygon whose sides say what lies across them.
    """
    frame: Cell = [((0.0, 0.0), None), ((float(width), 0.0), None), ((float(width), float(height)), None)]
    frame.append(((0.0, float(height)), None))
    cells: dict[str, Cell] = {}
    for name, centre in centres.items():
        cell = list(frame)
        for other, point in centres.items():
            if other != name and point != centre and cell:
                cell = _clip(cell, centre, point, other)
        cells[name] = cell
    return cells


def front_segments(cells: Mapping[str, Cell], owners: Mapping[str, str]) -> list[tuple[Point, Point]]:
    """The sides between two cells of different owners: the front, each side once.

    Args:
        cells: The territory cells.
        owners: Each zone's owner.

    Returns:
        The front's segments.
    """
    segments = []
    for name, cell in cells.items():
        for index, (start, other) in enumerate(cell):
            if other is None or other < name or owners.get(other, "neutral") == owners.get(name, "neutral"):
                continue
            end = cell[(index + 1) % len(cell)][0]
            if start != end:
                segments.append((start, end))
    return segments


def front_hatches(start: Point, end: Point, site: Point, *, spacing: float, length: float) -> list[tuple[Point, Point]]:
    """The hatches along one side of the front, as `veafCampaign.frontHatches` draws them on the F10 map.

    Args:
        start: One end of the side.
        end: The other end.
        site: The centre of the cell the hatches go into.
        spacing: The gap between two hatches, pixels.
        length: A hatch's length, pixels.

    Returns:
        The strokes, each slanted at 45° into the cell, the first half a gap from ``start``.
    """
    dx, dy = end[0] - start[0], end[1] - start[1]
    side = (dx * dx + dy * dy) ** 0.5
    if side == 0 or spacing <= 0:
        return []
    dx, dy = dx / side, dy / side
    # the normal to the side, turned towards the cell's own centre
    nx, ny = -dy, dx
    if (site[0] - start[0]) * nx + (site[1] - start[1]) * ny < 0:
        nx, ny = -nx, -ny
    reach = length / 2**0.5
    strokes = []
    along = spacing / 2
    while along <= side:
        base = (start[0] + dx * along, start[1] + dy * along)
        strokes.append((base, (base[0] + (nx + dx) * reach, base[1] + (ny + dy) * reach)))
        along += spacing
    return strokes


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

    # the territory as the F10 map draws it: a faint fill, the front, and its hatches on each side
    cells = territory_cells(centres, width, height)
    fill = Image.new("RGBA", background.size, (0, 0, 0, 0))
    fill_draw = ImageDraw.Draw(fill)
    for name, cell in cells.items():
        if len(cell) >= 3:
            colour = OWNER_COLOURS[owners.get(name, "neutral")]
            fill_draw.polygon([point for point, _ in cell], fill=(*colour, _FILL_ALPHA))
    background = Image.alpha_composite(background, fill)
    metres = metres_per_pixel((north + south) / 2, base.zoom)
    front = Image.new("RGBA", background.size, (0, 0, 0, 0))
    front_draw = ImageDraw.Draw(front)
    for name, cell in cells.items():
        owner = owners.get(name, "neutral")
        if owner == "neutral":
            continue
        for index, (start, other) in enumerate(cell):
            if other is None or owners.get(other, "neutral") == owner:
                continue
            end = cell[(index + 1) % len(cell)][0]
            for stroke in front_hatches(
                start, end, centres[name], spacing=_HATCH_SPACING_M / metres, length=_HATCH_LENGTH_M / metres
            ):
                front_draw.line(stroke, fill=(*OWNER_COLOURS[owner], _HATCH_ALPHA), width=_HATCH_WIDTH)
    for start, end in front_segments(cells, owners):
        front_draw.line((start, end), fill=_FRONT_COLOUR, width=_FRONT_WIDTH)
    background = Image.alpha_composite(background, front)

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
