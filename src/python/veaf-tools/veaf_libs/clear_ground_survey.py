"""Sweep a DCS theatre with the scenery probe, to fill the clear-ground catalogue.

The design and the measurements behind it live in ``.backlog/FEAT-CLEAR-GROUND-AT-AUTHORING``; the
catalogue itself in :mod:`veaf_libs.clear_ground_catalogue`. This module is the part that talks to DCS.

**On an empty mission, always.** The probe answers "is there room here", and a vehicle occupies room:
the same points read 12 of 14 blocked with a group standing on them and 0 of 14 once it was destroyed
(``known-limitations.yaml``, ``disposition-getsimplezones-is-a-lottery``). A sweep taken from a mission
holding units would record those units as permanent scenery. :func:`build_survey_mission` makes a
mission holding **no unit at all**, only the bridge the sweep talks through.

**Through ``dcs-serve``, as ``capture-map`` does.** The transport a mission maker already has for
capturing a theatre's airbases, so the on-demand half of the catalogue needs nothing new on their side.

**Resumable.** A whole-map pass takes tens of minutes and DCS dropped its connection three times in one
evening while this lot was investigated. Every batch is written to disk as it comes back, and a sweep
restarted on the same plan continues from the first cell not probed yet.
"""

from __future__ import annotations

import json
import math
import time
from collections.abc import Callable, Iterable
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from veaf_libs.clear_ground_catalogue import (
    STATE_PENDING,
    Catalogue,
    GridSpec,
    Layer,
)

#: Runs a Lua chunk in the survey mission and returns what it returned, as a string.
LuaExec = Callable[[str], str]

#: The probe, identical to ``veafUnits.SETTLE_UNIT_PROBE`` / ``SETTLE_UNIT_CLEARANCE`` and to
#: ``veaf.SPAWN_SEARCH_ATTEMPTS``: the catalogue has to agree with the test ``settleGroup`` applies at
#: runtime, or a position the tools call clear is one the runtime moves anyway.
PROBE_RADIUS_METERS = 20
PROBE_CLEARANCE_METERS = 5
PROBE_ATTEMPTS = 10

#: Coarse pass spacing, whole map (decision 1). **Its radius is not usable**: measured against rings
#: on 12 Caucasus points on 2026-09-28 it promised up to 200 m more than there was, so a coarse pass
#: is only planned when asked for (ticket 01, *Verdict*).
COARSE_SPACING_METERS = 200.0
#: Fine pass spacing, around the places groups are put. 25 m, not the 50 m decision 1 assumed: at 50 m
#: one point in twelve read 170 m clear where a copse stood 60 m away; at 25 m every point was within
#: -20 / +10 m of the reference (ticket 01).
FINE_SPACING_METERS = 25.0
#: Half-side of the square a fine layer covers around its centre.
FINE_HALF_SIDE_METERS = 3000.0
#: Margin added around the airfields when the coarse pass has to guess the map's extent.
COARSE_MARGIN_METERS = 20000.0

#: Cells per call to DCS. Measured on Caucasus on 2026-09-28: 190 ms per call, 0.15 ms per probe, so
#: 10 000 cells spend 1.5 s probing for 0.19 s crossing the bridge. The chunk runs inside one
#: simulation frame, which freezes for that long — acceptable on a mission nobody is flying.
DEFAULT_BATCH_CELLS = 10000

# One character per cell, from the states the catalogue knows. Runtime coordinates: a mission's `y` is
# the runtime's `z`, and a Vec2 carries that `z` in its `y` (docs/agents/dcs-coordinates.md).
_PROBE_FUNCTION_LUA = (
    """
local function probeCell(x, z)
  local v2 = { x = x, y = z }
  local surface = land.getSurfaceType(v2)
  if surface == land.SurfaceType.WATER or surface == land.SurfaceType.SHALLOW_WATER then
    return "W"
  end
  if surface == land.SurfaceType.RUNWAY then
    return "R"
  end
  local ok, candidates = pcall(Disposition.getSimpleZones, { x = x, y = land.getHeight(v2), z = z }, @RADIUS@, @CLEARANCE@, @ATTEMPTS@)
  if not ok or type(candidates) ~= "table" then
    return "?"
  end
  if #candidates > 0 then
    return "1"
  end
  return "0"
end
""".replace("@RADIUS@", str(PROBE_RADIUS_METERS))
    .replace("@CLEARANCE@", str(PROBE_CLEARANCE_METERS))
    .replace("@ATTEMPTS@", str(PROBE_ATTEMPTS))
)

_BLOCK_CHUNK_LUA = (
    _PROBE_FUNCTION_LUA
    + """
-- survey:block %(x)r %(y0)r %(spacing)r %(rows)d %(count)d
local out = {}
for r = 0, %(rows)d - 1 do
  for i = 0, %(count)d - 1 do
    out[#out + 1] = probeCell(%(x)r + r * %(spacing)r, %(y0)r + i * %(spacing)r)
  end
end
return table.concat(out)
"""
)

# Arbitrary points, as a flat `x, z, x, z…` list: what a mission's own unit positions are checked with.
_POINTS_CHUNK_LUA = (
    _PROBE_FUNCTION_LUA
    + """
-- survey:points %(count)d
local pts = { %(coords)s }
local out = {}
for i = 1, #pts, 2 do
  out[#out + 1] = probeCell(pts[i], pts[i + 1])
end
return table.concat(out)
"""
)

# The reference radius of ticket 01: rings of growing radius, every `step` metres along each ring,
# until one holds a sample that is not clear. Costly — a ring per step — which is the point of
# measuring it against the grid.
_RING_RADIUS_LUA = (
    _PROBE_FUNCTION_LUA
    + """
-- survey:ring %(x)r %(y)r %(step)r %(max)r
local x, z, step, maxRadius = %(x)r, %(y)r, %(step)r, %(max)r
local probes = 1
if probeCell(x, z) ~= "1" then
  return "0 1"
end
local radius = 0
while radius + step <= maxRadius do
  local r = radius + step
  local count = math.ceil(2 * math.pi * r / step)
  for k = 0, count - 1 do
    local a = 2 * math.pi * k / count
    probes = probes + 1
    if probeCell(x + r * math.cos(a), z + r * math.sin(a)) ~= "1" then
      return string.format("%%d %%d", radius, probes)
    end
  end
  radius = r
end
return string.format("%%d %%d", radius, probes)
"""
)

_THEATRE_LUA = 'return tostring(env.mission.theatre) .. " " .. tostring(#coalition.getGroups(1) + #coalition.getGroups(2) + #coalition.getGroups(0))'


class SurveyError(RuntimeError):
    """The sweep cannot proceed; the message says why in terms a mission maker can act on."""


@dataclass(frozen=True)
class PlannedLayer:
    """A layer the sweep will fill."""

    name: str
    grid: GridSpec

    def to_dict(self) -> dict[str, Any]:
        """Serialise to a JSON-ready dict."""
        return {"name": self.name, "grid": self.grid.to_dict()}


def grid_around(name: str, x: float, y: float, half_side: float, spacing: float) -> PlannedLayer:
    """Plan a square layer centred on a point, snapped to multiples of ``spacing``.

    Snapping makes two sweeps of the same place land on the same cells, whatever centre was asked.

    Args:
        name: The layer's name.
        x: Mission ``x`` of the centre.
        y: Mission ``y`` of the centre.
        half_side: Half the side of the square.
        spacing: Cell spacing.

    Returns:
        The planned layer.
    """
    x0 = math.floor((x - half_side) / spacing) * spacing
    y0 = math.floor((y - half_side) / spacing) * spacing
    cells = int(math.ceil(2 * half_side / spacing)) + 1
    return PlannedLayer(name, GridSpec(x0, y0, spacing, cells, cells))


def grid_over(name: str, bounds: tuple[float, float, float, float], spacing: float) -> PlannedLayer:
    """Plan a layer over ``(min_x, min_y, max_x, max_y)``, snapped to multiples of ``spacing``.

    Args:
        name: The layer's name.
        bounds: The extent to cover, in mission coordinates.
        spacing: Cell spacing.

    Returns:
        The planned layer.
    """
    min_x, min_y, max_x, max_y = bounds
    x0 = math.floor(min_x / spacing) * spacing
    y0 = math.floor(min_y / spacing) * spacing
    rows = int(math.ceil((max_x - x0) / spacing)) + 1
    cols = int(math.ceil((max_y - y0) / spacing)) + 1
    return PlannedLayer(name, GridSpec(x0, y0, spacing, rows, cols))


def airfield_positions(theatre: str) -> list[tuple[str, float, float]]:
    """Return ``(name, x, y)`` for every airbase the shipped data knows on a theatre.

    Args:
        theatre: The DCS theatre name.

    Returns:
        The airbases, in mission coordinates; empty when the theatre is unknown.
    """
    import yaml  # noqa: PLC0415

    from veaf_libs.bundled_data import read_bundled_text  # noqa: PLC0415
    from veaf_libs.coordinates import is_theatre_supported, latlon_to_xy  # noqa: PLC0415

    if not is_theatre_supported(theatre):
        return []
    data = yaml.safe_load(read_bundled_text("veaf_libs", "data", "airdrome-positions.yaml"))
    positions = []
    for entry in data.get("theatres", {}).get(theatre, []) or []:
        x, y = latlon_to_xy(theatre, float(entry["lat"]), float(entry["lon"]))
        positions.append((str(entry["name"]), x, y))
    return positions


def plan_sweep(
    theatre: str,
    *,
    zones: Iterable[tuple[str, float, float]] = (),
    bounds: tuple[float, float, float, float] | None = None,
    coarse: bool = False,
    airfields: bool = True,
) -> list[PlannedLayer]:
    """Plan the two passes of decision 1: coarse over the map, fine around the places that matter.

    Args:
        theatre: The DCS theatre name.
        zones: ``(name, x, y)`` of the combat zones to cover finely.
        bounds: The coarse pass's extent; by default the airfields' extent plus
            :data:`COARSE_MARGIN_METERS`, since DCS offers no call that returns a map's edges.
        coarse: Plan the coarse pass — off by default, its radius being unreliable
            (:data:`COARSE_SPACING_METERS`).
        airfields: Plan a fine layer around every airfield.

    Returns:
        The layers, coarse first.

    Raises:
        SurveyError: If a coarse pass is asked with no bounds and no airfield to derive them from.
    """
    fields = airfield_positions(theatre) if (airfields or (coarse and bounds is None)) else []
    layers: list[PlannedLayer] = []
    if coarse:
        if bounds is None:
            if not fields:
                raise SurveyError(f"no airfield known on {theatre}, so the map's extent must be given")
            xs, ys = [f[1] for f in fields], [f[2] for f in fields]
            bounds = (
                min(xs) - COARSE_MARGIN_METERS,
                min(ys) - COARSE_MARGIN_METERS,
                max(xs) + COARSE_MARGIN_METERS,
                max(ys) + COARSE_MARGIN_METERS,
            )
        layers.append(grid_over("coarse", bounds, COARSE_SPACING_METERS))
    for name, x, y in zones:
        layers.append(grid_around(f"zone:{name}", x, y, FINE_HALF_SIDE_METERS, FINE_SPACING_METERS))
    if airfields:
        for name, x, y in fields:
            layers.append(grid_around(f"airfield:{name}", x, y, FINE_HALF_SIDE_METERS, FINE_SPACING_METERS))
    return layers


def combat_zones_of(miz_path: Path) -> list[tuple[str, float, float]]:
    """Return ``(name, x, y)`` of the trigger zones named ``combatZone...`` in a mission.

    Args:
        miz_path: The mission to read — a ``.miz``, or a mission folder (its ``src/mission``), which is
            what a mission maker has in hand before building.

    Returns:
        The combat zones, in the mission's order.
    """
    from mission_tools.miz_tools import read_mission_folder, read_miz  # noqa: PLC0415

    mission = read_mission_folder(miz_path) if miz_path.is_dir() else read_miz(miz_path)
    content = mission.mission_content or {}
    zones = content.get("triggers", {}).get("zones", {}) or {}
    items = zones.values() if isinstance(zones, dict) else zones
    return [
        (str(z["name"]), float(z["x"]), float(z["y"]))
        for z in items
        if isinstance(z, dict) and str(z.get("name", "")).startswith("combatZone")
    ]


def build_survey_mission(theatre: str, out_path: Path, bridge_lua: Path) -> Path:
    """Write a mission holding no unit at all, carrying the bridge the sweep talks through.

    Args:
        theatre: The DCS theatre name.
        out_path: The ``.miz`` to write.
        bridge_lua: The ``dcs-bridge.lua`` to embed.

    Returns:
        ``out_path``.
    """
    from mission_tools.miz_tools import create_miz  # noqa: PLC0415

    from veaf_libs.blank_mission import generate_blank_mission  # noqa: PLC0415
    from veaf_libs.dcs_bridge_capture import inject_bridge  # noqa: PLC0415

    out_path.parent.mkdir(parents=True, exist_ok=True)
    create_miz(out_path, generate_blank_mission(theatre))
    inject_bridge(out_path, bridge_lua)
    return out_path


def check_survey_mission(exec_lua: LuaExec, theatre: str) -> None:
    """Refuse to sweep anything but an empty mission on the expected theatre.

    Args:
        exec_lua: The transport.
        theatre: The theatre the plan was made for.

    Raises:
        SurveyError: If the running mission is on another theatre, or holds groups.
    """
    running, groups = exec_lua(_THEATRE_LUA).rsplit(" ", 1)
    if running != theatre:
        raise SurveyError(f"the running mission is on {running}, the sweep was planned for {theatre}")
    if int(groups) != 0:
        raise SurveyError(
            f"the running mission holds {groups} groups: the probe counts vehicles as obstacles, so the "
            "sweep would record them as scenery — load the survey mission, which holds none"
        )


def probe_row_chunk(exec_lua: LuaExec, x: float, y0: float, spacing: float, count: int) -> bytes:
    """Probe ``count`` cells along one row and return one state byte per cell.

    Args:
        exec_lua: The transport.
        x: Mission ``x`` of the row.
        y0: Mission ``y`` of its first cell.
        spacing: Cell spacing.
        count: Cells to probe.

    Returns:
        ``count`` state bytes.

    Raises:
        SurveyError: If DCS returns anything but one known state per cell.
    """
    return probe_block(exec_lua, x, y0, spacing, 1, count)


def probe_block(exec_lua: LuaExec, x: float, y0: float, spacing: float, rows: int, count: int) -> bytes:
    """Probe ``rows`` rows of ``count`` cells in one call, row-major, one state byte per cell.

    Whole rows go in one call because the call, not the probe, is what costs: measured on Caucasus on
    2026-09-28, **190 ms per call against 0.15 ms per probe**, so a 241-cell row alone would spend
    84 % of its time crossing the bridge.

    Args:
        exec_lua: The transport.
        x: Mission ``x`` of the first row.
        y0: Mission ``y`` of the first column.
        spacing: Cell spacing, along both axes.
        rows: Rows to probe.
        count: Cells per row.

    Returns:
        ``rows * count`` state bytes.

    Raises:
        SurveyError: If DCS returns anything but one known state per cell.
    """
    code = _BLOCK_CHUNK_LUA % {
        "x": float(x),
        "y0": float(y0),
        "spacing": float(spacing),
        "rows": rows,
        "count": count,
    }
    result = exec_lua(code).encode("ascii", errors="replace")
    expected = rows * count
    if len(result) != expected or any(chr(b) not in "10WR?" for b in result):
        raise SurveyError(f"unexpected probe answer ({len(result)} bytes for {expected} cells): {result[:80]!r}")
    return result


def probe_points(exec_lua: LuaExec, points: list[tuple[float, float]], batch: int = DEFAULT_BATCH_CELLS) -> bytes:
    """Probe arbitrary points (mission ``x``, ``y``), one state byte each, in batches.

    Args:
        exec_lua: The transport.
        points: The points to probe.
        batch: At most this many points per call to DCS.

    Returns:
        One state byte per point, in order.

    Raises:
        SurveyError: If DCS returns anything but one known state per point.
    """
    answers = bytearray()
    for start in range(0, len(points), batch):
        chunk = points[start : start + batch]
        coords = ", ".join(f"{float(x)!r}, {float(y)!r}" for x, y in chunk)
        result = exec_lua(_POINTS_CHUNK_LUA % {"count": len(chunk), "coords": coords}).encode("ascii", errors="replace")
        if len(result) != len(chunk) or any(chr(b) not in "10WR?" for b in result):
            raise SurveyError(f"unexpected probe answer ({len(result)} bytes for {len(chunk)} points): {result[:80]!r}")
        answers += result
    return bytes(answers)


class SweepState:
    """The on-disk progress of a sweep: the plan, and one state file per layer.

    Args:
        directory: Where the progress lives. Created when missing.
        theatre: The theatre swept.
        layers: The plan.
    """

    def __init__(self, directory: Path, theatre: str, layers: list[PlannedLayer]) -> None:
        self.directory = directory
        self.theatre = theatre
        self.layers = layers
        self.states: dict[str, bytearray] = {}

    def _plan_document(self) -> dict[str, Any]:
        return {"theatre": self.theatre, "layers": [layer.to_dict() for layer in self.layers]}

    def _path(self, index: int) -> Path:
        return self.directory / f"layer-{index:04d}.states"

    def open(self, *, restart: bool = False) -> None:
        """Load the progress of the same plan, or start a new one.

        Args:
            restart: Throw away the progress of a different plan instead of refusing.

        Raises:
            SurveyError: If the directory holds the progress of another plan and ``restart`` is false.
        """
        self.directory.mkdir(parents=True, exist_ok=True)
        plan_path = self.directory / "plan.json"
        plan = self._plan_document()
        if plan_path.is_file() and json.loads(plan_path.read_text(encoding="utf-8")) != plan:
            if not restart:
                raise SurveyError(f"{self.directory} holds a sweep of another plan; pass --restart to throw it away")
            for stale in self.directory.glob("layer-*.states"):
                stale.unlink()
        plan_path.write_text(json.dumps(plan, indent=1, sort_keys=True), encoding="utf-8")
        for index, layer in enumerate(self.layers):
            path = self._path(index)
            if path.is_file() and path.stat().st_size == layer.grid.size:
                self.states[layer.name] = bytearray(path.read_bytes())
            else:
                self.states[layer.name] = bytearray([STATE_PENDING]) * layer.grid.size

    def save(self, index: int) -> None:
        """Write one layer's progress, atomically so an interruption cannot leave half a file."""
        layer = self.layers[index]
        path = self._path(index)
        partial = path.with_suffix(".partial")
        partial.write_bytes(self.states[layer.name])
        partial.replace(path)

    def pending(self) -> int:
        """Number of cells not probed yet, all layers together."""
        return sum(states.count(STATE_PENDING) for states in self.states.values())

    def catalogue(self) -> Catalogue:
        """Build the catalogue from a finished sweep.

        Raises:
            SurveyError: If cells are still pending.
        """
        if self.pending():
            raise SurveyError(f"{self.pending()} cells are not probed yet; resume the sweep first")
        layers = [Layer(p.name, p.grid, bytearray(self.states[p.name])) for p in self.layers]
        for layer in layers:
            layer.derive_radii()
        return Catalogue(self.theatre, layers)


def sweep(
    state: SweepState,
    exec_lua: LuaExec,
    *,
    batch_cells: int = DEFAULT_BATCH_CELLS,
    on_progress: Callable[[int, int, str], None] | None = None,
) -> None:
    """Probe every pending cell of every layer, saving after each batch.

    A batch is as many **whole rows** as fit in ``batch_cells``, or a slice of one row when a row
    alone is longer. Progress is kept per cell, so an interrupted sweep resumes at its first cell
    not probed yet.

    Args:
        state: The opened progress.
        exec_lua: The transport.
        batch_cells: At most this many cells per call to DCS.
        on_progress: Called with ``(done, total, layer name)`` after every batch.
    """
    total = sum(layer.grid.size for layer in state.layers)
    done = total - state.pending()
    for index, layer in enumerate(state.layers):
        grid, states = layer.grid, state.states[layer.name]
        row = 0
        while row < grid.rows:
            start = row * grid.cols
            if STATE_PENDING not in states[start : start + grid.cols]:
                row += 1
                continue
            col = states.index(STATE_PENDING, start) - start
            rows = 1
            if col == 0 and grid.cols <= batch_cells:
                # Extend over the following rows while they are wholly pending.
                limit = min(batch_cells // grid.cols, grid.rows - row)
                while rows < limit and _row_is_pending(states, grid, row + rows):
                    rows += 1
                count = grid.cols
            else:
                count = min(batch_cells, grid.cols - col)
            x, y0 = grid.cell_position(row, col)
            begin = start + col
            states[begin : begin + rows * count] = probe_block(exec_lua, x, y0, grid.spacing, rows, count)
            state.save(index)
            done += rows * count
            if on_progress:
                on_progress(done, total, layer.name)
            if rows > 1 or col + count >= grid.cols:
                row += rows


def _row_is_pending(states: bytearray, grid: GridSpec, row: int) -> bool:
    """Tell whether no cell of a row has been probed yet.

    Args:
        states: A layer's probe answers.
        grid: The layer's grid.
        row: The row.

    Returns:
        True when every cell of the row is still pending.
    """
    start = row * grid.cols
    return states.count(STATE_PENDING, start, start + grid.cols) == grid.cols


@dataclass(frozen=True)
class RadiusSample:
    """One point of the ticket 01 comparison."""

    x: float
    y: float
    ring_radius: float
    ring_probes: int
    ring_seconds: float
    grid_radius: dict[float, float]


@dataclass(frozen=True)
class CostReport:
    """What ticket 01 measures."""

    call_overhead_seconds: float
    seconds_per_probe: float
    samples: list[RadiusSample]

    def to_dict(self) -> dict[str, Any]:
        """Serialise to a JSON-ready dict."""
        return {
            "call_overhead_seconds": self.call_overhead_seconds,
            "seconds_per_probe": self.seconds_per_probe,
            "samples": [sample.__dict__ for sample in self.samples],
        }


def measure_cost(
    exec_lua: LuaExec,
    points: list[tuple[float, float]],
    *,
    ring_step: float = 20.0,
    ring_max: float = 500.0,
    grid_spacings: tuple[float, ...] = (FINE_SPACING_METERS, COARSE_SPACING_METERS),
    clock: Callable[[], float] = time.perf_counter,
) -> CostReport:
    """Measure what a catalogued point costs, and how far the grid's radius is from a ring's (ticket 01).

    Args:
        exec_lua: The transport, to an empty mission.
        points: ``(x, y)`` sample points, in mission coordinates.
        ring_step: Ring spacing of the reference method.
        ring_max: Where the reference method stops.
        grid_spacings: The grid spacings to compare with it.
        clock: Wall clock, injectable for tests.

    Returns:
        The report.
    """
    # The fixed price of one call, measured with an empty chunk.
    start = clock()
    for _ in range(5):
        exec_lua("return ''")
    overhead = (clock() - start) / 5

    # The price of one probe, from one long row, less the fixed price.
    count = 2000
    start = clock()
    probe_row_chunk(exec_lua, points[0][0], points[0][1], FINE_SPACING_METERS, count)
    per_probe = max(0.0, (clock() - start - overhead) / count)

    samples = []
    for x, y in points:
        start = clock()
        radius, probes = exec_lua(
            _RING_RADIUS_LUA % {"x": float(x), "y": float(y), "step": ring_step, "max": ring_max}
        ).split()
        ring_seconds = clock() - start
        grid_radius = {}
        for spacing in grid_spacings:
            # Centred on the sample itself, not snapped: a snapped grid puts its nearest cell up to
            # 0.7 spacing away, 140 m at the coarse spacing, and compares two different places.
            half = math.ceil((ring_max + 2 * spacing) / spacing)
            grid = GridSpec(x - half * spacing, y - half * spacing, spacing, 2 * half + 1, 2 * half + 1)
            states = bytearray()
            for row in range(grid.rows):
                row_x, row_y0 = grid.cell_position(row, 0)
                states += probe_row_chunk(exec_lua, row_x, row_y0, spacing, grid.cols)
            built = Layer("sample", grid, states)
            built.derive_radii()
            grid_radius[spacing] = built.radius_at(half, half)
        samples.append(RadiusSample(x, y, float(radius), int(probes), ring_seconds, grid_radius))
    return CostReport(overhead, per_probe, samples)
