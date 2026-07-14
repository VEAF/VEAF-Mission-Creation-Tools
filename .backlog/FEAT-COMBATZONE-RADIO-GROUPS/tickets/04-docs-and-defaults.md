# 04 — Docs + defaults lockstep

Status: ⬜ ready

## Context

The new combat-zone keys and the automatic pagination change user-facing behaviour
and config; documentation + the shipped default must move in lockstep (CLAUDE.md
§9.7). CONTEXT.md glossary entries (`Combat zone radio group`, `Combat zone menu
prefix`) already landed during the grill.

## Tasks

- [ ] Combat-zone module doc: document `radio_group_name` (grouping submenu) and
      `radio_menu_prefix` (label prefix) as optional per-zone keys (FR + `.en`).
- [ ] `veafRadio` doc: document automatic render-time pagination (menus over 10
      items get `Next page` automatically) and `veafRadio.doNotPaginate(menu)` as
      the opt-out; note the `ForUnit` guard.
- [ ] `src/defaults/mission-folder/mission.yaml`: add a commented combat zone under
      `modules.COMBATZONE.combat_zones` showing both keys.
- [ ] MISSION_YAML_REFERENCE (and any module-key index): add the two keys.

## Definition of Done

- Docs describe both keys and the pagination behaviour/opt-out; FR and `.en` stay
  in sync.
- Shipped default `mission.yaml` illustrates `radio_group_name` / `radio_menu_prefix`
  and matches what `lua_config_generator` produces.
- `CHANGELOG.md` `[Unreleased]` has one entry for the lot; markdown-lint clean.
