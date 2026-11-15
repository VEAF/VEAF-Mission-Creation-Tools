# 07 — CTLD et logistique d'entrepôt (Foothold v6.5.3)

Source : tag amont v6.5.3, commit 27d8cf4a.
Noms courts de fichiers utilisés dans les citations : `CTLD.lua` = `Common Scripts/Foothold CTLD.lua`, `CTLD_Red.lua` = `Common Scripts/Foothold_CTLD_Red.lua`, `zc2` = `Common Scripts/zoneCommanderv2.lua`, `Moose` = `Common Scripts/Moose_2026-10-11.lua`, `Config` = `Common Scripts/Foothold Config.lua`, `L10N` = `Common Scripts/Foothold_Localization.lua`, `Setup` = `Setup files/MA_Setup_CAv2.lua`.

La classe `CTLD` de Moose embarquée est en version 1.4.45 (`Moose:76160`).
Ce n'est pas une classe standard utilisée telle quelle : elle contient déjà des hooks qui n'existent que pour Foothold (par exemple `self._updateManagedWarehouseDynamicCargo`, appelée depuis le gestionnaire d'événements de Moose, `Moose:77313`, `Moose:77346`, fonction définie dans `CTLD.lua:6603`).
Dans ce document, « Moose » signifie « implémenté dans la classe `CTLD` de Moose embarquée », « Foothold » signifie « implémenté dans `Foothold CTLD.lua` / le moteur ».

## Liste des fonctionnalités

| # | Fonctionnalité | Description en une ligne | Principal emplacement dans le code |
|---|---|---|---|
| 1 | Instance CTLD et avions de transport | Un CTLD Moose par coalition, filtre par préfixe de groupe, capacités par cellule | `CTLD.lua:104-176`, `CTLD.lua:453-476` |
| 2 | Catalogue de cargaison | Troupes, véhicules et SAM construits à partir de caisses, véhicules entiers du C-130J, caisses de supply statiques, par époque | `CTLD.lua:264-367` |
| 3 | Prix, rang, disponibilité | Prix en crédits et rang minimum par objet, masquage des objets indisponibles | `CTLD.lua:182-257`, `CTLD.lua:373-388` |
| 4 | Zones qui suivent la propriété | Zone amie = zone de ramassage, autres zones = cibles de déplacement, navires, FARP | `CTLD.lua:483-542` |
| 5 | Flux chargement/déchargement/construction et veto de paiement | Débit avant le spawn, remboursement des troupes ramenées, extraits vocaux | `CTLD.lua:6636-6675`, `Moose:78256-78283` |
| 6 | Stock et limites | Stock fini, plus ancien groupe retiré au-delà de 5, réapprovisionnement toutes les 60 s, plafonds de restauration | `CTLD.lua:408-450`, `CTLD.lua:6087-6117`, `CTLD.lua:9331-9415` |
| 7 | Troupes → capture / renfort / retour | Les troupes déposées capturent les zones neutres, approvisionnent les zones amies, ou sont remboursées | `CTLD.lua:8286-9327` |
| 8 | Zone supplies | Caisses de supply physiques suivies du ramassage à la livraison ; capture ou approvisionnement d'une zone | `CTLD.lua:3044-5476`, `CTLD.lua:6733-6782` |
| 9 | Cargaison d'entrepôt | Lots qui déplacent du stock d'armement entre les entrepôts des aérodromes | `CTLD.lua:1309-1354`, `CTLD.lua:6300-6634`, `CTLD.lua:6785-6959` |
| 10 | Zone Spy et Demolition Team | Équipes spéciales IA : intel d'une heure sur une zone, charges temporisées sur les structures d'une zone | `CTLD.lua:1531-2589` |
| 11 | Extensions SAM et fusion | Caisses de lanceur/radar supplémentaires fusionnées dans un site HAWK/NASAMS/IRIS-T proche | `CTLD.lua:556-1281`, `CTLD.lua:7847-8095` |
| 12 | Règle d'espacement des SAM (PvP) | 8 NM entre deux SAM protégés du même type construits | `CTLD.lua:2778-2900` |
| 13 | Chargement C-130J, largage, construction automatique | Les ensembles de caisses largués se construisent seuls via un soldat auxiliaire caché | `CTLD.lua:2595-2775`, `CTLD.lua:3455-3759` |
| 14 | FARP et FARP avec kits ZELL | FARP invisible construit par un joueur, avec entrepôt, compteur de supply, lanceur ZELL optionnel | `CTLD.lua:5525-5925` |
| 15 | Récompenses, crédit de kill, hooks de carrière | Récompenses de construction, kills par des unités construites par des joueurs, statistiques de carrière | `CTLD.lua:5930-6298`, `zc2:42827-42845` |
| 16 | Persistance | CSV Moose pour les unités/troupes, CSV propre pour les FARP, élagage par distance et plafonds | `CTLD.lua:7609-8284` |
| 17 | Système de logistique d'entrepôt | Stocks d'armement finis par aérodrome, catalogue, réapprovisionnements, politique d'emplacement, listes d'avions | `zc2:51006-51340`, `zc2:112318-115262`, `zc2:20074-20244` |
| 18 | Logistique héritée LogisticCommander | Menu virtuel « load supplies » (mode hérité), propriétaire des menus, avertissement au décollage | `zc2:97554-98443`, `zc2:101336-101791` |
| 19 | Arborescence du menu F10 | Logistics → Zone supplies / Warehouse / Mark Zone / CTLD … | `zc2:101557-101781`, `Moose:80721-81133` |
| 20 | HercCargoDropSupply | Caisse générique du mod Hercules larguée au-dessus d'une zone = livraison de supply | `zc2:102295-102457` |
| 21 | ExternalHeloCargoRoute | Constructeurs de tâches de cargaison sous élingue réservés à l'IA (le joueur voit un hélico IA avec une caisse) | `zc2:58056-58240` |
| 22 | CTLD Rouge | Seconde instance CTLD pour RED (option PvE ou PvP) | `CTLD_Red.lua:1-2417` |
| 23 | Paramètres de configuration | Tableau récapitulatif des paramètres CTLD et logistique | `Config:1273-1434`, `Config:1955-2176` |
| 24 | Dispositifs de performance | Limiteurs, files d'attente, caches, dormance | voir §24 |
| 25 | Fonctionnalités du CTLD Moose de base utilisées | Liste neutre pour comparaison avec un autre CTLD | voir §25 |
| 26 | Économie du « regular supply » des zones | Production de supply prêt, stock, permis d'envoi IA, chantiers locaux de réparation/construction, délais | `zc2:52059-55000`, `zc2:8480-8504` |
| 27 | Bâtiment d'entrepôt destructible | Static `[WH]` d'un centre logistique : implantation, effets de la destruction, réparation en 30 min, objets de la boutique | `zc2:46108-46580`, `zc2:24155-24253` |
| 28 | `TheaterInfrastructure` | Un bâtiment de la carte détruit coupe définitivement une route de supply RED | `Setup:2271-2360`, `zc2:53810-53861` |
| 29 | Industrie PvP et territoire de départ | Cœurs industriels, coupure du revenu, mission de frappe industrielle, part du territoire de départ | `zc2:55109-55159`, `zc2:102566-102742`, `Setup:5876-5908` |
| 30 | Supply et réparation par train (Normandie) | Trains créés sur la carte qui capturent/approvisionnent à l'arrivée, trains et gares destructibles, réparation via la boutique | `zc2:38128-38597`, `Normandy_Zone_Setup.lua:1115-1168`, `:4492-5022` |

## 1. Instance CTLD, options et avions de transport

### Ce que voit le joueur

Les joueurs aux commandes d'un avion capable de transport disposent d'un menu F10 `CTLD` (construit par `CTLD:_RefreshF10Menus` de Moose, `Moose:80721`).
Les portes doivent être ouvertes pour charger ou décharger (`pilotmustopendoors = true`, `CTLD.lua:158`).
Les caisses peuvent être déposées n'importe où (`dropcratesanywhere = true`, `CTLD.lua:142`), le chargement en vol stationnaire n'est pas imposé et le chargement automatique en vol stationnaire est désactivé (`CTLD.lua:143`, `CTLD.lua:155`), le sling load est activé (`CTLD.lua:156`).
La construction prend 30 s (`buildtime = 30`, `CTLD.lua:159`).
Les transports à voilure fixe peuvent larguer par parachute au-dessus de 100 m AGL et en dessous de 200 (unité telle qu'utilisée par Moose) de vitesse (`CTLD.lua:149-151`).

### Ce que règle le créateur de mission

Une instance Moose est créée pour BLUE : `Foothold_ctld = CTLD:New(coalition.side.BLUE, {prefix list}, "Lufttransportbrigade I")` (`CTLD.lua:104`).
Le deuxième argument est une liste de **préfixes de noms de groupe** (patterns Lua) : `CH.47`, `Ka.50.III`, `SA342L`, `UH.1H`, `Hercules`, `Mi.8MT`, `Ми.8МТВ2`, `Ми.24П`, `Bronco.OV`, `UH.60L`, `Mi.24P`, `OH.58D`, `KA.50`, `AH.64D`, `UH.60.DAP`, `C.130J.30`, `MH.60R` (`CTLD.lua:104`).
Un slot client n'obtient CTLD que si le nom de son groupe commence par l'un de ces préfixes : Moose construit `SET_GROUP:New():FilterCoalitions():FilterPrefixes(prefix):FilterStart()` (`Moose:83545-83551`).
Les capacités par cellule sont une table globale `CTLDUnitCapabilities` (surchargeable avant le chargement du script) : `{canCrates, canTroops, crateLimit, troopLimit, length, maxCargoMassKg}` appliquée avec `CTLD:SetUnitCapabilities` (`CTLD.lua:453-476`).

| Type | caisses | troupes | limite de caisses | limite de troupes | masse de cargaison (kg) |
|---|---|---|---|---|---|
| SA342L | non | oui | 1 | 2 | 400 |
| SA342M / Mistral / Minigun | non | oui | 0 | 2 | 400 |
| UH-1H | oui | oui | 1 | 8 | 800 |
| Mi-8MT | oui | oui | 3 | 16 | 6000 |
| Mi-8MTV2 | oui | oui | 3 | 18 | 6000 |
| Mi-24P / Mi-24V | oui | oui | 2 | 8 | 1000 |
| UH-60L / UH-60L_DAP | oui | oui | 2 | 20 | 3500 |
| CH-47Fbl1 | oui | oui | 5 | 32 | 10800 |
| Hercules (mod) | oui | oui | 8 | 20 | 20000 |
| C-130J-30 | oui | oui | 7 | 64 | 21500 |
| Ka-50, Ka-50_3, AH-64D_BLK_II, OH58D | non | non | 0 | 0 | 400 |

(`CTLD.lua:453-472`.)

Autres options d'instance réglées par Foothold (toutes sont des champs de `CTLD` de Moose) : `CrateDistance = 65`, `PackDistance = 120`, fenêtre de vol stationnaire de 3 à 20 m, `smokedistance = 8000`, `dropAsCargoCrate = true`, `nobuildinloadzones = true` (false en PvP), `movecratesbeforebuild = false`, `usesubcats = true`, `TroopUnloadDistGroundHook = 35`, `droppedbeacontimeout = 7200`, `movetroopsdistance = MaxTroopsRunDistanceTowardZone or 5000`, `onestepmenu = true`, `basetype = "uh1h_cargo"`, une liste de 5 formations de déplacement de véhicules, `returntroopstobase = false` (`CTLD.lua:142-171`).
`UseC130LoadAndUnload` (global de Config) est recopié sur l'instance (`CTLD.lua:168-170`).
`CaptureZoneWithEngineer` (Config, false par défaut) décide si l'unique « Engineer soldier » peut capturer ou améliorer une zone (`CTLD.lua:173-174`, `CTLD.lua:1283-1287`).
L'instance est démarrée avec `Foothold_ctld:__Start(1)` (`CTLD.lua:176`).

### Mécanisme

`CTLD:onafterStart` de Moose s'abonne à `EVENTS.PlayerEnterAircraft`, `PlayerEnterUnit`, `PlayerLeaveUnit`, `UnitLost`, `NewDynamicCargo`, `DynamicCargoLoaded`, `DynamicCargoUnloaded`, `DynamicCargoRemoved`, `Land`, `Takeoff` (`Moose:83555-83564`), c'est-à-dire aux événements DCS `S_EVENT_PLAYER_ENTER_UNIT`, `S_EVENT_PLAYER_LEAVE_UNIT`, `S_EVENT_UNIT_LOST`, aux quatre événements de cargaison dynamique, `S_EVENT_LAND`, `S_EVENT_TAKEOFF`, via `EVENT`/`world.addEventHandler` de Moose.
Moose fait tourner un tick de FSM de statut toutes les 30 s (`__Status(-30)`, `Moose:83639`) qui nettoie les troupes déposées mortes, rafraîchit les menus F10, vérifie les balises déposées, rafraîchit les balises radio, vérifie le chargement automatique en vol stationnaire et les ingénieurs (`Moose:83595-83603`).
Moose conserve un état par unité `Loaded_Cargo[unitName] = {Troopsloaded, Cratesloaded, Cargo = {CTLD_CARGO…}}`, vidé quand un joueur entre dans l'unité ou la quitte (`Moose:77273-77306`).
La localisation de chaque chaîne CTLD est redirigée vers la table propre à Foothold par `SetGroupLocaleResolver` (`CTLD.lua:133-135`) et par la table `CTLD_MENU_LABEL_KEYS` pour les libellés de menu (`CTLD.lua:50-99`).

### Notes de reproduction

Tout ce fichier repose sur la FSM `CTLD` de Moose (`OnAfterTroopsPickedUp`, `OnAfterTroopsDeployed`, `OnAfterGetCrates`, `OnAfterCratesPickedUp`, `OnAfterCratesBuild`, `OnAfterCratesBuildStarted`, `OnBeforeCratesPacked`, `OnAfterCratesPacked`, `OnAfterRemoveCratesNearby`, `OnAfterLoaded`) et sur cinq hooks de veto que Moose appelle avant d'agir et qui valent `return true` par défaut : `CanGetTroops`, `CanGetUnits`, `CanGetCrates`, `CanUnloadAllTroops`, `CanBuildCrates` (`Moose:77542`, `Moose:78104`, `Moose:78230`, `Moose:79313`, `Moose:79580`).
Foothold surcharge `CanGetTroops`, `CanGetUnits`, `CanGetCrates`, `_GetCrates` et (PvP) `CanBuildCrates`, `_CleanUpCrates`, `_BuildObjectFromCrates` (`CTLD.lua:6636`, `CTLD.lua:6654`, `CTLD.lua:6690`, `CTLD.lua:7346`, `CTLD.lua:2787-2896`).
Une réimplémentation a besoin d'un contrat équivalent « veto avant l'action / événement après l'action » autour de chacune des opérations charger, décharger, obtenir des caisses, construire, replier.

## 2. Catalogue de cargaison (troupes, caisses, unités à chargement direct, caisses de supply statiques)

### Ce que voit le joueur

Le catalogue apparaît sous forme de sous-menus par sous-catégorie parce que `usesubcats = true` (`CTLD.lua:157`) ; sous-catégories utilisées : `ANTI TANK`, `Support`, `SAM/AAA`, `SAM Addon`, `FARP`, `Zone supplies`, `Warehouse` (`CTLD.lua:280-366`).
Chaque objet a un prix en crédits et un rang minimum ; les deux sont des ajouts de Foothold (voir §3).

### Troupes (`AddTroopsCargo` de Moose, `CTLD.lua:264-277`)

| Nom | Groupe template | Type | Places | kg par homme | Stock | Disponibilité | Prix / rang par défaut |
|---|---|---|---|---|---|---|---|
| Squad 8 | `CTLD_TROOPS_ATS` | TROOPS | 8 | 80 | 10 | toujours | 50 / 1 |
| Platoon 16 | `CTLD_TROOPS_Platon16` | TROOPS | 16 | 80 | 10 | toujours | 100 / 1 |
| Platoon 32 | `CTLD_TROOPS_Platon1` | TROOPS | 32 | 80 | 10 | toujours | 200 / 1 |
| Mortar Squad | `CTLD_TROOPS_MRS` | TROOPS | 6 | 80 | 10 | toujours | 100 / 1 |
| Engineer soldier | `CTLD_TROOPS_Engineers` | ENGINEERS | 1 | 80 | 10 | toujours | 50 / 1 |
| Zone Spy | `CTLD_TROOPS_SPY` | TROOPS | 1 | 80 | 10 | pas en PvP | 100 / 2 |
| Demolition Team | `CTLD_TROOPS_DEMO` | TROOPS | 2 | 80 | 10 | pas en PvP, seulement si `UseStatics` | 100 / 2 |
| Anti-Air Soldiers | `CTLD_TROOPS_AA` | TROOPS | 5 | 80 | 10 | pas à l'époque Vietnam | 100 / 1 |

Prix et rangs : `CTLD.lua:206-242`.

### Objets construits à partir de caisses (`AddCratesCargo` / `AddCratesCargoNoMove` de Moose, `CTLD.lua:279-328`)

Les objets « NoMove » restent là où ils sont construits ; les autres roulent vers la zone MOVE la plus proche (`movetroopsdistance` de Moose).

| Nom | Template | Type d'enum | Caisses | kg par caisse | Stock | Sous-menu | Époque | Se déplace | Prix / rang |
|---|---|---|---|---|---|---|---|---|---|
| Mephisto | `CTLD_CARGO_Mephisto` | VEHICLE | 2 | 1500 | 10 | ANTI TANK | pas Vietnam | oui | 250 / 2 |
| Humvee | `CTLD_CARGO_HMMWV` | VEHICLE | 2 | 1000 | 10 | ANTI TANK | pas Vietnam | oui | 250 / 1 |
| Bradly | `CTLD_CARGO_Bradly` | VEHICLE | 2 | 1500 | 10 | ANTI TANK | pas Vietnam | oui | 250 / 1 |
| L118 | `CTLD_CARGO_L118` | VEHICLE | 1 | 700 | 12 | Support | toutes | non | 150 / 1 |
| Ammo Truck | `CTLD_CARGO_AmmoTruck` | VEHICLE | 2 | 800 | 10 | Support | toutes | non | 100 / 1 |
| Humvee scout | `CTLD_CARGO_Scout` | VEHICLE | 2 | 1000 | 10 | Support | toutes | oui | 100 / 1 |
| HAWK System | `CTLD_CARGO_HAWKSite` | FOB | 4 | 1900 | 10 | SAM/AAA | toutes | non | 750 / 3 |
| Hawk TR / SR / LN Add-on | `CTLD_CARGO_HAWKSite_TR/_SR/_LN` | FOB | 1 | 1500 | 10 / 15 / 10 | SAM Addon | toutes | non | 250 / 3 |
| NASAMS System | `CTLD_CARGO_NasamsSite` | FOB | 4 | 1900 | 10 | SAM/AAA | Moderne | non | 750 / 3 |
| NASAMS C2 / SR / LN Add-on | `CTLD_CARGO_NasamsSite_C2/_SR/_LN` | FOB | 1 | 1500 | 10 / 15 / 10 | SAM Addon | Moderne | non | 250 / 3 |
| IRIS T System | `CTLD_CARGO_IRISTSLM_System` | FOB | 3 | 2800 | 10 | SAM/AAA | Moderne | non | 1800 / 3 |
| IRIS T STR Add-on | `CTLD_CARGO_IRISTSLM_STR` | FOB | 1 | 2500 | 10 | SAM Addon | Moderne | non | 750 / 3 |
| IRIS T LN Add-on | `CTLD_CARGO_IRISTSLM-LN` | FOB | 1 | 3500 | 15 | SAM Addon | Moderne | non | 500 / 3 |
| IRIS T C2 Add-on | `CTLD_CARGO_IRISTSLM_C2` | FOB | 1 | 1900 | 10 | SAM Addon | Moderne | non | 500 / 3 |
| Pantsir S1 | `Blue SAM SHORAD Pantsir` | FOB | 2 | 3000 | 10 | SAM/AAA | Moderne + PvP + template présent | non | 500 / 2 |
| C-RAM | `CTLD_CARGO_CRAM` | FOB | 2 | 1000 | 10 | SAM/AAA | Moderne | non | 500 / 2 |
| HIMARS GMLRRS HE GUIDED | `CTLD_CARGO_GMLRS_HE` | VEHICLE | 2 | 3500 | 12 | Support | Moderne | non | 1000 / 3 |
| Linebacker | `CTLD_CARGO_Linebacker` | VEHICLE | 2 | 1500 | 10 | SAM/AAA | pas Vietnam | oui | 300 / 2 |
| Vulcan | `CTLD_CARGO_Vulcan` | VEHICLE | 2 | 1500 | 10 | SAM/AAA | pas Vietnam | oui | 300 / 2 |
| FARP Huey | `CTLD_TROOP_FOB` | FOB | 3 | 700 | 10 | FARP | toutes, UH-1H seulement | – | 500 / 1 (alias de FARP, `CTLD.lua:182-184`) |
| FARP | `CTLD_TROOP_FOB` | FOB | 3 | 1200 | 10 | FARP | toutes | – | 500 / 1 |
| FARP with ZELL | `CTLD_TROOP_FOB_ZELL` | FOB | 3 | 750 | 10 | FARP | seulement si ce template existe dans le `.miz` | – | 750 / 1 |

Plusieurs d'entre eux passent à Moose une forme statique de caisse (`"iso_container_small"`, `"cds_crate"`, `"ammo_cargo"`, `"iso_container"`) et une catégorie de carte de ressources `"Cargos"` (`CTLD.lua:284-327`).

### Véhicules entiers à chargement direct pour le C-130J (`AddUnits` de Moose, `CTLD.lua:315-323`)

`Humvee`, `Humvee scout` (toutes époques), et `Mephisto`, `Vulcan`, `Avenger`, `FV-107 Scimitar`, `FV-101 Scorpion` (pas Vietnam), chacun avec un stock de 10.
Moose les stocke dans `C130GetUnits` et les sert via `CTLD:_C130GetUnits(Group, Unit, Name)` depuis le menu `Manage Units → Get Units` (`Moose:78107-78229`) ; le côté Foothold se contente de les enregistrer et de leur fixer un prix (Avenger 250 / 2, Scimitar 250 / 2, Scorpion 250 / 2, `CTLD.lua:239-241`).
Ce que fait Moose en jeu : l'avion doit se trouver dans une zone LOAD et le stock ne doit pas être épuisé ; le hook de veto `CanGetUnits` est appelé (vérification des crédits et du rang par Foothold) ; au plus `maxUnitsNearby` (3 par défaut) de ces véhicules peuvent déjà se trouver à moins de `UnitDistance` (90 m par défaut) de l'avion, sinon `TOO_MANY_UNITS_NEARBY` ; ensuite chaque template de l'entrée est spawné comme un **groupe au sol vivant** derrière l'avion (cap + 180°, à la moitié de la longueur de la cellule + 5 m, 2,5 m plus loin par template) avec `SPAWN:NewWithAlias(template, "<template>-<random>"):InitRandomizeUnits(true, 10, 2):InitCoalition():SpawnFromVec2()` (→ `coalition.addGroup`), enregistré dans `DroppedTroops`, avec un événement FSM `UnitsSpawn`, le stock décrémenté et le message `DEPLOYED_NEAR_YOU` (`Moose:78123-78228`).
Il n'y a donc ni caisse ni construction : le véhicule existe tout de suite sur la rampe, et le faire entrer dans la soute est laissé au système de chargement de véhicules propre au module C-130J (le script ne fait rien de plus avec lui ; le chargement lui-même est un comportement de DCS, non lu dans le code — (estimation)).

### Caisses de supply statiques (`AddStaticsCargoFromType` de Moose, `CTLD.lua:330-367`)

Elles ne servent à construire rien : ce sont la « monnaie » des systèmes de zone supplies et de warehouse supplies (§8, §9).
Chacune est réservée à certaines cellules (argument `unitTypes`) et apparaît sous un seul nom d'affichage.

| Nom de cargaison | Type de static | kg | Sous-menu | Cellules |
|---|---|---|---|---|
| Zone supplies C-130J | `iso_container_small` | 4000 | Zone supplies | C-130J-30 |
| Zone supplies CH-47 | `cds_crate` | 3500 | Zone supplies | CH-47Fbl1 |
| Zone supplies UH-1H | `ammo_cargo` | 500 | Zone supplies | UH-1H |
| Zone supplies SA342L | `ammo_cargo` | 350 | Zone supplies | SA342L |
| Zone supplies MI-8 | `ammo_cargo` | 2300 | Zone supplies | Mi-8MT |
| Zone supplies Blackhawk | `ammo_cargo` | 2000 | Zone supplies | UH-60L, UH-60L_DAP |
| Zone supplies Mi-24P | `ammo_cargo` | 500 | Zone supplies | Mi-24P |
| 15 of everything CH-47 / MI-8 / Blackhawk | `cds_crate` / `cds_crate` / `ammo_cargo` | 3500 / 3500 / 2000 | Warehouse | CH-47 / Mi-8MT / UH-60L(+DAP) |
| 15 A/A Missiles, 15 A/G Missiles, 15 A/G Bombs | `ammo_cargo` | 1000 | Warehouse | CH-47, UH-1H, Mi-8MT, Mi-24P, UH-60L(+DAP) |
| 15 A/G Rockets, 15 (Plane fuel tanks) and pylons | `ammo_cargo` | 500 | Warehouse | mêmes hélicoptères |
| 25 of everything | `iso_container_small` | 4000 | Warehouse | C-130J-30 |
| 25 A/A Missiles, A/G Missiles, A/G Rockets, A/G Bombs, Plane fuel-tanks and pylons | `cds_crate` | 1000 | Warehouse | C-130J-30 |
| 50 of everything | `iso_container` | 8000 | Warehouse | C-130J-30 |
| 50 A/A Missiles, A/G Missiles, A/G Rockets, A/G Bombs, Plane fuel-tanks and pylons | `iso_container_small` | 2000 | Warehouse | C-130J-30 |
| 15 / 25 / 50 Modded weapons | `ammo_cargo` 500 / `cds_crate` 1000 / `iso_container_small` 2000 | – | Warehouse | hélicoptères / C-130J / C-130J, seulement si `AllowMods` et `Era == "Modern"` |

### Mécanisme

Tous les appels d'enregistrement sont du Moose (`AddTroopsCargo` `Moose:81932`, `AddUnits` `Moose:81956`, `AddCratesCargo` `Moose:81994`, `AddCratesCargoNoMove` `Moose:82024`, `AddStaticsCargoFromType` `Moose:82093`).
Les templates sont des groupes en late activation dans le `.miz` dont les noms sont donnés ci-dessus ; Moose les vérifie avec `_CheckTemplates` (`Moose:81917`).
La disponibilité est une couche Foothold : après l'enregistrement, chaque entrée du catalogue dont la politique dit `available = false` reçoit `DontShowInMenu = true`, et les entrées `C130GetUnits` indisponibles reçoivent une liste de cellules vide (`CTLD.lua:373-388`).
Le filtrage par époque est un simple `if Era ~= "Vietnam"` / `if Era == 'Modern'` autour des appels d'enregistrement (`CTLD.lua:275-323`).

### Notes de reproduction

Les noms de templates sont une convention de `.miz` : une mission sans groupes en late activation `CTLD_CARGO_*` / `CTLD_TROOPS_*` ne peut rien construire.
`FARP with ZELL` et `Pantsir S1` ne sont enregistrés que si leur template existe (`CTLD.lua:326`, `CTLD.lua:305`).

## 3. Prix, rang requis et politique de disponibilité

### Ce que règle le créateur de mission

`CTLDPrices` (global de Config) est une table `name → number` ou `name → {price=, reqRank=, available=}` ; elle est fusionnée par-dessus le `CTLDPriceDefaults` intégré (`CTLD.lua:206-255`).
`CTLD_DEFAULT_PRICE = 0` pour tout ce qui n'est pas listé (`CTLD.lua:257`), donc les caisses de supply statiques sont gratuites par défaut.
`FARP Huey` est tarifé comme `FARP` (`CTLD.lua:182-184`).

### Mécanisme

`Foothold_ctld:_readCargoPolicy(name)` renvoie `available, price, reqRank` (`CTLD.lua:186-193`) ; `priceOf` et `reqRankOf` sont des helpers globaux (`CTLD.lua:195-203`).
Les vérifications elles-mêmes vivent dans les surcharges de `CanGetTroops` / `CanGetCrates` / `CanGetUnits` (§6).

## 4. Zones de ramassage et de dépose qui suivent la propriété des zones

### Ce que voit le joueur

Les troupes et les caisses ne peuvent être demandées que dans une zone de campagne amie, sur un porte-avions/LHA, ou à un FARP construit par un joueur.
Les véhicules terrestres construits et les troupes déposées marchent vers la zone de campagne non amie la plus proche dans la limite de `movetroopsdistance` (5 km par défaut, `CTLD.lua:162`).

### Mécanisme

Au chargement, chaque zone de campagne dont le nom ne contient pas `hidden`, `carrier` ni `fob alpha` est enregistrée deux fois dans le CTLD de Moose, comme zone `LOAD` et comme zone `MOVE`, toutes deux inactives (`CTLD.lua:493-499`).
Des zones de navire (`CTLD.CargoZoneType.SHIP`, avec longueur/largeur du navire) sont ajoutées pour `Tarawa`, `Khasab Tarawa`, `HMS Invincible`, `CVN-72/73/74/59`, `FOB ALPHA` quand l'époque n'est pas Vietnam (`CTLD.lua:483-492`).
`addCTLDZonesForBlueControlled(zoneName)` règle, pour une zone ou pour toutes : zone inactive → les deux désactivées ; zone BLUE → `LOAD` activée, `MOVE` désactivée ; tout le reste (RED ou neutre) → `LOAD` désactivée, `MOVE` activée (`CTLD.lua:501-538`).
Elle est exécutée une fois 5 s après le chargement par un `SCHEDULER` de Moose (`CTLD.lua:540-542`), puis de nouveau par le moteur pour la zone concernée à trois endroits de `ZoneCommander` où une zone change de camp ou d'état actif (`zc2:50227-50231`, `zc2:55433-55437`, `zc2:56645-56649`).
`AddCTLDZone`, `ActivateZone`, `DeactivateZone`, `IsUnitInZone` sont du Moose (`Moose:82269`, `Moose:82195`, `Moose:82222`, `Moose:82511`).
`nobuildinloadzones = true` (hors PvP) interdit de construire dans une zone `LOAD`, c'est-à-dire dans une zone amie (`CTLD.lua:153`).
Un FARP construit par un joueur devient une zone `LOAD` de rayon 150 m avec une fumée bleue (`CTLD.lua:5826`, `CTLD.lua:5853`).

### Notes de reproduction

L'astuce de la zone MOVE est ce qui fait « attaquer » aux troupes déposées et aux véhicules construits la zone ennemie ou neutre la plus proche sans aucun code Foothold : c'est le `_MoveGroupToZone` de Moose (`Moose:80298`).
Une réimplémentation a besoin de son propre « zone non amie la plus proche dans un rayon de N mètres → y envoyer le groupe » au moment de la dépose des troupes et de la construction des véhicules.

## 5. Flux chargement / déchargement / construction et veto de paiement

### Ce que voit le joueur

Demander des troupes ou des caisses coûte des crédits quand `CTLDCost` est vrai et exige le rang minimum de l'objet.
Un achat refusé produit le message « pas assez de crédits / de rang » propre au moteur (venu de `bc:debit`, thème boutique) et rien n'est spawné.
Des extraits vocaux aléatoires sont joués au chargement des troupes (`troops_load_to_action.ogg`, `troops_load_ready.ogg`, `troops_load_ao.ogg`) et à leur déchargement (`troops_unload_everybody_off.ogg`, `…get_off.ogg`, `…here_we_go.ogg`, `…moving_out.ogg`, `…thanks.ogg`) (`CTLD.lua:8400-8422`).

### Mécanisme

`CanGetTroops` : renvoie false si l'objet est indisponible ; sinon, si `CTLDCost == true`, appelle `bc:debit(coalition, price × quantity, groupId, dcsGroup, reason, reqRank)` et renvoie son résultat (`CTLD.lua:6654-6675`).
`CanGetUnits` (véhicules entiers du C-130J) : même logique (`CTLD.lua:6636-6652`).
`CanGetCrates` : ignoré pour les opérations de dépose et de repliage (`CTLD.lua:6691`) ; pour « Zone supplies », il débite le stock de supply de la zone de ramassage (§8) ; pour les lots « Warehouse », il vérifie et débite l'entrepôt de l'aérodrome (§9) ; la facturation en crédits des lots d'entrepôt est `price × sets` avec vérification du rang (`CTLD.lua:6885-6901`).
Les caisses de construction ordinaires ne sont pas facturées dans `CanGetCrates` (la fonction renvoie true dès que la cargaison n'est ni un zone supply ni un lot d'entrepôt connu, `CTLD.lua:6785-6788`).
Le prix des caisses de construction ordinaires est facturé dans le Moose embarqué lui-même : `CTLD:_GetCrates` lit `CTLDCost`, `self:GetCargoPrice()` ou le `priceOf(name)` global, et appelle `bc:debit(coal, charge, gid, dcs, reason, reqRank)` (`Moose:78256-78283`) ; les libellés de menu de Moose ajoutent aussi le prix (`CTLD:_GetCargoPriceLabel`, `Moose:76351-76370`).
Le Moose embarqué dépend donc de globals Foothold (`bc`, `CTLDCost`, `priceOf`).
`Foothold_ctld._GetCrates` est en plus enveloppée pour refuser `Tor M2` et `Pantsir S1` hors PvP, et pour transporter la demande d'entrepôt à travers l'appel Moose (`CTLD.lua:7306-7350`, `CTLD.lua:7398-7401`).
Les troupes inutilisées ramenées dans une zone amie sont remboursées : `refundOrReturnRejectedTroops` accumule `priceOf(cargo)` par groupe de déployeur et vide le cumul 2 s plus tard en un seul `bc:credit(side, amount, gid, dcs, "Troops returned")` (`CTLD.lua:8472-8532`).

### Notes de reproduction

Le débit a lieu avant le spawn et il n'existe pas de chemin de retour en arrière si le spawn de Moose échoue ensuite.
Les remboursements sont regroupés sur 2 s afin que le déchargement d'un peloton de 32 hommes composé de plusieurs groupes ne produise qu'une seule ligne de crédit.

## 6. Stock, limites et règle « le plus ancien est retiré »

### Ce que voit le joueur

Chaque objet du catalogue a un stock fini (de 10 à 15, voir §2).
Quand le stock d'un objet tombe sous 5, charger ou construire un exemplaire de plus supprime le plus ancien groupe survivant de ce type et en informe le joueur : `CTLD_LIMIT_REACHED_REMOVED_OLDEST` (caisses) ou `CTLD_TROOP_LIMIT_REACHED_REMOVED_OLDEST` (troupes) (`CTLD.lua:6087-6117`, `CTLD.lua:8430-8469`).

### Mécanisme

Foothold tient deux listes, `GroundUnits` (construits à partir de caisses) et `TroopUnits` (troupes déposées), chaque entrée valant `{groupName, Timestamp, Group, CargoName, Stock, PlayerName}` (`CTLD.lua:548-549`, `CTLD.lua:6282-6289`, `CTLD.lua:8630-8640`).
`OnAfterCratesBuildStarted` : si le stock de la cargaison est inférieur à 5, l'entrée `GroundUnits` la plus ancienne de cette cargaison est détruite, retirée, et une unité de stock est rendue (`CTLD.lua:6102-6113`).
`OnAfterTroopsPickedUp` : même chose au chargement des troupes, limitée aux entrées dont le stock enregistré était inférieur à 5 (`CTLD.lua:8437-8459`) ; `OnAfterTroopsDeployed` répète la vérification au moment de la dépose (`CTLD.lua:8680-8713`).
Toutes les 60 s, `RefillMissingWithCountTable` appelle `_CountStockPlusInHeloPlusAliveGroups` de Moose (`Moose:82855`) et, pour chaque cargaison, si stock + chargé + vivant est inférieur au stock initial (`Stock0`), remet la différence ; s'il est supérieur, abaisse le stock mais jamais en dessous de 5 (`CTLD.lua:9331-9386`, timer `CTLD.lua:9415`).
Le réapprovisionnement est ignoré tant qu'une construction est en cours (compteur `buildRunning` incrémenté dans `OnAfterCratesBuildStarted`, décrémenté dans `OnAfterCratesBuild`, `CTLD.lua:9332`, `CTLD.lua:6089`, `CTLD.lua:6122`).
Construire un FARP retire une unité de stock de `CTLD_TROOP_FOB` (`CTLD.lua:5856`).

### Ce que règle le créateur de mission

`MAX_AT_SPAWN` (global, surchargeable) plafonne le nombre de groupes de chaque cargaison restaurés depuis le fichier de sauvegarde, les plus anciens étant supprimés en premier : par exemple Mephisto 2, L118 3, HAWK System 3, Hawk LN Add-on 8, IRIS T System 2, C-RAM 4, HIMARS 4, FARP 3, toute l'infanterie à 0 sauf Anti-Air Soldiers 2 et Mortar Squad 2 (`CTLD.lua:408-447`).
`MAX_SAVED_FARPS` (3 par défaut) plafonne les FARP restaurés (`CTLD.lua:450`).

### Notes de reproduction

Le plafond effectif dans le monde pour chaque objet est le « stock initial », appliqué par conservation (stock + transporté + vivant = Stock0) plutôt que par un compteur d'unités construites.
Les unités mortes rendent leur stock en moins de 60 s, donc les pertes sont gratuites.

## 7. Déploiement de troupes → capture de zone, renfort ou retour

### Ce que voit le joueur

Les troupes déposées dans une zone ou près d'elle y courent (zone MOVE de Moose), et toute la coalition voit `CTLD_TROOP_GROUP_ENTERED_ZONE` quand elles y entrent (`CTLD.lua:8862-8864`).
Dans une zone **neutre**, elles lancent une capture temporisée (règles de capture : thème 01) ; dans une zone **amie** qui peut recevoir du supply, elles sont consommées comme une livraison de supply ; dans une zone amie qui n'a besoin de rien, ou dans la zone où elles ont été ramassées, elles sont retirées et remboursées ; dans une zone **ennemie**, elles restent et se battent.
À la fin, la coalition voit une ligne par zone `CTLD_TROOP_ZONE_EVENT_LINE` (joueur, action, zone) avec l'action `captured`, `upgraded`, `stocked` ou `captured and upgraded`, plus `CTLD_TROOP_ZONE_EVENT_TOTAL` avec les crédits gagnés (`CTLD.lua:9027-9113`).
Récompense : la moitié de `bc.rewards['Zone capture']` (200 par défaut) ou la moitié de `bc.rewards['Zone supply delivery']` (150 par défaut), noms de statistiques `Zone capture (troops)` / `Zone supply delivery (troops)` (`CTLD.lua:8945-8949`, `CTLD.lua:9300-9303`).
Les ingénieurs ne peuvent pas capturer sauf si `CaptureZoneWithEngineer` est vrai ; Zone Spy et Demolition Team ne capturent jamais (`CTLD.lua:1283-1287`, `CTLD.lua:1779-1782`).

### Mécanisme

`OnAfterTroopsPickedUp` enregistre la zone de ramassage sur le groupe Moose (`updateLastPickupZone` → `bc:getZoneOfPoint`, avec repli sur la liste `supplyZones`, `CTLD.lua:3761-3807`, `CTLD.lua:8433`).
`OnAfterTroopsDeployed` (événement FSM de Moose) fait, pour chaque groupe déposé (`CTLD.lua:8535-8827`) :
- l'enregistre dans `deployedTroops`, dans le `SET_GROUP` Moose `deployedTroopsSet`, et dans `TroopUnits` ;
- trouve l'entrée du catalogue en cherchant le nom du template dans le nom du groupe spawné (`CTLD.lua:8590-8603`) ;
- enregistre le groupe pour les récompenses de kill (§15) ;
- liste les zones de campagne dans lesquelles le groupe se trouve déjà en partie (`GROUP:IsPartlyOrCompletelyInZone`, `CTLD.lua:8714-8722`) ;
- stocke `zoneCaptureInfo[groupName] = {troopGroup, zoneName, deployer, cargoName, cargoType, canCaptureZone, pickupZoneName, careerPlayerName…}` ;
- zone amie et (aucune zone de ramassage connue, ou même zone que le ramassage, ou la zone n'a pas besoin de supply selon `zone:canRecieveSupply()`) → remboursement et destruction immédiate (`CTLD.lua:8791-8802`) ;
- sinon appelle `CaptureZoneIfNeutral()`.
Les groupes déposés hors de toute zone sont surveillés par `zoneSet`, un `SET_ZONE` Moose de toutes les zones de campagne (`CTLD.lua:8286-8290`) dont la FSM `Trigger(deployedTroopsSet)` fait de la scrutation toutes les `Checktime` secondes (5 s par défaut dans Moose, `Moose:10426`, `Moose:10626`) et déclenche `EnteredZone` ; Foothold surcharge `_TriggerCheck` pour ne lire la position de chaque groupe qu'une fois par passe et pour sauter les groupes marqués `_footholdZoneEntryComplete` (`CTLD.lua:8293-8351`), et arrête la FSM de déclenchement quand plus aucune troupe déployée n'est vivante (`CTLD.lua:8385-8398`).
`zoneSet:OnAfterEnteredZone` met à jour `zoneCaptureInfo` et, pour les troupes capables de capturer dans une zone amie ou neutre, planifie `CaptureZoneIfNeutral()` 10 s plus tard (`CTLD.lua:8829-8924`).
`CaptureZoneIfNeutral` met les zones en file et exécute `processQueuedCaptures`, un worker sérialisé qui traite un groupe de troupes à la fois avec 0,1 à 5 s entre deux groupes (`CTLD.lua:8971-9327`) :
- zone neutre active → `zone:startPendingCapture(side, {kind="group", name, template, position, heading, destroyOnFinish=true, tombstone=true, stopGroup=true, delivery={handler="blue_ctld_troop_capture", payload}})` (`CTLD.lua:9263-9293`) ; le handler `completePendingBlueCtldTroop` verse la récompense quand le moteur termine la capture (`CTLD.lua:8926-8963`) ;
- zone amie → `bc:_applyRegularSupplyDelivery(zone, side, now, true)`, destruction du groupe, versement de la moitié de la récompense (`CTLD.lua:9294-9309`) ;
- troupes non capturantes dans une zone amie → stock rendu, groupe détruit, message `CTLD_TROOPS_RETURNED_TO_BASE` (`CTLD.lua:9220-9234`).
Quand le joueur récompensé est au sol dans une zone amie, un `S_EVENT_LAND` synthétique est injecté avec `world.onEvent` 5 s plus tard, de sorte que le code de récompense à l'atterrissage du moteur encaisse les crédits immédiatement (`CTLD.lua:9061-9099`).

### Notes de reproduction

Le point d'accroche dans le système de capture est un unique appel au moteur, `zone:startPendingCapture(side, request)`, plus un handler de fin nommé enregistré avec `bc:registerPendingCaptureHandler` (`CTLD.lua:8963`).
La règle « même zone que le ramassage » exige que la zone de ramassage soit mémorisée pour chaque groupe de troupes transporté : le Moose embarqué stocke `_footholdPickupZone` sur la cargaison chargée au moment du chargement (en interrogeant Foothold via `self:GetTroopPickupZone`, `Moose:77614-77616`, `CTLD.lua:8426-8428`) et le recopie sur le groupe déposé (`Moose:79394`, `Moose:81776`).
L'événement d'atterrissage synthétique est un couplage avec le système de récompenses (les crédits sont « portés » jusqu'à l'atterrissage).

## 8. Zone supplies (caisses de supply des joueurs)

### Ce que voit le joueur

Menu : F10 → `Logistics` → `Zone supplies` → la caisse correspondant à la cellule du joueur, avec un sous-menu de quantité (`zc2:101588-101695`).
La caisse est spawnée à côté de l'avion dans une zone amie (ou un FARP), chargée par l'équipe au sol de DCS / en sling / par le système de cargaison du C-130J, transportée vers une autre zone et déchargée ou larguée par parachute là-bas.
Messages : `CTLD_CRATE_LOADED_GROUND_CREW`, `CTLD_CRATE_UNLOADED_GROUND_CREW` (`CTLD.lua:4620`, `CTLD.lua:4787`), puis `CTLD_ZONE_SUPPLIES_DELIVERED` avec un texte d'action : `captured`, `capturing`, `queued`, `stocked (ready/max)` (`CTLD.lua:4502-4508`, `CTLD.lua:5353-5357`).
Livrée dans une zone neutre, elle lance une capture ; dans une zone amie, elle ajoute une unité de supply accélérée au stock de la zone et 10 de chaque arme à son entrepôt ; dans un FARP de joueur, elle ajoute 1 au compteur de supply du FARP ; dans une zone ennemie, elle est détruite avec la raison `enemy zone` (`CTLD.lua:5196-5222`, `CTLD.lua:5315-5371`).
Récompense de 150 crédits et statistique `Zone supply delivery` (`CTLD.lua:5371`, `CTLD.lua:5216-5217`) ; une capture menée à terme verse `bc.rewards['Zone capture']` (200 par défaut) et la statistique `Zone capture` (`CTLD.lua:4555-4558`, `CTLD.lua:1362`).
Reposée dans la zone d'où elle vient, la caisse est retirée et le stock remboursé : `CTLD_SUPPLIES_RETURNED_TO_ZONE` (`CTLD.lua:5063-5075`).
Décoller d'une zone de supply sans supplies déclenche `LOGISTICS_WARNING_NOT_LOADED` et `micclick.ogg` pour certaines cellules (`zc2:101336-101410`).

### Ce que règle le créateur de mission

`PlayerZoneSuppliesConsumeStock` (Config) : quand il est vrai, prendre une caisse de supply consomme une unité du stock de « regular supply » de la zone source et échoue avec `CTLD_WAREHOUSE_NOT_AVAILABLE` / `CTLD_REASON_INSUFFICIENT_STOCK` quand la zone n'en a plus (`CTLD.lua:6768-6782`).
`CTLDSupplyCapacity` : compteur de supply initial d'un FARP nouvellement construit (`CTLD.lua:5718`).
`CTLDCargoTrackingInterval` : période de suivi des caisses ordinaires, bornée à 3–6 s (`CTLD.lua:9437`).
`WarningNoSupplies` et `ZoneSupplyTakeoffWarningTypes` : interrupteur de l'avertissement au décollage et liste des cellules (`zc2:97620-97644`).

### Mécanisme

Ramassage : `CanGetCrates` résout la zone de ramassage, puis consomme soit le stock du FARP (`consumeBuiltFarpSupplyStock`), soit le stock de la zone (`zone:_consumePlayerRegularSupplyStock(sets, BLUE, now)`), et met en file un enregistrement de « débit de ramassage » indexé par nom d'unité (`CTLD.lua:6733-6782`, `CTLD.lua:3175-3207`).
`OnAfterGetCrates` (événement Moose après le spawn des statics de caisse) enregistre chaque caisse dans `zoneSupplyCrates[cargoId]` avec la zone de ramassage, le groupe, le joueur, l'unité porteuse, les dimensions de la cellule, et réclame le débit en attente pour que la caisse se souvienne du stock de zone qu'elle a consommé (`CTLD.lua:7094-7177`, `CTLD.lua:3344-3417`, `CTLD.lua:3280-3335`).
`OnAfterCratesPickedUp` rattache l'entrée de suivi à celui qui l'a réellement chargée (`CTLD.lua:7270-7303`).
Boucle de suivi `tickZoneSupply` : toutes les 3 s pour les caisses du C-130J et toutes les `CTLDCargoTrackingInterval` pour les autres, un seul `timer.scheduleFunction` pilotant les deux cadences (`CTLD.lua:9418-9438`, `CTLD.lua:4191-4202`).
Pour chaque caisse suivie, `processZoneSupplyDeliveries` lit la position du static (`STATIC:GetVec3`), décide « déplacée » quand elle a bougé de plus de 0,5 m depuis la passe précédente (`CTLD.lua:2968-2982`), et dérive les états `wasAirborne`, `attached`, `detached`, `_wasUnloaded` en comparant la position de la caisse avec celle de l'unité porteuse par rapport à une boîte par cellule `{width, height, length, ropelength}` (`CTLD.lua:1372-1382`, `CTLD.lua:4703-4793`).
Une caisse est « au sol » quand son AGL ≤ 0,5 m ou qu'elle a été déchargée et ne bouge plus (`CTLD.lua:4803`) ; les largages par parachute du C-130J sont confirmés par une vérification unique 1 s plus tard : la caisse doit être sous 10 m AGL et ne pas avoir bougé de plus de 0,5 m (`CTLD.lua:4143-4189`, `CTLD.lua:1368-1370`).
Une caisse posée est rattachée à une zone avec `bc:getZoneOfPoint(vec3)`, sinon comparée aux noms de `supplyZones` via `ZONE:IsVec3InZone` de Moose (`CTLD.lua:4817-4833`) ; hors de toute zone, elle est revérifiée toutes les 60 s et supprimée après 600 s (`CTLD.lua:4971-4993`, `CTLD.lua:1364-1366`).
Les caisses prêtes sont appliquées une par une, à 3 s d'intervalle, par `zoneSupplyProcessReadyQueue` → `zoneSupplyApplyOne` (`CTLD.lua:5375-5476`).
Zone neutre : `zone:startPendingCapture(BLUE, {kind="static", name, position, staticType, country, destroyOnFinish=true, tombstone=true, delivery={handler="blue_ctld_capture_delivery", …}})` (`CTLD.lua:5316-5363`) ; le handler `completePendingBlueCtldSupply` accorde le lot d'entrepôt et verse la récompense (`CTLD.lua:4528-4561`).
Zone amie : `zone:_addExpeditedRegularSupplyStock(1, now)`, `grantZoneBundle` (= `adjustWarehouseStockAtZone(zone, +10, all categories)`), récompense (`CTLD.lua:5366-5371`, `CTLD.lua:3925-3929`).
L'API brute de DCS en dessous : `StaticObject.getByName():destroy()` pour la suppression (`CTLD.lua:4126-4135`), `Unit:getPoint/inAir/getVelocity`, `land.getHeight`.

### Notes de reproduction

Il n'existe aucun événement DCS « static de cargaison posé dans la zone X » qui fonctionne à la fois pour le sling, l'équipe au sol et le C-130J, d'où la machine à états de scrutation sur chaque caisse vivante ; le nombre d'objets scrutés est égal au nombre de caisses de supply dans le monde.
Le test de la boîte par cellule remplace une API « ce static est-il à l'intérieur de cet avion » qui n'existe pas.
Les livraisons sont volontairement sérialisées (une toutes les 3 s) et les suppressions sont mises en file (`zoneSupplyPendingRemoval`) pour éviter les rafales.
Le cache `ZoneSupplyOnboardByGroup` (id de groupe → a des supplies à bord) n'existe que pour que l'avertissement au décollage ne parcoure pas toutes les caisses (`CTLD.lua:3109-3139`).

## 9. Cargaison d'entrepôt : déplacer du stock d'armement entre aérodromes avec CTLD

### Ce que voit le joueur

Menu : F10 → `Logistics` → `Warehouse` → `15 / 25 / 50 of everything`, `… A/A Missiles`, `… A/G Missiles`, `… A/G Rockets`, `… A/G Bombs`, `… fuel tanks and pylons`, `… Modded weapons` (§2).
Prendre un lot retire ce nombre de **chaque** arme des catégories listées à l'aérodrome sur lequel se trouve le joueur ; le livrer à un autre aérodrome/FARP ami les y ajoute.
Refus : `CTLD_WAREHOUSE_NOT_AVAILABLE` (libellé, lieu, raisons `CTLD_REASON_NO_ITEMS` / `CTLD_REASON_INSUFFICIENT_STOCK` par catégorie / `CTLD_REASON_NO_STORAGE`), `CTLD_WAREHOUSE_REMOVE_FAILED`, `CTLD_WAREHOUSE_MISCONFIGURED_INVALID_AMOUNT` (`CTLD.lua:6791-6925`).
Livraison : message de coalition `CTLD_SUPPLIES_DELIVERED_BY` (libellé, zone, joueur), récompense issue de la définition du lot (150 pour « 15/50 of everything », 75 pour « 25 of everything », 15–50 pour les lots à catégorie unique), statistique `Warehouse delivery` (`CTLD.lua:1309-1335`, `CTLD.lua:5294-5306`).
Larguée dans une zone ennemie, la caisse est détruite (`enemy zone`) ; dans une zone neutre, elle attend 60 s que la zone devienne amie, puis est détruite (`neutral zone timeout`) (`CTLD.lua:5226-5246`).

### Mécanisme

Actif seulement quand `WarehouseLogistics == true` (`CTLD.lua:6785`, `CTLD.lua:6301`).
`WAREHOUSE_SUPPLY_TYPES[name] = {categories, amount, reward, label}` (`CTLD.lua:1309-1347`) ; les roquettes comptent triple (`WAREHOUSE_CATEGORY_MULTIPLIER.AG_ROCKETS = 3`, `CTLD.lua:1398-1400`).
Ramassage (`CanGetCrates`) : trouver le stockage de l'aérodrome de la zone de ramassage (`getZoneStorageHandle` : `STORAGE:FindByName(zone.airbaseName or zone.baseName or zoneName)`, mis en cache, `CTLD.lua:3858-3881`), vérifier que la quantité cumulée de chaque catégorie est au moins `amount × sets`, facturer les crédits, puis `adjustWarehouseStockAtZone(zone, -amount×sets, categories)` (`CTLD.lua:6822-6907`).
`adjustWarehouseStockAtZone` parcourt `WEAPONSLIST.GetItems(category)` et, pour chaque objet, fait `storage:SetItem(name, current + delta)` ; au débit, les objets dont le stock est inférieur au besoin sont sautés ; au crédit, les objets restreints par époque sont sautés en Coldwar, les armes intelligentes listées dans `WarehouseWeaponCaps` reçoivent la moitié quand `StrictSmartWeaponsInventory` est vrai, et les objets de `ForbiddWeaponsInAllEra` sont toujours forcés à 0 (`CTLD.lua:6300-6388`, `CTLD.lua:3904-3923`).
Livraison (`zoneSupplyApplyOne`) : même suivi que les zone supplies avec `deliveryType = "warehouse"`, se terminant par `adjustWarehouseStockAtZone(zone, +amount, categories)` (`CTLD.lua:5225-5311`).
Deux variantes plus strictes existent : le PvP, et le mode « managed » quand une `WarehouseWeaponLocationPolicy` est active ; dans les deux, les quantités exactes par objet débitées sont stockées sur la caisse (`cargo._warehouseDebitItems`) et réappliquées objet par objet à destination par `ApplyWarehouseDebitItems` (`storage:AddItem`), avec des états de règlement `applied` / `discarded` et un chemin de remboursement quand la caisse est retirée à sa source (`CTLD.lua:6395-6425`, `CTLD.lua:6427-6505`, `CTLD.lua:6964-7006`).
Le `STORAGE` de Moose enveloppe l'objet `Warehouse` de DCS : voir §17.

### Le mode managed en détail (PvE avec une politique d'emplacement des armes)

- Entrée : `Foothold_ctld._GetCrates` (l'enveloppe autour de la fonction Moose) construit un `warehouseRequest = {cargoName, _warehouseMeta}` quand `WarehouseLogistics` est actif, qu'une politique est active et que la sous-catégorie de la cargaison est `Warehouse`, et le passe à l'appel Moose comme argument supplémentaire ; le `CTLD:_GetCrates` du Moose embarqué rappelle `_prepareManagedWarehousePickup` avant le spawn (`Moose:78338`), `_completeManagedWarehousePickup` après (`Moose:78609`) et `_bindManagedWarehouseDrop` quand une caisse larguée est remplacée (`Moose:78578`) — trois hooks de plus propres à Foothold à l'intérieur du Moose embarqué (`CTLD.lua:7355-7360`, `CTLD.lua:7401-7402`).
- Préparation (`_prepareManagedWarehousePickup`) : le stockage source doit exister et appartenir au camp du joueur ; pour chaque catégorie du lot, chaque objet du catalogue est résolu en une identité de politique (`WarehouseWeaponLocationPolicy.GetItemIdentity`) et reçoit une ligne `{key, item, stock, optional, take}` (`CTLD.lua:6427-6453`).
- Un objet dont la règle de politique n'autorise pas cet aérodrome est « optional » : tout ce qui est en stock est pris, jusqu'à la limite ; tout autre objet n'est pris que si le stock couvre toute la limite (`amount × sets`, × 3 pour les roquettes), sinon rien n'en est pris ; la catégorie est refusée avec `CTLD_REASON_INSUFFICIENT_STOCK` quand le stock total de ses objets attendus est inférieur au besoin (`CTLD.lua:6455-6473`).
- La facturation en crédits (`price × sets`, vérification du rang) est débitée à ce stade par `bc:debit` et mémorisée dans `request.paid` (`CTLD.lua:6489-6503`).
- Achèvement (`_completeManagedWarehousePickup`) : si Moose a spawné moins de caisses que demandé, les sets non spawnés sont remboursés (`bc:credit(…, "warehouse crate spawn")`) ; chaque caisse est marquée `_warehouseManaged` et estampillée avec sa zone source, son aérodrome, l'id natif de l'aérodrome, le camp, sa part du prix et le nom de l'acheteur ; le `take` de chaque ligne est réparti à parts égales entre les caisses (le reste aux premières) dans `cargo._warehouseDebitItems[key] = {item, amount}`, et ce n'est qu'alors que le stockage est débité avec `storage:SetItem(key, stock - take)` (les stocks illimités sont laissés intacts) (`CTLD.lua:6518-6554`).
- Une caisse managed est donc un manifeste exact : ce qui quitte un entrepôt est ce qui arrive dans l'autre, objet par objet (`ApplyWarehouseDebitItems` ajoute `amount.amount` de `amount.item`, en sautant les objets interdits, ceux restreints par époque à la livraison et les destinations qui détiennent l'objet en quantité illimitée) (`CTLD.lua:6395-6423`).
- Identité de la caisse à travers les opérations de cargaison de DCS : `_indexManagedWarehouseCargo` tient `_managedWarehouseCargoByStatic[staticName] = cargo` ; les événements de cargaison dynamique du Moose embarqué appellent `_updateManagedWarehouseDynamicCargo(event, "loaded" | "unloaded" | "removed")`, qui rattache l'entrée de suivi à l'objet de cargaison dynamique de DCS, marque la caisse attachée/détachée, ou abandonne le manifeste quand DCS a retiré la cargaison (`CTLD.lua:6507-6516`, `CTLD.lua:6603-6634`, `Moose:77313`, `Moose:77346`).
- Quand Moose remplace un objet caisse à la dépose, `_bindManagedWarehouseDrop(original, replacement)` transfère tout le manifeste et l'état de règlement au remplaçant et le réenregistre dans la boucle de suivi des supplies comme déjà déchargé (`CTLD.lua:6556-6595`).

### Le mode PvP en détail

- En PvP, chaque demande de caisse (pas seulement les lots d'entrepôt) ouvre un contexte `_warehousePickupRequest` contenant l'unité de ramassage, la zone LOAD où elle se trouve et, quand cette zone est un FARP construit par un joueur, son enregistrement et son aérodrome natif ; un FARP de l'autre camp refuse la demande (`CTLD.lua:7370-7388`).
- Pour les lots d'entrepôt, la demande porte aussi la définition du lot et une phase de devis (`awaiting` quand `CTLDCost`, sinon `free`) : le prix est annoncé et facturé dans les hooks, et le stock réellement admis est rattaché ensuite aux caisses spawnées par `claimZoneSupplyPickupDebit` (zone source, camp, id natif, manifeste des objets, prix payé, acheteur) (`CTLD.lua:7390-7400`, `CTLD.lua:7495-7511`).
- À la dépose, quand Moose spawne une caisse de remplacement pour une caisse qui portait un manifeste ou une unité de zone supply consommée, chaque champ `_warehouse*` / `_zoneSupply*` est déplacé de l'ancien objet de cargaison vers le nouveau et l'entrée de suivi est ré-indexée, marquée en vol puis déchargée (`CTLD.lua:7408-7475`).
- La même enveloppe maintient cohérent l'ensemble de construction automatique du C-130J quand l'une de ses caisses est remplacée à la dépose (`CTLD.lua:7477-7494`).
- L'enveloppe bloque aussi toujours `Tor M2`, `Pantsir S1` hors PvP Modern, et toute cargaison dont la politique dit indisponible (`CTLD.lua:7347-7354`).

### Notes de reproduction

Dans le mode par défaut (non managed), un lot n'est pas conservé : le débit saute les objets en rupture de stock alors que le crédit ajoute la quantité complète de chaque objet, si bien qu'une livraison peut créer du stock.
Le mode managed/PvP existe pour combler cet écart, au prix d'un manifeste par caisse.

## 10. Équipes de troupes spéciales : Zone Spy et Demolition Team

Les deux sont des comportements propres à Foothold posés par-dessus la cargaison de troupes de Moose ; aucune n'existe en PvP, et la Demolition Team exige `UseStatics` (`CTLD.lua:269-274`).

### Zone Spy — ce que voit le joueur et mécanisme

Un seul soldat déposé à moins de `movetroopsdistance` d'une zone ennemie marche vers la zone RED la plus proche (vitesse de route de 36 km/h, vitesse du contrôleur forcée à 10 m/s avec `Controller:setSpeed`), en formation `Diamond` (`CTLD.lua:1531-1537`, `CTLD.lua:1887-1945`).
En y entrant, `startZoneIntel(zoneName, 3600, BLUE)` révèle la zone pendant une heure (système d'intel : autre thème) et la coalition reçoit `CTLD_SPY_INTEL_ACTIVE` (`CTLD.lua:1947-1964`).
L'espion retourne ensuite à son point de dépose ; à l'arrivée : message de coalition `CTLD_SPY_READY_EXTRACTION` avec le nom de la zone la plus proche et le MGRS, et fumée bleue à 30 m (`CTLD.lua:1813-1868`).
Si aucune zone ennemie n'est à portée : `CTLD_DEMO_NO_ENEMY_ZONE` avec la portée (`CTLD.lua:1924-1932`).
Le routage utilise `GROUP:RouteGroundTo`, `COORDINATE:WaypointGround` et `GROUP:TaskFunction` de Moose (une tâche de waypoint qui appelle par son nom une fonction Lua globale, c'est-à-dire un `WrappedAction` DCS avec une commande `Script`) (`CTLD.lua:1815-1831`).

### Demolition Team (la classe `Demolition`, `CTLD.lua:1557-2589`)

Ce que c'est : une équipe de sapeurs IA de deux hommes qui entre dans une zone ennemie, pose des charges temporisées sur les **structures statiques** de la zone (noms de `zoneObject.built` résolus avec `StaticObject.getByName`, `CTLD.lua:1972-1982`) et ressort avant qu'elles n'explosent.
Constantes : vitesse de route 36 km/h, retrait du waypoint à 35 m de la cible, portée de pose 150 m, mèche 120 s, vitesse de planification 3,5 m/s, marge d'évacuation 25 m, distance de confirmation +200 m, 16 rayons d'évacuation, récompense de 50 crédits par structure détruite (`CTLD.lua:1558-1571`).
Zone cible : la zone RED la plus proche dans la limite de `movetroopsdistance` qui a encore des structures vivantes ; sinon `CTLD_DEMO_NO_STRUCTURE_TARGETS` ou `CTLD_DEMO_NO_ENEMY_ZONE` (`CTLD.lua:1984-2012`, `CTLD.lua:2420-2430`).
Les cibles sont ordonnées par plus proche voisin glouton (`OrderNearest`, `CTLD.lua:1747-1766`) et l'équipe est routée vers un point à 35 m en deçà de la première avec une tâche de waypoint `Foothold_ctld.DemolitionPlantWaypoint` (`CTLD.lua:2085-2118`).
Au waypoint, un « lot » est créé : la cible principale plus toute autre structure assignée à moins de 150 m d'un membre vivant de l'équipe reçoit une charge dont la puissance est `max(100, ceil(life × 0.45 / 50) × 50)` (`CTLD.lua:1573-1576`, `CTLD.lua:2301-2366`) ; message de coalition `CTLD_DEMO_PLANTING` (`CTLD.lua:2399-2403`).
Planification de l'évacuation : chaque charge est un cercle de danger dont le rayon est interpolé à partir de la puissance (100 → 200 m, 450 → 300 m, 750 → 350 m, 1800 → 450 m), plus un cercle agrégé au centroïde pondéré par la puissance ; 17 directions candidates (à l'opposé du centroïde + 16 rayons, ou tout droit vers la cible suivante si cela dégage tous les cercles) sont notées par distance de sortie, et les infaisables (impossibles à parcourir en 120 s à 3,5 m/s) sont pénalisées (`CTLD.lua:1584-1730`).
Détonation : `timer.scheduleFunction(FuseBatch, batch, plantedAt + 120)` ; le lot n'explose que lorsque la mèche est écoulée **et** que chaque membre vivant de l'équipe est hors de tous les cercles de danger (revérifié au waypoint d'évacuation et toutes les 60 s par `RefreshPendingBatch`), avec `trigger.action.explosion(point, power)` ; une seconde plus tard, `ConfirmCharge` vérifie que le static est mort et rémunère le propriétaire s'il est encore vivant dans son avion (`CTLD.lua:2236-2286`, `CTLD.lua:2220-2234`, `CTLD.lua:2159-2172`).
Récompenses : `bc:addContribution(owner, BLUE, 50)`, statistique temporaire `Demolition kill`, statistique de carrière `DemolitionKills` (`CTLD.lua:2226-2230`).
Plusieurs équipes dans la même zone se partagent les cibles : `RebalanceZone` donne à chaque équipe un quota équilibré, conserve la cible vers laquelle une équipe marche déjà, et place les arrivées tardives en `reserve` jusqu'à ce qu'elles soient dans la zone (`CTLD.lua:2463-2556`).
Changements de zone : zone devenue neutre → l'équipe s'arrête et tient position, charges annulées ; zone devenue BLUE → équipe détruite et son stock remboursé (`CTLD_TROOPS_RETURNED_TO_BASE`) ; zone redevenue RED → l'équipe rentre (`CTLD.lua:2558-2588`).
La mort de l'équipe est détectée par le timer de réapprovisionnement de 60 s et annoncée avec `CTLD_DEMO_KILLED` (`CTLD.lua:9388-9412`).
Une fois terminée, l'équipe retourne à son point de dépose et annonce `CTLD_DEMO_READY_EXTRACTION` avec une fumée, comme l'espion (`CTLD.lua:2135-2148`).
L'état vit sur l'entrée `TroopUnits` sous la forme `entry.Demo = {deployer, ownerPlayerName, ownerGroupName, dropPoint, targetZoneName, status, routeGeneration, assignedTargets, currentTarget, planted, activeBatch…}` (`CTLD.lua:8654-8669`) ; un compteur `routeGeneration` invalide les callbacks de waypoint périmés (`CTLD.lua:2373`).

### Notes de reproduction

Le tout est piloté par événements via des tâches de waypoint, donc il ne coûte rien pendant que l'équipe marche ; la seule scrutation est le rafraîchissement mort/mèche de 60 s.
Les parties difficiles : les callbacks de tâche de waypoint qui arrivent après un nouvel itinéraire (d'où le compteur de génération), et la garantie que l'équipe est à l'abri avant `trigger.action.explosion` (l'explosion tue l'infanterie amie).
Cela dépend de ce que l'objet zone expose les noms de ses structures (`zone.built`) — un concept du moteur issu d'un autre thème.

## 11. Systèmes SAM construits en pièces (caisses « Add-on » et fusion)

### Ce que voit le joueur

Un `HAWK System`, `NASAMS System` ou `IRIS T System` est un site de base complet.
Les caisses `… Add-on` (une caisse chacune) construites à moins de 400 m d'un système existant de la même famille y sont absorbées : le site est respawné comme un seul groupe avec le lanceur/radar/poste de commandement supplémentaire (`CTLD.lua:577`, `CTLD.lua:1180-1281`).
Messages : `CTLD_SAM_MERGE_COMPLETE` (famille, rôle) ou `CTLD_SAM_MERGE_FAILED_MISSING_TEMPLATE` / `_NO_COMPONENT` / `_APPEND` / `_SPAWN` (`CTLD.lua:1223-1279`).
Récompense pour une amélioration : 150 (HAWK, NASAMS) ou 200 (IRIS-T), statistiques `Upgraded HAWK` etc. (`CTLD.lua:5947-5951`).

### Mécanisme

`SAM_MERGE_PROFILES` décrit chaque famille : nom du template du système, noms de cargaison, ordre des rôles, nom de cargaison → rôle, template → rôle, rôle → type d'unité DCS, et nombres d'unités de base (HAWK : TR 1, SR 1, LN 2, PCP 1, CWAR 1 ; NASAMS : C2 1, SR 1, LN 2 ; IRIS : STR 1, LN 1, C2 1) (`CTLD.lua:749-813`).
Dans `OnAfterCratesBuild`, si le véhicule construit se résout en un profil et un rôle, `samMergeTryMergeComponentIntoNearbySystem` est appelée (`CTLD.lua:6227-6246`).
Elle trouve le groupe de système vivant le plus proche du profil (d'abord dans `GroundUnits`, sinon un balayage unique `SET_GROUP:FilterCoalitions("blue"):FilterZones({ZONE_RADIUS}):FilterOnce()` de Moose, `CTLD.lua:1128-1178`), prend le template courant du système, y ajoute l'unité du composant, réordonne les unités par rôle, les dispose sur des anneaux de 6 emplacements (rayon 120 m + 35 m par anneau) autour de l'unité d'ancrage, répartit uniformément les caps des lanceurs sur 360°, nettoie les épaves avec `world.removeJunk` dans une sphère de 400 m, spawne le template fusionné sous un nouveau nom `<system_template>-<random>`, puis détruit l'ancien système et le composant (`CTLD.lua:587-669`, `CTLD.lua:1234-1254`).
Les listes de suivi (`GroundUnits`, `DroppedTroops` de Moose, registre des récompenses de kill) sont repointées vers le nouveau groupe (`CTLD.lua:1256-1273`).
Les sites augmentés survivent aux redémarrages **sans fichier de sauvegarde propre** : le CSV du CTLD de Moose stocke déjà, pour chaque groupe sauvegardé, une colonne `Structure` listant `unitType==count;…` (`UTILS.GetCountPerTypeName(group)`, `Moose:83881`, `Moose:83910-83912`), et Foothold relit ce même fichier 5 s après le chargement du CTLD (`CTLD.lua:8276-8283`) :
- `LoadIRISAugments()` relit `Foothold_ctld.filename` avec `UTILS.LoadFromFile`, garde les lignes qui sont un système SAM d'un profil connu (nom du template du système dans le nom du groupe ou dans la colonne des templates de cargaison, ou un nom de cargaison de système), convertit la colonne `Structure` en un nombre par rôle, et garde les lignes où un rôle dépasse la base du profil : `{profile_key, x, y, extras = {[role] = count above baseline}}` (`CTLD.lua:7847-7924`) ;
- `ApplyIRISAugments(rows)` : Moose vient de restaurer chaque site depuis son template de **base** ; pour chaque ligne, le système restauré du même profil le plus proche dans `IRIS_MERGE_DISTANCE` (400 m) et pas encore apparié est retenu, son template est étendu avec des copies de l'unité de chaque rôle jusqu'à atteindre les nombres sauvegardés, la disposition est recalculée, et le site est respawné sous un nouveau nom `<system_template>-<random>`, avec le même repointage de `GroundUnits`, de `DroppedTroops` de Moose et du registre des récompenses de kill qu'une fusion en direct (`CTLD.lua:7926-8060`) ;
- `RunIrisOnePassStandaloneMerge()` parcourt ensuite `GroundUnits` une fois et tente de fusionner chaque composant d'extension autonome survivant dans un système proche (`CTLD.lua:8062-8096`).
Les trois étapes sont sautées quand une remise à zéro de manche PvP est en attente (`CTLD.lua:8277`).
Replier un site augmenté : `OnBeforeCratesPacked` compte les unités de chaque rôle dans le groupe replié et, pour chaque unité au-dessus de la base, crée le lot de caisses d'extension correspondant à côté du joueur (`_GetCrates(Group, Unit, addonCargo, extra × cratesPerSet, false, true, true, true)`, message `CTLD_CRATES_POSITIONED`), de sorte que rien ne soit perdu quand un HAWK à 3 lanceurs est replié en caisses ; pour un C-130J, les nouvelles caisses sont enregistrées comme celles qui ont été demandées (`CTLD.lua:7520-7594`, `CTLD.lua:7596-7602`).
Quand la construction vient d'un auxiliaire de construction automatique du C-130J, le rayon de fusion est le `EngineerSearch` de Moose au lieu de 400 m (`CTLD.lua:6229-6238`).

### Notes de reproduction

DCS ne peut pas ajouter une unité à un groupe vivant : la fusion consiste à « respawner tout le site », ce qui remet les dégâts à zéro sauf traitement particulier (`IRIS_RESTORE_UNIT_HEALTH_ON_MERGE`, false par défaut, `CTLD.lua:581`) et change le nom du groupe, donc tout ce qui référence l'ancien nom (réseau de défense aérienne, persistance, récompenses) doit être mis à jour.

## 12. Distance minimale entre SAM construits (PvP uniquement)

En PvP, `CanBuildCrates` est surchargée : les caisses nommées `Pantsir S1`, `Tor M2` ou `SA-8` sont retirées de la liste de construction quand un groupe vivant construit à partir de la même cargaison par la même coalition se trouve à moins de 8 NM (`8 * 1852` m) de la caisse, ou quand une autre construction de la même cargaison est en attente à moins de 8 NM (`CTLD.lua:2778-2866`).
Le joueur (ou le pilote du C-130J derrière un auxiliaire de construction automatique) reçoit `CTLD_SAM_BUILD_SPACING` avec le nom de la cargaison (`CTLD.lua:2858-2864`).
`_CleanUpCrates` et `_BuildObjectFromCrates` sont enveloppées pour enregistrer et effacer la position de la construction en attente (`CTLD.lua:2868-2896`).
Dans le jeu hors PvP, `Foothold CTLD.lua` ne contient aucune règle d'espacement ; la seule règle de placement est `nobuildinloadzones` (`CTLD.lua:153`).

## 13. C-130J (et mod Hercules) : chargement, largage et construction automatique

### Ce que voit le joueur

Le C-130J-30 utilise le système de cargaison natif de DCS : les caisses demandées depuis le menu CTLD spawnent sur le côté de la rampe, sont chargées avec l'interface de chargement propre au module, et peuvent être déchargées au sol ou larguées par parachute en vol.
Quand **toutes** les caisses d'un ensemble demandé se sont immobilisées au sol en dehors de la zone où elles ont été ramassées, l'objet se construit tout seul après environ 2 s plus les 30 s de construction, sans ingénieur et sans action de menu (`CTLD.lua:3604-3704`).
Messages : `CTLD_MOVE_CARGO_BEFORE_HERCULES_AUTOBUILD` (caisses posées dans leur zone de ramassage), `CTLD_AUTO_BUILD_FAILED_DESTROYED` (une caisse est morte), `CTLD_AUTO_BUILD_SKIPPED_AIRBORNE` (`CTLD.lua:3555`, `CTLD.lua:3586`, `CTLD.lua:3606`).
Les caisses de zone supply et d'entrepôt larguées depuis un C-130J suivent §8/§9 avec une détection d'atterrissage dédiée.
Le C-130J peut aussi prendre des véhicules entiers (`AddUnits`, §2) et jusqu'à 64 troupes (§1).

### Ce que règle le créateur de mission

`UseC130LoadAndUnload` (Config) active la fonctionnalité (`CTLD.lua:168-170`, `CTLD.lua:7193`).

### Mécanisme

`OnAfterGetCrates` : quand l'unité demandeuse est un C-130J (`CTLD:IsC130J`, Moose) et que la fonctionnalité est active, les caisses constructibles de la demande sont enregistrées comme un seul « ensemble de construction automatique » `{id, groupName, playerName, unitName, pickupZone, crates, required}` et une entrée par caisse (`CTLD.lua:7193-7211`, `CTLD.lua:2720-2775`).
`processC130AutoBuild` tourne dans le tick de 3 s (`CTLD.lua:4191-4194`, `CTLD.lua:3455-3759`) : pour chaque caisse, il suit `attached` (caisse à moins de `attach` = 10 m de l'avion au sol), `detached` (à plus de `detach` = 14 m de l'avion en vol), `wasAirborne` (AGL ≥ 8 m) et `landed` (AGL ≤ 0,5 m, immobile, AGL stable à 0,05 m près sur deux passes, et hors de la zone de ramassage).
Si personne n'est enregistré comme propriétaire, les 10 premiers mètres de déplacement de la caisse désignent le propriétaire comme le client C-130J le plus proche (à moins de 4 m en 2D, sinon à moins de 250 m en 3D) parmi un `SET_CLIENT` de Moose filtré sur le type `C-130J-30` (`CTLD.lua:2639-2699`, `CTLD.lua:3489-3499`).
Quand toutes les caisses d'un ensemble ont atterri, l'ensemble est abandonné avec `CTLD_AUTO_BUILD_SKIPPED_AIRBORNE` (« auto-build skipped (aircraft not airborne) », `L10N:1706`) si l'avion propriétaire est au sol avec un joueur dedans (`c130AutoBuildCarrierBlocksBuild`, `CTLD.lua:2603-2619`, `CTLD.lua:3605-3611`) : la construction automatique ne vaut que pour les ensembles largués en vol, les caisses déchargées au sol restent pour une construction manuelle.
Sinon, le script spawne un auxiliaire invisible : un groupe `Soldier M4` d'un seul homme `CTLD_C130_HELPER_<n>` au centroïde des caisses via `coalition.addGroup` (`CTLD.lua:3613-3655`).
Deux secondes plus tard, il appelle `_BuildCrates(helperGroup, helperUnit, true, true, notifyGroup)` de Moose — la même routine de construction qu'un joueur déclencherait, l'auxiliaire jouant le rôle d'ingénieur — et détruit l'auxiliaire `buildtime + 5` s plus tard ; les caisses restantes sont détruites en même temps (`CTLD.lua:3668-3753`).
Le nom de l'auxiliaire renvoie au vrai joueur pour les récompenses et les statistiques de carrière (`ctldBuildRewardHelperOwners`, `CTLD.lua:3659-3664`, `CTLD.lua:6030-6041`) et les constructions larguées ont leurs propres compteurs de carrière (`CTLD.lua:6056-6064`).
Le Moose embarqué contient aussi sa propre construction automatique par cargaison dynamique du C-130 (`_C130DcAuto*`, `Moose:76571-77249`, activée seulement si `UseC130DynamicCargoAutoBuild` est défini, `Moose:83574-83577`) ; Foothold ne positionne pas ce drapeau dans `CTLD.lua` et utilise sa propre implémentation décrite ci-dessus.
**Mod Hercules** : c'est un transport CTLD valide (préfixe `Hercules`, capacités 8 caisses / 20 troupes, `CTLD.lua:104`, `CTLD.lua:465`) et il a un chemin hérité séparé, `HercCargoDropSupply` (§20).

### Notes de reproduction

La détection d'atterrissage des statics en chute libre/sous parachute est de la pure scrutation avec anti-rebond ; les seuils (0,5 m AGL, 0,05 m de stabilité, 8 m « était en vol », 10/14 m d'attache/détache) sont empiriques.
L'astuce du soldat auxiliaire réutilise une routine de construction qui exige une unité constructrice près des caisses.

## 14. Kits de construction FARP et « FARP with ZELL »

### Ce que voit le joueur

Trois caisses de `FARP` (ou `FARP Huey` pour l'UH-1H, caisses plus légères) construites en dehors de toute zone de campagne créent un FARP invisible fonctionnel nommé `CTLD FARP <name>` à partir d'une liste fixe de 11 noms clairs (`CTLD.lua:5769-5807`).
Message de coalition `DYNAMIC_FARP_IN_OPERATION` (`CTLD.lua:5854`).
Sur la carte F10 : un cercle de 150 m et une étiquette de texte `<name> [SUP] <n>` montrant le compteur de supply du FARP (`CTLD.lua:5907-5923`, `CTLD.lua:1428-1431`).
Le FARP est une zone de ramassage CTLD (troupes, caisses, zone supplies tant que son compteur de supply est supérieur à zéro), possède un entrepôt, et peut servir au réarmement/ravitaillement en carburant et (si la mission l'autorise) au spawn dynamique.
`FARP with ZELL` spawne en plus un objet héliport `Zell` (lancement à longueur nulle) à côté du FARP, approvisionné avec un type d'avion et du carburant, depuis lequel un jet peut spawner (`CTLD.lua:5600-5692`, `CTLD.lua:5590-5597`).
Récompense de construction : 100 crédits, statistique `Built FARP`, statistique de carrière `FarpsBuilt` (`CTLD.lua:5932-5937`, `CTLD.lua:6142-6149`).
Construire à l'intérieur d'une zone de campagne est refusé en silence (`CTLD.lua:5699-5702`).

### Ce que règle le créateur de mission

Les templates `CTLD_TROOP_FOB` et (optionnel) `CTLD_TROOP_FOB_ZELL` doivent exister dans le `.miz` (`CTLD.lua:324-328`).
Config : `CTLDSupplyCapacity` (compteur de supply initial du FARP, 1 par défaut, `Config:1299`), `MAX_SAVED_FARPS` (maximum restauré, 3 par défaut, `Config:2155`), entrées de prix `FARP` et `FARP with ZELL` (`Config:2011-2012`).
En dur dans `CTLD.lua` : noms London, Dallas, Paris, Moscow, Berlin, Rome, Madrid, Warsaw, Dublin, Perth, Stockholm (PvP rouge : Minsk, Kazan, Kursk…), compteur de fréquence radio démarrant à 129 (AM) et incrémenté par FARP, avion ZELL `F-100D` (plus `F-104G`) en quantité illimitée (1073741823) et 10 000 000 de chaque liquide (`CTLD.lua:5529-5550`, `CTLD.lua:5800-5801`, `CTLD.lua:5830-5834`).
`FARPStock` (nombre maximal de FARP conservés dans le fichier de sauvegarde) est lu mais défini nulle part dans les scripts, donc tous les FARP vivants sont sauvegardés (`CTLD.lua:7644`).

### Mécanisme

Moose construit le groupe template `CTLD_TROOP_FOB` comme n'importe quelle cargaison de caisses ; `OnAfterCratesBuild` reconnaît le nom du template dans le nom du nouveau groupe, détruit ce groupe provisoire et appelle `BuildAFARP(coordinate, {zell=…})` (`CTLD.lua:6128-6196`).
`BuildAFARP` (`CTLD.lua:5695-5925`) :
- choisit un nom libre, crée un `ZONE_RADIUS` de Moose de 150 m ;
- appelle `UTILS.SpawnFARPAndFunctionalStatics(name, coord, ENUMS.FARPType.INVISIBLE, coalition, country, callsignNumber, frequency, AM, nil, nil, nil, 10000, 0, 0, nil, true, true, 3, 80, 80)` de Moose (`CTLD.lua:5830-5834`), c'est-à-dire pas de balise ADF, pas de template de véhicule, liquides 10000, équipement 0, cellules 0, pas de texte F10, spawn dynamique et démarrage à chaud autorisés, **3 pads** espacés de 80 m ;
  - ce que fait Moose (`Moose:4843-5001`) : avec plus d'un pad, il construit une table de groupe d'unités de catégorie `Heliports` de type `Invisible FARP` / forme `invisiblefarp` (`Moose:2030`), la première nommée `<name>` et les autres `<name>-2`, `<name>-3`, placées sur un triangle équilatéral de côté 80 m, chacune portant `heliport_callsign_id`, `heliport_frequency`, `heliport_modulation`, `dynamicSpawn`, `allowHotStart`, et le spawne avec **`coalition.addGroup(country, -1, groupData)`** (catégorie −1), puis injecte un `EVENTS.Birth` synthétique avec `world.onEvent` pour que Moose enregistre le nouvel aérodrome (`Moose:4888-4943`) ; un pad unique passerait à la place par `SPAWNSTATIC:NewFromType(type, "Heliports", country):InitFARP(…):SpawnFromCoordinate` (→ `coalition.addStaticObject`) (`Moose:4945-4949`) ;
  - `PopulateStorage` : `STORAGE:New(name)` puis `SetLiquid` de 10000 × 1000 = 10 000 000 pour le diesel, l'essence, le carburant jet et le MW50 ; l'équipement et les cellules sont laissés intacts parce que Foothold passe 0 (il les approvisionne lui-même dans `CopyWarehouse`) (`Moose:4844-4866`, `Moose:4875-4878`, `Moose:4951`) ;
  - quatre statics de service spawnés avec `SPAWNSTATIC` (→ `coalition.addStaticObject`) à 100 m du centre, espacés de 30°, face à lui : `FUEL - <name>` (`FARP Fuel Depot`), `AMMO - <name>` (`FARP Ammo Dump Coating`), `TENT - <name>` (`FARP Tent`), `WINDSOCK - <name>` (`Windsock`), tous de catégorie `Fortifications` ; ce sont les noms que le code ZELL recherche ensuite (`Moose:4952-4968`, `CTLD.lua:5618-5619`) ;
- ajoute une zone `LOAD` du CTLD de Moose dessus (`CTLD.lua:5853`) ;
- enregistre `{name, coord, seq, zell, supplyStock}` dans `BuiltFARPCoordinates` et `builtFarpSupplyRecordsByName`, et appelle `bc:registerDynamicFarp(name, coord, side)` pour que le moteur le connaisse (`CTLD.lua:5858-5877`) ;
- une seconde plus tard, `bc:CopyWarehouse(name, isFromSave)` approvisionne son entrepôt (§17) (`CTLD.lua:5887-5905`) ;
- dessine le cercle et l'étiquette avec `trigger.action.circleToAll`, `textToAll`, `setMarkupText` (`CTLD.lua:5907-5923`).
`CopyWarehouse` ajoute aussi le nom du FARP à la liste globale `supplyZones` et à `allZones`, l'enregistre auprès du script de message de bienvenue et de la persistance d'entrepôt, et rafraîchit les cibles d'entrepôt de la boutique (`zc2:20112-20141`).
ZELL : le script calcule une position à partir des relèvements des statics de munitions et de manche à air, puis spawne un groupe de type static avec `coalition.addGroup(country, -1, {units={{category="Heliports", type="Zell", shape_name="ZELL", dynamicSpawn=true, allowHotStart=true…}}})` et déclenche un `EVENTS.Birth` synthétique pour que Moose enregistre le nouvel aérodrome (`CTLD.lua:5618-5673`) ; son entrepôt reçoit `FARP_ZELL_AIRCRAFT` et `F-104G` à `FARP_ZELL_AIRCRAFT_AMOUNT` et les quatre liquides à `FARP_ZELL_LIQUID_AMOUNT` (`CTLD.lua:5590-5597`).
Compteur de supply du FARP : `GetFarpSupplyStock`, `AddFarpSupplyStock`, `ConsumeFarpSupplyStock` (`CTLD.lua:1476-1508`) ; il est débité quand un joueur y prend des zone supplies et crédité quand des supplies y sont livrées.
Le PvP ajoute la propriété (`side`, `country`, id natif de l'aérodrome), une limite de 3 FARP actifs par camp (`CTLD.lua:5708-5713`), `Airbase:autoCapture(true)` sur la nouvelle base (`CTLD.lua:5840`) et des noms rouges séparés.

### « FOB / Logistic Center »

Il n'existe pas de kit FOB séparé dans la v6.5.3 : le type de cargaison `CTLD_CARGO.Enum.FOB` de Moose n'est utilisé que comme type « site statique, ne se déplace pas » pour les kits FARP et les sites SAM (`CTLD.lua:287-327`).
`LogisticCenter` est une **propriété de zone** dans le moteur (`zoneObj.LogisticCenter == true`), pas quelque chose que les joueurs construisent avec des caisses CTLD : elle marque les zones dont l'entrepôt est la source illimitée d'armement quand `WarehouseLogistics` est actif (`zc2:115114`, `zc2:115191-115204`, §17).
Elle est posée par le fichier de setup pour les bases de départ, et les joueurs peuvent en créer une dans une zone d'aérodrome amie entièrement améliorée avec l'objet de boutique « Logistic Center [WH] », qui spawne le bâtiment `[WH]` décrit au §27 (`Setup:5921-5934`, `zc2:24155-24210`).

### Notes de reproduction

Spawner un FARP fonctionnel à l'exécution repose sur le fait que DCS accepte `coalition.addGroup(country, -1, {units = {{category = "Heliports", type = "Invisible FARP", …}}})` (plusieurs pads) ou `coalition.addStaticObject` avec un static `Heliports` (un pad) et que l'on donne un entrepôt au résultat ; l'entrepôt est ensuite accessible avec `Airbase.getByName(name):getWarehouse()` (`Moose:4903-4949`).
Les FARP créés à l'exécution ne sont pas dans `env.mission`, donc tout ce qui énumère les aérodromes au démarrage doit en être informé (les appels `RegisterExtraAirbase` / `supplyZones` / `allZones`).

## 15. Récompenses, crédit de kill et hooks de carrière

Récompenses de construction (`CTLD_BUILD_REWARD_BY_CARGO`) : FARP 100 (`Built FARP`), HAWK System 150 (`Built HAWK`), NASAMS System 150 (`Built NASAMS`), IRIS T System 200 (`Built IRIS-T`) ; le PvP ajoute Pantsir S1, SA-3, SA-8, Tor M2 à 150 (`CTLD.lua:5932-5945`).
Versées avec `bc:addContribution(player, side, reward)` et `bc:addTempStat(player, stat, 1)` seulement si le joueur a un enregistrement de contribution (`CTLD.lua:6066-6080`).
Crédit de kill pour les unités construites par des joueurs : `RegisterPlayerCtldRewardGroup(Vehicle, cargoName, playerName)` stocke, par id d'unité DCS, `{groupName, playerName, stat}` avec la statistique `CTLD <cargo> kill` (surcharges : `CTLD HAWK kill`, `CTLD NASAMS kill`, `CTLD IRIS-T kill`, `CTLD HIMARS kill`) (`CTLD.lua:5957-6028`).
Le gestionnaire de kills du moteur cherche le tireur dans `Foothold_ctld.PlayerCtldRewards.unitsById[unit:getID()]` quand le tireur est une unité au sol, et crédite le constructeur de `bc.rewards.ctldAir` (20 par défaut) ou `bc.rewards.ctldGround` (10 par défaut) via `_handleCtldRewardKill` (`zc2:42827-42845`, `Config:1923-1924`).
La sauvegarde de Moose écrit aussi le nom du constructeur à côté de chaque groupe sauvegardé (`Moose:83888`), ce qui fait revenir `PlayerName` dans `OnAfterLoaded`.
Statistiques de carrière enregistrées via `bc:recordCareerStat` / `bc:recordCareerAircraftStat` : `CtldBuilds`, `CtldUpgrades`, `FarpsBuilt`, `AirDefenseBuilt`, `AirdroppedBuilds`, `AirdroppedAirDefenseBuilds`, `TroopDrops`, `TroopCaptures`, `SupplyUnitsDelivered`, `ZoneSupplyUnits`, `FarpSupplyUnits`, `AirdroppedSupplyUnits`, `WarehouseDeliveries`, `DemolitionKills` (`CTLD.lua:4241-4271`, `CTLD.lua:6043-6064`, `CTLD.lua:6142-6144`, `CTLD.lua:6241-6251`, `CTLD.lua:8564`, `CTLD.lua:8943`, `CTLD.lua:2229`).
Le rang n'est qu'une condition d'entrée (`reqRank` passé à `bc:debit`) ; les actions CTLD alimentent le rang indirectement via les contributions et les statistiques de carrière.

## 16. Persistance des unités construites, des troupes et des FARP

### Ce que règle le créateur de mission

Exige des `io`/`lfs` dé-sanitisés ; sinon un message `CTLD_SAVE_LOAD_DISABLED_DESANITIZE` de 300 s est affiché à tous (`CTLD.lua:8153-8154`).
Fichiers (dans `FootholdSavePath` ou `<Saved Games>\Missions\Saves`) : `<base>_CTLD_Save.csv` (format Moose ; sa colonne `Structure` est aussi ce qui restaure les extensions SAM, §11), le fichier de FARP `FarpFileName`, et `<base>_CTLD_Red_Save.csv` quand le CTLD rouge existe (`CTLD.lua:8105-8110`, `CTLD.lua:8137-8146`).

### Mécanisme

Unités construites et troupes déposées : sauvegarde/chargement propre au CTLD de Moose (`enableLoadSave = true`, `saveinterval = 300`, `__Load(1)` ; `onafterSave` de Moose `Moose:83829`, `onafterLoad` `Moose:84008`), avec `eventoninject = true` pour que `OnAfterCratesBuild` / `OnAfterTroopsDeployed` se déclenchent pour les groupes restaurés, et `useprecisecoordloads = true` (`CTLD.lua:8105-8110`, `CTLD.lua:8161`).
`OnAfterLoaded` post-traite les groupes restaurés (`CTLD.lua:8163-8284`) :
- un groupe à plus de 80 NM de l'ennemi le plus proche n'est pas conservé : il est détruit et son stock rendu (`bc:_restorePointTooFarFromEnemy(point, 80)`, `CTLD.lua:8188`, `CTLD.lua:8199-8209`) ;
- les autres sont placés dans `GroundUnits` / `TroopUnits`, puis `EnforceMaxAtSpawnForTrackedUnits` supprime les plus anciens au-delà de `MAX_AT_SPAWN` et rend leur stock (`CTLD.lua:8221-8237`, `CTLD.lua:3419-3453`) ;
- toutes les caisses libres restaurées sont détruites et les caisses sont retirées de chaque `Loaded_Cargo` (seules les troupes restent chargées) (`CTLD.lua:8251-8274`) ;
- 5 s plus tard, les extensions SAM sont réappliquées (`CTLD.lua:8276-8283`).
FARP : `SaveFARPS` toutes les 300 s (la première à 30 s) écrit une ligne par FARP `seq;name;x;y;zell;lat;lon;supplyStock;` (le PvP ajoute camp et pays), conserve les `FARPStock` plus récents et renumérote `seq` à partir de 1 (`CTLD.lua:7613-7710`, timers `CTLD.lua:8099-8103`).
`LoadFARPS` s'exécute 1 s après le chargement, accepte trois formats de ligne hérités, restaure les plus récents d'abord jusqu'à `MAX_SAVED_FARPS`, et saute un FARP à plus de 60 NM de l'ennemi le plus proche (`CTLD.lua:7712-7845`, `CTLD.lua:5735-5746`).
Les entrepôts des FARP sont restaurés via `WarehousePersistence` (le FARP est enregistré comme « aérodrome supplémentaire » et sa restauration est séquencée par `BeginFarpStartupRestore` / `CompleteFarpStartupRestore`, `CTLD.lua:8098`, `CTLD.lua:7841-7844`, `zc2:20235-20242`).
`resetSaveFileAndFarp()` tronque tous les fichiers de sauvegarde CTLD et vide les tables de FARP (remise à zéro de campagne) (`CTLD.lua:8113-8152`).

### Notes de reproduction

La persistance des unités construites est entièrement le CSV de Moose plus le respawn des templates ; les ajouts de Foothold sont l'élagage par distance au front et les plafonds par type.

## 17. Système de logistique d'entrepôt (côté moteur)

### Ce que voit le joueur

Avec `WarehouseLogistics = true` (valeur livrée par défaut, `Config:1279`), les armes sont finies à chaque aérodrome/FARP sauf aux centres logistiques.
Une base fraîchement capturée a un entrepôt d'armement vide (« Neutral zones start without weapons; you must bring them or wait for AI delivery », `Config:1276-1279`) ; les joueurs l'approvisionnent avec des caisses de zone supply (+10 de chaque), des lots d'entrepôt (§9), des objets de boutique, ou attendent des livraisons IA et le remplissage automatique périodique.
Les étiquettes de zone affichent un marqueur de stock bas calculé par un « scanner de santé » en arrière-plan (`zc2:111752-111822`).
Avec `WarehouseLogistics = false`, chaque aérodrome ami est simplement réglé sur armement illimité et l'ancien menu « Load supplies » est utilisé à la place (§18).
La disponibilité des avions par base suit les listes d'époque : en Coldwar/Vietnam (et en PvP Modern avec des listes séparées), seules les cellules listées peuvent être spawnées sur une base, et la liste s'inverse quand la base change de camp (`zc2:56522-56553`).

### Ce que règle le créateur de mission (Config)

| Paramètre | Défaut | Signification | Réf. |
|---|---|---|---|
| `WarehouseLogistics` | true | stocks d'armement finis et cargaison de supply CTLD ; false = ancien mode illimité | `Config:1279` |
| `AutoFillResources` | 5 | toutes les 15 min, chaque aérodrome de zone amie non suspendue gagne ce nombre de chaque arme | `Config:1350`, `zc2:51106-51136` |
| `AIDeliveryamount` | 20 | armes de chaque type ajoutées par une mission de ravitaillement d'un hélicoptère/convoi IA (50 pour un avion de supply) | `Config:1347`, `zc2:67860-67866` |
| `NormalSupplyCapacity` / `WarehouseSupplyCapacity` | 1 / 6 | paquets de supply prêts qu'accumule une zone normale / une zone de centre logistique | `Config:1289-1294`, `zc2:52332-52341` |
| `PlayerZoneSuppliesConsumeStock` | true | les ramassages des joueurs consomment ces paquets | `Config:1337` |
| `StrictSmartWeaponsInventory`, `WarehouseWeaponCaps` | false, `{}` | les armes « intelligentes » listées reçoivent la moitié de tout réapprovisionnement | `Config:1422-1427`, `zc2:19566-19588` |
| `WarehouseWeaponsAllowedAtAirbases` | `{}` | PvE seulement : par nom de mission, id d'arme → liste des seuls aérodromes qui peuvent la stocker | `Config:1429-1434`, `zc2:51167-51230` |
| `ForbiddWeaponsInAllEra` | RN-24, RN-28 | toujours forcées à 0 | `zc2:114797-114800` |
| `restrictedWeapons`, `restrictedWeaponsVietnam` | listes (AIM-120, AIM-9X, AGM-154…) | retirées de tous les entrepôts en Coldwar/Vietnam | `zc2:114802-114812`, `zc2:114929-114939` |
| `allowedPlanes`, `allowedPlanesRed`, `allowedPlanesVietnam`, `allowedPlanesRedVietnam`, `allowedPlanesModern`, `allowedPlanesRedModern`, `AllowedWW2Planes`, `AllowedWW2RedPlanes` | listes par époque | cellules réglées sur illimité à une base selon l'époque et le propriétaire ; toutes les autres réglées à 0 | `zc2:114980-115020` |
| `restockAircraft` | liste (UH-60L, Ka-50, OH-6A, mods…) | cellules remises sur illimité à l'époque Modern | `zc2:114925-114927`, `zc2:115076-115081` |
| `AIOnlyAircraft` | liste (A-50, B-1B, An-26B…) | toujours illimitées pour que les vols IA puissent spawner depuis une base | `zc2:8-14`, `zc2:11972-11976` |
| `AllowMods` | false | Modern seulement : ajoute une catégorie d'armes `MODS` et les lots « Modded weapons » | `Config:258`, `zc2:114443-114445` |
| `PvPSeparateAircraftLists` | false | PvP : listes d'avions BLUE/RED séparées appliquées par base et par FARP | `Config:2391`, `zc2:20209-20234` |
| `zone.LogisticCenter = true` | posé dans le fichier de setup | marque les bases sources illimitées | `Setup:5922-5934` |

Règle de l'éditeur de mission énoncée dans la config : chaque entrepôt doit avoir ses avions réglés sur LIMITED, et non copiés vers tous les navires (`Config:197`) ; le moteur avertit avec `WAREHOUSE_UNLIMITED_AIRCRAFT_DETECTED` / `WAREHOUSE_UNLIMITED_WAREHOUSE_DETECTED` quand il en détecte un illimité (`zc2:114943-114961`, `zc2:115093-115106`).

### Mécanisme

**API DCS** : tout passe par `STORAGE` de Moose, une fine enveloppe : `STORAGE:New(name)` = `Airbase.getByName(name):getWarehouse()` ; `AddItem` → `Warehouse:addItem`, `SetItem` → `Warehouse:setItem`, `GetItemAmount` → `Warehouse:getItemCount`, `RemoveItem` → `Warehouse:removeItem`, `SetLiquid` → `Warehouse:setLiquidAmount` (`Moose:35734-35738`), `GetInventory` → `Warehouse:getInventory()` qui renvoie les tables des avions, des liquides et des armes (`Moose:35671-35727`, `Moose:35838-35841`).
`STORAGE:FindByName` lit le registre de stockage `_DATABASE` de Moose (`Moose:35698-35701`) ; pour les aérodromes créés à l'exécution, le moteur rectifie `storage.airbase` / `storage.warehouse` à la main (`zc2:20143-20147`, `zc2:15512-15527`).
Le moteur utilise aussi `Warehouse.getResourceMap()` (nom → 4-uplet wsType) et lit `env.warehouses.airports[id].weapons` pour les objets que la carte ne nomme pas (`zc2:51139-51149`, `zc2:114625`, `zc2:114703-114719`).
« Illimité » est représenté par la quantité 1073741823 (`zc2:20204`, `zc2:115071`).

**`WEAPONSLIST`** (`zc2:112318-114937`) : un catalogue tenu à la main `WEAPONSLIST.Items[category] = {weapon ids…}` avec les catégories `AA_MISSILES`, `AG_MISSILES`, `AG_ROCKETS`, `AG_BOMBS`, `AG_GUIDED_BOMBS`, `FUEL_TANKS`, `MISC`, `MODS` (`zc2:112323-112372`), environ 1 300 lignes d'ids plus une liste de mods séparée (`zc2:113738-114440`).
Structure du catalogue :
- Une entrée d'arme ne porte **aucun attribut** (ni nom, ni masse, ni prix, ni époque) : ce n'est qu'un identifiant, sous l'une des deux formes acceptées par l'API `Warehouse` de DCS — une chaîne de ressource telle que `'weapons.missiles.AIM-7E'`, `'weapons.nurs.ARAKM70BAP'`, `'weapons.bombs.AGM_62'`, `'weapons.droptanks.1100L Tank'`, `'weapons.containers.{GPU_5_POD}'`, `'weapons.gunmounts.A20_TopTurret_M2_L'`, ou un 4-uplet wsType tel que `{4,4,8,477}` pour les objets qui n'ont pas de chaîne de ressource (`zc2:112375`, `zc2:112559-112560`, `zc2:112953-112956`).
- La catégorie est la seule métadonnée, donnée par la liste dans laquelle l'id est écrit ; `CategoryOrder` fixe l'ordre dans lequel les catégories sont parcourues, et `ItemCategory.ALL` est une pseudo-catégorie pour « toutes les listes » (`zc2:112323-112344`).

| Catégorie | Contenu | Entrées (chaînes + uplets) | Lignes |
|---|---|---|---|
| `AA_MISSILES` | missiles air-air | 67 | `zc2:112373-112443` |
| `AG_MISSILES` | missiles air-sol, leurres, quelques armes planantes guidées | 113 + 2 | `zc2:112444-112563` |
| `AG_ROCKETS` | roquettes non guidées (`weapons.nurs.*`) | 77 | `zc2:112564-112644` |
| `AG_BOMBS` | bombes non guidées, à sous-munitions et générales | 142 + 3 | `zc2:112645-112794` |
| `AG_GUIDED_BOMBS` | bombes guidées | 40 + 1 | `zc2:112795-112840` |
| `FUEL_TANKS` | réservoirs larguables | 106 | `zc2:112841-112951` |
| `MISC` | adaptateurs, pylônes, pods, conteneurs, affûts de mitrailleuses, tout le reste | 768 + 8 | `zc2:112952-113737` |
| `MODS` | armes des mods d'avions de la communauté ; rattachée seulement quand `AllowMods` et `Era == "Modern"` | 689 + 3 | `zc2:113738-114445` |

- Cela fait donc environ 1 330 entrées dans les sept catégories de base et environ 690 de plus avec les mods (comptes faits par script sur les plages de lignes indiquées).
- Tout le reste concernant une arme vit hors de la liste, sous forme d'ensembles de noms séparés : restriction d'époque (`restrictedWeapons`, `restrictedWeaponsVietnam` → `IsRestricted`), toujours interdites (`ForbiddWeaponsInAllEra`), réapprovisionnement à moitié des « armes intelligentes » (`WarehouseWeaponCaps`), règles d'emplacement par aérodrome (`WarehouseWeaponsAllowedAtAirbases`), le multiplicateur ×3 pour toute la catégorie `AG_ROCKETS`, et un `WEAPONSLIST_MODS_CLEAR_SET` utilisé pour mettre à zéro les armes de mods quand les mods sont désactivés (`zc2:114438-114445`, `zc2:114797-114812`, `CTLD.lua:1398-1400`).
- `_flattenUnique(itemsByCategory, categories)` construit la liste plate dédoublonnée derrière `GetAllItems()`, et `_wsFilterRestricted` retire les ids restreints par époque en Coldwar/Vietnam (`zc2:114447-114484`).
`GetItems(category)` renvoie la liste, moins les objets restreints par époque en Coldwar/Vietnam ; `GetAllItems()` est la liste aplatie mise en cache ; `IsRestricted(name)` teste la liste d'époque (`zc2:114498-114517`, `zc2:114937-114939`).
`SyncFromWarehouseLogistics` s'exécute 0,1 s après le chargement : il parcourt l'inventaire des aérodromes de centres logistiques à la recherche de clés d'armes absentes du catalogue, les range dans une catégorie dérivée de leur wsType, et les met à zéro dans toutes les autres bases amies — une étape d'auto-réparation pour les nouvelles armes de DCS (`zc2:114617-114768`, `zc2:115251-115262`).
`ClearWeaponsInStorage` met chaque objet du catalogue à 0 (`zc2:114770-114787`).

**Approvisionnement initial** — `checkWeaponsList()` 1 s après le chargement (`zc2:115247-115249`, `zc2:115022-115245`) :
- Époque Modern : pour les aérodromes de centres logistiques (ou tous les aérodromes de zone quand `WarehouseLogistics` est false), chaque arme du catalogue est réglée sur illimité sauf si la zone a une installation d'entrepôt finie ; `restockAircraft` réglé sur illimité ; armes interdites à 0 (`zc2:115183-115245`).
- Coldwar/Vietnam : par aérodrome, armes restreintes retirées, puis armes réglées sur illimité seulement aux centres logistiques (ou partout si la logistique est désactivée), et l'inventaire d'avions remplacé par la liste d'époque du camp propriétaire (`zc2:115093-115181`).
- Normandie : seules les listes d'avions sont appliquées (`zc2:115023-115037`).

**À la capture / au changement de camp** (`ZoneCommander:init` et les chemins de capture) : la coalition de l'aérodrome DCS est forcée avec `Airbase:setCoalition(side)` après `autoCapture(false)` (`zc2:51439`, `zc2:51450-51476`, `zc2:56757`), un `S_EVENT_BASE_CAPTURED` synthétique est injecté (`zc2:56761-56767`), les statics de service de la base sont respawnés pour le nouveau camp (`RespawnStaticsForAirbase`), et, avec `WarehouseLogistics` actif et une zone qui n'est pas un centre logistique, **l'entrepôt d'armement est vidé** (`WEAPONSLIST.ClearWeaponsAtAirbase`, `zc2:51451-51453`, `zc2:51477-51479`, `zc2:55364-55366`).
Une zone de centre logistique tenue par BLUE est pré-remplie avec 1000 de chaque arme que la carte de ressources connaît et que le catalogue ne connaît pas (`zc2:51440-51442`, `zc2:51294-51340`) ; en PvE, un centre logistique capturé par RED perd le drapeau (`zc2:51459`).
La liste d'avions est resynchronisée par `syncColdwarAllowedPlanesAtAirbase` (`zc2:56522-56553`, appelée en `zc2:55369`, `zc2:56771`).

**Réapprovisionnements** :
- `bc:addWarehouseItemsAtZone(zone, side, amount)` est la primitive commune : `storage:AddItem` de `amount` pour chaque arme du catalogue (×3 pour les roquettes, divisé par deux pour les armes intelligentes strictes, en sautant les armes interdites, restreintes par époque et refusées par la politique), répliqué dans l'entrepôt ZELL associé s'il y en a un (`zc2:51022-51104`).
- Appelants : remplissage automatique toutes les 900 s, étalé de 0,2 s par aérodrome (`zc2:51106-51136`) ; arrivée d'un supply IA (`zc2:67860-67866`) ; caisse du mod Hercules (+10, `zc2:102425-102427`) ; objet de boutique « Resupply warehouse with 50 » (`applyWarehouseResupply`, `zc2:24300-24319`, `Config:1693`, `Config:1833`) ; activation d'un centre logistique acheté (+500 000, `zc2:46356-46369`) ; fin de capture temporisée avec une charge utile `warehouseAmount` (`zc2:24714`).
- `ManualAdjustWarehouse(zoneName, delta)` / `GroupCommander:_adjustWarehouseStock` ajoutent ou retirent une quantité fixe de chaque arme (plancher 0) — utilisés par les vols IA qui prélèvent sur une base (`zc2:59529-59581`).
- CTLD : `adjustWarehouseStockAtZone` (§9).

**`WarehouseWeaponLocationPolicy`** (`zc2:51151-51292`) : construite au démarrage à partir de `WarehouseWeaponsAllowedAtAirbases[<mission name by theatre>]` ; inactive en PvP ou quand elle est vide (`zc2:51167-51186`).
Chaque règle est `{id, key, name, allowed = {airbaseName = true}}` indexée par la clé de ressource de l'arme (`zc2:51188-51214`).
`IsDenied(policy, airbase, item)` est consultée par chaque routine d'approvisionnement ci-dessus ; `RestoreBalance` met à zéro les armes refusées au premier contact avec un entrepôt et restaure ensuite les soldes sauvegardés (`zc2:51245-51292`).
Quand une politique est active, les lots d'entrepôt CTLD passent en mode « managed » à manifeste exact (§9).

**FARP dynamiques et ZELL** — `bc:CopyWarehouse(name, fromSave)` (`zc2:20074-20244`) : malgré son nom, elle ne copie rien ; elle réessaie jusqu'à 10 fois à 2 s d'intervalle jusqu'à ce que le `STORAGE` existe, puis règle chaque arme du catalogue à 30 (roquettes 90) pour un nouveau FARP, 0 pour un FARP restauré (l'inventaire sauvegardé est ensuite chargé par `WarehousePersistence.Load`), ou illimité quand la logistique est désactivée ; règle les avions autorisés de l'époque sur illimité (listes PvP séparées : tout mettre d'abord à zéro) ; et approvisionne `AIOnlyAircraft`.
Les **porte-avions** sont exclus de la persistance d'entrepôt (`_shouldSkip`, `zc2:111508-111520`) et sont réapprovisionnés avec `checkWeaponsList(groupName)` quand le groupe du porte-avions est respawné par la fonctionnalité de navigation de porte-avions (`zc2:15512-15527`, `zc2:15569-15571`).

**`WarehousePersistence` côté logistique** : démarrée par `startWarehousePersistence()` depuis le fichier de setup (`Setup:6013`) avec chargement à +5 s, sauvegarde à +30 s puis toutes les 300 s, fichier `<base>_storage.csv` (`zc2:112302-112316`) ; elle couvre les aérodromes de zones amies hors centres logistiques plus les « aérodromes supplémentaires » enregistrés à l'exécution — FARP et ZELL de joueurs (`RegisterExtraAirbase`, `zc2:111522-111535`, `zc2:111537-111568`).
Un scanner de santé évalue une zone par seconde en tourniquet et stocke `WarehouseLowSupplies[zone] = {state, lowCategories…}` utilisé pour l'étiquette de zone (`zc2:111825-111849`).
Format de fichier : thème 02.

**Stock de « regular supply » des zones** (les paquets que consomment les joueurs) : `zone._regularSupplyReady`, `_regularSupplyExpeditedReady`, `_regularSupplyPendingStock`, `_regularSupplyStockSide` ; `_consumePlayerRegularSupplyStock(amount, side, now)` refuse quand la zone n'est pas celle du joueur, ou quand le prêt moins le réservé est insuffisant (elle essaie d'abord de libérer des permis d'envoi IA différés au profit du joueur), et renvoie combien des unités consommées étaient des unités « expedited » (`zc2:52369-52401`) ; `_restorePlayerRegularSupplyStock` les remet (`zc2:52403-52416`).
La production, l'envoi IA et les chantiers de réparation qui dépensent ce stock sont décrits au §26.

### Notes de reproduction

DCS n'offre aucun appel « lister tous les ids d'armes », d'où le catalogue manuel de 1 300 lignes et le balayage auto-réparateur d'un entrepôt de référence.
Les clés d'objets sont soit des chaînes (`weapons.missiles.AIM_120C`), soit des 4-uplets wsType ; le code normalise avec `_getWarehouseItemKey` et `ResourceKey` (`zc2:19590-19595`, `zc2:51153-51164`).
`Warehouse:setItem` sur des aérodromes spawnés à l'exécution ne fonctionne qu'une fois que l'objet aérodrome existe, d'où la boucle de nouvelles tentatives.
Chaque « réapprovisionnement » touche chaque id d'arme du catalogue sur un entrepôt (environ 1 000 appels `addItem`), ce qui explique que les réapprovisionnements soient étalés par aérodrome.

## 18. LogisticCommander : la logistique d'origine « load supplies »

### Ce qui est encore actif dans la v6.5.3

`LogisticCommander` est encore instancié par chaque fichier de setup (`lc = LogisticCommander:new({battleCommander = bc, supplyZones = supplyZones})`, `lc:init()`, `Setup:5792`, `Setup:5833`) et reste propriétaire de : le menu F10 `Logistics` par joueur, le système CSAR/sauvetage de pilote (thème 06), les handlers de naissance/décollage qui construisent tous les menus par groupe, et l'avertissement au décollage « supplies not loaded ».
Ses **commandes de chargement/déchargement de supply ne sont ajoutées que lorsque `WarehouseLogistics == false`** et que la cellule est dans `AllowedToCarrySupplies` (`zc2:101566-101585`) ; avec la valeur livrée par défaut, le même menu héberge à la place les entrées de cargaison statique CTLD (§19).
`init()` ne lance que la restauration CSAR et une boucle `update` de 10 s (CSAR) (`zc2:102273-102278`).

### Ce que voit le joueur (mode hérité)

`Logistics` → `Load supplies` / `Unload supplies` (sous-menus « Load 1 supply … Load N supplies » quand la cellule en transporte plus d'un : 2 pour le CH-47 et le Mosquito, 3 pour le Hercules et le C-130J, `zc2:97695-97707`), `List supply zones`, `Supplies Status`, `Mark Zone` (fumée sur une zone choisie) (`zc2:101566-101585`, `zc2:101757-101771`).
Le chargement n'est possible qu'au sol à l'intérieur d'une **zone de supply** amie (noms listés dans `supplyZones` du setup), à moins de 200 m d'un porte-avions, ou à l'intérieur d'une zone de FARP de joueur/d'escorte (`zc2:98075-98190`).
La cargaison est virtuelle : aucun objet n'est spawné ; l'avion reçoit 100 kg de cargaison interne par supply avec `trigger.action.setUnitInternalCargo(unitName, 100 × count)` (`zc2:98056`, `zc2:98179`).
Décharger au sol dans une zone neutre lance une capture ; dans une zone amie, cela ajoute un paquet de supply accéléré et verse `Zone upgrade` (100, ou 25 % avec `LOGISTICS_RESUPPLY_NO_DEMAND` quand la zone n'a besoin de rien) ; décharger dans la zone source rend simplement le stock ; sur un porte-avions, cela jette ; dans un FARP, cela s'ajoute au compteur de supply du FARP (`zc2:98194-98412`).
Messages : les clés `LOGISTICS_*` (`L10N:1638-1665`).

### Mécanisme

État : `self.carriedCargo[groupId] = {source, count, stockConsumed, expeditedStockConsumed}` (`zc2:98173-98178`), réinitialisé à chaque naissance (`zc2:101775`).
Le déchargement planifie une « dépose » par supply : la première après 1 s, les suivantes toutes les 3 s, chacune réévaluant la zone sous l'avion (`zc2:98319-98352`).
Zone neutre : `zone:startPendingCaptureWithCargoStatic(side, point 10–20 m behind the aircraft, country, {delivery = {handler = "zonecommander_capture_delivery", payload}})` — un vrai static de cargaison est spawné au sol comme jeton de capture (`zc2:98246-98268`).
Un `S_EVENT_LAND` synthétique est injecté 5 s plus tard pour encaisser la récompense (`zc2:98330-98346`).
Les menus sont créés 0,5 s après le `S_EVENT_BIRTH` d'une unité de joueur par `_handleBirth`, protégés par un jeton par groupe pour qu'une construction planifiée périmée soit abandonnée (`zc2:101471`, `zc2:101557-101558`, `zc2:101781`).
`pruneGroupMenus` retire chaque menu par groupe de chaque sous-système quand le joueur part, y compris en vidant les poignées de menu CTLD de Moose sur l'objet groupe (`zc2:97785-97950`, `zc2:97816-97823`).

### Relation avec CTLD

Mêmes effets sur les zones (jeton de capture, `_addExpeditedRegularSupplyStock`, compteur de supply du FARP) atteints par deux interfaces : cargaison virtuelle ici, caisses physiques suivies au §8.
Le menu Moose `Logistics` créé ici est le parent sous lequel le CTLD de Moose accroche son propre menu `CTLD` (`Moose:80799-80806`).
Avertissement au décollage : `_warnIfSupplyCarrierTakesOffEmpty` vérifie, au décollage d'une zone de supply amie ou d'un FARP avec du stock disponible, si l'avion transporte une cargaison d'action de zone (caisses CTLD ou troupes capables de capturer en mode logistique, `carriedCargo` en mode hérité) et, sinon, affiche `LOGISTICS_WARNING_NOT_LOADED` pendant 30 s avec `micclick.ogg` ; le user flag 180 non nul le désactive (`zc2:101336-101410`).

## 19. L'arborescence du menu F10 telle que la voit le joueur (mode logistique, BLUE)

```
F10 Other
└─ Logistics                                   (LogisticCommander, MENU_GROUP de Moose ; zc2:101562)
   ├─ Supplies help                            (texte de présentation de 45 s ; zc2:101591)
   ├─ Zone supplies                            (cargaison statique CTLD, par cellule ; zc2:101690)
   │   └─ <crate label + mass> → quantity sub-menu (_AddCrateQuantityMenus de Moose ; zc2:101677)
   ├─ Warehouse                                (même mécanisme ; pages de 9 avec "More")
   │   └─ 15/25/50 of everything, A/A Missiles, A/G Missiles, A/G Rockets, A/G Bombs, fuel tanks and pylons, Modded weapons
   ├─ Mark Zone → <zone names, pages of 9>     (fumée sur la zone ; zc2:101757)
   └─ CTLD                                     (Moose ; Moose:80806)
      ├─ Manage Troops
      │   ├─ Load troops → [sub-category] → <troop type> → quantity
      │   ├─ Drop Troops → Drop ALL troops | <one line per loaded group>
      │   └─ Extract troops
      ├─ Manage Crates
      │   ├─ Get Crates → <sub-category: ANTI TANK, Support, SAM/AAA, SAM Addon, FARP> → <item> → quantity
      │   ├─ Load Crates → Load ALL | Show loadable crates
      │   ├─ Drop Crates → <per crate set>
      │   ├─ Build crates
      │   ├─ Repair
      │   ├─ Remove crates → Remove crates nearby
      │   ├─ Pack → Pack | Pack and Load | Pack and Remove
      │   └─ List crates nearby
      ├─ Manage Units (C-130J only) → Get Units → <vehicle> | Remove units nearby
      ├─ List boarded cargo
      ├─ Inventory
      ├─ List active zone beacons
      ├─ Smokes, Flares, Beacons → Smoke zones nearby | Drop smoke now (red/blue/green/orange/white) | Flare zones nearby | Fire flare now | Drop beacon now
      └─ Show hover parameters  (helicopters)  /  Show flight parameters (fixed wing)
```

Références de la structure des menus : `Moose:80808-80810` (troupes), `Moose:80874-81042` (caisses), `Moose:81063-81096` (unités), `Moose:81100-81117` (entrées communes) ; libellés anglais `Moose:84621-84682`.
Les caisses de supply statiques sont enregistrées avec `DontShowInMenu = true` (6e argument de `AddStaticsCargoFromType`, `CTLD.lua:330`, `Moose:82093`), donc elles n'apparaissent pas sous `CTLD → Get Crates` ; Foothold les liste lui-même sous `Logistics` (`zc2:101588-101695`).
Les libellés d'objets portent le nombre de caisses, la masse et le suffixe de prix (`Moose:76351-76393`).
Le menu `CSAR` est une racine séparée construite dans le même handler (`zc2:101522-101553`) et réutilise `Foothold_ctld:SmokeZoneNearBy` pour « smoke/flare nearest zone » (`zc2:101532-101548`).
En PvE, les joueurs RED avec `Allow_Red_CTLD` obtiennent `Logistics → Zone supplies` adossé à `Foothold_redCtld` (`zc2:101697-101755`).

Les messages destinés aux joueurs sont listés avec chaque fonctionnalité ; les messages génériques du CTLD de Moose (troupes embarquées, caisses larguées, construction lancée, etc.) viennent de la table de localisation propre à Moose (`Moose:84600+`, non listés ici).

## 20. HercCargoDropSupply (largage par parachute du mod Hercules)

### Ce que voit le joueur

Un joueur du mod Hercules (Anubis) qui largue la `Generic Crate [20000lb]` du mod au-dessus d'une zone effectue une livraison de zone supply sans aucune interaction avec CTLD.
Les messages réutilisent `CTLD_ZONE_SUPPLIES_DELIVERED` avec `captured` / `capture started at` / `queued…` / `stocked (n/m ready) at` (`zc2:102405-102431`).

### Mécanisme

Le gestionnaire de tirs du moteur transmet à `HandleShot` les armes dont le nom de type figure dans `HercCargoDropSupply.allowedCargo` (`weapons.bombs.Generic Crate [20000lb]`) (`zc2:42927-42928`, `zc2:102297-102298`) ; l'événement est le `S_EVENT_SHOT` de DCS (`zc2:42921`).
L'arme-caisse est scrutée toutes les 0,2 s avec `timer.scheduleFunction` jusqu'à passer sous 5 m AGL (`zc2:102307-102318`, `zc2:102444-102457`).
`ProcessCargo` : trouve la zone sous l'arme (`bc:getZoneOfWeapon`) ; ignore le largage (et détruit la caisse) si l'avion n'a pas de zone de décollage enregistrée ou largue dans sa zone de décollage (`herculesRegistry[unitName].takeoffzone`, posé au décollage par `_updateHerculesTakeoffZone`, `zc2:101322-101334`, `zc2:102356-102361`).
Zone neutre → `startPendingCaptureWithCargoStatic(side, point, country, {staticType = "iso_container_small", mass = 4000, delivery = {…, warehouseAmount = 10}})` (`zc2:102378-102403`).
Zone amie → `_addExpeditedRegularSupplyStock(1)`, 150 crédits (`Zone supply delivery`), et +10 de chaque arme si la logistique est active (`zc2:102410-102427`).
L'objet arme est détruit ensuite (`zc2:102438`).
Si le largage a été fait au sol, un événement d'atterrissage synthétique est planifié 5 s plus tard (`zc2:102320-102349`).
`HercCargoDropSupply.init(bc)` est appelée depuis le fichier de setup (`Setup:6001`).
La config note que le mod Hercules ne peut pas être inclus dans l'avertissement au décollage parce que sa cargaison générique ne peut pas être détectée (`Config:1417`).

## 21. ExternalHeloCargoRoute (pour ce qui concerne les joueurs)

C'est un auxiliaire réservé à l'IA : des constructeurs pour les tâches d'hélicoptère DCS `ExternalCargoLoad` (`unitIdTransport`, cargaison `groupId`/`unitId`) et `ExternalCargoUnLoad` (`zoneId`), une tâche d'orbite en racetrack, et des générateurs de waypoints pour les hélicoptères de supply IA qui transportent une cargaison visible sous élingue (`zc2:58056-58081`, `zc2:58083-58240`), utilisés quand `SuppliesCargoTransport` est vrai (`Config:1344`, sites d'appel `zc2:58648`, `zc2:59354`).
Les joueurs ne le déclenchent jamais ; ce qu'ils voient est un CH-47 ou un Mi-8 IA portant une caisse sous élingue, et son arrivée a le même effet sur l'entrepôt que « l'arrivée d'un supply IA » du §17.
Détails : thème 03.

## 22. CTLD Rouge (`Foothold_CTLD_Red.lua`)

Chargé seulement quand `Allow_Red_CTLD == true` (false par défaut, `Config:1963`) ou que le PvP est activé (`CTLD_Red.lua:5`).
Une seconde instance Moose `Foothold_redCtld = CTLD:New(coalition.side.RED, prefixes, "Red Logistics")` avec les préfixes `Mi.8MT`, `Hercules`, `Ми.8МТВ2`, `Ми.24П`, `Mi.24P` (+ `C.130J.30` en PvP) et les mêmes valeurs d'options que BLUE (`CTLD_Red.lua:40-88`).
Catalogue (`CTLD_Red.lua:784-815`) : troupes `Squad 4 AK47`, `Squad 8 AK47` ; caisses (2 chacune) `Scout BRDM 2`, `Ammo Truck`, `Arty SPH 253 Akatsia 8 NM`, `Truck with ZU-23`, et hors Vietnam `Arty SPM 259 Nona 3 NM`, `ATGM AT-3 SAGGER`, `Kord 12.7 MM`, `MLRS LC 80 MM 2.2 NM`, `MRAP M-ATV` ; `SA-8` (2 caisses) et `SA-3 SAM system` (4 caisses) si ces templates rouges sont activés ; `Tor M2` (PvP Modern) ; sous-menus `Support`, `ARTY`, `SAM/AAA`, `ANTI TANK`, `LIGHT ARMOR` ; stock 6 (PvE) ou 10–12 (PvP).
Prix : `RedCTLDPrices`, défauts PvE de 100 (squad, Kord) jusqu'à 5000 / rang 8 (SA-3) (`CTLD_Red.lua:122-136`) ; le PvP utilise les `CTLDPrices` partagés avec des entrées rouges (25–750) (`CTLD_Red.lua:96-120`, `Config:2035-2058`).
Zone supplies : `Red zone supplies C-130J / MI-8 / Mi-24P` (`CTLD_Red.lua:818-820`) avec sa propre boucle de suivi plus simple `tickRedZoneSupply` toutes les 5 s (`CTLD_Red.lua:2218`, `CTLD_Red.lua:1895-2216`) et son propre handler de fin `completePendingRedCtldSupply` (`CTLD_Red.lua:1437`).
Boucle de suivi rouge en détail (`redCtldProcessZoneSupply`, `CTLD_Red.lua:1895-2207`), exécutée pour chaque caisse suivie par `tickRedZoneSupply` sur un `TIMER` de Moose démarré à 15 s avec une période de 5 s, qui retourne immédiatement quand aucune caisse n'est suivie et reconstruit le cache « supplies à bord » à la fin (`CTLD_Red.lua:2209-2218`) :
- caisse signalée à bord par Moose, ou trouvée à l'intérieur de la boîte du porteur → marquée chargée ; static disparu alors que le porteur existe encore → toujours à bord ; static disparu sinon → entrée retirée (`CTLD_Red.lua:1896-1924`) ;
- premier mouvement de la caisse → `CTLD_CRATE_LOADED_GROUND_CREW`, `wasAirborne = true` ; une fois qu'elle a bougé, « déchargée » est décidé à partir du porteur : au sol, caisse plus loin que le `detach`/`width` de la cellule (cargaison interne, `ropelength == 0`) ou hors de `width`/`height` (sling) ; en vol, plus loin que `detach` en 3D ou hors de la boîte `width × ropelength × width` ; sans porteur, caisse à ≤ 0,5 m AGL (`RED_ZONE_SUPPLY_AGL_THRESHOLD`) (`CTLD_Red.lua:1931-1981`, `CTLD_Red.lua:863`) ;
- une caisse est « au sol » à ≤ 0,5 m AGL ou une fois déchargée et immobile ; sa zone est résolue d'après sa position ; hors de toute zone, elle est revérifiée toutes les 60 s et abandonnée après 600 s (`RED_ZONE_SUPPLY_NOZONE_RECHECK`, `_TTL`) (`CTLD_Red.lua:1984-1989`, `CTLD_Red.lua:2042-2051`, `CTLD_Red.lua:864-865`) ;
- PvP, caisse sur un FARP rouge construit par un joueur : une caisse de zone supply ajoute 1 au compteur de supply du FARP (150 crédits, `Zone supply delivery`) ou est remboursée si elle venait de ce FARP ; une caisse d'entrepôt est réglée dans le stockage du FARP (`CTLD_Red.lua:1990-2040`) ;
- caisses d'entrepôt PvP dans une zone : réglées avec `Foothold_ctld.ApplyWarehouseDebitItems(storage, cargo, zone, "delivery" | "return")`, récompense = le `reward` du lot (sinon 100 pour un lot multi-catégories, 50 pour un lot à catégorie unique), statistique `Warehouse delivery` ; détruites avec une raison dans une zone ennemie, quand la logistique est désactivée, ou quand aucun stockage n'existe ; laissées en attente dans une zone neutre (`CTLD_Red.lua:2053-2118`) ;
- caisse de zone supply revenue dans sa zone de ramassage → stock remboursé (`CTLD_SUPPLIES_RETURNED_TO_ZONE`) ; dans une zone BLUE → détruite (« enemy zone ») ; dans une zone neutre → `zone:startPendingCapture(RED, {kind = "static", …, delivery = {handler = "red_ctld_capture_delivery", payload}})` ; dans une zone RED → `zone:_addImportedRegularSupplyStock(1, now)` et `redCtldFinalizeDelivery(…, "CTLD_ZONE_SUPPLY_ACTION_STOCKED", "Zone supply delivery", 150, {ready, max})` (`CTLD_Red.lua:2120-2206`).
Différences avec la boucle BLUE (§8) : pas de cadence séparée pour le C-130J ni de confirmation d'atterrissage unique, pas de « file de prêtes » sérialisée (chaque caisse est appliquée dans la passe qui la voit), pas de lot d'entrepôt automatique lors d'une livraison de zone supply, et le stock ajouté est une unité « importée » plutôt qu'une unité « expedited » (`CTLD_Red.lua:2194`, `CTLD.lua:5366-5371`).
Zones : `addCTLDZonesForRedControlled` reprend le §4 avec les camps échangés ; les noms de zones contenant `hidden`, `dropzone`, `carrier` ou `fob alpha` ne sont pas enregistrés (`CTLD_Red.lua:2220-2235`, `CTLD_Red.lua:2237-2274`).
Persistance : `<base>_CTLD_Red_Save.csv`, mêmes options Moose (`CTLD_Red.lua:2276-2318`).
En PvP, il emprunte les implémentations BLUE en affectant les fonctions (`CanBuildCrates`, `OnAfterTroopsDeployed`, `OnAfterTroopsPickedUp`, registre des récompenses, enregistreurs de carrière…) (`CTLD_Red.lua:2297-2316`), clone les templates de FARP sous les noms `CTLD_TROOP_FOB_RED` / `CTLD_TROOP_FOB_ZELL_RED` sous le pays RUSSIA (`CTLD_Red.lua:765-782`), et copie les lots « Warehouse » de BLUE (`CTLD_Red.lua:822-836`).
Restrictions PvP par FARP : au plus 3 FARP actifs par camp (`CTLD.lua:5708-5713`), propriété du FARP vérifiée par camp et id natif d'aérodrome à chaque ramassage (`CTLD.lua:6715-6720`), et les entrepôts de FARP/ZELL ne reçoivent que la liste d'avions du propriétaire (`zc2:20209-20234`, `CTLD.lua:5590-5593`).

## 23. Récapitulatif des paramètres de configuration (CTLD et logistique)

| Paramètre | Défaut | Réf. |
|---|---|---|
| `CTLDCost` | true (false = tout est gratuit) | `Config:1959` |
| `Allow_Red_CTLD` | false | `Config:1963` |
| `MaxTroopsRunDistanceTowardZone` | 5000 m | `Config:1967` |
| `CTLDCargoTrackingInterval` | 3 s (borné à 3–6) | `Config:1971`, `CTLD.lua:9437` |
| `CTLDPrices` | table `{available, price, reqRank}` par objet | `Config:1975-2058` |
| `MAX_AT_SPAWN` | plafond de restauration par objet | `Config:2063-2147` |
| `CaptureZoneWithEngineer` | false | `Config:2150` |
| `MAX_SAVED_FARPS` | 3 | `Config:2155` |
| `IRIS_RESTORE_UNIT_HEALTH_ON_MERGE` | false | `Config:2161` |
| `CTLDUnitCapabilities` | table par cellule | `Config:2176`, `CTLD.lua:453-476` |
| `UseC130LoadAndUnload` | true ("C-130J-30 and Chinook use the internal ground-crew loading system only") | `Config:1339-1340` |
| `UseStatics` | true | `Config:515` |
| `WarningNoSupplies`, `ZoneSupplyTakeoffWarningTypes` | true, par cellule | `Config:1389-1418` |
| `AllowedToCarrySupplies` (mode hérité seulement) | par cellule | `Config:1365-1367` |
| `rewards.ctldGround`, `rewards.ctldAir`, `Warehouse delivery` | 10, 20, 150 | `Config:1923-1924`, `Config:1935` |
| boutique : `zwh50` "Resupply warehouse with 50", `farphere` "Deploy FARP", `supplies2` "Resupply friendly Zone" | prix 500, 1000, 200 | `Config:1792-1839` (thème 05) |
| paramètres d'entrepôt | voir le tableau du §17 | |

## 24. Dispositifs de performance

- Un seul timer pour les deux cadences de caisses ; rien ne tourne quand aucune caisse n'est suivie (`if not next(zoneSupplyCrates) then return`) (`CTLD.lua:4191-4202`, `CTLD.lua:9418-9438`).
- Les livraisons prêtes et le traitement des captures sont sérialisés avec 3 à 5 s entre deux éléments ; ré-entrance protégée par les drapeaux `zoneSupplyProcessRunning` / `captureRunning` et un drapeau « queued » (`CTLD.lua:5375-5476`, `CTLD.lua:8968-8996`).
- Les suppressions de statics sont mises en file avec une échéance et vidées par un seul timer qui se replanifie (`CTLD.lua:4378-4453`).
- Les caisses hors de toute zone ne sont recherchées que toutes les 60 s (`_noZoneNextCheckAt`), et le limiteur est levé quand une nouvelle zone de FARP apparaît (`CTLD.lua:4817-4820`, `CTLD.lua:3061-3067`, `zc2:20129-20131`).
- Caches : poignée de stockage par zone, liste d'armes par catégorie, enveloppe de zone Moose par nom, unité porteuse et dimensions de cellule par caisse, drapeau « à bord » par groupe (`CTLD.lua:1390-1392`, `CTLD.lua:3858-3902`, `CTLD.lua:1522-1529`, `CTLD.lua:2984-3015`, `CTLD.lua:3130-3139`).
- Le déclencheur d'entrée en zone des troupes lit la position de chaque groupe une fois par passe, saute les groupes terminés, et s'arrête de lui-même quand plus aucune troupe déployée n'est vivante (`CTLD.lua:8293-8398`).
- Le réapprovisionnement du stock est sauté tant qu'une construction est en cours (`CTLD.lua:9332-9334`).
- Les réapprovisionnements d'entrepôt sont étalés de 0,2 s par aérodrome ; le scanner de santé traite une zone par seconde (`zc2:51118-51129`, `zc2:111839-111847`).
- Les constructions de menus sont différées de 0,5 s après la naissance et invalidées par un jeton par groupe (`zc2:101557-101558`).

## 25. Fonctionnalités du CTLD Moose de base sur lesquelles s'appuie Foothold (pour une comparaison ultérieure avec un autre CTLD)

Uniquement les fonctionnalités, chacune avec l'endroit où Foothold l'utilise.

- Instance par coalition filtrée par préfixes de noms de groupe, avec table de capacités par cellule (peut transporter des caisses, des troupes, limite de caisses, limite de troupes, longueur, masse maximale de cargaison) (`CTLD.lua:104`, `CTLD.lua:474-476`).
- Cargaison de troupes à partir de groupes template en late activation, avec places, masse par homme et stock (`CTLD.lua:264-277`).
- Cargaison de caisses construisant un groupe template à partir de N caisses, avec masse par caisse, stock, sous-catégorie, restriction de cellule optionnelle, type/forme de static de caisse (`CTLD.lua:280-327`).
- Variante « NoMove » (le groupe construit reste en place) contre variante mobile (le groupe construit se dirige vers la zone MOVE la plus proche) (`CTLD.lua:284-313`).
- Unités entières à chargement direct pour le C-130J (`AddUnits`) (`CTLD.lua:315-323`).
- Cargaison statique créée à partir d'un type de static DCS, non constructible, restreinte à certaines cellules, masquée du menu standard (`CTLD.lua:330-367`).
- Type de troupe ingénieur (`CTLD_CARGO.Enum.ENGINEERS`) et entrée de menu de caisses de réparation (`CTLD.lua:268`, `Moose:81027`).
- Types de zones LOAD, MOVE, SHIP (et DROP, UNLOAD, BEACON existent mais ne sont pas utilisés par Foothold), avec activation/désactivation à l'exécution, couleur de fumée, dimensions de navire (`CTLD.lua:483-538`).
- Comptabilité de stock par cargaison (`AddStock*`, `RemoveStock*`, `GetStock`, `GetStock0`) et le compte combiné « stock + dans l'avion + groupes vivants » (`CTLD.lua:9335-9366`).
- Hooks de veto avant l'action : `CanGetTroops`, `CanGetCrates`, `CanGetUnits`, `CanBuildCrates`, `CanUnloadAllTroops` (`Moose:77542`, `Moose:78104`, `Moose:78230`, `Moose:79313`, `Moose:79580`).
- Événements FSM après l'action : `TroopsPickedUp`, `TroopsDeployed`, `TroopsExtracted`, `GetCrates`, `CratesPickedUp`, `CratesDropped`, `CratesBuildStarted`, `CratesBuild`, `CratesPacked`, `RemoveCratesNearby`, `Loaded`, `HelicopterLost` (`CTLD.lua:6087`, `CTLD.lua:6119`, `CTLD.lua:6964`, `CTLD.lua:7094`, `CTLD.lua:7215`, `CTLD.lua:7520`, `CTLD.lua:8163`, `CTLD.lua:8430`, `CTLD.lua:8535`).
- Construction avec un timer (`buildtime`), construction depuis un groupe « ingénieur » non joueur (`_BuildCrates(group, unit, true, true, notifyGroup)`), règle d'interdiction de construire en zone de chargement (`CTLD.lua:159`, `CTLD.lua:153`, `CTLD.lua:3689-3691`).
- Replier un groupe construit en caisses (Pack / Pack and Load / Pack and Remove) (`CTLD.lua:145`, `CTLD.lua:7520-7611`).
- Modes de chargement : chargement au sol portes ouvertes, fenêtre de chargement en vol stationnaire, sling load, cargaison dynamique DCS (équipe au sol, CH-47, C-130J) avec les événements `NewDynamicCargo` / `DynamicCargoLoaded` / `DynamicCargoUnloaded` / `DynamicCargoRemoved` (`CTLD.lua:143-158`, `Moose:83559-83562`).
- Largage par parachute de troupes et de caisses depuis une voilure fixe avec hauteur minimale et vitesse maximale (`CTLD.lua:149-151`).
- Extraction de troupes (reprendre des troupes déployées) (`Moose:77729` ; utilisée par l'extraction de l'espion/des démolisseurs).
- Troupes déposées et véhicules construits qui se déplacent vers la zone MOVE la plus proche dans une certaine distance, avec une liste de formations (`CTLD.lua:162-166`).
- Menus en une étape avec sous-menus de quantité, menus de sous-catégories, libellé de prix et suffixe de stock dans les entrées de menu, résolveur de locale par groupe et table de textes surchargeable (`CTLD.lua:133-141`, `CTLD.lua:157`, `CTLD.lua:163`).
- Sauvegarde/chargement des troupes déposées et des groupes construits en CSV avec intervalle, API d'« injection » (`InjectTroops`, `InjectVehicles`, `InjectStatics`) et événements déclenchés au chargement (`CTLD.lua:8105-8110`, `CTLD.lua:8161`).
- Fumée/fusée éclairante sur la zone la plus proche, fumée sur sa propre position, balises radio aux zones et balise larguable avec timeout, affichage des paramètres de vol stationnaire/de vol, listes de cargaison et d'inventaire (`CTLD.lua:148`, `CTLD.lua:161`, `Moose:81100-81117`).
- Helpers de recherche utilisés par Foothold : `IsUnitInZone`, `_FindCratesCargoObject`, `_FindTroopsCargoObject`, `GetGenericCargoObjectFromGroupName`, `IsC130J`, `Loaded_Cargo`, `DroppedTroops`, `Spawned_Cargo`, `C130GetUnits` (`CTLD.lua:6713`, `CTLD.lua:6099`, `CTLD.lua:2822`, `CTLD.lua:7193`, `CTLD.lua:8251-8273`).
- Autres classes Moose utilisées autour de CTLD : `SET_GROUP`, `SET_ZONE` (avec sa FSM `Trigger`), `SET_CLIENT`, `ZONE` / `ZONE_RADIUS`, routage de `GROUP` (`RouteGroundTo`, `Route`, `TaskFunction`), `COORDINATE`, `STORAGE`, `AIRBASE`, `STATIC`, `MESSAGE`, `USERSOUND`, `MENU_GROUP`, `SCHEDULER`, `TIMER`, `UTILS.SpawnFARPAndFunctionalStatics`, `UTILS.SaveToFile` / `LoadFromFile`.

## 26. Économie du « regular supply » des zones : production, stock, envoi IA, récupération locale

C'est le modèle côté moteur derrière le chiffre `[SUP] n/max` de l'étiquette d'une zone : chaque zone possédée fabrique lentement du « supply prêt », qui est dépensé par les joueurs (caisses de zone supply, §8), par les vols de supply IA vers d'autres zones, et par les propres chantiers de réparation et d'amélioration de la zone.
Les citations du manuel viennent de `Foothold Manual v2.7.pdf` §3.5 « Supply Missions, Production, and Recovery » (p. 36) et du chapitre Config Manager.

### Ce que voit le joueur

- Étiquette de zone : `[SUP] n/max [■■□□□] p%` pendant la production, `[Supplies] n/max` quand la cible est atteinte, `[Supplies] n` pour une zone qui détient du stock mais ne peut pas produire ; la barre a 5 cases ; la progression BLUE est affichée par pas de 1 %, RED par pas de 10 % (`zc2:52471-52491`, `zc2:52433-52441`).
- L'étiquette nomme aussi les chantiers en cours (« Building: Armor -- 57% », « Repairing », « Training » pour l'infanterie) et affiche « Resupply! » quand une zone BLUE a moins de stock prêt que son travail restant n'en demande (manuel p. 30).
- Constructeur d'étiquette (`_regularSupplyLocalRecoveryLabelText(intelViewerSide, includeMissing, jobs)`, `zc2:52575-52635`) : pour le propriétaire, une ligne par chantier visible, `ZONE_UPGRADE_REPAIRING_PERCENT` pour une réparation (`ZONE_UPGRADE_TRAINING_PERCENT` quand l'emplacement est de l'infanterie) et `ZONE_UPGRADE_BUILDING_PERCENT` pour une reconstruction ou une installation, avec le nom d'affichage de l'emplacement et `percent = elapsed ÷ duration` ; les réparations viennent en premier, et la dernière ligne de réparation est suffixée par la santé du groupe le plus endommagé (« • n% »).
- Sans chantier en cours, le constructeur se rabat sur un résumé des emplacements d'amélioration : noms « missing » (sur demande), noms « repair needed » (les groupes déjà en réparation sont exclus), ou nom de la prochaine amélioration à construire ; les emplacements identiques sont groupés en « name ×n » (`_upgradeDisplaySummaryText`, `zc2:52527-52573`).
- Pour l'ennemi, la même fonction est appelée avec `intelViewerSide` : les chantiers RED ne sont montrés que via l'intel, sous la forme « <famille SAM> repairing / installing n% » ou « defences repairing / installing n% » (`zc2:52581-52602`).
- Quand l'IA s'apprête à envoyer des supplies hors d'une zone, les joueurs BLUE au sol dans cette zone, dans un avion capable de transporter des zone supplies, reçoivent « <zone>: Supplies are ready and will be dispatched to <target> in 30 seconds. » — la fenêtre dans laquelle ils peuvent prendre eux-mêmes le paquet (`zc2:53746-53793`, `L10N:1650`).
- Perte d'une sortie de supply IA : « We have lost a supply helicopter / aircraft / convoy from <zone>. » (`zc2:54192-54199`, `L10N:2188-2190`).
- La récupération des SAM RED est annoncée à BLUE avec l'une des 3 variantes aléatoires par événement : construction commencée (famille, zone, minutes), réparation commencée, terminée (`RED_SAM_<EVENT>_<1..3>`, `zc2:53229-53238`, `zc2:53454-53458`).
- `F10 > Stats and Settings > AI Logistics (Currently …)` bascule les livraisons IA régulières de BLUE quand `RadioMenuStopSupplies` est vrai ; chaque joueur BLUE est informé de qui a basculé (`zc2:52108-52160`, `Config:1361-1363`).

### Ce que règle le créateur de mission

| Paramètre | Défaut | Signification | Réf. |
|---|---|---|---|
| `NormalSupplyCapacity` | 1 (1–3) | cible de production automatique d'une zone normale | `Config:1286-1289`, `zc2:8484` |
| `WarehouseSupplyCapacity` | 6 (3–6) | cible de production automatique d'une zone `[WH]` (centre logistique) | `Config:1291-1294`, `zc2:8485` |
| `GlobalSettings.supplyDifficultyScaling = {[1]=1.0, [2]=1.0}` | 1.0 / 1.0 | multiplicateur du temps de production et des timers de missions de supply IA, par camp (0.5 = deux fois plus vite) | `Config:1301-1310`, `zc2:52425-52430` |
| `GlobalSettings.repairDifficultyScaling = {[1]=1, [2]=1}` | 1 / 1 | multiplicateur du temps de réparation / reconstruction / installation, par camp (plancher 0.1) | `Config:1312-1325`, `zc2:8486-8491` |
| `ExtraRedRepairTimeLowPlayerCountPercent` | 0 (0–50) | temps de réparation/construction RED supplémentaire quand moins de 2 joueurs BLUE en CAS sont présents, appliqué une fois au début du chantier | `Config:1327-1332`, `zc2:53254-53256` |
| `PlayerZoneSuppliesConsumeStock` | true | un ramassage de joueur retire un supply prêt | `Config:1334-1337` |
| `NoAIBlueSupplies` | false | désactive définitivement les livraisons IA régulières de BLUE (et la production dans les zones qui ne produisent que par des routes IA) | `Config:1352-1354`, `zc2:52172` |
| `NoAIBlueCapture` | false | pas d'envoi automatique de capture BLUE vers les zones neutres (PvE) | `Config:1356-1359`, `zc2:54275-54277` |
| `RadioMenuStopSupplies` | false | donne aux joueurs la bascule AI Logistics | `Config:1361-1363` |
| `pvp_supplies` | true | PvP : quand false, les supplies IA ne tournent que lorsqu'ils sont achetés | `Config:320-322`, `zc2:54204-54206` |

Constantes du moteur (posées dans un bloc `do` au chargement, pas dans la Config) : production de 20 min par supply dans une zone normale et 10 min dans une zone `[WH]`, délai de priorité joueur 30 s, 2 livraisons payées maximum par zone cible, base de récupération locale 15 min (normale) / 5 min (`[WH]`), temps d'unité de réparation 1 min (RED) / 2 min (BLUE), temps d'unité de capteur 3 min (les deux), durée maximale d'un chantier 20 min, nouvelle tentative de permis 60 s, 2 envois par tick (`zc2:8480-8504`).

Délais tels que l'énonce le manuel (p. 36), qui correspondent au code ci-dessus :
- production : un supply prêt toutes les 20 minutes dans une zone normale, toutes les 10 minutes dans une zone `[WH]`, avec Supply Speed Scaling à 1.00 et à pleine efficacité ; les groupes d'amélioration manquants ou endommagés ajoutent un retard plafonné à 10 minutes ; la production se met en pause quand aucun groupe d'amélioration n'est opérationnel, et s'arrête à la cible automatique (pas une limite de stockage) ;
- réparation/installation BLUE : base de 15 minutes dans une zone normale ou de 5 minutes dans une zone `[WH]`, plus 2 minutes par unité normale manquante ou 3 minutes par unité SR/TR/STR manquante ; les supplies apportés par les joueurs, CTLD, par largage, « Add 3 supplies » et « Resupply friendly zone » sautent le temps de base ;
- réparation/installation RED (PvE) : pas de temps de base (RED doit d'abord recevoir une livraison), 1 minute par unité normale manquante, 3 minutes par unité SR/TR/STR manquante ;
- chaque chantier est plafonné à 20 minutes à un scaling de 1.00, et le plafond suit le Repair Time Scaling ;
- jusqu'à deux chantiers par zone à la fois ; chaque chantier BLUE consomme un supply stocké ; le stock, la progression de production et la progression des chantiers survivent à un redémarrage.

### Mécanisme

État par zone (champs de `ZoneCommander`) : `_regularSupplyStockSide`, `_regularSupplyReady`, `_regularSupplyExpeditedReady` (la part du stock prêt qui a été apportée plutôt que produite), `_regularSupplyProgress` (secondes accumulées vers le prochain supply), `_regularSupplyLastUpdateAt`, `_regularSupplyPendingStock` (unités prêtes réservées par des permis d'envoi IA), `_regularSupplyEfficiency`, `_regularSupplyLossDelays`, et jusqu'à deux chantiers de récupération locale (`zc2:52343-52366`, `zc2:53687-53743`, `zc2:52494`).

**Tick** : `bc:_updateRegularSupplyStock(now)` puis `bc:_dispatchRegularSupplyStock(now)` sont appelées une fois au début de chaque cycle de mise à jour des zones du `BattleCommander` (`zc2:43251-43252`) ; il n'y a pas de timer dédié.

**Qui peut stocker et qui peut produire** (`_regularSupplyHasRouteForSide`, `zc2:52163-52191`, `zc2:53690-53692`) :
- une zone peut stocker quand elle est active, non cachée, RED ou BLUE ;
- elle peut produire quand c'est un centre logistique (BLUE, ou le propriétaire en PvP), ou que son nom figure dans la liste `supplyZones` du setup, ou qu'elle possède au moins un `GroupCommander` de supply de son camp qui n'est pas réservé à la boutique (c'est-à-dire qu'elle a une route de supply IA) ; avec `NoAIBlueSupplies`, une zone BLUE du troisième cas ne produit pas.
- Quand le propriétaire change (ou que la zone ne peut pas stocker), le stock, la part expedited et la progression sont remis à 0 (`zc2:53695-53702`).

**Production** (`ZoneCommander:_updateRegularSupplyStock`, `zc2:53713-53741`) :
- `interval = baseSeconds × supplyDifficultyScaling[side]`, base 1200 s (normale) ou 600 s (centre logistique) (`zc2:52418-52430`) ;
- `conditionDelay = 600 s × scale × (1 − efficiency)` et `productionRate = interval / (interval + conditionDelay)` ; taux 0 quand l'efficacité est 0 ;
- `progress += elapsed × productionRate` ; chaque fois que `progress >= interval` et que le stock est sous le maximum, un supply devient prêt ; la progression est remise à zéro au maximum.
- Efficacité = capacité opérationnelle ÷ nombre d'emplacements d'amélioration de la zone, bornée à 0–1 (`_commitRegularSupplyEfficiency`, `zc2:52314-52329`).
- La capacité opérationnelle est sommée par la passe de maintenance des groupes construits de la zone quand la zone est marquée « sale » (unité perdue, ensemble d'améliorations modifié) : chaque groupe construit avec une unité vivante compte `min(1, living units ÷ initial group size)`, chaque static vivant compte 1, et les groupes retirés par reddition sont soustraits (`zc2:55908-55914`, `zc2:55968-55970`, `zc2:55696-55697`, `zc2:55555`, `zc2:52291-52311`).
- Maximum (la cible automatique) : `WarehouseSupplyCapacity` pour un centre logistique, `NormalSupplyCapacity` sinon, et un 3 fixe pour une zone RED PvE qui a un bâtiment d'entrepôt opérationnel (`zc2:52332-52341`).

**Ajout de stock** :
- `_addImportedRegularSupplyStock(n)` : simple +n sur le stock prêt, **sans limite supérieure** (les livraisons peuvent dépasser la cible ; la production reste alors en pause) (`zc2:52343-52358`) ;
- `_addExpeditedRegularSupplyStock(n)` : pareil, et les unités sont marquées expedited, ce qui fait sauter le temps de base au chantier qu'elles paient (`zc2:52360-52367`, `zc2:52863-52870`) ;
- appelants : caisse CTLD BLUE → expedited (§8), caisse CTLD RED → imported (§22), largage Hercules et déchargement hérité → expedited (§18, §20), `zsup3` de la boutique et `supplies2` scripté → expedited (`zc2:24289`), arrivée d'une livraison IA → `_applyRegularSupplyDelivery`.

**Arrivée d'une livraison IA** (`bc:_applyRegularSupplyDelivery(zone, side, now, paidStockpile)`, `zc2:53286-53310`) :
- une livraison « stockpile » `supplies2` payée → +1 expedited ;
- BLUE (et RED en PvP) → +1 imported : la livraison ne fait que remplir le stock, la zone le dépense ensuite elle-même ;
- RED en PvE → pas de stock : la livraison lance immédiatement un chantier de récupération RED sur le premier candidat à la réparation, sinon sur le premier candidat à l'amélioration, sinon appelle `zone:upgrade()` ; chaque livraison RED réussie donne aussi 100 crédits à la coalition RED.

**Chantiers de récupération locale** (2 au maximum par zone, `REGULAR_SUPPLY_LOCAL_RECOVERY_MAX_JOBS = 2`) :
- candidats (`_regularSupplyLocalRecoveryCandidates`, `zc2:52908-52970`) : pour chaque emplacement d'amélioration dans l'ordre des index, un groupe construit auquel il manque des unités est un `repair` (ou un `rebuild` s'il n'en reste rien) ; un emplacement pas encore construit est un `upgrade` ; les statics, les groupes « dismounted » et les emplacements déjà réservés par un chantier sont sautés ; « manquant » est le nombre d'unités du template moins la taille du groupe vivant, les capteurs (SR/TR/STR) étant comptés à part (`_regularSupplyRepairFacts`, `zc2:52637-52690`) ;
- choix (`_selectRegularSupplyLocalRecoveryTarget`) : quand les deux sortes sont en attente et qu'un chantier tourne déjà, le second chantier prend l'autre sorte, si bien qu'une zone répare et construit en parallèle ; sinon les réparations d'abord (`zc2:52972-53010`) ;
- démarrage BLUE (`_startRegularSupplyLocalRecovery`) : exige `ready − pending ≥ 1`, un emplacement libre et une cible ; prend un supply prêt (un expedited en premier), et crée `{side, action, targetName, targetIndex, durationSec, startedAt, completeAt, usesExpeditedSupply, recoveryBaseSec, showLabel}` ; les chantiers démarrent automatiquement à chaque tick tant que le stock et les emplacements le permettent (`zc2:53180-53227`, `zc2:53660-53679`) ;
- durées : réparation = `min(max × scale, (base + normalMissing × unitSec + missingSensors × sensorSec) × scale)` ; construction = pareil en comptant toutes les unités du template ; `base` vaut 0 pour un supply expedited et pour RED (`zc2:52863-52906`) ;
- démarrage RED (`_startRedRegularSupplyLocalRecovery`) : aucun supply stocké, pas d'étiquette, majoration optionnelle pour faible nombre de joueurs, messages SAM à BLUE (`zc2:53241-53284`) ;
- fin (`_finishRegularSupplyLocalRecovery`) : revalide la cible, puis `zone:upgrade(silent, targetName)` pour une réparation/reconstruction ou `zone:upgrade(silent, nil, targetIndex)` pour une installation ; en cas d'échec, le chantier est retenté plus tard ; une réparation BLUE dont le groupe a entre-temps été anéanti devient une reconstruction, alors qu'une réparation RED dans le même cas est annulée et nécessite une nouvelle livraison (`zc2:53358-53384`, `zc2:53426-53468`) ;
- l'annulation rembourse le supply quand la zone est simplement suspendue ou que la cible a disparu, pas quand la zone a changé de camp (`zc2:53340-53349`, `zc2:53576-53581`) ;
- les chantiers sont sauvegardés et restaurés avec leur temps restant (`zc2:53475-53555`).

**Envoi IA** (`bc:_dispatchRegularSupplyStock`, `zc2:54689-55000`) :
- il commence par réconcilier les permis et exécuter la mise à jour de récupération locale, puis parcourt les zones en tourniquet à partir d'un curseur ; une zone source est éligible quand elle détient du stock prêt non réservé de son propre camp, que le supply IA est activé pour ce camp, et qu'elle est active, non suspendue, non cachée (`zc2:54690-54716`) ;
- ses routes de supply utilisables (les `GroupCommander` de supply de la zone, tournés par un curseur par zone) deviennent des « offres » regroupées par zone cible (`zc2:54747-54780`) ;
- demande de la cible = emplacements d'amélioration manquants + groupes endommagés (1 pour une zone neutre) (`_regularSupplyTargetDemand`, `zc2:54287-54335`) ;
- priorité de la cible = `100 + 45 × missing + 35 × damaged` + 130 si neutre + bonus de front (80 à moins de 5 NM du front, 50 à moins de 15, 20 à moins de 30) + temps d'attente (1 point par 30 s, max 90) − contention (220 + 60 par livraison ennemie supplémentaire déjà engagée vers la même zone neutre) + un terme Director (`_regularSupplyTargetPriority`, `zc2:54443-54504`) ;
- à chaque tick, au plus `regularSupplyDispatchBudgetPerTick` (2) envois sont faits, en choisissant le meilleur « ticket » = priorité + 30 par unité non pourvue (max 3) − 70 par envoi déjà fait vers cette cible pendant ce tick (`zc2:54960-55000`, `zc2:8504`) ;
- `_dispatchRegularSupplyCommander` réserve un **permis** sur le groupe : `{sourceZone, targetZone, side, reservedAt, dispatchAt = now + 30 s, allowSuspendedSource}`, incrémente le `_regularSupplyPendingStock` de la zone source, active la machine à états du groupe, et prévient les joueurs présents dans la zone (la fenêtre de 30 s ci-dessus) (`zc2:54615-54687`, `zc2:54208-54226`) ;
- un joueur qui prend une caisse pendant la fenêtre obtient la priorité : `_consumePlayerRegularSupplyStock` libère autant de permis encore différés de cette zone que nécessaire (`zc2:52381-52387`, `zc2:53902-53939`) ;
- quand le groupe décolle réellement, `_consumeRegularSupplyPermit` retire un supply prêt de la source (un ordinaire en premier) et estampille la sortie avec son origine (`zc2:53941-53967`) ;
- `_reconcileRegularSupplyPermits` libère un permis dépassant de plus de 60 s son heure d'envoi, ou dont la source/la cible est devenue invalide (changement de camp, suspension, supply IA désactivé, route coupée par l'infrastructure, §28) (`zc2:54247-54285`) ;
- une sortie perdue remet à 0 la progression de production de la zone source ; en PvE, un hélicoptère ou un convoi RED perdu place aussi cette route sous un « délai de perte » de 300 s qui ne commence à compter que lorsque la zone a de nouveau du stock (`_handleRegularSupplySortieLoss`, `_recordRegularSupplyLossDelay`, `zc2:54156-54201`, `zc2:54013-54076`).

### Notes de reproduction

- Le modèle tient en trois petites pièces : un accumulateur de production par zone, un stock à deux saveurs (produit / apporté), et une couche de réservation (« permis ») qui arbitre entre l'IA et les joueurs pour le même stock.
- Le coût de la production est de l'arithmétique en O(zones) par cycle ; l'envoi est borné par le budget par tick et par les curseurs en tourniquet.
- L'asymétrie entre les camps est voulue : les zones BLUE détiennent du stock et se réparent avec ; les zones RED PvE ne détiennent (presque) aucun stock et ne réparent qu'à l'arrivée d'une livraison, ce qui rend la coupure des routes de supply RED significative.
- Dépendances cachées : le modèle d'emplacements d'amélioration d'une zone (`zone.built`, templates, `zone:upgrade`), la machine à états `GroupCommander` des vols de supply, et le terme de priorité du Director.

## 27. Le bâtiment d'entrepôt destructible d'une zone (static `[WH]`)

### Ce que voit le joueur

- Un centre logistique a un bâtiment physique, un static nommé `[WH] <zone>` ; l'étiquette de zone affiche `[WH]`, `[WH destroyed]` ou `[WH] Repairing n%` (`zc2:46472`, `L10N:1388-1391`).
- Tant qu'il est debout, la zone a les avantages du centre logistique : stock d'armement illimité (§17), cible de supply plus haute et temps de base de production et de réparation plus courts (§26).
- Le détruire (c'est une cible normale pour les armes des joueurs, il est ajouté aux listes de cibles des vols de CAS, de bombardiers et de frappe de structures achetés, et il apparaît dans les listes de cibles du JTAC et de l'intel de zone ; `zc2:36122-36128`, `zc2:1508-1517`, `zc2:109751-109753`) supprime ces avantages : le stock de supply est ramené à la cible d'une zone normale, et l'entrepôt d'armement devient fini, remis à 50 de chaque arme autorisée (150 pour les roquettes) (`zc2:46526-46570`, `zc2:51006-51020`).
- Boutique : « Logistic Center [WH] » (`zlogc`, 5000) en crée un dans une zone d'aérodrome amie entièrement améliorée ; « Repair Logistic Center » (`zwhrepair`, 2000) lance une réparation de 30 minutes : "Warehouse repair started at <zone>. Completion in 30 minutes of mission time.", puis "Warehouse repair completed at <zone>. Logistic Center benefits restored." (`zc2:24155-24253`, `L10N:1394-1395` ; manuel p. 31).
- En PvE, le Director RED peut acheter la même chose pour RED (`redwarehouse`, `redwhrepair`) : un « dépôt de supply arrière » RED (`Setup:4833-4864`, `zc2:24212-24234`).

### Mécanisme

- État : `zone.warehouseFacility = {name = '[WH] <zone>', state = 'operational' | 'destroyed' | 'repairing', placement = {x, z, heading, kind, subZone, reservedSubZones}, object, repairCompleteAt, repairDurationSec, weaponStock}` (`zc2:24176`, `zc2:46385-46406`).
- Spawn : `coalition.addStaticObject(country, {category = 'Fortifications', type = 'af_hq', shape_name = 'syr_af_hq', name, x, y, heading})`, pays RUSSIA pour RED et USA pour BLUE ; si une épave porte encore le nom, elle est détruite d'abord et le spawn est retenté à la mise à jour suivante (`zc2:46301-46334`).
- Implantation (`_findWarehousePlacement`, `zc2:46108-46299`), pour une zone d'aérodrome active qui n'est pas un porte-avions :
  - l'emprise du bâtiment est d'environ 100 m × 31 m (X local ±49,8 m, Z local de −20,5 m à +10,8 m) ;
  - premier choix : à côté d'une route — un indice du créateur de mission (une trigger zone nommée `<zone>-wh`), sinon le point de route le plus proche du centre de la zone, sinon jusqu'à 8 points de route mis en cache pour les sous-zones numérotées de la zone ; la direction de la route est estimée à partir de quatre sondes `land.getClosestPointOnRoads` à 20 m autour du point, et le bâtiment est placé à 28 m de la route, de l'un ou l'autre côté, son mur avant tourné vers elle ;
  - chaque coin de l'emprise doit être à l'intérieur de la zone, sur une surface `LAND` ou `ROAD`, pas sur une route, et la hauteur du sol ne doit pas varier de plus de 2 m ;
  - repli (BLUE seulement ; un dépôt RED exige un site en bord de route) : le centre d'une sous-zone libre, en essayant 8 caps et en gardant le plus plat ;
  - un candidat est rejeté quand une unité vivante, un static ou un objet de décor se trouve à moins de 100 m (sphère `world.searchObjects`), et il « réserve » chaque sous-zone de spawn que son emprise recouvre pour qu'aucun groupe défensif ne soit ensuite spawné dans le bâtiment ;
  - l'implantation retenue est mise en cache et sauvegardée, si bien que le bâtiment revient au même endroit.
- Achat (`applyLogisticCenterUpgrade`) : la zone doit être amie, active, un aérodrome, pas déjà un centre logistique, et entièrement améliorée (`not zone:canRecieveSupply()`) ; le static est spawné tout de suite, l'étiquette est rafraîchie 1 s plus tard, et 2 s plus tard `_activateWarehouseFacility` pose `LogisticCenter = true` et ajoute 500 000 de chaque arme à l'aérodrome (`addWarehouseItemsAtZone(zone, side, 500000)`), libère les permis de supply en attente de la zone et annonce `WAREHOUSE_LOGISTIC_CENTER_CREATED` (`zc2:24155-24210`, `zc2:46356-46369`).
- Surveillance (`_updateWarehouseFacility(now)`, appelée en `zc2:55257` sur le chemin de mise à jour de zone, qui ne l'exécute que pour les zones ayant une installation, `zc2:55150-55152`) : une installation opérationnelle dont le static n'existe plus ou n'a plus de vie devient `destroyed` : `LogisticCenter = false`, le stock prêt est borné au nouveau maximum, les permis IA excédentaires de la zone sont libérés (les plus récents d'abord), et l'inventaire d'armement est remis à zéro par `_resetWarehouseFacilityWeapons` (`zc2:46526-46570`).
- Réparation (`applyWarehouseRepair`) : `state = 'repairing'`, `repairDurationSec = 1800` ; quand le temps est écoulé, le static est respawné et l'installation réactivée (`zc2:24236-24253`, `zc2:46572-46580`).
- Tant qu'elle est détruite ou en réparation, la zone a un stock d'armement **fini** qui est capturé dans la sauvegarde (`_hasFiniteWarehouseStock`, `weaponStock = WarehousePersistence.CaptureWeapons(storage)`), si bien que l'inventaire et l'état du bâtiment sont sauvegardés dans le même point de contrôle (`zc2:46378-46406`).
- Redémarrage : `_initWarehouseFacility` (appelée depuis `ZoneCommander:init`, `zc2:51389`) recrée un bâtiment opérationnel à partir de son implantation sauvegardée ; pour un bâtiment détruit ou en réparation, elle recrée l'**épave** en spawnant le static et en le faisant exploser avec `trigger.action.explosion(point, 50)` après avoir vérifié que rien d'autre ne se trouve à moins de 50 m ; un centre logistique d'une ancienne sauvegarde sans implantation en reçoit une calculée plus tard, une zone par seconde (`zc2:46464-46524`, `zc2:46444-46462`).
- Une zone qui est un centre logistique par le setup (`zones.x.LogisticCenter = true`) voit son enregistrement d'installation créé de la même façon par `_initWarehouseFacility` (`zc2:46470-46473`, `Setup:5921-5934`).

### Notes de reproduction

- Le bâtiment est un static unique dont la vie est scrutée par la mise à jour de la zone propriétaire ; aucun événement n'est utilisé.
- La partie difficile est l'implantation automatique : placement en bord de route, planéité, dégagement, et réservation des sous-zones de spawn qu'il recouvre.
- Restaurer un état détruit demande une épave visible, obtenue en spawnant puis en faisant exploser le static, ce qui n'est sûr que sur un site dégagé.

## 28. `TheaterInfrastructure` : un bâtiment de la carte détruit coupe une route de supply RED

### Ce que voit le joueur

- Chaque zone SAM RED de la campagne du Caucase est approvisionnée depuis une base RED, et ce lien dépend d'un **bâtiment d'entrepôt de la carte** (un objet de décor) ; détruire le bâtiment empêche RED d'approvisionner, et donc de réparer, cette zone SAM depuis cette base.
- Une cible plus grande, l'entrepôt de supply de Vaziani, coupe tout un ensemble de routes autour de Tbilissi et de Vaziani ; elle est proposée comme mission de frappe (« Strike Vaziani », 1000 crédits) une fois que BLUE tient Lima alors que Vaziani est encore RED (`Setup:9295-9310`).

### Ce que règle le créateur de mission

`TheaterInfrastructure` est une liste globale dans le fichier de setup ; chaque entrée est `{id, flag, effect, side, scope, sourceZone, targetZones}` (`Setup:2271-2360`) :

| `id` | `flag` | `effect` | `sourceZone` → `targetZones` |
|---|---|---|---|
| `kobuleti_sam_india_warehouse` | `SamAlphaWarehouse` | `defence_supply` | Kobuleti → SAM-India |
| `sukhumi_sam_foxtrot_warehouse` | `SamDeltaWarehouse` | `defence_supply` | Sukhumi → SAM-Foxtrot |
| `sochi_sam_echo_warehouse` | `SamEchoWarehouse` | `defence_supply` | Sochi → SAM-Echo |
| `anapa_sam_alpha_warehouse` | `SamGolfWarehouse` | `defence_supply` | Anapa → SAM-Alpha |
| `krasnodar_sam_charlie_warehouse` | `SamHotelWarehouse` | `defence_supply` | Krasnodar-Pashkovsky → SAM-Charlie |
| `mineralnye_sam_juliett_warehouse` | `SamJuliettWarehouse` | `defence_supply` | Mineralnye → SAM-Juliett |
| `mozdok_sam_kilo_warehouse` | `SamKiloWarehouse` | `defence_supply` | Mozdok → SAM-Kilo |
| `tbilisi_vaziani_warehouse` | `StrikeVaziani` | `regional_supply` | Tbilisi → Soganlug, Vaziani |
| `vaziani_warehouse` | `StrikeVaziani` | `regional_supply` | Vaziani → Kilo, Lima, Soganlug, Tbilisi, SAM-Lima, SAM-Mike |

- Toutes les entrées sont `side = RED`, `scope = "routes"` ; `scope = "source"` (toute route quittant la zone source) est aussi accepté (`zc2:75005-75024`).
- Le `flag` est le nom d'une trigger zone placée sur le bâtiment dans le `.miz` : le setup la résout avec `SCENERY:FindByZoneName(flag)` de Moose et signale un objet manquant au démarrage (`Setup:9004-9038`).
- Le Director valide la liste au chargement (`id` unique, `flag` non vide, camp et portée valides, zone source existante, liste de cibles non vide) et lève une erreur Lua sinon (`zc2:74986-75035`).

### Mécanisme

- Un drapeau devient vrai quand sa cible est détruite : `CustomFlags[flag] = true` est ce que le registre des cibles de mission pose pour une cible « custom » (à usage unique), si bien que la coupure est définitive et persistée avec la campagne (note 05 §11 ; `Setup:9302`).
- `bc:_ensureRegularSupplyInfrastructureIndex()` indexe la liste par zone source et par zone cible (`"*"` pour `scope = "source"`) (`zc2:53810-53837`).
- `bc:_regularSupplyRouteInfrastructureBlocked(groupCommander)` renvoie true quand une entrée pour la zone source et la zone cible du groupe (ou une entrée `"*"`) correspond au camp du groupe et que son drapeau est levé (`zc2:53839-53861`).
- Elle est consultée quand une route de supply est évaluée pour un envoi, quand les permis différés sont réconciliés, et par le Director quand il planifie le supply RED (`zc2:54549`, `zc2:54262`, `zc2:77962`, `zc2:78094`).
- La même condition est aussi écrite directement sur les capacités de supply du setup, par exemple `DirectorCapability:new({name = 'Support-SAM-India', mission = 'supply', targetzone = 'SAM-India', template = 'SupplyConvoy', type = 'surface', condition = function(self) return not (self.side == 1 and CustomFlags["SamAlphaWarehouse"]) end})` (`Setup:1291`, `Setup:1633-1667`).
- Comme une zone RED PvE ne répare qu'à la livraison (§26), une route coupée signifie que la zone SAM reste endommagée.

### Notes de reproduction

- La fonctionnalité est une table de correspondance entre « drapeau d'objectif détruit » et « routes de supply bloquées » ; le coût est une recherche de table par évaluation de route.
- Elle exige des objets de décor adressables depuis le `.miz` (une trigger zone sur le bâtiment) et un stockage persistant de drapeaux.
- `effect` n'est pas utilisé par la vérification de route ; il est transporté dans le catalogue du Director (`zc2:95900`, `zc2:75457`, `zc2:76208`), où seul `defence_supply` a un comportement propre : un bâtiment `defence_supply` du camp RED détruit est enregistré comme preuve persistante pour le plan défensif du Director RED, rattachée à la zone de la zone source (`Director:_defensivePlanPersistentEvidence`, `zc2:76464`, `zc2:76520-76529`) ; `regional_supply` n'apparaît nulle part ailleurs dans le moteur que comme champ recopié.

## 29. PvP : objectifs industriels et part du territoire de départ

### Zones industrielles (PvP uniquement)

- Cinq zones du setup du Caucase sont des sites industriels dont les bâtiments clés sont déclarés comme `industryCores` (un ensemble de noms de statics) : Mining Facility (Factory, HQ), Insurgent Camp, Secret Tech Facility (Factory, Factory 2, HQ), Ammunition Depot (quatre entrepôts), Tank Factory (deux usines) (`Setup:868-874`).
- Revenu : à chaque mise à jour de zone en PvP, une zone qui a un `income` et un propriétaire verse ce revenu au compte de la coalition de son propriétaire, sauf `productionDisabled` (`zc2:55155-55159`).
- `_observeIndustryCores()` (à chaque mise à jour) : un static de cœur qui n'existe plus ou n'a plus de vie est « retiré » définitivement (ajouté à `zone.retiredStaticUpgrades`, retiré de `zone.built`) ; quand plus aucun cœur n'est vivant, `zone.productionDisabled = true` et le revenu s'arrête (`zc2:55109-55144`).
- Les cœurs sont exclus des chantiers de réparation et de reconstruction de la zone, si bien qu'une usine détruite n'est jamais reconstruite (`zc2:53013-53016`).
- Mission de frappe : `MissionCommander:new` construit, par camp, une mission de « frappe industrielle » à partir des statics de cœur de type `Workshop A`, `Tech combine` ou `Tech hangar A` ; un site est éligible quand il appartient à l'ennemi et que chacun de ses cœurs vivants se trouve à moins de 100 NM d'une zone que possède l'attaquant ; un site éligible est tiré au hasard et enregistré comme cible de groupe de statics `INDUSTRY:<side>:<zone>` valant `min(1000, 300 × number of buildings)`, avec les coordonnées de chaque bâtiment dans le texte de la mission (`zc2:102566-102600`, `zc2:102707-102737`).

### Part du territoire de départ

- `PvPStartingTerritoryPercent` (Config, 50 par défaut ; valeurs permises 20, 30, 40, 50) est la part du territoire que possède chaque coalition au début d'une manche PvP nouvelle ou remise à zéro, le reste étant neutre (20 → 20 % RED, 20 % BLUE, 60 % neutre ; 50 → tout est réparti) (`Config:313-318`).
- Le setup contient une liste ordonnée écrite à la main de clés de zones par camp, `pvpStartingTerritoryOrder[1]` (34 clés, commençant par `anapa`, `samalpha`, `anastasia`, `novorossiysk`… et finissant à l'est par `novopavlo`, `zhemtala`) et `[2]` (35 clés, commençant par `vaziani`, `tbilisi`, `sammike`, `samlima`… et finissant sur la côte par `sukhumi`, `samfoxtrot`, `gudauta`), commentée « Connected geographic expansion order; StartNormal assigns coalition colors » : chaque liste s'éloigne d'une base d'origine à travers des zones connectées (`Setup:969-987`) ; il calcule `quota = round(total zones × percent / 100)` ; les `quota` premières zones de chaque liste vont à ce camp, les autres démarrent neutres (`Setup:5885-5892`).
- Les sites industriels sont hors quota et suivent un voisin nommé : Mining Facility suit Batumi, Secret Tech Facility suit Sukhumi, Insurgent Camp suit India (sinon Isunderi), Ammunition Depot suit Sochi, Tank Factory suit la zone de clé `krasnodarc` (sinon `holmskiy`) (`Setup:5893-5898`).
- La valeur utilisée est stockée dans `CustomFlags.PvPStartingTerritoryPercent`, si bien qu'une sauvegarde existante conserve sa disposition : la propriété sauvegardée l'emporte, et seules les zones absentes de la sauvegarde prennent la disposition de départ ; `StartNormal` échange les deux camps (`Setup:5877-5884`, `Setup:5900-5908`).
- Anapa et Vaziani démarrent comme les deux centres logistiques d'une manche PvP, avec un stock de supply plein (`Setup:5921-5927`).
- Victoire : `pvpVictoryZones` est la liste de toutes les zones territoriales de `pvpStartingOwners` (zones normales et zones SAM ; les cinq sites industriels sont ajoutés à la table des propriétaires ensuite et ne sont donc **pas** des zones de victoire) (`Setup:949-968`).
- `checkMissionComplete` est enregistrée sur les déclencheurs `lost`, `destroyed` et `captured` de chaque zone de victoire ; elle retourne dès qu'elle trouve une zone de victoire RED et une BLUE ; quand une seule coalition possède encore des zones de victoire (les neutres ne comptent pas), cette coalition gagne : `PVP_MISSION_WINNER` ("<side> coalition wins!"), son `BH.ogg` pour le gagnant, user flag 180 posé (`Setup:2734-2752`, `Setup:2834-2840`).
- Avec `AutoRestart`, la sauvegarde de campagne est vidée (`bc._persistenceResetPending = true`, `Utils.saveTable(bc.saveFile, 'zonePersistance', {})`, `resetSaveFileAndFarp()`) et le user flag 181 est levé 5 s plus tard pour terminer la mission ; sinon la coalition gagnante obtient un menu F10 « Restart and reset » (`Setup:2753-2765`).
- Les zones SAM d'origine des deux camps (`samalpha`, `sammike`) sont gardées en permanence éveillées en PvP (`customSuspendNm = 1000`, `noIdleSuspend = true`) (`Setup:988-992`).

## 30. Supply et réparation par train (Normandie)

Normandie seulement : chaque fonction ci-dessous retourne immédiatement quand `bc:isNormandyTheatre()` est faux (le global `map` contient "normandy") (`zc2:27041-27043`).
`NZ` = `Setup files/Normandy_Zone_Setup.lua`.

### Ce que voit le joueur

- La carte F10 montre le **réseau de supply** sous forme de flèches entre zones (une par connexion de supply) : bleue quand l'origine est BLUE et que la destination n'est pas RED, rouge dans le cas miroir, blanche sinon ; la flèche d'une connexion par train disparaît quand son train est détruit (`zc2:38232-38292`).
- Les trains sont de vrais groupes de trains DCS qui roulent d'une zone à la suivante ; quand un train atteint sa zone de destination, la zone est capturée (si elle est neutre) ou approvisionnée (si elle appartient au camp du train) (`NZ:4492-4565`).
- Tuer un train : "Enemy train <name> destroyed!", "Strategic asset destroyed: +1000 credits" sur le compte de la coalition du tueur, "Enemy supply chain disrupted! Train routes are now cut off." (`zc2:38337-38348`, `L10N:1317-1319`).
- Détruire une gare ou un dépôt ferroviaire (bâtiments de la carte) : "<Depot> destroyed! N military units abandoned due to supply disruption: <names>" et "Enemy railway infrastructure destroyed! Strategic targeting bonus: +N credits" — 2000 crédits par train qui dépendait de cette gare (`zc2:38534-38597`, `L10N:1321-1322`).
- Après un redémarrage : "Train <name> remains destroyed from previous mission." (`zc2:38338-38339`, `L10N:1320`).
- Réparation de train : `Shop > Capture & resources > Repair train route` (`ztrainrepair`, 2000 crédits, rang 1), puis choisir la route détruite par « origine → destination » ; l'origine doit être BLUE, la destination n'a pas à l'être ; l'objet n'est en rayon que tant qu'il existe au moins une telle route (manuel p. 47 ; `NZ:1600`, `NZ:1625`, `NZ:2994-3001`, `zc2:38472-38497`).

### Ce que règle le créateur de mission

- `bc:addConnectionSupply(from, to[, method])` déclare un lien de supply ; `method` vaut `'train'` ou `'default'` par défaut ; l'appeler une fois fait basculer le moteur sur une **carte de connexions de supply** séparée (`bc.useSupplyConnectionMap`), distincte des connexions d'attaque (`zc2:27045-27054`).
- Le setup de Normandie déclare 51 liens de supply, dont 20 par train : London → Manston, Farnborough, Chailey, Ford, Hawkinge côté britannique ; Cherbourg → Valognes → Le Molay → Caen, Bernay → Caen, Dunkirk-Port → Calais, Amiens → Abbeville → Le Touquet, Le Havre → Rouen et Fecamp, Paris → Orly, Saint-Aubain, Fecamp, Saint-Andre → Bernay sur le continent (`NZ:1115-1168`).
- Les groupes de trains dans le `.miz` sont des groupes en late activation nommés `<prefix><From>-resupply-<To>` avec le préfixe `AXE_Train_` (allemand) ou `UK_Train_` ; le moteur extrait l'origine et la destination du nom (`zc2:38128-38145`, `zc2:38172-38184`, `zc2:17167`).
- `RAILWAY_STATION_GROUPS[stationName] = {train group names}` associe chaque gare ou dépôt ferroviaire aux trains qui en dépendent ; la gare est un objet de décor trouvé via une trigger zone `Hidden<stationName>` (`SCENERY:FindByZoneName`) (`NZ:2885`, `NZ:2893-2990`).
- L'arrivée est détectée par une trigger zone par route (`supply-volognes`, `supply-Caen`, …) et un user flag par route : 200–214 pour les trains de l'Axe, 300–305 pour les trains britanniques (`NZ:4501-4523`).
- `bc:startTrainSupplyMonitor({stationGroups, initialDelay = 60, interval = 120, notifyRestored = true})` ; valeurs par défaut `trainSupplyRewardAmount = 1000`, `railwaySupplyRewardAmount = 2000`, coalition récompensée selon le préfixe (`AXE_Train_` → BLUE, `UK_Train_` → RED) (`NZ:3322-3329`, `zc2:17164-17170`, `zc2:38413-38430`).

### Mécanisme

- Routes : `bc:registerRailwayStationGroups(RAILWAY_STATION_GROUPS)` construit une route par groupe de train, `{groupName, fromZone, toZone, stations, choice = {label = "From → To", params = {route}}}`, indexée par nom de groupe et par zone d'origine, et mémorise le pays utilisé par les templates de train de chaque coalition ; deux groupes créés sur la carte roulent « à l'envers » et ont leurs extrémités échangées (`zc2:38432-38470`).
- Activation au démarrage (`activateLivingTrainGroups`) : un train non marqué détruit est activé (`GROUP:Activate`) quand sa zone d'origine est neutre ou appartient à la coalition du template ; si l'origine est tenue par l'autre camp, le train est spawné pour ce camp à la place (`_spawnRepairedTrain`) ; un second lot est activé 600 s plus tard (`NZ:3263-3284`, `NZ:3330-3333`).
- Arrivée : un `timer.scheduleFunction` vérifie une route par seconde, en rotation, et lève le user flag de la route quand la première unité du train est dans la zone d'arrivée de la route ; un autre exécute `checkZoneFlags()` toutes les 30 s : pour chaque drapeau levé, si la zone d'origine est possédée, une destination neutre est capturée pour le camp de l'origine (`zone:capture(side)`), une destination du même camp reçoit `applyTrainSupply` (un supply prêt importé quand la zone est suspendue ou n'a besoin de rien, sinon un `zone:upgrade()` immédiat), et le drapeau est remis à zéro (`NZ:4530-4541`, `NZ:5006-5022`, `NZ:4492-4499`, `NZ:4546-4566`).
- Perte d'un train : `_monitorTrainSupplyGroups` (`SCHEDULER` de Moose, premier passage à 60 s, puis toutes les 120 s) liste les groupes des deux camps dans les catégories `GROUND` et `TRAIN` dont le nom contient un préfixe de train ; un groupe sans unité, ou dont la première unité n'existe pas ou a une vie ≤ 1, est « détruit » : le groupe est retiré, `CustomFlags[groupName] = true` (persisté), les crédits vont à la coalition adverse, la flèche est retirée et la boutique de réparation rafraîchie (`zc2:38376-38411`, `zc2:38315-38360`).
- Perte d'une gare : un scheduler de 60 s (premier passage à 30 s) lit la vie relative des objets de décor de chaque gare ; quand tous sont à 50 % ou moins et que la gare n'est pas encore marquée, `CustomFlags[station] = true` et `bc:destroyRailwayDependentGroups(station)` détruit chaque train qui y est associé, marque chacun détruit, et verse 2000 par train à la coalition adverse (`NZ:3462-3499`, `zc2:38534-38597`).
- Redémarrage : `restoreRailwayDestructionState` re-endommage le décor de chaque gare marquée avec `trigger.action.explosion(point, 500)` et détruit de nouveau ses trains ; `restoreTrainSupplyState` retire chaque train dont le drapeau est levé (`NZ:3158-3198`, `zc2:38362-38374`).
- Réparation (`bc:applyTrainRepair(route)`) : exige que le drapeau de la route soit levé et une origine BLUE ; le template du train est spawné de nouveau (`_DATABASE:Spawn(template)`, coalition et pays basculés vers le propriétaire de l'origine, drapeau d'arrivée remis à zéro), le drapeau du train et les drapeaux de toutes ses gares sont effacés (les drapeaux de gares sont mis à `false`, si bien que le décor peut être détruit de nouveau), les flèches redessinées, message `TRAIN_REPAIR_COMPLETE` (`zc2:38499-38532`).
- Changement de propriétaire : quand une zone qui est l'origine de routes de train change de camp, `buildConnectionMap` respawne chaque train vivant de cette origine pour le nouveau propriétaire, et les choix de la boutique de réparation sont rafraîchis (`zc2:27399-27413`).
- La carte de connexions de supply remplace aussi la carte de connexions d'attaque partout où le moteur demande « quelles zones approvisionnent quelles zones » en Normandie (par exemple l'adjacence des cibles de piste, les voisins de supply du Director) (`zc2:27543-27550`, `zc2:62362`, `zc2:74479`).

### Notes de reproduction

- Le supply par train ne fait pas partie de l'envoi de regular supply du §26 : c'est un horaire fixe de trains créés sur la carte, avec une arrivée détectée par scrutation d'une trigger zone, et l'effet appliqué par du code du fichier de setup.
- Deux couches peuvent couper une route : le train lui-même (un groupe) et la gare (décor) ; les deux sont persistées sous forme de drapeaux nommés, et seule la couche train est réparable depuis la boutique.
- Les coûts sont faibles et bornés : une route vérifiée par seconde, un listage de groupes toutes les 120 s, une lecture de vie de décor par gare toutes les 60 s.

## Vu hors de ce thème

- Mécanique de capture temporisée (`startPendingCapture`, `startPendingCaptureWithCargoStatic`, `registerPendingCaptureHandler`, tombstones) : `zc2:46797-46986`, `zc2:24675` — thème 01.
- Production du « regular supply » des zones, permis d'envoi IA et chantiers de récupération locale : détaillés désormais au §26.
- **Installation** d'entrepôt par zone (static `[WH]`) et objets de boutique qui créent et réparent un centre logistique : détaillés désormais au §27.
- Objets de boutique `zwh50`, `farphere` (FARP construit par l'IA, messages `LOGISTICS_FARP_HELO_ENROUTE*`), `supplies2` : `Config:1609-1889` — thème 05.
- Intel de zone lancé par l'espion (`startZoneIntel`) : `CTLD.lua:1956` — thème intel.
- CSAR / sauvetage de pilote dans `LogisticCommander` (`zc2:98446-100730`, `zc2:101831-102270`) — thème 06.
- Statistiques de carrière et encaissement des récompenses de contribution/atterrissage (`bc:addContribution`, `_handleRewardPlayerLanding`, `recordCareerStat`) — thème 05.
- Navigation de porte-avions / respawn de porte-avions qui réapprovisionne les entrepôts des porte-avions : `zc2:15512-15573`.
- Vols IA BLUE qui tirent leur chargement de l'entrepôt de la base (`_prepareBlueAiWarehouseSpawn`, `BlueAiWarehouseEquipmentByClsid`) : `zc2:19599-20072` — thème 03.
- Format de fichier de sauvegarde/chargement de `WarehousePersistence` : `zc2:111851-112251` — thème 02.
- Script de message de bienvenue qui enregistre les nouvelles zones de FARP (`RegisterWelcomeZone`) : `zc2:20122-20124`.
