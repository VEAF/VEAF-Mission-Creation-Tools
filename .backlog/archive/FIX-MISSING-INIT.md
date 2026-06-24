# Lot FIX-MISSING-INIT — missing `initialize()` on 4 Lua modules

Status: ✅ done

**Goal**: Fix DCS runtime crashes `attempt to call field 'initialize' (a nil value)` on modules not yet covered.

**Context**: The Python build (`lua_config_generator.py`) generates an `<module>.initialize()` call for all modules listed in `_MODULE_INIT_ORDER`. A full audit revealed 4 modules missing this function: `veafCacheManager`, `veafTime`, `veafUnits`, `veafSkynetIadsMonitor`.

**Branch**: `fix/missing-initialize-fns` → PR → `develop-v6`

| # | Ticket | Files | Type | Effort | Status |
|---|--------|-------|------|--------|--------|
| MISSING-INIT-001 | Add `initialize()` to `veafCacheManager.lua` | `src/scripts/veaf/veafCacheManager.lua` | fix | 5 min | ✅ |
| MISSING-INIT-002 | Add `initialize()` to `veafTime.lua` | `src/scripts/veaf/veafTime.lua` | fix | 5 min | ✅ |
| MISSING-INIT-003 | Add `initialize()` to `veafUnits.lua` | `src/scripts/veaf/veafUnits.lua` | fix | 5 min | ✅ |
| MISSING-INIT-004 | Add `initialize()` to `veafSkynetIadsMonitor.lua` | `src/scripts/veaf/veafSkynetIadsMonitor.lua` | fix | 5 min | ✅ |
