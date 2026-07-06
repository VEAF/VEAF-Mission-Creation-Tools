---
status: accepted
---

# Radio menus declared in YAML (module shortcut + Mission-Master menu)

## Context

Creating an F10 radio menu that is **not** part of the standard VEAF radio tree —
to start/stop a QRA, drive an AirWave, flip a mission flag — is only possible in
Lua today, via `veafRadio.createUserMenu(configuration, groupId)` called from
`mission-script.lua`. The `configuration` table is built with the
`veafRadio.mainmenu()` / `menu()` / `command()` helpers, and each `command` binds
a label to a **Lua function** + parameters. A mission-maker who does not write Lua
cannot add such menus, and the shipped example reads as Lua with no hint whether it
belongs in `mission.yaml` or an external script (Tripack's feedback).

The runtime plumbing already exists and is addressable by name:
`veafQraManager.get(name):start()/:stop()`, `veafAirWaves.get(name):start()/
:stop()/:reset()`, and the Mission-Master flag helpers in `veafSpawnCore.lua`
(`missionMasterSetFlag` / `Increment` / `Decrement`, `missionMasterOutText`).
QRA and AirWaves are the only "triggerable" subsystems with **no** standard radio
menu of their own — CombatZone, Carrier, CombatMission and Assets each already ship
one, so they are out of scope. The gap is purely the lack of a YAML surface.

A `command` cannot carry an arbitrary Lua function through YAML, so a declarative
**action vocabulary** is required.

## Decision

Expose radio menus in YAML through **two mechanisms sharing one action dispatch**.

**Action vocabulary** (fixed, no Lua authored inline):

| Action | Target key(s) | Runtime |
|--------|---------------|---------|
| `qra.start` / `qra.stop` | `qra:` | `veafQraManager.get(n):start()/:stop()` |
| `airwave.start` / `airwave.stop` / `airwave.reset` | `airwave:` | `veafAirWaves.get(n):start()/:stop()/:reset()` |
| `flag.on` / `flag.off` / `flag.set` / `flag.increment` / `flag.decrement` | `flag:` (+ `value:` for `set`) | `veafSpawn.missionMaster*Flag*` |
| `message` | `text:` | outText |
| `lua` | `function:` (+ `args:`) | a Lua function the maker defines elsewhere |

**Mechanism 1 — per-module shortcut** (QRA and AirWaves only): a `radio_menu: true`
key on a QRA definition / AirWave zone auto-generates its start/stop(/reset) commands.
Optional `radio_menu_restrict_to_group: "<DCS group name>"`.

**Mechanism 2 — Mission-Master menu** under `modules.RADIO.user_menus`: a free
`tree` of `menu`/`items`, optionally `restrict_to_group: "<DCS group name>"`, each
item an action from the vocabulary above. Mechanism 1 is sugar emitting the same
dispatch as mechanism 2.

Both compile to a `veafRadio.createUserMenu(...)` call in the generated config.

- **`lua` action references, never inlines.** An item may bind a command to a Lua
  function **by name** (`action: lua`, `function: "myMission.doStuff"`, optional
  `args:`). The function is authored by the maker in `mission-script.lua`; the menu
  is still declared in YAML. If a referenced function is **not found** in the
  mission's Lua at build time, the **build fails** (scanned via
  `lua_module_scanner.py`). This keeps "no Lua required" true for the vocabulary
  path while letting advanced makers wire custom behaviour without leaving YAML to
  build the menu.
- **Group restriction by name.** v5 passed a numeric `MISSION_MASTER_GROUPID`; YAML
  uses the **DCS group name** (resolved to a group id at runtime). Absent →
  the menu is global. This is the "reserved for the Mission Master" control.

Terms (`Mission Master`, `user radio menu`) are defined in
[CONTEXT.md](../../CONTEXT.md).

## Consequences

- A mission-maker adds QRA/AirWave/flag menus with zero Lua; the shortcut covers
  the common case, the `RADIO.user_menus` tree covers arbitrary composition.
- The vocabulary is a closed set: a new action is a deliberate addition (dispatch
  entry + generator + validation + doc), not something a maker can invent. The
  `lua` escape hatch absorbs everything else — at the cost of a Lua function the
  maker owns, verified at build.
- QRA/AirWaves gain a YAML menu surface; modules with a standard menu are untouched.
- The runtime must resolve a group **name** → id when a menu is restricted; a name
  matching no live group yields a global (or skipped) menu — logged, not fatal.

## Alternatives rejected

- **`lua` action inlining code in YAML** — mixes languages in one file and defeats
  the "declare the menu in YAML" framing; referencing a named function keeps the
  Lua in `mission-script.lua` where it belongs.
- **Exposing modules that already have a standard menu** (CombatZone, Carrier,
  CombatMission, Assets) — duplicates existing radio commands.
- **Numeric group id in YAML** (v5's `MISSION_MASTER_GROUPID`) — not knowable by a
  maker at design time; the group name is the natural handle.
- **Open callback vocabulary** (any `veaf*` function by name) — no build-time
  safety and a huge surface; the closed vocabulary + `lua` escape hatch is safer.
