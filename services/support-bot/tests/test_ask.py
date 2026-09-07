"""The ``/ask`` exchange: what happens, in what order, and what the user is left looking at.

The ordering assertions are the point. Every one of them fails if a step is moved, which is what
tells a future change that Discord's three-second budget, or the "a refusal opens no thread" rule,
was load-bearing rather than incidental.
"""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path
from typing import Any, cast

from tests.fakes import FakeWorker, RecordingExchange
from veaf_support_bot.answer import SOURCES_KEYWORD, SOURCES_MARKER, render_partial
from veaf_support_bot.ask import AskContext, AskHandler, discord_timestamp, quota_message
from veaf_support_bot.quota import REFUSAL_REASONS, QuotaDecision, QuotaKeeper, QuotaLimits, QuotaStore
from veaf_support_bot.texts import support_page_url, text
from veaf_support_bot.worker import FailureKind, WorkerFailure

#: A title that really is in the checked-in documentation index, so a link is really produced.
#:
#: Deliberately **not** the support page. That page's title is also the link text of the "no source
#: was resolved" fallback, so a test using it is satisfied by the very message that means citations
#: were lost: dropping ``source_links`` from the handler left the whole of ``TestSources`` green.
REAL_TITLE = "Le build"

#: Where that title resolves. Asserting on it is what makes a lost citation fail a test.
REAL_TITLE_URL = "https://veaf.github.io/documentation/dev/mission-maker/concepts/build/"


def _keeper(directory: str, **limits: Any) -> QuotaKeeper:
    """Build a keeper backed by a real store, so it counts rather than degrading.

    A keeper with no store runs degraded on purpose — counters nobody keeps are counters a restart
    wipes — so a test about the ceilings has to give it somewhere to keep them.

    Args:
        directory: A temporary directory to keep the counters in.
        **limits: Overrides of :class:`~veaf_support_bot.quota.QuotaLimits`.

    Returns:
        The keeper.
    """
    keeper = QuotaKeeper(QuotaLimits(**limits), QuotaStore(Path(directory) / "quota.json"))
    assert not keeper.degraded, "the fixture keeper must actually be counting"
    return keeper


def _handler(worker: Any, quota: QuotaKeeper | None = None, **kwargs: Any) -> AskHandler:
    """Build a handler over a fake Worker and permissive counters.

    Args:
        worker: The Worker stand-in.
        quota: Counters to use; a wide-open keeper when omitted.
        **kwargs: Passed to :class:`~veaf_support_bot.ask.AskHandler`.

    Returns:
        The handler.
    """
    keeper = quota or QuotaKeeper(QuotaLimits(user_per_window=99, user_per_day=99, global_per_day=99))
    return AskHandler(cast(Any, worker), keeper, **kwargs)


def _context(question: str = "comment builder une mission ?", locale: str | None = "fr") -> AskContext:
    """Build an ask context.

    Args:
        question: The question asked.
        locale: The Discord locale.

    Returns:
        The context.
    """
    return AskContext(user_id="42", user_display="Zip", question=question, locale=locale)


class TestTheOrderOfTheExchange(unittest.IsolatedAsyncioTestCase):
    """Discord's rules are about ordering, so the order is what is asserted."""

    async def test_the_acknowledgement_comes_before_anything_that_can_be_slow(self) -> None:
        """Three seconds is the whole budget; a quota read or a Worker call can exceed it alone."""
        exchange = RecordingExchange()

        await _handler(FakeWorker(["ok"])).handle(exchange, _context())

        self.assertEqual(exchange.steps[0], "defer")

    async def test_the_thread_is_opened_before_the_answer_is_posted(self) -> None:
        exchange = RecordingExchange()

        await _handler(FakeWorker(["ok"])).handle(exchange, _context())

        self.assertLess(exchange.steps.index("open_thread"), exchange.steps.index("post"))

    async def test_the_question_is_visible_in_the_channel_before_the_thread_hangs_off_it(self) -> None:
        """The thread is created *from* the question message, so the channel stays readable."""
        exchange = RecordingExchange()

        await _handler(FakeWorker(["ok"])).handle(exchange, _context())

        self.assertLess(exchange.steps.index("announce"), exchange.steps.index("open_thread"))
        self.assertIn("Zip", exchange.contents("announce")[0])
        self.assertIn("comment builder une mission", exchange.contents("announce")[0])

    async def test_the_thread_name_carries_the_question(self) -> None:
        exchange = RecordingExchange()

        await _handler(FakeWorker(["ok"])).handle(exchange, _context())

        name = exchange.contents("open_thread")[0]
        self.assertIn("comment builder", name)
        self.assertLessEqual(len(name), 100)

    async def test_a_placeholder_is_posted_before_the_answer_arrives(self) -> None:
        exchange = RecordingExchange()

        await _handler(FakeWorker(["ok"])).handle(exchange, _context())

        self.assertEqual(exchange.contents("post")[0], text("ask.thinking", "fr"))

    async def test_the_answer_replaces_the_placeholder_by_editing_it(self) -> None:
        exchange = RecordingExchange()

        await _handler(FakeWorker(["la réponse"])).handle(exchange, _context())

        # The escalation offer comes after, and writes nothing: what the asker is left reading is
        # still the edited answer.
        self.assertEqual([step for step in exchange.steps if step != "offer_escalation"][-1], "edit")
        self.assertIn("la réponse", exchange.final)


class TestSources(unittest.IsolatedAsyncioTestCase):
    def test_the_fixture_title_is_not_the_one_the_fallback_uses(self) -> None:
        """Guards the guard: with the support page here, every test below passes with no citations."""
        self.assertNotIn(REAL_TITLE_URL, text("ask.no_sources", "fr", support_url=support_page_url("fr")))

    async def test_a_declared_title_becomes_a_link_to_its_page(self) -> None:
        worker = FakeWorker([f"Voici la réponse.\n{SOURCES_MARKER} {REAL_TITLE}"])
        exchange = RecordingExchange()

        await _handler(worker).handle(exchange, _context())

        self.assertIn(f"[{REAL_TITLE}]({REAL_TITLE_URL})", exchange.final)

    async def test_a_reformatted_trailer_still_cites_and_still_leaves_the_body_clean(self) -> None:
        """The model reformats the marker; the parser must not turn that into "no page was cited".

        Enumerated over the shapes it actually produces — including the backticked one this module's
        own instruction shows it, and the French spacing the bot's own language invites.
        """
        shapes = {
            "plain": f"{SOURCES_MARKER} {REAL_TITLE}",
            "backticked": f"`{SOURCES_MARKER} {REAL_TITLE}`",
            "bold": f"**{SOURCES_MARKER}** {REAL_TITLE}",
            "bold marker and title": f"**{SOURCES_MARKER} {REAL_TITLE}**",
            "french spacing": f"{SOURCES_KEYWORD} : {REAL_TITLE}",
            "french no-break space": f"{SOURCES_KEYWORD}\u00a0: {REAL_TITLE}",
            "french narrow no-break space": f"{SOURCES_KEYWORD}\u202f: {REAL_TITLE}",
            "bullet": f"- {SOURCES_MARKER} {REAL_TITLE}",
            "heading": f"## {SOURCES_MARKER} {REAL_TITLE}",
            "quoted": f"> {SOURCES_MARKER} {REAL_TITLE}",
            "indented": f"   {SOURCES_MARKER} {REAL_TITLE}",
            "full-width colon": f"{SOURCES_KEYWORD}： {REAL_TITLE}",
        }
        for name, trailer in shapes.items():
            with self.subTest(shape=name):
                exchange = RecordingExchange()

                await _handler(FakeWorker([f"Voici la réponse.\n{trailer}"])).handle(exchange, _context())

                self.assertIn(REAL_TITLE_URL, exchange.final, f"the citation was lost on the {name} trailer")
                self.assertNotIn(SOURCES_KEYWORD, exchange.final, f"the protocol line leaked on the {name} trailer")
                self.assertIn("Voici la réponse.", exchange.final)

    async def test_the_trailer_never_reaches_the_reader(self) -> None:
        worker = FakeWorker([f"Voici la réponse.\n{SOURCES_MARKER} {REAL_TITLE}"])
        exchange = RecordingExchange()

        await _handler(worker).handle(exchange, _context())

        self.assertNotIn(SOURCES_MARKER, exchange.final)

    async def test_a_title_the_corpus_does_not_have_is_dropped_rather_than_linked(self) -> None:
        """A hallucinated source must never become a link, nor appear as an uncheckable title."""
        worker = FakeWorker([f"Une réponse.\n{SOURCES_MARKER} Le Grand Livre Des Choses"])
        exchange = RecordingExchange()

        await _handler(worker).handle(exchange, _context())

        self.assertNotIn("Le Grand Livre Des Choses", exchange.final)

    async def test_an_answer_with_no_usable_source_routes_to_the_support_page(self) -> None:
        """That is how "not covered by the documentation" reaches the reader in this lot."""
        worker = FakeWorker(["Je ne trouve rien là-dessus dans la documentation."])
        exchange = RecordingExchange()

        await _handler(worker).handle(exchange, _context())

        self.assertIn(support_page_url("fr"), exchange.final)

    async def test_the_answer_always_carries_its_caveat(self) -> None:
        worker = FakeWorker([f"Réponse.\n{SOURCES_MARKER} {REAL_TITLE}"])
        exchange = RecordingExchange()

        await _handler(worker).handle(exchange, _context())

        self.assertIn(text("ask.disclaimer", "fr"), exchange.final)


class TestUpstreamFailures(unittest.IsolatedAsyncioTestCase):
    """Every failure is a sentence. None is a stack trace, and none is silence."""

    async def _failure_message(self, failure: WorkerFailure, fragments: list[str] | None = None) -> str:
        """Run an exchange that fails, and return what the user is left with.

        Args:
            failure: The failure the Worker raises.
            fragments: Fragments emitted before it, if any.

        Returns:
            The final message content.
        """
        worker = FakeWorker(fragments or [], failure=failure, fail_after=0 if fragments else None)
        exchange = RecordingExchange()
        await _handler(worker).handle(exchange, _context())
        return exchange.final

    async def test_a_rate_limited_worker_is_explained_not_hidden(self) -> None:
        message = await self._failure_message(WorkerFailure(FailureKind.RATE_LIMITED, "HTTP 429"))

        self.assertEqual(message, text("ask.error.rate_limited", "fr"))

    async def test_an_unreachable_worker_is_explained(self) -> None:
        message = await self._failure_message(WorkerFailure(FailureKind.UNAVAILABLE, "HTTP 502"))

        self.assertEqual(message, text("ask.error.unavailable", "fr"))

    async def test_a_timeout_is_explained(self) -> None:
        message = await self._failure_message(WorkerFailure(FailureKind.TIMEOUT, "timed out"))

        self.assertEqual(message, text("ask.error.timeout", "fr"))

    async def test_an_empty_stream_is_explained(self) -> None:
        message = await self._failure_message(WorkerFailure(FailureKind.EMPTY, "no text"))

        self.assertEqual(message, text("ask.error.empty", "fr"))

    async def test_a_refused_client_mode_says_retrying_will_not_help(self) -> None:
        """The expected answer until the Worker's ``DISCORD_CLIENT_SECRET`` is posted."""
        message = await self._failure_message(WorkerFailure(FailureKind.FORBIDDEN, "HTTP 403"))

        self.assertEqual(message, text("ask.error.forbidden", "fr"))

    async def test_no_technical_detail_reaches_the_reader(self) -> None:
        message = await self._failure_message(WorkerFailure(FailureKind.UNAVAILABLE, "ClientConnectorError"))

        self.assertNotIn("ClientConnectorError", message)

    async def test_a_failure_halfway_through_does_not_leave_half_an_answer(self) -> None:
        """A truncated body with no caveat would read as a complete answer. It is not."""
        message = await self._failure_message(
            WorkerFailure(FailureKind.UNAVAILABLE, "died"), fragments=["la moitié de la"]
        )

        self.assertEqual(message, text("ask.error.unavailable", "fr"))

    async def test_every_failure_kind_has_a_sentence(self) -> None:
        """Guards the family, rather than the five cases above one at a time."""
        for kind in FailureKind:
            with self.subTest(kind=kind):
                for lang in ("fr", "en"):
                    self.assertTrue(text(f"ask.error.{kind.value}", lang))


class TestThreadPermission(unittest.IsolatedAsyncioTestCase):
    async def test_a_missing_thread_permission_still_delivers_the_answer(self) -> None:
        exchange = RecordingExchange(thread_allowed=False)

        await _handler(FakeWorker(["la réponse"])).handle(exchange, _context())

        self.assertIn("la réponse", exchange.final)

    async def test_it_says_why_the_answer_is_not_in_a_thread(self) -> None:
        exchange = RecordingExchange(thread_allowed=False)

        await _handler(FakeWorker(["la réponse"])).handle(exchange, _context())

        self.assertEqual(exchange.contents("post")[0], text("ask.error.no_thread", "fr"))


class TestLanguage(unittest.IsolatedAsyncioTestCase):
    async def test_an_english_asker_is_answered_in_english(self) -> None:
        exchange = RecordingExchange()

        await _handler(FakeWorker(["the answer"])).handle(exchange, _context(locale="en-GB"))

        self.assertIn(text("ask.disclaimer", "en"), exchange.final)

    async def test_the_language_is_what_the_worker_is_asked_for(self) -> None:
        worker = FakeWorker(["the answer"])

        await _handler(worker).handle(RecordingExchange(), _context(locale="en-US"))

        self.assertEqual(worker.seen[0]["lang"], "en")

    async def test_an_unknown_locale_falls_back_to_the_site_default(self) -> None:
        exchange = RecordingExchange()

        await _handler(FakeWorker(["la réponse"])).handle(exchange, _context(locale="pt-BR"))

        self.assertIn(text("ask.disclaimer", "fr"), exchange.final)


class TestWhatTheWorkerIsSent(unittest.IsolatedAsyncioTestCase):
    async def test_the_question_is_the_last_turn_and_is_untouched(self) -> None:
        """The Worker embeds the last user turn verbatim; instructions in it would poison retrieval."""
        worker = FakeWorker(["ok"])

        await _handler(worker).handle(RecordingExchange(), _context(question="comment builder ?"))

        messages = worker.seen[0]["messages"]
        self.assertEqual(messages[-1], {"role": "user", "content": "comment builder ?"})

    async def test_the_source_protocol_is_a_prior_turn(self) -> None:
        worker = FakeWorker(["ok"])

        await _handler(worker).handle(RecordingExchange(), _context())

        messages = worker.seen[0]["messages"]
        self.assertIn(SOURCES_MARKER, messages[0]["content"])
        self.assertEqual(messages[0]["role"], "user")

    async def test_the_quota_subject_is_the_discord_user(self) -> None:
        """Without it the Worker keys on the bot's IP, and the whole server shares one allowance."""
        worker = FakeWorker(["ok"])

        await _handler(worker).handle(RecordingExchange(), _context())

        self.assertEqual(worker.seen[0]["subject"], "42")


class TestQuotaRefusals(unittest.IsolatedAsyncioTestCase):
    """The counters seen from the exchange: a refused question costs nothing and says so."""

    def setUp(self) -> None:
        """Give each test a private directory for the counters."""
        self._directory = tempfile.TemporaryDirectory()
        self.addCleanup(self._directory.cleanup)

    async def _exhaust(self, worker: FakeWorker, **limits: Any) -> tuple[AskHandler, RecordingExchange]:
        """Spend a user's first allowance, then run one more question.

        Args:
            worker: The Worker stand-in.
            **limits: Overrides of the ceilings.

        Returns:
            The handler, and the exchange of the refused question.
        """
        handler = _handler(worker, _keeper(self._directory.name, **limits))
        await handler.handle(RecordingExchange(), _context())
        exchange = RecordingExchange()
        await handler.handle(exchange, _context())
        return handler, exchange

    async def test_a_refused_question_never_reaches_the_worker(self) -> None:
        worker = FakeWorker(["ok"])

        await self._exhaust(worker, user_per_window=1, user_per_day=1, global_per_day=99)

        self.assertEqual(len(worker.seen), 1)

    async def test_a_refused_question_opens_no_thread(self) -> None:
        _, exchange = await self._exhaust(FakeWorker(["ok"]), user_per_window=1, user_per_day=1, global_per_day=99)

        self.assertNotIn("open_thread", exchange.steps)

    async def test_a_refusal_is_still_acknowledged_first(self) -> None:
        _, exchange = await self._exhaust(FakeWorker(["ok"]), user_per_window=1, user_per_day=1, global_per_day=99)

        self.assertEqual(exchange.steps[0], "defer")

    async def test_a_refusal_says_when_it_lifts(self) -> None:
        """A bot that goes quiet is indistinguishable from a bot that is broken."""
        _, exchange = await self._exhaust(FakeWorker(["ok"]), user_per_window=1, user_per_day=9, global_per_day=99)

        self.assertIn("<t:", exchange.final)

    async def test_the_bot_s_own_daily_ceiling_refuses_a_user_who_still_has_allowance(self) -> None:
        """The only bound on total spend: the Worker counts per user and cannot see the bot's total."""
        _, exchange = await self._exhaust(FakeWorker(["ok"]), user_per_window=9, user_per_day=9, global_per_day=1)

        # The part of the sentence before its first timestamp, so the assertion survives a reword
        # of the message without hard-coding it.
        lead = text("quota.global-day", "fr", limit=1, reset_relative="\x00", reset_time="\x00").split("\x00")[0]
        self.assertTrue(exchange.final.startswith(lead), exchange.final)


class TestNothingGetsPastTheDeferWithoutAnswering(unittest.IsolatedAsyncioTestCase):
    """After ``defer``, Discord shows "the bot is thinking" until something edits the response.

    ``WorkerFailure`` was the only failure that reached the reader as a sentence. Anything else —
    Discord answering 500 to an ``announce``, a missing text key, a bug in ``render`` — escaped into
    the gateway, whose default handler writes a log line and touches the interaction never again.
    """

    async def _run(self, fails_on: str) -> RecordingExchange:
        """Run an exchange in which one Discord call refuses.

        Args:
            fails_on: The exchange method that raises.

        Returns:
            The transcript.
        """
        exchange = RecordingExchange(fails_on=[fails_on])
        await _handler(FakeWorker(["la réponse"])).handle(exchange, _context())
        return exchange

    async def test_a_refusal_at_any_step_still_leaves_a_sentence_on_screen(self) -> None:
        """Enumerated over every call the exchange makes after the defer, not sampled."""
        for step in ("announce", "open_thread", "post", "edit"):
            with self.subTest(step=step):
                exchange = await self._run(step)

                self.assertEqual(exchange.final, text("ask.error.unexpected", "fr"))

    async def test_the_exception_does_not_escape_into_the_gateway(self) -> None:
        """It is logged and answered here; escaping means an unhandled error and no message at all."""
        exchange = RecordingExchange(fails_on=["announce"])

        await _handler(FakeWorker(["la réponse"])).handle(exchange, _context())

        self.assertEqual(exchange.steps[0], "defer")

    async def test_no_technical_detail_of_our_own_bug_reaches_the_reader(self) -> None:
        exchange = await self._run("post")

        self.assertNotIn("RuntimeError", exchange.final)
        self.assertNotIn("Discord refused", exchange.final)

    async def test_a_failure_before_the_defer_is_not_swallowed(self) -> None:
        """Nothing is on screen yet, so there is nobody to apologise to — and the caller must know."""
        exchange = RecordingExchange(fails_on=["defer"])

        with self.assertRaises(RuntimeError):
            await _handler(FakeWorker(["la réponse"])).handle(exchange, _context())


class TestTheProgressiveEdit(unittest.IsolatedAsyncioTestCase):
    """The feature the lot leads with, and the one path no test used to run.

    ``AskHandler`` takes ``clock``, ``min_edit_interval`` and ``min_edit_chars`` "so a test can inject
    a clock" — and no test did. Making the pacing branch unreachable left all 311 tests green.
    """

    class _Clock:
        """A clock that advances a fixed step each time it is read."""

        def __init__(self, step: float) -> None:
            """Initialize the clock.

            Args:
                step: Seconds added per reading.
            """
            self.now = 0.0
            self._step = step

        def __call__(self) -> float:
            """Return the instant, then move on.

            Returns:
                The instant before the step.
            """
            now = self.now
            self.now += self._step
            return now

    async def _stream(self, *, step: float, min_chars: int, interval: float, fragments: int = 20) -> RecordingExchange:
        """Stream *fragments* of a hundred characters against a scripted clock.

        Args:
            step: Seconds the clock advances per reading.
            min_chars: Characters required between two edits.
            interval: Seconds required between two edits.
            fragments: How many fragments the Worker yields.

        Returns:
            The transcript.
        """
        exchange = RecordingExchange()
        handler = _handler(
            FakeWorker(["x" * 100 for _ in range(fragments)]),
            clock=self._Clock(step),
            min_edit_chars=min_chars,
            min_edit_interval=interval,
        )
        await handler.handle(exchange, _context())
        return exchange

    async def test_the_answer_is_edited_in_as_it_streams(self) -> None:
        exchange = await self._stream(step=1.0, min_chars=100, interval=0.5)

        self.assertGreater(len(exchange.contents("edit")), 1, "nothing was shown until the answer was complete")

    async def test_an_intermediate_edit_shows_the_placeholder_form_not_the_final_one(self) -> None:
        """No sources and no caveat: neither is known yet, and a caveat invites acting on a half."""
        exchange = await self._stream(step=1.0, min_chars=100, interval=0.5)

        intermediate = exchange.contents("edit")[0]
        self.assertEqual(intermediate, render_partial("x" * 100, "fr"))
        self.assertNotIn(text("ask.disclaimer", "fr"), intermediate)

    async def test_no_edit_is_made_below_the_character_delta(self) -> None:
        """The gate that stops one edit per token; the clock is wide open so only chars can refuse."""
        exchange = await self._stream(step=10.0, min_chars=100_000, interval=0.0)

        self.assertEqual(len(exchange.contents("edit")), 1, "only the final edit should have been made")

    async def test_no_edit_is_made_below_the_interval(self) -> None:
        """The gate that stands between the bot and a 429 on Discord's edit endpoint."""
        exchange = await self._stream(step=0.0, min_chars=1, interval=1.5)

        self.assertEqual(len(exchange.contents("edit")), 1, "only the final edit should have been made")

    async def test_the_pacing_is_measured_from_the_end_of_an_edit_not_its_start(self) -> None:
        """An edit longer than the interval used to satisfy the gate the moment it returned.

        The throttle then stopped throttling precisely while Discord was pushing back — the one
        moment it exists for. Here every edit costs more than the whole interval, and the stream
        itself advances the clock only a little: stamping the time *before* the await lets every
        remaining fragment through, 14 edits over 20 fragments against the 3 the gate allows.
        """
        clock = self._Clock(0.2)

        class _SlowEdits(RecordingExchange):
            async def edit(self, content: str) -> None:
                clock.now += 2.0
                await super().edit(content)

        exchange = _SlowEdits()
        handler = _handler(
            FakeWorker(["x" * 10 for _ in range(20)]),
            clock=clock,
            min_edit_chars=1,
            min_edit_interval=1.5,
        )

        await handler.handle(exchange, _context())

        self.assertLessEqual(
            len(exchange.contents("edit")), 5, "the throttle disarmed itself as soon as an edit ran long"
        )


class TestTheExchangeBudget(unittest.IsolatedAsyncioTestCase):
    """``ClientTimeout(total=...)`` only bounds what aiohttp *waits* for.

    Once bytes are buffered, a slow consumer — this loop awaiting a Discord edit that is being
    rate-limited — runs unbounded, and a deferred interaction token dies after fifteen minutes.
    """

    async def test_a_stream_that_outlasts_the_budget_ends_as_a_timeout_sentence(self) -> None:
        worker = FakeWorker(["fragment " for _ in range(50)], timeout=0.05, pause=0.01)
        exchange = RecordingExchange()

        await _handler(worker).handle(exchange, _context())

        self.assertEqual(exchange.final, text("ask.error.timeout", "fr"))

    async def test_a_stream_inside_the_budget_is_answered_normally(self) -> None:
        """A bound that can only fail one way proves nothing."""
        worker = FakeWorker(["la réponse"], timeout=5.0, pause=0.001)
        exchange = RecordingExchange()

        await _handler(worker).handle(exchange, _context())

        self.assertIn("la réponse", exchange.final)

    async def test_the_budget_is_the_client_s_own_and_not_a_second_number(self) -> None:
        """Two independent budgets would drift, and the docstring names only one."""
        worker = FakeWorker(["x"], timeout=0.02, pause=0.2)
        exchange = RecordingExchange()

        await _handler(worker).handle(exchange, _context())

        self.assertEqual(exchange.final, text("ask.error.timeout", "fr"))


class TestQuotaMessage(unittest.TestCase):
    def test_a_reset_time_renders_in_the_reader_s_own_timezone(self) -> None:
        self.assertEqual(discord_timestamp(1757030400.7, "R"), "<t:1757030400:R>")

    def test_every_refusal_reason_has_a_sentence_in_both_languages(self) -> None:
        """Enumerated from the reasons the keeper can actually produce, not sampled by hand."""
        for reason in REFUSAL_REASONS:
            for lang in ("fr", "en"):
                with self.subTest(reason=reason, lang=lang):
                    rendered = quota_message(QuotaDecision(False, reason, 1757030400.0, 15), lang)

                    self.assertIn("<t:1757030400:R>", rendered)

    def test_a_daily_refusal_names_the_ceiling_it_hit(self) -> None:
        rendered = quota_message(QuotaDecision(False, "user-day", 1757030400.0, 15), "en")

        self.assertIn("15", rendered)

    def test_rendering_a_refusal_for_an_allowed_decision_is_an_error(self) -> None:
        with self.assertRaises(ValueError):
            quota_message(QuotaDecision(True), "fr")


if __name__ == "__main__":
    unittest.main()
