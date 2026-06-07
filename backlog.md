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
| Lot 18 — VERSIONING | ~1h45 | [archived](backlog-archive.md) |
| Lot 19 — MIGRATOR | ~2h30 | [archived](backlog-archive.md) |
| Lot 20 — DEEPENING | ~7h | [archived](backlog-archive.md) |
| Lot 21 — TYPING | ~20 min | [archived](backlog-archive.md) |
| Lot 22 — TEST-LAYOUT | ~55 min | [archived](backlog-archive.md) |
| Lot 23 — DOC-YAML | ~8h20 | [archived](backlog-archive.md) |
| Lot 24 — DOC-REVIEW | ~2h45 | ⬜ (REV-002 en attente) |
| Lot 25 — EXT-YAML | ~2h | [archived](backlog-archive.md) |
| Lot FIX-SORT — LUADATA FIX | ~15 min | [archived](backlog-archive.md) |
| Lot 26 — IMC-FEEDBACK | ~2h40 | [archived](backlog-archive.md) |
| Lot FIX-BUNDLE — VEAFCOMMANDS MISSING | ~10 min | [archived](backlog-archive.md) |
| Lot FIX-ASSETS-NEWLINE — ASSETS newline in Lua string | ~20 min | [archived](backlog-archive.md) |
| Lot FIX-WEATHER-ALIAS — missions.yaml + versions.yaml coexistence | ~25 min | [archived](backlog-archive.md) |
| Lot FIX-MISSIONCONFIG-BAK — supprimer extension .bak inutile | ~20 min | [archived](backlog-archive.md) |
| Lot FIX-README-COPY — ne plus copier presets.md dans src/ | ~10 min | [archived](backlog-archive.md) |
| Lot FIX-AIRCRAFT-ORPHAN — alerte fichier orphelin manquante pour aircraft-templates.yaml | ~15 min | [archived](backlog-archive.md) |
| Lot DOC-DEV-MODE — documenter dev_mode + scripts_path | ~30 min | [archived](backlog-archive.md) |
| Lot FEAT-PROFILES — profils de build dans mission.yaml | ~3h | [archived](backlog-archive.md) |
| Lot FEAT-MODULE-UX — Catégories, modules obligatoires, dépendances | ~2h | [archived](backlog-archive.md) |
| Lot FEAT-GITIGNORE — Template `.gitignore` VEAF MCT dans les defaults | ~25 min | [archived](backlog-archive.md) |
| Lot FIX-OLDSCRIPTS — Détection fichiers .lua résiduels dans src/scripts/ | ~45 min | ✅ |
| Lot FIX-MARKERS-INIT — Ajout de `veafMarkers.initialize()` manquante | ~5 min | ✅ |
| Lot FIX-MISSING-INIT — `initialize()` manquante sur 4 modules Lua | ~20 min | ✅ |
| Lot 27 — DOC-FR-MERGE | ~6h | ✅ |
| Lot FIX-YAML-SYNTAX — Erreur YAML non gérée dans build et mission_builder_worker | ~15 min | ✅ |
| Lot FIX-MANDATORY-ENABLE — Bloquer enable sur les modules obligatoires | ~20 min | ✅ |
| Lot FEAT-CUSTOM-SCRIPTS — Section custom_scripts dans mission.yaml | ~45 min | ✅ |
| Lot FIX-REMOVE-CONVERT — Suppression de la commande `convert` | ~20 min | ✅ |
| Lot FIX-MISSIONCONFIG-REFS — Références à `missionConfig.lua` dans doc et code | ~30 min | ✅ |
| **Total** | **~175h35** | |

*Initial calibration factor: 1.15 — recalculate after each completed lot.*

---

## Lot FIX-MISSIONCONFIG-REFS — Références à `missionConfig.lua` dans doc et code

**Goal**: Remplacer toutes les références utilisateur à `missionConfig.lua` par le nom v6 correct (`mission-script.lua` pour le code custom, `mission.yaml` pour la config).

**Branch**: `fix/remove-convert-command` → PR #371 → `develop-v6`

| # | Ticket | Files | Type | Effort | Status |
|---|--------|-------|------|--------|--------|
| MCR-001 | Corriger `veafQraManager.md/en.md` : section "Via missionConfig.lua" | `doc/mission-maker/scripts/` | doc | 5 min | ✅ |
| MCR-002 | Corriger `veafSkynetIadsHelper.md/en.md` : prérequis et titre de section | `doc/mission-maker/scripts/` | doc | 5 min | ✅ |
| MCR-003 | Corriger arborescences dans `mission_builder_README.py` et `mission_extractor_README.py` | `src/python/veaf-tools/` | doc | 5 min | ✅ |
| MCR-004 | Corriger commentaires AIEN/CTLD/CSAR dans `veaf.lua` | `src/scripts/veaf/veaf.lua` | chore | 5 min | ✅ |
| MCR-005 | Corriger fixtures de test (`veafDynamicConfig.lua`, `mapResource`) | `test/veaf-tools/` | chore | 10 min | ✅ |

---

## Lot FIX-REMOVE-CONVERT — Suppression de la commande `convert`

**Goal**: Retirer la commande `convert` qui est cassée sur les missions v6 (crash sur `missionConfig.lua` inexistant) et dont le rôle est couvert par `extract` + `build`.

**Branch**: `fix/remove-convert-command` → PR #371 → `develop-v6`

| # | Ticket | Files | Type | Effort | Status |
|---|--------|-------|------|--------|--------|
| RMC-001 | Supprimer `commands/convert.py` et le package `mission_converter/` | `src/python/veaf-tools/` | chore | 5 min | ✅ |
| RMC-002 | Retirer l'entrée TUI et les clés de locale `cmd.convert.*` | `tui.py`, `en.json`, `fr.json` | chore | 10 min | ✅ |
| RMC-003 | Retirer l'assertion de test correspondante | `test/python/veaf_libs/test_tui.py` | test | 5 min | ✅ |

---

## Lot FEAT-CUSTOM-SCRIPTS — Section custom_scripts dans mission.yaml

**Goal**: Permettre de déclarer des scripts Lua custom dans `mission.yaml` pour supprimer les warnings et contrôler la génération du trigger DCS de chargement.

**Branch**: `feature/custom-scripts` → PR → `develop-v6`

| # | Ticket | Files | Type | Effort | Status |
|---|--------|-------|------|--------|--------|
| CUSTOM-001 | Ajouter `CustomScript` dataclass + parsing `custom_scripts` dans `__init__` | `mission_builder_worker.py` | feat | 10 min | 🔄 |
| CUSTOM-002 | Mettre à jour la logique de warning (déclaré = info, inconnu = warning avec hint) | `mission_builder_worker.py` | feat | 10 min | 🔄 |
| CUSTOM-003 | Filtrer les triggers de chargement selon `generate_load_trigger` | `mission_builder_worker.py` | feat | 10 min | 🔄 |
| CUSTOM-004 | Tests TDD (warnings + trigger resolution) | `test_mission_builder_defaults.py` | test | 10 min | 🔄 |
| CUSTOM-005 | Documenter la section dans `mission.yaml` par défaut | `src/defaults/mission-folder/mission.yaml` | doc | 5 min | 🔄 |

---

## Lot FIX-MISSING-INIT — `initialize()` manquante sur 4 modules Lua

**Goal**: Corriger les crashes DCS runtime `attempt to call field 'initialize' (a nil value)` sur les modules non encore couverts.

**Context**: Le build Python (`lua_config_generator.py`) génère un appel `<module>.initialize()` pour tous les modules listés dans `_MODULE_INIT_ORDER`. Audit complet révèle 4 modules sans cette fonction : `veafCacheManager`, `veafTime`, `veafUnits`, `veafSkynetIadsMonitor`.

**Branch**: `fix/missing-initialize-fns` → PR → `develop-v6`

| # | Ticket | Files | Type | Effort | Status |
|---|--------|-------|------|--------|--------|
| MISSING-INIT-001 | Ajouter `initialize()` dans `veafCacheManager.lua` | `src/scripts/veaf/veafCacheManager.lua` | fix | 5 min | ✅ |
| MISSING-INIT-002 | Ajouter `initialize()` dans `veafTime.lua` | `src/scripts/veaf/veafTime.lua` | fix | 5 min | ✅ |
| MISSING-INIT-003 | Ajouter `initialize()` dans `veafUnits.lua` | `src/scripts/veaf/veafUnits.lua` | fix | 5 min | ✅ |
| MISSING-INIT-004 | Ajouter `initialize()` dans `veafSkynetIadsMonitor.lua` | `src/scripts/veaf/veafSkynetIadsMonitor.lua` | fix | 5 min | ✅ |

---

## Lot FIX-MARKERS-INIT — Ajout de `veafMarkers.initialize()` manquante

**Goal**: Corriger l'erreur DCS runtime `attempt to call field 'initialize' (a nil value)` sur `veafMarkers`.

**Context**: La fonction `initialize()` était absente de `veafMarkers.lua` alors que `veaf-config.lua` l'appelle systématiquement. Le module était déjà auto-initialisé au chargement ; la fonction ajoutée se contente de logger.

**Branch**: commit direct sans branche (fix minimal, testé par l'utilisateur)

| # | Ticket | Files | Type | Effort | Status |
|---|--------|-------|------|--------|--------|
| MARKERS-INIT-001 | Ajouter `veafMarkers.initialize()` dans `src/scripts/veaf/veafMarkers.lua` | `src/scripts/veaf/veafMarkers.lua` | fix | 5 min | ✅ |

---

## Lot FIX-OLDSCRIPTS — Détection fichiers .lua résiduels dans src/scripts/

**Goal**: Détecter les fichiers `.lua` résiduels v5 dans `src/scripts/` d'une mission convertie et émettre un avertissement au build.

**Context**: Le bug original (`veafCommands nil`) a été résolu par Lot FIX-BUNDLE. Cause secondaire potentielle non traitée : des fichiers VEAF `.lua` v5 individuels encore présents dans `src/scripts/` pourraient être chargés via le glob `src/scripts/*.lua` et créer des conflits au runtime DCS. OLDSCRIPTS-002 peut être implémenté indépendamment de l'investigation.

**Branch**: `fix/oldscripts-detection` → PR → `develop-v6`

| # | Ticket | Files | Type | Effort | Status |
|---|--------|-------|------|--------|--------|
| OLDSCRIPTS-000 | Investigation : reproduire le bug avec une vraie mission v5→v6 ; obtenir les logs DCS complets ; identifier le fichier responsable | — | chore | 15 min | ✅ (résolu — voir contexte) |
| OLDSCRIPTS-001 | Fix : selon le résultat de l'investigation, corriger la cause racine identifiée | TBD | fix | TBD | ✅ (résolu par FIX-BUNDLE) |
| OLDSCRIPTS-002 | Ajouter un warning si des fichiers `.lua` inattendus sont présents dans `src/scripts/` (i.e. non listés explicitement dans `get_mission_script_files()`) | `mission_tools/mission_constants.py` ou `mission_builder_worker.py` | fix | 15 min | ✅ |

**Raw total: ~45 min estimé (hors investigation)**

---

## Lot 27 — DOC-FR-MERGE: Français par défaut + merge contenu v5

**Goal**: Passer le français en langue par défaut de la documentation MkDocs et enrichir les pages v6 avec le contenu conceptuel manquant issu de la documentation v5 (écrite manuellement).

**Branch**: `feature/doc-fr-default-and-v5-merge` → PR → `develop-v6`

| # | Ticket | Fichiers touchés | Type | Effort | Status |
|---|--------|-----------------|------|--------|--------|
| DOC-FR-001 | Renommer `*.md` → `*.en.md` et `*.fr.md` → `*.md` (35 paires) | `doc/**` | chore | 15 min | ✅ |
| DOC-FR-002 | Mettre à jour `mkdocs.yml` : FR défaut, EN secondaire | `mkdocs.yml` | chore | 10 min | ✅ |
| DOC-FR-003 | Merge contenu v5 → `veafQraManager.md` (FR + EN) | `doc/mission-maker/scripts/veafQraManager.*` | chore | 45 min | ✅ |
| DOC-FR-004 | Merge contenu v5 → `veafCombatZone.md` (FR + EN) | `doc/mission-maker/scripts/veafCombatZone.*` | chore | 45 min | ✅ |
| DOC-FR-005 | Merge contenu v5 → `veafAirWaves.md` (FR + EN) | `doc/mission-maker/scripts/veafAirWaves.*` | chore | 30 min | ✅ (v6 déjà complet) |
| DOC-FR-006 | Merge contenu v5 → `veafRadio.md` (FR + EN) | `doc/mission-maker/scripts/veafRadio.*` | chore | 20 min | ✅ |
| DOC-FR-007 | Merge contenu v5 → `veafSkynetIadsHelper.md` (FR + EN) | `doc/mission-maker/scripts/veafSkynetIadsHelper.*` | chore | 20 min | ✅ |
| DOC-FR-008 | Merge contenu v5 → `veafWeather.md` (FR + EN) | `doc/mission-maker/scripts/veafWeather.*` | chore | 20 min | ✅ |
| DOC-FR-009 | Vérifier `presets.md` v5 et identifier l'équivalent v6 | TBD | chore | 15 min | ✅ (déjà dans GUIDE.md) |

---

## Lot FIX-YAML-SYNTAX — Erreur YAML non gérée dans build et mission_builder_worker

**Goal**: Intercepter les erreurs de syntaxe YAML dans `mission.yaml` pour afficher un message clair au lieu d'un traceback Python.

**Context**: Un `yaml.YAMLError` non géré dans `build.py` (peek du nom) et `mission_builder_worker.py` (chargement complet) causait un crash avec traceback. Le message d'erreur natif de PyYAML (fichier, ligne, colonne, contexte) est propagé via `logger.error`.

**Branch**: `fix/yaml-syntax-error` → PR → `develop-v6`

| # | Ticket | Files | Type | Effort | Status |
|---|--------|-------|------|--------|--------|
| YAML-SYNTAX-001 | Gérer `yaml.YAMLError` dans `build.py` (peek mission name) | `src/python/veaf-tools/veaf_tools/commands/build.py` | fix | 5 min | ✅ |
| YAML-SYNTAX-002 | Gérer `yaml.YAMLError` dans `mission_builder_worker.py` (chargement complet) | `src/python/veaf-tools/mission_builder/mission_builder_worker.py` | fix | 5 min | ✅ |

---

## Lot 24 — DOC-REVIEW: Klogg profile (REV-002)

**Goal**: Committer le profil Klogg VEAF dans le repo pour faciliter la lecture des logs DCS.

**Context**: Tous les autres tickets REV-* du Lot 24 sont archivés. REV-002 attend que l'utilisateur fournisse le fichier `.conf` Klogg.

**Branch**: `fix/doc-review-klogg` → PR → `develop-v6`

| # | Ticket | Fichiers touchés | Type | Effort | Status |
|---|--------|-----------------|------|--------|--------|
| REV-002 | Committer le profil Klogg fourni par l'utilisateur dans `tools/klogg/veaf.conf` ; mettre à jour la section "Reading the log" dans `GUIDE.md` et `GUIDE.fr.md` pour pointer vers ce fichier | `tools/klogg/veaf.conf`, `doc/mission-maker/GUIDE.md`, `doc/mission-maker/GUIDE.fr.md` | chore | 20 min | ⬜ |

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
