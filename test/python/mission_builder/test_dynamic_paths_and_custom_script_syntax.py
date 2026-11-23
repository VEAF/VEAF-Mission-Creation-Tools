"""Two build checks from BFR's port (FIX-CONVERT-V5-PARITY tickets 03 and 04).

- `VEAF_DYNAMIC_MISSIONPATH` is the mission folder, not the folder the `.miz` is written to (#1302):
  a dynamic build written to `build/` or a server folder pointed its scripts at the wrong place.
- A `custom_scripts` file that does not parse stops `validate` and the build (#1303): it went into the
  `.miz` unseen and showed up as a script that silently did not load in DCS.
"""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from mission_builder.mission_builder_worker import MissionBuilderWorker
from veaf_libs.mission_validator import ERROR, validate_mission_folder

_BASE_MISSION = 'mission = {\n  ["date"] = { ["Year"] = 2011, ["Month"] = 6, ["Day"] = 1 },\n}\n'


class _MissionFolder(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        root = Path(self._tmp.name)
        self.folder = root / "mission"
        (self.folder / "src" / "mission").mkdir(parents=True)
        (self.folder / "src" / "mission" / "mission").write_text(_BASE_MISSION, encoding="utf-8")
        (self.folder / "src" / "scripts").mkdir(parents=True)
        self.elsewhere = root / "server" / "Missions"
        self.elsewhere.mkdir(parents=True)

    def tearDown(self) -> None:
        self._tmp.cleanup()


class TestDynamicMissionPath(_MissionFolder):
    def test_the_mission_path_is_the_mission_folder_when_the_miz_goes_elsewhere(self) -> None:
        (self.folder / "mission.yaml").write_text("mission:\n  name: Test\n", encoding="utf-8")
        worker = MissionBuilderWorker(
            mission_folder=self.folder, output_mission=self.elsewhere / "out.miz", dynamic_mode=None
        )
        scripts_path, mission_path = worker._veaf_dynamic_paths()
        self.assertEqual(mission_path, f"[[{self.folder.resolve().as_posix()}/]]")
        self.assertEqual(scripts_path, f"[[{(self.folder / 'published').resolve().as_posix()}/]]")


class TestCustomScriptSyntax(_MissionFolder):
    def _yaml(self, script: str) -> None:
        (self.folder / "mission.yaml").write_text(
            f"mission:\n  name: Test\ncustom_scripts:\n  scripts:\n    - path: src/scripts/{script}\n",
            encoding="utf-8",
        )

    def test_validate_names_a_custom_script_that_does_not_parse(self) -> None:
        (self.folder / "src" / "scripts" / "layer.lua").write_text("local x = {\n", encoding="utf-8")
        self._yaml("layer.lua")
        findings = validate_mission_folder(self.folder)
        errors = [f for f in findings if f.level == ERROR and "layer.lua" in f.message]
        self.assertTrue(errors, [f.message for f in findings])

    def test_validate_accepts_a_custom_script_that_parses(self) -> None:
        (self.folder / "src" / "scripts" / "layer.lua").write_text("local x = {}\n", encoding="utf-8")
        self._yaml("layer.lua")
        findings = validate_mission_folder(self.folder)
        self.assertFalse([f for f in findings if f.level == ERROR and "layer.lua" in f.message])

    def test_the_build_stops_on_a_custom_script_that_does_not_parse(self) -> None:
        (self.folder / "src" / "scripts" / "layer.lua").write_text("if true then\n", encoding="utf-8")
        self._yaml("layer.lua")
        worker = MissionBuilderWorker(
            mission_folder=self.folder, output_mission=self.folder / "out.miz", dynamic_mode=None
        )
        with self.assertRaises(RuntimeError) as caught:
            worker.check_custom_scripts_syntax()
        self.assertIn("layer.lua", str(caught.exception))


if __name__ == "__main__":
    unittest.main()
