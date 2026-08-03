"""Tests for verifying a resolved checklist against a real cockpit."""

import unittest
from pathlib import Path
from tempfile import TemporaryDirectory
from unittest import mock

import yaml
from typer.testing import CliRunner
from veaf_libs.checklist_verifier import (
    StepReading,
    VerificationError,
    highlight,
    read_argument,
    say,
    wait_for_value,
)


class FakeCockpit:
    """A cockpit whose argument the test moves, standing in for DCS and the bridge."""

    def __init__(self, readings):
        self.readings = list(readings)
        self.calls = []
        self.clock = 0.0

    def run(self, code: str) -> str:
        self.calls.append(code)
        if "get_argument_value" in code:
            return str(self.readings.pop(0) if len(self.readings) > 1 else self.readings[0])
        return "ok"

    def sleep(self, seconds: float) -> None:
        self.clock += seconds

    def now(self) -> float:
        return self.clock


class TestReading(unittest.TestCase):
    """Getting a number out of the cockpit, or saying clearly that there is none."""

    def test_an_argument_comes_back_as_a_number(self):
        self.assertEqual(-1.0, read_argument(FakeCockpit([-1.0]).run, 510))

    def test_the_argument_asked_for_is_the_one_read(self):
        cockpit = FakeCockpit([0.0])
        read_argument(cockpit.run, 2102)
        self.assertIn("get_argument_value(2102)", cockpit.calls[0])

    def test_no_cockpit_is_an_error_naming_what_to_check(self):
        with self.assertRaises(VerificationError) as raised:
            read_argument(lambda code: "nodevice", 510)
        self.assertIn("510", str(raised.exception))
        self.assertIn("bridge", str(raised.exception))


class TestHighlighting(unittest.TestCase):
    """Boxing a control is the only thing this does to the pilot's aircraft."""

    def test_an_element_is_boxed_by_name(self):
        cockpit = FakeCockpit([0.0])
        highlight(cockpit.run, "PNT_629")
        self.assertIn('a_cockpit_highlight(1, "PNT_629")', cockpit.calls[0])

    def test_an_instruction_reaches_the_game_not_the_console(self):
        # The pilot is at full screen in a cockpit; a console line is invisible to the
        # only person who can act on it.
        cockpit = FakeCockpit([0.0])
        say(cockpit.run, "2. Pompe sur SHUTOFF")
        self.assertIn("outText", cockpit.calls[0])
        self.assertIn("Pompe sur SHUTOFF", cockpit.calls[0])

    def test_a_quote_in_a_message_does_not_break_the_lua(self):
        cockpit = FakeCockpit([0.0])
        say(cockpit.run, 'mettre "MAIN PWR"')
        self.assertNotIn('""', cockpit.calls[0].replace('\\"', ""))

    def test_none_clears_the_box(self):
        cockpit = FakeCockpit([0.0])
        highlight(cockpit.run, None)
        self.assertIn("a_cockpit_remove_highlight(1)", cockpit.calls[0])


class TestWaitingForThePilot(unittest.TestCase):
    """Waiting on the control moving, not on a keypress: nobody holds a keyboard in a cockpit."""

    def _wait(self, readings, expected=1.0, timeout=60.0):
        cockpit = FakeCockpit(readings)
        return wait_for_value(cockpit.run, 629, expected, timeout=timeout, sleep=cockpit.sleep, now=cockpit.now)

    def test_reaching_the_wanted_value_ends_the_wait(self):
        self.assertEqual(1.0, self._wait([0.0, 1.0, 1.0]))

    def test_a_control_already_in_position_is_confirmed_at_once(self):
        # Asking someone to move a switch that is already correct reads as a broken tool.
        self.assertEqual(1.0, self._wait([1.0]))

    def test_passing_through_another_position_does_not_end_the_wait(self):
        # Told to put a switch back and forth, the first version caught the first half of
        # the trip and announced the checklist had the wrong value. It had not.
        self.assertEqual(1.0, self._wait([1.0, 0.0, 0.0, 0.0, 1.0, 1.0], expected=1.0))

    def test_a_value_that_never_moves_times_out(self):
        self.assertIsNone(self._wait([0.0] * 40, timeout=2.0))

    def test_settling_on_the_wrong_position_reports_it(self):
        # The interesting answer: the pilot put it where the step says, and the number
        # disagrees — so the checklist is wrong.
        self.assertEqual(-1.0, self._wait([0.0, -1.0, -1.0, -1.0, -1.0, -1.0], expected=1.0, timeout=3.0))


class TestStepReading(unittest.TestCase):
    """What the result says about one step."""

    def _reading(self, measured):
        return StepReading(number=1, element="PNT_629", argument=629, expected=1.0, measured=measured)

    def test_the_expected_value_matches(self):
        self.assertTrue(self._reading(1.0).matches)

    def test_a_hair_off_still_matches(self):
        # DCS animates an argument towards its target; exact equality is too strict.
        self.assertTrue(self._reading(0.995).matches)

    def test_a_different_position_does_not_match(self):
        # The interesting case: it means the checklist has the wrong value.
        self.assertFalse(self._reading(-1.0).matches)

    def test_a_timeout_is_neither_a_match_nor_a_value(self):
        reading = self._reading(None)
        self.assertTrue(reading.timed_out)
        self.assertFalse(reading.matches)


class TestTheCommand(unittest.TestCase):
    """The `verify-checklist` command, with the cockpit faked out."""

    CHECKLIST = """\
id: f14bu-engine-start
title: Test
aircraft: [F-14BU]
menu: cold-start

steps:
  - label: Pump to SHUTOFF
    element: PNT_629
    argument: 629
    equals: 1.0

  - label: Pilot confirms
    element: PNT_933
    confirm: true
"""

    def setUp(self):
        import veaf_tools.commands  # noqa: F401 — registers the commands
        from veaf_tools.app import app

        self._dir = TemporaryDirectory()
        self.addCleanup(self._dir.cleanup)
        self.path = Path(self._dir.name) / "check.yaml"
        self.path.write_text(self.CHECKLIST, encoding="utf-8")
        self.runner = CliRunner()
        self.app = app

    def _run(self, measured, *extra):
        reading = StepReading(number=1, element="PNT_629", argument=629, expected=1.0, measured=measured)
        # Patch where the command *looks them up*, not where they are defined: the command
        # imports resolve_api_key at module level, so patching the source module leaves the
        # real one in place — which passed locally, where a dcs-serve.yaml holds a key, and
        # failed in CI, where none exists.
        with (
            mock.patch("veaf_libs.checklist_verifier.make_lua_runner", return_value=lambda code: "ok"),
            mock.patch("veaf_libs.checklist_verifier.verify_step", return_value=reading),
            mock.patch("veaf_tools.commands.verify_checklist.resolve_api_key", return_value="key"),
        ):
            return self.runner.invoke(self.app, ["verify-checklist", str(self.path), *extra])

    def test_a_matching_step_succeeds(self):
        result = self._run(1.0)
        self.assertEqual(0, result.exit_code, result.output)

    def test_only_measurable_steps_are_checked(self):
        # The confirm step has nothing to read; asking the pilot to move it would be
        # asking them to move a control the checklist never checks.
        result = self._run(1.0)
        self.assertNotIn("PNT_933", result.output)

    def test_a_mismatch_fails_the_command(self):
        # The interesting case: the checklist claims a value the cockpit disagrees with.
        result = self._run(-1.0)
        self.assertEqual(1, result.exit_code, result.output)

    def test_a_timeout_is_not_a_failure(self):
        # The pilot skipped that one; nothing was learned, but nothing is wrong either.
        self.assertEqual(0, self._run(None).exit_code)

    def test_write_marks_the_confirmed_step(self):
        self._run(1.0, "--write")
        steps = yaml.safe_load(self.path.read_text(encoding="utf-8"))["steps"]
        self.assertTrue(steps[0]["verified"])
        self.assertNotIn("verified", steps[1])

    def test_nothing_is_written_without_the_flag(self):
        self._run(1.0)
        self.assertNotIn("verified", self.path.read_text(encoding="utf-8"))

    def test_a_missing_file_is_reported_rather_than_traced(self):
        result = self.runner.invoke(self.app, ["verify-checklist", str(self.path.parent / "nope.yaml")])
        self.assertEqual(1, result.exit_code)


if __name__ == "__main__":
    unittest.main()


class TestWhatTheCommandTellsYouToDo(unittest.TestCase):
    """The prompt has to name the control and the position, not the step."""

    def test_the_instructors_own_words_are_used_when_present(self):
        from veaf_libs.checklists import ChecklistStep
        from veaf_tools.commands.verify_checklist import _what_to_do

        step = ChecklistStep(
            label="Lancer le moteur droit",  # a pilot's label: says neither what nor where
            control="Engine Crank sur Right Engine",
            resolved_from="Engine Crank sur Right Engine",
            element="PNT_2102",
            argument=2102,
            equals=-1.0,
        )
        self.assertEqual("Engine Crank sur Right Engine", _what_to_do(step))

    def test_a_technical_step_falls_back_to_element_and_value(self):
        from veaf_libs.checklists import ChecklistStep
        from veaf_tools.commands.verify_checklist import _what_to_do

        step = ChecklistStep(label="Batterie", element="PNT_629", argument=629, equals=1.0)
        told = _what_to_do(step)
        self.assertIn("PNT_629", told)
        self.assertIn("1.0", told)
