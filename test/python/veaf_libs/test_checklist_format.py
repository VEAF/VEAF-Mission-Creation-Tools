"""Tests for the guided-checklist YAML format: model, loader and Lua emission."""

import unittest
from pathlib import Path
from tempfile import TemporaryDirectory

from veaf_libs.checklists import (
    CHECKLISTS_FOLDER_NAME,
    ChecklistError,
    load_checklists,
    parse_checklist,
    resolve_text,
)
from veaf_libs.lua_config_generator import generate_config_lua

VALID_CHECKLIST = {
    "id": "f16c-cold-start",
    "title": "assist.f16c.coldstart.title",
    "aircraft": ["F-16C_50"],
    "menu": "cold-start",
    "steps": [
        {
            "label": "assist.gear_down",
            "element": "PTR-ELEC-TMB-MPWR-510",
            "param": "BASE_SENSOR_NOSE_GEAR_DOWN",
            "equals": 1.0,
            "tolerance": 0.05,
        },
        {
            "label": "assist.f16c.check_hyd",
            "element": "PTR-HYDCP-IND-3018",
            "confirm": True,
        },
    ],
}


def _with_steps(*steps: dict) -> dict:
    """Return a valid checklist whose steps are replaced by *steps*."""
    return {**VALID_CHECKLIST, "steps": list(steps)}


def _write(folder: Path, name: str, raw: dict) -> None:
    """Write *raw* as a YAML checklist file named *name* under *folder*."""
    import yaml

    folder.mkdir(parents=True, exist_ok=True)
    (folder / name).write_text(yaml.safe_dump(raw, sort_keys=False), encoding="utf-8")


class TestChecklistModel(unittest.TestCase):
    """Validation rules of a single checklist definition."""

    def test_valid_checklist_parses(self):
        checklist = parse_checklist(VALID_CHECKLIST, source="test.yaml")
        self.assertEqual("f16c-cold-start", checklist.id)
        self.assertEqual(["F-16C_50"], checklist.aircraft)
        self.assertEqual(2, len(checklist.steps))

    def test_param_step_resolves_its_window(self):
        checklist = parse_checklist(VALID_CHECKLIST, source="test.yaml")
        self.assertEqual(
            {"type": "cockpit_param", "param": "BASE_SENSOR_NOSE_GEAR_DOWN", "min": 0.95, "max": 1.05},
            checklist.steps[0].check_table(),
        )

    def test_step_without_validation_mode_is_a_confirm_step(self):
        checklist = parse_checklist(
            _with_steps({"label": "assist.check", "element": "PTR-X"}),
            source="test.yaml",
        )
        self.assertEqual({"type": "confirm"}, checklist.steps[0].check_table())

    def test_range_window_is_used_as_is(self):
        checklist = parse_checklist(
            _with_steps({"label": "l", "param": "BASE_SENSOR_IAS", "range": [120.0, 180.0]}),
            source="test.yaml",
        )
        self.assertEqual(
            {"type": "cockpit_param", "param": "BASE_SENSOR_IAS", "min": 120.0, "max": 180.0},
            checklist.steps[0].check_table(),
        )

    def test_default_tolerance_applies_when_omitted(self):
        checklist = parse_checklist(
            _with_steps({"label": "l", "param": "BASE_SENSOR_FLAPS_RETRACTED", "equals": 0.5}),
            source="test.yaml",
        )
        self.assertEqual(
            {"type": "cockpit_param", "param": "BASE_SENSOR_FLAPS_RETRACTED", "min": 0.45, "max": 0.55},
            checklist.steps[0].check_table(),
        )

    def test_named_check_is_carried_through(self):
        checklist = parse_checklist(
            _with_steps({"label": "l", "check": {"type": "altitude_above", "value": 15000, "unit": "feet"}}),
            source="test.yaml",
        )
        self.assertEqual(
            {"type": "altitude_above", "value": 15000, "unit": "feet"},
            checklist.steps[0].check_table(),
        )

    def test_device_and_command_are_carried(self):
        checklist = parse_checklist(
            _with_steps({"label": "l", "element": "PTR-X", "device": 3, "command": 3001}),
            source="test.yaml",
        )
        self.assertEqual(3, checklist.steps[0].device)
        self.assertEqual(3001, checklist.steps[0].command)


class TestInlineTranslations(unittest.TestCase):
    """A mission maker writes their own labels, in as many languages as they want."""

    def _step(self, label: object) -> dict:
        return {**VALID_CHECKLIST, "steps": [{"label": label, "element": "PTR-X", "confirm": True}]}

    def test_a_mapping_is_accepted_for_a_label(self):
        checklist = parse_checklist(self._step({"fr": "Batterie", "en": "Battery"}), source="test.yaml")
        self.assertEqual({"fr": "Batterie", "en": "Battery"}, checklist.steps[0].label)

    def test_a_mapping_is_accepted_for_a_title(self):
        checklist = parse_checklist(
            {**VALID_CHECKLIST, "title": {"fr": "Démarrage", "en": "Start-up"}}, source="test.yaml"
        )
        self.assertEqual("Démarrage", resolve_text(checklist.title, {}, "fr"))

    def test_it_resolves_to_the_missions_language(self):
        self.assertEqual("Battery", resolve_text({"fr": "Batterie", "en": "Battery"}, {}, "en"))
        self.assertEqual("Batterie", resolve_text({"fr": "Batterie", "en": "Battery"}, {}, "fr"))

    def test_it_falls_back_to_french_then_to_anything(self):
        self.assertEqual("Batterie", resolve_text({"fr": "Batterie"}, {}, "de"))
        # A label in the wrong language beats no label at all.
        self.assertEqual("Battery", resolve_text({"en": "Battery"}, {}, "de"))

    def test_a_string_still_goes_through_the_catalog(self):
        catalog = {"my.key": {"fr": "Depuis le catalogue", "en": "From the catalog"}}
        self.assertEqual("From the catalog", resolve_text("my.key", catalog, "en"))
        self.assertEqual("plain text", resolve_text("plain text", catalog, "en"))

    def test_an_empty_mapping_is_rejected(self):
        with self.assertRaises(ChecklistError) as ctx:
            parse_checklist(self._step({}), source="bad.yaml")
        self.assertIn("label", str(ctx.exception))

    def test_a_blank_translation_is_rejected(self):
        with self.assertRaises(ChecklistError) as ctx:
            parse_checklist(self._step({"fr": "Batterie", "en": "  "}), source="bad.yaml")
        self.assertIn("en", str(ctx.exception))

    def test_an_empty_string_label_is_rejected(self):
        with self.assertRaises(ChecklistError):
            parse_checklist(self._step(""), source="bad.yaml")


class TestChecklistRejections(unittest.TestCase):
    """Every rejection rule produces a readable error naming the source file."""

    def _assert_rejected(self, raw: dict, *expected_fragments: str) -> None:
        with self.assertRaises(ChecklistError) as ctx:
            parse_checklist(raw, source="bad.yaml")
        message = str(ctx.exception)
        self.assertIn("bad.yaml", message)
        for fragment in expected_fragments:
            self.assertIn(fragment, message)

    def test_missing_id_is_rejected(self):
        raw = {k: v for k, v in VALID_CHECKLIST.items() if k != "id"}
        self._assert_rejected(raw, "id")

    def test_missing_title_is_rejected(self):
        raw = {k: v for k, v in VALID_CHECKLIST.items() if k != "title"}
        self._assert_rejected(raw, "title")

    def test_missing_menu_is_rejected(self):
        raw = {k: v for k, v in VALID_CHECKLIST.items() if k != "menu"}
        self._assert_rejected(raw, "menu")

    def test_empty_steps_is_rejected(self):
        self._assert_rejected({**VALID_CHECKLIST, "steps": []}, "steps")

    def test_empty_aircraft_is_rejected(self):
        self._assert_rejected({**VALID_CHECKLIST, "aircraft": []}, "aircraft")

    def test_unknown_aircraft_type_is_rejected(self):
        self._assert_rejected({**VALID_CHECKLIST, "aircraft": ["F-16C_51"]}, "F-16C_51")

    def test_param_and_check_together_are_rejected(self):
        self._assert_rejected(
            _with_steps({"label": "l", "param": "P", "equals": 1.0, "check": {"type": "x"}}),
            "param",
            "check",
        )

    def test_the_argument_field_is_rejected_with_an_explanation(self):
        # A cockpit control's position is unreadable from the mission environment, so a
        # step written this way would never tick. It must fail loudly, not silently.
        self._assert_rejected(
            _with_steps({"label": "l", "argument": 510, "equals": 1.0}),
            "argument",
            "confirm",
            "param",
        )

    def test_confirm_with_param_is_rejected(self):
        self._assert_rejected(
            _with_steps({"label": "l", "param": "P", "equals": 1.0, "confirm": True}),
            "confirm",
        )

    def test_tolerance_without_equals_is_rejected(self):
        self._assert_rejected(
            _with_steps({"label": "l", "param": "P", "range": [0.0, 1.0], "tolerance": 0.05}),
            "tolerance",
        )

    def test_equals_and_range_together_are_rejected(self):
        self._assert_rejected(
            _with_steps({"label": "l", "param": "P", "equals": 1.0, "range": [0.0, 1.0]}),
            "range",
        )

    def test_equals_without_param_is_rejected(self):
        self._assert_rejected(_with_steps({"label": "l", "equals": 1.0}), "equals")

    def test_param_without_window_is_rejected(self):
        self._assert_rejected(_with_steps({"label": "l", "param": "P"}), "param")

    def test_inverted_range_is_rejected(self):
        self._assert_rejected(
            _with_steps({"label": "l", "param": "P", "range": [1.0, 0.0]}),
            "range",
        )

    def test_bare_step_without_element_or_mode_is_rejected(self):
        self._assert_rejected(_with_steps({"label": "l"}), "element")

    def test_named_check_without_type_is_rejected(self):
        self._assert_rejected(_with_steps({"label": "l", "check": {"value": 1}}), "type")

    def test_unknown_field_is_rejected(self):
        self._assert_rejected({**VALID_CHECKLIST, "aircrafts": ["F-16C_50"]}, "aircrafts")


class TestChecklistLoading(unittest.TestCase):
    """Catalogue + mission-folder resolution."""

    def test_mission_folder_overrides_catalogue_by_id(self):
        with TemporaryDirectory() as tmp:
            root = Path(tmp)
            catalogue = root / "catalogue"
            mission = root / "mission"
            _write(catalogue, "cold.yaml", VALID_CHECKLIST)
            _write(
                mission / CHECKLISTS_FOLDER_NAME,
                "mine.yaml",
                {**VALID_CHECKLIST, "title": "mine"},
            )

            loaded = load_checklists(mission_folder=mission, catalogue_dir=catalogue)

            self.assertEqual(["f16c-cold-start"], list(loaded))
            self.assertEqual("mine", loaded["f16c-cold-start"].title)

    def test_catalogue_entry_kept_when_mission_adds_another(self):
        with TemporaryDirectory() as tmp:
            root = Path(tmp)
            catalogue = root / "catalogue"
            mission = root / "mission"
            _write(catalogue, "cold.yaml", VALID_CHECKLIST)
            _write(
                mission / CHECKLISTS_FOLDER_NAME,
                "other.yaml",
                {**VALID_CHECKLIST, "id": "f16c-shutdown"},
            )

            loaded = load_checklists(mission_folder=mission, catalogue_dir=catalogue)

            self.assertEqual({"f16c-cold-start", "f16c-shutdown"}, set(loaded))

    def test_duplicate_id_within_one_folder_is_rejected(self):
        with TemporaryDirectory() as tmp:
            catalogue = Path(tmp) / "catalogue"
            _write(catalogue, "a.yaml", VALID_CHECKLIST)
            _write(catalogue, "b.yaml", VALID_CHECKLIST)

            with self.assertRaises(ChecklistError) as ctx:
                load_checklists(mission_folder=None, catalogue_dir=catalogue)
            self.assertIn("f16c-cold-start", str(ctx.exception))

    def test_missing_folders_load_nothing(self):
        with TemporaryDirectory() as tmp:
            root = Path(tmp)
            self.assertEqual({}, load_checklists(mission_folder=root / "nope", catalogue_dir=root / "none"))

    def test_bad_file_names_its_source(self):
        with TemporaryDirectory() as tmp:
            catalogue = Path(tmp) / "catalogue"
            _write(catalogue, "broken.yaml", {**VALID_CHECKLIST, "steps": []})

            with self.assertRaises(ChecklistError) as ctx:
                load_checklists(mission_folder=None, catalogue_dir=catalogue)
            self.assertIn("broken.yaml", str(ctx.exception))


class TestChecklistEmission(unittest.TestCase):
    """The Lua the engine consumes."""

    def _emit(self, *raw: dict) -> str:
        checklists = [parse_checklist(entry, source="test.yaml") for entry in raw]
        return generate_config_lua({"lua_modules": {"ASSIST": {}}}, checklists=checklists)

    def test_one_register_call_per_checklist(self):
        lua = self._emit(VALID_CHECKLIST, {**VALID_CHECKLIST, "id": "second"})
        self.assertEqual(2, lua.count("veafAssist.registerChecklist("))
        self.assertIn('id = "f16c-cold-start"', lua)
        self.assertIn('id = "second"', lua)

    def test_emitted_step_carries_element_and_window(self):
        lua = self._emit(VALID_CHECKLIST)
        self.assertIn('element = "PTR-ELEC-TMB-MPWR-510"', lua)
        self.assertIn('type = "cockpit_param"', lua)
        self.assertIn('param = "BASE_SENSOR_NOSE_GEAR_DOWN"', lua)
        self.assertIn("min = 0.95", lua)
        self.assertIn("max = 1.05", lua)

    def test_emitted_confirm_step_has_no_window(self):
        lua = self._emit(_with_steps({"label": "l", "element": "PTR-X"}))
        self.assertIn('type = "confirm"', lua)
        self.assertNotIn("min = ", lua)

    def test_aircraft_list_is_emitted_as_a_lua_table(self):
        lua = self._emit({**VALID_CHECKLIST, "aircraft": ["F-16C_50", "F-16C bl.50"]})
        self.assertIn('aircraft = {"F-16C_50", "F-16C bl.50"}', lua)

    def test_label_with_quotes_is_emitted_safely(self):
        lua = self._emit(_with_steps({"label": 'say "go"', "element": "PTR-X"}))
        self.assertIn('label = [[say "go"]]', lua)

    def test_mission_activating_nothing_emits_nothing(self):
        lua = generate_config_lua({"lua_modules": {"ASSIST": {}}}, checklists=[])
        self.assertNotIn("registerChecklist", lua)
        self.assertNotIn("registerChecklist", generate_config_lua({"lua_modules": {"ASSIST": {}}}))


if __name__ == "__main__":
    unittest.main()
