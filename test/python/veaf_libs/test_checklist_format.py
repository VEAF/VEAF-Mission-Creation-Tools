"""Tests for the guided-checklist YAML format: model, loader and Lua emission."""

import unittest
from pathlib import Path
from tempfile import TemporaryDirectory

import yaml
from veaf_libs.checklists import (
    CHECKLISTS_FOLDER_NAME,
    ChecklistError,
    load_checklists,
    parse_checklist,
    resolve_text,
    select_activated,
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

    def test_an_argument_step_resolves_to_a_switch_check(self):
        checklist = parse_checklist(
            _with_steps({"label": "l", "element": "PTR-X", "argument": 510, "equals": 1.0}),
            source="test.yaml",
        )
        self.assertEqual(
            {"type": "switch", "argument": 510, "min": 0.95, "max": 1.05},
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

    def test_an_aircraft_too_recent_for_the_catalogue_is_accepted_if_indexed(self):
        # The unit catalogue is generated from a datamine at a pinned revision, so it does
        # not know the F-14B(U). Refusing a checklist for the aircraft somebody just bought
        # would be the wrong answer; its committed cockpit index proves it exists.
        checklist = parse_checklist({**VALID_CHECKLIST, "aircraft": ["F-14BU"]}, "s")
        self.assertEqual(["F-14BU"], checklist.aircraft)

    def test_param_and_check_together_are_rejected(self):
        self._assert_rejected(
            _with_steps({"label": "l", "param": "P", "equals": 1.0, "check": {"type": "x"}}),
            "param",
            "check",
        )

    def test_argument_and_param_together_are_rejected(self):
        self._assert_rejected(
            _with_steps({"label": "l", "argument": 510, "param": "P", "equals": 1.0}),
            "argument",
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
        self._assert_rejected(_with_steps({"label": "l", "param": "P"}), "acceptance window")

    def test_argument_without_window_is_rejected(self):
        self._assert_rejected(_with_steps({"label": "l", "argument": 510}), "acceptance window")

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


class TestInstructorControl(unittest.TestCase):
    """`control` — the free text an instructor writes, and `resolved_from`, its witness.

    The point of the pair is that an instructor keeps owning one file: they write the
    control in their own words, a resolution pass fills the technical fields beside it,
    and a later edit of the text is visible because `resolved_from` no longer matches.
    """

    def test_a_step_may_carry_only_a_control(self):
        # The resolver has to be able to load its own input; refusing here would mean an
        # instructor could not write a checklist at all before resolving it.
        checklist = parse_checklist(_with_steps({"label": "l", "control": "throttle sur idle"}), "s")
        self.assertEqual("throttle sur idle", checklist.steps[0].control)

    def test_a_control_alone_is_unresolved(self):
        step = parse_checklist(_with_steps({"label": "l", "control": "throttle sur idle"}), "s").steps[0]
        self.assertTrue(step.needs_resolution)

    def test_a_control_matching_its_witness_is_resolved(self):
        step = parse_checklist(
            _with_steps(
                {
                    "label": "l",
                    "control": "main pwr sur batt",
                    "resolved_from": "main pwr sur batt",
                    "element": "PTR-ELEC-TMB-MPWR-510",
                    "argument": 510,
                    "equals": 0.0,
                }
            ),
            "s",
        ).steps[0]
        self.assertFalse(step.needs_resolution)

    def test_an_edited_control_goes_stale(self):
        step = parse_checklist(
            _with_steps(
                {
                    "label": "l",
                    "control": "main pwr sur main pwr",
                    "resolved_from": "main pwr sur batt",
                    "element": "PTR-ELEC-TMB-MPWR-510",
                    "argument": 510,
                    "equals": 0.0,
                }
            ),
            "s",
        ).steps[0]
        self.assertTrue(step.needs_resolution)

    def test_matching_ignores_case_and_spacing(self):
        # Re-resolving every step because someone fixed an indent would make the witness
        # useless noise.
        step = parse_checklist(
            _with_steps(
                {
                    "label": "l",
                    "control": "  Throttle  sur IDLE ",
                    "resolved_from": "throttle sur idle",
                    "element": "PTR-THRTL-RLS-757",
                    "confirm": True,
                }
            ),
            "s",
        ).steps[0]
        self.assertFalse(step.needs_resolution)

    def test_a_witness_without_a_control_is_not_stale(self):
        # Someone deleted the source text; the technical fields are still valid.
        step = parse_checklist(
            _with_steps(
                {
                    "label": "l",
                    "resolved_from": "main pwr sur batt",
                    "element": "PTR-ELEC-TMB-MPWR-510",
                    "argument": 510,
                    "equals": 0.0,
                }
            ),
            "s",
        ).steps[0]
        self.assertFalse(step.needs_resolution)

    def test_a_technical_step_is_never_stale(self):
        step = parse_checklist(_with_steps({"label": "l", "element": "PTR-X", "confirm": True}), "s").steps[0]
        self.assertFalse(step.needs_resolution)

    def test_a_checklist_reports_its_unresolved_steps_by_number(self):
        checklist = parse_checklist(
            _with_steps(
                {"label": "one", "element": "PTR-X", "confirm": True},
                {"label": "two", "control": "throttle sur idle"},
                {"label": "three", "control": "gear up", "resolved_from": "gear down", "element": "PTR-Y"},
            ),
            "s",
        )
        self.assertEqual([2, 3], [number for number, _step in checklist.unresolved_steps()])


class TestUnresolvedChecklistIsRefused(unittest.TestCase):
    """A build must not ship a checklist whose steps do not say what they check."""

    def _mission_with(self, step: dict) -> Path:
        folder = Path(self._dir.name)
        (folder / CHECKLISTS_FOLDER_NAME).mkdir()
        (folder / CHECKLISTS_FOLDER_NAME / "own.yaml").write_text(
            yaml.safe_dump({**VALID_CHECKLIST, "id": "own", "steps": [step]}),
            encoding="utf-8",
        )
        return folder

    def setUp(self):
        self._dir = TemporaryDirectory()
        self.addCleanup(self._dir.cleanup)

    def test_an_unresolved_step_fails_the_activation(self):
        folder = self._mission_with({"label": "l", "control": "throttle sur idle"})
        available = load_checklists(folder, catalogue_dir=folder / "no-catalogue")
        with self.assertRaises(ChecklistError) as raised:
            select_activated(available, None, mission_ids=["own"])
        # Naming the step is the whole point: "run the resolver" with no idea where.
        self.assertIn("own", str(raised.exception))
        self.assertIn("throttle sur idle", str(raised.exception))

    def test_a_resolved_checklist_activates(self):
        folder = self._mission_with(
            {
                "label": "l",
                "control": "throttle sur idle",
                "resolved_from": "throttle sur idle",
                "element": "PTR-THRTL-RLS-757",
                "confirm": True,
            }
        )
        available = load_checklists(folder, catalogue_dir=folder / "no-catalogue")
        self.assertEqual(1, len(select_activated(available, None, mission_ids=["own"])))


class TestControlStaysDesignTime(unittest.TestCase):
    """The engine has no use for the instructor's text, so it must not travel."""

    def test_control_and_witness_do_not_reach_the_lua(self):
        lua = generate_config_lua(
            {"lua_modules": {"ASSIST": {}}},
            checklists=[
                parse_checklist(
                    _with_steps(
                        {
                            "label": "l",
                            "control": "throttle sur idle",
                            "resolved_from": "throttle sur idle",
                            "element": "PTR-THRTL-RLS-757",
                            "confirm": True,
                        }
                    ),
                    "s",
                )
            ],
        )
        self.assertIn("PTR-THRTL-RLS-757", lua)
        self.assertNotIn("throttle sur idle", lua)
        self.assertNotIn("resolved_from", lua)


class TestShippedCatalogue(unittest.TestCase):
    """Every checklist this project ships has to load, and be fully resolved."""

    def test_the_shipped_checklists_load(self):
        shipped = load_checklists()
        self.assertIn("f16c-cold-start", shipped)
        self.assertIn("f14bu-engine-start", shipped)

    def test_no_shipped_checklist_has_an_unresolved_step(self):
        # A shipped checklist with a stale `control` would fail the build of any mission
        # that activates it — found here rather than by a mission maker.
        for identifier, checklist in load_checklists().items():
            self.assertEqual([], checklist.unresolved_steps(), identifier)

    def test_the_f14bu_checklist_checks_the_switches_it_can(self):
        steps = load_checklists()["f14bu-engine-start"].steps
        switches = [step.check_table() for step in steps if step.check_table()["type"] == "switch"]
        # The two transfer-pump steps and the two engine-crank ones; the throttles are
        # axes and the air-source selector is five separate buttons.
        self.assertEqual(4, len(switches))


if __name__ == "__main__":
    unittest.main()


class TestDevConditionHatch(unittest.TestCase):
    """`dev_condition` — the hatch that lets an author see step 30 without doing 1 to 29.

    It bypasses the real gate, so every test here is about it being **off unless asked** and
    **impossible to ship unnoticed**. A shipped checklist that auto-ticks tells a pilot they did
    something they did not, in a training tool whose whole value is telling them the truth.
    """

    def _emit(self, *raw: dict) -> str:
        checklists = [parse_checklist(entry, source="test.yaml") for entry in raw]
        return generate_config_lua({"lua_modules": {"ASSIST": {}}}, checklists=checklists)

    def test_absent_means_exactly_todays_behaviour(self):
        # The regression guard that matters: nothing about the emitted step changes.
        self.assertNotIn("devCondition", self._emit(VALID_CHECKLIST))

    def test_declared_false_emits_nothing_either(self):
        lua = self._emit(_with_steps({"label": "l", "element": "PTR-X", "dev_condition": False}))
        self.assertNotIn("devCondition", lua)

    def test_declared_true_reaches_the_engine(self):
        lua = self._emit(_with_steps({"label": "l", "element": "PTR-X", "dev_condition": True}))
        self.assertIn("devCondition = true", lua)

    def test_it_does_not_disturb_the_validation_mode(self):
        # A dev step keeps whatever check it declared: the hatch is a short-circuit at
        # evaluation time, not a third validation mode replacing the real one.
        lua = self._emit(_with_steps({**VALID_CHECKLIST["steps"][0], "dev_condition": True}))
        self.assertIn('type = "cockpit_param"', lua)
        self.assertIn("devCondition = true", lua)

    def test_a_non_boolean_is_rejected(self):
        for bad in ("yes", 1, 0, "true", [], {}):
            with self.subTest(value=bad):
                with self.assertRaises(ChecklistError):
                    parse_checklist(
                        _with_steps({"label": "l", "element": "PTR-X", "dev_condition": bad}),
                        source="test.yaml",
                    )

    def test_the_step_counts_are_reported_for_the_build_warning(self):
        checklist = parse_checklist(
            {
                **VALID_CHECKLIST,
                "steps": [
                    {"label": "a", "element": "PTR-X", "dev_condition": True},
                    {"label": "b", "element": "PTR-Y"},
                    {"label": "c", "element": "PTR-Z", "dev_condition": True},
                ],
            },
            source="test.yaml",
        )
        # Numbered as a pilot sees them, like `unresolved_steps`, so the warning is actionable.
        self.assertEqual([1, 3], [number for number, _ in checklist.dev_condition_steps()])

    def test_a_checklist_without_the_hatch_reports_nothing(self):
        self.assertEqual([], parse_checklist(VALID_CHECKLIST, source="test.yaml").dev_condition_steps())


class TestDevConditionCannotShipSilently(unittest.TestCase):
    """Proven by a test rather than left to a convention, as the ticket asked."""

    def _activate(self, *raw: dict):
        available = {entry["id"]: parse_checklist(entry, source="test.yaml") for entry in raw}
        return select_activated(available, list(available))

    def test_activating_a_dev_checklist_warns_and_names_the_steps(self):
        dev = {
            **VALID_CHECKLIST,
            "id": "dev-one",
            "steps": [
                {"label": "a", "element": "PTR-X", "dev_condition": True},
                {"label": "b", "element": "PTR-Y"},
            ],
        }
        with self.assertLogs("veaf-tools", level="WARNING") as captured:
            self._activate(dev)
        logged = " ".join(captured.output)
        self.assertIn("dev-one", logged)
        self.assertIn("1", logged)

    def test_a_clean_build_warns_about_nothing(self):
        with self.assertRaises(AssertionError):
            # assertLogs fails when nothing is logged, which is the assertion here.
            with self.assertLogs("veaf-tools", level="WARNING"):
                self._activate(VALID_CHECKLIST)
