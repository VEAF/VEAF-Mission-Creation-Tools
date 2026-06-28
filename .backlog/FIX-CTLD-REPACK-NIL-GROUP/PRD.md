# FIX-CTLD-REPACK-NIL-GROUP

Status: ✅ done

Reported by Tripack. A standalone technical analysis was produced as a deliverable for
the in-progress CTLD rewrite (handed off directly, not committed to the repo).

## Problem

Taking a **dynamic slot on a runtime-spawned FARP** duplicates the CTLD F10 radio menu
(every entry appears twice; clicks do nothing). A dynamic slot on a base airfield is fine.

## Root cause (confirmed by runtime log)

`ctld.getUnitsInRepackRadius` calls `unitObject:getGroup():getID()` on a `nil` unit:
`getNearbyUnits` returns a name whose `Unit.getByName` is `nil` (a transient
`mist.DBs.unitsByName` entry from the runtime FARP / dynamic slot), but `isRepackableUnit`
still returns truthy → crash. The crash happens **inside** `addTransportF10MenuOptions`
(via `updateRepackMenu`), **after** the menu is added but **before**
`ctld.addedTo[groupId] = true`. The dedup flag is never set, so the second birth event
(DCS fires `S_EVENT_PLAYER_ENTER_UNIT` + `S_EVENT_BIRTH`, both deferred for dynamic slots)
rebuilds the whole menu → duplicate.

Confirmed via a diagnostic wrapper in the test mission: two `ENTER` with `addedTo=nil` and
two `attempt to call method 'getGroup' (a nil value)` errors for the FARP dynamic slot.

## Fix

Nil-guards in the vendored `src/scripts/community/CTLD.lua`:
- `getUnitsInRepackRadius`: skip a name with no live unit / no group before `:getGroup()`.
- `isRepackableUnit`: return `nil` when `Unit.getByName` is `nil`.

With the crash gone, `addTransportF10MenuOptions` completes, sets `addedTo`, and the menu
is built once.

## Validation

- A corrected `.miz` is produced for Tripack (fix in place of the diagnostic) to confirm
  the duplicate is gone in-game.
- The community CTLD copy is **not** covered by the Lua test/lint gate (gate scope =
  `src/scripts/veaf/`), so validation is the in-game `.miz` check.

## Out of scope / handoff

- The deeper architectural fragility (dedup flag set only at the end of a long function;
  two-event dynamic-slot births; MIST vs live group id) is documented for the CTLD
  rewrite in the analysis doc, not refactored in the vendored copy.
