"""`build_mission_promotion` — a mission's poster, calendar banner and Discord post (FEAT-OBJECTIVE-MISSION-V2 12).

The announcement of "Marteau du Golan" was made by hand: a poster, a banner for the VEAF calendar and a
Discord post. The assistant passes the words; the executable reads the built mission and the briefing's
maps and photos (`mission_briefing/mission_promotion.py`).
"""

from pathlib import Path
from typing import Any

from mission_briefing.mission_promotion import PromotionContent, build_mission_promotion

from veaf_mission_mcp.accents import missing_accents_warnings
from veaf_mission_mcp.build_briefing import _lines


def build_promotion(params: dict[str, Any]) -> dict[str, Any]:
    """Run the action from its parameters.

    Args:
        params: The action's parameters, as the schema declares them.

    Returns:
        ``{poster, banner, discord, discord_post, discord_chars, warnings}``.

    Raises:
        ValueError: An unbuilt mission, or a post longer than Discord takes.
    """
    content = PromotionContent(
        title=str(params["title"]),
        event=str(params.get("event") or ""),
        tagline=_lines(params.get("tagline")),
        pitch=_lines(params.get("pitch")),
        program=_lines(params.get("program")),
        aircraft=_lines(params.get("aircraft")),
        practical=_lines(params.get("practical")),
        calendar_url=str(params.get("calendar_url") or ""),
        briefing_url=str(params.get("briefing_url") or ""),
        closing=str(params.get("closing") or ""),
    )
    report = build_mission_promotion(
        Path(params["mission_path"]),
        content,
        side=str(params.get("side") or "blue"),
        recon_folder=Path(params["recon_folder"]) if params.get("recon_folder") else None,
    )
    texts = {
        "title": content.title,
        "tagline": " ".join(content.tagline),
        "pitch": " ".join(content.pitch),
        "program": " ".join(content.program),
        "practical": " ".join(content.practical),
        "closing": content.closing,
    }
    return {
        "poster": str(report.poster),
        "banner": str(report.banner),
        "discord": str(report.discord),
        "discord_post": report.discord.read_text(encoding="utf-8"),
        "discord_chars": report.discord_chars,
        "warnings": [*report.warnings, *missing_accents_warnings(texts)],
    }
