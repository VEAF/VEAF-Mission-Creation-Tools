"""`describe_units` — read the units, loadouts and routes a mutation action needs to see.

`describe_mission` answers *"what groups and zones exist"*, which is enough to decide where to add
something. It is not enough to **change** something: it reports no units, no loadout, no skill, no
livery, no route, no waypoint and no task. So the mutation actions of
``FEAT-MCP-MUTATION-ACTIONS`` — "give Colt flight an air-to-ground loadout", "add a waypoint after
the third" — would be attempted on a guess, and a mission mutated on a guess opens in the Mission
Editor and flies wrong. That failure mode has nothing to catch it, which is why this read action is
a prerequisite rather than a convenience (the lot's triage explains the ordering).

A separate action rather than a bigger ``describe_mission``: that one is documented as situational
awareness before a write, and a Foothold mission has thousands of units — returning them all would
make the pair unusable for exactly the missions that need them most. Hence the filters, and a cap
the caller is told about.

Everything here reads the mission table in pure Python (:func:`mission_tools.miz_tools.read_miz`);
no DCS, no Lua.
"""

from pathlib import Path
from typing import Any

from mission_tools.miz_tools import read_miz

#: Group categories a mission table may hold, in the order DCS writes them.
_CATEGORIES: tuple[str, ...] = ("plane", "helicopter", "vehicle", "ship", "static")

#: Groups returned when the caller names no limit. Chosen to be generous for a hand-built mission
#: and still short of burying an agent's context with an adopted one.
_DEFAULT_LIMIT = 50


def _indexed(container: Any) -> list[Any]:
    """Return a DCS 1-based table's values in key order, whether it arrived as a dict or a list.

    Args:
        container: The raw value, of whatever shape the Lua parser produced.

    Returns:
        The entries in table order (empty when there are none).
    """
    if isinstance(container, dict):
        return [container[key] for key in sorted(container, key=_numeric_first)]
    if isinstance(container, list):
        return list(container)
    return []


def _numeric_first(key: Any) -> tuple[int, float, str]:
    """Sort key ordering numeric table keys numerically, before any non-numeric ones."""
    try:
        return (0, float(key), "")
    except (TypeError, ValueError):
        return (1, 0.0, str(key))


def _pylons(payload: Any) -> dict[int, str]:
    """Return ``{pylon number: weapon CLSID}`` from a unit's payload.

    **Keyed by number, never positional.** DCS indexes pylons by station and the numbers are not
    contiguous — a real FA-18C carries pylons 1, 4, 5, 6 and 9. Measured on Foothold Caucasus 4.4.1:
    170 of 357 armed units have a gapped layout, and the Lua parser hands those back as a dict while
    it flattens the contiguous ones into a list. A reader treating pylons as an ordered list is
    therefore right about half the time and silently wrong the rest, which is how a setter comes to
    hang a weapon on the wrong station.

    Args:
        payload: The unit's ``payload`` table, or anything else.

    Returns:
        Station number to CLSID, empty when the unit carries nothing.
    """
    if not isinstance(payload, dict):
        return {}
    pylons = payload.get("pylons")
    result: dict[int, str] = {}
    if isinstance(pylons, dict):
        for station, entry in pylons.items():
            clsid = entry.get("CLSID") if isinstance(entry, dict) else None
            if clsid is not None:
                result[int(station)] = str(clsid)
    elif isinstance(pylons, list):
        # Flattened by the parser because the stations happened to be 1..n: the index carries the
        # station number, so restore it rather than reporting a position.
        for offset, entry in enumerate(pylons, start=1):
            clsid = entry.get("CLSID") if isinstance(entry, dict) else None
            if clsid is not None:
                result[offset] = str(clsid)
    return result


def _callsign(raw: Any) -> str | None:
    """Return a unit's callsign as the name a pilot says, not the index table DCS stores.

    Args:
        raw: The unit's ``callsign`` value: a table with a ``name`` for aircraft, a plain number for
            a ground unit, or absent.

    Returns:
        The readable callsign, or ``None`` when there is none.
    """
    if isinstance(raw, dict):
        name = raw.get("name")
        return str(name) if name is not None else None
    return str(raw) if isinstance(raw, str) and raw else None


def _tasks(waypoint: dict[str, Any]) -> list[dict[str, Any]]:
    """Return a waypoint's tasks, in declared order, separating authored ones from the editor's.

    A DCS waypoint task is a ``ComboTask`` whose ``params.tasks`` mixes the task a mission maker
    added with the options the editor writes by itself (ROE, radar usage, formation…), all marked
    ``auto = true``. Both are reported, because hiding the auto ones would misrepresent the mission —
    but only an authored task carries its ``params``, since forty option bodies would bury the one
    entry that was put there on purpose.

    Args:
        waypoint: One route point.

    Returns:
        One entry per task: ``number``, ``id``, ``enabled``, ``auto``, and ``params`` for the
        authored ones.
    """
    task = waypoint.get("task")
    if not isinstance(task, dict):
        return []
    entries = _indexed((task.get("params") or {}).get("tasks"))
    result: list[dict[str, Any]] = []
    for entry in entries:
        if not isinstance(entry, dict):
            continue
        auto = bool(entry.get("auto"))
        described: dict[str, Any] = {
            "number": entry.get("number"),
            "id": entry.get("id"),
            "enabled": bool(entry.get("enabled")),
            "auto": auto,
        }
        if not auto:
            described["params"] = entry.get("params") or {}
        result.append(described)
    return result


def _route(group: dict[str, Any]) -> list[dict[str, Any]]:
    """Return a group's waypoints in order, each with the fields a route editor changes.

    Args:
        group: One group table.

    Returns:
        One entry per waypoint, ``index`` being the 1-based position a mission maker counts by.
    """
    points = _indexed((group.get("route") or {}).get("points"))
    return [
        {
            "index": index,
            "name": point.get("name"),
            "type": point.get("type"),
            "action": point.get("action"),
            "x": point.get("x"),
            "y": point.get("y"),
            "alt": point.get("alt"),
            "alt_type": point.get("alt_type"),
            "speed": point.get("speed"),
            "eta": point.get("ETA"),
            "eta_locked": bool(point.get("ETA_locked")),
            "speed_locked": bool(point.get("speed_locked")),
            "airdrome_id": point.get("airdromeId"),
            "tasks": _tasks(point),
        }
        for index, point in enumerate(points, start=1)
        if isinstance(point, dict)
    ]


def _unit(unit: dict[str, Any]) -> dict[str, Any]:
    """Return one unit's readable properties, including its loadout.

    Args:
        unit: One unit table.

    Returns:
        The unit's fields, with ``pylons`` keyed by station number.
    """
    payload = unit.get("payload") if isinstance(unit.get("payload"), dict) else {}
    return {
        "name": unit.get("name"),
        "type": unit.get("type"),
        "skill": unit.get("skill"),
        "livery": unit.get("livery_id"),
        "callsign": _callsign(unit.get("callsign")),
        "onboard_num": unit.get("onboard_num"),
        "x": unit.get("x"),
        "y": unit.get("y"),
        "heading": unit.get("heading"),
        "alt": unit.get("alt"),
        "alt_type": unit.get("alt_type"),
        "speed": unit.get("speed"),
        "parking": unit.get("parking"),
        "fuel": (payload or {}).get("fuel"),
        "chaff": (payload or {}).get("chaff"),
        "flare": (payload or {}).get("flare"),
        "gun": (payload or {}).get("gun"),
        "pylons": _pylons(payload),
    }


def _group(
    group: dict[str, Any], coalition: str, country: str, category: str, include_route: bool = True
) -> dict[str, Any]:
    """Return one group with its units and route.

    Boolean flags are reported as booleans rather than passed through: DCS **omits** a key that is
    off, and an agent reading ``None`` cannot tell "off" from "the reader did not look".

    Args:
        group: One group table.
        coalition: ``blue``/``red``/``neutrals``.
        country: The country's name.
        category: The group category (``plane``, ``vehicle``, …).
        include_route: Whether to read the route. Off, the key is absent rather than empty, so a
            caller cannot mistake "not asked for" for "this group has no route".

    Returns:
        The group's identity, the properties a setter changes, its units and its route.
    """
    return {
        "name": group.get("name"),
        "coalition": coalition,
        "country": country,
        "category": category,
        "task": group.get("task"),
        "frequency": group.get("frequency"),
        "modulation": group.get("modulation"),
        "hidden": bool(group.get("hidden")),
        "hidden_on_mfd": bool(group.get("hiddenOnMFD")),
        "hidden_on_planner": bool(group.get("hiddenOnPlanner")),
        "uncontrolled": bool(group.get("uncontrolled")),
        "late_activation": bool(group.get("lateActivation")),
        "start_time": group.get("start_time"),
        "x": group.get("x"),
        "y": group.get("y"),
        "units": [_unit(unit) for unit in _indexed(group.get("units")) if isinstance(unit, dict)],
        **({"route": _route(group)} if include_route else {}),
    }


def describe_units(
    miz_path: Path,
    group_name: str | None = None,
    coalition: str | None = None,
    category: str | None = None,
    limit: int | None = None,
    include_route: bool = True,
) -> dict[str, Any]:
    """Describe a mission's groups down to their units, loadouts and routes.

    Args:
        miz_path: Path to the mission's source `.miz`.
        group_name: Keep only groups whose name contains this, case-insensitively — a mission maker
            says "Colt", not the full generated name.
        coalition: Keep only this coalition (``blue``, ``red``, ``neutrals``).
        category: Keep only this group category (``plane``, ``helicopter``, ``vehicle``, ``ship``,
            ``static``).
        limit: Maximum groups to return; defaults to 50. ``truncated`` says whether it bit.
        include_route: Read each group's route. On by default, but worth turning off when the
            question is about loadouts: measured on Foothold Caucasus, one 62-waypoint group is 18 KB
            with its route and a fraction of that without, and the whole mission is 1.9 MB.

    Returns:
        ``{groups, matched, truncated}`` — ``matched`` counts every group passing the filters, so a
        truncated answer still says how much was left out.

    Raises:
        ValueError: If the archive has no ``mission`` file (not a valid mission archive).
    """
    mission = read_miz(miz_path)
    if mission.mission_content is None:
        raise ValueError(f"Not a valid DCS mission archive (missing 'mission' file): {miz_path}")

    wanted_name = (group_name or "").strip().lower()
    matched: list[dict[str, Any]] = []
    for side, coalition_table in (mission.mission_content.get("coalition") or {}).items():
        if not isinstance(coalition_table, dict):
            continue
        if coalition is not None and side != coalition:
            continue
        for country in _indexed(coalition_table.get("country")):
            if not isinstance(country, dict):
                continue
            country_name = str(country.get("name", ""))
            for group_category in _CATEGORIES:
                if category is not None and group_category != category:
                    continue
                for group in _indexed((country.get(group_category) or {}).get("group")):
                    if not isinstance(group, dict):
                        continue
                    if wanted_name and wanted_name not in str(group.get("name", "")).lower():
                        continue
                    matched.append(_group(group, side, country_name, group_category, include_route))

    effective_limit = _DEFAULT_LIMIT if limit is None else limit
    return {
        "groups": matched[:effective_limit],
        "matched": len(matched),
        "truncated": len(matched) > effective_limit,
    }
