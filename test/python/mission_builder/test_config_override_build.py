"""config_override rendering, validation and ordering in the build (FOOTHOLD-V6-004)."""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from mission_builder.mission_builder_worker import MissionBuilderWorker
from veaf_libs.config_override import OVERRIDE_SCRIPT_NAME


def _bare_worker(target: str | None, values: dict) -> MissionBuilderWorker:
    """A worker shell carrying only the config_override attributes (no __init__)."""
    worker: MissionBuilderWorker = object.__new__(MissionBuilderWorker)
    worker._dcs_bridge_temp_file = None
    worker.config_override_target = target
    worker.config_override_values = values
    return worker


class TestRenderConfigOverride(unittest.TestCase):
    def _folder_with_config(self, body: str) -> Path:
        folder = Path(tempfile.mkdtemp())
        scripts = folder / "src" / "scripts"
        scripts.mkdir(parents=True)
        (scripts / "Foothold Config.lua").write_text(body, encoding="utf-8")
        return folder

    def test_writes_override_file_with_assignments(self) -> None:
        folder = self._folder_with_config("CapDifficulty = easy\n")
        worker = _bare_worker("Foothold Config.lua", {"CapDifficulty": "medium"})
        worker.mission_folder = folder
        worker.render_config_override()
        out = (folder / "src" / "scripts" / OVERRIDE_SCRIPT_NAME).read_text(encoding="utf-8")
        self.assertIn('CapDifficulty = "medium"', out)

    def test_unknown_segment_aborts_build_without_writing(self) -> None:
        folder = self._folder_with_config("CapDifficulty = easy\n")
        worker = _bare_worker("Foothold Config.lua", {"GhostSetting": 1})
        worker.mission_folder = folder
        with self.assertRaises(RuntimeError):
            worker.render_config_override()
        self.assertFalse((folder / "src" / "scripts" / OVERRIDE_SCRIPT_NAME).exists())

    def test_no_values_is_a_noop(self) -> None:
        folder = self._folder_with_config("CapDifficulty = easy\n")
        worker = _bare_worker(None, {})
        worker.mission_folder = folder
        worker.render_config_override()
        self.assertFalse((folder / "src" / "scripts" / OVERRIDE_SCRIPT_NAME).exists())


class TestPositionConfigOverride(unittest.TestCase):
    def test_override_is_moved_right_after_target(self) -> None:
        worker = _bare_worker("Foothold Config.lua", {"CapDifficulty": "x"})
        files = [
            "l10n/DEFAULT/Moose.lua",
            "l10n/DEFAULT/Foothold Config.lua",
            "l10n/DEFAULT/Foothold setup.lua",
            f"l10n/DEFAULT/{OVERRIDE_SCRIPT_NAME}",
        ]
        names = [Path(f).name for f in worker._position_config_override(files)]
        self.assertEqual(
            names,
            ["Moose.lua", "Foothold Config.lua", OVERRIDE_SCRIPT_NAME, "Foothold setup.lua"],
        )

    def test_noop_without_override_values(self) -> None:
        worker = _bare_worker(None, {})
        files = ["a.lua", "b.lua"]
        self.assertEqual(worker._position_config_override(files), files)


class TestConfigOverrideParsing(unittest.TestCase):
    def _real_worker(self, yaml_content: str) -> MissionBuilderWorker:
        mission_dir = Path(tempfile.mkdtemp())
        (mission_dir / "mission.yaml").write_text(yaml_content, encoding="utf-8")
        return MissionBuilderWorker(
            mission_folder=mission_dir,
            output_mission=mission_dir / "out.miz",
            dynamic_mode=None,
        )

    def test_init_parses_target_basename_and_values(self) -> None:
        worker = self._real_worker(
            'config_override:\n  target: "Foothold Config.lua"\n  values:\n    CapDifficulty: medium\n'
        )
        self.assertEqual(worker.config_override_target, "Foothold Config.lua")
        self.assertEqual(worker.config_override_values, {"CapDifficulty": "medium"})

    def test_init_without_section_yields_empty(self) -> None:
        worker = self._real_worker("modules:\n  RADIO: true\n")
        self.assertIsNone(worker.config_override_target)
        self.assertEqual(worker.config_override_values, {})


if __name__ == "__main__":
    unittest.main()
