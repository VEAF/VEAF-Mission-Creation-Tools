# Guide du développeur — VEAF Mission Creation Tools

Ce guide s'adresse aux développeurs qui souhaitent contribuer au code source de VEAF Mission Creation Tools, créer de nouvelles versions ou étendre le framework.

---

## Table des matières

1. [Vue d'ensemble de l'architecture](#vue-densemble-de-larchitecture)
2. [Structure du dépôt](#structure-du-dépôt)
3. [Environnement de développement](#environnement-de-développement)
4. [Scripts Lua runtime](#scripts-lua-runtime)
5. [Outils Python](#outils-python)
6. [Build et publication](#build-et-publication)
7. [Tests](#tests)
8. [Portes de qualité](#portes-de-qualité)
9. [Contribuer](#contribuer)

---

## Vue d'ensemble de l'architecture

Le projet comporte deux couches complètement séparées :

```
┌──────────────────────────────────────────────────────────┐
│  DESIGN-TIME (Python)                                    │
│                                                          │
│  veaf-tools.exe  ──────────────── manipulation des .miz  │
│  veaf-tools-updater.exe ──────── gestion des versions    │
│  veaf-build  (poetry run veaf-build) ─ pipeline de build │
└──────────────────────────────────────────────────────────┘
                        ↓ produit
                  published.zip
                        ↓ consommé par
┌──────────────────────────────────────────────────────────┐
│  RUNTIME (Lua, dans DCS World)                           │
│                                                          │
│  veaf-scripts.lua  ────── les 32 modules concaténés     │
│  missionconfig.lua ────── config spécifique à la mission │
└──────────────────────────────────────────────────────────┘
```

- **Runtime** (`src/scripts/veaf/`) — 32 modules Lua chargés dans les missions DCS
- **Design-time** (`src/python/veaf-tools/`) — outils CLI Python pour la manipulation des fichiers `.miz`

---

## Structure du dépôt

```
VEAF-Mission-Creation-Tools/
├── veaf_build/                   # CLI veaf-build (orchestrateur build & publication)
├── build-and-release.py          # Shim de rétrocompatibilité (utiliser veaf-build à la place)
├── src/
│   ├── scripts/veaf/             # Modules Lua runtime (32 fichiers)
│   └── python/veaf-tools/        # Code source Python CLI
│       ├── veaf-tools.py         # Point d'entrée
│       ├── veaf_libs/            # Utilitaires partagés (logger, progress, miz)
│       ├── mission_tools/        # Lecture/écriture .miz
│       └── *_injector/           # Un dossier par commande CLI
├── published/                    # Sortie Lua compilée
├── dist/                         # Sortie .exe PyInstaller
├── build/                        # Espace de travail de build temporaire
├── test/
│   └── lua/                      # Tests unitaires Lua (31 suites)
├── doc/                          # Documentation
├── openspec/                     # Gestion des changements (workflow OpenSpec)
└── .github/
    └── workflows/                # CI/CD GitHub Actions
```

---

## Environnement de développement

Deux options de setup sont disponibles. Le DevContainer est recommandé pour les nouveaux contributeurs : il garantit un environnement identique à la CI.

### Option A — DevContainer (recommandé)

Le dépôt inclut une configuration `.devcontainer/` qui fournit un environnement pré-configuré, sans installation manuelle : Python 3.13, Lua 5.1, StyLua 2.4.0, Poetry et toutes les extensions VS Code sont déjà installées.

**VS Code Dev Containers** (Docker local) :

1. Installer [Docker Desktop](https://www.docker.com/products/docker-desktop/) et l'extension [Dev Containers](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)
2. Ouvrir le dossier du dépôt dans VS Code
3. Appuyer sur `Ctrl+Shift+P` → *Dev Containers: Reopen in Container*
4. Attendre la construction du conteneur et la fin de `poetry install` — l'environnement est prêt

**GitHub Codespaces** (navigateur, sans installation locale) :

1. Sur la page du dépôt, cliquer sur **Code** → **Codespaces** → **New codespace**
2. L'environnement se construit automatiquement — ouvrir un terminal et commencer à travailler

Dans les deux cas, `poetry install --without build --all-extras` s'exécute automatiquement à la première ouverture.

### Option B — Setup manuel (Windows)

### Prérequis

- Python 3.9+ (3.13 recommandé)
- Git
- GitHub CLI (`gh`) — pour publier les versions
- Lua 5.1 — pour lancer les tests unitaires en local
- StyLua 2.4.0 — pour le formatage Lua (installé dans `~/.local/bin/stylua.exe`)

### Installation

```powershell
# Cloner
git clone https://github.com/VEAF/VEAF-Mission-Creation-Tools.git
cd VEAF-Mission-Creation-Tools

# Installer les dépendances (Poetry gère son propre environnement virtuel)
poetry install              # quality gate + veaf-tools
poetry install --with build # ajouter PyInstaller (nécessaire pour compiler les .exe)
```

> Utiliser `poetry run <cmd>` pour exécuter n'importe quelle commande Python dans l'environnement Poetry,
> ou `poetry shell` pour ouvrir une session interactive.

### Dépendances Python

| Package | Utilité |
|---------|---------|
| `typer` | Framework CLI |
| `rich` | Interface terminal (barres de progression, tableaux) |
| `pyyaml` | Chargement des fichiers de config |
| `luadata` | Sérialisation/désérialisation Lua |
| `pyinstaller` | Compilation des exécutables Windows |
| `pillow` | Traitement d'images (icônes météo) |

---

## Scripts Lua runtime

### Structure des modules

Chaque module Lua suit ce modèle :

```lua
moduleName = {}

moduleName.Id = "MODULE_ID"
moduleName.Version = "1.x.y"
-- moduleName.LogLevel = "trace"  -- décommenter pour augmenter la verbosité

veaf.loggers.new(moduleName.Id, moduleName.LogLevel)

function moduleName.initialize()
  -- s'enregistrer auprès des marqueurs, radio, gestionnaire d'événements
end

function moduleName.start()
  -- démarrer les watchdogs, tâches planifiées
end
```

### Ordre de chargement

1. `veaf.lua` — doit être en premier
2. `veafEventHandler.lua`
3. `veafMarkers.lua`, `veafRadio.lua`, `veafSecurity.lua`
4. Tous les autres modules (dans n'importe quel ordre)

### Journalisation

```lua
veaf.loggers.get(moduleName.Id):info("Message")
veaf.loggers.get(moduleName.Id):debug("Debug: %s", variable)
veaf.loggers.get(moduleName.Id):trace("Trace: %s", veaf.lp(table))
```

Niveaux de log : `error` (1) → `warning` (2) → `info` (3) → `debug` (4) → `trace` (5). Par défaut : `info` (3).

Pour les arguments coûteux à évaluer, utiliser `veaf.lp()` (proxy lazy — stringifié uniquement si le niveau est actif).

Pour augmenter la verbosité pour une mission au **moment du build** (global, intégré dans le `.miz`), ajouter `global_log_level` dans `mission.yaml` :

```yaml
global_log_level: debug
```

Pour le contrôle **par module au moment du build**, utiliser la section `lua_modules` :

```yaml
lua_modules:
  SPAWN:
    logLevel: debug
  RADIO:
    logLevel: trace
```

Cela génère des appels `veaf.setConfig("MODULE_ID", "logLevel", "...")` dans `veaf-modules-config.lua`. Ou utiliser `--log-modules SPAWN,RADIO` sur la CLI pour réduire au silence tout le reste.

Pour le contrôle **par module au runtime** (sans rebuild), utiliser `missionconfig.lua` directement :

```lua
veaf.loggers.get("SPAWN"):setLevel("debug", true)  -- force=true contourne le cap BaseLogLevel
```

### Accès mist.DBs

Ne pas accéder à `mist.DBs.*` directement. Utiliser l'interface `veaf.mist` :

```lua
local unitData  = veaf.mist.getUnitData(unitName)
local groupData = veaf.mist.getGroupData(groupName)
local isHuman   = veaf.mist.isHumanUnit(unitName)
local allUnits  = veaf.mist.getAllUnitData()
local groupById = veaf.mist.getGroupById(groupId)
```

---

## Outils Python

### Architecture CLI

Chaque sous-commande de `veaf-tools.exe` est implémentée comme un package `*_injector/` :

```
weather_injector/
├── weather_worker.py    # Point d'entrée (méthode run())
├── weather_manager.py   # Logique de transformation des données
├── models.py            # Définitions des dataclasses
└── weather_README.py    # Chaînes d'aide/documentation
```

### Pattern de journalisation

```python
from veaf_libs.logger import logger, console

logger.info("Traitement de la mission...")
logger.debug("Informations détaillées")
logger.warning("Attention")
logger.error("Échec", raise_exception=True)
```

### Ajouter un nouvel outil

1. Créer `src/python/veaf-tools/new_feature_injector/`
2. Implémenter `new_feature_worker.py` avec une méthode `run()`
3. Enregistrer la commande dans `veaf-tools.py` avec `typer`
4. Ajouter le schéma de configuration YAML dans `models.py`

---

## Build et publication

### Build local

```powershell
# Build (compile Lua + construit les .exe)
poetry run veaf-build build --version 6.0.5
```

Ce que cela fait :
1. Valide les prérequis (Git, Python, PyInstaller)
2. Concatène les modules Lua → `published/veaf-scripts.lua`
3. Construit `veaf-tools.exe` et `veaf-tools-updater.exe` via PyInstaller
4. Crée `published.zip` avec tous les artefacts + somme SHA256

### Publier une version

#### Automatisé (recommandé)

Pousser un tag versionné — GitHub Actions fait tout :

```bash
git tag published-v6.0.6
git push origin published-v6.0.6
```

Le workflow CI `release` va :
1. Générer les notes de release depuis les commits conventionnels (git-cliff)
2. Construire `veaf-tools.exe`, `veaf-tools-updater.exe` et `published.zip`
3. Créer la GitHub Release et uploader tous les artefacts
4. Déplacer le tag flottant `published-latest`

Les notes de release sont auto-générées depuis les messages de commit. Elles sont éditables sur GitHub après la release.

#### Manuel (mode de secours)

```powershell
# Build d'abord
poetry run veaf-build build --version 6.0.5

# Puis publication (interactif — demande RELEASE_NOTES.md)
# Nécessite la variable d'environnement GITHUB_TOKEN
poetry run veaf-build publish --version 6.0.5
```

### Modèle de sécurité

```
veaf-build calcule le SHA256 de published.zip
    ↓
SHA256 stocké avec le ZIP dans la GitHub Release
    ↓
veaf-tools-updater.exe télécharge les deux fichiers
    ↓
Somme de contrôle vérifiée avant extraction
    ↓
✅ Intégrité garantie
```

---

## Tests

### Lancer tous les tests

```powershell
.\test\lua\run_tests.ps1
```

Code de sortie `0` = tous passent, `1` = échecs.

### Exécution filtrée

```powershell
.\test\lua\run_tests.ps1 -Filter spawn
.\test\lua\run_tests.ps1 -Filter combat
```

### Suite unique

```powershell
lua test\lua\test_veafSpawn.lua
```

### Infrastructure

- **Framework :** [luaunit](https://github.com/bluebird75/luaunit) (intégré dans `test/lua/luaunit.lua`)
- **Stubs DCS :** `test/lua/dcs_mocks.lua` — stubs pour tous les espaces de noms de l'API DCS
- **Chargeur de modules :** `test/lua/veaf_loader.lua`
- Aucune installation DCS requise

Référence complète des tests : [Guide de tests](../TESTING.md)

---

## Portes de qualité

### Avant chaque commit sur des fichiers Lua

```powershell
# Vérifier le formatage (équivalent CI)
~/.local/bin/stylua.exe --check src/scripts/veaf/

# Corriger automatiquement
~/.local/bin/stylua.exe src/scripts/veaf/

# Analyse statique
luacheck src/scripts/veaf/ --config .luacheckrc
```

Version StyLua : **2.4.0** (imposée par le job CI `StyLua Formatting`).
Luacheck est imposé par le job CI `Luacheck`.

### Jobs CI

| Job | Ce qu'il vérifie |
|-----|-----------------|
| `Lua Unit Tests` | Les 31 suites de tests passent |
| `Luacheck` | Aucune variable globale non définie, variable inutilisée ni shadowing dans `src/scripts/veaf/` |
| `StyLua Formatting` | Aucune violation de formatage dans `src/scripts/veaf/` |
| `python-quality` | ruff lint + format, mypy types, pytest |
| `Release` | Déclenché sur push de tag `published-v*` — build et publication sur GitHub |

Tous les jobs CI doivent être verts avant qu'une PR puisse être mergée.

---

### Publier une nouvelle version

Pousser un tag `published-v*` — le workflow CI `Release` fait tout automatiquement :

```bash
git tag published-v6.1.0
git push origin published-v6.1.0
```

---

## Contribuer

### Git Flow

- **Développement de fonctionnalité :** créer `feature/xxx` depuis `develop-v6`, ouvrir PR → `develop-v6`
- **Corrections de bugs :** créer `fix/xxx` depuis `develop-v6`, ouvrir PR → `develop-v6`
- **Hotfixes en production :** `fix/xxx` depuis `master`, PR → `master`
- **Versions :** `release/vX.Y.Z` depuis `develop-v6`, PR → `master`

### Convention de commit

```
type(scope): courte description

feat(spawn): ajouter le mode patrouille convoy
fix(qra): vérifier unit:isExist() avant unit:inAir()
chore(deps): mettre à jour luaunit à 3.4
docs(api): documenter les helpers tanker de veafMove
```

Types : `feat`, `fix`, `chore`, `docs`, `test`, `refactor`, `style`.

### Checklist Pull Request

- [ ] Tous les changements Lua passent `stylua --check`
- [ ] Tous les tests unitaires passent (`run_tests.ps1`)
- [ ] Les nouvelles fonctionnalités ont des tests dans `test/lua/`
- [ ] Les changements d'API publique sont documentés dans `doc/LUA_API_REFERENCE.md`
- [ ] `CHANGELOG.md` mis à jour pour les changements visibles par les utilisateurs

---

## Pour aller plus loin

- [Référence API Lua](../LUA_API_REFERENCE.md) — API publique complète des 32 modules
- [Guide de tests](../TESTING.md) — détails de l'infrastructure de test
- [Référence des outils](../TOOLS_REFERENCE.md) — CLI `veaf-tools.exe`
- [Feuille de route](../ROADMAP.md) — travaux planifiés
