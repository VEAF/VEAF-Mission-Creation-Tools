# FIX-RADIO-CAPACITY-FOLLOWUP — The manual assignment path is capped, and truncation warns once per build

Status: ✅ done

Follow-up of FEAT-RADIO-CAPACITY-ALL-TYPES (#1263), agreed by David on 2026-11-11 ("ok, on fait ta reco").

## What #1263 left

1. **The `presets_assignments` path is not capped.** The shipped defaults' blue CH-47F gets the 30-entry `radio_fm_30` list through it, on a radio that holds 20 — the situation that crashed the OH-58D's client. Whether the Chinook crashes is not known.
2. **A build from the defaults raises 29 capacity warnings**, one per truncated radio: the shared role lists are longer than the small radios (warbirds 4–6 channels, Mosquito, MiG-19P, AH-64D 10, F-4E and F-86 18). An OT build raises 32 to 66.

## Decisions — 2026-11-11

| # | Question | Decision |
|---|---|---|
| D1 | The manual path | The radios written through `presets_assignments` are capped by the same capacities, with the same truncation by slot. The `radio_fm_30` list itself is **not** changed: only the first 20 reach the CH-47F's radio |
| D2 | The warning | **One summary warning per build**, listing the truncated type / radio pairs with their capacity and dropped count, instead of one line per radio. The per-radio detail stays at debug level |
| D3 | No other change | A mission whose lists fit is byte-for-byte unchanged (the #1263 test still holds) |

## Tickets

| # | Ticket | Status |
|---|---|---|
| 01 | [Cap the manual assignment path](tickets/01-cap-assignments.md) | ✅ |
| 02 | [One summary warning per build](tickets/02-summary-warning.md) | ✅ |

Python, TDD. One branch, one PR.

## Outcome — 2026-11-11

### D1 — the manual path is capped

`get_radios_for` passes a `presets_assignments` preset through `_cap_preset_to_capacity`: its radios map to the physical radios in order (as `PresetDefinition.to_dict` writes them), each is cut by slot at its capacity (the layout's, else the module's), and a cut radio is a copy, so the shared collection is never touched. A preset that fits, `none` and an unknown type (`all`) come back as they are.
The shipped blue CH-47F gets slots 1-20 of `radio_fm_30`; the list in `presets.yaml` and in the loaded collection still holds 30 (tested).

### D2 — one summary warning

`_truncate_to_capacity` records each truncation as (type, radio, capacity, dropped) in the build's set and logs the per-radio line at debug; outside a build (no set) it still warns on the spot. `log_capacity_truncations` logs one warning listing them, sorted, in fr and en; the presets worker calls it once after its groups, convert-v5 once after its comparison pass.
**Measured on the 122 (coalition, type) pairs of the shipped templates: one warning, listing 30 radios** — the 29 of #1263 plus the CH-47F's radio 1, now cut from 30 to 20.

### D3

The #1263 test `test_the_shipped_defaults_change_only_by_the_cut` still passes; a fitting manual preset is the same object.

### Known limitations

`radio-capacity-not-applied-to-manual-presets` gets `fixed_in: 6.37.0`; its La-7 / MiG-15bis half, not fixed, becomes `radio-capacity-unknown-for-overlay-radios`. Both are `kind: tool`, which `dcs-runtime-traps.md` does not list: regenerating it changed nothing.
