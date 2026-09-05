"""The working copy: that it refreshes, that a failure is survivable, and that it says which.

The freshness mechanism only earns its place if the two failure modes are visible. A checkout that
silently stopped refreshing would keep printing locations that look exactly like fresh ones — the
worst outcome of the whole feature, because a wrong file:line carries a machine's confidence.

These cases run against **real git repositories** built in temporary directories: a clone with a
remote it can fetch from, and one whose remote does not exist.
"""

from __future__ import annotations

import subprocess
import tempfile
import threading
import time
import unittest
from pathlib import Path

from veaf_support_bot.checkout import (
    UNKNOWN_REVISION,
    Checkout,
    CheckoutUnavailable,
    Freshness,
    _humanise_age,
    open_checkout,
)


def _git(root: Path, *args: str) -> None:
    """Run a git command, failing the test loudly when it does not work.

    Args:
        root: The working tree.
        *args: Arguments after ``git``.
    """
    subprocess.run(
        ["git", "-C", str(root), *args],
        check=True,
        capture_output=True,
        text=True,
        stdin=subprocess.DEVNULL,
    )


def _repository(root: Path, content: str = "one") -> None:
    """Build a git repository with one commit.

    Args:
        root: Where to build it.
        content: What the single file holds.
    """
    root.mkdir(parents=True, exist_ok=True)
    _git(root, "init", "--quiet", "--initial-branch=develop")
    _git(root, "config", "user.email", "test@example.org")
    _git(root, "config", "user.name", "Test")
    (root / "file.txt").write_text(content, encoding="utf-8")
    _git(root, "add", "file.txt")
    _git(root, "commit", "--quiet", "-m", "one")


def _git_is_available() -> bool:
    """Say whether ``git`` can be run at all.

    Returns:
        ``True`` when it is on the path.
    """
    try:
        subprocess.run(["git", "--version"], check=True, capture_output=True, stdin=subprocess.DEVNULL)
    except (OSError, subprocess.SubprocessError):
        return False
    return True


@unittest.skipUnless(_git_is_available(), "git is not available")
class TestOpeningACheckout(unittest.TestCase):
    def test_a_real_working_tree_opens(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / "repo"
            _repository(root)
            checkout = open_checkout(str(root), refresh_seconds=0)
            self.assertNotEqual(checkout.freshness().revision, UNKNOWN_REVISION)

    def test_a_directory_that_is_not_a_working_tree_is_refused_at_startup(self) -> None:
        """Discovering this on the first bug report is discovering it a week late."""
        with tempfile.TemporaryDirectory() as directory:
            with self.assertRaises(CheckoutUnavailable):
                open_checkout(directory)

    def test_a_path_that_does_not_exist_is_refused(self) -> None:
        with self.assertRaises(CheckoutUnavailable):
            open_checkout(str(Path(tempfile.gettempdir()) / "nothing-here-at-all"))


@unittest.skipUnless(_git_is_available(), "git is not available")
class TestRefreshing(unittest.TestCase):
    def setUp(self) -> None:
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        base = Path(self.directory.name)
        self.origin = base / "origin"
        _repository(self.origin)
        self.clone = base / "clone"
        subprocess.run(
            ["git", "clone", "--quiet", str(self.origin), str(self.clone)],
            check=True,
            capture_output=True,
            stdin=subprocess.DEVNULL,
        )

    def test_a_refresh_picks_up_a_new_commit(self) -> None:
        (self.origin / "file.txt").write_text("two", encoding="utf-8")
        _git(self.origin, "commit", "--quiet", "-am", "two")

        checkout = Checkout(self.clone, refresh_seconds=1)
        before = checkout.freshness().revision
        after = checkout.refresh(force=True)
        self.assertNotEqual(after.revision, before)
        self.assertFalse(after.stale)
        self.assertEqual((self.clone / "file.txt").read_text(encoding="utf-8"), "two")

    def test_a_failed_refresh_keeps_the_previous_revision_and_says_it_is_stale(self) -> None:
        """The network is down; the service keeps answering, and every location says so."""
        _git(self.clone, "remote", "set-url", "origin", str(Path(self.directory.name) / "gone"))
        checkout = Checkout(self.clone, refresh_seconds=1)
        before = checkout.freshness().revision
        after = checkout.refresh(force=True)
        self.assertEqual(after.revision, before)
        self.assertTrue(after.stale)
        self.assertTrue(after.error)
        self.assertIn("LAST REFRESH FAILED", after.describe())

    def test_a_refresh_is_not_repeated_inside_its_interval(self) -> None:
        checkout = Checkout(self.clone, refresh_seconds=3600)
        checkout.refresh(force=True)
        self.assertFalse(checkout.due())
        self.assertEqual(checkout.refresh(), checkout.freshness())

    def test_refreshing_can_be_turned_off_entirely(self) -> None:
        checkout = Checkout(self.clone, refresh_seconds=0)
        self.assertFalse(checkout.due())

    def test_a_failed_attempt_is_retried_on_the_timer_not_on_every_report(self) -> None:
        """Otherwise a dead remote makes every single report pay for a fetch that cannot work."""
        _git(self.clone, "remote", "set-url", "origin", str(Path(self.directory.name) / "gone"))
        checkout = Checkout(self.clone, refresh_seconds=3600)
        checkout.refresh(force=True)
        self.assertFalse(checkout.due())


class TestDescribingFreshness(unittest.TestCase):
    def test_a_checkout_never_refreshed_says_so_rather_than_nothing(self) -> None:
        described = Freshness(revision="4f2a1c9ab").describe()
        self.assertIn("never refreshed", described)

    def test_a_fresh_checkout_names_its_revision_and_its_age(self) -> None:
        described = Freshness(revision="4f2a1c9ab", refreshed_at=1_000_000.0).describe(now=1_000_900.0)
        self.assertIn("4f2a1c9ab", described)
        self.assertIn("15 min ago", described)

    def test_an_unknown_revision_is_still_named(self) -> None:
        self.assertIn(UNKNOWN_REVISION, Freshness().describe())

    def test_ages_read_the_way_a_sentence_says_them(self) -> None:
        self.assertEqual(_humanise_age(30), "30 s ago")
        self.assertEqual(_humanise_age(600), "10 min ago")
        self.assertEqual(_humanise_age(7200), "2 h ago")
        self.assertEqual(_humanise_age(400_000), "4 days ago")


class TestResolvingWithoutGit(unittest.TestCase):
    def test_a_checkout_whose_git_cannot_answer_reports_an_unknown_revision(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            self.assertEqual(Checkout(Path(directory)).freshness().revision, UNKNOWN_REVISION)

    def test_resolving_an_empty_path_yields_nothing(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            self.assertIsNone(Checkout(Path(directory)).resolve(""))

    def test_resolving_a_directory_yields_nothing(self) -> None:
        """Only a regular file can be quoted; a directory that resolved would crash the reader."""
        with tempfile.TemporaryDirectory() as directory:
            (Path(directory) / "sub").mkdir()
            self.assertIsNone(Checkout(Path(directory)).resolve("sub"))


class TestTwoReportsAtOnceRefreshOnce(unittest.TestCase):
    """Two ``/bug`` submissions inside one interval must not both reset the same working tree.

    Without the lock the sequence is: both read ``due()`` as true, both call ``git reset --hard``,
    and the loser dies on ``.git/index.lock`` — marking a checkout stale that is in fact current.
    The test counts the ``git`` pass rather than watching for the lock file, because the count is
    the property and the lock file is only one way it shows.
    """

    #: How long the window between deciding "due" and recording the attempt is held open, and how
    #: long the git pass takes. The window is real and narrow; widening it is what makes the case
    #: decide the same way every run instead of once in twenty.
    WINDOW_SECONDS = 0.05
    GIT_SECONDS = 0.2

    def _checkout(self, attempts: list[float], *, widen: bool) -> Checkout:
        """Build a checkout whose git pass is counted and slow enough to overlap.

        Args:
            attempts: Where each attempt records its start time.
            widen: Whether ``due`` holds the window open, so the interleaving is the one being
                asserted about rather than whichever one the scheduler happened to pick.

        Returns:
            The checkout.
        """
        checkout = Checkout(Path(tempfile.mkdtemp()), refresh_seconds=900.0)
        real_due = checkout.due

        def fetch_and_reset() -> str:
            attempts.append(time.time())
            time.sleep(self.GIT_SECONDS)
            return ""

        def slow_due(now: float | None = None) -> bool:
            answer = real_due(now)
            if widen:
                time.sleep(self.WINDOW_SECONDS)
            return answer

        checkout._fetch_and_reset = fetch_and_reset  # type: ignore[method-assign]
        checkout._read_revision = lambda: "abc123def"  # type: ignore[method-assign]
        checkout.due = slow_due  # type: ignore[method-assign]
        return checkout

    def _both_report(self, checkout: Checkout, gate: threading.Barrier) -> list[Freshness]:
        """Drive two threads through the call site :meth:`BugIntake.build` uses.

        Args:
            checkout: The checkout under test.
            gate: Released once both threads have read ``due()`` as true.

        Returns:
            What each thread got back.
        """
        results: list[Freshness] = []

        def report() -> None:
            if checkout.due():
                gate.wait()
                results.append(checkout.refresh())
            else:
                results.append(checkout.freshness())

        threads = [threading.Thread(target=report) for _ in range(2)]
        for thread in threads:
            thread.start()
        for thread in threads:
            thread.join()
        return results

    def test_two_reports_deciding_a_refresh_is_due_run_git_once(self) -> None:
        attempts: list[float] = []
        checkout = self._checkout(attempts, widen=True)
        self._both_report(checkout, threading.Barrier(2, timeout=5))
        self.assertEqual(len(attempts), 1, "both threads ran `git reset --hard` in the same tree")
        self.assertFalse(checkout.freshness().stale)

    def test_the_second_caller_waits_for_the_first_ones_answer(self) -> None:
        """Not merely one fetch: the second caller must get the refreshed state, not the old one."""
        attempts: list[float] = []
        checkout = self._checkout(attempts, widen=False)
        results = self._both_report(checkout, threading.Barrier(2, timeout=5))
        self.assertEqual(len(set(results)), 1, "one of the two answered from before the refresh")


if __name__ == "__main__":
    unittest.main()
