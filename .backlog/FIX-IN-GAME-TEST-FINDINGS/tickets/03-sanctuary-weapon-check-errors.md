# 03 — The sanctuary's weapon check raises on a weapon with no target, or already gone

Status: ✅ done — 2026-09-29
Type: fix
Files: `src/scripts/veaf/veafSanctuary.lua` (`VeafSanctuaryZone:handleWeapon`), Lua tests

## Origin

GermanyCW-v6 on the private1 server, 2026-09-28 evening, `protect_from_missiles: true` on its four
sanctuaries; `dcs.log` watched while several players flew it.

## Measured

- Every `S_EVENT_SHOT`, from anyone, schedules `handleWeapon` in **every** sanctuary zone,
  `DESTROY_WEAPONS_AFTER` (2 s) later (`veafSanctuary.lua:813`).
- 19:52:14, 2 s after David's A-10 released a CBU-105:
  `VEAF-SCHEDULER|E|6393: error in scheduled function: … veaf-scripts.lua"]:58320: attempt to index
  local 'target' (a nil value)`. Again at 19:53:03 and 19:53:06, each 2 s after an AGM-88C fired by
  one of two other players' F-16Cs. Source line 602: `Unit.getByName(target:getName())`, right after
  `local target = weapon:getTarget()` (601). `getTarget()` returned `nil` for those weapons — presumably released
  with no target object designated (a CBU-105 on coordinates, a HARM with no lock: not checked); the check assumes a target whenever
  the shooter is a human of the other coalition, which any blue pilot is for the three red
  sanctuaries.
- 20:18:53: `…:58303: Weapon doesn't exist`, 2 s after a 57 mm round from an AI S-60. Source line
  585: `weapon:getLauncher()` is called before anything checks the weapon still exists, and before
  the "is the shooter a human" test — so AI fire raises it too, whenever the weapon is gone after
  two seconds.
- The code dates from 2021 (`cace38a7`); any mission with `protect_from_missiles` has been logging
  these. Nothing is lost in play — a weapon with no target threatens no defender, and one already
  gone cannot be destroyed — but each shot can raise one error per sanctuary, which buries real
  errors in the log: the GermanyCW watch had to exclude both lines to stay readable.

## Done when

- `handleWeapon` returns quietly when the weapon no longer exists (`weapon:isExist()`) and when
  `getTarget()` is `nil`.
- Lua tests for both cases, and for the guided case still reaching the in-zone check.

## Done — 2026-09-29

`handleWeapon` returns when `weapon:isExist()` is false (before `getLauncher`), when `getTarget()`
is `nil`, and when the target no longer exists — the last one not measured, the same failure one
step further. Four Lua tests; the two measured errors reproduced word for word before the fix.
