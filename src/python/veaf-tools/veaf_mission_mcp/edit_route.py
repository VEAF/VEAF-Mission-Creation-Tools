"""`edit_route` — edit a group's waypoints, and what they tell the flight to do.

Ticket 04 of ``FEAT-MCP-MUTATION-ACTIONS``, the largest of the three the exploration note named:
dcs-sms spends 27 verbs here, more than on units, which says where mission-editing effort actually
goes. Two layers, and the second is where the value is — the route itself is a list operation on
``route.points``; a waypoint's **tasks** are what makes a flight do something.

**The invariant that makes this surgery rather than list editing.**
``FIX-WAYPOINTS-ETA-LOCKED`` established that DCS *refuses to save* a mission whose route has no
waypoint with a locked time (*"Route has no waypoints with locked time!"*), and that the repair is to
lock the first, as DCS itself does. Removing or reordering waypoints can therefore produce a mission
the editor rejects — a failure that surfaces far from the edit that caused it. Every operation here
restores the invariant and **says so** when it had to.

**Units.** The mission table holds metres and metres per second; a mission maker says feet and knots.
As with ``set_unit_properties``' ``heading_deg``, the parameters carry their unit in their name
(``altitude_ft``, ``speed_kt``) and the result reports both, so a caller never converts back.

**Tasks are a named set with validated signatures, not a free-form table.** That is a deliberate
choice from the ticket: a generic "write this task table" action is a foot-gun, because an agent
produces a plausible table, DCS ignores it silently, and the mission maker finds out an hour into
testing that the flight does nothing. The escape hatch starts **closed**.

Every signature below was read out of a real mission, and three are traps a generic writer walks into:

- **``SetFrequency`` takes hertz** (``31000000`` for 31 MHz) while a *group's* frequency is in MHz.
  Two units for the same notion, in the same file.
- **``EngageTargetsInZone`` duplicates its target list** into a serialised ``value`` string
  (``"Air;Cruise missiles;"``) beside the ``targetTypes`` array; writing one alone leaves them
  disagreeing.
- **``SetFrequency`` and ``SwitchWaypoint`` are not tasks** but *actions*, carried inside a
  ``WrappedAction`` envelope.
"""

from pathlib import Path
from typing import Any

from mission_tools.miz_backup import backup_before_write
from mission_tools.miz_tools import read_miz, write_miz

from veaf_mission_mcp.mission_table import find_group, indexed

#: Metres per foot, and metres per second per knot.
_M_PER_FT = 0.3048
_MPS_PER_KT = 0.514444

#: The waypoint types DCS writes, each with the `action` that always accompanies it. The pair is
#: what a real mission carries — measured across this repository's fixtures — and setting `type`
#: without its `action` produces a waypoint the editor shows and DCS does not fly.
_WAYPOINT_TYPES: dict[str, str] = {
    "Turning Point": "Turning Point",
    "Fly Over Point": "Fly Over Point",
    "TakeOff": "From Runway",
    "TakeOffParking": "From Parking Area",
    "TakeOffParkingHot": "From Parking Area Hot",
    "TakeOffGround": "From Ground Area",
    "TakeOffGroundHot": "From Ground Area Hot",
    "Land": "Landing",
}

#: Orbit patterns DCS accepts.
_ORBIT_PATTERNS: tuple[str, ...] = ("Race-Track", "Circle")

#: Group modulation names, as `set_group_properties` spells them.
_MODULATIONS: dict[str, int] = {"AM": 0, "FM": 1}

#: `weaponType` is a DCS weapon-category bitmask, and an attack task **without it is discarded by the
#: Mission Editor on save** (measured 2026-08-15 — a `Bombing` written without it came back with an
#: empty `tasks`). These are the editor's own "Auto" values, taken by frequency across this
#: repository's fixtures rather than invented: `Bombing` 2032 (128 occurrences), `AttackGroup`
#: 9659482112 (8). A caller may override via `weapon_type`.
_WEAPON_TYPE_AUTO: dict[str, int] = {"bombing": 2032, "attack_group": 9659482112}

#: The operations this action performs.
_OPERATIONS: tuple[str, ...] = ("add", "insert", "remove", "reorder", "set", "add_task", "clear_tasks")


def edit_route(
    miz_path: Path,
    *,
    group_name: str,
    operation: str,
    index: int | None = None,
    to_index: int | None = None,
    position: dict[str, float] | None = None,
    name: str | None = None,
    altitude_ft: float | None = None,
    speed_kt: float | None = None,
    waypoint_type: str | None = None,
    eta_locked: bool | None = None,
    task: str | None = None,
    task_params: dict[str, Any] | None = None,
) -> dict[str, Any]:
    """Edit one group's route in place, backed up first.

    Args:
        miz_path: Path to the mission's source `.miz`.
        group_name: The group's **exact** name.
        operation: One of ``add``, ``insert``, ``remove``, ``reorder``, ``set``, ``add_task``,
            ``clear_tasks``.
        index: The 1-based waypoint the operation acts on (every operation but ``add`` needs one).
        to_index: Destination index, for ``reorder``.
        position: ``{"x": ..., "y": ...}`` for ``add`` / ``insert``.
        name: A waypoint name, for ``add``, ``insert`` or ``set``.
        altitude_ft: Altitude in **feet**; stored as metres.
        speed_kt: Speed in **knots**; stored as metres per second.
        waypoint_type: One of the DCS waypoint types; its matching ``action`` is written with it.
        eta_locked: Whether this waypoint's time is locked.
        task: For ``add_task``, one of ``orbit``, ``land``, ``attack_group``, ``bombing``,
            ``engage_targets_in_zone``, ``set_frequency``, ``switch_waypoint``.
        task_params: That task's parameters; each task validates its own and names what is missing.

    Returns:
        ``{group, operation, changed, route, warnings}`` — ``route`` is the resulting route, so a
        caller sees what it just edited without a second read.

    Raises:
        ValueError: If the archive is not a valid mission, the group does not exist or has no route,
            the operation or task is unknown, an index is out of range, a required parameter is
            missing, or removing would leave no waypoint at all.
    """
    if operation not in _OPERATIONS:
        raise ValueError(f"unknown operation {operation!r}; expected one of {', '.join(_OPERATIONS)}")

    mission = read_miz(miz_path)
    if mission.mission_content is None:
        raise ValueError(f"Not a valid DCS mission archive (missing 'mission' file): {miz_path}")

    group = find_group(mission.mission_content, group_name)
    points = _points_list(group, group_name)

    changed: dict[str, Any] = {}
    warnings: list[str] = []

    if operation == "add":
        _add(points, position, name, len(points) + 1, changed, altitude_ft=altitude_ft, speed_kt=speed_kt)
    elif operation == "insert":
        _add(
            points,
            position,
            name,
            _checked_index(index, points, allow_append=True),
            changed,
            altitude_ft=altitude_ft,
            speed_kt=speed_kt,
        )
    elif operation == "remove":
        _remove(points, _checked_index(index, points), changed)
    elif operation == "reorder":
        _reorder(points, _checked_index(index, points), _checked_index(to_index, points, field="to_index"), changed)
    elif operation == "set":
        _set_fields(
            points[_checked_index(index, points) - 1],
            name=name,
            altitude_ft=altitude_ft,
            speed_kt=speed_kt,
            waypoint_type=waypoint_type,
            eta_locked=eta_locked,
            changed=changed,
        )
    elif operation == "add_task":
        _add_task(points[_checked_index(index, points) - 1], task, task_params or {}, changed)
    else:  # clear_tasks
        _clear_tasks(points[_checked_index(index, points) - 1], changed)

    _restore_eta_lock(points, warnings)

    backup_before_write(miz_path)
    write_miz(mission, miz_path)

    return {
        "group": group_name,
        "operation": operation,
        "changed": changed,
        "route": [_described(point, position_index) for position_index, point in enumerate(points, start=1)],
        "warnings": warnings,
    }


def _points_list(group: dict[str, Any], group_name: str) -> list[dict[str, Any]]:
    """Return the group's waypoint list, normalised in place so the caller can mutate it.

    Args:
        group: The group table.
        group_name: Its name, for the error message.

    Returns:
        The waypoint list, held under ``route.points``.

    Raises:
        ValueError: If the group has no route at all — which is a ground group that was never given
            waypoints, and deserves saying so rather than an index error.
    """
    route = group.get("route")
    if not isinstance(route, dict) or route.get("points") is None:
        raise ValueError(
            f"group {group_name!r} has no route: it was never given waypoints, so there is nothing "
            "to edit. Add a route first, or check the group name"
        )
    points = indexed(route.get("points"))
    route["points"] = points
    return points


def _checked_index(
    index: int | None, points: list[dict[str, Any]], *, field: str = "index", allow_append: bool = False
) -> int:
    """Return `index` after checking it addresses a waypoint, or raise naming the valid range.

    Args:
        index: The 1-based index the caller passed.
        points: The current waypoints.
        field: The parameter's name, for the message.
        allow_append: Whether one past the end is valid (inserting at the tail).

    Returns:
        The index.

    Raises:
        ValueError: If `index` is absent or out of range.
    """
    upper = len(points) + 1 if allow_append else len(points)
    if index is None:
        raise ValueError(f"{field} is required for this operation (1..{upper})")
    if not 1 <= int(index) <= upper:
        raise ValueError(f"{field} {index} is out of range: this route has {len(points)} waypoints (1..{upper})")
    return int(index)


def _add(
    points: list[dict[str, Any]],
    position: dict[str, float] | None,
    name: str | None,
    at: int,
    changed: dict[str, Any],
    *,
    altitude_ft: float | None = None,
    speed_kt: float | None = None,
) -> None:
    """Insert a waypoint at 1-based position `at`, honouring altitude/speed or inheriting them.

    When ``altitude_ft``/``speed_kt`` are given they are written (converted); when omitted the new
    waypoint inherits its neighbour's, because a waypoint written with no altitude sits at 0 and a
    flight given one dives into the ground on its way there. DCS's own editor copies the previous
    leg's values too. A caller that passed the parameters used to have them silently dropped.

    Args:
        points: The waypoint list to mutate.
        position: The waypoint's coordinates.
        name: An optional name; defaults to ``WP<n>``.
        at: 1-based insertion position.
        changed: The report to record the change in.
        altitude_ft: Altitude in feet; inherited from the neighbour when omitted.
        speed_kt: Speed in knots; inherited from the neighbour when omitted.

    Raises:
        ValueError: If `position` is missing.
    """
    if position is None or "x" not in position or "y" not in position:
        raise ValueError("position {x, y} is required to add a waypoint")
    reference = points[at - 2] if at >= 2 and points else (points[0] if points else {})
    alt = float(altitude_ft) * _M_PER_FT if altitude_ft is not None else reference.get("alt", 0)
    speed = float(speed_kt) * _MPS_PER_KT if speed_kt is not None else reference.get("speed", 0)
    point: dict[str, Any] = {
        "name": name if name is not None else f"WP{at}",
        "type": "Turning Point",
        "action": "Turning Point",
        "x": float(position["x"]),
        "y": float(position["y"]),
        "alt": alt,
        "alt_type": reference.get("alt_type", "BARO"),
        "speed": speed,
        "ETA": 0,
        "ETA_locked": False,
        "speed_locked": True,
        "task": _empty_combo_task(),
    }
    points.insert(at - 1, point)
    changed["added"] = {"index": at, "name": point["name"]}


def _remove(points: list[dict[str, Any]], index: int, changed: dict[str, Any]) -> None:
    """Remove the waypoint at 1-based `index`.

    Args:
        points: The waypoint list to mutate.
        index: 1-based index.
        changed: The report to record the change in.

    Raises:
        ValueError: If it is the only waypoint left — a route with none is not a route.
    """
    if len(points) == 1:
        raise ValueError(
            "refusing to remove the last waypoint: a route with no waypoints is not a route, and "
            "DCS will not fly the group"
        )
    removed = points.pop(index - 1)
    changed["removed"] = {"index": index, "name": removed.get("name")}


def _reorder(points: list[dict[str, Any]], index: int, to_index: int, changed: dict[str, Any]) -> None:
    """Move the waypoint at `index` to `to_index`, both 1-based.

    Args:
        points: The waypoint list to mutate.
        index: The waypoint to move.
        to_index: Where it goes.
        changed: The report to record the change in.
    """
    point = points.pop(index - 1)
    points.insert(to_index - 1, point)
    changed["reordered"] = {"from": index, "to": to_index, "name": point.get("name")}


def _set_fields(
    point: dict[str, Any],
    *,
    name: str | None,
    altitude_ft: float | None,
    speed_kt: float | None,
    waypoint_type: str | None,
    eta_locked: bool | None,
    changed: dict[str, Any],
) -> None:
    """Set a waypoint's editable fields, converting the units the caller speaks.

    Args:
        point: The waypoint to mutate.
        name: A new name.
        altitude_ft: Altitude in feet.
        speed_kt: Speed in knots.
        waypoint_type: A DCS waypoint type; its `action` travels with it.
        eta_locked: Whether the time is locked.
        changed: The report to record the changes in.

    Raises:
        ValueError: If nothing was given, or the waypoint type is unknown.
    """
    if all(value is None for value in (name, altitude_ft, speed_kt, waypoint_type, eta_locked)):
        raise ValueError("no field given — pass at least one of name, altitude_ft, speed_kt, waypoint_type, eta_locked")
    if name is not None:
        changed["name"] = {"from": point.get("name"), "to": name}
        point["name"] = name
    if altitude_ft is not None:
        metres = float(altitude_ft) * _M_PER_FT
        changed["altitude"] = {"from": point.get("alt"), "to": metres, "to_ft": float(altitude_ft)}
        point["alt"] = metres
    if speed_kt is not None:
        mps = float(speed_kt) * _MPS_PER_KT
        changed["speed"] = {"from": point.get("speed"), "to": mps, "to_kt": float(speed_kt)}
        point["speed"] = mps
    if waypoint_type is not None:
        if waypoint_type not in _WAYPOINT_TYPES:
            raise ValueError(f"unknown waypoint type {waypoint_type!r}; expected one of {', '.join(_WAYPOINT_TYPES)}")
        changed["type"] = {"from": point.get("type"), "to": waypoint_type}
        point["type"] = waypoint_type
        # `action` is not decoration: it is the half of the pair DCS reads to decide how the aircraft
        # gets there, and every real mission carries them together.
        point["action"] = _WAYPOINT_TYPES[waypoint_type]
    if eta_locked is not None:
        changed["eta_locked"] = {"from": bool(point.get("ETA_locked")), "to": eta_locked}
        point["ETA_locked"] = eta_locked


def _empty_combo_task() -> dict[str, Any]:
    """Return the empty `ComboTask` envelope every waypoint carries."""
    return {"id": "ComboTask", "params": {"tasks": []}}


def _tasks_list(point: dict[str, Any]) -> list[dict[str, Any]]:
    """Return the waypoint's task list, normalising the envelope in place.

    Args:
        point: The waypoint to read.

    Returns:
        The task list, held under ``task.params.tasks``.
    """
    task = point.get("task")
    if not isinstance(task, dict) or task.get("id") != "ComboTask":
        task = _empty_combo_task()
        point["task"] = task
    params = task.setdefault("params", {})
    tasks = indexed(params.get("tasks"))
    params["tasks"] = tasks
    return tasks


def _add_task(point: dict[str, Any], task: str | None, params: dict[str, Any], changed: dict[str, Any]) -> None:
    """Append one task from the named set to a waypoint.

    Args:
        point: The waypoint to mutate.
        task: The task's name in this action's vocabulary.
        params: Its parameters.
        changed: The report to record the change in.

    Raises:
        ValueError: If the task is unknown or a required parameter is missing.
    """
    if task is None:
        raise ValueError(f"task is required for add_task; expected one of {', '.join(sorted(_TASK_BUILDERS))}")
    builder = _TASK_BUILDERS.get(task)
    if builder is None:
        raise ValueError(f"unknown task {task!r}; expected one of {', '.join(sorted(_TASK_BUILDERS))}")

    tasks = _tasks_list(point)
    entry = builder(params)
    # `number` is what DCS reads to order them, and `auto` is what marks the *editor's* own options:
    # an authored task claiming `auto = true` would be treated as one and hidden from the maker.
    entry["number"] = len(tasks) + 1
    entry["enabled"] = True
    entry["auto"] = False
    tasks.append(entry)
    changed["task_added"] = {"task": task, "number": entry["number"]}


def _clear_tasks(point: dict[str, Any], changed: dict[str, Any]) -> None:
    """Remove every task from a waypoint.

    Args:
        point: The waypoint to mutate.
        changed: The report to record the change in.
    """
    tasks = _tasks_list(point)
    changed["tasks_cleared"] = len(tasks)
    point["task"] = _empty_combo_task()


def _required(params: dict[str, Any], field: str, task: str) -> Any:
    """Return `params[field]`, or raise naming the field and the task that wanted it.

    Args:
        params: The caller's task parameters.
        field: The required field's name.
        task: The task's name, for the message.

    Returns:
        The value.

    Raises:
        ValueError: If the field is absent.
    """
    if field not in params:
        raise ValueError(f"task {task!r} requires {field!r}")
    return params[field]


def _point_params(params: dict[str, Any], task: str) -> dict[str, float]:
    """Return a ``{x, y}`` ground point from a task's ``position`` parameter."""
    position = _required(params, "position", task)
    if not isinstance(position, dict) or "x" not in position or "y" not in position:
        raise ValueError(f"task {task!r} requires position {{x, y}}")
    return {"x": float(position["x"]), "y": float(position["y"])}


def _build_orbit(params: dict[str, Any]) -> dict[str, Any]:
    """Build an ``Orbit`` task: a pattern, an altitude and a speed."""
    pattern = params.get("pattern", "Race-Track")
    if pattern not in _ORBIT_PATTERNS:
        raise ValueError(f"unknown orbit pattern {pattern!r}; expected one of {', '.join(_ORBIT_PATTERNS)}")
    body: dict[str, Any] = {"id": "Orbit", "params": {"pattern": pattern}}
    if "altitude_ft" in params:
        body["params"]["altitude"] = float(params["altitude_ft"]) * _M_PER_FT
    if "speed_kt" in params:
        body["params"]["speed"] = float(params["speed_kt"]) * _MPS_PER_KT
        # The editor writes this alongside an explicit speed; without it DCS may use the leg's.
        body["params"]["speedEdited"] = True
    return body


def _build_land(params: dict[str, Any]) -> dict[str, Any]:
    """Build a ``Land`` task — a point on the ground and a wait, not an airfield reference."""
    point = _point_params(params, "land")
    duration = params.get("duration_s")
    return {
        "id": "Land",
        "params": {
            "x": point["x"],
            "y": point["y"],
            "duration": int(duration) if duration is not None else 300,
            "durationFlag": duration is not None,
        },
    }


def _attack_common(params: dict[str, Any], task: str) -> dict[str, Any]:
    """The fields every attack task shares, in the shape the Mission Editor writes them.

    Measured 2026-08-15: `Bombing` and `AttackGroup` both carry `weaponType`, an `expend`/`attackQty`/
    `attackQtyLimit`/`groupAttack` set, and **present-but-disabled** `altitude`/`altitudeEnabled` and
    `direction`/`directionEnabled` pairs. Writing a subset is what made the editor discard the task on
    save. The `*Enabled` flags default off — DCS wants the field present with the flag clear, not the
    field missing — and turn on when the caller supplies the value.

    Args:
        params: The caller's task parameters.
        task: The task name, choosing the measured default `weaponType`.

    Returns:
        The shared parameter block.
    """
    altitude_given = "altitude_ft" in params
    direction_given = "direction_deg" in params
    return {
        "weaponType": int(params.get("weapon_type", _WEAPON_TYPE_AUTO[task])),
        "expend": params.get("expend", "Auto"),
        "attackQty": int(params.get("attack_qty", 1)),
        "attackQtyLimit": "attack_qty" in params,
        "groupAttack": bool(params.get("group_attack", False)),
        "altitude": float(params["altitude_ft"]) * _M_PER_FT if altitude_given else 0.0,
        "altitudeEnabled": altitude_given,
        "direction": float(params["direction_deg"]) % 360 * 3.141592653589793 / 180.0 if direction_given else 0.0,
        "directionEnabled": direction_given,
    }


def _build_attack_group(params: dict[str, Any]) -> dict[str, Any]:
    """Build an ``AttackGroup`` task against a group id."""
    body = _attack_common(params, "attack_group")
    body["groupId"] = int(_required(params, "group_id", "attack_group"))
    return {"id": "AttackGroup", "params": body}


def _build_bombing(params: dict[str, Any]) -> dict[str, Any]:
    """Build a ``Bombing`` task against a ground point."""
    point = _point_params(params, "bombing")
    body = _attack_common(params, "bombing")
    body["x"] = point["x"]
    body["y"] = point["y"]
    return {"id": "Bombing", "params": body}


def _build_engage_targets_in_zone(params: dict[str, Any]) -> dict[str, Any]:
    """Build an ``EngageTargetsInZone`` task, keeping its two target lists in step.

    DCS stores the target list **twice**: as a ``targetTypes`` array and as a serialised ``value``
    string (``"Air;Cruise missiles;"``). Both are written from the one list the caller gave, because
    writing only the array leaves the mission carrying two versions of the same decision.
    """
    point = _point_params(params, "engage_targets_in_zone")
    target_types = list(params.get("target_types") or ["All"])
    return {
        "id": "EngageTargetsInZone",
        "params": {
            "x": point["x"],
            "y": point["y"],
            "zoneRadius": float(_required(params, "radius_m", "engage_targets_in_zone")),
            "targetTypes": target_types,
            "value": "".join(f"{entry};" for entry in target_types),
            # The editor writes an explicit exclusion list beside the inclusion one (measured
            # 2026-08-15); an empty list excludes nothing, which is the right default for a caller
            # who named only what to engage.
            "noTargetTypes": list(params.get("no_target_types") or []),
            "priority": int(params.get("priority", 0)),
        },
    }


def _build_set_frequency(params: dict[str, Any]) -> dict[str, Any]:
    """Build a ``SetFrequency`` **action**, wrapped as DCS carries it.

    The frequency is taken in MHz and written in **hertz**: a real mission holds `31000000` for
    31 MHz, while a *group's* primary frequency — `set_group_properties` — is in MHz. Two units for
    the same notion in one file, so the parameter states which one it takes.
    """
    modulation = str(params.get("modulation", "AM")).strip().upper()
    if modulation not in _MODULATIONS:
        raise ValueError(f"unknown modulation {modulation!r}; expected one of {', '.join(_MODULATIONS)}")
    megahertz = float(_required(params, "frequency_mhz", "set_frequency"))
    return _wrapped(
        {
            "id": "SetFrequency",
            "params": {
                "frequency": int(round(megahertz * 1_000_000)),
                "modulation": _MODULATIONS[modulation],
                "power": int(params.get("power", 100)),
            },
        }
    )


def _build_switch_waypoint(params: dict[str, Any]) -> dict[str, Any]:
    """Build a ``SwitchWaypoint`` **action** — how a route loops back on itself."""
    return _wrapped(
        {
            "id": "SwitchWaypoint",
            "params": {
                "goToWaypointIndex": int(_required(params, "to_index", "switch_waypoint")),
                "fromWaypointIndex": int(params.get("from_index", 1)),
            },
        }
    )


def _wrapped(action: dict[str, Any]) -> dict[str, Any]:
    """Wrap an *action* in the ``WrappedAction`` envelope DCS reads it from.

    `SetFrequency` and `SwitchWaypoint` are not tasks: they are actions, and a mission carries them
    inside this envelope. Writing one as a bare task produces a table DCS ignores in silence.
    """
    return {"id": "WrappedAction", "params": {"action": action}}


#: The named set. Closed on purpose: a generic "write this task table" action lets an agent produce
#: a plausible table DCS ignores, and the mission maker discovers it an hour into testing.
_TASK_BUILDERS: dict[str, Any] = {
    "orbit": _build_orbit,
    "land": _build_land,
    "attack_group": _build_attack_group,
    "bombing": _build_bombing,
    "engage_targets_in_zone": _build_engage_targets_in_zone,
    "set_frequency": _build_set_frequency,
    "switch_waypoint": _build_switch_waypoint,
}


def _restore_eta_lock(points: list[dict[str, Any]], warnings: list[str]) -> None:
    """Guarantee at least one waypoint has a locked time, locking the first when none has.

    `FIX-WAYPOINTS-ETA-LOCKED`: DCS refuses to save a mission whose route has no locked-time
    waypoint, and its own repair is to lock the departure. An edit that removes the only locked
    waypoint would otherwise produce a mission the editor rejects, with an error naming the route
    rather than the edit.

    Args:
        points: The waypoints, after the edit.
        warnings: The warning list, told when the lock had to be restored.
    """
    if not points or any(point.get("ETA_locked") for point in points):
        return
    points[0]["ETA_locked"] = True
    warnings.append(
        "no waypoint had a locked time left after this edit, so the first one was locked: DCS "
        "refuses to save a mission whose route has none ('Route has no waypoints with locked time!')"
    )


def _described(point: dict[str, Any], index: int) -> dict[str, Any]:
    """Return one waypoint as the caller reads it, in both unit systems.

    Args:
        point: The waypoint.
        index: Its 1-based position.

    Returns:
        The fields an editor cares about, altitude and speed in metres **and** in feet/knots.
    """
    altitude = point.get("alt")
    speed = point.get("speed")
    return {
        "index": index,
        "name": point.get("name"),
        "type": point.get("type"),
        "action": point.get("action"),
        "x": point.get("x"),
        "y": point.get("y"),
        "alt": altitude,
        "altitude_ft": (float(altitude) / _M_PER_FT) if isinstance(altitude, (int, float)) else None,
        "speed": speed,
        "speed_kt": (float(speed) / _MPS_PER_KT) if isinstance(speed, (int, float)) else None,
        "eta_locked": bool(point.get("ETA_locked")),
        "tasks": [
            {"number": entry.get("number"), "id": entry.get("id"), "auto": bool(entry.get("auto"))}
            for entry in indexed(((point.get("task") or {}).get("params") or {}).get("tasks"))
            if isinstance(entry, dict)
        ],
    }
