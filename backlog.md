# Backlog — VEAF Mission Creation Tools v6

## Calibration Table

| Lot | Estimated (min) | Actual (min) | Ratio | Note |
|-----|----------------|--------------|-------|------|
| *(no lot completed yet)* | | | | Initial factor: 1.15 |
| Lot 6 — BONUS | 210 | — | — | LUA-006 + TOOL-004 + LUA-007 |

## Legend

- **Effort**: estimated Copilot time in minutes (excludes user decisions and review)
- **Type**: `feat` / `fix` / `chore`
- **Status**: `⬜` to do · `🔄` in progress · `✅` done

> Completed lots (> 3 days ago) are moved to [backlog-archive.md](backlog-archive.md).

---

## Summary

| Lot | Estimate | Status |
|-----|----------|--------|
| Phase 0 — Restart | ~3h | [archived](backlog-archive.md) |
| Phase 0b — GitHub cleanup | ~25 min | ⬜ |
| Lot 1 — INFRA | ~4h15 | [archived](backlog-archive.md) |
| Lot 2 — CLI | ~2h35 | [archived](backlog-archive.md) |
| Lot 3 — TUI | ~2h20 | [archived](backlog-archive.md) |
| Lot 4 — LUA-CONFIG | ~6h | [archived](backlog-archive.md) |
| Lot 5 — RELEASE | ~1h30 | ⬜ |
| Lot 6 — BONUS | ~3h30 | [archived](backlog-archive.md) |
| Lot 7 — LUA FIXES | ~5h45 | [archived](backlog-archive.md) |
| Lot 8 — LUA-QUALITY | ~3h35 | [archived](backlog-archive.md) |
| Lot RC — v6.1.0 RC fixes | ~1h35 | [archived](backlog-archive.md) |
| Lot 9 — LUA-REFACTOR | ~11h30 | [archived](backlog-archive.md) |
| Lot 10 — YAML-CONFIG | ~14h | [archived](backlog-archive.md) |
| Lot 11 — I18N | ~7h10 | [archived](backlog-archive.md) |
| Lot 12 — QUALITY | ~16h35 | [archived](backlog-archive.md) |
| Lot 13 — DISCUSS | ~13h50 | [archived](backlog-archive.md) |
| Lot 14 — ARCH-COMMANDS | ~7h30 | [archived](backlog-archive.md) |
| Lot 15 — DOC | ~6h | [archived](backlog-archive.md) |
| Lot UPDATER-FIX | ~65 min | [archived](backlog-archive.md) |
| Lot 16 — LUA-COVERAGE | ~17h15 | [archived](backlog-archive.md) |
| Lot 17 — USER-CONFIG | ~3h | [archived](backlog-archive.md) |
| Lot 18 — VERSIONING | ~1h45 | ✅ |
| Lot 19 — MIGRATOR | ~2h30 | ✅ |
| Lot 20 — DEEPENING | ~7h | ✅ |
| Lot 21 — TYPING | ~20 min | ✅ |
| Lot 22 — TEST-LAYOUT | ~55 min | ✅ |
x| Lot 23 — DOC-YAML | ~8h20 | ✅ |
| Lot 24 — DOC-REVIEW | ~2h45 | ✅ (REV-002 différé) |
| Lot 25 — EXT-YAML | ~2h | ⬜ |
| Lot FIX-SORT — LUADATA FIX | ~15 min | ✅ |
| Lot 26 — IMC-FEEDBACK | ~2h40 | ✅ |
| Lot FIX-BUNDLE — VEAFCOMMANDS MISSING | ~10 min | ✅ |
| Lot FIX-ASSETS-NEWLINE — ASSETS newline in Lua string | ~20 min | ✅ |
| Lot FIX-WEATHER-ALIAS — missions.yaml + versions.yaml coexistence | ~25 min | ⬜ |
| Lot FIX-MISSIONCONFIG-BAK — supprimer extension .bak inutile | ~20 min | ⬜ |
| Lot FIX-README-COPY — ne plus copier presets.md dans src/ | ~10 min | ⬜ |
| Lot FIX-AIRCRAFT-ORPHAN — alerte fichier orphelin manquante pour aircraft-templates.yaml | ~15 min | ⬜ |
| Lot DOC-DEV-MODE — documenter dev_mode + scripts_path | ~30 min | ⬜ |
| Lot FEAT-PROFILES — profils de build dans mission.yaml | ~3h | ⬜ |
| Lot FEAT-MODULE-UX — Catégories, modules obligatoires, dépendances | ~2h | ⬜ |
| Lot FEAT-GITIGNORE — Template `.gitignore` VEAF MCT dans les defaults | ~25 min | ⬜ |
| **Total** | **~167h20** | |

*Initial calibration factor: 1.15 — recalculate after each completed lot.*

---

## Lot FEAT-MODULE-UX — Categories, mandatory modules, and dependency resolution

**Goal**: Improve the `lua_modules:` section in three independent but cohesive ways:
1. **Categories** (cosmetic) — group modules under comment headers in the `mission.yaml` template and in the generated `veaf-modules-config.lua`
2. **Mandatory modules** — emit a warning if a mandatory module (infrastructure tier) has `enable: false`
3. **Dependency resolution** — if module A is enabled and its dependency B is absent/disabled, auto-enable B in memory and emit a warning; the `mission.yaml` on disk is never modified

**Design decisions**:
- Categories: cosmetic only (no new YAML key, no behavioral change)
- Mandatory module with `enable: false`: warning + generate anyway (never hard-block)
- Dependency graph: hardcoded Python dict `_MODULE_DEPS` in `lua_config_generator.py`, maintained by AI when Lua source changes
- Missing dependency: auto-activate in memory + `logger.warning` (no disk write)

**Branch**: `feature/module-ux` → PR → `develop-v6`

| # | Ticket | Files | Type | Effort | Status |
|---|--------|-------|------|--------|--------|
| MODUX-001 | Add `_MODULE_CATEGORIES` dict in `lua_config_generator.py` (4 tiers: Infrastructure, Core, Features, Combat + External). Insert `# ── Category ──` comment headers in the YAML template generator and in `veaf-modules-config.lua` output | `veaf_libs/lua_config_generator.py` | feat | 20 min | ⬜ |
| MODUX-002 | Add `_MANDATORY_MODULES` frozenset (UNITS, TIME, CACHE, EVENTS, MARKERS, COMMANDS). In `lua_config_generator.py`, warn if a mandatory module has `enable: false` | `veaf_libs/lua_config_generator.py` | feat | 10 min | ⬜ |
| MODUX-003 | Add `_MODULE_DEPS` dict (see details). In `lua_config_generator.py`, after building the effective module list: for each enabled module, recursively resolve missing deps → auto-add with `enable: true` in memory + `logger.warning` per auto-added module | `veaf_libs/lua_config_generator.py` | feat | 30 min | ⬜ |
| MODUX-004 | Update `src/defaults/mission-folder/mission.yaml` — reorder `lua_modules:` comment block to match category grouping; add `# mandatory` annotation for infrastructure modules | `src/defaults/mission-folder/mission.yaml` | doc | 15 min | ⬜ |
| MODUX-005 | Unit tests: (a) category headers present in generated Lua, (b) warning on mandatory module disabled, (c) dep auto-resolution with warning, (d) transitive dep chain (A→B→C all resolved) | `test/python/test_lua_config_generator.py` | chore | 30 min | ⬜ |

**Raw total: 105 min → estimated (×1.15): ~120 min (~2h)**

<details>
<summary>Ticket details</summary>

**MODUX-001 — Categories**

```python
_MODULE_CATEGORIES: dict[str, list[str]] = {
    "Infrastructure": ["UNITS", "TIME", "CACHE", "EVENTS", "MARKERS", "COMMANDS"],
    "Core":           ["SECURITY", "RADIO", "GROUNDAI", "SHORTCUTS", "NAMEDPOINTS", "SPAWN"],
    "Features":       ["ASSETS", "MOVE", "GRASS", "SANCTUARY", "WEATHER", "REMOTE",
                       "AIRBASES", "MISSILEGUARDIAN", "INTERPRETER"],
    "Combat":         ["CASMISSION", "TRANSPORTMISSION", "COMBATMISSION", "COMBATZONE",
                       "QRA", "AIRWAVES", "CARRIER"],
    "External":       ["SKYNET", "SKYNET_MONITOR"],
}
```

In the YAML template generator (`_build_yaml_template()`): insert a comment line `# ── <Category> ────` before each group. In `generate_veaf_modules_config_lua()`: insert a `-- ── <Category> ──` comment before each group's `if varName then … end` block.

**MODUX-002 — Mandatory modules**

```python
_MANDATORY_MODULES: frozenset[str] = frozenset(
    {"UNITS", "TIME", "CACHE", "EVENTS", "MARKERS", "COMMANDS"}
)
```

Check point: in `generate_veaf_modules_config_lua()`, after resolving `lua_modules`:
```python
for mod_id in _MANDATORY_MODULES:
    cfg = effective_modules.get(mod_id, {})
    if isinstance(cfg, dict) and cfg.get("enable") is False:
        logger.warning(
            f"Module '{mod_id}' is mandatory and cannot be disabled — ignoring enable: false"
        )
        cfg.pop("enable", None)  # treat as enabled
```

**MODUX-003 — Dependency graph**

Initial graph (to be refined at implementation by scanning Lua files):

```python
_MODULE_DEPS: dict[str, list[str]] = {
    # Core
    "COMMANDS":          ["MARKERS"],
    "GROUNDAI":          ["COMMANDS"],
    "SHORTCUTS":         ["RADIO", "COMMANDS"],
    "NAMEDPOINTS":       ["COMMANDS"],
    "SPAWN":             ["UNITS"],
    # Features
    "ASSETS":            ["RADIO", "SPAWN"],
    "MOVE":              ["SPAWN", "COMMANDS"],
    "GRASS":             ["SPAWN"],
    "INTERPRETER":       ["RADIO", "COMMANDS"],
    # Combat
    "CASMISSION":        ["SPAWN", "GROUNDAI"],
    "TRANSPORTMISSION":  ["SPAWN"],
    "COMBATMISSION":     ["SPAWN"],
    "COMBATZONE":        ["SPAWN"],
    "QRA":               ["SPAWN", "RADIO"],
    "AIRWAVES":          ["SPAWN"],
    "CARRIER":           ["RADIO"],
    # External
    "SKYNET_MONITOR":    ["SKYNET"],
}
```

Resolution algorithm (after building effective module list, before generation):
```python
def _resolve_deps(effective: dict) -> dict:
    """Auto-enable missing dependencies, return updated dict."""
    changed = True
    while changed:  # iterate until stable (handles transitive deps)
        changed = False
        for mod_id, deps in _MODULE_DEPS.items():
            cfg = effective.get(mod_id, {})
            if isinstance(cfg, dict) and cfg.get("enable") is False:
                continue  # explicitly disabled — skip dep check
            if mod_id not in effective:
                continue  # not requested — skip
            for dep in deps:
                dep_cfg = effective.get(dep, {})
                if isinstance(dep_cfg, dict) and dep_cfg.get("enable") is False:
                    logger.warning(
                        f"Module '{mod_id}' requires '{dep}' "
                        f"but '{dep}' is disabled — auto-enabling '{dep}'"
                    )
                    effective[dep] = {"enable": True}
                    changed = True
                elif dep not in effective:
                    logger.warning(
                        f"Module '{mod_id}' requires '{dep}' "
                        f"which is not configured — auto-enabling '{dep}'"
                    )
                    effective[dep] = {"enable": True}
                    changed = True
    return effective
```

**MODUX-004 — mission.yaml template update**

Reorder the commented `lua_modules:` block to match the category groups. Add `# mandatory — cannot be disabled` annotation next to infrastructure modules. Example:

```yaml
# lua_modules:
#   # ── Infrastructure (mandatory) ──────────────────────────────────────────
#   UNITS:    {}   # mandatory — cannot be disabled
#   TIME:     {}   # mandatory — cannot be disabled
#   MARKERS:  {}   # mandatory — cannot be disabled
#   COMMANDS: {}   # mandatory — cannot be disabled
#   # ── Core ────────────────────────────────────────────────────────────────
#   SECURITY:     { enable: true }
#   RADIO:        { enable: true }
#   …
```

</details>

---

## Lot FEAT-PROFILES — Build profiles in mission.yaml

**Goal**: Allow defining named build profiles in `mission.yaml` (e.g. `TEST`, `SERVER`) that override configuration sections at build time. `veaf-tools build --profile TEST` applies the profile overrides on top of the base config.

**Context**: Typical use case — `TEST` profile: weather disabled, security disabled, log level debug; `SERVER` profile: all steps active, security enabled, log level info. Currently requires manual edits to `mission.yaml` between builds.

**Proposed design**:

```yaml
# mission.yaml (base config — always applied)
global_log_level: info
security:
  disabled: false
pipeline:
  weather: true

# Profiles — named sections under the `profiles:` key
profiles:
  TEST:
    global_log_level: debug
    security:
      disabled: true
    pipeline:
      weather: false
  SERVER:
    pipeline:
      weather: true
```

Merge strategy: deep-merge of the profile onto the base config (keys absent from the profile keep the base value). CLI: `veaf-tools build --profile TEST`.

**Branch**: `feature/build-profiles` → PR → `develop-v6`

| # | Ticket | Files | Type | Effort | Status |
|---|--------|-------|------|--------|--------|
| PROF-001 | Parse `profiles:` in `mission.yaml` + `_resolve_profile(base_yaml, profile_name) → merged_yaml` (deep merge) | `veaf_libs/mission_yaml.py` (new) or `mission_builder_worker.py` | feat | 45 min | ⬜ |
| PROF-002 | `--profile` option on `veaf-tools build`; pass name to `MissionBuilderWorker` which resolves the merged config before any other resolution | `veaf_tools/commands/build.py`, `mission_builder/mission_builder_worker.py` | feat | 30 min | ⬜ |
| PROF-003 | Log the active profile at build time (`Building with profile: TEST`); warn if unknown profile | `mission_builder/mission_builder_worker.py` | feat | 10 min | ⬜ |
| PROF-004 | Update `src/defaults/mission-folder/mission.yaml`: add commented `profiles:` section with `TEST` and `SERVER` examples | `src/defaults/mission-folder/mission.yaml` | doc | 15 min | ⬜ |
| PROF-005 | Unit tests: basic merge, unknown profile (warning), empty profile, profile disabling pipeline step | `test/python/test_build_profiles.py` | chore | 30 min | ⬜ |
| PROF-006 | Docs: "Build Profiles" section in `doc/MISSION_YAML_REFERENCE.md` (+ `.fr.md`) + mention in `doc/mission-maker/GUIDE.md` (+ `.fr.md`) | 4 doc files | doc | 30 min | ⬜ |

**Raw total: 160 min → estimated (×1.15): ~185 min (~3h)**

<details>
<summary>Ticket details</summary>

**PROF-001 — Deep merge**

Merge rule: for each profile key, override the base value. For nested dicts, merge recursively. Lists are replaced (not concatenated). `profiles:` itself is excluded from the effective config.

```python
def _deep_merge(base: dict, override: dict) -> dict:
    result = dict(base)
    for k, v in override.items():
        if k in result and isinstance(result[k], dict) and isinstance(v, dict):
            result[k] = _deep_merge(result[k], v)
        else:
            result[k] = v
    return result

def resolve_profile(yaml_data: dict, profile_name: str | None) -> dict:
    profiles = yaml_data.get("profiles") or {}
    base = {k: v for k, v in yaml_data.items() if k != "profiles"}
    if profile_name is None:
        return base
    if profile_name not in profiles:
        logger.warning(f"Profile '{profile_name}' not found in mission.yaml — using base config")
        return base
    return _deep_merge(base, profiles[profile_name])
```

**PROF-002 — CLI**

```python
profile: str | None = typer.Option(None, "--profile", "-p", help=t("cmd.build.opt.profile"))
```

In `MissionBuilderWorker.__init__()`, after reading `mission.yaml`:
```python
effective_yaml = resolve_profile(raw_yaml, profile_name)
```
All subsequent resolution (pipeline, lua_modules, security, etc.) reads from `effective_yaml` instead of `raw_yaml`.

**PROF-004 — Example in defaults/mission-folder/mission.yaml**

```yaml
# ── Build profiles ────────────────────────────────────────────────────────────
# Named overrides applied when building with --profile <name>.
# Keys in the profile deep-merge onto the base config above.
#
# profiles:
#   TEST:
#     global_log_level: debug
#     security:
#       disabled: true
#     pipeline:
#       weather: false
#   SERVER:
#     global_log_level: info
#     pipeline:
#       weather: true
```

</details>

---

## Lot FIX-OLDSCRIPTS — ~~veafCommands nil sur mission convertie v5→v6~~ (RÉSOLU — doublon de FIX-BUNDLE)

**Résolu** : root cause identifiée post-analyse des numéros de ligne DCS.

Comparaison log (01/06) vs build actuel :
- `VEAF-MARKERS|I|22032` → ligne 22032 ✓
- `VEAF-INTERPRETER|I|22182` → ligne **22325** aujourd'hui (+143 lignes)
- crash `veaf-scripts.lua:28283` → ligne **28425** aujourd'hui (+142)

Le `veaf-scripts.lua` utilisé le 01/06 manquait exactement le bloc `veafCommands.lua` (~143 lignes). Lot FIX-BUNDLE corrigeait précisément ce cas. **La mission doit simplement être rebuildée avec le package actuel.**

**Pas de nouveau ticket à créer.**

**Bug signalé** : en chargeant une mission convertie v5→v6 et buildée, DCS logue :
```
STATIC Mission scripts loading
Mission script error: [string "l10n/DEFAULT/veaf-scripts.lua"]:28283:
  attempt to index global 'veafCommands' (a nil value)
    in function 'initialize'
  [string "l10n/DEFAULT/veaf-config.lua"]:19: in main chunk
```

**Ce qu'on sait** :
- `veafSecurity` est défini (la guard `if veafSecurity then` passe)
- `veafSecurity.initialize()` est appelée → elle appelle `veafCommands.registerCommandHandler()` → crash nil
- Dans `veaf-scripts.lua` (v6), `veafCommands` est défini à la ligne 22040, **avant** `veafSecurity` à la ligne 27764
- Le log ne montre que "STATIC Mission scripts loading" (trigger 6) — le message "STATIC VEAF scripts loading" (trigger 4) est absent du log fourni

**Hypothèses à investiguer** (besoin de logs DCS complets) :

1. **Trigger 4 absent ou en erreur** : si `veaf-scripts.lua` ne s'est pas chargé (ou a crashé avant la ligne 22040), `veafCommands` serait nil. Mais `veafSecurity` (ligne 27764) serait aussi nil → la guard bloquerait. Sauf si `veafSecurity` vient d'une autre source.

2. **Fichiers `.lua` résiduels v5 dans `src/scripts/`** : le glob `src/scripts/*.lua` dans `get_mission_script_files()` ramasse TOUS les fichiers `.lua` de `src/scripts/`. Si des fichiers VEAF individuels v5 (ex. `veafSecurity.lua`) traînent là après conversion, ils sont chargés en mission scripts (trigger 6). Si ces fichiers v5 contiennent une version de `veafSecurity.initialize` qui appelle `veafCommands` sans que `veafCommands` soit défini dans le contexte...

3. **Double chargement** : `src/scripts/*.lua` matche aussi les fichiers déjà listés explicitement (`veaf-config.lua`, `mission-script.lua`). Ce double listing est probablement inoffensif (même contenu) mais vérifier.

**Investigation requise** : fournir les logs DCS complets depuis le début du chargement de la mission pour confirmer si trigger 4 (VEAF scripts) s'est exécuté normalement. Lister les fichiers présents dans `src/scripts/` de la mission.

**Fix envisagé** (à confirmer après investigation) : filtrer le glob `src/scripts/*.lua` pour exclure les fichiers déjà listés explicitement, ET/OU détecter les fichiers `.lua` inattendus dans `src/scripts/` et émettre un avertissement.

**Branch**: `fix/oldscripts-detection` → PR → `develop-v6`

| # | Ticket | Files | Type | Effort | Status |
|---|--------|-------|------|--------|--------|
| OLDSCRIPTS-000 | Investigation : reproduire le bug avec une vraie mission v5→v6 ; obtenir les logs DCS complets ; identifier le fichier responsable | — | chore | 15 min | ⬜ |
| OLDSCRIPTS-001 | Fix : selon le résultat de l'investigation, corriger la cause racine identifiée | TBD | fix | TBD | ⬜ |
| OLDSCRIPTS-002 | Ajouter un warning si des fichiers `.lua` inattendus sont présents dans `src/scripts/` (i.e. non listés explicitement dans `get_mission_script_files()`) | `src/python/veaf-tools/mission_tools/mission_constants.py` ou `mission_builder_worker.py` | fix | 15 min | ⬜ |

**Raw total: ~45 min estimé (hors investigation)**

---

## Lot DOC-DEV-MODE — Document dev_mode and scripts_path

**Goal**: `dev_mode` / `scripts_path` are nearly absent from the docs (1 mention as a YAML comment in GUIDE.md, no explanation of the concept, effects, or priority chain). Document for VEAF contributors who develop and test locally.

**Context**: `dev_mode: true` → `veaf-tools build` resolves `veaf-scripts.lua` from `build/veaf-scripts.lua` in the local repo (instead of `published/src/scripts/veaf/veaf-scripts.lua`). Requires `scripts_path` pointing to the `VEAF-Mission-Creation-Tools` repo. Priority chain: `--dev-mode` CLI → `mission.yaml build.dev_mode` → default `false`. Persisted in `mission.yaml` when passed via CLI. Same applies to `scripts_path` (CLI → `mission.yaml build.scripts_path` → `~/veafmct.yaml scripts_path`).

No named profiles — `dev_mode: true` (local scripts) vs `dev_mode: false` (published scripts). No distinct prod/staging concept.

**Branch**: `doc/dev-mode` → PR → `develop-v6`

| # | Ticket | Files | Type | Effort | Status |
|---|--------|-------|------|--------|--------|
| DEVMODE-001 | Add "Developer Mode" section in `doc/developer/GUIDE.md` (+ `.fr.md`): concept, prerequisites, how to activate (CLI / mission.yaml / veafmct.yaml), priority chain, effect on `veaf-scripts.lua` | `doc/developer/GUIDE.md`, `doc/developer/GUIDE.fr.md` | doc | 20 min | ⬜ |
| DEVMODE-002 | Document `build.dev_mode` and `build.scripts_path` in `doc/MISSION_YAML_REFERENCE.md` (+ `.fr.md`) under the `build:` section | `doc/MISSION_YAML_REFERENCE.md`, `doc/MISSION_YAML_REFERENCE.fr.md` | doc | 10 min | ⬜ |

**Raw total: 30 min → estimated (×1.15): ~35 min**

<details>
<summary>Expected content for DEVMODE-001</summary>

```markdown
## Developer Mode

Developer mode lets you test local changes to `veaf-scripts.lua` without publishing a release.
When enabled, `veaf-tools build` reads scripts from the local VEAF-Mission-Creation-Tools repo
instead of the `published/` folder shipped with veaf-tools.

### Prerequisites
- Clone/checkout VEAF-Mission-Creation-Tools locally
- Run `poetry run veaf-build build` to produce `build/veaf-scripts.lua`

### Activation (priority order — first match wins)
1. CLI flag: `veaf-tools build --dev-mode`
2. `mission.yaml`: `build: { dev_mode: true, scripts_path: <repo_root> }`
3. Default: `false`

`scripts_path` resolution order:
1. `--scripts-path <path>` CLI option
2. `mission.yaml build.scripts_path`
3. `~/veafmct.yaml scripts_path`

When passed via CLI, `dev_mode` and `scripts_path` are persisted in `mission.yaml`.

### Effect
- `dev_mode: false` (default): reads `published/src/scripts/veaf/veaf-scripts.lua`
- `dev_mode: true`: reads `<scripts_path>/build/veaf-scripts.lua`
```

</details>

---

## Lot FIX-README-COPY — Stop copying presets.md into src/

**Goal**: `complete_src_folder_with_defaults()` copies `src/defaults/mission-folder/src/presets.md` into the mission's `src/` folder. This is noise: docs are online, and a user who already has a `presets.md` doesn't expect it to be silently created/overwritten by the build. Remove this behavior.

**Context**: `_DEFAULT_FILE_MODULE_MAP` in `mission_builder_worker.py` lists `"presets.md": {"pipeline": "presets"}`. The file `src/defaults/mission-folder/src/presets.md` exists in the defaults. The `rglob("*")` loop detects it and copies it if absent (no overwrite thanks to `if not relative_path.exists()` — but silent creation is undesirable). No other `.md` file is in the defaults.

**Fix**:
1. Delete `src/defaults/mission-folder/src/presets.md` — root cause
2. Remove `"presets.md"` from `_DEFAULT_FILE_MODULE_MAP` — now a dead reference

**Branch**: `fix/no-readme-copy` → PR → `develop-v6`

| # | Ticket | Files | Type | Effort | Status |
|---|--------|-------|------|--------|--------|
| README-001 | Delete `src/defaults/mission-folder/src/presets.md` | `src/defaults/mission-folder/src/presets.md` | fix | 2 min | ⬜ |
| README-002 | Remove `"presets.md": {"pipeline": "presets"}` from `_DEFAULT_FILE_MODULE_MAP` | `mission_builder/mission_builder_worker.py` | fix | 3 min | ⬜ |
| README-003 | Audit: verify no other doc-only `.md` or `.txt` exists in `src/defaults/` (one-shot, no code change) | — | chore | 5 min | ⬜ |

**Raw total: 10 min → estimated (×1.15): ~12 min (~15 min)**

<details>
<summary>Ticket details</summary>

**README-001**: `git rm src/defaults/mission-folder/src/presets.md`

**README-002**: remove the line:
```python
"presets.md": {"pipeline": "presets"},
```
from `_DEFAULT_FILE_MODULE_MAP`.

**README-003**: `git ls-files src/defaults/` — verify only functional files remain (`.yaml`, `.lua`). If other doc-only `.md` or `.txt` files exist → delete them in this same ticket.

Note: the `README.txt` generated in `backup_v5/` by the v5 conversion is intentional (explains the backup folder contents) — do not touch here (see ticket BAK-003 if needed).

</details>

---

## Lot FIX-AIRCRAFT-ORPHAN — Missing orphan-file warning for aircraft-templates.yaml

**Goal**: When `aircraft_groups` pipeline step is disabled in `mission.yaml` but `src/aircraft-templates.yaml` still exists in the mission folder, no warning is emitted. The user gets no feedback that the file is being silently ignored.

**Root cause**: The orphan-file mechanism in `complete_src_folder_with_defaults()` (`mission_builder_worker.py`) only covers files that physically exist in `src/defaults/mission-folder/` **and** are listed in `_DEFAULT_FILE_MODULE_MAP`. Since `aircraft-templates.yaml` is a user-generated file (not a default), it is never iterated → the guard is never reached.

**Fix**: Add a dedicated post-pipeline check in `build.py` (after `_step_file()` returns `None` for `aircraft_groups`) that scans for `src/aircraft-templates.yaml` in the mission folder and emits `logger.warning` if found.

**Branch**: `fix/aircraft-orphan-warn` → PR → `develop-v6`

| # | Ticket | Files | Type | Effort | Status |
|---|--------|-------|------|--------|--------|
| AORPHAN-001 | In `build.py`, after `_step_file("aircraft_groups", …)` returns `None` (step skipped/disabled), check if `p_mission_folder / "src/aircraft-templates.yaml"` exists and warn | `veaf_tools/commands/build.py` | fix | 10 min | ⬜ |
| AORPHAN-002 | Unit test: assert warning emitted when `aircraft_groups` disabled + `src/aircraft-templates.yaml` present; assert no warning when step enabled or file absent | `test/python/test_build_pipeline.py` | chore | 10 min | ⬜ |

**Raw total: 20 min → estimated (×1.15): ~23 min (~25 min)**

<details>
<summary>Ticket details</summary>

**AORPHAN-001 — Warning in build.py**

Current code (around line 164):
```python
aircraft_path = _step_file(
    "aircraft_groups", "src/aircraft-templates.yaml", "src/templates.yaml", "aircraft-templates.yaml"
)
if aircraft_path:
    ...  # inject
```

Change: after the `if aircraft_path:` block, add:
```python
else:
    # Step skipped: warn if the file is present (would be silently ignored)
    _orphan = p_mission_folder / "src" / "aircraft-templates.yaml"
    if _orphan.exists():
        logger.warning(
            f"Orphan file 'src/aircraft-templates.yaml': "
            f"pipeline 'aircraft_groups' is disabled or skipped "
            f"but the file still exists in your mission folder. "
            f"You can safely delete it, or enable 'aircraft_groups' in mission.yaml."
        )
```

**AORPHAN-002 — Unit test** 

Mock `p_mission_folder` with a temporary directory containing `src/aircraft-templates.yaml`. Set `pipeline_cfg["aircraft_groups"] = False`. Assert `logger.warning` called with a message containing `"aircraft-templates.yaml"`.

</details>

---

## Lot FIX-MISSIONCONFIG-BAK — Remove useless `.bak` extension on missionConfig.lua

**Goal**: During v5→v6 conversion, `missionConfig.lua` is copied into `backup_v5/` with a `.lua.bak` extension. This is inconsistent: all other backed-up files keep their original name, and `.bak` adds nothing since the file is already isolated in `backup_v5/`. Remove the rename → `backup_v5/src/scripts/missionConfig.lua`.

**Context**: `_migrate_config()` in `v5_converter.py`:
1. Creates `backup_v5/src/scripts/missionConfig.lua.bak` (copy of original)
2. Embeds annotated content in the Markdown report (no separate file)
3. Writes `src/scripts/mission-script.lua` (clean v6 file)
4. Deletes `src/scripts/missionConfig.lua`

The `.bak` is referenced in: `report.missionconfig_backup`, i18n keys `convert_v5.action.missionconfig_bak`, `report.missionconfig.migrated`, `report.cleanup.delete_bak`, `_build_manual_review()`, and the `README.txt` in `backup_v5/`.

**Fix**: replace `src.stem + ".lua.bak"` with `src.name` (= `"missionConfig.lua"`). Update all i18n strings and the generated `README.txt`.

**Branch**: `fix/missionconfig-no-bak` → PR → `develop-v6`

| # | Ticket | Files | Type | Effort | Status |
|---|--------|-------|------|--------|--------|
| BAK-001 | `_migrate_config()`: `bak_path = backup_dir / src.name` instead of `backup_dir / (src.stem + ".lua.bak")` | `mission_builder/v5_converter.py` | fix | 5 min | ⬜ |
| BAK-002 | Update i18n strings `convert_v5.action.missionconfig_bak` (en + fr) and `report.cleanup.delete_bak` → remove all `.bak` references | `veaf_libs/locales/en.json`, `veaf_libs/locales/fr.json` | fix | 5 min | ⬜ |
| BAK-003 | Update the `README.txt` generated in `backup_v5/` → replace `missionConfig.lua.bak` with `missionConfig.lua` | `mission_builder/v5_converter.py` | fix | 5 min | ⬜ |
| BAK-004 | Unit test: `_migrate_config()` with `backup=True` → assert `backup_v5/.../missionConfig.lua` exists and `missionConfig.lua.bak` does **not** exist | `test/python/test_v5_converter.py` | chore | 5 min | ⬜ |

**Raw total: 20 min → estimated (×1.15): ~23 min (~25 min)**

<details>
<summary>Ticket details</summary>

**BAK-001 — Main fix**

```python
# Before
bak_path = backup_dir / (src.stem + ".lua.bak")
# After
bak_path = backup_dir / src.name  # → missionConfig.lua
```

Also update the `t()` call that formats the path:
```python
report.actions.append(t("convert_v5.action.missionconfig_bak", path=f"{rel.parent}/{src.name}"))
```

**BAK-002 — i18n**

`en.json` (no content change — `{path}` will now contain `.lua` without `.bak`):
```json
"convert_v5.action.missionconfig_bak": "missionConfig.lua: original backed up → backup_v5/{path}",
```

`report.cleanup.delete_bak` key → rename to `report.cleanup.delete_missionconfig_backup` for clarity, or simply update the text.

**BAK-003 — README.txt**

Line to update:
```
  src/scripts/missionConfig.lua.bak  — original unmodified file (for rollback)
```
→
```
  src/scripts/missionConfig.lua  — original unmodified file (for rollback)
```

**BAK-004 — Test**

Assert:
- `backup_v5/src/scripts/missionConfig.lua` exists
- `backup_v5/src/scripts/missionConfig.lua.bak` does not exist

</details>

---

## Lot FIX-WEATHER-ALIAS — missions.yaml and versions.yaml coexistence after v5→v6 conversion

**Goal**: Prevent `src/missions.yaml` (legacy alias) and `src/versions.yaml` (canonical v6) from both being present in a converted mission folder, which causes the wrong file to be silently used at build time.

**Context**: Before REV-001 (v6.2.0), the canonical weather file was called `missions.yaml`. After REV-001 it is `versions.yaml` — `missions.yaml` is now accepted as a legacy fallback. Regression scenario:
1. Partially migrated mission already has `src/missions.yaml`
2. `complete_src_folder_with_defaults()` only checks for the absence of `versions.yaml` → copies the default file from defaults
3. Both files coexist
4. `build.py:_step_file("weather", "src/missions.yaml", "src/versions.yaml", …)` picks `missions.yaml` first → the empty default `versions.yaml` is ignored, but having both creates confusion and can mask bugs if content diverges

**Proposed fix**:
- `complete_src_folder_with_defaults()`: before copying `versions.yaml`, check whether a legacy weather alias (`missions.yaml`) already exists in `src/`. If so, skip + warn: "legacy alias `missions.yaml` found, skipping copy of `versions.yaml`; consider renaming to `versions.yaml`"
- Add `missions.yaml` to `_DEFAULT_FILE_MODULE_MAP` with `{"pipeline": "weather"}` so the orphan-file warning also fires if the weather step is disabled

**Branch**: `fix/weather-alias-coexistence` → PR → `develop-v6`

| # | Ticket | Files | Type | Effort | Status |
|---|--------|-------|------|--------|--------|
| WEATHER-001 | `complete_src_folder_with_defaults()`: skip copying `versions.yaml` if `missions.yaml` already exists in `src/`; emit `logger.warning` with migration message | `mission_builder/mission_builder_worker.py` | fix | 10 min | ⬜ |
| WEATHER-002 | Add `"missions.yaml": {"pipeline": "weather"}` to `_DEFAULT_FILE_MODULE_MAP` for orphan-warning coverage | `mission_builder/mission_builder_worker.py` | fix | 5 min | ⬜ |
| WEATHER-003 | Unit test: mission folder with existing `src/missions.yaml` → `complete_src_folder_with_defaults()` does not create `src/versions.yaml` + warning is emitted | `test/python/test_mission_builder_worker.py` | chore | 10 min | ⬜ |

**Raw total: 25 min → estimated (×1.15): ~29 min (~30 min)**

<details>
<summary>Ticket details</summary>

**WEATHER-001 — Conditional skip**

In `complete_src_folder_with_defaults()`, the block that copies `versions.yaml` should first check:
```python
if f.name == "versions.yaml":
    legacy = self.mission_folder / "src" / "missions.yaml"
    if legacy.exists():
        logger.warning(
            f"Legacy weather config '{legacy.relative_to(self.mission_folder)}' found. "
            f"Skipping copy of default 'src/versions.yaml'. "
            f"Consider renaming 'missions.yaml' → 'versions.yaml'."
        )
        continue
```

**WEATHER-002 — `_DEFAULT_FILE_MODULE_MAP`**

Add before the `for f in defaults_folder.rglob("*")` loop:
```python
"missions.yaml": {"pipeline": "weather"},
```
Note: `missions.yaml` is not in the defaults (only `versions.yaml` is), so this entry will only trigger the orphan-file warning code (file exists in mission but step is disabled).

**WEATHER-003 — Test**

Scenario: mock `defaults_folder` with `src/versions.yaml`, mock `mission_folder/src/missions.yaml` present. Assert `versions.yaml` is not created and logger receives the expected warning message.

</details>

---

## Lot FIX-ASSETS-NEWLINE — ASSETS: newline inside generated Lua strings

**Goal**: Fix the Lua syntax error produced when a `description` or `information` field of an asset (in `mission.yaml`) contains `\n`: the generator inserts a literal newline inside a `"..."` string, which is invalid in Lua 5.1.

**Context**: `lua_config_generator.py` (~lines 174–178) generates the `name`, `description`, `information` fields as `f'field = "{value}"'`. If the YAML value contains `\n` (e.g. `"Tacan 64Y\nU290.50 (20)\nZone OUEST"`), Python decodes `\n` to a real newline → the generated Lua string is split across multiple lines → syntax error when loading the mission.

**Proposed fix**: in `_emit_lua_string(value)`, use `[[value]]` (Lua long string) when the value contains `\n` or `"`, otherwise keep `"value"`.

**Branch**: `fix/assets-newline-lua-string` → PR → `develop-v6`

| # | Ticket | Files | Type | Effort | Status |
|---|--------|-------|------|--------|--------|
| ASSETS-001 | Add `_emit_lua_string(value: str) -> str` in `lua_config_generator.py`: returns `[[value]]` if value contains `\n` or `"`, otherwise `"value"`. Apply to `name`, `description`, `information` fields in the ASSETS block. | `veaf_libs/lua_config_generator.py` | fix | 10 min | ✅ |
| ASSETS-002 | Unit test: asset with multi-line `information` → generated Lua contains `[[...]]` and parses without error | `test/python/test_lua_config_generator.py` | chore | 10 min | ✅ |

**Raw total: 20 min → estimated (×1.15): ~23 min (~25 min)**

<details>
<summary>Ticket details</summary>

**ASSETS-001 — Fix `_emit_lua_string`**

Input YAML:
```yaml
assets:
  - sort: 3
    name: "T1-Arco-1"
    description: "Arco-1 (KC-135)"
    information: "Tacan 64Y\nU290.50 (20)\nZone OUEST"
    linked: "T1-Arco-1 escort"
```

Expected Lua (currently broken):
```lua
{sort = 3, name = "T1-Arco-1", description = "Arco-1 (KC-135)", information = "Tacan 64Y
U290.50 (20)
Zone OUEST", linked = "T1-Arco-1 escort"},
```

Expected Lua (correct after fix):
```lua
{sort = 3, name = "T1-Arco-1", description = "Arco-1 (KC-135)", information = [[Tacan 64Y
U290.50 (20)
Zone OUEST]], linked = "T1-Arco-1 escort"},
```

Rule: use `[[...]]` whenever the value contains `\n` or `"`. Lua long strings natively support newlines and don't require quote escaping.

**ASSETS-002 — Test**
Assert that the Lua generated for an asset with a multi-line `information`:
1. Contains `[[` and `]]`
2. Does not contain `"Tacan 64Y\n` (newline inside a quoted string)

</details>

---

## Lot FIX-BUNDLE — VEAFCOMMANDS MISSING: veafCommands.lua absent du bundle

**Goal**: Corriger le crash `attempt to index global 'veafCommands' (a nil value)` au chargement de mission — `veafCommands.lua` était absent de la liste de concaténation dans `veaf_build/worker.py`.

**Context**: `veafGroundAI.lua`, `veafCasMission.lua` et d'autres modules appellent `veafCommands.registerCommandHandler()` dans leur `initialize()`. Or `veafCommands.lua` n'était pas inclus dans `lua_scripts` → absent du bundle `veaf-scripts.lua` → nil au runtime. Le guard IMC-010 dans `veaf.initialize()` ne pouvait pas non plus aider car il est lui-même dans le bundle.
**Branch**: `fix/veafcommands-missing-bundle` → PR → `develop-v6`

| # | Ticket | Fichiers touchés | Type | Effort | Status |
|---|--------|-----------------|------|--------|--------|
| BUNDLE-001 | Ajouter `"veafCommands.lua"` dans `lua_scripts` après `"veafMarkers.lua"` dans `veaf_build/worker.py` | `veaf_build/worker.py` | fix | 5 min | ✅ |

**Raw total: 5 min → estimated (×1.15): ~6 min (~10 min)**

---

## Lot 19 — MIGRATOR: Audit et complétion de la conversion missionConfig.lua

**Goal**: Vérifier que `ConfigMigrator` gère correctement toutes les constructions Lua réelles d'un `missionConfig.lua` v5 ; combler les lacunes de tests ; corriger les régressions trouvées.
**Context**: `ConfigMigrator` contient 12 méthodes `_extract_*` mais seulement 4 sont couvertes par des tests unitaires. Aucun test d'intégration n'existe à ce jour malgré la présence de fixtures réelles dans `test/veaf-tools/`.
**Branch**: `fix/migrator-coverage` → PR → `develop-v6`

| # | Ticket | Fichiers touchés | Type | Effort | Status |
|---|--------|-----------------|------|--------|--------|
| MIG-001 | Test d'intégration end-to-end — faire tourner `ConfigMigrator.migrate()` sur les fixtures réelles (`test/veaf-tools/mission-builder/src/scripts/missionConfig.lua` et `test/veaf-tools/demo-mission/src/scripts/missionConfig.lua`) et vérifier qu'aucune exception n'est levée et que les modules attendus sont bien détectés | `mission_builder/test_config_migrator.py` | chore | 30 min | ✅ |
| MIG-002 | Ajouter des tests unitaires pour les 8 extracteurs non couverts : `_extract_identity_and_security`, `_extract_combat_missions`, `_extract_shortcuts`, `_extract_named_points`, `_extract_sanctuary_zones`, `_extract_combat_zone_settings`, `_extract_combat_zones`, `_extract_airwaves_zones`, `_extract_security_mm` | `mission_builder/test_config_migrator.py` | chore | 60 min | ✅ |
| MIG-003 | Corriger les bugs trouvés lors de MIG-001/MIG-002 (régressions, patterns non couverts) | `mission_builder/config_migrator.py` | fix | 60 min | ✅ |

**Raw total: 150 min → estimated (×1.15): ~175 min (~2h30)**

<details>
<summary>Détails des tickets</summary>

**MIG-001 — Test d'intégration**
Les fixtures disponibles :
- `test/veaf-tools/mission-builder/src/scripts/missionConfig.lua` — mission de test générique avec QRA, shortcuts, assets, radio
- `test/veaf-tools/demo-mission/src/scripts/missionConfig.lua` — mission de démo plus complète

Le test d'intégration doit vérifier :
- Aucune exception lors de `migrate()`
- `enabled_modules` contient les modules présents dans le fichier
- Tous les `doFile(veaf...)` sont commentés
- Le YAML snippet généré est un YAML valide (`yaml.safe_load` ne plante pas)

**MIG-002 — Tests unitaires des extracteurs**
Extracteurs actuellement sans test :
- `_extract_identity_and_security` : extraction de `veaf.config.MISSION_NAME`, `MISSION_EXPORT_PATH`, `veafSecurity.disable()`, `global_log_level`
- `_extract_combat_missions` : définitions `VeafCombatMission:new()` avec chaining
- `_extract_shortcuts` : blocs `VeafAlias:new()` avec `setName`/`setVeafCommand`/`setBypassSecurity`
- `_extract_named_points` : bloc `if veafNamedPoints then` → commenté avec note de migration
- `_extract_sanctuary_zones` : blocs `VeafSanctuaryZone:new()` enveloppés dans `veafSanctuary.addZone()`
- `_extract_combat_zone_settings` : settings globaux `veafCombatZone.xxx = yyy`
- `_extract_combat_zones` : définitions `VeafCombatZone:new()` avec chaining
- `_extract_airwaves_zones` : définitions `VeafAirWave:new()` avec chaining
- `_extract_security_mm` : `veafSecurity.setMasterPassword()` hashes

**MIG-003 — Corrections**
Corrections à apporter une fois les bugs identifiés via MIG-001 et MIG-002. Exemples typiques :
- Patterns réels non reconnus par les regex (variantes de syntaxe Lua : newlines dans les appels, espaces variables)
- Méthodes de chaining inconnues générant des warnings au lieu d'être silencieuses
- Blocs multi-instances mal délimités (chevauchement de `_find_matching_close`)

</details>

---

## Lot 18 — VERSIONING: Single source of truth pour la version

**Goal**: Centraliser la version dans `pyproject.toml` et la propager automatiquement partout — fallbacks dans les `.py`, métadonnées des `.exe` Windows, et affichage dans la commande `about`.
**Branch**: `feature/versioning-sot` → PR → `develop-v6`

| # | Ticket | Fichiers touchés | Type | Effort | Status |
|---|--------|-----------------|------|--------|--------|
| VER-001 | Supprimer les fallbacks version hardcodés dans `app.py` ("6.1.2") et `veaf-tools-updater.py` ("6.1.5") ; lire `pyproject.toml` à la compilation pour injecter la bonne valeur, ou générer un `_version.py` depuis `veaf_build/worker.py` | `veaf_tools/app.py`, `veaf-tools-updater.py`, `veaf_build/worker.py` | chore | 30 min | ✅ |
| VER-002 | Embarquer les métadonnées Windows (FILE_VERSION / PRODUCT_VERSION) dans les `.exe` PyInstaller — créer un `version_file.txt` généré dynamiquement au build depuis la version lue dans `pyproject.toml`, le référencer dans `veaf-tools.spec` et `veaf-tools-updater.spec` | `veaf-tools.spec`, `veaf-tools-updater.spec`, `veaf_build/worker.py` | chore | 45 min | ✅ |
| VER-003 | Afficher la version de l'outil dans `about` — ajouter `VERSION` à la sortie de la commande (ex : `veaf-tools v6.1.5`) | `veaf_tools/commands/about.py`, `locales/en.json`, `locales/fr.json` | feat | 15 min | ✅ |

**Raw total: 90 min → estimated (×1.15): ~105 min (~1h45)**

<details>
<summary>Détails des tickets</summary>

**VER-001 — Single source of truth**
Problème actuel : trois endroits où la version est déclarée :
1. `pyproject.toml` → `version = "6.1.5"` (source de vérité Poetry)
2. `veaf_tools/app.py` → fallback hardcodé `"6.1.2"` (désynchronisé !)
3. `veaf-tools-updater.py` → fallback hardcodé `"6.1.5"`

Solution recommandée : dans `veaf_build/worker.py`, lire la version depuis `pyproject.toml` (via `tomllib` stdlib Python 3.11+) et générer un fichier `veaf_tools/_version.py` à la compilation. Les deux modules importent depuis `_version.py` au lieu d'un fallback hardcodé. Au runtime (dev), `importlib.metadata` reste le mécanisme principal ; `_version.py` n'est le fallback que pour l'exe PyInstaller.

**VER-002 — Métadonnées EXE Windows**
Problème : un utilisateur qui fait clic droit → Propriétés sur `veaf-tools.exe` ne voit aucune version dans l'onglet Détails. PyInstaller supporte un fichier `version_file.txt` (format `VSVersionInfo`) référencé dans le `.spec` via `version=`. Générer ce fichier dans `worker.py` depuis la version lue en VER-001 (même code). Les quatre champs `filevers`, `prodvers`, `FileVersion`, `ProductVersion` sont remplis dynamiquement.

**VER-003 — `about` affiche la version**
La commande `about` affiche des informations sur le VEAF et les modules Lua, mais pas la version de l'outil lui-même. Ajouter une ligne `veaf-tools vX.Y.Z` en en-tête (avant l'info VEAF). Exemple :
```
veaf-tools v6.1.5
VEAF — Virtual European Air Force
...
```

</details>

---

## Lot 21 — TYPING: Migrate `Optional[T]` to `X | Y` syntax

**Goal**: Enable ruff `UP007` rule (currently ignored) and migrate the single `Optional[T]` usage to modern `X | Y` union syntax. Update the copilot-instructions override accordingly.
**Branch**: direct commit on `develop-v6` (1-line change, no feature branch needed)

| # | Ticket | File(s) | Type | Effort | Status |
|---|--------|---------|------|--------|--------|
| TYP-001 | Remove `UP007` from ruff ignore list + fix `lua_tests.py:147` + update copilot-instructions override | `pyproject.toml`, `veaf_build/lua_tests.py`, `.github/copilot-instructions.md` | chore | 15 min | ✅ |

**Raw total: 15 min → estimated (×1.15): ~17 min (~20 min)**

<details>
<summary>Ticket details</summary>

**TYP-001 — Enable UP007 and migrate Optional[T]**

Current state: ruff `UP007` is intentionally ignored in `pyproject.toml` with comment `# use X | Y for type union — keep Optional[] for clarity`. There is exactly 1 occurrence of `Optional[T]` in the codebase:
- `veaf_build/lua_tests.py:147`: `suite_filter: Optional[str] = typer.Option(...)`

Steps:
1. In `pyproject.toml`: remove `"UP007",  # use X | Y for type union — keep Optional[] for clarity` from the `[tool.ruff.lint] ignore` list.
2. In `veaf_build/lua_tests.py`: change `Optional[str]` to `str | None` and remove `Optional` from the `from typing import` line (or the whole import if it was the only name).
3. In `.github/copilot-instructions.md`: remove the `Optional[T]` override from the Overrides section (or update it to say `str | None` is the standard).
4. Run `poetry run ruff check .` to verify no remaining UP007 violations.

</details>

---

## Lot 22 — TEST-LAYOUT: Move Python tests to `test/python/`

**Goal**: Move the 28 `test_*.py` files from inside `src/python/veaf-tools/` to `test/python/`, mirroring the existing `test/lua/` convention. Tests live outside the source tree; fixtures stay in `test/veaf-tools/`.
**Branch**: direct commit on `develop-v6` (no logic change — pure reorganization)

| # | Ticket | File(s) | Type | Effort | Status |
|---|--------|---------|------|--------|--------|
| TST-001 | Move 28 `test_*.py` files + update `pyproject.toml` + verify CI passes | `test/python/**`, `pyproject.toml`, `.github/copilot-instructions.md` | chore | 45 min | ✅ |

**Raw total: 45 min → estimated (×1.15): ~52 min (~55 min)**

<details>
<summary>Ticket details</summary>

**TST-001 — Relocate Python tests**

Current state: 28 `test_*.py` files scattered throughout `src/python/veaf-tools/` (colocated with source modules). Target: `test/python/` with the same subdirectory structure, mirroring `test/lua/`.

Target tree (examples):
```
test/python/
  test_version_constraint.py
  mission_builder/
    test_config_migrator.py
    test_v5_converter.py
    test_v5_pipeline_converters.py
  mission_extractor/
    test_mission_extractor_worker.py
  mission_tools/
    test_mission_constants.py
    test_miz_tools.py
  presets_injector/
    test_presets_injector_worker.py
    test_presets.py
  veaf_libs/
    test_config_generator.py
    test_dcs_units_parser.py
    test_i18n.py
    test_lua_module_scanner.py
    test_migrate_lazy_log.py
    test_paths.py
    test_preferences.py
    test_progress.py
    test_tui.py
    test_update_checker.py
    test_user_config.py
  veaf_tools/
    test_helpers.py
  waypoints_injector/
    test_waypoints_injector_worker.py
    test_waypoints_manager.py
  weather_injector/
    test_weather_injector_worker.py
    utils/
      test_lua_converter.py
      test_solar_calculator.py
      test_time_expression_parser.py
    weather/
      test_dcs_weather_converter.py
```

`pyproject.toml` changes:
- `testpaths = ["test/python"]` (was `src/python/veaf-tools`)
- `pythonpath = ["src/python/veaf-tools"]` — unchanged (production code imports)
- `--cov=src/python/veaf-tools` — unchanged (coverage source)
- `[tool.ruff.lint.per-file-ignores]` — update path if needed (`test/python/**`)

Notes:
- `--import-mode=importlib` already in use — no `__init__.py` needed in `test/python/`
- Verify `poetry run pytest` passes after move
- Each subdirectory of `test/python/` may need an empty `__init__.py` depending on how importlib resolves relative imports in tests — check at implementation time

</details>

---

## Phase 0b — GitHub cleanup

Close issues identified during triage. **Verify each one before closing.**
Direct commits on `develop-v6` (no feature branch needed — no code change).

| # | Ticket | Type | Effort | Status |
|---|--------|------|--------|--------|
| CLOSE-001 | Close WONTFIX issues: #55, #146, #147, #180, #193, #246 | chore | 15 min | ⬜ |
| CLOSE-002 | Close STALE issues: #9, #19, #41, #167 | chore | 10 min | ⬜ |

<details>
<summary>Issues to close</summary>

**WONTFIX — Already implemented or out of scope**

| # | Title | Reason |
|---|-------|--------|
| #55 | Faire un système de zone de combat dynamique | Already implemented → `veafCombatZone` |
| #146 | CTLD JTAC 9-line | External project (CTLD/Ciribob) |
| #147 | CTLD JTAC Ask for wind/speed correction | External project (CTLD/Ciribob) |
| #180 | AirWaves - forcer à rester dans la zone | Both tasks already checked ✅ in the issue |
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

## Lot 5 — RELEASE: v6.1.0

**Goal**: Merge v6 to master and publish the official release.
**From**: `develop-v6` directly

| # | Ticket | Type | Effort | Depends on | Status |
|---|--------|------|--------|------------|--------|
| REL-001 | Finalize `CHANGELOG.md` for v6.1.0 | chore | 20 min | Lots 1–4 | ⬜ |
| REL-002 | Write `RELEASE_NOTES.md` for v6.1.0 | chore | 20 min | REL-001 | ⬜ |
| REL-003 | Squash merge `develop-v6` → `master` | chore | 15 min | REL-002 | ⬜ |
| REL-004 | Tag `v6.1.0` + publish GitHub (`veaf-build publish`) | chore | 30 min | REL-003 | ⬜ |

**Estimated total: ~85 min (~1h30)**

---

## Lot 20 — DEEPENING: Architecture deepening Python + Lua

**Goal**: Approfondir l'architecture sur 5 axes identifiés lors de la revue de session `develop-v6`.
- Python : enrichir `DcsMission`, abstraire le traversal coalition/country/group, base class injectors, résolution config builder
- Lua : migrer `veafGroundAI` vers `veafCommands`, restructurer la table d'options spawn
**Branch**: une branche par ticket `feature/deep-xxx` → PR → `develop-v6`

| # | Ticket | File(s) | Type | Effort | Depends on | Status |
|---|--------|---------|------|--------|------------|--------|
| DEEP-001 | `Group` dataclass + `DcsMission.iter_groups()` + tests (`TestIterGroups` synthétique + smoke test sur `test.miz`) | `miz_tools.py`, `__init__.py`, `test_miz_tools.py` | feat | 60 min | — | ✅ |
| DEEP-002 | `DcsMission.get/set_weather()` + `get/set_options()` + migrer `_set_mission_weather()` dans `WeatherInjectorWorker` | `miz_tools.py`, `weather_injector_worker.py` | feat | 30 min | — | ✅ |
| DEEP-003 | Supprimer le traversal dupliqué (coalition/country/group + `human_pilot`) des 3 injectors ; utiliser `mission.iter_groups()` | `presets_injector_worker.py`, `waypoints_injector_worker.py`, `aircrafts_injector_worker.py` | chore | 60 min | DEEP-001 | ✅ (aircraft injector exclu — DCS mock complexity, voir note) |
| DEEP-004 | `GroupInjectorWorker` base class + normaliser `AircraftGroupsInjectorWorker.inject(mode)` → `.work()` avec `mode` dans `__init__` | `veaf_libs/` (nouveau fichier), 3 injectors, `build.py` | feat | 60 min | DEEP-001, DEEP-003 | ✅ (AircraftGroupsInjectorWorker exclu — API publique à préserver, voir note) |
| DEEP-005 | Migrer `veafGroundAI.onEventMarkChange` vers `veafCommands.registerCommandHandler` ; supprimer `veafMarkers.registerEventHandler(MarkerChange, ...)` direct | `veafGroundAI.lua`, `veafCommands.lua` | chore | 30 min | — | ✅ |
| DEEP-006 | Refactor structure `veafSpawnParser.markTextAnalysis()` — defaults communs en tête, defaults spécifiques au type dans leur bloc IF/ELSEIF ; aucun changement comportemental | `veafSpawnParser.lua` | chore | 60 min | — | ✅ |
| DEEP-007 | Déplacer la résolution de config (`dev_mode`, `scripts_path`, `log_modules` → `lua_modules`) dans `MissionBuilderWorker.__init__()` ; `build.py` ne fait que parser les args CLI et appeler le worker | `mission_builder_worker.py`, `build.py` | chore | 60 min | — | ✅ |

**Raw total: 360 min → estimated (×1.15): ~414 min (~6h54)**

<details>
<summary>Ticket details</summary>

**DEEP-001 — `Group` dataclass + `iter_groups()`**

Nouveau dataclass canonique `Group` dans `miz_tools.py` (avant `DcsMission`) :
```python
@dataclass
class Group:
    group_dcs: dict       # raw DCS Lua dict — callers mutent directement
    aircraft_type: str    # "helicopter" | "plane"
    country: str
    coalition: str
    human_pilot: bool = False
    name: str | None = None
    unit_type: str | None = None
```

Nouvelle méthode `DcsMission.iter_groups() -> Iterator[Group]` : générateur traversant `mission_content["coalition"] → country → {"helicopter","plane"} → group`. Peuple `human_pilot` en scannant `unit.skill in ["Client", "Player"]`, `name` depuis `group["name"]`, `unit_type` depuis le premier `unit["type"]`.

Tests ajoutés dans `TestIterGroups` :
- synthétique : `DcsMission` avec `mission_content` construit à la main → assert nombre de groups, `human_pilot`, `aircraft_type`, `coalition`
- smoke test : charger `test/veaf-tools/test.miz` → assert ≥ 1 group retourné

`Group` exporté depuis `mission_tools/__init__.py`.

---

**DEEP-002 — `get/set_weather()` + `get/set_options()`**

Méthodes ajoutées à `DcsMission` :
```python
def get_weather(self) -> dict | None:
    return self.mission_content.get("weather") if self.mission_content else None

def set_weather(self, data: dict) -> None:
    if self.mission_content is not None:
        self.mission_content["weather"] = data

def get_options(self) -> dict | None:
    return self.options_content

def set_options(self, data: dict) -> None:
    self.options_content = data
```

`WeatherInjectorWorker._set_mission_weather()` utilise `self.mission_data.set_weather(weather)` au lieu de l'accès direct au dict.

Note : `_set_mission_time()` et `_set_mission_date()` gardent leurs accès directs (hors scope DEEP-002).

---

## Lot FEAT-GITIGNORE — Template `.gitignore` VEAF MCT dans les defaults

**Goal**: Add a standard `.gitignore` file to `src/defaults/mission-folder/`, copied into the mission folder during `veaf-tools prepare`. This file is never overwritten even with `--force`, since users may have customized it.

**Context**: `prepare.py` copies everything from `src/defaults/mission-folder/` to the target mission folder. New files are copied directly; existing files prompt the user (or are silently overwritten with `--force`). The `.gitignore` is a special case: it must never be overwritten (not even `--force`) to preserve user customizations.

**Branch**: `feature/gitignore-default` → PR → `develop-v6`

| # | Ticket | Files | Type | Effort | Status |
|---|--------|-------|------|--------|--------|
| GITIGNORE-001 | Create `src/defaults/mission-folder/.gitignore` with standard VEAF MCT entries (see content below) | `src/defaults/mission-folder/.gitignore` | feat | 5 min | ⬜ |
| GITIGNORE-002 | In `prepare.py`: add a `NEVER_OVERWRITE` frozenset `{".gitignore"}`. In the copy loop, skip these files if they already exist in the target (no prompt, no `--force` override). Log a `debug` message when skipped | `src/python/veaf-tools/veaf_tools/commands/prepare.py` | feat | 15 min | ⬜ |
| GITIGNORE-003 | Unit test: `prepare` with `--force` does NOT overwrite an existing `.gitignore` in the mission folder | `test/python/test_prepare.py` | chore | 5 min | ⬜ |

**Raw total: 25 min → estimated (×1.15): ~30 min**

<details>
<summary>Ticket details</summary>

**GITIGNORE-001 — `.gitignore` content**

```gitignore
# VEAF Mission Creation Tools — generated/downloaded files (never commit these)

# VEAF tools executables (downloaded by the updater)
/veaf*.exe

# Published VEAF scripts (downloaded by the build pipeline)
/published/

# Build artifacts
/build/
*.miz.bak

# OS / editor noise
.DS_Store
Thumbs.db
```

**GITIGNORE-002 — `prepare.py` change**

```python
NEVER_OVERWRITE: frozenset[str] = frozenset({".gitignore"})

# Inside the copy loop, replace the `if dest_file.exists():` block:
if dest_file.exists():
    if str(relative_path) in NEVER_OVERWRITE:
        logger.debug(f"Never-overwrite: {relative_path}")
        files_skipped += 1
        continue
    # ... existing prompt / force logic unchanged
```

</details>

---

**DEEP-003 — Supprimer traversal dupliqué des injectors**

Dans chaque injector (`presets`, `waypoints`, `aircrafts`) :
- Supprimer la classe `Group` locale (identique à celle de `mission_tools`)
- Supprimer les méthodes `add_group()`, `_process_coalition()`, `_process_country()`, `_process_aircraft_type()` (ou leurs équivalents)
- Réécrire la boucle principale pour itérer via `self.dcs_mission.iter_groups()`
- `waypoints_injector_worker.py` : `group.category` → `group.aircraft_type` (les deux champs étaient identiques, cf. ligne 158 : `category=aircraft_type`)

---

**DEEP-004 — `GroupInjectorWorker` base class**

Nouveau `GroupInjectorWorker(BaseWorker, ABC)` dans `veaf_libs/group_injector_worker.py` :
```python
class GroupInjectorWorker(BaseWorker, ABC):
    def __init__(self, config_file: Path | None, input_mission: Path | None, output_mission: Path | None): ...

    @abstractmethod
    def load_config(self) -> Any: ...

    @abstractmethod
    def process_group(self, group: Group) -> None: ...

    def work(self) -> Path:
        """Read miz, iter_groups, process each group, write miz."""
        ...
```

`PresetsInjectorWorker`, `WaypointsInjectorWorker`, `AircraftGroupsInjectorWorker` héritent de `GroupInjectorWorker`.

`AircraftGroupsInjectorWorker.inject(mode=...)` → renommé `.work()`, `mode` passé dans `__init__`. Appel dans `build.py` mis à jour : `AircraftGroupsInjectorWorker(..., mode=aircraft_mode).work()`.

Note : vérifier à l'implémentation si la logique inject-FROM-YAML de `AircraftGroupsInjectorWorker` s'intègre proprement dans le pattern `process_group` — adapter si besoin.

---

**DEEP-005 — `veafGroundAI` → `veafCommands`**

Dans `veafCommands.lua` : ajouter `veafCommands.PRIORITY_GROUNDAI = 62` (entre MOVE=60 et RADIO=70).

Dans `veafGroundAI.lua`, fonction `initialize()`, remplacer :
```lua
veafMarkers.registerEventHandler(veafMarkers.MarkerChange, veafGroundAI.onEventMarkChange)
```
par :
```lua
veafCommands.registerCommandHandler(function(pos, event, bypass, fromMarker, groups, route)
    if not fromMarker then return false end
    return veafGroundAI.onEventMarkChange(pos, event)
end, veafCommands.PRIORITY_GROUNDAI)
```

La fonction `veafGroundAI.onEventMarkChange` reste publique. Quality gate : stylua + luacheck + test suite Lua.

---

**DEEP-006 — Restructurer table options spawn**

Dans `veafSpawnParser.markTextAnalysis()` (lignes 33–234) :
1. Bloc d'init en tête : garder uniquement les **champs communs** (`czName`, `name`, `unitName`, `country`, `side`, `altitude`, `altitudedelta`, `heading`, `radius`, `multiplier`, `password`, `repeatCount`, `repeatDelay`, `delayedStart`, `hiddenOnMFD`, `AlarmState`, `disperse`).
2. Déplacer les champs spécifiques dans leur bloc IF/ELSEIF de détection, groupés par domaine (`-- ground`, `-- air`, `-- effects`, `-- drawing`, `-- mm`).

Aucun changement comportemental. Quality gate : stylua + luacheck + test suite Lua.

---

**DEEP-007 — Config resolution dans `MissionBuilderWorker`**

Déplacer de `build.py` vers `MissionBuilderWorker.__init__()` :
- Lecture de `mission.yaml` (si `mission_folder / "mission.yaml"` existe)
- Résolution priorité CLI > YAML > défaut : `dev_mode`, `scripts_path`
- Transformation `log_modules` → liste de modules à silencer
- Extraction `lua_modules`, `global_log_level`, `pipeline_cfg` depuis YAML

Nouveaux paramètres du `__init__` : `dev_mode_override: bool | None = None`, `scripts_path_override: str | Path | None = None`, `log_modules_filter: str | None = None`.

Reste dans `build.py` (préoccupations CLI uniquement) :
- `_update_build_config_in_yaml()` (persistance préférences utilisateur)
- Validation de l'existence du dossier mission
- Résolution chemin de sortie (`p_output_mission`)
- Orchestration pipeline (presets, waypoints, aircraft, weather)

`build.py` passe de ~180 lignes à ~100 lignes.

</details>

---

## Lot 24 — DOC-REVIEW: Corrections issues du doc-review

**Goal**: Corriger les inexactitudes et lacunes identifiées lors de la revue manuelle de la documentation (`doc-review.md`) — mauvaises références v5 survivantes en v6, exemples Lua à remplacer par YAML, workflow de build simplifié, prérequis manquants, landing page.

**Context**: Suite à la rédaction initiale de la doc v6, une revue manuelle a identifié plusieurs points : sections `MIGRATION_GUIDE.md` encore en v5, workflow "Typical Build" montrant 4 commandes séparées alors qu'un seul `build` suffit, exemples de configuration en Lua builder-chains au lieu de YAML, prérequis DCS editor manquants, et profil Klogg non committé dans le repo.

**Branch**: `fix/doc-review` → PR → `develop-v6`

| # | Ticket | Fichiers touchés | Type | Effort | Status |
|---|--------|-----------------|------|--------|--------|
| REV-001 | Remplacer `missions.yaml` par `versions.yaml` partout dans la doc et dans le template `mission.yaml` commenté (`lua_config_generator.py` ligne ~839) | `doc/**/*.md`, `src/python/veaf-tools/veaf_libs/lua_config_generator.py`, `src/defaults/mission-folder/mission.yaml` | fix | 20 min | ✅ |
| REV-002 | Committer le profil Klogg fourni par l'utilisateur dans `tools/klogg/veaf.conf` ; mettre à jour la section "Reading the log" dans `GUIDE.md` et `GUIDE.fr.md` pour pointer vers ce fichier | `tools/klogg/veaf.conf`, `doc/mission-maker/GUIDE.md`, `doc/mission-maker/GUIDE.fr.md` | chore | 20 min | ⬜ |
| REV-004 | Corriger `MIGRATION_GUIDE.md` — section "Common Issues" : remplacer les références `missionConfig.lua` par `mission.yaml` + `mission-script.lua` selon le cas ; ajouter entrée "Reading the logs" (Klogg ou Notepad++, chemin `Saved Games\DCS\Logs\dcs.log`, filtre `VEAF`, lien vers profil Klogg committé en REV-002) | `doc/mission-maker/MIGRATION_GUIDE.md`, `doc/mission-maker/MIGRATION_GUIDE.fr.md` | fix | 20 min | ✅ |
| REV-006 | Corriger `GUIDE.md` — "Typical Build Workflow" : remplacer les 4 commandes séparées par `veaf-tools.exe build .` (le pipeline est intégré) ; déplacer les commandes `inject-*` dans une note collapsible "Advanced: running pipeline steps individually" | `doc/mission-maker/GUIDE.md`, `doc/mission-maker/GUIDE.fr.md` | fix | 20 min | ✅ |
| REV-007 | Corriger `doc/index.md` et `doc/index.fr.md` — phrase d'accroche (une ligne orientée nouveau venu avant le tableau role-based) ; passer le diagramme Mermaid de `flowchart LR` à `flowchart TD` | `doc/index.md`, `doc/index.fr.md` | fix | 15 min | ✅ |
| REV-008 | Ajouter prérequis dans `GUIDE.md` et `GUIDE.fr.md` section "Getting Started" : (1) la mission de base dans le DCS Editor **doit** contenir au moins un groupe terrestre bleu et un rouge (requis pour que les tables Lua de pays/coalitions soient complètes et que les outils d'injection fonctionnent) ; (2) éditeur texte recommandé : Notepad++ (YAML/Lua) | `doc/mission-maker/GUIDE.md`, `doc/mission-maker/GUIDE.fr.md` | fix | 20 min | ✅ |
| REV-010 | Corriger `GUIDE.md` — section "CTLD and CSAR Integration" : (1) supprimer la phrase inventée sur l'auto-lasing JTACs dans "VEAF automatic defaults" ; (2) documenter la double approche YAML-first (`external_modules.ctld`) + Lua callback ; (3) noter explicitement que CSAR n'est pas encore configurable via YAML (renvoi vers Lot 25 — EXT-YAML) | `doc/mission-maker/GUIDE.md`, `doc/mission-maker/GUIDE.fr.md` | fix | 30 min | ✅ |

**Raw total: 145 min → estimated (×1.15): ~167 min (~2h45)**

> ~~REV-003~~, ~~REV-005~~, ~~REV-009~~ supprimés — absorbés par DOC-008 (Lot 23).

<details>
<summary>Détails des tickets</summary>

**REV-001 — versions.yaml**
`versions.yaml` est le nom canonique v6. `missions.yaml` est un alias legacy accepté par le code (`_step_file` cherche les deux). Corriger la doc et le commentaire dans `lua_config_generator.py` (ligne ~839 : `"#   weather: true             # src/missions.yaml"`) pour utiliser `versions.yaml` partout.

**REV-002 — Profil Klogg**
L'utilisateur fournira le fichier `.conf` Klogg. Le committer dans `tools/klogg/veaf.conf`. Mettre à jour la phrase dans `GUIDE.md` section "Reading the log" : remplacer la référence au Discord par un lien direct vers le fichier committé.

**REV-003 — Mission Folder Reference v6**
Remplacer l'arborescence actuelle (qui montre `missionConfig.lua` et pas `mission.yaml`) par la structure v6 correcte, puis pointer vers `GUIDE.md` pour la référence complète (éviter duplication).

**REV-004 — Common Issues + logs**
Les entrées "Radio menus don't appear" et "Marker commands don't work" pointent vers `missionConfig.lua` → corriger vers `mission.yaml` / `mission-script.lua`. Nouvelle entrée : comment lire les logs VEAF (chemin, outil, filtre).

**REV-005 — Step 5 vanilla integration**
La section "Configure which modules" montre du Lua `missionConfig.lua` commenté → remplacer par un exemple `mission.yaml` avec `lua_modules:` décommenté et commenté.

**REV-006 — Typical Build Workflow**
Le pipeline `build` intègre déjà presets, waypoints, weather si configurés dans `mission.yaml`. Montrer uniquement `veaf-tools.exe build .`. Les commandes séparées restent disponibles pour les cas avancés (injecter la météo seule, etc.) — les documenter dans une `<details>` collapsible.

**REV-007 — Landing page**
Ajouter une phrase d'accroche avant le tableau role-based, ex. : *"VEAF MCT turns a standard DCS mission into a dynamic, player-driven sandbox — 34 Lua modules, a build pipeline, and a CLI tool that does the heavy lifting."*. Passer `flowchart LR` → `flowchart TD`.

**REV-008 — Prérequis DCS Editor**
Sans groupe bleu et rouge dans le `.miz` de base, les tables `coalition.side.BLUE` et `coalition.side.RED` sont vides en Lua, ce qui peut faire échouer silencieusement les outils d'injection (presets par coalition, waypoints filtrés, etc.). C'est un prérequis technique, pas juste une recommandation.

**REV-009 — Configuration Examples YAML**
Les builder-chains Lua sont l'API bas niveau. En v6, QRA, CombatZone et AirWaves se configurent via `mission.yaml` (`qra:`, `combat_zones:`, `airwave_zones:`). Montrer le YAML en premier ; garder le Lua en `<details>` pour les cas où `mission-script.lua` est préféré.

</details>

---

## Lot 26 — IMC-FEEDBACK: Retours utilisateur tests IMC-Day (v6.2.0)

**Goal**: Traiter les retours terrain remontés lors des tests de migration IMC-Day du 31/05/2026 : UX exe, clarté du dossier backup_v5, fichiers defaults superflus, documentation architecture YAML, filtrage smart des defaults, et investigation du crash `veafCommands nil`.

**Context**: Tests effectués par un utilisateur externe sur v6.2.0 — 11 points remontés. Ce lot traite les 6 points confirmés (P0→P2).

**Branch**: `fix/imc-feedback` → PR → `develop-v6`

| # | Ticket | Fichiers touchés | Type | Effort | Status |
|---|--------|-----------------|------|--------|--------|
| IMC-001 | **Auto-pause smart** : détecter si le process tourne en double-clic (`sys.stdout.isatty()` + détection parent process `explorer.exe` sur Windows) — ne faire la pause qu'en cas de double-clic, pas en CLI/CI | `veaf_tools/commands/build.py`, `veaf_tools/app.py` | fix | 25 min | ✅ |
| IMC-002 | **backup_v5 trompeur** : (B) intégrer le contenu annoté de `missionConfig.lua` directement dans le rapport `convert-v5-report.md` au lieu d'un fichier intermédiaire dans backup_v5 ; (C) créer un `backup_v5/README.txt` expliquant le rôle de chaque fichier présent | `mission_builder/v5_converter.py` | fix | 30 min | ✅ |
| IMC-003 | **Supprimer le README des defaults copiés** : retirer tout fichier `README*` de `published/src/defaults/mission-folder/` — la doc en ligne suffit, les liens internes seraient cassés dans le contexte mission | `published/src/defaults/mission-folder/` | fix | 10 min | ✅ |
| IMC-007 | **Doc architecture YAML** : ajouter dans `MISSION_YAML_REFERENCE.md` (+ `.fr.md`) une section d'introduction distinguant (1) les fichiers du pipeline de build (`waypoints.yaml`, `presets.yaml`, etc.) et (2) la configuration runtime des modules Lua dans `mission.yaml` (`assets`, `shortcuts`, `qra`…) — avec schéma visuel | `doc/MISSION_YAML_REFERENCE.md`, `doc/MISSION_YAML_REFERENCE.fr.md` | doc | 30 min | ✅ |
| IMC-008 | **Filtrage smart des defaults** : dans `complete_src_folder_with_defaults()`, ne copier un fichier default que si le module associé est actif dans `mission.yaml` ; émettre un warning pour tout fichier déjà présent dans le projet dont le module est désactivé ("fichier orphelin") | `mission_builder/mission_builder_worker.py` | fix | 35 min | ✅ |
| IMC-010 | **Investigate + validation version veafCommands** : (1) reproduire l'erreur `veafCommands nil` depuis `veaf-config.lua:19` — identifier mismatch de version ou dépendance manquante ; (2) ajouter dans `veaf.initialize()` une vérification de cohérence entre la version de `veaf-scripts.lua` et `veaf-config.lua` avec message d'erreur explicite | `src/scripts/veaf/veaf.lua`, `src/scripts/veaf/veafCommands.lua` | fix | 45 min | ✅ |

**Raw total: 175 min → estimated (×1.15): ~200 min (~3h20)**

> **Tickets non priorisés** (pour un lot ultérieur si besoin) : IMC-004 (nom mission depuis dossier courant), IMC-005 (profils de build prod/test/dev), IMC-006 (modules obligatoires + groupes + dépendances), IMC-009 (migration dynamic loading), IMC-011 (.gitignore template)

---

## Lot FIX-SORT — LUADATA FIX: Crash tri clés mixtes int/str

**Goal**: Corriger le `TypeError: '<' not supported between instances of 'int' and 'str'` dans `luadata/serializer/serialize.py` lors de la sérialisation de missions DCS contenant des tables Lua avec des clés mixtes (entières et chaînes).

**Context**: Remonté par un utilisateur convertissant une mission v5 avec les VMCT. La fonction `_sort` construisait des tuples de tri `(priority, order, clé)` où la clé pouvait être `int` ou `str`. Quand les deux premiers éléments du tuple sont identiques (cas fréquent : deux clés non-prioritaires → `(1, 0, ?)`), Python tente de comparer le 3ème — ce qui plante si l'un est `int` et l'autre `str`. Fix : convertir la clé en `str` avant de la placer dans le tuple.

**Branch**: `fix/luadata-sort-mixed-keys` → PR → `develop-v6`

| # | Ticket | Fichiers touchés | Type | Effort | Status |
|---|--------|-----------------|------|--------|--------|
| SORT-001 | Convertir la clé en `str` dans `sort_key` de `_sort()` pour éviter la comparaison `int < str` lors du tri de tables Lua avec clés mixtes | `src/python/veaf-tools/luadata/serializer/serialize.py` | fix | 5 min | ✅ |
| SORT-002 | Ajouter un test unitaire : `_sort([1, "name", 2, "type"])` ne lève pas d'exception et retourne une liste triée | `test/python/` | test | 10 min | ✅ |

**Raw total: 15 min → estimated (×1.15): ~17 min (~15 min)**

---

## Lot 25 — EXT-YAML: Support YAML pour les modules externes (CTLD/CSAR)

**Goal**: Étendre `lua_config_generator.py` pour générer la configuration CSAR depuis `mission.yaml`, à l'image de ce qui existe déjà pour CTLD (`external_modules.ctld`). Réduire au maximum la Lua boilerplate nécessaire dans `mission-script.lua` pour les intégrations CTLD/CSAR.

**Context**: CTLD est partiellement configurable via `mission.yaml` (`external_modules.ctld: {enabled: true, hoverPickup: false, ...}`). CSAR ne l'est pas — la config reste 100 % Lua dans `mission-script.lua`. La documentation (`GUIDE.md`) a été corrigée pour refléter l'état actuel ; ce lot implémente la feature manquante puis la doc est mise à jour.

**Branch**: `feature/ext-yaml` → PR → `develop-v6`

| # | Ticket | Fichiers touchés | Type | Effort | Status |
|---|--------|-----------------|------|--------|--------|
| EXT-001 | Ajouter support `external_modules.csar` dans `lua_config_generator.py` : générer `csar.xxx = value` + `csar.initialize()` depuis YAML, symétrique à l'implémentation CTLD existante | `veaf_libs/lua_config_generator.py`, `src/defaults/mission-folder/mission.yaml` | feature | 30 min | ⬜ |
| EXT-002 | Étendre le support CTLD : générer l'appel `ctld.initialize()` depuis YAML (actuellement seules les propriétés sont générées, l'appel `initialize` lui-même reste en Lua) | `veaf_libs/lua_config_generator.py` | feature | 20 min | ⬜ |
| EXT-003 | Tests unitaires pour EXT-001 et EXT-002 : vérifier la génération Lua correcte depuis des configs YAML CTLD/CSAR types (enabled/disabled, propriétés, initialize call) | `test/python/veaf_libs/test_lua_config_generator.py` | test | 40 min | ⬜ |
| EXT-004 | Mettre à jour `GUIDE.md` (+ `.fr.md`) section "CTLD and CSAR Integration" : remplacer les exemples Lua callback par des exemples YAML-first, conserver Lua comme fallback | `doc/mission-maker/GUIDE.md`, `doc/mission-maker/GUIDE.fr.md` | doc | 30 min | ⬜ |

**Raw total: 120 min → estimated (×1.15): ~140 min (~2h20)**

---


---

## Lot 23 — DOC-YAML: Référence YAML complète

**Goal**: Documenter exhaustivement toute la configuration YAML — étapes du pipeline de build et modules Lua — avec tous les champs possibles, leurs types, valeurs par défaut, et un double index (par catégorie et par fréquence d'utilisation).

**Context**: Les docs de modules couvrent uniquement l'API Lua (builder chains). La configuration YAML (`mission.yaml`, `presets.yaml`, `waypoints.yaml`, etc.) n'est référencée que dans les commentaires des fichiers source et dans les strings README des injectors Python. Il n'existe aucune page de référence dédiée dans `doc/`.

Source de vérité : `src/python/veaf-tools/veaf_libs/lua_config_generator.py` (générateur de `veaf-config.lua`) + `src/defaults/mission-folder/mission.yaml` (template annoté) + les `*_README.py` de chaque injector.

**Design decisions** :
- Public primaire : mission makers débutants → exemples minimaux + valeurs par défaut en premier ; référence exhaustive en secondaire via l'index.
- Style : sections rédigées progressives et pédagogiques avec exemples détaillés ; sections référence techniques mais claires.
- `MISSION_YAML_REFERENCE.md` : page hub légère (sections top-level + double index) qui pointe vers les pages de modules. Pas de duplication — chaque module est maître de sa propre doc.
- Traduction : toujours EN + FR — éditer les fichiers existants, créer les `.fr.md` manquants (ex. `veafRadio.fr.md`). Pas de fallback, pas de report.
- Position section YAML dans les docs de modules : après "Enable", avant les sections API. Flux débutant : enable → configure → API avancée.
- Tableau de référence des champs : colonnes `Champ | Type | Défaut | Requis | Description`. Valeurs énumérées dans le bloc YAML commenté, pas dans le tableau.
- `mkdocs.yml` nav : nouvelles pages dans `References` (option A) + dans `Mission Maker → Configuration` (option B) — les deux. Labels : `mission.yaml Reference` → `MISSION_YAML_REFERENCE.md` ; `Pipeline Reference` → `PIPELINE_REFERENCE.md`. FR : `Référence mission.yaml` / `Référence Pipeline`.
- `PIPELINE_REFERENCE.md` scope : section `pipeline:` de `mission.yaml` (activation/config des étapes) + schémas YAML des fichiers externes (`presets.yaml`, `waypoints.yaml`, `aircraft-templates.yaml`, `versions.yaml`).
- DOC-008 scope : couvre tous les `doc/**/*.md` (inclus `GUIDE.md`, `MIGRATION_GUIDE.md`) — absorbe REV-003, REV-005, REV-009 de Lot 24.

**Branch**: `feature/doc-yaml-reference` → PR → `develop-v6`

| # | Ticket | Fichiers touchés | Type | Effort | Status |
|---|--------|-----------------|------|--------|--------|
| DOC-001 | Créer `doc/PIPELINE_REFERENCE.md` (+ `.fr.md`) : référence complète des 4 étapes du pipeline de build (`presets`, `waypoints`, `aircraft_groups`, `weather`) avec schéma YAML complet pour chacune, et documentation de la section `pipeline:` de `mission.yaml` (activation, chemin fichier, mode add/replace) | `doc/PIPELINE_REFERENCE.md`, `doc/PIPELINE_REFERENCE.fr.md` | doc | 60 min | ✅ |
| DOC-002 | Créer `doc/MISSION_YAML_REFERENCE.md` (+ `.fr.md`) : référence des sections top-level de `mission.yaml` (`mission:`, `global_log_level`, `security:`, `settings:`, `external_modules:`, `veaf_tools:`) + squelette du double index par catégorie et par fréquence d'utilisation | `doc/MISSION_YAML_REFERENCE.md`, `doc/MISSION_YAML_REFERENCE.fr.md` | doc | 45 min | ✅ |
| DOC-003 | Ajouter section "Configuration (`mission.yaml`)" dans les docs des modules à config simple : `veafRadio.md`, `veafShortcuts.md`, `veafNamedPoints.md`, `veafCarrierOperations.md` (+ `.fr.md` correspondants, créer si manquants). Champs : `enable`, `logLevel`, plus `init.help_menus` (RADIO), `init.include_carrier_operations_radio` (CARRIER), `custom_points[]` (NAMEDPOINTS), `shortcuts[]` (SHORTCUTS) | `doc/mission-maker/scripts/veafRadio.md`, `veafShortcuts.md`, `veafNamedPoints.md`, `veafCarrierOperations.md` (+ `.fr.md`) | doc | 60 min | ✅ |
| DOC-004 | Ajouter section YAML dans `veafAssets.md` et `veafSanctuary.md` (+ `.fr.md`) : `assets[]` avec tous les sous-champs (sort, name, description, information, linked, jtac, freq, mod) ; `sanctuary_zones[]` avec tous les sous-champs (polygon_units, coalition, delay_warning, delay_spawn, delay_instant, protect_from_missiles) | `doc/mission-maker/scripts/veafAssets.md`, `veafSanctuary.md` (+ `.fr.md`) | doc | 45 min | ✅ |
| DOC-005 | Ajouter section YAML dans `veafCombatZone.md` et `veafAirWaves.md` (+ `.fr.md`) : schémas complexes — `combat_zone_settings`, `combat_zones[]` (type zone/operation, chained_zones, tasking_orders), `airwave_zones[]` (toute la liste de champs : player_coalitions, waves[], messages, min/max altitudes, delays, etc.) | `doc/mission-maker/scripts/veafCombatZone.md`, `veafAirWaves.md` (+ `.fr.md`) | doc | 90 min | ✅ |
| DOC-006 | Ajouter section YAML dans `veafQraManager.md` (+ `.fr.md`) : section top-level `qra:` complète (silence_all, definitions[] avec tous les sous-champs : coalition, enemy_coalitions, trigger_zone, simple_groups, groups_by_enemy_count, delay_before_rearming, delay_before_activating, react_on_helicopters, airport_link) + documenter les sections top-level `cap_missions:` et `combat_missions:` dans `veafCasMission.md` (+ `.fr.md`) | `doc/mission-maker/scripts/veafQraManager.md`, `veafCasMission.md` (+ `.fr.md`) | doc | 60 min | ✅ |
| DOC-007 | Compléter `doc/MISSION_YAML_REFERENCE.md` (+ `.fr.md`) avec le double index final : index par **catégorie** (Core, Security, Combat, Air Defense, Assets & Support, Build Pipeline) et par **fréquence d'utilisation** (Essentiel — toute mission / Courant — la plupart des missions / Avancé — cas spécifiques). Chaque entrée pointe vers la section de référence correspondante. | `doc/MISSION_YAML_REFERENCE.md`, `doc/MISSION_YAML_REFERENCE.fr.md` | doc | 30 min | ✅ |
| DOC-008 | **Audit global missionConfig.lua** : (1) grep tous les fichiers `doc/**/*.md` pour les références à `missionConfig.lua` — remplacer par une note "ce fichier n'existe plus en v6, voir `mission.yaml`" ; (2) convertir les exemples de configuration encore écrits en syntaxe Lua (ex: `veaf.config.XXX = yyy`, builder chains dans les docs) en équivalent YAML ; (3) vérifier qu'aucun exemple de `do file()` ou de trigger DCS Editor ne reste dans la doc comme instruction à suivre. | `doc/**/*.md` | doc | 45 min | ✅ |

**Raw total: 435 min → estimated (×1.15): ~500 min (~8h20)**

<details>
<summary>Détails des tickets</summary>

**DOC-001 — Pipeline steps reference**

Les 4 étapes du pipeline injectent des données dans le `.miz` au moment du build. Leurs schémas YAML vivent dans des fichiers séparés (pas dans `mission.yaml`) et sont actuellement documentés uniquement dans les `*_README.py` Python :

- `presets`: `src/presets.yaml` → `radios_collection:`, `presets_collection:`, `presets_assignments:`, `channels_collection:`
- `waypoints`: `src/waypoints.yaml` → `waypoints:` (champs : type, action, alt, alt_type, speed, speed_type, x, y) + `settings:` (matching par type/category/coalition)
- `aircraft_groups`: `src/aircraft-templates.yaml` → `airplanes:` / `helicopters:` avec coalitions > pays > groupe > units[]
- `weather`: `src/missions.yaml` (ou `versions.yaml`) → `position:`, `base_date:`, `versions[]` (name, time, date, metar, weather{})

La section `pipeline:` de `mission.yaml` contrôle l'activation de chaque étape :
```yaml
pipeline:
  presets: true               # true | false | {file: path, mode: add|replace}
  waypoints: true
  aircraft_groups:
    file: src/my-aircraft.yaml
    mode: add                 # add (default) | replace
  weather: false
```

**DOC-002 — Top-level mission.yaml structure**

Sections top-level à documenter avec tous les champs :

| Section | Champs | Notes |
|---------|--------|-------|
| `global_log_level:` | error/warning/info/debug/trace | Override global de tous les modules |
| `mission:` | name, export_path, era (MODERN/COLD_WAR/WW2), language | Identité de la mission |
| `security:` | disabled, password_hashes[], password_mm_hashes[] | Hashes SHA-256 |
| `settings:` | clés arbitraires | → `veaf.config.KEY = value` |
| `external_modules:` | skynet.{enabled, include_red/blue_in_radio, debug_red/blue}, ctld.{enabled, ...} | Modules tiers |
| `veaf_tools:` | version | Contrainte semver : "6", "6.1", "^6.1.3", "~6.1.3" |

**DOC-003 — Modules simples**

Chaque doc doit avoir une section `## Configuration (mission.yaml)` avec :
1. Un bloc YAML montrant toutes les clés possibles avec commentaires inline
2. Un tableau de référence des champs
3. Un exemple minimal

RADIO : `init.help_menus: bool` (défaut : true)
CARRIER : `init.include_carrier_operations_radio: bool` (défaut : true)
NAMEDPOINTS : `custom_points[]` avec name, lat (string), lon (string)
SHORTCUTS : `shortcuts[]` avec name, description, command (ex: `/_smoke`), bypass_security (défaut: false)

**DOC-005 — AIRWAVES (schéma complet)**

Champs de `airwave_zones[]` à documenter exhaustivement :
```yaml
- name: string
  description: string           # optionnel
  start: boolean                # défaut: false
  player_coalitions: [BLUE|RED]
  zone_center_coordinates: string  # format "N41°00'00\" E044°00'00\""
  trigger_zone_name: string     # OU zone_center_coordinates + zone_radius
  zone_radius: number           # mètres
  draw_zone: boolean
  respawn_default_offset: [lat_delta_m, lon_delta_m]
  respawn_radius: number
  delay_before_activation: number
  delay_between_waves: number
  min_seconds_between_waves: number
  max_seconds_between_waves: number
  max_altitude_ft: number
  min_altitude_ft: number
  max_seconds_outside_ia: number
  minimum_life_percent: number
  reset_when_dying: boolean
  message_start: string
  message_wait_for_humans: string
  message_wave_deployed: string
  message_end_zone: string
  message_end_all: string
  waves:
    - groups: string            # nom de groupe ou liste séparée par espaces
      delay: number             # -1 = concurrent avec le suivant
      number: string            # "1-3" = pick aléatoire entre 1 et 3
      bias: number              # 0 = uniforme
```

**DOC-007 — Double index**

Index par **catégorie** :
- **Core** : `mission:`, `global_log_level`, `settings:`, `veaf_tools:`
- **Security** : `security:`, module SECURITY
- **Combat** : COMBATZONE, AIRWAVES, QRA, modules CAP/COMBATMISSION, CASMISSION, TRANSPORTMISSION
- **Air Defense** : SKYNET, SANCTUARY, MISSILEGUARDIAN
- **Assets & Support** : ASSETS, CARRIER, NAMEDPOINTS, RADIO, SHORTCUTS
- **Build Pipeline** : presets, waypoints, aircraft_groups, weather

Index par **fréquence d'utilisation** :
- **Essentiel** (toute mission) : `mission:`, `security:`, `global_log_level`, RADIO, ASSETS, pipeline.presets/waypoints
- **Courant** (la plupart des missions) : SHORTCUTS, NAMEDPOINTS, QRA, COMBATZONE, CARRIER
- **Avancé** (cas spécifiques) : AIRWAVES, SANCTUARY, MISSILEGUARDIAN, SKYNET, `external_modules:`, `veaf_tools:`

**DOC-008 — Audit global missionConfig.lua**

`missionConfig.lua` était le fichier de configuration v5 (syntaxe Lua). Il a été remplacé par `mission.yaml` en v6. La doc doit refléter ce changement :

1. **Grep exhaustif** — chercher dans tous les `doc/**/*.md` :
   - `missionConfig.lua` → remplacer par note "Ce fichier n'existe plus en v6. Voir `mission.yaml`."
   - `veaf.config.XXX = yyy` (syntaxe Lua de config) → convertir en équivalent `settings: { XXX: yyy }` YAML
   - Exemples de builder chains dans un contexte de "configuration de mission" (vs API de développement) → convertir en YAML
   - Instructions "ouvrir l'éditeur DCS et ajouter un trigger DO SCRIPT FILE" comme procédure de config → corriger (le build génère les triggers automatiquement)

2. **Conserver** les exemples Lua dans les docs API (LUA_API_REFERENCE.md, docs de scripts) quand ils montrent l'utilisation de l'API elle-même — seuls les exemples de *configuration de mission* passent en YAML.

3. **Vérifier spécifiquement** : `doc/mission-maker/GUIDE.md`, `doc/mission-maker/GUIDE.fr.md`, `doc/index.md`, `doc/index.fr.md`, `README.md`.

</details>
