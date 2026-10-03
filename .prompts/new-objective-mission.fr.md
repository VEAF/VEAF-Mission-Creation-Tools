# Prompt — construire une mission VEAF à objectifs, à jouer en une séance

> À coller tel quel au début d'une nouvelle session Claude Code, dans un **dossier vide** qui sera
> le dossier de la mission.

---

Tu vas concevoir puis construire **de zéro** une mission VEAF **à objectifs** pour DCS World, avec
les outils VEAF Mission Creation Tools v6 (`veaf-tools`) et le serveur MCP `veaf-mission-mcp`
(plugin Claude `veaf-mission-editor`).

Ce n'est **pas** une Open Training. Une mission à objectifs se joue **une fois**, en **une séance**,
par un groupe de pilotes qui partent ensemble : un scénario, un ou plusieurs objectifs, un départ,
une menace, un retour. Elle est jetable : pas de variantes météo, pas de zones à la carte, pas
d'infrastructure de théâtre. Ce qui compte, c'est que le scénario tienne debout, qu'il se joue dans le
temps de la séance, et que **tout ce que les pilotes lisent au briefing soit juste**.

Le travail a **deux phases**, et la frontière entre les deux est stricte :

1. **Le scénario** (section 2) : tu proposes, l'utilisateur discute, demande d'autres scénarios
   autant qu'il veut, pose ses questions, demande un pré-briefing. **Aucun fichier n'est écrit.**
2. **La génération** (sections 4 à 7) : seulement après une **validation explicite** d'un scénario.
   Tu construis la mission et le fichier de briefing.

## 0. Avant tout

1. **Charge le skill `veaf-mission-editor:veaf-mission-authoring`** et suis-le : il est la source de
   vérité pour les conventions VEAF (noms réservés, `#command`, `#veafInterpreter`, zones, QRA).
2. Appelle `capabilities` et `list_catalog` : note la version de `veaf-tools` et les actions
   disponibles. Lis les **limitations connues** (`describe_known_limitations`) et tiens-en compte
   dès le scénario : ne propose pas ce que les outils ou DCS ne savent pas faire.
3. **Ce qui manque ou ne marche pas dans les outils, tu le signales.** Une action absente, un
   résultat faux, une doc qui dit autre chose que le comportement : tu contournes proprement pour
   avancer, et tu le notes dans un bloc **« Retours pour VMCT »** de ton rapport final (quoi, où,
   comment tu l'as vu, ce que tu as fait à la place). C'est ainsi qu'on améliore les outils.
4. Réponds en français, concis. Pose tes questions **une par une**, avec des choix et ta reco.
5. **Lire sans dossier de mission.** En phase 1 le dossier est vide, et `geocode` comme
   `resolve_coordinates` exigent un `mission_path` (ils ne prennent pas de théâtre). Pointe-les, en
   lecture seule, sur une mission existante du même théâtre (une Open Training, par exemple) ; ne
   crée rien pour ça.

## 1. Les questions de départ (et seulement celles-là)

Une par une. L'utilisateur peut répondre « peu importe » ou « surprends-moi » à chacune : tu choisis
alors, et tu le dis.

1. **La carte** (un théâtre supporté par `scaffold_mission`).
2. **Les appareils joués et le nombre de pilotes** : quels types, combien de chaque, avions et/ou
   hélicoptères. C'est ce qui décide des objectifs possibles, des bases de départ et des distances.
   Demande aussi **le mode de slots** : des slots nommés (un groupe par vol de l'ATO, section 4.3) ou
   des **slots dynamiques** sur les bases de départ (placement libre). Avec des slots dynamiques,
   demande l'ordre de grandeur du public (types, nombre de pilotes) : c'est lui qui dimensionne la
   menace et les places de parking.
3. **La durée de la séance** : le temps de vol disponible, briefing non compris. Reco : 2 h ; c'est
   le budget dans lequel tout le profil de vol doit tenir.
4. **Le genre de mission**, s'il en a une envie : frappe dans la profondeur, appui feu (CAS), SEAD /
   DEAD, antinavire, escorte, interception, héliportage / CSAR, ou un mélange. Et l'**époque** si elle
   ne découle pas des appareils.

Tout le reste — lieu, objectifs, menace, heure, météo, soutien — c'est **toi** qui le proposes, dans
le scénario.

**L'ATO nomme ses vols avec les indicatifs standard VEAF.** Leur fréquence est dans le catalogue des
outils (`presets_injector/freq_alias.py`, et `presets.yaml` du gabarit) ; leur appareil n'y est pas.
Ceux qu'on connaît :

| Indicatif | Appareil |
|---|---|
| Archer | A-10C |
| Arctic | F/A-18C |
| Ninja | F-16C |
| Pinder | Mirage 2000 |
| Bengal | F-15 (E pour une frappe) |
| Blade | hélicoptères |

Pour un autre indicatif du catalogue (Astro, Nickel, Nitro, Gordon…), demande le type : ne le devine
pas.

## 2. Phase 1 — proposer un scénario

### 2.1 Ce qu'un scénario doit être

- **Plausible** : des lieux **réels** de la carte (`geocode`, `list_airfields`, `describe_map` —
  affiche ce que tu as trouvé), des cibles qui ont un sens à cet endroit et à cette époque, une
  menace d'époque cohérente avec ce qu'elle protège (`list_shortcuts`, `list_unit_types` ; **lis ce
  qu'un alias pose réellement**, pas sa description).
- **Jouable dans la séance** : mesure les distances (base → objectif → retour, ravitaillement compris)
  et **calcule** le temps de vol à la vitesse de croisière du type le plus lent du package. Le total,
  temps sur l'objectif compris, tient dans la durée de la question 1.3, avec une marge. Cette vitesse
  est une **estimation** : dis-la comme telle.
- **Faisable avec les outils** : tout ce que le scénario promet doit pouvoir se construire (section
  4). Ce qui dépend d'un réglage que tu n'as pas vérifié se dit « à vérifier », pas « prévu ».
- **Des bases qui accueillent le public.** Compte les places de parking de chaque base de départ
  dans `veaf_libs/data/parking/<théâtre>.json` (champ `t` de chaque place : de mémoire de l'API DCS
  `Airbase.getParking`, 68 abri durci, 72 avion, 104 plein air, 40 hélicoptère, 16 piste — à
  confirmer) et compare-les au nombre de pilotes. Une base trop petite refuse les slots dynamiques en
  silence côté joueur (« Can't create dynamic group, no suitable parking was found » dans le journal
  serveur) : mesuré sur Syria, At Tanf n'a que **2 hélisurfaces** et H4 environ 13 places avions.
  Prévois une FARP (`add_farp`) pour les hélicoptères ou une seconde base pour les jets.
- **Un convoi sur une vraie route.** Pose son départ et ses points **sur** la route, vérifiée sur le
  fond de carte : un convoi posé à côté va d'abord chercher la route la plus proche. Sa durée de
  trajet (longueur ÷ vitesse) doit tenir dans la séance.
- **Une zone à défendre, peuplée.** Si l'enjeu est un site ami (une garnison, une ville), pose-y des
  unités amies : assez pour qu'on ait envie de le défendre, **trop peu pour qu'il tienne seul** face à
  l'attaquant (pas de char face à des chars, par exemple). Et la route de l'attaquant doit **arriver
  au contact**, pas s'arrêter hors de portée.
- **Lisible en un coup d'œil** : un pitch qui se raconte en deux phrases.

Les actions de lecture (`geocode`, `list_airfields`, `describe_map`, `list_shortcuts`,
`list_unit_types`, `resolve_coordinates`, `terrain_elevation`, `describe_known_limitations`) sont
permises en phase 1.
**Aucune action qui écrit** : ni `scaffold_mission`, ni fichier, ni dossier.

### 2.2 La fiche de scénario

Chaque proposition porte un **numéro** (Scénario 1, 2, 3…) pour que l'utilisateur puisse y revenir
ou en combiner deux (« le 2, mais avec le départ du 1 »). Elle tient **en un écran**, en texte
formaté, sans image :

```
### Scénario N — <titre>

> <pitch : le contexte et l'enjeu, en deux phrases>

| | |
|---|---|
| Carte, époque | … |
| Date, heure | … (jour / nuit, et pourquoi) |
| Météo | … en une ligne |
| Départ | base ou porte-avions, type de départ |
| Package | qui vole quoi (d'après la question 1.2) |
| Soutien | ravitailleurs, AWACS / GCI, ou rien |

**Objectifs**
1. <objectif principal> — <lieu>, <ce qu'il faut détruire / faire>
2. … (objectifs secondaires signalés comme tels)

**Menace** : sol (grandes familles, sans chiffre de portée non sourcé) ; air (rien, QRA, CAP).

**Profil** : <itinéraire en une ligne> — ≈ <distance> nm aller, ≈ <durée> de vol au total (estimation
à <vitesse> kt).

**Ce qui fait l'intérêt** : <la difficulté, le choix tactique, ce que le groupe va devoir faire>

**À vérifier** : <ce qui dépend des outils ou de DCS et que tu n'as pas pu confirmer> (omis si rien)
```

Termine par une ligne : « Un autre scénario, des détails, le pré-briefing, ou on valide ? »

### 2.3 Itérer

- **Un nouveau scénario est vraiment différent** — autre objectif, autre lieu ou autre profil — sauf
  si l'utilisateur demande une variante (« le même, plus court »).
- **Les questions** sur un scénario reçoivent une réponse directe, sourcée quand c'est un fait
  (distance mesurée, type d'unité vérifié). Une réponse qui change le scénario en fait une nouvelle
  version : « Scénario 2 bis ».
- Il n'y a **pas de limite** au nombre de scénarios. Ne pousse pas vers la validation.

### 2.4 Le pré-briefing, sur demande

Quand l'utilisateur le demande, tu rédiges **dans la conversation** (pas de fichier) le briefing du
scénario, dans la structure du modèle VEAF de la section 3. Mêmes rubriques, même ordre, en Markdown :
titres, tableaux pour l'ATO et le plan de fréquences, listes à puces. **Pas d'image** : la rubrique
« Situation tactique » devient une description de la géographie, un élément par ligne, avec son
relèvement et sa distance depuis le bullseye.

Les **coordonnées** des cibles et les **fréquences** y sont **provisoires** (calculées depuis
`geocode`) et marquées comme telles : les vraies viennent de la mission construite (section 6).

### 2.5 La validation

La phase 2 ne commence que sur une **validation explicite** d'un scénario identifié : « je valide le
3 », « go pour le 2 bis ». Une question, un « pas mal » ou un pré-briefing demandé ne valent pas
validation. Au moment de valider, demande seulement ce qui manque encore :

- le **format du briefing** : en pratique, VEAF le partage en **Google Slides dans un Google Drive**.
  Le script génère un PPTX, que Drive convertit en Slides à l'import ; s'il y a un connecteur Google
  Drive, propose de l'y déposer, converti, dans le dossier que l'utilisateur indique (c'est une
  publication : demande son accord). Un PDF en plus si on veut diffuser un fichier figé ;
- les **noms des pilotes** pour l'ATO, s'il les a (sinon les cases restent vides, comme dans le
  modèle).

## 3. Le modèle de briefing VEAF

C'est le format des briefings de mission VEAF (référence : *Deep Strike Palmyra*). Une page par
rubrique, en 16:9, fond blanc, **titre en gras en haut à gauche**, texte aligné à gauche — **jamais
justifié** : dans le modèle, une ligne justifiée étale « Départ : USS Truman, Case 1, Beyrouth » sur
toute la largeur et devient illisible.

1. **Couverture** — le titre de la mission en très gros à gauche ; à droite, le sommaire (Situation
   générale, ATO, Situation tactique, Plan de vol), liens vers les pages.
2. **Situation générale** — rubriques en gras, chacune suivie de son texte :
   - **Contexte** : le pourquoi, en deux ou trois phrases, et le principe de l'itinéraire ;
   - **Mission** : trois à cinq puces à l'infinitif (s'infiltrer, détruire, s'exfiltrer…) ;
   - **Bullseye** : où il est (un point que les pilotes peuvent nommer, ou un waypoint) ;
   - **Départ** : base ou porte-avions, type de départ (Case I, moteur froid…) ;
   - **Menace** : les familles de défenses (AAA, SA-8, SA-15…) ;
   - **Météo** : nuages, visibilité, vent (direction et force), turbulence, lune la nuit ;
   - **Horaire** : l'heure de mission.
3. **ATO** — sous le titre **PACKAGE**, un cadre par vol : indicatif (en bleu), nom de vol, type
   d'appareil ; la base en italique dessous ; quatre lignes numérotées 1 à 4 pour les pilotes ; une
   colonne d'emport (« Armement libre » ou l'emport imposé). À droite, les **moyens de soutien**
   (indicatif en bordeaux, rôle, type : ravitailleurs, AWACS) et le **contrôle** (GCI / ATC).
4. **Situation tactique** — la carte générale : départ, itinéraire, points nommés (START, INGRESS,
   EGRESS), objectifs, menaces connues avec leur cercle.
5. **Situation tactique WPn** — une page par objectif, un zoom de plus en plus serré sur la cible : le
   site, ses bâtiments, ses défenses proches.
6. **Déroulement mission** — **Objectifs principaux** (liste), **Opposition aérienne** (ce qu'on sait,
   ce qui peut décoller et quand), **Défenses antiaériennes** (et comment l'itinéraire les évite),
   **Autres informations** (mode d'attaque conseillé, ravitaillement au retour, terrain de
   dégagement).
7. **Plan de vol** — un waypoint par ligne avec son rôle : `W1 : Hold`, `W2 : Insertion TBA`, …,
   `W6 : IP`, `W7 (Bullseye) : Target …`, `W8 : Egress Point`.
8. **Plan de fréquences** — UHF puis VHF : `<nom> Ch. <n> : <fréquence> MHz`, Garde en tête.
9. **Coordonnées cibles** — le format annoncé en tête (« Lat Long secondes, précis »), puis une ligne
   par cible : `<nom> : N34°33'37.31" E38°18'48.77" <altitude> ft`.

## 4. Phase 2 — conception de la mission

Avant de construire, rends **le plan en une liste** (dossier, gabarit, slots, objectifs, menaces,
soutien, route) et commence sans attendre de nouvelle validation. **Si un point du scénario validé
ne peut pas se construire tel quel, arrête-toi et dis-le** avant de t'en écarter : l'utilisateur a
validé un scénario, pas un à-peu-près.

### 4.1 Méthode

- **Rien de mémoire.** Types d'unités → `list_unit_types` ; alias → `list_shortcuts` ; lieux →
  `geocode` ; coordonnées → `resolve_coordinates`. Un chiffre de briefing se **calcule** ; une
  enveloppe d'arme ne s'écrit que si elle est sourcée.
- **Travaille dans le dossier** (`src/mission/` + `mission.yaml`), pas dans un `.miz`.
- **Relis ce que chaque action écrit**, au moins une fois par type d'action et de catégorie (avion,
  véhicule, statique, navire) : un fichier valide peut produire des unités qui ne marchent pas.
- Si tu dois modifier `src/mission/mission` sans action dédiée : script qui charge la table Lua, la
  modifie et la réécrit — jamais de remplacement de texte — et tu le notes dans « Retours pour VMCT ».
- **Arrête-toi avant tout commit / push** et demande le feu vert.

### 4.2 Identité

- **Gabarit** de `scaffold_mission` : `minimal` pour une mission sans hélicoptère ni logistique ;
  `standard` si le scénario utilise CTLD, CSAR ou des missions de transport. Tu choisis et tu
  l'annonces. Désactive les modules du gabarit dont le scénario ne se sert pas. Avec CTLD, règle
  `modules.CTLD.airbase_logistics_radius` (250 m par défaut, une valeur pour tous les terrains) sur le
  plus grand terrain d'où partent les transports — 1 100 m pour une grande base comme Ramstein, où un
  C-130 se gare à 997 m du point de chargement.
- **Nom** : `VEAF_<Carte>_<Titre>` (titre en PascalCase sans accents, ex.
  `VEAF_Syria_DeepStrikePalmyra`).
- `mission.era`, **date** et **heure** (`set_mission_date`) cohérentes avec le scénario. Si le
  scénario dit « pleine lune » ou « nuit sans lune », **choisis la date d'après une éphéméride
  sourcée**, pas de mémoire.
- **Météo** : une seule, celle du scénario (`set_weather`). Pas de variantes : `pipeline.weather:
  false` (et retire alors `src/versions.yaml`, que le build signale orphelin), ou un
  `src/versions.yaml` à une seule version. Une visibilité **≥ 9 000 m est écrite 80 km** (règle du
  « 9999 » METAR) : pour une brume, demande 8 000 m au plus.
- **Langue** : `mission.language: fr` et briefing en français, sauf mention contraire.
- `silence_atc_on_all_airbases: true`.
- **Sécurité active par défaut** (la mission tourne sur les serveurs VEAF) ; demande s'il faut des
  hachages de mot de passe. **Jamais un mot de passe en clair**, même en commentaire. Un **profil
  `LOCAL_TEST`** : sécurité désactivée, logs `debug`, noms de groupes lisibles
  (`hide_names_from_spawned_groups: false`). Les deux profils écrivent **le même nom de `.miz`** :
  renomme le premier avant de construire le second, ou passe par un script de build.
- **Slot Game Master** s'il est demandé : `groundControl.roles.instructor` de la table de mission
  (aucune action ne le règle : script qui charge et réécrit la table, à noter aux retours VMCT ;
  qu'il apparaisse sans Combined Arms est à vérifier en jeu). Un **slot de test** fixe (un appareil
  en vol près de l'objectif) ne va que dans le `.miz` `LOCAL_TEST` — retire-le du `.miz` serveur
  construit avec `remove_group` — ou nulle part.
- **Aucun mod exigé** : `requiredModules` reste vide, sauf demande explicite.
- **Bullseye** (`set_bullseye`) : celui du scénario, le même pour les deux camps.

### 4.3 Les vols joueurs

- **Un groupe par vol de l'ATO**, au nom de son indicatif (`ARCHER`, `NINJA`…), **autant de slots
  que de places du cadre ATO** (quatre par défaut), skill `Client`, au **départ du scénario** :
  parking moteur froid par défaut (`add_air_group` ou `add_player_slot`, `ground-cold`), pont du
  porte-avions (`add_air_group`, `start: deck-cold` ou `deck-hot`, `carrier` = l'unité que rend
  `add_carrier_group`), en vol seulement si le scénario le dit.
- **Slots nommés ou dynamiques, selon la réponse à la question 1.2.**
  - *Nommés* : l'ATO nomme des vols, la mission les donne ; `dynamic_spawn: false` sur chaque
    aérodrome.
  - *Dynamiques* : `set_airbase_coalition` ouvre les slots des bases de départ (ferme ceux des bases
    ennemies avec `dynamic_spawn: false`), l'ATO garde les indicatifs avec des cases pilotes vides.
    Le catalogue livré offre **tous** les types bleus, warbirds compris : dis-le, et propose de le
    restreindre (`content pull-aircraft-groups`) si l'époque compte. Vérifie la capacité des bases
    (section 2.1).
- **Emport** : celui du scénario, ou un emport de base cohérent avec la mission si l'ATO dit
  « Armement libre » (les pilotes le changent au sol).
- **Plan de vol dans l'appareil** : il **est** le plan de vol du briefing, dans le même ordre et sous
  les mêmes noms. Dans DCS le point 0 est le départ : `W1` du briefing est le point d'index 1.
  Vérifie-le dans le `.miz`. Avec des slots nommés, c'est la route du groupe (`edit_route`) ou
  `src/waypoints.yaml` ; avec des slots dynamiques, **seulement `src/waypoints.yaml`** : le build
  ajoute ses points après le départ de chaque gabarit joueur (un plan par catégorie et coalition, un
  pour les jets, un pour les hélicoptères), puis un BULLSEYE.
- **Un point par objectif**, y compris le départ d'un convoi (`COLONNE`), sur le chemin du vol.
  Quand le plan change, renumérote partout : briefing, cartes, étiquettes F10.
- **Les waypoints sont au sol** : altitude `BARO` = sol DCS sous le point, lue par `terrain_elevation`
  (`points`), pour que chaque steerpoint porte les coordonnées du terrain. Déclare le **BULLSEYE**
  dans `waypoints.yaml`, au sol lui aussi : sinon le build en injecte un à 20 000 ft (un point déclaré
  sous ce nom remplace le sien). L'altitude de vol se dit au briefing, pas dans les points.
- **Profil bas (TBA)**, si le scénario en a un : `terrain_elevation` avec la `route` donne le sol le
  plus haut de chaque branche ; le briefing donne une altitude de branche au-dessus de ce maximum.
  Sol seulement — ni bâtiments, ni pylônes, ni arbres : garde une marge, et dis laquelle. Si le
  théâtre n'a pas de grille (`available: false`), l'altitude reste un point ouvert à vérifier en jeu.

### 4.4 Les objectifs

- **Un objectif = une zone de combat** (`create_combat_zone`), avec son `briefing`. La zone se
  termine quand ses unités et ses statiques rouges sont détruits : c'est ce qui dit qu'un objectif est
  atteint, et la zone l'annonce elle-même.
- **Les objectifs principaux sont regroupés dans une opération** : une entrée `type: operation` de
  `combat_zones[]`, avec un `tasking_orders` par objectif et **`active_at_start: true` sur
  l'opération seule** (pas sur ses zones : c'est elle qui les active). Quand le dernier objectif tombe,
  elle annonce « L'opération … est terminée » à tous : c'est le message de fin de mission, sans une
  ligne de Lua. Son menu F10 liste les objectifs qui restent. `dependencies` ordonne les tâches
  (« la tour après le radar ») : la suivante n'est donnée qu'une fois la précédente terminée.
- **Un objectif qui ne doit exister qu'après un autre** (renfort qui arrive, phase 2 révélée par la
  phase 1) : activer l'opération fait apparaître **toutes** ses zones d'un coup, les dépendances n'y
  changent rien. Cet objectif-là est un `chained_zones` de la zone qui le déclenche, avec
  `chained_delay` — et il ne compte pas dans la fin de l'opération : dis-le au briefing.
- **Une cible qui fait partie de la carte** (un pont, un bâtiment du décor) n'est pas une unité de la
  zone : elle ne compte que listée dans `scenery_targets` par son identifiant DCS. Cet identifiant
  n'existe que dans DCS : `offer_scenery_lookup` donne la commande que l'utilisateur lance pour
  l'obtenir (elle demande DCS), et tant qu'il ne l'a pas, l'objectif est un point ouvert — ou une
  statique posée à la place, si le scénario le permet.
- **Le réalisme d'abord** : sur une mission à objectifs, pas de fumigène ni de liste des unités à la
  demande, sauf si le scénario les prévoit (`smoke_and_flare: false`, `show_units_list: false`).
- **Cibles** : statiques pour bâtiments, dépôts, réservoirs, avions au sol (les seules **vraiment
  inertes**) ; groupes natifs pour ce qui vit ; un convoi = un groupe natif avec une route sur route
  (points 2+ « On Road »), sa défense dans le même groupe. **Noms d'unités uniques**, parlants.
- **Le nom d'unité d'une statique commence par le nom de la zone.** Pour une statique, la zone lit
  le nom de l'**unité**, pas celui du groupe : `Tanf-PC-CentreCommandement` (groupe) contenant
  « Centre de commandement » (unité) est **ignoré**, et l'objectif se termine sans lui. Le journal le
  dit au démarrage (`reportGroupsExcludedByName` : « … ont été ignorés »). Nomme l'unité
  `<Zone> Centre de commandement` ; le briefing garde le nom lisible.
- **Une batterie SAM-objectif = un groupe natif radar + lanceurs.** Les alias de groupe (`sa11`,
  `sa6`…) posent aussi des camions de logistique, qui comptent dans la fin de la zone. `add_group` et
  `create_combat_zone` alignent les unités tous les 20 m, cap 0 : disperse les lanceurs autour du
  radar (`set_unit_properties`, position et cap). Les groupes fixes d'une zone entrent dans Skynet.
- **Un convoi se crée avec sa route** (`create_combat_zone` ou `add_group` avec `route`, points 2+
  « On Road »). `edit_route` ajoute un point de véhicule en « Turning Point » et ne sait pas écrire
  « On Road » : pour changer la route, `remove_group` puis recrée le groupe.

### 4.5 La menace

- **Défense sol** : batteries permanentes via `#veafInterpreter["-<alias>, country <pays>, hdg
  <cap>"]` — **porteur = une unité de la classe générée** (le lanceur de l'alias), pour que
  l'éditeur montre le cercle de portée ; noms d'unités uniques (`… #<site>-01`). Ou des groupes natifs
  placés là où le scénario les met.
- **L'itinéraire du scénario doit exister vraiment.** S'il « passe sous la couverture » ou « entre
  deux sites », mesure la distance de chaque segment de la route à chaque batterie et compare-la à la
  portée de l'arme (sourcée, ou mesurée dans DCS ; sinon, le chiffre reste en point ouvert). Le
  masquage par le relief : `terrain_elevation` avec la `route` (altitudes et `alt_type` des
  waypoints) et les batteries en `observers` dit, branche par branche, combien de mètres chaque
  batterie voit dans sa portée. Mets ce tableau dans le briefing des défenses. Il ne compte que le
  relief : un bâtiment ou une forêt qui masque dans DCS n'y est pas, et la détection réelle reste à
  vérifier en jeu. Les waypoints étant au sol, calcule-le sur un profil d'altitude **supposé**, et
  dis lequel.
- **Portées connues**, avec leur source — ni `dcsUnits.yaml` ni Skynet n'en donnent :

  | Système | Tir | Détection | Source |
  |---|---|---|---|
  | SA-11 (Buk) | ≈ 25 nm | ≈ 45 nm (radar 9S18) | DCS, donnée d'un mission maker VEAF |
  | SA-6 (Kub) | ≈ 24 km | — | mesuré en jeu, `describe_known_limitations` |
  | SA-8 (Osa) | ≈ 10 km | — | idem |

  Pour un autre système, ne trace rien sans source : demande, ou mesure dans DCS. Sur les cartes,
  **tir et détection ont deux cercles différents**.
- **Le PUSH et l'EGRESS sont hors de tir de toutes les batteries**, avec une marge (3 km au moins),
  et le briefing dit **où** la route entre dans chaque enveloppe (« 5,4 nm avant l'IP ») : c'est là
  que les vols de frappe attendent le SEAD.
- **Opposition aérienne** : celle du scénario. « Ils pourraient faire décoller des chasseurs après la
  frappe » = une **QRA** (`create_qra`) sur la base ennemie, cercle dans le territoire rouge, avec
  `delay_before_activating` et `react_on_helicopters` décidés et écrits au briefing ; intercepteurs
  d'époque avec **emport** (`pylons`, `payload` par son nom via `list_payloads`, ou `loadout_from`),
  `airport_link` sur la base. Une patrouille
  déjà en vol = un groupe natif en orbite, pas une CAP à la demande. `delay_before_activating` compte
  **depuis le début de la mission**, pas depuis l'intrusion : la QRA décolle dès l'intrusion une fois
  en ligne. Écris-le ainsi au briefing (« en place à H+15 min »).
- **Radars d'alerte (EWR)** si le scénario parle d'être détecté, et **Skynet** si la défense doit
  réagir en réseau.

### 4.6 Soutien, radio, carte

- **Soutien** : seulement ce que le scénario cite. Ravitailleur : `add_air_group` (départ en vol),
  `edit_route` `add_task` : `orbit`, `tanker`, `activate_beacon` (TACAN Y), `set_unlimited_fuel`.
  AWACS : `awacs`, `eplrs`, `set_unlimited_fuel`, `orbit`. **Un nom partout** : nom de groupe =
  indicatif (Texaco, Shell, Overlord…) = libellé de preset = ligne du briefing ; déclaré dans
  `modules.ASSETS`. Relis l'indicatif radio DCS de l'unité : `add_air_group` le tire du nom pour un
  ravitailleur, mais a donné « Overlord » à un AWACS nommé Magic (`set_unit_properties`, famille 2 =
  Magic).
- **Porte-avions** si le départ est en mer : `add_carrier_group` (TACAN, ICLS, Link 4, ravitailleur
  embarqué, hélicoptère de sauvetage, entrepôt), module `CARRIER`. **Toujours deux porte-avions, le
  Stennis et le Roosevelt** (un `add_carrier_group` chacun, TACAN, ICLS, Link 4 et fréquences
  distincts) : décision de David du 02/10/2026, valable pour toute mission générée qui a un groupe
  aéronaval.
- **`src/presets.yaml` = le plan de fréquences du briefing**, canal pour canal : Garde, bases, porte-
  avions, AWACS, ravitailleurs, fréquence de package. Les **canaux de base portent les fréquences que
  DCS donne à l'aérodrome** : `describe_airfield_channels` puis `set_airfield_channels`, jamais une
  fréquence d'aérodrome tapée à la main. Réécris **toutes** les listes `channel_lists` du gabarit :
  sur une autre carte, il garde des aérodromes du Caucase (Batumi, Beslan…). Relis les préréglages
  réellement injectés dans le `.miz`, appareil par appareil. Le SA342 Gazelle n'en reçoit aucun
  (seule sa radio FM se règle par préréglage) : dis au briefing que ses radios se règlent à la main.
- **`src/waypoints.yaml`** : retire les exemples du gabarit.
- **Carte du briefing** : générée depuis les données de la mission par un script (x/y → lat/lon via
  `resolve_coordinates` ou `veaf_libs.coordinates`), jamais dessinée à la main. Une carte générale
  (départ, itinéraire et points nommés, objectifs, menaces connues à leur rayon, soutien, bullseye,
  légende, échelle en nautiques) et **un zoom par objectif**, cadré par la liste des objets à montrer.
  Fond OpenStreetMap avec un `User-Agent` qui identifie l'outil par son URL (**jamais une donnée
  personnelle**), tuiles en cache local, mention « © OpenStreetMap contributors ». **Ne montre que ce
  que le renseignement est censé connaître** : une menace surprise prévue par le scénario n'est pas
  sur la carte.
  - **Dans un désert, le fond OSM standard est presque vide** : prends OpenTopoMap
    (`tile.opentopomap.org`, relief ombré et courbes de niveau, attribution « © OpenStreetMap
    contributors, SRTM | style © OpenTopoMap (CC-BY-SA) »).
  - **Les zooms se cadrent large** (3 à 10 km, pour qu'une route ou un relief serve de repère) avec un
    **encart** qui détaille les unités une par une ; un zoom sur 300 m n'a plus de fond.
  - **Une carte générale très haute est illisible sur une page 16:9** : ajoute une carte paysage de
    la zone d'opérations, et garde la générale comme vue d'ensemble.
  - **Regarde chaque carte rendue** : aucune étiquette ne doit en chevaucher une autre, ni désigner le
    mauvais point, ni sortir du cadre.
- **Images de briefing DCS** : les mêmes cartes en JPEG d'environ 1600 px, copiées dans
  `src/mission/l10n/DEFAULT/`, déclarées dans `mapResource`, listées carte générale en tête dans
  `pictureFileNameB` et `pictureFileNameN` ; `pictureFileNameR` vide (`describe_known_limitations`,
  `briefing-pictures-red-then-blue`). Aucune action ne le fait : script qui charge et réécrit les
  tables (`mission_tools.miz_tools.read_mission_folder` / `write_mission_folder`, et
  `luadata.serialize` pour `mapResource`), à noter aux retours VMCT.
- **Dessins F10** (`add_map_drawing`) sur la couche `Blue` : l'itinéraire et ses points nommés, les
  menaces connues avec leur contour. Chaque étiquette avec un `fill_color` **opaque et clair**, sinon
  le fond par défaut (noir à moitié transparent) la rend illisible.
- **Briefing de la mission** (`set_briefing`) : le même contenu que le fichier de briefing, en texte.

## 5. Ordre de construction

1. `scaffold_mission` dans le dossier vide.
2. `mission.yaml` : identité, sécurité et profil `LOCAL_TEST`, modules.
3. Aérodromes (`set_airbase_coalition`), porte-avions, vols joueurs (4.3).
4. Objectifs (4.4), menace (4.5), et la zone à défendre s'il y en a une (2.1).
5. Soutien, radio, waypoints (4.6) ; date, météo, bullseye.
6. Carte du briefing, images, dessins F10, `set_briefing`.
7. `validate_mission`, `build_mission` (et le profil `LOCAL_TEST`), puis la section 8.
8. Le fichier de briefing (section 6).
9. `README.md` : le scénario, comment construire, les fichiers, les limites connues.

Point d'étape bref après chaque étape : ce qui est fait, pas ce que tu t'apprêtes à faire.

## 6. Le fichier de briefing

- **PPTX (et PDF si demandé)** dans `docs/` (`docs/briefing.pptx`, `docs/briefing.pdf`), le modèle
  de la section 3, page pour page ; le PPTX est la source de la version **Google Slides** (import dans
  Drive). Garde des polices que Slides connaît (Calibri, Cambria, Arial), et regarde le rendu converti
  s'il est déposé.
- **Généré par un script** qui lit la mission construite, comme la carte, pour qu'on le régénère
  après un changement. Pour le PPTX, le skill de présentations s'il est disponible, sinon
  `python-pptx` ; pour le PDF, l'export du PPTX ou une génération directe, avec les mêmes pages.
- **Les chiffres viennent de la mission, pas du scénario** : coordonnées des cibles relues sur les
  objets posés (DMS au centième de seconde), plan de fréquences relu dans `presets.yaml`, plan de vol
  relu sur la route du groupe ou dans `src/waypoints.yaml`, indicatifs relus sur les groupes. L'altitude d'une cible est celle du
  sol sous l'objet posé, lue par `terrain_elevation` (`points`), en pieds ; sans grille pour le
  théâtre, la colonne reste vide et c'est un point ouvert.
- **Relis chaque page rendue** (convertis-la en image et regarde-la) : rien ne déborde, aucune
  étiquette de carte n'en chevauche une autre, chaque numéro de waypoint correspond à la route. Sans
  LibreOffice, PowerPoint fait le rendu par COM (`Presentations.Open` puis `Slide.Export` en PNG) —
  c'est d'ailleurs le logiciel des lecteurs.

## 7. Ce que tu rends à la fin

- Le scénario tel que construit, en cinq lignes, et **chaque écart avec le scénario validé**.
- Les chemins du `.miz`, du briefing et des cartes.
- **Ce que tu as vérifié, et ce que tu n'as pas pu vérifier** (tout ce qui demande DCS).
- Le bloc **« Retours pour VMCT »**.
- Des **points ouverts numérotés**, avec ta reco pour chacun.

Ce qui revient à l'utilisateur : commit, push, publication, lancer DCS.

## 8. Vérification avant de dire « c'est prêt »

- **Lis tout le journal du build**, pas seulement le code de sortie : presets injectés dans combien
  d'appareils, waypoints injectés dans combien de groupes, liens des warehouses, avertissements. Tout
  zéro est suspect. Lance les builds **l'entrée standard fermée** (`< /dev/null`, ou
  `stdin=DEVNULL`) : un build est resté bloqué dix minutes à attendre une saisie, sans rien afficher.
- **Ouvre le `.miz` produit** (un zip ; `mission` et `warehouses` sont des tables Lua) et contrôle :
  - noms de groupes et d'unités **uniques** ;
  - slots nommés : un groupe par vol de l'ATO, le bon nombre de slots `Client`, au bon départ, avec
    un emport, et aucun slot dynamique ; slots dynamiques : seulement sur les bases prévues, et aucun
    slot fixe inattendu ;
  - la route de chaque vol joueur = le plan de vol du briefing (nombre de points, ordre, noms) ;
  - chaque objectif dans `veaf-config.lua`, avec ses unités, ses statiques et ses `addSceneryTarget` ;
    l'opération qui les regroupe, et son `ActivateZone` après `initialize()` ;
  - le nom d'**unité** de chaque statique-objectif commence par le nom de sa zone (4.4) ;
  - le plan de vol injecté dans les gabarits de slots dynamiques, et les altitudes au sol ;
  - les tâches des ravitailleurs et de l'AWACS ;
  - chaque nom de `modules.ASSETS` désigne un groupe qui existe ;
  - chaque porteur `#veafInterpreter` est du type du lanceur que génère son alias ;
  - le tableau des distances route ↔ menaces (4.5) ;
  - `requiredModules` vide ;
  - le profil `LOCAL_TEST` construit sans sécurité, la configuration par défaut avec ;
  - les images de briefing présentes, listées dans `pictureFileNameB` et `pictureFileNameN`,
    `pictureFileNameR` vide.
- **Relis le briefing, le fichier et la mission l'un contre l'autre** : chaque coordonnée,
  fréquence, indicatif, cap, distance et heure doit être le même partout.
- Liste ce qui reste à vérifier dans DCS : placement des statiques sur le terrain, masquage de la
  route par ce que le relief ne compte pas (bâtiments, forêts), réaction des défenses, déclenchement de la QRA, fin de chaque objectif (les cibles
  du décor comprises) et message de fin de l'opération, et
  les dessins de la carte F10 (ils ne se voient **qu'en jeu**).

## 9. Après le dépôt sur le serveur

Le dépôt revient à l'utilisateur ; ce qui suit l'aide à savoir ce qui tourne vraiment.

- **Mets un numéro de version dans le nom du `.miz`** (`…_v3.miz`). DCSServerBot reconnaît une
  mission à son nom : un fichier redéposé sous le même nom est renommé `-01`, et DCSSB garde ses
  propres copies, modifiées par RealWeather et MizEdit, dans `Missions/.dcssb/`. Avec un nom neuf,
  on voit dans la liste quelle version tourne.
- **Une trace `.trk` contient la mission telle qu'elle a été jouée** : c'est un zip, comme le `.miz`.
  Avant de chercher un bug signalé en jeu, ouvre la trace et compte les groupes. Le jour où « la
  garnison n'est pas là », les trois parties avaient tourné sur le dépôt précédent.
- **Les journaux d'un serveur VEAF se lisent en SFTP**, avec les serveurs déclarés dans
  `~/veafmct.yaml` (`servers.<machine>.logs.<instance>`), en lecture seule. Le journal de DCS dit
  quel fichier il charge (`loading mission from`), celui de DCSSB ce qu'il a modifié. Y chercher
  aussi les zones qui ignorent des groupes (`reportGroupsExcludedByName`) et les slots refusés faute
  de place (`no suitable parking`).
