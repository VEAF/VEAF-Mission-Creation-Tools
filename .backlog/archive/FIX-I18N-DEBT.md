# Lot FIX-I18N-DEBT — Clear remaining hardcoded-string debt

Status: ✅ done

**Goal**: Fix all 107 hardcoded English strings in the 25 files currently listed in `_TODO_EXEMPTIONS`, add matching keys to `en.json`/`fr.json`, and remove every file from the exemption list so COV-003 enforces the whole codebase.

**Branch**: `fix/i18n-debt` → PR → `develop-v6`

| # | Ticket | Files | Type | Effort | Status |
|---|--------|-------|------|--------|--------|
| DEBT-001 | Fix `mission_builder_worker.py` (14 violations) | worker + locales | fix | 30 min | ✅ |
| DEBT-002 | Fix `waypoints_injector_worker.py` (25 violations) | worker + locales | fix | 40 min | ✅ |
| DEBT-003 | Fix `veaf_tools/commands/convert_v5.py` (12 violations) | command + locales | fix | 20 min | ✅ |
| DEBT-004 | Fix `veaf_tools/commands/aircraft_groups.py` (7 violations) | command + locales | fix | 15 min | ✅ |
| DEBT-005 | Fix `veaf_tools/commands/build.py` (5 violations) | command + locales | fix | 10 min | ✅ |
| DEBT-006 | Fix `weather_injector/utils/lua_converter.py` (5 violations) | util + locales | fix | 10 min | ✅ |
| DEBT-007 | Fix remaining small files (≤3 violations each): mission_extractor, mission_tools, presets_injector, veaf-tools-updater, veaf_libs/*, veaf_tools/commands (7 files), waypoints_manager, weather_injector/* | various + locales | fix | 45 min | ✅ |
| DEBT-008 | Remove all 25 files from `_TODO_EXEMPTIONS` in test_i18n.py | test | 5 min | ✅ |
