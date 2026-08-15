"""`set_unit_properties` — change a unit the mission already contains.

The first mutation action of ``FEAT-MCP-MUTATION-ACTIONS``: every ``set_*`` shipped before it
operates on mission *configuration* (modules, security, logging, an airbase's coalition), so
*"give Colt flight an air-to-ground loadout"* was impossible while every other link in the chain
existed.

Three shapes here were **measured** rather than taken from the ticket, and two contradict it:

- **``skill`` has seven values, not four.** ``Average``/``Good``/``High``/``Excellent``/``Random``
  are AI levels; ``Client`` and ``Player`` are *human slots*. Crossing that line either way changes
  the multiplayer slot list — the bug ``FIX-TEMPLATE-SLOTS-VISIBLE`` was opened for — so it is
  refused by name instead of honoured as a skill.
- **An aircraft's ``callsign`` is a structured table**, ``{1: family, 2: flight, 3: number,
  name: "Colt11"}``, whose ``name`` is the family's word followed by the two indices. Writing
  ``name`` alone desynchronises the radio call from the editor's display, so the indices are edited
  and ``name`` rebuilt from the prefix already there. A *family* change needs DCS's family→word
  table, which this repository does not ship, so it is refused unless the caller supplies the name.
- **``heading`` is radians** while a mission maker speaks degrees, the trap ``resolve_coordinates``
  hides elsewhere. The parameter is named ``heading_deg`` so the unit is impossible to mistake.

What this action deliberately does **not** validate, because the data to do it does not exist here:
a weapon's CLSID against the airframe that carries it, and a livery against the skins installed.
DCS silently drops an impossible weapon and silently shows the default skin, so both limits are
returned as warnings rather than implied by their absence.
"""

import math
from pathlib import Path
from typing import Any

from mission_tools.miz_backup import backup_before_write
from mission_tools.miz_tools import read_miz, write_miz
from veaf_libs.mission_table import CATEGORIES

from veaf_mission_mcp.mission_table import find_group, indexed, listed

#: The AI competence levels. `Random` is one of them: DCS picks a level at mission start.
_AI_SKILLS: tuple[str, ...] = ("Average", "Good", "High", "Excellent", "Random")

#: Not skills at all — a unit carrying one of these is a slot a human can take.
_HUMAN_SKILLS: tuple[str, ...] = ("Client", "Player")

#: DCS callsign indices: family (the word), flight, and number within the flight.
_CALLSIGN_FAMILY, _CALLSIGN_FLIGHT, _CALLSIGN_NUMBER = 1, 2, 3

#: Both indices a callsign's flight/number accept; `name` concatenates them, so 10 would read as 1.
_CALLSIGN_INDEX_RANGE = range(1, 10)

#: Aircraft categories, and the in-air first-waypoint types. DCS recomputes an **airborne** aircraft's
#: heading from its route's first leg on save, so a heading set on one has a lifetime of one save; a
#: parked start (``TakeOffParking...``) was not measured, so the warning is scoped to what was.
_AIRCRAFT_CATEGORIES: tuple[str, ...] = ("plane", "helicopter")
_IN_AIR_WAYPOINT_TYPES: tuple[str, ...] = ("Turning Point", "Fly Over Point")


def set_unit_properties(
    miz_path: Path,
    *,
    group_name: str,
    unit_name: str,
    skill: str | None = None,
    livery: str | None = None,
    heading_deg: float | None = None,
    callsign: dict[str, int | str] | int | str | None = None,
    onboard_num: str | None = None,
    pylons: dict[int | str, str] | None = None,
    pylons_mode: str = "replace",
) -> dict[str, Any]:
    """Change one named unit inside one named group, in place, backed up first.

    Args:
        miz_path: Path to the mission's source `.miz`.
        group_name: The group's **exact** name. A fragment is refused: `describe_units` filters on
            one, but an edit landing on whichever group matched first is not recoverable.
        unit_name: The unit's exact name within that group.
        skill: One of ``Average``, ``Good``, ``High``, ``Excellent``, ``Random``. ``Client`` and
            ``Player`` are refused — they add or remove a multiplayer slot rather than set a skill.
        livery: The livery id. Not validated (no skin inventory ships here); warned about.
        heading_deg: Heading in **degrees**, normalised onto 0..360 and stored as radians.
        callsign: For an aircraft, ``{"family": int, "flight": int, "number": int, "name": str}`` —
            any subset, except that ``family`` requires ``name`` since the family→word table is not
            available. For a ground unit, the bare number DCS stores.
        onboard_num: The tail number, kept as text so a leading zero survives.
        pylons: ``{station number: CLSID}``. Keyed **by station**, never positional: DCS numbers
            stations non-contiguously (a real FA-18C carries 1, 4, 5, 6, 9). ``None`` means "leave
            the loadout alone"; ``{}`` in replace mode means "carry nothing".
        pylons_mode: ``replace`` (the default) writes exactly the stations given; ``merge`` updates
            only those, and an empty CLSID empties that station.

    Returns:
        ``{group, unit, changed, warnings}`` — ``changed`` maps each touched field to
        ``{"from": ..., "to": ...}`` so the caller can report, and undo, what it did.

    Raises:
        ValueError: If the archive is not a valid mission, the group or unit does not exist, no
            property was given, or a value is refused (unknown skill, human-slot crossing, bad
            station number, callsign index out of range, family without its name).
    """
    if pylons_mode not in ("replace", "merge"):
        raise ValueError(f"pylons_mode must be 'replace' or 'merge', got {pylons_mode!r}")
    if all(value is None for value in (skill, livery, heading_deg, callsign, onboard_num, pylons)):
        raise ValueError(
            "no property given — pass at least one of skill, livery, heading_deg, callsign, onboard_num, pylons"
        )

    mission = read_miz(miz_path)
    if mission.mission_content is None:
        raise ValueError(f"Not a valid DCS mission archive (missing 'mission' file): {miz_path}")

    group = find_group(mission.mission_content, group_name)
    unit = _find_unit(group, group_name, unit_name)

    # Everything is validated before anything is stored, so a refusal cannot half-write a mission.
    changed: dict[str, Any] = {}
    warnings: list[str] = []
    if skill is not None:
        _apply_skill(unit, skill, changed)
    if livery is not None:
        changed["livery"] = {"from": unit.get("livery_id"), "to": livery}
        unit["livery_id"] = livery
        warnings.append(
            "livery is not validated: DCS shows the default skin for an unknown livery id without "
            "raising anything, so check it in the editor"
        )
    if heading_deg is not None:
        _apply_heading(unit, heading_deg, changed)
        if _heading_will_be_recalculated(mission.mission_content, group_name, group):
            warnings.append(
                "heading on an airborne aircraft has a lifetime of one save: DCS recomputes it from "
                "the route's first leg (measured 2026-08-15 — a set heading came back as the bearing "
                "to the next waypoint). To point the aircraft, set the route, not the heading"
            )
    if callsign is not None:
        _apply_callsign(unit, callsign, changed)
    if onboard_num is not None:
        changed["onboard_num"] = {"from": unit.get("onboard_num"), "to": str(onboard_num)}
        unit["onboard_num"] = str(onboard_num)
    if pylons is not None:
        _apply_pylons(unit, pylons, pylons_mode, changed)
        warnings.append(
            "a weapon's CLSID is not checked against the airframe: no per-type weapon table ships "
            "with veaf-tools, and DCS drops a weapon the aircraft cannot carry without an error"
        )

    backup_before_write(miz_path)
    write_miz(mission, miz_path)

    return {"group": group_name, "unit": unit_name, "changed": changed, "warnings": warnings}


def _find_unit(group: dict[str, Any], group_name: str, unit_name: str) -> dict[str, Any]:
    """Return the unit named `unit_name` inside `group`, or raise naming the group's units.

    Args:
        group: The group table to search.
        group_name: The group's name, for the error message.
        unit_name: The exact unit name to find.

    Returns:
        The unit table, so the caller mutates the mission's own dict.

    Raises:
        ValueError: If the group holds no unit with that name.
    """
    names: list[str] = []
    for unit in indexed(group.get("units")):
        if not isinstance(unit, dict):
            continue
        name = str(unit.get("name", ""))
        if name == unit_name:
            return unit
        names.append(name)
    raise ValueError(f"No unit named {unit_name!r} in group {group_name!r}. Units in that group: {listed(names)}")


def _group_category(mission_content: dict[str, Any], group_name: str) -> str | None:
    """Return the category (`plane`, `vehicle`, ...) the group sits under, or None if not found."""
    for coalition in (mission_content.get("coalition") or {}).values():
        if not isinstance(coalition, dict):
            continue
        for country in indexed(coalition.get("country")):
            if not isinstance(country, dict):
                continue
            for category in CATEGORIES:
                for group in indexed((country.get(category) or {}).get("group")):
                    if isinstance(group, dict) and str(group.get("name", "")) == group_name:
                        return category
    return None


def _heading_will_be_recalculated(mission_content: dict[str, Any], group_name: str, group: dict[str, Any]) -> bool:
    """Whether DCS will overwrite a set heading — an airborne aircraft with a route of 2+ waypoints.

    Scoped to the measured case: a parked aircraft (a ``TakeOff*`` first waypoint) was not tested, so
    it does not warn. A ground unit's heading is meaningful and never recomputed.

    Args:
        mission_content: The parsed ``mission`` table (to read the group's category).
        group_name: The group's name.
        group: The group table (to read its route).

    Returns:
        True when the heading would be recomputed from the route on save.
    """
    if _group_category(mission_content, group_name) not in _AIRCRAFT_CATEGORIES:
        return False
    points = indexed((group.get("route") or {}).get("points"))
    if len(points) < 2 or not isinstance(points[0], dict):
        return False
    return str(points[0].get("type", "")) in _IN_AIR_WAYPOINT_TYPES


def _apply_skill(unit: dict[str, Any], skill: str, changed: dict[str, Any]) -> None:
    """Set a unit's AI competence, refusing to cross the human-slot line in either direction.

    Args:
        unit: The unit table to mutate.
        skill: The requested skill.
        changed: The report to record the change in.

    Raises:
        ValueError: If `skill` is unknown, or if the change would add or remove a human slot.
    """
    current = str(unit.get("skill") or "")
    if skill in _HUMAN_SKILLS:
        raise ValueError(
            f"{skill!r} is a human slot, not a skill level: setting it would add this unit to the "
            f"multiplayer slot list. Valid skills: {', '.join(_AI_SKILLS)}"
        )
    if skill not in _AI_SKILLS:
        raise ValueError(f"Unknown skill {skill!r}. Valid skills: {', '.join(_AI_SKILLS)}")
    if current in _HUMAN_SKILLS:
        raise ValueError(
            f"unit is a human slot (skill {current!r}): giving it an AI skill would remove it from "
            "the multiplayer slot list. Change the slot deliberately, not through a skill setter"
        )
    changed["skill"] = {"from": unit.get("skill"), "to": skill}
    unit["skill"] = skill


def _apply_heading(unit: dict[str, Any], heading_deg: float, changed: dict[str, Any]) -> None:
    """Store a compass bearing as the radians DCS keeps, normalised onto one turn.

    Args:
        unit: The unit table to mutate.
        heading_deg: The bearing in degrees; -90 and 450 are as valid as 270 and 90.
        changed: The report to record the change in.
    """
    normalised = float(heading_deg) % 360.0
    radians = math.radians(normalised)
    changed["heading"] = {
        "from": unit.get("heading"),
        "to": radians,
        "to_degrees": normalised,
    }
    unit["heading"] = radians


def _apply_callsign(unit: dict[str, Any], callsign: dict[str, int | str] | int | str, changed: dict[str, Any]) -> None:
    """Set a callsign, keeping an aircraft's `name` in step with its indices.

    Args:
        unit: The unit table to mutate.
        callsign: A component mapping for an aircraft, or the bare value a ground unit stores.
        changed: The report to record the change in.

    Raises:
        ValueError: If an index falls outside 1..9, or a family is given without its name.
    """
    previous = unit.get("callsign")
    if not isinstance(callsign, dict):
        changed["callsign"] = {"from": previous, "to": callsign}
        unit["callsign"] = callsign
        return

    unknown = set(callsign) - {"family", "flight", "number", "name"}
    if unknown:
        raise ValueError(f"unknown callsign field(s) {listed(sorted(unknown))}; expected family, flight, number, name")
    for field in ("family", "flight", "number"):
        if field in callsign and int(callsign[field]) not in _CALLSIGN_INDEX_RANGE:
            raise ValueError(f"callsign {field} must be in 1..9, got {callsign[field]!r}")
    if "family" in callsign and "name" not in callsign:
        raise ValueError(
            "changing the callsign family also changes the spoken word, and DCS's family->word "
            "table does not ship with veaf-tools: pass the resulting name too "
            '(e.g. family=5 with name="Dodge11")'
        )

    table = dict(previous) if isinstance(previous, dict) else {}
    for field, index in (
        ("family", _CALLSIGN_FAMILY),
        ("flight", _CALLSIGN_FLIGHT),
        ("number", _CALLSIGN_NUMBER),
    ):
        if field in callsign:
            table[index] = int(callsign[field])
    table["name"] = str(callsign["name"]) if "name" in callsign else _rebuilt_callsign_name(previous, table)
    changed["callsign"] = {"from": previous, "to": table}
    unit["callsign"] = table


def _rebuilt_callsign_name(previous: Any, table: dict[Any, Any]) -> str:
    """Return the spoken callsign for `table`, reusing the word the unit already carries.

    DCS renders a callsign as the family's word followed by the flight and number
    (``{1:4, 2:1, 3:1}`` reads ``Colt11``). The word itself lives in a DCS table this repository
    does not ship, so it is recovered from the previous name by dropping its two trailing digits —
    which is exact whenever the family is unchanged, and that is the only case reaching here.

    Args:
        previous: The unit's callsign before the edit.
        table: The callsign being written, already carrying its indices.

    Returns:
        The rebuilt name, falling back to the digits alone when there was no previous word.
    """
    previous_name = str(previous.get("name", "")) if isinstance(previous, dict) else ""
    word = previous_name[:-2] if len(previous_name) > 2 and previous_name[-2:].isdigit() else previous_name
    flight = table.get(_CALLSIGN_FLIGHT, 1)
    number = table.get(_CALLSIGN_NUMBER, 1)
    return f"{word}{flight}{number}"


def _apply_pylons(unit: dict[str, Any], pylons: dict[int | str, str], mode: str, changed: dict[str, Any]) -> None:
    """Write a loadout, keyed by station number.

    Args:
        unit: The unit table to mutate.
        pylons: ``{station: CLSID}``; in ``merge`` mode an empty CLSID empties that station.
        mode: ``replace`` or ``merge``.
        changed: The report to record the change in.

    Raises:
        ValueError: If a key is not a station number of 1 or more.
    """
    stations: dict[int, str] = {}
    for raw_station, clsid in pylons.items():
        station = _station_number(raw_station)
        stations[station] = str(clsid)

    payload = unit.get("payload")
    if not isinstance(payload, dict):
        payload = {}
        unit["payload"] = payload
    before = _current_pylons(payload)

    after = dict(before) if mode == "merge" else {}
    for station, clsid in stations.items():
        if mode == "merge" and not clsid:
            after.pop(station, None)
        else:
            after[station] = clsid

    payload["pylons"] = {station: {"CLSID": clsid} for station, clsid in sorted(after.items())}
    changed["pylons"] = {"from": before, "to": after}


def _station_number(raw: Any) -> int:
    """Return `raw` as a station number, refusing anything that is not one.

    A bad station is an error rather than a dropped key: silently ignoring it would hang nothing
    where the caller asked for a weapon, and the mission would fly wrong with no sign of why.

    Args:
        raw: The pylon key as the caller passed it.

    Returns:
        The station number.

    Raises:
        ValueError: If `raw` is not an integer of 1 or more.
    """
    try:
        station = int(raw)
    except (TypeError, ValueError):
        raise ValueError(
            f"pylon station must be a number, got {raw!r} — DCS keys pylons by station number "
            "(a real FA-18C carries 1, 4, 5, 6, 9)"
        ) from None
    if station < 1:
        raise ValueError(f"pylon station must be 1 or more, got {station}")
    return station


def _current_pylons(payload: dict[str, Any]) -> dict[int, str]:
    """Return the loadout already on the unit as ``{station: CLSID}``.

    The Lua parser hands a contiguous pylon table back as a **list** and a gapped one as a dict, so
    a list's position carries the station number and must be restored rather than reported.

    Args:
        payload: The unit's payload table.

    Returns:
        Station number to CLSID, empty when the unit carries nothing.
    """
    raw = payload.get("pylons")
    result: dict[int, str] = {}
    if isinstance(raw, dict):
        for station, entry in raw.items():
            clsid = entry.get("CLSID") if isinstance(entry, dict) else None
            if clsid is not None:
                result[int(station)] = str(clsid)
    elif isinstance(raw, list):
        for offset, entry in enumerate(raw, start=1):
            clsid = entry.get("CLSID") if isinstance(entry, dict) else None
            if clsid is not None:
                result[offset] = str(clsid)
    return result
