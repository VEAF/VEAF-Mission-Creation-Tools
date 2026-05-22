# Guide des tests

Documentation de la suite de tests unitaires Lua VEAF et du pipeline CI/CD.

## Table des matières

- [Vue d'ensemble](#vue-densemble)
- [Exécuter les tests](#executer-les-tests)
- [Infrastructure](#infrastructure)
- [Suite de tests](#suite-de-tests)
- [Écrire des tests](#ecrire-des-tests)
- [Pipeline CI/CD](#pipeline-cicd)

---

## Vue d'ensemble

Le projet compte 31 suites de tests Lua couvrant tous les modules runtime, totalisant ~915 tests. Les tests s'exécutent en **Lua 5.1** standard avec le framework [luaunit](https://github.com/bluebird75/luaunit). Aucune installation de DCS n'est requise — l'API DCS est simulée par `dcs_mocks.lua`.

---

## Exécuter les tests

### Tous les tests

```powershell
.\test\lua\run_tests.ps1
```

Code de sortie `0` si toutes les suites passent, `1` si un test échoue.

### Exécution filtrée

```powershell
# Exécuter les suites dont le nom de fichier correspond à une sous-chaîne
.\test\lua\run_tests.ps1 -Filter spawn
.\test\lua\run_tests.ps1 -Filter combat
```

### Fichier unique

```powershell
lua test\lua\test_veafSpawn.lua
```

### Prérequis

- Lua 5.1 dans le PATH, ou installé à `c:\program files (x86)\lua\5.1\lua.exe`
- Aucune autre dépendance (luaunit est embarqué dans `test/lua/luaunit.lua`)

---

## Infrastructure

### Organisation des fichiers

```
test/lua/
├── luaunit.lua         # Framework de test (embarqué)
├── dcs_mocks.lua       # Stubs de l'API DCS
├── veaf_loader.lua     # Chargeur de modules pour src/scripts/veaf/
├── run_tests.ps1       # Lanceur de tests (PowerShell)
└── test_*.lua          # Un fichier par module (31 fichiers)
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

| Suite | Tests | Ce qu'elle couvre |
|-------|-------|-------------------|
| `test_veaf.lua` | 93 | Utilitaires de base, helpers string/table/vecteur, logging |
| `test_veafCacheManager.lua` | 12 | Cache get/set/invalidate |
| `test_veafInterpreter.lua` | 9 | Tokeniseur de texte marqueur |
| `test_veafTime.lua` | 71 | Parsing de temps, formatage, helpers temps DCS |
| `test_veafSecurity.lua` | 24 | Niveaux de sécurité, gestion des admins |
| `test_veafNamedPoints.lua` | 25 | Enregistrement de points, recherche, helpers ATC |
| `test_veafShortcuts.lua` | 39 | Enregistrement et résolution des raccourcis |
| `test_veafWeather.lua` | 65 | Parsing météo, calculs QNH/vent |
| `test_dcsDataExport.lua` | 29 | Utilitaires d'export de données unités |
| `test_veafCombatMission.lua` | 59 | Cycle de vie d'une mission de combat |
| `test_veafAirbases.lua` | 13 | Recherche de données aérodromes |
| `test_veafCombatZone.lua` | 51 | Activation de zone, scoring, machine à états |
| `test_veafUnits.lua` | 34 | Recherche de templates d'unités, filtrage par catégorie |
| `test_veafAssets.lua` | 19 | Enregistrement d'assets, suivi d'état |
| `test_veafRemote.lua` | 25 | Parsing de commandes distantes |
| `test_veafMarkers.lua` | 17 | Gestion des événements marqueur |
| `test_veafEventHandler.lua` | 21 | Dispatch d'événements, enregistrement de handlers |
| `test_veafSkynetIadsHelper.lua` | 18 | Helpers d'intégration Skynet IADS |
| `test_veafSkynetIadsMonitor.lua` | 18 | État du moniteur Skynet |
| `test_veafGroundAI.lua` | 26 | Flags de comportement IA sol |
| `test_veafRadio.lua` | 24 | Construction de l'arbre de menus radio |
| `test_veafQraManager.lua` | 28 | Machine à états QRA, gestion de zones |
| `test_veafAirWaves.lua` | 30 | Planification de waves, assignation de groupes |
| `test_veafSanctuary.lua` | 19 | Détection de zone sanctuaire |
| `test_veafMissileGuardian.lua` | 16 | Logique d'interception de missiles |
| `test_veafCasMission.lua` | 14 | Génération de packages de menaces CAS |
| `test_veafTransportMission.lua` | 14 | Setup de mission de transport |
| `test_veafCarrierOperations.lua` | 16 | Séquence de recovery porte-avions |
| `test_veafMove.lua` | 19 | Parsing de commandes de déplacement/téléportation |
| `test_veafGrass.lua` | 12 | Initialisation de pistes en herbe |
| `test_veafSpawn.lua` | 55 | Commandes spawn, analyse de texte marqueur, conversion fréquence laser |

**Modules non couverts** (design-time ou externes uniquement) :

| Module | Raison |
|--------|--------|
| `veafMissionEditor.lua` | Opère sur des fichiers ZIP `.miz` ; testé via les tests d'intégration Python |
| `veafMissionFlightPlanEditor.lua` | idem |
| `veafMissionNormalizer.lua` | idem |
| `veafMissionRadioPresetsEditor.lua` | idem |
| `veafMissionTriggerInjector.lua` | idem |
| `veafSpawnableAircraftsEditor.lua` | idem |
| `veafHoundElintHelper.lua` | Dépend de la bibliothèque externe Hound ELINT |
| `dcsUnits.lua` | Fichier de données pur ; exercé indirectement via `test_veafUnits.lua` |
| `veaf-scripts-trace.lua` | Wrapper config/include sans logique testable |

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

function TestVeafMyModuleConstants:test_Version()
  luaunit.assertNotNil(veafMyModule.Version)
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

**`stylua-check`** — Ubuntu latest
1. Checkout du dépôt
2. Exécution de `JohnnyMorganz/stylua-action@v4` avec la version `2.4.0`
3. Vérification de `src/scripts/veaf/` contre `.stylua.toml`
4. Échec si un fichier n'est pas formaté

### Exécuter StyLua localement

```powershell
# Vérification seule (pas d'écriture)
stylua --check src/scripts/veaf/

# Auto-formatage
stylua src/scripts/veaf/
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
