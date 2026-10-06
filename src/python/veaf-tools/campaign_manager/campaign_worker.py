"""The campaign folder's commands: `campaign init` and `campaign validate` (ticket 01).

A campaign is a folder: `campaign.yaml`, what the author declares and the tools never rewrite;
`campaign-state.yaml`, what the campaign has become, rewritten after every mission; and one
sub-folder per mission under `missions/` (tickets 08 and 09).
"""

from __future__ import annotations

import shutil
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from veaf_libs.i18n import language, t
from veaf_libs.mission_validator import ERROR, ValidationIssue

from campaign_manager.campaign_manager import initial_state, load_campaign, load_state, save_state, validate_state
from campaign_manager.debriefing import debriefing_text
from campaign_manager.models import Objective
from campaign_manager.next_mission import BRIEFING_LANGUAGES, NextMissionReport, prepare_next_mission
from campaign_manager.turn_manager import (
    evaluate_objectives,
    merge_state_file,
    outcome,
    play_turn,
    read_state_file,
    validate_state_file,
)

#: What the author writes.
CAMPAIGN_FILE = "campaign.yaml"

#: What the campaign has become.
STATE_FILE = "campaign-state.yaml"

#: Where each mission's history is kept, one sub-folder per mission.
MISSIONS_FOLDER = "missions"

#: The debriefing `apply` writes in the mission's sub-folder, one file per language.
DEBRIEFING_FILE = "debriefing.{lang}.txt"

#: The mission folder itself, inside a mission's sub-folder.
MISSION_SUBFOLDER = "mission"


@dataclass(frozen=True)
class ApplyReport:
    """What applying a mission did, for the command to print."""

    mission: int
    changes: list[dict[str, Any]]
    objectives: list[tuple[Objective, bool]]
    outcome: str
    missions_left: int
    debriefing: dict[str, str]
    """The debriefing, by language, as written next to the state file."""
    folder: Path
    """The mission's sub-folder, where the debriefing and the states before and after are kept."""


class CampaignWorker:
    """Runs the campaign commands on one campaign folder."""

    def __init__(self, folder: Path) -> None:
        """Bind the worker to a folder.

        Args:
            folder: The campaign folder, holding `campaign.yaml`.
        """
        self.folder = folder
        self.campaign_file = folder / CAMPAIGN_FILE
        self.state_file = folder / STATE_FILE

    def init(self) -> list[ValidationIssue]:
        """Create the initial campaign state from `campaign.yaml`.

        An existing state is never overwritten: it holds missions already flown.

        Returns:
            Every issue found. When one is an error, nothing was written.
        """
        if self.state_file.exists():
            return [ValidationIssue(ERROR, t("campaign.issue.state_exists", path=self.state_file))]
        campaign, issues = load_campaign(self.campaign_file)
        if campaign is None:
            return issues
        save_state(initial_state(campaign), self.state_file)
        return issues

    def mission_folder(self, mission: int) -> Path:
        """Return the sub-folder that keeps one mission's history.

        Args:
            mission: The mission number.

        Returns:
            ``missions/mission-NN`` under the campaign folder.
        """
        return self.folder / MISSIONS_FOLDER / f"mission-{mission:02d}"

    def apply(self, state_file: Path) -> tuple[list[ValidationIssue], ApplyReport | None]:
        """Apply a flown mission's state file: merge it, play the turn, judge the objectives.

        The mission's sub-folder keeps the state file and the campaign state before and after, so a
        merge can be looked at, or undone by putting the *before* file back.

        Args:
            state_file: The file the mission wrote.

        Returns:
            Every issue found, and the report — ``None`` when any issue is an error, in which case
            nothing was written.
        """
        campaign, issues = load_campaign(self.campaign_file)
        if campaign is None:
            return issues, None
        if not self.state_file.exists():
            return [*issues, ValidationIssue(ERROR, t("campaign.issue.not_started", path=self.state_file))], None
        current, state_issues = load_state(self.state_file)
        if current is None:
            return issues + state_issues, None
        flown, flown_issues = read_state_file(state_file)
        issues = issues + flown_issues
        if flown is None:
            return issues, None
        refused = validate_state_file(campaign, current, flown)
        if refused:
            return issues + refused, None

        merged, flight = merge_state_file(current, flown)
        turn = play_turn(campaign, merged)
        changes = flight + turn
        result = outcome(campaign, merged)
        merged.history.append({"mission": merged.mission, "changes": changes, "outcome": result})

        archive = self.mission_folder(merged.mission)
        archive.mkdir(parents=True, exist_ok=True)
        # both the file and its temporary when there is one: the one actually read may be either
        for written in (state_file, state_file.with_name(state_file.name + ".tmp")):
            if written.is_file():
                shutil.copyfile(written, archive / written.name)
        save_state(current, archive / "campaign-state.before.yaml")
        save_state(merged, archive / "campaign-state.after.yaml")
        save_state(merged, self.state_file)
        debriefing = {}
        for lang in BRIEFING_LANGUAGES:
            with language(lang):
                debriefing[lang] = debriefing_text(campaign, merged, flight, turn)
            (archive / DEBRIEFING_FILE.format(lang=lang)).write_text(debriefing[lang], encoding="utf-8")
        return issues, ApplyReport(
            mission=merged.mission,
            changes=changes,
            objectives=evaluate_objectives(campaign, merged),
            outcome=result,
            missions_left=max(campaign.missions - merged.mission, 0),
            debriefing=debriefing,
            folder=archive,
        )

    def next(self) -> tuple[list[ValidationIssue], NextMissionReport | None]:
        """Create, or refresh, the next mission's folder: ``missions/mission-NN/mission``.

        Returns:
            Every issue found, and the report — ``None`` when any issue is an error.
        """
        campaign, issues = load_campaign(self.campaign_file)
        if campaign is None:
            return issues, None
        if not self.state_file.exists():
            return [*issues, ValidationIssue(ERROR, t("campaign.issue.not_started", path=self.state_file))], None
        state, state_issues = load_state(self.state_file)
        if state is None:
            return issues + state_issues, None
        mismatch = validate_state(campaign, state)
        if mismatch:
            return issues + mismatch, None
        folder = self.mission_folder(state.mission + 1) / MISSION_SUBFOLDER
        try:
            report = prepare_next_mission(campaign, state, self.folder, folder)
        except FileNotFoundError as error:
            return [*issues, ValidationIssue(ERROR, str(error))], None
        return issues, report

    def validate(self) -> list[ValidationIssue]:
        """Check `campaign.yaml`, and the campaign state against it when there is one.

        Returns:
            Every issue found; empty when the folder is clean.
        """
        campaign, issues = load_campaign(self.campaign_file)
        if campaign is None or not self.state_file.exists():
            return issues
        state, state_issues = load_state(self.state_file)
        if state is None:
            return issues + state_issues
        return issues + validate_state(campaign, state)
