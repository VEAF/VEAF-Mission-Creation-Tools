# 01 — Each module in its own block, and a test that runs the bundle

Status: 🔄 in-progress

- `veaf_build/worker.py`: one function writes a module's section of the bundle, `do` after its START banner and `end` before its END banner; used for `veaf.lua` and every module of `LUA_BUNDLE_SCRIPTS`.
- `test/python/veaf_build/test_lua_bundle_runs.py`: the section is wrapped; the whole bundle, built from `src/scripts/veaf/`, loads and runs under Lua 5.1 with `test/lua/dcs_mocks.lua` and defines `veaf`, `veafCampaign`, `veafOpposition`. Skipped without Lua 5.1, except when `VEAF_REQUIRE_LUA51` is set.
- `.github/workflows/lua-ci.yml`: the Lua coverage job, which has Lua 5.1, runs that test with `VEAF_REQUIRE_LUA51=1`.
- `known-limitations.yaml`: the 200-locals limit of a Lua 5.1 chunk, measured.
