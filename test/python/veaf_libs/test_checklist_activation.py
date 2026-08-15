"""Tests for which checklists a mission activates, and the build plumbing behind it."""

import unittest
from pathlib import Path
from tempfile import TemporaryDirectory

import yaml
from veaf_libs.checklist_images import render_checklist_images
from veaf_libs.checklists import (
    CHECKLISTS_FOLDER_NAME,
    ChecklistError,
    load_checklists,
    load_mission_checklists,
    parse_checklist,
    select_activated,
)
from veaf_libs.lua_config_generator import enabled_module_config

CATALOGUE_ENTRY = {
    "id": "f16c-cold-start",
    "title": "assist.f16c.coldstart.title",
    "aircraft": ["F-16C_50"],
    "menu": "cold-start",
    "steps": [{"label": "l", "element": "PTR-X", "confirm": True}],
}


def _write(folder: Path, name: str, raw: dict) -> None:
    folder.mkdir(parents=True, exist_ok=True)
    (folder / name).write_text(yaml.safe_dump(raw, sort_keys=False), encoding="utf-8")


def _available(*raw: dict) -> dict:
    return {entry["id"]: parse_checklist(entry, source="test.yaml") for entry in raw}


class TestSelection(unittest.TestCase):
    """The activation rule: explicit list wins, else the mission's own folder."""

    def test_explicit_list_wins(self):
        available = _available(CATALOGUE_ENTRY, {**CATALOGUE_ENTRY, "id": "other"})
        selected = select_activated(available, ["other"], mission_ids=["f16c-cold-start"])
        self.assertEqual(["other"], [entry.id for entry in selected])

    def test_no_list_activates_the_missions_own_folder(self):
        available = _available(CATALOGUE_ENTRY, {**CATALOGUE_ENTRY, "id": "mine"})
        selected = select_activated(available, None, mission_ids=["mine"])
        self.assertEqual(["mine"], [entry.id for entry in selected])

    def test_no_list_and_no_mission_folder_activates_nothing(self):
        available = _available(CATALOGUE_ENTRY)
        self.assertEqual([], select_activated(available, None, mission_ids=[]))

    def test_the_whole_catalogue_is_never_activated_by_default(self):
        available = _available(CATALOGUE_ENTRY, {**CATALOGUE_ENTRY, "id": "second"})
        self.assertEqual([], select_activated(available, None))

    def test_empty_list_activates_nothing(self):
        available = _available(CATALOGUE_ENTRY)
        self.assertEqual([], select_activated(available, [], mission_ids=["f16c-cold-start"]))

    def test_unknown_id_is_a_build_error(self):
        available = _available(CATALOGUE_ENTRY)
        with self.assertRaises(ChecklistError) as ctx:
            select_activated(available, ["typo-id"])
        self.assertIn("typo-id", str(ctx.exception))
        self.assertIn("f16c-cold-start", str(ctx.exception))

    def test_selection_is_sorted_by_id(self):
        available = _available(
            {**CATALOGUE_ENTRY, "id": "zulu"},
            {**CATALOGUE_ENTRY, "id": "alpha"},
        )
        selected = select_activated(available, ["zulu", "alpha"])
        self.assertEqual(["alpha", "zulu"], [entry.id for entry in selected])


class TestMissionFolderLoading(unittest.TestCase):
    """Reading the mission's own checklists/ folder."""

    def test_only_the_missions_own_folder_is_read(self):
        with TemporaryDirectory() as tmp:
            root = Path(tmp)
            _write(root / "catalogue", "cold.yaml", CATALOGUE_ENTRY)
            _write(root / "mission" / CHECKLISTS_FOLDER_NAME, "mine.yaml", {**CATALOGUE_ENTRY, "id": "mine"})

            self.assertEqual({"mine"}, set(load_mission_checklists(root / "mission")))
            self.assertEqual(
                {"mine", "f16c-cold-start"},
                set(load_checklists(mission_folder=root / "mission", catalogue_dir=root / "catalogue")),
            )

    def test_a_mission_without_the_folder_loads_nothing(self):
        with TemporaryDirectory() as tmp:
            self.assertEqual({}, load_mission_checklists(Path(tmp)))


class TestModuleConfig(unittest.TestCase):
    """`enabled_module_config` — every shape a mission may write for a module."""

    def test_absent_module_is_none(self):
        self.assertIsNone(enabled_module_config({"lua_modules": {}}, "ASSIST"))

    def test_shorthand_true(self):
        self.assertEqual({"enabled": True}, enabled_module_config({"lua_modules": {"ASSIST": True}}, "ASSIST"))

    def test_null_value_is_enabled(self):
        self.assertEqual({}, enabled_module_config({"lua_modules": {"ASSIST": None}}, "ASSIST"))

    def test_block_with_settings(self):
        config = enabled_module_config(
            {"lua_modules": {"ASSIST": {"enabled": True, "checklists": ["a"]}}},
            "ASSIST",
        )
        self.assertEqual(["a"], (config or {}).get("checklists"))

    def test_disabled_module_is_none(self):
        self.assertIsNone(enabled_module_config({"lua_modules": {"ASSIST": {"enabled": False}}}, "ASSIST"))
        self.assertIsNone(enabled_module_config({"lua_modules": {"ASSIST": False}}, "ASSIST"))


class TestResourceMapping(unittest.TestCase):
    """Resource key → embedded file name, the pairing the .miz depends on."""

    def _images(self, step_count: int):
        checklist = parse_checklist(
            {
                **CATALOGUE_ENTRY,
                "steps": [{"label": f"l{i}", "element": "PTR-X", "confirm": True} for i in range(step_count)],
            },
            source="test.yaml",
        )
        return render_checklist_images(checklist, {}, "en")

    def test_every_state_maps_to_its_own_file(self):
        images = self._images(3)
        resources = images.resources()
        self.assertEqual(4, len(resources))
        self.assertEqual(set(images.files), set(resources.values()))

    def test_state_ten_is_not_paired_with_state_one(self):
        # Sorting file names lexicographically would put state 10 between states 1 and 2 and
        # mis-pair every state of a long checklist.
        #
        # Asserted on the state prefix rather than the whole name: the name now ends in a digest
        # of its own bytes (FEAT-ASSIST-FOLLOWUP ticket 01), and pinning that here would make this
        # test fail whenever the *rendering* changes, which is not what it is about.
        images = self._images(12)
        resources = images.resources()
        self.assertTrue(resources[images.resource_keys[10]].startswith("assist-f16c-cold-start-10-"))
        self.assertTrue(resources[images.resource_keys[1]].startswith("assist-f16c-cold-start-1-"))


if __name__ == "__main__":
    unittest.main()
