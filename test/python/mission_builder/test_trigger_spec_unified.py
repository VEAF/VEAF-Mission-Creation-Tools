"""CUSTOM-SCRIPTS-TRIGGERS: the trig and trigrules forms derive from one source.

A VEAF load trigger is written into the ``.miz`` twice: the DCS ``trig`` table
(the compiled ``funcStartup`` form executed at runtime) and the ``trigrules``
table (the Mission Editor form). They used to be hand-built separately and
drifted — the static-mission ``trig`` form loaded the full ordered mission-script
list (honouring ``custom_scripts``) while the static-mission ``trigrules`` form
loaded only ``veaf-config.lua`` + ``mission-script.lua``. Re-saving the mission in
the ME recompiled the trigrules into ``trig`` and silently dropped custom scripts.

Both forms are now derived from a single ordered ``list[VeafTriggerSpec]`` via two
emitters, so they can never reference a different set of scripts.
"""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from mission_builder.mission_builder_worker import (
    _VEAF_TRIGGER_DICT_KEYS,
    FileAction,
    LuaAction,
    MissionBuilderWorker,
    _emit_trig_action_string,
    _emit_trigrule_actions,
)

#: Dictionary key of the static-mission trigger (#6) — a stable identifier, unlike the
#: human-facing ``comment``.
_STATIC_MISSION_DICT_KEY = _VEAF_TRIGGER_DICT_KEYS[5]


def _make_worker() -> MissionBuilderWorker:
    worker: MissionBuilderWorker = object.__new__(MissionBuilderWorker)
    worker.mission_folder = Path(tempfile.mkdtemp())
    worker.output_mission = worker.mission_folder / "out.miz"
    worker.scripts_path = None
    worker.dev_mode = True
    worker.get_collected_community_script_files = lambda: []  # type: ignore[method-assign]
    worker.get_collected_veaf_script_files = lambda: []  # type: ignore[method-assign]
    worker._active_community_scripts = lambda: []  # type: ignore[method-assign]
    return worker


#: A static-mission map resource with a custom script alongside the standard files.
_MISSION_FILES = {
    "VEAF_MapKey_ActionText_11000": "veaf-config.lua",
    "VEAF_MapKey_ActionText_11001": "mission-script.lua",
    "VEAF_MapKey_ActionText_11002": "my-custom-script.lua",
}
_SCRIPT_FILES = {
    "VEAF_MapKey_ActionText_10000": "veaf-scripts.lua",
}


class TestTriggerSpecUnified(unittest.TestCase):
    def _static_mission_spec(self, worker: MissionBuilderWorker):
        specs = worker._build_veaf_trigger_specs(_SCRIPT_FILES, _MISSION_FILES)
        return next(s for s in specs if s.dict_key == _STATIC_MISSION_DICT_KEY)

    def test_static_mission_spec_carries_every_mission_script(self) -> None:
        """spec for static mission loading references all mission scripts, incl. custom."""
        worker = _make_worker()
        spec = self._static_mission_spec(worker)
        file_keys = [a.map_key for a in spec.actions if isinstance(a, FileAction)]
        self.assertEqual(file_keys, list(_MISSION_FILES))

    def test_both_emitters_reference_the_same_scripts(self) -> None:
        """The trig string and the trigrules action dicts load the identical set."""
        worker = _make_worker()
        spec = self._static_mission_spec(worker)

        trig_string = _emit_trig_action_string(spec.actions)
        trigrule_actions = _emit_trigrule_actions(spec.actions)

        trigrule_files = [a["file"] for a in trigrule_actions if a.get("predicate") == "a_do_script_file"]
        self.assertEqual(trigrule_files, list(_MISSION_FILES))
        # Every map key present in the editor form must also be in the compiled form.
        for map_key in _MISSION_FILES:
            self.assertIn(map_key, trig_string)


class TestTriggerGoldenBytes(unittest.TestCase):
    """Byte-identity golden of the emitted forms — locks escaping and the meters/zone drop.

    These reproduce exactly what the pre-refactor hand-built code emitted (minus the
    intentionally-dropped editor-only ``meters``/``zone`` fields), so a future edit that
    silently changes the on-disk Lua is caught.
    """

    def _specs(self):
        worker = _make_worker()
        worker._active_community_scripts = lambda: [{"path": "src/scripts/community/mist.lua"}]  # type: ignore[method-assign]
        return worker._build_veaf_trigger_specs(_SCRIPT_FILES, _MISSION_FILES)

    def test_trig_action_strings_golden(self) -> None:
        specs = self._specs()
        # #1 / #2 — path-setting (the [[…]] literal embeds a temp path, so assert the wrapping)
        self.assertEqual(_emit_trig_action_string(specs[0].actions), f'a_do_script("{specs[0].actions[0].lua}");')
        self.assertTrue(specs[0].actions[0].lua.startswith("VEAF_DYNAMIC_SCRIPTSPATH = [["))
        self.assertEqual(_emit_trig_action_string(specs[1].actions), f'a_do_script("{specs[1].actions[0].lua}");')
        # #3 — VEAF scripts dynamic (escaped quotes, community + dev framework loader)
        self.assertEqual(
            _emit_trig_action_string(specs[2].actions),
            'a_do_script("env.info(\\"DYNAMIC VEAF scripts loading from \\"..VEAF_DYNAMIC_SCRIPTSPATH)");'
            'a_do_script("assert(loadfile(VEAF_DYNAMIC_SCRIPTSPATH .. \\"src/scripts/community/mist.lua\\"))()");'
            'a_do_script("assert(loadfile(VEAF_DYNAMIC_SCRIPTSPATH .. \\"/src/scripts/VeafDynamicLoader.lua\\"))()");',
        )
        # #4 — VEAF scripts static (mapResource file loads)
        self.assertEqual(
            _emit_trig_action_string(specs[3].actions),
            'a_do_script("env.info(\\"STATIC VEAF scripts loading\\")");'
            'a_do_script_file(getValueResourceByKey("VEAF_MapKey_ActionText_10000"));',
        )
        # #5 — Mission scripts dynamic
        self.assertEqual(
            _emit_trig_action_string(specs[4].actions),
            'a_do_script("env.info(\\"DYNAMIC Mission scripts loading from \\"..VEAF_DYNAMIC_MISSIONPATH)");'
            'a_do_script("assert(loadfile(VEAF_DYNAMIC_MISSIONPATH .. \\"/src/scripts/veafDynamicConfig.lua\\"))()");',
        )
        # #6 — Mission scripts static (full ordered list, incl. custom)
        self.assertEqual(
            _emit_trig_action_string(specs[5].actions),
            'a_do_script("env.info(\\"STATIC Mission scripts loading\\")");'
            'a_do_script_file(getValueResourceByKey("VEAF_MapKey_ActionText_11000"));'
            'a_do_script_file(getValueResourceByKey("VEAF_MapKey_ActionText_11001"));'
            'a_do_script_file(getValueResourceByKey("VEAF_MapKey_ActionText_11002"));',
        )

    def test_trigrule_actions_golden(self) -> None:
        specs = self._specs()
        # #5 — Mission scripts dynamic: no meters/zone leftovers (dropped by decision)
        self.assertEqual(
            _emit_trigrule_actions(specs[4].actions),
            [
                {
                    "predicate": "a_do_script",
                    "text": 'env.info("DYNAMIC Mission scripts loading from "..VEAF_DYNAMIC_MISSIONPATH)',
                },
                {
                    "predicate": "a_do_script",
                    "text": 'assert(loadfile(VEAF_DYNAMIC_MISSIONPATH .. "/src/scripts/veafDynamicConfig.lua"))()',
                },
            ],
        )
        # #6 — Mission scripts static: env.info then one file load per mission script
        self.assertEqual(
            _emit_trigrule_actions(specs[5].actions),
            [
                {"predicate": "a_do_script", "text": 'env.info("STATIC Mission scripts loading")'},
                {"predicate": "a_do_script_file", "file": "VEAF_MapKey_ActionText_11000"},
                {"predicate": "a_do_script_file", "file": "VEAF_MapKey_ActionText_11001"},
                {"predicate": "a_do_script_file", "file": "VEAF_MapKey_ActionText_11002"},
            ],
        )

    def test_path_actions_are_lua_not_file(self) -> None:
        """The two path-setting triggers are raw Lua, never file loads."""
        specs = self._specs()
        self.assertIsInstance(specs[0].actions[0], LuaAction)
        self.assertIsInstance(specs[1].actions[0], LuaAction)
        self.assertTrue(specs[1].actions[0].lua.startswith("VEAF_DYNAMIC_MISSIONPATH = [["))


if __name__ == "__main__":
    unittest.main()
