"""Building the next mission of a campaign from its state (ticket 09)."""

from __future__ import annotations

import copy
import shutil
from pathlib import Path
from typing import Any

import pytest
import yaml
from campaign_fixture import VALID
from campaign_manager.campaign_manager import initial_state, parse_campaign
from campaign_manager.campaign_worker import CAMPAIGN_FILE, STATE_FILE, CampaignWorker
from campaign_manager.models import CampaignDefinition, CampaignState
from campaign_manager.next_mission import DATA_FILE, mission_data, prepare_next_mission, strategic_situation
from lua_runner import run_lua
from mission_tools.miz_tools import DcsMission
from typer.testing import CliRunner
from veaf_libs.blank_mission import generate_blank_mission
from veaf_libs.dcs_airdromes import airdrome_id_for_name
from veaf_libs.i18n import language, t
from veaf_libs.lua_config_generator import generate_config_lua
from veaf_libs.mission_validator import ERROR, WARNING
from veaf_mission_mcp.mission_folder import load_folder_mission
from veaf_mission_mcp.mission_settings import set_briefing

REPO = Path(__file__).resolve().parents[3]


def _campaign() -> CampaignDefinition:
    campaign, issues = parse_campaign(copy.deepcopy(VALID))
    assert campaign is not None, issues
    return campaign


def _template(folder: Path) -> Path:
    """A minimal mission folder, as `prepare --theatre Caucasus` lays one down."""
    template = folder / "template"
    for relative, content in generate_blank_mission("Caucasus").items():
        path = template / "src" / "mission" / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(content)
    shutil.copy(
        REPO / "src" / "defaults" / "mission-folder" / "src" / "warehouses.yaml", template / "src" / "warehouses.yaml"
    )
    (template / "mission.yaml").write_text(
        "# the mission maker's comment, kept\nmission:\n  name: Campaign mission\nmodules:\n  UNITS: true\n",
        encoding="utf-8",
    )
    (template / "build").mkdir()
    (template / "build" / "old.miz").write_bytes(b"x")
    return template


def _airport(mission: DcsMission, name: str) -> dict[str, Any]:
    return mission.warehouses_content["airports"][airdrome_id_for_name("Caucasus", name)]


def _briefing(mission: DcsMission) -> str:
    """The situation text of the briefing, through the dictionary key when there is one."""
    text = mission.mission_content.get("descriptionText")
    dictionary = mission.dictionary_content or {}
    return str(dictionary.get(text, text))


# ---------------------------------------------------------------------------
# The data table
# ---------------------------------------------------------------------------


class TestTheDataTable:
    def test_it_carries_what_the_runtime_module_reads(self) -> None:
        campaign = _campaign()
        state = initial_state(campaign)
        state.mission = 2
        data = mission_data(campaign, state)
        assert (data["campaign"], data["mission"], data["missions"]) == ("Caucasus Front", 3, 8)
        assert (data["capture_seconds"], data["state_write_seconds"]) == (120, 60)
        assert data["objectives"] == [
            {"kind": "capture", "zones": ["Senaki"]},
            {"kind": "destroy", "zones": ["Gudauta depot"]},
        ]
        assert data["connections"] == [["Kobuleti", "Senaki"], ["Senaki", "Gudauta depot"]]
        assert data["sides"]["red"] == {"reserve": {"armor": 0, "air_defense": 0, "transport": 0}}

    def test_an_airfield_zone_is_placed_by_its_airbase_and_a_point_by_its_coordinates(self) -> None:
        data = mission_data(_campaign(), initial_state(_campaign()))
        senaki, depot = data["zones"][1], data["zones"][2]
        assert senaki["airbase"] == "Senaki-Kolkhi"
        assert "lat" not in senaki
        assert (depot["lat"], depot["lon"]) == (43.10, 40.58)
        assert depot["kind"] == "logistics"
        assert depot["garrison_list"] == ["sa8", "shilka", "T-72B"]
        assert depot["declared_side"] == "red"  # a side taking the zone draws its own

    def test_a_zone_carries_its_size_class_parameters_and_its_recorded_garrison(self) -> None:
        campaign = _campaign()
        state = initial_state(campaign)
        state.zones["Senaki"].garrison = [{"name": "g", "units": []}]
        senaki = mission_data(campaign, state)["zones"][1]
        assert senaki["size"] == {"size": 1, "defense": 3, "armor": 2, "long_range_sam": True}
        assert senaki["garrison"] == [{"name": "g", "units": []}]
        assert "garrison" not in mission_data(campaign, state)["zones"][0]


# ---------------------------------------------------------------------------
# The strategic briefing
# ---------------------------------------------------------------------------


class TestTheStrategicBriefing:
    def _state(self) -> tuple[CampaignDefinition, CampaignState]:
        campaign = _campaign()
        state = initial_state(campaign)
        state.mission = 1
        state.zones["Senaki"].owner = "neutral"
        state.zones["Gudauta depot"].garrison = [
            {"name": "g", "units": [{"type": "T-72B", "alive": True}, {"type": "T-72B", "alive": False}]}
        ]
        state.sides["red"].reserve = {"armor": 4, "air_defense": 1, "transport": 0}
        state.history = [
            {"mission": 1, "changes": [{"kind": "owner", "zone": "Senaki", "from": "red", "to": "neutral"}]}
        ]
        return campaign, state

    def test_it_says_the_front_the_last_mission_the_enemy_and_the_objectives(self) -> None:
        campaign, state = self._state()
        with language("en"):
            text = strategic_situation(campaign, state)
        assert text.splitlines() == [
            "STRATEGIC SITUATION — mission 2 of 8",
            "",
            "Held by blue: Kobuleti",
            "Held by red: Gudauta depot",
            "Neutral, open to capture: Senaki",
            "",
            "Since mission 1:",
            "- Senaki: red → neutral",
            "",
            "Enemy reserve: 4 armour, 1 air defence, 0 transport.",
            "- Gudauta depot: garrison at 50%",
            "",
            "Campaign objectives:",
            "[ ] capture Senaki",
            "[ ] destroy Gudauta depot",
            "7 mission(s) planned left, this one included.",
        ]

    def test_it_is_written_in_french_too(self) -> None:
        campaign, state = self._state()
        with language("fr"):
            text = strategic_situation(campaign, state)
        assert "SITUATION STRATÉGIQUE — mission 2 sur 8" in text
        assert "- Gudauta depot : garnison à 50 %" in text

    def test_a_garrison_not_drawn_yet_is_an_estimate(self) -> None:
        campaign = _campaign()
        with language("en"):
            text = strategic_situation(campaign, initial_state(campaign))
        assert "- Senaki: garrison strength unknown (estimated from intelligence)" in text
        assert "Since mission" not in text


# ---------------------------------------------------------------------------
# The mission folder
# ---------------------------------------------------------------------------


class TestTheMissionFolder:
    def test_the_first_run_copies_the_template_without_its_build_output(self, tmp_path: Path) -> None:
        _template(tmp_path)
        report = prepare_next_mission(_campaign(), initial_state(_campaign()), tmp_path, tmp_path / "m1")
        assert report.created
        assert report.mission == 1
        assert (tmp_path / "m1" / "src" / "mission" / "mission").is_file()
        assert not (tmp_path / "m1" / "build").exists()

    def test_every_campaign_airbase_goes_to_its_owner_and_a_neutral_one_offers_no_slot(self, tmp_path: Path) -> None:
        _template(tmp_path)
        campaign = _campaign()
        state = initial_state(campaign)
        state.zones["Senaki"].owner = "neutral"
        report = prepare_next_mission(campaign, state, tmp_path, tmp_path / "m1")
        assert report.airbases == ["Kobuleti", "Senaki-Kolkhi"]
        mission = load_folder_mission(tmp_path / "m1")
        assert (_airport(mission, "Kobuleti")["coalition"], _airport(mission, "Kobuleti")["dynamicSpawn"]) == (
            "BLUE",
            True,
        )
        senaki = _airport(mission, "Senaki-Kolkhi")
        assert (senaki["coalition"], senaki["dynamicSpawn"]) == ("NEUTRAL", False)

    def test_the_data_table_and_both_briefings_are_written(self, tmp_path: Path) -> None:
        _template(tmp_path)
        campaign = _campaign()
        prepare_next_mission(campaign, initial_state(campaign), tmp_path, tmp_path / "m1")
        data = yaml.safe_load((tmp_path / "m1" / DATA_FILE).read_text(encoding="utf-8"))
        assert data == mission_data(campaign, initial_state(campaign))
        assert "SITUATION STRATÉGIQUE" in (tmp_path / "m1" / "strategic-situation.fr.txt").read_text(encoding="utf-8")
        assert "STRATEGIC SITUATION" in (tmp_path / "m1" / "strategic-situation.en.txt").read_text(encoding="utf-8")

    def test_the_campaign_module_is_turned_on_and_the_rest_of_mission_yaml_kept(self, tmp_path: Path) -> None:
        _template(tmp_path)
        prepare_next_mission(_campaign(), initial_state(_campaign()), tmp_path, tmp_path / "m1")
        text = (tmp_path / "m1" / "mission.yaml").read_text(encoding="utf-8")
        assert "# the mission maker's comment, kept" in text
        mission_yaml = yaml.safe_load(text)
        assert mission_yaml["modules"]["CAMPAIGN"] == {"enable": True, "data_file": DATA_FILE}
        assert mission_yaml["modules"]["UNITS"] is True
        assert mission_yaml["mission"] == {"name": "Campaign mission", "era": "MODERN"}

    def test_a_second_run_refreshes_and_keeps_what_was_designed(self, tmp_path: Path) -> None:
        _template(tmp_path)
        campaign = _campaign()
        prepare_next_mission(campaign, initial_state(campaign), tmp_path, tmp_path / "m1")
        (tmp_path / "m1" / "src" / "designed.lua").write_text("-- Claude's work", encoding="utf-8")
        state = initial_state(campaign)
        state.zones["Kobuleti"].owner = "red"
        report = prepare_next_mission(campaign, state, tmp_path, tmp_path / "m1")
        assert not report.created
        assert (tmp_path / "m1" / "src" / "designed.lua").is_file()
        assert _airport(load_folder_mission(tmp_path / "m1"), "Kobuleti")["coalition"] == "RED"

    def test_the_strategic_situation_is_the_missions_briefing(self, tmp_path: Path) -> None:
        # a mission built straight after `campaign next` flies with it, not with an empty briefing
        _template(tmp_path)
        campaign = _campaign()
        with language("fr"):
            prepare_next_mission(campaign, initial_state(campaign), tmp_path, tmp_path / "m1")
        assert _briefing(load_folder_mission(tmp_path / "m1")) == (
            tmp_path / "m1" / "strategic-situation.fr.txt"
        ).read_text(encoding="utf-8")

    def test_a_second_run_leaves_the_briefing_as_designed(self, tmp_path: Path) -> None:
        _template(tmp_path)
        campaign = _campaign()
        prepare_next_mission(campaign, initial_state(campaign), tmp_path, tmp_path / "m1")
        set_briefing(tmp_path / "m1", situation="Claude's narrative")
        prepare_next_mission(campaign, initial_state(campaign), tmp_path, tmp_path / "m1")
        assert _briefing(load_folder_mission(tmp_path / "m1")) == "Claude's narrative"

    def test_a_missing_template_is_reported(self, tmp_path: Path) -> None:
        with pytest.raises(FileNotFoundError, match="template"):
            prepare_next_mission(_campaign(), initial_state(_campaign()), tmp_path, tmp_path / "m1")


# ---------------------------------------------------------------------------
# The build: veaf-config.lua carries the table, and the runtime module reads it
# ---------------------------------------------------------------------------


class TestTheBuild:
    def test_the_config_sets_the_data_table_before_initialising_the_module(self) -> None:
        data = mission_data(_campaign(), initial_state(_campaign()))
        lua = generate_config_lua(
            {"lua_modules": {"CAMPAIGN": {"enable": True, "data_file": DATA_FILE}}}, campaign_data=data
        )
        body = lua[lua.index("if veafCampaign then") :]
        assert body.index("veafCampaign.data = {") < body.index("veafCampaign.initialize()")
        assert "data_file" not in lua  # a build-time setting, not a runtime one

    def test_the_builder_reads_the_data_file_the_module_names(self, tmp_path: Path) -> None:
        """The wiring, not only the generator: mission.yaml's `modules:` reaches the builder as `lua_modules`."""
        from mission_builder_factory import make_worker

        (tmp_path / "src").mkdir()
        (tmp_path / DATA_FILE).write_text("campaign: C\nzones: []\n", encoding="utf-8")
        worker = make_worker(mission_folder=tmp_path)
        enabled = {"lua_modules": {"CAMPAIGN": {"enable": True, "data_file": DATA_FILE}}}
        assert worker._campaign_data(enabled) == {"campaign": "C", "zones": []}
        assert worker._campaign_data({"lua_modules": {"CAMPAIGN": {"enable": False, "data_file": DATA_FILE}}}) is None
        assert worker._campaign_data({"lua_modules": {}}) is None

    def test_a_missing_data_file_builds_without_the_campaign(self, tmp_path: Path) -> None:
        from mission_builder_factory import make_worker

        worker = make_worker(mission_folder=tmp_path)
        assert worker._campaign_data({"lua_modules": {"CAMPAIGN": {"enable": True, "data_file": DATA_FILE}}}) is None

    def test_without_data_the_module_is_still_initialised(self) -> None:
        lua = generate_config_lua({"lua_modules": {"CAMPAIGN": {"enable": True}}})
        assert "veafCampaign.initialize()" in lua
        assert "veafCampaign.data =" not in lua

    def test_the_runtime_module_starts_from_the_generated_table(self) -> None:
        """The table goes through the real generator and the real module, under the DCS mocks."""
        campaign = _campaign()
        state = initial_state(campaign)
        state.zones["Senaki"].garrison = [
            {"name": "Senaki garrison", "units": [{"type": "T-72B", "x": 1, "z": 2, "heading": 0, "alive": True}]}
        ]
        lua = generate_config_lua(
            {"lua_modules": {"CAMPAIGN": {"enable": True}}}, campaign_data=mission_data(campaign, state)
        )
        data_line = next(line for line in lua.splitlines() if "veafCampaign.data = " in line)
        src = (REPO / "src" / "scripts" / "veaf").as_posix()
        mocks = (REPO / "test" / "lua").as_posix()
        result = run_lua(
            f"""
dofile("{mocks}/dcs_mocks.lua")
for _, m in ipairs({{"veaf","veafI18n","veafScheduler","veafMath","veafGeo","veafMissionDb","veafDcsSpawner",
  "dcsUnits","veafUnits","veafCasMission","veafEventHandler","veafCampaign"}}) do dofile("{src}/" .. m .. ".lua") end
Airbase.getByName = function(name) return {{ getPoint = function() return {{ x = 100, y = 0, z = 200 }} end }} end
veafCasMission.generateCasGroup = function() return {{}} end
{data_line.strip()}
assert(veafCampaign.initialize())
local senaki = veafCampaign.zones["Senaki"]
print(veafCampaign.data.mission, senaki.entry.x, senaki.entry.z, #veafCampaign.zoneList, veafCampaign.zones["Gudauta depot"].entry.x ~= nil)
"""
        )
        assert result.returncode == 0, result.stderr
        assert result.stdout.split() == ["1", "100", "200", "3", "true"]


# ---------------------------------------------------------------------------
# Worker and command
# ---------------------------------------------------------------------------


class TestTheWorker:
    def _folder(self, tmp_path: Path) -> Path:
        (tmp_path / CAMPAIGN_FILE).write_text(yaml.safe_dump(copy.deepcopy(VALID)), encoding="utf-8")
        _template(tmp_path)
        return tmp_path

    def test_next_builds_mission_one_in_its_sub_folder(self, tmp_path: Path) -> None:
        folder = self._folder(tmp_path)
        worker = CampaignWorker(folder)
        worker.init()
        issues, report = worker.next()
        assert issues == []
        assert report is not None
        assert report.folder == folder / "missions" / "mission-01" / "mission"
        assert (report.folder / DATA_FILE).is_file()

    def test_next_before_init_is_reported(self, tmp_path: Path) -> None:
        folder = self._folder(tmp_path)
        issues, report = CampaignWorker(folder).next()
        assert report is None
        assert [i.message for i in issues] == [t("campaign.issue.not_started", path=folder / STATE_FILE)]

    def test_a_missing_template_is_an_error_not_a_crash(self, tmp_path: Path) -> None:
        (tmp_path / CAMPAIGN_FILE).write_text(yaml.safe_dump(copy.deepcopy(VALID)), encoding="utf-8")
        worker = CampaignWorker(tmp_path)
        worker.init()
        issues, report = worker.next()
        assert report is None
        assert [i.level for i in issues] == [ERROR]

    def test_the_command(self, tmp_path: Path) -> None:
        import veaf_tools.commands  # noqa: F401
        from veaf_tools.app import app

        folder = self._folder(tmp_path)
        CampaignWorker(folder).init()
        result = CliRunner().invoke(app, ["campaign-next", str(folder)])
        assert result.exit_code == 0, result.output
        assert (folder / "missions" / "mission-01" / "mission" / DATA_FILE).is_file()

    def test_next_writes_the_strategic_briefing_deck_next_to_the_mission(self, tmp_path: Path) -> None:
        folder = self._folder(tmp_path)
        worker = CampaignWorker(folder)
        worker.init()
        _, report = worker.next()
        assert report is not None
        assert report.deck == folder / "missions" / "mission-01" / "briefing-campagne.pptx"
        assert report.deck.is_file()

    def test_an_error_in_briefing_yaml_does_not_stop_the_next_mission(self, tmp_path: Path) -> None:
        folder = self._folder(tmp_path)
        (folder / "briefing.yaml").write_text("situation: 12\n", encoding="utf-8")
        worker = CampaignWorker(folder)
        worker.init()
        issues, report = worker.next()
        assert report is not None and report.deck is None
        assert issues and all(issue.level == WARNING for issue in issues)

    def test_a_deck_that_cannot_be_drawn_does_not_stop_the_next_mission(
        self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        from campaign_manager import campaign_worker

        def full_disk(*args: Any, **kwargs: Any) -> None:
            raise OSError("no space left on device")

        monkeypatch.setattr(campaign_worker, "campaign_deck", full_disk)
        folder = self._folder(tmp_path)
        worker = CampaignWorker(folder)
        worker.init()
        issues, report = worker.next()
        assert report is not None and report.deck is None
        assert [issue.message for issue in issues] == [
            t("campaign.issue.deck_failed", error=OSError("no space left on device"))
        ]

    def test_the_briefing_command(self, tmp_path: Path) -> None:
        import veaf_tools.commands  # noqa: F401
        from veaf_tools.app import app

        folder = self._folder(tmp_path)
        CampaignWorker(folder).init()
        result = CliRunner().invoke(app, ["campaign-briefing", str(folder)])
        assert result.exit_code == 0, result.output
        assert (folder / "missions" / "mission-01" / "briefing-campagne.pptx").is_file()
