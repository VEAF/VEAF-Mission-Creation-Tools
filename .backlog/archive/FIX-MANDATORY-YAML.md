# Lot FIX-MANDATORY-YAML — YAML generators: emit `{}` for mandatory modules instead of `enable: true`

Status: ✅ done

**Goal**: The three YAML generators (`v5_converter.py`, `lua_config_generator.py`, `config_migrator.py`) emitted `enable: true` for mandatory modules (UNITS, TIME, CACHE, EVENTS, MARKERS, COMMANDS). The build blocked on these entries with a critical error. They must emit `{}` instead (matching the `src/defaults/mission-folder/mission.yaml` template).

**Branch**: `fix/mandatory-yaml-enable` → PR → `develop`

| # | Ticket | Files | Type | Effort | Status |
|---|--------|-------|------|--------|--------|
| FMY-001 | Expose `_MANDATORY_MODULES` as public in `lua_config_generator.py` and emit `{}` for mandatory modules in `generate_mission_yaml_template` | `veaf_libs/lua_config_generator.py` | fix | 10 min | ✅ |
| FMY-002 | In `v5_converter.py`: import `MANDATORY_MODULES`, add COMMANDS to `_BASE_ALWAYS_ON`, emit `{}` instead of `enable: true` for mandatory modules | `mission_builder/v5_converter.py` | fix | 10 min | ✅ |
| FMY-003 | In `config_migrator.py`: import `MANDATORY_MODULES`, emit `{}` instead of `enable: true` for mandatory modules | `mission_builder/config_migrator.py` | fix | 10 min | ✅ |
| FMY-004 | Update impacted tests and add missing cases | `test/python/` | test | 5 min | ✅ |
