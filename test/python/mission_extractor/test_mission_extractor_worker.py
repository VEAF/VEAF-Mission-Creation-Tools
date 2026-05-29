"""Tests for MissionExtractorWorker.__init__ — path validation."""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path


class TestMissionExtractorWorkerInit(unittest.TestCase):
    def test_valid_inputs_init_succeeds(self) -> None:
        from mission_extractor.mission_extractor_worker import MissionExtractorWorker

        with tempfile.TemporaryDirectory() as tmpdir:
            folder = Path(tmpdir)
            miz = folder / "test.miz"
            miz.write_bytes(b"PK\x03\x04")
            worker = MissionExtractorWorker(mission_folder=folder, input_mission_path=miz)
            self.assertEqual(worker.input_mission_path, miz)
            self.assertEqual(worker.mission_folder, folder)

    def test_missing_mission_file_raises(self) -> None:
        from mission_extractor.mission_extractor_worker import MissionExtractorWorker

        with tempfile.TemporaryDirectory() as tmpdir:
            folder = Path(tmpdir)
            missing = folder / "nonexistent.miz"
            with self.assertRaises((FileNotFoundError, SystemExit)):
                MissionExtractorWorker(mission_folder=folder, input_mission_path=missing)

    def test_missing_mission_folder_raises(self) -> None:
        from mission_extractor.mission_extractor_worker import MissionExtractorWorker

        with tempfile.TemporaryDirectory() as tmpdir:
            folder = Path(tmpdir)
            miz = folder / "test.miz"
            miz.write_bytes(b"PK\x03\x04")
            nonexistent_folder = folder / "no_such_folder"
            with self.assertRaises((FileNotFoundError, SystemExit)):
                MissionExtractorWorker(mission_folder=nonexistent_folder, input_mission_path=miz)


if __name__ == "__main__":
    unittest.main()
