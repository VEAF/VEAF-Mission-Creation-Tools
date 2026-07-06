# Lot FEAT-CONVERTV5-FREQ-ALIASING — replace hardcoded preset freqs with readable aliases

Status: ✅ done
Branch: feat/convertv5-freq-aliasing → PR → develop-v6
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
