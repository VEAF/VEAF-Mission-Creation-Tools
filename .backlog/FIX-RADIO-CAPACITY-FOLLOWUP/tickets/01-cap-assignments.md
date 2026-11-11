# 01 — Cap the manual assignment path

Status: ⬜ ready

## Done when

- A radio written through `presets_assignments` is truncated to its declared capacity, by slot, like the role-list path (PRD D1); test on the shipped defaults' CH-47F: its FM radio holds 20 channels in the built table, `radio_fm_30` unchanged in `presets.yaml`.
- The known limitation recorded by #1263 for this path gets its `fixed_in`; `dcs-runtime-traps.md` regenerated.
