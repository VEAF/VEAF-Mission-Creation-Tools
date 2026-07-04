# FIX-DYNSLOT-TEMPLATE-CATEGORY-002 — investigate the QRA airplane-intruder symptom

Status: ✅ done — root cause found & fixed in lot FIX-EVENTHANDLER-UNITCATEGORY (PR #544)
Type: fix
Files: `veafQraCore.lua`, `test/lua/`, DCS manual test (Tripack)

## Resolution (2026-06-29)

Tripack reproduced the symptom in-game after #299 (dynamic Hornet, Sukhumi → airborne in
the Gudauta QRA zone: no activation with `react_on_helicopters` false, activates when set
true). Root cause was **not** in the QRA: `veafEventHandler.completeUnitFromName` populated
`event.initiator.unitCategory` with `unit:getCategory()` (an `Object.Category` whose UNIT=1
collides with `Unit.Category.HELICOPTER`), so `humanBornEvent` never reached #299's
`getCategoryEx` branch (it only runs when `unitCategory == nil`). Fixed in
**FIX-EVENTHANDLER-UNITCATEGORY** (PR #544): `completeUnitFromName` now reads
`getCategoryEx()`. Regression test added in `test_veafEventHandler.lua`. Final closure of
the lot still benefits from Tripack's in-game re-test on a `6.7.5+<sha>` build.

## What to build

Investigate the QRA symptom — link to 001 unconfirmed. Repro: dynamic-slot airplane +
a QRA with `react_on_helicopters: false`/absent → the QRA must activate. Test
before/after 001 to settle whether the category fix resolves it. If it persists, fix
QRA intruder detection so an airplane is recognised by real DCS unit type
(`unit:getCategory()`) regardless of the mist/section category (`unit.category` line
666, `group:getCategory()` line 774). Add a QRA test for the airplane-intruder case.

## Acceptance criteria

- [x] Repro tested before/after 001 to settle whether the category fix resolves it
- [x] If it persists, QRA recognises an airplane intruder by real DCS unit type
- [x] QRA test added for the airplane-intruder case

## Blocked by

None — Tripack confirmed in-game on a `6.7.8+<sha>` build.
