"""The counters, and above all the two ways they must not fail.

They must not reset to "unlimited" — not on a restart, not when the file is corrupt, not when the
disk refuses a write. And a refusal must carry when it lifts, because a bot that goes quiet reads as
a broken bot.
"""

from __future__ import annotations

import json
import tempfile
import unittest
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

from veaf_support_bot.quota import (
    DEGRADED_PER_WINDOW,
    QuotaKeeper,
    QuotaLimits,
    QuotaStore,
    next_midnight,
)

#: A fixed instant, so "the next UTC midnight" is a number the tests can name.
NOON = datetime(2026, 9, 5, 12, 0, 0, tzinfo=UTC).timestamp()


class _Clock:
    """A clock the tests move by hand."""

    def __init__(self, now: float = NOON) -> None:
        """Initialize the clock.

        Args:
            now: The starting instant.
        """
        self.now = now

    def __call__(self) -> float:
        """Return the current instant.

        Returns:
            The instant.
        """
        return self.now


class _QuotaTestCase(unittest.TestCase):
    """Gives each test a private counters file."""

    def setUp(self) -> None:
        """Create the temporary directory the counters live in."""
        self._directory = tempfile.TemporaryDirectory()
        self.addCleanup(self._directory.cleanup)
        self.path = Path(self._directory.name) / "quota.json"

    def keeper(self, clock: _Clock | None = None, **limits: Any) -> QuotaKeeper:
        """Build a keeper on the test's own file.

        Args:
            clock: The clock to use.
            **limits: Overrides of :class:`~veaf_support_bot.quota.QuotaLimits`.

        Returns:
            The keeper.
        """
        return QuotaKeeper(QuotaLimits(**limits), QuotaStore(self.path), clock=clock or _Clock())


class TestPerUserCeilings(_QuotaTestCase):
    def test_a_user_may_ask_up_to_the_window_allowance(self) -> None:
        keeper = self.keeper(user_per_window=3, user_per_day=99, global_per_day=99)

        self.assertTrue(all(keeper.check_and_consume("u1").allowed for _ in range(3)))

    def test_the_next_one_is_refused(self) -> None:
        keeper = self.keeper(user_per_window=2, user_per_day=99, global_per_day=99)
        for _ in range(2):
            keeper.check_and_consume("u1")

        decision = keeper.check_and_consume("u1")

        self.assertFalse(decision.allowed)
        self.assertEqual(decision.reason, "user-window")

    def test_the_window_reopens_when_it_expires(self) -> None:
        clock = _Clock()
        keeper = self.keeper(clock, user_window_seconds=60, user_per_window=1, user_per_day=99, global_per_day=99)
        keeper.check_and_consume("u1")

        clock.now += 61

        self.assertTrue(keeper.check_and_consume("u1").allowed)

    def test_one_user_s_burst_does_not_refuse_another(self) -> None:
        keeper = self.keeper(user_per_window=1, user_per_day=99, global_per_day=99)
        keeper.check_and_consume("u1")

        self.assertTrue(keeper.check_and_consume("u2").allowed)

    def test_the_daily_ceiling_holds_across_windows(self) -> None:
        clock = _Clock()
        keeper = self.keeper(clock, user_window_seconds=60, user_per_window=1, user_per_day=2, global_per_day=99)
        for _ in range(2):
            keeper.check_and_consume("u1")
            clock.now += 61

        decision = keeper.check_and_consume("u1")

        self.assertFalse(decision.allowed)
        self.assertEqual(decision.reason, "user-day")

    def test_a_daily_refusal_lifts_at_the_next_utc_midnight(self) -> None:
        keeper = self.keeper(user_per_day=1, user_per_window=9, global_per_day=99)
        keeper.check_and_consume("u1")

        decision = keeper.check_and_consume("u1")

        self.assertEqual(decision.reset_at, next_midnight(NOON))

    def test_a_new_day_gives_everyone_their_allowance_back(self) -> None:
        clock = _Clock()
        keeper = self.keeper(clock, user_per_day=1, user_per_window=9, global_per_day=99)
        keeper.check_and_consume("u1")

        clock.now = next_midnight(NOON) + 1

        self.assertTrue(keeper.check_and_consume("u1").allowed)


class TestTheGlobalCeiling(_QuotaTestCase):
    """The only bound on the bot's total spend: the Worker counts per user and cannot see it."""

    def test_it_refuses_a_user_who_still_has_allowance_of_their_own(self) -> None:
        keeper = self.keeper(user_per_window=9, user_per_day=9, global_per_day=2)
        keeper.check_and_consume("u1")
        keeper.check_and_consume("u2")

        decision = keeper.check_and_consume("u3")

        self.assertFalse(decision.allowed)
        self.assertEqual(decision.reason, "global-day")

    def test_it_is_checked_before_the_per_user_counters(self) -> None:
        """A user at *both* ceilings must be told the one that actually governs the whole bot."""
        keeper = self.keeper(user_per_window=1, user_per_day=1, global_per_day=1)
        keeper.check_and_consume("u1")

        self.assertEqual(keeper.check_and_consume("u1").reason, "global-day")

    def test_a_refused_question_is_not_counted(self) -> None:
        keeper = self.keeper(user_per_window=1, user_per_day=9, global_per_day=99)
        keeper.check_and_consume("u1")
        keeper.check_and_consume("u1")

        self.assertEqual(keeper.snapshot()["global_count"], 1)

    def test_it_lifts_at_the_next_utc_midnight(self) -> None:
        keeper = self.keeper(user_per_window=9, user_per_day=9, global_per_day=1)
        keeper.check_and_consume("u1")

        self.assertEqual(keeper.check_and_consume("u2").reset_at, next_midnight(NOON))


class TestRestart(_QuotaTestCase):
    """A restart must not be a way to get a fresh allowance."""

    def test_a_user_at_their_daily_ceiling_is_still_refused_after_a_restart(self) -> None:
        first = self.keeper(user_per_window=9, user_per_day=1, global_per_day=99)
        first.check_and_consume("u1")

        restarted = self.keeper(user_per_window=9, user_per_day=1, global_per_day=99)

        self.assertFalse(restarted.check_and_consume("u1").allowed)

    def test_the_bot_s_daily_spend_survives_a_restart(self) -> None:
        first = self.keeper(user_per_window=9, user_per_day=9, global_per_day=5)
        for user in ("u1", "u2", "u3"):
            first.check_and_consume(user)

        restarted = self.keeper(user_per_window=9, user_per_day=9, global_per_day=5)

        self.assertEqual(restarted.snapshot()["global_count"], 3)

    def test_a_crash_mid_write_leaves_the_previous_counters_not_a_truncated_file(self) -> None:
        """The store writes to a temporary file and renames, so there is no half-written state."""
        keeper = self.keeper(user_per_window=9, user_per_day=9, global_per_day=99)
        keeper.check_and_consume("u1")

        document = json.loads(self.path.read_text(encoding="utf-8"))

        self.assertEqual(document["global_count"], 1)
        self.assertEqual(list(Path(self._directory.name).glob(".quota-*")), [])


class TestFailingClosed(_QuotaTestCase):
    """When the counters cannot be kept, the answer is *stricter*, never "unlimited"."""

    def test_a_corrupt_file_degrades_instead_of_reading_as_no_counters(self) -> None:
        self.path.write_text("{not json at all", encoding="utf-8")

        keeper = self.keeper(user_per_window=99, user_per_day=99, global_per_day=99)

        self.assertTrue(keeper.degraded)

    def test_a_file_from_an_unknown_version_degrades(self) -> None:
        self.path.write_text(json.dumps({"version": 99, "day": "", "global_count": 0}), encoding="utf-8")

        keeper = self.keeper(user_per_window=99, user_per_day=99, global_per_day=99)

        self.assertTrue(keeper.degraded)

    def test_a_degraded_keeper_is_far_stricter_than_the_configured_ceilings(self) -> None:
        self.path.write_text("{", encoding="utf-8")
        keeper = self.keeper(user_per_window=99, user_per_day=99, global_per_day=99)

        allowed = sum(1 for _ in range(10) if keeper.check_and_consume("u1").allowed)

        self.assertEqual(allowed, DEGRADED_PER_WINDOW)

    def test_a_degraded_refusal_still_says_when_it_lifts(self) -> None:
        self.path.write_text("{", encoding="utf-8")
        clock = _Clock()
        keeper = QuotaKeeper(QuotaLimits(user_window_seconds=60), QuotaStore(self.path), clock=clock)
        for _ in range(DEGRADED_PER_WINDOW):
            keeper.check_and_consume("u1")

        decision = keeper.check_and_consume("u1")

        self.assertEqual(decision.reason, "degraded")
        self.assertEqual(decision.reset_at, NOON + 60)

    def test_the_degraded_ceiling_counts_the_whole_bot_not_one_user(self) -> None:
        """Otherwise a broken store would be *looser* per user than a working one for a big server."""
        self.path.write_text("{", encoding="utf-8")
        keeper = self.keeper()
        for _ in range(DEGRADED_PER_WINDOW):
            keeper.check_and_consume("u1")

        self.assertFalse(keeper.check_and_consume("someone-else").allowed)

    def test_no_store_at_all_is_itself_a_reason_to_degrade(self) -> None:
        """Counters nobody keeps are counters a restart wipes."""
        keeper = QuotaKeeper(QuotaLimits())

        self.assertTrue(keeper.degraded)

    def test_a_write_that_fails_degrades_the_rest_of_the_run(self) -> None:
        """The question that fails to be written was already counted; the *next* one must not be."""
        # A file where the counters' directory should be — a mount that came back as a file, a
        # volume that was never created. The store cannot write there and cannot create it either.
        blocked = Path(self._directory.name) / "blocked"
        blocked.write_text("not a directory", encoding="utf-8")
        keeper = QuotaKeeper(
            QuotaLimits(user_per_window=99, user_per_day=99, global_per_day=99),
            QuotaStore(blocked / "quota.json"),
            clock=_Clock(),
        )
        self.assertFalse(keeper.degraded, "nothing has been written yet, so nothing has failed yet")

        keeper.check_and_consume("u1")

        self.assertTrue(keeper.degraded)
        self.assertIn("could not be written", str(keeper.degraded_reason))

    def test_the_reason_it_degraded_is_reported_not_only_the_fact(self) -> None:
        self.path.write_text("{", encoding="utf-8")

        keeper = self.keeper()

        self.assertIn("could not be read", str(keeper.degraded_reason))


class TestStatusReporting(_QuotaTestCase):
    """What an operator sees when the bot starts refusing."""

    def test_the_snapshot_shows_the_day_s_spend_against_its_ceiling(self) -> None:
        keeper = self.keeper(user_per_window=9, user_per_day=9, global_per_day=200)
        keeper.check_and_consume("u1")

        snapshot = keeper.snapshot()

        self.assertEqual((snapshot["global_count"], snapshot["global_per_day"]), (1, 200))

    def test_the_snapshot_says_when_the_counters_are_not_being_kept(self) -> None:
        self.path.write_text("{", encoding="utf-8")

        self.assertTrue(self.keeper().snapshot()["degraded"])

    def test_the_snapshot_carries_no_user_identity(self) -> None:
        """`/status` is an operator endpoint, not a list of who asked what."""
        keeper = self.keeper(user_per_window=9, user_per_day=9, global_per_day=99)
        keeper.check_and_consume("a-very-recognisable-user")

        self.assertNotIn("a-very-recognisable-user", json.dumps(keeper.snapshot()))
        self.assertEqual(keeper.snapshot()["tracked_users"], 1)


if __name__ == "__main__":
    unittest.main()
