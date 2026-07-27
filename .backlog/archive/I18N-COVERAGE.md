# Lot I18N-COVERAGE — i18n coverage tests + fix remaining hardcoded English strings

Status: ✅ done

**Goal**: Add automated i18n coverage tests so hardcoded strings and missing translations are caught at CI. Then fix all currently identified violations.

### Context

`test_i18n.py` tests only the `t()` mechanics. No test currently verifies:
- every `t("key")` call in code has a matching entry in `en.json`
- every key in `en.json` has a translation in `fr.json`
- no user-visible message is a raw English string literal instead of `t("key")`

### Hardcoded strings identified (must fix)

| File | Strings |
|------|---------|
| `mission_builder/mission_builder_worker.py` | `Found lua_modules section`, `Found global_log_level`, `Legacy weather config`, `Generated '...' from mission.yaml` (~line 106, 109, 438, 1074) |
| `aircrafts_injector/aircrafts_injector_worker.py` | `No issues found`, `YAML validation successful`, `YAML validation failed`, `YAML file loaded successfully`, `Mission file loaded successfully`, `Mission written successfully`, etc. (~20 strings) |
| `veaf_libs/lua_config_generator.py` | `Module '...' requires '...' which is not configured — auto-enabling '...'` (~line 628) |
| `waypoints_injector/waypoints_manager.py` | `Loaded N waypoint(s) and N flight plan template(s)` (~line 142) |

**Branch**: `fix/i18n-coverage` → PR → `develop`

| # | Ticket | Files | Type | Effort | Status |
|---|--------|-------|------|--------|--------|
| I18N-COV-001 | Add test: all `t("key")` calls in `src/python/` reference a key that exists in `en.json` | `test/python/veaf_libs/test_i18n.py` | test | 20 min | ✅ |
| I18N-COV-002 | Add test: every key in `en.json` has a non-empty entry in `fr.json` | `test/python/veaf_libs/test_i18n.py` | test | 10 min | ✅ |
| I18N-COV-003 | Add i18n keys for `mission_builder_worker.py` hardcoded strings and replace with `t()` | `mission_builder/mission_builder_worker.py`, `locales/en.json`, `locales/fr.json` | fix | 20 min | ✅ |
| I18N-COV-004 | Add i18n keys for `aircrafts_injector_worker.py` hardcoded strings and replace with `t()` | `aircrafts_injector/aircrafts_injector_worker.py`, `locales/en.json`, `locales/fr.json` | fix | 45 min | ✅ |
| I18N-COV-005 | Add i18n keys for `lua_config_generator.py` and `waypoints_manager.py` hardcoded strings | `veaf_libs/lua_config_generator.py`, `waypoints_injector/waypoints_manager.py`, `locales/*.json` | fix | 15 min | ✅ |
