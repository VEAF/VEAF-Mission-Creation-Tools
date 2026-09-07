"""What a follow-up is, what it remembers, and what it sends.

The three units this lot adds, tested apart from Discord: the guard that decides whether a message
is a follow-up at all, the record that survives a restart, and the turns handed to the Worker.
"""

from __future__ import annotations

import json
import unittest
from pathlib import Path
from tempfile import TemporaryDirectory
from typing import Any, cast

from tests.fakes import FakeWorker, RecordingExchange
from veaf_support_bot import answer as answer_module
from veaf_support_bot.ask import AskContext, AskHandler
from veaf_support_bot.followup import (
    MAX_REMEMBERED_TURNS,
    ThreadConversation,
    ThreadMemory,
    followup_turns,
    retrieval_query,
    strip_mentions,
)
from veaf_support_bot.quota import QuotaKeeper, QuotaLimits, QuotaStore
from veaf_support_bot.texts import text
from veaf_support_bot.worker import MAX_QUESTION_CHARS


class StripMentionsTests(unittest.TestCase):
    """What is left of a message once the bot's own name is taken out of it."""

    def test_removes_the_mention_in_both_forms(self) -> None:
        """Discord writes a user mention as ``<@id>`` and, on older clients, ``<@!id>``."""
        for form in ("<@42>", "<@!42>"):
            with self.subTest(form=form):
                self.assertEqual(strip_mentions(f"{form} et les modèles ?", "42"), "et les modèles ?")

    def test_keeps_a_mention_of_somebody_else(self) -> None:
        """Only the bot's own mention is noise; another one is part of what was written."""
        self.assertEqual(strip_mentions("<@42> demande à <@7>", "42"), "demande à <@7>")

    def test_collapses_whitespace_and_reports_an_empty_question(self) -> None:
        """A bare mention carries no question, and must not reach the Worker as an empty turn."""
        self.assertEqual(strip_mentions("<@42>   ", "42"), "")
        self.assertEqual(strip_mentions("<@42>  deux   espaces", "42"), "deux espaces")


class RetrievalQueryTests(unittest.TestCase):
    """The last user turn, which the Worker also uses to pick the documentation passages."""

    def test_joins_the_opening_question_to_the_follow_up(self) -> None:
        """An elliptical follow-up retrieves against the thread's subject, not against itself."""
        query = retrieval_query("comment ajouter un préréglage radio ?", "et pour une mission ?")
        self.assertTrue(query.endswith("et pour une mission ?"))
        self.assertIn("préréglage radio", query)

    def test_the_follow_up_survives_a_long_opening_question(self) -> None:
        """The ceiling cuts the context, never the question actually being asked."""
        opening = "a" * (MAX_QUESTION_CHARS * 2)
        query = retrieval_query(opening, "et les modèles ?")
        self.assertLessEqual(len(query), MAX_QUESTION_CHARS)
        self.assertTrue(query.endswith("et les modèles ?"))

    def test_a_follow_up_longer_than_the_ceiling_is_trimmed_to_it(self) -> None:
        """A pasted wall of text is bounded like any question."""
        query = retrieval_query("courte", "b" * (MAX_QUESTION_CHARS * 2))
        self.assertEqual(len(query), MAX_QUESTION_CHARS)


class FollowupTurnsTests(unittest.TestCase):
    """The conversation handed to the Worker for a follow-up."""

    def setUp(self) -> None:
        """Build a conversation of one exchange."""
        self.conversation = ThreadConversation(
            thread_id="t1",
            question="comment ajouter un préréglage radio ?",
            turns=[
                {"role": "user", "content": "comment ajouter un préréglage radio ?"},
                {"role": "assistant", "content": "dans mission.yaml, sous radioPresets."},
            ],
            updated_at=0.0,
        )

    def test_keeps_the_protocol_first_and_the_question_last(self) -> None:
        """The Worker embeds the last user turn; an instruction in it would poison retrieval."""
        turns = followup_turns(self.conversation, "et les modèles ?")
        protocol = answer_module.protocol_turns("x")
        self.assertEqual(turns[0], protocol[0])
        self.assertEqual(turns[1], protocol[1])
        self.assertEqual(turns[-1]["role"], "user")
        self.assertTrue(turns[-1]["content"].endswith("et les modèles ?"))

    def test_carries_the_exchange_that_came_before(self) -> None:
        """Without the previous turns the model answers an ellipsis with no antecedent."""
        turns = followup_turns(self.conversation, "et les modèles ?")
        self.assertIn({"role": "assistant", "content": "dans mission.yaml, sous radioPresets."}, turns)

    def test_alternates_roles_so_the_model_reads_a_conversation(self) -> None:
        """Two user turns in a row is not a conversation, and Gemini rejects some shapes of it."""
        turns = followup_turns(self.conversation, "et les modèles ?")
        roles = [turn["role"] for turn in turns]
        self.assertEqual(roles, ["user", "assistant", "user", "assistant", "user"])


class ThreadMemoryTests(unittest.TestCase):
    """The record that makes a thread continuable after a restart."""

    def setUp(self) -> None:
        """Give each test its own state directory."""
        self._dir = TemporaryDirectory()
        self.addCleanup(self._dir.cleanup)
        self.path = Path(self._dir.name) / "ask-threads.json"

    def test_remembers_a_question_and_its_answer(self) -> None:
        """The first `/ask` is what a follow-up continues."""
        memory = ThreadMemory(self.path)
        memory.remember("t1", "une question ?", "une réponse.")
        conversation = memory.conversation("t1")
        assert conversation is not None
        self.assertEqual(conversation.question, "une question ?")
        self.assertEqual(conversation.turns[-1], {"role": "assistant", "content": "une réponse."})

    def test_an_unknown_thread_has_no_conversation(self) -> None:
        """A `/bug` thread, or one from before this feature, is not continuable."""
        self.assertIsNone(ThreadMemory(self.path).conversation("nope"))

    def test_survives_a_restart(self) -> None:
        """The whole point of the file: `docker compose up -d --build` must not end a conversation."""
        ThreadMemory(self.path).remember("t1", "une question ?", "une réponse.")
        conversation = ThreadMemory(self.path).conversation("t1")
        assert conversation is not None
        self.assertEqual(conversation.question, "une question ?")

    def test_appends_a_follow_up_and_its_answer(self) -> None:
        """A thread is a conversation, not a single exchange."""
        memory = ThreadMemory(self.path)
        memory.remember("t1", "q1", "a1")
        memory.remember("t1", "q2", "a2")
        conversation = memory.conversation("t1")
        assert conversation is not None
        self.assertEqual(conversation.question, "q1", "the opening question is what retrieval widens with")
        self.assertEqual([turn["content"] for turn in conversation.turns], ["q1", "a1", "q2", "a2"])

    def test_keeps_only_the_last_turns(self) -> None:
        """The Worker trims at twelve turns anyway; storing more grows a file for nothing."""
        memory = ThreadMemory(self.path)
        for index in range(MAX_REMEMBERED_TURNS):
            memory.remember("t1", f"q{index}", f"a{index}")
        conversation = memory.conversation("t1")
        assert conversation is not None
        self.assertLessEqual(len(conversation.turns), MAX_REMEMBERED_TURNS)
        self.assertEqual(conversation.turns[-1]["content"], f"a{MAX_REMEMBERED_TURNS - 1}")

    def test_forgets_threads_nobody_touched_for_days(self) -> None:
        """Otherwise the file grows for ever on a busy server."""
        clock = [1_000_000.0]
        memory = ThreadMemory(self.path, clock=lambda: clock[0], max_age_seconds=100.0)
        memory.remember("old", "q", "a")
        clock[0] += 1_000.0
        memory.remember("new", "q", "a")
        self.assertIsNone(memory.conversation("old"))
        self.assertIsNotNone(memory.conversation("new"))

    def test_an_unreadable_file_is_not_a_crash(self) -> None:
        """`/ask` must keep working when the state volume does not: a follow-up degrades, alone."""
        self.path.write_text("{ not json", encoding="utf-8")
        memory = ThreadMemory(self.path)
        self.assertIsNone(memory.conversation("t1"))
        memory.remember("t1", "q", "a")
        self.assertIsNotNone(memory.conversation("t1"))

    def test_a_file_of_an_unknown_version_is_ignored(self) -> None:
        """A format from the future is not guessed at."""
        self.path.write_text(json.dumps({"version": 99, "threads": []}), encoding="utf-8")
        self.assertIsNone(ThreadMemory(self.path).conversation("t1"))

    def test_an_unwritable_path_does_not_raise(self) -> None:
        """A read-only state volume costs the continuation, never the answer."""
        memory = ThreadMemory(Path(self._dir.name) / "nope" / "\0" / "ask-threads.json")
        memory.remember("t1", "q", "a")  # must not raise


class TheExchangeOfAFollowupTests(unittest.IsolatedAsyncioTestCase):
    """One follow-up, run through the handler that also runs `/ask`."""

    def setUp(self) -> None:
        """Give each test a memory holding one answered thread."""
        self._dir = TemporaryDirectory()
        self.addCleanup(self._dir.cleanup)
        self.memory = ThreadMemory(Path(self._dir.name) / "ask-threads.json")
        self.memory.remember("thread-1", "comment ajouter un préréglage radio ?", "dans mission.yaml.", "fr")
        self.worker = FakeWorker(["voici la réponse."])
        self.quota = QuotaKeeper(QuotaLimits(), QuotaStore(Path(self._dir.name) / "quota.json"))
        self.handler = AskHandler(cast(Any, self.worker), self.quota, memory=self.memory)

    async def test_it_opens_nothing_and_announces_nothing(self) -> None:
        """The reader is already in the thread, and his own message says what he asked."""
        exchange = RecordingExchange()
        conversation = self.memory.conversation("thread-1")
        assert conversation is not None
        context = AskContext("42", "Zip", "et les modèles ?", "fr", conversation)
        await self.handler.handle(exchange, context)
        self.assertNotIn("announce", exchange.steps)
        self.assertNotIn("open_thread", exchange.steps)
        self.assertIn("post", exchange.steps)

    async def test_the_worker_receives_the_thread_and_the_question(self) -> None:
        """The whole point: retrieval widened, and the exchange the model needs to read an ellipsis."""
        exchange = RecordingExchange()
        conversation = self.memory.conversation("thread-1")
        assert conversation is not None
        await self.handler.handle(exchange, AskContext("42", "Zip", "et les modèles ?", "fr", conversation))
        messages = self.worker.seen[0]["messages"]
        self.assertIn("dans mission.yaml.", [turn["content"] for turn in messages])
        self.assertTrue(messages[-1]["content"].endswith("et les modèles ?"))
        self.assertIn("préréglage radio", messages[-1]["content"])

    async def test_a_refusal_reaches_the_thread(self) -> None:
        """A follow-up spends a question, and a spent allowance has to be said somewhere."""
        quota = QuotaKeeper(QuotaLimits(user_per_day=0), QuotaStore(Path(self._dir.name) / "spent.json"))
        handler = AskHandler(cast(Any, self.worker), quota, memory=self.memory)
        exchange = RecordingExchange()
        conversation = self.memory.conversation("thread-1")
        assert conversation is not None
        await handler.handle(exchange, AskContext("42", "Zip", "et ?", "fr", conversation))
        self.assertIn("announce", exchange.steps, "a refused follow-up still has to be told to the reader")
        self.assertEqual(self.worker.seen, [])

    async def test_the_answer_is_recorded_so_the_next_follow_up_sees_it(self) -> None:
        """A thread is a conversation: the third question needs the second answer."""
        exchange = RecordingExchange()
        conversation = self.memory.conversation("thread-1")
        assert conversation is not None
        await self.handler.handle(exchange, AskContext("42", "Zip", "et les modèles ?", "fr", conversation))
        again = self.memory.conversation("thread-1")
        assert again is not None
        self.assertEqual([turn["content"] for turn in again.turns][-2:], ["et les modèles ?", "voici la réponse."])


class TheFirstAnswerTests(unittest.IsolatedAsyncioTestCase):
    """What a plain `/ask` now leaves behind, and what it tells the reader."""

    def setUp(self) -> None:
        """Give each test an empty memory."""
        self._dir = TemporaryDirectory()
        self.addCleanup(self._dir.cleanup)
        self.memory = ThreadMemory(Path(self._dir.name) / "ask-threads.json")
        self.worker = FakeWorker(["voici la réponse."])
        self.quota = QuotaKeeper(QuotaLimits(), QuotaStore(Path(self._dir.name) / "quota.json"))
        self.handler = AskHandler(cast(Any, self.worker), self.quota, memory=self.memory)

    async def test_an_answered_question_becomes_a_continuable_thread(self) -> None:
        """Without this the mention has nothing to look up and the feature does not exist."""
        await self.handler.handle(RecordingExchange(), AskContext("42", "Zip", "une question ?", "fr"))
        conversation = self.memory.conversation("thread-1")
        assert conversation is not None
        self.assertEqual(conversation.question, "une question ?")
        self.assertEqual(conversation.lang, "fr")

    async def test_the_answer_says_how_to_continue(self) -> None:
        """Nobody discovers a mention by accident."""
        exchange = RecordingExchange()
        await self.handler.handle(exchange, AskContext("42", "Zip", "une question ?", "fr"))
        self.assertIn(text("ask.continue", "fr"), exchange.final)

    async def test_an_answer_with_no_thread_promises_nothing(self) -> None:
        """A channel answer cannot be continued, so it must not invite anybody to try."""
        exchange = RecordingExchange(thread_allowed=False)
        await self.handler.handle(exchange, AskContext("42", "Zip", "une question ?", "fr"))
        self.assertNotIn(text("ask.continue", "fr"), exchange.final)
        self.assertIsNone(self.memory.conversation("thread-1"))

    async def test_the_gateway_can_reach_the_memory_to_recognise_a_follow_up(self) -> None:
        """The client reads this to know whether a mention continues anything."""
        self.assertIs(self.handler.memory, self.memory)

    async def test_a_thread_discord_will_not_name_costs_the_follow_up_and_not_the_answer(self) -> None:
        """The answer is written by then; a failure identifying its thread must stop right there."""

        class _Mute(RecordingExchange):
            async def thread_id(self) -> str | None:
                raise RuntimeError("Discord said no")

        exchange = _Mute()
        await self.handler.handle(exchange, AskContext("42", "Zip", "une question ?", "fr"))
        self.assertIn("voici la réponse.", exchange.final)
        self.assertNotIn(text("ask.continue", "fr"), exchange.final)

    async def test_a_handler_without_a_memory_promises_nothing_either(self) -> None:
        """The deployment where the state volume is not there: the answer is unchanged."""
        handler = AskHandler(cast(Any, self.worker), self.quota)
        exchange = RecordingExchange()
        await handler.handle(exchange, AskContext("42", "Zip", "une question ?", "fr"))
        self.assertNotIn(text("ask.continue", "fr"), exchange.final)


if __name__ == "__main__":
    unittest.main()
