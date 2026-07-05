# FEAT-RADIO-PRESET-PROJECTION-01 — full chain on a standard aircraft

Status: ⬜ ready
Type: feat · Phase: 1 · AFK

## Parent

Lot [FEAT-RADIO-PRESET-PROJECTION](../PRD.md) · [ADR 0010](../../../docs/adr/0010-per-type-radio-preset-projection.md)

## What to build

The founding tracer bullet: the complete path for a standard 1:1 aircraft. Parse
a `channel_lists` block (per coalition, roles `primary_1`/`primary_2`/`fm_*`),
resolve each role to its band from `channels_collection`, deduce the role of each
physical radio from the specs (band-based default, no layout file yet), pack a
`PresetDefinition`, and let the existing injector write `unit["Radio"]`. A channel
lacking the role's band is dropped. An explicit old-format preset assigned to a
type still wins over the packer (manual override, ADR 0010).

Verifiable end-to-end: an F-16 receives its UHF/VHF/FM lists on the right radios;
a type with an explicit override keeps it.

## Acceptance criteria

- [ ] `channel_lists` parsed per coalition into roles; aliases resolve by band.
- [ ] Band-based default maps a standard aircraft's radios to roles from specs.
- [ ] Packer emits a `PresetDefinition`; downstream injection/validation reused.
- [ ] Channel lacking the role's band is dropped (recorded).
- [ ] Explicit old-format assignment wins over the packer.
- [ ] Tests: parsing + a standard aircraft packed end-to-end (prior art
      `test_presets.py`, `test_presets_injector_worker.py`).

## Blocked by

None — can start immediately.
