"""The campaign folder's commands: `campaign init` and `campaign validate` (ticket 01).

A campaign is a folder: `campaign.yaml`, what the author declares and the tools never rewrite;
`campaign-state.yaml`, what the campaign has become, rewritten after every mission; and one
sub-folder per mission under `missions/` (tickets 08 and 09).
"""

from __future__ import annotations

import shutil
import zipfile
from dataclasses import dataclass, replace
from pathlib import Path
from typing import Any

from veaf_libs.i18n import language, t
from veaf_libs.map_tiles import Fetch
from veaf_libs.mission_validator import ERROR, WARNING, ValidationIssue

from campaign_manager.briefing_deck import DeckReport, campaign_deck
from campaign_manager.briefing_prose import BriefingProse, load_prose
from campaign_manager.campaign_manager import initial_state, load_campaign, load_state, save_state, validate_state
from campaign_manager.debriefing import debriefing_text
from campaign_manager.mission_conditions import folder_date
from campaign_manager.mission_deck import MissionDeckReport, mission_deck
from campaign_manager.mission_picture import find_built_mission, read_mission_picture
from campaign_manager.models import CampaignDefinition, CampaignState, Objective
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

    def __init__(self, folder: Path, *, tile_cache: Path | None = None, tile_fetch: Fetch | None = None) -> None:
        """Bind the worker to a folder.

        Args:
            folder: The campaign folder, holding `campaign.yaml`.
            tile_cache: Where the strategic map's tiles are kept; the user's cache when omitted.
            tile_fetch: How a map tile is downloaded; from OpenStreetMap when omitted.
        """
        self.folder = folder
        self.campaign_file = folder / CAMPAIGN_FILE
        self.state_file = folder / STATE_FILE
        self.tile_cache = tile_cache
        self.tile_fetch = tile_fetch

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
        entry: dict[str, Any] = {"mission": merged.mission, "changes": changes, "outcome": result}
        flown_on = folder_date(self.mission_folder(merged.mission) / MISSION_SUBFOLDER)
        if flown_on:
            entry["date"] = flown_on  # the next mission's date follows it
        merged.history.append(entry)

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

    def next(self, players: tuple[int, int] | None = None) -> tuple[list[ValidationIssue], NextMissionReport | None]:
        """Create, or refresh, the next mission's folder: ``missions/mission-NN/mission``.

        Args:
            players: How many players are expected tonight, beating `campaign.yaml`'s `players`.

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
        # the tasks name the zones the waypoints go to; a defect in briefing.yaml is the deck's to report
        prose, prose_issues = load_prose(self.folder, campaign.missions, state.mission + 1)
        page = (
            prose.missions.get(state.mission + 1) if prose and not any(i.level == ERROR for i in prose_issues) else None
        )
        try:
            report = prepare_next_mission(campaign, state, self.folder, folder, players=players, page=page)
        except FileNotFoundError as error:
            return [*issues, ValidationIssue(ERROR, str(error))], None
        # the deck comes with the folder; neither a defect in briefing.yaml nor a failure to draw it
        # stops the mission, which is what the squadron flies
        try:
            deck_issues, deck = self._deck(campaign, state)
        except (OSError, KeyError, ValueError) as error:
            deck_issues, deck = [ValidationIssue(WARNING, t("campaign.issue.deck_failed", error=error))], None
        issues += [ValidationIssue(WARNING, issue.message) for issue in deck_issues]
        return issues, replace(
            report, deck=deck.path if deck else None, mission_deck=deck.mission_deck if deck else None
        )

    def briefing(self) -> tuple[list[ValidationIssue], DeckReport | None]:
        """Write the coming mission's briefings: ``missions/mission-NN/briefing-campagne.pptx``, and
        ``briefing-mission.pptx`` once the mission has been built.

        Returns:
            Every issue found — a mission not built yet is a warning saying how to build it —, and the
            report: ``None`` when any issue is an error.
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
        deck_issues, report = self._deck(campaign, state)
        folder = self.mission_folder(state.mission + 1) / MISSION_SUBFOLDER
        if report is not None and find_built_mission(folder) is None:
            deck_issues = [*deck_issues, ValidationIssue(WARNING, t("campaign.issue.no_built_mission", folder=folder))]
        return issues + deck_issues, report

    def _deck(
        self, campaign: CampaignDefinition, state: CampaignState
    ) -> tuple[list[ValidationIssue], DeckReport | None]:
        """Generate the deck from `briefing.yaml`, unless that file has an error."""
        prose, issues = load_prose(self.folder, campaign.missions, state.mission + 1)
        if any(issue.level == ERROR for issue in issues):
            return issues, None
        report = campaign_deck(
            campaign,
            state,
            prose,
            self.mission_folder(state.mission + 1),
            cache_dir=self.tile_cache,
            fetch=self.tile_fetch,
        )
        built = find_built_mission(self.mission_folder(state.mission + 1) / MISSION_SUBFOLDER)
        if built is None:
            return issues, report
        try:
            mission = self._mission_deck(campaign, state, prose, built)
        except (OSError, KeyError, ValueError, zipfile.BadZipFile) as error:  # a build cut short
            return [*issues, ValidationIssue(WARNING, t("campaign.issue.mission_deck_failed", error=error))], report
        return issues, replace(report, mission_deck=mission.path)

    def _mission_deck(
        self, campaign: CampaignDefinition, state: CampaignState, prose: BriefingProse | None, built: Path
    ) -> MissionDeckReport:
        """Write the mission's own briefing from its built `.miz`."""
        picture = read_mission_picture(built, campaign.player_side, built.parent)
        return mission_deck(
            campaign,
            state,
            prose,
            picture,
            self.mission_folder(state.mission + 1),
            cache_dir=self.tile_cache,
            fetch=self.tile_fetch,
        )

    def validate(self) -> list[ValidationIssue]:
        """Check `campaign.yaml`, the campaign state against it when there is one, and `briefing.yaml`.

        Returns:
            Every issue found; empty when the folder is clean.
        """
        campaign, issues = load_campaign(self.campaign_file)
        if campaign is None:
            return issues
        coming = 1
        if self.state_file.exists():
            state, state_issues = load_state(self.state_file)
            if state is None:
                return issues + state_issues
            issues = issues + validate_state(campaign, state)
            coming = state.mission + 1
        return issues + load_prose(self.folder, campaign.missions, coming)[1]
