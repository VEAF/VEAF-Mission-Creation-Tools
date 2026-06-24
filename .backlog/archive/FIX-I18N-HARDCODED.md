# Lot FIX-I18N-HARDCODED — AST test + fix hardcoded strings in aircrafts_injector + lua_config_generator

Status: ✅ done

**Goal**: Ensure no hardcoded English prose appears in `logger.*()`, `console.print()`, or `return` statements. Add an AST-based test (`TestI18nNoHardcodedStrings`, COV-003) that fails when violations are found, then fix all violations in the two files targeted for this lot.

**Root cause**: `aircrafts_injector_worker.py` and `lua_config_generator.py` contained hardcoded English strings in logger/console calls and return values, bypassing the `t()` i18n system.

**Files changed**:
- `test/python/veaf_libs/test_i18n.py` — new `TestI18nNoHardcodedStrings` class with `_TODO_EXEMPTIONS` (25 files), `_has_prose()`, `_is_t_call()`, `_violations_in_file()`
- `src/python/veaf-tools/aircrafts_injector/aircrafts_injector_worker.py` — 15+ hardcoded strings → `t()` calls
- `src/python/veaf-tools/veaf_libs/lua_config_generator.py` — 2 `logger.warning()` calls → `t()` calls
- `src/python/veaf-tools/veaf_libs/locales/en.json` + `fr.json` — 18 new keys added

| # | Ticket | Files | Type | Effort | Status |
|---|--------|-------|------|--------|--------|
| IH-001 | Write failing AST-based `TestI18nNoHardcodedStrings` test | `test/python/veaf_libs/test_i18n.py` | test | 20 min | ✅ |
| IH-002 | Fix hardcoded strings in `aircrafts_injector_worker.py` (15 violations) | `aircrafts_injector_worker.py`, `en.json`, `fr.json` | fix | 25 min | ✅ |
| IH-003 | Fix hardcoded strings in `lua_config_generator.py` (2 violations) | `lua_config_generator.py`, `en.json`, `fr.json` | fix | 10 min | ✅ |
