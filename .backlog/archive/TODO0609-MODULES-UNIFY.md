# Lot TODO0609-MODULES-UNIFY — Single `modules:` block as the source of truth

Status: ✅ done

**Goal**: Today a module/community-script can appear in up to three places in `mission.yaml`: a toggle under `modules:`, a detailed block under `external_modules:`, and a top-level `qra:` block. Collapse everything into a single `modules:` block where each module has one entry with its config nested (Skynet, CTLD, CSAR, QRA included). Remove `external_modules:` and the top-level `qra:`. **Hard break** — v6 is not officially released yet, so no backward-compatibility shim. Covers todo-2026.06.09 items 5, 6, 8.

**Decisions** (grilling 2026-06-10): everything nested under `modules:`; remove `external_modules:`/`qra:`; hard break (no deprecation); `convert-v5` extracts CTLD/CSAR config from v5. See `docs/adr/0001-modules-single-source-of-truth.md`.

**Branch**: `feat/modules-unify` → PR → `develop`

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| MODULES-UNIFY-001 | Redesign the `mission.yaml` schema: one `modules:` block, each module/community-script an entry with nested config (incl. `skynet`, `ctld`, `csar`, `qra`). Update the default template and the validator. | `src/defaults/mission-folder/mission.yaml`, `veaf_libs/yaml_validator.py` | feat | ✅ |
| MODULES-UNIFY-002 | `lua_config_generator`: read nested per-module config from `modules:`; drop all handling of `external_modules:` and top-level `qra:`. | `veaf_libs/lua_config_generator.py`, `test/python/` | feat | ✅ |
| MODULES-UNIFY-003 | `convert-v5`: emit converted modules (incl. QRA) into the new nested `modules:` structure instead of separate `external_modules:`/`qra:` sections. | `mission_builder/config_migrator.py`, `mission_builder/v5_converter.py`, `test/python/` | feat | ✅ |
| MODULES-UNIFY-004 | `convert-v5`: extract CTLD/CSAR config from `missionConfig.lua` (`ctld.xxx = …` / `csar.xxx = …` assignments) into `modules.CTLD` / `modules.CSAR`. (todo item 6) | `mission_builder/config_migrator.py`, `test/python/` | feat | ✅ |
| MODULES-UNIFY-005 | Update docs: `doc/MISSION_YAML_REFERENCE.md` (+ `.fr`), migration guide, and any example referencing `external_modules:`/`qra:`. | `doc/MISSION_YAML_REFERENCE*.md`, `doc/mission-maker/MIGRATION_GUIDE*.md` | chore | ✅ |
| MODULES-UNIFY-006 | Add **semantic** validation of the unified `modules:` block — distinct from the YAML *syntax* validation already provided by `yaml_validator.validate_yaml_file`. Today `lua_config_generator` reads `modules:` as raw nested dicts with silent `.get(key, default)` (`:349-458`), so an unknown module key, an unrecognized `init:` parameter, or a wrong scalar type is silently dropped and produces wrong Lua with no warning to the mission-maker. Validate: unknown module key → error, unrecognized `init:` param → warning, wrong type → error. Reuse the localized `ValidationError` style already rolled out in `aircrafts_injector_worker` (`:31`, `:114-297`) for consistency; consider promoting it (and the existing `weather_injector/models/` config models) toward a shared typed `mission.yaml` model. | `veaf_libs/yaml_validator.py`, `veaf_libs/lua_config_generator.py`, `test/python/` | feat | ✅ |
