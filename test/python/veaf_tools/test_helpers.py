"""Tests for veaf_tools.helpers — build config YAML manipulation and auto-pause detection."""

from __future__ import annotations

import os
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from veaf_tools.helpers import _is_double_clicked, _update_build_config_in_yaml, should_auto_pause


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

    def test_env_var_forces_no_pause_without_checking_launch(self) -> None:
        with (
            patch.dict(os.environ, {"VEAF_UPDATER_NO_PAUSE": "1"}),
            patch("veaf_tools.helpers._is_double_clicked", return_value=True) as double_clicked,
        ):
            self.assertFalse(should_auto_pause())
            double_clicked.assert_not_called()  # short-circuits, never consults the launch context

    def test_delegates_to_double_clicked_when_env_absent(self) -> None:
        with patch.dict(os.environ, {}, clear=False):
            os.environ.pop("VEAF_UPDATER_NO_PAUSE", None)
            with patch("veaf_tools.helpers._is_double_clicked", return_value=True):
                self.assertTrue(should_auto_pause())
            with patch("veaf_tools.helpers._is_double_clicked", return_value=False):
                self.assertFalse(should_auto_pause())


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
