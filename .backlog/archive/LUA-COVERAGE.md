# Lot LUA-COVERAGE — Lua test-coverage objective for runtime modules

Status: ✅ done

**Goal**: the Lua runtime modules (`veafCasMission`, `veafCombatZone`, `veafQraManager`, …) are far less tested than the Python side. Establish a measurable Lua coverage objective (luacov via `test-lua`), set a baseline gate, and add tests for the least-covered critical modules. Secures the campaign/persistence work that will touch these modules.

**Done (wave 1)**: luacov + the report table were already wired in `test-lua`; the gaps were the **gate** and **CI**. Added `--cov-fail-under FLOAT` to `test-lua` (`_display_coverage_report` now returns the total %; exit 1 when below the floor) with Python tests, and a new `lua-coverage` CI job in `lua-ci.yml` (lua5.1 + luacov via LuaRocks → `poetry run test-lua --cov-fail-under 67`). Baseline measured 68.50 %; floor set to **67** (ratchet — only ever goes up). **Backfill**: `veafUnits` 20.36 % → **93.10 %** (33 tests targeting `placeGroup`/`processGroup`/`findGroup`/`countInfantryAndVehicles`/`removePathfindingFixUnit`/log/trace/initialize), lifting the total to **69.73 %**. A file-scoped `math.random` mock reproduces DCS' permissive reversed-interval behaviour (`placeGroup` L609-610 passes m>n on normal groups; DCS tolerates it, stock Lua 5.1 raises "interval is empty") — a DCS-environment mock, not a bug. **Wave 2+ (separate lots)**: the ~50 % cluster (`Sanctuary`, `CombatMission`, `Skynet*`, `Weather`, `MissileGuardian`, `CombatZone`, `CasMission`, …), raising the floor each pass.

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| LUA-COVERAGE-001 | Coverage gate (`--cov-fail-under` in `test-lua` + `lua-coverage` CI job, floor 67) + `veafUnits` backfill 20→93 % (total 68.50→69.73 %) | `veaf_build/lua_tests.py`, `.github/workflows/lua-ci.yml`, `test/lua/test_veafUnits.lua`, `test/python/veaf_build/test_lua_coverage_gate.py`, `CLAUDE.md` | test | ✅ |

> **Wave 2+ tracked separately**: raising the ~50 %-covered cluster (`Sanctuary`, `CombatMission`, `Skynet*`, `Weather`, `MissileGuardian`, `CombatZone`, `CasMission`, …) and ratcheting the floor up will be its own lot when scheduled.
