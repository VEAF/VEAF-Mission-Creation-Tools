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

    def test_only_disabled_script_absent(self) -> None:
        """Only listing one script as disabled leaves all others active (opt-out semantics)."""
        worker = _make_worker("community_scripts:\n  skynet: {enabled: false}\n")
        assert worker.enabled_community_script_ids is not None
        self.assertNotIn("skynet", worker.enabled_community_script_ids)
        self.assertIn("mist", worker.enabled_community_script_ids)
        self.assertIn("ctld", worker.enabled_community_script_ids)

    def test_one_script_disabled(self) -> None:
        """A single script with enabled: false is absent from enabled_community_script_ids."""
        worker = _make_worker("community_scripts:\n  ctld: {enabled: false}\n")
        assert worker.enabled_community_script_ids is not None
        self.assertNotIn("ctld", worker.enabled_community_script_ids)

    def test_multiple_scripts_disabled(self) -> None:
        """Multiple scripts disabled are all absent."""
        worker = _make_worker(
            "community_scripts:\n  ctld: {enabled: false}\n  csar: {enabled: false}\n  mist: {enabled: true}\n"
        )
        assert worker.enabled_community_script_ids is not None
        self.assertNotIn("ctld", worker.enabled_community_script_ids)
        self.assertNotIn("csar", worker.enabled_community_script_ids)
        self.assertIn("mist", worker.enabled_community_script_ids)

    def test_empty_section_treated_as_absent(self) -> None:
        """An empty community_scripts: {} section is treated as absent — all scripts active."""
        worker = _make_worker("community_scripts: {}\n")
        self.assertIsNone(worker.enabled_community_script_ids)

    def test_unknown_id_is_ignored_with_warning(self) -> None:
        """An unknown script id in community_scripts: is ignored (a warning is emitted)."""
        worker = _make_worker("community_scripts:\n  unknown_tool: {enabled: true}\n")
        assert worker.enabled_community_script_ids is not None
        self.assertNotIn("unknown_tool", worker.enabled_community_script_ids)

    def test_boolean_shorthand_true(self) -> None:
        """ctld: true enables ctld (non-dict shorthand)."""
        worker = _make_worker("community_scripts:\n  ctld: true\n")
        assert worker.enabled_community_script_ids is not None
        self.assertIn("ctld", worker.enabled_community_script_ids)

    def test_boolean_shorthand_false(self) -> None:
        """ctld: false disables ctld (non-dict shorthand)."""
        worker = _make_worker("community_scripts:\n  ctld: false\n")
        assert worker.enabled_community_script_ids is not None
        self.assertNotIn("ctld", worker.enabled_community_script_ids)

    def test_null_value_disables_script(self) -> None:
        """ctld: null disables ctld (null is not truthy)."""
        worker = _make_worker("community_scripts:\n  ctld: ~\n")
        assert worker.enabled_community_script_ids is not None
        self.assertNotIn("ctld", worker.enabled_community_script_ids)

    def test_empty_dict_value_enables_script(self) -> None:
        """ctld: {} enables ctld (empty dict → enabled defaults to true)."""
        worker = _make_worker("community_scripts:\n  ctld: {}\n")
        assert worker.enabled_community_script_ids is not None
        self.assertIn("ctld", worker.enabled_community_script_ids)

    def test_non_dict_section_treated_as_absent(self) -> None:
        """A non-dict community_scripts value is ignored; all scripts remain active."""
        worker = _make_worker("community_scripts: not-a-dict\n")
        self.assertIsNone(worker.enabled_community_script_ids)


class TestMistMandatory(unittest.TestCase):
    """MiST is a mandatory community dependency — always injected (FIX-DEFAULTS-MODULES)."""

    def test_mist_kept_when_disabled_explicitly(self) -> None:
        worker = _make_worker("community_scripts:\n  mist: {enabled: false}\n  ctld: {enabled: false}\n")
        assert worker.enabled_community_script_ids is not None
        self.assertIn("mist", worker.enabled_community_script_ids)  # mandatory → kept
        self.assertNotIn("ctld", worker.enabled_community_script_ids)  # ordinary → disabled

    def test_mist_kept_with_false_shorthand(self) -> None:
        worker = _make_worker("community_scripts:\n  mist: false\n")
        assert worker.enabled_community_script_ids is not None
        self.assertIn("mist", worker.enabled_community_script_ids)

    def test_mist_kept_when_bare_in_modules(self) -> None:
        # The default ships `modules:\n  MIST:` (bare) → normalized to community mist=None → kept.
        worker = _make_worker("modules:\n  MIST:\n  RADIO: true\n")
        assert worker.enabled_community_script_ids is not None
        self.assertIn("mist", worker.enabled_community_script_ids)


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

    def test_disabled_script_absent_from_active_scripts_and_paths(self) -> None:
        """A script disabled via YAML is absent from _active_community_scripts and its path is not present."""
        worker = _make_worker("community_scripts:\n  skynet: {enabled: false}\n")
        active = worker._active_community_scripts()
        active_ids = {s["id"] for s in active}
        active_paths = [s["path"] for s in active]
        self.assertNotIn("skynet", active_ids)
        self.assertFalse(any("skynet" in p for p in active_paths))
        # All other community scripts remain active
        self.assertIn("mist", active_ids)
        self.assertIn("ctld", active_ids)


if __name__ == "__main__":
    unittest.main()
