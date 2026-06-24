# Lot TUM-AUTOINIT — auto-init TheUniversalMission when selected

Status: ✅ done

**Goal**: when `TUM` is selected in `mission.yaml` `modules:`, `TUM.initialize()` (TheUniversalMission) must be called automatically — **but TUM must never be enabled by default** (vanilla mission or `convert-v5`), because it aborts at start-up without BLUFOR/REDFOR territory zones.

**Done**: made TUM **opt-in** across the build. New `get_optin_community_script_ids()` (`mission_constants.py`) returns `{"tum"}`; the builder enablement (`enabled_community_script_ids`, `_active_community_scripts`, `_community_enabled`), the generator `_community_enabled` (None-branch), and `convert-v5` output now treat opt-in ids as OFF unless an explicit `<ID>: true` is set — while opt-out scripts (ctld, csar, …) keep their active-by-default behaviour. When `TUM: true`, the generator still emits `if TUM then TUM.initialize() end`. `convert-v5` emits `TUM: false` even when the TUM file is detected. Tests added (builder opt-in parsing, generator default-off, convert-v5 emit). Doc: `MISSION_YAML_REFERENCE` (FR/EN) opt-in note, default `mission.yaml` comment, CHANGELOG.

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| TUM-AUTOINIT-001 | Make TUM opt-in (off by default everywhere) and auto-init `TUM.initialize()` only when `TUM: true` | `mission_tools/mission_constants.py`, `mission_builder/mission_builder_worker.py`, `mission_builder/v5_converter.py`, `veaf_libs/lua_config_generator.py`, `test/python/` | fix | ✅ |
