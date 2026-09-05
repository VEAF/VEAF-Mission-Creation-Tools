"""Stand-ins for Discord and the Worker, built to make the *order* of calls assertable.

The repository has shipped four bugs green because the tests called the handler and never the thing
that wires it up. So the fakes here record a transcript rather than answering questions in
isolation: what is asserted is the sequence — deferred first, refusal before any thread, the final
edit last — not merely that each step can be performed.
"""

from __future__ import annotations

from collections.abc import AsyncIterator, Sequence
from typing import Any

from veaf_support_bot.worker import WorkerFailure


class RecordingExchange:
    """An :class:`~veaf_support_bot.ask.Exchange` that writes down everything asked of it.

    Attributes:
        calls: The transcript, as ``(method, argument)`` pairs in the order they happened.
        thread_allowed: Whether :meth:`open_thread` succeeds.
    """

    def __init__(self, *, thread_allowed: bool = True) -> None:
        """Initialize the recorder.

        Args:
            thread_allowed: Whether opening a thread is permitted, so the degraded path is testable.
        """
        self.calls: list[tuple[str, str]] = []
        self.thread_allowed = thread_allowed

    async def defer(self) -> None:
        """Record the deferred acknowledgement."""
        self.calls.append(("defer", ""))

    async def announce(self, content: str) -> None:
        """Record the visible question message.

        Args:
            content: The announced content.
        """
        self.calls.append(("announce", content))

    async def open_thread(self, name: str) -> bool:
        """Record a thread creation attempt.

        Args:
            name: The thread name.

        Returns:
            :attr:`thread_allowed`.
        """
        self.calls.append(("open_thread", name))
        return self.thread_allowed

    async def post(self, content: str) -> None:
        """Record the first message.

        Args:
            content: The message content.
        """
        self.calls.append(("post", content))

    async def edit(self, content: str) -> None:
        """Record an edit.

        Args:
            content: The new content.
        """
        self.calls.append(("edit", content))

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
    """

    def __init__(
        self,
        fragments: Sequence[str] = (),
        failure: WorkerFailure | None = None,
        *,
        fail_after: int | None = None,
    ) -> None:
        """Initialize the fake.

        Args:
            fragments: What the stream yields, in order.
            failure: Raised instead of finishing, when given.
            fail_after: Yield this many fragments before raising *failure*; ``None`` raises before
                any fragment.
        """
        self._fragments = list(fragments)
        self._failure = failure
        self._fail_after = fail_after
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
            yield fragment
        if self._failure is not None:
            raise self._failure
