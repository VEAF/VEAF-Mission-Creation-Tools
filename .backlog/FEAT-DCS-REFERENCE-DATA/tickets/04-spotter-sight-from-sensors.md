# FEAT-DCS-REFERENCE-DATA-04 — spotter sight from the unit's sensors

Status: ⬜ ready
Type: fix
Files: `src/scripts/veaf/veafSkynetIadsHelper.lua`, a generated Lua table, `known-limitations.yaml`, `test/lua/`

## What

Give each spotter the sight range its real sensors allow, from the reference's `sensors` table (optics and their `detectionRangeKm`), rather than the range of the first `SpotterUnitTable` row its attributes match.

## Why

`SAM elements` (range 0) comes before `AAA` and `Air Defence vehicles` in the table, so a Shilka, a Roland, a Kub or an Osa is blind as a spotter (`air-defence-spotters-are-blind`, measured 2026-09-21).
DCS gives the Shilka and the Osa optics; the blindness is ours.

## Open point

The sensor ranges are what DCS's AI uses to detect, not what a forward observer should report: decide when the ticket is taken whether the table keeps a cap per class, and what a unit with no sensor gets (Strela-10M3, ZU-23 Ural have none).

## Done when

- The spotter range of a unit with optics comes from its sensors; a unit with none falls back to the table.
- `air-defence-spotters-are-blind` gets `fixed_in`, `dcs-runtime-traps.md` regenerated.
- Lua test: a Shilka spotter has a non-zero range.
