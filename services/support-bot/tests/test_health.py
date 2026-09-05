"""The endpoints an operator uses to find out the bot has died.

These tests talk to a **real socket** on an ephemeral port rather than calling the routing method:
the failure being guarded against is "the process is up and answers nothing", which only a request
over the wire can disprove.
"""

from __future__ import annotations

import asyncio
import unittest

from tests.http_probe import request
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
