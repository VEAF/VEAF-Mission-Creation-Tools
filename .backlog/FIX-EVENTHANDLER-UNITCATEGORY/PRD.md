# Lot FIX-EVENTHANDLER-UNITCATEGORY — dynamic-slot airplane still treated as a helicopter by the QRA

Status: 🔄 in-progress
Branch: fix/eventhandler-unitcategory → PR → develop-v6

## Problem Statement

A dynamic-slot **airplane** still only triggers a QRA when `react_on_helicopters` is
`true` — the exact #299 symptom, reproduced in-game by Tripack **after** #299 shipped
(dynamic Hornet from Sukhumi, airborne inside the Gudauta QRA zone: no activation with
`react_on_helicopters` false; activates as soon as it is set true, same slot).

## Root cause

#299 fixed `veafQraCore:humanBornEvent` to read the intruder category via
`unit:getCategoryEx()` (a `Unit.Category`: AIRPLANE=0 / HELICOPTER=1) — but **only on the
`unit.unitCategory == nil` branch**. In the real flow that branch is never reached:
`veafEventHandler.completeUnitFromName` (`veafEventHandler.lua:74`) pre-populates
`event.initiator.unitCategory` with **`unit:getCategory()`**, an `Object.Category` whose
`UNIT` value (1) **collides** with `Unit.Category.HELICOPTER` (1). So every event-born
unit arrives at the QRA already mislabelled as a helicopter, and #299's `getCategoryEx`
fix is dead code for that path.

Normal slots are unaffected because they are detected via the mist path
(`_getEnemyHumanUnits`, `unit.category == "plane"`), not via `humanBornEvent`. Only
**dynamic** slots (absent from the mission table / mist) depend on the event path.

`event.initiator.unitCategory` has a **single** consumer in the codebase
(`veafQraCore.lua:628`), which compares it against `Unit.Category.AIRPLANE/HELICOPTER` —
so it was always meant to hold a `Unit.Category`. `getCategory()` returns `Object.Category.UNIT`
(always 1) for any unit, which is meaningless as a unit category: this is a plain bug.

## Solution

`completeUnitFromName` populates `unitCategory` with `unit:getCategoryEx()` (Unit.Category),
falling back to `unit:getCategory()` only when `getCategoryEx` is unavailable.

## Testing Decisions

- Lua test on `completeUnitFromName`: an airplane unit (`getCategoryEx` → AIRPLANE,
  `getCategory` → Object.Category.UNIT) yields `unitCategory == Unit.Category.AIRPLANE`
  (fails before the fix, passes after).

## Out of Scope

- The #299 `humanBornEvent` getCategoryEx branch stays as defensive code (still covered).
- `veafCombatZone`'s own `Unit.getCategory(unit)` use is a separate concern.
