"""`build_mission_briefing` — a one-shot mission's VEAF briefing, built by the server (FEAT-MCP-MISSION-BRIEFING).

An assistant with no shell — Claude Desktop in chat mode — cannot run the scripts the objective-mission
prompt used to ask for. It passes the scenario's words; the executable reads the built mission and
writes the PPTX, the maps and the DCS briefing pictures (`mission_briefing/`).
"""

from pathlib import Path
from typing import Any

from mission_briefing.mission_briefing_worker import build_mission_briefing
from mission_briefing.models import BriefingContent, Objective, Threat
from veaf_libs.map_tiles import TILE_SOURCES

from veaf_mission_mcp.accents import missing_accents_warnings
from veaf_mission_mcp.map_tools import list_airfields


def _lines(value: Any) -> tuple[str, ...]:
    """A list of lines, or one string as a single line."""
    if value is None:
        return ()
    return (str(value),) if isinstance(value, str) else tuple(str(item) for item in value)


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


def build_briefing(params: dict[str, Any]) -> dict[str, Any]:
    """Run the action from its parameters.

    Args:
        params: The action's parameters, as the schema declares them.

    Returns:
        ``{deck, pages, pdf, pdf_pages, maps, pictures, miz, archives, kneeboard, map_offline, warnings}``.

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
        objectives=tuple(
            Objective(str(o["zone"]), str(o.get("title") or o["zone"]), _lines(o.get("task")))
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
    )
    report = build_mission_briefing(
        Path(params["mission_path"]),
        content,
        side=str(params.get("side") or "blue"),
        source=TILE_SOURCES[basemap],
        kneeboard=params.get("kneeboard") is not False,
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
        "map_offline": report.offline,
        "warnings": [*report.warnings, *missing_accents_warnings(_texts(content))],
    }


def _texts(content: BriefingContent) -> dict[str, str]:
    """The words the assistant passed, one text per field, to look for missing accents."""
    fields = {
        "title": [content.title],
        "context": content.context,
        "mission_bullets": content.mission,
        "air_opposition": content.air_opposition,
        "air_defences": content.air_defences,
        "other": content.other,
    }
    for objective in content.objectives:
        fields[f"objective {objective.zone}"] = [objective.title, *objective.task]
    return {label: " ".join(lines) for label, lines in fields.items()}
