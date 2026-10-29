"""`build_mission_briefing` — a one-shot mission's VEAF briefing, built by the server (FEAT-MCP-MISSION-BRIEFING).

An assistant with no shell — Claude Desktop in chat mode — cannot run the scripts the objective-mission
prompt used to ask for. It passes the scenario's words; the executable reads the built mission and
writes the PPTX, the maps and the DCS briefing pictures (`mission_briefing/`).
"""

import re
from pathlib import Path
from typing import Any

from mission_briefing.mission_briefing_worker import build_mission_briefing
from mission_briefing.models import BriefingContent, CodeWord, Objective, PackageFlight, SupportAsset, Threat
from veaf_libs.map_tiles import TILE_SOURCES

from veaf_mission_mcp.accents import missing_accents_warnings
from veaf_mission_mcp.map_tools import list_airfields


def _lines(value: Any) -> tuple[str, ...]:
    """A list of lines, or one string as its paragraphs: the blocks its blank lines separate.

    A paragraph keeps its own line breaks joined by spaces: prose is wrapped by the page, not by the writer.
    """
    if value is None:
        return ()
    if isinstance(value, str):
        return tuple(" ".join(part.split()) for part in re.split(r"\n\s*\n", value) if part.strip())
    return tuple(str(item) for item in value)


def _diversions(folder: Path, given: Any) -> tuple[str, ...] | None:
    """The diversion fields the assistant names, spelt as DCS spells them; ``None`` when it names none.

    Raises:
        ValueError: A name that is no airfield of the mission's theatre.
    """
    if given is None:
        return None
    names = _lines(given)
    known = {str(a["name"]).lower(): str(a["name"]) for a in list_airfields(mission_path=folder)["airfields"]}
    unknown = [name for name in names if name.lower() not in known]
    if unknown:
        raise ValueError(
            f"diversions: no airfield named {', '.join(unknown)} on this map; list_airfields gives the names"
        )
    return tuple(known[name.lower()] for name in names)


#: The keys of `waypoint_notes` that hold one plan's notes, and the plan's category.
_PLANS = {"plane": "plane", "planes": "plane", "jets": "plane", "helicopter": "helicopter", "helicopters": "helicopter"}


def _plan_notes(notes: dict[str, Any]) -> dict[str, dict[str, str]]:
    """The notes of `waypoint_notes` given for one plan: ``{"helicopter": {"KHAN": "…"}}`` (FIX-BRIEFING-PARITY-MARTEAU 08).

    Raises:
        ValueError: A map under a key that names no plan.
    """
    found: dict[str, dict[str, str]] = {}
    for key, value in notes.items():
        if not isinstance(value, dict):
            continue
        category = _PLANS.get(str(key).lower())
        if category is None:
            raise ValueError(
                f"waypoint_notes: {key!r} holds a map but names no plan; use 'plane' or 'helicopter', or a string"
            )
        found.setdefault(category, {}).update({str(name): str(text) for name, text in value.items()})
    return found


#: An objective's statuses, as the parameter takes them (FIX-BRIEFING-PARITY-MARTEAU-2 04).
_STATUSES = ("main", "secondary", "prerequisite")


def _status(value: Any) -> str:
    """An objective's status, checked; empty when none is given.

    Raises:
        ValueError: A status that is not one of ``main``, ``secondary``, ``prerequisite``.
    """
    if not value:
        return ""
    if str(value) not in _STATUSES:
        raise ValueError(f"objectives[].status: {value!r} is not one of {', '.join(_STATUSES)}")
    return str(value)


def build_briefing(params: dict[str, Any]) -> dict[str, Any]:
    """Run the action from its parameters.

    Args:
        params: The action's parameters, as the schema declares them.

    Returns:
        ``{deck, pages, pdf, pdf_pages, maps, pictures, miz, archives, kneeboard, recon, map_offline, warnings}``.

    Raises:
        ValueError: An unknown basemap or diversion field, an unbuilt mission, or an objective naming no zone
            of the mission.
    """
    basemap = str(params.get("basemap") or "osm")
    if basemap not in TILE_SOURCES:
        raise ValueError(f"unknown basemap {basemap!r}; expected one of {', '.join(TILE_SOURCES)}")
    content = BriefingContent(
        title=str(params["title"]),
        context=_lines(params.get("context")),
        mission=_lines(params.get("mission_bullets")),
        mission_prose=isinstance(params.get("mission_bullets"), str),
        strategic_situation=_lines(params.get("strategic_situation")),
        deployment=_lines(params.get("deployment")),
        waypoint_notes={
            str(k): str(v) for k, v in (params.get("waypoint_notes") or {}).items() if not isinstance(v, dict)
        },
        plan_notes=_plan_notes(params.get("waypoint_notes") or {}),
        objectives=tuple(
            Objective(
                str(o["zone"]),
                str(o.get("title") or o["zone"]),
                _lines(o.get("task")),
                _lines(o.get("flights")),
                _status(o.get("status")),
            )
            for o in params.get("objectives") or []
        ),
        threats=tuple(
            Threat(
                name=str(th["name"]),
                group=str(th["group"]),
                family=str(th.get("family") or ""),
                engagement_nm=float(th["engagement_nm"]) if th.get("engagement_nm") else None,
                detection_nm=float(th["detection_nm"]) if th.get("detection_nm") else None,
                source=str(th.get("source") or ""),
            )
            for th in params.get("threats") or []
        ),
        air_opposition=_lines(params.get("air_opposition")),
        air_defences=_lines(params.get("air_defences")),
        other=_lines(params.get("other")),
        pilots={str(k): [str(name) for name in v] for k, v in (params.get("pilots") or {}).items()},
        loadouts={str(k): str(v) for k, v in (params.get("loadouts") or {}).items()},
        diversions=_diversions(Path(params["mission_path"]), params.get("diversions")),
        flights=tuple(
            PackageFlight(
                callsign=str(f["callsign"]),
                base=str(f.get("base") or ""),
                aircraft=str(f.get("aircraft") or ""),
                count=int(f.get("count") or 0),
                task=str(f.get("task") or ""),
            )
            for f in params.get("flights") or []
        ),
        support=tuple(
            SupportAsset(
                callsign=str(a["callsign"]),
                role=str(a.get("role") or ""),
                frequency=str(a.get("frequency") or ""),
                details=str(a.get("details") or ""),
            )
            for a in params.get("support") or []
        ),
        code_words=tuple(
            CodeWord(word=str(c["word"]), meaning=str(c.get("meaning") or ""), who=str(c.get("who") or ""))
            for c in params.get("code_words") or []
        ),
    )
    report = build_mission_briefing(
        Path(params["mission_path"]),
        content,
        side=str(params.get("side") or "blue"),
        source=TILE_SOURCES[basemap],
        kneeboard=params.get("kneeboard") is not False,
        recon_folder=Path(params["recon_folder"]) if params.get("recon_folder") else None,
        kneeboard_replace=params.get("kneeboard_replace") is True,
    )
    return {
        "deck": str(report.deck),
        "pages": report.pages,
        "pdf": str(report.pdf) if report.pdf else None,
        "pdf_pages": report.pdf_pages,
        "maps": [str(path) for path in report.maps],
        "pictures": report.pictures,
        "miz": str(report.miz),
        "archives": [str(path) for path in report.archives],
        "kneeboard": report.kneeboard,
        "recon": [str(path) for path in report.recon],
        "map_offline": report.offline,
        "warnings": [*report.warnings, *missing_accents_warnings(_texts(content))],
    }


def _texts(content: BriefingContent) -> dict[str, str]:
    """The words the assistant passed, one text per field, to look for missing accents."""
    fields = {
        "title": [content.title],
        "context": content.context,
        "mission_bullets": content.mission,
        "strategic_situation": content.strategic_situation,
        "deployment": content.deployment,
        "code_words": tuple(f"{c.word} {c.meaning} {c.who}" for c in content.code_words),
        "support": tuple(f"{a.role} {a.details}" for a in content.support),
        "waypoint_notes": (
            *content.waypoint_notes.values(),
            *(text for notes in content.plan_notes.values() for text in notes.values()),
        ),
        "air_opposition": content.air_opposition,
        "air_defences": content.air_defences,
        "other": content.other,
    }
    for objective in content.objectives:
        fields[f"objective {objective.zone}"] = [objective.title, *objective.task]
    return {label: " ".join(lines) for label, lines in fields.items()}
