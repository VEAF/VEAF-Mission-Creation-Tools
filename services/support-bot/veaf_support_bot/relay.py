"""Ticket 06: what happens on the issue comes back to where the reporter is.

Filing under a machine account means the reporter is subscribed to nothing. A maintainer asking
*"can you attach your `dcs.log`?"* on the issue is talking to an empty room, and the reporter never
learns his bug was even looked at. This is where integrations of this kind normally die: the report
travels fine, and then nobody speaks to anybody.

## One direction only

GitHub → Discord. The other way round would open a write channel from a room anyone can join onto a
public repository, and that needs its own decision and its own guards. The consequence is stated in
the documentation rather than hidden: to add something to his report, the reporter posts in the
thread and a maintainer carries it over. That is a manual step, and it is the accepted cost.

## Polling, not a webhook

The App is installed with **no webhook and no events** — ticket 05's decision, and the reason it
needs no inbound port. So the service asks, every few minutes, what changed on the issues it filed.
A webhook would be faster and would cost a public HTTP endpoint, a shared secret, and a signature
check on a route anybody can reach; nobody is waiting in front of a bug report, so the trade is not
close.

## What is relayed, and what is not

Relaying everything turns a thread into noise. A **comment a human wrote** and the issue **closing**
are what the reporter can act on or wants to know. Its own comments are never relayed — that is the
loop this module has to not have — and neither is a label, a milestone or an edit.

## Failing quietly is the point

A deleted thread, an archived thread, a reporter who left the server, a GitHub outage: none of them
may stop the relay for everybody else. Each is skipped, counted and logged; the link is dropped only
when Discord says the thread is gone for good.
"""

from __future__ import annotations

import json
from collections.abc import Sequence
from dataclasses import dataclass, field
from logging import Logger
from pathlib import Path
from typing import Any, Protocol

from veaf_support_bot.github_app import GitHubApp, GitHubError
from veaf_support_bot.logging_setup import get_logger
from veaf_support_bot.texts import normalize_language, text
from veaf_support_bot.untrusted import one_line, quote

#: Version of the persisted document. A file of another version is refused rather than reinterpreted.
LINKS_VERSION = 1

#: How often the tracked issues are polled, in seconds. Nobody is waiting in front of a bug report,
#: and each round is one API call per tracked issue: ten minutes keeps a busy day well inside the
#: 5000 requests an hour a GitHub App installation gets.
DEFAULT_POLL_SECONDS = 600.0

#: Comments carried into the thread in one round, per issue. A maintainer pasting a long exchange
#: must not turn a thread into a wall; the rest stays one click away on the issue.
MAX_RELAYED_PER_ROUND = 5

#: Longest relayed comment. Past it the thread shows the beginning and says where the rest is —
#: never a silent cut.
MAX_COMMENT_CHARS = 1200

#: Longest author name shown, so a display name cannot push the message over Discord's ceiling.
MAX_AUTHOR_CHARS = 80


@dataclass
class Link:
    """One filed issue, and the Discord thread it must answer in.

    Attributes:
        issue: The issue number.
        channel_id: Channel the thread lives in, so a restart can find it without a cache.
        thread_id: Thread the relay posts into.
        lang: Language the reporter was answered in.
        last_comment_id: Highest comment id already relayed. ``0`` means none yet — deliberately
            **not** a timestamp: two comments in the same second would race, and ids only grow.
        closed: Whether the closure has already been announced, so it is announced once.
        failures: Consecutive rounds this link could not be delivered to.
    """

    issue: int
    channel_id: int
    thread_id: int
    lang: str = "fr"
    last_comment_id: int = 0
    closed: bool = False
    failures: int = 0


@dataclass
class Comment:
    """One comment on an issue, as the relay needs it.

    Attributes:
        identifier: The comment id, which is what the cursor advances on.
        author: Who wrote it.
        body: What it says.
        by_bot: Whether it came from an App or a bot — never relayed, or the service would answer
            itself in a loop.
    """

    identifier: int
    author: str
    body: str
    by_bot: bool = False


@dataclass
class IssueState:
    """What one round found on one issue.

    Attributes:
        comments: Comments newer than the cursor, oldest first.
        closed: Whether the issue is closed now.
    """

    comments: tuple[Comment, ...] = ()
    closed: bool = False


class ThreadPoster(Protocol):
    """Posting into a Discord thread, without this module importing ``discord``."""

    async def post_to_thread(self, channel_id: int, thread_id: int, content: str) -> bool:
        """Post one message into a thread.

        Args:
            channel_id: The channel the thread belongs to.
            thread_id: The thread.
            content: What to post.

        Returns:
            ``True`` when it was posted. ``False`` when the thread is gone for good — deleted, or
            in a channel the bot can no longer see — which is the one case where the link is
            dropped rather than retried.
        """

    async def mark_closed(self, channel_id: int, thread_id: int) -> bool:
        """Mark the thread as settled, once the issue is closed.

        Args:
            channel_id: The channel the thread belongs to.
            thread_id: The thread.

        Returns:
            Whether the mark was applied. A refusal is cosmetic and never fails a round: the closure
            is also said in words.
        """


class LinkStore:
    """Where the thread ↔ issue links live, so a restart does not orphan every report.

    A whole-file rewrite of a small JSON document, like the quota counters and the filing ledger:
    the failure mode of a truncated append is an entry that reads as absent, and an absent entry
    here is a reporter who never hears back.
    """

    def __init__(self, path: Path, logger: Logger | None = None) -> None:
        """Initialize the store.

        Args:
            path: File the links are kept in.
            logger: Logger for a store that cannot be read or written.
        """
        self.path = path
        self._logger = logger or get_logger("relay")

    def load(self) -> dict[int, Link]:
        """Read every link back.

        Returns:
            The links by issue number. An unreadable or unrecognised file yields an empty mapping
            and a warning rather than an exception: the relay is a convenience on top of reports
            that are already filed, and it must never be the reason the service will not start.
        """
        if not self.path.exists():
            return {}
        try:
            document = json.loads(self.path.read_text(encoding="utf-8"))
        except (OSError, ValueError) as error:
            self._logger.warning(
                "the relay links could not be read",
                extra={"event": "relay.unreadable", "path": str(self.path), "error": str(error)},
            )
            return {}
        if not isinstance(document, dict) or document.get("version") != LINKS_VERSION:
            self._logger.warning(
                "the relay links are of an unknown version and were ignored",
                extra={"event": "relay.version", "path": str(self.path)},
            )
            return {}
        entries = document.get("links")
        if not isinstance(entries, list):
            return {}
        links: dict[int, Link] = {}
        for entry in entries:
            link = _link_of(entry)
            if link is not None:
                links[link.issue] = link
        return links

    def save(self, links: dict[int, Link]) -> None:
        """Write every link out.

        Args:
            links: The links to persist.
        """
        document = {
            "version": LINKS_VERSION,
            "links": [
                {
                    "issue": link.issue,
                    "channel_id": link.channel_id,
                    "thread_id": link.thread_id,
                    "lang": link.lang,
                    "last_comment_id": link.last_comment_id,
                    "closed": link.closed,
                    "failures": link.failures,
                }
                for link in links.values()
            ],
        }
        try:
            self.path.parent.mkdir(parents=True, exist_ok=True)
            self.path.write_text(json.dumps(document, indent=2), encoding="utf-8")
        except OSError as error:
            self._logger.warning(
                "the relay links could not be written",
                extra={"event": "relay.unwritable", "path": str(self.path), "error": str(error)},
            )


def _link_of(entry: Any) -> Link | None:
    """Turn one persisted entry into a link.

    Args:
        entry: The decoded entry.

    Returns:
        The link, or ``None`` when the entry is not one. A single bad entry is skipped rather than
        failing the whole file: the other reporters did nothing wrong.
    """
    if not isinstance(entry, dict):
        return None
    try:
        return Link(
            issue=int(entry["issue"]),
            channel_id=int(entry["channel_id"]),
            thread_id=int(entry["thread_id"]),
            lang=normalize_language(str(entry.get("lang", "fr"))),
            last_comment_id=int(entry.get("last_comment_id", 0)),
            closed=bool(entry.get("closed", False)),
            failures=int(entry.get("failures", 0)),
        )
    except (KeyError, TypeError, ValueError):
        return None


class IssueWatcher:
    """Asks GitHub what changed on one issue since the last round."""

    def __init__(self, app: GitHubApp, logger: Logger | None = None) -> None:
        """Initialize the watcher.

        Args:
            app: The authenticated client.
            logger: Logger to use.
        """
        self._app = app
        self._logger = logger or get_logger("relay")

    async def since(self, issue: int, last_comment_id: int) -> IssueState | None:
        """Read the comments newer than the cursor, and whether the issue is closed.

        Args:
            issue: The issue number.
            last_comment_id: Highest comment id already relayed.

        Returns:
            What changed, or ``None`` when GitHub could not be asked — which is a *transient*
            answer: nothing is relayed and nothing is marked as seen, so the next round tries again
            rather than losing the comment.
        """
        try:
            issue_response = await self._app.request("GET", f"/repos/{self._app.repository}/issues/{issue}")
            comments_response = await self._app.request(
                "GET", f"/repos/{self._app.repository}/issues/{issue}/comments?per_page=100"
            )
        except GitHubError as error:
            self._logger.warning(
                "an issue could not be polled",
                extra={"event": "relay.poll_failed", "issue": issue, "error": str(error)},
            )
            return None
        body: dict[str, Any] = issue_response.body if isinstance(issue_response.body, dict) else {}
        items: list[Any] = comments_response.body if isinstance(comments_response.body, list) else []
        comments = [_comment_of(item) for item in items if isinstance(item, dict)]
        # Not filtered here. Whose comment gets relayed is the relay's rule, and it belongs at the
        # step that posts — a filter on the way *in* leaves every other producer of an `IssueState`
        # free to feed the loop this module exists to not have.
        fresh = tuple(
            comment
            for comment in sorted(comments, key=lambda item: item.identifier)
            if comment.identifier > last_comment_id
        )
        return IssueState(comments=fresh, closed=str(body.get("state") or "open") == "closed")


def _comment_of(item: dict[str, Any]) -> Comment:
    """Turn one API comment object into a comment.

    Args:
        item: The decoded comment.

    Returns:
        The comment. ``by_bot`` covers both an App's own comments and any other bot's: the service
        files under an App, so its own writing comes back through this endpoint and must not be
        relayed into the thread it came from.
    """
    raw = item.get("user")
    user: dict[str, Any] = raw if isinstance(raw, dict) else {}
    author = str(user.get("login") or "?")
    kind = str(user.get("type") or "")
    return Comment(
        identifier=int(item.get("id") or 0),
        author=author,
        body=str(item.get("body") or ""),
        by_bot=kind.lower() == "bot" or author.endswith("[bot]"),
    )


def render_comment(comment: Comment, issue: int, url: str, lang: str) -> str:
    """Render one maintainer comment as something a non-developer reads.

    Args:
        comment: The comment.
        issue: The issue number it is on.
        url: Where to read the whole thread of it.
        lang: ``"fr"`` or ``"en"``.

    Returns:
        The message. The comment is quoted rather than reflowed — it is somebody else's words, and
        it can contain a mention, a code block or a stray ``@everyone``.
    """
    body = comment.body if len(comment.body) <= MAX_COMMENT_CHARS else comment.body[:MAX_COMMENT_CHARS]
    message = text(
        "relay.comment",
        lang,
        author=one_line(comment.author, MAX_AUTHOR_CHARS),
        issue=issue,
        url=url,
    )
    parts = [message, quote(body)]
    if len(comment.body) > MAX_COMMENT_CHARS:
        parts.append(text("relay.truncated", lang, url=url))
    return "\n".join(part for part in parts if part)


def render_closed(issue: int, url: str, lang: str) -> str:
    """Render the closure of an issue.

    Args:
        issue: The issue number.
        url: Where to read it.
        lang: ``"fr"`` or ``"en"``.

    Returns:
        The message.
    """
    return text("relay.closed", lang, issue=issue, url=url)


@dataclass
class Round:
    """What one polling round did, for the log and for the tests.

    Attributes:
        polled: Links looked at.
        relayed: Messages posted into threads.
        closed: Closures announced.
        dropped: Links given up on because the thread is gone.
        failed: Links that could not be reached this round and stay for the next.
    """

    polled: int = 0
    relayed: int = 0
    closed: int = 0
    dropped: int = 0
    failed: int = 0
    notes: list[str] = field(default_factory=list)


class Relay:
    """Carries what happens on an issue back into the thread the report came from."""

    def __init__(
        self,
        watcher: IssueWatcher,
        poster: ThreadPoster,
        store: LinkStore,
        *,
        repository: str,
        logger: Logger | None = None,
    ) -> None:
        """Initialize the relay.

        Args:
            watcher: What asks GitHub.
            poster: What writes into Discord.
            store: Where the links are kept.
            repository: ``owner/name``, for the issue links written into the messages.
            logger: Logger to use.
        """
        self._watcher = watcher
        self._poster = poster
        self._store = store
        self._repository = repository
        self._logger = logger or get_logger("relay")
        self._links: dict[int, Link] = store.load()

    def attach(self, poster: ThreadPoster) -> None:
        """Give the relay its Discord side, once the connection exists.

        Args:
            poster: What writes into threads.
        """
        self._poster = poster

    @property
    def tracked(self) -> int:
        """Return how many reports are being followed.

        Returns:
            The number of links.
        """
        return len(self._links)

    def remember(self, issue: int, *, channel_id: int, thread_id: int, lang: str) -> None:
        """Record that one issue must answer in one thread.

        Args:
            issue: The issue that was filed.
            channel_id: Channel the thread lives in.
            thread_id: The thread.
            lang: Language the reporter was answered in.
        """
        if issue <= 0 or thread_id <= 0:
            return
        self._links[issue] = Link(issue=issue, channel_id=channel_id, thread_id=thread_id, lang=lang)
        self._store.save(self._links)
        self._logger.info(
            "a report is now followed",
            extra={"event": "relay.tracked", "issue": issue, "discord_thread": thread_id, "tracked": len(self._links)},
        )

    def _url(self, issue: int) -> str:
        """Return the web address of one issue.

        Args:
            issue: The issue number.

        Returns:
            The URL.
        """
        return f"https://github.com/{self._repository}/issues/{issue}"

    async def run_once(self) -> Round:
        """Poll every tracked issue and deliver what is new.

        Returns:
            What the round did. Never raises: a relay that dies takes every *other* reporter's
            follow-up with it, and this runs unattended in a background task.
        """
        result = Round()
        for issue in list(self._links):
            link = self._links.get(issue)
            if link is None:
                continue
            result.polled += 1
            await self._deliver(link, result)
        self._store.save(self._links)
        if result.relayed or result.closed or result.dropped:
            self._logger.info(
                "relay round done",
                extra={
                    "event": "relay.round",
                    "polled": result.polled,
                    "relayed": result.relayed,
                    "closed": result.closed,
                    "dropped": result.dropped,
                    "failed": result.failed,
                },
            )
        return result

    async def _deliver(self, link: Link, result: Round) -> None:
        """Deliver one issue's news into its thread.

        Args:
            link: The link to deliver.
            result: The round's tally, updated in place.
        """
        state = await self._watcher.since(link.issue, link.last_comment_id)
        if state is None:
            # Transient: the cursor is not moved, so nothing is lost — the next round sees the same
            # comments again.
            result.failed += 1
            return

        url = self._url(link.issue)
        carried = relayable(state.comments)[:MAX_RELAYED_PER_ROUND]
        for comment in state.comments:
            if comment not in carried:
                # A bot's comment — most often this service's own hypothesis. Not posted, but the
                # cursor moves past it, or every round would read it again for nothing.
                link.last_comment_id = max(link.last_comment_id, comment.identifier)
                continue
            if not await self._post(link, render_comment(comment, link.issue, url, link.lang), result):
                return
            link.last_comment_id = comment.identifier
            result.relayed += 1

        if relayable(state.comments)[MAX_RELAYED_PER_ROUND:]:
            # Said, not silently skipped: the reporter is told there is more on the issue, and the
            # cursor stays where it is so the rest arrives next round.
            await self._post(link, text("relay.more", link.lang, url=url), result)

        if state.closed and not link.closed:
            if not await self._post(link, render_closed(link.issue, url, link.lang), result):
                return
            await self._poster.mark_closed(link.channel_id, link.thread_id)
            link.closed = True
            result.closed += 1

    async def _post(self, link: Link, content: str, result: Round) -> bool:
        """Post one message, and drop the link when the thread is gone for good.

        Args:
            link: The link being delivered.
            content: What to post.
            result: The round's tally, updated in place.

        Returns:
            ``True`` when the message was posted.
        """
        try:
            posted = await self._poster.post_to_thread(link.channel_id, link.thread_id, content)
        except Exception as error:  # noqa: BLE001 - one bad thread must not end the round
            self._logger.warning(
                "a thread could not be written to",
                extra={"event": "relay.post_failed", "issue": link.issue, "error": type(error).__name__},
            )
            link.failures += 1
            result.failed += 1
            return False
        if posted:
            link.failures = 0
            return True
        # A definitive refusal: the thread is deleted, or its channel is no longer visible. Keeping
        # the link would poll an issue forever for a room that no longer exists.
        self._links.pop(link.issue, None)
        result.dropped += 1
        result.notes.append(f"#{link.issue}: the thread is gone")
        self._logger.info(
            "a report is no longer followed: its thread is gone",
            extra={"event": "relay.dropped", "issue": link.issue, "discord_thread": link.thread_id},
        )
        return False


def relayable(comments: Sequence[Comment]) -> tuple[Comment, ...]:
    """Return the comments a reporter should hear about.

    Kept as a function so the rule is one testable place rather than a condition inside a loop: the
    service's own comments come back through the same endpoint it wrote them to, and relaying one
    would post the bot's hypothesis into the thread that produced it.

    Args:
        comments: The comments read off the issue.

    Returns:
        The ones written by a person.
    """
    return tuple(comment for comment in comments if not comment.by_bot)
