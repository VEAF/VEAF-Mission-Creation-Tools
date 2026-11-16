# 03 — Groupes IA et sorties (Foothold v6.5.3)

Périmètre : tout ce que l'IA pilote en vol, au sol ou en mer, sauf le planificateur Red/Blue `Director`, les règles de capture, les internes de la boutique, les internes de CTLD et la persistance.
Toutes les références de ligne portent sur `zoneCommanderv2.lua`, sauf mention d'un autre fichier.

« (estimation) » désigne tout ce qui n'a pas été lu dans le code.

| # | Fonctionnalité | Description en une ligne | Emplacement principal dans le code |
|---|---|---|---|
| 1 | Déclaration des sorties et templates | les enregistrements `addGroups` (`DirectorCapability` / `GroupCommander`) nomment l'origine, la cible, la mission, le jeu de templates | `11958`, `57265`, `57725`, `60357-60505`, `MA_Setup_CAv2.lua:1060-1340` |
| 2 | Machine à états des sorties aériennes | hangar → preparing → takeoff → inair → landed, scrutée ; spawn au parking, tasking, atterrissage de supply → capture/livraison | `68725-68868`, `67521-68006`, `68330-68712` |
| 3 | Éligibilité au spawn et plafonds par rôle | une porte unique décide si une sortie peut décoller ; plafonds CAP/CAS/SEAD/piste selon le nombre de joueurs et la difficulté | `66102-66597`, `60825-61110`, `57104-57262` |
| 4 | Comportement des CAP | orbite en racetrack avec engagement en route, RTB sur winchester/cible perdue, évitement des SAM, assistance de la CAP Blue | `35751-35999`, `67137-67333` |
| 5 | Tasking des frappes | CAS, SEAD, bombardement de piste, routes anti-navires sous forme de tâches DCS brutes | `35309-35530`, `36091-36474` |
| 6 | Sorties de surface | convois de supply/d'attaque sur route, batteries d'artillerie, navires ; arrivée → capture/livraison | `70792-70844`, `69739-70135`, `70508-70763`, `11024-11610` |
| 7 | Usage de Moose OPS | six petits emplacements seulement (Hunter, cuirassé, artillerie navale, V1) | `41099`, `10932`, `70022`, `109998`, `111165` |
| 8 | Hunter | deux appareils Red lancés après la série de kills d'un joueur | `40974-41168` |
| 9 | Cargo des hélicoptères de supply IA | conteneur en sling load, points d'atterrissage, récupération après décrochage | `58056-58260`, `58495-58533`, `68267-68307` |
| 10 | Patrouilles de zone et AIEN | groupes qui circulent entre sous-zones ; réactions AIEN aux tirs, débarquements, suppression, initiative | `27654-28100`, `AIEN.lua` |
| 11 | Réseau de défense aérienne | contrôle d'émission MANTIS, masquage/révélation des SAM sur le MFD, temps de réaction de nuit et flou radar | `111396-111495`, `4432-4441`, `41579-41640` |
| 12 | Bombardier stratégique | raid de bombardier spawné en vol avec escorte ; tirage d'un intercepteur Red contre le raid Blue | `1500-2320`, `2350-4195` |
| 13 | Appuis d'artillerie en Normandie | artillerie navale + frappeur ennemi, sites de lancement de V1 | `109927-110100`, `111165-111390` |
| 14 | IA Blue (PvE) et différences PvP | limites du support Blue, coût de supply, usage de l'entrepôt ; limites PvP et systèmes en miroir | `61022-61110`, `66386-66403`, `17095-17102` |
| 15 | Limiteurs et nettoyage | mises à jour de zone étalées, FSM en dormance, file d'évaluation des spawns, nettoyage des épaves et des atterrissages | `43225-43346`, `56268-56440`, `65896-66000`, `17853-18000` |

## 1. GroupCommander — déclaration et résolution des templates

### Ce que règle le créateur de mission

Les sorties IA d'une zone se déclarent dans le fichier de setup avec `zones.<zone>:addGroups({ ... })` (`MA_Setup_CAv2.lua:1290-1297`).
Dans la v6.5.3, presque toutes les entrées sont un enregistrement `DirectorCapability:new({...})` (402 occurrences dans `MA_Setup_CAv2.lua`), et seules 7 sont des `GroupCommander:new({...})` directs (toutes de l'artillerie fixe, par exemple `MA_Setup_CAv2.lua:1366`).
Une `DirectorCapability` est une table passive qui porte les mêmes champs qu'un `GroupCommander` ; elle est marquée `_isDirectorCapability`, vaut `type='air'` par défaut et ne peut pas définir de méthodes de FSM (`zoneCommanderv2.lua:11958-11969`).
`ZoneCommander:addGroups` route les enregistrements marqués vers `addDirectorCapabilities` et insère les objets `GroupCommander` simples dans `zone.groups` (`56468-56489`).
Une capability ne devient un `GroupCommander` vivant que lorsque `BattleCommander:activateDirectorCapability` copie ses champs dans `GroupCommander:new(authored)`, appelle `originZone:addGroup` puis `:init()`, et active sa FSM (`26383-26450`) ; jusqu'à deux instances « dérivées » supplémentaires (emplacements 2 et 3) peuvent être créées à partir du même enregistrement, nommées `<name>__Director2/3` (`26389-26415`).
(Quand et pourquoi une capability est activée relève du Director — non analysé ici.)

Champs vus dans le fichier de setup et lus par le moteur :

| Champ | Signification | Où il est lu |
|---|---|---|
| `name` | Identifiant unique ; c'est aussi le nom du groupe du `.miz` quand aucun `template` n'est donné | `57265`, `60484-60487` |
| `mission` | `'supply'`, `'patrol'` ou `'attack'` (choisit la ligne de timers de respawn et la branche d'éligibilité) | `57264`, `66102-66593` |
| `MissionType` | `'CAP'`, `'CAS'`, `'SEAD'`, `'RUNWAYSTRIKE'`, `'ANTISHIP'`, `'ARTY'`, `'BATTLESHIP'` (sous-rôle ; absent pour le supply et pour l'attaque ou la patrouille au sol simples) | `68336-68425`, `66170` |
| `targetzone` | Nom de la zone sur laquelle le groupe travaille | `66163` |
| `type` | `'air'` (défaut), `'carrier_air'` (se pose sur le porte-avions) ou `'surface'` (sol ou navire) | `57271-57279` |
| `template` | Nom d'une table Lua globale qui liste les noms de groupes template du `.miz` (par exemple `CapPlaneTemplate`) ; l'un d'eux est tiré au spawn | `60474-60505` |
| `Altitude` | Altitude de croisière en pieds, le plus souvent via une fonction d'aide aléatoire (`CapAltitude()` = 22–32 kft, `CasAltitude()` 15–25 kft, `SeadAltitude()` 25–33 kft, `RunwayStrikeAltitude()` 23–28 kft) | `MA_Setup_CAv2.lua:1227-1230` |
| `condition`, `Bluecondition`, `Redcondition` | Prédicats ; `false` bloque le spawn ; les versions colorées restreignent aussi le camp | `66220-66238` |
| `urgent` | Booléen ou fonction ; bascule sur les timers « urgent » courts et autorise la première capture d'une zone neutre | `66242-66243`, `66375-66380` |
| `ForceUrgent` | Permet à un supply urgent de capturer une zone neutre même après une première capture par Red | `66375` |
| `diceChance` | 1–100 : probabilité que la sortie décolle réellement quand son timer de hangar expire | `67943-67957` |
| `spawnDelayFactor` | Nombre ou fonction qui multiplie les timers de hangar/dead | `57727`, `65831` |
| `Airbase` | Force le spawn sur un aérodrome/navire nommé au lieu du `airbaseName` de la zone | `68583-68596` |
| `ForceFromGround` | Hélicoptère : spawn au sol dans la zone au lieu du parking | `68573-68575` |
| `SpawnHot` | Départ moteurs en marche (forcé pour le SEAD quand il est spawné de force) | `66205`, `68519` |
| `ShopLaunchOnly` | Groupe de supply qui ne vole que s'il est acheté en boutique | `66127-66129` |
| `NotCargo` | Hélicoptère de supply sans sling load | `67697` |
| `FixedArty`, `SetActiveMission` | Drapeaux des groupes d'artillerie fixe (voir la section artillerie) | `MA_Setup_CAv2.lua:1366` |
| `terminalType` | Surcharge du type de terminal de parking de Moose | `60551` |

Les jeux de templates sont de simples tableaux Lua globaux de noms de groupes du `.miz`, construits dans le fichier de setup.
`AllCapPlaneTemplates`, `AllCasPlaneTemplates`, `AllSeadPlaneTemplates`, `AllRunwayStrikePlaneTemplates`, `AllCasHeloTemplates`, `AllSupplyHeloTemplates` listent chaque groupe template en late activation de la mission (les noms encodent le camp, la cellule, le rôle, l'emport et la taille de la patrouille, par exemple `RED_SU25_CAS_KH25ML_S25Lx2_FAB500M62x2_B8x2_SPPU_2SHIP`) (`MA_Setup_CAv2.lua:1060-1187`).
Les jeux actifs (`CapPlaneTemplate`, `CasPlaneTemplate`, `SeadPlaneTemplate`, `RunwayStrikePlaneTemplate`, `CasHeloTemplate`, `HeloSupplyTemplate`) sont les listes maîtres filtrées par des tables d'activation par camp (`RedCapPlaneEnabled`, `BlueCapPlaneEnabled`, …) issues de la Config (`MA_Setup_CAv2.lua:73-88`, `1189-1194`).
Les jeux sol/avions sont littéraux : `SupplyConvoy` = `"SupplyConvoy 1..3"`, `"SupplyConvoy_Blue 1"` ; `PlaneSupplyTemplate` = `"IL-76MD"`, `"C-130J-30"`, `"AN-30M"` ; `ArtilleryConvoyLong/Short`, `InsurgentConvoy` (`MA_Setup_CAv2.lua:1196-1224`).
Chaque zone qui lance des avions a `zones.<z>.airbaseName = '<DCS airbase or FARP name>'` (`MA_Setup_CAv2.lua:1232-1288`).

### Mécanisme

`GroupCommander:new` pose `state='inhangar'`, `side=0`, `landsatcarrier = (type=='carrier_air')`, `diceChance` à 0 par défaut, et marque chaque groupe de supply hors boutique `AllowSupplyLaunchFromSuspendedZone` (`57265-57286`).
`GroupCommander:init` résout le jeu de templates via `_getTemplateSet` (une table globale nommée par `template`, sinon `dc.SETS[template]`) (`60474-60482`), puis, pour chaque template, lit le groupe DCS vivant (`Group.getByName`) ou la base de templates de Moose `_DATABASE.Templates.Groups[name]` pour connaître la coalition (`ResolveTemplateSide`), la catégorie d'unité de l'unité 1 et la taille de la patrouille (`AirCount`), et range les templates dans `_tplBySide[1]` / `_tplBySide[2]` (`57725-57805`).
Les groupes template non aériens trouvés vivants au démarrage de la mission sont détruits à l'init (`57750`, `57770`, `57790`).
Un template manquant affiche `ZONE_ERROR_GROUP_TEMPLATE_MISSING` à tous (`57761-57763`).
Comme les templates sont indexés par camp, le même enregistrement sert la coalition qui possède la zone d'origine : à chaque évaluation, `self.side` bascule sur le camp de la zone si un template existe pour ce camp, sinon le spawn est refusé (`66209-66222`).
Au spawn, `_resolveTemplateName` choisit un template pour le camp courant ; pour les avions, il passe par `Respawn.PickTemplateFamilyVariant` (`60484-60505`, `1293`), pour les groupes de surface par un tirage aléatoire uniforme.
Sans `template`, le groupe est le groupe du `.miz` nommé `name` et il est re-spawné avec `Respawn.Group(self.name)` (`68623-68639`).

### Groupes template requis dans le `.miz`

Un groupe en late activation par nom dans chaque jeu de templates, avec le type d'appareil, l'emport, la taille de la patrouille et le pays de coalition réglés dans le Mission Editor (le camp se déduit du groupe, pas du nom) (`57741-57757`).
Les groupes fixes (hors template) comme `'Gudauta-attack-Sukhumi-Arty'` existent sous ce nom exact (`MA_Setup_CAv2.lua:1366`).

## 2. GroupCommander — machine à états aérienne

États pour `type='air'`/`'carrier_air'` : `inhangar → preparing → takeoff → inair → landed → inhangar`, plus `dead` (`68725-68868`).
La FSM n'est pas pilotée par événements : `GroupCommander:update` est appelée par la boucle de mise à jour de zone et scrute le groupe DCS (`70846-70870`).
À chaque mise à jour, le groupe DCS est récupéré (`_getDcsGroupCached`), et un groupe absent ou vide dans n'importe quel état vivant fait passer la FSM à `dead` avec `lastStateTime = now` (`68753-68787`).

Les timers (secondes) viennent de `GlobalSettings.respawnTimers[side][mission]` = `{dead, hangar, preparing}`, par défaut 15 min / 18 min / 2 min pour chaque mission et les deux camps (`8572-8582`), mis à l'échelle par camp par `GlobalSettings.difficultyScaling` et, séparément pour le supply, par `supplyDifficultyScaling` (`8660-8683`).
Les groupes urgents utilisent `GlobalSettings.urgentRespawnTimers` = dead 35 s, hangar 20 s, preparing 5 s (`8565-8569`).

| État | Il en sort quand | Code |
|---|---|---|
| `inhangar` | `now - lastStateTime > hangar × spawnDelayFactor` (ou qu'une heure de nouvel essai liée à une limite aérienne est atteinte) ; puis le tirage optionnel de `diceChance` (échec → `dead`), puis `evaluateSpawnEligibility` ; succès → `preparing` ; refus → planification d'un nouvel essai ou retour au hangar | `67938-67977` |
| `preparing` | après `preparing` secondes : l'éligibilité est revérifiée et le groupe est spawné → `takeoff` | `68713-68723`, `68444-68712` |
| `takeoff` | une unité en vol → `inair` ; toujours au sol après `blockedDespawnTime` (12 min) et complètement arrêté → détruit, retour à `inhangar` | `67521-67591`, `8534` |
| `inair` | toutes les unités posées → `landed` | `67593-67763` |
| `landed` | supply : dans la zone cible → capture ou livraison ; tous : dans la zone d'origine/de récupération → `inhangar` ; sinon despawn après `landedDespawnTime` (60 s hélicoptères, 180 s avions) | `67765-67936`, `8535` |
| `dead` | après `dead × spawnDelayFactor` : vérification d'éligibilité ; succès → `inhangar` (une nouvelle attente complète en hangar), sinon un nouvel essai en dormance | `67979-68006` |

Entrer au hangar (`_enterHangar`) efface tous les drapeaux par sortie et pose `lastStateTime = now + delay`, où delay vaut 0–25 min au hasard pour les groupes normaux (60 s minimum au démarrage de la mission) et 0 (20 s au démarrage) pour les urgents (`57288-57312`, `57569-57664`).
Ce décalage aléatoire en hangar est le principal désynchroniseur des lancements IA.
Les vols de supply Red attendent plus longtemps quand peu de joueurs Blue sont en ligne : ×1,5 avec 0 joueur, ×1,3 avec 1 (PvE seulement) (`68835-68843`).

### Spawn (preparing → takeoff)

`_processAirFreshSpawn` appelle d'abord `clearWreckage` sur la zone cible (`68462`), choisit le template, puis résout un spawn au parking (`68468-68494`).
`_resolveAirbaseSpawn` utilise `AIRBASE:FindByName`, `IsAirdrome/IsHelipad/IsShip`, `GetFreeParkingSpotsTable(terminalType)` de Moose et a besoin de `AirCount` places libres ; il renvoie les identifiants de places (`60507-60544`) ; les avions d'une zone sans places propres retombent sur `_resolveParkingWithBelonging` (un aérodrome voisin listé dans `AirbaseBelonging`) (`68490-68492`, `57832`).
Le spawn lui-même est `SPAWN:NewFromTemplate(tpl, resolved, alias, true):InitSkill(...):OnSpawnGroup(cb)` de Moose, puis `SpawnAtParkingSpot(airbase, spots, takeoff)` avec repli sur `SpawnAtAirbase` (`68503-68507`, `68579-68582`) ; ces appels enveloppent `coalition.addGroup` avec un premier waypoint réécrit (détail dans « Ce que le spawn au parking de Moose écrit » plus bas).
Le niveau (skill) est `AiPlaneSkill` (Config) pour Red et toujours `"Excellent"` pour Blue (`68504`).
Le départ est à froid, sauf si le groupe est un vol de supply Blue (ou PvP) ou a `SpawnHot` (`68508-68509`).
Les avions sans parking ne sont pas spawnés (retour au hangar) ; les hélicoptères sans parking sont spawnés au sol dans la zone par `_spawnFromGroundAt` (`68611-68617`, `66786`).
Les spawns d'IA Blue appellent d'abord `_prepareBlueAiWarehouseSpawn` pour que l'entrepôt DCS contienne la cellule (`68580`).
Les hélicoptères de supply peuvent aussi décoller d'un FARP CTLD construit par un joueur (`_pendingSupplyFarpLaunch`, `SpawnAtAirbase(farpAb, Hot)`) (`68518-68553`).
Après un spawn réussi : `Spawned=true`, `state='takeoff'`, et un message d'intel `INTEL_AIR_STARTING_UP_AT` est diffusé quand le groupe est dans la zone d'origine (`68667-68697`).

### Ce que le spawn au parking de Moose écrit (pour le refaire sans Moose)

Requête de parking, `AIRBASE:GetFreeParkingSpotsTable(termtype, allowTOAC)` (`Moose_2026-10-11.lua:33755-33770`) : un seul appel DCS, `Airbase:getParking(true)` (le `true` demande à DCS les places libres seulement, `33597-33604`), puis deux filtres.
Filtre 1, type de terminal : chaque enregistrement DCS a un `Term_Type` ; avec `termtype == nil`, toutes les places sont acceptées sauf les points de spawn sur piste (16) ; sinon le type doit correspondre exactement ou appartenir à un composite — `OpenMedOrBig` (176) = 72 ou 104 ; `HelicopterUsable` (216) = 72, 104 ou 40 ; `FighterAircraft` (244) = 72, 104 ou 68 (abri) ; `FighterAircraftSmall` (344) ajoute les places pour petits chasseurs (`33324-33335`, `33943-33976`).
Filtre 2, « appareil au décollage ou à l'atterrissage » : une place dont le drapeau `TO_AC` est vrai est ignorée sauf si `allowTOAC` est vrai (`33760`).
Chaque place renvoyée est l'enregistrement Moose mis en cache, construit une fois à partir de `getParking(false)` : `TerminalID = Term_Index`, `Coordinate`/`Vec3 = vTerminalPos`, `TerminalType = Term_Type`, `DistToRwy = fDistToRW`, `TOAC`, plus `ClientSpot` quand un slot client de la mission démarre à moins de 2 m de la place (`33679-33724`).
Foothold ne garde alors que le nombre de places égal au nombre d'appareils de la patrouille et transmet leurs `TerminalID` (`60507-60544`).

`SPAWN:SpawnAtParkingSpot(airbase, spotIds, takeoff)` relit chaque identifiant (`GetParkingSpotData`, qui recalcule `Free` en comparant `getParking(false)` et `getParking(true)`), exige autant de places libres que d'unités, et appelle `SpawnAtAirbase(airbase, takeoff, nil, nil, nil, parkingData)` (`21719-21749`, `33728-33754`, `33771-33782`).
`SPAWN:SpawnAtAirbase` modifie ensuite la table du groupe (une copie du template de l'éditeur) (`21486-21718`) :

| Champ | Valeur écrite | Code |
|---|---|---|
| `route.points[1].airdromeId` | L'identifiant de l'aérodrome pour un aérodrome ; nil sinon. | `21508-21518` |
| `route.points[1].helipadId` et `.linkUnit` | L'identifiant de l'aérodrome pour un FARP/héliport ou un navire ; nil pour un aérodrome. | `21510-21516` |
| `route.points[1].type` / `.action` | À froid : `"TakeOffParking"` / `"From Parking Area"` ; à chaud : `"TakeOffParkingHot"` / `"From Parking Area Hot"` ; piste : `"TakeOff"` / `"From Runway"` ; en l'air : `"Turning Point"` / `"Turning Point"`. | `21520-21521`, `29382-29387` |
| `route.points[1].x`, `.y`, `.alt` | Position de la première place de parking (`alt` d'abord mis à 0, puis à la hauteur de la place). | `21519`, `21702-21704` |
| `units[i].x`, `.y`, `.alt` | Position de la place de parking `i` (`Coordinate.x`, `.z`, `.y`). | `21686-21690` |
| `units[i].parking` | `TerminalID` (le `Term_Index` DCS) de la place `i`. | `21695-21699` |
| `units[i].parking_id` | Effacé (nil) ; Moose ne le renseigne pas. | `21696` |
| `x`, `y` du groupe | Position de la première place. | `21705-21706` |
| `uncontrolled` | Le drapeau uncontrolled du spawner (false ici). | `21707` |
| `parked` (drapeau privé de Moose sur le template) | true, pour qu'un second appel ne re-gare pas. | `21671-21672` |

Quand aucune liste de places explicite n'est donnée, la même fonction cherche elle-même des places avec `FindFreeParkingSpotForAircraft` (type de terminal choisi d'après les attributs du groupe : hélicoptères `HelicopterOnly` puis `HelicopterUsable`, bombardiers/transports/ravitailleurs/AWACS `OpenBig` puis `OpenMedOrBig`, les autres `FighterAircraft`, avec un balayage d'obstacles de 50 m sur les unités et les statics) ; sur les FARP et les navires (« autoparking »), elle met chaque unité sur la première place et laisse DCS les répartir (`21529-21620`).
Avec trop peu de places, elle se replie sur un départ en l'air à 500–2 500 m au-dessus du terrain (100–1 000 m pour les hélicoptères), ce que Foothold évite en passant toujours une liste explicite et en vérifiant d'abord le nombre (`21635-21650`).

Enfin `SpawnWithIndex` → `_Prepare` et `DATABASE:Spawn` terminent la table et appellent DCS (`21246`, `22179-22225`, `12903-12923`) :

- `name` = le nom de spawn construit à partir de l'alias ; `groupId = nil` ; chaque `units[i].unitId = nil` et `units[i].name = "<group name>-<NN>"` ; `lateActivation = false` ;
- `skill`, `livery_id`, `onboard_num`, `heading`/`psi` optionnels par unité, et `hiddenOnMFD`, `hiddenOnPlanner`, `hidden`, `communication`/`frequency`/`modulation` du groupe, selon les appels `Init…` utilisés ;
- `CoalitionID`, `CountryID`, `CategoryID` sont retirés de la table et passés en arguments : `coalition.addGroup(countryId, categoryId, template)`.

Donc, sans Moose, un spawn au parking se fait ainsi : `Airbase.getByName(name):getParking(true)` → filtrer sur `Term_Type` et `TO_AC` → prendre N places → écrire les champs du tableau ci-dessus dans une copie du template avec des noms neufs et sans identifiants → `coalition.addGroup`.

### Tasking après le spawn

`_onFreshAirSpawn` (le callback `OnSpawnGroup`) aiguille selon le rôle (`68330-68442`) :

| Rôle | Appel | Ligne |
|---|---|---|
| Patrouille CAP | station choisie par `Frontline.PickStationNearZone(targetzone, side, ±35 nm, …)`, puis `_assignCapTask` avec une orbite de 30–40 nm | `68336-68351` |
| Attaque CAP | station par `Frontline.PickCapStationFromOrigin(origin, target, side, 100, 35/25 nm)`, orbite de 35–45 nm | `68353-68366` |
| Hélicoptère de supply | `_routeFreshSupplyHelo` 2 s plus tard | `68368-68391` |
| Avion de supply | `_routeFreshSupplyPlane` 2 s plus tard | `68393-68406` |
| Avion CAS | `bc:EngageCasMission(targetzone, …, Altitude, landUnitID, side, …{routeSpeedIasKnots=300})` | `68408-68414` |
| Hélicoptère CAS | `bc:EngageHeloCasMission` (ou `EngageHeloCasAtPoint` pour une réponse à une position ennemie) | `68416-68429` |
| SEAD | `bc:EngageSeadMission` | `68430-68432` |
| Frappe de piste | `bc:EngageRunwayBombing(homeAirbase, targetzone, …)` | `68434-68435` |
| Anti-navire | `bc:EngageAntiShipMission` | `68437-68438` |

### Arrivée d'un vol de supply

Quand toutes les unités d'un vol de supply sont posées et qu'au moins une est dans la zone cible (`Utils.someOfGroupInZone`) : si la zone est neutre, `tg:startPendingCaptureFromAircraft(side, group, captureDelivery, …)` lance la capture ; si elle est amie, `bc:_applyRegularSupplyDelivery(tg, side, now, paid)` livre les supplies (réparation/upgrade — thème capture) (`67803-67861`).
Pour Blue (et Red en PvP) avec la logistique d'entrepôt, une livraison ajoute aussi 20 objets d'entrepôt (`AIDeliveryamount`) pour un hélicoptère ou 50 pour un avion (`67819-67827`, `67863-67871`).
Le résultat est rapporté au Director (`_recordDirectorRegularSupplyOutcome` 'delivered'/'aborted') (`67830-67834`).
Un hélicoptère de supply Red qui se pose dans une zone amie alors qu'un joueur Blue est proche attend 60 s avant de livrer (PvE) (`67810-67816`).
La FSM revient ensuite à `inhangar` et `_scheduleLandingCleanup(gr)` retire l'appareil (`67836-67873`).
Une cible invalide (tenue par l'ennemi, suspendue) annule la livraison (`67791-67808`).
Le supply normal de Blue coûte des crédits en PvE quand des joueurs sont en ligne : `min(blueZoneCount × 10, 100)`, vérifié à l'éligibilité et débité au spawn (`66386-66403`, `68370-68374`).

### RTB, atterrissage, pertes

Les appareils hors supply qui se posent dans leur zone d'origine ou de récupération CAP retournent à `inhangar` ; en PvE, chaque atterrissage Red de ce type crédite Red de 100 (`67895-67922`).
Un avion en attaque/patrouille qui se pose ailleurs est lui aussi recyclé immédiatement ; les hélicoptères attendent `landedDespawnTime` (`67924-67934`).
La FSM ne tient aucune comptabilité des pertes par unité : un groupe ne devient `dead` que lorsque son groupe DCS a disparu ou est de taille 0 (`68753-68787`) ; les pertes partielles lui sont invisibles.
Un hélicoptère de supply Blue qui meurt entre 60 et 120 s après le spawn est relancé une fois sans cargo (`68759-68781`).
Un hélicoptère de supply encore dans sa zone d'origine 280 s après le décollage est détruit et remis en file sans cargo (`67599-67606`).

### Restauration des sorties aériennes après un redémarrage du serveur

Ce qui est sauvegardé par sortie aérienne vivante (`_buildAirPersistenceRecord`, `25441-25560`) : nom du commander, identifiant de capability du Director / emplacement dérivé / génération d'instance, zones d'origine et cible, camp, `mission`, `MissionType`, catégorie d'unité, jeu de templates et template réellement utilisé, plus des extras selon le rôle (altitude CAS, point d'attente CAP, distance d'orbite, tampon, état de retour SAM et de retour à la base, retask d'assistance CAP, drapeaux de retour à la base et de boutique du supply, phase d'advance capture et point d'attente).
La sauvegarde les répartit en `inair` (position, cap, nombre de vivants, temps passé dans l'état) et `spawnNowTakeoff` (les vols encore au sol : ils sont simplement relancés) (`29604-29610`, `29788-29790`).
`bc:init()` planifie `_runPendingAirAiRestore` 5 s après le démarrage ; elle attend (jusqu'à 12 × 5 s) l'amorçage du dynamic-hybrid, et retient la liste des décollages jusqu'à ce que la persistance de l'entrepôt soit chargée (`30285`, `29573-29602`, `29892-29919`).

Association d'un enregistrement sauvegardé à un commander (`_resolveAirPersistenceCommander`, `29389-29501`) : d'abord par identifiant de capability du Director (la capability est réactivée en commander, `29301-29387`) ; sinon par nom exact (un suffixe `_retasked_…` retiré) ; sinon, pour les groupes dynamic-hybrid, par nom de base avec un score sur origine/cible/rôle/camp/mission ; sinon par score de métadonnées (origine 3, cible 4, camp 3, mission 3, MissionType 3, catégorie 2, template 2), accepté à partir de 10 points ; les enregistrements de supply n'utilisent jamais le repli par métadonnées.
Le commander retenu reçoit les extras sauvegardés, `state = 'preparing'` avec `lastStateTime = now − 999999` pour que le prochain `update` spawne aussitôt, et, pour un enregistrement en vol, `_pendingInAirRestore = saved` (`29741-29780`, `29825-29870`).
Un enregistrement de décollage est abandonné quand la zone d'origine a changé de camp, ou qu'elle est entièrement suspendue et que le groupe n'est ni un supply de boutique ni un supply régulier autorisé (`29637-29641`).

`_processAirRestoredSpawn(restoreData, …)` (`68044-68265`), appelée depuis l'état `preparing` à la place du spawn au parking :

1. Retour au hangar quand la position sauvegardée ou le template manque, ou quand un avion CAS/SEAD a été sauvegardé à plus de max(2 × distance origine–cible, 100 NM) de son origine comme de sa cible (`68045-68078`, `67025-67043`).
2. Ajustement du point de spawn : le CAS est remis sur son axe origine→cible (`_getRestoreCasSpawnPoint`) ; un hélicoptère ou un avion de supply sauvegardé en approche finale est ramené à 1 NM avant le point d'approche, la destination étant la cible, ou l'origine quand il rentrait ou que la cible n'est plus valide (`68079-68107`, `59692-59709`).
3. Altitude : celle qui a été sauvegardée ; les hélicoptères sont bornés à 60–300 m AGL (1 500 ft AGL quand aucune altitude n'a été sauvegardée) (`68109-68124`).
4. Réécriture du template, sans parking : chaque unité est translatée/pivotée autour de l'unité 1 jusqu'à la position et au cap sauvegardés et reçoit `alt`, `heading`, `psi` ; la route est remplacée par deux waypoints « Turning Point », le point de spawn et un point 2 NM devant, tous deux `alt_type = "BARO"` à l'altitude sauvegardée et à la vitesse du template (380 m/s par défaut) (`68126-68173`).
5. `SPAWN:NewFromTemplate(tpl, template, alias, true):InitSkill(…):OnSpawnGroup(cb):Spawn()` → `coalition.addGroup` en l'air (`68183-68245`).
6. Dans le callback : `state = 'inair'`, `lastStateTime = now − saved time in state`, unités en surplus détruites depuis le dernier indice pour qu'il n'en reste que `aliveCount`, poids du cargo appliqué aux avions, et `_assignRestoredAirMission` planifiée 0,5 s (CAS) ou 2,5 s plus tard (`68199-68242`).
7. `_assignRestoredAirMission` attend d'abord (nouveaux essais à 0,5 s, jusqu'à `idleZoneWakeHoldSec`) le réveil des zones « idle » de l'empreinte de la cible, puis appelle `_assignMissionAfterInAirRestore`, qui réémet le tasking normal du rôle depuis la position courante avec les variantes « restore direct » ; « Not available » est retenté jusqu'à 10 fois à 0,5 s (`68008-68042`).

Il n'y a aucune restauration du carburant, de l'armement ni des dégâts : le vol revient avec l'emport complet du template et seul le nombre d'unités est conservé.

## 3. Éligibilité au spawn : comment un groupe décide qu'il peut décoller

### Mécanisme

`GroupCommander:evaluateSpawnEligibility` est la porte unique, appelée aux transitions `inhangar`, `preparing` et `dead` (`66102-66597`).
Refus génériques, dans l'ordre : zone d'origine inactive (`66111`) ; envoi de supply désactivé pour le camp (`66121-66125`) ; `ShopLaunchOnly` sans demande de boutique (`66127`) ; piste de l'origine bloquée (`isRunwayPlaneSpawnBlockedForGroup`, `66131`) ; zone d'origine suspendue, sauf missions d'attaque/patrouille et supply autorisé (`66135-66156`) ; **un joueur Blue près de la zone d'origine Red** (`zone.BlueIsNear`, ou `BluePlaneIsNear` pour les avions) — le groupe Red repart alors pour une nouvelle attente en hangar afin que rien ne spawne devant un joueur (`66158-66165`) ; zone cible inconnue, suspendue ou inactive (`66167-66171`) ; `NoAIBlueCapture` interdit aux IA Blue de capturer des zones neutres en PvE (`66172-66179`).
Ensuite : le jeu de templates doit contenir un groupe pour le camp actuel de la zone, et `self.side` doit égaler le camp de la zone d'origine (`66209-66222`) ; `condition` / `Bluecondition` / `Redcondition` (`66224-66238`).
Distance au front : `Frontline.ZoneDistToFrontNm(targetzone)` ; les missions hors supply sont refusées quand la cible est plus loin derrière le front que `frontlineDistanceLimitBlue` (30 nm) / `frontlineDistanceLimitRed` (60 nm), et les CAP en plus par `capRearlineNmBlue` (30) / `capRearlineNmRed` (60) (`66245-66266`, `8508-8509`, `8522-8523`).

Par mission :

| Mission | Règle | Code |
|---|---|---|
| `attack` + CAS/SEAD/RUNWAYSTRIKE/ANTISHIP | la cible doit être tenue par l'ennemi (pas neutre) ; le SEAD exige `HasSeadTargets` ; le nombre de groupes actifs de ce rôle doit être sous la limite du rôle | `66271-66361` |
| `supply` | cible neutre : seul un groupe urgent peut la capturer (et pas si Red l'a déjà capturée avant, sauf `ForceUrgent`) ; cible amie ou neutre : seulement si `tg:canRecieveSupply()` ; Blue paie (voir §2) | `66363-66411` |
| `patrol` + CAP | la cible doit être amie ; nombre de CAP actives sous la limite ; la cible doit se classer dans la « fenêtre CAP » des zones les plus proches des joueurs | `66413-66497` |
| `attack` + CAP | la cible doit être tenue par l'ennemi ; même limite et même logique de classement | `66499-66575` |
| `attack` sans MissionType (convois, artillerie, navires) | cible tenue par l'ennemi | `66578-66582` |
| `patrol` sans MissionType | cible amie | `66584-66588` |

Le choix de la cible est donc statique : chaque enregistrement nomme une seule `targetzone`, et le « graphe » est l'ensemble des paires origine→cible écrites à la main ; un enregistrement ne se déclenche que si la possession de ses deux extrémités correspond à sa mission.
(Le Director peut re-tasker ou choisir parmi les enregistrements ; hors périmètre.)

### Plafonds de sorties IA simultanées

Limite des CAP Red selon le nombre de joueurs Blue et `CapDifficulty` (Config, `"easy"|"medium"|"hard"`) : medium = 1,2,3,4,4,5,5,5,5,5,6,7,7 pour 0…12+ joueurs ; easy plafonne à 6, hard à 8 (`60867-60961`).
Limites de frappe Red (`CasDifficulty`, `SeadDifficulty`, `RunwayStrikeDifficulty`, `AntiShipDifficulty`) : medium = 1 (≤1 joueur), 2 (≤3), 3 (4), 4 (5+) avions ; plus un emplacement d'hélicoptère supplémentaire par rôle (`60963-61020`, `66298-66326`).
Support IA Blue (`FriendlyCapSupport`, `FriendlyCasSupport`, `FriendlySeadSupport`) : medium = 1 groupe avec 0–1 joueur, 0 au-delà ; easy = 2/2/1 ; hard = 0 (`61022-61110`).
Chaque table peut être remplacée par des listes de « paliers » (`CapLimitStages`, `RedCasLimitStages`, `BlueCapSupportStages`, … = `{ {player=n, amount=m}, … }`) (`60825-60836`).
Les nombres de joueurs viennent d'instantanés de `refreshPlayers()` (`getBluePlayersCount`, `getBlueCasPlayersCount`, `getRedCasPlayersCount`) (`60619-60647`).
Les comptes de groupes actifs sont tenus dans des seaux incrémentaux (`_capDelta`, `_nonCapDeltaStrike`, `getActiveCAPCount`, `getActiveStrikeCount`) plutôt que recomptés (`61114-61961`).
Une CAP/frappe refusée reçoit une heure de nouvel essai au lieu d'un cycle de hangar normal : CAP 5 min +2 min par refus jusqu'à 15 min ; CAS/SEAD 4 min +4 jusqu'à 20 avec une fenêtre aléatoire de 4 min ; frappe de piste 15–25 min (`57104-57111`, `57324-57347`).
Les groupes CAP Red refusés d'une même mission forment une « cohorte » classée (les plus proches des joueurs d'abord) avec 2–5 min d'écart, pour que les candidats suivants ne doublent pas le premier (`57113-57262`).
Les zones CAP sont classées par `getClosestCapZonesToPlayers` (distance aux joueurs, bonus d'adjacence à l'ennemi) et seules les `limit − current` premières zones peuvent lancer (`66432-66470`, `65609`).

## 4. Comportement des CAP en vol

### Mécanisme

`Frontline.SetUpCapTask` construit un racetrack : deux points à 10–15 km de part et d'autre de la station, perpendiculaires à l'axe de route quand il est donné, ramenés en arrière pour que le tronçon reste à `bufferNm` du centre de la zone ennemie la plus proche (`35751-35830`).
`Frontline.AssignCapRoute` émet une tâche DCS `Mission` brute via `controller:setTask` : waypoint 1 avec une tâche en route `EngageTargets` (`maxDist` = portée d'orbite 30–45 nm, types de cibles `Planes`, ou `Planes`+`Helicopters`, ou classes chasseur/bombardier quand `InvisibleA10` est activé), waypoints p1 et p2 à 280 m/s, une `ControlledTask` qui enveloppe une `Orbit` (racetrack, 250 m/s) avec une condition d'arrêt `duration`, puis un waypoint d'atterrissage sur l'aérodrome d'attache (`35931-35999`).
Une tâche `WrappedAction`/`Script` sur le waypoint d'orbite rappelle `CapRef[name]:_capOrbitEvent(groupId, version)` pour horodater le début de l'orbite ; l'échéance est `now + duration` (`35978-35986`, `67206-67213`).
`SetUpCAP_DefaultAA` règle les options du contrôleur : pas d'air-sol, RTB sur bingo, RTB à court de missiles, réaction à la menace « bypass and escape », portée d'attaque des missiles « target threat estimate », largage des réservoirs vides seulement (`9077-9089`).
La probabilité de cibler les hélicoptères vient de la Config `ChanceAiAttackHelo` (PvE, Red seulement) / `PvPChanceAiAttackHelo` ; la CAP Blue en PvE engage toujours les hélicoptères (`35764-35776`, `Foothold Config.lua:842-854`).
À chaque mise à jour `inair`, `_checkCapReturnHome` renvoie la CAP à la base quand elle n'a plus de munitions air-air (`_airGroupHasMissionAmmo`) ou quand sa zone cible a changé de camp/a été suspendue (`67313-67333`, `67295-67311`).
Le RTB est une route Moose à deux waypoints (`COORDINATE:WaypointAirTurningPoint` + `WaypointAirLanding`, `GROUP:Route`) vers la zone de récupération valide la plus proche trouvée par `bc:_findCapRecoveryZone` (`67137-67189`, `67261-67293`).
`_checkCapSamReturn` refait le tronçon d'origine si la menace SAM qui avait déplacé la CAP a disparu, toutes les 30 s, seulement si tous les appareils ont ≥ 40 % de carburant (`67215-67259`).
« Assistance CAP » : quand une CAP Red décolle, une CAP Blue déjà en vol peut être re-taskée vers sa zone cible après 120–300 s (`GlobalSettings.capAssist*`, `8510-8520`, `67581-67584`, `61582`).

### Assistance CAP (CAP Blue re-taskée contre une CAP Red), PvE seulement

Réglages : `capAssistEnabled = true`, `capAssistCoverageNm = 30`, `capAssistDelayMinSec = 120`, `capAssistDelayMaxSec = 300`, `capAssistTargetZoneCooldownSec = 300` (`8510-8520`).
Déclencheur : `_tryScheduleBlueCapAssistFromRedCap(redGc)` quand une CAP Red décolle ; elle exige au moins une CAP Blue en vol, aucun délai de récupération et aucune demande en attente sur la zone cible de cette CAP Red (`61582-61607`).
Mode : `patrol` quand la zone cible de la CAP Red est Blue (Red attaque une zone Blue), `attack` sinon (`61273-61280`).
Station voulue : patrol = `Frontline.PickStationNearZone(zone, 2, −35 NM, …, safe 30 NM)` ; attack = `Frontline.PickCapStationFromOrigin(blueOrigin, zone, 2, 100, 25 NM)` calculée par candidat (`61287-61305`).
Déjà couvert : si une CAP Blue affectée à cette zone a son point d'attente actuel à moins de 30 NM de la station voulue (patrol) ou qu'une couverture d'attaque équivalente existe, rien n'est planifié et la zone reçoit un délai de récupération de 60 s (`61307-61339`, `61613-61630`).
Candidat : la CAP Blue en vol, qui ne rentre pas à la base, pas déjà re-taskée pendant cette sortie, « prête à être re-taskée » (en vol, avec un `_capRetaskCapabilityScore` positif = 12 points par missile air-air restant, plafonné à 12 missiles par type, plus jusqu'à 20 points de coups de canon, comptés seulement pour les types d'armes du profil de son template — et une fraction de carburant minimale d'au moins 0,40 sur tout le vol, `19839-19878`), dont le point d'attente actuel est le plus proche de la station voulue (`61376-61434`, `19875-19878`).
Une demande `{token, executeAt = now + random(120, 300), assistMode, blueGroupName}` est stockée par zone cible et exécutée par `_executeBlueCapAssistForTargetzone` (`61640-61650`).
À l'exécution, les vérifications sont refaites (une CAP Red toujours `inair` sur cette zone, toujours pas de couverture, candidat toujours valide, sinon un autre candidat est choisi) ; puis le groupe Blue reçoit simplement un nouveau `_assignCapTask` à la nouvelle station avec une portée d'orbite de 35–40 NM (attack) ou 30–40 NM (patrol), est marqué `_capAssistRetaskedThisSortie` et `_capAssistRetaskedTargetzone`, et la zone reçoit le délai de récupération de 300 s ; tout échec pose un délai de 60 s (`61453-61580`).
Le retask est sauvegardé et restauré avec la sortie (`25476-25477`, `29749-29750`).

### Classement des cibles CAP (`CapTargets`, `CapRef`, `getClosestCapZonesToPlayers`)

`BattleCommander:buildCapSpawnBuckets()` reconstruit quatre tables globales à partir de chaque commander CAP aérien et de chaque capability CAP du Director pas encore activée (`30667-30759`) :

- `CapTargets[side][mission][targetZone] = { candidates = {{name, origin, dist, state, unitCategory, capability}, …}, ranksByName = {name → rank} }`, les candidats d'une cible étant triés par `_sortCapBucketCandidates` (la distance origine→cible issue de `ZONE_DISTANCES` est le `dist` stocké) (`30683-30699`, `30717-30736`) ;
- `CapSpawnBucket[side][mission][targetZone]` = le même ordre sous forme de liste de noms, et `CapRankIndex[name] = {side, mission, target, rank}` (`30732-30734`) ;
- `CapRef[name]` = l'objet `GroupCommander` vivant pour un nom de CAP, aussi tenu à jour quand une capability du Director est activée ou éliminée ; c'est lui que la tâche `Script` de début d'orbite et les cohortes de refus utilisent pour retrouver le commander à partir d'un nom (`30698`, `26450`, `26752`, `35985`, `57244`) ;
- `CapAnchors[side][mission]` = chaque zone qui est la cible d'au moins un enregistrement CAP, utilisée comme ancres de repli ; `CapAnchorRowByZoneName[zone]` = la ligne de `ZONE_DISTANCES` de cette zone (`30741-30756`).

Elle est reconstruite après chaque capture et neutralisation (thème zones) et se termine en rééchelonnant les délais de hangar des CAP (`30757-30758`).

`getClosestCapZonesToPlayers(missionType, side, …)` classe les zones cibles d'un camp et d'une mission (`65609-65780`) :

1. Ancres = les zones de `playerZoneSpawn` (nom du joueur → zone où l'avion de ce joueur a démarré en dernier ; A-10A/C, AV-8B et Hercules/C-130J ne sont pas enregistrés) qui appartiennent à **l'ennemi du camp en patrouille** pour `patrol`, ou au camp qui agit pour `attack`, actives, éveillées et visibles ; sans ancre de ce genre, toutes les zones cibles CAP (`CapAnchors`) sont utilisées (`65621-65639`, `101090-101099`).
2. Candidats = clés de `CapTargets[side][mission]` actives, éveillées, visibles et du bon propriétaire (son propre camp pour patrol, l'ennemi et non neutre pour attack) (`65686-65711`).
3. Score = distance moyenne du candidat à toutes les ancres (`ZONE_DISTANCES`), multipliée par 0,6 quand le candidat a un voisin ennemi dans le graphe de connexions ; tri croissant (`65713-65727`).
4. Le résultat géométrique est mis en cache par (camp, mission, version du seau, génération de l'état des cibles, ensemble d'ancres) pendant au moins 300 s (`65647-65660`, `65729-65736`).
5. Elle renvoie aussi `capMeta = {limit, currentCap, capLeft = max(1, limit − currentCap), targets, enemyAdj}` (`65738-65752`).

Usage dans la porte (`66442-66475`) : la cible du groupe doit se classer dans `capWindow = min(#ranked, capLeft)`, ou dans les `max(3, capWindow)` premières quand elle a un voisin ennemi ; un groupe Red refusé reçoit le refus de limite aérienne (timers de nouvel essai du §3), un groupe Blue refusé retourne au hangar.
Ensuite, dans la liste de candidats propre à la cible, le groupe compte les candidats mieux classés déjà en `preparing` pour que deux groupes ne prennent pas le même emplacement (`66465-66475`).
Pour Red en PvE, la liste classée passe par le Director (`rankCapZones`) ; Blue et PvP utilisent `getCapSpawnRankingForSide`, une variante en miroir qui connaît le Director (`66435-66443`, `30848`).

## 5. Tasking des frappes (CAS, SEAD, frappe de piste, anti-navire)

Les quatre suivent le même schéma : calculer les waypoints depuis la position courante du groupe, construire des tables de tâches DCS, les envelopper avec `COORDINATE:WaypointAirTurningPoint(...)` / `WaypointAirLanding(...)` de Moose et les pousser avec `GROUP:Route(wp, 1)` (une tâche `Mission` posée sur le contrôleur après 1 s), puis `bc:setDefaultAG(group)` pour les options (`35309-35429`).
SEAD : `buildSeadIngressPlan` choisit les émetteurs viables et un point d'ingress ; la route est départ → montée optionnelle → point d'engagement (tâche = `EngageTargets {'SAM elements','Air Defence'}` + une tâche d'attaque par unité viable issue de `getAttackTask`) → cible → point d'approche à 20 nm → atterrissage ; un `EngageTargets` d'autodéfense contre les avions à moins de 15 nm (Red) / 20 nm (Blue) accompagne chaque tronçon (`35322-35423`).
`gmoose:TaskFunction("BattleCommander.MarkSeadIngressCommitted", routeState)` et `"BattleCommander.MarkAirReturnHome"` sont des callbacks de script déclenchés à des waypoints pour mettre à jour les drapeaux de la FSM (`35377`, `35391`).
Frappe de piste : 4 waypoints le long de la ligne droite vers l'aérodrome cible (attaque à 75 % de la distance, 450 kt), tâche `BombingRunway {runwayId, weaponType=AnyBomb, expend=ALL, groupAttack=true}` (`35431-35521`) ; les templates à trois appareils emportent des BetAB-500 / Durandal (`MA_Setup_CAv2.lua:1145-1150`).
Les avions de frappe de piste Blue sont rendus invisibles à l'IA avec la commande `SetInvisible` (`35512-35514`).

### Les tables de tâches, telles que construites

Ce que produisent les fonctions d'aide de Moose, pour pouvoir écrire les tables à la main.
`GROUP:Route(points, delay)` = `controller:setTask({id='Mission', params={airborne=<is air>, route={points=points}}})` après `delay` secondes (`Moose_2026-10-11.lua:27090-27098`, `27177-27186`, `26038-26054`).
`COORDINATE:WaypointAirTurningPoint(altType, speedKmh, tasks, name)` = `{x, y=<z>, alt, alt_type, type="Turning Point", action="Turning Point", speed=<m/s>, speed_locked=true, ETA=0, ETA_locked=false, name, task={id="ComboTask", params={tasks=tasks}}}` ; `WaypointAirLanding(speedKmh, airbase)` est identique avec `type="Land"`, `action="Landing"`, `speed_locked=false` et `airdromeId = <airbase id>` (ou `helipadId` + `linkUnit` pour un FARP ou un navire) (`Moose_2026-10-11.lua:18720-18764`, `18777-18779`).
`GROUP:EnRouteTaskEngageTargets(dist, types, prio)` = `{id='EngageTargets', params={maxDistEnabled=true, maxDist=dist, targetTypes=types, priority=prio}}` (`Moose_2026-10-11.lua:26804-26815`).
`GROUP:TaskFunction("Fn", args…)` = une `WrappedAction` dont l'action est une commande `Script` qui exécute `Fn(GROUP:Find(...), unpack(args))`, les arguments étant rangés dans une table d'état de Moose indexée par le groupe (`Moose_2026-10-11.lua:26951-26964`).
`getAttackTask(name, expend, altitude)` renvoie, pour un nom de groupe, `{id='AttackGroup', params={groupId, expend, weaponType=Weapon.flag.AnyWeapon, altitudeEnabled=(altitude~=nil), altitude, groupAttack=false}}`, et pour un nom de static ou d'unité `{id='AttackUnit', params={unitId, expend, weaponType=AnyWeapon, groupAttack=true, altitudeEnabled, altitude}}` (`36557-36597`).
`setDefaultAG(group, search)` règle les options du contrôleur `JETT_TANKS_IF_EMPTY=true`, `PROHIBIT_JETT=true`, `RTB_ON_BINGO=true`, `REACTION_ON_THREAT=BYPASS_AND_ESCAPE`, `SILENCE=true`, `RADAR_USING=FOR_CONTINUOUS_SEARCH` quand `search`, et `RTB_ON_OUT_OF_AMMO = 2147485694 + 30720 + 4161536` (un masque de drapeaux d'armes) (`36613-36624`).

`EngageCasMission(targetZone, groupName, expend, weapon, altitudeFt, landAirbaseId, side, approachFrom, restoreDirect, opts)` (`36091-36323`) :

- tâche d'attaque : une `ComboTask` qui contient un `getAttackTask` par nom dans le `built` de la zone cible (plus le static d'entrepôt de la zone comme `AttackUnit`), `expend` valant par défaut `AI.Task.WeaponExpend.ONE`, avec surcharges optionnelles `weaponType`, `groupAttack`, `attackQtyLimit`/`attackQty` (`36112-36183`) ;
- tâche en route : `EngageTargets` avec `maxDist` de 20 NM (Blue) / 15 NM (Red) et types de cibles `{'Planes','Ground Units'}`, ou `{'Planes','Helicopters','Ground Units'}` pour Blue en PvE et pour Red sur un tirage `ChanceAiAttackHelo`, ou `{'Multirole fighters','Interceptors','Bombers','Ground Units'}` avec `InvisibleA10` (`36138-36158`) ;
- géométrie : axe du point de lancement (ou `approachFrom`) vers la première cible ; altitude = `Altitude` en pieds → mètres (6 000 m par défaut), sauf le CAS en Su-25 / Su-25T qui vole à une altitude aléatoire de 5 000–10 000 ft conservée toute la vie du groupe (`36185-36201`, `36211-36226`) ;
- waypoints, tous « Turning Point » : WP1 à la position courante (350 m/s sauf si une vitesse de route est donnée ; le CAS régulier passe 300 kt IAS), WP2 5 NM le long de l'axe avec la tâche en route, WP3 20 NM avant la cible avec la tâche en route + la `ComboTask` d'attaque, WP4 15 NM au-delà du départ le long de l'axe (ou 10 NM avant l'aérodrome de récupération quand le suivi du retour est actif) avec la tâche en route + le callback `MarkAirReturnHome`, puis un waypoint `Land` sur l'aérodrome `landAirbaseId` (300 kt) (`36280-36299`) ;
- après `Route` : `CommandSetUnlimitedFuel(true)` et `setDefaultAG(group, true)` (`36308-36322`).

`EngageHeloCasMission` (`36325-36472`) : option radar réglée sur 3 (`SetOptionRadarUsing(3)`), 300 ft AGL par défaut, 70 m/s ; tâche en route `EngageTargets{maxDist = 4 NM, targetTypes = {'Ground Units'}}` ; la même `ComboTask` d'`AttackGroup`/`AttackUnit` construite à partir de la garnison et de l'entrepôt de la zone, la géométrie visant le centroïde de la zone ; waypoints = un point de décollage brut `{type=TAKEOFF, action=FIN_POINT, speed=0, alt=0}` avec l'option d'atterrissage vertical préféré, « CAS Mid 1 NM » (tâche en route), « CAS Approach 5 NM » avant le centre de la zone (en route + attaque + un callback `MarkHeloCasIngressCommitted`), éventuellement « CAS RTB Approach » 3 NM avant la base (callback `MarkAirReturnHome`), puis soit un waypoint `Land` sur un aérodrome, soit un turning point qui porte `{id='Land', params={point=<home vec2>, durationFlag=false, combatLandingFlag=false}}` ; puis `setDefaultAG(group)` (`36338-36471`, `Moose_2026-10-11.lua:26688-26703`).
Elle renvoie un `routeState` (`committed` une fois à moins de 5 NM de la cible) que la FSM utilise pour savoir si l'attaque a commencé (`36369-36378`).

`EngageAntiShipMission` (`35524-35586`) : cible = les trois groupes `built` les plus proches de la zone, au plus, dont la première unité est un navire ; chacun reçoit `{id='AttackGroup', params={groupId, expend = ALL by default, altitudeEnabled=true, altitude = 4 572 m or the given altitude, weaponType?}}` dans une seule `ComboTask`.
La route vient de `getDefaultWaypoints` : un `{id='Mission', params={route={points={WP1 at the current position (350 m/s), WP2 over the first target (250 m/s), Land at the airbase}}}}` brut où WP1 et WP2 portent tous deux la `ComboTask` d'attaque (`36979-37002`) ; un `EngageTargets{maxDist = 30 NM, targetTypes = {'Ships'}}` est ajouté aux tâches des points 2 et 3 quand ils ont une liste de tâches, et le tout est posé directement avec `controller:setTask`, puis `setDefaultAG` (`35566-35585`).

Route de l'avion de supply, `_assignPlaneRoute` (`57887-57920`, plan dans `_resolvePlaneRoutePlan`, `59660-59690`) : trois waypoints poussés avec `GROUP:Route(wp, 1)` — un point de décollage brut à la position courante, un turning point « Approach » 20 NM avant l'aérodrome cible sur la ligne depuis le départ (BARO, altitude de croisière = `Altitude` ou 10 000 ft, 250 kt IAS convertis en TAS), et un waypoint `Land` sur l'aérodrome de la zone cible (50 m/s) ; aucune tâche sur aucun d'eux.
L'aérodrome cible est le `airbaseName` de la zone ; si sa coalition DCS diffère du camp de la zone, il est d'abord forcé en neutre (`SetCoalition(0)`) pour que l'atterrissage soit accepté (`59664-59668`).
Sauf indication contraire, la fonction retire aussi 50 objets de l'entrepôt d'origine (`57915-57917`).

## 6. GroupCommander — machine à états de surface (convois, artillerie, navires)

États pour `type='surface'` : `inhangar → preparing → enroute → atdestination → inhangar`, plus `dead` (`70792-70844`).
Les timers utilisent la même table ; ralentissement supplémentaire selon le nombre de joueurs Blue pour les convois de supply Red et tous les convois d'attaque : ×3 avec 0 joueur, ×2,5 avec 1, ×2 avec 2, ×1,5 avec 3, ×1,25 avec 4 (attaque seulement) (`65840-65870`).

### Spawn et route

`_processSurfaceFreshSpawn` construit d'abord la route ; s'il n'existe aucune route, le groupe est retiré ou rendu au Director (`70545-70580`).
Les routes viennent des fonctions d'aide `dc` (« DynamicConvoy ») et sont mises en cache par paire origine>cible (`10244-10249`, `11694`, `11932`).
`dc.BuildAttackConvoyRoute` : refuse les paires distantes de plus de 40 nm (`ZONE_DISTANCES`) ; point de départ = la sous-zone d'origine la plus proche de l'accroche de route ou de la cible ; `land.getClosestPointOnRoads("roads", …)` donne l'entrée et la sortie sur route ; les waypoints sont départ (Off Road) → début de route (`on_road`) → fin de route → puis chaque sous-zone cible visitée de façon gloutonne, la plus proche d'abord, à mi-vitesse dans une formation aléatoire (Cone/Diamond/Vee) (`11024-11176`).
La vitesse par défaut est de 20 m/s, portée à 60 km/h pour Red (`dc.DEFAULT_SPEED`, `dc.RouteTaskForSide`, `10254-10288`).
Conventions du `.miz` : les sous-zones nommées `<Zone>-<number>` sont les points de patrouille/d'arrivée (`1423-1442`) ; les accroches de route sont des zones nommées `<Zone>-road` et `<Zone>-road-0…9`, calées sur la route la plus proche dans la zone d'accroche (`10975-10999`).
Le groupe est spawné au point de départ avec `SPAWN:NewFromTemplate(tpl, name, self.name, true):InitGroupHeading(...)` de Moose et `SpawnFromPointVec2` (→ `coalition.addGroup`), et 5 s plus tard la route est poussée avec `controller:popTask()` / `controller:pushTask(selectedTask)` bruts (`70592-70636`).
Un départ de convoi ne déclenche des messages d'intel que par hasard : à chaque mise à jour `enroute`, un tirage à 2 % (`math.random(0,100) > 98`) envoie à Blue le texte et le son « enemy supply/attack/artillery convoy inbound » une fois par sortie (`69842-69864`).

### Arrivée

`enroute → atdestination` quand une unité quelconque est dans la zone cible (`69818-69841`).
Convoi de supply dans une zone amie : après `landedDespawnTime` (60 s) il livre (`_applyRegularSupplyDelivery`) et est détruit (`69885-69975`).
Convoi de supply ou d'attaque dans une zone neutre : `tg:startPendingCapture(side, {kind="group", …, destroyOnFinish=true, stopGroup=true})` — le convoi lui-même devient la force qui capture (`69931-69953`, `70079-70103`).
Convoi d'attaque dans une zone ennemie : aucune action explicite ; les unités combattent avec leur IA DCS en parcourant la queue de sous-zones, et la FSM reste en `atdestination` jusqu'à ce que la zone change de camp ou que le groupe meure (`70061-70135`).
Un convoi Red qui arrive là où un joueur Blue est proche attend 60 s (`70070-70077`).

### Restauration des sorties de surface après un redémarrage du serveur

`_runPendingSurfaceAiRestore` (planifiée comme celle des avions) associe chaque enregistrement sauvegardé de `pending.active` à un commander et le passe à `_processSurfaceRestoredSpawn(restoreData, now, bc)` (`30034-30075`, `30286`, `70141-70505`).
Test de validité : le groupe n'est restauré que si ce qu'il faisait a encore un sens — la zone sous sa position sauvegardée, ou sa cible, doit encore avoir le bon propriétaire pour sa mission (supply : cible amie ou neutre, ou la base quand il rentre ; attaque : cible ennemie ; artillerie qui rentre : base toujours possédée ; advance capture : cible toujours ennemie) ; sinon il retourne au hangar (`70158-70222`).
Si l'empreinte de la cible est suspendue « idle », la restauration est reportée jusqu'au réveil des zones, au plus `idleZoneWakeHoldSec` (`70223-70234`).
Route : reconstruite depuis la position sauvegardée — `_buildSurfaceRestoreTask` (route sur route de ce point jusqu'à la cible, ou jusqu'à la base pour un supply qui rentre), une `Mission` hors route à deux points vers le point d'attente sauvegardé pour un convoi qui attend en advance capture, `_buildSurfaceArtilleryHomeTaskFromPoint` pour l'artillerie qui rentre, et pour un convoi d'attaque sauvegardé `atdestination` un nouveau tour de sous-zones de la cible (`70284-70371`).
Spawn : le template est pivoté au cap sauvegardé et spawné avec `SPAWN:NewFromTemplate(tpl, template, self.name, true)` à la position sauvegardée (`70268-70279`, `70382-70390`).
Dans le callback, la FSM est mise à l'état sauvegardé (`enroute` ou `atdestination`) avec `lastStateTime = now − saved duration`, les unités mortes du « masque de vivants » sauvegardé sont retirées (`_applySurfaceRestoreAliveMask`), et la route est poussée 5 s après un `controller:popTask()` (`70411-70467`, `69196`).
Un cuirassé de Normandie est d'abord déplacé vers un point d'eau sûr à moins de 5 km (`70236-70248`).

### Artillerie

`MissionType='ARTY'` (ou tout groupe dont les unités ont l'attribut `MLRS`/`Artillery`) route vers un point de tir à distance de sécurité du centre de la cible : 8 nm pour les templates nommés `ArtilleryConvoyLong…`, 2,2 nm sinon, ou `artilleryRangeNm` (`10321-10331`, `11505-11560`, `24754-24762`).
Le dernier waypoint exécute un script `bc:startFiringAtZone(groupName, target, 10, true)` : toutes les 10 min, `_fireAtResolvedZone` tire sur les unités construites de la zone ; quand la cible n'est plus Blue ou n'a plus de cibles, la batterie est routée vers sa base (`_routeSurfaceArtilleryHome`) (`11512`, `24931-24972`).
Tant que `_artilleryOnStation`, le handler `enroute` de la FSM ne fait rien (`69794-69796`).
Les groupes `FixedArty=true` sont des groupes du `.miz` re-spawnés sur place avec `Respawn.Group` (sans template) et `SetActiveMission` pose `ActiveMission[name]=true` pour le suivi de mission (`70700-70722`, `70771-70773`).

### Navires

`MissionType='BATTLESHIP'` (Normandie seulement) : routé par `dc.BuildSupplyNavalRoute` ; 30 s après l'arrivée, un `NAVYGROUP:New(name)` de Moose est créé et un `AUFTRAG:NewARTY(enemyShipGroup, nil, 250)` par groupe de navires ennemi de la zone est ajouté, avec `SetDetection()` / `SetEngageDetectedOn()` (`70011-70059`).
Le spawn d'un cuirassé programme une contre-frappe ennemie : 30 s plus tard, `SPAWN:New('AXEAntishipJU88Template' | 'UKAntiShipF4UDTemplate'):SpawnAtAirbase(Hot)` enveloppé dans un `FLIGHTGROUP:New` avec `AUFTRAG:NewANTISHIP(battleship, 3000)` (`10834-10945`, `70662-70665`).
Des variantes navales et aériennes du supply (`SupplyNavalTemplate`, `SupplyAirTemplate`) existent aussi pour la Normandie (`68989-68996`).

## 7. Ce qui repose sur Moose OPS

Comptes dans `zoneCommanderv2.lua` (grep) : `FLIGHTGROUP:New` 3, `NAVYGROUP:New` 2, `ARMYGROUP:New` 1, `AUFTRAG:New*` 6, `:AddMission(` 6 ; aucun usage direct de `AIRWING`, `SQUADRON`, `LEGION`, `CHIEF`, `COMMANDER`, `INTEL`, `OPSGROUP`, aucun dispatcher `AI_*`.
En face : `SPAWN:New*` 35, `:Route(` 30, `controller:setTask`/`:setTask(` 22, `SCHEDULER:New` 97, `timer.scheduleFunction` 162.
Les emplacements OPS sont tous des fonctionnalités annexes :

| Emplacement | Usage d'OPS | Ligne |
|---|---|---|
| Hunter, deux appareils | `FLIGHTGROUP` + `AUFTRAG:NewINTERCEPT`, hooks de FSM `OnAfterTakeoff/Dead/Landed` | `41099-41129` |
| Contre-frappe du cuirassé | `FLIGHTGROUP` + `AUFTRAG:NewANTISHIP` | `10932-10940` |
| Engagement du cuirassé | `NAVYGROUP` + `AUFTRAG:NewARTY` | `70022-70053` |
| Appui d'artillerie navale (Normandie) | `NAVYGROUP` + `AUFTRAG:NewARTY` ; frappeur `FLIGHTGROUP` + `AUFTRAG:NewANTISHIP` | `109998-110093` |
| Lanceur de V1 (Normandie) | `ARMYGROUP` + `AUFTRAG:NewARTY` | `111165`, `111330` |

Ce qu'OPS apporte là : le cycle de vie des missions (file, exécution, terminé), le RTB et l'atterrissage automatiques, et les événements de FSM `OnAfter*` utilisés pour les messages et le nettoyage.
Tout le système régulier de sorties (supply, CAP, CAS, SEAD, piste, convois, artillerie) utilise des tâches DCS brutes ; Moose sert de boîte à outils : `SPAWN` (copie de template + nommage unique + spawn au parking), `AIRBASE` (requêtes de places de parking), constructeurs de waypoints `COORDINATE`, `GROUP:Route`, `GROUP:TaskFunction`, `ZONE`, `SCHEDULER`.

## 8. Hunter (deux appareils Red lancés contre un joueur qui réussit)

### Ce que voit le joueur

Après assez de kills, un message de coalition Blue `COMBAT_HUNT_SCRAMBLE` (avec le nom du joueur) apparaît quand les hunters décollent, et le joueur chassé entend `Watch your six.ogg` (`41106-41120`).

### Ce que règle le créateur de mission

Config `EnableHunter = true` (désactivé en PvP) (`Foothold Config.lua:856-858`).
Setup : `bc:initHunter(HuntNumber, AirHuntNumber)` avec des seuils tirés au démarrage de la mission : kills au sol 6–15 (8–15 avec Splash Damage), kills en l'air 4–8 (`MA_Setup_CAv2.lua:6038-6042`).

### Mécanisme

`registerHuntKill(pname, unit, killType)` compte les kills par joueur ; les hélicoptères et les pilotes d'A-10C/A-10A/AV-8B en sont exemptés ; une fois le seuil atteint, chaque kill suivant a 9 % de chances (`roll < 10`) de déclencher, une fois par vie de joueur (`41136-41168`).
`_spawnHunterForPlayer` choisit un aérodrome Red avec deux places de parking libres (`_pickHunterBase`), un template CAP Red au hasard, spawne `HUNTER_<player>` à chaud au parking, l'enveloppe dans un `FLIGHTGROUP`, fixe la base d'attache et un `AUFTRAG:NewINTERCEPT(playerGroup)` à 25 000 ft / 500 kt (`41059-41131`).
`OnAfterLanded` détruit le groupe après 5 s ; `OnAfterDead` remet à zéro les compteurs du joueur (`41123-41128`).
`Hunt` et `Intercept` sont des globales, donc seul le dernier hunter est référencé (`41099-41101`).

## 9. Hélicoptères de supply IA : cargo en sling load et points d'atterrissage (`ExternalHeloCargoRoute`)

### Ce que voit le joueur

Les hélicoptères de supply transportent un conteneur visible en sling load, annoncent leur envoi (`LOGISTICS_SUPPLY_HELO_DISPATCH` / `LOGISTICS_SUPPLY_PLANE_DISPATCH`) et, pour Red, déclenchent des messages d'intel et les sons `Enemy supply helicopter detected.ogg` / `Enemy supply plane detected.ogg` quand ils démarrent, décollent et arrivent (`68652-68656`, `67536-67550`, `68679-68693`).

### Ce que règle le créateur de mission

Config : `SuppliesCargoTransport = true` (les hélicoptères IA utilisent le transport de cargo), `AIDeliveryamount = 20` (objets d'entrepôt par rotation), `NoAIBlueSupplies`, `NoAIBlueCapture`, `RadioMenuStopSupplies` (`Foothold Config.lua:1344-1363`).
`.miz` : des zones optionnelles de points d'atterrissage `<Zone>-land` / `<Zone>-land-<n>` (et `<Zone>-land-forced-<n>` générées) donnent les points de prise du cargo et d'atterrissage (`610-676`, `59309-59316`).

### Mécanisme

`_routeFreshSupplyHelo` (2 s après le spawn) choisit la route : route simple (`_assignHeloRoute`) quand le cargo est désactivé, route en sling load (`_assignHeloExternalCargoLogisticsRoute`) quand `WarehouseLogistics` et `SuppliesCargoTransport` sont actifs et que le groupe n'est pas `NotCargo`, route de cargo interne pour les templates de type Chinook (actuellement désactivée : « DCS internal cargo is broken » (le cargo interne de DCS est cassé), le template est forcé en `NotCargo`) (`68267-68307`, `68510-68513`).
Le conteneur est un `coalition.addStaticObject(country, {type="container_cargo", category="Cargos", canCargo=true, mass=600, …})` brut posé à un point d'atterrissage de la zone d'origine ou juste devant l'hélicoptère (`58495-58533`, `59309-59330`).
`ExternalHeloCargoRoute` est une petite table de constructeurs de tâches DCS brutes : `ExternalCargoLoad {unitIdTransport, groupId, unitId}`, `ExternalCargoUnLoad {zoneId, unitIdTransport}`, une `Orbit` en racetrack à vitesse nulle utilisée comme attente en vol stationnaire, des waypoints en l'air, et des fonctions d'aide de routes de transit (`58056-58260`).
Filets de sécurité : un hélicoptère en vol stationnaire sous un seuil de vitesse dans la zone cible pendant trop longtemps voit son cargo détruit pour qu'il puisse se poser (`67691-67741`) ; une variante « advance capture » garde l'hélicoptère en orbite hors d'une zone ennemie jusqu'à ce qu'elle devienne neutre, puis le libère (`67621-67653`).
Les avions de supply utilisent `_assignPlaneRoute` : point de décollage, un point d'approche 20 NM avant l'aérodrome cible à l'altitude de croisière, atterrissage sur cet aérodrome (détail au §5) (`57887-57920`).
Les hélicoptères de supply reçoivent leurs ROE via `_applySupplyHeloDefaultRoe` et `OptionPreferVerticalLanding` (`58301`, `68600`).

### Cargo interne des hélicoptères de supply IA (écrit, désactivé dans la v6.5.3)

Périmètre : uniquement un hélicoptère de supply Blue dont le type d'unité du template est `CH-47Fbl1`, avec `WarehouseLogistics` actif, `SuppliesCargoTransport` pas à false, pas `NotCargo`, pas un nouvel essai sans cargo et pas un décollage de FARP à route seule (`59028-59033`, `59126-59130`).
Dans la v6.5.3, les deux chemins de spawn forcent `NotCargo = true` pour ces templates et l'appel à `_prepareHeloInternalCargoSpawn` est commenté (« Internal cargo temporarily disabled after the DCS update » (cargo interne temporairement désactivé après la mise à jour de DCS)), donc le code ci-dessous est dormant (`66793-66794`, `68509-68512`).
Mécanisme quand il est activé : `_prepareHeloInternalCargoSpawn` enveloppe le `SpawnWithIndex` du spawner Moose pour que, avant `coalition.addGroup`, il fixe le `unitId` de l'unité de tête, réserve trois identifiants de cargo et réécrive la route du template ; juste après le spawn, il crée trois statics derrière l'hélicoptère (12 m en arrière, espacés de 1,3 m) avec `coalition.addStaticObject(country.id.USA, {type='cds_crate', shape_name='cds_crate', category='Cargos', canCargo=true, mass=400, groupId, unitId, x, y, heading, name='<group>_INTCARGO_<i>'})` (`59131-59178`).
Le premier waypoint reçoit une tâche par caisse `{id='CargoTransportationPlane', params={x, y, unitIdTransport=<helo unit id>, groupId=<crate>, unitId=<crate>}}` suivie d'un callback `Script` `bc:_markInternalSupplyLoaded(group, version, heloUnitId)` (`59044-59053`).
Tronçon de livraison (`_buildHeloInternalCargoRoute`) : les waypoints de transit habituels du supply à 289 km/h, un point « Approach » à 500 ft, puis un point « Landing Approach » à 400 ft / 160 km/h dont la liste de tâches est : callback optionnel de retour à la base, `Land{point = destination, duration 2 s, combatLanding for Blue}`, un `{id='CargoUnloadPlane', params={groupId, unitId}}` par caisse, et un callback `Script` `bc:_markInternalSupplyUnloaded(…)` (`59072-59117`).
`_markInternalSupplyUnloaded` force la FSM à `landed`, ce qui laisse le code d'arrivée normal capturer ou livrer (`59258-59272`).
Variante advance capture : au lieu d'atterrir, un point de ralentissement 1,5 NM avant l'attente et une `Orbit` en vol stationnaire à 100 m AGL / 140 km/h au point d'attente (à 80 % du trajet, au moins 10 NM avant), avec les mêmes timers de libération de 120 s / 600 s que dans le cas du sling load (`59054-59071`, `59091-59100`).
L'entrepôt d'origine est débité de `AIDeliveryamount` (20) une fois par sortie (`59206-59210`).

### Notes de reproduction

Les tâches de cargo (`ExternalCargoLoad`/`ExternalCargoUnLoad`) sont des tâches DCS non documentées qui exigent les identifiants d'unité/de groupe vivants du static et un identifiant de trigger zone ; le code garde plusieurs délais d'expiration parce que les hélicoptères décrochent souvent.
La capture par atterrissage repose sur une scrutation « tous posés + une unité quelconque dans la zone », pas sur `S_EVENT_LAND`.

## 10. Mouvement au sol dans les zones (itinérance) et AIEN

### Patrouille de zone (« roam »)

Créateur de mission : Config `DisableZonePatrol = false` (`Foothold Config.lua:486`) ; appel de setup `bc:roamGroupsToLocalSubZone(prefixes, 50, nil, {groupMin=10, groupMax=45, zoneMin=120, zoneMax=360, cycleMin=420, cycleMax=720})` 30 s après le démarrage, avec des préfixes de noms de groupes comme `"Red Armour Group"`, `"Red SAM SHORAD"`, et un second appel pour les navires (`'Moskva #'`, `'Rezky #'`, …) avec un cycle de 30–38 min (`MA_Setup_CAv2.lua:2850-2886`).
Mécanisme : `SET_GROUP:New():FilterPrefixes(p):FilterStart()` tient des ensembles vivants par préfixe (`27901-27905`) ; seules les zones connectées à une zone Blue ou proches d'elle (à moins de 50 nm) sont traitées (`27912-27960`) ; les zones sont visitées une à la fois avec un délai aléatoire entre les groupes et entre les zones.
Pour chaque groupe, une sous-zone libre `<Zone>-<n>` est choisie (`_roamPickLocalSubZone`) et, seulement si l'unité de tête est immobile et que la sous-zone est à moins de 3 nm, le groupe y est envoyé à 30–60 km/h dans une formation aléatoire, par la route quand les deux extrémités sont proches d'une route (`27721-27760`, `27842-27878`).
Les navires utilisent `GROUP:RouteGroundTo(coord, speed, "Off Road", 1)` de Moose (`27749-27753`).

### AIEN (`AIEN.lua`, 16 093 lignes)

AIEN est un script d'IA terrestre tiers (« AI ENhancement »), embarqué et modifié pour Foothold ; il tourne seul et rappelle `bc`.
Ce que Foothold expose dans la Config : `AIEN.config.dontInitialize=false`, `blueAI=true`, `redAI=true`, `dismount=true`, `message_feed=true`, `initiative=true`, et les cadences du scheduler `phaseCycleTimerMin=0.2`, `phaseCycleTimerActive=0.08`, `phaseCycleTimerIdle=0.5` s (`Foothold Config.lua:2363-2382`).
Fixé dans AIEN : `firemissions=true` (l'artillerie tire sur les cibles signalées par d'autres unités et des drones), `uavNightScan=true`, `reactions=true`, `suppression=true` (le commentaire de la source dit que les groupes non blindés sont supprimés 15–45 s ; le code fait le test inverse, voir « Détail des réactions AIEN » plus bas), `directorReaction=true` (`AIEN.lua:17-24`).
Exclusions par fragment de nom de groupe : `AIEN_xcl_tag = {"Testing","Hidden","hidden","supply","support","EscortGroup","attack"}` — donc les convois nommés `…-supply-…` / `…-attack-…` ne sont pas touchés ; les groupes `"Red SAM"` ne peuvent que déléguer ; les groupes `"Blue SAM"` gardent leur conscience de la situation mais ne bougent jamais et ne changent jamais de ROE ; les groupes `"Blue Armor …"` peuvent répondre aux attaques par délégation (`AIEN.lua:27-30`).
Limites de mouvement : `maxGroupInMovement = 10` groupes à la fois, `initiativeRange = 4000` m, `maxSlope = 25°`, vitesses de 8 m/s hors route, 15 m/s sur route, 2 m/s pour l'infanterie (`AIEN.lua:34`, `44-51`).
Mécanisme : un seul `world.addEventHandler` qui traite `S_EVENT_HIT`, `S_EVENT_BIRTH`, `S_EVENT_DEAD`/`S_EVENT_UNIT_LOST` (`AIEN.lua:16057-16080`), plus un `AIEN.performPhaseCycle` qui se replanifie lui-même et fait tourner les phases (`update_GROUND`, `update_DRONE`, `update_TACTICAL`, `update_INITIATIVE`) à la cadence ci-dessus (`AIEN.lua:14069-14071`, `14097`, `14253`, `14857`, `14868`, `15144`).
Sur un impact, la conscience de la situation du groupe est notée et une réaction est choisie parmi : accélérer, se disperser, paniquer (fuir), larguer des fumigènes, se replier, attaquer, se couvrir dans les bâtiments, appeler un appui au sol, se placer sous couverture de défense aérienne, tir de mission sur le tireur (contre-batterie) (`AIEN.lua:11933-12733`, `13595`).
Débarquements : les camions/APC/IFV touchés mais pas détruits larguent de l'infanterie (une équipe MANPAD si le tireur est en l'air), qui remonte à bord après `remountTime = 600` s (`AIEN.lua:56`, `11507-11870`, `15322-15330`).
Crochets vers Foothold : `bc:getZoneOfPoint` pour garder les réactions à l'intérieur de la zone propriétaire (nombreux emplacements, par exemple `AIEN.lua:7817`, `12244`) ; `bc:roamGroupsInZoneNow` pour faire bouger les autres groupes de la zone quand l'un est touché (`AIEN.lua:9374`) ; `bc:startZoneAttackFlash(z, 60)` (`AIEN.lua:13658`) ; `bc:reportAIENAirSupportAttack` et `bc:reportAIENEnemyPositionAttack`, qui demandent au Director une CAP d'appui aérien (10 % de chances, 20 min de délai de récupération) ou une sortie de « réponse à une position ennemie » (30 % de chances ; CAS par hélicoptère ou convoi vers la position du tireur) (`AIEN.lua:13554-13556`, `13619`, `15636` ; `zoneCommanderv2.lua:70995-70997`, `71901-71907`).
Un convoi de réponse à une position ennemie roule jusqu'au point signalé, y reste 15 s à moins de 1 km, revient à moins de 1 km de sa base et despawne ; un avertissement `AIEN_ENEMY_POSITION_ARTILLERY_CONVOY_WARNING` est envoyé 2–3 min après le lancement quand le déclencheur était de l'artillerie (`69668-69737`).
`AIEN.ReactToSmoke(zoneObj, groupName, 20)` est appelée par le moteur quand un fumigène est utilisé sur une zone (`23658`, `AIEN.lua:11034`).

### Détail des réactions AIEN

Point d'entrée : `event_hit(unit, shooter, weapon)` depuis `S_EVENT_HIT`, seulement pour les véhicules d'un groupe qui passe `groupAllowedForAI` (tags d'exclusion, interrupteur de coalition) (`AIEN.lua:15179-15265`).
Les tirs amis sont ignorés (`AIEN.lua:15267-15279`).
Ordre des effets sur un impact :

1. Les groupes `Blue SAM` ne produisent que le rapport « zone under attack » (`reportOnlyReaction`) à leur premier impact et rien d'autre (`AIEN.lua:15281-15301`, `13710-13715`).
2. Suppression : si le tireur est connu et a l'attribut `Air`, `Ships` ou `Indirect fire`, et que l'unité touchée a l'attribut `Armored vehicles`, `groupSuppress` règle les ROE au sol sur 4 (weapon hold) puis sur 2 après 2 × le temps de réaction (`AIEN.lua:15303-15315`, `10412-10431`).
3. Débarquement, au premier impact seulement : tireur en l'air → l'équipe MANPAD transportée par le groupe est larguée 8–15 s plus tard ; tireur terrestre à moins de 1 000 m → toute l'infanterie transportée est larguée 8–15 s plus tard ; les deux remontent à bord après `remountTime` (600 s) (`AIEN.lua:15317-15330`, `11793-11860`).
4. Choix de la réaction, au premier impact seulement (un groupe reste « sous attaque » pendant `underAttackTimeout` = 600 s et ne réévalue pas) (`AIEN.lua:15339-15343`, `14150-14153`, `69`) : le groupe est arrêté (`trigger.action.groupStopMoving`), et sept faits sont calculés — catégorie d'arme `w_cat` (obus/missile/roquette/bombe), catégorie du tireur `s_cat` (avion/hélicoptère/sol/navire/structure), `s_indirect` (le tireur a `Indirect fire`, ou tireur inconnu avec obus/roquette), `s_close` (tireur à l'intérieur de la portée d'armes du groupe), `s_fireMis` (tireur vu il y a moins de 30 s et plus lent que 1 m/s, ou un tirage à 30 %), classe propre `o_cls`, classe du tireur `s_cls` (`ARBN` pour un tireur inconnu avec missile/bombe) (`AIEN.lua:15354-15466`).
5. La liste de candidats est formée des 11 entrées de `reactionsDb` moins celles écartées par la situation (tableau ci-dessous), moins toute entrée dont l'indice dépasse 2 × le nombre de skill du groupe (`AIEN.lua:15483-15548`).
   Le nombre de skill est la moyenne des `skillVal` des unités telles qu'écrites dans le fichier de mission, un 4–12 aléatoire pour « Random », et un 2–5 aléatoire quand l'identifiant du groupe est introuvable dans `env.mission` (ce qui est le cas des groupes créés à l'exécution — estimation) (`AIEN.lua:9842-9879`).
6. Chaque entrée restante est notée par la somme de sept consultations de table, une par fait (poids `w_cat`, `s_cat`, `s_indirect`, `s_close`, `s_fireMis`, `o_cls`, `s_cls` stockés dans l'entrée), la liste est triée par score décroissant, et `executeReactions` exécute les fonctions dans cet ordre jusqu'à ce que l'une renvoie true (`AIEN.lua:15558-15598`, `13595-13610`).
7. En cas de succès, on dit au groupe de reprendre sa marche (`trigger.action.groupContinueMoving`) quand l'entrée a `resume`, et le message, le flash et le son du rapport d'attaque de zone sont produits (`AIEN.lua:13611-13684`).

| # | Réaction | Retirée quand | Ce qu'elle fait | Code |
|---|---|---|---|---|
| 1 | `ac_accelerate` | — | Seulement si le groupe est en mouvement : `controller:setSpeed(30, true)`. | `AIEN.lua:11933-11960` |
| 2 | `ac_panic` | — | Larguer son infanterie, puis après le temps de réaction se déplacer vers un point de terrain valide au hasard à 500–2 000 m (par la route quand une route est proche et que le trajet dépasse 700 m) et régler la vitesse à 30 m/s. | `AIEN.lua:11980-12064` |
| 3 | `ac_disperse` | le tireur est un hélicoptère ou un avion | Active l'option DCS « se disperser sous le feu » pour le groupe. | `AIEN.lua:11962-11978`, `15512-15527` |
| 4 | `ac_dropSmoke` | l'unité touchée n'est pas blindée | Exige au moins 50 % d'unités `HeavyArmoredUnits` ou `IFV` ; après le temps de réaction, fait apparaître `smoke_source_num` (5) fumigènes à 15–30 m autour de chacune de ces unités, étalés sur 1–5 s, et décale le groupe de quelques mètres. | `AIEN.lua:12066-12166`, `15532-15534` |
| 5 | `ac_withdraw` | la classe propre est ARTY/MLRS/MISSILE ; carte Kola | Se déplace vers le groupe ami le plus proche **de la garnison de la même zone** situé à 2 000–3 500 m ; 600–900 s plus tard, retourne à la fin de sa route d'éditeur ou à sa position d'origine. | `AIEN.lua:12169-12262`, `15495-15500` |
| 6 | `ac_attack` | position du tireur inconnue ou non détectée ; le tireur est un avion ; la classe propre est SAM/SHORAD/ARTY/MLRS/AAA | Refusée quand la force ennemie à moins de 8 km du tireur dépasse 20 ; sinon ROE libres, largue l'infanterie (sauf si l'attaquant est un hélicoptère), se porte sur la position du tireur en formation Cone à 10 m/s (4 m/s avec des débarqués) ; revient 120 s après être arrivé à moins de 300 m, ou après 600 s. | `AIEN.lua:12275-12410`, `15501-15527` |
| 7 | `ac_coverBuildings` | carte Kola | Teste quatre points à 2 500 m au N/S/E/O du groupe, dans la même zone, ayant au moins 4 bâtiments de décor à moins de 2 500 m (`CustomZone:getZoneBuildings`) et aucune unité ennemie ; se déplace vers le centroïde des bâtiments du point le plus proche de ce genre ; revient après 420–900 s. | `AIEN.lua:12419-12540` |
| 8 | `ac_groundSupport` | tireur pas assez récent (`s_fireMis` < 1) ; tireur inconnu ; tireur en l'air ; carte Kola | Choisit, parmi les autres groupes de la garnison de la même zone, celui qui a le meilleur poids de classe (MBT 10, ATGM 9, IFV 7, APC 5,5, SHORAD 5 …) et envoie **celui-ci** à la position du groupe touché. | `AIEN.lua:12545-12610`, `253-274`, `15489-15527` |
| 9 | `ac_coverADS` | la classe du tireur n'est pas `ARBN` | Choisit le groupe de la garnison de la même zone avec le meilleur poids antiaérien (SAM 10, SHORAD 9, MANPADS 8, AAA 7 …) et, s'il n'est pas déjà dans sa portée de menace, se place à côté de lui ; revient après 900–1 200 s. | `AIEN.lua:12623-12720`, `276-296`, `15529-15531` |
| 10 | `ac_fireMissionOnShooter` | tireur inconnu/non détecté, ou ni un hélicoptère ni une unité terrestre | Le premier groupe `ARTY` ami inactif dont la portée à 80 % couvre le tireur abandonne sa tâche et tire 20 coups sur la position du tireur. | `AIEN.lua:12733-12765`, `15501-15511` |
| 11 | `ac_airSupport` | — | Inerte : l'entrée de la table référence une fonction `ac_airSupport` qui n'est définie nulle part dans le fichier, donc `executeReactions` la saute. | `AIEN.lua:13486-13488`, `13599-13600` |

Le temps de réaction utilisé par chaque action différée est `random(1..3) × 25 / skill` secondes (`AIEN.lua:130-131`, `9149-9157`).

Après la réaction, toujours dans le handler d'impact (`AIEN.lua:15601-15800`) :

- contre-batterie (`firemissions`) : sauf si la réaction était déjà un tir de mission et sauf si le tireur est un avion, une ARTY/MLRS amie inactive dont la portée à 90 % couvre le tireur peut riposter ; elle exige une unité amie `SAM SR`, `SAM TR` ou `EWR` à moins de 50 km de l'impact, réussit avec la probabilité `1 − (d / 50 km)²`, annonce « identified enemy artillery fire » et tire après 160 s ± 35 % sur un point dispersé jusqu'à `300 × (d / 50 km)^1.5` m (`AIEN.lua:11121-11215`) ;
- réponse du Director (crochet Foothold, Red seulement, pas la Normandie) : si la zone du groupe touché est une zone d'aérodrome Red avec spawn d'avions, « armée » pour l'advance capture et pas encore éligible, et que l'attaquant est un hélicoptère de joueur à moins de 5 NM ou de l'artillerie à moins de 10 NM, alors une fois par zone un tirage à 30 % appelle `bc:reportAIENEnemyPositionAttack(zone, attackerPos, kind)` (`AIEN.lua:13554-13591`, `15618-15638`) ;
- délégation : un groupe Red SAM/SHORAD/ARTY/MLRS touché par un hélicoptère, ou n'importe quel groupe touché par un attaquant terrestre éligible, confie le combat au meilleur groupe mobile inactif de la garnison de la même zone (poids de classe × 10 000 − distance, à moins de 4 000 m pour le cas anti-hélicoptère et 10 000 m pour le cas terrestre) ; ce groupe exécute `ac_attack` avec retour à la zone, un deuxième le rejoint avec 25 % de chances, et la zone est verrouillée contre toute nouvelle délégation pendant 1 200 s (`AIEN.lua:15641-15800`, `78`) ;
- itinérance de zone : quand rien de plus fort n'a été lancé, un tirage à 10 % (15 minutes de délai de récupération par zone) appelle `bc:roamGroupsInZoneNow(zone, candidates, {stepDelay = 5})` pour que d'autres groupes de la zone changent de sous-zone (`AIEN.lua:9360-9378`, `79-81`).

Hors impacts, le cycle de phases exécute ces comportements activés :

- phase A `update_GROUND` : un groupe par pas, rafraîchit sa conscience de la situation (`getSA`), fait expirer les drapeaux `tasked` après `taskTimeout` et le drapeau « sous attaque » après 600 s (`AIEN.lua:14097-14190`) ;
- phase B `update_ISR` : purge les entrées mortes ou périmées de la base d'intel (`AIEN.lua:14194-14246`) ;
- phase C `update_DRONE` : un groupe de drones (UAV) par pas reçoit le même rafraîchissement de conscience de la situation (`getSA`) que les groupes terrestres, ce qui fait entrer ses contacts dans la base d'intel ; les drones morts sont écartés (`AIEN.lua:14253-14300`) ;
- phase D `update_ARTY` (`firemissions`) : chaque ARTY/MLRS inactive avec des coups restants cherche des unités ennemies à l'intérieur de 85 % de sa portée (et hors de sa portée minimale), exige un contact de moins de 180 s et, pour une batterie non guidée, une cible plus lente que 0,5 m/s, puis tire ; **les batteries Blue (et les deux camps en PvP) exigent en plus un observateur sur la zone de la cible** — un JTAC dans la file JTAC de Foothold, un 9-line actif, un scout actif, ou un intel de zone actif (`_zoneIntelIsActive`) (`AIEN.lua:14412-14800`, `14430`, `14556-14600`) ;
- phase E `update_TACTICAL` : vide dans cette version, elle ne fait qu'avancer la phase (`AIEN.lua:14857-14861`) ;
- phase F `update_INITIATIVE` (`initiative`, pas sur Kola) : seulement les groupes MBT/ATGM/IFV/APC/RECCE sans route d'éditeur, inactifs, pas sous attaque, d'une force supérieure à 3 et avec au moins une cible connue ; le groupe ennemi connu le plus proche à moins de 4 000 m est comparé en force, et s'il est plus faible le groupe avance vers un point sur la ligne qui mène à lui (`pointBetween(own, enemy, 5000)`) en formation Cone, annonce « moving to engage hasty targets », et retourne à son poste 480 s plus tard ; au plus `maxGroupInMovement` (10) de ces mouvements par cycle (`AIEN.lua:14868-15060`).

### Notes de reproduction

AIEN est indépendant de Moose (API DCS brute) mais c'est un gros moteur de comportement avec sa propre base d'intel, ses délais d'expiration et un modèle de skill par groupe ; son coût est maîtrisé par la cadence des phases et le plafond de 10 groupes en mouvement.
L'itinérance et les convois dépendent tous deux de sous-zones numérotées placées à la main dans chaque zone.

## 11. Défense aérienne : réseau MANTIS, masquage sur le MFD, réglages de nuit

### Ce que règle le créateur de mission

Config (`Foothold Config.lua:508-538`) : `DisableMantis = false` ; `HideSAMOnMFD = "random"` (`false` affiché, `true` masqué, `"random"` 50 % par spawn) ; `RevealSamOnMfdAfterDetection = false` (PvE seulement, exige `HideSAMOnMFD = true`) ; `NightMantisInterval = 30` (secondes entre les décisions de défense aérienne la nuit, 0 = désactivé, borné à 15–120) ; `NightRadarBlur = true`.
Conventions du `.miz` : groupes SAM nommés avec le préfixe `Red SAM…`, groupes EWR `Red EWR…` (plus `Red GCI` en PvP), groupe AWACS `AWACS_RED`, trigger zones optionnelles préfixées `Scoot` pour le déplacement en shoot-and-scoot (`111399`, `111454-111455`).

### Mécanisme

10 s après le chargement, sauf désactivation ou sur Normandie/Vietnam : `FootholdMantis = MANTIS:New("Foothold MANTIS","Red SAM","Red EWR",nil,"red",true,"AWACS_RED")` (`111396-111399`).
MANTIS (Moose) garde les SAM éteints (alarm state green / émissions coupées) et passe un site au rouge quand une cible détectée par un EWR/AWACS entre dans sa portée ; il embarque des workers `INTEL` de Moose pour la détection et un handler `SEAD` pour l'évasion des ARM (détail dans « Ce que MANTIS fait pour Foothold » plus bas ; le code propre de Foothold va chercher `mantis.intelset`, `mantis.mysead`, `SamStateTracker`, `SuppressedGroups`, `InboundARMs` : `41616`, `109010-109021`).

### Ce que MANTIS fait pour Foothold (Moose embarqué, `Moose_2026-10-11.lua`)

Appartenance : deux ensembles vivants filtrés par préfixe, `SAM_Group` (`"Red SAM"`) et `EWR_Group` (`"Red EWR"`), tous deux `SET_GROUP:New():FilterPrefixes(...):FilterCoalitions(...)`, donc tout groupe spawné plus tard avec un nom correspondant rejoint le réseau ; l'ensemble de capteurs filtre en réalité sur les préfixes SAM, les préfixes EWR **et** le nom du groupe AWACS, donc les radars SAM et l'AWACS sont aussi des détecteurs (`56826-56842`).
Classification : à chaque troisième tick de statut, `_RefreshSAMTable` reconstruit cinq tables — tous, longue, moyenne, courte portée, défense ponctuelle — d'enregistrements `{name, coordinate, radius, height, blind range, type, ARM capacity}` issus de `_GetSAMRange` (la fonction que Foothold surcharge) (`58458-58461`, `58010`, `57788`).
État de départ (`SetSAMStartState`) : chaque SAM reçoit `EnableEmission(false)` + `OptionAlarmStateGreen()` et `OptionEngageRange(95)` (engagement à 95 % de la portée maximale), et un objet `SEAD` de Moose est créé sur tous les noms de groupes SAM (`57925-58009`).
Source de détection (`StartIntelDetection`) : deux workers `INTEL`, l'un alimenté par l'ensemble EWR et l'autre par l'ensemble SAM lui-même, chacun traitant un groupe détecteur par 0,1 s, avec la détection acoustique optionnelle (joueurs dans le rayon configuré, hélicoptères seulement par défaut), fusionnés par un `INTEL_DLINK` avec un cache de contacts de 120 s (`57512-57554`) ; l'AWACS n'est pas un détecteur séparé ici, c'est un membre de l'ensemble du premier worker, et en mode « advanced » (non activé par Foothold) il compte aussi comme un EWR vivant (`56832-56834`, `57252-57275`).
Boucle principale : l'événement de FSM `Status` est réarmé toutes les `detectinterval` secondes (30 par défaut, 15 réglé par Foothold) ; `onbeforeStatus` → `_Check` construit un instantané de tous les contacts (groupe, position, hauteur, catégorie) et exécute `_CheckLoop` une fois par classe avec le plafond de cette classe (`58458-58527`, `58276-58353`).
`_CheckLoop`, par enregistrement SAM (`58167-58275`) : ignorer les sites morts et les sites qui ont perdu leur radar de poursuite ou n'ont plus de missiles ; `_CheckObjectInZone` = un contact quelconque est-il dans le `radius` (2D) du site et sous sa `height` ; un site est allumé quand un contact est à portée, que le site n'est pas supprimé, n'est pas un SHORAD actif, et que soit le plafond de classe n'est pas atteint, soit la menace est « proche » (à moins de la moitié du rayon une fois le plafond plein) — les sites de courte portée et de défense ponctuelle ne comptent pas dans le test de plafond des sites de longue portée.
Appels d'émission on/off : on = `group:EnableEmission(true)` (quand le mode « EmOnOff » est utilisé) ou `group:OptionAlarmStateRed()`, puis l'événement de FSM `RedState` (le crochet que Foothold utilise pour révéler un SAM sur les MFD) ; off = `EnableEmission(false)` + `OptionAlarmStateGreen()`, puis `GreenState` ; l'état courant par nom est `SamStateTracker[name]` = `"RED"`/`"GREEN"` (`58210-58262`).
Repli : quand aucun EWR n'est vivant, un SAM vivant au hasard qui a encore un radar de poursuite est allumé à chaque tick, si bien que le réseau n'est jamais complètement aveugle (`58466-58492`).
Réaction à un impact (`_EventHandler`, `S_EVENT_HIT` / `S_EVENT_UNIT_LOST` sur un SAM ou un EWR du réseau) : le site est allumé aussitôt, `SAMUnitHit`/`SAMUnitLost` se déclenchent, et le lien SHORAD réveille les voisins (`56886-56997`).
Lien SHORAD : `onafterStart` crée un objet `SHORAD` de Moose sur le même ensemble SAM avec le préfixe `"SHORAD"`, une distance d'activation de 25 km, un temps actif de 600 s, des limites de défense de 80–95 % ; chaque fois qu'un site passe au rouge avec le contact à moins de 25 km (ou dans la portée aveugle du site), ou est touché, `Shorad:WakeUpShorad(name, 25 km, 600 s)` allume les groupes SHORAD autour de lui pour 75–100 % du temps actif, puis les rendort (`58433-58457`, `58248-58253`, `59508-59560`).
Défense contre les ARM : les handlers de tir `SHORAD`/`SEAD` surveillent `S_EVENT_SHOT` pour les armes antiradiation et de type Maverick dirigées contre un membre du réseau ; `SeadAllowSuppression` laisse le site visé s'éteindre et se déplacer seulement quand le nombre d'ARM en approche atteint son `ARMCapacity` (ou qu'il n'a plus de missiles) ; le site supprimé est listé dans `SuppressedGroups` et laissé tranquille par la boucle principale jusqu'à la fin de la suppression (`58116-58166`, `59703-59720`, `58557-58582`).
Scoot : avec `AddScootZones(zoneSet, 3, true, "Cone")`, chaque fois qu'un groupe SHORAD est réveillé, rendormi ou pris pour cible, `onafterShootAndScoot` choisit au hasard l'une des trois premières zones « Scoot » situées à 100–3 000 m et, si le groupe est immobile, le conduit vers un point terre/route aléatoire de cette zone à 20 km/h en formation Cone (`RouteGroundTo`) (`57013-57021`, `59674-59702`).
Une seconde définition de `_CheckLoop` / `onbeforeStatus` à la fin de la classe enveloppe les originaux avec l'extension de brouilleur (non activée par Foothold) (`59055-59108`).
Foothold surcharge `_GetSAMRange` pour dériver portée/hauteur/type de son propre cache de templates d'upgrade (la plus grande famille de SAM du template l'emporte ; les noms contenant `SHORAD` deviennent de la défense ponctuelle) (`111401-111435`) ; il enregistre le profil SON-9 pour `Red SAM AAA 3/4` et filtre tous les autres groupes `Red SAM AAA…` hors du réseau (`111436-111447`).
Réglages : `SetDetectInterval(15)`, `SetAccousticDetectionOn(3000, nil, true, playerSnapshotProvider)` (détection acoustique des joueurs à moins de 3 km), `AddScootZones(SET_ZONE prefix "Scoot", 3, true, "Cone")`, `SetMaxActiveSAMs(3, 3, 3, 6, 6)` (`111450-111456`).
Le PvP ajoute un réseau Blue en miroir `MANTIS:New("Foothold Blue MANTIS","Blue SAM",{"BlueGCI","Blue GCI","Blue EWR"},nil,"blue",true,AWACS_GROUPS[2])` et filtre les événements hit/lost sur la coalition propre (`111457-111464`, `111484-111493`).
Masquage sur le MFD : au spawn, le champ de template `tpl.hiddenOnMFD` est posé pour les groupes dont le nom contient `Red SAM`, `Blue SAM`, `blueHAWK`, `bluePD`, `bluePATRIOT` (`4432-4441`, `4652`, `5191`, `5238`).
Révélation : chaque groupe SAM porte une propriété Moose `FOOTHOLD_SAM_MFD_SLOT` ; `FootholdMantis:OnAfterRedState` enregistre la révélation dans `zone.samMfdReveals[index]`, si bien que le prochain respawn de cet emplacement est spawné avec `hiddenOnMFD=false` (`47696-47726`, `111465-111482`, `8417`).
Nuit : à chaque décollage de joueur, `_nightTakeoffFacts` calcule le lever et le coucher du soleil à un point de référence ; s'il fait nuit, `_applyNightMantisState` règle l'intervalle de détection sur `NightMantisInterval` et applique `INTEL:SetRadarBlur(150, 25, 100, 20)` avec `RadarBlurPlayersOnly=true` à chaque worker intel de MANTIS ; un décollage de jour rétablit 15 s et les valeurs de flou sauvegardées (`101814-101824`, `41579-41640`).
Le support SEAD/leurre de la boutique force un SAM au rouge et le marque supprimé pendant 300 s en écrivant dans les internes de MANTIS (`109007-109024`) — simple crochet.

### Notes de reproduction

MANTIS est la dépendance Moose la plus lourde de ce thème : fusion de détections (EWR + AWACS + acoustique), contrôle d'émission avec plafond de sites actifs simultanément par classe, suppression à l'approche d'ARM, shoot-and-scoot.
Foothold dépend en plus de champs privés de MANTIS/INTEL, si bien que le comportement est lié à la version de Moose embarquée (`Moose_2026-10-11.lua`).

## 12. Bombardier stratégique, escortes et intercepteurs (`StrategicBomber`, `DynamicBomber`)

### Ce que voit le joueur

Raid Red : une cible de mission « intercept bombers » (intercepter les bombardiers) valant 500 est enregistrée (`RegisterGroupTarget(template, 500, …, "bomb")`) (`4160`).
Raid Blue (objet de boutique, simple crochet) : menu de contrôle F10 pour pousser/retenir/détruire, escorte optionnelle par un joueur avec récompenses (`3293`, `3936-4121`, `4195`).
Quand Red lance un intercepteur contre le bombardier Blue : `ding.ogg` + `STRATEGIC_BOMBER_INTERCEPTOR_LAUNCHED` (`2680-2692`).

### Ce que règle le créateur de mission

`StrategicBomber.Configure({[1]={…}, [2]={…}})` dans le fichier de setup : template de bombardier (`RedBomberEvent[_CW]`, `BlueBomberEvent[_CW]`), `escortTemplates` (les templates CAP du camp), altitude de route/d'attaque 25 000 ft, vitesses (attente 300, vers l'ingress 380, après l'ingress 350 kt), `weaponExpend`, `ingressDistanceNm=25`, `rtbApproachDistanceNm=30`, `pickOptions` (`minTargetSpawnNm=80`, `minPlayerSpawnNm=80`, `avoidPlayerCoalition`, `randomCandidateLimit=5`), `interceptorTemplates` pour Blue seulement, `recoveryZones` (`MA_Setup_CAv2.lua:3652-3715`).
Le raid Red est lancé par un événement du fichier de setup qui appelle `StrategicBomber.LaunchRed()` (`MA_Setup_CAv2.lua:4828`).
Indisponible à l'époque du Vietnam (`4127`).

### Mécanisme

`DynamicBomber.PickMission(attackerSide, targetSide, opts)` rassemble les zones ennemies sur les connexions de front (`CollectTargetCandidates`) et, pour chacune, les aérodromes amis à au moins 80 nm de la cible et 80 nm de tout joueur (`PickSpawnForTarget`) (`2166-2318`).
Le bombardier est **spawné en vol** avec `Respawn.SpawnAtPoint(template, coord, heading, 5, altitude, speed, …)` et mis en silence radio (`4140-4144`) ; l'escorte est spawnée plus tard (`SpawnEscortLater`) et reçoit une `ComboTask` brute de `Follow` (décalage de 15 nm devant pour Red, 2 000 ft au-dessus) + `EngageTargets` des avions à moins de 40 nm (`2055-2090`).
`StartBomberAuftrag` (malgré son nom, des tâches brutes) → `DynamicBomber.AssignIngressBombingTask` : `BuildBombingTaskForZone` fait une tâche de bombardement par unité/static des groupes construits de la zone cible, entrepôt compris, puis une route de RTB avec un point d'approche et une tâche `Script` qui détruit le groupe au dernier waypoint (`1500-1700`, `1702-1740`, `1776`).
`StrategicBomber.StartMonitor(side)` scrute l'état du raid ; `Finish` applique les délais de récupération et les pénalités de pertes (`2980-3057`).

### Le moniteur et les commandes Blue en détail

Moniteur (`3018-3057`) : un `timer.scheduleFunction` qui se replanifie lui-même par camp, période de 20 s, premier passage 20 s après le lancement, gardé par un jeton par camp pour qu'un raid plus récent annule silencieusement l'ancienne boucle.
À chaque tick, il cherche le bombardier par son nom de template (`Group.getByName(cfg.template)`, le bombardier est spawné sous ce nom fixe) : s'il a disparu → `Finish(side, "dead")` ; sinon il rafraîchit `status = "alive"`, `lastAliveTime`, et réveille de nouveau les zones « idle » de l'empreinte du raid.
La fin réussie n'est pas détectée par le moniteur : le script du dernier waypoint du bombardier (et le handler d'atterrissage) appellent `MarkRecoveredByGroupName`, qui pose `status = "recovered"`, verse les récompenses d'escorte aux joueurs, enregistre le résultat, nettoie l'escorte et efface l'état sans passer par `Finish` (`2923-2948`, `1591-1593`, `42268-42269`).
`Finish(side, status)` (`2980-3016`) : enregistre `lastResult[side] = {status, time, targetZone, spawnZone}` et prévient le Director Red (`onStrategicBomberResult`) ; sur `"dead"`, pose `cooldownUntil[side] = now + deathCooldownSeconds` (3 600 s par défaut) et, pour Blue, débite `lossPenaltyCredits` (500 par défaut) avec `cancel.ogg` et `STRATEGIC_BOMBER_LOST_CREDITS` ; met en file le nettoyage à l'atterrissage de l'escorte et de l'intercepteur (Blue) ou détruit l'escorte (Red, sauf si le bombardier est mort) ; détruit le groupe du bombardier et efface l'état (`2883-2899`).

Cycle de vie du raid Blue (`LaunchBlue`, `3759-3935`) : le bombardier est spawné en vol, reçoit du carburant illimité, et soit pousse tout de suite, soit commence par attendre.
Raisons d'attente : `"player"` quand l'acheteur a choisi une escorte par un joueur, `"sam"` quand la zone cible contient un type de SAM listé dans `StrategicBomber.BadSamDisplayByName` (le message d'attente les nomme) (`3784-3790`, `2552-2582`).
L'attente est une mission brute à un seul waypoint au point de spawn : `{id="Mission", params={route={points={{type="Turning Point", alt=<route altitude>, alt_type="BARO", speed=<300 kt IAS as TAS>, task=ComboTask{ {id="Orbit", params={pattern="Circle", speed, altitude}} }}}}}}` (`3341-3386`).
Menu F10 Blue : sous la racine par groupe `Dynamic Control` (`MENU_DYNAMIC_CONTROL`, construite par `buildCapControlMenu`), un sous-menu nommé d'après le bombardier (« B-1B Lancer », « B-52H Stratofortress » en Guerre froide) avec `Push` (seulement tant qu'il n'a pas été poussé) et `Destroy` ; il n'y a pas de commande `Hold` dans le menu bien que `HoldBlue` et son libellé existent (`4195-4223`, `16425`, `16656-16657`, `Foothold_Localization.lua:162`, `656-657`, `693-695`).
`PushBlue` (`3936-4039`) : refuse quand il pousse déjà ; appelle `StartBomberAuftrag(missionId, template, targetZone, escortName, nil, {routeAltitudeFt, attackAltitudeFt, weaponExpend, toIngressSpeedKt, afterIngressSpeedKt, staticsLast=true, deferBombingTaskToIngress=true, landAndRefuelAtOrigin=true, homeAirbaseName, rtbApproachDistanceNm})`, pose `pushed`, tire l'intercepteur Red (`TrySpawnBlueInterceptor`), joue `ding.ogg` et annonce `STRATEGIC_BOMBER_PUSHING` avec une ETA vers l'ingress (ou la variante d'escorte par un joueur), puis reconstruit le menu de contrôle.
`DestroyBlue` détruit le bombardier et l'escorte et efface l'état, avec `STRATEGIC_BOMBER_DESTROYED` pour l'appelant (`4101-4121`).
Escorte par un joueur (`3100-3340`) : un client compte comme escorteur tant qu'il est à moins de 2 NM à l'horizontale et ±2 000 ft du bombardier de tête (`PlayerEscortRadiusMeters`, `PlayerEscortAltitudeToleranceMeters`, `2339-2340`) ; après 60 s dans cette enveloppe (`PlayerEscortQualifySeconds`, `2341`) le joueur est « qualifié », et si le raid attendait une escorte par un joueur et qu'aucun SAM dangereux ne subsiste, la première qualification pousse le bombardier automatiquement (`3161-3185`, `3207-3232`).
Quand le bombardier est récupéré, `playerEscortReward` (1 000 par défaut) est réparti à parts égales entre les joueurs qualifiés comme crédit de contribution, avec la statistique de carrière « Strategic bomber escort » et le message `STRATEGIC_BOMBER_ESCORT_COMPLETED_SOLO` / `_MULTI` (`3125-3159`).
Intercepteur contre le bombardier Blue : un tirage par raid, `math.random(1,10) <= threshold` avec un seuil de 1/3/6 pour `CapDifficulty` easy/medium/hard ; spawné depuis l'aérodrome de récupération CAP Red le plus proche sur un parking libre pour chasseurs (`FindFreeParkingSpotForAircraft`) à partir d'un template CAP Red au hasard, taské par `AssignInterceptorTask` (`2344-2348`, `2640-2678`, `2787-2880`).
La WW2/Normandie a un ensemble de bombardiers plus ancien en parallèle (`bomberRedTemplate = 'DynamicBomberRed_Template'`, `redInterceptorTemplate`, distances minimales de spawn de 40 nm) (`110205-110228`).

## 13. Appuis d'artillerie propres à la Normandie (artillerie navale, frappeurs, V1)

`spawnNavyArtyAt(zone, targetZone, strikerZone)` : revient aussitôt sauf si la carte est la Normandie (`109950-109951`) ; spawne le template `UK_NavyArty` sur l'eau (`SPAWN:New():SpawnFromCoordinate`), l'enveloppe dans un `NAVYGROUP`, `AddWeaponRange(1, 8, Auto)`, et ajoute un `AUFTRAG:NewARTY(group, nil, 250)` par groupe Red trouvé dans la zone cible par un filtre `SET_GROUP` ponctuel (`109968-110024`).
Messages `NAVY_ARTY_ENGAGING_TARGETS`, `NAVY_ARTY_MISSION_COMPLETED`, `NAVY_ARTY_GROUP_DESTROYED` ; une entrée de menu reconstruite par `buildCapControlMenu()` permet de despawner (`109940-109948`, `110025-110036`).
« Frappeur » ennemi optionnel : template `AXE_NavyArty_Striker` spawné en vol à 7 620 m dans la zone du frappeur, `FLIGHTGROUP` + `AUFTRAG:NewANTISHIP(navyGroup, 3000)`, moitié de l'armement dépensé, détruit 5 s après l'atterrissage (`110037-110095`).
Sites V1 : `spawnV1ArtyAt(site, cfg)` / `launchRandomV1Artillery()` utilisent `ARMYGROUP` + `AUFTRAG:NewARTY(target, 1, 100)`, cinq roquettes puis un rechargement de 600 s (`111165`, `111330-111349`, `111373-111389`).

## 14. IA Blue en PvE, et différences PvP

### PvE

Les vols IA Blue existent mais sont bridés pour soutenir les joueurs, pas les remplacer : limites CAP/CAS/SEAD de 1 groupe avec au plus un joueur en ligne et 0 au-delà au `"medium"` par défaut (`61022-61110`) ; la CAP Blue engage aussi toujours les hélicoptères (`35772-35774`) ; les avions de frappe de piste Blue sont invisibles à l'IA (`35512-35514`).
Les avions IA Blue sont spawnés au niveau `"Excellent"`, Red à `AiPlaneSkill` (`"Random"` par défaut) (`68504`, `Foothold Config.lua:861`).
Le supply régulier de Blue coûte des crédits quand des joueurs sont en ligne et est conditionné par `NoAIBlueSupplies` / l'interrupteur F10 `RadioMenuStopSupplies` ; `NoAIBlueCapture` empêche l'IA Blue de capturer des zones neutres (`66121-66125`, `66172-66179`, `66386-66403`, `Foothold Config.lua:1354-1363`).
Le supply Blue et les avions IA Blue puisent leurs cellules dans l'entrepôt DCS (`_prepareBlueAiWarehouseSpawn`) et ajoutent du stock d'entrepôt à la livraison (`68580`, `67863-67871`).
Les défenses terrestres Blue sont les listes `blue = {'blueInfantry', 'Blue Armor Modern', 'Blue SAM NASAMS', …}` de la table d'upgrade de chaque zone, plafonnées par `MaxBlueGroundGroupsPerZone = 4` (Red : `MaxRedGroundGroupsPerZone = 12`), avec les niveaux `BlueAiGroundSkill` / `RedAiGroundSkill` (`MA_Setup_CAv2.lua:94-97`, `Foothold Config.lua:463-481`, `541-544`).
Les vols de soutien achetés en boutique (CAP/CAS/SEAD/leurre/bombardier/frappe de structure) utilisent des templates séparés (`CAP_Template`, `DynamicCas_Template`, `DynamicSead_Template`, `DynamicDecoy_Template`, `DynamicBomber_Template`, `DynamicStructure_Template`, chacun avec des variantes `_CW`/`_VT`) et `DynamicSupportNative` ; la Config `AIAttackTakeoffFromGround = true` décide pour eux entre départ au sol et spawn en vol (`105244`, `107935`, `108217`, `108673`, `109335`, `109698`, `106266`, `106500-106502`, `Foothold Config.lua:1941-1944`) — simple crochet.

### PvP (`GlobalSettings.pvpEnabled`)

Les limites de rôle viennent du Director de chaque camp (`director:_configuredRoleLimit`, `_groupSlotAvailable`) au lieu des tables par nombre de joueurs (`66288-66312`, `66421-66426`).
La Config `PvPDisableCombatAI` supprime les vols de combat automatiques ; `PvPCombatAIGroupLimit = 10` plafonne les groupes de combat à voilure fixe automatiques par coalition, réduit du nombre d'avions de joueurs du camp lui-même (0 = équilibrer les camps) (`Foothold Config.lua:328-337`, `17095-17102`).
Red reçoit le traitement de Blue : supply en départ à chaud, puisage dans l'entrepôt, pas de débit de crédits (`68508`, `68373-68375`).
Les messages d'intel et les marqueurs de carte sur les convois/transports ennemis ne sont envoyés qu'à un camp qui détient une autorisation d'intel active sur la zone d'origine (`67526-67535`, `69805-69816`).
Hunter est désactivé (`40975-40978`) ; un MANTIS Blue existe (`111484`) ; les groupes terrestres Blue font aussi de l'itinérance (`MA_Setup_CAv2.lua:2865-2876`).
Le blocage de spawn « joueur Blue près de l'origine » ne s'applique pas aux groupes aériens et de supply (`66158-66160`).

## 15. Limiteurs, étalement et nettoyage

| Mécanisme | Valeur | Code |
|---|---|---|
| Boucle principale | `BattleCommander:update` toutes les `updateFrequency` (10 s) ; après le premier passage, les zones sont mises à jour une par pas de « vague » de 0,1 s | `17117-17121`, `43282-43346` |
| Liste des FSM actives | chaque zone ne met à jour que les groupes de `_activeFsmGroups` ; un groupe est désactivé quand il est `inhangar`/`dead` sans rien en attente | `56268-56371` |
| Sommeil en dormance | les groupes `inhangar`/`dead` sautent les mises à jour jusqu'à `lastStateTime + delay − 30 s`, revérifiés au plus toutes les 30 s (`dormantFsmLeadSec`, `dormantFsmMaxSleepSec`, `dormantFsmRetrySec`) | `65896-66000`, `8531-8533` |
| Limiteur en vol | les groupes `inair` hors supply et `enroute` de surface sont traités un tick sur trois (`activeFsmThrottleBuckets = 3`) | `66977-66994`, `17136`, `43241-43250` |
| File d'évaluation des spawns | les vérifications d'éligibilité sont mises en file et évaluées par un dispatcher : tick de 0,5 s (±0,15 de gigue), 8 évaluations par tick (18 quand plus de 70 sont en file), résultat mis en cache 60 s | `17126-17133`, `17853-18000`, `66090-66098` |
| Gigue du hangar | décalage aléatoire de 0–25 min à chaque retour au hangar | `57288-57312` |
| Plafonds par rôle | voir §3 | |
| Dormance des zones | les zones à plus de 80 nm (Blue) / 120 nm (Red) derrière le front sont suspendues et leurs groupes non combattants ne décollent pas (`proximityWakeNm = 40`, `proximityWakeHoldSeconds = 600` règlent le réveil ; la logique de suspension/réveil est décrite dans la note 01, section 9) | `8524-8527`, `66135-66156` |
| Pas de spawn près des joueurs | zone d'origine Red avec un joueur Blue proche → retour au hangar | `66158-66165` |
| Budget du supply régulier | `regularSupplyDispatchBudgetPerTick = 2` | `8504` |
| Appareils coincés | despawn après 12 min au sol (`blockedDespawnTime`), appareils posés après 60 s / 180 s | `67585-67590`, `8534-8535` |
| Nettoyage à l'atterrissage | `_scheduleLandingCleanup` : détruire le groupe 0,5 s après le traitement de l'atterrissage | `57461-57469` |
| Nettoyage des épaves | avant chaque spawn, `world.removeJunk` sur une sphère du rayon de la zone **cible** | `66599-66602`, `56873-56882` |
| AIEN | au plus 10 groupes en mouvement ; cadence des phases 0,08–0,5 s | `AIEN.lua:34`, `Foothold Config.lua:2380-2382` |
| MANTIS | au plus 3/3/3/6/6 SAM actifs par classe ; intervalle de détection 15 s (30 s la nuit) | `111450-111456` |

## 16. Notes de reproduction pour l'ensemble du système de sorties

La FSM est une pure conception par scrutation (aucun `S_EVENT_*`) : l'existence du groupe, « une unité quelconque en vol », « tous posés », « une unité quelconque dans la zone » sont échantillonnés à chaque tick, donc chaque changement d'état a jusqu'à un tick (10 s, ou 30 s pour les groupes en vol limités) de latence.
Les morceaux de Moose dont elle a réellement besoin sont : le clonage de templates avec noms uniques (`SPAWN:NewFromTemplate`, alias), la découverte et la réservation des places de parking (`AIRBASE:GetFreeParkingSpotsTable`, `SpawnAtParkingSpot`) — la partie la plus difficile à refaire, puisque DCS n'expose que `Airbase:getParking()` et que le spawn doit écrire dans la table du groupe le `parking` par unité (le `Term_Index`) et le lien vers l'aérodrome du premier waypoint (voir « Ce que le spawn au parking de Moose écrit » au §2) — et les constructeurs de tables de waypoints.
Les enregistrements indifférents au camp (une paire origine→cible écrite à la main utilisable par la coalition qui possède l'origine) reposent sur les listes de templates par camp.
Le chemin de restauration en vol après un redémarrage du serveur (`_processAirRestoredSpawn`, `68044`) re-spawne les vols en l'air à leur position sauvegardée ; c'est le seul spawn en l'air des sorties régulières (voir « Restauration des sorties aériennes » au §2 et « Restauration des sorties de surface » au §6).
Dépendances cachées : `Frontline` (distance au front, choix des stations CAP), `ZONE_DISTANCES` et les caches de sous-zones/accroches de route, le système d'intel (`_zoneIntelBroadcast`, `_jtacMessage`), la logistique d'entrepôt, et les callbacks du Director semés dans chaque état (`_recordDirectorRegularSupplyOutcome`, `onManagedSpawnDenied`, `requestDirectorInstanceDisposal`).

## Vu hors de ce thème

- Enregistrements `DirectorCapability` et leur activation/dérivés — thème Director (`11958`, `26280-26450`).
- Génération « dynamic hybrid » des capabilities manquantes le long des connexions — thème Director (`31805-34000`).
- `RunwayHandler` / mission **joueur** de frappe de piste : handler d'`EVENT` de tir qui suit les bombes des joueurs avec `WEAPON:SetFuncImpact` de Moose, récompense 100/200, puis `bc:blockRunwayPlaneSpawns(zone, 3300)` qui bloque pendant 55 min les spawns d'avions IA depuis cette zone (`62287-62602`, `30463-30466`) — thème missions.
- `HercCargoDropSupply` : largages de cargo par un Hercules de joueur qui capturent ou ravitaillent une zone (`102303-102444`) — thème logistique.
- Groupes d'attaque au sol achetés par un joueur (`playerGroundAttack`, `dc.BuildPlayerGroundAttackRouteFromPoint`, retasking) (`69559`, `20335`) — thème boutique.
- Vols de soutien de la boutique et `DynamicSupportNative` (`105244-109700`, `106266-106469`) — thème boutique.
- Démarrage de la capture de zone (`startPendingCapture`, `startPendingCaptureFromAircraft`) et stock de supply (`_applyRegularSupplyDelivery`, permis de supply régulier) — thèmes capture/logistique (`67828`, `69940`).
- Marqueurs de dernière position connue d'« intel » de surface/air et rapports de route (`_scheduleSurfaceIntelRouteReports`, `69407`) — thème intel.
- Récompense de carrière/de nuit au décollage (`101808-101813`) — thème récompenses.
- Missions CAP de joueur et générateurs (`checkAndGenerateCAPMission`, `65505`) — thème missions.

