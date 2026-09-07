"""Start-up and, above all, the shutdown sequence.

``docker stop`` sends ``SIGTERM`` and waits. What the ticket asks for is that the wait is used: stop
declaring readiness, let the work in flight finish, cancel the rest and *say so*. Each of those
three steps is asserted separately, because a shutdown that merely exits looks identical from the
outside until the day it truncates an answer.
"""

from __future__ import annotations

import asyncio
import io
import json
import logging
import tempfile
import unittest
from pathlib import Path

from tests.http_probe import request
from veaf_support_bot.config import SupportBotConfig
from veaf_support_bot.health import ServiceState
from veaf_support_bot.logging_setup import ROOT_LOGGER_NAME, configure_logging
from veaf_support_bot.service import InFlightTasks, SupportBotService


class _StubGateway:
    """A Discord connection that never touches the network but behaves like one.

    Ticket 02 made readiness mean "the gateway is connected", so a lifecycle test that built no
    gateway would now be testing a service that stops on a failed login rather than one that runs.
    The stub publishes readiness the way the real client's ``on_ready`` does, and stays up until it
    is closed.
    """

    def __init__(self, state: ServiceState) -> None:
        """Initialize the stub.

        Args:
            state: The state readiness is published on.
        """
        self._state = state
        self._stop = asyncio.Event()

    async def start(self) -> None:
        """Publish readiness and stay connected until closed."""
        self._state.mark_ready()
        await self._stop.wait()

    async def close(self) -> None:
        """Disconnect."""
        self._stop.set()


def _service(**overrides: str) -> SupportBotService:
    """Build a service over a stub gateway, in a temporary directory for its counters.

    Args:
        **overrides: Extra environment entries, without the ``SUPPORT_BOT_`` prefix.

    Returns:
        The service.
    """
    directory = tempfile.mkdtemp()
    config = _config(QUOTA_STATE_FILE=str(Path(directory) / "quota.json"), **overrides)
    state = ServiceState(version="test", dry_run=config.dry_run)
    return SupportBotService(config, state=state, gateway=_StubGateway(state))


def _config(**overrides: str) -> SupportBotConfig:
    """Build a configuration for a test instance bound to an ephemeral port.

    Args:
        **overrides: Extra environment entries, without the ``SUPPORT_BOT_`` prefix.

    Returns:
        The resolved configuration.
    """
    env = {
        "SUPPORT_BOT_DISCORD_TOKEN": "a-token",
        "SUPPORT_BOT_DISCORD_GUILD_ID": "1",
        "SUPPORT_BOT_WORKER_SECRET": "a-worker-secret",
        "SUPPORT_BOT_HEALTH_PORT": "0",
        "SUPPORT_BOT_SHUTDOWN_GRACE_SECONDS": "0.2",
        "SUPPORT_BOT_HEARTBEAT_SECONDS": "0.05",
    }
    env.update({f"SUPPORT_BOT_{key}": value for key, value in overrides.items()})
    return SupportBotConfig.from_env(env)


class TestInFlightTasks(unittest.IsolatedAsyncioTestCase):
    async def test_draining_nothing_cancels_nothing(self) -> None:
        self.assertEqual(await InFlightTasks().drain(timeout=0.1), 0)

    async def test_work_that_finishes_in_time_is_not_cancelled(self) -> None:
        tasks = InFlightTasks()
        done = asyncio.Event()

        async def quick() -> None:
            await asyncio.sleep(0)
            done.set()

        tasks.track(quick())

        self.assertEqual(await tasks.drain(timeout=1), 0)
        self.assertTrue(done.is_set())

    async def test_work_that_outlives_the_grace_period_is_cancelled(self) -> None:
        tasks = InFlightTasks()
        cancelled = asyncio.Event()

        async def slow() -> None:
            try:
                await asyncio.sleep(30)
            except asyncio.CancelledError:
                cancelled.set()
                raise

        tasks.track(slow(), name="slow")

        self.assertEqual(await tasks.drain(timeout=0.05), 1)
        self.assertTrue(cancelled.is_set())

    async def test_a_finished_task_stops_being_tracked(self) -> None:
        tasks = InFlightTasks()

        async def quick() -> None:
            return None

        task = tasks.track(quick())
        await task
        await asyncio.sleep(0)

        self.assertEqual(len(tasks), 0)


class TestServiceLifecycle(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self) -> None:
        self.stream = io.StringIO()
        configure_logging(level="DEBUG", log_format="json", stream=self.stream)

    async def asyncTearDown(self) -> None:
        root = logging.getLogger(ROOT_LOGGER_NAME)
        for handler in list(root.handlers):
            root.removeHandler(handler)
            handler.close()

    def events(self) -> list[str]:
        """Return the ``event`` field of every log line emitted so far.

        Returns:
            The events, in order.
        """
        return [
            json.loads(line)["event"]
            for line in self.stream.getvalue().splitlines()
            if line.strip() and "event" in json.loads(line)
        ]

    async def _ready_service(self, service: SupportBotService) -> asyncio.Task[None]:
        """Run *service* in the background and wait until it reports itself ready.

        Args:
            service: The service to run.

        Returns:
            The task running it.
        """
        task = asyncio.ensure_future(service.run())
        for _ in range(200):
            if service.state.ready:
                return task
            await asyncio.sleep(0.01)
        task.cancel()
        raise AssertionError("the service never became ready")

    async def test_it_serves_its_health_endpoint_once_started(self) -> None:
        service = _service()
        task = await self._ready_service(service)

        assert service.health.port is not None
        status, body = await request(service.health.port, "/readyz")
        self.assertEqual(status, 200)
        assert body is not None
        self.assertTrue(body["ready"])

        service.request_stop("test")
        await task

    async def test_stopping_makes_it_unready_before_it_closes_the_socket(self) -> None:
        service = _service()
        task = await self._ready_service(service)

        service.request_stop("test")
        await task

        self.assertFalse(service.state.ready)
        self.assertEqual(service.state.snapshot()["not_ready_reason"], "shutting-down")

    async def test_the_health_endpoint_is_closed_on_shutdown(self) -> None:
        service = _service()
        task = await self._ready_service(service)
        port = service.health.port
        assert port is not None

        service.request_stop("test")
        await task

        with self.assertRaises(OSError):
            await asyncio.wait_for(asyncio.open_connection("127.0.0.1", port), timeout=5)

    async def test_in_flight_work_is_drained_before_the_process_leaves(self) -> None:
        service = _service()
        task = await self._ready_service(service)
        finished = asyncio.Event()

        async def exchange() -> None:
            await asyncio.sleep(0.05)
            finished.set()

        service.tasks.track(exchange(), name="exchange")
        service.request_stop("test")
        await task

        self.assertTrue(finished.is_set(), "a half-answered exchange was abandoned")
        self.assertIn("shutdown.draining", self.events())

    async def test_work_that_will_not_end_is_cancelled_and_reported(self) -> None:
        service = _service()
        task = await self._ready_service(service)

        async def stuck() -> None:
            await asyncio.sleep(30)

        service.tasks.track(stuck(), name="stuck")
        service.request_stop("test")
        await task

        self.assertIn("shutdown.cancelled", self.events())

    async def test_a_client_holding_a_health_socket_cannot_stall_the_stop(self) -> None:
        """The failure the whole shutdown sequence exists to prevent, reached from the outside.

        ``docker stop`` kills at ten seconds. Before the bound, one idle TCP connection to the health
        endpoint — a port scan is enough, and the container binds ``0.0.0.0`` — stretched the stop to
        the read timeout, and a client trickling one header at a time stretched it to minutes. The
        process then died on the kill with no ``service.stopped`` line: a silent death, which is the
        one thing this service is built not to do.
        """
        service = _service(SHUTDOWN_GRACE_SECONDS="0.3")
        task = await self._ready_service(service)
        assert service.health.port is not None
        _, hanger = await asyncio.open_connection("127.0.0.1", service.health.port)

        started = asyncio.get_running_loop().time()
        service.request_stop("test")
        await asyncio.wait_for(task, timeout=30)
        elapsed = asyncio.get_running_loop().time() - started
        hanger.close()

        self.assertLess(elapsed, 3.0, f"the shutdown was held by an idle client for {elapsed:.2f} s")
        self.assertIn("service.stopped", self.events())

    async def test_the_grace_period_bounds_the_whole_sequence_not_each_step(self) -> None:
        """Two steps each granted the full grace add up to a stop the container kills mid-way."""
        service = _service(SHUTDOWN_GRACE_SECONDS="0.4")
        task = await self._ready_service(service)
        assert service.health.port is not None
        _, hanger = await asyncio.open_connection("127.0.0.1", service.health.port)

        async def stuck() -> None:
            await asyncio.sleep(30)

        service.tasks.track(stuck(), name="stuck")
        started = asyncio.get_running_loop().time()
        service.request_stop("test")
        await asyncio.wait_for(task, timeout=30)
        elapsed = asyncio.get_running_loop().time() - started
        hanger.close()

        self.assertIn("shutdown.cancelled", self.events())
        self.assertLess(elapsed, 1.2, f"the drain and the endpoint each took a full grace ({elapsed:.2f} s)")

    async def test_the_first_stop_reason_is_the_one_reported(self) -> None:
        service = _service()
        task = await self._ready_service(service)

        service.request_stop("signal SIGTERM")
        service.request_stop("something else")
        await task

        stopped = [
            json.loads(line)
            for line in self.stream.getvalue().splitlines()
            if line.strip() and json.loads(line).get("event") == "service.stopped"
        ]
        self.assertEqual(stopped[0]["reason"], "signal SIGTERM")

    async def test_the_startup_line_never_carries_the_token(self) -> None:
        service = _service()
        task = await self._ready_service(service)
        service.request_stop("test")
        await task

        self.assertNotIn("a-token", self.stream.getvalue())

    async def test_it_beats_while_it_runs(self) -> None:
        """The heartbeat is what a log-based alert watches; without it, silence is ambiguous."""
        service = _service()
        task = await self._ready_service(service)

        for _ in range(200):
            if service.state.snapshot()["last_heartbeat_at"] is not None:
                break
            await asyncio.sleep(0.01)

        service.request_stop("test")
        await task

        self.assertIn("service.heartbeat", self.events())

    async def test_a_dry_run_says_so_loudly_and_keeps_saying_it(self) -> None:
        """A dry run left on in production must not become invisible once the log scrolls.

        It is *not* waited on with :meth:`_ready_service`: a dry run never becomes ready, on
        purpose. A process that answers nobody must not certify itself fit to serve, so the wait
        here is for the heartbeat instead.
        """
        service = _service(DRY_RUN="true")
        task = asyncio.ensure_future(service.run())

        for _ in range(200):
            if self.events().count("service.dry_run") >= 2:
                break
            await asyncio.sleep(0.01)

        service.request_stop("test")
        await task

        self.assertGreaterEqual(self.events().count("service.dry_run"), 2)
        self.assertTrue(service.state.snapshot()["dry_run"])

    async def test_a_dry_run_never_reports_itself_ready(self) -> None:
        """A readiness probe that says yes here would certify a service serving no users."""
        service = _service(DRY_RUN="true")
        task = asyncio.ensure_future(service.run())
        for _ in range(200):
            if service.health.port is not None:
                break
            await asyncio.sleep(0.01)

        assert service.health.port is not None
        status, body = await request(service.health.port, "/readyz")
        service.request_stop("test")
        await task

        self.assertEqual(status, 503)
        assert body is not None
        self.assertEqual(body["not_ready_reason"], "dry-run")


if __name__ == "__main__":
    unittest.main()
