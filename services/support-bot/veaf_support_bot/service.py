"""The process itself: start everything, stay observable, stop cleanly.

The shutdown path is the part worth reading. A container restart sends ``SIGTERM`` and waits a few
seconds; whatever is still running is killed. For this service that would mean a Discord thread
opened, the "thinking" placeholder posted, and no answer ever edited in — a visibly broken exchange
that stays on the server forever. So the service:

1. stops declaring itself ready, so a probe sees ``503`` immediately;
2. gives the work already in flight a bounded grace period to finish;
3. cancels what is left and says so in a log line, rather than dying silently.

``shutdown_grace_seconds`` bounds the sequence **end to end**, not each step: the health endpoint
gets what the drain left of it, never a second helping. A shutdown that can add up to twice the
configured grace is one that ``docker stop`` kills before its final line is written, which is the
same silent death seen from the outside. The only overshoot is the second
:data:`~veaf_support_bot.health._ABORT_TIMEOUT_SECONDS` grants the event loop to collect sockets it
has already torn down.

:class:`InFlightTasks` is where each ``/ask`` exchange hangs, so a shutdown lets an answer finish
being edited in rather than abandoning a "thinking" placeholder forever.

## What "ready" means, and what a dry run reports

Readiness is *the gateway is connected*. While ticket 01 had the service do nothing, "the health
endpoint answers" was a defensible definition; now that it answers users, a process with no gateway
declaring itself fit to serve would be a lie a monitor believes. So a **dry run is never ready**: it
answers ``503`` with ``not_ready_reason: "dry-run"``, and its container therefore shows as
*unhealthy* — which is exactly the visibility a dry run left on in production needs.

Liveness is unchanged and stays separate: ``/healthz`` still answers ``200``, because the process is
alive and restarting it would not connect a gateway it was told not to open.
"""

from __future__ import annotations

import asyncio
from collections.abc import Coroutine
from logging import Logger
from pathlib import Path
from typing import Any, Protocol

from veaf_support_bot import __version__
from veaf_support_bot.ask import AskHandler, build_handler
from veaf_support_bot.attachments import AttachmentCollector, http_download
from veaf_support_bot.checkout import CheckoutUnavailable, open_checkout
from veaf_support_bot.config import SupportBotConfig
from veaf_support_bot.filing import IssueFiler, Ledger, RepositoryIssues
from veaf_support_bot.github_app import AppCredentials, GitHubApp, aiohttp_transport, read_private_key
from veaf_support_bot.health import HealthServer, ServiceState
from veaf_support_bot.intake import BugIntake
from veaf_support_bot.logging_setup import get_logger
from veaf_support_bot.priorart import PriorArtGate, PriorArtSweeper
from veaf_support_bot.quota import QuotaKeeper, QuotaLimits, QuotaStore


class Gateway(Protocol):
    """The connection to Discord, reduced to what the lifecycle needs.

    A protocol rather than the concrete client, so the whole start/stop sequence — including the
    case where the connection dies on its own and must take the process down with it — is tested
    without a Discord token.
    """

    async def start(self) -> None:
        """Connect and serve until :meth:`close` is called."""

    async def close(self) -> None:
        """Disconnect and release the connection."""


def build_quota(config: SupportBotConfig, logger: Logger | None = None) -> QuotaKeeper:
    """Build the quota keeper described by a configuration.

    Args:
        config: The resolved configuration.
        logger: Logger to hand the keeper.

    Returns:
        The keeper, already loaded — or already degraded, when the counters could not be read.
    """
    limits = QuotaLimits(
        user_window_seconds=config.quota_user_window_seconds,
        user_per_window=config.quota_user_per_window,
        user_per_day=config.quota_user_per_day,
        global_per_day=config.quota_global_per_day,
    )
    return QuotaKeeper(limits, QuotaStore(Path(config.quota_state_file)), logger=logger)


def build_intake(config: SupportBotConfig, logger: Logger | None = None) -> BugIntake | None:
    """Build the ``/bug`` intake, when the deployment gave it a repository to read.

    A checkout is what turns a stack trace into a location, so without one the command is **not
    published** rather than published and answering "I cannot do this": an unusable command in the
    picker is a promise the service does not keep.

    A configured path that turns out not to be a git working tree is a different matter — that is a
    deployment mistake — but it is reported and skipped rather than raised, because the alternative
    is a service that refuses to answer documentation questions over a feature it was not asked for.
    The line in the log names the path and says ``/bug`` is off.

    Args:
        config: The resolved configuration.
        logger: Logger to report an unusable path on.

    Returns:
        The intake, or ``None`` when there is no usable checkout.
    """
    if not config.checkout_path:
        return None
    report = logger or get_logger("service")
    try:
        checkout = open_checkout(
            config.checkout_path,
            remote=config.checkout_remote,
            branch=config.checkout_branch,
            refresh_seconds=config.checkout_refresh_seconds,
        )
    except CheckoutUnavailable as error:
        report.error(
            "/bug is disabled: the configured checkout is unusable",
            extra={"event": "intake.no_checkout", "error": str(error)},
        )
        return None
    collector = AttachmentCollector(
        checkout,
        http_download,
        max_file_bytes=config.attachment_max_bytes,
        max_total_bytes=config.attachment_total_bytes,
    )
    app = build_github_app(config)
    return BugIntake(
        checkout,
        collector,
        logger=report,
        prior_art=PriorArtGate(PriorArtSweeper(checkout.root, RepositoryIssues(app) if app else None)),
        filer=IssueFiler(
            app,
            Ledger(Path(config.github_ledger_file), report),
            logger=report,
            machine_label=config.github_machine_label,
        )
        if app
        else None,
    )


def build_github_app(config: SupportBotConfig) -> GitHubApp | None:
    """Build the authenticated GitHub client, when this deployment has an App.

    Args:
        config: The resolved configuration.

    Returns:
        The client, or ``None`` when no App is configured — in which case ``/bug`` still prepares
        and shows a complete report, and says plainly that nothing was opened.

    Raises:
        GitHubError: The App is configured and its private key cannot be read. Deliberately fatal:
            :func:`veaf_support_bot.config.SupportBotConfig.from_env` has already refused a
            half-configured App, so reaching here with an unusable key is a deployment that would
            collect reports it can never file. The service exits 78 on it, like every other
            configuration failure — it does not find out on the first user's report.
    """
    if not config.files_issues:
        return None
    credentials = AppCredentials(
        app_id=config.github_app_id,
        installation_id=config.github_installation_id,
        private_key_pem=read_private_key(config.github_private_key, config.github_private_key_file),
    )
    return GitHubApp(credentials, config.github_repository, aiohttp_transport)


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
        quota: QuotaKeeper | None = None,
        gateway: Gateway | None = None,
    ) -> None:
        """Initialize the service without starting anything.

        Args:
            config: The resolved configuration.
            state: State object to publish; one is built from *config* when omitted.
            health_server: Health server to use; one is built from *config* when omitted.
            logger: Logger to use; defaults to the service's ``service`` logger.
            quota: Per-user counters; built from *config* when omitted.
            gateway: The Discord connection; built from *config* when omitted, and never built at
                all in a dry run.
            handler: Not a parameter — the ``/ask`` handler is built here from *quota*, because a
                handler wired to counters other than the service's own would enforce nothing.
        """
        self.config = config
        self.logger = logger or get_logger("service")
        self.state = state or ServiceState(version=__version__, dry_run=config.dry_run)
        self.health = health_server or HealthServer(self.state, config.health_host, config.health_port, self.logger)
        self.tasks = InFlightTasks(self.logger)
        self.quota = quota or build_quota(config, self.logger)
        self.handler: AskHandler = build_handler(config, self.quota)
        self.intake: BugIntake | None = build_intake(config, self.logger)
        self.state.set_details_provider(self.quota.snapshot)
        self._gateway = gateway
        self._connection: Gateway | None = gateway
        self._stop = asyncio.Event()
        self._stop_reason = "unknown"

    def _build_gateway(self) -> Gateway:
        """Build the Discord connection.

        Imported here rather than at module scope so the library is only needed by a process that
        actually connects — and so a dry run, which never calls this, does not depend on it.

        Returns:
            The gateway.
        """
        from veaf_support_bot.discord_bot import DiscordGateway, SupportBotClient

        client = SupportBotClient(self.config, self.state, self.handler, self.tasks, self.intake)
        return DiscordGateway(client, self.config.discord_token)

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

        if self.quota.degraded:
            self.logger.warning(
                "starting with degraded quota counters",
                extra={"event": "quota.degraded_at_startup", "reason": self.quota.degraded_reason},
            )

        await self.health.start()
        heartbeat = asyncio.ensure_future(self._heartbeat())
        gateway: asyncio.Task[Any] | None = None

        if self.config.dry_run:
            # Never ready: nothing can reach a bot with no gateway. Saying otherwise would let a
            # readiness probe certify a service that answers nobody — which is what a dry run left
            # on in production actually is.
            self.state.mark_not_ready("dry-run")
            self.logger.warning(
                "serving no users: readiness stays negative in a dry run",
                extra={"event": "service.dry_run_not_ready", "health_port": self.health.port},
            )
        else:
            connection = self._gateway or self._build_gateway()
            gateway = asyncio.ensure_future(connection.start())
            # Readiness is published by the gateway itself, from `on_ready`. What is handled here is
            # the connection ending on its own — a bad token, a gateway that gives up reconnecting.
            # Left alone that leaves a live process that will never answer again: the exact silent
            # death this service is built to prevent, so it takes the process down instead.
            gateway.add_done_callback(self._gateway_ended)
            self._connection = connection
            self.logger.info(
                "connecting to the gateway",
                extra={"event": "service.connecting", "health_port": self.health.port},
            )

        try:
            await self._stop.wait()
        finally:
            await self._shutdown(heartbeat, gateway)

    def _gateway_ended(self, task: asyncio.Task[Any]) -> None:
        """Stop the service when the Discord connection ends by itself.

        Args:
            task: The finished gateway task.
        """
        if task.cancelled() or self._stop.is_set():
            return
        error = task.exception()
        if error is not None:
            self.state.record_error(f"{type(error).__name__}: {error}")
            self.logger.error(
                "the Discord connection failed",
                extra={"event": "discord.failed", "error": f"{type(error).__name__}: {error}"},
            )
        self.state.mark_not_ready("gateway-ended")
        self.request_stop("the Discord connection ended")

    async def _shutdown(self, heartbeat: asyncio.Task[Any], gateway: asyncio.Task[Any] | None = None) -> None:
        """Take the service down in the order that keeps an exchange whole.

        Every step draws on one deadline, ``shutdown_grace_seconds`` from now, so the whole sequence
        is bounded by the number the operator configured rather than by the sum of its steps.

        Args:
            heartbeat: The heartbeat task to cancel.
            gateway: The Discord connection task, when there is one.
        """
        loop = asyncio.get_running_loop()
        deadline = loop.time() + self.config.shutdown_grace_seconds

        self.state.mark_not_ready("shutting-down")
        heartbeat.cancel()
        await asyncio.gather(heartbeat, return_exceptions=True)

        # Drained *before* the gateway closes, not after. Every in-flight exchange finishes by
        # editing a Discord message, and a closed connection cannot edit anything — closing first
        # would guarantee the abandoned "thinking" placeholder this whole sequence exists to avoid.
        cancelled = await self.tasks.drain(max(deadline - loop.time(), 0.0))
        if gateway is not None:
            await self._close_gateway(gateway, deadline - loop.time())
        await self.health.stop(timeout=deadline - loop.time())

        self.logger.info(
            "stopped",
            extra={
                "event": "service.stopped",
                "reason": self._stop_reason,
                "cancelled_tasks": cancelled,
                "uptime_seconds": self.state.snapshot()["uptime_seconds"],
            },
        )

    async def _close_gateway(self, gateway: asyncio.Task[Any], timeout: float) -> None:
        """Close the Discord connection, within what is left of the shutdown budget.

        Args:
            gateway: The running gateway task.
            timeout: Seconds left. At or below zero, the task is cancelled outright.
        """
        if gateway.done():
            # It already ended on its own, and `_gateway_ended` already logged why. Awaiting it here
            # would re-raise that same failure and report it a second time as a dirty close. The
            # exception is retrieved so asyncio does not later report it as never retrieved.
            if not gateway.cancelled():
                gateway.exception()
            return
        connection = self._connection
        try:
            if connection is not None and timeout > 0:
                async with asyncio.timeout(timeout):
                    await connection.close()
                    await gateway
                return
        except Exception as error:
            # Broad on purpose: `close()` reaches a websocket and an HTTP session, both of which can
            # fail in ways the library does not narrow. None of them may stop the process leaving.
            self.logger.warning(
                "the Discord connection did not close cleanly",
                extra={"event": "discord.close_failed", "error": f"{type(error).__name__}: {error}"},
            )
        gateway.cancel()
        await asyncio.gather(gateway, return_exceptions=True)

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
