# 06 — Docs + defaults lockstep + glossary

Status: ✅ done

## Context

The feature is only useful if the mission-maker can discover it. Tripack's confusion
was precisely doc-shaped: the `createUserMenu` example reads as Lua with no framing.

## Tasks

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

## Definition of Done

- FR + EN docs describe both mechanisms and the vocabulary; shipped default carries
  the commented examples; markdown-lint clean.
- Glossary terms present; ADR 0011 cross-reference resolves.
