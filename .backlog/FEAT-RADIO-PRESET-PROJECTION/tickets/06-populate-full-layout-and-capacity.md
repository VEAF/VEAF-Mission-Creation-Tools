# FEAT-RADIO-PRESET-PROJECTION-06 — populate the full layout + capacity/truncation

Status: ⬜ ready
Type: feat · Phase: 1 · AFK

## Parent

Lot [FEAT-RADIO-PRESET-PROJECTION](../PRD.md) · [ADR 0010](../../../docs/adr/0010-per-type-radio-preset-projection.md)

## What to build

With every primitive available, populate `dcs-radio-layouts.yaml` for the
remaining non-trivial types in the reference Tripack fixture (A-10 with the
deliberate VHF-on-radio-1 order, CH-47F, and any other quirk from §4 of the
analysis), and implement the **slot capacity** primitive with truncation when a
list exceeds a radio's capacity (recorded; verbose under `validate`, silent under
`build`). Band-only types are deliberately left to the default and documented as
such.

## Acceptance criteria

- [ ] Every non-trivial fixture type has a layout entry (A-10, CH-47F, …).
- [ ] Slot capacity + truncation implemented and reported.
- [ ] Band-only types documented as intentionally default.
- [ ] Radio-count guard passes for all populated entries.
- [ ] A test asserts the populated layout reproduces the fixture for the headline
      types.

## Blocked by

- FEAT-RADIO-PRESET-PROJECTION-02
- FEAT-RADIO-PRESET-PROJECTION-03
- FEAT-RADIO-PRESET-PROJECTION-04
- FEAT-RADIO-PRESET-PROJECTION-05
