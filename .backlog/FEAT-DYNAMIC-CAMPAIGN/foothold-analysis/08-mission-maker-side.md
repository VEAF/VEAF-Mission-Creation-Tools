# 08 — Côté créateur de mission et administrateur de serveur (Foothold v6.5.3)

Sources, avec les noms courts utilisés dans les citations : `manual` = `Common Scripts/Foothold Manual v2.7.pdf` (63 pages, cité `manual p.N`), `Config` = `Common Scripts/Foothold Config.lua`, `ConfigWW2` = `Common Scripts/Foothold Config WW2.lua`, `setup` = `Setup files/MA_Setup_CAv2.lua`, `kola` = `Setup files/kola_setup.lua`, `zc2` = `Common Scripts/zoneCommanderv2.lua`, `mission` = le fichier `mission` à l'intérieur de `Missions/Foothold_CA_6.5.2_Coldwar-Modern-Vietnam.miz`, `FCM-README` / `FCM-CHANGELOG` / `gui.json` = les trois fichiers lus sous `tools/FootholdConfigManager/`, `README` = le `README.md` du dépôt.
Cette note porte sur ce que fait une personne pour écrire, configurer et exploiter une carte Foothold ; les mécanismes du moteur eux-mêmes sont dans les notes sœurs `01-zones-capture-map.md` à `07-ctld-warehouse-logistics.md` et ne sont que référencés ici.
Les comptes donnés comme « mesurés » viennent de scripts exécutés sur les fichiers (comptages par regex, parcours de tables Lua), pas d'une lecture.

## Liste des fonctionnalités

| # | Fonctionnalité | Description en une ligne | Emplacement principal |
|---|---|---|---|
| 1 | Le manuel | PDF de 63 pages, 14 chapitres ; la moitié est une référence des écrans du Config Manager. | `manual p.1-63` |
| 2 | `Foothold Config.lua` | 202 réglages de premier niveau (135 scalaires, 67 tables) en 22 sections, annotés par des commentaires `@gui` lus par le Config Manager. | `Config:186-3526` |
| 3 | Surcharge externe de la config | Une copie dans `Saved Games\<profile>\Missions\Saves` remplace celle du `.miz` ; les réglages manquants retombent sur la valeur interne par défaut avec un avertissement à l'écran. | `Config:1-186`, `Config:3517-3526` |
| 4 | `Foothold Config WW2.lua` | Config réduite (104 réglages) pour la Normandie, avec ses propres listes d'avions. | `ConfigWW2:1-999` |
| 5 | Fichier de setup par carte | Un fichier Lua par carte (5 000 à 10 000 lignes) qui déclare zones, garnisons, connexions, sorties, boutique, missions, événements. | `setup:1-10014` |
| 6 | Conventions du `.miz` | Trigger zones, groupes template en late activation, statics, aérodromes à spawn dynamique, entrepôts, 4 triggers. | `mission` |
| 7 | Foothold Config Manager | Outil Windows : éditeur de config, mise à jour/téléchargement de mission, profils météo/heure, aide à la désanitisation, multi-instance. | `FCM-README`, `FCM-CHANGELOG`, `manual p.4-29` |
| 8 | Exploitation du serveur | `MissionScripting.lua` désanitisé, dossier de sauvegarde, remise à zéro, chemins de mise à jour, cartes/époques prises en charge, PvE/PvP, localisation. | `README`, `manual p.4-5, 25-29, 56, 61-63` |
| 9 | Commandes d'administration | Mots-clés de marqueur, renommables via la Config, sans contrôle d'identité. | `Config:3468-3514`, `manual p.61-62` |
| 10 | Coût d'écriture d'une carte | Tailles mesurées que l'auteur d'une carte entretient à la main. | dernière section |

## 1. Le manuel (`Foothold Manual v2.7.pdf`)

Le PDF compte 63 pages et a été lu en entier à partir d'une extraction `pdftotext -layout` (l'outil Read n'a pas pu l'afficher sur cette machine : pas de `pdftoppm`) ; les captures d'écran n'ont donc pas été vues, seulement leurs légendes.
Environ 25 des 63 pages (p.5-29) sont une référence champ par champ du Config Manager ; les chapitres de gameplay sont courts.

### Table des matières (telle qu'imprimée p.2-3)

| Chapitre | Titre | Pages |
|---|---|---|
| 1 | Introduction and How to Start | 4 |
| 2 | Mission Options and Config (2.1 Config file location, 2.2 Cold War / Modern era, 2.3 Era, aircraft and weapon settings, 2.4 Config Manager and options reference with 18 sub-sections, 2.5 Ranking system, 2.6 RED reactive counterpressure, 2.7 Mods support, 2.8 Updating the Manager and missions) | 5-29 |
| 3 | Warehouse Logistics (3.1 Zone supplies vs warehouse items, 3.2 Loading and unloading cargo, 3.3 C-130J-30 operations, 3.4 Airdrop, 3.5 Supply missions, production and recovery, 3.6 Legacy supplies) | 29-36 |
| 4 | Overview, Spawning and Zones (4.1 F10 map, 4.2 Spawning, 4.3 Zones explained) | 37-38 |
| 5 | Missions (5.1 Main, 5.2 Joint, 5.3 Side, 5.4 Tankers, 5.5 Carrier navigation) | 39-43 |
| 6 | AI Behaviour (6.1 Dynamic AI, 6.2 Hunt, 6.3 Ground AI units, 6.4 AIEN, 6.5 Quiet zones and performance, 6.6 MANTIS, 6.7 EWRS) | 43-44 |
| 7 | Shop (7.1 Radio menu shop, 7.2 JTAC MQ-9, 7.3 AI attack groups, 7.4 CAP control, 7.5 Other categories, 7.6 Map-marker purchases) | 44-49 |
| 8 | CTLD (8.1 Capable units, 8.2 Troops, 8.3 Crates, 8.4 Building and operating a FARP, 8.5 Red CTLD and C-130 airdrops) | 49-52 |
| 9 | CSAR (9.1 Overview, 9.2 Menu, 9.3 Recovering a pilot, 9.4 Capturing enemy pilots) | 52-53 |
| 10 | Private Escort | 54 |
| 11 | Stats and Budget | 55 |
| 12 | PvP Campaigns (12.1 Start, 12.2 Amount of AI support, 12.3 Fight, supply and replace losses, 12.4 Troops and CSAR, 12.5 PvP shop items) | 56-60 |
| 13 | Admin Commands | 61-62 |
| 14 | End Game, Discord and Support | 63 |

### Fonctionnalités documentées, avec la page

« Sibling » désigne la note dont le tableau des fonctionnalités contient déjà l'élément ; « not in sibling tables » signifie qu'un grep des notes 01-07 sur les mots-clés de la fonctionnalité n'a rien trouvé, ou seulement une mention en passant (la note 07 était encore courte, 171 lignes, au moment de la vérification).

| Page | Public | Fonctionnalité telle que l'énonce le manuel | Sibling |
|---|---|---|---|
| 4 | joueur | Les crédits se gagnent individuellement et sont mis en banque pour toute la coalition en se posant sur une base amie. | 05 #3 |
| 4 | admin | `MissionScripting.lua` doit être désanitisé, à refaire après chaque mise à jour de DCS ; le Config Manager a un panneau qui l'applique et le vérifie. | 02 (load order/saves) ; panneau : cette note §5 |
| 4 | admin | « Disable Tacview » comme conseil de performance. | not in sibling tables |
| 4 | admin | La mission doit être lancée comme serveur multijoueur même en solo, à cause du spawn dynamique. | 02 (slot control) |
| 5 | admin | L'assistant du premier lancement installe `Foothold Config.lua` dans `Saved Games\<profile>\Missions\Saves` ; ne jamais dézipper le `.miz` à la main. | 02 (external config) |
| 5-6 | créateur de mission | Le changement d'époque exige que les entrepôts du Mission Editor soient « limited » pour les avions ; les navires (CVN-72/73/74/59, Tarawa) doivent être édités un par un, jamais en « copy to all ». | not in sibling tables |
| 7 | admin | Liste des époques : Modern, Coldwar, Gulfwar, Vietnam ; listes Active/Inactive d'avions et d'armes ; la date de la mission ne peut pas être fixée par script (1989 recommandé pour la Guerre froide, 1975 pour le Vietnam). | 02 (era switch) |
| 8 | admin | Presets : jusqu'à trois instantanés de config nommés par instance et par type de config. | cette note §5 |
| 9 | admin | « Update Config > Update from MIZ » fusionne les valeurs par défaut d'une nouvelle version dans la config existante, avec une sauvegarde horodatée (cinq conservées). | cette note §5 |
| 10 | admin | Unités terrestres : nombre max de groupes par zone, liste de contrôle des templates SAM RED, désactiver MANTIS, cibles terrestres statiques, masquer les SAM sur le MFD, temps de réaction de la défense aérienne la nuit, plus difficile à détecter la nuit. | 01 #2, 03 #11 |
| 10-11 | admin | Listes de contrôle des templates de vols IA (12 listes), probabilité que l'IA attaque les hélicoptères. | 03 #1 |
| 11 | admin | Start Normal (inverser le sens de la campagne sur 4 cartes), Start From Incirlik, Remove Southern Syria. | not in sibling tables (interrupteurs propres à la Syrie) |
| 11 | admin | Auto Restart, PVE Only, Allow Mods, perte de crédits et de rang à la mort, Splash Damage, Show Kills, Store Limit, Ranking System, pénalité de tir ami, Invisible A-10, rang requis pour le porte-avions, commandes de marqueur Tarawa. | 02, 05 #7, 06 #10 |
| 12 | admin | Profils de difficulté (easy/medium/hard par rôle), échelle de vitesse de spawn IA par camp, compétences IA, Hunter, interrupteurs d'intel du Director, difficulté réactive RED. | 04 #15, 03 #8 |
| 12 | admin | Tables d'étapes : seuil de joueurs vers quantité, la dernière ligne non supérieure au nombre de joueurs comptés l'emporte ; listes d'ignorés de types d'avions qui ne comptent pas comme joueurs. | 04 #15 |
| 12-13 | admin | Message of the Day : un texte serveur 10 s après le démarrage, puis à chaque intervalle. | 02 (une mention) |
| 13 | admin | Familles d'indicatifs par avion avec quatre codes IFF LotATC chacune. | 06 #11 |
| 13 | admin | Table d'escorte : par type d'avion joueur, activée ou non, et quel template de CAP BLUE l'escorte ; option de décollage depuis le sol. | 06 #12 |
| 13-14 | admin | Interrupteur Warehouse Logistics, temps de capture neutre (120 s), capacités de supply (normal 1, `[WH]` 6, FARP CTLD 1), échelle de vitesse de supply et de réparation par camp, temps de réparation RED supplémentaire quand il y a peu de joueurs. | 01 #7 (temps de capture) ; durées de production/réparation : not in sibling tables |
| 14 | admin | Les prélèvements des joueurs consomment le stock, chargeurs natifs C-130/Chinook, hélicoptères IA qui transportent un vrai cargo, quantité de livraison IA (20), remplissage automatique (5 toutes les 15 min), désactiver ou mettre en pause par radio les supplies IA BLUE, avertissement au décollage quand c'est vide, inventaire strict des armes intelligentes. | 03 #9 (cargo d'hélicoptère) ; le reste not in sibling tables |
| 14-15 | admin | Boutique : seuil d'advance capture, prix, rangs requis, table des contributions de récompense (15 clés), récompense de ravitaillement, décollage des groupes d'attaque IA depuis le sol, achat admin, supplies scriptés, bonus de nuit. | 05 #5, #13 |
| 15-18 | admin | CTLD : interrupteur de coût, CTLD rouge, capture par ingénieur, nombre max de FARP sauvegardés, règle de fusion IRIS, table prix/rang, limites de restauration « Max at spawn », table de capacités par avion. | 07 |
| 18-19 | admin + joueur | CSAR : avions et sièges autorisés, chance de spawn sans crédits, max simultané et au redémarrage, poids du pilote, distance/hauteur/secondes de vol stationnaire, distance de guidage, probabilité d'infanterie hostile ; auto-récupération à moins de 3 NM ; les crédits du pilote abattu vont à son sauveteur. | 06 #4 |
| 19 | admin | Récompense de temps de vol (par minute après 5 min) et sa table par type. | 05 #3.3 |
| 19-20 | admin | Vitesses par défaut des ravitailleurs ; menu de vitesse en jeu 220/286/300/320/340 kt conservé d'un redémarrage à l'autre. | 06 #6 |
| 20-21 | admin + joueur | EWRS : 22 valeurs par défaut ; l'une d'elles (intervalle de mise à jour) est documentée comme sans effet (« the automatic scheduler is fixed at 20 seconds »), et Friendly Picture n'a pas de commande de menu. | 06 #13 |
| 21-22 | admin | Interrupteurs AIEN et trois timers de cadence. | 03 #10 |
| 22 | admin | Listes d'avions/d'armes par époque ; « Forbidden Weapons All Eras » (par défaut : les bombes nucléaires RN-24 et RN-28). | 07 (entrepôt) |
| 22-23 | admin | Affichage des connexions sur la carte F10 (flèches ou lignes, dynamiques ou blanches) ; tables radio AWACS, ravitailleur et porte-avions. | 01 #13, 06 #6-#10 |
| 23 | admin | Réglages verrouillés tant que le PvP est actif (liste de neuf groupes). | 03 #14, 04 #14 |
| 23-24 | joueur | Échelle de rangs : 20 titres de Recruit (0) à General of the Air Force (540 000), stockés dans `Foothold_Ranks.lua`, jamais remis à zéro, partagés par toutes les missions Foothold. | 05 #7 |
| 24 | joueur | Contre-pression réactive RED : douce (supply et CAP plus rapides) et dure (groupes d'attaque forcés). | 04 #12 |
| 24 | créateur de mission | Mods : la colonne EQP de l'entrepôt remplie avec 10 000 et copiée sur tous les aérodromes ; ne jamais cocher A/C ou les bases neutres deviennent à spawn dynamique. | not in sibling tables |
| 25-29 | admin | Flux de mise à jour de mission (fichiers seuls, téléchargement complet, copie d'entrepôt, enregistrement dans la liste des serveurs). | cette note §5 |
| 29-31 | joueur | Warehouse logistics : centre logistique `[WH]` au stock illimité, zone supplies contre warehouse items, abréviations des étiquettes de stock bas (A/A, A/G, RKT, TNK, G-B, U-B), étiquettes `[SUP]`/`[Supplies] n/m` avec une barre de progression à cinq cases, jobs Building/Repairing/Training (deux à la fois), `[WH destroyed]` et une réparation payante de 30 min. | 07 (en partie) ; grammaire des étiquettes et durées des jobs : not in sibling tables |
| 32-34 | joueur | Chargement des zone supplies uniquement par le panneau de réarmement « Cargo » de DCS, jamais par la commande de chargement CTLD ; décharger dans la zone. | 07 |
| 34-36 | joueur | C-130J-30 : jusqu'à 4 zone supplies (4 = capture/upgrade plus 40 de chaque article), largage avec parachutes, le cargo CTLD se construit automatiquement environ 30 s après un largage si toutes les pièces atterrissent à moins de 2 000 m et pas sur une maison. | not in sibling tables (construction automatique après largage) |
| 36 | joueur | Durées de production et de récupération : 20 min par supply (10 min dans une zone `[WH]`), base de réparation BLUE 15 min (5 min `[WH]`) + 2 min par unité ou 3 min par radar, RED 1 min par unité, plafond 20 min. | not in sibling tables |
| 36 | joueur | Supplies legacy quand `WarehouseLogistics = false` : menu Load/Unload Supplies, un supply = un groupe. | 07 (estimation) |
| 37 | joueur | Message de bienvenue avec ATIS et piste (BRC sur les porte-avions), indicatif et IFF automatiques. | 06 #11 |
| 37-38 | joueur | Étiquette de zone `Name (waypoint) built/total` ; les zones hostiles masquent le compte ; teinte de zone RED rouge / rouge clair (plus de défense aérienne) / violet (statics seulement) ; capture neutre temporisée avec progression dans l'étiquette. | 01 #4, #7, #12 |
| 39 | joueur | Missions principales : Attack (plus une troisième « dynamic operation area »), Supply, Capture, CAS, CAP, Recon (10 min d'intel), Bomb Runway, SEAD. | 05 #11 |
| 39-40 | joueur | Missions conjointes : jusqu'à quatre joueurs, récompense complète chacun, 120 s pour accepter. | 05 #10 |
| 40-41 | joueur | Missions secondaires : Strike (250-1 000), interception de frappe aérienne / bombardier / avion cargo, escorte en hélicoptère d'un convoi terrestre (1 000 crédits, un FARP à environ 70 % de l'itinéraire, menu du convoi : arrêt/marche, fumigène, relèvement). | 05 #11, 04 #16 ; l'escorte de convoi terrestre a une mention dans 05 |
| 42 | joueur | Ravitailleurs : déblocage unique, menu de contrôle, racetrack par deux marqueurs (`arcohere1/2`, `texacohere1/2`), rang 3 par défaut. | 06 #6 |
| 43 | joueur | Navigation des porte-avions : menu « Sail to <area> », avertissements de virage à 5 min et 1 min, commandes de marqueur Tarawa. | 06 #10 |
| 43 | joueur | L'IA dynamique s'adapte au nombre de joueurs ; A-10, C-130 et hélicoptères ne sont pas comptés ; Hunt ; unités terrestres en patrouille ; réponse défensive BLUE (contre-attaque terrestre en cas de brèche) ; zones calmes suspendues. | 03, 04 #9, 01 #9 |
| 44 | joueur | Réseau MANTIS (piloté par les EWR, mode de secours quand tous les EWR sont morts, shoot-and-scoot) ; menu de réglages EWRS. | 03 #11, 06 #13 |
| 45 | joueur | Catégories de la boutique : AI Attack, Zone Upgrades, JTAC & Intel, Combined Arms, Capture & resources, Other Support. | 05 #4, #5 |
| 45 | joueur | JTAC MQ-9, laser 1688, six entrées de menu. | 06 #1 |
| 46-47 | joueur | Groupes d'attaque IA avec « Push now / Push on command » pour SEAD et Decoy ; menu de contrôle des CAP et marqueurs `caphere1/2` ; les racetracks de CAP évitent la couverture SAM connue. | 05 #5, 06 #8 |
| 47 | joueur | Emplacement d'upgrade supplémentaire : deux upgrades achetés par zone, un troisième après un déblocage de coalition (Normandie : un, puis deux). | 05 (catalogue de la boutique) |
| 47 | joueur | Réparation de la voie ferrée en Normandie (2 000 crédits). | not in sibling tables (une mention dans 01 et 04) |
| 48 | joueur | Deploy FARP : marqueur hors des zones, à au moins 10 NM d'une zone ennemie, base amie à moins de 100 NM, livré par hélicoptère. | 05, 06 |
| 49 | joueur | Achats par marqueur `buy` et `buy:<itemID>`. | 05 #4 |
| 49-50 | joueur | Équipes spéciales CTLD : Zone Spy (60 min d'intel) et Demolition Team (détruit les structures, partage les cibles entre équipes). | 07 (une mention chacune) |
| 50-51 | joueur | Le L118 tire sur les cibles JTAC à moins de 7 NM, le HIMARS entre 9 et 29 NM ; les ajouts SAM fusionnent à moins de 400 m ; pack / pack and load / pack and remove avec remboursement. | 07 |
| 51 | joueur | FARP et FARP avec ZELL (point de décollage à longueur nulle pour F-100D), 30 de la plupart des armes et 90 roquettes à la construction. | 07 |
| 52 | joueur | CTLD rouge ; Pantsir (Blue) et Tor M2 (Red) réservés au PvP ; espacement de 8 NM entre unités du même type pour les Pantsir/Tor/SA-8 construits par CTLD. | 07 (Pantsir mentionné), règle d'espacement not in sibling tables |
| 52-53 | joueur | Menu CSAR, récupération en vol stationnaire et à l'atterrissage, capture de pilote ennemi avec 50 % de chance d'obtenir 30 min d'intel et 20 % de chance de révéler les plans du Director. | 06 #4 |
| 54 | joueur | Escorte privée pour A-10, C-130J-30, F-15E : deux F/A-18 10 000 ft au-dessus, distance de protection 40 NM, mode flight-sweep. | 06 #12 |
| 55 | joueur | Menu de statistiques (My Stats, All Stats, Top 5), bonus de même avion, aperçu du budget. | 05 #8 |
| 56 | admin | PvP : Caucase, Syrie et golfe Persique seulement ; territoire de départ 20/30/40/50 % par camp ; fonds de démarrage 1 000 par camp ; noms de sauvegarde séparés ; victoire quand l'adversaire ne possède aucune des zones de victoire principales. | 01 #18, 02 ; part du territoire de départ not in sibling tables |
| 56-57 | admin | IA PvP : limite partagée de groupes IA à voilure fixe réduite par les avions joueurs du camp (0 = équilibrer le nombre de joueurs), interrupteur de supplies automatiques, interrupteur d'escortes, listes d'avions séparées. | 03 #14, 04 #14 |
| 57 | joueur | Objectifs de frappe industrielle PvP (300 par bâtiment, plafond 1 000, territoire ami à moins de 100 NM) et objectifs EWR fixes (50 NM). | not in sibling tables |
| 58 | joueur | PvP : deux slots AWACS par camp, remplaçables un à la fois ; ravitailleurs destructibles. | 06 #7 |
| 59-60 | admin | Tables de boutique PvP : paliers nationaux d'upgrade et liste des articles non proposés en PvP. | 05 #5 |
| 61-62 | admin | Commandes d'administration : 11 mots de marqueur renommables, exacts et sensibles à la casse, sans contrôle de nom ni de mot de passe. | 01 #17, 02 (marker commands) |
| 63 | admin | Victoire : menu de redémarrage ou redémarrage automatique ; les sauvegardes de mission et de CTLD sont supprimées. | 01 #18, 02 |

### Affirmations du manuel à retenir pour une réimplémentation

Le manuel dit que le Config Manager, et non la mission, est le moyen pris en charge pour toucher à la configuration : « Do not open the miz as a ZIP or manually move Foothold Config.lua » (`manual p.4`).
Il indique que `MessageUpdateInterval` d'EWRS est exposé mais non honoré par le runtime (`manual p.20`), et que « Allow Friendly Picture » n'a pas d'entrée de menu (`manual p.20`).
Il indique que « Warehouse Weapon Caps » est mal nommé : l'appartenance à la liste divise par deux chaque réapprovisionnement, il n'y a pas de plafond numérique (`manual p.14`).
Il indique que les commandes de marqueur d'administration n'ont aucun contrôle de nom d'administrateur ni de mot de passe et doivent être protégées par le choix de mots secrets (`manual p.62`).
Il indique que la date de la mission ne peut pas être changée par script et doit être fixée dans le Mission Editor pour chaque époque (`manual p.7`).
Il indique que le PvP n'existe que sur trois cartes et que l'activer ne convertit pas une sauvegarde PvE en cours (`manual p.56`), ce qui concorde avec `Config:3525` qui force `PvP = false` sur tout autre théâtre.

## 2. `Foothold Config.lua`

### Structure du fichier

Les lignes 1-186 sont du code de chargement marqué « do not touch » : le fichier cherche une copie de lui-même dans `lfs.writedir() .. "Missions\\Saves"` et, s'il la trouve, l'exécute par-dessus les valeurs internes par défaut (`Config:1-7`, `Config:153-186`).
Deux listes, `FootholdConfigTrackedTableNames` (62 noms) et `FootholdConfigTrackedScalarNames` (18 noms), nomment les réglages dont l'absence de la copie externe doit être signalée (`Config:9-92`).
Le chunk externe est exécuté dans un environnement dont le `__newindex` enregistre chaque nom assigné ; une table suivie encore égale à la valeur interne par défaut, ou un scalaire suivi jamais assigné, est listé dans un `env.warning` et dans un message à l'écran répété 12 fois à intervalles de 10 s (`Config:94-135`).
Une erreur de syntaxe dans la copie externe est signalée à l'écran toutes les 30 s par « FOOTHOLD CONFIG ERROR » (`Config:137-146`).
En Normandie, le même chargeur lit `Foothold Config WW2.lua` dans le `.miz` (`l10n/DEFAULT/`) puis dans le dossier Saves (`Config:2-6`, `Config:163-181`).
Les dernières lignes forcent `PvP = false` sauf si le théâtre est Caucasus, Syria ou PersianGulf, et posent `FootholdConfigLoadedOk` (`Config:3525-3526`).
Le détail du mécanisme de surcharge est dans `02-persistence-lifecycle-plumbing.md` (« External config override »).

Les réglages portent des annotations en commentaires `-- @gui ...` que Lua ignore et que le Config Manager lit : `label`, `editor` (`checkboxTable`, `linkedTable`, `fieldTable`, `sideMultiplier`, `bucket`), `validValues`, conditions `visibleWhen` / `disabledWhen` portant sur d'autres réglages, `installPolicy` (`mergeRows`, `replaceTable`, `keepTable`) utilisé lors de la fusion d'une nouvelle version, `requiredValues` / `requiredSet` qui relient les templates IA aux types d'avions devant rester dans les listes de l'entrepôt (`Config:246-247`, `Config:552-556`, `Config:1607`, `Config:2393-2417`).
Les commentaires de ligne de la forme `-- eras=Modern|Coldwar; label` étiquettent chaque ligne de template avec les époques auxquelles elle appartient, ce que le Manager utilise pour cocher les lignes quand l'époque change (`Config:249-262`).
Le fichier Lua est donc à la fois la configuration d'exécution et le schéma de l'outil d'édition.

### Compte

Mesuré avec un script qui parcourt les affectations de premier niveau à partir de la ligne 186 : 135 réglages scalaires et 67 réglages tables, soit 202 au total (les 139 scalaires bruts du script incluent `GlobalSettings = GlobalSettings or {}`, `AIEN = AIEN or {}`, `AIEN.config = ...` et `FootholdConfigLoadedOk`, qui ne sont pas des réglages).
L'une des 67 tables, `WarehouseWeaponLocationAirbases`, est un catalogue de noms d'entrepôts par carte pour le sélecteur du Manager, et non un réglage de comportement (`Config:1436-1571`).
Les tables contiennent 1 181 lignes actives de premier niveau et 408 lignes commentées que le Manager présente comme des choix « inactifs » (somme des comptes par table du même script).

### Inventaire par section

Les valeurs par défaut sont celles du fichier ; « lignes » est le nombre d'entrées actives au premier niveau de la table.

**Options de mission** (`Config:193-299`, 20 réglages)

| Réglage | Défaut | Signification |
|---|---|---|
| `Era` | `"Modern"` | `Modern`, `Coldwar`, `Gulfwar` (nom irakien de Coldwar) ou `Vietnam` ; sélectionne les templates, les listes et le nom de sauvegarde (`Config:196-198`). |
| `PvP` | `false` | Mode symétrique ; seulement Caucase, Syrie, golfe Persique (`Config:200-202`, `Config:3525`). |
| `FootholdLocale` | `"EN"` | Langue des messages globaux ; 10 valeurs EN, DE, FR, ES, RU, PT-BR, TR, IT, zh-CN, zh-TW (`Config:204-220`). |
| `StartNormal` | `true` | `false` démarre par l'autre bout de la carte et désactive la zone du porte-avions ; Caucase, golfe Persique, Syrie, Afghanistan seulement (`Config:225-227`). |
| `StartFromIncirlik` | `false` | Syrie, PvE : démarrer depuis Incirlik au lieu d'Akrotiri (`Config:229-233`). |
| `RemoveSouthSyria` | `false` | Syrie : retirer les zones du sud, la progression est conservée (`Config:235-240`). |
| `AutoRestart` | `false` | Remise à zéro et redémarrage automatiques à la victoire, sinon un menu (`Config:242-244`). |
| `PVE_Only` | `false` | Les joueurs Red ne peuvent pas apparaître dans les zones rouges (`Config:246-251`). |
| `AllowMods` | `false` | La warehouse logistics réapprovisionne aussi les armes de mods ; Modern seulement (`Config:253-258`). |
| `CreditLosewhenKilled`, `CreditLosewhenKilledAmount` | `false`, `100` | Crédits de la coalition perdus à chaque mort d'un joueur (`Config:260-264`). |
| `RankLoseWhenKilled`, `RankLoseWhenKilledAmount` | `true`, `100` | Crédits de rang perdus à chaque mort d'un joueur (`Config:266-270`). |
| `SplashDamage` | `false` | Charger le script de splash damage (`Config:272-273`). |
| `ShowKills` | `false` | Messages de kill de Foothold (`Config:275`). |
| `StoreLimit` | `false` | Seuils de crédits gagnés pour les articles chers (>250 exige 100 gagnés, >1000 exige 1000, >2000 exige 2000, >3000 exige 3000) (`Config:277-282`). |
| `RankingSystem` | `true` | Rangs et seuils de rang (`Config:284-285`). |
| `FriendlyFireRankPenalty` | `500` | Crédits de rang retirés à chaque tir ami (`Config:287-288`). |
| `CarrierRankRequirement` | `5` | Rang nécessaire pour déplacer le porte-avions (`Config:290-292`). |
| `AllowTarawaToMoveFreely` | `false` | Commandes de marqueur du Tarawa (`Config:294-299`). |

**Réglages PvP** (`Config:302-337`, 6 réglages)

| Réglage | Défaut | Signification |
|---|---|---|
| `StartupFunds` | `{[1]=1000,[2]=1000}` | Crédits par camp au début d'une manche PvP, neuve ou remise à zéro (`Config:304-311`). |
| `PvPStartingTerritoryPercent` | `50` | Part des zones éligibles donnée à chaque camp au départ : 20, 30, 40 ou 50 (`Config:313-318`). |
| `pvp_supplies` | `true` | Supplies IA automatiques pour les deux camps, sinon seulement quand ils sont achetés (`Config:320-322`). |
| `PvPEscorts` | `false` | Offre d'escorte gratuite de deux appareils en PvP (`Config:324-327`). |
| `PvPDisableCombatAI` | `false` | Pas de vols de combat automatiques ordinaires (`Config:329-331`). |
| `PvPCombatAIGroupLimit` | `10` | Groupes de combat IA à voilure fixe automatiques par camp moins les avions joueurs du camp ; 0 = équilibrer le nombre de joueurs (`Config:333-337`). |

**Fréquences** (`Config:340-397`, 5 tables)

| Réglage | Défaut | Signification |
|---|---|---|
| `AWACSRadioFrequencies` | 4 lignes : Blue 251 / 251.5, Red 252 / 252.5 MHz AM | Les lignes Red ne s'appliquent qu'en PvP (`Config:343-354`). |
| `TankerRadioSettings` | 5 lignes : Blue Arco 260 / TACAN 101Y, Blue Texaco 266 / 102Y, Shell 253 / 103Y, Red Arco 260 / 104Y, Red Texaco 266 / 105Y | Fréquence et TACAN par ravitailleur (`Config:356-370`). |
| `CarrierNavigationRadios` | 3 lignes : CVN-72 TACAN 72X ATC 272, CVN-74 74X 274, Tarawa 1X 271.5 | (`Config:372-383`). |
| `CarrierNavigationICLS` | CVN-72 = 12, CVN-74 = 14 | Canal ICLS, 0 = désactivé (`Config:385-390`). |
| `CarrierNavigationLink4` | CVN-72 = 372, CVN-74 = 374 | Link 4 en MHz, 0 = désactivé (`Config:392-397`). |

**Carte F10** (`Config:400-411`, 2 réglages) : `ConnectionMapStyle = "line"` (`"arrow"` ou `"line"`) et `ConnectionMapColor = "dynamic"` (`"dynamic"` ou `"white"`).

**Difficulté** (`Config:414-438`, 4 réglages)

| Réglage | Défaut | Signification |
|---|---|---|
| `GlobalSettings.difficultyScaling` | `{[1]=1.0,[2]=1.0}` | Multiplicateur des timers IA hors supply, par camp, de 0,10 à 5,00 (`Config:417-423`). |
| `GlobalSettings.directorBattlefieldIntelligenceEnabled` | `true` | Le Director se souvient des résultats des sorties et des supplies (`Config:425-431`). |
| `GlobalSettings.directorAirCombatIntelligenceEnabled` | `true` | Le Director utilise les résultats récents de combat aérien pour rediriger les CAP (`Config:433-436`). |
| `RedReactiveDifficulty` | `"medium"` | Profil de la contre-pression réactive (`Config:438`). |

**Unités terrestres** (`Config:443-544`, 12 réglages)

| Réglage | Défaut | Signification |
|---|---|---|
| `MaxRedGroundGroupsPerZone` | `12` | Plafond de groupes Red générés par zone dans une campagne PvE neuve, de 5 à 12 ; maxima par carte listés dans le commentaire (Caucase 10) (`Config:445-463`). |
| `MaxBlueGroundGroupsPerZone` | `4` | Idem pour la garnison Blue aléatoire, de 1 à 4 (`Config:465-481`). |
| `DisableZonePatrol` | `false` | Pas de déplacement des groupes terrestres à l'intérieur des zones (`Config:483-486`). |
| `RedTemplateEnabled` | 14 lignes, toutes `true` | SA-2, SA-3, SA-5, SA-6, SA-8, SA-9, SA-13, SA-15, SA-19, SA-10, SA-11, Tor M2, Pantsir S1, MANPAD, chacune étiquetée avec ses époques (`Config:488-507`). |
| `DisableMantis` | `false` | Désactiver la défense aérienne coordonnée (`Config:509-511`). |
| `UseStatics` | `true` | Cibles terrestres statics dans les zones (`Config:513-515`). |
| `HideSAMOnMFD` | `"random"` | `false`, `true` ou `"random"` (50 % par spawn) (`Config:517-522`). |
| `RevealSamOnMfdAfterDetection` | `false` | PvE : révéler un SAM à son prochain spawn une fois qu'il a émis ou a été identifié par l'Intel (`Config:524-527`). |
| `NightMantisInterval` | `30` | Secondes entre deux décisions de la défense aérienne la nuit (15 de jour), 0 = désactivé (`Config:529-533`). |
| `NightRadarBlur` | `true` | Les joueurs volant bas sont plus difficiles à détecter la nuit (`Config:535-538`). |
| `RedAiGroundSkill`, `BlueAiGroundSkill` | `"Excellent"` | Niveau de compétence DCS des défenseurs terrestres des zones (`Config:540-544`). |

**Vols IA** (`Config:547-882`, 24 réglages)

| Réglage | Défaut | Signification |
|---|---|---|
| `RedCapPlaneEnabled` | 18 lignes | Liste de contrôle de noms de templates du `.miz` tels que `RED_MIG29S_CAP_R77x3_R27ET_R73x2`, chacun étiqueté avec ses époques et le type d'avion qu'il exige (`Config:550-590`). |
| `BlueCapPlaneEnabled` | 16 lignes | (`Config:593-629`). |
| `RedCasPlaneEnabled` | 30 lignes | (`Config:632-692`). |
| `BlueCasPlaneEnabled` | 13 lignes | (`Config:695-722`). |
| `RedSeadPlaneEnabled` | 12 lignes | (`Config:725-742`). |
| `BlueSeadPlaneEnabled` | 5 lignes | (`Config:745-756`). |
| `RedRunwayStrikePlaneEnabled` | 4 lignes | (`Config:759-767`). |
| `RedEnemyStrikePlaneEnabled` | 2 lignes | (`Config:770-773`). |
| `RedCasHeloEnabled` | 14 lignes | (`Config:776-799`). |
| `BlueCasHeloEnabled` | 11 lignes | (`Config:802-824`). |
| `RedSupplyHeloEnabled`, `BlueSupplyHeloEnabled` | 2 lignes chacune | (`Config:827-840`). |
| `PvPChanceAiAttackHelo` | `0` | Pourcentage de chances que les missions aériennes IA ciblent aussi les hélicoptères, PvP (`Config:845`). |
| `InvisibleA10` | `false` | A-10 exclu des cibles des chasseurs Red (`Config:848`). |
| `ChanceAiAttackHelo` | `0` | Même probabilité en PvE (`Config:854`). |
| `EnableHunter` | `true` | Hunter, patrouille de deux appareils après une série de kills (`Config:858`). |
| `AiPlaneSkill` | `"Random"` | Compétence des avions Red (`Config:861`). |
| `CapDifficulty`, `CasDifficulty`, `SeadDifficulty`, `RunwayStrikeDifficulty` | `"medium"` | Quelle colonne des tables d'étapes Red s'applique (`Config:866-874`). |
| `FriendlyCapSupport`, `FriendlyCasSupport`, `FriendlySeadSupport` | `"medium"` | Quelle colonne des tables d'étapes de soutien Blue s'applique (`Config:877-882`). |

Les douze tables `*Enabled` totalisent 129 noms de templates ; chaque template nommé doit exister comme groupe en late activation dans le `.miz` (« a check box cannot create a missing aircraft », `manual p.10`).

**Difficulté avancée** (`Config:885-1145`, 10 tables)

| Réglage | Forme | Signification |
|---|---|---|
| `CapLimitStages` | `easy` / `medium` / `hard`, chacun une liste de `{ player = n, amount = m }` | Quantité de CAP Red selon les joueurs comptés ; une quantité = une patrouille + un groupe d'attaque (`Config:888-927`). |
| `RedCasLimitStages`, `RedSeadLimitStages`, `RedRunwayStrikeLimitStages` | même forme | Vols Red simultanés de chaque rôle (`Config:936-1044`). |
| `BlueCapSupportStages`, `BlueCasSupportStages`, `BlueSeadSupportStages` | même forme | Soutien Blue automatique, plus important quand il y a moins de joueurs (`Config:1053-1111`). |
| `CapCountIgnoreTypes` | 7 lignes | Types d'avions non comptés comme joueurs pour l'échelle de CAP (`Config:1113-1131`). |
| `RedCasCountIgnoreTypes`, `BlueCasCountIgnoreTypes` | 3 lignes chacune | Idem pour l'échelle de CAS/SEAD/frappe de piste (`Config:1134-1145`). |

**Message of the Day** (`Config:1148-1162`, 1 table) : `MessageOfTheDay = { enabled = false, durationSec = 15, intervalSec = 1800, text = [[...]] }`.

**Indicatifs** (`Config:1164-1234`, 1 table) : `CallsignOverrides`, 17 clés de familles d'avions (chaque clé est un préfixe recherché par `applyCallsignOverrides`, `WelcomeMessage.lua:540-545`, par ex. `"F.A.18"`, `"F.16CM"`), chacune avec une à cinq familles d'indicatifs et quatre codes IFF par famille (`Config:1166-1180`).

**Escorte** (`Config:1238-1270`, 2 réglages) : `EscortTypeByPlayerType`, 16 lignes `["<DCS type>"] = { enabled, "<BLUE CAP template>", "<RED CAP template>" }` (`Config:1241-1266`), et `EscortTakeoffFromGround = true` (`Config:1270`).

**Logistique / Entrepôt** (`Config:1273-1571`, 23 réglages)

| Réglage | Défaut | Signification |
|---|---|---|
| `WarehouseLogistics` | `true` | Système d'entrepôt et de zone supplies ; `false` = supplies legacy (`Config:1279`). |
| `ZoneCaptureBuildSeconds` | `120` | Timer de capture neutre, 0 = immédiat (`Config:1284`). |
| `NormalSupplyCapacity` | `1` | Cible automatique de supplies prêts d'une zone normale, de 1 à 3 (`Config:1289`). |
| `WarehouseSupplyCapacity` | `6` | Idem pour une zone `[WH]`, de 3 à 6 (`Config:1294`). |
| `CTLDSupplyCapacity` | `1` | Supplies de départ d'un FARP CTLD (`Config:1299`). |
| `GlobalSettings.supplyDifficultyScaling` | `{[1]=1.0,[2]=1.0}` | Multiplicateur des timers de supply IA et de la production de supplies, par camp (`Config:1301-1310`). |
| `GlobalSettings.repairDifficultyScaling` | `{[1]=1,[2]=1}` | Multiplicateur du temps de réparation/construction par camp ; les temps de base sont dans le commentaire (`Config:1312-1325`). |
| `ExtraRedRepairTimeLowPlayerCountPercent` | `0` | Temps de réparation Red supplémentaire quand il y a moins de 2 joueurs CAS Blue, de 0 à 50 (`Config:1327-1332`). |
| `PlayerZoneSuppliesConsumeStock` | `true` | Un prélèvement par un joueur retire un supply prêt (`Config:1337`). |
| `UseC130LoadAndUnload` | `true` | Systèmes de cargo natifs du C-130/CH-47 suivis (`Config:1340`). |
| `SuppliesCargoTransport` | `true` | Les hélicoptères de supply IA emportent une vraie charge sling load (`Config:1344`). |
| `AIDeliveryamount` | `20` | Articles d'entrepôt ajoutés par type lors d'une livraison par hélicoptère IA (`Config:1347`). |
| `AutoFillResources` | `5` | Articles ajoutés à chaque aérodrome Blue actif toutes les 15 min, 0 = désactivé (`Config:1350`). |
| `NoAIBlueSupplies` | `false` | Arrêter les supplies IA Blue réguliers (`Config:1352-1354`). |
| `NoAIBlueCapture` | `false` | Arrêter les envois de capture automatiques Blue vers les zones neutres (`Config:1356-1359`). |
| `RadioMenuStopSupplies` | `false` | Les joueurs peuvent mettre en pause les supplies IA Blue depuis le menu (`Config:1361-1363`). |
| `AllowedToCarrySupplies` | 18 lignes | Autorisation legacy par type, ignorée quand `WarehouseLogistics` est actif (`Config:1365-1386`). |
| `WarningNoSupplies` | `true` | Avertir un avion capable de supply qui décolle à vide (`Config:1389`). |
| `ZoneSupplyTakeoffWarningTypes` | 21 lignes | Types concernés par cet avertissement (`Config:1396-1418`). |
| `StrictSmartWeaponsInventory` | `false` | Diviser par deux les réapprovisionnements des armes listées ci-dessous (`Config:1420-1422`). |
| `WarehouseWeaponCaps` | vide | La liste des ids d'armes concernées (`Config:1424-1427`). |
| `WarehouseWeaponsAllowedAtAirbases` | vide | PvE : par carte, ne stocker une arme donnée que dans des entrepôts nommés, par ex. l'AIM-54C seulement sur les porte-avions (`Config:1429-1434`). |
| `WarehouseWeaponLocationAirbases` | 10 cartes, 59 noms pour le Caucase | Catalogue du sélecteur de noms d'entrepôts (`Config:1436-1571`, Caucase `Config:1450-1466`). |

**Boutique / Récompenses** (`Config:1574-1952`, 14 réglages)

| Réglage | Défaut | Signification |
|---|---|---|
| `AllowCapAutoBuyAfterLoss`, `MaxCapAutoBuys` | `false`, `1` | Rachat automatique d'un vol de CAP perdu (`Config:1577-1584`). |
| `TurnaroundRewardPercent` | `10` | Bonus de même avion, de 0 à 50 (`Config:1586-1589`). |
| `NightRewardPercent` | `10` | Bonus de décollage de nuit, de 0 à 50 (`Config:1591-1594`). |
| `AdvanceCaptureRemainingThreshold` | `50` | Pourcentage de groupes d'upgrade ennemis restants à partir duquel Advance Capture apparaît, de 20 à 60 (`Config:1598-1602`). |
| `AvailableShopItems` | 70 lignes | Id d'article de boutique vers booléen, chaque ligne avec des conditions de visibilité sur le PvP et l'époque (`Config:1604-1767`). |
| `ShopPrices` | 48 lignes | Id d'article vers crédits, par ex. `smoke = 20`, `dynamiccap = 500`, `dynamicarco = 1000` (`Config:1771-1842`). |
| `ShopRankRequirements` | 47 lignes | Id d'article vers rang minimal (`Config:1846-1916`). |
| `RewardContribution` | 15 lignes | infantry 10, ground 10, ctldGround 10, ctldAir 20, sam 30, airplane 50, ship 200, helicopter 50, crate 100, rescue 200, enemyPilotCapture 200, structure 100, Zone upgrade 100, Zone capture 200, Warehouse delivery 150 (`Config:1918-1936`). |
| `RefuelReward` | `2` | Crédits par 100 lb reçues (`Config:1938-1939`). |
| `AIAttackTakeoffFromGround`, `AIAttackTakeoffFromGroundExtraNM` | `true`, `40` | Les vols achetés partent d'un aérodrome, avec une distance de sécurité supplémentaire (`Config:1941-1944`). |
| `AllowAdminBuy` | `true` | Marqueur `adminbuy:<id>` qui contourne le filtre de rang (`Config:1946-1948`). |
| `AllowScriptedSupplies` | `false` | Les supplies achetés sont appliqués d'un coup au lieu d'être acheminés en vol (`Config:1950-1952`). |

**CTLD** (`Config:1955-2195`, 10 réglages)

| Réglage | Défaut | Signification |
|---|---|---|
| `CTLDCost` | `true` | Les articles CTLD coûtent des crédits et exigent un rang (`Config:1958-1959`). |
| `Allow_Red_CTLD` | `false` | CTLD rouge en PvE (`Config:1961-1963`). |
| `MaxTroopsRunDistanceTowardZone` | `5000` | Mètres que parcourront en courant les troupes déposées vers une zone, de 2 000 à 15 000 (`Config:1965-1967`). |
| `CTLDCargoTrackingInterval` | `3` | Secondes entre deux vérifications de cargo, de 3 à 6 (`Config:1969-1971`). |
| `CTLDPrices` | 49 lignes | Nom d'article vers `{ available, price, reqRank }` (`Config:1973-2059`). |
| `MAX_AT_SPAWN` | 48 lignes | Nom d'article vers nombre d'exemplaires sauvegardés restaurés au redémarrage (`Config:2061-2146`). |
| `CaptureZoneWithEngineer` | `false` | Les ingénieurs comptent comme troupes de capture (`Config:2148-2150`). |
| `MAX_SAVED_FARPS` | `3` | FARP de joueurs restaurés depuis la sauvegarde (`Config:2153-2155`). |
| `IRIS_RESTORE_UNIT_HEALTH_ON_MERGE` | `false` | La fusion d'un ajout IRIS-T reconstruit à partir du template complet (`Config:2157-2161`). |
| `CTLDUnitCapabilities` | 18 lignes | Type vers `{ crates?, troops?, crate limit, troop limit, length m, max cargo kg }`, avec le commentaire « changing values will mostly have negative impact on the CTLD code » (`Config:2163-2195`). |

**CSAR** (`Config:2198-2257`, 10 réglages) : `AllowedCsar` (21 lignes, type vers nombre de sièges, 0 = pas de menu), `CsarPilotSpawnWithoutCreditsChance = 50`, `Max_CSAR_At_Once = 10`, `Max_CSAR_AT_Mission_Restart = 10`, `PilotWeight = 80`, `CsarHoverDistance = 20`, `CsarGuidanceDistance = 70`, `CsarHoverHeight = 60`, `CsarHoverSeconds = 10`, `CsarHostileInfantryChance = 25` (`Config:2205-2257`).

**Temps de vol** (`Config:2259-2303`, 4 réglages) : `RewardFlightTime = true`, `FlightTimeRewardPerMinute = 2`, `RewardAllAircraft = false`, `AllowedFlightTimeReward` (25 lignes, seuls `C-130J-30`, `CH-47Fbl1`, `Hercules` activés d'après `manual p.19`).

**Ravitailleurs** (`Config:2306-2311`, 2 réglages) : `TexacoSpeed = 286`, `ArcoSpeed = 286` nœuds, avec le commentaire que la vitesse d'orbite est codée en dur à 280.

**EWRS** (`Config:2314-2360`, 23 réglages) : `ewrs_enabled = true`, `ewrs_defaultReportStyle = 2`, `ewrs_maxRangeKm = 150`, `ewrs_maxRangeNm = 100`, `ewrs_defaultAircraftRangeLimit = 60`, `ewrs_defaultHelicopterRangeLimit = 20`, `ewrs_messageUpdateInterval = 20`, `ewrs_messageDisplayTime = 15`, `ewrs_restrictToOneReference = false`, `ewrs_defaultReference = "self"`, `ewrs_defaultMeasurements = "imperial"`, `ewrs_defaultShowTankers = false`, `ewrs_enableRedTeam = true`, `ewrs_enableBlueTeam = true`, `ewrs_disableMessageWhenNoThreats = true`, `ewrs_onDemand = false`, `ewrs_maxThreatDisplay = 5`, `ewrs_allowBogeyDope = true`, `ewrs_allowFriendlyPicture = true`, `ewrs_maxFriendlyDisplay = 3`, `ewrs_showType = true`, `ewrs_mergedRangeNm = 5`, et la table `ewrs_specialPlaneTypes` (4 lignes).

**AIEN** (`Config:2363-2382`, 9 réglages) : `AIEN.config.dontInitialize = false`, `.blueAI = true`, `.redAI = true`, `.dismount = true`, `.message_feed = true`, `.initiative = true`, et les globales `phaseCycleTimerMin = 0.2`, `phaseCycleTimerActive = 0.08`, `phaseCycleTimerIdle = 0.5`.

**Avions / Armes** (`Config:2385-3458`, 17 réglages)

| Réglage | Lignes actives (lignes commentées) | Signification |
|---|---|---|
| `PvPSeparateAircraftLists` | `false` | Une liste d'avions d'entrepôt par coalition en PvP (`Config:2388-2391`). |
| `allowedPlanesModern`, `allowedPlanesRedModern` | 18 (76), 17 (77) | Listes PvP Modern quand les listes séparées sont activées (`Config:2419-2617`). |
| `allowedPlanes` | 54 (3) | Avions d'entrepôt Blue en Coldwar/Gulfwar (`Config:2622-2680`). |
| `allowedPlanesSharedColdwarPvP`, `allowedPlanesBlueColdwarPvP` | 56 (9), 55 (3) | Listes PvP Coldwar partagée / Blue (`Config:2686-2817`). |
| `allowedPlanesRed`, `allowedPlanesRedColdwarPvP` | 53 (5), 53 (10) | Entrepôts Red/neutres en Coldwar (`Config:2822-2951`). |
| `allowedPlanesVietnam`, `allowedPlanesSharedVietnamPvP`, `allowedPlanesBlueVietnamPvP` | 16 (10), 22 (21), 16 (17) | Listes Vietnam Blue / partagée (`Config:2956-3073`). |
| `allowedPlanesRedVietnam`, `allowedPlanesRedVietnamPvP` | 6 (14), 8 (26) | Listes Vietnam Red (`Config:3078-3140`). |
| `restockAircraft` | 35 | Avions de mods réapprovisionnés quand `AllowMods` est actif et l'époque Modern (`Config:3141-3180`). |
| `restrictedWeapons` | 83 (10) | Ids d'armes DCS retirés des entrepôts Coldwar/Gulfwar, par ex. `weapons.missiles.F16V_GBU39` (`Config:3182-3279`). |
| `restrictedWeaponsVietnam` | 45 (25) | Idem pour le Vietnam (`Config:3284-3360`). |
| `ForbiddWeaponsInAllEra` | 2 (90) | Interdiction ferme dans toutes les époques (`Config:3365-3458`). |

Vingt-deux lignes de commentaire `-- @gui requiredSet=...` relient les tables de templates IA et les articles de la boutique aux types d'avions qui doivent rester dans ces listes, par ex. `F-4E-45MC` est requis tant que `dynamiccas` est achetable et que les vols décollent du sol (`Config:2393-2417`).

**Testing** (`Config:3461-3465`, 1 réglage) : `Testing = false`.

**Commandes d'administration** (`Config:3468-3514`, 2 réglages) : `AdminCommands = false`, et `AdminCommandAliases` avec 12 champs chaîne vides : `addBlueFunds`, `addRedFunds`, `addZoneItems`, `buyWithoutRank`, `createFarp`, `captureNeutralBlue`, `captureNeutralRed`, `clearZone`, `upgradeZone`, `fullyUpgradeZone`, `restartMission` (lève le flag 181), `endMission` (`Config:3477-3514`).
Le tableau du manuel en liste 11 sur 12 (`endMission` est absent de `manual p.62`).

### Ce que `Foothold Config WW2.lua` change pour la Normandie

Le fichier fait 999 lignes contre 3 530 et contient 104 réglages (76 scalaires, 28 tables) mesurés avec le même script (`ConfigWW2:1-999`).
Son chargeur ne cherche `Foothold Config WW2.lua` que dans le dossier Saves et suit 24 tables et 10 scalaires (`ConfigWW2:18-60`, `ConfigWW2:116-132`).
Sections supprimées entièrement : réglages PvP, Fréquences, Carte F10, Escorte, CTLD, Ravitailleurs, Testing ; et, dans les options de mission, `Era`, `PvP`, `StartNormal`, `AllowMods`, les réglages du porte-avions et du Tarawa (`ConfigWW2:134-192`).
Supprimés d'autres sections : toutes les listes de contrôle de templates, les tables d'étapes SEAD et la difficulté, les réglages MANTIS/MFD/nuit, les réglages d'articles d'entrepôt (`ConfigWW2:215-260`, `ConfigWW2:527-603`).
Valeurs par défaut modifiées : `SplashDamage = true` (`ConfigWW2:177`), `MaxRedGroundGroupsPerZone = 6` (`ConfigWW2:220`), `ewrs_maxFriendlyDisplay = 5` (`ConfigWW2:843`), listes d'ignorés vides (`ConfigWW2:456-463`), une boutique de 20 articles au lieu de 70 (`ConfigWW2:626-697`).
Ajoutés : `AddWeightToPlaneRed` (4 lignes) et `AddWeightToPlaneBlue` (8 lignes) (`ConfigWW2:425-445`), `ewrs_altitudeDisplayMode = "wwii"` qui rapporte Low/Medium/High au lieu d'une altitude (`ConfigWW2:813`), et les deux listes d'entrepôt `AllowedWW2Planes` et `AllowedWW2RedPlanes` de 18 types chacune (`ConfigWW2:891-935`).

## 3. Le fichier de setup par carte (`MA_Setup_CAv2.lua`, Caucase)

Le fichier de setup est le sixième script chargé (après Moose, la localisation, la Config, le moteur et EWRS, voir §4) et c'est le seul endroit où la carte existe sous forme de données.
C'est un seul chunk Lua à plat de 10 014 lignes, sans structure de module : d'abord des tables globales, puis des appels sur les objets du moteur, puis plusieurs milliers de lignes d'actions de boutique et de générateurs de missions.
Les comptes ci-dessous sont des comptes par regex sur le fichier (script `setupstats.py` dans le scratchpad) ; un appel situé dans une branche conditionnelle ou dans un callback est donc compté comme n'importe quel autre.

### Structure de haut en bas

| Lignes | Bloc | Ce qu'y écrit l'auteur de la carte |
|---|---|---|
| 1-87 | Helpers | Raccourcis de localisation, `BlueUpgradeTemplateMigration` (25 anciens noms de groupes associés aux noms actuels pour que les anciennes sauvegardes se chargent encore, `setup:20-46`), `merge`, `allExcept`, `BuildEnabledTemplateList` (`setup:73-87`). |
| 89-294 | `upgrades` | 49 listes de garnison nommées `{ blue = {...}, red = {...} }` de noms de groupes ou de statics du `.miz`. |
| 296-375 | `flavor` | Un texte localisé par zone (numéro de waypoint, rôle), environ 75 entrées. |
| 376-438 | `WaypointList` | 61 entrées `Zone = ' (n)'`, le numéro de waypoint affiché dans l'étiquette de la carte. |
| 440-485 | Mode et nom de sauvegarde | Sélection de la liste d'avions PvP, `FootholdSaveBaseName` par époque et par mode, chemin de sauvegarde sous `Missions/Saves`. |
| 487-591 | Substitutions d'époque | Tables `cwSwap` / `vnSwap` qui remplacent les noms de templates Modern par ceux de la Guerre froide ou du Vietnam, appliquées par `deepSwap` à `upgrades`. |
| 593-751 | Garnisons aléatoires | `RandomRedPool` (46 noms), `RandomBluePool` (9), `ZoneSizeExclusions`, `RandomUpgradeTemplates` (14 profils de taille), `RandomUpgradeTemplatesBlue`, profils PvP. |
| 754-762 | Objet moteur | `bc = BattleCommander:new(filepath, 10, 60)` et le chemin du fichier de rangs (`setup:754-757`). |
| 765-1002 | `zones` | 88 `ZoneCommander:new{...}` dans la table plus une zone réservée au PvP, puis des ajustements par zone selon le PvP et l'époque (`industryCores`, `pvpVictoryZones`, SAM épinglés supplémentaires). |
| 1004-1228 | Listes de templates IA | Listes par rôle de noms de templates du `.miz` (`AllCapPlaneTemplates`, `AllCasPlaneTemplates`, …) filtrées par les listes de contrôle de la Config, variantes d'époque des listes de convois, helpers d'altitude. |
| 1230-1288 | Rattachement aux aérodromes | 56 affectations `zones.<x>.airbaseName = '<DCS airbase or FARP name>'`. |
| 1290-1839 | Sorties | 56 blocs `zones.<x>:addGroups({...})` contenant 402 `DirectorCapability:new` et 7 `GroupCommander:new`. |
| 1841-2046 | `SpawnFriendlyAssets` | Le hook de changement de zone : réveille les zones cachées, ajoute des connexions à l'exécution, active les porte-avions et leur zone de navigation. |
| 2048-2064 | Enregistrement | `bc:addZone(v)` pour chaque zone, avec des assertions PvP sur les cœurs industriels. |
| 2067-2112 | `missions` | 4 missions d'escorte au sol en hélicoptère (PvE seulement). |
| 2114-2269 | Connexions | La partie statique des 135 appels `bc:addConnection` et 14 appels `bc:addHiddenConnection`. |
| 2271-2507 | Données de théâtre du Director | `TheaterInfrastructure` (9 entrées), `TheaterRegions` (vide sur le Caucase), `TheaterAreas` (9 zones avec rôles de zones). |
| 2509-2730 | Triggers de zone scriptés | La plupart des 31 appels `registerTrigger` : contre-attaques à la capture, zones désactivées quand elles sont perdues, crédits bonus. |
| 2732-2846 | Victoire | `checkMissionComplete`, remise à zéro de la sauvegarde, flag 181, menu de redémarrage. |
| 2848-2886 | Déplacements | Préfixes de noms des groupes qui patrouillent dans leur zone, et des navires qui se déplacent. |
| 2889-3883 | « DYNAMIC SHOP » | Prix par défaut et code d'action des vols achetables (CAP, CAS, bombardier…), avec leurs sélecteurs de zone. |
| 3886-4240 | Actions de boutique supply et capture | Non lu dans cette note ; décrit dans la note 05 (section 5, détail des actions de supply et de capture, `setup:3886-4052`). |
| 4241-4795 | JTAC | Objets drones JTAC par époque, zones JTAC 9-line, `CheckJtacStatus`. |
| 4796-5404 | « Zone upgrades » | Articles de boutique qui ajoutent un groupe de garnison à une zone, achats IA Red (`redMassAttackAction`, `setup:4814`), emplacements supplémentaires. |
| 5406-5500 | Tables de repli | `ShopPrices = ShopPrices or {...}` utilisé quand la Config ne l'a pas défini (valeurs de rang par défaut dans le même bloc : estimation). |
| 5501-5751 | Étagères | 76 appels `bc:addShopItem(side, id, stock, order, rank, category)` et les sept libellés de catégories. |
| 5753-5833 | Logistique et slots de missions | `supplyZones` (34 noms), `LogisticCommander:new`, `init*Missions`. |
| 5835-5993 | Chargement et post-chargement | `bc:loadFromDisk()`, nettoyage des étagères selon l'époque, fonds de départ PvP, restauration de `StartNormal` depuis la sauvegarde, désactivation des zones à usage unique, activation du porte-avions. |
| 5996-6129 | Démarrage des services | Boucle de récompenses, caches, front, persistance de l'entrepôt, navigation des porte-avions, hunter, AWACS, distances de suspension, `EventCommander`, `MissionCommander`, `DynamicHybridConfig`, les deux objets `Director`, contre-pression réactive. |
| 6131-6558 | Événements | Site de SCUD, interception d'avion cargo, interception de navire, événement bombardier, frappe aérienne. |
| 6559-9037 | Générateurs de missions | SEAD (`setup:7461`), recon (`setup:7646`), frappe d'artillerie, CAP, CAS (`setup:8378`), escorte au sol (`setup:8553`), piste (`setup:8739`) ; les lignes 6559-7458 (générateurs attack, resupply et capture) sont décrites dans la note 05, section 11. |
| 9039-9716 | Événements de frappe | Six cibles de frappe de haute valeur et sept cibles « entrepôt de SAM », chacune un `evc:addEvent` plus un `mc:trackMission`. |
| 9718-9890 | Timers | Timers de génération de missions (réarmement à 120 s ou 300 s) et `mc:init()`. |
| 9899-9936 | `airbaseStatics` | 35 FARP avec les noms de leurs statics de décor, lus par `WelcomeMessage.lua:235-261`. |
| 9938-10009 | Zone de test | Fait apparaître des templates de test dans la zone `testing` quand `Testing` est actif. |

### Comptes (Caucase)

| Élément | Compte |
|---|---|
| Zones | 89 `ZoneCommander:new` (88 dans la table `zones`, 1 zone EWR cachée réservée au PvP) |
| Zones par `facility` | 21 `airbase`, 35 `farp`, 1 `carrier`, 32 `none` |
| Zones par `size` | `small` 24, `mediumbig` 15, `smallmedium` 12, `sam` 12, `medium` 4, `bignosam` 4, `big` 1, `smallwithShorad` 1, `samspecial` 1, `redarmycamp3` 1, sans size 14 |
| Camp de départ | 76 rouges, 8 neutres, 1 bleue, 4 selon `StartNormal` |
| Listes de garnison nommées | 49 dans `upgrades` |
| Déclarations de sorties | 402 `DirectorCapability:new` + 7 `GroupCommander:new` dans 56 blocs `addGroups` |
| Sorties par `mission` | 247 supply, 86 attack, 76 patrol |
| Sorties par `MissionType` | 96 CAP, 28 CAS, 18 ARTY, 4 RUNWAYSTRIKE, 1 SEAD, 262 sans |
| Sorties par `template` | `HeloSupplyTemplate` 208, `CapPlaneTemplate` 96, `PlaneSupplyTemplate` 25, `CasHeloTemplate` 21, `SupplyConvoy` 14, `ArtilleryConvoyShort` 14, `AttackConvoy` 8, `CasPlaneTemplate` 7, `ArtilleryConvoyLong` 4, `RunwayStrikePlaneTemplate` 4, `SeadPlaneTemplate` 1, groupe `.miz` propre 7 |
| Sorties par `type` | 362 air, 47 surface |
| Sorties avec une `condition` | 23 |
| Connexions | 135 `bc:addConnection` (quelques-uns dans des callbacks d'exécution, par ex. `setup:1903`) + 14 `bc:addHiddenConnection` |
| Articles de boutique | 56 appels `bc:registerShopItem` pour 45 ids distincts ; 76 appels `bc:addShopItem` pour 54 ids distincts (49 sur l'étagère Blue, 26 sur la Red) |
| Événements | 17 `evc:addEvent` |
| Missions suivies | 44 `mc:trackMission` |
| Triggers de zone | 31 `registerTrigger` (24 `lost`, 5 `captured`, 2 `destroyed`) |
| Données du Director | 9 `TheaterAreas`, 9 `TheaterInfrastructure`, 0 `TheaterRegions` |
| Appels de localisation | 699 références `L10N` / `LTGet` / `LTFormat` |
| Branches de mode | 262 références à `pvpEnabled`, 90 tests d'époque (`Era ==`, `Era ~=`, `ColdWarTechEra`), 32 références à `StartNormal`, 63 à `CustomFlags[...]` |
| Accès directs au `.miz` | 84 `Group.getByName`, 24 `SCENERY:FindByZoneName` |

### Un extrait par type de déclaration

Les lignes longues sont coupées par `…` ; le numéro devant chaque ligne est son numéro de ligne dans `MA_Setup_CAv2.lua` ; les numéros sautés correspondent à des lignes omises.

Listes de garnison (`upgrades`) ; une entrée est un nom de groupe du `.miz`, un nom de static, ou `{ n = name, p = true }` pour une entrée épinglée (sens des champs dans `01-zones-capture-map.md`) :

```lua
89:  upgrades = {
90:  	redships = {
91:  		blue = {},
92:  		red = {'Molniya', 'Molniya', 'Rezky', 'Grisha', 'Molniya', 'Grisha', 'SpeedBoats', 'SpeedBoats','SpeedBoats'}
93:  	},
94:  	airfield1 = {
95:  		blue = {'blueInfantry', 'Blue Armor Modern', 'Blue SAM NASAMS'},
96:  		red = {'Enemy ground forces', 'Red SAM AAA', 'Red SAM AAA 2', 'Red Armour Group 2', 'Red Armour Group 3', 'Red SAM SHORAD SA-8', …}
97:  	},
98:  	Soganlug = {
99:  		blue = {'blueInfantry', 'Blue Armor Modern', { n = 'Blue SAM NASAMS', p = true }},
100: 		red = {'Red SAM AAA', 'Red SAM SHORAD SA-15'}
101: 	},
```

Profils de garnison aléatoire (une ligne par taille de zone ; `{a,b}` est une plage, `total` le nombre de groupes) :

```lua
698: RandomUpgradeTemplates = {
699: 	small = { sam = 0, shorad = {0,2}, aaa = {0,2}, ground = {0,3}, armor = {0,2}, arty = {0,2}, total = {4,6}, flakChance = 10, … },
702: 	medium = { sam = {0,1}, shorad = {0,3}, aaa = {0,3}, ground = {0,3}, armor = {0,3}, arty = {0,3}, total = {4,9}, flakChance = 20, … },
706: 	extrabig = { sam = {1,2}, shorad = {0,5}, aaa = {0,4}, ground = {0,4}, armor = {0,4}, arty = {0,4}, total = {7,12}, flakChance = 60, … },
710: 	redarmycamp = { sam = 0, shorad = 0, aaa = 0, ground = {3,5}, armor = 0, arty = {0,5}, total = {6,8} },
```

Déclarations de zones :

```lua
765: zones = {
766: 	redcarrier = ZoneCommander:new({facility='carrier', isHeloSpawn=Era ~= 'Vietnam' and true or nil, zone='Red Carrier', side=1, level=25, upgrades=upgrades.redships, crates={}, flavorText=flavor.redcarrier}),
768: 	batumi = ZoneCommander:new({facility='airbase', isPlaneSpawn=true, isHeloSpawn=true, zone='Batumi', side=1, size='big', level=25, upgrades=upgrades.airfield1, crates={}, flavorText=flavor.batumi}),
771: 	kutaisi = ZoneCommander:new({facility='airbase', isPlaneSpawn=true, isHeloSpawn=true, zone='Kutaisi', side=1, size='medium', level=25, upgrades=upgrades.airfield4Kutaisi, crates={}, flavorText=flavor.kutaisi, income=0.1}),
773: 	gudauta = ZoneCommander:new({facility='airbase', isHeloSpawn=true, zone='Gudauta', side=1, size='mediumbig', level=25, upgrades=upgrades.airfield2, crates={}, flavorText=flavor.gudauta}),
777: 	anapa = ZoneCommander:new({facility='airbase', isPlaneSpawn=true, isHeloSpawn=true, zone='Anapa', side=StartNormal and 2 or 1, size=StartNormal and 'bignosam' or 'mediumbig', level=25, upgrades=upgrades.Anapa, …}),
852: 	hidden1 = ZoneCommander:new({facility='none', zone='Hidden1', side=1, level=25, upgrades=upgrades.Hidden1Group, crates={}, flavorText=flavor.hidden1,NeutralAtStart=true}),
863: 	zones.blueEwr = ZoneCommander:new({facility='none', zone='HiddenBlueEWR', side=2, level=10,
864: 		upgrades={blue={'Blue EWR Fixed Pvp', 'Blue EWR Fixed Pvp-1', …}, red={}},
865: 		crates={}, isHidden=true})
```

Rattachement aux aérodromes (le nom de l'aérodrome DCS ou du static FARP que possède la zone) :

```lua
1231: zones.batumi.airbaseName = 'Batumi'
1234: zones.maykop.airbaseName = 'Maykop-Khanskaya'
1235: zones.anapa.airbaseName = 'Anapa-Vityazevo'
1254: zones.lima.airbaseName = 'Lima'
```

Déclarations de sorties (`DirectorCapability` ; champs dans `03-ai-groups-sorties.md` et `04-director.md`) :

```lua
1290: zones.kobuleti:addGroups({
1291: 	DirectorCapability:new({name='Support-SAM-India', mission='supply', targetzone='SAM-India',template='SupplyConvoy', type='surface', condition = function(self) return not (self.side == 1 and CustomFlags["SamAlphaWarehouse"])end}),
1292: 	DirectorCapability:new({name='Kobuleti-supply-Senaki', mission='supply',template='HeloSupplyTemplate', targetzone='Senaki'}),
1293: 	DirectorCapability:new({name='Kobuleti-supply-Batumi', mission='supply',template='HeloSupplyTemplate', targetzone='Batumi'}),
1294: 	DirectorCapability:new({name='Kobuleti-patrol-Batumi-Cap', mission='patrol',template='CapPlaneTemplate',MissionType='CAP', targetzone='Batumi', Altitude = CapAltitude()}),
1295: 	DirectorCapability:new({name='Kobuleti-attack-Kutaisi-Cap', mission='attack',template='CapPlaneTemplate',MissionType='CAP', targetzone='Kutaisi', Altitude = CapAltitude()}),
1296: 	DirectorCapability:new({name='Kobuleti-patrol-Kutaisi-Cap', mission='patrol',template='CapPlaneTemplate',MissionType='CAP', targetzone='Kutaisi', Altitude = CapAltitude()}),
1298: })
1365: 	DirectorCapability:new({name='Gudauta-attack-Sukhumi', mission='attack',template='AttackConvoy', targetzone='Sukhumi', type='surface'}),
1366: 	GroupCommander:new({name='Gudauta-attack-Sukhumi-Arty', mission='attack', targetzone='Sukhumi', type='surface', FixedArty = true, SetActiveMission = true}),
```

Connexions (signature `addConnection(f, t, drawBoth, preserveDirection)` à `zc2:27025` ; les connexions cachées à `zc2:27033`) :

```lua
2114: bc:addConnection("Batumi","Kobuleti")
2115: bc:addConnection("Kobuleti","SAM-India")
2116: bc:addConnection("Kobuleti","Senaki")
2118: bc:addConnection("Senaki","Kutaisi")
2119: bc:addConnection("Kutaisi","India")
2120: bc:addConnection("India","Sukhumi")
2121: bc:addConnection("India","InsurgentCamp",nil,true)
2122: bc:addConnection("Sukhumi","SAM-Foxtrot",nil,true)
2246: bc:addConnection("Sachhere","Kvomo",true)
2252: bc:addHiddenConnection("Nalchik","Beslan")
2253: bc:addHiddenConnection("Mineralnye","Maykop")
```

Données de théâtre du Director (infrastructure reliant un bâtiment destructible à une route de supply ; zones avec un rôle par zone) :

```lua
2271: TheaterInfrastructure = {
2272: 	{
2273: 		id = "kobuleti_sam_india_warehouse",
2274: 		flag = "SamAlphaWarehouse",
2275: 		effect = "defence_supply",
2276: 		side = coalition.side.RED,
2277: 		scope = "routes",
2278: 		sourceZone = "Kobuleti",
2279: 		targetZones = { "SAM-India" },
2280: 	},
2365: TheaterAreas = {
2366: 	{
2367: 		id = "western_georgia",
2368: 		kind = "air_network",
2369: 		name = "Western Georgia",
2370: 		zones = {
2371: 			{ name = "Batumi", role = "hub" },
2372: 			{ name = "MiningFacility", role = "resource" },
2374: 			{ name = "SAM-India", role = "defence" },
2379: 			{ name = "India", role = "gateway" },
```

Enregistrement des articles de boutique (l'article et son action, `zc2:19322`) et mise en étagère (camp, id, stock où -1 signifie illimité, ordre dans le menu, rang, catégorie, `zc2:19341`) :

```lua
3053:     bc:registerShopItem('dynamiccap', LTGet("SYRIA_SHOP_ITEM_CAP_FLIGHT"), ShopPrices.dynamiccap, capAction, capAltAction, nil, 'CAP', { [1]=redRow, [2]=blueRow })
3055:     bc:registerShopItem('dynamiccap', LTGet("SYRIA_SHOP_ITEM_CAP_FLIGHT"), ShopPrices.dynamiccap, capAction, capAltAction)
3057: bc.shopItems['dynamiccap'].groupZoneSelector = {
3058: 	targetzoneside = 2,
3059: 	includeSuspended = false,
3060: 	sortPolicy = 'friendly_frontline',
5501: -- first value below is how much in stock, the second number value is the ranking in the shop menu list, the third is the new ranking system.
5509: bc:addShopItem(1, 'redwarehouse', -1, 3, ShopRankRequirements.redwarehouse) -- red AI rear supply depot
5537: bc:addShopItem(2, 'dynamiccap', -1, 1, ShopRankRequirements.dynamiccap, ShopCats.AIAttack) -- CAP Flight
5538: if GlobalSettings.pvpEnabled == true then bc:addShopItem(1, 'dynamiccap', -1, 1, ShopRankRequirements.dynamiccap, ShopCats.AIAttack) end
5743: bc:addShopItem(2, 'dynamicarco', 1, 1, ShopRankRequirements.dynamicarco, ShopCats.OtherSupport) -- Navy tanker
5749: bc:addShopItem(2, 'farphere', -1, 3, ShopRankRequirements.farphere, ShopCats.OtherSupport) -- deploy FARP
```

Missions de type « escorte au sol » (un groupe de convoi du `.miz`, une zone de départ, une zone cible, un user flag, une zone cachée à activer) :

```lua
2067: missions = GlobalSettings.pvpEnabled ~= true and {
2068:         ["Sochi"] = {
2069:         zone = "Sochi",
2070:         missionGroup = "SochiEscortGroup",
2071:         menuTitle = LTFormat("CA_MISSION_GROUND_ESCORT_TITLE", "Sochi"),
2072:         missionTitle = LTFormat("CA_MISSION_GROUND_ESCORT_TITLE", "Sochi"),
2073:         TargetZone = "Delta",
2074:         radius = 2500,
2075:         MissionType = "Escort",
2076:         flag = 001,
2077: 		ActivateZone = "hidden"
2078:     },
```

Un événement et sa mission suivie (ici une frappe sur un bâtiment de la carte trouvé grâce à une trigger zone qui porte l'id de l'objet de décor) :

```lua
9339: evc:addEvent({
9340: 	id = 'SamDeltaWarehouse',
9341: 	StrikeMission = true,
9342: 	action = function()
9343: 		local tgt = sceneryList['SamDeltaWarehouse'][1] or SCENERY:FindByZoneName('SamDeltaWarehouse')
9348: 		RegisterScoreTarget('SamDeltaWarehouse',tgt,500,L10N:Get("MISSION_STRIKE_DEFAULT_TITLE"),true)
9352: 			trigger.action.markToCoalition(missionMarkId,L10N:Get("CA_MISSION_STRIKE_SAM_DELTA_WAREHOUSE_TITLE"),p,2,false,false)
9356: 	canExecute = function()
9357: 	if ActiveMission['SamDeltaWarehouse'] then return false end
9358: 	if CustomFlags["SamDeltaWarehouse"] then return false end
9359: 	local sukhumi = bc:getZoneByName('Sukhumi')
9360: 	if sukhumi.side ~= 1 or (sukhumi.suspended and not sukhumi._idleSuspended) then return false end
9363: 	if bc:getZoneByName('India').side ~= 2 and bc:getZoneByName('Sochi').side ~= 2 then return false end
9368: mc:trackMission({
9369: 	title = LTGet("CA_MISSION_STRIKE_SAM_DELTA_WAREHOUSE_TITLE"),
9371: 	messageStart = L10N:Get("CA_MISSION_STRIKE_SAM_DELTA_WAREHOUSE_START"),
9384: 	isActive = function()
9385: 		if CustomFlags["SamDeltaWarehouse"] then return false end
```

Porte-avions (activation des groupes et zones de navigation des porte-avions, qui sont des trigger zones nommées `CVN72_AREA_*`) :

```lua
5985: if carriersShouldBeActive then
5986: 	activateGroupIfNotActive('CVN-72')
5987: 	activateGroupIfNotActive('CVN-74')
5988: 	activateGroupIfNotActive('Tarawa')
6014: if Era ~= 'Vietnam' then
6015: 	bc:enableCarrierNavigation()
6018: 			bc:deployCarrierNavigationArea("CVN72_AREA_BATUMI")
6022: 			bc:deployCarrierNavigationArea("CVN72_AREA_NOVOROSSIYSK",true)
6025: 	bc:addCarrierNavigationSuspendConnection("CVN72_AREA_BATUMI", "Batumi", true)
6026: 	bc:addCarrierNavigationSuspendConnection("CVN72_AREA_SOCHI", "Sochi", true)
6034: 	bc:addCarrierNavigationSuspendConnection("CVN72_AREA_NOVOROSSIYSK", "Anapa", true)
```

Cas particuliers (une réaction scriptée enregistrée sur une zone, `registerTrigger(eventType, action, id, timesToRun, options)` à `zc2:50064` ; et une zone cachée réveillée avec une nouvelle connexion quand un voisin est capturé) :

```lua
2701: zones.tankfactory:registerTrigger('lost', function(event, sender)
2702: 	if GlobalSettings.pvpEnabled == true then return end
2703: 	sender:disableZone(true)
2704: 	bc:addFunds(2,500)
2705: 	trigger.action.outTextForCoalition(2,L10N:Get("CA_SETUP_TANK_FACTORY_DESTROYED"),20)
2706: end, 'disabletankfactory', nil, {disablesZone = true})
1896: 	if not zones.insurgencygriddl22.isAwaken and zones.krymsk.side == 2 and not insurgencydl22campStarted then
1900: 		zones.insurgencygriddl22:AwakenZoneAndUpgrade()
1903: 		bc:addConnection("Krymsk", "Insurgency Grid DL22")
1904: 		bc:buildConnectionMap()
```

Branches d'époque et de PvP (le nom de sauvegarde, qui décide quel fichier de campagne est lu, et la table de substitution d'époque) :

```lua
467: if Era == 'Vietnam' then
468: 	FootholdSaveBaseName = 'FootHold_CA_v0.3_Vietnam'
469: elseif Era == 'Coldwar' then
470: 	FootholdSaveBaseName = 'FootHold_CA_v0.3_Coldwar'
471: else
472: 	FootholdSaveBaseName = 'FootHold_CA_v0.3'
473: end
475: if GlobalSettings.pvpEnabled then
476: 	FootholdSaveBaseName = FootholdSaveBaseName .. 'Pvp'
477: end
487: local cwSwap = {
488: 	['Blue SAM NASAMS'] = 'Blue SAM HAWK',
490: 	['Red Armour Group 4']   						= 'Red Armor Group8',
```

### Ordre de démarrage dans le fichier de setup

L'ordre des appels fait partie de ce que reproduit un auteur de carte : les zones sont créées (`setup:765`), les sorties rattachées (`setup:1290`), les zones enregistrées (`setup:2063`), les connexions déclarées (`setup:2114`), les articles de boutique enregistrés et mis en étagère (`setup:3053`, `setup:5504`), puis `lc:init()` et `bc:loadFromDisk()` (`setup:5833-5835`), puis les caches et les services (`setup:6000-6013`), les commandants d'événements et de missions (`setup:6073-6075`), les deux Directors (`setup:6120-6123`), et enfin les générateurs de missions et `mc:init()` (`setup:9890`).
Les constantes de réglage propres à la carte sont posées dans la même passe : distances de suspension `autoSuspendNmBlue = 70` et `autoSuspendNmRed = 95` en PvE, 100 et 100 avec `proximityWakeNm = 50` en PvP (`setup:6062-6070`), paramètres d'orbite de l'AWACS (`setup:6053-6060`), `DynamicHybridConfig` avec des limites de distance et 22 surcharges par zone (`setup:6077-6118`), périodes de `EventCommander` (`setup:6073`).

### Socle commun contre contenu propre à chaque carte (comparaison avec `kola_setup.lua`)

`kola_setup.lua` fait 6 867 lignes avec le même squelette : `upgrades` (`kola:93-259`), `WaypointList` (`kola:627-685`), `flavor` (`kola:687-742`), nom de sauvegarde (`kola:745`), `zones` (`kola:842-939`), `TheaterInfrastructure`, `TheaterRegions` et `TheaterAreas` (`kola:1983-2335`), `supplyZones` (`kola:2338-2387`), `airbaseStatics` (`kola:6834-6867`).
Mesuré sur les lignes non vides à espaces normalisés, 62 % des lignes de Kola (3 450 sur 5 605) existent aussi à l'identique dans le fichier du Caucase.
La même mesure pour les autres fichiers de setup contre le Caucase donne Irak 74 %, Sinaï nord 74 %, golfe Persique 72 %, Afghanistan 69 %, Sinaï étendu 69 %, Syrie 69 %, Allemagne Guerre froide 65 %, Atlantique Sud 62 %, Normandie 35 %.
Par tranche de 500 lignes du fichier du Caucase, la part de lignes aussi présentes dans Kola est de 2 % pour les lignes 1501-2000 et de 10 % pour les lignes 2001-2500 (sorties, connexions, données de théâtre), de 60 à 77 % pour les lignes 3001-5500 (actions de boutique et articles de zone upgrade), et de 27 à 59 % ailleurs.
Le code des actions de boutique, le code JTAC et des générateurs de missions et le démarrage des services sont donc copiés d'une carte à l'autre avec de petites modifications, tandis que les données propres à chaque carte se concentrent sur environ 2 500 lignes : listes de garnison, zones, rattachement aux aérodromes, sorties, connexions, zones de théâtre, triggers scriptés, cibles de frappe et statics de FARP.
Il n'y a pas de fichier d'inclusion partagé : le code copié vit dans chacun des onze fichiers de setup.

Comptes de Kola pour comparaison (même script) : 81 `ZoneCommander:new`, 315 `DirectorCapability:new` + 5 `GroupCommander:new` dans 55 blocs, 91 connexions + 3 cachées, 45 `registerShopItem`, 52 `addShopItem`, 18 événements, 31 missions suivies, 3 `registerTrigger`, 16 `TheaterRegions`, 7 `TheaterAreas`.
Différences propres à la carte observées dans Kola : pas de PvP (2 références à `pvpEnabled` contre 262) et pas de `StartNormal` ; le camp de départ de pays entiers est une variable (`sideSE`, `sideNO`, `sideFIN`, `sideFIN_SE`) posée à partir de flags sauvegardés, ce qui donne plusieurs dispositions de campagne (`kola:756-820`) ; un flag `DynCampaign` change le nom de sauvegarde (`kola:745`) ; ses propres profils de taille (`mediumsam`, `bigsam`, `armor4`…) ; des `TheaterRegions` multi-zones (`kola:2002-2208`).

## 4. Les conventions du `.miz` (mission du Caucase)

Source : `Missions/Foothold_CA_6.5.2_Coldwar-Modern-Vietnam.miz`, déjà extrait par une note sœur dans le dossier scratchpad `miz-ca-02` ; les fichiers `mission`, `options`, `warehouses`, `dictionary` et `mapResource` ont été analysés avec un petit analyseur de tables Lua en Python (scripts `miz1.py`, `miz2.py`, `miz3.py`, gardés hors du dossier extrait et exécutés avec `python -I`).
Chaque nombre de cette section est mesuré sur les tables analysées.
L'archive contient `mission` (8,2 Mo), `warehouses` (12,2 Mo), `options`, `theatre`, `KNEEBOARD/IMAGES/Freq.png` et `l10n/DEFAULT` avec 70 fichiers : 12 scripts Lua, 54 `.ogg`, 1 `.wav`, 1 `.jpg`, `dictionary` et `mapResource`.

### Triggers et ordre de chargement des scripts

La mission a 7 règles de trigger (table `trigrules` de `mission`, avec les conditions et les actions dans `trig`).

| # | Nom | Type | Condition | Actions |
|---|---|---|---|---|
| 1 | Remove Trees | start | aucune | 12 `a_remove_scene_objects` sur des ids de trigger zones, masques 0 ou 1 (ids non résolus en noms de zones) |
| 2 | ScriptLoader 1 | start | aucune | `Moose_2026-10-11.lua`, `Foothold_Localization.lua`, `Foothold Config.lua` |
| 3 | ScriptLoader 2 | start | aucune | `zoneCommanderv2.lua`, `EWRS.lua`, `MA_Setup_CAv2.lua`, `WelcomeMessage.lua` |
| 4 | ScriptLoader 3 | once | `c_time_after(3)` | `Zeus.lua`, `Foothold CTLD.lua`, `Foothold_CTLD_Red.lua`, `Splash_Damage_3.4.1_leka.lua` |
| 5 | AIEN | once | `c_time_after(12)` | `AIEN.lua` |
| 6 | Sounds | once | aucune | 54 `a_out_sound_g` vers le group id 41, un par fichier son |
| 7 | END GAME | once | `c_flag_is_true("181")` | `a_end_mission("blue", "", 0)` |

La règle « Sounds » joue chaque fichier son vers un seul groupe ; son but apparent est de faire garder les fichiers son dans l'archive par le Mission Editor, puisque les scripts les jouent par nom de fichier avec `trigger.action.outSoundForCoalition` (par ex. `setup:1902`) (estimation sur le but).
Le flag 181 est le seul lien des scripts vers les triggers de la mission (`setup:2811`, `Config:3508`).
Le flag 180 est lu par le fichier de setup pour couper les sons de mission (`setup:6202`) ; l'endroit où il est posé n'a pas été cherché.
L'ordre de chargement et ses conséquences sont détaillés dans `02-persistence-lifecycle-plumbing.md`.

### Trigger zones

Il y a 1 331 trigger zones : 1 240 cercles et 91 quadrilatères.
Treize zones portent des propriétés du Mission Editor (`OBJECT ID`, `NAME`, `ROLE`, `VALUE`) : ce sont les zones liées à un bâtiment de la carte, utilisées pour les cibles de frappe (`StrikeTarget`, `StrikeTarget1`, `StrikeTarget2`, `StrikeVaziani`, `LefttHandMan`, `RightHandMan`, et les sept `Sam<X>Warehouse`).
Aucune zone ne porte d'autre propriété : toute la signification pour le moteur est portée par le nom de la zone.

| Convention | Nombre | Exemple | Recherchée par |
|---|---|---|---|
| `<Zone>` (nom simple) | 120 | `Batumi`, `SAM-Alpha`, `Hidden4`, `TankFactory` | `zone='Batumi'` dans `ZoneCommander:new` (`setup:768`) ; la table des zones de la mission est indexée par nom dans `buildZoneByName` (`zc2:203-207`). |
| `<Zone>-N` | 717 | `Kutaisi-1` … `Kutaisi-15` | Sous-zones de spawn, énumérées à partir de 1 jusqu'à ce qu'un numéro manque (`zc2:27236-27244`, `zc2:10676-10680`) ; le parent est retrouvé en retirant `-%d+$` (`zc2:5778-5781`). |
| `<Zone>-sam-N` | 60 | `Kutaisi-sam-0` | Sous-zones réservées aux sites SAM, reconnues par le préfixe en minuscules `<zone>-sam-` (`zc2:4725-4734`). |
| `<Zone>-land`, `<Zone>-land-N` | 107 | `Batumi-land-0` | Points d'atterrissage d'hélicoptère d'une zone (`zc2:610`, `zc2:652`, `zc2:58355`, `zc2:66757`, `zc2:99457`). |
| `<Zone>-land-forced-N` | 2 | `Gelendzhik-land-forced-0` | Points d'atterrissage prioritaires (`zc2:273`, `zc2:633`). |
| `<Zone>-road`, `<Zone>-road-N` | 23 | `Anapa-road-0` | Points d'accroche routiers pour les convois (`zc2:10989-10994`). |
| `<Zone>-wh` | 35 | `Alpha-wh` | Indication de position du bâtiment d'entrepôt du centre logistique (`zc2:46249-46268`). |
| `<A>-<B>-Supply-N` | 87 | `Guso-Digora-Supply-1` | Waypoints ordonnés d'un couloir de supply par hélicoptère entre deux zones, utilisable dans les deux sens (`zc2:209-216`, `zc2:58128-58138`). |
| `<A>-<B>-Supply-Landing`, `<A>-<B>-Landing` | 8 | `India-Revari-Supply-Landing` | Point d'atterrissage de ce couloir (`zc2:58148-58156`) ; les noms sans `-Supply` (par ex. `Hurzuk-Tyra-Landing`) ne correspondent pas à cette recherche et aucune autre recherche n'a été trouvée dans `zoneCommanderv2.lua`. |
| `Arty-<A>-<B>`, `Arty-<A>-<B>-N` | 24 | `Arty-Krymsk-Alpha-0` | Positions de tir des sorties d'artillerie de A contre B, avec un repli legacy `Arty-<B>` (`zc2:10354-10361`). |
| `Scoot-N`, `Scoot-<x>` | 78 + 9 | `Scoot-12` | Zones de déplacement du shoot-and-scoot de MANTIS, prises par le préfixe `Scoot` (`zc2:111454-111455`, `zc2:111490`). |
| `CVN72_AREA_<X>` | 6 quadrilatères | `CVN72_AREA_SOCHI` | Zones de navigation des porte-avions (`zc2:13876-13880`, `setup:6018-6034`). |
| `CVN72_AREA_<X>-N` | 36 | `CVN72_AREA_BATUMI-1` | Points à l'intérieur d'une zone, `-1` et `-2` étant lus en premier (`zc2:13879-13880`). |
| `<Area>-N-Edge` | 28 | `Red Carrier-3-Edge` | Points de bord d'une zone maritime, reconnus par `^%d+%-edge$` après le nom de base (`zc2:1445-1462`) ; deux zones sont orthographiées `-2-Ed-ge` et `-4-E-dge` et ne correspondent donc pas. |
| `Hidden`, `HiddenN`, `HiddenN-M` | 10 + 68 | `Hidden4-12` | Zones et sous-zones ordinaires ; leur zone est déclarée `NeutralAtStart` ou `isHidden` dans le setup (`setup:852-865`). |
| Quadrilatères liés à un décor | 13 | `SamDeltaWarehouse` | `SCENERY:FindByZoneName` dans le setup (`setup:9343`). |
| `Trees-<Zone>`, `Tree-Mezmay` | 6 | `Trees-Guso` | Aucune recherche par script trouvée ; vraisemblablement le trigger de mission « Remove Trees » (estimation). |
| `testing`, `testing air` | 2 | | Zone de spawn de test (`setup:9940`). |

Parmi les 1 006 zones dont le nom se termine par un nombre (zones de couloir et de porte-avions exclues), 917 ont un rayon inférieur à 200 m (443 sous 50 m, 141 entre 50 et 100 m, 118 entre 100 et 150 m, 215 entre 150 et 200 m), c'est-à-dire que chacune est un emplacement pour un groupe.
Les 89 zones de campagne coûtent donc environ 1 100 zones auxiliaires placées à la main.

### Groupes

La mission contient 880 groupes et 1 851 unités : 542 groupes non statiques (206 avions, 40 hélicoptères, 283 terrestres, 13 navires) et 338 statics.
Sur les 542 groupes non statiques, 508 sont en late activation ; les 34 autres sont les slots clients.
Aucun groupe n'est marqué `uncontrolled`.
Par coalition : rouge 626 groupes (Russie 445, CJTF Red 181), bleu 216 (USA 158, CJTF Blue 54, Allemagne 4), neutre 38 statics.
Chaque groupe IA est donc un template que les scripts copient ; rien n'est vivant au démarrage de la mission, sauf ce que les scripts font apparaître.

| Famille (nom de groupe) | Nombre | Camp | Utilisée par |
|---|---|---|---|
| `RED_<TYPE>_<ROLE>_<LOADOUT>[_nSHIP]` | 92 | rouge | Templates de vols IA ; les noms sont les clés des listes de contrôle de la Config (`Config:553-840`) et des listes du setup (`setup:1042-1220`) ; choisis par l'ensemble `template` d'une sortie (`zc2:60474-60490`). |
| `BLUE_<TYPE>_<ROLE>_<LOADOUT>[_nSHIP]` | 49 | bleu | Idem pour le soutien Blue et les vols achetés. |
| `CAP_Template`, `DynamicCas_Template`, `DynamicSead_Template`, `DynamicBomber_Template`, `DynamicDecoy_Template`, `DynamicStructure_Template`, chacun avec des variantes `_CW` et `_VT`, et les jumeaux `RED_*` | environ 30 | les deux | Vols achetés (`zc2:105244`, `zc2:107935`, `zc2:108217`, `zc2:108673`, `zc2:109335`, `zc2:109698`, `zc2:110205-110213` ; jumeaux PvP `setup:3049`). |
| `Red SAM …`, `Red SAM SHORAD …`, `Red SAM AAA n`, `Red Armour Group n`, `Red Mech group n`, `Red Arty n`, `Enemy ground forces`, `… Vietnam n` | environ 90 | rouge | Templates de garnison nommés dans `upgrades` et `RandomRedPool` (`setup:89-294`, `setup:594-651`) ; MANTIS prend ses SAM par le préfixe `Red SAM` et ses radars par `Red EWR` (`zc2:111399`). |
| noms contenant `Fixed` (`Red EWR Fixed 1`, `hiddenground-Fixed-n`, `Blue EWR Fixed Pvp-n`) | environ 40 | les deux | Un nom contenant `Fixed` prend la branche de `CustomZone:spawnGroup` qui utilise le template propre du groupe dans le Mission Editor au lieu d'un placement en sous-zone (`zc2:5220-5234`) ; `hidden` + `fixed` est une autre classe (`zc2:1011-1015`). |
| `Blue SAM HAWK`, `Blue SAM NASAMS`, `Blue Armor Modern`, `blueInfantry`, … | environ 15 | bleu | Templates de garnison Blue (`setup:95`, `setup:668-678`). |
| `AttackConvoy n`, `AttackConvoy CW n`, `SupplyConvoy n`, `ArtilleryConvoyShort n`, `ArtilleryConvoyLong n`, `GroundAttackConvoy n`, `InsurgentConvoy n` | environ 25 | les deux | Templates de sorties de surface (`setup:1004-1040`). |
| `<Origin>-attack-<Target>-Arty` | 9 | rouge | Groupes d'artillerie fixes référencés par nom dans `GroupCommander:new` (`setup:1366`). |
| `CTLD_CARGO_*`, `CTLD_TROOPS_*`, `CTLD_CARGO_RED_*` | environ 45 | les deux | Templates de cargo CTLD (`Foothold CTLD.lua:264-270`). |
| `evt-*`, `RedBomberEvent`, `EscortBomber`, `Maykop-Scuds`, `Kutaisi-Sead-Attack…`, `interceptor-n` | environ 25 | rouge | Groupes d'événements recherchés par nom littéral dans le setup (`setup:6214`, `setup:6225-6249`, `setup:2515-2529`). |
| `<Zone>EscortGroup` | 4 | bleu | Convois d'escorte au sol (`setup:2070`). |
| `AWACS_RED`, `AWACS_BLUE`, `AWACS_BLUE_SECONDARY`, `…_VT`, `Arco`, `Texaco`, `Shell`, `jtacDrone1/2`, `JTAC9lineam/fm`, `Escort1_Hornet` … | environ 25 | les deux | Avions de soutien par nom littéral (`zc2:9332-9335`, `zc2:13660`, `setup:4242-4244`). |
| `CVN-72`, `CVN-74`, `Tarawa` ; `Molniya`, `Rezky`, `Grisha`, `Moskva`, `SpeedBoats`, `MissileBoat`, `FacLa`, `evt-shiptercept n` | 13 | les deux | Porte-avions activés par nom (`setup:5986-5988`), navires rouges comme garnison de la zone du porte-avions (`setup:92`) et préfixes de déplacement (`setup:2878-2885`). |
| `CSAR_RED_INF_1/2` | 2 | rouge | Infanterie hostile près d'un pilote abattu (`zc2:97724`). |
| `Testing …` | 17 | rouge | Zone de test (`setup:9941-9945`). |

Les comptes « environ » viennent d'un regroupement des noms par famille dans la sortie du script, pas d'un motif exact par ligne.

### Objets statiques

Il y a 338 groupes de statics : 254 fortifications rouges et 38 neutres, 35 héliports rouges, 5 statics rouges de la catégorie entrepôts, 4 hélicoptères statiques rouges, et 2 bleus (dont un `Zone supplies UH-1H`, un cargo).
Les 35 héliports sont les zones de FARP : 20 de type `FARP` et 15 `SINGLE_HELIPAD`, chacun nommé exactement comme sa zone (`Alpha`, `Hady`, …), ce que désigne `zones.<x>.airbaseName` (`setup:1254-1288`).
Autour d'eux, `FARP Tent` (98), `Windsock` (73), `FARP Fuel Depot` (35) et `FARP Ammo Dump Coating` (35) sont nommés `Farp<zone>ammo`, `Farp<zone>fuel`, `Farp<zone>tent1..4`, `Farp<zone>command`, `Farp<zone>wind` et listés par zone dans `airbaseStatics` (`setup:9899-9936`).
Les autres statics nommés sont des objectifs destructibles placés dans des listes de garnison ou des zones industrielles : `Mineralnye HQ`, `Kobuleti Fuel Tank`, `Communication Tower`, `Tank Factory`, `MiningFacility Factory`, `SecretTechFacility HQ`, `Ammunition Storage n`, `InsurgentCamp` (`setup:102-109`, `setup:869-870`).

### Slots clients et spawn dynamique

Les 34 groupes clients sont tous du côté Blue et portent tous `dynSpawnTemplate = true` : un groupe par type ou variante d'avion (25 avions, 9 hélicoptères), y compris des types de fabrication rouge (`MiG-29S`, `Su-25T`, `Su-27`, `Su-33`, `MiG-29 Fulcrum`, `JF-17`, `Mi-8MT`, `Mi-24P`, `Ka-50_3`).
Il n'y a pas de slot fixe par aérodrome : les joueurs apparaissent par le spawn dynamique de DCS, et ces groupes servent de templates par type.
La coalition Red n'a aucun groupe client dans ce fichier.
Dans le fichier `warehouses`, les 21 aéroports ont tous `dynamicSpawn = true`, `dynamicCargo = true`, `allowHotStart = true`, `unlimitedAircrafts = false`, `unlimitedMunitions = false`, `unlimitedFuel = true` ; 19 sont Red et 2 Blue au départ.
Sur les 46 entrepôts hors aéroports (FARP, navires et statics d'entrepôt), 38 ont le spawn dynamique activé avec les mêmes réglages de stock limité, 5 sont illimités avec le spawn dynamique désactivé, et 3 sont des cas particuliers.
Un entrepôt liste 146 types d'avions et 28 types d'hélicoptères avec `initialAmount = 10000`, et 800 entrées d'armes dont 786 à 10 000, 9 à 100 et 5 à 0 (lu sur le premier aéroport et le premier entrepôt seulement).
Un stock « limited » avec de très grandes quantités est donc la convention d'écriture, et le manuel interdit « unlimited » pour une mission Guerre froide parce que les listes d'époque ne s'appliqueraient sinon pas (`manual p.5-6`).
La zone où un joueur peut apparaître est décidée à l'exécution d'après la possession des zones ; voir « Spawn handling and slot control » dans `02-persistence-lifecycle-plumbing.md`.

### Options qui comptent

`requiredModules` est vide : la mission ne déclare aucun mod.
`forcedOptions` (imposées aux clients) : `userMarks = true` (les commandes de marqueur en dépendent), `externalViews = true`, `labels = 0`, `optionsView = "optview_allies"`, `easyCommunication = false`, `radio = false`, `unrestrictedSATNAV = true`, `permitCrash = false`, `wakeTurbulence = false`, `birds = 0`, `civTraffic = ""`, `padlock = false`, `miniHUD = false`, `immortal = false`, `fuel = false`, `weapons = false`, `Supercarrier = { deck_crew = true, speakers_enabled = true }`.
Rôles de contrôle au sol : Blue a 2 commandants d'artillerie, 2 observateurs avancés, 2 observateurs et 2 instructeurs ; Red a 2 observateurs et 2 instructeurs ; `isPilotControlVehicles = true`.
Date : 31 octobre 2024, heure de départ 36 000 s (10:00), preset de nuages `Preset11`.
Le texte du briefing est le même pour les deux camps et commence par « The goal is to capture all zones » (l'objectif est de capturer toutes les zones).
Composition des coalitions : Blue 4 pays, Red 3, neutre 85.

## 5. Le Foothold Config Manager

Lus : `tools/FootholdConfigManager/README.md`, `CHANGELOG.md`, `Foothold Config.gui.json`, et les pages du manuel qui décrivent l'outil ; le source C# n'a pas été lu (la liste de ses noms de fichiers a été relevée, et une recherche textuelle de `.miz.orig` a été lancée).
C'est un programme de bureau Windows construit sur .NET 8 (`FCM-README`), livré sous la forme `Common Scripts/Foothold Config Manager 2.5.7.exe`.
Son état (préférences, instances, presets) vit dans `Saved Games/Foothold Config Manager` (`FCM-README`).

| Fonction | Ce qu'elle fait pour l'admin | Source |
|---|---|---|
| Assistant du premier lancement | Choisir un `.miz`, choisir un profil Saved Games, installer la config Normal ou WW2 dans `Missions\Saves`, la valider et l'ouvrir ; une config existante n'est pas écrasée. | `manual p.5` |
| Éditeur de config | Catégories à gauche, champs typés, listes de contrôle, grilles liées (disponibilité + prix + rang dans une seule grille), aide par champ, validation de la syntaxe Lua, Undo, Restore Defaults, une vue des commentaires. | `manual p.9-10`, `FCM-CHANGELOG` |
| Interface pilotée par métadonnées | Libellés, éditeurs, valeurs valides, conditions de visibilité et de verrouillage viennent des commentaires `@gui` de la Config elle-même ; `Foothold Config.gui.json` contient 15 entrées supplémentaires (libellé, aide, choix) comme `FootholdLocale`, `CallsignOverrides`, `ShopPrices`. | `Config:246-247`, `gui.json` |
| Changement d'époque | Choisir une époque propose de cocher les lignes de templates étiquetées pour cette époque et rafraîchit les listes d'avions et d'armes ; les avions exigés par les fonctions IA activées sont protégés et expliqués. | `manual p.7, 22`, `FCM-CHANGELOG` (2026-10-25) |
| Presets | Trois instantanés nommés par instance et par type de config ; le changement valide et sauvegarde la config en cours. | `manual p.8` |
| Instances | Plusieurs profils DCS ou instances de serveur, chacun avec sa propre config ; copie des réglages de l'un vers l'autre ; mise à jour des variantes de config correspondantes sur plusieurs instances. | `manual p.10`, `FCM-CHANGELOG` |
| Update Config | Fusionner la config d'une nouvelle version (depuis un `.miz` ou un fichier) dans la config actuelle, en choisissant pour chaque valeur par défaut modifiée ; sauvegarde horodatée, cinq conservées ; règle de fusion par table (`mergeRows`, `replaceTable`, `keepTable`). | `manual p.9`, `Config:1607` |
| Panneau MissionScripting | Affiche le chemin de `MissionScripting.lua`, applique la modification de désanitisation, revérifie l'état. | `manual p.4` |
| Téléchargement de mission | Liste les cartes d'une version, télécharge les missions complètes dans une instance choisie ou un dossier personnalisé mémorisé, avec une revue de chaque nom de fichier de sortie. | `manual p.27-29`, `FCM-CHANGELOG` (2026-11-05) |
| Mise à jour de fichiers seulement | Pour les missions vérifiées compatibles avec la version, crée une copie où seuls les fichiers de scripts sont remplacés, en gardant les modifications propres à la mission, l'entrepôt et la météo ; plusieurs variantes (jour, nuit…) à la fois. | `manual p.25-26` |
| Copie d'entrepôt | Pendant un téléchargement complet, copie le fichier d'entrepôt d'une ancienne mission de la même carte, y compris le stock modé. | `manual p.28` |
| Profils météo et heure | Profils enregistrés de météo, de date et d'heure appliqués aux missions créées, avec des noms de fichiers fondés sur le profil ; les réglages peuvent être lus depuis un autre `.miz`. | `manual p.28`, noms de fichiers `Weather*.cs` |
| Options de mission | Applique des réglages d'options de mission préparés aux missions téléchargées. | `manual p.28` |
| Prise en charge de DCSServerBot | Lit les sauvegardes `.miz.orig` des dossiers `.dcssb` découverts comme sources de mise à jour et peut enregistrer le résultat comme original DCSServerBot (`.miz.orig`). | `FCM-CHANGELOG` ("updating missions from DCSServerBot backups"), chaînes d'interface à `MainForm.MissionDownloads.Files.cs:904` et `MainForm.MissionDownloads.Review.cs:143` |
| Liste des serveurs | Pour une instance de serveur dédié vérifiée, ajoute les missions créées à la liste des missions du serveur (en marche ou arrêté) ; ne démarre ni ne charge rien. | `manual p.28-29` |
| Auto-mise à jour | Vérifie séparément la présence d'un Manager plus récent et de versions de missions. | `manual p.25` |
| Concepteur admin et export utilisateur | Un concepteur protégé par mot de passe peut exporter un exécutable « utilisateur » avec une sélection de réglages de l'interface ; un déverrouillage Testing affiche les réglages de test. | `FCM-README` |
| Ligne de commande | `--check <config>`, `--audit <config> <log>`, `--self-test-stability`, `--self-test-merge`. | `FCM-README` |

Le manuel dit aux admins d'utiliser cet outil et de ne pas modifier le `.miz` ni déplacer la config à la main (`manual p.4`).

## 6. Exploiter Foothold sur un serveur

### Ce dont le serveur a besoin

`MissionScripting.lua` doit être désanitisé pour que `io` et `lfs` soient disponibles, et cela doit être refait après chaque mise à jour de DCS (`manual p.4`).
Sans `io`, le moteur affiche `PERSISTENCE_SAVE_DISABLED` pendant 600 s et cesse d'essayer de sauvegarder (`zc2:7136-7140`) ; sans `lfs`, il affiche `PERSISTENCE_SAVE_DESANITIZE` et ne charge rien (`zc2:7252-7258`).
Le chargeur de la Config utilise aussi `lfs.writedir()` et `loadfile` pour trouver la config externe (`Config:1`, `Config:153-155`).
Le source du moteur contient 4 `io.open`, 8 références à `lfs.` et aucun `os.remove` (comptes par regex sur `zoneCommanderv2.lua`), et la remise à zéro d'une campagne se fait en écrivant une table vide, pas en supprimant un fichier (`setup:2805-2806`).
La mission doit être hébergée comme serveur multijoueur même pour un seul joueur, parce que les slots sont en spawn dynamique (`manual p.4`).
Aucun mod n'est requis (`requiredModules` vide dans `mission`) ; les mods sont une option gérée par `AllowMods` et une modification d'entrepôt (`manual p.24`).
Le manuel recommande de désactiver Tacview sur le serveur pour les performances (`manual p.4`).

### Fichiers sur le serveur

Tout se trouve sous `Saved Games\<profile>\Missions\Saves` : `Foothold Config.lua` (et `Foothold Config WW2.lua`), la sauvegarde de campagne `<FootholdSaveBaseName>.lua`, le fichier de rangs `Foothold_Ranks.lua` partagé par toutes les campagnes (`setup:756`), et les sauvegardes CTLD, d'entrepôt et autres listées dans « Save folder inventory » de `02-persistence-lifecycle-plumbing.md`.
Il existe une sauvegarde de campagne par carte, par époque et par mode : sur le Caucase `FootHold_CA_v0.3`, `FootHold_CA_v0.3_Coldwar`, `FootHold_CA_v0.3_Vietnam`, chacune avec un suffixe `Pvp` en PvP (`setup:467-477`).
Le nom de sauvegarde ne contient pas la version de la mission (la mission est en 6.5.2, le nom de sauvegarde dit `v0.3`), de sorte qu'une nouvelle version de la mission reprend la campagne existante.

### Remise à zéro et redémarrage

À la victoire ou à la défaite avec `AutoRestart`, le setup écrit une table `zonePersistance` vide, appelle `resetSaveFileAndFarp`, et lève le flag 181 cinq secondes plus tard, ce qui déclenche le trigger `a_end_mission` (`setup:2803-2812`, règle 7 de `mission`).
Avec `AutoRestart = false`, Blue obtient à la place un menu « restart and reset » avec Yes et No (`setup:2813-2828`).
Un admin peut forcer la même chose avec les mots de marqueur `restartMission` et `endMission` (`Config:3508-3513`).
Ce que le serveur charge ensuite relève de sa propre liste de missions : « Restart requests the mission restart flag; it does not itself choose a different MIZ » (`manual p.62`).
Le fichier de rangs n'est jamais remis à zéro (`manual p.23`).

### Mettre à jour sans perdre la progression

La progression survit à une mise à jour parce qu'elle vit hors du `.miz`, sous des noms de sauvegarde qui ne changent pas d'une version à l'autre.
Il existe trois voies de mise à jour, toutes par le Config Manager (§5) : mise à jour de fichiers seulement du `.miz` propre à l'admin (conserve les modifications, l'entrepôt, la météo), téléchargement complet avec copie d'entrepôt facultative, et fusion de config (« Update from MIZ »).
Une config externe qui n'a pas les réglages ajoutés par une nouvelle version se charge quand même : les réglages manquants prennent les valeurs internes par défaut et un avertissement s'affiche 12 fois (`Config:94-135`).
Les templates de garnison renommés d'une version à l'autre sont associés par `BlueUpgradeTemplateMigration` (`setup:20-50`).

### `MizBatchUpdater.exe` et `MizFileReplacer.exe`

Tous deux n'existent que sous forme de binaires dans `tools/` (199 ko et 173 ko).
Ni le `README.md` du dépôt, ni le manuel, ni le `README.md` et le `CHANGELOG.md` du Config Manager ne les mentionnent (0 correspondance textuelle dans chacun).
La seule mention figure dans `THIRD_PARTY_NOTICES.md`, qui liste « the authorship, dependency notices and corresponding source » des deux exécutables parmi les éléments dont la provenance n'a pas été établie.
D'après leurs noms, ils remplacent des fichiers de scripts à l'intérieur d'une ou plusieurs archives `.miz`, ce que fait la mise à jour de fichiers seulement du Config Manager (estimation ; rien n'a été exécuté ni désassemblé).

### Cartes, époques et modes pris en charge

La version livre 11 fichiers de mission : Afghanistan, Caucase, Allemagne Guerre froide, Irak, Kola, golfe Persique, Atlantique Sud (version 0.83), Sinaï nord, Sinaï étendu, Syrie étendue, et Normandie WWII (`Missions/`).
Le `README` liste neuf théâtres pris en charge (Caucase, golfe Persique, Sinaï, Syrie, Allemagne Guerre froide, Kola, Irak, Afghanistan, Normandie WWII) ; l'Atlantique Sud est livré mais ne figure pas dans cette liste.
Un seul `.miz` par carte sert toutes les époques : le nom de fichier dit `Coldwar-Modern-Vietnam` (Irak : `Gulfwar_Modern_Vietnam`) et l'époque est le réglage `Era`, qui échange les noms de templates et les listes d'entrepôt au chargement (`Config:198`, `setup:487-591`).
La date de la mission fait exception : elle doit être changée dans le Mission Editor (`manual p.7`).
Il n'y a pas de fichier de mission PvP séparé : le PvP est le réglage `PvP`, honoré seulement sur le Caucase, la Syrie et le golfe Persique (`Config:3525`, `manual p.56`), avec son propre nom de sauvegarde.
La Normandie est une lignée à part : son propre fichier de config, un fichier de setup dont 35 % des lignes sont communes avec le Caucase, et `zeus_Full_v2.1.lua` embarqué à la place de `Zeus.lua` (`THIRD_PARTY_NOTICES.md`).

### Localisation

`Foothold_Localization.lua` (38 857 lignes) définit dix locales : EN, DE, FR, ES, RU, PT-BR, TR, IT, zh-CN, zh-TW (`Config:204-219`).
La langue du serveur est le réglage `FootholdLocale`, appliqué par `FootholdLocalization:SetLocale` juste après la lecture de la config (`Config:220-223`, `Foothold_Localization.lua:20831`) ; une valeur inconnue retombe sur la locale par défaut (`Foothold_Localization.lua:20823-20829`).
Elle régit les messages globaux à l'écran ; chaque joueur peut choisir une autre langue pour ses propres menus et messages, et ce choix est sauvegardé avec la campagne (`zc2:25741-25742`).
Le fichier de setup ne contient aucun texte destiné au joueur, seulement des clés (699 sites d'appel de localisation), si bien qu'une nouvelle carte signifie aussi de nouvelles clés dans le fichier de localisation pour chaque texte d'ambiance de zone, titre de mission et message d'événement (`setup:297-300`, `setup:6197-6199`).
Détails dans « Messages and localisation » de `02-persistence-lifecycle-plumbing.md`.

## Coût d'écriture d'une carte

Mesuré sur le Caucase (mission v6.5.2, scripts v6.5.3) ; tout ce qui suit est entretenu à la main dans le Mission Editor ou dans un éditeur de texte.

| Élément | Taille |
|---|---|
| Fichier de setup | 10 014 lignes, dont environ 2 500 sont des données de carte et le reste du code copié d'une carte à l'autre (62 à 74 % des lignes des autres fichiers de setup modernes sont identiques à des lignes du Caucase) |
| Zones déclarées | 89 (21 aérodromes, 35 FARP, 1 porte-avions, 32 autres) |
| Listes de garnison nommées | 49, plus 14 profils de taille aléatoires et un pool de 46 noms de templates Red et 9 Blue |
| Numéros de waypoint et textes d'ambiance | 61 et environ 75 |
| Rattachements aux aérodromes | 56 |
| Déclarations de sorties | 409 (402 `DirectorCapability` + 7 `GroupCommander`) dans 56 blocs |
| Connexions | 135 visibles + 14 cachées |
| Données de théâtre du Director | 9 zones, 9 liens d'infrastructure |
| Boutique | 45 ids d'articles enregistrés, 54 ids mis en étagère, 76 lignes d'étagère |
| Événements et missions suivies | 17 et 44 |
| Triggers de zone scriptés | 31 |
| Branches de mode et d'époque dans le setup | 262 références PvP, 90 tests d'époque |
| Sites d'appel de localisation dans le setup | 699 |
| Trigger zones dans le `.miz` | 1 331 (120 noms simples, 717 sous-zones de spawn, 109 points d'atterrissage, 60 emplacements SAM, 87 waypoints de couloir, 87 zones de scoot, 70 zones de porte-avions, 35 indications d'entrepôt, 24 positions d'artillerie, 23 points d'accroche routiers, 8 points d'atterrissage de couloir) |
| Groupes template dans le `.miz` | 508 groupes en late activation (181 avions, 31 hélicoptères, 283 terrestres, 13 navires), dont 141 chargements de vols `RED_` / `BLUE_` |
| Templates de slots clients | 34 |
| Statics | 338 (35 plates-formes de FARP avec environ 240 statics de décor, plus des objectifs nommés) |
| Entrepôts | 21 aéroports + 46 autres, chacun avec 174 lignes d'avions et 800 lignes d'armes |
| Fichiers son | 55 |
| Triggers de mission | 7 |
| Lignes de listes de contrôle de la Config nommant des templates du `.miz` | 129 templates de vols + 14 familles de SAM, à tenir en accord avec le `.miz` |

Le même fichier de mission doit aussi rester cohérent sur trois époques : les templates de garnison et de convois existent en variantes Modern, Cold War et Vietnam (`setup:487-591`, `setup:1004-1040`).

## Vu hors de ce thème

- `BlueUpgradeTemplateMigration` : une table de renommage appliquée aux noms de garnison sauvegardés, c'est-à-dire une migration de format de sauvegarde qui vit dans le fichier de setup (`setup:20-50`).
- `DynamicHybridConfig` et `bc:startDynamicHybridFiller` : génération de capacités de sorties à l'exécution à partir de règles de distance, en plus de celles écrites à la main (`setup:6077-6118`, `zc2:23020`).
- `TheaterInfrastructure` : un bâtiment de la carte détruit coupe la route de supply Red d'une zone SAM (`setup:2271-2360`, `setup:1291`).
- `bc:roamGroupsToLocalSubZone` : patrouille des groupes de garnison entre sous-zones et déplacement des navires, pilotés par des préfixes de noms (`setup:2848-2886`).
- `HercCargoDropSupply.init(bc)`, `startWarehousePersistence()`, `Frontline.BuildFromZones` et sept caches sont démarrés explicitement par le fichier de setup, pas par le moteur (`setup:6000-6013`).
- Variante Kola : le camp de départ de pays entiers vient de flags sauvegardés, et un flag `DynCampaign` change le nom de sauvegarde (`kola:745-820`).
- `ewrs_altitudeDisplayMode = "wwii"` : EWRS rapporte des tranches d'altitude en Normandie (`ConfigWW2:813`).
- `AddWeightToPlaneRed` / `AddWeightToPlaneBlue` : poids de cargo interne supplémentaire appliqué aux types d'avions de la Seconde Guerre mondiale (`ConfigWW2:422-445`).
