# 06 — Outils d'aide aux joueurs (Foothold v6.5.3)

Périmètre : tout ce qui aide un joueur à voler et à se battre, hors règles de boutique et d'économie, CTLD, exécution des vols IA et capture de zone.
Les noms de fichiers sont abrégés : `zc2` = `Common Scripts/zoneCommanderv2.lua`, `setup` = `Setup files/MA_Setup_CAv2.lua`, `WM` = `Common Scripts/WelcomeMessage.lua`, `loc` = `Common Scripts/Foothold_Localization.lua`, `cfg` = `Common Scripts/Foothold Config.lua`.

| # | Fonctionnalité | Description en une ligne | Emplacement principal dans le code |
|---|---|---|---|
| 1 | Drone JTAC (auto-lase) | un drone acheté orbite au-dessus d'une zone ennemie, désigne au laser ou à l'IR une cible, menu coalition pour la cible, la priorité, le code, la fumée, la fusée éclairante | `zc2:7366-8148`, `setup:4234-4291` |
| 2 | Drones JTAC 9-line (AM/FM) | un drone acheté avec la tâche DCS native `FAC` sur 241 AM / 31 FM | `zc2:8150-8400`, `setup:4292-4470` |
| 3 | Désignateur laser du joueur (`SelfJtac`) | les appareils de reconnaissance désignent au laser des cibles dans un cône devant eux, avec des options par joueur | `zc2:96368-97550` |
| 4 | CSAR et pilotes ennemis | pilotes abattus générés à l'éjection, balise, marqueur, récupération en vol stationnaire ou posé, infanterie hostile, capture de pilote ennemi et debrief | `zc2:98446-101025`, `zc2:101831-102230`, `zc2:42284-42440` |
| 5 | Intel de zone | intel acheté de 60 min : rapport de contenu, marqueurs de carte par groupe, mises à jour différentielles | `zc2:5567-7014`, `setup:4762-4794` |
| 6 | Ravitailleurs à la demande et leur contrôle | spawn d'Arco/Texaco, TACAN, racetrack par menu ou par marqueurs, menus d'altitude et de vitesse | `zc2:105300-106250`, `zc2:107547-107930`, `zc2:16696-17080` |
| 7 | AWACS | AWACS toujours actif, repositionné derrière le front après chaque capture | `zc2:9331-10146` |
| 8 | Contrôle des CAP | menu et marqueurs `caphere1/2` pour déplacer la CAP achetée | `zc2:28148-28352`, `zc2:105747` |
| 9 | Commandes par marqueurs de carte | la liste complète des textes de marqueurs compris par le moteur | `zc2:28354-29290` |
| 10 | Contrôle des porte-avions et des navires | menu « Sail to area », Tarawa par marqueur, vitesse de vent sur le pont, balises, ravitailleur de récupération | `zc2:13403-16200`, `WM:779-926` |
| 11 | Message de bienvenue, callsigns/IFF, ATIS | accueil, attribution des callsigns et de l'IFF, menu ATIS, aérodrome le plus proche, ATIS de capture, récompense de ravitaillement | `WM:1-1723`, `WM:2731-2941` |
| 12 | Vol d'escorte pour les joueurs | escorte gratuite de 2 appareils sur demande, choix de l'altitude, patrouille/racetrack/orbite/rejointe/RTB | `WM:1434-1470`, `WM:1724-2730` |
| 13 | EWRS | situation BRA fondée sur le radar, bogey dope, menu de réglages par joueur | `EWRS.lua:1-1745` |
| 14 | Zeus | commandes de marqueurs du maître de jeu (`-create`, `-destroyN`, `-explode`, `-smoke`, `-illuminate`) | `Zeus.lua:1-105`, `zeus_Full_v2.1.lua` |
| 15 | Fumée / fusée éclairante / illumination sur les cibles | marquage acheté de jusqu'à 3 cibles d'une zone ennemie | `zc2:23618-23775`, `setup:4547-4634` |
| 16 | `DynamicSupportNative` | registre et surveillance des munitions toutes les 30 s des vols IA achetés (messages en vol, winchester, posé, détruit) | `zc2:106261-106469` |
| 17 | Hunt | 2 appareils rouges envoyés après un joueur qui a beaucoup de kills | `zc2:40974-41168` |
| 18 | Splash damage (variante Foothold) | kills par splash attribués aux joueurs, options réglées | `Splash_Damage_3.4.1_leka.lua` |
| 19 | Aide, informations radio, météo | textes d'aide, validation des réglages radio, fiche de fréquences du kneeboard, relevés de vent et de température | `zc2:13632-13690`, `loc:2055` |

Sous-systèmes Moose : **aucun de `CSAR`, `INTEL`, `ATIS`, `AIRBOSS`, `RECOVERYTANKER`, `RESCUEHELO`, `MSRS` n'est instancié** par les scripts Foothold de ce thème (grep de `<CLASS>:New` dans `zoneCommanderv2.lua`, `WelcomeMessage.lua`, `EWRS.lua`, `Zeus.lua`, le fichier de setup : 0 résultat).
Moose sert de boîte à outils : `SPAWN`, `SCHEDULER`, `COORDINATE`, `UTILS`, `MESSAGE`, `MARKER`, `MENU_GROUP*` (WelcomeMessage uniquement), `SET_CLIENT`, `ZONE*`, `AIRBASE`, `ASTAR`, `EVENTS`/`BASE:HandleEvent`.
Scripts livrés dans le `.miz` du Caucase : `AIEN.lua`, `EWRS.lua`, `Foothold Config.lua`, `Foothold CTLD.lua`, `Foothold_CTLD_Red.lua`, `Foothold_Localization.lua`, `MA_Setup_CAv2.lua`, `Moose_2026-10-11.lua`, `Splash_Damage_3.4.1_leka.lua`, `WelcomeMessage.lua`, `Zeus.lua`, `zoneCommanderv2.lua`.

## 1. Drone JTAC (auto-lase) — `JTAC`

### Ce que voit le joueur

- Acheté via l'article de boutique `jtac` (« JTAC MQ9 », clé de label `SYRIA_SHOP_ITEM_JTAC_MQ9`), puis on choisit une zone cible ; la zone doit être rouge et non suspendue (`setup:4246-4275`).
- Un sous-menu F10 « JTAC … <zone> » (`JTAC_MENU_TITLE`), valable pour toute la coalition, apparaît avec : Target report, Next target, Smoke on target, Change smoke color (5 couleurs), Flare on target, Set priority (SAM / Structures / Infantry / Armor / Support / Clear), Set laser code (cadran à trois niveaux de chiffres 1111–1788, puis « Accept »), Select target (liste numérotée, sous-menus « More » toutes les 9 entrées) (`zc2:7522-7720`, `zc2:8054-8148`).
- Les messages sont des textes visibles de toute la coalition : "JTAC is deployed, Looking for targets, standby" (`loc:1498`), le rapport de désignation "Lasing <type> at <zone> … Code: <n>" suivi de DDM, DMS, MGRS et de l'altitude en m/ft (`zc2:7781-7843`, `loc:1502`), "kill confirmed", "no more targets".
- Le code laser peut aussi être réglé par un marqueur de carte dont le texte est `jtac-code:<1111-1788>` ; le marqueur est supprimé après usage (`zc2:7403-7418`).
- Deux drones JTAC au plus en même temps ; en acheter un troisième détruit le plus ancien (`setup:4255-4259`).
- La fumée est larguée à 50–100 m de la cible, sur un cap aléatoire, et le message donne le décalage et la direction cardinale de la fumée vers la cible ; la fusée éclairante est une fusée de signalisation rouge à 20–40 m (`zc2:7556-7592`, `zc2:7631-7663`).

### Ce que règle le créateur de mission

- Le `.miz` doit contenir des groupes de drones en late activation nommés `jtacDrone1`, `jtacDrone2` (moderne) et `jtacDroneColdwar1`, `jtacDroneColdwar2` (époque guerre froide, un F-14 « Tomcat » d'après les clés de message) ; le setup détruit les quatre au démarrage et construit les objets `JTAC` à partir de la paire qui correspond à `ColdWarTechEra` (`setup:4236-4245`).
- Le JTAC auto-lase **n'est pas enregistré en mode PvP** (garde `GlobalSettings.pvpEnabled ~= true`, `setup:4240`, `setup:4291`).
- Prix dans `ShopPrices.jtac = 500`, entrée `jtac = 2` dans la table des rangs requis (`setup:2908`, `setup:2945`).
- `UseStatics` ajoute la catégorie de priorité « Structures » (`zc2:7372-7374`).

### Mécanisme

- Code Foothold à 100 % sur l'API DCS brute ; Moose ne sert qu'au spawn (`SPAWN:NewFromTemplate(tpl, name, nil, true):OnSpawnGroup(...):SpawnFromCoordinate(coord)` → `coalition.addGroup` avec le template pris dans `_DATABASE.Templates.Groups[name].Template`), à la boucle de 5 secondes (`SCHEDULER:New(nil, self.searchIfNoTarget, {self}, 20, 5)` → `timer.scheduleFunction`), et au formatage via `COORDINATE`/`UTILS.tostringMGRS`/`UTILS.VecHdg` (`zc2:7980-8003`, `zc2:7781-7830`).
- Déploiement : le drone est généré à 6 000 m au-dessus du centre de la zone (`zoneCom._cz.point`), puis `setOrbit` le met en `SetInvisible`, `SetImmortal`, `SetUnlimitedFuel`, `EPLRS` activé, `AI.Option.Air.id.SILENCE`, et lui donne une tâche `Orbit` / `Circle` à 6 000 m ; première recherche de cible 15 s plus tard (`zc2:7980-8052`).
- Le déploiement annule aussi toute mission de reconnaissance sur cette zone et pose `jtacIntelActive[zone] = true` (la zone est traitée comme « intel connu » tant qu'un JTAC la survole) (`zc2:7986-7989`).
- Liste des cibles : chaque unité avec `getLife() >= 1` de chaque nom de groupe de `zone.built`, chaque static existant de cette liste, plus la cible entrepôt de la zone ; la liste est mise en cache dans `zone._jtacTargetSnapshot` et reconstruite quand un objet du cache est mort (`zc2:7420-7457`) ; la boucle de maintenance propre à la zone publie l'instantané quand un drone surveille la zone (`zc2:46078-46100`).
- Filtre de priorité : `Unit:hasAttribute(attr)` contre les listes d'attributs de la catégorie ; « StaticObjects » correspond à `Object.Category.STATIC` ; si rien ne correspond, la priorité est effacée avec un message (`zc2:7888-7910`).
- Tri : le rang le plus bas l'emporte parmi les attributs `SAM TR`=1, `IR Guided SAM`=2, `SAM SR`=3, `AAA`=4, `Tanks`=5, `IFV`=6, `APC`=7, `Artillery`=8, `SAM LL`=9, `SAM CC`=10, `Unarmed vehicles`=11, `Infantry`=12, `Structures`=13 ; une unité à la fois AAA et radar reçoit +0,1 (`zc2:7459-7501`).
- Désignation : `Spot.createLaser(emitterUnit, {x=0,y=2,z=0}, targetPoint, code)` et `Spot.createInfraRed(...)` ; les deux spots sont déplacés avec `Spot:setPoint` par un timer de 0,5 s qui se reprogramme lui-même (`timer.scheduleFunction`) tant que la cible vit (`zc2:7731-7779`).
- Boucle toutes les 5 s (`searchIfNoTarget`) : si le groupe du drone a disparu → on nettoie ; si la cible est morte → "kill confirmed", pause de 5 s, puis cible suivante ; si le nombre de cibles viables a baissé → reconstruction du menu Select target (`zc2:7942-7978`, `zc2:7911-7922`).
- « Next target » choisit une cible viable au hasard (`randomNext`), sinon la tête du tri par menace (`zc2:7924-7928`).
- Fin de vie : plus de cibles ou zone qui n'est plus hostile → `clearTarget` détruit les spots, arrête le scheduler, détruit le groupe du drone, supprime le menu et se retire de `jtacQueue` (`zc2:7845-7876`, `zc2:7930-7938`).
- État : global `jtacQueue` (drones actifs, 2 au maximum), `jtacIntelActive[zone]`, par objet `lasers`, `target` (nom d'unité), `laserCode`, `priority`, `smokeColor`.
- Les menus sont des menus **coalition** (`missionCommands.addSubMenuForCoalition`), pas par groupe ; le seul cadran du code laser crée plusieurs centaines de nœuds de menu par drone (`zc2:7689-7708`).

### Notes de reproduction

- Aucune dépendance Moose notable ; l'API `Spot`, `hasAttribute`, `trigger.action.smoke/signalFlare` sont du DCS brut.
- Le drone a besoin de la liste des noms de groupes générés de la zone (`zone.built`) et du couplage avec le drapeau « intel ».
- Le timer de mise à jour du laser de 0,5 s par drone et le tri complet à chaque recherche sont les seuls coûts récurrents ; deux drones au maximum les bornent.
- L'écouteur de marqueurs est un `world.addEventHandler` par objet JTAC (donc deux handlers, chacun analysant chaque changement de marqueur) (`zc2:7403-7418`).

## 2. Drones JTAC 9-line (AM / FM) — `JTAC9line`, `JTAC9linefmr`

### Ce que voit le joueur

- Articles de boutique `9lineam` et `9linefm` (prix 0, rang 1 dans le setup du Caucase : `setup:2909-2910`, `setup:2991-2992`), puis on choisit une zone ennemie.
- Le drone est un **FAC DCS natif** : le joueur le contacte par le menu radio standard de DCS (check-in JTAC, 9-line, marquage laser/fumée/IR : tout est fait par la logique FAC de l'IA DCS).
- Fréquences : 241,000 MHz AM (`zc2:8245-8246`) et 31,000 MHz FM (`zc2:8374-8375`) ; index de callsign `callname = 2`, `number = 1`, `designation = 'Auto'`, `datalink = true`.
- Un message à la coalition annonce le drone et sa fréquence (clés `SYRIA_SHOP_JTAC_REAPER_AM/FM`, `SYRIA_SHOP_JTAC_TOMCAT_AM/FM`) (`setup:4327-4338`).

### Ce que règle le créateur de mission

- Groupes en late activation `JTAC9lineam`, `JTAC9lineamColdwar`, `JTAC9linefm`, `JTAC9linefmColdwar` dans le `.miz` ; détruits au démarrage, regénérés depuis le template (`setup:4296-4313`, `setup:4353-4371`).
- En mode PvP, un objet par camp est créé (le rouge à partir d'un template en miroir) et les deux camps peuvent l'acheter (`setup:4299-4308`, `setup:4345`).

### Mécanisme

- Spawn à 6 000 m au-dessus du centre de la zone via `SPAWN:NewFromTemplate():SpawnFromCoordinate()` ; `setTasks` applique `SetInvisible`, `SetImmortal`, `SetUnlimitedFuel`, `EPLRS`, puis une `ComboTask` de `{id='FAC', params={frequency, modulation, callname, number, designation='Auto', datalink=true, priority=1}}` + `Orbit` circulaire à 6 000 m (`zc2:8162-8275`).
- `jtacZones[zone] = {drone = <group name>}` enregistre quelle zone a un drone 9-line ; `CheckJtacStatus()` détruit le drone quand sa zone n'est plus une zone ennemie active (`setup:4412-4470`) ; elle est appelée depuis deux endroits de `ZoneCommander` : `disableZone` (la zone est désactivée et passe neutre, `zc2:50185`, `zc2:50216-50225`) et `_neutralizeEmptyBuiltZone` (le dernier défenseur de la zone a été détruit et elle devient neutre, `zc2:55294`, `zc2:55419-55424`).
- `BattleCommander:_hasActiveJtacOnZone` répond à « y a-t-il un JTAC (de l'un ou l'autre type) sur cette zone » pour les autres sous-systèmes (`zc2:37190-37216`).
- Tout ce qu'entend le joueur vient du FAC intégré de DCS ; Foothold n'écrit lui-même aucun texte 9-line.

### Notes de reproduction

- Trivial sans Moose : un `coalition.addGroup` et un `Controller:setTask`.
- La tâche FAC engage en « Auto » : DCS choisit les cibles parmi ce que le FAC détecte ; il n'y a pas de liste de cibles Foothold ici.

## 3. Désignateur laser du joueur — `SelfJtac` (menu « Laser Designator »)

### Ce que voit le joueur

- Sous-menu F10 de groupe « Laser Designator » (`loc:1510`) pour les joueurs qui pilotent l'un des types listés : SA342L, SA342M, UH-60L, UH-60L_DAP, AH-6J, OH-6A, Bronco-OV-10A, F-4E-45MC (`zc2:97528-97542`).
- Entrées : Search, Target info, Mark with Smoke, Clear, Priority (SAM / Infantry / Armor / Support / Structures / Clear), Options (Toggle KM / NM, Auto Search on/off, Auto-Next Target on/off, Hide coordinates on/off, Ignore structures on/off, cadran du code laser), Select target (`zc2:96617-96746`).
- Rapport (texte de groupe, 60 s, vue dégagée) : type de cible, code laser, relèvement magnétique et distance depuis le joueur, puis DDM / DMS / MGRS / altitude sauf si « hide coordinates » est actif (`zc2:96963-97026`).
- « Mark with Smoke » pose une fumée **bleue** exactement sur la cible (`zc2:97029-97042`).
- Messages : "target out of bounds" quand la cible sort du cône, de la portée ou de la ligne de vue, "kill confirmed", "no targets found", "target lost".

### Ce que règle le créateur de mission

- Aucun interrupteur de Config trouvé pour la table des types ; les limites par type sont codées en dur : `minDist` (en réalité la portée **maximale**, en km), `maxDeviation` (demi-cône en degrés par rapport au nez), `laserOffset` (origine du pointeur IR sur la cellule) (`zc2:97528-97536`).
- Les options par joueur (auto search, auto next, hide coordinates, ignore structures) sont persistées par nom de joueur et exportées/importées avec la sauvegarde des rangs (`zc2:96393-96506`, `zc2:43833-43843`).

### Mécanisme

- Code Foothold à 100 % ; Moose seulement pour `COORDINATE:HeadingTo`, `GetMagneticDeclination`, `ToStringMGRS` dans le rapport (`zc2:96983-97007`).
- Création : au spawn du joueur, `LogisticCommander:_refreshSelfJtacForSpawn` construit un `SelfJtac` pour le groupe si le type d'unité a des statistiques, en remplaçant l'éventuel précédent (`zc2:101266-101287`) ; `setAirborne(true)` au décollage et `setAirborne(false)` à l'atterrissage ou au départ (`zc2:101806-101808`, `zc2:42451-42453`), l'atterrissage efface la cible (`zc2:96804-96814`).
- Recherche : `world.searchObjects({UNIT, STATIC}, SPHERE(player ground point, radius = minDist km))`, on garde les objets actifs de la coalition ennemie, puis on filtre par distance, par `|bearing − aircraft heading| <= maxDeviation`, et par `land.isVisible(playerPoint+1.5 m, targetPoint+1.5 m)` (`zc2:97245-97311`).
- Choix : la cible viable la plus proche du joueur, ou — après un kill avec auto-next — la plus proche de la dernière position de la cible précédente, avec préférence pour le même groupe ennemi (`zc2:97347-97371`, `zc2:97165-97181`).
- Suivi : `setTarget` revérifie portée/cône/LOS, crée `Spot.createLaser(playerUnit, {0,5,0}, surfacePoint, code)` et `Spot.createInfraRed(playerUnit, laserOffset, point)`, ne les déplace que si la cible a bougé d'au moins 0,5 m, et se reprogramme toutes les **0,1 s** (1 s pendant la réacquisition) via `timer.scheduleFunction` (`zc2:96872-96961`).
- Perte de suivi avec auto-search actif : les spots sont détruits, état `_reacquiring`, et à chaque tick on teste au plus 3 cibles du cache (curseur tournant) pour la visibilité afin de sauter vers une autre cible (`zc2:96911-96925`, `zc2:97086-97135`).
- Auto search : un timer de 30 s par joueur tant qu'il est en vol (`zc2:96789-96796`).
- Les métadonnées de cible (catégorie, type affiché, nom de groupe, attributs) sont mises en cache par nom de cible et élaguées aux objets vus lors de la dernière recherche (`zc2:96508-96556`).
- État : `SelfJtac.jtacs[groupId]`, `SelfJtac.savedPlayerSettings[playerName]`.

### Notes de reproduction

- Le timer à 10 Hz par joueur pendant qu'une cible est désignée est la partie sensible pour les performances ; la recherche elle-même est une sphère `world.searchObjects` de 30 km de rayon au plus, lancée à la demande ou toutes les 30 s.
- L'émetteur laser est l'unité du joueur lui-même (`Spot.createLaser` avec une unité de joueur comme source fonctionne dans DCS), donc le spot suit l'appareil.
- Les menus sont par groupe et reconstruits de façon sélective (les éléments d'option sont retirés puis rajoutés pour afficher l'état ON/OFF courant) (`zc2:96686-96727`).

## 4. CSAR : pilotes abattus, sauvetage, pilotes ennemis

**Rien de tout cela n'est le `CSAR` de Moose.**
Toute la fonctionnalité est du code Foothold dans `LogisticCommander` (`zc2:98446-101025`, `zc2:101831-102230`) ; Moose sert au spawn (`SPAWN:NewWithAlias():InitCoalition():SpawnFromPointVec3()` → `coalition.addGroup`), au déplacement du survivant (`GROUP:RouteToVec2` → une tâche `Mission` avec des waypoints au sol via `Controller:setTask`), à `COORDINATE:Translate/HeadingTo`, et à `SCHEDULER`.

### Ce que voit le joueur

- Sous-menu F10 de groupe « CSAR » pour les appareils dont le type a une capacité > 0 dans `AllowedCsar` : Info on closest pilot, Info on three closest pilots, Deploy smoke at closest pilot, Deploy flare at closest pilot, Smoke nearest zone, Flare nearest zone (ces deux-là appellent `SmokeZoneNearBy` de l'objet CTLD), et — quand le template de pilote ennemi existe — Info on closest enemy pilot, Deploy smoke at closest enemy pilot (`zc2:101522-101553`, `loc:1808-1814`).
- Chaque pilote ami abattu a un marqueur de carte de coalition dont le libellé est "[player] Lost: N Credits" ou "Downed pilot", plus "ADF: nnn kHz" ; les pilotes ennemis sont libellés "enemy pilot" (`zc2:99283-99362`, `loc:1830-1833`).
- Chaque pilote ami émet une balise ADF (`beacon.ogg`) sur une fréquence aléatoire de 250–700 kHz, 1 000 W (`zc2:100578-100602`).
- Déroulé du sauvetage : à moins de 3 km le pilote répond ("We hear you! Request smoke if needed", infos de relèvement/distance) et tire 3 fusées éclairantes ; à moins de 650 m "You're close now! I'm at your N o'clock. Land in a safe place, we will come to you" et 3 fusées de plus ; si l'hélicoptère est au sol à moins de 650 m le survivant court vers lui ("I'm coming to you. ETA n seconds") et monte à bord à moins de 20 m ; sinon, récupération en vol stationnaire : dans la distance de hover, sous la hauteur de hover et sous 5 m/s pendant la durée de hover, avec un guidage "Forward/Right/Left/Back n m, descend n ft" et un compte à rebours (`zc2:100612-100692`, `zc2:100387-100440`, `zc2:100953-100996`, `zc2:97764-97766`, `loc:1846-1858`).
- L'embarquement ajoute `PilotWeight` (80 kg) par pilote à l'appareil (`trigger.action.setUnitInternalCargo`) et affiche "Pilot onboard [n/max]" (`zc2:98766`, `loc:1862`).
- Dépose : se poser dans une zone amie ; "Pilots dropped off", et chaque joueur sauvé voit sa statistique « Deaths » décrémentée (`zc2:98767-98774`).
- La récompense est versée au **ramassage**, au **sauveteur** : `boardPilot` ajoute `rewards.rescue` (200 par défaut) plus les 75 % que le joueur éjecté avait perdus (`pilotData.lostCredits`) à la bourse du sauveteur (`bc:addContribution`), compte une statistique `Pilot Rescue` et le `PilotRescues` de la carrière, remet `lostCredits` à zéro sur la fiche (`rescueRewardPaid`), et annonce à la coalition "[X] rescued [Y] +N credits. Land at any friendly zone to drop off." (`CSAR_RESCUED_WITH_CREDITS` ; simple `CSAR_RESCUED` quand rien n'est versé, par exemple si le sauveteur n'est pas inscrit) (`zc2:100535-100560`, `loc:1860`).
- Donc le joueur éjecté ne récupère pas ses crédits par un sauvetage : ils passent dans la bourse du sauveteur et sont encaissés quand celui-ci se pose (note 05 §3.2) ; le joueur sauvé voit seulement sa statistique `Deaths` décrémentée à la dépose (`zc2:100540-100550`, `zc2:98767-98774`).
- L'embarquement est refusé à pleine capacité (`CSAR_AT_MAX_CAPACITY`) ; un pilote ennemi monte à bord à moins de 50 m au lieu des 20 m de la distance de chargement et donne "enemy onboard" sans crédits à ce moment (`zc2:100516-100521`, `zc2:100563-100566`).
- Un joueur qui s'éjecte et atterrit **dans une zone amie** est « posé sain et sauf » et récupère les crédits perdus ; dans une zone ennemie, il a 60 s de grâce puis est traité comme en territoire hostile, ou "captured by enemy forces … Assumed dead" (`zc2:101926-101957`).
- Un survivant à moins de 3 NM d'une zone amie ou d'un FARP rentre tout seul en courant à 3,6 m/s ("Ejected Pilot X is running toward Y"), et il est terminé à l'arrivée ("is now home", crédits récupérés) ; un hélicoptère proche peut interrompre la course pour le ramasser (`zc2:99761-99811`, `zc2:99677-99743`, `zc2:100694-100728`, `loc:1837-1841`).
- Infanterie ennemie : 25 % de chances (Config) que 1 à 3 groupes d'infanterie hostile apparaissent à 0,2–0,4 NM autour d'un pilote abattu hors de toute zone et à moins de 20 NM d'une zone ennemie ; 120 s plus tard la coalition est avertie "Enemy forces have surrounded [X]. Hurry and save him" (`zc2:101977-102112`, `zc2:102196-102217`).
- Pilotes ennemis (PvE) : un pilote IA rouge qui se pose après éjection dans une zone bleue est « capturé » aussitôt ; ailleurs un groupe `RedDownedPilot` est généré et peut être ramassé (distance de chargement 50 m) puis livré à une zone amie pour `enemyPilotCapture` crédits (200 par défaut) et un « debrief » (`zc2:101904-101924`, `zc2:100767`, `zc2:42284-42311`).
- S'approcher d'un pilote ennemi a 10 % de chances de déclencher une embuscade (1 à 3 groupes d'infanterie, message `CSAR_ENEMY_AMBUSH`) (`zc2:98474-98541`).
- Debrief des pilotes capturés (10–60 s plus tard) : 50 % de chances par pilote d'obtenir l'intel d'une zone ennemie, 20 % de chances d'un message révélant la cible/phase de l'opération en cours du Director ennemi ou sa priorité défensive, sinon l'une des 7 lignes « debrief failed » (`zc2:42313-42363`).

### Ce que règle le créateur de mission

- Templates dans le `.miz` : `Downed Pilot` (bleu), `RedDownedPilot` (sa présence active le CSAR des pilotes ennemis : `zc2:102274`), `CSAR_RED_INF_1`, `CSAR_RED_INF_2` infanterie hostile (`zc2:97724`).
- Config (`cfg:2198-2257`) : `AllowedCsar` (type → sièges ; 0 masque le menu ; par ex. UH-1H 11, Mi-8MT 24, CH-47 32, AH-64D 2), `CsarPilotSpawnWithoutCreditsChance = 50`, `Max_CSAR_At_Once = 10`, `Max_CSAR_AT_Mission_Restart = 10`, `PilotWeight = 80`, `CsarHoverDistance = 20`, `CsarGuidanceDistance = 70`, `CsarHoverHeight = 60`, `CsarHoverSeconds = 10`, `CsarHostileInfantryChance = 25`.
- Codé en dur : approche 3 000 m, extraction 650 m, chargement 20 m (`zc2:97764-97766`) ; retour à pied 3 NM / arrivée 120 m / 3,6 m/s sauf si `CsarHomeDistanceNM`, `CsarHomeArrivalDistance`, `CsarHomeRunSpeed` sont définis (`zc2:97719-97721`).
- Récompense `enemyPilotCapture = 200` dans la table des récompenses (`cfg:1931`).
- L'infanterie hostile est ignorée sur la carte Normandie (`zc2:101977`).

### Mécanisme

- Événements (un seul `world.addEventHandler` dans BattleCommander) : `S_EVENT_EJECTION` → `_handleRewardEjection` enregistre qui s'est éjecté et les crédits perdus, indexés par id d'appareil (`ejectedPilotOwnersByAircraft`) (`zc2:43081-43086`, `zc2:42133`) ; `S_EVENT_LANDING_AFTER_EJECTION` → `_handleLandingAfterEjection(event, pilotUnit, aircraftID = event.place.id_, …)` (`zc2:42980-42991`).
- À l'atterrissage : eau → l'objet pilote DCS est détruit et rien ne se passe ; pilote IA sans données de propriétaire → généré seulement avec `CsarPilotSpawnWithoutCreditsChance` ; un survivant par appareil IA ; sinon un groupe `Downed Pilot` est généré à 10 m de l'épave ou du point d'atterrissage (8 caps candidats, en évitant l'eau) et rendu invisible à l'IA si des hostiles ont été générés (`zc2:101851-101888`, `zc2:101960-101975`, `zc2:102113-102126`, `zc2:102139-102183`).
- La fiche du pilote (`player`, `coalition`, `lostCredits`, `timestamp`, noms des groupes hostiles, drapeau d'embuscade) est liée à l'id d'objet de l'unité générée dans `csarPilotDataByObject` / `landedPilotOwners` ; l'unité entre dans `self.ejectedPilots` (`zc2:102186-102229`, `zc2:100244-100290`).
- Boucle principale : `SCHEDULER:New(nil, self.update, {self}, 10, 10)` — toutes les 10 s (`zc2:102276`) ; elle élague les survivants morts (message KIA), rafraîchit les balises (réémises seulement si le point a changé, contrôle toutes les 25 s), puis pour chaque survivant × chaque appareil de joueur éligible calcule la distance et applique les seuils ci-dessus (`zc2:100237-100300`, `zc2:100757-101023`).
- Scrutation adaptative : par survivant un `csarNextTick` (10 s au-delà de 3 km, 5 s en deçà, 3 s à moins de 650 m, 1 s pendant le chargement ou le hover) et, quand un hélicoptère est proche, une boucle rapide dédiée `timer.scheduleFunction` toutes les 3 s ; le compte à rebours du hover a son propre timer de 2 s par (pilote, groupe) (`zc2:100997-101015`, `zc2:100912-100918`, `zc2:100410-100432`).
- Les messages sont dédupliqués par (pilote, groupe) et regroupés : un second survivant à moins de 92 m et 20 s ne répète pas le message (`zc2:100625-100638`).
- Transport : compteur `carriedPilots[groupId]` et manifeste `carriedPilotData[groupId]` ; si l'appareil sauveteur est perdu, son manifeste est effacé (`zc2:43062-43068`).
- Rééjection des pilotes transportés : quand un sauveteur s'éjecte, `_handleRewardEjection` clone son manifeste (`_cloneCarriedPilotDataForEjection` : une copie de chaque fiche de pilote transporté, sans ses champs de groupe hostile et de grâce) et l'attache comme `carriedRescuedPilots` à la fiche du premier membre d'équipage éjecté éligible ; le manifeste de l'appareil est ensuite effacé (`zc2:98638-98666`, `zc2:42137-42153`, `zc2:41771-41809`).
- Quand le parachute de ce membre d'équipage se pose (`_handleLandingAfterEjection`), chaque pilote transporté est regénéré comme son propre groupe `Downed Pilot` sur un petit anneau (rayon 3–5 m, caps régulièrement répartis) autour du survivant du sauveteur, lié à sa fiche d'origine (son nom figure donc toujours sur le marqueur ; `lostCredits` vaut déjà 0 si la récompense de sauvetage a été versée), remis dans les files CSAR et, si une zone amie est proche, envoyé en courant vers elle (`zc2:102231-102265`).
- Cela se produit aussi quand le sauveteur lui-même ne produit aucun survivant (il se pose dans une zone amie, ou le dé « sans crédits » dit non) : `skipMainPilot` fait continuer la fonction uniquement pour générer les passagers (`zc2:101953-101957`, `zc2:101969-101973`).
- Un pilote ennemi transporté n'est regénéré que là où le CSAR de pilote ennemi est possible (pas près d'une zone de son propre camp) (`zc2:102246-102248`).
- Limite : les survivants les plus anciens sont retirés au-delà de `Max_CSAR_At_Once` (`zc2:99960`) ; les survivants sont persistés et restaurés au redémarrage (`zc2:100094`, `zc2:44890`).
- Fumée/fusée sur le pilote : fumée bleue sur le survivant le plus proche, salves de fusées via `_signalPilotFlareBurst` (`zc2:98830-98958`).

### Notes de reproduction

- L'identification de « quel joueur s'est éjecté » repose sur le fait que `event.place.id_` de `S_EVENT_LANDING_AFTER_EJECTION` est l'id d'objet de l'appareil enregistré à `S_EVENT_EJECTION`.
- L'objet pilote éjecté natif de DCS est remplacé par un groupe d'infanterie contrôlable (pour pouvoir le router et le faire survivre comme groupe) ; l'objet natif est détruit.
- Les balises utilisent `trigger.action.radioTransmission(file, point, AM, loop, freq, power, name)` et doivent être arrêtées par leur nom (`stopRadioTransmission`) quand le survivant bouge ou est sauvé.
- Modèle de coût : O(survivants × appareils de joueur éligibles) toutes les 10 s, borné par `Max_CSAR_At_Once`, avec un back-off par survivant.
- Le survivant qui « rentre en courant » et celui qui « court vers l'hélicoptère » demandent un routage au sol hors route et une scrutation de l'arrivée (30 s pour le retour).

## 5. Intel de zone (« Intel on enemy zone »)

**Ce n'est pas le `INTEL` de Moose.** Aucun `INTEL:New` n'existe dans aucun fichier Foothold ; la fonctionnalité est un ensemble de fonctions libres `_zoneIntel*` (`zc2:5567-7014`) qui lisent la liste propre de la zone des groupes générés.

### Ce que voit le joueur

- Point d'entrée : article de boutique `intel`, puis choix d'une zone ennemie non suspendue ; message "gathering intel" (`setup:4762-4794`).
- 10 s plus tard, un message à la coalition avec le son `Intel.ogg` : "Intel on <zone>:" puis les lignes "Identified SAMs: …", "Armor: …", "Artillery: …", "Ground forces: …" (avec l'indicateur MANPAD), "AAA: …", "Structures: …" (y compris "Warehouse building"), "Additional contacts: …" (`zc2:6387-6417`, `loc:1232-1273`).
- Carte : un marqueur de coalition en lecture seule par groupe/static ennemi vivant de la zone, posé sur sa première unité vivante et libellé avec le nom du groupe, plus un marqueur sur l'entrepôt de la zone (`zc2:6749-6821`).
- Toutes les 20 s les marqueurs suivent les groupes et un message "Intel update on <zone>:" liste les différences : "X destroyed", "X detected", "TR destroyed; site degraded", "Enemy repaired X STR", "MANPAD threat neutralized…" (`zc2:6897-6907`, `loc:1233-1256`).
- Tant que l'intel est actif sur une zone, d'autres sous-systèmes émettent des lignes "Intel:" supplémentaires à son sujet : un groupe itinérant "is on the move", des appareils ennemis "starting up at / just took off from / inbound and about to land at", "enemy convoy moving out from / about to arrive at", "The enemy is launching a mass attack on" (`loc:1257-1264`, `zc2:6691`).
- Durée : 60 min pour un achat, 30 min quand il est accordé par un pilote ennemi capturé ; racheter pendant que l'intel est actif garde la plus tardive des deux expirations (elles ne s'additionnent pas) (`zc2:6962-6991`, `zc2:42411`) ; à l'expiration "Intel on <zone> has expired." (`zc2:6947-6950`).
- Le menu F10 de groupe « Intel » liste les zones avec un intel actif et réimprime le rapport courant (`zc2:103337-103393`) ; la commande de marqueur de carte `intelstatus` sur une zone imprime son statut avec le détail de l'intel (`zc2:29068-29079`).
- Aucune formulation « extend coverage » n'a été trouvée sous ce nom dans le fichier de localisation ; le seul mécanisme d'extension lu est le maximum des expirations ci-dessus.

### Ce que règle le créateur de mission

- Globales `zoneIntelRefreshSec` (20 par défaut, plancher 5) et `zoneIntelStartupMessageDelaySec` (10 par défaut) (`zc2:5567-5569`).
- La classification des contacts mêle des faits sur les unités et des **motifs de noms de groupes**, donc elle dépend de la convention de nommage des templates du fichier de setup (tableau ci-dessous, `zc2:5783-5825`, `zc2:6240-6373`).

| Catégorie dans le rapport | Comment un groupe / static généré de `zone.built` y est classé | Code |
|---|---|---|
| Site SAM à longue portée (`SA-2`, `SA-3`, `SA-5`, `SA-6`, `SA-10`, `SA-11`, `HAWK`, `NASAMS`, `PATRIOT`) | une unité vivante dont la « famille SAM » (issue des fiches d'unités du template d'upgrade, sinon `BattleCommander.ClassifySeadThreatFamily(groupName, typeName)`) est l'une de celles-ci ; pour un static, le nom contient `red sam sa-10`, `-11`, `-6`, `-5`, `-3`, `-2` | `zc2:5700`, `zc2:6263-6292`, `zc2:5783-5791`, `zc2:6341-6356` |
| Site « degraded » | le site est vivant mais aucune unité vivante ne correspond au motif de son type de radar de poursuite (`CustomZone.samTrackerPatterns` : SA-2 `snr_75v`, SA-3 `snr s-125 tr`, SA-5 `rpc_5n62v`, SA-6 `kub 1s91 str`, SA-10 `40b6m tr`, SA-11 `9s18m1`, HAWK `hawk tr`, NASAMS `nasams_radar`, PATRIOT `patriot str`) | `zc2:5702-5712`, `zc2:6270-6273`, `zc2:6375-6382` |
| SHORAD (Pantsir S1, SA-15, Tor M2, SA-19, SA-13, SA-9, SA-8, Avenger, Roland) | une unité vivante d'une famille SAM sans motif de poursuite ; pour un static, le nom contient `red sam shorad pantsir`, `sa-15`, `tor m2`, `sa-19`, `sa-13`, `sa-9`, `sa-8` | `zc2:5701`, `zc2:6293-6296`, `zc2:5793-5802` |
| Blindés (Armor) | le nom du groupe contient `armour`, `armor`, `red mech group` ou `red special` | `zc2:5804-5809`, `zc2:6301-6303` |
| AAA | le nom du groupe contient `aaa` ; sous-type d'après les types d'unités vivantes : Flak (`ks-19`, `s-60`, ou un radar `son_9` déjà vu), Heavy AAA (`zsu_57_2`), Shilka, ZU-23, Other ; un groupe Flak dont le SON-9 est mort est « Flak radar destroyed » | `zc2:5811-5813`, `zc2:5976-6029`, `zc2:6304-6322` |
| Artillerie (Artillery) | le nom du groupe contient `artillery` ou `arty` | `zc2:5815-5818`, `zc2:6323-6325` |
| Forces au sol (Ground forces) | le nom du groupe commence par `enemy task forces` ou `enemy ground forces`, ou tout autre groupe ayant un MANPAD vivant (le nom du type, ou son nom affiché via `renameType`, contient `manpad`) ; l'indicateur MANPAD est conservé par groupe | `zc2:5820-5823`, `zc2:5959-5974`, `zc2:6326-6336` |
| Structures | un static vivant qui n'est ni un site SAM ni du SHORAD ; son nom affiché est le nom de base du static suivi, sinon celui du static créé à la main le plus proche dans la zone (`zone.newStatics`, même type à moins de 25 m, n'importe quel type à moins de 15 m), sans les nombres finaux ni le mot « Fixed » | `zc2:6338-6365`, `zc2:5838-5891`, `zc2:5766-5776`, `zc2:5825-5836` |
| Bâtiment d'entrepôt (Warehouse building) | `zone.warehouseFacility.state` (`operational` / détruit) | `zc2:6236-6238` |
| Contacts additionnels (Additional contacts) | tout ce qui est vivant et ne correspond à rien ci-dessus, compté par nom de base | `zc2:6369-6372` |

- Un groupe nommé `blue sam aaa…` sans unité AAA vivante est ignoré silencieusement (`zc2:6299-6300`).

### Mécanisme

- État par camp et par zone : `zoneIntels[side][zone]` (dernier instantané, table de marqueurs, prochaine heure de rafraîchissement), `intelExpireTimes[side][zone]`, `intelActiveZones[side][zone]` (`zc2:6954-7013`).
- Pas de timer propre : `_zoneIntelUpdateActiveZones(now)` est appelée à la fin de chaque cycle de mise à jour des zones de BattleCommander (`zc2:43255-43258`) et se limite elle-même avec `state.nextIntelAt` (`zc2:6882-6909`).
- L'intel s'arrête quand la zone devient neutre ou amie, ou à l'expiration (`zc2:6873-6877`).
- Marqueurs : `MARKER:New(coord, text):ReadOnly():ToCoalition(side)` de Moose, déplacés avec `UpdateCoordinate` quand le point a changé de plus de 1 m (`MARKER` enveloppe `trigger.action.markToCoalition` / suppression + recréation) (`zc2:6719-6726`, `zc2:6796-6803`).
- Démarrer l'intel annule une mission de reconnaissance en attente sur la même zone (`zc2:6999-7003`) ; un drone JTAC au-dessus de la zone pose `jtacIntelActive[zone]` séparément (`zc2:7989`).
- En PvE avec l'option « SAM MFD reveal », l'intel bleu sur une zone rouge révèle aussi les sites SAM (`revealSamSites`, `zc2:6885`).

### Notes de reproduction

- Le constructeur de messages instantané/différentiel (≈450 lignes, `zc2:6203-6665`) est le gros du travail.
- Instantané (`_zoneIntelBuildSnapshot(zoneName, state, groupSamples, revealSamSites)`) : `{longSites = {[site] = {alive, degraded}}, shorad = {[name] = count}, counts = {armor, artillery, ground, groundWithManpad, aaaTotal, aaaShilka, aaaHeavy, aaaFlak, aaaZu23, aaaOther, aaaFlakRadarDestroyed}, aaaFlakRadarByGroup, structures = {[name] = count}, additionalContacts = {[name] = count}, warehouse}` (`zc2:6204-6238`).
- Il parcourt un index de `zone.built` conservé dans l'état d'intel (`state.builtIndex[name] = {builtIndex, cleanName, lowerName}`, resynchronisé à chaque passage), lit chaque groupe une fois par rafraîchissement via un cache partagé `groupSamples` (`Group.getByName(name):getUnits()`, unité vivante = `isExist()` et `getLife() >= 1`), et résout le template d'upgrade du groupe pour obtenir les fiches d'unités par type (attributs, famille SAM, « radar SAM critique ») (`zc2:5901-5957`, `zc2:6246-6277`).
- Avec `revealSamSites`, chaque groupe portant une famille SAM vivante est enregistré pour le « SAM MFD reveal » (`zone:_recordSamMfdReveal`) (`zc2:6282-6284`).
- Message de démarrage (`_zoneIntelBuildStartupMessage`) : les catégories dans un ordre fixe, les sites SAM listés par nom avec "(degraded)" le cas échéant (`zc2:6387-6417`, `zc2:6061-6093`).
- Différentiel (`_zoneIntelBuildUpdateMessage(zone, old, new)`), dans cet ordre : changement d'état de l'entrepôt ; par site longue portée détruit / détecté, puis radar de poursuite perdu ("TR destroyed; site degraded", "STR destroyed" pour le SA-6, "SnowDrift" pour le SA-11, "SR" pour le NASAMS) ou réparé ; type de SHORAD disparu / détecté ; variations de comptes pour les blindés, la Flak, l'AAA lourde, le ZU-23, les autres AAA, l'artillerie, les forces au sol — **les pertes seulement**, les augmentations ne sont pas annoncées pour ces catégories ; radars de Flak détruits / réparés ; menace MANPAD neutralisée / identifiée ; contacts additionnels et structures ajoutés ou retirés par nom (`zc2:6446-6633`).
- Quand la mise à jour ne contient que des pertes, un récapitulatif « remaining » est ajouté : SAM restants, ligne AAA restante, structures restantes, contacts additionnels restants (`zc2:6639-6663`).
- Aucune mise à jour n'est envoyée quand rien n'a changé (`zc2:6635-6637`).
- C'est « omniscient » : pas de modèle de détection, il lit la liste de spawn propre de la zone.
- Les marqueurs sont par groupe, rafraîchis toutes les 20 s seulement pour les zones à intel actif.

## 6. Ravitailleurs à la demande (Arco / Texaco) et leur contrôle

### Ce que voit le joueur

- Articles de boutique `dynamicarco` (« Tanker (Drogue) ») et `dynamictexaco` (« Tanker (Boom) ») : l'achat « débloque » un menu de coalition pour choisir la zone de spawn, ou prend directement zone + schéma dans le menu de boutique du groupe : "Orbit" ou "Hot 360/045/…/315" × "10/20/30/40/50 NM Leg" (`setup:3099-3189`, `setup:3191`).
- Message de mise en station avec TACAN (`101Y`/`102Y`), fréquence (260 / 266 MHz AM) et indication de preset (BTN 14 / 20) (`zc2:107766-107782`, `zc2:13651-13664`).
- S'approcher à moins de 2 000 ft à l'horizontale / 500 ft à la verticale du ravitailleur affiche "Approaching Arco, <radio info>" à ce client (`zc2:105306-105312`, `zc2:105571-105597`).
- Menu F10 de groupe « Tankers Control » (réservé selon le rang) : "<Tanker>: Move to Zone" (zone amie → Orbit ou cap → branche), "<Tanker>: Altitude" (liste, courante marquée), "<Tanker>: Speed" (liste en kt), "Tanker Help" (infos radio + aide sur les marqueurs) (`zc2:16795-17078`, `loc:1887-1926`).
- Les menus « Move by Position » sont commentés, remplacés par des commandes de marqueurs (`zc2:16912-16913`).
- Marqueurs de carte `arcohere1` puis `arcohere2` (ou `texacohere1` / `texacohere2`) : le point 1 est dessiné comme un cercle bleu (250 m) avec une étiquette "ARCO 1" ; le point 2 calcule le cap et la branche à partir du point 1 et envoie le ravitailleur ; message "Arco moving, distance N NM. New racetrack: N NM leg, heading N°" (`zc2:28148-28352`, `loc:1952-1956`).
- Un repositionnement est refusé avec "Players currently near the tanker. Try again later." tant qu'un joueur est proche du ravitailleur (`zc2:105340-105366`).
- Le racetrack est dessiné sur la carte F10 comme une forme grise en « stade » avec une étiquette de texte (`DrawDynamicTankerRacetrack`, `zc2:105861-105928`) :
  - la forme part du point de station le long du cap du racetrack sur `leg + 4 NM` (`DYNAMIC_TANKER_RACETRACK_LENGTH_BUFFER_NM`), fait 6 NM de large (`…_WIDTH_NM`), et est décalée de 2 NM sur le côté de l'axe (`…_TURN_WIDTH_NM / 2`) pour couvrir les virages ; chaque extrémité est un demi-cercle de 30 segments (`zc2:105806-105809`, `zc2:105871-105904`) ;
  - elle est dessinée deux fois avec `trigger.action.markupToAll(7, coalition, id, points…, color, fill, lineType, true, text)` (id de forme 7 = polygone libre) : une fois en remplissage gris opaque à 32 % avec un contour invisible, une fois en contour de type de ligne 3 sans remplissage ; l'appel est construit comme une chaîne Lua et exécuté par `UTILS.DoString` parce que le nombre de points est variable (`zc2:105839-105858`, `zc2:105906-105917`) ;
  - l'étiquette « ARCO », « TEXACO », ou « ARCO / TEXACO » quand les deux ravitailleurs volent sur le même racetrack (même point de base à 0,1 NM près, cap à 1° près, branche à 0,1 NM près) est un `trigger.action.textToAll` de taille 16 placé à 30 % de la longueur (`zc2:105920-105927`, `zc2:105955-105963`, `zc2:105985-105999`) ;
  - visible de tous en PvE (coalition −1), du camp propriétaire seulement en PvP ; rien n'est dessiné pour une simple orbite (branche 0) ; tous les ids de marques d'un ravitailleur sont supprimés et redessinés à chaque repositionnement (`RefreshDynamicTankerRacetrackDrawings`) (`zc2:105842-105845`, `zc2:105869`, `zc2:105815-105822`, `zc2:105965-105999`).

### Ce que règle le créateur de mission

- Templates `Arco` et `Texaco` dans le `.miz` (générés par `Respawn.SpawnAtPoint('Arco', …)`) (`zc2:107726-107728`).
- Config : `TankerRadioSettings` (`Blue Arco` 260 MHz / TACAN 101, `Blue Texaco` 266 / 102, `Shell` 253 / 103, `Red Arco` 260 / 104, `Red Texaco` 266 / 105 ; TACAN toujours en bande Y) (`cfg:356-369`) ; `TexacoSpeed = 286`, `ArcoSpeed = 286` kt (`cfg:2306-2311`) ; prix de 1 000 et rang requis 3 (`cfg:1776-1777`, `cfg:1860-1861`).
- Le contrôle par marqueurs exige un groupe piloté par un humain, hors hélicoptère, du camp propriétaire, avec un rang ≥ au rang requis du ravitailleur (`zc2:28217-28232`).

### Mécanisme

- Spawn : le `Respawn.SpawnAtPoint` propre à Foothold (`zc2:1344`) construit le groupe depuis le template à la zone, 1 s plus tard applique les commandes de protection (`ApplyProtectionCommandsToGroupController`), active le TACAN avec `Controller:setCommand({id='ActivateBeacon', params={type=BEACON.Type.TACAN, system=BEACON.System.TACAN_TANKER_Y, AA=true, bearing=true, …}})`, et règle le racetrack (`zc2:107734-107765`, `zc2:107591-107611`).
- Racetrack : `BuildOrbitTask(point, heading, legNm, TAS, altitude)` + `ApplyOrbitMissionToGroup(...)` — une tâche brute mission/orbite, IAS convertie avec `UTILS.IasToTas` (`zc2:106089-106110`).
- La station (point, cap, branche, zone, vitesse, altitude) est sauvegardée et restaurée après un redémarrage (`_saveTankerStation`, `schedulePersistentTankerRestore`, `zc2:106112`, `zc2:106153`).
- Message de proximité : une zone Moose attachée à l'unité ravitailleur (`newUnitEnvelopeZone`, un objet de type `ZONE_UNIT`) avec `:Trigger(BlueClients)` où `BlueClients = SET_CLIENT:New():FilterCoalitions():FilterCategories("plane"):FilterActive():FilterStart()` ; Moose scrute l'appartenance au set sur un timer et déclenche `OnAfterEnteredZone` (`zc2:105305`, `zc2:105580-105595`).
- Gestionnaire de marqueurs : un seul `world.addEventHandler` sur l'id d'événement 26 (`S_EVENT_MARK_CHANGE`) ; le point 1 en attente est conservé dans `bc._pendingDynamicTankerRacetrackPoints[kind]` avec ses ids de dessin (`trigger.action.circleToAll`, `textToAll`) (`zc2:28242-28285`).

### Notes de reproduction

- La seule partie très Moose est la zone de proximité sur un `SET_CLIENT` ; le reste, ce sont des tâches brutes.
- « Hot NNN » désigne le cap de l'axe du racetrack depuis la zone ; « Orbit » correspond à une branche de 0.
- Un ravitailleur perdu en PvP est suivi (`_handlePvpSupportAircraftLoss`, `zc2:106043`).

## 7. AWACS (automatique, suit le front)

### Ce que voit le joueur

- Un AWACS rouge et un ou deux AWACS bleus sont toujours en vol ; les joueurs ne s'en servent que par la radio DCS (menu AWACS) et la liaison de données.
- Les fréquences sont affichées dans le texte d'accueil/briefing et configurées (`cfg:343-353`).
- PvP seulement : un AWACS perdu reste perdu tant que l'article de boutique `replaceawacs` (« Replace one lost AWACS », 1 000 crédits, rang 3) n'est pas acheté ; message "AWACS replaced" (`setup:3283`, `zc2:106029-106041`, `cfg:1779`, `cfg:1863`).

### Ce que règle le créateur de mission

- Templates `AWACS_RED`, `AWACS_BLUE` (ou `AWACS_BLUE_VT` à l'ère Vietnam), `AWACS_BLUE_SECONDARY` (`AWACS_BLUE_VT_SECONDARY`), `AWACS_RED_SECONDARY_PVP` (`zc2:9331-9336`).
- Setup : `AWACS_CFG = { [1] = {alt=30000, speed=350, hdg=270, leg=15, sep=150}, [2] = {…, sep=70} }` où `sep` est la distance voulue en NM à la zone ennemie la plus proche ; généré 10 s après le démarrage par `spawnAwacs(1|2, nil, 10)` (`setup:6046-6060`).
- Config `AWACSRadioFrequencies` (Blue 1 251, Blue 2 251,5, Red 1 252, Red 2 252,5 MHz AM) (`cfg:347-353`).

### Mécanisme

- Code Foothold à 100 % sur des tâches brutes (`Respawn.SpawnAtPoint`, `Controller:setCommand` `SetInvisible`, `SetImmortal` (PvE seulement), `SetUnlimitedFuel`, `EPLRS`, `REACTION_ON_THREAT = NO_REACTION`) (`zc2:10038-10146`).
- Choix de la station `_computeAwacsStationWithZone(side)` : parmi les zones actives du camp, on prend celle dont la distance à la zone ennemie la plus proche est la plus proche de `sep` ; égalités départagées par l'ordre des waypoints (bleu PvE) puis par le nombre de voisines du même camp (`zc2:9618-9665`).
- Un second AWACS bleu prend une station à au moins 100 NM du premier (`_computeAwacsStationWithZoneSecondary(…, 100)`, `zc2:10134-10141`).
- `RepositionAwacsToFront()` est programmée 15 s après qu'une zone change de camp (`SCHEDULER:New(nil, RepositionAwacsToFront, {}, 15)`, `zc2:56680`) et redonne une tâche à chaque AWACS ; un déplacement de moins de 50 m est ignoré (`zc2:9870-9922`, `zc2:9939-9943`).
- L'orbite est une tâche brute `Orbit`, cercle ou racetrack, altitude baro, cap vers la zone ennemie la plus proche (`zc2:9945-9960`, `zc2:10069-10073`).

### Notes de reproduction

- Il faut un index de distances entre zones (`_buildAwacsZoneInfo`, `Frontline._zoneInfo`) partagé avec le calcul du front.
- L'AWACS est invisible et (en PvE) immortel : c'est un service, pas une cible.

## 8. Contrôle des CAP et des autres vols achetés par les joueurs

- « CAP Control » est un sous-menu du menu de groupe `F10 > Other > Dynamic Control`, présent tant qu'un vol de CAP acheté (`dynamiccap`) est actif ; `buildCapControlMenu()` appelle simplement `bc:refreshDynamicControlMenusForBlue()`, qui appelle `refreshDynamicControlMenuForGroup` pour chaque groupe de joueurs bleus vivant (et rouges en PvP) et pour les groupes dont le menu doit être retiré (`zc2:107172-107174`, `zc2:16232-16257`).
- La racine Dynamic Control n'est créée que lorsqu'un vol acheté ou un ravitailleur est actif et que le groupe a un joueur humain ; elle n'est reconstruite que lorsqu'une chaîne de signature par groupe change (`zc2:16276-16281`, `zc2:16340-16350`, `zc2:16418-16427`).
- Arborescence exacte de « CAP Control » (`zc2:16461-16625`, libellés `loc:34`, `loc:1874-1881`) :

```
Dynamic Control > CAP Control
├─ Stop CAP auto-buy                 seulement pour l'acheteur tant qu'un ordre d'achat automatique a encore des remplacements (zc2:16462-16466)
├─ CAP: Reposition by Zone           zones amies (et neutres déjà capturées), par numéro de waypoint décroissant, "More" toutes les 9
│  └─ <zone> > Orbit | Hot 360 | Hot 045 | … | Hot 315 > 10 / 20 / 30 / 40 / 50 NM Leg      (zc2:16469-16540)
├─ CAP: Reposition by Position       relatif à la position courante de la CAP
│  └─ Reposition 360 … 315 > 0 … 100 NM (pas de 10) > Orbit | Hot 360 … 315 > NM Leg         (zc2:16543-16580)
├─ CAP Help                          imprime l'aide des marqueurs caphere1 / caphere2 (zc2:16583-16585)
├─ CAP: Hold Racetrack               ROE open fire, message "CAP is set to (Engage If Engaged)" (zc2:16586-16602)
├─ CAP: Flightsweep                  ROE weapon free, message "CAP set to Engage All" (zc2:16603-16619)
└─ CAP: Destroy                      despawnCap (zc2:16620-16625)
```

- « Engage If Engaged » et « Engage All » ne sont donc pas un interrupteur séparé : ce sont les messages de « Hold Racetrack » et « Flightsweep », qui ne changent que les ROE du vol (`GROUP:OptionROEOpenFire` / `OptionROEOpenFireWeaponFree`) (`zc2:16594-16600`, `zc2:16611-16617`, `loc:1937-1938`).
- Les gestionnaires de zone appellent `setCapRacetrack(zoneCoord, heading, leg, zoneName)` (orbite = cap 045, branche 0) et annoncent `DYNAMIC_CAP_EN_ROUTE_TO_ZONE` ou `DYNAMIC_CAP_REPOSITIONING_ZONE` ; les gestionnaires de position translatent d'abord la coordonnée de la CAP de la distance et du relèvement choisis (`zc2:16504-16535`, `zc2:16557-16578`).
- La même racine porte aussi, en commandes directes, "CAS: Destroy", "Bomber: Destroy", "SEAD: Push" / "SEAD: Destroy", "DECOY: Push" / "DECOY: Destroy", "Building strike: Destroy", "Navy Artillery: Destroy", et le sous-menu « Tankers Control » (section 6) ; arborescence complète dans la note 05 §5 (`zc2:16627-16691`).
- Les marqueurs de carte `caphere1` / `caphere2` déplacent la CAP exactement comme les ravitailleurs (même gestionnaire, `kind = "cap"`, `setCapRacetrack`), sans la restriction de rang ni d'hélicoptère mais en exigeant toujours un groupe piloté par un humain du camp propriétaire (`zc2:28154-28155`, `zc2:28224-28232`, `zc2:28318-28320`, `zc2:105747`).
- Menu de contrôle du bombardier stratégique (`StrategicBomber.AddDynamicControlMenuForGroup`, appelé par le constructeur de Dynamic Control quand un raid acheté par les bleus est actif, `zc2:16656-16657`) : un sous-menu portant le nom du bombardier (`StrategicBomber.GetDisplayName`) avec "Push" (affiché jusqu'à ce que le raid ait été lancé) et "Destroy" (`zc2:4195-4223`, `loc:693-695`).
  - « Push » → `StrategicBomber.PushBlue(groupId)` : refuse avec `STRATEGIC_BOMBER_NOT_ACTIVE` ou `STRATEGIC_BOMBER_ALREADY_PUSHING`, sinon lance la route de bombardement du bombardier en attente et de son escorte (`StartBomberAuftrag(cfg.missionId, cfg.template, st.targetZone, st.escortGroupName, …)`) (`zc2:3936-3975`).
  - « Destroy » → `StrategicBomber.DestroyBlue(groupId)` : supprime le raid (`DestroySide`) avec `STRATEGIC_BOMBER_DESTROYED` (`zc2:4101-4121`).
  - En PvP, chaque gestionnaire revérifie d'abord que le groupe demandeur existe toujours dans le camp propriétaire et que l'état du raid et le jeton du moniteur sont inchangés (`zc2:4203-4213`).
- Les vols achetés eux-mêmes sont enregistrés dans `DynamicSupportNative` (section 16).

## 9. Commandes par marqueurs de carte (liste complète)

Toutes sont traitées par un seul gestionnaire d'événements créé dans `BattleCommander:startMonitorPlayerMarkers` (`zc2:28354-29290`), déclenché sur **changement de marque** (id d'événement 26) pour la coalition 1 ou 2 ; le texte du marqueur est la commande ; le marqueur est supprimé quand la commande a réussi (`zc2:28456`, `zc2:29246-29248`).
Aucune commande ne vérifie l'identité du joueur (nom, UCID, slot) : sur tout le gestionnaire (`zc2:28455-29260`), `event.initiator` ne sert qu'à adresser la réponse au bon groupe, à lire le rang de l'acheteur pour `buy:`, et à choisir le pays du FARP, et aucun appel `net.*` n'apparaît.
Les commandes « admin » ne sont que masquées par des mots suédois ; quand `AdminCommands == true` ces mots cessent de fonctionner et sont remplacés par les `AdminCommandAliases` configurables (douze actions : `addBlueFunds`, `addRedFunds`, `addZoneItems`, `buyWithoutRank`, `createFarp`, `captureNeutralBlue`, `captureNeutralRed`, `clearZone`, `upgradeZone`, `fullyUpgradeZone`, `restartMission`, `endMission`) ; un alias vide, en collision avec une commande intégrée ou défini deux fois est désactivé (`zc2:28355-28437`, `zc2:28460-28475`).
Les commandes de debug en anglais courant (`debug`, `spawn`, `prepp`, `addshop`, `event`, `addrank:` …) restent disponibles pour n'importe qui dans les deux modes (`zc2:28369-28378`, `zc2:29097-29124`).

| Texte du marqueur | Effet | Qui / condition | Code |
|---|---|---|---|
| `arcohere1`, `arcohere2` | règlent le racetrack d'Arco à partir de deux points | humain, voilure fixe, rang ≥ rang du ravitailleur | `zc2:28148-28352` |
| `texacohere1`, `texacohere2` | idem pour Texaco | idem | idem |
| `caphere1`, `caphere2` | idem pour le vol de CAP acheté | groupe humain du camp propriétaire | idem |
| `tarawahere`, `tarawahereandstop` | envoient le Tarawa au marqueur et l'arrêtent | navigation des porte-avions activée ; si `AllowTarawaToMoveFreely`, le point bleu doit être en territoire bleu/neutre | `zc2:28957-28966` |
| `tarawahere1`, `tarawahere2` | racetrack du Tarawa entre deux points d'eau | `AllowTarawaToMoveFreely`, bleu seulement | `zc2:28967-29003` |
| `tarawareturn` | le Tarawa retourne à sa zone de navigation | navigation des porte-avions activée | `zc2:29004-29008` |
| `tarawahelp` | imprime les commandes du Tarawa | — | `zc2:28948-28956` |
| `jtac-code:NNNN` | code laser du ou des drones JTAC | n'importe qui | `zc2:7403-7418` |
| `help` | imprime l'aide des commandes (`ADMIN_COMMAND_HELP`) | n'importe qui | `zc2:28481-28491` |
| `status` | statut de la zone sous le marqueur | n'importe qui | `zc2:28810-28835` |
| `intelstatus` | statut de la zone avec forçage de l'intel | n'importe qui | `zc2:29068-29079` |
| `missions` | imprime la liste des missions | n'importe qui | `zc2:29080-29084` |
| `stats`, `top`, `mystats` | classement / top 5 / ses propres stats | n'importe qui | `zc2:29215-29239` |
| `whynot` | explique pourquoi la zone est suspendue | n'importe qui | `zc2:28918-28926` |
| `buy`, `buy:<item>` | boutique par marqueur (agent 05) | — | `zc2:28555-28620` |
| `farphere…`, `givemefarp…`, `givemefarpzell`, `escortmissionfarp` | création dynamique de FARP (autre thème) | PvP / admin | `zc2:29011-29067` |
| `debughelp`, `ConfigStatus`, `debug`, `spawn`, `spawnnow…`, `prepp`, `addshop`, `removeshop`, `upgradeallred`, `upgradeallblue`, `event`, `event:<name>`, `recapture`, `givemesupplies`, `capture:<…>`, `additems…`, `adminbuy[:item]` (needs `AllowAdminBuy`), `addfunds:<n>`, `addfundsred:<n>`, `addrank:<player>,<n>`, `Message:<text>`, `SpelaMusik`, and the Swedish/aliased `köp[:item]`, `rensa`, `upgradera`, `maxxa`, `blå`, `röd`, `AvslutaFoothold`, `StartaOm` | admin/debug | correspondance de texte sans garde | `zc2:28492-29245` |
| `-code:<lua>` | **exécute du Lua arbitraire** via `loadstring` | sans garde | `zc2:29203-29214` |

Zeus ajoute ses propres commandes de marqueurs (section 14) et EWRS/WelcomeMessage n'en ajoutent aucune.

## 10. Contrôle des porte-avions et des navires

**Aucun `AIRBOSS`, `RECOVERYTANKER` ni `RESCUEHELO` de Moose** n'est instancié nulle part dans les fichiers Foothold ; les opérations de porte-avions utilisent l'ATC natif de DCS, et Foothold ajoute la navigation, les balises et l'information.

### Ce que voit le joueur

- Menu F10 de groupe `Stats and Settings > Carrier Navigation` (clé de label `DYNAMIC_CARRIER_NAVIGATION` ; groupes bleus seulement ; malgré le nom de la clé il est accroché sous le menu de stats `logistics.statsMenus[groupId]`, pas sous Dynamic Control, `zc2:16178-16229`), affiché quand la fonctionnalité est activée et, avec le système de rangs actif, quand le rang du joueur ≥ `CarrierRankRequirement` (5) : "Carrier info" (par porte-avions : ATC MHz, TACAN, callsign, canal ICLS, Link 4 MHz) et une entrée "Sail to <area>" par zone disponible (sous-menus « More » au-delà de 9) (`zc2:16081-16138`, `cfg:290-292`).
- Messages : "<carrier> moving to <area>", "area unavailable", "route failed", et — tant que la zone du porte-avions rouge n'est pas nettoyée — "red carrier required" (`zc2:15986-16014`, `zc2:13549-13554`).
- Avertissements à la coalition avant que le porte-avions ne vire au bout d'une branche de racetrack (5 min et 1 min) (`zc2:15112-15137`).
- Les zones des porte-avions sont dessinées/étiquetées sur la carte F10 ("Carrier: <label>") (`zc2:13905`, `zc2:14234`).
- Tarawa par marqueur de carte : voir la section 9 ; le texte de `tarawahelp` dépend de `AllowTarawaToMoveFreely` (`zc2:28948-28954`).
- L'ATIS d'un porte-avions donne le BRC (magnétique), le vent à 18 m, la ligne radio (section 11).

### Ce que règle le créateur de mission

- Les navires doivent être des groupes/unités nommés `CVN-72`, `CVN-74`, `Tarawa` (navigation) ; les balises sont aussi rafraîchies pour `CVN-73`, `CVN-59`, `CVN-75` s'ils existent (`WM:918-923`).
- Les zones de navigation sont des trigger zones quadrilatères `CVN72_AREA_<NAME>` avec des sous-zones ponctuelles `-1`/`-2` (extrémités du racetrack du CVN-72), `-3`/`-4` (Tarawa), `-5`/`-6` (CVN-74) (`zc2:13868-13925`).
- Appels du setup : `bc:deployCarrierNavigationArea("CVN72_AREA_SOCHI", true)`, `bc:setCarrierNavigationAreaAvailability({AREA = bool | {available=, autoMove=, …}})`, `bc:setCarrierNavigationAutoRoute({...})`, `bc:addCarrierNavigationSuspendConnection(area, zone)` ; dans le setup du Caucase les zones s'ouvrent au fil des captures et les porte-avions avancent automatiquement (`setup:1946-2040`, `zc2:13735`, `zc2:13828`, `zc2:27056`).
- Config : `CarrierNavigationRadios` (CVN-72 : TACAN 72X, ATC 272 ; CVN-74 : 74X, 274 ; Tarawa : 1X, 271,5), `CarrierNavigationICLS`, `CarrierNavigationLink4` (0 = désactivé), `CarrierRankRequirement = 5`, `AllowTarawaToMoveFreely = false` (`cfg:290-299`, `cfg:373-394`).
- Globales `CarrierNavigationSpeedCheckInitialSec` 60, `…IntervalSec` 1 800, `…AfterMoveSec` 120, `CarrierNavigationSpeedDeadbandKt` 1, `CarrierNavigationTargetWodKt` 24 (`zc2:13403-13408`, `zc2:14961`).

### Mécanisme

- Route : point de départ → stations « via » optionnelles → extrémité la plus proche du racetrack de destination → autre extrémité, avec une tâche de type `GoToWaypoint` sur le dernier waypoint qui reboucle sur le premier waypoint de station, de sorte que le navire parcourt le racetrack indéfiniment (`zc2:14669-14714`).
- Recherche de chemin sur l'eau : branche directe si valide, sinon `ASTAR:New()` de Moose sur une grille de nœuds `land.SurfaceType.WATER` (pas ≥ 2 km), `SetValidNeighbourLoS(corridor)`, `GetPath` (`zc2:14491-14518`).
- Vitesse : « contrôle de vitesse » périodique (60 s après le départ, puis toutes les 30 min, 2 min après un déplacement, 4 min après un virage) qui recalcule la vitesse du navire pour que le vent sur le pont ≈ 24 kt : `targetSpeed = clamp(24 − natural headwind)` à partir de `atmosphere.getWind` à 18 m, et réapplique la route si elle diffère d'au moins 1 kt ; il renvoie aussi à sa zone un porte-avions trouvé en dehors (`zc2:14949-14963`, `zc2:15012-15058`).
- Radios : commande `SetFrequency` sur l'unité navire pour la fréquence ATC (`zc2:13600-13606`) ; TACAN (`ActivateBeacon`, type 4, system 3), ICLS (`ActivateICLS`, type 131584), Link 4 (`ActivateLink4`) et ACLS (`ActivateACLS`) sont envoyés par `refreshBeacons()` de `WelcomeMessage.lua`, toutes les heures (`SCHEDULER:New(nil, refreshBeacons, {}, 5, 3600)`) (`WM:788-926`).
- Ravitailleur de récupération : `bc:spawnCarrierRecoveryTanker("Shell", "CVN-72", distNm)` regénère le template `Shell` près du porte-avions avec ses réglages radio — un simple respawn, pas le `RECOVERYTANKER` de Moose (`zc2:15814-15843`).
- Persistance des porte-avions :
  - état par groupe de porte-avions `bc.carrierNavigation[groupName] = {groupName, area, lane, routeSourceArea, speedKt, nextStationIndex, transitioning, x, y, z, headingDeg, currentArea, units = {{name, type, x, y, z, headingDeg}…}, custom…}` ; `_saveCarrierNavigationState` le capture quand une route est appliquée, et `_exportCarrierNavigationPersistence` recapture la position et le cap vivants de chaque unité de chaque groupe de porte-avions à chaque sauvegarde de campagne et renvoie `{version = 1, groups = {…}}` (`zc2:15218-15279`, `zc2:15282-15315`) ;
  - au chargement la table sauvegardée est normalisée (`_normalizeCarrierNavigationPersistence`), puis « réparée » : si plusieurs porte-avions partagent une zone et qu'au moins un a été sauvegardé à l'intérieur, un porte-avions sauvegardé hors de la zone (et pas en transit) est ramené sur un point de station de sa voie (`zc2:15317-15350`, `zc2:15393-15450`) ;
  - restauration (`_restoreCarrierNavigationGroup`) : ignorée tant que la navigation des porte-avions est encore verrouillée ou que la zone n'existe plus ; on vérifie que le point sauvegardé est dégagé sur l'eau et on le déplace vers le point dégagé le plus proche si besoin ; la première station à rallier est choisie d'après le cap sauvegardé et l'index de la station suivante (l'autre station si le navire est à moins de 2 NM de celle-ci) (`zc2:15638-15700`) ;
  - le navire n'est pas déplacé par une téléportation DCS : `_carrierNavigationTeleportGroup` prend le template du groupe dans `env.mission`, réécrit les positions des unités (unité de tête au point et cap sauvegardés, escorteurs pivotés autour d'elle de la différence de cap), et **regénère le groupe sous le même nom** avec `coalition.addGroup`, avec la route déjà attachée, la fréquence ATC sur l'unité de tête, et le groupe réglé invisible et immortel (`zc2:15453-15510`, `zc2:15529-15573`) ;
  - comme un respawn crée un nouvel objet aérodrome, l'entrepôt du porte-avions est relié à nouveau (`STORAGE` patché avec le nouveau `Airbase.getByName(name):getWarehouse()`) et réapprovisionné avec `checkWeaponsList(groupName)` ; les balises doivent être renvoyées pour la même raison (`zc2:15512-15527`, `zc2:15569-15571`, `WM:848-861`) ;
  - la route libre du Tarawa (`customMode`, `customPoints`) n'est restaurée par `_restoreTarawaCustomNavigationGroup` que si `AllowTarawaToMoveFreely` est toujours vrai ; sinon les champs personnalisés sont abandonnés et le Tarawa retourne sur la voie de sa zone (`zc2:15641-15651`, `zc2:15576-15637`).
- Route personnalisée du Tarawa : `_carrierNavigationApplyTarawaCustomRoute("tarawa-stop" | "tarawa-racetrack", points, …)` (`zc2:14825-14878`).

### Notes de reproduction

- La seule dépendance fortement Moose est `ASTAR` pour le routage maritime.
- Tout le sous-système fait ≈2 800 lignes (`zc2:13403-16200`), surtout des règles de disponibilité, de la persistance et des menus ; le cœur de la navigation est la route de waypoints bouclée plus le recalcul de vitesse du vent sur le pont.
- Les balises doivent être renvoyées après tout respawn/téléportation du navire (l'id d'unité change ; Link 4/ACLS sont envoyés une fois par id d'unité, `WM:848-861`).

## 11. `WelcomeMessage.lua` : texte d'accueil, attribution des callsigns/IFF, ATIS, informations d'aérodrome

`WelcomeMessage.lua` (2 941 lignes) est bien plus qu'un texte d'accueil : il contient le menu ATIS, l'allocateur de callsigns/IFF, les balises des porte-avions (section 10), toute la fonctionnalité d'escorte (section 12), la récompense de ravitaillement, le respawn des statics d'aérodrome à la capture et le nettoyage au départ d'un joueur.
Sa table `static` n'est **pas** relative aux objets statiques en général : c'est `STATIC:FindByName("EventMan", true)`, un wrapper Moose autour d'un objet statique nommé `EventMan` dans le `.miz`, utilisé uniquement comme objet gestionnaire d'événements (`static:HandleEvent(EVENTS.BaseCaptured | PlayerLeaveUnit | Refueling | RefuelingStop, …)`) et comme espace de noms de `static:processPlayerSpawn` (`WM:45`, `WM:2932-2935`).
`WelcomeMessagev2.lua` (2 641 lignes) existe aussi dans le dossier, mais le `.miz` du Caucase livre `WelcomeMessage.lua`.

### Ce que voit le joueur

- Au spawn dans une zone : un accueil "Welcome to <zone>, <rank> <name>, you are <callsign>, IFF <code>" (ou "standby" quand aucun callsign n'est libre), et 60 s plus tard un message détaillé avec vent, température, altimètre et piste active (zones d'aérodrome) ou ligne radio du porte-avions + BRC + vent sur le pont (zones de porte-avions) ; la formulation diffère pour une première visite et un retour ("welcome back") (`WM:1530-1628`).
- Menu « Change callsign » : **défini mais non proposé en v6.5.3**. Le constructeur `buildCallSignMenu()` existe (un `MENU_GROUP` Moose « Change callsign » avec un sous-menu par famille de callsigns configurée pour le type d'appareil, listant les emplacements `<family><n>` libres de la zone ; en choisir un libère l'emplacement précédent du joueur, prend le nouveau, renvoie l'accueil et le message détaillé de 60 s avec le nouveau callsign et IFF, et reconstruit les sous-menus ; le menu entier se retire après 60 s), mais son seul appel est commenté (`--buildCallSignMenu()`), donc les joueurs gardent le callsign attribué automatiquement (`WM:1630-1680`, `WM:1682-1684`).
- Menu de groupe F10 « ATIS / Closest airfield » (avions seulement) : "Closest friendly airfield" et un sous-menu "ATIS information" avec "Mother" (bleu, quand un porte-avions existe) et une entrée par zone d'aérodrome ami, triée par numéro de waypoint décroissant, "More" toutes les 9 (`WM:1306-1341`).
- « Closest friendly airfield » : pour les Hornets/Tomcats chaque porte-avions actif (distance NM, relèvement magnétique, ligne radio ou TACAN, BRC), puis la zone d'aérodrome ami la plus proche avec distance, relèvement magnétique, vent, altimètre, piste active avec cap magnétique (`WM:1191-1271`).
- ATIS d'une zone : "ATIS for <zone>: wind DDD at N kt, altimeter …, active runway NN (course DDD°M)", 20 s (`WM:1110-1130`, `WM:1156-1163`).
- ATIS de capture : 10 s après la capture d'un aérodrome, chaque client avion du nouveau propriétaire reçoit l'ATIS de cet aérodrome, et tous les menus ATIS sont reconstruits (un groupe toutes les 0,1 s) (`WM:1381-1431`, `WM:1345-1379`).

### Ce que règle le créateur de mission

- Un objet statique nommé `EventMan` doit exister dans le `.miz` (`WM:45`).
- `atisZones` / `allZones` sont construites au chargement à partir de la table `zones` de Foothold (les zones avec un aérodrome ont un ATIS) (`WM:84-161`, `WM:186-187`) ; le fichier doit donc s'exécuter après le fichier de setup.
- Config : le bloc de texte d'accueil et la table de callsigns « Welcome Message Callsigns » (`cfg:1156-1169`) ; `aircraftAssignments` associe un **motif de nom de groupe** (par ex. `"F.A.18"`) à des familles de callsigns avec chacune 4 codes IFF (par ex. `Arctic1` → 1400–1403) (`WM:566-720`).
- Réglages utilisateur de Moose forcés en fin de fichier : `_SETTINGS:SetPlayerMenuOff()`, `SetA2G_BR()`, `SetA2A_BULLS()`, `SetImperial()` (`WM:2936-2939`).

### Mécanisme

- Point d'entrée : `LogisticCommander` appelle `static:processPlayerSpawn(mooseUnit, zoneName)` au spawn du joueur (`zc2:101261`) ; l'accueil est envoyé aussitôt et le message détaillé par `SCHEDULER:New(nil, sendDetailedMessageToPlayer, {...}, 60)` conservé dans `followID[playerName]` (`WM:1624-1628`).
- Callsigns : `findOrAssignSlot(playerName, groupName, zoneName)` tient `zoneAssignments[zone]` et `globalCallsignAssignments[player]`, réutilise le callsign du joueur s'il respawne dans la même zone, le libère sinon, et donne le premier numéro libre de la famille préférée ; l'IFF est `details.IFFs[number]` (`WM:341-475`).
- Les données ATIS sont calculées par Foothold à partir des helpers d'aérodrome de Moose, **pas par la classe `ATIS` de Moose** (aucun `ATIS:New` nulle part) : vent = `COORDINATE:GetWind(10)` (→ `atmosphere.getWind`), piste = `AIRBASE:GetActiveRunway()` + `GetRunwayName()` (Moose choisit la piste d'après le vent), pression = `readAltimeterPressure()`, température = `COORDINATE:GetTemperature` (`WM:1004-1058`, `WM:1096-1106`).
- BRC du porte-avions = cap du navire − déclinaison magnétique (`WM:863-874`) ; vent du porte-avions = `COORDINATE:GetWind(18)` (`WM:972-995`).
- Les menus sont des `MENU_GROUP` / `MENU_GROUP_COMMAND` de Moose (→ `missionCommands.addSubMenuForGroup` / `addCommandForGroup`) (`WM:1318-1338`).
- Capture : `EVENTS.BaseCaptured` de Moose (→ `S_EVENT_BASE_CAPTURED`), clients énumérés avec `SET_CLIENT:New():FilterCategories("plane"):FilterCoalitions():FilterAlive():FilterOnce()` (`WM:1383-1415`).
- Le texte est du texte brut à l'écran ; rien n'est dit à voix haute (aucun usage de SRS/MSRS trouvé).
- Récompense de ravitaillement : `EVENTS.Refueling` stocke la fraction de carburant au contact (pour les événements de ravitailleur IA, chaque joueur à moins de 300 m du ravitailleur est enregistré), `EVENTS.RefuelingStop` convertit la fraction gagnée × `fuelMassMax` en livres et verse `floor(lbs/100) × RefuelReward` si ≥ `RefuelRewardMinimumLbs` (`WM:2731-2828`).
- Statics d'aérodrome : `GatherStaticDetails()` enregistre les statics listés par aérodrome dans `airbaseStatics`, et `RespawnStaticsForAirbase(airbase, side)` les regénère avec la nouvelle coalition quand la zone change de camp (appelée depuis `zc2:51447-51473`, `zc2:55361`, `zc2:56759`) (`WM:234-306`).
- Départ d'un joueur : `static:OnEventPlayerLeaveUnit` réinitialise les contributions, les stats temporaires, l'emplacement de callsign, les menus, l'escorte (`WM:2867-2930`).

### Notes de reproduction

- Le choix de la piste active et le nommage des pistes viennent de `AIRBASE` de Moose (géométrie des pistes issue de `Airbase:getRunways()` et du vent).
- L'allocation des callsigns repose sur des motifs de noms de groupes, donc le nommage des slots dans le `.miz` compte.
- Les messages sont localisés par joueur (`L10N:ForGroup`), c'est pourquoi les rapports sont mis en cache par locale quand ils sont diffusés (`WM:1157-1161`).

## 12. Vol d'escorte pour les joueurs

### Ce que voit le joueur

- Les types éligibles reçoivent, 10 s après le spawn, "Escort available" + `ding.ogg` et un menu de groupe « Request escort » avec : Same altitude, 2 000 ft above, 5 000 ft above, 10 000 ft above (`WM:1491-1514`, `WM:1724-1739`).
- Une escorte de chasseurs de 2 appareils décolle alors soit de l'aérodrome ami le plus proche ("scrambling, taxi", quand `EscortTakeoffFromGround`), soit est générée en l'air à 1 500 m derrière le joueur, 10 000 ft au-dessus de lui (ou tient à 27 000 ft au-dessus de la base d'attache si le joueur est au sol) (`WM:2133-2172`, `WM:2284-2294`, `WM:2298-2316`).
- Menu « Escort » : Patrol ahead (15 NM dans l'axe), Racetrack on the nose, Racetrack left-to-right, Racetrack right-to-left, Start orbit (25 000 ft au-dessus de la position du joueur), Rejoin, RTB (`WM:2321-2339`).
- « Rejoin » au sol fait tenir l'escorte à 10 000 ft et la fait rejoindre après le décollage ("can't join, you are on the ground") (`WM:2573-2602`).
- Si l'escorte est abattue, le menu est retiré et le joueur est prévenu (`WM:2428-2450`, `WM:2621-2633`).

### Ce que règle le créateur de mission

- Config `EscortTypeByPlayerType[type] = { enabled, blueTemplate | index, altitude, [redTemplate] }` (activée par défaut pour C-130J-30, AV8BNA, A-10C/A-10C_2/A-10A, Hercules, F-15ESE, AJS37), `EscortTakeoffFromGround = true`, `PvPEscorts = false` (`cfg:325-327`, `cfg:1238-1270`, `WM:193-211`).
- Le template d'escorte est l'un des templates de CAP activés (`BlueCapPlaneEnabled` / `RedCapPlaneEnabled`) (`WM:1434-1450`).

### Mécanisme

- Spawn : `SPAWN:NewWithAlias(template, alias):InitGrouping(2):InitHeading():OnSpawnGroup(cb):SpawnFromCoordinate(coord)` (→ `coalition.addGroup`), alias `<group>_<player>_Escort_NNN` (`WM:2158-2171`, `WM:2244`).
- Les tâches sont des tâches DCS brutes posées via `SetEscortNativeTask` : `{id="Escort", params={groupId, pos={x,y,z}, engagementDistMax=40 NM, targetTypes={"Air"}}}` pour suivre/patrouiller devant (pos x=15 NM devant, ou x=−100, z=300 pour rejoindre), `{id="Orbit", …RACE_TRACK}` pour les racetracks, `{id="EngageTargets", targetTypes={"Air"}}` (`WM:1770-1812`, `WM:2498-2502`, `WM:2584`).
- Options : `CommandSetUnlimitedFuel(true)`, recherche radar continue, pas de rapport de passage de waypoint (`WM:2272`).
- Suivi des pertes : `escortOwnerByUnitName[unit]` est consulté par le gestionnaire de pertes d'unités de BattleCommander (`HandleEscortUnitLost`, `zc2:43069`) ; le décollage du joueur déclenche `HandleEscortTakeoff` (`WM:2635`).
- État : `spawnedGroups[groupName]`, `escortGroups[groupName]`, `escortPendingJoin`.

### Notes de reproduction

- Entièrement faisable avec la tâche native `Escort` ; les parties délicates sont les cas au sol (joueur pas en vol, escorte qui décolle) et les compteurs de génération qui annulent les tâches différées périmées (`escortOrbitGeneration`, `WM:2459-2473`).

## 13. `EWRS.lua` : situation radar d'alerte avancée

Une copie modifiée du script public « EWRS by Steggles » (`EWRS.lua:1743-1745`), 1 745 lignes, en grande partie indépendante du moteur (seulement `L10N`, `SET_CLIENT`/`UTILS`/`BASE` de Moose et les hooks de persistance).

### Ce que voit le joueur

- Toutes les 20 s (par défaut) chaque joueur avec les rapports automatiques activés reçoit une « situation » en texte des appareils ennemis détectés au radar les plus proches dans sa limite de portée : type (nom de code OTAN), relèvement (arrondi à 5°), distance (arrondie : 1 sous 20, 5 sous 60, 10 au-dessus), altitude (milliers de ft ou dizaines de m), vitesse, cap, aspect Hot/Flanking/Beaming/Cold (`EWRS.lua:692-705`, `EWRS.lua:738-790`, `EWRS.lua:1719-1741`).
- La référence est l'appareil du joueur (BRA) ou le bullseye de la coalition (`coalition.getMainRefPoint`) (`EWRS.lua:718-727`).
- Le style 2 affiche "Merged" sous 5 NM (`cfg:2353`).
- Lignes amies optionnelles (autres appareils amis, ravitailleurs Arco/Texaco) (`EWRS.lua:792-830`, `EWRS.lua:1114-1203`).
- Menu F10 de groupe (clé de label `EWRS_MENU_ROOT`) : Request bogey dope ; (mode à la demande) Request picture ; Set detection range (listes en km ou nm) ; Set threat limit (1–5, All) ; Friendlies (show on/off, limit 1–5, show tankers on/off) ; Auto picture on/off ; Group settings → référence (bullseye/self), mesures (impérial/métrique), style de rapport (1/2) (`EWRS.lua:1591-1695`).
- Les réglages sont sauvegardés par nom de joueur et par catégorie d'appareil, et restaurés au prochain spawn et après un redémarrage (`EWRS.lua:331-656`).

### Ce que règle le créateur de mission

- Bloc de config `ewrs_*` (`cfg:2318-2355`) : `ewrs_enabled = true`, `ewrs_defaultReportStyle = 2`, `ewrs_maxRangeKm = 150`, `ewrs_maxRangeNm = 100`, `ewrs_defaultAircraftRangeLimit = 60`, `ewrs_defaultHelicopterRangeLimit = 20`, `ewrs_messageUpdateInterval = 20`, `ewrs_messageDisplayTime = 15`, `ewrs_restrictToOneReference = false`, `ewrs_defaultReference = "self"`, `ewrs_defaultMeasurements = "imperial"`, `ewrs_defaultShowTankers = false`, `ewrs_enableRedTeam = true`, `ewrs_enableBlueTeam = true`, `ewrs_disableMessageWhenNoThreats = true`, `ewrs_onDemand = false`, `ewrs_maxThreatDisplay = 5`, `ewrs_allowBogeyDope = true`, `ewrs_allowFriendlyPicture = true`, `ewrs_maxFriendlyDisplay = 3`, `ewrs_showType = true`, `ewrs_mergedRangeNm = 5`, `ewrs_specialPlaneTypes` (types qui voient les amis par défaut).
- La config doit être chargée avant `EWRS.lua` (`cfg:2318`).

### Mécanisme

- Détection : un « registre de radars » de chaque unité ayant l'attribut `SAM SR`, `EWR` ou `AWACS`, par camp, construit une fois à partir de `coalition.getGroups` et maintenu par les événements Moose `Birth`, `Dead`, `Crash`, `RemoveUnit`, `UnitLost` (`BASE:HandleEvent` → `world.addEventHandler`) (`EWRS.lua:1349-1394`).
- À chaque cycle, pour chaque radar du camp du joueur : `unit:getController():getDetectedTargets(Controller.Detection.RADAR)` ; on garde les objets qui existent, sont en vol et ont l'attribut `Planes` ou `Helicopters` ; dédupliqués par id d'objet (`EWRS.lua:1396-1431`).
- La situation est donc ce que **les radars amis détectent réellement** (masquage par le terrain et portée radar s'appliquent), calculée une fois par camp et par cycle et partagée par tous les joueurs de ce camp (`EWRS.lua:1722-1736`).
- Liste des joueurs : `ewrs.update()` → `buildActivePlayers()` utilise `SET_CLIENT:New():FilterActive(true):FilterOnce()` ; elle est appelée par le moteur au spawn/départ d'un joueur (`ewrs.registerPlayer`, `ewrs.pruneGroup`), pas sur un timer (`EWRS.lua:687-690`, `EWRS.lua:1205-1232`, `EWRS.lua:1308-1333`).
- Le registre est démonté quand aucun joueur n'est actif (`EWRS.lua:1226`, `EWRS.lua:1340-1347`).
- Un seul timer global (`timer.scheduleFunction`, premier passage à +6 s, période `messageUpdateInterval`) boucle sur les joueurs actifs ; un cache `contactFacts` par cycle partage position/cap/type par contact entre les joueurs (`EWRS.lua:1719-1741`).
- Noms de code : `UNIT:Find(obj)` de Moose puis une recherche dans une table avec des surcharges pour les types de la Seconde Guerre mondiale (`EWRS.lua:140-162`, `EWRS.lua:245-275`).
- Sortie : `trigger.action.outTextForGroup` (dans `ewrs.outText`, `EWRS.lua:966-1083`).

### Notes de reproduction

- Pas de dépendance lourde à Moose ; le cœur est `Controller:getDetectedTargets(RADAR)` sur chaque radar de veille ami.
- Coût : O(radars amis) requêtes de détection par cycle et par camp, plus O(joueurs × contacts) pour le formatage ; le registre évite de rescanner toutes les unités.
- La persistance des réglages par joueur (profils encodés compacts) représente à elle seule ≈300 lignes.

## 14. Zeus : commandes de marqueurs du maître de jeu (`Zeus.lua`, `zeus_Full_v2.1.lua`)

La mission du Caucase charge le court `Zeus.lua` (105 lignes), pas `zeus_Full_v2.1.lua` (le `.miz` ne contient que `l10n/DEFAULT/Zeus.lua`).

### Commandes de `Zeus.lua` (texte du marqueur, en minuscules, doit commencer par `-`)

| Texte du marqueur | Effet | Code |
|---|---|---|
| `-create <name>` | génère le template `<name>` au marqueur ; noms autorisés : SA-8, SA-9, SA-13, SA-15, SA-19, Soldier, Truck, Shilka, Igla, Igla-S, RPG, BMP2, Tank, BTR80, CTLD_CARGO_HMMWV, mig21, JTAC9lineam, JTAC9linefm, Tankm1, CTLD_CARGO_L118, CTLD_CARGO_Scout, CTLD_CARGO_AmmoTruck, CTLD_CARGO_GMLRS_HE | `Zeus.lua:15-29` |
| `-destroy1` | détruit toute unité à moins de 500 m | `Zeus.lua:37-42` |
| `-destroy2`, `-destroy3` | détruit toute unité à moins de 1 000 m | `Zeus.lua:44-49` |
| `-destroy4` | détruit toute unité à moins de 10 000 m | `Zeus.lua:51-56` |
| `-explode <power> [delay]` | explosion au marqueur (puissance 100 par défaut) | `Zeus.lua:58-64` |
| `-smoke <red/blue/green/orange/white>` | fumée au marqueur (rouge par défaut) | `Zeus.lua:66-74` |
| `-illuminate` | bombe éclairante 1 000 m au-dessus du marqueur, puissance 700 000 | `Zeus.lua:89-91` |
| `-static`, `-debug` | souches vides | `Zeus.lua:32-33` |

- Déclenchement : `world.addEventHandler` sur `S_EVENT_MARK_ADDED` et `S_EVENT_MARK_CHANGE` ; le marqueur est supprimé après une commande reconnue (`Zeus.lua:76-102`).
- **Qui peut les utiliser : toute personne qui peut poser un marqueur.** Il n'y a aucune vérification de coalition, de nom de joueur, d'UCID ou de slot dans le fichier (`Zeus.lua:76-102`).
- Usage de Moose : `SPAWN:NewWithAlias(name, name..rnd):SpawnFromVec2`, `ZONE_RADIUS:New():SearchZone(fn, Object.Category.UNIT)` (→ sphère `world.searchObjects`), `COORDINATE:Explosion` (→ `trigger.action.explosion`), `COORDINATE:Smoke*` (→ `trigger.action.smoke`), `COORDINATE:IlluminationBomb` (→ `trigger.action.illuminationBomb`).

### `zeus_Full_v2.1.lua` (1 750 lignes, non chargé par la mission CA)

- Mêmes commandes `-destroyN`, `-explode`, `-smoke`, `-illuminate` (`zeus_Full_v2.1.lua:1465-1485`).
- Syntaxe à point-virgule sur **changement de marque** uniquement : `<model>;<unit name>[;red/blue]` génère un appareil à partir de templates intégrés (`airUnitDB` : mig29, mig23, mig21, j11, m2k, f14, f15, f16, f18, f1, f5, mig28, f4, p51, spit, mossie, bf109, fw190a8, fw190d9, ju88, plus `jtac`, `texaco`, `arco`) au marqueur via `coalition.addGroup` ; les types de soutien apparaissent du côté du joueur, les autres en adversaires sauf surcharge (`zeus_Full_v2.1.lua:1497-1533`, `zeus_Full_v2.1.lua:1668-1742`).
- `destroy;<spawn name>` renvoie un ensemble généré ; `illumin;` lâche 5 bombes éclairantes (puissance 1 000 000, 600–1 200 m, étalées de 5 à 13 s après un délai de 15 s) ; `smoke;<colors>` ; `strike;` = 16 explosions sur 5–20 s (`zeus_Full_v2.1.lua:1534-1549`, `zeus_Full_v2.1.lua:1572-1602`).
- Effets optionnels de napalm / phosphore, tous deux désactivés par défaut (`zeus_Full_v2.1.lua:11-14`).
- Il ignore les textes de marqueurs qui correspondent aux commandes du moteur (liste d'exclusion : help, buy, status, stats, capture, `-code:`, …) (`zeus_Full_v2.1.lua:17-55`).
- Seule garde : au moins un joueur doit être dans la mission (`zeus_Full_v2.1.lua:1509`, `zeus_Full_v2.1.lua:1532`) ; aucune vérification d'admin.

## 15. Fumée, fusée éclairante et illumination sur les cibles d'une zone

- Articles de boutique `smoke`, `flare`, `illum` → choix d'une zone ennemie non suspendue → `bc:smokeTargets(zone)`, `bc:flareTargets(zone)`, `bc:illumTargets(zone)` et un message à la coalition (`setup:4547-4634`).
- Fumée : jusqu'à 3 unités/statics vivants de la zone tirés au hasard reçoivent une fumée **rouge** (`trigger.action.smoke(point, 1)`) ; les groupes fumés reçoivent l'ordre de réagir via `AIEN.ReactToSmoke(zone, groupName, 20)` (le script d'IA au sol) (`zc2:23618-23660`).
- Fusée éclairante : jusqu'à 3 cibles au hasard, chacune avec 3 fusées de signalisation rouges espacées de 5 s (`trigger.action.signalFlare`, `timer.scheduleFunction`) (`zc2:23662-23694`).
- Illumination : jusqu'à 3 positions (chefs de groupe quand la zone a ≥ 3 groupes, sinon unités au hasard), altitude 1 000 m, puissance 700 000 via `trigger.action.illuminationBomb(point, power)` (`zc2:23696-23774`).
- Autres marquages à la demande déjà listés : fumée/fusée du drone JTAC (section 1), fumée bleue du désignateur du joueur (section 3), fumée/fusée CSAR sur le pilote et « smoke/flare nearest zone » (section 4), `-smoke` / `-illuminate` de Zeus (section 14).
- Toutes des actions de trigger DCS brutes ; pas de Moose.

## 16. `DynamicSupportNative` : suivi du cycle de vie des vols de soutien IA achetés

- Rôle : un registre des vols achetés par les joueurs (CAP, CAS, SEAD, bombardier, leurre…) qui rapporte leur cycle de vie à la coalition et pilote le rafraîchissement des menus de contrôle ; ce n'est **pas** en soi une demande de soutien à la demande (`zc2:106261-106469`).
- `Register(record, group)` stocke `record` sous `record.groupName` avec des callbacks/messages : `airborneMessage`, `onMissionStarted`, `winchesterMessage` / `onWinchester`, `completedMessage`, `landedMessage`, `killedMessage`, `clearActive()`, `isActive()` (`zc2:106367-106378`).
- Surveillance des munitions : un seul `timer.scheduleFunction` partagé toutes les 30 s tant qu'un vol est enregistré ; `_hasMissionAmmo` scrute `Unit:getAmmo()` à la recherche de bombes, roquettes et missiles non AAM (ou seulement des AAM quand `aamOnly`) ; la première fois qu'un vol qui avait des munitions de mission n'en a plus → message « winchester » et callback (`zc2:106266-106291`, `zc2:106303-106365`).
- Le même tick réveille les zones suspendues « idle » le long de l'empreinte du vol (`_idleWakeFootprint`) et termine les vols dont le groupe a disparu (`zc2:106314-106350`).
- Hooks d'événements appelés depuis le gestionnaire de BattleCommander : `HandleTakeoff` (message en vol, rafraîchissement du menu), `HandleUnitLost` (dernière unité perdue → message « killed », rachat automatique optionnel de la CAP via `_replaceLostPurchasedCap` quand `AllowCapAutoBuyAfterLoss`), `HandleLanding` (`zc2:106402-106469`, `zc2:43070-43073`).
- `ReportMissionStarted` / `ReportMissionComplete` sont appelées par les propres scripts de tâche des vols (`zc2:106380-106400`).
- Pas de Moose dans le suivi lui-même ; les vols qu'il suit reçoivent des tables de tâches DCS brutes (`Controller:setTask({id = "Mission", …})`, `Bombing`, `ComboTask`), pas les `FLIGHTGROUP` / `AUFTRAG` de Moose OPS (seul l'article d'artillerie navale les utilise), ce qui est probablement le sens de « Native » (`zc2:109065`, `zc2:1503-1561`, `zc2:109950-110096` ; le nom lui-même n'est pas expliqué dans le code — (estimation)).

## 17. « Hunt » : chasseurs ennemis lancés contre un joueur performant

- C'est une menace, pas un outil de soutien, mais c'est la seule chose nommée `Hunt` dans le moteur.
- Config `EnableHunter = true` (désactivé en PvP) (`cfg:856-858`, `zc2:40974-40986`).
- Setup : `bc:initHunter(HuntNumber, AirHuntNumber)` avec un seuil de kills au sol de 6–15 (8–15 avec splash damage) et un seuil de kills en l'air de 4–8, tirés au démarrage de la mission (`setup:6040-6043`).
- `registerHuntKill(pname, unit, killType)` compte les kills par joueur bleu (hélicoptères, A-10C_2, A-10A et AV8BNA exemptés) ; une fois le seuil atteint chaque kill supplémentaire a 10 % de chances (une fois par vie) d'appeler `_spawnHunterForPlayer`, qui choisit un aérodrome rouge avec 2 places de parking libres et lance 2 appareils contre le joueur (`zc2:41136-41168`, `zc2:41059-41075`).
- Les compteurs sont remis à zéro quand le joueur part ou respawne (`WM:2888`, `zc2:41695`).

## 18. `Splash_Damage_3.4.1_leka.lua` : personnalisations Foothold (bref)

- Script tiers « Splash Damage 3.4.1 » (4 932 lignes) ; la variante Foothold diffère de `Splash_Damage_3.4.1_Default.lua` (4 824 lignes) par environ 80 blocs de diff.
- Les citations ci-dessous sont des numéros de ligne de `Splash_Damage_3.4.1_leka.lua` (nom court `SD`) ; « Default » est la valeur à l'endroit correspondant de `Splash_Damage_3.4.1_Default.lua`.

| Personnalisation Foothold | Lignes (`SD`) | Fichier par défaut |
|---|---|---|
| Tout le script est enveloppé dans `if SplashDamage == true or splashDamageIsNormandy then … end` (Config `SplashDamage` par défaut `false`, `cfg:273` ; toujours actif pour le théâtre Normandie) | `SD:1-4`, `SD:4802` | s'exécute sans condition |
| Note d'en-tête "this is a 3.4.1 version for leka's foothold" et "Added in Lekas Foothold Integration to allow splash kills to count towards the points, killfeed is required" | `SD:18`, `SD:24` | absente |
| `dynamic_blast_radius_modifier = 1.5` | `SD:76` | 2 |
| `cascade_scaling = 1.5` | `SD:90` | 2 |
| `ordnance_protection = false` | `SD:153` | true |
| `killfeed_enable = true` ("required for lekas foothold") | `SD:218` | true (sans remarque Foothold) |
| `killfeed_lekas_foothold_integration = true`, `killfeed_lekas_contribution_delay = 0` | `SD:220-221` | options absentes |
| Surcharge Normandie : `larger_explosions = true`, `dynamic_blast_radius_modifier = 2`, `cascade_scaling = 2`, `ordnance_protection = true` | `SD:286-292` | absente |
| Table d'armes : `F16V_GBU53`, `F16V_GBU39` (explosif 25) ajoutées | `SD:714-715` | absente |
| Une arme absente de la table est journalisée une seule fois par nom de type (`reportedMissingWeapons`) au lieu de chaque tir | `SD:1053`, `SD:3429-3433` | journalisée à chaque fois |
| Les tirs dont l'arme est `ZELL Booster` ou `SPRD-99` sont ignorés | `SD:3308-3310` | absente |
| `getFootholdRewardDataForObject(object, name)` : objets rouges seulement, `bc:objectToRewardPoints2` → nom de stat et points | `SD:1304-1323` | absente |
| Une entrée de kill par splash n'est mise en file que si elle a un nom de stat et des points, une fois par id d'unité | `SD:1325-1342` | mise en file sans données de récompense |
| `isFootholdRewardPlayer(name)` : `bc.playerContributions[2][name] ~= nil` | `SD:1344-1346` | absente |
| Données de récompense attachées là où le script trouve ses victimes : scan de napalm (`scanUnitsForNapalm`), suivi principal des armes (`track_wpns`), impacts de bomblets de bombes à sous-munitions (`CBUBombletHitExplosion`) | `SD:1547`, `SD:1576`, `SD:2866`, `SD:3827` | absentes |
| `processSplashKillfeed` : toutes les 5 s tant que des entrées sont en file (60 s sinon) applique `bc:addTempStat`, `bc:addContribution(player, 2, points)`, `bc:registerCasMissionKill`, `bc:registerSeadMissionKill`, `bc:registerMissionTargetKill` (quand l'unité est dans `MissionTargets`) pour les joueurs inscrits, puis retire l'entrée | `SD:3492-3532` | le même timer ne fait qu'expirer les anciennes entrées |
| Le timer de traitement est démarré au chargement, 60 s après le début | `SD:4780-4783` | absent |
| Un vrai `S_EVENT_KILL` pour une unité déjà en file comme kill par splash retire l'entrée en file (pas de double paiement) | `SD:4549-4559` | même déduplication, utilisée pour le fil de texte seulement |
| `processedSmoke[unitID]` contient une heure d'expiration au lieu de `true`, prolongée de la durée de l'effet, et une passe d'élagage supprime les entrées expirées, de sorte que l'effet de fumée/cook-off d'une unité n'est pas rejoué et que la table ne grossit pas | `SD:1407-1410`, `SD:2065`, `SD:2119-2120`, `SD:2383-2384`, `SD:2418-2419` | `processedSmoke[unitID] = true`, jamais élagué |

- Ce qui est inchangé : les effets de fumée et de cook-off standard « toutes unités », le modèle d'onde de souffle et de cascade, les options de menu radio du script d'origine (non listées ici).
- Les récompenses de splash sont réservées aux bleus (le camp 2 est codé en dur à `SD:1345` et `SD:3513`) et ne passent pas par le gestionnaire de kills du moteur, donc elles alimentent la bourse, les stats de sortie et les missions CAS/SEAD/cible mais pas les compteurs de kills de carrière (`SD:3511-3519`).

## 19. Textes d'aide, informations radio, météo

- Le marqueur `help` imprime `ADMIN_COMMAND_HELP` ; `debughelp` imprime `ADMIN_DEBUG_HELP` ; `tarawahelp` imprime les commandes du Tarawa (`zc2:28481-28501`, `zc2:28948-28956`, `loc:1896`).
- Entrées d'aide des menus : "Tanker Help" (infos radio des deux ravitailleurs + syntaxe des marqueurs), "CAP Help" (syntaxe des marqueurs), "Carrier info" (ATC/TACAN/ICLS/Link 4), "Rank Help", "Supplies help", "Help" des missions conjointes (`loc:1913-1914`, `loc:1875-1876`, `loc:1024`, `loc:1634`, `loc:1606`).
- L'information sur les fréquences radio est centralisée dans `BattleCommander:_initializeSupportRadioSettings` (AWACS, ravitailleurs, Shell) et `enableCarrierNavigation` (porte-avions), validée au chargement par `assert` (30–400 MHz, TACAN 1–126) (`zc2:13630-13676`, `zc2:13560-13597`).
- Le `.miz` livre une seule image de kneeboard, `KNEEBOARD/IMAGES/Freq.png` (fiche de fréquences) ; aucun script ne génère de pages de kneeboard.
- Météo : seulement lue, jamais modifiée : `atmosphere.getWind` (position du joueur, pont du porte-avions à 18 m), `COORDINATE:GetWind(10)` de Moose, `GetTemperature`, altimètre (`WM:1081-1106`, `WM:753-777`, `zc2:14959`) ; aucun helper d'heure du jour n'a été trouvé dans ce thème.

## Vu hors de ce thème

- Les missions de reconnaissance (`BattleCommander:initReconMissions`, slots, suivis `ReconMissionTrackers`) sont un type de mission du MissionCommander ; l'intel de zone et le déploiement d'un JTAC les annulent (`zc2:62654-62690`, `zc2:6999-7003`, `zc2:7986-7987`).
- Création dynamique de FARP par marqueur (`farphere`, `givemefarp`, `escortmissionfarp`) (`zc2:29011-29067`).
- Boutique par marqueur (`buy`, `buy:<item>`, `adminbuy`, `köp`) et commandes d'économie admin (`addfunds:`, `addrank:`) (`zc2:28555-28706`, `zc2:29085-29135`).
- Affichage du statut de zone `ZoneCommander:displayStatus` et menu « Intel / zone status » (`zc2:50274`, `zc2:40330`).
- Les vols IA achetés eux-mêmes : `spawnCapAt`, actions de boutique CAS/SEAD/bombardier/leurre, menu de contrôle `StrategicBomber` (`zc2:107204`, `setup:3053-3780`, `zc2:4195`).
- Réactions de l'IA au sol de `AIEN.lua` (`AIEN.ReactToSmoke`) (`zc2:23658`).
- Carrière/statistiques (`recordCareerStat`, `printStats`, `mystats`) (`zc2:29215-29239`, `WM:2802`).
- Menus conditionnés par le rang du joueur (`_getGroupRank`, `CarrierRankRequirement`, rang des ravitailleurs) (`zc2:28227`, `zc2:16084`).
- Calque de territoire utilisé pour valider les déplacements du Tarawa (`_territoryOverlaySideAtPoint`) (`zc2:28930`).
- Le marqueur `-code:<lua>` exécute du Lua arbitraire pour toute personne capable d'éditer un marqueur (`zc2:29203-29214`).
- Persistance de l'état du soutien : stations des ravitailleurs, navigation des porte-avions, pilotes CSAR, réglages de SelfJtac et d'EWRS par joueur (`zc2:106153`, `zc2:15298`, `zc2:44890`, `zc2:43833`, `EWRS.lua:529-656`).
