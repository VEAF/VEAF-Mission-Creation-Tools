# Guide des tests

Documentation de la suite de tests unitaires Lua VEAF et du pipeline CI/CD.

## Table des matières

- [Vue d'ensemble](#vue-densemble)
- [Exécuter les tests](#exécuter-les-tests)
- [Couverture](#coverage)
- [Infrastructure](#infrastructure)
- [Suite de tests](#suite-de-tests)
- [Écrire des tests](#écrire-des-tests)
- [Pipeline CI/CD](#pipeline-cicd)

---

## Vue d'ensemble

Le projet couvre les modules runtime par une suite de tests Lua par module — la section « Suite de tests » les énumère toutes, et liste à sa fin ce qui n'est délibérément pas couvert. Les tests s'exécutent en **Lua 5.1** standard avec le framework [luaunit](https://github.com/bluebird75/luaunit). Aucune installation de DCS n'est requise — l'API DCS est simulée par `dcs_mocks.lua`.

---

## Exécuter les tests

### Tous les tests

```shell
poetry run test-lua
```

Code de sortie `0` si toutes les suites passent, `1` si un test échoue.

### Exécution filtrée

```shell
poetry run test-lua --filter spawn
poetry run test-lua --filter combat
```

### Fichier unique

```shell
lua test/lua/test_veafSpawn.lua
```

### Prérequis

- `poetry install` doit avoir été exécuté une fois
- Lua 5.1 dans le PATH (`lua5.1`, `lua51` ou `lua`, ou `C:\Program Files (x86)\Lua\5.1\lua.exe` sous Windows)
- Aucune autre dépendance (luaunit est embarqué dans `test/lua/luaunit.lua`)

La version **5.1** est vérifiée : chaque candidat est interrogé avec `lua -v`, et un interpréteur
5.2+ est refusé au lieu d'être utilisé. C'est délibéré — Lua 5.2 a supprimé `unpack` et rendu
`string.format('%d', ...)` intolérant aux nombres fractionnaires, donc une exécution sous 5.4
produit des dizaines d'échecs qui ressemblent à des régressions et n'en sont pas.

Sous Windows, `scoop install lua51` fournit Lua 5.1.5. Attention : son shim `lua` remplace celui
d'une autre version de Lua déjà installée par scoop ; le shim `lua51` permet de garder les deux.

---

## Couverture {#coverage}

Générez un rapport de couverture par fichier avec [luacov](https://github.com/lunarmodules/luacov) :

```shell
poetry run test-lua --coverage
# ou forme courte :
poetry run test-lua -c
```

Après l'exécution, un tableau est affiché avec le nombre de lignes couvertes, manquées et le pourcentage de couverture par module. Le rapport est également écrit dans `luacov.report.out` à la racine du dépôt.

### Prérequis (couverture)

luacov doit être installé via luarocks :

```shell
# Linux / DevContainer (luarocks est pré-installé)
luarocks install luacov

# Windows (peut nécessiter un shell élevé)
luarocks install luacov
```

Dans le DevContainer, luacov est installé automatiquement — aucune étape supplémentaire requise.

### Configuration

La couverture est collectée uniquement pour les modules sous `src/scripts/veaf/` (les helpers de test et luaunit sont exclus). Le fichier `.luacov` à la racine du dépôt contrôle ce comportement.

---

## Infrastructure

### Organisation des fichiers

```
test/lua/
├── luaunit.lua         # Framework de test (embarqué)
├── dcs_mocks.lua       # Stubs de l'API DCS
├── veaf_loader.lua     # Chargeur de modules pour src/scripts/veaf/
└── test_*.lua          # Un fichier par module
```

### dcs_mocks.lua

Fournit des stubs minimaux pour l'API globale DCS afin que les modules puissent être chargés via `require` sans instance DCS active. Espaces de noms simulés :

- `env`, `timer`, `world`
- `Unit`, `Group`, `StaticObject`, `Airbase`
- `coalition`, `country`, `radio`
- `trigger` (incluant `trigger.smokeColor`, `trigger.action.*`)
- `mist` (utilitaires de base utilisés par plusieurs modules)
- Helpers mathématiques (`math.isnan`, `math.inf`)

Si un nouveau module ne se charge pas à cause d'un appel API DCS manquant, ajoutez le stub dans `dcs_mocks.lua`.

### veaf_loader.lua

Modifie `package.path` pour que `require("veaf")`, `require("veafSpawn")`, etc. pointent vers `src/scripts/veaf/`. Chaque fichier de test commence par :

```lua
dofile("test/lua/dcs_mocks.lua")
dofile("test/lua/veaf_loader.lua")
local luaunit = require("luaunit")
-- charger le module à tester :
require("veafSpawn")
```

### luaunit

L'API standard luaunit s'applique. Attention : `assertNoError` n'existe pas dans cette version ; utilisez `pcall` à la place :

```lua
local ok, err = pcall(function() veafSpawn.someFunction() end)
luaunit.assertIsTrue(ok, err)
```

---

## Suite de tests

| Suite | Ce qu'elle couvre |
|-------|-------------------|
| `test_veaf.lua` | Utilitaires de base, helpers string/table/vecteur, logging |
| `test_veafCacheManager.lua` | Cache get/set/invalidate |
| `test_veafScheduler.lua` | Planificateur sur le timer natif : répétition, heure d'arrêt, tâche en échec |
| `test_veafMath.lua` | Conversions d'unités, vecteurs, formes de coordonnées, copie profonde |
| `test_veafGeo.lua` | Rendu texte des coordonnées, zones, positions moyennes, polygones |
| `test_veafMissionDb.lua` | Instantané de la mission, liste des joueurs, registre des noms, identifiants |
| `test_veafInterpreter.lua` | Tokeniseur de texte marqueur |
| `test_veafTime.lua` | Parsing de temps, formatage, helpers temps DCS |
| `test_veafSecurity.lua` | Niveaux de sécurité, gestion des admins |
| `test_veafServerHook.lua` | Hook serveur : parsing et dispatch des commandes chat |
| `test_veafNamedPoints.lua` | Enregistrement de points, recherche, helpers ATC |
| `test_veafShortcuts.lua` | Enregistrement et résolution des raccourcis |
| `test_veafWeather.lua` | Parsing météo, calculs QNH/vent |
| `test_dcsDataExport.lua` | Utilitaires d'export de données unités |
| `test_veafCombatMission.lua` | Cycle de vie d'une mission de combat |
| `test_veafAirbases.lua` | Recherche de données aérodromes |
| `test_veafCombatZone.lua` | Activation de zone, scoring, machine à états |
| `test_veafUnits.lua` | Recherche de templates d'unités, filtrage par catégorie |
| `test_veafAssets.lua` | Enregistrement d'assets, suivi d'état |
| `test_veafAssist.lua` | Assistance pilote : checklists, progression, menus |
| `test_veafRemote.lua` | Parsing de commandes distantes |
| `test_veafMarkers.lua` | Gestion des événements marqueur |
| `test_veafEventHandler.lua` | Dispatch d'événements, enregistrement de handlers |
| `test_veafSkynetIadsHelper.lua` | Helpers d'intégration Skynet IADS |
| `test_veafSkynetIadsMonitor.lua` | État du moniteur Skynet |
| `test_veafGroundAI.lua` | Flags de comportement IA sol |
| `test_veafRadio.lua` | Construction de l'arbre de menus radio |
| `test_veafQraManager.lua` | Machine à états QRA, gestion de zones |
| `test_veafAirWaves.lua` | Planification de waves, assignation de groupes |
| `test_veafSanctuary.lua` | Détection de zone sanctuaire |
| `test_veafMissileGuardian.lua` | Logique d'interception de missiles |
| `test_veafCasMission.lua` | Génération de packages de menaces CAS |
| `test_veafTransportMission.lua` | Setup de mission de transport |
| `test_veafCarrierOperations.lua` | Séquence de recovery porte-avions |
| `test_veafMove.lua` | Parsing de commandes de déplacement/téléportation |
| `test_veafMove_escort.lua` | Récupération de la tâche Escort après recréation du groupe escorté |
| `test_veafGrass.lua` | Initialisation de pistes en herbe |
| `test_veafSpawn.lua` | Commandes spawn, analyse de texte marqueur, conversion fréquence laser |
| `test_veafSpawnParser.lua` | Parsing déterministe du texte marqueur de spawn (`markTextAnalysis`) |
| `test_veafCommands.lua` | Registre de commandes : ordonnancement par priorité et dispatch |
| `test_veafI18n.lua` | Couche i18n runtime Lua (`veaf.t`, catalogue `veafI18n`) |

**Module non couvert** :

| Module | Raison |
|--------|--------|
| `dcsUnits.lua` | Fichier de données pur ; exercé indirectement via `test_veafUnits.lua` |

---

## Écrire des tests

### Template minimal

```lua
-- test_veafMyModule.lua
package.path = package.path .. ";test/lua/?.lua;src/scripts/veaf/?.lua"
dofile("test/lua/dcs_mocks.lua")
dofile("test/lua/veaf_loader.lua")
local luaunit = require("luaunit")
require("veafMyModule")

TestVeafMyModuleConstants = {}

function TestVeafMyModuleConstants:test_Id()
  luaunit.assertEquals(veafMyModule.Id, "MYMODULE")
end

TestVeafMyModuleLogic = {}

function TestVeafMyModuleLogic:test_someFunction()
  local result = veafMyModule.someFunction("input")
  luaunit.assertEquals(result, "expected")
end

-- Point d'entrée
os.exit(luaunit.LuaUnit.run())
```

### Conventions

- Un fichier par module : `test_veaf<NomModule>.lua`
- Grouper les tests en classes : `TestVeaf<NomModule>Constants`, `TestVeaf<NomModule>Logic`, etc.
- Toujours terminer par `os.exit(luaunit.LuaUnit.run())`
- Utiliser `pcall` au lieu de `assertNoError` (indisponible dans cette version de luaunit)
- Ne pas tester les fonctions internes/privées — uniquement ce que le module Lua exporte sur sa table globale

### Ajouter des stubs d'API DCS

Si votre test échoue avec "nil value" ou "attempt to call a nil value" sur une fonction DCS, ajoutez le stub dans `dcs_mocks.lua` :

```lua
-- Dans dcs_mocks.lua :
trigger.action.myNewFunction = function(...) end
trigger.myNewConstant = 42
```

---

## Pipeline CI/CD

Le workflow GitHub Actions (`.github/workflows/lua-ci.yml`) s'exécute à chaque push et pull request :

### Jobs

**`lua-unit-tests`** — Ubuntu latest
1. Checkout du dépôt
2. Installation de `lua5.1` via apt
3. Exécution de tous les fichiers `test/lua/test_*.lua`
4. Échec du job si une suite retourne un code non-zéro

**`luacheck`** — Ubuntu latest
1. Checkout du dépôt
2. Installation de `lua5.1` + `luacheck` via LuaRocks
3. Analyse statique de `src/scripts/veaf/` avec `luacheck --config .luacheckrc` (globaux non définis, variables inutilisées, shadowing)
4. Échec si une violation est détectée

**`stylua-check`** — Ubuntu latest
1. Checkout du dépôt
2. Exécution de `JohnnyMorganz/stylua-action@v5` avec la version `2.4.0`
3. Vérification de `src/scripts/veaf/` **et** `test/lua/` contre `.stylua.toml`
4. Échec si un fichier n'est pas formaté

**`lua-coverage`** — Ubuntu latest
1. Checkout du dépôt
2. Installation de `lua5.1` + `luacov` via LuaRocks, puis de Poetry et des dépendances
3. Exécution de `poetry run test-lua --cov-fail-under 72` (couverture ligne via luacov)
4. Échec si la couverture passe sous le plancher à cliquet (le nombre ne fait que monter)

### Exécuter StyLua localement

```powershell
# Vérification seule (pas d'écriture)
stylua --check src/scripts/veaf/ test/lua/

# Auto-formatage
stylua src/scripts/veaf/ test/lua/
```

### Exécuter Luacheck localement

```powershell
luacheck --config .luacheckrc src/scripts/veaf/
```

Configuration StyLua (`.stylua.toml`) :

```toml
column_width = 140
line_endings = "Windows"
indent_type = "Spaces"
indent_width = 2
quote_style = "AutoPreferDouble"
call_parentheses = "Always"
collapse_simple_statement = "Never"
```
