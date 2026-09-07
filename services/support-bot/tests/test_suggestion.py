"""What a submitted idea becomes, and the one thing that can rot silently.

The component list writes the options of ``.github/ISSUE_TEMPLATE/feature_request.yml`` into a filed
issue, so a renamed option there would leave the bot writing a component nobody can filter on — with
every other test in this file still green, since they only compare strings to themselves.
"""

from __future__ import annotations

import unittest
from pathlib import Path

from veaf_support_bot.existing import ABSENT, EXISTS, UNKNOWN, DocumentationCheck
from veaf_support_bot.issue_body import marker_for
from veaf_support_bot.priorart import SOURCE_BACKLOG, Candidate, Match, Sweep
from veaf_support_bot.suggestion import (
    COMPONENTS,
    TITLE_MAX_CHARS,
    SuggestionForm,
    build_title,
    language_of,
    render_suggestion_body,
    suggestion_key,
)

#: The repository's own issue template, read for real.
TEMPLATE = Path(__file__).resolve().parents[3] / ".github" / "ISSUE_TEMPLATE" / "feature_request.yml"


def a_form(**overrides: str) -> SuggestionForm:
    """Build a complete form.

    Args:
        **overrides: Fields to replace.

    Returns:
        The form.
    """
    base = {
        "summary": "Convoys along a drawn route",
        "problem": "Placing a convoy by hand takes ten minutes per mission.",
        "solution": "Let me draw a route and have the convoy follow it.",
        "asker": "Someone",
        "asker_id": "42",
        "language": "en",
    }
    base.update(overrides)
    return SuggestionForm(**base)


def a_body(form: SuggestionForm | None = None, **kwargs: object) -> str:
    """Render an issue body with sensible defaults.

    Args:
        form: The form; a default one when omitted.
        **kwargs: Passed through to the renderer.

    Returns:
        The Markdown body.
    """
    form = form or a_form()
    check = kwargs.pop("check", DocumentationCheck(verdict=ABSENT))
    return render_suggestion_body(form, "key123", check=check, **kwargs)  # type: ignore[arg-type]


class TestTheComponentListIsReal(unittest.TestCase):
    """The list is only useful if it is the template's."""

    def test_every_component_exists_in_the_template(self) -> None:
        template = TEMPLATE.read_text(encoding="utf-8")

        for component in COMPONENTS:
            with self.subTest(component=component):
                self.assertIn(component, template)

    def test_the_template_is_where_it_is_expected(self) -> None:
        self.assertTrue(TEMPLATE.is_file(), TEMPLATE)


class TestTheRequiredFields(unittest.TestCase):
    """A solution with no problem cannot be weighed against anything."""

    def test_a_blank_problem_is_missing(self) -> None:
        self.assertEqual(a_form(problem="   ").missing_fields(), ("problem",))

    def test_a_complete_form_is_missing_nothing(self) -> None:
        self.assertEqual(a_form().missing_fields(), ())

    def test_the_optional_fields_are_optional(self) -> None:
        self.assertEqual(a_form(alternatives="", context="").missing_fields(), ())


class TestTheIdentity(unittest.TestCase):
    """The same suggestion twice is one issue, so the key comes from the content alone."""

    def test_the_same_form_gives_the_same_key(self) -> None:
        self.assertEqual(suggestion_key(a_form()), suggestion_key(a_form()))

    def test_a_different_asker_gives_a_different_key(self) -> None:
        self.assertNotEqual(suggestion_key(a_form()), suggestion_key(a_form(asker_id="43")))

    def test_a_changed_word_gives_a_different_key(self) -> None:
        self.assertNotEqual(suggestion_key(a_form()), suggestion_key(a_form(solution="something else")))

    def test_the_key_is_in_the_body_as_a_hidden_marker(self) -> None:
        self.assertIn(marker_for("key123"), a_body())


class TestTheTitle(unittest.TestCase):
    """The title is the asker's own summary, bounded."""

    def test_it_is_the_summary(self) -> None:
        self.assertEqual(build_title(a_form(summary="Add a thing")), "Add a thing")

    def test_it_is_bounded(self) -> None:
        self.assertLessEqual(len(build_title(a_form(summary="x" * 400))), TITLE_MAX_CHARS)

    def test_an_empty_summary_still_gives_a_title(self) -> None:
        self.assertNotEqual(build_title(a_form(summary="  ")), "")


class TestTheBody(unittest.TestCase):
    """It reads like a hand-filled feature request, in the asker's language."""

    def test_it_carries_the_template_sections(self) -> None:
        body = a_body()

        for expected in ("Component", "What problem does this solve?", "Proposed solution"):
            with self.subTest(section=expected):
                self.assertIn(expected, body)

    def test_it_is_written_in_the_askers_language(self) -> None:
        self.assertIn("Quel problème cela résout-il ?", a_body(a_form(language="fr")))

    def test_an_unknown_locale_falls_back_to_english(self) -> None:
        self.assertEqual(language_of(a_form(language="de")), "en")

    def test_an_empty_optional_section_is_omitted(self) -> None:
        self.assertNotIn("Alternatives considered", a_body(a_form(alternatives="")))

    def test_a_filled_optional_section_is_kept(self) -> None:
        self.assertIn("Alternatives considered", a_body(a_form(alternatives="a trigger")))

    def test_the_askers_text_is_quoted_so_it_cannot_escape(self) -> None:
        body = a_body(a_form(problem="### Not a heading\n@everyone"))

        self.assertIn("```", body)
        self.assertNotIn("@everyone", body)

    def test_it_says_no_sketch_was_made(self) -> None:
        self.assertIn("No technical sketch", a_body())

    def test_it_credits_the_asker_and_the_bot(self) -> None:
        body = a_body()

        self.assertIn("Someone", body)
        self.assertIn("support bot", body)

    def test_a_thread_is_linked_when_there_is_one(self) -> None:
        self.assertIn("https://discord.test/1", a_body(thread_url="https://discord.test/1"))

    def test_no_thread_says_so_rather_than_inventing_one(self) -> None:
        self.assertIn("not recorded", a_body())


class TestWhatWasChecked(unittest.TestCase):
    """A reader three months later must not have to redo the search."""

    def test_an_answered_documentation_is_recorded_with_its_pages(self) -> None:
        check = DocumentationCheck(verdict=EXISTS, answer="The `_convoy` command does this.", links=("[page](u)",))

        body = a_body(check=check)

        self.assertIn("_convoy", body)
        self.assertIn("[page](u)", body)
        self.assertIn("the request was maintained regardless", body)

    def test_a_silent_documentation_is_flagged_as_a_possible_gap(self) -> None:
        body = a_body(check=DocumentationCheck(verdict=ABSENT))

        self.assertIn("documentation gap", body)

    def test_an_unreachable_documentation_never_reads_as_a_silent_one(self) -> None:
        """The distinction the whole verdict exists for."""
        unreachable = a_body(check=DocumentationCheck(verdict=UNKNOWN, problem="timeout"))
        silent = a_body(check=DocumentationCheck(verdict=ABSENT))

        self.assertIn("could not be asked", unreachable)
        self.assertNotIn("documentation gap", unreachable)
        self.assertNotIn("could not be asked", silent)

    def test_the_sweep_is_recorded_with_its_evidence(self) -> None:
        sweep = Sweep(
            verdict="in-progress",
            best=Match(Candidate(SOURCE_BACKLOG, "FEAT-X", "a lot", url=".backlog/FEAT-X/PRD.md"), 0.5, ("convoy",)),
            checked=("28 open backlog lot(s)",),
        )

        body = a_body(sweep=sweep)

        self.assertIn("FEAT-X", body)
        self.assertIn("convoy", body)
        self.assertIn("28 open backlog lot(s)", body)

    def test_no_sweep_records_only_the_documentation(self) -> None:
        self.assertNotIn("Prior art checked", a_body(sweep=None))
