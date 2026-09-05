"""The wiring, not the handler.

Four bugs shipped green on this repository because the tests called the handler and never the thing
that branches to it: the subscription, the schedule, the keyword filter. The handler worked; nothing
called it. So this file asserts only the connections, each one where cutting it would leave every
other test in this suite still passing:

* ``/ask`` is **registered** on the command tree, with the name and the option Discord will send;
* the registered callback **reaches the handler**, with the interaction's user, locale and question;
* an exchange is **tracked**, so a shutdown drains it instead of abandoning a placeholder;
* the gateway **publishes readiness**, and a disconnection withdraws it;
* the service **builds its counters from the configuration**, rather than from defaults;
* the handler the service runs uses **those** counters, not a second set nobody enforces;
* ``/status`` **reports** them.

Each of these is proved to detect a regression: ``TestTheseTestsDetectABrokenWiring`` cuts the wire
and asserts the corresponding test fails.
"""

from __future__ import annotations

import asyncio
import io
import json
import tempfile
import unittest
from pathlib import Path
from typing import Any, cast

import discord
from discord import app_commands

from tests.fakes import FakeWorker, RecordingExchange
from tests.http_probe import request
from veaf_support_bot import discord_bot
from veaf_support_bot.ask import AskContext, AskHandler
from veaf_support_bot.config import SupportBotConfig
from veaf_support_bot.discord_bot import QUESTION_MAX_LENGTH, register_commands
from veaf_support_bot.health import ServiceState
from veaf_support_bot.logging_setup import get_logger
from veaf_support_bot.quota import QuotaKeeper, QuotaLimits, QuotaStore
from veaf_support_bot.service import InFlightTasks, SupportBotService


def _config(**overrides: str) -> SupportBotConfig:
    """Build a configuration bound to an ephemeral port.

    Args:
        **overrides: Extra environment entries, without the ``SUPPORT_BOT_`` prefix.

    Returns:
        The resolved configuration.
    """
    env = {
        "SUPPORT_BOT_DISCORD_TOKEN": "a-token",
        "SUPPORT_BOT_DISCORD_GUILD_ID": "1",
        "SUPPORT_BOT_WORKER_SECRET": "a-secret",
        "SUPPORT_BOT_HEALTH_PORT": "0",
        "SUPPORT_BOT_SHUTDOWN_GRACE_SECONDS": "0.3",
        "SUPPORT_BOT_HEARTBEAT_SECONDS": "0.05",
    }
    env.update({f"SUPPORT_BOT_{key}": value for key, value in overrides.items()})
    return SupportBotConfig.from_env(env)


class _RecordingHandler:
    """An :class:`~veaf_support_bot.ask.AskHandler` stand-in that records what reached it."""

    def __init__(self) -> None:
        """Initialize the recorder."""
        self.contexts: list[AskContext] = []

    async def handle(self, exchange: Any, context: AskContext) -> None:
        """Record one exchange.

        Args:
            exchange: The Discord side, unused.
            context: The question and who asked it.
        """
        self.contexts.append(context)


class _FakeUser:
    """The parts of ``discord.User`` the command reads."""

    def __init__(self, user_id: int = 4242, display_name: str = "Zip") -> None:
        """Initialize the user.

        Args:
            user_id: The Discord id.
            display_name: The display name.
        """
        self.id = user_id
        self.display_name = display_name


class _FakeInteraction:
    """The parts of ``discord.Interaction`` the command reads."""

    def __init__(self, locale: str = "fr") -> None:
        """Initialize the interaction.

        Args:
            locale: The reported locale.
        """
        self.user = _FakeUser()
        self.locale = locale


def _ask_command(tree: app_commands.CommandTree) -> app_commands.Command[Any, Any, Any]:
    """Return the registered ``/ask`` command.

    Args:
        tree: The tree to look in.

    Returns:
        The command.

    Raises:
        AssertionError: When nothing named ``ask`` is registered — which is the wiring bug itself.
    """
    command = tree.get_command("ask")
    assert command is not None, "no /ask command is registered on the tree"
    return cast(app_commands.Command[Any, Any, Any], command)


class _Tree:
    """A command tree over a client that is never connected."""

    def __init__(self) -> None:
        """Build the tree."""
        self.client = discord.Client(intents=discord.Intents.none())
        self.tree = app_commands.CommandTree(self.client)


class TestTheCommandIsRegistered(unittest.TestCase):
    """A handler that works and a command nobody attached answers nobody."""

    def setUp(self) -> None:
        """Register the commands on a fresh tree."""
        self.holder = _Tree()
        self.handler = _RecordingHandler()
        register_commands(self.holder.tree, cast(AskHandler, self.handler), get_logger("test"))

    def test_ask_is_on_the_tree(self) -> None:
        self.assertIsNotNone(self.holder.tree.get_command("ask"))

    def test_it_declares_the_question_option_discord_will_send(self) -> None:
        parameters = {parameter.name for parameter in _ask_command(self.holder.tree).parameters}

        self.assertIn("question", parameters)

    def test_the_question_option_is_required(self) -> None:
        """An optional question would let Discord send an interaction with nothing to answer."""
        question = next(p for p in _ask_command(self.holder.tree).parameters if p.name == "question")

        self.assertTrue(question.required)

    def test_the_option_is_bounded_the_way_the_service_is(self) -> None:
        question = next(p for p in _ask_command(self.holder.tree).parameters if p.name == "question")

        self.assertEqual(question.max_value, QUESTION_MAX_LENGTH)

    def test_it_carries_a_description_users_will_read(self) -> None:
        self.assertTrue(_ask_command(self.holder.tree).description.strip())


class TestTheCommandReachesTheHandler(unittest.IsolatedAsyncioTestCase):
    """Registering a command that calls nothing is the same bug one layer down."""

    def setUp(self) -> None:
        """Register the commands on a fresh tree."""
        self.holder = _Tree()
        self.handler = _RecordingHandler()
        register_commands(self.holder.tree, cast(AskHandler, self.handler), get_logger("test"))

    async def _invoke(self, question: str = "comment builder ?", locale: str = "fr") -> None:
        """Invoke the registered callback the way Discord would.

        Args:
            question: The question option.
            locale: The interaction locale.
        """
        callback = cast(Any, _ask_command(self.holder.tree).callback)
        await callback(_FakeInteraction(locale), question)

    async def test_the_question_reaches_the_handler(self) -> None:
        await self._invoke(question="comment builder ?")

        self.assertEqual(self.handler.contexts[0].question, "comment builder ?")

    async def test_the_asker_reaches_the_handler_as_the_quota_subject(self) -> None:
        await self._invoke()

        self.assertEqual(self.handler.contexts[0].user_id, "4242")

    async def test_the_locale_reaches_the_handler(self) -> None:
        """Without it every English speaker is answered in French, and nothing crashes."""
        await self._invoke(locale="en-GB")

        self.assertEqual(self.handler.contexts[0].locale, "en-GB")

    async def test_the_display_name_reaches_the_handler(self) -> None:
        await self._invoke()

        self.assertEqual(self.handler.contexts[0].user_display, "Zip")


class TestTheExchangeIsDrainable(unittest.IsolatedAsyncioTestCase):
    """An untracked exchange is one ``docker stop`` cuts in half."""

    async def test_the_exchange_is_registered_with_the_shutdown_registry(self) -> None:
        holder = _Tree()
        tasks = InFlightTasks()
        seen: list[int] = []

        class _SlowHandler:
            async def handle(self, exchange: Any, context: AskContext) -> None:
                seen.append(len(tasks))

        register_commands(holder.tree, cast(AskHandler, _SlowHandler()), get_logger("test"), tasks)
        callback = cast(Any, _ask_command(holder.tree).callback)

        await callback(_FakeInteraction(), "q")

        self.assertEqual(seen, [1], "the exchange was not tracked while it ran")

    async def test_the_exchange_is_awaited_not_fired_and_forgotten(self) -> None:
        """The interaction has to stay alive for the whole exchange, so the callback must await."""
        holder = _Tree()
        tasks = InFlightTasks()
        finished: list[str] = []

        class _SlowHandler:
            async def handle(self, exchange: Any, context: AskContext) -> None:
                await asyncio.sleep(0.02)
                finished.append("done")

        register_commands(holder.tree, cast(AskHandler, _SlowHandler()), get_logger("test"), tasks)
        callback = cast(Any, _ask_command(holder.tree).callback)

        await callback(_FakeInteraction(), "q")

        self.assertEqual(finished, ["done"])


class TestReadinessFollowsTheGateway(unittest.IsolatedAsyncioTestCase):
    """A process with no gateway must not certify itself fit to serve."""

    def _client(self) -> tuple[discord_bot.SupportBotClient, ServiceState]:
        """Build a client that is never connected.

        Returns:
            The client and the state it publishes on.
        """
        state = ServiceState(version="test")
        handler = cast(AskHandler, _RecordingHandler())
        client = discord_bot.SupportBotClient(_config(), state, handler)
        self.addCleanup(lambda: asyncio.get_event_loop().is_closed())
        return client, state

    async def test_a_connected_gateway_publishes_readiness(self) -> None:
        client, state = self._client()
        self.assertFalse(state.ready)

        await client.on_ready()

        self.assertTrue(state.ready)

    async def test_a_disconnection_withdraws_readiness(self) -> None:
        client, state = self._client()
        await client.on_ready()

        await client.on_disconnect()

        self.assertFalse(state.ready)

    async def test_a_resumed_session_publishes_readiness_again(self) -> None:
        client, state = self._client()
        await client.on_ready()
        await client.on_disconnect()

        await client.on_resumed()

        self.assertTrue(state.ready)


class TestTheServiceWiresItsOwnPieces(unittest.IsolatedAsyncioTestCase):
    """The counters the configuration describes, and the handler that actually enforces them."""

    def setUp(self) -> None:
        """Give each test a private counters file."""
        self._directory = tempfile.TemporaryDirectory()
        self.addCleanup(self._directory.cleanup)
        self.state_file = str(Path(self._directory.name) / "quota.json")

    def _service(self, **overrides: str) -> SupportBotService:
        """Build a service on the test's own counters file.

        Args:
            **overrides: Extra environment entries.

        Returns:
            The service.
        """
        return SupportBotService(_config(QUOTA_STATE_FILE=self.state_file, **overrides))

    async def test_the_configured_ceilings_are_the_ones_enforced(self) -> None:
        """A keeper built from defaults would enforce numbers nobody configured."""
        service = self._service(QUOTA_GLOBAL_PER_DAY="7", QUOTA_USER_PER_DAY="5", QUOTA_USER_PER_WINDOW="2")

        self.assertEqual(service.quota.limits.global_per_day, 7)
        self.assertEqual(service.quota.limits.user_per_day, 5)
        self.assertEqual(service.quota.limits.user_per_window, 2)

    async def test_the_counters_are_kept_where_the_configuration_says(self) -> None:
        service = self._service()

        service.quota.check_and_consume("u1")

        self.assertTrue(Path(self.state_file).is_file())

    async def test_the_handler_enforces_the_service_s_own_counters(self) -> None:
        """A handler wired to a second keeper would count, and refuse, nothing."""
        service = self._service(QUOTA_USER_PER_WINDOW="1", QUOTA_USER_PER_DAY="1")
        worker = FakeWorker(["ok"])
        service.handler._worker = cast(Any, worker)  # noqa: SLF001 - asserting the wiring is the point

        await service.handler.handle(RecordingExchange(), AskContext("u1", "Zip", "q", "fr"))
        await service.handler.handle(RecordingExchange(), AskContext("u1", "Zip", "q", "fr"))

        self.assertEqual(len(worker.seen), 1)
        self.assertEqual(service.quota.snapshot()["global_count"], 1)

    async def test_the_status_endpoint_reports_the_day_s_spend(self) -> None:
        service = self._service()
        service.quota.check_and_consume("u1")
        await service.health.start()
        self.addCleanup(lambda: None)

        _, body = await request(cast(int, service.health.port), "/status")
        await service.health.stop(timeout=0.2)

        assert body is not None
        self.assertEqual(body["details"]["global_count"], 1)

    async def test_the_status_endpoint_says_when_the_counters_are_not_kept(self) -> None:
        Path(self.state_file).parent.mkdir(parents=True, exist_ok=True)
        Path(self.state_file).write_text("{", encoding="utf-8")
        service = self._service()
        await service.health.start()

        _, body = await request(cast(int, service.health.port), "/status")
        await service.health.stop(timeout=0.2)

        assert body is not None
        self.assertTrue(body["details"]["degraded"])

    async def test_no_discord_identity_reaches_the_status_endpoint(self) -> None:
        service = self._service()
        service.quota.check_and_consume("a-very-recognisable-user")
        await service.health.start()

        _, body = await request(cast(int, service.health.port), "/status")
        await service.health.stop(timeout=0.2)

        self.assertNotIn("a-very-recognisable-user", json.dumps(body))


class TestADryRunIsNeverReady(unittest.IsolatedAsyncioTestCase):
    """It answers nobody. A readiness probe must say so, or it certifies an empty service."""

    async def _run_briefly(self, **overrides: str) -> tuple[SupportBotService, int, dict[str, Any]]:
        """Start a service, probe ``/readyz``, stop it.

        Args:
            **overrides: Extra environment entries.

        Returns:
            The service, the status code and the body ``/readyz`` answered with.
        """
        service = SupportBotService(_config(**overrides))
        runner = asyncio.ensure_future(service.run())
        for _ in range(100):
            await asyncio.sleep(0.01)
            if service.health.port is not None:
                break
        status, body = await request(cast(int, service.health.port), "/readyz")
        service.request_stop("test")
        await runner
        assert body is not None
        return service, status, body

    async def test_readiness_is_refused(self) -> None:
        _, status, _ = await self._run_briefly(DRY_RUN="true")

        self.assertEqual(status, 503)

    async def test_it_says_why(self) -> None:
        _, _, body = await self._run_briefly(DRY_RUN="true")

        self.assertEqual(body["not_ready_reason"], "dry-run")

    async def test_liveness_still_answers_because_the_process_is_alive(self) -> None:
        """Restarting would not connect a gateway it was told not to open, so it is not a restart."""
        service = SupportBotService(_config(DRY_RUN="true"))
        runner = asyncio.ensure_future(service.run())
        for _ in range(100):
            await asyncio.sleep(0.01)
            if service.health.port is not None:
                break

        status, _ = await request(cast(int, service.health.port), "/healthz")
        service.request_stop("test")
        await runner

        self.assertEqual(status, 200)


class TestTheGatewayLifecycle(unittest.IsolatedAsyncioTestCase):
    """A live process whose connection died is the silent death the service must not have."""

    class _Gateway:
        """A gateway the test drives."""

        def __init__(self, fail: Exception | None = None) -> None:
            self.started = False
            self.closed = False
            self._fail = fail
            self._stop = asyncio.Event()

        async def start(self) -> None:
            self.started = True
            if self._fail is not None:
                raise self._fail
            await self._stop.wait()

        async def close(self) -> None:
            self.closed = True
            self._stop.set()

    async def _run(self, gateway: Any, stop_after: float = 0.1) -> SupportBotService:
        """Run a service over a fake gateway.

        Args:
            gateway: The gateway to use.
            stop_after: Seconds before asking it to stop.

        Returns:
            The service.
        """
        service = SupportBotService(_config(), gateway=gateway)
        runner = asyncio.ensure_future(service.run())
        await asyncio.sleep(stop_after)
        service.request_stop("test")
        await runner
        return service

    async def test_the_gateway_is_started(self) -> None:
        gateway = self._Gateway()

        await self._run(gateway)

        self.assertTrue(gateway.started)

    async def test_the_gateway_is_closed_on_shutdown(self) -> None:
        gateway = self._Gateway()

        await self._run(gateway)

        self.assertTrue(gateway.closed)

    async def test_a_connection_that_dies_takes_the_process_down(self) -> None:
        """Otherwise the container stays up, healthy-looking, answering nobody, for days."""
        service = SupportBotService(_config(), gateway=self._Gateway(fail=RuntimeError("bad token")))

        await asyncio.wait_for(service.run(), timeout=2)

        self.assertFalse(service.state.ready)

    async def test_the_failure_is_reported_rather_than_swallowed(self) -> None:
        service = SupportBotService(_config(), gateway=self._Gateway(fail=RuntimeError("bad token")))

        await asyncio.wait_for(service.run(), timeout=2)

        self.assertIn("bad token", str(service.state.snapshot()["last_error"]))


class TestTheseTestsDetectABrokenWiring(unittest.IsolatedAsyncioTestCase):
    """The tests above are only worth their runtime if cutting the wire turns them red.

    Each case here severs one connection and asserts the matching test fails. A green suite over a
    disconnected service is exactly what shipped four bugs here before.
    """

    def _run(self, case: type[unittest.TestCase], name: str) -> unittest.TestResult:
        """Run one test method and return its result.

        Args:
            case: The test class.
            name: The method name.

        Returns:
            The result.
        """
        return unittest.TextTestRunner(stream=io.StringIO()).run(case(name))

    def _assert_detects(self, case: type[unittest.TestCase], name: str) -> None:
        """Assert that a test method fails.

        Args:
            case: The test class.
            name: The method name.
        """
        result = self._run(case, name)
        self.assertFalse(result.wasSuccessful(), f"{case.__name__}.{name} passed with the wiring cut")

    def test_unregistering_the_command_is_detected(self) -> None:
        original = register_commands

        def _no_registration(*_: Any, **__: Any) -> None:
            return None

        setattr(discord_bot, "register_commands", _no_registration)
        globals()["register_commands"] = _no_registration
        try:
            self._assert_detects(TestTheCommandIsRegistered, "test_ask_is_on_the_tree")
        finally:
            setattr(discord_bot, "register_commands", original)
            globals()["register_commands"] = original

    def test_a_callback_that_never_calls_the_handler_is_detected(self) -> None:
        original = _RecordingHandler.handle

        async def _never_records(self: Any, exchange: Any, context: AskContext) -> None:
            return None

        setattr(_RecordingHandler, "handle", _never_records)
        try:
            self._assert_detects(TestTheCommandReachesTheHandler, "test_the_question_reaches_the_handler")
        finally:
            setattr(_RecordingHandler, "handle", original)

    def test_dropping_the_locale_is_detected(self) -> None:
        """The bug that answers every English speaker in French while nothing crashes."""
        original = discord_bot.AskContext

        class _LocaleLosingContext(AskContext):
            def __init__(self, *args: Any, **kwargs: Any) -> None:
                kwargs.pop("locale", None)
                super().__init__(*args, **kwargs)

        setattr(discord_bot, "AskContext", _LocaleLosingContext)
        try:
            self._assert_detects(TestTheCommandReachesTheHandler, "test_the_locale_reaches_the_handler")
        finally:
            setattr(discord_bot, "AskContext", original)

    def test_an_untracked_exchange_is_detected(self) -> None:
        original = InFlightTasks.track

        def _untracked(self: Any, coro: Any, name: str | None = None) -> Any:
            return asyncio.ensure_future(coro)

        setattr(InFlightTasks, "track", _untracked)
        try:
            self._assert_detects(
                TestTheExchangeIsDrainable, "test_the_exchange_is_registered_with_the_shutdown_registry"
            )
        finally:
            setattr(InFlightTasks, "track", original)

    def test_a_gateway_that_never_publishes_readiness_is_detected(self) -> None:
        original = discord_bot.SupportBotClient.on_ready

        async def _silent(self: Any) -> None:
            return None

        setattr(discord_bot.SupportBotClient, "on_ready", _silent)
        try:
            self._assert_detects(TestReadinessFollowsTheGateway, "test_a_connected_gateway_publishes_readiness")
        finally:
            setattr(discord_bot.SupportBotClient, "on_ready", original)

    def test_counters_built_from_defaults_instead_of_the_configuration_is_detected(self) -> None:
        import veaf_support_bot.service as service_module

        original = service_module.build_quota

        def _defaults(config: Any, logger: Any = None) -> QuotaKeeper:
            return QuotaKeeper(QuotaLimits(), QuotaStore(Path(config.quota_state_file)), logger=logger)

        setattr(service_module, "build_quota", _defaults)
        try:
            self._assert_detects(TestTheServiceWiresItsOwnPieces, "test_the_configured_ceilings_are_the_ones_enforced")
        finally:
            setattr(service_module, "build_quota", original)

    def test_a_handler_wired_to_other_counters_is_detected(self) -> None:
        """The bug where the quota exists, is correct, and gates nothing."""
        import veaf_support_bot.service as service_module

        original = service_module.build_handler

        def _own_keeper(config: Any, quota: QuotaKeeper, **kwargs: Any) -> AskHandler:
            return original(config, QuotaKeeper(QuotaLimits(user_per_window=99, user_per_day=99)), **kwargs)

        setattr(service_module, "build_handler", _own_keeper)
        try:
            self._assert_detects(
                TestTheServiceWiresItsOwnPieces, "test_the_handler_enforces_the_service_s_own_counters"
            )
        finally:
            setattr(service_module, "build_handler", original)

    def test_a_dry_run_that_declares_itself_ready_is_detected(self) -> None:
        """The exact regression the skeleton's review left as a warning for this lot."""
        import veaf_support_bot.service as service_module

        original = service_module.SupportBotService._shutdown

        async def _mark_ready_anyway(self: Any, *args: Any, **kwargs: Any) -> None:
            await original(self, *args, **kwargs)

        # Cut the wire where it actually is: readiness withheld in a dry run.
        state_original = service_module.ServiceState.mark_not_ready

        def _ignore_dry_run(self: Any, reason: str) -> None:
            if reason == "dry-run":
                self.mark_ready()
                return
            state_original(self, reason)

        setattr(service_module.ServiceState, "mark_not_ready", _ignore_dry_run)
        try:
            self._assert_detects(TestADryRunIsNeverReady, "test_readiness_is_refused")
        finally:
            setattr(service_module.ServiceState, "mark_not_ready", state_original)

    def test_a_dead_connection_that_leaves_the_process_up_is_detected(self) -> None:
        import veaf_support_bot.service as service_module

        original = service_module.SupportBotService._gateway_ended

        def _ignore(self: Any, task: Any) -> None:
            return None

        setattr(service_module.SupportBotService, "_gateway_ended", _ignore)
        try:
            result = unittest.TextTestRunner(stream=io.StringIO()).run(
                TestTheGatewayLifecycle("test_a_connection_that_dies_takes_the_process_down")
            )

            self.assertFalse(result.wasSuccessful(), "a dead connection left the process running, undetected")
        finally:
            setattr(service_module.SupportBotService, "_gateway_ended", original)


if __name__ == "__main__":
    unittest.main()
