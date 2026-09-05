"""Tests for veaf_libs.logger.Logger transient-output routing, and what reaches the log file.

The file half was added by FEAT-SUPPORT-DIAGNOSTIC ticket 02. Three things changed there, and each
one is pinned below: the stack trace of an exception is written (it never was), an uncaught
exception is journalled before it reaches the terminal (it never was), and the file rotates (it grew
for ever — measured at 87 MB on a real machine, which is why nobody ever opened it).

The constraint on all three is that **the console must not move**. So the tests assert not only what
the file gains, but what the console still shows: exactly the message, and nothing more.
"""

from __future__ import annotations

import io
import logging
import logging.handlers
import sys
import unittest
from pathlib import Path
from tempfile import TemporaryDirectory
from unittest.mock import MagicMock, patch

from rich.console import Console
from veaf_libs import logger as logger_module
from veaf_libs.logger import Logger, configure_stdio_encoding, install_excepthook


def _recording_console() -> Console:
    """Return a Console that records output for inspection in tests."""
    return Console(file=io.StringIO(), record=True, force_terminal=False, width=200)


class TestConfigureStdioEncoding(unittest.TestCase):
    def test_reconfigures_stdout_and_stderr_to_utf8(self) -> None:
        out, err = MagicMock(), MagicMock()
        with patch("sys.stdout", out), patch("sys.stderr", err):
            configure_stdio_encoding()
        out.reconfigure.assert_called_once_with(encoding="utf-8", errors="replace")
        err.reconfigure.assert_called_once_with(encoding="utf-8", errors="replace")

    def test_stream_without_reconfigure_is_skipped(self) -> None:
        plain = io.StringIO()  # no reconfigure attribute
        with patch("sys.stdout", plain), patch("sys.stderr", plain):
            configure_stdio_encoding()  # must not raise

    def test_reconfigure_failure_is_swallowed(self) -> None:
        bad = MagicMock()
        bad.reconfigure.side_effect = ValueError("cannot reconfigure")
        with patch("sys.stdout", bad), patch("sys.stderr", bad):
            configure_stdio_encoding()  # must not raise


class TestLoggerInfoRouting(unittest.TestCase):
    def test_info_prints_permanently_when_status_disabled(self) -> None:
        console = _recording_console()
        log = Logger(logger_name="test-logger-info", console=console)
        # status exists but disabled by default → permanent print
        log.info("plain info line")
        self.assertIn("plain info line", console.export_text())

    def test_info_routes_to_status_when_enabled(self) -> None:
        console = _recording_console()
        log = Logger(logger_name="test-logger-info2", console=console)
        log.status = MagicMock()
        log.status.update.return_value = True  # claims it displayed transiently
        log.info("secret transient line")
        log.status.update.assert_called_once()
        # Not printed permanently because the status line handled it.
        self.assertNotIn("secret transient line", console.export_text())


class TestMuteConsole(unittest.TestCase):
    """A stdio MCP server must never let a log line reach stdout (JSON-RPC only)."""

    def test_mute_console_silences_rich_output(self) -> None:
        console = _recording_console()
        log = Logger(logger_name="test-logger-mute", console=console)
        log.mute_console()
        self.assertIsNone(log.console)
        self.assertIsNone(log.status)
        log.info("must not reach stdout")  # no console → nothing printed
        self.assertEqual(console.export_text(), "")

    def test_info_falls_back_when_status_declines(self) -> None:
        console = _recording_console()
        log = Logger(logger_name="test-logger-info3", console=console)
        log.status = MagicMock()
        log.status.update.return_value = False  # declined → permanent print
        log.info("fallback line")
        self.assertIn("fallback line", console.export_text())

    def test_info_no_console_suppresses_output(self) -> None:
        console = _recording_console()
        log = Logger(logger_name="test-logger-info4", console=console)
        log.info("hidden line", no_console=True)
        self.assertNotIn("hidden line", console.export_text())


class TestLoggerPermanentLines(unittest.TestCase):
    def test_tech_always_prints(self) -> None:
        console = _recording_console()
        log = Logger(logger_name="test-logger-tech", console=console)
        log.status = MagicMock()
        log.status.update.return_value = True  # even if status enabled
        log.tech("technical permanent line")
        self.assertIn("technical permanent line", console.export_text())
        log.status.update.assert_not_called()

    def test_step_prints_header_with_message(self) -> None:
        console = _recording_console()
        log = Logger(logger_name="test-logger-step", console=console)
        log.step("Pipeline stage")
        self.assertIn("Pipeline stage", console.export_text())

    def test_step_interprets_markup_in_message(self) -> None:
        console = _recording_console()
        log = Logger(logger_name="test-logger-step3", console=console)
        log.step("[bold blue]Chapter[/bold blue]")
        text = console.export_text()
        self.assertIn("Chapter", text)
        self.assertNotIn("[bold blue]", text)  # markup rendered, not literal

    def test_step_clears_status_line(self) -> None:
        console = _recording_console()
        log = Logger(logger_name="test-logger-step2", console=console)
        log.status = MagicMock()
        log.step("Stage")
        log.status.clear.assert_called_once()


class TestLoggerVerboseConfiguresStatus(unittest.TestCase):
    def _logger_with_mock_status(self, name: str, *, terminal: bool) -> Logger:
        # force_terminal drives Console.is_terminal, which set_verbose reads.
        console = Console(file=io.StringIO(), force_terminal=terminal, width=200)
        log = Logger(logger_name=name, console=console)
        log.status = MagicMock()
        return log

    def test_verbose_disables_transient(self) -> None:
        log = self._logger_with_mock_status("test-logger-v1", terminal=True)
        log.set_verbose(True)
        log.status.configure.assert_called_once_with(enabled=False)

    def test_interactive_non_verbose_enables_transient(self) -> None:
        log = self._logger_with_mock_status("test-logger-v2", terminal=True)
        log.set_verbose(False)
        log.status.configure.assert_called_once_with(enabled=True)

    def test_non_interactive_disables_transient(self) -> None:
        log = self._logger_with_mock_status("test-logger-v3", terminal=False)
        log.set_verbose(False)
        log.status.configure.assert_called_once_with(enabled=False)

    def test_stop_status_stops_line(self) -> None:
        log = self._logger_with_mock_status("test-logger-stop", terminal=True)
        log.stop_status()
        log.status.stop.assert_called_once()


class _FileLoggerCase(unittest.TestCase):
    """Base for tests that read the log file back.

    Each test gets its own ``VEAF_HOME`` and its own logger name: ``logging.getLogger`` is a
    process-wide registry, so a shared name would reuse the previous test's file handler and read
    the wrong file.
    """

    def setUp(self) -> None:
        self._tmp = TemporaryDirectory()
        self.home = Path(self._tmp.name)
        self._env = patch.dict("os.environ", {"VEAF_HOME": str(self.home)})
        self._env.start()
        self.addCleanup(self._env.stop)
        self.addCleanup(self._tmp.cleanup)

    def make_logger(self, name: str, console: Console | None = None) -> Logger:
        """Build a logger writing into this test's home, and close its handlers afterwards."""
        log = Logger(logger_name=name, console=console)
        self.addCleanup(lambda: [handler.close() for handler in log.logger.handlers])
        self.addCleanup(log.logger.handlers.clear)
        return log

    def read_log(self, name: str) -> str:
        return (self.home / f"{name}.log").read_text(encoding="utf-8")


class TestTheLogFileRecordsStackTraces(_FileLoggerCase):
    """`exception()` used to write the message and drop the only part that says where it broke."""

    def test_the_traceback_reaches_the_file(self) -> None:
        name = "test-logger-trace"
        log = self.make_logger(name)
        try:
            raise ValueError("boom")
        except ValueError as caught:
            with self.assertRaises(ValueError):
                log.exception(caught)
        written = self.read_log(name)
        self.assertIn("boom", written)
        self.assertIn("Traceback (most recent call last)", written)
        self.assertIn("test_the_traceback_reaches_the_file", written)

    def test_a_cause_chain_is_written_whole(self) -> None:
        name = "test-logger-chain"
        log = self.make_logger(name)
        try:
            try:
                raise KeyError("root cause")
            except KeyError as root:
                raise RuntimeError("outer failure") from root
        except RuntimeError as caught:
            with self.assertRaises(RuntimeError):
                log.exception(caught)
        written = self.read_log(name)
        self.assertIn("root cause", written)
        self.assertIn("outer failure", written)

    def test_the_console_still_shows_the_message_and_nothing_else(self) -> None:
        # The trace goes to the file sink only: what the user reads must not move.
        console = _recording_console()
        log = self.make_logger("test-logger-trace-console", console)
        try:
            raise ValueError("boom")
        except ValueError as caught:
            with self.assertRaises(ValueError):
                log.exception(caught)
        self.assertEqual(console.export_text().strip(), "boom")

    def test_a_plain_error_writes_no_traceback(self) -> None:
        name = "test-logger-plain"
        log = self.make_logger(name)
        with self.assertRaises(RuntimeError):
            log.error("plain failure", exception_type=RuntimeError)
        self.assertNotIn("Traceback", self.read_log(name))


class TestUncaughtExceptionsAreJournalled(_FileLoggerCase):
    """A crash used to leave a traceback on stderr and nothing at all in the log."""

    def setUp(self) -> None:
        super().setUp()
        original = sys.excepthook
        self.addCleanup(lambda: setattr(sys, "excepthook", original))

    def _raise_through(self, hook, error: BaseException) -> None:
        try:
            raise error
        except BaseException:
            hook(*sys.exc_info())  # type: ignore[misc]

    def test_the_crash_is_written_to_the_file(self) -> None:
        name = "test-logger-uncaught"
        log = self.make_logger(name)
        with patch.object(sys, "excepthook", lambda *args: None):
            hook = install_excepthook(log)
            self._raise_through(hook, ValueError("unhandled boom"))
        written = self.read_log(name)
        self.assertIn("ValueError: unhandled boom", written)
        self.assertIn("Traceback (most recent call last)", written)

    def test_the_user_still_sees_what_they_saw_before(self) -> None:
        # The previous hook is called with the same arguments: stderr output is unchanged.
        seen: list[tuple] = []
        with patch.object(sys, "excepthook", lambda *args: seen.append(args)):
            hook = install_excepthook(self.make_logger("test-logger-uncaught-chain"))
            self._raise_through(hook, ValueError("boom"))
        self.assertEqual(len(seen), 1)
        self.assertIs(seen[0][0], ValueError)

    def test_a_ctrl_c_is_passed_through_without_being_journalled(self) -> None:
        name = "test-logger-interrupt"
        log = self.make_logger(name)
        seen: list[tuple] = []
        with patch.object(sys, "excepthook", lambda *args: seen.append(args)):
            hook = install_excepthook(log)
            self._raise_through(hook, KeyboardInterrupt())
        self.assertEqual(len(seen), 1, "the interrupt must still reach the previous hook")
        self.assertNotIn("KeyboardInterrupt", self.read_log(name))

    def test_installing_twice_does_not_chain_twice(self) -> None:
        log = self.make_logger("test-logger-idempotent")
        seen: list[tuple] = []
        with patch.object(sys, "excepthook", lambda *args: seen.append(args)):
            install_excepthook(log)
            hook = install_excepthook(log)
            self._raise_through(hook, ValueError("boom"))
        self.assertEqual(len(seen), 1, "the original hook must be called once, not once per install")


class TestTheLogFileRotates(_FileLoggerCase):
    """It appended for ever, which is exactly why nobody read it."""

    def test_rotation_fires_and_keeps_the_backup(self) -> None:
        name = "test-logger-rotation"
        with patch.object(logger_module, "LOG_MAX_BYTES", 512), patch.object(logger_module, "LOG_BACKUP_COUNT", 2):
            log = self.make_logger(name)
            for index in range(200):
                log.info(f"line {index} " + "x" * 80, no_console=True)
        self.assertTrue((self.home / f"{name}.log.1").is_file(), "no backup file: rotation never fired")
        self.assertLess((self.home / f"{name}.log").stat().st_size, 4096)

    def test_retention_is_bounded(self) -> None:
        name = "test-logger-retention"
        with patch.object(logger_module, "LOG_MAX_BYTES", 256), patch.object(logger_module, "LOG_BACKUP_COUNT", 2):
            log = self.make_logger(name)
            for index in range(400):
                log.info(f"line {index} " + "x" * 80, no_console=True)
        backups = sorted(self.home.glob(f"{name}.log.*"))
        self.assertEqual(len(backups), 2, "backupCount must cap how many rolled files survive")

    def test_the_handler_is_a_rotating_one(self) -> None:
        log = self.make_logger("test-logger-handler-kind")
        self.assertIsInstance(log.logger.handlers[0], logging.handlers.RotatingFileHandler)


if __name__ == "__main__":
    unittest.main()
