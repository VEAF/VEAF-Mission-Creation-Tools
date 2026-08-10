# Feuille de route — VEAF Mission Creation Tools

Ce document décrit la direction prévue pour le projet. Les éléments sont classés par priorité, pas par date. Aucune date de livraison n'est engagée.

---

## Légende des statuts

| Symbole | Signification |
|---------|---------------|
| ✅ | Fait — livré dans une release |
| 🔄 | En cours — sur `develop` |
| 🔵 | Planifié — ticket existant dans le backlog |
| ⚪ | Idée — pas encore de ticket |

---

## v6.x — Cycle de développement actuel (`develop`)

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
- ✅ **Releases v6.x** — chaque release part d'une branche `release/x.y.z` mergée dans `master` (la ligne stable v6 depuis la 6.10.0), puis taguée deux fois : `published-vx.y.z` pour les binaires, `vx.y.z` pour la documentation versionnée. Version courante **6.13.0**.
- ✅ **Release v6.13.0** — **CTLD 2**. Le script de transport et logistique embarqué passe du monolithe ciribob à la réécriture VEAF ([VEAF/CTLD](https://github.com/VEAF/CTLD) 2.0.0-rc3), et sa configuration quitte `mission.yaml` pour un `ctld-config.yaml` posé à côté, édité dans `ctld-tools.exe` et injecté par le build ([ADR 0016](https://github.com/VEAF/VEAF-Mission-Creation-Tools/blob/develop/docs/adr/0016-ctld2-sidecar-configuration.md)). `modules.CTLD.settings:` n'est plus lu et **fait échouer `validate`** : ce canal n'a jamais complètement fonctionné, la configuration VEAF en dur écrasait la moitié de ce qu'on y écrivait. CTLD devient un module VEAF ordinaire (ordre d'initialisation, `enable`, `logLevel`), les vingt noms de zones réservés cèdent la place à la découverte par préfixe `LGZ_` / `TRZ_`, et les quatre ponts runtime passent aux managers v2. Côté vol : le stationnaire suffit désormais à ramasser une caisse, et les capacités d'emport sont réalignées sur CTLD 2 (FEAT-CTLD2-INTEGRATION).
- ✅ **Release v6.12.0** — **zones de combat des deux côtés** : `enemy_coalition` rend une zone jouable côté rouge (la complétion et les libellés amis/ennemis suivent), et son menu F10 n'est plus proposé qu'au camp qui la joue (`radio_menu_coalition`, avec `ALL` pour revenir au menu commun) — `veafRadio` sait désormais réserver un sous-menu à une coalition. **Chaîne Foothold** : `convert-other` adopte l'archive de release telle quelle, profil `foothold-ww2` pour la Normandie, `validate` refuse une `config_override.target` inopérante, adoption par lot des dix cartes, préréglages radio au modèle par plan. **Fiabilité** : la fréquence principale d'un groupe est bornée par la vraie plage de l'appareil (bug FW-190 signalé par Tripack, 27 appareils concernés), un mot de passe `mission.yaml` protège enfin (empreintes SHA-1, pas SHA-256). **Documentation** : audit complet du site publié et garde-fou CI pour l'y maintenir.
- ✅ **Release v6.9.2** — **confort des menus radio F10** : pagination automatique de tout menu VEAF dépassant la limite DCS de 10 entrées (sous-menus « Page suivante », opt-out `veafRadio.doNotPaginate`, ADR 0013) ; regroupement des combat zones dans le menu radio via deux clés `mission.yaml` (`radio_group_name` = sous-menu commun, `radio_menu_prefix` = préfixe de libellé), reprises par `convert-v5`. Retour de Reaper (FEAT-COMBATZONE-RADIO-GROUPS).
- ✅ **Release v6.9.0** — **planchettes radio** : deux attributs d'auteur valables sur tous les appareils — `priority` (surligne un canal sur la planchette + marqueur `Pn` ; sur l'AJS-37, alimente en plus les raccourcis FR22 Special 1/2/3 & FR24 H) et `color` (regroupe les canaux par couleur) ; **une planchette par type d'appareil** (`KNEEBOARD/<type>/IMAGES/`, entêtes gris). Vitrine : l'AJS-37 Viggen, packé par clé sur les Groups 100-139 avec ses vrais libellés cockpit sur deux colonnes (ADR 0012, casse l'iso-fonctionnalité ADR 0003 côté packer ; convert-v5 inchangé). Retours de Tripack (FEAT-PRESETS-PRIORITY-COLOR).
- ✅ **Release v6.8.0** — **presets radio** : nouveau modèle « plan » (`channel_lists` projetés automatiquement sur chaque appareil, ADR 0010), fréquences remplacées par des **noms lisibles** à la conversion (aérodromes + indicatifs VEAF), `convert-v5` génère un plan par défaut + copie fidèle ; **menus radio F10 déclarables en YAML** sans Lua (ADR 0011) ; `pipeline.presets` peut désactiver les kneeboards en gardant l'injection radio ; data ATC des aérodromes dataminée par théâtre. Corrections : presets radio dans l'exe, sortie `presets.yaml` nettoyée, CH-47F. Retours de Tripack (FEAT-RADIO-PRESET-PROJECTION, FEAT-CONVERTV5-PLAN-PRESETS, FEAT-CONVERTV5-FREQ-ALIASING, FEAT-AIRFIELD-FREQS-DATA, FEAT-RADIO-YAML-MENUS, FEAT-PRESETS-KNEEBOARD-TOGGLE, FIX-CONVERTV5-PRESETS-OUTPUT).
- ✅ **Release v6.7.8** — **fiabilité**, retour de Tripack : correction d'un plantage d'initialisation du module MissileGuardian (appel à un `dumpMissionsList` inexistant) qui interrompait toute la séquence de démarrage VEAF — donc plus de dispatcher de marqueurs F10 (spawns par alias et `_spawn` inertes malgré `SHORTCUTS: true`), ni CTLD/CSAR ; le module MissileGuardian (WIP de 2021) sort du tier `full` et devient opt-in (FIX-MISSILEGUARDIAN-INIT-CRASH).
- ✅ **Release v6.7.7** — **fiabilité**, deux retours de Tripack : le build accepte la radio HF principale du MiG-15bis (RSI-6K 3.75 MHz) au lieu de la rejeter sous le plancher 30 MHz (FIX-MIG15-PRIMARY-FREQ) ; `prepare --template` génère le même préambule riche que `convert-v5` (guide YAML, `global_log_level`, `mission:`, `security:`, `pipeline:`) via des helpers partagés (ENRICH-PREPARE-TEMPLATE).
- ✅ **Release v6.7.5** — **multi-plateforme et fiabilité** : binaires `veaf-tools` natifs Linux/macOS et updater cross-platform (FEAT-CROSSPLATFORM-BINARIES, UPDATER-CROSSPLATFORM) ; **stamp de build unique** (`6.7.5+<sha git>`) dans les logs DCS à la place des versions par module (FEAT-LUA-BUILD-STAMP) ; vraie cause racine du bug QRA slot dynamique corrigée dans le gestionnaire d'événements (FIX-EVENTHANDLER-UNITCATEGORY, signalé par Tripack).
- ✅ **Release v6.7.2** — correctifs terrain autour des **slots dynamiques DCS** : QRA réagissant aux avions slot-dyn (#299), plus de menu CTLD en double sur un hélico en slot dyn sur FARP spawnée, conversion des avions spawnables au format « à plat ». Plus un nettoyage de la sortie console (pluriels naturels, étapes de build indentées, comptes « 0 » non trompeurs).
- ✅ **Release v6.7.0** — ouverture des missions à l'outillage externe : commande `export` (JSON/YAML/Markdown, sans exécution de Lua, FEAT-EXPORT-MISSION + FEAT-EXPORT-BFR-PARSER) ; `convert-v5` promeut désormais `src/mission/` en v6 sur disque (FEAT-MIGRATE-MISSION-V6) ; correctifs slots dynamiques (templates avions mal catégorisés, injection `dict`) et TUI (commandes manquantes).
- ✅ **Release v6.6.1** — correctifs : toutes les commandes CLI accessibles depuis le TUI (FIX-TUI-MISSING-COMMANDS) ; injection des slots dynamiques réparée (`'dict' object has no attribute 'append'`, FIX-AIRCRAFT-INJECT-DICT-GROUP).
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
- ⚪ **Validation de mission** — commande `veaf-tools mission validate` qui vérifie une mission contre les prérequis VEAF connus
- ⚪ **Support multi-carte** — meilleure gestion des missions sur différentes cartes DCS (Caucase, Syrie, Golfe Persique, etc.)
- ⚪ **Extension VS Code** — coloration syntaxique et validation pour les fichiers de config YAML VEAF

---

## Maintenu mais stable (v5)

La branche `master` porte la dernière release v5 (**v5.103.3**). Seuls les correctifs critiques seront appliqués à la v5.
Les nouvelles fonctionnalités ciblent uniquement la v6.
