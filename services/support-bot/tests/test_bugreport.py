"""What the form becomes, and the promise that nothing in it was guessed.

The two things worth asserting hard:

* **missing is stated.** A version nobody pasted must not become "latest", "6.x" or anything else a
  maintainer could mistake for a reading;
* **the component table is real.** It writes the options of ``.github/ISSUE_TEMPLATE/bug_report.yml``
  into a filed issue, so a renamed option there would leave the bot writing a component nobody can
  filter on — with every test in this file still green if it only compared strings to itself.
"""

from __future__ import annotations

import unittest
from pathlib import Path

from tests.intake_fixtures import (
    LUA_ERROR,
    MISSING_TRACEBACK,
    PYTHON_TRACEBACK,
    doctor_block,
    fixture_checkout,
)
from veaf_support_bot.bugreport import (
    BASE_LABEL,
    COMPONENT_RULES,
    NOT_STATED,
    TITLE_MAX_CHARS,
    UNKNOWN_COMPONENT,
    BugForm,
    assemble,
    build_title,
    component_for,
    safe_redact,
)

#: The repository's own issue template, read for real.
TEMPLATE = Path(__file__).resolve().parents[3] / ".github" / "ISSUE_TEMPLATE" / "bug_report.yml"


def _form(**overrides: str) -> BugForm:
    """Build a complete form with sensible values.

    Args:
        **overrides: Fields to replace.

    Returns:
        The form.
    """
    base = {
        "summary": "convert-v5 crashes on my mission",
        "happened": "It stopped with a traceback.",
        "expected": "It should have converted the mission.",
        "steps": "1. run convert-v5\n2. watch it fail",
        "doctor": doctor_block("6.16.3"),
        "reporter": "Someone",
        "reporter_id": "42",
        "language": "en",
    }
    base.update(overrides)
    return BugForm(**base)


class TestTheComponentTableIsTheTemplates(unittest.TestCase):
    def test_the_template_is_where_the_test_thinks_it_is(self) -> None:
        self.assertTrue(TEMPLATE.is_file(), f"no issue template at {TEMPLATE}")

    def test_every_component_written_is_an_option_the_template_offers(self) -> None:
        offered = TEMPLATE.read_text(encoding="utf-8")
        for _, component, _ in COMPONENT_RULES:
            with self.subTest(component=component):
                self.assertIn(component, offered)

    def test_the_catch_all_is_an_option_too(self) -> None:
        self.assertIn(UNKNOWN_COMPONENT, TEMPLATE.read_text(encoding="utf-8"))

    def test_the_longest_prefix_wins(self) -> None:
        """The updater sits inside the CLI's own tree, so order in the table is load-bearing."""
        self.assertEqual(component_for("src/python/veaf-tools/veaf-tools-updater.py")[0], "veaf-tools-updater.exe")
        self.assertEqual(component_for("src/python/veaf-tools/veaf_libs/x.py")[0], "veaf-tools.exe (Python CLI)")

    def test_a_path_the_table_does_not_cover_is_the_catch_all(self) -> None:
        self.assertEqual(component_for("something/else.py"), (UNKNOWN_COMPONENT, ""))


class TestTheTitle(unittest.TestCase):
    def test_a_claimed_version_is_prefixed(self) -> None:
        self.assertTrue(build_title(_form(), "6.16.3").startswith("[6.16.3] "))

    def test_an_unstated_version_puts_no_placeholder_in_the_title(self) -> None:
        self.assertNotIn(NOT_STATED, build_title(_form(), NOT_STATED))

    def test_a_long_summary_is_cut_not_wrapped(self) -> None:
        title = build_title(_form(summary="word " * 200), "6.16.3")
        self.assertLessEqual(len(title), TITLE_MAX_CHARS)
        self.assertTrue(title.endswith("…"))

    def test_an_empty_summary_still_yields_a_title(self) -> None:
        self.assertTrue(build_title(_form(summary="  "), NOT_STATED).strip())


class TestAssembly(unittest.TestCase):
    def setUp(self) -> None:
        self.checkout = fixture_checkout()

    def test_a_full_report_locates_the_fault_and_names_the_component(self) -> None:
        report = assemble(_form(happened=PYTHON_TRACEBACK), self.checkout)
        self.assertEqual(report.version, "6.16.3")
        self.assertEqual(report.component, "veaf-tools.exe (Python CLI)")
        self.assertIn("python", report.labels)
        self.assertIn(BASE_LABEL, report.labels)
        self.assertEqual(report.located[0].relative, "src/python/veaf-tools/mission_builder/sample.py")

    def test_a_lua_fault_is_a_lua_component(self) -> None:
        report = assemble(_form(happened=LUA_ERROR), self.checkout)
        self.assertEqual(report.component, "Lua runtime scripts (in-mission)")

    def test_a_report_with_no_trace_is_still_a_report(self) -> None:
        report = assemble(_form(), self.checkout)
        self.assertEqual(report.located, ())
        self.assertEqual(report.component, UNKNOWN_COMPONENT)
        self.assertEqual(report.version, "6.16.3")

    def test_a_missing_doctor_block_is_stated_and_the_version_is_not_invented(self) -> None:
        report = assemble(_form(doctor=""), self.checkout)
        self.assertEqual(report.version, NOT_STATED)
        self.assertTrue(any("doctor block" in note.subject for note in report.notes))

    def test_a_trace_pointing_at_a_file_that_no_longer_exists_says_so_with_the_revision(self) -> None:
        report = assemble(_form(happened=MISSING_TRACEBACK), self.checkout)
        self.assertEqual(report.located, ())
        note = next(note for note in report.notes if "removed_three_releases_ago" in note.subject)
        self.assertIn("absent from the checkout", note.reason)
        self.assertIn(report.freshness.revision, note.reason)

    def test_an_empty_required_field_is_listed_rather_than_left_blank(self) -> None:
        report = assemble(_form(steps="   "), self.checkout)
        self.assertTrue(any("steps" in note.subject for note in report.notes))

    def test_a_trace_that_only_appears_in_the_attached_log_is_located_too(self) -> None:
        report = assemble(_form(), self.checkout, extra_text=PYTHON_TRACEBACK)
        self.assertTrue(report.located)


class TestRedactionNeverFailsOpen(unittest.TestCase):
    def test_a_home_directory_in_a_typed_field_is_stripped(self) -> None:
        redacted, problem = safe_redact(fixture_checkout(), r"C:\Users\Firstname Lastname\dev")
        self.assertIsNone(problem)
        self.assertNotIn("Firstname Lastname", redacted)

    def test_an_unavailable_redactor_withholds_the_text_rather_than_publishing_it(self) -> None:
        from veaf_support_bot.checkout import Checkout

        nowhere = Checkout(Path("does-not-exist-anywhere"), refresh_seconds=0)
        redacted, problem = safe_redact(nowhere, r"C:\Users\Firstname Lastname\dev")
        self.assertIsNotNone(problem)
        self.assertNotIn("Firstname Lastname", redacted)


if __name__ == "__main__":
    unittest.main()
