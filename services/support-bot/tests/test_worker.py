"""The Worker contract, exercised over a fake session rather than described in a comment.

What is asserted here is the wire: the headers that select and prove the client mode, the per-user
subject that stops a whole Discord sharing one IP's allowance, and the mapping from every status the
Worker can answer with to a failure the bot can put into a sentence.
"""

from __future__ import annotations

import json
import unittest
from collections.abc import AsyncIterator, Sequence
from typing import Any

import aiohttp

from veaf_support_bot.worker import (
    DEFAULT_TIMEOUT_SECONDS,
    MAX_SUBJECT_CHARS,
    FailureKind,
    WorkerClient,
    WorkerFailure,
)


class _FakeContent:
    """An async iterator over pre-baked SSE lines."""

    def __init__(self, lines: Sequence[bytes]) -> None:
        """Initialize the content.

        Args:
            lines: The lines the stream yields.
        """
        self._lines = list(lines)

    def __aiter__(self) -> AsyncIterator[bytes]:
        """Return the iterator.

        Returns:
            Self.
        """
        return self._iterate()

    async def _iterate(self) -> AsyncIterator[bytes]:
        """Yield each line.

        Yields:
            The lines.
        """
        for line in self._lines:
            yield line


class _FakeResponse:
    """A minimal ``aiohttp`` response."""

    def __init__(self, status: int, lines: Sequence[bytes]) -> None:
        """Initialize the response.

        Args:
            status: The HTTP status.
            lines: The SSE lines.
        """
        self.status = status
        self.content = _FakeContent(lines)

    async def __aenter__(self) -> _FakeResponse:
        """Enter the context.

        Returns:
            Self.
        """
        return self

    async def __aexit__(self, *_: Any) -> None:
        """Leave the context."""


class _FakeSession:
    """A session that records the one request made through it."""

    def __init__(self, status: int = 200, lines: Sequence[bytes] = (), error: Exception | None = None) -> None:
        """Initialize the session.

        Args:
            status: The status to answer with.
            lines: The SSE lines to answer with.
            error: Raised by ``post`` instead of answering, when given.
        """
        self.status = status
        self.lines = list(lines)
        self.error = error
        self.requests: list[dict[str, Any]] = []

    async def __aenter__(self) -> _FakeSession:
        """Enter the context.

        Returns:
            Self.
        """
        return self

    async def __aexit__(self, *_: Any) -> None:
        """Leave the context."""

    def post(self, url: str, *, json: Any = None, headers: Any = None) -> _FakeResponse:
        """Record and answer a request.

        Args:
            url: The endpoint.
            json: The body.
            headers: The request headers.

        Returns:
            The canned response.

        Raises:
            Exception: The one the fake was built with.
        """
        self.requests.append({"url": url, "json": json, "headers": dict(headers or {})})
        if self.error is not None:
            raise self.error
        return _FakeResponse(self.status, self.lines)


def _client(session: _FakeSession, secret: str = "s3cret") -> WorkerClient:
    """Build a client over a fake session.

    Args:
        session: The session to use.
        secret: The ``X-VEAF-Auth`` value.

    Returns:
        The client.
    """
    return WorkerClient(
        "https://worker.test/chat",
        "discord",
        secret,
        session_factory=lambda **_: session,
    )


def _sse(*payloads: Any) -> list[bytes]:
    """Render payloads as SSE lines.

    Args:
        *payloads: JSON-serialisable payloads.

    Returns:
        The lines, terminated by ``[DONE]``.
    """
    lines = [f"data: {json.dumps(payload)}\n".encode() for payload in payloads]
    return [*lines, b"data: [DONE]\n"]


async def _collect(client: WorkerClient, subject: str = "42") -> str:
    """Run a stream to completion.

    Args:
        client: The client.
        subject: The rate-limit subject.

    Returns:
        The concatenated fragments.
    """
    return "".join([fragment async for fragment in client.stream([{"role": "user", "content": "q"}], "fr", subject)])


class TestTheExchangeBudgetIsReadable(unittest.TestCase):
    """The consumer has to hold the same budget, so it has to be able to read it.

    ``ClientTimeout(total=...)`` only bounds what aiohttp waits for: measured against a real local
    server, a stream with a slow consumer ran 12.25 s on a 2.0 s budget while a hanging server was
    cut off at 2.00 s. The bound over the consuming loop lives in ``AskHandler._collect``, and it
    reads this rather than keeping a second number that would drift.
    """

    def test_it_reports_the_budget_it_was_built_with(self) -> None:
        self.assertEqual(_client(_FakeSession(200, []), secret="s").timeout, DEFAULT_TIMEOUT_SECONDS)

    def test_an_overridden_budget_is_the_one_reported(self) -> None:
        client = WorkerClient("https://worker.test/chat", "discord", "s", timeout=3.5)

        self.assertEqual(client.timeout, 3.5)


class TestTheRequest(unittest.IsolatedAsyncioTestCase):
    async def test_it_declares_the_discord_client_mode(self) -> None:
        session = _FakeSession(200, _sse({"text": "ok"}))

        await _collect(_client(session))

        self.assertEqual(session.requests[0]["headers"]["X-VEAF-Client"], "discord")

    async def test_it_presents_the_secret_the_worker_requires(self) -> None:
        """The ``discord`` mode is refused outright while the Worker's Secret is unset."""
        session = _FakeSession(200, _sse({"text": "ok"}))

        await _collect(_client(session))

        self.assertEqual(session.requests[0]["headers"]["X-VEAF-Auth"], "s3cret")

    async def test_no_secret_means_no_header_rather_than_an_empty_one(self) -> None:
        session = _FakeSession(200, _sse({"text": "ok"}))

        await _collect(_client(session, secret=""))

        self.assertNotIn("X-VEAF-Auth", session.requests[0]["headers"])

    async def test_it_carries_the_per_user_subject(self) -> None:
        """Without it a whole Discord is one IP, hence one user's daily allowance."""
        session = _FakeSession(200, _sse({"text": "ok"}))

        await _collect(_client(session), subject="user-7")

        self.assertEqual(session.requests[0]["json"]["subject"], "user-7")

    async def test_a_long_subject_is_truncated_here_not_silently_by_the_worker(self) -> None:
        """The Worker slices at 64; two users sharing a prefix would land on one counter."""
        session = _FakeSession(200, _sse({"text": "ok"}))

        await _collect(_client(session), subject="x" * 200)

        self.assertEqual(len(session.requests[0]["json"]["subject"]), MAX_SUBJECT_CHARS)


class TestTheStream(unittest.IsolatedAsyncioTestCase):
    async def test_fragments_arrive_in_order(self) -> None:
        session = _FakeSession(200, _sse({"text": "Bon"}, {"text": "jour"}))

        self.assertEqual(await _collect(_client(session)), "Bonjour")

    async def test_the_done_sentinel_is_not_answer_text(self) -> None:
        session = _FakeSession(200, [b"data: [DONE]\n", *_sse({"text": "x"})])

        self.assertEqual(await _collect(_client(session)), "x")

    async def test_a_malformed_frame_does_not_end_a_good_stream(self) -> None:
        session = _FakeSession(200, [b"data: {oops\n", *_sse({"text": "x"})])

        self.assertEqual(await _collect(_client(session)), "x")

    async def test_keep_alive_comments_and_blank_lines_are_ignored(self) -> None:
        session = _FakeSession(200, [b": keep-alive\n", b"\n", *_sse({"text": "x"})])

        self.assertEqual(await _collect(_client(session)), "x")


class TestFailures(unittest.IsolatedAsyncioTestCase):
    async def _kind(self, session: _FakeSession) -> FailureKind:
        """Run a stream expected to fail and return its kind.

        Args:
            session: The session to run against.

        Returns:
            The failure kind.
        """
        with self.assertRaises(WorkerFailure) as raised:
            await _collect(_client(session))
        return raised.exception.kind

    async def test_a_429_is_a_rate_limit_not_a_generic_outage(self) -> None:
        self.assertEqual(await self._kind(_FakeSession(429)), FailureKind.RATE_LIMITED)

    async def test_a_403_is_the_refused_client_mode(self) -> None:
        self.assertEqual(await self._kind(_FakeSession(403)), FailureKind.FORBIDDEN)

    async def test_a_502_is_an_outage(self) -> None:
        self.assertEqual(await self._kind(_FakeSession(502)), FailureKind.UNAVAILABLE)

    async def test_an_unreachable_worker_is_an_outage(self) -> None:
        session = _FakeSession(error=aiohttp.ClientConnectionError("no route"))

        self.assertEqual(await self._kind(session), FailureKind.UNAVAILABLE)

    async def test_a_timeout_is_its_own_kind(self) -> None:
        self.assertEqual(await self._kind(_FakeSession(error=TimeoutError())), FailureKind.TIMEOUT)

    async def test_a_stream_that_carries_no_text_is_a_failure_not_an_empty_answer(self) -> None:
        """An empty message posted as an answer is the silent failure this service must not have."""
        self.assertEqual(await self._kind(_FakeSession(200, [b"data: [DONE]\n"])), FailureKind.EMPTY)

    async def test_an_error_payload_inside_a_200_stream_is_still_a_failure(self) -> None:
        session = _FakeSession(200, _sse({"error": "Assistant momentanément indisponible."}))

        self.assertEqual(await self._kind(session), FailureKind.UNAVAILABLE)

    async def test_the_worker_s_own_message_is_not_shown_to_the_user(self) -> None:
        """It only knows the language it was told; the service has both and renders its own."""
        session = _FakeSession(200, _sse({"error": "Assistant momentanément indisponible."}))

        with self.assertRaises(WorkerFailure) as raised:
            await _collect(_client(session))

        self.assertNotEqual(raised.exception.detail, "")
        self.assertIn("indisponible", raised.exception.detail)


if __name__ == "__main__":
    unittest.main()
