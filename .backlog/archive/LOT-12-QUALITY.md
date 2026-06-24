# Lot 12 — QUALITY: Nettoyage, consolidation et qualité du code

Status: ✅ done

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
