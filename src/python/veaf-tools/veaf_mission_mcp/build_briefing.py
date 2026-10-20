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


def _lines(value: Any) -> tuple[str, ...]:
    """A list of lines, or one string as a single line."""
    if value is None:
        return ()
    return (str(value),) if isinstance(value, str) else tuple(str(item) for item in value)


def build_briefing(params: dict[str, Any]) -> dict[str, Any]:
    """Run the action from its parameters.

    Args:
        params: The action's parameters, as the schema declares them.

    Returns:
        ``{deck, pages, maps, pictures, miz, map_offline, warnings}``.

    Raises:
        ValueError: An unknown basemap, an unbuilt mission, or an objective naming no zone of the mission.
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
    )
    report = build_mission_briefing(
        Path(params["mission_path"]), content, side=str(params.get("side") or "blue"), source=TILE_SOURCES[basemap]
    )
    return {
        "deck": str(report.deck),
        "pages": report.pages,
        "maps": [str(path) for path in report.maps],
        "pictures": report.pictures,
        "miz": str(report.miz),
        "map_offline": report.offline,
        "warnings": report.warnings,
    }
