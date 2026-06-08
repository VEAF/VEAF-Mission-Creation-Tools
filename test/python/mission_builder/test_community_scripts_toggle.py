"""Tests for community_scripts toggle parsing in MissionBuilderWorker — COMM-002/COMM-006."""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from mission_builder.mission_builder_worker import MissionBuilderWorker
from mission_tools.mission_constants import get_community_script_files


def _make_worker(yaml_content: str) -> MissionBuilderWorker:
    with tempfile.TemporaryDirectory() as tmpdir:
        mission_dir = Path(tmpdir)
        (mission_dir / "mission.yaml").write_text(yaml_content, encoding="utf-8")
        return MissionBuilderWorker(
            mission_folder=mission_dir,
            output_mission=mission_dir / "out.miz",
            dynamic_mode=None,
        )


ALL_IDS = {s["id"] for s in get_community_script_files()}


class TestCommunityScriptsToggleParsing(unittest.TestCase):
    """Unit tests for community_scripts: section parsing."""

    def test_no_section_enables_all(self) -> None:
        """Without community_scripts section, enabled_community_script_ids is None (all active)."""
        worker = _make_worker("")
        self.assertIsNone(worker.enabled_community_script_ids)

    def test_all_enabled_true_yields_all_ids(self) -> None:
        """When all scripts are listed with enabled: true, all ids are present."""
        yaml = "community_scripts:\n" + "".join(f"  {sid}: {{enabled: true}}\n" for sid in ALL_IDS)
        worker = _make_worker(yaml)
        self.assertEqual(worker.enabled_community_script_ids, ALL_IDS)

    def test_one_script_disabled(self) -> None:
        """A single script with enabled: false is absent from enabled_community_script_ids."""
        worker = _make_worker("community_scripts:\n  ctld: {enabled: false}\n")
        assert worker.enabled_community_script_ids is not None
        self.assertNotIn("ctld", worker.enabled_community_script_ids)

    def test_multiple_scripts_disabled(self) -> None:
        """Multiple scripts disabled are all absent."""
        worker = _make_worker(
            "community_scripts:\n"
            "  ctld: {enabled: false}\n"
            "  csar: {enabled: false}\n"
            "  mist: {enabled: true}\n"
        )
        assert worker.enabled_community_script_ids is not None
        self.assertNotIn("ctld", worker.enabled_community_script_ids)
        self.assertNotIn("csar", worker.enabled_community_script_ids)
        self.assertIn("mist", worker.enabled_community_script_ids)

    def test_empty_section_enables_nothing(self) -> None:
        """An empty community_scripts: section produces an empty enabled set."""
        worker = _make_worker("community_scripts: {}\n")
        self.assertIsNotNone(worker.enabled_community_script_ids)
        self.assertEqual(worker.enabled_community_script_ids, set())

    def test_unknown_id_is_ignored(self) -> None:
        """An unknown script id in community_scripts: is silently ignored."""
        worker = _make_worker("community_scripts:\n  unknown_tool: {enabled: true}\n")
        assert worker.enabled_community_script_ids is not None
        self.assertNotIn("unknown_tool", worker.enabled_community_script_ids)

    def test_non_dict_section_treated_as_absent(self) -> None:
        """A non-dict community_scripts value is ignored; all scripts remain active."""
        worker = _make_worker("community_scripts: not-a-dict\n")
        self.assertIsNone(worker.enabled_community_script_ids)


class TestActiveCommunityScripts(unittest.TestCase):
    """Unit tests for _active_community_scripts helper."""

    def test_none_returns_all(self) -> None:
        """_active_community_scripts returns all scripts when enabled_community_script_ids is None."""
        worker: MissionBuilderWorker = object.__new__(MissionBuilderWorker)
        worker.enabled_community_script_ids = None
        result = worker._active_community_scripts()
        self.assertEqual(result, get_community_script_files())

    def test_empty_set_returns_nothing(self) -> None:
        """_active_community_scripts returns empty list when no ids are enabled."""
        worker: MissionBuilderWorker = object.__new__(MissionBuilderWorker)
        worker.enabled_community_script_ids = set()
        self.assertEqual(worker._active_community_scripts(), [])

    def test_subset_returns_matching_scripts(self) -> None:
        """_active_community_scripts returns only scripts whose id is in the enabled set."""
        worker: MissionBuilderWorker = object.__new__(MissionBuilderWorker)
        worker.enabled_community_script_ids = {"mist", "ctld"}
        result = worker._active_community_scripts()
        result_ids = {s["id"] for s in result}
        self.assertEqual(result_ids, {"mist", "ctld"})


if __name__ == "__main__":
    unittest.main()
