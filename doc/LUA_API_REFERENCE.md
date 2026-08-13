# Modules Lua VEAF — Référence API complète

**Version :** générée pour la 6.11.x

**Dernière mise à jour :** Juillet 2026

**Projet :** VEAF Mission Creation Tools

---

## Table des matières

1. [Introduction](#introduction)
2. [Architecture des modules](#architecture-des-modules)
3. [Infrastructure de base](#infrastructure-de-base)
   - [veaf.lua](#veaflua) — Utilitaires de base et logger
   - [veafEventHandler.lua](#veafeventhandlerlua) — Gestion des événements
   - [veafMarkers.lua](#veafmarkerslua) — Système de marqueurs carte
   - [veafCommands.lua](#veafcommandslua) — Dispatching central des commandes
   - [veafInterpreter.lua](#veafinterpreterlua) — Parsing de commandes
4. [Gestion des unités et groupes](#gestion-des-unités-et-groupes)
   - [veafSpawnParser.lua](#veafspawnparserlua) — Parseur de commandes spawn
   - [veafSpawn.lua](#veafspawnlua) — Spawn dynamique
   - [veafUnits.lua](#veafunitslua) — Définitions d'unités
   - [veafAssets.lua](#veafassetslua) — Suivi des assets
5. [Systèmes de mission](#systèmes-de-mission)
   - [veafCombatMission.lua](#veafcombatmissionlua) — Missions de combat
   - [veafCasMission.lua](#veafcasmissionlua) — Missions CAS
6. [Infrastructure et services](#infrastructure-et-services)
   - [veafAirbases.lua](#veafairbaseslua) — Données aérodromes
   - [veafCarrierOperations.lua](#veafcarrieroperationslua) — Opérations porte-avions
7. [Communication et contrôle](#communication-et-contrôle)
   - [veafRadio.lua](#veafradiolua) — Menus radio
8. [Systèmes de support](#systèmes-de-support)
   - [veafWeather.lua](#veafweatherlua) — Système météo
   - [veafTime.lua](#veaftimelua) — Gestion du temps
9. [Données et base de données](#données-et-base-de-données)
   - [dcsUnits.lua](#dcsunitslua) — Base de données d'unités DCS
   - [dcsDataExport.lua](#dcsdataexportlua) — Export de données
10. [Annexe](#annexe)

---

## Introduction

Les modules Lua VEAF (Virtual European Air Force) fournissent un framework complet pour créer des missions DCS World dynamiques. Cette référence API documente toutes les fonctions publiques, classes et constantes disponibles pour les créateurs de missions.

### Fonctionnalités clés

- **33+ modules Lua** fournissant des fonctionnalités runtime
- **Architecture événementielle** utilisant le système d'événements DCS World
- **Conception modulaire** permettant une utilisation sélective des modules
- **Logging extensif** avec niveaux configurables
- **Système de sécurité** pour un accès contrôlé
- **Intégration menus radio** via le menu F10
- **Commandes par marqueur** via les marqueurs carte

### Ordre de chargement des modules

Les modules doivent être chargés dans l'ordre de dépendance :
1. `veaf.lua` (core — doit être premier)
2. `veafEventHandler.lua`
3. `veafMarkers.lua`
4. Autres modules (ordre libre)

### Conventions utilisées

**Types de paramètres :**

- `string` — Chaîne de texte
- `number` — Valeur numérique
- `boolean` — true/false
- `table` — Table/tableau Lua
- `vec3` — Vecteur 3D : `{x=number, y=number, z=number}`
- `function` — Fonction callback
- `coalition` — ID de coalition : 0=neutre, **1=rouge, 2=bleu** (`coalition.side.RED` vaut 1 — voir la note ci-dessous)

!!! danger "`coalition.side` vaut RED=1, BLUE=2"

    ```lua
    coalition.side = { NEUTRAL = 0, RED = 1, BLUE = 2 }
    ```

    Une inversion de ces valeurs n'est attrapée par rien : du code écrit d'après un mauvais
    tableau compile, s'exécute, et vise silencieusement **le camp adverse**.


**Valeurs de retour :**

- Les fonctions retournent `nil` en cas d'échec sauf mention contraire
- Les retours booléens indiquent succès/échec

---

## Architecture des modules

### Structure standard d'un module

Tous les modules VEAF suivent ce patron :

```lua
-- Déclaration du module
veafModuleName = veafModuleName or {}

-- Métadonnées du module
veafModuleName.Id = "MODULE_ID"
veafModuleName.LogLevel = "info"  -- ou "debug", "trace"

-- Initialisation du logger
veafModuleName.logger = veaf.loggers.new(veafModuleName.Id, veafModuleName.LogLevel)

-- Fonction d'initialisation
function veafModuleName.initialize()
  veafModuleName.logger:info("Initializing module")
  -- Code d'initialisation
end

-- Fonction de démarrage (si applicable)
function veafModuleName.start()
  veafModuleName.logger:info("Starting module")
  -- Démarrage des services/monitoring
end
```

### Niveaux de logging

Tous les modules utilisent un logging standardisé :

| Niveau | Valeur | Utilisation |
|--------|--------|-------------|
| `error` | 1 | Erreurs critiques uniquement |
| `warning` | 2 | Avertissements et erreurs |
| `info` | 3 | Opérations normales (défaut) |
| `debug` | 4 | Débogage détaillé |
| `trace` | 5 | Traçage très verbeux |

**Configurer les niveaux de log :**
```lua
veafModuleName.LogLevel = "debug"
veaf.loggers.setBaseLevel("info")  -- Défaut global
```

---

## Infrastructure de base

### veaf.lua

**Module ID :** `VEAF`

**Objectif :** Bibliothèque racine fournissant les utilitaires de base, constantes et système de logger

#### Constantes

```lua
veaf.BuildVersion = "6.7.x+<sha>"  -- stamp de build (version package + sha git) injecté au build ; "dev" hors build
veaf.Development = false  -- Activer les fonctionnalités de développement
veaf.HideNamesFromSpawnedGroups = false
veaf.BaseLogLevel = 3  -- Niveau de log par défaut (info) ; sert de plafond pour les modules
veaf.DEFAULT_GROUND_SPEED_KPH = 30
veaf.DEFAULT_GROUND_SPEED_KTS = 16.2
veaf.DEFAULT_SPEED_KTS = 350
veaf.MIST_MARKER_ID_INITIAL_VALUE = 50000
```

#### Localisation (i18n) & retour pilote

Les messages en jeu destinés au pilote sont localisés (FR/EN). La langue active est `veaf.config.language` (issue de `mission.language`, sinon la langue résolue des outils au build, dont le repli final est `en`) ; les logs restent toujours en anglais.

##### `veaf.t(key, ...)`

Renvoie la chaîne localisée pour `key` depuis `veaf.i18nCatalog` (peuplé par `veafI18n.lua`), avec interpolation `string.format`. Repli : langue demandée → français → la clé elle-même (une entrée manquante ne plante jamais).

```lua
trigger.action.outText(veaf.t("spawn.group_spawned", group.description, country), 5)
```

##### `veaf.reportToPilot(message, duration, coalition)`

Affiche `message` en jeu. Avec une `coalition`, utilise `outTextForCoalition` ; sinon (ou `nil`), l'affiche à tous (`outText`). À utiliser pour le feedback de commande adressé à l'émetteur.

##### `veaf.nearestMatch(word, candidates, maxDistance)`

Renvoie la chaîne de `candidates` la plus proche dans la limite de `maxDistance` éditions de Levenshtein (ou `nil`). Sert à l'indice « vouliez-vous dire… ? » des paramètres de spawn.

##### `veaf.getRequesterCoalition(event)`

La coalition qui a émis une commande (poseur du marqueur / unité `veafInterpreter`), normalisée en `coalition.side.RED`/`.BLUE`, ou `nil` si inconnue/all. À utiliser pour le feedback pilote — **pas** pour décider le camp des unités spawnées.

##### `veaf.getOppositeCoalition(side)`

La coalition opposée — le camp par défaut des unités spawnées depuis un marqueur (RED↔BLUE ; neutre/all → RED). Passez un paramètre `side`/`country` explicite pour surcharger.

#### Fonctions JSON

##### `veaf.json.stringify(obj, as_key)`

Convertit un objet Lua en chaîne JSON.

**Paramètres :**

- `obj` (any) — Objet Lua à sérialiser
- `as_key` (boolean, optionnel) — Formater comme clé JSON

**Retourne :** `string` — Représentation JSON

**Exemple :**
```lua
local data = {name = "Strike", type = "mission"}
local json = veaf.json.stringify(data)
-- Résultat : '{"name":"Strike","type":"mission"}'
```

##### `veaf.json.parse(str, pos, end_delim)`

Parse une chaîne JSON en objet Lua.

**Paramètres :**

- `str` (string) — Chaîne JSON
- `pos` (number, optionnel) — Position de départ (défaut : 1)
- `end_delim` (string, optionnel) — Délimiteur de fin

**Retourne :** `table` — Objet Lua parsé

**Exemple :**
```lua
local json = '{"name":"Strike","type":"mission"}'
local data = veaf.json.parse(json)
-- Résultat : {name = "Strike", type = "mission"}
```

#### Utilitaires de chaînes

##### `veaf.trim(s)`

Supprime les espaces en début et fin de chaîne.

**Paramètres :**

- `s` (string) — Chaîne à nettoyer

**Retourne :** `string` — Chaîne nettoyée

**Exemple :**
```lua
local trimmed = veaf.trim("  hello  ")
-- Résultat : "hello"
```

##### `veaf.split(str, sep)`

Découpe une chaîne par séparateur en tableau.

**Paramètres :**

- `str` (string) — Chaîne à découper
- `sep` (string) — Caractère/chaîne séparateur

**Retourne :** `table` — Tableau de sous-chaînes

**Exemple :**
```lua
local parts = veaf.split("red,blue,green", ",")
-- Résultat : {"red", "blue", "green"}
```

##### `veaf.splitWithPattern(str, pat)`

Découpe une chaîne en utilisant un pattern regex.

**Paramètres :**

- `str` (string) — Chaîne à découper
- `pat` (string) — Pattern Lua

**Retourne :** `table` — Tableau de sous-chaînes

##### `veaf.breakString(str, sep)`

Coupe une chaîne autour d'un séparateur (retourne 2 parties).

**Paramètres :**

- `str` (string) — Chaîne à couper
- `sep` (string) — Séparateur

**Retourne :** `string, string` — Deux parties (avant et après le séparateur)

**Exemple :**
```lua
local before, after = veaf.breakString("key=value", "=")
-- Résultat : before="key", after="value"
```

##### `veaf.escapeRegex(stringToEscape)`

Échappe les caractères spéciaux regex.

**Paramètres :**

- `stringToEscape` (string) — Chaîne à échapper

**Retourne :** `string` — Chaîne échappée

#### Utilitaires de tables/tableaux

##### `veaf.length(T)`

Obtient la longueur d'une table (gère les clés non-séquentielles).

**Paramètres :**

- `T` (table) — Table à mesurer

**Retourne :** `number` — Nombre d'éléments

**Exemple :**
```lua
local t = {a=1, b=2, c=3}
local len = veaf.length(t)
-- Résultat : 3
```

##### `veaf.arrayRemoveWhen(t, fnKeep)`

Supprime les éléments d'un tableau selon une condition.

**Paramètres :**

- `t` (table) — Tableau à filtrer
- `fnKeep` (function) — Fonction de conservation : `function(element) return boolean end`

**Retourne :** `table` — Tableau modifié

**Exemple :**
```lua
local numbers = {1, 2, 3, 4, 5}
veaf.arrayRemoveWhen(numbers, function(n) return n > 3 end)
-- Résultat : {1, 2, 3}
```

##### `veaf.shuffle(tbl)`

Mélange aléatoirement les éléments d'un tableau en place.

**Paramètres :**

- `tbl` (table) — Tableau à mélanger

**Retourne :** `table` — Tableau mélangé (même référence)

##### `veaf.tableContains(table, element)`

Vérifie si une table contient un élément.

**Paramètres :**

- `table` (table) — Table à chercher
- `element` (any) — Élément à trouver

**Retourne :** `boolean` — True si trouvé

##### `veaf.randomlyChooseFrom(aTable, bias)`

Choisit un élément aléatoire dans une table avec biais optionnel.

**Paramètres :**

- `aTable` (table) — Table source
- `bias` (number, optionnel) — Facteur de biais (défaut : 1.0)

**Retourne :** `any` — Élément aléatoire

**Exemple :**
```lua
local colors = {"red", "blue", "green"}
local color = veaf.randomlyChooseFrom(colors)
```

#### Fonctions de vecteurs et coordonnées

##### `veaf.vecToString(vec)`

Convertit un vecteur 3D en chaîne lisible.

**Paramètres :**

- `vec` (vec3) — Vecteur `{x, y, z}`

**Retourne :** `string` — Chaîne formatée

**Exemple :**
```lua
local pos = {x=1000, y=50, z=2000}
local str = veaf.vecToString(pos)
-- Résultat : "x=1000, y=50, z=2000"
```

##### `veaf.findPointInZone(spawnSpot, dispersion, isShip)`

Trouve un point de spawn aléatoire dans une zone avec dispersion.

**Paramètres :**

- `spawnSpot` (vec3) — Position centrale
- `dispersion` (number) — Rayon en mètres
- `isShip` (boolean, optionnel) — Trouver un emplacement en eau

**Retourne :** `vec3` — Point aléatoire dans la zone

##### `veaf.placePointOnLand(vec3)`

Place un point sur la surface terrestre (ajuste l'altitude Y).

**Paramètres :**

- `vec3` (vec3) — Position à ajuster

**Retourne :** `vec3` — Position sur la surface

##### `veaf.findSpawnPoint(vec3, radius, safeRadius)`

Cherche un point d'apparition au sol acceptable près d'un centre. Là où `placePointOnLand`
déplace un point **verticalement**, celle-ci en **cherche** un.

La recherche dégrade en trois paliers bornés :

1. **Tous les critères, dégagement du décor inclus** — via le singleton DCS `Disposition`, qui
   rend des points à l'écart des bâtiments et des forêts.
2. **Tous les critères sauf le dégagement** — tirages aléatoires validés dans le rayon.
3. **Échec** — retourne `nil` ; l'appelant signale et abandonne l'apparition.

**Paramètres :**

- `vec3` (vec3) — Centre de la recherche
- `radius` (number) — Rayon de recherche en mètres, utilisé par le palier aléatoire
- `safeRadius` (number, optionnel) — Dégagement exigé (défaut `veaf.DEFAULT_SPAWN_CLEARANCE`)

**Retourne :** `vec3` posé sur le sol, ou `nil` si aucun point acceptable n'a été trouvé

**Réglages :**

- `veaf.SPAWN_SEARCH_ATTEMPTS` (défaut 10) — nombre de candidats examinés par palier
- `veaf.DEFAULT_SPAWN_CLEARANCE` (défaut 100) — dégagement demandé, en mètres
- `veaf.doNotAvoidScenery` (défaut `false`) — à `true`, saute le palier 1

> **Note :** `Disposition` est une API DCS **native mais non documentée**, absente de
> `dcs-world-schema`. L'appel est gardé et protégé par `pcall` : si le singleton est absent de
> cette version de DCS ou de cette carte, la recherche passe au palier 2 au lieu d'échouer.

##### `veaf.getLandHeight(vec3)`

Obtient la hauteur du terrain aux coordonnées.

**Paramètres :**

- `vec3` (vec3) — Position

**Retourne :** `number` — Altitude du terrain en mètres

##### `veaf.headingBetweenPoints(point1, point2)`

Calcule le cap de point1 vers point2.

**Paramètres :**

- `point1` (vec3) — Point de départ
- `point2` (vec3) — Point de destination

**Retourne :** `number` — Cap en degrés (0-360)

##### `veaf.getBearingAndRangeFromTo(fromPoint, toPoint)`

Calcule le relèvement et la distance entre deux points.

**Paramètres :**

- `fromPoint` (vec3) — Point de départ
- `toPoint` (vec3) — Point de destination

**Retourne :** `number, number` — Relèvement (degrés), Distance (mètres)

**Exemple :**
```lua
local bearing, range = veaf.getBearingAndRangeFromTo(pos1, pos2)
veaf.logger:info("Cible au %d° pour %.0f mètres", bearing, range)
```

##### `veaf.computeLLFromString(value)`

Parse une latitude/longitude depuis une chaîne.

**Paramètres :**

- `value` (string) — Chaîne Lat/Lon (plusieurs formats supportés)

**Retourne :** `table` — `{lat=number, lon=number}` ou nil

**Formats supportés :**

- DMS : `N 43°15'30" E 005°45'20"`
- Décimal : `43.258333, 5.755556`
- MGRS : (via conversion)

##### `veaf.computeCoordinatesOffsetFromRoute(startingPoint, destinationPoint, distanceFromStartingPoint, offset)`

Calcule une position décalée par rapport à une route.

**Paramètres :**

- `startingPoint` (vec3) — Début de route
- `destinationPoint` (vec3) — Fin de route
- `distanceFromStartingPoint` (number) — Distance le long de la route (mètres)
- `offset` (number) — Décalage perpendiculaire (mètres, positif = droite)

**Retourne :** `vec3` — Position décalée

#### Fonctions d'unités et groupes

##### `veaf.addUnit(group, spawnSpot, dispersion, unitType, unitName, skill)`

Ajoute une unité à une définition de groupe.

**Paramètres :**

- `group` (table) — Table de définition du groupe
- `spawnSpot` (vec3) — Position de spawn
- `dispersion` (number) — Rayon de dispersion (mètres)
- `unitType` (string) — Nom de type DCS de l'unité
- `unitName` (string) — Nom de l'unité
- `skill` (string) — Niveau de compétence : "Average", "Good", "High", "Excellent", "Random"

**Retourne :** `table` — Table de groupe modifiée

##### `veaf.getAveragePosition(group)`

Obtient la position centrale du groupe.

**Paramètres :**

- `group` (table ou DCS Group) — Objet groupe ou table

**Retourne :** `vec3` — Position moyenne

##### `veaf.getAvgGroupPos(groupName)`

Obtient la position moyenne d'un groupe par son nom.

**Paramètres :**

- `groupName` (string) — Nom du groupe

**Retourne :** `vec3` — Position moyenne ou nil

##### `veaf.moveGroupAt(groupName, leadUnitName, heading, speed, timeInSeconds, endPosition, pMiddlePointDistance)`

Déplace un groupe dans une direction et à une vitesse spécifiques.

**Paramètres :**

- `groupName` (string) — Groupe à déplacer
- `leadUnitName` (string) — Nom de l'unité leader
- `heading` (number) — Direction en degrés
- `speed` (number) — Vitesse en m/s
- `timeInSeconds` (number) — Durée du déplacement
- `endPosition` (vec3, optionnel) — Position finale
- `pMiddlePointDistance` (number, optionnel) — Distance du waypoint intermédiaire

**Retourne :** `boolean` — Indicateur de succès

##### `veaf.moveGroupTo(groupName, pos, speed, altitude)`

Déplace un groupe vers une position.

**Paramètres :**

- `groupName` (string) — Nom du groupe
- `pos` (vec3) — Destination
- `speed` (number, optionnel) — Vitesse en m/s (défaut : 30 kph)
- `altitude` (number, optionnel) — Altitude forcée

**Retourne :** `boolean` — Succès

##### `veaf.readyForCombat(group, alarm, disperseTime)`

Prépare un groupe terrestre au combat.

**Paramètres :**

- `group` (DCS Group ou string) — Groupe ou nom de groupe
- `alarm` (boolean, optionnel) — État d'alerte (défaut : false)
- `disperseTime` (number, optionnel) — Temps de dispersion en secondes

**Retourne :** Rien

**Description :** Met le groupe en état prêt au combat, disperse optionnellement les unités.

##### `veaf.getGroupsOfCoalition(coa)`

Obtient tous les groupes d'une coalition.

**Paramètres :**

- `coa` (coalition, optionnel) — Filtre de coalition (défaut : tous)

**Retourne :** `table` — Tableau d'objets DCS Group

##### `veaf.getUnitsOfCoalition(includeStatics, coa)`

Obtient toutes les unités d'une coalition.

**Paramètres :**

- `includeStatics` (boolean) — Inclure les objets statiques
- `coa` (coalition, optionnel) — Filtre de coalition

**Retourne :** `table` — Tableau d'objets unités/statiques

##### `veaf.findUnitsInCircle(center, radius, includeStatics, onlyTheseUnits)`

Trouve les unités dans une zone circulaire.

**Paramètres :**

- `center` (vec3) — Centre du cercle
- `radius` (number) — Rayon en mètres
- `includeStatics` (boolean, optionnel) — Inclure les statiques
- `onlyTheseUnits` (table, optionnel) — Filtrer à ces unités uniquement

**Retourne :** `table` — Tableau d'unités/statiques

**Exemple :**
```lua
local targetPos = {x=1000, y=0, z=2000}
local enemyUnits = veaf.findUnitsInCircle(targetPos, 500, false)
veaf.logger:info("Trouvé %d unités ennemies", #enemyUnits)
```

##### `veaf.isUnitInZone(unitOrName, zoneOrName)`

Vérifie si une unité est dans une zone trigger.

**Paramètres :**

- `unitOrName` (DCS Unit ou string) — Unité ou nom d'unité
- `zoneOrName` (DCS Zone ou string) — Zone ou nom de zone

**Retourne :** `boolean` — True si dans la zone

##### `veaf.isUnitAlive(unit)`

Vérifie si une unité est en vie.

**Paramètres :**

- `unit` (DCS Unit ou string) — Unité ou nom d'unité

**Retourne :** `boolean` — True si en vie

##### `veaf.getUnitLifeRelative(unit)`

Obtient la santé d'une unité en pourcentage.

**Paramètres :**

- `unit` (DCS Unit ou string) — Unité ou nom d'unité

**Retourne :** `number` — Pourcentage de santé (0-100)

##### `veaf.fixUnitsTable(unitsOrNames)`

Convertit les noms d'unités en objets unités.

**Paramètres :**

- `unitsOrNames` (table) — Tableau d'unités ou noms d'unités

**Retourne :** `table` — Tableau d'objets unités

#### Génération de routes

##### `veaf.generateVehiclesRoute(startPoint, destination, onRoad, speed, groupName)`

Génère une route de déplacement véhicule.

**Paramètres :**

- `startPoint` (vec3) — Position de départ
- `destination` (vec3) — Position de destination
- `onRoad` (boolean) — Utiliser les routes si possible
- `speed` (number) — Vitesse en m/s
- `groupName` (string, optionnel) — Nom du groupe pour le logging

**Retourne :** `table` — Table de route

**Structure de la table de route :**
```lua
{
  [1] = {
    x = number,
    y = number,
    action = "On Road" or "Off Road",
    speed = number,
    type = "Turning Point"
  },
  -- ... plus de waypoints
}
```

##### `veaf.PatrolWatchdog(groupName, patrolRoute, speed, firstPass)`

Surveille une route de patrouille et la répète.

**Paramètres :**

- `groupName` (string) — Nom du groupe
- `patrolRoute` (table) — Table de route
- `speed` (number) — Vitesse en m/s
- `firstPass` (boolean) — Est la première itération

**Retourne :** Rien (se reprogramme automatiquement)

#### Fonctions d'information

##### `veaf.getTankerData(tankerGroupName)`

Obtient les informations d'un ravitailleur.

**Paramètres :**

- `tankerGroupName` (string) — Nom du groupe ravitailleur

**Retourne :** `table` — Structure de données ravitailleur

**Structure de données ravitailleur :**
```lua
{
  name = "Texaco-1",
  type = "KC-135",
  TACANchannel = "61X",
  TACANfrequency = "1088 MHz",
  TACANmorse = "...",
  RadioFrequency = "251.0 MHz",
  RadioModulation = "AM",
  callsign = "Texaco 1-1",
  position = vec3
}
```

##### `veaf.getCarrierATCdata(carrierGroupName, carrierUnitName)`

Obtient les données ATC d'un porte-avions.

**Paramètres :**

- `carrierGroupName` (string) — Nom du groupe porte-avions
- `carrierUnitName` (string, optionnel) — Nom d'unité spécifique

**Retourne :** `table` — Données ATC

**Structure de données ATC :**
```lua
{
  name = "CVN-73",
  callsign = "Mother",
  RadioFrequency = "127.5 MHz",
  RadioModulation = "AM",
  TACANchannel = "73X",
  TACANfrequency = "1205 MHz",
  TACANmorse = "...",
  ICLS = "13",
  position = vec3,
  heading = number
}
```

##### `veaf.getGroupData(groupIdent)`

Obtient les données brutes DCS d'un groupe.

**Paramètres :**

- `groupIdent` (string ou number) — Nom ou ID du groupe

**Retourne :** `table` — Table de données DCS du groupe

##### `veafWeatherData.getWeatherString(vec3, dcsElementName, unitSystem, iSurfaceAltitudeMeters)`

Génère un rapport météo sous forme de texte pour une position. Le système d'unités et l'inclusion des données LASTE sont déduits de l'élément DCS fourni (ex. : un A-10 active automatiquement le LASTE).

**Paramètres :**

- `vec3` (vec3) — Position pour le rapport
- `dcsElementName` (string, optionnel) — Nom d'un élément DCS (unité/base) servant à déduire le système d'unités et le LASTE
- `unitSystem` (string, optionnel) — Système d'unités ; par défaut déduit de l'élément
- `iSurfaceAltitudeMeters` (number, optionnel) — Altitude du sol en mètres

**Retourne :** `string` — Texte du rapport météo

**Exemple de sortie :**
```
Weather at position:
QNH: 29.92 inHg (1013 hPa)
Temperature: 15°C (59°F)
Wind: 270° at 10 kts
```

#### Fonctions de sortie

##### `veaf.outTextForUnit(unitName, message, duration, forAllGroup)`

Affiche un message texte à une unité.

**Paramètres :**

- `unitName` (string) — Nom de l'unité cible
- `message` (string) — Texte du message
- `duration` (number, optionnel) — Durée d'affichage en secondes (défaut : 5)
- `forAllGroup` (boolean, optionnel) — Afficher à tous les membres du groupe

**Retourne :** Rien

**Exemple :**
```lua
veaf.outTextForUnit("Viper 1-1", "Cible détruite !", 10, true)
```

##### `veaf.outTextForGroup(unitName, message, duration)`

Affiche un texte à tout le groupe.

**Paramètres :**

- `unitName` (string) — N'importe quelle unité du groupe
- `message` (string) — Texte du message
- `duration` (number, optionnel) — Durée en secondes

**Retourne :** Rien

#### Fonctions de conversion

##### `veaf.convertMachSpeed(mach, altitude, temperature)`

Convertit un nombre Mach en vitesse vraie (TAS).

**Paramètres :**

- `mach` (number) — Nombre Mach
- `altitude` (number) — Altitude en mètres
- `temperature` (number, optionnel) — Écart de température en °C

**Retourne :** `number` — Vitesse vraie en nœuds

##### `veaf.convertTrueAirSpeed(ktas, altitude, temperature)`

Convertit une vitesse vraie en Mach.

**Paramètres :**

- `ktas` (number) — Vitesse vraie en nœuds
- `altitude` (number) — Altitude en mètres
- `temperature` (number, optionnel) — Écart de température

**Retourne :** `number` — Nombre Mach

##### `veaf.convertSpeeds(mach, kias, ktas, altitude, temperature, pressure)`

Convertit entre formats de vitesse.

**Paramètres :**

- `mach` (number, optionnel) — Nombre Mach
- `kias` (number, optionnel) — Vitesse indiquée (nœuds)
- `ktas` (number, optionnel) — Vitesse vraie (nœuds)
- `altitude` (number) — Altitude en mètres
- `temperature` (number, optionnel) — Écart de température
- `pressure` (number, optionnel) — Pression en hPa

**Retourne :** `table` — `{mach, kias, ktas}`

**Exemple :**
```lua
local speeds = veaf.convertSpeeds(0.9, nil, nil, 10000)
-- Résultat : {mach=0.9, kias=calculé, ktas=calculé}
```

##### `veaf.getMagneticDeclination()`

Obtient la déclinaison magnétique du théâtre actuel.

**Retourne :** `number` — Déclinaison en degrés

##### `veaf.getWind(point)`

Obtient le vent à une position.

**Paramètres :**

- `point` (vec3) — Position

**Retourne :** `table` — `{direction=number, strength=number}`

#### Fonctions mathématiques et utilitaires

##### `veaf.round(num, numDecimalPlaces)`

Arrondit un nombre à un nombre de décimales.

**Paramètres :**

- `num` (number) — Nombre à arrondir
- `numDecimalPlaces` (number, optionnel) — Nombre de décimales (défaut : 0)

**Retourne :** `number` — Nombre arrondi

##### `veaf.getRandomizableNumeric(val)`

Parse une valeur numérique randomisable.

**Paramètres :**

- `val` (string ou number) — Valeur comme "2-6" ou "5"

**Retourne :** `number` — Valeur aléatoire dans la plage

**Exemple :**
```lua
local size = veaf.getRandomizableNumeric("3-7")
-- Résultat : Nombre aléatoire entre 3 et 7
```

##### `veaf.invertHeading(heading)`

Obtient le cap opposé.

**Paramètres :**

- `heading` (number) — Cap en degrés

**Retourne :** `number` — Cap opposé (0-360)

##### `veaf.laserCodeToDigit(code)`

Convertit un code laser en chiffre.

**Paramètres :**

- `code` (number) — Code laser (ex : 1688)

**Retourne :** `number` — Représentation en chiffre

#### Fonctions pays et coalition

##### `veaf.getCountryId(countryName)`

Obtient l'ID pays DCS à partir du nom.

**Paramètres :**

- `countryName` (string) — Nom du pays (ex : "USA", "Russia")

**Retourne :** `number` — ID du pays ou nil

##### `veaf.getCountryName(countryId)`

Obtient le nom du pays à partir de l'ID.

**Paramètres :**

- `countryId` (number) — ID pays DCS

**Retourne :** `string` — Nom du pays

##### `veaf.getCountryForCoalition(coalition)`

Obtient le pays par défaut pour une coalition.

**Paramètres :**

- `coalition` (coalition) — ID de coalition

**Retourne :** `number` — ID du pays

**Mapping par défaut :**

- Bleu → USA (2)
- Rouge → Russie (0)

##### `veaf.getCoalitionForCountry(countryName, asNumber)`

Obtient la coalition pour un pays.

**Paramètres :**

- `countryName` (string) — Nom du pays
- `asNumber` (boolean, optionnel) — Retourner comme nombre au lieu d'objet coalition

**Retourne :** `coalition` ou `number` — Coalition

##### `veaf.getAirbaseForCoalition(airbase_name, coa)`

Obtient l'objet aérodrome pour une coalition.

**Paramètres :**

- `airbase_name` (string) — Nom de l'aérodrome
- `coa` (coalition) — Coalition

**Retourne :** `DCS Airbase` — Objet aérodrome ou nil

#### Fonctions aérodromes

##### `veaf.findDcsAirbase(name)`

Trouve un aérodrome DCS par nom (insensible à la casse).

**Paramètres :**

- `name` (string) — Nom de l'aérodrome

**Retourne :** `DCS Airbase` — Objet aérodrome ou nil

##### `veaf.silenceAtcOnAllAirbases()`

Désactive l'ATC sur tous les aérodromes.

**Retourne :** Rien

**Description :** Utile pour l'immersion ou pour éviter les conflits ATC.

##### `veaf.loadAirbasesLife0()`

Charge les données de santé initiale des aérodromes.

**Retourne :** Rien

**Description :** Doit être appelé avant d'utiliser `veaf.getAirbaseLife()`.

##### `veaf.getAirbaseLife(airbase_name, percentage, loading)`

Obtient la santé/dommages d'un aérodrome.

**Paramètres :**

- `airbase_name` (string) — Nom de l'aérodrome
- `percentage` (boolean, optionnel) — Retourner en pourcentage
- `loading` (boolean, optionnel) — Chargement des données initiales

**Retourne :** `number` — Valeur de santé (0-1 ou 0-100 si pourcentage)

##### `veaf.getPolygonFromUnits(unitNames)`

Crée un polygone à partir des positions d'unités.

**Paramètres :**

- `unitNames` (table) — Tableau de noms d'unités

**Retourne :** `table` — Tableau de positions vec3

#### Fonctions de zones trigger

##### `veaf.getTriggerZone(zoneName)`

Obtient une zone trigger par nom.

**Paramètres :**

- `zoneName` (string) — Nom de la zone

**Retourne :** `DCS Zone` — Objet zone ou nil

##### `veaf.getZoneProperty(zoneName, key)`

Lit une propriété de zone trigger, telle que saisie par le mission maker dans l'éditeur.

DCS stocke ces propriétés sous forme de **tableau de paires** `{ key = "…", value = "…" }`,
jamais de dictionnaire, et **toute valeur est une chaîne**. Ces trois accesseurs remplacent le
parcours linéaire et le `tonumber` que chaque appelant devrait écrire.

**Paramètres :**

- `zoneName` (string) — Nom de la zone
- `key` (string) — Nom de la propriété

**Retourne :** `string` — ou `nil` si la zone, ses propriétés ou la clé sont absentes

##### `veaf.getZonePropertyBoolean(zoneName, key, default)`

Lit une propriété comme booléen. Accepte `true`/`false` sans distinction de casse ; toute autre
valeur est un échec de lecture et rend `default` — une coquille ne peut donc pas se lire
silencieusement comme `false`.

**Paramètres :**

- `zoneName` (string) — Nom de la zone
- `key` (string) — Nom de la propriété
- `default` (boolean) — Valeur rendue si absente ou illisible

**Retourne :** `boolean`

##### `veaf.getZonePropertyNumber(zoneName, key, default, min, max)`

Lit une propriété comme nombre, **borné** dans un intervalle optionnel. Borne au lieu de
rejeter : un mission maker qui saisit une valeur absurde obtient la borne, pas un module mort.

**Paramètres :**

- `zoneName` (string) — Nom de la zone
- `key` (string) — Nom de la propriété
- `default` (number) — Valeur rendue si absente ou non numérique
- `min` (number, optionnel) — Borne basse
- `max` (number, optionnel) — Borne haute

**Retourne :** `number`

#### Fonctions de contrôle de mission

##### `veaf.endMissionAt(endTimeHour, endTimeMinute, checkIntervalInSeconds, checkMessage, ...)`

Planifie la fin de mission à une heure spécifique.

**Paramètres :**

- `endTimeHour` (number) — Heure (0-23)
- `endTimeMinute` (number) — Minute (0-59)
- `checkIntervalInSeconds` (number) — Fréquence de vérification
- `checkMessage` (string, optionnel) — Message à afficher
- Paramètres additionnels pour le formatage du message

**Retourne :** Rien

**Exemple :**
```lua
-- Fin de mission à 14:30
veaf.endMissionAt(14, 30, 60, "La mission se termine à %s")
```

##### `veaf.getDcsTypeName(dcsElementName)`

Obtient le nom de type DCS d'un élément.

**Paramètres :**

- `dcsElementName` (string) — Nom de l'élément DCS

**Retourne :** `string` — Nom de type

#### Fonctions de sérialisation

##### `veaf.p(o, level, skip, includeMeta, dontRecurse)`

Sérialise/affiche joliment un objet.

**Paramètres :**

- `o` (any) — Objet à sérialiser
- `level` (number, optionnel) — Niveau d'indentation
- `skip` (table, optionnel) — Clés à ignorer
- `includeMeta` (boolean, optionnel) — Inclure les métatables
- `dontRecurse` (table, optionnel) — Objets à ne pas parcourir récursivement

**Retourne :** `string` — Représentation sérialisée

**Exemple :**
```lua
local data = {name = "Strike", units = {1, 2, 3}}
local str = veaf.p(data)
print(str)
-- Sortie :
-- {
--   name = "Strike",
--   units = {
--     [1] = 1,
--     [2] = 2,
--     [3] = 3
--   }
-- }
```

##### `veaf.serialize(name, value, level)`

Sérialise une valeur en code Lua.

**Paramètres :**

- `name` (string) — Nom de variable
- `value` (any) — Valeur à sérialiser
- `level` (number, optionnel) — Niveau d'indentation

**Retourne :** `string` — Chaîne de code Lua

##### `veaf.exportAsJson(data, name, jsonify, filename, export_path)`

Exporte des données vers un fichier JSON.

**Paramètres :**

- `data` (any) — Données à exporter
- `name` (string) — Nom de variable
- `jsonify` (boolean) — Convertir en JSON (vs Lua)
- `filename` (string, optionnel) — Nom du fichier de sortie
- `export_path` (string, optionnel) — Répertoire d'export

**Retourne :** `boolean` — Indicateur de succès

**Exemple :**
```lua
local missions = {
  {name = "CAP Alpha", type = "air"},
  {name = "Strike Bravo", type = "ground"}
}
veaf.exportAsJson(missions, "missions", true, "missions.json")
```

#### Classe Logger

La classe `veaf.Logger` fournit un logging structuré avec des niveaux.

##### Créer des loggers

```lua
-- Loggers globaux
veaf.loggers.setBaseLevel("info")  -- Définir le niveau par défaut
local logger = veaf.loggers.new("MYMODULE", "debug")  -- Créer un logger
local existingLogger = veaf.loggers.get("MYMODULE")  -- Obtenir un existant

-- Loggers d'instance
local myLogger = veaf.Logger:new("MYMODULE", "info")
```

##### Méthodes du logger

**`logger:setName(value)`**

Définit le nom du logger.

**`logger:setLevel(value, force)`**

Définit le niveau de logging.

**Paramètres :**

- `value` (string ou number) — Niveau : "error", "warning", "info", "debug", "trace"
- `force` (boolean, optionnel) — Forcer le dépassement du niveau de base

**`logger:error(text, ...)`**

Logue un message d'erreur (niveau 1).

**Paramètres :**

- `text` (string) — Message avec marqueurs de format
- `...` — Arguments de format

**Exemple :**
```lua
logger:error("Échec du spawn %s à la position %s", groupName, veaf.vecToString(pos))
```

**`logger:warn(text, ...)`**

Logue un avertissement (niveau 2).

**`logger:info(text, ...)`**

Logue un message d'info (niveau 3).

**`logger:debug(text, ...)`**

Logue un message de débogage (niveau 4).

**`logger:trace(text, ...)`**

Logue un message de trace (niveau 5).

**`logger:wouldLogDebug()`**

Vérifie si le logging debug est activé.

**Retourne :** `boolean`

**`logger:wouldLogTrace()`**

Vérifie si le logging trace est activé.

**Retourne :** `boolean`

**Usage :**
```lua
if logger:wouldLogTrace() then
  -- Logging trace coûteux
  logger:trace("Données complexes : %s", veaf.p(largeTable))
end
```

##### Marqueurs carte pour le logging

**`logger:marker(id, header, message, position, markersTable, radius, fillColor)`**

Ajoute un marqueur carte pour le débogage.

**Paramètres :**

- `id` (number) — ID du marqueur
- `header` (string) — Texte d'en-tête
- `message` (string) — Message du marqueur
- `position` (vec3) — Position du marqueur
- `markersTable` (table, optionnel) — Suivi des marqueurs dans une table
- `radius` (number, optionnel) — Rayon du cercle
- `fillColor` (table, optionnel) — Couleur de remplissage `{r, g, b, a}`

**Retourne :** Rien

**`logger:markerArrow(id, header, message, positionStart, positionEnd, markersTable, lineType, fillColor)`**

Ajoute un marqueur flèche.

**Paramètres :**

- `id` (number) — ID du marqueur
- `header` (string) — Texte d'en-tête
- `message` (string) — Message
- `positionStart` (vec3) — Début de la flèche
- `positionEnd` (vec3) — Fin de la flèche
- `markersTable` (table, optionnel) — Suivi des marqueurs
- `lineType` (number, optionnel) — Type de ligne
- `fillColor` (table, optionnel) — Couleur

**`logger:markerQuad(id, header, message, points, markersTable, lineType, fillColor)`**

Ajoute un marqueur quadrilatère.

**Paramètres :**

- `id` (number) — ID du marqueur
- `header` (string) — En-tête
- `message` (string) — Message
- `points` (table) — Tableau de 4 points vec3
- `markersTable` (table, optionnel) — Suivi des marqueurs
- `lineType` (number, optionnel) — Type de ligne
- `fillColor` (table, optionnel) — Couleur

---

### veafEventHandler.lua

**Module ID :** `EVENTS`

**Objectif :** Gestion des événements DCS World et des callbacks

#### Constantes

##### Types d'événements

```lua
veafEventHandler.EVENTS = {
  [0] = "S_EVENT_INVALID",
  [1] = "S_EVENT_SHOT",
  [2] = "S_EVENT_HIT",
  [3] = "S_EVENT_TAKEOFF",
  [4] = "S_EVENT_LAND",
  [5] = "S_EVENT_CRASH",
  [6] = "S_EVENT_EJECTION",
  [7] = "S_EVENT_REFUELING",
  [8] = "S_EVENT_DEAD",
  [9] = "S_EVENT_PILOT_DEAD",
  [10] = "S_EVENT_BASE_CAPTURED",
  [11] = "S_EVENT_MISSION_START",
  [12] = "S_EVENT_MISSION_END",
  [13] = "S_EVENT_TOOK_CONTROL",
  [14] = "S_EVENT_REFUELING_STOP",
  [15] = "S_EVENT_BIRTH",
  [16] = "S_EVENT_HUMAN_FAILURE",
  [17] = "S_EVENT_DETAILED_FAILURE",
  [18] = "S_EVENT_ENGINE_STARTUP",
  [19] = "S_EVENT_ENGINE_SHUTDOWN",
  [20] = "S_EVENT_PLAYER_ENTER_UNIT",
  [21] = "S_EVENT_PLAYER_LEAVE_UNIT",
  [22] = "S_EVENT_PLAYER_COMMENT",
  [23] = "S_EVENT_SHOOTING_START",
  [24] = "S_EVENT_SHOOTING_END",
  [25] = "S_EVENT_MARK_ADDED",
  [26] = "S_EVENT_MARK_CHANGE",
  [27] = "S_EVENT_MARK_REMOVED",
  [28] = "S_EVENT_KILL",
  [29] = "S_EVENT_SCORE",
  [30] = "S_EVENT_UNIT_LOST",
  [31] = "S_EVENT_LANDING_AFTER_EJECTION",
  [32] = "S_EVENT_PARATROOPER_LENDING",
  [33] = "S_EVENT_DISCARD_CHAIR_AFTER_EJECTION",
  [34] = "S_EVENT_WEAPON_ADD",
  [35] = "S_EVENT_TRIGGER_ZONE",
  -- ... jusqu'à l'événement 61
}
```

##### Délai de callback

```lua
veafEventHandler.CALLBACK_DELAY = 0.5  -- secondes
```

#### Fonctions

##### `veafEventHandler.addCallback(name, events, callback)`

Enregistre une fonction callback d'événement.

**Paramètres :**

- `name` (string) — Nom unique du callback
- `events` (table ou nil) — Tableau d'ID/noms d'événements, ou nil pour tous
- `callback` (function) — Fonction callback

**Signature du callback :**
```lua
function callback(transformedEvent)
  -- transformedEvent est une table d'événement enrichie
end
```

**Retourne :** `boolean` — True si enregistré avec succès

**Exemple :**
```lua
-- Écouter tous les événements
veafEventHandler.addCallback("myHandler", nil, function(event)
  veaf.logger:info("Événement : %s", event.type.name)
end)

-- Écouter des événements spécifiques
veafEventHandler.addCallback("birthHandler",
  {"S_EVENT_BIRTH", "S_EVENT_PLAYER_ENTER_UNIT"},
  function(event)
    if event.initiator then
      veaf.logger:info("Unité apparue : %s", event.initiator.unitName)
    end
  end
)

-- Écouter par ID d'événement
veafEventHandler.addCallback("shotHandler", {1, 23}, function(event)
  -- Gère S_EVENT_SHOT et S_EVENT_SHOOTING_START
end)
```

##### `veafEventHandler.completeUnit(unit)`

Obtient les informations complètes d'une unité DCS.

**Paramètres :**

- `unit` (DCS Unit) — Objet unité

**Retourne :** `table` — Table d'info unité

**Structure de l'info unité :**
```lua
{
  unitName = "Viper 1-1",
  unitCallsign = "Viper11",
  unitType = "F-16C_50",
  unitGroupName = "Viper Flight",
  unitGroupId = 123,
  unitCoalition = coalition.side.BLUE,
  unitCategory = Unit.Category.AIRPLANE,
  unitPilotName = "Nom du joueur",  -- si humain
  unitPilotUcid = "abc123...",       -- si humain avec SRS
  unitLifePercent = 100.0
}
```

##### `veafEventHandler.completeUnitFromName(unitName)`

Obtient les informations d'unité à partir du nom.

**Paramètres :**

- `unitName` (string) — Nom de l'unité

**Retourne :** `table` — Table d'info unité (même structure que completeUnit)

**Exemple :**
```lua
local unitInfo = veafEventHandler.completeUnitFromName("Viper 1-1")
if unitInfo then
  veaf.logger:info("L'unité %s est à %.0f%% de vie",
    unitInfo.unitName, unitInfo.unitLifePercent)
end
```

##### `veafEventHandler.checkEventKnown(eventNameOrId, warnOnly)`

Vérifie qu'un événement est reconnu par DCS.

**Paramètres :**

- `eventNameOrId` (string ou number) — Nom ou ID de l'événement
- `warnOnly` (boolean, optionnel) — Émet seulement un avertissement, sans erreur

**Retourne :** `boolean` — True si l'événement est connu

##### `veafEventHandler.setEventEnabled(eventNameOrId, enabled)`

Active ou désactive le traitement d'un événement.

**Paramètres :**

- `eventNameOrId` (string ou number) — Événement à contrôler
- `enabled` (boolean) — Indicateur d'activation

**Retourne :** Rien

**Exemple :**
```lua
-- Désactiver les événements de tir pour les performances
veafEventHandler.setEventEnabled("S_EVENT_SHOOTING_START", false)
veafEventHandler.setEventEnabled("S_EVENT_SHOOTING_END", false)
```

##### `veafEventHandler.isEventEnabled(eventNameOrId)`

Vérifie si le traitement d'un événement est activé.

**Paramètres :**

- `eventNameOrId` (string ou number) — Événement à vérifier

**Retourne :** `boolean` — True si activé

##### `veafEventHandler.isEventDelayedCallback(eventNameOrId)`

Vérifie si un événement utilise un callback différé.

**Paramètres :**

- `eventNameOrId` (string ou number) — Événement à vérifier

**Retourne :** `boolean` — True si différé

**Description :** Certains événements comme BIRTH nécessitent des callbacks différés pour laisser DCS initialiser complètement les objets.

##### `veafEventHandler.initialize()`

Initialise le système de gestion des événements.

**Retourne :** Rien

**Description :** Appelé automatiquement lors de l'initialisation VEAF. Enregistre le handler d'événements DCS world.

#### Structure d'événement enrichi

Les événements passés aux callbacks sont enrichis de champs supplémentaires :

```lua
{
  -- Champs d'événement DCS originaux
  id = number,                    -- ID événement DCS
  time = number,                  -- Temps mission
  initiator = DCS_Unit,           -- Unité ayant déclenché l'événement
  target = DCS_Unit,              -- Unité cible (si applicable)
  weapon = DCS_Weapon,            -- Objet arme (si applicable)
  place = DCS_Airbase,            -- Aérodrome (pour décollage/atterrissage)

  -- Enrichissements VEAF
  type = {                        -- Info type d'événement
    id = number,
    name = "S_EVENT_XXX",
    definition = event_definition
  },
  idx = number,                   -- Index de l'événement
  coordinates = vec3,             -- Position de l'événement
  text = string,                  -- Texte marqueur (pour événements marqueur)
  coalition = coalition,          -- ID coalition
  groupId = number,               -- ID du groupe

  -- Info unité enrichie (si initiator existe)
  initiator = {
    unitName = string,
    unitCallsign = string,
    unitType = string,
    unitGroupName = string,
    unitGroupId = number,
    unitCoalition = coalition,
    unitCategory = category,
    unitPilotName = string,       -- si humain
    unitPilotUcid = string,       -- si humain
    unitLifePercent = number
  },

  -- Info cible enrichie (si target existe)
  target = {
    -- même structure que initiator
  },

  -- Info arme (si une arme a tiré/touché)
  weaponName = string,            -- Nom du type d'arme

  -- Champs d'événement marqueur
  comment = string                -- Texte du commentaire de marqueur
}
```

#### Bonnes pratiques de gestion des événements

**Performance :**

- Désactiver les événements inutilisés pour réduire la charge
- Utiliser les callbacks différés pour les opérations coûteuses
- Filtrer les événements par type lors de l'enregistrement des callbacks

**Timing des événements :**

- Les événements BIRTH se déclenchent avant que les unités soient complètement initialisées
- Utiliser les callbacks différés pour BIRTH si vous accédez aux propriétés de l'unité
- PLAYER_ENTER_UNIT se déclenche après le chargement complet du joueur

**Exemple : handler d'événements complet :**
```lua
-- Suivre les kills des joueurs
local playerKills = {}

veafEventHandler.addCallback("killTracker", {"S_EVENT_KILL"}, function(event)
  if event.initiator and event.initiator.unitPilotName then
    -- Un joueur humain a réalisé un kill
    local playerName = event.initiator.unitPilotName
    playerKills[playerName] = (playerKills[playerName] or 0) + 1

    local targetName = "unknown"
    if event.target and event.target.unitName then
      targetName = event.target.unitName
    end

    veaf.outTextForUnit(event.initiator.unitName,
      string.format("Kill confirmed! Total: %d", playerKills[playerName]),
      10, false)

    veaf.logger:info("%s killed %s (total kills: %d)",
      playerName, targetName, playerKills[playerName])
  end
end)
```

---

### veafMarkers.lua

**Module ID :** `MARKERS`

**Objectif :** Écouter les événements de marqueurs carte et exécuter des handlers

#### Constantes

```lua
veafMarkers.MarkerAdd = 1       -- Événement ajout de marqueur
veafMarkers.MarkerChange = 2    -- Événement modification de marqueur
veafMarkers.MarkerRemove = 3    -- Événement suppression de marqueur
veafMarkers.DCSbugfixed = true  -- Statut du bug marqueur DCS
```

#### Fonctions

##### `veafMarkers.registerEventHandler(eventType, eventHandler)`

Enregistre un handler pour les événements marqueur.

**Paramètres :**

- `eventType` (number) — Type d'événement : `MarkerAdd`, `MarkerChange` ou `MarkerRemove`
- `eventHandler` (function) — Fonction handler

**Signature du handler :**
```lua
function eventHandler(vec3_position, event)
  -- vec3_position : position du marqueur
  -- event : table d'événement DCS
end
```

**Retourne :** `number` — ID du handler pour désenregistrement

**Exemple :**
```lua
-- Écouter les ajouts de marqueurs
local handlerId = veafMarkers.registerEventHandler(
  veafMarkers.MarkerAdd,
  function(pos, event)
    local text = event.text or ""
    if text:match("^_spawn") then
      veaf.logger:info("Marqueur spawn à %s", veaf.vecToString(pos))
    end
  end
)
```

##### `veafMarkers.unregisterEventHandler(id)`

Supprime un handler d'événement marqueur.

**Paramètres :**

- `id` (number) — ID du handler depuis registerEventHandler

**Retourne :** `boolean` — True si désenregistré avec succès

**Exemple :**
```lua
local handlerId = veafMarkers.registerEventHandler(veafMarkers.MarkerAdd, myHandler)
-- Plus tard...
veafMarkers.unregisterEventHandler(handlerId)
```

#### Structure d'événement marqueur

Les événements marqueur reçus par les handlers contiennent :

```lua
{
  id = number,              -- ID du marqueur
  time = number,            -- Temps mission
  initiator = DCS_Unit,     -- Unité ayant créé le marqueur (si applicable)
  coalition = coalition,    -- Coalition (-1 pour toutes, 0=neutre, 1=bleu, 2=rouge)
  groupID = number,         -- ID du groupe
  text = string,            -- Texte du marqueur
  pos = vec3                -- Position du marqueur
}
```

#### Patrons d'utilisation

**Patron commande :**

Les modules enregistrent un handler auprès de `veafCommands`, qui route de façon centralisée toutes les commandes des marqueurs F10 :
```lua
-- Dans la fonction initialize() d'un module :
veafCommands.registerCommandHandler(function(pos, event, bypass, fromMarker, groups, route)
  local text = event.text or ""
  if not text:lower():match("^_mycommand") then
    return false  -- not our command
  end
  -- handle the command...
  return true   -- consumed
end, veafCommands.PRIORITY_SPAWN)
```

Tous les handlers sont appelés par ordre de priorité jusqu'à ce que l'un retourne `true`.
Le dispatcher central (`veafCommands.dispatchMarker`) gère automatiquement la suppression du marqueur.

**Patron sécurité :**

Vérifiez la coalition avant d'exécuter :
```lua
veafMarkers.registerEventHandler(veafMarkers.MarkerAdd, function(pos, event)
  -- Only allow blue coalition markers
  if event.coalition == coalition.side.BLUE then
    processCommand(pos, event.text)
  else
    veaf.logger:warn("Unauthorized marker from coalition %d", event.coalition)
  end
end)
```

**Patron nettoyage :**

Supprimez les marqueurs après traitement :
```lua
veafMarkers.registerEventHandler(veafMarkers.MarkerChange, function(pos, event)
  if processMarkerCommand(pos, event.text) then
    -- Remove marker after successful processing
    trigger.action.removeMark(event.id)
  end
end)
```

---

### veafCommands.lua

**Module ID :** `COMMANDS`

**Ordre d'init :** 15 (après veafMarkers, avant tous les modules de commande)

**Objectif :** Registre central et dispatcher pour toutes les commandes texte (marqueurs F10 et interpréteur)

#### Constantes

```lua
veafCommands.PRIORITY_SHORTCUTS    = 10
veafCommands.PRIORITY_SPAWN        = 20
veafCommands.PRIORITY_NAMEDPOINTS  = 30
veafCommands.PRIORITY_CASMISSION   = 40
veafCommands.PRIORITY_SECURITY     = 50
veafCommands.PRIORITY_MOVE         = 60
veafCommands.PRIORITY_RADIO        = 70
veafCommands.PRIORITY_REMOTE       = 80
```

#### Fonctions

##### `veafCommands.registerCommandHandler(fn, priority)`

Enregistre une fonction handler de commande. Les handlers sont appelés par ordre de priorité croissant.

**Paramètres :**

- `fn` (function) — Handler avec signature `(pos, event, bypass, fromMarker, groups, route) → boolean`
- `priority` (number) — Ordre d'exécution (plus bas = plus tôt) ; utiliser les constantes `PRIORITY_*`

##### `veafCommands.execute(pos, text, coalition, groups, route)`

Exécute une commande depuis le chemin interpréteur (noms d'unités). La coalition est utilisée telle quelle.

**Paramètres :**

- `pos` (vec3) — Position d'exécution
- `text` (string) — Texte de commande
- `coalition` (number) — Numéro de coalition
- `groups` (table, optionnel) — Table pour recevoir les noms de groupes spawnés
- `route` (table, optionnel) — Définition de route

**Retourne :** `boolean` — true si un handler a consommé la commande

##### `veafCommands.dispatchMarker(eventPos, event)`

Gère un événement de modification de marqueur. Inverse la coalition (les événements marqueur rapportent le côté du poseur, pas celui de la cible), appelle tous les handlers enregistrés par ordre de priorité, et supprime le marqueur en cas de succès.

**Paramètres :**

- `eventPos` (vec3) — Position du marqueur
- `event` (table) — Objet événement marqueur

---

### veafInterpreter.lua

**Module ID :** `INTERPRETER`

**Objectif :** Interpréter et exécuter des commandes depuis les noms d'unités et marqueurs

#### Constantes

```lua
veafInterpreter.Starter = "#veafInterpreter[\""  -- Préfixe de commande dans le nom d'unité
veafInterpreter.Trailer = "\"]"                   -- Suffixe de commande
veafInterpreter.DelayForStartup = 1              -- Délai de démarrage (secondes)
```

#### Fonctions

##### `veafInterpreter.interpret(text)`

Extrait la commande d'une chaîne de texte.

**Paramètres :**

- `text` (string) — Texte contenant la commande (nom d'unité ou texte de marqueur)

**Retourne :** `string` — Commande extraite ou nil

**Exemple :**
```lua
local unitName = "#veafInterpreter[\"_spawn, name F-16C, group 2\"]"
local command = veafInterpreter.interpret(unitName)
-- Résultat : "_spawn, name F-16C, group 2"
```

##### `veafInterpreter.execute(command, position, coalition, route, spawnedGroups)`

Exécute une commande VEAF. Délègue à `veafCommands.execute()` — tous les handlers enregistrés sont essayés par ordre de priorité.

**Paramètres :**

- `command` (string) — Chaîne de commande
- `position` (vec3) — Position d'exécution de la commande
- `coalition` (coalition, optionnel) — Coalition exécutant la commande
- `route` (table, optionnel) — Définition de route pour les groupes spawnés
- `spawnedGroups` (table, optionnel) — Table pour recevoir les noms des groupes spawnés

**Retourne :** `boolean` — True si la commande a été exécutée avec succès

**Note :** le routage des commandes est géré par `veafCommands`. Les modules s'enregistrent via `veafCommands.registerCommandHandler()`.

**Exemple :**
```lua
local pos = {x=1000, y=50, z=2000}
local success = veafInterpreter.execute("_spawn, name F-16C, group 2", pos, coalition.side.BLUE)
if success then
  veaf.logger:info("Commande exécutée avec succès")
end
```

##### `veafInterpreter.executeCommandOnUnit(unitName, command)`

Exécute une commande depuis la position d'une unité.

**Paramètres :**

- `unitName` (string) — Nom de l'unité ou statique
- `command` (string) — Commande à exécuter

**Retourne :** Rien

**Description :**

- Trouve l'unité ou l'objet statique par nom
- Exécute la commande à la position de l'unité
- Détruit l'unité/statique après exécution réussie
- Utile pour les unités trigger pré-placées

**Exemple :**
```lua
-- Dans l'éditeur de mission, créer une unité nommée : "#veafInterpreter[\"_spawn, name SA-6\"]"
-- Ou exécuter par script :
veafInterpreter.executeCommandOnUnit("TriggerUnit1", "_spawn, name SA-6")
```

##### `veafInterpreter.initialize()`

Initialise le module interpréteur.

**Retourne :** Rien

**Description :**

- Appelé automatiquement lors de l'initialisation VEAF
- Scanne les unités avec des commandes interpréteur dans les noms
- Exécute les commandes après un délai

#### Flux d'exécution des commandes

```
1. Command received (unit name or marker)
   ↓
2. veafInterpreter.interpret() extracts command
   ↓
3. Check veafShortcuts for shorthand
   ↓
4. Try module-specific handlers in order:
   - veafSpawn (spawn commands)
   - veafNamedPoints (named locations)
   - veafCasMission (CAS missions)
   - veafSecurity (security commands)
   - veafMove (movement)
   - veafRadio (radio/comms)
   - veafRemote (remote API)
   ↓
5. Return success/failure
```

#### Patron d'utilisation des commandes dans les noms d'unités

**Usage dans l'éditeur de mission :**
1. Créer une unité (n'importe quel type, même statique)
2. Nommer l'unité : `#veafInterpreter["COMMANDE ICI"]`
3. L'unité exécutera la commande au démarrage de la mission et s'autodétruira

**Exemples d'utilisation :**
```lua
-- Spawner une CAP au démarrage
Nom d'unité : #veafInterpreter["_spawn, name CAP-2, alt 25000, hdg 090, speed 450"]

-- Créer une zone cible CAS
Nom d'unité : #veafInterpreter["_cas, size 5, defense 3, armor 2"]

-- Spawner un convoi sur route
Nom d'unité : #veafInterpreter["_spawn, convoy, name convoy1, dest marker1, speed 50"]
```

---

## Gestion des unités et groupes

### veafSpawnParser.lua

**Objectif :** Parser le texte des commandes spawn en tables d'options. Sous-module extrait de `veafSpawn`.

#### Fonctions

##### `veafSpawn.markTextAnalysis(text)`

Parse le texte d'un marqueur pour les paramètres de spawn. Défini dans `veafSpawnParser.lua`, disponible sur la table `veafSpawn`.

**Paramètres :**

- `text` (string) — Texte du marqueur à parser

**Retourne :** `table` — Table d'options avec les paires clé/valeur parsées

##### `veafSpawn.convertLaserToFreq(laser)`

Convertit un code laser en chaîne de fréquence TACAN/radio.

**Paramètres :**

- `laser` (number) — Code laser (1111–1788)

**Retourne :** `string` — Label de fréquence, ou nil si non trouvé

---

### veafSpawn.lua

**Module ID :** `SPAWN`

**Objectif :** Système de spawn dynamique pour unités, groupes, convois et effets

#### Constantes

##### Mots-clés

```lua
veafSpawn.SpawnKeyphrase = "_spawn"
veafSpawn.DestroyKeyphrase = "_destroy"
veafSpawn.TeleportKeyphrase = "_teleport"
veafSpawn.DrawingKeyphrase = "_drawing"
veafSpawn.MissionMasterKeyphrase = "_mm"
```

##### Configuration

```lua
veafSpawn.IlluminationFlareAglAltitude = 1000  -- mètres
veafSpawn.LogisticUnitType = "FARP Ammo Dump Coating"
veafSpawn.CAP_WATCHDOG_DELAY = 10  -- secondes
veafSpawn.AFAC.maximumAmount = 8   -- max AFACs simultanés
```

#### Fonctions principales

##### `veafSpawn.executeCommand(eventPos, eventText, coalition, markId, bypassSecurity, spawnedGroups, repeatCount, repeatDelay, route, allowStartDelay, requesterCoalition)`

Exécute une commande spawn depuis un marqueur ou un script.

**Paramètres :**

- `eventPos` (vec3) — Position de spawn
- `eventText` (string) — Texte de commande
- `coalition` (coalition, optionnel) — Coalition
- `markId` (number, optionnel) — ID de marqueur à supprimer
- `bypassSecurity` (boolean, optionnel) — Ignorer la vérification de sécurité
- `spawnedGroups` (table, optionnel) — Recevoir les noms des groupes spawnés
- `repeatCount` (number, optionnel) — Nombre de répétitions
- `repeatDelay` (number, optionnel) — Délai entre les spawns (secondes)
- `route` (table, optionnel) — Route pour les groupes spawnés
- `allowStartDelay` (boolean, optionnel) — Autoriser un démarrage différé
- `requesterCoalition` (coalition, optionnel) — Coalition du demandeur

**Retourne :** `boolean` — Indicateur de succès

**Exemple :**
```lua
local pos = {x=1000, y=0, z=2000}
veafSpawn.executeCommand(pos, "_spawn, name F-16C, group 2, hdg 270", coalition.side.BLUE)
```

##### `veafSpawn.markTextAnalysis(text)`

Analyse le texte d'un marqueur pour en extraire les paramètres de spawn.

**Paramètres :**

- `text` (string) — Texte du marqueur

**Retourne :** `table` — Options analysées

**Champs de la table retournée :**
```lua
{
  name = string,           -- Unit/group name
  unitName = string,       -- Specific unit name
  groupName = string,      -- Override group name
  alias = string,          -- Name alias
  group = number,          -- Group count
  country = string,        -- Country name
  alt = number,            -- Altitude (feet)
  altitude = number,       -- Altitude (feet)
  hdg = number,            -- Heading (degrees)
  heading = number,        -- Heading (degrees)
  speed = number,          -- Speed (knots)
  dist = number,           -- Distance
  spacing = number,        -- Unit spacing (meters)
  side = coalition,        -- Coalition
  defense = number,        -- Defense level (0-5)
  armor = number,          -- Armor level (0-5)
  size = number,           -- Size (0-5)
  shells = number,         -- Shell count
  power = number,          -- Explosion power
  radius = number,         -- Dispersion radius
  color = string,          -- Smoke color
  smoke = boolean,         -- Add smoke
  type = string,           -- Type specification
  skill = string,          -- Skill level
  password = string,       -- Security password
  silent = boolean,        -- Suppress messages

  -- Specific spawn types
  convoy = boolean,
  dest = vec3,             -- Destination
  patrol = boolean,
  offroad = boolean,

  -- Air units
  cap = boolean,           -- CAP mission
  capRadius = number,      -- CAP radius
  afac = boolean,          -- AFAC unit
  immortal = boolean,      -- Invulnerable

  -- Effects
  bomb = boolean,
  smoke = boolean,
  flare = boolean,
  illumination = boolean,

  -- FARP/FOB
  farp = boolean,
  fob = boolean,
  farptype = string,
  fobtype = string,

  -- Advanced
  code = number,           -- Laser/TACAN code
  freq = number,           -- Frequency
  mod = string,            -- Modulation
  role = string,           -- Unit role
  static = boolean,        -- Spawn as static
  hidden = boolean         -- Hide from MFD
}
```

#### Fonctions de spawn d'unités

##### `veafSpawn.spawnUnit(spawnPosition, radius, name, czName, country, alt, hdg, unitName, role, static, code, freq, mod, silent, hiddenOnMFD)`

Spawne une unité individuelle.

**Paramètres :**

- `spawnPosition` (vec3) — Position de spawn
- `radius` (number) — Rayon de dispersion (mètres)
- `name` (string) — Nom de type d'unité (type DCS ou alias)
- `czName` (string, optionnel) — Nom de zone de combat
- `country` (number, optionnel) — ID pays
- `alt` (number, optionnel) — Altitude (pieds)
- `hdg` (number, optionnel) — Cap (degrés)
- `unitName` (string, optionnel) — Nom d'unité forcé
- `role` (string, optionnel) — Rôle de l'unité
- `static` (boolean, optionnel) — Spawner en tant qu'objet statique
- `code` (number, optionnel) — Code laser/TACAN
- `freq` (number, optionnel) — Fréquence radio
- `mod` (string, optionnel) — Modulation radio
- `silent` (boolean, optionnel) — Supprimer les messages
- `hiddenOnMFD` (boolean, optionnel) — Masquer du MFD

**Retourne :** `table` — Info du groupe spawné

**Exemple :**
```lua
-- Spawner un F-16C à une position
local pos = {x=1000, y=0, z=2000}
veafSpawn.spawnUnit(pos, 50, "F-16C", nil, nil, 5000, 270)

-- Spawner un JTAC avec code laser
veafSpawn.spawnUnit(pos, 0, "JTAC", nil, nil, nil, nil, "JTAC-1", "forward_observer", false, 1688)

-- Spawner un ravitailleur avec TACAN
veafSpawn.spawnUnit(pos, 100, "KC-135", nil, nil, 25000, 270, "Texaco", nil, false, 61, 251.0, "AM")
```

##### `veafSpawn.spawnGroup(spawnSpot, radius, name, czName, country, alt, hdg, spacing, groupName, silent, hasDest, hiddenOnMFD)`

Spawne un groupe prédéfini.

**Paramètres :**

- `spawnSpot` (vec3) — Position de spawn
- `radius` (number) — Rayon de dispersion
- `name` (string) — Nom de template du groupe
- `czName` (string, optionnel) — Zone de combat
- `country` (number, optionnel) — Pays
- `alt` (number, optionnel) — Altitude
- `hdg` (number, optionnel) — Cap
- `spacing` (number, optionnel) — Espacement des unités
- `groupName` (string, optionnel) — Nom de groupe forcé
- `silent` (boolean, optionnel) — Supprimer les messages
- `hasDest` (vec3, optionnel) — Destination de déplacement
- `hiddenOnMFD` (boolean, optionnel) — Masquer du MFD

**Retourne :** `table` — Info du groupe

**Exemple :**
```lua
-- Spawner un peloton blindé depuis un template
veafSpawn.spawnGroup(pos, 100, "Soviet Armor Platoon", nil, nil, nil, 180, 50)
```

#### Spawn de forces terrestres

##### `veafSpawn.spawnInfantryGroup(spawnSpot, radius, czName, country, side, heading, spacing, defense, armor, size, silent, hiddenOnMFD)`

Spawne un groupe d'infanterie avec paramètres.

**Paramètres :**

- `spawnSpot` (vec3) — Position de spawn
- `radius` (number) — Rayon de dispersion
- `czName` (string, optionnel) — Zone de combat
- `country` (number, optionnel) — Pays
- `side` (coalition) — Coalition
- `heading` (number, optionnel) — Cap de formation
- `spacing` (number) — Espacement des unités (mètres)
- `defense` (number) — Niveau de défense 0-5
- `armor` (number) — Niveau de blindage 0-5
- `size` (number) — Taille 0-5 (affecte le nombre d'unités)
- `silent` (boolean, optionnel) — Supprimer les messages
- `hiddenOnMFD` (boolean, optionnel) — Masquer du MFD

**Retourne :** `table` — Info du groupe

**Exemple :**
```lua
-- Spawner une petite escouade d'infanterie
veafSpawn.spawnInfantryGroup(pos, 50, nil, nil, coalition.side.RED, 0, 10, 0, 0, 1, false)
```

##### `veafSpawn.spawnArmoredPlatoon(spawnSpot, radius, czName, country, side, heading, spacing, defense, armor, size, silent, hasDest, hiddenOnMFD)`

Spawne un peloton blindé.

**Paramètres :** Identiques à infantry + `hasDest` pour le déplacement

**Retourne :** `table` — Info du groupe

**Exemple :**
```lua
-- Spawner un peloton de chars moyens
veafSpawn.spawnArmoredPlatoon(pos, 100, nil, nil, coalition.side.BLUE, 90, 50, 2, 3, 3, false)
```

##### `veafSpawn.spawnAirDefenseBattery(spawnSpot, radius, czName, country, side, heading, spacing, defense, silent, hasDest, hiddenOnMFD)`

Spawne une batterie SAM/AAA.

**Paramètres :** Similaires au peloton blindé

**Retourne :** `table` — Info du groupe

**Exemple :**
```lua
-- Spawner une batterie SA-6
veafSpawn.spawnAirDefenseBattery(pos, 200, nil, nil, coalition.side.RED, 0, 75, 4, false)
```

##### `veafSpawn.spawnTransportCompany(spawnSpot, radius, czName, country, side, heading, spacing, defense, size, silent, hasDest, hiddenOnMFD)`

Spawne une compagnie de transport (camions).

**Retourne :** `table` — Info du groupe

##### `veafSpawn.spawnFullCombatGroup(spawnSpot, radius, czName, country, side, heading, spacing, defense, armor, size, silent, hiddenOnMFD)`

Spawne un groupe d'armes combinées (infanterie + blindés + transport).

**Retourne :** `table` — Info de groupes multiples

#### Système de convois

##### `veafSpawn.spawnConvoy(spawnSpot, name, czName, radius, country, side, heading, spacing, speed, patrol, offroad, destination, defense, size, armor, silent, hiddenOnMFD)`

Spawne un convoi de véhicules avec waypoints.

**Paramètres :**

- `spawnSpot` (vec3) — Position de départ
- `name` (string) — Nom du convoi
- `czName` (string, optionnel) — Zone de combat
- `radius` (number) — Dispersion
- `country` (number, optionnel) — Pays
- `side` (coalition) — Coalition
- `heading` (number, optionnel) — Cap initial
- `spacing` (number) — Espacement entre véhicules
- `speed` (number) — Vitesse (km/h)
- `patrol` (boolean) — Mode patrouille (retour au point de départ)
- `offroad` (boolean) — Autoriser le déplacement hors route
- `destination` (vec3) — Position de destination
- `defense` (number) — Niveau de défense 0-5
- `size` (number) — Taille 0-5
- `armor` (number) — Niveau de blindage 0-5
- `silent` (boolean, optionnel) — Supprimer les messages
- `hiddenOnMFD` (boolean, optionnel) — Masquer du MFD

**Retourne :** `table` — Info du convoi

**Exemple :**
```lua
local start = {x=1000, y=0, z=2000}
local dest = {x=5000, y=0, z=6000}
veafSpawn.spawnConvoy(start, "Convoy1", nil, 50, nil, coalition.side.RED,
  nil, 25, 40, false, false, dest, 2, 3, 2, false)
```

##### Fonctions de contrôle des convois

**`veafSpawn.stopClosestConvoy(unitName)`**

Arrête le convoi le plus proche de l'unité.

**`veafSpawn.moveClosestConvoy(unitName)`**

Reprend le déplacement du convoi le plus proche.

**`veafSpawn.markClosestConvoyWithSmoke(unitName)`**

Marque le convoi le plus proche à la fumée.

**`veafSpawn.markClosestConvoyRouteWithSmoke(unitName)`**

Marque la route du convoi avec des marqueurs fumée.

**`veafSpawn.infoOnAllConvoys(unitName)`**

Affiche les informations de tous les convois actifs.

**`veafSpawn.cleanupAllConvoys()`**

Détruit tous les convois actifs.

#### Spawn aérien

##### `veafSpawn.spawnCombatAirPatrol(spawnSpot, radius, name, country, altitude, altitudeDelta, hdg, distance, speed, capRadius, skill, silent, hiddenOnMFD)`

Spawne un vol CAP avec orbite de patrouille.

**Paramètres :**

- `spawnSpot` (vec3) — Position de spawn
- `radius` (number) — Dispersion
- `name` (string) — Type d'appareil
- `country` (number, optionnel) — Pays
- `altitude` (number) — Altitude de patrouille (pieds)
- `altitudeDelta` (number, optionnel) — Randomisation d'altitude
- `hdg` (number) — Cap de l'orbite
- `distance` (number) — Distance à l'orbite (mètres)
- `speed` (number) — Vitesse (nœuds)
- `capRadius` (number) — Rayon de l'orbite (mètres)
- `skill` (string) — Niveau de compétence
- `silent` (boolean, optionnel) — Supprimer les messages
- `hiddenOnMFD` (boolean, optionnel) — Masquer du MFD

**Retourne :** `table` — Info du vol CAP

**Description :**

- Spawne l'appareil à la position
- Crée une orbite racetrack à l'emplacement spécifié
- Démarre un watchdog pour surveiller et engager les cibles

**Exemple :**
```lua
-- Spawner une CAP de F-15C
local pos = {x=0, y=0, z=0}
veafSpawn.spawnCombatAirPatrol(pos, 100, "F-15C", nil, 25000, 2000,
  90, 50000, 450, 20000, "Good", false)
```

##### `veafSpawn.spawnAFAC(spawnSpot, name, country, altitude, speed, hdg, frequency, mod, code, immortal, silent, hiddenOnMFD)`

Spawne un contrôleur aérien avancé en vol (AFAC).

**Paramètres :**

- `spawnSpot` (vec3) — Position de spawn
- `name` (string) — Type d'appareil
- `country` (number, optionnel) — Pays
- `altitude` (number) — Altitude d'orbite (pieds)
- `speed` (number) — Vitesse (nœuds)
- `hdg` (number) — Cap d'orbite
- `frequency` (number) — Fréquence radio (MHz)
- `mod` (string) — "AM" ou "FM"
- `code` (number) — Code laser (ex : 1688)
- `immortal` (boolean) — Indicateur invulnérable
- `silent` (boolean, optionnel) — Supprimer les messages
- `hiddenOnMFD` (boolean, optionnel) — Masquer du MFD

**Retourne :** `table` — Info AFAC

**Exemple :**
```lua
-- Spawner un AFAC A-10C
veafSpawn.spawnAFAC(pos, "A-10C", nil, 15000, 250, 0, 133.0, "AM", 1688, true, false)
```

##### `veafSpawn.startCapWatchdog(capGroupName, capCoalition, capZone, pTargetsList, pNumberOfTasksAddedByWatchdog)`

Démarre le watchdog d'engagement de la CAP.

**Paramètres :**

- `capGroupName` (string) — Nom du groupe CAP
- `capCoalition` (coalition) — Coalition
- `capZone` (table) — Définition de la zone
- `pTargetsList` (table, optionnel) — Cibles spécifiques
- `pNumberOfTasksAddedByWatchdog` (number, optionnel) — Tâches maximum

**Retourne :** Rien

**Description :** Surveille la zone et missionne la CAP pour engager les appareils ennemis.

#### Cargo et logistique

##### `veafSpawn.spawnCargo(spawnSpot, radius, cargoType, country, weightBias, cargoSmoke, unitName, silent, hiddenOnMFD)`

Spawne un cargo CTLD.

**Paramètres :**

- `spawnSpot` (vec3) — Position de spawn
- `radius` (number) — Dispersion
- `cargoType` (string) — Type de cargo : "container", "barrels", "ammo", "fuel"
- `country` (number, optionnel) — Pays
- `weightBias` (number, optionnel) — Préférence de poids (0-1)
- `cargoSmoke` (boolean) — Ajouter un marqueur fumée
- `unitName` (string, optionnel) — Nom du cargo
- `silent` (boolean, optionnel) — Supprimer les messages
- `hiddenOnMFD` (boolean, optionnel) — Masquer du MFD

**Retourne :** `table` — Info du cargo

**Exemple :**
```lua
-- Spawner des conteneurs de carburant
veafSpawn.spawnCargo(pos, 10, "fuel", nil, 0.5, true, "Fuel-1", false)
```

##### `veafSpawn.spawnLogistic(spawnSpot, radius, country, silent, hiddenOnMFD)`

Spawne une unité logistique CTLD.

**Retourne :** `table` — Info de l'unité logistique

#### FARP et FOB

##### `veafSpawn.spawnFarp(spawnSpot, radius, name, country, farptype, side, hdg, spacing, silent, hiddenOnMFD, noFarpMarkers, code, freq, mod)`

Spawne un point d'armement et de ravitaillement avancé (FARP).

**Paramètres :**

- `spawnSpot` (vec3) — Position
- `radius` (number) — Dispersion
- `name` (string) — Nom du FARP
- `country` (number, optionnel) — Pays
- `farptype` (string, optionnel) — Type de configuration FARP
- `side` (coalition) — Coalition
- `hdg` (number, optionnel) — Cap
- `spacing` (number) — Espacement des unités
- `silent` (boolean, optionnel) — Supprimer les messages
- `hiddenOnMFD` (boolean, optionnel) — Masquer du MFD
- `noFarpMarkers` (boolean, optionnel) — Ne pas créer de marqueurs
- `code` (number, optionnel) — Code TACAN
- `freq` (number, optionnel) — Fréquence radio
- `mod` (string, optionnel) — Modulation

**Retourne :** `table` — Info du FARP

**Exemple :**
```lua
-- Spawner un FARP basique
veafSpawn.spawnFarp(pos, 100, "FARP Alpha", nil, nil, coalition.side.BLUE,
  0, 50, false, false, false, 71, 251.0, "AM")
```

##### `veafSpawn.spawnFob(spawnSpot, radius, name, country, fobtype, side, hdg, spacing, silent, hiddenOnMFD)`

Spawne une base d'opérations avancée (FOB).

**Paramètres :** Similaires au FARP

**Retourne :** `table` — Info du FOB

#### Effets et marqueurs

##### `veafSpawn.spawnBomb(spawnSpot, radius, shells, power, altitude, altitudedelta, password)`

Crée un effet d'explosion.

**Paramètres :**

- `spawnSpot` (vec3) — Position de l'explosion
- `radius` (number) — Dispersion
- `shells` (number) — Nombre d'explosions
- `power` (number) — Puissance de l'explosion (kg équivalent TNT)
- `altitude` (number, optionnel) — Décalage d'altitude
- `altitudedelta` (number, optionnel) — Randomisation d'altitude
- `password` (string, optionnel) — Mot de passe de sécurité

**Retourne :** Rien

**Exemple :**
```lua
-- Créer 5 explosions de 500 kg
veafSpawn.spawnBomb(pos, 50, 5, 500, 0, 0)
```

##### `veafSpawn.spawnSmoke(spawnSpot, color, radius, shells)`

Ajoute des marqueurs fumée.

**Paramètres :**

- `spawnSpot` (vec3) — Position
- `color` (string) — "Green", "Red", "White", "Orange", "Blue"
- `radius` (number) — Dispersion
- `shells` (number) — Nombre de marqueurs fumée

**Retourne :** Rien

**Exemple :**
```lua
-- Marquer une position avec de la fumée rouge
veafSpawn.spawnSmoke(pos, "Red", 0, 1)
```

##### `veafSpawn.spawnSignalFlare(spawnSpot, radius, shells, color)`

Tire des fusées éclairantes de signalisation.

**Paramètres :**

- `spawnSpot` (vec3) — Position
- `radius` (number) — Dispersion
- `shells` (number) — Nombre de fusées
- `color` (string) — Couleur de la fusée

**Retourne :** Rien

##### `veafSpawn.spawnIlluminationFlare(spawnSpot, radius, steps, power, height, heading, distance, speed)`

Crée un patron d'illumination par fusées éclairantes.

**Paramètres :**

- `spawnSpot` (vec3) — Position
- `radius` (number) — Dispersion
- `steps` (number) — Nombre de fusées en ligne
- `power` (number) — Puissance de la fusée
- `height` (number, optionnel) — Altitude AGL
- `heading` (number, optionnel) — Cap de la ligne
- `distance` (number, optionnel) — Distance entre fusées
- `speed` (number, optionnel) — Vitesse de largage

**Retourne :** Rien

**Exemple :**
```lua
-- Créer une ligne d'illumination
veafSpawn.spawnIlluminationFlare(pos, 0, 5, 1000000, 1000, 90, 500, 0)
```

#### Fonctions de dessin

##### `veafSpawn.drawCircle(point, name, radius, color, fillColor, lineType)`

Dessine un cercle sur la carte.

**Paramètres :**

- `point` (vec3) — Position du centre
- `name` (string) — Nom du dessin
- `radius` (number) — Rayon du cercle (mètres)
- `color` (table, optionnel) — Couleur de ligne `{r, g, b, a}` (plage 0-1)
- `fillColor` (table, optionnel) — Couleur de remplissage
- `lineType` (number, optionnel) — Type de ligne

**Retourne :** Rien

**Exemple :**
```lua
-- Dessiner un cercle rouge
veafSpawn.drawCircle(pos, "Zone1", 5000, {1, 0, 0, 1}, {1, 0, 0, 0.3})
```

##### `veafSpawn.drawSquare(point, name, side, color, fillColor, lineType)`

Dessine un carré sur la carte.

**Paramètres :**

- `point` (vec3) — Centre
- `name` (string) — Nom du dessin
- `side` (number) — Longueur du côté (mètres)
- `color` (table, optionnel) — Couleur de ligne
- `fillColor` (table, optionnel) — Couleur de remplissage
- `lineType` (number, optionnel) — Type de ligne

**Retourne :** Rien

##### `veafSpawn.eraseDrawing(name)`

Supprime un dessin de la carte.

**Paramètres :**

- `name` (string) — Nom du dessin

**Retourne :** Rien

#### Destruction et téléportation

##### `veafSpawn.destroy(spawnSpot, radius, unitName)`

Détruit les unités dans une zone ou une unité spécifique.

**Paramètres :**

- `spawnSpot` (vec3) — Position
- `radius` (number) — Rayon de recherche (0 pour unité spécifique)
- `unitName` (string, optionnel) — Nom d'unité spécifique

**Retourne :** Rien

**Exemple :**
```lua
-- Détruire toutes les unités dans un rayon de 500m
veafSpawn.destroy(pos, 500)

-- Détruire une unité spécifique
veafSpawn.destroy(pos, 0, "Tank-1")
```

##### `veafSpawn.teleport(spawnSpot, name, silent)`

Téléporte un groupe à une position.

**Paramètres :**

- `spawnSpot` (vec3) — Destination
- `name` (string) — Nom du groupe
- `silent` (boolean, optionnel) — Supprimer les messages

**Retourne :** Rien

**Exemple :**
```lua
-- Téléporter le groupe du joueur à une position
veafSpawn.teleport(newPos, "Viper Flight", false)
```

#### Fonctions JTAC

##### `veafSpawn.JTACAutoLase(groupName, laserCode, radioData)`

Configure un JTAC en auto-désignation laser.

**Paramètres :**

- `groupName` (string) — Nom du groupe JTAC
- `laserCode` (number) — Code laser (ex : 1688)
- `radioData` (table, optionnel) — Configuration radio

**Retourne :** Rien

**Exemple :**
```lua
veafSpawn.JTACAutoLase("JTAC-1", 1688, {freq=133.0, mod="AM"})
```

##### `veafSpawn.convertLaserToFreq(laser)`

Convertit un code laser en fréquence radio.

**Paramètres :**

- `laser` (number) — Code laser

**Retourne :** `number` — Fréquence en MHz

#### Fonctions Mission Master

Mission Master fournit un contrôle de mission scriptable.

##### `veafSpawn.missionMasterSetMessagingMode(silent, toGroupId)`

Définit le mode de sortie des messages.

**Paramètres :**

- `silent` (boolean) — Mode silencieux
- `toGroupId` (number, optionnel) — ID du groupe cible

**Retourne :** Rien

##### `veafSpawn.missionMasterOutText(message)`

Affiche un message Mission Master.

**Paramètres :**

- `message` (string) — Texte du message

**Retourne :** Rien

##### `veafSpawn.missionMasterAddRunnable(name, code, parameters)`

Ajoute une commande exécutable.

**Paramètres :**

- `name` (string) — Nom de la commande
- `code` (string) — Code Lua à exécuter
- `parameters` (table, optionnel) — Paramètres

**Retourne :** Rien

##### `veafSpawn.missionMasterRun(name)`

Exécute une commande Mission Master.

**Paramètres :**

- `name` (string) — Nom de la commande

**Retourne :** Rien

##### `veafSpawn.missionMasterSetFlag(name, value)`

Définit un flag Mission Master.

**Paramètres :**

- `name` (string) — Nom du flag
- `value` (any) — Valeur du flag

**Retourne :** Rien

##### `veafSpawn.missionMasterGetFlag(name)`

Récupère la valeur d'un flag.

**Paramètres :**

- `name` (string) — Nom du flag

**Retourne :** `any` — Valeur du flag

##### `veafSpawn.missionMasterAddValueToFlag(name, increment)`

Modifie la valeur d'un flag.

**Paramètres :**

- `name` (string) — Nom du flag
- `increment` (number) — Valeur à ajouter

**Retourne :** Rien

#### Fonctions utilitaires

##### `veafSpawn.listAllCAP(unitName)`

Affiche la liste de tous les vols CAP actifs.

**Paramètres :**

- `unitName` (string) — Nom de l'unité demandeuse

**Retourne :** Rien

##### `veafSpawn.dumpSpawnablePlanesList(export_path)`

Exporte la liste des appareils spawnables vers un fichier.

**Paramètres :**

- `export_path` (string, optionnel) — Répertoire d'export

**Retourne :** Rien

##### `veafSpawn.buildRadioMenu()`

Construit le menu radio de spawn.

**Retourne :** Rien

##### `veafSpawn.initialize()`

Initialise le module de spawn.

**Retourne :** Rien

---

### veafUnits.lua

**Module ID :** `UNITS`

**Objectif :** Définitions d'unités/groupes et utilitaires

#### Constantes

```lua
veafUnits.DefaultCellWidth = 10        -- meters
veafUnits.DefaultCellHeight = 10       -- meters
veafUnits.DefaultPathfindingUnitType = "TZ-22_KrAZ"
veafUnits.delayBeforePathfindingFix = 5  -- seconds
```

#### Fonctions

##### `veafUnits.findDcsUnit(unitType)`

Trouve une unité DCS par nom de type (insensible à la casse).

**Paramètres :**

- `unitType` (string) — Type d'unité (ex : "F-16C", "M-1 Abrams")

**Retourne :** `table` — Définition d'unité ou nil

**Exemple :**
```lua
local f16 = veafUnits.findDcsUnit("F-16C_50")
if f16 then
  veaf.logger:info("Found: %s", f16.displayName)
end
```

##### `veafUnits.countInfantryAndVehicles(groupname)`

Compte les unités d'infanterie et de véhicules dans un groupe.

**Paramètres :**

- `groupname` (string) — Nom du groupe

**Retourne :** `number, number` — Nombre de véhicules, Nombre d'infanterie

##### `veafUnits.processGroup(group)`

Traite et valide une définition de groupe.

**Paramètres :**

- `group` (table) — Table de définition du groupe

**Retourne :** `table` — Groupe traité

**Description :** Gère le positionnement des unités, l'espacement, la formation.

---

### veafAssets.lua

**Module ID :** `ASSETS`

**Objectif :** Gérer et suivre les assets de mission (ravitailleurs, AWACS, porte-avions)

#### Structures de données

##### Définition d'asset

```lua
{
  name = "Tanker-1",              -- Nom du groupe
  description = "KC-135 Texaco",  -- Nom d'affichage
  information = "TACAN 61X",      -- Info optionnelle
  disposable = false,             -- Peut être détruit
  jtac = 1688,                    -- Code laser JTAC optionnel
  linked = {"AWACS-1"}            -- Respawner ces groupes aussi
}
```

#### Fonctions

##### `veafAssets.respawn(name)`

Respawne un groupe d'asset.

**Paramètres :**

- `name` (string) — Nom de l'asset

**Retourne :** Rien

**Description :**

- Respawne le groupe d'asset
- Respawne tous les groupes liés
- Démarre le JTAC si configuré

**Exemple :**
```lua
veafAssets.respawn("Tanker-1")
```

##### `veafAssets.dispose(name)`

Détruit un asset.

**Paramètres :**

- `name` (string) — Nom de l'asset

**Retourne :** Rien

**Exemple :**
```lua
veafAssets.dispose("AWACS-1")
```

##### `veafAssets.info(parameters)`

Obtient les informations d'un asset.

**Paramètres :**

- `parameters` (table) — `{name=string, unitName=string}`

**Retourne :** `string` — Texte d'info de l'asset

**Exemple :**
```lua
local info = veafAssets.info({name="Tanker-1", unitName="Viper 1-1"})
-- Displays tanker position, TACAN, frequency
```

##### `veafAssets.get(assetName)`

Obtient la définition d'un asset.

**Paramètres :**

- `assetName` (string) — Nom de l'asset

**Retourne :** `table` — Définition de l'asset

##### `veafAssets.help(unitName)`

Affiche le texte d'aide.

**Paramètres :**

- `unitName` (string) — Unité destinataire de l'aide

**Retourne :** Rien

##### `veafAssets.buildRadioMenu()`

Construit le menu radio des assets.

**Retourne :** Rien

##### `veafAssets.buildAssetsDatabase()`

Construit les tables de recherche des assets.

**Retourne :** Rien

##### `veafAssets.initialize()`

Initialise le module assets.

**Retourne :** Rien

**Description :**

- Construit la base de données des assets
- Crée les menus radio
- Doit être appelé après la définition des assets

---

## Systèmes de mission

### veafCombatMission.lua

**Module ID :** `COMBATMISSION`

**Objectif :** Créer et gérer des missions de combat avec objectifs

#### Constantes

```lua
veafCombatMission.SecondsBetweenWatchdogChecks = 30
veafCombatMission.RadioMenuName = "MISSIONS"
veafCombatMission.MinimumSpacingBetweenClones = 300  -- meters
```

#### Classes

##### VeafCombatMissionObjective

Définition d'objectif de mission.

**Champs :**

- `name` (string) — Nom de l'objectif
- `description` (string) — Texte de description
- `message` (string) — Message de complétion
- `parameters` (table) — Paramètres de l'objectif
- `onStartupFunction` (function) — Appelée au démarrage de la mission
- `onCheckFunction` (function) — Appelée périodiquement pour vérifier la complétion

**États :**
```lua
VeafCombatMissionObjective.FAILED = -1
VeafCombatMissionObjective.SUCCESS = 1
VeafCombatMissionObjective.NOTHING = 0
```

**Méthodes :**
```lua
obj = VeafCombatMissionObjective:new()
obj:setName(value)
obj:getName()
obj:setDescription(value)
obj:getDescription()
obj:setMessage(value)
obj:getMessage()
obj:setParameters(value)
obj:getParameters()
obj:setOnStartup(value)
obj:getOnStartup()
obj:setOnCheck(value)
obj:getOnCheck()
obj:onStartup(mission)
obj:onCheck(mission)
obj:configureAsTimedObjective(timeInSeconds)
obj:configureAsKillEnemiesObjective(nbKillsToWin, whatsInAKill)
obj:configureAsPreventDestructionOfSceneryObjectsInZone(zones, objects)
```

**Exemple :**
```lua
local objective = VeafCombatMissionObjective:new()
objective:setName("Destroy Armor")
objective:setDescription("Destroy all enemy tanks")
objective:setOnStartup(function(mission)
  -- Spawn enemy tanks
end)
objective:setOnCheck(function(mission)
  -- Check if tanks destroyed
  if allTanksDestroyed() then
    return VeafCombatMissionObjective.SUCCESS
  end
  return VeafCombatMissionObjective.NOTHING
end)
```

##### VeafCombatMission

Définition complète d'une mission.

**Champs :**

- `name` (string) — Nom de la mission (technique)
- `friendlyName` (string) — Nom lisible de la mission
- `briefing` (string) — Texte de briefing complet
- `secured` (boolean) — Nécessite une autorisation de sécurité
- `radioMenuEnabled` (boolean) — Afficher dans le menu F10
- `objectives` (table) — Tableau d'objectifs
- `elements` (table) — Éléments définis dans la mission
- `spawnedGroups` (table) — Groupes DCS spawnés
- `active` (boolean) — La mission est active
- `training` (boolean) — Mission d'entraînement
- `hidden` (boolean) — Aucun message à l'activation/désactivation
- `silent` (boolean) — Comme `hidden`, mais pour une seule activation

**Méthodes :**
```lua
mission = VeafCombatMission:new()
mission:setName(value)
mission:getName()
mission:setFriendlyName(value)
mission:getFriendlyName()
mission:setBriefing(value)
mission:getBriefing()
mission:setSecured(value)
mission:isSecured()
mission:setRadioMenuEnabled(value)
mission:isRadioMenuEnabled()
mission:setActive(value)
mission:isActive()
mission:setTraining(value)
mission:isTraining()
mission:setHidden(value)
mission:isHidden()
mission:setSilent(value)
mission:isSilent()
mission:addObjective(objective)
mission:getObjectives()
mission:addElement(value)
mission:addSpawnedGroup(group)
mission:addDefaultObjectives()
mission:getRemainingEnemies(whatsInAKill)
mission:getInformation()
mission:initialize()
mission:activate(silent)
mission:desactivate()
```

**Exemple :**
```lua
local mission = VeafCombatMission:new()
mission:setName("Strike Alpha")
mission:setFriendlyName("Strike Alpha")
mission:setBriefing("Enemy armor advancing on friendly position. Destroy all tanks.")
mission:addObjective(destroyTanksObjective)
mission:addObjective(rtbObjective)

veafCombatMission.AddMission(mission)
```

#### Fonctions

##### `veafCombatMission.AddMission(mission)`

Enregistre une mission.

**Paramètres :**

- `mission` (VeafCombatMission) — Objet mission

**Retourne :** Rien

##### `veafCombatMission.AddMissionsWithSkillAndScale(mission, includeOriginal, skills, scales)`

Ajoute des variantes de mission avec différents niveaux de compétence/échelle.

**Paramètres :**

- `mission` (VeafCombatMission) — Mission de base
- `includeOriginal` (boolean) — Inclure l'original
- `skills` (table) — Niveaux de compétence : `{"Average", "Good", "High"}`
- `scales` (table) — Facteurs d'échelle : `{0.5, 1.0, 1.5}`

**Retourne :** Rien

**Description :** Crée plusieurs variantes (ex : "Strike Alpha - Good - 1.0x")

**Exemple :**
```lua
veafCombatMission.AddMissionsWithSkillAndScale(
  baseMission,
  false,
  {"Average", "Good", "High", "Excellent"},
  {0.5, 1.0, 1.5, 2.0}
)
-- Creates 16 mission variants (4 skills × 4 scales)
```

##### `veafCombatMission.GetMission(name)`

Obtient une mission par nom.

**Paramètres :**

- `name` (string) — Nom de la mission

**Retourne :** `VeafCombatMission` — Objet mission ou nil

##### `veafCombatMission.GetMissionNumber(number)`

Obtient une mission par index.

**Paramètres :**

- `number` (number) — Index de la mission (à partir de 1)

**Retourne :** `VeafCombatMission` — Objet mission

##### `veafCombatMission.ActivateMission(name, silent, unitName)`

Active une mission.

**Paramètres :**

- `name` (string) — Nom de la mission
- `silent` (boolean, optionnel) — Supprimer les messages
- `unitName` (string, optionnel) — Unité recevant les messages

**Retourne :** Rien

**Description :**

- Exécute toutes les fonctions de démarrage des objectifs
- Spawne les éléments de mission
- Démarre le timer watchdog
- Affiche le briefing

**Exemple :**
```lua
veafCombatMission.ActivateMission("Strike Alpha", false, "Viper 1-1")
```

##### `veafCombatMission.ActivateMissionNumber(number, silent)`

Active une mission par index.

**Paramètres :**

- `number` (number) — Index de la mission
- `silent` (boolean, optionnel) — Supprimer les messages

**Retourne :** Rien

##### `veafCombatMission.DesactivateMission(name, silent, unitName)`

Désactive une mission.

**Paramètres :**

- `name` (string) — Nom de la mission
- `silent` (boolean, optionnel) — Supprimer les messages
- `unitName` (string, optionnel) — Unité recevant les messages

**Retourne :** Rien

**Description :**

- Arrête le watchdog de mission
- Détruit les groupes spawnés
- Réinitialise les objectifs

##### `veafCombatMission.DesactivateMissionNumber(number, silent)`

Désactive une mission par index.

**Retourne :** Rien

##### `veafCombatMission.GetInformationOnMission(parameters)`

Obtient l'état d'une mission.

**Paramètres :**

- `parameters` (table) — `{name=string, unitName=string}`

**Retourne :** `string` — Texte d'état de la mission

**Exemple :**
```lua
local status = veafCombatMission.GetInformationOnMission({
  name = "Strike Alpha",
  unitName = "Viper 1-1"
})
```

##### `veafCombatMission.CompletionCheck(name)`

Vérifie l'état de complétion d'une mission.

**Paramètres :**

- `name` (string) — Nom de la mission

**Retourne :** `number` — État : FAILED (-1), SUCCESS (1), NOTHING (0)

**Description :** Appelle toutes les fonctions de vérification des objectifs et agrège les résultats.

##### `veafCombatMission.addCapMission(missionName, missionDescription, missionBriefing, secured, radioMenuEnabled, skills, scales, spawnRadius)`

Assistant de création de mission CAP.

**Paramètres :**

- `missionName` (string) — Nom de la mission
- `missionDescription` (string) — Description
- `missionBriefing` (string) — Briefing
- `secured` (boolean) — Sécurité requise
- `radioMenuEnabled` (boolean) — Afficher dans le menu
- `skills` (table) — Niveaux de compétence
- `scales` (table) — Facteurs d'échelle
- `spawnRadius` (number) — Dispersion de spawn

**Retourne :** `VeafCombatMission` — Objet mission

**Description :** Assistant pour créer des missions CAP avec des objectifs standard.

##### `veafCombatMission.listAvailableMissions(unitName)`

Affiche la liste des missions au joueur.

**Paramètres :**

- `unitName` (string) — Unité recevant la liste

**Retourne :** Rien

##### `veafCombatMission.listActiveMissions()`

Affiche les missions actives.

**Retourne :** Rien

##### `veafCombatMission.help(unitName)`

Affiche le texte d'aide.

**Paramètres :**

- `unitName` (string) — Unité recevant l'aide

**Retourne :** Rien

##### `veafCombatMission.buildRadioMenu()`

Construit le menu radio des missions.

**Retourne :** Rien

##### `veafCombatMission.executeCommandFromRemote(parameters)`

Exécute une commande depuis l'API distante.

**Paramètres :**

- `parameters` (table) — Paramètres de commande distante

**Retourne :** Rien

##### `veafCombatMission.dumpMissionsList(export_path)`

Exporte les missions vers un fichier.

**Paramètres :**

- `export_path` (string, optionnel) — Répertoire d'export

**Retourne :** Rien

##### `veafCombatMission.initialize()`

Initialise le module.

**Retourne :** Rien

---

### veafCasMission.lua

**Module ID :** `CASMISSION`

**Objectif :** Créer des missions d'entraînement Close Air Support

#### Constantes

```lua
veafCasMission.Keyphrase = "_cas"
veafCasMission.SecondsBetweenWatchdogChecks = 15
veafCasMission.SecondsBetweenSmokeRequests = 180
veafCasMission.SecondsBetweenFlareRequests = 120
veafCasMission.RedCasGroupName = "Red CAS Group"
veafCasMission.BlueCasGroupName = "Blue CAS Group"
veafCasMission.RadioMenuName = "CAS MISSION"
```

#### Tables de types d'unités

Les unités sont catégorisées par coalition, époque et niveau de défense :

```lua
TRANSPORT_TYPES[coalition][era][defense] = {unit_types}
ARMOR_TYPES[coalition][era][defense] = {unit_types}
DEFENSE_TYPES[coalition][era][defense] = {unit_types}
```

**Coalition :** `"blue"`, `"red"`

**Époque :** `"cold"`, `"modern"`

**Défense :** `0-5` (0=aucune, 5=lourde)

#### Fonctions

##### `veafCasMission.executeCommand(eventPos, eventText, coalition, markId, bypassSecurity)`

Exécute une commande de mission CAS.

**Paramètres :**

- `eventPos` (vec3) — Position de spawn
- `eventText` (string) — Texte de commande
- `coalition` (coalition, optionnel) — Coalition
- `markId` (number, optionnel) — ID du marqueur
- `bypassSecurity` (boolean, optionnel) — Ignorer la sécurité

**Retourne :** `boolean` — Indicateur de succès

##### `veafCasMission.markTextAnalysis(text)`

Analyse le texte d'un marqueur CAS.

**Paramètres :**

- `text` (string) — Texte du marqueur

**Retourne :** `table` — Options analysées

**Options :**
```lua
{
  size = 0-5,              -- Force size
  defense = 0-5,           -- Defense level
  armor = 0-5,             -- Armor level
  spacing = number,        -- Unit spacing (meters)
  disperseOnAttack = boolean,  -- Units disperse when attacked
  side = coalition         -- Coalition
}
```

##### `veafCasMission.generateCasMission(spawnSpot, size, defense, armor, spacing, disperseOnAttack, side)`

Génère une mission CAS complète.

**Paramètres :**

- `spawnSpot` (vec3) — Position de spawn
- `size` (number) — Taille 0-5
- `defense` (number) — Défense 0-5
- `armor` (number) — Blindage 0-5
- `spacing` (number) — Espacement des unités (mètres)
- `disperseOnAttack` (boolean) — Disperser lors d'une attaque
- `side` (coalition) — Coalition

**Retourne :** `table` — Info du groupe généré

**Description :**

- Spawne de l'infanterie, des blindés, du transport et de la DCA
- Les groupes réagissent aux attaques des joueurs
- Fournit un marquage par fumée/fusée

**Exemple :**
```lua
-- Générer une mission CAS de difficulté moyenne
local pos = {x=1000, y=0, z=2000}
veafCasMission.generateCasMission(pos, 3, 3, 3, 50, true, coalition.side.RED)
```

##### `veafCasMission.smokeCasTargetGroup()`

Ajoute de la fumée sur la cible CAS actuelle.

**Retourne :** Rien

**Description :** Limité par le timer `SecondsBetweenSmokeRequests`.

##### `veafCasMission.flareCasTargetGroup()`

Ajoute une fusée sur la cible CAS actuelle.

**Retourne :** Rien

##### `veafCasMission.smokeReset()`

Réinitialise le timer des demandes de fumée.

**Retourne :** Rien

##### `veafCasMission.flareReset()`

Réinitialise le timer des demandes de fusée.

**Retourne :** Rien

##### `veafCasMission.skipCasTarget()`

Passe le groupe cible actuel (détruit sans score).

**Retourne :** Rien

##### `veafCasMission.reportTargetInformation(unitName)`

Obtient les informations de la cible CAS.

**Paramètres :**

- `unitName` (string) — Unité recevant le rapport

**Retourne :** Rien

##### `veafCasMission.help(unitName)`

Affiche le texte d'aide CAS.

**Paramètres :**

- `unitName` (string) — Unité recevant l'aide

**Retourne :** Rien

##### `veafCasMission.buildRadioMenu()`

Construit le menu radio CAS.

**Retourne :** Rien

##### `veafCasMission.initialize()`

Initialise le module CAS.

**Retourne :** Rien

---

## Infrastructure et services

### veafAirbases.lua

**Module ID :** `AIRBASES`

**Objectif :** Informations normalisées sur les aérodromes et pistes

#### Classes

##### veafAirbase

Descripteur d'aérodrome contenant les informations normalisées d'un aérodrome DCS.

**Champs :**

- `Name` (string) — Nom de l'aérodrome
- `DisplayName` (string) — Nom d'affichage normalisé
- `Category` (number) — Catégorie DCS (`AIRDROME`, `HELIPAD`, `SHIP`)
- `DcsAirbase` (DCS Airbase) — Objet aérodrome DCS sous-jacent
- `Runways` (table) — Tableau d'objets `veafAirbaseRunway`

**Méthodes :**
```lua
airbase = veafAirbase:create(dcsAirbase)
airbase:getRunwayInService(iWindDirectionTrue)        -- Meilleure extrémité de piste face au vent
airbase:getRunwayInServiceString(iWindDirectionTrue)  -- Numéro de piste en service ("02")
airbase:toString()
```

##### veafAirbaseRunway

Descripteur de piste contenant les informations normalisées d'une piste d'aérodrome DCS.

Chaque objet est une table indexée des deux extrémités de la piste (`[1]` et `[2]`), chacune ayant :

- `Number` (number) — Numéro de piste (1-36)
- `Heading` (number) — Cap vrai de l'extrémité (degrés)

**Méthodes :**
```lua
runway = veafAirbaseRunway:create(dcsAirbase, dcsRunway, iReportOrder)
runway:toString()
```

#### Fonctions

##### `veafAirbases.initialize(bReset)`

Initialise la base de données des aérodromes.

**Paramètres :**

- `bReset` (boolean, optionnel) — Forcer la reconstruction de la base

**Retourne :** Rien

##### `veafAirbases.getAirbaseByName(sAirbaseName)`

Obtient un aérodrome par nom.

**Paramètres :**

- `sAirbaseName` (string) — Nom de l'aérodrome

**Retourne :** `veafAirbase` — Objet aérodrome ou nil

**Exemple :**
```lua
local kutaisi = veafAirbases.getAirbaseByName("Kutaisi")
if kutaisi then
  veaf.loggers.get("AIRBASES"):info("Kutaisi has %d runways", #kutaisi.Runways)
  veaf.loggers.get("AIRBASES"):info("Airbase: %s", kutaisi:toString())
end
```

##### `veafAirbases.getAirbaseFromDcsAirbase(dcsAirbase)`

Convertit un aérodrome DCS en objet `veafAirbase`.

**Paramètres :**

- `dcsAirbase` (DCS Airbase) — Objet aérodrome DCS

**Retourne :** `veafAirbase` — Objet aérodrome VEAF

##### `veafAirbases.getNearestAirbaseList(dcsUnit, iCount)`

Obtient les aérodromes les plus proches d'une unité.

**Paramètres :**

- `dcsUnit` (DCS Unit) — Objet unité
- `iCount` (number) — Nombre de résultats

**Retourne :** `table` — Tableau de paires `{veafAirbase, distance}` triées par distance croissante

**Exemple :**
```lua
local unit = Unit.getByName("Viper 1-1")
local nearestBases = veafAirbases.getNearestAirbaseList(unit, 3)
for i, pair in ipairs(nearestBases) do
  local airbase = pair[1]
  local distance = pair[2]
  veaf.loggers.get("AIRBASES"):info("%d. %s (%dm)", i, airbase.Name, distance)
end
```

##### `veafAirbases.getNearestAirbase(dcsUnit)`

Obtient l'aérodrome le plus proche.

**Paramètres :**

- `dcsUnit` (DCS Unit) — Objet unité

**Retourne :** `veafAirbase` — Aérodrome le plus proche

**Exemple :**
```lua
local unit = Unit.getByName("Viper 1-1")
local nearest = veafAirbases.getNearestAirbase(unit)
veaf.outTextForUnit("Viper 1-1",
  string.format("Nearest airbase: %s", nearest.Name), 10)
```

---

### veafCarrierOperations.lua

**Module ID :** `CARRIER`

**Objectif :** Gérer les opérations de porte-avions

#### Fonctions

##### `veafCarrierOperations.startCarrierOperations(parameters)`

Démarre les opérations de recovery du porte-avions.

**Paramètres :**

- `parameters` (table) — `{carrierGroupName=string, userUnitName=string}`

**Retourne :** Rien

**Description :**

- Tourne le porte-avions face au vent
- Maintient la position pour la recovery
- Rapporte la direction du vent et les infos ATC

**Exemple :**
```lua
veafCarrierOperations.startCarrierOperations({
  carrierGroupName = "CVN-73",
  userUnitName = "Hornet 1-1"
})
```

##### `veafCarrierOperations.continueCarrierOperations(groupName, userUnitName)`

Poursuit les opérations du porte-avions.

**Paramètres :**

- `groupName` (string) — Nom du groupe porte-avions
- `userUnitName` (string, optionnel) — Unité utilisateur

**Retourne :** Rien

##### `veafCarrierOperations.stopCarrierOperations(parameters)`

Arrête les opérations du porte-avions.

**Paramètres :**

- `parameters` (table) — `{carrierGroupName=string}`

**Retourne :** Rien

**Description :** Ramène le porte-avions à la navigation normale.

##### `veafCarrierOperations.getAtcForCarrierOperations(groupName, skipNavigationData)`

Obtient les données ATC du porte-avions.

**Paramètres :**

- `groupName` (string) — Nom du groupe porte-avions
- `skipNavigationData` (boolean, optionnel) — Ignorer les infos de navigation

**Retourne :** `string` — Texte d'information ATC

**Exemple de sortie :**
```
CVN-73 Washington
Callsign: Mother
Position: N 42°15' E 041°45'
Heading: 270°
Wind: 285° at 25 kts
Radio: 127.5 MHz AM
TACAN: 73X (1205 MHz)
ICLS: 13
```

##### `veafCarrierOperations.atcForCarrierOperations(parameters)`

Obtient l'ATC pour le porte-avions (avec sortie).

**Paramètres :**

- `parameters` (table) — `{carrierGroupName=string, userUnitName=string}`

**Retourne :** Rien

##### `veafCarrierOperations.listAvailableCarriers(forGroup)`

Affiche les porte-avions disponibles.

**Paramètres :**

- `forGroup` (string, optionnel) — Nom du groupe recevant la liste

**Retourne :** Rien

##### `veafCarrierOperations.executeCommandFromRemote(parameters)`

Exécute depuis l'API distante.

**Paramètres :**

- `parameters` (table) — Paramètres de commande distante

**Retourne :** Rien

##### `veafCarrierOperations.initializeCarrierGroups()`

Initialise les groupes de porte-avions.

**Retourne :** Rien

##### `veafCarrierOperations.buildRadioMenu()`

Construit le menu radio des porte-avions.

**Retourne :** Rien

##### `veafCarrierOperations.initialize()`

Initialise le module opérations porte-avions.

**Retourne :** Rien

---

## Communication et contrôle

### veafRadio.lua

**Module ID :** `RADIO`

**Objectif :** Gérer les menus radio F10 et les communications

#### Constantes

```lua
veafRadio.RadioMenuName = "VEAF"
veafRadio.Keyphrase = "_radio"
veafRadio.BEACONS_SCHEDULE = 5  -- secondes
veafRadio.USAGE_ForAll = 0
veafRadio.USAGE_ForGroup = 1
veafRadio.USAGE_ForUnit = 2
```

#### Fonctions

##### `veafRadio.addSubMenu(title, parentMenu, coalitionSide)`

Ajoute un sous-menu au menu radio.

**Paramètres :**

- `title` (string) — Titre du sous-menu
- `parentMenu` (menu, optionnel) — Menu parent (nil = menu VEAF racine)
- `coalitionSide` (number, optionnel) — `coalition.side.RED` / `coalition.side.BLUE` : le
  sous-menu **et tout ce qu'il contient** ne sont montrés qu'à cette coalition (`nil` = tout le
  monde). L'appartenance est héritée par les sous-menus, les commandes et les pages de
  pagination ; une commande `USAGE_ForGroup` n'est posée que pour les groupes de ce camp.

**Retourne :** `menu` — Objet sous-menu

**Exemple :**
```lua
local assetsMenu = veafRadio.addSubMenu("Assets")
local tankersMenu = veafRadio.addSubMenu("Ravitailleurs", assetsMenu)
```

##### `veafRadio.addCommandToSubmenu(text, menu, callback, parameters, usage)`

Ajoute une commande à un sous-menu.

**Paramètres :**

- `text` (string) — Texte de la commande
- `menu` (menu) — Menu cible
- `callback` (function) — Fonction callback
- `parameters` (any, optionnel) — Paramètres passés au callback
- `usage` (number, optionnel) — Type d'usage : `USAGE_ForAll`, `USAGE_ForGroup`, `USAGE_ForUnit`

**Retourne :** Rien

**Signature du callback :**
```lua
function callback(parameters)
  -- parameters: value passed to addCommandToSubmenu
end
```

**Exemple :**
```lua
local menu = veafRadio.addSubMenu("Test")
veafRadio.addCommandToSubmenu("Dire Bonjour", menu, function(params)
  veaf.logger:info("Bonjour de %s !", params.unitName)
end, {unitName = "Player"}, veafRadio.USAGE_ForAll)
```

##### `veafRadio.addSecuredCommandToSubmenu(text, menu, callback, parameters, usage)`

Ajoute une commande protégée par la sécurité.

**Paramètres :** Identiques à `addCommandToSubmenu`

**Retourne :** Rien

**Description :** La commande n'apparaît que si l'utilisateur a l'habilitation de sécurité.

##### `veafRadio.executeCommand(eventPos, eventText, eventCoalition, bypassSecurity)`

Exécute une commande radio depuis un marqueur.

**Paramètres :**

- `eventPos` (vec3) — Position de la commande
- `eventText` (string) — Texte de la commande
- `eventCoalition` (coalition) — Coalition
- `bypassSecurity` (boolean, optionnel) — Ignorer la vérification de sécurité

**Retourne :** `boolean` — Indicateur de succès

**Commandes supportées :**

- `transmit` — Transmettre via SRS
- `playmp3` — Jouer un MP3 via SRS

##### `veafRadio.markTextAnalysis(text)`

Analyse le texte d'un marqueur radio.

**Paramètres :**

- `text` (string) — Texte du marqueur

**Retourne :** `table` — Options analysées

**Options :**
```lua
{
  transmit = boolean,      -- Transmit message
  playmp3 = boolean,       -- Play MP3 file
  message = string,        -- Message text
  frequencies = table,     -- Array of frequencies (MHz)
  modulations = table,     -- Array of "AM"/"FM"
  name = string,           -- Transmission name
  path = string,           -- MP3 file path
  quiet = boolean          -- Suppress confirmation
}
```

##### `veafRadio.transmitMessage(message, frequencies, modulations, name, coalition, position, quiet)`

Transmet un message via SRS.

**Paramètres :**

- `message` (string) — Texte du message (TTS)
- `frequencies` (table) — Tableau de fréquences
- `modulations` (table) — Tableau de modulations
- `name` (string) — Nom/indicatif de la transmission
- `coalition` (coalition, optionnel) — Coalition
- `position` (vec3, optionnel) — Origine de la transmission
- `quiet` (boolean, optionnel) — Supprimer la confirmation

**Retourne :** Rien

**Exemple :**
```lua
veafRadio.transmitMessage(
  "À tous les appareils, retour à la base",
  {251.0, 305.0},
  {"AM", "AM"},
  "Tour",
  coalition.side.BLUE,
  airbasePos,
  false
)
```

##### `veafRadio.playToRadio(path, frequencies, modulations, name, coalition, position, quiet)`

Joue un fichier MP3 via SRS.

**Paramètres :**

- `path` (string) — Chemin du fichier MP3
- Autres paramètres identiques à `transmitMessage`

**Retourne :** Rien

**Exemple :**
```lua
veafRadio.playToRadio(
  "D:\\Sounds\\airraid.mp3",
  {305.0},
  {"AM"},
  "Alert",
  coalition.side.BLUE,
  nil,
  false
)
```

##### `veafRadio.refreshRadioMenu()`

Reconstruit le menu radio (différé).

**Retourne :** Rien

**Description :** Planifie la reconstruction du menu après un délai pour éviter les conflits.

##### `veafRadio.addPaginatedRadioElements(menu, buildFunction, elements, sortKey, sortField)`

Ajoute des éléments paginés à un menu.

**Paramètres :**

- `menu` (menu) — Menu cible
- `buildFunction` (function) — Fonction de construction de chaque élément
- `elements` (table) — Tableau d'éléments
- `sortKey` (string, optionnel) — Clé de tri
- `sortField` (string, optionnel) — Champ de tri

**Retourne :** Rien

**Description :** Crée des pages de 10 éléments avec navigation suivant/précédent.

##### `veafRadio.onBirthEvent(event)`

Gère la naissance d'une unité (ajout au menu radio).

**Paramètres :**

- `event` (table) — Événement de naissance

**Retourne :** Rien

**Description :** Ajoute automatiquement les unités humaines au menu radio.

##### `veafRadio.initialize()`

Initialise le module radio.

**Retourne :** Rien

---

## Systèmes de support

### veafWeather.lua

**Module ID :** `WEATHER`

**Objectif :** Système météo dynamique

#### Fonctions

##### `veafWeatherData.getWeatherString(vec3, dcsElementName, unitSystem, iSurfaceAltitudeMeters)`

Construit le rapport météo textuel complet à une position donnée.

**Paramètres :**

- `vec3` (vec3) — Position
- `dcsElementName` (string) — Nom de l'élément DCS (sert à déduire le système d'unités par défaut)
- `unitSystem` (optionnel) — Système d'unités (par défaut déduit du type de l'élément)
- `iSurfaceAltitudeMeters` (number, optionnel) — Altitude de la surface en mètres

**Retourne :** `string` — Le rapport météo

##### `veafWeather.getWind(vec3, iAltitudeMeters, bTurbulence)`

Calcule le vent à une position et une altitude.

**Paramètres :**

- `vec3` (vec3) — Position
- `iAltitudeMeters` (number) — Altitude en mètres
- `bTurbulence` (boolean, optionnel) — Inclure la turbulence (par défaut `false`)

**Retourne :** `number, number` — Direction (degrés, « d'où vient le vent », `[1, 360]`) et vitesse (m/s)

##### `veafWeather.messageWeatherAtClosestPoint(unitName, forUnit)`

Affiche le rapport météo du point nommé le plus proche de l'unité.

**Paramètres :**

- `unitName` (string) — Nom de l'unité
- `forUnit` (boolean) — Si `true`, affiche au pilote uniquement ; sinon au groupe

##### `veafWeather.messageAtcClosestAirbase(unitName, forUnit)`

Affiche le rapport ATC (ATIS) de l'aérodrome le plus proche de l'unité.

**Paramètres :**

- `unitName` (string) — Nom de l'unité
- `forUnit` (boolean) — Si `true`, affiche au pilote uniquement ; sinon au groupe

##### `veafWeather.messageAtcAndWeather(unitName, forUnit)`

Affiche successivement le rapport ATC puis le rapport météo.

**Paramètres :**

- `unitName` (string) — Nom de l'unité
- `forUnit` (boolean) — Si `true`, affiche au pilote uniquement ; sinon au groupe

##### `veafWeather.createStaticFog(name, thickness, visibility)`

Crée un objet de brouillard statique.

**Paramètres :**

- `name` (string) — Nom du brouillard
- `thickness` (number) — Épaisseur (mètres)
- `visibility` (number) — Visibilité (mètres)

**Retourne :** Un objet brouillard

##### `veafWeather.createDynamicFog(name, baseFactor, notAnimated)`

Crée un objet de brouillard dynamique.

**Paramètres :**

- `name` (string) — Nom du brouillard
- `baseFactor` (number) — Facteur de base du brouillard dynamique
- `notAnimated` (boolean, optionnel) — Si `true`, le brouillard n'est pas animé

**Retourne :** Un objet brouillard

##### `veafWeather.createAnimatedFog(name, minutes, thickness, visibility)`

Crée un objet de brouillard animé sur une durée donnée.

**Paramètres :**

- `name` (string) — Nom du brouillard
- `minutes` (number) — Durée de l'animation (minutes)
- `thickness` (number) — Épaisseur (mètres)
- `visibility` (number) — Visibilité (mètres)

**Retourne :** Un objet brouillard

##### `veafWeather.setAndActivateFog(fogObject)`

Désactive le brouillard existant éventuel puis active l'objet de brouillard fourni.

**Paramètres :**

- `fogObject` — Un objet brouillard (créé via les fonctions `create*Fog` ou une constante `veafWeather.FOG_*`)

**Retourne :** L'objet brouillard activé

**Constantes de brouillard pré-définies :** `veafWeather.FOG_DYNAMIC_HEAVY`, `FOG_DYNAMIC_MEDIUM`, `FOG_DYNAMIC_SPARSE`, `FOG_STATIC_HEAVY`, `FOG_STATIC_MEDIUM`, `FOG_STATIC_MEDIUM_LOW`, `FOG_STATIC_SPARSE`, `FOG_STATIC_SPARSE_LOW`, `FOG_STATIC_NO`.

---

### veafTime.lua

**Module ID :** `TIME`

**Objectif :** Gestion du temps de mission

> Module en lecture seule : il **calcule** des informations de date et d'heure à
> partir de l'heure de mission, il ne modifie jamais l'heure ou la date de la mission.

#### Fonctions

##### `veafTime.getMissionDateTime(iAbsTime)`

Calcule la date et l'heure de mission correspondant à un temps absolu (gère les
débordements de jour, mois et année).

**Paramètres :**

- `iAbsTime` (number, optionnel) — Temps absolu (par défaut `timer.getAbsTime()`)

**Retourne :** `table` — `{ year, month, day, yday, hour, min, sec }`

##### `veafTime.absTimeToStringTime(iAbsTime, bWithSeconds)`

Formate un temps absolu en chaîne d'heure.

**Paramètres :**

- `iAbsTime` (number) — Temps absolu
- `bWithSeconds` (boolean, optionnel) — Inclure les secondes

**Retourne :** `string`

##### `veafTime.toZulu(dateTime, nOffsetHours)`

Convertit une date/heure locale en temps Zulu (UTC).

**Paramètres :**

- `dateTime` (table) — Date/heure (format de `getMissionDateTime`)
- `nOffsetHours` (number, optionnel) — Décalage horaire (par défaut déduit de `getTimezone`)

**Retourne :** `table` — Date/heure en Zulu

##### `veafTime.getSunTimesZulu(vec3, iAbsTime)`

Calcule les heures de lever et coucher du soleil (en Zulu) pour une position.

**Paramètres :**

- `vec3` (vec3) — Position
- `iAbsTime` (number) — Temps absolu

**Retourne :** Les heures de lever et de coucher du soleil

##### `veafTime.determineSeason(month, latitude)`

Détermine la saison à partir du mois et de la latitude (gère les deux hémisphères).

**Paramètres :**

- `month` (number) — Mois (1-12)
- `latitude` (number, optionnel) — Latitude (hémisphère nord si `nil` ou `>= 0`)

**Retourne :** `string` — Saison (« spring », « summer », « autumn », « winter »)

> Autres fonctions disponibles : `getMissionAbsTime`, `absTimeToDateTime`,
> `toStringDate` / `absTimeToStringDate`, `toStringTime`, `toStringDateTime` /
> `absTimeToStringDateTime`, `getTimezone`, `toLocal`, `getSunTimesLocal`,
> `isAeronauticalNight`.

---

## Données et base de données

### dcsUnits.lua

**Module ID :** `DCSUNITS`

**Version :** datamine-dc7d15e8

**Objectif :** Base de données complète des unités DCS

> Ce module n'expose pas de fonctions : il fournit uniquement des tables de données.

#### Structures de données

##### `dcsUnits.DcsUnitsDatabase`

Base de données brute des unités DCS, indexée par identifiant de type DCS.

Schéma de chaque entrée :
```lua
{
  type = ".Ammunition depot",      -- Identifiant de type DCS (clé de la table)
  name = "Ammunition depot",       -- Nom lisible
  kind = "static",                 -- Genre ("static", "vehicle", "plane", etc.)
  category = "Warehouse",          -- Catégorie DCS
  description = "Ammunition depot", -- Description
  attribute = {},                  -- Table des attributs DCS
}
```

##### `dcsUnits.NavalStatics`

Ensemble (table de booléens) des noms de statiques considérés comme navals :

```lua
dcsUnits.NavalStatics = {
  ["Gas platform"] = true,
  ["M1 barrage balloon"] = true,
  ["Oil platform"] = true,
  ["Oil rig"] = true,
  ["Orca"] = true,
  ["offshore WindTurbine"] = true,
  ["offshore WindTurbine2"] = true,
}
```

> Voir aussi [dcs-data.md](developer/dcs-data.md) pour la description détaillée du schéma.

---

### dcsDataExport.lua

**Module ID :** `DCSEXPORT`

**Objectif :** Script d'export de données DCS, à exécuter dans l'éditeur de mission

#### Description

Il ne s'agit pas d'une bibliothèque : ce script n'expose **aucune fonction
publique**. Il est conçu pour être chargé (`dofile`) à la fin du fichier
`DCS World\MissionEditor\modules\me_mission.lua`. Au chargement, il définit la
table globale `DcsDataExport` (utilitaires de log et de sérialisation interne)
puis exécute immédiatement l'export : il écrit la base de données des unités
(`db.Units.lua`) et appelle `browseUnits(...)` pour chaque catégorie d'unités
(Animal, Cargo, Vehicle, Effect, Fortification, GrassAirfield, GroundObject,
Helicopter, Heliport, Personnel, Plane, Ship, Warehouse).

Le répertoire de sortie est défini par la variable locale `export_path` (par
défaut `.\`, le répertoire courant).

---

## Annexe

### Patrons courants

#### Créer une commande de spawn

```lua
-- Via marqueur
local pos = {x=1000, y=0, z=2000}
veafSpawn.executeCommand(pos, "_spawn, name F-16C, group 2, hdg 270", coalition.side.BLUE)

-- Via interpréteur (dans le nom d'unité)
veafInterpreter.executeCommandOnUnit("SpawnTrigger1", "_spawn, name F-16C, group 2")

-- Programmatiquement
veafSpawn.spawnUnit(pos, 50, "F-16C", nil, nil, 5000, 270)
```

#### Écouter les événements

```lua
-- Enregistrer un callback
veafEventHandler.addCallback("myHandler", {"S_EVENT_TAKEOFF", "S_EVENT_LAND"},
  function(event)
    if event.initiator then
      veaf.logger:info("%s - %s", event.type.name, event.initiator.unitName)
    end
  end
)
```

#### Créer une mission

```lua
-- Définir un objectif
local objective = VeafCombatMissionObjective:new()
objective:setName("Détruire les chars")
objective:setOnStartup(function(mission)
  -- Spawner les chars
  local spawnPos = mist.utils.zoneToVec3("TargetZone")
  veafSpawn.spawnArmoredPlatoon(spawnPos, 100, nil, nil,
    coalition.side.RED, 0, 50, 2, 3, 3, true)
end)
objective:setOnCheck(function(mission)
  -- Vérifier la complétion
  if allTanksDestroyed() then
    return VeafCombatMissionObjective.SUCCESS
  end
  return VeafCombatMissionObjective.NOTHING
end)

-- Définir la mission
local mission = VeafCombatMission:new()
mission:setName("Chasse aux chars")
mission:setFriendlyName("Chasse aux chars")
mission:setBriefing("Détruire les blindés ennemis")
mission:addObjective(objective)

-- Enregistrer
veafCombatMission.AddMission(mission)
```

#### Construire des menus radio

```lua
-- Créer un sous-menu
local myMenu = veafRadio.addSubMenu("Mes commandes")

-- Ajouter une commande
veafRadio.addCommandToSubmenu("Faire quelque chose", myMenu, function(params)
  veaf.logger:info("Commande exécutée !")
  veaf.outTextForUnit(params.unitName, "Fait !", 5)
end, {unitName = "Viper 1-1"}, veafRadio.USAGE_ForAll)
```

### Bonnes pratiques de sécurité

1. **Utiliser veafSecurity pour les commandes sensibles**
2. **Valider la coalition avant de spawner**
3. **Utiliser bypassSecurity uniquement quand nécessaire**
4. **Vérifier les permissions utilisateur via les menus radio**

### Optimisation des performances

1. **Désactiver les événements inutilisés :** `veafEventHandler.setEventEnabled("S_EVENT_SHOOTING_START", false)`
2. **Utiliser les callbacks différés pour les opérations coûteuses**
3. **Limiter le nombre de spawns et les zones**
4. **Nettoyer régulièrement les groupes inactifs**

### Conseils de débogage

1. **Activer le logging trace :** `veafModuleName.LogLevel = "trace"`
2. **Utiliser les marqueurs logger :** `logger:marker(id, "Debug", "Position", pos)`
3. **Exporter les données pour analyse :** `veaf.exportAsJson(data, "debug", true, "debug.json")`
4. **Vérifier les handlers d'événements :** Vérifier que les callbacks sont bien enregistrés

---

## Historique des versions

- **v1.57.0** (veaf.lua) — Derniers utilitaires de base
- **v1.59.3** (veafSpawn.lua) — Dernier système de spawn
- **v2.2.1** (veafCombatMission.lua) — Dernier système de mission
- **v1.15.3** (veafCasMission.lua) — Dernier système CAS

---

## Crédits

**Projet VEAF :** https://www.veaf.org

**Dépôt :** https://github.com/VEAF/VEAF-Mission-Creation-Tools

**Documentation :** https://veaf.github.io/documentation/

**Développeur principal :** Zip (davidp57)

---

**Version du document :** 1.0

**Dernière mise à jour :** Juin 2026

**Généré pour :** VEAF Mission Creation Tools v6.5.25
