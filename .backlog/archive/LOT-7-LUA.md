# Lot 7 — LUA FIXES: High-priority bug fixes from issue triage

Status: ✅ done

**Goal**: Fix the most impactful Lua bugs, prioritized from issue triage.
**Branch**: `fix/lua-high-priority` → PR → `develop-v6`
**Depends on**: Lot 4 (LUA-CONFIG — same files, avoid conflicts)

| # | Ticket | Issue | Type | Effort | Status |
|---|--------|-------|------|--------|--------|
| LUA-FIX-001 | Fix `math.atan` wind direction calculation (Lua 5.1 compat) | #287 | fix | 30 min | [x] |
| LUA-FIX-002 | Fix stale DCS object ref in `getNearestAirbaseList` | #302 | fix | 45 min | [x] |
| LUA-FIX-003 | Fix dynamic slots breaking QRA, Radio, AirWaves, Sanctuary, Grass | #293 | fix | 90 min | [x] |
| LUA-FIX-004 | Fix QRA not triggered by dynamic slot aircraft | #299 | fix | 45 min | [x] |
| LUA-FIX-005 | Fix CasMission/CombatZone always using Blue bullseye | #304 | fix | 30 min | [x] |
| LUA-FIX-006 | Update unit list for DCS 2.9.19.13478 new assets | #295, #296 | chore | 60 min | [x] |

**Raw total: 300 min → estimated (×1.15): ~345 min (~5h45)**
