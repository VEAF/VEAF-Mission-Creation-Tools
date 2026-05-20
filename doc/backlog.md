# Backlog — VEAF Mission Creation Tools v6

## Calibration Table

| Lot | Estimated (min) | Actual (min) | Ratio | Note |
|-----|----------------|--------------|-------|------|
| *(no lot completed yet)* | | | | Initial factor: 1.15 |
| Lot 6 — BONUS | 210 | — | — | LUA-006 + TOOL-004 + LUA-007 |

## Legend

- **Effort**: estimated Copilot time in minutes (excludes user decisions and review)
- **Type**: `feat` / `fix` / `chore`
- **Status**: `[ ]` to do · `[→]` in progress · `[x]` done

---

## Phase 0 — Restart

Immediate actions — no feature branch, direct commits on `develop-v6`.

| # | Ticket | Type | Effort | Status |
|---|--------|------|--------|--------|
| DOC-001 | Rename branch `develop/v6-new-build-system` → `develop-v6` | chore | 5 min | [x] |
| DOC-002 | Create `plan-2026.05.16.md` (pitch doc) | chore | 20 min | [x] |
| DOC-003 | Create `doc/backlog.md` (this file) | chore | 30 min | [x] |
| DOC-004 | Create `CHANGELOG.md` (from `RELEASE_NOTES.md`, Keep a Changelog format) | chore | 30 min | [x] |
| DOC-005 | Create `doc/ROADMAP.md` | chore | 20 min | [x] |
| DOC-006 | Triage 73 GitHub issues → add relevant ones here | chore | 45 min | [x] |

**Raw total: 150 min → estimated (×1.15): ~175 min (~3h)**

<details>
<summary>Ticket details</summary>

**DOC-001 — Rename branch**
```powershell
git branch -m develop/v6-new-build-system develop-v6
git push origin develop-v6
git push origin --delete develop/v6-new-build-system
```
Update the default branch on GitHub if needed.

**DOC-004 — CHANGELOG.md**
[Keep a Changelog](https://keepachangelog.com/en/1.0.0/) format. Port entries from `RELEASE_NOTES.md` (v6.0.5, v6.0.4, ...). Add `[Unreleased]` section for `develop-v6` changes not yet released.

**DOC-005 — ROADMAP.md**
v6 vision and beyond: quality gate, TUI, Lua config system, DCSUnits doc. No dates — priority order and per-feature status only.

**DOC-006 — Issue triage results (2026-05-16)**

73 open issues analyzed. Summary:

| Category | Count | Action |
|----------|-------|--------|
| FIX | 16 | High-priority ones added to Lot 7 below |
| FEAT | 39 | Relevant ones noted in ROADMAP / lot details |
| CHORE | 6 | Added to applicable lots (assets, spawn) |
| STALE | 4 | Close: #9, #19, #41, #167 |
| WONTFIX | 6 | Close: #55, #146, #147, #180, #193, #246 |

**Issues to close on GitHub** (already done or out of scope):
- WONTFIX: #55 (CombatZone already exists), #180 (tasks checked off), #146, #147, #193, #246 (CTLD external project)
- STALE: #9, #19, #41 (2018–2021 with no activity), #167 (gRPC spike with no follow-up)

</details>

---

## Phase 0b — GitHub cleanup

Close issues identified during triage. **Verify each one before closing.**
Direct commits on `develop-v6` (no feature branch needed — no code change).

| # | Ticket | Type | Effort | Status |
|---|--------|------|--------|--------|
| CLOSE-001 | Close WONTFIX issues: #55, #146, #147, #180, #193, #246 | chore | 15 min | [ ] |
| CLOSE-002 | Close STALE issues: #9, #19, #41, #167 | chore | 10 min | [ ] |

<details>
<summary>Issues to close</summary>

**WONTFIX — Already implemented or out of scope**

| # | Title | Reason |
|---|-------|--------|
| #55 | Faire un système de zone de combat dynamique | Already implemented → `veafCombatZone` |
| #146 | CTLD JTAC 9-line | External project (CTLD/Ciribob) |
| #147 | CTLD JTAC Ask for wind/speed correction | External project (CTLD/Ciribob) |
| #180 | AirWaves - forcer à rester dans la zone | Both tasks already checked [x] in the issue |
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

## Lot 1 — INFRA: Python quality gate + CI

**Goal**: Python quality gate working locally and in CI before any feature work.
**Branch**: `feature/infra-poetry-quality-gate` → PR → `develop-v6`

| # | Ticket | Type | Effort | Depends on | Status |
|---|--------|------|--------|------------|--------|
| INFRA-001 | Create `pyproject.toml` with Poetry, migrate `requirements.txt` | chore | 45 min | — | [x] |
| INFRA-002 | Configure ruff (lint + format) in `pyproject.toml` | chore | 20 min | INFRA-001 | [x] |
| INFRA-003 | Configure mypy in `pyproject.toml` | chore | 30 min | INFRA-001 | [x] |
| INFRA-004 | Fix all ruff/mypy violations in `src/python` | fix | 60 min | INFRA-002, INFRA-003 | [x] |
| INFRA-005 | Configure pytest globally (`testpaths`, coverage) | chore | 30 min | INFRA-001 | [x] |
| INFRA-006 | Add `python-quality` job in `.github/workflows/` | chore | 30 min | INFRA-001 | [x] |

**Raw total: 215 min → estimated (×1.15): ~250 min (~4h15)**

<details>
<summary>Ticket details</summary>

**INFRA-001 — pyproject.toml Poetry**
Migrate `requirements.txt` (lupa, rich, typer, pyyaml, Pillow, astral, pydantic, avwx-engine) to Poetry groups (`[tool.poetry.dependencies]` for runtime, `[tool.poetry.group.dev.dependencies]` for quality tools). Verify PyInstaller (`veaf-tools.spec`) still works with the Poetry environment.
⚠️ The existing `.venv` must remain compatible with the PyInstaller workflow.

**INFRA-002 — ruff configuration**
`[tool.ruff]` section in `pyproject.toml`. Enabled rules: `E`, `F`, `W`, `I` (import sorting), `UP` (pyupgrade). Exclude `luadata/` (bundled third-party library). Line length: 120.

**INFRA-003 — mypy configuration**
`[tool.mypy]` section in `pyproject.toml`. Strict on `src/python/veaf-tools/` except `luadata/`. Configure stubs for untyped libraries (pyyaml → `types-PyYAML`, lupa → ignore).

**INFRA-004 — Fix existing violations**
Fix all ruff + mypy errors. The 2 TODOs in `presets_manager.py`:
- Line 18: missing modulation → implement or convert to `# TODO(FEAT-xxx): add modulation`
- Line 450: deferred GUI editor → convert to `# TODO(FEAT-001): implement in interactive mode`

**INFRA-005 — Unified pytest**
`testpaths = ["src/python/veaf-tools", "test"]`. pytest auto-discovers existing unittest tests (`test_presets.py`, `luadata/__test__.py`). Add `pytest-cov` for coverage. Minimum target: 60% on `src/python/veaf-tools/`.

**INFRA-006 — CI python-quality**
New file `.github/workflows/python-ci.yml` (or extra job in `lua-ci.yml`). Steps:
1. `actions/checkout@v4`
2. `actions/setup-python@v5` with Python 3.11
3. `pip install poetry` + `poetry install`
4. `poetry run ruff check src/python`
5. `poetry run ruff format --check src/python`
6. `poetry run mypy src/python`
7. `poetry run pytest`

</details>

---

## Lot 2 — CLI: veaf-tools improvements

**Goal**: Improve `veaf-tools.exe` startup behavior and centralize installation.
**Branch**: `feature/cli-improvements` → PR → `develop-v6`
**Depends on**: Lot 1 complete (quality gate)

| # | Ticket | Type | Effort | Depends on | Status |
|---|--------|------|--------|------------|--------|
| TOOL-001 | Version check on startup + update prompt | feat | 45 min | — | [x] |
| TOOL-002 | Centralized `~/.veaf/` directory (VEAF_HOME) | feat | 30 min | — | [x] |
| TOOL-003 | Build embeds Lua module list in the exe | feat | 60 min | — | [x] |

**Raw total: 135 min → estimated (×1.15): ~155 min (~2h35)**

<details>
<summary>Ticket details</summary>

**TOOL-001 — Version check**
On `veaf-tools` startup, before running the command: compare the current version (constant in code, set from `package.json` at build time) against the latest GitHub release (API `https://api.github.com/repos/VEAF/VEAF-Mission-Creation-Tools/releases/latest`). 2-second timeout so offline use is not blocked. If a newer version exists: display a colored Rich warning with the available version and `veaf-tools-updater update` hint.

**TOOL-002 — VEAF_HOME**
Define `~/.veaf/` as the centralized directory for: installed Lua scripts, preferences, logs. Resolution priority: `VEAF_HOME` env var > default `~/.veaf/`. Auto-create the directory if it does not exist. Migrate all `veaf_libs` paths that currently reference user-specific locations.

**TOOL-003 — Embed module list**
In `veaf_build/worker.py`: scan `src/scripts/veaf/veaf*.lua`, extract ID and version via regex (`veafXxx.Id`, `veafXxx.Version`). Embed in the exe as a Python constant or bundled JSON file (PyInstaller `--add-data`). Expose via `veaf-tools about --modules` (Rich table).

</details>

---

## Lot 3 — TUI: InquirerPy interactive mode

**Goal**: `veaf-tools` with no arguments opens a guided interactive mode instead of showing help.
**Branch**: `feature/tui-interactive` → PR → `develop-v6`
**Depends on**: Lot 1 (quality gate), Lot 2 TOOL-002 (VEAF_HOME for preferences)

| # | Ticket | Type | Effort | Depends on | Status |
|---|--------|------|--------|------------|--------|
| FEAT-001 | InquirerPy interactive mode when no argument is given | feat | 60 min | — | [x] |
| FEAT-002 | Persist preferences in `~/.veaf/preferences.json` | feat | 30 min | TOOL-002 | [x] |
| FEAT-003 | Pre-fill prompts from saved preferences | feat | 30 min | FEAT-002 | [x] |

**Raw total: 120 min → estimated (×1.15): ~140 min (~2h20)**

<details>
<summary>Ticket details</summary>

**FEAT-001 — Interactive mode**
Add `inquirerpy` to Poetry dependencies. If `len(sys.argv) == 1` (no arguments): show a fuzzy command selector (all 11 commands with descriptions), then prompts for the required parameters of the selected command. Reuse the same validators as the typer CLI to ensure consistency.

**FEAT-002 — Preference persistence**
JSON structure in `~/.veaf/preferences.json`:
```json
{
  "last_command": "build",
  "build": { "mission_folder": "...", "output": "..." },
  "inject-weather": { "mission": "...", "config": "..." }
}
```
Read via `veaf_libs` on interactive mode startup, written after each successful run.

**FEAT-003 — Pre-fill from preferences**
On interactive mode launch, read `preferences.json` and inject the last-used values as `default` in the InquirerPy prompts for the selected command. The user can modify them or confirm directly.

</details>

---

## Lot 4 — LUA-CONFIG: Lua configuration system

**Goal**: Each Lua module can be configured and disabled via `missionconfig.lua` without touching module source code. Fully backward compatible.
**Branch**: `feature/lua-config-system` → PR → `develop-v6`
**Depends on**: Lot 1 (quality gate for TOOL-003/LUA-005)

| # | Ticket | Type | Effort | Depends on | Status |
|---|--------|------|--------|------------|--------|
| LUA-001 | `veaf.config` per module + `enable=true` option in `veaf.lua` | feat | 90 min | — | [x] |
| LUA-002 | Load and apply `missionconfig.lua` | feat | 60 min | LUA-001 | [x] |
| LUA-003 | Deferred module initialization after missionconfig load | feat | 60 min | LUA-002 | [x] |
| LUA-004 | `veaf-tools generate-config` command → `missionconfig.lua` template | feat | 45 min | LUA-001, TOOL-003 | [x] |
| LUA-005 | Module selection + options via mission YAML (`veaf-tools build`) | feat | 60 min | LUA-004 | [x] |

**Raw total: 315 min → estimated (×1.15): ~360 min (~6h)**
⚠️ Highest-risk lot — impacts Lua runtime of all existing missions. Require Lua test coverage before merge.

<details>
<summary>Ticket details</summary>

**LUA-001 — veaf.config**
In `veaf.lua`: `veaf.config = {}`. Each module registers its default config on load:
```lua
-- In veafSpawn.lua
veaf.config["veafSpawn"] = {
  enable = true,
  logLevel = "info",
  -- module-specific options
}
```
Public API: `veaf.getConfig(moduleId)`, `veaf.setConfig(moduleId, key, value)`, `veaf.isEnabled(moduleId)`.

**LUA-002 — missionconfig.lua**
After all modules are loaded via `require`, `veaf.lua` attempts `dofile("missionconfig.lua")`. That file contains `veaf.setConfig(...)` calls that override defaults. If the file does not exist: unchanged behavior (full backward compatibility).

**LUA-003 — Deferred init**
Refactor the startup sequence: `require` (load modules) → `dofile missionconfig` (override config) → `veaf.initialize()` (triggers init of all enabled modules). Each module exposes a distinct `init()` function separate from loading. Modules with `enable = false` do not initialize. Backward fallback: if `veaf.initialize()` is not called explicitly within a timeout, trigger automatically for legacy missions.

**LUA-004 — generate-config**
New command `veaf-tools generate-config --mission <folder>`: reads the embedded module list (from TOOL-003 data), generates a `missionconfig.lua` template with all options documented in comments and their default values. Output to the mission folder.

**LUA-005 — Mission YAML → modules**
In `mission.yaml` (mission configuration): `lua_modules` section listing modules to enable with their options. During `veaf-tools build`: this section is read and converted to a generated `missionconfig.lua`, injected into the `.miz`. Missions without this section keep current behavior (all modules active).

</details>

---

## Lot RC — v6.1.0 RC bug fixes

**Goal**: Fix bugs discovered during RC testing before the final release.
**Branch**: `develop-v6` (direct commits — RC hotfixes)

| # | Ticket | Type | Effort | Status |
|---|--------|------|--------|--------|
| RC-001 | Fix `.\published\veaf-tools.exe` → `.\veaf-tools.exe` in `doc/mission-maker/MIGRATION_GUIDE.md` | fix | 10 min | [x] |
| RC-002 | Bundle lupa in exe (`pyproject.toml` non-optional + `hiddenimports` in `.spec`) | fix | 20 min | [x] |
| RC-003 | Fix version comparison (`5.103.3 > 6.1.0-rc1`) — strip pre-release suffix in `_version_tuple` | fix | 15 min | [x] |
| RC-004 | Fix `No such command 'normalize'` — rewrite `src/build-scripts/build.cmd` with real command names | fix | 20 min | [x] |
| RC-005 | Sync `published/build-scripts/build.cmd` to match `src/build-scripts/build.cmd` | fix | 10 min | [x] |
| RC-006 | Fix wrong command names in `doc/MISSION_MAKER_GUIDE.md` and `doc/mission-maker/README.md` | fix | 20 min | [x] |
| RC-007 | Fix `string.format("%s", veaf.lp(...))` crash in `veaf.lua` (4 occurrences in `getAirbaseLife`, `_endMission`, `_checkForEndMission`, `endMissionAt`) | fix | 20 min | [x] |
| RC-008 | Fix `prepare` command distributing files from wrong root (`defaults/mission-folder/src/` → `defaults/mission-folder/`) | fix | 15 min | [x] |
| RC-009 | Fix `complete_src_folder_with_defaults` looking at `published/defaults/` instead of `published/src/defaults/` | fix | 20 min | [x] |
| RC-010 | Move default `mission.yaml` from `src/defaults/mission-folder/src/` to `src/defaults/mission-folder/` (root) so it lands at `<mission_folder>/mission.yaml` | fix | 10 min | [x] |
| RC-011 | Fix `veaf-modules-config.lua` not loaded in dynamic mode — add conditional `loadfile` in "Mission scripts loading - dynamic" trigger | fix | 20 min | [x] |
| RC-012 | `prepare` command: replace `typer.confirm` with `_ask_replace()` using `sys.stdin` (fix terminal blocking + add "A" yes-to-all option) | fix | 15 min | [x] |
| RC-013 | `veaf-tools-updater` `_install_defaults`: add `mission.yaml` copy (root of `mission-folder/`) — missing from first-install bootstrap | fix | 10 min | [x] |
| RC-014 | `prepare` command: replace `sys.stdin.readline()` with `msvcrt.getwch()` (single-char, no Enter required) — fix terminal blocking on Windows/ConPTY | fix | 15 min | [x] |
| RC-015 | `veaf.Logger`: `getEffectiveLevel()` retournait une string, les méthodes de log comparaient `self.level` (number figé) → `ForcedLogLevel` ignoré à l'exécution. Fix: `getEffectiveLevel()` retourne un number, toutes les méthodes utilisent `self:getEffectiveLevel()` | fix | 20 min | [x] |
| RC-016 | `veaf.lp()` inside `string.format()` crashes Lua 5.1 unconditionally — arguments are evaluated before the logger level guard runs. `veaf.lp()` returns a table; Lua 5.1 `string.format("%s", table)` does not call `__tostring`. Fix: replaced `veaf.lp()` with `veaf.p()` in all `string.format()` calls across 7 files (`veafCarrierOperations`, `veafCasMission`, `veafGroundAI`, `veafRemote`, `veafSanctuary`, `veafShortcuts`, `veafSpawn`) | fix | 30 min | [x] |
| RC-017 | `veaf.lp()` used with `..` concatenation crashes Lua 5.1 unconditionally — same root cause as RC-016. Lua 5.1 does not call `__tostring` on `..` operands, so `"text=" .. veaf.lp(x)` throws *"attempt to concatenate a table value"*. Fix: converted 11 call sites in 4 files (`veafCarrierOperations`, `veafMove`, `veafRadio`, `veafUnits`) from `"label=" .. veaf.lp(x)` to `"label=%s", veaf.lp(x)` | fix | 20 min | [x] |
| RC-018 | `veaf.getCountryForCoalition` returned nil for coalitions with no pre-placed units — `_initializeCountriesAndCoalitions` only read `mist.DBs.units` (pre-placed groups). Dynamic test missions have no RED pre-placed units → `countriesByCoalition["red"]` empty → nil passed to `mist.dynAdd` → *"Country not found: $1"* (MIST format placeholder for nil) → group not spawned → `Group.getByName():getController()` crashes. Fix: supplement with `country.id` + `coalition.getCountryCoalition()` DCS API (first attempt used `coalition.getCountries` which does not exist in DCS). Also fixed broken `_sortByImportance` comparator (returned nil instead of false). | fix | 35 min | [x] |
| RC-019 | Pipeline auto-detection in `veaf-tools build`: after the base build, auto-detect and run optional injection steps based on file presence (`src/presets.yaml`, `src/waypoints.yaml`, `src/aircraft-templates.yaml`, `src/missions.yaml`). Configurable via new `pipeline:` section in `mission.yaml`. `build.cmd` template simplified to 2 commands (updater + build). | feat | 45 min | [x] |
| RC-020 | `veaf-tools migrate-config` command: parses an existing `missionConfig.lua`, comments out `doFile()` calls for VEAF scripts (now injected by the builder), wraps bare `veafXxx.initialize()` calls in `if veafXxx then … end` guards, and outputs a `lua_modules:` YAML snippet showing which modules were found enabled. Implementation: `mission_builder/config_migrator.py` (`ConfigMigrator`, `MigrationResult`), exported from `mission_builder/__init__.py`, CLI command in `veaf-tools.py`. | feat | 40 min | [x] |
| RC-021 | `veaf-tools convert-v5` command: single-pass v5→v6 mission folder conversion. (1) Scans for `missionConfig.lua` and pipeline config files (`presets.yaml`, `waypoints.yaml`, `aircraft-templates.yaml`, `missions.yaml`). (2) Migrates `missionConfig.lua` in-place via `ConfigMigrator` (creates `.bak` backup). (3) **Automatically converts v5 pipeline config files** to v6 YAML: `radioSettings.lua` → `presets.yaml` (channels + warbird), `weatherAndTime/` → `weather-config.yaml` (all versions incl. `realweather`), `wp.lua` → `waypoints.yaml`, aircraft JSON → `aircraft-templates.yaml`. ICAO code prompted once if a realweather version is detected. `--no-convert-pipeline` flag skips auto-conversion. (4) Generates `mission.yaml` with `lua_modules:` and `pipeline:` sections. (5) Prints Rich scan table + actions summary, saves full Markdown report. Implementation: `mission_builder/v5_pipeline_converters.py` (4 converters), `mission_builder/v5_converter.py` (`V5Converter`, `ConversionReport`, `PipelineFile` with `converted` field), CLI in `veaf-tools.py`. | feat | 120 min | [x] |

**Estimated total: ~390 min**

---

## Lot 5 — RELEASE: v6.1.0

**Goal**: Merge v6 to master and publish the official release.
**From**: `develop-v6` directly

| # | Ticket | Type | Effort | Depends on | Status |
|---|--------|------|--------|------------|--------|
| REL-001 | Finalize `CHANGELOG.md` for v6.1.0 | chore | 20 min | Lots 1–4 | [ ] |
| REL-002 | Write `RELEASE_NOTES.md` for v6.1.0 | chore | 20 min | REL-001 | [ ] |
| REL-003 | Squash merge `develop-v6` → `master` | chore | 15 min | REL-002 | [ ] |
| REL-004 | Tag `v6.1.0` + publish GitHub (`veaf-build publish`) | chore | 30 min | REL-003 | [ ] |

**Estimated total: ~85 min (~1h30)**

---

## Lot 6 — BONUS: Logger filter + DCSUnits doc

**Goal**: Quality-of-life improvements after the priority lots.
**Branch**: `feature/bonus-logger-doc` → PR → `develop-v6`
**Depends on**: Lot 4 (LUA-001), Lot 2 (TOOL-003)

| # | Ticket | Type | Effort | Depends on | Status |
|---|--------|------|--------|------------|--------|
| LUA-006 | `--log-modules` option in `veaf-tools` to filter which modules log | feat | 90 min | LUA-001 | [x] |
| TOOL-004 | Parse `dcsUnits.lua` → dynamic markdown doc generated before publish | feat | 90 min | TOOL-003 | [x] |
| LUA-007 | Lazy log args (`veaf.lp`), single build, runtime log control (`global_log_level`) | feat | 120 min | LUA-006 | [x] |

**Raw total: 300 min → estimated (×1.15): ~345 min (~5h45)**

<details>
<summary>Ticket details</summary>

**LUA-006 — Logger filter**
`--log-modules spawn,radio,assets` option on `veaf-tools build` and `veaf-tools inject-*` commands. Translates to a section in the generated `missionconfig.lua` that disables logging (or forces `logLevel = "error"`) for all unlisted modules. Useful for debugging a mission without log noise.

**LUA-007 — Lazy log args + single build + runtime log control**
- `veaf.lp(value)`: lazy proxy so log arguments are only stringified if the log level is active.
  Returns a metatable with `__tostring` → `veaf.p(value)`. Safe to use in `:trace()`/`:debug()` calls.
- Migrate all 1233 `veaf.p(` → `veaf.lp(` calls across the Lua codebase (automated via `migrate_lazy_log.py`).
- Remove build-time comment-out step (`--scripts-variant debug/trace/standard`) from `veaf_build/worker.py`.
- Remove `_create_lua_variant_files()` and the three `veaf-scripts-*.lua` variant generation steps.
- `veaf.BaseLogLevel = 3` (info) as default; replace `--scripts-variant` with `mission.yaml: global_log_level`.
  Writes `veaf.ForcedLogLevel = "<level>"` in the generated `veaf-modules-config.lua`.

</details>

---

## Lot 7 — LUA FIXES: High-priority bug fixes from issue triage

**Goal**: Fix the most impactful Lua bugs, prioritized from issue triage.
**Branch**: `fix/lua-high-priority` → PR → `develop-v6`
**Depends on**: Lot 4 (LUA-CONFIG — same files, avoid conflicts)

| # | Ticket | Issue | Type | Effort | Status |
|---|--------|-------|------|--------|--------|
| LUA-FIX-001 | Fix `math.atan` wind direction calculation (Lua 5.1 compat) | #287 | fix | 30 min | [x] |
| LUA-FIX-002 | Fix stale DCS object ref in `getNearestAirbaseList` | #302 | fix | 45 min | [x] |
| LUA-FIX-003 | Fix dynamic slots breaking QRA, Radio, AirWaves, Sanctuary, Grass | #293 | fix | 90 min | [x] |
| LUA-FIX-004 | Fix QRA not triggered by dynamic slot aircraft | #299 | fix | 45 min | [x] |
| LUA-FIX-005 | Fix CasMission/CombatZone always using Blue bullseye | #304 | fix | 30 min | [x] |
| LUA-FIX-006 | Update unit list for DCS 2.9.19.13478 new assets | #295, #296 | chore | 60 min | [x] |

**Raw total: 300 min → estimated (×1.15): ~345 min (~5h45)**

---

## Lot 8 — LUA-QUALITY: Code quality quick wins

**Goal**: Targeted fixes for identified bugs and recurring anti-patterns in the Lua codebase.
No structural breakage — each ticket is isolated and low-risk.
**Branch**: `fix/lua-quality` → PR → `develop-v6`

| # | Ticket | File(s) | Type | Effort | Status |
|---|--------|---------|------|--------|--------|
| LUAQ-001 | Ajouter `unit:isExist()` guards dans `VeafQRA.check()` avant appels DCS | `veafQraManager.lua` | fix | 30 min | [x] |
| LUAQ-002 | Remplacer le pattern `arg`/`arg.n` (Lua 5.1 deprecated) par `{...}`/`select` dans `AirWaveZone:addWave()` | `veafAirWaves.lua` | chore | 20 min | [x] |
| LUAQ-003 | Wrapper `veaf.mist` pour centraliser les accès à `mist.DBs` (getUnitByName, getGroupByName, isHumanUnit) | `veaf.lua` + modules | chore | 60 min | [x] |
| LUAQ-004 | Factoriser la logique convoy dupliquée dans veafSpawn (`stop/move/markRoute`) | `veafSpawn.lua` | chore | 45 min | [x] |
| LUAQ-005 | Factoriser `moveTanker`/`changeTanker` (logique route commune ~40% dupliquée) | `veafMove.lua` | chore | 30 min | [x] |

**Raw total: 185 min → estimated (×1.15): ~215 min (~3h35)**

<details>
<summary>Ticket details</summary>

**LUAQ-001 — isExist() guards dans VeafQRA.check()**
Dans `VeafQRA.check()`, le watchdog tourne toutes les 5 secondes (`veafQraManager.WATCHDOG_DELAY = 5`). Les objets DCS retournés par `group:getUnits()` peuvent devenir des références stales si l'unité est détruite entre deux ticks. Même avec `if unit then`, un objet DCS mort peut lever une exception sur `:getLife()` ou `:inAir()`.
Correction : ajouter `if unit:isExist() then` avant chaque appel de méthode DCS sur une unité. Pattern à appliquer aussi dans `VeafQRA.rearm()` et `VeafQRA.resupply()`.

**LUAQ-002 — Varargs propres dans addWave()**
`addWave(...)` utilise la table implicite `arg` (Lua 5.1 legacy). Ce pattern génère du bruit `---@diagnostic disable-next-line: undefined-field` et est fragile dans certains contextes DCS.
Correction : remplacer par `local args = {...}` + `local nArgs = select('#', ...)`, supprimer la directive `@diagnostic disable`.

**LUAQ-003 — Wrapper veaf.mist**
Accès directs à `mist.DBs.unitsByName`, `mist.DBs.groupsByName`, `mist.DBs.humansByName` éparpillés dans veafSpawn, veafRadio, veafGrass, veafQraManager, veafInterpreter. Si mist change ses internals, tous ces modules cassent.
Proposition :
```lua
-- Dans veaf.lua
veaf.mist = {}
function veaf.mist.getUnitData(unitName) return mist.DBs.unitsByName[unitName] end
function veaf.mist.getGroupData(groupName) return mist.DBs.groupsByName[groupName] end
function veaf.mist.isHumanUnit(unitName) return mist.DBs.humansByName[unitName] ~= nil end
```
Remplacer tous les accès directs par ces wrappers.

**LUAQ-004 — Convoy helpers dans veafSpawn**
`_findClosestConvoy`, `_commandConvoy`, `stopClosestConvoy`, `moveClosestConvoy`, `_markClosestConvoyWithSmoke`, `markClosestConvoyWithSmoke`, `markClosestConvoyRouteWithSmoke` contiennent des blocs de validation quasi-identiques (~30 lignes chacun). Extraire `veafSpawn._getConvoyOrWarn(unitName)` qui centralise la recherche et le message d'erreur.

**LUAQ-005 — Tanker route helpers dans veafMove**
`moveTanker()` et `changeTanker()` partagent ~40% de logique identique (récupération du groupe tanker, validation des waypoints, construction de la route DCS). Extraire `veafMove._buildTankerRoute(group, waypoints)` utilisé par les deux.

</details>

---

## Lot 9 — LUA-REFACTOR: Refactoring structurel des modules majeurs

**Goal**: Réduire la complexité des modules les plus chargés du codebase Lua.
Chaque ticket est indépendant mais risqué — à traiter un par un avec tests en mission réelle.
**Branch**: une branche par ticket `refactor/lua-xxx` → PR → `develop-v6`
⚠️ Impact fort sur les missions existantes : chaque PR doit être testée en mission avant merge.

| # | Ticket | File(s) | Type | Effort | Status |
|---|--------|---------|------|--------|--------|
| LUAR-001 | Scinder `veafSpawn.lua` (3200+ lignes) en 4 modules thématiques | `veafSpawn*.lua` | feat | 240 min | [ ] |
| LUAR-002 | Machine d'état explicite (FSM) pour `AirWaveZone` | `veafAirWaves.lua` | feat | 120 min | [ ] |
| LUAR-003 | Scinder `VeafQRA` (1200+ lignes) en `VeafQRACore` + `VeafQRALogistics` | `veafQraManager.lua` | feat | 150 min | [ ] |
| LUAR-004 | `RadioMenuBuilder` — abstraction de la construction des menus dans veafRadio | `veafRadio.lua` | feat | 90 min | [ ] |

**Raw total: 600 min → estimated (×1.15): ~690 min (~11h30)**

<details>
<summary>Ticket details</summary>

**LUAR-001 — Split veafSpawn.lua**
3200+ lignes, 35+ fonctions publiques avec 5 responsabilités distinctes. Proposition de découpage :
- `veafSpawnCore.lua` — `executeCommand`, parsing de markers, `doSpawnGroup`, `_createDcsUnits`, dessin (addPointToDrawing, drawCircle, drawSquare, eraseDrawing)
- `veafSpawnGround.lua` — `spawnGroup`, `spawnInfantryGroup`, `spawnArmoredPlatoon`, `spawnAirDefenseBattery`, `spawnTransportCompany`, `spawnFullCombatGroup`, `spawnConvoy`, `spawnFarp`, `spawnFob`
- `veafSpawnAircraft.lua` — `spawnUnit` (avions/hélicos), `spawnCombatAirPatrol`, JTAC/lasing
- `veafSpawnEffects.lua` — `spawnBomb`, `spawnSmoke`, `spawnSignalFlare`, `spawnIlluminationFlare`, `spawnCargo`, `spawnLogistic`, `destroy`, `teleport`

`veafSpawn.lua` devient un proxy qui charge les 4 sous-modules et ré-exporte les fonctions publiques pour backward compatibility.

**LUAR-002 — FSM AirWaveZone**
`AirWaveZone` gère 7+ états (`READY`, `WAITING_FOR_HUMANS`, `ACTIVE`, `WAITING_FOR_NEXTWAVE`, `CLEANUP`, `DONE`, `PAUSED`) via des variables booléennes et des `if/elseif` chaînés dans `check()`.
Refactorer en FSM explicite :
```lua
AirWaveZone.FSM = {
  READY = { enter = AirWaveZone._onEnterReady, transitions = { WAITING_FOR_HUMANS = AirWaveZone._canWaitForHumans } },
  ACTIVE = { enter = AirWaveZone._onEnterActive, transitions = { WAITING_FOR_NEXTWAVE = AirWaveZone._waveEnded } },
  ...
}
```
Bénéfice : `check()` devient une boucle sur `FSM[self.state].transitions`, pas de if imbriqués, états clairement documentés.

**LUAR-003 — Split VeafQRA**
`VeafQRA` fait 1200+ lignes avec 3 responsabilités :
1. **Détection + spawn** : `check()`, `humanBornEvent()`, `spawnQra()`, `despawnQra()`
2. **Logistique** : `rearm()`, `resupply()`, `refuel()`, délais de ravitaillement
3. **Communication** : messages radio, marqueurs carte, `getInformation()`

Proposition :
- `VeafQRACore` — état, détection, spawn/despawn
- `VeafQRALogistics` — rearm/resupply/refuel (classe séparée, référencée depuis Core)
- Laisser les messages dans Core mais extraire `VeafQRA:buildStatusMessage()` en helpers

**LUAR-004 — RadioMenuBuilder**
`veafRadio.lua` construit les menus DCS missionCommands via des appels `missionCommands.addSubMenu` / `addCommand` entrelacés avec la logique de rebuild. Créer `RadioMenuBuilder` :
```lua
local RadioMenuBuilder = {}
function RadioMenuBuilder:new(root) ... end
function RadioMenuBuilder:addMenu(label, parent) ... end
function RadioMenuBuilder:addCommand(label, parent, fn, args) ... end
function RadioMenuBuilder:build() ... end
function RadioMenuBuilder:rebuild() ... end  -- clear + rebuild
```
Isole la complexité de l'arbre DCS et facilite le test unitaire.

</details>

---

## Summary

| Lot | Estimate | Status |
|-----|----------|--------|
| Phase 0 — Restart | ~3h | [x] |
| Phase 0b — GitHub cleanup | ~25 min | [ ] |
| Lot 1 — INFRA | ~4h15 | [x] |
| Lot 2 — CLI | ~2h35 | [x] |
| Lot 3 — TUI | ~2h20 | [x] |
| Lot 4 — LUA-CONFIG | ~6h | [x] |
| Lot 5 — RELEASE | ~1h30 | [ ] |
| Lot 6 — BONUS | ~3h30 | [x] |
| Lot 7 — LUA FIXES | ~5h45 | [x] |
| Lot 8 — LUA-QUALITY | ~3h35 | [x] |
| Lot RC — v6.1.0 RC fixes | ~1h35 | [x] |
| Lot 9 — LUA-REFACTOR | ~11h30 | [ ] |
| Lot 10 — YAML-CONFIG | ~14h | [x] |
| Lot 11 — I18N | ~7h10 | [x] |
| Lot 12 — QUALITY | ~16h35 | [x] |
| Lot 13 — DISCUSS | ~12h50 | [ ] |
| **Total** | **~94h** | |

*Initial calibration factor: 1.15 — recalculate after each completed lot.*

---

## Lot 10 — YAML-CONFIG: mission.yaml source de vérité

**Goal**: `mission.yaml` becomes the single source of truth for all mission configuration. Python generates `veaf-config.lua` at build time. `missionConfig.lua` → `mission-script.lua` (custom code only). `convert-v5` actively extracts all recognized patterns.
**Branch**: `feature/yaml-config` → PR → `develop-v6`
**Depends on**: Lot RC (builder infrastructure), Lot 4 (LUA-CONFIG)

| # | Ticket | Type | Effort | Depends on | Status |
|---|--------|------|--------|------------|--------|
| YAML-001 | Rename `veaf-modules-config.lua` → `veaf-config.lua` and `missionConfig.lua` → `mission-script.lua` everywhere (no compat fallback) | chore | 40 min | — | [x] |
| YAML-002 | Core YAML schema + generator: `mission:`, `security:`, `settings:`, auto-`initialize()` with typed `init:` params per module | feat | 60 min | YAML-001 | [x] |
| YAML-003 | YAML schema + generator: `lua_modules.ASSETS.assets:` table + `lua_modules.NAMED_POINTS.custom_points:` | feat | 45 min | YAML-002 | [x] |
| YAML-004 | YAML schema + generator: `external_modules.skynet:` + `external_modules.ctld:` | feat | 35 min | YAML-002 | [x] |
| YAML-005 | YAML schema + generator: `qra:` list → `VeafQRA:new():set*():start()` builder chains | feat | 60 min | YAML-002 | [x] |
| YAML-006 | YAML schema + generator: `cap_missions:` + `combat_missions:` → `addCapMission()` + `VeafCombatMission` builder chains | feat | 90 min | YAML-002 | [x] |
| YAML-007 | Update `generate-config` command: produce exhaustive commented `mission.yaml` with all known options and defaults | feat | 45 min | YAML-002–006 | [x] |
| YAML-008 | Update default templates: `mission.yaml` (all new sections commented), `mission-script.lua` (custom-only stub), `test-tools-v6` fixtures | chore | 30 min | YAML-002–006 | [x] |
| YAML-009 | `convert-v5` — extract core config + Skynet: `MISSION_NAME`, `era`, `SecurityDisabled`, simple `initialize()` params, Skynet params | feat | 60 min | YAML-002, YAML-004 | [x] |
| YAML-010 | `convert-v5` — extract `veafAssets.Assets = {...}` Lua table → `lua_modules.ASSETS.assets:` YAML | feat | 45 min | YAML-003 | [x] |
| YAML-011 | `convert-v5` — extract `VeafQRA:new():...:start()` chains → `qra:` YAML entries | feat | 60 min | YAML-005 | [x] |
| YAML-012 | `convert-v5` — extract `addCapMission()` + `VeafCombatMission:new():...` chains → `cap_missions:` / `combat_missions:` YAML | feat | 75 min | YAML-006 | [x] |
| YAML-013 | Tests: `test_config_generator.py` (mission, security, auto-init, QRA, CombatMission, Assets) + `test_config_migrator.py` updates (new extraction patterns) | chore | 60 min | YAML-001–012 | [x] |
| YAML-014 | Docs: update `MISSION_MAKER_GUIDE.md`, `MIGRATION_GUIDE.md` for new YAML → `veaf-config.lua` + `mission-script.lua` workflow | chore | 30 min | YAML-001–012 | [x] |

**Raw total: 735 min → estimated (×1.15): ~845 min (~14h05)**

<details>
<summary>Ticket details</summary>

**YAML-001 — File renames (no compat fallback)**
- `veaf-modules-config.lua` → `veaf-config.lua`:
  - `mission_builder_worker.py`: all path constants + trigrule strings + `write_lua_modules_config()` → `write_config_lua()`
  - `mission_constants.py`: path tuple
  - `veaf-tools.py`: `generate-config` command messages
- `missionConfig.lua` → `mission-script.lua`:
  - `src/defaults/mission-folder/src/scripts/missionConfig.lua` renamed
  - `veafDynamicConfig.lua`: `"missionConfig.lua"` → `"mission-script.lua"`, remove fallback logic
  - `v5_converter.py`: `MISSIONCONFIG_DEFAULT`, `MISSIONCONFIG_CANDIDATES`, output filename
  - `config_migrator.py`: output filename
  - `mission_builder_worker.py`: static trigrule `veaf_mission_config_map_key` reference
  - `test-tools-v6/src/scripts/missionConfig.lua` renamed

**YAML-002 — Core schema + generator**
New `mission.yaml` sections:
```yaml
mission:
  name: "My-Mission"          # veaf.config.MISSION_NAME
  export_path: null           # veaf.config.MISSION_EXPORT_PATH
  era: MODERN                 # veaf.config.era  (WW2 | COLD_WAR | MODERN)
security:
  disabled: true              # veaf.SecurityDisabled
  # password_hashes: ["sha1"]
settings:                     # dict → veaf.config.KEY = value
  DEFAULT_GROUND_SPEED_KPH: 25
```
`lua_modules` gains a typed `init:` sub-section per known module (hardcoded mapping in generator):
- `RADIO.init.help_menus: bool` → positional arg of `veafRadio.initialize(bool)`
- `CARRIER.init.include_carrier_operations_radio: bool`
- (all other modules: `initialize()` with no args when `init:` absent)

Generator (`generate_config_lua()` in `lua_module_scanner.py`) updated to:
1. Emit mission identity block
2. Emit security block
3. Emit `veaf.config.XXX = ...` from `settings:`
4. For each module with `enable: true`: emit `veaf.setConfig()` calls then auto-`if veafXxx then veafXxx.initialize(...) end`
5. Initialization order is fixed (recommended VEAF order, `veafInterpreter` always last)
`mission_builder_worker.py`: `write_config_lua()` passes all new YAML sections to generator.

**YAML-003 — Assets + NamedPoints**
```yaml
lua_modules:
  ASSETS:
    enable: true
    assets:
      - sort: 1
        name: "CSG-74 Stennis"
        description: "Stennis (CVN)"
        information: "Tacan 10X\nICLS 10"
        linked: null     # optional
        jtac: null       # optional (laser code int)
        freq: null       # optional (float)
        mod: null        # optional ("am" | "fm")
  NAMED_POINTS:
    enable: true
    custom_points:
      - name: "Battle Area Alpha"
        lat: "41.123456"
        lon: "44.987654"
```
Generator: emit `veafAssets.Assets = { {...}, ... }` before `veafAssets.initialize()`. Emit `local customPoints = { {name=..., point=coord.LLtoLO(...)} }` passed to `veafNamedPoints.initialize(customPoints)`.

**YAML-004 — External modules (Skynet, CTLD)**
```yaml
external_modules:
  skynet:
    enabled: false
    include_red_in_radio: false
    debug_red: false
    include_blue_in_radio: false
    debug_blue: false
  ctld:
    enabled: false
    hover_pickup: true
    enable_crates: true
    # ... other ctld.xxx keys
```
Generator: emit `if veafSkynet then veafSkynet.initialize(false, false, false, false) end`.
For CTLD: emit `ctld.xxx = value` property assignments (not `ctld.initialize()` — the script loading stays in `mission-script.lua`). CTLD emitted only if `ctld.enabled: true`.

**YAML-005 — QRA schema + generator**
```yaml
qra:
  silence_all: true             # VeafQRA.ToggleAllSilence(true)
  definitions:
    - name: QRA_Minevody
      coalition: RED            # coalition.side.RED
      enemy_coalitions: [BLUE]
      trigger_zone: QRA_Minevody
      zone_radius: null         # optional (metres)
      delay_before_rearming: 10
      delay_before_activating: 60
      react_on_helicopters: true
      airport_link: null        # optional (airbase name)
      groups_by_enemy_count:
        - enemy_count: 1
          groups: ["QRA_Minevody-1", "QRA_Minevody-2"]
          random_pick: 1
      simple_groups: []         # alternative to groups_by_enemy_count: flat :addGroup() calls
```
Generator: emit `veafQraManager.initialize()`, optional `VeafQRA.ToggleAllSilence(bool)`, then for each definition a `VeafQRA:new()` builder chain ending in `:start()`. Coalition values mapped `RED` → `coalition.side.RED`.

**YAML-006 — CombatMission schema + generator**
```yaml
cap_missions:
  - group_name: "training-radar-tu22-FL300"
    menu_name: "WEST - Tu22 FL300"
    briefing: "Russian TU-22 patrols at FL300..."
    default: false
    activated: true
combat_missions:
  - name: Intercept-Kraznodar-1
    friendly_name: "Intercept a transport / KRAZNODAR - MINVODY"
    secured: true
    radio_menu_enabled: true
    briefing: |
      A Russian transport plane is taking off from Kraznodar...
    elements:
      - name: OnDemand-Intercept-Transport-Krasnodar-Mineral-Transport
        groups: ["OnDemand-Intercept-Transport-Krasnodar-Mineral-Transport"]
        scalable: false
```
Generator: emit `veafCombatMission.initialize()`, then `addCapMission()` calls, then `AddMissionsWithSkillAndScale(VeafCombatMission:new():...:addElement(VeafCombatMissionElement:new():...):...)` chains. Multi-line briefings emitted as Lua long strings (`[[...]]`).

**YAML-007 — generate-config command**
`veaf-tools generate-config --mission <folder>`: produces a fully-commented `mission.yaml` at the mission folder root. Every known option listed with its type, default value, and a one-line comment. Sections: `mission:`, `security:`, `settings:`, `global_log_level:`, `lua_modules:` (all known modules with all `init:` params), `external_modules:`, `qra:` (example entry), `cap_missions:` / `combat_missions:` (example entries).

**YAML-008 — Template updates**
- `src/defaults/mission-folder/mission.yaml`: add all new sections with commented examples.
- `src/defaults/mission-folder/src/scripts/mission-script.lua`: stripped to custom-code stub with commented examples for QRA, CombatMission, community script loading (e.g. CTLD.lua).
- `test-tools-v6/mission.yaml`: updated to use new sections.
- `test-tools-v6/src/scripts/mission-script.lua`: migrated from `missionConfig.lua`.

**YAML-009 — convert-v5: core + Skynet extraction**
`config_migrator.py` extended to extract from `missionConfig.lua`:
- `veaf.config.MISSION_NAME = "..."` → `mission.name:`
- `veaf.config.MISSION_EXPORT_PATH = ...` → `mission.export_path:`
- `veaf.config.era = veaf.ERA.XXX` → `mission.era:`
- `veaf.SecurityDisabled = true/false` → `security.disabled:`
- `veafSecurity.password_L9["hash"] = true` → `security.password_hashes: [hash]`
- `veaf.DEFAULT_GROUND_SPEED_KPH = N` → `settings.DEFAULT_GROUND_SPEED_KPH:`
- `veafRadio.initialize(true/false)` → `lua_modules.RADIO.init.help_menus:`
- `veafSkynet.initialize(a, b, c, d)` → `external_modules.skynet:` params
`v5_converter.py`: emit these sections in the generated `mission.yaml`.

**YAML-010 — convert-v5: Assets extraction**
Regex + Lua table parser for `veafAssets.Assets = { {...}, {...} }`. Extract each table entry (sort, name, description, information, linked?, jtac?, freq?, mod?) into `lua_modules.ASSETS.assets:` YAML list. Multi-line `information` strings (with `\n`) handled correctly.

**YAML-011 — convert-v5: QRA extraction**
Parse `VeafQRA:new()` method chains:
- Detect block pattern `VeafQRA:new()\n:setName(...)\n:...\n:start()`
- Extract each `:setXxx(...)` call to the corresponding YAML field
- Handle `setRandomGroupsToDeployByEnemyQuantity(count, {groups}, pick)` → `groups_by_enemy_count:` entry
- Handle `VeafQRA.ToggleAllSilence(bool)` → top-level `qra.silence_all:`
- Remaining unrecognized chained calls: warn + keep in `mission-script.lua`

**YAML-012 — convert-v5: CombatMission extraction**
- `veafCombatMission.addCapMission(g, m, b, def, act)` → `cap_missions:` entries
- `VeafCombatMission:new():...:addElement(VeafCombatMissionElement:new():...):...` chains → `combat_missions:` entries
- Long-string briefings `[[...]]` extracted to YAML multi-line `|` strings
- `VeafCombatMissionElement` fields: `name`, `groups`, `scalable`, `spawned`

**YAML-013 — Tests**
New `test/python/test_config_generator.py`:
- `test_mission_identity()`: `mission:` section → correct Lua output
- `test_security_block()`: password hashes + `SecurityDisabled`
- `test_auto_initialize_no_init_section()`: `enable: true` without `init:` → `initialize()` emitted
- `test_radio_init_params()`: `RADIO.init.help_menus: true` → `veafRadio.initialize(true)`
- `test_assets_table()`: assets list → correct Lua table literal
- `test_qra_builder_chain()`: QRA definition → correct `VeafQRA:new():set*():start()` output
- `test_combat_mission_briefing()`: multi-line briefing → `[[...]]` long string

Extend `test_config_migrator.py` (or `test_v5_converter.py`) with cases for the new extraction patterns.

**YAML-014 — Docs**
`MISSION_MAKER_GUIDE.md`: update "Module configuration" section to describe YAML → `veaf-config.lua` flow, new sections (`mission:`, `security:`, `settings:`, `qra:`, etc.), and `mission-script.lua` role.
`MIGRATION_GUIDE.md`: update convert-v5 section to reflect active extraction + renamed output files.

</details>


---

## Lot 11 — I18N: Internationalisation (EN + FR)

**Goal**: Auto-detect the user's language (OS locale or `--lang` flag) and deliver the full experience in that language: CLI output, generated file comments, and documentation. Ship EN and FR as first-class citizens.
**Branch**: `feature/i18n` → PR → `develop-v6`
**Depends on**: Lot 10 (generated-file comment strings stabilised)

| # | Ticket | Type | Effort | Depends on | Status |
|---|--------|------|--------|------------|--------|
| I18N-001 | i18n infrastructure: OS locale auto-detection + `--lang` CLI override, translation catalog loader (`veaf_libs/i18n.py`), `t()` helper | feat | 60 min | — | [x] |
| I18N-002 | Translate all user-visible CLI messages (typer help strings, Rich output, logger messages) — EN catalog first, FR translation | feat | 120 min | I18N-001 | [x] |
| I18N-003 | Translate comments in generated files (`veaf-config.lua`, `mission.yaml` template, `mission-script.lua` stub, `generate-config` output) | feat | 60 min | I18N-001, Lot 10 | [x] |
| I18N-004 | Translate `MISSION_MAKER_GUIDE.md` → `doc/fr/MISSION_MAKER_GUIDE.md` (FR version maintained alongside EN) | chore | 90 min | — | [x] |
| I18N-005 | `convert-v5` report output in detected language (scan table headers, action descriptions, warning messages) | feat | 45 min | I18N-002 | [x] |
| I18N-006 | `mission.yaml` `language:` field → emit `veaf.config.language` in Lua; translate `generate-config` YAML template comments | feat | 45 min | I18N-001, I18N-003 | [x] |
| I18N-007 | Full bilingual doc structure: FR translations of all doc guides (`pilot/fr/GUIDE.md`, `developer/fr/GUIDE.md`, `mission-maker/fr/scripts/*.md`), bilingual README headers, `--lang --help` pre-parse fix | chore | 120 min | I18N-004 | [x] |

**Raw total: 540 min → estimated (×1.15): ~621 min (~10h21)**

<details>
<summary>Ticket details</summary>

**I18N-001 — Infrastructure**
`veaf_libs/i18n.py`:
- At startup, detect language: read `--lang` CLI option (passed as a global typer callback) → fall back to `locale.getdefaultlocale()[0]` (e.g. `"fr_FR"` → `"fr"`) → fall back to `"en"`.
- Load the matching catalog from `veaf_libs/locales/<lang>.json` (plain dict of `key → string`). Fall back to `en.json` if the requested locale has no catalog.
- Expose `t(key: str, **kwargs) -> str`: looks up the key, formats with `kwargs` via `str.format_map`. Missing key returns the key itself (never crashes).
- Ship `veaf_libs/locales/en.json` (authoritative) and `veaf_libs/locales/fr.json` (FR translation).
- PyInstaller spec: include `veaf_libs/locales/` as data files.

**I18N-002 — CLI messages**
Convert all hard-coded user-visible strings in `veaf-tools.py`, `mission_builder/`, `weather_injector/`, `aircrafts_injector/`, `waypoints_injector/` etc. to `t("key")` calls. Strings that are internal log messages (debug/trace) stay as-is — only INFO/WARNING/ERROR messages visible in normal use are translated.
Catalog keys follow the pattern `<module>.<context>.<id>`, e.g. `build.start`, `convert_v5.no_mission_yaml`, `weather.clearsky_applied`.

**I18N-003 — Generated file comments**
`lua_config_generator.py` and `generate-config` command currently emit English inline comments. Extract these strings into the catalog. At generation time, call `t(key)` to emit comments in the active language.
Scope: section headers and field description comments in `veaf-config.lua`; every `# …` comment line in the `mission.yaml` template output.

**I18N-004 — FR documentation**
Create `doc/fr/MISSION_MAKER_GUIDE.md` as a full FR translation of `doc/MISSION_MAKER_GUIDE.md`. Maintain both files — a note at the top of each links to the other language. No automated sync: manual update on structural changes.

**I18N-006 — mission.yaml `language:` field + Lua emit**
Add `language: en|fr` (optional) to `mission.yaml`. `generate_config_lua()` emits `veaf.config.language = "fr"` when set so the Lua runtime can read it. Also translate every `#` comment line in the `generate_mission_yaml()` YAML template output using `t()`.

</details>

---

## Lot 12 — QUALITY: Nettoyage, consolidation et qualité du code

**Goal**: Résoudre les problèmes de qualité identifiés lors de la revue de code (mai 2026). Fixes ciblés, pas de changement structurel majeur.
**Branch**: `feature/quality-cleanup` → PR #316 → `develop-v6` ✅ merged 2026-05-20
**Depends on**: Lot 5 (release v6.1.0 terminée — ces fixes sont post-release)

| # | Ticket | File(s) | Type | Effort | Status |
|---|--------|---------|------|--------|--------|
| QUAL-001 | Supprimer `package.json` — version unique via `pyproject.toml` + `importlib.metadata` | `package.json`, `veaf-tools.py`, `veaf-tools-updater.py`, `veaf_build/cli.py` | chore | 45 min | [x] |
| QUAL-002 | Supprimer les `VERSION` hardcodées dans `veaf-tools.py` et `veaf-tools-updater.py` — utiliser `importlib.metadata.version("veaf-tools")` | `veaf-tools.py`, `veaf-tools-updater.py` | fix | 20 min | [x] |
| QUAL-003 | Factoriser `resolve_path()` dans `veaf_libs/paths.py` (utilisé par tools + updater) | `veaf_libs/`, `veaf-tools.py`, `veaf-tools-updater.py` | chore | 30 min | [x] |
| QUAL-004 | Factoriser `resolve_mission_file()` helper (pattern glob dupliqué 6+ fois) | `veaf-tools.py`, `veaf_libs/` | chore | 30 min | [x] |
| QUAL-005 | Fix `miz_tools.py:195` — ne pas `os.replace` après exception dans le try/except | `mission_tools/miz_tools.py` | fix | 15 min | [x] |
| QUAL-006 | Fix `progress.py:19` — bug de précédence d'opérateur (parenthèses manquantes) | `veaf_libs/progress.py` | fix | 10 min | [x] |
| QUAL-007 | Supprimer fichier fantôme `veaf_libs/__init__,py` (virgule dans le nom) | `veaf_libs/` | fix | 5 min | [x] |
| QUAL-008 | Fix typo `WheatherInjectorREADME` → `WeatherInjectorREADME` | `weather_injector/__init__.py`, `veaf-tools.py` | fix | 5 min | [x] |
| QUAL-009 | Vérifier et supprimer la dépendance `Pillow` si inutilisée | `pyproject.toml` | chore | 15 min | [x] |
| QUAL-010 | Ajouter bornes supérieures sur les dépendances critiques (PyInstaller compat) | `pyproject.toml` | chore | 20 min | [x] |
| QUAL-011 | Découper `veaf-tools.py` (1541 lignes) en package `commands/` | `veaf-tools.py` → `veaf_tools/commands/*.py` | chore | 120 min | [x] |
| QUAL-012 | Créer `BaseWorker` ABC pour formaliser le pattern worker | `veaf_libs/base_worker.py` + workers | chore | 45 min | [x] |
| QUAL-013 | Remédiation mypy : retirer `ignore_errors` pour 5 premiers modules (veaf_libs.logger, mission_tools.mission_constants, mission_tools.miz_tools, veaf_libs.progress, presets_injector.presets_manager) | `pyproject.toml` + modules concernés | fix | 90 min | [x] |
| QUAL-014 | Lua: normaliser format `Id` (supprimer trailing `" - "`) dans tous les modules | `veafGroundAI.lua`, `veafAirWaves.lua`, `veafEventHandler.lua`, etc. | chore | 20 min | [x] |
| QUAL-015 | Lua: remettre `LogLevel` à `nil` dans `veafSpawn.lua` et `veafMarkers.lua` (actuellement "trace" en production) | `veafSpawn.lua`, `veafMarkers.lua` | fix | 5 min | [x] |
| QUAL-016 | Lua: ajouter `pcall` wrapping aux entry points critiques (scheduled callbacks, event handlers) | `veaf.lua`, `veafQraManager.lua`, `veafAirWaves.lua`, `veafGroundAI.lua` | fix | 45 min | [x] |
| QUAL-017 | Lua: factoriser `statusToString()` dupliqué en helper `veaf.enumToString(value, mapping)` | `veaf.lua`, `veafQraManager.lua`, `veafAirWaves.lua`, `veafGroundAI.lua` | chore | 20 min | [x] |
| QUAL-018 | Lua: remplacer `getRandomizableNumeric_norandom()` hardcodé par calcul algorithmique de la médiane | `veaf.lua` | fix | 30 min | [x] |
| QUAL-019 | Lua: nettoyer dead code (blocs commentés GoToWaypoint, StaticObject.getByName, etc.) | multiples fichiers | chore | 20 min | [x] |
| QUAL-020 | Lua: corriger variable shadowing (`local coalition = coalition` dans `veaf.lua:2571`) | `veaf.lua`, `veafSpawn.lua` | fix | 15 min | [x] |
| QUAL-021 | Python + Lua: ajouter tests unitaires pour `miz_tools.py` (read/write .miz) | `test/veaf-tools/` + nouveau test file | feat | 60 min | [x] |
| QUAL-022 | Lua: enrichir `dcs_mocks.lua` — supporter `Unit.getByName`/`Group.getByName` configurables pour débloquer les tests logiques | `test/lua/dcs_mocks.lua` | feat | 45 min | [x] |
| QUAL-023 | Lua: ajouter tests state-machine pour `VeafQRA` lifecycle (spawn/despawn/rearm cycle) | `test/lua/test_veafQraManager.lua` | feat | 60 min | [x] |
| QUAL-024 | Documentation: supprimer ou archiver `todo.md` | `todo.md` | chore | 5 min | [x] |
| QUAL-025 | Documentation: résoudre date `[6.0.2] — 2025-11-??` dans `CHANGELOG.md` | `CHANGELOG.md` | fix | 5 min | [x] |
| QUAL-026 | Documentation: vérifier/corriger lien vers `RELEASE_NOTES.md` dans `README.md` | `README.md` | fix | 10 min | [x] |
| QUAL-027 | Documentation: vérifier et corriger les liens `fr/scripts/` dans `doc/mission-maker/` | `doc/mission-maker/` | fix | 15 min | [x] |

**Raw total: 865 min → estimated (×1.15): ~995 min (~16h35)**

<details>
<summary>Ticket details</summary>

**QUAL-001 — Supprimer package.json**
`package.json` est un vestige du build system Node.js de la v5. En v6 Python-native, la source de vérité pour la version est `pyproject.toml`. Le seul consommateur est `veaf_build/cli.py:_resolve_version()` qui lit `package.json` comme fallback.
- Supprimer `package.json`
- Dans `veaf_build/cli.py`: remplacer `_resolve_version()` par lecture de `pyproject.toml` via `tomllib` (stdlib 3.11+) ou `importlib.metadata.version("veaf-tools")`
- Dans `veaf-tools-updater.py`: `get_installed_version()` lit actuellement `package.json` du dossier mission — à remplacer par un fichier `veaf-version.json` déposé dans `published/` au build time

**QUAL-002 — Supprimer VERSION hardcodées**
- Remplacer `VERSION: str = "6.0.4"` par `VERSION = importlib.metadata.version("veaf-tools")` dans les deux entry-points
- En mode PyInstaller (frozen), `importlib.metadata` fonctionne si le package est correctement bundlé — vérifier avec `veaf-tools.spec`
- Fallback: lire `pyproject.toml` du répertoire racine via `tomllib`

**QUAL-005 — Fix miz_tools.py os.replace after exception**
Ligne 187-195 : le `os.replace(temp_file, final_path)` est hors du try/except, donc exécuté même si l'écriture a échoué. Déplacer dans le bloc `try` ou conditionner à un flag `success`.

**QUAL-006 — Fix progress.py operator precedence**
`if sys.stdout and not sys.stdout.encoding or ...` — le `not` a priorité sur `and`. Corriger avec des parenthèses explicites : `if sys.stdout and (not sys.stdout.encoding or ...)`.

**QUAL-011 — Découper veaf-tools.py**
Structure cible :
```
src/python/veaf-tools/
  veaf_tools/
    __init__.py
    main.py              ← app = typer.Typer()
    commands/
      build.py           ← @app.command() build
      extract.py         ← @app.command() extract
      convert.py         ← @app.command() convert-v5
      inject_presets.py
      inject_waypoints.py
      inject_weather.py
      inject_aircrafts.py
      extract_aircrafts.py
      extract_waypoints.py
      generate_config.py
      migrate_config.py
      prepare.py
```
L'entry-point `veaf-tools.py` importe `veaf_tools.main:app` et appelle `app()`.

**QUAL-013 — Remédiation mypy (5 premiers modules)**
Retirer `ignore_errors = true` pour les 5 modules les plus simples, fixer les erreurs de type. Objectif : réduire la dette de 18 → 13 modules ignorés comme premier pas. Prioriser les modules fondamentaux (`logger`, `mission_constants`, `miz_tools`).

**QUAL-016 — pcall wrapping**
Ajouter un helper `veaf.safeCall(fn, ...)` qui wrappe dans `pcall`, log l'erreur si échec, et retourne `nil`. L'utiliser dans :
- `mist.scheduleFunction` callbacks (QRA check, AirWaves check, GroundAI check)
- `veafEventHandler` dispatch (handler errors shouldn't crash DCS)
- `veafMarkers` marker change handler

**QUAL-022 — Enrichir dcs_mocks.lua**
Ajouter à `dcs_mocks.lua` :
- `dcs_mocks.addUnit(name, data)` → `Unit.getByName(name)` retourne un objet mocké
- `dcs_mocks.addGroup(name, data)` → `Group.getByName(name)` retourne un objet mocké avec `:getUnits()`, `:getController()`
- Mocker `:isExist()`, `:getLife()`, `:getPoint()`, `:inAir()`
Cela débloque les tests unitaires des state machines (QRA, AirWaves).

</details>

---

## Lot 13 — DISCUSS: Standards industrie — à évaluer et décider

**Goal**: Évaluer les standards industrie manquants et décider lesquels adopter. Chaque ticket est un point de discussion/décision avant implémentation éventuelle.
**Branch**: décision d'abord, implémentation dans un lot futur
**Statut**: 🟡 À discuter — pas d'implémentation avant validation

| # | Ticket | Sujet | Type | Effort si adopté | Status |
|---|--------|-------|------|-----------------|--------|
| DISC-001 | Pre-commit hooks (`pre-commit` framework) : ruff + stylua + luacheck + detect-secrets | chore | 45 min | [ ] |
| DISC-002 | Ajouter `luacheck` au CI (lint statique Lua — undefined globals, unused vars, shadowing) | chore | 60 min | [ ] |
| DISC-003 | Coverage reporting en CI (Codecov ou Coveralls) + badge README + seuil `--cov-fail-under` | chore | 30 min | [ ] |
| DISC-004 | `CONTRIBUTING.md` + PR template + issue templates (bug report / feature request) | chore | 45 min | [ ] |
| DISC-005 | `SECURITY.md` — politique de disclosure des vulnérabilités | chore | 15 min | [ ] |
| DISC-006 | `CODEOWNERS` — auto-assign reviewers par path (`src/scripts/` → Lua team, `src/python/` → Python team) | chore | 10 min | [ ] |
| DISC-007 | Dependabot ou Renovate — auto-update des dépendances Python + GitHub Actions | chore | 20 min | [ ] |
| DISC-008 | Release automation complète — GitHub Actions workflow sur tag push (build + publish, zéro intervention manuelle) | feat | 120 min | [ ] |
| DISC-009 | `.editorconfig` — uniformité des settings IDE (indentation, EOL, trim trailing whitespace) | chore | 10 min | [ ] |
| DISC-010 | DevContainer / Docker — environnement dev reproductible (Python 3.13 + Lua 5.1 + outils) | feat | 90 min | [ ] |
| DISC-011 | Signed commits / tag signing — intégrité supply chain | chore | 15 min | [ ] |
| DISC-012 | Branch protection rules — require CI pass + review avant merge | chore | 10 min | [ ] |
| DISC-013 | Changelog automation (`git-cliff` ou `release-please` + conventional commits) | feat | 60 min | [ ] |
| DISC-014 | Documentation versionnée — lier les docs à une release (GitHub Pages tags ou dossiers versionnés) | feat | 90 min | [ ] |
| DISC-015 | SBOM (Software Bill of Materials) — traçabilité des dépendances embarquées dans l'exe | chore | 30 min | [ ] |
| DISC-016 | API deprecation warnings — système de warnings Lua quand des fonctions legacy sont appelées | feat | 45 min | [ ] |
| DISC-017 | Secret scanning — activer GitHub secret scanning ou intégrer `gitleaks` en CI | chore | 15 min | [ ] |
| DISC-018 | Monorepo workspace Poetry — structurer `veaf-tools` + `veaf_build` comme un vrai workspace avec dépendances explicites | chore | 60 min | [ ] |

**Effort total si tout adopté: ~770 min (~12h50)**
⚠️ Chaque ticket doit être discuté individuellement — certains seront adoptés, d'autres rejetés ou reportés.

<details>
<summary>Points de discussion par ticket</summary>

**DISC-001 — Pre-commit hooks**
- **Pour** : Catch les erreurs avant le push, impossible d'oublier de formatter
- **Contre** : Friction pour les contributeurs occasionnels, complexifie le setup
- **Question** : Est-ce que les contributeurs sont suffisamment techniques pour installer `pre-commit` ? Ou suffit-il de compter sur la CI ?

**DISC-002 — Luacheck**
- **Pour** : Détecte des vrais bugs (undefined globals, unused vars, variable shadowing comme `local coalition = coalition`). StyLua ne vérifie que le formatage.
- **Contre** : Configuration initiale complexe (beaucoup de globals DCS à déclarer), bruit potentiel
- **Question** : Le `.luarc.json` remplit déjà partiellement ce rôle. Luacheck en CI apporte-t-il un gain suffisant ?
- **Recommandation** : Oui, fort gain. La liste de globals est déjà dans `.luarc.json` — convertible en `.luacheckrc`.

**DISC-003 — Coverage CI**
- **Pour** : Visibilité, empêche les régressions, motive l'écriture de tests
- **Contre** : Seuil bas (15%) est symbolique ; seuil haut inatteignable à court terme
- **Question** : Quel seuil initial ? Monter graduellement (15% → 30% → 50%) ?
- **Recommandation** : Commencer à 15%, monter de 5% par lot.

**DISC-004 — CONTRIBUTING.md**
- **Pour** : Standard OSS, onboarde les nouveaux contributeurs
- **Contre** : Overhead de maintenance si peu de contributeurs externes
- **Question** : Le projet a-t-il des contributeurs externes réguliers ou est-ce principalement l'équipe VEAF ?

**DISC-005 — SECURITY.md**
- **Pour** : GitHub affiche un avertissement si absent, standard pour tout projet public
- **Contre** : Quasi-gratuit à créer (template GitHub)
- **Recommandation** : Adopter (5 min de travail réel)

**DISC-006 — CODEOWNERS**
- **Pour** : Auto-assign les bons reviewers, protège les chemins critiques
- **Contre** : Nécessite de définir les responsabilités formellement
- **Question** : Qui sont les reviewers Lua vs Python ?

**DISC-007 — Dependabot/Renovate**
- **Pour** : Alerte sur les vulnérabilités, PR automatiques pour updates
- **Contre** : Bruit (PRs fréquentes), risque de casser PyInstaller si pas de bornes
- **Recommandation** : Adopter Dependabot avec `open-pull-requests-limit: 5` et grouping

**DISC-008 — Release automation**
- **Pour** : Zéro intervention manuelle → zéro risque d'erreur, reproductible
- **Contre** : Le process actuel (CLI `veaf-build`) fonctionne et permet une pause pour éditer les release notes
- **Question** : Veut-on garder la pause manuelle (release notes) ou passer en full-auto (changelog auto-généré) ?
- **Recommandation** : Hybrid — tag push déclenche le build + upload, mais les release notes restent manuelles (pré-écrites dans CHANGELOG.md avant le tag)

**DISC-009 — .editorconfig**
- **Pour** : Fonctionne avec tous les IDE, pas de dépendance à VS Code settings
- **Contre** : Quasi-gratuit, pas de raison de ne pas le faire
- **Recommandation** : Adopter immédiatement (5 min)

**DISC-010 — DevContainer**
- **Pour** : Zéro-config pour les nouveaux développeurs, environnement identique pour tous
- **Contre** : Docker requis, overhead pour dev habitués à leur propre env
- **Question** : Les contributeurs sont-ils sous Windows (DCS = Windows only) ? Un devcontainer Linux est-il pertinent pour un projet DCS ?
- **Recommandation** : Utile surtout pour la CI reproductible. En dev local, documenter le setup Windows suffit peut-être.

**DISC-011 — Signed commits**
- **Pour** : Intégrité supply chain (important pour un .exe distribué à la communauté)
- **Contre** : Complexifie le workflow (GPG keys), freine les contributeurs occasionnels
- **Recommandation** : Au minimum, signer les tags de release (pas tous les commits)

**DISC-013 — Changelog automation**
- **Pour** : Plus d'oublis, changelog toujours à jour
- **Contre** : Impose conventional commits (`feat:`, `fix:`, `chore:`) — changement d'habitude
- **Question** : L'équipe est-elle prête à adopter conventional commits ?

**DISC-014 — Documentation versionnée**
- **Pour** : Un utilisateur en v6.0.3 voit les docs correspondantes, pas les docs de develop
- **Contre** : Complexité GitHub Pages, maintenance de branches docs
- **Recommandation** : Reporter — pertinent quand il y aura des breaking changes entre versions

**DISC-016 — Deprecation warnings Lua**
- **Pour** : Migration douce quand des fonctions sont renommées/supprimées
- **Contre** : Overhead (wrapper chaque fonction deprecated)
- **Recommandation** : Utile surtout pour LUAR-001 (split veafSpawn) — implémenter quand le refactoring commence

</details>
