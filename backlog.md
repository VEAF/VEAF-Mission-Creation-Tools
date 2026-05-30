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
| Lot 20 — DEEPENING | ~7h | ⬜ |
| Lot 21 — TYPING | ~20 min | ✅ |
| Lot 22 — TEST-LAYOUT | ~55 min | ✅ |
| Lot 23 — DOC-YAML | ~8h20 | ⬜ |
| Lot 24 — DOC-REVIEW | ~2h45 | ⬜ |
| Lot 25 — EXT-YAML | ~2h | ⬜ |
| **Total** | **~157h05** | |

*Initial calibration factor: 1.15 — recalculate after each completed lot.*

---

## Lot 19 — MIGRATOR: Audit et complétion de la conversion missionConfig.lua

**Goal**: Vérifier que `ConfigMigrator` gère correctement toutes les constructions Lua réelles d'un `missionConfig.lua` v5 ; combler les lacunes de tests ; corriger les régressions trouvées.
**Context**: `ConfigMigrator` contient 12 méthodes `_extract_*` mais seulement 4 sont couvertes par des tests unitaires. Aucun test d'intégration n'existe à ce jour malgré la présence de fixtures réelles dans `test/veaf-tools/`.
**Branch**: `fix/migrator-coverage` → PR → `develop-v6`

| # | Ticket | Fichiers touchés | Type | Effort | Status |
|---|--------|-----------------|------|--------|--------|
| MIG-001 | Test d'intégration end-to-end — faire tourner `ConfigMigrator.migrate()` sur les fixtures réelles (`test/veaf-tools/mission-builder/src/scripts/missionConfig.lua` et `test/veaf-tools/demo-mission/src/scripts/missionConfig.lua`) et vérifier qu'aucune exception n'est levée et que les modules attendus sont bien détectés | `mission_builder/test_config_migrator.py` | chore | 30 min | ⬜ |
| MIG-002 | Ajouter des tests unitaires pour les 8 extracteurs non couverts : `_extract_identity_and_security`, `_extract_combat_missions`, `_extract_shortcuts`, `_extract_named_points`, `_extract_sanctuary_zones`, `_extract_combat_zone_settings`, `_extract_combat_zones`, `_extract_airwaves_zones`, `_extract_security_mm` | `mission_builder/test_config_migrator.py` | chore | 60 min | ⬜ |
| MIG-003 | Corriger les bugs trouvés lors de MIG-001/MIG-002 (régressions, patterns non couverts) | `mission_builder/config_migrator.py` | fix | 60 min | ⬜ |

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
| DEEP-001 | `Group` dataclass + `DcsMission.iter_groups()` + tests (`TestIterGroups` synthétique + smoke test sur `test.miz`) | `miz_tools.py`, `__init__.py`, `test_miz_tools.py` | feat | 60 min | — | ⬜ |
| DEEP-002 | `DcsMission.get/set_weather()` + `get/set_options()` + migrer `_set_mission_weather()` dans `WeatherInjectorWorker` | `miz_tools.py`, `weather_injector_worker.py` | feat | 30 min | — | ⬜ |
| DEEP-003 | Supprimer le traversal dupliqué (coalition/country/group + `human_pilot`) des 3 injectors ; utiliser `mission.iter_groups()` | `presets_injector_worker.py`, `waypoints_injector_worker.py`, `aircrafts_injector_worker.py` | chore | 60 min | DEEP-001 | ⬜ |
| DEEP-004 | `GroupInjectorWorker` base class + normaliser `AircraftGroupsInjectorWorker.inject(mode)` → `.work()` avec `mode` dans `__init__` | `veaf_libs/` (nouveau fichier), 3 injectors, `build.py` | feat | 60 min | DEEP-001, DEEP-003 | ⬜ |
| DEEP-005 | Migrer `veafGroundAI.onEventMarkChange` vers `veafCommands.registerCommandHandler` ; supprimer `veafMarkers.registerEventHandler(MarkerChange, ...)` direct | `veafGroundAI.lua`, `veafCommands.lua` | chore | 30 min | — | ⬜ |
| DEEP-006 | Refactor structure `veafSpawnParser.markTextAnalysis()` — defaults communs en tête, defaults spécifiques au type dans leur bloc IF/ELSEIF ; aucun changement comportemental | `veafSpawnParser.lua` | chore | 60 min | — | ⬜ |
| DEEP-007 | Déplacer la résolution de config (`dev_mode`, `scripts_path`, `log_modules` → `lua_modules`) dans `MissionBuilderWorker.__init__()` ; `build.py` ne fait que parser les args CLI et appeler le worker | `mission_builder_worker.py`, `build.py` | chore | 60 min | — | ⬜ |

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
| REV-001 | Remplacer `missions.yaml` par `versions.yaml` partout dans la doc et dans le template `mission.yaml` commenté (`lua_config_generator.py` ligne ~839) | `doc/**/*.md`, `src/python/veaf-tools/veaf_libs/lua_config_generator.py`, `src/defaults/mission-folder/mission.yaml` | fix | 20 min | ⬜ |
| REV-002 | Committer le profil Klogg fourni par l'utilisateur dans `tools/klogg/veaf.conf` ; mettre à jour la section "Reading the log" dans `GUIDE.md` et `GUIDE.fr.md` pour pointer vers ce fichier | `tools/klogg/veaf.conf`, `doc/mission-maker/GUIDE.md`, `doc/mission-maker/GUIDE.fr.md` | chore | 20 min | ⬜ |
| REV-004 | Corriger `MIGRATION_GUIDE.md` — section "Common Issues" : remplacer les références `missionConfig.lua` par `mission.yaml` + `mission-script.lua` selon le cas ; ajouter entrée "Reading the logs" (Klogg ou Notepad++, chemin `Saved Games\DCS\Logs\dcs.log`, filtre `VEAF`, lien vers profil Klogg committé en REV-002) | `doc/mission-maker/MIGRATION_GUIDE.md`, `doc/mission-maker/MIGRATION_GUIDE.fr.md` | fix | 20 min | ⬜ |
| REV-006 | Corriger `GUIDE.md` — "Typical Build Workflow" : remplacer les 4 commandes séparées par `veaf-tools.exe build .` (le pipeline est intégré) ; déplacer les commandes `inject-*` dans une note collapsible "Advanced: running pipeline steps individually" | `doc/mission-maker/GUIDE.md`, `doc/mission-maker/GUIDE.fr.md` | fix | 20 min | ⬜ |
| REV-007 | Corriger `doc/index.md` et `doc/index.fr.md` — phrase d'accroche (une ligne orientée nouveau venu avant le tableau role-based) ; passer le diagramme Mermaid de `flowchart LR` à `flowchart TD` | `doc/index.md`, `doc/index.fr.md` | fix | 15 min | ⬜ |
| REV-008 | Ajouter prérequis dans `GUIDE.md` et `GUIDE.fr.md` section "Getting Started" : (1) le mission de base dans le DCS Editor **doit** contenir au moins un groupe terrestre bleu et un rouge (requis pour que les tables Lua de pays/coalitions soient complètes et que les outils d'injection fonctionnent) ; (2) éditeur texte recommandé : Notepad++ (YAML/Lua) | `doc/mission-maker/GUIDE.md`, `doc/mission-maker/GUIDE.fr.md` | fix | 20 min | ⬜ |
| REV-010 | Corriger `GUIDE.md` — section "CTLD and CSAR Integration" : (1) supprimer la phrase inventée sur l'auto-lasing JTACs dans "VEAF automatic defaults" ; (2) documenter la double approche YAML-first (`external_modules.ctld`) + Lua callback ; (3) noter explicitement que CSAR n'est pas encore configurable via YAML (renvoi vers Lot 25 — EXT-YAML) | `doc/mission-maker/GUIDE.md`, `doc/mission-maker/GUIDE.fr.md` | fix | 30 min | ⬜ |

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
