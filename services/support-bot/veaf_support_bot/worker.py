"""Talking to the documentation chatbot Worker, and turning its failures into sentences.

The Worker (``poc/doc-chatbot/worker``) owns the Gemini key, runs the retrieval and streams the
answer back as Server-Sent Events. This module is the service's half of that contract:

* it declares itself with ``X-VEAF-Client: discord`` and proves it with ``X-VEAF-Auth``. That mode
  is refused outright while the Worker's ``DISCORD_CLIENT_SECRET`` is unset — it is groundwork, not
  an open door — so :data:`FailureKind.FORBIDDEN` is the *expected* answer until that Secret is
  posted, and it must read as a deployment problem rather than as a broken bot;
* it passes a ``subject``, which the Worker uses as the rate-limit key instead of the caller's IP. A
  whole Discord is one IP, so without it the server would share a single user's daily allowance.
  The service's own per-user quota (:mod:`veaf_support_bot.quota`) is the primary guard; this is the
  same decision enforced a second time, one layer up;
* every way the exchange can fail becomes one of :class:`FailureKind`, which
  :mod:`veaf_support_bot.texts` renders as a human sentence. A stack trace in a Discord thread is
  not an error message, and silence is worse: it is indistinguishable from a dead bot.

``aiohttp`` rather than ``requests``: the service is asyncio end to end, and the Discord library
already brings it in, so it costs no new dependency.
"""

from __future__ import annotations

import json
from collections.abc import AsyncIterator, Mapping, Sequence
from enum import StrEnum
from typing import Any, Final

import aiohttp

#: How long the whole exchange may take. Comfortably above the Worker's own generation time, and
#: well under the fifteen minutes Discord gives a deferred interaction.
#:
#: ``ClientTimeout(total=...)`` alone does **not** hold this: aiohttp only consults its timer while
#: it is waiting on the socket, so once bytes are buffered a slow *consumer* — one awaiting a Discord
#: edit that is being rate-limited — runs unbounded. The budget is therefore also applied around the
#: consuming loop, in :meth:`~veaf_support_bot.ask.AskHandler._collect`.
DEFAULT_TIMEOUT_SECONDS: Final = 60.0

#: Longest question forwarded. Well under the Worker's 64 KiB body ceiling for this client; the
#: binding constraint is the other end, where the question is echoed into a Discord message that
#: cannot exceed 2000 characters. A question longer than this is a paste, and retrieval does nothing
#: useful with a paste.
MAX_QUESTION_CHARS: Final = 1000

#: Longest rate-limit subject the Worker keeps — it truncates at 64 characters, and a silently
#: truncated subject would key two users to the same counter.
MAX_SUBJECT_CHARS: Final = 64


class FailureKind(StrEnum):
    """Why an exchange with the Worker did not produce an answer.

    Each value maps to one ``ask.error.*`` key in :mod:`veaf_support_bot.texts`, so adding a kind
    without adding its sentence is a failing test rather than a blank message.
    """

    #: The Worker, or the model behind it, is out of quota. The user should simply retry later.
    RATE_LIMITED = "rate_limited"
    #: The exchange took longer than :data:`DEFAULT_TIMEOUT_SECONDS`.
    TIMEOUT = "timeout"
    #: The Worker refused this client mode: the ``discord`` Secret is unset or does not match. An
    #: operator problem, never something the user can retry their way out of.
    FORBIDDEN = "forbidden"
    #: Anything else — unreachable, a 5xx, a malformed stream.
    UNAVAILABLE = "unavailable"
    #: The stream completed carrying no text at all.
    EMPTY = "empty"


class WorkerFailure(RuntimeError):
    """An exchange with the Worker that produced no answer.

    Attributes:
        kind: Which failure it was, so the caller renders the matching sentence.
        detail: A short technical description for the log line. **Never shown to a user.**
    """

    def __init__(self, kind: FailureKind, detail: str) -> None:
        """Initialize the failure.

        Args:
            kind: The failure category.
            detail: Technical description, for the log only.
        """
        super().__init__(f"{kind.value}: {detail}")
        self.kind = kind
        self.detail = detail


def _classify(status: int) -> FailureKind:
    """Map an HTTP status from the Worker to a failure kind.

    Args:
        status: The response status code.

    Returns:
        The matching :class:`FailureKind`.
    """
    if status == 429:
        return FailureKind.RATE_LIMITED
    if status == 403:
        return FailureKind.FORBIDDEN
    return FailureKind.UNAVAILABLE


class WorkerClient:
    """Streams answers out of the documentation chatbot Worker."""

    def __init__(
        self,
        endpoint: str,
        client: str,
        secret: str,
        *,
        timeout: float = DEFAULT_TIMEOUT_SECONDS,
        session_factory: Any | None = None,
    ) -> None:
        """Initialize the client.

        Args:
            endpoint: The Worker ``/chat`` URL.
            client: Value of the ``X-VEAF-Client`` header, normally ``"discord"``.
            secret: Value of the ``X-VEAF-Auth`` header. May be empty, in which case the Worker
                refuses the exchange with a 403 — which is the honest outcome, reported as such.
            timeout: Seconds granted to the whole exchange.
            session_factory: Callable returning an ``aiohttp.ClientSession``; injected by the tests
                so the streaming path is exercised without a network.
        """
        self._endpoint = endpoint
        self._client = client
        self._secret = secret
        self._timeout = timeout
        self._session_factory = session_factory or aiohttp.ClientSession

    @property
    def timeout(self) -> float:
        """Return the seconds granted to one exchange.

        Read by the caller rather than kept as a second number of its own: ``ClientTimeout`` only
        bounds what this client *waits* for, and the consumer of :meth:`stream` has to hold the same
        budget over its own work — see :meth:`~veaf_support_bot.ask.AskHandler._collect`.

        Returns:
            The budget in seconds.
        """
        return self._timeout

    @property
    def headers(self) -> dict[str, str]:
        """Return the headers every request carries.

        The auth header is omitted rather than sent empty when there is no secret: an empty value is
        a *presented* credential that fails to match, and the distinction shows up in a Worker log.

        Returns:
            The request headers.
        """
        headers = {"Content-Type": "application/json", "X-VEAF-Client": self._client}
        if self._secret:
            headers["X-VEAF-Auth"] = self._secret
        return headers

    def body(self, messages: Sequence[Mapping[str, str]], lang: str, subject: str) -> dict[str, Any]:
        """Build the request payload.

        Args:
            messages: The conversation turns, oldest first.
            lang: ``"fr"`` or ``"en"``.
            subject: Per-user rate-limit subject. Truncated here rather than by the Worker, so two
                users with a long shared prefix cannot collapse onto one counter unnoticed.

        Returns:
            The JSON body.
        """
        return {"lang": lang, "messages": list(messages), "subject": subject[:MAX_SUBJECT_CHARS]}

    async def stream(self, messages: Sequence[Mapping[str, str]], lang: str, subject: str) -> AsyncIterator[str]:
        """Stream the answer to a conversation, one text fragment at a time.

        Args:
            messages: The conversation turns, oldest first; the last user turn is what the Worker
                embeds for retrieval.
            lang: ``"fr"`` or ``"en"``.
            subject: Per-user rate-limit subject.

        Yields:
            Answer fragments in order.

        Raises:
            WorkerFailure: When the exchange produced no answer, whatever the reason.
        """
        timeout = aiohttp.ClientTimeout(total=self._timeout)
        emitted = False
        try:
            async with self._session_factory(timeout=timeout) as session:
                post = session.post(
                    self._endpoint,
                    json=self.body(messages, lang, subject),
                    headers=self.headers,
                )
                async with post as response:
                    if response.status != 200:
                        raise WorkerFailure(_classify(response.status), f"HTTP {response.status}")
                    async for raw in response.content:
                        for fragment in _fragments(raw):
                            emitted = True
                            yield fragment
        except WorkerFailure:
            raise
        except TimeoutError as error:
            raise WorkerFailure(FailureKind.TIMEOUT, str(error) or "timed out") from error
        except aiohttp.ClientError as error:
            raise WorkerFailure(FailureKind.UNAVAILABLE, f"{type(error).__name__}: {error}") from error

        if not emitted:
            raise WorkerFailure(FailureKind.EMPTY, "the stream carried no text")


def _fragments(raw: bytes) -> list[str]:
    """Decode one SSE line into the answer fragments it carries.

    Args:
        raw: One line off the wire, newline included.

    Returns:
        The text fragments the line carries; empty for a comment, a blank line or ``[DONE]``.

    Raises:
        WorkerFailure: When the line carries the Worker's own error payload. The Worker sends its
            localized message there; it is deliberately **not** shown to the user, because the
            service already has both languages and the Worker only knows the one it was told.
    """
    line = raw.decode("utf-8", errors="replace").strip()
    if not line.startswith("data:"):
        return []
    payload = line[len("data:") :].strip()
    if not payload or payload == "[DONE]":
        return []
    try:
        data = json.loads(payload)
    except ValueError:
        # A payload that is not JSON is noise, not an answer: skipping it keeps a malformed frame
        # from ending an otherwise good stream.
        return []
    if not isinstance(data, dict):
        return []
    if data.get("error"):
        # The Worker sends this with a 429 too, but also inside a 200 stream when generation fails
        # mid-flight. Reaching here on a 200 means the failure was not visible in the status.
        raise WorkerFailure(FailureKind.UNAVAILABLE, str(data["error"])[:200])
    text = data.get("text")
    return [text] if isinstance(text, str) and text else []
