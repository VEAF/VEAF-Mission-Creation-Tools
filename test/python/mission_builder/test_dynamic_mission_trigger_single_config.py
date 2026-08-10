"""Regression: the dynamic mission-loading trigrule must load veaf-config.lua only ONCE.

In dynamic mode the mission-loading trigrule runs veafDynamicConfig.lua, whose
generated ``scriptsToLoad`` already starts with veaf-config.lua. An additional
explicit ``loadfile(veaf-config.lua)`` in the same trigrule made veaf-config.lua
run twice, re-initializing every module twice (e.g. veafCommands registered its
central marker-dispatch handler twice → markers like ``_spawn`` fired twice).
"""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from mission_builder.mission_builder_worker import MissionBuilderWorker


def _make_worker() -> MissionBuilderWorker:
    worker: MissionBuilderWorker = object.__new__(MissionBuilderWorker)
    worker.mission_folder = Path(tempfile.mkdtemp())
    worker.output_mission = worker.mission_folder / "out.miz"
    worker.scripts_path = None
    # No CTLD/CSAR sound to declare: these hand-built workers exercise the load triggers,
    # not the sound declaration (FIX-COMMUNITY-SOUNDS-PRUNED).
    worker.collected_community_sound_files = {}
    worker.collected_mission_data_files = {}
    worker.dev_mode = True
    # Stub the file-collection helpers used by insert_veaf_trigrules.
    worker.get_collected_community_script_files = lambda: []  # type: ignore[method-assign]
    worker.get_collected_veaf_script_files = lambda: []  # type: ignore[method-assign]
    worker._active_community_scripts = lambda: []  # type: ignore[method-assign]
    worker.dcs_mission = type("M", (), {})()
    worker.dcs_mission.mission_content = {"trigrules": {}}
    return worker


def _dynamic_mission_trigrule(worker: MissionBuilderWorker) -> dict:
    trigrules: dict = worker.dcs_mission.mission_content["trigrules"]
    return next(r for r in trigrules.values() if r.get("comment") == "Mission scripts loading - dynamic")


class TestDynamicMissionTriggerSingleConfig(unittest.TestCase):
    def test_dynamic_trigrule_loads_dynamic_config_not_explicit_veaf_config(self) -> None:
        worker = _make_worker()
        worker.insert_veaf_trigrules(worker._build_veaf_trigger_specs({}, {}))

        rule = _dynamic_mission_trigrule(worker)
        action_texts = [a.get("text", "") for a in rule["actions"]]

        # veafDynamicConfig.lua is the single entry point for dynamic mission loading.
        self.assertTrue(any("veafDynamicConfig.lua" in t for t in action_texts))
        # No explicit veaf-config.lua load — that would run it twice (double init).
        self.assertFalse(
            any("veaf-config.lua" in t for t in action_texts),
            f"dynamic trigrule must not load veaf-config.lua explicitly: {action_texts}",
        )


if __name__ == "__main__":
    unittest.main()
