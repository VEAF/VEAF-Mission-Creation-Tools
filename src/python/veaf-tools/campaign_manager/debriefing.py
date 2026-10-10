"""The debriefing of a campaign mission, written by `campaign apply` (FEAT-MULTI-MISSION-CAMPAIGN ticket 12).

The factual account of what the flight did — ground changing hands, each side's losses zone by zone
and type by type, scenery destroyed — then what the turn between missions did, and where the
objectives stand. It is written for the squadron, to read after the evening or to post as it is;
Claude tells it as a story when asked, from the same facts (David, 2026-10-06: "a+b").
"""

from __future__ import annotations

from typing import Any

from veaf_libs.i18n import t

from campaign_manager.models import COALITIONS, CampaignDefinition, CampaignState
from campaign_manager.turn_manager import describe_change, evaluate_objectives, outcome


def _losses_lines(losses: list[dict[str, Any]], player_side: str) -> list[str]:
    """The losses section: per side, the players' first, its total, then one line per zone with its unit types."""
    lines = []
    for side in sorted(COALITIONS, key=lambda side: side != player_side):
        own = [change for change in losses if change["side"] == side]
        if not own:
            continue
        side_name = t(f"campaign.side_name.{side}")
        lines.append(t("campaign.debriefing.side_losses", side=side_name, count=sum(c["lost"] for c in own)))
        for change in own:
            types = ", ".join(f"{count} × {unit_type}" for unit_type, count in change["types"].items())
            lines.append(t("campaign.debriefing.zone_losses", zone=change["zone"], count=change["lost"], types=types))
    return lines or [t("campaign.debriefing.no_losses")]


def debriefing_text(
    campaign: CampaignDefinition,
    state: CampaignState,
    flight: list[dict[str, Any]],
    turn: list[dict[str, Any]],
) -> str:
    """Write the debriefing of the mission just applied, in the current language.

    Args:
        campaign: The validated campaign.
        state: The campaign state after the merge and the turn.
        flight: The changes the merge found — what the flight did.
        turn: The changes the turn between missions made.

    Returns:
        Plain text, one fact per line.
    """
    lines = [t("campaign.debriefing.header", campaign=campaign.name, mission=state.mission, missions=campaign.missions)]

    owners = [change for change in flight if change["kind"] == "owner"]
    lines += ["", t("campaign.debriefing.ground")]
    lines += [f"- {describe_change(change)}" for change in owners] or [t("campaign.debriefing.no_ground")]

    lines += ["", t("campaign.debriefing.losses")]
    lines += _losses_lines([change for change in flight if change["kind"] == "losses"], campaign.player_side)
    for change in flight:
        if change["kind"] == "scenery":
            lines.append(t("campaign.debriefing.scenery", count=change["destroyed"]))
        elif change["kind"] == "convoy_returned":
            lines.append(f"- {describe_change(change)}")

    lines += ["", t("campaign.debriefing.turn")]
    lines += [f"- {describe_change(change)}" for change in turn] or [t("campaign.debriefing.quiet_turn")]

    lines += ["", t("campaign.briefing.objectives")]
    for objective, met in evaluate_objectives(campaign, state):
        mark = "[x]" if met else "[ ]"
        lines.append(f"{mark} {t(f'campaign.objective.{objective.kind}', zones=', '.join(objective.zones))}")
    result = outcome(campaign, state)
    key = "campaign.debriefing.left" if result == "running" else f"campaign.briefing.outcome.{result}"
    lines.append(t(key, left=max(campaign.missions - state.mission, 0)))
    return "\n".join(lines) + "\n"
