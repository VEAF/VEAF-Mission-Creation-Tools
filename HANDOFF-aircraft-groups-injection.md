# Handoff — Refonte de l'injection des groupes d'avions (spawnables vs dynamic-slot templates)

> Ce document est un **brief autonome** pour une session Claude travaillant **sur une
> branche dédiée**. Il contient l'analyse, les décisions déjà figées (glossaire +
> ADR), et le travail à réaliser. Lis d'abord `CONTEXT.md` et
> `docs/adr/0002-aircraft-group-injection-sort-criteria.md` : ils font foi.

## 0. Contexte en une phrase

Le pipeline v6 (`veaf-tools build`) sait injecter des groupes d'avions dans le
`.miz`, mais la séparation historique entre **deux usages distincts** de ces
groupes a été à moitié perdue lors de la réécriture Python. Il faut la rétablir
proprement, avec deux steps de pipeline séparés, et fiabiliser le tri.

## 1. Les deux concepts (cf. `CONTEXT.md`)

Ce sont **deux features séparées** qui partagent **le même outil** d'extraction/injection.

| | (B) Groupe avion spawnable | (C) Modèle de slot dynamique |
|---|---|---|
| **Usage** | spawn **à la demande** en jeu | **modèle** pour Dynamic Slots DCS |
| **Nature** | vrai groupe avion caché, late-activation, **cloné** (MiST) au spawn | groupe avec flag natif `dynSpawnTemplate=true` |
| **Consommé par** | script Lua `veafSpawn` (`_spawn cap`, spawn avion) | **moteur DCS** nativement (dialogue Warehouse) |
| **Marqueur d'identification** | **préfixe de nom `veafSpawn-`** (= contrat runtime) | **flag `dynSpawnTemplate==true`** (= contrat DCS) |
| **Fichier source (proposé)** | `src/spawnables.yaml` | `src/dynamic-templates.yaml` *(à nommer, voir Q ouverte)* |
| **Step pipeline (proposé)** | `spawnable_aircrafts` | `dynamic_slot_templates` |

> ⚠️ Ne PAS confondre avec les **« Spawn group definition »** du glossaire (groupes
> **sol/hélico** de la base `veafUnits`, commande `_spawn group`) : usage différent,
> chantier différent (voir §6).

## 2. Décisions déjà figées (NE PAS rediscuter sans raison)

1. **Ce sont 2 features distinctes**, gérées par le même outil. Deux fichiers de
   défaut, deux steps de pipeline configurables séparément.
2. **Critère de tri à l'extraction** (cf. ADR 0002) :
   ```
   pour chaque groupe avion de la mission :
       si dynSpawnTemplate == true            → (C) modèle de slot dynamique
       sinon si nom commence par "veafSpawn-" → (B) groupe avion spawnable
       sinon                                  → ignoré (groupe ordinaire)
   ```
   - Flag prioritaire si un groupe est les deux.
   - **Abandon total du tri par nom `.*[tT]emplate.*`** (source du bug historique :
     un spawnable nommé `… Template …` était misrouté).
3. **`veafSpawn-` reste le marqueur de (B)** parce que c'est déjà le contrat runtime
   (`veafSpawn.AirUnitTemplatesPrefix` dans `src/scripts/veaf/veafSpawnCore.lua`).
   Note d'avenir inscrite dans l'ADR : si un jour un champ de **métadonnée custom**
   sur un groupe DCS devient possible, on bascule (B) là-dessus et on retire le test
   du nom.

## 3. État actuel du code (constats de l'analyse)

- **Step pipeline `aircraft_groups`** (`src/python/veaf-tools/veaf_tools/commands/build.py`,
  ~L215) prend le **premier fichier trouvé** parmi
  `src/aircraft-templates.yaml` → `src/templates.yaml` → `aircraft-templates.yaml`.
  → `spawnables.yaml` **n'y figure pas** : il n'est **jamais injecté**.
  → `templates.yaml` et `aircraft-templates.yaml` se **cannibalisent** (premier gagne).
- **`spawnables.yaml`** n'est référencé QUE comme défaut copié quand le module Lua
  `SPAWN` est actif (`mission_builder/mission_builder_worker.py` ~L467). Aucun step ne le lit.
- **Extraction** (`aircrafts_injector/aircrafts_injector_worker.py`,
  `find_matching_groups` ~L1056) filtre par `group_name_pattern` (regex de nom).
  C'est là que le tri par nom doit être remplacé par le critère §2.2.
  ⚠️ Bug latent repéré au passage : la branche **helicopters** (~L1070-1076) a un
  `if pattern` **hors de la boucle `for group`** (mauvaise indentation) → ne traite
  que le dernier groupe. À corriger.
- **Injection** : l'injecteur injecte **tout** le YAML source (le pattern n'est pas
  réutilisé). Donc avec deux fichiers + deux steps, le tri tient au fichier d'entrée.
- **convert-v5** : `mission_builder/v5_pipeline_converters.py::convert_aircraft_groups`
  convertit `src/spawnableAircrafts/settings.lua` → un seul YAML. Les candidats v5/v6
  sont dans `mission_builder/v5_converter.py` (`V5_PIPELINE_CANDIDATES` /
  `V6_PIPELINE_CANDIDATES`, ~L59-73). Le v5 d'origine produisait DEUX familles
  (`merge_spawnables.cmd` filtre `veafSpawn-.+`, `merge_templates.cmd` filtre
  `.*[tT]emplate.*`) fusionnées dans un `settings.lua` unique.
- **Référence morte** : `.vscode/launch.json` (~L248) pointe vers
  `../../defaults/veafSpawnableAircraftsEditor/settings-templates.lua` (dossier supprimé).
- **Doc incohérente** : `doc/mission-maker/scripts/veafSpawn.md` (~L169) décrit
  `spawnables.yaml` avec un schéma simplifié (`groups:`), alors que le fichier de
  défaut `src/defaults/mission-folder/src/spawnables.yaml` utilise le schéma DCS
  complet (identique à `templates.yaml`).

## 4. Travail à réaliser (périmètre = AVIONS uniquement)

### 4.1 Pipeline — deux steps séparés
- Remplacer le step unique `aircraft_groups` par **deux steps** :
  `spawnable_aircrafts` (→ `src/spawnables.yaml`) et
  `dynamic_slot_templates` (→ `src/dynamic-templates.yaml`).
- Chacun configurable indépendamment dans `mission.yaml > pipeline:`
  (mêmes capacités que les autres steps : `true/false`, ou `{enabled, file, mode}`).
- Décider de la **compat ascendante** de l'ancien `aircraft_groups` / des noms de
  fichiers `aircraft-templates.yaml` / `templates.yaml`. Note : ADR 0001 montre que
  le projet assume des **hard breaks** tant que v6 n'est pas publié → privilégier un
  hard break propre plutôt qu'un shim, sauf objection de David.

### 4.2 Defaults
- Garder **les deux** fichiers de défaut dans `src/defaults/mission-folder/src/` :
  `spawnables.yaml` (B) et le fichier (C) renommé de façon cohérente.
- Mettre à jour la table de mapping des défauts dans
  `mission_builder/mission_builder_worker.py` (les deux fichiers, rattachés à leurs
  steps respectifs) + tests `test/python/mission_builder/test_mission_builder_defaults.py`.

### 4.3 Extraction
- Implémenter le tri §2.2 dans l'extracteur : router chaque groupe vers (B) ou (C)
  selon `dynSpawnTemplate`/préfixe, ignorer le reste.
- Idéalement : une seule passe d'extraction produit **les deux fichiers** (ou un flag
  `--kind spawnable|dynamic-template`). À arbitrer.
- Corriger le bug d'indentation helicopters (§3).

### 4.4 Injection
- Deux steps injectent chacun leur fichier **tel quel** (pas de regex de nom).
- Vérifier le mode `add`/`replace` par step.

### 4.5 convert-v5
- Faire produire au convertisseur **les deux** fichiers v6 à partir du
  `settings.lua` v5, en appliquant le même tri §2.2 (flag/préfixe).
- Mettre à jour `V5_PIPELINE_CANDIDATES` / `V6_PIPELINE_CANDIDATES`.

### 4.6 Nettoyage
- Corriger la référence morte `.vscode/launch.json`.
- Réaligner `doc/mission-maker/scripts/veafSpawn.md` (et la version `.en.md`) sur le
  schéma réel + la distinction B/C. Idem `doc/MISSION_YAML_REFERENCE.md` (les deux
  langues) et `doc/PIPELINE_REFERENCE.md`.

### 4.7 Tests (TDD)
- Tri B/C (flag prioritaire, préfixe, ignoré).
- Deux steps de pipeline activés/désactivés indépendamment.
- convert-v5 produisant deux fichiers.
- Non-régression injection.

## 5. Bonus (à creuser, NON figé) — câblage Warehouse des modèles (C)

Injecter un groupe `dynSpawnTemplate=true` met le **groupe** dans la mission, mais
pour que DCS le propose réellement en Dynamic Slot, le fichier **`warehouses`** du
`.miz` doit aussi le référencer (`airports[id].dynamicSpawn=true` + liste
d'aircrafts). L'injecteur actuel **ne touche pas** `warehouses`.
Exemple concret : `test/veaf-tools/demo-mission/src/mission/warehouses`
(`dynamicSpawn = true` ~L1966).
→ Tâche séparée : parser/modifier `warehouses` pour câbler automatiquement les
modèles (C). Faisabilité et design à investiguer.

## 6. Hors périmètre (autre session en cours)

Refonte de `veafUnits.lua` (groupes) et `dcsUnits.lua` (unités) en YAML générant des
bases Lua au build. **Ne pas y toucher ici.** Conclusion de l'analyse : factoriser
selon **l'axe pipeline** (B+C = « injection de groupes » ensemble ; A + veafUnits =
« génération de base Lua » ensemble), PAS selon « c'est un groupe ». Ne pas chercher
un schéma de groupe unifié A↔B/C.

## 7. Questions ouvertes à trancher avec David

1. Nom canonique du fichier (C) : `dynamic-templates.yaml` ? `dynamic-slot-templates.yaml` ?
2. Noms canoniques des steps de pipeline.
3. Hard break vs compat sur l'ancien `aircraft_groups` / `aircraft-templates.yaml`.
4. Extraction : une passe → deux fichiers, ou deux invocations avec `--kind` ?
5. Bonus warehouse : dans ce lot ou lot séparé ?

## 8. Procédure projet (rappel)

Respecter `CLAUDE.md` : branche `feature/<id>` depuis `develop-v6`, un lot dans
`BACKLOG.md`, TDD, `poetry run pytest`, ruff + mypy, `CHANGELOG.md` (`[Unreleased]`),
bump PATCH dans `pyproject.toml`, `poetry install`, PR vers `develop-v6` (review
Sourcery, pas de review Copilot sauf si Sourcery échoue).
