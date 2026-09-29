# 01 — secured "for all" radio commands refuse every click

Status: ✅ done

## Measured (2026-09-29)

- `dcs.log` of private1: `VEAF-RADIO|W|26606: refusing a secured command posted without a group` at
  11:19:40, 11:20:56 and 11:21:13 UTC, `veaf.SecurityDisabled=[false]`, no startup warning.
- The activation that went through 30 s later (`combatZone_WahnerHeide_Easy`) is a **training** zone
  (`:setTraining(true)` in the mission's `veaf-config.lua`): its *activate* entry is not secured
  (`veafCombatZone.lua`, `isTraining()` branch). The 16 non-training zones of the mission post a
  secured activate; Letzlingen and Werneuchen had just been opened by the refused pilot.
- No menu is built per group for a ForAll command: `_placeCommandOnMenu` sends every ForAll command
  to `_addDcsCommand(nil, ...)`, which wraps a secured one into `_proxyMethod` with `groupId = nil`.
  `_proxyMethod` refuses that since #676 (6.14.0, 2026-08-09).

## Fix

- A secured ForAll command is posted once per human group (same coalition filter and spawned-unit
  rule as ForGroup), with its parameters unchanged — ForGroup appends the unit name, ForAll methods do
  not expect it.
- Only while security is enabled: with security disabled `_proxyMethod` runs anything, and posting for
  all keeps the entry visible to a game master or a spectator, who have no group.
- `_addDcsCommand` warns when a secured command still reaches it without a group while security is on.

## Done when

Lua tests in `test/lua/test_veafRadio.lua` cover the cases in the PRD's definition of done.
