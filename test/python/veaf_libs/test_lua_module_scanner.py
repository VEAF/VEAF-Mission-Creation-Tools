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
    scan_module_initialisation,
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


# ---------------------------------------------------------------------------
# scan_module_initialisation
# ---------------------------------------------------------------------------


class TestScanModuleInitialisation(unittest.TestCase):
    """Unit-level checks on synthetic sources.

    The cross-check against the real tree lives in ``test_module_init_registry.py``; this class
    covers the parser's edge cases, which the repository's own files do not all exercise.
    """

    @staticmethod
    def _write(directory: Path, name: str, content: str) -> None:
        (directory / name).write_text(content, encoding="utf-8")

    def test_empty_dir(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            self.assertEqual(scan_module_initialisation(Path(tmp)), {})

    def test_a_file_with_no_id_line_is_not_a_module(self) -> None:
        """``veaf.lua`` itself falls here: it declares ``registerModule`` and registers CTLD."""
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            self._write(
                tmp_path,
                "veaf.lua",
                "function veaf.registerModule(id, initFn, defaults, order)\nend\n"
                "veaf.registerModule(veaf.ctldId, veaf.ctld_initialize, { enable = true }, 50)\n",
            )
            self.assertEqual(scan_module_initialisation(tmp_path), {})

    def test_a_registration_for_another_table_is_ignored(self) -> None:
        """Only ``<the file's own table>.Id`` counts, so a foreign registration cannot be claimed."""
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            self._write(
                tmp_path,
                "veafThing.lua",
                'veafThing.Id = "THING"\n'
                "function veafThing.initialize()\nend\n"
                "veaf.registerModule(veafOther.Id, veafOther.initialize, { enable = true }, 42)\n",
            )
            facts = scan_module_initialisation(tmp_path)
            self.assertFalse(facts["THING"]["registers"])
            self.assertIsNone(facts["THING"]["order"])

    def test_order_defaults_to_100_when_omitted(self) -> None:
        """``registerModule`` itself defaults to 100; the scan must report the same number."""
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            self._write(
                tmp_path,
                "veafThing.lua",
                'veafThing.Id = "THING"\n'
                "function veafThing.initialize()\nend\n"
                "veaf.registerModule(veafThing.Id, veafThing.initialize, { enable = true })\n",
            )
            self.assertEqual(scan_module_initialisation(tmp_path)["THING"]["order"], 100)

    def test_a_closure_registration_is_parsed_with_its_braces_and_commas(self) -> None:
        """The closure body holds both, which is what defeats a single-regex parse."""
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            self._write(
                tmp_path,
                "veafThing.lua",
                'veafThing.Id = "THING"\n'
                "function veafThing.initialize(a, b)\nend\n"
                "veaf.registerModule(veafThing.Id, function()\n"
                "  local cfg = veaf.getConfig(veafThing.Id)\n"
                "  veafThing.initialize(cfg.a, cfg.b)\n"
                "end, { enable = true, a = false }, 77)\n",
            )
            facts = scan_module_initialisation(tmp_path)["THING"]
            self.assertTrue(facts["registers"])
            self.assertTrue(facts["wrapped"])
            self.assertEqual(facts["order"], 77)
            self.assertEqual(facts["init_params"], "a, b")

    def test_a_commented_out_registration_does_not_count(self) -> None:
        """Both comment forms, because two module files keep a ``--[[ … ]]`` scratch block."""
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            self._write(
                tmp_path,
                "veafThing.lua",
                'veafThing.Id = "THING"\n'
                "function veafThing.initialize()\nend\n"
                "-- veaf.registerModule(veafThing.Id, veafThing.initialize, { enable = true }, 1)\n"
                "--[[\nveafThing.initialize()\n"
                "veaf.registerModule(veafThing.Id, veafThing.initialize, { enable = true }, 2)\n]]\n",
            )
            facts = scan_module_initialisation(tmp_path)["THING"]
            self.assertFalse(facts["registers"])
            self.assertFalse(facts["self_initialises"])

    def test_self_initialisation_is_only_a_top_level_call(self) -> None:
        """An indented call is somebody's function body, not initialisation at load."""
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            self._write(
                tmp_path,
                "veafInner.lua",
                'veafInner.Id = "INNER"\n'
                "function veafInner.initialize()\nend\n"
                "function veafInner.restart()\n  veafInner.initialize()\nend\n",
            )
            self._write(
                tmp_path,
                "veafOuter.lua",
                'veafOuter.Id = "OUTER"\nfunction veafOuter.initialize()\nend\nveafOuter.initialize()\n',
            )
            facts = scan_module_initialisation(tmp_path)
            self.assertFalse(facts["INNER"]["self_initialises"])
            self.assertTrue(facts["OUTER"]["self_initialises"])

    def test_a_module_with_no_initialize_is_reported_as_such(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            self._write(tmp_path, "veafData.lua", 'veafData.Id = "DATA"\nveafData.table = {}\n')
            facts = scan_module_initialisation(tmp_path)["DATA"]
            self.assertFalse(facts["has_initialize"])
            self.assertEqual(facts["init_params"], "")


if __name__ == "__main__":
    unittest.main()
