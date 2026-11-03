"""The training versions wired into the build: the plan, the profile, the worker (FEAT-ROLE-TRAINING-VARIANTS).

The rules themselves are tested in ``test_training_variants.py``; here, that the build asks for them at
the right moments — the version planned **before** the configuration Lua is written, its table edits
replayed **after** the mission is read back — and that the night's build goes through untouched.
"""

from __future__ import annotations

import copy
from pathlib import Path

import luadata
import pytest
from mission_builder.group_removal import group_names
from mission_builder.mission_builder_worker import _normalize_mission_yaml
from mission_builder.training_variants import VARIANT_KEY
from mission_builder_factory import make_worker
from mission_tools.miz_tools import DcsMission
from test_training_variants import _mission, _yaml
from veaf_libs.build_profiles import resolve_profile


def _folder(tmp_path: Path) -> Path:
    mission_dir = tmp_path / "src" / "mission"
    mission_dir.mkdir(parents=True)
    (mission_dir / "mission").write_text("mission = " + luadata.serialize(_mission()), encoding="utf-8")
    return tmp_path


class TestBuildPlan:
    def _plan(self, yaml_data: dict, profile: str | None = None) -> list:
        from veaf_tools.commands.build import _build_plan

        return _build_plan(yaml_data, profile, Path("/m/Night_20261103.miz"), "Night")

    def test_the_night_first_then_one_version_per_role(self) -> None:
        assert self._plan(_yaml()) == [
            (None, Path("/m/Night_20261103.miz"), "Night"),
            ("TRAINING_A2G", Path("/m/Night_20261103_TRAINING_A2G.miz"), "Night_TRAINING_A2G"),
            ("TRAINING_CAP", Path("/m/Night_20261103_TRAINING_CAP.miz"), "Night_TRAINING_CAP"),
            ("TRAINING_SEAD", Path("/m/Night_20261103_TRAINING_SEAD.miz"), "Night_TRAINING_SEAD"),
            ("TRAINING_ALL", Path("/m/Night_20261103_TRAINING_ALL.miz"), "Night_TRAINING_ALL"),
        ]

    def test_an_explicit_training_profile_is_one_build(self) -> None:
        assert self._plan(_yaml(), "training_sead") == [
            ("training_sead", Path("/m/Night_20261103_TRAINING_SEAD.miz"), "Night_TRAINING_SEAD")
        ]

    def test_beside_build_variants_it_is_refused(self) -> None:
        with pytest.raises(ValueError, match="build_variants"):
            self._plan(_yaml(build_variants=["MODERN"]))


def test_a_derived_profile_resolves_to_its_role() -> None:
    from mission_builder.training_variants import with_training_profiles

    resolved = resolve_profile(with_training_profiles(_yaml()), "TRAINING_SEAD")
    assert resolved[VARIANT_KEY] == "SEAD"
    assert VARIANT_KEY not in resolve_profile(with_training_profiles(_yaml()), None)


class TestWorker:
    def _worker(self, tmp_path: Path, role: str | None):
        # As __init__ leaves it: profile resolved, then normalised into the keys the generator reads.
        yaml_data = resolve_profile(_yaml(), None)
        if role:
            yaml_data[VARIANT_KEY] = role
        return make_worker(mission_folder=_folder(tmp_path), mission_yaml=_normalize_mission_yaml(yaml_data))

    def test_the_night_build_plans_nothing(self, tmp_path: Path) -> None:
        worker = self._worker(tmp_path, None)
        before = copy.deepcopy(worker.mission_yaml)
        worker.prepare_training_variant()
        assert worker.training_variant is None and worker.mission_yaml == before

    def test_a_version_takes_its_configuration_before_the_lua_is_written(self, tmp_path: Path) -> None:
        worker = self._worker(tmp_path, "A2G")
        worker.prepare_training_variant()
        assert worker.training_variant is not None
        # What the generator reads: the keys derived from `modules:`, not `modules:` itself. Asserting on
        # `modules:` passed while the built .miz had neither the zone nor the QRA change (2026-11-03).
        assert worker.mission_yaml["qra"]["definitions"] == []
        assert worker.mission_yaml["lua_modules"]["COMBATZONE"]["combat_zones"][-1]["zone_name"] == "TRAINING-column"

    def test_the_table_edits_land_on_the_mission_read_back(self, tmp_path: Path) -> None:
        worker = self._worker(tmp_path, "A2G")
        worker.prepare_training_variant()
        worker.dcs_mission = DcsMission(file_path=tmp_path / "out.miz", mission_content=_mission())
        worker.apply_group_edits()
        names = group_names(worker.dcs_mission.mission_content)
        assert "Red CAP Maykop" not in names and "SA-10 Gudauta" not in names
        assert "TRAINING-column-Column 1" in names and "Factory-Tanks" in names

    def test_a_block_that_does_not_fit_stops_the_build(self, tmp_path: Path) -> None:
        worker = self._worker(tmp_path, "ALL")
        worker.mission_yaml["training"]["elements"] = [{"qra": "Nope", "kind": "qra"}]
        with pytest.raises(ValueError, match="no QRA named 'Nope'"):
            worker.prepare_training_variant()

    def test_a_profile_remove_groups_applies_to_any_build(self, tmp_path: Path) -> None:
        worker = make_worker(mission_folder=tmp_path, mission_yaml={"remove_groups": ["Blue HQ", "Ghost*"]})
        worker.dcs_mission = DcsMission(file_path=tmp_path / "out.miz", mission_content=_mission())
        worker.apply_group_edits()
        assert "Blue HQ" not in group_names(worker.dcs_mission.mission_content)

    def test_without_remove_groups_the_table_is_untouched(self, tmp_path: Path) -> None:
        worker = make_worker(mission_folder=tmp_path, mission_yaml={"modules": {}})
        worker.dcs_mission = DcsMission(file_path=tmp_path / "out.miz", mission_content=_mission())
        worker.apply_group_edits()
        assert worker.dcs_mission.mission_content == _mission()


def test_the_validator_reports_the_block(tmp_path: Path) -> None:
    import yaml
    from veaf_libs.mission_validator import ERROR, validate_mission_folder

    folder = _folder(tmp_path)
    data = _yaml()
    data["training"]["randomize"][0]["pool"].append({"command": "-nothing-like-it"})
    (folder / "mission.yaml").write_text(yaml.safe_dump(data), encoding="utf-8")
    messages = [issue.message for issue in validate_mission_folder(folder) if issue.level == ERROR]
    assert any("not a VEAF shortcut" in message for message in messages)
