# Feuille de route — VEAF Mission Creation Tools

Ce document décrit la direction prévue pour le projet. Les éléments sont classés par priorité, pas par date. Aucune date de livraison n'est engagée.

---

## Légende des statuts

| Symbole | Signification |
|---------|---------------|
| ✅ | Fait — livré dans une release |
| 🔄 | En cours — sur `develop-v6` |
| 🔵 | Planifié — ticket existant dans le backlog |
| ⚪ | Idée — pas encore de ticket |

---

## v6.x — Cycle de développement actuel (`develop-v6`)

### Fondations (Lot 1 — INFRA)
- ✅ **Migration Poetry** — remplacement de `requirements.txt` par `pyproject.toml` géré par Poetry
- ✅ **Quality gate Python** — ruff (lint + format) + mypy (types) + pytest, appliqué en CI
- ✅ **Job CI Python** — job GitHub Actions `python-quality` aux côtés du CI Lua existant

### Améliorations CLI (Lot 2 — CLI)
- 🔵 **Vérification de version au démarrage** — comparer la version installée avec la dernière release GitHub, proposer la mise à jour
- 🔵 **Répertoire centralisé `~/.veaf/`** — toutes les données utilisateur (scripts installés, préférences, logs) au même endroit
- 🔵 **Liste de modules embarquée** — l'exe `veaf-tools` embarque la liste des modules Lua avec infos de version ; exposée via `about --modules`

### Mode interactif (Lot 3 — TUI)
- ✅ **Mode interactif InquirerPy** — lancer `veaf-tools` sans argument ouvre un assistant guidé au lieu d'afficher l'aide
- ✅ **Persistance des préférences** — derniers paramètres utilisés sauvegardés dans `~/.veaf/preferences.json` et pré-remplis au prochain lancement

### Système de configuration Lua (Lot 4 — LUA-CONFIG)
- ✅ **`veaf.config` par module** — chaque module Lua enregistre sa configuration par défaut ; les modules peuvent être activés/désactivés
- ✅ **`veaf-config.lua`** — fichier de config généré au build (depuis `mission.yaml`) ; remplace le `veaf-modules-config.lua` écrit à la main
- ✅ **`mission-script.lua`** — fichier Lua au niveau mission pour du code custom ; remplace `missionConfig.lua`
- ✅ **Commande `generate-config`** — génère un template `mission.yaml` documenté pour une mission donnée
- ✅ **Mission YAML → sélection de modules** — la section `lua_modules` dans `mission.yaml` pilote quels modules sont inclus et comment ils sont initialisés

### Release
- ✅ **Releases v6.x** — publication continue depuis `develop-v6` (tags `published-vx.y.z`) ; version courante **6.6.0**. Le merge `develop-v6` → `master` est réservé aux jalons stables.
- ✅ **Release v6.6.0** — consolidation et améliorations : adoption de missions tierces (`convert-other` + profils Foothold, `config_override:`, build multi-variant), outils mission-maker (`validate`, `prepare --template`, pont CLI↔TUI, validation des références au build), et un large lot de correctifs (`convert-v5` sous-zones d'opération, AirWaves, slots dynamiques, catégories de templates).
- ✅ **Release v6.3.0** — corrections de bugs et améliorations UX (Lot 26 + FIX-SORT) : correction du crash convert-v5, auto-pause au double-clic, filtrage des smart defaults, vérification nil de veaf.initialize()
- ✅ **Release v6.3.3** — stabilisation et corrections de bugs : crashs des initialize() Lua, corrections du pipeline de build, profils de build, CSAR YAML-first, résolution automatique des dépendances

---

## Qualité & Tests

- ✅ Tests unitaires Lua (31 suites, ~915 tests) — `luaunit` + `dcs_mocks.lua` + `poetry run test-lua`
- ✅ Vérification de formatage StyLua en CI
- ✅ Analyse statique Luacheck en CI
- ✅ CI Lua sur GitHub Actions (`lua-unit-tests` + `luacheck` + `stylua-check`)
- ✅ Tests unitaires Python — pytest avec couverture
- ✅ Quality gate Python en CI

---

## Au-delà de la v6 (idées, pas encore de ticket)

- ✅ **Filtre de logger** (`--log-modules`) — filtrer quels modules Lua écrivent dans le log DCS, pour un débogage plus propre
- ✅ **Doc DCSUnits** — auto-génération de `doc/DCS_UNITS.md` depuis `dcsUnits.lua` avant chaque publication
- ⚪ **Validation de mission** — commande `veaf-tools validate` qui vérifie une mission contre les prérequis VEAF connus
- ⚪ **Support multi-carte** — meilleure gestion des missions sur différentes cartes DCS (Caucase, Syrie, Golfe Persique, etc.)
- ⚪ **Extension VS Code** — coloration syntaxique et validation pour les fichiers de config YAML VEAF

---

## Maintenu mais stable (v5)

La branche `master` porte la dernière release v5 (**v5.103.3**). Seuls les correctifs critiques seront appliqués à la v5.
Les nouvelles fonctionnalités ciblent uniquement la v6.
