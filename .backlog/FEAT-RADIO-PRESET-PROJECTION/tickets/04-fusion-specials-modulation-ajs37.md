# FEAT-RADIO-PRESET-PROJECTION-04 — radio fusion + hardcoded specials + modulation (AJS-37)

Status: ✅ done
Type: feat · Phase: 1 · AFK

## Parent

Lot [FEAT-RADIO-PRESET-PROJECTION](../PRD.md) · [ADR 0010](../../../docs/adr/0010-per-type-radio-preset-projection.md)

## What to build

Implement the remaining primitives — **radio fusion** (concatenate several role
lists into one physical radio), **trailing hardcoded specials** (constant
frequencies + modulations appended after the lists), and **per-channel
modulation** — end-to-end on the AJS-37: its single V/UHF radio fuses `primary_1`
+ `primary_2` behind a leading dummy, then the FR22/FR24 special channels
(including GUARD), with the AM/FM modulation map preserved.

Verifiable end-to-end: the AJS-37's fused radio with dummy, specials and
modulations is reproduced.

## Acceptance criteria

- [x] Radio fusion primitive (ordered concatenation of role lists) implemented.
- [x] Trailing hardcoded specials (freq + mod) appended; overridable by the maker.
- [x] Per-channel modulation emitted in the `PresetDefinition`.
- [x] AJS-37 reproduced (dummy + fused lists + specials + modulations).
- [x] Tests (prior art `test_presets_fidelity.py`).

## Blocked by

- FEAT-RADIO-PRESET-PROJECTION-02 (needs its `dcs-radio-layouts.yaml` file + parser
  + packer-override wiring — corrected from the original "01 only" dependency,
  which assumed that plumbing already existed)

## Implementation notes

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
