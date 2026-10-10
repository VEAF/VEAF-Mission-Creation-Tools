# 02 — Missions declared after `initialize()` land at the root of the VEAF menu

Status: 🧑 waiting-human
Type: fix (6.29.0 regression, caused by ticket 01)
Files: `src/scripts/veaf/veafCombatMission.lua`, `test/lua/test_veafCombatMission_menu.lua`, `CHANGELOG.md`

## What happens

Measured in game with David on 2026-10-10: the Caucasus Open Training v6, rebuilt with 6.29.0, multiplayer, dynamic A-10C slot.
The root of F10 > VEAF opens on 9 « +ACTIVER LA MISSION » entries followed by next pages.
Read through DCS Fiddle (`veafRadio._builder._rendered`, `veafRadio.radioMenu.commands`): 25 `veafCombatMission.ActivateMission` commands sit in the `commands` of the VEAF root.
They belong to the scripted missions the mission's `src/scripts/mission-script.lua` declares: « Interception-VIP » (one per skill and scale, through `AddMissionsWithSkillAndScale`), « Attaque-Gudauta » and « Vague-Tu-160 », each twice.

## Why

- Ticket 01 (#1085) moved `veafCombatMission.initialize()` after the `addCapMission` calls of the generated `veaf-config.lua`, so `buildRadioMenu()` sets `veafCombatMission.rootPath` as soon as there is a CAP.
- `mission-script.lua` loads after `veaf-config.lua`. A mission it declares goes through `AddMission` → `mission:initialize()` → `VeafCombatMission:updateRadioMenu()`, which only checked `veafCombatMission.rootPath`, not the mission's own `radioRootPath` — still nil. `veafRadio.addCommandToSubmenu(..., nil, ...)` → `RadioMenuBuilder:addCommand` puts the command in `self._root`, the VEAF root.
- The duplicates: the script also calls `:initialize()` before `AddMission`, as `addCapMission` does. Two calls, two sets of commands, and nothing clears the root (`clearSubmenu` only runs when `radioRootPath` exists).
- And nothing put those missions under MISSIONS before the first `buildRadioMenu()` an activation triggers.
- In 6.26 there was no residue because `rootPath` stayed nil — and no MISSIONS menu at all, the defect ticket 01 fixed.
  The Open Training prompt (`.prompts/new-open-training-mission.fr.md`, §4.12) has the scripted missions written in `mission-script.lua`: every OT built with it is affected.

## Fix

1. `VeafCombatMission:updateRadioMenu()` places nothing while the mission has no submenu (`self.radioRootPath` nil): `buildRadioMenu()` gives it one.
2. `veafCombatMission.initialize()` sets `veafCombatMission._initialized`. A mission added after it (`AddMission`, so also `AddMissionsWithSkillAndScale` and `addCapMission`) calls `_scheduleRadioMenuRebuild()`, which schedules one `buildRadioMenu()` `RadioMenuRebuildDelay` (1 s) later and ignores further calls until it has run: one rebuild for a whole burst of declarations.
   The flag is `_initialized` rather than `rootPath`, so a config with `COMBATMISSION` enabled and no mission of its own — `initialize()` builds nothing then — still gets a MISSIONS menu for the missions its script declares.
   Missions declared before `initialize()` (the generator's order) schedule nothing: `initialize()` builds the menu itself.

## Same pattern elsewhere

Checked 2026-10-10, not affected:

- `VeafCombatZone:updateRadioMenu` returns while `radioParentPath` is nil and creates `radioRootPath` itself before adding any command.
- `VeafCombatOperation:updateRadioMenu` returns while `veafCombatZone.rootPath` is nil, and creates its `radioRootPath` when it has none.
- `veafMissileGuardian` copies the combat mission's menu code, but `AddGuardian` refuses (nothing can be stored), so no guardian ever reaches `updateRadioMenu` outside `buildRadioMenu()`.

## Test

`test/lua/test_veafCombatMission_menu.lua`, against the real veafRadio tree, written and seen failing before the fix (4 of 6: 4 commands at the root for one mission — info and activate, twice):

- a mission declared after `initialize()` leaves no command at the VEAF root, before and after the deferred rebuild;
- it appears under MISSIONS after the deferred rebuild, next to the config's mission, in a single MISSIONS menu;
- a burst of three declarations rebuilds the menu once;
- missions declared after an `initialize()` that had no mission still get a MISSIONS menu;
- missions declared before `initialize()` schedule nothing;
- the Caucasus workaround (below) stays harmless.

Each test checked by mutation: dropping the `radioRootPath` guard, the debounce, the scheduling, or using `rootPath` instead of `_initialized` each turns at least one of them red.
The generator's init-order test from ticket 01 (`test_combat_mission_init_order.py`) is untouched and green.

## The Caucasus workaround

The Caucasus OT v6 carries a workaround in its `mission-script.lua` (branch `fix/missions-scenarisees-menu` of `VEAF/VEAF-Open-Training-Mission-Caucasus-v6`): `veafCombatMission.rootPath` set to nil around the declarations, restored, then `buildRadioMenu()`.
With this fix it stays harmless — the deferred rebuild runs once more on a menu already complete; `test_the_caucasus_workaround_stays_harmless` reproduces it.
**To remove after the release that ships this fix.**

## To check in game

- [ ] Caucasus OT v6 rebuilt with this fix (with or without the workaround): the VEAF root has no « Activer la mission » entry, and « Interception-VIP », « Attaque-Gudauta » and « Vague-Tu-160 » are under MISSIONS from the start.
- [ ] GermanyCW-v6 and Syria-v6: their `mission-script.lua` (`origin/main`, 2026-10-10) declares no combat mission, so they are not exposed through this path; a look at the VEAF root after their next rebuild is enough.
