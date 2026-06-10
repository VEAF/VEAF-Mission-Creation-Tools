"""CONVERT-FIDELITY-001 — recover commented-out v5 elements as commented YAML."""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from mission_builder.v5_converter import V5Converter, _decomment_lua
from veaf_libs.i18n import current_language, set_language


class TestDecommentLua(unittest.TestCase):
    def test_uncomments_single_line_comments(self) -> None:
        out = _decomment_lua("-- foo = 1\n--   bar = 2\n")
        self.assertEqual(out, "foo = 1\n  bar = 2")

    def test_leaves_v6_markers_untouched(self) -> None:
        out = _decomment_lua("-- [v6 migration] removed\nactive = 1\n")
        self.assertIn("-- [v6 migration] removed", out)

    def test_leaves_active_code_untouched(self) -> None:
        self.assertEqual(_decomment_lua("active = 1\n"), "active = 1")


class TestCommentedElementsRecovery(unittest.TestCase):
    def setUp(self) -> None:
        self._prev = current_language()
        set_language("en")

    def tearDown(self) -> None:
        set_language(self._prev)

    def _make_missionconfig(self, folder: Path, content: str) -> None:
        scripts_dir = folder / "src" / "scripts"
        scripts_dir.mkdir(parents=True)
        (scripts_dir / "missionConfig.lua").write_text(content, encoding="utf-8")

    def test_commented_combat_zone_recovered_as_commented_yaml(self) -> None:
        mission_config = (
            "-- if veafCombatZone then\n"
            "--   veafCombatZone.AddZone(\n"
            "--     VeafCombatZone:new()\n"
            '--       :setMissionEditorZoneName("AbuZone")\n'
            '--       :setFriendlyName("Abu")\n'
            "--       :initialize()\n"
            "--   )\n"
            "-- end\n"
        )
        with tempfile.TemporaryDirectory() as td:
            folder = Path(td)
            self._make_missionconfig(folder, mission_config)
            V5Converter().convert(folder, backup=False)
            yaml_content = (folder / "mission.yaml").read_text()
            # The recovered block header is present, and the zone appears commented.
            self.assertIn("Commented-out v5 elements", yaml_content)
            self.assertIn("AbuZone", yaml_content)
            # The recovered zone line is itself commented out.
            zone_line = next(line for line in yaml_content.splitlines() if "AbuZone" in line)
            self.assertTrue(zone_line.lstrip().startswith("#"), zone_line)

    def test_no_block_when_nothing_commented(self) -> None:
        # Only active code → nothing to recover.
        mission_config = "if veafSpawn then\n  veafSpawn.initialize()\nend\n"
        with tempfile.TemporaryDirectory() as td:
            folder = Path(td)
            self._make_missionconfig(folder, mission_config)
            V5Converter().convert(folder, backup=False)
            yaml_content = (folder / "mission.yaml").read_text()
            self.assertNotIn("Commented-out v5 elements", yaml_content)


if __name__ == "__main__":
    unittest.main()
