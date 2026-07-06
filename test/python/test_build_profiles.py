"""Unit tests for veaf_libs.build_profiles — PROF-005."""

from __future__ import annotations

import unittest
from unittest.mock import patch

from veaf_libs.build_profiles import (
    _deep_merge,
    canonical_profile_name,
    pipeline_step_enabled_anywhere,
    pipeline_step_subflag,
    resolve_profile,
)


class TestDeepMerge(unittest.TestCase):
    def test_no_overlap(self) -> None:
        result = _deep_merge({"a": 1}, {"b": 2})
        self.assertEqual(result, {"a": 1, "b": 2})

    def test_scalar_override(self) -> None:
        result = _deep_merge({"a": 1, "b": 2}, {"b": 99})
        self.assertEqual(result, {"a": 1, "b": 99})

    def test_nested_dict_merge(self) -> None:
        base = {"security": {"disabled": False, "password_hashes": []}}
        override = {"security": {"disabled": True}}
        result = _deep_merge(base, override)
        self.assertEqual(result["security"]["disabled"], True)
        # key from base not in override must be kept
        self.assertIn("password_hashes", result["security"])

    def test_list_replaced_not_concatenated(self) -> None:
        base = {"items": [1, 2, 3]}
        override = {"items": [99]}
        result = _deep_merge(base, override)
        self.assertEqual(result["items"], [99])

    def test_base_not_mutated(self) -> None:
        base = {"a": {"x": 1}}
        override = {"a": {"y": 2}}
        _deep_merge(base, override)
        self.assertNotIn("y", base["a"])

    def test_transitive_nesting(self) -> None:
        base = {"a": {"b": {"c": 1, "d": 2}}}
        override = {"a": {"b": {"c": 99}}}
        result = _deep_merge(base, override)
        self.assertEqual(result["a"]["b"]["c"], 99)
        self.assertEqual(result["a"]["b"]["d"], 2)


class TestResolveProfile(unittest.TestCase):
    _YAML: dict = {
        "global_log_level": "info",
        "security": {"disabled": False},
        "pipeline": {"weather": True},
        "profiles": {
            "TEST": {
                "global_log_level": "debug",
                "security": {"disabled": True},
                "pipeline": {"weather": False},
            },
            "SERVER": {
                "pipeline": {"weather": True},
            },
            "EMPTY": {},
        },
    }

    def test_no_profile_returns_base_without_profiles_key(self) -> None:
        result = resolve_profile(self._YAML, None)
        self.assertEqual(result["global_log_level"], "info")
        self.assertNotIn("profiles", result)

    def test_basic_merge(self) -> None:
        result = resolve_profile(self._YAML, "TEST")
        self.assertEqual(result["global_log_level"], "debug")
        self.assertEqual(result["security"]["disabled"], True)
        self.assertEqual(result["pipeline"]["weather"], False)
        self.assertNotIn("profiles", result)

    def test_partial_override_keeps_base_keys(self) -> None:
        """SERVER only overrides pipeline.weather — security and log_level must come from base."""
        result = resolve_profile(self._YAML, "SERVER")
        self.assertEqual(result["global_log_level"], "info")
        self.assertEqual(result["security"]["disabled"], False)
        self.assertEqual(result["pipeline"]["weather"], True)

    def test_empty_profile_returns_base(self) -> None:
        result = resolve_profile(self._YAML, "EMPTY")
        self.assertEqual(result["global_log_level"], "info")

    def test_unknown_profile_warns_and_returns_base(self) -> None:
        with patch("veaf_libs.build_profiles.logger") as mock_logger:
            result = resolve_profile(self._YAML, "NONEXISTENT")
            mock_logger.warning.assert_called_once()
            warning_msg: str = mock_logger.warning.call_args[0][0]
            self.assertIn("NONEXISTENT", warning_msg)
        self.assertEqual(result["global_log_level"], "info")

    def test_profile_disables_pipeline_step(self) -> None:
        result = resolve_profile(self._YAML, "TEST")
        self.assertFalse(result["pipeline"]["weather"])

    def test_profiles_key_never_in_result(self) -> None:
        for profile in (None, "TEST", "SERVER", "EMPTY"):
            with self.subTest(profile=profile):
                result = resolve_profile(self._YAML, profile)
                self.assertNotIn("profiles", result)

    def test_no_profiles_section_in_yaml(self) -> None:
        yaml_data = {"global_log_level": "info"}
        result = resolve_profile(yaml_data, None)
        self.assertEqual(result, {"global_log_level": "info"})

    def test_no_profiles_section_unknown_profile_warns(self) -> None:
        yaml_data = {"global_log_level": "info"}
        with patch("veaf_libs.build_profiles.logger") as mock_logger:
            result = resolve_profile(yaml_data, "TEST")
            mock_logger.warning.assert_called_once()
        self.assertEqual(result["global_log_level"], "info")

    def test_invalid_profiles_section_warns_and_ignores(self) -> None:
        """profiles: set to a non-dict (e.g. list) must not raise TypeError."""
        yaml_data = {"global_log_level": "info", "profiles": ["bad", "value"]}
        with patch("veaf_libs.build_profiles.logger") as mock_logger:
            result = resolve_profile(yaml_data, "TEST")
            # At least one warning about the invalid profiles section
            warning_calls = [str(call) for call in mock_logger.warning.call_args_list]
            self.assertTrue(
                any("invalid" in msg.lower() for msg in warning_calls),
                f"Expected 'invalid' warning, got: {warning_calls}",
            )
        # Falls back to base config, profiles key stripped
        self.assertEqual(result["global_log_level"], "info")
        self.assertNotIn("profiles", result)

    def test_known_profile_logs_info(self) -> None:
        with patch("veaf_libs.build_profiles.logger") as mock_logger:
            resolve_profile(self._YAML, "TEST")
            mock_logger.info.assert_called_once()
            info_msg: str = mock_logger.info.call_args[0][0]
            self.assertIn("TEST", info_msg)

    def test_profile_name_is_case_insensitive(self) -> None:
        """--profile test resolves the TEST profile."""
        result = resolve_profile(self._YAML, "test")
        self.assertEqual(result["pipeline"]["weather"], False)
        self.assertEqual(result["global_log_level"], "debug")

    def test_case_insensitive_match_logs_canonical_name(self) -> None:
        with patch("veaf_libs.build_profiles.logger") as mock_logger:
            resolve_profile(self._YAML, "server")
            info_msg: str = mock_logger.info.call_args[0][0]
            self.assertIn("SERVER", info_msg)  # canonical, not the typed "server"

    def test_ambiguous_case_warns_and_returns_base(self) -> None:
        yaml_data = {"pipeline": {"weather": True}, "profiles": {"Foo": {}, "foo": {}}}
        with patch("veaf_libs.build_profiles.logger") as mock_logger:
            result = resolve_profile(yaml_data, "FOO")
            warnings = [str(c.args[0]) for c in mock_logger.warning.call_args_list if c.args]
            self.assertTrue(any("FOO" in m for m in warnings), warnings)
        self.assertNotIn("profiles", result)


class TestCanonicalProfileName(unittest.TestCase):
    _YAML: dict = {"profiles": {"TEST": {}, "COLD_WAR": {}}}

    def test_returns_canonical_for_any_case(self) -> None:
        self.assertEqual(canonical_profile_name(self._YAML, "test"), "TEST")
        self.assertEqual(canonical_profile_name(self._YAML, "Cold_War"), "COLD_WAR")

    def test_exact_match_preserved(self) -> None:
        self.assertEqual(canonical_profile_name(self._YAML, "TEST"), "TEST")

    def test_none_and_unknown_and_no_profiles(self) -> None:
        self.assertIsNone(canonical_profile_name(self._YAML, None))
        self.assertIsNone(canonical_profile_name(self._YAML, "nope"))
        self.assertIsNone(canonical_profile_name({}, "TEST"))


class TestPipelineStepEnabledAnywhere(unittest.TestCase):
    def test_enabled_when_base_does_not_disable(self) -> None:
        # weather absent from base pipeline → enabled by default
        self.assertTrue(pipeline_step_enabled_anywhere({"pipeline": {}}, "weather"))
        self.assertTrue(pipeline_step_enabled_anywhere({}, "weather"))
        self.assertTrue(pipeline_step_enabled_anywhere({"pipeline": {"weather": True}}, "weather"))

    def test_base_enabled_profile_disabled_is_still_enabled_anywhere(self) -> None:
        # The TEST case: base on (implicitly), TEST off → file still used by base/SERVER.
        yaml_data = {"pipeline": {}, "profiles": {"TEST": {"pipeline": {"weather": False}}}}
        self.assertTrue(pipeline_step_enabled_anywhere(yaml_data, "weather"))

    def test_base_disabled_profile_enabled_is_enabled_anywhere(self) -> None:
        # The symmetric case: base off, a METEO profile turns it on.
        yaml_data = {"pipeline": {"weather": False}, "profiles": {"METEO": {"pipeline": {"weather": True}}}}
        self.assertTrue(pipeline_step_enabled_anywhere(yaml_data, "weather"))

    def test_disabled_everywhere_is_orphan(self) -> None:
        # Base off and no profile re-enables it → genuine orphan.
        yaml_data = {"pipeline": {"weather": False}, "profiles": {"TEST": {"pipeline": {"weather": False}}}}
        self.assertFalse(pipeline_step_enabled_anywhere(yaml_data, "weather"))

    def test_enabled_dict_form_counts_as_enabled(self) -> None:
        yaml_data = {"pipeline": {"weather": False}, "profiles": {"M": {"pipeline": {"weather": {"enabled": True}}}}}
        self.assertTrue(pipeline_step_enabled_anywhere(yaml_data, "weather"))


class TestPipelineStepSubflag(unittest.TestCase):
    """pipeline_step_subflag — pipeline.presets.kneeboards (FEAT-PRESETS-KNEEBOARD-TOGGLE)."""

    def test_scalar_true_returns_default(self) -> None:
        # Scalar form carries no sub-flags → default applies.
        self.assertTrue(pipeline_step_subflag({"presets": True}, "presets", "kneeboards", True))

    def test_absent_step_returns_default(self) -> None:
        self.assertTrue(pipeline_step_subflag({}, "presets", "kneeboards", True))

    def test_mapping_without_subkey_returns_default(self) -> None:
        self.assertTrue(pipeline_step_subflag({"presets": {"enabled": True}}, "presets", "kneeboards", True))

    def test_mapping_subkey_false_overrides(self) -> None:
        self.assertFalse(pipeline_step_subflag({"presets": {"kneeboards": False}}, "presets", "kneeboards", True))

    def test_mapping_subkey_true(self) -> None:
        self.assertTrue(pipeline_step_subflag({"presets": {"kneeboards": True}}, "presets", "kneeboards", True))


if __name__ == "__main__":
    unittest.main()
