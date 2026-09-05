"""The entry point, including the two things an operator meets first.

A misconfigured deployment must exit with a code that says *misconfigured* — a supervisor that
restarts on any non-zero code would otherwise loop forever on a missing token — and the readiness
probe the container image calls must actually distinguish a live instance from nothing at all.
"""

from __future__ import annotations

import asyncio
import contextlib
import io
import logging
import socket
import threading
import unittest
from unittest import mock

from veaf_support_bot.cli import EXIT_CONFIG_ERROR, healthcheck, main
from veaf_support_bot.health import HealthServer, ServiceState
from veaf_support_bot.logging_setup import ROOT_LOGGER_NAME, configure_logging


class CaptureLogs(unittest.TestCase):
    """Base class capturing the service's log tree."""

    def setUp(self) -> None:
        self.stream = io.StringIO()
        configure_logging(log_format="text", stream=self.stream)

    def tearDown(self) -> None:
        root = logging.getLogger(ROOT_LOGGER_NAME)
        for handler in list(root.handlers):
            root.removeHandler(handler)
            handler.close()


def _run_main(argv: list[str], env: dict[str, str] | None = None) -> tuple[int, str]:
    """Run ``main`` and capture what an operator would see on stdout.

    ``main`` configures the logging itself — that is the point of the branch under test, since a
    startup failure has to be visible before any configuration is known — so the output is captured
    from the real stream rather than injected.

    Args:
        argv: Command-line arguments.
        env: Environment to run under; the current one is replaced entirely when given.

    Returns:
        The exit code and everything written to stdout.
    """
    buffer = io.StringIO()
    with contextlib.redirect_stdout(buffer):
        if env is None:
            code = main(argv)
        else:
            with mock.patch.dict("os.environ", env, clear=True):
                code = main(argv)
    return code, buffer.getvalue()


class TestArguments(CaptureLogs):
    def test_version_is_reported(self) -> None:
        code, output = _run_main(["--version"])

        self.assertEqual(code, 0)
        self.assertIn("cli.version", output)

    def test_an_unknown_option_is_refused_rather_than_ignored(self) -> None:
        code, output = _run_main(["--serve-everything"])

        self.assertEqual(code, 2)
        self.assertIn("unknown argument", output)


class TestConfigurationFailure(CaptureLogs):
    def test_a_missing_variable_exits_with_the_configuration_code(self) -> None:
        """78 is EX_CONFIG: a supervisor can tell "restarting will not help" from "it crashed"."""
        code, _ = _run_main([], env={})

        self.assertEqual(code, EXIT_CONFIG_ERROR)

    def test_the_failure_names_what_is_missing(self) -> None:
        _, output = _run_main([], env={})

        self.assertIn("SUPPORT_BOT_DISCORD_TOKEN", output)
        self.assertIn("SUPPORT_BOT_DISCORD_GUILD_ID", output)
        self.assertIn("CRITICAL", output)

    def test_the_failure_happens_at_startup_not_at_the_first_request(self) -> None:
        """`main` returns before anything is served: nothing can be bound by a broken deployment."""
        code, _ = _run_main([], env={"SUPPORT_BOT_LOG_FORMAT": "xml"})

        self.assertEqual(code, EXIT_CONFIG_ERROR)


class TestHealthcheckProbe(CaptureLogs):
    """`--healthcheck` is what the image's HEALTHCHECK calls; it has to be able to fail."""

    def _serve(self, ready: bool) -> int:
        """Run a health server on a background loop and return its port.

        Args:
            ready: Whether the served state reports itself ready.

        Returns:
            The bound port.
        """
        state = ServiceState(version="9.9.9")
        if ready:
            state.mark_ready()
        server = HealthServer(state, "127.0.0.1", 0)
        loop = asyncio.new_event_loop()
        port = loop.run_until_complete(server.start())

        thread = threading.Thread(target=loop.run_forever, daemon=True)
        thread.start()

        def _close() -> None:
            asyncio.run_coroutine_threadsafe(server.stop(), loop).result(timeout=5)
            loop.call_soon_threadsafe(loop.stop)
            thread.join(timeout=5)
            loop.close()

        self.addCleanup(_close)
        return port

    def test_a_ready_instance_answers_zero(self) -> None:
        port = self._serve(ready=True)

        self.assertEqual(healthcheck({"SUPPORT_BOT_HEALTH_PORT": str(port)}), 0)

    def test_an_instance_that_is_not_ready_answers_one(self) -> None:
        port = self._serve(ready=False)

        self.assertEqual(healthcheck({"SUPPORT_BOT_HEALTH_PORT": str(port)}), 1)

    def test_nothing_listening_answers_one(self) -> None:
        """The probe has to be able to fail, or a green health check proves nothing."""
        with socket.socket() as free:
            free.bind(("127.0.0.1", 0))
            port = int(free.getsockname()[1])

        self.assertEqual(healthcheck({"SUPPORT_BOT_HEALTH_PORT": str(port)}), 1)
        self.assertIn("readiness probe failed", self.stream.getvalue())

    def test_the_bind_address_is_translated_into_a_dial_address(self) -> None:
        """The image binds 0.0.0.0; connecting to 0.0.0.0 is not portable, so it probes loopback."""
        port = self._serve(ready=True)

        self.assertEqual(healthcheck({"SUPPORT_BOT_HEALTH_HOST": "0.0.0.0", "SUPPORT_BOT_HEALTH_PORT": str(port)}), 0)

    def test_an_ephemeral_port_is_reported_as_unprobeable_not_as_a_dead_service(self) -> None:
        """`HEALTH_PORT=0` is accepted by the configuration but leaves the probe nothing to dial.

        The number the OS picked lives only inside the running process. Dialling port 0 fails with a
        connection error indistinguishable from a dead service, so the probe says what is actually
        wrong instead of blaming the instance.
        """
        self.assertEqual(healthcheck({"SUPPORT_BOT_HEALTH_PORT": "0"}), 1)

        output = self.stream.getvalue()
        self.assertIn("ephemeral port", output)
        self.assertNotIn("readiness probe failed", output)

    def test_an_unreadable_port_falls_back_to_the_default(self) -> None:
        """A probe must not crash on a malformed variable — it falls back and reports the truth."""
        port = self._serve(ready=True)

        with mock.patch("veaf_support_bot.cli.DEFAULT_HEALTH_PORT", port):
            self.assertEqual(healthcheck({"SUPPORT_BOT_HEALTH_PORT": "not-a-port"}), 0)


if __name__ == "__main__":
    unittest.main()
