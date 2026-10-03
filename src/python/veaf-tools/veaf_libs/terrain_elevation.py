"""Ground elevation of a DCS theatre, read with no DCS running (FEAT-TERRAIN-ELEVATION).

A briefing's target altitudes, the floor of a low-level route and terrain masking between a route and
a SAM all need the height of the ground, which DCS answers only at runtime (``land.getHeight``). So a
theatre is swept once (:mod:`veaf_libs.terrain_survey`) and the heights are kept here, as data.

**What is stored** is the grid of sampled heights, not anything derived from it: a cell maximum
answers the minimum-altitude question and gives a wrong number for a target's altitude, so the
queries derive what they need on demand, the way the clear-ground catalogue stores probe answers and
derives radii.

**Terrain only.** ``land.getHeight`` ignores buildings, pylons and trees: every figure derived here is
the height of the ground, never an obstacle clearance.

**A point off the grid is not covered**, never 0: sea level is a real answer, and a wrong one inland.
"""

from __future__ import annotations

import itertools
import json
import lzma
import math
import struct
import sys
from array import array
from dataclasses import dataclass
from functools import cache
from pathlib import Path

from veaf_libs.clear_ground_catalogue import GridSpec

#: A cell not swept yet — only ever seen in a sweep in progress, never in a finished grid.
PENDING_HEIGHT = -32768

GRID_FORMAT_VERSION = 1
_GRID_SUFFIX = ".terrain"
#: The file starts with this, then the format version and the length of a small JSON header (theatre,
#: grid), then the heights. Binary, because nothing but this module reads it: base64 in a JSON file
#: cost a third more (9.1 MB against 5.5 MB for Syria at 250 m, measured 2026-10-01).
_MAGIC = b"VEAFTERR"
_PREAMBLE = struct.Struct("<8sHI")


@dataclass
class ElevationGrid:
    """A theatre's sampled ground heights.

    Args:
        theatre: The DCS theatre name, as a mission's ``theatre`` member spells it.
        grid: Where the samples are, in mission coordinates (``x`` north, ``y`` east).
        heights: One height per cell, row-major, in whole metres above sea level.
    """

    theatre: str
    grid: GridSpec
    heights: array

    def sample(self, row: int, col: int) -> int:
        """Return the stored height of one cell, in metres."""
        return int(self.heights[row * self.grid.cols + col])

    def elevation_at(self, x: float, y: float) -> float | None:
        """Return the ground height at a point, bilinear between the four samples around it.

        Args:
            x: Mission ``x`` (north), metres.
            y: Mission ``y`` (east), metres.

        Returns:
            The height in metres above sea level, or ``None`` when the point is off the grid.
        """
        grid = self.grid
        if not grid.contains(x, y):
            return None
        fr = (x - grid.origin_x) / grid.spacing
        fc = (y - grid.origin_y) / grid.spacing
        # Clamped so a point on the last row or column still has a cell to interpolate in.
        r0 = min(int(fr), max(grid.rows - 2, 0))
        c0 = min(int(fc), max(grid.cols - 2, 0))
        r1 = min(r0 + 1, grid.rows - 1)
        c1 = min(c0 + 1, grid.cols - 1)
        tr, tc = fr - r0, fc - c0
        top = self.sample(r0, c0) * (1 - tc) + self.sample(r0, c1) * tc
        bottom = self.sample(r1, c0) * (1 - tc) + self.sample(r1, c1) * tc
        return top * (1 - tr) + bottom * tr


def _little_endian(values: array) -> bytes:
    """Return an int16 array's bytes in little-endian order, whatever the machine's."""
    if sys.byteorder == "big":
        values = array("h", values)
        values.byteswap()
    return values.tobytes()


def _from_little_endian(data: bytes) -> array:
    """Reverse :func:`_little_endian`."""
    values = array("h")
    values.frombytes(data)
    if sys.byteorder == "big":
        values.byteswap()
    return values


def _encode(heights: array, cols: int) -> bytes:
    """Delta-encode each row, then compress: neighbouring samples differ by little.

    lzma rather than zlib: 5.5 MB against 7.0 MB on Syria at 250 m. A two-dimensional predictor saved
    another 6 % for twice the encoding time and was not kept (measured 2026-10-01).

    Args:
        heights: One height per cell, row-major.
        cols: Cells per row.

    Returns:
        The compressed bytes.
    """
    deltas = array("h")
    for start in range(0, len(heights), cols):
        row = heights[start : start + cols]
        deltas.append(row[0])
        deltas.extend(b - a for a, b in itertools.pairwise(row))
    return lzma.compress(_little_endian(deltas), preset=9)


def _decode(data: bytes, cols: int) -> array:
    """Reverse :func:`_encode`."""
    deltas = _from_little_endian(lzma.decompress(data))
    heights = array("h")
    for start in range(0, len(deltas), cols):
        heights.extend(itertools.accumulate(deltas[start : start + cols]))
    return heights


def save_grid(elevation: ElevationGrid, path: Path) -> None:
    """Write a grid, byte for byte reproducible from the same heights.

    Args:
        elevation: What to write.
        path: The destination file.

    Raises:
        ValueError: If cells are still pending, or the grid does not hold one height per cell.
    """
    if len(elevation.heights) != elevation.grid.size:
        raise ValueError(f"{len(elevation.heights)} heights for {elevation.grid.size} cells")
    pending = elevation.heights.count(PENDING_HEIGHT)
    if pending:
        raise ValueError(f"{pending} cells are not swept yet; resume the sweep first")
    header = json.dumps({"theatre": elevation.theatre, "grid": elevation.grid.to_dict()}, sort_keys=True)
    encoded = header.encode("utf-8")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(
        _PREAMBLE.pack(_MAGIC, GRID_FORMAT_VERSION, len(encoded))
        + encoded
        + _encode(elevation.heights, elevation.grid.cols)
    )


def load_grid(path: Path) -> ElevationGrid:
    """Read a grid written by :func:`save_grid`.

    Args:
        path: The grid file.

    Returns:
        The grid.

    Raises:
        ValueError: If the file is not a grid, is of a format this code does not read, is damaged, or
            does not hold one height per cell.
    """
    data = path.read_bytes()
    if len(data) < _PREAMBLE.size or data[: len(_MAGIC)] != _MAGIC:
        raise ValueError(f"{path}: not a terrain grid")
    _magic, version, header_length = _PREAMBLE.unpack_from(data)
    if version != GRID_FORMAT_VERSION:
        raise ValueError(f"{path}: terrain format {version}, expected {GRID_FORMAT_VERSION}")
    body = _PREAMBLE.size + header_length
    header = json.loads(data[_PREAMBLE.size : body].decode("utf-8"))
    grid = GridSpec.from_dict(header["grid"])
    try:
        heights = _decode(data[body:], grid.cols)
    except lzma.LZMAError as e:
        raise ValueError(f"{path}: damaged terrain grid ({e})") from e
    if len(heights) != grid.size:
        raise ValueError(f"{path}: {len(heights)} values for {grid.size} cells, not one height per cell")
    return ElevationGrid(header["theatre"], grid, heights)


def grid_file_name(theatre: str) -> str:
    """Return the file name a theatre's grid is stored under."""
    return f"{theatre}{_GRID_SUFFIX}"


def local_grid_dir() -> Path:
    """Where grids swept on this workstation go: under the VEAF home, so an update keeps them."""
    from veaf_libs.veaf_home import get_veaf_home  # noqa: PLC0415

    return get_veaf_home() / "terrain"


@cache
def _load_cached(path: str, mtime: float) -> ElevationGrid:
    """Load a grid once per file version (``mtime`` is part of the cache key only)."""
    del mtime
    return load_grid(Path(path))


def grid_for_theatre(theatre: str) -> ElevationGrid | None:
    """Return the grid swept on this workstation for a theatre.

    None is shipped with the tools: a theatre weighs some 5.5 MB at 250 m, a mission maker has DCS at
    hand and sweeps one in under three minutes (David, 2026-10-01).

    Args:
        theatre: The theatre, any case or alias: ``terrain-sweep`` saves it under DCS's spelling.

    Returns:
        The grid, or ``None`` when none was swept.
    """
    from veaf_libs.blank_mission import canonical_theatre_name  # noqa: PLC0415

    path = local_grid_dir() / grid_file_name(canonical_theatre_name(theatre))
    if not path.is_file():
        return None
    return _load_cached(str(path), path.stat().st_mtime)


def metres_to_feet(metres: float) -> float:
    """Convert metres to feet."""
    return metres / 0.3048


#: Effective Earth radius for a radar line of sight: 4/3 of the real one, the standard allowance for
#: atmospheric refraction.
RADAR_EARTH_RADIUS_METERS = 6371000.0 * 4 / 3

#: The cell kinds :func:`maxima_per_cell` knows.
CELL_KINDS = ("mgrs10km", "quadrangle30")


@dataclass(frozen=True)
class ProfileSample:
    """One point of a profile: distance from the leg's start, position, ground height (``None`` off the grid)."""

    distance: float
    x: float
    y: float
    height: float | None


@dataclass(frozen=True)
class Leg:
    """The terrain along one leg of a route.

    Args:
        length: The leg's length, metres.
        samples: The ground every half grid spacing, both ends included.
        highest: The highest sample on the grid, metres; ``None`` when no sample is covered.
        covered: Whether every sample is on the grid.
    """

    length: float
    samples: list[ProfileSample]
    highest: float | None
    covered: bool


def _along(start: tuple[float, float], end: tuple[float, float], step: float) -> list[tuple[float, float, float]]:
    """Points every ``step`` at most from ``start`` to ``end``, both included, as ``(distance, x, y)``."""
    length = math.dist(start, end)
    count = max(1, math.ceil(length / step))
    return [
        (length * i / count, start[0] + (end[0] - start[0]) * i / count, start[1] + (end[1] - start[1]) * i / count)
        for i in range(count + 1)
    ]


def profile(elevation: ElevationGrid, route: list[tuple[float, float]]) -> list[Leg]:
    """Return the terrain along each leg of a route, sampled every half grid spacing.

    Args:
        elevation: The grid.
        route: Two points or more, mission ``(x, y)``.

    Returns:
        One :class:`Leg` per pair of consecutive points.

    Raises:
        ValueError: If the route has fewer than two points.
    """
    if len(route) < 2:
        raise ValueError("a profile takes two points or more")
    legs = []
    for start, end in itertools.pairwise(route):
        samples = [
            ProfileSample(d, x, y, elevation.elevation_at(x, y))
            for d, x, y in _along(start, end, elevation.grid.spacing / 2)
        ]
        heights = [s.height for s in samples if s.height is not None]
        legs.append(
            Leg(math.dist(start, end), samples, max(heights) if heights else None, len(heights) == len(samples))
        )
    return legs


@dataclass(frozen=True)
class SightMask:
    """The sample of a line of sight with the least clearance under the ray.

    Args:
        distance: From the observer, metres.
        x: Mission ``x``.
        y: Mission ``y``.
        height: Ground height there, metres.
        clearance: Ray height minus ground height, Earth's bulge included; negative when it masks.
    """

    distance: float
    x: float
    y: float
    height: float
    clearance: float


@dataclass(frozen=True)
class Sight:
    """Whether an observer sees a target over the terrain.

    Args:
        visible: No sample rises above the ray.
        mask: The sample with the least clearance (the masking one when not visible); ``None`` when
            the two points are too close to have a sample between them.
        covered: Whether the whole path is on the grid; when it is not, ``visible`` says nothing.
    """

    visible: bool
    mask: SightMask | None
    covered: bool


def line_of_sight(
    elevation: ElevationGrid,
    observer: tuple[float, float],
    observer_height: float,
    target: tuple[float, float],
    target_altitude: float,
) -> Sight:
    """Tell whether an observer sees a target, over the terrain and the 4/3 Earth's bulge.

    The ray is straight between the observer's antenna and the target; every half grid spacing, the
    ground is raised by the Earth's bulge at that point, ``d1 * d2 / (2 R)`` with the radar's
    :data:`RADAR_EARTH_RADIUS_METERS`, and compared with it. Terrain only: a building or a forest that
    masks in DCS is not seen here.

    Args:
        elevation: The grid.
        observer: Mission ``(x, y)`` of the observer.
        observer_height: The observer's antenna height above the ground, metres.
        target: Mission ``(x, y)`` of the target.
        target_altitude: The target's altitude above sea level, metres.

    Returns:
        The answer.
    """
    ground = elevation.elevation_at(*observer)
    covered = ground is not None and elevation.elevation_at(*target) is not None
    start = (ground or 0.0) + observer_height
    points = _along(observer, target, elevation.grid.spacing / 2)
    total = points[-1][0]
    mask: SightMask | None = None
    for d, x, y in points[1:-1]:
        h = elevation.elevation_at(x, y)
        if h is None:
            covered = False
            continue
        ray = start + (target_altitude - start) * d / total
        clearance = ray - h - d * (total - d) / (2 * RADAR_EARTH_RADIUS_METERS)
        if mask is None or clearance < mask.clearance:
            mask = SightMask(d, x, y, h, clearance)
    return Sight(mask is None or mask.clearance >= 0, mask, covered)


#: Spacing of the aircraft positions :func:`route_exposure` checks along a leg.
EXPOSURE_STEP_METERS = 1000.0


@dataclass(frozen=True)
class RoutePoint:
    """A route point with its altitude, as a waypoint carries it.

    Args:
        x: Mission ``x``.
        y: Mission ``y``.
        alt: Altitude, metres.
        agl: ``alt`` is above the ground (a waypoint's ``RADIO``) rather than above sea level (``BARO``).
    """

    x: float
    y: float
    alt: float
    agl: bool


@dataclass(frozen=True)
class LegExposure:
    """How much of a leg an observer sees.

    Args:
        in_range_length: Metres of the leg within the observer's range.
        seen_length: Metres of those the observer sees over the terrain.
        covered: Whether every position checked, and every sample between it and the observer, was on
            the grid. When not, the lengths are wrong either way: a sample off the grid cannot mask, and
            an aircraft whose height comes from ground off the grid is counted in range, never seen.
    """

    in_range_length: float
    seen_length: float
    covered: bool


def _above_sea(elevation: ElevationGrid, point: RoutePoint) -> float | None:
    """A route point's altitude above sea level; ``None`` when it is above ground off the grid."""
    if not point.agl:
        return point.alt
    ground = elevation.elevation_at(point.x, point.y)
    return None if ground is None else ground + point.alt


def route_exposure(
    elevation: ElevationGrid,
    observer: tuple[float, float],
    observer_height: float,
    route: list[RoutePoint],
    *,
    max_range: float,
    step: float = EXPOSURE_STEP_METERS,
) -> list[LegExposure]:
    """Tell, leg by leg, how much of a route an observer within range sees over the terrain.

    Each leg is cut in pieces of ``step`` at most, and the aircraft checked at the middle of each piece
    with :func:`line_of_sight`. A leg between two ``agl`` points follows the ground, at a height
    interpolated between theirs; any other leg is a straight line between the two points' altitudes
    above sea level, each converted with its own type.

    Args:
        elevation: The grid.
        observer: Mission ``(x, y)`` of the observer (a radar, a SAM).
        observer_height: Its antenna height above the ground, metres.
        route: Two points or more.
        max_range: Beyond this distance, a position is not counted, seen or not.
        step: Spacing of the positions checked.

    Returns:
        One :class:`LegExposure` per leg.

    Raises:
        ValueError: If the route has fewer than two points.
    """
    if len(route) < 2:
        raise ValueError("a route takes two points or more")
    legs = []
    for start, end in itertools.pairwise(route):
        length = math.dist((start.x, start.y), (end.x, end.y))
        pieces = max(1, math.ceil(length / step))
        in_range = seen = 0.0
        covered = True
        follows_ground = start.agl and end.agl
        alt0 = start.alt if follows_ground else _above_sea(elevation, start)
        alt1 = end.alt if follows_ground else _above_sea(elevation, end)
        for i in range(pieces):
            t = (i + 0.5) / pieces
            x, y = start.x + (end.x - start.x) * t, start.y + (end.y - start.y) * t
            if math.dist(observer, (x, y)) > max_range:
                continue
            in_range += length / pieces
            ground = elevation.elevation_at(x, y) if follows_ground else 0.0
            if ground is None or alt0 is None or alt1 is None:
                covered = False
                continue
            alt = ground + alt0 + (alt1 - alt0) * t
            sight = line_of_sight(elevation, observer, observer_height, (x, y), alt)
            covered = covered and sight.covered
            if sight.visible:
                seen += length / pieces
        legs.append(LegExposure(in_range, seen, covered))
    return legs


@dataclass(frozen=True)
class CellMaximum:
    """The highest sample of one map cell.

    Args:
        cell: The cell's name — an MGRS square (``"38T KM 6 7"``) or a quadrangle's south-west corner
            (``"N42°00' E042°30'"``).
        highest: The highest sample, metres. Terrain only, and a peak between two samples can be
            higher: the grid spacing bounds how much.
        x: Mission ``x`` of that sample.
        y: Mission ``y`` of that sample.
        samples: How many samples of the area fell in the cell.
    """

    cell: str
    highest: int
    x: float
    y: float
    samples: int


def _quadrangle(lat: float, lon: float) -> str:
    """Name the 30′ quadrangle holding a position by its south-west corner."""
    south = math.floor(lat * 2) / 2
    west = math.floor(lon * 2) / 2
    ns, ew = ("N" if south >= 0 else "S"), ("E" if west >= 0 else "W")
    lat_deg, lat_min = int(abs(south)), int(abs(south) % 1 * 60)
    lon_deg, lon_min = int(abs(west)), int(abs(west) % 1 * 60)
    return f"{ns}{lat_deg:02d}°{lat_min:02d}' {ew}{lon_deg:03d}°{lon_min:02d}'"


def maxima_per_cell(
    elevation: ElevationGrid, bounds: tuple[float, float, float, float], kind: str
) -> list[CellMaximum]:
    """Return the highest sample of each cell an area touches.

    Args:
        elevation: The grid; its theatre must have a projection (:mod:`veaf_libs.coordinates`).
        bounds: ``(min_x, min_y, max_x, max_y)``, mission coordinates. Only the samples inside count,
            so a cell the area cuts through is reported for its part inside.
        kind: ``"mgrs10km"`` — the 10 km squares of the F10 grid — or ``"quadrangle30"`` — 30′ by 30′,
            as on an aeronautical chart.

    Returns:
        One entry per cell, ordered by name.

    Raises:
        ValueError: If ``kind`` is unknown, or the theatre has no projection.
    """
    from veaf_libs.coordinates import xy_to_latlon  # noqa: PLC0415
    from veaf_libs.mgrs import mgrs_square  # noqa: PLC0415

    if kind not in CELL_KINDS:
        raise ValueError(f"cell kind {kind!r}: expected one of {', '.join(CELL_KINDS)}")
    grid = elevation.grid
    min_x, min_y, max_x, max_y = bounds
    first_row = max(0, math.ceil((min_x - grid.origin_x) / grid.spacing))
    last_row = min(grid.rows - 1, math.floor((max_x - grid.origin_x) / grid.spacing))
    first_col = max(0, math.ceil((min_y - grid.origin_y) / grid.spacing))
    last_col = min(grid.cols - 1, math.floor((max_y - grid.origin_y) / grid.spacing))
    found: dict[str, CellMaximum] = {}
    for r in range(first_row, last_row + 1):
        for c in range(first_col, last_col + 1):
            x, y = grid.cell_position(r, c)
            lat, lon = xy_to_latlon(elevation.theatre, x, y)
            name = mgrs_square(lat, lon, 10000) if kind == "mgrs10km" else _quadrangle(lat, lon)
            h = elevation.sample(r, c)
            known = found.get(name)
            if known is None:
                found[name] = CellMaximum(name, h, x, y, 1)
            elif h > known.highest:
                found[name] = CellMaximum(name, h, x, y, known.samples + 1)
            else:
                found[name] = CellMaximum(name, known.highest, known.x, known.y, known.samples + 1)
    return [found[name] for name in sorted(found)]
