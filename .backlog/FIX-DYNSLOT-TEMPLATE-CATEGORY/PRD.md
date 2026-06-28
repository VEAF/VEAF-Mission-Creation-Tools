# Lot FIX-DYNSLOT-TEMPLATE-CATEGORY — airplane dynamic-slot templates miscategorized as helicopters

Status: 🔄 in-progress
Branch: fix/dynslot-template-category → PR → develop-v6

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

**Investigation note (BLOCKED — needs Tripack's SOURCE mission)**: the extraction is
**faithful** to the source mission's structure — `_collect`
(`aircrafts_injector_worker.py:1120`) reads `country.plane.group` → `airplanes` and
`country.helicopter.group` → `helicopters`. Evidence is contradictory: `tmp/test` has
`airplanes: {}` empty with the A-10C under `helicopters`, but Tripack's built `.miz`
appears to file the A-10C `dynSpawnTemplate` under `plane` (correct). Root cause cannot
be confirmed from the built `.miz` alone — need Tripack's **source** mission (pre-build)
or a clean repro. **Do not implement 002 until the source mission is available.**
