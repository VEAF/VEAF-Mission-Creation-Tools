"""The process itself: start everything, stay observable, stop cleanly.

The shutdown path is the part worth reading. A container restart sends ``SIGTERM`` and waits a few
seconds; whatever is still running is killed. For this service that would mean a Discord thread
opened, the "thinking" placeholder posted, and no answer ever edited in — a visibly broken exchange
that stays on the server forever. So the service:

1. stops declaring itself ready, so a probe sees ``503`` immediately;
2. gives the work already in flight a bounded grace period to finish;
3. cancels what is left and says so in a log line, rather than dying silently.

Ticket 01 has no in-flight work yet — :class:`InFlightTasks` is the hook ticket 02 hangs each
``/ask`` exchange on, and it is tested here on its own.
"""

from __future__ import annotations

import asyncio
from collections.abc import Coroutine
from logging import Logger
from typing import Any

from veaf_support_bot import __version__
from veaf_support_bot.config import SupportBotConfig
from veaf_support_bot.health import HealthServer, ServiceState
from veaf_support_bot.logging_setup import get_logger


class InFlightTasks:
    """The work a clean shutdown must wait for."""

    def __init__(self, logger: Logger | None = None) -> None:
        """Initialize an empty registry.

        Args:
            logger: Logger to use; defaults to the service's ``tasks`` logger.
        """
        self._logger = logger or get_logger("tasks")
        self._tasks: set[asyncio.Task[Any]] = set()

    def __len__(self) -> int:
        """Return the number of tasks currently in flight.

        Returns:
            How many tracked tasks have not finished yet.
        """
        return len(self._tasks)

    def track(self, coro: Coroutine[Any, Any, Any], *, name: str | None = None) -> asyncio.Task[Any]:
        """Schedule a coroutine and remember it until it finishes.

        Args:
            coro: The coroutine to run.
            name: Optional task name, used in logs.

        Returns:
            The scheduled task.
        """
        task = asyncio.ensure_future(coro)
        if name:
            task.set_name(name)
        self._tasks.add(task)
        task.add_done_callback(self._tasks.discard)
        return task

    async def drain(self, timeout: float) -> int:
        """Wait for the tracked tasks, then cancel whatever is left.

        Args:
            timeout: Seconds granted to the tasks still running.

        Returns:
            The number of tasks that had to be cancelled — zero means the shutdown was clean.
        """
        pending = set(self._tasks)
        if not pending:
            return 0
        self._logger.info(
            "waiting for in-flight work",
            extra={"event": "shutdown.draining", "tasks": len(pending), "timeout": timeout},
        )
        _, still_running = await asyncio.wait(pending, timeout=timeout)
        for task in still_running:
            task.cancel()
        if still_running:
            await asyncio.gather(*still_running, return_exceptions=True)
            self._logger.warning(
                "cancelled work that outlived the grace period",
                extra={"event": "shutdown.cancelled", "tasks": len(still_running)},
            )
        return len(still_running)


class SupportBotService:
    """Assembles the health server, the heartbeat and the shutdown sequence."""

    def __init__(
        self,
        config: SupportBotConfig,
        *,
        state: ServiceState | None = None,
        health_server: HealthServer | None = None,
        logger: Logger | None = None,
    ) -> None:
        """Initialize the service without starting anything.

        Args:
            config: The resolved configuration.
            state: State object to publish; one is built from *config* when omitted.
            health_server: Health server to use; one is built from *config* when omitted.
            logger: Logger to use; defaults to the service's ``service`` logger.
        """
        self.config = config
        self.logger = logger or get_logger("service")
        self.state = state or ServiceState(version=__version__, dry_run=config.dry_run)
        self.health = health_server or HealthServer(self.state, config.health_host, config.health_port, self.logger)
        self.tasks = InFlightTasks(self.logger)
        self._stop = asyncio.Event()
        self._stop_reason = "unknown"

    def request_stop(self, reason: str) -> None:
        """Ask the service to shut down.

        Safe to call from a signal handler and safe to call twice: the first reason is the one
        reported.

        Args:
            reason: Why the service is stopping, e.g. ``"signal SIGTERM"``.
        """
        if self._stop.is_set():
            return
        self._stop_reason = reason
        self.logger.info("shutdown requested", extra={"event": "shutdown.requested", "reason": reason})
        self._stop.set()

    async def run(self) -> None:
        """Start every part, serve until asked to stop, then shut down cleanly."""
        self.logger.info(
            "starting",
            extra={"event": "service.starting", "version": __version__, "config": self.config.redacted()},
        )
        if self.config.dry_run:
            self.logger.warning(
                "dry run: the service will not connect to Discord",
                extra={"event": "service.dry_run"},
            )

        await self.health.start()
        heartbeat = asyncio.ensure_future(self._heartbeat())
        # Ticket 01: serving the health endpoint *is* the whole job, so that is what readiness
        # means today. Ticket 02 adds "and the Discord gateway is connected".
        self.state.mark_ready()
        self.logger.info("ready", extra={"event": "service.ready", "health_port": self.health.port})

        try:
            await self._stop.wait()
        finally:
            await self._shutdown(heartbeat)

    async def _shutdown(self, heartbeat: asyncio.Task[Any]) -> None:
        """Take the service down in the order that keeps an exchange whole.

        Args:
            heartbeat: The heartbeat task to cancel.
        """
        self.state.mark_not_ready("shutting-down")
        heartbeat.cancel()
        await asyncio.gather(heartbeat, return_exceptions=True)

        cancelled = await self.tasks.drain(self.config.shutdown_grace_seconds)
        await self.health.stop()

        self.logger.info(
            "stopped",
            extra={
                "event": "service.stopped",
                "reason": self._stop_reason,
                "cancelled_tasks": cancelled,
                "uptime_seconds": self.state.snapshot()["uptime_seconds"],
            },
        )

    async def _heartbeat(self) -> None:
        """Emit a heartbeat line at the configured interval until cancelled."""
        while True:
            await asyncio.sleep(self.config.heartbeat_seconds)
            self.state.beat()
            snapshot = self.state.snapshot()
            self.logger.info(
                "heartbeat",
                extra={
                    "event": "service.heartbeat",
                    "uptime_seconds": snapshot["uptime_seconds"],
                    "ready": snapshot["ready"],
                    "dry_run": self.config.dry_run,
                },
            )
            if self.config.dry_run:
                # Repeated on every beat on purpose: a dry run left on in production is otherwise
                # invisible after the startup line has scrolled away.
                self.logger.warning("still running in dry-run mode", extra={"event": "service.dry_run"})
