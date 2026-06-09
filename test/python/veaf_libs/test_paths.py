"""Tests for veaf_libs.paths — resolve_path and resolve_mission_file."""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

import typer


class TestResolvePath(unittest.TestCase):
    def test_path_provided_resolves(self) -> None:
        from veaf_libs.paths import resolve_path

        with tempfile.TemporaryDirectory() as tmpdir:
            p = Path(tmpdir) / "file.txt"
            p.write_text("x", encoding="utf-8")
            result = resolve_path(path=str(p))
            self.assertEqual(result, p.resolve())

    def test_default_path_used_when_path_is_none(self) -> None:
        from veaf_libs.paths import resolve_path

        with tempfile.TemporaryDirectory() as tmpdir:
            p = Path(tmpdir) / "default.txt"
            p.write_text("x", encoding="utf-8")
            result = resolve_path(default_path=str(p))
            self.assertEqual(result, p.resolve())

    def test_neither_path_raises(self) -> None:
        from veaf_libs.paths import resolve_path

        with self.assertRaises((typer.Abort, SystemExit, ValueError)):
            resolve_path()

    def test_create_directory_if_not_exist(self) -> None:
        from veaf_libs.paths import resolve_path

        with tempfile.TemporaryDirectory() as tmpdir:
            new_dir = Path(tmpdir) / "new_subdir"
            result = resolve_path(path=str(new_dir), create_if_not_exist=True)
            self.assertTrue(result.is_dir())

    def test_create_parent_for_file_path(self) -> None:
        from veaf_libs.paths import resolve_path

        with tempfile.TemporaryDirectory() as tmpdir:
            new_file = Path(tmpdir) / "sub" / "file.txt"
            result = resolve_path(path=str(new_file), create_if_not_exist=True)
            self.assertTrue(result.parent.is_dir())

    def test_should_exist_raises_when_missing(self) -> None:
        from veaf_libs.paths import resolve_path

        with tempfile.TemporaryDirectory() as tmpdir:
            missing = Path(tmpdir) / "does_not_exist.txt"
            with self.assertRaises((typer.Abort, SystemExit, FileNotFoundError)):
                resolve_path(path=str(missing), should_exist=True)

    def test_should_exist_passes_for_existing_path(self) -> None:
        from veaf_libs.paths import resolve_path

        with tempfile.TemporaryDirectory() as tmpdir:
            p = Path(tmpdir) / "exists.txt"
            p.write_text("x", encoding="utf-8")
            result = resolve_path(path=str(p), should_exist=True)
            self.assertEqual(result, p.resolve())

    def test_path_takes_precedence_over_default(self) -> None:
        from veaf_libs.paths import resolve_path

        with tempfile.TemporaryDirectory() as tmpdir:
            preferred = Path(tmpdir) / "preferred.txt"
            default = Path(tmpdir) / "default.txt"
            preferred.write_text("x", encoding="utf-8")
            result = resolve_path(path=str(preferred), default_path=str(default))
            self.assertEqual(result, preferred.resolve())


class TestResolveMissionFile(unittest.TestCase):
    def test_none_uses_default_name(self) -> None:
        from veaf_libs.paths import resolve_mission_file

        with tempfile.TemporaryDirectory() as tmpdir:
            folder = Path(tmpdir)
            miz = folder / "mission.miz"
            miz.write_bytes(b"PK")
            result = resolve_mission_file(folder, name_or_file=None)
            self.assertEqual(result, miz.resolve())

    def test_absolute_miz_path_resolved_directly(self) -> None:
        from veaf_libs.paths import resolve_mission_file

        with tempfile.TemporaryDirectory() as tmpdir:
            folder = Path(tmpdir)
            miz = folder / "custom.miz"
            miz.write_bytes(b"PK")
            result = resolve_mission_file(folder, name_or_file=miz)
            self.assertEqual(result, miz.resolve())

    def test_relative_miz_path_resolved_in_folder(self) -> None:
        from veaf_libs.paths import resolve_mission_file

        with tempfile.TemporaryDirectory() as tmpdir:
            folder = Path(tmpdir)
            miz = folder / "my_mission.miz"
            miz.write_bytes(b"PK")
            result = resolve_mission_file(folder, name_or_file="my_mission.miz")
            self.assertEqual(result, miz.resolve())

    def test_stem_glob_finds_most_recent(self) -> None:
        from veaf_libs.paths import resolve_mission_file

        with tempfile.TemporaryDirectory() as tmpdir:
            folder = Path(tmpdir)
            older = folder / "mission_v1.miz"
            newer = folder / "mission_v2.miz"
            older.write_bytes(b"PK")
            import time

            time.sleep(0.01)
            newer.write_bytes(b"PK")
            result = resolve_mission_file(folder, name_or_file="mission")
            self.assertEqual(result, newer.resolve())

    def test_custom_default_name(self) -> None:
        from veaf_libs.paths import resolve_mission_file

        with tempfile.TemporaryDirectory() as tmpdir:
            folder = Path(tmpdir)
            miz = folder / "custom_default.miz"
            miz.write_bytes(b"PK")
            result = resolve_mission_file(folder, default_name="custom_default.miz")
            self.assertEqual(result, miz.resolve())


if __name__ == "__main__":
    unittest.main()
