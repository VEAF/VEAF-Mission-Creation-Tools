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

    def test_config_override_scaffolds_foothold_locale(self) -> None:
        # Upstream config V1.0.9 added FootholdLocale (ten locales); a VEAF Foothold
        # wants French on-screen text, so it belongs in the scaffold.
        profile = load_profile("foothold")
        assert profile.config_override is not None
        self.assertEqual(profile.config_override.defaults.get("FootholdLocale"), "FR")

    def test_disables_veaf_community_scripts(self) -> None:
        # Foothold ships its own community libs — VEAF's must be scaffolded OFF (FOOTHOLD-V6-009).
        # MiST is excluded: it is a mandatory VEAF dependency and cannot be disabled.
        profile = load_profile("foothold")
        self.assertEqual(
            set(profile.disabled_community_scripts),
            {"stts", "ctld", "aien", "csar", "skynet", "tum"},
        )

    def test_normalizes_versioned_moose_name(self) -> None:
        profile = load_profile("foothold")
        self.assertEqual(profile.normalize_script_name("Moose_2026-04-28.lua"), "Moose.lua")

    def test_normalizes_versioned_splash_damage_name(self) -> None:
        # Upstream ships Splash_Damage_<version>_leka.lua; without a rule, every version
        # bump breaks the custom_scripts path on `convert-other --update`.
        profile = load_profile("foothold")
        self.assertEqual(profile.normalize_script_name("Splash_Damage_3.4.1_leka.lua"), "Splash_Damage.lua")

    def test_leaves_unmatched_names_unchanged(self) -> None:
        profile = load_profile("foothold")
        self.assertEqual(profile.normalize_script_name("AIEN.lua"), "AIEN.lua")

    def test_leaves_per_map_setup_script_unchanged(self) -> None:
        # Setup script names differ per *map*, not per version, and a folder adopts one
        # map — collapsing them would hide which map the folder holds.
        profile = load_profile("foothold")
        for name in ("MA_Setup_CA.lua", "footholdSyriaSetup.lua", "kola_setup.lua", "Zeus.lua"):
            self.assertEqual(profile.normalize_script_name(name), name)


class TestBundledFootholdWw2Profile(unittest.TestCase):
    """Normandy WWII Foothold is a different family — hence its own profile (ticket 04)."""

    def setUp(self) -> None:
        self.profile = load_profile("foothold-ww2")

    def test_targets_the_ww2_config_file(self) -> None:
        assert self.profile.config_override is not None
        self.assertEqual(self.profile.config_override.target, "Foothold Config WW2.lua")

    def test_scaffolds_only_keys_the_ww2_config_has(self) -> None:
        # The WW2 config has no Era (WW2 has no era switch) and no StartNormal; scaffolding
        # either would fail `validate`, which checks each key against the injected code.
        assert self.profile.config_override is not None
        defaults = self.profile.config_override.defaults
        self.assertEqual(set(defaults), {"AutoRestart", "CapDifficulty", "FootholdLocale"})

    def test_veaf_ctld_is_not_incompatible(self) -> None:
        # Unlike the modern maps, Normandy ships no Foothold CTLD at all.
        self.assertEqual(self.profile.incompatible_modules, ())
        self.assertNotIn("ctld", self.profile.disabled_community_scripts)

    def test_still_disables_the_libs_it_does_ship(self) -> None:
        self.assertEqual(
            set(self.profile.disabled_community_scripts),
            {"stts", "aien", "csar", "skynet", "tum"},
        )

    def test_normalizes_the_same_versioned_names(self) -> None:
        self.assertEqual(self.profile.normalize_script_name("Moose_2026-06-14.lua"), "Moose.lua")
        self.assertEqual(self.profile.normalize_script_name("Splash_Damage_3.4.1_leka.lua"), "Splash_Damage.lua")

    def test_enables_the_same_veaf_modules_as_foothold(self) -> None:
        self.assertEqual(set(self.profile.modules), set(load_profile("foothold").modules))


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

    def test_parses_disabled_community_scripts(self) -> None:
        with TemporaryDirectory() as td:
            p = Path(td) / "cs.yaml"
            p.write_text("name: cs\ndisabled_community_scripts: [mist, ctld]\n", encoding="utf-8")
            profile = load_profile(str(p))
            self.assertEqual(profile.disabled_community_scripts, ("mist", "ctld"))

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
