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
when Discord says the thread is gone for good, or when GitHub says the **issue** is.

## A closure is not the end of the conversation

Announcing a closure used to drop the link, to bound how many issues a round polls. Measured on
#946, closed one evening and reopened the next morning: the reopening reached a relay that no longer
knew the issue existed, and ten comments were written into a thread that had been archived and
marked as settled. So a closed link is now **kept** for `KEEP_CLOSED_SECONDS`, which is what carries
a reopening back to the reporter, and the ceiling it was protecting is bounded by that window
instead.
"""

from __future__ import annotations

import json
import time
from collections.abc import Callable, Sequence
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
#: and each round costs **two** API calls per tracked issue — the issue's state and its comments.
#: At ten minutes that is 12 calls an hour per followed report, against the 5000 an hour a GitHub
#: App installation gets; a link is dropped as soon as its issue closes, which is what keeps that
#: number from growing without end.
DEFAULT_POLL_SECONDS = 600.0

#: Comments carried into the thread in one round, per issue. A maintainer pasting a long exchange
#: must not turn a thread into a wall; the rest stays one click away on the issue.
MAX_RELAYED_PER_ROUND = 5

#: Longest relayed comment. Past it the thread shows the beginning and says where the rest is —
#: never a silent cut.
MAX_COMMENT_CHARS = 1200

#: Longest author name shown, so a display name cannot push the message over Discord's ceiling.
MAX_AUTHOR_CHARS = 80

#: Comments asked for per page, and how many pages one round will read. The product bounds the
#: work an issue with a very long discussion can ask of a single round.
COMMENT_PAGE_SIZE = 100
MAX_COMMENT_PAGES = 5

#: How long a link whose issue is closed is kept before it is forgotten. It is what carries a
#: **reopening** back to the thread, and a week is long enough that a reopening later than that is a
#: new conversation anyway. The cost is small: at two calls per link per round, six rounds an hour,
#: ten closed links spend 120 of the 5000 calls an hour a GitHub App installation gets.
KEEP_CLOSED_SECONDS = 7 * 24 * 3600.0

#: The statuses that mean the issue itself is gone and asking again can only fail. `410` is the only
#: member on purpose: GitHub answers it with *"This issue was deleted"* and nothing else. A `404` is
#: that same deletion **and** an installation whose access was revoked for a minute, so dropping
#: every link on the first `404` would unsubscribe every reporter at once over a transient fault.
GONE_STATUSES = (410,)


class IssueGone(Exception):
    """The issue itself no longer exists, so following it can only fail from now on.

    Distinct from the ``None`` a watcher returns for a transient failure: that one holds the cursor
    and tries again next round, which is right for an outage and wrong for a deletion — three
    deleted issues were polled every ten minutes for a day, and their warnings were the only thing
    in the log of a relay that had stopped relaying.
    """


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
        closed: Whether the closure has already been announced, so it is announced once. Cleared
            again when the issue is reopened, which is what makes the reopening announced once too.
        closed_since: When the closure was announced, as a Unix timestamp; ``0.0`` while the issue
            is open. What the retention window is measured from.
        closed_marked: Whether the **thread** currently carries the settled mark. Tracked apart
            from :attr:`closed` because the two can disagree: Discord allows a thread two renames
            every ten minutes, so a rename can be refused. Held until the rename succeeds, or a
            reopened report would keep a thread named as closed for ever.
        failures: Consecutive rounds this link could not be delivered to.
    """

    issue: int
    channel_id: int
    thread_id: int
    lang: str = "fr"
    last_comment_id: int = 0
    closed: bool = False
    closed_since: float = 0.0
    closed_marked: bool = False
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

    async def mark_reopened(self, channel_id: int, thread_id: int) -> bool:
        """Take the settled mark back off, once the issue is open again.

        Args:
            channel_id: The channel the thread belongs to.
            thread_id: The thread.

        Returns:
            Whether the mark was removed. Cosmetic like its counterpart — the reopening is said in
            words too — so a refusal never fails a round.
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
                    "closed_since": link.closed_since,
                    "closed_marked": link.closed_marked,
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
            closed_since=float(entry.get("closed_since", 0.0)),
            # Defaults to `closed` rather than to False: a link persisted as closed was normally
            # marked when it closed, and a file written before this field existed — or one an
            # operator repaired by hand — must not leave a `✅` nobody will take off.
            closed_marked=bool(entry.get("closed_marked", entry.get("closed", False))),
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

    async def _recent_comments(self, issue: int) -> list[Any]:
        """Read the newest page of an issue's comments, and the pages before it while they matter.

        Args:
            issue: The issue number.

        Returns:
            The decoded comment objects of the pages read.

        Raises:
            GitHubError: A page could not be read. The caller turns that into a transient answer.
        """
        path = f"/repos/{self._app.repository}/issues/{issue}/comments?per_page={COMMENT_PAGE_SIZE}"
        first = await self._app.request("GET", f"{path}&page=1")
        items: list[Any] = first.body if isinstance(first.body, list) else []
        if len(items) < COMMENT_PAGE_SIZE:
            return items
        # A full first page means there are more. Walk forward, bounded: an issue with thousands of
        # comments must not turn one round into a hundred calls, and the ceiling is announced by the
        # `relay.more` message rather than reached in silence.
        for page in range(2, MAX_COMMENT_PAGES + 1):
            response = await self._app.request("GET", f"{path}&page={page}")
            batch = response.body if isinstance(response.body, list) else []
            items.extend(batch)
            if len(batch) < COMMENT_PAGE_SIZE:
                break
        return items

    async def since(self, issue: int, last_comment_id: int) -> IssueState | None:
        """Read the comments newer than the cursor, and whether the issue is closed.

        Args:
            issue: The issue number.
            last_comment_id: Highest comment id already relayed.

        Returns:
            What changed, or ``None`` when GitHub could not be asked — which is a *transient*
            answer: nothing is relayed and nothing is marked as seen, so the next round tries again
            rather than losing the comment.

        Raises:
            IssueGone: The issue was deleted. Definitive, so the caller stops following it rather
                than asking again every ten minutes for ever.
        """
        try:
            issue_response = await self._app.request("GET", f"/repos/{self._app.repository}/issues/{issue}")
            # Last page first. GitHub returns an issue's comments oldest-first, so a fixed
            # ``page=1`` would freeze on the hundred *oldest* ones: past the hundredth comment the
            # relay would find nothing new for ever, with no error and no log line. Reading the last
            # page — and walking back while it is still ahead of the cursor — keeps the newest ones
            # in view whatever the issue's length.
            items = await self._recent_comments(issue)
        except GitHubError as error:
            # Either call can be the one that answers `410`: an issue can be deleted between the
            # read of its state and the read of its comments.
            if error.status in GONE_STATUSES:
                raise IssueGone(str(error)) from error
            self._logger.warning(
                "an issue could not be polled",
                extra={"event": "relay.poll_failed", "issue": issue, "error": str(error)},
            )
            return None
        body: dict[str, Any] = issue_response.body if isinstance(issue_response.body, dict) else {}
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


def render_reopened(issue: int, url: str, lang: str) -> str:
    """Render the reopening of an issue.

    Args:
        issue: The issue number.
        url: Where to read it.
        lang: ``"fr"`` or ``"en"``.

    Returns:
        The message.
    """
    return text("relay.reopened", lang, issue=issue, url=url)


@dataclass
class Round:
    """What one polling round did, for the log and for the tests.

    Attributes:
        polled: Links looked at.
        relayed: Messages posted into threads.
        closed: Closures announced.
        reopened: Reopenings announced.
        dropped: Links given up on because the thread, or the issue, is gone.
        forgotten: Links let go because their issue has been closed for the whole window.
        failed: Links that could not be reached this round and stay for the next.
    """

    polled: int = 0
    relayed: int = 0
    closed: int = 0
    reopened: int = 0
    dropped: int = 0
    forgotten: int = 0
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
        clock: Callable[[], float] | None = None,
    ) -> None:
        """Initialize the relay.

        Args:
            watcher: What asks GitHub.
            poster: What writes into Discord.
            store: Where the links are kept.
            repository: ``owner/name``, for the issue links written into the messages.
            logger: Logger to use.
            clock: Source of Unix timestamps; defaults to :func:`time.time`. Injected so the
                retention window can be tested without waiting a week for it.
        """
        self._watcher = watcher
        self._poster = poster
        self._store = store
        self._repository = repository
        self._logger = logger or get_logger("relay")
        self._clock: Callable[[], float] = clock or time.time
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
            if self._expired(link):
                # Checked before the round spends a call on it: a link whose window is over has
                # nothing left to say, and asking GitHub about it first would be two calls to learn
                # what the clock already knows.
                self._links.pop(issue, None)
                result.forgotten += 1
                self._logger.info(
                    "a report closed long enough ago is no longer followed",
                    extra={"event": "relay.forgotten", "issue": link.issue},
                )
            else:
                result.polled += 1
                await self._deliver(link, result)
            # Persisted per link, not once at the end. A shutdown cancels this loop, and
            # `CancelledError` is not an `Exception` in 3.11 — so a save deferred to the end is a
            # save that never happens, and every message already posted is posted again on restart.
            self._store.save(self._links)
        if result.relayed or result.closed or result.reopened or result.dropped or result.forgotten:
            self._logger.info(
                "relay round done",
                extra={
                    "event": "relay.round",
                    "polled": result.polled,
                    "relayed": result.relayed,
                    "closed": result.closed,
                    "reopened": result.reopened,
                    "dropped": result.dropped,
                    "forgotten": result.forgotten,
                    "failed": result.failed,
                },
            )
        return result

    def _expired(self, link: Link) -> bool:
        """Say whether a closed link has been closed long enough to let go of.

        Args:
            link: The link, whose ``closed_since`` is repaired in place when it says nothing usable.

        Returns:
            Whether the retention window is over.
        """
        if not link.closed:
            return False
        now = self._clock()
        if not 0.0 < link.closed_since <= now:
            # Absent — a file written before this window existed, or edited by hand — or ahead of
            # the clock, which an NTP correction can produce. Either way the window starts now:
            # letting a link go early is the failure this whole mechanism exists to prevent, so the
            # ambiguous case must never resolve to it.
            link.closed_since = now
            return False
        return now - link.closed_since >= KEEP_CLOSED_SECONDS

    async def _deliver(self, link: Link, result: Round) -> None:
        """Deliver one issue's news into its thread.

        Args:
            link: The link to deliver.
            result: The round's tally, updated in place.
        """
        try:
            state = await self._watcher.since(link.issue, link.last_comment_id)
        except IssueGone as error:
            # Definitive, unlike the `None` below: the issue was deleted, and every future round
            # would ask for it again and warn again. Dropped once, said once.
            self._links.pop(link.issue, None)
            result.dropped += 1
            result.notes.append(f"#{link.issue}: the issue is gone")
            self._logger.info(
                "a report is no longer followed: its issue is gone",
                extra={"event": "relay.issue_gone", "issue": link.issue, "error": str(error)},
            )
            return
        if state is None:
            # Transient: the cursor is not moved, so nothing is lost — the next round sees the same
            # comments again.
            result.failed += 1
            return

        url = self._url(link.issue)
        # The reopening comes first, before any comment. What follows it is everything said on the
        # issue while nobody was listening, and it reads backwards arriving under a thread still
        # named `✅` and still archived.
        if link.closed and not state.closed:
            if not await self._post(link, render_reopened(link.issue, url, link.lang), result):
                return
            link.closed = False
            link.closed_since = 0.0
            result.reopened += 1
        if not state.closed and link.closed_marked:
            # Deliberately **not** part of the branch above, and not gated on its success either.
            # Discord allows a thread two renames every ten minutes and the closure spent one, so
            # this rename can be refused — and neither outcome may stop the round: holding the
            # announcement behind it would cost the reporter his messages over a cosmetic call,
            # while clearing the flag anyway would leave a live thread named `✅` for ever, with no
            # later round in a position to retry. So the flag survives a refusal and only a
            # success clears it.
            link.closed_marked = not await self._poster.mark_reopened(link.channel_id, link.thread_id)

        posted = 0
        for comment in state.comments:
            if comment.by_bot:
                # A bot's comment — most often this service's own hypothesis. Not posted, and the
                # cursor moves past it, or every round would read it again for nothing.
                link.last_comment_id = max(link.last_comment_id, comment.identifier)
                continue
            if posted >= MAX_RELAYED_PER_ROUND:
                # The ceiling. The cursor stops **here**, before this comment, so the next round
                # starts on it: advancing past a comment that was not posted is how a reporter
                # loses the one answer that mattered, and it was promised to him below.
                await self._post(link, text("relay.more", link.lang, url=url), result)
                break
            if not await self._post(link, render_comment(comment, link.issue, url, link.lang), result):
                return
            link.last_comment_id = comment.identifier
            posted += 1
            result.relayed += 1

        if state.closed and not link.closed:
            if not await self._post(link, render_closed(link.issue, url, link.lang), result):
                return
            link.closed_marked = await self._poster.mark_closed(link.channel_id, link.thread_id)
            link.closed = True
            link.closed_since = self._clock()
            result.closed += 1
            # Kept, not dropped. A link that is never let go makes the round grow for ever — at two
            # calls per link every ten minutes, a few hundred reports would exhaust the
            # installation's hourly quota and silence the relay for everybody — but dropping it
            # *here* is worse, and was the bug: the `relay.closed` message invites the reporter to
            # say so if the problem persists, a maintainer answers that by **reopening** the issue,
            # and the link is the only thing that can carry the reopening back to him. So the
            # ceiling is held by `KEEP_CLOSED_SECONDS` instead, and `_expired` does the letting go.

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
