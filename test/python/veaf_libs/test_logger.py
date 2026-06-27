"""Tests for veaf_libs.logger.Logger transient-output routing."""

from __future__ import annotations

import io
import unittest
from unittest.mock import MagicMock, patch

from rich.console import Console
from veaf_libs.logger import Logger, configure_stdio_encoding


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


if __name__ == "__main__":
    unittest.main()
