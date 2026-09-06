"""Ticket 06: the answer comes back, exactly once, and one dead thread does not stop the rest.

The relay runs unattended in a background task, which is what makes its failure modes expensive:
nothing tells anybody it stopped. So what is asserted here is mostly *not* the happy path —

* its own comments are never relayed, or the bot answers its own hypothesis for ever;
* a comment already carried over is not carried over twice, across a restart included;
* a transient GitHub failure moves no cursor, so nothing is lost;
* a deleted thread drops one link and leaves every other report followed;
* a closure is announced once.

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
    LINKS_VERSION,
    MAX_RELAYED_PER_ROUND,
    Comment,
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

    def __init__(self, *rounds: IssueState | None) -> None:
        """Initialize the watcher.

        Args:
            *rounds: What each successive round returns; the last one repeats.
        """
        self._rounds = list(rounds) or [IssueState()]
        self.seen: list[tuple[int, int]] = []

    async def since(self, issue: int, last_comment_id: int) -> IssueState | None:
        """Answer one round.

        Args:
            issue: The issue polled.
            last_comment_id: The cursor it was polled with.

        Returns:
            The scripted state.
        """
        self.seen.append((issue, last_comment_id))
        return self._rounds[min(len(self.seen) - 1, len(self._rounds) - 1)]


class _Poster:
    """A poster that records what reached which thread."""

    def __init__(self, *, gone: bool = False, raises: Exception | None = None) -> None:
        """Initialize the poster.

        Args:
            gone: Whether every thread answers "I no longer exist".
            raises: Raised instead of posting, for the transient case.
        """
        self.posted: list[tuple[int, str]] = []
        self.marked: list[int] = []
        self.gone = gone
        self.raises = raises

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
            ``True``.
        """
        self.marked.append(thread_id)
        return True


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


def _relay(watcher: _Watcher, poster: Any, *, links: list[Link] | None = None) -> tuple[Relay, LinkStore]:
    """Build a relay over a temporary store.

    Args:
        watcher: What answers for GitHub.
        poster: What answers for Discord.
        links: Links to start from.

    Returns:
        The relay and its store.
    """
    folder = tempfile.mkdtemp()
    store = LinkStore(Path(folder) / "relay-links.json")
    if links:
        store.save({link.issue: link for link in links})
    return Relay(watcher, poster, store, repository="VEAF/VEAF-Mission-Creation-Tools"), store  # type: ignore[arg-type]


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

    def __init__(self, comments: list[dict[str, Any]], state: str = "open", *, fail: bool = False) -> None:
        """Initialize the transport.

        Args:
            comments: What the comments endpoint returns.
            state: The issue state.
            fail: Whether every call is refused.
        """
        self.comments = comments
        self.state = state
        self.fail = fail
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
            return Response(503, {"message": "unavailable"})
        if url.endswith("/comments") or "/comments?" in url:
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
        self.assertEqual(placeholder.calls, 1)

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


if __name__ == "__main__":
    unittest.main()
