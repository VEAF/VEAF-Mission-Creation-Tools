"""Check that a ground unit is not in the sea and a ship not on land, where the elevation grid exists.

An Avenger battery was placed at Paphos at 0 m — in the sea — with no warning, while the theatre's
elevation grid could have said so (FIX-OPEN-TRAINING-SYRIA-FINDINGS ticket 04).

DCS's ground never reads below 0: the sea reads 0 and ground under sea level reads 3 m (known
limitation ``dcs-ground-is-never-below-sea-level``). So a sample of 0 is the sea, and anything
above it is land — 3 m included. A unit is in the sea only when the whole grid cell around it
is, and a ship on land only when the whole cell is: within a cell of a shore the interpolation says
nothing either way.
"""

from typing import Any

from veaf_libs.mission_table import indexed
from veaf_libs.terrain_elevation import ElevationGrid, grid_for_theatre


def surface_warnings(theatre: str | None, units: Any, *, afloat: bool) -> list[str]:
    """Return the warnings for units placed on the wrong surface.

    Args:
        theatre: The mission's theatre.
        units: The units (a list or an indexed table), each with ``x``, ``y`` and ``name``.
        afloat: True for ships, which belong on water; False for ground units, statics and FARPs.

    Returns:
        One warning per unit on the wrong surface; one "not checked" warning when the theatre has no
        grid; nothing when every unit is where it belongs.
    """
    grid = grid_for_theatre(theatre) if theatre else None
    if grid is None:
        # The same for every placement of the mission: a caller placing several keeps one.
        warning = f"surface not checked: no elevation grid for {theatre or 'this theatre'}"
        return [warning]
    warnings: list[str] = []
    for unit in indexed(units):
        if not isinstance(unit, dict) or "x" not in unit or "y" not in unit:
            continue
        corners = _cell_corners(grid, float(unit["x"]), float(unit["y"]))
        if corners is None:
            continue
        # The whole cell, not the interpolated point: within a cell of a shore, a unit on the beach
        # interpolates to 0 and a ship offshore above it, and neither is wrong.
        if afloat and min(corners) > 0:
            warnings.append(f"ship {unit.get('name')!r} is on land: the ground reads {min(corners)} m or more there")
        elif not afloat and max(corners) == 0:
            warnings.append(f"{unit.get('name')!r} is in the sea: the ground reads 0 m there")
    return warnings


def _cell_corners(grid: ElevationGrid, x: float, y: float) -> list[int] | None:
    """Return the four samples around a point, the same cell :meth:`ElevationGrid.elevation_at` reads.

    Args:
        grid: The theatre's elevation grid.
        x: Mission ``x`` (north), metres.
        y: Mission ``y`` (east), metres.

    Returns:
        The four heights, or ``None`` when the point is off the grid.
    """
    spec = grid.grid
    if not spec.contains(x, y):
        return None
    r0 = min(int((x - spec.origin_x) / spec.spacing), max(spec.rows - 2, 0))
    c0 = min(int((y - spec.origin_y) / spec.spacing), max(spec.cols - 2, 0))
    r1, c1 = min(r0 + 1, spec.rows - 1), min(c0 + 1, spec.cols - 1)
    return [grid.sample(r, c) for r in (r0, r1) for c in (c0, c1)]
