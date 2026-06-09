# Backlog Archive — VEAF Mission Creation Tools v6

Lots completed on **2026-05-16** (archived 2026-05-20 — more than 3 days after completion).

→ [Active backlog](backlog.md)

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

## Lots archivés le 2026-05-29

→ [Backlog actif](backlog.md)

---

## Lot UPDATER-FIX — Séparation updater / prepare / workflow v5

**Goal**: Corriger l'architecture updater → ne plus créer de fichiers `src/` par défaut. `prepare` est la commande dédiée pour initialiser un nouveau dossier. Supprimer `build.cmd` du toolkit v6. Corriger la doc MIGRATION_GUIDE (partir du dossier v5 existant, pas d'un dossier vide).
**Branch**: `feature/updater-no-src-defaults` → PR → `develop-v6`

| # | Ticket | Fichiers touchés | Type | Effort | Status |
|---|--------|-----------------|------|--------|--------|
| UPDFIX-001 | Supprimer `src/build-scripts/build.cmd` (plus de `build.cmd` dans le toolkit v6) | `src/build-scripts/build.cmd` | chore | 5 min | ✅ |
| UPDFIX-002 | `veaf-tools-updater.py` — `_install_defaults()` n'installe plus rien dans `src/` ; affiche juste un message vers `veaf-tools prepare` au premier install | `src/python/veaf-tools/veaf-tools-updater.py` | fix | 15 min | ✅ |
| UPDFIX-003 | `prepare.py` — corriger la résolution de chemin (sans bloc `build_scripts`) | `src/python/veaf-tools/veaf_tools/commands/prepare.py` | fix | 20 min | ✅ |
| UPDFIX-004 | Doc `MIGRATION_GUIDE.md/.fr.md` — workflow v5 : partir du dossier existant, pas d'un dossier vide | `doc/mission-maker/MIGRATION_GUIDE.md`, `doc/mission-maker/MIGRATION_GUIDE.fr.md` | doc | 20 min | ✅ |
| UPDFIX-005 | Doc `GUIDE.md/.fr.md` — supprimer `build.cmd` de la structure de dossier | `doc/mission-maker/GUIDE.md`, `doc/mission-maker/GUIDE.fr.md` | doc | 5 min | ✅ |

**Estimated total: ~65 min**

---

## Lot 17 — USER-CONFIG: Configuration globale utilisateur + i18n complète

**Goal**: Ajouter un fichier `~/veafmct.yaml` de configuration globale utilisateur ; compléter l'audit i18n (toutes les chaînes des commandes CLI traduites) ; nouvelle commande `user-config`.
**Branch**: `feature/user-global-config` → PR → `develop-v6`

| # | Ticket | Fichiers touchés | Type | Effort | Status |
|---|--------|-----------------|------|--------|--------|
| UC-001 | Créer `veaf_libs/user_config.py` + tests | `user_config.py`, `test_user_config.py` | feat | 45 min | ✅ |
| UC-002 | Brancher `user_config.get_lang()` dans `i18n._detect_lang()` | `veaf_libs/i18n.py` | feat | 15 min | ✅ |
| UC-003 | Brancher `user_config.get_check_updates()` dans `app.py` | `veaf_tools/app.py` | feat | 10 min | ✅ |
| UC-004 | Audit i18n complet — 55+ clés locales + mise à jour de toutes les commandes | `locales/en.json`, `locales/fr.json`, toutes les commandes | feat | 90 min | ✅ |
| UC-005 | Nouvelle commande `user-config` | `veaf_tools/commands/user_config.py` | feat | 20 min | ✅ |

**Estimated total: ~3h**

---

## Lot 16 — LUA-COVERAGE: Couverture de tests ≥ 50 % par module

**Goal**: Faire passer chaque module Lua à au moins 50 % de couverture de ligne (mesurée via `poetry run test-lua --coverage`).
Couverture initiale (2026-05-23) : 48,35 % global, mais 26 modules en dessous du seuil.
**Branch**: une branche par ticket `test/cov-xxx` → PR → `develop-v6`
⚠️ Certains modules nécessitent d'étoffer `dcs_mocks.lua` pour exposer des chemins de code difficiles à atteindre.

| # | Ticket | Modules ciblés (couverture actuelle) | Type | Effort | Status |
|---|--------|--------------------------------------|------|--------|--------|
| COV-001 | `veaf.lua` → 50 % (31 %) — utilitaires core : `veaf.p`, `veaf.safeCall`, timers, loggers, `getCountryForCoalition`, `getClosestAirbase` | `veaf.lua` | chore | 90 min | ✅ |
| COV-002 | `veafSpawn` sub-modules → 50 % chacun — Core (19 %), Ground (6 %), Aircraft (3 %), Effects (7 %) ; nécessite mock `mist.dynAdd` et `trigger.action.*` | `veafSpawnCore`, `veafSpawnGround`, `veafSpawnAircraft`, `veafSpawnEffects` | chore | 180 min | ✅ |
| COV-003 | `veafCombatMission` (32 %) + `veafCombatZone` (26 %) → 50 % chacun — logique d'état de zone, spawn de vagues, victoire | `veafCombatMission.lua`, `veafCombatZone.lua` | chore | 120 min | ✅ |
| COV-004 | `veafAirWaves` (34 %) + `veafCarrierOperations` (9 %) → 50 % chacun — FSM AirWave, helpers carrier | `veafAirWaves.lua`, `veafCarrierOperations.lua` | chore | 120 min | ✅ |
| COV-005 | `veafRadio` (30 %) + `veafShortcuts` (10 %) → 50 % chacun — construction de menus, dispatch de raccourcis | `veafRadio.lua`, `veafShortcuts.lua` | chore | 90 min | ✅ |
| COV-006 | `veafQraCore` (43 %) + `veafQraLogistics` (31 %) + `veafSkynetIadsHelper` (11 %) + `veafSkynetIadsMonitor` (23 %) → 50 % chacun | `veafQraCore.lua`, `veafQraLogistics.lua`, `veafSkynetIadsHelper.lua`, `veafSkynetIadsMonitor.lua` | chore | 90 min | ✅ |
| COV-007 | `veafCasMission` (47 %) + `veafTransportMission` (21 %) + `veafGroundAI` (28 %) + `veafMove` (18 %) → 50 % chacun | `veafCasMission.lua`, `veafTransportMission.lua`, `veafGroundAI.lua`, `veafMove.lua` | chore | 90 min | ✅ |
| COV-008 | `veafAirbases` (29 %) + `veafAssets` (23 %) + `veafInterpreter` (39 %) + `veafMissileGuardian` (36 %) + `veafRemote` (32 %) + `veafSanctuary` (31 %) + `veafWeather` (37 %) → 50 % chacun | 7 fichiers | chore | 120 min | ✅ |

**Raw total: 900 min → estimated (×1.15): ~1035 min (~17h15)**

> Modules déjà ≥ 50 % (non ciblés) : `dcsDataExport` (55 %), `veafCacheManager` (100 %), `veafCommands` (76 %), `veafEventHandler` (83 %), `veafGrass` (70 %), `veafMarkers` (52 %), `veafNamedPoints` (97 %), `veafQraManager` (100 %), `veafSecurity` (59 %), `veafSpawn` proxy (100 %), `veafSpawnParser` (54 %), `veafTime` (87 %), `veafUnits` (78 %).

---

## Lot 9 — LUA-REFACTOR: Refactoring structurel des modules majeurs

**Goal**: Réduire la complexité des modules les plus chargés du codebase Lua.
Chaque ticket est indépendant mais risqué — à traiter un par un avec tests en mission réelle.
**Branch**: une branche par ticket `refactor/lua-xxx` → PR → `develop-v6`
⚠️ Impact fort sur les missions existantes : chaque PR doit être testée en mission avant merge.

| # | Ticket | File(s) | Type | Effort | Status |
|---|--------|---------|------|--------|--------|
| LUAR-001 | Scinder `veafSpawn.lua` (3200+ lignes) en 4 modules thématiques — `veafSpawn.lua` devient un proxy de backward compatibility | `veafSpawn*.lua` | feat | 240 min | ✅ |
| LUAR-002 | Machine d'état explicite (FSM) pour `AirWaveZone` | `veafAirWaves.lua` | feat | 120 min | ✅ |
| LUAR-003 | Scinder `VeafQRA` (1200+ lignes) en `VeafQRACore` + `VeafQRALogistics` | `veafQraManager.lua` | feat | 150 min | ✅ |
| LUAR-004 | `RadioMenuBuilder` — abstraction de la construction des menus dans veafRadio | `veafRadio.lua` | feat | 90 min | ✅ |

**Raw total: 600 min → estimated (×1.15): ~690 min (~11h30)**

> LUAR-005 migré vers **Lot 14 — ARCH-COMMANDS** (ARCH-004 + ARCH-005) après analyse : le pattern marker/command est transversal à 8+ modules.

<details>
<summary>Ticket details</summary>

**LUAR-001 — Split veafSpawn.lua**
3200+ lignes, 35+ fonctions publiques avec 5 responsabilités distinctes. Proposition de découpage :
- `veafSpawnCore.lua` — `executeCommand`, parsing de markers, `doSpawnGroup`, `_createDcsUnits`, dessin (addPointToDrawing, drawCircle, drawSquare, eraseDrawing)
- `veafSpawnGround.lua` — `spawnGroup`, `spawnInfantryGroup`, `spawnArmoredPlatoon`, `spawnAirDefenseBattery`, `spawnTransportCompany`, `spawnFullCombatGroup`, `spawnConvoy`, `spawnFarp`, `spawnFob`
- `veafSpawnAircraft.lua` — `spawnUnit` (avions/hélicos), `spawnCombatAirPatrol`, JTAC/lasing
- `veafSpawnEffects.lua` — `spawnBomb`, `spawnSmoke`, `spawnSignalFlare`, `spawnIlluminationFlare`, `spawnCargo`, `spawnLogistic`, `destroy`, `teleport`

**Décision (2026-05-21)** : `veafSpawn.lua` devient un **proxy** qui charge les 4 sous-modules et ré-exporte les fonctions publiques — les missions existantes n'ont rien à changer. Pas de deprecation warnings (DISC-016 rejeté) : le proxy est transparent et silencieux, les missions continueront de fonctionner indéfiniment.

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

## Lot 14 — ARCH-COMMANDS: Refactoring de l'infrastructure commandes/marqueurs

**Goal**: Éliminer la duplication du pattern `onEventMarkChange + executeCommand + markTextAnalysis` répété dans 8+ modules, et remplacer les dispatchers if/elseif manuels par des registres dynamiques.
Chaque ticket est indépendant — ordre recommandé : ARCH-001 → ARCH-002 → ARCH-003, puis ARCH-004 → ARCH-005 en parallèle.
**Branch**: une branche par ticket `refactor/arch-xxx` → PR → `develop-v6`
⚠️ ARCH-001 : l'ordre d'enregistrement dans le registre doit reproduire exactement l'ordre actuel du if/elseif (veafShortcuts en premier).

| # | Ticket | File(s) | Type | Effort | Status |
|---|--------|---------|------|--------|--------|
| ARCH-001 | Registre de modules dans `veafInterpreter.execute` — remplacer le if/elseif de 8 modules par un tableau ordonné ; chaque module s'auto-enregistre dans `initialize()` | `veafInterpreter.lua` + 8 modules | chore | 60 min | ✅ |
| ARCH-002 | Registre de modules dans `veafRemote.executeCommandFromRemote` — `veafRemote.registerRemoteModule(name, fn)` ; remplace le switch string sur 7 modules | `veafRemote.lua` + 7 modules | chore | 60 min | ✅ |
| ARCH-003 | Factoriser le boilerplate `onEventMarkChange` — helper `veafMarkers.makeMarkHandler(fn)` qui génère la fonction standard (invertedCoalition + executeCommand + removeMark) ; remplace 8 fonctions quasi-identiques | `veafMarkers.lua` + 8 modules | chore | 90 min | ✅ |
| ARCH-004 | Extraire `veafSpawnParser.lua` — isoler `markTextAnalysis` + `convertLaserToFreq` hors de `veafSpawnCore.lua` ; le parseur devient testable indépendamment (portage LUAR-005 pt.1) | `veafSpawnCore.lua` → `veafSpawnParser.lua`, `veafSpawn.lua` | feat | 60 min | ✅ |
| ARCH-005 | Système de handlers dans `veafSpawnCore.executeCommand` — `veafSpawn.registerCommandHandler(key, fn)` ; les 4 sous-modules s'enregistrent ; Core < 300 lignes (portage LUAR-005 pt.2) | `veafSpawnCore.lua`, `veafSpawnGround.lua`, `veafSpawnAircraft.lua`, `veafSpawnEffects.lua` | feat | 120 min | ✅ |

**Raw total: 390 min → estimated (×1.15): ~449 min (~7h30)**

<details>
<summary>Ticket details</summary>

**ARCH-001 — Registre veafInterpreter**
Actuellement `veafInterpreter.execute()` contient 8 `if/elseif` hardcodés dans l'ordre : veafShortcuts → veafSpawn → veafNamedPoints → veafCasMission → veafSecurity → veafMove → veafRadio → veafRemote. Chaque ajout de module nécessite de modifier ce fichier.
Proposition :
```lua
veafInterpreter.moduleRegistry = {}  -- ordered list
function veafInterpreter.registerModule(fn)
  table.insert(veafInterpreter.moduleRegistry, fn)
end
-- dans execute() :
for _, fn in ipairs(veafInterpreter.moduleRegistry) do
  if fn(position, command, coalition, spawnedGroups, route) then return true end
end
```
Chaque module appelle `veafInterpreter.registerModule(...)` depuis son `initialize()`. L'ordre d'enregistrement reproduit l'ordre actuel.

**ARCH-002 — Registre veafRemote**
Actuellement `veafRemote.executeCommandFromRemote()` switche sur des chaînes `"air"`, `"point"`, `"atis"`, etc. Ajouter un module nécessite de modifier `veafRemote.lua`.
Proposition :
```lua
function veafRemote.registerRemoteModule(name, fn)
  veafRemote.remoteModuleRegistry[name:lower()] = fn
end
-- dans executeCommandFromRemote() :
local handler = veafRemote.remoteModuleRegistry[_module]
if handler then _status, _retval = pcall(handler, _parameters) end
```

**ARCH-003 — Helper onEventMarkChange**
Les 8 `onEventMarkChange` sont quasi-identiques :
```lua
function module.onEventMarkChange(eventPos, event)
  local invertedCoalition = event.coalition == 1 and 2 or 1
  if module.executeCommand(eventPos, event.text, invertedCoalition, event.idx) then
    trigger.action.removeMark(event.idx)
  end
end
```
Proposition dans `veafMarkers.lua` :
```lua
function veafMarkers.makeMarkHandler(executeFn)
  return function(eventPos, event)
    local inv = event.coalition == 1 and 2 or 1
    if executeFn(eventPos, event.text, inv, event.idx) then
      trigger.action.removeMark(event.idx)
    end
  end
end
```
Note : certains modules ont des variantes légères (pas d'invertedCoalition, signature différente) — à analyser module par module.

**ARCH-004 — veafSpawnParser.lua**
`veafSpawnCore.lua` contient `convertLaserToFreq` (17 lignes) et `markTextAnalysis` (612 lignes) qui n'ont aucune dépendance sur les fonctions de spawn. Les extraire dans `veafSpawnParser.lua` rend le parseur testable de manière isolée et réduit Core de ~630 lignes.
`veafSpawn.lua` (proxy) charge `veafSpawnParser.lua` avant `veafSpawnCore.lua`.

**ARCH-005 — Système de handlers dans executeCommand**
`veafSpawnCore.executeCommand` contient un if/elseif de ~400 lignes avec 20+ branches. Chaque branche appartient logiquement à un sous-module.
Proposition :
```lua
veafSpawn.commandHandlers = {}  -- { [optionKey] = fn }
function veafSpawn.registerCommandHandler(key, fn)
  veafSpawn.commandHandlers[key] = fn
end
-- dans executeCommand(), remplace le if/elseif :
for key, fn in pairs(veafSpawn.commandHandlers) do
  if options[key] then
    local g, done = fn(eventPos, options, coalition, markId, bypassSecurity)
    if g then spawnedGroup = g end
    if done then routeDone = done end
    break
  end
end
```
Chaque sous-module enregistre ses handlers à la fin de son fichier : Ground (farp/fob/group/infantry/armor/aiDefense/transport/combat/convoy), Aircraft (unit/afac/cap), Effects (cargo/logistic/destroy/teleport/bomb/smoke/flare/signal), Core (drawing/missionMaster).

</details>

---

## Lot 13 — DISCUSS: Standards industrie — à évaluer et décider

**Goal**: Évaluer les standards industrie manquants et décider lesquels adopter. Chaque ticket est un point de discussion/décision avant implémentation éventuelle.
**Branch**: `feature/disc-wave3` (PR #320 mergée)
**Statut**: ✅ Lot terminé — DISC-001/002/003/004/005/006/007/008/009/010/011/012/013/014/015/017/019 implémentés — DISC-016 rejeté (proxy silencieux dans LUAR-001) — DISC-018 rejeté (sur-ingénierie)

| # | Ticket | Type | Effort si adopté | Status |
|---|--------|------|-----------------|--------|
| DISC-008 | Release automation complète — GitHub Actions workflow sur tag push (build + publish, zéro intervention manuelle) | feat | 120 min | ✅ |
| DISC-014 | Documentation versionnée — lier les docs à une release (GitHub Pages tags ou dossiers versionnés) | feat | 90 min | ✅ |
| DISC-016 | API deprecation warnings — système de warnings Lua quand des fonctions legacy sont appelées | feat | 45 min | ❌ |
| DISC-018 | Monorepo workspace Poetry — structurer `veaf-tools` + `veaf_build` comme un vrai workspace avec dépendances explicites | chore | 60 min | ❌ |
| DISC-019 | GitHub Pages — publier la documentation (`doc/`) sur `https://veaf.github.io/VEAF-Mission-Creation-Tools-v6/` via GitHub Actions (déclenchement sur merge PR vers `develop-v6` / `main`) | feat | 60 min | ✅ |
| DISC-001 | Pre-commit hooks (`pre-commit` framework) : ruff + stylua + luacheck + detect-secrets | chore | 45 min | ✅ |
| DISC-002 | Ajouter `luacheck` au CI (lint statique Lua — undefined globals, unused vars, shadowing) | chore | 60 min | ✅ |
| DISC-003 | Coverage reporting en CI (Codecov ou Coveralls) + badge README + seuil `--cov-fail-under` | chore | 30 min | ✅ |
| DISC-004 | `CONTRIBUTING.md` + PR template + issue templates (bug report / feature request) | chore | 45 min | ✅ |
| DISC-005 | `SECURITY.md` — politique de disclosure des vulnérabilités | chore | 15 min | ✅ |
| DISC-006 | `CODEOWNERS` — auto-assign reviewers par path (`src/scripts/` → Lua team, `src/python/` → Python team) | chore | 10 min | ✅ |
| DISC-007 | Dependabot ou Renovate — auto-update des dépendances Python + GitHub Actions | chore | 20 min | ✅ |
| DISC-009 | `.editorconfig` — uniformité des settings IDE (indentation, EOL, trim trailing whitespace) | chore | 10 min | ✅ |
| DISC-010 | DevContainer / Docker — environnement dev reproductible (Python 3.13 + Lua 5.1 + outils) | feat | 90 min | ✅ |
| DISC-011 | Signed commits / tag signing — intégrité supply chain | chore | 15 min | ✅ |
| DISC-012 | Branch protection rules — require CI pass + review avant merge | chore | 10 min | ✅ |
| DISC-013 | Changelog automation (`git-cliff` ou `release-please` + conventional commits) | feat | 60 min | ✅ |
| DISC-015 | SBOM (Software Bill of Materials) — traçabilité des dépendances embarquées dans l'exe | chore | 30 min | ✅ |
| DISC-017 | Secret scanning — activer GitHub secret scanning ou intégrer `gitleaks` en CI | chore | 15 min | ✅ |

**Effort total si tout adopté: ~830 min (~13h50)**
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

**DISC-008 — Release automation** ✅
- **Décision** : Full-auto — tag push `published-v*` déclenche build + publish via GitHub Actions
- **Notes** : git-cliff génère les release notes depuis les commits conventionnels ; le dev peut enrichir/traduire sur GitHub après la release
- **Implémenté dans** : `feature/disc-008-release-automation` — `.github/workflows/release.yml`, `--ci` flag sur `veaf-build publish`

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

**DISC-012 — Branch protection rules**
- **Pour** : Empêche les push directs sur `develop-v6` et `main`, garantit que le CI passe avant tout merge. Standard pour tout projet collaboratif.
- **Contre** : Peut bloquer des hotfixes urgents si le CI est cassé pour une raison externe
- **Statut** : ✅ Implémenté — settings à appliquer dans GitHub Settings (action admin requise)

**Settings à appliquer** sur `develop-v6` et `main` :

*GitHub → Settings → Branches → Add branch protection rule*

| Setting | Valeur recommandée |
|---------|-------------------|
| Require a pull request before merging | ✅ (1 approval required) |
| Require status checks to pass | ✅ |
| — Status checks : `Lua Unit Tests` | ✅ |
| — Status checks : `StyLua Formatting` | ✅ |
| — Status checks : `python-quality` | ✅ |
| Require branches to be up to date | ✅ |
| Do not allow bypassing the above settings | ❌ (laisser l'escape hatch admin) |
| Restrict who can push to matching branches | Optionnel |

**DISC-013 — Changelog automation**
- **Pour** : Plus d'oublis, changelog toujours à jour
- **Contre** : Impose conventional commits (`feat:`, `fix:`, `chore:`) — changement d'habitude
- **Question** : L'équipe est-elle prête à adopter conventional commits ?

**DISC-014 — Documentation versionnée**
- **Pour** : Un utilisateur en v6.0.3 voit les docs correspondantes, pas les docs de develop
- **Contre** : Complexité GitHub Pages, maintenance de branches docs
- **Recommandation** : Reporter — pertinent quand il y aura des breaking changes entre versions

**DISC-015 — SBOM**
- **Pour** : Le projet distribue un `.exe` PyInstaller qui embarque des dizaines de bibliothèques tierces. Un SBOM (`cyclonedx-bom` ou `syft`) permet d'auditer les licences et de détecter des CVEs dans les dépendances embarquées. Standard dans la communauté open-source depuis le décret US 2021.
- **Contre** : Peu d'utilisateurs VEAF ne vont pas auditer le SBOM. Overhead de génération et de publication.
- **Recommandation** : Générer le SBOM en artifact CI sans le publier obligatoirement — coût quasi-nul, utilisable si besoin.

**DISC-016 — Deprecation warnings Lua** ❌ Rejeté (2026-05-21)
- **Décision** : Rejeté. LUAR-001 utilise un proxy **silencieux et transparent** — `veafSpawn.lua` ré-exporte les fonctions publiques sans warning. Les missions existantes continuent de fonctionner indéfiniment sans modification, et sans bruit dans les logs DCS. Les deprecation warnings ajouteraient de l'overhead (un wrapper par fonction) pour un bénéfice nul : l'API publique de `veafSpawn` ne sera pas supprimée.

**DISC-017 — Secret scanning**
- **Pour** : Détecte les API keys, tokens, mots de passe accidentellement commités. GitHub secret scanning est gratuit sur les repos publics et couvre des centaines de patterns (AWS, GCP, GitHub tokens, etc.). `gitleaks` en CI ajoute une couche pour les secrets maison.
- **Contre** : Faux positifs possibles (ex : clés DCS dans les fichiers de mission). Configuration du `.gitleaksignore` nécessaire.
- **Recommandation** : Activer GitHub secret scanning (zéro coût, zéro configuration). `gitleaks` en CI est optionnel — à voir si les faux positifs sont gérables.

**DISC-018 — Monorepo workspace Poetry** ❌ Rejeté (2026-05-21)
- **Décision** : Rejeté. La situation actuelle (un seul `pyproject.toml`, `veaf_build` embarqué via `packages`) fonctionne correctement. Poetry workspace 2.x est une fonctionnalité récente dont la maturité sur Windows reste à confirmer, le refactoring des imports serait non trivial, et le gain est marginal pour un projet sans équipes séparées sur les deux packages. Pas assez intéressant pour le coût.

**DISC-019 — GitHub Pages**
- **Situation actuelle** : La documentation (`doc/`) existe uniquement dans le repo Git — pas de site web navigable, pas d'URL publique stable.
- **Ce que proposerait DISC-019** : Publier automatiquement `doc/` sur GitHub Pages (`https://veaf.github.io/VEAF-Mission-Creation-Tools/`) via un workflow GitHub Actions déclenché sur push `develop-v6` et sur chaque tag. Utiliser [MkDocs](https://www.mkdocs.org/) (Material theme) ou simplement servir les Markdown via GitHub Pages natif. Lien DISC-014 (docs versionnées) — DISC-019 est le prérequis.
- **Pour** : URL stable et partageable pour les utilisateurs, navigabilité entre les pages, moteur de recherche intégré (MkDocs Material), nul coût d'hébergement.
- **Contre** : Nécessite de choisir et configurer un générateur de site statique. MkDocs ajoute une dépendance Python (groupe `docs`).
- **Recommandation** : Adopter — c'est la norme pour les projets open-source. MkDocs Material est le choix le plus rapide à mettre en place.

</details>

---

## Lot RC — v6.1.0 RC bug fixes

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

---

## Lot 6 — BONUS: Logger filter + DCSUnits doc

**Goal**: Quality-of-life improvements after the priority lots.
**Branch**: `feature/bonus-logger-doc` → PR → `develop-v6`
**Depends on**: Lot 4 (LUA-001), Lot 2 (TOOL-003)

| # | Ticket | Type | Effort | Depends on | Status |
|---|--------|------|--------|------------|--------|
| LUA-006 | `--log-modules` option in `veaf-tools` to filter which modules log | feat | 90 min | LUA-001 | ✅ |
| TOOL-004 | Parse `dcsUnits.lua` → dynamic markdown doc generated before publish | feat | 90 min | TOOL-003 | ✅ |
| LUA-007 | Lazy log args (`veaf.lp`), single build, runtime log control (`global_log_level`) | feat | 120 min | LUA-006 | ✅ |

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

## Lot 10 — YAML-CONFIG: mission.yaml source de vérité

**Goal**: `mission.yaml` becomes the single source of truth for all mission configuration. Python generates `veaf-config.lua` at build time. `missionConfig.lua` → `mission-script.lua` (custom code only). `convert-v5` actively extracts all recognized patterns.
**Branch**: `feature/yaml-config` → PR → `develop-v6`
**Depends on**: Lot RC (builder infrastructure), Lot 4 (LUA-CONFIG)

| # | Ticket | Type | Effort | Depends on | Status |
|---|--------|------|--------|------------|--------|
| YAML-001 | Rename `veaf-modules-config.lua` → `veaf-config.lua` and `missionConfig.lua` → `mission-script.lua` everywhere (no compat fallback) | chore | 40 min | — | ✅ |
| YAML-002 | Core YAML schema + generator: `mission:`, `security:`, `settings:`, auto-`initialize()` with typed `init:` params per module | feat | 60 min | YAML-001 | ✅ |
| YAML-003 | YAML schema + generator: `lua_modules.ASSETS.assets:` table + `lua_modules.NAMED_POINTS.custom_points:` | feat | 45 min | YAML-002 | ✅ |
| YAML-004 | YAML schema + generator: `external_modules.skynet:` + `external_modules.ctld:` | feat | 35 min | YAML-002 | ✅ |
| YAML-005 | YAML schema + generator: `qra:` list → `VeafQRA:new():set*():start()` builder chains | feat | 60 min | YAML-002 | ✅ |
| YAML-006 | YAML schema + generator: `cap_missions:` + `combat_missions:` → `addCapMission()` + `VeafCombatMission` builder chains | feat | 90 min | YAML-002 | ✅ |
| YAML-007 | Update `generate-config` command: produce exhaustive commented `mission.yaml` with all known options and defaults | feat | 45 min | YAML-002–006 | ✅ |
| YAML-008 | Update default templates: `mission.yaml` (all new sections commented), `mission-script.lua` (custom-only stub), `test-tools-v6` fixtures | chore | 30 min | YAML-002–006 | ✅ |
| YAML-009 | `convert-v5` — extract core config + Skynet: `MISSION_NAME`, `era`, `SecurityDisabled`, simple `initialize()` params, Skynet params | feat | 60 min | YAML-002, YAML-004 | ✅ |
| YAML-010 | `convert-v5` — extract `veafAssets.Assets = {...}` Lua table → `lua_modules.ASSETS.assets:` YAML | feat | 45 min | YAML-003 | ✅ |
| YAML-011 | `convert-v5` — extract `VeafQRA:new():...:start()` chains → `qra:` YAML entries | feat | 60 min | YAML-005 | ✅ |
| YAML-012 | `convert-v5` — extract `addCapMission()` + `VeafCombatMission:new():...` chains → `cap_missions:` / `combat_missions:` YAML | feat | 75 min | YAML-006 | ✅ |
| YAML-013 | Tests: `test_config_generator.py` (mission, security, auto-init, QRA, CombatMission, Assets) + `test_config_migrator.py` updates (new extraction patterns) | chore | 60 min | YAML-001–012 | ✅ |
| YAML-014 | Docs: update `MISSION_MAKER_GUIDE.md`, `MIGRATION_GUIDE.md` for new YAML → `veaf-config.lua` + `mission-script.lua` workflow | chore | 30 min | YAML-001–012 | ✅ |

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

## Lot 15 — DOC: Restructuration et mise à jour de la documentation

**Goal**: Éliminer les redondances, améliorer la navigation, créer des landing pages par audience, mettre à jour le contenu.
**Branch**: `doc/restructure-navigation` → PR → `develop-v6`

| # | Ticket | Type | Effort | Depends on | Status |
|---|--------|------|--------|------------|--------|
| DOC-001 | Nouvelle nav mkdocs (retirer USER_GUIDE, déplacer Testing sous Developer) | chore | 10 min | — | ✅ |
| DOC-002 | Réécrire Home (`doc/README.md` + `.fr.md`) — accroche, Getting Started global, quick links | feat | 30 min | DOC-001 | ✅ |
| DOC-003 | Enrichir `pilot/README.md` + `.fr.md` — landing page + Quick Start pilote | feat | 25 min | DOC-001 | ✅ |
| DOC-004 | Enrichir `mission-maker/README.md` + `.fr.md` — landing page + Quick Start mission-maker | feat | 30 min | DOC-001 | ✅ |
| DOC-005 | Enrichir `developer/README.md` + `.fr.md` — landing page + Quick Start dev | feat | 25 min | DOC-001 | ✅ |
| DOC-006 | Réécrire `mission-maker/scripts/README.md` + `.fr.md` — hub multi-index (workflow / interaction / fréquence) | feat | 40 min | DOC-004 | ✅ |
| DOC-007 | Mettre à jour versions (6.0.5 → 6.1.0) dans tous les fichiers doc | chore | 15 min | — | ✅ |
| DOC-008 | Redistribuer contenu unique de USER_GUIDE.md dans pilot/GUIDE.md | feat | 30 min | DOC-003 | ✅ |
| DOC-009 | Supprimer USER_GUIDE.md | chore | 5 min | DOC-008 | ✅ |
| DOC-010 | Fixer liens morts vers USER_GUIDE.md | fix | 20 min | DOC-009 | ✅ |

**Raw total: 230 min → estimated (×1.15): ~265 min (~4h25)**

<details>
<summary>Decisions log</summary>

- **USER_GUIDE.md** : retirer de la nav (DOC-001), redistribuer contenu utile dans pilot/GUIDE.md (DOC-008), puis supprimer (DOC-009)
- **Getting Started** : global sur Home + Quick Start intégré dans chaque Overview par rôle
- **Pages Overview** : enrichir comme landing pages (pas les supprimer)
- **Scripts** : 3 index sur la page Overview scripts (par workflow, par interaction joueur, par fréquence d'usage) — la nav latérale garde la liste plate pour accès direct
- **Traductions FR** : maintenues en parallèle
- **Testing** : déplacé sous la section Developer
- **Ton** : technique et factuel

</details>

<details>
<summary>Target nav structure</summary>

```yaml
nav:
  - Home: README.md
  - Pilot Guide:
    - Overview: pilot/README.md
    - Full Guide: pilot/GUIDE.md
  - Mission Maker:
    - Overview: mission-maker/README.md
    - Guide: mission-maker/GUIDE.md
    - Migration Guide: mission-maker/MIGRATION_GUIDE.md
    - Scripts:
      - Overview: mission-maker/scripts/README.md
      - veafAirWaves: mission-maker/scripts/veafAirWaves.md
      - veafAirbases: mission-maker/scripts/veafAirbases.md
      - veafAssets: mission-maker/scripts/veafAssets.md
      - veafCarrierOperations: mission-maker/scripts/veafCarrierOperations.md
      - veafCasMission: mission-maker/scripts/veafCasMission.md
      - veafCombatZone: mission-maker/scripts/veafCombatZone.md
      - veafGrass: mission-maker/scripts/veafGrass.md
      - veafMissileGuardian: mission-maker/scripts/veafMissileGuardian.md
      - veafMove: mission-maker/scripts/veafMove.md
      - veafNamedPoints: mission-maker/scripts/veafNamedPoints.md
      - veafQraManager: mission-maker/scripts/veafQraManager.md
      - veafSanctuary: mission-maker/scripts/veafSanctuary.md
      - veafSecurity: mission-maker/scripts/veafSecurity.md
      - veafSkynetIadsHelper: mission-maker/scripts/veafSkynetIadsHelper.md
      - veafSpawn: mission-maker/scripts/veafSpawn.md
      - veafTransportMission: mission-maker/scripts/veafTransportMission.md
      - veafWeather: mission-maker/scripts/veafWeather.md
  - Developer:
    - Overview: developer/README.md
    - Guide: developer/GUIDE.md
    - Testing: TESTING.md
  - References:
    - Lua API Reference: LUA_API_REFERENCE.md
    - Tools CLI Reference: TOOLS_REFERENCE.md
    - Roadmap: ROADMAP.md
```

</details>

---

## Lot 11 — I18N: Internationalisation (EN + FR)

**Goal**: Auto-detect the user's language (OS locale or `--lang` flag) and deliver the full experience in that language: CLI output, generated file comments, and documentation. Ship EN and FR as first-class citizens.
**Branch**: `feature/i18n` → PR → `develop-v6`
**Depends on**: Lot 10 (generated-file comment strings stabilised)

| # | Ticket | Type | Effort | Depends on | Status |
|---|--------|------|--------|------------|--------|
| I18N-001 | i18n infrastructure: OS locale auto-detection + `--lang` CLI override, translation catalog loader (`veaf_libs/i18n.py`), `t()` helper | feat | 60 min | — | ✅ |
| I18N-002 | Translate all user-visible CLI messages (typer help strings, Rich output, logger messages) — EN catalog first, FR translation | feat | 120 min | I18N-001 | ✅ |
| I18N-003 | Translate comments in generated files (`veaf-config.lua`, `mission.yaml` template, `mission-script.lua` stub, `generate-config` output) | feat | 60 min | I18N-001, Lot 10 | ✅ |
| I18N-004 | Translate `MISSION_MAKER_GUIDE.md` → `doc/fr/MISSION_MAKER_GUIDE.md` (FR version maintained alongside EN) | chore | 90 min | — | ✅ |
| I18N-005 | `convert-v5` report output in detected language (scan table headers, action descriptions, warning messages) | feat | 45 min | I18N-002 | ✅ |
| I18N-006 | `mission.yaml` `language:` field → emit `veaf.config.language` in Lua; translate `generate-config` YAML template comments | feat | 45 min | I18N-001, I18N-003 | ✅ |
| I18N-007 | Full bilingual doc structure: FR translations of all doc guides (`pilot/fr/GUIDE.md`, `developer/fr/GUIDE.md`, `mission-maker/fr/scripts/*.md`), bilingual README headers, `--lang --help` pre-parse fix | chore | 120 min | I18N-004 | ✅ |

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
| QUAL-001 | Supprimer `package.json` — version unique via `pyproject.toml` + `importlib.metadata` | `package.json`, `veaf-tools.py`, `veaf-tools-updater.py`, `veaf_build/cli.py` | chore | 45 min | ✅ |
| QUAL-002 | Supprimer les `VERSION` hardcodées dans `veaf-tools.py` et `veaf-tools-updater.py` — utiliser `importlib.metadata.version("veaf-tools")` | `veaf-tools.py`, `veaf-tools-updater.py` | fix | 20 min | ✅ |
| QUAL-003 | Factoriser `resolve_path()` dans `veaf_libs/paths.py` (utilisé par tools + updater) | `veaf_libs/`, `veaf-tools.py`, `veaf-tools-updater.py` | chore | 30 min | ✅ |
| QUAL-004 | Factoriser `resolve_mission_file()` helper (pattern glob dupliqué 6+ fois) | `veaf-tools.py`, `veaf_libs/` | chore | 30 min | ✅ |
| QUAL-005 | Fix `miz_tools.py:195` — ne pas `os.replace` après exception dans le try/except | `mission_tools/miz_tools.py` | fix | 15 min | ✅ |
| QUAL-006 | Fix `progress.py:19` — bug de précédence d'opérateur (parenthèses manquantes) | `veaf_libs/progress.py` | fix | 10 min | ✅ |
| QUAL-007 | Supprimer fichier fantôme `veaf_libs/__init__,py` (virgule dans le nom) | `veaf_libs/` | fix | 5 min | ✅ |
| QUAL-008 | Fix typo `WheatherInjectorREADME` → `WeatherInjectorREADME` | `weather_injector/__init__.py`, `veaf-tools.py` | fix | 5 min | ✅ |
| QUAL-009 | Vérifier et supprimer la dépendance `Pillow` si inutilisée | `pyproject.toml` | chore | 15 min | ✅ |
| QUAL-010 | Ajouter bornes supérieures sur les dépendances critiques (PyInstaller compat) | `pyproject.toml` | chore | 20 min | ✅ |
| QUAL-011 | Découper `veaf-tools.py` (1541 lignes) en package `commands/` | `veaf-tools.py` → `veaf_tools/commands/*.py` | chore | 120 min | ✅ |
| QUAL-012 | Créer `BaseWorker` ABC pour formaliser le pattern worker | `veaf_libs/base_worker.py` + workers | chore | 45 min | ✅ |
| QUAL-013 | Remédiation mypy : retirer `ignore_errors` pour 5 premiers modules (veaf_libs.logger, mission_tools.mission_constants, mission_tools.miz_tools, veaf_libs.progress, presets_injector.presets_manager) | `pyproject.toml` + modules concernés | fix | 90 min | ✅ |
| QUAL-014 | Lua: normaliser format `Id` (supprimer trailing `" - "`) dans tous les modules | `veafGroundAI.lua`, `veafAirWaves.lua`, `veafEventHandler.lua`, etc. | chore | 20 min | ✅ |
| QUAL-015 | Lua: remettre `LogLevel` à `nil` dans `veafSpawn.lua` et `veafMarkers.lua` (actuellement "trace" en production) | `veafSpawn.lua`, `veafMarkers.lua` | fix | 5 min | ✅ |
| QUAL-016 | Lua: ajouter `pcall` wrapping aux entry points critiques (scheduled callbacks, event handlers) | `veaf.lua`, `veafQraManager.lua`, `veafAirWaves.lua`, `veafGroundAI.lua` | fix | 45 min | ✅ |
| QUAL-017 | Lua: factoriser `statusToString()` dupliqué en helper `veaf.enumToString(value, mapping)` | `veaf.lua`, `veafQraManager.lua`, `veafAirWaves.lua`, `veafGroundAI.lua` | chore | 20 min | ✅ |
| QUAL-018 | Lua: remplacer `getRandomizableNumeric_norandom()` hardcodé par calcul algorithmique de la médiane | `veaf.lua` | fix | 30 min | ✅ |
| QUAL-019 | Lua: nettoyer dead code (blocs commentés GoToWaypoint, StaticObject.getByName, etc.) | multiples fichiers | chore | 20 min | ✅ |
| QUAL-020 | Lua: corriger variable shadowing (`local coalition = coalition` dans `veaf.lua:2571`) | `veaf.lua`, `veafSpawn.lua` | fix | 15 min | ✅ |
| QUAL-021 | Python + Lua: ajouter tests unitaires pour `miz_tools.py` (read/write .miz) | `test/veaf-tools/` + nouveau test file | feat | 60 min | ✅ |
| QUAL-022 | Lua: enrichir `dcs_mocks.lua` — supporter `Unit.getByName`/`Group.getByName` configurables pour débloquer les tests logiques | `test/lua/dcs_mocks.lua` | feat | 45 min | ✅ |
| QUAL-023 | Lua: ajouter tests state-machine pour `VeafQRA` lifecycle (spawn/despawn/rearm cycle) | `test/lua/test_veafQraManager.lua` | feat | 60 min | ✅ |
| QUAL-024 | Documentation: supprimer ou archiver `todo.md` | `todo.md` | chore | 5 min | ✅ |
| QUAL-025 | Documentation: résoudre date `[6.0.2] — 2025-11-??` dans `CHANGELOG.md` | `CHANGELOG.md` | fix | 5 min | ✅ |
| QUAL-026 | Documentation: vérifier/corriger lien vers `RELEASE_NOTES.md` dans `README.md` | `README.md` | fix | 10 min | ✅ |
| QUAL-027 | Documentation: vérifier et corriger les liens `fr/scripts/` dans `doc/mission-maker/` | `doc/mission-maker/` | fix | 15 min | ✅ |

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

## Lot 18 — VERSIONING: Single source of truth pour la version ✅

**Goal**: Centraliser la version dans `pyproject.toml` et la propager automatiquement partout.

| # | Ticket | Fichiers touchés | Type | Effort | Status |
|---|--------|-----------------|------|--------|--------|
| VER-001 | Supprimer les fallbacks version hardcodés ; générer `_version.py` depuis `veaf_build/worker.py` | `veaf_tools/app.py`, `veaf-tools-updater.py`, `veaf_build/worker.py` | chore | 30 min | ✅ |
| VER-002 | Métadonnées Windows EXE (FILE_VERSION/PRODUCT_VERSION) via PyInstaller `version_file.txt` | `veaf-tools.spec`, `veaf-tools-updater.spec`, `veaf_build/worker.py` | chore | 45 min | ✅ |
| VER-003 | Afficher la version dans `about` (`veaf-tools vX.Y.Z`) | `veaf_tools/commands/about.py`, `locales/en.json`, `locales/fr.json` | feat | 15 min | ✅ |

**Raw total: 90 min → ~105 min (~1h45)**

---

## Lot 19 — MIGRATOR: Audit et complétion de la conversion missionConfig.lua ✅

**Goal**: Vérifier que `ConfigMigrator` gère correctement toutes les constructions Lua réelles d'un `missionConfig.lua` v5 ; combler les lacunes de tests ; corriger les régressions.

| # | Ticket | Fichiers touchés | Type | Effort | Status |
|---|--------|-----------------|------|--------|--------|
| MIG-001 | Test d'intégration end-to-end sur fixtures réelles | `test_config_migrator.py` | chore | 30 min | ✅ |
| MIG-002 | Tests unitaires pour les 8 extracteurs non couverts | `test_config_migrator.py` | chore | 60 min | ✅ |
| MIG-003 | Corrections bugs trouvés lors de MIG-001/MIG-002 | `mission_builder/config_migrator.py` | fix | 60 min | ✅ |

**Raw total: 150 min → ~175 min (~2h30)**

---

## Lot 20 — DEEPENING: Architecture deepening Python + Lua ✅

**Goal**: `Group` dataclass + `iter_groups()`, `DcsMission` weather/options accessors, suppression du traversal dupliqué dans les injectors, base class `GroupInjectorWorker`, migration `veafGroundAI` → `veafCommands`, restructuration options spawn, config resolution dans `MissionBuilderWorker`.

| # | Ticket | File(s) | Type | Effort | Status |
|---|--------|---------|------|--------|--------|
| DEEP-001 | `Group` dataclass + `DcsMission.iter_groups()` + tests | `miz_tools.py`, `__init__.py`, `test_miz_tools.py` | feat | 60 min | ✅ |
| DEEP-002 | `DcsMission.get/set_weather()` + `get/set_options()` | `miz_tools.py`, `weather_injector_worker.py` | feat | 30 min | ✅ |
| DEEP-003 | Supprimer traversal dupliqué des 3 injectors | `presets_injector_worker.py`, `waypoints_injector_worker.py` | chore | 60 min | ✅ |
| DEEP-004 | `GroupInjectorWorker` base class | `veaf_libs/group_injector_worker.py`, injectors | feat | 60 min | ✅ |
| DEEP-005 | `veafGroundAI` → `veafCommands.registerCommandHandler` | `veafGroundAI.lua`, `veafCommands.lua` | chore | 30 min | ✅ |
| DEEP-006 | Restructuration table options spawn `markTextAnalysis()` | `veafSpawnParser.lua` | chore | 60 min | ✅ |
| DEEP-007 | Config resolution dans `MissionBuilderWorker.__init__()` | `mission_builder_worker.py`, `build.py` | chore | 60 min | ✅ |

**Raw total: 360 min → ~414 min (~7h)**

---

## Lot 21 — TYPING: Migrate `Optional[T]` to `X | Y` syntax ✅

**Goal**: Enable ruff `UP007` + migrate `Optional[str]` → `str | None`.

| # | Ticket | File(s) | Type | Effort | Status |
|---|--------|---------|------|--------|--------|
| TYP-001 | Remove UP007 from ruff ignore + fix `lua_tests.py` + update copilot-instructions | `pyproject.toml`, `lua_tests.py`, `.github/copilot-instructions.md` | chore | 15 min | ✅ |

---

## Lot 22 — TEST-LAYOUT: Move Python tests to `test/python/` ✅

**Goal**: Déplacer les 28 `test_*.py` de `src/python/veaf-tools/` vers `test/python/`.

| # | Ticket | File(s) | Type | Effort | Status |
|---|--------|---------|------|--------|--------|
| TST-001 | Déplacer 28 fichiers + update `pyproject.toml` | `test/python/**`, `pyproject.toml` | chore | 45 min | ✅ |

---

## Lot 23 — DOC-YAML: Référence YAML complète ✅

**Goal**: Documenter exhaustivement toute la configuration YAML (pipeline + modules Lua) avec double index.

| # | Ticket | Type | Effort | Status |
|---|--------|------|--------|--------|
| DOC-001 | `PIPELINE_REFERENCE.md` + `.fr.md` | doc | 60 min | ✅ |
| DOC-002 | `MISSION_YAML_REFERENCE.md` + `.fr.md` (squelette) | doc | 45 min | ✅ |
| DOC-003 | YAML sections dans docs modules simples (RADIO, SHORTCUTS, NAMEDPOINTS, CARRIER) | doc | 60 min | ✅ |
| DOC-004 | YAML sections dans ASSETS + SANCTUARY | doc | 45 min | ✅ |
| DOC-005 | YAML sections dans COMBATZONE + AIRWAVES | doc | 90 min | ✅ |
| DOC-006 | YAML sections dans QRA + CASMISSION | doc | 60 min | ✅ |
| DOC-007 | Double index final `MISSION_YAML_REFERENCE.md` | doc | 30 min | ✅ |
| DOC-008 | Audit global missionConfig.lua dans tous les `.md` | doc | 45 min | ✅ |

**Raw total: 435 min → ~500 min (~8h20)**

---

## Lot 24 — DOC-REVIEW: Corrections issues du doc-review ✅ (REV-002 différé)

**Goal**: Corriger les inexactitudes et lacunes identifiées lors de la revue manuelle de la doc v6.

| # | Ticket | Type | Effort | Status |
|---|--------|------|--------|--------|
| REV-001 | Remplacer `missions.yaml` → `versions.yaml` partout dans la doc | fix | 20 min | ✅ |
| REV-002 | Committer profil Klogg → `tools/klogg/veaf.conf` | chore | 20 min | ⬜ (différé) |
| REV-004 | Corriger `MIGRATION_GUIDE.md` — Common Issues + logs | fix | 20 min | ✅ |
| REV-006 | Corriger `GUIDE.md` — Typical Build Workflow (pipeline intégré) | fix | 20 min | ✅ |
| REV-007 | Corriger `doc/index.md` — phrase d'accroche + diagramme TD | fix | 15 min | ✅ |
| REV-008 | Prérequis DCS Editor dans `GUIDE.md` (groupe bleu + rouge requis) | fix | 20 min | ✅ |
| REV-010 | CTLD/CSAR Integration — corriger la section dans `GUIDE.md` | fix | 30 min | ✅ |

**Raw total: 145 min → ~167 min (~2h45)**

---

## Lot 25 — EXT-YAML: Support YAML pour les modules externes (CTLD/CSAR) ✅

**Goal**: Support `external_modules.csar` dans `lua_config_generator.py` + étendre CTLD + tests + doc.

| # | Ticket | Type | Effort | Status |
|---|--------|------|--------|--------|
| EXT-001 | Support `external_modules.csar` | feat | 30 min | ✅ |
| EXT-002 | Générer `ctld.initialize()` depuis YAML | feat | 20 min | ✅ |
| EXT-003 | Tests unitaires CTLD/CSAR | test | 40 min | ✅ |
| EXT-004 | Update `GUIDE.md` CTLD/CSAR section | doc | 30 min | ✅ |

**Raw total: 120 min → ~140 min (~2h)**

---

## Lot FIX-SORT — LUADATA FIX: Crash tri clés mixtes int/str ✅

**Goal**: Corriger le `TypeError: '<' not supported between instances of 'int' and 'str'` dans `luadata/serializer/serialize.py`.

| # | Ticket | Type | Effort | Status |
|---|--------|------|--------|--------|
| SORT-001 | Convertir la clé en `str` dans `sort_key` de `_sort()` | fix | 5 min | ✅ |
| SORT-002 | Test unitaire : `_sort` avec clés mixtes ne plante pas | test | 10 min | ✅ |

---

## Lot 26 — IMC-FEEDBACK: Retours utilisateur tests IMC-Day (v6.2.0) ✅

**Goal**: Traiter les retours terrain remontés lors des tests de migration IMC-Day du 31/05/2026.

| # | Ticket | Type | Effort | Status |
|---|--------|------|--------|--------|
| IMC-001 | Auto-pause smart (double-clic vs CLI) | fix | 25 min | ✅ |
| IMC-002 | backup_v5 trompeur — rapport + README.txt | fix | 30 min | ✅ |
| IMC-003 | Supprimer README des defaults copiés | fix | 10 min | ✅ |
| IMC-007 | Doc architecture YAML dans `MISSION_YAML_REFERENCE.md` | doc | 30 min | ✅ |
| IMC-008 | Filtrage smart des defaults + warnings orphelins | fix | 35 min | ✅ |
| IMC-010 | Investigate + validation version veafCommands | fix | 45 min | ✅ |

**Raw total: 175 min → ~200 min (~3h20)**

---

## Lot FIX-BUNDLE — VEAFCOMMANDS MISSING ✅

**Goal**: Corriger le crash `attempt to index global 'veafCommands' (a nil value)` — `veafCommands.lua` était absent du bundle.

| # | Ticket | Type | Effort | Status |
|---|--------|------|--------|--------|
| BUNDLE-001 | Ajouter `"veafCommands.lua"` dans `lua_scripts` après `"veafMarkers.lua"` | fix | 5 min | ✅ |

---

## Lot FIX-ASSETS-NEWLINE — ASSETS newline in Lua string ✅

**Goal**: Corriger l'erreur Lua quand `description`/`information` contient `\n` → utiliser `[[...]]`.

| # | Ticket | Type | Effort | Status |
|---|--------|------|--------|--------|
| ASSETS-001 | Ajouter `_emit_lua_string()` dans `lua_config_generator.py` | fix | 10 min | ✅ |
| ASSETS-002 | Test unitaire | chore | 10 min | ✅ |

---

## Lot FIX-WEATHER-ALIAS — missions.yaml + versions.yaml coexistence ✅

**Goal**: Éviter la coexistence de `missions.yaml` et `versions.yaml` dans un dossier mission converti.

| # | Ticket | Type | Effort | Status |
|---|--------|------|--------|--------|
| WEATHER-001 | Skip copy `versions.yaml` si `missions.yaml` présent + warning | fix | 10 min | ✅ |
| WEATHER-002 | Ajouter `missions.yaml` à `_DEFAULT_FILE_MODULE_MAP` | fix | 5 min | ✅ |
| WEATHER-003 | Test unitaire | chore | 10 min | ✅ |

---

## Lot FIX-MISSIONCONFIG-BAK — supprimer extension .bak inutile ✅

**Goal**: Supprimer l'extension `.lua.bak` du fichier backup dans `backup_v5/`.

| # | Ticket | Type | Effort | Status |
|---|--------|------|--------|--------|
| BAK-001 | `bak_path = backup_dir / src.name` | fix | 5 min | ✅ |
| BAK-002 | Update i18n strings | fix | 5 min | ✅ |
| BAK-003 | Update `README.txt` généré | fix | 5 min | ✅ |
| BAK-004 | Test unitaire | chore | 5 min | ✅ |

---

## Lot FIX-README-COPY — Stop copying presets.md into src/ ✅

**Goal**: Supprimer la copie silencieuse de `presets.md` dans le dossier `src/` des missions au build.

| # | Ticket | Type | Effort | Status |
|---|--------|------|--------|--------|
| README-001 | Supprimer `src/defaults/mission-folder/src/presets.md` | fix | 2 min | ✅ |
| README-002 | Retirer `"presets.md"` de `_DEFAULT_FILE_MODULE_MAP` | fix | 3 min | ✅ |
| README-003 | Audit defaults — vérifier aucun fichier doc-only résiduel | chore | 5 min | ✅ |

---

## Lot FIX-AIRCRAFT-ORPHAN — alerte fichier orphelin aircraft-templates.yaml ✅

**Goal**: Émettre un warning si `src/aircraft-templates.yaml` est présent mais le step `aircraft_groups` est désactivé.

| # | Ticket | Type | Effort | Status |
|---|--------|------|--------|--------|
| AORPHAN-001 | Warning dans `build.py` après step skipped | fix | 10 min | ✅ |
| AORPHAN-002 | Test unitaire | chore | 10 min | ✅ |

---

## Lot DOC-DEV-MODE — documenter dev_mode + scripts_path ✅

**Goal**: Documenter `dev_mode` / `scripts_path` pour les contributeurs VEAF développant localement.

| # | Ticket | Type | Effort | Status |
|---|--------|------|--------|--------|
| DEVMODE-001 | Section "Developer Mode" dans `doc/developer/GUIDE.md` + `.fr.md` | doc | 20 min | ✅ |
| DEVMODE-002 | Documenter `build.dev_mode` et `build.scripts_path` dans `MISSION_YAML_REFERENCE.md` + `.fr.md` | doc | 10 min | ✅ |

---

## Lot FEAT-PROFILES — profils de build dans mission.yaml ✅

**Goal**: Permettre des profils nommés dans `mission.yaml` (`TEST`, `SERVER`) applicables via `veaf-tools build --profile TEST`.

| # | Ticket | Type | Effort | Status |
|---|--------|------|--------|--------|
| PROF-001 | `resolve_profile()` + deep merge dans `veaf_libs/build_profiles.py` | feat | 45 min | ✅ |
| PROF-002 | Option `--profile` / `-p` sur `veaf-tools build` | feat | 30 min | ✅ |
| PROF-003 | Log du profil actif au build | feat | 10 min | ✅ |
| PROF-004 | Exemple `profiles:` commenté dans `src/defaults/mission-folder/mission.yaml` | doc | 15 min | ✅ |
| PROF-005 | Tests unitaires | chore | 30 min | ✅ |
| PROF-006 | Doc "Build Profiles" dans `MISSION_YAML_REFERENCE.md` + `GUIDE.md` | doc | 30 min | ✅ |

**Raw total: 160 min → ~185 min (~3h)**

---

## Lot FEAT-MODULE-UX — Catégories, modules obligatoires, dépendances ✅

**Goal**: Améliorer la section `lua_modules:` : catégories cosmétiques, warning modules obligatoires, résolution automatique des dépendances.

| # | Ticket | Type | Effort | Status |
|---|--------|------|--------|--------|
| MODUX-001 | `_MODULE_CATEGORIES` dict + headers dans YAML template et Lua output | feat | 20 min | ✅ |
| MODUX-002 | `_MANDATORY_MODULES` frozenset + warning si `enable: false` | feat | 10 min | ✅ |
| MODUX-003 | `_MODULE_DEPS` dict + `_resolve_deps()` — auto-enable en mémoire | feat | 30 min | ✅ |
| MODUX-004 | Update `src/defaults/mission-folder/mission.yaml` — ordre catégories + annotations | doc | 15 min | ✅ |
| MODUX-005 | Tests unitaires (catégories, mandatory warning, deps, transitive chain) | chore | 30 min | ✅ |

**Raw total: 105 min → ~120 min (~2h)**

---

## Lot FEAT-GITIGNORE — Template `.gitignore` VEAF MCT dans les defaults ✅

**Goal**: Ajouter un `.gitignore` standard dans `src/defaults/mission-folder/`, jamais écrasé même avec `--force`.

| # | Ticket | Type | Effort | Status |
|---|--------|------|--------|--------|
| GITIGNORE-001 | Créer `src/defaults/mission-folder/.gitignore` | feat | 5 min | ✅ |
| GITIGNORE-002 | `NEVER_OVERWRITE = frozenset({".gitignore"})` dans `prepare.py` | feat | 15 min | ✅ |
| GITIGNORE-003 | Test unitaire : `--force` ne surécrit pas `.gitignore` | chore | 5 min | ✅ |

**Raw total: 25 min → ~30 min**

---

Lots completed and archived on **2026-06-08**.

---

## Lot FIX-OLDSCRIPTS — detect residual .lua files in src/scripts/

**Goal**: Detect residual v5 `.lua` files in `src/scripts/` of a converted mission and emit a warning at build time.

**Context**: The original bug (`veafCommands nil`) was resolved by Lot FIX-BUNDLE. Potential secondary cause not addressed: individual v5 VEAF `.lua` files still present in `src/scripts/` could be loaded via the `src/scripts/*.lua` glob and create DCS runtime conflicts. OLDSCRIPTS-002 can be implemented independently of the investigation.

**Branch**: `fix/oldscripts-detection` → PR → `develop-v6`

| # | Ticket | Files | Type | Effort | Status |
|---|--------|-------|------|--------|--------|
| OLDSCRIPTS-000 | Investigation: reproduce the bug with a real v5→v6 mission; obtain full DCS logs; identify the responsible file | — | chore | 15 min | ✅ (resolved — see context) |
| OLDSCRIPTS-001 | Fix: based on investigation result, fix the identified root cause | TBD | fix | TBD | ✅ (resolved by FIX-BUNDLE) |
| OLDSCRIPTS-002 | Add a warning if unexpected `.lua` files are present in `src/scripts/` (i.e. not explicitly listed in `get_mission_script_files()`) | `mission_tools/mission_constants.py` or `mission_builder_worker.py` | fix | 15 min | ✅ |

---

## Lot FIX-MARKERS-INIT — add missing `veafMarkers.initialize()`

**Goal**: Fix DCS runtime error `attempt to call field 'initialize' (a nil value)` on `veafMarkers`.

**Context**: The `initialize()` function was missing from `veafMarkers.lua` even though `veaf-config.lua` always calls it. The module was already self-initializing on load; the added function simply logs.

**Branch**: direct commit without branch (minimal fix, tested by user)

| # | Ticket | Files | Type | Effort | Status |
|---|--------|-------|------|--------|--------|
| MARKERS-INIT-001 | Add `veafMarkers.initialize()` to `src/scripts/veaf/veafMarkers.lua` | `src/scripts/veaf/veafMarkers.lua` | fix | 5 min | ✅ |

---

## Lot FIX-MISSING-INIT — missing `initialize()` on 4 Lua modules

**Goal**: Fix DCS runtime crashes `attempt to call field 'initialize' (a nil value)` on modules not yet covered.

**Context**: The Python build (`lua_config_generator.py`) generates an `<module>.initialize()` call for all modules listed in `_MODULE_INIT_ORDER`. A full audit revealed 4 modules missing this function: `veafCacheManager`, `veafTime`, `veafUnits`, `veafSkynetIadsMonitor`.

**Branch**: `fix/missing-initialize-fns` → PR → `develop-v6`

| # | Ticket | Files | Type | Effort | Status |
|---|--------|-------|------|--------|--------|
| MISSING-INIT-001 | Add `initialize()` to `veafCacheManager.lua` | `src/scripts/veaf/veafCacheManager.lua` | fix | 5 min | ✅ |
| MISSING-INIT-002 | Add `initialize()` to `veafTime.lua` | `src/scripts/veaf/veafTime.lua` | fix | 5 min | ✅ |
| MISSING-INIT-003 | Add `initialize()` to `veafUnits.lua` | `src/scripts/veaf/veafUnits.lua` | fix | 5 min | ✅ |
| MISSING-INIT-004 | Add `initialize()` to `veafSkynetIadsMonitor.lua` | `src/scripts/veaf/veafSkynetIadsMonitor.lua` | fix | 5 min | ✅ |

---

## Lot 27 — DOC-FR-MERGE: French as default language + v5 content merge

**Goal**: Switch French as the default MkDocs documentation language and enrich v6 pages with the missing conceptual content from the v5 documentation (written manually).

**Branch**: `feature/doc-fr-default-and-v5-merge` → PR → `develop-v6`

| # | Ticket | Files | Type | Effort | Status |
|---|--------|-------|------|--------|--------|
| DOC-FR-001 | Rename `*.md` → `*.en.md` and `*.fr.md` → `*.md` (35 pairs) | `doc/**` | chore | 15 min | ✅ |
| DOC-FR-002 | Update `mkdocs.yml`: FR default, EN secondary | `mkdocs.yml` | chore | 10 min | ✅ |
| DOC-FR-003 | Merge v5 content → `veafQraManager.md` (FR + EN) | `doc/mission-maker/scripts/veafQraManager.*` | chore | 45 min | ✅ |
| DOC-FR-004 | Merge v5 content → `veafCombatZone.md` (FR + EN) | `doc/mission-maker/scripts/veafCombatZone.*` | chore | 45 min | ✅ |
| DOC-FR-005 | Merge v5 content → `veafAirWaves.md` (FR + EN) | `doc/mission-maker/scripts/veafAirWaves.*` | chore | 30 min | ✅ (v6 already complete) |
| DOC-FR-006 | Merge v5 content → `veafRadio.md` (FR + EN) | `doc/mission-maker/scripts/veafRadio.*` | chore | 20 min | ✅ |
| DOC-FR-007 | Merge v5 content → `veafSkynetIadsHelper.md` (FR + EN) | `doc/mission-maker/scripts/veafSkynetIadsHelper.*` | chore | 20 min | ✅ |
| DOC-FR-008 | Merge v5 content → `veafWeather.md` (FR + EN) | `doc/mission-maker/scripts/veafWeather.*` | chore | 20 min | ✅ |
| DOC-FR-009 | Check `presets.md` v5 and identify the v6 equivalent | TBD | chore | 15 min | ✅ (already in GUIDE.md) |

---

## Lot FIX-YAML-SYNTAX — unhandled YAML error in build and mission_builder_worker

**Goal**: Catch YAML syntax errors in `mission.yaml` to display a clear message instead of a Python traceback.

**Context**: An unhandled `yaml.YAMLError` in `build.py` (name peek) and `mission_builder_worker.py` (full load) caused a crash with traceback. PyYAML's native error message (file, line, column, context) is now propagated via `logger.error`.

**Branch**: `fix/yaml-syntax-error` → PR → `develop-v6`

| # | Ticket | Files | Type | Effort | Status |
|---|--------|-------|------|--------|--------|
| YAML-SYNTAX-001 | Handle `yaml.YAMLError` in `build.py` (peek mission name) | `src/python/veaf-tools/veaf_tools/commands/build.py` | fix | 5 min | ✅ |
| YAML-SYNTAX-002 | Handle `yaml.YAMLError` in `mission_builder_worker.py` (full load) | `src/python/veaf-tools/mission_builder/mission_builder_worker.py` | fix | 5 min | ✅ |

---

## Lot FIX-MANDATORY-ENABLE — block enable on mandatory modules

**Goal**: Prevent users from explicitly setting `enable: true` (or any value) on mandatory modules in `mission.yaml`; emit a clear error at build time.

**Branch**: `fix/mandatory-yaml-enable` → PR → `develop-v6`

| # | Ticket | Type | Effort | Status |
|---|--------|------|--------|--------|
| FME-001 | Detect mandatory-module `enable:` keys in `mission_builder_worker.py` and raise a critical error | fix | 10 min | ✅ |
| FME-002 | Test: verify error is raised when mandatory module has `enable: true` | test | 10 min | ✅ |

---

## Lot FIX-REMOVE-CONVERT — remove the `convert` command

**Goal**: Remove the `convert` command which is broken on v6 missions (crashes on missing `missionConfig.lua`) and whose role is covered by `extract` + `build`.

**Branch**: `fix/remove-convert-command` → PR #371 → `develop-v6`

| # | Ticket | Files | Type | Effort | Status |
|---|--------|-------|------|--------|--------|
| RMC-001 | Delete `commands/convert.py` and the `mission_converter/` package | `src/python/veaf-tools/` | chore | 5 min | ✅ |
| RMC-002 | Remove TUI entry and `cmd.convert.*` locale keys | `tui.py`, `en.json`, `fr.json` | chore | 10 min | ✅ |
| RMC-003 | Remove the corresponding test assertion | `test/python/veaf_libs/test_tui.py` | test | 5 min | ✅ |

---

## Lot FIX-MISSIONCONFIG-REFS — references to `missionConfig.lua` in doc and code

**Goal**: Replace all user-facing references to `missionConfig.lua` with the correct v6 name (`mission-script.lua` for custom code, `mission.yaml` for configuration).

**Branch**: `fix/remove-convert-command` → PR #371 → `develop-v6`

| # | Ticket | Files | Type | Effort | Status |
|---|--------|-------|------|--------|--------|
| MCR-001 | Fix `veafQraManager.md/en.md`: "Via missionConfig.lua" section | `doc/mission-maker/scripts/` | doc | 5 min | ✅ |
| MCR-002 | Fix `veafSkynetIadsHelper.md/en.md`: prerequisites and section title | `doc/mission-maker/scripts/` | doc | 5 min | ✅ |
| MCR-003 | Fix directory trees in `mission_builder_README.py` and `mission_extractor_README.py` | `src/python/veaf-tools/` | doc | 5 min | ✅ |
| MCR-004 | Fix AIEN/CTLD/CSAR comments in `veaf.lua` | `src/scripts/veaf/veaf.lua` | chore | 5 min | ✅ |
| MCR-005 | Fix test fixtures (`veafDynamicConfig.lua`, `mapResource`) | `test/veaf-tools/` | chore | 10 min | ✅ |

---

## Lot FEAT-DCS-BRIDGE — Optional dcs-bridge.lua injection

**Goal**: Allow the build tool to optionally inject `dcs-bridge.lua` into a DCS mission via a DO SCRIPT FILE trigger, controlled by a flag in `mission.yaml`.

**Branch**: `feature/dcs-bridge-injection` → PR → `develop-v6`

| # | Ticket | Files | Type | Effort | Status |
|---|--------|-------|------|--------|--------|
| DCSB-001 | Add optional `dcs_bridge.enabled` key (bool, default `false`) to the `mission.yaml` schema and `MissionConfig` dataclass | `src/defaults/mission-folder/mission.yaml`, `mission_config.py` | feat | 15 min | ✅ |
| DCSB-002 | Add optional `dcs_bridge.lua_path` key (path to `dcs-bridge.lua`; auto-detected from a well-known location if absent) | `mission_config.py` | feat | 15 min | ✅ |
| DCSB-003 | Copy `dcs-bridge.lua` into the build output and inject the DO SCRIPT FILE trigger into the mission | `mission_builder_worker.py` | feat | 30 min | ✅ |
| DCSB-004 | TDD tests: trigger injected when `enabled: true`, absent when `false`, error raised when file not found | `test/` | test | 20 min | ✅ |
| DCSB-005 | Document `dcs_bridge` section in the default `mission.yaml` and in the user documentation | `src/defaults/mission-folder/mission.yaml`, `doc/` | doc | 10 min | ✅ |

---

## Lot FIX-MANDATORY-YAML — YAML generators: emit `{}` for mandatory modules instead of `enable: true`

**Goal**: The three YAML generators (`v5_converter.py`, `lua_config_generator.py`, `config_migrator.py`) emitted `enable: true` for mandatory modules (UNITS, TIME, CACHE, EVENTS, MARKERS, COMMANDS). The build blocked on these entries with a critical error. They must emit `{}` instead (matching the `src/defaults/mission-folder/mission.yaml` template).

**Branch**: `fix/mandatory-yaml-enable` → PR → `develop-v6`

| # | Ticket | Files | Type | Effort | Status |
|---|--------|-------|------|--------|--------|
| FMY-001 | Expose `_MANDATORY_MODULES` as public in `lua_config_generator.py` and emit `{}` for mandatory modules in `generate_mission_yaml_template` | `veaf_libs/lua_config_generator.py` | fix | 10 min | ✅ |
| FMY-002 | In `v5_converter.py`: import `MANDATORY_MODULES`, add COMMANDS to `_BASE_ALWAYS_ON`, emit `{}` instead of `enable: true` for mandatory modules | `mission_builder/v5_converter.py` | fix | 10 min | ✅ |
| FMY-003 | In `config_migrator.py`: import `MANDATORY_MODULES`, emit `{}` instead of `enable: true` for mandatory modules | `mission_builder/config_migrator.py` | fix | 10 min | ✅ |
| FMY-004 | Update impacted tests and add missing cases | `test/python/` | test | 5 min | ✅ |

---

## Lot CMT-YAML-DOCS — doc comments and links in generated `mission.yaml` files

**Goal**: Generated `mission.yaml` files (by `generate-config`, `convert-v5` and `prepare`) must contain explanatory comments and a link to the relevant documentation chapter for each section. The current URLs pointed to a non-existent file.

**Branch**: `fix/mandatory-yaml-enable` (amended on current branch)

| # | Ticket | Files | Type | Effort | Status |
|---|--------|-------|------|--------|--------|
| CMT-001 | Fix the doc URL and add per-section links in `en.json` | `veaf_libs/locales/en.json` | chore | 10 min | ✅ |
| CMT-002 | Same fixes in `fr.json` | `veaf_libs/locales/fr.json` | chore | 10 min | ✅ |
| CMT-003 | Fix the URL and add per-section links in `v5_converter.py` | `mission_builder/v5_converter.py` | chore | 10 min | ✅ |
| CMT-004 | Fix the URL in `src/defaults/mission-folder/mission.yaml` | `src/defaults/mission-folder/mission.yaml` | chore | 5 min | ✅ |
| CMT-005 | Tests: verify links are present in generated YAML files | `test/python/` | test | 10 min | ✅ |

---

## Lot FIX-AIRCRAFT-DUPLICATE — Duplicate aircraft groups in "add" injection mode

**Goal**: Fix a DCS crash (`attempt to index global 'teamMemberDatalinks' (a nil value)`) caused by duplicate aircraft groups created during `inject_groups(mode="add")`. In add mode, groups already present in the mission were appended again from YAML, creating copies without `datalinks` metadata. The fix skips groups whose name already exists.

**Branch**: `fix/aircraft-duplicate-inject` → PR #375 → `develop-v6`

| # | Ticket | Files | Type | Effort | Status |
|---|--------|-------|------|--------|--------|
| ADUP-001 | In `inject_groups(mode="add")`: skip groups whose name already exists in the mission instead of appending | `aircrafts_injector/aircrafts_injector_worker.py` | fix | 10 min | ✅ |
| ADUP-002 | Regression tests: duplicate skipped, original data preserved, mix add/skip, replace mode unaffected | `test/python/aircrafts_injector/test_aircrafts_injector_worker.py` | test | 10 min | ✅ |

---

Lots completed 2026-06-07 → 2026-06-09 (archived 2026-06-09, on request — ahead of the usual 3-day rule).

---

## Lot FIX-CONVERT-V5-PRESETS — Per-aircraft radio assignments in convert-v5 presets

**Goal**: Fix `convert-v5` so that per-aircraft radio specificity from `radioSettings` is preserved in the generated `presets.yaml`.

**Branch**: `fix/convert-v5-presets-per-aircraft` → PR #381 → `develop-v6`

| # | Ticket | Files | Type | Effort | Status |
|---|--------|-------|------|--------|--------|
| CVPRE-001 | Parse `radioSettings` table and detect per-aircraft radio layouts (warbird, VHF-primary, hardcoded) | `v5_pipeline_converters.py` | fix | 30 min | ✅ |
| CVPRE-002 | Auto-assign warbird and VHF-primary aircraft in `presets_assignments`; emit warnings for typePattern and hardcoded entries | `v5_pipeline_converters.py` | fix | 10 min | ✅ |
| CVPRE-003 | Add i18n messages for new warnings; add 28 unit tests | `locales/en.json`, `locales/fr.json`, `test_v5_pipeline_converters.py` | feat | 5 min | ✅ |
| CVPRE-004 | Support regex patterns as `unit_type` keys in `presets_assignments` (exact > pattern > `all`) | `presets_manager.py`, `test_presets.py` | feat | 20 min | ✅ |

---

## Lot FEAT-COMMUNITY-TOGGLE — Enable/disable community scripts from mission.yaml

**Goal**: Allow mission makers to individually enable or disable community Lua scripts (TUM, CTLD, CSAR, etc.) via a `community_scripts:` section in `mission.yaml`, analogous to the existing `lua_modules:` section.

**Branch**: `feature/community-toggle` → PR → `develop-v6`

| # | Ticket | Files | Type | Effort | Status |
|---|--------|-------|------|--------|--------|
| COMM-001 | Give each community script a stable ID (key) in `get_community_script_files()` — return `list[dict]` instead of `list[tuple]` | `mission_tools/mission_constants.py` | refactor | 15 min | ✅ |
| COMM-002 | Parse `community_scripts:` section in `MissionBuilderWorker.__init__`; filter the list of community scripts to inject based on `enabled:` flags | `mission_builder/mission_builder_worker.py` | feat | 30 min | ✅ |
| COMM-003 | Apply the filter in both static trigger (`insert_veaf_trigrules`) and dynamic trigger (`insert_veaf_triggers`) | `mission_builder/mission_builder_worker.py` | feat | 20 min | ✅ |
| COMM-004 | Add `community_scripts:` block to the default `mission.yaml` with all scripts listed and `enabled: true` by default, with comments | `src/defaults/mission-folder/mission.yaml` | doc | 15 min | ✅ |
| COMM-005 | Update YAML reference doc (`MISSION_YAML_REFERENCE.md` + `.en.md`) with the new section | `doc/MISSION_YAML_REFERENCE.md`, `doc/MISSION_YAML_REFERENCE.en.md` | doc | 20 min | ✅ |
| COMM-006 | TDD tests: verify that a script with `enabled: false` is absent from the injected triggers | `test/python/` | test | 20 min | ✅ |
| COMM-007 | `convert-v5`: detect community scripts present in `published/src/scripts/community/` and emit `community_scripts:` section in generated `mission.yaml` | `mission_builder/v5_converter.py`, `test_v5_converter.py` | feat | 20 min | ✅ |

---

## Lot FEAT-CUSTOM-SCRIPTS — custom_scripts section in mission.yaml

**Goal**: Allow declaring custom Lua scripts in `mission.yaml` to suppress warnings and control the generation of the DCS load trigger.

**Branch**: `feature/custom-scripts` → PR → `develop-v6`

| # | Ticket | Files | Type | Effort | Status |
|---|--------|-------|------|--------|--------|
| CUSTOM-001 | Add `CustomScript` dataclass + parse `custom_scripts` in `__init__` | `mission_builder_worker.py` | feat | 10 min | ✅ |
| CUSTOM-002 | Update warning logic (declared = info, unknown = warning with hint) | `mission_builder_worker.py` | feat | 10 min | ✅ |
| CUSTOM-003 | Filter load triggers according to `generate_load_trigger` | `mission_builder_worker.py` | feat | 10 min | ✅ |
| CUSTOM-004 | TDD tests (warnings + trigger resolution) | `test_mission_builder_defaults.py` | test | 10 min | ✅ |
| CUSTOM-005 | Document the section in the default `mission.yaml` | `src/defaults/mission-folder/mission.yaml` | doc | 5 min | ✅ |

---

## Lot 24 — DOC-REVIEW: Klogg profile (REV-002)

**Goal**: Commit the VEAF Klogg profile to the repo to ease DCS log reading.

**Context**: All other REV-* tickets from Lot 24 are archived. REV-002 is waiting for the user to provide the `.conf` file.

**Branch**: `fix/doc-review-klogg` → PR → `develop-v6`

| # | Ticket | Files | Type | Effort | Status |
|---|--------|-------|------|--------|--------|
| REV-002 | Commit the Klogg profile provided by the user to `tools/klogg/veaf.conf`; update the "Reading the log" section in `GUIDE.md` and `GUIDE.fr.md` to point to this file | `tools/klogg/veaf.conf`, `doc/mission-maker/GUIDE.md`, `doc/mission-maker/GUIDE.fr.md` | chore | 20 min | ✅ |

---

## Lot RADIO-SPECS — DCS radio frequency validation in inject-presets

**Goal**: Extract DCS aircraft radio frequency specs from `dcs-lua-datamine`, bundle them as a YAML data file, validate preset frequencies at inject time, and publish a human-readable reference doc.
**Branch**: `feature/radio-specs-validation`

| # | Ticket | Type | Effort | Status |
|---|--------|------|--------|--------|
| RADIO-001 | Extraction script: fetch `panelRadio` from dcs-lua-datamine and generate `dcs-radio-specs.yaml` | feat | 45 min | ✅ |
| RADIO-002 | Bundle `dcs-radio-specs.yaml` as package data; load via `importlib.resources` | feat | 15 min | ✅ |
| RADIO-003 | `RadioFrequencyValidator`: validate preset frequencies against aircraft specs, warn on mismatch | feat | 45 min | ✅ |
| RADIO-004 | Integrate validator into `PresetsInjectorWorker.process_groups()` | feat | 20 min | ✅ |
| RADIO-005 | Generate `doc/mission-maker/dcs-radio-specs.md` (human-readable Markdown table) from the YAML | feat | 30 min | ✅ |
| RADIO-006 | Unit tests for validator (valid/invalid frequency, unknown aircraft, partial ranges) | feat | 45 min | ✅ |

**Estimated total: ~3h**

---

## Lot FIX-CONVERT-V5-DEFAULT-CWD — `convert-v5` uses current directory by default

**Goal**: Remove `no_args_is_help=True` from the `convert-v5` command so that invoking `veaf-tools convert-v5` with no arguments runs against the current working directory (the default `"."` already declared on `mission_folder`).

**Root cause**: `convert_v5.py:19` — `@app.command(no_args_is_help=True, ...)` overrides the `"."` default and shows help instead.

**Fix**: Change `no_args_is_help=True` → `no_args_is_help=False` (or remove the parameter entirely).

**Branch**: `fix/convert-v5-default-cwd` → PR → `develop-v6`

| # | Ticket | Files | Type | Effort | Status |
|---|--------|-------|------|--------|--------|
| CVCWD-001 | Remove `no_args_is_help=True` from `@app.command` decorator | `veaf_tools/commands/convert_v5.py` | fix | 5 min | ✅ |

---

## Lot FIX-SRS-WARN — false warning when SRS config file is absent

**Goal**: Suppress the spurious `W|initialize` warning emitted when SRS is not installed. SRS integration is optional; an absent config file is normal, not an error.

**Root cause**: `veafRadio.lua:932-934` — `loadfile(srsConfigPath)` returns `nil` both when the file **does not exist** and when it exists but is invalid. The code logs a `warn` in both cases. Users without SRS see this warning on every mission start.

**Fix**: Use `lfs.attributes(srsConfigPath)` (already available via `l_lfs`) to test for file existence before calling `loadfile`:
- File absent → `debug` log ("SRS config not found, SRS integration disabled")
- File present but `loadfile` returns `nil` → keep `warn` (actual corruption/syntax error)

**File**: `src/scripts/veaf/veafRadio.lua`, around line 920–934.

**Branch**: `fix/srs-warn` → PR → `develop-v6`

| # | Ticket | Files | Type | Effort | Status |
|---|--------|-------|------|--------|--------|
| SRS-001 | Check `lfs.attributes` before `loadfile`; downgrade absent-file log to `debug` | `src/scripts/veaf/veafRadio.lua` | fix | 10 min | ✅ |

---

## Lot FIX-CTLD-NIL — nil crash on ctld.builtFOBS / ctld.logisticUnits in scheduled fns

**Goal**: Fix `bad argument #1 to 'insert' (table expected, got nil)` crash in MIST scheduled functions when CTLD module table exists but its internal lists haven't been initialized yet (race condition on mission start).

**Root cause**: Three call sites guard only against `ctld` being falsy, but `ctld.builtFOBS` and `ctld.logisticUnits` are `nil` until `ctld.initialize()` runs. If a scheduled function fires before CTLD init completes, `table.insert` crashes.

| Site | File | Issue |
|------|------|-------|
| `veafGrass.lua:1003` | `if ctld then` | `ctld.builtFOBS` / `ctld.logisticUnits` may be nil |
| `veafSpawnGround.lua:182` | no guard | immediate crash if ctld not init |
| `veafSpawnEffects.lua:32` | `if ctld then` | `ctld.logisticUnits` may be nil |

**Fix**: extend all three guards to `if ctld and ctld.builtFOBS and ctld.logisticUnits then` (or equivalent per site).

**Branch**: `fix/ctld-nil` → PR → `develop-v6`

| # | Ticket | Files | Type | Effort | Status |
|---|--------|-------|------|--------|--------|
| CTLD-001 | Extend ctld guard in `veafGrass.lua` (~line 1003) | `src/scripts/veaf/veafGrass.lua` | fix | 5 min | ✅ |
| CTLD-002 | Add ctld guard in `veafSpawnGround.lua` (~line 182) | `src/scripts/veaf/veafSpawnGround.lua` | fix | 5 min | ✅ |
| CTLD-003 | Extend ctld guard in `veafSpawnEffects.lua` (~line 32) | `src/scripts/veaf/veafSpawnEffects.lua` | fix | 5 min | ✅ |

---

## Lot I18N-COVERAGE — i18n coverage tests + fix remaining hardcoded English strings

**Goal**: Add automated i18n coverage tests so hardcoded strings and missing translations are caught at CI. Then fix all currently identified violations.

### Context

`test_i18n.py` tests only the `t()` mechanics. No test currently verifies:
- every `t("key")` call in code has a matching entry in `en.json`
- every key in `en.json` has a translation in `fr.json`
- no user-visible message is a raw English string literal instead of `t("key")`

### Hardcoded strings identified (must fix)

| File | Strings |
|------|---------|
| `mission_builder/mission_builder_worker.py` | `Found lua_modules section`, `Found global_log_level`, `Legacy weather config`, `Generated '...' from mission.yaml` (~line 106, 109, 438, 1074) |
| `aircrafts_injector/aircrafts_injector_worker.py` | `No issues found`, `YAML validation successful`, `YAML validation failed`, `YAML file loaded successfully`, `Mission file loaded successfully`, `Mission written successfully`, etc. (~20 strings) |
| `veaf_libs/lua_config_generator.py` | `Module '...' requires '...' which is not configured — auto-enabling '...'` (~line 628) |
| `waypoints_injector/waypoints_manager.py` | `Loaded N waypoint(s) and N flight plan template(s)` (~line 142) |

**Branch**: `fix/i18n-coverage` → PR → `develop-v6`

| # | Ticket | Files | Type | Effort | Status |
|---|--------|-------|------|--------|--------|
| I18N-COV-001 | Add test: all `t("key")` calls in `src/python/` reference a key that exists in `en.json` | `test/python/veaf_libs/test_i18n.py` | test | 20 min | ✅ |
| I18N-COV-002 | Add test: every key in `en.json` has a non-empty entry in `fr.json` | `test/python/veaf_libs/test_i18n.py` | test | 10 min | ✅ |
| I18N-COV-003 | Add i18n keys for `mission_builder_worker.py` hardcoded strings and replace with `t()` | `mission_builder/mission_builder_worker.py`, `locales/en.json`, `locales/fr.json` | fix | 20 min | ✅ |
| I18N-COV-004 | Add i18n keys for `aircrafts_injector_worker.py` hardcoded strings and replace with `t()` | `aircrafts_injector/aircrafts_injector_worker.py`, `locales/en.json`, `locales/fr.json` | fix | 45 min | ✅ |
| I18N-COV-005 | Add i18n keys for `lua_config_generator.py` and `waypoints_manager.py` hardcoded strings | `veaf_libs/lua_config_generator.py`, `waypoints_injector/waypoints_manager.py`, `locales/*.json` | fix | 15 min | ✅ |

---

## Lot FIX-VERSIONS-YAML-ONLY — drop missions.yaml alias for weather pipeline

**Goal**: Remove `missions.yaml` as an accepted alias for the weather pipeline config. `versions.yaml` is the only valid filename. Eliminates confusion with `mission.yaml`.

**Branch**: `feature/versions-yaml-only` → PR #386 → `develop-v6`

| # | Ticket | Files | Type | Effort | Status |
|---|--------|-------|------|--------|--------|
| VYO-001 | Remove `missions.yaml` from `V6_PIPELINE_CANDIDATES["weather"]` | `mission_builder/v5_converter.py` | fix | 2 min | ✅ |
| VYO-002 | Remove legacy WEATHER-001 coexistence guard from `mission_builder_worker.py` | `mission_builder/mission_builder_worker.py` | fix | 5 min | ✅ |
| VYO-003 | Update `build.py` `_step_file` call and `weather.py` CLI default | `veaf_tools/commands/build.py`, `veaf_tools/commands/weather.py` | fix | 2 min | ✅ |
| VYO-004 | Update `weather_injector_README.py` and pipeline reference docs | `weather_injector/weather_injector_README.py`, `doc/PIPELINE_REFERENCE*.md` | doc | 5 min | ✅ |
| VYO-005 | Drop obsolete test `test_versions_not_copied_when_missions_exists` | `test/python/mission_builder/test_mission_builder_defaults.py` | test | 1 min | ✅ |

---

## Lot YAML-UX — Simplification syntaxe mission.yaml

**Goal**: Rendre `mission.yaml` lisible et modifiable par des utilisateurs non-informaticiens. Réduire les pièges syntaxiques (deux mots-clés pour la même chose, `{}`, `[]` inline, guillemets inconsistants). Unifier `lua_modules` et `community_scripts` en un seul bloc `modules:`.

**Principes directeurs**:
- Un seul style par construction YAML
- Même syntaxe pour les modules VEAF et les scripts communautaires
- Guillemets uniquement quand nécessaire, règle documentée
- Les listes toujours en style bloc (`-`), jamais inline `[]`
- `true`/`false` seuls quand pas de config supplémentaire, bloc `enabled:` sinon

**Dépendances**: UX-001 → UX-002 → UX-003 (dans cet ordre). UX-004/005/006 indépendants.

**Branch**: `feature/yaml-ux` → PR → `develop-v6`

| # | Ticket | Description | Files | Type | Effort | Status |
|---|--------|-------------|-------|------|--------|--------|
| YAML-UX-001 | `MODULE: {}` → `MODULE:` (null = module obligatoire actif, plus lisible) | Remplacer la génération et le parsing de `{}` pour les modules obligatoires — `null` YAML est équivalent et moins cryptique | `lua_config_generator.py`, `mission_builder_worker.py`, template `mission.yaml`, `config_migrator.py` | feat | 45 min | ✅ |
| YAML-UX-002 | Unifier `enable`/`enabled` → `enabled` partout | `lua_modules` utilise `enable`, `community_scripts` et `dcs_bridge` utilisent `enabled` — standardiser sur `enabled`, lire l'ancienne clé avec warning de dépréciation | `lua_config_generator.py`, `mission_builder_worker.py`, `v5_converter.py`, docs, template | feat | 1h | ✅ |
| YAML-UX-003 | Fusionner `lua_modules` + `community_scripts` → `modules:` avec syntaxe unifiée | Un seul bloc `modules:` ; syntaxe : `MODULE: true`/`false` (scalaire) ou bloc avec `enabled:` + config ; rétrocompat `lua_modules`/`community_scripts` avec warning pendant 1 version | `lua_config_generator.py`, `mission_builder_worker.py`, `v5_converter.py`, `config_migrator.py`, tests, docs | feat | 3h | ✅ |
| YAML-UX-004 | Listes toujours en style bloc (`-`) dans fichiers générés et template | Supprimer `groups: ["A", "B"]` et `enemy_coalitions: [BLUE]` → style bloc dans tous les fichiers générés par `v5_converter.py` et `lua_config_generator.py` | `lua_config_generator.py`, `v5_converter.py`, template `mission.yaml` | feat | 30 min | ✅ |
| YAML-UX-005 | En-tête syntaxe YAML dans `mission.yaml` généré + template + doc | Ajouter un bloc commentaire en tête expliquant : indentation espaces, règle des guillemets, style liste bloc, booléens — aussi dans `doc/` | `lua_config_generator.py`, `v5_converter.py`, template `mission.yaml`, `doc/GUIDE*.md` | doc | 30 min | ✅ |
| YAML-UX-006 | `migrate-config` : migrer fichiers existants vers nouvelle syntaxe | Ajouter une migration dans `config_migrator.py` pour convertir `lua_modules`/`community_scripts` → `modules:`, `enable` → `enabled`, `{}` → null, listes inline → bloc | `config_migrator.py`, tests | feat | 1h | ✅ |

---

## Lot FEAT-YAML-MODULE-UX — Module shorthand, uppercase community IDs, category sort

**Goal**: Improve readability of the generated `mission.yaml` from `convert-v5`:
1. Simple enabled modules use `MODULE: true` shorthand instead of two-line `MODULE:\n  enabled: true`
2. Community script IDs displayed in uppercase (`MIST`, `STTS`…) like VEAF modules
3. Modules sorted by category (Infrastructure first, then Core / Features / Combat / External)

**Branch**: `feature/yaml-module-ux` → PR → `develop-v6`

| # | Ticket | Files | Type | Effort | Status |
|---|--------|-------|------|--------|--------|
| MUX-001 | `yaml_module_entry()`: add `has_config` param — emit `MODULE: true` when no extra config | `lua_config_generator.py` | feat | 10 min | ✅ |
| MUX-002 | v5_converter: pass `has_config=True` for modules with extracted data; sort by category | `v5_converter.py` | feat | 25 min | ✅ |
| MUX-003 | Community script keys uppercase in generated YAML; case-insensitive matching in parser | `v5_converter.py`, `mission_builder_worker.py` | feat | 15 min | ✅ |
| MUX-004 | Update tests | `test_v5_converter.py`, `test_lua_config_generator.py` | test | 10 min | ✅ |

---

## Lot FIX-BRIEFING-MULTILINE — convert-v5 truncates multi-line Lua briefings

**Goal**: `setBriefing("line1\n" .. "line2\n")` must produce a complete multiline string in `mission.yaml`; currently only the first fragment is captured and literal `\n` is not decoded to a real newline.

**Root causes**:
1. `config_migrator.py` regex `"([^"]*)"` stops at first `"..."` fragment — ignores Lua `..` concatenation.
2. Lua escape `\n` is kept as literal `\n` instead of being decoded to a real newline.
3. `_yaml_str()` in `v5_converter.py` does not handle strings containing real newlines.
4. CAP mission briefings emitted inline via `_yaml_str()` instead of block scalar.

**Branch**: `fix/briefing-multiline` → PR → `develop-v6`

| # | Ticket | Files | Type | Effort | Status |
|---|--------|-------|------|--------|--------|
| BML-001 | Add `_lua_extract_string()` helper + apply to 3 `setBriefing` extraction sites | `config_migrator.py` | fix | 15 min | ✅ |
| BML-002 | `_yaml_str()`: handle strings with real newlines; CAP mission briefing → block scalar | `v5_converter.py` | fix | 10 min | ✅ |
| BML-003 | Tests | `test_config_migrator.py` | test | 20 min | ✅ |

---

## Lot FIX-CONVERTER-YAML-I18N — Syntax header + i18n comments in convert-v5 output

**Goal**: Fix two regressions in the `mission.yaml` generated by `convert-v5`:
1. The YAML syntax quick-reference header is missing (only present in `generate-config` output, not in `convert-v5` output).
2. All comment strings in the generated file are hardcoded English regardless of the user locale.

**Branch**: `fix/converter-yaml-i18n` → PR → `develop-v6`

| # | Ticket | Files | Type | Effort | Status |
|---|--------|-------|------|--------|--------|
| CYI-001 | Convert `_YAML_SYNTAX_HEADER` constant → `yaml_syntax_header()` public function using `t()` | `lua_config_generator.py`, `en.json`, `fr.json` | fix | 10 min | ✅ |
| CYI-002 | Add `yaml_syntax_header()` call to `v5_converter._build_mission_yaml_lines()` | `v5_converter.py` | fix | 5 min | ✅ |
| CYI-003 | Replace all hardcoded English comment strings in `_build_mission_yaml_lines()` with `t()` | `v5_converter.py`, `en.json`, `fr.json` | fix | 25 min | ✅ |
| CYI-004 | Update tests for new output format | `test_v5_converter.py` | test | 5 min | ✅ |

---

## Lot FIX-CONVERT-V5-LOG-DEFAULT — convert-v5 defaults global_log_level to debug instead of info

**Goal**: Change the fallback value for `global_log_level` in the generated `mission.yaml` from `debug` to `info`, so missions converted with no prior log level set are not silently deployed in debug mode.

**Root cause**: `v5_converter.py:811` — `f"global_log_level: {extracted_ll or 'debug'}"`. When `missionConfig.lua` had no explicit log level, `extracted_ll` is `None` and the fallback is `'debug'`. The inline comment even warns *"Remove or set to 'info' before deploying to players"* — but the default does the opposite.

**Fix**: Change `'debug'` → `'info'` in the fallback.

**Branch**: `fix/convert-v5-log-default` → PR → `develop-v6`

| # | Ticket | Files | Type | Effort | Status |
|---|--------|-------|------|--------|--------|
| CVLOG-001 | Change fallback `'debug'` → `'info'` in `_build_mission_yaml_lines` | `src/python/veaf-tools/mission_builder/v5_converter.py` | fix | 5 min | ✅ |

---

## Lot FIX-I18N-HARDCODED — AST test + fix hardcoded strings in aircrafts_injector + lua_config_generator

**Goal**: Ensure no hardcoded English prose appears in `logger.*()`, `console.print()`, or `return` statements. Add an AST-based test (`TestI18nNoHardcodedStrings`, COV-003) that fails when violations are found, then fix all violations in the two files targeted for this lot.

**Root cause**: `aircrafts_injector_worker.py` and `lua_config_generator.py` contained hardcoded English strings in logger/console calls and return values, bypassing the `t()` i18n system.

**Files changed**:
- `test/python/veaf_libs/test_i18n.py` — new `TestI18nNoHardcodedStrings` class with `_TODO_EXEMPTIONS` (25 files), `_has_prose()`, `_is_t_call()`, `_violations_in_file()`
- `src/python/veaf-tools/aircrafts_injector/aircrafts_injector_worker.py` — 15+ hardcoded strings → `t()` calls
- `src/python/veaf-tools/veaf_libs/lua_config_generator.py` — 2 `logger.warning()` calls → `t()` calls
- `src/python/veaf-tools/veaf_libs/locales/en.json` + `fr.json` — 18 new keys added

| # | Ticket | Files | Type | Effort | Status |
|---|--------|-------|------|--------|--------|
| IH-001 | Write failing AST-based `TestI18nNoHardcodedStrings` test | `test/python/veaf_libs/test_i18n.py` | test | 20 min | ✅ |
| IH-002 | Fix hardcoded strings in `aircrafts_injector_worker.py` (15 violations) | `aircrafts_injector_worker.py`, `en.json`, `fr.json` | fix | 25 min | ✅ |
| IH-003 | Fix hardcoded strings in `lua_config_generator.py` (2 violations) | `lua_config_generator.py`, `en.json`, `fr.json` | fix | 10 min | ✅ |

---

## Lot FIX-I18N-DEBT — Clear remaining hardcoded-string debt

**Goal**: Fix all 107 hardcoded English strings in the 25 files currently listed in `_TODO_EXEMPTIONS`, add matching keys to `en.json`/`fr.json`, and remove every file from the exemption list so COV-003 enforces the whole codebase.

**Branch**: `fix/i18n-debt` → PR → `develop-v6`

| # | Ticket | Files | Type | Effort | Status |
|---|--------|-------|------|--------|--------|
| DEBT-001 | Fix `mission_builder_worker.py` (14 violations) | worker + locales | fix | 30 min | ✅ |
| DEBT-002 | Fix `waypoints_injector_worker.py` (25 violations) | worker + locales | fix | 40 min | ✅ |
| DEBT-003 | Fix `veaf_tools/commands/convert_v5.py` (12 violations) | command + locales | fix | 20 min | ✅ |
| DEBT-004 | Fix `veaf_tools/commands/aircraft_groups.py` (7 violations) | command + locales | fix | 15 min | ✅ |
| DEBT-005 | Fix `veaf_tools/commands/build.py` (5 violations) | command + locales | fix | 10 min | ✅ |
| DEBT-006 | Fix `weather_injector/utils/lua_converter.py` (5 violations) | util + locales | fix | 10 min | ✅ |
| DEBT-007 | Fix remaining small files (≤3 violations each): mission_extractor, mission_tools, presets_injector, veaf-tools-updater, veaf_libs/*, veaf_tools/commands (7 files), waypoints_manager, weather_injector/* | various + locales | fix | 45 min | ✅ |
| DEBT-008 | Remove all 25 files from `_TODO_EXEMPTIONS` in test_i18n.py | test | 5 min | ✅ |

---

## Lot DOC-OVERHAUL — Complete, detailed, bilingual, ELI5 documentation

**Goal**: Make the documentation complete, detailed, accessible, fully bilingual (FR/EN parity), with ELI5 explanations for non-dev audiences (pilots, mission makers), mermaid diagrams, and screenshot placeholders. Blocks the next develop-v6 release.

**Branch**: `feature/doc-overhaul` → PR → `develop-v6`

**Audit findings** (verified):
- FR systematically lags EN: LUA_API_REFERENCE −1077 lines, TOOLS_REFERENCE −346, pilot/GUIDE −103, veafAirWaves −131, veafCombatZone −103, others −20…−50
- Missing files: `veafInterpreter.md` (no FR → nav L105 404), `dcs-radio-specs.en.md` (no EN)
- Zero images/screenshots in 40 docs; mermaid only in developer docs
- Pilot guide not truly ELI5 (unexplained jargon: Lua framework, AWACS, IADS)
- Content errors: deprecated `enable:` examples, removed `convert` command listed, CSAR "not available" (false), dead URL in updater

| # | Ticket | Type | Effort | Status |
|---|--------|------|--------|--------|
| DOC-001 | Create `veafInterpreter.md` (FR) — fixes broken FR nav. (`dcs-radio-specs` EN parity deferred to DOC-005: file is hand-maintained, not purely generated) | fix | 30 min | ✅ |
| DOC-002 | Isolated content errors done: remove `convert`, CSAR note (FR+EN), dead updater URL, debug-logging section, CHANGELOG consolidation. (`enable:`→`enabled:` + `lua_modules:`→`modules:` across ~20 files folded into per-file DOC-005 passes) | fix | 45 min | ✅ |
| DOC-003 | Pilot guide rewritten (FR+EN): deduplicated, accessible, `_auth` standardized, mermaid F10 menu, screenshot placeholders; READMEs reviewed (already clean) | feat | 2h | ✅ |
| DOC-004 | Mission-maker GUIDE + MIGRATION_GUIDE (FR+EN): build-pipeline + v5→v6 mermaid diagrams, `modules:` block example, broken `GUIDE.fr.md` links fixed | feat | 2h | ✅ |
| DOC-005a | Mechanical syntax sweeps (`enable:`→`enabled:` ×62, `lua_modules:`→`modules:` ×56) + MISSION_YAML_REFERENCE unified `modules:` rewrite (FR+EN) | feat | 1h30 | ✅ |
| DOC-005b | Script docs FR→EN parity: veafAirWaves, veafCombatZone, veafQraManager, veafShortcuts, veafWeather, veafRadio (all now delta ≤10) + broken `.fr.md` links fixed | feat | 2h30 | ✅ |
| DOC-005c | Big references in-section depth parity: LUA_API_REFERENCE (~1050 l. across 5 API sections) + TOOLS_REFERENCE (~346 l.) + dcs-radio-specs FR prose | feat | 5h | ✅ |
| DOC-006 | Produce DCS screenshot capture list for the user | chore | 30 min | ✅ |

**Estimated total: ~12h**

### DOC-005c handoff brief (cold-start ready)

The remaining work is **in-section depth parity** — same headings in FR and EN, but the
FR has shorter descriptions / fewer code examples. Approach: for each section, read the
EN version, then expand the FR to match (translate the missing prose, tables, and code
blocks). Code blocks/identifiers stay identical; only prose is translated.

**Files and gaps (FR lines behind EN):**

| File | Gap | Where the gap is |
|------|-----|------------------|
| `doc/LUA_API_REFERENCE.md` | ~1050 | Core Infrastructure (−190), Unit & Group Management (−388), Mission Systems (−284), Infrastructure & Services (−102), Communication & Control (−90). Other sections already at parity. |
| `doc/TOOLS_REFERENCE.md` | ~346 | All sections present (translated headings); depth is thinner throughout the updater/publish/architecture sections. |
| `doc/mission-maker/dcs-radio-specs.md` | prose only | The frequency table is language-neutral and fine; only the header prose + the hand-written "Critical aircraft" section need a FR pass. NOTE: this file is **hand-maintained** beyond what `veaf_build/radio_specs_updater.py` generates — do not regenerate, edit by hand. |

**Conventions already established this lot (keep consistent):**
- Tone: sober, vouvoiement, jargon explained at first use (no childish analogies).
- YAML syntax in examples: unified `modules:` block, `enabled:` (never `enable:`), community scripts as uppercase IDs inside `modules:`.
- Auth command is `_auth [PASSWORD]` (canonical `veafSecurity.Keyphrase`); never `-login`.
- Cross-doc links use `*.md` (NOT `*.fr.md` / `*.en.md`) — mkdocs-static-i18n resolves the language. Several `.fr.md` links were already fixed; watch for more.
- Screenshot placeholders live under `doc/assets/img/<area>/`.
- Per-doc commits, verify parity with `wc -l` after each file.

**After DOC-005c:** update CHANGELOG, open PR `feature/doc-overhaul` → `develop-v6`,
then the user captures the screenshots listed in DOC-006 to drop into `doc/assets/img/`.
