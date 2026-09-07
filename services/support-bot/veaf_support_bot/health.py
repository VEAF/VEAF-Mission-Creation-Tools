"""Liveness and readiness: how anyone finds out the bot has died.

A self-hosted Discord bot fails silently. The process is up, the container is *running*, and the
only symptom is that nobody gets an answer — often for days. The VEAF has no supervision for this
yet, so the service has to make itself checkable with the two things any supervisor can already
consume:

* an **HTTP endpoint** — ``/healthz`` (the process loop is alive), ``/readyz`` (it can actually
  serve), ``/status`` (the full picture, for a human). The container image wires ``/readyz`` into a
  Docker ``HEALTHCHECK``; an external uptime monitor can poll the same URL.
* a **heartbeat log line** at a fixed interval, so a log-based alert ("nothing from the bot for 10
  minutes") works even where nothing polls an endpoint.

The HTTP layer is deliberately hand-rolled on :mod:`asyncio`: three read-only routes returning JSON
do not justify a web framework in a service that otherwise has zero runtime dependencies.
"""

from __future__ import annotations

import asyncio
import json
import time
from collections.abc import Callable, Mapping
from datetime import UTC, datetime
from logging import Logger
from typing import Any, Final

from veaf_support_bot.logging_setup import get_logger

#: Longest request head accepted, and longest wait for **the whole of it**. A health endpoint talks
#: to a monitor, not to the internet; anything larger or slower than this is not a health check.
#: The budget is deliberately not per line: 64 lines at 5 s each would be a five-minute connection,
#: and :meth:`HealthServer.stop` waits for connections.
_MAX_HEADER_LINES: Final = 64
_REQUEST_TIMEOUT_SECONDS: Final = 5.0
_STREAM_LIMIT: Final = 8192

#: The only methods a read-only health endpoint answers; also the value of its ``Allow`` header.
_ALLOWED_METHODS: Final = ("GET", "HEAD")

#: Default budget :meth:`HealthServer.stop` grants the connections still open. The service overrides
#: it with what is left of ``SUPPORT_BOT_SHUTDOWN_GRACE_SECONDS``.
DEFAULT_CLOSE_TIMEOUT_SECONDS: Final = 2.0

#: Grace given to the event loop to notice the aborted transports. Not a wait for a client: the
#: sockets are already gone by then.
_ABORT_TIMEOUT_SECONDS: Final = 1.0


def _iso(timestamp: float) -> str:
    """Return a UTC ISO-8601 rendering of a Unix timestamp.

    Args:
        timestamp: Seconds since the epoch.

    Returns:
        The timestamp in ISO-8601, millisecond precision, UTC.
    """
    return datetime.fromtimestamp(timestamp, tz=UTC).isoformat(timespec="milliseconds")


class ServiceState:
    """The service's own view of whether it is working.

    Held by the service and read by the health endpoints. Deliberately a plain object with an
    injectable clock rather than a global, so the tests assert on real transitions.
    """

    def __init__(self, *, version: str, dry_run: bool = False, clock: Callable[[], float] | None = None) -> None:
        """Initialize the state as *started but not ready*.

        Args:
            version: The service version, reported by ``/status``.
            dry_run: Whether the process runs without touching the outside world.
            clock: Source of Unix timestamps; defaults to :func:`time.time`.
        """
        self._clock: Callable[[], float] = clock or time.time
        self.version = version
        self.dry_run = dry_run
        self.started_at = self._clock()
        self._ready = False
        self._ready_since: float | None = None
        self._not_ready_reason: str | None = "starting"
        self._last_heartbeat_at: float | None = None
        self._last_error: dict[str, Any] | None = None
        self._details: Callable[[], Mapping[str, Any]] | None = None

    def set_details_provider(self, provider: Callable[[], Mapping[str, Any]]) -> None:
        """Attach a source of extra fields for ``/status``.

        Used by the quota keeper: how much of the day's allowance is spent, and whether the counters
        are being kept at all, is the first thing an operator asks when the bot starts refusing.

        Args:
            provider: Called on every snapshot; its mapping is merged under ``"details"``.
        """
        self._details = provider

    @property
    def ready(self) -> bool:
        """Whether the service can serve right now.

        Returns:
            ``True`` once every moving part has started and nothing has taken it back down.
        """
        return self._ready

    def mark_ready(self) -> None:
        """Record that the service is now able to serve."""
        if not self._ready:
            self._ready_since = self._clock()
        self._ready = True
        self._not_ready_reason = None

    def mark_not_ready(self, reason: str) -> None:
        """Record that the service can no longer serve.

        Args:
            reason: Short machine-readable cause, e.g. ``"shutting-down"``.
        """
        self._ready = False
        self._ready_since = None
        self._not_ready_reason = reason

    def record_error(self, message: str) -> None:
        """Remember the most recent error, so ``/status`` can show it.

        Args:
            message: The error text.
        """
        self._last_error = {"message": message, "at": _iso(self._clock())}

    def beat(self) -> None:
        """Record a heartbeat tick."""
        self._last_heartbeat_at = self._clock()

    def snapshot(self) -> dict[str, Any]:
        """Return the full state, ready to be serialised as JSON.

        Returns:
            A mapping describing uptime, readiness, the last heartbeat and the last error.
        """
        now = self._clock()
        return {
            "service": "veaf-support-bot",
            "version": self.version,
            "ready": self._ready,
            "not_ready_reason": self._not_ready_reason,
            "dry_run": self.dry_run,
            "started_at": _iso(self.started_at),
            "uptime_seconds": round(now - self.started_at, 3),
            "ready_since": _iso(self._ready_since) if self._ready_since is not None else None,
            "last_heartbeat_at": _iso(self._last_heartbeat_at) if self._last_heartbeat_at is not None else None,
            "last_heartbeat_age_seconds": (
                round(now - self._last_heartbeat_at, 3) if self._last_heartbeat_at is not None else None
            ),
            "last_error": self._last_error,
            "details": dict(self._details()) if self._details is not None else {},
        }


class HealthServer:
    """A minimal HTTP server exposing :class:`ServiceState` on three routes."""

    def __init__(self, state: ServiceState, host: str, port: int, logger: Logger | None = None) -> None:
        """Initialize the server.

        Args:
            state: The state the routes report on.
            host: Interface to bind.
            port: Port to bind; ``0`` asks the OS for an ephemeral one.
            logger: Logger to use; defaults to the service's ``health`` logger.
        """
        self._state = state
        self._host = host
        self._requested_port = port
        self._logger = logger or get_logger("health")
        self._server: asyncio.AbstractServer | None = None
        #: The connections currently being served, so a shutdown can end the ones that overstay.
        self._connections: set[asyncio.StreamWriter] = set()
        self.port: int | None = None

    async def start(self) -> int:
        """Bind and start serving.

        Returns:
            The port actually bound — the requested one, or the ephemeral one the OS picked.

        Raises:
            OSError: When the address cannot be bound. Deliberately not swallowed: a service whose
                health endpoint is dead must not pretend to be healthy.
        """
        self._server = await asyncio.start_server(
            self._handle, host=self._host, port=self._requested_port, limit=_STREAM_LIMIT
        )
        sockets = self._server.sockets or ()
        self.port = int(sockets[0].getsockname()[1]) if sockets else self._requested_port
        self._logger.info(
            "health endpoint listening",
            extra={"event": "health.listening", "host": self._host, "port": self.port},
        )
        return self.port

    async def stop(self, timeout: float = DEFAULT_CLOSE_TIMEOUT_SECONDS) -> None:
        """Stop serving, giving the connections still open a **bounded** moment to finish.

        The bound is the point. Since Python 3.12, :meth:`asyncio.Server.wait_closed` waits for every
        connection handler, not merely for the listening socket, so an unbounded wait here hands the
        end of the process to whoever holds a socket — an idle probe, a port scan, a client trickling
        one header at a time. ``docker stop`` kills at ten seconds regardless, and the final
        ``service.stopped`` line is then never written: exactly the silent death this module exists
        to prevent.

        Args:
            timeout: Seconds granted to the connections still open. Whatever outlives it has its
                transport aborted; a value at or below zero aborts them at once.
        """
        server = self._server
        if server is None:
            return
        server.close()
        if not await self._wait_closed(server, timeout):
            stranded = len(self._connections)
            for writer in tuple(self._connections):
                writer.transport.abort()
            self._logger.warning(
                "aborted health connections that outlived the shutdown budget",
                extra={"event": "health.connections_aborted", "connections": stranded, "timeout": timeout},
            )
            await self._wait_closed(server, _ABORT_TIMEOUT_SECONDS)
        self._server = None
        self._logger.info("health endpoint stopped", extra={"event": "health.stopped"})

    async def _wait_closed(self, server: asyncio.AbstractServer, timeout: float) -> bool:
        """Wait for *server* to report every connection gone, for at most *timeout* seconds.

        Args:
            server: The server being closed.
            timeout: Seconds to wait; anything below zero is read as zero.

        Returns:
            ``True`` when the server closed within the budget, ``False`` when the budget expired.
        """
        try:
            async with asyncio.timeout(max(timeout, 0.0)):
                await server.wait_closed()
        except TimeoutError:
            return False
        return True

    async def _handle(self, reader: asyncio.StreamReader, writer: asyncio.StreamWriter) -> None:
        """Serve one connection: read the request head, answer, close.

        Args:
            reader: Connection reader.
            writer: Connection writer.
        """
        self._connections.add(writer)
        try:
            request = await self._read_request(reader)
            if request is None:
                await self._write(writer, 400, "Bad Request", {"error": "malformed request"}, head_only=False)
                return
            method, path = request
            status, reason, body = self._route(method, path)
            headers = {"Allow": ", ".join(_ALLOWED_METHODS)} if status == 405 else None
            await self._write(writer, status, reason, body, head_only=method == "HEAD", headers=headers)
        except (ConnectionError, asyncio.IncompleteReadError):
            # A monitor that hangs up mid-probe is normal traffic, not an incident. So is a shutdown
            # aborting this very connection.
            pass
        except asyncio.CancelledError:
            raise
        except Exception as error:
            # A broad catch on purpose: the health endpoint is what proves the service is alive, so
            # it must never be the thing that kills it.
            self._logger.warning("health request failed", extra={"event": "health.request_failed", "error": str(error)})
        finally:
            self._connections.discard(writer)
            writer.close()
            try:
                await writer.wait_closed()
            except (ConnectionError, asyncio.IncompleteReadError):
                pass

    async def _read_request(self, reader: asyncio.StreamReader) -> tuple[str, str] | None:
        """Read the request line and drain the headers, under a **single** deadline.

        One budget for the whole head, not one per line. A per-line timeout is not a bound: a client
        sending one header just inside the timeout holds the connection for :data:`_MAX_HEADER_LINES`
        times that timeout — minutes — and :meth:`stop` then has that connection to wait for.

        Args:
            reader: Connection reader.

        Returns:
            ``(method, path)`` with the query string stripped, or ``None`` when the request is
            malformed, oversized or too slow.
        """
        try:
            async with asyncio.timeout(_REQUEST_TIMEOUT_SECONDS):
                raw = await reader.readline()
                parts = raw.decode("latin-1", errors="replace").split()
                if len(parts) < 2:
                    return None
                method, target = parts[0].upper(), parts[1]

                for _ in range(_MAX_HEADER_LINES):
                    line = await reader.readline()
                    if line in (b"\r\n", b"\n", b""):
                        break

                return method, target.split("?", 1)[0]
        except (TimeoutError, ValueError):
            # ValueError: asyncio raises LimitOverrunError (a ValueError) past the stream limit.
            return None

    def _route(self, method: str, path: str) -> tuple[int, str, dict[str, Any]]:
        """Map a request to its response.

        Args:
            method: HTTP method, uppercased.
            path: Request path without its query string.

        Returns:
            ``(status code, reason phrase, JSON body)``.
        """
        if method not in _ALLOWED_METHODS:
            return 405, "Method Not Allowed", {"error": f"only {' and '.join(_ALLOWED_METHODS)} are supported"}
        if path == "/healthz":
            # Liveness: reaching this line proves the event loop still turns. It says nothing about
            # readiness on purpose — conflating the two makes a restart loop out of a transient
            # disconnection.
            return 200, "OK", {"status": "alive", "uptime_seconds": self._state.snapshot()["uptime_seconds"]}
        if path == "/readyz":
            snapshot = self._state.snapshot()
            return (200, "OK", snapshot) if self._state.ready else (503, "Service Unavailable", snapshot)
        if path == "/status":
            return 200, "OK", self._state.snapshot()
        return 404, "Not Found", {"error": "unknown endpoint", "endpoints": ["/healthz", "/readyz", "/status"]}

    async def _write(
        self,
        writer: asyncio.StreamWriter,
        status: int,
        reason: str,
        body: dict[str, Any],
        *,
        head_only: bool,
        headers: Mapping[str, str] | None = None,
    ) -> None:
        """Write a JSON response and flush it.

        Args:
            writer: Connection writer.
            status: HTTP status code.
            reason: HTTP reason phrase.
            body: The JSON body.
            head_only: Send headers only (``HEAD`` request).
            headers: Extra response headers, e.g. the ``Allow`` header RFC 9110 makes mandatory on a
                ``405``.
        """
        encoded = json.dumps(body, ensure_ascii=False, default=str).encode("utf-8")
        extra = "".join(f"{name}: {value}\r\n" for name, value in (headers or {}).items())
        head = (
            f"HTTP/1.1 {status} {reason}\r\n"
            "Content-Type: application/json; charset=utf-8\r\n"
            f"Content-Length: {len(encoded)}\r\n"
            "Cache-Control: no-store\r\n"
            "Connection: close\r\n"
            f"{extra}"
            "\r\n"
        ).encode("latin-1")
        writer.write(head if head_only else head + encoded)
        await writer.drain()
