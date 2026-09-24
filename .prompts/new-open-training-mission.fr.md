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
- **FARP** : une bonne pratique à généraliser — un FARP bleu près du front et près de chaque zone
  destinée aux hélicoptères (réarmement, CTLD, CSAR). Si le MCP ne sait pas en poser, signale-le.
- `set_airbase_coalition` pour chaque aérodrome, avec `dynamic_spawn: false` sur ceux qui ne doivent
  pas offrir de slots. `src/warehouses.yaml` : carburant et munitions illimités, départ moteur chaud.
  `src/dynamic-slot-templates.yaml` : modèles des deux coalitions qui ont des slots.

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
  hachages de mot de passe, ou si le niveau des pilotes du serveur suffit.
- **Deux usages, deux configurations** dans `mission.yaml` :
  - **par défaut** = serveur : sécurité active, logs `info`, toutes les variantes météo ;
  - **profil `LOCAL_TEST`** (`veaf-tools mission build --profile LOCAL_TEST`) : sécurité désactivée,
    logs `debug`, noms des groupes lisibles (`hide_names_from_spawned_groups: false`), pas de
    variantes météo (`pipeline.weather: false`), et ce qui rend un test local plus rapide.
- **Date et heure** de mission : `set_mission_date`.
- **Bullseye** (`set_bullseye`) : un **repère que les pilotes peuvent nommer**, au centre du front, le
  même pour les deux camps.
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
3. **SEAD / DEAD** : **loin de tout** (bases, pistes de ravitailleurs, autres zones), pour que les
   équipages s'y entraînent tranquilles. Facile = une batterie moyenne portée seule ; moyen =
   moyenne + courte portée ; difficile = longue portée, moyenne, courte et EWR, en réseau Skynet.

**Graduer la difficulté avec `defense N`.** Les commandes de spawn de groupes (`_spawn samgroup`,
`armorgroup`, `combatgroup`, `transportgroup`, `convoy`…) acceptent `defense 0` à `5`, qui choisit
une batterie antiaérienne type de plus en plus forte (AAA à 0, SAM courte portée IR puis radar vers le
haut). Tu peux donc écrire un même porteur à chaque niveau avec une valeur croissante :
`#command="_spawn samgroup, defense 1"` / `… defense 3` / `… defense 5`. Les niveaux suivent
`mission.era`. Deux précautions :
- le tirage **ajoute un aléa** (un niveau de plus ou de moins de temps en temps) ;
- **vérifie la composition de chaque niveau** pour l'époque de la mission (`list_shortcuts`) avant de
  t'y fier ; si elle ne convient pas, prends des alias explicites.

Les statiques sont la seule façon d'avoir une cible **vraiment inerte** (un blindé réel tire à la
mitrailleuse sur un hélicoptère ; aucune balise ne met une unité en « feu interdit »).
`training: true`, un menu radio par famille.

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
  antiaérienne dans le même groupe.
- **Portée des SAM des zones actives** : aucun ne doit atteindre une base amie, une piste de
  ravitailleur ou une zone d'entraînement.
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
  rouge vole. L'ATC étant coupé, les fréquences de base sont des fréquences de trafic de la mission.
- **`src/versions.yaml` à réécrire** : position = base mère, fuseau, `base_date` d'époque ; variantes
  nuit / aube / matin / jour / soir × réel (`airport_icao`) / dégagé (`clearsky`) / épars / pluie.
- **`src/waypoints.yaml`** : retire les exemples du gabarit ; un plan par catégorie et par camp jouable,
  avec le bullseye.

### 4.11 Modules

`COMBATZONE`, `QRA`, `COMBATMISSION` (CAP), `ASSETS`, `MOVE`, `CTLD`, `CSAR`, `AIEN`, `STTS`,
et **`SKYNET` avec le réseau de guetteurs** (`spotter_network: true`, vue F10 réglable par menu
radio). Un son cité dans les réglages CSAR / CTLD doit exister dans la mission.

## 5. Ordre de construction

1. `scaffold_mission` dans le dossier vide.
2. Mesure du front et plan chiffré (bases, soutien, zones, QRA, CAP), **présenté à l'utilisateur**
   avant de construire.
3. `mission.yaml` : identité, sécurité et profils, modules.
4. Aérodromes et FARP (4.1), soutien (4.3-4.4), défense aérienne (4.5).
5. Zones d'entraînement (4.6), vraies zones (4.7), QRA (4.8), CAP (4.9).
6. Radio, météo, waypoints (4.10) ; date, bullseye, briefing.
7. `validate_mission`, `build_mission` (et le profil `LOCAL_TEST`), puis la section 8.
8. `README.md` + `readme.fr.md` : contenu, construction, fichiers, limites connues.

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
  - deux variantes météo **différentes dans les champs que DCS lit** (`clouds.preset`,
    `season.temperature`, `wind.atGround`), et l'heure de l'aube cohérente avec le lever du soleil ;
  - le profil `LOCAL_TEST` construit sans sécurité, la configuration par défaut avec.
- **Relis tes briefings** : chaque distance, cap, altitude et nom de lieu recalculé ou sourcé.
- Liste ce qui reste à vérifier dans DCS (placement des statiques sur les terrains, suivi des routes
  par les convois, imbrication des zones, apparence du ciel).
