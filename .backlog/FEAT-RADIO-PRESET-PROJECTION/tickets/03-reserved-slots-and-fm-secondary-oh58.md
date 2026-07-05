# FEAT-RADIO-PRESET-PROJECTION-03 — reserved head slots + fm_secondary (OH-58D)

Status: ⬜ ready
Type: feat · Phase: 1 · AFK

## Parent

Lot [FEAT-RADIO-PRESET-PROJECTION](../PRD.md) · [ADR 0010](../../../docs/adr/0010-per-type-radio-preset-projection.md)

## What to build

Implement the **reserved head slot(s)** primitive (default fill = the list's last
entry #20; the OH-58D FM adds a second head slot filled from #01), and the
`fm_secondary` role (defaults to a copy of `fm_supplement` when the mission-maker
does not define it). Demonstrate end-to-end on the OH-58D: UHF/VHF radios get a
reserved "M" head slot; FM1/FM2 get "C"+"M" head slots; the two FM radios receive
`fm_supplement` and `fm_secondary`.

Verifiable end-to-end: the OH-58D's "no channel 1" layout is reproduced.

## Acceptance criteria

- [ ] Reserved head slot primitive (count + fill entry) implemented.
- [ ] `fm_secondary` role; absent → copy of `fm_supplement`.
- [ ] OH-58D reproduced: M/C head slots on the right radios.
- [ ] Tests (prior art `test_presets_fidelity.py`).

## Blocked by

- FEAT-RADIO-PRESET-PROJECTION-01
