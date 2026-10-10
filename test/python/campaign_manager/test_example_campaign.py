"""The shipped example campaign starts, and its first mission is laid down and starts in Lua (ticket 10)."""

from __future__ import annotations

import shutil
from pathlib import Path

import yaml
from campaign_manager.briefing_prose import PROSE_FILE
from campaign_manager.campaign_manager import load_campaign
from campaign_manager.campaign_worker import CAMPAIGN_FILE, CampaignWorker
from campaign_manager.next_mission import DATA_FILE
from lua_runner import run_lua
from veaf_libs.blank_mission import generate_blank_mission
from veaf_libs.i18n import t
from veaf_libs.lua_config_generator import generate_config_lua

REPO = Path(__file__).resolve().parents[3]
EXAMPLE = REPO / "src" / "defaults" / "campaign-folder"


def _folder(tmp_path: Path) -> Path:
    shutil.copy(EXAMPLE / CAMPAIGN_FILE, tmp_path / CAMPAIGN_FILE)
    template = tmp_path / "template"
    for relative, content in generate_blank_mission("Caucasus").items():
        path = template / "src" / "mission" / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(content)
    (template / "mission.yaml").write_text("mission:\n  name: Western Georgia\n", encoding="utf-8")
    return tmp_path


def test_its_briefing_deck_generates_from_a_fresh_copy(tmp_path: Path) -> None:
    folder = _folder(tmp_path)
    shutil.copy(EXAMPLE / PROSE_FILE, folder / PROSE_FILE)
    worker = CampaignWorker(folder)
    worker.init()
    assert worker.validate() == []
    issues, report = worker.briefing()
    # the one warning: no mission built yet, so no mission briefing, and how to get one
    assert [issue.message for issue in issues] == [
        t("campaign.issue.no_built_mission", folder=worker.mission_folder(1) / "mission")
    ]
    assert report is not None and report.prose
    assert report.path == folder / "missions" / "mission-01" / "briefing-campagne.pptx"


def test_the_example_is_valid_without_a_single_warning() -> None:
    campaign, issues = load_campaign(EXAMPLE / CAMPAIGN_FILE)
    assert issues == []
    assert campaign is not None
    assert (len(campaign.zones), campaign.missions) == (12, 10)


def test_its_first_mission_is_laid_down_and_starts(tmp_path: Path) -> None:
    folder = _folder(tmp_path)
    worker = CampaignWorker(folder)
    assert worker.init() == []
    issues, report = worker.next()
    assert issues == []
    assert report is not None
    assert len(report.airbases) == 7
    data = yaml.safe_load((report.folder / DATA_FILE).read_text(encoding="utf-8"))
    lua = generate_config_lua({"lua_modules": {"CAMPAIGN": {"enable": True}}}, campaign_data=data)
    data_line = next(line for line in lua.splitlines() if "veafCampaign.data = " in line)
    src = (REPO / "src" / "scripts" / "veaf").as_posix()
    mocks = (REPO / "test" / "lua").as_posix()
    result = run_lua(
        f"""
dofile("{mocks}/dcs_mocks.lua")
for _, m in ipairs({{"veaf","veafI18n","veafScheduler","veafMath","veafGeo","veafMissionDb","veafDcsSpawner",
  "dcsUnits","veafUnits","veafCasMission","veafEventHandler","veafCampaign"}}) do dofile("{src}/" .. m .. ".lua") end
Airbase.getByName = function(name) return {{ getPoint = function() return {{ x = 1, y = 0, z = 2 }} end }} end
{data_line.strip()}
assert(veafCampaign.initialize())
local drawn = 0
for _, zone in ipairs(veafCampaign.zoneList) do
  if zone.entry.garrison then drawn = drawn + 1 end
end
print(#veafCampaign.zoneList, drawn, #dcs_mocks.groupsAdded > 0)
"""
    )
    assert result.returncode == 0, result.stderr
    # every zone but neutral Poti draws its starting garrison with the real CAS generators
    assert result.stdout.split() == ["12", "11", "true"]
