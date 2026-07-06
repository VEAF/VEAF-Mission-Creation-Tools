"""Tests for custom_scripts parsing in MissionBuilderWorker.__init__ — CUSTOM-001."""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from mission_builder.mission_builder_worker import CustomScript, MissionBuilderWorker


def _make_worker_from_yaml(yaml_dict: dict) -> MissionBuilderWorker:
    """Instantiate a MissionBuilderWorker without __init__, injecting custom_scripts parsing attributes."""
    worker: MissionBuilderWorker = object.__new__(MissionBuilderWorker)
    worker.mission_yaml = yaml_dict
    # Replicate the parsing logic from __init__
    worker.custom_scripts = []
    worker.custom_scripts_generate_load_trigger = True
    cs_section: dict = yaml_dict.get("custom_scripts") or {}
    if cs_section:
        worker.custom_scripts_generate_load_trigger = bool(cs_section.get("generate_load_trigger", True))
        for script_item in cs_section.get("scripts") or []:
            if isinstance(script_item, dict):
                path = script_item.get("path", "")
                per_script_trigger: bool | None = script_item.get("generate_load_trigger")
            else:
                path = str(script_item)
                per_script_trigger = None
            worker.custom_scripts.append(CustomScript(path=Path(path).name, generate_load_trigger=per_script_trigger))
    return worker


class TestCustomScriptsParsing(unittest.TestCase):
    """Unit tests for custom_scripts section parsing from mission.yaml."""

    def test_no_section_yields_empty_list_and_default_trigger_true(self) -> None:
        """Without custom_scripts section, list is empty and global default is True."""
        worker = _make_worker_from_yaml({})
        self.assertEqual(worker.custom_scripts, [])
        self.assertTrue(worker.custom_scripts_generate_load_trigger)

    def test_global_generate_load_trigger_false_is_parsed(self) -> None:
        """Global generate_load_trigger: false is correctly parsed."""
        worker = _make_worker_from_yaml({"custom_scripts": {"generate_load_trigger": False, "scripts": []}})
        self.assertFalse(worker.custom_scripts_generate_load_trigger)

    def test_scripts_paths_are_stored_as_basename(self) -> None:
        """Only the basename of each path is stored."""
        worker = _make_worker_from_yaml(
            {
                "custom_scripts": {
                    "scripts": [
                        {"path": "src/scripts/FgMission.lua"},
                        {"path": "src/scripts/FgTools.lua"},
                    ]
                }
            }
        )
        names = [cs.path for cs in worker.custom_scripts]
        self.assertEqual(names, ["FgMission.lua", "FgTools.lua"])

    def test_per_script_generate_load_trigger_false_is_parsed(self) -> None:
        """Per-script generate_load_trigger: false is stored on the CustomScript."""
        worker = _make_worker_from_yaml(
            {
                "custom_scripts": {
                    "scripts": [
                        {"path": "src/scripts/FgMission.lua"},
                        {"path": "src/scripts/FgTools.lua", "generate_load_trigger": False},
                    ]
                }
            }
        )
        self.assertIsNone(worker.custom_scripts[0].generate_load_trigger)
        self.assertFalse(worker.custom_scripts[1].generate_load_trigger)

    def test_per_script_generate_load_trigger_true_is_parsed(self) -> None:
        """Per-script generate_load_trigger: true is stored on the CustomScript."""
        worker = _make_worker_from_yaml(
            {
                "custom_scripts": {
                    "generate_load_trigger": False,
                    "scripts": [
                        {"path": "src/scripts/Override.lua", "generate_load_trigger": True},
                    ],
                }
            }
        )
        self.assertTrue(worker.custom_scripts[0].generate_load_trigger)

    def test_empty_scripts_list_is_accepted(self) -> None:
        """custom_scripts section with empty scripts list produces no custom scripts."""
        worker = _make_worker_from_yaml({"custom_scripts": {"scripts": []}})
        self.assertEqual(worker.custom_scripts, [])

    def test_null_custom_scripts_section_is_treated_as_absent(self) -> None:
        """custom_scripts: null behaves as if the section were absent."""
        worker = _make_worker_from_yaml({"custom_scripts": None})
        self.assertEqual(worker.custom_scripts, [])
        self.assertTrue(worker.custom_scripts_generate_load_trigger)


class TestCustomScriptsParsingIntegration(unittest.TestCase):
    """Integration tests: parse custom_scripts via the real MissionBuilderWorker.__init__."""

    def _make_real_worker(self, yaml_content: str) -> MissionBuilderWorker:
        with tempfile.TemporaryDirectory() as tmpdir:
            mission_dir = Path(tmpdir)
            output_mission = mission_dir / "out.miz"
            (mission_dir / "mission.yaml").write_text(yaml_content, encoding="utf-8")
            return MissionBuilderWorker(
                mission_folder=mission_dir,
                output_mission=output_mission,
                dynamic_mode=None,
            )

    def test_init_parses_global_trigger_false(self) -> None:
        """__init__ correctly sets custom_scripts_generate_load_trigger to False."""
        worker = self._make_real_worker("custom_scripts:\n  generate_load_trigger: false\n  scripts: []\n")
        self.assertFalse(worker.custom_scripts_generate_load_trigger)

    def test_init_parses_scripts_basenames_and_per_script_override(self) -> None:
        """__init__ stores basenames and per-script generate_load_trigger."""
        worker = self._make_real_worker(
            "custom_scripts:\n"
            "  scripts:\n"
            "    - path: src/scripts/FgMission.lua\n"
            "    - path: src/scripts/FgTools.lua\n"
            "      generate_load_trigger: false\n"
        )
        self.assertEqual(len(worker.custom_scripts), 2)
        self.assertEqual(worker.custom_scripts[0], CustomScript(path="FgMission.lua"))
        self.assertEqual(worker.custom_scripts[1], CustomScript(path="FgTools.lua", generate_load_trigger=False))
        self.assertTrue(worker.custom_scripts_generate_load_trigger)

    def test_init_non_dict_custom_scripts_ignored(self) -> None:
        """__init__ ignores a non-dict custom_scripts value and produces empty list."""
        worker = self._make_real_worker("custom_scripts: not-a-dict\n")
        self.assertEqual(worker.custom_scripts, [])


if __name__ == "__main__":
    unittest.main()
