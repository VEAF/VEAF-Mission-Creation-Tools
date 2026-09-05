"""The endpoints an operator uses to find out the bot has died.

These tests talk to a **real socket** on an ephemeral port rather than calling the routing method:
the failure being guarded against is "the process is up and answers nothing", which only a request
over the wire can disprove.
"""

from __future__ import annotations

import asyncio
import contextlib
import unittest
from collections.abc import AsyncIterator
from unittest import mock

from tests.http_probe import raw_head, request
from veaf_support_bot import health
from veaf_support_bot.health import HealthServer, ServiceState


class FakeClock:
    """A clock the tests move by hand, so uptime assertions are exact."""

    def __init__(self, now: float = 1_000_000.0) -> None:
        """Initialize the clock.

        Args:
            now: The initial Unix timestamp.
        """
        self.now = now

    def __call__(self) -> float:
        """Return the current fake timestamp.

        Returns:
            The timestamp the test last set.
        """
        return self.now


class TestServiceState(unittest.TestCase):
    def setUp(self) -> None:
        self.clock = FakeClock()
        self.state = ServiceState(version="9.9.9", clock=self.clock)

    def test_a_fresh_service_is_not_ready_and_says_why(self) -> None:
        self.assertFalse(self.state.ready)
        self.assertEqual(self.state.snapshot()["not_ready_reason"], "starting")

    def test_becoming_ready_records_when(self) -> None:
        self.clock.now += 5
        self.state.mark_ready()

        snapshot = self.state.snapshot()
        self.assertTrue(snapshot["ready"])
        self.assertIsNone(snapshot["not_ready_reason"])
        self.assertEqual(snapshot["ready_since"], "1970-01-12T13:46:45.000+00:00")

    def test_readiness_is_not_re_stamped_by_a_second_call(self) -> None:
        self.state.mark_ready()
        first = self.state.snapshot()["ready_since"]
        self.clock.now += 60
        self.state.mark_ready()

        self.assertEqual(self.state.snapshot()["ready_since"], first)

    def test_losing_readiness_reports_the_reason(self) -> None:
        self.state.mark_ready()
        self.state.mark_not_ready("shutting-down")

        snapshot = self.state.snapshot()
        self.assertFalse(snapshot["ready"])
        self.assertEqual(snapshot["not_ready_reason"], "shutting-down")
        self.assertIsNone(snapshot["ready_since"])

    def test_uptime_follows_the_clock(self) -> None:
        self.clock.now += 42.5

        self.assertEqual(self.state.snapshot()["uptime_seconds"], 42.5)

    def test_a_heartbeat_is_dated_and_aged(self) -> None:
        self.state.beat()
        self.clock.now += 30

        snapshot = self.state.snapshot()
        self.assertEqual(snapshot["last_heartbeat_age_seconds"], 30.0)
        self.assertIsNotNone(snapshot["last_heartbeat_at"])

    def test_no_heartbeat_yet_reads_as_none_not_as_zero(self) -> None:
        """Zero would read as "beating right now", which is the opposite of the truth."""
        snapshot = self.state.snapshot()

        self.assertIsNone(snapshot["last_heartbeat_at"])
        self.assertIsNone(snapshot["last_heartbeat_age_seconds"])

    def test_the_last_error_is_kept_with_its_timestamp(self) -> None:
        self.state.record_error("worker unreachable")

        error = self.state.snapshot()["last_error"]
        self.assertEqual(error["message"], "worker unreachable")
        self.assertIn("at", error)


class TestHealthEndpoints(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self) -> None:
        self.state = ServiceState(version="9.9.9")
        self.server = HealthServer(self.state, "127.0.0.1", 0)
        self.port = await self.server.start()

    async def asyncTearDown(self) -> None:
        await self.server.stop()

    async def test_liveness_answers_before_the_service_is_ready(self) -> None:
        """The two are separate on purpose: a transient un-readiness must not trigger a restart."""
        status, body = await request(self.port, "/healthz")

        self.assertEqual(status, 200)
        assert body is not None
        self.assertEqual(body["status"], "alive")

    async def test_readiness_is_503_until_the_service_says_otherwise(self) -> None:
        status, body = await request(self.port, "/readyz")

        self.assertEqual(status, 503)
        assert body is not None
        self.assertFalse(body["ready"])

    async def test_readiness_turns_200_once_ready(self) -> None:
        self.state.mark_ready()

        status, body = await request(self.port, "/readyz")

        self.assertEqual(status, 200)
        assert body is not None
        self.assertTrue(body["ready"])

    async def test_readiness_goes_back_to_503_on_shutdown(self) -> None:
        """A probe must see the drain start, not discover it when the socket closes."""
        self.state.mark_ready()
        self.state.mark_not_ready("shutting-down")

        status, body = await request(self.port, "/readyz")

        self.assertEqual(status, 503)
        assert body is not None
        self.assertEqual(body["not_ready_reason"], "shutting-down")

    async def test_status_returns_the_whole_picture(self) -> None:
        status, body = await request(self.port, "/status")

        self.assertEqual(status, 200)
        assert body is not None
        self.assertEqual(body["service"], "veaf-support-bot")
        self.assertEqual(body["version"], "9.9.9")
        for key in ("uptime_seconds", "started_at", "last_heartbeat_at", "last_error", "dry_run"):
            self.assertIn(key, body)

    async def test_a_query_string_does_not_hide_the_route(self) -> None:
        status, _ = await request(self.port, "/readyz?probe=docker")

        self.assertEqual(status, 503)

    async def test_an_unknown_route_lists_the_real_ones(self) -> None:
        status, body = await request(self.port, "/")

        self.assertEqual(status, 404)
        assert body is not None
        self.assertEqual(body["endpoints"], ["/healthz", "/readyz", "/status"])

    async def test_a_write_method_is_refused(self) -> None:
        status, _ = await request(self.port, "/status", method="POST")

        self.assertEqual(status, 405)

    async def test_the_refusal_says_which_methods_are_allowed(self) -> None:
        """RFC 9110 makes ``Allow`` mandatory on a 405, and a bare refusal tells a client nothing."""
        head = await raw_head(self.port, "/status", method="POST")

        self.assertIn("allow: get, head", head.lower())

    async def test_head_returns_the_status_without_a_body(self) -> None:
        status, body = await request(self.port, "/healthz", method="HEAD")

        self.assertEqual(status, 200)
        self.assertIsNone(body)

    async def test_a_malformed_request_is_answered_not_crashed_on(self) -> None:
        reader, writer = await asyncio.open_connection("127.0.0.1", self.port)
        writer.write(b"garbage\r\n\r\n")
        await writer.drain()
        raw = await asyncio.wait_for(reader.read(), timeout=5)
        writer.close()
        await writer.wait_closed()

        self.assertIn(b"400", raw.split(b"\r\n")[0])

    async def test_the_server_survives_a_client_that_hangs_up_mid_request(self) -> None:
        _, writer = await asyncio.open_connection("127.0.0.1", self.port)
        writer.write(b"GET /status HTT")
        await writer.drain()
        writer.close()

        status, _ = await request(self.port, "/healthz")
        self.assertEqual(status, 200)

    async def test_an_ephemeral_port_is_reported_back(self) -> None:
        """The service logs the port it actually got; 0 in the log would be useless."""
        self.assertGreater(self.port, 0)
        self.assertEqual(self.server.port, self.port)


class TestAClientCannotHoldTheShutdown(unittest.IsolatedAsyncioTestCase):
    """The half of the shutdown no other test covered: a client that hangs *on*, not up.

    Since Python 3.12, ``Server.wait_closed()`` waits for every connection handler, so an unbounded
    wait in :meth:`HealthServer.stop` hands the end of the process to whoever holds a socket. On
    ``python:3.13-slim`` — the deployed image — one idle TCP connection was enough to stall the stop
    for the whole read timeout, and a client trickling a header just inside that timeout stalled it
    for minutes, well past the ten seconds after which ``docker stop`` kills. The `service.stopped`
    line was then never written: the silent death this module exists to make impossible.
    """

    async def asyncSetUp(self) -> None:
        self.state = ServiceState(version="9.9.9")
        self.server = HealthServer(self.state, "127.0.0.1", 0)
        self.port = await self.server.start()
        self.opened: list[asyncio.StreamWriter] = []

    async def asyncTearDown(self) -> None:
        for writer in self.opened:
            writer.close()

    async def _hold(self, *, preamble: bytes = b"") -> tuple[asyncio.StreamReader, asyncio.StreamWriter]:
        """Open a connection and keep it open, optionally after sending a partial request.

        Args:
            preamble: Bytes to send before going quiet.

        Returns:
            The reader and the writer, kept open until teardown.
        """
        reader, writer = await asyncio.open_connection("127.0.0.1", self.port)
        if preamble:
            writer.write(preamble)
            await writer.drain()
        self.opened.append(writer)
        return reader, writer

    @contextlib.asynccontextmanager
    async def _trickling(self, interval: float) -> AsyncIterator[asyncio.StreamReader]:
        """Run a client that sends one header every *interval* seconds and never finishes.

        The interval is chosen just *under* the read timeout on purpose: such a client never idles
        long enough to trip a per-line wait, which is what made the old bound no bound at all.

        Args:
            interval: Seconds between two header lines.

        Yields:
            The reader of the trickling connection.
        """
        reader, writer = await self._hold(preamble=b"GET /status HTTP/1.1\r\n")

        async def trickle() -> None:
            while True:
                await asyncio.sleep(interval)
                writer.write(b"X-Probe: still-here\r\n")
                await writer.drain()

        pest = asyncio.ensure_future(trickle())
        try:
            yield reader
        finally:
            pest.cancel()
            await asyncio.gather(pest, return_exceptions=True)

    async def _timed_stop(self, timeout: float) -> float:
        """Stop the server and return how long it took.

        Args:
            timeout: Budget handed to :meth:`HealthServer.stop`.

        Returns:
            Seconds elapsed.
        """
        started = asyncio.get_running_loop().time()
        await asyncio.wait_for(self.server.stop(timeout=timeout), timeout=60)
        return asyncio.get_running_loop().time() - started

    async def test_one_idle_connection_does_not_hold_the_shutdown(self) -> None:
        """Measured before the fix: 4.8 s for a single connection that sends nothing at all."""
        await self._hold()

        self.assertLess(await self._timed_stop(0.2), 2.0)

    async def test_many_idle_connections_do_not_hold_the_shutdown(self) -> None:
        for _ in range(20):
            await self._hold()

        self.assertLess(await self._timed_stop(0.2), 2.0)

    async def test_a_client_trickling_headers_does_not_hold_the_shutdown(self) -> None:
        """Measured before the fix: still blocked after 60 s, with a ceiling near five minutes.

        The read timeout is shrunk so the same arithmetic fits in a test: a header every 0.3 s under
        a 0.5 s per-line wait never times out, and 64 of them are 19 s of shutdown. The point is that
        ``stop`` returns on its own budget whatever the connection is doing.
        """
        with mock.patch.object(health, "_REQUEST_TIMEOUT_SECONDS", 0.5):
            async with self._trickling(interval=0.3):
                self.assertLess(await self._timed_stop(0.2), 2.0)

    async def test_the_request_head_is_on_one_deadline_not_one_per_line(self) -> None:
        """The other half: with no shutdown involved, the head deadline alone ends the connection."""
        with mock.patch.object(health, "_REQUEST_TIMEOUT_SECONDS", 0.5):
            async with self._trickling(interval=0.3) as reader:
                started = asyncio.get_running_loop().time()
                # The server answers 400 and closes as soon as the head deadline expires. Under a
                # per-line budget it would keep reading for 64 x 0.3 s instead.
                raw = await asyncio.wait_for(reader.read(), timeout=15)
                elapsed = asyncio.get_running_loop().time() - started

        self.assertIn(b"400", raw.split(b"\r\n")[0])
        self.assertLess(elapsed, 5.0, "the deadline is being applied per line, not per request")

    async def test_cutting_a_connection_short_is_reported_never_silent(self) -> None:
        """Aborting someone's socket is a decision, and an operator has to be able to see it made."""
        logger = mock.Mock()
        self.server._logger = logger
        await self._hold()

        await self.server.stop(timeout=0.2)

        events = [call.kwargs["extra"]["event"] for call in logger.warning.call_args_list]
        self.assertIn("health.connections_aborted", events)

    async def test_a_connection_still_being_served_is_given_its_budget(self) -> None:
        """Bounded is not brutal: a probe already mid-request is answered, not cut off."""
        reader, writer = await asyncio.open_connection("127.0.0.1", self.port)
        self.opened.append(writer)
        writer.write(b"GET /healthz HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n")
        await writer.drain()

        await self.server.stop(timeout=5.0)
        raw = await asyncio.wait_for(reader.read(), timeout=5)

        self.assertIn(b"200", raw.split(b"\r\n")[0])


class TestServerLifecycle(unittest.IsolatedAsyncioTestCase):
    async def test_stopping_twice_is_harmless(self) -> None:
        server = HealthServer(ServiceState(version="0"), "127.0.0.1", 0)
        await server.start()

        await server.stop()
        await server.stop()

    async def test_stopping_a_server_that_never_started_is_harmless(self) -> None:
        await HealthServer(ServiceState(version="0"), "127.0.0.1", 0).stop()

    async def test_the_socket_is_really_closed_afterwards(self) -> None:
        server = HealthServer(ServiceState(version="0"), "127.0.0.1", 0)
        port = await server.start()
        await server.stop()

        with self.assertRaises(OSError):
            await asyncio.wait_for(asyncio.open_connection("127.0.0.1", port), timeout=5)


if __name__ == "__main__":
    unittest.main()
