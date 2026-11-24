"""Drive a multi-mission campaign from the MCP: read it, apply a flown mission, build the next one.

``campaign_init`` and ``campaign_validate`` start and check a campaign, a persistent one included
(FEAT-PERSISTENT-CAMPAIGN-AI). The other actions are the loop of FEAT-MULTI-MISSION-CAMPAIGN as Claude runs it: ``campaign_status``
before deciding anything, ``campaign_apply`` once the squadron has flown and the state file has been
fetched, ``campaign_next`` to lay down the next mission folder — which Claude then designs with the
other actions —, ``campaign_briefing`` for the strategic briefing deck around `briefing.yaml`. Each
one is the matching ``veaf-tools campaign`` command, returning data instead of printing it.
"""

from __future__ import annotations

from pathlib import Path
from typing import Any

from campaign_manager.briefing_prose import SECTIONS
from campaign_manager.campaign_manager import load_campaign, load_state, parse_players, validate_state
from campaign_manager.campaign_worker import CampaignWorker
from campaign_manager.next_mission import BRIEFING_FILE, BRIEFING_LANGUAGES
from campaign_manager.turn_manager import describe_change, evaluate_objectives, garrison_strength, outcome
from veaf_libs.i18n import t
from veaf_libs.mission_validator import ERROR, ValidationIssue


def _refuse(issues: list[ValidationIssue]) -> None:
    errors = [issue.message for issue in issues if issue.level == ERROR]
    if errors:
        raise ValueError("\n".join(errors))


def campaign_init(campaign_folder: Path, example: str | None = None) -> dict[str, Any]:
    """Lay down a shipped example campaign, or start the campaign: ``campaign init``.

    Args:
        campaign_folder: The campaign folder; created when an example is laid down in it.
        example: `persistent` or `multi-mission`: copy that shipped example into a folder that has no
            `campaign.yaml` yet, and draw no state. Omitted: draw the initial state from `campaign.yaml`.

    Returns:
        ``{started: False, copied}`` for an example, the files written; ``{started: True, state_file,
        warnings}`` for a campaign started.

    Raises:
        ValueError: An unknown example, a `campaign.yaml` already there, an invalid campaign, or a
            campaign already started. Nothing is written then.
    """
    worker = CampaignWorker(campaign_folder)
    if example is not None:
        issues, copied = worker.scaffold(example)
        _refuse(issues)
        return {"started": False, "copied": [str(path) for path in copied]}
    issues = worker.init()
    _refuse(issues)
    return {
        "started": True,
        "state_file": str(worker.state_file),
        "warnings": [issue.message for issue in issues if issue.level != ERROR],
    }


def campaign_validate(campaign_folder: Path) -> dict[str, Any]:
    """Check a campaign folder: `campaign.yaml`, the state against it, and `briefing.yaml`.

    Args:
        campaign_folder: The campaign folder.

    Returns:
        ``{valid, errors, warnings}``, the messages ``campaign validate`` prints; ``valid`` is true when
        there is no error. Never raises on an invalid campaign: reporting it is the point.
    """
    issues = CampaignWorker(campaign_folder).validate()
    errors = [issue.message for issue in issues if issue.level == ERROR]
    return {
        "valid": not errors,
        "errors": errors,
        "warnings": [issue.message for issue in issues if issue.level != ERROR],
    }


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
        ``{mission, changes, objectives, outcome, missions_left, debriefing}``, the changes said in
        plain words, and the factual debriefing by language — the one `apply` wrote next to the state
        file.

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
        "debriefing": report.debriefing,
    }


def campaign_next(campaign_folder: Path, players: int | str | None = None) -> dict[str, Any]:
    """Create, or refresh, the next mission's folder from the campaign state.

    Args:
        campaign_folder: The campaign folder.
        players: How many players are expected tonight, a count or a range (``"5-7"``); beats
            `campaign.yaml`'s `players`.

    Returns:
        ``{mission, folder, created, airbases, conditions, briefing_deck, mission_deck,
        strategic_situation}``: the folder to design the mission in; the date, start time and weather
        fixed in a folder created now (``None`` on a refresh, which keeps them); the strategic briefing
        deck written next to it (``None`` when `briefing.yaml` has an error) and the mission's own
        briefing (``None`` until the mission is built); and the factual part of its strategic briefing
        in each language.

    Raises:
        ValueError: The campaign is invalid, not started, has no mission template, or `players` is not a
            count of players.
    """
    expected = None
    if players is not None:
        try:
            expected = parse_players(players)
        except ValueError:
            raise ValueError(t("campaign.issue.bad_players", value=players)) from None
    issues, report = CampaignWorker(campaign_folder).next(players=expected)
    _refuse(issues)
    assert report is not None
    return {
        "mission": report.mission,
        "folder": str(report.folder),
        "created": report.created,
        "name": report.name,
        "security_restored": report.security_restored,
        "interpreter_commands": report.interpreter_commands,
        "airbases": report.airbases,
        "conditions": (
            {
                "date": report.conditions.date.isoformat(),
                "start_time": report.conditions.clock,
                "weather": report.conditions.weather,
            }
            if report.conditions
            else None
        ),
        "briefing_deck": str(report.deck) if report.deck else None,
        "mission_deck": str(report.mission_deck) if report.mission_deck else None,
        "strategic_situation": {
            lang: (report.folder / BRIEFING_FILE.format(lang=lang)).read_text(encoding="utf-8")
            for lang in BRIEFING_LANGUAGES
        },
    }


def campaign_briefing(campaign_folder: Path) -> dict[str, Any]:
    """Write the coming mission's strategic briefing deck, from the campaign and its `briefing.yaml`.

    Args:
        campaign_folder: The campaign folder.

    Returns:
        ``{path, map, pages, prose, map_offline, mission_deck, sections, warnings}``: the deck and its
        map, its page count, whether `briefing.yaml` was there, whether the map had to do without its
        background, the mission's own briefing (``None`` until the mission is built — a warning then
        says how), and the sections `briefing.yaml` may hold.

    Raises:
        ValueError: The campaign is invalid or not started, or `briefing.yaml` has an error.
    """
    issues, report = CampaignWorker(campaign_folder).briefing()
    _refuse(issues)
    assert report is not None
    return {
        "path": str(report.path),
        "map": str(report.map.path),
        "pages": report.pages,
        "prose": report.prose,
        "map_offline": report.map.offline,
        "mission_deck": str(report.mission_deck) if report.mission_deck else None,
        "sections": {section: list(parts) for section, parts in SECTIONS.items()},
        "warnings": [issue.message for issue in issues if issue.level != ERROR],
    }
