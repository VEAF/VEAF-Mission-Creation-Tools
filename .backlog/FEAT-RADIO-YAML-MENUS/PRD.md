# Lot FEAT-RADIO-YAML-MENUS — declare F10 radio menus in YAML (with Tripack)

Status: ⬜ ready
Branch: feat/radio-yaml-menus → PR → develop-v6
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
