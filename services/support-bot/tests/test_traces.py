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
from veaf_support_bot.bugreport import BugForm, assemble
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
        self.assertEqual(frames[0].symbol, "convert_fixture")

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
        self.assertEqual(enclosing_function(self.lines, 7), "convert_fixture")

    def test_a_line_above_every_definition_has_no_enclosing_function(self) -> None:
        self.assertEqual(enclosing_function(self.lines, 1), "")


class TestFindingCallers(unittest.TestCase):
    def test_both_callers_are_found_and_the_definition_is_not(self) -> None:
        root = fixture_root()
        defined_in = root / "src/python/veaf-tools/mission_builder/sample.py"
        callers, total = find_callers(root, "convert_fixture", defined_in)
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
        self.assertEqual(find_callers(root, "convert_fixture(); import os; os.system", root / "x"), ((), 0))


class TestTheWholePass(unittest.TestCase):
    def setUp(self) -> None:
        self.checkout = fixture_checkout()

    def test_a_python_traceback_becomes_a_located_fault_with_its_callers(self) -> None:
        reading = read_trace(self.checkout, PYTHON_TRACEBACK)
        self.assertEqual(reading.locations[0].relative, "src/python/veaf-tools/mission_builder/sample.py")
        self.assertEqual(reading.locations[0].line, 7)
        self.assertEqual(reading.locations[0].function, "convert_fixture")
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


#: Where the fixture's twelve-line module sits, as a trace on a stranger's machine writes it.
_SAMPLE = r"C:\Users\Someone\dev\veaf\src\python\veaf-tools\mission_builder\sample.py"


def _trace(line: int, symbol: str) -> str:
    """Render one CPython frame naming the fixture's sample module.

    Args:
        line: The line the frame states.
        symbol: The function the frame names.

    Returns:
        The frame, as a traceback writes it.
    """
    return f'  File "{_SAMPLE}", line {line}, in {symbol}\n'


class TestALocationTheRevisionDoesNotHave(unittest.TestCase):
    """A resolved file is not a resolved location, and the difference has to be said out loud.

    ``checkout.py``'s own header: a location pointing at a line that moved *"is worse than no
    location — it sends a maintainer to the wrong code with the confidence of a machine-produced
    fact"*. A reporter on an older build hitting a file that has since shrunk is the common case,
    not a corner one.
    """

    def setUp(self) -> None:
        self.checkout = fixture_checkout()
        self.length = len((fixture_root() / "src/python/veaf-tools/mission_builder/sample.py").read_text().splitlines())

    def test_a_line_past_the_end_of_the_file_is_not_presented_as_a_position(self) -> None:
        found = read_trace(self.checkout, _trace(999, "gone")).locations[0]
        self.assertEqual(found.file_lines, self.length)
        self.assertFalse(found.line_exists)
        self.assertEqual(found.excerpt, "")

    def test_no_function_is_invented_for_a_line_that_does_not_exist(self) -> None:
        """`enclosing_function` scans up from the end of the file, so it always answers something."""
        found = read_trace(self.checkout, f'  File "{_SAMPLE}", line 999\n').locations[0]
        self.assertEqual(found.enclosing, "")
        self.assertEqual(found.function, "", "the last function in the file is not where line 999 is")

    def test_the_report_says_so_rather_than_printing_a_bare_file_and_line(self) -> None:
        report = assemble(BugForm("s", _trace(999, "gone"), "e", "st"), self.checkout)
        stated = [note.reason for note in report.notes if note.subject.endswith("sample.py:999")]
        self.assertEqual(len(stated), 1)
        self.assertIn(f"{self.length} lines", stated[0])

    def test_a_line_the_file_does_have_is_reported_as_nothing_of_the_sort(self) -> None:
        found = read_trace(self.checkout, _trace(7, "convert_fixture")).locations[0]
        self.assertTrue(found.line_exists)
        self.assertFalse(found.stale_symbol)
        report = assemble(BugForm("s", _trace(7, "convert_fixture"), "e", "st"), self.checkout)
        self.assertEqual([note for note in report.notes if "sample.py:7" in note.subject], [])


class TestTheTracesSymbolIsConfrontedWithTheFile(unittest.TestCase):
    """The trace names a function and the file says which function that line is in. Comparing the
    two is a staleness detector that costs one string comparison, and it was being thrown away."""

    def setUp(self) -> None:
        self.checkout = fixture_checkout()

    def test_a_line_at_module_level_is_not_published_as_being_in_a_function(self) -> None:
        found = read_trace(self.checkout, _trace(2, "convert_fixture")).locations[0]
        self.assertTrue(found.line_exists)
        self.assertEqual(found.enclosing, "", "line 2 is a blank line after the module docstring")
        self.assertTrue(found.stale_symbol)

    def test_the_disagreement_is_stated_with_both_names(self) -> None:
        report = assemble(BugForm("s", _trace(11, "convert_fixture"), "e", "st"), self.checkout)
        stated = [note.reason for note in report.notes if note.subject.endswith("sample.py:11")]
        self.assertEqual(len(stated), 1)
        self.assertIn("convert_fixture", stated[0], "what the reporter's build said")
        self.assertIn("validate", stated[0], "what this revision says")

    def test_a_frame_naming_no_function_is_not_a_disagreement(self) -> None:
        """CPython writes `<module>`, `<listcomp>` and `<lambda>`; none of them is a claim."""
        for symbol in ("<module>", "<listcomp>", "<lambda>"):
            with self.subTest(symbol=symbol):
                found = read_trace(self.checkout, _trace(2, symbol)).locations[0]
                self.assertFalse(found.stale_symbol)

    def test_agreement_produces_no_note(self) -> None:
        report = assemble(BugForm("s", _trace(6, "convert_fixture"), "e", "st"), self.checkout)
        self.assertEqual([note for note in report.notes if "sample.py:6" in note.subject], [])


if __name__ == "__main__":
    unittest.main()
