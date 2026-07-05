# FEAT-RADIO-PRESET-PROJECTION-05 — warbirds on primary_2 + out-of-band drop

Status: ⬜ ready
Type: feat · Phase: 1 · AFK

## Parent

Lot [FEAT-RADIO-PRESET-PROJECTION](../PRD.md) · [ADR 0010](../../../docs/adr/0010-per-type-radio-preset-projection.md)

## What to build

Pack the warbirds' single radio on `primary_2` (VHF) and make the out-of-band
**drop** behaviour explicit: channels outside the type's specs band are dropped
from the list, explained under `validate` (verbose) and silent under `build` —
reusing the existing frequency validator and report split. Demonstrate end-to-end
on a warbird (e.g. P-51D receives the airbase VHF channels that fall in its band;
UHF-only channels are dropped).

Note: whether the module truly accepts airbase VHF in game is out of scope (the
38–156 band is datamined) — see PRD Out of Scope; this slice implements the
tooling behaviour, in-game confirmation is a separate follow-up.

## Acceptance criteria

- [ ] Warbird single radio packed on `primary_2`.
- [ ] Out-of-band channels dropped; reported under `validate`, silent under `build`.
- [ ] Tests: a warbird packs its in-band VHF and drops the rest (prior art
      `test_radio_frequency_validator.py`, `test_presets_fidelity.py`).

## Blocked by

- FEAT-RADIO-PRESET-PROJECTION-01
