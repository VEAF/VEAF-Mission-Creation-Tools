# Lot FEAT-CONVERTV5-FREQ-ALIASING — replace hardcoded preset freqs with readable aliases

Status: ✅ done
Branch: feat/convertv5-freq-aliasing → PR → develop
ADR: extends [0010](../../docs/adr/0010-per-type-radio-preset-projection.md)

> Lot 3/3 of the convert-v5 preset-aliasing plan. Needs
> [FEAT-AIRFIELD-FREQS-DATA](../FEAT-AIRFIELD-FREQS-DATA/PRD.md) (lot 2) merged;
> lot 1 (FEAT-CONVERTV5-PLAN-PRESETS, ADR 0010) is done.

## Problem Statement

Even with the preset plan (lot 1), `convert-v5`'s `presets.yaml` still lists **raw
frequencies** (`260`, `390`, …) instead of readable **aliases** (`Gudauta`, `Archer`).
The mission-maker can't tell what a channel is for. VEAF already names these — airfields
(Gudauta…) by their real DCS ATC freqs, and flight/tactical channels (Guard, Magic,
Archer, Texaco-1…) by **VEAF conventions absent from DCS**.

## Solution

At conversion, insert a channel catalog and replace matched raw frequencies with named
aliases in the **build-loaded plan** (`presets.yaml`). **Revised decision**: the
faithful copy (`presets.v5.yaml`) is left **byte-identical / raw** — its whole point is
to be an iso-functional rollback reference (ADR 0003), so aliasing only the plan (the
file makers actually read/load) keeps that invariant intact. The legacy no-plan case
(single file, no `channel_lists`) is also left unchanged.

- Detect the theatre from the `.miz` (`theatre`).
- Load the **generic VEAF catalog** (tactical/flights: Guard/Magic/Archer/Texaco… —
  VEAF conventions) **+ the theatre's airfields** (from `airfield-frequencies.yaml`,
  lot 2).
- **Reverse-lookup `freq + band → alias`**; replace a matched channel frequency with
  its alias; insert the catalog (`channels_collection`) so the aliases resolve.
- A frequency with **no catalog match stays hardcoded**.

Plus a **type-aliasing annex** (Tripack's AH-64D case): a small explicit type-alias
table so the packer resolves DCS name mismatches and projects the aircraft instead of
leaving a residual override.

## Decisions (validated by David)

- Airfields come from the **bundled** data (lot 2); flight/tactical aliases from a
  **maintained generic VEAF catalog** (VEAF conventions, not DCS data).
- Reverse-lookup keyed by **frequency + band**; unmatched → left hardcoded.
- Specials/fusions: **option (a)** — packer best-effort, no override (confirmed).
- **Type aliasing via an explicit table, not a regex**: `get_radios` / `is_strict` /
  `get_valid_ranges` do an exact `specs.get(unit_type)` and gate before layouts, so a
  regex layout key cannot help; an explicit alias table applied at that lookup is the
  fix.

## Scope

- **Ticket 01** — the generic VEAF alias catalog (tactical/flights conventions:
  Guard/Magic/Archer/Texaco…) as maintained data, keyed by `freq + band`.
- **Ticket 02** — theatre detection + reverse-lookup (`freq+band → alias`) + catalog
  insertion + frequency→alias replacement across both files; unmatched kept raw. Tests.
- **Ticket 03** — aircraft **type-alias table** (`AH-64D → AH-64D_BLK_II`) applied to
  `get_radios` / `is_strict` / `get_valid_ranges` (`radio_frequency_validator`), so the
  aircraft is projected automatically instead of remaining a residual override. Tests.

## Out of scope

- Airfield data extraction — lot 2.
- Changing the preset plan model / packer projection logic (ADR 0010) beyond the
  type-alias lookup.
- A frequency→alias reverse-lookup for arbitrary user missions at build time (this lot
  is convert-v5-only; the build still consumes explicit aliases).

---

## 01 — Generic VEAF alias catalog (tactical / flights)

Status: ✅ done
Type: feat

### Context

Flight and tactical channels (Guard, Magic, Archer, Nickel, Texaco-1, Shell-1…) are
**VEAF conventions**, not DCS data — they must be maintained by VEAF. Today they live
inline in the shipped default `presets.yaml` `channels_collection`
(`tactical`/`flights` groups). Lot 3 needs them as a reusable catalog keyed for
reverse-lookup.

### Tasks

- [ ] Extract / define the generic VEAF alias catalog (tactical + flights) as
      maintained data, reusing the values already in the default `presets.yaml`
      (Guard 243/121.5, Archer vhf 120 / uhf 390, Texaco-1 uhf 290.1, …).
- [ ] Build a reverse index `(band, freq) → alias` from it (plus a forward
      `alias → {band: freq}` for emission), with a clear precedence when two aliases
      share a frequency.
- [ ] Unit tests: a few known lookups (Guard/uhf → Guard, 390/uhf → Archer…).

### Definition of Done

- Catalog + reverse index available to the converter; unit-tested.
- No behaviour change yet (data + lookup only); `ruff`/`mypy`/`pytest` green.

---

## 02 — Theatre-aware freq→alias replacement in convert-v5 output

Status: ✅ done
Type: feat

### Context

The core of the lot: turn raw frequencies in the converted presets into readable
aliases, using the VEAF catalog (ticket 01) + the theatre's airfields (lot 2,
`airfield-frequencies.yaml`).

### Tasks (TDD)

- [ ] Detect the theatre from the `.miz` (`theatre`); load the theatre's airfield
      frequencies (lot 2) and merge with the generic VEAF catalog (ticket 01) into one
      reverse index `(band, freq) → alias`.
- [ ] For each channel frequency in the converted presets, reverse-lookup by
      `freq + band`; on a match, replace the raw frequency with the alias reference.
      **Unmatched frequency → left hardcoded** (test this explicitly).
- [ ] Insert the resolved catalog (`channels_collection`) into **both** `presets.yaml`
      and `presets.v5.yaml` so the aliases resolve at build time.
- [ ] Specials/fusions: option (a) — packer best-effort, no override.
- [ ] Failing tests first: a converted preset with a Gudauta-matching freq becomes
      `Gudauta`; an Archer-matching freq becomes `Archer`; an off-catalog freq stays raw.

### Definition of Done

- Converted `presets.yaml`/`presets.v5.yaml` carry aliases where matched, raw
  frequencies otherwise; catalog embedded so the build resolves them.
- Round-trip: the aliased output still builds to the same channels as before aliasing.
- `ruff`/`mypy`/`pytest` green; coverage gate respected; doc updated (convert-v5 /
  presets reference) if user-facing output changes.

---

## 03 — Aircraft type-alias table (packer name-mismatch resolution)

Status: ✅ done
Type: feat

### Context

The packer resolves an aircraft's physical radios by an **exact** `specs.get(unit_type)`
(`radio_frequency_validator.get_radios`, l.87), which gates before layouts/assignments
(`_resolved_slots_for_type`: `radios = get_radios(...)` → `None` skips projection).
When a mission uses a DCS type name that differs from the specs key — e.g. `AH-64D`
(mission) vs `AH-64D_BLK_II` (specs) — the aircraft can't be projected and falls back
to a manual override in `presets.v5.yaml`. A regex **layout** key does not help because
`get_radios` returns `None` first. (Distinct from the T-45, a third-party mod absent
from the specs → a permanent override, not a name mismatch.)

### Tasks (TDD)

- [ ] Add a small explicit **type-alias table** (`{"AH-64D": "AH-64D_BLK_II", …}`) as
      maintained data.
- [ ] Apply it as normalisation at the exact-lookup sites in
      `radio_frequency_validator`: `get_radios`, `is_strict`, `get_valid_ranges`
      (resolve the alias before `specs.get(...)`). Keep it one shared normaliser.
- [ ] Failing test first: `get_radios("AH-64D")` now returns the `AH-64D_BLK_II` radios;
      an unaliased/unknown type still returns `None`.
- [ ] Verify the AH-64D is projected by the packer (no longer a residual override) via
      an end-to-end packer test.

### Definition of Done

- The aliased type projects automatically; regression test proves it.
- `ruff`/`mypy`/`pytest` green (validator is not in the mypy ignore list — keep clean).
