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
| Lot RADIO-SPECS — DCS radio frequency validation | ~3h | ✅ |
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
| Lot 24 — DOC-REVIEW | ~2h45 | ✅ |
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
| Lot FIX-OLDSCRIPTS — detect residual .lua files in src/scripts/ | ~45 min | [archived](backlog-archive.md) |
| Lot FIX-MARKERS-INIT — add missing `veafMarkers.initialize()` | ~5 min | [archived](backlog-archive.md) |
| Lot FIX-MISSING-INIT — missing `initialize()` on 4 Lua modules | ~20 min | [archived](backlog-archive.md) |
| Lot 27 — DOC-FR-MERGE | ~6h | [archived](backlog-archive.md) |
| Lot FIX-YAML-SYNTAX — unhandled YAML error in build and mission_builder_worker | ~15 min | [archived](backlog-archive.md) |
| Lot FIX-MANDATORY-ENABLE — block enable on mandatory modules | ~20 min | [archived](backlog-archive.md) |
| Lot FEAT-CUSTOM-SCRIPTS — custom_scripts section in mission.yaml | ~45 min | ✅ |
| Lot FIX-REMOVE-CONVERT — remove the `convert` command | ~20 min | [archived](backlog-archive.md) |
| Lot FIX-MISSIONCONFIG-REFS — references to `missionConfig.lua` in doc and code | ~30 min | [archived](backlog-archive.md) |
| Lot FEAT-DCS-BRIDGE — Optional dcs-bridge.lua injection | ~1h30 | [archived](backlog-archive.md) |
| Lot FIX-MANDATORY-YAML — YAML generators: emit `{}` for mandatory modules instead of `enable: true` | ~35 min | [archived](backlog-archive.md) |
| Lot CMT-YAML-DOCS — doc comments and links in generated `mission.yaml` files | ~45 min | [archived](backlog-archive.md) |
| Lot FIX-AIRCRAFT-DUPLICATE — Duplicate aircraft groups in "add" injection mode | ~20 min | [archived](backlog-archive.md) |
| Lot FIX-I18N-CONVERT-V5 — Hardcoded English messages in convert-v5 | ~30 min | ✅ |
| Lot FIX-CONVERT-V5-PRESETS — Per-aircraft radio assignments in convert-v5 presets | ~45 min | ✅ |
| Lot FEAT-COMMUNITY-TOGGLE — Enable/disable community scripts from mission.yaml | ~2h | ✅ |
| Lot FIX-CONVERT-V5-DEFAULT-CWD — `convert-v5` uses current directory by default | ~5 min | ✅ |
| Lot FIX-SRS-WARN — false warning when SRS config file is absent | ~10 min | ✅ |
| Lot FIX-CTLD-NIL — nil crash on ctld.builtFOBS / ctld.logisticUnits in scheduled fns | ~15 min | ✅ |
| Lot I18N-COVERAGE — i18n coverage tests + fix remaining hardcoded English strings | ~2h30 | ✅ |
| Lot FIX-CONVERT-V5-LOG-DEFAULT — convert-v5 defaults global_log_level to debug instead of info | ~5 min | ✅ |
| Lot FIX-VERSIONS-YAML-ONLY — drop missions.yaml alias, use versions.yaml exclusively for weather pipeline | ~15 min | ✅ |
| Lot YAML-UX — Simplification syntaxe mission.yaml | ~8h | ✅ |
| Lot FIX-CONVERTER-YAML-I18N — Syntax header + i18n comments in convert-v5 output | ~45 min | ✅ |
| Lot FEAT-YAML-MODULE-UX — Module shorthand, uppercase community IDs, category sort | ~1h | ✅ |
| Lot FIX-BRIEFING-MULTILINE — convert-v5 truncates multi-line Lua briefings | ~45 min | ✅ |
| Lot FIX-I18N-HARDCODED — AST test + fix hardcoded strings in aircrafts_injector + lua_config_generator | ~1h | ✅ |
| Lot FIX-I18N-DEBT — Fix remaining 107 hardcoded strings across 25 files, clear _TODO_EXEMPTIONS | ~4h | ✅ |
| Lot DOC-OVERHAUL — Complete, detailed, bilingual, ELI5 documentation with diagrams + screenshots | ~12h | ✅ |
| Lot PREREL-BUGS — pre-release code review findings (briefing over-capture, exit codes, i18n, error handling) | ~2h | ⬜ |
| Lot UI-OUTPUT — Declutter CLI output (transient status line + chapter/technical tiers) | ~3h30 | ✅ |
| Lot FIX-CONVERT-V5-DEPS — resolve module dependencies when generating mission.yaml | ~45 min | ⬜ |
| **Total** | **~212h** | |

*Initial calibration factor: 1.15 — recalculate after each completed lot.*

---

## Lot FIX-CONVERT-V5-DEPS — resolve module dependencies when generating mission.yaml

**Goal**: When `convert-v5` generates `mission.yaml`, it does not resolve module dependencies. As a result, `veaf-tools build` later auto-enables missing dependencies at config-generation time and prints a warning (e.g. *"Module 'CASMISSION' requires 'GROUNDAI' which is not configured — auto-enabling 'GROUNDAI'"*). Since the converter just produced the file, it should pre-resolve dependencies so required modules are already enabled in the generated `mission.yaml` — no build-time warning, and the file accurately reflects what will run.

**Context**: The dependency graph `_MODULE_DEPS` and the resolver `_resolve_deps()` live in `veaf_libs/lua_config_generator.py` (e.g. `"CASMISSION": ["SPAWN", "GROUNDAI"]`). The converter writes the `modules:` section in `mission_builder/v5_converter.py` without consulting them.

**Branch**: handled on `feature/UI-OUTPUT` (per user request) — no separate branch.

| # | Ticket | Files | Type | Effort | Status |
|---|--------|-------|------|--------|--------|
| CVDEP-001 | Expose the dependency graph / resolver from `lua_config_generator.py` so the converter can reuse it (avoid duplicating `_MODULE_DEPS`) | `veaf_libs/lua_config_generator.py` | refactor | 15 min | ⬜ |
| CVDEP-002 | In `convert-v5` module generation, auto-enable required dependencies (transitively) and emit them explicitly in the generated `mission.yaml`; add a one-line note in the conversion report listing dependencies that were auto-added | `mission_builder/v5_converter.py`, `locales/*.json` | feat | 20 min | ⬜ |
| CVDEP-003 | TDD: a v5 folder enabling `CASMISSION` produces a `mission.yaml` with `GROUNDAI` (and `SPAWN`) enabled; `build` no longer prints the dependency auto-enable warning for it | `test/python/` | test | 10 min | ⬜ |

---

## Lot UI-OUTPUT — Declutter CLI output (transient status line + chapter/technical tiers)

**Goal**: Make `veaf-tools` (and later `veaf-tools-updater`) output readable. Low-importance progress messages scroll endlessly today. Introduce three output tiers: permanent technical lines, permanent chapter headers, and a single overwriting transient line for everything else (warnings/errors stay permanent). The full log file keeps every message. `--verbose` and non-interactive output fall back to the classic line-by-line display.

**Branch**: `feature/UI-OUTPUT` → PR → `develop-v6`

| # | Ticket | Files | Type | Effort | Status |
|---|--------|-------|------|--------|--------|
| UIOUT-001 | `StatusLine` helper: single overwriting Rich `Live` line, enable/disable, suspend for nested `Live` | `veaf_libs/console_status.py` | feat | 40 min | ✅ |
| UIOUT-002 | Wire into `Logger`: `info()` transient by default, add `tech()`/`step()`, `set_verbose` gates transient on TTY, `stop_status()` | `veaf_libs/logger.py` | feat | 30 min | ✅ |
| UIOUT-003 | Make `spinner_context`/`progress_context` suspend the status line and render transiently when active | `veaf_libs/progress.py` | feat | 20 min | ✅ |
| UIOUT-004 | Pilot `build`: promote pipeline headers to `step()`, key results to `tech()`; stop status line at program end | `veaf_tools/commands/build.py`, `veaf_tools/app.py`, `mission_builder/mission_builder_worker.py` | feat | 20 min | ✅ |
| UIOUT-005 | Unit tests for `StatusLine` and `Logger` routing | `test/python/veaf_libs/test_console_status.py`, `test_logger.py` | test | 30 min | ✅ |
| UIOUT-006 | Phase 2 — extend to `veaf-tools-updater` and `veaf-build`: `stop_status()` at program exit + promote outcome lines (`up_to_date`, `success`) to `tech()`. Standalone `veaf-tools` commands already inherit the model via `app.main()` + the shared logger/progress, so they needed no change. | `veaf-tools-updater.py`, `veaf_build/cli.py` | feat | 30 min | ✅ |

---

## Lot FIX-CONVERT-V5-PRESETS — Per-aircraft radio assignments in convert-v5 presets

**Goal**: Fix `convert-v5` so that per-aircraft radio specificity from `radioSettings` is preserved in the generated `presets.yaml`.

**Branch**: `fix/convert-v5-presets-per-aircraft` → PR #381 → `develop-v6`

| # | Ticket | Files | Type | Effort | Status |
|---|--------|-------|------|--------|--------|
| CVPRE-001 | Parse `radioSettings` table and detect per-aircraft radio layouts (warbird, VHF-primary, hardcoded) | `v5_pipeline_converters.py` | fix | 30 min | ✅ |
| CVPRE-002 | Auto-assign warbird and VHF-primary aircraft in `presets_assignments`; emit warnings for typePattern and hardcoded entries | `v5_pipeline_converters.py` | fix | 10 min | ✅ |
| CVPRE-003 | Add i18n messages for new warnings; add 28 unit tests | `locales/en.json`, `locales/fr.json`, `test_v5_pipeline_converters.py` | feat | 5 min | ✅ |
| CVPRE-004 | Support regex patterns as `unit_type` keys in `presets_assignments` (exact > pattern > `all`) | `presets_manager.py`, `test_presets.py` | feat | 20 min | ✅ |

---

## Lot FEAT-COMMUNITY-TOGGLE — Enable/disable community scripts from mission.yaml

**Goal**: Allow mission makers to individually enable or disable community Lua scripts (TUM, CTLD, CSAR, etc.) via a `community_scripts:` section in `mission.yaml`, analogous to the existing `lua_modules:` section.

**Branch**: `feature/community-toggle` → PR → `develop-v6`

| # | Ticket | Files | Type | Effort | Status |
|---|--------|-------|------|--------|--------|
| COMM-001 | Give each community script a stable ID (key) in `get_community_script_files()` — return `list[dict]` instead of `list[tuple]` | `mission_tools/mission_constants.py` | refactor | 15 min | ✅ |
| COMM-002 | Parse `community_scripts:` section in `MissionBuilderWorker.__init__`; filter the list of community scripts to inject based on `enabled:` flags | `mission_builder/mission_builder_worker.py` | feat | 30 min | ✅ |
| COMM-003 | Apply the filter in both static trigger (`insert_veaf_trigrules`) and dynamic trigger (`insert_veaf_triggers`) | `mission_builder/mission_builder_worker.py` | feat | 20 min | ✅ |
| COMM-004 | Add `community_scripts:` block to the default `mission.yaml` with all scripts listed and `enabled: true` by default, with comments | `src/defaults/mission-folder/mission.yaml` | doc | 15 min | ✅ |
| COMM-005 | Update YAML reference doc (`MISSION_YAML_REFERENCE.md` + `.en.md`) with the new section | `doc/MISSION_YAML_REFERENCE.md`, `doc/MISSION_YAML_REFERENCE.en.md` | doc | 20 min | ✅ |
| COMM-006 | TDD tests: verify that a script with `enabled: false` is absent from the injected triggers | `test/python/` | test | 20 min | ✅ |
| COMM-007 | `convert-v5`: detect community scripts present in `published/src/scripts/community/` and emit `community_scripts:` section in generated `mission.yaml` | `mission_builder/v5_converter.py`, `test_v5_converter.py` | feat | 20 min | ✅ |

---

## Lot FEAT-CUSTOM-SCRIPTS — custom_scripts section in mission.yaml

**Goal**: Allow declaring custom Lua scripts in `mission.yaml` to suppress warnings and control the generation of the DCS load trigger.

**Branch**: `feature/custom-scripts` → PR → `develop-v6`

| # | Ticket | Files | Type | Effort | Status |
|---|--------|-------|------|--------|--------|
| CUSTOM-001 | Add `CustomScript` dataclass + parse `custom_scripts` in `__init__` | `mission_builder_worker.py` | feat | 10 min | ✅ |
| CUSTOM-002 | Update warning logic (declared = info, unknown = warning with hint) | `mission_builder_worker.py` | feat | 10 min | ✅ |
| CUSTOM-003 | Filter load triggers according to `generate_load_trigger` | `mission_builder_worker.py` | feat | 10 min | ✅ |
| CUSTOM-004 | TDD tests (warnings + trigger resolution) | `test_mission_builder_defaults.py` | test | 10 min | ✅ |
| CUSTOM-005 | Document the section in the default `mission.yaml` | `src/defaults/mission-folder/mission.yaml` | doc | 5 min | ✅ |

---

## Lot 24 — DOC-REVIEW: Klogg profile (REV-002)

**Goal**: Commit the VEAF Klogg profile to the repo to ease DCS log reading.

**Context**: All other REV-* tickets from Lot 24 are archived. REV-002 is waiting for the user to provide the `.conf` file.

**Branch**: `fix/doc-review-klogg` → PR → `develop-v6`

| # | Ticket | Files | Type | Effort | Status |
|---|--------|-------|------|--------|--------|
| REV-002 | Commit the Klogg profile provided by the user to `tools/klogg/veaf.conf`; update the "Reading the log" section in `GUIDE.md` and `GUIDE.fr.md` to point to this file | `tools/klogg/veaf.conf`, `doc/mission-maker/GUIDE.md`, `doc/mission-maker/GUIDE.fr.md` | chore | 20 min | ✅ |

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
| REL-005 | Change doc URL prefix from `/dev/` to `/latest/` in `v5_converter.py` (`DOC_BASE`, `_DOC_BASE`) and `src/defaults/mission-folder/mission.yaml` | chore | 5 min | REL-003 | ⬜ |

**Estimated total: ~85 min (~1h30)**

---

## Lot RADIO-SPECS — DCS radio frequency validation in inject-presets

**Goal**: Extract DCS aircraft radio frequency specs from `dcs-lua-datamine`, bundle them as a YAML data file, validate preset frequencies at inject time, and publish a human-readable reference doc.
**Branch**: `feature/radio-specs-validation`

| # | Ticket | Type | Effort | Status |
|---|--------|------|--------|--------|
| RADIO-001 | Extraction script: fetch `panelRadio` from dcs-lua-datamine and generate `dcs-radio-specs.yaml` | feat | 45 min | ✅ |
| RADIO-002 | Bundle `dcs-radio-specs.yaml` as package data; load via `importlib.resources` | feat | 15 min | ✅ |
| RADIO-003 | `RadioFrequencyValidator`: validate preset frequencies against aircraft specs, warn on mismatch | feat | 45 min | ✅ |
| RADIO-004 | Integrate validator into `PresetsInjectorWorker.process_groups()` | feat | 20 min | ✅ |
| RADIO-005 | Generate `doc/mission-maker/dcs-radio-specs.md` (human-readable Markdown table) from the YAML | feat | 30 min | ✅ |
| RADIO-006 | Unit tests for validator (valid/invalid frequency, unknown aircraft, partial ranges) | feat | 45 min | ✅ |

**Estimated total: ~3h**

---

## Lot FIX-CONVERT-V5-DEFAULT-CWD — `convert-v5` uses current directory by default

**Goal**: Remove `no_args_is_help=True` from the `convert-v5` command so that invoking `veaf-tools convert-v5` with no arguments runs against the current working directory (the default `"."` already declared on `mission_folder`).

**Root cause**: `convert_v5.py:19` — `@app.command(no_args_is_help=True, ...)` overrides the `"."` default and shows help instead.

**Fix**: Change `no_args_is_help=True` → `no_args_is_help=False` (or remove the parameter entirely).

**Branch**: `fix/convert-v5-default-cwd` → PR → `develop-v6`

| # | Ticket | Files | Type | Effort | Status |
|---|--------|-------|------|--------|--------|
| CVCWD-001 | Remove `no_args_is_help=True` from `@app.command` decorator | `veaf_tools/commands/convert_v5.py` | fix | 5 min | ✅ |

---

## Lot FIX-SRS-WARN — false warning when SRS config file is absent

**Goal**: Suppress the spurious `W|initialize` warning emitted when SRS is not installed. SRS integration is optional; an absent config file is normal, not an error.

**Root cause**: `veafRadio.lua:932-934` — `loadfile(srsConfigPath)` returns `nil` both when the file **does not exist** and when it exists but is invalid. The code logs a `warn` in both cases. Users without SRS see this warning on every mission start.

**Fix**: Use `lfs.attributes(srsConfigPath)` (already available via `l_lfs`) to test for file existence before calling `loadfile`:
- File absent → `debug` log ("SRS config not found, SRS integration disabled")
- File present but `loadfile` returns `nil` → keep `warn` (actual corruption/syntax error)

**File**: `src/scripts/veaf/veafRadio.lua`, around line 920–934.

**Branch**: `fix/srs-warn` → PR → `develop-v6`

| # | Ticket | Files | Type | Effort | Status |
|---|--------|-------|------|--------|--------|
| SRS-001 | Check `lfs.attributes` before `loadfile`; downgrade absent-file log to `debug` | `src/scripts/veaf/veafRadio.lua` | fix | 10 min | ✅ |

---

## Lot FIX-CTLD-NIL — nil crash on ctld.builtFOBS / ctld.logisticUnits in scheduled fns

**Goal**: Fix `bad argument #1 to 'insert' (table expected, got nil)` crash in MIST scheduled functions when CTLD module table exists but its internal lists haven't been initialized yet (race condition on mission start).

**Root cause**: Three call sites guard only against `ctld` being falsy, but `ctld.builtFOBS` and `ctld.logisticUnits` are `nil` until `ctld.initialize()` runs. If a scheduled function fires before CTLD init completes, `table.insert` crashes.

| Site | File | Issue |
|------|------|-------|
| `veafGrass.lua:1003` | `if ctld then` | `ctld.builtFOBS` / `ctld.logisticUnits` may be nil |
| `veafSpawnGround.lua:182` | no guard | immediate crash if ctld not init |
| `veafSpawnEffects.lua:32` | `if ctld then` | `ctld.logisticUnits` may be nil |

**Fix**: extend all three guards to `if ctld and ctld.builtFOBS and ctld.logisticUnits then` (or equivalent per site).

**Branch**: `fix/ctld-nil` → PR → `develop-v6`

| # | Ticket | Files | Type | Effort | Status |
|---|--------|-------|------|--------|--------|
| CTLD-001 | Extend ctld guard in `veafGrass.lua` (~line 1003) | `src/scripts/veaf/veafGrass.lua` | fix | 5 min | ✅ |
| CTLD-002 | Add ctld guard in `veafSpawnGround.lua` (~line 182) | `src/scripts/veaf/veafSpawnGround.lua` | fix | 5 min | ✅ |
| CTLD-003 | Extend ctld guard in `veafSpawnEffects.lua` (~line 32) | `src/scripts/veaf/veafSpawnEffects.lua` | fix | 5 min | ✅ |

---

## Lot I18N-COVERAGE — i18n coverage tests + fix remaining hardcoded English strings

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

**Branch**: `fix/i18n-coverage` → PR → `develop-v6`

| # | Ticket | Files | Type | Effort | Status |
|---|--------|-------|------|--------|--------|
| I18N-COV-001 | Add test: all `t("key")` calls in `src/python/` reference a key that exists in `en.json` | `test/python/veaf_libs/test_i18n.py` | test | 20 min | ✅ |
| I18N-COV-002 | Add test: every key in `en.json` has a non-empty entry in `fr.json` | `test/python/veaf_libs/test_i18n.py` | test | 10 min | ✅ |
| I18N-COV-003 | Add i18n keys for `mission_builder_worker.py` hardcoded strings and replace with `t()` | `mission_builder/mission_builder_worker.py`, `locales/en.json`, `locales/fr.json` | fix | 20 min | ✅ |
| I18N-COV-004 | Add i18n keys for `aircrafts_injector_worker.py` hardcoded strings and replace with `t()` | `aircrafts_injector/aircrafts_injector_worker.py`, `locales/en.json`, `locales/fr.json` | fix | 45 min | ✅ |
| I18N-COV-005 | Add i18n keys for `lua_config_generator.py` and `waypoints_manager.py` hardcoded strings | `veaf_libs/lua_config_generator.py`, `waypoints_injector/waypoints_manager.py`, `locales/*.json` | fix | 15 min | ✅ |

---

## Lot FIX-VERSIONS-YAML-ONLY — drop missions.yaml alias for weather pipeline

**Goal**: Remove `missions.yaml` as an accepted alias for the weather pipeline config. `versions.yaml` is the only valid filename. Eliminates confusion with `mission.yaml`.

**Branch**: `feature/versions-yaml-only` → PR #386 → `develop-v6`

| # | Ticket | Files | Type | Effort | Status |
|---|--------|-------|------|--------|--------|
| VYO-001 | Remove `missions.yaml` from `V6_PIPELINE_CANDIDATES["weather"]` | `mission_builder/v5_converter.py` | fix | 2 min | ✅ |
| VYO-002 | Remove legacy WEATHER-001 coexistence guard from `mission_builder_worker.py` | `mission_builder/mission_builder_worker.py` | fix | 5 min | ✅ |
| VYO-003 | Update `build.py` `_step_file` call and `weather.py` CLI default | `veaf_tools/commands/build.py`, `veaf_tools/commands/weather.py` | fix | 2 min | ✅ |
| VYO-004 | Update `weather_injector_README.py` and pipeline reference docs | `weather_injector/weather_injector_README.py`, `doc/PIPELINE_REFERENCE*.md` | doc | 5 min | ✅ |
| VYO-005 | Drop obsolete test `test_versions_not_copied_when_missions_exists` | `test/python/mission_builder/test_mission_builder_defaults.py` | test | 1 min | ✅ |

----

## Lot YAML-UX — Simplification syntaxe mission.yaml

**Goal**: Rendre `mission.yaml` lisible et modifiable par des utilisateurs non-informaticiens. Réduire les pièges syntaxiques (deux mots-clés pour la même chose, `{}`, `[]` inline, guillemets inconsistants). Unifier `lua_modules` et `community_scripts` en un seul bloc `modules:`.

**Principes directeurs**:
- Un seul style par construction YAML
- Même syntaxe pour les modules VEAF et les scripts communautaires
- Guillemets uniquement quand nécessaire, règle documentée
- Les listes toujours en style bloc (`-`), jamais inline `[]`
- `true`/`false` seuls quand pas de config supplémentaire, bloc `enabled:` sinon

**Dépendances**: UX-001 → UX-002 → UX-003 (dans cet ordre). UX-004/005/006 indépendants.

**Branch**: `feature/yaml-ux` → PR → `develop-v6`

| # | Ticket | Description | Files | Type | Effort | Status |
|---|--------|-------------|-------|------|--------|--------|
| YAML-UX-001 | `MODULE: {}` → `MODULE:` (null = module obligatoire actif, plus lisible) | Remplacer la génération et le parsing de `{}` pour les modules obligatoires — `null` YAML est équivalent et moins cryptique | `lua_config_generator.py`, `mission_builder_worker.py`, template `mission.yaml`, `config_migrator.py` | feat | 45 min | ✅ |
| YAML-UX-002 | Unifier `enable`/`enabled` → `enabled` partout | `lua_modules` utilise `enable`, `community_scripts` et `dcs_bridge` utilisent `enabled` — standardiser sur `enabled`, lire l'ancienne clé avec warning de dépréciation | `lua_config_generator.py`, `mission_builder_worker.py`, `v5_converter.py`, docs, template | feat | 1h | ✅ |
| YAML-UX-003 | Fusionner `lua_modules` + `community_scripts` → `modules:` avec syntaxe unifiée | Un seul bloc `modules:` ; syntaxe : `MODULE: true`/`false` (scalaire) ou bloc avec `enabled:` + config ; rétrocompat `lua_modules`/`community_scripts` avec warning pendant 1 version | `lua_config_generator.py`, `mission_builder_worker.py`, `v5_converter.py`, `config_migrator.py`, tests, docs | feat | 3h | ✅ |
| YAML-UX-004 | Listes toujours en style bloc (`-`) dans fichiers générés et template | Supprimer `groups: ["A", "B"]` et `enemy_coalitions: [BLUE]` → style bloc dans tous les fichiers générés par `v5_converter.py` et `lua_config_generator.py` | `lua_config_generator.py`, `v5_converter.py`, template `mission.yaml` | feat | 30 min | ✅ |
| YAML-UX-005 | En-tête syntaxe YAML dans `mission.yaml` généré + template + doc | Ajouter un bloc commentaire en tête expliquant : indentation espaces, règle des guillemets, style liste bloc, booléens — aussi dans `doc/` | `lua_config_generator.py`, `v5_converter.py`, template `mission.yaml`, `doc/GUIDE*.md` | doc | 30 min | ✅ |
| YAML-UX-006 | `migrate-config` : migrer fichiers existants vers nouvelle syntaxe | Ajouter une migration dans `config_migrator.py` pour convertir `lua_modules`/`community_scripts` → `modules:`, `enable` → `enabled`, `{}` → null, listes inline → bloc | `config_migrator.py`, tests | feat | 1h | ✅ |

---

## Lot FEAT-YAML-MODULE-UX — Module shorthand, uppercase community IDs, category sort

**Goal**: Improve readability of the generated `mission.yaml` from `convert-v5`:
1. Simple enabled modules use `MODULE: true` shorthand instead of two-line `MODULE:\n  enabled: true`
2. Community script IDs displayed in uppercase (`MIST`, `STTS`…) like VEAF modules
3. Modules sorted by category (Infrastructure first, then Core / Features / Combat / External)

**Branch**: `feature/yaml-module-ux` → PR → `develop-v6`

| # | Ticket | Files | Type | Effort | Status |
|---|--------|-------|------|--------|--------|
| MUX-001 | `yaml_module_entry()`: add `has_config` param — emit `MODULE: true` when no extra config | `lua_config_generator.py` | feat | 10 min | ✅ |
| MUX-002 | v5_converter: pass `has_config=True` for modules with extracted data; sort by category | `v5_converter.py` | feat | 25 min | ✅ |
| MUX-003 | Community script keys uppercase in generated YAML; case-insensitive matching in parser | `v5_converter.py`, `mission_builder_worker.py` | feat | 15 min | ✅ |
| MUX-004 | Update tests | `test_v5_converter.py`, `test_lua_config_generator.py` | test | 10 min | ✅ |

---

## Lot FIX-BRIEFING-MULTILINE — convert-v5 truncates multi-line Lua briefings

**Goal**: `setBriefing("line1\n" .. "line2\n")` must produce a complete multiline string in `mission.yaml`; currently only the first fragment is captured and literal `\n` is not decoded to a real newline.

**Root causes**:
1. `config_migrator.py` regex `"([^"]*)"` stops at first `"..."` fragment — ignores Lua `..` concatenation.
2. Lua escape `\n` is kept as literal `\n` instead of being decoded to a real newline.
3. `_yaml_str()` in `v5_converter.py` does not handle strings containing real newlines.
4. CAP mission briefings emitted inline via `_yaml_str()` instead of block scalar.

**Branch**: `fix/briefing-multiline` → PR → `develop-v6`

| # | Ticket | Files | Type | Effort | Status |
|---|--------|-------|------|--------|--------|
| BML-001 | Add `_lua_extract_string()` helper + apply to 3 `setBriefing` extraction sites | `config_migrator.py` | fix | 15 min | ✅ |
| BML-002 | `_yaml_str()`: handle strings with real newlines; CAP mission briefing → block scalar | `v5_converter.py` | fix | 10 min | ✅ |
| BML-003 | Tests | `test_config_migrator.py` | test | 20 min | ✅ |

---

## Lot FIX-CONVERTER-YAML-I18N — Syntax header + i18n comments in convert-v5 output

**Goal**: Fix two regressions in the `mission.yaml` generated by `convert-v5`:
1. The YAML syntax quick-reference header is missing (only present in `generate-config` output, not in `convert-v5` output).
2. All comment strings in the generated file are hardcoded English regardless of the user locale.

**Branch**: `fix/converter-yaml-i18n` → PR → `develop-v6`

| # | Ticket | Files | Type | Effort | Status |
|---|--------|-------|------|--------|--------|
| CYI-001 | Convert `_YAML_SYNTAX_HEADER` constant → `yaml_syntax_header()` public function using `t()` | `lua_config_generator.py`, `en.json`, `fr.json` | fix | 10 min | ✅ |
| CYI-002 | Add `yaml_syntax_header()` call to `v5_converter._build_mission_yaml_lines()` | `v5_converter.py` | fix | 5 min | ✅ |
| CYI-003 | Replace all hardcoded English comment strings in `_build_mission_yaml_lines()` with `t()` | `v5_converter.py`, `en.json`, `fr.json` | fix | 25 min | ✅ |
| CYI-004 | Update tests for new output format | `test_v5_converter.py` | test | 5 min | ✅ |

---

## Lot FIX-CONVERT-V5-LOG-DEFAULT — convert-v5 defaults global_log_level to debug instead of info

**Goal**: Change the fallback value for `global_log_level` in the generated `mission.yaml` from `debug` to `info`, so missions converted with no prior log level set are not silently deployed in debug mode.

**Root cause**: `v5_converter.py:811` — `f"global_log_level: {extracted_ll or 'debug'}"`. When `missionConfig.lua` had no explicit log level, `extracted_ll` is `None` and the fallback is `'debug'`. The inline comment even warns *"Remove or set to 'info' before deploying to players"* — but the default does the opposite.

**Fix**: Change `'debug'` → `'info'` in the fallback.

**Branch**: `fix/convert-v5-log-default` → PR → `develop-v6`

| # | Ticket | Files | Type | Effort | Status |
|---|--------|-------|------|--------|--------|
| CVLOG-001 | Change fallback `'debug'` → `'info'` in `_build_mission_yaml_lines` | `src/python/veaf-tools/mission_builder/v5_converter.py` | fix | 5 min | ✅ |

---


## Lot FIX-I18N-HARDCODED — AST test + fix hardcoded strings in aircrafts_injector + lua_config_generator

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

---

## Lot FIX-I18N-DEBT — Clear remaining hardcoded-string debt

**Goal**: Fix all 107 hardcoded English strings in the 25 files currently listed in `_TODO_EXEMPTIONS`, add matching keys to `en.json`/`fr.json`, and remove every file from the exemption list so COV-003 enforces the whole codebase.

**Branch**: `fix/i18n-debt` → PR → `develop-v6`

| # | Ticket | Files | Type | Effort | Status |
|---|--------|-------|------|--------|--------|
| DEBT-001 | Fix `mission_builder_worker.py` (14 violations) | worker + locales | fix | 30 min | ⬜ |
| DEBT-002 | Fix `waypoints_injector_worker.py` (25 violations) | worker + locales | fix | 40 min | ⬜ |
| DEBT-003 | Fix `veaf_tools/commands/convert_v5.py` (12 violations) | command + locales | fix | 20 min | ⬜ |
| DEBT-004 | Fix `veaf_tools/commands/aircraft_groups.py` (7 violations) | command + locales | fix | 15 min | ⬜ |
| DEBT-005 | Fix `veaf_tools/commands/build.py` (5 violations) | command + locales | fix | 10 min | ⬜ |
| DEBT-006 | Fix `weather_injector/utils/lua_converter.py` (5 violations) | util + locales | fix | 10 min | ⬜ |
| DEBT-007 | Fix remaining small files (≤3 violations each): mission_extractor, mission_tools, presets_injector, veaf-tools-updater, veaf_libs/*, veaf_tools/commands (7 files), waypoints_manager, weather_injector/* | various + locales | fix | 45 min | ⬜ |
| DEBT-008 | Remove all 25 files from `_TODO_EXEMPTIONS` in test_i18n.py | test | 5 min | ⬜ |

---

## Lot DOC-OVERHAUL — Complete, detailed, bilingual, ELI5 documentation

**Goal**: Make the documentation complete, detailed, accessible, fully bilingual (FR/EN parity), with ELI5 explanations for non-dev audiences (pilots, mission makers), mermaid diagrams, and screenshot placeholders. Blocks the next develop-v6 release.

**Branch**: `feature/doc-overhaul` → PR → `develop-v6`

**Audit findings** (verified):
- FR systematically lags EN: LUA_API_REFERENCE −1077 lines, TOOLS_REFERENCE −346, pilot/GUIDE −103, veafAirWaves −131, veafCombatZone −103, others −20…−50
- Missing files: `veafInterpreter.md` (no FR → nav L105 404), `dcs-radio-specs.en.md` (no EN)
- Zero images/screenshots in 40 docs; mermaid only in developer docs
- Pilot guide not truly ELI5 (unexplained jargon: Lua framework, AWACS, IADS)
- Content errors: deprecated `enable:` examples, removed `convert` command listed, CSAR "not available" (false), dead URL in updater

| # | Ticket | Type | Effort | Status |
|---|--------|------|--------|--------|
| DOC-001 | Create `veafInterpreter.md` (FR) — fixes broken FR nav. (`dcs-radio-specs` EN parity deferred to DOC-005: file is hand-maintained, not purely generated) | fix | 30 min | ✅ |
| DOC-002 | Isolated content errors done: remove `convert`, CSAR note (FR+EN), dead updater URL, debug-logging section, CHANGELOG consolidation. (`enable:`→`enabled:` + `lua_modules:`→`modules:` across ~20 files folded into per-file DOC-005 passes) | fix | 45 min | ✅ |
| DOC-003 | Pilot guide rewritten (FR+EN): deduplicated, accessible, `_auth` standardized, mermaid F10 menu, screenshot placeholders; READMEs reviewed (already clean) | feat | 2h | ✅ |
| DOC-004 | Mission-maker GUIDE + MIGRATION_GUIDE (FR+EN): build-pipeline + v5→v6 mermaid diagrams, `modules:` block example, broken `GUIDE.fr.md` links fixed | feat | 2h | ✅ |
| DOC-005a | Mechanical syntax sweeps (`enable:`→`enabled:` ×62, `lua_modules:`→`modules:` ×56) + MISSION_YAML_REFERENCE unified `modules:` rewrite (FR+EN) | feat | 1h30 | ✅ |
| DOC-005b | Script docs FR→EN parity: veafAirWaves, veafCombatZone, veafQraManager, veafShortcuts, veafWeather, veafRadio (all now delta ≤10) + broken `.fr.md` links fixed | feat | 2h30 | ✅ |
| DOC-005c | Big references in-section depth parity: LUA_API_REFERENCE (~1050 l. across 5 API sections) + TOOLS_REFERENCE (~346 l.) + dcs-radio-specs FR prose | feat | 5h | ✅ |
| DOC-006 | Produce DCS screenshot capture list for the user | chore | 30 min | ✅ |

**Estimated total: ~12h**

### DOC-005c handoff brief (cold-start ready)

The remaining work is **in-section depth parity** — same headings in FR and EN, but the
FR has shorter descriptions / fewer code examples. Approach: for each section, read the
EN version, then expand the FR to match (translate the missing prose, tables, and code
blocks). Code blocks/identifiers stay identical; only prose is translated.

**Files and gaps (FR lines behind EN):**

| File | Gap | Where the gap is |
|------|-----|------------------|
| `doc/LUA_API_REFERENCE.md` | ~1050 | Core Infrastructure (−190), Unit & Group Management (−388), Mission Systems (−284), Infrastructure & Services (−102), Communication & Control (−90). Other sections already at parity. |
| `doc/TOOLS_REFERENCE.md` | ~346 | All sections present (translated headings); depth is thinner throughout the updater/publish/architecture sections. |
| `doc/mission-maker/dcs-radio-specs.md` | prose only | The frequency table is language-neutral and fine; only the header prose + the hand-written "Critical aircraft" section need a FR pass. NOTE: this file is **hand-maintained** beyond what `veaf_build/radio_specs_updater.py` generates — do not regenerate, edit by hand. |

**Conventions already established this lot (keep consistent):**
- Tone: sober, vouvoiement, jargon explained at first use (no childish analogies).
- YAML syntax in examples: unified `modules:` block, `enabled:` (never `enable:`), community scripts as uppercase IDs inside `modules:`.
- Auth command is `_auth [PASSWORD]` (canonical `veafSecurity.Keyphrase`); never `-login`.
- Cross-doc links use `*.md` (NOT `*.fr.md` / `*.en.md`) — mkdocs-static-i18n resolves the language. Several `.fr.md` links were already fixed; watch for more.
- Screenshot placeholders live under `doc/assets/img/<area>/`.
- Per-doc commits, verify parity with `wc -l` after each file.

**After DOC-005c:** update CHANGELOG, open PR `feature/doc-overhaul` → `develop-v6`,
then the user captures the screenshots listed in DOC-006 to drop into `doc/assets/img/`.

---

## Lot PREREL-BUGS — Pre-release code review findings

**Goal**: Fix bugs found during a verified pre-release code review (unrelated to the documentation lot). These block the next `develop-v6` release. B1 is a functional regression and should be fixed first.

**Branch**: `fix/prerel-bugs` → PR → `develop-v6` (Python changes; separate from the doc PR)

| # | Ticket | Type | Effort | Status |
|---|--------|------|--------|--------|
| PREREL-001 (B1) | **Regression** — `config_migrator.py` `_lua_extract_string()` over-collects quoted strings after `:setBriefing(`: a briefing absorbs following setter strings in the same call chain. Introduced by the multiline fix (PR #390), reproduced empirically. Fix: bound the search to the matching `)` of `:setBriefing(`. Add a regression test covering a chained `:setBriefing("..."):setX("...")` case. | fix | 1h | ⬜ |
| PREREL-002 (B2) | `mission_builder_worker.py` (~L339): `exit()` returns code 0 after a fatal error, so a failed build is reported as success. Use a non-zero exit code / raise. | fix | 20 min | ⬜ |
| PREREL-003 (B3/B4) | Hardcoded English in `mission_builder_worker.py`: ~L333-338 missing-files message and ~L1168 `"Injecting dcs-bridge.lua"` spinner must use `t()`; add FR translations to `fr.json`. | fix | 20 min | ⬜ |
| PREREL-004 (I1) | `paths.py`: replace `exit(-1)` with a raised exception (utility code should not call `exit()`; makes it testable). | fix | 15 min | ⬜ |
| PREREL-005 (cosmetic) | `v5_converter.py` (~L885): remove the dead `is None` branch (never reached). Low priority. | chore | 10 min | ⬜ |

**Estimated total: ~2h05**

---
