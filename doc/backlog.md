# Backlog — VEAF Mission Creation Tools v6

## Calibration Table

| Lot | Estimated (min) | Actual (min) | Ratio | Note |
|-----|----------------|--------------|-------|------|
| *(no lot completed yet)* | | | | Initial factor: 1.15 |

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

## Lot 1 — INFRA: Python quality gate + CI

**Goal**: Python quality gate working locally and in CI before any feature work.
**Branch**: `feature/infra-poetry-quality-gate` → PR → `develop-v6`

| # | Ticket | Type | Effort | Depends on | Status |
|---|--------|------|--------|------------|--------|
| INFRA-001 | Create `pyproject.toml` with Poetry, migrate `requirements.txt` | chore | 45 min | — | [ ] |
| INFRA-002 | Configure ruff (lint + format) in `pyproject.toml` | chore | 20 min | INFRA-001 | [ ] |
| INFRA-003 | Configure mypy in `pyproject.toml` | chore | 30 min | INFRA-001 | [ ] |
| INFRA-004 | Fix all ruff/mypy violations in `src/python` | fix | 60 min | INFRA-002, INFRA-003 | [ ] |
| INFRA-005 | Configure pytest globally (`testpaths`, coverage) | chore | 30 min | INFRA-001 | [ ] |
| INFRA-006 | Add `python-quality` job in `.github/workflows/` | chore | 30 min | INFRA-001 | [ ] |

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
| TOOL-001 | Version check on startup + update prompt | feat | 45 min | — | [ ] |
| TOOL-002 | Centralized `~/.veaf/` directory (VEAF_HOME) | feat | 30 min | — | [ ] |
| TOOL-003 | Build embeds Lua module list in the exe | feat | 60 min | — | [ ] |

**Raw total: 135 min → estimated (×1.15): ~155 min (~2h35)**

<details>
<summary>Ticket details</summary>

**TOOL-001 — Version check**
On `veaf-tools` startup, before running the command: compare the current version (constant in code, set from `package.json` at build time) against the latest GitHub release (API `https://api.github.com/repos/VEAF/VEAF-Mission-Creation-Tools/releases/latest`). 2-second timeout so offline use is not blocked. If a newer version exists: display a colored Rich warning with the available version and `veaf-tools-updater update` hint.

**TOOL-002 — VEAF_HOME**
Define `~/.veaf/` as the centralized directory for: installed Lua scripts, preferences, logs. Resolution priority: `VEAF_HOME` env var > default `~/.veaf/`. Auto-create the directory if it does not exist. Migrate all `veaf_libs` paths that currently reference user-specific locations.

**TOOL-003 — Embed module list**
In `build-and-release.py`: scan `src/scripts/veaf/veaf*.lua`, extract ID and version via regex (`veafXxx.Id`, `veafXxx.Version`). Embed in the exe as a Python constant or bundled JSON file (PyInstaller `--add-data`). Expose via `veaf-tools about --modules` (Rich table).

</details>

---

## Lot 3 — TUI: InquirerPy interactive mode

**Goal**: `veaf-tools` with no arguments opens a guided interactive mode instead of showing help.
**Branch**: `feature/tui-interactive` → PR → `develop-v6`
**Depends on**: Lot 1 (quality gate), Lot 2 TOOL-002 (VEAF_HOME for preferences)

| # | Ticket | Type | Effort | Depends on | Status |
|---|--------|------|--------|------------|--------|
| FEAT-001 | InquirerPy interactive mode when no argument is given | feat | 60 min | — | [ ] |
| FEAT-002 | Persist preferences in `~/.veaf/preferences.json` | feat | 30 min | TOOL-002 | [ ] |
| FEAT-003 | Pre-fill prompts from saved preferences | feat | 30 min | FEAT-002 | [ ] |

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
| LUA-001 | `veaf.config` per module + `enable=true` option in `veaf.lua` | feat | 90 min | — | [ ] |
| LUA-002 | Load and apply `missionconfig.lua` | feat | 60 min | LUA-001 | [ ] |
| LUA-003 | Deferred module initialization after missionconfig load | feat | 60 min | LUA-002 | [ ] |
| LUA-004 | `veaf-tools generate-config` command → `missionconfig.lua` template | feat | 45 min | LUA-001, TOOL-003 | [ ] |
| LUA-005 | Module selection + options via mission YAML (`veaf-tools build`) | feat | 60 min | LUA-004 | [ ] |

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

## Lot 5 — RELEASE: v6.1.0

**Goal**: Merge v6 to master and publish the official release.
**From**: `develop-v6` directly

| # | Ticket | Type | Effort | Depends on | Status |
|---|--------|------|--------|------------|--------|
| REL-001 | Finalize `CHANGELOG.md` for v6.1.0 | chore | 20 min | Lots 1–4 | [ ] |
| REL-002 | Write `RELEASE_NOTES.md` for v6.1.0 | chore | 20 min | REL-001 | [ ] |
| REL-003 | Squash merge `develop-v6` → `master` | chore | 15 min | REL-002 | [ ] |
| REL-004 | Tag `v6.1.0` + publish GitHub (`build-and-release.py publish`) | chore | 30 min | REL-003 | [ ] |

**Estimated total: ~85 min (~1h30)**

---

## Lot 6 — BONUS: Logger filter + DCSUnits doc

**Goal**: Quality-of-life improvements after the priority lots.
**Branch**: `feature/bonus-logger-doc` → PR → `develop-v6`
**Depends on**: Lot 4 (LUA-001), Lot 2 (TOOL-003)

| # | Ticket | Type | Effort | Depends on | Status |
|---|--------|------|--------|------------|--------|
| LUA-006 | `--log-modules` option in `veaf-tools` to filter which modules log | feat | 90 min | LUA-001 | [ ] |
| TOOL-004 | Parse `dcsUnits.lua` → dynamic markdown doc generated before publish | feat | 90 min | TOOL-003 | [ ] |

**Raw total: 180 min → estimated (×1.15): ~210 min (~3h30)**

<details>
<summary>Ticket details</summary>

**LUA-006 — Logger filter**
`--log-modules spawn,radio,assets` option on `veaf-tools build` and `veaf-tools inject-*` commands. Translates to a section in the generated `missionconfig.lua` that disables logging (or forces `logLevel = "error"`) for all unlisted modules. Useful for debugging a mission without log noise.

**TOOL-004 — DCSUnits doc**
In `build-and-release.py`, before publish: parse `src/scripts/veaf/dcsUnits.lua` (Lua data table), extract the unit list with category and type, generate `doc/DCS_UNITS.md` (markdown table sorted by category). Include in the published artifact.

</details>

---

## Lot 7 — LUA FIXES: High-priority bug fixes from issue triage

**Goal**: Fix the most impactful Lua bugs, prioritized from issue triage.
**Branch**: `fix/lua-high-priority` → PR → `develop-v6`
**Depends on**: Lot 4 (LUA-CONFIG — same files, avoid conflicts)

| # | Ticket | Issue | Type | Effort | Status |
|---|--------|-------|------|--------|--------|
| LUA-FIX-001 | Fix `math.atan` wind direction calculation (Lua 5.1 compat) | #287 | fix | 30 min | [ ] |
| LUA-FIX-002 | Fix stale DCS object ref in `getNearestAirbaseList` | #302 | fix | 45 min | [ ] |
| LUA-FIX-003 | Fix dynamic slots breaking QRA, Radio, AirWaves, Sanctuary, Grass | #293 | fix | 90 min | [ ] |
| LUA-FIX-004 | Fix QRA not triggered by dynamic slot aircraft | #299 | fix | 45 min | [ ] |
| LUA-FIX-005 | Fix CasMission/CombatZone always using Blue bullseye | #304 | fix | 30 min | [ ] |
| LUA-FIX-006 | Update unit list for DCS 2.9.19.13478 new assets | #295, #296 | chore | 60 min | [ ] |

**Raw total: 300 min → estimated (×1.15): ~345 min (~5h45)**

---

## Summary

| Lot | Estimate | Status |
|-----|----------|--------|
| Phase 0 — Restart | ~3h | [x] |
| Lot 1 — INFRA | ~4h15 | [ ] |
| Lot 2 — CLI | ~2h35 | [ ] |
| Lot 3 — TUI | ~2h20 | [ ] |
| Lot 4 — LUA-CONFIG | ~6h | [ ] |
| Lot 5 — RELEASE | ~1h30 | [ ] |
| Lot 6 — BONUS | ~3h30 | [ ] |
| Lot 7 — LUA FIXES | ~5h45 | [ ] |
| **Total** | **~29h** | |

*Initial calibration factor: 1.15 — recalculate after each completed lot.*
