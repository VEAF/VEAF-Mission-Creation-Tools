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

- FEAT-RADIO-PRESET-PROJECTION-01 only — does NOT need ticket 02's layout file:
  warbirds already pack onto `primary_2` by default under ticket 01's
  band-classification (a single-range radio spanning both the FM ceiling and the
  UHF floor resolves to "vhf", see `_classify_radio` and
  `test_warbird_single_radio_resolves_to_primary_2`). No layout entry needed.

## Note

The "pack on primary_2" acceptance criterion is already satisfied by ticket 01.
This ticket's real remaining scope is the **out-of-band drop reporting split**
(verbose under `validate`, silent under `build`) — check whether that mode
distinction already exists in the `validate`/`build` commands or needs adding.
