# Changelog

All notable changes to VEAF Mission Creation Tools are documented here.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
Versions follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased] — develop-v6

### Added
- `plan-2026.05.16.md` — v6 restart plan and technical decisions
- `doc/backlog.md` — operational backlog with ticket estimates
- `doc/ROADMAP.md` — project roadmap
- `CHANGELOG.md` — this file
- `veaf.lp()` — lazy log argument proxy: arguments are only stringified when the active log level warrants it
- `mission.yaml: global_log_level` — replaces `--scripts-variant`; writes `veaf.ForcedLogLevel` in the generated `veaf-modules-config.lua`
- `--log-modules` option on `veaf-tools build` to selectively set log levels per module
- `.github/workflows/release.yml` — automated release on `published-v*` tag push (build + publish via GitHub Actions, zero manual intervention)
- `--ci` flag on `veaf-build publish` and `veaf-build build-and-publish` for non-interactive CI mode

### Changed
- Branch renamed from `develop/v6-new-build-system` to `develop-v6`
- `veaf.BaseLogLevel` default changed from `trace` to `info`
- All 1233 `veaf.p(` log-argument calls migrated to `veaf.lp(` across all Lua scripts
- Single build output (`veaf-scripts.lua`) — `veaf-scripts-debug.lua` / `veaf-scripts-trace.lua` variants removed
- `build-and-release.py`: removed build-time comment-out step and `_create_lua_variant_files()`
- `cliff.toml`: `tag_pattern` now matches both `published-v*` and `v*` tags

### Removed
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
