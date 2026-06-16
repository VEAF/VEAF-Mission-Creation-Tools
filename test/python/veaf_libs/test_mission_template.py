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
        for mod in ("UNITS", "MIST", "RADIO", "SPAWN", "SHORTCUTS", "INTERPRETER"):
            self.assertIn(mod, active)
        # standard/full features are absent from minimal
        for mod in ("WEATHER", "CASMISSION", "QRA", "TUM"):
            self.assertNotIn(mod, active)

    def test_security_is_always_present_but_never_active(self) -> None:
        # David's rule: security off by default (commented) but always shown — every tier
        # AND a custom set that omits it must still carry the commented SECURITY how-to.
        for enabled in (tier_modules("minimal"), tier_modules("standard"), tier_modules("full"), {"RADIO"}):
            text = generate_mission_yaml(enabled)
            self.assertIn("SECURITY", text)  # the commented how-to is always emitted
            self.assertNotIn("SECURITY", _modules(text))  # ...but never active

    def test_groundai_is_nowhere(self) -> None:
        self.assertNotIn("GROUNDAI", CATALOG)
        for tier in ("minimal", "standard", "full"):
            self.assertNotIn("GROUNDAI", generate_mission_yaml(tier_modules(tier)))

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
        self.assertIn("MISSILEGUARDIAN", active)
        self.assertIn("SKYNET", text)
        self.assertNotIn("TUM", active)  # commented (would abort without zones)
        self.assertIn("TUM", text)

    def test_custom_set_is_honoured(self) -> None:
        active = _modules(generate_mission_yaml({"RADIO", "WEATHER"}))
        self.assertIn("RADIO", active)
        self.assertIn("WEATHER", active)
        self.assertNotIn("SPAWN", active)
        self.assertIn("MIST", active)  # infra always

    def test_selectable_excludes_infra(self) -> None:
        self.assertNotIn("MIST", SELECTABLE_MODULES)
        self.assertIn("QRA", SELECTABLE_MODULES)


if __name__ == "__main__":
    unittest.main()
