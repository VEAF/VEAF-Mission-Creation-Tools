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

## 1. Les questions de départ (et seulement celles-là)

Une par une. L'utilisateur peut répondre « peu importe » ou « surprends-moi » à chacune : tu choisis
alors, et tu le dis.

1. **La carte** (un théâtre supporté par `scaffold_mission`).
2. **Les appareils joués et le nombre de pilotes** : quels types, combien de chaque, avions et/ou
   hélicoptères. C'est ce qui décide des objectifs possibles, des bases de départ et des distances.
3. **La durée de la séance** : le temps de vol disponible, briefing non compris. Reco : 2 h ; c'est
   le budget dans lequel tout le profil de vol doit tenir.
4. **Le genre de mission**, s'il en a une envie : frappe dans la profondeur, appui feu (CAS), SEAD /
   DEAD, antinavire, escorte, interception, héliportage / CSAR, ou un mélange. Et l'**époque** si elle
   ne découle pas des appareils.

Tout le reste — lieu, objectifs, menace, heure, météo, soutien — c'est **toi** qui le proposes, dans
le scénario.

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
- **Lisible en un coup d'œil** : un pitch qui se raconte en deux phrases.

Les actions de lecture (`geocode`, `list_airfields`, `describe_map`, `list_shortcuts`,
`list_unit_types`, `resolve_coordinates`, `describe_known_limitations`) sont permises en phase 1.
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

- le **format du briefing** : PPTX, PDF ou les deux (reco : les deux — le PDF pour diffuser, le PPTX
  pour retoucher) ;
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
  l'annonces. Désactive les modules du gabarit dont le scénario ne se sert pas.
- **Nom** : `VEAF_<Carte>_<Titre>` (titre en PascalCase sans accents, ex.
  `VEAF_Syria_DeepStrikePalmyra`).
- `mission.era`, **date** et **heure** (`set_mission_date`) cohérentes avec le scénario. Si le
  scénario dit « pleine lune » ou « nuit sans lune », **choisis la date d'après une éphéméride
  sourcée**, pas de mémoire.
- **Météo** : une seule, celle du scénario (`set_weather`). Pas de variantes : `pipeline.weather:
  false`, ou un `src/versions.yaml` à une seule version.
- **Langue** : `mission.language: fr` et briefing en français, sauf mention contraire.
- `silence_atc_on_all_airbases: true`.
- **Sécurité active par défaut** (la mission tourne sur les serveurs VEAF) ; demande s'il faut des
  hachages de mot de passe. **Jamais un mot de passe en clair**, même en commentaire. Un **profil
  `LOCAL_TEST`** : sécurité désactivée, logs `debug`, noms de groupes lisibles
  (`hide_names_from_spawned_groups: false`).
- **Aucun mod exigé** : `requiredModules` reste vide, sauf demande explicite.
- **Bullseye** (`set_bullseye`) : celui du scénario, le même pour les deux camps.

### 4.3 Les vols joueurs

- **Un groupe par vol de l'ATO**, au nom de son indicatif (`ARCHER`, `NINJA`…), **autant de slots
  que de places du cadre ATO** (quatre par défaut), skill `Client`, au **départ du scénario** :
  parking moteur froid par défaut (`add_air_group` ou `add_player_slot`, `ground-cold`), pont du
  porte-avions (`add_air_group`, `start: deck-cold` ou `deck-hot`, `carrier` = l'unité que rend
  `add_carrier_group`), en vol seulement si le scénario le dit.
- **Pas de slots dynamiques** : l'ATO nomme des vols, la mission les donne. `dynamic_spawn: false`
  sur chaque aérodrome.
- **Emport** : celui du scénario, ou un emport de base cohérent avec la mission si l'ATO dit
  « Armement libre » (les pilotes le changent au sol).
- **Plan de vol dans l'appareil** : la route du groupe (`edit_route`) **est** le plan de vol du
  briefing, dans le même ordre et sous les mêmes noms. Dans DCS le point 0 est le départ : `W1` du
  briefing est le point d'index 1. Vérifie-le à la relecture.
- **Altitude des points TBA** : très basse au-dessus du sol réel, pas au-dessus du niveau de la mer.
  Aucune action ne donne l'altitude du sol : note-le dans « Retours pour VMCT » et mets en point
  ouvert ce qui reste à vérifier en jeu.

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
  (points 2+ « On Road »), sa défense dans le même groupe. **Noms d'unités uniques**, parlants : ce
  sont ceux du briefing (« Centre de commandement », « Réservoir 3 »).

### 4.5 La menace

- **Défense sol** : batteries permanentes via `#veafInterpreter["-<alias>, country <pays>, hdg
  <cap>"]` — **porteur = une unité de la classe générée** (le lanceur de l'alias), pour que
  l'éditeur montre le cercle de portée ; noms d'unités uniques (`… #<site>-01`). Ou des groupes natifs
  placés là où le scénario les met.
- **L'itinéraire du scénario doit exister vraiment.** S'il « passe sous la couverture » ou « entre
  deux sites », mesure la distance de chaque segment de la route à chaque batterie et compare-la à la
  portée de l'arme (sourcée, ou mesurée dans DCS ; sinon, le chiffre reste en point ouvert). Le
  masquage par le relief ne se vérifie qu'en jeu : liste-le dans ce qui reste à vérifier.
- **Opposition aérienne** : celle du scénario. « Ils pourraient faire décoller des chasseurs après la
  frappe » = une **QRA** (`create_qra`) sur la base ennemie, cercle dans le territoire rouge, avec
  `delay_before_activating` et `react_on_helicopters` décidés et écrits au briefing ; intercepteurs
  d'époque avec **emport** (`pylons` ou `loadout_from`), `airport_link` sur la base. Une patrouille
  déjà en vol = un groupe natif en orbite, pas une CAP à la demande.
- **Radars d'alerte (EWR)** si le scénario parle d'être détecté, et **Skynet** si la défense doit
  réagir en réseau.

### 4.6 Soutien, radio, carte

- **Soutien** : seulement ce que le scénario cite. Ravitailleur : `add_air_group` (départ en vol),
  `edit_route` `add_task` : `orbit`, `tanker`, `activate_beacon` (TACAN Y), `set_unlimited_fuel`.
  AWACS : `awacs`, `eplrs`, `set_unlimited_fuel`, `orbit`. **Un nom partout** : nom de groupe =
  indicatif (Texaco, Shell, Overlord…) = libellé de preset = ligne du briefing ; déclaré dans
  `modules.ASSETS`.
- **Porte-avions** si le départ est en mer : `add_carrier_group` (TACAN, ICLS, Link 4, ravitailleur
  embarqué, hélicoptère de sauvetage, entrepôt), module `CARRIER`.
- **`src/presets.yaml` = le plan de fréquences du briefing**, canal pour canal : Garde, bases, porte-
  avions, AWACS, ravitailleurs, fréquence de package. Les **canaux de base portent les fréquences que
  DCS donne à l'aérodrome** : `describe_airfield_channels` puis `set_airfield_channels`, jamais une
  fréquence d'aérodrome tapée à la main.
- **`src/waypoints.yaml`** : retire les exemples du gabarit.
- **Carte du briefing** : générée depuis les données de la mission par un script (x/y → lat/lon via
  `resolve_coordinates` ou `veaf_libs.coordinates`), jamais dessinée à la main. Une carte générale
  (départ, itinéraire et points nommés, objectifs, menaces connues à leur rayon, soutien, bullseye,
  légende, échelle en nautiques) et **un zoom par objectif**, cadré par la liste des objets à montrer.
  Fond OpenStreetMap avec un `User-Agent` qui identifie l'outil par son URL (**jamais une donnée
  personnelle**), tuiles en cache local, mention « © OpenStreetMap contributors ». **Ne montre que ce
  que le renseignement est censé connaître** : une menace surprise prévue par le scénario n'est pas
  sur la carte.
- **Images de briefing DCS** : les mêmes cartes en JPEG d'environ 1600 px, copiées dans
  `src/mission/l10n/DEFAULT/`, déclarées dans `mapResource`, listées carte générale en tête dans
  `pictureFileNameB` et `pictureFileNameN` ; `pictureFileNameR` vide (`describe_known_limitations`,
  `briefing-pictures-red-then-blue`).
- **Dessins F10** (`add_map_drawing`) sur la couche `Blue` : l'itinéraire et ses points nommés, les
  menaces connues avec leur contour. Chaque étiquette avec un `fill_color` **opaque et clair**, sinon
  le fond par défaut (noir à moitié transparent) la rend illisible.
- **Briefing de la mission** (`set_briefing`) : le même contenu que le fichier de briefing, en texte.

## 5. Ordre de construction

1. `scaffold_mission` dans le dossier vide.
2. `mission.yaml` : identité, sécurité et profil `LOCAL_TEST`, modules.
3. Aérodromes (`set_airbase_coalition`), porte-avions, vols joueurs (4.3).
4. Objectifs (4.4), menace (4.5).
5. Soutien, radio, waypoints (4.6) ; date, météo, bullseye.
6. Carte du briefing, images, dessins F10, `set_briefing`.
7. `validate_mission`, `build_mission` (et le profil `LOCAL_TEST`), puis la section 8.
8. Le fichier de briefing (section 6).
9. `README.md` : le scénario, comment construire, les fichiers, les limites connues.

Point d'étape bref après chaque étape : ce qui est fait, pas ce que tu t'apprêtes à faire.

## 6. Le fichier de briefing

- **PPTX et/ou PDF**, selon la réponse à la validation, dans `docs/` (`docs/briefing.pptx`,
  `docs/briefing.pdf`). Le modèle de la section 3, page pour page.
- **Généré par un script** qui lit la mission construite, comme la carte, pour qu'on le régénère
  après un changement. Pour le PPTX, le skill de présentations s'il est disponible, sinon
  `python-pptx` ; pour le PDF, l'export du PPTX ou une génération directe, avec les mêmes pages.
- **Les chiffres viennent de la mission, pas du scénario** : coordonnées des cibles relues sur les
  objets posés (DMS au centième de seconde), plan de fréquences relu dans `presets.yaml`, plan de vol
  relu sur la route du groupe, indicatifs relus sur les groupes. L'altitude d'une cible ne s'écrit que
  si elle est mesurée (en jeu, `land.getHeight`) ; sinon la colonne reste vide et c'est un point
  ouvert.
- **Relis chaque page rendue** (convertis-la en image et regarde-la) : rien ne déborde, aucune
  étiquette de carte n'en chevauche une autre, chaque numéro de waypoint correspond à la route.

## 7. Ce que tu rends à la fin

- Le scénario tel que construit, en cinq lignes, et **chaque écart avec le scénario validé**.
- Les chemins du `.miz`, du briefing et des cartes.
- **Ce que tu as vérifié, et ce que tu n'as pas pu vérifier** (tout ce qui demande DCS).
- Le bloc **« Retours pour VMCT »**.
- Des **points ouverts numérotés**, avec ta reco pour chacun.

Ce qui revient à l'utilisateur : commit, push, publication, lancer DCS.

## 8. Vérification avant de dire « c'est prêt »

- **Lis tout le journal du build**, pas seulement le code de sortie : presets injectés dans combien
  d'appareils, liens des warehouses, avertissements. Tout zéro est suspect.
- **Ouvre le `.miz` produit** (un zip ; `mission` et `warehouses` sont des tables Lua) et contrôle :
  - noms de groupes et d'unités **uniques** ;
  - un groupe par vol de l'ATO, le bon nombre de slots `Client`, au bon départ, avec un emport ;
  - la route de chaque vol joueur = le plan de vol du briefing (nombre de points, ordre, noms) ;
  - aucun slot dynamique ;
  - chaque objectif dans `veaf-config.lua`, avec ses unités, ses statiques et ses `addSceneryTarget` ;
    l'opération qui les regroupe, et son `ActivateZone` après `initialize()` ;
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
  route par le relief, réaction des défenses, déclenchement de la QRA, fin de chaque objectif (les cibles
  du décor comprises) et message de fin de l'opération, et
  les dessins de la carte F10 (ils ne se voient **qu'en jeu**).
