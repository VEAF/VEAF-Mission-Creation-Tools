"""The order of the ``/suggest`` steps, and the two ways a request settles without an issue.

The point of asserting on the order is that the bugs this flow can ship are *in* the order: the
documentation is asked before anything is drafted, the sweep runs before anything is opened, and
nothing reaches GitHub before the click. All of that is observable here without a Discord
connection.
"""

from __future__ import annotations

import asyncio
import tempfile
import unittest
from collections.abc import Sequence
from pathlib import Path

from tests.intake_fixtures import fixture_root
from tests.test_priorart import RESOLVER_REPORT
from veaf_support_bot.draft import CANCEL, EXPIRED, FILE
from veaf_support_bot.exchange import ThreadHandle
from veaf_support_bot.existing import ABSENT, EXISTS, UNKNOWN, DocumentationCheck
from veaf_support_bot.filing import Outcome
from veaf_support_bot.priorart import PriorArtGate, PriorArtSweeper
from veaf_support_bot.quota import QuotaKeeper, QuotaLimits, QuotaStore
from veaf_support_bot.suggest import SuggestIntake, SuggestSubmission, render_outcome
from veaf_support_bot.suggestion import BASE_LABEL, SuggestionForm
from veaf_support_bot.texts import text

#: A request phrased the way a mission maker phrases one.
REQUEST = "Je voudrais pouvoir faire apparaitre un convoi qui suit une route que je dessine."


def a_form(**overrides: str) -> SuggestionForm:
    """Build a submitted form.

    Args:
        **overrides: Fields to replace.

    Returns:
        The form.
    """
    base = {
        "summary": "Convois sur route dessinee",
        "problem": "Placer un convoi a la main prend dix minutes par mission.",
        "solution": REQUEST,
        "asker": "Someone",
        "asker_id": "42",
        "language": "fr",
    }
    base.update(overrides)
    return SuggestionForm(**base)


class RecordingExchange:
    """Records the order the exchange was driven in, and answers the way a script says to."""

    def __init__(self, *, confirms: Sequence[bool] = (), choice: str = CANCEL) -> None:
        """Initialize the stand-in.

        Args:
            confirms: What each successive yes-or-no question is answered, oldest first. Missing
                answers are ``False``, which is how an unreachable person answers.
            choice: What is done with the draft.
        """
        self.calls: list[str] = []
        self.posted: list[str] = []
        self.shown: list[str] = []
        self.thread_messages: list[str] = []
        self._confirms = list(confirms)
        self._choice = choice

    async def defer(self) -> None:
        self.calls.append("defer")

    async def post(self, content: str) -> None:
        self.calls.append("post")
        self.posted.append(content)

    async def decide(self, content: str, lang: str) -> str:
        self.calls.append("decide")
        self.shown.append(content)
        return self._choice

    async def confirm(self, content: str, lang: str) -> bool:
        self.calls.append("confirm")
        self.shown.append(content)
        return self._confirms.pop(0) if self._confirms else False

    async def open_followup_thread(self, name: str) -> ThreadHandle:
        self.calls.append("open_followup_thread")
        return ThreadHandle(channel_id=10, thread_id=20, url="https://discord.test/threads/20")

    async def post_in_thread(self, handle: ThreadHandle, content: str) -> None:
        self.calls.append("post_in_thread")
        self.thread_messages.append(content)


class ScriptedDocumentation:
    """An :class:`~veaf_support_bot.existing.AskTheDocumentation` stand-in."""

    def __init__(self, finding: DocumentationCheck) -> None:
        self.finding = finding
        self.asked: list[tuple[str, str, str]] = []

    async def check(self, request: str, lang: str, subject: str) -> DocumentationCheck:
        self.asked.append((request, lang, subject))
        return self.finding


class RecordingFiler:
    """A :class:`~veaf_support_bot.suggest.PreparedFiler` that records what it was asked to file."""

    machine_label = "filed-by-bot"

    def __init__(self, outcome: Outcome | None = None) -> None:
        self.filed: list[dict[str, object]] = []
        self._outcome = outcome or Outcome(action="created", number=7, url="https://github.test/issues/7")

    async def file_prepared(self, key: str, title: str, body: str, labels: Sequence[str]) -> Outcome:
        self.filed.append({"key": key, "title": title, "body": body, "labels": tuple(labels)})
        return self._outcome


class RecordingTracker:
    """A tracker that records what it was told to remember."""

    def __init__(self) -> None:
        self.remembered: list[tuple[int, int, int, str]] = []

    def remember(self, issue: int, *, channel_id: int, thread_id: int, lang: str) -> None:
        self.remembered.append((issue, channel_id, thread_id, lang))


class Clock:
    """A monotonic clock a test drives by hand.

    Attributes:
        readings: What each successive call returns; the last value repeats once exhausted.
    """

    def __init__(self, *readings: float) -> None:
        self.readings = list(readings) or [0.0]

    def __call__(self) -> float:
        return self.readings.pop(0) if len(self.readings) > 1 else self.readings[0]


def run(intake: SuggestIntake, exchange: RecordingExchange, form: SuggestionForm | None = None) -> Outcome | None:
    """Run one exchange.

    Args:
        intake: The flow under test.
        exchange: The Discord stand-in.
        form: The submitted form; a default one when omitted.

    Returns:
        What the flow returned.
    """
    return asyncio.run(intake.handle(exchange, SuggestSubmission(form=form or a_form())))


class TestTheDocumentationComesFirst(unittest.TestCase):
    """Nothing is drafted before the documentation has been asked."""

    def test_it_is_asked_before_anything_is_shown(self) -> None:
        documentation = ScriptedDocumentation(DocumentationCheck(verdict=ABSENT))
        exchange = RecordingExchange()

        run(SuggestIntake(documentation=documentation), exchange)

        self.assertEqual(len(documentation.asked), 1)
        self.assertEqual(exchange.calls[0], "defer")

    def test_the_whole_form_is_what_is_asked_about(self) -> None:
        documentation = ScriptedDocumentation(DocumentationCheck(verdict=ABSENT))
        form = a_form()

        run(SuggestIntake(documentation=documentation), RecordingExchange(), form)

        asked, lang, subject = documentation.asked[0]
        self.assertIn(form.problem, asked)
        self.assertIn(form.solution, asked)
        self.assertEqual((lang, subject), ("fr", "42"))

    def test_an_answer_the_asker_accepts_opens_nothing(self) -> None:
        documentation = ScriptedDocumentation(
            DocumentationCheck(verdict=EXISTS, answer="La commande `_convoy` fait cela.", links=("[p](u)",))
        )
        filer = RecordingFiler()
        exchange = RecordingExchange(confirms=[True])

        outcome = run(SuggestIntake(documentation=documentation, filer=filer), exchange)

        self.assertIsNone(outcome)
        self.assertEqual(filer.filed, [])
        self.assertNotIn("decide", exchange.calls)
        self.assertIn("_convoy", exchange.shown[0])
        self.assertIn("[p](u)", exchange.shown[0])

    def test_an_answer_the_asker_rejects_carries_on(self) -> None:
        """The failure mode this step is shaped around: a real idea must survive a wrong match."""
        documentation = ScriptedDocumentation(DocumentationCheck(verdict=EXISTS, answer="Autre chose."))
        filer = RecordingFiler()
        exchange = RecordingExchange(confirms=[False], choice=FILE)

        outcome = run(SuggestIntake(documentation=documentation, filer=filer), exchange)

        self.assertIsNotNone(outcome)
        self.assertEqual(len(filer.filed), 1)

    def test_a_silent_documentation_is_never_put_to_the_asker(self) -> None:
        documentation = ScriptedDocumentation(DocumentationCheck(verdict=ABSENT))
        exchange = RecordingExchange(choice=CANCEL)

        run(SuggestIntake(documentation=documentation, filer=RecordingFiler()), exchange)

        self.assertNotIn("confirm", exchange.calls)

    def test_what_the_documentation_said_reaches_the_issue(self) -> None:
        """Specifically *what* it said: all three verdicts mention the documentation."""
        documentation = ScriptedDocumentation(DocumentationCheck(verdict=ABSENT))
        filer = RecordingFiler()

        run(
            SuggestIntake(documentation=documentation, filer=filer),
            RecordingExchange(choice=FILE),
            a_form(language="en"),
        )

        body = str(filer.filed[0]["body"])
        self.assertIn("it says nothing about this", body)
        self.assertNotIn("could not be asked", body)

    def test_an_unreachable_documentation_does_not_stop_the_suggestion(self) -> None:
        documentation = ScriptedDocumentation(DocumentationCheck(verdict=UNKNOWN, problem="unavailable"))
        filer = RecordingFiler()

        outcome = run(SuggestIntake(documentation=documentation, filer=filer), RecordingExchange(choice=FILE))

        self.assertIsNotNone(outcome)
        self.assertIn("unavailable", str(filer.filed[0]["body"]))

    def test_no_documentation_configured_says_so_in_the_issue(self) -> None:
        filer = RecordingFiler()

        run(SuggestIntake(filer=filer), RecordingExchange(choice=FILE), a_form(language="en"))

        self.assertIn("could not be asked", str(filer.filed[0]["body"]))
        self.assertIn("not configured", str(filer.filed[0]["body"]))


class TestTheQuota(unittest.TestCase):
    """The documentation question is one model call, and it is charged as one."""

    def test_a_spent_allowance_does_not_refuse_the_suggestion(self) -> None:
        documentation = ScriptedDocumentation(DocumentationCheck(verdict=EXISTS, answer="x"))
        filer = RecordingFiler()

        outcome = run(
            SuggestIntake(documentation=documentation, quota=_spent_quota(), filer=filer),
            RecordingExchange(choice=FILE),
        )

        self.assertIsNotNone(outcome)
        self.assertEqual(documentation.asked, [])
        self.assertIn("quota", str(filer.filed[0]["body"]))


def _spent_quota() -> QuotaKeeper:
    """Return a real quota keeper with nothing left to spend.

    A stand-in would prove less: what the flow must survive is the production keeper's own refusal,
    counters and all.

    Returns:
        The keeper.
    """
    directory = tempfile.mkdtemp(prefix="veaf-suggest-quota-")
    return QuotaKeeper(
        QuotaLimits(user_window_seconds=60.0, user_per_window=0, user_per_day=0, global_per_day=0),
        QuotaStore(Path(directory) / "quota.json"),
    )


#: The lot the miniature fixture repository carries, and which the request below matches.
FIXTURE_LOT = "FEAT-SAMPLE-RESOLVER"


def a_matching_form(**overrides: str) -> SuggestionForm:
    """Build a request the fixture's open lot really answers.

    The words matter: the sweep scores the *whole* form against the lot, so padding it with
    unrelated prose drops the score below the threshold and the match disappears. Three tests were
    green that way, proving nothing — what ended them was the default *cancel*, not a match.

    Args:
        **overrides: Fields to replace.

    Returns:
        The form.
    """
    summary, rest = RESOLVER_REPORT.split("\n", 1)
    return a_form(summary=summary, problem=RESOLVER_REPORT, solution=rest, **overrides)


class TestThePriorArtSweep(unittest.TestCase):
    """The issues, the lots and the roadmap, swept the way the bug flow sweeps them."""

    def setUp(self) -> None:
        self.root = fixture_root()

    def _gate(self) -> PriorArtGate:
        return PriorArtGate(sweeper=PriorArtSweeper(root=self.root, issues=None))

    def test_the_fixture_really_produces_a_match(self) -> None:
        """Without this, every test below passes on an empty sweep and asserts nothing."""
        exchange = RecordingExchange(confirms=[True])

        run(SuggestIntake(prior_art=self._gate(), filer=RecordingFiler()), exchange, a_matching_form())

        self.assertIn("confirm", exchange.calls)
        self.assertIn(FIXTURE_LOT, exchange.shown[0])

    def test_an_accepted_match_opens_nothing(self) -> None:
        filer = RecordingFiler()
        exchange = RecordingExchange(confirms=[True], choice=FILE)

        outcome = run(SuggestIntake(prior_art=self._gate(), filer=filer), exchange, a_matching_form())

        self.assertIsNone(outcome)
        self.assertEqual(filer.filed, [])
        self.assertNotIn("decide", exchange.calls)

    def test_a_rejected_match_still_files(self) -> None:
        filer = RecordingFiler()
        exchange = RecordingExchange(confirms=[False], choice=FILE)

        outcome = run(SuggestIntake(prior_art=self._gate(), filer=filer), exchange, a_matching_form())

        self.assertIsNotNone(outcome)
        self.assertIn("Prior art checked", str(filer.filed[0]["body"]))
        self.assertIn(FIXTURE_LOT, str(filer.filed[0]["body"]))


class TestNothingIsFiledWithoutTheClick(unittest.TestCase):
    """Every answer that is not *file it* leaves the tracker untouched, and says which one it was."""

    def test_a_cancelled_draft_files_nothing(self) -> None:
        filer = RecordingFiler()

        outcome = run(SuggestIntake(filer=filer), RecordingExchange(choice=CANCEL))

        self.assertIsNone(outcome)
        self.assertEqual(filer.filed, [])

    def test_an_expired_draft_says_so(self) -> None:
        exchange = RecordingExchange(choice=EXPIRED)

        run(SuggestIntake(filer=RecordingFiler()), exchange)

        self.assertEqual(exchange.posted[-1], text("draft.expired", "fr"))
        self.assertNotEqual(text("draft.expired", "fr"), text("draft.cancelled", "fr"))

    def test_the_draft_is_shown_before_it_is_filed(self) -> None:
        exchange = RecordingExchange(choice=FILE)

        run(SuggestIntake(filer=RecordingFiler()), exchange)

        self.assertLess(exchange.calls.index("decide"), exchange.calls.index("open_followup_thread"))

    def test_with_no_filer_the_request_is_shown_and_nothing_is_opened(self) -> None:
        exchange = RecordingExchange()

        outcome = run(SuggestIntake(), exchange)

        self.assertIsNone(outcome)
        self.assertNotIn("decide", exchange.calls)
        self.assertIn("Convois", exchange.posted[0])


class TestWhatIsFiled(unittest.TestCase):
    """The issue is a feature request, labelled as one, and it links its thread."""

    def test_it_carries_the_enhancement_and_machine_labels(self) -> None:
        filer = RecordingFiler()

        run(SuggestIntake(filer=filer), RecordingExchange(choice=FILE))

        self.assertEqual(filer.filed[0]["labels"], (BASE_LABEL, "filed-by-bot"))

    def test_the_thread_is_opened_before_the_issue_is_filed(self) -> None:
        exchange = RecordingExchange(choice=FILE)
        filer = RecordingFiler()

        run(SuggestIntake(filer=filer), exchange)

        self.assertIn("https://discord.test/threads/20", str(filer.filed[0]["body"]))

    def test_the_thread_is_told_the_issue_address(self) -> None:
        exchange = RecordingExchange(choice=FILE)

        run(SuggestIntake(filer=RecordingFiler()), exchange)

        self.assertIn("https://github.test/issues/7", exchange.thread_messages[0])

    def test_the_issue_and_its_thread_are_linked_for_the_relay(self) -> None:
        tracker = RecordingTracker()

        run(SuggestIntake(filer=RecordingFiler(), tracker=tracker), RecordingExchange(choice=FILE))

        self.assertEqual(tracker.remembered, [(7, 10, 20, "fr")])

    def test_the_same_suggestion_twice_carries_the_same_key(self) -> None:
        filer = RecordingFiler()

        run(SuggestIntake(filer=filer), RecordingExchange(choice=FILE))
        run(SuggestIntake(filer=filer), RecordingExchange(choice=FILE))

        self.assertEqual(filer.filed[0]["key"], filer.filed[1]["key"])


class TestWhenItGoesWrong(unittest.TestCase):
    """A failure is a sentence somebody reads, never a silence."""

    def test_a_failed_filing_is_explained_with_a_way_out(self) -> None:
        filer = RecordingFiler(Outcome(action="failed", error="502 Bad Gateway"))
        exchange = RecordingExchange(choice=FILE)

        run(SuggestIntake(filer=filer), exchange)

        self.assertIn("502", exchange.posted[-1])
        self.assertIn("feature_request.yml", exchange.posted[-1])

    def test_a_crash_after_the_acknowledgement_is_told_to_the_asker(self) -> None:
        class Exploding(ScriptedDocumentation):
            async def check(self, request: str, lang: str, subject: str) -> DocumentationCheck:
                raise RuntimeError("boom")

        exchange = RecordingExchange()

        outcome = run(SuggestIntake(documentation=Exploding(DocumentationCheck())), exchange)

        self.assertIsNone(outcome)
        self.assertEqual(exchange.posted[-1], text("suggest.error.unexpected", "fr"))

    def test_a_form_missing_its_problem_is_refused_before_anything_else(self) -> None:
        documentation = ScriptedDocumentation(DocumentationCheck(verdict=ABSENT))
        exchange = RecordingExchange()

        run(SuggestIntake(documentation=documentation, filer=RecordingFiler()), exchange, a_form(problem="  "))

        self.assertEqual(documentation.asked, [])
        self.assertIn("problem", exchange.posted[0])


class TestRenderOutcome(unittest.TestCase):
    """What the asker is told about the filing."""

    def test_a_reused_issue_says_nothing_was_opened_twice(self) -> None:
        rendered = render_outcome(Outcome(action="reused", number=7, url="u"), "en")

        self.assertIn("already been filed", rendered)

    def test_notes_are_carried(self) -> None:
        rendered = render_outcome(Outcome(action="created", number=7, url="u", notes=("a label was refused",)), "en")

        self.assertIn("a label was refused", rendered)


class TestTheInteractionTokenBudget(unittest.TestCase):
    """Three timed waits do not fit in one Discord token, so the checks give way, never the click.

    The numbers are the bug lot's own: a prior-art proposal waits 300 seconds and a draft 480, out
    of the 900 a deferred interaction token lives. This flow has one more question to ask than that
    lot did, and asking all three would leave somebody clicking *File the issue* on a dead token —
    consent given to something that will never happen, with nothing to tell him.
    """

    def test_a_late_exchange_does_not_put_the_documentation_to_the_asker(self) -> None:
        documentation = ScriptedDocumentation(DocumentationCheck(verdict=EXISTS, answer="La doc dit ceci."))
        filer = RecordingFiler()
        exchange = RecordingExchange(confirms=[True], choice=FILE)

        outcome = run(
            SuggestIntake(documentation=documentation, filer=filer, clock=Clock(0.0, 600.0)),
            exchange,
        )

        self.assertNotIn("confirm", exchange.calls)
        self.assertIsNotNone(outcome)

    def test_the_issue_says_nobody_was_asked_rather_than_that_he_disagreed(self) -> None:
        documentation = ScriptedDocumentation(DocumentationCheck(verdict=EXISTS, answer="La doc dit ceci."))
        filer = RecordingFiler()

        run(
            SuggestIntake(documentation=documentation, filer=filer, clock=Clock(0.0, 600.0)),
            RecordingExchange(choice=FILE),
            a_form(language="en"),
        )

        body = str(filer.filed[0]["body"])
        self.assertIn("could **not** be put", body)
        self.assertNotIn("is not what he meant", body)

    def test_an_early_exchange_still_asks(self) -> None:
        documentation = ScriptedDocumentation(DocumentationCheck(verdict=EXISTS, answer="La doc dit ceci."))
        exchange = RecordingExchange(confirms=[True])

        run(SuggestIntake(documentation=documentation, filer=RecordingFiler(), clock=Clock(0.0, 5.0)), exchange)

        self.assertIn("confirm", exchange.calls)

    def test_a_late_exchange_still_sweeps_and_still_records_what_it_found(self) -> None:
        """The finding is not lost, only the question is: the issue carries it either way."""
        filer = RecordingFiler()
        exchange = RecordingExchange(confirms=[True], choice=FILE)
        gate = PriorArtGate(sweeper=PriorArtSweeper(root=fixture_root(), issues=None))

        outcome = run(SuggestIntake(prior_art=gate, filer=filer, clock=Clock(0.0, 600.0)), exchange, a_matching_form())

        self.assertNotIn("confirm", exchange.calls)
        self.assertIsNotNone(outcome)
        self.assertIn(FIXTURE_LOT, str(filer.filed[0]["body"]))

    def test_the_consent_click_is_never_the_step_that_gives_way(self) -> None:
        filer = RecordingFiler()
        exchange = RecordingExchange(choice=FILE)

        run(SuggestIntake(documentation=None, filer=filer, clock=Clock(0.0, 880.0)), exchange)

        self.assertIn("decide", exchange.calls)


class TestTheLabels(unittest.TestCase):
    """A label GitHub refuses costs the issue every other label with it."""

    def test_an_unset_machine_label_is_dropped_rather_than_sent_empty(self) -> None:
        filer = RecordingFiler()
        filer.machine_label = ""

        run(SuggestIntake(filer=filer), RecordingExchange(choice=FILE))

        self.assertEqual(filer.filed[0]["labels"], (BASE_LABEL,))
