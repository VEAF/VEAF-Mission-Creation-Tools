"""Tests for veaf_libs.console_status.StatusLine."""

from __future__ import annotations

import unittest
from unittest.mock import MagicMock, patch

from rich.console import Console

from veaf_libs.console_status import StatusLine


class TestStatusLineDisabled(unittest.TestCase):
    def setUp(self) -> None:
        self.console = MagicMock(spec=Console)
        self.status = StatusLine(self.console)

    def test_disabled_by_default(self) -> None:
        self.assertFalse(self.status.enabled)

    def test_update_returns_false_when_disabled(self) -> None:
        self.assertFalse(self.status.update("hello"))

    def test_update_creates_no_live_when_disabled(self) -> None:
        with patch("veaf_libs.console_status.Live") as live_cls:
            self.status.update("hello")
            live_cls.assert_not_called()


class TestStatusLineEnabled(unittest.TestCase):
    def setUp(self) -> None:
        self.console = MagicMock(spec=Console)
        self.status = StatusLine(self.console)
        self.status.configure(enabled=True)

    def test_enabled_after_configure(self) -> None:
        self.assertTrue(self.status.enabled)

    def test_update_returns_true_and_starts_live(self) -> None:
        mock_live = MagicMock()
        with patch("veaf_libs.console_status.Live", return_value=mock_live):
            self.assertTrue(self.status.update("hello"))
            mock_live.start.assert_called_once()
            mock_live.update.assert_called_once()

    def test_update_reuses_single_live(self) -> None:
        mock_live = MagicMock()
        with patch("veaf_libs.console_status.Live", return_value=mock_live) as live_cls:
            self.status.update("a")
            self.status.update("b")
            live_cls.assert_called_once()  # only one Live ever created
            self.assertEqual(mock_live.update.call_count, 2)

    def test_clear_blanks_active_line(self) -> None:
        mock_live = MagicMock()
        with patch("veaf_libs.console_status.Live", return_value=mock_live):
            self.status.update("a")
            self.status.clear()
            self.assertEqual(self.status._text, "")
            self.assertGreaterEqual(mock_live.update.call_count, 2)

    def test_stop_stops_and_resets(self) -> None:
        mock_live = MagicMock()
        with patch("veaf_libs.console_status.Live", return_value=mock_live):
            self.status.update("a")
            self.status.stop()
            mock_live.stop.assert_called_once()
            self.assertEqual(self.status._text, "")
            # next update re-creates a live
            self.status.update("b")
            mock_live.start.assert_called()

    def test_configure_disable_stops_live(self) -> None:
        mock_live = MagicMock()
        with patch("veaf_libs.console_status.Live", return_value=mock_live):
            self.status.update("a")
            self.status.configure(enabled=False)
            mock_live.stop.assert_called_once()
            self.assertFalse(self.status.enabled)
            self.assertFalse(self.status.update("b"))

    def test_suspend_stops_live_and_yields(self) -> None:
        mock_live = MagicMock()
        with patch("veaf_libs.console_status.Live", return_value=mock_live):
            self.status.update("a")
            with self.status.suspend():
                mock_live.stop.assert_called_once()
            # not auto-restarted inside suspend
            self.assertIsNone(self.status._live)

    def test_suspend_noop_when_inactive(self) -> None:
        # No live started yet; suspend must not raise.
        with self.status.suspend():
            pass

    def test_update_during_suspend_does_not_start_live(self) -> None:
        # While suspended (a nested Live owns the display), update must claim
        # the message (return True) without creating a competing Live.
        with patch("veaf_libs.console_status.Live") as live_cls:
            with self.status.suspend():
                self.assertTrue(self.status.update("x"))
                live_cls.assert_not_called()
        # After suspend ends, transient rendering resumes.
        mock_live = MagicMock()
        with patch("veaf_libs.console_status.Live", return_value=mock_live):
            self.assertTrue(self.status.update("y"))
            mock_live.start.assert_called_once()


class TestStatusLineMarkup(unittest.TestCase):
    def test_render_interprets_markup_not_literally(self) -> None:
        status = StatusLine(MagicMock(spec=Console))
        text = status._render("[bold]hi[/bold] world", "cyan")
        # Markup is parsed away from the plain text (indented), not kept literally.
        self.assertEqual(text.plain, "  hi world")
        self.assertNotIn("[bold]", text.plain)


if __name__ == "__main__":
    unittest.main()
