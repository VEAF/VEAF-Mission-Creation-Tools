"""A map background from OpenStreetMap tiles, for the pictures the tools draw.

Shared by the campaign's strategic map (FEAT-CAMPAIGN-BRIEFING-DECK ticket 01) and, when it is taken,
a mission's briefing map (FEAT-BRIEFING-MAP ticket 01).

The OpenStreetMap tile usage policy asks for a ``User-Agent`` that identifies the application, tiles
kept in a local cache, and the credit shown on the map. The ``User-Agent`` names the tool by its URL
and carries **nothing else** — no user name, no e-mail address (FEAT-BRIEFING-MAP found one sent by a
mission's own script). Without the network, or with a tile refused, the map still renders, on a plain
background, and says so.
"""

from __future__ import annotations

import io
import math
import os
from collections.abc import Callable
from dataclasses import dataclass
from pathlib import Path

import requests
from PIL import Image, UnidentifiedImageError

#: Identifies the tool to the tile server, and nothing else.
USER_AGENT = "veaf-tools (+https://github.com/VEAF/VEAF-Mission-Creation-Tools)"

#: The standard OpenStreetMap tiles.
TILE_URL = "https://tile.openstreetmap.org/{z}/{x}/{y}.png"

#: The credit the tile policy asks to show on the map.
CREDIT = "© OpenStreetMap contributors"

#: The side of a tile, in pixels.
TILE_SIZE = 256

#: The colour of the background when a tile is missing.
PLAIN = (236, 233, 226)

#: Seconds before a tile download gives up.
_TIMEOUT = 20

#: Gets the bytes at a URL, or ``None`` when it cannot.
Fetch = Callable[[str], bytes | None]


def http_fetch(url: str) -> bytes | None:
    """Download a tile, identified by :data:`USER_AGENT`.

    Args:
        url: The tile's URL.

    Returns:
        The image bytes, or ``None`` when the download fails for any reason.
    """
    try:
        response = requests.get(url, headers={"User-Agent": USER_AGENT}, timeout=_TIMEOUT)
    except requests.RequestException:
        return None
    return response.content if response.ok else None


def default_cache_dir() -> Path:
    """Where tiles are kept between runs: the user's local application data, never the mission."""
    base = os.environ.get("LOCALAPPDATA")
    return (Path(base) if base else Path.home() / ".cache") / "veaf-tools" / "tiles"


def world_pixel(lat: float, lon: float, zoom: int) -> tuple[float, float]:
    """Web Mercator: the pixel of a point in the whole world's image at that zoom."""
    scale = TILE_SIZE * 2**zoom
    x = (lon + 180.0) / 360.0 * scale
    y = (1.0 - math.asinh(math.tan(math.radians(lat))) / math.pi) / 2.0 * scale
    return x, y


def metres_per_pixel(lat: float, zoom: int) -> float:
    """The ground a pixel covers at that latitude and zoom."""
    return 156543.03392 * math.cos(math.radians(lat)) / 2**zoom


def choose_zoom(north: float, west: float, south: float, east: float, max_pixels: int) -> int:
    """The highest zoom at which the box fits in ``max_pixels`` on its longer side."""
    for zoom in range(14, 2, -1):
        x0, y0 = world_pixel(north, west, zoom)
        x1, y1 = world_pixel(south, east, zoom)
        if max(x1 - x0, y1 - y0) <= max_pixels:
            return zoom
    return 3


@dataclass
class BaseMap:
    """A background image and how to place a point on it."""

    image: Image.Image
    zoom: int
    origin: tuple[float, float]
    """The world pixel of the image's top-left corner."""
    offline: bool
    """Whether at least one tile was missing, and the plain background shows instead."""

    def pixel(self, lat: float, lon: float) -> tuple[float, float]:
        """The pixel of a point in this image."""
        x, y = world_pixel(lat, lon, self.zoom)
        return x - self.origin[0], y - self.origin[1]


def _tile(zoom: int, x: int, y: int, cache_dir: Path, fetch: Fetch) -> Image.Image | None:
    """One tile, from the cache or downloaded into it; ``None`` when it cannot be had."""
    path = cache_dir / str(zoom) / str(x) / f"{y}.png"
    if path.is_file():
        data: bytes | None = path.read_bytes()
    else:
        data = fetch(TILE_URL.format(z=zoom, x=x, y=y))
        if data:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(data)
    if not data:
        return None
    try:
        return Image.open(io.BytesIO(data)).convert("RGB")
    except (UnidentifiedImageError, OSError):
        return None


def render_base_map(
    north: float,
    west: float,
    south: float,
    east: float,
    *,
    max_pixels: int = 1400,
    cache_dir: Path | None = None,
    fetch: Fetch | None = None,
) -> BaseMap:
    """Assemble the background of a box from tiles.

    Args:
        north: The box's northern latitude.
        west: Its western longitude.
        south: Its southern latitude.
        east: Its eastern longitude.
        max_pixels: The longer side of the image at most; the zoom is chosen to fit.
        cache_dir: Where tiles are kept; :func:`default_cache_dir` when omitted.
        fetch: How a tile is downloaded; :func:`http_fetch` when omitted.

    Returns:
        The background, cropped to the box.
    """
    zoom = choose_zoom(north, west, south, east, max_pixels)
    cache_dir = cache_dir or default_cache_dir()
    fetch = fetch or http_fetch
    x0, y0 = world_pixel(north, west, zoom)
    x1, y1 = world_pixel(south, east, zoom)
    tx0, ty0, tx1, ty1 = int(x0 // TILE_SIZE), int(y0 // TILE_SIZE), int(x1 // TILE_SIZE), int(y1 // TILE_SIZE)
    canvas = Image.new("RGB", ((tx1 - tx0 + 1) * TILE_SIZE, (ty1 - ty0 + 1) * TILE_SIZE), PLAIN)
    offline = False
    for tx in range(tx0, tx1 + 1):
        for ty in range(ty0, ty1 + 1):
            tile = _tile(zoom, tx, ty, cache_dir, fetch)
            if tile is None:
                offline = True
            else:
                canvas.paste(tile, ((tx - tx0) * TILE_SIZE, (ty - ty0) * TILE_SIZE))
    left, top = x0 - tx0 * TILE_SIZE, y0 - ty0 * TILE_SIZE
    image = canvas.crop((int(left), int(top), int(left + x1 - x0), int(top + y1 - y0)))
    return BaseMap(image=image, zoom=zoom, origin=(int(x0), int(y0)), offline=offline)
