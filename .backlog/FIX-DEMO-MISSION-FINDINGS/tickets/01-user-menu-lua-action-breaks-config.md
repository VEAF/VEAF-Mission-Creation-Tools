# 01 — A `lua` user-menu action breaks the whole config

Status: ⬜ ready
Type: fix
Files: `src/python/veaf-tools/veaf_libs/lua_config_generator.py` (`lua` branch near l. 1489), `validate`, `doc/mission-maker/scripts/veafRadio*.md`, tests

## What happens

`modules.RADIO.user_menus` with `{ command: "…", action: lua, function: "demo.spawnCsar" }` is rendered as `veafRadio.command("…", demo.spawnCsar)`: a bare reference, **evaluated when `veaf-config.lua` loads**.
The docs say to define the function in `mission-script.lua`, which loads after `veaf-config.lua` (`VEAF_MapKey_ActionText_11000` then `11001`), so the reference is `nil` — `attempt to index global 'demo' (a nil value)` — and everything after that line in the config never runs.
`validate` and the build pass; they only check that the function name appears in the mission's Lua.

## Measured

Demo mission, 2026-10-05: `src/scripts/veaf-config.lua:62`; reproduced with `lua` 5.1 on stubs. Found by the code review of the demo before it was flown.

## Fix

Emit a function that resolves the name at click time, e.g. `function(...) return demo.spawnCsar(...) end` (and the `args` form likewise), so the declared load order works as documented.
Test: a generated config loaded on stubs with the function defined *after* it must not raise, and the click must call it.

## Demo workaround to remove

The demo's actions moved to a Lua menu built in `src/scripts/guided-tour.lua` (« Démo : actions »), and `tools/verify.py` rejects any `lua` action.
