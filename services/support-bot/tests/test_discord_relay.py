"""The Discord side of the relay: the follow-up thread, and writing into it after a restart.

Two things can only break here. A thread the cache does not hold — which, on ``Intents.none()``, is
every thread after a restart — must be **fetched** rather than treated as gone, or the relay quietly
forgets every report it was following the first time the service is redeployed. And a refusal has to
be told apart from a deletion: one is retried, the other ends the follow-up for good.
"""

from __future__ import annotations

import unittest
from typing import Any, cast
from unittest import mock

import discord

from veaf_support_bot.discord_bot import CLOSED_MARK, ClientThreadPoster, ModalExchange
from veaf_support_bot.logging_setup import get_logger


class _Stub:
    """A stand-in for the ``aiohttp`` response ``discord.HTTPException`` wants."""

    status = 429
    reason = "Too Many Requests"


def _refused(reason: str = "rate limited") -> discord.HTTPException:
    """Build a transient refusal.

    Args:
        reason: What Discord said.

    Returns:
        The exception.
    """
    return discord.HTTPException(cast(Any, _Stub()), reason)


def _gone(reason: str = "unknown channel") -> discord.NotFound:
    """Build a definitive refusal.

    Args:
        reason: What Discord said.

    Returns:
        The exception.
    """
    return discord.NotFound(cast(Any, _Stub()), reason)


class _Thread:
    """A thread that records what was sent, and can refuse."""

    def __init__(self, name: str = "a report", *, error: Exception | None = None) -> None:
        """Initialize the thread.

        Args:
            name: Its name.
            error: Raised by :meth:`send`, when given.
        """
        self.name = name
        self.sent: list[str] = []
        self.edits: list[dict[str, Any]] = []
        self.edit_error: Exception | None = None
        self._error = error

    async def send(self, content: str, allowed_mentions: Any = None) -> None:
        """Record a message.

        Args:
            content: What was sent.
            allowed_mentions: What it may ping.

        Raises:
            Exception: The one this thread was built with.
        """
        if self._error is not None:
            raise self._error
        self.sent.append(content)

    async def edit(self, **fields: Any) -> None:
        """Record an edit.

        Args:
            **fields: What was changed.

        Raises:
            Exception: :attr:`edit_error`, when set.
        """
        if self.edit_error is not None:
            raise self.edit_error
        self.edits.append(fields)


class _Client:
    """A gateway client with a cold or warm cache."""

    def __init__(self, cached: Any = None, fetched: Any = None, *, fetch_error: Exception | None = None) -> None:
        """Initialize the client.

        Args:
            cached: What ``get_channel`` returns.
            fetched: What ``fetch_channel`` returns.
            fetch_error: Raised by ``fetch_channel``, when given.
        """
        self._cached = cached
        self._fetched = fetched
        self._fetch_error = fetch_error
        self.fetches = 0

    def get_channel(self, channel_id: int) -> Any:
        """Return the cached channel.

        Args:
            channel_id: The channel.

        Returns:
            What the cache holds.
        """
        return self._cached

    async def fetch_channel(self, channel_id: int) -> Any:
        """Fetch the channel from the API.

        Args:
            channel_id: The channel.

        Returns:
            The channel.

        Raises:
            Exception: The one this client was built with.
        """
        self.fetches += 1
        if self._fetch_error is not None:
            raise self._fetch_error
        return self._fetched


def _poster(client: _Client) -> ClientThreadPoster:
    """Build the poster under test.

    Args:
        client: The client to reach Discord through.

    Returns:
        The poster.
    """
    return ClientThreadPoster(cast(discord.Client, cast(object, client)), get_logger("test"))


class TestPostingIntoAFollowedThread(unittest.IsolatedAsyncioTestCase):
    """``isinstance(..., discord.Thread)`` decides, so every double is one for real."""

    def setUp(self) -> None:
        """Make the fake threads pass the library's own type check."""
        patch = mock.patch("veaf_support_bot.discord_bot.discord.Thread", _Thread)
        patch.start()
        self.addCleanup(patch.stop)

    async def test_a_cached_thread_is_written_to_without_a_fetch(self) -> None:
        thread = _Thread()
        client = _Client(cached=thread)

        posted = await _poster(client).post_to_thread(10, 20, "a maintainer replied")

        self.assertTrue(posted)
        self.assertEqual(thread.sent, ["a maintainer replied"])
        self.assertEqual(client.fetches, 0)

    async def test_a_cold_cache_fetches_rather_than_giving_up(self) -> None:
        """After a restart the cache is empty; giving up here forgets every followed report."""
        thread = _Thread()
        client = _Client(cached=None, fetched=thread)

        posted = await _poster(client).post_to_thread(10, 20, "hello")

        self.assertTrue(posted)
        self.assertEqual(client.fetches, 1)

    async def test_a_thread_that_cannot_be_reached_at_all_is_gone(self) -> None:
        client = _Client(fetch_error=_gone())

        self.assertFalse(await _poster(client).post_to_thread(10, 20, "hello"))

    async def test_a_rate_limit_is_raised_so_the_link_is_kept(self) -> None:
        """Dropping a link on a 429 would end the follow-up over a transient refusal."""
        client = _Client(cached=_Thread(error=_refused()))

        with self.assertRaises(discord.HTTPException):
            await _poster(client).post_to_thread(10, 20, "hello")

    async def test_a_deleted_thread_answers_gone_rather_than_raising(self) -> None:
        client = _Client(cached=_Thread(error=_gone("unknown message")))

        self.assertFalse(await _poster(client).post_to_thread(10, 20, "hello"))

    async def test_the_thread_is_renamed_and_archived_when_the_issue_closes(self) -> None:
        thread = _Thread(name="a report")
        client = _Client(cached=thread)

        self.assertTrue(await _poster(client).mark_closed(10, 20))
        self.assertTrue(thread.edits[0]["name"].startswith(CLOSED_MARK))
        self.assertTrue(thread.edits[0]["archived"])

    async def test_a_second_closure_does_not_stack_the_mark(self) -> None:
        thread = _Thread(name=f"{CLOSED_MARK}a report")
        client = _Client(cached=thread)

        await _poster(client).mark_closed(10, 20)

        self.assertEqual(thread.edits[0]["name"].count(CLOSED_MARK), 1)

    async def test_a_refused_mark_is_cosmetic_and_never_fails_the_round(self) -> None:
        thread = _Thread()
        thread.edit_error = _refused("forbidden")
        client = _Client(cached=thread)

        self.assertFalse(await _poster(client).mark_closed(10, 20))


class _Anchor:
    """The public message a follow-up thread hangs off."""

    def __init__(self, error: Exception | None = None) -> None:
        """Initialize the anchor.

        Args:
            error: Raised by :meth:`create_thread`, when given.
        """
        self._error = error

    async def create_thread(self, name: str) -> Any:
        """Open the thread.

        Args:
            name: Its name.

        Returns:
            A thread-shaped object.

        Raises:
            Exception: The one this anchor was built with.
        """
        if self._error is not None:
            raise self._error
        opened = _OpenedThread()
        opened.name = name
        return opened


class _OpenedThread:
    """What ``create_thread`` gives back."""

    id = 20
    jump_url = "https://discord.test/threads/20"
    name = ""


class _Channel:
    """A text channel that can hold a thread, or refuse to."""

    def __init__(self, *, send_error: Exception | None = None, thread_error: Exception | None = None) -> None:
        """Initialize the channel.

        Args:
            send_error: Raised when the anchor is posted, when given.
            thread_error: Raised when the thread is opened, when given.
        """
        self.id = 10
        self.sent: list[str] = []
        self._send_error = send_error
        self._thread_error = thread_error

    async def send(self, content: str, allowed_mentions: Any = None) -> Any:
        """Post the anchor message.

        Args:
            content: What was sent.
            allowed_mentions: What it may ping.

        Returns:
            The anchor.

        Raises:
            Exception: The one this channel was built with.
        """
        if self._send_error is not None:
            raise self._send_error
        self.sent.append(content)
        return _Anchor(self._thread_error)


class _Interaction:
    """The parts of an interaction the thread opening touches."""

    def __init__(self, channel: Any) -> None:
        """Initialize the interaction.

        Args:
            channel: The channel the command was used in.
        """
        self.channel = channel


class TestOpeningTheFollowUpThread(unittest.IsolatedAsyncioTestCase):
    """The room a maintainer's answer is carried into, opened after the click and before the filing."""

    def setUp(self) -> None:
        """Let the fake channel be a channel a thread can hang off."""
        patch = mock.patch("veaf_support_bot.discord_bot.THREADABLE", (_Channel,))
        patch.start()
        self.addCleanup(patch.stop)

    def _exchange(self, channel: Any) -> ModalExchange:
        """Build a modal exchange over a fake interaction.

        Args:
            channel: The channel to open in.

        Returns:
            The exchange.
        """
        interaction = _Interaction(channel)
        return ModalExchange(cast(discord.Interaction, cast(object, interaction)), None, get_logger("test"))

    async def test_a_thread_is_opened_and_its_address_comes_back(self) -> None:
        channel = _Channel()

        handle = await self._exchange(channel).open_followup_thread("a report")

        self.assertTrue(handle.opened)
        self.assertEqual((handle.channel_id, handle.thread_id), (10, 20))
        self.assertEqual(handle.url, "https://discord.test/threads/20")
        self.assertEqual(channel.sent, ["a report"], "the thread needs a public message to hang off")

    async def test_a_channel_that_cannot_hold_a_thread_yields_none(self) -> None:
        """A DM, a forum post, a thread: the report is filed anyway, without a follow-up."""
        handle = await self._exchange(object()).open_followup_thread("a report")

        self.assertFalse(handle.opened)

    async def test_a_refused_anchor_yields_no_thread_rather_than_raising(self) -> None:
        """A missing *Send Messages* must cost the follow-up, never the report."""
        handle = await self._exchange(_Channel(send_error=_refused("no permission"))).open_followup_thread("r")

        self.assertFalse(handle.opened)

    async def test_a_refused_thread_yields_no_thread_rather_than_raising(self) -> None:
        handle = await self._exchange(_Channel(thread_error=_refused("no threads here"))).open_followup_thread("r")

        self.assertFalse(handle.opened)


if __name__ == "__main__":
    unittest.main()
