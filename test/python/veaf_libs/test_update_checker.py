"""Tests for veaf_libs.update_checker — pure-Python, no network calls."""

from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

from veaf_libs.update_checker import _load_cache, _save_cache, _version_tuple


class TestVersionTuple(unittest.TestCase):
    def test_simple_version(self) -> None:
        self.assertEqual(_version_tuple("6.1.0"), (6, 1, 0))

    def test_two_part_version(self) -> None:
        self.assertEqual(_version_tuple("1.2"), (1, 2))

    def test_pre_release_stripped(self) -> None:
        self.assertEqual(_version_tuple("6.1.0-rc1"), (6, 1, 0))

    def test_build_metadata_stripped(self) -> None:
        self.assertEqual(_version_tuple("6.1.0+build123"), (6, 1, 0))

    def test_both_pre_release_and_metadata_stripped(self) -> None:
        self.assertEqual(_version_tuple("6.1.0-alpha+build"), (6, 1, 0))

    def test_invalid_version_returns_zero_tuple(self) -> None:
        self.assertEqual(_version_tuple("not.a.version"), (0,))

    def test_version_comparison_newer(self) -> None:
        self.assertGreater(_version_tuple("6.2.0"), _version_tuple("6.1.0"))

    def test_version_comparison_older(self) -> None:
        self.assertLess(_version_tuple("5.9.9"), _version_tuple("6.0.0"))

    def test_version_comparison_equal(self) -> None:
        self.assertEqual(_version_tuple("6.0.0"), _version_tuple("6.0.0"))


class TestLoadCache(unittest.TestCase):
    def test_empty_dir_returns_empty_dict(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            result = _load_cache(Path(tmpdir))
            self.assertEqual(result, {})

    def test_valid_cache_loaded(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            cache_file = Path(tmpdir) / "update_check_cache.json"
            cache_file.write_text(json.dumps({"last_check": "2024-01-01", "latest": "6.2.0"}), encoding="utf-8")
            result = _load_cache(Path(tmpdir))
            self.assertEqual(result["latest"], "6.2.0")
            self.assertEqual(result["last_check"], "2024-01-01")

    def test_invalid_json_returns_empty_dict(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            cache_file = Path(tmpdir) / "update_check_cache.json"
            cache_file.write_text("{invalid json", encoding="utf-8")
            result = _load_cache(Path(tmpdir))
            self.assertEqual(result, {})


class TestSaveCache(unittest.TestCase):
    def test_cache_written(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            _save_cache(Path(tmpdir), "6.2.0")
            cache_file = Path(tmpdir) / "update_check_cache.json"
            self.assertTrue(cache_file.exists())
            data = json.loads(cache_file.read_text(encoding="utf-8"))
            self.assertEqual(data["latest"], "6.2.0")

    def test_cache_contains_today(self) -> None:
        from datetime import date

        with tempfile.TemporaryDirectory() as tmpdir:
            _save_cache(Path(tmpdir), "6.2.0")
            cache_file = Path(tmpdir) / "update_check_cache.json"
            data = json.loads(cache_file.read_text(encoding="utf-8"))
            self.assertEqual(data["last_check"], str(date.today()))

    def test_save_silently_ignores_errors(self) -> None:
        # Passing a non-writable path-like — should not raise
        _save_cache(Path("/nonexistent/path/that/wont/exist"), "6.2.0")


if __name__ == "__main__":
    unittest.main()
