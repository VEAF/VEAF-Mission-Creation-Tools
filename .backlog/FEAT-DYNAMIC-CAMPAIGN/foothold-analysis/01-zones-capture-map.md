# 01 — Zones, propriété, capture et carte (Foothold v6.5.3)

Sources, avec les noms courts utilisés dans les citations : `zc2` = `Common Scripts/zoneCommanderv2.lua`, `setup` = `Setup files/MA_Setup_CAv2.lua`, `config` = `Common Scripts/Foothold Config.lua`, `ctld` = `Common Scripts/Foothold CTLD.lua`, `ctldred` = `Common Scripts/Foothold_CTLD_Red.lua`, `l10n` = `Common Scripts/Foothold_Localization.lua`.
Les numéros de coalition sont ceux de DCS : 0 neutre, 1 rouge, 2 bleu.
« PvE » est le mode par défaut (joueurs bleus contre une IA rouge) ; `GlobalSettings.pvpEnabled` fait basculer de nombreuses branches vers un mode symétrique.

## Liste des fonctionnalités

| # | Fonctionnalité | Description en une ligne | Emplacement principal dans le code |
|---|---|---|---|
| 1 | Modèle de zone | Une zone = un objet `ZoneCommander` + une trigger zone (cercle ou quadrilatère) avec propriétaire, type d'installation, listes de garnison, flags. | `zc2:46584-46695`, `zc2:4226-4356`, `setup:765-865` |
| 2 | Définition de la garnison et génération aléatoire | Liste ordonnée de groupes/statics template par propriétaire, éventuellement retirée au sort à chaque campagne à partir de templates de taille ; spawn dans des sous-zones. | `zc2:48329-49620`, `zc2:4621-4674`, `zc2:5214-5339` |
| 3 | Initialisation de la zone | Dessin, coalition de l'aérodrome, spawn ou restauration de la garnison. | `zc2:51378-51779` |
| 4 | Boucle de mise à jour de la zone, pertes, réparation, upgrade, reddition | Tick de 10 s étalé ; détection des pertes par scrutation ; upgrade/réparation d'un cran ; les zones rouges s'affaiblissent visiblement et peuvent se rendre. | `zc2:43291-43347`, `zc2:55146-56030`, `zc2:56884-57100` |
| 5 | Neutralisation et désactivation | Une zone vidée devient neutre ; certaines zones sont détruites pour de bon (objets critiques, zones à usage unique). | `zc2:55294-55451`, `zc2:50185-50270` |
| 6 | Canaux de capture | Tout ce qui peut capturer une zone neutre, et ce qu'une capture déclenche. | `zc2:56557-56818` et appelants |
| 7 | Capture temporisée | La capture dure `ZoneCaptureBuildSeconds` et exige un participant survivant dans la zone. | `zc2:46711-47125` |
| 8 | Advance capture | Supply pré-positionné contre une zone rouge affaiblie, libéré quand elle tombe. | `zc2:50100-50142`, `zc2:55453-55502`, `zc2:60041-60292` |
| 9 | Dormance des zones | Suspension par distance, suspension « idle », réveil par proximité et par la mission, respawn mis en file. | `zc2:37445-37990`, `zc2:37071-37163`, `zc2:47748-48084` |
| 10 | Graphe de connexions | Adjacence déclarée à la main et tables dérivées « connecté au bleu ». | `zc2:27025-27054`, `zc2:27303-27535` |
| 11 | Front | Segments vers l'ennemi le plus proche, distance signée au front, listes de voisins. | `zc2:9092-9612` |
| 12 | Carte : formes et libellés des zones | Forme colorée et une zone de texte par coalition, mises à jour en place ; flash d'attaque. | `zc2:51392-51436`, `zc2:51694-51742`, `zc2:56076-56264` |
| 13 | Carte : lignes de connexion / flèches de supply | Lignes ou flèches entre les bords des zones, colorées selon le propriétaire. | `zc2:38010-38292`, `zc2:38985-39110` |
| 14 | Carte : calques de territoire | Cellules de Voronoï teintées par propriétaire avec bordures de front, redessin incrémental. | `zc2:39115-40310` |
| 15 | Zones cachées, zones qui apparaissent, événements de zone scriptés | Zones de réserve invisibles, zones qui apparaissent en cours de campagne, réactions du fichier de setup. | `zc2:44581-44598`, `zc2:50470-50640`, `setup:1851-1940` |
| 16 | Menu F10 « Intel & Zone status » et message de statut | Liste des zones par camp pour chaque groupe ; texte de statut avec état de la garnison et coordonnées. | `zc2:40312-40507`, `zc2:50274-50465` |
| 17 | Commandes marqueur d'admin sur les zones | Capture, upgrade, nettoyage, explication. | `zc2:28886-29202` |
| 18 | Victoire / défaite de campagne | Toutes les zones visibles d'un camp perdues → message, réinitialisation de la sauvegarde, fin de mission. | `setup:2732-2849` |


## 1. Modèle de zone (`ZoneCommander` + `CustomZone`)

### Ce que règle le créateur de mission

Une zone est un objet Lua créé dans le fichier de setup et une trigger zone de même nom dans le `.miz`.
`ZoneCommander:new({facility=, zone=, side=, size=, level=, upgrades=, crates=, flavorText=, income=, isHeloSpawn=, isPlaneSpawn=, NeutralAtStart=, isHidden=})` est l'appel du constructeur, par exemple `batumi = ZoneCommander:new({facility='airbase', isPlaneSpawn=true, isHeloSpawn=true, zone='Batumi', side=1, size='big', level=25, upgrades=upgrades.airfield1, crates={}, flavorText=flavor.batumi})` (`setup:768`).
Le setup du Caucase déclare 89 zones de cette façon (`setup:766-865`, décompte par grep).
La zone est ensuite enregistrée avec `bc:addZone(zone)`, qui lui donne son identifiant de base de marque de carte `index = #zones + 3000`, met en cache sa `CustomZone` dans `zone._cz`, et dérive `isHidden` du nom de la zone s'il contient « hidden » quand le champ n'a pas été renseigné (`zc2:26791-26812`).

Champs du constructeur réellement lus par le moteur :

| Champ | Signification | Où |
|---|---|---|
| `zone` | Nom de la trigger zone dans le `.miz` ; c'est aussi le nom affiché et la clé dans `bc.indexedZones`. | `zc2:46682`, `zc2:26802` |
| `side` | Propriétaire de départ 0/1/2. | `zc2:51394-51400` |
| `facility` | L'un de `airbase`, `farp`, `carrier`, `ground`, `logistics`, `none` ; vérifié par assertion, vaut `none` par défaut avec une ligne de log. | `zc2:45868-45875`, `zc2:46586-46591` |
| `isPlaneSpawn`, `isHeloSpawn` | La zone peut lancer des avions / hélicoptères IA ; une zone bleue avec l'un ou l'autre reçoit un contour vert en pointillés. | `zc2:46592-46593`, `zc2:51739-51742` |
| `level` | Nombre d'emplacements de garnison (upgrade) spawnés au démarrage de la mission (emplacements `1..level`) ; 25 partout dans le Caucase, c'est-à-dire « tous ». | `zc2:51621-51623`, `setup:768` |
| `upgrades = {red={...}, blue={...}}` | Liste de garnison ordonnée par propriétaire ; chaque entrée est un nom de groupe en late activation, un nom de static, ou `{n='name', p=true}` (« épinglé » : jamais tiré au sort ni remplacé). | `zc2:46653-46674`, `zc2:48604-48615` |
| `size` | Clé dans les templates de garnison aléatoire (`small`, `smallmedium`, `medium`, `mediumbig`, `big`, `bignosam`, `smallwithShorad`, `redarmycamp`…). | `zc2:48539-48542`, `setup:768-834` |
| `income` | Crédits ajoutés au propriétaire à chaque tick de mise à jour de la zone. | `zc2:55157-55167` |
| `crates` | Noms d'objets cargo statiques du `.miz` qui capturent ou améliorent la zone quand on les trouve au sol à l'intérieur. | `zc2:55206-55253` |
| `flavorText` | Texte libre affiché dans le message de statut de la zone. | `setup:768` (code d'affichage : `zc2:50274` et suivantes) |
| `NeutralAtStart` | Marque les zones qui commencent neutres ; effacé à l'init si la zone a un propriétaire, et à la première capture. | `zc2:51407-51409`, `zc2:56622` |
| `isHidden` | La zone n'a ni dessin sur la carte, ni libellé, ni entrée dans le menu de statut, ni message de perte. | `zc2:51411-51417`, `zc2:55370` |
| `upgradesUsed` | Compteurs par camp `upgradesUsedRed` / `upgradesUsedBlue`. | `zc2:46607-46610` |

Champs posés après la construction dans le fichier de setup :

- `zones.X.airbaseName = 'Batumi'` lie la zone à un objet aérodrome ou FARP de DCS (`setup:1231-1288`) ; utilisé pour `Airbase:setCoalition`, les entrepôts et les statics de slot.
- `zones.X.industryCores = {['static name']=true}` (zones industrielles PvP, `setup:869-873`).
- `zones.X.customSuspendNm`, `zones.X.noIdleSuspend` surchargent les règles de dormance par zone (`setup:989-992`).
- `zone:addCriticalObject(staticName)` : quand tous les statics critiques sont morts, la zone est désactivée pour de bon (`zc2:50036-50039`, `zc2:51904-51930`).
- `zone:registerTrigger(eventType, action, id, timesToRun, options)` avec les types d'événement `captured`, `upgraded`, `repaired`, `lost`, `destroyed` (`zc2:50062-50072`) ; `options.disablesZone` sur un trigger `lost` marque la zone comme « disparaît quand elle est perdue », ce qui l'exclut aussi de l'advance capture (`zc2:50066-50071`, `zc2:50126`).
- `zone:addRestrictedPlayerGroup({name=, side=})` : un user flag portant le nom du groupe est mis à 1 quand la zone n'appartient pas à `side`, à exploiter par une logique de blocage des slots (`zc2:50022-50024`, `zc2:55197-55202`, `zc2:51745-51747`).

Conventions de trigger zone dans le `.miz` (toutes lues depuis `env.mission.triggers.zones`, `zc2:203-223`) :

- La zone principale peut être un cercle ou un quadrilatère à 4 points (`type` 0 ou 2) ; les deux sont gérés pour les tests d'inclusion et le dessin (`zc2:4244-4278`, `zc2:4294-4306`).
- `<Zone>-<number>` sont des sous-zones de spawn pour les groupes de garnison (`zc2:1423-1442`).
- `<Zone>-SAM-…` et `<Zone>-SHORAD-…` sont des sous-zones réservées aux groupes SAM longue portée et SHORAD (la correspondance ne distingue pas les majuscules) (`zc2:4725-4745`, `zc2:5257-5269`).
- Les zones `<Key>-Supply-<n>` sont des waypoints de routes de cargo par hélicoptère (autre thème) (`zc2:209-222`).
- Une zone dont le nom contient « hidden » est cachée (`zc2:4236`, `zc2:26792-26794`).

### Mécanisme

`CustomZone:getByName` construit une seule fois par nom une table `{name, type, point, radius, vertices, minX…maxZ, radiusSq, isHidden}` à partir de la table de la mission et la met en cache (`zc2:4228-4284`).
`CustomZone:isInside(point)` fait un rejet par boîte englobante, puis un test de distance au carré pour les cercles ou `UTILS.IsPointInPolygon` pour les quadrilatères (`zc2:4294-4306`) ; cet utilitaire de Moose est un simple test de lancer de rayon (nombre de croisements sur `x`/`z`, sur une copie profonde de la liste de sommets à chaque appel) et c'est la seule dépendance de la géométrie envers Moose (`Moose_2026-10-11.lua:5145-5168`).
`CustomZone:getZoneBuildings` exécute `world.searchObjects(Object.Category.SCENERY, sphere)` une fois par zone et met en cache les positions des objets de décor portant l'attribut `Buildings` (`zc2:4308-4343`).

État conservé par zone à l'exécution : `side`, `active`, `suspended`, `built` (indice d'emplacement → groupe vivant ou nom de static), `spawnSubZones` (emplacement → sous-zone utilisée), `groups` (les `GroupCommander` IA basés là, autre thème), `triggers`, `criticalObjects`, `restrictedGroups`, `pendingCapture`, ainsi qu'un ensemble de caches et de flags de dormance (`zc2:46594-46651`).

### Notes de reproduction

Le nom de la zone sert d'identifiant partout, y compris comme préfixe des sous-zones ; une zone renommée dans l'éditeur perd silencieusement ses sous-zones.
Les zones quadrilatères sont stockées avec `y` et `z` inversés par rapport à la table de la mission (`zc2:4249-4253`).
La propriété « hidden » repose sur le nom à deux endroits et sur un champ à un troisième, donc les trois doivent concorder.

## 2. Définition de la garnison, génération aléatoire et placement des spawns

### Ce que règle le créateur de mission

Le global `upgrades` du fichier de setup nomme des listes réutilisables, par exemple `airfield1 = { blue = {'blueInfantry', 'Blue Armor Modern', 'Blue SAM NASAMS'}, red = {'Enemy ground forces', 'Red SAM AAA', …} }` (`setup:89-97`).
Chaque nom doit exister dans le `.miz` comme groupe en late activation (utilisé comme template) ou comme objet static ; un nom manquant déclenche un message à l'écran à l'init (`zc2:51558-51584`).
Un nom contenant `Fixed` est spawné exactement là où il a été placé dans l'éditeur, au lieu d'une sous-zone aléatoire (`zc2:5220-5243`).
Un nom contenant `Fixed` ou `(p)`, ou une entrée avec `p=true`, est exclu de la randomisation (`zc2:48598-48615`).
Un nom contenant `dismounted` n'est jamais spawné par la zone elle-même (`zc2:51560`, `zc2:51606`, `zc2:51631`).
Les noms de groupes contenant `IsNotShown` ou `Red EWR` sont spawnés cachés sur la carte F10 (`zc2:4658-4660`).

Garnisons aléatoires : `RandomGroundGroups` et `RandomBlueGroups` valent true par défaut (`zc2:48417-48418`).
`applyRandomRedUpgrades()` réécrit `zone.upgrades.red` de chaque zone éligible (ni cachée sans size, ni porte-avions) à partir d'un template de taille `RandomUpgradeTemplates[size]` qui donne un nombre ou une plage `{min,max}` par catégorie `sam`, `shorad`, `aaa`, `ground`, `armor`, `arty` et un `total` (`zc2:49516-49598` ; les tables elles-mêmes sont dans `setup:698-728`, résolues par `resolveTemplate`, `zc2:48506-48524`).
`MaxRedGroundGroupsPerZone` (Config) plafonne le nombre de groupes rouges par zone, borné entre 5 et 12 (3 et 6 sur Normandie), et réduit les templates par palier de taille quand il est inférieur au maximum de la carte (`zc2:49517-49581`).
Les catégories sont dérivées du nom du groupe par sous-chaîne (`aaa`, `shorad`/`sa-8`/`sa-15`…, `sa-2`/`sa-10`/`hawk`/`patriot`…, `arty`/`mlrs`…, `armor`, `infantry`/`truck`…) (`zc2:48550-48596`).
Les entrées épinglées, `Fixed` et static sont conservées ; le reste est tiré d'un pool global de templates rouges (ou bleus) filtré par les interrupteurs « templates activés » de la Config (détail plus bas).
Le tirage est déterministe par campagne : une graine de campagne est créée une fois (à partir de `socket.gettime` si LuaSocket se charge, sinon de la date de la mission et des timers) et mélangée avec le camp, la taille de la zone et le nom de la zone avant la génération de chaque zone (`zc2:48450-48494`) ; tous les tirages passent par `fhRand`, un générateur congruentiel linéaire `seed = (1103515245 × seed + 12345) mod 2^31` (`zc2:48420-48440`).
Le fichier de setup n'appelle `applyRandomRedUpgrades()` et `applyRandomBlueUpgrades()` que lorsqu'aucune sauvegarde n'a été chargée, et `applyRandomUpgradesForNewZonesOnly()` dans le cas contraire (`setup:5917-5919`, `setup:5938-5939`).

Templates de taille pour le rouge, Caucase (`setup:698-714`) ; un nombre seul est un compte fixe, `a–b` une plage uniforme, « flak » = `flakChance` / `flakSecondChance` / `flakMax`, « keep » = `RandomRedPickKeepChance` pour `Red SAM SHORAD Pantsir S1` et `Red SAM SHORAD Tor M2` à la fois :

| size | sam | shorad | aaa | ground | armor | arty | total | flak | keep % |
|---|---|---|---|---|---|---|---|---|---|
| `small` | 0 | 0–2 | 0–2 | 0–3 | 0–2 | 0–2 | 4–6 | 10 / 0 / 1 | 20 |
| `smallwithShorad` | 0 | 2 | 2 | 0–1 | 1 | 0 | 4–7 | 10 / 0 / 1 | 30 |
| `smallmedium` | 0 | 0–3 | 0–2 | 0–3 | 0–3 | 0–2 | 4–7 | 12 / 0 / 1 | 30 |
| `medium` | 0–1 | 0–3 | 0–3 | 0–3 | 0–3 | 0–3 | 4–9 | 20 / 0 / 1 | 40 |
| `mediumbig` | 0–1 | 0–4 | 0–3 | 0–3 | 0–4 | 0–3 | 5–10 | 30 / 5 / 2 | 50 |
| `big` | 0–1 | 0–4 | 0–3 | 0–3 | 0–4 | 0–3 | 5–10 | 50 / 20 / 2 | 70 |
| `bignosam` | 0 | 0–4 | 0–3 | 0–3 | 0–4 | 0–3 | 5–10 | 50 / 20 / 2 | 70 |
| `extrabig` | 1–2 | 0–5 | 0–4 | 0–4 | 0–4 | 0–4 | 7–12 | 60 / 30 / 2 | 100 |
| `sam` | 1 | 1–2 | 1–2 | 0 | 0 | 0 | 3–5 | 10 / 0 / 1 | 70 |
| `sam2` | 1 | 1–2 | 1–2 | 0 | 0–1 | 0 | 3–6 | 10 / 0 / 1 | — |
| `samspecial` | 2 | 1–3 | 1–2 | 0 | 0 | 0 | 6–7 | 25 / 8 / 2 | 0 |
| `redarmycamp` | 0 | 0 | 0 | 3–5 | 0 | 0–5 | 6–8 | — | — |
| `redarmycamp2` | 0 | 0 | 1–2 | 3–5 | 0 | 0–4 | 6–8 | 0 / 0 / 0 | — |
| `redarmycamp3` | 0–2 | 0–3 | 1–3 | 0 | 0 | 0 | 6–8 | 0 / 0 / 0 | — |

Templates de taille pour le bleu (`RandomUpgradeTemplatesBlue`, `setup:716-727`) : chaque size a `ground 0–1`, `armor 1`, `aaa 0–1`, `shorad 0–1` ; `sam` vaut 0 pour `small`, `smallmedium`, `medium`, `mediumbig`, `bignosam` et 0–1 pour `big`, `extrabig`, `sam`, `sam2`, `samspecial` ; `total` vaut 2 (`small`, `smallmedium`), 2–3 (`medium`, `mediumbig`), 3–4 (`big`, `extrabig`, `bignosam`), 4 (`sam`, `sam2`, `samspecial`).
En PvP, les deux camps utilisent `PvPBaseGarrisonProfiles`, qui rabat chaque size sur les lignes bleues `small` / `medium` / `big` / `bignosam` / `sam`, les grandes étant forcées à `total = 3` (`setup:729-746`).
`ZoneSizeExclusions[size]` est une liste de sous-chaînes en minuscules qu'un nom de template ne doit pas contenir pour cette size, par exemple `small = {"sa-10","sa-11","sa-2","pantsir","tor m2"}`, `medium = {"sa-10","sa-11","pantsir"}` (`setup:689-696`, `zc2:48728-48744`) ; `zone.noLongRangeSam` interdit en plus les noms SA-2/SA-10/SA-11 (`zc2:48739-48741`, `zc2:48633-48639`).
`RandomRedPool` (55 noms pour l'ère moderne : 5 SAM stratégiques, 7 SHORAD, 10 AAA, 2 infanterie, 3 blindés, 6 mécanisés, 3 spéciaux, 10 artillerie, plus 6 groupes « Enemy Ground-Light » hors Vietnam et 3 groupes « …-Modern » à l'ère moderne) et `RandomBluePool` (9 noms) sont des listes littérales dans le fichier de setup, échangées nom par nom pour les ères Guerre froide et Vietnam (`setup:594-687`, décomptes par lecture de la liste).

### Mécanisme — le tirage aléatoire

Pools (`zc2:48746-48866`).
`getGlobalRedPool()` renvoie `RandomRedPool` quand le fichier de setup la définit ; sinon elle parcourt chaque liste `upgrades.<key>.red` (porte-avions et clés « hidden » exceptés) et garde chaque nom qui n'est ni épinglé, ni `Fixed`, ni un static et qui existe comme template (`zc2:48746-48780`).
`getGlobalBluePool()` est la même chose sur `upgrades.<key>.blue`, avec `Blue SAM PATRIOT` toujours exclu (`zc2:48782-48813`).
`fillPoolsFrom(source, pools, zone, size)` range les noms candidats dans des listes par catégorie après quatre filtres : ni épinglé/`Fixed`/static ; activé par les interrupteurs de la Config ; non exclu par `ZoneSizeExclusions` ni `noLongRangeSam` ; un template de ce nom existe (`zc2:48815-48848`).
L'interrupteur de la Config est une table `RedTemplateEnabled` (ou l'ancienne `RedSamTemplateEnabled`) indexée par famille — `SA-2`, `SA-3`, `SA-5`, `SA-6`, `SA-8`, `SA-9`, `SA-10`, `SA-11`, `SA-13`, `SA-15`, `SA-19`, `Tor M2`, `Pantsir S1`, `MANPAD`, toutes à true par défaut ; la famille d'un nom se trouve par sous-chaîne (`manpad`, `pantsir`, `tor m2`, puis `sa-19` … `sa-2` en commençant par le plus long, avec trait d'union ou espace), avec des surcharges par nom `RedTemplateKeyByName` et la règle intégrée `Enemy Task forces` → `MANPAD` (`zc2:48641-48687`, `zc2:48689-48712`).
Un nom désactivé est remplacé par `RedTemplateReplacementByName[name]` (intégré : `Enemy Task forces` → `Enemy ground forces`) et le remplaçant est filtré à nouveau ; sans remplaçant, il est abandonné (`zc2:48714-48719`, `zc2:48828-48836`).
En PvP, le but « garnison de base » interdit en plus SA-5, SA-10, SA-11, SA-15, SA-19, Tor M2 et Pantsir, ainsi que tout SAM/SHORAD dont la famille n'est pas SA-2/3/6/8/9/13/MANPAD (`zc2:48691-48706`).

`buildRandomRedUpgrades(zone, maxGroups, generationProfiles)` (`zc2:49028-49302`) :

1. Initialiser le générateur pour (zone, « red », size) ; sans template pour cette size, la liste écrite à la main est renvoyée avec les noms désactivés remplacés (`resolveConfiguredRedUpgrades`) (`zc2:49030-49034`, `zc2:49000-49014`).
2. Résoudre le template : chaque plage est tirée une fois avec `fhRand`, et `total` est borné à `maxGroups` (`zc2:48506-48524`, `zc2:49037`).
3. Parcourir la liste écrite à la main : les statics vont dans `staticList` ; une entrée épinglée dont la famille est désactivée est abandonnée ; les entrées `Fixed`, épinglées et « extra forcées » (les noms de `zone.extraUpgrade` achetés pour le rouge) vont dans `fixedList` et sont comptées par catégorie (`zc2:49039-49083`).
4. Construire les pools à partir du pool rouge global (ou, quand `RandomGroundGroups` est false, à partir de la liste propre à la zone, avec repli sur le pool global si elle ne donne rien), et en retirer les noms forcés (`zc2:49104-49128`).
5. Flak : quand le template a `flakChance`, le pool de flak (`RandomFlakPool` ou, par défaut, `Red SAM AAA 3` et `Red SAM AAA 4`, filtré comme n'importe quel pool et restreint à la catégorie `aaa`) est sorti du pool AAA ordinaire (`zc2:48926-48942`, `zc2:49130-49136`).
6. Cibles : `needed[cat] = rolled count − fixed count` ; `targetTotal` vaut au moins `fixed + sum of category minimums` et au plus `maxGroups` ; si les besoins des catégories dépassent la place restante, des catégories tirées au hasard qui ont une plage sont décrémentées une à une, jamais en dessous de leur minimum (`zc2:49138-49190`).
7. Ordre de sortie : statics (seulement si `UseStatics`), puis fixed, puis pour chaque catégorie dans l'ordre sam, shorad, aaa, ground, armor, arty : `want` noms tirés sans répétition dans le pool de la catégorie, avec répétition seulement quand le pool est plus petit que `want` (`pickFromPoolAllowRepeats`) (`zc2:49191-49228`, `zc2:48869-48900`).
8. Chaque nom tiré passe par `applyRandomRedPickKeepChance` : un nom listé dans `RandomRedPickKeepChance` du template est conservé avec ce pourcentage, sinon il est échangé contre un autre nom du même pool qui n'est pas déjà tiré et, de préférence, n'est pas lui-même dans la liste keep-chance (`zc2:48902-48924`).
9. S'il reste de la place (`total` supérieur à la somme des catégories), les noms sont tirés un par un dans l'union de tous les pools de catégorie qui ont encore de la place sous leur maximum, avec repli sur le pool `other` (`zc2:49230-49266`).
10. Substitution de flak : un tirage à `flakChance` %, puis (si `flakMax > 1` et qu'au moins deux emplacements AAA aléatoires existent) un tirage à `flakSecondChance` % ; autant d'emplacements AAA aléatoires, choisis au hasard, sont écrasés par des noms distincts du pool de flak (`zc2:48956-48998`, `zc2:49268-49270`).

Réduction par `MaxRedGroundGroupsPerZone` (`zc2:49517-49581`) : uniquement en PvE, pas sur Normandie, et seulement quand le réglage est inférieur à la fois à 12 et au plus grand maximum de `total` des size utilisées.
Chaque size reçoit alors un `ceiling` : avec un réglage ≤ 6, `min(high, setting − gap)` où `gap` vaut 2 pour `small`, 1 pour `smallmedium` et `medium`, 0 pour `mediumbig`, `big`, `bignosam` ; au-dessus de 6, `high` est réduit de `(high − (6 − gap)) × (mapMax − setting) / (mapMax − 6)` arrondi à l'inférieur (arrondi au plus proche quand `gap` vaut 0) ; la borne basse suit (`zc2:49528`, `zc2:49556-49574`).
Avec un réglage ≤ 6 et `gap > 0`, un « budget de poids » est aussi appliqué : budget = 2 × (min(rolled total, max(tierMinimum, rolled total − 1)) − fixed count) avec `tierMinimum` valant 2 pour `small` et 3 sinon ; chaque tirage aléatoire coûte 2, ou 1 pour un template AAA/SHORAD à une seule unité ; les tirages qui satisfont le minimum d'une catégorie sont toujours payés, les autres ne sont conservés dans l'ordre que tant que le budget dure (`zc2:49575-49577`, `zc2:49142-49147`, `zc2:49272-49299`).
Les size sans entrée `tierGap` (`extrabig`, `sam…`, `redarmycamp…`, `smallwithShorad`) gardent leur template et seulement le bornage global de `total` (`zc2:49557-49558`, `zc2:49094-49101`).

`buildRandomBlueUpgrades(zone, actualOwner)` suit le même plan avec moins d'étapes : template de `RandomUpgradeTemplatesBlue[size]`, `total` borné à `MaxBlueGroundGroupsPerZone` (lui-même borné entre 1 et 4), statics et entrées fixed/épinglées/forcées d'abord, puis par catégorie dans l'ordre sam, shorad, ground, aaa, armor, arty un tirage **sans** répétition, puis un remplissage à partir des catégories encore sous leur maximum, chaque nom n'étant utilisé qu'une fois (`zc2:49304-49330`, `zc2:49366-49399`, `zc2:49438-49506`).
Il n'y a ni keep-chance, ni flak, ni réduction pour le bleu.
Avec `actualOwner` fourni (PvP), la même fonction construit la garnison de base de l'un ou l'autre camp à partir de `PvPBaseGarrisonProfiles`, garde d'abord les statics de cœur industriel, et renvoie une seconde liste « matérialisée » = base + les upgrades supplémentaires payés de ce camp ajoutés comme entrées épinglées (`zc2:49305-49350`, `zc2:49449-49455`, `zc2:49508-49512`).

Stockage du résultat : la liste tirée est stockée deux fois, comme `zone.randomUpgradesRed` / `randomUpgradesBlue` (la « base », persistée) et comme copie dans `zone.upgrades.red` / `.blue` (la liste de travail que les upgrades supplémentaires étendent ensuite) (`zc2:49587-49594`, `zc2:49608-49615`).

`applyRandomUpgradesForNewZonesOnly()` (`zc2:49621-49849`), exécutée à la place des deux fonctions ci-dessus quand une sauvegarde a été chargée :

- une zone n'est tirée que si elle n'a aucune entrée sauvegardée, ou (PvE) une entrée sauvegardée sans aucune des listes `randomUpgrades*` ; elle oublie alors aussi `remainingUnits` et pose `_refreshRandomUpgrades` (`zc2:49732-49771`) ;
- sur Normandie, elle renomme d'abord les anciens upgrades supplémentaires sauvegardés `EWR` / `BluePD` en `bluePD` (`zc2:49624-49658`) ;
- pour chaque zone restaurée comme suspendue, chaque emplacement de `remainingUnitsSnapshot` est comparé aux types d'unités du template actuellement dans cet emplacement (`_getUpgradeTemplateUnitCount`) : les survivants sauvegardés sont conservés quand le nom du template est inchangé et que les types sauvegardés forment un sous-multiensemble des types du template pour une zone suspendue « idle », une zone PvP, une zone `_preserveSuspendedLosses` ou un template `Blue SAM …` / `Blue Armor …` ; sinon l'emplacement est réinitialisé au template complet (et sa sous-zone sauvegardée oubliée) dès que le nom a changé ou que les types sauvegardés ne sont pas exactement ceux du template (`zc2:49773-49846`, `zc2:49685-49722`).

`pickReplacementUpgrade(zone, missingName, upgradesList, side)` (`zc2:49851-50020`) est le repli pour un seul emplacement, utilisé quand un template échoue à spawner ou est désactivé : elle construit les mêmes pools filtrés, prend la catégorie du nom manquant, et tire uniformément parmi les noms du pool de cette catégorie qui ne sont pas déjà dans `upgradesList` ; quand cette catégorie est vide, interdite par le template de taille (maximum 0) ou déjà à son maximum, elle tire parmi toutes les catégories qui ont encore de la place ; elle renvoie nil quand rien ne convient.

### Mécanisme — spawn d'un groupe de garnison

`ZoneCommander:_spawnBuiltGroup` → `CustomZone:spawnGroup(grname, …)` (`zc2:47728`, `zc2:5214-5339`).

1. Groupes `Fixed` : prendre le template de l'éditeur (`GROUP:GetTemplate()` ou `_DATABASE.Templates.Groups[name]`), détruire toute copie vivante, `SPAWN:NewFromTemplate(tpl, grname, nil, true):Spawn()` — c'est-à-dire `coalition.addGroup` avec le nom et les positions d'origine (`zc2:5220-5243`).
2. Sinon choisir un pool de sous-zones : sous-zones `-SAM-` pour les SAM stratégiques, `-SHORAD-` pour les SHORAD, sinon les sous-zones numérotées, en préférant à chaque fois celles qui ne sont pas encore utilisées par cette zone ou globalement (`USED_SUB_ZONES`), et en excluant celles de la liste noire et la sous-zone réservée au static d'entrepôt (`zc2:5254-5288`).
3. Si un placement sauvegardé `{template, subZone}` est fourni (après un redémarrage ou un réveil) et toujours valide, le réutiliser (`zc2:5290-5318`).
4. Sinon tirer des sous-zones au hasard jusqu'à ce que `SpawnCustom` réussisse ; sans aucune sous-zone, la zone principale est utilisée (`zc2:5285-5288`, `zc2:5320-5334`).

`SpawnCustom(grname, zoneName, side, alias)` (`zc2:4621-4674`) :
l'alias est `"<template> # <n>"` avec un compteur par template (`zc2:4622-4623`) ;
`SPAWN:NewFromTemplate(tpl, grname, alias, true):InitSkill(...)` (`zc2:4654`) ;
les groupes non SAM voient la disposition de leurs unités re-randomisée avec `InitSetUnitRelativePositions(randomGroundLayout(...))`, les navires reçoivent `InitRandomizeUnits(true, 1500, 1000)` (`zc2:4655-4657`) ;
les templates SAM gardent leur disposition de l'éditeur ;
le point de spawn vient de `GetValidCords`, qui essaie jusqu'à 100 points aléatoires de la zone Moose et accepte le premier dont `land.getSurfaceType` vaut LAND ou ROAD (WATER/SHALLOW_WATER pour les zones de porte-avions), jamais RUNWAY (`zc2:4390-4403`, `zc2:4643-4649`) ;
une sous-zone sans point valide est mise sur liste noire dans `INVALID_SPAWN_SUB_ZONES` pour la session (`zc2:4404-4413`) ;
puis `spawn:SpawnFromCoordinate(coord)` → `coalition.addGroup` (`zc2:4661-4668`).
Les groupes SAM peuvent être marqués `hiddenOnMFD` selon le réglage `HideSAMOnMFD` (`true`, `false`, `"random"`) (`zc2:4432-4439`, `zc2:4651-4653`).

### Notes de reproduction

Les templates sont consommés par nom parmi les groupes en late activation de la mission ; le groupe template d'origine est détruit s'il est vivant (`zc2:4630`).
La tenue des comptes de sous-zones est globale (`USED_SUB_ZONES`) et par zone (`usedSpawnZones`) et est vidée par préfixe quand une zone devient neutre (`zc2:5341-5350`, `zc2:55354-55355`).
Les morceaux de Moose utilisés sont `SPAWN` (copie de template, alias, repositionnement des unités, skill) et `ZONE:GetRandomCoordinate` ; aucun n'est profond.

## 3. Initialisation de la zone (`ZoneCommander:init`)

Appelée pour chaque zone par `bc:init()` après l'application du fichier de sauvegarde (`setup:5835`, `setup:5961`).

- Dessine la forme de la zone et ses deux libellés (section 12) (`zc2:51411-51417`, `zc2:51694-51736`).
- Pour une zone avec `airbaseName` (porte-avions `CVN-72…75` exceptés) : coupe la capture automatique de DCS (`ab:autoCapture(false)`), fixe la coalition de l'aérodrome au camp de la zone avec `Airbase:setCoalition`, refait spawner les statics de slot de cette base pour le camp (`RespawnStaticsForAirbase`, 1 s plus tard), et vide les armements de l'entrepôt quand la logistique d'entrepôt est activée et que la zone n'est pas un centre logistique (`zc2:51434-51485`).
- Construit la garnison : si la zone a une liste de survivants par emplacement sauvegardée (`remainingUnits`), seuls ces emplacements sont respawnés puis élagués unité par unité (`weedOutRemainingUnits`) ; sinon les emplacements `1..level` de la liste d'upgrades filtrée sont spawnés (`zc2:51593-51688`, `zc2:51743`).
- Un groupe qui échoue à spawner est remplacé par un autre template de la même catégorie quand il en existe un (`pickReplacementUpgrade`), et le remplaçant est réécrit dans la liste d'upgrades (`zc2:51645-51677`).
- Une zone restaurée comme suspendue ne spawne pas sa garnison : les noms d'emplacements sont mis dans `built` et mémorisés dans `_persistedHibernatedSlots` ; seuls les groupes dont le template est un « radar persistant en suspension » (GCI/EWR bleu) sont spawnés (`zc2:51504-51545`).
- Pose les flags de groupes restreints, initialise les commandants de groupes IA de la zone, amorce les caches de supply et d'advance capture (`zc2:51745-51756`).

`weedOutRemainingUnits(opts)` est la passe d'élagage qui ramène une garnison tout juste respawnée à pleine force à celle, endommagée, qui avait été sauvegardée (`zc2:51788-51901`).
Elle détruit d'abord tout groupe vivant dont le nom figure dans la liste d'upgrades de la zone mais pas dans `built` (restes de templates), sauf si `skipDestroyUnspawnedGroups` est posé (`zc2:51794-51807`, `zc2:51893-51895`).
L'élagage lui-même s'exécute deux fois, 2 s et 4 s après l'appel (deux `SCHEDULER` à tir unique, le second déclenchant aussi `opts.onTrimComplete`), parce que les groupes viennent tout juste d'être demandés à `coalition.addGroup` (`zc2:51896-51900`).
Pour chaque groupe construit, elle lit l'emplacement sauvegardé, soit `remainingUnits[slot]` (une liste de **noms de types** d'unités), soit, pour les groupes « fixed hidden », `remainingUnitNames[slot]` (une liste de **noms** d'unités) (`zc2:51814-51821`).
Branche par nom exact : si au moins un nom d'unité vivante figure dans la liste sauvegardée, toute unité dont le nom n'y figure pas (ou dépasse son compte sauvegardé) est détruite avec `Unit:destroy()` (`zc2:51824-51850`).
Branche par type (le cas « tri par type ») : sinon un multiensemble `need[typeName] = count` est construit à partir de la liste sauvegardée et les unités du groupe sont parcourues dans l'ordre ; une unité dont le type a encore un compte positif en consomme un, toute autre unité est détruite, de sorte que les survivants sont les N premières unités de chaque type, et non les mêmes individus (`zc2:51851-51865`).
Une liste de types sauvegardée vide ne détruit rien, sauf dans une restauration de réveil « idle » (`idleRestoreToken`) où elle vide le groupe (`zc2:51851`).
Elle détruit aussi les statics listés dans `newStatics` qui ne sont pas dans `built` (cœurs industriels neutres PvP exceptés) et marque le cache d'efficacité de supply comme sale quand quoi que ce soit a été retiré (`zc2:51869-51891`).
Un élagage de réveil « idle » est abandonné si la zone a changé de camp, est retournée dormir ou a été supplantée entre-temps par un réveil plus récent (`zc2:51810-51812`).

Statics comme garnison : quand `UseStatics` est true, un static nommé dans `upgrades` compte comme un emplacement construit tant qu'il existe ; quand c'est false, de tels statics sont détruits par `getFilteredUpgrades` (`zc2:51510-51515`, `zc2:48403-48408`).

`getFilteredUpgrades()` renvoie la liste d'upgrades du propriétaire actuel, avec les templates rouges désactivés dans la Config retirés ou substitués (`getRedTemplateReplacement`), et renvoie une liste vide pour une zone neutre (`zc2:48329-48414`).

## 4. La boucle de mise à jour de la zone, les pertes, les réparations et l'« efficacité au combat »

### Mécanisme

`BattleCommander:new(savepath, updateFrequency, saveFrequency)` est appelé avec `updateFrequency = 10` s et `saveFrequency = 60` s (`setup:754`, `zc2:17082`).
`BattleCommander:update()` s'exécute une fois par période ; après une première passe synchrone, il traite les zones en « vague » : un `zone:update()` toutes les 0,1 s via un `timer.scheduleFunction` qui se reprogramme lui-même, et un tick qui arrive pendant qu'une vague tourne encore est mis en file, pas exécuté en parallèle (`zc2:43291-43347`).
Après la vague : mise à jour de l'intel de zone, moniteur de ROE, atténuation de la difficulté (`zc2:43255-43276`).

`ZoneCommander:update()` par zone (`zc2:55146-55204`) :

1. Les zones inactives ne font rien.
2. Faire avancer le timer de capture temporisée (section 7).
3. État d'installation d'entrepôt (autre thème).
4. Verser `income` au propriétaire (PvE : une zone bleue suspendue par distance ne rapporte rien ; les zones `redIncomeOnly` ne paient que le rouge) (`zc2:55155-55168`).
5. Les zones suspendues s'arrêtent ici (seuls leurs groupes IA actifs sont mis à jour) (`zc2:55169-55174`).
6. Toutes les `GlobalSettings.builtMaintenanceNormalSec` (30 s par défaut, surcharge par zone `_builtMaintenanceInterval`), alignées sur le tick de 10 s et réparties sur les emplacements par un ordinal propre à chaque zone pour que toutes les zones ne scrutent pas au même tick, exécuter `_maintainBuiltState` (`zc2:55175-55182`, `zc2:37394-37406`).
7. Si `built` est vide et que la zone a un propriétaire → `_neutralizeEmptyBuiltZone()` (section 6) (`zc2:55184-55188`).
8. Mettre à jour les groupes IA actifs de la zone, traiter les crates de supply, rafraîchir les flags de groupes restreints (`zc2:55190-55203`).

`_maintainBuiltState` (`zc2:55741-56030`) parcourt chaque emplacement construit avec des appels DCS bruts (`Group.getByName`, `StaticObject.getByName`, `getSize`, `getInitialSize`, `getLife`) :

- un groupe de taille 0 ou sans aucune unité de vie ≥ 1 est détruit et son emplacement retiré ; un static de vie < 1 de même ; un nom qui ne se résout plus est retiré (`zc2:55844-55847`, `zc2:55923-55948`, `zc2:55971-55979`) ;
- un emplacement retiré produit le message facultatif "ZONE_LOST_GROUP" (`GlobalSettings.messages.grouplost`) (`zc2:55624`) ;
- un emplacement est conservé dans `built` bien que détruit si un travail local de réparation/reconstruction le vise déjà, sauf si tout a été détruit (`zc2:55598-55613`) ;
- avec `UseStatics`, un static détruit est consigné dans `retiredStaticUpgrades` et retiré pour de bon de la liste d'upgrades (`zc2:55617-55647`) ;
- il accumule la « capacité opérationnelle » (unités vivantes / unités prévues par groupe), compte les groupes endommagés, et publie des instantanés utilisés par la demande de supply, la menace SEAD, les cibles JTAC et les libellés (`zc2:55898-55922`, `zc2:56018-56026`).

Efficacité au combat et reddition (zones rouges, visibles, hors porte-avions uniquement, `zc2:55780-55781`) :

- L'état `full`, `reduced` (endommagé, il reste des unités mobiles, plus de défense aérienne) ou `static` (endommagé, il ne reste que des statics) recolore le remplissage de la zone : rouge `{1,0,0,0.3}`, rouge clair `{1,0.45,0.45,0.3}`, violet `{0.55,0.2,0.7,0.3}` (`zc2:55655-55664`, `zc2:45911-45915`).
- Défense aérienne = unité ayant l'attribut `SAM TR`, `AAA` ou `IR Guided SAM` ; « faible » = pas de défense aérienne et `Unarmed vehicles` ou `Infantry` (`zc2:45901-45908`).
- Quand la zone n'est plus « forte » (aucun static, aucun navire, aucune défense aérienne, tous les groupes mobiles faibles, au plus 4 unités vivantes), un palier 4..1 est évalué et un tirage de reddition est fait avec une chance de 40/60/70/80 % pour les paliers 4/3/2/1 (`zc2:55666-55683`, `zc2:45916-45921`).
- Le palier **est** le nombre d'unités de garnison vivantes (1 à 4) : `EvaluateZoneSurrenderTransition` garde trois valeurs par zone — le dernier compte d'unités vivantes observé, si la zone était forte au dernier balayage, et le plus bas palier déjà tiré (`surrenderEvaluatedTier`, persisté) — et ne renvoie un palier à tirer que lorsque la zone s'est affaiblie depuis le dernier balayage (elle était forte, ou le compte a baissé) et que le compte est inférieur à tout palier déjà tiré (`zc2:45942-45970`).
- Conséquences : au plus un tirage par palier et par cycle d'affaiblissement, donc au plus quatre tirages (4, 3, 2, 1 unités) à mesure que la garnison s'use ; le premier balayage après un chargement ou un réveil ne fait qu'amorcer l'observation et ne tire jamais ; une zone redevenue forte (réparation, upgrade) oublie ses paliers tirés ; une zone protégée (ci-dessous) n'est pas touchée (`zc2:45944-45958`, `zc2:45973-45982`).
- Le tirage lui-même utilise `math.random(1,100) <= chance`, pas le générateur de campagne (`zc2:55998`).
- En cas de succès, tous les groupes faibles sont détruits et retirés de `built`, et le bleu reçoit "ZONE_ENEMY_FORCES_SURRENDERED" (`zc2:55998-56010`, `zc2:55686-55705`).
- Les unités visées par un slot CAS actif sont « protégées contre la reddition » (`zc2:55729-55733`, `zc2:46001`).

### Upgrade et réparation (`ZoneCommander:upgrade`)

`zone:upgrade(silent, repairTargetName, upgradeTargetIndex)` fait exactement un cran par appel (`zc2:56884-57100`) :

- première passe sur `built` : le premier groupe dont la taille est inférieure à sa taille initiale est respawné en entier (`RespawnZoneRepairTarget`), message "ZONE_REPAIRED" (rouge) ou "ZONE_GROUP_REPAIRED" (bleu), trigger `repaired`, `world.removeJunk` sur la sphère de la zone, rafraîchissement du libellé, puis arrêt (`zc2:56919-56985`, `zc2:56873-56882`) ;
- si rien ne nécessitait de réparation et que tous les emplacements sont pleins → "ZONE_ALREADY_FULLY_UPGRADED" (bleu seulement), renvoie false (`zc2:56990-56995`) ;
- sinon le premier emplacement manquant est spawné (groupe via `_spawnBuiltGroup`, static via `SPAWNSTATIC:NewFromTemplate(...):SpawnFromCoordinate` → `coalition.addStaticObject`), message "ZONE_UPGRADED_COUNT" n/total (bleu) ou "ZONE_DEFENSES_UPGRADED" (rouge, aussi montré au bleu en PvE), trigger `upgraded` (`zc2:56997-57089`).

Qui appelle `upgrade()` : chaque livraison de supply réussie vers une zone amie (vol de supply IA ou convoi, crate de supply de joueur, crate pré-placée — `zc2:55236-55248`, `zc2:69981-69985`), la capture elle-même (un cran, `zc2:56702-56707`), les travaux de « récupération locale » du supply régulier (autre thème : logistique), les commandes d'admin, et les boucles « jusqu'à complétion » ci-dessous.

Boucles « jusqu'à complétion », toutes construites sur un `timer.scheduleFunction` qui se reprogramme lui-même et s'arrête dès que la zone change de camp :

- `ZoneCommander:UpgradeUntilComplete(onComplete, delaySeconds)` : renvoie false immédiatement quand rien n'est endommagé ni manquant ; sinon, à partir de 1 s plus tard puis toutes les `delaySeconds` (2 s par défaut), chaque étape respawne soit un groupe endommagé (`RespawnZoneRepairTarget`), soit, quand aucun n'est endommagé, appelle `upgrade(true)` pour un emplacement manquant ; `onComplete(zone)` est appelé après la dernière étape (`zc2:50822-50856`).
  Son seul appelant dans le setup du Caucase est l'article de boutique `supplies` (« fully upgrade zone ») (`setup:4017-4035`).
- `ScheduleZoneUpgradeUntilComplete(zone, …)` (local) : variante upgrade seul (sans réparation), un `upgrade(true)` silencieux toutes les 2 s jusqu'à ce que `built` soit aussi long que la liste d'upgrades filtrée ; utilisée par `MakeZoneRedAndUpgrade` et les deux variantes `AwakenZone…` (`zc2:50494-50513`, `zc2:50518`, `zc2:50628`, `zc2:50637`).
- `upgradeRedZones()` / `upgradeBlueZones()` (marqueurs d'admin `upgradeallred` / `upgradeallblue`) : collectent chaque zone visible et éveillée du camp qui a besoin d'une réparation ou d'un emplacement, puis les traitent l'une après l'autre, à 10 s d'intervalle, chacune avec sa propre boucle réparation-ou-upgrade de 2 s ; un flag d'occupation refuse un second lancement et « all zones fully upgraded » est affiché à la fin (`zc2:50858-50975`).

### Notes de reproduction

La détection des pertes se fait par scrutation, pas par événements : aucun handler `S_EVENT_DEAD` n'alimente `built`.
Le coût du balayage est borné par l'étalement (0,1 s entre zones, période de maintenance de 30 s répartie sur les ticks) et par le saut des zones suspendues.
Un groupe est réparé en le détruisant puis en le respawnant à pleine force dans sa sous-zone mémorisée, pas en ressuscitant les unités.

## 5. Perdre une zone : neutralisation, désactivation, objets critiques

### Ce que voit le joueur

Une zone ne change jamais de mains directement : elle devient d'abord neutre quand son dernier emplacement de garnison disparaît, puis quelqu'un doit la capturer.
Messages à la neutralisation (si `GlobalSettings.messages.zonelost`, zone non cachée) : l'ancien propriétaire lit "We have lost <zone>!" (« Nous avons perdu <zone> ! »), l'autre camp "<zone> is now neutral" (« <zone> est maintenant neutre »), et tout le monde entend `ding.ogg` (`zc2:55370-55376`, `l10n:1414-1415`).
Le cercle de la zone et ses libellés passent au gris (`zc2:55402-55407`).
Certaines zones « disparaissent » à la place : après la perte, elles sont dessinées presque en noir et annoncent "<zone> has been destroyed" (« <zone> a été détruite ») (`zc2:50242-50256`, `l10n:1419`).

### Mécanisme — `_neutralizeEmptyBuiltZone` (`zc2:55294-55451`)

Déclencheur : dans `ZoneCommander:update`, `next(self.built) == nil` sur une zone active possédée (`zc2:55184-55188`).
Effets, dans l'ordre : escalade de la difficulté si le perdant est la « coalition de difficulté » (`zc2:55297-55299`) ; `side = 0` ; tous les flags de dormance effacés ; le Director est informé (`Director:recordZoneOwnershipChange`) ; les supplies d'advance capture retenus pour cette zone sont libérés (`zc2:55337`) ; les triggers `lost` s'exécutent (`zc2:55341`) ; `bc:buildConnectionMap(zone, previousSide)` ; le calque de territoire et les lignes de connexion de cette zone sont redessinés ; le rafraîchissement du menu de statut des zones et du front est demandé (`zc2:55342-55351`) ; les sous-zones utilisées sont libérées (`zc2:55354-55355`) ; l'aérodrome DCS passe à la coalition 0, ses statics de slot sont respawnés neutres, ses armements d'entrepôt vidés quand la logistique d'entrepôt est activée (`zc2:55356-55368`) ; les zones CTLD sont réévaluées (`addCTLDZonesForBlueControlled`), `SpawnFriendlyAssets(zone)` est programmé 2 s plus tard, les seaux de spawn CAP reconstruits 5 s plus tard, la difficulté rouge rééquilibrée (`zc2:55433-55450`).
Une zone de porte-avions qui devient neutre avec la logistique d'entrepôt activée est désactivée à l'ère Vietnam, ou recapturée automatiquement par le bleu après 5 s sur les cartes autres que le Caucase (avec une exception pour le golfe Persique) (`zc2:55377-55400`).

### Mécanisme — désactivation

`ZoneCommander:disableZone(silent)` détruit chaque groupe/static construit et les statics critiques, pose `side = 0` et `active = false`, exécute les triggers `destroyed`, reconstruit le graphe de connexions et redessine (`zc2:50185-50270`).
Une zone inactive est sautée par `update()` (`zc2:55147`), ne peut pas être capturée (`capture()` exige `active`, `zc2:56559` ; une tentative de capture affiche "<zone> has been destroyed and can no longer be captured" (« <zone> a été détruite et ne peut plus être capturée »), `zc2:56793-56802`), et est dessinée sombre (`zc2:51402-51405`).
Elle est appelée (a) par `checkCriticalObjects` quand tous les statics de `criticalObjects` sont morts (scruté dans la passe de maintenance, `zc2:55742-55744`, `zc2:51904-51930`), (b) par les triggers `lost` du fichier de setup pour les zones à usage unique, par exemple les grilles d'insurrection qui versent aussi 500 crédits au bleu (`setup:2725-2729`).
`checkAndDisableFriendlyZones()` n'appelle pas `disableZone` : c'est un hook facultatif du fichier de setup que `capture()` invoque après chaque capture quand ce global existe (`zc2:56686-56688`).
Dans le setup du Caucase, c'est une fonction vide (`setup:2048-2049`) ; les autres cartes s'en servent pour passer au rouge des zones de réserve cachées (`MakeZoneRedAndUpgrade`) ou les détruire (`DestroyHiddenZone`) selon les zones nommées qui sont bleues, et la programment aussi une fois 3 à 10 s après le démarrage (`COLDWAR_SETUP.lua:2302-2333`, `foothold pg nya v2.lua:1627-1647`, `IRAQ_SETUP.lua:1411-1424`).
`RecaptureBlueZone()` est l'inverse de la désactivation, accessible seulement depuis le marqueur d'admin `recapture` : sur une zone inactive, elle pose `active = true`, invalide le cache de menace SAM des CAP et, 2 s plus tard, appelle `capture(2, true)` ; sur une zone active, elle ne fait rien (`zc2:50977-50992`, `zc2:29149-29155`).
`DestroyHiddenZone()` est la variante pour les zones cachées : pas de messages, pas de dessin (`zc2:50146-50183`).

### Notes de reproduction

« Neutre » est un véritable troisième état, avec sa propre liste de garnison (vide) et sa propre coalition d'aérodrome ; la capture automatique des aérodromes de DCS est coupée à l'init pour que DCS ne contredise jamais le script (`zc2:51439`).
Les triggers sont de simples callbacks stockés sur la zone avec une limite facultative du nombre d'exécutions (`zc2:50064-50084`).

## 6. Capturer une zone neutre — les canaux

`ZoneCommander:capture(newside, silent)` n'agit que lorsque la zone est active et neutre (`zc2:56559`).
Hors commandes d'admin, personne ne l'appelle directement : chaque canal passe par `startPendingCapture` (section 7), qui appelle `capture` à la fin de son timer (`zc2:47081`).

| Canal | Qui | Code |
|---|---|---|
| Un hélicoptère ou un avion de supply IA se pose dans une zone neutre | Les vols de supply IA des deux camps, y compris ceux achetés dans la boutique (« capture mission ») | `zc2:67826-67840` (chemin d'atterrissage), `zc2:69943-69957` |
| Un convoi de supply IA terrestre ou naval s'arrête dans une zone neutre | Les deux camps | `zc2:69958-69971`, `zc2:70067-70102` |
| Troupes CTLD de joueur déployées dans une zone neutre | Pilotes d'hélicoptère/de transport bleus (et rouges en PvP) | `ctld:9263-9290` |
| Crate CTLD « zone supply » de joueur larguée/déchargée dans une zone neutre | Bleu ; équivalent rouge | `ctld:5316-5349`, `ctldred:2160` |
| « Internal supplies » de joueur déchargés depuis le menu de logistique | Joueurs, les deux camps | `zc2:98238-98268` |
| Largage Hercules d'un conteneur de supply | Joueurs | `zc2:102378-102400` |
| Crate static pré-placée (`crates = {...}`) posée au sol dans la zone | Créateur de mission / sling load | `zc2:55206-55235` |
| Groupe terrestre de mission d'escorte bleue atteignant une zone cible neutre | Mission « Escort » | `zc2:104187-104213` |
| Article de boutique « capture »/« emergency capture » → `requestCaptureMission` | Bleu (ou le camp acheteur en PvP) | `zc2:23416-23569` |
| Article de boutique « advance capture » (supply pré-positionné retenu jusqu'à la chute de la zone) | Bleu | section 8 |
| Marqueurs F10 d'admin sur la carte `capture:1`, `capture:2`, alias | Administrateur du serveur | `zc2:29172-29202` |
| Recapture automatique d'un porte-avions | Moteur | `zc2:55385-55397` |

`requestCaptureMission(zone, options)` choisit le meilleur `GroupCommander` de supply pour cette cible (`_selectShopSupplyCommander`), le rebase éventuellement sur un FARP plus proche, force son état à `preparing` avec `urgent = true`, et annonce "looking for pilots" (« à la recherche de pilotes »), un départ de convoi ou un message d'« emergency capture » ; le vol capture ensuite par le canal normal d'atterrissage IA (`zc2:23436-23568`).
Elle refuse une zone qui a déjà une capture temporisée et une zone non neutre, sauf si l'appel est une advance capture sur une zone rouge active et éveillée (`zc2:23420-23431`).

### Ce que fait `capture()` (`zc2:56557-56818`)

- Annule toute capture temporisée, pose `side`, efface la dormance et l'état de reddition, informe le Director (`zc2:56558-56600`).
- Marque comme sales tous les caches dérivés : cibles CAP, filtre de groupes FSM, réindexation de combat, cache de supply, seaux du sélecteur de boutique, bases de chasse (`zc2:56603-56606`, `zc2:56671-56672`).
- Enregistre l'heure de la capture pour la logique « réactive » du rouge quand le bleu a capturé (`zc2:56611-56616`).
- Recolore la forme de la carte et les libellés (`zc2:56655-56658`), dessine un contour vert en pointillés si la zone est bleue et a un spawn aérien (`zc2:56750-56753`).
- Programme `SpawnFriendlyAssets(zone)` (+2 s) et réévalue les zones CTLD (`zc2:56642-56654`).
- Exécute les triggers `captured` (`zc2:56659`).
- Reconstruit le graphe de connexions, redessine la cellule de territoire et les lignes de connexion de cette zone, demande un rafraîchissement du front et un repositionnement de l'AWACS (+15 s), interrompt les vols de supply ennemis qui se dirigent encore vers la zone (+10 s) (`zc2:56665-56684`).
- Message à tous "<zone> captured by RED|BLUE" (« <zone> capturée par RED|BLUE ») si `GlobalSettings.messages.captured` (`zc2:56696-56700`, `l10n:1417`).
- Fait spawner le premier emplacement de garnison avec `self:upgrade()` ; le reste arrive par le supply (`zc2:56702-56707`).
- Sur une capture bleue, laisse le Director rouge envisager de détourner du CAS vers la zone (`zc2:56708-56710`).
- Pour une zone avec aérodrome : `Airbase:setCoalition(side)`, `RespawnStaticsForAirbase(airbase, side)` (les statics de slot), et un `S_EVENT_BASE_CAPTURED` synthétique poussé via `world.onEvent` pour que les autres scripts réagissent (`zc2:56754-56770`).
- Sur une capture neutre→bleu, 1 s plus tard, chaque joueur bleu posé dans la zone avec une contribution en attente reçoit un `S_EVENT_LAND` synthétique pour que la récompense soit encaissée sans redécoller (`zc2:56713-56748`).
- Les groupes IA basés dans la zone qui sont `inhangar`/`dead` reçoivent un nouveau délai de départ aléatoire (30 s si urgent, sinon 60 s à `initialDelayVariance` minutes) (`zc2:56775-56785`).
- Seaux de spawn CAP reconstruits, menu de contrôle dynamique rafraîchi, difficulté diminuée si le capteur est la coalition de difficulté (`zc2:56786-56791`).

Les récompenses de capture sont versées par le handler de livraison du participant, pas par `capture()` (section 7).

## 7. Capture temporisée (la capture prend du temps)

### Ce que voit le joueur

Amener dans une zone neutre quelque chose qui peut capturer lance un compte à rebours ; le camp du premier livreur lit "Capturing <zone>..." (« Capture de <zone>... »), l'ennemi (le bleu seulement en PvE) lit "Enemy is capturing <zone>" (« L'ennemi capture <zone> ») avec `Intel_short.ogg` (`zc2:46781-46795`, `l10n:1375-1376`).
Pendant le compte à rebours, le remplissage gris neutre vire vers la couleur du camp capteur en 4 paliers (20/40/60/80 %) et le libellé de la zone est rafraîchi chaque seconde (`zc2:46730-46763`, `zc2:46772-46779`, `zc2:45876-45881`).
La capture réussit à la fin du timer si au moins un participant est encore vivant dans la zone ; elle est annulée quand tous les participants sont perdus.

### Ce que règle le créateur de mission

`ZoneCaptureBuildSeconds = 120` dans le fichier de Config ; 0 rend la capture immédiate (`config:1284`, `zc2:45866`, `zc2:47035-47038`).

### Mécanisme

État : `zone.pendingCapture = { side, startedAt, completeAt, participants = {name → participant}, nextJoinOrder }` (`zc2:47019-47032`).
Un participant est `{kind = 'group'|'static', name, template, position, heading, unitTypes, staticType, country, destroyOnFinish, tombstone, retireAction, delivery = {handler, payload}, joinOrder}` (`zc2:46999-47012`).
`startPendingCapture(side, request)` refuse : un camp invalide, une zone non active ou non neutre, une zone dont une capture est en cours de restauration depuis la sauvegarde, et un participant de l'autre camp tant qu'une capture est en cours (« reserved ») (`zc2:46986-46997`).
Un second participant du même camp rejoint la capture en cours sans remettre le timer à zéro (`zc2:47030-47050`).
`stopGroup = true` fige un groupe terrestre avec `trigger.action.groupStopMoving` (`zc2:47044-47047`).
Pour les aéronefs IA, `startPendingCaptureFromAircraft` fait spawner une petite équipe d'infanterie (« CTLD_TROOPS_ATS » / « CTLD_TROOPS_RED_Squad_8 », variantes Normandie) 20 m ou plus derrière l'aéronef posé avec `SPAWN:NewWithAlias(...):InitCoalition(side):SpawnFromVec2` et enregistre ce groupe comme participant ; l'aéronef est libre de repartir (`zc2:46797-46846`, `zc2:46765-46770`).
Pour les supplies portés par un joueur et les largages Hercules, `startPendingCaptureWithCargoStatic` crée un static de cargo (`coalition.addStaticObject`, catégorie `Cargos`, type `ammo_cargo` ou `iso_container_small`) et l'enregistre (`zc2:46848-46877`, `zc2:102383-102387`).
`_updatePendingCapture(now)` s'exécute à chaque mise à jour de zone (10 s) : retire les participants morts ou hors zone (`Utils.someOfGroupInZone` pour les groupes, `Utils.isInZone` pour les statics), annule quand il n'en reste aucun, termine quand `now >= completeAt` (`zc2:47098-47125`, `zc2:46879-46937`).
`_completePendingCapture` appelle `capture(side)`, puis pour chaque participant dans l'ordre d'arrivée : les participants après le premier appliquent une livraison de supply supplémentaire (c'est-à-dire un cran d'upgrade), le handler de livraison est appelé avec `succeeded`, l'objet participant est détruit si `destroyOnFinish`, le commandant IA est renvoyé au hangar, et une entrée « tombstone » garde le nom réservé pendant 900 s (`zc2:47065-47096`, `zc2:46964-46984`, `zc2:45867`).
Les handlers de livraison sont enregistrés par nom avec `bc:registerPendingCaptureHandler(name, fn)` ; le `zonecommander_capture_delivery` du moteur verse `captureFundReward` (par défaut `rewards['Zone capture']` ou 200) au joueur ou à la coalition du premier participant, `upgradeFundReward` (par défaut 100) aux participants qui rejoignent, ajoute du stock d'entrepôt, et enregistre les statistiques de carrière (`zc2:24675-24739`, `zc2:98260-98261`, `zc2:30233-30235`).
CTLD enregistre ses propres handlers `blue_ctld_capture_delivery` et `blue_ctld_troop_capture` (`ctld:5340`, `ctld:9277`).
Les captures temporisées sont sauvegardées et restaurées (`_serializePendingCapture`, `_restorePendingCapture`, `zc2:47127-47199` ; le format relève du thème de la persistance).

### Notes de reproduction

La capture est ancrée sur un objet physique qui peut être tué, ce qui la rend contestable.
La période de vérification est le tick de zone (10 s), donc la durée effective est `ZoneCaptureBuildSeconds` arrondie au tick suivant.
Les convois terrestres IA rouges attendent 60 s avant d'agir quand un joueur bleu est à moins de 5 NM de la cible (`BlueIsNear`) (`zc2:70080-70087`, `zc2:37149-37151`).

## 8. Advance capture

### Ce que voit le joueur

Le bleu peut acheter une « advance capture » sur une zone rouge qui a été usée : un vol ou un convoi de supply est envoyé tôt, attend près de la zone, et est libéré pour capturer dès que la zone devient neutre.
Le bleu lit "Advance Capture is now available for <zone>." (« L'advance capture est maintenant disponible pour <zone>. ») quand une zone devient éligible (`zc2:17631-17647`, `l10n:574`).

### Ce que règle le créateur de mission

`AdvanceCaptureRemainingThreshold` (0,50 par défaut, accepté comme ratio ou comme pourcentage, borné entre 0,20 et 0,60) : la zone est éligible quand son ratio construit/total est tombé à cette valeur ou en dessous (`zc2:50106-50110`).
`AdvanceCaptureAbortRemainingThreshold` (0,90 par défaut) : si la zone est réparée au-dessus de ce ratio, les supplies retenus sont renvoyés chez eux ou annulés (`zc2:55489-55501`, `zc2:60205-60292`).

### Mécanisme

Éligibilité (`zc2:50100-50142`) : zone active, non suspendue, non cachée, rouge, sans trigger `lost`/`destroyed` autre que celui de fin de mission, « armed » (son ratio a été vu au-dessus du seuil au moins une fois depuis qu'elle est devenue rouge), ratio > 0 et ≤ seuil.
Recalculée à chaque passe de maintenance (pas sur Normandie) (`zc2:56027-56029`, `zc2:55453-55488`) ; un changement met à jour le seau du sélecteur de boutique `advance_capture_targets` et met en file le message de disponibilité.
L'achat appelle `requestCaptureMission(zone, {advanceCapture = true})`, qui pose `_advanceCaptureWaitingForNeutral` sur le commandant de supply choisi (`zc2:23494-23498`) ; les zones de porte-avions sont refusées (`zc2:23426-23428`).
Quand la zone est neutralisée, `_releaseAdvanceCaptureHeldSupply(zone)` redirige les hélicoptères/avions/convois en attente pour qu'ils se posent ou entrent par la route (`zc2:55337`, `zc2:60041-60075`).
### Mécanisme — routes d'attente, de libération et d'abandon

Le point d'attente est toujours « à 80 % du chemin, mais jamais plus près de la cible qu'une distance minimale » : `holdDistance = min(0.8 × L, L − dmin)`, 0 quand `L ≤ dmin`, avec `dmin` = 25 NM pour les avions, 10 NM pour les hélicoptères, 4 NM de distance routière pour les convois (`zc2:57939-57955`, `zc2:59785-59801`, `zc2:58616-58624`, `zc2:68909-68918`).
Le point est stocké dans `gc._advanceCaptureHold = {x, z, aglM|altitude}` et persisté, de sorte qu'un vol restauré revient au même point d'attente (`zc2:57996`, `zc2:59849`, `zc2:25485-25492`, `zc2:29759`).

`_assignAdvanceCaptureHoldRoute` aiguille selon le type de porteur (`zc2:59447-59468`) :

| Porteur | Route d'attente | Code |
|---|---|---|
| Avion | Deux waypoints bruts poussés avec `GROUP:Route` : un point de décollage, puis un point tournant en survol au point d'attente portant `ComboTask{ Orbit{pattern = CIRCLE, point, speed = 250 kt IAS converted to TAS, altitude = cruise altitude BARO} }`. | `zc2:57922-58007` |
| Hélicoptère, sans cargo | Position actuelle → les waypoints de transit de supply habituels arrêtés au point d'attente → un point tournant « Advance Capture Hold » à 200 m AGL portant une tâche `Orbit` avec `pattern = "Race-Track"`, `speed = 0` (un vol stationnaire). | `zc2:59776-59850`, `zc2:58083-58097` |
| Hélicoptère, sling load (`WarehouseLogistics` et `SuppliesCargoTransport` activés, pas `NotCargo`) | Idem, précédé d'un waypoint dont la tâche est la prise de cargo (`ExternalCargoLoad`) d'un conteneur de 600 kg tout juste spawné ; la libération n'est pas permise avant 120 s après la pose de la route, et est forcée après 600 s même si l'hélicoptère n'a jamais signalé avoir atteint le point d'attente. | `zc2:59439-59463`, `zc2:58640-58705` |
| Hélicoptère, cargo interne | La route de logistique de cargo interne (même fonction qu'une livraison normale). | `zc2:59451-59454` |
| Convoi terrestre / naval | La route de supply routière normale (`dc.GetSupplyConvoyRoute`) est copiée en profondeur et coupée à la distance d'attente mesurée le long de ses segments ; le dernier point est déplacé à la position d'attente et perd sa tâche, de sorte que le convoi s'y arrête simplement. | `zc2:68871-68954`, `zc2:68974-68979` |

Libération, `_releaseAdvanceCaptureHeldSupply(zoneName)`, appelée depuis `_neutralizeEmptyBuiltZone` (`zc2:60041-60203`) :

- chaque commandant de supply ayant `_advanceCaptureWaitingForNeutral` et cette cible est redirigé : un avion reçoit le `_assignPlaneRoute` ordinaire vers la zone, un hélicoptère reçoit sa route de déchargement et d'atterrissage (sling load, cargo interne) ou le simple `_assignHeloRoute`, un convoi reçoit une nouvelle route routière depuis sa position actuelle (`dc.BuildSupplyConvoyRouteFromPoint`) poussée 1 s après un `controller:popTask()` (`zc2:60129-60196`, `zc2:59503-59527`) ;
- un hélicoptère en sling load n'est libéré que lorsque `_advanceCaptureExternalCargoCanRelease` est vrai : le délai de 120 s est écoulé **et** l'unité de tête a été vue à moins de 1 NM du point d'attente, ou le repli de 600 s a expiré ; sinon la libération est retentée à chaque mise à jour en vol de ce groupe tant que la cible est neutre ou amie (`zc2:59995-60025`, `zc2:60142-60163`, `zc2:67623-67652`) ;
- la même fonction fait aussi faire demi-tour aux groupes de supply qui rentraient déjà chez eux après un abandon (`_supplyReturnHome`) et les envoie vers la zone (`zc2:60045-60127`).

Si la zone est déjà neutre ou amie quand l'achat est traité, `_assignAdvanceCaptureOpenRoute` saute l'attente et assigne directement la route de livraison normale (`zc2:59470-59501`).

Abandon, `_abortAdvanceCaptureHeldSupply(zoneName, ratio)`, appelé quand la zone a été réparée au-dessus de `AdvanceCaptureAbortRemainingThreshold` (`zc2:60205-60292`) : un vol en l'air est routé de retour vers sa propre zone avec `_supplyReturnHome = true` ; un vol encore en `takeoff` est détruit avec son cargo et renvoyé au hangar ; un convoi encore en `preparing` retourne au hangar ; un convoi en `enroute` reçoit une route routière de retour.

## 9. Dormance des zones : suspension par distance, suspension « idle », réveil

### Ce que voit le joueur

Les joueurs ne voient pas la dormance directement : une zone suspendue garde sa couleur, son libellé et son propriétaire, mais sa garnison n'existe pas dans le monde.
Une zone se réveille quand un joueur ennemi arrive à moins de `proximityWakeNm`, quand le front se rapproche, ou quand une mission IA la cible ou la survole.
Le marqueur d'admin sur la carte `whynot` affiche la décision de suspension de la zone qu'il recouvre (`zc2:28918-28922`).
`explainSuspendDecision(zoneName, groupId)` affiche un texte de 25 s au groupe (ou à tous) (`zc2:37219-37392`).
Avec la suspension « idle » activée et un enregistrement de décision mémorisé, elle affiche cet enregistrement : état (`idle` / `normal` / `awake`), âge de la décision, distance à l'ennemi le plus proche par rapport aux limites complète et « idle », et un booléen par blocage (`idleCandidate`, `normalSuspend`, `nearbyHold`, `settlingHold`, `attackHold`, `eventHold`, `committed`, `playerObjective`, `incomingSupply`, `canReceive`, `supplierHold`, `playerHold`, `jtacHold`, `farpHold`, `carrierHold`, `neighborHold`, `criticalHold`, `reactiveHold`, `startupRestore`, `sa5Hold`, `noIdleSuspend`) (`zc2:37222-37235`).
Sinon elle recalcule la décision sur-le-champ avec les mêmes entrées que `_autoZoneSuspend` (elle appelle `reindexCombatZones(true, true)` pour obtenir aussi les sources textuelles) et affiche la distance, la limite, les flags de voisins, le test de réveil de zone neutre, le supply entrant/recevable, la liste des propres groupes d'attaque/de patrouille de la zone qui la maintiennent active comme origine, les listes de groupes qui en font une cible active, et le verdict `=> shouldSuspend=` (`zc2:37244-37391`).

### Réglages

| Réglage | Défaut dans le moteur | Setup du Caucase | Signification | Où |
|---|---|---|---|---|
| `GlobalSettings.autoSuspendNmBlue` | 80 | 70 (PvE), 100 (PvP) | Une zone bleue plus éloignée que cette valeur de la zone ennemie active la plus proche est suspendue. | `zc2:8526`, `setup:6063-6069` |
| `GlobalSettings.autoSuspendNmRed` | 120 | 95 (PvE), 100 (PvP) | Idem pour les zones rouges. | `zc2:8527`, `setup:6064-6069` |
| `zone.customSuspendNm`, `customSuspendNmRed`, `customSuspendNmBlue` | — | 1000 sur deux sites SAM de base arrière en PvP | Surcharge de la limite par zone. | `zc2:37520-37523`, `setup:989-992` |
| `GlobalSettings.neutralWakeFactor` | 0.5 | — | Rester éveillée si une zone neutre se trouve à moins de limite × facteur. | `zc2:8528`, `zc2:37763` |
| `GlobalSettings.proximityWakeNm` | 40 | 50 (PvP) | Distance d'un joueur ennemi qui réveille une zone. | `zc2:8524`, `zc2:37103` |
| `GlobalSettings.proximityWakeHoldSeconds` | 600 | — | Durée de maintien d'un réveil par proximité. | `zc2:8525`, `zc2:37142` |
| `GlobalSettings.idleZoneSuspendEnabled` | true | — | Active le second niveau de sommeil, « idle ». | `zc2:8464` |
| `GlobalSettings.idleZoneSuspendFactor` | 0.5 | — | Le sommeil « idle » s'applique au-delà de limite × facteur. | `zc2:8465`, `zc2:37810` |
| `GlobalSettings.idleZoneWakeHoldSec` | 120 | — | Durée minimale d'éveil après un réveil « idle », et délai d'expiration d'une restauration de réveil. | `zc2:8466`, `zc2:35709`, `zc2:48011` |
| `zone.noIdleSuspend` | — | true sur les deux mêmes sites SAM | Ne jamais suspendre cette zone en « idle ». | `zc2:37804` |
| `GlobalSettings.builtMaintenanceNormalSec` / `SlowSec` / `SlowFactorBlue` / `SlowFactorRed` | 30 / 60 / 0.50 / 0.80 | — | Paliers de période de balayage de la garnison (ci-dessous). | `zc2:37527-37531` |

### Mécanisme — la décision (`BattleCommander:_autoZoneSuspend`, toutes les 60 s, premier passage à +1 s)

Programmée par `SCHEDULER:New(self, …, {}, 1, 60)` dans `bc:init()` ; `_proximityWakeSuspendedZones` tourne sur son propre scheduler de 60 s à partir de +10 s (`zc2:30291-30292`).
Les zones cachées et les zones de porte-avions ne sont jamais considérées (`zc2:37752`).
Pour chaque zone possédée et active, elle calcule (`zc2:37753-37834`) :

- `dist` : distance en NM à la zone ennemie éveillée ou suspendue « idle » la plus proche, d'après la matrice précalculée `ZONE_DISTANCES` (`zc2:37555-37576`) ; les zones bleues ignorent les zones rouges « Popup » et les zones rouges qui ne peuvent ni spawner ni attaquer (`zc2:35032-35037`, `zc2:37446-37462`) ;
- `hasOppositeNeighbor`, `hasNeutralNeighbor` : d'après le graphe de connexions (`zc2:37662-37689`) ;
- `neutralHalfWake` : une zone neutre à moins de limite × `neutralWakeFactor` (les zones neutres au départ ne comptent pas pour le rouge) (`zc2:37577-37591`, `zc2:37763`) ;
- `combat` / `originActive` : la zone est la cible ou l'origine d'une attaque/patrouille IA vivante (d'après `reindexCombatZones`) (`zc2:37463`, `zc2:37764-37765`) ;
- `incoming` : un groupe de supply vivant s'y dirige ; `canReceive` : elle a une demande de supply non satisfaite (`zc2:37699-37721`, `zc2:37617-37645`) ;
- blocages : JTAC actif sur la zone, réveil par proximité de joueur encore valide, lien de navigation de porte-avions, un FARP dynamique à moins de 20 NM, objets critiques présents, pression « réactive » du rouge (`zc2:37778-37791`).

`shouldSuspend` = aucun des blocages, aucun voisin ennemi ou neutre, aucun combat, aucun supply entrant, ne peut pas recevoir de supply, et `dist > limit` (`zc2:37802`).

`reindexCombatZones(includeSources, useAutoSuspendEnemyReferences)` reconstruit de zéro, à chaque appel, les deux ensembles utilisés ci-dessus, `_activeAttackOrPatrol[zoneName]` (les zones qui sont une cible vivante) et `_activeOrigin[zoneName]` (les zones qui sont une origine vivante) (`zc2:35040-35228`).
Il parcourt, pour chaque zone, une liste en cache de ses commandants de groupes d'attaque/de patrouille (`_getReindexCombatCache`) et calcule pour chacun : `live` (état autre que `inhangar`/`dead`), `spawnable` (le résultat en cache de la porte d'éligibilité au spawn), `directorReserved` (le Director retient le groupe pour une opération), et `sideValid` (patrouille : origine et cible du même camp ; attaque : cible possédée par l'autre camp et non neutre) (`zc2:35074-35103`).
Un enregistrement compte quand il a une raison (`spawnable`, `live` ou `director-reserved`) et qu'il est valide côté camp ou vivant : un enregistrement d'attaque marque son origine active et, si la cible est active, visible, possédée et éveillée ou suspendue « idle », sa cible active ; un enregistrement de patrouille marque les deux seulement quand la zone patrouillée est dans sa propre limite de suspension d'une zone ennemie (`zc2:35120-35170`).
Les capacités passives du Director (`directorPassiveCombatByOrigin[origin].attack/.patrol`, comptes par cible) ajoutent les mêmes marques sans groupe vivant (`zc2:35184-35222`).
Effets de bord : un groupe en route vers sa base réveille à nouveau les zones « idle » de son empreinte de retour, et un groupe engagé réveille à nouveau l'empreinte de sa cible (`_wakeIdleMissionZones`) (`zc2:35105-35118`).
Il renvoie le cache de distance à l'ennemi le plus proche par zone et l'ensemble des noms de cibles « engagées », que le test de suspension « idle » utilise (`zc2:35227`).
Avec `includeSources`, il remplit aussi `_activeAttackOrPatrolSources` / `_activeOriginSources` avec une ligne de texte par groupe contributeur, pour l'explication de `whynot` (`zc2:35043-35044`, `zc2:35133-35136`).
Sinon une zone suspendue est mise en file pour reprise (`zc2:37841-37848`).
Règles de réveil supplémentaires : jusqu'à deux voisines suspendues de chaque zone neutre sont réveillées si elles ont une raison d'agir (`zc2:37723-37749`) ; les zones rouges à moins de 12 NM (5 NM sur Normandie) d'une zone rouge éveillée sont maintenues éveillées ensemble (`zc2:37857-37909`) ; une zone avec un radar GCI bleu endommagé est toujours réveillée (`zc2:37503-37506`, `zc2:37914`).

La suspension « idle » est un second niveau, plus léger, décidé dans la même passe : une zone qui n'est pas due pour la suspension complète mais qui est plus loin que limite × `idleZoneSuspendFactor`, sans blocage, sans cible IA engagée, sans objectif de joueur (`ActiveCurrentMission`), sans demande de supply, sans menace de poursuite SA-5, et pas près d'une zone amie occupée, est endormie avec `suspend(true)` (`zc2:37804-37818`, `zc2:37923-37943`).
Les nouveaux sommeils « idle » sont différés jusqu'à ce que la première passe soit terminée et que l'IA sauvegardée ait été restaurée (`zc2:37486-37488`).
Chaque zone garde l'enregistrement complet de la décision dans `_idleSuspendDecision` pour l'explication d'admin (`zc2:37819-37834`, `zc2:37931-37936`).

La même passe fixe la période de balayage de la garnison de chaque zone éveillée : 10 s (la fréquence de mise à jour) sous toute pression ou quand elle n'est pas entièrement construite, 60 s quand elle est stable et plus loin que limite × 0,5 (bleu) ou × 0,8 (rouge), sinon 30 s (`zc2:37785-37801`).

### Mécanisme — réveil par proximité (`_proximityWakeSuspendedZones`, toutes les 60 s)

Prend un instantané de tous les joueurs des deux camps avec leur position (`getPlayerSnapshot`), et pour chaque zone possédée teste la distance 2D au carré de chaque joueur ennemi au centre de la zone (`zc2:37071-37139`).
À moins de `proximityWakeNm` : `_proximityWakeUntil = now + hold` et `resume()` si suspendue (`zc2:37141-37147`).
Il pose aussi, pour les zones rouges connectées au territoire bleu, `BlueIsNear` (un joueur bleu à moins de 5 NM) et `BluePlaneIsNear` (un avion bleu à moins de 15 NM), utilisés pour retarder les atterrissages de supply rouges et bloquer les spawns (`zc2:37104-37154`).
La même boucle rafraîchit `bc.playersState` (latitude/longitude de chaque joueur) pour l'export de statut externe (`zc2:37090-37097`).

### Mécanisme — réveil « idle » par les missions IA

`_wakeIdleMissionZones(owner, target, routePoints, threatView)` construit une « empreinte » pour un groupe IA : la zone cible, ses voisines du même camp dans le rayon de zone proche, et toute zone dont le cercle de menace SAM touche la cible ou un tronçon de la route ; chacune reçoit `_idleWakeUntil = now + 120 s` et est reprise si elle est suspendue « idle » ; la fonction ne renvoie true que lorsque toutes sont éveillées, de sorte que les lancements l'attendent (`zc2:35649-35715`).
Les appelants sont les constructeurs de routes IA et la boucle de supply (`zc2:35321`, `zc2:35412`, `zc2:37713-37717`).

### Mécanisme — `suspend` et `resume`

`ZoneCommander:suspend(idle)` (`zc2:47748-47852`) : garde dans une liste à part les groupes IA actuellement vivants pour qu'ils continuent d'être mis à jour ; prend un instantané de la garnison sous la forme `remainingUnitsSnapshot[slot] = {unit type names}` (unités vivantes seulement pour une suspension « idle ») et, pour les groupes fixed hidden, des noms d'unités ; puis détruit chaque groupe construit avec `Group:destroy()` et consigne son nom dans `_hibernated` ; `built` garde les noms d'emplacements ; les groupes radar GCI/EWR bleus ne sont jamais détruits (`IsSuspensionPersistentRadarTemplateName`).
Les statics ne sont pas touchés.

`ZoneCommander:resume()` (`zc2:47901-48084`) ne spawne pas immédiatement : il met en file un travail dans une file de réveil globale servie par un seul worker qui effectue **une étape toutes les 0,1 s**, et une étape spawne **un groupe** (`zc2:47854-47899`, `zc2:47941-48004`).
Après le dernier groupe : `suspended = false`, puis `weedOutRemainingUnits` élague chaque groupe respawné jusqu'à l'instantané (de sorte que les pertes subies avant le sommeil sont préservées), les caches sont salis, le libellé est rafraîchi (`zc2:48024-48080`).
Si certains groupes ont échoué à spawner, le travail est retenté 2 s plus tard ; un réveil « idle » qui ne peut pas se terminer dans `idleZoneWakeHoldSec` est abandonné (`zc2:48009-48023`).
Une zone restaurée depuis une sauvegarde comme suspendue démarre avec `_persistedHibernatedSlots` et est traitée de la même façon (`zc2:51504-51545`, `zc2:47936-47975`).

Effets d'être suspendue ailleurs : pas de balayage de garnison, pas de traitement des crates, pas de rafraîchissement des groupes restreints (`zc2:55169-55174`) ; en PvE une zone bleue entièrement (pas « idle ») suspendue ne rapporte aucun revenu (`zc2:55160`) ; `getFilteredUpgrades` ne renvoie que les emplacements présents dans l'instantané (`zc2:48345-48364`) ; la zone n'est pas éligible à l'advance capture (`zc2:50124`).

### Notes de reproduction

C'est le principal dispositif de performance du moteur : avec 89 zones, seules celles proches du front ou des joueurs ont des unités dans le monde.
Les points durs : préserver les pertes partielles à travers le sommeil (listes de types d'unités par emplacement et passe d'élagage après respawn), garder le même placement en sous-zone, garder les groupes radar en vie pour le GCI, les nombreuses raisons de « blocage » qui doivent être évaluées de façon cohérente, et la file de spawn qui étale un réveil sur plusieurs frames.
Les distances viennent d'une matrice zone-à-zone construite une fois (`bc:buildZoneDistanceCache()`, `setup:6003`, `zc2:27596`), pas de la géométrie en direct.
Un champ `_lastSuspendedAt` est lu comme un délai de 10 s avant reprise mais n'est assigné nulle part dans le fichier (grep), donc ce délai est inerte (`zc2:37842`).

## 10. Le graphe de connexions

### Ce que règle le créateur de mission

`bc:addConnection(from, to, drawBoth, preserveDirection)` déclare une arête entre deux zones ; le Caucase en déclare 135 (`zc2:27025-27031`, `setup:2114-2183`, décompte par grep).
`drawBoth = true` dessine une flèche dans chaque sens ; `preserveDirection = true` garde la flèche orientée `from → to` (`zc2:39037-39040`, `zc2:38121-38123`).
`bc:addHiddenConnection(from, to)` déclare une arête qui n'est jamais dessinée et ne fait partie que d'un second graphe, `connectionMapHybridSuspend`, utilisé par le remplisseur IA dynamique (`zc2:27033-27039`, `zc2:27320-27322`, `setup:2252-2269`).
`bc:addConnectionSupply(from, to, method)` (Normandie seulement) déclare des liens de supply, éventuellement par `'train'`, qui remplacent le dessin ordinaire par des flèches de supply (`zc2:27045-27054`).
`bc:BlockGroundConvoy(a, b)` interdit les convois terrestres sur une paire sans retirer l'arête (`zc2:27172-27180`, `setup:2208-2211`).
Des connexions peuvent être ajoutées à l'exécution, par exemple quand une grille d'insurrection apparaît : `bc:addConnection("Krymsk", "Insurgency Grid DL22")`, `bc:buildConnectionMap()`, `bc:RefreshConnectionsLines("Krymsk")` (`setup:1903-1905`).

### Mécanisme

Le graphe est non orienté : `connectionMap[a][b] = connectionMap[b][a] = true` (`zc2:27303-27325`).
`bc:buildConnectionMap(zoneName, previousSide)` maintient des tables globales dérivées (`zc2:27350-27535`) :

- `ZONE_CONNECTED_TO_BLUE[zone]` et `ZONE_CONNECTED_BLUE_COUNT[zone]` : la zone a au moins un voisin bleu (et combien) ;
- `ZONE_NEAR_BLUE[zone]` : une zone rouge avec une zone bleue à moins de `NEAR_BLUE_METERS` ;
- `ZONE_NEAREST_BLUE[zone]` : distance à la zone bleue la plus proche.

Appelée sans argument, elle reconstruit tout ; appelée avec la zone dont le camp a changé, elle met à jour de façon incrémentale les compteurs des voisines (`zc2:27438-27523`).
`bc:buildZoneDistanceCache()` remplit `ZONE_DISTANCES[a][b]` une fois pour chaque paire avec `measureDistanceZoneToZone` (`zc2:27596-27638`).

À quoi sert le graphe dans ce thème : les blocages « a un voisin ennemi/neutre » de la décision de dormance (`zc2:37662-37689`), le réveil des voisines d'une zone neutre (`zc2:37723-37749`), `BlueIsNear` (`zc2:37149`), et les lignes de la carte.
Hors de ce thème, il détermine qui peut ravitailler ou attaquer qui (vols IA, Director).

### Notes de reproduction

L'adjacence est déclarée à la main, pas dérivée de la distance ; la distance est une matrice à part.
Une capture met à jour des compteurs en O(voisines) ; une reconstruction complète n'a lieu que lorsque la topologie change.

## 11. Front

### Ce qu'il calcule (`Frontline.BuildFromZones`, `zc2:9183-9284`)

Entrée : toutes les zones actives non cachées avec leur centroïde (centre du cercle ou moyenne des sommets du quadrilatère, `zc2:9142-9163`).
Pour chaque paire rouge/bleu plus proche que `GlobalSettings.frontlineMaxSegmentNm` (120 NM), il enregistre, pour chaque zone, sa zone ennemie la plus proche (`zc2:9208-9238`, `zc2:8521`).
Chaque zone ayant une zone ennemie la plus proche produit un « segment » `{A, B, m = midpoint, n = unit normal pointing toward the enemy for blue / toward own side for red}` (`zc2:9260-9272`).
`distToFrontNm` d'une zone est la projection signée de (centre de la zone − milieu du segment le plus proche) sur la normale de ce segment (`zc2:9168-9181`, `zc2:9278-9282`).
Il stocke aussi par zone les listes triées `sameSideNeighbors` et `enemyNeighbors` avec distance et relèvement ; les zones neutres et inactives comptent comme « du même camp » (`zc2:9243-9256`, `zc2:9273-9277`).
`Frontline.ReindexZoneCalcs()` construit ensuite une table de « conscience de zone » (zones amies, zones ennemies et cibles CAP dans un rayon de 160 NM) (`zc2:9600-9612`, `zc2:9494-9530`).

Il n'y a pas de ligne de front dessinée ; le « front » visible sur la carte est la bordure du calque de territoire (section 14).

### À quoi il sert

Placement des stations de CAP et de patrouille (`Frontline.PickCapStationFromOrigin`, `PickStationNearZone`, `zc2:61292-61301`, `zc2:67392-67406`), tests de distance au front dans la logique des groupes IA et du Director (`zc2:66255`, `zc2:75771`, `zc2:76673`, `zc2:80640`), ciblage du supply (`zc2:54473`), station AWACS (`zc2:9618` et suivantes).
Tout cela relève des thèmes IA.

### Rafraîchissement

`bc:requestFrontlineRefresh()` pose un flag sale et programme une seule reconstruction 0,15 s plus tard, de sorte que plusieurs changements de propriétaire dans la même frame ne coûtent qu'une reconstruction (`zc2:17699-17718`).
Il est demandé à la capture, à la neutralisation, à la désactivation et à la révélation d'une zone (`zc2:56684`, `zc2:55346`, `zc2:50266`, `zc2:50617`), et construit une fois au démarrage (`setup:6010-6011`).

## 12. Carte : formes et libellés des zones

### Ce que voit le joueur

Chaque zone visible est dessinée sur la carte F10 sous la forme de sa trigger zone (cercle ou quadrilatère), remplie et cernée de la couleur du propriétaire : rouge `{1,0,0,0.3}`, bleu `{0,0,1,0.3}`, gris neutre `{0.7,0.7,0.7,0.3}`, presque noir pour une zone désactivée `{0.1,0.1,0.1,0.3}` (`zc2:51392-51405`, `zc2:4345-4356`).
Une zone bleue d'où des aéronefs peuvent spawner a un contour vert en pointillés (`zc2:51739-51742`).
Le remplissage d'une zone rouge change avec son efficacité au combat (section 4).
Une zone neutre en cours de capture vire vers la couleur du capteur (section 7).
Une zone bleue sous attaque terrestre reçoit un contour en pointillés qui clignote rouge/vert une fois par seconde pendant 60 s (joueurs bleus seulement) (`zc2:26879-26919`, `zc2:26857-26877`, trigger dans `AIEN.lua:13656-13659`).
Une zone de texte est posée au point de plus grand `z` de la forme (son bord est, puisque `z` pointe vers l'est dans DCS) et porte, pour le libellé bleu : le nom de la zone avec son numéro de waypoint, "[WH]" pour un entrepôt, la garnison construite/totale quand elle est incomplète et le plus bas pourcentage de groupe endommagé, des lignes de stock de supply et de progression des réparations, "Mission!" ou des étiquettes de mission ("Attack!", "SEAD!", "Capture!"…), l'état d'entrepôt bas/vide/en réparation/détruit, et "Capturing: NN%" (`zc2:51419-51432`, `zc2:56098-56263`, `l10n:1373-1374`, `l10n:1388`).
Les joueurs rouges ont leur propre zone de texte avec la même logique appliquée à leur camp ; une zone ennemie n'affiche que son nom sauf si l'intel de zone est actif (`zc2:56222-56224`, `zc2:56259-56262`).

### Ce que règle le créateur de mission

`WaypointList = { Anapa = ' (1)', … }` dans le fichier de setup donne le numéro ajouté aux noms de zones dans les libellés et les menus (`setup:376-382`, `zc2:56098-56099`).
`PVE_Only` (Config, false par défaut) supprime les mises à jour des libellés rouges en PvE (`config:251`, `zc2:56097`).
`GlobalSettings.messages = { grouplost=false, captured=true, upgraded=true, repaired=true, zonelost=true, disabled=true }` active ou coupe les messages texte de zone (`zc2:8556-8563`).

### Mécanisme

Les identifiants de marque sont fixes par zone : `index = 3000 + n` pour la forme, `2000 + index` pour le texte bleu, `12000 + index` pour le texte rouge (`zc2:26798`, `zc2:51732-51733`).
Forme : `trigger.action.circleToAll(-1, id, point, radius, border, fill, 1)` ou `trigger.action.quadToAll(-1, id, v4, v3, v2, v1, border, fill, 1)` (`zc2:4348-4353`).
Textes : `trigger.action.textToAll(coalition, id, point, textColor, {0.7,0.7,0.7,0.8}, 17, true, text)` une fois à l'init, un par coalition (`zc2:51731-51733`).
Ensuite rien n'est redessiné : les changements de propriétaire utilisent `trigger.action.setMarkupColor` / `setMarkupColorFill` / `setMarkupTypeLine` sur les identifiants existants, et les changements de texte utilisent `trigger.action.setMarkupText(labelId, msg)` (`zc2:56655-56658`, `zc2:56751-56752`, `zc2:56263`).
`ZoneCommander:updateLabel(side)` reconstruit tout le texte pour une coalition et est appelée à chaque changement d'état : capture, neutralisation, upgrade/réparation, suspension/reprise, tick de capture temporisée (chaque seconde), changement d'entrepôt, changement d'étiquette de mission (`zc2:56076`, `zc2:56804`, `zc2:55407`, `zc2:56975`, `zc2:48076`, `zc2:46775`).
Les zones cachées n'ont aucune marque (`zc2:51411-51417`, `zc2:56086`) ; la forme et le libellé rouge d'une zone désactivée sont supprimés et son libellé bleu est vidé (`zc2:56087-56096`).
Le flash d'attaque est une marque séparée (`UTILS.GetMarkID()`), basculée par un seul `timer.scheduleFunction` partagé à 1 Hz qui s'arrête de lui-même quand il ne reste plus aucun flash (`zc2:26897-26917`, `zc2:26857-26877`).

### Notes de reproduction

Des identifiants fixes plus des appels `setMarkup*` en place évitent le scintillement du retrait/rajout et le coût du redessin de 89 formes.
Le texte du libellé est recalculé de zéro à chaque appel et `updateLabel` n'a pas de limiteur en soi ; le limiteur se trouve chez les appelants (tick de zone de 10 s, tick de capture de 1 s).
`UTILS._MarkID` est relevé au-dessus des identifiants réservés à `addZone` pour que les identifiants alloués par Moose n'entrent jamais en collision (`zc2:26799`).

## 13. Carte : lignes de connexion et flèches de supply

### Ce que voit le joueur et réglages

Chaque connexion déclarée est dessinée entre les bords des deux formes de zone.
`ConnectionMapStyle = "line"` (défaut de la Config ; `"arrow"` est l'autre valeur) et `ConnectionMapColor = "dynamic"` (ou `"white"`) (`config:402-411`, `zc2:38010-38031`).
Couleur dynamique : bleue quand l'origine est bleue et que la destination n'est pas rouge, rouge quand l'origine est rouge et que la destination n'est pas bleue, blanche sinon (c'est-à-dire à travers le front ou entre neutres) (`zc2:38024-38030`).
En mode ligne : `trigger.action.lineToAll(-1, id, head, tail, color(alpha 0.85), 4, true)` ; en mode flèche : `trigger.action.arrowToAll(-1, id, head, tail, {0,0,0,0.5}, color(alpha 0.5), 0.5)` (`zc2:39012-39023`).
Sens de la flèche : vers la zone rouge sur une paire bleu/rouge ; sinon comme déclaré, inversé quand la campagne a démarré avec `StartNormal == false`, sauf si le nom de la cible contient "sam"/"defence" ou si `preserveDirection` est posé (`zc2:38096-38126`).
Une connexion qui touche une zone désactivée n'est pas dessinée (`zc2:39008`).

### Mécanisme

Les extrémités sont calculées par `GetConnectionEdgePoint` : centre + rayon le long du relèvement pour les cercles, intersection rayon/arête pour les quadrilatères (`zc2:38033-38094`).
`DrawConnectionLines()` supprime toutes les marques de connexion et les redessine toutes ; elle s'exécute une fois 0,1 s après l'init (`zc2:38985-39046`, `zc2:30269-30276`).
`RefreshConnectionsLines(zoneName)` supprime et redessine seulement les connexions qui touchent une zone, en utilisant la table `ConnectionArrowIds["from=>to"]` (`zc2:39048-39110`) ; appelée à la capture, à la neutralisation, à la désactivation, à la réparation et à la révélation (`zc2:56675`, `zc2:55351`, `zc2:50262`, `zc2:56969`, `zc2:50605`).
Mode supply de Normandie : `drawSupplyArrows()` redessine toutes les flèches de supply (un lien de train est sauté quand son groupe de train est mort), avec anti-rebond à un redessin par 60 s par `drawSupplyArrowsDebounced` (`zc2:38192-38292`).

## 14. Carte : calques de territoire

### Ce que voit le joueur

La carte est teintée selon le propriétaire : chaque zone visible possède la partie de la carte plus proche d'elle que de toute autre zone, remplie d'une couleur translucide (rouge pour l'ennemi, vert pour l'ami, blanc pour le neutre), et la bordure entre cellules de propriétaires différents est dessinée comme une ligne épaisse.

### Réglages (globaux avec défauts du moteur, `zc2:8539-8553`)

`ShowEnemyTerritoryOverlay = true`, `EnemyTerritoryOverlayColor = {1,0,0}`, `EnemyTerritoryOverlayBorderAlpha = 18`, `EnemyTerritoryOverlayFillAlpha = 0.12`, `EnemyTerritoryOverlayBoundsMargin = 70000` (m), `ShowFriendlyTerritoryOverlay = true`, `FriendlyTerritoryOverlayColor = {0,0.8,0}` (alpha 18 / 0.12), `ShowNeutralTerritoryOverlay = true`, `NeutralTerritoryOverlayColor = {1,1,1}` (bordure 0, remplissage 0.10), `TerritoryOverlayFrontierOnlyBorders = true`, `TerritoryOverlayOuterDrawPushMeters = 0`.

### Mécanisme

C'est un diagramme de Voronoï calculé par découpage en demi-plans.
Sites : le centre de chaque zone active non cachée ; une zone de porte-avions peut à la place apporter plusieurs sites nommés `<Zone>-<n>-edge`, et les zones de navigation de porte-avions ajoutent des sites virtuels (`zc2:39518-39573`, `zc2:1445-1494`).
Bornes : la boîte englobante de tous les sites agrandie de la marge (`zc2:39637` et suivantes).
Cellule d'une zone : partir du polygone des bornes et le découper successivement par la médiatrice avec chaque autre site, le plus proche d'abord (Sutherland–Hodgman contre un demi-plan) ; les cellules de moins de 1000 m² sont abandonnées (`zc2:39751-39779`, `zc2:39233-39275`).
Pour chaque cellule, l'ensemble des sites qui l'ont effectivement découpée (`impacts`) est mémorisé, ainsi que l'index inverse `_territoryOverlayAffectedBy` (`zc2:39759-39768`, `zc2:39899` et suivantes).
Dessin : `ZONE_ELASTIC:New(name, polygon):DrawZone(-1, color, borderAlpha, color, fillAlpha, 1, true)` (`zc2:39790-39803`) ; dans Moose, `ZONE_POLYGON_BASE:DrawZone` triangule le polygone et remplit chaque triangle comme sa propre marque de carte, puis dessine les lignes de bordure (`Moose_2026-10-11.lua:11635-11700`).
La triangulation est faite une fois dans `ZONE_POLYGON_BASE:New` par découpage d'oreilles : la liste de sommets est forcée dans le sens horaire, puis récursivement le premier coin horaire qui ne contient aucun autre sommet est coupé comme un triangle jusqu'à ce qu'il reste trois points, ce qui donne n − 2 triangles pour un polygone à n côtés (`Moose_2026-10-11.lua:11449-11521`).
Chaque triangle est rempli par `_ZONE_TRIANGLE:Fill` → `COORDINATE:MarkupToAllFreeForm({p2, p3}, coalition, nil, nil, fillColor, fillAlpha, 0, nil)`, qui aboutit à `trigger.action.markupToAll(7, coalition, markId, v1, v2, v3, lineColor, fillColor, lineType, readOnly, "")` — l'identifiant de forme 7 est le polygone libre, ici à trois sommets, avec le type de ligne 0 (pas de contour) et un nouveau `UTILS.GetMarkID()` par triangle (`Moose_2026-10-11.lua:11419-11425`, `Moose_2026-10-11.lua:19268-19287`).
La bordure est une marque `trigger.action.lineToAll` par arête de polygone (`COORDINATE:LineToAll`) (`Moose_2026-10-11.lua:11682-11705`).
Tous les identifiants sont gardés dans la liste `DrawID` de l'objet zone et supprimés un par un (`UTILS.RemoveMark`) par `UndrawZone` quand une cellule est reconstruite (`Moose_2026-10-11.lua:10581-10595`, `zc2:39390`, `zc2:39405`).
Avec `TerritoryOverlayFrontierOnlyBorders`, les bordures de cellules sont supprimées et seules les arêtes partagées avec une cellule d'un propriétaire différent sont dessinées, chacune comme un quadrilatère de 250 m de large (`trigger.action.quadToAll`) (`zc2:39794-39796`, `zc2:39805-39897`).
Le calque d'un camp n'est montré que si un autre camp existe encore sur la carte (`_territoryHasOpposition`) (`zc2:39781-39788`).

### Redessin et limitation

`RefreshTerritoryOverlays(force)` calcule une clé d'état (valeurs de config + nom/camp/actif/caché de chaque zone) et ne fait rien quand elle est inchangée ; sinon elle efface et reconstruit tout (`zc2:40157-40182`, `zc2:39443-39472`).
`RefreshTerritoryOverlayZone(zoneName)` est le chemin incrémental utilisé à chaque changement de propriétaire : un changement de camp à visibilité inchangée ne recolore que cette cellule ; une zone qui apparaît ou disparaît reconstruit cette cellule plus les cellules qu'elle impacte ; les segments de front ne sont reconstruits que pour l'ensemble sale ; tout cas inhabituel (bornes changées, config changée, zone de porte-avions) retombe sur la reconstruction complète (`zc2:40184-40310`).
Appelée à l'init, 0,1 s après l'init, et depuis la capture, la neutralisation, la désactivation et la révélation (`zc2:30268-30276`, `zc2:56674`, `zc2:55350`, `zc2:50261`, `zc2:50604`).

### Notes de reproduction

La géométrie est du Lua pur et autonome ; la seule dépendance envers Moose est le remplissage de polygone (`ZONE_ELASTIC`), c'est-à-dire la triangulation d'un polygone convexe et une marque par triangle.
Le nombre de marques de carte est grand (triangles par cellule plus quadrilatères de front), ce qui explique l'existence du chemin incrémental.

## 15. Zones cachées, zones qui apparaissent et événements de zone scriptés

- Une zone cachée (`isHidden` ou « hidden » dans le nom) est une zone à part entière sans aucune présence sur la carte : elle contient des groupes de garnison que le créateur de mission veut voir gérés et persistés, par exemple `HiddenBlueEWR`, ou des forces de réserve `Hidden1…8` (`setup:851-865`).
- `SpawnFriendlyAssets(changedZone)` est une fonction du fichier de setup appelée 2 s après chaque capture/neutralisation/désactivation ; au Caucase, elle passe au rouge des zones de réserve cachées et les améliore (`MakeZoneRedAndUpgrade`) quand exactement une de deux zones nommées est bleue, les détruit (`DestroyHiddenZone`) quand les deux sont bleues, et réveille les grilles d'insurrection (`setup:1851-1940`, `zc2:56642-56644`).
- `MakeZoneRedAndUpgrade()` capture silencieusement pour le rouge une zone neutre au départ et l'améliore d'un emplacement toutes les 2 s jusqu'à ce qu'elle soit pleine (`zc2:50494-50522`).
- `MakeZoneBlue()` détruit toute unité rouge à l'intérieur de la zone et la capture pour le bleu 12 s plus tard (`zc2:50470-50491`).
- Zones qui apparaissent (`Popup = true`, `NeutralAtStart = true`) : `normalizePopupAwakenState` les garde cachées, neutres et inertes jusqu'à `isAwaken` ; `AwakenZone()` révèle la zone, dessine sa forme et ses libellés pour la première fois, reconstruit les connexions, le calque, les menus et le front ; `AwakenZoneAndUpgrade()` la passe aussi au rouge et la remplit (`zc2:44581-44598`, `zc2:50543-50631`, `setup:831-834`).
- Les grilles d'insurrection du Caucase sont des zones qui apparaissent, réveillées quand une zone donnée devient bleue, annoncées par un texte et `WarningSound.ogg`, connectées à la carte à ce moment-là, et désactivées pour de bon avec une récompense de 500 crédits quand elles sont perdues (`setup:1896-1905`, `setup:2725-2729`).
- Les zones à `income` (usines, dépôts) paient leur propriétaire à chaque tick de 10 s (`setup:826-830`, `zc2:55157-55167`).

## 16. Menu radio F10 « Intel & Zone status » et message de statut de zone

### Ce que voit le joueur

Menu par groupe `Intel & Zone status` → `Red Side` / `Blue Side` → une commande par zone visible et éveillée (ou suspendue « idle »), libellée "<zone> (<waypoint n>)", triée par numéro de waypoint décroissant puis par nom, paginée par 9 sous des sous-menus `More` imbriqués (`zc2:40326-40467`, `l10n:160-170`).
Sélectionner une zone affiche pendant 15 s (au groupe) : "<zone> status", "Controlled by <side>", les minutes d'intel restantes, "upgrades n/total", la liste des groupes de garnison avec leur santé en % (taille / taille initiale), le flavour text, "irreparably damaged" pour une zone désactivée, et le centre de la zone en DDM, DMS, MGRS plus l'élévation en m et en ft (`zc2:50274-50465`).
Pour une zone ennemie, la liste de garnison n'est montrée que tant que l'intel de zone ou l'intel JTAC est actif ; sinon le texte dit d'acheter de l'intel ou un JTAC (`zc2:50313-50367`).
Le même menu racine héberge le sous-menu d'intel/de mission du commandant de mission (autre thème) (`zc2:40333-40342`).

### Mécanisme

Les menus sont créés avec `missionCommands.addSubMenuForGroup` / `addCommandForGroup` bruts ; le callback de commande est `ZoneCommander.displayStatus` avec les arguments `(zone, groupId, 15, false, viewerSide)` (`zc2:40423-40457`).
Un cache par groupe des lignes `{zone, handler, label}` permet au constructeur de sauter le sous-menu d'un camp quand rien n'a changé ; sinon tout le sous-menu du camp est supprimé et reconstruit (`zc2:40317-40324`, `zc2:40408-40466`).
`bc:requestZoneStatusMenuRefresh(groupId, intelOnly)` ne fait que poser des flags et programmer un vidage 0,15 s plus tard ; le vidage met en file tous les groupes qui ont le menu et un worker reconstruit **un groupe toutes les 0,1 s**, en partageant les listes de zones triées entre les groupes d'une même passe (`zc2:17272-17317`, `zc2:40469-40499`).
Demandé à la capture, à la neutralisation, à la désactivation, aux changements de suspension/reprise et aux réveils par proximité (`zc2:56618`, `zc2:55345`, `zc2:50264`, `zc2:37975`, `zc2:37161`).

### Notes de reproduction

DCS n'a pas d'appel « mettre à jour un élément de menu », donc une liste modifiée signifie supprimer puis recréer ; le cache de lignes et le worker à un groupe par tick sont ce qui rend cela abordable avec de nombreux groupes de joueurs.
Le pourcentage de santé est la taille du groupe sur sa taille initiale, pas la vie des unités.

## 17. Commandes d'admin par marqueur de carte F10 qui agissent sur les zones

Gérées dans le handler de changement de marque (`event.id == 26`, coalition 1 ou 2) de `startMonitorPlayerMarkers` (`zc2:28455-28456`) ; le contrôle d'accès admin et le mécanisme d'alias (`adminAliases`) relèvent d'un autre thème.
Commandes liées aux zones, chacune agissant sur la zone située sous le marqueur (`bc:getZoneOfPoint(event.pos)`) :

| Texte du marqueur (par défaut / action d'alias) | Effet | Code |
|---|---|---|
| `capture:1`, `capture:2` | `zone:capture(side)` (seulement si neutre) | `zc2:29172-29184` |
| `blå` / `captureNeutralBlue`, `röd` / `captureNeutralRed` | capture pour le bleu / le rouge | `zc2:29185-29202` |
| `upgradera` / `upgradeZone` | un cran d'upgrade | `zc2:29137` |
| `maxxa` / `fullyUpgradeZone` | `MakeZoneSideAndUpgraded()` | `zc2:29164-29171` |
| `recapture` | `RecaptureBlueZone()` | `zc2:29149-29156` |
| `rensa` / `clearZone` | `zone:killAll()` puis `update()` → la zone devient neutre | `zc2:28886-28895` |
| `upgradeallred`, `upgradeallblue` | améliorer toutes les zones d'un camp | `zc2:28794-28803` |
| `whynot` | explique la décision de suspension de la zone | `zc2:28918-28922` |
| `givemesupplies` | ajoute 3 de stock de supply express à la zone | `zc2:29157-29163` |
| `status` | Le message de statut de zone de la section 16 pour la zone sous le marqueur, 60 s au groupe de l'auteur (30 s à la coalition quand la marque n'a pas d'initiateur, suivi du détail de récupération locale de la zone si elle est amie) ; hors de toute zone, l'auteur est informé que la commande a besoin d'une zone. | `zc2:28810-28832` |

## 18. Conditions de victoire et de défaite de la campagne

### Ce que voit le joueur

Victoire PvE : quand plus aucune zone visible n'est rouge, tout le monde lit "Enemy has been defeated. Mission Complete." (« L'ennemi a été vaincu. Mission accomplie. ») et le bleu entend `BH.ogg` 2 s plus tard (`setup:2779-2795`, `l10n:2061-2062`).
Avec `AutoRestart`, le texte se termine par "Restarting now.." et la mission se termine 5 s plus tard ; sans lui, un menu de coalition `Restart and Reset?` → `Yes` / `No` est ajouté pour le bleu (`setup:2797-2826`, `l10n:167`).
Défaite PvE : quand plus aucune zone visible n'est bleue, "Mission failed, Server restarting..." (« Mission échouée, redémarrage du serveur... ») et une réinitialisation et un redémarrage inconditionnels (`setup:2768-2811`).
PvP : le camp qui possède toutes les « zones de victoire » gagne, avec "<side> coalition wins!" (« La coalition <side> gagne ! ») (`setup:2736-2775`, `setup:2833`).

### Mécanisme

`checkMissionComplete(event, sender)` est enregistrée comme trigger de zone avec l'identifiant `missioncompleted` sur les événements `lost` et `destroyed` de chaque zone (et `captured` en PvP sur les zones de victoire), et est aussi appelée une fois depuis un timer de démarrage après l'application de la sauvegarde (`setup:2834-2849`).
PvE : elle parcourt `bc:getZones()`, en ignorant les zones dont le nom contient "hidden" ; `done` = aucune zone avec `side == 1` ; `missionFailed` = aucune zone avec `side == 2`, considéré seulement une fois que l'appel de démarrage a posé `missionCheckReady` (`setup:2776-2790`).
À l'achèvement : `missionCompleted = true` ; le user flag 180 est posé (il coupe les autres sons et messages de la mission dans tout le fichier de setup, par exemple `setup:6202`, et le « ding » à la perte d'une zone, `zc2:55374`) ; la sauvegarde est effacée en écrivant une table `zonePersistance` vide et en appelant `resetSaveFileAndFarp()` quand elle existe ; `bc._persistenceResetPending = true` ; 5 s plus tard, le user flag 181 est posé (`setup:2791-2808`).
Le flag 181 est le flag « fin de mission » : le moteur le pose aussi depuis les commandes de redémarrage d'admin (`zc2:28126`, `zc2:28139`, `zc2:29243`), et le `.miz` contient un trigger dont la condition est `c_flag_is_true("181")` et l'action `a_end_mission("blue", …)` (fichier `mission` de `Foothold_CA_6.5.2_Coldwar-Modern-Vietnam.miz`, trigger 7).
L'identifiant de trigger `missioncompleted` est explicitement exclu de la détection « la zone disparaît quand elle est perdue » (`zc2:50066`, `zc2:50091`).
Un marqueur d'admin `AvslutaFoothold` / `endMission` appelle `forceMissionComplete()` s'il est défini (`zc2:28911-28917`).

### Notes de reproduction

Le test de victoire n'est évalué que sur des événements de zone, pas sur un timer, plus une fois au démarrage.
Les zones « hidden » sont exclues par leur nom, donc une réserve rouge cachée n'empêche pas la victoire.
La réinitialisation consiste à « écrire une sauvegarde vide, puis terminer la mission » ; le serveur est censé recharger la même mission.

## Vu hors de ce thème

- Stock de supply régulier, efficacité du supply, travaux de récupération locale (réparation/reconstruction) et leurs lignes de libellé : `zc2:52059-54106` (thème logistique).
- Static d'installation d'entrepôt par zone (`_initWarehouseFacility`, `_updateWarehouseFacility`), politique de stock d'armement : `zc2:46108-46584`, `zc2:51151-51356`.
- FSM des `GroupCommander` IA, code d'atterrissage de supply/d'arrivée de convoi qui alimente la capture : `zc2:67800-67850`, `zc2:69925-70120`.
- Réactions du Director aux changements de propriétaire (`recordZoneOwnershipChange`, détournement de CAS vers une zone capturée) : `zc2:84482-84736`.
- Articles de boutique « capture », « advance capture » et menus de sélection de zone cible : `setup:4639-4746`, `zc2:22553-22620`, `zc2:34146-34329`.
- Activation des zones CTLD au changement de propriétaire (`addCTLDZonesForBlueControlled`), handlers de capture par troupes/crates : `ctld:5300-5350`, `ctld:9245-9290`.
- Intel de zone (ce que révèlent le libellé et le statut ennemis) : `_zoneIntelIsActive`, `zc2:5746-6668`.
- Difficulté dynamique (`increaseDifficulty` à la perte d'une zone, `_rebalanceRedDifficulty`) : `zc2:19253-19260`, `zc2:37031`.
- Zones de navigation de porte-avions dessinées sur la carte et leurs liens de suspension : `zc2:14200-14344`, `zc2:27056-27167`.
- Dessins des racetracks de ravitailleurs dynamiques : `zc2:105815-105965`.
- Commandes d'admin par marqueur en général, exécution Lua à distance `-code:` depuis un marqueur : `zc2:28455-29242`, `zc2:29203-29205`.
- Persistance des zones (instantanés de suspension, captures temporisées, statics retirés) : `zc2:1169-1204`, `zc2:47127-47298`, `zc2:44601`.
- Logique de révélation des SAM « hidden on MFD » : `zc2:47696-47728`.
- Réactions de l'IA terrestre AIEN qui déclenchent le message et le flash « zone under attack » : `AIEN.lua:13640-13662`.
- Export de l'état des joueurs (`bc.playersState`) rafraîchi dans la boucle de proximité : `zc2:37090-37097`.

