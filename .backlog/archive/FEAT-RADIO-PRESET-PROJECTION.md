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

---

## FEAT-RADIO-PRESET-PROJECTION-01 — full chain on a standard aircraft

Status: ✅ done
Type: feat · Phase: 1 · AFK

### Parent

Lot [FEAT-RADIO-PRESET-PROJECTION](../PRD.md) · [ADR 0010](../../../docs/adr/0010-per-type-radio-preset-projection.md)

### What to build

The founding tracer bullet: the complete path for a standard 1:1 aircraft. Parse
a `channel_lists` block (per coalition, roles `primary_1`/`primary_2`/`fm_*`),
resolve each role to its band from `channels_collection`, deduce the role of each
physical radio from the specs (band-based default, no layout file yet), pack a
`PresetDefinition`, and let the existing injector write `unit["Radio"]`. A channel
lacking the role's band is dropped. An explicit old-format preset assigned to a
type still wins over the packer (manual override, ADR 0010).

Verifiable end-to-end: an F-16 receives its UHF/VHF/FM lists on the right radios;
a type with an explicit override keeps it.

### Acceptance criteria

- [x] `channel_lists` parsed per coalition into roles; aliases resolve by band.
- [x] Default maps a standard aircraft's radios to roles from the specs.
- [x] Packer emits a `PresetDefinition`; downstream injection/validation reused.
- [x] Channel lacking the role's band is dropped (recorded).
- [x] Explicit old-format assignment wins over the packer.
- [x] Tests: parsing + a standard aircraft packed end-to-end (prior art
      `test_presets.py`, `test_presets_injector_worker.py`).

### Blocked by

None — can start immediately.

### Implementation notes

The default is **not** the flat "radio 1 -> primary_1, radio 2 -> primary_2,
radio 3 -> FM" positional rule the ticket description sketched. Verified against
the real `dcs-radio-specs.yaml`: only 19 of 87 aircraft have radios that are
cleanly single-band throughout — most modern radios (ARC-210, ARC-222…) report
the union of every mode they support, and some 2-radio helicopters (Mi-8MT,
UH-1H-shaped) mean "1 primary + 1 FM", not "UHF + VHF". A pure radio-count or
band-purity heuristic misclassifies the F-16 (this ticket's own worked example),
the Hornet, and most helicopters.

The implemented default instead classifies each physical radio from its ranges
(uhf-dedicated / vhf-dedicated / ambiguous combo / FM-or-other), assigns
dedicated radios to their natural role directly (so the A-10's inverted
VHF-first order resolves correctly with **no** explicit layout entry), and falls
back to physical order only for genuinely ambiguous combo radios (e.g. the
Hornet's two identical ARC-210s). See `_classify_radio` / `_assign_roles_by_position`
in `presets_manager.py` for the reasoning, and
`TestPackPresetRealSpecsEndToEnd` in `test_radio_preset_packer.py` for the
regression coverage against real aircraft (F-16, F/A-18, A-10, UH-1H, Mi-8MT,
Bf-109K-4).

This does not reopen ADR 0010's decisions — the outcome (simple default for the
common case, explicit `Radio layout` override for the rest) is unchanged; only
the *mechanism* differs from the ADR's illustrative sketch. `fm_secondary`
defaulting to a copy of `fm_supplement` (ticket 03's stated behaviour) is
implemented here too, since it falls out naturally from the same role-assignment
pass.

---

## FEAT-RADIO-PRESET-PROJECTION-02 — radio layout file + channel-0 rotation (Mi-24P)

Status: ✅ done
Type: feat · Phase: 1 · AFK

### Parent

Lot [FEAT-RADIO-PRESET-PROJECTION](../PRD.md) · [ADR 0010](../../../docs/adr/0010-per-type-radio-preset-projection.md)

### What to build

Introduce the hand-maintained `dcs-radio-layouts.yaml` (beside the auto-generated
specs), keyed by type, mapping physical radios by index (with clear comments) to
roles plus primitives. Wire it into the packer as an override of the band-based
default, add the radio-count guard (flag layout/specs drift under `validate`), and
implement the first primitive — **channel-0 rotation** — end-to-end on the Mi-24P
(radio 1 rotates the list's last entry to the head; radio 2 = `fm_substitute`).

Verifiable end-to-end: the Mi-24P shows the rotated channel 0.

### Acceptance criteria

- [x] `dcs-radio-layouts.yaml` parsed (exact type + regex), radios by index.
- [x] Layout entry overrides the band-based default for its type.
- [x] Channel-0 rotation primitive implemented; Mi-24P reproduced.
- [x] `fm_substitute` role reaches the Mi-24P FM radio.
- [x] Radio-count guard flags drift under `validate`.
- [x] Tests (prior art `test_presets_fidelity.py`).

### Blocked by

- FEAT-RADIO-PRESET-PROJECTION-01

### Implementation notes

- Schema: `dcs-radio-layouts.yaml` top-level keys are unit_type strings (exact
  match first, then `re.fullmatch` regex fallback — mirrors
  `PresetAssignmentCollection._match_unit_type`). Each entry has a `radios` map
  keyed by **1-based physical radio index**; each radio has a mandatory `role`
  and optional primitive flags — so far only `rotate_last_to_head: true`
  (channel-0 rotation). The file's header comment documents the schema in full
  for tickets 03/04 to extend.
- New `presets_manager.py` pieces: `RadioLayoutRadio`/`RadioLayoutEntry`
  dataclasses, `parse_radio_layouts`, `get_radio_layout` (exact+regex lookup),
  `_check_layout_radio_count` (the radio-count guard), `_rotate_last_to_head`
  (the rotation primitive, produces a renumbered `RadioDefinition` copy). The
  bundled file is cached module-level via `_load_radio_layouts`, same pattern
  as `radio_frequency_validator._load_specs`.
- `_resolved_slots_for_type` now consults `get_radio_layout` first; when an
  entry exists it fully replaces `_assign_roles_by_position`'s role assignment
  for that type (not merged/blended) and carries a per-radio rotation flag
  through to `pack_preset_for_type`, which applies `_rotate_last_to_head` when
  building that radio's channel content.
- The radio-count guard runs at pack time (not a separate `validate` pass —
  there is no dedicated validate/build verbosity split for this concern yet)
  and logs via `logger.warning` (i18n key
  `presets_injector.radio_layout.count_mismatch`, added to en.json/fr.json to
  satisfy the repo's no-hardcoded-prose i18n test).
- Mi-24P entry: radio 1 (R-863) `primary_1` + `rotate_last_to_head: true`;
  radio 2 (R-828) `fm_substitute`. Verified end-to-end against the real
  `dcs-radio-specs.yaml` (2 radios) and reproduces the Tripack fixture's
  channel-0 rotation (list entry #20 at DCS channel slot 1, #1..#19 at slots
  2..20), uniformly for both coalitions (rotation is an airframe property).

---

## FEAT-RADIO-PRESET-PROJECTION-03 — reserved head slots + fm_secondary (OH-58D)

Status: ✅ done
Type: feat · Phase: 1 · AFK

### Parent

Lot [FEAT-RADIO-PRESET-PROJECTION](../PRD.md) · [ADR 0010](../../../docs/adr/0010-per-type-radio-preset-projection.md)

### What to build

Implement the **reserved head slot(s)** primitive (default fill = the list's last
entry #20; the OH-58D FM adds a second head slot filled from #01), and the
`fm_secondary` role (defaults to a copy of `fm_supplement` when the mission-maker
does not define it). Demonstrate end-to-end on the OH-58D: UHF/VHF radios get a
reserved "M" head slot; FM1/FM2 get "C"+"M" head slots; the two FM radios receive
`fm_supplement` and `fm_secondary`.

Verifiable end-to-end: the OH-58D's "no channel 1" layout is reproduced.

### Acceptance criteria

- [x] Reserved head slot primitive (count + fill entry) implemented.
- [x] `fm_secondary` role; absent → copy of `fm_supplement`.
- [x] OH-58D reproduced: M/C head slots on the right radios.
- [x] Tests (prior art `test_presets_fidelity.py`).

### Blocked by

- FEAT-RADIO-PRESET-PROJECTION-02 (needs its `dcs-radio-layouts.yaml` file + parser
  + packer-override wiring — corrected from the original "01 only" dependency,
  which assumed that plumbing already existed)

### Note

`fm_secondary` defaulting to a copy of `fm_supplement` was already implemented in
ticket 01 (it fell out naturally from the role-assignment pass). This ticket's
remaining scope is the **reserved head slot** primitive and the OH-58D layout
entry.

### Implementation notes

- Schema: `dcs-radio-layouts.yaml` radios gain a second, optional primitive key,
  `reserved_head_slots: [<list index>, ...]`, alongside ticket 02's
  `rotate_last_to_head`. Each entry is a **1-based index into the channel
  list** that fills one leading DCS channel slot, in the declared order.
  **Only the index matching the list's actual last entry is removed from its
  original tail position** (rotation semantics, the same convention as
  `rotate_last_to_head`); any other reserved index is a leading **duplicate**
  that also stays in its original tail position. Two shapes populated so far:
  `[20]` (a single "M" slot fed by the list's last entry, removed from the
  tail — a 20-entry list still produces 20 slots total — OH-58D UHF/VHF) and
  `[1, 20]` (a "C" slot duplicating the list's first entry — which stays in
  the tail too — then an "M" slot fed by the last entry, removed from the
  tail — a 20-entry list produces 21 slots total — OH-58D FM1/FM2). The two
  primitives are mutually exclusive per radio: declaring both on the same
  radio entry is a rejected authoring error (`parse_radio_layouts` raises
  `ValueError`). The file's header comment documents the schema in full for
  ticket 06 to extend.
- `RadioLayoutRadio` gains a `reserved_head_slots: list[int]` field (default
  `[]`). New `_prepend_reserved_slots` function (parallel to
  `_rotate_last_to_head`): produces a renumbered `RadioDefinition` copy with
  the reserved entries first, then the tail (the list minus only the
  last-entry index, if it was one of the reserved ones). An index that is not
  a valid 1-based position (`<= 0`, or beyond the list's actual length) is
  skipped rather than raising — safe degradation for a shorter-than-expected
  maker list, consistent with `pack_preset_for_type`'s existing HF-radio
  fallback philosophy. `parse_radio_layouts` also tolerates a non-integer
  `reserved_head_slots` entry (malformed YAML): logged via a new i18n key
  (`presets_injector.radio_layout.invalid_reserved_head_slot`) and skipped,
  rather than aborting the whole layout file's parsing.
- Landed after ticket 04 (AJS-37 fusion/specials/modulation) merged first and
  restructured the same dispatch: `_content_for_radio` now applies all
  declared primitives in a fixed composition order (fusion/base content, then
  rotation-or-reserved-slots — mutually exclusive with each other — then
  leading dummy, then trailing specials). `reserved_head_slots` slots into
  that pipeline as an `elif` alongside `rotate_last_to_head`, rather than
  needing its own tuple-threading through `_resolved_slots_for_type` as
  originally implemented pre-rebase.
- OH-58D layout entry (4 physical radios, verified against the real
  `dcs-radio-specs.yaml` — unit_type is `OH58D`, no hyphen): radio 1 (UHF)
  `primary_1` + `reserved_head_slots: [20]`; radio 2 (VHF) `primary_2` +
  `reserved_head_slots: [20]`; radio 3 (FM1) `fm_supplement` +
  `reserved_head_slots: [1, 20]`; radio 4 (FM2) `fm_secondary` +
  `reserved_head_slots: [1, 20]` (content defaults to `fm_supplement`'s list
  via ticket 01's `_channel_list_for_role`, independent of the primitive
  declared on the radio). Note: the raw Tripack fixture
  (`tripack_radioSettings.lua`, `["blue OH-58D"]`) itself has a stale/buggy
  head-slot fill (duplicates entry #01 instead of reserving #01 then #20) —
  implemented per ADR 0010's resolved decision and the exploration doc's §8
  analysis instead of literally reproducing that fixture bug.

---

## FEAT-RADIO-PRESET-PROJECTION-04 — radio fusion + hardcoded specials + modulation (AJS-37)

Status: ✅ done
Type: feat · Phase: 1 · AFK

### Parent

Lot [FEAT-RADIO-PRESET-PROJECTION](../PRD.md) · [ADR 0010](../../../docs/adr/0010-per-type-radio-preset-projection.md)

### What to build

Implement the remaining primitives — **radio fusion** (concatenate several role
lists into one physical radio), **trailing hardcoded specials** (constant
frequencies + modulations appended after the lists), and **per-channel
modulation** — end-to-end on the AJS-37: its single V/UHF radio fuses `primary_1`
+ `primary_2` behind a leading dummy, then the FR22/FR24 special channels
(including GUARD), with the AM/FM modulation map preserved.

Verifiable end-to-end: the AJS-37's fused radio with dummy, specials and
modulations is reproduced.

### Acceptance criteria

- [x] Radio fusion primitive (ordered concatenation of role lists) implemented.
- [x] Trailing hardcoded specials (freq + mod) appended; overridable by the maker.
- [x] Per-channel modulation emitted in the `PresetDefinition`.
- [x] AJS-37 reproduced (dummy + fused lists + specials + modulations).
- [x] Tests (prior art `test_presets_fidelity.py`).

### Blocked by

- FEAT-RADIO-PRESET-PROJECTION-02 (needs its `dcs-radio-layouts.yaml` file + parser
  + packer-override wiring — corrected from the original "01 only" dependency,
  which assumed that plumbing already existed)

### Implementation notes

- Schema: three new optional keys on a `dcs-radio-layouts.yaml` radio entry,
  alongside ticket 02's `role`/`rotate_last_to_head`:
  - `fuse: [role_a, role_b, ...]` — radio fusion. Concatenates two or more
    Radio roles' channel lists, in the declared order, into this ONE physical
    radio's channel map; each source list's own numbering is discarded and the
    fused result is renumbered sequentially from slot 1. Replaces the plain
    single-role lookup entirely for that radio. `role` is still read (used for
    the resulting radio's `radio_type`/title).
  - `leading_dummy: {freq: <float>, mod: <0|1>}` — a reserved slot 1 with a
    fixed, hardcoded frequency and no source Channel-list entry at all
    (distinct from ticket 03's reserved-slot primitive, which fills its head
    slot(s) from a channel-list index — this one is a pure airframe constant).
    Shifts the rest of the radio's content to start at slot 2.
  - `trailing_specials: [{freq: <float>, mod: <0|1>}, ...]` — a declared,
    ordered list of fixed (frequency, modulation) pairs appended after the
    radio's other content, at the trailing slots.
  - Composition order when several primitives apply to the same radio: fusion
    (or the plain role list) → channel-0 rotation → leading dummy inserted at
    slot 1 → trailing specials appended last.
- New `presets_manager.py` pieces: `HardcodedChannel` dataclass (freq + optional
  mod, used by both `leading_dummy` and `trailing_specials`);
  `RadioLayoutRadio` gained `fuse`/`leading_dummy`/`trailing_specials` fields;
  `parse_radio_layouts` gained `_parse_hardcoded_channel`/
  `_parse_hardcoded_channels` helpers; `_fuse_role_lists` (the fusion
  primitive), `_renumber_from` (renumbering helper reused by the dummy
  insertion), `_content_for_radio` (applies all primitives in composition
  order to materialize one physical radio's final channel map).
- `_resolved_slots_for_type` was refactored: per-radio resolution (role lookup,
  fuse detection, "does this radio have any content at all" check) is now
  isolated in a new `_resolve_one_radio` helper, which delegates to
  `_content_for_radio` for primitive application. This keeps the "gap before
  the last usable radio" safety check and the overall flow unchanged for
  tickets 01/02's existing radios (no primitives declared -> `_content_for_radio`
  degenerates to the plain role list, byte-identical to the pre-ticket-04
  behaviour) while giving fusion a way to produce content without needing its
  own single-role match.
- Per-channel modulation needed no changes to `RadioDefinition.to_dict()`
  (already emits a `modulations` table when any channel has `.mod` set,
  ticket 01) — the new primitives simply set `mod` on the `Channel` objects
  they produce.
- AJS-37 entry: one radio, `role: primary_1` (the first fused list) with
  `fuse: [primary_1, primary_2]`, `leading_dummy: {freq: 0, mod: 0}` and 7
  `trailing_specials` (FR22 x3 at 30/31/32 MHz FM, FR24 E/F at 33/34 MHz FM,
  FR24 G at 127.5 MHz AM, FR24 H/GUARD at 243.0 MHz AM). Values are the real
  Tripack fixture's `red AJS37` data (`test/python/mission_builder/fixtures/
  tripack_radioSettings.lua`), the same ground truth already pinned by the
  ADR 0003 legacy-path regression tests in `test_presets_fidelity.py`
  (`TestTripackPresetsFidelity.test_ajs37_hardcoded_specials_preserved` /
  `test_ajs37_modulations_preserved`) — chosen over `blue AJS37`'s values in
  the same fixture, whose slot 47 (284.0 MHz) does not match the standard
  243.0 MHz UHF guard frequency the `red` side and external sources agree on;
  `blue`'s block looks like a data-entry inconsistency in that particular
  Tripack mission rather than an airframe constant.
- Manual-override guard: `TestBespokeOverrideStillWinsOverAjs37Packer` in
  `test_radio_preset_ajs37.py` asserts `PresetsManager.get_radios_for` returns
  an explicit `presets_assignments` preset for `AJS37` untouched by the packer
  — no production code change was needed for this (the override check already
  runs, and returns, before the packer is ever invoked).

---

## FEAT-RADIO-PRESET-PROJECTION-05 — warbirds on primary_2 + out-of-band drop

Status: ✅ done
Type: feat · Phase: 1 · AFK

### Parent

Lot [FEAT-RADIO-PRESET-PROJECTION](../PRD.md) · [ADR 0010](../../../docs/adr/0010-per-type-radio-preset-projection.md)

### What to build

Pack the warbirds' single radio on `primary_2` (VHF) and make the out-of-band
**drop** behaviour explicit: channels outside the type's specs band are dropped
from the list, explained under `validate` (verbose) and silent under `build` —
reusing the existing frequency validator and report split. Demonstrate end-to-end
on a warbird (e.g. P-51D receives the airbase VHF channels that fall in its band;
UHF-only channels are dropped).

Note: whether the module truly accepts airbase VHF in game is out of scope (the
38–156 band is datamined) — see PRD Out of Scope; this slice implements the
tooling behaviour, in-game confirmation is a separate follow-up.

### Acceptance criteria

- [x] Warbird single radio packed on `primary_2`.
- [x] Out-of-band channels dropped; reported under `validate`, silent under `build`.
- [x] Tests: a warbird packs its in-band VHF and drops the rest (prior art
      `test_radio_frequency_validator.py`, `test_presets_fidelity.py`).

### Blocked by

- FEAT-RADIO-PRESET-PROJECTION-01 only — does NOT need ticket 02's layout file:
  warbirds already pack onto `primary_2` by default under ticket 01's
  band-classification (a single-range radio spanning both the FM ceiling and the
  UHF floor resolves to "vhf", see `_classify_radio` and
  `test_warbird_single_radio_resolves_to_primary_2`). No layout entry needed.

### Note

The "pack on primary_2" acceptance criterion is already satisfied by ticket 01.
This ticket's real remaining scope is the **out-of-band drop reporting split**
(verbose under `validate`, silent under `build`) — check whether that mode
distinction already exists in the `validate`/`build` commands or needs adding.

### Implementation notes

Investigation confirmed both halves of the acceptance criteria are already
satisfied by existing infrastructure — no production code changed, only tests
added to pin the behaviour down as a regression guard:

- **"Warbird on `primary_2`"**: already covered by ticket 01's
  `test_warbird_single_radio_resolves_to_primary_2` (a warbird's single radio,
  e.g. `Bf-109K-4`'s FuG 16 ZY spanning 38–156 MHz in one range, is classified
  "vhf" by `_classify_radio` and lands on `primary_2` with no layout entry).

- **"Out-of-band drop, reported under `validate`, silent under `build`"**:
  the codebase has no `presets`-aware `validate` CLI command — `validate.py`
  only runs `validate_mission_folder` (mission-folder linting, unrelated to
  radio presets). The actual verbosity split already lives one layer down, in
  `PresetsInjectorWorker` + `radio_frequency_validator.py`, and it already
  implements exactly what the ADR describes:
  - `_drop_out_of_range_channels` (pre-existing, added for a prior ticket)
    silently drops any channel outside the aircraft's hardware range before
    writing the `Radio` table — DCS would otherwise refuse to save the
    mission.
  - `warn_invalid_channel_frequencies` logs at `logger.warning` only for
    `dcs_rejects_on_load: true` aircraft (a handful of hard-crash types); every
    other aircraft — including all warbirds, none of which are in that strict
    list — logs at `logger.debug`, which is invisible in a normal `build`'s
    console output.
  - `generate_validation_report` always writes a full per-channel Markdown
    report (`presets-validation-report.md`), which `build.py` generates then
    deletes when clean, and which `inject_presets --validate-report <file>`
    (the closest thing to a "validate" entry point for presets) keeps and
    exposes explicitly. This is the "verbose" side of the split — every
    dropped channel, its frequency, and the aircraft's valid ranges, spelled
    out.
  - Net effect: a normal `build` stays terse (no console noise for a
    non-strict warbird drop), while the full explanation is always one
    `--validate-report` flag (or an inspection of the generated report file)
    away. This already satisfies "verbose under validate, silent under build"
    in spirit; no new flag or plumbing was needed (Absolute Simplicity rule).

- **What changed**: only tests, in
  `test/python/presets_injector/test_presets_injector_worker.py`
  (`TestWarbirdPrimary2BandDropReporting`). They exercise the real
  `pack_preset_for_type` → `PresetsInjectorWorker.process_units`/
  `process_groups` → `generate_validation_report` pipeline end-to-end for
  `Bf-109K-4` with a `primary_2` channel list mixing an in-band VHF frequency
  (131.0 MHz) and an out-of-band UHF one (280.0 MHz), asserting: the injected
  `Radio` table drops the UHF channel and keeps the VHF one, the drop is
  reported in the generated validation report, and no `logger.warning` fires
  during a normal (non-strict) `process_groups` run.

---

## FEAT-RADIO-PRESET-PROJECTION-06 — populate the full layout + capacity/truncation

Status: ✅ done
Type: feat · Phase: 1 · AFK

### Parent

Lot [FEAT-RADIO-PRESET-PROJECTION](../PRD.md) · [ADR 0010](../../../docs/adr/0010-per-type-radio-preset-projection.md)

### What to build

With every primitive available, populate `dcs-radio-layouts.yaml` for the
remaining non-trivial types in the reference Tripack fixture (A-10 with the
deliberate VHF-on-radio-1 order, CH-47F, and any other quirk from §4 of the
analysis), and implement the **slot capacity** primitive with truncation when a
list exceeds a radio's capacity (recorded; verbose under `validate`, silent under
`build`). Band-only types are deliberately left to the default and documented as
such.

### Acceptance criteria

- [x] Every non-trivial fixture type has a layout entry (A-10, CH-47F, …).
- [x] Slot capacity + truncation implemented and reported.
- [x] Band-only types documented as intentionally default.
- [x] Radio-count guard passes for all populated entries.
- [x] A test asserts the populated layout reproduces the fixture for the headline
      types.

### Blocked by

- FEAT-RADIO-PRESET-PROJECTION-02
- FEAT-RADIO-PRESET-PROJECTION-03
- FEAT-RADIO-PRESET-PROJECTION-04
- FEAT-RADIO-PRESET-PROJECTION-05

### Implementation notes

**Slot capacity primitive.** New optional `RadioLayoutRadio.capacity: int | None`
field, parsed from a `capacity: <int>` key in `dcs-radio-layouts.yaml`. Applied
in `_content_for_radio` as the LAST composition step (after rotation/reserved
slots, leading dummy, and trailing specials), via a new `_truncate_to_capacity`
helper: when the fully composed channel count exceeds `capacity`, the excess is
dropped from the END of the list and the survivors renumbered 1..capacity. A
truncation logs one `logger.debug` line (`presets_injector.radio_layout.capacity_truncated`,
en+fr) with the unit type, radio index, capacity and dropped count — matching
ticket 05's silent-under-build / no-warning-noise convention (exploration doc
§8.4); no new reporting subsystem was added, since the packer has no group/
mission context to feed the existing `FrequencyIssue`/validation-report
mechanism, and a debug log is sufficient per the ticket's own guidance. No
aircraft in the reference fixture actually needs it today — the AJS-37's
47-slot fused radio is already an exact fit (confirmed by
`test_radio_preset_ajs37.py`'s `len(channels) == 47` assertion) — so the
primitive ships available but unused in `dcs-radio-layouts.yaml`, ready for the
next aircraft that needs it.

**CH-47Fbl1 fix.** Real `dcs-radio-specs.yaml` data: radio 1 "VHF FM: ARC-186"
has ranges `[30-88 FM, 108-116 AM, 116-152 AM]` — the secondary AM range pushes
`_classify_radio` to return `"vhf"` (reaches above the FM ceiling into the
V/UHF window) instead of recognizing the radio's real FM role, so the default
projection puts `primary_2` on it instead of an FM role — pinned by a new test
using the REAL specs (`TestDefaultMisclassifiesCh47fWithoutLayoutEntry` in
`test_radio_preset_ch47f.py`) before adding the fix. Added an explicit
`CH-47Fbl1` entry: radio 1 (ARC-186) → `fm_substitute` + `rotate_last_to_head`,
radio 2 (ARC-164, UHF) → `primary_1` + `rotate_last_to_head` (both rotations
match the real Tripack fixture, which rotates both radios exactly like the
Mi-24P), radio 3 (ARC-201D, a clean second FM set) → `fm_secondary` with no
primitive — declared so the radio-count guard matches the specs' real 3-radio
count, but produces no content unless the maker declares a distinct
`fm_secondary` list (`_channel_list_for_role` defaults `fm_secondary` to
`fm_supplement`, which the shipped default's `channel_lists.blue` does not
declare — see below).

**A-10C / A-10C_2 — intentionally absent.** Both are already resolved
correctly by `_assign_roles_by_position`'s band-based default (confirmed by
`test_radio_preset_packer.py::TestPackPresetRealSpecsEndToEnd` for A-10C's
VHF-first order, and `test_channel_lists.py::TestShippedDefaultMigration` for
A-10C_2's ARC-210, both already merged from tickets 01/07). Documented directly
in `dcs-radio-layouts.yaml`'s header comment (pointing at those two tests) so a
future maintainer does not wonder why they are missing, per this ticket's
acceptance criterion — no code change needed, no entry added.

**Other §4 quirks — no further entries needed.** §4.2's "minor quirks" (A-10C's
trailing empty/AM channels, CH-47F's flat `modulations` table) do not break the
1:1 mapping and are not reproduced as new primitives — they either already work
through the existing per-channel modulation support (ticket 04) or are cosmetic
artifacts of the source data, not layout concerns. §4.3's restricted-band
warbirds/prop/ADF families are validation-only concerns, already fully covered
by `dcs-radio-specs.yaml` + the frequency validator + ticket 05's regression
test — no layout entry warranted.

**Shipped default's CH-47Fbl1 `presets_assignments` override — kept, not
removed.** Verified empirically: the legacy override only ever populates 2
radios (FM then UHF, `modern_blue_fm_uhf`). Packing the new layout entry
against the shipped default's actual declared lists (`primary_1` +
`fm_supplement`, no `fm_substitute`/`fm_secondary`) either produces no radio 1
content at all (if radio 1 is mapped to `fm_substitute`, which the shipped
default never declares) or produces an unwanted 3rd radio (if radio 3 is mapped
to a role that resolves to `fm_supplement`'s list, which the shipped default
DOES declare) — neither reproduces the legacy 2-radio-only result byte-for-byte
without either changing the shipped default's channel_lists shape or adding
per-type content-suppression logic, both out of this ticket's scope. Removing
the override is left as a follow-up once the shipped default itself is
revisited (e.g. if it starts declaring a role vocabulary that naturally leaves
the 3rd radio empty).

**Full-lot regression test.** `test/python/presets_injector/test_radio_preset_full_layout_fidelity.py`
exercises `pack_preset_for_type` against the real bundled `dcs-radio-specs.yaml`
+ `dcs-radio-layouts.yaml` (no mocks) for Mi-24P (rotation), AJS-37 (fusion +
dummy + specials + modulation + exact 47-slot fit), OH-58D (reserved head
slots) and CH-47F (the role fix), confirming all five tickets' primitives still
compose correctly together in the shipped layout file.

---

## FEAT-RADIO-PRESET-PROJECTION-07 — migrate shipped default + docs

Status: ✅ done
Type: feat · Phase: 1 · AFK

### Parent

Lot [FEAT-RADIO-PRESET-PROJECTION](../PRD.md) · [ADR 0010](../../../docs/adr/0010-per-type-radio-preset-projection.md)

### What to build

Migrate the shipped default `presets.yaml` (`src/defaults/mission-folder/src/`) to
the `channel_lists` preset plan so the shipped default demonstrates the new model
(defaults-lockstep, CLAUDE.md §9.7), keeping `channels_collection` as the
frequency source. Update the mission-maker docs (Pipeline Reference §1 and the DCS
radio specs page, FR + EN) to document channel lists, roles, the layout file, and
the manual-override path.

### Acceptance criteria

- [x] Shipped default uses `channel_lists` (a role per radio).
- [x] `channels_collection` unchanged as the frequency source.
- [x] Pipeline Reference FR + EN document the preset plan + override.
- [x] Existing default-scaffold / mission-builder-defaults tests stay green.

### Blocked by

- FEAT-RADIO-PRESET-PROJECTION-01

### Implementation notes

The legacy shipped default assigned the same generic preset (`radio_uhf_30` /
`radio_vhf_30` / `radio_fm_30`, i.e. UHF+VHF+FM) to `blue.plane.all` and
`blue.helicopter.all`, with three explicit `presets_assignments` overrides.
Migrated to `channel_lists.blue`: `primary_1` (was `radio_uhf_30`), `primary_2`
(was `radio_vhf_30`), `fm_supplement` (was `radio_fm_30`) — same 30-channel
lists, verbatim frequencies, now declared once instead of duplicated per
preset. `channels_collection` is untouched.

Verified empirically (`pack_preset_for_type` / `PresetsManager.get_radios_for`
against the real shipped file) for each of the three overrides:

- **`A-10C_2: modern_blue_vhf_uhf_fm` — removed.** The packer's default band
  classification (ticket 01) already resolves `A-10C_2`'s ARC-210 the same way
  it resolves plain `A-10C`: VHF list on physical radio 1, UHF list on radio 2,
  FM on radio 3 — byte-for-byte identical to what the legacy override produced.
  No `presets_assignments` entry needed anymore.
- **`CH-47Fbl1: modern_blue_fm_uhf` — kept.** The legacy preset put only 2
  radios on the CH-47 (FM, then UHF). The packer's default classifies the
  CH-47's 1st physical radio (`VHF FM: ARC-186`, whose range extends into
  108–152 MHz) as VHF-capable rather than FM, so its own default would put the
  VHF list there and add an unwanted 3rd (VHF) radio overall — not what the
  legacy preset produced (FM + UHF only). Kept the explicit override to
  preserve the intended 2-radio layout; noted as a possible packer
  classification edge case below (not fixed here — out of this ticket's scope
  per the "do not touch presets_manager.py" caution).
- **`Mi-8MT: none` — kept as-is.** `none` (disable injection entirely) has no
  `channel_lists` equivalent; this is exactly ADR 0010's manual-override
  escape hatch.
- **Red coalition — kept as-is** (`all: none` for both plane and helicopter).
  No mission-content behaviour change intended by this ticket; git history
  showed no rationale to revisit, so the safe default (unchanged) was kept.

New regression tests added in `test/python/presets_injector/test_channel_lists.py`
(`TestShippedDefaultMigration`) load the real shipped `presets.yaml` via
`PresetsManager.read_yaml` and assert `get_radios_for` reproduces the exact
legacy frequencies/slots for `F-16C_50` (no override, either format), `A-10C_2`
(override dropped), `CH-47Fbl1` (override kept), `Mi-8MT` (explicit `none`
kept), and red coalition (still no injection).

**Possible packer follow-up (not fixed here, flagged for the orchestrating
session's judgement):** the CH-47's `VHF FM: ARC-186` radio spec reports a
108–152 MHz secondary range (an AM navaid/voice band alongside its 30–88 MHz
FM range) that makes `_classify_radio` treat it as `vhf`-capable even though
its module name ("VHF FM") and role are FM-oriented. This is a data/heuristic
edge case in `_classify_radio`'s coarse threshold, not a bug introduced by
this ticket — flagged, not fixed, per this ticket's "do not touch
presets_manager.py" instruction.

---

## FEAT-RADIO-PRESET-PROJECTION-08 — convert-v5 generates a preset plan (phase 2)

Status: ✅ done
Type: feat · Phase: 2 · AFK

### Parent

Lot [FEAT-RADIO-PRESET-PROJECTION](../PRD.md) · [ADR 0010](../../../docs/adr/0010-per-type-radio-preset-projection.md)

### What to build

Make `convert-v5` generate a preset plan by default: read the v5 `radioPresets*`
tables (`RADIO1_*`→`primary_1`, `RADIO2_*`→`primary_2`, `RADIO3_*`→`fm_supplement`,
`RADIO1_H_*`→helicopter `primary_1`, warbird tables as appropriate) and emit
`channel_lists`. When the mission cannot be factored into a single set of lists
(aircraft whose lists diverge, no shared table, unsupported construct), **fall
back** to the faithful per-aircraft copy (ADR 0003 behaviour) and warn which
aircraft fell back and why. This inverts ADR 0003's default.

### Acceptance criteria

- [x] Shared-table v5 file → a `channel_lists` preset plan by default.
- [x] Divergent / unfactorable mission → faithful per-aircraft copy fallback, with
      a clear warning naming the affected aircraft.
- [x] No silent data loss (fidelity preserved on fallback).
- [x] Tests extend `test_v5_pipeline_converters` / `test_presets_fidelity`.

### Blocked by

- FEAT-RADIO-PRESET-PROJECTION-06
- FEAT-RADIO-PRESET-PROJECTION-07

### Implementation notes

- **Radio-number → role convention**, verified empirically against the real
  Tripack fixture (not assumed): `RADIO1_*` → `primary_1`, `RADIO2_*` →
  `primary_2`, `RADIO3_*` → **both** `fm_substitute` and `fm_supplement`
  (`_ROLES_BY_RADIO_NUM`). The mission only declares one shared FM channel
  list; exposing it under both FM role keys lets the packer resolve it
  regardless of which FM role a given airframe's `Radio layout` (or the
  band-based default) assigns — the packer's `_channel_list_for_role` only
  defaults `fm_secondary` to `fm_supplement`, not `fm_substitute`, so without
  this duplication every helicopter-shaped airframe (`fm_substitute`) would
  silently pack an empty FM radio.
- **Factorability check**: for each **bespoke** aircraft (per the existing
  `_entry_is_standard` classifier — unchanged), `convert_presets` now calls
  the phase-1 packer (`pack_preset_for_type`) with the mission's own
  `channel_lists` and compares the result **channel-by-channel and
  radio-by-radio** against the exact v5 map (`_dedicated_matches_packed`,
  `_resolve_dedicated_channels`). Only an **exact** match (same radio count,
  same channel count per radio, same frequency/modulation) drops the legacy
  per-aircraft override; any divergence keeps it, with a warning
  (`convert_v5.warn.preset_plan_fallback`) naming the aircraft. **Standard**
  (1:1) aircraft need no such check — they were always covered by the shared
  assignment before ticket 08, and the plan's channel lists cover them
  identically now (verified in `test_standard_aircraft_fully_covered_by_plan`
  / `test_standard_aircraft_covered_by_plan_gets_no_override`).
- **What falls back, and why, for the real Tripack fixture** — empirically,
  **none** of its four bespoke aircraft factor exactly, despite each having a
  populated phase-1 `Radio layout` entry:
  - **Mi-24P** (both coalitions): the UHF radio's channel-0 rotation matches
    the packer exactly (20/20 channels), but the mission's shared FM channel
    list has 30 entries while the real v5 Mi-24P entry only ever used 10 of
    them — the packer would add 20 phantom channels the aircraft never had.
  - **AJS-37** (both coalitions — a NEW finding beyond phase 1's own
    ground-truth analysis, which only flagged blue's specials as suspect):
    the fused radio needs exactly 47 slots (1 dummy + 20 `primary_1` + 19
    `primary_2` + 7 specials), but the mission's `primary_2` list has 20
    entries — one more than this airframe's real layout consumes. The
    packer's fused radio overflows to 48 slots and shifts every trailing
    special by one position. This is a genuine mismatch between the
    populated `dcs-radio-layouts.yaml` AJS-37 entry (correct per ADR 0010)
    and this specific fixture's authored channel count — not a bug in
    either; the safe fallback is kept rather than adding a 7th primitive or
    guessing.
  - **OH-58D**: already documented in ticket 03's implementation notes as a
    known fixture inconsistency (the raw Tripack data duplicates entry #01
    instead of implementing the ADR-0010 "#20 to head" reserved-slot rule).
  - **CH-47Fbl1**: the fixture feeds VHF-band (`RADIO2_*`) content into the
    Radio layout's declared `fm_substitute` (FM-band) role for radio 1 — a
    band mismatch the packer cannot bridge from `channel_lists` alone.
  - No new (7th) `Radio layout` primitive was added, and
    `dcs-radio-layouts.yaml` / `dcs-radio-specs.yaml` were not modified — per
    the ticket's guardrail, all four fall back to the existing legacy
    mechanism instead.
  - The **mechanism** that drops the override on an exact match IS exercised
    and passes, on a minimal synthetic fixture built specifically to match
    (`test_v5_pipeline_converters.py::TestConvertPresetsPlanGeneration
    ::test_bespoke_aircraft_reproduced_by_packer_gets_no_override`), proving
    the logic is correct even though no aircraft in the real Tripack fixture
    happens to hit that branch.
- **No shared table at all**: `convert_presets` returns its pre-ticket-08
  early-exit warning and writes nothing — zero `channel_lists`, 100% legacy,
  unchanged (`test_no_shared_preset_table_yields_no_channel_lists`).
- **Mixed mode**: `channel_lists` and `presets_assignments` per-aircraft
  overrides coexist in the same `presets.yaml` output whenever at least one
  bespoke aircraft needs the fallback — natural, not all-or-nothing (ADR
  0010: overrides always win over the packer).
- **Test coverage**: `test/python/mission_builder/test_presets_fidelity.py`
  (`TestTripackPresetPlanGeneration`, real Tripack fixture — plan generation,
  standard-aircraft coverage, all four fallbacks, byte-identical legacy
  frequencies, warning content) and
  `test/python/mission_builder/test_v5_pipeline_converters.py`
  (`TestConvertPresetsPlanGeneration`, synthetic fixtures — no-table
  regression, role mapping incl. `fm_supplement`, channel-name exclusion,
  standard-aircraft no-override, and the exact-match no-override mechanism).
  The pre-existing `TestTripackPresetsFidelity` suite (legacy path) passes
  unchanged — none of its assertions were weakened or removed.
