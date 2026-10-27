"""convert-v5 on a mission that carries a script layer of its own (FEAT-BFR-V6-SUPPORT ticket 10).

Measured on 2026-10-27 with this branch on SeaShepherd part 1 (BFR): 5 modules detected, because only
``missionConfig.lua`` was read while BFR's scripts start nine; no ``custom_scripts:``, because the
ordered ``scriptsToLoad`` list of ``veafDynamicConfig.lua`` (36 scripts) was not read; SKYNET, CTLD and
CSAR came out disabled; and 4 settings were reported as not migrated without saying they are computed
from data rather than written as values.
"""

from __future__ import annotations

from pathlib import Path

import yaml
from mission_builder.config_migrator import ConfigMigrator
from mission_builder.v5_converter import V5Converter
from veaf_libs.i18n import language

_DYNAMIC_CONFIG = """\
local scriptsToLoad =
{
    "layer-core.lua",
    -- 2-missionConfig.lua
    "missionConfig.lua",
    "layer-veaf.lua",
    -- "layer-old.lua",
    "layer-data.lua",
}
if (VEAF_DYNAMIC_MISSIONPATH) then
    for _, script in ipairs(scriptsToLoad) do
        loadfile(VEAF_DYNAMIC_MISSIONPATH .. script)()
    end
end
"""

_LAYER_VEAF = """\
-- the one file that talks to VEAF
function F.initializeCombatZone() return veafCombatZone.initialize() end
function F.initializeSkynet(a, b, c, d)
    return veafSkynet.initialize(a, b, c, d)
end
function F.carriers()
    veafCarrierOperations.initializeCarrierGroups()
end
function F.ctld(callback)
    return ctld.initialize(callback)
end
-- veafShortcuts.initialize() is only mentioned in this comment
if veafRadio then veafRadio.refreshRadioMenu() end
function F.qra(name) return veafQraManager.get(name) end
"""

_MISSION_CONFIG = """\
veaf.config.MISSION_NAME = champ("nom", "string", nil)
veaf.config.MISSION_EXPORT_PATH = "C:/export"
if veafRadio then
    veafRadio.initialize(true)
end
"""


def _mission(tmp_path: Path) -> Path:
    scripts = tmp_path / "src" / "scripts"
    scripts.mkdir(parents=True)
    (scripts / "veafDynamicConfig.lua").write_text(_DYNAMIC_CONFIG, encoding="utf-8")
    (scripts / "missionConfig.lua").write_text(_MISSION_CONFIG, encoding="utf-8")
    (scripts / "layer-core.lua").write_text("Layer = {}\n", encoding="utf-8")
    (scripts / "layer-veaf.lua").write_text(_LAYER_VEAF, encoding="utf-8")
    (scripts / "layer-data.lua").write_text("Data = { csarLives = csar.maxLives }\n", encoding="utf-8")
    return tmp_path


def _convert(tmp_path: Path) -> tuple[dict, object]:
    folder = _mission(tmp_path)
    with language("en"):
        report = V5Converter().convert(folder, convert_pipeline=False)
    return yaml.safe_load((folder / "mission.yaml").read_text(encoding="utf-8")), report


class TestScriptsToLoad:
    def test_the_ordered_list_becomes_custom_scripts(self, tmp_path: Path) -> None:
        data, _ = _convert(tmp_path)
        paths = [entry["path"] for entry in data["custom_scripts"]["scripts"]]
        # missionConfig.lua is migrated, not loaded; a commented entry is not loaded either
        assert paths == ["src/scripts/layer-core.lua", "src/scripts/layer-veaf.lua", "src/scripts/layer-data.lua"]

    def test_a_listed_script_that_is_missing_is_left_out_and_reported(self, tmp_path: Path) -> None:
        folder = _mission(tmp_path)
        (folder / "src" / "scripts" / "layer-data.lua").unlink()
        with language("en"):
            report = V5Converter().convert(folder, convert_pipeline=False)
        data = yaml.safe_load((folder / "mission.yaml").read_text(encoding="utf-8"))
        assert "src/scripts/layer-data.lua" not in [e["path"] for e in data["custom_scripts"]["scripts"]]
        assert any("layer-data.lua" in w for w in report.warnings)

    def test_a_standard_v5_mission_gets_no_custom_scripts(self, tmp_path: Path) -> None:
        folder = _mission(tmp_path)
        (folder / "src" / "scripts" / "veafDynamicConfig.lua").write_text(
            'local scriptsToLoad = { "missionConfig.lua" }\n', encoding="utf-8"
        )
        for name in ("layer-core.lua", "layer-veaf.lua", "layer-data.lua"):
            (folder / "src" / "scripts" / name).unlink()
        with language("en"):
            V5Converter().convert(folder, convert_pipeline=False)
        data = yaml.safe_load((folder / "mission.yaml").read_text(encoding="utf-8"))
        assert "custom_scripts" not in data


class TestModulesStartedByTheMissionScripts:
    def test_a_module_a_script_initializes_is_handed_to_the_mission(self, tmp_path: Path) -> None:
        data, _ = _convert(tmp_path)
        assert data["modules"]["COMBATZONE"]["initialized_by_mission"] is True
        assert data["modules"]["COMBATZONE"]["enabled"] is True

    def test_copying_the_carrier_initialization_counts_too(self, tmp_path: Path) -> None:
        data, _ = _convert(tmp_path)
        assert data["modules"]["CARRIER"]["initialized_by_mission"] is True

    def test_skynet_is_enabled_and_handed_to_the_mission(self, tmp_path: Path) -> None:
        data, _ = _convert(tmp_path)
        assert data["modules"]["SKYNET"]["enabled"] is True
        assert data["modules"]["SKYNET"]["initialized_by_mission"] is True

    def test_ctld_v1_started_by_the_layer_is_enabled_but_left_to_veaf(self, tmp_path: Path) -> None:
        # `ctld.initialize(callback)` is CTLD v1's; CTLD 2 is started by `veaf.ctld_initialize()`, which also
        # builds its menu and the airbase logistics: handing it to the mission would leave CTLD 2 unstarted.
        data, _ = _convert(tmp_path)
        assert data["modules"]["CTLD"] is True

    def test_a_community_script_the_layer_only_reads_is_enabled(self, tmp_path: Path) -> None:
        data, _ = _convert(tmp_path)
        assert data["modules"]["CSAR"] is True

    def test_a_module_the_layer_only_calls_into_is_enabled_and_left_to_the_build(self, tmp_path: Path) -> None:
        data, _ = _convert(tmp_path)
        assert data["modules"]["QRA"] is True

    def test_a_module_missionconfig_initializes_stays_with_the_build(self, tmp_path: Path) -> None:
        data, _ = _convert(tmp_path)
        assert data["modules"]["RADIO"] is True

    def test_a_comment_or_a_presence_check_is_not_an_initialization(self, tmp_path: Path) -> None:
        data, _ = _convert(tmp_path)
        assert "SHORTCUTS" not in data["modules"]

    def test_the_report_names_the_modules_handed_to_the_mission(self, tmp_path: Path) -> None:
        _, report = _convert(tmp_path)
        assert any("COMBATZONE" in action and "initialized_by_mission" in action for action in report.actions)


class TestSettingsComputedFromData:
    def test_a_setting_computed_by_the_script_is_reported_as_such(self) -> None:
        result = ConfigMigrator().migrate(_MISSION_CONFIG)
        assert result.not_migrated_computed == ['veaf.config.MISSION_NAME = champ("nom", "string", nil)']

    def test_the_report_says_why_it_was_not_carried(self, tmp_path: Path) -> None:
        _, report = _convert(tmp_path)
        assert any("computed" in w and "MISSION_NAME" in w for w in report.warnings)
