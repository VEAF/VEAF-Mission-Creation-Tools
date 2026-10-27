# Porter une mission à couche de scripts maison

Certaines missions ne se contentent pas des modules VEAF : elles portent leur propre couche de scripts, qui pilote les objectifs, les menus, la persistance, les porte-avions…
Cette page dit comment brancher une telle couche sur VMCT 6.
L'exemple suivi est celui de BFR (Bullseye Francophone), dont les campagnes tournaient sur VMCT 5.103.3 avec une vingtaine de scripts `bfr-*.lua` et un fichier `veafPatches.lua` qui remplaçait une quinzaine de fonctions VMCT au chargement.

La conversion elle-même se fait avec `.\veaf-tools.exe convert v5` : voir le [Guide de migration](MIGRATION_GUIDE.md#own-script-layer), qui dit ce que le convertisseur reprend tout seul.

## Isoler la couche derrière une seule interface {#one-interface}

La règle qui rend un portage court : **un seul fichier parle à VEAF**.
Chez BFR, c'est `bfr-veaf.lua` : chaque appel à VEAF y est enveloppé dans une fonction de la couche (`F.initializeCombatZone()`, `F.namedPointsSet(points)`…), et les autres scripts n'appellent que ces fonctions.
Quand VEAF change, on réécrit l'intérieur de ce fichier, pas les vingt autres.

Ce qui ne se met pas derrière l'interface — les triggers de l'éditeur, qui appellent `veafCombatZone.ActivateZone` ou `veafShortcuts.ExecuteBatchAliasesList` — doit se limiter aux fonctions stables de VEAF.

## Déclarer ses scripts et ses réglages {#declare}

- Les scripts de la couche se déclarent dans [`custom_scripts:`](../MISSION_YAML_REFERENCE.md#custom-scripts), **dans leur ordre de chargement** : données avant moteurs, interface VEAF avant ceux qui l'appellent.
  Ils se chargent après `veaf-config.lua` et `mission-script.lua`, donc après la configuration des modules.
- Un réglage de module écrit en dur dans un script (`veafRadio.RadioMenuName = "BFR"`) passe dans `module_settings:`.
- Un réglage que votre script **lisait dans ses données** (nom de mission, chemin d'export) passe dans `mission.yaml` : `veaf-config.lua` se charge avant tous vos scripts, il ne peut pas les lire.

## Les modules que la mission démarre elle-même {#initialized-by-mission}

Un module déclaré actif dans `modules:` est démarré par le `veaf-config.lua` généré.
Si votre couche le démarre aussi, il l'est **deux fois** : deux réseaux Skynet, des menus en double, la boucle des porte-avions relancée.
Le déclarer à `false` n'est pas une issue pour `SKYNET` ni `CTLD` : `false` retire aussi le script communautaire.

La clé `initialized_by_mission: true` garde le script et applique la configuration, mais laisse l'appel `initialize()` à vos scripts :

```yaml
modules:
  SHORTCUTS:
    enabled: true
    initialized_by_mission: true   # bfr-raccourcis.lua l'initialise
  SKYNET:
    enabled: true
    initialized_by_mission: true   # bfr-iads.lua appelle veafSkynet.initialize(...)
    last_line_of_defence: false    # les réglages s'appliquent quand même
```

Elle vaut pour tout module de `modules:`, et pour `SKYNET`, `CTLD` et `CSAR`.
Pour `CTLD`, vos scripts doivent alors appeler `veaf.ctld_initialize()`, pas le `ctld.initialize()` de CTLD v1 : c'est lui qui démarre CTLD 2 avec son menu et la logistique des aérodromes ; `convert v5` ne confie donc jamais CTLD à la mission.
`veaf.initialize()` saute aussi un tel module, si votre couche s'en sert.

## Les fonctions qui servent à une couche maison {#functions}

| besoin | v6 |
|---|---|
| porte-avions sans la boucle VEAF de 60 s | `CARRIER.init.operations_scheduler: false` — voir [veafCarrierOperations](scripts/veafCarrierOperations.md) |
| pas d'accueil météo VEAF à la prise de slot (la couche a le sien) | `WEATHER.welcomeBrief: false` — voir [veafWeather](scripts/veafWeather.md#welcome-brief) |
| déclarer un lot de points nommés depuis un script | `veafNamedPoints.declarePoints(points)` — voir [veafNamedPoints](scripts/veafNamedPoints.md#declare-points) |
| un sous-menu F10 réservé à certains groupes | `veafRadio.addSubMenuForGroups(titre, parent, filtre)` — voir [veafRadio](scripts/veafRadio.md#group-and-pilot-menus) |
| un sous-menu par pilote dans les groupes à plusieurs places, réponse au seul cliqueur | `veafRadio.addSubMenuPerPilot(titre, parent)` et `veaf.outTextForUnit(nomUnité, …)` |
| un raccourci sans mot de passe qui admet quelques options | `VeafAlias:setAllowedOptions{…}` — voir [veafShortcuts](scripts/veafShortcuts.md#bypass-options) |

Les commandes F10 par groupe suivent maintenant les pilotes présents : quand un pilote quitte son slot, ses équipiers retrouvent les commandes du groupe.
Une couche qui corrigeait ce point elle-même (BFR remplaçait `veafRadio.refreshRadioSubmenu`) peut retirer son correctif.

## Ce qui a changé depuis la v5 {#v5-changes}

| v5 | v6 |
|---|---|
| `veafNamedPoints.Points = {…}` | `veafNamedPoints.declarePoints(points)`, ou `NAMEDPOINTS.custom_points` dans `mission.yaml` |
| `veafCombatZone.HideZoneNameFromGroupNames` | `mission.hide_names_from_spawned_groups` |
| `veafWeatherAtis.getAtisString` rend une phrase de repli sans ATIS | rend `nil` : à accepter |
| libellés de menus et messages VEAF en texte | clés de traduction ; un texte qui n'est pas une clé s'affiche tel quel |
| CTLD v1 (`ctld.initialize(callback)`, `ctld.addCallback`) | CTLD 2, configuré par `ctld-config.yaml` (voir plus bas) |
| `WeatherMark`, `HoundElint`, `Hercules_Cargo` livrés | absents |

Les tables que BFR lit en direct existent toujours, avec les champs utilisés : `veafCombatZone.zonesList`, `.rootPath`, `veafRadio.USAGE_ForGroup`, `.humanGroups`, `.radioMenu`, `veafQraManager.qras`, `.STATUS_DEAD`, `veafCarrierOperations.carriers`, `.continueCarrierOperations`.

## Se passer de MiST {#mist}

MiST n'est plus livré d'office : le build le réinjecte quand un de vos scripts écrit `mist.`, ce qui marche mais ajoute 336 Ko au `.miz`.
VMCT 6 a les équivalents :

| MiST | v6 |
|---|---|
| `mist.scheduleFunction` | `veaf.scheduleFunction` |
| `mist.DBs.humansByName` | `veafMissionDb.getAllHumanRecords()` (slots dynamiques compris) |
| `mist.DBs.unitsByName` | `veafMissionDb.getAllUnitRecords()` |
| `mist.DBs.groupsByName` | `veafMissionDb.getAllGroupRecords()`, `veaf.getGroupRecord(nom)` |
| `mist.DBs.groupsById` | `veafMissionDb.getGroupRecordById(id)` (`coalition` reste `"red"` / `"blue"`) |
| `mist.getGroupRoute(nom, "task")`, `mist.goRoute` | `veafDcsSpawner.getGroupRoute(nom)`, `veafDcsSpawner.goRoute` |
| `mist.getHeading(unité, true)` | `veafGeo.getHeading` |
| `mist.vec.mag`, `mist.utils.round`, `mist.utils.toDegree` | `veafMath.vecMag`, `veaf.round`, `math.deg` |

**Le piège** : un appel protégé par `if mist and mist.xxx then` se tait **sans erreur** quand MiST n'est plus là.
Après remplacement, une recherche de `mist` dans `src/scripts` doit rendre zéro, et le journal du build ne doit plus dire que MiST est réinjecté.

## CTLD 2 : ce qui remplace les lectures de CTLD v1 {#ctld2}

CTLD 2 ne se configure plus par script : sa configuration est le `ctld-config.yaml` de la mission, édité avec `ctld-tools.exe`.
Une couche qui lisait l'intérieur de CTLD v1 passe par ses événements et ses gestionnaires :

| lecture CTLD v1 | CTLD 2 |
|---|---|
| `ctld.builtFOBS`, `buildTimeFOB` | événements `OnFOBDeployed`, `OnFOBDestroyed` ; `CTLDFOBManager.getInstance():getFOBsForCoalition(coalition)` ; le délai de construction est dans `ctld-config.yaml` |
| `ctld.pickupZones` | `CTLDZoneManager.getInstance():getTroopZonesForCoalition(coalition)`, `getTroopZoneAtPoint(point, coalition)` ; événement `OnTroopZoneUpdated` |
| `ctld.logisticUnits` | `CTLDZoneManager.getInstance():getLogisticZonesForCoalition(coalition)`, `getLogisticZoneAtPoint(point, coalition)` ; événement `OnLogisticZoneUpdated` |
| `ctld.completeAASystems` | événements `OnAASystemDeployed`, `OnAASystemRepaired`, `OnAASystemRearmed` |
| `ctld.addCallback` (gestes des joueurs) | `EventDispatcher.getInstance():subscribe(nom, fonction)` sur `OnTroopsDeployed`, `OnCrateLoaded`, `OnCrateUnpacked`, `OnVehicleLoaded`, `OnVehicleUnloaded`, `OnJTACSpawned`… |

CTLD 2.0.0-rc13 publie 47 événements ; leur liste est dans `CTLD.lua` (`EventDispatcher:publish`).
Chaque abonné reçoit une table qui décrit le geste (`carrierUnitName`, `player`, `fob.name`…).
VMCT n'ajoute pas d'interface tant qu'un besoin de BFR n'est pas couvert par ces événements.

## Les comportements par défaut de la v6 à connaître {#v6-defaults}

| changement | effet | retrouver l'ancien comportement |
|---|---|---|
| Skynet « last line of defence » : chaque site SAM détecte seul à 10-15 km | voler sous la couverture radar ne protège plus | `SKYNET.last_line_of_defence: false` |
| groupes de zone qui ont une route : alerte AUTO au lieu de rouge | convois et renforts se mettent à rouler | `module_settings: veafCombatZone.DefaultAlarmStateMobile: 2` |
| accueil météo VEAF à chaque prise de slot | deux accueils si la couche a le sien | `WEATHER.welcomeBrief: false` |
| chaque aérodrome devient une zone logistique CTLD | caisses et troupes sur tout terrain tenu | `CTLD.manage_airbase_logistics: false` |
| pagination des menus au-delà de 10 entrées | menus longs en pages | `veafRadio.doNotPaginate(menu)` |
| messages VEAF dans la langue du poste qui build | | `mission.language: fr` explicite |

## À tester en jeu {#in-game-checks}

À deux joueurs au moins dans un même groupe :

- les menus F10 par pilote, puis après le départ du premier pilote du groupe ;
- un sous-menu réservé, invisible aux groupes qu'il n'admet pas ;
- le cycle complet d'un porte-avions, sans doublon de boucle ;
- un seul accueil à la prise de slot ;
- les raccourcis sans mot de passe (`-jtac, laser 1511`, `-smoke, color red`), et le refus d'une option qu'ils n'admettent pas, sur un serveur ;
- les modules déclarés `initialized_by_mission` : un seul réseau Skynet, un seul menu par module ;
- les gestes CTLD : FOB, troupes, JTAC.
