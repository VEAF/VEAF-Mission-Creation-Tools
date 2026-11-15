# Foothold 6.5.3 — inventaire fonctionnel et technique

Écrit le 2026-11-15 pour [`FEAT-DYNAMIC-CAMPAIGN`](PRD.md), dont le ticket 07 mesure notre propre moteur face à Foothold.
En français à la demande de David (2026-11-15), par exception à la règle du dépôt.
Cette page est le point d'entrée : la version analysée, le catalogue des fonctionnalités avec ce que VEAF a déjà et ce que chacune coûterait, et une proposition d'ordre.
Les mécanismes eux-mêmes sont dans huit notes détaillées sous [`foothold-analysis/`](foothold-analysis/), où chaque affirmation est citée `fichier:ligne` dans la version analysée.
Le but est qu'une session ultérieure travaille à partir de ces pages sans relire le code amont.
Rien ici n'est une décision : le choix des fonctionnalités à intégrer revient à David.

## 1. Version analysée

| | |
|---|---|
| Amont | [`leka1986/Lekas-Foothold`](https://github.com/leka1986/Lekas-Foothold) |
| Analysé | tag `v6.5.3`, commit `27d8cf4a6e579f3c60a5f715bbdf06782fb1d351`, 2026-11-13 (dernière release au 2026-11-15) |
| Après le tag | 6 commits sur `main` jusqu'au 2026-11-14, tous sur le Config Manager (2.5.8 à 2.6.0) et le dossier des sauvegardes ; non analysés |
| Missions du tag | encore nommées 6.5.2 (`Missions/Foothold_CA_6.5.2_…miz`), avec les scripts 6.5.3 dedans |
| Ce que VEAF fait tourner | 5.3.5, rafraîchie le 2026-10-19 dans les dix dépôts `VEAF-Foothold-*` (`chore: update to Foothold 5.3.5`) |
| Taille du moteur | `zoneCommanderv2.lua` : 102 728 lignes dans notre 5.3.5, 115 262 en 6.5.3 |
| Clone local | `D:\dev\_dcs-other\Lekas-Foothold` (remotes `origin` = amont, `fork` = `VEAF/Lekas-Foothold`) ; son `main` local est sur un commit du 2025-12-29, laissé tel quel |

Seize releases séparent la 5.3.5 de la 6.5.3.
Ce qu'elles ont ajouté, d'après les notes de version :

- le PvP sur Caucase, Syrie et Golfe Persique, avec boutique, CTLD et CSAR rouges (5.4.0, 5.4.1) ;
- le choix d'altitude des escortes et les radios configurables des AWACS, ravitailleurs et porte-avions (5.4.3) ;
- `NoAIBlueCapture` (5.4.4) ;
- la refonte de l'apprentissage et de la réévaluation du Director (5.4.5, 6.4.6) ;
- le bonus d'opération de nuit, les réglages de défense aérienne de nuit, `MaxRedGroundGroupsPerZone` (6.4.6) ;
- la sauvegarde étalée, le réveil des zones en file d'attente et les rafraîchissements de menus en file (6.4.8 à 6.5.0) ;
- les zones « idle », l'interrupteur des patrouilles au sol, le plafond des défenses bleues (6.5.1) ;
- le redémarrage sur défaite en PvE, la localisation des armes par entrepôt, le rachat automatique de CAP, la révélation des SAM (6.5.2) ;
- la carte South Atlantic (6.5.3).

### Retrouver le source

La copie de travail de cette analyse était un extrait temporaire.
Pour la refaire : `git -C D:\dev\_dcs-other\Lekas-Foothold fetch --tags origin`, puis `git archive v6.5.3 | tar -x -C <dossier vide>`.
Un index des fonctions (une ligne `ligne:signature` par définition) se régénère avec `grep -nE '^\s*(local\s+)?function\s+[A-Za-z_][A-Za-z0-9_.:]*\s*\(' "Common Scripts/zoneCommanderv2.lua"` ; il compte environ 3 100 entrées.

### Ce que contient la release

| Fichier | Lignes | Rôle |
|---|---|---|
| `Common Scripts/zoneCommanderv2.lua` | 115 262 | le moteur, commun à toutes les cartes |
| `Common Scripts/Moose_2026-10-11.lua` | 132 407 | le Moose embarqué, **modifié pour Foothold** (son CTLD appelle des fonctions de Foothold, note 07 §1) |
| `Common Scripts/Foothold_Localization.lua` | 38 857 | tous les textes vus par les joueurs, 10 langues |
| `Common Scripts/AIEN.lua` | 16 093 | réactions de l'IA au sol (Chromium18), adaptées |
| `Setup files/<carte>.lua` | 5 000 à 10 000 | les données de campagne d'une carte, écrites à la main |
| `Common Scripts/Foothold CTLD.lua`, `Foothold_CTLD_Red.lua` | 9 441, 2 417 | la logistique, sur le CTLD de Moose |
| `Common Scripts/Splash_Damage_3.4.1_leka.lua` | 4 932 | splash damage, adapté |
| `Common Scripts/Foothold Config.lua` | 3 530 | 202 réglages serveur |
| `Common Scripts/WelcomeMessage.lua`, `EWRS.lua`, `Zeus.lua` | 2 941, 1 745, 105 | callsigns, ATIS et escorte ; image radar ; marqueurs de game master |
| `zoneCommander.lua`, `zeus_Full_v2.1.lua`, `WelcomeMessagev2.lua` | — | présents dans le dépôt, **non chargés** par les missions |

## 2. Les notes détaillées

| Note | Couvre | Taille |
|---|---|---|
| [`01-zones-capture-map.md`](foothold-analysis/01-zones-capture-map.md) | modèle de zone, garnisons, pertes, état neutre, canaux de capture, capture temporisée, advance capture, dormance, graphe de connexions, frontline, tout ce qui est dessiné sur la carte F10, victoire et défaite | 18 fonctionnalités |
| [`02-persistence-lifecycle-plumbing.md`](foothold-analysis/02-persistence-lifecycle-plumbing.md) | fichiers de sauvegarde et leurs champs, sauvegarde étalée, chargement et réapplication, redémarrage et reset, ères et PvE/PvP, identité des joueurs, contrôle des slots, événements, boucles et timers, files de menus F10, langues, recensement de Moose, ordre de chargement des scripts | 21 fonctionnalités |
| [`03-ai-groups-sorties.md`](foothold-analysis/03-ai-groups-sorties.md) | machines à états de `GroupCommander` (air et surface), conditions de spawn et plafonds, CAP et frappes, hélicoptères de supply IA, AIEN, MANTIS, bombardiers, Hunter, limiteurs | 15 fonctionnalités |
| [`04-director.md`](foothold-analysis/04-director.md) | le planificateur qui autorise chaque sortie IA : capacités, cycle, choix de cible, packages, posture, phases et verrous, apprentissage, slots de CAP, sorties au sol, événements, difficulté | 19 fonctionnalités |
| [`05-economy-shop-ranks-missions.md`](foothold-analysis/05-economy-shop-ranks-missions.md) | crédits de coalition et personnels, attribution des kills, tout le catalogue de la boutique, rangs, statistiques, carrière, missions conjointes, missions joueurs, arbre F10 | 13 fonctionnalités |
| [`06-player-support-tools.md`](foothold-analysis/06-player-support-tools.md) | drones JTAC, désignateur laser du joueur, CSAR, intel de zone, ravitailleurs, AWACS, contrôle des CAP, toutes les commandes par marqueur, porte-avions, accueil/callsigns/ATIS, escorte, EWRS, Zeus, splash damage | 19 fonctionnalités |
| [`07-ctld-warehouse-logistics.md`](foothold-analysis/07-ctld-warehouse-logistics.md) | ce que Foothold ajoute au CTLD de Moose, catalogue de cargo, supplies de zone, cargo d'entrepôt, kits de FARP, C-130J, équipes espion et démolition, stocks d'entrepôt, ancienne logistique, CTLD rouge, liste des fonctions du CTLD Moose utilisées | 22 fonctionnalités, plus la production de supply, le bâtiment entrepôt, les infrastructures, l'industrie PvP et les trains |
| [`08-mission-maker-side.md`](foothold-analysis/08-mission-maker-side.md) | le manuel (63 pages), les 202 réglages de config, la structure d'un fichier de setup avec extraits, les conventions du `.miz` mesurées, le Config Manager, l'exploitation serveur, le coût d'écriture d'une carte | 10 rubriques |
| [`09-moose-functions.md`](foothold-analysis/09-moose-functions.md) | la liste des fonctions de Moose appelées par les scripts de Foothold, relevée par script : appels statiques par classe (exact) et méthodes d'instance (approximation), avec le compte par fichier | 42 classes, 112 membres statiques, 275 méthodes d'instance |

Chaque note s'ouvre sur son tableau de fonctionnalités et finit par ce qu'elle a vu hors de son thème.
Les notes ont été écrites en anglais puis traduites en français le 2026-11-15 ; le code, les citations `fichier:ligne` et les messages du jeu y sont restés tels quels.
Dans une note, « (estimation) » et « non lu » marquent ce qui n'a pas été lu dans le code ; la section 8 ci-dessous liste ce qui le reste.

## 3. Constats qui changent ce que supposait le PRD

Le PRD de ce lot a été écrit d'après Foothold 4.7.0 (lu le 2026-10-02).
Cinq de ses affirmations ne tiennent plus sur la 6.5.3.

1. **Il y a une licence maintenant.**
   Le PRD écarte un fork parce que l'amont était en `license: null`.
   La 6.5.3 livre un `LICENSE` (GPL-3.0-only pour le code de Leka), avec Apache-2.0 conservée sur les parties d'origine de zoneCommander, GPL-3 pour Moose et AIEN, MIT pour Splash Damage et EWRS (`THIRD_PARTY_NOTICES.md`).
   La seconde raison contre un fork tient toujours : le moteur a grossi de 12 500 lignes en quatre semaines.
   Une conséquence à peser : du code copié ou adapté de près depuis Foothold dans un module VEAF emporterait les termes de la GPL-3.0 ; les idées et les mécanismes, non.
2. **Moose est une boîte à outils dans le moteur, pas son squelette.**
   Le recensement (note 02, « Recensement des dépendances à Moose ») compte, dans le moteur, 392 appels bruts à `missionCommands`, 574 `outText` bruts, 162 `timer.scheduleFunction` bruts et 3 `world.addEventHandler`.
   En face, Moose sert surtout aux conversions d'unités (`UTILS`, 384), aux positions (`COORDINATE`, 182) et aux timers (`SCHEDULER`, 97).
   La « couche OPS (`AUFTRAG`/`FLIGHTGROUP`, une machine à états par vol IA) » du PRD a disparu des sorties ordinaires : OPS ne sert plus qu'à six endroits annexes (Hunter, cuirassé, artillerie navale, V1), et toutes les sorties de supply, CAP, CAS, SEAD, frappe de piste et convoi sont pilotées par des tâches DCS brutes (note 03 §7).
   Les parties de Moose qui pèsent vraiment sont `SPAWN` avec `AIRBASE` (spawn des avions IA au parking), `STORAGE` (entrepôts), `MANTIS` (défense aérienne), `CTLD`, et le registre de templates `_DATABASE.Templates.Groups`.
   « C'est Moose qui coûte les images » est donc moins probable que le PRD le supposait ; ce n'est toujours pas mesuré, et le ticket 07 reste le moyen de le savoir.
3. **Foothold fait déjà ce que prévoit notre section performance.**
   Les zones dormantes existent : suspension par la distance, suspension « idle », réveil par les joueurs, par le front ou par une mission IA, respawn d'un groupe toutes les 0,1 s, pertes conservées (note 01 §9).
   La mise à jour des zones est une seule vague étalée (une zone toutes les 0,1 s dans une période de 10 s), les décisions de spawn passent par une file avec budget, la sauvegarde est étalée, les rafraîchissements de menus sont en file (note 02, « Boucles principales et timers du moteur »).
   La seule chose que nous prévoyons et que Foothold ne fait pas : utiliser les événements pour les pertes ; il scrute chaque garnison (note 01 §4) et l'état de chaque groupe IA (note 03 §16).
4. **Les sorties ne sont plus déclarées une par une comme objets vivants.**
   Le setup du Caucase déclare 402 `DirectorCapability` contre 7 `GroupCommander:new` ; une capacité est une donnée passive, instanciée quand le Director l'autorise, et un générateur « DynamicHybrid » en ajoute d'après des règles de distance (notes 04 §2, 08 §3).
   C'est proche de nos « sorties dérivées du graphe », atteint par l'autre bout.
5. **Le coût d'écriture d'une carte était sous-compté.**
   Mesuré sur le Caucase (note 08, « Coût d'écriture d'une carte ») : 10 014 lignes de setup, 89 zones, 409 déclarations de sorties, 135 connexions visibles et 14 cachées, 1 331 trigger zones (dont 717 sous-zones de spawn), 508 groupes templates en late activation, 338 statics.
   62 à 74 % des lignes des autres setups modernes sont identiques à des lignes du Caucase : l'essentiel d'un fichier de setup est du code copié d'une carte à l'autre.

Un constat concerne nos serveurs d'aujourd'hui plutôt que la conception : voir la section 9.

## 4. Comment marche Foothold, en une page

Une campagne est un graphe de **zones** (89 sur le Caucase).
Chaque zone a un propriétaire (0 neutre, 1 rouge, 2 bleu), un type d'installation (aérodrome, FARP, porte-avions, sol, logistique) et une **garnison** : une liste ordonnée de groupes templates par propriétaire, retirée au hasard à chaque campagne d'après des profils de taille (note 01 §1–2).

Une zone ne change jamais de camp directement.
Sa garnison est détruite emplacement par emplacement ; quand le dernier est tombé, la zone devient **neutre** (note 01 §5).
Une zone neutre se capture en y amenant quelque chose : un hélicoptère ou un convoi de supply IA, des troupes CTLD, une caisse de supply, un largage de Hercules.
Cela lance une **capture temporisée** de `ZoneCaptureBuildSeconds` (120 s), ancrée sur un objet physique que l'ennemi peut détruire (note 01 §6–7).
À la capture, le premier emplacement de garnison apparaît ; chaque livraison de supply suivante en ajoute ou en répare un (note 01 §4).
Une zone aérodrome bascule la coalition de l'aérodrome DCS, ce qui ouvre ou ferme ses slots en dynamic spawn (notes 01 §6, 02 « Gestion du spawn des joueurs et contrôle des slots »).

L'IA a deux étages.
`GroupCommander` est la machine à états qui exécute une sortie (hangar → préparation → décollage → en vol → posé), entièrement par scrutation (note 03 §2).
Le `Director`, un par camp, décide : toutes les 30 s il note les zones bleues, en tire une au hasard pondéré, compose un package (CAP, SEAD, CAS, frappe de piste, surface, feinte, réserve), autorise les décollages par des verrous, réévalue toutes les 90 s, et garde une mémoire dégressive de ce qui a marché (note 04 §3–8).
La CAP de routine, la sortie des convois et les réactions aux captures des joueurs sont des fonctions séparées du Director (note 04 §9–12).
La défense aérienne est un réseau MANTIS par camp (note 03 §11) ; les groupes au sol réagissent au feu par AIEN (note 03 §10).

Les joueurs gagnent des **crédits personnels** pour leurs kills et leurs livraisons.
Ces crédits ne deviennent crédits de coalition et rang qu'en **se posant dans une zone amie** ; mourir les fait perdre, s'éjecter en garde 25 % (note 05 §3).
Les crédits de coalition achètent des articles de boutique — vols de soutien, drones JTAC, intel, captures, améliorations et réparations de zone — depuis un menu F10 ou un marqueur `buy:<id>` (note 05 §4–5).
Une échelle de 20 **rangs** conditionne les articles de boutique et de CTLD (note 05 §7).
Les **missions** proposées aux joueurs sont une liste de fonctions scrutées, avec récompense, affichées dans un menu et sur la carte (note 05 §11).

La logistique est le CTLD de Moose avec Foothold par-dessus : prix et rangs sur le cargo, zones qui suivent le propriétaire, caisses de supply suivies physiquement, stocks d'armes déplacés entre **entrepôts** d'aérodromes, FARP construits par les joueurs (note 07).

L'état est sauvegardé toutes les 60 s dans des fichiers Lua sous `Saved Games\<instance>\Missions\Saves` (huit fichiers par carte, ère et mode — note 02 « Fichiers écrits sous `Saved Games` »), ce qui exige `io` et `lfs` dans `MissionScripting.lua`.
Une victoire ou une défaite efface la sauvegarde et pose le flag 181, qu'un trigger de la mission transforme en `a_end_mission` ; le serveur recharge la mission (notes 01 §18, 02 « Cycle de vie de la campagne »).

## 5. Ce que VEAF a déjà

Lu dans les en-têtes des modules et par grep sur `src/scripts/` (2026-11-15, `origin/develop` à `cfe3dcf8`).
Ce n'est pas une lecture ligne à ligne, sauf la liste des fonctions de `veafCampaign.lua`.

| Brique VEAF | Ce qu'elle apporte face à Foothold |
|---|---|
| `veafCampaign.lua` (1 559 lignes, `FEAT-MULTI-MISSION-CAMPAIGN`, 🧑 en attente de son contrôle en jeu) | zones par propriétaire avec un état neutre, garnisons tirées une fois avec les générateurs de `veafCasMission` et enregistrées, pertes par `S_EVENT_DEAD`, capture d'une zone neutre par une présence au sol tenue un certain temps (caisses CTLD comprises), bascule de coalition de l'aérodrome, zones et connexions sur la carte F10, menu radio de situation, convois d'assaut par règle et sur ordre des joueurs payés sur une réserve, fichier d'état écrit par `io`/`lfs`, décor détruit, missiles SAM restants, compteurs de travail |
| `veafCombatZone.lua` | zones de l'éditeur activées et désactivées à la demande avec leurs groupes : ce qui ressemble le plus à la dormance |
| `veafQraCore.lua`, `veafAirWaves.lua`, `veafReactiveZone.lua`, `veafOpposition.lua` | vols IA réactifs autour d'une zone, vagues, et un niveau d'opposition qui suit le nombre de joueurs |
| `veafSkynetIadsHelper.lua` + Skynet-IADS | la défense aérienne intégrée, à la place de MANTIS |
| `veafGroundAI.lua` + `AIEN.lua` embarqué | ordres aux groupes au sol et réactions au feu |
| CTLD 2 de VEAF (`src/scripts/community/CTLD.lua`) | troupes, caisses, FOB, avec un `EventDispatcher` (`OnTroopsDeployed`, `OnCrateUnpacked`…) ; zones logistiques d'aérodrome (`FEAT-CTLD-AIRBASE-LOGISTICS`, fait) ; Fat Cow |
| `community/CSAR.lua` | sauvetage des pilotes |
| `veafCarrierOperations.lua`, `veafAssets.lua`, `veafMove.lua` | opérations porte-avions par menu radio, informations ravitailleurs et AWACS, repositionnement d'un ravitailleur par marqueur |
| `veafWeather.lua`, `veafAirbases.lua`, `veafAirfieldFrequencies.lua` | ATIS et METAR, données de pistes, fréquences d'aérodromes |
| `veafSpawn*.lua`, `veafShortcuts.lua`, `veafSecurity.lua` | commandes par marqueur pour un game master (spawn, destruction, fumigènes, flares, éclairage) derrière des niveaux de sécurité — le Zeus de Foothold n'a aucun contrôle d'identité |
| `veafRadio.lua`, `veafScheduler.lua`, `veafEventHandler.lua`, `veafI18n.lua` | menus F10 paginés qui survivent au recyclage d'ids de DCS, planification sur le timer natif, un répartiteur d'événements, un catalogue FR/EN |
| `veafCombatLog.lua` | chaque tir, impact et kill avec le tireur et son joueur : la matière première d'un système de récompenses ou de statistiques |

Rien dans `src/scripts/veaf/` ne correspond à ces mots : `credit` au sens d'une économie, `shop`, une échelle de rangs, `splash`, `force_player_slot`, `dormant` (grep, aucun résultat pertinent).

## 6. Catalogue et tableau de synthèse

L'effort est ce qu'il faudrait pour reproduire la fonctionnalité sur les briques VEAF, sans Moose : **faible** (quelques jours, sur une brique existante), **moyen** (un ou deux tickets, du code neuf en terrain connu), **fort** (un lot à lui seul, ou dépendant d'inconnues dans DCS).
« Réf. » renvoie à la note et à la section qui détaillent le mécanisme.

### 6.1 Zones, capture et carte

| Fonctionnalité | Ce que voit le joueur | Mécanisme | Équivalent VEAF | Effort | Réf. |
|---|---|---|---|---|---|
| Modèle de zone avec état neutre | zones colorées rouge, bleu, gris | un objet par zone lié à la trigger zone du même nom ; propriétaire 0/1/2 ; capture automatique des aérodromes DCS coupée | zones de `veafCampaign`, déclarées dans `campaign.yaml` | fait | 01 §1, §5 |
| Garnisons aléatoires par profil de taille | une défense différente à chaque campagne | effectifs par catégorie (SAM, SHORAD, AAA, sol, blindés, artillerie) tirés dans un pool de templates avec une graine de campagne | `veafCampaign.composeGarrison` sur les générateurs de `veafCasMission` | fait, par un autre chemin | 01 §2 |
| Sous-zones de spawn | groupes répartis dans la zone, SAM sur des emplacements préparés | 717 sous-zones posées à la main (`<Zone>-n`, `-SAM-`, `-SHORAD-`), point valide au hasard sur la terre | `veaf.findSpawnPoint`, `veafCampaign.placeGarrisonGroup` : aucune sous-zone à poser | fait, par un autre chemin | 01 §2 |
| Détection des pertes | « la zone a perdu un groupe » | **par scrutation** : chaque emplacement construit relu toutes les 10 à 60 s | `veafCampaign.onUnitDead` (événement) | fait | 01 §4 |
| Amélioration et réparation, un emplacement par livraison | « zone améliorée 3/8 », les groupes réparés reviennent entiers | `upgrade()` répare le premier groupe abîmé par respawn, sinon fait apparaître l'emplacement suivant | renforts seulement entre deux missions (règles de campagne) | moyen : une règle de renfort en direct et son déclencheur | 01 §4 |
| Efficacité au combat et reddition | les zones rouges affaiblies changent de couleur ; les dernières unités faibles peuvent se rendre | états plein / réduit / statique d'après les attributs des unités ; tirage de reddition de 40 à 80 % selon le palier | rien | faible | 01 §4 |
| Revenu de zone | des crédits à chaque tick | le propriétaire touche `income` à chaque mise à jour de zone | rien (pas d'économie) | faible une fois qu'une économie existe | 01 §4 |
| Zones désactivées et objets critiques | « zone détruite », dessinée en noir | zone désactivée pour de bon quand ses statics critiques sont morts | le décor détruit est enregistré ; pas d'état « zone détruite » | faible | 01 §5 |
| Canaux de capture | poser un hélicoptère, larguer des troupes ou une caisse, amener un convoi | chaque canal appelle `startPendingCapture` avec un participant | `veafCampaign.holdsGround` : une seule détection pour toute présence au sol | fait | 01 §6 |
| Capture temporisée | « Capture de X… », remplissage qui vire à la couleur en 4 paliers, ennemi prévenu | timer de 120 s lié à un participant vivant dans la zone ; annulée si tous sont perdus | la durée de tenue d'une zone neutre existe | faible : le dégradé de couleur et l'avertissement | 01 §7 |
| Advance capture | acheter un supply qui attend près d'une zone usée et la capture dès qu'elle tombe | seuil d'éligibilité sur le ratio construit ; supply retenu puis relâché à la neutralisation | rien | moyen, après les sorties de supply IA | 01 §8 |
| Dormance des zones | rien de visible ; les unités apparaissent quand les joueurs approchent | la suspension détruit la garnison en gardant les survivants par emplacement ; le réveil respawne un groupe toutes les 0,1 s puis réduit aux survivants ; une douzaine de raisons de rester éveillée | rien ; l'activation de `veafCombatZone` s'en approche | **fort** : prévu au ticket 02 ; le travail est dans les règles de maintien et le respawn qui préserve les pertes | 01 §9 |
| Graphe de connexions | lignes ou flèches entre zones | arêtes non orientées déclarées à la main, tables dérivées « reliée au bleu », matrice des distances entre zones | connexions et `neighbours` de `veafCampaign` | fait | 01 §10 |
| Calcul du front | non dessiné ; pilote les stations de CAP et l'AWACS | segments vers l'ennemi le plus proche et distance signée au front par zone | rien | moyen | 01 §11 |
| Formes et étiquettes de zone sur la carte | cercle ou quadrilatère coloré, une étiquette par coalition avec l'état de la garnison | ids de marques fixes mis à jour en place par `setMarkup*` | dessin de `veafCampaign` | fait ; le contenu de l'étiquette est faible | 01 §12 |
| Lignes de connexion et flèches de supply | colorées selon le propriétaire | `lineToAll` / `arrowToAll` entre les bords des zones | `veafCampaign.drawConnections` | fait | 01 §13 |
| Territoires colorés | cellules de Voronoï teintées par propriétaire, avec les frontières | géométrie en Lua pur, redessin incrémental, beaucoup de marques | rien | moyen | 01 §14 |
| Zones cachées, zones qui apparaissent, triggers de zone | des zones qui surgissent en cours de campagne | drapeau « caché » porté par le nom ; fonctions appelées sur capture / perte / destruction | rien | faible | 01 §15 |
| Menu d'état des zones | liste des zones par camp, texte d'état avec santé et coordonnées | menu par groupe reconstruit via une file | `veafCampaign.buildRadioMenu`, `situationText` | fait | 01 §16 |
| Victoire et défaite | « L'ennemi est vaincu », redémarrage | test sur les événements de zone ; sauvegarde effacée ; flag 181 → `a_end_mission` | rien dans `veafCampaign` (la campagne par épisodes se termine entre deux missions) | faible : ticket 05 | 01 §18 |

### 6.2 Persistance, cycle de vie et plomberie

| Fonctionnalité | Ce que voit le joueur | Mécanisme | Équivalent VEAF | Effort | Réf. |
|---|---|---|---|---|---|
| Sauvegarde de campagne | la progression survit à un redémarrage | table Lua sérialisée dans un fichier toutes les 60 s ; zones, survivants des garnisons, crédits, stock de la boutique, groupes IA vivants, mémoire du Director | `veafCampaign.writeState` (zones, garnisons, pertes, stocks, décor) | faible : la cadence et les champs en plus | 02 « Sauvegarde de campagne » |
| Sauvegarde étalée | pas de saccade à la sauvegarde | 8 zones collectées toutes les 0,1 s, puis sérialisation dans une coroutine | écriture en une fois | faible | 02 « Sauvegarde automatique étalée » |
| Restauration des vols et convois IA vivants | les vols réapparaissent en l'air après un redémarrage | position et état sauvegardés par groupe vivant, respawn en vol | rien | moyen, avec les sorties IA | 02 « Chargement de la campagne et réapplication au démarrage », 03 §16 |
| Persistance des entrepôts | les stocks d'armes survivent | CSV, un aérodrome par seconde | `veafCampaign` enregistre les stocks | faible | 02 « Persistance des entrepôts » |
| Fichier des joueurs | crédits, rang, carrière et langue suivent le joueur d'une carte à l'autre | indexé par UCID sur disque, par nom en jeu | rien | moyen : la première donnée persistante par joueur chez VEAF | 02 « Fichier de rang et de statistiques des joueurs » |
| Reset et redémarrage | commande admin « fin de mission et reset » | sauvegarde vide écrite, flag 181, le serveur recharge | rien | faible | 02 « Cycle de vie de la campagne » |
| Ères et PvE/PvP | Modern, Cold War, Vietnam ; variantes PvP | deux globales de config choisissent les jeux de templates et le nom de sauvegarde | `mission.era` filtre au build ; variantes de build | faible pour l'ère ; le PvP est une conception à part | 02 « Interrupteurs d'époque et de mode » |
| Contrôle des slots | des slots seulement là où son camp tient la base | coalition de l'aérodrome ; un user flag par groupe client ; rejet au `S_EVENT_BIRTH` par `net.force_player_slot` | `veafCampaign.setAirbaseCoalition` ; pas de rejet à la naissance | faible | 02 « Gestion du spawn des joueurs et contrôle des slots » |
| Tir fratricide | message et pénalité de rang | sur `S_EVENT_KILL` entre amis | rien | faible | 02 « Tirs fratricides » |
| Commandes admin par marqueur | rien pour les joueurs | des mots tapés dans un marqueur, sans liste d'admins, alias configurables | niveaux de `veafSecurity`, `veafRemote` | fait, et plus strict | 02 « Commandes par marqueurs de carte, admin et joueur » |
| Boucles principales, files, chien de garde | un avertissement à l'écran si la boucle meurt | vague de 10 s à 0,1 s par zone ; file d'évaluation avec budget ; chien de garde sur la dernière mise à jour terminée | `veafScheduler` ; `veafCampaign.beat` | faible : les schémas sont connus | 02 « Boucles principales et timers du moteur » |
| Files de menus F10 | les menus se rafraîchissent sans à-coup | poignées par groupe, rafraîchissement différé, un groupe par tick, test « inchangé » | `veafRadio` | fait pour l'arbre ; les budgets par groupe sont faibles | 02 « Gestion du menu radio F10 » |
| Langues | chaque joueur choisit parmi 10 langues | recherche par clé avec repli sur l'anglais ; portées serveur / joueur / groupe | `veafI18n` (FR, EN, une langue par mission) | moyen pour une langue par joueur | 02 « Sortie des messages et localisation » |

### 6.3 Groupes et sorties IA

| Fonctionnalité | Ce que voit le joueur | Mécanisme | Équivalent VEAF | Effort | Réf. |
|---|---|---|---|---|---|
| Machine à états des sorties aériennes | des vols IA qui partent du parking, volent, se posent, disparaissent | une machine à états scrutée par sortie ; spawn au parking ; tâches DCS brutes | les machines à états de `veafQraCore` / `veafAirWaves` pour les vols défensifs ; pas de sortie générique | **fort** : ticket 04 | 03 §2 |
| Spawn au parking | les avions apparaissent sur les stands | `SPAWN` et `AIRBASE` de Moose cherchent les places libres et écrivent `parking` par unité | `veafSpawnAircraft`, `veafAircraftSpawn` font apparaître des avions ; les données de parking par terrain existent côté outils | moyen | 03 §16 |
| Conditions de spawn et plafonds par rôle | moins de vols ennemis quand il y a moins de joueurs | un seul verrou ; plafonds CAP, CAS, SEAD, piste selon le nombre de joueurs et la difficulté | le niveau de `veafOpposition` | moyen | 03 §3 |
| Comportement des CAP | des patrouilles qui engagent, rentrent à court de munitions | hippodrome avec engagement en route, règles de retour, évitement des SAM | QRA et vagues | moyen | 03 §4 |
| Frappes (CAS, SEAD, piste, anti-navire) | des frappes ennemies sur les zones bleues | tables de tâches brutes par rôle | `veafCombatMission` fait apparaître des vols ennemis ; pas de frappe ciblée sur une zone | moyen pour chacune | 03 §5 |
| Sorties de surface | convois sur route, artillerie, navires | routes entre zones, arrivée → capture ou livraison | `veafCampaign.sendConvoy`, `absorbConvoy` | fait pour les convois d'assaut ; convois de supply faible | 03 §6 |
| Hélicoptères de supply IA | des hélicoptères qui se posent dans les zones, certains sous élingue | points de poser (109 zones sur le Caucase), récupération quand l'hélicoptère cale | rien ; deux pièges DCS sur le poser d'un hélicoptère scripté sont consignés dans `dcs-runtime-traps.md` | **fort** : poser un hélicoptère scripté sur un point n'est pas fiable dans DCS | 03 §9 |
| Patrouilles de garnison et AIEN | les groupes au sol patrouillent, débarquent, réagissent au feu | déplacement entre sous-zones d'après un préfixe de nom ; réactions AIEN | `veafGroundAI`, AIEN embarqué | faible | 03 §10 |
| Réseau de défense aérienne | des SAM qui s'allument et s'éteignent, cachés sur le MFD tant qu'ils n'ont pas été vus | un MANTIS par camp ; drapeau caché/révélé ; délai de réaction de nuit, flou radar à basse altitude | Skynet via `veafSkynetIadsHelper` | faible pour le réseau ; les règles de nuit et de révélation sont faibles à moyennes | 03 §11 |
| Bombardier stratégique et intercepteurs | un raid de bombardiers escorté ; des intercepteurs tirés contre lui | raid apparu en vol, surveillance, menus | rien | moyen | 03 §12 |
| Hunter | deux chasseurs envoyés après un joueur en série de kills | interception par Moose OPS | l'échelle des QRA s'en approche | faible à moyen | 03 §8, 06 §17 |
| Limiteurs et nettoyage | — | mises à jour étalées, machine à états en sommeil, file de spawn, nettoyage des épaves | plafonds prévus au PRD | moyen | 03 §15 |

### 6.4 Le Director

| Fonctionnalité | Ce que voit le joueur | Mécanisme | Équivalent VEAF | Effort | Réf. |
|---|---|---|---|---|---|
| Catalogue de capacités | — | enregistrements passifs : origine, cible, rôle, templates, condition | les « sorties dérivées du graphe » du PRD | moyen | 04 §2 |
| Cycle de planification et opérations | des attaques qui arrivent en packages, avec des pauses | tick de 30 s ; états attente / récupération / préparation / assaut / exploitation / poussée | rien ; dans `FEAT-MULTI-MISSION-CAMPAIGN` c'est Claude qui joue l'ennemi entre deux missions | **fort** | 04 §3 |
| Choix de cible | l'ennemi vise les zones faibles ou précieuses | score additif, tirage pondéré | `veafCampaign.planAssaults` (règle : tout voisin neutre) | moyen pour un score simple | 04 §4 |
| Objectif de campagne | une poussée ennemie cohérente dans une région | stratégie nommée, régions déclarées par carte, objectifs classés | rien | fort | 04 §5 |
| Composition du package, feinte, réserve | CAP + SEAD + frappe qui arrivent ensemble | doctrine → tirage pondéré des rôles ; réserve conditionnelle | rien | fort | 04 §6 |
| Phases, verrous, réévaluation, apprentissage | la SEAD avant le CAS ; des attaques annulées quand elles échouent | machine à phases, réévaluation toutes les 90 s, compteurs de résultats dégressifs sauvegardés en temps restant | rien | fort | 04 §8 |
| Slots de CAP de routine et décollage sur alerte | des CAP ennemies là où volent les joueurs | la notion de slot garde le nombre de CAP stable | QRA, vagues | moyen | 04 §9 |
| Sortie des forces au sol | un convoi ou un groupe d'artillerie de temps en temps | tirage toutes les 90 s sous des limites liées au nombre de joueurs | `veafCampaign.launchDueAssaults` | faible | 04 §10 |
| Réactions aux captures | du CAS détourné sur une zone que le bleu vient de prendre | opérations de réaction sur capture et sur pression | convoi de contre-attaque après un délai | moyen | 04 §12 |
| Difficulté et nombre de joueurs | plus dur à plusieurs, plus doux après des pertes | tables de paliers et profils de difficulté qui nourrissent toutes les limites | `veafOpposition` | faible à moyen | 04 §15 |
| Événements aléatoires | une mission de frappe, un événement spécial toutes les 15 à 25 min | `EventCommander` ; 17 événements sur le Caucase | rien | faible par événement ; le coût est dans le contenu | 04 §16 |
| IA bleue en PvE | des vols IA bleus en soutien de l'attaque des joueurs | soutien de la mission des joueurs, pas un plan | rien | moyen | 04 §14 |

`BudgetCommander` est du code mort en 6.5.3 (note 04 §13).

### 6.5 Économie, boutique, rangs, missions

| Fonctionnalité | Ce que voit le joueur | Mécanisme | Équivalent VEAF | Effort | Réf. |
|---|---|---|---|---|---|
| Crédits de coalition | un solde commun | un compte par camp | la réserve au sol de `veafCampaign` est un budget en unités, pas en crédits | faible | 05 §1 |
| Crédits personnels encaissés à l'atterrissage | « +50 crédits (non encaissés) », touchés en se posant dans une zone amie, perdus à la mort | attribution sur `S_EVENT_KILL`, classe de cible d'après les attributs DCS, test d'atterrissage 5 s après | `veafCombatLog` enregistre les mêmes événements | moyen | 05 §3 |
| Primes de temps de vol, de rotation, de nuit, de ravitaillement | de petits bonus | timers sur décollage et atterrissage ; événements de ravitaillement | rien | faible pour chacune | 05 §3 |
| Boutique | menu F10 par catégorie avec choix de zone ; marqueurs `buy:<id>` | registre d'articles, étagères par camp avec stock et rang, paiement différé | rien | moyen pour le mécanisme ; chaque article est un effet à part | 05 §2, §4 |
| Catalogue de la boutique | 45 articles sur le Caucase | chaque article appelle une fonction du moteur | partiel : plusieurs effets existent en commandes VEAF (fumigènes, éclairage, spawn de CAP ou de JTAC par marqueur) | par article, de faible à fort | 05 §5 |
| Rachat automatique de CAP | une CAP détruite est remplacée et payée toute seule | nombre de remplacements autorisés à l'achat | rien | faible une fois l'achat de CAP en place | 05 §6 |
| Rangs | 20 rangs qui conditionnent les articles | seuils sur les crédits de rang, sauvegardés par UCID | rien | moyen, avec le fichier des joueurs | 05 §7 |
| Statistiques et classements | des classements, un bilan par vol | compteurs par vol, par session, à vie | `veafCombatLog` + `veaf-tools mission combat-log` (après le vol) | faible pour un bilan en jeu | 05 §8 |
| Carrière et hauts faits | compteurs à vie avec paliers payés | par joueur et par appareil | rien | moyen | 05 §9 |
| Missions conjointes | des équipes de 4 au plus qui partagent les récompenses | invitation et partage | rien | moyen | 05 §10 |
| Missions joueurs | une liste de missions disponibles avec récompense, marques sur la carte | fonctions `isActive` / `isCompleted` scrutées ; 44 missions suivies sur le Caucase | `veafCombatMission`, `veafCombatZone`, `veafCasMission` : missions à la demande, sans récompense | moyen pour un tableau des tâches sur les missions existantes | 05 §11 |

### 6.6 Outils de soutien aux joueurs

| Fonctionnalité | Ce que voit le joueur | Mécanisme | Équivalent VEAF | Effort | Réf. |
|---|---|---|---|---|---|
| Drone JTAC | un drone qui illumine au laser les cibles d'une zone, menu pour le code, la priorité, la fumée | `Spot.createLaser`, mise à jour toutes les 0,5 s, liste de cibles tirée des groupes spawnés de la zone | `_spawn jtac` et le JTAC de CTLD (estimation : non comparés point par point) | faible | 06 §1 |
| JTAC 9-line | parler à un FAC à la radio | tâche DCS native `FAC` | JTAC de `veafSpawn` avec fréquence | fait ou faible | 06 §2 |
| Désignateur laser du joueur | un appareil éclaireur illumine ce qu'il a devant lui | recherche en cône par `world.searchObjects`, mise à jour du spot à 10 Hz par joueur | rien | moyen | 06 §3 |
| CSAR et pilotes ennemis | pilotes abattus avec balise et marqueur ; capture de pilotes ennemis | code propre à Foothold dans `LogisticCommander`, **pas** le CSAR de Moose | `community/CSAR.lua` | faible pour brancher des récompenses ; moyen pour la capture de pilotes ennemis | 06 §4 |
| Intel de zone | un rapport acheté pour 60 min et des marqueurs par groupe | lit la liste de spawn de la zone (« omniscient »), instantané puis différences | `FEAT-CAMPAIGN-INTEL-DELAY` (côté briefing) | moyen | 06 §5 |
| Ravitailleurs et AWACS à la demande | faire venir un ravitailleur, déplacer son hippodrome par menu ou par deux marqueurs | spawn en vol, TACAN, tâche d'hippodrome | plan de vol ravitailleur par marqueur de `veafMove`, `veafAssets` | faible | 06 §6–7 |
| AWACS qui suit le front | la station de l'AWACS bouge après chaque capture | station calculée d'après le front | rien | faible une fois qu'un front existe | 06 §7 |
| Contrôle des CAP | déplacer une CAP achetée avec `caphere1` / `caphere2` | paire de marqueurs → hippodrome | rien pour des vols achetés | faible | 06 §8 |
| Contrôle du porte-avions | menu « naviguer vers la zone » ; Tarawa par marqueur ; vent sur le pont | route en boucle, vitesse recalculée pour le vent, routage maritime `ASTAR` | `veafCarrierOperations` | faible : aller vers une zone nommée | 06 §10 |
| Callsigns, IFF, ATIS, aérodrome le plus proche | un callsign et un code IFF au spawn ; ATIS à la demande | attribution d'après le nom du groupe ; piste en service d'après le vent | ATIS de `veafWeather`, `veafAirbases` ; pas d'attribution de callsign | faible | 06 §11 |
| Escorte pour les joueurs | une escorte gratuite de deux avions avec choix d'altitude et ordres d'orbite | tâche native `Escort`, compteurs de génération | lot `FEAT-AWACS-ESCORT-COMMANDS` (🧑 en attente de son contrôle en jeu) | faible à moyen | 06 §12 |
| EWRS | image BRA et bogey dope, réglages par joueur | `getDetectedTargets(RADAR)` sur les radars amis | rien | moyen | 06 §13 |
| Zeus | marqueurs `-create`, `-destroy`, `-explode`, `-smoke`, `-illuminate` | aucun contrôle d'identité | `veafSpawn`, `veafShortcuts` derrière `veafSecurity` | fait | 06 §14 |
| Fumée, flares, éclairage sur des cibles | marquage acheté de 3 cibles | appels `trigger.action` bruts | `veafCombatZone` et `veafSpawnEffects` | fait | 06 §15 |
| Splash damage | les kills de zone crédités au joueur | script tiers, réglé | rien | moyen à embarquer et à maintenir ; un choix de conception | 06 §18 |

### 6.7 CTLD et entrepôts

| Fonctionnalité | Ce que voit le joueur | Mécanisme | Équivalent VEAF | Effort | Réf. |
|---|---|---|---|---|---|
| Catalogue de cargo avec prix et rangs | les articles CTLD coûtent des crédits et exigent un rang | veto avant le chargement et la construction | catalogue de CTLD 2, sans prix | faible une fois les crédits en place | 07 §2–3 |
| Zones qui suivent le propriétaire | des zones de chargement apparaissent sur les bases capturées | zones activées et désactivées à la capture | `FEAT-CTLD-AIRBASE-LOGISTICS` (les zones logistiques d'aérodrome suivent le propriétaire) | fait | 07 §4 |
| Troupes qui capturent ou renforcent | larguer des troupes pour capturer une zone neutre | événement CTLD → capture temporisée | `OnTroopsDeployed` de CTLD 2 → `veafCampaign.holdsGround` | fait | 07 §7 |
| Supplies de zone | porter des caisses physiques pour améliorer une zone | caisses suivies du chargement à la livraison toutes les 3 à 6 s | une caisse présente capture ; pas de « le supply améliore la zone » | moyen | 07 §8 |
| Logistique d'entrepôts | des stocks d'armes finis par aérodrome, déplacés par les joueurs | API d'entrepôt DCS via `STORAGE` de Moose ; réassorts ; règles de localisation | stocks de `veafCampaign` ; `veafQraLogistics` | moyen | 07 §9, §17 |
| FARP construits par les joueurs | construire un FARP avec entrepôt à partir d'un kit | static FARP invisible et statics fonctionnels | Fat Cow et `add_farp` (outils) ; décors de FARP de `veafGrass` | moyen | 07 §14 |
| C-130J : chargement, largage, construction automatique | larguer des caisses qui se montent toutes seules | événements de cargo dynamique, soldat auxiliaire caché | le script Hercules a été retiré en 6.18.0 ; prise en charge par CTLD 2 non vérifiée (estimation) | moyen | 07 §13 |
| SAM construits en plusieurs parties | ajouter des lanceurs à un site existant | fusion de groupes près d'un site | rien | moyen | 07 §11 |
| Équipes espion et démolition | des équipes IA qui donnent de l'intel ou font sauter des structures | infanterie routée avec minuteries | rien | moyen | 07 §10 |
| Persistance des unités construites | les unités et FARP construits survivent à un redémarrage | CSV de Moose et CSV de Foothold | non vérifié dans CTLD 2 (estimation) | moyen | 07 §16 |
| Production de supply des zones | l'étiquette de zone affiche `[SUP] n/max` et les travaux en cours (« Building: Armor 57 % ») ; « les supplies partent dans 30 secondes » | chaque zone tenue fabrique lentement des supplies, dépensés par les joueurs, par les vols de supply IA et par ses propres travaux de réparation et d'amélioration | la réserve de `veafCampaign`, comptée par camp et non par zone | moyen | 07 §26 |
| Bâtiment entrepôt d'une zone (Logistic Center) | un bâtiment `[WH]` destructible ; tant qu'il tient, stock d'armes illimité et production plus rapide ; réparable à la boutique en 30 min | un static par zone, suivi et sauvegardé | rien | moyen | 07 §27 |
| Infrastructures de théâtre | détruire un bâtiment de la carte coupe la route de supply rouge d'une zone SAM | bâtiments du décor déclarés par carte, lus par le Director | le décor détruit est enregistré par `veafCampaign` ; aucun effet attaché | faible à moyen | 07 §28 |
| Industrie et territoire de départ en PvP | objectifs industriels à frapper ; partage initial du territoire | zones industrielles avec leurs statics ; ordre de territoire écrit à la main par carte | rien (pas de PvP) | hors sujet tant qu'il n'y a pas de PvP | 07 §29 |
| Trains de supply (Normandie) | des trains ravitaillent les zones ; perdre un train ou une gare se paie ; réparation à la boutique | 51 liens de supply dont 20 par train, arrivée détectée par trigger zone et user flags | rien | moyen, propre à la Normandie | 07 §30 |

La note 07 §25 liste les fonctions du CTLD de Moose sur lesquelles Foothold s'appuie, pour une comparaison ultérieure avec CTLD 2.

### 6.8 Le côté créateur de mission

| Fonctionnalité | Ce que fait le créateur de mission | Équivalent VEAF | Effort | Réf. |
|---|---|---|---|---|
| Fichier de setup | écrit 5 000 à 10 000 lignes de Lua par carte | `campaign.yaml` et génération au build (PRD) | fait dans le principe | 08 §3 |
| Conventions du `.miz` | pose 1 331 trigger zones et 508 groupes templates selon des conventions de nommage | le build génère les zones et les slots ; aucun groupe template | fait dans le principe | 08 §4 |
| Fichier de config | 202 réglages en 22 sections | `mission.yaml` ; pour Foothold lui-même, `config_override:` (ADR 0008) | sans objet | 08 §2 |
| Config Manager | un outil Windows édite la config, télécharge et met à jour les missions, gère les `.miz.orig` de DCSServerBot | `veaf-tools`, `Publish-Foothold.ps1` | sans objet | 08 §5 |
| Exploitation serveur | désanitiser `MissionScripting.lua`, dossier de sauvegardes, reset | déjà vrai sur dcs.veaf.org (`io` et `lfs` ouverts, mesuré le 2026-10-03) | sans objet | 08 §6 |

## 7. Ce qui est couvert, ce qui est bon marché, ce qui coûte cher

**Déjà couvert par les briques VEAF** (la boucle de base) : zones avec état neutre, garnisons aléatoires, capture par présence au sol avec durée de tenue, coalition des aérodromes, carte F10 avec zones et connexions, menu de situation, convois d'assaut, fichier d'état, capture par troupes CTLD, zones logistiques qui suivent le propriétaire, marqueurs de game master, réseau de défense aérienne.

**Bon marché sur ces briques** : victoire et défaite avec reset, dégradé de couleur et avertissement de la capture en cours, reddition des zones faibles, objets critiques, compte de crédits de coalition, revenu par zone, rejet d'un slot à la naissance, contrôle des ravitailleurs et des CAP par marqueurs, porte-avions « naviguer vers la zone », bilan statistique, règles de sortie des forces au sol, mécanisme d'événements aléatoires.

**Cher**, avec la raison :

1. **La dormance des zones** — une douzaine de raisons de rester éveillée qui doivent s'accorder, et un respawn qui rend exactement les survivants aux mêmes endroits ; c'est aussi la fonctionnalité qui rapporte le plus en performance.
2. **Les sorties aériennes IA génériques** — spawn au parking, une machine à états par sortie, une tâche par rôle, la restauration après redémarrage ; Foothold y consacre environ 13 500 lignes (`GroupCommander`).
3. **Les hélicoptères de supply IA qui se posent dans les zones** — DCS ne pose pas de façon fiable un hélicoptère scripté sur un point (deux pièges consignés dans `docs/agents/dcs-runtime-traps.md`) ; sur une seule carte, Foothold a besoin de 109 zones de poser placées à la main et d'une procédure de récupération.
4. **Le Director** — 25 000 lignes ; la difficulté n'est dans aucune formule isolée, mais dans la quantité d'état partagé qu'il lit et dans l'hystérésis qui entoure chaque choix (note 04, « Notes de reproduction »).
5. **L'économie des joueurs prise en bloc** — crédits encaissés à l'atterrissage, boutique, rangs, carrière : chaque pièce est moyenne, mais ensemble elles exigent une donnée persistante par joueur, que VEAF n'a jamais eue, et un catalogue d'effets.
6. **La logistique d'entrepôts** — des stocks d'armes finis déplacés par les joueurs touchent chaque entrepôt d'aérodrome et la sauvegarde.

## 8. Ce qui n'a pas été lu

Les notes ont été écrites en une première passe, puis reprises par une passe de comblement sur tout ce qu'elles marquaient « non lu » ou « estimation » ; l'historique git de `foothold-analysis/` en garde la trace.
À l'issue (2026-11-15), il reste :

- notes 01, 04 et 05 : plus aucun trou marqué ;
- note 02 : huit estimations, toutes sur ce que le code ne montre pas — cinq sur le comportement de DCS ou du serveur (la suite de `a_end_mission`, le refus d'un slot sur une base adverse, un script serveur de blocage de slots absent du dépôt, la réutilisation des ids de groupe, la coalition d'un marqueur de spectateur), trois sur l'intention de l'auteur ;
- note 03 : une estimation (le niveau de compétence qu'AIEN donne aux groupes spawnés en cours de mission) ;
- note 06 : une estimation (le sens du mot « Native » dans `DynamicSupportNative`) ;
- note 07 : une estimation (le chargement d'un véhicule dans la soute du C-130J, fait par le module DCS) ; et `_regularSupplyCandidateUsable` (`zoneCommanderv2.lua:54507-54555`) lu en partie seulement ;
- note 08 : son tableau du setup marque encore « non lu » les lignes 3886–4240 et 6559–7458, qui ont depuis été lues et décrites dans la note 05 ; les captures d'écran du manuel n'ont pas été vues (seul le texte a été extrait) ; `MizBatchUpdater.exe` et `MizFileReplacer.exe` n'ont aucune documentation dans le dépôt ; le code C# du Config Manager n'a pas été lu, volontairement ;
- les fichiers de setup des neuf autres cartes n'ont été comparés au Caucase que par similarité de lignes, sauf la Normandie pour les trains (note 07 §30) ;
- l'intérieur d'AIEN et de MANTIS est décrit à partir d'extraits filtrés : quelques références de ligne peuvent être décalées d'une ou deux lignes ;
- rien n'a été lancé dans DCS : tout vient de la lecture du code, du manuel et du fichier de mission.

Erreurs trouvées et corrigées dans les notes pendant la passe de comblement, à connaître si une conclusion antérieure s'appuyait dessus : les kills par splash sont crédités directement par le script de splash et non par `S_EVENT_KILL` ; la navigation du porte-avions est sous le menu `Stats and Settings` ; le menu « Change callsign » n'est plus proposé en 6.5.3 ; la récompense de sauvetage va au sauveteur ; le CAS détourné sur une zone capturée ne concerne que les hélicoptères pas encore engagés ; l'escalade de difficulté est inactive sur le Caucase.

La colonne VEAF de la section 6 vient des en-têtes de modules et de grep, pas de la lecture de chaque module VEAF ; là où elle pèse sur une décision, lire le module d'abord.

## 9. Un constat de sécurité sur les missions que nous faisons tourner

Dans Foothold, un marqueur de carte F10 dont le texte commence par `-code:` voit le reste de son texte compilé par `loadstring` et exécuté (`zoneCommanderv2.lua:29203-29210` en 6.5.3).
La seule condition du gestionnaire est que l'événement de marqueur porte la coalition 1 ou 2 (`zoneCommanderv2.lua:28456`).
Il n'y a sur cette branche aucun contrôle de nom de joueur, d'UCID, de rang ni de mot de passe, et les alias admin configurables ne la couvrent pas.
Le même code est dans la 5.3.5 que font tourner nos missions (`VEAF-Foothold-Caucasus/src/scripts/zoneCommanderv2.lua:26331`).
Sur dcs.veaf.org, `io` et `lfs` sont ouverts aux missions (mesuré le 2026-10-03, voir le PRD), donc ce Lua peut lire et écrire des fichiers du serveur.
Non testé en jeu.
`Zeus.lua` (spawn et destruction par marqueur) n'a pas non plus de contrôle d'identité (note 06 §14).

## 10. Un ordre d'intégration possible

Une proposition à discuter, pas un plan ; chaque étape est un choix que David peut écarter.

1. **Finir la boucle de base sur l'existant** — le ticket 05 de ce lot (cadence de la sauvegarde périodique, victoire et défaite, reset) et le fignolage bon marché de la capture (couleurs et avertissement de la capture en cours, objets critiques).
   Cela donne une campagne persistante jouable avec des convois seulement, et c'est ce dont le ticket 07 a besoin pour mesurer quoi que ce soit.
2. **La dormance** (ticket 02) — avant d'ajouter de l'IA, parce qu'elle fixe combien de zones un serveur peut porter, et que les règles de Foothold (note 01 §9) sont une liste éprouvée de ce qui doit garder une zone éveillée.
3. **Un petit ennemi** — des capacités dérivées du graphe et un score simple pour la cible (notes 04 §2, §4, §10), au sol d'abord, puis des CAP par les briques QRA et vagues.
   Le Director complet n'est pas nécessaire pour avoir des contre-attaques ; il peut rester dehors, comme le dit déjà le PRD.
4. **Les sorties aériennes IA** (ticket 04) — frappes CAS et SEAD sur les zones, puis vols de supply ; les hélicoptères qui se posent dans les zones en dernier, ou remplacés par des convois et du CTLD, vu les pièges DCS.
5. **Une économie, si on en veut une** — d'abord un compte de crédits de coalition et un revenu, puis une boutique de quelques articles dont VEAF a déjà les effets (JTAC, fumée et éclairage, ravitailleur, CAP), puis les crédits personnels encaissés à l'atterrissage.
   Rangs, carrière et hauts faits demandent un fichier par joueur et peuvent venir en dernier, ou jamais.
6. **La profondeur logistique** — des supplies qui améliorent une zone via CTLD 2, puis des stocks d'entrepôt.
7. **Les outils de confort** — EWRS, intel de zone, porte-avions « naviguer vers la zone », attribution de callsigns, chacun indépendant du reste.

Le PRD met aujourd'hui hors périmètre la boutique, l'économie, les rangs, les événements, le Director, le tableau des tâches, le JTAC et les ravitailleurs à la demande ; les étapes 5 à 7 rouvriraient chacune une part de cela.

## 11. Scénario : retirer Moose de Foothold et le remplacer par nos outils

Question de David, 2026-11-15 : quelle est l'ampleur du chantier si l'on gardait Foothold tel quel et qu'on y remplaçait seulement Moose par les outils VMCT.
Chiffres tirés de la note 09 et d'un relevé par fichier fait le même jour ; les tailles de code à écrire sont des estimations.

### Ce qu'il faudrait toucher

Environ 4 000 appels à Moose dans sept scripts : moteur 2 471, `Foothold CTLD.lua` 763, `WelcomeMessage.lua` 372, `Foothold_CTLD_Red.lua` 194, `EWRS.lua` 101, setup Caucase 93, `Zeus.lua` 26.
`AIEN.lua` et `Splash_Damage_3.4.1_leka.lua` n'appellent pas Moose (grep, 0 occurrence hors commentaires).
Les fichiers de setup des neuf autres cartes ont chacun leurs propres appels, non comptés.

Nos outils n'offrent pas d'API compatible avec Moose : aucun `veaf*` ne répond à `GROUP:FindByName(x):GetCoordinate()`.
Il y a donc deux façons de faire, et seule la première tient face au rythme de l'amont :

- **une couche de compatibilité** (« Moose réduit ») : on réécrit, sur l'API DCS et nos modules, les seules fonctions de Moose que Foothold appelle — 112 membres statiques et environ 275 méthodes d'instance — sans toucher au code de Foothold ;
- **réécrire les appels** dans le code de Foothold : 4 000 modifications dans 130 000 lignes, à refaire à chaque release amont.

### Le chantier, par couche

| Couche | Appels (environ) | Remplacement | Effort |
|---|---|---|---|
| Utilitaires (`UTILS` : conversions, `DeepCopy`, `Round`, distances) | 480 | fonctions pures, en partie dans `veaf.lua` | faible |
| Messages, timers, menus (`MESSAGE`, `SCHEDULER`, `TIMER`, `MENU_GROUP*`) | 250 | `trigger.action.outText*`, `veafScheduler`, `missionCommands` | faible |
| Enveloppes d'objets (`GROUP`, `UNIT`, `STATIC`, `AIRBASE`, `ZONE`, `SCENERY` ; `:GetName`, `:IsAlive`, `:GetCoordinate`…) | 1 600 | objets légers sur `Group`, `Unit`, `Airbase`… ; le piège est de reproduire exactement leur comportement sur un objet mort ou absent | moyen : beaucoup de petites fonctions dont Foothold dépend du détail |
| `COORDINATE` et tâches (`WaypointAir*`, `Translate`, `Route`, `TaskLandAtVec2`, options ROE) | 550 | constructeurs de waypoints et de tâches DCS | moyen |
| Ensembles (`SET_*`, `FilterStart`) | 300 | listes tenues par événements ou balayages ponctuels | faible à moyen |
| Spawn (`SPAWN`, parking, registre `_DATABASE.Templates`) | 170 | copie de template avec alias, spawn au parking, rappels `OnSpawnGroup` ; `veafDcsSpawner` sait déjà appeler `coalition.addGroup` | moyen à fort : le choix des places de parking est la partie dure (note 03 §16) |
| Entrepôts (`STORAGE`) | 120 | API entrepôt de DCS | faible |
| Défense aérienne (`MANTIS`) | 3 sites, mais Foothold lit et modifie ses champs internes | Skynet via `veafSkynetIadsHelper` | moyen à fort : ce n'est pas le même comportement ; SAM cachés sur le MFD, révélation, zones de « scoot » et SHORAD sont à refaire et à régler |
| OPS (`AUFTRAG`, `FLIGHTGROUP`, `NAVYGROUP`, `ARMYGROUP`) | 6 sites | tâches DCS brutes | moyen ; ou abandonner Hunter, le cuirassé, l'artillerie navale et les V1 |
| CTLD (`CTLD`, `CTLD_CARGO` et la logistique de Foothold) | 1 000, et 11 900 lignes de Foothold écrites comme extensions du CTLD de Moose | porter toute la logistique sur notre CTLD 2 | **fort** |

### Ce qui décide de l'ampleur : CTLD

On ne peut pas garder le CTLD de Moose et retirer le reste : il repose sur le cœur de Moose (`BASE`, machines à états, `SET_*`, menus, `SCHEDULER`, base de données des unités).
Et le Moose embarqué est déjà modifié pour Foothold : son CTLD appelle `bc:debit`, `priceOf` et des hooks du moteur (note 07 §1).
Retirer Moose, c'est donc réécrire la logistique de Foothold sur CTLD 2 : prix et rangs, zones qui suivent le propriétaire, supplies de zone suivis physiquement, cargo d'entrepôt, kits de FARP, C-130J, espion et démolition, persistance des unités construites, CTLD rouge (note 07).
Ce morceau-là ne se fait pas par une couche de compatibilité : CTLD 2 n'a pas le même modèle que le CTLD de Moose, et chaque release amont qui touche `Foothold CTLD.lua` serait à reporter à la main.

### Le coût qui revient

L'amont a publié 16 releases en quatre semaines et ajouté 12 500 lignes au moteur.
Avec une couche de compatibilité, une mise à jour reste possible si l'on relance à chaque release le relevé de la note 09 pour voir quelles fonctions de Moose Lekaa a ajoutées, puis qu'on les écrit dans la couche.
La logistique portée sur CTLD 2, elle, diverge à la première release qui touche `Foothold CTLD.lua`.
Un fork doit rester sous GPL-3.0 et être publié comme tel.

### Ce que ça rapporterait : inconnu

Le moteur de Foothold est déjà en API DCS brute pour l'essentiel (note 02, recensement).
Ce que Moose coûte vraiment à l'exécution — le chargement de 132 000 lignes et de sa base de données, son propre gestionnaire d'événements, les ensembles tenus à jour, les boucles de MANTIS et de CTLD — n'a jamais été mesuré.
Le ticket 07 de ce lot prévoit justement la mesure (FPS par minute de DCSServerBot, profiler en mode `sample`).
Sans elle, le chantier peut coûter plusieurs lots pour un gain nul.

### Ordre de grandeur (estimation)

- couche de compatibilité hors CTLD et MANTIS : de l'ordre de 3 000 à 5 000 lignes de Lua et leurs tests ;
- MANTIS vers Skynet : un lot, plus des réglages en jeu ;
- OPS : quelques jours, ou rien si l'on abandonne ces fonctionnalités ;
- CTLD : un gros lot, du même ordre que les 11 900 lignes qu'il remplace, et la divergence avec l'amont qui va avec ;
- à chaque release amont : un relevé, quelques fonctions à ajouter à la couche, et un report manuel de ce qui touche la logistique.
