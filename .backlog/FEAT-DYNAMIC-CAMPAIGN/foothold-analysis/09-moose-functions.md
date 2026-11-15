# 09 — Fonctions de Moose utilisées par Foothold 6.5.3

Relevé mécanique du 2026-11-15 sur le tag `v6.5.3` (commit `27d8cf4a`), par un script qui lit les sept scripts Foothold chargés par la mission Caucase et les compare aux classes et méthodes définies dans le Moose embarqué (`Common Scripts/Moose_2026-10-11.lua`).
Les commentaires Lua sont retirés avant le comptage ; les comptes diffèrent donc un peu du recensement de la note 02, qui comptait les commentaires.

Colonnes des fichiers : `zc2` = `zoneCommanderv2.lua` (le moteur), `setup` = `MA_Setup_CAv2.lua`, `ctld` = `Foothold CTLD.lua`, `ctldred` = `Foothold_CTLD_Red.lua`, `wm` = `WelcomeMessage.lua`, `ewrs` = `EWRS.lua`, `zeus` = `Zeus.lua`.
`AIEN.lua` et `Splash_Damage_3.4.1_leka.lua` ne sont pas comptés : ce sont des scripts tiers.

## Ce que le relevé dit et ne dit pas

- **Section 1, appels statiques** (`CLASSE:Méthode(` ou `CLASSE.Membre`) : le relevé est exact, la classe est écrite dans le code.
- **Section 2, méthodes d'instance** (`objet:Méthode(`) : le relevé est une approximation.
  Une méthode y figure quand son nom commence par une majuscule, qu'elle est définie dans Moose et qu'aucun script Foothold ne définit de méthode du même nom.
  La classe de l'objet n'est pas connue du script : la colonne « Classes Moose » liste celles qui définissent ce nom.
  Une méthode que Foothold redéfinit sous le même nom qu'une méthode Moose est donc absente, et un objet Foothold qui porterait une méthode homonyme serait compté à tort.
- Le Moose embarqué définit 341 classes ou tables globales ; Foothold en nomme 42 en statique.
- La classe `JTAC` est exclue : Foothold définit la sienne dans le moteur, qui remplace celle de Moose.
- Les constantes (`ENUMS.…`, `EVENTS.…`, `AIRBASE.TerminalType.…`, `CTLD_CARGO.Enum.…`) sont des membres de tables, pas des fonctions ; elles sont listées parce qu'il faudrait les remplacer aussi.

## 1. Appels statiques, par classe

| Classe | Membres distincts | Occurrences |
|---|---|---|
| `UTILS` | 29 | 484 |
| `COORDINATE` | 5 | 193 |
| `SCHEDULER` | 1 | 120 |
| `GROUP` | 2 | 110 |
| `MESSAGE` | 1 | 91 |
| `AIRBASE` | 5 | 71 |
| `CTLD_CARGO` | 1 | 63 |
| `SPAWN` | 4 | 58 |
| `CTLD` | 5 | 55 |
| `STORAGE` | 3 | 52 |
| `ZONE` | 2 | 47 |
| `BASE` | 3 | 35 |
| `EVENTS` | 11 | 25 |
| `SCENERY` | 1 | 24 |
| `UNIT` | 2 | 19 |
| `ENUMS` | 3 | 16 |
| `MENU_GROUP_COMMAND` | 1 | 15 |
| `MENU_GROUP` | 2 | 14 |
| `TIMER` | 2 | 11 |
| `STATIC` | 1 | 10 |
| `SET_GROUP` | 1 | 9 |
| `ZONE_RADIUS` | 1 | 9 |
| `SET_CLIENT` | 1 | 7 |
| `AUFTRAG` | 3 | 6 |
| `SPAWNSTATIC` | 2 | 4 |
| `CLIENT` | 2 | 3 |
| `FLIGHTGROUP` | 1 | 3 |
| `WEAPON` | 1 | 3 |
| `MANTIS` | 2 | 3 |
| `SET_UNIT` | 1 | 3 |
| `USERSOUND` | 1 | 2 |
| `EVENT` | 1 | 2 |
| `NAVYGROUP` | 1 | 2 |
| `BEACON` | 2 | 2 |
| `SET_ZONE` | 1 | 2 |
| `ZONE_UNIT` | 1 | 1 |
| `MARKER` | 1 | 1 |
| `ASTAR` | 1 | 1 |
| `ZONE_ELASTIC` | 1 | 1 |
| `ZONE_GROUP` | 1 | 1 |
| `ARMYGROUP` | 1 | 1 |
| `EVENTHANDLER` | 1 | 1 |

### `UTILS`

| Membre | Total | zc2 | setup | ctld | ctldred | wm | ewrs | zeus |
|---|---|---|---|---|---|---|---|---|
| `UTILS.NMToMeters` | 112 | 107 |  |  |  | 5 |  |  |
| `UTILS.FeetToMeters` | 80 | 71 |  |  |  | 9 |  |  |
| `UTILS.DeepCopy` | 47 | 34 | 8 | 4 | 1 |  |  |  |
| `UTILS.Round` | 40 |  |  |  |  |  | 40 |  |
| `UTILS.KnotsToKmph` | 33 | 32 |  |  |  | 1 |  |  |
| `UTILS.MpsToKmph` | 26 | 21 |  |  |  | 1 | 4 |  |
| `UTILS.KnotsToMps` | 23 | 21 |  |  |  | 2 |  |  |
| `UTILS.MetersToNM` | 21 | 17 |  |  |  |  | 4 |  |
| `UTILS.VecDist2D` | 16 | 15 |  |  | 1 |  |  |  |
| `UTILS.IasToTas` | 14 | 12 |  |  |  | 2 |  |  |
| `UTILS.VecDist3D` | 10 | 10 |  |  |  |  |  |  |
| `UTILS.GetMarkID` | 8 | 8 |  |  |  |  |  |  |
| `UTILS.MetersToFeet` | 7 |  |  |  |  | 2 | 5 |  |
| `UTILS.SpawnFARPAndFunctionalStatics` | 6 | 4 |  | 2 |  |  |  |  |
| `UTILS.LoadFromFile` | 5 | 3 |  | 2 |  |  |  |  |
| `UTILS.VecTranslate` | 5 | 5 |  |  |  |  |  |  |
| `UTILS.MpsToKnots` | 4 |  |  |  |  |  | 4 |  |
| `UTILS.Split` | 4 | 2 |  | 2 |  |  |  |  |
| `UTILS.Vec2Translate` | 4 | 3 |  |  |  | 1 |  |  |
| `UTILS.SaveToFile` | 3 | 2 |  | 1 |  |  |  |  |
| `UTILS.TACANToFrequency` | 3 | 2 |  |  |  | 1 |  |  |
| `UTILS.GetReportingName` | 2 | 1 |  |  |  |  | 1 |  |
| `UTILS.VecHdg` | 2 | 2 |  |  |  |  |  |  |
| `UTILS.VecNorm` | 2 | 2 |  |  |  |  |  |  |
| `UTILS._MarkID` | 2 | 2 |  |  |  |  |  |  |
| `UTILS.tostringMGRS` | 2 | 2 |  |  |  |  |  |  |
| `UTILS.DoString` | 1 | 1 |  |  |  |  |  |  |
| `UTILS.GetMagneticDeclination` | 1 |  |  |  |  | 1 |  |  |
| `UTILS.IsPointInPolygon` | 1 | 1 |  |  |  |  |  |  |

### `COORDINATE`

| Membre | Total | zc2 | setup | ctld | ctldred | wm | ewrs | zeus |
|---|---|---|---|---|---|---|---|---|
| `COORDINATE:New` | 130 | 129 |  |  |  | 1 |  |  |
| `COORDINATE:NewFromVec3` | 54 | 43 |  | 7 |  | 3 |  | 1 |
| `COORDINATE:NewFromVec2` | 5 | 3 |  | 2 |  |  |  |  |
| `COORDINATE.WaypointAction` | 2 | 2 |  |  |  |  |  |  |
| `COORDINATE:TaskCargoTransportation` | 2 | 2 |  |  |  |  |  |  |

### `SCHEDULER`

| Membre | Total | zc2 | setup | ctld | ctldred | wm | ewrs | zeus |
|---|---|---|---|---|---|---|---|---|
| `SCHEDULER:New` | 120 | 96 | 6 | 8 | 2 | 8 |  |  |

### `GROUP`

| Membre | Total | zc2 | setup | ctld | ctldred | wm | ewrs | zeus |
|---|---|---|---|---|---|---|---|---|
| `GROUP:FindByName` | 106 | 85 | 2 | 10 | 3 | 6 |  |  |
| `GROUP:NewTemplate` | 4 |  | 4 |  |  |  |  |  |

### `MESSAGE`

| Membre | Total | zc2 | setup | ctld | ctldred | wm | ewrs | zeus |
|---|---|---|---|---|---|---|---|---|
| `MESSAGE:New` | 91 | 39 |  | 14 | 3 | 35 |  |  |

### `AIRBASE`

| Membre | Total | zc2 | setup | ctld | ctldred | wm | ewrs | zeus |
|---|---|---|---|---|---|---|---|---|
| `AIRBASE:FindByName` | 34 | 25 | 3 | 5 |  | 1 |  |  |
| `AIRBASE.TerminalType` | 22 | 21 |  |  |  | 1 |  |  |
| `AIRBASE:FindByID` | 10 | 10 |  |  |  |  |  |  |
| `AIRBASE.GetAllAirbases` | 3 | 3 |  |  |  |  |  |  |
| `AIRBASE.FindByName` | 2 | 1 |  | 1 |  |  |  |  |

### `CTLD_CARGO`

| Membre | Total | zc2 | setup | ctld | ctldred | wm | ewrs | zeus |
|---|---|---|---|---|---|---|---|---|
| `CTLD_CARGO.Enum` | 63 |  |  | 48 | 15 |  |  |  |

### `SPAWN`

| Membre | Total | zc2 | setup | ctld | ctldred | wm | ewrs | zeus |
|---|---|---|---|---|---|---|---|---|
| `SPAWN:NewFromTemplate` | 21 | 19 |  | 2 |  |  |  |  |
| `SPAWN:NewWithAlias` | 17 | 12 | 2 |  |  | 2 |  | 1 |
| `SPAWN.Takeoff` | 16 | 15 |  |  |  | 1 |  |  |
| `SPAWN:New` | 4 | 4 |  |  |  |  |  |  |

### `CTLD`

| Membre | Total | zc2 | setup | ctld | ctldred | wm | ewrs | zeus |
|---|---|---|---|---|---|---|---|---|
| `CTLD.CargoZoneType` | 44 | 3 |  | 28 | 13 |  |  |  |
| `CTLD.UnitTypeCapabilities` | 6 | 6 |  |  |  |  |  |  |
| `CTLD._CleanUpCrates` | 2 |  |  | 2 |  |  |  |  |
| `CTLD:New` | 2 |  |  | 1 | 1 |  |  |  |
| `CTLD._BuildObjectFromCrates` | 1 |  |  | 1 |  |  |  |  |

### `STORAGE`

| Membre | Total | zc2 | setup | ctld | ctldred | wm | ewrs | zeus |
|---|---|---|---|---|---|---|---|---|
| `STORAGE:FindByName` | 44 | 23 |  | 15 | 6 |  |  |  |
| `STORAGE.FindByName` | 4 | 3 |  | 1 |  |  |  |  |
| `STORAGE.Liquid` | 4 |  |  | 4 |  |  |  |  |

### `ZONE`

| Membre | Total | zc2 | setup | ctld | ctldred | wm | ewrs | zeus |
|---|---|---|---|---|---|---|---|---|
| `ZONE:FindByName` | 40 | 37 |  | 3 |  |  |  |  |
| `ZONE:New` | 7 | 2 | 2 | 1 |  | 2 |  |  |

### `BASE`

| Membre | Total | zc2 | setup | ctld | ctldred | wm | ewrs | zeus |
|---|---|---|---|---|---|---|---|---|
| `BASE:I` | 27 | 20 |  | 4 | 2 | 1 |  |  |
| `BASE:E` | 7 | 3 |  | 4 |  |  |  |  |
| `BASE:New` | 1 |  |  |  |  |  | 1 |  |

### `EVENTS`

| Membre | Total | zc2 | setup | ctld | ctldred | wm | ewrs | zeus |
|---|---|---|---|---|---|---|---|---|
| `EVENTS.Shot` | 6 | 6 |  |  |  |  |  |  |
| `EVENTS.Birth` | 3 |  |  | 1 |  |  | 2 |  |
| `EVENTS.UnitLost` | 3 | 1 |  |  |  |  | 2 |  |
| `EVENTS.BaseCaptured` | 2 |  |  |  |  | 2 |  |  |
| `EVENTS.Crash` | 2 |  |  |  |  |  | 2 |  |
| `EVENTS.Dead` | 2 |  |  |  |  |  | 2 |  |
| `EVENTS.PlayerLeaveUnit` | 2 |  |  |  |  | 2 |  |  |
| `EVENTS.RemoveUnit` | 2 |  |  |  |  |  | 2 |  |
| `EVENTS.Hit` | 1 | 1 |  |  |  |  |  |  |
| `EVENTS.Refueling` | 1 |  |  |  |  | 1 |  |  |
| `EVENTS.RefuelingStop` | 1 |  |  |  |  | 1 |  |  |

### `SCENERY`

| Membre | Total | zc2 | setup | ctld | ctldred | wm | ewrs | zeus |
|---|---|---|---|---|---|---|---|---|
| `SCENERY:FindByZoneName` | 24 |  | 24 |  |  |  |  |  |

### `UNIT`

| Membre | Total | zc2 | setup | ctld | ctldred | wm | ewrs | zeus |
|---|---|---|---|---|---|---|---|---|
| `UNIT:FindByName` | 14 | 5 |  |  |  | 8 | 1 |  |
| `UNIT:Find` | 5 | 2 |  |  |  |  | 3 |  |

### `ENUMS`

| Membre | Total | zc2 | setup | ctld | ctldred | wm | ewrs | zeus |
|---|---|---|---|---|---|---|---|---|
| `ENUMS.WeaponFlag` | 9 | 9 |  |  |  |  |  |  |
| `ENUMS.FARPType` | 6 | 4 |  | 2 |  |  |  |  |
| `ENUMS.Formation` | 1 | 1 |  |  |  |  |  |  |

### `MENU_GROUP_COMMAND`

| Membre | Total | zc2 | setup | ctld | ctldred | wm | ewrs | zeus |
|---|---|---|---|---|---|---|---|---|
| `MENU_GROUP_COMMAND:New` | 15 |  |  |  |  | 15 |  |  |

### `MENU_GROUP`

| Membre | Total | zc2 | setup | ctld | ctldred | wm | ewrs | zeus |
|---|---|---|---|---|---|---|---|---|
| `MENU_GROUP:New` | 13 | 6 |  |  |  | 7 |  |  |
| `MENU_GROUP.New` | 1 | 1 |  |  |  |  |  |  |

### `TIMER`

| Membre | Total | zc2 | setup | ctld | ctldred | wm | ewrs | zeus |
|---|---|---|---|---|---|---|---|---|
| `TIMER:New` | 8 | 3 |  | 4 | 1 |  |  |  |
| `TIMER.New` | 3 | 3 |  |  |  |  |  |  |

### `STATIC`

| Membre | Total | zc2 | setup | ctld | ctldred | wm | ewrs | zeus |
|---|---|---|---|---|---|---|---|---|
| `STATIC:FindByName` | 10 | 5 |  | 2 |  | 3 |  |  |

### `SET_GROUP`

| Membre | Total | zc2 | setup | ctld | ctldred | wm | ewrs | zeus |
|---|---|---|---|---|---|---|---|---|
| `SET_GROUP:New` | 9 | 7 |  | 2 |  |  |  |  |

### `ZONE_RADIUS`

| Membre | Total | zc2 | setup | ctld | ctldred | wm | ewrs | zeus |
|---|---|---|---|---|---|---|---|---|
| `ZONE_RADIUS:New` | 9 | 2 |  | 4 |  |  |  | 3 |

### `SET_CLIENT`

| Membre | Total | zc2 | setup | ctld | ctldred | wm | ewrs | zeus |
|---|---|---|---|---|---|---|---|---|
| `SET_CLIENT:New` | 7 | 3 |  | 1 |  | 2 | 1 |  |

### `AUFTRAG`

| Membre | Total | zc2 | setup | ctld | ctldred | wm | ewrs | zeus |
|---|---|---|---|---|---|---|---|---|
| `AUFTRAG:NewARTY` | 3 | 3 |  |  |  |  |  |  |
| `AUFTRAG:NewANTISHIP` | 2 | 2 |  |  |  |  |  |  |
| `AUFTRAG:NewINTERCEPT` | 1 | 1 |  |  |  |  |  |  |

### `SPAWNSTATIC`

| Membre | Total | zc2 | setup | ctld | ctldred | wm | ewrs | zeus |
|---|---|---|---|---|---|---|---|---|
| `SPAWNSTATIC:NewFromTemplate` | 3 | 2 |  |  |  | 1 |  |  |
| `SPAWNSTATIC:NewFromType` | 1 | 1 |  |  |  |  |  |  |

### `CLIENT`

| Membre | Total | zc2 | setup | ctld | ctldred | wm | ewrs | zeus |
|---|---|---|---|---|---|---|---|---|
| `CLIENT:FindByPlayerName` | 2 | 1 |  | 1 |  |  |  |  |
| `CLIENT:FindByName` | 1 | 1 |  |  |  |  |  |  |

### `FLIGHTGROUP`

| Membre | Total | zc2 | setup | ctld | ctldred | wm | ewrs | zeus |
|---|---|---|---|---|---|---|---|---|
| `FLIGHTGROUP:New` | 3 | 3 |  |  |  |  |  |  |

### `WEAPON`

| Membre | Total | zc2 | setup | ctld | ctldred | wm | ewrs | zeus |
|---|---|---|---|---|---|---|---|---|
| `WEAPON:New` | 3 | 3 |  |  |  |  |  |  |

### `MANTIS`

| Membre | Total | zc2 | setup | ctld | ctldred | wm | ewrs | zeus |
|---|---|---|---|---|---|---|---|---|
| `MANTIS:New` | 2 | 2 |  |  |  |  |  |  |
| `MANTIS.SamType` | 1 | 1 |  |  |  |  |  |  |

### `SET_UNIT`

| Membre | Total | zc2 | setup | ctld | ctldred | wm | ewrs | zeus |
|---|---|---|---|---|---|---|---|---|
| `SET_UNIT:New` | 3 |  |  |  |  |  | 3 |  |

### `USERSOUND`

| Membre | Total | zc2 | setup | ctld | ctldred | wm | ewrs | zeus |
|---|---|---|---|---|---|---|---|---|
| `USERSOUND:New` | 2 | 1 |  | 1 |  |  |  |  |

### `EVENT`

| Membre | Total | zc2 | setup | ctld | ctldred | wm | ewrs | zeus |
|---|---|---|---|---|---|---|---|---|
| `EVENT:New` | 2 | 2 |  |  |  |  |  |  |

### `NAVYGROUP`

| Membre | Total | zc2 | setup | ctld | ctldred | wm | ewrs | zeus |
|---|---|---|---|---|---|---|---|---|
| `NAVYGROUP:New` | 2 | 2 |  |  |  |  |  |  |

### `BEACON`

| Membre | Total | zc2 | setup | ctld | ctldred | wm | ewrs | zeus |
|---|---|---|---|---|---|---|---|---|
| `BEACON.System` | 1 | 1 |  |  |  |  |  |  |
| `BEACON.Type` | 1 | 1 |  |  |  |  |  |  |

### `SET_ZONE`

| Membre | Total | zc2 | setup | ctld | ctldred | wm | ewrs | zeus |
|---|---|---|---|---|---|---|---|---|
| `SET_ZONE:New` | 2 | 1 |  | 1 |  |  |  |  |

### `ZONE_UNIT`

| Membre | Total | zc2 | setup | ctld | ctldred | wm | ewrs | zeus |
|---|---|---|---|---|---|---|---|---|
| `ZONE_UNIT:New` | 1 | 1 |  |  |  |  |  |  |

### `MARKER`

| Membre | Total | zc2 | setup | ctld | ctldred | wm | ewrs | zeus |
|---|---|---|---|---|---|---|---|---|
| `MARKER:New` | 1 | 1 |  |  |  |  |  |  |

### `ASTAR`

| Membre | Total | zc2 | setup | ctld | ctldred | wm | ewrs | zeus |
|---|---|---|---|---|---|---|---|---|
| `ASTAR:New` | 1 | 1 |  |  |  |  |  |  |

### `ZONE_ELASTIC`

| Membre | Total | zc2 | setup | ctld | ctldred | wm | ewrs | zeus |
|---|---|---|---|---|---|---|---|---|
| `ZONE_ELASTIC:New` | 1 | 1 |  |  |  |  |  |  |

### `ZONE_GROUP`

| Membre | Total | zc2 | setup | ctld | ctldred | wm | ewrs | zeus |
|---|---|---|---|---|---|---|---|---|
| `ZONE_GROUP:New` | 1 | 1 |  |  |  |  |  |  |

### `ARMYGROUP`

| Membre | Total | zc2 | setup | ctld | ctldred | wm | ewrs | zeus |
|---|---|---|---|---|---|---|---|---|
| `ARMYGROUP:New` | 1 | 1 |  |  |  |  |  |  |

### `EVENTHANDLER`

| Membre | Total | zc2 | setup | ctld | ctldred | wm | ewrs | zeus |
|---|---|---|---|---|---|---|---|---|
| `EVENTHANDLER:New` | 1 |  |  |  |  |  |  | 1 |

## 2. Méthodes d'instance (approximation)

275 méthodes distinctes, 2440 occurrences.

| Méthode | Total | zc2 | setup | ctld | ctldred | wm | ewrs | zeus | Classes Moose qui la définissent |
|---|---|---|---|---|---|---|---|---|---|
| `:GetName` | 274 | 126 |  | 79 | 29 | 40 |  |  | `AUFTRAG`, `AWACS`, `COHORT`, `COORDINATE` et 14 autres |
| `:IsAlive` | 151 | 59 |  | 61 | 10 | 21 |  |  | `GROUP`, `IDENTIFIABLE`, `OPSGROUP`, `SCENERY` et 2 autres |
| `:GetCoordinate` | 143 | 90 |  | 39 | 1 | 13 |  |  | `AIRBOSS`, `BEACONS`, `COORDINATE`, `FLIGHTCONTROL` et 17 autres |
| `:GetDCSObject` | 112 | 54 | 22 | 28 | 7 | 1 |  |  | `AIRBASE`, `DYNAMICCARGO`, `GROUP`, `OPSGROUP` et 5 autres |
| `:GetVec3` | 74 | 37 | 2 | 26 | 5 | 4 |  |  | `BEACONS`, `COORDINATE`, `GROUP`, `OPSGROUP` et 11 autres |
| `:WaypointAirTurningPoint` | 73 | 70 |  |  |  | 3 |  |  | `COORDINATE` |
| `:GetCoalition` | 67 | 32 | 4 | 12 | 3 | 16 |  |  | `AIRBOSS`, `ATIS`, `COMMANDER`, `FLIGHTCONTROL` et 8 autres |
| `:Destroy` | 65 | 29 | 1 | 25 | 6 | 1 |  | 3 | `DYNAMICCARGO`, `GROUP`, `OBJECT`, `OPSGROUP` et 4 autres |
| `:GetID` | 52 | 20 |  | 13 | 6 | 12 | 1 |  | `AIRBASE`, `CTLD_CARGO`, `OBJECT`, `SCENERY` |
| `:GetVec2` | 36 | 27 |  | 4 |  | 1 |  | 4 | `AIRBASE`, `COORDINATE`, `GROUP`, `OPSGROUP` et 13 autres |
| `:SetItem` | 34 | 28 |  | 6 |  |  |  |  | `STORAGE` |
| `:Route` | 33 | 29 |  | 3 |  | 1 |  |  | `CONTROLLABLE`, `OPSGROUP` |
| `:Get2DDistance` | 32 | 18 |  | 9 |  | 5 |  |  | `COORDINATE`, `OPSGROUP`, `ZONE_BASE` |
| `:Get` | 28 | 24 |  | 1 | 1 | 2 |  |  | `FSM_SET`, `SET_BASE`, `USERFLAG`, `VELOCITY` et 1 autres |
| `:WaypointAirLanding` | 27 | 26 |  |  |  | 1 |  |  | `COORDINATE` |
| `:GetPositionable` | 25 |  |  | 21 | 4 |  |  |  | `CTLD_CARGO` |
| `:IsAirdrome` | 25 | 23 |  |  |  | 2 |  |  | `AIRBASE` |
| `:Translate` | 25 | 24 |  | 1 |  |  |  |  | `COORDINATE`, `VECTOR` |
| `:GetPlayerName` | 24 | 1 |  | 13 | 5 | 5 |  |  | `FLIGHTGROUP`, `GROUP`, `UNIT` |
| `:I` | 23 |  |  | 13 | 10 |  |  |  | `BASE` |
| `:Stop` | 23 | 17 |  | 2 |  | 4 |  |  | `CTLD_ENGINEERING`, `PROFILER`, `RADIOQUEUE`, `RAT` et 5 autres |
| `:GetUnit` | 22 | 14 |  |  |  | 8 |  |  | `GROUP`, `OPSGROUP` |
| `:OnSpawnGroup` | 22 | 20 |  |  |  | 2 |  |  | `SPAWN` |
| `:GetTypeName` | 21 | 9 |  | 6 |  | 5 | 1 |  | `GROUP`, `IDENTIFIABLE`, `WEAPON` |
| `:GetUnits` | 21 | 11 |  | 8 | 1 | 1 |  |  | `GROUP`, `STATIC`, `UNIT` |
| `:AddCratesCargoNoMove` | 20 |  |  | 17 | 3 |  |  |  | `CTLD` |
| `:AddCratesCargo` | 19 |  |  | 9 | 10 |  |  |  | `CTLD` |
| `:GetAngleDegrees` | 17 | 17 |  |  |  |  |  |  | `COORDINATE` |
| `:GetDirectionVec3` | 17 | 17 |  |  |  |  |  |  | `COORDINATE` |
| `:GetGroup` | 17 | 6 |  | 2 |  | 7 | 2 |  | `OPSGROUP`, `UNIT` |
| `:GetItemAmount` | 17 | 13 |  | 4 |  |  |  |  | `STORAGE` |
| `:AddCTLDZone` | 16 | 2 |  | 12 | 2 |  |  |  | `CTLD` |
| `:OptionROEOpenFire` | 15 | 15 |  |  |  |  |  |  | `CONTROLLABLE` |
| `:SpawnFromCoordinate` | 15 | 13 |  |  |  | 2 |  |  | `SPAWN`, `SPAWNSTATIC` |
| `:TaskLandAtVec2` | 15 | 15 |  |  |  |  |  |  | `CONTROLLABLE` |
| `:FilterCoalitions` | 14 | 9 |  | 1 |  | 1 | 3 |  | `SET_BASE` |
| `:FilterOnce` | 14 | 7 |  | 1 |  | 2 | 4 |  | `SET_BASE`, `SET_OPSZONE`, `SET_SCENERY` |
| `:GetStock` | 14 |  |  | 10 | 4 |  |  |  | `CTLD_CARGO` |
| `:HasAttribute` | 14 | 14 |  |  |  |  |  |  | `GROUP`, `IDENTIFIABLE` |
| `:AddStockTroops` | 13 |  |  | 11 | 2 |  |  |  | `CTLD` |
| `:DeactivateZone` | 13 | 1 |  | 8 | 4 |  |  |  | `CTLD` |
| `:GetClosestAirbase` | 13 | 13 |  |  |  |  |  |  | `COORDINATE`, `FLIGHTGROUP` |
| `:Remove` | 13 | 5 |  |  |  | 8 |  |  | `FSM_PROCESS`, `MARKER`, `MENU_COALITION`, `MENU_COALITION_COMMAND` et 8 autres |
| `:Spawn` | 13 | 11 | 1 | 1 |  |  |  |  | `DATABASE`, `RAT`, `SPAWN`, `SPAWNSTATIC` |
| `:GetCratesNeeded` | 12 | 3 |  | 7 | 2 |  |  |  | `CTLD_CARGO`, `DYNAMICCARGO` |
| `:GetTemplate` | 12 | 9 |  | 3 |  |  |  |  | `GROUP`, `UNIT` |
| `:GetHeading` | 11 | 5 |  | 1 |  | 5 |  |  | `AIRBOSS`, `COORDINATE`, `GROUP`, `LINE` et 6 autres |
| `:GetPointVec3` | 11 | 6 |  |  |  | 5 |  |  | `POSITIONABLE`, `ZONE_BASE` |
| `:SpawnAtAirbase` | 11 | 11 |  |  |  |  |  |  | `SPAWN` |
| `:AddTroopsCargo` | 10 |  |  | 8 | 2 |  |  |  | `CTLD` |
| `:GetFreeParkingSpotsTable` | 10 | 8 |  |  |  | 2 |  |  | `AIRBASE` |
| `:InitCoalition` | 10 | 8 |  |  |  | 2 |  |  | `SPAWN` |
| `:IsShip` | 10 | 10 |  |  |  |  |  |  | `AIRBASE`, `GROUP`, `POSITIONABLE`, `STRATEGO` et 2 autres |
| `:IsVec3InZone` | 10 | 7 |  | 3 |  |  |  |  | `ZONE_BASE`, `ZONE_DETECTION`, `ZONE_POLYGON_BASE`, `ZONE_RADIUS` |
| `:FilterCategories` | 9 | 4 |  |  |  | 3 | 2 |  | `DETECTION_BASE`, `SET_AIRBASE`, `SET_CLIENT`, `SET_GROUP` et 4 autres |
| `:HandleEvent` | 9 | 3 |  |  |  | 4 | 2 |  | `BASE`, `GROUP`, `UNIT` |
| `:HeadingTo` | 9 | 5 |  | 2 |  | 2 |  |  | `COORDINATE` |
| `:IsUnitInZone` | 9 |  |  | 4 | 5 |  |  |  | `CTLD` |
| `:RouteStop` | 9 | 6 |  | 3 |  |  |  |  | `CONTROLLABLE` |
| `:SetAltitude` | 9 | 9 |  |  |  |  |  |  | `CONTROLLABLE`, `COORDINATE`, `OPSGROUP`, `RECOVERYTANKER` et 1 autres |
| `:ToUnit` | 9 | 3 |  |  |  | 6 |  |  | `MESSAGE`, `USERSOUND` |
| `:FilterActive` | 8 | 7 |  |  |  |  | 1 |  | `SET_CLIENT`, `SET_GROUP`, `SET_OPSGROUP`, `SET_UNIT` |
| `:FilterStart` | 8 | 7 |  | 1 |  |  |  |  | `SET_AIRBASE`, `SET_CLIENT`, `SET_DYNAMICCARGO`, `SET_GROUP` et 7 autres |
| `:ForEachClient` | 8 | 6 |  |  |  | 2 |  |  | `DATABASE`, `SET_CLIENT` |
| `:GetInventory` | 8 | 8 |  |  |  |  |  |  | `STORAGE` |
| `:InitSkill` | 8 | 8 |  |  |  |  |  |  | `SPAWN` |
| `:SetProperty` | 8 | 8 |  |  |  |  |  |  | `BASE`, `SCENERY` |
| `:TaskFunction` | 8 | 5 |  | 3 |  |  |  |  | `CONTROLLABLE` |
| `:ToStringMGRS` | 8 | 7 |  | 1 |  |  |  |  | `COORDINATE`, `VECTOR` |
| `:AddStockCrates` | 7 |  |  | 4 | 3 |  |  |  | `CTLD` |
| `:AddUnits` | 7 |  |  | 7 |  |  |  |  | `CTLD` |
| `:GetMagneticDeclination` | 7 | 4 |  |  |  | 3 |  |  | `COORDINATE`, `UTILS` |
| `:GetProperty` | 7 | 7 |  |  |  |  |  |  | `BASE`, `SCENERY`, `ZONE_BASE` |
| `:IsInZone` | 7 | 7 |  |  |  |  |  |  | `GROUP`, `OPSGROUP`, `POSITIONABLE`, `SET_BASE` |
| `:SetOption` | 7 | 7 |  |  |  |  |  |  | `CONTROLLABLE` |
| `:ActivateZone` | 6 |  |  | 4 | 2 |  |  |  | `CTLD` |
| `:AddMission` | 6 | 6 |  |  |  |  |  |  | `CHIEF`, `COMMANDER`, `LEGION`, `OPERATION` et 1 autres |
| `:Schedule` | 6 | 6 |  |  |  |  |  |  | `DETECTION_BASE`, `SCHEDULER` |
| `:SetOptionRadioSilence` | 6 | 6 |  |  |  |  |  |  | `CONTROLLABLE` |
| `:SpawnFromPointVec3` | 6 | 6 |  |  |  |  |  |  | `SPAWN` |
| `:StopTrack` | 6 | 6 |  |  |  |  |  |  | `WEAPON` |
| `:WaypointGround` | 6 |  |  | 6 |  |  |  |  | `COORDINATE` |
| `:AddItem` | 5 | 4 |  | 1 |  |  |  |  | `STORAGE` |
| `:EnRouteTaskEngageTargets` | 5 | 5 |  |  |  |  |  |  | `CONTROLLABLE` |
| `:FilterZones` | 5 | 4 |  | 1 |  |  |  |  | `SET_AIRBASE`, `SET_CLIENT`, `SET_DYNAMICCARGO`, `SET_GROUP` et 4 autres |
| `:ForEachGroup` | 5 | 5 |  |  |  |  |  |  | `DATABASE`, `SET_GROUP`, `SET_OPSGROUP` |
| `:GetCountry` | 5 |  |  | 2 |  | 3 |  |  | `FLIGHTCONTROL`, `GROUP`, `IDENTIFIABLE`, `WAREHOUSE` et 1 autres |
| `:InitHeading` | 5 | 4 |  |  |  | 1 |  |  | `GROUP`, `SPAWN`, `SPAWNSTATIC` |
| `:IsC130J` | 5 |  |  | 4 | 1 |  |  |  | `CTLD` |
| `:IsPartlyOrCompletelyInZone` | 5 |  |  | 5 |  |  |  |  | `GROUP` |
| `:RemoveGroupsByName` | 5 |  |  | 5 |  |  |  |  | `SET_GROUP`, `SET_OPSGROUP` |
| `:SpawnAtParkingSpot` | 5 | 4 |  |  |  | 1 |  |  | `SPAWN` |
| `:CommandSetUnlimitedFuel` | 4 | 3 |  |  |  | 1 |  |  | `CONTROLLABLE` |
| `:Count` | 4 | 4 |  |  |  |  |  |  | `FIFO`, `LIFO`, `SET_BASE` |
| `:FilterAlive` | 4 | 1 |  | 1 |  | 2 |  |  | `SET_CLIENT`, `SET_GROUP`, `SET_UNIT` |
| `:GetCarrierGroupName` | 4 |  |  | 2 | 2 |  |  |  | `DYNAMICCARGO` |
| `:GetClientGroupID` | 4 | 4 |  |  |  |  |  |  | `CLIENT` |
| `:GetLandHeight` | 4 | 3 |  |  |  |  |  | 1 | `COORDINATE` |
| `:GetSetNames` | 4 |  |  |  |  |  | 4 |  | `SET_BASE` |
| `:GetSize` | 4 | 4 |  |  |  |  |  |  | `FIFO`, `GROUP`, `LIFO`, `POSITIONABLE` |
| `:InAir` | 4 | 2 |  |  |  | 2 |  |  | `GROUP`, `POSITIONABLE`, `UNIT`, `WEAPON` |
| `:InitCountry` | 4 | 2 |  |  |  | 2 |  |  | `SPAWN`, `SPAWNSTATIC` |
| `:OptionPreferVerticalLanding` | 4 | 4 |  |  |  |  |  |  | `CONTROLLABLE` |
| `:OptionROEReturnFire` | 4 | 4 |  |  |  |  |  |  | `CONTROLLABLE` |
| `:OptionROTEvadeFire` | 4 | 4 |  |  |  |  |  |  | `CONTROLLABLE` |
| `:RouteGroundTo` | 4 | 2 |  | 2 |  |  |  |  | `CONTROLLABLE` |
| `:SetLiquid` | 4 |  |  | 4 |  |  |  |  | `STORAGE` |
| `:SetMissionSpeed` | 4 | 4 |  |  |  |  |  |  | `AUFTRAG` |
| `:SmokeZoneNearBy` | 4 | 4 |  |  |  |  |  |  | `CTLD` |
| `:Trigger` | 4 | 3 |  | 1 |  |  |  |  | `SET_ZONE`, `ZONE_BASE` |
| `:UnHandleEvent` | 4 | 3 |  |  |  |  | 1 |  | `BASE`, `GROUP`, `UNIT` |
| `:WasDropped` | 4 |  |  | 3 | 1 |  |  |  | `CTLD_CARGO`, `DYNAMICCARGO` |
| `:AddStaticsCargoFromType` | 3 |  |  | 1 | 2 |  |  |  | `CTLD` |
| `:CommandDoScript` | 3 | 3 |  |  |  |  |  |  | `CONTROLLABLE` |
| `:DeleteZone` | 3 | 3 |  |  |  |  |  |  | `DATABASE` |
| `:Despawn` | 3 | 3 |  |  |  |  |  |  | `OPSGROUP` |
| `:FilterFunction` | 3 | 2 |  | 1 |  |  |  |  | `SET_BASE` |
| `:FilterPrefixes` | 3 | 3 |  |  |  |  |  |  | `SET_CLIENT`, `SET_DYNAMICCARGO`, `SET_GROUP`, `SET_OPSGROUP` et 7 autres |
| `:GetAirbaseCategory` | 3 | 3 |  |  |  |  |  |  | `AIRBASE`, `WAREHOUSE` |
| `:GetCargoDisplayName` | 3 |  |  | 1 | 2 |  |  |  | `DYNAMICCARGO` |
| `:GetCoord` | 3 |  |  | 3 |  |  |  |  | `AIRBOSS`, `POSITIONABLE` |
| `:GetImpactVec3` | 3 | 3 |  |  |  |  |  |  | `WEAPON` |
| `:GetPointVec2` | 3 |  |  |  |  | 3 |  |  | `GROUP`, `POSITIONABLE`, `ZONE_BASE` |
| `:GetRandomCoordinate` | 3 | 3 |  |  |  |  |  |  | `LINE`, `OPSZONE`, `ZONE_POLYGON_BASE`, `ZONE_RADIUS` |
| `:GetRunways` | 3 | 2 |  |  |  | 1 |  |  | `AIRBASE` |
| `:GetStock0` | 3 |  |  | 1 | 2 |  |  |  | `CTLD_CARGO` |
| `:GetStorage` | 3 | 3 |  |  |  |  |  |  | `AIRBASE` |
| `:GetType` | 3 |  |  | 3 |  |  |  |  | `AUFTRAG`, `CTLD_CARGO`, `DYNAMICCARGO` |
| `:InitGrouping` | 3 | 1 |  |  |  | 2 |  |  | `SPAWN` |
| `:IsBomb` | 3 | 3 |  |  |  |  |  |  | `WEAPON` |
| `:OptionAlarmStateGreen` | 3 | 2 | 1 |  |  |  |  |  | `CONTROLLABLE` |
| `:OptionROEOpenFireWeaponFree` | 3 | 3 |  |  |  |  |  |  | `CONTROLLABLE` |
| `:ReSpawn` | 3 | 2 |  |  |  | 1 |  |  | `SPAWN`, `STATIC` |
| `:SearchZone` | 3 |  |  |  |  |  |  | 3 | `ZONE_RADIUS` |
| `:SetDetectInterval` | 3 | 3 |  |  |  |  |  |  | `MANTIS` |
| `:SetDistanceInterceptPoint` | 3 | 3 |  |  |  |  |  |  | `WEAPON` |
| `:SetFuncImpact` | 3 | 3 |  |  |  |  |  |  | `WEAPON` |
| `:SetMissionAltitude` | 3 | 3 |  |  |  |  |  |  | `AUFTRAG` |
| `:SetUnitCapabilities` | 3 |  |  | 1 | 2 |  |  |  | `CTLD` |
| `:SetWeaponType` | 3 | 3 |  |  |  |  |  |  | `AUFTRAG` |
| `:SpawnFromVec2` | 3 | 2 |  |  |  |  |  | 1 | `SPAWN` |
| `:StartTrack` | 3 | 3 |  |  |  |  |  |  | `WEAPON` |
| `:TaskWrappedAction` | 3 | 3 |  |  |  |  |  |  | `CONTROLLABLE` |
| `:AddGroup` | 2 |  |  | 1 | 1 |  |  |  | `DATABASE`, `SET_GROUP`, `SET_OPSGROUP` |
| `:AddScootZones` | 2 | 2 |  |  |  |  |  |  | `MANTIS`, `SHORAD` |
| `:AddWeaponRange` | 2 | 2 |  |  |  |  |  |  | `COHORT`, `OPSGROUP` |
| `:CountAliveUnits` | 2 | 1 | 1 |  |  |  |  |  | `GROUP` |
| `:EnableEmission` | 2 | 2 |  |  |  |  |  |  | `GROUP`, `UNIT` |
| `:FilterHasSEAD` | 2 |  |  |  |  |  | 2 |  | `SET_UNIT` |
| `:GetActiveRunway` | 2 | 1 |  |  |  | 1 |  |  | `AIRBASE`, `ATIS`, `FLIGHTCONTROL` |
| `:GetDesc` | 2 | 1 |  |  |  | 1 |  |  | `IDENTIFIABLE` |
| `:GetFuel` | 2 |  |  |  |  | 2 |  |  | `CONTROLLABLE`, `GROUP`, `UNIT` |
| `:GetParkingSpotsTable` | 2 | 2 |  |  |  |  |  |  | `AIRBASE` |
| `:GetRunwayName` | 2 | 1 |  |  |  | 1 |  |  | `AIRBASE` |
| `:GetSet` | 2 |  |  | 2 |  |  |  |  | `SET_BASE` |
| `:GetSurfaceType` | 2 | 2 |  |  |  |  |  |  | `COORDINATE`, `VECTOR`, `ZONE_BASE` |
| `:GetTemplates` | 2 |  |  | 2 |  |  |  |  | `CTLD_CARGO` |
| `:GetUnitCategory` | 2 |  |  |  |  | 2 |  |  | `UNIT` |
| `:GetWind` | 2 |  |  |  |  | 2 |  |  | `AIRBOSS`, `COORDINATE`, `NAVYGROUP` |
| `:GetZone` | 2 |  |  | 2 |  |  |  |  | `AIRBASE`, `OPSZONE`, `ZONE_GOAL` |
| `:HasMoved` | 2 |  |  | 1 | 1 |  |  |  | `CTLD_CARGO` |
| `:InitDelayOff` | 2 | 2 |  |  |  |  |  |  | `SPAWN` |
| `:InitGroupHeading` | 2 | 2 |  |  |  |  |  |  | `SPAWN` |
| `:InitHiddenOnMap` | 2 | 2 |  |  |  |  |  |  | `SPAWN`, `SPAWNSTATIC` |
| `:InitValidateAndRepositionGroundUnits` | 2 | 2 |  |  |  |  |  |  | `SPAWN` |
| `:IsAttached` | 2 |  |  | 1 | 1 |  |  |  | `DYNAMICCARGO` |
| `:IsHelipad` | 2 | 2 |  |  |  |  |  |  | `AIRBASE` |
| `:IsLoaded` | 2 |  |  | 1 | 1 |  |  |  | `DYNAMICCARGO`, `OPSGROUP`, `WAREHOUSE` |
| `:OnBeforeTemplateSpawnGroup` | 2 |  | 2 |  |  |  |  |  | `SPAWN` |
| `:OptionAlarmStateRed` | 2 | 2 |  |  |  |  |  |  | `CONTROLLABLE` |
| `:RouteResume` | 2 | 1 |  | 1 |  |  |  |  | `CONTROLLABLE` |
| `:RouteToVec2` | 2 | 2 |  |  |  |  |  |  | `CONTROLLABLE` |
| `:ScheduleOnce` | 2 | 2 |  |  |  |  |  |  | `BASE` |
| `:SetAIOn` | 2 | 2 |  |  |  |  |  |  | `GROUP`, `UNIT` |
| `:SetAccousticDetectionOn` | 2 | 2 |  |  |  |  |  |  | `INTEL`, `MANTIS` |
| `:SetEngageAsGroup` | 2 | 2 |  |  |  |  |  |  | `AUFTRAG` |
| `:SetGroupLocaleResolver` | 2 |  |  | 1 | 1 |  |  |  | `CTLD` |
| `:SetMaxActiveSAMs` | 2 | 2 |  |  |  |  |  |  | `MANTIS` |
| `:SetOptionRadarUsing` | 2 | 2 |  |  |  |  |  |  | `CONTROLLABLE` |
| `:SetOptionRadarUsingForContinousSearch` | 2 | 1 |  |  |  | 1 |  |  | `CONTROLLABLE` |
| `:SetWeaponExpend` | 2 | 2 |  |  |  |  |  |  | `AUFTRAG` |
| `:SmokeRed` | 2 |  |  |  |  |  |  | 2 | `COORDINATE`, `POSITIONABLE` |
| `:SpawnFromPointVec2` | 2 | 2 |  |  |  |  |  |  | `SPAWN`, `SPAWNSTATIC` |
| `:Text` | 2 | 1 |  |  |  | 1 |  |  | `REPORT` |
| `:ToGroup` | 2 |  |  | 1 |  | 1 |  |  | `MARKER`, `MESSAGE`, `USERSOUND` |
| `:UndrawZone` | 2 | 2 |  |  |  |  |  |  | `ZONE_BASE`, `ZONE_OVAL` |
| `:UnitCanCarry` | 2 | 2 |  |  |  |  |  |  | `CTLD_CARGO` |
| `:UpdateFromVec2` | 2 |  |  | 2 |  |  |  |  | `COORDINATE`, `ZONE_POLYGON_BASE`, `ZONE_RADIUS` |
| `:UpdateFromVec3` | 2 |  |  | 2 |  |  |  |  | `COORDINATE`, `ZONE_POLYGON_BASE`, `ZONE_RADIUS` |
| `:AddStockUnits` | 1 |  |  | 1 |  |  |  |  | `CTLD` |
| `:AddStorage` | 1 | 1 |  |  |  |  |  |  | `DATABASE` |
| `:AddZone` | 1 |  |  | 1 |  |  |  |  | `CTLD`, `DATABASE`, `SET_OPSZONE`, `SET_ZONE` et 1 autres |
| `:CommandEPLRS` | 1 | 1 |  |  |  |  |  |  | `CONTROLLABLE` |
| `:CountRemainingMissison` | 1 | 1 |  |  |  |  |  |  | `OPSGROUP` |
| `:CreateGrid` | 1 | 1 |  |  |  |  |  |  | `ASTAR` |
| `:DrawZone` | 1 | 1 |  |  |  |  |  |  | `SET_ZONE`, `ZONE_OVAL`, `ZONE_POLYGON_BASE`, `ZONE_RADIUS` |
| `:Explosion` | 1 |  |  |  |  |  |  | 1 | `COORDINATE`, `VECTOR` |
| `:FilterStop` | 1 | 1 |  |  |  |  |  |  | `SET_BASE`, `SET_CLIENT`, `SET_DYNAMICCARGO`, `SET_GROUP` et 4 autres |
| `:FilterTypes` | 1 |  |  |  |  |  | 1 |  | `SET_CLIENT`, `SET_DYNAMICCARGO`, `SET_PLAYER`, `SET_STATIC` et 1 autres |
| `:FindFreeParkingSpotForAircraft` | 1 | 1 |  |  |  |  |  |  | `AIRBASE` |
| `:Get3DDistance` | 1 |  |  | 1 |  |  |  |  | `COORDINATE` |
| `:GetActiveRunwayTakeoff` | 1 | 1 |  |  |  |  |  |  | `AIRBASE`, `FLIGHTCONTROL` |
| `:GetAliveSet` | 1 |  |  | 1 |  |  |  |  | `SET_BASE`, `SET_CLIENT`, `SET_GROUP`, `SET_OPSGROUP` et 2 autres |
| `:GetAmmunition` | 1 |  | 1 |  |  |  |  |  | `GROUP`, `UNIT` |
| `:GetCategory` | 1 | 1 |  |  |  |  |  |  | `AIRBASE`, `COHORT`, `GROUP`, `IDENTIFIABLE` et 1 autres |
| `:GetGenericCargoObjectFromGroupName` | 1 |  |  | 1 |  |  |  |  | `CTLD` |
| `:GetGroupTemplate` | 1 | 1 |  |  |  |  |  |  | `DATABASE` |
| `:GetLLDDM` | 1 |  |  | 1 |  |  |  |  | `COORDINATE` |
| `:GetMass` | 1 |  |  |  | 1 |  |  |  | `CTLD_CARGO` |
| `:GetMissionCurrent` | 1 | 1 |  |  |  |  |  |  | `OPSGROUP` |
| `:GetPath` | 1 | 1 |  |  |  |  |  |  | `ASTAR`, `CLIENTMENU`, `MSRS`, `SOUNDFILE` |
| `:GetPlayerUnits` | 1 |  |  |  |  | 1 |  |  | `DATABASE`, `GROUP` |
| `:GetPressure` | 1 |  |  |  |  | 1 |  |  | `COORDINATE` |
| `:GetRelativeLife` | 1 | 1 |  |  |  |  |  |  | `SCENERY`, `SET_SCENERY` |
| `:GetRunwayIntoWind` | 1 | 1 |  |  |  |  |  |  | `AIRBASE` |
| `:GetTemperature` | 1 |  |  |  |  | 1 |  |  | `COORDINATE` |
| `:HasSEAD` | 1 | 1 |  |  |  |  |  |  | `SET_UNIT`, `UNIT` |
| `:IlluminationBomb` | 1 |  |  |  |  |  |  | 1 | `COORDINATE`, `VECTOR` |
| `:InitCargo` | 1 | 1 |  |  |  |  |  |  | `SPAWNSTATIC` |
| `:InitCargoMass` | 1 | 1 |  |  |  |  |  |  | `SPAWNSTATIC` |
| `:InitCoordinate` | 1 | 1 |  |  |  |  |  |  | `GROUP`, `SPAWNSTATIC` |
| `:InitRadioCommsOnOff` | 1 | 1 |  |  |  |  |  |  | `GROUP`, `SPAWN` |
| `:InitRandomizePosition` | 1 | 1 |  |  |  |  |  |  | `SPAWN` |
| `:InitRandomizeTemplate` | 1 |  | 1 |  |  |  |  |  | `SPAWN` |
| `:InitRandomizeUnits` | 1 | 1 |  |  |  |  |  |  | `SPAWN` |
| `:InitSetUnitRelativePositions` | 1 | 1 |  |  |  |  |  |  | `SPAWN` |
| `:InitSpeedMps` | 1 |  | 1 |  |  |  |  |  | `SPAWN` |
| `:IsAirborne` | 1 |  |  |  |  | 1 |  |  | `FLIGHTGROUP`, `GROUP` |
| `:IsAnyInZone` | 1 |  |  | 1 |  |  |  |  | `GROUP` |
| `:IsRepair` | 1 |  |  | 1 |  |  |  |  | `CTLD_CARGO` |
| `:IsStatic` | 1 |  |  | 1 |  |  |  |  | `CTLD_CARGO`, `WAREHOUSE` |
| `:IsUnlimited` | 1 | 1 |  |  |  |  |  |  | `STORAGE` |
| `:Isloaded` | 1 |  |  |  | 1 |  |  |  | `CTLD_CARGO` |
| `:OptionROEHoldFire` | 1 |  | 1 |  |  |  |  |  | `CONTROLLABLE` |
| `:OptionROT` | 1 |  |  |  |  | 1 |  |  | `CONTROLLABLE` |
| `:OptionRTBAmmo` | 1 | 1 |  |  |  |  |  |  | `CONTROLLABLE` |
| `:ReadOnly` | 1 | 1 |  |  |  |  |  |  | `MARKER` |
| `:RemoveItem` | 1 | 1 |  |  |  |  |  |  | `STORAGE` |
| `:RemoveJunk` | 1 |  | 1 |  |  |  |  |  | `ZONE_POLYGON_BASE`, `ZONE_RADIUS` |
| `:RemoveStockCrates` | 1 |  |  | 1 |  |  |  |  | `CTLD` |
| `:Respawn` | 1 | 1 |  |  |  |  |  |  | `GROUP` |
| `:RoutePush` | 1 | 1 |  |  |  |  |  |  | `CONTROLLABLE` |
| `:SetA2A_BULLS` | 1 |  |  |  |  | 1 |  |  | `SETTINGS` |
| `:SetA2G_BR` | 1 |  |  |  |  | 1 |  |  | `SETTINGS` |
| `:SetCoalition` | 1 | 1 |  |  |  |  |  |  | `AIRBASE`, `MSRS`, `PLAYERTASK`, `RAT` et 1 autres |
| `:SetDefaultFormation` | 1 | 1 |  |  |  |  |  |  | `OPSGROUP` |
| `:SetDetection` | 1 | 1 |  |  |  |  |  |  | `ESCORT`, `OPSGROUP` |
| `:SetEndCoordinate` | 1 | 1 |  |  |  |  |  |  | `ASTAR` |
| `:SetEngageDetectedOn` | 1 | 1 |  |  |  |  |  |  | `OPSGROUP` |
| `:SetHomebase` | 1 | 1 |  |  |  |  |  |  | `FLIGHTGROUP` |
| `:SetImperial` | 1 |  |  |  |  | 1 |  |  | `SETTINGS` |
| `:SetMissionIngressCoord` | 1 | 1 |  |  |  |  |  |  | `AUFTRAG` |
| `:SetOptionWaypointPassReport` | 1 |  |  |  |  | 1 |  |  | `CONTROLLABLE` |
| `:SetPartlyInside` | 1 | 1 |  |  |  |  |  |  | `SET_ZONE`, `ZONE_BASE` |
| `:SetPlayerMenuOff` | 1 |  |  |  |  | 1 |  |  | `SETTINGS` |
| `:SetRadarBlur` | 1 | 1 |  |  |  |  |  |  | `AWACS`, `DETECTION_BASE`, `INTEL` |
| `:SetStartCoordinate` | 1 | 1 |  |  |  |  |  |  | `ASTAR` |
| `:SetTask` | 1 |  | 1 |  |  |  |  |  | `CONTROLLABLE`, `FSM_PROCESS`, `OPSGROUP` |
| `:SetValidNeighbourLoS` | 1 | 1 |  |  |  |  |  |  | `ASTAR` |
| `:SetVerbosity` | 1 | 1 |  |  |  |  |  |  | `AUFTRAG`, `COHORT`, `COMMANDER`, `FLIGHTCONTROL` et 9 autres |
| `:SmokeBlue` | 1 |  |  |  |  |  |  | 1 | `COORDINATE`, `POSITIONABLE` |
| `:SmokeGreen` | 1 |  |  |  |  |  |  | 1 | `COORDINATE`, `POSITIONABLE` |
| `:SmokeOrange` | 1 |  |  |  |  |  |  | 1 | `COORDINATE`, `POSITIONABLE` |
| `:SmokeWhite` | 1 |  |  |  |  |  |  | 1 | `COORDINATE`, `POSITIONABLE` |
| `:SpawnFromVec3` | 1 |  | 1 |  |  |  |  |  | `SPAWN` |
| `:SwitchROE` | 1 | 1 |  |  |  |  |  |  | `OPSGROUP` |
| `:TaskOrbit` | 1 |  | 1 |  |  |  |  |  | `CONTROLLABLE` |
| `:TaskRoute` | 1 |  |  |  |  | 1 |  |  | `CONTROLLABLE` |
| `:ToClient` | 1 | 1 |  |  |  |  |  |  | `MESSAGE`, `USERSOUND` |
| `:ToCoalition` | 1 | 1 |  |  |  |  |  |  | `MARKER`, `MESSAGE`, `USERSOUND` |
| `:ToStringLLDDM` | 1 | 1 |  |  |  |  |  |  | `COORDINATE` |
| `:ToStringLLDMS` | 1 | 1 |  |  |  |  |  |  | `COORDINATE` |
| `:UpdateCoordinate` | 1 | 1 |  |  |  |  |  |  | `MARKER` |
| `:UpdateText` | 1 | 1 |  |  |  |  |  |  | `MARKER` |
| `:WaypointAirFlyOverPoint` | 1 | 1 |  |  |  |  |  |  | `COORDINATE` |
