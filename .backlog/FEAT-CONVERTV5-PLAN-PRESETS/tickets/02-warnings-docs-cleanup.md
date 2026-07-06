# FEAT-CONVERTV5-PLAN-PRESETS-02 — warnings, cleanup recognition, docs

Status: ✅ done
Type: feat

## What to build

- New i18n messages (FR/EN) telling the maker: `presets.yaml` is a simplified plan
  (frequencies may differ from v5 — warbirds, fused/modulated jet radios projected at
  best effort), verify/edit; the exact v5 reproduction is in `presets.v5.yaml`.
- Replace / complement the per-aircraft `preset_plan_fallback` warning spam with a single
  summary line naming how many aircraft the plan projects at best effort.
- `presets.v5.yaml` recognised as a known v6 mission file (not listed as "unrecognized"
  in cleanup); NOT added to `V6_PIPELINE_CANDIDATES["presets"]` (build loads only
  `presets.yaml`).
- Docs: pipeline reference (FR + EN) documents the two-file output and when to edit which.

## Acceptance criteria

- [ ] All new strings routed through `t()` (FR + EN), no hardcoded English.
- [ ] `presets.v5.yaml` never listed as deletable/unrecognized by the cleanup scan.
- [ ] Build still loads only `presets.yaml`.
- [ ] Pipeline reference pages updated (FR/EN).
