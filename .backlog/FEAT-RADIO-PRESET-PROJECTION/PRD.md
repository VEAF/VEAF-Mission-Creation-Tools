# Lot FEAT-RADIO-PRESET-PROJECTION — per-type radio-preset projection (preset plan model)

Status: ✅ done
Branch: feature/radio-preset-projection → PR → develop
Decisions: [ADR 0010](../../docs/adr/0010-per-type-radio-preset-projection.md) ·
Analysis: [RADIO-PRESETS-PER-TYPE-PROJECTION](../../docs/exploration/RADIO-PRESETS-PER-TYPE-PROJECTION.md) ·
Glossary: [CONTEXT.md](../../CONTEXT.md)

## Problem Statement

Setting up radio presets today means describing each aircraft's channels almost
one by one through `radios_collection` / `presets_collection` /
`presets_assignments`. Changing a frequency or a channel order forces the
mission-maker to touch many places, and aircraft with non-1:1 radio hardware —
the Mi-24P (channel 0), the OH-58D (no channel 1 / reserved "M" slot), the AJS-37
(fused radios, leading dummy, hardcoded specials) — each need a hand-written
bespoke _Radio preset_. A change to the mission's frequencies does not propagate
to those aircraft.

## Solution

The mission-maker declares a small _Preset plan_ — a few _Channel lists_ by
_Radio role_ (`primary_1`, `primary_2`, `fm_substitute`, `fm_supplement`,
`fm_secondary`) and coalition — **once**. A per-type _Radio layout_, maintained
by VEAF, lets a packer project those lists onto each aircraft's physical radios,
applying that type's quirks automatically (channel-0 rotation, reserved head
slots, hardcoded specials, radio fusion, capacity, modulation). The packer is a
generator overlay: it produces the existing `PresetDefinition` and reuses the
current injector, band validation and kneeboard generation untouched. Manual
override (an explicit preset assigned to a type) always wins.

## User Stories

1. As a mission-maker, I want to declare my UHF channels once, so that every
   aircraft with a UHF radio gets them without per-type editing.
2. As a mission-maker, I want to declare a second V/UHF list (VHF), so that
   two-radio aircraft are configured from the same place.
3. As a mission-maker, I want an FM list for helicopters (FM standing in for a
   missing second radio), so that helo FM carries mostly the airbase/tactical
   channels of my second list.
4. As a mission-maker, I want a distinct supplemental FM list for attack aircraft
   (FM on top of two V/UHF), so that ground-tactical frequencies are separate.
5. As a mission-maker, I want a secondary supplemental FM for aircraft with two FM
   radios (OH-58D), defaulting to a copy of the supplemental FM if I don't define
   it, so that I only specify it when I care.
6. As a mission-maker, I want the Mi-24P to receive my channels rotated onto its
   channel 0 automatically, so that I don't hand-encode the rotation.
7. As a mission-maker, I want the OH-58D reserved "M"/"C" slots filled
   automatically, so that its "no channel 1" quirk is handled for me.
8. As a mission-maker, I want the AJS-37 to fuse my two V/UHF lists into its
   single radio and keep its hardcoded special channels, so that the Viggen just
   works.
9. As a mission-maker, I want to change one frequency in `channels_collection`
   and have it propagate to every aircraft, so that maintenance is a single edit.
10. As a mission-maker, I want to still override a specific aircraft with a bespoke
    preset when I need to, so that the automation never traps me.
11. As a mission-maker, I want warbirds to receive my VHF list (their band allows
    airbase VHF), so that a P-51 pilot gets tower frequencies without effort.
12. As a mission-maker, I want a channel that lacks a role's band to be dropped
    cleanly (explained under `validate`, silent under `build`), so that a stray
    UHF-only channel in a VHF list is not an error.
13. As a VEAF maintainer, I want each aircraft's radio quirks described as data in
    one hand-maintained layout file, so that supporting a new special airframe is
    a data edit, not code.
14. As a VEAF maintainer, I want the packer to flag when a type's layout no longer
    matches the number of radios in the auto-generated specs, so that a DCS patch
    reordering radios is caught.
15. As a mission-maker migrating from v5, I want `convert-v5` to build a preset
    plan from my old `radioPresets*` tables by default, so that I land on the new
    model automatically.
16. As a mission-maker migrating from v5, I want `convert-v5` to fall back to a
    faithful per-aircraft copy (and tell me) when it cannot factor my mission, so
    that I never silently lose a bespoke layout.

## Implementation Decisions

Per [ADR 0010](../../docs/adr/0010-per-type-radio-preset-projection.md):

- **Generator overlay (option A).** The packer emits `PresetDefinition` objects;
  the injector, `radio_frequency_validator`, and kneeboard generation are reused
  unchanged. The old three layers remain the manual-override path and are read
  as before — no deprecation.
- **Radio roles**: fixed vocabulary `primary_1` (uhf), `primary_2` (vhf; also the
  warbirds' single radio), `fm_substitute`, `fm_supplement`, `fm_secondary`
  (defaults to a copy of `fm_supplement`). The role carries the resolution band;
  a channel with no frequency for that band is dropped from the list.
- **`channel_lists`** authoring block, per coalition, each role an ordered list of
  channel aliases / literals / `{freq, mod}` — reusing `channels_collection`.
  Indicative shape:
  ```yaml
  channel_lists:
    blue:
      primary_1: { 01: Overlord, 20: Garde }   # → uhf
      primary_2: { 01: Batumi }                 # → vhf
      fm_supplement: { 01: JTAC-Alpha }         # → fm
  ```
- **Radio layout** in a new hand-maintained `dcs-radio-layouts.yaml` beside the
  auto-generated specs, keyed by type (exact or regex). Physical radios
  referenced by **index** (specs/`.miz` order) with clear comments. Indicative
  shape:
  ```yaml
  Mi-24P:
    radios:
      1: { role: primary_1, rotate_last_to_head: true }  # R-863, channel 0
      2: { role: fm_substitute }                          # R-828 FM
  ```
  Primitives: slot→role mapping, channel-0 rotation, reserved head slots (default
  fill = the list's last entry #20), hardcoded trailing specials (freq + mod),
  radio fusion, slot capacity, per-channel modulation.
- **Band-based default** for types with no layout entry (UHF radio→`primary_1`,
  VHF→`primary_2`, FM→substitute/supplement by V/UHF count). Explicit layout wins
  and is required whenever a radio is band-ambiguous (A-10C_2 ARC-210) or the
  order is deliberate (A-10 wants VHF on radio 1).
- **Radio-count guard**: the packer cross-checks a layout's radio count against
  the specs and surfaces drift under `validate`.
- **convert-v5** (phase 2): generate a preset plan by default from the v5
  `radioPresets*` tables; fall back to a faithful per-aircraft copy (ADR 0003
  behaviour) with a warning when the mission cannot be factored (aircraft whose
  lists diverge, no shared table).

## Testing Decisions

Good tests assert external behaviour — the projected channels/modulations per
physical slot — not the packer's internal steps.

- **Highest seam = the packer**, tested like `test_presets_fidelity.py`: feed
  `channel_lists` + a minimal `Radio layout` (+ specs), run the packer, assert the
  resulting per-slot `channels`/`modulations`. Cases: standard 1:1, Mi-24P
  rotation, OH-58D reserved slots + `fm_secondary` default, AJS-37 fusion + dummy
  + specials, warbird on `primary_2`, band-mismatch drop.
- **Parsing seam**: `channel_lists` and `dcs-radio-layouts.yaml` parsing, at the
  `PresetsManager` level (prior art: `test_presets.py`).
- **Default-resolution seam**: band-based role deduction for a type with no
  layout entry; radio-count guard flags drift.
- **Integration seam**: the existing injector worker test
  (`test_presets_injector_worker.py`) — a packed plan lands correctly in
  `unit["Radio"]` and old-format override still wins.
- **convert-v5 seam** (phase 2): extend `test_v5_pipeline_converters` /
  `test_presets_fidelity` — a shared-table v5 file yields a preset plan; a
  divergent one falls back with a warning.

## Out of Scope

- In-game confirmation that warbirds accept airbase VHF on their real radios
  (the specs band 38–156 is datamined; verify in DCS, fix-forward if needed).
- Enriching the *content* of the shipped default channels — coordinated with lot
  ENRICH-DEFAULT-PRESETS (see Further Notes).
- Any change to the runtime Lua radio menu (`veafRadio`).

## Further Notes

- **Vertical slices (tracer bullets).** The tickets are thin end-to-end slices —
  each makes one aircraft (or behaviour) work through the whole chain — not
  horizontal layers. **Phase 1**: `01` standard aircraft end-to-end (founding
  bullet), then `02` Mi-24P rotation, `03` OH-58D reserved slots + `fm_secondary`,
  `04` AJS-37 fusion + specials + modulation, `05` warbirds + out-of-band drop
  (these four are independent once `01` lands — parallelisable), `06` populate the
  full layout + capacity, `07` shipped-default migration + docs. **Phase 2**: `08`
  convert-v5 plan generation. Likely one PR per phase. All slices are AFK (the
  architecture is settled in ADR 0010); the warbird in-game band check is a
  separate follow-up, not a blocker.
- Relation to **ENRICH-DEFAULT-PRESETS**: migrating the shipped `presets.yaml` to
  `channel_lists` (ticket 05) is the natural home for broadening the default
  channels; that lot should be folded into or sequenced right after phase 1.
- The reference `radioSettings.lua` (Tripack) already ships as a test fixture
  (`test/python/mission_builder/fixtures/tripack_radioSettings.lua`) and is the
  source for populating the layout (ticket 04).
