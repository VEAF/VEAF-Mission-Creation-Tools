# Lot TEST-PHASE-6.4.x — manual test-campaign fixes

Status: ✅ done

**Goal**: during the manual v6.4.x test campaign (a v6-built mission tested in DCS in **dynamic** mode, plus design-time checks of `convert-v5`, the CLI/TUI and `veaf-build`), every plan section (build, runtime, convert-v5, CLI/TUI, DCS data, security/perf) was exercised. Most items already worked; the issues below were found and fixed. Each is journaled (remark → analysis → fix) in the temporary `TEST-PLAN-VEAF-6.4.x.md`. Single branch, single PR.

**Branch**: `fix/tests` → [PR #468](https://github.com/VEAF/VEAF-Mission-Creation-Tools/pull/468) → `develop-v6` (squash `d62e0c23`)

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| C1 | Split spawn/QRA proxies (`veafSpawn.lua`/`veafQraManager.lua`) resolve their dir under DCS dynamic `loadfile` (chunk source without `@`), fixing the `no file 'veafSpawnCore.lua'` + `veafRemote`/`veafUnits` nil cascade | `src/scripts/veaf/veafSpawn.lua`, `veafQraManager.lua` | fix | ✅ |
| C2 | Generated `veafDynamicConfig.lua` no longer lists itself → no infinite reload at mission start in dynamic mode | `mission_builder/mission_builder_worker.py`, `test/python/` | fix | ✅ |
| C3 | `SHORTCUTS` enabled by default in the shipped `mission.yaml` (built-in aliases work out of the box) | `src/defaults/mission-folder/mission.yaml` | feat | ✅ |
| C4 | `CASMISSION` + `TRANSPORTMISSION` enabled by default (marker-driven, no config) | `src/defaults/mission-folder/mission.yaml` | feat | ✅ |
| C5 | Config generator maps each module id to its real table name (`<table>.Id`) not the filename → `veafSpawn.initialize()`/`veafQraManager.initialize()` actually run in dynamic mode (`_spawn` handler registered) | `veaf_libs/lua_config_generator.py`, `test/python/` | fix | ✅ |
| C6 | Dynamic mission trigrule loaded `veaf-config.lua` twice (explicit + via `veafDynamicConfig.lua`) → modules initialized twice → markers fired twice; removed the redundant explicit load | `mission_builder/mission_builder_worker.py`, `test/python/` | fix | ✅ |
| C7 | `_spawn unit` success message + JTAC variant routed through `veaf.t` (FR+EN) | `src/scripts/veaf/veafSpawnAircraft.lua`, `veafI18n.lua` | fix | ✅ |
| C8 | Warehouse dynamic-slot aircraft nested by category (`aircrafts.helicopters`/`.planes`) so `linkDynTempl` binds; classified via the DCS units DB | `warehouses_injector/warehouses_injector_worker.py`, `test/python/` | fix | ✅ |
| C9 | Presets: drop per-aircraft out-of-range channels so the mission still saves + add the missing MiG-15bis radio spec (extends FIX-PRESETS-RADIO-COMPAT) | `presets_injector/`, `presets_injector/data/dcs-radio-specs.yaml`, `test/python/` | fix | ✅ |
| C10 | Coalition refactor: `veaf.getOppositeCoalition` (spawn side) + `veaf.getRequesterCoalition` (feedback audience) replace the scattered inversion; the unknown-parameter hint reaches the requester | `src/scripts/veaf/veaf.lua`, `veafSpawnCore.lua`, `veafCasMission.lua`, `veafShortcuts.lua`, `veafMarkers.lua`, `test/lua/` | fix | ✅ |
| C11 | An unknown spawn parameter aborts the command (message, no spawn) instead of spawning anyway | `src/scripts/veaf/veafSpawnCore.lua`, `test/lua/` | fix | ✅ |
