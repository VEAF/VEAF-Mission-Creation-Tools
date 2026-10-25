"""`set_route` — write a players' flight plan into `src/waypoints.yaml` in one action (FIX-COWORK-SESSION-FINDINGS 11).

An assistant used to write its route by search-and-replace in `waypoints.yaml` (`edit_mission_file`):
the template's example points replaced by a two-kilobyte block, every altitude computed by hand from
`terrain_elevation`, the plan edited in a second call — and two points named COAST, the second of which
replaced the first in the cockpit. This takes the ordered points, sets each on the ground (the flight
altitude belongs to the briefing), refuses a repeated name, and writes the points and their plan with
the rest of the file and its comments untouched.
"""

from __future__ import annotations

import math
import re
from pathlib import Path
from typing import Any

from campaign_manager.mission_picture import NM
from mission_tools.mission_yaml_editor import _yaml, load_yaml, save_yaml
from ruamel.yaml.comments import CommentedMap, CommentedSeq
from veaf_libs.coordinates import latlon_to_xy
from veaf_libs.terrain_elevation import grid_for_theatre

from veaf_mission_mcp.map_tools import mission_theatre

#: The flight plans' file, in the mission folder.
WAYPOINTS_FILE = Path("src") / "waypoints.yaml"

_KNOT = 1852 / 3600


def _slug(text: str) -> str:
    """``FEET WET`` -> ``FEET_WET``: the part of a waypoint key that comes from its name."""
    return re.sub(r"[^A-Za-z0-9]+", "_", text).strip("_").upper()


def _position(theatre: str, point: dict[str, Any]) -> tuple[float, float]:
    """A point's mission ``x``/``y``, given as such or as ``lat``/``lon``.

    Raises:
        ValueError: When the point carries neither.
    """
    if "x" in point and "y" in point:
        return float(point["x"]), float(point["y"])
    if "lat" in point and "lon" in point:
        return latlon_to_xy(theatre, float(point["lat"]), float(point["lon"]))
    raise ValueError(f"point {point.get('name')!r} has no position: give x and y, or lat and lon")


def set_route(
    folder: Path,
    *,
    plan: str,
    points: list[dict[str, Any]],
    coalition: str = "blue",
    category: str = "plane",
    aircraft_type: str | None = None,
    country: str | None = None,
) -> dict[str, Any]:
    """Write a flight plan and its points into a mission folder's ``src/waypoints.yaml``.

    Args:
        folder: The mission folder.
        plan: The plan's name; a plan of that name is replaced, and its points no other plan uses go.
        points: In flight order, each ``{"name", "x", "y"}`` or ``{"name", "lat", "lon"}``, optionally
            ``speed_kt``. Names must differ: the cockpit shows them, and the build refuses a repeat.
        coalition: Which aircraft get the plan: ``blue`` or ``red``.
        category: ``plane`` or ``helicopter``.
        aircraft_type: A DCS type, to give the plan to that type only (it then wins over a plan without).
        country: A country, to narrow it further.

    Returns:
        ``{file, backup, plan, points: [{key, name, x, y, alt_m}], legs: [{from, to, heading, nm}],
        warnings}``; ``backup`` is ``None`` when the file did not exist.

    Raises:
        ValueError: An empty list, a point with no position, or two points with one name.
    """
    if not points:
        raise ValueError("set_route needs at least one point")
    theatre = mission_theatre(folder)
    names = [str(point.get("name") or "").strip() for point in points]
    if not all(names):
        raise ValueError("every point needs a name: the cockpit shows it, and the briefing cites it")
    seen: dict[str, str] = {}
    for name in names:
        if _slug(name) in seen:
            raise ValueError(
                f"two points named {seen[_slug(name)]!r} and {name!r}: the cockpit and the briefing "
                "could not tell them apart; give each its own name (FEET WET and FEET DRY rather than COAST twice)"
            )
        seen[_slug(name)] = name

    grid = grid_for_theatre(theatre)
    warnings = (
        []
        if grid
        else [
            f"no elevation grid for {theatre} on this PC: the points are written at sea level "
            "(see the terrain_elevation action)"
        ]
    )
    prefix = _slug(plan)
    resolved: list[dict[str, Any]] = []
    for name, point in zip(names, points, strict=True):
        x, y = _position(theatre, point)
        ground = grid.elevation_at(x, y) if grid else None
        resolved.append(
            {
                "key": f"{prefix}_{_slug(name)}",
                "name": name,
                "x": round(x),
                "y": round(y),
                "alt_m": round(ground or 0.0),
                "speed_kt": point.get("speed_kt"),
            }
        )

    path = folder / WAYPOINTS_FILE
    data = load_yaml(path) if path.is_file() else CommentedMap()
    if data is None:
        data = CommentedMap()
    waypoints = data.setdefault("waypoints", CommentedMap())
    settings = data.setdefault("settings", CommentedMap())

    previous = list((settings.get(plan) or {}).get("waypoints") or [])
    kept = {key for name, other in settings.items() if name != plan for key in (other or {}).get("waypoints") or []}
    for key in previous:
        if key not in kept and key not in {point["key"] for point in resolved}:
            waypoints.pop(key, None)

    for point in resolved:
        entry = CommentedMap(
            [
                ("type", "Turning Point"),
                ("action", "Turning Point"),
                ("alt", point["alt_m"]),
                ("alt_type", "BARO"),
                ("x", point["x"]),
                ("y", point["y"]),
                ("name", point["name"]),
            ]
        )
        if point["speed_kt"]:
            entry["speed"] = round(float(point["speed_kt"]) * _KNOT, 1)
            entry["speed_type"] = "TAS"
        waypoints[point["key"]] = entry

    selector = CommentedMap([("coalition", coalition), ("category", category)])
    if aircraft_type:
        selector["type"] = aircraft_type
    if country:
        selector["country"] = country
    keys = CommentedSeq([point["key"] for point in resolved])
    selector["waypoints"] = keys
    settings[plan] = selector
    warnings += _shadowing_plans(settings, plan)

    path.parent.mkdir(parents=True, exist_ok=True)
    backup: Path | None = None
    if path.is_file():
        backup = save_yaml(path, data)
    else:
        _first_write(path, data)

    legs = []
    for a, b in zip(resolved, resolved[1:], strict=False):
        dx, dy = b["x"] - a["x"], b["y"] - a["y"]
        legs.append(
            {
                "from": a["name"],
                "to": b["name"],
                "heading": round(math.degrees(math.atan2(dy, dx))) % 360 or 360,
                "nm": round(math.hypot(dx, dy) / NM),
            }
        )
    return {
        "file": str(WAYPOINTS_FILE).replace("\\", "/"),
        "backup": str(backup) if backup else None,
        "plan": plan,
        "points": [{k: v for k, v in point.items() if k != "speed_kt"} for point in resolved],
        "legs": legs,
        "warnings": warnings,
    }


_CRITERIA = ("coalition", "category", "type", "country")


def _shadowing_plans(settings: CommentedMap, plan: str) -> list[str]:
    """Name the plans that take this plan's aircraft from it: as specific or more, and declared first on a tie.

    The injector gives an aircraft the most specific matching plan, the first declared on a tie
    (`WaypointsManager.get_flight_plan_for`): the template's ``all_blue_planes`` beats a plan written after
    it with the same coalition and category.

    Returns:
        One warning per such plan.
    """
    ours = {key: settings[plan].get(key) for key in _CRITERIA if settings[plan].get(key)}
    names = list(settings)
    warnings = []
    for name in names:
        other = settings[name]
        if name == plan or not isinstance(other, dict):
            continue
        theirs = {key: other.get(key) for key in _CRITERIA if other.get(key)}
        if any(ours.get(key) not in (None, value) for key, value in theirs.items()):
            continue  # their criteria exclude some of our aircraft
        if len(theirs) > len(ours) or (len(theirs) == len(ours) and names.index(name) < names.index(plan)):
            warnings.append(
                f"plan '{name}' matches the same aircraft and wins over '{plan}' (as specific or more, declared "
                f"first): remove it from src/waypoints.yaml, or give '{plan}' an aircraft_type"
            )
    return warnings


def _first_write(path: Path, data: CommentedMap) -> None:
    """Write a `waypoints.yaml` that did not exist: nothing to back up."""
    with path.open("w", encoding="utf-8", newline="\n") as handle:
        _yaml().dump(data, handle)
