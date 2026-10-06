"""Drive a multi-mission campaign from the MCP: read it, apply a flown mission, build the next one.

The three actions are the loop of FEAT-MULTI-MISSION-CAMPAIGN as Claude runs it: ``campaign_status``
before deciding anything, ``campaign_apply`` once the squadron has flown and the state file has been
fetched, ``campaign_next`` to lay down the next mission folder — which Claude then designs with the
other actions. Each one is the matching ``veaf-tools campaign`` command, returning data instead of
printing it.
"""

from __future__ import annotations

from pathlib import Path
from typing import Any

from campaign_manager.campaign_manager import load_campaign, load_state, validate_state
from campaign_manager.campaign_worker import CampaignWorker
from campaign_manager.next_mission import BRIEFING_FILE, BRIEFING_LANGUAGES
from campaign_manager.turn_manager import describe_change, evaluate_objectives, garrison_strength, outcome
from veaf_libs.mission_validator import ERROR, ValidationIssue


def _refuse(issues: list[ValidationIssue]) -> None:
    errors = [issue.message for issue in issues if issue.level == ERROR]
    if errors:
        raise ValueError("\n".join(errors))


def campaign_status(campaign_folder: Path) -> dict[str, Any]:
    """Read where a campaign stands.

    Args:
        campaign_folder: The campaign folder, holding `campaign.yaml` and `campaign-state.yaml`.

    Returns:
        ``{campaign, mission, missions, outcome, zones, reserves, objectives, last_mission, warnings}``:
        ``mission`` is the number of missions applied, each zone gives its owner and its garrison
        strength in percent (``None`` while not drawn yet), ``last_mission`` what changed in it.

    Raises:
        ValueError: The campaign or its state is invalid, or the campaign has not been started.
    """
    worker = CampaignWorker(campaign_folder)
    campaign, issues = load_campaign(worker.campaign_file)
    _refuse(issues)
    assert campaign is not None
    if not worker.state_file.exists():
        raise ValueError(f"{worker.state_file} does not exist: start the campaign with `campaign init` first.")
    state, state_issues = load_state(worker.state_file)
    _refuse(state_issues)
    assert state is not None
    _refuse(validate_state(campaign, state))
    last = state.history[-1] if state.history else None
    return {
        "campaign": campaign.name,
        "mission": state.mission,
        "missions": campaign.missions,
        "player_side": campaign.player_side,
        "outcome": outcome(campaign, state),
        "zones": {
            zone.name: {
                "owner": state.zones[zone.name].owner,
                "strength_percent": garrison_strength(state.zones[zone.name].garrison),
                "kind": zone.kind,
                "neighbours": list(campaign.neighbours(zone.name)),
            }
            for zone in campaign.zones
        },
        "reserves": {side: dict(side_state.reserve) for side, side_state in state.sides.items()},
        "objectives": [
            {"kind": objective.kind, "zones": list(objective.zones), "met": met}
            for objective, met in evaluate_objectives(campaign, state)
        ],
        "last_mission": (
            {"mission": last["mission"], "changes": [describe_change(c) for c in last["changes"]]} if last else None
        ),
        "warnings": [issue.message for issue in issues if issue.level != ERROR],
    }


def campaign_apply(campaign_folder: Path, state_file: Path) -> dict[str, Any]:
    """Apply a flown mission's state file, then play the turn between missions.

    Args:
        campaign_folder: The campaign folder.
        state_file: The file the mission wrote, fetched from the server.

    Returns:
        ``{mission, changes, objectives, outcome, missions_left}``, the changes said in plain words.

    Raises:
        ValueError: The file is refused — already applied, from another campaign, skipping a
            mission, unreadable — or the campaign is invalid. Nothing is written then.
    """
    issues, report = CampaignWorker(campaign_folder).apply(state_file)
    _refuse(issues)
    assert report is not None
    return {
        "mission": report.mission,
        "changes": [describe_change(change) for change in report.changes],
        "objectives": [
            {"kind": objective.kind, "zones": list(objective.zones), "met": met} for objective, met in report.objectives
        ],
        "outcome": report.outcome,
        "missions_left": report.missions_left,
    }


def campaign_next(campaign_folder: Path) -> dict[str, Any]:
    """Create, or refresh, the next mission's folder from the campaign state.

    Args:
        campaign_folder: The campaign folder.

    Returns:
        ``{mission, folder, created, airbases, strategic_situation}``: the folder to design the
        mission in, and the factual part of its strategic briefing in each language.

    Raises:
        ValueError: The campaign is invalid, not started, or has no mission template.
    """
    issues, report = CampaignWorker(campaign_folder).next()
    _refuse(issues)
    assert report is not None
    return {
        "mission": report.mission,
        "folder": str(report.folder),
        "created": report.created,
        "airbases": report.airbases,
        "strategic_situation": {
            lang: (report.folder / BRIEFING_FILE.format(lang=lang)).read_text(encoding="utf-8")
            for lang in BRIEFING_LANGUAGES
        },
    }
