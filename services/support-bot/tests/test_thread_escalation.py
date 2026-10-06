"""FEAT-SUPPORT-ASK-ESCALATE: turning an ``/ask`` thread into a ``/bug`` or a ``/suggest``.

The CSAR thread of 2026-09-22 found a real documentation gap and produced no issue, because both
intake forms started from an empty page. What is asserted here is the whole path from the mention to
the tracker: the word that asks for it, where it is offered and where it is not, what the form is
filled with, and that the tracker is touched exactly once and only on a confirmation.
"""

from __future__ import annotations

import asyncio
import logging
import unittest
from dataclasses import replace
from pathlib import Path
from tempfile import TemporaryDirectory
from typing import Any, cast

import discord

from tests.fakes import FakeWorker, RecordingExchange
from tests.test_discord_consent import _Click
from tests.test_discord_consent import _intake as _bug_intake
from tests.test_followup_wiring import _FakeAuthor, _FakeBotUser, _FakeChannel, _FakeMessage, _RecordingHandler
from tests.test_intake_github_wiring import _Exchange, _Filer, _intake
from tests.test_suggest import RecordingExchange as SuggestExchange
from tests.test_suggest import RecordingFiler, ScriptedDocumentation
from veaf_support_bot.ask import AskContext, AskHandler
from veaf_support_bot.bugreport import BugForm
from veaf_support_bot.config import SupportBotConfig
from veaf_support_bot.discord_bot import SuggestModal, SupportBotClient
from veaf_support_bot.draft import CANCEL, FILE
from veaf_support_bot.existing import ABSENT, DocumentationCheck
from veaf_support_bot.followup import ThreadMemory, escalation_kind, escalation_transcript
from veaf_support_bot.health import ServiceState
from veaf_support_bot.intake import BugSubmission, escalation_form
from veaf_support_bot.quota import QuotaKeeper, QuotaLimits, QuotaStore
from veaf_support_bot.suggest import SuggestIntake, SuggestSubmission
from veaf_support_bot.suggestion import PARAGRAPH_MAX_CHARS, UNKNOWN_COMPONENT, escalated_suggestion
from veaf_support_bot.texts import text

#: A thread that drifted, the way the CSAR one did.
THREAD = [
    {"role": "user", "content": "how do I configure CSAR?"},
    {"role": "assistant", "content": "in mission.yaml, under modules."},
    {"role": "user", "content": "and the pickup zones?"},
    {"role": "assistant", "content": "the documentation does not say."},
]


class TheKeywordTests(unittest.TestCase):
    """The word that asks for an escalation, and the questions it must not swallow."""

    def test_the_two_words_are_recognised(self) -> None:
        self.assertEqual(escalation_kind("bug"), "bug")
        self.assertEqual(escalation_kind("suggest"), "suggest")
        self.assertEqual(escalation_kind("suggestion"), "suggest")

    def test_case_spacing_and_punctuation_do_not_matter(self) -> None:
        """French typography writes *"bug !"*, and a habit of slash commands writes *"/bug"*."""
        self.assertEqual(escalation_kind("  BUG "), "bug")
        self.assertEqual(escalation_kind("bug !"), "bug")
        self.assertEqual(escalation_kind("/bug"), "bug")
        self.assertEqual(escalation_kind("suggest."), "suggest")

    def test_a_question_that_starts_with_the_word_is_still_a_question(self) -> None:
        """*"bug dans CTLD ?"* is somebody asking, and taking it for an escalation would swallow it."""
        self.assertIsNone(escalation_kind("bug dans CTLD ?"))
        self.assertIsNone(escalation_kind("et les modèles ?"))


class TheTranscriptTests(unittest.TestCase):
    """What the thread becomes once it is in a form."""

    def test_both_sides_are_labelled_oldest_first(self) -> None:
        transcript = escalation_transcript(THREAD, "en", 2000)

        self.assertTrue(transcript.startswith("Question: how do I configure CSAR?"))
        self.assertTrue(transcript.endswith("Bot's answer: the documentation does not say."))

    def test_nobody_is_written_in_the_first_person(self) -> None:
        """Whoever escalates may not be whoever asked: a *"Me:"* would put his name on their question."""
        transcript = escalation_transcript(THREAD, "fr", 2000)

        self.assertNotIn("Moi", transcript)
        self.assertTrue(transcript.startswith("Question : how do I configure CSAR?"))

    def test_it_never_exceeds_its_budget(self) -> None:
        for budget in (10, 60, 200):
            self.assertLessEqual(len(escalation_transcript(THREAD, "en", budget)), budget)

    def test_a_tight_budget_keeps_the_end_of_the_thread(self) -> None:
        transcript = escalation_transcript(THREAD, "en", 60)

        self.assertIn("does not say", transcript)
        self.assertNotIn("CSAR", transcript)

    def test_empty_turns_are_skipped(self) -> None:
        transcript = escalation_transcript([{"role": "user", "content": "  "}, *THREAD[:2]], "fr", 2000)

        self.assertTrue(transcript.startswith("Question : how do I configure CSAR?"))

    def test_a_cut_never_opens_on_an_answer_without_its_question(self) -> None:
        """The reader of the issue could not tell what that answer answers."""
        turns = [
            {"role": "user", "content": "first " + "q" * 280},
            {"role": "assistant", "content": "first answer, short"},
            {"role": "user", "content": "second " + "q" * 280},
            {"role": "assistant", "content": "second answer, short"},
        ]

        # Room for the last answer, the last question and the first answer, not for the first question.
        transcript = escalation_transcript(turns, "en", 500)

        self.assertTrue(transcript.startswith("Question: second"), transcript[:40])
        self.assertNotIn("first answer", transcript)


class TheEscalatedSuggestionTests(unittest.TestCase):
    """The ``/suggest`` form, pre-filled from the thread."""

    def test_the_thread_is_the_problem_and_the_solution_is_left_to_write(self) -> None:
        form = escalated_suggestion(THREAD, asker="Tripack", asker_id="4242", language="en")

        self.assertIn("pickup zones", form.problem)
        self.assertIn("does not say", form.problem)
        self.assertEqual(form.solution, "")
        self.assertEqual(form.component, UNKNOWN_COMPONENT)
        self.assertEqual(form.summary, "and the pickup zones?")
        self.assertEqual(form.missing_fields(), ("solution",), "nothing is filed until somebody writes it")

    def test_a_long_thread_still_fits_the_field(self) -> None:
        """Discord refuses a modal whose pre-filled value overflows: too long means *no form*."""
        turns = [{"role": "user", "content": "q" * 900}, {"role": "assistant", "content": "a" * 9000}] * 6

        form = escalated_suggestion(turns, asker="Tripack", asker_id="4242", language="fr")

        self.assertLessEqual(len(form.problem), PARAGRAPH_MAX_CHARS)


def _completed_bug(turns: list[dict[str, str]]) -> BugSubmission:
    """Build the submission a reporter sends after completing the escalated form.

    Args:
        turns: The thread.

    Returns:
        The submission, with the fields the form leaves to the reporter filled in.
    """
    form = escalation_form(turns, reporter="Tripack", reporter_id="4242", language="en")
    completed = BugForm(
        summary=form.summary,
        happened=form.happened,
        expected="the documentation should describe the pickup zones",
        steps="1. ask the bot about CSAR pickup zones",
        reporter=form.reporter,
        reporter_id=form.reporter_id,
        language=form.language,
    )
    return BugSubmission(form=completed, attachments=[])


class TheConsentPathTests(unittest.IsolatedAsyncioTestCase):
    """An escalated draft goes through the same confirmation as a typed one."""

    async def test_a_declined_bug_files_nothing(self) -> None:
        filer = _Filer()

        await _intake(filer=filer).handle(_Exchange(decision=CANCEL), _completed_bug(THREAD))

        self.assertEqual(filer.filed, [])

    async def test_a_confirmed_bug_files_exactly_once(self) -> None:
        filer = _Filer()
        exchange = _Exchange(decision=FILE)

        await _intake(filer=filer).handle(exchange, _completed_bug(THREAD))

        self.assertEqual(len(exchange.drafts), 1, "the draft was shown first")
        self.assertEqual(len(filer.filed), 1)

    def _suggest(self, choice: str) -> RecordingFiler:
        """Run one escalated suggestion through the flow.

        Args:
            choice: What is done with the draft.

        Returns:
            The filer, holding what was filed.
        """
        filer = RecordingFiler()
        form = escalated_suggestion(THREAD, asker="Tripack", asker_id="4242", language="en")
        completed = SuggestSubmission(form=replace(form, solution="document the pickup zones"))
        intake = SuggestIntake(documentation=ScriptedDocumentation(DocumentationCheck(verdict=ABSENT)), filer=filer)
        asyncio.run(intake.handle(SuggestExchange(choice=choice), completed))
        return filer

    def test_a_declined_suggestion_files_nothing(self) -> None:
        self.assertEqual(self._suggest(CANCEL).filed, [])

    def test_a_confirmed_suggestion_files_exactly_once(self) -> None:
        self.assertEqual(len(self._suggest(FILE).filed), 1)


class TheButtonCarriesTheThreadTests(unittest.IsolatedAsyncioTestCase):
    """The *Report a bug* button under an answer hands over the thread, not only its last line."""

    async def test_a_follow_up_answer_offers_the_whole_thread(self) -> None:
        with TemporaryDirectory() as directory:
            memory = ThreadMemory(Path(directory) / "ask-threads.json")
            memory.remember("thread-1", "how do I configure CSAR?", "in mission.yaml.", "en")
            quota = QuotaKeeper(QuotaLimits(), QuotaStore(Path(directory) / "quota.json"))
            handler = AskHandler(cast(Any, FakeWorker(["the documentation does not say."])), quota, memory=memory)
            conversation = memory.conversation("thread-1")
            assert conversation is not None
            exchange = RecordingExchange()

            await handler.handle(exchange, AskContext("42", "Zip", "and the pickup zones?", "en", conversation))

        turns, lang = exchange.escalations[0]
        self.assertEqual(
            [turn["content"] for turn in turns],
            [
                "how do I configure CSAR?",
                "in mission.yaml.",
                "and the pickup zones?",
                "the documentation does not say.",
            ],
        )
        self.assertEqual(lang, "en")


class _ViewChannel(_FakeChannel):
    """A thread that also keeps the components each message was sent with."""

    def __init__(self, channel_id: int = 777) -> None:
        """Initialize the channel.

        Args:
            channel_id: The thread id.
        """
        super().__init__(channel_id)
        self.views: list[Any] = []

    async def send(self, content: str, **kwargs: Any) -> Any:
        """Record one message and its view.

        Args:
            content: What was written.
            **kwargs: What it was sent with.

        Returns:
            A stand-in message.
        """
        self.views.append(kwargs.get("view"))
        return await super().send(content)


class TheMentionWiringTests(unittest.IsolatedAsyncioTestCase):
    """What the gateway does with ``@bot bug`` and ``@bot suggest``."""

    def setUp(self) -> None:
        """Build a client whose gateway is never connected, over a memory of one thread."""
        self._dir = TemporaryDirectory()
        self.addCleanup(self._dir.cleanup)
        self.memory = ThreadMemory(Path(self._dir.name) / "ask-threads.json")
        self.memory.remember("777", "how do I configure CSAR?", "in mission.yaml.", "en")
        self.memory.remember("777", "and the pickup zones?", "the documentation does not say.", "en")
        self.handler = _RecordingHandler(self.memory)
        self._bot_user = _FakeBotUser()

    def _client(self, *, published: bool = True) -> SupportBotClient:
        """Build the client.

        Args:
            published: Whether ``/bug`` and ``/suggest`` exist on this deployment.

        Returns:
            The client.
        """
        config = SupportBotConfig.from_env(
            {
                "SUPPORT_BOT_DISCORD_TOKEN": "a-token",
                "SUPPORT_BOT_DISCORD_GUILD_ID": "1",
                "SUPPORT_BOT_WORKER_SECRET": "a-secret",
                "SUPPORT_BOT_HEALTH_PORT": "0",
            }
        )
        client = SupportBotClient(
            config,
            ServiceState(version="test"),
            cast(AskHandler, self.handler),
            intake=_bug_intake() if published else None,
            suggest=SuggestIntake() if published else None,
        )
        client._logger = logging.getLogger("test")
        return client

    async def _deliver(self, client: SupportBotClient, content: str, channel: _ViewChannel) -> None:
        """Hand one mention to the client the way the gateway would.

        Args:
            client: The client.
            content: What follows the mention.
            channel: Where it was written.
        """
        message = _FakeMessage(
            f"<@99> {content}", mentions=[_FakeAuthor(user_id=99, bot=True)], channel=cast(_FakeChannel, channel)
        )
        original = type(client).user
        try:
            type(client).user = property(lambda _self: self._bot_user)  # type: ignore[assignment,method-assign]
            await client.on_message(cast(Any, message))
        finally:
            type(client).user = original  # type: ignore[method-assign]

    async def test_bug_offers_the_pre_filled_report_and_asks_nothing(self) -> None:
        channel = _ViewChannel()

        await self._deliver(self._client(), "bug", channel)

        self.assertEqual(self.handler.contexts, [], "no question was asked, so no quota is spent")
        self.assertEqual(channel.sent, [text("escalate.ready.bug", "en")])
        self.assertEqual([item.label for item in channel.views[0].children], ["Report a bug"])

    async def test_pressing_it_opens_the_form_filled_from_the_thread(self) -> None:
        channel = _ViewChannel()
        await self._deliver(self._client(), "bug", channel)
        click = _Click()

        await channel.views[0].children[0].callback(cast(Any, click))

        opened = click.response.modals[0]
        self.assertIn("how do I configure CSAR?", str(opened.happened.default))
        self.assertIn("does not say", str(opened.happened.default))
        self.assertEqual(str(opened.summary.default), "and the pickup zones?")

    async def test_suggest_opens_the_suggestion_form_filled_from_the_thread(self) -> None:
        channel = _ViewChannel()
        await self._deliver(self._client(), "suggest", channel)
        click = _Click()

        self.assertEqual([item.label for item in channel.views[0].children], ["Suggest an improvement"])
        await channel.views[0].children[0].callback(cast(Any, click))

        opened = click.response.modals[0]
        self.assertIsInstance(opened, SuggestModal)
        assert isinstance(opened, SuggestModal)
        self.assertIn("pickup zones", str(opened.problem.default))
        self.assertFalse(opened.solution.default, "the solution is left for the asker to write")

    async def test_it_is_not_offered_in_a_thread_the_bot_does_not_own(self) -> None:
        channel = _ViewChannel(4321)

        await self._deliver(self._client(), "bug", channel)

        self.assertEqual(channel.sent, [])
        self.assertEqual(self.handler.contexts, [])

    async def test_without_the_flow_the_word_is_answered_as_a_question(self) -> None:
        """A deployment with no checkout publishes neither ``/bug`` nor ``/suggest``."""
        channel = _ViewChannel()

        await self._deliver(self._client(published=False), "bug", channel)

        self.assertEqual(channel.sent, [])
        self.assertEqual([context.question for context in self.handler.contexts], ["bug"])

    async def test_a_refused_send_is_logged_and_not_answered_as_a_question(self) -> None:
        """The word was understood; turning it into a question would spend a quota question on it."""

        class _Refusing(_ViewChannel):
            async def send(self, content: str, **kwargs: Any) -> Any:
                raise discord.HTTPException(cast(Any, type("R", (), {"status": 403, "reason": "Forbidden"})()), "no")

        channel = _Refusing()

        await self._deliver(self._client(), "bug", channel)  # must not raise

        self.assertEqual(self.handler.contexts, [])

    async def test_a_question_that_starts_with_the_word_is_answered(self) -> None:
        channel = _ViewChannel()

        await self._deliver(self._client(), "bug dans CTLD ?", channel)

        self.assertEqual(channel.sent, [])
        self.assertEqual([context.question for context in self.handler.contexts], ["bug dans CTLD ?"])


if __name__ == "__main__":
    unittest.main()
