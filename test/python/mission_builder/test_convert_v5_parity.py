"""A converted v5 mission behaves as it did in v5, or says what changed (FIX-CONVERT-V5-PARITY ticket 01, #1300).

Each test converts a small v5 folder and reads the generated ``mission.yaml`` back as YAML, so a key
written under the wrong parent or a comment taken for a value fails here, not in the build.
"""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

import yaml
from mission_builder.v5_converter import V5Converter
from veaf_libs.i18n import language


def _make_folder(folder: Path, mission_config: str) -> None:
    scripts = folder / "src" / "scripts"
    scripts.mkdir(parents=True)
    (scripts / "missionConfig.lua").write_text(mission_config, encoding="utf-8")


def _community(folder: Path, *names: str) -> None:
    comm = folder / "published" / "src" / "scripts" / "community"
    comm.mkdir(parents=True)
    for name in names:
        (comm / name).write_text("-- stub\n", encoding="utf-8")


def _convert(folder: Path) -> tuple[dict, str, object]:
    report = V5Converter().convert(folder, backup=False)
    text = (folder / "mission.yaml").read_text(encoding="utf-8")
    return yaml.safe_load(text), text, report


class TestSilenceAll(unittest.TestCase):
    def test_silence_all_is_kept_without_a_yaml_qra(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            folder = Path(td)
            _make_folder(folder, "if VeafQRA then\n  VeafQRA.ToggleAllSilence(true)\nend\n")
            data, _, _ = _convert(folder)
            self.assertIs(data["modules"]["QRA"]["silence_all"], True)

    def test_no_silence_call_writes_no_qra(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            folder = Path(td)
            _make_folder(folder, "-- nothing\n")
            data, _, _ = _convert(folder)
            self.assertNotIn("QRA", data["modules"])


class TestCommunityScriptsFromWhatV5Loaded(unittest.TestCase):
    def test_aien_in_the_bundle_but_never_loaded_is_off(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            folder = Path(td)
            _make_folder(folder, "-- nothing\n")
            _community(folder, "AIEN.lua")
            data, text, report = _convert(folder)
            self.assertIs(data["modules"]["AIEN"], False)
            self.assertNotIn("aien", report.detected_community_script_ids)

    def test_aien_loaded_by_the_mission_stays_on(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            folder = Path(td)
            _make_folder(folder, "-- nothing\n")
            _community(folder, "AIEN.lua")
            mission_dir = folder / "src" / "mission"
            mission_dir.mkdir(parents=True)
            (mission_dir / "mission").write_text(
                'mission = { ["trig"] = { ["actions"] = { [1] = "a_do_script_file(getValueResourceByKey(\\"ResKey_Action_7\\"))" } } }\n'
                "-- l10n/DEFAULT/AIEN.lua\n",
                encoding="utf-8",
            )
            data, _, _ = _convert(folder)
            self.assertIs(data["modules"]["AIEN"], True)

    def test_remote_needs_its_initialize_call(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            folder = Path(td)
            _make_folder(folder, "if veafRemote then\n  veafRemote.monitorWithSlMod = false\nend\n")
            data, _, _ = _convert(folder)
            self.assertNotIn("REMOTE", data["modules"])

    def test_remote_initialized_in_v5_stays_on(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            folder = Path(td)
            _make_folder(folder, "if veafRemote then\n  veafRemote.initialize()\nend\n")
            data, _, _ = _convert(folder)
            self.assertIs(data["modules"]["REMOTE"], True)


class TestPipelineParity(unittest.TestCase):
    def test_a_mission_with_no_pipeline_file_gets_every_v6_step_off(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            folder = Path(td)
            _make_folder(folder, "-- nothing\n")
            data, _, _ = _convert(folder)
            pipeline = data["pipeline"]
            for step in (
                "presets",
                "waypoints",
                "spawnable_aircrafts",
                "dynamic_slot_templates",
                "warehouses",
                "weather",
            ):
                self.assertIs(pipeline[step], False, step)
            self.assertFalse((folder / "src" / "dynamic-slot-templates.yaml").exists())
            self.assertFalse((folder / "src" / "warehouses.yaml").exists())

    def test_a_converted_step_is_on_without_the_v6_extras(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            folder = Path(td)
            _make_folder(folder, "-- nothing\n")
            (folder / "src" / "presets.yaml").write_text("presets: {}\n", encoding="utf-8")
            (folder / "src" / "waypoints.yaml").write_text("waypoints: []\n", encoding="utf-8")
            data, _, _ = _convert(folder)
            pipeline = data["pipeline"]
            self.assertEqual(pipeline["presets"], {"enabled": True, "kneeboards": False})
            self.assertEqual(pipeline["waypoints"], {"enabled": True, "bullseye": False})

    def test_dynamic_slots_in_the_v5_mission_keep_the_templates(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            folder = Path(td)
            _make_folder(folder, "-- nothing\n")
            mission_dir = folder / "src" / "mission"
            mission_dir.mkdir(parents=True)
            (mission_dir / "warehouses").write_text(
                'warehouses = { ["airports"] = { [22] = { ["dynamicSpawn"] = true } } }\n', encoding="utf-8"
            )
            data, _, _ = _convert(folder)
            self.assertIs(data["pipeline"]["dynamic_slot_templates"], True)
            self.assertIs(data["pipeline"]["warehouses"], False)


class TestLanguageAndExports(unittest.TestCase):
    def test_the_language_is_always_written(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            folder = Path(td)
            _make_folder(folder, "-- nothing\n")
            with language("fr"):
                data, _, _ = _convert(folder)
            self.assertEqual(data["mission"]["language"], "fr")

    def test_a_computed_json_export_switch_is_offered_as_a_comment(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            folder = Path(td)
            _make_folder(folder, "veaf.DO_NOT_EXPORT_JSON_FILES = veaf.isServer()\n")
            data, text, _ = _convert(folder)
            self.assertIn("#   veaf.DO_NOT_EXPORT_JSON_FILES: true", text)


class TestReport(unittest.TestCase):
    def test_the_report_lists_what_was_kept_from_v5(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            folder = Path(td)
            _make_folder(folder, "-- nothing\n")
            _, _, report = _convert(folder)
            markdown = report.to_markdown()
            self.assertIn("dynamic_slot_templates: false", markdown)

    def test_the_report_states_the_log_level_written(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            folder = Path(td)
            _make_folder(folder, "-- nothing\n")
            _, _, report = _convert(folder)
            markdown = report.to_markdown()
            self.assertIn("`global_log_level: info`", markdown)
            self.assertNotIn("`global_log_level: debug`", markdown)


if __name__ == "__main__":
    unittest.main()
