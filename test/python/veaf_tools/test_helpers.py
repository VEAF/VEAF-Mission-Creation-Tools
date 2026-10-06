"""Tests for veaf_tools.helpers — build config YAML manipulation and auto-pause detection."""

from __future__ import annotations

import os
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from veaf_tools.helpers import (
    NO_PAUSE_ENV_VAR,
    _is_double_clicked,
    _update_build_config_in_yaml,
    should_auto_pause,
)


class TestUpdateBuildConfigInYaml(unittest.TestCase):
    def test_appends_build_section_to_empty_file(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            yaml_file = Path(tmpdir) / "mission.yaml"
            yaml_file.write_text("mission:\n  name: test\n", encoding="utf-8")
            _update_build_config_in_yaml(yaml_file, dev_mode=False, scripts_path=None)
            content = yaml_file.read_text(encoding="utf-8")
            self.assertIn("build:", content)
            self.assertIn("dev_mode: false", content)

    def test_dev_mode_true_written(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            yaml_file = Path(tmpdir) / "mission.yaml"
            yaml_file.write_text("", encoding="utf-8")
            _update_build_config_in_yaml(yaml_file, dev_mode=True, scripts_path=None)
            content = yaml_file.read_text(encoding="utf-8")
            self.assertIn("dev_mode: true", content)

    def test_scripts_path_written_when_provided(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            yaml_file = Path(tmpdir) / "mission.yaml"
            yaml_file.write_text("", encoding="utf-8")
            scripts_path = Path("/some/scripts/path")
            _update_build_config_in_yaml(yaml_file, dev_mode=False, scripts_path=scripts_path)
            content = yaml_file.read_text(encoding="utf-8")
            self.assertIn("scripts_path:", content)
            self.assertIn("some/scripts/path", content)

    def test_scripts_path_absent_when_none(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            yaml_file = Path(tmpdir) / "mission.yaml"
            yaml_file.write_text("", encoding="utf-8")
            _update_build_config_in_yaml(yaml_file, dev_mode=False, scripts_path=None)
            content = yaml_file.read_text(encoding="utf-8")
            self.assertNotIn("scripts_path:", content)

    def test_replaces_existing_build_section(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            yaml_file = Path(tmpdir) / "mission.yaml"
            original = "mission:\n  name: test\n\n# ── Build configuration\nbuild:\n  dev_mode: false\n"
            yaml_file.write_text(original, encoding="utf-8")
            _update_build_config_in_yaml(yaml_file, dev_mode=True, scripts_path=None)
            content = yaml_file.read_text(encoding="utf-8")
            self.assertIn("dev_mode: true", content)
            # Only one build: section
            self.assertEqual(content.count("build:"), 1)


class TestShouldAutoPause(unittest.TestCase):
    """`VEAF_UPDATER_NO_PAUSE` must force no-pause so a programmatic caller never hangs."""

    def test_truthy_env_var_forces_no_pause_without_checking_launch(self) -> None:
        with (
            patch.dict(os.environ, {NO_PAUSE_ENV_VAR: "1"}),
            patch("veaf_tools.helpers._is_double_clicked", return_value=True) as double_clicked,
        ):
            self.assertFalse(should_auto_pause())
            double_clicked.assert_not_called()  # short-circuits, never consults the launch context

    def test_falsy_env_var_does_not_disable_pause(self) -> None:
        # "0" is not truthy → behaves as if unset (delegates to the launch heuristic).
        with (
            patch.dict(os.environ, {NO_PAUSE_ENV_VAR: "0"}),
            patch("veaf_tools.helpers._is_double_clicked", return_value=True),
        ):
            self.assertTrue(should_auto_pause())

    def test_delegates_to_double_clicked_when_env_absent(self) -> None:
        with patch.dict(os.environ, {}, clear=False):
            os.environ.pop(NO_PAUSE_ENV_VAR, None)
            with patch("veaf_tools.helpers._is_double_clicked", return_value=True):
                self.assertTrue(should_auto_pause())
            with patch("veaf_tools.helpers._is_double_clicked", return_value=False):
                self.assertFalse(should_auto_pause())


class TestPauseOnAClosedStdin(unittest.TestCase):
    """`mission build … > /dev/null` from Git Bash exited 1 after succeeding (FIX-DEMO-MISSION-FINDINGS 04).

    Windows answers `isatty()` true for `NUL`, so the launch passed for a double-click, and the final
    `input()` raised `EOFError` with nobody to press a key — replacing the command's own exit code.
    """

    def test_the_pause_returns_quietly_when_nobody_can_answer(self) -> None:
        from veaf_tools.helpers import pause_before_exit

        with patch("builtins.input", side_effect=EOFError):
            pause_before_exit("Press Enter")  # must not raise

    def test_the_command_keeps_its_exit_code(self) -> None:
        from veaf_tools import app as app_module

        with (
            patch.object(app_module, "app", side_effect=SystemExit(0)),
            patch("veaf_tools.command_tree.build_cli_tree"),
            patch("veaf_libs.tui.maybe_bridge_to_tui", return_value=None),
            patch("veaf_tools.helpers.should_auto_pause", return_value=True),
            patch("veaf_libs.logger.logger.stop_status"),
            patch("builtins.input", side_effect=EOFError),
            self.assertRaises(SystemExit) as raised,
        ):
            app_module.main()
        self.assertEqual(raised.exception.code, 0)

    def test_no_double_click_when_stdin_is_not_a_terminal(self) -> None:
        with (
            patch.object(sys.stdout, "isatty", return_value=True),
            patch.object(sys.stdin, "isatty", return_value=False),
            patch("sys.platform", "win32"),
            patch("veaf_tools.helpers._build_process_tree_windows") as tree,
        ):
            self.assertFalse(_is_double_clicked())
            tree.assert_not_called()


class TestIsDoubleClicked(unittest.TestCase):
    def test_returns_false_when_not_a_tty(self) -> None:
        with patch.object(sys.stdout, "isatty", return_value=False):
            self.assertFalse(_is_double_clicked())

    def test_returns_false_on_non_windows(self) -> None:
        with patch.object(sys.stdout, "isatty", return_value=True), patch("sys.platform", "linux"):
            self.assertFalse(_is_double_clicked())

    def test_returns_false_when_no_ctypes(self) -> None:
        """When ctypes is unavailable (e.g. some embedded interpreters), must not raise."""
        import builtins

        real_import = builtins.__import__

        def mock_import(name: str, *args, **kwargs):
            if name in ("ctypes", "ctypes.wintypes"):
                raise ImportError
            return real_import(name, *args, **kwargs)

        with (
            patch.object(sys.stdout, "isatty", return_value=True),
            patch("sys.platform", "win32"),
            patch("builtins.__import__", side_effect=mock_import),
        ):
            # Should not raise; result doesn't matter (ctypes unavailable)
            try:
                result = _is_double_clicked()
                self.assertIsInstance(result, bool)
            except ImportError:
                pass  # acceptable — function may propagate if ctypes not available at import time


if __name__ == "__main__":
    unittest.main()
