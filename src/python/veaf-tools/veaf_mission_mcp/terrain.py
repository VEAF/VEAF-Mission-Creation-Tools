"""`terrain_elevation` — ground heights, route floors and masking, read with no DCS (FEAT-TERRAIN-ELEVATION).

Answers from the theatre's swept grid (:mod:`veaf_libs.terrain_elevation`). Every answer says what it
is: **terrain only** — no building, pylon or tree — at the grid's spacing; a point off the grid is
``null``, never 0. With no grid for the theatre, the answer says so and how to sweep one.
"""

from typing import Any

from veaf_libs.terrain_elevation import (
    CELL_KINDS,
    ElevationGrid,
    RoutePoint,
    grid_for_theatre,
    maxima_per_cell,
    metres_to_feet,
    profile,
    route_exposure,
)

_CAVEAT = (
    "Terrain only: buildings, pylons and trees are not included. Heights are interpolated between "
    "samples {spacing:g} m apart; a peak between two samples can be higher than any figure here."
)
#: What was measured at the default spacing (``terrain_survey.DEFAULT_SPACING_METERS``), said when a
#: grid has that spacing so a floor can be given a margin that is not a guess.
_MEASURED_AT_250 = (
    " Measured at 250 m on Syria's relief: a point within 15 m 95 % of the time, 81 m at worst, and a leg "
    "is interpolated like a point; a 10 km square's highest sample at most 44 m below the true highest "
    "ground. Add at least 100 m to a floor taken from these figures."
)


def _height(metres: float | None) -> dict[str, int] | None:
    """A height in both units, rounded, or ``None`` off the grid."""
    if metres is None:
        return None
    return {"m": round(metres), "ft": round(metres_to_feet(metres))}


def _route(points: list[dict[str, Any]]) -> list[RoutePoint]:
    """Read route points; ``alt_type`` follows DCS: ``RADIO`` is above the ground, ``BARO`` (default) above sea.

    Raises:
        ValueError: If a point has no ``alt``: defaulting to sea level would put the aircraft under the
            ground and report every leg as masked.
    """
    missing = [i for i, p in enumerate(points) if "alt" not in p]
    if missing:
        raise ValueError(f"route points {missing} have no alt: observers need the route's altitudes")
    return [
        RoutePoint(float(p["x"]), float(p["y"]), float(p["alt"]), str(p.get("alt_type", "BARO")) == "RADIO")
        for p in points
    ]


def _legs(grid: ElevationGrid, route: list[dict[str, Any]]) -> list[dict[str, Any]]:
    return [
        {
            "leg": f"{i}-{i + 1}",
            "length_m": round(leg.length),
            "highest": _height(leg.highest),
            "covered": leg.covered,
        }
        for i, leg in enumerate(profile(grid, [(float(p["x"]), float(p["y"])) for p in route]))
    ]


def _exposure(
    grid: ElevationGrid, route: list[dict[str, Any]], observers: list[dict[str, Any]]
) -> list[dict[str, Any]]:
    points = _route(route)
    table = []
    for observer in observers:
        legs = route_exposure(
            grid,
            (float(observer["x"]), float(observer["y"])),
            float(observer.get("height_agl", 5.0)),
            points,
            max_range=float(observer["range"]),
        )
        table.append(
            {
                "observer": observer.get("name", f"{observer['x']:.0f},{observer['y']:.0f}"),
                "legs": [
                    {
                        "leg": f"{i}-{i + 1}",
                        "in_range_m": round(leg.in_range_length),
                        "seen_m": round(leg.seen_length),
                        "covered": leg.covered,
                    }
                    for i, leg in enumerate(legs)
                ],
            }
        )
    return table


def describe_terrain(
    theatre: str,
    *,
    points: list[dict[str, Any]] | None = None,
    route: list[dict[str, Any]] | None = None,
    observers: list[dict[str, Any]] | None = None,
    area: dict[str, Any] | None = None,
) -> dict[str, Any]:
    """Answer the terrain questions asked, from the theatre's swept grid.

    Args:
        theatre: The DCS theatre, as a mission spells it.
        points: ``{x, y}`` — the ground height at each.
        route: ``{x, y, alt?, alt_type?}`` — the highest ground along each leg; with ``observers``, how
            much of each leg each observer sees.
        observers: ``{name?, x, y, range, height_agl?}`` — radars or SAMs, range in metres, antenna
            height above the ground (default 5 m).
        area: ``{min_x, min_y, max_x, max_y, cell}`` — the highest sample per cell, ``cell`` one of
            :data:`CELL_KINDS`.

    Returns:
        ``{theatre, available, ...}``: when a grid exists, ``spacing_m``, ``caveat`` and one key per
        question asked (``points``, ``legs``, ``exposure``, ``cells``); otherwise ``how`` to sweep it.

    Raises:
        ValueError: If ``observers`` are given without a ``route`` or with a route point lacking ``alt``,
            or ``area.cell`` is unknown.
    """
    grid = grid_for_theatre(theatre)
    if grid is None:
        return {
            "theatre": theatre,
            "available": False,
            "how": (
                f"No elevation grid for {theatre}. One is swept in DCS with "
                f"`.\\veaf-tools.exe dcs terrain-sweep {theatre}` (it needs DCS; offer it to the user). "
                "Until then, ground heights stay an open point to check in game."
            ),
        }
    if observers and not route:
        raise ValueError("observers need a route to look at")
    answer: dict[str, Any] = {
        "theatre": theatre,
        "available": True,
        "spacing_m": grid.grid.spacing,
        "caveat": _CAVEAT.format(spacing=grid.grid.spacing) + (_MEASURED_AT_250 if grid.grid.spacing == 250 else ""),
    }
    if points:
        answer["points"] = [
            {"x": p["x"], "y": p["y"], "ground": _height(grid.elevation_at(float(p["x"]), float(p["y"])))}
            for p in points
        ]
    if route:
        answer["legs"] = _legs(grid, route)
        if observers:
            answer["exposure"] = _exposure(grid, route, observers)
    if area:
        kind = str(area.get("cell", "mgrs10km"))
        if kind not in CELL_KINDS:
            raise ValueError(f"area.cell {kind!r}: expected one of {', '.join(CELL_KINDS)}")
        bounds = (float(area["min_x"]), float(area["min_y"]), float(area["max_x"]), float(area["max_y"]))
        answer["cells"] = [
            {"cell": c.cell, "highest": _height(c.highest), "at": {"x": round(c.x), "y": round(c.y)}}
            for c in maxima_per_cell(grid, bounds, kind)
        ]
    return answer
