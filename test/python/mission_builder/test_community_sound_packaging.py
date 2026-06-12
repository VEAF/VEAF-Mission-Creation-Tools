"""Tests for community sound packaging at build time — BUILD-COMMUNITY-SOUNDS-001.

The build injects the CTLD/CSAR ``.ogg`` sounds (shipped under
``src/scripts/community/sounds/``) into the mission's ``l10n/DEFAULT/`` when the
owning module is enabled, without overwriting sounds the mission already
provides. A required sound shipped by neither the tool nor the mission is warned.
"""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path
from unittest import mock

from mission_builder.mission_builder_worker import MissionBuilderWorker


class TestCommunitySoundPackaging(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.mission_dir = Path(self._tmp.name)
        self.sounds_dir = self.mission_dir / "published" / "src" / "scripts" / "community" / "sounds"
        self.sounds_dir.mkdir(parents=True)

    def _write_sounds(self, *names: str) -> None:
        for name in names:
            (self.sounds_dir / name).write_bytes(b"OggS-fake-audio")

    def _worker(self, yaml: str = "") -> MissionBuilderWorker:
        (self.mission_dir / "mission.yaml").write_text(yaml, encoding="utf-8")
        return MissionBuilderWorker(
            mission_folder=self.mission_dir,
            output_mission=self.mission_dir / "out.miz",
            dynamic_mode=None,
        )

    def test_all_enabled_collects_ctld_and_csar_sounds(self) -> None:
        """No community_scripts section → all enabled → every shipped required sound is collected."""
        self._write_sounds("beacon.ogg", "beaconsilent.ogg", "CSAR.ogg")
        worker = self._worker("")
        collected = worker.get_collected_community_sound_files()
        self.assertEqual({Path(k).name for k in collected}, {"beacon.ogg", "beaconsilent.ogg", "CSAR.ogg"})
        self.assertIn("l10n/DEFAULT/beacon.ogg", collected)

    def test_both_disabled_collects_nothing(self) -> None:
        """Both CTLD and CSAR disabled → no sounds collected."""
        self._write_sounds("beacon.ogg", "beaconsilent.ogg", "CSAR.ogg")
        worker = self._worker("community_scripts:\n  ctld: {enabled: false}\n  csar: {enabled: false}\n")
        self.assertEqual(worker.get_collected_community_sound_files(), {})

    def test_csar_only_keeps_shared_beacon(self) -> None:
        """CTLD off, CSAR on → CSAR's sounds (beacon.ogg + CSAR.ogg) collected, CTLD-only beaconsilent excluded."""
        self._write_sounds("beacon.ogg", "beaconsilent.ogg", "CSAR.ogg")
        worker = self._worker("community_scripts:\n  ctld: {enabled: false}\n")
        self.assertEqual({Path(k).name for k in worker.get_collected_community_sound_files()}, {"beacon.ogg", "CSAR.ogg"})

    def test_ctld_only_excludes_csar_sound(self) -> None:
        """CSAR off, CTLD on → CTLD's available sounds collected, CSAR.ogg excluded."""
        self._write_sounds("beacon.ogg", "beaconsilent.ogg", "CSAR.ogg")
        worker = self._worker("community_scripts:\n  csar: {enabled: false}\n")
        # radiobeep.ogg is required by CTLD but not shipped here → absent from result
        self.assertEqual(
            {Path(k).name for k in worker.get_collected_community_sound_files()},
            {"beacon.ogg", "beaconsilent.ogg"},
        )

    def test_missing_required_sound_warns(self) -> None:
        """A required sound shipped by neither tool nor mission triggers a build warning."""
        self._write_sounds("beacon.ogg")  # beaconsilent.ogg, radiobeep.ogg, CSAR.ogg missing
        worker = self._worker("")
        with mock.patch.object(
            __import__("mission_builder.mission_builder_worker", fromlist=["logger"]).logger, "warning"
        ) as warn:
            worker.get_collected_community_sound_files()
        warned = " ".join(str(c.args) + str(c.kwargs) for c in warn.call_args_list)
        self.assertIn("beaconsilent.ogg", warned)
        self.assertIn("radiobeep.ogg", warned)
        self.assertIn("CSAR.ogg", warned)

    def test_result_is_cached(self) -> None:
        """The collection is computed once and cached."""
        self._write_sounds("beacon.ogg", "beaconsilent.ogg", "CSAR.ogg")
        worker = self._worker("")
        first = worker.get_collected_community_sound_files()
        self.assertIs(first, worker.get_collected_community_sound_files())


if __name__ == "__main__":
    unittest.main()
