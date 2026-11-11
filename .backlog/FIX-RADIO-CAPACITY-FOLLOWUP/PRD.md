# FIX-RADIO-CAPACITY-FOLLOWUP — The manual assignment path is capped, and truncation warns once per build

Status: 🔄 in-progress

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
| 01 | [Cap the manual assignment path](tickets/01-cap-assignments.md) | ⬜ |
| 02 | [One summary warning per build](tickets/02-summary-warning.md) | ⬜ |

Python, TDD. One branch, one PR.
