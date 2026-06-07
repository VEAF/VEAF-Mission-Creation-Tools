# Changelog

All notable changes to VEAF Mission Creation Tools are documented here.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
Versions follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

### Added
- `mission.yaml`: new `custom_scripts` section to declare custom Lua scripts in `src/scripts/` — declared scripts are included silently and can opt out of automatic DCS load-trigger generation with `generate_load_trigger: false` (global default or per-script override)

### Removed
- `convert` command removed — it was broken on v6 missions (crash on missing `missionConfig.lua`) and its purpose is fully covered by `extract` followed by `build`

### Fixed
- `lua_config_generator.py`: specifying `enable` (true or false) on a mandatory Lua module in `mission.yaml` now raises an error instead of silently overriding — mandatory modules are always active and cannot be enabled or disabled


- `build.py`, `mission_builder_worker.py`: catch `yaml.YAMLError` when loading `mission.yaml` — display a clear, localised error message (file, line, column, plain-language hint) instead of crashing with a Python traceback

### Documentation
- `MISSION_YAML_REFERENCE.md`, `MISSION_YAML_REFERENCE.en.md`: added "Syntax errors" section explaining the new error messages and common causes

### Changed
- `mkdocs.yml`, `docs.yml`: deploy documentation to `veaf.github.io/documentation/` (was `veaf.github.io/VEAF-Mission-Creation-Tools-v6/`)
- Documentation: French is now the default language; English (`*.en.md`) is the secondary language — all 35 documentation page pairs renamed accordingly
- `mkdocs.yml`: `fr` locale set as default, `en` as secondary
- `doc/mission-maker/scripts/veafSkynetIadsHelper.md`: complete rewrite — corrected API names (`veafSkynet.*`), added point defence modes, group integration modes, dynamic spawn, command centers, network deactivation, and deferred network access pattern
- `doc/mission-maker/scripts/veafQraManager.md`: added note on `veafQraManager.initialize()` requirement for dynamic slots
- `doc/mission-maker/scripts/veafCombatZone.md`: added radio menu security note, cleanup options, and display options
- `doc/mission-maker/scripts/veafRadio.md`: added practical callback examples (QRA start/stop, group destroy, DCS flag management)
- `doc/mission-maker/scripts/veafWeather.md`: added fog management section (static/animated/dynamic constants, trigger usage, chat commands)

---

## [6.3.3] — 2026-06-06

### Fixed
- `veafCacheManager.lua`, `veafTime.lua`, `veafUnits.lua`, `veafSkynetIadsMonitor.lua`: added missing `initialize()` function — the generated `veaf-config.lua` calls `<module>.initialize()` on every listed module; absence caused a DCS runtime crash (`attempt to call field 'initialize' (a nil value)`)

### Added
- `mission_builder_worker.py`: `complete_src_folder_with_defaults()` now warns when unexpected `.lua` files are found in `src/scripts/` (potential v5 residues that would be loaded as DCS mission scripts and may conflict with the bundled `veaf-scripts.lua`)
- `prepare.py`: `.gitignore` template added to `src/defaults/mission-folder/` — copied on `veaf-tools prepare` when absent; never overwritten (even with `--force`) to preserve user customizations
- `lua_config_generator.py`: `_MODULE_CATEGORIES` dict — groups modules into 4 tiers (Infrastructure, Core, Features, Combat) plus External; category comment headers (`-- ── Category ──`) are emitted in `veaf-config.lua` and (`# ── Category ──`) in the YAML template
- `lua_config_generator.py`: `_MANDATORY_MODULES` frozenset — if a mandatory module (UNITS, TIME, CACHE, EVENTS, MARKERS, COMMANDS) has `enable: false`, a warning is logged and the flag is ignored (module still generated)
- `lua_config_generator.py`: `_MODULE_DEPS` dict + `_resolve_deps()` — after building the effective module list, missing or disabled dependencies are auto-enabled in memory with a `logger.warning` per auto-added module; transitive chains are fully resolved; disk is never modified
- `src/defaults/mission-folder/mission.yaml`: `lua_modules:` comment block reordered to match category grouping; Infrastructure modules annotated as mandatory
- `veaf_libs/build_profiles.py`: new `resolve_profile(yaml_data, profile_name)` function — deep-merges a named profile from the `profiles:` section of `mission.yaml` onto the base config; lists are replaced, not concatenated; `profiles:` key is stripped from the effective config
- `mission_builder_worker.py`: `MissionBuilderWorker.__init__` now accepts `profile_name: str | None`; calls `resolve_profile` immediately after loading `mission.yaml`, before any other config resolution
- `veaf_tools/commands/build.py`: new `--profile` / `-p` option on `veaf-tools build` to select a named build profile at build time
- `src/defaults/mission-folder/mission.yaml`: new commented `profiles:` section with `TEST` and `SERVER` examples
- `doc/MISSION_YAML_REFERENCE.md` (+ `.fr.md`): new `profiles:` section; entry added to the Build Pipeline index
- `doc/mission-maker/GUIDE.md` (+ `.fr.md`): new "Build Profiles" section explaining `--profile` usage with an example
- `lua_config_generator.py`: CSAR YAML support — `external_modules.csar` in `mission.yaml` generates `csar.xxx` property assignments and `csar.initialize()` in `veaf-config.lua`, symmetric to the existing CTLD support
- `lua_config_generator.py`: CTLD block now wrapped in `if ctld then … end` guard and includes `ctld.initialize()` call — no more manual `ctld.initialize()` required in `mission-script.lua` when using YAML-first config
- `doc/mission-maker/GUIDE.md` (+ `.fr.md`): CSAR YAML-first configuration documented; Lua fallback sections kept for complex settings (e.g. `aircraftType` tables)
- `doc/developer/GUIDE.md` (+ `.fr.md`): new "Developer Mode" section documenting `dev_mode` / `scripts_path` — concept, activation priority chain, workflow
- `doc/MISSION_YAML_REFERENCE.md` (+ `.fr.md`): new `build:` section documenting `dev_mode` and `scripts_path` fields

### Fixed
- `lua_config_generator.py`: asset `description`, `name`, `information` fields containing `\n` or `"` now use Lua long-string syntax (`[[...]]`) instead of plain `"..."` — prevents Lua syntax error at mission load
- `mission_builder_worker.py`: `complete_src_folder_with_defaults()` no longer copies the default `versions.yaml` when a legacy `missions.yaml` already exists in `src/`; emits a warning prompting to rename it
- `mission_builder_worker.py`: added `missions.yaml` to `_DEFAULT_FILE_MODULE_MAP` (pipeline `weather`) — covers future orphan-warning cases
- `v5_converter.py`: migration backup now uses the original filename `missionConfig.lua` instead of `missionConfig.lua.bak` — consistent with all other backup files in `backup_v5/`
- `mission_builder_worker.py`: `_DEFAULT_FILE_MODULE_MAP` no longer includes `presets.md`; corresponding default file `src/defaults/mission-folder/src/presets.md` deleted — docs are online, silent file creation was undesirable
- `build.py`: warn when `src/aircraft-templates.yaml` exists in the mission folder but the `aircraft_groups` pipeline step is disabled or skipped

---

## [6.3.2] — 2026-06-05

### Added
- `pyproject.toml` + `veaf_tools/app.py`: point d'entrée Poetry `veaf-tools` (équivalent à l'exe) avec affichage de la version au démarrage
- `veaf-tools.py`, `veaf-tools-updater.py`: pause automatique en fin d'exécution quand lancé par double-clic (détection par remontée de l'arbre de processus Windows, compatible PyInstaller one-file)

### Fixed
- `aircrafts_injector_worker.py`: lookup de country case-insensitive + préservation du champ `id` DCS lors de la création d'une country → empêche le crash `attempt to index field '?' (a nil value)` dans `me_mission.lua:fixCountriesNames` au chargement de mission

---

## [6.3.0] — 2026-05-31

### Added
- `veaf.initialize()`: nil-check for `veafCommands` with a clear error message if using outdated `veaf-scripts.lua` (IMC-010)
- `doc/MISSION_YAML_REFERENCE.md`: new intro section distinguishing build-pipeline YAML files from runtime `mission.yaml` config, with an ASCII tree diagram (IMC-007)
- Tests for `_is_double_clicked()` (IMC-001), annotated content in `ConversionReport.to_markdown()` (IMC-002), `complete_src_folder_with_defaults()` filtering and orphan warning (IMC-008), and `luadata._sort()` mixed-key crash (SORT-001)

### Fixed
- `luadata.serializer.serialize._sort()`: crash `TypeError: '<' not supported between instances of 'int' and 'str'` when sorting a Lua table with mixed integer and string keys (regression seen during v5 → v6 mission conversion) (SORT-001)

### Changed
- `veaf-tools convert-v5`: annotated `missionConfig.lua` is now embedded as a code block in `convert-v5-report.md` instead of being written to `backup_v5/src/scripts/missionConfig.lua`; a `README.txt` is added to `backup_v5/` explaining its contents (IMC-002)
- `veaf-tools build`: auto-pauses before exit when launched by double-click (Explorer.exe parent process) without an explicit `--pause`/`--no-pause` flag — no pause in CI or piped output (IMC-001)
- `complete_src_folder_with_defaults()`: skips copying a default file when its associated pipeline step or Lua module is disabled in `mission.yaml`; emits a warning if the now-orphan file already exists in the mission folder (IMC-008)

### Removed
- `src/defaults/mission-folder/src/README-versions.md` — stray documentation file removed from the defaults folder (IMC-003)

---

## [6.2.0] — 2026-05-30

### Added
- `veafCommands.lua` — central priority-ordered command dispatcher for F10 markers and interpreter path; exposes `registerCommandHandler(fn, priority)` and priority constants (`PRIORITY_SHORTCUTS`…`PRIORITY_REMOTE`)
- `veafSpawnParser.lua` — spawn command text parser extracted from `veafSpawnCore.lua` (`convertLaserToFreq`, `markTextAnalysis`)
- `veafRemote.registerRemoteModule(name, fn)` — registry for hook-server remote commands (replaces hardcoded if/elseif in `executeCommandFromRemote`)
- `backlog.md` — operational backlog with ticket estimates
- `doc/ROADMAP.md` — project roadmap
- `CHANGELOG.md` — this file
- `veaf.lp()` — lazy log argument proxy: arguments are only stringified when the active log level warrants it
- `mission.yaml: global_log_level` — replaces `--scripts-variant`; writes `veaf.ForcedLogLevel` in the generated `veaf-modules-config.lua`
- `--log-modules` option on `veaf-tools build` to selectively set log levels per module
- `.github/workflows/release.yml` — automated release on `published-v*` tag push (build + publish via GitHub Actions, zero manual intervention)
- `--ci` flag on `veaf-build publish` and `veaf-build build-and-publish` for non-interactive CI mode
- `veaf_tools/_version.py` committed stub — version injected by `worker.py` at PyInstaller build time, restored to `"unknown"` after; `app.py` and `veaf-tools-updater.py` resolve `VERSION` via `importlib.metadata` then `_version.__version__` fallback (VER-001)
- `about` command now prints `veaf-tools vX.Y.Z` before VEAF info (VER-003)
- Windows PE version metadata (FILE_VERSION / PRODUCT_VERSION) embedded in `veaf-tools.exe` and `veaf-tools-updater.exe` via `VSVersionInfo` generated dynamically at build time (VER-002)
- `ConfigMigrator` test coverage: integration tests on real fixtures (`mission-builder` and `demo-mission`) + unit tests for all 9 extractors previously untested (MIG-001, MIG-002)
- `doc/PIPELINE_REFERENCE.md` (+ `.fr.md`) — full YAML reference for all 4 pipeline steps (presets, waypoints, aircraft groups, weather/time) (DOC-001)
- `doc/MISSION_YAML_REFERENCE.md` (+ `.fr.md`) — hub page for `mission.yaml` top-level sections; category index and module index (DOC-002)
- `## Configuration (mission.yaml)` sections added to: `veafRadio`, `veafShortcuts`, `veafNamedPoints`, `veafCarrierOperations`, `veafAssets`, `veafSanctuary`, `veafCombatZone`, `veafAirWaves`, `veafQraManager`, `veafCasMission` (DOC-003 to DOC-006)
- `doc/mission-maker/scripts/veafRadio.fr.md` — created (was missing) (DOC-003)
- Module index in `MISSION_YAML_REFERENCE.md` completed with direct anchored links to every module's YAML section (DOC-007)
- `doc/index.md` (+ `.fr.md`) — hook sentence added before role table; `flowchart LR` → `flowchart TD` (REV-007)
- `doc/mission-maker/GUIDE.md` (+ `.fr.md`) — DCS Mission Editor added to prerequisites; base mission requirement (blue + red ground group) documented; Notepad++ listed as recommended editor (REV-008)
- `doc/mission-maker/GUIDE.md` (+ `.fr.md`) — CTLD/CSAR section: YAML-first approach via `external_modules.ctld` documented; CSAR YAML config noted as planned; `Intégration CTLD et CSAR` section added to French guide (was missing) (REV-010)
- `doc/mission-maker/MIGRATION_GUIDE.md` (+ `.fr.md`) — "Common Issues": refs to `missionConfig.lua` replaced by `mission.yaml` YAML config; "Reading the logs" entry added (Klogg + Notepad++) (REV-004)

### Changed
- `veaf_build/lua_tests.py`: `Optional[str]` migrated to `str | None` (UP007 now enforced)
- `pyproject.toml`: `UP007` removed from ruff ignore list — `str | None` union syntax enforced across all Python files
- `pyproject.toml`: `testpaths` changed to `["test/python"]` — test discovery now targets the new location
- 28 `test_*.py` files moved from `src/python/veaf-tools/**` to `test/python/**` — mirrors `test/lua/` convention (TST-001)
- `veaf_libs/paths.py`: `resolve_mission_file` glob branch now returns `.resolve()` path — fixes Windows short-path comparison
- `src/defaults/mission-folder/mission.yaml`: `versions.yaml` is now the canonical filename for the weather pipeline step; `missions.yaml` noted as legacy alias (REV-001)
- `src/python/veaf-tools/veaf_libs/lua_config_generator.py`: generated `mission.yaml` template comment updated to `versions.yaml` (REV-001)
- `doc/mission-maker/GUIDE.md` (+ `.fr.md`) — "Typical Build Workflow" simplified to `veaf-tools.exe build`; individual inject-* commands moved to collapsible Advanced section (REV-006)

### Changed (Shortcuts, Spawn, NamedPoints, CasMission, Security, Move, Radio, Remote) self-register via `veafCommands.registerCommandHandler()` — per-module `onEventMarkChange` functions removed
- Developer Guide (`doc/developer/GUIDE.md` + `.fr.md`) — Mermaid architecture diagram and runtime logging section updated to reference `veaf-config.lua` and `mission-script.lua` (v6) instead of the v5 `missionconfig.lua` (DOC-008)
- `veafInterpreter.execute()` delegates to `veafCommands.execute()` — hardcoded 8-branch if/elseif removed
- `mission_tools.DcsMission` — added `Group` dataclass and `iter_groups()` iterator; all injectors now share a single traversal path (DEEP-001)
- `mission_tools.DcsMission` — added `get_weather()` / `set_weather()` / `get_options()` / `set_options()` accessors; `WeatherInjectorWorker` updated to use them (DEEP-002)
- `WaypointsInjectorWorker`, `PresetsInjectorWorker` — local group traversal removed; now delegated to `DcsMission.iter_groups()` (DEEP-003)
- `veafCommands.lua` — added `PRIORITY_GROUNDAI = 62` constant (DEEP-005)
- `veafGroundAI.initialize()` — migrated from `veafMarkers.registerEventHandler` to `veafCommands.registerCommandHandler` at `PRIORITY_GROUNDAI` (DEEP-005)
- `veafSpawnParser.markTextAnalysis()` — common option defaults now in a single header block; type-specific defaults moved into their respective IF/ELSEIF branches (DEEP-006)
- `MissionBuilderWorker.__init__()` — now reads `mission.yaml`, resolves `dev_mode` / `scripts_path` from priority chain (CLI override > YAML > user config), and applies `log_modules_filter`; `build.py` simplified from ~180 to ~110 lines (DEEP-007)

### Added
- `veaf_libs.GroupInjectorWorker` — abstract base class for group-iterating injectors; `PresetsInjectorWorker` and `WaypointsInjectorWorker` now inherit from it (DEEP-004)
- `veafSpawnCore.lua` reduced from ~1834 to ~900 lines: parser extracted; 25-branch if/elseif replaced by handler dispatch loop
- `veafSpawnGround`, `veafSpawnAircraft`, `veafSpawnEffects` sub-modules self-register their spawn handlers via `veafSpawn.registerCommandHandler()`
- 7 remote modules self-register via `veafRemote.registerRemoteModule()` — hardcoded switch in `executeCommandFromRemote` removed
- Branch renamed from `develop/v6-new-build-system` to `develop-v6`
- `veaf.BaseLogLevel` default changed from `trace` to `info`
- All 1233 `veaf.p(` log-argument calls migrated to `veaf.lp(` across all Lua scripts
- Single build output (`veaf-scripts.lua`) — `veaf-scripts-debug.lua` / `veaf-scripts-trace.lua` variants removed
- `build-and-release.py`: removed build-time comment-out step and `_create_lua_variant_files()`
- `cliff.toml`: `tag_pattern` now matches both `published-v*` and `v*` tags

### Removed
- `module.onEventMarkChange()` functions from all 8 command modules (routing now handled by `veafCommands`)
- Hardcoded 8-branch command dispatch in `veafInterpreter.execute()`
- Hardcoded 25-branch if/elseif in `veafSpawnCore.executeCommand()`
- Hardcoded module switch in `veafRemote.executeCommandFromRemote()`
- `--scripts-variant` option from `veaf-tools build` and `veaf-tools convert`
- `.github/workflows/changelog.yml` — superseded by `release.yml`

---

## [6.0.5] — 2025-12-10

### Added
- Waypoint extractor and injector commands (`extract-waypoints`, `inject-waypoints`)
- Lua script debug and trace variants for enhanced mission development
- Option to hide radio menus for mission creators
- Defaults included in published artifacts for better out-of-the-box experience
- Confirmation prompt before overwriting `RELEASE_NOTES.md` during build

### Changed
- IADS package is now optional — missions that don't require IADS can omit it
- Refactored script file handling using `DEFAULT_SCRIPTS_LOCATION` constant for improved consistency
- Improved logging levels in Lua scripts for better clarity during development
- Streamlined mission conversion with better path management and error signaling
- Improved error signaling for missing VEAF and community script files

### Fixed
- File locking issues during updater operations
- Script path handling in mission builder
- CI: StyLua CRLF → LF line ending fix for cross-platform CI

---

## [6.0.2] — 2025-11-12

### Added
- Centralized `veaf_libs` module for logging and progress management (shared across all tools)

### Changed
- Migrated logging and progress management from individual tools to `veaf_libs`
- Updated version to 6.0.2

### Fixed
- Bug corrections in presets injector

---

## [6.0.1] — 2025-10-27

### Added
- `--pause` option on all commands — keeps the terminal open after execution for review

---

## [6.0.0] — 2025-10-26

### Added
- New `veaf-tools` CLI with 11 commands: `build`, `extract`, `convert`, `inject-presets`, `extract-aircraft-groups`, `inject-aircraft-groups`, `extract-waypoints`, `inject-waypoints`, `inject-weather`, `about`
- Auto-update mechanism via `veaf-tools-updater.exe`
- Radio presets injector with kneeboard image generation (PNG)
- Aircraft groups extractor and injector
- Weather injector (YAML-driven)
- Scripts injector — injects VEAF Lua scripts into missions
- Mission normalizer — deterministic Lua serialization to minimize diff noise
- Mission converter — converts legacy missions to v6 format
- Persian Gulf airport frequencies
- Documentation restructured into `doc/` folder by audience (pilot, mission maker, developer)
- GitHub Actions CI: `lua-unit-tests` + `stylua-check` jobs
- 31 Lua test suites (~915 tests) with `luaunit`, `dcs_mocks.lua`, `run_tests.ps1`

### Changed
- Reworked publication mechanism — `build-and-release.py` now orchestrates the full pipeline
- Refactored build and release: removed `published/` directory handling in favor of local ZIP artifacts
- Enhanced logging and error reporting throughout

### Fixed
- Trigger insertion method rewrite for reliability
- Normalizer sort key stability
- Presets injector: no duplicate kneeboard image files, inject only into human units

---

## v5.x

See git tags (`v5.80.0` → `v5.103.3`) for full v5 history.
Last v5 release: **v5.103.3**.
