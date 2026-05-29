"""Tests for veaf_libs.lua_module_scanner."""

from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

from veaf_libs.lua_module_scanner import (
    _extract_defaults,
    _find_lua_scripts_dir,
    _scan_lua_directory,
    find_lua_scripts_dir,
    generate_modules_json,
    get_modules,
    scan_module_configs,
)

# ---------------------------------------------------------------------------
# _find_lua_scripts_dir / find_lua_scripts_dir
# ---------------------------------------------------------------------------


class TestFindLuaScriptsDir(unittest.TestCase):
    def test_finds_src_scripts_veaf(self) -> None:
        """Should locate src/scripts/veaf in the repo checkout."""
        result = _find_lua_scripts_dir()
        self.assertIsNotNone(result)

    def test_public_wrapper_matches(self) -> None:
        self.assertEqual(find_lua_scripts_dir(), _find_lua_scripts_dir())

    def test_returned_dir_exists(self) -> None:
        d = _find_lua_scripts_dir()
        if d is not None:
            self.assertTrue(d.is_dir())

    def test_returned_dir_contains_lua_files(self) -> None:
        d = _find_lua_scripts_dir()
        if d is not None:
            lua_files = list(d.glob("veaf*.lua"))
            self.assertGreater(len(lua_files), 0)


# ---------------------------------------------------------------------------
# _scan_lua_directory
# ---------------------------------------------------------------------------


class TestScanLuaDirectory(unittest.TestCase):
    def _write_lua(self, directory: Path, name: str, content: str) -> Path:
        f = directory / name
        f.write_text(content, encoding="utf-8")
        return f

    def test_scan_empty_directory(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            result = _scan_lua_directory(Path(tmp))
            self.assertEqual(result, [])

    def test_scan_module_with_id_and_version(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            self._write_lua(
                tmp_path,
                "veafSpawn.lua",
                'veafSpawn.Id = "SPAWN"\nveafSpawn.Version = "6.0.1"\n',
            )
            modules = _scan_lua_directory(tmp_path)
            self.assertEqual(len(modules), 1)
            self.assertEqual(modules[0]["id"], "SPAWN")
            self.assertEqual(modules[0]["version"], "6.0.1")
            self.assertEqual(modules[0]["filename"], "veafSpawn.lua")

    def test_scan_module_without_version(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            self._write_lua(tmp_path, "veafTest.lua", 'veafTest.Id = "TEST"\n')
            modules = _scan_lua_directory(tmp_path)
            self.assertEqual(len(modules), 1)
            self.assertEqual(modules[0]["version"], "")

    def test_scan_ignores_non_veaf_files(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            self._write_lua(tmp_path, "other.lua", 'other.Id = "OTHER"\n')
            modules = _scan_lua_directory(tmp_path)
            self.assertEqual(modules, [])

    def test_scan_file_without_id_skipped(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            self._write_lua(tmp_path, "veafNoId.lua", "-- nothing useful\n")
            modules = _scan_lua_directory(tmp_path)
            self.assertEqual(modules, [])

    def test_scan_multiple_modules_sorted(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            self._write_lua(tmp_path, "veafZeta.lua", 'veafZeta.Id = "ZETA"\nveafZeta.Version = "1.0"\n')
            self._write_lua(tmp_path, "veafAlpha.lua", 'veafAlpha.Id = "ALPHA"\nveafAlpha.Version = "2.0"\n')
            modules = _scan_lua_directory(tmp_path)
            self.assertEqual(len(modules), 2)
            # sorted() → alphabetical: veafAlpha before veafZeta
            self.assertEqual(modules[0]["filename"], "veafAlpha.lua")
            self.assertEqual(modules[1]["filename"], "veafZeta.lua")


# ---------------------------------------------------------------------------
# generate_modules_json
# ---------------------------------------------------------------------------


class TestGenerateModulesJson(unittest.TestCase):
    def test_generates_valid_json_file(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            lua_dir = tmp_path / "lua"
            lua_dir.mkdir()
            (lua_dir / "veafTest.lua").write_text('veafTest.Id = "TEST"\nveafTest.Version = "1.0"\n')

            output_path = tmp_path / "modules.json"
            count = generate_modules_json(output_path, lua_dir)
            self.assertEqual(count, 1)
            self.assertTrue(output_path.exists())

            data = json.loads(output_path.read_text(encoding="utf-8"))
            self.assertIsInstance(data, list)
            self.assertEqual(len(data), 1)
            self.assertEqual(data[0]["id"], "TEST")

    def test_empty_lua_dir_writes_empty_json(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            lua_dir = tmp_path / "lua"
            lua_dir.mkdir()
            output_path = tmp_path / "modules.json"
            count = generate_modules_json(output_path, lua_dir)
            self.assertEqual(count, 0)
            data = json.loads(output_path.read_text(encoding="utf-8"))
            self.assertEqual(data, [])


# ---------------------------------------------------------------------------
# get_modules
# ---------------------------------------------------------------------------


class TestGetModules(unittest.TestCase):
    def test_returns_list(self) -> None:
        modules = get_modules()
        self.assertIsInstance(modules, list)

    def test_modules_have_id_version_filename(self) -> None:
        modules = get_modules()
        if modules:
            m = modules[0]
            self.assertIn("id", m)
            self.assertIn("version", m)
            self.assertIn("filename", m)


# ---------------------------------------------------------------------------
# _extract_defaults
# ---------------------------------------------------------------------------


class TestExtractDefaults(unittest.TestCase):
    def test_empty_string(self) -> None:
        self.assertEqual(_extract_defaults(""), {})

    def test_true_value(self) -> None:
        result = _extract_defaults("enabled = true")
        self.assertEqual(result, {"enabled": True})

    def test_false_value(self) -> None:
        result = _extract_defaults("debug = false")
        self.assertEqual(result, {"debug": False})

    def test_multiple_values(self) -> None:
        result = _extract_defaults("a = true, b = false, c = true")
        self.assertEqual(result, {"a": True, "b": False, "c": True})

    def test_non_boolean_ignored(self) -> None:
        result = _extract_defaults('name = "hello", count = 5')
        self.assertEqual(result, {})

    def test_mixed_boolean_and_other(self) -> None:
        result = _extract_defaults('enabled = true, name = "test", debug = false')
        self.assertEqual(result, {"enabled": True, "debug": False})


# ---------------------------------------------------------------------------
# scan_module_configs
# ---------------------------------------------------------------------------


class TestScanModuleConfigs(unittest.TestCase):
    def _write_lua(self, directory: Path, name: str, content: str) -> Path:
        f = directory / name
        f.write_text(content, encoding="utf-8")
        return f

    def test_empty_dir(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            result = scan_module_configs(Path(tmp))
            self.assertEqual(result, {})

    def test_module_with_register_call(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            content = """\
veafSpawn = {}
veafSpawn.Id = "SPAWN"
veafSpawn.Version = "6.0.0"
veaf.registerModule(veafSpawn.Id, function() end, {enabled = true, debug = false}, 10)
"""
            self._write_lua(tmp_path, "veafSpawn.lua", content)
            result = scan_module_configs(tmp_path)
            self.assertIn("SPAWN", result)
            self.assertEqual(result["SPAWN"]["enabled"], True)
            self.assertEqual(result["SPAWN"]["debug"], False)

    def test_module_without_register_call(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            self._write_lua(tmp_path, "veafNoReg.lua", 'veafNoReg.Id = "NOREG"\n')
            result = scan_module_configs(tmp_path)
            self.assertNotIn("NOREG", result)


if __name__ == "__main__":
    unittest.main()
