# Lot FEAT-RADIO-YAML-MENUS — declare F10 radio menus in YAML (with Tripack)

Status: ✅ done
Branch: feat/radio-yaml-menus → PR → develop
ADR: [0011](../../docs/adr/0011-radio-yaml-menus.md)

## Problem Statement

Adding an F10 radio menu that is **not** part of the standard VEAF tree — start/stop
a QRA, drive an AirWave, flip a mission flag, run a maker's own function — is only
possible in Lua today (`veafRadio.createUserMenu()` in `mission-script.lua`). A
mission-maker who does not write Lua cannot do it, and the shipped example reads as
Lua with no hint whether it belongs in `mission.yaml` or an external script
(Tripack: *"pas clair si je dois l'intégrer au mission.yaml ou faire un script
externe en lua"*).

The runtime is already there and addressable by name (`veafQraManager.get(n)`,
`veafAirWaves.get(n)`, the `veafSpawn.missionMaster*` flag helpers). Only the YAML
surface is missing. QRA and AirWaves are the **only** triggerable subsystems with no
standard radio menu; CombatZone / Carrier / CombatMission / Assets already ship one.

## Solution

Two mechanisms sharing one **action dispatch** (full rationale in ADR 0011).

**Action vocabulary** (declarative, no inline Lua): `qra.start|stop`,
`airwave.start|stop|reset`, `flag.on|off|set|increment|decrement`, `message`, and
`lua` (references a named maker function, verified at build).

**Mechanism 1 — per-module shortcut** (QRA + AirWaves):

```yaml
modules:
  QRA:
    definitions:
      - name: "QRA-Nord"
        radio_menu: true                          # auto "QRA-Nord ▸ Démarrer / Arrêter"
        radio_menu_restrict_to_group: "MM Ctrl"   # optional — DCS group name
```

**Mechanism 2 — Mission-Master menu** (`modules.RADIO.user_menus`):

```yaml
modules:
  RADIO:
    user_menus:
      restrict_to_group: "MM Ctrl"     # optional — DCS group name; absent = global
      tree:
        - menu: "Drapeaux"
          items:
            - { command: "Activer ALPHA",     action: flag.on,   flag: "alpha" }
            - { command: "Score +1",          action: flag.increment, flag: "score" }
        - menu: "Divers"
          items:
            - { command: "Démarrer QRA Nord", action: qra.start, qra: "QRA-Nord" }
            - { command: "Annonce",           action: message,   text: "Go!" }
            - { command: "Mon script",        action: lua, function: "maMission.doStuff", args: [1, "x"] }
```

Both compile to `veafRadio.createUserMenu(...)`; the optional group name is resolved
to a group id at runtime (`addCommandForGroup`) — absent = global menu.

## Decisions (validated by David)

- Two mechanisms, one shared vocabulary (ADR 0011). QRA + AirWaves are the only
  modules getting a shortcut; modules with a standard menu are untouched.
- Vocabulary v1 = `qra.*`, `airwave.*`, `flag.*`, `message`, `lua`.
- `lua` **references** a function the maker defines in `mission-script.lua` (never
  inlines code); a reference with no matching Lua definition **fails the build**.
- Group restriction by **DCS group name** (not v5's numeric id), resolved at runtime.
- ADR required (new declarative surface with an action vocabulary) → ADR 0011.

## Scope

- **Ticket 01** — action dispatch + `modules.RADIO.user_menus` generator (`flag.*`,
  `message`) → `createUserMenu` chain. Python + tests.
- **Ticket 02** — `qra.*` / `airwave.*` actions + per-module `radio_menu` shortcut
  under QRA definitions and AirWave zones. Python + tests.
- **Ticket 03** — `lua` action (named-function reference) + build-time verification
  that the function exists in the mission Lua (via `lua_module_scanner.py`); build
  failure otherwise. Python + tests.
- **Ticket 04** — group restriction: resolve `restrict_to_group` /
  `radio_menu_restrict_to_group` (DCS group name → group id) at runtime; Lua helper
  in `veafRadio.lua` + Lua tests.
- **Ticket 05** — schema validation in `mission_validator.py` (keys, closed action
  vocabulary, required target per action, clear errors). Python + tests.
- **Ticket 06** — docs + defaults lockstep: `veafRadio.md`/`.en` (new "Menus radio
  en YAML" section + state clearly that `createUserMenu` is Lua / `mission-script.lua`),
  `veafQraManager.md`/`.en` and AirWaves doc (`radio_menu`), `mission.yaml` shipped
  default (commented `RADIO.user_menus` + QRA `radio_menu`), MISSION_YAML_REFERENCE /
  module refs, CONTEXT.md glossary (`Mission Master`, `user radio menu`).

## Cross-cutting Definition of Done

- **Quality ratchet** (CLAUDE.md §3): any worker touched substantially and still in
  the mypy `ignore_errors` list (e.g. `lua_config_generator.py`, `mission_validator.py`)
  must be dropped from that list and its type errors fixed. Bump `--cov-fail-under`
  to stay within ~2 pts of measured coverage.
- **Defaults lockstep** (CLAUDE.md §9.7): `src/defaults/mission-folder/mission.yaml`
  updated in this lot.
- Quality gate green: `ruff check --fix`, `ruff format --check`, `mypy`, `pytest`,
  `test-lua`, `stylua --check`, `luacheck` (CI).

## Out of scope

- Inline Lua code in YAML (only named-function references) — rejected in ADR 0011.
- Exposing modules that already ship a standard radio menu (CombatZone, Carrier,
  CombatMission, Assets).
- Category-B extensions (`combatmission.activate`, `alias.execute`, `asset.*`,
  `group.move`, `mission.run`) — future lots; the dispatch is left extensible.
- convert-v5 emitting these menus automatically (the maker opts in by hand).

---

## 01 — Action dispatch + `modules.RADIO.user_menus` generator

Status: ✅ done

### Context

`modules.RADIO` exposes only `help_menus` today (`lua_config_generator.py`,
`_MODULE_INIT_PARAMS`). Add a `user_menus` block that compiles a declarative
menu tree into a `veafRadio.createUserMenu(...)` call using the existing
`veafRadio.mainmenu()/menu()/command()` helpers. This ticket lands the dispatch
skeleton + the two Lua-free vocabulary actions that need no other module:
`flag.*` and `message`.

### Tasks

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

### Definition of Done

- Given a `RADIO.user_menus` YAML block, the generated config Lua builds the menu
  with `flag.*` / `message` commands; unit tests cover nesting + each flag verb.
- Quality ratchet: if `lua_config_generator.py` is substantially edited and still in
  the mypy `ignore_errors` list, drop it and fix the surfaced errors.
- `ruff`, `ruff format --check`, `mypy`, `pytest` green; coverage gate bumped.

---

## 02 — `qra.*` / `airwave.*` actions + per-module `radio_menu` shortcut

Status: ✅ done

### Context

Extends the dispatch (ticket 01) with the two "addressable by name" subsystems that
have no standard radio menu:

- QRA — `veafQraManager.get("<name>"):start()` / `:stop()` (registry auto-populated
  in `setName`, `veafQraCore.lua`).
- AirWaves — `veafAirWaves.get("<name>"):start()` / `:stop()` / `:reset()`
  (`veafAirWaves.zones`, `veafAirWaves.get`).

Plus **mechanism 1**: a `radio_menu` shortcut on a QRA definition / AirWave zone that
auto-generates the start/stop(/reset) commands, so the maker does not hand-write the
`RADIO.user_menus` tree for the common case.

### Tasks

- [ ] Dispatch: `qra.start` / `qra.stop` (target key `qra:`),
      `airwave.start` / `airwave.stop` / `airwave.reset` (target key `airwave:`).
      These are usable in a `RADIO.user_menus` tree (ticket 01) targeting any QRA /
      AirWave by name — including ones declared in Lua.
- [ ] `modules.QRA.definitions[].radio_menu: true` → auto-emit a submenu with
      "Démarrer / Arrêter <name>" for that QRA. Optional
      `radio_menu_restrict_to_group` (group name → ticket 04).
- [ ] Same shortcut on AirWave zones (locate the AirWaves YAML definition surface;
      see `_emit_airwave_zone` in `lua_config_generator.py`): start / stop / reset.
- [ ] i18n the generated command labels (FR/EN) via the existing `t()` mechanism.

### Definition of Done

- A QRA/AirWave definition with `radio_menu: true` yields its control submenu;
  `qra.*` / `airwave.*` also work inside a `RADIO.user_menus` tree by name.
- Unit tests cover shortcut emission (QRA + AirWave) and dispatch-by-name.
- Quality ratchet + coverage gate obligations (see PRD).

---

## 03 — `lua` action (named-function reference) + build-time verification

Status: ✅ done

### Context

The escape hatch (ADR 0011): a menu item may bind a command to a Lua function the
maker defines in `mission-script.lua`, **by name** — never inline code:

```yaml
- { command: "Mon script", action: lua, function: "maMission.doStuff", args: [1, "x"] }
```

The menu stays declared in YAML; the function lives in the maker's Lua. A reference
with no matching definition must **fail the build** (not silently drop the command).

### Tasks

- [ ] Dispatch: `action: lua` emits `veafRadio.command(label, <function>, <args>)`
      with the referenced function symbol and literal `args`.
- [ ] Build-time check: scan the mission Lua (`mission-script.lua` and any injected
      scripts) for the referenced function definition, reusing / extending
      `lua_module_scanner.py`. Missing symbol → build error naming the function and
      the menu item.
- [ ] Support dotted symbols (`table.func`) and plain globals; document the matching
      rule (definition present, not merely a call site).

### Definition of Done

- A valid `lua` reference emits the command; a dangling reference fails the build
  with a clear message.
- Unit tests: resolves an existing function, fails on a missing one, handles dotted
  names and `args`.
- Quality ratchet + coverage gate obligations (see PRD).

---

## 04 — Group restriction (DCS group name → group id at runtime)

Status: ✅ done

### Context

v5 restricted a user menu to the Mission Master by passing a numeric
`MISSION_MASTER_GROUPID` to `veafRadio.createUserMenu(config, groupId)` (→
`addSubMenuForGroup` / `addCommandForGroup`). YAML uses the **DCS group name**
instead (ADR 0011); the id is only known at runtime.

`veafRadio.createUserMenu(configuration, groupId)` already accepts a numeric
`groupId`. This ticket adds name-based resolution so the generated config can pass a
group **name** from YAML (`restrict_to_group` / `radio_menu_restrict_to_group`).

### Tasks

- [ ] Lua: resolve a group name → group id at menu-creation time (e.g. accept a name
      in `createUserMenu`, or a thin wrapper resolving via `Group.getByName(...):getID()`).
      Absent / unknown name → global menu, logged (not fatal).
- [ ] Generator (tickets 01–02): pass the group name from YAML into the generated
      call using this path.
- [ ] Lua unit tests (`test/lua/test_veafRadio.lua`): name resolves → ForGroup calls;
      unknown name → global; no name → global.

### Definition of Done

- A menu with `restrict_to_group: "<name>"` is created only for that group at
  runtime; unknown/absent name falls back to a global menu with a warning.
- `stylua --check` and `luacheck` (CI) green; Lua tests pass.

---

## 05 — Schema validation for the new YAML keys

Status: ✅ done

### Context

The new surfaces (`modules.RADIO.user_menus`, QRA/AirWave `radio_menu`) need
validation in `mission_validator.py` so mistakes are caught with a clear message at
build/validate time rather than producing broken Lua.

### Tasks

- [ ] Validate `RADIO.user_menus`: `restrict_to_group` (string), `tree` (list),
      each node either a `menu` (name + `items`) or a leaf `command` with an
      `action`.
- [ ] Validate the **closed action vocabulary** and each action's required target:
      `qra.*`→`qra`, `airwave.*`→`airwave`, `flag.set`→`flag`+`value`,
      `flag.on/off/increment/decrement`→`flag`, `message`→`text`,
      `lua`→`function`. Unknown action or missing target → error naming the item.
- [ ] Validate the per-module shortcut keys (`radio_menu` boolean,
      `radio_menu_restrict_to_group` string) on QRA definitions and AirWave zones.
- [ ] Messages routed through `t()` (FR/EN), consistent with existing validator
      errors.

### Definition of Done

- Invalid vocabulary / missing target / malformed tree each raise a clear,
  localized validation error; valid blocks pass.
- Unit tests cover each error path and a valid tree.
- Quality ratchet: if `mission_validator.py` is substantially edited and still in the
  mypy `ignore_errors` list, drop it and fix the errors. Coverage gate bumped.

---

## 06 — Docs + defaults lockstep + glossary

Status: ✅ done

### Context

The feature is only useful if the mission-maker can discover it. Tripack's confusion
was precisely doc-shaped: the `createUserMenu` example reads as Lua with no framing.

### Tasks

- [ ] `doc/mission-maker/scripts/veafRadio.md` (+ `.en.md`): new section **"Menus
      radio en YAML"** documenting mechanism 2 (`modules.RADIO.user_menus`), the
      full action vocabulary (with per-action target keys and one example each), and
      `restrict_to_group`. Clarify that the existing `createUserMenu()` example is
      **Lua** and belongs in `mission-script.lua` (the `lua` action being the bridge).
- [ ] `veafQraManager.md` (+ `.en.md`) and the AirWaves doc: document the
      `radio_menu` / `radio_menu_restrict_to_group` shortcut (mechanism 1).
- [ ] `src/defaults/mission-folder/mission.yaml` (**lockstep**): commented
      `RADIO.user_menus` example + a commented QRA `radio_menu`.
- [ ] MISSION_YAML_REFERENCE / relevant module reference pages updated for the new
      keys.
- [ ] `CONTEXT.md` glossary: `Mission Master`, `user radio menu` (referenced by ADR
      0011).
- [ ] `CHANGELOG.md` under `[Unreleased]`: one entry for the feature.

### Definition of Done

- FR + EN docs describe both mechanisms and the vocabulary; shipped default carries
  the commented examples; markdown-lint clean.
- Glossary terms present; ADR 0011 cross-reference resolves.
