"""Stand-ins for Discord and the Worker, built to make the *order* of calls assertable.

The repository has shipped four bugs green because the tests called the handler and never the thing
that wires it up. So the fakes here record a transcript rather than answering questions in
isolation: what is asserted is the sequence — deferred first, refusal before any thread, the final
edit last — not merely that each step can be performed.
"""

from __future__ import annotations

import asyncio
from collections.abc import AsyncIterator, Sequence
from typing import Any

from veaf_support_bot.worker import DEFAULT_TIMEOUT_SECONDS, WorkerFailure


class RecordingExchange:
    """An :class:`~veaf_support_bot.ask.Exchange` that writes down everything asked of it.

    Attributes:
        calls: The transcript, as ``(method, argument)`` pairs in the order they happened.
        thread_allowed: Whether :meth:`open_thread` succeeds.
    """

    def __init__(self, *, thread_allowed: bool = True, fails_on: Sequence[str] = ()) -> None:
        """Initialize the recorder.

        Args:
            thread_allowed: Whether opening a thread is permitted, so the degraded path is testable.
            fails_on: Method names that raise ``RuntimeError`` after recording the call. Discord
                answering 500 to an ``announce`` or a ``post`` is not a modelled failure anywhere in
                the exchange, and once the interaction is deferred an escape leaves the reader on a
                placeholder forever — so it has to be reachable from a test.
        """
        self.calls: list[tuple[str, str]] = []
        self.thread_allowed = thread_allowed
        self._fails_on = set(fails_on)

    def _record(self, method: str, content: str) -> None:
        """Write one call down, and fail it when the test asked for that.

        Args:
            method: The method called.
            content: Its argument.

        Raises:
            RuntimeError: When *method* is one of the methods this recorder was told to fail.
        """
        self.calls.append((method, content))
        if method in self._fails_on:
            raise RuntimeError(f"Discord refused {method}")

    async def defer(self) -> None:
        """Record the deferred acknowledgement."""
        self._record("defer", "")

    async def announce(self, content: str) -> None:
        """Record the visible question message.

        Args:
            content: The announced content.
        """
        self._record("announce", content)

    async def open_thread(self, name: str) -> bool:
        """Record a thread creation attempt.

        Args:
            name: The thread name.

        Returns:
            :attr:`thread_allowed`.
        """
        self._record("open_thread", name)
        return self.thread_allowed

    async def post(self, content: str) -> None:
        """Record the first message.

        Args:
            content: The message content.
        """
        self._record("post", content)

    async def edit(self, content: str) -> None:
        """Record an edit.

        Args:
            content: The new content.
        """
        self._record("edit", content)

    @property
    def steps(self) -> list[str]:
        """Return only the method names, in order.

        Returns:
            The transcript's method names.
        """
        return [name for name, _ in self.calls]

    def contents(self, method: str) -> list[str]:
        """Return every argument passed to one method, in order.

        Args:
            method: The method name.

        Returns:
            The recorded arguments.
        """
        return [value for name, value in self.calls if name == method]

    @property
    def final(self) -> str:
        """Return the last content the user would be left looking at.

        Returns:
            The content of the last call that wrote a message.

        Raises:
            AssertionError: When nothing was ever written — which is the silent-bot failure, and it
                must fail a test rather than pass as an empty string.
        """
        written = [value for name, value in self.calls if name in ("announce", "post", "edit")]
        assert written, "the exchange wrote nothing at all"
        return written[-1]


class FakeWorker:
    """A :class:`~veaf_support_bot.worker.WorkerClient` stand-in with a scripted answer.

    Attributes:
        seen: The arguments of each :meth:`stream` call, so a test can assert the question reached
            the Worker unmodified and the quota subject was the Discord user id.
        timeout: The exchange budget, read by the handler — the real client exposes the same, and the
            handler applies it around its own consuming loop.
    """

    def __init__(
        self,
        fragments: Sequence[str] = (),
        failure: WorkerFailure | None = None,
        *,
        fail_after: int | None = None,
        timeout: float = DEFAULT_TIMEOUT_SECONDS,
        pause: float = 0.0,
    ) -> None:
        """Initialize the fake.

        Args:
            fragments: What the stream yields, in order.
            failure: Raised instead of finishing, when given.
            fail_after: Yield this many fragments before raising *failure*; ``None`` raises before
                any fragment.
            timeout: The exchange budget the handler is to hold.
            pause: Seconds slept before each fragment, so a test can make the stream outlast a
                budget without the consumer being the slow side.
        """
        self._fragments = list(fragments)
        self._failure = failure
        self._fail_after = fail_after
        self._pause = pause
        self.timeout = timeout
        self.seen: list[dict[str, Any]] = []

    async def stream(self, messages: Sequence[Any], lang: str, subject: str) -> AsyncIterator[str]:
        """Yield the scripted fragments.

        Args:
            messages: The conversation turns.
            lang: The language asked for.
            subject: The rate-limit subject.

        Yields:
            The scripted fragments.

        Raises:
            WorkerFailure: When the fake was built with one.
        """
        self.seen.append({"messages": list(messages), "lang": lang, "subject": subject})
        if self._failure is not None and self._fail_after is None:
            raise self._failure
        for index, fragment in enumerate(self._fragments):
            if self._failure is not None and self._fail_after is not None and index >= self._fail_after:
                raise self._failure
            if self._pause:
                await asyncio.sleep(self._pause)
            yield fragment
        if self._failure is not None:
            raise self._failure
