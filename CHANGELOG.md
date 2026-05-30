# Changelog

All notable changes to VEAF Mission Creation Tools are documented here.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
Versions follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

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
