# FEAT-RADIO-PRESET-PROJECTION-06 — convert-v5 generates a preset plan (phase 2)

Status: ⬜ ready
Type: feat
Phase: 2
Files: `mission_builder/v5_pipeline_converters.py` (`convert_presets`), `test/python/mission_builder/`

## What to build

Make `convert-v5` generate a _Preset plan_ by default: read the v5
`radioPresets*` tables (`RADIO1_*`→`primary_1`, `RADIO2_*`→`primary_2`,
`RADIO3_*`→`fm_supplement`, `RADIO1_H_*`→helicopter `primary_1`, warbird tables as
appropriate) and emit `channel_lists`. When the mission cannot be factored into a
single set of lists (aircraft whose lists diverge, no shared table, unsupported
construct), **fall back** to the current faithful per-aircraft copy (ADR 0003
behaviour) and warn the mission-maker which aircraft fell back and why. This
inverts ADR 0003's default (faithful copy becomes the safety net).

## Acceptance criteria

- [ ] Shared-table v5 file → a `channel_lists` preset plan by default.
- [ ] Divergent / unfactorable mission → faithful per-aircraft copy fallback,
      with a clear warning naming the affected aircraft.
- [ ] No silent data loss (existing fidelity guarantees preserved on fallback).
- [ ] Tests extend `test_v5_pipeline_converters` / `test_presets_fidelity`.

## Blocked by

Phase 1 (the preset plan model must exist as the conversion target).
