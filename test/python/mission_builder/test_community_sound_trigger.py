"""Tests for the legacy community sound-preload trigger removal — TRIGGERS-VERIFY-004.

When neither CTLD nor CSAR is enabled, the build must drop the legacy v5
"sound preload" trigger (an ``out_sound`` registering beacon/CSAR ``.ogg`` files)
together with its mapResource entries. When either module is enabled, the trigger
must be kept untouched.
"""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from mission_builder.mission_builder_worker import MissionBuilderWorker
from mission_tools.miz_tools import DcsMission


def _make_worker(yaml_content: str) -> MissionBuilderWorker:
    with tempfile.TemporaryDirectory() as tmpdir:
        mission_dir = Path(tmpdir)
        (mission_dir / "mission.yaml").write_text(yaml_content, encoding="utf-8")
        return MissionBuilderWorker(
            mission_folder=mission_dir,
            output_mission=mission_dir / "out.miz",
            dynamic_mode=None,
        )


def _mission_with_sound_trigger() -> DcsMission:
    """Build a minimal mission carrying a CTLD/CSAR sound-preload trigger (index 5)."""
    sound_action = (
        'a_out_sound_c(89, getValueResourceByKey("ResKey_Action_797"), 0);'
        'a_out_sound_c(89, getValueResourceByKey("ResKey_Action_796"), 0);'
        'a_out_sound_c(89, getValueResourceByKey("ResKey_Action_803"), 0);'
    )
    return DcsMission(
        file_path=Path("dummy.miz"),
        mission_content={
            "trig": {
                "actions": {1: "a_do_script(0);", 5: sound_action},
                "conditions": {1: "return true", 5: "return true"},
            },
            "trigrules": {1: {"comment": "keep"}, 5: {"comment": "sound preload"}},
        },
        dictionary_content={},
        map_resource_content={
            "ResKey_Action_797": "beacon.ogg",
            "ResKey_Action_796": "beaconsilent.ogg",
            "ResKey_Action_803": "CSAR.ogg",
            "ResKey_Action_900": "mybriefing.ogg",
        },
    )


class TestCommunitySoundTriggerRemoval(unittest.TestCase):
    """clear_veaf_triggers drops the community sound-preload trigger only when both modules are off."""

    def test_removed_when_both_ctld_and_csar_disabled(self) -> None:
        """Both modules disabled → the sound trigger and its resources are removed."""
        worker = _make_worker("community_scripts:\n  ctld: {enabled: false}\n  csar: {enabled: false}\n")
        worker.dcs_mission = _mission_with_sound_trigger()

        worker.clear_veaf_triggers()

        actions = worker.dcs_mission.mission_content["trig"]["actions"]
        self.assertNotIn(5, actions)
        self.assertIn(1, actions)
        self.assertNotIn(5, worker.dcs_mission.mission_content["trigrules"])
        resources = worker.dcs_mission.map_resource_content
        self.assertNotIn("ResKey_Action_797", resources)
        self.assertNotIn("ResKey_Action_796", resources)
        self.assertNotIn("ResKey_Action_803", resources)

    def test_unrelated_sound_resource_is_preserved(self) -> None:
        """A non-community sound resource is never removed, even when both modules are off."""
        worker = _make_worker("community_scripts:\n  ctld: {enabled: false}\n  csar: {enabled: false}\n")
        worker.dcs_mission = _mission_with_sound_trigger()

        worker.clear_veaf_triggers()

        self.assertIn("ResKey_Action_900", worker.dcs_mission.map_resource_content)

    def test_kept_when_ctld_enabled(self) -> None:
        """CTLD enabled (CSAR off) → the sound trigger and its resources are kept."""
        worker = _make_worker("community_scripts:\n  csar: {enabled: false}\n")
        worker.dcs_mission = _mission_with_sound_trigger()

        worker.clear_veaf_triggers()

        self.assertIn(5, worker.dcs_mission.mission_content["trig"]["actions"])
        self.assertIn("ResKey_Action_797", worker.dcs_mission.map_resource_content)

    def test_kept_when_csar_enabled(self) -> None:
        """CSAR enabled (CTLD off) → the sound trigger and its resources are kept."""
        worker = _make_worker("community_scripts:\n  ctld: {enabled: false}\n")
        worker.dcs_mission = _mission_with_sound_trigger()

        worker.clear_veaf_triggers()

        self.assertIn(5, worker.dcs_mission.mission_content["trig"]["actions"])
        self.assertIn("ResKey_Action_803", worker.dcs_mission.map_resource_content)

    def test_kept_when_all_enabled_by_default(self) -> None:
        """No community_scripts section → all enabled → trigger kept."""
        worker = _make_worker("")
        worker.dcs_mission = _mission_with_sound_trigger()

        worker.clear_veaf_triggers()

        self.assertIn(5, worker.dcs_mission.mission_content["trig"]["actions"])
        self.assertIn("ResKey_Action_797", worker.dcs_mission.map_resource_content)


class TestCommunityEnabledHelper(unittest.TestCase):
    """_community_enabled honours opt-out semantics."""

    def test_none_means_all_enabled(self) -> None:
        worker = _make_worker("")
        self.assertTrue(worker._community_enabled("ctld"))
        self.assertTrue(worker._community_enabled("csar"))

    def test_disabled_id_is_false(self) -> None:
        worker = _make_worker("community_scripts:\n  ctld: {enabled: false}\n")
        self.assertFalse(worker._community_enabled("ctld"))
        self.assertTrue(worker._community_enabled("csar"))


if __name__ == "__main__":
    unittest.main()
