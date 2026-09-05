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
from veaf_support_bot.answer import SOURCES_MARKER
from veaf_support_bot.ask import AskContext, AskHandler, discord_timestamp, quota_message
from veaf_support_bot.quota import REFUSAL_REASONS, QuotaDecision, QuotaKeeper, QuotaLimits, QuotaStore
from veaf_support_bot.texts import support_page_url, text
from veaf_support_bot.worker import FailureKind, WorkerFailure

#: A title that really is in the checked-in documentation index, so a link is really produced.
REAL_TITLE = "Obtenir de l'aide"


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

        self.assertEqual(exchange.steps[-1], "edit")
        self.assertIn("la réponse", exchange.final)


class TestSources(unittest.IsolatedAsyncioTestCase):
    async def test_a_declared_title_becomes_a_link_to_its_page(self) -> None:
        worker = FakeWorker([f"Voici la réponse.\n{SOURCES_MARKER} {REAL_TITLE}"])
        exchange = RecordingExchange()

        await _handler(worker).handle(exchange, _context())

        self.assertIn(f"[{REAL_TITLE}](", exchange.final)
        self.assertIn("/SUPPORT/", exchange.final)

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
