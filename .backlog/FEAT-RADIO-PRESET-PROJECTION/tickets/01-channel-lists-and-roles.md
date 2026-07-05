# FEAT-RADIO-PRESET-PROJECTION-01 — radio roles + channel_lists parsing

Status: ⬜ ready
Type: feat
Phase: 1
Files: `presets_injector/presets_manager.py`, `test/python/presets_injector/`

## What to build

Introduce the fixed _Radio role_ vocabulary (`primary_1`, `primary_2`,
`fm_substitute`, `fm_supplement`, `fm_secondary`) and parse a new `channel_lists`
block from `presets.yaml`: per coalition, each role an ordered list of channel
aliases / literals / `{freq, mod}`, resolved against `channels_collection` using
the role's band (primary_1→uhf, primary_2→vhf, fm_*→fm). A channel with no
frequency for the role's band is dropped from the list (recorded for reporting).
`fm_secondary` defaults to a copy of `fm_supplement` when absent.

## Acceptance criteria

- [ ] The five roles are defined with their resolution band.
- [ ] `channel_lists` parses per coalition into role→ordered-channels structures.
- [ ] Aliases resolve to the role's band; literals and `{freq, mod}` supported.
- [ ] A channel lacking the role's band is dropped and the drop is recorded.
- [ ] `fm_secondary` absent → resolves to a copy of `fm_supplement`.
- [ ] Unit tests (prior art: `test_presets.py`).

## Blocked by

None — can start immediately.
