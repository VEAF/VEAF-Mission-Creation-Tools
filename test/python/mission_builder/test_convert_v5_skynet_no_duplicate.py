"""convert-v5 must emit SKYNET exactly once in the generated ``modules:`` block.

SKYNET is both a module (``MODULE_CATEGORIES`` "External") and a community script that owns a
richer, config-carrying entry in the dedicated community section. Before the fix, an enabled
SKYNET produced two ``SKYNET:`` keys — one bare ``SKYNET: true`` under "External" and one config
block under the community header. That is a duplicate YAML mapping key: the reader keeps the last
one, silently dropping whichever came first. The community section is authoritative, so the
"External" emission is the one that must go.
"""

from __future__ import annotations

import unittest
from pathlib import Path

import yaml
from mission_builder.config_migrator import MigrationResult
from mission_builder.v5_converter import ConversionReport, V5Converter
from veaf_libs.i18n import language


def _build_yaml(mr: MigrationResult) -> str:
    report = ConversionReport(mission_folder=Path("demo-mission"), migration_result=mr)
    with language("en"):
        return V5Converter()._build_mission_yaml(report)


def _skynet_key_lines(yaml_text: str) -> list[str]:
    return [ln for ln in yaml_text.splitlines() if ln.strip().startswith("SKYNET:")]


class TestSkynetEmittedOnce(unittest.TestCase):
    def test_enabled_with_config_yields_a_single_key(self) -> None:
        mr = MigrationResult(
            new_content="",
            enabled_modules=["SKYNET"],
            skynet_config={"include_red_in_radio": True, "debug_red": False},
        )
        text = _build_yaml(mr)
        self.assertEqual(len(_skynet_key_lines(text)), 1, text)

    def test_the_surviving_entry_is_the_config_block(self) -> None:
        mr = MigrationResult(
            new_content="",
            enabled_modules=["SKYNET"],
            skynet_config={"include_red_in_radio": True, "debug_red": False},
        )
        text = _build_yaml(mr)
        parsed = yaml.safe_load(text)
        self.assertEqual(parsed["modules"]["SKYNET"]["enabled"], True)
        self.assertEqual(parsed["modules"]["SKYNET"]["include_red_in_radio"], True)

    def test_enabled_without_config_still_reads_as_enabled(self) -> None:
        # No skynet_config and the .lua is not detected, but the module was enabled: the single
        # community entry must still say true (this is the enabled_by_id branch).
        mr = MigrationResult(new_content="", enabled_modules=["SKYNET"])
        text = _build_yaml(mr)
        lines = _skynet_key_lines(text)
        self.assertEqual(len(lines), 1, text)
        self.assertTrue(lines[0].strip().endswith("true"), lines)


if __name__ == "__main__":
    unittest.main()
