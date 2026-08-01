"""FEAT-ASSIST-CHECKLISTS: the activated checklists reach the .miz, and nothing else does.

A checklist costs one embedded picture per step, so what the build activates has to be
exactly what the mission asked for — and a mission that asks for none must pay nothing.
"""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

import yaml
from mission_builder.mission_builder_worker import MissionBuilderWorker
from veaf_libs.checklists import CHECKLISTS_FOLDER_NAME

_MIZ_FOLDER = "l10n/DEFAULT"

_CHECKLIST = {
    "id": "mission-own",
    "title": "assist.test.title",
    "aircraft": ["F-16C_50"],
    "menu": "cold-start",
    "steps": [
        {"label": "step.one", "element": "PTR-ELEC-TMB-MPWR-510", "argument": 510, "equals": 1.0},
        {"label": "step.two", "element": "PTR-X", "confirm": True},
    ],
}


def _make_worker(with_mission_checklist: bool = True) -> MissionBuilderWorker:
    worker: MissionBuilderWorker = object.__new__(MissionBuilderWorker)
    worker.mission_folder = Path(tempfile.mkdtemp())
    worker.output_mission = worker.mission_folder / "out.miz"
    worker.scripts_path = None
    worker.dev_mode = True
    worker.checklist_images = []
    if with_mission_checklist:
        folder = worker.mission_folder / CHECKLISTS_FOLDER_NAME
        folder.mkdir(parents=True)
        (folder / "mine.yaml").write_text(yaml.safe_dump(_CHECKLIST, sort_keys=False), encoding="utf-8")
    return worker


def _yaml(assist: object) -> dict:
    return {"lua_modules": {"ASSIST": assist}} if assist is not None else {"lua_modules": {}}


class TestActivation(unittest.TestCase):
    """Which checklists a build resolves, from the module block alone."""

    def test_module_absent_activates_nothing(self):
        worker = _make_worker()
        self.assertEqual([], worker._resolve_checklists(_yaml(None)))
        self.assertEqual([], worker.checklist_images)

    def test_module_disabled_activates_nothing(self):
        worker = _make_worker()
        self.assertEqual([], worker._resolve_checklists(_yaml({"enabled": False})))

    def test_enabled_without_a_list_activates_the_missions_own_folder(self):
        worker = _make_worker()
        selected = worker._resolve_checklists(_yaml({"enabled": True}))
        self.assertEqual(["mission-own"], [entry.id for entry in selected])

    def test_enabled_with_no_mission_folder_activates_nothing(self):
        worker = _make_worker(with_mission_checklist=False)
        self.assertEqual([], worker._resolve_checklists(_yaml({"enabled": True})))
        self.assertEqual([], worker.checklist_images)

    def test_the_shipped_catalogue_can_be_activated_by_id(self):
        worker = _make_worker(with_mission_checklist=False)
        selected = worker._resolve_checklists(_yaml({"enabled": True, "checklists": ["f16c-cold-start"]}))
        self.assertEqual(["f16c-cold-start"], [entry.id for entry in selected])


class TestImageResources(unittest.TestCase):
    """The rendered pictures, and the keys DCS resolves them through."""

    def test_images_are_rendered_for_every_state(self):
        worker = _make_worker()
        worker._resolve_checklists(_yaml({"enabled": True}))
        self.assertEqual(1, len(worker.checklist_images))
        # Two steps -> three states.
        self.assertEqual(3, len(worker.checklist_images[0].files))

    def test_resource_keys_map_to_the_embedded_file_names(self):
        worker = _make_worker()
        worker._resolve_checklists(_yaml({"enabled": True}))
        resources = worker._checklist_resources()
        self.assertEqual(3, len(resources))
        self.assertEqual(set(worker.checklist_images[0].files), set(resources.values()))
        for key in resources:
            self.assertTrue(key.startswith("VEAF_MapKey_Assist_"))

    def test_no_resources_when_nothing_is_activated(self):
        worker = _make_worker(with_mission_checklist=False)
        worker._resolve_checklists(_yaml({"enabled": True}))
        self.assertEqual({}, worker._checklist_resources())


class TestGeneratedLua(unittest.TestCase):
    """What the engine reads at runtime."""

    def _config_lua(self, assist: object) -> str:
        from veaf_libs.lua_config_generator import generate_config_lua

        worker = _make_worker()
        yaml_dict = _yaml(assist)
        checklists = worker._resolve_checklists(yaml_dict)
        image_keys = {entry.checklist_id: entry.resource_keys for entry in worker.checklist_images}
        return generate_config_lua(yaml_dict, checklists=checklists, checklist_images=image_keys)

    def test_the_checklist_is_registered_with_its_images(self):
        lua = self._config_lua({"enabled": True})
        self.assertIn("veafAssist.registerChecklist({", lua)
        self.assertIn('id = "mission-own"', lua)
        self.assertIn("images = {", lua)
        self.assertIn('type = "argument"', lua)
        self.assertIn('type = "confirm"', lua)

    def test_nothing_is_registered_when_the_module_is_off(self):
        self.assertNotIn("registerChecklist", self._config_lua({"enabled": False}))

    def test_the_checklists_list_is_not_emitted_as_a_runtime_setting(self):
        # It selects what the build embeds; the engine only ever sees what was emitted.
        lua = self._config_lua({"enabled": True, "checklists": ["mission-own"]})
        self.assertNotIn('"checklists"', lua)


if __name__ == "__main__":
    unittest.main()
