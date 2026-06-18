"""Tests for native load-trigger stripping at build (FOOTHOLD-V6-003)."""

import unittest
from pathlib import Path

from mission_builder.mission_builder_worker import strip_native_load_triggers
from mission_tools.miz_tools import DcsMission


def _mission(trigrules: dict, trig: dict, mapres: dict) -> DcsMission:
    return DcsMission(
        file_path=Path("x.miz"),
        mission_content={"trigrules": trigrules, "trig": trig},
        map_resource_content=mapres,
    )


class TestStripNativeLoadTriggers(unittest.TestCase):
    def test_removes_matching_trigrule_trig_and_mapresource(self) -> None:
        trigrules = {
            1: {"comment": "ScriptLoader 1", "actions": {1: {"predicate": "a_do_script_file", "file": "K1"}}},
            2: {"comment": "Mission start", "actions": {1: {"predicate": "a_do_script", "text": "x"}}},
        }
        trig = {"actions": {1: "do_script_file(...)", 2: "other"}, "funcStartup": {1: "a", 2: "b"}}
        mapres = {"K1": "Moose.lua", "Snd": "beacon.ogg"}

        strip_native_load_triggers(_mission(trigrules, trig, mapres), ["ScriptLoader 1"])

        # The function mutates in place; re-read from the same objects.
        self.assertNotIn(1, trigrules)
        self.assertIn(2, trigrules)
        self.assertNotIn(1, trig["actions"])
        self.assertIn(2, trig["actions"])
        self.assertNotIn(1, trig["funcStartup"])
        self.assertNotIn("K1", mapres)
        self.assertIn("Snd", mapres)

    def test_glob_pattern_matches_multiple(self) -> None:
        trigrules = {
            1: {"comment": "ScriptLoader 1", "actions": {}},
            2: {"comment": "ScriptLoader 2", "actions": {}},
            3: {"comment": "Keep me", "actions": {}},
        }
        strip_native_load_triggers(_mission(trigrules, {}, {}), ["ScriptLoader *"])

        self.assertEqual(set(trigrules.keys()), {3})

    def test_no_labels_is_noop(self) -> None:
        trigrules = {1: {"comment": "ScriptLoader 1", "actions": {}}}
        strip_native_load_triggers(_mission(trigrules, {}, {}), [])

        self.assertIn(1, trigrules)

    def test_list_form_actions_supported(self) -> None:
        trigrules = {1: {"comment": "AIEN", "actions": [{"predicate": "a_do_script_file", "file": "K"}]}}
        mapres = {"K": "AIEN.lua"}
        strip_native_load_triggers(_mission(trigrules, {}, mapres), ["AIEN"])

        self.assertEqual(trigrules, {})
        self.assertNotIn("K", mapres)


if __name__ == "__main__":
    unittest.main()
