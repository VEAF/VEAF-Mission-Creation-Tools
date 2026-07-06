# 01 — Action dispatch + `modules.RADIO.user_menus` generator

Status: ⬜ ready

## Context

`modules.RADIO` exposes only `help_menus` today (`lua_config_generator.py`,
`_MODULE_INIT_PARAMS`). Add a `user_menus` block that compiles a declarative
menu tree into a `veafRadio.createUserMenu(...)` call using the existing
`veafRadio.mainmenu()/menu()/command()` helpers. This ticket lands the dispatch
skeleton + the two Lua-free vocabulary actions that need no other module:
`flag.*` and `message`.

## Tasks

- [ ] Define the action dispatch (Python side): map each vocabulary action to the
      Lua call it emits. Land `flag.on/off/set/increment/decrement`
      (→ `veafSpawn.missionMasterSetFlag` / `missionMasterAddValueToFlag`) and
      `message` (→ outText).
- [ ] Emit a `veafRadio.createUserMenu(...)` chain from `modules.RADIO.user_menus.tree`
      (recursive `menu` / `items`), mirroring the AirWave/QRA emit helpers already
      in `lua_config_generator.py`.
- [ ] `flag.set` requires `value`; `flag.on`/`off` map to value `1`/`0`.
- [ ] Group restriction (`restrict_to_group`) is threaded through as a parameter but
      its runtime resolution lands in ticket 04 — here just pass the group name to
      the generated call.

## Definition of Done

- Given a `RADIO.user_menus` YAML block, the generated config Lua builds the menu
  with `flag.*` / `message` commands; unit tests cover nesting + each flag verb.
- Quality ratchet: if `lua_config_generator.py` is substantially edited and still in
  the mypy `ignore_errors` list, drop it and fix the surfaced errors.
- `ruff`, `ruff format --check`, `mypy`, `pytest` green; coverage gate bumped.
