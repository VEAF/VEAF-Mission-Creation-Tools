"""What the gateway does with a message, which is where this feature can silently not exist.

The handler can be perfect and the ear absent — this repository has shipped that shape green four
times. So what is asserted here is the wiring: the intents the connection asks for, the four
conditions that make a message a follow-up, and the fact that everything else produces **nothing**.
"""

from __future__ import annotations

import logging
import unittest
from pathlib import Path
from tempfile import TemporaryDirectory
from typing import Any, cast

import discord

from veaf_support_bot.ask import AskContext, AskHandler
from veaf_support_bot.config import SupportBotConfig
from veaf_support_bot.discord_bot import INTENTS, SupportBotClient, ThreadExchange
from veaf_support_bot.followup import ThreadMemory
from veaf_support_bot.health import ServiceState
from veaf_support_bot.service import InFlightTasks
from veaf_support_bot.texts import text


class TheIntentsTests(unittest.TestCase):
    """What the connection asks Discord for, and what it deliberately does not."""

    def test_it_hears_guild_messages(self) -> None:
        """Without this the event never arrives and the whole feature is absent."""
        self.assertTrue(INTENTS.guild_messages)

    def test_it_asks_for_nothing_privileged(self) -> None:
        """Message content and member lists are privileged; a mention is delivered without them."""
        self.assertFalse(INTENTS.message_content)
        self.assertFalse(INTENTS.members)
        self.assertFalse(INTENTS.presences)


class _RecordingHandler:
    """An :class:`~veaf_support_bot.ask.AskHandler` stand-in that records what reached it."""

    def __init__(self, memory: ThreadMemory | None) -> None:
        """Initialize the recorder.

        Args:
            memory: What the client reads to recognise a follow-up.
        """
        self.memory = memory
        self.contexts: list[AskContext] = []

    async def handle(self, exchange: Any, context: AskContext) -> None:
        """Record one exchange.

        Args:
            exchange: The Discord side.
            context: The question and who asked it.
        """
        self.contexts.append(context)


class _FakeAuthor:
    """The parts of ``discord.Member`` the follow-up path reads."""

    def __init__(self, user_id: int = 4242, *, bot: bool = False, display_name: str = "Zip") -> None:
        """Initialize the author.

        Args:
            user_id: The Discord id.
            bot: Whether Discord flags this author as a bot.
            display_name: The display name.
        """
        self.id = user_id
        self.bot = bot
        self.display_name = display_name


class _FakeChannel:
    """A thread that records what was written into it."""

    def __init__(self, channel_id: int = 777) -> None:
        """Initialize the channel.

        Args:
            channel_id: The thread id.
        """
        self.id = channel_id
        self.sent: list[str] = []

    async def send(self, content: str, **kwargs: Any) -> Any:
        """Record one message.

        Args:
            content: What was written.
            **kwargs: Ignored.

        Returns:
            A stand-in message.
        """
        self.sent.append(content)
        return object()


class _FakeMessage:
    """The parts of ``discord.Message`` the follow-up path reads."""

    def __init__(
        self,
        content: str,
        *,
        mentions: list[_FakeAuthor] | None = None,
        author: _FakeAuthor | None = None,
        channel: _FakeChannel | None = None,
    ) -> None:
        """Initialize the message.

        Args:
            content: The raw content, as Discord delivers it.
            mentions: Who is mentioned in it.
            author: Who wrote it.
            channel: Where it was written.
        """
        self.content = content
        self.mentions = mentions or []
        self.author = author or _FakeAuthor()
        self.channel = channel or _FakeChannel()


class _FakeBotUser:
    """The client's own user."""

    id = 99


class FollowupWiringTests(unittest.IsolatedAsyncioTestCase):
    """The four conditions, and what happens when each one fails."""

    def setUp(self) -> None:
        """Build a client whose gateway is never connected, over a memory of one thread."""
        self._dir = TemporaryDirectory()
        self.addCleanup(self._dir.cleanup)
        self.memory = ThreadMemory(Path(self._dir.name) / "ask-threads.json")
        self.memory.remember("777", "comment ajouter un préréglage radio ?", "dans mission.yaml.", "fr")
        self.handler = _RecordingHandler(self.memory)
        config = SupportBotConfig.from_env(
            {
                "SUPPORT_BOT_DISCORD_TOKEN": "a-token",
                "SUPPORT_BOT_DISCORD_GUILD_ID": "1",
                "SUPPORT_BOT_WORKER_SECRET": "a-secret",
                "SUPPORT_BOT_HEALTH_PORT": "0",
            }
        )
        self.client = SupportBotClient(config, ServiceState(version="test"), cast(AskHandler, self.handler))
        self.client._logger = logging.getLogger("test")
        self._bot_user = _FakeBotUser()

    def _mention(self) -> _FakeAuthor:
        """Return the bot, as it appears in a message's mentions.

        Returns:
            The bot's user.
        """
        return _FakeAuthor(user_id=self._bot_user.id, bot=True)

    async def _deliver(self, message: Any) -> None:
        """Hand one message to the client the way the gateway would.

        Args:
            message: The message.
        """
        original = type(self.client).user
        try:
            type(self.client).user = property(lambda _self: self._bot_user)  # type: ignore[assignment,method-assign]
            await self.client.on_message(message)
        finally:
            type(self.client).user = original  # type: ignore[method-assign]

    async def test_a_mention_in_a_known_thread_reaches_the_handler(self) -> None:
        """The feature itself."""
        await self._deliver(_FakeMessage("<@99> et les modèles ?", mentions=[self._mention()]))
        self.assertEqual(len(self.handler.contexts), 1)
        context = self.handler.contexts[0]
        self.assertEqual(context.question, "et les modèles ?", "the bot's own mention is not part of the question")
        self.assertIsNotNone(context.conversation)
        assert context.conversation is not None
        self.assertEqual(context.conversation.question, "comment ajouter un préréglage radio ?")

    async def test_the_asker_is_the_quota_subject(self) -> None:
        """A follow-up spends a question of the person asking it, like any other."""
        await self._deliver(_FakeMessage("<@99> et ?", mentions=[self._mention()]))
        self.assertEqual(self.handler.contexts[0].user_id, "4242")

    async def test_it_answers_in_the_language_the_thread_was_answered_in(self) -> None:
        """A message carries no locale — only an interaction does — so the record supplies it."""
        self.memory.remember("778", "how do I add a radio preset?", "in mission.yaml.", "en")
        await self._deliver(_FakeMessage("<@99> and templates?", mentions=[self._mention()], channel=_FakeChannel(778)))
        self.assertEqual(self.handler.contexts[-1].locale, "en")

    async def test_a_message_without_a_mention_does_nothing(self) -> None:
        """The ordinary case: people talking in the thread are not talking to the bot."""
        await self._deliver(_FakeMessage("je crois que c'est plutôt ça"))
        self.assertEqual(self.handler.contexts, [])

    async def test_a_message_from_a_bot_does_nothing(self) -> None:
        """Two bots answering each other's mentions is a runaway that spends the day's allowance."""
        author = _FakeAuthor(user_id=1234, bot=True)
        await self._deliver(_FakeMessage("<@99> et ?", mentions=[self._mention()], author=author))
        self.assertEqual(self.handler.contexts, [])

    async def test_its_own_message_does_nothing(self) -> None:
        """Every answer quotes the reader's question, mention included."""
        author = _FakeAuthor(user_id=99)
        await self._deliver(_FakeMessage("<@99> et ?", mentions=[self._mention()], author=author))
        self.assertEqual(self.handler.contexts, [])

    async def test_a_mention_in_an_unknown_thread_does_nothing_at_all(self) -> None:
        """A `/bug` thread belongs to the relay, and somebody else's thread to nobody here."""
        message = _FakeMessage("<@99> et ?", mentions=[self._mention()], channel=_FakeChannel(4321))
        await self._deliver(message)
        self.assertEqual(self.handler.contexts, [])
        self.assertEqual(message.channel.sent, [], "an unknown thread is answered with silence, not with a sentence")

    async def test_a_bare_mention_asks_nothing(self) -> None:
        """An empty turn must never reach the Worker."""
        await self._deliver(_FakeMessage("<@99>   ", mentions=[self._mention()]))
        self.assertEqual(self.handler.contexts, [])

    async def test_an_expired_thread_is_told_rather_than_ignored(self) -> None:
        """The reader is following an invitation the bot itself wrote; silence reads as a breakage."""
        clock = [1_000_000.0]
        memory = ThreadMemory(Path(self._dir.name) / "aged.json", clock=lambda: clock[0], max_age_seconds=10.0)
        memory.remember("777", "q", "a", "fr")
        clock[0] += 1_000.0
        self.handler.memory = memory
        message = _FakeMessage("<@99> et ?", mentions=[self._mention()])
        await self._deliver(message)
        self.assertEqual(self.handler.contexts, [])
        self.assertEqual(message.channel.sent, [text("ask.followup.forgotten", "fr")])

    async def test_a_handler_that_raises_does_not_escape_into_the_gateway(self) -> None:
        """An escaping exception would leave the mention answered by nothing, logged nowhere useful."""

        class _Exploding(_RecordingHandler):
            async def handle(self, exchange: Any, context: AskContext) -> None:
                raise RuntimeError("boom")

        self.client._handler = cast(AskHandler, _Exploding(self.memory))
        await self._deliver(_FakeMessage("<@99> et ?", mentions=[self._mention()]))

    async def test_the_exchange_is_tracked_so_a_shutdown_waits_for_it(self) -> None:
        """An untracked exchange is one `docker stop` cuts in half, leaving a placeholder for ever."""
        tracked: list[str] = []

        class _Tasks:
            async def track(self, coroutine: Any, name: str = "") -> None:
                tracked.append(name)
                await coroutine

        self.client._tasks = cast(InFlightTasks, _Tasks())
        await self._deliver(_FakeMessage("<@99> et ?", mentions=[self._mention()]))
        self.assertEqual(tracked, ["followup:4242"])


class ThreadExchangeTests(unittest.IsolatedAsyncioTestCase):
    """The Discord side of a follow-up."""

    def setUp(self) -> None:
        """Build an exchange over a recording channel."""
        self.channel = _FakeChannel()
        self.exchange = ThreadExchange(self.channel, "777")  # type: ignore[arg-type]

    async def test_nothing_is_deferred_and_no_thread_is_opened(self) -> None:
        """There is no interaction to acknowledge, and the reader is already in the thread."""
        await self.exchange.defer()
        self.assertTrue(await self.exchange.open_thread("ignored"))
        self.assertEqual(self.channel.sent, [])

    async def test_the_answer_goes_into_the_thread(self) -> None:
        """Where the question was asked, which is the only place it makes sense."""
        await self.exchange.post("…")
        self.assertEqual(self.channel.sent, ["…"])

    async def test_it_reports_the_thread_it_was_recognised_by(self) -> None:
        """So the answer is recorded against the same thread the next follow-up will look up."""
        self.assertEqual(await self.exchange.thread_id(), "777")

    async def test_nothing_it_sends_can_ping(self) -> None:
        """Every message carries text the bot did not author, the reader's own mention included."""
        sends: list[Any] = []

        class _Watching(_FakeChannel):
            async def send(self, content: str, **kwargs: Any) -> Any:
                sends.append(kwargs.get("allowed_mentions"))
                return object()

        exchange = ThreadExchange(_Watching(), "777")  # type: ignore[arg-type]
        await exchange.post("hello")
        await exchange.announce("refused")
        self.assertEqual(len(sends), 2)
        for allowed in sends:
            self.assertIsInstance(allowed, discord.AllowedMentions)
            self.assertFalse(allowed.everyone or allowed.users or allowed.roles or allowed.replied_user)


if __name__ == "__main__":
    unittest.main()
