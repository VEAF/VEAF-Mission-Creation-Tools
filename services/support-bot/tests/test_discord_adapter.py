"""The thin layer between the exchange protocol and ``discord.py``.

It is thin on purpose, but it is where the Discord-specific decisions live: that the acknowledgement
is public rather than ephemeral, that the thread hangs off the interaction's own message, and that a
refused edit never escapes into the gateway's task — where it becomes a log nobody reads and a
"thinking" message that never resolves.
"""

from __future__ import annotations

import unittest
from typing import Any, cast

import discord

from veaf_support_bot.discord_bot import INTENTS, InteractionExchange
from veaf_support_bot.logging_setup import get_logger


class _Response:
    """Records how the interaction was acknowledged."""

    def __init__(self) -> None:
        """Initialize the recorder."""
        self.deferred_with: dict[str, Any] | None = None

    async def defer(self, **kwargs: Any) -> None:
        """Record the deferral.

        Args:
            **kwargs: What it was deferred with.
        """
        self.deferred_with = kwargs


class _Message:
    """A posted message that can be edited, and can refuse a thread."""

    def __init__(self, content: str = "", *, thread_error: Exception | None = None) -> None:
        """Initialize the message.

        Args:
            content: Its content.
            thread_error: Raised by :meth:`create_thread`, when given.
        """
        self.content = content
        self.edits: list[str] = []
        self.edit_error: Exception | None = None
        self._thread_error = thread_error

    async def create_thread(self, name: str) -> _Thread:
        """Open a thread on this message.

        Args:
            name: The thread name.

        Returns:
            The thread.

        Raises:
            Exception: The one the message was built with.
        """
        if self._thread_error is not None:
            raise self._thread_error
        return _Thread(name)

    async def edit(self, content: str) -> None:
        """Record an edit.

        Args:
            content: The new content.

        Raises:
            Exception: :attr:`edit_error`, when set.
        """
        if self.edit_error is not None:
            raise self.edit_error
        self.edits.append(content)


class _Thread:
    """A thread that records what was sent into it."""

    def __init__(self, name: str) -> None:
        """Initialize the thread.

        Args:
            name: Its name.
        """
        self.name = name
        self.sent: list[str] = []

    async def send(self, content: str) -> _Message:
        """Record a message.

        Args:
            content: The content.

        Returns:
            The posted message.
        """
        self.sent.append(content)
        return _Message(content)


class _Followup:
    """The followup channel, used when there is no thread."""

    def __init__(self) -> None:
        """Initialize the recorder."""
        self.sent: list[str] = []

    async def send(self, content: str, wait: bool = False) -> _Message:
        """Record a followup message.

        Args:
            content: The content.
            wait: Whether the caller wants the message back.

        Returns:
            The posted message.
        """
        self.sent.append(content)
        return _Message(content)


class _Interaction:
    """The parts of ``discord.Interaction`` the adapter touches."""

    def __init__(self, *, thread_error: Exception | None = None) -> None:
        """Initialize the interaction.

        Args:
            thread_error: Raised when the adapter tries to open a thread.
        """
        self.response = _Response()
        self.followup = _Followup()
        self.original = _Message(thread_error=thread_error)
        self.edited: list[str] = []

    async def edit_original_response(self, content: str) -> _Message:
        """Record an edit of the acknowledgement.

        Args:
            content: The new content.

        Returns:
            The message.
        """
        self.edited.append(content)
        self.original.content = content
        return self.original

    async def original_response(self) -> _Message:
        """Return the acknowledgement message.

        Returns:
            The message.
        """
        return self.original


def _exchange(interaction: _Interaction) -> InteractionExchange:
    """Build an exchange over a fake interaction.

    Args:
        interaction: The interaction.

    Returns:
        The exchange.
    """
    return InteractionExchange(cast(discord.Interaction, cast(object, interaction)), get_logger("test"))


class TestTheAcknowledgement(unittest.IsolatedAsyncioTestCase):
    async def test_it_is_deferred_so_discord_stops_counting(self) -> None:
        interaction = _Interaction()

        await _exchange(interaction).defer()

        self.assertEqual(interaction.response.deferred_with, {"thinking": True})

    async def test_it_is_public_not_ephemeral(self) -> None:
        """An ephemeral reply cannot carry a thread, and the answer must serve the next person."""
        interaction = _Interaction()

        await _exchange(interaction).defer()

        assert interaction.response.deferred_with is not None
        self.assertFalse(interaction.response.deferred_with.get("ephemeral", False))

    async def test_announcing_turns_it_into_the_question_message(self) -> None:
        interaction = _Interaction()

        await _exchange(interaction).announce("**Zip** demande : q")

        self.assertEqual(interaction.edited, ["**Zip** demande : q"])


class TestTheThread(unittest.IsolatedAsyncioTestCase):
    async def test_it_hangs_off_the_question_message(self) -> None:
        interaction = _Interaction()
        exchange = _exchange(interaction)

        self.assertTrue(await exchange.open_thread("❓ q"))

    async def test_the_answer_goes_into_the_thread(self) -> None:
        interaction = _Interaction()
        exchange = _exchange(interaction)
        await exchange.open_thread("❓ q")

        await exchange.post("la réponse")

        self.assertEqual(interaction.followup.sent, [], "the answer bypassed the thread")

    async def test_a_refused_thread_is_reported_not_raised(self) -> None:
        """Losing the answer to a missing permission would be the worst outcome available."""
        interaction = _Interaction(thread_error=discord.HTTPException(cast(Any, _Stub()), "forbidden"))
        exchange = _exchange(interaction)

        self.assertFalse(await exchange.open_thread("❓ q"))

    async def test_without_a_thread_the_answer_is_posted_where_the_question_was_asked(self) -> None:
        interaction = _Interaction(thread_error=discord.HTTPException(cast(Any, _Stub()), "forbidden"))
        exchange = _exchange(interaction)
        await exchange.open_thread("❓ q")

        await exchange.post("la réponse")

        self.assertEqual(interaction.followup.sent, ["la réponse"])


class TestEditing(unittest.IsolatedAsyncioTestCase):
    async def test_an_edit_before_anything_was_posted_posts_instead(self) -> None:
        """Otherwise an early failure edits a message that does not exist, and shows nothing."""
        interaction = _Interaction(thread_error=discord.HTTPException(cast(Any, _Stub()), "no"))
        exchange = _exchange(interaction)
        await exchange.open_thread("❓ q")

        await exchange.edit("le message d'erreur")

        self.assertEqual(interaction.followup.sent, ["le message d'erreur"])

    async def test_a_refused_edit_does_not_escape_into_the_gateway(self) -> None:
        """An exception here becomes an unhandled gateway error and no message at all."""
        interaction = _Interaction(thread_error=discord.HTTPException(cast(Any, _Stub()), "no"))
        exchange = _exchange(interaction)
        await exchange.open_thread("❓ q")
        await exchange.post("placeholder")
        exchange._message.edit_error = discord.HTTPException(cast(Any, _Stub()), "rate limited")  # type: ignore[union-attr]

        await exchange.edit("la réponse")  # must not raise


class TestTheGatewayAsksForNoPrivilegedIntent(unittest.TestCase):
    """The bot reads slash-command options, never message content or member lists."""

    def test_it_reads_no_message_content(self) -> None:
        self.assertFalse(INTENTS.message_content)

    def test_it_reads_no_member_list(self) -> None:
        self.assertFalse(INTENTS.members)

    def test_it_reads_no_presences(self) -> None:
        self.assertFalse(INTENTS.presences)


class _Stub:
    """A stand-in for the ``aiohttp`` response ``discord.HTTPException`` wants."""

    status = 403
    reason = "Forbidden"


if __name__ == "__main__":
    unittest.main()
