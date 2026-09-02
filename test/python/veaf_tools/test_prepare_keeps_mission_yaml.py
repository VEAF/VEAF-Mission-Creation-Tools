"""`prepare --template` must not rewrite an existing mission.yaml behind its own prompt.

FIX-TUTORIAL-FIRST-RUN ticket 06. `prepare` guards every existing file behind a four-way menu
(replace this / keep this / replace all / keep all) and then wrote `mission.yaml` unconditionally
whenever `--template` was passed. It is the most valuable file in the folder and the one a mission
maker edits by hand — module configuration, security block, build settings.

A non-interactive run answers "keep all" (`_ask_replace` returns `(False, True)` when stdin is not
a tty), which is exactly the case these tests exercise.
"""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

import veaf_tools.commands  # noqa: F401  — side effect: registers all commands on `app`
import yaml
from typer.testing import CliRunner
from veaf_tools.app import app

_runner = CliRunner()

# A mission.yaml a maker would recognise as theirs: a module the template does not enable, and a
# security block the generated file only ever ships commented out.
_HAND_EDITED = """\
mission:
  name: Mon-Premier-Vol

security:
  disabled: true

modules:
  RADIO: true
  SPAWN: true
  COMBATZONE:
    enabled: true
    combat_zones:
      - zone_name: CZ-Alpha
        friendly_name: Zone Alpha
        training: true
"""


class TestPrepareKeepsMissionYaml(unittest.TestCase):
    def test_a_fresh_folder_still_gets_its_generated_mission_yaml(self) -> None:
        """Nothing to lose, nothing to ask."""
        with tempfile.TemporaryDirectory() as tmp:
            folder = Path(tmp)
            result = _runner.invoke(app, ["prepare", "--template", "minimal", str(folder)])
            self.assertEqual(result.exit_code, 0, result.output)
            modules = (yaml.safe_load((folder / "mission.yaml").read_text(encoding="utf-8")) or {}).get("modules") or {}
            self.assertIn("RADIO", modules)

    def test_an_existing_mission_yaml_survives_a_second_prepare(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            folder = Path(tmp)
            self.assertEqual(_runner.invoke(app, ["prepare", "--template", "minimal", str(folder)]).exit_code, 0)

            mission_yaml = folder / "mission.yaml"
            mission_yaml.write_text(_HAND_EDITED, encoding="utf-8")

            result = _runner.invoke(app, ["prepare", "--template", "minimal", str(folder)])
            self.assertEqual(result.exit_code, 0, result.output)
            self.assertEqual(mission_yaml.read_text(encoding="utf-8"), _HAND_EDITED)

    def test_the_run_says_the_template_was_not_applied(self) -> None:
        """A kept file means `--template` did nothing; silence would let someone conclude it worked."""
        with tempfile.TemporaryDirectory() as tmp:
            folder = Path(tmp)
            _runner.invoke(app, ["prepare", "--template", "minimal", str(folder)])
            (folder / "mission.yaml").write_text(_HAND_EDITED, encoding="utf-8")

            result = _runner.invoke(app, ["prepare", "--template", "standard", str(folder)])
            self.assertEqual(result.exit_code, 0, result.output)
            # Rich wraps the console output, so assert on words rather than the whole sentence.
            self.assertIn("standard", result.output)
            self.assertIn("--force", result.output)
            self.assertNotIn("module(s)", result.output)  # the "applied" message must not appear

    def test_force_still_replaces_it(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            folder = Path(tmp)
            _runner.invoke(app, ["prepare", "--template", "minimal", str(folder)])
            (folder / "mission.yaml").write_text(_HAND_EDITED, encoding="utf-8")

            result = _runner.invoke(app, ["prepare", "--template", "standard", str(folder), "--force"])
            self.assertEqual(result.exit_code, 0, result.output)
            modules = (yaml.safe_load((folder / "mission.yaml").read_text(encoding="utf-8")) or {}).get("modules") or {}
            self.assertIn("WEATHER", modules)  # standard-only, so the template really was applied

    def test_a_second_prepare_without_a_template_leaves_it_alone_too(self) -> None:
        """The pre-existing contract for every other file, unchanged."""
        with tempfile.TemporaryDirectory() as tmp:
            folder = Path(tmp)
            _runner.invoke(app, ["prepare", "--template", "minimal", str(folder)])
            (folder / "mission.yaml").write_text(_HAND_EDITED, encoding="utf-8")

            result = _runner.invoke(app, ["prepare", str(folder)])
            self.assertEqual(result.exit_code, 0, result.output)
            self.assertEqual((folder / "mission.yaml").read_text(encoding="utf-8"), _HAND_EDITED)


if __name__ == "__main__":
    unittest.main()
