"""SECREV-2 / VMR-049 — the auto-downloaded dcs-bridge.lua leaked a temp file every build.

`resolve_dcs_bridge_file` wrote the download to a `NamedTemporaryFile(delete=False)` and returned
its path; nothing ever removed it. The trap is that the caller cannot simply delete what it is
given: the same parameter carries a `lua_path` the mission maker provided, which must survive.
"""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path
from unittest import mock

from mission_builder import mission_builder_worker
from mission_builder.mission_builder_worker import MissionBuilderWorker
from mission_tools.miz_tools import DcsMission


def _worker(yaml_content: str) -> MissionBuilderWorker:
    folder = Path(tempfile.mkdtemp())
    (folder / "mission.yaml").write_text(yaml_content, encoding="utf-8")
    return MissionBuilderWorker(mission_folder=folder, output_mission=folder / "out.miz", dynamic_mode=None)


def _mission() -> DcsMission:
    return DcsMission(
        file_path=Path("dummy.miz"),
        mission_content={
            "trig": {"actions": {}, "conditions": {}, "func": {}, "funcStartup": {}, "flag": {}},
            "trigrules": {},
        },
        dictionary_content={},
        map_resource_content={},
    )


class TestDownloadedTempFileIsCleanedUp(unittest.TestCase):
    def test_the_temp_file_is_gone_once_its_bytes_are_read(self) -> None:
        worker = _worker("dcs_bridge:\n  enabled: true\n")
        worker.dcs_mission = _mission()
        with mock.patch.object(mission_builder_worker.urllib.request, "urlopen") as urlopen:
            urlopen.return_value.__enter__.return_value.read.return_value = b"-- bridge"
            path = worker.resolve_dcs_bridge_file()
        assert path is not None
        self.assertTrue(path.exists(), "the download must land somewhere the caller can read")

        worker.inject_dcs_bridge_trigger(path)

        self.assertEqual(worker.dcs_bridge_bytes, b"-- bridge", "the content still has to reach the mission")
        self.assertFalse(path.exists(), "the temp file must not survive the build")


class TestAMissionMakersFileIsNeverDeleted(unittest.TestCase):
    def test_an_explicit_lua_path_survives(self) -> None:
        # The same argument carries both cases, which is exactly why the worker has to remember
        # which one it created rather than deleting whatever it is handed.
        folder = Path(tempfile.mkdtemp())
        theirs = folder / "my-bridge.lua"
        theirs.write_text("-- mine", encoding="utf-8")

        worker = _worker(f"dcs_bridge:\n  enabled: true\n  lua_path: {theirs.as_posix()}\n")
        worker.dcs_mission = _mission()
        path = worker.resolve_dcs_bridge_file()
        self.assertEqual(path, theirs)

        worker.inject_dcs_bridge_trigger(path)

        self.assertTrue(theirs.exists(), "deleting the mission maker's own file would be a data loss bug")
        self.assertEqual(worker.dcs_bridge_bytes, b"-- mine")


if __name__ == "__main__":
    unittest.main()
