# Lot FIX-MIG15-PRIMARY-FREQ — build wrongly rejects the MiG-15bis HF primary frequency

Status: ✅ done
Branch: fix/mig15-primary-freq → PR #546 → merged into develop

## Problem Statement

Building a mission containing a MiG-15bis (reported by Tripack) fails the radio-presets
phase with *"Invalid primary radio frequency (below 30.0 MHz …): MiG-15 Template
(3.75 MHz), MiG-15 Template Red (3.75 MHz)"*. The failure appears **only after** editing
the mission in the DCS Mission Editor and re-extracting: that is when DCS materialises the
group's `frequency: 3.75` into `dynamic-slot-templates.yaml`.

## Root cause

The build-time safety net in `PresetsInjectorWorker.process_groups`
(`presets_injector_worker.py`) applies a blanket floor: any human group whose primary
`frequency` is below `_MIN_PRIMARY_RADIO_MHZ` (30.0) fails the build. That floor was added
(FIX-DYNSLOT-RADIO-UNITS) to stop an **ADF** channel (e.g. Yak-52 ARK-15M, 0.625 MHz) from
being promoted to the primary radio — a case DCS does reject.

But the **MiG-15bis** legitimately has an HF primary radio: its only radio, the RSI-6K,
operates at **3.75–5.0 MHz** (`dcs-radio-specs.yaml`, `dcs_rejects_on_load: true`). DCS
itself writes and accepts `frequency: 3.75`, so the blanket floor is a false positive.
The spec range alone cannot distinguish the two cases: 3.75 is in the RSI-6K range and
0.625 is in the ARK-15M range.

Discriminator (verified across the whole spec DB): the **only** aircraft with both
`dcs_rejects_on_load: true` and a sub-30 MHz radio is the MiG-15bis family, and that radio
is its genuine primary. Every other sub-30 case (Yak-52, Ka-50, Mi-8/24, MiG-29…) is an
ADF/HF secondary alongside a VHF/UHF primary.

## Solution

Make the build-time safety net spec-aware (the promotion guard in `process_units` is left
untouched — it has no per-aircraft context). New helper
`_is_valid_primary_frequency_for_unit(unit_type, freq)`:

- frequency at/above the 30 MHz floor → valid (unchanged);
- below the floor → valid **only** when DCS strictly validates the aircraft
  (`is_strict`) **and** the frequency is in its spec ranges (`validate_frequency`).

This accepts the MiG-15bis @ 3.75 while still rejecting the Yak-52 @ 0.625 (non-strict)
and any unknown aircraft below the floor.

## Testing Decisions

- `process_groups` with a MiG-15bis @ 3.75 human group → does **not** raise (new test).
- Existing Yak-52 @ 0.625 → still raises (unchanged guard).
- Helper validated against Tripack's real data: MiG-15bis@3.75=True, Yak-52@0.625=False,
  MiG-15bis@2.0=False (out of range), unknown@5.0=False.
- Real end-to-end build is not reproducible in the dev checkout (the presets phase runs
  after `.miz` packing, which aborts earlier on missing community `published/` scripts);
  the unit test exercises the exact failing code path.

## Out of Scope

- The promotion guard floor in `process_units` (still correct without per-aircraft context).
- The `dcs-radio-specs.yaml` data (already accurate for the MiG-15bis).
