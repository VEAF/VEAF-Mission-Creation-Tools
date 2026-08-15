"""Tests for veaf_libs.update_checker — pure-Python, no network calls."""

from __future__ import annotations

import json
import tempfile
import unittest
from datetime import date
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


class TestAnUnreadableCurrentVersionSaysNothing(unittest.TestCase):
    """SECREV-2 / VMR-063 — `_version_tuple` falls back to (0,), below every real release.

    So an unreadable *current* version made the check confidently announce "a new version is
    available" on every single run. Saying nothing is the honest answer when we do not know what is
    installed.
    """

    def _run(self, current: str, latest: str = "6.20.0") -> list[str]:
        from unittest import mock

        from veaf_libs import update_checker

        printed: list[str] = []
        console = mock.MagicMock()
        console.print.side_effect = lambda *args, **kwargs: printed.append(str(args[0]) if args else "")

        with (
            mock.patch.object(update_checker.sys.stdout, "isatty", return_value=True),
            mock.patch.object(
                update_checker, "_load_cache", return_value={"latest": latest, "last_check": str(date.today())}
            ),
            mock.patch.object(update_checker, "_save_cache"),
        ):
            update_checker.check_for_updates(current, console)
        return printed

    def test_an_unreadable_version_produces_no_prompt(self) -> None:
        self.assertEqual(self._run("unknown"), [], "an unknown installed version must not claim to be old")

    def test_an_empty_version_produces_no_prompt(self) -> None:
        self.assertEqual(self._run(""), [])

    def test_the_sentinel_is_what_the_parser_returns_for_junk(self) -> None:
        # Pinning the link between the two: if the fallback changes, the guard must change with it.
        from veaf_libs.update_checker import _UNPARSEABLE_VERSION

        self.assertEqual(_version_tuple("not-a-version"), _UNPARSEABLE_VERSION)
        self.assertNotEqual(_version_tuple("6.13.0"), _UNPARSEABLE_VERSION)

    def test_a_readable_older_version_does_prompt(self) -> None:
        # The control that makes the tests above mean something: if the mocked cache were being
        # rejected, `latest` would be empty and nothing would print either way.
        printed = self._run("6.1.0")

        self.assertTrue(printed, "a genuinely older version must still be told about the update")
        self.assertTrue(any("6.20.0" in line for line in printed), printed)
