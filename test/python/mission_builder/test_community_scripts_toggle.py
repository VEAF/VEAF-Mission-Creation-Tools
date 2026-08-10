"""Tests for community_scripts toggle parsing in MissionBuilderWorker — COMM-002/COMM-006."""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from mission_builder.mission_builder_worker import MissionBuilderWorker
from mission_builder_factory import make_worker
from mission_tools.mission_constants import (
    get_community_script_files,
    get_optin_community_script_ids,
    is_community_script_enabled_by_default,
)


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

    def test_none_returns_all_optout(self) -> None:
        """_active_community_scripts returns every opt-out script (all but opt-in ids) when the set is None."""
        worker = make_worker(enabled_community_script_ids=None)
        result = worker._active_community_scripts()
        expected = [s for s in get_community_script_files() if s["id"] not in get_optin_community_script_ids()]
        self.assertEqual(result, expected)

    def test_none_excludes_optin_scripts(self) -> None:
        """Opt-in scripts (e.g. TUM) are NOT active by default when the set is None."""
        worker = make_worker(enabled_community_script_ids=None)
        active_ids = {s["id"] for s in worker._active_community_scripts()}
        for optin in get_optin_community_script_ids():
            self.assertNotIn(optin, active_ids)

    def test_empty_set_returns_nothing(self) -> None:
        """_active_community_scripts returns empty list when no ids are enabled."""
        worker = make_worker(enabled_community_script_ids=set())
        self.assertEqual(worker._active_community_scripts(), [])

    def test_subset_returns_matching_scripts(self) -> None:
        """_active_community_scripts returns only scripts whose id is in the enabled set."""
        worker = make_worker(enabled_community_script_ids={"mist", "ctld"})
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


class TestOptInScripts(unittest.TestCase):
    """Opt-in community scripts (e.g. TUM) are OFF unless explicitly enabled — TUM-AUTOINIT."""

    def test_optin_absent_from_section_is_disabled(self) -> None:
        """A community_scripts section that omits an opt-in id leaves it disabled."""
        worker = _make_worker("community_scripts:\n  ctld: {enabled: true}\n")
        assert worker.enabled_community_script_ids is not None
        for optin in get_optin_community_script_ids():
            self.assertNotIn(optin, worker.enabled_community_script_ids)
        self.assertIn("ctld", worker.enabled_community_script_ids)

    def test_optin_disabled_when_bare_modules_block(self) -> None:
        """A modules: block without the opt-in key leaves it inactive (vanilla/convert-v5 default)."""
        worker = _make_worker("modules:\n  RADIO: true\n  SPAWN: true\n")
        active_ids = {s["id"] for s in worker._active_community_scripts()}
        self.assertNotIn("tum", active_ids)

    def test_optin_enabled_when_explicitly_true(self) -> None:
        """Only an explicit <ID>: true turns an opt-in script on."""
        worker = _make_worker("community_scripts:\n  tum: {enabled: true}\n")
        assert worker.enabled_community_script_ids is not None
        self.assertIn("tum", worker.enabled_community_script_ids)

    def test_optin_disabled_when_explicitly_false(self) -> None:
        """An explicit <ID>: false keeps the opt-in script off."""
        worker = _make_worker("community_scripts:\n  tum: {enabled: false}\n")
        assert worker.enabled_community_script_ids is not None
        self.assertNotIn("tum", worker.enabled_community_script_ids)

    def test_shared_default_helper(self) -> None:
        """is_community_script_enabled_by_default: opt-out → True, opt-in → False (shared source of truth)."""
        for optin in get_optin_community_script_ids():
            self.assertFalse(is_community_script_enabled_by_default(optin))
        self.assertTrue(is_community_script_enabled_by_default("ctld"))
        self.assertTrue(is_community_script_enabled_by_default("csar"))


if __name__ == "__main__":
    unittest.main()
