"""Tests for mission_builder.mission_promoter (FEAT-MIGRATE-MISSION-V6-002).

The promoter orchestrates a base build → backup → extract round-trip. These
tests mock both sub-workers and assert the orchestration contract: backup made,
src/mission rewritten, and non-blocking behaviour on build/extract failure.
"""

from __future__ import annotations

import shutil
import tempfile
import unittest
from pathlib import Path
from unittest.mock import MagicMock, patch

from mission_builder.mission_promoter import promote_mission_to_v6


def _make_mission_folder() -> Path:
    """Create a temp mission folder holding a v5 src/mission/mission marker."""
    folder = Path(tempfile.mkdtemp())
    src_mission = folder / "src" / "mission"
    src_mission.mkdir(parents=True)
    (src_mission / "mission").write_text("v5 content", encoding="utf-8")
    return folder


def _builder_factory(*_args, **kwargs):
    """A mock MissionBuilderWorker whose work() writes the requested output .miz."""
    worker = MagicMock()
    out: Path = kwargs["output_mission"]
    worker.work.side_effect = lambda silent=False: out.write_bytes(b"miz")
    return worker


def _extractor_factory(*_args, **kwargs):
    """A mock MissionExtractorWorker whose work() rewrites src/mission with v6 content."""
    worker = MagicMock()
    folder: Path = kwargs["mission_folder"]

    def _work(silent: bool = False) -> None:
        src_mission = folder / "src" / "mission"
        src_mission.mkdir(parents=True, exist_ok=True)
        (src_mission / "mission").write_text("v6 content", encoding="utf-8")

    worker.work.side_effect = _work
    return worker


class TestPromoteMissionToV6(unittest.TestCase):
    """Orchestration contract of promote_mission_to_v6."""

    def setUp(self) -> None:
        self.folder = _make_mission_folder()
        self.addCleanup(shutil.rmtree, self.folder, ignore_errors=True)

    def test_no_src_mission_returns_not_promoted(self) -> None:
        """A folder without src/mission/ is skipped, not crashed."""
        empty = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, empty, ignore_errors=True)
        result = promote_mission_to_v6(empty)
        self.assertFalse(result.promoted)
        self.assertTrue(result.reason)

    @patch("mission_extractor.MissionExtractorWorker", side_effect=_extractor_factory)
    @patch("mission_builder.mission_promoter.MissionBuilderWorker", side_effect=_builder_factory)
    def test_nominal_promotion(self, mock_builder_cls: MagicMock, mock_extractor_cls: MagicMock) -> None:
        """Happy path: backup made, src/mission rewritten in v6, both workers run once."""
        result = promote_mission_to_v6(self.folder)

        self.assertTrue(result.promoted)
        backup = self.folder / "backup_v5" / "src" / "mission" / "mission"
        self.assertTrue(backup.exists())
        self.assertEqual(backup.read_text(encoding="utf-8"), "v5 content")
        self.assertEqual(
            (self.folder / "src" / "mission" / "mission").read_text(encoding="utf-8"), "v6 content"
        )
        mock_builder_cls.assert_called_once()
        mock_extractor_cls.assert_called_once()

    @patch("mission_extractor.MissionExtractorWorker")
    @patch("mission_builder.mission_promoter.MissionBuilderWorker")
    def test_build_failure_is_non_blocking(
        self, mock_builder_cls: MagicMock, mock_extractor_cls: MagicMock
    ) -> None:
        """A base-build failure leaves src/mission untouched and never extracts."""
        failing = MagicMock()
        failing.work.side_effect = RuntimeError("build boom")
        mock_builder_cls.return_value = failing

        result = promote_mission_to_v6(self.folder)

        self.assertFalse(result.promoted)
        self.assertTrue(result.reason)
        # src/mission is untouched and no backup was taken.
        self.assertEqual(
            (self.folder / "src" / "mission" / "mission").read_text(encoding="utf-8"), "v5 content"
        )
        self.assertFalse((self.folder / "backup_v5").exists())
        mock_extractor_cls.assert_not_called()

    @patch("mission_extractor.MissionExtractorWorker")
    @patch("mission_builder.mission_promoter.MissionBuilderWorker", side_effect=_builder_factory)
    def test_extract_failure_restores_backup(
        self, mock_builder_cls: MagicMock, mock_extractor_cls: MagicMock
    ) -> None:
        """An extract failure restores src/mission from the backup."""
        failing = MagicMock()
        failing.work.side_effect = RuntimeError("extract boom")
        mock_extractor_cls.return_value = failing

        result = promote_mission_to_v6(self.folder)

        self.assertFalse(result.promoted)
        self.assertTrue(result.reason)
        # src/mission restored to its original v5 content from backup_v5/.
        self.assertEqual(
            (self.folder / "src" / "mission" / "mission").read_text(encoding="utf-8"), "v5 content"
        )
        self.assertIsNotNone(result.backup_path)


if __name__ == "__main__":
    unittest.main()
