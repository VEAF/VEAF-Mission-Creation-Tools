"""Tests for mission_constants — list-returning getters and collect_files_from_globs."""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from mission_tools.mission_constants import (
    collect_files_from_globs,
    get_community_script_files,
    get_legacy_script_files,
    get_mission_data_files,
    get_mission_files_to_cleanup_on_extract,
    get_mission_script_files,
    get_veaf_script_files,
)


class TestGetterFunctions(unittest.TestCase):
    def test_legacy_scripts_returns_list_of_tuples(self) -> None:
        result = get_legacy_script_files()
        self.assertIsInstance(result, list)
        self.assertTrue(len(result) > 0)
        for item in result:
            self.assertIsInstance(item, tuple)
            self.assertEqual(len(item), 2)

    def test_community_scripts_returns_list_of_tuples(self) -> None:
        result = get_community_script_files()
        self.assertIsInstance(result, list)
        self.assertTrue(len(result) > 0)
        for item in result:
            self.assertIsInstance(item, tuple)
            self.assertEqual(len(item), 2)

    def test_veaf_script_files_returns_nonempty(self) -> None:
        result = get_veaf_script_files()
        self.assertIsInstance(result, list)
        self.assertGreater(len(result), 0)

    def test_mission_script_files_returns_nonempty(self) -> None:
        result = get_mission_script_files()
        self.assertIsInstance(result, list)
        self.assertGreater(len(result), 0)

    def test_mission_data_files_returns_nonempty(self) -> None:
        result = get_mission_data_files()
        self.assertIsInstance(result, list)
        self.assertGreater(len(result), 0)

    def test_mission_files_to_cleanup_returns_nonempty(self) -> None:
        result = get_mission_files_to_cleanup_on_extract()
        self.assertIsInstance(result, list)
        self.assertGreater(len(result), 0)
        for item in result:
            self.assertIsInstance(item, tuple)
            self.assertEqual(len(item), 2)

    def test_legacy_scripts_include_known_files(self) -> None:
        paths = [item[0] for item in get_legacy_script_files()]
        self.assertTrue(any("veaf-scripts-debug" in p for p in paths))

    def test_community_scripts_include_mist(self) -> None:
        paths = [item[0] for item in get_community_script_files()]
        self.assertTrue(any("mist.lua" in p for p in paths))

    def test_all_getter_return_types(self) -> None:
        for fn in [
            get_legacy_script_files,
            get_community_script_files,
            get_veaf_script_files,
            get_mission_script_files,
            get_mission_data_files,
        ]:
            result = fn()
            self.assertIsInstance(result, list, f"{fn.__name__} should return a list")


class TestCollectFilesFromGlobs(unittest.TestCase):
    def _setup_tree(self, base: Path) -> None:
        (base / "src" / "scripts").mkdir(parents=True)
        (base / "src" / "scripts" / "mission.lua").write_bytes(b"-- mission")
        (base / "src" / "scripts" / "helper.lua").write_bytes(b"-- helper")
        (base / "src" / "data").mkdir()
        (base / "src" / "data" / "config.json").write_bytes(b"{}")

    def test_exact_file_collected(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            base = Path(td)
            self._setup_tree(base)
            patterns = [("src/scripts/mission.lua", "l10n/DEFAULT")]
            result = collect_files_from_globs(base, patterns)
            self.assertTrue(len(result) >= 1)

    def test_glob_pattern_collects_multiple(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            base = Path(td)
            self._setup_tree(base)
            patterns = [("src/scripts/*.lua", "l10n/DEFAULT")]
            result = collect_files_from_globs(base, patterns)
            self.assertGreaterEqual(len(result), 2)

    def test_nonexistent_file_returns_empty(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            base = Path(td)
            patterns = [("no/such/file.lua", "l10n/DEFAULT")]
            result = collect_files_from_globs(base, patterns)
            self.assertEqual(result, {})

    def test_alternative_folder_fallback(self) -> None:
        with tempfile.TemporaryDirectory() as td1, tempfile.TemporaryDirectory() as td2:
            base = Path(td1)
            alt = Path(td2)
            (alt / "src" / "scripts").mkdir(parents=True)
            (alt / "src" / "scripts" / "fallback.lua").write_bytes(b"-- fallback")
            patterns = [("src/scripts/fallback.lua", "l10n/DEFAULT")]
            result = collect_files_from_globs(base, patterns, alternative_folder=alt)
            self.assertTrue(len(result) >= 1)

    def test_returns_dict_with_bytes_values(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            base = Path(td)
            self._setup_tree(base)
            patterns = [("src/scripts/mission.lua", "l10n/DEFAULT")]
            result = collect_files_from_globs(base, patterns)
            for key, value in result.items():
                self.assertIsInstance(key, str)
                self.assertIsInstance(value, bytes)

    def test_double_star_glob_recursive(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            base = Path(td)
            (base / "src" / "mission").mkdir(parents=True)
            (base / "src" / "mission" / "deep.txt").write_bytes(b"content")
            patterns = [("src/mission/**", "")]
            result = collect_files_from_globs(base, patterns)
            self.assertTrue(len(result) >= 1)


if __name__ == "__main__":
    unittest.main()
