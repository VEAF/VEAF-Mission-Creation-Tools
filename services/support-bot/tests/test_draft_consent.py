"""Ticket 04: what the reporter is shown, and what his click does — or does not — publish.

Two properties carry the whole ticket, and both are asserted on the **production** path rather than
on a rendering helper:

* **Nothing reaches GitHub before the click.** Not a preview that resembles the issue and a filing
  that happens anyway: the filer is asked for the draft, the reporter is asked, and only then is
  anything filed. Every other answer — edit, cancel, silence — leaves the tracker untouched.
* **What he is shown is what will be published.** The draft is the filer's own body, so a preview
  that drifts from the issue is a test failure rather than a surprise on a public tracker.

The rest is the cutting: a report does not fit in a Discord message, and a preview that cuts
silently is a preview that lies about the part he did not write.
"""

from __future__ import annotations

import unittest
from typing import Any

from tests.test_intake_github_wiring import _Exchange, _Filer, _intake, _submission
from veaf_support_bot.draft import (
    CANCEL,
    DRAFT_MAX_CHARS,
    EDIT,
    EXPIRED,
    FILE,
    Draft,
    fold,
)
from veaf_support_bot.intake import (
    ESCALATED_ANSWER_CHARS,
    ESCALATED_QUESTION_CHARS,
    PARAGRAPH_MAX_CHARS,
    SUMMARY_MAX_CHARS,
    escalation_form,
)
from veaf_support_bot.texts import text


def _long_body(lines: int = 400) -> str:
    """Build a body no Discord message can hold.

    Args:
        lines: How many lines it has.

    Returns:
        The body.
    """
    return "\n".join(f"line {index} of a report that is far too long to preview" for index in range(lines))


class TestTheDraftIsTheIssue(unittest.IsolatedAsyncioTestCase):
    """The preview is the body that will be sent, not a second rendering of it."""

    async def test_what_is_shown_is_the_body_the_filer_would_publish(self) -> None:
        filer = _Filer()
        exchange = _Exchange(decision=FILE)

        report = await _intake(filer=filer).handle(exchange, _submission())

        assert report is not None
        self.assertIn(filer.draft_of(report).body, exchange.drafts[0])

    async def test_the_title_is_shown_with_the_body(self) -> None:
        exchange = _Exchange(decision=CANCEL)

        report = await _intake(filer=_Filer()).handle(exchange, _submission())

        assert report is not None
        self.assertIn(report.title, exchange.drafts[0])


class TestNothingIsFiledBeforeTheClick(unittest.IsolatedAsyncioTestCase):
    """The one irreversible step of this flow, and the only gate in front of it."""

    async def test_the_draft_is_shown_before_anything_is_filed(self) -> None:
        filer = _Filer()
        exchange = _Exchange(decision=FILE)

        await _intake(filer=filer).handle(exchange, _submission())

        self.assertEqual(len(exchange.drafts), 1)
        self.assertEqual(len(filer.filed), 1)

    async def test_a_cancelled_draft_files_nothing_and_says_so(self) -> None:
        filer = _Filer()
        exchange = _Exchange(decision=CANCEL)

        await _intake(filer=filer).handle(exchange, _submission())

        self.assertEqual(filer.filed, [])
        self.assertEqual(exchange.messages[0], text("draft.cancelled", "en"))

    async def test_an_expired_draft_files_nothing_and_says_it_expired(self) -> None:
        filer = _Filer()
        exchange = _Exchange(decision=EXPIRED)

        await _intake(filer=filer).handle(exchange, _submission())

        self.assertEqual(filer.filed, [])
        # Distinguished from a cancellation on purpose: a reporter who walked away must be able to
        # tell that his report lapsed rather than that he dropped it.
        self.assertEqual(exchange.messages[0], text("draft.expired", "en"))
        self.assertNotEqual(text("draft.expired", "en"), text("draft.cancelled", "en"))

    async def test_an_edited_draft_files_nothing_and_points_at_the_reopened_form(self) -> None:
        filer = _Filer()
        exchange = _Exchange(decision=EDIT)

        await _intake(filer=filer).handle(exchange, _submission())

        self.assertEqual(filer.filed, [])
        self.assertEqual(exchange.messages[0], text("draft.editing", "en"))

    async def test_an_unknown_answer_is_treated_as_a_refusal(self) -> None:
        """Fail closed: an answer nobody wrote a case for must not publish."""
        filer = _Filer()
        exchange = _Exchange(decision="something the ui never sends")

        await _intake(filer=filer).handle(exchange, _submission())

        self.assertEqual(filer.filed, [])

    async def test_an_accepted_duplicate_shows_the_comment_and_opens_no_issue(self) -> None:
        """The other thing this flow publishes, and it goes through the same click."""
        from tests.test_intake_github_wiring import _gate
        from tests.test_priorart import _resolver_issue

        filer = _Filer()
        exchange = _Exchange(recognises=True, decision=CANCEL)

        await _intake(prior_art=_gate(opened=[_resolver_issue()]), filer=filer).handle(exchange, _submission())

        # The double renders comments as "observation on <title>", so this is the comment body
        # and not the issue body — the two are different publications and get different previews.
        self.assertIn("observation on", exchange.drafts[0])
        self.assertEqual((filer.filed, filer.commented), ([], []))


class TestTruncationIsAnnounced(unittest.TestCase):
    """A cut nobody is told about is a preview that misrepresents what gets published."""

    def test_a_short_body_is_shown_whole_with_no_notice(self) -> None:
        rendered = Draft(title="short", body="one line").render("en")

        self.assertIn("one line", rendered)
        self.assertNotIn("Preview cut here", rendered)

    def test_a_long_body_is_cut_within_discords_ceiling(self) -> None:
        rendered = Draft(title="long", body=_long_body()).render("en")

        self.assertLessEqual(len(rendered), DRAFT_MAX_CHARS)

    def test_a_long_body_says_how_much_it_left_out(self) -> None:
        body = _long_body()

        rendered = Draft(title="long", body=body).render("en")

        self.assertIn("more lines", rendered)
        # The count is the real one, not a placeholder: a notice saying "a few more lines" is the
        # same lie as no notice at all.
        kept, lines, chars = fold(body, 500)
        self.assertEqual(chars, len(body) - len(kept))
        self.assertEqual(lines, body[len(kept) :].count("\n"))

    def test_the_cut_falls_on_a_line_boundary(self) -> None:
        kept, _, _ = fold(_long_body(), 500)

        self.assertFalse(kept.endswith(" of a report"), "a mid-sentence cut reads as corruption")
        self.assertTrue(_long_body().startswith(kept))

    def test_a_fenced_block_the_cut_ran_through_is_closed(self) -> None:
        body = "before\n```\n" + "\n".join(f"log line {index}" for index in range(200)) + "\n```\n"

        kept, _, _ = fold(body, 400)

        self.assertEqual(kept.count("```") % 2, 0, "an unclosed fence swallows the rest of the message")

    def test_a_body_that_is_all_one_line_is_still_cut(self) -> None:
        """No line boundary to prefer, and the ceiling still has to hold."""
        rendered = Draft(title="one line", body="x" * 5000).render("en")

        self.assertLessEqual(len(rendered), DRAFT_MAX_CHARS)
        self.assertIn("more lines", rendered)


class TestTheEscalatedForm(unittest.TestCase):
    """What ``/ask`` carries into ``/bug`` when its answer did not help."""

    def _form(self, question: str = "how do I set a QRA?", answer: str = "you cannot") -> Any:
        """Build an escalated form.

        Args:
            question: What was asked.
            answer: What the bot replied.

        Returns:
            The form.
        """
        return escalation_form(question, answer, reporter="Tripack", reporter_id="4242", language="en")

    def test_the_exchange_is_carried_into_what_happened(self) -> None:
        form = self._form()

        self.assertIn("how do I set a QRA?", form.happened)
        self.assertIn("you cannot", form.happened)

    def test_the_summary_is_the_question(self) -> None:
        self.assertIn("QRA", self._form().summary)

    def test_what_was_expected_is_left_for_the_reporter_to_write(self) -> None:
        """The exchange is the observation; the report is still his to make."""
        form = self._form()

        self.assertEqual((form.expected, form.steps), ("", ""))

    def test_a_long_exchange_stays_inside_what_a_modal_accepts(self) -> None:
        """Discord refuses a modal whose pre-filled value overflows: too long means *no form*."""
        form = self._form(question="q" * 4000, answer="a" * 9000)

        self.assertLessEqual(len(form.summary), SUMMARY_MAX_CHARS)
        self.assertLessEqual(len(form.happened), PARAGRAPH_MAX_CHARS)
        self.assertLess(ESCALATED_QUESTION_CHARS + ESCALATED_ANSWER_CHARS, PARAGRAPH_MAX_CHARS)
