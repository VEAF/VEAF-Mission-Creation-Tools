# Lot FIX-DCS-MOCKS-COMPLETION — fill the DCS-mock gaps surfaced by `audit-dcs-mocks`

Status: ✅ done (merged in PR #523)
Branch: `fix/dcs-mocks-completion` (one branch + one PR for the lot)

## Problem Statement

The `audit-dcs-mocks` command (delivered in TOOLING-DCS-MOCK-COVERAGE) reports **10
DCS calls used by `src/scripts/veaf/*.lua` but not defined in `test/lua/dcs_mocks.lua`**.
Each is a latent test gap: a future test loading the calling module would blow up on
`attempt to call a nil value`. Now that we can see them ahead of time, we fix them.

## Solution

Add behavioural stubs for the 10 missing DCS functions, matching how the VEAF callers
use the return values (verified against the call sites and the vendored schema):

- `land.getClosestPointOnRoads(roadType, x, z)` — callers do `road_x, road_z = …`, so it
  returns **two numbers**; the stub echoes the query point `(x, z)`.
- `trigger.action.quadToAll(...)`, `trigger.action.radioTransmission(...)` — side-effect
  only, no-op stubs.
- `world.getMarkPanels()` — iterated with `pairs`, returns `{}`.
- `world.removeJunk(searchVolume)` — used as a count, returns `0`.
- `world.weather.{getFogThickness,getFogVisibilityDistance}()` — numeric getters, return `0`.
- `world.weather.{setFogAnimation,setFogThickness,setFogVisibilityDistance}(...)` — setters,
  no-op stubs. (`world.weather` is a new sub-table in the mock.)

## Testing Decisions

- No new Lua test is required: the change is to the shared mock fixture. Validation is that
  the full Lua suite still passes and `audit-dcs-mocks` now reports an **empty** gap.

## Out of Scope

- A CI ratchet that *fails* on new gaps (the audit job stays non-blocking — a later option).
- The informational `unknown` / `unused` audit buckets (instance methods called statically,
  preventive stubs not yet exercised) — not gaps.

---

## FDM-001 — add the 10 missing DCS mocks

Status: ✅ done
Type: fix (test infra)
Files: `test/lua/dcs_mocks.lua`

### What to build

Add behavioural stubs for the DCS functions the audit flags as used-but-not-mocked, with
return values matching the VEAF call sites.

### Acceptance criteria

- [x] `land.getClosestPointOnRoads` returns two numbers (echoes the query point)
- [x] `trigger.action.quadToAll` / `radioTransmission` no-op stubs added
- [x] `world.getMarkPanels` returns `{}`, `world.removeJunk` returns `0`
- [x] `world.weather` sub-table with the 5 fog getters/setters
- [x] Full Lua suite passes (`poetry run test-lua`); coverage floor (67) still met
- [x] `poetry run audit-dcs-mocks` reports an empty `missing` gap

### Blocked by

—
