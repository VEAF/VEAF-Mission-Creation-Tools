"""Integration test: `veaf-tools prepare --template` writes a generated mission.yaml."""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

import veaf_tools.commands  # noqa: F401  — side effect: registers all commands on `app`
import yaml
from typer.testing import CliRunner
from veaf_tools.app import app

_runner = CliRunner()


class TestPrepareTemplates(unittest.TestCase):
    def test_list_templates(self) -> None:
        result = _runner.invoke(app, ["prepare", "--list-templates"])
        self.assertEqual(result.exit_code, 0)
        for name in ("minimal", "standard", "full", "custom"):
            self.assertIn(name, result.output)

    def test_minimal_template_generates_focused_mission_yaml(self) -> None:
        folder = Path(tempfile.mkdtemp())
        result = _runner.invoke(app, ["prepare", "--template", "minimal", str(folder), "--force"])
        self.assertEqual(result.exit_code, 0, result.output)
        modules = (yaml.safe_load((folder / "mission.yaml").read_text(encoding="utf-8")) or {}).get("modules") or {}
        self.assertIn("RADIO", modules)
        self.assertIn("SPAWN", modules)
        self.assertNotIn("WEATHER", modules)  # standard-only
        self.assertNotIn("SECURITY", modules)  # off by default

    def test_unknown_template_exits_nonzero(self) -> None:
        folder = Path(tempfile.mkdtemp())
        result = _runner.invoke(app, ["prepare", "--template", "nope", str(folder)])
        self.assertNotEqual(result.exit_code, 0)


if __name__ == "__main__":
    unittest.main()
