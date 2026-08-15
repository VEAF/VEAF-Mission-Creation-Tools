"""SECREV-2 / VMR-005 — inserting the dcs-bridge trigger broke every existing trigger.

`inject_dcs_bridge_trigger` made room at index 1 by shifting every `trig` category up
(`{k + 1: v ...}`) without rewriting the **Lua text** of the shifted entries. Those strings
hardcode their own indices:

    if mission.trig.conditions[1]() then mission.trig.actions[1]() end

so after the shift the trigger sitting at key 2 still invoked `conditions[1]` — the
bridge's. Every previously inserted trigger fired the wrong pair.

`insert_veaf_triggers` already does this correctly, rewriting `[old]` → `[new]` inside the
string values, which is why the fix is routing rather than new logic.
"""

from __future__ import annotations

from pathlib import Path

import pytest
from mission_builder.mission_builder_worker import MissionBuilderWorker
from mission_builder_factory import make_worker
from mission_tools.miz_tools import DcsMission


def _mission_with_one_trigger() -> DcsMission:
    """A mission holding a single pre-existing trigger that references its own pair."""
    mission = DcsMission(file_path=Path("unused.miz"))
    mission.mission_content = {
        "trig": {
            "actions": {1: 'a_do_script("existing()");'},
            "conditions": {1: "return true"},
            "flag": {1: True},
            "funcStartup": {1: "if mission.trig.conditions[1]() then mission.trig.actions[1]() end"},
        },
        "trigrules": {1: {"comment": "existing", "predicate": "triggerStart", "rules": [], "actions": []}},
    }
    mission.map_resource_content = {}
    return mission


@pytest.fixture
def worker(tmp_path: Path) -> MissionBuilderWorker:
    # _dcs_bridge_temp_file stays None (the factory default): this bridge file is the fixture's
    # own, not one the worker downloaded, so it must survive (SECREV-2 / VMR-049).
    return make_worker(dcs_mission=_mission_with_one_trigger())


@pytest.fixture
def bridge_file(tmp_path: Path) -> Path:
    path = tmp_path / "dcs-bridge.lua"
    path.write_text("-- bridge", encoding="utf-8")
    return path


class TestExistingTriggersSurviveTheShift:
    def test_existing_trigger_still_references_its_own_pair(
        self, worker: MissionBuilderWorker, bridge_file: Path
    ) -> None:
        """The regression: the shifted trigger must point at [2], not at the bridge's [1]."""
        worker.inject_dcs_bridge_trigger(bridge_file)

        func_startup = worker.dcs_mission.mission_content["trig"]["funcStartup"]
        shifted = func_startup[2]
        assert "conditions[2]" in shifted, f"shifted trigger still points elsewhere: {shifted}"
        assert "actions[2]" in shifted, f"shifted trigger still points elsewhere: {shifted}"
        assert "conditions[1]" not in shifted

    def test_bridge_occupies_index_one(self, worker: MissionBuilderWorker, bridge_file: Path) -> None:
        worker.inject_dcs_bridge_trigger(bridge_file)
        trig = worker.dcs_mission.mission_content["trig"]
        assert "VEAF_MapKey_DcsBridge" in trig["actions"][1]
        assert "conditions[1]" in trig["funcStartup"][1]

    def test_existing_action_is_preserved(self, worker: MissionBuilderWorker, bridge_file: Path) -> None:
        worker.inject_dcs_bridge_trigger(bridge_file)
        assert "existing()" in worker.dcs_mission.mission_content["trig"]["actions"][2]

    def test_trigrules_shift_too(self, worker: MissionBuilderWorker, bridge_file: Path) -> None:
        worker.inject_dcs_bridge_trigger(bridge_file)
        trigrules = worker.dcs_mission.mission_content["trigrules"]
        assert trigrules[1]["comment"] == "dcs-bridge loading"
        assert trigrules[2]["comment"] == "existing"

    def test_map_resource_registers_the_bridge(self, worker: MissionBuilderWorker, bridge_file: Path) -> None:
        worker.inject_dcs_bridge_trigger(bridge_file)
        assert worker.dcs_mission.map_resource_content["VEAF_MapKey_DcsBridge"] == "dcs-bridge.lua"

    def test_none_is_a_noop(self, worker: MissionBuilderWorker) -> None:
        before = dict(worker.dcs_mission.mission_content["trig"]["funcStartup"])
        worker.inject_dcs_bridge_trigger(None)
        assert worker.dcs_mission.mission_content["trig"]["funcStartup"] == before


class TestSeveralTriggersShiftWithoutColliding:
    """Each string must be rewritten with its own key — a blanket substitution would cross-talk."""

    @pytest.fixture
    def worker_with_three(self, tmp_path: Path) -> MissionBuilderWorker:
        mission = DcsMission(file_path=Path("unused.miz"))
        mission.mission_content = {
            "trig": {
                "actions": {n: f'a_do_script("t{n}()");' for n in (1, 2, 3)},
                "conditions": {n: "return true" for n in (1, 2, 3)},
                "flag": {n: True for n in (1, 2, 3)},
                "funcStartup": {
                    n: f"if mission.trig.conditions[{n}]() then mission.trig.actions[{n}]() end" for n in (1, 2, 3)
                },
            },
            "trigrules": {
                n: {"comment": f"t{n}", "predicate": "triggerStart", "rules": [], "actions": []} for n in (1, 2, 3)
            },
        }
        mission.map_resource_content = {}
        return make_worker(dcs_mission=mission)

    def test_every_trigger_points_at_its_own_new_index(
        self, worker_with_three: MissionBuilderWorker, bridge_file: Path
    ) -> None:
        worker_with_three.inject_dcs_bridge_trigger(bridge_file)
        func_startup = worker_with_three.dcs_mission.mission_content["trig"]["funcStartup"]
        for new_key in (2, 3, 4):
            assert f"conditions[{new_key}]" in func_startup[new_key]
            assert f"actions[{new_key}]" in func_startup[new_key]

    def test_actions_follow_their_trigger(self, worker_with_three: MissionBuilderWorker, bridge_file: Path) -> None:
        worker_with_three.inject_dcs_bridge_trigger(bridge_file)
        actions = worker_with_three.dcs_mission.mission_content["trig"]["actions"]
        assert "t1()" in actions[2]
        assert "t2()" in actions[3]
        assert "t3()" in actions[4]
