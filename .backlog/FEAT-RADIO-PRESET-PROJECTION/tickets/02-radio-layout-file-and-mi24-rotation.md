# FEAT-RADIO-PRESET-PROJECTION-02 — radio layout file + channel-0 rotation (Mi-24P)

Status: ⬜ ready
Type: feat · Phase: 1 · AFK

## Parent

Lot [FEAT-RADIO-PRESET-PROJECTION](../PRD.md) · [ADR 0010](../../../docs/adr/0010-per-type-radio-preset-projection.md)

## What to build

Introduce the hand-maintained `dcs-radio-layouts.yaml` (beside the auto-generated
specs), keyed by type, mapping physical radios by index (with clear comments) to
roles plus primitives. Wire it into the packer as an override of the band-based
default, add the radio-count guard (flag layout/specs drift under `validate`), and
implement the first primitive — **channel-0 rotation** — end-to-end on the Mi-24P
(radio 1 rotates the list's last entry to the head; radio 2 = `fm_substitute`).

Verifiable end-to-end: the Mi-24P shows the rotated channel 0.

## Acceptance criteria

- [ ] `dcs-radio-layouts.yaml` parsed (exact type + regex), radios by index.
- [ ] Layout entry overrides the band-based default for its type.
- [ ] Channel-0 rotation primitive implemented; Mi-24P reproduced.
- [ ] `fm_substitute` role reaches the Mi-24P FM radio.
- [ ] Radio-count guard flags drift under `validate`.
- [ ] Tests (prior art `test_presets_fidelity.py`).

## Blocked by

- FEAT-RADIO-PRESET-PROJECTION-01
