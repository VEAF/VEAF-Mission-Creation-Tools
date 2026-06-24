# Lot RC — v6.1.0 RC bug fixes

Status: ✅ done

**Goal**: Fix bugs discovered during RC testing before the final release.
**Branch**: `develop-v6` (direct commits — RC hotfixes)

| # | Ticket | Type | Effort | Status |
|---|--------|------|--------|--------|
| RC-001 | Fix `.\published\veaf-tools.exe` → `.\veaf-tools.exe` in `doc/mission-maker/MIGRATION_GUIDE.md` | fix | 10 min | ✅ |
| RC-002 | Bundle lupa in exe (`pyproject.toml` non-optional + `hiddenimports` in `.spec`) | fix | 20 min | ✅ |
| RC-003 | Fix version comparison (`5.103.3 > 6.1.0-rc1`) — strip pre-release suffix in `_version_tuple` | fix | 15 min | ✅ |
| RC-004 | Fix `No such command 'normalize'` — rewrite `src/build-scripts/build.cmd` with real command names | fix | 20 min | ✅ |
| RC-005 | Sync `published/build-scripts/build.cmd` to match `src/build-scripts/build.cmd` | fix | 10 min | ✅ |
| RC-006 | Fix wrong command names in `doc/MISSION_MAKER_GUIDE.md` and `doc/mission-maker/README.md` | fix | 20 min | ✅ |
| RC-007 | Fix `string.format("%s", veaf.lp(...))` crash in `veaf.lua` (4 occurrences in `getAirbaseLife`, `_endMission`, `_checkForEndMission`, `endMissionAt`) | fix | 20 min | ✅ |
| RC-008 | Fix `prepare` command distributing files from wrong root (`defaults/mission-folder/src/` → `defaults/mission-folder/`) | fix | 15 min | ✅ |
| RC-009 | Fix `complete_src_folder_with_defaults` looking at `published/defaults/` instead of `published/src/defaults/` | fix | 20 min | ✅ |
| RC-010 | Move default `mission.yaml` from `src/defaults/mission-folder/src/` to `src/defaults/mission-folder/` (root) so it lands at `<mission_folder>/mission.yaml` | fix | 10 min | ✅ |
| RC-011 | Fix `veaf-modules-config.lua` not loaded in dynamic mode — add conditional `loadfile` in "Mission scripts loading - dynamic" trigger | fix | 20 min | ✅ |
| RC-012 | `prepare` command: replace `typer.confirm` with `_ask_replace()` using `sys.stdin` (fix terminal blocking + add "A" yes-to-all option) | fix | 15 min | ✅ |
| RC-013 | `veaf-tools-updater` `_install_defaults`: add `mission.yaml` copy (root of `mission-folder/`) — missing from first-install bootstrap | fix | 10 min | ✅ |
| RC-014 | `prepare` command: replace `sys.stdin.readline()` with `msvcrt.getwch()` (single-char, no Enter required) — fix terminal blocking on Windows/ConPTY | fix | 15 min | ✅ |
| RC-015 | `veaf.Logger`: `getEffectiveLevel()` retournait une string, les méthodes de log comparaient `self.level` (number figé) → `ForcedLogLevel` ignoré à l'exécution. Fix: `getEffectiveLevel()` retourne un number, toutes les méthodes utilisent `self:getEffectiveLevel()` | fix | 20 min | ✅ |
| RC-016 | `veaf.lp()` inside `string.format()` crashes Lua 5.1 unconditionally — arguments are evaluated before the logger level guard runs. `veaf.lp()` returns a table; Lua 5.1 `string.format("%s", table)` does not call `__tostring`. Fix: replaced `veaf.lp()` with `veaf.p()` in all `string.format()` calls across 7 files (`veafCarrierOperations`, `veafCasMission`, `veafGroundAI`, `veafRemote`, `veafSanctuary`, `veafShortcuts`, `veafSpawn`) | fix | 30 min | ✅ |
| RC-017 | `veaf.lp()` used with `..` concatenation crashes Lua 5.1 unconditionally — same root cause as RC-016. Lua 5.1 does not call `__tostring` on `..` operands, so `"text=" .. veaf.lp(x)` throws *"attempt to concatenate a table value"*. Fix: converted 11 call sites in 4 files (`veafCarrierOperations`, `veafMove`, `veafRadio`, `veafUnits`) from `"label=" .. veaf.lp(x)` to `"label=%s", veaf.lp(x)` | fix | 20 min | ✅ |
| RC-018 | `veaf.getCountryForCoalition` returned nil for coalitions with no pre-placed units — `_initializeCountriesAndCoalitions` only read `mist.DBs.units` (pre-placed groups). Dynamic test missions have no RED pre-placed units → `countriesByCoalition["red"]` empty → nil passed to `mist.dynAdd` → *"Country not found: $1"* (MIST format placeholder for nil) → group not spawned → `Group.getByName():getController()` crashes. Fix: supplement with `country.id` + `coalition.getCountryCoalition()` DCS API (first attempt used `coalition.getCountries` which does not exist in DCS). Also fixed broken `_sortByImportance` comparator (returned nil instead of false). | fix | 35 min | ✅ |
| RC-019 | Pipeline auto-detection in `veaf-tools build`: after the base build, auto-detect and run optional injection steps based on file presence (`src/presets.yaml`, `src/waypoints.yaml`, `src/aircraft-templates.yaml`, `src/missions.yaml`). Configurable via new `pipeline:` section in `mission.yaml`. `build.cmd` template simplified to 2 commands (updater + build). | feat | 45 min | ✅ |
| RC-020 | `veaf-tools migrate-config` command: parses an existing `missionConfig.lua`, comments out `doFile()` calls for VEAF scripts (now injected by the builder), wraps bare `veafXxx.initialize()` calls in `if veafXxx then … end` guards, and outputs a `lua_modules:` YAML snippet showing which modules were found enabled. Implementation: `mission_builder/config_migrator.py` (`ConfigMigrator`, `MigrationResult`), exported from `mission_builder/__init__.py`, CLI command in `veaf-tools.py`. | feat | 40 min | ✅ |
| RC-021 | `veaf-tools convert-v5` command: single-pass v5→v6 mission folder conversion. (1) Scans for `missionConfig.lua` and pipeline config files (`presets.yaml`, `waypoints.yaml`, `aircraft-templates.yaml`, `missions.yaml`). (2) Migrates `missionConfig.lua` in-place via `ConfigMigrator` (creates `.bak` backup). (3) **Automatically converts v5 pipeline config files** to v6 YAML: `radioSettings.lua` → `presets.yaml` (channels + warbird), `weatherAndTime/` → `weather-config.yaml` (all versions incl. `realweather`), `wp.lua` → `waypoints.yaml`, aircraft JSON → `aircraft-templates.yaml`. ICAO code prompted once if a realweather version is detected. `--no-convert-pipeline` flag skips auto-conversion. (4) Generates `mission.yaml` with `lua_modules:` and `pipeline:` sections. (5) Prints Rich scan table + actions summary, saves full Markdown report. Implementation: `mission_builder/v5_pipeline_converters.py` (4 converters), `mission_builder/v5_converter.py` (`V5Converter`, `ConversionReport`, `PipelineFile` with `converted` field), CLI in `veaf-tools.py`. | feat | 120 min | ✅ |
| RC-022 | `convert-v5`: replace interactive stdin ICAO prompt with `--icao` CLI option — stdin prompt blocks when running in a non-interactive terminal (ConPTY / CI). Fix: add `--icao` Typer option, remove `Prompt.ask()` call, document in migration guides (EN + FR). | fix | 20 min | ✅ |
| RC-023 | `convert-v5`: complete i18n — raw key strings appeared in `convert-v5-report.md` when running the compiled `.exe`. Root cause: `veaf_libs/locales/` not bundled by PyInstaller (missing `--add-data` in `veaf_build/worker.py`). Fix: (1) bundle locales in `worker.py`, (2) expand `en.json`/`fr.json` to 155 keys (symmetric), (3) replace all hardcoded English strings in `to_markdown()` and `_convert_pipeline_files()` with `t()` calls, (4) remove unused `PIPELINE_LABELS` constant, (5) fix tests for language-sensitivity. PR #336. | fix | 60 min | ✅ |

**Estimated total: ~470 min**

---
