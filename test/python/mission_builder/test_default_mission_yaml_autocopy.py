"""The default mission.yaml is copied BEFORE config resolution (FIX-BUILD-COPY-DEFAULTS).

Regression: when the user has no mission.yaml, the build copied the default only
later (in complete_src_folder_with_defaults), after the config had already been
resolved from an absent file → no veaf-config.lua and wrong module toggles.
"""

from __future__ import annotations

from pathlib import Path

from mission_builder.mission_builder_worker import MissionBuilderWorker


def _make_mission_folder(tmp_path: Path, default_yaml: str) -> Path:
    mission_folder = tmp_path / "mission"
    defaults = mission_folder / "published" / "src" / "defaults" / "mission-folder"
    defaults.mkdir(parents=True)
    (defaults / "mission.yaml").write_text(default_yaml, encoding="utf-8")
    return mission_folder


class TestDefaultMissionYamlAutocopy:
    def test_absent_mission_yaml_is_copied_and_resolved(self, tmp_path: Path) -> None:
        mission_folder = _make_mission_folder(
            tmp_path,
            "modules:\n  UNITS:\n  RADIO: true\n  MIST:\n  SKYNET: false\n",
        )
        worker = MissionBuilderWorker(
            mission_folder=mission_folder,
            output_mission=mission_folder / "out.miz",
            dynamic_mode=None,
        )
        # The default was copied into the mission folder...
        assert (mission_folder / "mission.yaml").exists()
        # ...and the config was resolved from it (not from an empty file).
        assert "modules" in worker.mission_yaml
        assert worker.mission_yaml["modules"].get("RADIO") is True
        # MiST mandatory stays enabled, SKYNET disabled — community resolved from the copied default.
        assert worker.enabled_community_script_ids is not None
        assert "mist" in worker.enabled_community_script_ids
        assert "skynet" not in worker.enabled_community_script_ids

    def test_existing_mission_yaml_is_not_overwritten(self, tmp_path: Path) -> None:
        mission_folder = _make_mission_folder(tmp_path, "modules:\n  RADIO: true\n")
        (mission_folder / "mission.yaml").write_text("modules:\n  RADIO: false\n", encoding="utf-8")
        worker = MissionBuilderWorker(
            mission_folder=mission_folder,
            output_mission=mission_folder / "out.miz",
            dynamic_mode=None,
        )
        # The user's own file wins; the default is not copied over it.
        assert worker.mission_yaml["modules"].get("RADIO") is False
