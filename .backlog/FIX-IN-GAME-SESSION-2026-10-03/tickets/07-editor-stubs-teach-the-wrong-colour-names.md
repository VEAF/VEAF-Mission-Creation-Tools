# 07 — the editor's DCS stubs teach the wrong colour names

Status: ⬜ ready
Type: chore

## Found

By the `pr-code-review` of #1054. The upper-case colour keys of ticket 01 were not an original
mistake: commit `7954b9fe` (2026-05-18, "fix(lint): … smokeColor case … DCS stubs") replaced correct
`Red` / `Green` with `RED` / `GREEN` to silence the editor. Its DCS stubs, the third-party addon in
`.lua-addons/dcs-world/library/mission/trigger.lua` (git-ignored, listed in `.luarc.json`'s
`Lua.workspace.library`), declare:

```lua
trigger.smokeColor = { GREEN = 0, Red = 1, RED = 1, ... }
trigger.flareColor = { GREEN = 0, RED = 1, WHITE = 2, ... }
```

DCS answers `Green`, `Red`, `White`, `Orange`, `Blue` / `Yellow` (measured 2026-10-03). Since #1054
the editor flags `Green`, `White`, `Orange`, `Blue` as undefined fields — against CLAUDE.md §3, "No
warnings or errors must remain in the editor" — and invites the same "fix" again.

## Already covered

A return to upper case fails CI: `test/python/test_lua_names_that_exist.py`.

## To do

Point the editor at the schema the repository already vendors and keeps current,
`src/python/veaf-tools/veaf_libs/data/dcs-schema/dcs-world-api.lua` (right names, lines 3461-3482),
instead of the addon's `mission` library — then check that the editor shows no new warning
elsewhere, since the two stub sets will not declare everything alike.
