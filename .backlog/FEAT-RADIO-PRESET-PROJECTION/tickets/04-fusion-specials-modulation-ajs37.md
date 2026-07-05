# FEAT-RADIO-PRESET-PROJECTION-04 — radio fusion + hardcoded specials + modulation (AJS-37)

Status: ⬜ ready
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

- [ ] Radio fusion primitive (ordered concatenation of role lists) implemented.
- [ ] Trailing hardcoded specials (freq + mod) appended; overridable by the maker.
- [ ] Per-channel modulation emitted in the `PresetDefinition`.
- [ ] AJS-37 reproduced (dummy + fused lists + specials + modulations).
- [ ] Tests (prior art `test_presets_fidelity.py`).

## Blocked by

- FEAT-RADIO-PRESET-PROJECTION-02 (needs its `dcs-radio-layouts.yaml` file + parser
  + packer-override wiring — corrected from the original "01 only" dependency,
  which assumed that plumbing already existed)
