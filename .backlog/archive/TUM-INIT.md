# Lot TUM-INIT — initialize TheUniversalMission from config

Status: ✅ done

**Goal**: `TUM: true` in `mission.yaml` currently does nothing — the generated `veaf-config.lua` never calls `TUM.initialize()` (the runtime logs "loaded, but not initialized"). Generate the init so the toggle actually starts TUM.

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| TUM-INIT-001 | Emit `TUM.initialize()` in `veaf-config.lua` when `TUM` is enabled (decide config surface, e.g. a `settings:` block). Add tests. | `veaf_libs/lua_config_generator.py`, `mission_builder/mission_builder_worker.py`, `test/python/` | feat | ✅ |
