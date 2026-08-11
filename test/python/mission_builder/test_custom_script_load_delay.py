"""FEAT-CUSTOM-SCRIPT-LOAD-DELAY: `custom_scripts` can stagger its loading like upstream does.

A third-party mission may load its scripts in stages — Foothold uses `triggerStart`, then
`triggerOnce` + `c_time_after 3`, then `+12` — and adopting it collapsed everything into one
`triggerStart`. Nothing said so: the order held, only the wall-clock delay was lost.

**That loss is not cosmetic.** AIEN's `populate_Db()` is, in its own words, "launched once at mission
start and collect everything relevant that is already there" — a single inventory of ground groups.
Foothold spawns its own groups from `SCHEDULER:New(…, o:update(), …, 2, …)` and deferred save
restores, i.e. from t+2 s onwards. Loading AIEN at t=0 instead of t+12 s hands it a world those
schedulers have not populated yet, and the symptom is silent: no log error, just ground AI that never
manages the groups Foothold created.

The structural facts asserted here were **read out of an upstream `.miz`** rather than assumed
(Foothold_CA 4.4.1, its `mission` table): a delayed trigger lives in `trig.func` and not
`trig.funcStartup`, its condition is `return(c_time_after(N) )`, and its action string ends in
`mission.trig.func[i]=nil;` — that self-disarming suffix is what makes a `triggerOnce` fire once.
"""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path
from unittest import mock

from mission_builder import mission_builder_worker
from mission_builder.mission_builder_worker import (
    CustomScript,
    MissionBuilderWorker,
    _parse_custom_scripts,
)
from mission_builder_factory import make_worker

_STAMP = "9.9.9+testsha"

#: A static-mission map resource: the two standard files plus three custom ones.
_MISSION_FILES = {
    "VEAF_MapKey_ActionText_11000": "veaf-config.lua",
    "VEAF_MapKey_ActionText_11001": "mission-script.lua",
    "VEAF_MapKey_ActionText_11002": "early.lua",
    "VEAF_MapKey_ActionText_11003": "middle.lua",
    "VEAF_MapKey_ActionText_11004": "late.lua",
}


def _make_worker(custom_scripts: list[CustomScript] | None = None) -> MissionBuilderWorker:
    worker = make_worker(
        mission_folder=Path(tempfile.mkdtemp()),
        dev_mode=True,
        collected_community_sound_files={},
        collected_mission_data_files={},
    )
    worker.get_collected_community_script_files = lambda: []  # type: ignore[method-assign]
    worker.get_collected_veaf_script_files = lambda: []  # type: ignore[method-assign]
    worker._active_community_scripts = lambda: []  # type: ignore[method-assign]
    worker.custom_scripts = custom_scripts or []
    return worker


def _specs(worker: MissionBuilderWorker):
    with mock.patch.object(mission_builder_worker, "get_build_stamp", return_value=_STAMP):
        return worker._build_veaf_trigger_specs({}, dict(_MISSION_FILES))


def _by_comment(specs, needle: str):
    return [spec for spec in specs if needle in spec.comment]


class TestDelayParsing(unittest.TestCase):
    """`delay_seconds` in `mission.yaml`, and what an unusable value does."""

    def test_absent_is_none_not_zero(self):
        # None and 0 must stay distinguishable: 0 would be a delayed trigger firing immediately,
        # which is a different .miz from today's shared triggerStart.
        _, scripts = _parse_custom_scripts({"scripts": [{"path": "a.lua"}]})
        self.assertIsNone(scripts[0].delay_seconds)

    def test_a_plain_string_entry_still_works(self):
        _, scripts = _parse_custom_scripts({"scripts": ["a.lua"]})
        self.assertEqual([CustomScript(path="a.lua")], scripts)

    def test_a_delay_is_read(self):
        _, scripts = _parse_custom_scripts({"scripts": [{"path": "a.lua", "delay_seconds": 12}]})
        self.assertEqual(12.0, scripts[0].delay_seconds)

    def test_a_fractional_delay_is_kept(self):
        _, scripts = _parse_custom_scripts({"scripts": [{"path": "a.lua", "delay_seconds": 0.5}]})
        self.assertEqual(0.5, scripts[0].delay_seconds)

    def test_a_non_numeric_delay_is_dropped_with_a_warning(self):
        with self.assertLogs("veaf-tools", level="WARNING") as captured:
            _, scripts = _parse_custom_scripts({"scripts": [{"path": "a.lua", "delay_seconds": "soon"}]})
        self.assertIsNone(scripts[0].delay_seconds)
        self.assertIn("a.lua", " ".join(captured.output))

    def test_a_negative_delay_is_dropped_with_a_warning(self):
        with self.assertLogs("veaf-tools", level="WARNING"):
            _, scripts = _parse_custom_scripts({"scripts": [{"path": "a.lua", "delay_seconds": -3}]})
        self.assertIsNone(scripts[0].delay_seconds)

    def test_zero_is_dropped_too(self):
        # A zero delay expresses "no delay", which the absent key already says. Accepting it would
        # emit an extra trigger that fires on the first tick — same result, one more trigger.
        with self.assertLogs("veaf-tools", level="WARNING"):
            _, scripts = _parse_custom_scripts({"scripts": [{"path": "a.lua", "delay_seconds": 0}]})
        self.assertIsNone(scripts[0].delay_seconds)

    def test_a_bad_delay_does_not_lose_the_script(self):
        # The script must still load, in the shared trigger: refusing the whole entry over a bad
        # delay would silently drop a script the mission needs.
        _, scripts = _parse_custom_scripts({"scripts": [{"path": "a.lua", "delay_seconds": None}]})
        self.assertEqual(["a.lua"], [script.path for script in scripts])


class TestNoDelayChangesNothing(unittest.TestCase):
    """The regression guard that matters most: an ordinary mission's triggers are untouched."""

    def test_without_any_delay_there_is_one_static_mission_trigger(self):
        specs = _specs(_make_worker([CustomScript(path="early.lua")]))
        self.assertEqual(1, len(_by_comment(specs, "Mission scripts loading - static")))
        self.assertEqual([], [spec for spec in specs if spec.delay_seconds is not None])

    def test_all_five_files_stay_in_that_single_trigger(self):
        specs = _specs(_make_worker([CustomScript(path="early.lua")]))
        static = _by_comment(specs, "Mission scripts loading - static")[0]
        self.assertEqual(
            list(_MISSION_FILES),
            [action.map_key for action in static.actions if hasattr(action, "map_key")],
        )


class TestDelayedScriptsLeaveTheSharedTrigger(unittest.TestCase):
    """One extra trigger per distinct delay, and the shared one keeps the rest."""

    def _specs_with_two_delays(self):
        return _specs(
            _make_worker(
                [
                    CustomScript(path="early.lua"),
                    CustomScript(path="middle.lua", delay_seconds=3),
                    CustomScript(path="late.lua", delay_seconds=12),
                ]
            )
        )

    def test_two_delays_add_two_triggers(self):
        delayed = [spec for spec in self._specs_with_two_delays() if spec.delay_seconds is not None]
        self.assertEqual([3.0, 12.0], [spec.delay_seconds for spec in delayed])

    def test_the_shared_trigger_no_longer_loads_them(self):
        static = _by_comment(self._specs_with_two_delays(), "Mission scripts loading - static")[0]
        keys = [action.map_key for action in static.actions if hasattr(action, "map_key")]
        self.assertEqual(
            ["VEAF_MapKey_ActionText_11000", "VEAF_MapKey_ActionText_11001", "VEAF_MapKey_ActionText_11002"],
            keys,
        )

    def test_each_delayed_trigger_loads_only_its_own_script(self):
        delayed = [spec for spec in self._specs_with_two_delays() if spec.delay_seconds is not None]
        self.assertEqual(
            [["VEAF_MapKey_ActionText_11003"], ["VEAF_MapKey_ActionText_11004"]],
            [[action.map_key for action in spec.actions if hasattr(action, "map_key")] for spec in delayed],
        )

    def test_the_comment_says_the_delay_so_the_editor_reads_it(self):
        delayed = [spec for spec in self._specs_with_two_delays() if spec.delay_seconds is not None]
        self.assertIn("3", delayed[0].comment)
        self.assertIn("12", delayed[1].comment)

    def test_scripts_sharing_a_delay_share_one_trigger_in_declared_order(self):
        specs = _specs(
            _make_worker(
                [
                    CustomScript(path="late.lua", delay_seconds=12),
                    CustomScript(path="middle.lua", delay_seconds=12),
                ]
            )
        )
        delayed = [spec for spec in specs if spec.delay_seconds is not None]
        self.assertEqual(1, len(delayed), "one trigger per distinct delay, not per script")
        # Declaration order inside the group, which is the order of the mission-file list.
        self.assertEqual(
            ["VEAF_MapKey_ActionText_11003", "VEAF_MapKey_ActionText_11004"],
            [action.map_key for action in delayed[0].actions if hasattr(action, "map_key")],
        )

    def test_delayed_triggers_are_ordered_by_delay_not_by_declaration(self):
        specs = _specs(
            _make_worker(
                [
                    CustomScript(path="late.lua", delay_seconds=12),
                    CustomScript(path="middle.lua", delay_seconds=3),
                ]
            )
        )
        delayed = [spec for spec in specs if spec.delay_seconds is not None]
        self.assertEqual([3.0, 12.0], [spec.delay_seconds for spec in delayed])

    def test_every_delayed_trigger_gets_its_own_dictionary_key(self):
        specs = self._specs_with_two_delays()
        keys = [spec.dict_key for spec in specs]
        self.assertEqual(len(keys), len(set(keys)), f"duplicate dictionary key among {keys}")

    def test_the_dictionary_declares_a_condition_for_every_spec(self):
        worker = _make_worker(
            [CustomScript(path="middle.lua", delay_seconds=3), CustomScript(path="late.lua", delay_seconds=12)]
        )
        worker.dcs_mission = mock.MagicMock()
        worker.dcs_mission.dictionary_content = {}
        specs = _specs(worker)
        with mock.patch.object(mission_builder_worker, "get_build_stamp", return_value=_STAMP):
            declared = worker.update_dictionary_with_veaf_entries()
        missing = [spec.dict_key for spec in specs if spec.dict_key not in declared]
        self.assertEqual([], missing, "a trigger condition would read an absent dictionary entry")


class TestTheCompiledFormMatchesDcs(unittest.TestCase):
    """Asserted against an upstream `.miz`, not against what seemed reasonable."""

    def _built(self):
        worker = _make_worker([CustomScript(path="late.lua", delay_seconds=12)])
        worker.dcs_mission = mock.MagicMock()
        worker.dcs_mission.mission_content = {"trig": {"actions": {}, "conditions": {}, "funcStartup": {}}}
        specs = _specs(worker)
        worker.insert_veaf_triggers(specs)
        return specs, worker.dcs_mission.mission_content["trig"]

    def test_a_delayed_trigger_is_evaluated_continuously_not_at_startup(self):
        specs, trig = self._built()
        index = 1 + next(i for i, spec in enumerate(specs) if spec.delay_seconds is not None)
        self.assertIn(index, trig["func"], "a delayed trigger must live in func, not funcStartup")
        self.assertNotIn(index, trig["funcStartup"])

    def test_an_undelayed_trigger_still_runs_at_startup(self):
        specs, trig = self._built()
        index = 1 + next(i for i, spec in enumerate(specs) if spec.delay_seconds is None)
        self.assertIn(index, trig["funcStartup"])
        self.assertNotIn(index, trig.get("func", {}))

    def test_the_condition_carries_both_the_mode_switch_and_the_delay(self):
        specs, trig = self._built()
        index = 1 + next(i for i, spec in enumerate(specs) if spec.delay_seconds is not None)
        condition = trig["conditions"][index]
        # c_predicate is how a static trigger refuses to run in a dynamic build; dropping it
        # would make the delayed script load twice in dynamic mode.
        self.assertIn("c_predicate", condition)
        self.assertIn("c_time_after(12)", condition)

    def test_the_action_disarms_itself_so_it_fires_once(self):
        specs, trig = self._built()
        index = 1 + next(i for i, spec in enumerate(specs) if spec.delay_seconds is not None)
        self.assertTrue(
            trig["actions"][index].endswith(f" mission.trig.func[{index}]=nil;"),
            trig["actions"][index][-60:],
        )

    def test_an_undelayed_action_does_not_disarm_anything(self):
        specs, trig = self._built()
        index = 1 + next(i for i, spec in enumerate(specs) if spec.delay_seconds is None)
        self.assertNotIn("mission.trig.func", trig["actions"][index])


class TestTheEditorFormMatchesDcs(unittest.TestCase):
    """The trigrules half: what the Mission Editor shows and recompiles."""

    def _rules(self):
        worker = _make_worker([CustomScript(path="late.lua", delay_seconds=12)])
        worker.dcs_mission = mock.MagicMock()
        worker.dcs_mission.mission_content = {"trigrules": {}}
        specs = _specs(worker)
        worker.insert_veaf_trigrules(specs)
        rules = worker.dcs_mission.mission_content["trigrules"]
        delayed_index = 1 + next(i for i, spec in enumerate(specs) if spec.delay_seconds is not None)
        return rules[delayed_index], rules

    def test_a_delayed_trigrule_is_a_triggerOnce(self):
        delayed, _ = self._rules()
        self.assertEqual("triggerOnce", delayed["predicate"])

    def test_it_carries_the_time_rule_beside_the_predicate_rule(self):
        delayed, _ = self._rules()
        predicates = [rule["predicate"] for rule in delayed["rules"]]
        self.assertEqual(["c_predicate", "c_time_after"], predicates)
        self.assertEqual(12, delayed["rules"][1]["seconds"])

    def test_an_undelayed_trigrule_is_still_a_triggerStart(self):
        _, rules = self._rules()
        starts = [rule for rule in rules.values() if rule["predicate"] == "triggerStart"]
        self.assertTrue(starts)
        for rule in starts:
            self.assertEqual(["c_predicate"], [inner["predicate"] for inner in rule["rules"]])


class TestDynamicModeHonoursTheDelayToo(unittest.TestCase):
    """`generate_load_trigger` governs both modes, so a delay must not silently differ."""

    def _generated(self, custom_scripts: list[CustomScript]) -> str:
        folder = Path(tempfile.mkdtemp())
        worker = _make_worker(custom_scripts)
        worker.mission_folder = folder
        worker._ordered_mission_script_names = lambda: [  # type: ignore[method-assign]
            "veaf-config.lua",
            "mission-script.lua",
            "late.lua",
        ]
        worker.generate_veaf_dynamic_config()
        return (folder / "src" / "scripts" / "veafDynamicConfig.lua").read_text(encoding="utf-8")

    def test_without_a_delay_no_script_carries_one(self):
        # The `if script.delay then` branch is emitted unconditionally — one generator, not a
        # conditional variant of it. What matters is that no entry carries a delay, so the branch
        # is never taken; asserting the absence of `scheduleFunction` would assert the shape of the
        # loop instead of the behaviour of the mission.
        content = self._generated([CustomScript(path="late.lua")])
        self.assertNotIn("delay =", content)

    def test_a_delayed_script_declares_its_delay(self):
        content = self._generated([CustomScript(path="late.lua", delay_seconds=12)])
        self.assertIn('{ name = "late.lua", delay = 12 }', content)
        self.assertIn("timer.scheduleFunction", content)

    def test_the_undelayed_scripts_carry_no_delay(self):
        content = self._generated([CustomScript(path="late.lua", delay_seconds=12)])
        self.assertIn('{ name = "veaf-config.lua" },', content)
        self.assertIn('{ name = "mission-script.lua" },', content)

    def test_a_fractional_delay_is_emitted_readably(self):
        content = self._generated([CustomScript(path="late.lua", delay_seconds=0.5)])
        self.assertIn("delay = 0.5", content)


if __name__ == "__main__":
    unittest.main()
