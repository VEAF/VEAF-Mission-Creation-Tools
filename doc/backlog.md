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

**Estimated total: ~245 min**

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
| **Total** | **~44h** | |

*Initial calibration factor: 1.15 — recalculate after each completed lot.*
