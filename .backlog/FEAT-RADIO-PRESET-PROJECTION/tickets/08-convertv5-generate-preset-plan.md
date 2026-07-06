# FEAT-RADIO-PRESET-PROJECTION-08 — convert-v5 generates a preset plan (phase 2)

Status: ✅ done
Type: feat · Phase: 2 · AFK

## Parent

Lot [FEAT-RADIO-PRESET-PROJECTION](../PRD.md) · [ADR 0010](../../../docs/adr/0010-per-type-radio-preset-projection.md)

## What to build

Make `convert-v5` generate a preset plan by default: read the v5 `radioPresets*`
tables (`RADIO1_*`→`primary_1`, `RADIO2_*`→`primary_2`, `RADIO3_*`→`fm_supplement`,
`RADIO1_H_*`→helicopter `primary_1`, warbird tables as appropriate) and emit
`channel_lists`. When the mission cannot be factored into a single set of lists
(aircraft whose lists diverge, no shared table, unsupported construct), **fall
back** to the faithful per-aircraft copy (ADR 0003 behaviour) and warn which
aircraft fell back and why. This inverts ADR 0003's default.

## Acceptance criteria

- [x] Shared-table v5 file → a `channel_lists` preset plan by default.
- [x] Divergent / unfactorable mission → faithful per-aircraft copy fallback, with
      a clear warning naming the affected aircraft.
- [x] No silent data loss (fidelity preserved on fallback).
- [x] Tests extend `test_v5_pipeline_converters` / `test_presets_fidelity`.

## Blocked by

- FEAT-RADIO-PRESET-PROJECTION-06
- FEAT-RADIO-PRESET-PROJECTION-07

## Implementation notes

- **Radio-number → role convention**, verified empirically against the real
  Tripack fixture (not assumed): `RADIO1_*` → `primary_1`, `RADIO2_*` →
  `primary_2`, `RADIO3_*` → **both** `fm_substitute` and `fm_supplement`
  (`_ROLES_BY_RADIO_NUM`). The mission only declares one shared FM channel
  list; exposing it under both FM role keys lets the packer resolve it
  regardless of which FM role a given airframe's `Radio layout` (or the
  band-based default) assigns — the packer's `_channel_list_for_role` only
  defaults `fm_secondary` to `fm_supplement`, not `fm_substitute`, so without
  this duplication every helicopter-shaped airframe (`fm_substitute`) would
  silently pack an empty FM radio.
- **Factorability check**: for each **bespoke** aircraft (per the existing
  `_entry_is_standard` classifier — unchanged), `convert_presets` now calls
  the phase-1 packer (`pack_preset_for_type`) with the mission's own
  `channel_lists` and compares the result **channel-by-channel and
  radio-by-radio** against the exact v5 map (`_dedicated_matches_packed`,
  `_resolve_dedicated_channels`). Only an **exact** match (same radio count,
  same channel count per radio, same frequency/modulation) drops the legacy
  per-aircraft override; any divergence keeps it, with a warning
  (`convert_v5.warn.preset_plan_fallback`) naming the aircraft. **Standard**
  (1:1) aircraft need no such check — they were always covered by the shared
  assignment before ticket 08, and the plan's channel lists cover them
  identically now (verified in `test_standard_aircraft_fully_covered_by_plan`
  / `test_standard_aircraft_covered_by_plan_gets_no_override`).
- **What falls back, and why, for the real Tripack fixture** — empirically,
  **none** of its four bespoke aircraft factor exactly, despite each having a
  populated phase-1 `Radio layout` entry:
  - **Mi-24P** (both coalitions): the UHF radio's channel-0 rotation matches
    the packer exactly (20/20 channels), but the mission's shared FM channel
    list has 30 entries while the real v5 Mi-24P entry only ever used 10 of
    them — the packer would add 20 phantom channels the aircraft never had.
  - **AJS-37** (both coalitions — a NEW finding beyond phase 1's own
    ground-truth analysis, which only flagged blue's specials as suspect):
    the fused radio needs exactly 47 slots (1 dummy + 20 `primary_1` + 19
    `primary_2` + 7 specials), but the mission's `primary_2` list has 20
    entries — one more than this airframe's real layout consumes. The
    packer's fused radio overflows to 48 slots and shifts every trailing
    special by one position. This is a genuine mismatch between the
    populated `dcs-radio-layouts.yaml` AJS-37 entry (correct per ADR 0010)
    and this specific fixture's authored channel count — not a bug in
    either; the safe fallback is kept rather than adding a 7th primitive or
    guessing.
  - **OH-58D**: already documented in ticket 03's implementation notes as a
    known fixture inconsistency (the raw Tripack data duplicates entry #01
    instead of implementing the ADR-0010 "#20 to head" reserved-slot rule).
  - **CH-47Fbl1**: the fixture feeds VHF-band (`RADIO2_*`) content into the
    Radio layout's declared `fm_substitute` (FM-band) role for radio 1 — a
    band mismatch the packer cannot bridge from `channel_lists` alone.
  - No new (7th) `Radio layout` primitive was added, and
    `dcs-radio-layouts.yaml` / `dcs-radio-specs.yaml` were not modified — per
    the ticket's guardrail, all four fall back to the existing legacy
    mechanism instead.
  - The **mechanism** that drops the override on an exact match IS exercised
    and passes, on a minimal synthetic fixture built specifically to match
    (`test_v5_pipeline_converters.py::TestConvertPresetsPlanGeneration
    ::test_bespoke_aircraft_reproduced_by_packer_gets_no_override`), proving
    the logic is correct even though no aircraft in the real Tripack fixture
    happens to hit that branch.
- **No shared table at all**: `convert_presets` returns its pre-ticket-08
  early-exit warning and writes nothing — zero `channel_lists`, 100% legacy,
  unchanged (`test_no_shared_preset_table_yields_no_channel_lists`).
- **Mixed mode**: `channel_lists` and `presets_assignments` per-aircraft
  overrides coexist in the same `presets.yaml` output whenever at least one
  bespoke aircraft needs the fallback — natural, not all-or-nothing (ADR
  0010: overrides always win over the packer).
- **Test coverage**: `test/python/mission_builder/test_presets_fidelity.py`
  (`TestTripackPresetPlanGeneration`, real Tripack fixture — plan generation,
  standard-aircraft coverage, all four fallbacks, byte-identical legacy
  frequencies, warning content) and
  `test/python/mission_builder/test_v5_pipeline_converters.py`
  (`TestConvertPresetsPlanGeneration`, synthetic fixtures — no-table
  regression, role mapping incl. `fm_supplement`, channel-name exclusion,
  standard-aircraft no-override, and the exact-match no-override mechanism).
  The pre-existing `TestTripackPresetsFidelity` suite (legacy path) passes
  unchanged — none of its assertions were weakened or removed.
