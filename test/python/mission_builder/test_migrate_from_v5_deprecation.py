"""Deprecation notice for migrate_from_v5 (FEAT-MIGRATE-MISSION-V6-003).

When the build still has to neutralise legacy v5 triggers in memory, it should
warn the maker to promote src/mission/ to v6 on disk (via convert-v5) so the
build-time migration becomes unnecessary. The flag itself stays for back-compat.
"""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from mission_builder.mission_builder_worker import MissionBuilderWorker
from mission_tools.miz_tools import DcsMission


def _make_worker() -> MissionBuilderWorker:
    with tempfile.TemporaryDirectory() as tmpdir:
        mission_dir = Path(tmpdir)
        (mission_dir / "mission.yaml").write_text("", encoding="utf-8")
        return MissionBuilderWorker(
            mission_folder=mission_dir,
            output_mission=mission_dir / "out.miz",
            dynamic_mode=None,
        )


def _mission_with_legacy_v5_trigger() -> DcsMission:
    """A mission whose dictionary carries a legacy v5 VEAF trigger value."""
    return DcsMission(
        file_path=Path("dummy.miz"),
        mission_content={"trig": {"actions": {}}, "trigrules": {}},
        dictionary_content={"VEAF_DictKey_1": "return false -- scripts"},
        map_resource_content={},
    )


def _mission_without_legacy() -> DcsMission:
    """A mission with a VEAF dict key but no legacy v5 value."""
    return DcsMission(
        file_path=Path("dummy.miz"),
        mission_content={"trig": {"actions": {}}, "trigrules": {}},
        dictionary_content={"VEAF_DictKey_1": "some current value"},
        map_resource_content={},
    )


class TestMigrateFromV5Deprecation(unittest.TestCase):
    def test_warns_when_legacy_v5_triggers_migrated(self) -> None:
        """A legacy v5 trigger triggers the deprecation nudge toward convert-v5."""
        worker = _make_worker()
        worker.dcs_mission = _mission_with_legacy_v5_trigger()

        with patch("mission_builder.mission_builder_worker.logger") as mock_logger:
            worker.clear_veaf_triggers()

        messages = [str(call.args[0]) for call in mock_logger.warning.call_args_list if call.args]
        self.assertTrue(any("convert-v5" in m for m in messages), messages)

    def test_no_warning_without_legacy_triggers(self) -> None:
        """A non-legacy VEAF key is cleared but raises no deprecation warning."""
        worker = _make_worker()
        worker.dcs_mission = _mission_without_legacy()

        with patch("mission_builder.mission_builder_worker.logger") as mock_logger:
            worker.clear_veaf_triggers()

        messages = [str(call.args[0]) for call in mock_logger.warning.call_args_list if call.args]
        self.assertFalse(any("convert-v5" in m for m in messages), messages)


if __name__ == "__main__":
    unittest.main()
