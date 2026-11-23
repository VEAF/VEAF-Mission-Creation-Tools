"""A conversion that cannot finish writes nothing, and the build refuses a half-converted folder.

FIX-CONVERT-V5-PARITY ticket 02, #1301: on a 149-character folder, `convert v5` died on `[WinError 3]`
copying the deepest file into `backup_v5/`, after writing `mission.yaml`; `mission build` then built
the half-converted folder and exited 0.

The Windows limit is patched down so the test runs on any system and in a short temporary folder.
"""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path
from unittest import mock

import typer

from mission_builder import v5_converter
from mission_builder.v5_converter import PathTooLongError, V5Converter


def _v5_folder(folder: Path) -> None:
    scripts = folder / "src" / "scripts"
    scripts.mkdir(parents=True)
    (scripts / "missionConfig.lua").write_text("-- v5\n", encoding="utf-8")
    deep = folder / "src" / "mission" / "KNEEBOARD" / "FA-18C_hornet" / "IMAGES"
    deep.mkdir(parents=True)
    (deep / "this folder contains the images (jpg).txt").write_text("", encoding="utf-8")


class TestLongPathRefusedBeforeWriting(unittest.TestCase):
    def test_a_path_past_the_limit_is_refused_before_anything_is_written(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            folder = Path(td)
            _v5_folder(folder)
            deepest = folder / "backup_v5" / "src" / "mission" / "KNEEBOARD" / "FA-18C_hornet" / "IMAGES"
            limit = len(str(deepest)) + 10
            with mock.patch.object(v5_converter, "_path_limit", return_value=limit):
                with self.assertRaises(PathTooLongError) as raised:
                    V5Converter().convert(folder, backup=True)
            self.assertIn("this folder contains the images", str(raised.exception.path))
            self.assertGreater(raised.exception.length, limit)
            self.assertFalse((folder / "mission.yaml").exists())
            self.assertFalse((folder / "backup_v5").exists())
            self.assertTrue((folder / "src" / "scripts" / "missionConfig.lua").exists())

    def test_a_short_folder_converts(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            folder = Path(td)
            _v5_folder(folder)
            with mock.patch.object(v5_converter, "_path_limit", return_value=10_000):
                report = V5Converter().convert(folder, backup=True)
            self.assertTrue(report.mission_yaml_generated)

    def test_no_limit_means_no_check(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            folder = Path(td)
            _v5_folder(folder)
            with mock.patch.object(v5_converter, "_path_limit", return_value=None):
                report = V5Converter().convert(folder, backup=True)
            self.assertTrue(report.mission_yaml_generated)


class TestTheBuildRefusesAHalfConvertedFolder(unittest.TestCase):
    def test_backup_v5_without_mission_yaml_is_refused(self) -> None:
        from mission_builder.mission_builder_worker import MissionBuilderWorker

        with tempfile.TemporaryDirectory() as td:
            folder = Path(td)
            (folder / "backup_v5").mkdir()
            # logger.error stops the run (typer.Abort), after naming the folder and `convert v5`.
            with self.assertRaises(typer.Abort):
                MissionBuilderWorker._refuse_half_converted_folder(folder)

    def test_a_converted_folder_is_not_refused(self) -> None:
        from mission_builder.mission_builder_worker import MissionBuilderWorker

        with tempfile.TemporaryDirectory() as td:
            folder = Path(td)
            (folder / "backup_v5").mkdir()
            (folder / "mission.yaml").write_text("modules: {}\n", encoding="utf-8")
            MissionBuilderWorker._refuse_half_converted_folder(folder)


if __name__ == "__main__":
    unittest.main()


class TestTheCommandStopsCleanly(unittest.TestCase):
    """`convert v5` ends in a message and exit code 1, never in a traceback, and leaves no marker."""

    def setUp(self) -> None:
        import veaf_tools.commands  # noqa: F401  — side effect: registers every command on `app`
        from typer.testing import CliRunner

        self.runner = CliRunner()
        patcher = mock.patch("veaf_libs.user_config.get_check_updates", return_value=False)
        patcher.start()
        self.addCleanup(patcher.stop)

    def _invoke(self, folder: Path) -> object:
        from veaf_tools.app import app

        return self.runner.invoke(app, ["convert-v5", str(folder), "--force"])

    def test_a_refused_path_exits_1_and_writes_nothing(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            folder = Path(td)
            _v5_folder(folder)
            with mock.patch.object(v5_converter, "_path_limit", return_value=20):
                result = self._invoke(folder)
            self.assertEqual(result.exit_code, 1, result.output)
            self.assertFalse((folder / "mission.yaml").exists())
            self.assertFalse((folder / "backup_v5").exists())

    def test_a_promotion_that_fails_removes_mission_yaml_and_exits_1(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            folder = Path(td)
            _v5_folder(folder)
            with (
                mock.patch.object(v5_converter, "_path_limit", return_value=None),
                mock.patch(
                    "veaf_tools.commands.convert_v5.promote_mission_to_v6",
                    side_effect=FileNotFoundError(3, "The system cannot find the path specified"),
                ),
            ):
                result = self._invoke(folder)
            self.assertEqual(result.exit_code, 1, result.output)
            self.assertFalse((folder / "mission.yaml").exists())
            self.assertTrue((folder / "backup_v5").is_dir())
