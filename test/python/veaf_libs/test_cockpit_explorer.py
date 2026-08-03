"""Tests for naming a cockpit control by moving it."""

import unittest

from veaf_libs.checklist_verifier import VerificationError
from veaf_libs.cockpit_explorer import (
    arguments_of,
    identify,
    read_many,
)

INDEX = {
    "aircraft": "F-14BU",
    "controls": {
        "PNT_629": {
            "argument": 629,
            "hint": "Hydraulic Transfer Pump Switch",
            "values": {"NORMAL": 0.0, "SHUTOFF": 1.0},
        },
        "PNT_630": {
            # A guard sharing nothing with the switch, but with its own argument.
            "argument": 630,
            "hint": "Hydraulic Transfer Pump Switch Cover",
            "values": {"CLOSE": 0.0, "OPEN": 1.0},
        },
        "PNT_928": {
            # The AH-64D's whole cockpit looks like this: no known position values.
            "argument": 928,
            "hint": "Hydraulic Emergency Flight Control Switch",
            "values": {},
        },
        "PNT_2102_TWIN": {"argument": 629, "hint": "A second element on the same argument"},
    },
}


class TestArguments(unittest.TestCase):
    """What gets read, and how often."""

    def test_arguments_are_unique_and_sorted(self):
        # 629 appears twice in the index; reading it twice tells us nothing new.
        self.assertEqual([629, 630, 928], arguments_of(INDEX))

    def test_an_index_with_no_controls_asks_for_nothing(self):
        self.assertEqual([], arguments_of({"controls": {}}))


class TestReadingTheCockpit(unittest.TestCase):
    """One round trip for the whole cockpit, not one per control."""

    def test_the_whole_batch_is_one_call(self):
        calls = []

        def run(code):
            calls.append(code)
            return "629=0,630=1,928=-1"

        readings = read_many(run, [629, 630, 928])
        self.assertEqual(1, len(calls))
        self.assertEqual({629: 0.0, 630: 1.0, 928: -1.0}, readings)

    def test_an_unanswered_argument_is_absent_rather_than_zero(self):
        # Absent and zero mean different things: one is "no reading", the other is a
        # position. Filling the gap with 0.0 would invent a change on the next poll.
        readings = read_many(lambda code: "629=1", [629, 630])
        self.assertNotIn(630, readings)

    def test_no_aircraft_is_an_error_the_pilot_can_act_on(self):
        with self.assertRaises(VerificationError) as raised:
            read_many(lambda code: "nodevice", [629])
        self.assertIn("bridge", str(raised.exception))

    def test_a_silent_cockpit_is_an_error_too(self):
        with self.assertRaises(VerificationError):
            read_many(lambda code: "", [629])


class TestIdentifying(unittest.TestCase):
    """The direction that matters: the pilot moves something, the tool names it."""

    def test_a_moved_control_names_itself_with_its_position(self):
        changes = identify({629: 0.0}, {629: 1.0}, INDEX)
        self.assertEqual(1, len(changes))
        self.assertEqual("PNT_629", changes[0].element)
        self.assertEqual("SHUTOFF", changes[0].position)
        self.assertEqual(1.0, changes[0].value)

    def test_a_control_with_no_known_values_is_still_named(self):
        # This is the whole point for the AH-64D: the value is measured, so the author
        # gets a usable step even though nothing in the files named that position.
        changes = identify({928: 0.0}, {928: -1.0}, INDEX)
        self.assertEqual("PNT_928", changes[0].element)
        self.assertIsNone(changes[0].position)
        self.assertEqual(-1.0, changes[0].value)

    def test_an_unchanged_cockpit_reports_nothing(self):
        self.assertEqual([], identify({629: 1.0, 630: 0.0}, {629: 1.0, 630: 0.0}, INDEX))

    def test_jitter_is_not_a_change(self):
        self.assertEqual([], identify({629: 0.0}, {629: 0.005}, INDEX))

    def test_an_argument_no_element_claims_is_skipped(self):
        # It moved, but there is nothing to tell the author about it.
        self.assertEqual([], identify({7777: 0.0}, {7777: 1.0}, INDEX))

    def test_a_first_reading_is_not_a_change(self):
        # An argument absent from `before` has not moved — it has just been seen.
        self.assertEqual([], identify({}, {629: 1.0}, INDEX))

    def test_a_named_position_is_reported_before_an_unnamed_one(self):
        changes = identify({629: 0.0, 928: 0.0}, {629: 1.0, 928: 1.0}, INDEX)
        self.assertEqual(["PNT_629", "PNT_928"], [change.element for change in changes])

    def test_a_change_renders_as_a_pasteable_step(self):
        step = identify({629: 0.0}, {629: 1.0}, INDEX)[0].as_step(label="Pump to SHUTOFF")
        self.assertIn("element: PNT_629", step)
        self.assertIn("argument: 629", step)
        self.assertIn("equals: 1.0", step)


if __name__ == "__main__":
    unittest.main()
