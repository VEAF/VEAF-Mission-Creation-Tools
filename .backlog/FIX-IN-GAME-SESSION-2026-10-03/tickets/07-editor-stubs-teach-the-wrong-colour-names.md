# 07 — the editor's DCS stubs teach the wrong colour names

Status: 🧑 waiting-human — not reproduced, one question for David (see the end)
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

## Measured (2026-10-03, afternoon) — not reproduced

`lua-language-server --check` (the VS Code extension's own binary, 3.19.1), on this branch, with the
addon copied in: **no** `undefined-field` on `Green`, `White`, `Orange`, `Blue` or `Yellow` anywhere —
the vendored schema is already in `Lua.workspace.library` and declares them. 319 problems in all.

Dropping the addon's `mission` library, as proposed: **344** problems — 94 duplicate and
`inject-field` diagnostics on the schema go away, 119 new ones appear (`log` undefined in the server
hooks, stricter signatures in the schema). Not a gain, so `.luarc.json` is left as it is.

The question: does David's editor underline `trigger.smokeColor.Green` in `veafSpawnParser.lua`? If
not, close as not reproduced.
