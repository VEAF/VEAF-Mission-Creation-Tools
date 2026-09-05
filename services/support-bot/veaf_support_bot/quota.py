"""Counting questions per Discord user, and per day for the whole bot.

## Why the service counts at all

The Worker rate-limits per **subject**, and for an IP-bound client the subject is the caller's IP
(``poc/doc-chatbot/worker/src/index.js``). A Discord bot is one IP for an entire server: left alone,
the whole VEAF would share one browser's allowance, and one person could exhaust it by lunchtime.
The service is the only component that knows *who* is asking, so the per-user quota lives here. It
passes a per-user subject to the Worker as well, so the same decision is enforced twice — but the
Worker has no idea what the bot's *total* spend is, and this module does.

## What it enforces

Three ceilings, checked in the order a user meets them:

* a **short window** per user, against a burst;
* a **day** per user, so one person cannot spend the server's allowance;
* a **day for the whole bot**, so a bad day has a known cost and a known end. This is the only bound
  on total spend, because the Worker's own counters are per user.

## Two decisions worth stating

**A refusal speaks.** It carries the reason and the moment the ceiling lifts, rendered as a Discord
timestamp so every reader sees it in their own timezone. A bot that simply goes quiet is
indistinguishable from a bot that is broken — the same failure as a monitoring loop that dies and
reports nothing.

**It fails closed.** Counters are persisted, so a restart does not hand everyone a fresh allowance.
When the store cannot be read or cannot be written, the service does not carry on with counters that
will evaporate: it drops to a much stricter in-memory ceiling for the whole bot and says so. That is
the same choice the Worker makes when KV is unreachable, for the same reason — the previous
behaviour there, returning "allowed", meant an outage silently removed every limit.
"""

from __future__ import annotations

import json
import os
import tempfile
import time
from collections.abc import Callable
from dataclasses import dataclass, field
from datetime import UTC, datetime, timedelta
from logging import Logger
from pathlib import Path
from typing import Any, Final

from veaf_support_bot.logging_setup import get_logger

#: Version of the persisted document. A file written by a future version is not read.
STATE_VERSION: Final = 1

#: Requests the whole bot may serve per window while the store is unusable. Deliberately tiny: the
#: point is to stay barely useful rather than to stay open, and it mirrors the Worker's own
#: degraded ceiling.
DEGRADED_PER_WINDOW: Final = 2


def _day_of(now: float) -> str:
    """Return the UTC calendar day a timestamp falls in.

    Args:
        now: Unix timestamp.

    Returns:
        The day as ``YYYY-MM-DD``.
    """
    return datetime.fromtimestamp(now, tz=UTC).strftime("%Y-%m-%d")


def next_midnight(now: float) -> float:
    """Return the Unix timestamp of the next UTC midnight.

    A daily counter that resets on a wall-clock boundary can state its reset time without storing
    one, and states the same time to everybody.

    Args:
        now: Unix timestamp.

    Returns:
        When the current UTC day ends.
    """
    moment = datetime.fromtimestamp(now, tz=UTC)
    midnight = (moment + timedelta(days=1)).replace(hour=0, minute=0, second=0, microsecond=0)
    return midnight.timestamp()


@dataclass(frozen=True)
class QuotaLimits:
    """The ceilings, all configurable.

    Attributes:
        user_window_seconds: Length of the per-user short window.
        user_per_window: Questions one user may ask inside a short window.
        user_per_day: Questions one user may ask in a UTC day.
        global_per_day: Questions the whole bot may serve in a UTC day.
    """

    user_window_seconds: float = 60.0
    user_per_window: int = 3
    user_per_day: int = 15
    global_per_day: int = 200


@dataclass
class QuotaDecision:
    """Whether a question may be asked, and what to tell the user when it may not.

    Attributes:
        allowed: Whether the question goes through.
        reason: Which ceiling refused it — ``"user-window"``, ``"user-day"``, ``"global-day"`` or
            ``"degraded"``. ``None`` when allowed. The value is the suffix of the ``quota.*`` text
            key, so a reason with no sentence is a failing test rather than a blank message.
        reset_at: Unix timestamp at which the ceiling lifts. ``None`` when allowed.
        limit: The ceiling that refused, for the sentence that names it.
    """

    allowed: bool
    reason: str | None = None
    reset_at: float | None = None
    limit: int = 0


@dataclass
class _UserCounters:
    """One user's counters.

    Attributes:
        window_start: When the current short window opened.
        window_count: Questions asked inside it.
        day: The UTC day *day_count* refers to.
        day_count: Questions asked that day.
    """

    window_start: float = 0.0
    window_count: int = 0
    day: str = ""
    day_count: int = 0


@dataclass
class _State:
    """Everything the counters need to survive a restart.

    Attributes:
        day: The UTC day *global_count* refers to.
        global_count: Questions the bot has served that day.
        users: Per-user counters, keyed by Discord user id.
    """

    day: str = ""
    global_count: int = 0
    users: dict[str, _UserCounters] = field(default_factory=dict)


class QuotaStore:
    """Reads and writes the counters as one small JSON document.

    A whole-file rewrite rather than an append log: the document is a few kilobytes even for a busy
    day, and the failure mode of a truncated append — a counter that reads as zero — is exactly the
    one this module must not have.
    """

    def __init__(self, path: Path) -> None:
        """Initialize the store.

        Args:
            path: File the counters are kept in.
        """
        self.path = path

    def load(self) -> _State:
        """Read the counters back.

        Returns:
            The stored state.

        Raises:
            OSError: When the file exists but cannot be read.
            ValueError: When it can be read but does not describe counters this version understands.
                Both are deliberately loud: the caller turns either into degraded mode, and a
                corrupt file silently read as "no counters" would be a full quota reset.
        """
        if not self.path.exists():
            return _State(day="", global_count=0, users={})
        document = json.loads(self.path.read_text(encoding="utf-8"))
        if not isinstance(document, dict) or document.get("version") != STATE_VERSION:
            raise ValueError(f"unsupported quota state version: {document.get('version') if isinstance(document, dict) else type(document).__name__}")
        users: dict[str, _UserCounters] = {}
        for user_id, raw in (document.get("users") or {}).items():
            users[str(user_id)] = _UserCounters(
                window_start=float(raw.get("window_start", 0.0)),
                window_count=int(raw.get("window_count", 0)),
                day=str(raw.get("day", "")),
                day_count=int(raw.get("day_count", 0)),
            )
        return _State(
            day=str(document.get("day", "")),
            global_count=int(document.get("global_count", 0)),
            users=users,
        )

    def save(self, state: _State) -> None:
        """Write the counters.

        Written to a temporary file in the same directory and renamed over the target, so a crash
        mid-write leaves the previous counters rather than a truncated file — which would read as a
        quota reset on the next start.

        Args:
            state: The state to persist.

        Raises:
            OSError: When the file cannot be written. The caller turns that into degraded mode
                rather than serving with counters nobody is keeping.
        """
        document: dict[str, Any] = {
            "version": STATE_VERSION,
            "day": state.day,
            "global_count": state.global_count,
            "users": {
                user_id: {
                    "window_start": counters.window_start,
                    "window_count": counters.window_count,
                    "day": counters.day,
                    "day_count": counters.day_count,
                }
                for user_id, counters in state.users.items()
            },
        }
        self.path.parent.mkdir(parents=True, exist_ok=True)
        handle, temporary = tempfile.mkstemp(dir=str(self.path.parent), prefix=".quota-", suffix=".json")
        try:
            with os.fdopen(handle, "w", encoding="utf-8", newline="\n") as stream:
                json.dump(document, stream, ensure_ascii=False)
            os.replace(temporary, self.path)
        except BaseException:
            Path(temporary).unlink(missing_ok=True)
            raise


class QuotaKeeper:
    """Decides whether a question may be asked, and remembers that it was."""

    def __init__(
        self,
        limits: QuotaLimits,
        store: QuotaStore | None = None,
        *,
        clock: Callable[[], float] | None = None,
        logger: Logger | None = None,
    ) -> None:
        """Load the counters, or start degraded when they cannot be loaded.

        Args:
            limits: The ceilings to enforce.
            store: Where the counters live. ``None`` means no persistence was configured, which is
                itself a reason to run degraded: counters nobody keeps are counters a restart wipes.
            clock: Source of Unix timestamps; defaults to :func:`time.time`.
            logger: Logger to use; defaults to the service's ``quota`` logger.
        """
        self.limits = limits
        self._store = store
        self._clock: Callable[[], float] = clock or time.time
        self._logger = logger or get_logger("quota")
        self._degraded_window_start = 0.0
        self._degraded_count = 0
        self._state = _State()
        self.degraded = False
        self.degraded_reason: str | None = None

        if store is None:
            self._degrade("no quota state file is configured")
            return
        try:
            self._state = store.load()
        except (OSError, ValueError, TypeError, KeyError) as error:
            self._degrade(f"the quota state could not be read: {type(error).__name__}: {error}")

    def _degrade(self, reason: str) -> None:
        """Drop to the stricter in-memory ceiling and say so, once.

        Args:
            reason: Why persistence is unusable.
        """
        if self.degraded:
            return
        self.degraded = True
        self.degraded_reason = reason
        self._logger.error(
            "quota counters are not being kept; answering at a reduced rate",
            extra={"event": "quota.degraded", "reason": reason, "per_window": DEGRADED_PER_WINDOW},
        )

    def snapshot(self) -> dict[str, Any]:
        """Return the counters as ``/status`` reports them.

        Returns:
            The day, the bot's spend against its ceiling, how many users are tracked, and whether
            persistence is working.
        """
        return {
            "day": self._state.day,
            "global_count": self._state.global_count,
            "global_per_day": self.limits.global_per_day,
            "tracked_users": len(self._state.users),
            "degraded": self.degraded,
            "degraded_reason": self.degraded_reason,
        }

    def check_and_consume(self, user_id: str) -> QuotaDecision:
        """Decide whether *user_id* may ask a question now, counting it when they may.

        Args:
            user_id: The Discord user id.

        Returns:
            The decision. A refusal carries the ceiling that refused and when it lifts, so the bot
            can say both.
        """
        now = self._clock()
        if self.degraded:
            return self._degraded_decision(now)

        today = _day_of(now)
        if self._state.day != today:
            # A new UTC day: the bot's own counter rolls over, and yesterday's users are forgotten
            # rather than carried — their daily counters would be stale and their windows expired.
            self._state.day = today
            self._state.global_count = 0
            self._state.users.clear()

        if self._state.global_count >= self.limits.global_per_day:
            return QuotaDecision(False, "global-day", next_midnight(now), self.limits.global_per_day)

        counters = self._state.users.setdefault(user_id, _UserCounters())
        if counters.day != today:
            counters.day = today
            counters.day_count = 0
        if now - counters.window_start >= self.limits.user_window_seconds:
            counters.window_start = now
            counters.window_count = 0

        if counters.day_count >= self.limits.user_per_day:
            return QuotaDecision(False, "user-day", next_midnight(now), self.limits.user_per_day)
        if counters.window_count >= self.limits.user_per_window:
            reset = counters.window_start + self.limits.user_window_seconds
            return QuotaDecision(False, "user-window", reset, self.limits.user_per_window)

        counters.window_count += 1
        counters.day_count += 1
        self._state.global_count += 1
        self._persist(now)
        return QuotaDecision(True)

    def _persist(self, now: float) -> QuotaDecision | None:
        """Write the counters, degrading when the write fails.

        Args:
            now: The current timestamp, used to open the degraded window.

        Returns:
            ``None``; the return type exists so a caller can chain on a future failure decision.
        """
        if self._store is None:
            return None
        try:
            self._store.save(self._state)
        except OSError as error:
            # The question already went through — refusing it now would be a lie, it was counted.
            # What must not happen is the *next* one going through on counters nobody is keeping.
            self._degrade(f"the quota state could not be written: {type(error).__name__}: {error}")
            self._degraded_window_start = now
        return None

    def _degraded_decision(self, now: float) -> QuotaDecision:
        """Apply the stricter in-memory ceiling.

        Args:
            now: The current timestamp.

        Returns:
            The decision, refusing with ``"degraded"`` once the window's tiny allowance is spent.
        """
        if now - self._degraded_window_start >= self.limits.user_window_seconds:
            self._degraded_window_start = now
            self._degraded_count = 0
        if self._degraded_count >= DEGRADED_PER_WINDOW:
            reset = self._degraded_window_start + self.limits.user_window_seconds
            return QuotaDecision(False, "degraded", reset, DEGRADED_PER_WINDOW)
        self._degraded_count += 1
        return QuotaDecision(True)
