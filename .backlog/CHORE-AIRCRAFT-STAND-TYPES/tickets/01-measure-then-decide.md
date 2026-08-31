# 01 — Measure, then decide

Status: ⬜ ready

Type: chore · File: `src/python/veaf-tools/veaf_libs/dcs_parking.py`

## Do the measurement first

Do not start by editing the constant. The deliverable is a decision backed by numbers; the code
change may well be "none".

Three measurements, in order of what they settle:

1. **Stand census** over the three bundled theatres (`veaf_libs/data/parking/*.json`): how many
   stands of each `Term_Type`, and how many airfields have **no** `68`/`104` stand at all. That
   last number is the one that matters — an airfield with only `72`/`100` stands is one the tool
   currently refuses to place anything on.
2. **Real usage**: in the VEAF Foothold missions (`D:\dev\_VEAF\VEAF-Foothold-*`) and the Open
   Training Syria mission (`D:\dev\_VEAF\tmp\VEAF-Open-Training-Mission-Syria`), **read-only**,
   resolve every parked aircraft's `parking` value against the bundled stand table and report the
   terminal type it sits on. If mission makers and DCS never use 72/100 for planes, the narrow set
   is describing reality.
3. **Airframe sensitivity**, only if 1 or 2 suggest widening: does `SmallSizeFighter` (100) hold a
   heavy? A stand type named for small fighters is a hint that the answer may depend on the unit.

A previous attempt at measurement 2 reported "0 parked groups" on three missions — that was a
broken probe, not a finding. Establish how a parked aircraft is actually represented (the group's
airfield reference and each unit's `parking` field) before trusting any count, and sanity-check
your probe against a mission you can eyeball in the Mission Editor.

## Then decide

Widen, keep, or make it airframe-dependent — any of the three is a valid outcome. What is not
valid is leaving two neighbouring constants that appear to contradict each other with no
explanation.

## Definition of done

- [ ] The numbers are in the module, beside the constants, with how they were obtained
- [ ] The decision is applied, whatever it is
- [ ] If placement behaviour changes, the tests pinning it change too, and the PR names the
      airfields that start behaving differently
- [ ] If nothing changes, `AIRCRAFT_STAND_TYPES`' comment says why it is narrower than
      `PLANE_STAND_TYPES` — the two must stop looking like an oversight
