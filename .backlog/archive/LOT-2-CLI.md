# Lot 2 — CLI: veaf-tools improvements

Status: ✅ done

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
