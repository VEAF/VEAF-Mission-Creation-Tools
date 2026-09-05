"""The repository working copy the intake reads, and how it is kept fresh.

``/bug`` turns a stack trace into a **location**: ``mission_builder/v5_converter.py:412``, the lines
around it, and the functions that call the one it sits in. That is only worth printing if the file
on disk is the file the reporter is running. A location pointing at a line that moved three releases
ago is worse than no location — it sends a maintainer to the wrong code with the confidence of a
machine-produced fact.

So the service keeps a **dedicated clone** of the repository and refreshes it on a timer. Three
things follow from that, and each of them is visible rather than assumed:

* **The clone is the service's, not a shared one.** Refreshing does ``fetch`` then a hard reset onto
  the tracked branch, which throws away anything local. Pointing this at a working copy somebody
  edits would lose their work, so the configuration variable is documented as needing its own
  clone, and nothing here ever writes to a checkout it was not given.
* **A refresh that fails is not fatal.** The network is down, the remote moved, the disk is full:
  the previous revision stays usable and the service goes on answering. What changes is that the
  checkout is now *stale*, and it says so.
* **Every location carries the revision it came from.** That is the part that makes staleness
  harmless: a reader who sees ``at 4f2a1c9 (2 hours old)`` under a file:line can tell whether to
  trust it. A location with no provenance cannot be checked at all.

This module runs ``git`` and nothing else. It never imports from the checkout — that is
:mod:`veaf_support_bot.toolkit`'s job — and it never interprets what the checkout contains.
"""

from __future__ import annotations

import subprocess
import threading
import time
from dataclasses import dataclass
from pathlib import Path

from veaf_support_bot.logging_setup import get_logger

#: How long a ``git`` invocation is given before it is killed. A fetch that hangs on a dead remote
#: must not hold the refresh lock until the next restart.
GIT_TIMEOUT_SECONDS = 120.0

#: Length of the short revision the issue quotes.
SHORT_REVISION_CHARS = 9

#: What :meth:`Checkout.revision` reports when ``git`` could not answer.
UNKNOWN_REVISION = "unknown"


class CheckoutUnavailable(RuntimeError):
    """The service has no usable working copy of the repository.

    Raised by :func:`open_checkout` at startup rather than by the first ``/bug``: a path that is not
    a git working tree is a deployment mistake, and finding it out when the first user reports a bug
    is finding it out too late.
    """


@dataclass(frozen=True)
class Freshness:
    """What is known about the checkout's currency, as the issue will state it.

    Attributes:
        revision: The short commit the working copy is at, or :data:`UNKNOWN_REVISION`.
        refreshed_at: Unix timestamp of the last **successful** refresh, or ``0.0`` when none has
            succeeded in this process.
        stale: ``True`` when the last refresh attempt failed. A stale checkout still produces
            locations; they are simply labelled as coming from an unverified revision.
        error: Short description of the last failure, or an empty string.
    """

    revision: str = UNKNOWN_REVISION
    refreshed_at: float = 0.0
    stale: bool = False
    error: str = ""

    def describe(self, now: float | None = None) -> str:
        """Render the provenance line that travels under every extracted location.

        Args:
            now: Current Unix timestamp; defaults to the clock.

        Returns:
            A short phrase, e.g. ``"4f2a1c9ab, refreshed 12 min ago"``. Never an empty string: a
            location whose provenance renders blank is a location a reader cannot check.
        """
        if self.refreshed_at <= 0:
            described = f"{self.revision} (never refreshed by this service)"
        else:
            age = max(0.0, (time.time() if now is None else now) - self.refreshed_at)
            described = f"{self.revision}, refreshed {_humanise_age(age)}"
        # The failure is appended in **both** cases. A checkout that has never refreshed *and* is
        # failing is the worst case there is, and an early return on the first condition made it
        # the one that said the least.
        return f"{described} — LAST REFRESH FAILED: {self.error}" if self.stale else described


def _humanise_age(seconds: float) -> str:
    """Render a duration the way a sentence would say it.

    Args:
        seconds: Age in seconds.

    Returns:
        e.g. ``"12 min ago"``.
    """
    if seconds < 90:
        return f"{int(seconds)} s ago"
    if seconds < 5400:
        return f"{int(seconds // 60)} min ago"
    if seconds < 172800:
        return f"{int(seconds // 3600)} h ago"
    return f"{int(seconds // 86400)} days ago"


def _run_git(root: Path, *args: str) -> subprocess.CompletedProcess[str]:
    """Run one ``git`` command inside *root*.

    Args:
        root: The working tree.
        *args: Arguments after ``git``.

    Returns:
        The completed process, whatever its exit code — the callers decide what a failure means.

    Raises:
        OSError: ``git`` is not installed or not executable.
        subprocess.TimeoutExpired: The command outlived :data:`GIT_TIMEOUT_SECONDS`.
    """
    return subprocess.run(
        ["git", "-C", str(root), *args],
        capture_output=True,
        text=True,
        timeout=GIT_TIMEOUT_SECONDS,
        check=False,
        # No shell, no inherited stdin: this runs unattended and must never stop on a credential
        # prompt. A private remote is configured with a credential helper or a deploy key, not by
        # a service waiting forever on a terminal that does not exist.
        stdin=subprocess.DEVNULL,
    )


class Checkout:
    """A working copy of the repository, and the timer that keeps it current.

    The object is cheap to hold and safe to consult from anywhere: :meth:`freshness` reads state,
    :meth:`refresh` changes it, and every caller of :meth:`refresh` gets the same answer within one
    refresh interval rather than each triggering a fetch.
    """

    def __init__(
        self,
        root: Path,
        *,
        remote: str = "origin",
        branch: str = "develop",
        refresh_seconds: float = 900.0,
    ) -> None:
        """Initialize the checkout without touching it.

        Args:
            root: The working tree. Must be a clone the service owns.
            remote: The remote to fetch from.
            branch: The branch to reset onto.
            refresh_seconds: Shortest gap between two refreshes; ``0`` disables refreshing entirely,
                which is how a read-only deployment pins a revision on purpose.
        """
        self.root = root
        self.remote = remote
        self.branch = branch
        self.refresh_seconds = refresh_seconds
        self._logger = get_logger("checkout")
        self._lock = threading.Lock()
        self._freshness = Freshness(revision=self._read_revision())
        self._last_attempt = 0.0

    # -- reading ---------------------------------------------------------------

    def freshness(self) -> Freshness:
        """Return what is currently known about the checkout's currency.

        Returns:
            The last recorded :class:`Freshness`.
        """
        return self._freshness

    def resolve(self, relative: str) -> Path | None:
        """Turn a repository-relative path into an existing file inside the checkout.

        This is the **only** way anything in the service turns a path that came from user text into
        a path on disk. A trace pasted into a public form can name ``../../etc/passwd`` or an
        absolute path on another machine; both must resolve to nothing rather than to a file.

        Args:
            relative: A path as it appears in the repository, e.g. ``"veaf_libs/redaction.py"``.

        Returns:
            The resolved file, or ``None`` when it does not exist, is not a regular file, or would
            land outside the checkout.
        """
        if not relative:
            return None
        try:
            root = self.root.resolve()
            candidate = (root / relative).resolve()
        except (OSError, ValueError, RuntimeError):
            return None
        if not candidate.is_relative_to(root):
            return None
        return candidate if candidate.is_file() else None

    def _read_revision(self) -> str:
        """Read the commit the working copy is at.

        Returns:
            The short revision, or :data:`UNKNOWN_REVISION` when ``git`` could not answer.
        """
        try:
            done = _run_git(self.root, "rev-parse", "--short", "HEAD")
        except (OSError, subprocess.SubprocessError):
            return UNKNOWN_REVISION
        revision = done.stdout.strip()
        return revision[:SHORT_REVISION_CHARS] if done.returncode == 0 and revision else UNKNOWN_REVISION

    # -- refreshing ------------------------------------------------------------

    def due(self, now: float | None = None) -> bool:
        """Say whether a refresh is worth attempting.

        Args:
            now: Current Unix timestamp; defaults to the clock.

        Returns:
            ``False`` when refreshing is disabled or the interval has not elapsed since the last
            *attempt* — attempt, not success, so a remote that is down is retried on the timer
            rather than on every report.
        """
        if self.refresh_seconds <= 0:
            return False
        moment = time.time() if now is None else now
        return moment - self._last_attempt >= self.refresh_seconds

    def refresh(self, *, force: bool = False) -> Freshness:
        """Fetch and reset onto the tracked branch, unless it is too soon.

        Blocking: it runs ``git``. Call it from a worker thread, never on the event loop.

        Serialised on a lock, and the ``due`` check is taken **inside** it. Without that, two
        reports arriving inside one interval both read ``due()`` as true, and both run
        ``git reset --hard`` in the same working tree: the loser dies on ``.git/index.lock`` and
        marks a checkout stale that is in fact perfectly current. Holding the lock across the whole
        attempt is deliberate — the second caller wants the answer the first one is fetching, not a
        second fetch — and :data:`GIT_TIMEOUT_SECONDS` is what bounds the wait.

        Args:
            force: Refresh even when :meth:`due` says no.

        Returns:
            The freshness after the attempt. A failed attempt returns the previous revision with
            :attr:`Freshness.stale` set — the service keeps working on what it has.
        """
        with self._lock:
            return self._refresh_locked(force=force)

    def _refresh_locked(self, *, force: bool) -> Freshness:
        """Do the refresh, with :attr:`_lock` already held.

        Args:
            force: Refresh even when :meth:`due` says no.

        Returns:
            The freshness after the attempt.
        """
        if not force and not self.due():
            return self._freshness
        self._last_attempt = time.time()
        problem = self._fetch_and_reset()
        revision = self._read_revision()
        if problem:
            self._freshness = Freshness(
                revision=revision,
                refreshed_at=self._freshness.refreshed_at,
                stale=True,
                error=problem,
            )
            self._logger.warning(
                "the checkout could not be refreshed; locations will be labelled stale",
                extra={"event": "checkout.refresh_failed", "error": problem, "revision": revision},
            )
        else:
            self._freshness = Freshness(revision=revision, refreshed_at=time.time(), stale=False, error="")
            self._logger.info(
                "checkout refreshed",
                extra={"event": "checkout.refreshed", "revision": revision},
            )
        return self._freshness

    def _fetch_and_reset(self) -> str:
        """Run the two commands a refresh is made of.

        Returns:
            An empty string on success, or a short description of what went wrong. The description
            is built from the command that failed and its **last** line of standard error; a fetch
            failure can print a page, and the whole page has no place in a log line.
        """
        for args in (
            ("fetch", "--quiet", "--prune", self.remote, self.branch),
            ("reset", "--hard", "--quiet", f"{self.remote}/{self.branch}"),
        ):
            try:
                done = _run_git(self.root, *args)
            except subprocess.TimeoutExpired:
                return f"git {args[0]} timed out after {GIT_TIMEOUT_SECONDS:.0f} s"
            except OSError as error:
                return f"git could not be run ({type(error).__name__})"
            if done.returncode != 0:
                detail = (done.stderr or done.stdout).strip().splitlines()
                return f"git {args[0]} exited {done.returncode}: {detail[-1] if detail else 'no output'}"
        return ""


def open_checkout(
    path: str,
    *,
    remote: str = "origin",
    branch: str = "develop",
    refresh_seconds: float = 900.0,
) -> Checkout:
    """Validate a configured path and wrap it.

    Args:
        path: The configured filesystem path.
        remote: The remote to fetch from.
        branch: The branch to reset onto.
        refresh_seconds: Shortest gap between two refreshes.

    Returns:
        The checkout.

    Raises:
        CheckoutUnavailable: The path does not exist, or is not a git working tree. Both are
            deployment mistakes, and both are worth stopping the startup for: without a checkout,
            ``/bug`` files issues with no location in them and nobody notices for a week.
    """
    root = Path(path).expanduser()
    if not root.is_dir():
        raise CheckoutUnavailable(f"{root} is not a directory")
    if not (root / ".git").exists():
        raise CheckoutUnavailable(f"{root} is not a git working tree (no .git)")
    return Checkout(root, remote=remote, branch=branch, refresh_seconds=refresh_seconds)
