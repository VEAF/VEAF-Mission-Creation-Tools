# 03 — Aircraft type-alias table (packer name-mismatch resolution)

Status: ⬜ ready
Type: feat

## Context

The packer resolves an aircraft's physical radios by an **exact** `specs.get(unit_type)`
(`radio_frequency_validator.get_radios`, l.87), which gates before layouts/assignments
(`_resolved_slots_for_type`: `radios = get_radios(...)` → `None` skips projection).
When a mission uses a DCS type name that differs from the specs key — e.g. `AH-64D`
(mission) vs `AH-64D_BLK_II` (specs) — the aircraft can't be projected and falls back
to a manual override in `presets.v5.yaml`. A regex **layout** key does not help because
`get_radios` returns `None` first. (Distinct from the T-45, a third-party mod absent
from the specs → a permanent override, not a name mismatch.)

## Tasks (TDD)

- [ ] Add a small explicit **type-alias table** (`{"AH-64D": "AH-64D_BLK_II", …}`) as
      maintained data.
- [ ] Apply it as normalisation at the exact-lookup sites in
      `radio_frequency_validator`: `get_radios`, `is_strict`, `get_valid_ranges`
      (resolve the alias before `specs.get(...)`). Keep it one shared normaliser.
- [ ] Failing test first: `get_radios("AH-64D")` now returns the `AH-64D_BLK_II` radios;
      an unaliased/unknown type still returns `None`.
- [ ] Verify the AH-64D is projected by the packer (no longer a residual override) via
      an end-to-end packer test.

## Definition of Done

- The aliased type projects automatically; regression test proves it.
- `ruff`/`mypy`/`pytest` green (validator is not in the mypy ignore list — keep clean).
