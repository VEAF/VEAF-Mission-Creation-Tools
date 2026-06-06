"""Unit tests for veaf_libs.build_profiles — PROF-005."""

from __future__ import annotations

import unittest
from unittest.mock import patch

from veaf_libs.build_profiles import _deep_merge, resolve_profile


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

    def test_known_profile_logs_info(self) -> None:
        with patch("veaf_libs.build_profiles.logger") as mock_logger:
            resolve_profile(self._YAML, "TEST")
            mock_logger.info.assert_called_once()
            info_msg: str = mock_logger.info.call_args[0][0]
            self.assertIn("TEST", info_msg)


if __name__ == "__main__":
    unittest.main()
