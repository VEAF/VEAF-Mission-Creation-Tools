"""TDD tests for dcs-bridge.lua injection — DCSB-004."""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path
from unittest.mock import MagicMock, patch

from mission_builder.mission_builder_worker import MissionBuilderWorker


def _make_worker(mission_yaml: dict, mission_folder: Path | None = None) -> MissionBuilderWorker:
    """Instantiate a MissionBuilderWorker without running __init__, injecting only the
    attributes needed by dcs-bridge methods."""
    worker: MissionBuilderWorker = object.__new__(MissionBuilderWorker)
    worker._dcs_bridge_temp_file = None
    worker.mission_yaml = mission_yaml
    worker.mission_folder = mission_folder or Path(tempfile.mkdtemp())
    worker.scripts_path = None
    worker.output_mission = worker.mission_folder / "out.miz"
    worker.dcs_mission = None
    # Parse dcs_bridge config the same way __init__ does
    dcsb_cfg: dict = mission_yaml.get("dcs_bridge") or {}
    worker.dcs_bridge_enabled: bool = bool(dcsb_cfg.get("enabled", False))
    worker.dcs_bridge_lua_path: str | None = dcsb_cfg.get("lua_path")
    return worker


class TestDcsBridgeParsing(unittest.TestCase):
    """Unit tests for dcs_bridge section parsing from mission.yaml."""

    def test_absent_section_defaults_to_disabled(self) -> None:
        worker = _make_worker({})
        self.assertFalse(worker.dcs_bridge_enabled)
        self.assertIsNone(worker.dcs_bridge_lua_path)

    def test_enabled_false_explicit(self) -> None:
        worker = _make_worker({"dcs_bridge": {"enabled": False}})
        self.assertFalse(worker.dcs_bridge_enabled)

    def test_enabled_true(self) -> None:
        worker = _make_worker({"dcs_bridge": {"enabled": True}})
        self.assertTrue(worker.dcs_bridge_enabled)

    def test_lua_path_stored(self) -> None:
        worker = _make_worker({"dcs_bridge": {"enabled": True, "lua_path": "/some/path/dcs-bridge.lua"}})
        self.assertEqual(worker.dcs_bridge_lua_path, "/some/path/dcs-bridge.lua")

    def test_null_section_treated_as_absent(self) -> None:
        worker = _make_worker({"dcs_bridge": None})
        self.assertFalse(worker.dcs_bridge_enabled)


class TestResolveDcsBridgeFile(unittest.TestCase):
    """Unit tests for MissionBuilderWorker.resolve_dcs_bridge_file()."""

    def test_returns_none_when_disabled(self) -> None:
        worker = _make_worker({"dcs_bridge": {"enabled": False}})
        self.assertIsNone(worker.resolve_dcs_bridge_file())

    def test_returns_local_path_when_lua_path_set_and_exists(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            lua_file = Path(tmpdir) / "dcs-bridge.lua"
            lua_file.write_text("-- bridge", encoding="utf-8")
            worker = _make_worker({"dcs_bridge": {"enabled": True, "lua_path": str(lua_file)}})
            result = worker.resolve_dcs_bridge_file()
            self.assertIsNotNone(result)
            assert result is not None
            self.assertEqual(result.read_bytes(), b"-- bridge")

    def test_raises_when_lua_path_set_but_missing(self) -> None:
        worker = _make_worker({"dcs_bridge": {"enabled": True, "lua_path": "/nonexistent/dcs-bridge.lua"}})
        with self.assertRaises(FileNotFoundError):
            worker.resolve_dcs_bridge_file()

    def test_downloads_from_github_when_no_lua_path(self) -> None:
        fake_content = b"-- downloaded bridge"
        worker = _make_worker({"dcs_bridge": {"enabled": True}})
        with patch("mission_builder.mission_builder_worker.urllib.request.urlopen") as mock_open:
            mock_resp = MagicMock()
            mock_resp.read.return_value = fake_content
            mock_resp.__enter__ = lambda s: s
            mock_resp.__exit__ = MagicMock(return_value=False)
            mock_open.return_value = mock_resp
            result = worker.resolve_dcs_bridge_file()
        self.assertIsNotNone(result)
        assert result is not None
        self.assertEqual(result.read_bytes(), fake_content)

    def test_raises_on_download_failure(self) -> None:
        import urllib.error

        worker = _make_worker({"dcs_bridge": {"enabled": True}})
        with patch("mission_builder.mission_builder_worker.urllib.request.urlopen") as mock_open:
            mock_open.side_effect = urllib.error.URLError("connection refused")
            with self.assertRaises(RuntimeError):
                worker.resolve_dcs_bridge_file()


class TestInjectDcsBridgeTrigger(unittest.TestCase):
    """Unit tests for MissionBuilderWorker.inject_dcs_bridge_trigger()."""

    def _make_worker_with_mission(self, bridge_content: bytes) -> tuple[MissionBuilderWorker, Path]:
        tmpdir = Path(tempfile.mkdtemp())
        worker = _make_worker({"dcs_bridge": {"enabled": True}}, mission_folder=tmpdir)

        # Stub dcs_mission with minimal structure
        worker.dcs_mission = MagicMock()
        worker.dcs_mission.map_resource_content = {}
        worker.dcs_mission.mission_content = {
            "trig": {
                "actions": {1: 'a_do_script("existing");'},
                "conditions": {1: "return true"},
                "custom": {},
                "customStartup": {},
                "events": {},
                "flag": {1: True},
                "func": {},
                "funcStartup": {1: "if mission.trig.conditions[1]() then mission.trig.actions[1]() end"},
            },
            "trigrules": {
                1: {"comment": "existing", "predicate": "triggerStart", "rules": [], "actions": [], "eventlist": ""}
            },
        }

        # Write a fake bridge file
        bridge_file = tmpdir / "dcs-bridge.lua"
        bridge_file.write_bytes(bridge_content)
        return worker, bridge_file

    def test_inject_is_noop_when_bridge_file_is_none(self) -> None:
        worker = _make_worker({"dcs_bridge": {"enabled": False}})
        worker.dcs_mission = MagicMock()
        worker.inject_dcs_bridge_trigger(None)
        worker.dcs_mission.map_resource_content  # not touched — just ensure no crash

    def test_trigger_injected_at_position_1(self) -> None:
        worker, bridge_file = self._make_worker_with_mission(b"-- bridge")
        worker.inject_dcs_bridge_trigger(bridge_file)

        trigrules: dict = worker.dcs_mission.mission_content["trigrules"]
        # The bridge trigger is first (key=1), existing trigger is shifted to key=2
        self.assertIn(1, trigrules)
        self.assertIn("dcs-bridge", trigrules[1]["comment"].lower())
        self.assertIn(2, trigrules)
        self.assertEqual(trigrules[2]["comment"], "existing")

    def test_map_resource_entry_added(self) -> None:
        worker, bridge_file = self._make_worker_with_mission(b"-- bridge")
        worker.inject_dcs_bridge_trigger(bridge_file)

        map_res: dict = worker.dcs_mission.map_resource_content
        values = list(map_res.values())
        self.assertIn("dcs-bridge.lua", values)

    def test_action_references_map_resource_key(self) -> None:
        worker, bridge_file = self._make_worker_with_mission(b"-- bridge")
        worker.inject_dcs_bridge_trigger(bridge_file)

        map_res: dict = worker.dcs_mission.map_resource_content
        bridge_key = next(k for k, v in map_res.items() if v == "dcs-bridge.lua")
        trigrules: dict = worker.dcs_mission.mission_content["trigrules"]
        actions = trigrules[1]["actions"]
        self.assertTrue(any(bridge_key in str(a) for a in actions))

    def test_bridge_bytes_stored_for_write_miz(self) -> None:
        """inject_dcs_bridge_trigger stores the bridge bytes so write_mission can pass them to write_miz."""
        worker, bridge_file = self._make_worker_with_mission(b"-- bridge content")
        worker.inject_dcs_bridge_trigger(bridge_file)

        self.assertEqual(worker.dcs_bridge_bytes, b"-- bridge content")


if __name__ == "__main__":
    unittest.main()
