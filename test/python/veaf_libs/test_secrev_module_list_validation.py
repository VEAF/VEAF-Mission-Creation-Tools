"""SECREV-2 / VMR-061 — the bundled module list was trusted straight into Lua emission.

`get_modules()` read a JSON file (bundled in the exe, or pre-generated next to the module) and
returned `json.loads(...)` unchecked. A stale or truncated file therefore surfaced as a `KeyError`
far from its cause — inside the Lua config generator, while emitting a mission's init sequence.

The consumers do not even agree on what the entries must carry: `lua_config_generator` reads
`mod["var_name"]` directly, while `config_migrator` uses `.get("var_name")` with a comment saying
old bundled JSON did not have it. So a JSON that one accepts, the other crashes on.
"""

from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from veaf_libs import lua_module_scanner
from veaf_libs.lua_module_scanner import get_modules


def _with_bundled(payload: object) -> Path:
    folder = Path(tempfile.mkdtemp())
    path = folder / "veaf_modules_list.json"
    path.write_text(json.dumps(payload), encoding="utf-8")
    return path


class TestBundledModuleListIsValidated(unittest.TestCase):
    def _get_modules_from(self, payload: object) -> list:
        path = _with_bundled(payload)
        with mock.patch.object(lua_module_scanner, "_bundled_json_path", return_value=path):
            return get_modules()

    def test_a_well_formed_list_is_returned(self) -> None:
        # The control: the normal payload must go through untouched.
        modules = self._get_modules_from(
            [{"id": "SPAWN", "version": "1.0", "filename": "veafSpawnCore.lua", "var_name": "veafSpawn"}]
        )
        self.assertEqual(len(modules), 1)
        self.assertEqual(modules[0]["id"], "SPAWN")
        self.assertEqual(modules[0]["var_name"], "veafSpawn")

    def test_a_missing_var_name_is_filled_in_from_the_filename(self) -> None:
        # An old bundled JSON has no var_name. config_migrator already coped with that;
        # lua_config_generator read the key directly and raised. Normalised here instead, so both
        # consumers see the same shape.
        modules = self._get_modules_from([{"id": "SPAWN", "filename": "veafSpawnCore.lua"}])
        self.assertEqual(modules[0]["var_name"], "veafSpawnCore")
        self.assertEqual(modules[0]["version"], "")

    def test_an_entry_without_an_id_is_refused_by_name(self) -> None:
        with self.assertRaises(ValueError) as caught:
            self._get_modules_from([{"filename": "veafSpawnCore.lua"}])
        message = str(caught.exception)
        self.assertIn("id", message)
        self.assertIn("veaf_modules_list.json", message, "the refusal must name the file at fault")

    def test_an_entry_without_a_filename_is_refused(self) -> None:
        with self.assertRaises(ValueError):
            self._get_modules_from([{"id": "SPAWN"}])

    def test_an_empty_id_is_refused(self) -> None:
        # Present but blank is the shape a truncated generator run produces.
        with self.assertRaises(ValueError):
            self._get_modules_from([{"id": "", "filename": "veafSpawnCore.lua"}])

    def test_a_payload_that_is_not_a_list_is_refused(self) -> None:
        with self.assertRaises(ValueError):
            self._get_modules_from({"id": "SPAWN", "filename": "veafSpawnCore.lua"})

    def test_a_list_of_something_else_is_refused(self) -> None:
        with self.assertRaises(ValueError):
            self._get_modules_from(["veafSpawnCore.lua"])

    def test_an_empty_list_is_accepted(self) -> None:
        # Not an error: a mission tree with no VEAF modules is a legitimate state, and the live
        # scan already returns [] for it.
        self.assertEqual(self._get_modules_from([]), [])


class TestTheLiveScanStillWorks(unittest.TestCase):
    """The repo checkout path must be unaffected — it is what every developer run uses."""

    def test_the_repo_scan_returns_usable_entries(self) -> None:
        with (
            mock.patch.object(lua_module_scanner, "_bundled_json_path", return_value=None),
            mock.patch.object(lua_module_scanner, "_pregenerated_json_path", return_value=None),
        ):
            modules = get_modules()
        self.assertGreater(len(modules), 10, "the live scan found next to nothing")
        for mod in modules:
            self.assertTrue(mod["id"])
            self.assertTrue(mod["filename"])
            self.assertTrue(mod["var_name"], f"{mod['filename']} has no var_name")


if __name__ == "__main__":
    unittest.main()
