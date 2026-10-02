"""Build-time mirror of the rule a QRA or an air wave applies to each editor aircraft group it deploys.

At runtime (`veafAircraftSpawn.needsZoneDefense`, FEAT-AIRCRAFT-ROLES), a group tasked ``CAP`` or
``Intercept`` whose route engages no aircraft is not flown as the editor wrote it: it is given the
``zone_defense`` role, a race-track across the zone and the CAP watchdog. That is what the mission maker
wants when he placed an interceptor with one waypoint and nothing else — and a surprise when he wrote a
route of his own and forgot the engagement task. The build says which is which:

* an empty route (at most one waypoint, carrying nothing but options) → :data:`ROUTE_ZONE_DEFENSE`,
  information: the script gives the group its job — the case this lot was opened for, which the mission
  maker has to be told about since nothing in the editor shows it;
* a route written without air engagement → :data:`ROUTE_REPLACED`, a non-blocking warning;
* a route that engages air → :data:`ROUTE_ENGAGES_AIR`, information: it is flown as written.

Any other task — a bomber wave, an escort — flies its route and is not reported. The tables below are
the Lua ones; ``test_aircraft_roles.py`` compares the two.
"""

from __future__ import annotations

from typing import Any

from veaf_libs.mission_table import indexed

from mission_builder.group_validation import collect_declared_groups

#: Target types that make an engagement task an **air** engagement (`veafAircraftSpawn.AIR_TARGET_TYPES`).
AIR_TARGET_TYPES: tuple[str, ...] = (
    "Air",
    "Planes",
    "Helicopters",
    "Fighters",
    "Multirole fighters",
    "Bombers",
    "Strategic bombers",
    "Battle airplanes",
    "Battleplanes",
    "AWACS",
    "Tankers",
    "Transports",
    "UAVs",
    "Attack helicopters",
    "Transport helicopters",
)

#: Engagement tasks whose ``targetTypes`` are read (`veafAircraftSpawn.ENGAGE_TASK_IDS`).
ENGAGE_TASK_IDS: frozenset[str] = frozenset({"EngageTargets", "EngageTargetsInZone"})

#: Editor group tasks the runtime may give the ``zone_defense`` role (`veafAircraftSpawn.ZONE_DEFENSE_TASKS`).
ZONE_DEFENSE_TASKS: frozenset[str] = frozenset({"CAP", "Intercept"})

#: The route is empty: the runtime gives the group the ``zone_defense`` role, as intended.
ROUTE_ZONE_DEFENSE = "zone_defense"

#: The route was written without air engagement: the runtime replaces it with ``zone_defense``.
ROUTE_REPLACED = "replaced"

#: The route engages air: the runtime flies it as written.
ROUTE_ENGAGES_AIR = "engages_air"

#: The sections whose deploy lists are flown by a QRA or an air wave.
_DEPLOYING_SECTIONS = ("QRA", "AIRWAVES")

#: Group categories a QRA or an air wave can give a role to.
_AIRCRAFT_CATEGORIES = ("plane", "helicopter")


def _tasks_of(point: Any) -> list[Any]:
    """Return the tasks a route point carries; a ``ComboTask`` holds them in ``params.tasks``.

    Args:
        point: One route point, as parsed from the mission table.

    Returns:
        The point's tasks, empty when it has none.
    """
    task = point.get("task") if isinstance(point, dict) else None
    if not isinstance(task, dict):
        return []
    if task.get("id") == "ComboTask":
        params = task.get("params")
        return indexed(params.get("tasks")) if isinstance(params, dict) else []
    return [task]


def route_engages_air(points: Any) -> bool:
    """Tell whether a route makes its group engage aircraft.

    True when one of its points carries an enabled ``EngageTargets`` or ``EngageTargetsInZone`` task
    whose target types include an aircraft type — `veafAircraftSpawn.routeEngagesAir`.

    Args:
        points: The route points, as a list or as a 1-based dict.

    Returns:
        Whether the route engages air.
    """
    for point in indexed(points):
        for task in _tasks_of(point):
            if not isinstance(task, dict) or task.get("id") not in ENGAGE_TASK_IDS or task.get("enabled") is False:
                continue
            params = task.get("params")
            target_types = indexed(params.get("targetTypes")) if isinstance(params, dict) else []
            if any(target_type in AIR_TARGET_TYPES for target_type in target_types):
                return True
    return False


def is_empty_route(points: Any) -> bool:
    """Tell whether a route leaves the group's job to the framework.

    At most one waypoint, carrying nothing but options (``WrappedAction``): the shape ``create_qra``
    writes, and what a mission maker places when the QRA module is to do the rest.

    Args:
        points: The route points, as a list or as a 1-based dict.

    Returns:
        Whether the route is empty.
    """
    route = indexed(points)
    if len(route) > 1:
        return False
    return all(
        isinstance(task, dict) and task.get("id") == "WrappedAction" for point in route for task in _tasks_of(point)
    )


def classify_deployed_group(group: dict[str, Any]) -> str | None:
    """Say what the runtime will do with the route of an aircraft group a QRA or a wave deploys.

    Args:
        group: The group, as parsed from the mission table.

    Returns:
        :data:`ROUTE_ZONE_DEFENSE`, :data:`ROUTE_REPLACED`, :data:`ROUTE_ENGAGES_AIR`, or None for a task
        other than ``CAP`` / ``Intercept``, whose route is the mission.
    """
    if group.get("task") not in ZONE_DEFENSE_TASKS:
        return None
    route = group.get("route")
    points = route.get("points") if isinstance(route, dict) else None
    if route_engages_air(points):
        return ROUTE_ENGAGES_AIR
    if is_empty_route(points):
        return ROUTE_ZONE_DEFENSE
    return ROUTE_REPLACED


def _aircraft_groups_by_name(mission_content: dict[str, Any]) -> dict[str, dict[str, Any]]:
    """Return every plane and helicopter group of the mission, by name.

    Args:
        mission_content: The parsed DCS mission table.

    Returns:
        The groups, keyed by their name.
    """
    groups: dict[str, dict[str, Any]] = {}
    coalitions = mission_content.get("coalition") or {}
    for coalition in coalitions.values() if isinstance(coalitions, dict) else []:
        for country in indexed(coalition.get("country")) if isinstance(coalition, dict) else []:
            for category in _AIRCRAFT_CATEGORIES:
                container = country.get(category) if isinstance(country, dict) else None
                for group in indexed(container.get("group")) if isinstance(container, dict) else []:
                    if isinstance(group, dict) and (name := group.get("name")):
                        groups[str(name)] = group
    return groups


def find_deployed_aircraft_routes(
    mission_yaml: dict[str, Any], mission_content: dict[str, Any]
) -> list[tuple[str, str, str]]:
    """Classify each editor aircraft group a QRA or an air wave deploys.

    Args:
        mission_yaml: The parsed ``mission.yaml``.
        mission_content: The parsed DCS mission table.

    Returns:
        ``(section, group_name, verdict)`` for each group with something to report, in declaration
        order and once per group; a missing group is :func:`find_missing_declared_groups`'s business.
    """
    aircraft = _aircraft_groups_by_name(mission_content)
    findings: list[tuple[str, str, str]] = []
    seen: set[str] = set()
    for section, name in collect_declared_groups(mission_yaml):
        if section not in _DEPLOYING_SECTIONS or name in seen or name not in aircraft:
            continue
        seen.add(name)
        if verdict := classify_deployed_group(aircraft[name]):
            findings.append((section, name, verdict))
    return findings
