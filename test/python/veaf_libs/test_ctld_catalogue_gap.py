"""A mission's ctld-config.yaml against the vendored CTLD catalogue (FIX-OPEN-TRAINING-CAUCASUS-FINDINGS ticket 02)."""

from __future__ import annotations

import difflib
import io
from pathlib import Path

import pytest
import yaml
from ruamel.yaml import YAML
from veaf_libs.ctld_config import (
    apply_veaf_overrides,
    find_catalogue_gap,
    read_default_config,
    upgrade_to_catalogue,
)

_CATALOGUE = """configVersion: "2.2.0"
mm_facing:
  alpha: 1
  newScalar: true
  capabilitiesByType:
    UH-1H:
      cratesEnabled: true
      crateSpawnSector: side
    Mi-8MT:
      cratesEnabled: true
  pickupZones:
  - one
  newList:
  - x
advanced:
  beta: 2
  newTable:
    a: 1
  newAdvanced: 0.5
"""

_MISSION = """configVersion: "2.0.0"
mm_facing:
  alpha: 7
  capabilitiesByType:
    UH-1H:
      cratesEnabled: false
  pickupZones:
  - mine
  oldSetting: 3
advanced:
  beta: 9
"""


class TestFindCatalogueGap:
    def test_same_version_is_quiet(self) -> None:
        assert find_catalogue_gap(_CATALOGUE, _CATALOGUE) is None

    def test_a_missing_setting_is_listed_with_its_section(self) -> None:
        gap = find_catalogue_gap(_MISSION, _CATALOGUE)

        assert gap is not None
        assert gap.mission_version == "2.0.0"
        assert gap.catalogue_version == "2.2.0"
        assert gap.missing == (("mm_facing", "newScalar"), ("advanced", "newTable"), ("advanced", "newAdvanced"))

    def test_a_missing_list_is_not_listed(self) -> None:
        gap = find_catalogue_gap(_MISSION, _CATALOGUE)

        assert gap is not None
        assert all(key != "newList" for _, key in gap.missing)

    def test_a_setting_the_catalogue_dropped_is_listed_apart(self) -> None:
        gap = find_catalogue_gap(_MISSION, _CATALOGUE)

        assert gap is not None
        assert gap.removed == ("oldSetting",)

    def test_a_key_inside_an_entry_the_mission_has_is_a_feature_it_does_not_use(self) -> None:
        gap = find_catalogue_gap(_MISSION, _CATALOGUE)

        assert gap is not None
        assert gap.unused_features == ("capabilitiesByType.UH-1H.crateSpawnSector", "capabilitiesByType.Mi-8MT")

    def test_a_mission_without_a_version_differs(self) -> None:
        gap = find_catalogue_gap("mm_facing:\n  alpha: 1\n", _CATALOGUE)

        assert gap is not None
        assert gap.mission_version is None

    def test_an_unreadable_document_gives_no_gap(self) -> None:
        assert find_catalogue_gap("mm_facing: [unclosed", _CATALOGUE) is None
        assert find_catalogue_gap("- a list\n", _CATALOGUE) is None


class TestUpgradeToCatalogue:
    def test_missing_settings_are_added_at_the_catalogue_default_in_its_section(self) -> None:
        upgraded = yaml.safe_load(upgrade_to_catalogue(_MISSION, _CATALOGUE))

        assert upgraded["mm_facing"]["newScalar"] is True
        assert upgraded["advanced"]["newTable"] == {"a": 1}
        assert upgraded["advanced"]["newAdvanced"] == 0.5

    def test_the_version_is_bumped(self) -> None:
        assert yaml.safe_load(upgrade_to_catalogue(_MISSION, _CATALOGUE))["configVersion"] == "2.2.0"

    def test_no_existing_value_changes(self) -> None:
        before = yaml.safe_load(_MISSION)
        after = yaml.safe_load(upgrade_to_catalogue(_MISSION, _CATALOGUE))

        for section in ("mm_facing", "advanced"):
            for key, value in before[section].items():
                assert after[section][key] == value

    def test_lists_and_entries_are_not_touched(self) -> None:
        after = yaml.safe_load(upgrade_to_catalogue(_MISSION, _CATALOGUE))

        assert "newList" not in after["mm_facing"]
        assert after["mm_facing"]["capabilitiesByType"] == {"UH-1H": {"cratesEnabled": False}}

    def test_after_the_upgrade_the_gap_is_gone(self) -> None:
        assert find_catalogue_gap(upgrade_to_catalogue(_MISSION, _CATALOGUE), _CATALOGUE) is None

    def test_a_missing_section_is_created(self) -> None:
        after = yaml.safe_load(upgrade_to_catalogue('configVersion: "2.0.0"\nmm_facing:\n  alpha: 1\n', _CATALOGUE))

        assert after["advanced"] == {"beta": 2, "newTable": {"a": 1}, "newAdvanced": 0.5}


def _vendored_catalogue() -> str:
    vendored = Path(__file__).resolve().parents[3] / "src" / "scripts" / "community" / "CTLD.lua"
    catalogue = read_default_config(vendored)
    if catalogue is None:
        pytest.skip("vendored CTLD.lua not present")
    return catalogue


def _as_2_0_0(catalogue: str) -> str:
    """The vendored catalogue as a mission scaffolded against 2.0.0 holds it: the 2.2.0 additions removed."""
    ruamel = YAML()
    ruamel.preserve_quotes = True
    document = ruamel.load(apply_veaf_overrides(catalogue))
    document["configVersion"] = "2.0.0"
    del document["mm_facing"]["enableParachuteDrop"]
    del document["advanced"]["crateDropExtraDistance"]
    del document["advanced"]["crateSpawnGap"]
    stream = io.StringIO()
    ruamel.dump(document, stream)
    return stream.getvalue()


class TestAgainstTheVendoredCatalogue:
    def test_a_2_0_0_snapshot_lacks_the_three_settings_ctld_reported(self) -> None:
        catalogue = _vendored_catalogue()

        gap = find_catalogue_gap(_as_2_0_0(catalogue), catalogue)

        assert gap is not None
        assert gap.missing == (
            ("mm_facing", "enableParachuteDrop"),
            ("advanced", "crateDropExtraDistance"),
            ("advanced", "crateSpawnGap"),
        )
        assert gap.removed == ()

    def test_the_upgrade_only_adds_lines(self) -> None:
        catalogue = _vendored_catalogue()
        mission = _as_2_0_0(catalogue)

        upgraded = upgrade_to_catalogue(mission, catalogue)

        changed = [
            line
            for line in difflib.unified_diff(mission.splitlines(), upgraded.splitlines(), lineterm="", n=0)
            if line[:1] in "+-" and not line.startswith(("+++", "---"))
        ]
        assert sorted(changed) == sorted(
            [
                '-configVersion: "2.0.0"',
                '+configVersion: "2.2.0"',
                "+  enableParachuteDrop: true",
                "+  crateDropExtraDistance: 2",
                "+  crateSpawnGap: 0.5",
            ]
        )
        assert find_catalogue_gap(upgraded, catalogue) is None


def _mission_folder(tmp_path: Path, config: str | None) -> Path:
    (tmp_path / "mission.yaml").write_text("modules:\n  RADIO: true\n", encoding="utf-8")
    if config is not None:
        (tmp_path / "ctld-config.yaml").write_bytes(config.encode("utf-8"))
    return tmp_path


class TestValidateReportsTheGap:
    def test_a_2_0_0_file_gives_a_warning_naming_the_three_settings(self, tmp_path: Path) -> None:
        from veaf_libs.mission_validator import WARNING, validate_mission_folder

        folder = _mission_folder(tmp_path, _as_2_0_0(_vendored_catalogue()))

        gap_issues = [i for i in validate_mission_folder(folder) if "ctld-upgrade" in i.message]

        assert len(gap_issues) == 1
        assert gap_issues[0].level == WARNING
        for key in ("enableParachuteDrop", "crateDropExtraDistance", "crateSpawnGap"):
            assert key in gap_issues[0].message

    def test_an_up_to_date_file_gives_nothing(self, tmp_path: Path) -> None:
        from veaf_libs.mission_validator import validate_mission_folder

        folder = _mission_folder(tmp_path, apply_veaf_overrides(_vendored_catalogue()))

        assert not [i for i in validate_mission_folder(folder) if "CTLD" in i.message]

    def test_a_mission_that_turns_ctld_off_is_not_checked(self, tmp_path: Path) -> None:
        from veaf_libs.mission_validator import validate_mission_folder

        folder = _mission_folder(tmp_path, _as_2_0_0(_vendored_catalogue()))
        (folder / "mission.yaml").write_text("modules:\n  CTLD: false\n", encoding="utf-8")

        assert not [i for i in validate_mission_folder(folder) if "ctld-upgrade" in i.message]


class TestCtldUpgradeCommand:
    def _run(self, folder: Path) -> str:
        from typer.testing import CliRunner
        from veaf_tools import app as app_mod
        from veaf_tools.commands import ctld_upgrade  # noqa: F401  (registers the command)

        result = CliRunner().invoke(app_mod.app, ["ctld-upgrade", str(folder)])
        assert result.exit_code == 0, result.output
        return result.output

    def test_the_command_upgrades_the_file_and_validate_is_then_quiet(self, tmp_path: Path) -> None:
        from veaf_libs.mission_validator import validate_mission_folder

        folder = _mission_folder(tmp_path, _as_2_0_0(_vendored_catalogue()).replace("\n", "\r\n"))

        output = self._run(folder)

        assert "crateSpawnGap" in output
        raw = (folder / "ctld-config.yaml").read_bytes()
        assert b"\r\n" in raw and b"\n" not in raw.replace(b"\r\n", b"")
        assert not [i for i in validate_mission_folder(folder) if "CTLD" in i.message]

    def test_an_up_to_date_file_is_left_alone(self, tmp_path: Path) -> None:
        config = apply_veaf_overrides(_vendored_catalogue())
        folder = _mission_folder(tmp_path, config)

        self._run(folder)

        assert (folder / "ctld-config.yaml").read_bytes() == config.encode("utf-8")

    def test_no_configuration_fails(self, tmp_path: Path) -> None:
        from typer.testing import CliRunner
        from veaf_tools import app as app_mod
        from veaf_tools.commands import ctld_upgrade  # noqa: F401

        result = CliRunner().invoke(app_mod.app, ["ctld-upgrade", str(_mission_folder(tmp_path, None))])

        assert result.exit_code == 1

    def test_an_unreadable_configuration_fails_and_is_left_alone(self, tmp_path: Path) -> None:
        from typer.testing import CliRunner
        from veaf_tools import app as app_mod
        from veaf_tools.commands import ctld_upgrade  # noqa: F401

        folder = _mission_folder(tmp_path, "mm_facing: [unclosed\n")

        result = CliRunner().invoke(app_mod.app, ["ctld-upgrade", str(folder)])

        assert result.exit_code == 1
        assert (folder / "ctld-config.yaml").read_bytes() == b"mm_facing: [unclosed\n"


def test_a_catalogue_without_a_version_leaves_the_mission_version_alone() -> None:
    upgraded = yaml.safe_load(upgrade_to_catalogue(_MISSION, _CATALOGUE.replace('configVersion: "2.2.0"\n', "")))

    assert upgraded["configVersion"] == "2.0.0"
    assert upgraded["mm_facing"]["newScalar"] is True


def test_a_file_indented_its_own_way_only_gains_lines() -> None:
    """Review finding: an editor-indented file (`  - item` under its key) was re-indented whole."""
    long = "x" * 120
    mission = (
        'configVersion: "2.0.0"\n'
        "mm_facing:\n"
        "    alpha: 7\n"
        f"    note: {long}\n"
        "    pickupZones:\n"
        "      - mine\n"
        "      - other\n"
        "advanced:\n"
        "    beta: 9\n"
    )

    upgraded = upgrade_to_catalogue(mission, _CATALOGUE)

    removed = [line for line in difflib.ndiff(mission.splitlines(), upgraded.splitlines()) if line.startswith("- ")]
    assert removed == ['- configVersion: "2.0.0"']
    assert "    newScalar: true" in upgraded.splitlines()
