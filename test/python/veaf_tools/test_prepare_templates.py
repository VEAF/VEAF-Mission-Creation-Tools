"""Integration test: `veaf-tools prepare --template` writes a generated mission.yaml."""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

import veaf_tools.commands  # noqa: F401  — side effect: registers all commands on `app`
import yaml
from typer.testing import CliRunner
from veaf_libs.mission_template import TIER_NAMES
from veaf_tools.app import app

_runner = CliRunner()

# The template names the CLI exposes — derived from the source of truth, not hardcoded.
_ALL_TEMPLATES = (*TIER_NAMES, "custom")


class TestPrepareTemplates(unittest.TestCase):
    def test_no_args_shows_help_not_scaffold(self) -> None:
        # Bare `prepare` must show the help (options + template names), not silently
        # scaffold the current directory.
        result = _runner.invoke(app, ["prepare"])
        self.assertNotEqual(result.exit_code, 0)  # no_args_is_help exits non-zero
        self.assertIn("Usage", result.output)
        for name in _ALL_TEMPLATES:
            self.assertIn(name, result.output)

    def test_list_templates(self) -> None:
        result = _runner.invoke(app, ["prepare", "--list-templates"])
        self.assertEqual(result.exit_code, 0)
        for name in _ALL_TEMPLATES:
            self.assertIn(name, result.output)

    def test_minimal_template_generates_focused_mission_yaml(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            folder = Path(tmp)
            result = _runner.invoke(app, ["prepare", "--template", "minimal", str(folder), "--force"])
            self.assertEqual(result.exit_code, 0, result.output)
            modules = (yaml.safe_load((folder / "mission.yaml").read_text(encoding="utf-8")) or {}).get("modules") or {}
            self.assertIn("RADIO", modules)
            self.assertIn("SPAWN", modules)
            self.assertNotIn("WEATHER", modules)  # standard-only
            self.assertNotIn("SECURITY", modules)  # off by default

    def test_standard_template_seeds_the_ctld_configuration(self) -> None:
        """A template that enables CTLD ships the matching ctld-config.yaml (ADR 0016).

        CTLD 2 reads a complete snapshot, so the mission maker starts from the engine's
        own catalogue — extracted from the vendored CTLD.lua, never a copy kept here.
        """
        import yaml as _yaml

        with tempfile.TemporaryDirectory() as tmp:
            folder = Path(tmp)
            result = _runner.invoke(app, ["prepare", "--template", "standard", str(folder), "--force"])
            self.assertEqual(result.exit_code, 0, result.output)

            config = folder / "ctld-config.yaml"
            self.assertTrue(config.is_file(), "standard enables CTLD, so its config must be seeded")
            parsed = _yaml.safe_load(config.read_text(encoding="utf-8"))
            self.assertIn("configVersion", parsed)

            # The VEAF overrides are applied on the way out: without them a VEAF mission
            # loses the carrier / FARP recognition autoInitializeAllLogistic used to give.
            # The two discovery settings landed in CTLD after 2.0.0-rc2, so this assertion
            # only runs once the vendored engine carries them — re-vendoring turns it on.
            if "logisticUnitTypes" not in parsed["mm_facing"]:
                self.skipTest("vendored CTLD predates logisticUnitTypes / troopZoneShipTypes")
            self.assertIn("Stennis", parsed["mm_facing"]["logisticUnitTypes"])
            self.assertIn("CVN_71", parsed["mm_facing"]["troopZoneShipTypes"])

    def test_minimal_template_does_not_seed_a_ctld_configuration(self) -> None:
        """No CTLD, no 1000-line file in the mission maker's folder."""
        with tempfile.TemporaryDirectory() as tmp:
            folder = Path(tmp)
            _runner.invoke(app, ["prepare", "--template", "minimal", str(folder), "--force"])
            self.assertFalse((folder / "ctld-config.yaml").exists())

    def test_an_existing_ctld_configuration_survives_force(self) -> None:
        """It is the mission maker's configuration, not a scaffold artifact."""
        with tempfile.TemporaryDirectory() as tmp:
            folder = Path(tmp)
            config = folder / "ctld-config.yaml"
            config.write_text("# mine\n", encoding="utf-8")
            _runner.invoke(app, ["prepare", "--template", "standard", str(folder), "--force"])
            self.assertEqual(config.read_text(encoding="utf-8"), "# mine\n")

    def test_ask_replace_non_interactive_keeps_all(self) -> None:
        # Without a TTY (CI, pipes), the overwrite prompt must not block: keep everything.
        from unittest import mock

        from veaf_tools.helpers import _ask_replace

        with mock.patch("sys.stdin.isatty", return_value=False):
            self.assertEqual(_ask_replace(Path("some/file.yaml")), (False, True))

    def test_unknown_template_exits_nonzero(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            result = _runner.invoke(app, ["prepare", "--template", "nope", tmp])
            self.assertNotEqual(result.exit_code, 0)

    def test_custom_picker_returns_selected_modules(self) -> None:
        from unittest import mock

        from veaf_tools.commands.prepare import _select_custom_modules

        picked = type("C", (), {"execute": lambda self: ["RADIO", "SPAWN"]})()
        with mock.patch("InquirerPy.inquirer.checkbox", return_value=picked):
            self.assertEqual(_select_custom_modules(), {"RADIO", "SPAWN"})

    def test_custom_picker_back_then_quit_exits_cleanly(self) -> None:
        # Back out of the picker (checkbox None) → template choice; back out of that
        # (select None) → clean exit.
        from unittest import mock

        import typer
        from veaf_tools.commands.prepare import _resolve_template_modules

        none_cb = type("C", (), {"execute": lambda self: None})()
        none_sel = type("S", (), {"execute": lambda self: None})()
        with mock.patch("InquirerPy.inquirer.checkbox", return_value=none_cb):
            with mock.patch("InquirerPy.inquirer.select", return_value=none_sel):
                with self.assertRaises(typer.Exit) as ctx:
                    _resolve_template_modules("custom")
        self.assertEqual(ctx.exception.exit_code, 0)

    def test_custom_picker_back_to_template_resolves_tier(self) -> None:
        # Back out of the picker → pick a tier at the template choice → that tier's modules.
        from unittest import mock

        from veaf_libs.mission_template import tier_modules
        from veaf_tools.commands.prepare import _resolve_template_modules

        none_cb = type("C", (), {"execute": lambda self: None})()
        pick_minimal = type("S", (), {"execute": lambda self: "minimal"})()
        with mock.patch("InquirerPy.inquirer.checkbox", return_value=none_cb):
            with mock.patch("InquirerPy.inquirer.select", return_value=pick_minimal):
                result = _resolve_template_modules("custom")
        self.assertEqual(result, tier_modules("minimal"))


if __name__ == "__main__":
    unittest.main()
