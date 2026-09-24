"""Mission-wide settings the editor has and the catalogue did not: date and time, bullseyes, briefing.

FIX-SCRATCH-MISSION-FINDINGS ticket 07: on GermanyCW-v6 the agent patched ``src/mission/mission``
through a Lua serializer for all three — the synthetic blank mission is dated 2016 when a Cold War
mission wants 1980, ``describe_map`` reads the bullseyes and nothing wrote them, and the briefing had
no action at all. ``FIX-MCP-AUTHORING-GAPS`` put the rule plainly: an action that does not exist is an
invitation to corrupt the mission file.

Each action targets a mission **folder** (durable) or a ``.miz`` (transient) and backs up what it
rewrites, like every other write action.
"""

from datetime import date as dt_date
from pathlib import Path
from typing import Any

from veaf_mission_mcp.mission_folder import commit_mission, open_mission

#: The coalitions a mission table holds a bullseye for.
_COALITIONS: tuple[str, ...] = ("blue", "red", "neutrals")

#: Briefing fields, by the name this action takes, to the mission-table key DCS reads.
_BRIEFING_FIELDS: dict[str, str] = {
    "sortie": "sortie",
    "situation": "descriptionText",
    "blue_task": "descriptionBlueTask",
    "red_task": "descriptionRedTask",
    "neutrals_task": "descriptionNeutralsTask",
}


def set_mission_date(target: Path, *, date: str | None = None, start_time: str | None = None) -> dict[str, Any]:
    """Set the mission's date and/or start time, in place, backed up first.

    The weather variants of ``versions.yaml`` still override both per variant at build; this sets the
    base mission's, which is what a mission without variants flies and what a variant inherits when it
    names no date or time.

    Args:
        target: The mission folder or `.miz`.
        date: ``"YYYY-MM-DD"``.
        start_time: ``"HH:MM"`` or ``"HH:MM:SS"``, on the theatre's clock — the one DCS shows.

    Returns:
        ``{date, start_time, durable}`` as now written.

    Raises:
        ValueError: If neither is given, or either is not a valid date / time of day.
    """
    if date is None and start_time is None:
        raise ValueError("give a date, a start_time, or both")
    mission, content = open_mission(target)
    if date is not None:
        try:
            parsed = dt_date.fromisoformat(date)
        except ValueError as exc:
            raise ValueError(f"date must be YYYY-MM-DD, got {date!r}") from exc
        content["date"] = {"Day": parsed.day, "Month": parsed.month, "Year": parsed.year}
    if start_time is not None:
        content["start_time"] = _seconds_of_day(start_time)
    durable = commit_mission(mission, target)["durable"]
    stored = content.get("date") or {}
    seconds = int(content.get("start_time") or 0)
    return {
        "date": f"{stored.get('Year', 0):04d}-{stored.get('Month', 0):02d}-{stored.get('Day', 0):02d}",
        "start_time": f"{seconds // 3600:02d}:{seconds % 3600 // 60:02d}:{seconds % 60:02d}",
        "durable": durable,
    }


def _seconds_of_day(value: str) -> int:
    """Parse ``"HH:MM"`` / ``"HH:MM:SS"`` into seconds since midnight.

    Args:
        value: The time of day.

    Returns:
        Seconds since midnight.

    Raises:
        ValueError: If it is not a valid time of day.
    """
    parts = value.split(":")
    try:
        numbers = [int(part) for part in parts]
    except ValueError:
        numbers = []
    if len(numbers) not in (2, 3):
        raise ValueError(f"start_time must be HH:MM or HH:MM:SS, got {value!r}")
    hours, minutes, seconds = (numbers + [0])[:3]
    if not (0 <= hours < 24 and 0 <= minutes < 60 and 0 <= seconds < 60):
        raise ValueError(f"start_time must be a time of day, got {value!r}")
    return hours * 3600 + minutes * 60 + seconds


def set_bullseye(target: Path, *, coalition: str, position: dict[str, float]) -> dict[str, Any]:
    """Set one coalition's bullseye, in place, backed up first.

    The weather-variant build injects each flight's BULLSEYE waypoint from here, and the in-game
    scripts announce positions relative to it, so it is worth setting before anything else.

    Args:
        target: The mission folder or `.miz`.
        coalition: ``"blue"``, ``"red"`` or ``"neutrals"``.
        position: ``{"x", "y"}`` in mission-table coordinates, as `describe_map` reports them.

    Returns:
        ``{coalition, bullseye, durable}``.

    Raises:
        ValueError: If the coalition is unknown or the position incomplete.
    """
    side = coalition.strip().lower()
    if side not in _COALITIONS:
        raise ValueError(f"coalition must be one of {', '.join(_COALITIONS)}, got {coalition!r}")
    if not isinstance(position, dict) or "x" not in position or "y" not in position:
        raise ValueError("position must be {x, y}")
    mission, content = open_mission(target)
    coalitions = content.setdefault("coalition", {})
    table = coalitions.setdefault(side, {})
    table["bullseye"] = {"x": float(position["x"]), "y": float(position["y"])}
    durable = commit_mission(mission, target)["durable"]
    return {"coalition": side, "bullseye": table["bullseye"], "durable": durable}


def set_briefing(target: Path, **texts: str | None) -> dict[str, Any]:
    """Set the briefing texts, in place, backed up first; a field left out is untouched.

    A mission saved by the editor keeps its briefing in ``l10n/DEFAULT/dictionary``: the mission
    table holds a ``DictKey_…`` reference and the dictionary the prose. The text goes where the
    mission already keeps it — written into the dictionary behind an existing key, so the key stays a
    key, or into the mission table otherwise. ``${METAR}`` and the other briefing variables are
    substituted at build, per weather variant.

    Args:
        target: The mission folder or `.miz`.
        **texts: Any of ``sortie`` (the mission's name in the briefing), ``situation``,
            ``blue_task``, ``red_task``, ``neutrals_task``.

    Returns:
        ``{written: {field: "dictionary" | "mission"}, durable}``.

    Raises:
        ValueError: If a field is unknown, or none is given.
    """
    unknown = sorted(set(texts) - set(_BRIEFING_FIELDS))
    if unknown:
        raise ValueError(f"unknown briefing field(s) {', '.join(unknown)}; expected {', '.join(_BRIEFING_FIELDS)}")
    wanted = {field: text for field, text in texts.items() if text is not None}
    if not wanted:
        raise ValueError(f"give at least one of {', '.join(_BRIEFING_FIELDS)}")
    mission, content = open_mission(target)
    dictionary = mission.dictionary_content
    written: dict[str, str] = {}
    for field, text in wanted.items():
        key = _BRIEFING_FIELDS[field]
        current = content.get(key)
        if dictionary is not None and isinstance(current, str) and current in dictionary:
            dictionary[current] = text
            written[field] = "dictionary"
        else:
            content[key] = text
            written[field] = "mission"
    durable = commit_mission(mission, target)["durable"]
    return {"written": written, "durable": durable}
