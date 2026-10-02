"""Check that a ground unit is not in the sea and a ship not on land, where the elevation grid exists.

An Avenger battery was placed at Paphos at 0 m — in the sea — with no warning, while the theatre's
elevation grid could have said so (FIX-OPEN-TRAINING-SYRIA-FINDINGS ticket 04).

DCS's ground never reads below 0: the sea reads 0 and ground under sea level reads 3 m (known
limitation ``dcs-ground-is-never-below-sea-level``). So a height that rounds to 0 is the sea, and
anything above it is land — 3 m included.
"""

from typing import Any

from veaf_libs.mission_table import indexed
from veaf_libs.terrain_elevation import grid_for_theatre


def surface_warnings(theatre: str | None, units: Any, *, afloat: bool, label: str) -> list[str]:
    """Return the warnings for units placed on the wrong surface.

    Args:
        theatre: The mission's theatre.
        units: The units (a list or an indexed table), each with ``x``, ``y`` and ``name``.
        afloat: True for ships, which belong on water; False for ground units, statics and FARPs.
        label: How to name the group in the "not checked" warning.

    Returns:
        One warning per unit on the wrong surface; one "not checked" warning when the theatre has no
        grid; nothing when every unit is where it belongs.
    """
    grid = grid_for_theatre(theatre) if theatre else None
    if grid is None:
        warning = f"{label}: surface not checked: no elevation grid for {theatre or 'this theatre'}"
        return [warning]
    warnings: list[str] = []
    for unit in indexed(units):
        if not isinstance(unit, dict) or "x" not in unit or "y" not in unit:
            continue
        height = grid.elevation_at(float(unit["x"]), float(unit["y"]))
        if height is None:
            continue
        metres = round(height)
        if afloat and metres > 0:
            warnings.append(f"ship {unit.get('name')!r} is on land: the ground reads {metres} m there")
        elif not afloat and metres == 0:
            warnings.append(f"{unit.get('name')!r} is in the sea: the ground reads 0 m there")
    return warnings
