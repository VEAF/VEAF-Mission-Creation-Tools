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

from veaf_mission_mcp.group_naming import resolve_group_name, validate_group_name

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
    for_combat_zone: str | None = None,
    late_activation: bool = False,
    as_spawn_template: bool = False,
) -> dict[str, Any]:
    """Add a group to a mission's source `.miz`, in place, backed up first.

    Args:
        miz_path: Path to the mission's source `.miz`.
        coalition: `"blue"`, `"red"` or `"neutral"`.
        country_id: The DCS numeric country id (e.g. 0 for Russia).
        country_name: The DCS country name (e.g. `"Russia"`), used only if the
            country does not exist yet in this coalition.
        category: One of `"vehicle"`, `"plane"`, `"helicopter"`, `"ship"`, `"static"`.
        name: The group's base name (before any naming-intent prefixing).
        position: The group's anchor position, `{"x": ..., "y": ...}`.
        units: `[{"type": <DCS unit type>, "count": <int>, "name"?: <str>}, ...]` — concrete unit
            types are the calling LLM's decision, not this action's. An optional `name` sets the
            unit name (else auto-named); carry a combat-zone marker there, e.g.
            `#command="-armor ..."`.
        route: Optional waypoints (`{"x": ..., "y": ...}`, ...). Defaults to a single
            stationary waypoint at `position`.
        patrol: If true (and `route` has at least 2 points), the last waypoint loops
            back to the first — a DCS ground-unit patrol.
        for_combat_zone: If set, prefix the name with this combat-zone trigger-zone name
            so the group is picked up by that zone (idempotent).
        late_activation: If true, mark the group late-activation (QRA interceptors,
            CAP/on-demand templates).
        as_spawn_template: If true, prefix the name with `veafSpawn-` (registers it as a
            spawnable-aircraft template).

    Returns:
        `{"group_id": <int>, "name": <resolved name>, "warnings": [...]}` — `warnings` flags any
        reserved-naming-convention collision for the caller to relay (the write still happens).

    Raises:
        ValueError: If the archive is not a valid mission, or `units` yields no units.
    """
    mission = read_miz(miz_path)
    if mission.mission_content is None:
        raise ValueError(f"Not a valid DCS mission archive (missing 'mission' file): {miz_path}")

    name = resolve_group_name(name, for_combat_zone=for_combat_zone, as_spawn_template=as_spawn_template)
    group_id = insert_group_into_content(
        mission.mission_content,
        coalition=coalition,
        country_id=country_id,
        country_name=country_name,
        category=category,
        name=name,
        position=position,
        units=units,
        route=route,
        patrol=patrol,
        late_activation=late_activation,
    )

    warnings = validate_group_name(name, miz_path=miz_path, expected_combat_zone=for_combat_zone)["warnings"]

    backup_before_write(miz_path)
    write_miz(mission, miz_path)

    return {"group_id": group_id, "name": name, "warnings": warnings}


def insert_group_into_content(
    mission_content: dict[str, Any],
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
    late_activation: bool = False,
) -> int:
    """Build a group and insert it into `mission_content` in place; return its fresh `groupId`.

    The content-level core shared by the `.miz` action :func:`add_group` and the wave-8 composite
    builders (which mutate a mission folder's exploded content). Does no I/O and no name
    resolution — the caller passes the final `name`.

    Args:
        mission_content: The parsed ``mission`` table to mutate.
        coalition: `"blue"`, `"red"` or `"neutral"`.
        country_id: DCS numeric country id.
        country_name: DCS country name (used only if the country is absent in this coalition).
        category: One of `"vehicle"`, `"plane"`, `"helicopter"`, `"ship"`, `"static"`.
        name: The group's final name.
        position: The group's anchor position.
        units: `[{"type", "count"}, ...]`.
        route: Optional waypoints; defaults to a stationary point at `position`.
        patrol: Loop the route back to its start.
        late_activation: Mark the group late-activation.

    Returns:
        The fresh ``groupId`` assigned to the inserted group.

    Raises:
        ValueError: If `units` yields no units.
    """
    group = _build_group(
        name=name, position=position, units=units, route=route, patrol=patrol, late_activation=late_activation
    )
    return insert_group(
        mission_content,
        coalition=coalition,
        country_id=country_id,
        country_name=country_name,
        category=category,
        group=group,
    )


def _build_group(
    *,
    name: str,
    position: dict[str, float],
    units: list[dict[str, Any]],
    route: list[dict[str, float]] | None,
    patrol: bool,
    late_activation: bool = False,
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
        "lateActivation": late_activation,
        "taskSelected": True,
        "uncontrollable": False,
        "start_time": 0,
    }


def _build_units(units: list[dict[str, Any]], *, position: dict[str, float], group_name: str) -> list[dict[str, Any]]:
    """Expand `[{"type", "count", "name"?}, ...]` into individual, spaced-out unit dicts.

    An explicit ``name`` is honoured verbatim (for ``count == 1``) or suffixed ``"<name> #NN"``
    (for ``count > 1``, to keep DCS unit names unique) — this is how a combat-zone marker such as
    ``#command="-armor ..."`` is carried on the unit name. Without ``name``, units are auto-named.
    """
    built: list[dict[str, Any]] = []
    for spec in units:
        count = spec.get("count", 1)
        explicit_name = spec.get("name")
        for index in range(count):
            if explicit_name:
                unit_name = explicit_name if count == 1 else f"{explicit_name} #{index + 1:02d}"
            else:
                unit_name = f"{group_name} Unit #{len(built) + 1:03d}"
            built.append(
                {
                    "name": unit_name,
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
