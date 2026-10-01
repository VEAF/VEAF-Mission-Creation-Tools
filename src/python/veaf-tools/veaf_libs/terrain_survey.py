"""Sweep a DCS theatre's ground elevation with ``land.getHeight``, to fill :mod:`terrain_elevation`.

The clear-ground sweep's flow (:mod:`veaf_libs.clear_ground_survey`): an empty survey mission carrying
the bridge, ``dcs-serve`` as transport, batches written to disk as they come back so an interrupted
sweep resumes where it stopped. Only the probe differs, and it is the cheap one: a height, independent
of the units on the map.

**The cells are swept in order**, row-major, so the progress is a count: the heights already received,
appended to one file. A batch costs one append, not a rewrite of a file of several megabytes.

**Whole metres.** A sample is rounded to the metre: the error of interpolating between two samples
hundreds of metres apart is measured in tens of metres (``measure_resolution``), and an int16 per cell
keeps a theatre within a few megabytes.
"""

from __future__ import annotations

import json
import math
import statistics
from array import array
from collections.abc import Callable
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

from veaf_libs.clear_ground_catalogue import GridSpec
from veaf_libs.clear_ground_survey import LuaExec, SurveyError, airfield_positions, grid_over
from veaf_libs.terrain_elevation import ElevationGrid

#: Default sample spacing. Measured on Syria on 2026-10-01 against 50 m patches (Hermon, Qurnat as Sawda,
#: Homs plain): at 250 m a point is within 15 m 95 % of the time (81 m at worst) and a 10 km square's
#: maximum is at most 44 m low; at 500 m those become 39 m and 95 m, too much for a low-level floor;
#: 100 m gains some 30 m for six times the cells (ticket 01).
DEFAULT_SPACING_METERS = 250.0
#: Cells per call to DCS. A call costs 190 ms crossing the bridge (measured for the clear-ground
#: sweep, 2026-09-28); a height costs far less than a scenery probe, so batches can be larger.
DEFAULT_BATCH_CELLS = 20000
#: Added around the airfields when nothing else gives the map's extent.
AIRFIELD_MARGIN_METERS = 50000.0

#: Spacing of a measurement's reference patch; every candidate spacing is a multiple of it.
REFERENCE_SPACING_METERS = 50.0
#: Half-side of a measurement's reference patch.
REFERENCE_HALF_SIDE_METERS = 10000.0
#: The spacings a measurement compares.
CANDIDATE_SPACINGS_METERS = (100.0, 250.0, 500.0, 1000.0)
#: Side of the squares a measurement compares maxima over — the F10 grid's.
MAXIMUM_CELL_METERS = 10000.0

# Runtime coordinates: a Vec2's `y` is the mission's `y` (the runtime's `z`), see
# docs/agents/dcs-coordinates.md.
_CELLS_CHUNK_LUA = """
-- terrain:cells %(ox)r %(oy)r %(spacing)r %(cols)d %(start)d %(count)d
local ox, oy, s, cols = %(ox)r, %(oy)r, %(spacing)r, %(cols)d
local out = {}
for i = %(start)d, %(start)d + %(count)d - 1 do
  local r = math.floor(i / cols)
  local c = i - r * cols
  out[#out + 1] = string.format("%%d", math.floor(land.getHeight({ x = ox + r * s, y = oy + c * s }) + 0.5))
end
return table.concat(out, ",")
"""

# The map's extent, from the GUI state where the Mission Editor reads it (`me_managerDTC.lua`), in
# kilometres, `{x, y, z}`. Reaching the GUI from the mission is not always allowed: an empty answer
# means "ask somebody else".
_BOUNDS_LUA = """
-- terrain:bounds
local ok, answer = pcall(function()
  return net.dostring_in("gui", [[
    local T = Terrain or require("terrain")
    local sw, ne = T.GetTerrainConfig("SW_bound"), T.GetTerrainConfig("NE_bound")
    return sw[1] * 1000 .. " " .. sw[3] * 1000 .. " " .. ne[1] * 1000 .. " " .. ne[3] * 1000
  ]])
end)
if ok and type(answer) == "string" then
  return answer
end
return ""
"""


def probe_cells(exec_lua: LuaExec, grid: GridSpec, start: int, count: int) -> array:
    """Read the heights of ``count`` cells from index ``start``, row-major.

    Args:
        exec_lua: The transport.
        grid: The grid the indices are in.
        start: The first cell.
        count: Cells to read.

    Returns:
        One height per cell, whole metres.

    Raises:
        SurveyError: If DCS returns anything but one integer per cell.
    """
    code = _CELLS_CHUNK_LUA % {
        "ox": float(grid.origin_x),
        "oy": float(grid.origin_y),
        "spacing": float(grid.spacing),
        "cols": grid.cols,
        "start": start,
        "count": count,
    }
    answer = exec_lua(code)
    try:
        heights = array("h", (int(v) for v in answer.split(",")))
    except (ValueError, OverflowError) as e:
        raise SurveyError(f"unexpected height answer for {count} cells: {answer[:80]!r}") from e
    if len(heights) != count:
        raise SurveyError(f"unexpected height answer ({len(heights)} values for {count} cells): {answer[:80]!r}")
    return heights


def map_bounds(exec_lua: LuaExec, theatre: str) -> tuple[tuple[float, float, float, float], str]:
    """Return the extent to sweep, and where it came from.

    Args:
        exec_lua: The transport.
        theatre: The theatre, for the airfield fallback.

    Returns:
        ``(min_x, min_y, max_x, max_y)`` in mission coordinates, and ``"terrain"`` (DCS's own bounds)
        or ``"airfields"`` (their extent plus :data:`AIRFIELD_MARGIN_METERS`).

    Raises:
        SurveyError: If DCS does not give its bounds and no airfield is known on the theatre.
    """
    answer = exec_lua(_BOUNDS_LUA).split()
    try:
        # The GUI state can answer with an error message instead: anything but four numbers is "no".
        sw_x, sw_y, ne_x, ne_y = (float(v) for v in answer)
    except ValueError:
        pass
    else:
        return (min(sw_x, ne_x), min(sw_y, ne_y), max(sw_x, ne_x), max(sw_y, ne_y)), "terrain"
    fields = airfield_positions(theatre)
    if not fields:
        raise SurveyError(f"DCS did not give the extent of {theatre} and no airfield is known there: pass --bounds")
    xs, ys = [f[1] for f in fields], [f[2] for f in fields]
    margin = AIRFIELD_MARGIN_METERS
    return (min(xs) - margin, min(ys) - margin, max(xs) + margin, max(ys) + margin), "airfields"


def plan_grid(bounds: tuple[float, float, float, float], spacing: float) -> GridSpec:
    """Plan the grid over ``bounds``, snapped to multiples of ``spacing``.

    Args:
        bounds: ``(min_x, min_y, max_x, max_y)``, mission coordinates.
        spacing: Sample spacing.

    Returns:
        The grid.
    """
    return grid_over("terrain", bounds, spacing).grid


class TerrainSweepState:
    """The on-disk progress of a sweep: the plan, and the heights received so far, in cell order.

    Args:
        directory: Where the progress lives. Created when missing.
        theatre: The theatre swept.
        grid: The plan.
    """

    def __init__(self, directory: Path, theatre: str, grid: GridSpec) -> None:
        self.directory = directory
        self.theatre = theatre
        self.grid = grid
        self.done = 0

    @property
    def _heights_path(self) -> Path:
        return self.directory / "heights.bin"

    def open(self, *, restart: bool = False) -> None:
        """Load the progress of the same plan, or start a new one.

        Args:
            restart: Throw away the progress of a different plan instead of refusing.

        Raises:
            SurveyError: If the directory holds the progress of another plan and ``restart`` is false.
        """
        self.directory.mkdir(parents=True, exist_ok=True)
        plan_path = self.directory / "plan.json"
        plan = {"theatre": self.theatre, "grid": self.grid.to_dict()}
        if plan_path.is_file() and json.loads(plan_path.read_text(encoding="utf-8")) != plan:
            if not restart:
                raise SurveyError(f"{self.directory} holds a sweep of another plan; pass --restart to throw it away")
            self._heights_path.unlink(missing_ok=True)
        plan_path.write_text(json.dumps(plan, indent=1, sort_keys=True), encoding="utf-8")
        if not self._heights_path.is_file():
            self._heights_path.write_bytes(b"")
        size = self._heights_path.stat().st_size
        # An append cut short leaves half a height: drop it, the cell is read again.
        if size % 2:
            with self._heights_path.open("r+b") as f:
                f.truncate(size - 1)
        self.done = min(size // 2, self.grid.size)

    def append(self, heights: array) -> None:
        """Record the next heights, in cell order.

        Args:
            heights: The heights of the cells following those already received.
        """
        with self._heights_path.open("ab") as f:
            f.write(heights.tobytes())
        self.done += len(heights)

    def pending(self) -> int:
        """Number of cells not received yet."""
        return self.grid.size - self.done

    def elevation(self) -> ElevationGrid:
        """Build the grid from a finished sweep.

        Raises:
            SurveyError: If cells are still pending.
        """
        if self.pending():
            raise SurveyError(f"{self.pending()} cells are not swept yet; resume the sweep first")
        heights = array("h")
        heights.frombytes(self._heights_path.read_bytes()[: 2 * self.grid.size])
        return ElevationGrid(self.theatre, self.grid, heights)


def sweep(
    state: TerrainSweepState,
    exec_lua: LuaExec,
    *,
    batch_cells: int = DEFAULT_BATCH_CELLS,
    on_progress: Callable[[int, int], None] | None = None,
) -> None:
    """Read every pending cell, appending after each batch.

    Args:
        state: The opened progress.
        exec_lua: The transport.
        batch_cells: At most this many cells per call to DCS.
        on_progress: Called with ``(done, total)`` after every batch.
    """
    total = state.grid.size
    while state.done < total:
        count = min(batch_cells, total - state.done)
        state.append(probe_cells(exec_lua, state.grid, state.done, count))
        if on_progress:
            on_progress(state.done, total)


@dataclass(frozen=True)
class SpacingError:
    """How far a candidate spacing is from the reference, over the measured patches."""

    spacing: float
    point_max: float
    point_p95: float
    point_mean: float
    peak_max: float
    peak_mean: float

    def to_dict(self) -> dict[str, float]:
        """Serialise to a JSON-ready dict."""
        return dict(self.__dict__)


@dataclass
class ResolutionReport:
    """What ticket 01 measures: per candidate spacing, the error against a fine reference."""

    reference_spacing: float
    patches: list[dict[str, float]]
    spacings: list[SpacingError] = field(default_factory=list)

    def to_dict(self) -> dict[str, Any]:
        """Serialise to a JSON-ready dict."""
        return {
            "reference_spacing": self.reference_spacing,
            "patches": self.patches,
            "spacings": [s.to_dict() for s in self.spacings],
        }


def _subsample(reference: ElevationGrid, step: int) -> ElevationGrid:
    """Keep every ``step``-th sample of a grid along both axes, as a coarser sweep would read them."""
    ref = reference.grid
    rows = (ref.rows - 1) // step + 1
    cols = (ref.cols - 1) // step + 1
    heights = array("h", (reference.sample(r * step, c * step) for r in range(rows) for c in range(cols)))
    grid = GridSpec(ref.origin_x, ref.origin_y, ref.spacing * step, rows, cols)
    return ElevationGrid(reference.theatre, grid, heights)


def _percentile(values: list[float], fraction: float) -> float:
    """Return the value below which ``fraction`` of ``values`` lie (nearest rank)."""
    ordered = sorted(values)
    return ordered[min(len(ordered) - 1, max(0, math.ceil(fraction * len(ordered)) - 1))]


def compare_spacings(
    references: list[ElevationGrid],
    candidates: tuple[float, ...] = CANDIDATE_SPACINGS_METERS,
    maximum_cell: float = MAXIMUM_CELL_METERS,
) -> list[SpacingError]:
    """Measure, for each candidate spacing, the two errors a coarser grid makes against the reference.

    **At a point**: the height interpolated from the coarse samples against the reference sample, at
    every reference sample the coarse grid covers. **For a cell maximum**: how far the highest coarse
    sample in a ``maximum_cell`` square falls below the highest reference sample — a peak between two
    samples is a peak the coarse grid does not see.

    Args:
        references: Fine grids, at a spacing every candidate is a multiple of.
        candidates: The spacings to compare.
        maximum_cell: Side of the squares maxima are compared over.

    Returns:
        One result per candidate.

    Raises:
        ValueError: If a candidate is not a multiple of a reference's spacing.
    """
    results = []
    for spacing in candidates:
        point_errors: list[float] = []
        peak_errors: list[float] = []
        for reference in references:
            ref = reference.grid
            step = round(spacing / ref.spacing)
            if not math.isclose(step * ref.spacing, spacing):
                raise ValueError(f"{spacing} m is not a multiple of the reference's {ref.spacing} m")
            coarse = _subsample(reference, step)
            per_cell = max(1, round(maximum_cell / ref.spacing))
            true_max: dict[tuple[int, int], int] = {}
            seen_max: dict[tuple[int, int], int] = {}
            for r in range(ref.rows):
                for c in range(ref.cols):
                    x, y = ref.cell_position(r, c)
                    h = reference.sample(r, c)
                    interpolated = coarse.elevation_at(x, y)
                    if interpolated is None:
                        continue
                    point_errors.append(abs(interpolated - h))
                    key = (r // per_cell, c // per_cell)
                    true_max[key] = max(true_max.get(key, h), h)
                    if r % step == 0 and c % step == 0:
                        seen_max[key] = max(seen_max.get(key, h), h)
            peak_errors.extend(true_max[k] - seen_max[k] for k in true_max if k in seen_max)
        results.append(
            SpacingError(
                spacing=spacing,
                point_max=max(point_errors),
                point_p95=_percentile(point_errors, 0.95),
                point_mean=statistics.fmean(point_errors),
                peak_max=float(max(peak_errors)),
                peak_mean=statistics.fmean(peak_errors),
            )
        )
    return results


def measure_resolution(
    exec_lua: LuaExec,
    theatre: str,
    centres: list[tuple[float, float]],
    *,
    half_side: float = REFERENCE_HALF_SIDE_METERS,
    reference_spacing: float = REFERENCE_SPACING_METERS,
    candidates: tuple[float, ...] = CANDIDATE_SPACINGS_METERS,
    batch_cells: int = DEFAULT_BATCH_CELLS,
) -> ResolutionReport:
    """Sweep a fine patch around each centre and compare the candidate spacings against it.

    Args:
        exec_lua: The transport, to the survey mission.
        theatre: The theatre.
        centres: ``(x, y)`` of the patches, mission coordinates — choose relief, where errors are.
        half_side: Half the side of a patch.
        reference_spacing: The patches' spacing.
        candidates: The spacings to compare.
        batch_cells: At most this many cells per call to DCS.

    Returns:
        The report.
    """
    references = []
    patches = []
    for x, y in centres:
        grid = plan_grid((x - half_side, y - half_side, x + half_side, y + half_side), reference_spacing)
        heights = array("h")
        for start in range(0, grid.size, batch_cells):
            heights.extend(probe_cells(exec_lua, grid, start, min(batch_cells, grid.size - start)))
        reference = ElevationGrid(theatre, grid, heights)
        references.append(reference)
        patches.append({"x": x, "y": y, "min": float(min(heights)), "max": float(max(heights))})
    report = ResolutionReport(reference_spacing, patches)
    report.spacings = compare_spacings(references, candidates)
    return report
