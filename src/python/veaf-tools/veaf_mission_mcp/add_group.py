"""`add_group` — editor-parity write action: insert a ground/vehicle group.

Builds a DCS group/unit/route structure from the calling LLM's already-decided unit
types (this server does not curate a unit catalog — see
``.backlog/FEAT-MCP-MISSION-EDITOR/PRD.md``), then delegates the actual mutation to
:func:`mission_tools.group_insertion.add_group`, backed up first
(:func:`mission_tools.miz_backup.backup_before_write`). Mirrors adding a group by hand
in the DCS Mission Editor: not deduplicated, calling this twice creates two groups.
"""

from pathlib import Path
from typing import Any

from mission_tools.group_insertion import add_group as insert_group
from mission_tools.miz_backup import backup_before_write
from mission_tools.miz_tools import read_miz, write_miz

_UNIT_SPACING_METERS = 20
_DEFAULT_SPEED_MPS = 5.5555555555556  # ~20 km/h, a typical DCS ground-group cruise speed


def add_group(
    miz_path: Path,
    *,
    coalition: str,
    country_id: int,
    country_name: str,
    category: str,
    name: str,
    position: dict[str, float],
    units: list[dict[str, Any]],
    route: list[dict[str, float]] | None = None,
    patrol: bool = False,
) -> dict[str, Any]:
    """Add a group to a mission's source `.miz`, in place, backed up first.

    Args:
        miz_path: Path to the mission's source `.miz`.
        coalition: `"blue"`, `"red"` or `"neutral"`.
        country_id: The DCS numeric country id (e.g. 0 for Russia).
        country_name: The DCS country name (e.g. `"Russia"`), used only if the
            country does not exist yet in this coalition.
        category: One of `"vehicle"`, `"plane"`, `"helicopter"`, `"ship"`, `"static"`.
        name: The group's name.
        position: The group's anchor position, `{"x": ..., "y": ...}`.
        units: `[{"type": <DCS unit type>, "count": <int>}, ...]` — concrete unit
            types are the calling LLM's decision, not this action's.
        route: Optional waypoints (`{"x": ..., "y": ...}`, ...). Defaults to a single
            stationary waypoint at `position`.
        patrol: If true (and `route` has at least 2 points), the last waypoint loops
            back to the first — a DCS ground-unit patrol.

    Returns:
        `{"group_id": <int>, "name": <str>}`.

    Raises:
        ValueError: If the archive is not a valid mission, or `units` yields no units.
    """
    mission = read_miz(miz_path)
    if mission.mission_content is None:
        raise ValueError(f"Not a valid DCS mission archive (missing 'mission' file): {miz_path}")

    group = _build_group(name=name, position=position, units=units, route=route, patrol=patrol)

    group_id = insert_group(
        mission.mission_content,
        coalition=coalition,
        country_id=country_id,
        country_name=country_name,
        category=category,
        group=group,
    )

    backup_before_write(miz_path)
    write_miz(mission, miz_path)

    return {"group_id": group_id, "name": name}


def _build_group(
    *,
    name: str,
    position: dict[str, float],
    units: list[dict[str, Any]],
    route: list[dict[str, float]] | None,
    patrol: bool,
) -> dict[str, Any]:
    """Build a DCS group dict ready for `mission_tools.group_insertion.add_group`."""
    built_units = _build_units(units, position=position, group_name=name)
    if not built_units:
        raise ValueError("add_group requires at least one unit")
    return {
        "name": name,
        "x": position["x"],
        "y": position["y"],
        "task": "Ground Nothing",
        "route": _build_route(route or [position], patrol=patrol),
        "units": built_units,
        "visible": False,
        "hidden": False,
        "taskSelected": True,
        "uncontrollable": False,
        "start_time": 0,
    }


def _build_units(units: list[dict[str, Any]], *, position: dict[str, float], group_name: str) -> list[dict[str, Any]]:
    """Expand `[{"type", "count"}, ...]` into individual, spaced-out unit dicts."""
    built: list[dict[str, Any]] = []
    for spec in units:
        for _ in range(spec.get("count", 1)):
            built.append(
                {
                    "name": f"{group_name} Unit #{len(built) + 1:03d}",
                    "type": spec["type"],
                    "x": position["x"] + len(built) * _UNIT_SPACING_METERS,
                    "y": position["y"],
                    "skill": "Average",
                    "heading": 0,
                    "playerCanDrive": True,
                    "coldAtStart": False,
                }
            )
    return built


def _build_route(points: list[dict[str, float]], *, patrol: bool) -> dict[str, Any]:
    """Build a route from waypoints; loop the last one back to the first if `patrol`."""
    waypoints = [_build_waypoint(point, is_first=(i == 0)) for i, point in enumerate(points)]
    if patrol and len(waypoints) >= 2:
        waypoints[-1]["task"] = _patrol_task(first_waypoint_index=1, last_waypoint_index=len(waypoints))
    return {"points": waypoints}


def _build_waypoint(point: dict[str, float], *, is_first: bool) -> dict[str, Any]:
    return {
        "x": point["x"],
        "y": point["y"],
        "alt": point.get("alt", 0),
        "alt_type": "BARO",
        "type": "Turning Point",
        "action": "Off Road" if is_first else "On Road",
        "speed": point.get("speed", _DEFAULT_SPEED_MPS),
        "ETA": 0,
        "ETA_locked": is_first,
        "formation_template": "",
        "name": "",
        "speed_locked": True,
        "task": {"id": "ComboTask", "params": {"tasks": {}}},
    }


def _patrol_task(*, first_waypoint_index: int, last_waypoint_index: int) -> dict[str, Any]:
    """A "Go To Waypoint" task looping the route back to its start — a DCS ground patrol."""
    return {
        "id": "ComboTask",
        "params": {
            "tasks": {
                "1": {
                    "enabled": True,
                    "auto": False,
                    "id": "GoToWaypoint",
                    "number": 1,
                    "params": {"fromWaypoint": last_waypoint_index, "nWaypoint": first_waypoint_index},
                },
            },
        },
    }
