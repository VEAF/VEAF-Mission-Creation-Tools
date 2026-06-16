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
    FileAction,
    MissionBuilderWorker,
    _emit_trig_action_string,
    _emit_trigrule_actions,
)


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
        return next(s for s in specs if s.comment == "Mission scripts loading - static")

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


if __name__ == "__main__":
    unittest.main()
