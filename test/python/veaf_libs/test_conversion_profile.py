"""Tests for veaf_libs.conversion_profile (FOOTHOLD-V6-002)."""

import unittest
from pathlib import Path
from tempfile import TemporaryDirectory

from veaf_libs.conversion_profile import (
    ConversionProfile,
    incompatible_modules_enabled,
    load_profile,
)


class TestBundledFootholdProfile(unittest.TestCase):
    def test_loads_by_name(self) -> None:
        profile = load_profile("foothold")
        self.assertEqual(profile.name, "foothold")

    def test_enables_expected_modules(self) -> None:
        profile = load_profile("foothold")
        self.assertEqual(
            set(profile.modules),
            {"RADIO", "SPAWN", "WEATHER", "SHORTCUTS", "SECURITY", "REMOTE"},
        )

    def test_marks_ctld_incompatible(self) -> None:
        self.assertIn("CTLD", load_profile("foothold").incompatible_modules)

    def test_config_override_targets_foothold_config(self) -> None:
        profile = load_profile("foothold")
        assert profile.config_override is not None
        self.assertEqual(profile.config_override.target, "Foothold Config.lua")
        self.assertIn("CapDifficulty", profile.config_override.defaults)

    def test_normalizes_versioned_moose_name(self) -> None:
        profile = load_profile("foothold")
        self.assertEqual(profile.normalize_script_name("Moose_2026-04-28.lua"), "Moose.lua")

    def test_leaves_unmatched_names_unchanged(self) -> None:
        profile = load_profile("foothold")
        self.assertEqual(profile.normalize_script_name("AIEN.lua"), "AIEN.lua")


class TestLoadProfileFromPath(unittest.TestCase):
    def test_loads_custom_profile_from_path(self) -> None:
        with TemporaryDirectory() as td:
            p = Path(td) / "custom.yaml"
            p.write_text(
                "name: custom\nmodules: [RADIO]\nincompatible_modules: [SPAWN]\n",
                encoding="utf-8",
            )
            profile = load_profile(str(p))
            self.assertEqual(profile.name, "custom")
            self.assertEqual(profile.modules, ("RADIO",))
            self.assertEqual(profile.incompatible_modules, ("SPAWN",))

    def test_unknown_name_raises(self) -> None:
        with self.assertRaises(FileNotFoundError):
            load_profile("does-not-exist")

    def test_missing_path_raises(self) -> None:
        with self.assertRaises(FileNotFoundError):
            load_profile("/no/such/profile.yaml")

    def test_minimal_profile_has_safe_defaults(self) -> None:
        with TemporaryDirectory() as td:
            p = Path(td) / "bare.yaml"
            p.write_text("name: bare\n", encoding="utf-8")
            profile = load_profile(str(p))
            self.assertEqual(profile, ConversionProfile(name="bare"))


class TestIncompatibleModulesEnabled(unittest.TestCase):
    def test_flags_ctld_enabled_on_foothold(self) -> None:
        data = {"conversion_profile": "foothold", "modules": {"CTLD": True, "RADIO": True}}
        self.assertEqual(incompatible_modules_enabled(data), ["CTLD"])

    def test_ctld_disabled_is_fine(self) -> None:
        data = {"conversion_profile": "foothold", "modules": {"CTLD": False, "RADIO": True}}
        self.assertEqual(incompatible_modules_enabled(data), [])

    def test_ctld_as_config_dict_counts_as_enabled(self) -> None:
        data = {"conversion_profile": "foothold", "modules": {"CTLD": {"some": "config"}}}
        self.assertEqual(incompatible_modules_enabled(data), ["CTLD"])

    def test_no_profile_marker_means_no_check(self) -> None:
        self.assertEqual(incompatible_modules_enabled({"modules": {"CTLD": True}}), [])

    def test_unknown_profile_is_silent(self) -> None:
        self.assertEqual(incompatible_modules_enabled({"conversion_profile": "nope", "modules": {"CTLD": True}}), [])


if __name__ == "__main__":
    unittest.main()
