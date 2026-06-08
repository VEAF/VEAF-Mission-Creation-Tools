# Backlog — VEAF Mission Creation Tools v6

## Calibration Table

| Lot | Estimated (min) | Actual (min) | Ratio | Note |
|-----|----------------|--------------|-------|------|
| *(no lot completed yet)* | | | | Initial factor: 1.15 |
| Lot 6 — BONUS | 210 | — | — | LUA-006 + TOOL-004 + LUA-007 |

## Legend

- **Effort**: estimated Copilot time in minutes (excludes user decisions and review)
- **Type**: `feat` / `fix` / `chore`
- **Status**: `⬜` to do · `🔄` in progress · `✅` done

> Completed lots (> 3 days ago) are moved to [backlog-archive.md](backlog-archive.md).

---

## Summary

| Lot | Estimate | Status |
|-----|----------|--------|
| Phase 0 — Restart | ~3h | [archived](backlog-archive.md) |
| Phase 0b — GitHub cleanup | ~25 min | ⬜ |
| Lot 1 — INFRA | ~4h15 | [archived](backlog-archive.md) |
| Lot 2 — CLI | ~2h35 | [archived](backlog-archive.md) |
| Lot 3 — TUI | ~2h20 | [archived](backlog-archive.md) |
| Lot 4 — LUA-CONFIG | ~6h | [archived](backlog-archive.md) |
| Lot 5 — RELEASE | ~1h30 | ⬜ |
| Lot 6 — BONUS | ~3h30 | [archived](backlog-archive.md) |
| Lot 7 — LUA FIXES | ~5h45 | [archived](backlog-archive.md) |
| Lot 8 — LUA-QUALITY | ~3h35 | [archived](backlog-archive.md) |
| Lot RC — v6.1.0 RC fixes | ~1h35 | [archived](backlog-archive.md) |
| Lot 9 — LUA-REFACTOR | ~11h30 | [archived](backlog-archive.md) |
| Lot 10 — YAML-CONFIG | ~14h | [archived](backlog-archive.md) |
| Lot 11 — I18N | ~7h10 | [archived](backlog-archive.md) |
| Lot 12 — QUALITY | ~16h35 | [archived](backlog-archive.md) |
| Lot 13 — DISCUSS | ~13h50 | [archived](backlog-archive.md) |
| Lot 14 — ARCH-COMMANDS | ~7h30 | [archived](backlog-archive.md) |
| Lot 15 — DOC | ~6h | [archived](backlog-archive.md) |
| Lot UPDATER-FIX | ~65 min | [archived](backlog-archive.md) |
| Lot 16 — LUA-COVERAGE | ~17h15 | [archived](backlog-archive.md) |
| Lot 17 — USER-CONFIG | ~3h | [archived](backlog-archive.md) |
| Lot 18 — VERSIONING | ~1h45 | [archived](backlog-archive.md) |
| Lot 19 — MIGRATOR | ~2h30 | [archived](backlog-archive.md) |
| Lot 20 — DEEPENING | ~7h | [archived](backlog-archive.md) |
| Lot 21 — TYPING | ~20 min | [archived](backlog-archive.md) |
| Lot 22 — TEST-LAYOUT | ~55 min | [archived](backlog-archive.md) |
| Lot 23 — DOC-YAML | ~8h20 | [archived](backlog-archive.md) |
| Lot 24 — DOC-REVIEW | ~2h45 | ⬜ (REV-002 pending) |
| Lot 25 — EXT-YAML | ~2h | [archived](backlog-archive.md) |
| Lot FIX-SORT — LUADATA FIX | ~15 min | [archived](backlog-archive.md) |
| Lot 26 — IMC-FEEDBACK | ~2h40 | [archived](backlog-archive.md) |
| Lot FIX-BUNDLE — VEAFCOMMANDS MISSING | ~10 min | [archived](backlog-archive.md) |
| Lot FIX-ASSETS-NEWLINE — ASSETS newline in Lua string | ~20 min | [archived](backlog-archive.md) |
| Lot FIX-WEATHER-ALIAS — missions.yaml + versions.yaml coexistence | ~25 min | [archived](backlog-archive.md) |
| Lot FIX-MISSIONCONFIG-BAK — remove unused .bak extension | ~20 min | [archived](backlog-archive.md) |
| Lot FIX-README-COPY — stop copying presets.md into src/ | ~10 min | [archived](backlog-archive.md) |
| Lot FIX-AIRCRAFT-ORPHAN — missing orphan-file warning for aircraft-templates.yaml | ~15 min | [archived](backlog-archive.md) |
| Lot DOC-DEV-MODE — document dev_mode + scripts_path | ~30 min | [archived](backlog-archive.md) |
| Lot FEAT-PROFILES — build profiles in mission.yaml | ~3h | [archived](backlog-archive.md) |
| Lot FEAT-MODULE-UX — module categories, mandatory modules, dependencies | ~2h | [archived](backlog-archive.md) |
| Lot FEAT-GITIGNORE — VEAF MCT .gitignore template in defaults | ~25 min | [archived](backlog-archive.md) |
| Lot FIX-OLDSCRIPTS — detect residual .lua files in src/scripts/ | ~45 min | ✅ |
| Lot FIX-MARKERS-INIT — add missing `veafMarkers.initialize()` | ~5 min | ✅ |
| Lot FIX-MISSING-INIT — missing `initialize()` on 4 Lua modules | ~20 min | ✅ |
| Lot 27 — DOC-FR-MERGE | ~6h | ✅ |
| Lot FIX-YAML-SYNTAX — unhandled YAML error in build and mission_builder_worker | ~15 min | ✅ |
| Lot FIX-MANDATORY-ENABLE — block enable on mandatory modules | ~20 min | ✅ |
| Lot FEAT-CUSTOM-SCRIPTS — custom_scripts section in mission.yaml | ~45 min | ✅ |
| Lot FIX-REMOVE-CONVERT — remove the `convert` command | ~20 min | ✅ |
| Lot FIX-MISSIONCONFIG-REFS — references to `missionConfig.lua` in doc and code | ~30 min | ✅ |
| Lot FEAT-DCS-BRIDGE — Optional dcs-bridge.lua injection | ~1h30 | ✅ |
| Lot FIX-MANDATORY-YAML — YAML generators: emit `{}` for mandatory modules instead of `enable: true` | ~35 min | ✅ |
| Lot CMT-YAML-DOCS — doc comments and links in generated `mission.yaml` files | ~45 min | ✅ |
| Lot FIX-AIRCRAFT-DUPLICATE — Duplicate aircraft groups in "add" injection mode | ~20 min | ✅ |
| **Total** | **~178h45** | |

*Initial calibration factor: 1.15 — recalculate after each completed lot.*

---

## Lot FIX-MANDATORY-YAML — YAML generators: emit `{}` for mandatory modules instead of `enable: true`

**Goal**: The three YAML generators (`v5_converter.py`, `lua_config_generator.py`, `config_migrator.py`) emitted `enable: true` for mandatory modules (UNITS, TIME, CACHE, EVENTS, MARKERS, COMMANDS). The build blocked on these entries with a critical error. They must emit `{}` instead (matching the `src/defaults/mission-folder/mission.yaml` template).

**Branch**: `fix/mandatory-yaml-enable` → PR → `develop-v6`

| # | Ticket | Files | Type | Effort | Status |
|---|--------|-------|------|--------|--------|
| FMY-001 | Expose `_MANDATORY_MODULES` as public in `lua_config_generator.py` and emit `{}` for mandatory modules in `generate_mission_yaml_template` | `veaf_libs/lua_config_generator.py` | fix | 10 min | ✅ |
| FMY-002 | In `v5_converter.py`: import `MANDATORY_MODULES`, add COMMANDS to `_BASE_ALWAYS_ON`, emit `{}` instead of `enable: true` for mandatory modules | `mission_builder/v5_converter.py` | fix | 10 min | ✅ |
| FMY-003 | In `config_migrator.py`: import `MANDATORY_MODULES`, emit `{}` instead of `enable: true` for mandatory modules | `mission_builder/config_migrator.py` | fix | 10 min | ✅ |
| FMY-004 | Update impacted tests and add missing cases | `test/python/` | test | 5 min | ✅ |

---

## Lot CMT-YAML-DOCS — doc comments and links in generated `mission.yaml` files

**Goal**: Generated `mission.yaml` files (by `generate-config`, `convert-v5` and `prepare`) must contain explanatory comments and a link to the relevant documentation chapter for each section. The current URLs pointed to a non-existent file.

**Branch**: `fix/mandatory-yaml-enable` (amended on current branch)

| # | Ticket | Files | Type | Effort | Status |
|---|--------|-------|------|--------|--------|
| CMT-001 | Fix the doc URL and add per-section links in `en.json` | `veaf_libs/locales/en.json` | chore | 10 min | ✅ |
| CMT-002 | Same fixes in `fr.json` | `veaf_libs/locales/fr.json` | chore | 10 min | ✅ |
| CMT-003 | Fix the URL and add per-section links in `v5_converter.py` | `mission_builder/v5_converter.py` | chore | 10 min | ✅ |
| CMT-004 | Fix the URL in `src/defaults/mission-folder/mission.yaml` | `src/defaults/mission-folder/mission.yaml` | chore | 5 min | ✅ |
| CMT-005 | Tests: verify links are present in generated YAML files | `test/python/` | test | 10 min | ✅ |

---

## Lot FIX-MISSIONCONFIG-REFS — references to `missionConfig.lua` in doc and code

**Goal**: Replace all user-facing references to `missionConfig.lua` with the correct v6 name (`mission-script.lua` for custom code, `mission.yaml` for configuration).

**Branch**: `fix/remove-convert-command` → PR #371 → `develop-v6`

| # | Ticket | Files | Type | Effort | Status |
|---|--------|-------|------|--------|--------|
| MCR-001 | Fix `veafQraManager.md/en.md`: "Via missionConfig.lua" section | `doc/mission-maker/scripts/` | doc | 5 min | ✅ |
| MCR-002 | Fix `veafSkynetIadsHelper.md/en.md`: prerequisites and section title | `doc/mission-maker/scripts/` | doc | 5 min | ✅ |
| MCR-003 | Fix directory trees in `mission_builder_README.py` and `mission_extractor_README.py` | `src/python/veaf-tools/` | doc | 5 min | ✅ |
| MCR-004 | Fix AIEN/CTLD/CSAR comments in `veaf.lua` | `src/scripts/veaf/veaf.lua` | chore | 5 min | ✅ |
| MCR-005 | Fix test fixtures (`veafDynamicConfig.lua`, `mapResource`) | `test/veaf-tools/` | chore | 10 min | ✅ |

---

## Lot FIX-REMOVE-CONVERT — remove the `convert` command

**Goal**: Remove the `convert` command which is broken on v6 missions (crashes on missing `missionConfig.lua`) and whose role is covered by `extract` + `build`.

**Branch**: `fix/remove-convert-command` → PR #371 → `develop-v6`

| # | Ticket | Files | Type | Effort | Status |
|---|--------|-------|------|--------|--------|
| RMC-001 | Delete `commands/convert.py` and the `mission_converter/` package | `src/python/veaf-tools/` | chore | 5 min | ✅ |
| RMC-002 | Remove TUI entry and `cmd.convert.*` locale keys | `tui.py`, `en.json`, `fr.json` | chore | 10 min | ✅ |
| RMC-003 | Remove the corresponding test assertion | `test/python/veaf_libs/test_tui.py` | test | 5 min | ✅ |

---

## Lot FEAT-CUSTOM-SCRIPTS — custom_scripts section in mission.yaml

**Goal**: Allow declaring custom Lua scripts in `mission.yaml` to suppress warnings and control the generation of the DCS load trigger.

**Branch**: `feature/custom-scripts` → PR → `develop-v6`

| # | Ticket | Files | Type | Effort | Status |
|---|--------|-------|------|--------|--------|
| CUSTOM-001 | Add `CustomScript` dataclass + parse `custom_scripts` in `__init__` | `mission_builder_worker.py` | feat | 10 min | 🔄 |
| CUSTOM-002 | Update warning logic (declared = info, unknown = warning with hint) | `mission_builder_worker.py` | feat | 10 min | 🔄 |
| CUSTOM-003 | Filter load triggers according to `generate_load_trigger` | `mission_builder_worker.py` | feat | 10 min | 🔄 |
| CUSTOM-004 | TDD tests (warnings + trigger resolution) | `test_mission_builder_defaults.py` | test | 10 min | 🔄 |
| CUSTOM-005 | Document the section in the default `mission.yaml` | `src/defaults/mission-folder/mission.yaml` | doc | 5 min | 🔄 |

---

## Lot FIX-MISSING-INIT — missing `initialize()` on 4 Lua modules

**Goal**: Fix DCS runtime crashes `attempt to call field 'initialize' (a nil value)` on modules not yet covered.

**Context**: The Python build (`lua_config_generator.py`) generates an `<module>.initialize()` call for all modules listed in `_MODULE_INIT_ORDER`. A full audit revealed 4 modules missing this function: `veafCacheManager`, `veafTime`, `veafUnits`, `veafSkynetIadsMonitor`.

**Branch**: `fix/missing-initialize-fns` → PR → `develop-v6`

| # | Ticket | Files | Type | Effort | Status |
|---|--------|-------|------|--------|--------|
| MISSING-INIT-001 | Add `initialize()` to `veafCacheManager.lua` | `src/scripts/veaf/veafCacheManager.lua` | fix | 5 min | ✅ |
| MISSING-INIT-002 | Add `initialize()` to `veafTime.lua` | `src/scripts/veaf/veafTime.lua` | fix | 5 min | ✅ |
| MISSING-INIT-003 | Add `initialize()` to `veafUnits.lua` | `src/scripts/veaf/veafUnits.lua` | fix | 5 min | ✅ |
| MISSING-INIT-004 | Add `initialize()` to `veafSkynetIadsMonitor.lua` | `src/scripts/veaf/veafSkynetIadsMonitor.lua` | fix | 5 min | ✅ |

---

## Lot FIX-MARKERS-INIT — add missing `veafMarkers.initialize()`

**Goal**: Fix DCS runtime error `attempt to call field 'initialize' (a nil value)` on `veafMarkers`.

**Context**: The `initialize()` function was missing from `veafMarkers.lua` even though `veaf-config.lua` always calls it. The module was already self-initializing on load; the added function simply logs.

**Branch**: direct commit without branch (minimal fix, tested by user)

| # | Ticket | Files | Type | Effort | Status |
|---|--------|-------|------|--------|--------|
| MARKERS-INIT-001 | Add `veafMarkers.initialize()` to `src/scripts/veaf/veafMarkers.lua` | `src/scripts/veaf/veafMarkers.lua` | fix | 5 min | ✅ |

---

## Lot FIX-OLDSCRIPTS — detect residual .lua files in src/scripts/

**Goal**: Detect residual v5 `.lua` files in `src/scripts/` of a converted mission and emit a warning at build time.

**Context**: The original bug (`veafCommands nil`) was resolved by Lot FIX-BUNDLE. Potential secondary cause not addressed: individual v5 VEAF `.lua` files still present in `src/scripts/` could be loaded via the `src/scripts/*.lua` glob and create DCS runtime conflicts. OLDSCRIPTS-002 can be implemented independently of the investigation.

**Branch**: `fix/oldscripts-detection` → PR → `develop-v6`

| # | Ticket | Files | Type | Effort | Status |
|---|--------|-------|------|--------|--------|
| OLDSCRIPTS-000 | Investigation: reproduce the bug with a real v5→v6 mission; obtain full DCS logs; identify the responsible file | — | chore | 15 min | ✅ (resolved — see context) |
| OLDSCRIPTS-001 | Fix: based on investigation result, fix the identified root cause | TBD | fix | TBD | ✅ (resolved by FIX-BUNDLE) |
| OLDSCRIPTS-002 | Add a warning if unexpected `.lua` files are present in `src/scripts/` (i.e. not explicitly listed in `get_mission_script_files()`) | `mission_tools/mission_constants.py` or `mission_builder_worker.py` | fix | 15 min | ✅ |

**Raw total: ~45 min estimated (excluding investigation)**

---

## Lot 27 — DOC-FR-MERGE: French as default language + v5 content merge

**Goal**: Switch French as the default MkDocs documentation language and enrich v6 pages with the missing conceptual content from the v5 documentation (written manually).

**Branch**: `feature/doc-fr-default-and-v5-merge` → PR → `develop-v6`

| # | Ticket | Files | Type | Effort | Status |
|---|--------|-------|------|--------|--------|
| DOC-FR-001 | Rename `*.md` → `*.en.md` and `*.fr.md` → `*.md` (35 pairs) | `doc/**` | chore | 15 min | ✅ |
| DOC-FR-002 | Update `mkdocs.yml`: FR default, EN secondary | `mkdocs.yml` | chore | 10 min | ✅ |
| DOC-FR-003 | Merge v5 content → `veafQraManager.md` (FR + EN) | `doc/mission-maker/scripts/veafQraManager.*` | chore | 45 min | ✅ |
| DOC-FR-004 | Merge v5 content → `veafCombatZone.md` (FR + EN) | `doc/mission-maker/scripts/veafCombatZone.*` | chore | 45 min | ✅ |
| DOC-FR-005 | Merge v5 content → `veafAirWaves.md` (FR + EN) | `doc/mission-maker/scripts/veafAirWaves.*` | chore | 30 min | ✅ (v6 already complete) |
| DOC-FR-006 | Merge v5 content → `veafRadio.md` (FR + EN) | `doc/mission-maker/scripts/veafRadio.*` | chore | 20 min | ✅ |
| DOC-FR-007 | Merge v5 content → `veafSkynetIadsHelper.md` (FR + EN) | `doc/mission-maker/scripts/veafSkynetIadsHelper.*` | chore | 20 min | ✅ |
| DOC-FR-008 | Merge v5 content → `veafWeather.md` (FR + EN) | `doc/mission-maker/scripts/veafWeather.*` | chore | 20 min | ✅ |
| DOC-FR-009 | Check `presets.md` v5 and identify the v6 equivalent | TBD | chore | 15 min | ✅ (already in GUIDE.md) |

---

## Lot FIX-YAML-SYNTAX — unhandled YAML error in build and mission_builder_worker

**Goal**: Catch YAML syntax errors in `mission.yaml` to display a clear message instead of a Python traceback.

**Context**: An unhandled `yaml.YAMLError` in `build.py` (name peek) and `mission_builder_worker.py` (full load) caused a crash with traceback. PyYAML's native error message (file, line, column, context) is now propagated via `logger.error`.

**Branch**: `fix/yaml-syntax-error` → PR → `develop-v6`

| # | Ticket | Files | Type | Effort | Status |
|---|--------|-------|------|--------|--------|
| YAML-SYNTAX-001 | Handle `yaml.YAMLError` in `build.py` (peek mission name) | `src/python/veaf-tools/veaf_tools/commands/build.py` | fix | 5 min | ✅ |
| YAML-SYNTAX-002 | Handle `yaml.YAMLError` in `mission_builder_worker.py` (full load) | `src/python/veaf-tools/mission_builder/mission_builder_worker.py` | fix | 5 min | ✅ |

---

## Lot 24 — DOC-REVIEW: Klogg profile (REV-002)

**Goal**: Commit the VEAF Klogg profile to the repo to ease DCS log reading.

**Context**: All other REV-* tickets from Lot 24 are archived. REV-002 is waiting for the user to provide the `.conf` file.

**Branch**: `fix/doc-review-klogg` → PR → `develop-v6`

| # | Ticket | Files | Type | Effort | Status |
|---|--------|-------|------|--------|--------|
| REV-002 | Commit the Klogg profile provided by the user to `tools/klogg/veaf.conf`; update the "Reading the log" section in `GUIDE.md` and `GUIDE.fr.md` to point to this file | `tools/klogg/veaf.conf`, `doc/mission-maker/GUIDE.md`, `doc/mission-maker/GUIDE.fr.md` | chore | 20 min | ⬜ |

---

## Phase 0b — GitHub cleanup

Close issues identified during triage. **Verify each one before closing.**
Direct commits on `develop-v6` (no feature branch needed — no code change).

| # | Ticket | Type | Effort | Status |
|---|--------|------|--------|--------|
| CLOSE-001 | Close WONTFIX issues: #55, #146, #147, #180, #193, #246 | chore | 15 min | ⬜ |
| CLOSE-002 | Close STALE issues: #9, #19, #41, #167 | chore | 10 min | ⬜ |

<details>
<summary>Issues to close</summary>

**WONTFIX — Already implemented or out of scope**

| # | Title | Reason |
|---|-------|--------|
| #55 | Faire un système de zone de combat dynamique | Already implemented → `veafCombatZone` |
| #146 | CTLD JTAC 9-line | External project (CTLD/Ciribob) |
| #147 | CTLD JTAC Ask for wind/speed correction | External project (CTLD/Ciribob) |
| #180 | AirWaves - forcer à rester dans la zone | Both tasks already checked ✅ in the issue |
| #193 | CTLD - gestion d'emport multiple de caisses | Requires upstream PR to CTLD, out of scope |
| #246 | CTLD - orientation des unités Patriot | CTLD external bug, out of scope |

**STALE — No activity, too vague, or superseded**

| # | Title | Reason |
|---|-------|--------|
| #9 | Marker command to build a transport mission interception | 2018, no activity since 2021, too vague |
| #19 | Idée - spawn facile avec inventaire des unités par coalition | 2020, informal idea, no spec |
| #41 | Tester spawn humains CASE 1 téléportés à la bonne position | 2021, vague, no activity |
| #167 | Tester gRPC | 2023 tech spike, no follow-up planned |

</details>

---

## Lot 5 — RELEASE: v6.1.0

**Goal**: Merge v6 to master and publish the official release.
**From**: `develop-v6` directly

| # | Ticket | Type | Effort | Depends on | Status |
|---|--------|------|--------|------------|--------|
| REL-001 | Finalize `CHANGELOG.md` for v6.1.0 | chore | 20 min | Lots 1–4 | ⬜ |
| REL-002 | Write `RELEASE_NOTES.md` for v6.1.0 | chore | 20 min | REL-001 | ⬜ |
| REL-003 | Squash merge `develop-v6` → `master` | chore | 15 min | REL-002 | ⬜ |
| REL-004 | Tag `v6.1.0` + publish GitHub (`veaf-build publish`) | chore | 30 min | REL-003 | ⬜ |

**Estimated total: ~85 min (~1h30)**

---

## Lot FEAT-DCS-BRIDGE — Optional dcs-bridge.lua injection

**Goal**: Allow the build tool to optionally inject `dcs-bridge.lua` into a DCS mission via a DO SCRIPT FILE trigger, controlled by a flag in `mission.yaml`.

**Branch**: `feature/dcs-bridge-injection` → PR → `develop-v6`

| # | Ticket | Files | Type | Effort | Status |
|---|--------|-------|------|--------|--------|
| DCSB-001 | Add optional `dcs_bridge.enabled` key (bool, default `false`) to the `mission.yaml` schema and `MissionConfig` dataclass | `src/defaults/mission-folder/mission.yaml`, `mission_config.py` | feat | 15 min | ✅ |
| DCSB-002 | Add optional `dcs_bridge.lua_path` key (path to `dcs-bridge.lua`; auto-detected from a well-known location if absent) | `mission_config.py` | feat | 15 min | ✅ |
| DCSB-003 | Copy `dcs-bridge.lua` into the build output and inject the DO SCRIPT FILE trigger into the mission | `mission_builder_worker.py` | feat | 30 min | ✅ |
| DCSB-004 | TDD tests: trigger injected when `enabled: true`, absent when `false`, error raised when file not found | `test/` | test | 20 min | ✅ |
| DCSB-005 | Document `dcs_bridge` section in the default `mission.yaml` and in the user documentation | `src/defaults/mission-folder/mission.yaml`, `doc/` | doc | 10 min | ✅ |

**Estimated total: ~1h30**
