# FDM-001 — add the 10 missing DCS mocks

Status: ✅ done
Type: fix (test infra)
Files: `test/lua/dcs_mocks.lua`

## What to build

Add behavioural stubs for the DCS functions the audit flags as used-but-not-mocked, with
return values matching the VEAF call sites.

## Acceptance criteria

- [x] `land.getClosestPointOnRoads` returns two numbers (echoes the query point)
- [x] `trigger.action.quadToAll` / `radioTransmission` no-op stubs added
- [x] `world.getMarkPanels` returns `{}`, `world.removeJunk` returns `0`
- [x] `world.weather` sub-table with the 5 fog getters/setters
- [x] Full Lua suite passes (`poetry run test-lua`); coverage floor (67) still met
- [x] `poetry run audit-dcs-mocks` reports an empty `missing` gap

## Blocked by

—
