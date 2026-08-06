"""Tests for veaf_libs.veaf_shortcuts_scanner."""

from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

from veaf_libs.veaf_shortcuts_scanner import (
    _find_shortcuts_lua,
    _parse_aliases,
    generate_shortcuts_json,
    get_shortcuts,
)

# A miniature `buildDefaultList()` body exercising every shape the real file uses:
# multi-line block, single-line block, a hidden alias (must be dropped), and a
# batch alias (no setVeafCommand → empty veafCommand).
_FAKE_LUA = """\
function veafShortcuts.buildDefaultList()
  veafShortcuts.AddAlias(
    VeafAlias:new()
      :setName("-samLR")
      :setDescription("Random long range SAM battery")
      :setVeafCommand("_spawn samgroup, skynet true")
      :setBypassSecurity(false)
  )
  veafShortcuts.AddAlias(
    VeafAlias:new():setName("-jtac"):setDescription("JTAC humvee"):setVeafCommand("_spawn jtac"):setBypassSecurity(true)
  )
  veafShortcuts.AddAlias(VeafAlias
    :new()
    :setName("-login")
    :setDescription("Unlock the system")
    :setHidden(true)
    :setVeafCommand("_auth")
    :setBypassSecurity(false))
  veafShortcuts.AddAlias(
    VeafAlias:new()
      :setName("-arty1")
      :setDescription("Spawns ARTY-1")
      :setBatchAliases({ "-arty, unitname arty-1" })
  )
end

function veafShortcuts.somethingElse()
  veafShortcuts.AddAlias(VeafAlias:new():setName("-notInDefaultList"):setVeafCommand("_x"))
end
"""


class TestParseAliases(unittest.TestCase):
    def test_extracts_multiline_alias(self) -> None:
        aliases = _parse_aliases(_FAKE_LUA)
        by_name = {a["aliases"][0]: a for a in aliases}
        self.assertIn("-samLR", by_name)
        self.assertEqual(by_name["-samLR"]["description"], "Random long range SAM battery")
        self.assertEqual(by_name["-samLR"]["veafCommand"], "_spawn samgroup, skynet true")

    def test_extracts_single_line_alias(self) -> None:
        by_name = {a["aliases"][0]: a for a in _parse_aliases(_FAKE_LUA)}
        self.assertIn("-jtac", by_name)
        self.assertEqual(by_name["-jtac"]["veafCommand"], "_spawn jtac")

    def test_hidden_alias_excluded(self) -> None:
        names = [a["aliases"][0] for a in _parse_aliases(_FAKE_LUA)]
        self.assertNotIn("-login", names)

    def test_batch_alias_has_empty_command(self) -> None:
        by_name = {a["aliases"][0]: a for a in _parse_aliases(_FAKE_LUA)}
        self.assertIn("-arty1", by_name)
        self.assertEqual(by_name["-arty1"]["veafCommand"], "")

    def test_only_scans_build_default_list(self) -> None:
        # Aliases defined in other functions must not leak in.
        names = [a["aliases"][0] for a in _parse_aliases(_FAKE_LUA)]
        self.assertNotIn("-notInDefaultList", names)

    def test_empty_content(self) -> None:
        self.assertEqual(_parse_aliases(""), [])


class TestGenerateShortcutsJson(unittest.TestCase):
    def test_generates_valid_json_file(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            lua_file = tmp_path / "veafShortcuts.lua"
            lua_file.write_text(_FAKE_LUA, encoding="utf-8")
            output_path = tmp_path / "veaf-shortcuts.json"

            count = generate_shortcuts_json(output_path, lua_file)

            self.assertEqual(count, 3)  # samLR, jtac, arty1 (login hidden, notInDefaultList out of scope)
            data = json.loads(output_path.read_text(encoding="utf-8"))
            self.assertIsInstance(data, list)
            self.assertEqual(len(data), 3)

    def test_missing_lua_file_writes_empty(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            output_path = tmp_path / "veaf-shortcuts.json"
            count = generate_shortcuts_json(output_path, tmp_path / "absent.lua")
            self.assertEqual(count, 0)
            self.assertEqual(json.loads(output_path.read_text(encoding="utf-8")), [])


class TestGetShortcutsAgainstRealFile(unittest.TestCase):
    """Integration: scan the real veafShortcuts.lua shipped in the repo."""

    def test_finds_real_lua(self) -> None:
        self.assertIsNotNone(_find_shortcuts_lua())

    def test_surfaces_samlr_not_hidden_login(self) -> None:
        shortcuts = get_shortcuts()
        names = {a["aliases"][0] for a in shortcuts}
        self.assertIn("-samLR", names)
        self.assertIn("-samSR", names)
        self.assertNotIn("-login", names)  # hidden alias must be excluded

    def test_shape_of_entries(self) -> None:
        shortcuts = get_shortcuts()
        self.assertGreater(len(shortcuts), 50)  # buildDefaultList defines ~120 visible aliases
        entry = shortcuts[0]
        self.assertIn("aliases", entry)
        self.assertIn("description", entry)
        self.assertIn("veafCommand", entry)


if __name__ == "__main__":
    unittest.main()


class TestLocalArtefactIsFresh(unittest.TestCase):
    """A leftover ``veaf-shortcuts.json`` must not disagree with the Lua it came from.

    The file is **gitignored** — a local build artefact, absent from a clean checkout and from CI, where
    ``get_shortcuts()`` therefore falls through to scanning the Lua. But when it *is* present it wins,
    and a stale one silently overrides the parser, its exclusion of internal aliases included.

    Not hypothetical: on this workstation it had drifted to 128 entries while the parser produced 123,
    so ``list_shortcuts`` was offering ``-login`` and ``-logout``, and
    ``test_surfaces_samlr_not_hidden_login`` failed locally while CI stayed green. That is the worst
    shape of divergence — it appears only to the person holding the stale file.

    Skipped rather than failed when absent: on CI that is the normal, correct state.
    """

    def test_a_present_artefact_matches_a_fresh_scan(self):
        root = Path(__file__).parents[3]
        artefact = root / "src" / "python" / "veaf-tools" / "veaf_libs" / "veaf-shortcuts.json"
        if not artefact.is_file():
            self.skipTest("no local veaf-shortcuts.json — the clean-checkout and CI case")

        fresh = _parse_aliases(
            (root / "src" / "scripts" / "veaf" / "veafShortcuts.lua").read_text(encoding="utf-8", errors="ignore")
        )
        assert json.loads(artefact.read_text(encoding="utf-8")) == fresh, (
            "the local veaf-shortcuts.json is stale — regenerate it with "
            "veaf_libs.veaf_shortcuts_scanner.generate_shortcuts_json(), or delete it. It wins over "
            "scanning, so a stale copy overrides the parser and its internal-alias exclusion, and only "
            "you will see the difference."
        )
