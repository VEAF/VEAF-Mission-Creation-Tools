"""Tests for the data-driven mission.yaml template generator (veaf_libs.mission_template)."""

from __future__ import annotations

import unittest

import yaml
from veaf_libs.mission_template import CATALOG, SELECTABLE_MODULES, generate_mission_yaml, tier_modules


def _modules(text: str) -> dict:
    """Parse the generated YAML and return its (active) modules block."""
    data = yaml.safe_load(text) or {}
    return data.get("modules") or {}


class TestMissionTemplate(unittest.TestCase):
    def test_every_tier_generates_valid_parseable_yaml(self) -> None:
        for tier in ("minimal", "standard", "full"):
            text = generate_mission_yaml(tier_modules(tier))
            data = yaml.safe_load(text)  # must not raise
            self.assertIn("modules", data)
            self.assertEqual(data["mission"]["name"], "My-Mission")

    def test_minimal_has_core_only(self) -> None:
        active = _modules(generate_mission_yaml(tier_modules("minimal")))
        # infra + core feature toggles are active
        for mod in ("UNITS", "RADIO", "SPAWN", "SHORTCUTS", "INTERPRETER"):
            self.assertIn(mod, active)
        # standard/full features are absent from minimal
        # MiST joined this list: it is no longer infrastructure, and no tier pulls it in.
        for mod in ("WEATHER", "CASMISSION", "QRA", "TUM", "MIST"):
            self.assertNotIn(mod, active)

    def test_security_is_always_present_but_never_active(self) -> None:
        # David's rule: security off by default (commented) but always shown — every tier
        # AND a custom set that omits it must still carry the commented SECURITY how-to.
        for enabled in (tier_modules("minimal"), tier_modules("standard"), tier_modules("full"), {"RADIO"}):
            text = generate_mission_yaml(enabled)
            self.assertIn("SECURITY", text)  # the commented how-to is always emitted
            self.assertNotIn("SECURITY", _modules(text))  # ...but never active

    def test_groundai_tracks_casmission_tiers(self) -> None:
        # GROUNDAI is CASMISSION's dependency: it must sit in exactly the same tiers so
        # enabling CASMISSION never silently auto-enables an undeclared GROUNDAI at build.
        self.assertIn("GROUNDAI", CATALOG)
        self.assertEqual(CATALOG["GROUNDAI"].tiers, CATALOG["CASMISSION"].tiers)
        for tier in ("standard", "full"):
            self.assertIn("GROUNDAI", _modules(generate_mission_yaml(tier_modules(tier))))
        self.assertNotIn("GROUNDAI", _modules(generate_mission_yaml(tier_modules("minimal"))))

    def test_standard_enables_toggles_and_comments_config_modules(self) -> None:
        text = generate_mission_yaml(tier_modules("standard"))
        active = _modules(text)
        self.assertIn("CARRIER", active)  # toggle → active
        self.assertIn("CTLD", active)
        self.assertNotIn("QRA", active)  # config-required → commented, not active
        self.assertIn("QRA", text)  # ...but present as a commented block for discoverability
        self.assertIn("COMBATZONE", text)
        self.assertNotIn("ASSETS", text)  # full-only

    def test_full_has_everything_with_tum_commented(self) -> None:
        text = generate_mission_yaml(tier_modules("full"))
        active = _modules(text)
        self.assertIn("SKYNET", text)
        self.assertNotIn("TUM", active)  # commented (would abort without zones)
        self.assertIn("TUM", text)

    def test_missileguardian_is_opt_in_only(self) -> None:
        # MISSILEGUARDIAN belongs to no named tier (2021 WIP relic): never auto-enabled,
        # not even by `full`, but still selectable in the `custom` picker.
        self.assertNotIn("MISSILEGUARDIAN", tier_modules("full"))
        self.assertNotIn("MISSILEGUARDIAN", _modules(generate_mission_yaml(tier_modules("full"))))
        self.assertIn("MISSILEGUARDIAN", SELECTABLE_MODULES)
        self.assertIn("MISSILEGUARDIAN", _modules(generate_mission_yaml({"MISSILEGUARDIAN"})))

    def test_custom_set_is_honoured(self) -> None:
        active = _modules(generate_mission_yaml({"RADIO", "WEATHER"}))
        self.assertIn("RADIO", active)
        self.assertIn("WEATHER", active)
        self.assertNotIn("SPAWN", active)
        self.assertNotIn("MIST", active)  # opt-in since DROP-MIST ticket 08

    def test_selectable_excludes_infra(self) -> None:
        self.assertNotIn("UNITS", SELECTABLE_MODULES)
        self.assertIn("QRA", SELECTABLE_MODULES)

    def test_mist_is_selectable_but_in_no_tier(self) -> None:
        """The escape hatch stays reachable: a mission that needs MiST can still ask for it,
        it is simply never handed out by a tier (DROP-MIST ticket 08)."""
        from veaf_libs.mission_template import module_lowest_tier

        self.assertIn("MIST", SELECTABLE_MODULES)
        self.assertIsNone(module_lowest_tier("MIST"))
        self.assertIn("MIST", _modules(generate_mission_yaml({"MIST"})))

    def test_module_lowest_tier(self) -> None:
        from veaf_libs.mission_template import module_lowest_tier

        self.assertEqual(module_lowest_tier("RADIO"), "minimal")
        self.assertEqual(module_lowest_tier("WEATHER"), "standard")
        self.assertEqual(module_lowest_tier("QRA"), "standard")
        self.assertIsNone(module_lowest_tier("MISSILEGUARDIAN"))  # opt-in: no tier


class TestMissionTemplatePreamble(unittest.TestCase):
    """The prepare template carries the same rich preamble as generate-config / convert-v5."""

    def test_preamble_sections_present_in_every_tier(self) -> None:
        # Tripack's gap: prepare lacked the guide / global_log_level / security / pipeline
        # sections that convert-v5 emits. They must now appear regardless of the tier.
        from veaf_libs.i18n import language

        with language("en"):  # deterministic comment text for substring assertions
            for enabled in (tier_modules("minimal"), tier_modules("standard"), tier_modules("full"), {"RADIO"}):
                text = generate_mission_yaml(enabled)
                self.assertIn("YAML syntax", text)  # syntax quick-reference guide
                self.assertIn("# global_log_level: debug", text)
                self.assertIn("# security:", text)
                self.assertIn("# pipeline:", text)
                self.assertIn("#   era: MODERN", text)  # enriched mission: identity hints

    def test_preamble_sections_are_commented_not_active(self) -> None:
        # The preamble must stay inert: only mission.name is live, everything else is a
        # commented example so a fresh build is not silently reconfigured.
        data = yaml.safe_load(generate_mission_yaml(tier_modules("full")))
        self.assertEqual(data["mission"]["name"], "My-Mission")
        self.assertIsNone(data.get("security"))
        self.assertIsNone(data.get("pipeline"))
        self.assertIsNone(data.get("global_log_level"))

    def test_preamble_shared_with_generate_config(self) -> None:
        # Same source of truth: the prepare output reuses the generate-config helpers verbatim.
        from veaf_libs.lua_config_generator import (
            global_log_level_section,
            pipeline_section,
            security_section,
        )

        text = generate_mission_yaml(tier_modules("standard"))
        for section in (global_log_level_section(), security_section(), pipeline_section()):
            self.assertIn("\n".join(section), text)


if __name__ == "__main__":
    unittest.main()
