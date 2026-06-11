"""Heuristic detection of custom Lua loaders (CONVERT-CUSTOM-LOADER-HINT).

A v5-style script that loads other scripts cannot be reliably auto-migrated, so
the build points the user at the v6 `custom_scripts:` mechanism instead.
"""

from __future__ import annotations

from mission_builder.mission_builder_worker import lua_loads_other_scripts


class TestLuaLoadsOtherScripts:
    def test_loadfile_detected(self) -> None:
        assert lua_loads_other_scripts('assert(loadfile(path .. "FgTools.lua"))()')

    def test_dofile_detected(self) -> None:
        assert lua_loads_other_scripts('dofile("scripts/x.lua")')

    def test_require_detected(self) -> None:
        assert lua_loads_other_scripts('local m = require("mymod")')

    def test_do_script_file_detected(self) -> None:
        assert lua_loads_other_scripts('a_do_script_file(getValueResourceByKey("X"))')

    def test_v5_dynamic_loader_detected(self) -> None:
        loader = (
            "local scriptsToLoad = { 'FgTools.lua', 'missionConfig.lua' }\n"
            "for _, s in pairs(scriptsToLoad) do assert(loadfile(base .. s))() end"
        )
        assert lua_loads_other_scripts(loader)

    def test_ordinary_script_not_flagged(self) -> None:
        ordinary = "veafSpawn.spawnConvoy({})\nlocal x = 1 + 2\ntrigger.action.outText('hi', 10)"
        assert not lua_loads_other_scripts(ordinary)

    def test_comment_mentioning_load_is_still_matched(self) -> None:
        # Heuristic is intentionally simple; a literal loadfile token matches even in prose.
        assert lua_loads_other_scripts("-- this used to call loadfile in v5")
