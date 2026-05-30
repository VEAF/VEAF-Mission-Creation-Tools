# VEAF Mission Creation Tools — v6.2.0

**Release Date:** 2026-05-30

## Highlights

- **Complete YAML configuration documentation** — every `mission.yaml` section now has a reference page
- **Architectural deepening** — internal refactoring improves tool reliability and lays the ground for future features
- **Version visibility** — `about` command shows tool version; Windows `.exe` files display version in file properties
- **ConfigMigrator hardened** — integration tests + unit tests for all 9 extractors ensure `convert-v5` reliably converts real missions

---

## For Mission Makers

### Documentation

The documentation has been significantly expanded. Two new reference pages cover every configurable option:

- **[`PIPELINE_REFERENCE.md`](doc/PIPELINE_REFERENCE.md)** — full YAML reference for all 4 pipeline steps: radio presets, waypoints, aircraft groups, and weather/time variants.
- **[`MISSION_YAML_REFERENCE.md`](doc/MISSION_YAML_REFERENCE.md)** — hub page for `mission.yaml` top-level sections, with a category index and a module index linking directly to each module's YAML configuration block.

Ten Lua modules now have a dedicated **"Configuration (mission.yaml)"** section in their reference pages: `veafRadio`, `veafShortcuts`, `veafNamedPoints`, `veafCarrierOperations`, `veafAssets`, `veafSanctuary`, `veafCombatZone`, `veafAirWaves`, `veafQraManager`, `veafCasMission`.

Other documentation improvements:
- `doc/mission-maker/GUIDE.md` — DCS Mission Editor added to prerequisites; base mission requirements documented; Notepad++ recommended; CTLD/CSAR YAML-first approach documented.
- `doc/mission-maker/MIGRATION_GUIDE.md` — "Common Issues" section updated for v6; "Reading the logs" entry added (Klogg + Notepad++).
- Developer Guide (`doc/developer/GUIDE.md`) — architecture diagram updated for `veaf-config.lua` / `mission-script.lua`.

### veaf-tools CLI

- **`veaf-tools about`** now prints the tool version (`veaf-tools v6.2.0`) before VEAF information.
- **Windows file properties**: `veaf-tools.exe` and `veaf-tools-updater.exe` now embed `FILE_VERSION` / `PRODUCT_VERSION` metadata — visible in the Windows Explorer "Details" tab.

### Compatibility

No breaking changes. All existing `mission.yaml` files and `mission-script.lua` scripts continue to work without modification.

---

## For Lua Script Developers

### `veafCommands.lua` — Central Command Dispatcher

A new module `veafCommands.lua` replaces the hardcoded `if/elseif` chains in `veafInterpreter.execute()`. Modules self-register via `veafCommands.registerCommandHandler(fn, priority)` and are dispatched in priority order. This makes adding new command sources trivial without touching the interpreter.

Priority constants: `PRIORITY_SHORTCUTS`, `PRIORITY_SPAWN`, `PRIORITY_NAMEDPOINTS`, `PRIORITY_CASMISSION`, `PRIORITY_SECURITY`, `PRIORITY_MOVE`, `PRIORITY_GROUNDAI`, `PRIORITY_RADIO`, `PRIORITY_REMOTE`.

The 8 existing command modules (`veafShortcuts`, `veafSpawn`, `veafNamedPoints`, `veafCasMission`, `veafSecurity`, `veafMove`, `veafGroundAI`, `veafRadio`, `veafRemote`) all self-register during `initialize()` — no visible change for mission makers.

### `veafSpawnCore.lua` — Reduced from 1834 to ~900 Lines

The spawn command handler dispatch is now registry-based. `veafSpawnGround`, `veafSpawnAircraft`, and `veafSpawnEffects` sub-modules self-register their handlers via `veafSpawn.registerCommandHandler()`. The 25-branch `if/elseif` in `executeCommand` is gone.

### `veafRemote.lua` — Remote Module Registry

7 remote modules now self-register via `veafRemote.registerRemoteModule(name, fn)`. The hardcoded string switch in `executeCommandFromRemote` is removed.

---

## For Python Tool Developers

### `DcsMission` — Unified Data Model

- `Group` dataclass and `iter_groups()` iterator added — all injectors now share a single traversal path.
- `get_weather()` / `set_weather()` / `get_options()` / `set_options()` accessors added — `WeatherInjectorWorker` updated to use them.

### `GroupInjectorWorker` — Abstract Base Class

New `veaf_libs.GroupInjectorWorker` abstract class for group-iterating injectors. `PresetsInjectorWorker` and `WaypointsInjectorWorker` now inherit from it, eliminating duplicated traversal logic (DEEP-004).

### `MissionBuilderWorker` — Simplified

`build.py` reduced from ~180 to ~110 lines. `MissionBuilderWorker.__init__()` now reads `mission.yaml` and resolves `dev_mode` / `scripts_path` / `log_modules_filter` from the priority chain (CLI override > YAML > user config).

### Test Infrastructure

- 28 `test_*.py` files moved from `src/python/veaf-tools/**` to `test/python/` — mirrors the `test/lua/` convention.
- `ConfigMigrator` now has integration tests on real fixtures (`mission-builder` and `demo-mission`) and unit tests for all 9 previously untested extractors.
- `UP007` (`Optional[str]` → `str | None`) now enforced across all Python files.

---

## Full Changelog

See [CHANGELOG.md](CHANGELOG.md) for the complete list of changes.

## What's New

### Lua Runtime

- **`veaf.lp()` — lazy log proxy**: log arguments are only stringified when the active log level
  warrants it, eliminating unnecessary `veaf.p()` calls at runtime. All 1233 call sites migrated.
- **Runtime log control** (`global_log_level` in `mission.yaml`): replaces the old `--scripts-variant`
  build option. Set `global_log_level: info` (default), `debug`, or `trace` per mission without
  rebuilding. Writes `veaf.ForcedLogLevel` into the generated `veaf-modules-config.lua`.
- **Per-module configuration system** (`veaf.config`): each Lua module registers its own default
  config on load. Missions can now override settings (including `enable = false` to disable a module
  entirely) via a `missionconfig.lua` file — fully backward compatible with existing missions.
- **Deferred module initialization**: startup sequence is now `load → missionconfig → initialize`,
  allowing `missionconfig.lua` to apply overrides before any module runs its `init()`.
- **Single build output**: `veaf-scripts.lua` is the only output file. The `veaf-scripts-debug.lua`
  and `veaf-scripts-trace.lua` variants are removed — log level is now controlled at runtime.

### veaf-tools CLI

- **Version check on startup**: `veaf-tools` checks GitHub for a newer release on every run
  (2-second timeout, non-blocking). Displays a colored prompt with `veaf-tools-updater update` if
  an update is available.
- **Centralized `~/.veaf/` directory** (`VEAF_HOME`): logs, preferences, and installed scripts now
  live in a single directory. Override with the `VEAF_HOME` environment variable.
- **Interactive mode** (InquirerPy): running `veaf-tools` with no arguments opens a guided
  interactive prompt instead of showing help. Remembers the last-used values per command in
  `~/.veaf/preferences.json`.
- **`generate-config` command**: generates a fully-documented `missionconfig.lua` template for a
  mission, with all module options and their default values.
- **Module selection in `mission.yaml`**: list which Lua modules to enable and configure them
  directly in the mission's YAML file — `veaf-tools build` converts this to a `missionconfig.lua`
  injected into the `.miz`.
- **`--log-modules` option** on `build` and `inject-*` commands: selectively override log levels
  per module (e.g. `--log-modules spawn=debug,radio=error`).
- **Lua module list embedded in the exe**: `veaf-tools about --modules` shows a Rich table of all
  bundled Lua modules with their IDs and versions.

### Developer / Build System

- **`veaf-build` CLI** (Poetry entry point): `poetry run veaf-build build/publish` replaces
  `python build-and-release.py`. Source refactored into `veaf_build/` (cli, worker, github modules).
- **Python quality gate**: ruff (lint + format), mypy, and pytest run in CI on every push.
- **DCS units reference doc**: `dcs-units-reference.md` generated automatically from `dcsUnits.lua`
  during the build and included in the release ZIP.

## Bug Fixes

- **RC-012/014 — `prepare` command blocked on Windows/ConPTY**: replaced `typer.confirm` /
  `sys.stdin.readline` with `msvcrt.getwch()` for single-character, no-Enter-required input.
  Added "A" (yes-to-all) option to skip all remaining overwrite prompts at once.
- **RC-013 — `mission.yaml` not copied on first install**: `veaf-tools-updater`
  `_install_defaults()` now copies `mission.yaml` from `src/defaults/mission-folder/` to the
  mission root on first install (or `--init`).
- **RC-015 — `veaf.ForcedLogLevel` had no runtime effect**: `Logger.getEffectiveLevel()` now
  returns the numeric forced level at call time; all log methods use `self:getEffectiveLevel()`
  instead of the frozen `self.level`.
- **RC-016 — `veaf.lp()` inside `string.format()` crashed Lua 5.1 unconditionally**:
  `veaf.lp()` returns a table with `__tostring`; Lua 5.1 does not call `__tostring` from
  `string.format`, so the call throws *"bad argument #N to 'format' (string expected, got table)"*
  **before** the logger's level guard runs. Fixed in 7 files
  (`veafCarrierOperations`, `veafCasMission`, `veafGroundAI`, `veafRemote`, `veafSanctuary`,
  `veafShortcuts`, `veafSpawn`) by replacing `veaf.lp()` with `veaf.p()` inside all
  `string.format()` calls.
- **RC-017 — `veaf.lp()` used with `..` concatenation crashed Lua 5.1 unconditionally**:
  same root cause as RC-016 — Lua 5.1 does not call `__tostring` when evaluating `..` operands,
  so `"text=" .. veaf.lp(x)` throws *"attempt to concatenate a table value"* unconditionally.
  Fixed in 4 files (`veafCarrierOperations`, `veafMove`, `veafRadio`, `veafUnits`) — 11 call sites —
  by converting `"label=" .. veaf.lp(x)` to the proper form `"label=%s", veaf.lp(x)` so the lazy
  proxy is passed as a direct logger argument.
- **RC-018 — `mist.dynAdd` failed with nil country in dynamic-spawn missions**: `veaf.getCountryForCoalition`
  relied solely on `mist.DBs.units` (pre-placed unit groups) to discover which countries belong to
  each coalition. Missions that spawn everything dynamically (no pre-placed units) had no entries for
  the "red" or "blue" coalition, causing `getCountryForCoalition` to return `nil` → MIST logged
  *"Country not found: $1"* and the subsequent `Group.getByName():getController()` crashed with
  *"attempt to index a nil value"*. Fixed by supplementing the initialization with
  `coalition.getCountries()` + `country.name` (DCS API), which returns all countries in each coalition
  regardless of pre-placed units. Also fixed the `_sortByImportance` comparator (was returning `nil`
  instead of `false`, violating Lua 5.1 table.sort requirements).
  *(Note: first fix attempt used `coalition.getCountries` which does not exist in DCS; corrected to
  `coalition.getCountryCoalition` + `country.id` iteration.)*
- **Pipeline auto-detection in `veaf-tools build`**: after the base `.miz` build, the `build`
  command now automatically detects and runs optional injection steps based on files present in `src/`:
  `src/presets.yaml` (radio presets), `src/waypoints.yaml` (waypoints),
  `src/aircraft-templates.yaml` (aircraft groups), `src/missions.yaml` / `src/versions.yaml`
  (weather variants). Steps can be disabled or customised via a new `pipeline:` section in
  `mission.yaml`. `build.cmd` no longer needs separate `inject-*` calls — a single
  `veaf-tools.exe build` does everything.
- **`migrate-config` command**: migrates a v5-style `missionConfig.lua` to the v6 format.
  Comments out `doFile(...)` calls that load VEAF scripts (now injected automatically by the
  builder), wraps bare `veafXxx.initialize()` calls in `if veafXxx then … end` guards, and prints
  a `lua_modules:` YAML snippet ready to paste into `mission.yaml`.

## Breaking Changes

- **`--scripts-variant` removed** from `veaf-tools build` and `veaf-tools convert`. Use
  `global_log_level` in `mission.yaml` instead.
- **`veaf-scripts-debug.lua` and `veaf-scripts-trace.lua` no longer published.** Only
  `veaf-scripts.lua` is distributed. Runtime log level is set via `missionconfig.lua`.

## Installation

### Quick Start

The easiest way to get started:

1. **Download `veaf-tools-updater.exe`** from this release
2. **Run it** - it will automatically download and install everything else:
   ```bash
   veaf-tools-updater.exe
   ```

That's it! The updater will:
- Create the necessary directories
- Download and extract the VEAF tools to your mission folder
- Set up your configuration

### Manual Installation

If you prefer to install manually:

1. Download `published.zip` from this release
2. Extract it to your VEAF mission folder
3. Run `veaf-tools.exe` to start using the tools

### Updating Existing Installation

If you already have VEAF tools installed:

```bash
veaf-tools-updater.exe update
```

This will download and install the latest version.

---

## Installation 🇫🇷

### Démarrage Rapide

Le moyen le plus simple de commencer :

1. **Téléchargez `veaf-tools-updater.exe`** depuis cette release
2. **Exécutez-le** - il téléchargera et installera automatiquement tout le reste :
   ```bash
   veaf-tools-updater.exe
   ```

C'est tout ! L'updater va :
- Créer les répertoires nécessaires
- Télécharger et extraire les outils VEAF dans votre dossier de mission
- Configurer votre environnement

### Installation Manuelle

Si vous préférez installer manuellement :

1. Téléchargez `published.zip` depuis cette release
2. Extrayez-le dans votre dossier VEAF mission
3. Exécutez `veaf-tools.exe` pour commencer à utiliser les outils

### Mise à Jour d'une Installation Existante

Si vous avez déjà VEAF tools installé :

```bash
veaf-tools-updater.exe update
```

Cela téléchargera et installera la dernière version.

---

## Changelog

See git history for detailed changes.

---
**Generated by veaf-build**
