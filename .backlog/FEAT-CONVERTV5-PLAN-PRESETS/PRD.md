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
