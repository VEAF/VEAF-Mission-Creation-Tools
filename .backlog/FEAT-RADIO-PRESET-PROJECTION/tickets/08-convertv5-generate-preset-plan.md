# FEAT-RADIO-PRESET-PROJECTION-08 — convert-v5 generates a preset plan (phase 2)

Status: ⬜ ready
Type: feat · Phase: 2 · AFK

## Parent

Lot [FEAT-RADIO-PRESET-PROJECTION](../PRD.md) · [ADR 0010](../../../docs/adr/0010-per-type-radio-preset-projection.md)

## What to build

Make `convert-v5` generate a preset plan by default: read the v5 `radioPresets*`
tables (`RADIO1_*`→`primary_1`, `RADIO2_*`→`primary_2`, `RADIO3_*`→`fm_supplement`,
`RADIO1_H_*`→helicopter `primary_1`, warbird tables as appropriate) and emit
`channel_lists`. When the mission cannot be factored into a single set of lists
(aircraft whose lists diverge, no shared table, unsupported construct), **fall
back** to the faithful per-aircraft copy (ADR 0003 behaviour) and warn which
aircraft fell back and why. This inverts ADR 0003's default.

## Acceptance criteria

- [ ] Shared-table v5 file → a `channel_lists` preset plan by default.
- [ ] Divergent / unfactorable mission → faithful per-aircraft copy fallback, with
      a clear warning naming the affected aircraft.
- [ ] No silent data loss (fidelity preserved on fallback).
- [ ] Tests extend `test_v5_pipeline_converters` / `test_presets_fidelity`.

## Blocked by

- FEAT-RADIO-PRESET-PROJECTION-06
- FEAT-RADIO-PRESET-PROJECTION-07
