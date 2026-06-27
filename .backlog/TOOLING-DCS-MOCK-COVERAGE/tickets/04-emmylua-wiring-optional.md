# TDM-004 — (optional follow-up) EmmyLua/LuaLS wiring for contributors

Status: ✅ done (delivered with the lot at David's request, though optional)
Type: feature (DX)
Files: vendored `dcs-world-api.lua` + `.luarc.json`

## What to build

For contributors who want IDE help **while writing** VEAF Lua: vendor the EmmyLua artifact
`dcs-world-api.lua` (same release as TDM-001) and add a `.luarc.json` pointing LuaLS at it,
for autocomplete + signature diagnostics in VSCode.

Not interesting for every maintainer (David: "pas pour moi, mais utile à d'autres") — hence
**optional**. The Selene artifact (`dcs-world-selene.yml`) is intentionally **not** adopted
(we already run luacheck + stylua; no third linter in CI).

## Acceptance criteria

- [x] `dcs-world-api.lua` vendored (same pinned release v0.3.5 as TDM-001)
- [x] `.luarc.json` wires LuaLS to it; documented in the developer README (FR/EN)
- [x] No CI impact (IDE-only; luacheck/stylua unchanged)

## Blocked by

TDM-001
