# 02 — Persistance, cycle de vie de la campagne, gestion des joueurs et plomberie du moteur (Foothold v6.5.3)

Source : tag amont v6.5.3 (commit 27d8cf4a), fichiers sous `Common Scripts/`, `Setup files/` et le `.miz` Caucasus.
Les noms de fichiers courts sont utilisés dans les citations : `zoneCommanderv2.lua` est le moteur, `Config` est `Foothold Config.lua`, `Setup` est `MA_Setup_CAv2.lua`, `mission` est le fichier `mission` à l'intérieur de `Foothold_CA_6.5.2_Coldwar-Modern-Vietnam.miz`.

## Liste des fonctionnalités

| Fonctionnalité | Description en une ligne | Emplacement principal dans le code |
|---|---|---|
| Ordre de chargement des scripts | Quatre triggers de mission chargent 12 fichiers Lua dans un ordre fixe | `mission:53-93`, `mission:276347-276560` |
| Surcharge de la config externe | Un `Foothold Config.lua` dans `Saved Games\...\Missions\Saves` remplace celui du `.miz` | `Config:1-186`, `Config:3517-3526` |
| Sérialiseur de tables Lua | Chaque fichier de sauvegarde est un chunk Lua qui assigne une table globale | `zoneCommanderv2.lua:7108-7275` |
| Sauvegarde de campagne (`zonePersistance`) | Zones, garnisons, crédits, stock de la boutique, groupes IA, mémoire du Director, ravitailleurs, porte-avions | `zoneCommanderv2.lua:25176-25855`, `44529-44579` |
| Sauvegarde automatique étalée | Sauvegarde toutes les 60 s, zones collectées 8 par 0,1 s puis sérialisées dans une coroutine | `zoneCommanderv2.lua:30328-30330`, `44410-44527` |
| Chargement de la campagne et réapplication | `bc:loadFromDisk()` puis restaurations différées | `zoneCommanderv2.lua:44601-45960`, `Setup:5835` |
| Inventaire du dossier de sauvegarde | Huit fichiers sous `Missions\Saves`, un jeu par carte, par époque et par mode | `Setup:467-485`, `Foothold CTLD.lua:8105-8108` |
| Persistance des entrepôts | Stock d'armes des aérodromes et des FARP dans un CSV, un aérodrome par seconde | `zoneCommanderv2.lua:111502-112315` |
| Fichier de rang et de joueurs | Crédits, carrière et réglages par UCID, partagés par toutes les campagnes | `zoneCommanderv2.lua:43358-43419`, `44332-44378` |
| Fin, réinitialisation et redémarrage | Détection de victoire/défaite, effacement de la sauvegarde, flag 181 → `a_end_mission` | `Setup:2732-2849`, `zoneCommanderv2.lua:28111-28147`, `mission:63` |
| Interrupteurs d'époque et PvE/PvP | Deux globales de config choisissent les templates, les listes et le nom de la sauvegarde | `Config:196-202`, `Setup:440-477` |
| Identification des joueurs | Nom à l'exécution, UCID sur disque, alias et gestion de l'héritage | `zoneCommanderv2.lua:43685-43779` |
| Gestion du spawn et contrôle des slots | Coalition de l'aérodrome, user flags par groupe, rejet de l'événement de naissance | `zoneCommanderv2.lua:101412-101500`, `51745-51747`, `56753-56767` |
| Suivi du décollage, de l'atterrissage et de l'éjection | Un seul handler d'événements du monde alimente les récompenses, la carrière et le CSAR | `zoneCommanderv2.lua:42893-43106` |
| Tirs fratricides | Message, compteur de carrière et pénalité de crédits de rang | `zoneCommanderv2.lua:42641-42670` |
| Commandes par marqueurs de carte | Commandes joueur et admin saisies dans des marqueurs F10, sans liste d'admins | `zoneCommanderv2.lua:28354-29253` |
| Boucles principales et timers | Vague de zones toutes les 10 s étalée à 0,1 s par zone, files avec budgets, watchdog | `zoneCommanderv2.lua:30226-30338`, `43235-43346` |
| Gestion des événements | Trois handlers bruts, scrutation de l'état des zones, peu de sets Moose | `zoneCommanderv2.lua:30228-30232`, `42893` |
| Gestion du menu F10 | `missionCommands` bruts, handles par groupe, files de rafraîchissement avec anti-rebond | `zoneCommanderv2.lua:17272-17317`, `40469-40500` |
| Messages et localisation | 10 locales, portées serveur / joueur / groupe, recherche par clé avec repli sur EN | `Foothold_Localization.lua:20814-21049` |
| Recensement des dépendances à Moose | Nombre d'appels classe par classe pour le moteur et les scripts satellites | section à la fin |

## Ordre de chargement des scripts dans le `.miz`

**Ce que règle le créateur de mission.**
La mission Caucasus a sept règles de trigger (`mission:276347-276560`, forme compilée à `mission:53-93`).
La règle 1 « Remove Trees » (démarrage de la mission) retire des objets du décor dans 12 zones (`mission:57`).
La règle 2 « ScriptLoader 1 » (démarrage de la mission, sans condition) charge trois fichiers dans cet ordre : `Moose_2026-10-11.lua`, `Foothold_Localization.lua`, `Foothold Config.lua` (`mission:58`, clés de ressource résolues dans `l10n/DEFAULT/mapResource:11,65,63`).
La règle 3 (démarrage de la mission, sans condition) charge `zoneCommanderv2.lua`, `EWRS.lua`, `MA_Setup_CAv2.lua`, `WelcomeMessage.lua` (`mission:59`, `mapResource:38,54,28,10`).
La règle 4 « ScriptLoader 3 » (une fois, `c_time_after(3)`) charge `Zeus.lua`, `Foothold CTLD.lua`, `Foothold_CTLD_Red.lua`, `Splash_Damage_3.4.1_leka.lua` (`mission:60,89`, `mapResource:70,31,36,7`).
La règle 5 « AIEN » (une fois, `c_time_after(12)`) charge `AIEN.lua` (`mission:61,90`, `mapResource:3`).
La règle 6 « Sounds » (démarrage de la mission) joue chaque `.ogg` une fois au groupe de coalition 41 pour que les fichiers soient embarqués dans le `.miz` (`mission:62`) (la finalité est une estimation ; la liste des actions est lue).
La règle 7 (une fois, `c_flag_is_true("181")`) exécute `a_end_mission("blue", "", 0)` (`mission:63,92`) : c'est le seul mécanisme de redémarrage de la mission elle-même.

| Ordre | Fichier | Rôle |
|---|---|---|
| 1 | `Moose_2026-10-11.lua` | Le framework Moose, embarqué |
| 2 | `Foothold_Localization.lua` | Tables de chaînes pour 10 locales et l'objet de recherche `L10N`/`FootholdLocalization` |
| 3 | `Foothold Config.lua` | Réglages serveur ; peut se remplacer par la copie du dossier Saves |
| 4 | `zoneCommanderv2.lua` | Le moteur (classes seulement ; rien ne démarre tant que le fichier de setup n'a pas tourné) |
| 5 | `EWRS.lua` | Comptes rendus radar d'alerte avancée en texte pour les joueurs |
| 6 | `MA_Setup_CAv2.lua` | Données de campagne de la carte ; crée `bc`, les zones, la boutique, appelle `bc:loadFromDisk()` et `bc:init()` |
| 7 | `WelcomeMessage.lua` | Texte d'accueil et briefing par joueur au spawn |
| 8 | `Zeus.lua` | Commandes de spawn/destruction par marqueurs de carte pour les game masters |
| 9 | `Foothold CTLD.lua` | Logistique bleue sur Moose CTLD/CSAR |
| 10 | `Foothold_CTLD_Red.lua` | CTLD côté rouge (PvP) |
| 11 | `Splash_Damage_3.4.1_leka.lua` | Script de dégâts de souffle |
| 12 | `AIEN.lua` | Script de réaction de l'IA au sol, 12 s après le démarrage |

**Notes de reproduction.**
L'ordre encode des dépendances : la config a besoin de `UTILS.CheckFileExists` et de `SCHEDULER` de Moose ainsi que de `FootholdLocalization` (`Config:132,152,165-168`), le fichier de setup a besoin des classes du moteur, et CTLD est chargé 3 s plus tard pour que `bc` et les zones existent.
Aucun script n'est chargé avec `dofile` depuis le disque, sauf la config externe, donc la mission tourne à partir du seul `.miz`.

## Surcharge de la config externe (`Foothold Config.lua` dans le dossier Saves)

**Ce que voit l'administrateur.**
Si `<Saved Games>\<DCS>\Missions\Saves\Foothold Config.lua` existe, il est utilisé à la place de la copie embarquée dans le `.miz`, et le message « Loaded Foothold Config.lua externally. » est affiché pendant 30 s une seconde après le démarrage (`Config:1-6`, `Config:150-159`, `Config:3517-3523`).
Sur la carte Normandie, le fichier s'appelle `Foothold Config WW2.lua` et le fichier de base est lu depuis `l10n/DEFAULT/` (`Config:2-6`, `Config:161-180`).
Si le fichier externe a une erreur de syntaxe, « FOOTHOLD CONFIG ERROR: Foothold config did not load correctly, Check syntax. » se répète toutes les 30 s (`Config:138-148`).
Si le fichier externe est plus ancien que la mission et qu'il lui manque des réglages, les valeurs par défaut embarquées sont conservées pour ceux-ci, un avertissement les liste dans `dcs.log`, et un avertissement à l'écran se répète 12 fois toutes les 10 s (`Config:94-136`).
Un outil Windows compagnon, `Foothold Config Manager 2.5.7.exe`, édite ce fichier ; les commentaires `-- @gui ...` dans la config sont ses annotations (`Config:201`, `Config:490`).

**Mécanisme.**
La config embarquée s'exécute en premier comme un chunk normal et met chaque globale à sa valeur par défaut.
En tête, elle ne fait que *compiler* le fichier externe avec `loadfile` (`Config:150-159`) ; tout à la fin, elle *exécute* le chunk compilé, de sorte que les valeurs externes écrasent les valeurs par défaut déjà posées (`Config:3517-3523`).
Le chunk externe s'exécute sous `setfenv` avec un environnement proxy dont le `__newindex` enregistre les globales assignées (`Config:104-114`).
Après son exécution, chaque nom de `FootholdConfigTrackedTableNames` (64 tables, `Config:9-74`) dont la valeur est encore l'objet table embarqué, et chaque nom de `FootholdConfigTrackedScalarNames` (18 scalaires, `Config:76-95`) non assigné, est signalé comme manquant (`Config:116-127`).
Les tables sont remplacées en bloc, pas fusionnées ; la vérification « manquant » se fait par identité d'objet (`Config:118`).
`PvP` est forcé à `false` sur toute carte autre que Caucasus, Syrie et Golfe Persique (`Config:3525`).
Nécessite `lfs` (pour `lfs.writedir`) et `loadfile`, donc `MissionScripting.lua` doit être désanitisé ; sans `lfs`, `savePath` vaut `nil` et la config embarquée est utilisée silencieusement (`Config:1`, `Config:150`).
Usage de Moose : `UTILS.CheckFileExists` (enveloppe `lfs.attributes`/`io.open`) et `SCHEDULER:New` pour les messages différés (`Config:132,150`).

## Sérialiseur de tables Lua (`Utils.saveTable` / `Utils.loadTable`)

**Mécanisme.**
Un fichier de sauvegarde est du source Lua : `<var> = {}` puis une assignation par clé de premier niveau, `<var>["key"] = <literal>` (`zoneCommanderv2.lua:7140-7183`).
`Utils.serializeValue` émet les nombres et les booléens avec `tostring`, les chaînes avec `%q`, et les tables récursivement avec une indentation de deux espaces ; les fonctions et les userdata sont silencieusement abandonnés (`zoneCommanderv2.lua:7214-7249`).
Pour le fichier de campagne, la clé `zones` est écrite une zone par instruction, pour qu'une zone puisse être re-sérialisée seule si elle a changé pendant une sauvegarde étalée (`zoneCommanderv2.lua:7142-7153`, `7185-7191`).
Pour le fichier de rang, chaque fiche joueur est écrite avec `name`, `lastSeen`, `credits` en premier (`zoneCommanderv2.lua:7154-7175`).
Le texte entier est construit en mémoire avec `table.concat` et écrit par un seul `io.open(filename, "w")`/`write`/`close` ; il n'y a ni fichier temporaire ni renommage, donc un crash pendant l'écriture tronque la sauvegarde (`zoneCommanderv2.lua:7196-7201`).
`Utils.loadTable` vérifie `lfs.attributes(filename)`, puis `loadfile(filename)()`, qui définit la globale (`zonePersistance`, `RankSave`, …) (`zoneCommanderv2.lua:7251-7261`).
Si le fichier ne compile pas, il est relu ligne par ligne, les lignes dont la clé contient une barre oblique ou inversée sont abandonnées, et le reste est exécuté avec `loadstring` — une réparation pour d'anciennes sauvegardes à clés ressemblant à des chemins (`zoneCommanderv2.lua:7263-7272`).
Si `io` est absent à la sauvegarde, le message `PERSISTENCE_SAVE_DISABLED` est affiché une fois pendant 600 s et la sauvegarde est désactivée (`Utils.canAccessFS = false`) ; si `lfs` est absent au chargement, `PERSISTENCE_SAVE_DESANITIZE` est affiché (`zoneCommanderv2.lua:7132-7138`, `7252-7257`).
Désanitisation nécessaire : `io` (open/write/read) et `lfs` (`writedir`, `mkdir`, `attributes`) ; `os` n'est pas requis par le sérialiseur (`zoneCommanderv2.lua:7128-7272`).

**Notes de reproduction.**
Le chargeur exécute le fichier de sauvegarde comme du code dans l'environnement de la mission, donc le fichier doit être de confiance.
Un compteur global de génération d'écriture (`Utils.zonePersistenceWriteGeneration`) est incrémenté par chaque écriture synchrone de la campagne et permet à une sauvegarde étalée en cours de détecter qu'elle est périmée (`zoneCommanderv2.lua:7109`, `7129-7131`, `7204-7207`, `44458-44464`).

## Fichiers écrits sous `Saved Games\<DCS>\Missions\Saves`

**Ce que voit l'administrateur.**
Tous les fichiers vivent dans `lfs.writedir()..'Missions/Saves'` (`Setup:479-485`), créé avec `lfs.mkdir` s'il manque (`Setup:482`).
`<base>` est `FootholdSaveBaseName`, fixé par carte et par époque par le fichier de setup : `FootHold_CA_v0.3`, `FootHold_CA_v0.3_Coldwar`, `FootHold_CA_v0.3_Vietnam`, avec `Pvp` ajouté en mode PvP (`Setup:467-477`).
Chaque époque et chaque mode a donc sa propre campagne ; seul le fichier de rang est partagé.

| Fichier | Format | Écrivain et période | Contenu |
|---|---|---|---|
| `<base>.lua` | Chunk Lua, globale `zonePersistance` | sauvegarde automatique étalée, d'abord à 30 s puis toutes les 60 s (`zoneCommanderv2.lua:30328-30330`) | la campagne (voir section suivante) |
| `Foothold_Ranks.lua` | Chunk Lua, globale `RankSave` | même tâche que la sauvegarde de campagne, seulement si `RankingSystem == true` (`zoneCommanderv2.lua:44356-44378`, `44532-44534`) | fiches joueur par UCID, partagées par toutes les cartes et époques (`Setup:756`) |
| `<base>_storage.csv` | lignes `AIRBASE;KIND;NAME;QTY` | toutes les 300 s, d'abord à 30 s, un aérodrome par seconde (`zoneCommanderv2.lua:112302-112315`, `112004-112052`) | stock d'armes de chaque aérodrome de zone et de chaque FARP CTLD |
| `<base>_CTLD_Save.csv` | Format de sauvegarde Moose CTLD | sauvegarde automatique Moose CTLD toutes les 300 s (`Foothold CTLD.lua:8105-8108`) | groupes au sol construits par CTLD et troupes larguées |
| `<base>_CTLD_Red_Save.csv` | idem | idem, instance CTLD rouge (`Foothold_CTLD_Red.lua:2283-2286`) | unités CTLD rouges (PvP) |
| `<base>_CTLD_FARPS.csv` | lignes `seq;name;x;y;zell;lat;lon;supplyStock;` après une ligne d'en-tête | `TIMER` d'abord à 30 s puis toutes les 300 s (`Foothold CTLD.lua:7611`, `7690-7708`, `8101-8103`) | FARP construits par les joueurs |
| `foothold.status` | une ligne : chemin du fichier de campagne | après chaque sauvegarde de campagne (`zoneCommanderv2.lua:44557-44568`) | pointeur pour les outils externes (« SITAC ») |
| `Foothold Config.lua` | Lua | lecture seule | config externe (section précédente) |

Autres écritures hors de ce dossier : `AIEN.lua` écrit un journal sous `Logs\` (`AIEN.lua:9117-9118`).
Désanitisation : le moteur a besoin de `io` et `lfs` ; aucun appel `os.` n'a été trouvé par grep dans `zoneCommanderv2.lua`.
Le temps réel (horloge murale) pour le champ `lastSeen` des fiches de rang vient de `socket.gettime()` de LuaSocket si une globale `socket` ou `package.loaded.socket` existe, sinon `lastSeen` n'est pas mis à jour (`zoneCommanderv2.lua:43666-43683`).
Un `require("socket")` existe à `zoneCommanderv2.lua:48459`, dans `fhEnsureCampaignSeed()`, qui initialise une fois par session le générateur aléatoire propre au moteur (`zoneCommanderv2.lua:48449-48475`).
Il est protégé par `if package and require`, donc il ne tourne que lorsque `require` est désanitisé ; il étend alors `package.path`/`package.cpath` avec `.\LuaSocket\` et utilise `socket.gettime()` en microsecondes comme graine.
Sans lui, la graine est construite à partir de la date de la mission, `env.mission.start_time`, `timer.getAbsTime()` et `timer.getTime()` (`zoneCommanderv2.lua:48465-48475`).
`net.get_player_list`, `net.get_name` et `net.get_player_info` sont appelés depuis l'environnement de scripting de la mission (`zoneCommanderv2.lua:41170-41195`, `43698-43708`, `43789-43795`).

## Sauvegarde de campagne : contenu de `zonePersistance`

**Clés de premier niveau** (construites par `_newPersistenceState`, `_collectPersistenceZoneState`, `_collectPersistenceZoneCommanders`, `_finalizePersistenceState`, `_writePersistenceState`) :

| Clé | Contenu | Code |
|---|---|---|
| `zones[zoneName]` | fiche par zone, détaillée plus bas | `zoneCommanderv2.lua:25276-25320` |
| `accounts` | soldes de crédits des coalitions | `zoneCommanderv2.lua:25717` |
| `shops[side][id].stock` | stock restant de chaque article de la boutique dont le stock n'est pas illimité (-1) | `zoneCommanderv2.lua:25719-25728` |
| `playerStats` (par UCID), `legacyPlayerStats` (par nom), `playerStatsIdentityVersion`, `ucidToName` | statistiques de campagne par joueur | `zoneCommanderv2.lua:25731-25734` |
| `ewrsSettings`, `selfJtacSettings` (+ `legacy…`), `settingsIdentityVersion` | préférences EWRS et self-JTAC par joueur ; retirées de ce fichier quand le fichier de rang les a stockées | `zoneCommanderv2.lua:25735-25740`, `44535-44546` |
| `playerLocales` | langue choisie par chaque joueur | `zoneCommanderv2.lua:25741-25743` |
| `zonesDetails[zoneName]` | `flavorText`, `hidden` — exportés pour les outils externes | `zoneCommanderv2.lua:25745-25761` |
| `missions` | titre, description, `isRunning`, `isEscortMission` des missions actives — exportés pour les outils externes | `zoneCommanderv2.lua:25764-25778`, `44486-44500` |
| `connections` | paires `from`/`to` du graphe des zones — exportées pour les outils externes | `zoneCommanderv2.lua:25781-25793` |
| `players` | dernières positions connues des joueurs (`bc.playersState`) | `zoneCommanderv2.lua:25796-25802` |
| `ejectedPilots` | pilotes abattus en attente de CSAR : joueur, crédits perdus, coalition, lat/long/alt, horodatage | `zoneCommanderv2.lua:25804-25815`, relus à `44890-44928` |
| `tankers` | `arco` et `texaco` : débloqué, x/y/z, cap, branche, zone, vitesse (par camp en PvP) | `zoneCommanderv2.lua:25817-25859` |
| `awacsLost` | PvP seulement, quatre booléens | `zoneCommanderv2.lua:25845-25847` |
| `carrierNavigation` | état de station/voie du groupe du porte-avions | `zoneCommanderv2.lua:25860-25863`, `15298-15317` |
| `runwayPlaneSpawnBlocks[zoneName]` | secondes restantes pendant lesquelles une piste cratérisée bloque les spawns d'avions IA | `zoneCommanderv2.lua:25864` |
| `redMassAttackMission` | état d'une attaque de masse rouge en cours (PvE) | `zoneCommanderv2.lua:25866-25869` |
| `director`, `blueDirector`, `blueAreaCommitment` | mémoire du Director : état, mémoire du front, stratégie, posture aérienne, renseignement, reliquats de cooldown, historiques de décisions, résultats | `zoneCommanderv2.lua:25875-25886`, `92448-93027` |
| `airAiPersistence` | enregistrements `inair[groupName]` et `spawnNowTakeoff[]` des vols IA | `zoneCommanderv2.lua:25563-25640` |
| `surfaceAiPersistence` | enregistrements `active[groupName]` des convois et navires en route ou à destination | `zoneCommanderv2.lua:25641-25691` |
| `suspendedGciStateVersion` | version de schéma de l'état radar des zones suspendues | `zoneCommanderv2.lua:25697` |
| `customFlags` | table clé/valeur libre `CustomFlags` utilisée par les fichiers de setup pour des événements de campagne ponctuels | `zoneCommanderv2.lua:44530` |
| `globalExtraUnlock` | drapeau de déblocage de la boutique (par camp en PvP) | `zoneCommanderv2.lua:44531` |

`zonePersistance.difficultyModifier` est lu au chargement (`zoneCommanderv2.lua:45690-45695`) mais **rien ne l'écrit** dans la v6.5.3 : un grep sur tous les fichiers `.lua` de l'extrait ne trouve le nom que dans sa valeur par défaut de classe (`11997`), dans `increaseDifficulty`/`decreaseDifficulty` (`19253-19265`) et dans cette branche de chargement.
Aucun des constructeurs de persistance (`25176-25886`, `44529-44552`) ne le met dans l'état, donc la branche de chargement est un reliquat qui ne se déclenche jamais sur une sauvegarde produite par cette version.
La valeur elle-même est aussi inerte sur Caucasus : elle ne bouge que si `bc.difficulty` existe, et le fichier de setup appelle `BattleCommander:new(filepath, 10, 60)` sans le quatrième argument `difficulty` (`Setup:754`, `zoneCommanderv2.lua:17082`, `17120`) ; voir `04-director.md` section 15.

**Fiche par zone** (`zoneCommanderv2.lua:25276-25320`, `25357-25400`) :
`side` ; `level` (nombre de groupes construits) ; `remainingUnits[slot]` = liste des noms de types des unités encore vivantes dans chaque groupe de garnison (vie ≥ 1) ; `remainingUnitNames[slot]` pour les groupes « Fixed » placés à la main (noms d'unités exacts) ; `spawnSubZones[slot]` (dans quelle sous-zone chaque groupe a été placé) ; `samMfdReveals` ; `suspended`, `idleSuspended`, `suspendedLossesVersion` ; `destroyed` (objets statiques critiques détruits) ; `active` ; `isAwaken` (zones pop-up) ; `triggers[id] = hasRun` ; `firstCaptureByRed` ; `advanceCaptureThresholdArmed` ; `upgradesUsed`, `upgradesUsedRed`, `upgradesUsedBlue` ; `surrenderEvaluatedTier` ; `extraUpgrade[] = {side, name}` (groupes achetés en boutique) ; `lat_long` ; `logisticCenter` ; `warehouseFacility` ; les compteurs de supply régulier (`regularSupplyReady`, `…ExpeditedReady`, `…Progress`, `…Efficiency`, `…StockSide`, `…LossDelays`, `…LocalRecoveryJobs` avec les secondes restantes) ; `pendingCapture` ; `captureObjectTombstones` ; `randomUpgradesRed`, `randomUpgradesBlue` (les noms de templates de garnison tirés pour cette campagne) ; `retiredStaticUpgrades`.
Pour une zone suspendue (unités despawnées), les listes de survivants viennent d'un instantané pris à la suspension, pas des groupes vivants (`zoneCommanderv2.lua:25190-25200`).

**Fiche par vol IA** (`zoneCommanderv2.lua:25441-25509`, `25609-25630`) : nom du groupe, identifiants de capacité du Director, zones d'origine et de cible, camp, mission et type de mission, jeu de templates et nom du template, point d'attente de la CAP, drapeaux de supply, puis `position {x,y,z}`, `headingDeg`, `aliveCount`, `lastStateDuration`, et `capReturnHome`/`airReturnHome` quand le vol n'a plus d'arme pour sa mission (vérifié avec `Unit.getAmmo`).
Les vols à voilure fixe ne sont sauvegardés que si au moins une unité est en vol (`zoneCommanderv2.lua:25618`).

**Fiche par groupe de surface** (`zoneCommanderv2.lua:25510-25562`, `25672-25687`) : mêmes champs d'identité plus `aliveUnitTypes`, `savedState` (`enroute`/`atdestination`), `passedRoadExit`, drapeaux d'artillerie.

**Ce qui n'est pas dans le fichier.**
Les appareils des joueurs, les armes en vol et les vols IA au sol autres que ceux à l'état `takeoff` ne sont pas sauvegardés (`zoneCommanderv2.lua:25567-25572`).
Les positions et les dégâts des unités de garnison ne sont pas sauvegardés : seulement la liste des noms de types survivants par groupe (`zoneCommanderv2.lua:25203-25219`).

## Sauvegarde automatique étalée (conception 6.4.8)

**Mécanisme.**
Un `SCHEDULER` Moose appelle `requestStagedSaveToDisk()` d'abord à 30 s puis toutes les `saveFrequency` = 60 s (`zoneCommanderv2.lua:30328-30330`, `Setup:754`).
Un commentaire interdit les écritures déclenchées par événement : les événements ne mettent à jour que la mémoire (`zoneCommanderv2.lua:30328-30329`).
La demande crée un job et un second `SCHEDULER` qui bat toutes les 0,1 s (`persistenceSaveBatchInterval`) (`zoneCommanderv2.lua:44433-44447`, `17124-17126`).
Phase `collect` : à chaque tick, 8 zones sont collectées (`persistenceSaveBatchSize`), à la fois la fiche de zone et ses groupes IA (`zoneCommanderv2.lua:44466-44479`).
Phase `finalize` : le reste tourne dans une coroutine Lua qui cède la main après chaque lot de 8 enregistrements sérialisés ou de 32 768 octets de texte, ou à des points de contrôle forcés, et qui est reprise une fois par tick de 0,1 s (`zoneCommanderv2.lua:44481-44517`).
Dans la coroutine : `_finalizePersistenceState` (comptes, boutiques, joueurs, export du Director), puis le fichier de rang, puis le fichier de campagne (`zoneCommanderv2.lua:44509-44516`, `44529-44552`).
Le `io.open`/`write` final de chaque fichier est un unique appel bloquant (`zoneCommanderv2.lua:7196-7201`).
Si une nouvelle demande arrive pendant qu'un job tourne, elle est ignorée, sauf si le job n'a pas battu depuis 5 s, auquel cas le job est abandonné et remplacé (`zoneCommanderv2.lua:44411-44428`).
Si une écriture synchrone de la campagne a eu lieu entre-temps (compteur de génération modifié) ou si une réinitialisation de campagne est en attente, le job est annulé (`zoneCommanderv2.lua:44458-44464`).
Une zone marquée « dirty » pendant que la coroutine sérialise est re-sérialisée avant l'écriture : le sérialiseur garde, par zone, l'index de son morceau de texte dans `saveJob.zoneParts.indices` et un ensemble `dirty`, et réécrit les morceaux dirty juste avant `table.concat` (`zoneCommanderv2.lua:7144-7154`, `7188-7194`).
Le seul code qui marque une zone dirty est `ZoneCommander:_requestSurrenderPersistenceRefresh()` : si un job qui n'est pas limité au rang tourne et a déjà collecté cette zone, il re-collecte la fiche de zone dans l'état du job et, si le morceau de la zone a déjà été sérialisé, le marque dirty (`zoneCommanderv2.lua:45984-45992`).
Son unique appelant est l'évaluation de la reddition de la zone, quand le `surrenderEvaluatedTier` de la zone change (`zoneCommanderv2.lua:56011`).
Le mécanisme « dirty » ne protège donc qu'un seul champ, le palier de reddition (la raison, éviter un second tirage de reddition après un redémarrage, est une estimation) ; tout autre changement fait pendant une sauvegarde étalée attend simplement la sauvegarde suivante.
Quand le job se termine, un callback de fin écrit le CSV des entrepôts (seulement quand `WarehouseLogistics == false`) et le fichier pointeur `foothold.status` (`zoneCommanderv2.lua:44553-44575`).
Une variante synchrone `saveToDisk()` construit tout l'état en un seul appel (`zoneCommanderv2.lua:44577-44579`, `25701-25709`).

**Notes de reproduction.**
Le coût étalé est double : `Group.getByName`/`getUnits`/`getLife`/`getDesc` sur chaque unité de garnison de chaque zone (`zoneCommanderv2.lua:25203-25212`), et la construction de chaînes.
L'état n'est pas un instantané cohérent : les zones sont lues sur plusieurs secondes pendant que le jeu tourne.
La conception dépend de la disponibilité de `coroutine` dans l'environnement de la mission et du fait que le `SCHEDULER` Moose traite un retour `nil` comme « continuer » et `false` comme « arrêter » (`zoneCommanderv2.lua:44478`, `44526`).

## Chargement de la campagne et réapplication au démarrage

**Séquence** (fichier de setup, au démarrage de la mission, une passe synchrone) :

1. `BattleCommander:new(filepath, 10, 60)` puis toutes les zones, connexions, articles de boutique et missions sont déclarés (`Setup:754`, `Setup:766` et suivantes).
2. `bc:loadFromDisk()` (`Setup:5835`) : charge le fichier de rang, puis le fichier de campagne (`zoneCommanderv2.lua:44930-44931`).
3. Ajustements dépendant de l'époque et du mode, fonds de départ sur un démarrage PvP neuf, pourcentage de territoire de départ (`Setup:5836-5920`).
4. `bc:init()` (`Setup:5961`) : chaque `ZoneCommander:init()` fait spawner sa garnison à partir de l'état chargé (`zoneCommanderv2.lua:30252-30262`).
5. Restaurations différées planifiées par `init` : vols IA et groupes de surface après 5 s, navigation du porte-avions, captures temporisées après 15 s (`zoneCommanderv2.lua:30283-30286`, `29909`, `30173`, `30199`).
6. `startWarehousePersistence()` : CSV des entrepôts chargé après 5 s, balayage de santé à 12 s (`zoneCommanderv2.lua:112302-112315`).
7. `Foothold CTLD.lua` (chargé 3 s plus tard) : `LoadFARPS` après 1 s, `__Load(1)` de Moose CTLD réinjecte les unités construites (`Foothold CTLD.lua:8100-8101`, `8161`).

**Démarrage neuf ou reprise.**
`bc.saveLoaded = true` quand le fichier a une table `zones` (`zoneCommanderv2.lua:44940-44941`) ; le fichier de setup le remet à `false` quand `zones` est vide (`Setup:5853-5855`).
Une réinitialisation écrit `zonePersistance = {}`, qui n'a pas de clé `zones`, donc le démarrage suivant est neuf (`Setup:2805`, `zoneCommanderv2.lua:7140`).
Sur un démarrage neuf, chaque zone garde le camp, le niveau et les listes d'upgrade donnés dans le fichier de setup.

**Réapplication des zones** (`zoneCommanderv2.lua:44940-45460`, lu en partie) :
`side`, `active`, `isAwaken`, les drapeaux `hasRun` des triggers, les tombstones de capture, les `upgradesUsed*` et les compteurs de supply sont recopiés sur l'objet zone.
Les listes sauvegardées de templates de garnison (`randomUpgradesRed/Blue`) remplacent celles de la config, après élagage des noms qui n'existent plus dans la mission ou qui sont désactivés dans la config, complément, et plafonnement au maximum du template (`zoneCommanderv2.lua:45332-45358`).
Un template manquant est remplacé par un du pool et un message est affiché (`zoneCommanderv2.lua:45366-45388`).
Les entrées `extraUpgrade` (achats en boutique) sont ajoutées à la liste d'upgrade du camp (`zoneCommanderv2.lua:45390-45428`).
Si la liste de garnison a dû changer, les listes de survivants sont abandonnées et la zone respawne à pleine force (`zoneCommanderv2.lua:45359-45363`).

**Garnisons avec pertes.**
Dans `ZoneCommander:init`, pour chaque slot sauvegardé dont la liste de survivants n'est pas vide, le groupe complet est spawné depuis son template (`zoneCommanderv2.lua:51593-51611`).
Puis `weedOutRemainingUnits` détruit les unités en surplus : pour les groupes « Fixed » par nom d'unité exact, à condition qu'au moins un nom sauvegardé existe encore dans le groupe (`zoneCommanderv2.lua:51788-51850`).
Sinon il apparie par type : la liste sauvegardée est convertie en un compte par nom de type, les unités vivantes sont parcourues dans l'ordre, chaque unité dont le `getDesc().typeName` a encore un compte positif est conservée (compte décrémenté) et toute autre unité est détruite avec `Unit:destroy()` (`zoneCommanderv2.lua:51851-51865`).
L'unité d'un type qui survit est donc la première dans l'ordre du groupe, pas celle qui a réellement survécu, et la position et les dégâts sont ceux d'un spawn neuf.
Les groupes listés dans les upgrades de la zone mais absents de `built` sont détruits d'emblée, et les statics de `newStatics` qui ne sont pas dans `built` sont détruits aussi (`zoneCommanderv2.lua:51794-51807`, `51869-51888`).
L'élagage tourne deux fois, 2 s et 4 s après l'appel, par deux `SCHEDULER` à un coup (`zoneCommanderv2.lua:51896-51900`).
Un slot dont la liste sauvegardée est vide n'est pas spawné du tout (`zoneCommanderv2.lua:51612-51614`).
Les upgrades de type static ne sont marqués comme construits que si le static existe encore (`zoneCommanderv2.lua:51599-51604`).

**Vols IA et convois.**
Analysés dans `_pendingAirAiPersistence` et `_pendingSurfaceAiPersistence` au chargement (`zoneCommanderv2.lua:44626-44889`), restaurés 5 s après `init` par un `timer.scheduleFunction` brut (`zoneCommanderv2.lua:29892-29918`, `30156-30178`), et redemandés juste après la fin du chargement des entrepôts (`zoneCommanderv2.lua:112270`).
Le mécanisme est détaillé dans la sous-section suivante.
La mémoire du Director est conservée dans `_pendingDirectorPersistence` et consommée par `Director:_restorePersistence` (`zoneCommanderv2.lua:44601-44624`, `93046`), détaillé après elle.
Les cooldowns sont sauvegardés en *secondes restantes*, pas en temps absolus, parce que le temps de mission repart à zéro à chaque lancement (`zoneCommanderv2.lua:92448-93027`, par exemple `recoveryRemainingSec`, `planningRemainingSec`).

### Restauration des vols IA et convois en cours (lu en entier : `29295-30180`, `68008-68265`, `70141-70470`)

**Deux étapes.**
La restauration ne fait jamais spawner quoi que ce soit elle-même : elle trouve le `GroupCommander` qui possédait le groupe sauvegardé, lui accroche la fiche sauvegardée, force sa machine à états sur `preparing` avec un timer expiré, et lance un `update` pour que le code de spawn propre au commander fasse le travail (`zoneCommanderv2.lua:29866-29870`, `30140-30144`).
`GroupCommander:_processAirPreparing` bifurque alors sur `_pendingInAirRestore` : spawn restauré au lieu d'un spawn neuf (`zoneCommanderv2.lua:68713-68722`) ; la contrepartie de surface consomme `_pendingSurfaceRestore` (`zoneCommanderv2.lua:70782-70784`).

**Conditions d'attente.**
Les deux restaurations attendent l'amorçage de DynamicHybrid (qui génère les commanders) : jusqu'à 12 nouvelles tentatives espacées de 5 s (`zoneCommanderv2.lua:29590-29598`, `30050-30058`).
Les vols sauvegardés à l'état `takeoff` attendent en plus que le CSV des entrepôts soit chargé quand `WarehouseLogistics` est actif, parce qu'un départ au sol prélève des appareils dans l'entrepôt ; les vols en l'air sont restaurés sans attendre (`zoneCommanderv2.lua:29600-29602`, `29877-29889`, `112270`).

**Retrouver le propriétaire d'une fiche sauvegardée** (`_resolveAirPersistenceCommander`, `_resolveSurfacePersistenceCommander`), dans cet ordre :
1. Capacité du Director : si la fiche porte `directorCapabilityId` (ou si son nom de groupe est un identifiant de capacité), la capacité est ré-instanciée avec le nom d'instance sauvegardé, le slot dérivé (2 ou 3) et la génération d'instance ; les écarts de génération et les doublons sont refusés avec une chaîne de raison (`zoneCommanderv2.lua:29301-29387`).
2. Nom exact du commander, aussi après avoir retiré un suffixe `_retasked_…` (`zoneCommanderv2.lua:29406-29423`, `29939-29956`).
3. Nom de base DynamicHybrid (`DYNH-…` sans son suffixe numérique) : le seul candidat, ou le meilleur selon un score sur l'origine (+4), la cible (+4), le rôle (+2), le camp (+2), la mission (+2), le type de mission (+2), la catégorie d'unité (+1), le template (+1) (`zoneCommanderv2.lua:29295-29299`, `29425-29472`, `29958-30004`).
4. Pour les fiches hors supply, tout commander compatible par score de métadonnées : origine +3, cible +4, camp +3, mission +3, type de mission +3, catégorie d'unité +2, template +2, accepté à partir de 10 points pour l'air et 9 pour la surface (`zoneCommanderv2.lua:29473-29500`, `30005-30031`).
5. Dernier recours pour une fiche DynamicHybrid sans propriétaire : un nouveau `GroupCommander` est construit à partir des champs sauvegardés (hélicoptères de supply achetés en boutique pour l'air ; n'importe quel rôle pour la surface), ajouté à la zone d'origine et enregistré auprès du suivi DynamicHybrid, et le compteur de noms DynamicHybrid est relevé jusqu'au suffixe sauvegardé (`zoneCommanderv2.lua:29522-29571`, `30074-30112`).
Une fiche sans propriétaire est abandonnée avec une ligne `env.info` (`zoneCommanderv2.lua:29782`, `29872`, `30146`).

**Les vols sauvegardés à l'état `takeoff`** (`spawnNowTakeoff`) ne sont pas restaurés sur place : le commander est mis en `preparing` avec `_spawnNowImmediateCheck`, si bien qu'il effectue aussitôt un lancement neuf normal depuis sa base (`zoneCommanderv2.lua:29771-29780`).
Ils sont ignorés quand la zone d'origine a changé de camp ou est suspendue (supply de boutique et supply régulier depuis une zone suspendue exceptés) (`zoneCommanderv2.lua:29637-29641`).
En PvP, une CAP ordinaire dans cet état n'est pas relancée : elle est remise aux données de sauvegarde en attente du Director comme un timer de CAP ou un membre d'opération avec un délai restant nul, pour que le Director la relance selon ses propres règles (`zoneCommanderv2.lua:29631-29636`, `29642-29701`).

**État de sortie recopié sur le commander avant le spawn** (`zoneCommanderv2.lua:29825-29856`) : camp de la sortie, origine du supply régulier, drapeaux de lancement depuis la boutique et de supply payé, retour à la base du supply, altitude de CAS, point d'attente de CAP avec distance d'orbite et marge, retour SAM de la CAP, cible de retasking de la CAP, retour à la base de la CAP avec ses secondes écoulées et son drapeau de slot libéré, les drapeaux d'advance capture et son point d'attente, la cible et la mission d'origine du retasking du Director, et la zone cible courante.

**Recréation en vol** (`GroupCommander:_processAirRestoredSpawn`) :
- Position : le `{x,y,z}` sauvegardé ; un avion de CAS ou de SEAD sauvegardé plus loin que `max(2 × route distance, 100 NM)` à la fois de sa base et de sa cible n'est pas restauré (`zoneCommanderv2.lua:68044-68078`, `67025-67043`).
- La position est corrigée selon la mission : un groupe de CAS sauvegardé au-delà de sa ligne d'engagement est ramené à 1 NM avant un point situé 5 NM (hélicoptère) ou 20 NM (avion) avant la cible sur l'axe base-cible ; les hélicoptères et avions de supply reçoivent un point calculé vers leur destination, ou vers la base quand ils reviennent ou quand la cible n'est plus valide (`zoneCommanderv2.lua:68079-68107`, `67045-67089`, `59692-59711`).
- Altitude : celle sauvegardée pour les avions ; pour les hélicoptères la hauteur sol sauvegardée bornée à 60–300 m, ou 1500 ft AGL quand aucune altitude n'a été sauvegardée (`zoneCommanderv2.lua:68109-68124`).
- Le template (`templateName` sauvegardé, sinon le dernier template du commander ou celui résolu) est copié, ses unités sont déplacées au point sauvegardé en gardant leurs décalages de formation tournés selon le cap sauvegardé, et sa route est remplacée par deux waypoints « Turning Point » espacés de 2 NM le long de ce cap, avec des tâches vides (`zoneCommanderv2.lua:68057-68065`, `68126-68173`).
- Le spawn est `SPAWN:NewFromTemplate(tpl, restoreTemplate, alias, true):InitSkill(...):OnSpawnGroup(...):Spawn()`, un départ en vol parce que le premier waypoint est un turning point ; le Rouge utilise `AiPlaneSkill`, le Bleu « Excellent » (`zoneCommanderv2.lua:68184-68187`, `68245`).
- Dans le callback de spawn : état `inair`, `lastStateTime = now − lastStateDuration` (pour que les timers de sortie reprennent), camp forcé au camp sauvegardé, et unités au-delà de `aliveCount` sauvegardé détruites en partant de la fin du groupe (`zoneCommanderv2.lua:68199-68225`).
- 0,5 s (CAS) ou 2,5 s (autres) plus tard, `_assignRestoredAirMission` donne au groupe sa vraie route avec `_assignMissionAfterInAirRestore`, en réessayant toutes les 0,5 s jusqu'à 10 fois tant que le groupe n'est pas encore disponible, et en réveillant d'abord une zone cible en suspension « idle » (attente jusqu'à `idleZoneWakeHoldSec` = 120 s) (`zoneCommanderv2.lua:68233-68242`, `68008-68042`, `67335`, `8466`).
- Un échec d'assignation de route est affiché à l'écran à tout le monde pendant 15 s (`zoneCommanderv2.lua:68035-68040`).
- Les armes tirées et le carburant brûlé ne sont pas restaurés : le groupe revient avec l'armement du template ; seul l'état « plus d'arme, retour à la base » est porté par `capReturnHome`/`airReturnHome` (`zoneCommanderv2.lua:68234-68235`, `25609-25630`).

**Recréation de surface** (`GroupCommander:_processSurfaceRestoredSpawn`) :
- La restauration n'est autorisée que si les zones ont encore un sens : la zone contenant le point sauvegardé, la zone de départ et la zone cible sont vérifiées par rapport au camp sauvegardé (une attaque exige une cible ennemie, un supply une cible amie ou neutre ou une base valide au retour, une artillerie qui rentre une base amie) (`zoneCommanderv2.lua:70158-70222`).
- Le template est copié avec le cap sauvegardé ; la route est reconstruite **à partir du point sauvegardé** : route routière restante vers la cible ou la base pour `enroute`, route de retour à la base pour une artillerie qui rentre, tronçon direct hors route à deux points vers le point d'attente sauvegardé pour un convoi d'advance capture qui attend une zone neutre, route d'attaque dans la zone pour un groupe d'attaque sauvegardé `atdestination` (`zoneCommanderv2.lua:70257-70371`, `69018-69193`).
- Si aucune route ne peut être construite, le groupe est retiré (`dead`) au lieu d'être spawné (`zoneCommanderv2.lua:70330-70352`).
- Le spawn est `SPAWN:NewFromTemplate(tpl, restoreTemplate, self.name, true)` à la position sauvegardée (`zoneCommanderv2.lua:70382-70390`).
- Dans le callback : état fixé sur `enroute`/`atdestination` sauvegardé, timers repris avec `lastStateDuration`, drapeaux restaurés, puis le masque des vivants est appliqué : avec `aliveUnitTypes`, les unités sont conservées par type jusqu'au compte sauvegardé et les autres détruites ; sans lui, les unités au-delà de `aliveCount` sont détruites (`zoneCommanderv2.lua:70411-70421`, `70455`, `69196-69230`).
- La tâche du contrôleur est dépilée et la route reconstruite poussée 5 s plus tard (`zoneCommanderv2.lua:70456-70467`).
- Sur Normandie, un cuirassé est d'abord déplacé vers un point d'eau sûr (`zoneCommanderv2.lua:70236-70248`).

Après les deux passes, chaque fiche sauvegardée est proposée à `_retryDirectorSavedInstanceDisposal`, qui jette les instances Director à la demande finalement inutilisées (`zoneCommanderv2.lua:29877-29885`, `30150-30153`, `26552`).

### `Director:_restorePersistence` (lu en entier : `93046-94266`)

Elle tourne au premier tick prêt du Director, refuse une table dont la `version` n'est pas 1 ou dont le `side` diffère, et reconstruit chaque mémoire avec une validation par rapport à la mission courante (`zoneCommanderv2.lua:93046-93047`, `95815-95818`).
Chaque `…RemainingSec` devient `now + remaining`, et chaque `…ElapsedSec` devient `now − elapsed` (`zoneCommanderv2.lua:93051-93052`, `93079-93080`, `93919-93934`).
Les entrées qui nomment un groupe, une capacité ou une zone qui n'existe plus sont abandonnées (historique au sol et cooldowns de réutilisation : `zoneCommanderv2.lua:93054-93082`).
Les slots de CAP sont reconstruits un par un : le propriétaire est re-résolu par `_restoreDirectorPersistenceCommander`, un état inconnu retombe sur `cooling`, un slot dont le propriétaire ne peut pas être restauré est remis à `cooling` sans propriétaire, et les champs de récupération après perte sont ré-ancrés sur `now` (`zoneCommanderv2.lua:93083-93183`).
Puis, dans l'ordre du fichier : mémoire du front de campagne, stratégie de campagne (nom et zone/région but validés), action de campagne, posture aérienne, décision de réaction aérienne, engagement de zone Bleu et timers Bleu, timers de groupes de CAP, compteur d'opérations, les trois tables de résultats, `history`, historique et cooldown des upgrades de zone, les timers de budget stratégique, intention et historique, le cooldown de frappe aérienne tactique et la dernière cible, la demande AIEN, les deux mémoires de renseignement, les timers de récupération/planification/surge, la réaction en attente, les transferts de frappe tactique et les déroutements de capture CAS, et enfin l'opération en cours (`zoneCommanderv2.lua:93184-93558`).
Détails de la partie médiane (`93196-93880`, lue à la seconde passe) :
- Les tables de résultats (`doctrineOutcomes`, `targetOutcomes`, `roleOutcomes`) passent par `_restoreDirectorOutcome`, qui redate chaque ligne à partir de son âge sauvegardé ; les lignes de cible sont abandonnées quand la zone n'existe plus, et les champs d'apprentissage de l'axe secondaire ne sont restaurés que s'ils sont plus jeunes que l'expiration du renseignement (`93239-93276`).
- `history` garde au plus `historySize` entrées dont la zone cible existe encore ; `zoneUpgradeHistory` au plus 4 ; `strategicBudgetHistory` au plus 6 entrées dont l'action est encore une action de boutique connue (`93277-93297`, `93337-93351`).
- L'intention de budget stratégique n'est restaurée que si son action est connue, que sa zone cible existe et qu'il lui reste du temps ; le timer de décision retombe sur le délai initial du profil de difficulté quand il est absent de la sauvegarde (`93298-93336`).
- La demande de soutien aérien AIEN n'est restaurée que si le système réactif est démarré avec le soutien AIEN activé et que la zone est toujours une zone Rouge utilisable (`93356-93378`).
- Une réaction Rouge en attente est remise en file avec son allocation, son mode, son délai de nouvel essai et son expiration (`93384-93406`).
- Les transferts de frappe tactique et les déroutements de capture CAS ne sont rattachés de nouveau à leur groupe que si ce groupe est retrouvé (par sa capacité Director, son nom ou son nom de base DynamicHybrid) et est vivant ou en préparation ; un CAS hélicoptère dérouté se voit réappliquer sa cible de déroutement (`93408-93553`).
- L'opération n'est restaurée que si le `state` sauvegardé est valide pour le camp (`shaping`/`assault`/`exploit`/`surge` pour le Rouge PvE, `support` pour le Bleu et le PvP) et que sa zone cible est encore active, visible, non suspendue et n'est pas un porte-avions ; sinon le Director démarre en `recovery` (Rouge) ou `waiting` (Bleu) (`93554-93568`).
- Champs de l'opération : chaque horloge est reconstruite à partir de secondes écoulées ou restantes (`startedAt`, `phaseDeadline`, `mainAuthorizeAt`, heures de réévaluation et de porte SEAD), chaque ratio est borné à 0–1, les noms de zones sont vérifiés, et les champs de preuve de rôle absents sont recalculés à partir de la zone vivante (`93569-93770`).
- Chaque assignation est re-liée à un commander dans cet ordre : instance de capacité Director, nom exact, nom de base DynamicHybrid ; celle dont la route ne correspond plus à sa cible (après annulation ou réapplication d'un retasking) est abandonnée ; en PvP, une assignation dont la capacité n'est pas encore instanciée est gardée comme enregistrement en file (`93776-93880`).
- Après le re-liage, les drapeaux sont remis en cohérence avec la réalité : un groupe vivant est `launched`, un groupe lancé désormais dormant est `completed`, un CAS à voilure fixe derrière une porte SEAD encore bloquée est dé-autorisé, et les CAS/SEAD Bleus (et les rôles de combat PvP) pas encore lancés sont mis en file pour capacité au lieu d'être autorisés (`93961-94060`).
L'opération est restaurée assignation par assignation : chacune est re-liée à son commander vivant ou à sa capacité, avec son rôle, sa phase, sa cible, ses drapeaux `authorized`/`launched`/`completed`, ses compteurs de kills, ses champs de réserve et de porte SEAD (`zoneCommanderv2.lua:93882-93960`).
Un enregistrement de soutien CAP d'ingress SEAD est recréé et une CAP lancée est re-routée vers le point d'ingress (`zoneCommanderv2.lua:94200-94242`).
Si aucune assignation de combat ne survit, une opération Rouge PvE est libérée et le Director démarre en `recovery` ; sinon le `state` sauvegardé est repris (`zoneCommanderv2.lua:94247-94263`).

**Boutiques et comptes.**
`accounts` remplace les soldes des coalitions et le stock de la boutique est restauré article par article avec un repli sur le stock par défaut (`_resolveSavedShopStock`, `zoneCommanderv2.lua:45642`).

**Notes de reproduction.**
Le chargement est tolérant par conception : chaque nom restauré est vérifié par rapport à la mission et à la config courantes, donc une mise à jour de la mission entre deux sessions ne casse pas une sauvegarde.
La restauration dépend de l'ordre « tout déclarer → charger → init » : les objets zone doivent exister avant que le fichier soit appliqué, et rien n'est spawné avant `init`.

## Persistance des entrepôts (`WarehousePersistence`)

**Ce que voit le joueur.**
Messages `WAREHOUSE_PERSISTENCE_STARTED` au démarrage et `WAREHOUSE_PERSISTENCE_LOADED` (nombre, nom du fichier) après le chargement (`zoneCommanderv2.lua:112309`, `112249`).

**Ce que voit l'administrateur.**
Actif en totalité quand `WarehouseLogistics == true`, ce qui est la valeur par défaut (`Config:1279`, `zoneCommanderv2.lua:112308-112310`).
Quand `WarehouseLogistics == false`, un mode réduit tourne avec les options `force` et `warehouseOnly` (`zoneCommanderv2.lua:112311-112314`, `44554-44556`).

**Mécanisme.**
Fichier `<base>_storage.csv`, en-tête `AIRBASE;KIND;NAME;QTY` (`zoneCommanderv2.lua:112003`).
Types de lignes : `B` marque un bloc d'aérodrome, `W` est un article d'arme et sa quantité, `P` est une quantité pour une règle d'arme « gérée » de `WarehouseWeaponLocationPolicy` (`zoneCommanderv2.lua:112025-112038`).
Seules les armes sont stockées (articles d'inventaire dont le nom commence par `weapons.` plus les articles adressés par une clé wsType à 4 nombres) ; les quantités illimitées (1073741823) et zéro sont ignorées (`zoneCommanderv2.lua:111898-111945`).
Les appareils et le carburant ne sont pas dans ce fichier (`zoneCommanderv2.lua:111898-111956`).
Les navires et porte-avions sont ignorés ; les FARP CTLD nommés `CTLD FARP ZELL …` sont inclus (`zoneCommanderv2.lua:111508-111520`).
La sauvegarde parcourt les aérodromes un par seconde avec un `TIMER` Moose (repli sur `SCHEDULER`), lit `STORAGE:FindByName(ab)` puis `GetInventory`/`GetItemAmount`, et écrit le fichier une seule fois à la fin avec `UTILS.SaveToFile` (`zoneCommanderv2.lua:112009-112066`).
En mode `warehouseOnly`, les lignes des aérodromes non réécrits sont reprises du fichier précédent (`zoneCommanderv2.lua:111990-111999`, `112054-112064`).
Le chargement lit le CSV avec `UTILS.LoadFromFile`/`UTILS.Split` et applique les quantités à chaque `STORAGE` ; une zone bleue suspendue dont le stock moyen est inférieur à 500 reçoit 500 de chaque article de réparation (`zoneCommanderv2.lua:112079-112125`, `112225-112246`).
Les FARP reconstruits au démarrage retardent le chargement des entrepôts jusqu'à ce qu'ils existent (`zoneCommanderv2.lua:111570-111630`, `112261-112268`).
Moose : `STORAGE` est une fine enveloppe autour de l'objet `Warehouse` de DCS.
`STORAGE:New(name)` fait `Airbase.getByName(name):getWarehouse()` et garde le résultat dans `self.warehouse` (`Moose_2026-10-11.lua:35671-35679`) ; `STORAGE:FindByName` ne renvoie que l'instance que Moose a enregistrée pour cet aérodrome dans sa base (`Moose_2026-10-11.lua:35698-35701`, `12649`).
Chaque méthode est un appel DCS : `AddItem` → `warehouse:addItem(name, n)`, `SetItem` → `warehouse:setItem`, `RemoveItem` → `warehouse:removeItem`, `GetItemAmount` → `warehouse:getItemCount(name)`, `GetInventory` → `warehouse:getInventory(item)` qui renvoie ses tables `aircraft`, `liquids` et `weapon` (`Moose_2026-10-11.lua:35710-35727`, `35838-35841`).
Les objets cargo utilisent à la place `Warehouse.getCargoAsWarehouse(staticOrUnit)` (`Moose_2026-10-11.lua:35680-35697`).
`AIRBASE:FindByName` est utilisé à côté de `Airbase.getByName` brut (`zoneCommanderv2.lua:111512-111518`).

**Notes de reproduction.**
La sauvegarde est étalée à raison d'un aérodrome par seconde (`zoneCommanderv2.lua:112005`, `112048-112052`) ; la raison (lecture lente de l'inventaire) est une estimation.
Une réinitialisation en cours interrompt une sauvegarde en cours et tronque le fichier (`zoneCommanderv2.lua:111864-111890`, `112011-112015`).

## Fichier de rang et de statistiques des joueurs (`Foothold_Ranks.lua`)

**Ce que voit l'administrateur.**
Écrit seulement quand `RankingSystem == true`, ce qui est la valeur par défaut (`Config:285`, `zoneCommanderv2.lua:44357`).
Un seul fichier pour toutes les cartes, époques et modes (`Setup:756`, `zoneCommanderv2.lua:44332-44341`).
Il n'est pas effacé par une réinitialisation de campagne : pendant une réinitialisation, le job étalé tourne en mode `rankOnly` (`zoneCommanderv2.lua:44434`, `44509-44511`).

**Contenu** (`zoneCommanderv2.lua:43358-43419`, `44356-44378`) :
`players[ucid]` = `{name, lastSeen, credits, career = {…}, aircraft = {…}}` (`zoneCommanderv2.lua:44089`, `44104`, `44404`) ;
`playerAliases[oldName] = ucid` (ou `false` quand ambigu) ;
`legacyPlayers[name]` pour les fiches créées avant les clés UCID ;
`ewrs[ucid]`, `selfJtac[ucid]` réglages compacts par joueur avec `ewrsVersion`/`selfJtacVersion` ;
`version`, `playerIdentityVersion` (2), `settingsIdentityVersion` (1).
Le rang est dérivé, pas stocké : c'est l'indice du plus haut seuil qui ne dépasse pas `credits` (`zoneCommanderv2.lua:44385-44394`).
Les séries de kills en cours sont effacées au chargement (`zoneCommanderv2.lua:44345-44353`).
Des migrations de schéma tournent au chargement : les fiches indexées par nom passent en clé UCID quand le nom correspond à exactement un UCID connu, sinon elles passent dans `legacyPlayers` (`zoneCommanderv2.lua:43381-43395`).
Une garde refuse de sauvegarder si le chargement a échoué (`zoneCommanderv2.lua:44358`, `25715`).

## Cycle de vie de la campagne : fin, réinitialisation et redémarrage

**Ce que voit le joueur.**
Victoire PvE : quand aucune zone non cachée n'est rouge, le son `BH.ogg` est joué au Bleu et soit le message `MISSION_COMPLETE_AUTORESTART` est affiché, soit `MISSION_COMPLETE_MANUAL_RESTART` plus un sous-menu F10 de la coalition bleue `MENU_RESTART_AND_RESET` avec Oui/Non (`Setup:2786-2830`).
Défaite PvE : quand aucune zone non cachée n'est bleue, « Mission failed, Server restarting... » et une réinitialisation et un redémarrage inconditionnels (`Setup:2784-2812`).
PvP : un camp gagne quand l'autre ne détient aucune des `pvpVictoryZones` ; mêmes deux branches, le menu va au camp vainqueur (`Setup:2736-2779`).

**Ce que voit l'administrateur.**
`AutoRestart` (par défaut `false`) : réinitialisation et redémarrage automatiques à la victoire (`Config:242-244`).
Commandes par marqueur : `StartaOm` (ou l'alias `restartMission`) positionne le flag 181 sans réinitialiser ; `AvslutaFoothold` (ou l'alias `endMission`) exécute `forceMissionComplete()` (`zoneCommanderv2.lua:29242-29245`, `28903-28911`, `Config:3505-3512`).

**Mécanisme.**
La vérification de victoire est un callback de trigger de zone enregistré sur `lost` et `destroyed` de chaque zone (et `captured` en PvP), plus une exécution planifiée après le démarrage (`Setup:2836-2849`).
Réinitialisation = `bc._persistenceResetPending = true`, puis `Utils.saveTable(bc.saveFile, 'zonePersistance', {})`, puis `resetSaveFileAndFarp()` qui tronque la sauvegarde CTLD, la sauvegarde CTLD rouge et le fichier FARP, et en PvP aussi le CSV des entrepôts, et arrête les timers FARP (`Setup:2800-2808`, `Foothold CTLD.lua:8113-8152`).
`_persistenceResetPending` bloque ensuite toute écriture de campagne ultérieure pour le reste de la session (`zoneCommanderv2.lua:44548`, `44458`, `111970`).
Redémarrage = `trigger.action.setUserFlag(181, true)` cinq secondes plus tard (`Setup:2809-2811`).
Le flag 181 est consommé par le trigger de mission 7, `a_end_mission("blue", "", 0)` (`mission:63,92`).
Aucun appel `net.load_mission` ni `net.dostring_in` n'existe dans `zoneCommanderv2.lua` (le grep ne renvoie rien) : après `a_end_mission`, le rechargement de la mission est laissé à la liste de missions du serveur dédié ou à un outil externe (estimation pour ce qui se passe ensuite).
Le flag 180 est positionné quand la mission est terminée et lu par le fichier de setup pour couper les annonces de mission (`Setup:2796`, `Setup:6202`).
`forceMissionComplete` duplique la branche de victoire PvE (`zoneCommanderv2.lua:28111-28147`).
Un simple redémarrage du serveur sans réinitialisation reprend la campagne à partir de la dernière sauvegarde automatique (`zoneCommanderv2.lua:30330`).

## Interrupteurs d'époque et de mode

**Ce que voit l'administrateur.**
`Era = "Modern"` | `"Coldwar"` | `"Vietnam"` (`"Gulfwar"` sur l'Irak) et `PvP = false` dans la config (`Config:196-202`).
`PvP` n'est pris en compte que sur Caucasus, Syrie et Golfe Persique (`Config:3525`).

**Ce qu'ils commutent** (setup Caucasus) :
le nom de base de la sauvegarde, donc une campagne séparée par époque et par mode (`Setup:467-477`) ;
les noms de templates par suffixe (`_CW`, `_VT`, `Coldwar`) pour les templates de CAP, CAS, SEAD, bombardiers, blindés et drone JTAC (`Setup:3049`, `3331`, `3446`, `3621`, `4299`, `5290`) ;
le SAM bleu de défense ponctuelle, HAWK ou NASAMS (`Setup:32`) ;
les articles de boutique retirés après le chargement : `zsam` et `zcram` hors Modern, `zpat` au Vietnam (`Setup:5844-5851`) ;
l'activation du porte-avions, désactivé au Vietnam (`Setup:5982-5990`) ;
les listes d'appareils autorisés par camp (`Setup:441-463`) ;
`GlobalSettings.pvpEnabled = (PvP == true)` (`Setup:440`), testé dans tout le moteur (par exemple `zoneCommanderv2.lua:17085-17112`).
L'époque est une constante fixée au chargement : les templates de toutes les époques sont présents dans l'unique `.miz` et le script les choisit par leur nom.

## Identification des joueurs

**Mécanisme.**
À l'exécution, presque tout est indexé par **nom de joueur** (`Unit:getPlayerName()`) : statistiques, contributions, locale, zone de spawn (`zoneCommanderv2.lua:42931-42933`, `101412-101420`, `Foothold_Localization.lua:20931-20948`).
Pour la persistance, le nom est résolu en **UCID** : le moteur parcourt `net.get_player_list()`, apparie `net.get_name(pid)` au nom, puis lit `net.get_player_info(pid, 'ucid')` (`zoneCommanderv2.lua:43685-43708`, `41170-41192`).
La recherche nom → pid est mise en cache et re-validée à chaque usage (`zoneCommanderv2.lua:41171-41183`).
Un renommage est détecté quand un UCID connu arrive avec un nouveau nom : l'ancien nom devient un alias de l'UCID, et un alias revendiqué par deux UCID est marqué ambigu (`false`) (`zoneCommanderv2.lua:43727-43739`).
Les fiches créées avant les clés UCID restent sous `legacyPlayers[name]` et sont réclamées par la première connexion vérifiée portant ce nom (`zoneCommanderv2.lua:43467-43471`, `43743-43744`).
La synchronisation d'identité tourne à chaque spawn de joueur et, pour tous les joueurs connectés, à chaque sauvegarde automatique (`zoneCommanderv2.lua:101468`, `44430-44432`, `43781-43802`).
Les noms de joueurs contenant `'`, `/` ou `\` sont refusés : le joueur est renvoyé en spectateur avec le message `PLAYER_ILLEGAL_NAME_CHARACTERS` (`zoneCommanderv2.lua:101418`, `101427-101430`).
Cette restriction correspond à la réparation de sauvegarde qui abandonne les lignes à clés ressemblant à des chemins (`zoneCommanderv2.lua:7263-7268`).

**Notes de reproduction.**
Les fonctions `net.*` n'ont de sens que sur un serveur ; sur une session solo, `net.get_player_list()` ne renvoie rien d'utile, d'où le commentaire « listen-server host » (`zoneCommanderv2.lua:43709`).
Les appareils multicrew sont gérés en résolvant l'équipage d'un slot par `net.get_player_info(pid, 'slot')` (`zoneCommanderv2.lua:41194-41196`, `40562`).

## Gestion du spawn des joueurs et contrôle des slots

**Ce que voit le joueur.**
Spawn dans une zone détenue par l'autre coalition : message de chat `PVP_CANNOT_SPAWN_IN_ZONE`, un texte à l'écran de 5 s, l'appareil est détruit et le joueur est déplacé en spectateur (`zoneCommanderv2.lua:101447-101452`, `101040-101049`).
Avec `PVE_Only = true`, tout slot rouge est refusé de la même façon avec `PVP_MODE_DISABLED_RED_SLOTS` (`zoneCommanderv2.lua:101431-101434`, `Config:247-251`).
Sur un spawn accepté, le groupe du joueur reçoit ses menus F10 (statistiques et langue, missions, logistique quand le type est autorisé, EWRS, contrôle du porte-avions et du ravitailleur) (`zoneCommanderv2.lua:101473-101500`).

**Ce que règle le créateur de mission.**
Aucune convention de nommage n'est nécessaire pour les groupes clients : à l'init, tout template de groupe dont la première unité a le skill `Client` et dont la position se trouve dans une zone est rattaché à cette zone comme « groupe restreint » (`zoneCommanderv2.lua:27186-27205`).
Les zones marquées `isHidden` ne restreignent pas les spawns (`zoneCommanderv2.lua:101447`).

**Mécanisme — trois couches.**
1. *Coalition de l'aérodrome* : quand une zone change de camp, `Airbase.getByName(name):setCoalition(side)` est appelé après `autoCapture(false)`, et un `S_EVENT_BASE_CAPTURED` synthétique est injecté avec `world.onEvent` (`zoneCommanderv2.lua:56753-56767`, `51439-51476`).
DCS lui-même refuse alors les slots d'un aérodrome détenu par l'autre coalition (estimation : comportement du moteur, pas dans le script).
2. *User flags* : pour chaque groupe client restreint, `trigger.action.setUserFlag(<groupName>, blocked)` est positionné à l'init de la zone et revérifié à chaque mise à jour de zone (`zoneCommanderv2.lua:51745-51747`, `55197-55202`).
La valeur du flag est 1 quand la coalition du groupe diffère du propriétaire de la zone.
Rien dans la mission ne lit ces flags : ils sont prévus pour un hook de blocage de slots côté serveur qui lirait un flag nommé d'après le groupe (estimation ; aucun hook de ce genre n'est livré dans le dépôt).
3. *Événement de naissance* : `S_EVENT_BIRTH` (testé comme `eventId == 15`) avec un nom de joueur appelle `LogisticCommander:_handleBirth` (`zoneCommanderv2.lua:42931-42947`).
Il trouve la zone qui contient l'unité et, quand le propriétaire diffère, appelle `_rejectPlayerSpawn` : `net.send_chat_to(message, pid)`, `net.force_player_slot(pid, 0, '')` après 0,1 s, `outTextForGroup`, puis `event.initiator:destroy()` (`zoneCommanderv2.lua:101029-101049`, `101443-101452`).
Cette troisième couche est la seule qui fonctionne sans hook serveur, et elle couvre aussi les slots de spawn dynamique et les slots de départ au sol hors aérodromes, puisqu'elle ne teste que la position de l'unité (`zoneCommanderv2.lua:101413`).

Sur un spawn accepté, `_handleBirth` aussi : efface l'état de respawn précédent du joueur, enregistre la zone de spawn (`playerZoneSpawn[player]`), synchronise l'identité UCID, lie l'identifiant du groupe à la locale du joueur, incrémente un « jeton de menu » par groupe, enregistre le groupe dans `activeAircraftGroupsById`, démarre un vol de carrière si le spawn est en l'air, enregistre auprès d'EWRS, et construit les menus (`zoneCommanderv2.lua:101421-101480`).
Le jeton de menu (`groupMenuTokens[groupid]`) est comparé par chaque callback différé pour que le travail planifié pour un occupant précédent du même identifiant de groupe soit abandonné (`zoneCommanderv2.lua:97779`, `101056-101058`, `101490`).

**Disponibilité des appareils dans l'entrepôt.**
Les comptes d'appareils par aérodrome sont gérés via l'entrepôt DCS (`STORAGE`), avec des listes `allowedPlanes*` par époque et par camp et une table `restockAircraft` dans la config (`Config:2622`, `Config:3144`, `Setup:441-463`) ; cela n'a pas été analysé ici (voir « Vu hors de ce thème »).

**Notes de reproduction.**
`net.force_player_slot` et `net.send_chat_to` sont appelés depuis l'environnement de la mission (`zoneCommanderv2.lua:101034-101036`).
Le handler de naissance détruit l'appareil après coup, donc le joueur voit le cockpit un instant.
DCS réutilise les identifiants de groupe pour les slots de spawn dynamique, ce qui explique le jeton de menu (estimation pour la raison ; le mécanisme du jeton est lu).

## Suivi du décollage, de l'atterrissage, de l'éjection et de la mort

**Mécanisme.**
Tout cela est accroché à l'unique `world.addEventHandler` de `BattleCommander:init` (`zoneCommanderv2.lua:30228-30232`).
`S_EVENT_TAKEOFF` : pour un joueur, marque l'origine porte-avions, signale le self-JTAC comme en vol, démarre le vol de carrière pour tout l'équipage, arme l'état « récompense à l'atterrissage », évalue les conditions de nuit (récompense de nuit, comportement des SAM de nuit), avertit quand un appareil de supply décolle à vide (`zoneCommanderv2.lua:42948-42977`, `101793-101829`).
`S_EVENT_LAND` : pour un joueur, `_handleRewardPlayerLanding` verse la contribution en attente si le lieu d'atterrissage est éligible ; pour une IA, `_handleRewardAiLanding` (`zoneCommanderv2.lua:43096-43103`).
Un `S_EVENT_LAND` synthétique est injecté avec `world.onEvent` pour les joueurs déjà posés dans une zone au moment où elle est capturée, afin qu'ils soient payés sans redécoller (`zoneCommanderv2.lua:56722-56745`, `41324`).
`S_EVENT_EJECTION`, `S_EVENT_PILOT_DEAD`, `S_EVENT_UNIT_LOST`, `S_EVENT_KILL`, `S_EVENT_SCORE` alimentent le code de récompenses et de pénalités (`zoneCommanderv2.lua:43024-43031`, `43060-43106`).
`S_EVENT_LANDING_AFTER_EJECTION` crée la fiche de pilote abattu utilisée par le CSAR (`zoneCommanderv2.lua:42978-42990`).
`S_EVENT_DEAD` d'un objet d'aérodrome (piste détruite) bloque les spawns d'avions IA dans cette zone pendant 3300 s (`zoneCommanderv2.lua:42906-42920`).
`S_EVENT_SHOT` d'un `Hercules` de joueur pilote le supply par largage cargo aérien (`zoneCommanderv2.lua:42921-42930`).
Toutes les 60 s, un scheduler retire les contributions en attente des joueurs qui ne sont ni dans un appareil de ce camp ni connectés de ce côté (`zoneCommanderv2.lua:43108-43148`).

## Tirs fratricides

**Ce que voit le joueur.**
Message `FRIENDLY_FIRE_PLAYER` (tueur, victime) ou `FRIENDLY_FIRE_UNIT` (tueur, nom de l'unité), suivi de `FRIENDLY_FIRE_RANK_LOSS` quand une pénalité s'applique (`zoneCommanderv2.lua:42648-42670`).

**Ce que voit l'administrateur.**
`FriendlyFireRankPenalty = 500` crédits, 0 désactive la pénalité (`Config:288`, `zoneCommanderv2.lua:42657-42658`).

**Mécanisme.**
Dans le chemin de récompense de `S_EVENT_KILL`, un kill dont la cible est du camp du tueur appelle `_handleRewardFriendlyKill`, qui incrémente le compteur de carrière `FriendlyKills`, retire des points aux statistiques de session et retire des crédits de rang (`zoneCommanderv2.lua:42641-42670`, `42879`, `44207-44212`).
Le script ne fait ni exclusion, ni bannissement, ni retrait de slot (`zoneCommanderv2.lua:42641-42675`).

## Commandes par marqueurs de carte, admin et joueur

**Ce que voit le joueur.**
Les commandes sont saisies comme texte d'un marqueur de carte F10 ; le marqueur est supprimé quand la commande est acceptée (`zoneCommanderv2.lua:29246-29248`).
Ouvertes à tous : `help`, `buy` / `buy:<item>`, `status`, `stats`, `top`, `mystats`, `missions`, `intelstatus`, `whynot`, `jtac-code:<code>`, marqueurs de station de ravitailleur et de CAP `arcohere1/2`, `texacohere1/2`, `caphere1/2`, `tarawahere…` (`zoneCommanderv2.lua:28356-28404`, `7403-7414`).

**Ce que voit l'administrateur.**
Il n'y a **aucune liste d'admins** : aucune vérification d'UCID ou de nom n'existe dans le handler de marqueurs ; une commande admin n'est protégée que par le secret de son mot (`zoneCommanderv2.lua:28455-28470`).
Avec `AdminCommands = false` (par défaut), les mots intégrés s'appliquent, plusieurs en suédois : `köp`, `rensa`, `upgradera`, `maxxa`, `blå`, `röd`, `StartaOm`, `AvslutaFoothold`, `addfunds:<n>`, `addfundsred:<n>`, `additems…`, `givemefarp…` (`zoneCommanderv2.lua:28885-28911`, `29242`, grep de `not adminAliases and` dans `28470-29245`).
Avec `AdminCommands = true`, ces mots intégrés sont désactivés et remplacés par les mots fixés dans `AdminCommandAliases` : `addBlueFunds`, `addRedFunds`, `addZoneItems`, `buyWithoutRank`, `createFarp`, `captureNeutralBlue`, `captureNeutralRed`, `clearZone`, `upgradeZone`, `fullyUpgradeZone`, `restartMission`, `endMission` (`zoneCommanderv2.lua:28423-28436`, `Config:3468-3512`).
Un alias est rejeté s'il contient `:` ou un saut de ligne, s'il est vide, s'il entre en collision avec une commande intégrée, ou s'il est utilisé deux fois (`zoneCommanderv2.lua:28409-28422`).
Les autres mots intégrés ne sont pas aliasables et restent actifs dans les deux modes : `debug`, `spawn`, `prepp`, `addshop`, `removeshop`, `upgradeallred`, `upgradeallblue`, `event`, `event:<name>`, `recapture`, `capture:<…>`, `givemesupplies`, `addrank:<player>,<n>`, `Message:<text>`, `SpelaMusik`, `ConfigStatus`, `debughelp`, `adminbuy` (nécessite `AllowAdminBuy`) (`zoneCommanderv2.lua:28356-28404`, grep de `event.text==` dans `28470-29245`).
`-code:<lua>` passe le reste du texte du marqueur à `loadstring` et `pcall` sans aucune garde (`zoneCommanderv2.lua:29203-29214`).

**Gardes, commande par commande** (corps lus en entier : `zoneCommanderv2.lua:28455-29253`).
Le seul test commun à toutes les commandes est la condition d'entrée du handler : événement 26, un texte, et une coalition de marqueur égale à 1 ou 2 (`zoneCommanderv2.lua:28456`).
Aucun corps de commande ne teste un UCID, un nom de joueur, un rang (sauf `buy`), un mot de passe ou un drapeau « debug activé » ; il n'y a ni mot de passe admin ni liste d'admins nulle part dans le fichier Config, dont la section « Admin Commands » ne contient que `AdminCommands` et `AdminCommandAliases` (`Config:3468-3512`).
Les `AdminCommandAliases` sont tous des chaînes vides par défaut, et un alias vide désactive cette action, donc activer `AdminCommands` sans remplir les mots supprime entièrement les douze actions aliasables (`Config:3477-3512`, `zoneCommanderv2.lua:28411-28412`).

| Commande | Garde dans son corps | Effet | Lignes |
|---|---|---|---|
| `help`, `debughelp`, `ConfigStatus` | aucune | texte au groupe de l'auteur, sinon à la coalition du marqueur | `28481-28553` |
| `buy`, `buy:<item>` | rang : avec `RankingSystem`, le rang de l'auteur doit atteindre le `reqRank` de l'article ; utilise le compte de la coalition du marqueur | liste ou achat | `28555-28620` |
| `adminbuy`, `adminbuy:<item>` | drapeau de config `AllowAdminBuy`, `true` par défaut ; pas de vérification de rang | achat sans rang, au coût de la coalition du marqueur | `28622-28660`, `Config:1948` |
| `köp…` / alias `buyWithoutRank` | mot secret seul | comme `adminbuy` | `28662-28705` |
| `debug` | aucune | vide dans `dcs.log` les groupes construits de la zone et la vie des unités | `28707-28746` |
| `spawn` | aucune | force chaque groupe `inhangar`/`dead` de la zone sous le marqueur à se lancer maintenant | `28747-28760` |
| `spawnnow[:<side>]` | aucune | `spawnNowBySide(side)`, camp par défaut = coalition du marqueur | `28761-28773` |
| `prepp` | aucune | fait passer les groupes `dead` de la zone à `inhangar` avec un timer expiré | `28774-28788` |
| `addshop`, `removeshop` | aucune | reconstruit ou supprime le menu de boutique Bleu | `28789-28793`, `28804-28808` |
| `upgradeallred`, `upgradeallblue` | aucune | améliore toutes les zones d'un camp | `28794-28803` |
| `status`, `intelstatus`, `whynot`, `missions`, `stats`, `top`, `mystats` | aucune (commandes joueur) | information | `28810-28834`, `28918`, `29068-29084`, `29215-29240` |
| `additems…` / alias `addZoneItems` | mot secret seul | ajoute des armes à l'entrepôt de la zone ou du FARP | `28836-28872` |
| `event` | aucune | liste les identifiants d'événements dans `dcs.log` | `28874-28879` |
| `event:<id>` | aucune | `evc:triggerEvent(id)` | `28880-28885` |
| `rensa` / alias `clearZone` | mot secret seul | `zone:killAll()` | `28886-28895` |
| `Message:<text>` | aucune | `trigger.action.outText` à tout le monde, 10 s | `28896-28901` |
| `SpelaMusik` | aucune | positionne le flag 180 pendant 300 s et joue `BH.ogg` au Bleu | `28902-28910` |
| `AvslutaFoothold` / alias `endMission` | mot secret seul | `forceMissionComplete()` | `28911-28917` |
| Marqueurs Tarawa | coalition Bleue et `AllowTarawaToMoveFreely` pour les formes de déplacement libre | routage du groupe du porte-avions | `28938-29009` |
| `farphere`, `givemefarpzell`, `escortmissionfarp` | PvP seulement pour cette branche ; alias `createFarp` | construit un FARP au marqueur | `29011-29040` |
| `givemefarp` / alias `createFarp` | mot secret seul | construit un FARP ordinaire | `29042-29066` |
| `addfunds:<n>` / alias `addBlueFunds` | mot secret seul | `bc:addFunds(2, n)` | `29085-29096` |
| `addrank:<player>,<n>` | aucune | ajoute des crédits de rang à un joueur nommé, avec le son de passage de rang | `29097-29123` |
| `addfundsred:<n>` / alias `addRedFunds` | mot secret seul | fonds Rouges | `29125-29136` |
| `upgradera` / alias `upgradeZone` | mot secret seul ; refuse une zone suspendue | `zone:upgrade()` | `29137-29148` |
| `recapture` | aucune | `zone:RecaptureBlueZone()` | `29149-29156` |
| `givemesupplies` | aucune | ajoute 3 de stock de supply accéléré à la zone | `29157-29163` |
| `maxxa` / alias `fullyUpgradeZone` | mot secret seul | `zone:MakeZoneSideAndUpgraded()` | `29164-29171` |
| `capture:<1|2>` | aucune | `zone:capture(side)` | `29172-29184` |
| `blå`, `röd` / alias `captureNeutralBlue`, `captureNeutralRed` | mot secret seul | `zone:capture(2)` / `zone:capture(1)` | `29185-29202` |
| `-code:<lua>` | aucune | Lua arbitraire | `29203-29214` |
| `StartaOm` / alias `restartMission` | mot secret seul | positionne le flag 181 | `29242-29245` |

« Mot secret seul » signifie que la branche est `(not adminAliases and text == <built-in word>) or customAdminAction == <action>` : connaître le mot est toute la protection.
`AdminCommands = true` ne cache donc que les douze actions aliasables derrière des mots choisis ; les lignes non aliasables marquées « aucune » (`spawn`, `capture:`, `addrank:`, `event:`, `Message:`, `recapture`, `upgradeall…`, `-code:`) restent ouvertes à tout client sous leurs noms fixes.
Ces noms sont publiés en jeu : la commande ouverte `debughelp` affiche le texte `ADMIN_DEBUG_HELP`, qui liste `spawn`, `rensa`, `capture:`, `maxxa`, `event:`, `addfunds:`, `addrank:`, `upgradera`, `upgradeallred`, `spawnnow:` et `-code:` avec des exemples (`zoneCommanderv2.lua:28492-28500`, `Foothold_Localization.lua:2056`).
Un marqueur dont la `event.coalition` n'est ni 1 ni 2 est ignoré (`zoneCommanderv2.lua:28456`) ; savoir si un marqueur de spectateur ou de game master porte une telle valeur est une estimation.

**Mécanisme.**
Un objet `world.addEventHandler` dédié teste `event.id == 26` (`S_EVENT_MARK_CHANGE`) avec un texte et une coalition de 1 ou 2 (`zoneCommanderv2.lua:28453-28456`, `29252`).
Les commandes ciblant une zone utilisent la position du marqueur : `bc:getZoneOfPoint(event.pos)` (`zoneCommanderv2.lua:28886`).
Une zone touchée par une commande est « réveillée » pour que sa maintenance tourne aussitôt (`zoneCommanderv2.lua:28439-28445`).

**Notes de reproduction.**
Tout client connecté de l'une ou l'autre coalition peut exécuter toute commande dont il connaît le mot, y compris du Lua arbitraire par `-code:`.

## Boucles principales et timers du moteur

**Les boucles démarrées par `BattleCommander:init`** (`zoneCommanderv2.lua:30226-30338`) :

| Boucle | Premier passage | Période | Ce qu'elle fait | Code |
|---|---|---|---|---|
| `update()` | 2 s | `updateFrequency` = 10 s | la vague de mise à jour des zones (ci-dessous) | `30293`, `Setup:754` |
| `_autoZoneSuspend()` | 1 s | 60 s | despawne les garnisons des zones loin du front | `30291`, `37445` |
| `_proximityWakeSuspendedZones()` | 10 s | 60 s | refait spawner une zone suspendue quand des joueurs approchent | `30292` |
| watchdog | 60 s | 60 s | affiche `SYSTEM_ENGINE_CRASH` si aucune mise à jour n'a abouti depuis `max(60, 2 × updateFrequency)` s, avec la phase, la zone et le groupe dans `dcs.log` | `30294-30327` |
| `requestStagedSaveToDisk()` | 30 s | 60 s | sauvegarde automatique | `30330` |
| `_runShouldSpawnEvalTick()` | ~0,5 s | 0,5 s (+ jusqu'à 0,15 s de jitter sur le premier) | vide une file d'évaluations « ce groupe IA doit-il spawner », 8 par tick, 18 quand plus de 70 attendent | `30331-30337`, `17127-17132`, `17982-18003` |
| nettoyage des contributions | 1 s | 60 s | abandonne les récompenses en attente des joueurs absents | `43108-43148` |
| message du jour | 10 s | `MessageOfTheDay.intervalSec` (1800 s) | répète un texte configuré | `30208-30224` |
| rafraîchissement de la superposition des territoires | 0,1 s | une fois | dessine la carte | `30267-30275` |

**La vague de mise à jour des zones.**
`update()` exécute d'abord le stock de supply au niveau des coalitions, puis planifie une chaîne d'étapes `timer.scheduleFunction` brutes : un `ZoneCommander:update()` par étape, espacées de 0,1 s (`zoneCommanderv2.lua:43235-43253`, `43291-43325`).
Le tout premier cycle après le démarrage met à jour toutes les zones en un seul appel (`zoneCommanderv2.lua:43335-43345`).
Si un nouveau tick de 10 s arrive alors qu'une vague tourne encore, il est seulement signalé et un cycle supplémentaire tourne à la fin de la vague (`zoneCommanderv2.lua:43328-43331`, `43277-43289`).
À la fin d'une vague : mise à jour de l'intel des zones, vérifications de ROE pour les groupes surveillés, fondu de difficulté, et horodatages du watchdog (`zoneCommanderv2.lua:43255-43275`).
Chaque zone porte son propre intervalle de maintenance et son état de dormance ; un compteur de « bucket FSM actif » étale les groupes IA d'une zone sur plusieurs ticks (`zoneCommanderv2.lua:43241-43244`, `28439-28444`) (la logique par zone et par groupe relève d'autres thèmes).

**Primitives de timer.**
Le moteur en mélange deux : 162 appels à `timer.scheduleFunction` brut (avec 14 `timer.removeFunction`) et 97 `SCHEDULER:New` plus 3 `TIMER:New` (comptes par grep sur `zoneCommanderv2.lua`).
Les timers bruts servent aux délais à un coup et aux chaînes qui se replanifient elles-mêmes (la fonction renvoie le temps suivant, par exemple `zoneCommanderv2.lua:43307`).
`SCHEDULER:New(obj, fn, args, start, repeat)` sert aux boucles récurrentes et à de nombreux coups uniques avec `repeat = 0` (par exemple `zoneCommanderv2.lua:28084`, `17314-17316`).
Le `SCHEDULER:New(master, fn, args, start, repeat, randomize, stop)` de Moose enregistre l'appel auprès du `_SCHEDULEDISPATCHER` global (`Moose_2026-10-11.lua:7884-7915`).
Le dispatcher enveloppe `fn` dans une fermeture `CallHandler` et la démarre avec `timer.scheduleFunction(CallHandler, {CallID, Info}, now + start)` ; l'arrêt se fait par `timer.removeFunction(ScheduleID)` (`Moose_2026-10-11.lua:7954-7990`, `8071-8087`, `8088-8105`).
Le handler exécute `fn` sous `xpcall` avec un gestionnaire d'erreur qui journalise « Error in timer function » et une trace d'appels dans `dcs.log` (`Moose_2026-10-11.lua:7996-8003`, `8030`, `8038`).
Règle de replanification : si l'appel a réussi et renvoyé `nil` ou toute valeur autre que `false`, et que `repeat ~= 0`, le handler renvoie à DCS `now + repeat ± randomize × repeat / 2` ; avec `repeat == 0` la planification est récupérée ; une erreur ou un retour `false` arrête une planification répétitive (`Moose_2026-10-11.lua:8043-8056`).
Une erreur Lua dans une fonction de `SCHEDULER` répétitif tue donc cette boucle en silence, ce qui est le même mode de défaillance pour lequel existe le watchdog du moteur.
Le contrat d'arrêt sur `false` est utilisé à `zoneCommanderv2.lua:44526`.
Le `TIMER:New(fn, ...):Start(tstart, dT, duration)` de Moose est la forme plus légère : un seul `timer.scheduleFunction(self._Function, self, tstart)` direct, ré-armé tous les `dT`, sans `xpcall` (`Moose_2026-10-11.lua:22991-23003`, `23042-23060`).
Le Moose embarqué est patché par Foothold : le gestionnaire d'erreur du dispatcher lit la globale du moteur `bc` pour ajouter du contexte à sa ligne de journal (`Moose_2026-10-11.lua:7998`), donc le fichier n'est pas un build Moose standard.

**Notes de reproduction.**
L'étalement de 0,1 s par zone, la file d'évaluation avec budget, la sauvegarde étalée et les files de menus suivent tous le même schéma : aucune boucle n'a le droit de toucher toutes les zones, tous les groupes ou tous les joueurs en une seule frame.
Le watchdog existe parce qu'une erreur dans la chaîne de la vague arrête la chaîne en silence ; il signale la dernière phase, zone et groupe atteints (`zoneCommanderv2.lua:30294-30326`, `43300-43302`).

## Gestion des événements

**Mécanisme.**
Le moteur n'enregistre que trois handlers DCS bruts avec `world.addEventHandler` : le dispatcher principal (`zoneCommanderv2.lua:30228-30232`), le handler des commandes par marqueurs (`29252`) et un par objet JTAC pour les marqueurs `jtac-code:` (`7403-7417`).
Le dispatcher principal `_handleWorldEvent` gère `S_EVENT_KILL`, `DEAD`, `CRASH`, `UNIT_LOST`, `SHOT`, `BIRTH` (15), `TAKEOFF`, `LANDING_AFTER_EJECTION`, `LAND`, `EJECTION`, `PILOT_DEAD`, `SCORE` (`zoneCommanderv2.lua:42893-43106`).
L'état des zones n'est **pas** piloté par événements : les morts d'unités dans une garnison sont trouvées par scrutation dans la mise à jour de zone, pas par `S_EVENT_DEAD` (le dispatcher retourne pour `S_EVENT_DEAD` sauf si l'objet est un aérodrome, `zoneCommanderv2.lua:42906-42909`).
Des événements synthétiques sont injectés avec `world.onEvent` pour `S_EVENT_LAND` et `S_EVENT_BASE_CAPTURED` (`zoneCommanderv2.lua:56735`, `56762`, `41324`, `98336`, `102339`).
La gestion d'événements Moose n'est utilisée qu'à deux endroits dans le moteur : un handler dérivé de `BASE` avec `HandleEvent(EVENTS.Shot)` pour les missions de frappe de piste (`zoneCommanderv2.lua:61999-62074`, `62522-62573`) et le hook de sous-classe MANTIS qui teste `EVENTS.Hit`/`EVENTS.UnitLost` (`zoneCommanderv2.lua:111460-111461`).
Les scripts satellites s'appuient davantage sur les événements Moose : `WelcomeMessage.lua` gère `EVENTS.BaseCaptured`, `PlayerLeaveUnit`, `Refueling`, `RefuelingStop` (`WelcomeMessage.lua:2932-2935`), ce qui explique pourquoi le moteur émet un `S_EVENT_BASE_CAPTURED` synthétique.

**Chaque `SET_*` du moteur** (`zoneCommanderv2.lua`) :

| Ligne | Set | Suit | Vivant ? |
|---|---|---|---|
| `105305` | `BlueClients = SET_CLIENT` avions bleus (bleus et rouges en PvP), actifs | appareils des joueurs, utilisé par la logique de ravitailleur et de soutien | `FilterStart` |
| `17104` | même set re-filtré pour les deux coalitions en PvP | — | `FilterOnce` |
| `65087-65093` | `SET_CLIENT` avions, actifs | joueurs pour les missions de reconnaissance | `FilterStart` |
| `27903-27905` | `SET_GROUP` par préfixe de nom | groupes de garnison qui circulent entre sous-zones | `FilterStart` |
| `104062` | `SET_GROUP` sol rouge, vivants | groupes qui entrent dans la trigger zone d'une mission d'escorte | `FilterStart`, arrêté par `FilterStop` à `104065` |
| `110008`, `111125`, `111208`, `111287` | `SET_GROUP` dans une zone, par coalition, actifs | cibles d'artillerie et de frappe navale | `FilterOnce` |
| `111446-111447` | MANTIS `SAM_Group`, `EWR_Group` | groupes SAM et EWR donnés à MANTIS | `FilterOnce` |
| `111454` | `SET_ZONE` préfixe `Scoot` | zones de repli (scoot) pour MANTIS | `FilterStart` |

`FilterOnce` est une unique passe sur la base de données Moose de ce type d'objet (`self.Database`), qui ajoute les objets passant les filtres et retire les autres ; rien n'est souscrit (`Moose_2026-10-11.lua:13954-13963`).
`SET_GROUP:FilterStart` fait la même passe initiale, puis abonne le set à `EVENTS.Birth` (ajout si le groupe passe les filtres), et à `Dead`, `Crash`, `RemoveUnit`, `UnitLost` et `PlayerLeaveUnit` (retrait du groupe quand sa dernière unité part) (`Moose_2026-10-11.lua:14358-14373`, `13970-13977`, `14009-14016`, `14392-14412`).
Quand le set a un filtre de zone, il démarre aussi un `TIMER` qui réévalue l'appartenance aux zones toutes les 30 s (`Moose_2026-10-11.lua:14366-14370`).
`SET_CLIENT:FilterStart` s'abonne à `Birth`, `Dead`, `Crash` et `PlayerLeaveUnit`, avec le même timer optionnel de 30 s pour les zones (`Moose_2026-10-11.lua:15941-15955`).
`SET_ZONE:FilterStart` parcourt la base de données des zones et s'abonne aux événements propres à Moose `NewZone`/`DeleteZone` (`Moose_2026-10-11.lua:16631-16644`).
`HandleEvent` enregistre l'objet auprès de l'unique dispatcher `EVENT` de Moose, qui est un seul `world.addEventHandler(self)` pour tout le framework et distribue chaque événement DCS aux objets abonnés (`Moose_2026-10-11.lua:6620-6623`, `8630-8634`, `8846`).
Chaque `SET_*` vivant coûte donc un callback par événement DCS correspondant, plus une scrutation de 30 s quand il est filtré par zone.

**Notes de reproduction.**
La dépendance cachée est la base de données Moose elle-même : `_DATABASE.Templates.Groups[name]` est lu 26 fois pour obtenir un template de groupe (unités, pays, catégorie) par son nom (`zoneCommanderv2.lua:1160`, `1220`, `1277`, `5228`, `27187`).
Ce registre est ce que Moose construit à partir de `env.mission` au chargement ; le moteur spawne ensuite avec ses propres helpers `Respawn` qui appellent directement `coalition.addGroup` (`zoneCommanderv2.lua:1315-1336`, `1344-1414`).

## Gestion du menu radio F10

**Mécanisme.**
Les menus sont construits avec l'API brute `missionCommands` : 392 appels dans le moteur (138 `addCommandForGroup`, 100 `addSubMenuForGroup`, 59 `removeItemForGroup`, 35 `addCommandForCoalition`, 36 `addSubMenuForCoalition`, 24 `removeItemForCoalition` ; comptes par grep).
`MENU_GROUP` de Moose apparaît 7 fois, toutes dans le menu de logistique (cargo) de `_handleBirth`, conservé dans `LogisticCommander.mooseLogisticsMenus` (`zoneCommanderv2.lua:101561-101739`).
Les menus sont par groupe (`…ForGroup(groupId, …)`), créés à la naissance du joueur, avec les handles conservés dans des tables indexées par identifiant de groupe (`statsMenus`, `languageMenus`, `MissionsRootMenus`, `printMissionMenus`, `zoneStatusMenus`, `groupMenus`) (`zoneCommanderv2.lua:101192-101234`, `101481-101486`, `101027-101029`).
La pagination est manuelle : un sous-menu « More » est inséré toutes les 9 entrées (`zoneCommanderv2.lua:101218-101224`).

**Files de rafraîchissement.**
Les menus dont le contenu dépend de l'état de la campagne (état des zones, sélecteurs de boutique, contrôle dynamique, ravitailleur, missions de frappe et d'intel, missions conjointes) ne sont jamais reconstruits chez l'appelant.
`requestZoneStatusMenuRefresh(groupId | nil, intelOnly)` se contente d'enregistrer ce qui est sale (tous les groupes, certains groupes, ou l'intel seul) et arme un `SCHEDULER` 0,15 s plus tard (`zoneCommanderv2.lua:17301-17317`).
Le flush transforme l'ensemble sale en une file de groupes et démarre une chaîne de timers bruts qui reconstruit **un groupe par 0,1 s** (`zoneCommanderv2.lua:17272-17299`, `40469-40500`).
Avant la reconstruction, chaque entrée est validée : le groupe existe encore, a toujours le même identifiant, et sa racine de menu et son objet d'état sont ceux capturés à la mise en file (`zoneCommanderv2.lua:40473-40476`).
Les demandes qui arrivent pendant un vidage sont accumulées et flushées quand la file se vide (`zoneCommanderv2.lua:40496-40499`).
Le même schéma demande/flush existe pour le sélecteur de boutique, le contrôle dynamique, les menus de supply et de ravitailleur (`zoneCommanderv2.lua:17319-17345`, `17389`, `17419`, `17441-17455`, `17600`) et pour les menus de missions conjointes (`18911`).
Aucun changelog du moteur n'est livré dans l'extrait (seulement `tools/FootholdConfigManager/CHANGELOG.md`), donc les files ne peuvent pas être rattachées aux correctifs de crash des 6.4.9 ou 6.5.0 ; ce qui suit est le code tel qu'il est en 6.5.3.

**Les cinq files de la 6.5.3.**

| File | Demande | Délai de regroupement | Débit de vidage | Unité de travail | Code |
|---|---|---|---|---|---|
| État des zones / intel | `requestZoneStatusMenuRefresh(groupId or nil, intelOnly)` | `SCHEDULER` à un coup 0,15 s | timer brut, **1 groupe par 0,1 s** | reconstruction des listes de zones Rouges/Bleues d'un groupe, ou de son seul sous-menu d'intel | `17272-17317`, `40469-40499` |
| Sélecteurs de boutique | `requestShopSelectorRefreshForCoalition(side, tags or item ids)` | `SCHEDULER` à un coup 0,15 s | `SCHEDULER` à un coup ré-armé tous les `shopSelectorRefreshInterval` = **0,25 s**, `shopSelectorRefreshBudget` = **1 job par tick** | une paire (groupe, article de boutique) : le sous-menu sélecteur de zone de cet article | `17319-17417`, `17513-17629`, `17649-17697`, `11999-12000` |
| Contrôle dynamique | `requestDynamicControlMenuRefresh()` | partage le flush de la boutique | partage le worker de la boutique : tant que les deux ont du travail, **un tick sur quatre** va au contrôle dynamique (après 3 jobs de boutique non prioritaires) | le menu racine « Dynamic Control » d'un groupe | `17389-17392`, `17600-17613`, `17655-17667` |
| Supply / ravitailleur | `requestDelayedSupplyMenuRefresh()`, `requestDelayedTankerMenuRefreshForBlue(needsShop)` | supply : timer brut, anti-rebond de 1 s après la **dernière** demande ; ravitailleur : timer brut 2 s | le supply alimente la file de la boutique ; ravitailleur : **1 groupe par 0,5 s**, relancé 2 s plus tard si demandé entre-temps | supply : articles de boutique `supplies`/`supplies2` ; ravitailleur : le menu de boutique ou de contrôle dynamique d'un groupe | `17419-17511` |
| Missions conjointes | `refreshJointMenusForSide(side)` | ensemble des camps en attente | timer brut, **1 groupe par 0,1 s** | les sous-menus de demande conjointe et de demandes en attente d'un groupe | `18911-18975` |

**Déduplication dans les files.**
État des zones : l'état sale tient en trois variables (`…RefreshAll`, `…RefreshIntel`, `…RefreshPendingGroups`), donc un nombre quelconque de demandes avant le flush donne au plus une entrée par groupe (`zoneCommanderv2.lua:17301-17308`, `17278-17292`).
Sélecteurs de boutique : un job est indexé `side|groupId|itemId` dans un ensemble `seen`, donc la même paire n'est jamais mise deux fois en file ; un article « prioritaire » (`capture`, `advancecapture`) est placé en tête de file (`zoneCommanderv2.lua:17549-17596`).
Contrôle dynamique : `indexByGroup` garde un emplacement par groupe et l'écrase (`zoneCommanderv2.lua:17607-17612`).

**Les vérifications « inchangé » qui évitent une reconstruction.**
- État des zones : les lignes de chaque camp (objet zone, handler, texte du libellé) sont comparées aux lignes rendues en dernier pour ce groupe, avec le handle racine, le camp du spectateur, le traducteur, la locale, les libellés de camp et le libellé « More » ; seul un camp qui diffère est retiré et ré-ajouté, et rien n'est touché quand les deux correspondent (`zoneCommanderv2.lua:40317-40324`, `40408-40466`).
- Contrôle dynamique : une chaîne de signature qui concatène chaque entrée du menu (vols de soutien actifs, index de spawn, modes de push, rang, …) est comparée à `groupDynamicSignatures[groupId]` ; quand elles sont égales et que le rafraîchissement n'est pas forcé, seule la sous-partie ravitailleur est rafraîchie (`zoneCommanderv2.lua:16408-16427`).
- Menus de missions de frappe et d'intel : une signature des missions ou zones actives est comparée à celle stockée, plus la racine rendue et la locale pour l'intel (`zoneCommanderv2.lua:103218`, `103254-103258`, `103318`, `103364-103368`).
- Demandes conjointes en attente : les lignes en attente (joueur, libellé, demande) et les quatre libellés sont comparés aux lignes précédentes ; identiques signifie retour immédiat (`zoneCommanderv2.lua:18861-18877`).
- Le menu racine de la boutique n'a pas de telle vérification : `refreshShopMenuForGroup` retire chaque article mémorisé et reconstruit (`zoneCommanderv2.lua:22395-22411`).

**Suivi et validation des handles.**
Les handles sont conservés dans des tables indexées par identifiant de groupe : `zoneStatusMenus`, `redSideMenus`, `blueSideMenus`, `_zoneStatusMenuStateByGroup`, `groupSupportMenus[gid] = {menu, items, selectorNodes}`, `groupDynamicMenus`, `groupDynamicSignatures`, `groupTankerMenus`, `groupCarrierNavigationMenus`, `jointMenusByGroup`, `jointMenuOwnersByGroup`/`BySide`, plus `statsMenus`, `languageMenus`, `aiLogisticsMenus` sur le `LogisticCommander` (`zoneCommanderv2.lua:40420-40466`, `22400-22411`, `97826-97889`).
Une entrée en file capture ce contre quoi elle a été mise en file (handle racine et objet d'état pour l'état des zones ; objet propriétaire et menu parent pour le conjoint ; jeton de menu pour le ravitailleur) et est ignorée au moment du vidage si le groupe vivant n'a plus le même identifiant ou si les objets capturés ont changé (`zoneCommanderv2.lua:17288-17290`, `40473-40476`, `18939-18945`, `17488`, `17665`).

**Abandon des handles.**
`LogisticCommander:pruneGroupMenus(groupid, groupname)` est l'unique nettoyage, appelé quand l'appareil du joueur a disparu (après le traitement de l'éjection, et depuis le nettoyage des appareils de joueurs du dispatcher d'événements) (`zoneCommanderv2.lua:97785`, `42158`, `43034`).
Il incrémente d'abord le jeton de menu du groupe, ce qui invalide tout job de menu en file ou différé pour cet identifiant de groupe (`zoneCommanderv2.lua:97786`, `97779-97783`).
Il vérifie ensuite si un groupe DCS vivant de ce nom a encore cet identifiant : si oui il appelle `missionCommands.removeItemForGroup` sur chaque handle suivi ; sinon il **oublie seulement les handles sans appeler DCS**, selon le commentaire « Retire native handles without touching DCS when this group is no longer available » (`zoneCommanderv2.lua:97796-97800`, `97825-97873`).
Il efface aussi les champs de menu Moose CTLD mis en cache sur l'objet groupe Moose (`zoneCommanderv2.lua:97816-97823`).

**Notes de reproduction.**
Retirer et ré-ajouter des éléments F10 pour de nombreux groupes en une seule frame est le coût que l'on évite.
Les handles périmés sont le principal danger : un identifiant de groupe peut être réutilisé par un autre joueur, d'où le jeton et les vérifications d'identité avant chaque opération de menu différée (`zoneCommanderv2.lua:97779`, `40473-40476`).

## Sortie des messages et localisation

**Ce que voit le joueur.**
F10 → menu des statistiques → `LANGUAGE_MENU_SET` liste 10 langues ; en choisir une affiche `LANGUAGE_SET_RESLOT` dans la nouvelle langue, et les menus changent à la prochaine sélection de slot (`zoneCommanderv2.lua:101214-101231`, `96-107`).
Langues : EN, DE, FR, ES, RU, PT-BR, TR, IT, zh-CN, zh-TW (`zoneCommanderv2.lua:96-107`, `Config:204-217`).

**Ce que voit l'administrateur.**
`FootholdLocale` (par défaut `"EN"`) fixe la langue du serveur utilisée pour les textes envoyés à tout le monde ou à une coalition (`Config:204-221`).

**Mécanisme.**
`Foothold_Localization.lua` définit la globale `FootholdLocalization` avec `Messages[locale][KEY] = text` (`Foothold_Localization.lua:14-27`).
`Get(key, locale)` cherche dans la locale demandée, puis dans la locale par défaut (EN), puis renvoie la clé elle-même (`Foothold_Localization.lua:20865-20879`).
`Format(key, ...)` est un `string.format` sur le résultat (`Foothold_Localization.lua:20881-20891`).
Les chaînes propres à une carte sont ajoutées avec `Register(locale, entries)` ; une locale sans table propre pour une carte retombe sur la table EN de cette carte (`Foothold_Localization.lua:20840-20847`, `24621-24622`).
Il existe trois portées de langue : la locale du serveur (`SetLocale`), une locale par joueur indexée par nom de joueur (`SetPlayerLocale`, `Foothold_Localization.lua:20931-20948`), et une liaison par groupe faite à la naissance avec `BindGroupLocale(groupId, playerName)` (`Foothold_Localization.lua:20950-20977`, `zoneCommanderv2.lua:101469`).
`ForGroup(groupId)` / `ForLocale(locale)` renvoient un objet « vue » `T` mis en cache, dont `Get`/`Format` sont liés à une locale ; les constructeurs de menus reçoivent `T` (`Foothold_Localization.lua:21000-21018`, `zoneCommanderv2.lua:101202-101204`).
Le moteur y accède par une façade locale `L10N` dont les méthodes transmettent à `FootholdLocalization` (`zoneCommanderv2.lua:75-93`) ; `L10N:` est appelé 875 fois dans le moteur (grep).
Les locales des joueurs sont sauvegardées dans le fichier de campagne et restaurées au chargement (`Foothold_Localization.lua:21024-21049`, `zoneCommanderv2.lua:25741-25743`).

**Primitives de sortie.**
`trigger.action.outText`, `outTextForCoalition`, `outTextForGroup`, `outTextForUnit` bruts : 574 appels ; `trigger.action.outSound*` : 67 appels ; `MESSAGE:New(...):ToAll()/ToGroup()` de Moose : 43 appels (comptes par grep sur le moteur).
Un texte pour toute une coalition ne peut être que dans une seule langue, donc ceux-ci utilisent la locale du serveur ; les textes par groupe utilisent la locale du groupe (`zoneCommanderv2.lua:101447-101448` montre les deux formes côte à côte).

**Notes de reproduction.**
Comme la locale par joueur est indexée par nom et celle par groupe par identifiant de groupe, un changement de langue n'atteint les menus qu'après un nouveau choix de slot.
Le fichier `Foothold_Localization.lua` fait 38 857 lignes pour 10 locales et est chargé avant la config, qui appelle `SetLocale` (`mission:58`, `Config:220-222`).

## Recensement des dépendances à Moose

Les comptes sont des occurrences de `CLASS:method` ou `CLASS.field` trouvées par grep ; ils sont approximatifs (commentaires inclus, méthodes d'instance sur des objets Moose non comptées).

**Moteur (`zoneCommanderv2.lua`).**

| Classe Moose | Nombre | À quoi elle sert | Poids |
|---|---|---|---|
| `UTILS` | 384 | conversions d'unités : `NMToMeters` 111, `FeetToMeters` 71, `KnotsToKmph` 32, `KnotsToMps` 21, `MpsToKmph` 21, `MetersToNM` 17, `IasToTas` 12 ; `DeepCopy` 34 ; `VecDist` 25 ; `GetMarkID` 8 ; helpers de fichiers `SaveToFile`/`LoadFromFile`/`Split` | helpers triviaux |
| `COORDINATE` | 182 | `COORDINATE:New` 132, `NewFromVec*` 46 : positions, waypoints, relèvements | moyen : une classe vecteur avec des constructeurs de points de route |
| `SCHEDULER` | 97 | timers (voir plus haut) | léger |
| `GROUP` | 86 | `GROUP:FindByName` 85 : objets enveloppes pour appeler les méthodes de controllable (routes, tâches, options) | moyen |
| `AIRBASE` | 61 | `FindByName` 26, `FindByID` 10, `TerminalType` 21 : places de parking et recherche d'aérodromes | moyen (données de parking) |
| `SPAWN` | 50 | `NewFromTemplate` 19, `NewWithAlias` 12, `New` 4, `SPAWN.Takeoff` 15 ; 42 appels `:Spawn…(` | lourd : spawn d'avions IA sur les aérodromes et en vol |
| `MESSAGE` | 43 | quelques messages à l'écran | trivial |
| `ZONE` | 39 | `ZONE:FindByName` 37 | léger |
| `BASE` | 35 | journalisation (`BASE:I`, `BASE:E`), traçage | trivial |
| `_DATABASE` | 32 | `Templates.Groups` 26 : registre des templates | caché mais structurel |
| `STORAGE` | 26 | `STORAGE:FindByName` 23 : entrepôts | moyen |
| `ENUMS` | 14 | constantes (ROE, formations…) | trivial |
| `CTLD` | 9 | références à l'instance CTLD | voir le thème logistique |
| `EVENTS` | 8 | deux handlers | trivial |
| `SET_GROUP` / `SET_CLIENT` / `SET_ZONE` | 7 / 3 / 1 | tableau ci-dessus | léger |
| `MENU_GROUP` | 7 | menu de logistique seulement | léger |
| `UNIT`, `STATIC`, `CLIENT`, `SPAWNSTATIC` | 7 / 5 / 2 / 4 | enveloppes occasionnelles | trivial |
| `TIMER` | 6 | étalement de la sauvegarde des entrepôts | trivial |
| `AUFTRAG` | 6 | `NewANTISHIP`, `NewINTERCEPT`, `NewARTY` | sous-système lourd, 6 sites d'appel |
| `FLIGHTGROUP` / `NAVYGROUP` / `ARMYGROUP` | 3 / 2 / 1 | contre-frappe du cuirassé, frappeur naval, chasse d'interception, artillerie navale et V1 | sous-système lourd (OPS), peu de sites d'appel (`zoneCommanderv2.lua:10932-10944`, `41099-41101`, `70022-70044`, `109998-110075`, `111165`, `111330`) |
| `MANTIS` | 3 | défense aérienne intégrée rouge et bleue (`zoneCommanderv2.lua:111399`, `111485`) | sous-système lourd |
| `ZONE_RADIUS`, `ZONE_UNIT`, `ZONE_GROUP` | 2 / 1 / 1 | zones ad hoc | trivial |
| `BEACON`, `MARKER`, `ASTAR`, `USERSOUND`, `_SETTINGS` | 2 / 1 / 1 / 1 / 2 | constantes TACAN, un marqueur, une recherche de chemin, un son | trivial |

Pas du tout utilisées par le moteur (0 occurrence) : `INTEL`, `CSAR`, `ATIS`, `MSRS`, `SOCKET`, `PLAYERTASK*`, `AIRBOSS`, `MENU_COALITION`, `MENU_MISSION`, `EVENTHANDLER`, `OPSGROUP`, `CHIEF`, `AIRWING` (seules des lignes `BASE:TraceClass` commentées en mentionnent certaines, `zoneCommanderv2.lua:35425-35426`, `105299-105300`).
Le `require("socket")` propre au moteur à `zoneCommanderv2.lua:48459` est LuaSocket, pas le `SOCKET` de Moose.

**Pour comparaison, API DCS brute dans le moteur** : `Group.getByName` 381, `trigger.action.outText*` 574, `missionCommands.*` 392, `timer.scheduleFunction` 162, appels de marquage de carte 113 + 30 appels de dessin, `StaticObject.getByName` 71, `Unit.getByName` 23, `coalition.addGroup` 3 (dans les helpers de respawn propres au moteur), `coalition.addStaticObject` 6.

**Scripts satellites.**

| Fichier | Classes Moose (nombre) |
|---|---|
| `Foothold CTLD.lua` | `CTLD_CARGO` 48, `CTLD` 32, `STORAGE` 20, `MESSAGE` 14, `UTILS` 11, `BASE` 11, `GROUP` 10, `COORDINATE` 9, `SCHEDULER` 8, `AIRBASE` 6, `ZONE_RADIUS` 4, `ZONE` 4, `TIMER` 4 |
| `Foothold_CTLD_Red.lua` | `CTLD_CARGO` 15, `CTLD` 14, `STORAGE` 6 |
| `EWRS.lua` | `UTILS` 61, `EVENTS` 10, `UNIT` 4, `SET_UNIT` 3, `SET_CLIENT` 1 |
| `WelcomeMessage.lua` | `MESSAGE` 35, `UTILS` 25, `MENU_GROUP_COMMAND` 15, `MENU_GROUP` 7, `SCHEDULER` 8, `UNIT` 8, `GROUP` 6, `EVENTS` 6, `COORDINATE` 4, `SPAWN` 3, `SET_CLIENT` 2 |
| `Zeus.lua` | `ZONE_RADIUS` 3, `SPAWN` 1, `EVENTHANDLER` 1, `COORDINATE` 1 |
| `MA_Setup_CAv2.lua` | `_DATABASE` 15, `UTILS` 8, `SCHEDULER` 6, `GROUP` 6, `AIRBASE` 3, `ZONE` 2, `SPAWN` 2 |

**Lecture du recensement.**
Le cœur du moteur (zones, capture, persistance, menus, messages, événements, timers, spawn des garnisons) est écrit contre l'API DCS brute, Moose n'étant utilisé que comme bibliothèque utilitaire.
Les classes Moose qui pèsent réellement sont `SPAWN` (vols IA), `COORDINATE`/`GROUP`/`AIRBASE` (routage et parking), `STORAGE` (entrepôts), `MANTIS` (défense aérienne), les classes OPS à six sites d'appel, et `CTLD`/`CTLD_CARGO` dans les scripts de logistique.

## Vu hors de ce thème

- Suspension et réveil des zones (despawn des garnisons loin du front, instantané des survivants) : `zoneCommanderv2.lua:37445`, `47925`, `48044`.
- Dispatcher d'évaluation « should spawn » pour les groupes IA (files par type de mission, budget par tick) : `zoneCommanderv2.lua:17982-18060`.
- Disponibilité des appareils dans les entrepôts, listes `allowedPlanes*` et `restockAircraft` : `Config:2622`, `Config:3144`, `zoneCommanderv2.lua:20074` (`CopyWarehouse`), `19949`.
- `WarehouseWeaponLocationPolicy` (quelles armes peuvent être stockées où) : `zoneCommanderv2.lua:51153-51258`.
- FARP dynamiques construits par les joueurs, leur fichier de sauvegarde et leur restauration au démarrage : `Foothold CTLD.lua:7609-7850`, `zoneCommanderv2.lua:111570-111630`.
- Navigation du porte-avions (stations, voies, routes personnalisées Tarawa) et son état sauvegardé : `zoneCommanderv2.lua:14041-15700`.
- Persistance des ravitailleurs et de l'AWACS et marqueurs `arcohere`/`texacohere`/`caphere` : `zoneCommanderv2.lua:28149`, `106153`.
- Statistiques de carrière et hauts faits (`CAREER_STAT`, métriques par appareil) : `zoneCommanderv2.lua:12021-12956`, `44089-44212`.
- Mise à l'échelle de la difficulté (`difficultyModifier`, fondu dans le temps) : `zoneCommanderv2.lua:43268-43272`, `8586`.
- Déplacement des groupes de garnison entre sous-zones (déplacements étalés par `SCHEDULER`) : `zoneCommanderv2.lua:27895-28108`.
- Destruction de piste bloquant les spawns d'avions IA pendant 3300 s : `zoneCommanderv2.lua:42906-42920`.
- Supply par largage cargo de l'Hercules sur `S_EVENT_SHOT` : `zoneCommanderv2.lua:102303-102444`.
- Outillage externe « SITAC » alimenté par `foothold.status`, `zonesDetails`, `connections`, `missions`, `players` : `zoneCommanderv2.lua:25745-25802`, `44557-44568`.
- Outil Windows `Foothold Config Manager` et ses annotations `-- @gui` : `tools/FootholdConfigManager/README.md`, `Config:201`.
