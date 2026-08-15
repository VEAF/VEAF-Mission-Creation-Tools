# FEAT-CONVERTV5-PLAN-PRESETS

Status: ✅ done
Type: feat · ADR 0010

## Context

`convert-v5` (ticket FEAT-RADIO-PRESET-PROJECTION-08) generates a `channel_lists`
preset plan **plus** a faithful per-aircraft override for every aircraft whose v5
layout the packer cannot reproduce *exactly*. On a real mission (Tripack), that
exact-match requirement is so conservative that ~21 aircraft types keep a dedicated
override — the resulting `presets.yaml` is 2900+ lines and barely exploits the
crystallisation the packer was built to project.

The overrides are not a packer limitation: the packer **can** project `channel_lists`
onto all these aircraft (warbirds included — their FuG16-class radios cover the VHF
band, so `primary_2` projects with out-of-band drop, per ticket 05). The dedicated
overrides are ADR-0003 "zero data loss" safety nets that *neutralise* the plan.

## Decision

`convert-v5` emits **two** preset files:

- **`presets.yaml` (plan, default — loaded by the build)**: `channel_lists` plus only
  the *irreducible* overrides (an aircraft the packer projects to **nothing**). Every
  reducible per-aircraft override is dropped — the packer projects the crystallisation
  automatically. For Tripack this collapses to essentially `channel_lists` alone.
- **`presets.v5.yaml` (faithful, reference/rollback — NOT loaded by the build)**: the
  current full output (channel_lists + every dedicated override), iso-functional with v5.

The maker is warned that `presets.yaml` is a simplified plan whose frequencies may
differ from the original v5 (warbirds, fused/modulated jet radios projected at best
effort — **option (a)**: the packer does its best, no override kept for specials/fusion),
and that the exact v5 reproduction is preserved in `presets.v5.yaml`.

### Option (a) confirmed

Specials (e.g. AJS-37 GUARD 243.0) and fused+modulated radios (F-14 radio 2) are
**not** kept as overrides in the plan file — the packer projects them at best effort
(possibly incomplete), the maker is warned, and `presets.v5.yaml` holds the exact copy.

## Scope

- `mission_builder/v5_pipeline_converters.py`: `convert_presets` produces both outputs;
  a helper derives the plan (channel_lists + irreducible overrides only).
- i18n FR/EN: new warning messages (plan is simplified, faithful copy location).
- Tests: redirect existing fidelity assertions to `presets.v5.yaml`; add plan-file tests
  (channel_lists present, no reducible overrides, warbird projected onto VHF).
- Docs: pipeline reference (FR/EN) documents the two files.
- `V6_PIPELINE_CANDIDATES`/cleanup known-files: `presets.v5.yaml` recognised, not loaded.

## Out of scope

- Per-type `dcs-radio-layouts.yaml` entries for the common jets (F-14, AV8B, MiG-29,
  AH-64, Ka-50, T-45) — that is the separate "layouts for jets" chantier which would let
  the plan reproduce their fused radios exactly. Here they are projected at best effort.
- Any change to the packer itself or the `channel_lists` model.

---

## FEAT-CONVERTV5-PLAN-PRESETS-01 — dual output: plan + faithful

Status: ✅ done
Type: feat

### What to build

`convert_presets(v5_path, v6_path)` writes **two** files instead of one:

- `v6_path` (`presets.yaml`) → **plan**: `channel_lists` + irreducible overrides only.
- sibling `presets.v5.yaml` → **faithful**: the current full output, unchanged.

### Acceptance criteria

- [ ] `presets.v5.yaml` is byte-identical to today's `presets.yaml` output (faithful path
      untouched — reuse the existing assembly).
- [ ] `presets.yaml` (plan) contains `channel_lists` and **no** reducible per-aircraft
      override (dedicated presets for warbirds/jets dropped).
- [ ] An aircraft the packer projects to nothing keeps its override in the plan file too
      (irreducible → zero-loss guard). Determined via `pack_preset_for_type` result.
- [ ] A v5 file with no shared `radioPresets*` table writes neither file's plan block —
      100% legacy, single `presets.yaml`, unchanged (pre-ticket-08 early exit preserved).

### Implementation notes

- Reuse the packer call already made per bespoke aircraft; classify each override
  reducible (packer projects non-empty) vs irreducible (None/empty).
- Plan file = `{channel_lists}` + irreducible overrides' `radios_collection`/
  `presets_collection`/`presets_assignments` subset only.

---

## FEAT-CONVERTV5-PLAN-PRESETS-02 — warnings, cleanup recognition, docs

Status: ✅ done
Type: feat

### What to build

- New i18n messages (FR/EN) telling the maker: `presets.yaml` is a simplified plan
  (frequencies may differ from v5 — warbirds, fused/modulated jet radios projected at
  best effort), verify/edit; the exact v5 reproduction is in `presets.v5.yaml`.
- Replace / complement the per-aircraft `preset_plan_fallback` warning spam with a single
  summary line naming how many aircraft the plan projects at best effort.
- `presets.v5.yaml` recognised as a known v6 mission file (not listed as "unrecognized"
  in cleanup); NOT added to `V6_PIPELINE_CANDIDATES["presets"]` (build loads only
  `presets.yaml`).
- Docs: pipeline reference (FR + EN) documents the two-file output and when to edit which.

### Acceptance criteria

- [ ] All new strings routed through `t()` (FR + EN), no hardcoded English.
- [ ] `presets.v5.yaml` never listed as deletable/unrecognized by the cleanup scan.
- [ ] Build still loads only `presets.yaml`.
- [ ] Pipeline reference pages updated (FR/EN).

---

## FEAT-CONVERTV5-PLAN-PRESETS-03 — tests

Status: ✅ done
Type: test

### What to build

- Redirect the existing `TestTripackPresetsFidelity` assertions to read
  `presets.v5.yaml` (the faithful file still carries the dedicated overrides).
- New plan-file tests (real Tripack fixture):
  - `presets.yaml` contains `channel_lists` for both coalitions.
  - `presets.yaml` has no dedicated warbird/jet override (reducible overrides dropped).
  - The packer, fed the plan's `channel_lists`, projects a warbird (e.g. Bf-109K-4)
    onto its VHF radio (proves the crystallisation is exploited).
- Synthetic test: an aircraft the packer projects to nothing keeps its override in the
  plan file (irreducible guard).

### Acceptance criteria

- [ ] Existing fidelity suite passes against `presets.v5.yaml`.
- [ ] New plan tests pass.
- [ ] `--cov-fail-under` bumped so the gate stays within ~2 pts of measured coverage.
