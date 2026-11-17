"""Integration test: `veaf-tools prepare --theatre` lays down a synthetic blank mission."""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

import veaf_tools.commands  # noqa: F401  — side effect: registers all commands on `app`
from mission_tools.miz_tools import read_mission_folder
from typer.testing import CliRunner
from veaf_tools.app import app

_runner = CliRunner()


class TestPrepareTheatre(unittest.TestCase):
    def test_list_theatres(self) -> None:
        result = _runner.invoke(app, ["prepare", "--list-theatres"])
        self.assertEqual(result.exit_code, 0, result.output)
        self.assertIn("Caucasus", result.output)

    def test_theatre_generates_a_parseable_src_mission(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            folder = Path(tmp)
            result = _runner.invoke(app, ["prepare", "--theatre", "caucasus", str(folder), "--force"])
            self.assertEqual(result.exit_code, 0, result.output)

            mission_file = folder / "src" / "mission" / "mission"
            self.assertTrue(mission_file.is_file())
            mission = read_mission_folder(folder)
            self.assertEqual(mission.theatre_content, "Caucasus")

    def test_theatre_composes_with_template(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            folder = Path(tmp)
            result = _runner.invoke(
                app, ["prepare", "--template", "minimal", "--theatre", "caucasus", str(folder), "--force"]
            )
            self.assertEqual(result.exit_code, 0, result.output)
            self.assertTrue((folder / "mission.yaml").is_file())
            self.assertTrue((folder / "src" / "mission" / "mission").is_file())

    def test_syria_gets_syria_airfields_on_the_second_radio(self) -> None:
        # 2026-11-16: the Syria campaign flew with Batumi and Kutaisi on its kneeboards
        import yaml

        with tempfile.TemporaryDirectory() as tmp:
            folder = Path(tmp)
            result = _runner.invoke(app, ["prepare", "--theatre", "syria", str(folder), "--force"])
            self.assertEqual(result.exit_code, 0, result.output)
            presets = yaml.safe_load((folder / "src" / "presets.yaml").read_text(encoding="utf-8"))
            radio = presets["channel_lists"]["blue"]["primary_2"]
            self.assertEqual(len(radio), 8)
            self.assertNotIn("Batumi", radio.values())
            self.assertIn("Incirlik", radio.values())
            syria = presets["channels_collection"]["airports-syria"]
            for alias in radio.values():
                self.assertIn(alias, syria)

    def test_caucasus_keeps_the_shipped_plan(self) -> None:
        import yaml

        with tempfile.TemporaryDirectory() as tmp:
            folder = Path(tmp)
            result = _runner.invoke(app, ["prepare", "--theatre", "caucasus", str(folder), "--force"])
            self.assertEqual(result.exit_code, 0, result.output)
            presets = yaml.safe_load((folder / "src" / "presets.yaml").read_text(encoding="utf-8"))
            self.assertEqual(presets["channel_lists"]["blue"]["primary_2"][1], "Batumi")

    def test_unknown_theatre_exits_nonzero(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            result = _runner.invoke(app, ["prepare", "--theatre", "nevada", tmp])
            self.assertNotEqual(result.exit_code, 0)


if __name__ == "__main__":
    unittest.main()
