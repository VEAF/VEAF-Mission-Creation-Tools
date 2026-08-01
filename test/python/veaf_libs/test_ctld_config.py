"""FEAT-CTLD2-INTEGRATION: reading CTLD 2's default catalogue out of the vendored engine.

A mission's ``ctld-config.yaml`` is a **complete** snapshot — CTLD 2 removes any list
the document omits — so it is seeded from the engine's own defaults rather than
written from scratch. Those defaults live inside the deliverable as a long-bracket Lua
string, which is what this module digs out. Keeping no copy in this repo is the point:
a CTLD release that adds a crate section is picked up with nothing to update here.
"""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from veaf_libs.ctld_config import extract_default_config, read_default_config

_YAML = 'configVersion: "2.0.0"\nmm_facing:\n  numberOfTroops: 10\n'


class TestExtractDefaultConfig(unittest.TestCase):
    def test_extracts_a_level_zero_bracket(self) -> None:
        lua = f"ctld = ctld or {{}}\nctld.configDefault = [[\n{_YAML}]]\nreturn true\n"
        self.assertEqual(extract_default_config(lua), _YAML)

    def test_extracts_a_higher_level_bracket(self) -> None:
        """The build raises the level when the catalogue itself contains ``]]``."""
        payload = 'desc: "a ]] inside"\n'
        lua = f"ctld.configDefault = [==[\n{payload}]==]\n"
        self.assertEqual(extract_default_config(lua), payload)

    def test_a_level_zero_document_stops_at_its_own_closer(self) -> None:
        """Level 0 must not swallow a later ``]]`` — the first one closes it."""
        lua = f"ctld.configDefault = [[\n{_YAML}]]\nlocal other = [[ x ]]\n"
        self.assertEqual(extract_default_config(lua), _YAML)

    def test_returns_none_when_absent(self) -> None:
        """A CTLD v1 script, or one that stopped embedding its defaults."""
        self.assertIsNone(extract_default_config("ctld = {}\nctld.Version = '1.6.1'\n"))


class TestReadDefaultConfig(unittest.TestCase):
    def test_reads_from_a_file(self) -> None:
        folder = Path(tempfile.mkdtemp())
        target = folder / "CTLD.lua"
        target.write_text(f"ctld.configDefault = [[\n{_YAML}]]\n", encoding="utf-8")
        self.assertEqual(read_default_config(target), _YAML)

    def test_missing_file_is_none_not_an_error(self) -> None:
        """The caller warns and skips; a missing engine must not abort a scaffold."""
        self.assertIsNone(read_default_config(Path(tempfile.mkdtemp()) / "absent.lua"))


class TestApplyVeafOverrides(unittest.TestCase):
    """CTLD ships both discovery lists empty; VEAF missions have relied on the
    equivalent behaviour since `autoInitializeAllLogistic` lived in veaf.lua."""

    _CATALOGUE = (
        'configVersion: "2.0.0"\n'
        "mm_facing:\n"
        "  # keep me\n"
        "  numberOfTroops: 10\n"
        "  logisticUnitTypes: []\n"
        "  troopZoneShipTypes: []\n"
    )

    def test_fills_both_discovery_lists(self) -> None:
        import yaml

        from veaf_libs.ctld_config import VEAF_CONFIG_OVERRIDES, apply_veaf_overrides

        result = yaml.safe_load(apply_veaf_overrides(self._CATALOGUE))["mm_facing"]
        self.assertEqual(result["logisticUnitTypes"], VEAF_CONFIG_OVERRIDES["logisticUnitTypes"])
        self.assertEqual(result["troopZoneShipTypes"], VEAF_CONFIG_OVERRIDES["troopZoneShipTypes"])

    def test_leaves_everything_else_alone(self) -> None:
        import yaml

        from veaf_libs.ctld_config import apply_veaf_overrides

        result = apply_veaf_overrides(self._CATALOGUE)
        self.assertEqual(yaml.safe_load(result)["mm_facing"]["numberOfTroops"], 10)
        self.assertIn("# keep me", result)  # comments survive: the MM reads this file

    def test_a_key_the_catalogue_does_not_define_is_skipped(self) -> None:
        """An older vendored engine must not gain an invented setting."""
        import yaml

        from veaf_libs.ctld_config import apply_veaf_overrides

        older = 'configVersion: "2.0.0"\nmm_facing:\n  numberOfTroops: 10\n'
        result = yaml.safe_load(apply_veaf_overrides(older))["mm_facing"]
        self.assertNotIn("logisticUnitTypes", result)

    def test_the_farp_display_name_is_not_carried_over(self) -> None:
        """`FARP Ammo Storage` is the display name of `FARP Ammo Dump Coating`, and
        getTypeName() returns the type id — the v1 entry never matched anything."""
        from veaf_libs.ctld_config import VEAF_CONFIG_OVERRIDES

        self.assertNotIn("FARP Ammo Storage", VEAF_CONFIG_OVERRIDES["logisticUnitTypes"])
        self.assertIn("FARP Ammo Dump Coating", VEAF_CONFIG_OVERRIDES["logisticUnitTypes"])


class TestAgainstTheVendoredEngine(unittest.TestCase):
    """The real artifact — catches a CTLD build that changes how it embeds its defaults."""

    def test_vendored_ctld_yields_a_parseable_catalogue(self) -> None:
        import yaml

        vendored = Path(__file__).resolve().parents[3] / "src" / "scripts" / "community" / "CTLD.lua"
        if not vendored.is_file():  # pragma: no cover - only in a partial checkout
            self.skipTest("vendored CTLD.lua not present")
        catalogue = read_default_config(vendored)
        assert catalogue is not None, "the vendored CTLD.lua no longer embeds ctld.configDefault"
        parsed = yaml.safe_load(catalogue)
        self.assertIn("configVersion", parsed)
        self.assertIn("capabilitiesByType", parsed.get("mm_facing", {}))


if __name__ == "__main__":
    unittest.main()
