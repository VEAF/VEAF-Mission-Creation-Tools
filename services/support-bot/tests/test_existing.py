"""Asking the documentation whether a suggestion already exists, and reading the answer.

The three verdicts are asserted one per test, and so are the two cases the module is shaped around:
an answer that merely *contains* the absence keyword is still an answer, and a documentation that
could not be consulted must never read as a documentation that said nothing.
"""

from __future__ import annotations

import asyncio
import unittest
from collections.abc import Sequence

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


def a_real_title(lang: str = "fr") -> str:
    """Return a documentation title the corpus really has, in the language being asked.

    Args:
        lang: ``"fr"`` or ``"en"``. A French title cited in an English answer resolves to nothing,
            and since ticket 06 an answer that cites nothing is read as silence — so a test that
            means to exercise *it exists* has to cite a page of the language it is checking.

    Returns:
        The first title of that corpus, so the link the check produces is a real page.
    """
    # A short, plain title: some real ones carry quotation marks and parentheses, which a
    # `Sources:` line renders but a test reads as noise when the match then fails for a reason that
    # has nothing to do with what it is asserting.
    return min((title for title in PAGES_BY_TITLE[lang] if title.isascii() and '"' not in title), key=len)


def check(
    worker: FakeWorker,
    request: str = REQUEST,
    lang: str = "fr",
    issues: Sequence[tuple[int, str]] = (),
) -> DocumentationCheck:
    """Run one check against a scripted Worker.

    Args:
        worker: The scripted Worker.
        request: What the user would like.
        lang: The language asked for.
        issues: The open issues offered for the second question.

    Returns:
        The finding.
    """
    return asyncio.run(AskTheDocumentation(worker).check(request, lang, "user-1", issues))


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

    def test_an_invented_page_leaves_the_answer_without_a_source(self) -> None:
        """A title the corpus does not have is dropped — and dropping it drops the claim with it.

        This case used to be *EXISTS with no link*, on the grounds that the title was unverifiable.
        Ticket 06 reads it the honest way instead: the model named a page that does not exist, so
        there is nothing for the asker to open and nothing that says his idea already exists.
        """
        worker = FakeWorker([f"Oui, c'est possible.\n{SOURCES_MARKER} Une page qui n'existe pas"])

        found = check(worker)

        self.assertEqual(found.verdict, ABSENT)
        self.assertEqual(found.links, ())

    def test_a_long_answer_is_bounded(self) -> None:
        worker = FakeWorker(["o" * (ANSWER_MAX_CHARS * 3) + f"\n{SOURCES_MARKER} {a_real_title()}"])

        self.assertEqual(len(check(worker).answer), ANSWER_MAX_CHARS)

    def test_it_says_what_was_asked_and_what_came_back(self) -> None:
        title = a_real_title()
        worker = FakeWorker([f"Oui.\n{SOURCES_MARKER} {title}"])

        described = check(worker).describe()

        self.assertIn("answered", described)
        self.assertIn(title, described)


class TestSayingItExistsNeedsAPageToOpen(unittest.TestCase):
    """Ticket 06, from the first real `/suggest` in front of a human.

    The bot announced *"la documentation semble déjà répondre à ta demande"* and displayed, as that
    answer, *"la documentation ne décrit pas de moyen de dessiner une route pour qu'un convoi la
    suive"* — the exact opposite of what it concluded. The model was told to answer a keyword when
    the documentation does not cover a subject and answered in prose instead, so the code saw no
    keyword and inferred presence.
    """

    def test_prose_with_no_citation_is_read_as_silence(self) -> None:
        found = check(FakeWorker(["La documentation ne décrit pas de moyen de faire cela."]))

        self.assertEqual(found.verdict, ABSENT)
        self.assertFalse(found.found)

    def test_prose_with_a_citation_still_says_it_exists(self) -> None:
        """The rule must not silence the answers it exists to keep."""
        found = check(FakeWorker([f"Oui, avec `_convoy`.\n{SOURCES_MARKER} {a_real_title()}"]))

        self.assertEqual(found.verdict, EXISTS)
        self.assertTrue(found.links)

    def test_the_keyword_still_works_decoration_and_all(self) -> None:
        found = check(FakeWorker([f"**{NOTHING_KEYWORD}**."]))

        self.assertEqual(found.verdict, ABSENT)


class TestARequestAlreadyMadeInOtherWords(unittest.TestCase):
    """Ticket 05. A duplicate was recognised by comparing words, and no two humans use the same ones.

    The tracker proves it: `#240 -cap un peu plus selectif`, `#187 Modifications du watchdog de CAP`
    and `#178 Gérer la destruction du -cap` are one subject in three vocabularies.
    """

    OPEN = ((240, "-cap un peu plus selectif"), (187, "Modifications du watchdog de CAP"))

    def test_the_open_issues_travel_in_the_call_the_flow_already_makes(self) -> None:
        """One call, two answers: joining the titles costs no extra model request."""
        worker = FakeWorker([f"**{NOTHING_KEYWORD}**."])

        check(worker, issues=self.OPEN)

        sent = "".join(turn["content"] for turn in worker.seen[0]["messages"])
        self.assertIn("#240", sent)
        self.assertIn("watchdog", sent)
        self.assertEqual(len(worker.seen), 1, "a second call would spend a second request")

    def test_a_reformulation_is_recognised(self) -> None:
        found = check(FakeWorker([f"**{NOTHING_KEYWORD}**.\nISSUE #240"]), issues=self.OPEN)

        self.assertEqual(found.issue, 240)

    def test_an_issue_it_was_not_offered_is_refused(self) -> None:
        """A model naming #999 would send the asker to an issue nobody wrote."""
        found = check(FakeWorker([f"**{NOTHING_KEYWORD}**.\nISSUE #999"]), issues=self.OPEN)

        self.assertEqual(found.issue, 0)

    def test_no_line_means_no_match(self) -> None:
        found = check(FakeWorker([f"**{NOTHING_KEYWORD}**."]), issues=self.OPEN)

        self.assertEqual(found.issue, 0)

    def test_the_marker_line_is_not_shown_to_the_asker(self) -> None:
        """It is an instruction to this code, like the idempotency marker in a Discord preview."""
        found = check(
            FakeWorker([f"Oui, avec `_convoy`.\n{SOURCES_MARKER} {a_real_title()}\nISSUE #240"]),
            issues=self.OPEN,
        )

        self.assertEqual(found.issue, 240)
        self.assertNotIn("ISSUE #240", found.answer)

    def test_with_no_issues_offered_the_question_is_not_asked_at_all(self) -> None:
        worker = FakeWorker([f"**{NOTHING_KEYWORD}**."])

        check(worker)

        sent = "".join(turn["content"] for turn in worker.seen[0]["messages"])
        self.assertNotIn("ISSUE", sent)


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
        found = check(
            FakeWorker(
                [f"{NOTHING_KEYWORD} is documented about the radio menu.\n{SOURCES_MARKER} {a_real_title('en')}"]
            ),
            lang="en",
        )

        self.assertEqual(found.verdict, EXISTS)

    def test_prose_containing_the_word_is_an_answer_not_an_absence(self) -> None:
        """The failure this bound exists for: a real answer thrown away for using the word."""
        worker = FakeWorker(
            [
                "There is nothing stopping you: the `_convoy` command already does this."
                f"\n{SOURCES_MARKER} {a_real_title('en')}"
            ]
        )

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
