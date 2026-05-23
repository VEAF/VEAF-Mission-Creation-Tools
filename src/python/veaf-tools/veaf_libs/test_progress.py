"""Tests for veaf_libs.progress — spinner_context and progress_context."""

from __future__ import annotations

import unittest
from unittest.mock import MagicMock, patch

from veaf_libs.progress import SpinnerControl, progress_context, spinner_context


class TestSpinnerContextSilent(unittest.TestCase):
    def test_silent_yields_spinner_control(self) -> None:
        with spinner_context("Testing...", silent=True) as ctrl:
            self.assertIsInstance(ctrl, SpinnerControl)

    def test_silent_done_message_passthrough(self) -> None:
        with spinner_context("Testing...", done_message="Done!", silent=True) as ctrl:
            self.assertEqual(ctrl.done_message, "Done!")

    def test_silent_no_exception(self) -> None:
        with spinner_context("Loading...", silent=True):
            pass  # Should complete without error

    def test_silent_allows_done_message_override(self) -> None:
        with spinner_context("Testing...", silent=True) as ctrl:
            ctrl.done_message = "Override!"
        self.assertEqual(ctrl.done_message, "Override!")


class TestSpinnerContextNonSilent(unittest.TestCase):
    def test_non_silent_yields_control(self) -> None:
        mock_live = MagicMock()
        mock_live.__enter__ = MagicMock(return_value=mock_live)
        mock_live.__exit__ = MagicMock(return_value=False)
        with patch("veaf_libs.progress.Live", return_value=mock_live):
            with spinner_context("Testing...", silent=False) as ctrl:
                self.assertIsInstance(ctrl, SpinnerControl)

    def test_non_silent_with_done_message(self) -> None:
        mock_live = MagicMock()
        mock_live.__enter__ = MagicMock(return_value=mock_live)
        mock_live.__exit__ = MagicMock(return_value=False)
        with patch("veaf_libs.progress.Live", return_value=mock_live):
            with spinner_context("Testing...", done_message="Completed!", silent=False) as ctrl:
                self.assertIsInstance(ctrl, SpinnerControl)

    def test_non_silent_exception_propagates(self) -> None:
        mock_live = MagicMock()
        mock_live.__enter__ = MagicMock(return_value=mock_live)
        mock_live.__exit__ = MagicMock(return_value=False)
        with patch("veaf_libs.progress.Live", return_value=mock_live):
            with self.assertRaises(ValueError):
                with spinner_context("Testing...", silent=False):
                    raise ValueError("test error")

    def test_non_silent_no_done_message_auto_generated(self) -> None:
        mock_live = MagicMock()
        with patch("veaf_libs.progress.Live", return_value=mock_live):
            with spinner_context("Loading...", silent=False):
                pass
            mock_live.start.assert_called_once()


class TestProgressContextSilent(unittest.TestCase):
    def test_silent_iterates_collection(self) -> None:
        result = []
        with progress_context([1, 2, 3], "Processing...", silent=True) as items:
            for item in items:
                result.append(item)
        self.assertEqual(result, [1, 2, 3])

    def test_silent_empty_collection(self) -> None:
        result = []
        with progress_context([], "Processing...", silent=True) as items:
            for item in items:
                result.append(item)
        self.assertEqual(result, [])

    def test_silent_with_done_message(self) -> None:
        result = []
        with progress_context([1], "Processing...", done_message="Done!", silent=True) as items:
            for item in items:
                result.append(item)
        self.assertEqual(result, [1])


class TestProgressContextNonSilent(unittest.TestCase):
    def test_non_silent_iterates_correctly(self) -> None:
        mock_live = MagicMock()
        mock_progress = MagicMock()
        mock_progress.add_task.return_value = 0
        with (
            patch("veaf_libs.progress.Live", return_value=mock_live),
            patch("veaf_libs.progress.Progress", return_value=mock_progress),
        ):
            result = []
            with progress_context([10, 20, 30], "Processing...", silent=False) as items:
                for item in items:
                    result.append(item)
            self.assertEqual(result, [10, 20, 30])

    def test_non_silent_requires_total_for_non_sized(self) -> None:
        def gen():
            yield 1
            yield 2

        with self.assertRaises(ValueError):
            with progress_context(gen(), "Processing...", silent=False):
                pass

    def test_non_silent_total_provided_explicitly(self) -> None:
        mock_live = MagicMock()
        mock_progress = MagicMock()
        mock_progress.add_task.return_value = 0

        def gen():
            yield 1
            yield 2

        with (
            patch("veaf_libs.progress.Live", return_value=mock_live),
            patch("veaf_libs.progress.Progress", return_value=mock_progress),
        ):
            result = []
            with progress_context(gen(), "Processing...", total=2, silent=False) as items:
                for item in items:
                    result.append(item)
            self.assertEqual(result, [1, 2])

    def test_non_silent_with_done_message(self) -> None:
        mock_live = MagicMock()
        mock_progress = MagicMock()
        mock_progress.add_task.return_value = 0
        with (
            patch("veaf_libs.progress.Live", return_value=mock_live),
            patch("veaf_libs.progress.Progress", return_value=mock_progress),
        ):
            with progress_context([1, 2], "Processing...", done_message="Finished!", silent=False) as items:
                for _ in items:
                    pass


if __name__ == "__main__":
    unittest.main()
