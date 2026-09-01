"""The build must refuse to ship a ``veaf-config.lua`` that does not parse.

This is the half of FIX-GENERATOR-UNESCAPED-STRINGS that matters more than the escaping.
On 2026-09-01 the build **succeeded**: it produced a ``.miz``, reported nothing, and the
broken configuration was only discovered in ``dcs.log`` once the mission was loaded in
the game — where DCS refuses the whole file and no VEAF module initialises.

A guard is only a guard if it can fail, so these tests drive it both ways: a mission that
produces valid Lua must still build, and one that does not must stop the build before a
file is written.
"""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from mission_builder.mission_builder_worker import MissionBuilderWorker

_BASE_MISSION = 'mission = {\n  ["date"] = { ["Year"] = 2011, ["Month"] = 6, ["Day"] = 1 },\n}\n'


class TestGeneratedConfigMustParse(unittest.TestCase):
    """``write_config_lua`` checks its own output before writing it."""

    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.folder = Path(self._tmp.name)
        (self.folder / "src" / "mission").mkdir(parents=True)
        (self.folder / "src" / "mission" / "mission").write_text(_BASE_MISSION, encoding="utf-8")

    def tearDown(self) -> None:
        self._tmp.cleanup()

    def _worker(self, yaml_content: str) -> MissionBuilderWorker:
        (self.folder / "mission.yaml").write_text(yaml_content, encoding="utf-8")
        return MissionBuilderWorker(
            mission_folder=self.folder,
            output_mission=self.folder / "out.miz",
            dynamic_mode=None,
        )

    @property
    def _config_file(self) -> Path:
        return self.folder / "src" / "scripts" / "veaf-config.lua"

    def test_a_settings_key_that_breaks_the_lua_stops_the_build(self) -> None:
        """A ``settings:`` key is written as a bare Lua name, so a quote in one is fatal.

        This is the one field of ``mission.yaml`` that lands in the generated file as
        *syntax* rather than as a value, which makes it the honest way to prove the guard
        fires on a real mission rather than on a hand-crafted string.
        """
        worker = self._worker("mission:\n  name: Test\nsettings:\n  'BAD\" KEY': 1\n")
        with self.assertRaises(RuntimeError) as caught:
            worker.write_config_lua()
        self.assertIn("veaf-config.lua", str(caught.exception))
        self.assertFalse(self._config_file.exists(), "a config that does not parse must not be written")

    def test_the_same_mission_with_a_valid_key_still_builds(self) -> None:
        """The other direction: the guard must let a correct mission through."""
        worker = self._worker("mission:\n  name: Test\nsettings:\n  GOOD_KEY: 1\n")
        worker.write_config_lua()
        self.assertIn("veaf.config.GOOD_KEY = 1", self._config_file.read_text(encoding="utf-8"))

    def test_the_coordinate_that_broke_the_mission_now_builds(self) -> None:
        """End to end, in the field and with the value that were flown."""
        worker = self._worker(
            "mission:\n"
            "  name: Test\n"
            "modules:\n"
            "  AIRWAVES:\n"
            "    airwave_zones:\n"
            "      - name: Wave\n"
            '        zone_center_coordinates: "N42°00\'00\\" E042°00\'00\\""\n'
        )
        worker.write_config_lua()
        self.assertIn("setZoneCenterFromCoordinates", self._config_file.read_text(encoding="utf-8"))
