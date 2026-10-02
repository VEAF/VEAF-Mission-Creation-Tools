# Prompt — construire une mission VEAF Open Training sur une carte DCS

> À coller tel quel au début d'une nouvelle session Claude Code, dans un **dossier vide** qui sera
> le dossier de la mission.

---

Tu vas construire **de zéro** une mission **VEAF Open Training** pour DCS World, avec les outils
VEAF Mission Creation Tools v6 (`veaf-tools`) et le serveur MCP `veaf-mission-mcp` (plugin Claude
`veaf-mission-editor`).

Une Open Training tourne sur les serveurs VEAF, ouverte à tous : des bases où l'on prend un avion
librement (slots dynamiques), du soutien (ravitailleurs, AWACS), des zones d'entraînement graduées,
de vraies zones de combat réparties sur le théâtre, des CAP et des QRA, une défense aérienne
crédible, et une météo déclinée en variantes. Les pilotes ne connaissent pas la mission : tout ce
qu'ils lisent doit être juste.

## 0. Avant tout

1. **Charge le skill `veaf-mission-editor:veaf-mission-authoring`** et suis-le : il est la source de
   vérité pour les conventions VEAF (noms réservés, `#command`, `#veafInterpreter`, zones, QRA).
2. Appelle `capabilities` et `list_catalog` : note la version de `veaf-tools` et les actions
   disponibles. Lis les **limitations connues** (`describe_known_limitations`) et tiens-en compte.
3. **Ce qui manque ou ne marche pas dans les outils, tu le signales.** Une action absente, un
   résultat faux, une doc qui dit autre chose que le comportement : tu contournes proprement pour
   avancer, et tu le notes dans un bloc **« Retours pour VMCT »** de ton rapport final (quoi, où,
   comment tu l'as vu, ce que tu as fait à la place). C'est ainsi qu'on améliore les outils.
4. Réponds en français, concis. Pose tes questions **une par une**, avec des choix et ta reco.

## 1. Les questions à poser (et seulement celles-là)

Une par une :

1. **La carte** (un théâtre supporté par `scaffold_mission`).
2. **L'époque** : moderne, Guerre froide (précise une année) ou WW2. Elle décide des matériels, des
   bases actives et de la date de mission. Propose celle qui colle à la carte.
3. **Le gabarit de départ** de `scaffold_mission`. Présente-le ainsi :
   - `minimal` — l'infrastructure et le cœur (menu radio, spawn, raccourcis, interpréteur,
     sécurité). Pour une mission très simple ou un banc d'essai.
   - `standard` — le cœur, plus CTLD et CSAR, déplacement des ravitailleurs, météo, points nommés,
     missions CAS et transport ; les zones de combat et les QRA y sont en **exemples commentés**, que
     `create_combat_zone` et `create_qra` activent à leur premier appel. **Reco** : c'est la base
     d'une Open Training ; on y ajoute ce qu'il manque (assets, missions CAP, Skynet, AIEN).
   - `full` — tout, dont Skynet, AIEN, assets, missions CAP, sanctuaires, vagues aériennes, TUM,
     avec la configuration avancée en exemples commentés. Plus lourd à relire.
   (Vérifie ces contenus dans le `mission.yaml` généré : ils peuvent avoir évolué.)
4. **Une mission existante dont s'inspirer ?** Si oui, section 3.
5. **Les escortes** des ravitailleurs et de l'AWACS, seulement pour ceux dont l'orbite est proche du
   front (voir 4.4).

Tout le reste, tu le décides avec les règles ci-dessous, et tu l'annonces.

## 2. Méthode

- **Rien de mémoire.** Types d'unités → `list_unit_types` ; alias → `list_shortcuts` ; lieux →
  `geocode` (affiche le point trouvé) ; coordonnées → `resolve_coordinates`. Un chiffre de briefing
  se **calcule** ; une enveloppe d'arme ne s'écrit que si elle est sourcée.
- **Ne te fie pas à la description d'un alias** : vérifie ce qu'il génère réellement (composition,
  époque des matériels) avant de le choisir.
- **Travaille dans le dossier** (`src/mission/` + `mission.yaml`, monde durable), pas dans un `.miz`.
- **Relis ce que chaque action écrit**, au moins une fois par type d'action et de catégorie (avion,
  véhicule, statique, navire) : un fichier valide peut produire des unités qui ne marchent pas.
- Si tu dois modifier `src/mission/mission` sans action dédiée : script qui charge la table Lua, la
  modifie et la réécrit — jamais de remplacement de texte — et tu le notes dans « Retours pour VMCT ».
- **Contrôle, puis affirme** : « c'est prêt » ne se dit qu'après la section 8.
- **Arrête-toi avant tout commit / push** et demande le feu vert.

## 3. S'inspirer d'une mission existante (si question 1.4 = oui)

On **s'en inspire, on ne la recopie pas.** Elle a été faite avec d'autres outils, souvent par
accumulation ; la nouvelle mission suit les règles de ce prompt.

- **Lis-la en entier** : groupes **et noms d'unités** (un groupe d'apparence inerte porte souvent un
  `#veafInterpreter["…"]` qui crée une batterie entière), zones, triggers, dessins, coalitions de
  tous les aérodromes, slots, bullseye, date, briefing, configuration, presets, variantes météo.
- Retiens-en **les intentions** : quelles bases, quel soutien, quelles défenses, quelles zones, quel
  esprit. Reprends ce qui est voulu et bon ; corrige ce qui est incohérent (et prouve-le) ; laisse ce
  qui ne sert à rien ; **signale ce que tu ne comprends pas** au lieu de l'effacer ou de le copier.
- **Une mission convertie (`convert-v5`) n'est pas la source** : lis la v5 d'origine (le dossier
  `backup_v5/` que laisse la conversion, ou le dépôt v5), puis compare-la à la version convertie. Une
  conversion perd du contenu sans le dire (des missions scénarisées entières), et le dossier converti
  peut porter des retouches manuelles faites depuis : signale chaque écart dans un sens ou dans l'autre.
- **Inventorie les ressources récupérables** : kneeboard (cartes d'approche, plan de fréquences),
  sons (balises, messages), images. Elles ne se voient que dans les fichiers.
- Rends un tableau **repris / adapté / écarté / inconnu**, avec la raison de chaque ligne.

## 4. Conception — règles et quantités

Les quantités dépendent de la **taille de la carte et du front**. Avant de poser quoi que ce soit,
mesure et annonce : la longueur du front (nm), la profondeur de chaque camp, le nombre d'aérodromes
utilisables de chaque côté. Les ordres de grandeur ci-dessous sont des points de départ ; ajuste-les
à ces mesures et dis pourquoi.

### 4.1 Front et aérodromes

- **Trace le front de l'époque** : quels pays / régions sont bleus, rouges, neutres (réalité
  historique ou scénario usuel de la carte). Une phrase avant de commencer.
- **Bases bleues avec slots dynamiques** (souvent 8 à 12). Dans l'ordre :
  1. bases **militaires réelles de l'époque** ; la principale devient la « base mère » (météo ICAO,
     ravitailleur arrière) ;
  2. réparties **en profondeur** : quelques bases avancées, le reste en arrière ;
  3. une **enclave** si l'histoire en offre une.
- **Bases rouges** : tous les aérodromes du côté rouge prennent la couleur rouge. **Quelques-unes
  ont des slots dynamiques** (nombre selon le front, souvent 2 à 4, réparties comme en bleu) : des
  joueurs volent rouge, pour le combat aérien entre joueurs. Pas de zone de combat côté rouge, mais
  des **QRA et CAP bleues** (4.8, 4.9) pour leur donner de l'opposition.
- **Neutres** : le reste. Jamais un aérodrome neutre avec des slots.
- **Si le rouge est jouable, écris la règle du combat entre joueurs** : où il est permis, où il est
  interdit, et dis-le dans le briefing. Deux outils, à proposer à l'utilisateur :
  - une **arène** dédiée, loin du théâtre : slots en départ en vol pour les deux camps, par type de
    missile (Fox 1, Fox 3), avec un AWACS de chaque camp ;
  - une **zone de sanctuaire** (module `SANCTUARY`, `sanctuary_zones`) qui protège les arrières d'un
    camp : un intrus est prévenu puis détruit, et `protect_from_missiles` détruit les missiles tirés
    sur les défenseurs. Le polygone est tracé par des unités en activation différée
    (`polygon_units`), jamais activées.
- **FARP** : une bonne pratique à généraliser — un FARP bleu près du front et près de chaque zone
  destinée aux hélicoptères (réarmement, CTLD, CSAR). `add_farp` le pose complet, avec son **dépôt de
  munitions** (statique `FARP Ammo Dump Coating`, `<FARP> - Ammo`) que CTLD reconnaît comme point
  logistique (`manage_logistics`, actif par défaut) ; le chargement de troupes au FARP est ouvert
  (`troopPickupAtFARP` dans `ctld-config.yaml`).
- **`ctld-config.yaml`** : vide les listes d'exemple que CTLD reprend de ses valeurs par défaut
  (`extract1`…`extract25`, `logistic1`…`logistic10`) — aucun de ces noms n'existe dans la mission, et
  ils font 35 avertissements au démarrage.
- `set_airbase_coalition` pour chaque aérodrome, avec `dynamic_spawn: false` sur ceux qui ne doivent
  pas offrir de slots. `src/warehouses.yaml` : carburant et munitions illimités, départ moteur chaud.
  `src/dynamic-slot-templates.yaml` : modèles des deux coalitions qui ont des slots, **de l'époque de la
  mission seulement** — le catalogue livré propose aussi des appareils WW2 et Guerre froide : retire ceux
  d'une autre époque (ils encombrent la liste et leurs radios ne prennent pas le plan de fréquences).

### 4.2 Identité et sécurité

- **Nom** : `VEAF_OpenTraining_<Carte>_ICAO_<code>`, `<code>` = aérodrome de la base mère **s'il a une
  station METAR vivante** (vérifie
  `https://tgftp.nws.noaa.gov/data/observations/metar/stations/<ICAO>.TXT`, jour du jour dans
  `JJHHMMZ`) ; sinon le grand aérodrome du théâtre le plus proche qui en a une.
- `mission.era`, **date de mission** et `base_date` de `versions.yaml` cohérentes avec l'époque.
- **Langue** : `mission.language: fr` et briefing en français, sauf mention contraire.
- `silence_atc_on_all_airbases: true`.
- **Sécurité active par défaut** : la mission tourne sur les serveurs VEAF. Pas de
  `security.disabled: true` dans la configuration de base. Demande à l'utilisateur s'il faut des
  hachages de mot de passe, ou si le niveau des pilotes du serveur suffit. **Jamais un mot de passe
  en clair**, même en commentaire à côté de son hachage : les sources se publient.
- **Aucun mod exigé** : la table `requiredModules` de la mission reste vide, sauf demande explicite.
  Un seul mod y suffit à interdire le serveur aux joueurs qui ne l'ont pas. Elle se remplit sans
  bruit quand on pose une unité d'un mod, ou quand on reprend une mission existante.
- **Deux usages, deux configurations** dans `mission.yaml` :
  - **par défaut** = serveur : sécurité active, logs `info`, toutes les variantes météo ;
  - **profil `LOCAL_TEST`** (`veaf-tools mission build --profile LOCAL_TEST`) : sécurité désactivée,
    logs `debug`, noms des groupes lisibles (`hide_names_from_spawned_groups: false`), pas de
    variantes météo (`pipeline.weather: false`), et ce qui rend un test local plus rapide.
- **Date et heure** de mission : `set_mission_date`.
- **Bullseye** (`set_bullseye`) : un **repère que les pilotes peuvent nommer**, au centre du front, le
  même pour les deux camps, **pas sur une zone** (il la masquerait sur la carte).
- **Briefing** (`set_briefing` : titre, situation, tâches bleue et rouge) : le contexte en deux
  phrases, les bases, le soutien (fréquences, TACAN, altitudes), les zones par menu F10, les QRA, les
  commandes VEAF utiles.

### 4.3 Soutien aérien

- **Ravitailleurs : au moins 2** (un à perche, un à panier), **plus si le front est long** : une paire
  par secteur de front, chaque secteur couvrant ses zones de combat. Pistes **séparées**, **altitudes
  différentes**. `add_air_group` (départ en vol), puis `edit_route` `add_task` : `orbit` race-track à
  l'altitude du point, `tanker`, `activate_beacon` (TACAN Y), `set_unlimited_fuel`.
- **AWACS : au moins 1**, plus si le front dépasse ce qu'un seul couvre en restant en retrait (vérifie
  la distance entre son orbite et les zones les plus lointaines). Tâches `awacs`, `eplrs`,
  `set_unlimited_fuel`, `orbit`.
- **Côté rouge**, s'il a des slots : au moins un ravitailleur et un AWACS rouges, mêmes règles.
- **Un nom partout** : nom de groupe = indicatif (familles tanker Texaco 1 / Arco 2 / Shell 3 ;
  AWACS Overlord 1 / Magic 2 / Wizard 3…) = libellé de preset = texte `ASSETS`. Même fréquence
  partout. Déclare-les dans `modules.ASSETS`.
- **Drones de guidage laser** (option) : un MQ-9 dont la **tâche de groupe est `AFAC`**, en orbite en
  cercle au-dessus de sa zone, déclaré dans `modules.ASSETS` avec son code laser et sa fréquence (`jtac`,
  `freq`, `mod`) : CTLD le prend comme JTAC et les pilotes le trouvent dans le menu (vérifié en jeu sur
  GermanyCW v6). Trois choses à savoir, à dire au briefing :
  - CTLD le remonte à `JTAC_droneAltitude` (3 000 m sol par défaut) quelle que soit l'altitude écrite :
    l'artillerie antiaérienne lourde d'une zone difficile l'abat (le menu `ASSETS` le relance) ;
  - le JTAC ne désigne que des **véhicules**, pas des statiques ;
  - il ne marque qu'à **10 km** : pas de drone sur une zone dont les SAM portent plus loin.
- **Groupe aéronaval ami** (option, si la carte a la mer et que les joueurs ont des appareils
  embarqués) : `add_carrier_group` pose le porte-avions avec son TACAN, son ICLS et son Link 4, le
  ravitailleur embarqué et l'hélicoptère de sauvetage que le module `CARRIER` cherche, et l'entrepôt
  du navire ; les slots sur le pont sont des `add_air_group` en `start: deck-cold` ou `deck-hot`, avec
  `carrier` = l'unité porte-avions qu'il a rendue. TACAN, ICLS et Link 4 dans le texte `ASSETS`,
  module `CARRIER` activé.
  **Toujours deux porte-avions, le Stennis et le Roosevelt** (un `add_carrier_group` chacun, TACAN,
  ICLS, Link 4 et fréquences distincts) : décision de David du 02/10/2026, valable pour toute mission
  générée qui a un groupe aéronaval.

### 4.4 Escortes

- Orbite **loin du front** (hors d'atteinte d'une CAP ou d'une QRA ennemie) : **escorte** (un vol de
  chasse avec la tâche `escort` vers le groupe escorté).
- Orbite **proche du front** : **demande à l'utilisateur** (question 1.5). Une escorte protège l'actif,
  mais elle abat aussi les cibles que les joueurs font apparaître à côté.

### 4.5 Défense aérienne des bases et des arrières

- **Chaque base avec slots** (bleue et rouge) : de la **courte portée et de la moyenne portée**.
- **Quelques batteries longue portée**, judicieusement réparties pour couvrir les zones clés sans
  fermer tout le ciel (SA-10, SA-11, Patriot… **selon l'époque et le camp** ; lis dans
  `list_shortcuts` quel alias pose vraiment de la longue portée — le nom d'un alias ne suffit pas).
- **Aucune défense permanente ne couvre une base adverse qui a des slots.** « Permanente » compte
  les batteries `#veafInterpreter` **et** les zones de combat activées au démarrage
  (`active_at_start`). Mesure la distance de chaque batterie moyenne et longue portée à chaque base
  adverse avec slots, et compare-la à la portée de l'arme — sourcée ou mesurée dans DCS ; sinon, donne
  la distance en point ouvert. Un pilote qui décolle sous un SA-10 ne s'entraîne pas.
- **Des radars d'alerte avancée (EWR) derrière les lignes**, des deux côtés.
- Posés en permanent via `#veafInterpreter["-<alias>, country <pays>, hdg <cap>"]`.
  **Porteur = une unité de la classe générée** (le lanceur de l'alias), pour que l'éditeur montre le
  cercle de portée. **Noms d'unités uniques** : suffixe après la balise (`… #<base>-01`).

### 4.6 Zones d'entraînement — 3 familles de 3 niveaux

Chaque famille = **3 zones imbriquées sur le même cercle** (facile ⊂ moyen ⊂ difficile) : les noms ne
se recouvrent pas (`combatZone_<Lieu>_Easy`, `…_Medium`, `…_Hard`), chaque zone ne contient **que
ses ajouts**, et chaque niveau inclut celui d'en dessous (clé `includes:` de `combat_zones[]`).

1. **Hélicoptères** : près d'une base bleue, ou d'un **FARP** posé à côté.
   Facile = statiques inertes ; moyen = AAA légère ; difficile = défense courte portée réaliste.
2. **Avions d'attaque** : peut être plus loin, tant qu'elle reste **à plus de 75 nm du front** et
   n'est dans la portée d'aucune défense réelle. Même progression, avec plus de blindés.
3. **SEAD / DEAD** : assez à l'écart pour que ses SAM n'atteignent ni une base, ni une piste de
   ravitailleur, ni une autre zone (4.7) — mais **pas plus loin que ça**. Facile = une batterie
   moyenne portée seule ; moyen = moyenne + courte portée ; difficile = moyenne, courte et EWR en
   réseau Skynet.

   **Pas de longue portée dans une zone d'entraînement.** Un SA-10 porte à 65 nm : interdire qu'il
   atteigne une base amie le repousse au-delà de 65 nm de tout ce qui est bleu, et sur une carte
   étroite il n'y a plus de terrain praticable à cette distance. Mesuré sur l'Open Training Caucase
   de septembre 2026 : la zone SEAD avait atterri en péninsule de Taman, à **24 minutes de vol** de
   la base bleue la plus proche et à 243 nm du premier ravitailleur, contre 1 minute pour la famille
   hélicoptères et 9 pour la famille attaque. Un pilote qui se fait descendre refait les 24 minutes.
   La décision de David (01/10/2026) tient en une phrase : *« on peut faire une CZ d'entraînement
   SEAD moins violente, et si on veut s'entraîner avec un SA-10 c'est pas ce qui manque sur la
   map »* — la longue portée vit dans les défenses permanentes (4.5) et dans les vraies zones (4.7),
   où personne ne vient la refaire dix fois.

   **Règle générale, valable pour les trois familles** : le temps de trajet depuis la base la plus
   proche fait partie de la conception. Vise le même ordre de grandeur pour les trois (quelques
   minutes), et quand un contenu impose un éloignement impraticable, **c'est le contenu qu'on
   réduit**, pas la distance qu'on subit.

**Graduer la difficulté avec `defense N`.** Les commandes de spawn de groupes (`_spawn samgroup`,
`armorgroup`, `combatgroup`, `transportgroup`, `convoy`…) acceptent `defense 0` à `5`, qui choisit
une batterie antiaérienne type de plus en plus forte (AAA à 0, SAM courte portée IR puis radar vers le
haut). Tu peux donc écrire un même porteur à chaque niveau avec une valeur croissante :
`#command="_spawn samgroup, defense 1"` / `… defense 3` / `… defense 5`. Les niveaux suivent
`mission.era`. Deux précautions :
- le tirage **ajoute un aléa** (un niveau de plus ou de moins de temps en temps) ;
- **vérifie la composition de chaque niveau** pour l'époque de la mission (`list_shortcuts`) avant de
  t'y fier ; si elle ne convient pas, prends des alias explicites.

**Faire varier un site d'une activation à l'autre** avec les balises de tirage, sur les noms
d'unités : tous les éléments qui portent le même `#spawngroup="<nom>"` forment un ensemble,
`#spawncount=` dit combien en sortent à coup sûr, `#spawnchance=` la probabilité de chacun. Exemple :
quatre SA-15 posés, `#spawngroup="SA15" #spawncount=2` → deux d'entre eux, jamais les mêmes. Un
pilote qui revient ne retrouve pas le site qu'il a appris. Vaut aussi pour les vraies zones (4.7).

**Cibles inertes des niveaux faciles : des groupes d'un véhicule, pas des statiques.** Un statique est
**froid au pod** (pas de moteur, aucun script ne le réchauffe) et le drone laser ne le désigne pas. Pose
chaque cible comme un groupe d'un seul véhicule, à sa place exacte, **chaud au départ**
(`coldAtStart = false`), **tir interdit** (ROE `weapon hold`) et **sans dispersion sous le feu** : il
reste immobile et muet, et un pod le voit (vérifié en jeu sur GermanyCW v6). Les statiques restent pour
ce qui ne vit pas : bâtiments, dépôts, avions au parking.
`training: true`, un menu radio par famille.

**En option, une zone hélicoptère hors combat** : navigation ou recherche d'un équipage abattu,
avec des balises radio sur l'itinéraire (sons joués en boucle, fréquences FM données au briefing) et
un signal de détresse sur le lieu. `training: true`, `completable: false`. Les sons doivent exister
dans la mission : `add_sound` embarque chacun, puis sur le premier point de chaque unité-balise
`edit_route` `add_task` `set_frequency` (FM) suivi de `transmit_message` (le son, `loop`, un
`subtitle`).

### 4.7 Vraies zones de combat — au moins 6 de plus que les zones d'entraînement

Avec 9 zones d'entraînement : **au moins 15 vraies zones**, plus si le front est long. Varie les types :

| Type | Nombre indicatif |
|---|---|
| Front — blindés, artillerie | 2-3 |
| SEAD — sites radar ou SAM isolés | 2 |
| Convois **en mouvement** | 2-3 |
| Frappe dans la profondeur — état-major, missiles sol-sol, dépôts, ponts, logistique | 3-4 |
| Base aérienne ennemie (OCA) | 1-2 |
| Antinavire (si la carte a la mer) | 1-2 |

Règles :
- **Lieux réels et plausibles pour l'époque** (terrains d'exercice, bases, sièges, axes routiers),
  cherchés pour cette carte-ci (`geocode`), réparties sur tout le front et en profondeur.
- **Défense d'époque cohérente avec la cible** (une grande unité blindée a sa défense de division, une
  base aérienne sa défense de base, un convoi sa propre AAA), via les alias, porteurs de la classe
  générée, noms d'unités uniques.
- **Cibles** : statiques pour bâtiments, bunkers, avions au sol ; groupes natifs pour ce qui vit ;
  convois = **un groupe natif** avec une route sur route (points 2+ « On Road »), sa défense
  antiaérienne dans le même groupe. Le **point de départ d'un convoi est sur la terre ferme**, pas sur un
  pont ni dans l'eau : VEAF replace au hasard un groupe dont la position est sur un terrain invalide.
- **Navires d'un même groupe espacés d'au moins 150 m** : collés, ils s'abordent et se gênent.
- **Portée des SAM des zones actives** : aucun ne doit atteindre une base amie, une piste de
  ravitailleur ou une zone d'entraînement. Une zone activée au démarrage est une défense permanente :
  la règle de 4.5 s'y applique.
- Menus radio par type, `training: false`.
- **Briefing de chaque zone** : quoi, où (**bullseye cap/distance calculés** depuis les x/y : x vers
  le nord, y vers l'est, cap = atan2(Δy, Δx)), quoi détruire, quelle défense (sans chiffre non sourcé),
  quel ravitailleur est proche et à quelle distance.

### 4.8 QRA — rouges, et bleues si le rouge est jouable

- **Couvrir certains endroits, pas tout** : une QRA partout rend le théâtre injouable. Protège les
  zones sensibles (grande base près du front, cible stratégique), laisse des couloirs praticables, et
  dis dans les briefings lesquels sont couverts.
- **Cercle dans le territoire du camp qui défend** (il se déclenche sur sa distance, pas sur une
  frontière).
- **Réponse graduée** (`groups_by_enemy_count`) : peu d'intrus → une paire légère ; davantage → plus.
- **Plusieurs variantes par niveau, tirées au hasard** : chaque niveau liste plusieurs groupes
  (chasseurs de menaces différentes) et `random_pick: 1` en fait sortir un. Les pilotes ne savent
  pas ce qui décolle.
- **Délai et hélicoptères, décidés et écrits** : `delay_before_activating` (le temps de réaction
  entre l'entrée du premier intrus et le décollage) et `react_on_helicopters` (une QRA qui
  réagit aux hélicoptères ferme la zone aux missions héliportées). Dis les deux dans le briefing.
- **Pas de menu radio de QRA ouvert à tous** : `radio_menu` seulement avec
  `radio_menu_restrict_to_group`. Chaque niveau tire entre des **appareils différents**, jamais entre des
  copies du même.
- `create_qra`, intercepteurs d'époque avec **emport** (dans chaque groupe : `pylons`, ou
  `loadout_from` un groupe `veafSpawn-*` du même type), `airport_link` sur la base.
- Si le rouge a des slots : **QRA bleues** sur quelques bases bleues, mêmes règles.

### 4.9 CAP à la demande

- **Rouges : 2 à 4**, de menaces différentes (chasseur IR, Fox 1 moyen, intercepteur haut et rapide,
  éventuellement un bombardier à intercepter), race-track **dans le territoire rouge**, virages compris.
- **Bleues** si le rouge a des slots, même logique.
- `create_cap_mission` avec une `route` (le second point donne l'hippodrome) et un emport (`pylons`
  ou `loadout_from`), et un nom de menu qui dit type, secteur, altitude.

### 4.10 Radio, météo, waypoints

- **`src/presets.yaml` à réécrire pour la carte** (le gabarit n'est pas fait pour elle) : UHF = Guard,
  bases, AWACS, patrouilles, ravitailleurs ; VHF = Guard + patrouilles ; FM 30-59 ; plan rouge si le
  rouge vole. **Les canaux de base portent les fréquences que DCS donne à l'aérodrome**, même ATC
  coupé : ce sont celles que le pilote lit sur la vue F10, et une série inventée le trompe. Ne tape
  jamais une fréquence d'aérodrome : `describe_airfield_channels` liste les bases de la mission avec
  leurs fréquences DCS, propose-les à l'utilisateur (une radio tient une vingtaine de canaux), puis
  `set_airfield_channels` écrit celles retenues dans la collection `bases` ; place-les ensuite dans
  les `channel_lists`.
- **Les canaux qui ne sont pas des aérodromes se choisissent hors de la bande des tours** (AWACS,
  ravitailleurs, porte-avions, patrouilles). Relève d'abord la bande qu'occupent les tours du
  théâtre — `describe_airfield_channels` les donne toutes — et place le reste en dehors : sur le
  Caucase elles prennent **250.0 à 270.0 sans un seul trou**, une par MHz, et y poser un ravitailleur
  crée un doublon que rien ne signale. Mesuré le 01/10/2026 : huit canaux VEAF vivaient dans cette
  bande, invisibles tant que les canaux de base portaient une série inventée ; avec les vraies
  fréquences, quatre se sont retrouvés en doublon, dont Magic 1 et Nalchik sur 265.0 **aux canaux 2
  et 16 de la même radio** — un pilote qui passait sur Nalchik se retrouvait sur l'AWACS. Garde la
  mnémonique quand il y en a une (le TACAN 51Y du ravitailleur Arco 1 donne 291.0).
- **Vérifie ensuite qu'aucune fréquence n'apparaît deux fois** dans une même liste de canaux, et
  qu'aucun canal non-aérodrome ne tombe sur une tour du théâtre. C'est ce contrôle qui manquait.
- **`src/versions.yaml` à réécrire** : position = base mère, fuseau, `base_date` d'époque ; variantes
  nuit / aube / matin / jour / soir × réel (`airport_icao`) / dégagé (`clearsky`) / épars / pluie.
- **`src/waypoints.yaml`** : retire les exemples du gabarit ; un plan par catégorie et par camp jouable,
  avec le bullseye.

### 4.11 Modules

`COMBATZONE`, `QRA`, `COMBATMISSION` (CAP, missions scénarisées), `ASSETS`, `MOVE`, `CTLD`, `CSAR`,
`AIEN`, `STTS`, et **`SKYNET` avec le réseau de guetteurs** (`spotter_network: true`, vue F10 désactivée :
`spotter_view: "off"`, ni affichage ni interrupteur radio). Selon les options retenues : `SANCTUARY`
(4.1), `CARRIER` (4.3). Un son cité dans les réglages CSAR / CTLD doit exister dans la mission.

### 4.12 Missions scénarisées (option, 1 à 3)

Des scénarios à déclencher par menu radio, au-delà des CAP (module `COMBATMISSION`). Exemples qui
ont marché :
- **défendre une base** : une vague d'attaque (SEAD puis bombardiers) vers une base amie, mission
  ratée si des bâtiments nommés de la base sont détruits ;
- **vague de bombardiers chronométrée** : une formation à abattre en un temps donné ;
- **intercepter un transport VIP escorté** entre deux bases ennemies ;
- **protéger un avion de soutien** (ELINT, transport) le long de sa route.

`combat_missions:` de `mission.yaml` ne porte que les éléments et leurs groupes : **ni objectifs**
(temps limité, bâtiments à protéger, taux de pertes), **ni niveau des pilotes**. Une mission qui en a
besoin s'écrit en Lua (`VeafCombatMission`) dans `src/scripts/mission-script.lua`, et tu le notes
dans « Retours pour VMCT ».

### 4.13 Carte du briefing et dessins F10

Un pilote qui découvre la mission doit voir le théâtre d'un coup d'œil, puis pouvoir lire le détail
de la zone où il va. **Une carte générale et des zooms, deux usages** : `docs/carte.jpg` en tête du
README et les zooms dans `docs/cartes/`, **chacun dans la section du README qu'il illustre** ; les mêmes
images dans le briefing de la mission, la carte générale d'abord.

- **Générée depuis les données de la mission, jamais dessinée à la main** : un script lit
  `src/mission/`, `mission.yaml` et les fichiers de `src/`, convertit les x/y en lat/lon
  (`resolve_coordinates`, ou `veaf_libs.coordinates`), et la redessine à chaque changement.
- **Ce qu'elle montre** : les bases avec slots (couleur du camp), les FARP, les hippodromes des
  ravitailleurs et des AWACS, les CAP à la demande, les cercles des QRA à leur rayon réel, les zones
  de combat **numérotées comme dans le briefing**, les zones d'entraînement (une lettre par
  famille), les sanctuaires, la ligne de front (dite approximative), le porte-avions, le bullseye.
  Ce qui sort du cadre (une arène au loin) est signalé par une flèche en bordure. Plus une légende,
  une échelle en nautiques et le titre de la mission.
- **Les zooms** : moins de dix, un par zone du théâtre (un groupe de bases, un secteur du front, les
  abords d'une capitale, l'arène). Le panneau de briefing de DCS **ajuste chaque image à sa taille** :
  la carte générale y devient illisible, c'est le zoom qui se lit. Chaque zoom porte **un titre** qui
  nomme la zone et ce qu'elle contient (« Front nord : Lübtheen, Ludwigslust, Parchim »). Il se
  déclare par la **liste des objets à cadrer** — le cadre en découle, rayons compris (un cercle de
  QRA entier), avec une marge — jamais par des coordonnées tapées. Les tuiles viennent du niveau de
  zoom OpenStreetMap le plus proche de la résolution de sortie, pour que les noms de lieux restent
  lisibles. Ce qui s'y ajoute : le **nom de chaque zone de combat à côté de son numéro**, l'étendue de
  la zone de sauvetage, le cercle de l'arène, le nom des lignes qui traversent le cadre (front,
  sanctuaire), une échelle ronde lue au centre. Un zoom ne recopie pas la légende.
- **Fond de carte** : les tuiles OpenStreetMap conviennent, à condition de suivre leur politique
  d'usage. Un `User-Agent` qui identifie l'outil par son URL, **jamais une donnée personnelle**
  (pas d'e-mail). Les tuiles en cache local, pour ne pas les retélécharger à chaque rendu. La mention
  « © OpenStreetMap contributors » sur l'image.
- **Images de briefing DCS** : les mêmes cartes en JPEG d'environ 1600 px de large (compte
  environ 0,5 Mo par image dans le `.miz`). Elles sont copiées dans `src/mission/l10n/DEFAULT/`,
  déclarées dans `mapResource`, et listées, carte générale en tête, dans **`pictureFileNameB` et
  `pictureFileNameN` seulement ; `pictureFileNameR` reste vide**. Quand DCS ne connaît pas le camp du
  joueur — slot `Client`, slot dynamique, spectateur — il affiche la liste rouge puis la bleue : une
  image présente dans les deux s'affiche deux fois (`describe_known_limitations`,
  `briefing-pictures-red-then-blue`). Le prix : un pilote rouge que DCS identifie peut n'avoir aucune
  carte (en multijoueur, à confirmer) ; ne le paie que si les slots rouges classiques n'en ont pas besoin
  (l'arène), et dis-le. Le script qui dessine les cartes **écrit lui-même ces listes et
  `mapResource`**, et retire les images qu'il ne dessine plus : la mission liste toujours ce qui a été
  dessiné. Si le MCP n'a pas d'action pour le faire, note-le dans « Retours pour VMCT ».
- **Dessins F10** (`add_map_drawing`, pour qu'ils survivent au build) : la ligne de front, les
  sanctuaires, les hippodromes de soutien, et **chaque zone avec son contour autant qu'avec son
  nom** — un cercle au rayon réel pour chaque zone de combat, chaque zone d'entraînement et chaque
  QRA, plus son étiquette. Une zone réduite à un nom posé au centre ne dit pas où elle commence :
  l'Open Training Caucase de septembre 2026 avait 38 dessins, 10 traits et 28 étiquettes, **pas un
  seul contour**. Chacun sur la **couche du camp qui doit le voir** (`Blue`, `Red`, ou `Common` pour
  ce que les deux partagent).
- **Lisibilité d'une étiquette F10** : donne-lui un `fill_color` **opaque et clair**. Sans lui,
  l'action applique son fond par défaut — `0x00000080`, noir à moitié transparent — et le texte,
  qui porte la couleur sombre de son camp, devient illisible sur la carte. Signalé en vol sur le
  Caucase le 29/09/2026.
- **Relis chaque image** avant de la livrer, zooms compris : aucune étiquette ne doit en chevaucher
  une autre, chaque numéro de zone doit correspondre à celui du briefing, et un trait en tirets doit
  rester en tirets sur les petits cercles.

## 5. Ordre de construction

1. `scaffold_mission` dans le dossier vide.
2. Mesure du front et plan chiffré (bases, soutien, zones, QRA, CAP), **présenté à l'utilisateur**
   avant de construire.
3. `mission.yaml` : identité, sécurité et profils, modules.
4. Aérodromes et FARP (4.1), soutien (4.3-4.4), défense aérienne (4.5).
5. Zones d'entraînement (4.6), vraies zones (4.7), QRA (4.8), CAP (4.9), missions scénarisées
   (4.12).
6. Radio, météo, waypoints (4.10) ; date, bullseye, briefing ; carte du briefing et dessins F10
   (4.13).
7. `validate_mission`, `build_mission` (et le profil `LOCAL_TEST`), puis la section 8.
8. **`README.md` = le briefing des pilotes**, en français, un seul fichier, **généré depuis la mission** par
   un script (comme la carte), jamais tapé : situation, carte, bases (fréquences, TACAN), défense
   aérienne permanente, soutien, porte-avions, drones, entraînement par famille, zones de combat par type
   avec le briefing de chacune, missions scénarisées, QRA, CAP, combat entre joueurs et arène, plan radio
   bleu et rouge, météo et heures, commandes utiles ; puis « Pour les créateurs de mission » :
   construire, fichiers, régénérer ce document, limites connues.
9. **Mission de test locale** (section 8).

Point d'étape bref après chaque étape : ce qui est fait, pas ce que tu t'apprêtes à faire.

## 6. Ce que tu rends à la fin

- Un résumé par rubrique (bases, soutien, défense, zones, QRA, CAP, météo).
- Le tableau repris / adapté / écarté / inconnu si une mission a servi d'inspiration.
- **Ce que tu as vérifié, et ce que tu n'as pas pu vérifier** (tout ce qui demande DCS).
- Le bloc **« Retours pour VMCT »**.
- Des **points ouverts numérotés**, avec ta reco pour chacun.

## 7. Ce qui revient à l'utilisateur

Commit, push, publication ; supprimer un élément « inconnu » d'une mission d'inspiration ; changer
l'époque ou les camps ; lancer DCS.

## 8. Vérification avant de dire « c'est prêt »

- **Lis tout le journal du build**, pas seulement le code de sortie : presets injectés dans combien
  d'appareils, waypoints dans combien de groupes, liens des warehouses, nombre de variantes,
  avertissements. Tout zéro est suspect.
- **Ouvre le `.miz` produit** (un zip ; `mission` et `warehouses` sont des tables Lua) et contrôle :
  - noms de groupes et d'unités **uniques** ;
  - slots dynamiques sur les seules bases voulues ;
  - tâches des ravitailleurs et des AWACS ;
  - structure des avions (altitude > 0, carburant, emport), des statiques (`category`), des navires ;
  - routes des convois ;
  - zones, QRA et CAP dans `veaf-config.lua` ;
  - chaque nom de `modules.ASSETS` (et son escorte `linked`) désigne un groupe qui existe : un nom
    sans groupe donne un menu vide, sans erreur ;
  - chaque porteur `#veafInterpreter` est du type du lanceur que génère son alias (sinon l'éditeur
    montre le cercle de portée d'une autre arme) ;
  - aucune défense permanente à portée d'une base adverse avec slots (4.5) : le tableau des
    distances ;
  - `requiredModules` vide (4.2) ;
  - deux variantes météo **différentes dans les champs que DCS lit** (`clouds.preset`,
    `season.temperature`, `wind.atGround`), et l'heure de l'aube cohérente avec le lever du soleil ;
  - le profil `LOCAL_TEST` construit sans sécurité, la configuration par défaut avec ;
  - les images de briefing présentes dans le `.miz`, listées dans `pictureFileNameB` et
    `pictureFileNameN`, `pictureFileNameR` vide (4.13).
- **Relis tes briefings** : chaque distance, cap, altitude et nom de lieu recalculé ou sourcé.
- **Livre une mission de test locale**, copie du build `LOCAL_TEST` (jamais dans les sources) avec : un
  **game master** bleu et un rouge ; un **slot `Client` classique d'A-10C II, au sol moteur chaud** à la
  base mère — les slots dynamiques ne fonctionnent qu'en multijoueur, une mission de test qui n'a qu'eux
  est inutilisable en solo ; le déclencheur du pont dcs-bridge (`veaf-tools dcs inject-bridge`). C'est
  toi qui lances `dcs-serve` ; l'utilisateur ne s'occupe que de DCS et du slot. Une sonde par le pont
  mesure ensuite ce que le `.miz` ne dit pas : imbrication des niveaux (chaque niveau fait apparaître
  plus que celui qu'il inclut), cibles à leur place, convois qui roulent, CAP qui engagent.
- Liste ce qui reste à vérifier dans DCS (placement des statiques sur les terrains, suivi des routes
  par les convois, imbrication des zones, apparence du ciel, **et les dessins de la carte F10**). Les
  images de briefing se relisent au rendu ; un dessin F10 ne se voit **qu'en jeu**, et il est passé
  entre ces deux mailles sur le Caucase — contours absents et étiquettes illisibles ont tenu jusqu'à
  ce qu'un pilote les signale en vol.
