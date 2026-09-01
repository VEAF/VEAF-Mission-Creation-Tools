"""Guard: the static Lua bundle manifest stays in sync with the files on disk.

The static `veaf-scripts.lua` bundle is built by concatenating the modules listed in
`LUA_BUNDLE_SCRIPTS` (plus `veaf.lua` first). Any `src/scripts/veaf/*.lua` file that is
neither in that list nor explicitly excluded is **silently dropped** from
static/distribution builds — which is exactly how `veafSpawnParser.lua` (defining
`veafSpawn.convertLaserToFreq` / `markTextAnalysis`) was lost after the spawn refactor,
breaking `_cas` and `_spawn` parsing in static missions while dynamic builds kept working.
"""

from __future__ import annotations

import re
import unittest

from veaf_build.worker import _PROJECT_ROOT, LUA_BUNDLE_EXCLUDED, LUA_BUNDLE_SCRIPTS

_VEAF_SCRIPTS_DIR = _PROJECT_ROOT / "src" / "scripts" / "veaf"

_SPAWN_PROXY = _VEAF_SCRIPTS_DIR / "veafSpawn.lua"
_DOFILE_RE = re.compile(r'dofile\(_dir \.\. "([^"]+)"\)')


def _spawn_submodules_on_disk() -> set[str]:
    """Every `veafSpawn*.lua` sub-module, i.e. all of them but the `veafSpawn.lua` proxy."""
    return {p.name for p in _VEAF_SCRIPTS_DIR.glob("veafSpawn*.lua")} - {_SPAWN_PROXY.name}


def _spawn_proxy_dofiles() -> list[str]:
    """The file names the `veafSpawn.lua` proxy loads, in order."""
    return _DOFILE_RE.findall(_SPAWN_PROXY.read_text(encoding="utf-8"))


class TestLuaBundleManifest(unittest.TestCase):
    def test_every_veaf_lua_file_is_bundled_or_explicitly_excluded(self) -> None:
        on_disk = {p.name for p in _VEAF_SCRIPTS_DIR.glob("*.lua")}
        accounted = set(LUA_BUNDLE_SCRIPTS) | LUA_BUNDLE_EXCLUDED

        missing = on_disk - accounted  # on disk but neither bundled nor excluded
        stale = accounted - on_disk  # listed but no longer on disk
        self.assertEqual(
            missing,
            set(),
            f"these veaf/*.lua files are neither bundled nor excluded (they would be "
            f"silently dropped from static builds): {sorted(missing)}",
        )
        self.assertEqual(stale, set(), f"manifest references files that no longer exist: {sorted(stale)}")

    def test_no_duplicate_entries(self) -> None:
        self.assertEqual(
            len(LUA_BUNDLE_SCRIPTS), len(set(LUA_BUNDLE_SCRIPTS)), "LUA_BUNDLE_SCRIPTS has duplicate entries"
        )

    def test_bundle_and_excluded_are_disjoint(self) -> None:
        # A file must not be both bundled and explicitly excluded.
        self.assertTrue(
            set(LUA_BUNDLE_SCRIPTS).isdisjoint(LUA_BUNDLE_EXCLUDED),
            "a veaf/*.lua file is both bundled and explicitly excluded",
        )

    def test_spawn_parser_bundled_after_core(self) -> None:
        # veafSpawnParser extends the veafSpawn table created by veafSpawnCore, so it
        # must be concatenated after it (the original regression: parser was absent).
        self.assertIn("veafSpawnParser.lua", LUA_BUNDLE_SCRIPTS)
        self.assertLess(
            LUA_BUNDLE_SCRIPTS.index("veafSpawnCore.lua"),
            LUA_BUNDLE_SCRIPTS.index("veafSpawnParser.lua"),
        )


class TestSpawnProxyLoadsEverySubModule(unittest.TestCase):
    """Guard: the one place in this repo where a missing line fails silently.

    `veafSpawn.lua` is a proxy whose only job is to `dofile` its sub-modules for the
    dynamic (non-bundled) load path. Forgetting one there raises no error at load time:
    the module's functions simply never exist, and the mission only finds out when a
    player types the command. `LUA_BUNDLE_SCRIPTS` covers the static build, this covers
    the dynamic one.
    """

    def test_every_spawn_submodule_is_loaded_by_the_proxy(self) -> None:
        missing = _spawn_submodules_on_disk() - set(_spawn_proxy_dofiles())
        self.assertEqual(
            missing,
            set(),
            f"these veafSpawn sub-modules exist on disk but {_SPAWN_PROXY.name} never dofile()s them, "
            f"so they are silently absent from dynamic builds: {sorted(missing)}",
        )

    def test_proxy_does_not_load_a_file_that_is_gone(self) -> None:
        stale = set(_spawn_proxy_dofiles()) - _spawn_submodules_on_disk()
        self.assertEqual(stale, set(), f"{_SPAWN_PROXY.name} dofile()s files that no longer exist: {sorted(stale)}")

    def test_proxy_order_matches_bundle_order(self) -> None:
        # Command handlers register at load time into an ordered list and dispatch is
        # first-match-wins, so the dynamic path must register them in the same order as
        # the concatenated bundle does.
        bundled = [name for name in LUA_BUNDLE_SCRIPTS if name in _spawn_submodules_on_disk()]
        self.assertEqual(_spawn_proxy_dofiles(), bundled)


if __name__ == "__main__":
    unittest.main()
