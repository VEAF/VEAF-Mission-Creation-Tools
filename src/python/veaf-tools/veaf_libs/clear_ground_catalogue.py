"""Catalogue of ground measured clear of scenery, per DCS theatre (FEAT-CLEAR-GROUND-AT-AUTHORING).

When the authoring tools choose where a ground group goes, they must choose ground that is clear of
trees and buildings. DCS only knows where its forests are at runtime, through the undocumented
``Disposition`` singleton, and only one use of it is dependable: the *small probe* — "is there a patch
of 5 m free within 20 m of this point?" — deterministic over 12 repetitions
(``known-limitations.yaml``, ``disposition-getsimplezones-is-a-lottery``). So a theatre is swept once
with that probe, on an empty mission, and the answers are kept here as data the tools can read with no
DCS running.

**What is stored.** One or more *layers*, each a regular grid of probe answers
(:data:`STATE_CLEAR`, :data:`STATE_BLOCKED`, ...) and, derived from it, the **clear radius** of every
cell: how far one can go from that cell in any direction before meeting a sample that is not clear.
A coarse layer covers the whole map, finer layers cover where groups are actually placed.

**Why the radius is derived rather than probed.** A radius probed point by point costs a ring of probes
per point — hundreds for a 300 m radius — where a grid costs one probe per point and the radius falls
out of a distance transform computed here, offline. The price is resolution: nothing is known between
two samples, so the radius is shortened by one spacing (:func:`compute_clear_radii`).

**What a query returns** is a :class:`ClearGroundAnswer`, whose ``status`` keeps apart the two answers
that call for different actions: *the catalogue does not cover this place* and *it covers it and found
nothing large enough*.
"""

from __future__ import annotations

import base64
import json
import math
import zlib
from dataclasses import dataclass, field
from enum import Enum
from functools import cache
from pathlib import Path
from typing import Any

from veaf_libs.bundled_data import bundled_dir

#: One probe answer per grid cell, one byte each.
STATE_CLEAR = ord("1")
STATE_BLOCKED = ord("0")
STATE_WATER = ord("W")
STATE_RUNWAY = ord("R")
#: The probe raised or returned something that was not a table: nothing is known here.
STATE_UNKNOWN = ord("?")
#: Not swept yet — only ever seen in a sweep in progress, never in a finished catalogue.
STATE_PENDING = ord(".")

#: The radius is stored in steps of this many metres, rounded **down**, in one byte per cell.
RADIUS_UNIT_METERS = 10
#: The largest radius one byte can hold. Nothing in this catalogue needs to know more: the largest
#: real group footprint measured on GermanyCW-v6 is 486 m.
MAX_STORED_RADIUS_METERS = 255 * RADIUS_UNIT_METERS

#: Added to the radius a group asks for before a cell may serve it.
#:
#: 40 m, because a VEAF group's footprint **moves by up to 38.8 m between two draws of its layout**
#: (FIX-PLACEMENT-IGNORES-SCENERY ticket 11, measured on GermanyCW-v6): a group spawned from a
#: ``#command`` marker is redrawn at every spawn, so the position the tools chose has to hold for any
#: draw, not for one of them.
PLACEMENT_MARGIN_METERS = 40.0

CATALOGUE_FORMAT_VERSION = 1
_CATALOGUE_SUFFIX = ".clear-ground.json"


@dataclass(frozen=True)
class GridSpec:
    """A regular grid in DCS mission coordinates.

    ``x`` is north and ``y`` is east, as in a mission table (``docs/agents/dcs-coordinates.md``); the
    runtime calls the second one ``z``. Row ``r``, column ``c`` sits at
    ``(origin_x + r * spacing, origin_y + c * spacing)``.

    Args:
        origin_x: Mission ``x`` of row 0.
        origin_y: Mission ``y`` of column 0.
        spacing: Distance between two neighbouring cells, in metres.
        rows: Number of rows, along ``x``.
        cols: Number of columns, along ``y``.
    """

    origin_x: float
    origin_y: float
    spacing: float
    rows: int
    cols: int

    @property
    def size(self) -> int:
        """Number of cells."""
        return self.rows * self.cols

    def cell_position(self, row: int, col: int) -> tuple[float, float]:
        """Return the mission ``(x, y)`` of a cell."""
        return self.origin_x + row * self.spacing, self.origin_y + col * self.spacing

    def contains(self, x: float, y: float) -> bool:
        """Tell whether a point lies inside the grid's extent."""
        max_x = self.origin_x + (self.rows - 1) * self.spacing
        max_y = self.origin_y + (self.cols - 1) * self.spacing
        return self.origin_x <= x <= max_x and self.origin_y <= y <= max_y

    def to_dict(self) -> dict[str, Any]:
        """Serialise to a JSON-ready dict."""
        return {
            "origin_x": float(self.origin_x),
            "origin_y": float(self.origin_y),
            "spacing": float(self.spacing),
            "rows": self.rows,
            "cols": self.cols,
        }

    @classmethod
    def from_dict(cls, data: dict[str, Any]) -> GridSpec:
        """Build from :meth:`to_dict` output."""
        return cls(
            origin_x=float(data["origin_x"]),
            origin_y=float(data["origin_y"]),
            spacing=float(data["spacing"]),
            rows=int(data["rows"]),
            cols=int(data["cols"]),
        )


@dataclass
class Layer:
    """One swept grid: its probe answers, and the clear radius derived from them.

    Args:
        name: What the layer covers, for a human (``"coarse"``, ``"combatZone_Wittstock"``...).
        grid: Where the cells are.
        states: One probe answer per cell, row-major.
        radii: One stored radius per cell, row-major, in :data:`RADIUS_UNIT_METERS` steps; empty until
            :meth:`derive_radii` runs.
    """

    name: str
    grid: GridSpec
    states: bytearray
    radii: bytearray = field(default_factory=bytearray)

    def derive_radii(self) -> None:
        """Compute :attr:`radii` from :attr:`states`."""
        self.radii = compute_clear_radii(self.states, self.grid)

    def radius_at(self, row: int, col: int) -> float:
        """Return the clear radius of a cell, in metres."""
        return float(self.radii[row * self.grid.cols + col] * RADIUS_UNIT_METERS)


@dataclass
class Catalogue:
    """Every layer swept for one theatre."""

    theatre: str
    layers: list[Layer]


class ClearGroundStatus(Enum):
    """What a query found, in the three cases a caller acts on differently."""

    #: At least one position was found.
    FOUND = "found"
    #: The catalogue covers the place, and nothing within the search radius is large enough.
    NONE_LARGE_ENOUGH = "none_large_enough"
    #: No catalogue, or no layer of it, covers the place: nothing is known either way.
    NOT_COVERED = "not_covered"


@dataclass(frozen=True)
class ClearPosition:
    """One candidate position.

    Args:
        x: Mission ``x``.
        y: Mission ``y``.
        clear_radius: The radius measured clear around it, in metres.
        distance: How far it is from the point asked about, in metres.
        layer: The layer it comes from.
        spacing: That layer's cell spacing — how precisely the position is known.
    """

    x: float
    y: float
    clear_radius: float
    distance: float
    layer: str
    spacing: float = 0.0


@dataclass(frozen=True)
class ClearGroundAnswer:
    """The result of :func:`find_clear_positions`."""

    status: ClearGroundStatus
    candidates: list[ClearPosition]


def compute_clear_radii(states: bytes | bytearray, grid: GridSpec) -> bytearray:
    """Derive the clear radius of every cell from the probe answers.

    The radius of a clear cell is its distance to the nearest cell that is **not** clear — blocked,
    water, runway, unknown — **minus one spacing**, because nothing is known between two samples and
    the obstacle may stand just past the last clear one. Everything outside the grid counts as not
    clear, so a layer never promises ground it did not measure. Cells that are not clear get 0.

    Exact Euclidean distance, by the separable transform of Felzenszwalb and Huttenlocher (2012):
    linear in the number of cells, which is what makes a whole-map layer of millions of cells
    affordable in pure Python.

    Args:
        states: One probe answer per cell, row-major.
        grid: The grid the answers were taken on.

    Returns:
        One byte per cell, the radius in :data:`RADIUS_UNIT_METERS` steps, rounded down and capped at
        :data:`MAX_STORED_RADIUS_METERS`.

    Raises:
        ValueError: If ``states`` does not hold one answer per cell.
    """
    rows, cols = grid.rows, grid.cols
    if len(states) != rows * cols:
        raise ValueError(f"expected {rows * cols} probe answers, got {len(states)}")
    # Pad by one cell all around: the padding is "not clear", which is how the outside of the grid
    # counts as an obstacle without a special case in the transform.
    prows, pcols = rows + 2, cols + 2
    inf = float((prows + pcols) ** 2)
    squared = [inf] * (prows * pcols)
    for r in range(prows):
        for c in range(pcols):
            inside = 0 < r <= rows and 0 < c <= cols
            if not inside or states[(r - 1) * cols + (c - 1)] != STATE_CLEAR:
                squared[r * pcols + c] = 0.0

    # Columns first, then rows: the 2-D squared distance is the 1-D transform applied along each axis.
    column = [0.0] * prows
    for c in range(pcols):
        for r in range(prows):
            column[r] = squared[r * pcols + c]
        transformed = _squared_distance_1d(column)
        for r in range(prows):
            squared[r * pcols + c] = transformed[r]
    for r in range(prows):
        start = r * pcols
        squared[start : start + pcols] = _squared_distance_1d(squared[start : start + pcols])

    radii = bytearray(rows * cols)
    max_steps = MAX_STORED_RADIUS_METERS // RADIUS_UNIT_METERS
    for r in range(rows):
        for c in range(cols):
            distance = math.sqrt(squared[(r + 1) * pcols + (c + 1)]) * grid.spacing
            meters = max(0.0, distance - grid.spacing)
            radii[r * cols + c] = min(max_steps, int(meters // RADIUS_UNIT_METERS))
    return radii


def _squared_distance_1d(values: list[float]) -> list[float]:
    """1-D squared distance transform (lower envelope of parabolas), Felzenszwalb & Huttenlocher.

    Args:
        values: 0 where a sample is an obstacle, a large number elsewhere — or, on the second pass,
            the squared distances the first pass computed.

    Returns:
        For each position, the smallest ``(q - v)**2 + values[v]`` over all ``v``.
    """
    n = len(values)
    result = [0.0] * n
    vertices = [0] * n
    boundaries = [0.0] * (n + 1)
    k = 0
    boundaries[0], boundaries[1] = -math.inf, math.inf
    for q in range(1, n):
        while True:
            v = vertices[k]
            s = ((values[q] + q * q) - (values[v] + v * v)) / (2 * q - 2 * v)
            if s <= boundaries[k]:
                k -= 1
                continue
            break
        k += 1
        vertices[k] = q
        boundaries[k] = s
        boundaries[k + 1] = math.inf
    k = 0
    for q in range(n):
        while boundaries[k + 1] < q:
            k += 1
        v = vertices[k]
        result[q] = (q - v) * (q - v) + values[v]
    return result


def find_clear_positions(
    catalogue: Catalogue | None,
    x: float,
    y: float,
    *,
    search_radius: float,
    required_radius: float,
    margin: float = PLACEMENT_MARGIN_METERS,
    limit: int | None = 10,
) -> ClearGroundAnswer:
    """Find positions near ``(x, y)`` where a footprint of ``required_radius`` fits, nearest first.

    A cell serves only when its stored radius is at least ``required_radius + margin``: the stored
    radius is a floor already, and the margin covers a layout redrawn at every spawn
    (:data:`PLACEMENT_MARGIN_METERS`).

    Args:
        catalogue: The theatre's catalogue, or ``None`` when there is none.
        x: Mission ``x`` of the point asked about.
        y: Mission ``y`` of the point asked about.
        search_radius: How far from the point a candidate may be, in metres.
        required_radius: The radius the group needs clear around its centre, in metres.
        margin: Added to ``required_radius``.
        limit: At most this many candidates are returned; ``None`` returns them all.

    Returns:
        The answer. Candidates come from every layer the search disc reaches, so a clearing in the
        next swept square is offered too; ``NOT_COVERED`` when no layer holds the point asked about
        and none of the layers within reach offers anything.
    """
    all_layers = catalogue.layers if catalogue else []
    covered = any(layer.grid.contains(x, y) for layer in all_layers)
    needed = required_radius + margin
    candidates: list[ClearPosition] = []
    for layer in all_layers:
        grid = layer.grid
        row_min = max(0, math.floor((x - search_radius - grid.origin_x) / grid.spacing))
        row_max = min(grid.rows - 1, math.ceil((x + search_radius - grid.origin_x) / grid.spacing))
        col_min = max(0, math.floor((y - search_radius - grid.origin_y) / grid.spacing))
        col_max = min(grid.cols - 1, math.ceil((y + search_radius - grid.origin_y) / grid.spacing))
        if row_min > row_max or col_min > col_max:
            continue  # the search disc does not reach this layer
        for row in range(row_min, row_max + 1):
            for col in range(col_min, col_max + 1):
                clear = layer.radius_at(row, col)
                if clear < needed:
                    continue
                cx, cy = grid.cell_position(row, col)
                distance = math.hypot(cx - x, cy - y)
                if distance <= search_radius:
                    candidates.append(ClearPosition(cx, cy, clear, distance, layer.name, grid.spacing))
    candidates.sort(key=lambda c: (c.distance, -c.clear_radius, c.x, c.y))
    if not candidates and not covered:
        return ClearGroundAnswer(ClearGroundStatus.NOT_COVERED, [])
    if not candidates:
        return ClearGroundAnswer(ClearGroundStatus.NONE_LARGE_ENOUGH, [])
    return ClearGroundAnswer(ClearGroundStatus.FOUND, candidates[:limit])


def _pack(data: bytes | bytearray) -> str:
    """Compress bytes into the text a catalogue file stores.

    Args:
        data: One byte per cell.

    Returns:
        The bytes, zlib-compressed and base64-encoded.
    """
    return base64.b64encode(zlib.compress(bytes(data), 9)).decode("ascii")


def _unpack(text: str) -> bytearray:
    """Reverse :func:`_pack`.

    Args:
        text: What :func:`_pack` produced.

    Returns:
        The bytes, one per cell.
    """
    return bytearray(zlib.decompress(base64.b64decode(text)))


def save_catalogue(catalogue: Catalogue, path: Path) -> None:
    """Write a catalogue, deriving any radius not derived yet.

    The output is byte-for-byte reproducible from the same probe answers: sweeping a theatre twice
    produces the same file, which is what makes a re-sweep reviewable as a diff.

    Args:
        catalogue: What to write.
        path: The destination file.
    """
    layers = []
    for layer in catalogue.layers:
        if len(layer.radii) != layer.grid.size:
            layer.derive_radii()
        layers.append(
            {
                "name": layer.name,
                "grid": layer.grid.to_dict(),
                "states": _pack(layer.states),
                "radii": _pack(layer.radii),
            }
        )
    document = {"format": CATALOGUE_FORMAT_VERSION, "theatre": catalogue.theatre, "layers": layers}
    path.parent.mkdir(parents=True, exist_ok=True)
    # Bytes, not text: `write_text` turns the line ends into CRLF on Windows, and the same sweep would
    # then produce a different file on two workstations.
    path.write_bytes((json.dumps(document, indent=1, sort_keys=True) + "\n").encode("utf-8"))


def load_catalogue(path: Path) -> Catalogue:
    """Read a catalogue written by :func:`save_catalogue`.

    Args:
        path: The catalogue file.

    Returns:
        The catalogue.

    Raises:
        ValueError: If the file is of a format this code does not read, or a layer is inconsistent.
    """
    document = json.loads(path.read_text(encoding="utf-8"))
    if document.get("format") != CATALOGUE_FORMAT_VERSION:
        raise ValueError(f"{path}: catalogue format {document.get('format')!r}, expected {CATALOGUE_FORMAT_VERSION}")
    layers = []
    for entry in document["layers"]:
        layer = Layer(
            name=entry["name"],
            grid=GridSpec.from_dict(entry["grid"]),
            states=_unpack(entry["states"]),
            radii=_unpack(entry["radii"]),
        )
        if len(layer.states) != layer.grid.size or len(layer.radii) != layer.grid.size:
            raise ValueError(f"{path}: layer {layer.name!r} does not hold one value per cell")
        layers.append(layer)
    return Catalogue(theatre=document["theatre"], layers=layers)


def catalogue_file_name(theatre: str) -> str:
    """Return the file name a theatre's catalogue is stored under."""
    return f"{theatre}{_CATALOGUE_SUFFIX}"


def local_catalogue_dir() -> Path:
    """Where catalogues swept on this workstation go (decision 5, second half).

    Under the user's VEAF home rather than next to the executable, so a local sweep survives an
    update of the tools and never overwrites the versioned catalogue.
    """
    from veaf_libs.veaf_home import get_veaf_home  # noqa: PLC0415

    return get_veaf_home() / "clear-ground"


@cache
def _load_cached(path: str, mtime: float) -> Catalogue:
    """Load a catalogue once per file version.

    Args:
        path: The catalogue file.
        mtime: Its modification time — part of the cache key only, so a re-swept file is read again.

    Returns:
        The catalogue.
    """
    del mtime
    return load_catalogue(Path(path))


def catalogue_for_theatre(theatre: str) -> Catalogue | None:
    """Return the catalogue for a theatre: swept locally if there is one, else the versioned one.

    The local one wins because it is the one somebody swept on purpose, for a map or an area the
    versioned one did not cover.

    Args:
        theatre: The DCS theatre name, as a mission's ``theatre`` member spells it.

    Returns:
        The catalogue, or ``None`` when neither exists.
    """
    name = catalogue_file_name(theatre)
    for directory in (local_catalogue_dir(), bundled_dir("veaf_libs", "data", "clear-ground")):
        path = directory / name
        if path.is_file():
            return _load_cached(str(path), path.stat().st_mtime)
    return None
