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

    def __init__(self, name: str = "a report", *, error: Exception | None = None, archived: bool = False) -> None:
        """Initialize the thread.

        Args:
            name: Its name.
            error: Raised by :meth:`send`, when given.
            archived: Whether it is archived, which is what a closure leaves behind.
        """
        self.name = name
        self.archived = archived
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

    def __init__(
        self,
        cached: Any = None,
        fetched: Any = None,
        *,
        fetch_error: Exception | None = None,
        forum_id: int = 0,
        forum_tags: dict[str, str] | None = None,
    ) -> None:
        """Initialize the client.

        Args:
            cached: What ``get_channel`` returns.
            fetched: What ``fetch_channel`` returns.
            fetch_error: Raised by ``fetch_channel``, when given.
            forum_id: The follow-up forum this deployment is configured with; ``0`` is none.
            forum_tags: The tag each flow's post is opened under, by flow name. Defaults to the
                shipped defaults, which is what production runs with.
        """
        self._cached = cached
        self._fetched = fetched
        self._fetch_error = fetch_error
        self.fetches = 0
        self.followup_forum_id = forum_id
        self.followup_forum_tags = {"bug": "issue", "suggest": "suggestion"} if forum_tags is None else forum_tags

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

    async def test_the_mark_and_the_archive_come_off_when_the_issue_reopens(self) -> None:
        thread = _Thread(name=f"{CLOSED_MARK}a report", archived=True)
        client = _Client(cached=thread)

        self.assertTrue(await _poster(client).mark_reopened(10, 20))
        self.assertEqual(thread.edits[0]["name"], "a report")
        self.assertFalse(thread.edits[0]["archived"])

    async def test_a_thread_with_nothing_to_undo_costs_no_call(self) -> None:
        """Discord allows two renames per ten minutes; spending one on a no-op wastes the one that counts."""
        thread = _Thread(name="a report", archived=False)
        client = _Client(cached=thread)

        self.assertTrue(await _poster(client).mark_reopened(10, 20))
        self.assertEqual(thread.edits, [])

    async def test_an_archived_thread_that_was_never_marked_is_still_unarchived(self) -> None:
        thread = _Thread(name="a report", archived=True)
        client = _Client(cached=thread)

        self.assertTrue(await _poster(client).mark_reopened(10, 20))
        self.assertEqual(thread.edits[0]["name"], "a report")
        self.assertFalse(thread.edits[0]["archived"])

    async def test_a_refused_unmark_is_cosmetic_too(self) -> None:
        thread = _Thread(name=f"{CLOSED_MARK}a report", archived=True)
        thread.edit_error = _refused("forbidden")
        client = _Client(cached=thread)

        self.assertFalse(await _poster(client).mark_reopened(10, 20))

    async def test_a_thread_gone_before_the_unmark_is_not_an_error(self) -> None:
        client = _Client(fetch_error=_gone())

        self.assertFalse(await _poster(client).mark_reopened(10, 20))

    async def test_a_thread_unreachable_before_the_unmark_is_not_an_error_either(self) -> None:
        client = _Client(fetch_error=_refused())

        self.assertFalse(await _poster(client).mark_reopened(10, 20))


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

    def __init__(self, channel: Any, client: Any = None) -> None:
        """Initialize the interaction.

        Args:
            channel: The channel the command was used in.
            client: The gateway client, which is where the follow-up forum is read from. Defaults
                to one with no forum configured, which is the historical behaviour.
        """
        self.channel = channel
        self.client = client if client is not None else _Client()


class TestOpeningTheFollowUpThread(unittest.IsolatedAsyncioTestCase):
    """The room a maintainer's answer is carried into, opened after the click and before the filing."""

    def setUp(self) -> None:
        """Let the fake channel be a channel a thread can hang off."""
        patch = mock.patch("veaf_support_bot.discord_bot.THREADABLE", (_Channel,))
        patch.start()
        self.addCleanup(patch.stop)

    def _exchange(self, channel: Any, client: Any = None) -> ModalExchange:
        """Build a modal exchange over a fake interaction.

        Args:
            channel: The channel to open in.
            client: The gateway client; defaults to one with no forum configured.

        Returns:
            The exchange.
        """
        interaction = _Interaction(channel, client)
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


class _Tag:
    """One of a forum's tags."""

    def __init__(self, name: str, tag_id: int) -> None:
        """Initialize the tag.

        Args:
            name: What it is called on the forum.
            tag_id: Its id.
        """
        self.name = name
        self.id = tag_id


class _Forum:
    """A forum channel that can open a post, or refuse to."""

    def __init__(self, *, error: Exception | None = None, tags: list[str] | None = None) -> None:
        """Initialize the forum.

        Args:
            error: Raised by :meth:`create_thread`, when given.
            tags: The names of the tags this forum carries.
        """
        self.id = 30
        self.posts: list[tuple[str, str]] = []
        self.applied: list[list[str]] = []
        self.available_tags = [_Tag(name, 100 + i) for i, name in enumerate(tags or [])]
        self._error = error

    async def create_thread(
        self, *, name: str, content: str, allowed_mentions: Any = None, applied_tags: Any = None
    ) -> Any:
        """Open a post.

        Args:
            name: Its title.
            content: Its opening message, which Discord requires.
            allowed_mentions: What it may ping.
            applied_tags: The tags it carries.

        Returns:
            The ``ThreadWithMessage`` pair the library gives back.

        Raises:
            Exception: The one this forum was built with.
        """
        if self._error is not None:
            raise self._error
        self.posts.append((name, content))
        self.applied.append([tag.name for tag in applied_tags or []])
        opened = _OpenedThread()
        opened.name = name
        return _ThreadWithMessage(opened)


class _ThreadWithMessage:
    """The pair ``ForumChannel.create_thread`` returns, of which only the thread is used."""

    def __init__(self, thread: Any) -> None:
        """Initialize the pair.

        Args:
            thread: The post that was opened.
        """
        self.thread = thread
        self.message = object()


class TestTheFollowUpGoesIntoTheForum(unittest.IsolatedAsyncioTestCase):
    """Where a `/bug` or `/suggest` follow-up lands once a forum channel is configured.

    The forum is the deployment's choice and the anchored thread is the fallback, so every test
    here is really the same question asked twice: did the post go into the forum, and — when
    anything at all went wrong with it — did the follow-up survive in the channel instead? A
    report that loses its follow-up because a forum id was mistyped would be the one outcome worth
    refusing.
    """

    def setUp(self) -> None:
        """Let the fakes be the two channel kinds this branch tells apart."""
        for target, kinds in (("THREADABLE", (_Channel,)), ("FORUMABLE", (_Forum,))):
            patch = mock.patch(f"veaf_support_bot.discord_bot.{target}", kinds)
            patch.start()
            self.addCleanup(patch.stop)

    def _exchange(self, channel: Any, client: Any) -> ModalExchange:
        """Build a modal exchange over a fake interaction.

        Args:
            channel: The channel the command was used in.
            client: The gateway client the forum is read from.

        Returns:
            The exchange.
        """
        interaction = _Interaction(channel, client)
        return ModalExchange(cast(discord.Interaction, cast(object, interaction)), None, get_logger("test"))

    async def test_the_follow_up_is_a_post_in_the_forum_and_the_channel_stays_clean(self) -> None:
        forum = _Forum()
        channel = _Channel()

        handle = await self._exchange(channel, _Client(cached=forum, forum_id=30)).open_followup_thread("a report")

        self.assertTrue(handle.opened)
        self.assertEqual((handle.channel_id, handle.thread_id), (30, 20))
        self.assertEqual(handle.url, "https://discord.test/threads/20")
        self.assertEqual(forum.posts, [("a report", "a report")], "a forum post needs a title and a first message")
        self.assertEqual(channel.sent, [], "the anchor is what the forum replaces")

    async def test_a_cold_cache_fetches_the_forum(self) -> None:
        """On ``Intents.none()`` the cache is empty, so a configured forum must still be reached."""
        forum = _Forum()
        client = _Client(fetched=forum, forum_id=30)

        handle = await self._exchange(_Channel(), client).open_followup_thread("a report")

        self.assertEqual(client.fetches, 1)
        self.assertEqual((handle.channel_id, handle.thread_id), (30, 20))

    async def test_a_warm_cache_needs_no_fetch(self) -> None:
        client = _Client(cached=_Forum(), forum_id=30)

        await self._exchange(_Channel(), client).open_followup_thread("a report")

        self.assertEqual(client.fetches, 0)

    async def test_no_forum_configured_keeps_the_anchored_thread(self) -> None:
        channel = _Channel()
        client = _Client(cached=_Forum())

        handle = await self._exchange(channel, client).open_followup_thread("a report")

        self.assertEqual((handle.channel_id, handle.thread_id), (10, 20))
        self.assertEqual(channel.sent, ["a report"])
        self.assertEqual(client.fetches, 0, "an unconfigured forum must not cost a round trip")

    async def test_an_unreachable_forum_falls_back_to_the_anchored_thread(self) -> None:
        """A deleted channel, or an id belonging to another guild."""
        channel = _Channel()
        client = _Client(fetch_error=_gone("unknown channel"), forum_id=30)

        handle = await self._exchange(channel, client).open_followup_thread("a report")

        self.assertEqual((handle.channel_id, handle.thread_id), (10, 20))
        self.assertEqual(channel.sent, ["a report"])

    async def test_an_id_that_is_not_a_forum_falls_back_to_the_anchored_thread(self) -> None:
        """The likeliest mistake: the id of the text channel the commands are typed in."""
        channel = _Channel()

        handle = await self._exchange(channel, _Client(cached=object(), forum_id=30)).open_followup_thread("a report")

        self.assertEqual((handle.channel_id, handle.thread_id), (10, 20))
        self.assertEqual(channel.sent, ["a report"])

    async def test_a_forum_that_refuses_the_post_falls_back_to_the_anchored_thread(self) -> None:
        """A missing *Create Posts*, or a forum that requires a tag on every post."""
        channel = _Channel()
        forum = _Forum(error=_refused("tag required"))

        handle = await self._exchange(channel, _Client(cached=forum, forum_id=30)).open_followup_thread("a report")

        self.assertEqual((handle.channel_id, handle.thread_id), (10, 20))
        self.assertEqual(channel.sent, ["a report"])

    async def test_both_ways_refused_costs_the_follow_up_and_nothing_else(self) -> None:
        """No forum and no channel to anchor in: the report is still filed, without a follow-up."""
        client = _Client(cached=_Forum(error=_refused("no posts here")), forum_id=30)

        handle = await self._exchange(object(), client).open_followup_thread("a report")

        self.assertFalse(handle.opened)


class TestThePostCarriesTheTagTheForumRequires(unittest.IsolatedAsyncioTestCase):
    """A forum can require a tag on every post, and Discord refuses an untagged one outright.

    That is not a hypothetical: the VEAF forum has *Tags requis lorsque les gens postent* on, and
    the first `/bug` after the forum was configured came back with error code 40067. The tag is
    looked up by name because Discord's interface offers no way to copy a tag's id.
    """

    def setUp(self) -> None:
        """Let the fakes be the two channel kinds this branch tells apart."""
        for target, kinds in (("THREADABLE", (_Channel,)), ("FORUMABLE", (_Forum,))):
            patch = mock.patch(f"veaf_support_bot.discord_bot.{target}", kinds)
            patch.start()
            self.addCleanup(patch.stop)

    def _exchange(self, client: Any, *, flow: str = "bug") -> ModalExchange:
        """Build a modal exchange over a fake interaction, for one of the two flows.

        Args:
            client: The gateway client the forum and its tags are read from.
            flow: Which command this exchange serves — the prefix it logs under.

        Returns:
            The exchange.
        """
        interaction = _Interaction(_Channel(), client)
        return ModalExchange(
            cast(discord.Interaction, cast(object, interaction)), None, get_logger("test"), event_prefix=flow
        )

    async def test_a_bug_post_is_tagged_issue(self) -> None:
        forum = _Forum(tags=["issue", "suggestion", "question"])

        await self._exchange(_Client(cached=forum, forum_id=30)).open_followup_thread("a report")

        self.assertEqual(forum.applied, [["issue"]])

    async def test_a_suggestion_post_is_tagged_suggestion(self) -> None:
        """The same adapter serves both flows, and each must carry its own tag."""
        forum = _Forum(tags=["issue", "suggestion", "question"])

        await self._exchange(_Client(cached=forum, forum_id=30), flow="suggest").open_followup_thread("an idea")

        self.assertEqual(forum.applied, [["suggestion"]])

    async def test_the_name_is_matched_whatever_its_case(self) -> None:
        """The tag is typed by a human on Discord and by another in a `.env`; they will differ."""
        forum = _Forum(tags=["Issue"])

        await self._exchange(_Client(cached=forum, forum_id=30)).open_followup_thread("a report")

        self.assertEqual(forum.applied, [["Issue"]])

    async def test_a_tag_the_forum_does_not_carry_still_posts(self) -> None:
        """A forum that requires no tag must not lose its follow-up over a name that never matched."""
        forum = _Forum(tags=["bugs", "ideas"])

        handle = await self._exchange(_Client(cached=forum, forum_id=30)).open_followup_thread("a report")

        self.assertEqual((handle.channel_id, handle.thread_id), (30, 20))
        self.assertEqual(forum.applied, [[]])

    async def test_an_unmatched_tag_says_which_tags_exist(self) -> None:
        """The one line that turns "the forum does not work" into "the tag is called bugs"."""
        forum = _Forum(tags=["bugs", "ideas"])

        with self.assertLogs("veaf-support-bot.test", level="WARNING") as logged:
            await self._exchange(_Client(cached=forum, forum_id=30)).open_followup_thread("a report")

        recorded = [record for record in logged.records if getattr(record, "event", "") == "bug.forum_tag_missing"]
        self.assertEqual(len(recorded), 1)
        self.assertEqual(getattr(recorded[0], "wanted"), "issue")
        self.assertEqual(getattr(recorded[0], "available"), ["bugs", "ideas"])

    async def test_no_tag_configured_posts_without_one(self) -> None:
        forum = _Forum(tags=["issue"])

        await self._exchange(_Client(cached=forum, forum_id=30, forum_tags={})).open_followup_thread("a report")

        self.assertEqual(forum.applied, [[]])

    async def test_a_forum_requiring_a_tag_falls_back_when_none_matched(self) -> None:
        """Exactly the production failure: no tag applied, Discord refuses, the anchor takes over."""
        forum = _Forum(tags=["bugs"], error=_refused("A tag is required to create a forum post"))
        channel = _Channel()
        interaction = _Interaction(channel, _Client(cached=forum, forum_id=30))
        exchange = ModalExchange(cast(discord.Interaction, cast(object, interaction)), None, get_logger("test"))

        handle = await exchange.open_followup_thread("a report")

        self.assertEqual((handle.channel_id, handle.thread_id), (10, 20))
        self.assertEqual(channel.sent, ["a report"])


if __name__ == "__main__":
    unittest.main()
