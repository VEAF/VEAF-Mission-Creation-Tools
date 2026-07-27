# Lot FIX-CTLD-NIL — nil crash on ctld.builtFOBS / ctld.logisticUnits in scheduled fns

Status: ✅ done

**Goal**: Fix `bad argument #1 to 'insert' (table expected, got nil)` crash in MIST scheduled functions when CTLD module table exists but its internal lists haven't been initialized yet (race condition on mission start).

**Root cause**: Three call sites guard only against `ctld` being falsy, but `ctld.builtFOBS` and `ctld.logisticUnits` are `nil` until `ctld.initialize()` runs. If a scheduled function fires before CTLD init completes, `table.insert` crashes.

| Site | File | Issue |
|------|------|-------|
| `veafGrass.lua:1003` | `if ctld then` | `ctld.builtFOBS` / `ctld.logisticUnits` may be nil |
| `veafSpawnGround.lua:182` | no guard | immediate crash if ctld not init |
| `veafSpawnEffects.lua:32` | `if ctld then` | `ctld.logisticUnits` may be nil |

**Fix**: extend all three guards to `if ctld and ctld.builtFOBS and ctld.logisticUnits then` (or equivalent per site).

**Branch**: `fix/ctld-nil` → PR → `develop`

| # | Ticket | Files | Type | Effort | Status |
|---|--------|-------|------|--------|--------|
| CTLD-001 | Extend ctld guard in `veafGrass.lua` (~line 1003) | `src/scripts/veaf/veafGrass.lua` | fix | 5 min | ✅ |
| CTLD-002 | Add ctld guard in `veafSpawnGround.lua` (~line 182) | `src/scripts/veaf/veafSpawnGround.lua` | fix | 5 min | ✅ |
| CTLD-003 | Extend ctld guard in `veafSpawnEffects.lua` (~line 32) | `src/scripts/veaf/veafSpawnEffects.lua` | fix | 5 min | ✅ |
