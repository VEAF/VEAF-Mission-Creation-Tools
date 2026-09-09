"""Ticket 06: the answer comes back, exactly once, and one dead thread does not stop the rest.

The relay runs unattended in a background task, which is what makes its failure modes expensive:
nothing tells anybody it stopped. So what is asserted here is mostly *not* the happy path —

* its own comments are never relayed, or the bot answers its own hypothesis for ever;
* a comment already carried over is not carried over twice, across a restart included;
* a transient GitHub failure moves no cursor, so nothing is lost;
* a deleted thread drops one link and leaves every other report followed;
* a *deleted issue* drops one too — the failure that is not transient, however alike it looks;
* a closure is announced once, and a **reopening** reaches the thread rather than nowhere.

The cursor is a comment **id**, never a timestamp: two comments in the same second would race, and
this is the kind of bug that shows up as "the reporter missed the one answer that mattered".
"""

from __future__ import annotations

import asyncio
import json
import tempfile
import unittest
from dataclasses import replace
from pathlib import Path
from typing import Any, cast

from tests.test_github_app import PEM, credentials
from veaf_support_bot.config import SupportBotConfig
from veaf_support_bot.github_app import GitHubApp, Response
from veaf_support_bot.relay import (
    COMMENT_PAGE_SIZE,
    KEEP_CLOSED_SECONDS,
    LINKS_VERSION,
    MAX_COMMENT_PAGES,
    MAX_RELAYED_PER_ROUND,
    Comment,
    IssueGone,
    IssueState,
    IssueWatcher,
    Link,
    LinkStore,
    Relay,
    relayable,
    render_comment,
)
from veaf_support_bot.service import SupportBotService, _NoPoster, build_relay


class _Watcher:
    """A watcher with scripted answers, one per round."""

    def __init__(self, *rounds: IssueState | None | Exception) -> None:
        """Initialize the watcher.

        Args:
            *rounds: What each successive round returns; the last one repeats. An exception is
                raised rather than returned, which is how the deleted issue is scripted.
        """
        self._rounds: list[IssueState | None | Exception] = list(rounds) or [IssueState()]
        self.seen: list[tuple[int, int]] = []

    async def since(self, issue: int, last_comment_id: int) -> IssueState | None:
        """Answer one round.

        Args:
            issue: The issue polled.
            last_comment_id: The cursor it was polled with.

        Returns:
            The scripted state.

        Raises:
            Exception: The one scripted for this round.
        """
        self.seen.append((issue, last_comment_id))
        answer = self._rounds[min(len(self.seen) - 1, len(self._rounds) - 1)]
        if isinstance(answer, Exception):
            raise answer
        return answer


class _Poster:
    """A poster that records what reached which thread."""

    def __init__(
        self,
        *,
        gone: bool = False,
        raises: Exception | None = None,
        refuse_marks: int = 0,
    ) -> None:
        """Initialize the poster.

        Args:
            gone: Whether every thread answers "I no longer exist".
            raises: Raised instead of posting, for the transient case.
            refuse_marks: How many of the first mark calls are refused — Discord allows a thread
                only two renames every ten minutes.
        """
        self.posted: list[tuple[int, str]] = []
        self.marked: list[int] = []
        self.unmarked: list[int] = []
        self.gone = gone
        self.raises = raises
        self.refuse_marks = refuse_marks

    async def post_to_thread(self, channel_id: int, thread_id: int, content: str) -> bool:
        """Record a post.

        Args:
            channel_id: The channel.
            thread_id: The thread.
            content: What was posted.

        Returns:
            Whether it was posted.

        Raises:
            Exception: The one this poster was built with.
        """
        if self.raises is not None:
            raise self.raises
        if self.gone:
            return False
        self.posted.append((thread_id, content))
        return True

    async def mark_closed(self, channel_id: int, thread_id: int) -> bool:
        """Record a closure mark.

        Args:
            channel_id: The channel.
            thread_id: The thread.

        Returns:
            Whether it was applied.
        """
        self.marked.append(thread_id)
        return self._accepted()

    async def mark_reopened(self, channel_id: int, thread_id: int) -> bool:
        """Record the removal of a closure mark.

        Args:
            channel_id: The channel.
            thread_id: The thread.

        Returns:
            Whether it was removed.
        """
        self.unmarked.append(thread_id)
        return self._accepted()

    def _accepted(self) -> bool:
        """Say whether this mark call is accepted, spending one refusal when it is not.

        Returns:
            Whether Discord took it.
        """
        if self.refuse_marks <= 0:
            return True
        self.refuse_marks -= 1
        return False


def _comment(identifier: int, body: str = "can you attach your dcs.log?", *, bot: bool = False) -> Comment:
    """Build a comment.

    Args:
        identifier: Its id.
        body: What it says.
        bot: Whether a bot wrote it.

    Returns:
        The comment.
    """
    return Comment(identifier=identifier, author="veaf-bot[bot]" if bot else "Zip", body=body, by_bot=bot)


#: A fixed "now" for the retention tests, so a window measured in days needs no waiting and no
#: dependence on the machine's clock.
NOW = 1_700_000_000.0


def _relay(
    watcher: _Watcher,
    poster: Any,
    *,
    links: list[Link] | None = None,
    clock: Any = None,
) -> tuple[Relay, LinkStore]:
    """Build a relay over a temporary store.

    Args:
        watcher: What answers for GitHub.
        poster: What answers for Discord.
        links: Links to start from.
        clock: Source of timestamps, for the retention window.

    Returns:
        The relay and its store.
    """
    folder = tempfile.mkdtemp()
    store = LinkStore(Path(folder) / "relay-links.json")
    if links:
        store.save({link.issue: link for link in links})
    relay = Relay(
        watcher,  # type: ignore[arg-type]
        poster,
        store,
        repository="VEAF/VEAF-Mission-Creation-Tools",
        clock=clock,
    )
    return relay, store


def _link(issue: int = 901, **overrides: Any) -> Link:
    """Build a link.

    Args:
        issue: The issue number.
        **overrides: Fields to replace.

    Returns:
        The link.
    """
    base = {"issue": issue, "channel_id": 10, "thread_id": 20, "lang": "en"}
    base.update(overrides)
    return Link(**base)  # type: ignore[arg-type]


class TestWhatComesBack(unittest.IsolatedAsyncioTestCase):
    async def test_a_maintainers_comment_reaches_the_thread(self) -> None:
        watcher = _Watcher(IssueState(comments=(_comment(1),)))
        poster = _Poster()
        relay, _ = _relay(watcher, poster, links=[_link()])

        result = await relay.run_once()

        self.assertEqual(result.relayed, 1)
        self.assertIn("dcs.log", poster.posted[0][1])
        self.assertIn("Zip", poster.posted[0][1])

    async def test_the_issue_is_named_and_linked_so_the_thread_is_not_a_dead_end(self) -> None:
        watcher = _Watcher(IssueState(comments=(_comment(1),)))
        poster = _Poster()
        relay, _ = _relay(watcher, poster, links=[_link(issue=712)])

        await relay.run_once()

        self.assertIn("#712", poster.posted[0][1])
        self.assertIn("issues/712", poster.posted[0][1])

    async def test_a_closure_is_announced_and_marked_once(self) -> None:
        watcher = _Watcher(IssueState(closed=True))
        poster = _Poster()
        relay, _ = _relay(watcher, poster, links=[_link()])

        first = await relay.run_once()
        second = await relay.run_once()

        self.assertEqual((first.closed, second.closed), (1, 0))
        self.assertEqual(poster.marked, [20])
        self.assertEqual(len(poster.posted), 1, "a closed issue must not be announced every round")


class TestTheLoopItMustNotHave(unittest.IsolatedAsyncioTestCase):
    """The service files under an App, so its own writing comes back through the same endpoint."""

    async def test_its_own_comments_are_never_relayed(self) -> None:
        watcher = _Watcher(IssueState(comments=(_comment(1, "## Automatic hypothesis", bot=True),)))
        poster = _Poster()
        relay, _ = _relay(watcher, poster, links=[_link()])

        result = await relay.run_once()

        self.assertEqual(result.relayed, 0)
        self.assertEqual(poster.posted, [])

    def test_the_rule_is_one_testable_place(self) -> None:
        kept = relayable([_comment(1), _comment(2, bot=True), _comment(3)])

        self.assertEqual([comment.identifier for comment in kept], [1, 3])


class TestNothingIsSaidTwice(unittest.IsolatedAsyncioTestCase):
    async def test_the_cursor_advances_past_what_was_relayed(self) -> None:
        watcher = _Watcher(IssueState(comments=(_comment(7),)), IssueState())
        poster = _Poster()
        relay, store = _relay(watcher, poster, links=[_link()])

        await relay.run_once()
        await relay.run_once()

        self.assertEqual(watcher.seen[1][1], 7, "the second round must ask for comments after 7")
        self.assertEqual(store.load()[901].last_comment_id, 7)

    async def test_the_cursor_survives_a_restart(self) -> None:
        """The whole point of persisting: a restart must not replay every comment into the thread."""
        watcher = _Watcher(IssueState(comments=(_comment(7),)))
        poster = _Poster()
        relay, store = _relay(watcher, poster, links=[_link()])
        await relay.run_once()

        restarted = Relay(_Watcher(IssueState()), poster, store, repository="o/n")  # type: ignore[arg-type]
        await restarted.run_once()

        self.assertEqual(len(poster.posted), 1)

    async def test_a_transient_failure_moves_no_cursor(self) -> None:
        """``None`` means "GitHub could not be asked", which must not read as "nothing is new"."""
        watcher = _Watcher(None, IssueState(comments=(_comment(7),)))
        poster = _Poster()
        relay, _ = _relay(watcher, poster, links=[_link()])

        first = await relay.run_once()
        second = await relay.run_once()

        self.assertEqual((first.failed, first.relayed), (1, 0))
        self.assertEqual(second.relayed, 1, "the comment must arrive on the next round, not be lost")


class TestOneBadThreadDoesNotStopTheRest(unittest.IsolatedAsyncioTestCase):
    async def test_a_deleted_thread_drops_only_its_own_link(self) -> None:
        watcher = _Watcher(IssueState(comments=(_comment(1),)))
        relay, store = _relay(watcher, _Poster(gone=True), links=[_link(901), _link(902, thread_id=21)])

        result = await relay.run_once()

        self.assertEqual(result.polled, 2)
        self.assertEqual(result.dropped, 2, "both were unreachable, and both were given up on")
        self.assertEqual(store.load(), {})

    async def test_a_refused_post_keeps_the_link_for_the_next_round(self) -> None:
        """Rate-limited is not deleted: dropping a link there would lose the follow-up for good."""
        relay, store = _relay(
            _Watcher(IssueState(comments=(_comment(1),))),
            _Poster(raises=RuntimeError("429")),
            links=[_link()],
        )

        result = await relay.run_once()

        self.assertEqual(result.dropped, 0)
        self.assertEqual(result.failed, 1)

    async def test_a_burst_of_comments_is_bounded_and_says_so(self) -> None:
        comments = tuple(_comment(index) for index in range(1, MAX_RELAYED_PER_ROUND + 4))
        poster = _Poster()
        relay, _ = _relay(_Watcher(IssueState(comments=comments)), poster, links=[_link()])

        result = await relay.run_once()

        self.assertEqual(result.relayed, MAX_RELAYED_PER_ROUND)
        self.assertIn("more messages", poster.posted[-1][1], "the rest must not be silently dropped")


class TestTheStore(unittest.TestCase):
    def test_an_unreadable_file_does_not_stop_the_service(self) -> None:
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "relay-links.json"
            path.write_text("{ this is not json", encoding="utf-8")

            self.assertEqual(LinkStore(path).load(), {})

    def test_a_file_of_another_version_is_refused_rather_than_reinterpreted(self) -> None:
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "relay-links.json"
            path.write_text(json.dumps({"version": LINKS_VERSION + 1, "links": []}), encoding="utf-8")

            self.assertEqual(LinkStore(path).load(), {})

    def test_one_bad_entry_does_not_lose_the_others(self) -> None:
        """The other reporters did nothing wrong."""
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "relay-links.json"
            document = {
                "version": LINKS_VERSION,
                "links": [{"issue": "not a number"}, {"issue": 5, "channel_id": 1, "thread_id": 2}],
            }
            path.write_text(json.dumps(document), encoding="utf-8")

            self.assertEqual(list(LinkStore(path).load()), [5])

    def test_a_remembered_report_is_readable_by_the_next_process(self) -> None:
        with tempfile.TemporaryDirectory() as folder:
            store = LinkStore(Path(folder) / "state" / "relay-links.json")
            relay = Relay(_Watcher(), _Poster(), store, repository="o/n")  # type: ignore[arg-type]

            relay.remember(901, channel_id=10, thread_id=20, lang="fr")

            self.assertEqual(store.load()[901].thread_id, 20)
            self.assertEqual(store.load()[901].lang, "fr")

    def test_an_issue_with_no_thread_is_not_followed(self) -> None:
        """Nothing to answer into: following it would poll forever for nobody."""
        with tempfile.TemporaryDirectory() as folder:
            store = LinkStore(Path(folder) / "relay-links.json")
            relay = Relay(_Watcher(), _Poster(), store, repository="o/n")  # type: ignore[arg-type]

            relay.remember(901, channel_id=0, thread_id=0, lang="fr")

            self.assertEqual(relay.tracked, 0)


class TestTheRenderedMessage(unittest.TestCase):
    def test_a_long_comment_is_cut_visibly_and_points_at_the_issue(self) -> None:
        rendered = render_comment(_comment(1, "x" * 5000), 901, "https://example.invalid/901", "en")

        self.assertIn("truncated", rendered)
        self.assertIn("https://example.invalid/901", rendered)

    def test_a_comment_cannot_ping_the_thread(self) -> None:
        rendered = render_comment(_comment(1, "@everyone look at this"), 901, "u", "en")

        self.assertNotIn("@everyone", rendered)


class _Transport:
    """A GitHub transport answering the two calls one round makes."""

    def __init__(
        self,
        comments: list[dict[str, Any]],
        state: str = "open",
        *,
        fail: bool = False,
        status: int = 503,
        fail_comments: bool = False,
    ) -> None:
        """Initialize the transport.

        Args:
            comments: What the comments endpoint returns.
            state: The issue state.
            fail: Whether every call is refused.
            status: The status a refused call answers with.
            fail_comments: Whether only the *comments* call is refused — an issue can be deleted
                between the read of its state and the read of its comments.
        """
        self.comments = comments
        self.state = state
        self.fail = fail
        self.status = status
        self.fail_comments = fail_comments
        self.urls: list[str] = []

    async def __call__(self, method: str, url: str, headers: Any, body: Any) -> Response:
        """Answer one call.

        Args:
            method: The HTTP method.
            url: The URL.
            headers: The request headers.
            body: The request body.

        Returns:
            The canned response.
        """
        if url.endswith("/access_tokens"):
            return Response(201, {"token": "ghs-t", "expires_at": "2999-01-01T00:00:00Z"})
        self.urls.append(url)
        if self.fail:
            return Response(self.status, {"message": "unavailable"})
        if url.endswith("/comments") or "/comments?" in url:
            if self.fail_comments:
                return Response(self.status, {"message": "This issue was deleted"})
            return Response(200, self.comments)
        return Response(200, {"number": 901, "state": self.state})


def _api_comment(identifier: int, login: str = "Zip", kind: str = "User") -> dict[str, Any]:
    """Build one API comment object.

    Args:
        identifier: Its id.
        login: Who wrote it.
        kind: ``"User"`` or ``"Bot"``.

    Returns:
        The decoded comment.
    """
    return {"id": identifier, "body": f"comment {identifier}", "user": {"login": login, "type": kind}}


class TestReadingTheIssue(unittest.IsolatedAsyncioTestCase):
    """What the watcher makes of GitHub's answers — including the ones it does not get."""

    def _watcher(self, transport: _Transport) -> IssueWatcher:
        """Build a watcher over a fake transport.

        Args:
            transport: What answers.

        Returns:
            The watcher.
        """
        return IssueWatcher(GitHubApp(credentials(), "VEAF/VEAF-Mission-Creation-Tools", transport))

    async def test_a_deleted_issue_is_definitive(self) -> None:
        transport = _Transport([], fail=True, status=410)

        with self.assertRaises(IssueGone):
            await self._watcher(transport).since(901, 0)

    async def test_an_issue_deleted_between_the_two_calls_is_definitive_too(self) -> None:
        transport = _Transport([_api_comment(1)], fail_comments=True, status=410)

        with self.assertRaises(IssueGone):
            await self._watcher(transport).since(901, 0)

    async def test_the_transient_statuses_stay_transient(self) -> None:
        """A `404` is a deletion **and** a permission lost for a minute; only `410` has one meaning."""
        for status in (403, 404, 429, 500, 503):
            with self.subTest(status=status):
                state = await self._watcher(_Transport([], fail=True, status=status)).since(901, 0)

                self.assertIsNone(state)

    async def test_only_comments_past_the_cursor_come_back(self) -> None:
        transport = _Transport([_api_comment(1), _api_comment(9)])

        state = await self._watcher(transport).since(901, 1)

        assert state is not None
        self.assertEqual([comment.identifier for comment in state.comments], [9])

    async def test_they_come_back_oldest_first(self) -> None:
        """Relayed out of order, a maintainer's exchange reads backwards in the thread."""
        transport = _Transport([_api_comment(9), _api_comment(3), _api_comment(5)])

        state = await self._watcher(transport).since(901, 0)

        assert state is not None
        self.assertEqual([comment.identifier for comment in state.comments], [3, 5, 9])

    async def test_a_bot_author_is_marked_as_such(self) -> None:
        transport = _Transport([_api_comment(1, "veaf-support[bot]", "Bot")])

        state = await self._watcher(transport).since(901, 0)

        assert state is not None
        self.assertTrue(state.comments[0].by_bot)

    async def test_a_closed_issue_is_reported_closed(self) -> None:
        state = await self._watcher(_Transport([], state="closed")).since(901, 0)

        assert state is not None
        self.assertTrue(state.closed)

    async def test_an_unreachable_github_answers_none_rather_than_empty(self) -> None:
        """Empty would read as "nothing new" and move the cursor past comments never delivered."""
        self.assertIsNone(await self._watcher(_Transport([], fail=True)).since(901, 0))


class TestTheServiceRunsIt(unittest.IsolatedAsyncioTestCase):
    """The relay only exists as a background loop somebody starts and something feeds.

    Both halves have failed silently in this repository before: a loop nobody starts, and an object
    built with a placeholder that is never replaced. Neither shows up as an error — the reports are
    filed, and the follow-up simply never happens.
    """

    def _config(self, **overrides: str) -> Any:
        """Build a configuration.

        Args:
            **overrides: Variables to set, without the ``SUPPORT_BOT_`` prefix.

        Returns:
            The resolved configuration.
        """
        env = {
            "SUPPORT_BOT_DISCORD_TOKEN": "a-token",
            "SUPPORT_BOT_DISCORD_GUILD_ID": "1",
            "SUPPORT_BOT_WORKER_SECRET": "a-secret",
            "SUPPORT_BOT_HEALTH_PORT": "0",
        }
        env.update({f"SUPPORT_BOT_{key}": value for key, value in overrides.items()})
        return SupportBotConfig.from_env(env)

    def test_no_github_app_means_no_relay(self) -> None:
        """Nothing of ours to poll, so nothing to poll it with."""
        self.assertIsNone(build_relay(self._config()))

    def test_a_configured_app_produces_a_relay(self) -> None:
        with tempfile.TemporaryDirectory() as folder:
            key = Path(folder) / "key.pem"
            key.write_text(PEM, encoding="utf-8")

            relay = build_relay(
                self._config(
                    GITHUB_APP_ID="123456",
                    GITHUB_INSTALLATION_ID="7890",
                    GITHUB_PRIVATE_KEY_FILE=str(key),
                    RELAY_LINKS_FILE=str(Path(folder) / "relay-links.json"),
                )
            )

            self.assertIsNotNone(relay)

    def test_the_placeholder_poster_refuses_so_it_cannot_go_unnoticed(self) -> None:
        """It answers "gone", which drops links — so a relay left holding it is loud, not silent."""
        placeholder = _NoPoster()

        self.assertFalse(asyncio.run(placeholder.post_to_thread(1, 2, "x")))
        self.assertFalse(asyncio.run(placeholder.mark_closed(1, 2)))
        self.assertFalse(asyncio.run(placeholder.mark_reopened(1, 2)))
        self.assertEqual(placeholder.calls, 3, "every refusal is counted, so a test can prove it was replaced")

    async def test_attaching_replaces_the_placeholder(self) -> None:
        poster = _Poster()
        relay, _ = _relay(_Watcher(IssueState(comments=(_comment(1),))), _NoPoster(), links=[_link()])

        relay.attach(poster)
        result = await relay.run_once()

        self.assertEqual(result.relayed, 1)
        self.assertEqual(result.dropped, 0)

    async def test_the_loop_polls_and_survives_a_bad_round(self) -> None:
        """One failing round must not end the follow-up for every other report."""
        service = SupportBotService(self._config(DRY_RUN="false"), gateway=_Silent())
        rounds: list[int] = []

        class _Explodes:
            async def run_once(self) -> None:
                rounds.append(len(rounds))
                if len(rounds) == 1:
                    raise RuntimeError("github said no")

        service.relay = cast(Any, _Explodes())
        service.config = replace(service.config, relay_poll_seconds=0.01)
        loop = asyncio.ensure_future(service._relay_loop())  # noqa: SLF001 - the loop is the subject
        for _ in range(200):
            if len(rounds) >= 3:
                break
            await asyncio.sleep(0.01)
        loop.cancel()

        self.assertGreaterEqual(len(rounds), 3, "the loop stopped after the round that raised")

    async def test_a_dry_run_polls_nothing(self) -> None:
        """It connects to nothing, so there is nothing to answer into."""
        service = SupportBotService(self._config(DRY_RUN="true"))
        service.relay = cast(Any, _Explodes := object())

        await asyncio.wait_for(service._relay_loop(), timeout=1)  # noqa: SLF001 - the loop is the subject


class _Silent:
    """A gateway that connects to nothing."""

    async def start(self) -> None:
        """Never return until cancelled."""
        await asyncio.Event().wait()

    async def close(self) -> None:
        """Close nothing."""


class TestWhatTheCeilingMustNotLose(unittest.IsolatedAsyncioTestCase):
    """Found in review, noted 100: the cursor advanced past comments the code promised to relay.

    The bug: the branch written for a bot's comment also caught the human comments the per-round
    ceiling had rejected, and moved the cursor over them. Five were relayed, the reporter was told
    the rest would come next round, and they never did — silently, for ever. The old test asserted
    the count and the message, never the cursor: that was the angle blind.
    """

    async def test_the_cursor_stops_at_the_ceiling_so_the_rest_arrives_next_round(self) -> None:
        comments = tuple(_comment(index) for index in range(1, 9))
        poster = _Poster()
        relay, store = _relay(_Watcher(IssueState(comments=comments)), poster, links=[_link()])

        await relay.run_once()

        self.assertEqual(store.load()[901].last_comment_id, MAX_RELAYED_PER_ROUND)

    async def test_the_ones_it_could_not_carry_are_carried_next_round(self) -> None:
        first = tuple(_comment(index, f"answer {index}") for index in range(1, 9))
        rest = tuple(_comment(index, f"answer {index}") for index in range(6, 9))
        poster = _Poster()
        relay, _ = _relay(_Watcher(IssueState(comments=first), IssueState(comments=rest)), poster, links=[_link()])

        await relay.run_once()
        await relay.run_once()

        bodies = [content for _, content in poster.posted]
        for identifier in (6, 7, 8):
            with self.subTest(comment=identifier):
                self.assertTrue(any(f"answer {identifier}" in body for body in bodies))

    async def test_a_bot_comment_between_two_human_ones_does_not_hold_the_cursor(self) -> None:
        """The reason the branch existed: its own hypothesis must not be re-read every round."""
        comments = (_comment(1), _comment(2, bot=True), _comment(3))
        relay, store = _relay(_Watcher(IssueState(comments=comments)), _Poster(), links=[_link()])

        await relay.run_once()

        self.assertEqual(store.load()[901].last_comment_id, 3)


class TestATransientDiscordFailureKeepsTheReport(unittest.IsolatedAsyncioTestCase):
    """Found in review, noted 75: a 503 dropped every followed report, permanently."""

    async def test_a_raised_failure_keeps_the_link(self) -> None:
        relay, store = _relay(
            _Watcher(IssueState(comments=(_comment(1),))),
            _Poster(raises=RuntimeError("Discord answered 503")),
            links=[_link()],
        )

        result = await relay.run_once()

        self.assertEqual(result.dropped, 0)
        self.assertIn(901, store.load(), "a bad minute at Discord must not end a follow-up")

    async def test_only_a_definitive_refusal_drops_it(self) -> None:
        relay, store = _relay(_Watcher(IssueState(comments=(_comment(1),))), _Poster(gone=True), links=[_link()])

        result = await relay.run_once()

        self.assertEqual(result.dropped, 1)
        self.assertEqual(store.load(), {})


class TestAClosureIsNotTheEnd(unittest.IsolatedAsyncioTestCase):
    """#946: closed one evening, reopened the next morning, ten comments relayed nowhere.

    The link used to be dropped the moment the closure was announced. That is the only thing that
    can carry a reopening back to the reporter, and `relay.closed` invites him to ask for exactly
    that — so the drop silenced the thread on the normal answer to its own last sentence.
    """

    async def test_a_reopening_is_announced_and_unmarks_the_thread(self) -> None:
        poster = _Poster()
        relay, _ = _relay(
            _Watcher(IssueState(closed=False)),
            poster,
            links=[_link(closed=True, closed_since=NOW - 3600.0, closed_marked=True)],
            clock=lambda: NOW,
        )

        result = await relay.run_once()

        self.assertEqual(result.reopened, 1)
        self.assertIn("reopened", poster.posted[0][1])
        self.assertEqual(poster.unmarked, [20])

    async def test_a_reopening_is_announced_once(self) -> None:
        poster = _Poster()
        relay, _ = _relay(
            _Watcher(IssueState(closed=False)),
            poster,
            links=[_link(closed=True, closed_since=NOW - 3600.0)],
            clock=lambda: NOW,
        )

        first = await relay.run_once()
        second = await relay.run_once()

        self.assertEqual((first.reopened, second.reopened), (1, 0))
        self.assertEqual(len(poster.posted), 1, "an open issue must not be reopened every round")

    async def test_the_reopening_comes_before_what_was_said_since(self) -> None:
        """Otherwise the backlog lands under a thread still named `✅` and still archived."""
        poster = _Poster()
        relay, _ = _relay(
            _Watcher(IssueState(comments=(_comment(1), _comment(2)), closed=False)),
            poster,
            links=[_link(closed=True, closed_since=NOW - 3600.0)],
            clock=lambda: NOW,
        )

        await relay.run_once()

        self.assertIn("reopened", poster.posted[0][1])
        self.assertEqual(len(poster.posted), 3, "the reopening, then both comments")

    async def test_a_link_closed_within_the_window_is_still_polled(self) -> None:
        watcher = _Watcher(IssueState(closed=True))
        relay, store = _relay(
            watcher,
            _Poster(),
            links=[_link(closed=True, closed_since=NOW - KEEP_CLOSED_SECONDS + 60.0)],
            clock=lambda: NOW,
        )

        result = await relay.run_once()

        self.assertEqual(result.forgotten, 0)
        self.assertEqual(len(watcher.seen), 1, "it must still be asked about, or a reopening is lost")
        self.assertIn(901, store.load())

    async def test_a_link_closed_for_the_whole_window_is_forgotten(self) -> None:
        watcher = _Watcher(IssueState(closed=True))
        relay, store = _relay(
            watcher,
            _Poster(),
            links=[_link(closed=True, closed_since=NOW - KEEP_CLOSED_SECONDS)],
            clock=lambda: NOW,
        )

        result = await relay.run_once()

        self.assertEqual(result.forgotten, 1)
        self.assertEqual(store.load(), {})
        self.assertEqual(relay.tracked, 0)
        self.assertEqual(watcher.seen, [], "the clock already knows; the round must spend no call")

    async def test_a_closed_link_with_no_moment_is_given_the_whole_window(self) -> None:
        """A file written before this window existed, or edited by hand: never dropped on sight."""
        relay, store = _relay(
            _Watcher(IssueState(closed=True)),
            _Poster(),
            links=[_link(closed=True, closed_since=0.0)],
            clock=lambda: NOW,
        )

        result = await relay.run_once()

        self.assertEqual(result.forgotten, 0)
        self.assertEqual(store.load()[901].closed_since, NOW)

    async def test_a_closed_link_ahead_of_the_clock_is_given_the_whole_window(self) -> None:
        """An NTP correction moves the clock back; it must not forget every closed report."""
        relay, store = _relay(
            _Watcher(IssueState(closed=True)),
            _Poster(),
            links=[_link(closed=True, closed_since=NOW + 86400.0)],
            clock=lambda: NOW,
        )

        result = await relay.run_once()

        self.assertEqual(result.forgotten, 0)
        self.assertEqual(store.load()[901].closed_since, NOW)

    async def test_a_refused_unmark_is_retried_until_it_takes(self) -> None:
        """Discord allows two renames per ten minutes; the closure already spent one."""
        poster = _Poster(refuse_marks=1)
        relay, store = _relay(
            _Watcher(IssueState(closed=False)),
            poster,
            links=[_link(closed=True, closed_since=NOW - 3600.0, closed_marked=True)],
            clock=lambda: NOW,
        )

        first = await relay.run_once()
        self.assertTrue(store.load()[901].closed_marked, "a refused rename must not be forgotten")

        second = await relay.run_once()

        self.assertEqual(poster.unmarked, [20, 20])
        self.assertFalse(store.load()[901].closed_marked)
        self.assertEqual((first.reopened, second.reopened), (1, 0), "and it is announced only once")

    async def test_a_refused_unmark_never_holds_back_the_messages(self) -> None:
        poster = _Poster(refuse_marks=5)
        relay, _ = _relay(
            _Watcher(IssueState(comments=(_comment(1),), closed=False)),
            poster,
            links=[_link(closed=True, closed_since=NOW - 3600.0, closed_marked=True)],
            clock=lambda: NOW,
        )

        result = await relay.run_once()

        self.assertEqual((result.reopened, result.relayed), (1, 1))
        self.assertEqual(len(poster.posted), 2, "a cosmetic refusal must not cost the reporter a word")

    async def test_a_closure_whose_mark_was_refused_arms_no_unmark(self) -> None:
        poster = _Poster(refuse_marks=1)
        relay, store = _relay(
            _Watcher(IssueState(closed=True), IssueState(closed=False)),
            poster,
            links=[_link()],
            clock=lambda: NOW,
        )

        await relay.run_once()
        self.assertFalse(store.load()[901].closed_marked, "nothing was marked, so nothing to undo")

        await relay.run_once()

        self.assertEqual(poster.unmarked, [], "no thread carries a mark to take off")

    async def test_a_link_persisted_as_closed_is_assumed_to_be_marked(self) -> None:
        """A file written before the field existed, or repaired by hand: the `✅` must come off."""
        poster = _Poster()
        folder = tempfile.mkdtemp()
        path = Path(folder) / "relay-links.json"
        path.write_text(
            json.dumps(
                {"version": LINKS_VERSION, "links": [{"issue": 901, "channel_id": 10, "thread_id": 20, "closed": True}]}
            ),
            encoding="utf-8",
        )
        store = LinkStore(path)
        relay = Relay(
            _Watcher(IssueState(closed=False)),  # type: ignore[arg-type]
            poster,
            store,
            repository="VEAF/VEAF-Mission-Creation-Tools",
            clock=lambda: NOW,
        )

        await relay.run_once()

        self.assertEqual(poster.unmarked, [20])

    async def test_a_thread_gone_during_the_reopening_drops_the_link(self) -> None:
        """And stops there: the comments behind it have nowhere to go either."""
        poster = _Poster(gone=True)
        relay, store = _relay(
            _Watcher(IssueState(comments=(_comment(1),), closed=False)),
            poster,
            links=[_link(closed=True, closed_since=NOW - 3600.0)],
            clock=lambda: NOW,
        )

        result = await relay.run_once()

        self.assertEqual((result.dropped, result.reopened, result.relayed), (1, 0, 0))
        self.assertEqual(store.load(), {})
        self.assertEqual(poster.unmarked, [], "a gone thread must not be renamed")

    async def test_the_closure_records_when_it_happened(self) -> None:
        relay, store = _relay(
            _Watcher(IssueState(closed=True)),
            _Poster(),
            links=[_link()],
            clock=lambda: NOW,
        )

        await relay.run_once()

        self.assertEqual(store.load()[901].closed_since, NOW)


class TestADeletedIssueStopsBeingPolled(unittest.IsolatedAsyncioTestCase):
    """Live on 2026-09-09: three deleted issues warned every ten minutes for a day.

    Every `GitHubError` was transient, which is right for an outage and wrong for a deletion. Their
    warnings were also the *only* content in the log, so a relay that had stopped relaying anything
    read as one that was working.
    """

    async def test_a_deleted_issue_drops_its_link(self) -> None:
        relay, store = _relay(
            _Watcher(IssueGone("GitHub answered 410: This issue was deleted")),
            _Poster(),
            links=[_link()],
        )

        result = await relay.run_once()

        self.assertEqual(result.dropped, 1)
        self.assertEqual(store.load(), {})

    async def test_the_other_reports_stay_followed(self) -> None:
        watcher = _Watcher(IssueGone("gone"), IssueState(comments=(_comment(1),)))
        poster = _Poster()
        relay, store = _relay(watcher, poster, links=[_link(901), _link(902, thread_id=21)])

        await relay.run_once()

        self.assertEqual(list(store.load()), [902])
        self.assertEqual([thread for thread, _ in poster.posted], [21])

    async def test_a_transient_failure_still_holds_the_link(self) -> None:
        relay, store = _relay(_Watcher(None), _Poster(), links=[_link(last_comment_id=7)])

        result = await relay.run_once()

        self.assertEqual((result.failed, result.dropped), (1, 0))
        self.assertEqual(store.load()[901].last_comment_id, 7, "the cursor must not move")


class TestTheRoundDoesNotGrowForEver(unittest.IsolatedAsyncioTestCase):
    """Found in review, noted 75: nothing was ever dropped, so the round grew until the API refused."""

    async def test_the_closure_is_still_announced_before_it_stops(self) -> None:
        poster = _Poster()
        relay, _ = _relay(_Watcher(IssueState(closed=True)), poster, links=[_link()])

        await relay.run_once()

        self.assertIn("closed", poster.posted[0][1])
        self.assertEqual(poster.marked, [20])

    async def test_each_link_is_saved_as_it_goes(self) -> None:
        """A shutdown cancels the loop, and a save deferred to the end never happens."""
        saves: list[int] = []
        relay, store = _relay(
            _Watcher(IssueState(comments=(_comment(1),))),
            _Poster(),
            links=[_link(901), _link(902, thread_id=21)],
        )
        original = store.save

        def _counting(links: Any) -> None:
            saves.append(len(links))
            original(links)

        store.save = _counting  # type: ignore[method-assign]

        await relay.run_once()

        self.assertGreaterEqual(len(saves), 2, "the state must be persisted per link, not once at the end")


class TestALongDiscussionStaysVisible(unittest.IsolatedAsyncioTestCase):
    """Found in review, noted 50: past the hundredth comment the issue went silent for good."""

    async def test_more_than_one_page_is_read(self) -> None:
        page_one = [_api_comment(index) for index in range(1, COMMENT_PAGE_SIZE + 1)]
        page_two = [_api_comment(COMMENT_PAGE_SIZE + 1)]
        transport = _PagedTransport([page_one, page_two])
        watcher = IssueWatcher(GitHubApp(credentials(), "o/n", transport))

        state = await watcher.since(901, COMMENT_PAGE_SIZE)

        assert state is not None
        self.assertEqual([comment.identifier for comment in state.comments], [COMMENT_PAGE_SIZE + 1])

    async def test_a_short_first_page_costs_one_call(self) -> None:
        transport = _PagedTransport([[_api_comment(1)]])
        watcher = IssueWatcher(GitHubApp(credentials(), "o/n", transport))

        await watcher.since(901, 0)

        self.assertEqual(len([url for url in transport.urls if "/comments" in url]), 1)

    async def test_the_pages_read_in_one_round_are_bounded(self) -> None:
        full = [[_api_comment(index) for index in range(1, COMMENT_PAGE_SIZE + 1)]] * (MAX_COMMENT_PAGES + 4)
        transport = _PagedTransport(full)
        watcher = IssueWatcher(GitHubApp(credentials(), "o/n", transport))

        await watcher.since(901, 0)

        self.assertEqual(len([url for url in transport.urls if "/comments" in url]), MAX_COMMENT_PAGES)


class _PagedTransport:
    """A transport serving one list of comments per page."""

    def __init__(self, pages: list[list[dict[str, Any]]]) -> None:
        """Initialize the transport.

        Args:
            pages: What each page returns, in order.
        """
        self.pages = pages
        self.urls: list[str] = []

    async def __call__(self, method: str, url: str, headers: Any, body: Any) -> Response:
        """Answer one call.

        Args:
            method: The HTTP method.
            url: The URL.
            headers: The request headers.
            body: The request body.

        Returns:
            The canned response.
        """
        if url.endswith("/access_tokens"):
            return Response(201, {"token": "ghs-t", "expires_at": "2999-01-01T00:00:00Z"})
        self.urls.append(url)
        if "/comments" not in url:
            return Response(200, {"number": 901, "state": "open"})
        page = int(url.rsplit("page=", 1)[1])
        return Response(200, self.pages[page - 1] if page <= len(self.pages) else [])


if __name__ == "__main__":
    unittest.main()
