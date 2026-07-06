# FEAT-CONVERTV5-PLAN-PRESETS-01 — dual output: plan + faithful

Status: ✅ done
Type: feat

## What to build

`convert_presets(v5_path, v6_path)` writes **two** files instead of one:

- `v6_path` (`presets.yaml`) → **plan**: `channel_lists` + irreducible overrides only.
- sibling `presets.v5.yaml` → **faithful**: the current full output, unchanged.

## Acceptance criteria

- [ ] `presets.v5.yaml` is byte-identical to today's `presets.yaml` output (faithful path
      untouched — reuse the existing assembly).
- [ ] `presets.yaml` (plan) contains `channel_lists` and **no** reducible per-aircraft
      override (dedicated presets for warbirds/jets dropped).
- [ ] An aircraft the packer projects to nothing keeps its override in the plan file too
      (irreducible → zero-loss guard). Determined via `pack_preset_for_type` result.
- [ ] A v5 file with no shared `radioPresets*` table writes neither file's plan block —
      100% legacy, single `presets.yaml`, unchanged (pre-ticket-08 early exit preserved).

## Implementation notes

- Reuse the packer call already made per bespoke aircraft; classify each override
  reducible (packer projects non-empty) vs irreducible (None/empty).
- Plan file = `{channel_lists}` + irreducible overrides' `radios_collection`/
  `presets_collection`/`presets_assignments` subset only.
