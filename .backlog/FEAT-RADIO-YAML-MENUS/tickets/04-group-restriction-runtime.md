# 04 — Group restriction (DCS group name → group id at runtime)

Status: ⬜ ready

## Context

v5 restricted a user menu to the Mission Master by passing a numeric
`MISSION_MASTER_GROUPID` to `veafRadio.createUserMenu(config, groupId)` (→
`addSubMenuForGroup` / `addCommandForGroup`). YAML uses the **DCS group name**
instead (ADR 0011); the id is only known at runtime.

`veafRadio.createUserMenu(configuration, groupId)` already accepts a numeric
`groupId`. This ticket adds name-based resolution so the generated config can pass a
group **name** from YAML (`restrict_to_group` / `radio_menu_restrict_to_group`).

## Tasks

- [ ] Lua: resolve a group name → group id at menu-creation time (e.g. accept a name
      in `createUserMenu`, or a thin wrapper resolving via `Group.getByName(...):getID()`).
      Absent / unknown name → global menu, logged (not fatal).
- [ ] Generator (tickets 01–02): pass the group name from YAML into the generated
      call using this path.
- [ ] Lua unit tests (`test/lua/test_veafRadio.lua`): name resolves → ForGroup calls;
      unknown name → global; no name → global.

## Definition of Done

- A menu with `restrict_to_group: "<name>"` is created only for that group at
  runtime; unknown/absent name falls back to a global menu with a warning.
- `stylua --check` and `luacheck` (CI) green; Lua tests pass.
