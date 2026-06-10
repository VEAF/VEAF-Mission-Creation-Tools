"""ERA-AUTODETECT-002 — wire era detection into the build (manual value wins)."""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from mission_builder.mission_builder_worker import MissionBuilderWorker

_BASE_MISSION_WW2 = (
    "mission = {\n"
    '  ["date"] = { ["Year"] = 2011, ["Month"] = 6, ["Day"] = 1 },\n'
    '  ["coalition"] = {\n'
    '    ["blue"] = {\n'
    '      ["country"] = {\n'
    "        [1] = {\n"
    '          ["name"] = "USA",\n'
    '          ["plane"] = { ["group"] = { [1] = { ["units"] = { [1] = { ["type"] = "SpitfireLFMkIX" } } } } },\n'
    "        },\n"
    "      },\n"
    "    },\n"
    "  },\n"
    "}\n"
)


class TestEraAutodetectWiring(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.folder = Path(self._tmp.name)
        (self.folder / "src" / "mission").mkdir(parents=True)
        (self.folder / "src" / "mission" / "mission").write_text(_BASE_MISSION_WW2, encoding="utf-8")

    def tearDown(self) -> None:
        self._tmp.cleanup()

    def _worker(self, yaml_content: str) -> MissionBuilderWorker:
        (self.folder / "mission.yaml").write_text(yaml_content, encoding="utf-8")
        return MissionBuilderWorker(
            mission_folder=self.folder,
            output_mission=self.folder / "out.miz",
            dynamic_mode=None,
        )

    def _generated_config(self) -> str:
        return (self.folder / "src" / "scripts" / "veaf-config.lua").read_text(encoding="utf-8")

    def test_detect_era_from_base_returns_ww2(self) -> None:
        worker = self._worker("mission:\n  name: Test\n")
        self.assertEqual(worker._detect_era_from_base(), "WW2")

    def test_era_injected_when_absent(self) -> None:
        worker = self._worker("mission:\n  name: Test\n")
        worker.write_config_lua()
        self.assertIn("veaf.config.era = veaf.ERA.WW2", self._generated_config())

    def test_manual_era_wins_over_detection(self) -> None:
        worker = self._worker("mission:\n  name: Test\n  era: MODERN\n")
        worker.write_config_lua()
        config = self._generated_config()
        self.assertIn("veaf.config.era = veaf.ERA.MODERN", config)
        self.assertNotIn("veaf.ERA.WW2", config)

    def test_no_base_mission_no_era(self) -> None:
        (self.folder / "src" / "mission" / "mission").unlink()
        worker = self._worker("mission:\n  name: Test\n")
        self.assertIsNone(worker._detect_era_from_base())


if __name__ == "__main__":
    unittest.main()
