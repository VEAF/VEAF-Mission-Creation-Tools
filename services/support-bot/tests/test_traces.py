"""Locating a fault from a pasted trace, against a real checkout.

Every case here runs against the miniature repository :mod:`tests.intake_fixtures` builds, so the
assertions are about resolution and reading, not about a stub agreeing with itself.
"""

from __future__ import annotations

import unittest
from pathlib import Path

from tests.intake_fixtures import (
    LUA_ERROR,
    MISSING_TRACEBACK,
    PYTHON_TRACEBACK,
    fixture_checkout,
    fixture_root,
)
from veaf_support_bot.traces import (
    RawFrame,
    enclosing_function,
    find_callers,
    find_frames,
    quote_neighbourhood,
    read_trace,
    resolve_frame,
    unique_by_name,
)


class TestFindingFrames(unittest.TestCase):
    def test_a_python_traceback_yields_its_frames_innermost_first(self) -> None:
        frames = find_frames(PYTHON_TRACEBACK)
        self.assertEqual([frame.line for frame in frames], [7, 7])
        self.assertTrue(frames[0].path.endswith("sample.py"))
        self.assertEqual(frames[0].symbol, "convert")

    def test_a_lua_error_yields_its_file_and_line(self) -> None:
        frames = find_frames(LUA_ERROR)
        self.assertEqual(len(frames), 1)
        self.assertTrue(frames[0].path.endswith("veafSample.lua"))
        self.assertEqual(frames[0].line, 4)

    def test_prose_with_no_trace_yields_nothing(self) -> None:
        self.assertEqual(find_frames("it crashed when I pressed the button"), [])

    def test_the_same_frame_twice_is_reported_once(self) -> None:
        doubled = PYTHON_TRACEBACK + PYTHON_TRACEBACK
        self.assertEqual(len(find_frames(doubled)), 2)


class TestResolvingAgainstTheCheckout(unittest.TestCase):
    def setUp(self) -> None:
        self.checkout = fixture_checkout()

    def test_a_machine_path_maps_onto_the_repository(self) -> None:
        frame = RawFrame(r"C:\Users\Someone\dev\veaf\src\python\veaf-tools\mission_builder\sample.py", 7)
        found = resolve_frame(self.checkout, frame)
        self.assertIsNotNone(found)
        assert found is not None
        self.assertEqual(found.name, "sample.py")

    def test_a_bare_basename_resolves_when_only_one_file_carries_it(self) -> None:
        """DCS names a Lua chunk with no directory at all, so this is the in-game shape."""
        self.assertIsNotNone(resolve_frame(self.checkout, RawFrame("sample.py", 1)))

    def test_a_basename_two_files_share_resolves_to_nothing(self) -> None:
        """Picking one of them would be a coin toss presented as a fact."""
        self.assertIsNone(unique_by_name(fixture_root(), "__init__.py"))

    def test_a_file_the_checkout_does_not_have_resolves_to_nothing(self) -> None:
        self.assertIsNone(resolve_frame(self.checkout, RawFrame("removed_three_releases_ago.py", 412)))

    def test_a_traversal_cannot_escape_the_checkout(self) -> None:
        """The path comes from a public form; ``..`` must reach nothing, not a real file."""
        for attempt in ("../../../../etc/passwd", r"..\..\..\..\Windows\win.ini", "/etc/passwd"):
            with self.subTest(attempt=attempt):
                self.assertIsNone(self.checkout.resolve(attempt))

    def test_an_absolute_path_outside_the_checkout_resolves_to_nothing(self) -> None:
        outside = Path(__file__).resolve()
        self.assertIsNone(self.checkout.resolve(str(outside)))


class TestReadingTheNeighbourhood(unittest.TestCase):
    def setUp(self) -> None:
        self.lines = (fixture_root() / "src/python/veaf-tools/mission_builder/sample.py").read_text().splitlines()

    def test_the_faulting_line_is_marked(self) -> None:
        quoted = quote_neighbourhood(self.lines, 7)
        self.assertIn("> ", quoted)
        marked = [line for line in quoted.splitlines() if line.startswith(">")]
        self.assertEqual(len(marked), 1)
        self.assertIn('validated["result"]', marked[0])

    def test_a_line_past_the_end_of_the_file_quotes_nothing(self) -> None:
        self.assertEqual(quote_neighbourhood(self.lines, 9999), "")

    def test_the_enclosing_function_is_read_from_the_file(self) -> None:
        self.assertEqual(enclosing_function(self.lines, 7), "convert")

    def test_a_line_above_every_definition_has_no_enclosing_function(self) -> None:
        self.assertEqual(enclosing_function(self.lines, 1), "")


class TestFindingCallers(unittest.TestCase):
    def test_both_callers_are_found_and_the_definition_is_not(self) -> None:
        root = fixture_root()
        defined_in = root / "src/python/veaf-tools/mission_builder/sample.py"
        callers, total = find_callers(root, "convert", defined_in)
        self.assertEqual(total, 2)
        named = {entry.split(":")[0] for entry in callers}
        self.assertEqual(
            named,
            {
                "src/python/veaf-tools/mission_builder/caller_one.py",
                "src/python/veaf-tools/mission_builder/caller_two.py",
            },
        )

    def test_a_function_nobody_calls_yields_nothing(self) -> None:
        root = fixture_root()
        callers, total = find_callers(
            root, "nobody_calls_this", root / "src/python/veaf-tools/mission_builder/sample.py"
        )
        self.assertEqual((callers, total), ((), 0))

    def test_a_name_that_is_not_an_identifier_is_refused(self) -> None:
        """The name can come from a trace, so it can be anything at all."""
        root = fixture_root()
        self.assertEqual(find_callers(root, "convert(); import os; os.system", root / "x"), ((), 0))


class TestTheWholePass(unittest.TestCase):
    def setUp(self) -> None:
        self.checkout = fixture_checkout()

    def test_a_python_traceback_becomes_a_located_fault_with_its_callers(self) -> None:
        reading = read_trace(self.checkout, PYTHON_TRACEBACK)
        self.assertEqual(reading.locations[0].relative, "src/python/veaf-tools/mission_builder/sample.py")
        self.assertEqual(reading.locations[0].line, 7)
        self.assertEqual(reading.locations[0].function, "convert")
        self.assertEqual(reading.locations[0].caller_total, 2)
        self.assertIn('validated["result"]', reading.locations[0].excerpt)

    def test_a_lua_error_is_located_too(self) -> None:
        reading = read_trace(self.checkout, LUA_ERROR)
        self.assertEqual(reading.locations[0].relative, "src/scripts/veaf/veafSample.lua")
        self.assertEqual(reading.locations[0].function, "veafSample.spawn")

    def test_a_file_that_no_longer_exists_is_reported_rather_than_dropped(self) -> None:
        reading = read_trace(self.checkout, MISSING_TRACEBACK)
        self.assertEqual(reading.locations, ())
        self.assertEqual(len(reading.unresolved), 1)
        self.assertEqual(reading.unresolved[0].line, 412)
        self.assertTrue(reading.found_anything)

    def test_a_report_with_no_trace_finds_nothing_and_says_so(self) -> None:
        reading = read_trace(self.checkout, "the button did nothing")
        self.assertFalse(reading.found_anything)


if __name__ == "__main__":
    unittest.main()
