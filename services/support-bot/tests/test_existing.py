"""Asking the documentation whether a suggestion already exists, and reading the answer.

The three verdicts are asserted one per test, and so are the two cases the module is shaped around:
an answer that merely *contains* the absence keyword is still an answer, and a documentation that
could not be consulted must never read as a documentation that said nothing.
"""

from __future__ import annotations

import asyncio
import unittest

from tests.fakes import FakeWorker
from veaf_support_bot.answer import SOURCES_MARKER
from veaf_support_bot.doc_pages_data import PAGES_BY_TITLE
from veaf_support_bot.existing import (
    ABSENT,
    ANSWER_MAX_CHARS,
    EXISTS,
    NOTHING_KEYWORD,
    UNKNOWN,
    AskTheDocumentation,
    DocumentationCheck,
    says_nothing,
)
from veaf_support_bot.worker import FailureKind, WorkerFailure

#: A request phrased the way a mission maker phrases one.
REQUEST = "Je voudrais pouvoir faire apparaitre un convoi qui suit une route que je dessine."


def a_real_title() -> str:
    """Return a documentation title the corpus really has.

    Returns:
        The first French title, so the link the check produces is a real page rather than a shape.
    """
    return sorted(PAGES_BY_TITLE["fr"])[0]


def check(worker: FakeWorker, request: str = REQUEST, lang: str = "fr") -> DocumentationCheck:
    """Run one check against a scripted Worker.

    Args:
        worker: The scripted Worker.
        request: What the user would like.
        lang: The language asked for.

    Returns:
        The finding.
    """
    return asyncio.run(AskTheDocumentation(worker).check(request, lang, "user-1"))


class TestTheDocumentationAnswers(unittest.TestCase):
    """The documentation describes a way to do it."""

    def test_the_answer_and_its_pages_are_kept(self) -> None:
        title = a_real_title()
        worker = FakeWorker(["Oui : la commande `_convoy` ", f"suit une route.\n{SOURCES_MARKER} {title}"])

        found = check(worker)

        self.assertEqual(found.verdict, EXISTS)
        self.assertTrue(found.found)
        self.assertIn("_convoy", found.answer)
        self.assertNotIn(SOURCES_MARKER, found.answer)
        self.assertEqual(len(found.links), 1)
        self.assertIn(title, found.links[0])

    def test_an_invented_page_is_not_linked(self) -> None:
        """A title the corpus does not have is dropped rather than turned into a dead link."""
        worker = FakeWorker([f"Oui, c'est possible.\n{SOURCES_MARKER} Une page qui n'existe pas"])

        found = check(worker)

        self.assertEqual(found.verdict, EXISTS)
        self.assertEqual(found.links, ())

    def test_a_long_answer_is_bounded(self) -> None:
        worker = FakeWorker(["o" * (ANSWER_MAX_CHARS * 3)])

        self.assertEqual(len(check(worker).answer), ANSWER_MAX_CHARS)

    def test_it_says_what_was_asked_and_what_came_back(self) -> None:
        title = a_real_title()
        worker = FakeWorker([f"Oui.\n{SOURCES_MARKER} {title}"])

        described = check(worker).describe()

        self.assertIn("answered", described)
        self.assertIn(title, described)


class TestTheDocumentationIsSilent(unittest.TestCase):
    """The documentation says nothing about it, which is a finding of its own."""

    def test_the_keyword_alone_is_an_absence(self) -> None:
        worker = FakeWorker([NOTHING_KEYWORD])

        found = check(worker)

        self.assertEqual(found.verdict, ABSENT)
        self.assertFalse(found.found)
        self.assertEqual(found.answer, "")

    def test_the_keyword_survives_the_decoration_a_model_adds(self) -> None:
        for body in (f"**{NOTHING_KEYWORD}**", f"`{NOTHING_KEYWORD}`.", f" {NOTHING_KEYWORD} "):
            with self.subTest(body=body):
                self.assertEqual(check(FakeWorker([body])).verdict, ABSENT)

    def test_the_keyword_with_its_empty_trailer_is_still_an_absence(self) -> None:
        self.assertEqual(check(FakeWorker([f"{NOTHING_KEYWORD}\n{SOURCES_MARKER}"])).verdict, ABSENT)

    def test_a_short_sentence_beginning_with_the_keyword_is_still_an_answer(self) -> None:
        """The prefix match this used to do discarded it as silence."""
        found = check(FakeWorker([f"{NOTHING_KEYWORD} is documented about the radio menu."]), lang="en")

        self.assertEqual(found.verdict, EXISTS)

    def test_prose_containing_the_word_is_an_answer_not_an_absence(self) -> None:
        """The failure this bound exists for: a real answer thrown away for using the word."""
        worker = FakeWorker(["There is nothing stopping you: the `_convoy` command already does this."])

        found = check(worker, lang="en")

        self.assertEqual(found.verdict, EXISTS)
        self.assertIn("_convoy", found.answer)

    def test_it_says_the_documentation_was_asked(self) -> None:
        self.assertIn("says nothing", check(FakeWorker([NOTHING_KEYWORD])).describe())


class TestTheDocumentationCannotBeAsked(unittest.TestCase):
    """Nobody could ask is not the same as nothing was found, and must not read as it."""

    def test_an_upstream_failure_is_a_finding_not_an_exception(self) -> None:
        worker = FakeWorker(failure=WorkerFailure(FailureKind.UNAVAILABLE, "connection refused"))

        found = check(worker)

        self.assertEqual(found.verdict, UNKNOWN)
        self.assertEqual(found.problem, FailureKind.UNAVAILABLE.value)

    def test_an_empty_answer_is_unknown_rather_than_absent(self) -> None:
        found = check(FakeWorker(["   "]))

        self.assertEqual(found.verdict, UNKNOWN)
        self.assertEqual(found.problem, "empty")

    def test_it_says_the_documentation_was_not_consulted(self) -> None:
        worker = FakeWorker(failure=WorkerFailure(FailureKind.TIMEOUT, "too slow"))

        described = check(worker).describe()

        self.assertIn("could not be asked", described)
        self.assertIn(FailureKind.TIMEOUT.value, described)

    def test_nothing_consulted_is_the_default(self) -> None:
        self.assertEqual(DocumentationCheck().verdict, UNKNOWN)


class TestWhatTheWorkerIsSent(unittest.TestCase):
    """The retrieval query is the request itself, and the instruction rides in an earlier turn."""

    def test_the_request_is_the_last_turn_and_is_untouched(self) -> None:
        worker = FakeWorker([NOTHING_KEYWORD])

        check(worker)

        turns = worker.seen[0]["messages"]
        self.assertEqual(turns[-1], {"role": "user", "content": REQUEST})

    def test_the_instruction_never_reaches_the_retrieval_query(self) -> None:
        """Appending it to the request would poison the search with the instruction's own words."""
        worker = FakeWorker([NOTHING_KEYWORD])

        check(worker)

        turns = worker.seen[0]["messages"]
        self.assertIn(NOTHING_KEYWORD, turns[0]["content"])
        self.assertNotIn(NOTHING_KEYWORD, turns[-1]["content"])
        self.assertIn(SOURCES_MARKER, turns[0]["content"])

    def test_the_language_and_the_subject_are_carried(self) -> None:
        worker = FakeWorker([NOTHING_KEYWORD])

        asyncio.run(AskTheDocumentation(worker).check(REQUEST, "en", "user-42"))

        self.assertEqual(worker.seen[0]["lang"], "en")
        self.assertEqual(worker.seen[0]["subject"], "user-42")


class TestSaysNothing(unittest.TestCase):
    """The bound between the keyword and prose that merely starts with it."""

    def test_a_long_body_is_never_the_keyword(self) -> None:
        self.assertFalse(says_nothing(f"{NOTHING_KEYWORD} " + "x" * 100))

    def test_an_empty_body_is_not_the_keyword(self) -> None:
        self.assertFalse(says_nothing(""))

    def test_a_sentence_starting_with_the_keyword_is_an_answer(self) -> None:
        """Reported by review: a prefix match throws away a real, short answer."""
        self.assertFalse(says_nothing(f"{NOTHING_KEYWORD} is documented about it"))
        self.assertFalse(says_nothing(f"{NOTHING_KEYWORD}NESS"))
