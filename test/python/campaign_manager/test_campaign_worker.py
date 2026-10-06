"""`campaign init` and `campaign validate` on a campaign folder (ticket 01)."""

from __future__ import annotations

import copy
from pathlib import Path

import yaml
from campaign_fixture import VALID
from campaign_manager.campaign_worker import CAMPAIGN_FILE, STATE_FILE, CampaignWorker
from typer.testing import CliRunner
from veaf_libs.i18n import t
from veaf_libs.mission_validator import ERROR


def _folder(tmp_path: Path, raw: dict | None = None) -> Path:
    (tmp_path / CAMPAIGN_FILE).write_text(yaml.safe_dump(raw or copy.deepcopy(VALID)), encoding="utf-8")
    return tmp_path


class TestInit:
    def test_it_writes_the_initial_state_next_to_the_campaign(self, tmp_path: Path) -> None:
        issues = CampaignWorker(_folder(tmp_path)).init()
        assert [i for i in issues if i.level == ERROR] == []
        state = yaml.safe_load((tmp_path / STATE_FILE).read_text(encoding="utf-8"))
        assert state["zones"]["Kobuleti"]["owner"] == "blue"

    def test_it_never_overwrites_an_existing_state(self, tmp_path: Path) -> None:
        folder = _folder(tmp_path)
        (folder / STATE_FILE).write_text("mission: 4\n", encoding="utf-8")
        issues = CampaignWorker(folder).init()
        assert [i.message for i in issues] == [t("campaign.issue.state_exists", path=folder / STATE_FILE)]
        assert (folder / STATE_FILE).read_text(encoding="utf-8") == "mission: 4\n"

    def test_an_invalid_campaign_writes_nothing(self, tmp_path: Path) -> None:
        raw = copy.deepcopy(VALID)
        raw["campaign"]["theatre"] = "Atlantis"
        folder = _folder(tmp_path, raw)
        issues = CampaignWorker(folder).init()
        assert any(i.level == ERROR for i in issues)
        assert not (folder / STATE_FILE).exists()

    def test_a_folder_without_campaign_yaml_is_reported(self, tmp_path: Path) -> None:
        issues = CampaignWorker(tmp_path).init()
        assert [i.message for i in issues] == [t("campaign.issue.no_campaign_file", path=tmp_path / CAMPAIGN_FILE)]

    def test_a_campaign_yaml_that_is_not_yaml_is_reported(self, tmp_path: Path) -> None:
        (tmp_path / CAMPAIGN_FILE).write_text("campaign: [unclosed", encoding="utf-8")
        issues = CampaignWorker(tmp_path).init()
        assert [i.message for i in issues] == [t("campaign.issue.campaign_unreadable", path=tmp_path / CAMPAIGN_FILE)]


class TestValidate:
    def test_a_campaign_freshly_initialised_is_clean(self, tmp_path: Path) -> None:
        folder = _folder(tmp_path)
        CampaignWorker(folder).init()
        assert CampaignWorker(folder).validate() == []

    def test_a_campaign_not_yet_initialised_validates_the_definition_alone(self, tmp_path: Path) -> None:
        assert CampaignWorker(_folder(tmp_path)).validate() == []

    def test_a_state_that_no_longer_matches_the_campaign_is_reported(self, tmp_path: Path) -> None:
        folder = _folder(tmp_path)
        CampaignWorker(folder).init()
        raw = copy.deepcopy(VALID)
        raw["campaign"]["name"] = "Renamed"
        (folder / CAMPAIGN_FILE).write_text(yaml.safe_dump(raw), encoding="utf-8")
        messages = [i.message for i in CampaignWorker(folder).validate()]
        assert messages == [t("campaign.issue.state_other_campaign", found="Caucasus Front", expected="Renamed")]


def _state_file(folder: Path, mission: int = 1, campaign: str = "Caucasus Front", senaki: str = "neutral") -> Path:
    """A state file as the mission writes it: a Lua literal."""
    from luadata.io.write import write

    current = yaml.safe_load((folder / STATE_FILE).read_text(encoding="utf-8"))
    current["mission"] = mission
    current["campaign"] = campaign
    current["zones"]["Senaki"]["owner"] = senaki
    for zone in current["zones"].values():
        for key in [k for k, v in zone.items() if v is None]:
            del zone[key]
    path = folder / f"mission-{mission:02d}.state"
    write(str(path), current, prefix="return ")
    return path


class TestApply:
    def test_a_flown_mission_is_merged_played_and_archived(self, tmp_path: Path) -> None:
        folder = _folder(tmp_path)
        worker = CampaignWorker(folder)
        worker.init()
        issues, report = worker.apply(_state_file(folder))
        assert issues == []
        assert report is not None
        assert report.mission == 1
        state = yaml.safe_load((folder / STATE_FILE).read_text(encoding="utf-8"))
        assert state["mission"] == 1
        # Senaki was freed by the flight; bordered by blue Kobuleti and the red depot, it stays neutral
        assert state["zones"]["Senaki"]["owner"] == "neutral"
        assert state["history"][0]["mission"] == 1
        archive = worker.mission_folder(1)
        assert sorted(p.name for p in archive.iterdir()) == [
            "campaign-state.after.yaml",
            "campaign-state.before.yaml",
            "mission-01.state",
        ]
        before = yaml.safe_load((archive / "campaign-state.before.yaml").read_text(encoding="utf-8"))
        assert before["mission"] == 0

    def test_applying_the_same_file_twice_is_refused_and_changes_nothing(self, tmp_path: Path) -> None:
        folder = _folder(tmp_path)
        worker = CampaignWorker(folder)
        worker.init()
        path = _state_file(folder)
        worker.apply(path)
        after_first = (folder / STATE_FILE).read_text(encoding="utf-8")
        issues, report = worker.apply(path)
        assert report is None
        assert [i.message for i in issues] == [t("campaign.issue.state_file_already_applied", mission=1)]
        assert (folder / STATE_FILE).read_text(encoding="utf-8") == after_first

    def test_a_file_from_another_campaign_is_refused(self, tmp_path: Path) -> None:
        folder = _folder(tmp_path)
        worker = CampaignWorker(folder)
        worker.init()
        issues, report = worker.apply(_state_file(folder, campaign="Syria Front"))
        assert report is None
        assert [i.message for i in issues] == [
            t("campaign.issue.state_other_campaign", found="Syria Front", expected="Caucasus Front")
        ]
        assert not (folder / "missions").exists()

    def test_a_campaign_not_started_is_reported(self, tmp_path: Path) -> None:
        folder = _folder(tmp_path)
        issues, report = CampaignWorker(folder).apply(tmp_path / "x.state")
        assert report is None
        assert [i.message for i in issues] == [t("campaign.issue.not_started", path=folder / STATE_FILE)]

    def test_the_objectives_and_outcome_are_reported(self, tmp_path: Path) -> None:
        folder = _folder(tmp_path)
        worker = CampaignWorker(folder)
        worker.init()
        _, report = worker.apply(_state_file(folder, senaki="blue"))
        assert report is not None
        assert [met for _, met in report.objectives] == [True, False]
        assert report.outcome == "running"
        assert report.missions_left == 7


class TestTheCommands:
    def test_init_then_validate_from_the_command_line(self, tmp_path: Path) -> None:
        import veaf_tools.commands  # noqa: F401  — registers the commands
        from veaf_tools.app import app

        folder = _folder(tmp_path)
        runner = CliRunner()
        result = runner.invoke(app, ["campaign-init", str(folder)])
        assert result.exit_code == 0, result.output
        assert (folder / STATE_FILE).exists()
        result = runner.invoke(app, ["campaign-validate", str(folder)])
        assert result.exit_code == 0, result.output

    def test_apply_from_the_command_line(self, tmp_path: Path) -> None:
        import veaf_tools.commands  # noqa: F401
        from veaf_tools.app import app

        folder = _folder(tmp_path)
        CampaignWorker(folder).init()
        state_file = _state_file(folder, senaki="blue")
        result = CliRunner().invoke(app, ["campaign-apply", str(state_file), str(folder)])
        assert result.exit_code == 0, result.output
        from campaign_manager.turn_manager import describe_change

        assert describe_change({"kind": "owner", "zone": "Senaki", "from": "red", "to": "blue"}) in result.output
        result = CliRunner().invoke(app, ["campaign-apply", str(state_file), str(folder)])
        assert result.exit_code == 1

    def test_validate_exits_non_zero_on_an_error(self, tmp_path: Path) -> None:
        import veaf_tools.commands  # noqa: F401
        from veaf_tools.app import app

        raw = copy.deepcopy(VALID)
        raw["campaign"]["era"] = "VIKING"
        result = CliRunner().invoke(app, ["campaign-validate", str(_folder(tmp_path, raw))])
        assert result.exit_code == 1
