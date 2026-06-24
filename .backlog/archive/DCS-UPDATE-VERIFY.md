# Lot DCS-UPDATE-VERIFY — post-DCS-update verification campaign

Status: ✅ done

**Goal**: a DCS World update landed; re-verify the maximum of things the toolchain depends on — every DCS-derived datum **and** the in-game runtime behaviour — and journal each check (remark → analysis → fix) in `TEST-PLAN-DCS-UPDATE.md`. Key insight: almost all DCS data comes from the **Quaggles datamine** at a pinned `DATAMINE_REF` (not the local DCS install), so a DCS update does **not** auto-change our data — only a datamine bump does. Only **airdromes** (`airdromes.yaml`, from `Mods/terrains/<map>/Beacons.lua`) depend on the local install and are **not** CI-guarded. Single branch, single PR at the end if fixes are produced.

**Branch**: `feature/dcs-update-verify` → PR → `develop-v6`

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| DCS-VERIFY-D1 | Datamine drift check: pinned `DATAMINE_REF` vs upstream HEAD | `veaf_build/dcs_data/datamine.py` | chore | ✅ |
| DCS-VERIFY-D2 | Regenerate countries + units at the pinned ref, assert no drift from committed data | `veaf_libs/data/`, `src/scripts/veaf/dcsUnits.lua` | chore | ✅ |
| DCS-VERIFY-D3 | Regenerate airdromes from the updated local DCS install; verify dynamic-slot warehouse name→id wiring | `veaf_libs/data/airdromes.yaml` | chore | ✅ (+6 Syria airfields) |
| DCS-VERIFY-D4 | Regenerate radio specs + re-apply `dcs_rejects_on_load` overlays (only if datamine bumped) | `presets_injector/data/dcs-radio-specs.yaml` | chore | ⬜ (deferred) |
| DCS-VERIFY-D5 | Run all DCS-data tests | `test/python/veaf_build/`, `test/python/veaf_libs/` | test | ✅ |
| DCS-VERIFY-R3-BUG | Static bundle dropped `veafSpawnParser.lua` (spawn-refactor regression) → `_cas`/`_spawn` parsing broke in static (`convertLaserToFreq` nil). Added it to the bundle list; extracted `LUA_BUNDLE_SCRIPTS`/`LUA_BUNDLE_EXCLUDED`; manifest-completeness test | `veaf_build/worker.py`, `test/python/veaf_build/test_lua_bundle_manifest.py` | fix | ✅ |
| DCS-VERIFY-R3-MQ9 | v5→v6 regression: default `spawnables.yaml` dropped the `veafSpawn-MQ-9 - AFAC - JTAC - DRONE` template → `_cas` AFAC + `-afac` alias found no MQ-9. Restored it (extracted from the demo mission, under `airplanes`) | `src/defaults/mission-folder/src/spawnables.yaml` | fix | ✅ |
| DCS-VERIFY-R | In-game runtime checklist in the updated DCS (R0-R7): mission loads, scripts load static+dynamic, F10 menu, ME save round-trip, dynamic slots, presets/waypoints save, convert-v5/build read. All green; 2 bugs fixed in-lot (bundle, MQ-9), 3 findings spun off | `TEST-PLAN-DCS-UPDATE.md` | test | ✅ |
