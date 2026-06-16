"""Guard: the static Lua bundle manifest stays in sync with the files on disk.

The static `veaf-scripts.lua` bundle is built by concatenating the modules listed in
`LUA_BUNDLE_SCRIPTS` (plus `veaf.lua` first). Any `src/scripts/veaf/*.lua` file that is
neither in that list nor explicitly excluded is **silently dropped** from
static/distribution builds — which is exactly how `veafSpawnParser.lua` (defining
`veafSpawn.convertLaserToFreq` / `markTextAnalysis`) was lost after the spawn refactor,
breaking `_cas` and `_spawn` parsing in static missions while dynamic builds kept working.
"""

from __future__ import annotations

import unittest

from veaf_build.worker import _PROJECT_ROOT, LUA_BUNDLE_EXCLUDED, LUA_BUNDLE_SCRIPTS

_VEAF_SCRIPTS_DIR = _PROJECT_ROOT / "src" / "scripts" / "veaf"


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


if __name__ == "__main__":
    unittest.main()
