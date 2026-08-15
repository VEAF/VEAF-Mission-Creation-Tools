# Lot FIX-DYNSLOT-TEMPLATE-CATEGORY — airplane dynamic-slot templates miscategorized as helicopters

Status: ✅ done
Branch: fix/dynslot-template-category → PR → develop

## Problem Statement

The auto-generated `dynamic-slot-templates.yaml` writes **every extracted air group
under `helicopters:`** — `airplanes:` is emitted as `coalitions: {}` (empty) while
airplanes like the **A-10C II** land under `helicopters:`. On injection, DCS therefore
shows the template as a **helicopter group** in the Mission Editor (group panel titled
"GROUPE D'HÉLICOPTÈRES" with the aircraft type highlighted/red), reported by Tripack.
This is **distinct from #478** (`FIX-SPAWNABLES-CATEGORY`, commit `d40ae5f2`), which
only re-categorized the **default CAP templates in `spawnables.yaml`** (data-only) and
did **not** touch the dynamic-slot extraction pipeline.

## Solution

The `extract-aircraft-groups` extraction must classify each group by its **DCS unit
category** (airplane vs helicopter) when writing `dynamic-slot-templates.yaml`, so
airplanes go under `airplanes:` and rotary under `helicopters:`. Regenerate the
test/default templates in lockstep; add a non-regression test asserting an airplane
type lands under `airplanes:`.

## User Stories

1. As a mission-maker, I want airplane dynamic-slot templates filed as airplanes, so
   that DCS injects them as airplane groups in the Mission Editor.

## Implementation Decisions

- Classify by real DCS unit **type** via the units DB, not by the source `.miz` section.
- Regenerate shipped/test templates in lockstep.

## Testing Decisions

- Non-regression test asserting an airplane type (e.g. A-10C II) lands under `airplanes:`.
- QRA airplane-intruder case investigated empirically (ticket 002, before/after 001).

## Out of Scope

- Assuming ticket 001 fixes the QRA symptom — that link is unconfirmed (see Further Notes).

## Further Notes

**Possibly-related symptom — NOW CONFIRMED & FIXED separately (lot FIX-QRA-DYNSLOT-CATEGORY,
#299)**: a QRA only triggers on an airplane dynamic-slot when `react_on_helicopters: true`;
with it `false`/absent the QRA ignores the airplane. The QRA reads the intruder category by **two different paths** in
`veafQraCore.lua`: (1) `humanBornEvent` (line 608) — the **dynamic-slot path** — uses
`unit:getCategory()`, the real DCS unit type (robust to the `.miz` section); (2)
`_getEnemyHumanUnits` (line 651) uses `unit.category` (mist string, reflects the
section), and `group:getCategory()` (line 774) likewise depends on the section. The
link is plausible but **not provable by static reading**. **Do NOT assume 001 fixes it.**

**Investigation note (RESOLVED)**: the QRA airplane-intruder symptom (ticket 002) was
traced to `veafEventHandler.completeUnitFromName` (see lot FIX-EVENTHANDLER-UNITCATEGORY,
PR #544), not to the extraction path. Tripack confirmed both fixes in-game on a
`6.7.8+<sha>` build.

---

## FIX-DYNSLOT-TEMPLATE-CATEGORY-001 — categorize templates by DCS unit category

Status: ✅ done
Type: fix
Files: aircraft-groups extraction (`aircrafts_injector/` / `extract-aircraft-groups`), default templates, `test/python/`

### What to build

Make the aircraft-groups extraction categorize each group by DCS unit category
(airplane vs helicopter) when emitting `dynamic-slot-templates.yaml`; airplanes must
land under `airplanes:`, not `helicopters:`. Regenerate the shipped/test templates.
Repro: extract a mission containing an A-10C II dynamic-slot template, confirm it
appears under `airplanes:` and injects as an airplane group in the ME.

### Acceptance criteria

- [x] Extraction classifies each group by DCS unit category
- [x] Airplanes land under `airplanes:`, rotary under `helicopters:`
- [x] Shipped/test templates regenerated
- [x] Non-regression test asserts an airplane type lands under `airplanes:`

### Blocked by

None — can start immediately

### Notes

Done in #515.

---

## FIX-DYNSLOT-TEMPLATE-CATEGORY-002 — investigate the QRA airplane-intruder symptom

Status: ✅ done — root cause found & fixed in lot FIX-EVENTHANDLER-UNITCATEGORY (PR #544)
Type: fix
Files: `veafQraCore.lua`, `test/lua/`, DCS manual test (Tripack)

### Resolution (2026-06-29)

Tripack reproduced the symptom in-game after #299 (dynamic Hornet, Sukhumi → airborne in
the Gudauta QRA zone: no activation with `react_on_helicopters` false, activates when set
true). Root cause was **not** in the QRA: `veafEventHandler.completeUnitFromName` populated
`event.initiator.unitCategory` with `unit:getCategory()` (an `Object.Category` whose UNIT=1
collides with `Unit.Category.HELICOPTER`), so `humanBornEvent` never reached #299's
`getCategoryEx` branch (it only runs when `unitCategory == nil`). Fixed in
**FIX-EVENTHANDLER-UNITCATEGORY** (PR #544): `completeUnitFromName` now reads
`getCategoryEx()`. Regression test added in `test_veafEventHandler.lua`. Final closure of
the lot still benefits from Tripack's in-game re-test on a `6.7.5+<sha>` build.

### What to build

Investigate the QRA symptom — link to 001 unconfirmed. Repro: dynamic-slot airplane +
a QRA with `react_on_helicopters: false`/absent → the QRA must activate. Test
before/after 001 to settle whether the category fix resolves it. If it persists, fix
QRA intruder detection so an airplane is recognised by real DCS unit type
(`unit:getCategory()`) regardless of the mist/section category (`unit.category` line
666, `group:getCategory()` line 774). Add a QRA test for the airplane-intruder case.

### Acceptance criteria

- [x] Repro tested before/after 001 to settle whether the category fix resolves it
- [x] If it persists, QRA recognises an airplane intruder by real DCS unit type
- [x] QRA test added for the airplane-intruder case

### Blocked by

None — Tripack confirmed in-game on a `6.7.8+<sha>` build.
