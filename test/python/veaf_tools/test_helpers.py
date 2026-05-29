"""Tests for veaf_tools.helpers — build config YAML manipulation."""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from veaf_tools.helpers import _update_build_config_in_yaml


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


if __name__ == "__main__":
    unittest.main()
