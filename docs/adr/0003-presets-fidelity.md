---
status: accepted
---

# Iso-functional radio-presets conversion (v5 → v6)

The v5 `radioSettings.lua` encodes, per aircraft, an explicit per-radio channel
table (`["Radio"][N]["channels"][index] = frequency`) that DCS writes verbatim
into each unit's `Radio` table. Some aircraft use **bespoke** tables that the
`convert-v5` presets converter silently flattened to a standard preset (or
skipped), losing real configuration. This note (PRESETS-FIDELITY spike, item
13b) documents the gap and the chosen fix (item 13a).

## The two reference quirks (from a real Tripack mission)

- **Mi-24P** — a **channel rotation**: slot `[1]` (DCS *channel 0*) holds preset
  **#20**, then channels 1–19 hold presets 1–19 (`{[1]=RADIO1_20, [2]=RADIO1_01,
  …, [20]=RADIO1_19}`). It also has a **second radio** (FM, `RADIO3_*`).
- **AJS37** — a **leading dummy** (`[1]=0`, "channel 100"), then 20 UHF + 19 VHF
  preset references, then **7 hardcoded special frequencies** (FR22/FR24), plus a
  per-channel **`modulations`** table (AM/FM selection).

The previous converter classified each aircraft only by *which preset table its
radio 1 referenced* (`uhf`/`vhf`/`fm`/`warbird`) and assigned a standard preset.
For these two aircraft that drops the rotation, the offset, the extra radio, the
hardcoded specials and the modulations.

## v6 representability

The v6 model already supports everything needed — no schema redesign required:

- `RadioDefinition.to_dict()` emits an explicit `channels: {number: freq}` map,
  so arbitrary channel→frequency mappings (rotations, offsets, hardcoded freqs)
  are representable.
- A `PresetDefinition` maps **several** radio slots, covering multi-radio
  aircraft (Mi-24 UHF + FM).
- The injector writes `unit["Radio"] = preset.to_dict()`, the **same shape** DCS
  expects, so reproducing the v5 table verbatim is **iso-functional by
  construction** (the v6 channel `number` is the v5 table index — no 0-indexed
  vs displayed ambiguity).
- **Gap:** the per-channel `mod` (modulation) field exists in the model but was
  commented out of `to_dict()`. The fix re-enables it so the AJS37 AM/FM
  selection round-trips.

## Decision

When an aircraft's v5 `["Radio"]` table is **non-standard** (any radio whose
channel list is not a plain 1:1 of a standard preset table — i.e. it reorders,
offsets, mixes hardcoded frequencies, carries modulations, or adds extra
radios), `convert-v5` emits a **dedicated per-aircraft preset** that reproduces
the exact channel→frequency map (resolving `radioPresets*["##TOKEN##"]`
references to their frequencies, keeping hardcoded literals) plus the
modulations, and assigns the aircraft to it. Standard aircraft keep the existing
lightweight assignment to a shared preset.

Decisions (2026-06-10, with David): include modulations now; merge on green CI
with the real Tripack `radioSettings.lua` as a regression fixture, then verify
the channels in-game post-merge (pre-release, fix-forward).

## Consequences

- Bespoke aircraft (Mi-24, AJS37, …) keep their exact radio layout after
  conversion instead of being flattened or skipped.
- Per-aircraft presets make `presets.yaml` larger for missions that use many
  bespoke layouts — acceptable, and only for the aircraft that need it.
- Channel correctness is ultimately a DCS-runtime property; the regression
  fixture locks the *conversion* output, the in-game test confirms the *result*.
