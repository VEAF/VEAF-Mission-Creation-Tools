# Changelog

All notable changes to VEAF Mission Creation Tools are documented here.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
Versions follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased] — develop-v6

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

### Changed
- `veaf_build/lua_tests.py`: `Optional[str]` migrated to `str | None` (UP007 now enforced)
- `pyproject.toml`: `UP007` removed from ruff ignore list — `str | None` union syntax enforced across all Python files

### Changed (Shortcuts, Spawn, NamedPoints, CasMission, Security, Move, Radio, Remote) self-register via `veafCommands.registerCommandHandler()` — per-module `onEventMarkChange` functions removed
- `veafInterpreter.execute()` delegates to `veafCommands.execute()` — hardcoded 8-branch if/elseif removed
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
