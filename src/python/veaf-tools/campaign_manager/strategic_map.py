"""The campaign's strategic map (FEAT-CAMPAIGN-BRIEFING-DECK ticket 01).

Each zone as a circle at its radius in its owner's colour, its name as the players read it, the axes
between zones, a scale in kilometres and nautical miles, the OpenStreetMap credit. Positions come from
`campaign.yaml` and, for airfields, from the airbase positions shipped with the tools.
"""

from __future__ import annotations

import math
from dataclasses import dataclass
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont
from veaf_libs.dcs_airdromes import airfields_for_theatre
from veaf_libs.map_tiles import CREDIT, Fetch, metres_per_pixel, render_base_map

from campaign_manager.models import CampaignDefinition, CampaignState, CampaignZone

#: Each owner's colour, as the F10 map shows them.
OWNER_COLOURS: dict[str, tuple[int, int, int]] = {
    "blue": (31, 95, 191),
    "red": (192, 57, 43),
    "neutral": (110, 110, 110),
}

#: Degrees of margin around the zones, so that no circle or label touches the edge.
_MARGIN_LAT, _MARGIN_LON = 0.16, 0.25

#: The scale bar's length.
_SCALE_KM = 20


@dataclass(frozen=True)
class MapReport:
    """What rendering the map produced."""

    path: Path
    offline: bool
    """Whether tiles were missing and the zones stand on a plain background."""


def zone_position(campaign: CampaignDefinition, zone: CampaignZone) -> tuple[float, float]:
    """The latitude and longitude of a zone's centre.

    Args:
        campaign: The validated campaign, for its theatre.
        zone: One of its zones.

    Returns:
        ``(lat, lon)``.

    Raises:
        KeyError: The zone's airfield has no known position on the theatre.
    """
    if zone.location.airfield is None:
        assert zone.location.lat is not None and zone.location.lon is not None
        return zone.location.lat, zone.location.lon
    for airfield in airfields_for_theatre(campaign.theatre):
        if airfield["name"] == zone.location.airfield:
            return float(airfield["lat"]), float(airfield["lon"])
    raise KeyError(zone.location.airfield)


def _font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    """Calibri when the system has it, a free font otherwise, Pillow's own at the last."""
    for name in ("calibrib.ttf", "DejaVuSans-Bold.ttf") if bold else ("calibri.ttf", "DejaVuSans.ttf"):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            continue
    return ImageFont.load_default(size)


def _dashed(draw: ImageDraw.ImageDraw, a: tuple[float, float], b: tuple[float, float]) -> None:
    """A dashed line, 12-pixel dashes."""
    steps = max(int(math.dist(a, b) // 12), 1)
    for i in range(0, steps, 2):
        s, e = i / steps, min((i + 1) / steps, 1.0)
        draw.line(
            [
                (a[0] + (b[0] - a[0]) * s, a[1] + (b[1] - a[1]) * s),
                (a[0] + (b[0] - a[0]) * e, a[1] + (b[1] - a[1]) * e),
            ],
            fill=(40, 40, 40, 200),
            width=3,
        )


def _boxed_text(
    draw: ImageDraw.ImageDraw, at: tuple[float, float], text: str, font: object, colour: tuple[int, ...]
) -> None:
    """Text on a white box, readable over any background."""
    box = draw.textbbox(at, text, font=font)  # type: ignore[arg-type]
    draw.rectangle((box[0] - 4, box[1] - 2, box[2] + 4, box[3] + 2), fill=(255, 255, 255, 220))
    draw.text(at, text, font=font, fill=colour)  # type: ignore[arg-type]


def render_strategic_map(
    campaign: CampaignDefinition,
    state: CampaignState,
    out: Path,
    *,
    cache_dir: Path | None = None,
    fetch: Fetch | None = None,
) -> MapReport:
    """Render the strategic map of the campaign as the state leaves it, to a PNG.

    Args:
        campaign: The validated campaign.
        state: The campaign state the coming mission starts from.
        out: Where the PNG is written.
        cache_dir: Where map tiles are kept between runs.
        fetch: How a tile is downloaded (tests pass their own).

    Returns:
        Where the map is, and whether it had to do without tiles.
    """
    points = {zone.name: zone_position(campaign, zone) for zone in campaign.zones}
    lats = [lat for lat, _ in points.values()]
    lons = [lon for _, lon in points.values()]
    base = render_base_map(
        max(lats) + _MARGIN_LAT,
        min(lons) - _MARGIN_LON,
        min(lats) - _MARGIN_LAT,
        max(lons) + _MARGIN_LON,
        cache_dir=cache_dir,
        fetch=fetch,
    )
    # washed out, so the zones stand out from the map
    background = Image.blend(base.image, Image.new("RGB", base.image.size, (255, 255, 255)), 0.35)
    overlay = Image.new("RGBA", background.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    label_font, small_font = _font(22, bold=True), _font(16)

    for a, b in campaign.connections:
        _dashed(draw, base.pixel(*points[a]), base.pixel(*points[b]))
    for zone in campaign.zones:
        lat, lon = points[zone.name]
        cx, cy = base.pixel(lat, lon)
        radius = zone.radius / metres_per_pixel(lat, base.zoom)
        colour = OWNER_COLOURS[state.zones[zone.name].owner]
        draw.ellipse(
            (cx - radius, cy - radius, cx + radius, cy + radius), fill=(*colour, 90), outline=(*colour, 255), width=3
        )
        _boxed_text(draw, (cx + radius + 6, cy - 12), zone.label, label_font, (*colour, 255))

    width, height = background.size
    bar = _SCALE_KM * 1000 / metres_per_pixel(sum(lats) / len(lats), base.zoom)
    x, y = 20, height - 50
    draw.rectangle((x - 6, y - 26, x + bar + 60, y + 14), fill=(255, 255, 255, 220))
    draw.line((x, y, x + bar, y), fill=(0, 0, 0, 255), width=4)
    draw.text((x + bar + 8, y - 10), f"{_SCALE_KM} km", font=small_font, fill=(0, 0, 0, 255))
    draw.text((x, y - 26), f"≈ {_SCALE_KM / 1.852:.0f} nm", font=small_font, fill=(0, 0, 0, 255))
    credit_box = draw.textbbox((0, 0), CREDIT, font=small_font)
    _boxed_text(draw, (width - credit_box[2] - 10, height - credit_box[3] - 8), CREDIT, small_font, (0, 0, 0, 255))

    out.parent.mkdir(parents=True, exist_ok=True)
    Image.alpha_composite(background.convert("RGBA"), overlay).convert("RGB").save(out)
    return MapReport(path=out, offline=base.offline)
