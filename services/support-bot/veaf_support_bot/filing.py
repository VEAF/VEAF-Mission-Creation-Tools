"""Filing the issue, exactly once, and saying so when it could not be filed.

## Once, across three different ways of asking twice

The ticket names three: a double click, a retry after a timeout, and a restart in mid-flight. They
are three different failures and they need three different answers, so the module has three:

| What happens twice | What stops it |
|---|---|
| Two clicks arriving together | an :class:`asyncio.Lock` per key — the second waits, then reads the first one's result |
| A retry after a timeout, same process | the **ledger**, a small JSON file that already holds the issue number |
| A restart after the ``POST`` was sent and the answer lost, **or any loss of the ledger** | the **marker**, an HTML comment carrying the key inside the issue; the recovery search runs on every report with no recorded number, so it does not need the ledger to be readable |

The key is derived from the report itself — the reporter, his five fields, and the names and sizes
of what he attached — so *the same report* always produces *the same key*, and a genuinely new
report by the same person a minute later does not.

The marker is the one that matters, because it is the only one that survives losing local state
entirely. It is why the ledger's write before the call is not a nicety: a crash between the ``POST``
and the ledger write leaves an issue nobody recorded, and only a search for the marker finds it.

## A failure is said, never swallowed

Every path returns an :class:`Outcome` carrying what happened. The intake turns it into a sentence
the reporter reads in his thread — including *"I could not file this, here is why, and here is your
report so it is not lost"*. An issue that failed to be created and a reporter who thinks it was
created is the worst outcome available, and it is the one an exception swallowed into a log produces.

## What this module is allowed to do on GitHub

Create an issue, comment on one, list them, and set labels — all of which the *Issues: read and
write* permission covers, on one repository, and nothing else. It never pushes, never reads code,
never touches a workflow. See ``services/support-bot/README.md`` for the permission list as it must
be granted.
"""

from __future__ import annotations

import asyncio
import hashlib
import json
import time
from collections.abc import AsyncIterator, Callable, Sequence
from contextlib import asynccontextmanager
from dataclasses import dataclass, field
from logging import Logger
from pathlib import Path
from typing import Any

from veaf_support_bot.attachments import Prepared
from veaf_support_bot.bugreport import BASE_LABEL, BugReport
from veaf_support_bot.github_app import GitHubApp, GitHubError
from veaf_support_bot.issue_body import (
    Carried,
    carry,
    marker_for,
    render_attachment_comments,
    render_body,
    render_duplicate_comment,
)
from veaf_support_bot.logging_setup import get_logger
from veaf_support_bot.priorart import IssueRecord

#: Label marking an issue as filed by the machine, so these are findable and countable later. Not a
#: replacement for ``bug``: the issue carries both, and the template's own label stays the one a
#: maintainer filters on.
MACHINE_LABEL = "filed-by-bot"

#: How many recently closed issues the sweep considers. Beyond that a "fix" is old enough that the
#: reporter's version almost certainly has it.
CLOSED_ISSUE_COUNT = 50

#: Page size asked of the API.
PAGE_SIZE = 100

#: How many pages are read at most, so a repository that grows does not turn one report into a
#: hundred calls.
MAX_PAGES = 5

#: Version of the ledger document. A file of another version is refused rather than reinterpreted.
LEDGER_VERSION = 1

#: Appended to the ledger's name when an unreadable one is moved aside rather than overwritten.
CORRUPT_SUFFIX = ".corrupt"


@dataclass(frozen=True)
class Outcome:
    """What became of one report.

    Attributes:
        action: ``"created"``, ``"commented"``, ``"reused"`` (an earlier attempt had already filed
            it) or ``"failed"``.
        number: The issue number, when there is one.
        url: The issue's address, when there is one.
        error: What went wrong, when :attr:`action` is ``"failed"``. Never a stack trace, never a
            credential.
        notes: Things that were degraded but not fatal — a label that could not be applied, an
            attachment comment that did not post.
    """

    action: str
    number: int = 0
    url: str = ""
    error: str = ""
    notes: tuple[str, ...] = ()

    @property
    def filed(self) -> bool:
        """Say whether an issue exists at the end of this.

        Returns:
            ``True`` for every action but ``"failed"``.
        """
        return self.action != "failed"


def report_key(report: BugReport) -> str:
    """Derive the stable identity of one report.

    Built from what the reporter supplied and nothing else — deliberately **not** from a timestamp
    or a random value, because the same report submitted twice must produce the same key and a
    restart must be able to recompute it from the report alone.

    Args:
        report: The assembled report.

    Returns:
        A 32-character hex digest.
    """
    form = report.form
    material = [
        form.reporter_id,
        form.summary,
        form.happened,
        form.expected,
        form.steps,
        form.doctor,
    ]
    for attachment in report.attachments:
        if isinstance(attachment, Prepared):
            material.append(f"{attachment.filename}:{attachment.size}")
    joined = "\x1f".join(material).encode("utf-8", errors="replace")
    return hashlib.sha256(joined).hexdigest()[:32]


class Ledger:
    """What this service already filed, kept across restarts.

    A whole-file rewrite of a small JSON document, for the same reason the quota counters are: the
    failure mode of a truncated append is an entry that reads as absent, and an absent entry here is
    a second issue.
    """

    def __init__(self, path: Path, logger: Logger | None = None) -> None:
        """Initialize the ledger.

        Args:
            path: File the entries are kept in.
            logger: Logger for a store that cannot be read or written.
        """
        self.path = path
        self._logger = logger or get_logger("filing")

    def load(self) -> dict[str, dict[str, Any]]:
        """Read every entry back.

        Returns:
            The entries by key. An unreadable or unrecognised file yields an empty mapping and a
            warning: refusing to file anything because a bookkeeping file is corrupt would lose
            reports, and :meth:`IssueFiler._file_once` searches for the marker on **every** report
            it has no number for, so the duplicate is still stopped.
        """
        return self._read()[0]

    def _read(self) -> tuple[dict[str, dict[str, Any]], bool]:
        """Read the file back, saying whether it could be understood.

        The second value is what :meth:`record` needs and :meth:`load` does not: a caller that only
        reads can treat *corrupt* and *absent* alike, and a caller about to **overwrite** cannot —
        an empty mapping from a corrupt read, written back, is every other entry deleted.

        Returns:
            The entries, and whether the file on disk was readable. An absent file is readable: it
            is the state a first run legitimately starts from.
        """
        if not self.path.exists():
            return {}, True
        try:
            document = json.loads(self.path.read_text(encoding="utf-8"))
            if not isinstance(document, dict) or document.get("version") != LEDGER_VERSION:
                raise ValueError("unsupported ledger version")
            entries = document.get("reports")
            if not isinstance(entries, dict):
                raise ValueError("the ledger has no reports mapping")
        except (OSError, ValueError) as error:
            self._logger.warning(
                "the filing ledger could not be read; falling back to the in-issue marker",
                extra={"event": "filing.ledger_unreadable", "error": f"{type(error).__name__}: {error}"},
            )
            return {}, False
        return {str(key): value for key, value in entries.items() if isinstance(value, dict)}, True

    def record(self, key: str, entry: dict[str, Any]) -> None:
        """Write one entry, keeping the others.

        Args:
            key: The report key.
            entry: What to record.
        """
        entries, readable = self._read()
        if not readable:
            self._preserve()
        entries[key] = entry
        document = {"version": LEDGER_VERSION, "reports": entries}
        try:
            self.path.parent.mkdir(parents=True, exist_ok=True)
            temporary = self.path.with_suffix(f"{self.path.suffix}.tmp")
            temporary.write_text(json.dumps(document, indent=1, sort_keys=True), encoding="utf-8")
            temporary.replace(self.path)
        except OSError as error:
            self._logger.warning(
                "the filing ledger could not be written; a retry will fall back to the in-issue marker",
                extra={"event": "filing.ledger_unwritable", "error": f"{type(error).__name__}: {error}"},
            )

    def _preserve(self) -> None:
        """Move an unreadable ledger aside instead of writing over it.

        A corrupt file still holds the issue numbers of every report filed before it broke, in a
        form a human can read even when :func:`json.loads` cannot. Overwriting it is the one action
        that makes the damage permanent, and it is what a plain rewrite does silently.
        """
        aside = self.path.with_suffix(f"{self.path.suffix}{CORRUPT_SUFFIX}")
        try:
            self.path.replace(aside)
        except OSError as error:
            self._logger.warning(
                "the unreadable filing ledger could not be moved aside; it is about to be overwritten",
                extra={"event": "filing.ledger_not_preserved", "error": f"{type(error).__name__}: {error}"},
            )
            return
        self._logger.warning(
            "the unreadable filing ledger was moved aside",
            extra={"event": "filing.ledger_preserved", "path": str(aside)},
        )


class RepositoryIssues:
    """The issue half of the prior-art corpus, read through the App.

    Implements :class:`~veaf_support_bot.priorart.IssueSource`. Pull requests are filtered out:
    GitHub returns them from the issues endpoint, and proposing a pull request as a duplicate of a
    bug report is a proposal a reporter cannot evaluate.
    """

    def __init__(self, app: GitHubApp, *, closed_count: int = CLOSED_ISSUE_COUNT) -> None:
        """Initialize the source.

        Args:
            app: The authenticated client.
            closed_count: How many recently closed issues to consider.
        """
        self._app = app
        self._closed_count = closed_count

    async def open_issues(self) -> Sequence[IssueRecord]:
        """Return every open issue.

        Returns:
            The open issues.
        """
        return await self._list("open", self._closed_count * MAX_PAGES)

    async def recently_closed_issues(self) -> Sequence[IssueRecord]:
        """Return the most recently closed issues.

        Returns:
            The closed issues, newest first.
        """
        return await self._list("closed", self._closed_count)

    async def _list(self, state: str, ceiling: int) -> list[IssueRecord]:
        """Page through the issues endpoint.

        Args:
            state: ``"open"`` or ``"closed"``.
            ceiling: Most records to return.

        Returns:
            The records.
        """
        records: list[IssueRecord] = []
        for page in range(1, MAX_PAGES + 1):
            path = (
                f"/repos/{self._app.repository}/issues"
                f"?state={state}&sort=updated&direction=desc&per_page={PAGE_SIZE}&page={page}"
            )
            response = await self._app.request("GET", path)
            items = response.body if isinstance(response.body, list) else []
            for item in items:
                if not isinstance(item, dict) or item.get("pull_request") is not None:
                    continue
                records.append(_record_of(item))
                if len(records) >= ceiling:
                    return records
            if len(items) < PAGE_SIZE:
                break
        return records


def _record_of(item: dict[str, Any]) -> IssueRecord:
    """Turn one API issue object into a record.

    Args:
        item: The decoded issue.

    Returns:
        The record.
    """
    labels = tuple(str(label.get("name") or "") for label in item.get("labels") or [] if isinstance(label, dict))
    return IssueRecord(
        number=int(item.get("number") or 0),
        title=str(item.get("title") or ""),
        body=str(item.get("body") or ""),
        url=str(item.get("html_url") or ""),
        state=str(item.get("state") or "open"),
        closed_at=str(item.get("closed_at") or ""),
        labels=labels,
    )


@dataclass
class _Serialiser:
    """One key's lock, and how many callers still need it.

    The count is what lets the entry be dropped: a plain ``dict`` of locks keyed by report never
    shrinks, and a long-running service files reports for as long as it runs.

    Attributes:
        lock: The lock two simultaneous filings of the same report contend on.
        waiting: How many callers hold it or are queued for it.
    """

    lock: asyncio.Lock = field(default_factory=asyncio.Lock)
    waiting: int = 0


class IssueFiler:
    """Files one report as one issue, whatever happens twice."""

    def __init__(
        self,
        app: GitHubApp,
        ledger: Ledger,
        *,
        redactor: Callable[[str], str],
        logger: Logger | None = None,
        machine_label: str = MACHINE_LABEL,
    ) -> None:
        """Initialize the filer.

        Args:
            app: The authenticated client.
            ledger: Where filed reports are recorded.
            redactor: The single redaction helper, bound to the checkout it resolves out of. What
                this filer publishes whole — the text attachments — goes through it.
            logger: Logger to use.
            machine_label: The label marking an issue as machine-filed.
        """
        self._app = app
        self._ledger = ledger
        self._redactor = redactor
        self._logger = logger or get_logger("filing")
        self._machine_label = machine_label
        self._locks: dict[str, _Serialiser] = {}

    @asynccontextmanager
    async def _serialised(self, key: str) -> AsyncIterator[None]:
        """Hold one report's lock, and forget the lock once nobody wants it.

        Args:
            key: The report's idempotency key.

        Yields:
            Nothing; the block runs with the key's lock held.
        """
        entry = self._locks.setdefault(key, _Serialiser())
        entry.waiting += 1
        try:
            async with entry.lock:
                yield
        finally:
            entry.waiting -= 1
            if entry.waiting == 0:
                # Safe to drop: every caller for this key has left, so nobody can be handed a second
                # lock while a first one is still held.
                self._locks.pop(key, None)

    async def file(self, report: BugReport, *, thread_url: str = "") -> Outcome:
        """Open the issue for one report, or return the one already opened for it.

        Args:
            report: The assembled report.
            thread_url: Link back to the Discord thread.

        Returns:
            The outcome. Never raises: a failure is an :class:`Outcome` the reporter is told about,
            because an exception here loses a report he has already spent five minutes on.
        """
        key = report_key(report)
        async with self._serialised(key):
            recorded = self._ledger.load().get(key) or {}
            if recorded.get("number"):
                return Outcome(action="reused", number=int(recorded["number"]), url=str(recorded.get("url") or ""))
            try:
                return await self._file_once(report, key, thread_url)
            except GitHubError as error:
                self._logger.error(
                    "the issue could not be filed",
                    extra={"event": "filing.failed", "key": key, "status": error.status, "error": str(error)},
                )
                return Outcome(action="failed", error=str(error))

    async def comment_on(self, number: int, report: BugReport, *, thread_url: str = "") -> Outcome:
        """Add the new observation to an existing issue instead of opening a second one.

        Args:
            number: The issue to comment on.
            report: The assembled report.
            thread_url: Link back to the Discord thread.

        Returns:
            The outcome.
        """
        lang = report.form.language if report.form.language in ("fr", "en") else "en"
        try:
            response = await self._app.request(
                "POST",
                f"/repos/{self._app.repository}/issues/{number}/comments",
                {"body": render_duplicate_comment(report, lang, thread_url)},
            )
        except GitHubError as error:
            self._logger.error(
                "the observation could not be added to the existing issue",
                extra={"event": "filing.comment_failed", "issue": number, "error": str(error)},
            )
            return Outcome(action="failed", error=str(error))
        url = str(response.body.get("html_url") or "") if isinstance(response.body, dict) else ""
        return Outcome(action="commented", number=number, url=url)

    async def _file_once(self, report: BugReport, key: str, thread_url: str) -> Outcome:
        """Create the issue, having first made sure no earlier attempt already did.

        The marker search runs on **every** report that has no recorded number, not only on one the
        ledger remembers as interrupted. Gating it on ``state == "filing"`` made it unreachable in
        the three situations it exists for — a ledger that is corrupt, one on a state volume that
        was never mounted, and one whose write was swallowed — because each of those makes the
        ledger read as *empty*, not as *interrupted*. The cost of the ungated search is one ``GET``
        on the first filing of a genuinely new report; the cost of the gate was a second issue on a
        public tracker, which is the outcome the ticket calls hardest to undo.

        Args:
            report: The assembled report.
            key: The report's idempotency key.
            thread_url: Link back to the Discord thread.

        Returns:
            The outcome.

        Raises:
            GitHubError: The creation failed.
        """
        existing = await self._find_by_marker(key)
        if existing is not None:
            self._remember(key, existing)
            return Outcome(action="reused", number=existing.number, url=existing.url)

        carried = [carry(item, redactor=self._redactor) for item in report.attachments if isinstance(item, Prepared)]
        body = render_body(report, key, thread_url=thread_url, carried=carried)
        labels = self._labels_for(report)

        self._ledger.record(key, {"state": "filing", "started": time.time()})
        response, notes = await self._create(report.title, body, labels)
        item = _record_of(response if isinstance(response, dict) else {})
        self._remember(key, item)
        notes += await self._attach(item.number, carried)
        self._logger.info(
            "issue filed",
            extra={"event": "filing.created", "key": key, "issue": item.number, "labels": list(labels)},
        )
        return Outcome(action="created", number=item.number, url=item.url, notes=notes)

    async def _create(self, title: str, body: str, labels: tuple[str, ...]) -> tuple[Any, tuple[str, ...]]:
        """Create the issue, retrying without the labels if GitHub refuses them.

        A label that does not exist yet is a ``422``, and losing the whole report over a label is
        the wrong trade — the issue is filed and the missing label becomes a note. Creating labels
        would need no extra permission, but it would let a bot invent taxonomy in a public
        repository, which is a decision for a maintainer.

        Args:
            title: The issue title.
            body: The issue body.
            labels: The labels to ask for.

        Returns:
            A pair of the created issue object and any notes.

        Raises:
            GitHubError: The creation failed for a reason the labels do not explain.
        """
        path = f"/repos/{self._app.repository}/issues"
        try:
            asked = await self._app.request("POST", path, {"title": title, "body": body, "labels": list(labels)})
            return asked.body, ()
        except GitHubError as error:
            if error.status != 422:
                raise
            # Bound outside the handler: Python deletes the `as` name when the block ends, and the
            # note built below would otherwise be a NameError at the one moment it is needed.
            refusal = str(error)
        self._logger.warning(
            "GitHub refused the labels; filing without them",
            extra={"event": "filing.labels_refused", "labels": list(labels), "error": refusal},
        )
        response = await self._app.request("POST", path, {"title": title, "body": body})
        return response.body, (f"labels {', '.join(labels)} could not be applied: {refusal}",)

    async def _attach(self, number: int, carried: Sequence[Carried]) -> tuple[str, ...]:
        """Post the comments carrying the text attachments whole.

        Best effort on purpose: the issue exists and holds the excerpt already: failing to post a
        full log must not turn a filed issue into a failure the reporter is told to retry.

        Args:
            number: The issue number.
            carried: What became of each attachment.

        Returns:
            One note per comment that could not be posted.
        """
        notes: list[str] = []
        for comment in render_attachment_comments(carried):
            try:
                await self._app.request(
                    "POST", f"/repos/{self._app.repository}/issues/{number}/comments", {"body": comment}
                )
            except GitHubError as error:
                notes.append(f"an attachment could not be added to the issue: {error}")
                self._logger.warning(
                    "an attachment comment could not be posted",
                    extra={"event": "filing.attachment_failed", "issue": number, "error": str(error)},
                )
        return tuple(notes)

    async def _find_by_marker(self, key: str) -> IssueRecord | None:
        """Look for an issue this service already opened for *key*.

        The recovery path for a restart that lost the answer to a ``POST`` it had already sent. It
        reads the repository's own recent issues rather than the search API: search is eventually
        consistent and an issue created seconds ago is routinely absent from it, which is exactly
        the moment this runs.

        **It sees one page — the 100 most recently created issues.** That is enough for what it
        defends against, because a re-submission arrives while the reporter is still in the thread
        and a restart replays what was in flight. What it does not cover is the same report filed
        again long after 100 issues have gone by, and the ledger is what covers that: this is a
        second line, not a replacement. Paging further would cost up to five ``GET`` calls on every
        report to close a case the ledger already closes whenever it is readable.

        Args:
            key: The report's idempotency key.

        Returns:
            The issue, or ``None``.
        """
        marker = marker_for(key)
        path = f"/repos/{self._app.repository}/issues?state=all&sort=created&direction=desc&per_page={PAGE_SIZE}"
        try:
            response = await self._app.request("GET", path)
        except GitHubError as error:
            self._logger.warning(
                "the recovery search could not run; a duplicate issue is possible",
                extra={"event": "filing.recovery_failed", "error": str(error)},
            )
            return None
        for item in response.body if isinstance(response.body, list) else []:
            if isinstance(item, dict) and marker in str(item.get("body") or ""):
                return _record_of(item)
        return None

    def _labels_for(self, report: BugReport) -> tuple[str, ...]:
        """Return the labels the issue is opened with.

        Args:
            report: The assembled report.

        Returns:
            The report's own labels plus the machine-filed marker, deduplicated, ``bug`` first.
        """
        wanted = [BASE_LABEL, *report.labels, self._machine_label]
        seen: list[str] = []
        for label in wanted:
            if label and label not in seen:
                seen.append(label)
        return tuple(seen)

    def _remember(self, key: str, item: IssueRecord) -> None:
        """Record a filed issue against its key.

        Args:
            key: The report's idempotency key.
            item: The issue.
        """
        self._ledger.record(key, {"state": "filed", "number": item.number, "url": item.url, "at": time.time()})
