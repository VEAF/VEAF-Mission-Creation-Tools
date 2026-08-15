"""Tests for turning an instructor's plain-words control into technical fields."""

import unittest
from pathlib import Path
from tempfile import TemporaryDirectory

import yaml
from veaf_libs.checklist_resolver import (
    ResolverError,
    apply_resolutions,
    load_control_index,
    resolve_checklist_file,
    resolve_control,
)

# Trimmed from the committed F-16C index, keeping the shapes that matter: a three-position
# switch whose hint order is not its value order, a two-position one, a button with no
# position at all, a control with named positions but no values, and a near-namesake.
INDEX = {
    "aircraft": "F-16C_50",
    "controls": {
        "PTR-ELEC-TMB-MPWR-510": {
            "argument": 510,
            "hint": "MAIN PWR Switch, MAIN PWR/BATT/OFF",
            "positions": ["MAIN PWR", "BATT", "OFF"],
            "range": [-1.0, 1.0],
            "readable": True,
            "values": {"OFF": -1.0, "BATT": 0.0, "MAIN PWR": 1.0},
        },
        "PTR-FLTCP-TMB-DIGITAL-566": {
            "argument": 566,
            "hint": "DIGITAL BACKUP Switch, OFF/BACKUP",
            "positions": ["OFF", "BACKUP"],
            "range": [0.0, 1.0],
            "readable": True,
            "values": {"OFF": 0.0, "BACKUP": 1.0},
        },
        "PTR-THRTL-RLS-757": {
            "argument": 757,
            "hint": "Throttle, OFF/IDLE",
            "positions": ["OFF", "IDLE"],
            "range": [0.0, 1.0],
            "readable": False,
            "values": {},
        },
        "PTR-EPU-TMB-EPU-370": {
            "argument": 370,
            "hint": "EPU Switch, NORM/OFF",
            "positions": ["NORM", "OFF"],
            "range": [-1.0, 1.0],
            "readable": True,
            "values": {"NORM": 0.0, "OFF": -1.0},
        },
        "PTR-ANTI-ICE-TMB-341": {
            "argument": 341,
            "hint": "ANTI-ICE Switch, ON/AUTO/OFF",
            "positions": ["ON", "AUTO", "OFF"],
            "range": [-1.0, 1.0],
            "readable": True,
            # No binding names this one's positions — the AH-64D is mostly like this.
            "values": {},
        },
        "PTR-ELEC-TMB-MPWR-511": {
            "argument": 511,
            "hint": "MAIN PWR Test Switch, TEST/NORM",
            "positions": ["TEST", "NORM"],
            "range": [0.0, 1.0],
            "readable": True,
            "values": {"TEST": 1.0, "NORM": 0.0},
        },
    },
}


class TestOrdinaryMatch(unittest.TestCase):
    """The case that has to just work, or the whole feature is pointless."""

    def test_a_control_and_its_position_are_resolved(self):
        resolution = resolve_control("main pwr sur batt", INDEX)
        self.assertEqual("PTR-ELEC-TMB-MPWR-510", resolution.fields["element"])
        self.assertEqual(510, resolution.fields["argument"])
        self.assertEqual(0.0, resolution.fields["equals"])
        self.assertEqual("", resolution.refusal)

    def test_the_value_comes_from_the_bindings_not_from_the_rank(self):
        # OFF is last in the hint and lowest in value; a resolver reading rank order
        # would emit +1 here and the step would never tick.
        self.assertEqual(-1.0, resolve_control("main pwr sur off", INDEX).fields["equals"])

    def test_an_english_instructor_is_understood_too(self):
        self.assertEqual(1.0, resolve_control("set MAIN PWR switch to MAIN PWR", INDEX).fields["equals"])

    def test_filler_words_do_not_break_the_match(self):
        resolution = resolve_control("mettre le bouton DIGITAL BACKUP en position BACKUP", INDEX)
        self.assertEqual("PTR-FLTCP-TMB-DIGITAL-566", resolution.fields["element"])
        self.assertEqual(1.0, resolution.fields["equals"])

    def test_accents_and_punctuation_are_ignored(self):
        resolution = resolve_control("interrupteur EPU sur NORM", INDEX)
        self.assertEqual("PTR-EPU-TMB-EPU-370", resolution.fields["element"])


class TestRefusals(unittest.TestCase):
    """Failing well is the feature: a wrong resolution looks finished and never ticks."""

    def test_an_unknown_control_is_refused_with_candidates(self):
        resolution = resolve_control("bouton hydraulique numero 3", INDEX)
        self.assertNotEqual("", resolution.refusal)
        self.assertEqual({}, resolution.fields)

    def test_two_equally_good_matches_are_refused_and_both_named(self):
        # This names both switches in full: MAIN PWR and MAIN PWR Test. Scoring cannot
        # separate them and only the instructor knows which they meant.
        resolution = resolve_control("main pwr test sur norm", INDEX)
        self.assertNotEqual("", resolution.refusal)
        named = {candidate.element for candidate in resolution.candidates}
        self.assertIn("PTR-ELEC-TMB-MPWR-510", named)
        self.assertIn("PTR-ELEC-TMB-MPWR-511", named)

    def test_a_position_the_control_does_not_have_is_refused(self):
        resolution = resolve_control("main pwr sur turbo", INDEX)
        self.assertNotEqual("", resolution.refusal)
        # The message has to say what the control does offer, or the instructor is stuck.
        self.assertIn("BATT", resolution.refusal)

    def test_a_control_with_no_known_values_is_refused_saying_so(self):
        resolution = resolve_control("ANTI-ICE sur AUTO", INDEX)
        self.assertEqual({}, resolution.fields)
        # The refusal has to point somewhere: the hint's own position names.
        self.assertIn("AUTO", resolution.refusal)

    def test_a_refusal_never_writes_half_a_step(self):
        for text in ("bouton hydraulique numero 3", "main pwr test sur norm", "main pwr sur turbo"):
            self.assertEqual({}, resolve_control(text, INDEX).fields, text)


class TestUnreadableControls(unittest.TestCase):
    """A button has no position to poll, so the pilot is the only possible witness."""

    def test_a_button_resolves_to_a_confirm_step(self):
        resolution = resolve_control("throttle sur idle", INDEX)
        self.assertEqual("PTR-THRTL-RLS-757", resolution.fields["element"])
        self.assertTrue(resolution.fields["confirm"])
        self.assertNotIn("argument", resolution.fields)
        self.assertNotIn("equals", resolution.fields)

    def test_that_choice_is_reported_rather_than_made_silently(self):
        # It is the right step, but it is not what the instructor asked for: they asked
        # for a check, and got a confirmation.
        self.assertNotEqual("", resolve_control("throttle sur idle", INDEX).note)


class TestIndexLoading(unittest.TestCase):
    """The shipped indexes, and what happens for an aircraft with none."""

    def test_the_shipped_f16c_index_loads(self):
        index = load_control_index("F-16C_50")
        self.assertEqual("F-16C_50", index["aircraft"])
        self.assertIn("PTR-ELEC-TMB-MPWR-510", index["controls"])

    def test_an_unindexed_aircraft_says_which_ones_exist(self):
        with self.assertRaises(ResolverError) as raised:
            load_control_index("Su-25T")
        self.assertIn("F-16C_50", str(raised.exception))

    def test_the_shipped_index_resolves_the_step_this_lot_started_from(self):
        # End to end against the real F-16C data, not the trimmed fixture above.
        resolution = resolve_control("MAIN PWR sur BATT", load_control_index("F-16C_50"))
        self.assertEqual("PTR-ELEC-TMB-MPWR-510", resolution.fields["element"])
        self.assertEqual(0.0, resolution.fields["equals"])


INSTRUCTOR_FILE = """\
# An instructor's own notes, which they must still have after a resolution run.
id: f16c-cold-start
title: My start-up
aircraft: [F-16C_50]
menu: cold-start

steps:
  # Battery first, or the rest does nothing.
  - label: Battery on
    control: MAIN PWR sur BATT

  - label: Full power
    control: MAIN PWR sur MAIN PWR

  - label: Already done by hand
    element: PTR-X
    confirm: true
"""


class TestResolvingAWholeFile(unittest.TestCase):
    """The file belongs to the instructor; the resolver is a guest in it."""

    def setUp(self):
        self._dir = TemporaryDirectory()
        self.addCleanup(self._dir.cleanup)
        self.path = Path(self._dir.name) / "start.yaml"
        self.path.write_text(INSTRUCTOR_FILE, encoding="utf-8")

    def test_only_the_stale_steps_are_resolved(self):
        outcomes = resolve_checklist_file(self.path)
        self.assertEqual([1, 2], [outcome.number for outcome in outcomes])

    def test_writing_fills_the_technical_fields_and_the_witness(self):
        apply_resolutions(self.path, resolve_checklist_file(self.path))
        steps = yaml.safe_load(self.path.read_text(encoding="utf-8"))["steps"]
        self.assertEqual("PTR-ELEC-TMB-MPWR-510", steps[0]["element"])
        self.assertEqual(0.0, steps[0]["equals"])
        self.assertEqual("MAIN PWR sur BATT", steps[0]["resolved_from"])

    def test_the_instructors_comments_survive(self):
        apply_resolutions(self.path, resolve_checklist_file(self.path))
        written = self.path.read_text(encoding="utf-8")
        self.assertIn("# An instructor's own notes", written)
        self.assertIn("# Battery first, or the rest does nothing.", written)

    def test_the_layout_survives_too(self):
        # Not cosmetic: a run that reindents the file or moves the blank lines around
        # turns a two-field edit into a diff the instructor cannot read, and they stop
        # trusting the tool with their own file.
        apply_resolutions(self.path, resolve_checklist_file(self.path))
        written = self.path.read_text(encoding="utf-8")
        self.assertIn("  - label: Battery on", written)
        # The separator stays between two steps, not inside one.
        self.assertIn("resolved_from: MAIN PWR sur BATT\n\n  - label: Full power", written)

    def test_a_resolved_file_needs_no_second_run(self):
        apply_resolutions(self.path, resolve_checklist_file(self.path))
        self.assertEqual([], resolve_checklist_file(self.path))

    def test_editing_a_control_makes_that_step_stale_again(self):
        apply_resolutions(self.path, resolve_checklist_file(self.path))
        self.path.write_text(
            self.path.read_text(encoding="utf-8").replace("control: MAIN PWR sur BATT", "control: MAIN PWR sur OFF"),
            encoding="utf-8",
        )
        outcomes = resolve_checklist_file(self.path)
        self.assertEqual([1], [outcome.number for outcome in outcomes])
        apply_resolutions(self.path, outcomes)
        steps = yaml.safe_load(self.path.read_text(encoding="utf-8"))["steps"]
        self.assertEqual(-1.0, steps[0]["equals"])

    def test_a_step_that_becomes_a_confirm_loses_its_stale_argument(self):
        apply_resolutions(self.path, resolve_checklist_file(self.path))
        self.path.write_text(
            self.path.read_text(encoding="utf-8").replace("control: MAIN PWR sur BATT", "control: throttle sur idle"),
            encoding="utf-8",
        )
        apply_resolutions(self.path, resolve_checklist_file(self.path))
        step = yaml.safe_load(self.path.read_text(encoding="utf-8"))["steps"][0]
        self.assertTrue(step["confirm"])
        # Keeping `argument: 510` beside `confirm: true` would fail validation, and worse,
        # would describe the previous control.
        self.assertNotIn("argument", step)

    def test_nothing_is_written_when_any_step_is_refused(self):
        self.path.write_text(
            INSTRUCTOR_FILE.replace("control: MAIN PWR sur MAIN PWR", "control: le bidule bleu"),
            encoding="utf-8",
        )
        before = self.path.read_text(encoding="utf-8")
        with self.assertRaises(ResolverError):
            apply_resolutions(self.path, resolve_checklist_file(self.path))
        self.assertEqual(before, self.path.read_text(encoding="utf-8"))


if __name__ == "__main__":
    unittest.main()
