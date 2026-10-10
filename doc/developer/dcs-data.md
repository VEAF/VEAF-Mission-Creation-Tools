# Générateurs de données de référence DCS

Certains outils de build ont besoin de données de la base DCS absentes du
fichier mission — l'**id numérique de pays** correspondant à un nom de pays, les
**plages de fréquences radio** valides d'un appareil, la liste des **types
d'unités** connus. Ces données sont générées dans des artefacts committés, pour
que le build n'ait jamais besoin d'une installation DCS.

## Stratégies de sourcing

Les données DCS entrent dans le dépôt de plusieurs façons, non interchangeables :

| Source | Comment | Besoin de DCS ? | Exemples |
|--------|---------|-----------------|----------|
| **Datamine communautaire** | clone de `Quaggles/dcs-lua-datamine` à un ref pinné | non | table des pays, **base des unités**, specs radio |
| **Base de référence `dcs-world-schema`** | base SQLite d'une release pinnée (version et SHA-256) | non | table nom→id et positions des aérodromes |
| **Export in-DCS** | capturer un dump en jeu (dcs-bridge `world.getAirbases()`, ou `dcsDataExport.lua`), committer le dump | oui (DCS lancé) | aérodromes d'une carte absente de la base de référence, armements |
| **Fichiers d'install DCS** | lire les fichiers d'une install locale (`--dcs-path`) | install seule (pas lancé) | fréquences ATC d'aérodrome, contrôles de cockpit |

La voie datamine est reproductible et vérifiable en CI ; c'est la voie par défaut
pour toutes les données dont VEAF a besoin au build/runtime. L'export in-DCS ne
couvre plus que ce que ni le datamine ni la base de référence n'exposent (armements,
aérodromes de TheChannel) et reste une rare étape manuelle.

## La commande `update-dcs-data`

Les artefacts issus du datamine se régénèrent avec :

```bash
veaf-build update-dcs-data            # tous les artefacts purs (countries + units + airdromes)
veaf-build update-dcs-data --countries
veaf-build update-dcs-data --units    # régénère dcsUnits.yaml ET dcsUnits.lua
veaf-build update-dcs-data --radio
veaf-build update-dcs-data --airdromes    # base de référence + dumps runtime committés
```

`--radio`, `--airfield-freqs`, `--cockpit-controls`, `--cities` et `--payloads` sont exclus
du run sans flag / `--all` : radio a des overlays manuels, et les autres lisent une
install DCS locale (`--dcs-path`).

Le datamine est cloné à un ref **pinné**
(`veaf_build.dcs_data.datamine.DATAMINE_REF`), donc la génération est
reproductible : relancer sur le même ref produit un artefact identique au
byte près, et la CI peut détecter un artefact committé qui dérive du générateur.
Pour récupérer des données DCS plus récentes, bumpez `DATAMINE_REF`, relancez la
commande et committez le diff.

### Artefacts purs vs hybrides

- **`dcs-countries.yaml`** est un artefact **pur** — 100 % output du générateur.
  Ne jamais l'éditer à la main ; la CI échoue s'il dérive du générateur.
- **`dcsUnits.yaml`** et le **`dcsUnits.lua`** rendu sont **purs** eux aussi (voir
  [La base des unités](#la-base-des-unités)). Les deux sont gardés par la CI :
  éditez le générateur, pas les fichiers.
- **`dcs-radio-specs.yaml` / `dcs-radio-specs.md`** sont **hybrides** : une base
  générée plus des **overlays manuels** que le générateur ne reproduit pas — les
  flags `dcs_rejects_on_load` (appareils qui font planter DCS au chargement avec
  un preset hors plage) et une section de doc bilingue « appareils critiques »
  écrite à la main. De ce fait, `--all` **saute** radio (avec un avertissement),
  et `--radio` régénère mais avertit que les overlays doivent être réappliqués
  ensuite.

`update-radio-specs` reste un alias de compatibilité pour `--radio`.

## La table des pays

`src/python/veaf-tools/veaf_libs/data/dcs-countries.yaml` associe chaque pays DCS
à son id numérique, matché par nom canonique, nom d'affichage de l'éditeur
(ex. `CJTF Blue`) et code court. Elle est lue au design-time par
`veaf_libs.dcs_countries.country_id_for_name()` — notamment par l'injecteur
d'appareils, qui doit poser un `country.id` valide sur tout pays qu'il
synthétise, sans quoi l'éditeur de mission DCS plante au chargement
(`me_mission.lua` → `fixCountriesNames` → nil-index).

## La base des unités

La base des unités DCS est générée depuis le datamine en **deux étapes** :

```text
_G/db/Units/**          (datamine, ref pinné)
   │  veaf_build.dcs_data.units   →  parse + dérivation
   ▼
dcsUnits.yaml           (source canonique committée, veaf_libs/data/)
   │  veaf_build.dcs_data.units_lua  →  rendu
   ▼
dcsUnits.lua            (table runtime committée, src/scripts/veaf/)
   │  chargée dans DCS
   ▼
veafUnits / veafSkynetIadsHelper   (consommateurs runtime)
```

`veaf-build update-dcs-data --units` exécute les deux étapes.

### Le `kind` dérivé

Chaque unité reçoit un **`kind`** unique — `air` / `naval` / `infantry` /
`vehicle` / `static` — dérivé des flags `attribute` DCS, par ordre de priorité :

| Priorité | Signal (attribute) | kind |
|---|---|---|
| 1 | `Air` | `air` |
| 2 | `Naval` ou `Ships` | `naval` |
| 3 | `Infantry` | `infantry` |
| 4 | `Ground vehicles` / `Vehicles` / `GroundUnits` / `RailwayUnits` | `vehicle` |
| 5 | *(aucun ci-dessus)* | `static` |

`kind` remplace les quatre booléens mutuellement exclusifs de l'ancien export
(`naval`/`air`/`infantry`/`vehicle`). `RailwayUnits`/`GroundUnits` rattrapent le
matériel ferroviaire (locomotives, wagons), classé `vehicle` par l'ancien export.

### Schéma YAML et Lua

`dcsUnits.yaml` est la source de vérité :

```yaml
units:
- type: "1L13 EWR"          # id de type DCS (clé de la base)
  name: EWR 1L13            # nom d'affichage
  kind: vehicle
  category: Air Defence     # catégorie DCS (avions/navires/hélicos dérivés du dossier)
  description: EWR 1L13
  attributes: [EWR, "Air Defence vehicles", ...]
- type: .Command Center
  kind: static
  shape_name: ComCenter     # statiques seulement : le `shape_name` que l'éditeur écrit
naval_statics:              # statiques offshore posés sur l'eau (liste curée)
- offshore WindTurbine
```

`dcsUnits.lua` rend cette table runtime épurée — clé par `type`, un seul `kind`
et une map `attribute` (Skynet s'appuie sur `SAM SR` / `EWR`) :

```lua
dcsUnits.NavalStatics = { ["offshore WindTurbine"] = true, ... }
dcsUnits.DcsUnitsDatabase = {
  ["1L13 EWR"] = {
    type = "1L13 EWR", name = "EWR 1L13", kind = "vehicle",
    category = "Air Defence", description = "EWR 1L13",
    attribute = { ["EWR"] = true, ... },
  },
}
```

Le runtime lit `type`, `name`, `description`, `category`, `kind` et `attribute` ;
`veafUnits.processUnit` reconvertit `kind` en les flags
`naval`/`air`/`infantry`/`vehicle`/`static` attendus par le reste du code. Le
fichier Lua est **exclu de `stylua`** (`.styluaignore`) car son formatage est un
output déterministe du générateur.

`shape_name` n'est pas rendu dans le Lua : il sert au design time. `add_group` l'écrit sur
un statique, et `validate` signale un statique qui n'en a pas alors que son type en a un.
DCS résout beaucoup de types sans lui, pas tous : un `.Command Center` ou un `.Ammunition
depot` posé sans `shape_name` est refusé au chargement (« unknown static shape_name »,
mesuré le 2026-09-28) et l'objet n'existe pas.

### Unités reportées et statiques navals

Deux choses absentes du datamine sont gérées explicitement dans
`veaf_build/dcs_data/units.py` :

- **`CARRIED_UNITS`** — unités présentes dans l'ancien export mais absentes du
  datamine (actuellement `Container_20ft` / `Container_40ft`). Reportées telles
  quelles pour que la migration ne perde jamais une unité.
- **`NAVAL_STATICS`** — la courte liste de statiques offshore (`Oil platform`, …).
  Le datamine n'a pas de flag fiable (`isPutToWater` est faux même pour
  l'éolienne offshore), donc la liste est curée ici.

Quand DCS livre une unité absente du datamine, ou un nouveau statique offshore,
ajoutez-le à la constante correspondante.

## La table des aérodromes

`src/python/veaf-tools/veaf_libs/data/airdromes.yaml` associe, **par théâtre**, un
nom d'aérodrome à son **id numérique** — le même id que `airports[<id>]` dans les
`warehouses` d'une mission. Elle permet aux outils de build (le câblage warehouse
des Dynamic Slots) d'accepter des **noms** d'aérodrome au lieu d'ids bruts.

La seule source du nom *exact* attendu par `Airbase.getByName` / le `airport_link` d'une QRA est DCS lui-même (`Airbase:getName()`).
Les fichiers terrain portent des libellés de *beacon* ou d'*ATC* qui diffèrent du vrai nom (ex. `Abu_Ad_Duhur` au lieu de `Abu al-Duhur`) — d'où l'abandon de `Beacons.lua`.

**Source principale : la base de référence de `dcs-world-schema`** (`veaf_build.dcs_data.reference`), une base SQLite lue dans DCS par ce projet et publiée avec chaque release.
Elle est téléchargée à une release pinnée et vérifiée par son SHA-256 : un asset republié en amont fait échouer la génération au lieu de modifier un artefact committé.
Mesuré le 2026-10-08 sur `v0.5.0` : ses 798 aérodromes de 13 théâtres ont les mêmes noms et ids que nos dumps runtime, sans exception.
Sa position est le **point de référence** du terrain, qui tombe au centre des pistes (écart médian 0 m) ; `Airbase:getPoint()`, ce que portent les dumps, tombe à environ 1 km de là.
`airdrome-positions.yaml` porte donc le point de référence depuis FEAT-DCS-REFERENCE-DATA.

**Les dumps runtime ne servent plus qu'aux théâtres absents de la base** (TheChannel à `v0.5.0`) : pour un théâtre que la base connaît, la base l'emporte.
Chaque dump est capturé une fois en jeu avec le **VEAF dcs-bridge** (`world.getAirbases()`, catégorie `AIRDROME` — tout, aérodromes **et** héliports de terrain, tous des `Airbase` valides avec warehouse).
Les deux sources étant pinnées ou committées, les deux fichiers sont **gardés par la CI** (`dcs-data-consistency.yml`) :

```bash
veaf-build update-dcs-data --airdromes
```

Pour une base plus récente, changez ensemble `REFERENCE_TAG`, `REFERENCE_ASSET` et `REFERENCE_SHA256` (le SHA-256 est publié par GitHub dans le `digest` de l'asset), relancez la commande et committez le diff.

**Capturer un dump (délégable, sans source ni Python).** Deux commandes `veaf-tools`
(donc dans l'exe distribué, utilisable par un non-dev) produisent le dump riche
`airbase_dumps/<theatre>.json` (`{id, name, lat, lon, coalition}` par aérodrome) :

```bash
# 1. injecter le pont dans n'importe quelle mission du théâtre voulu
veaf-tools dcs inject-bridge maMission.miz
# 2. lancer maMission.miz dans DCS + démarrer dcs-serve, puis capturer
veaf-tools dcs capture-map --api-key <token superuser dcs-serve> --out-dir <dossier>
```

Le `veaf-build update-dcs-data --airdromes` (côté dev) fusionne ensuite les `.json`
committés sous `veaf_build/dcs_data/airbase_dumps/` dans le YAML, pour les théâtres que la base de référence ne connaît pas.
Procédure complète pour les assistants : [capture-airbases](capture-airbases.md). Voir
le [dépôt VEAF-dcs-bridge](https://github.com/VEAF/VEAF-dcs-bridge) pour `dcs-serve`.

`veaf_libs.dcs_airdromes.airdrome_id_for_name(theatre, name)` la lit. Couverture : **les 14 théâtres DCS** (810 aérodromes : 798 de la base de référence, 12 du dump de TheChannel). Limite résiduelle : la
table ne couvre que les théâtres de la base ou **déjà dumpés** ; un autre théâtre ne donne
aucune entrée — l'appelant retombe alors sur les ids. La résolution est insensible
à la casse.

## Les places de parking {#parking}

`parking/<theatre>.json` liste, **par théâtre**, les emplacements où un appareil peut se garer.
Séparé des dumps d'aérodromes plutôt que fusionné avec eux : les 15 théâtres déjà capturés n'ont pas
besoin d'être refaits, et la capture des aérodromes reste la moitié utile si la seconde échoue.

Capturé en jeu avec le **VEAF dcs-bridge**, `Airbase:getParking(false)` par aérodrome :

```bash
veaf-tools dcs capture-map --parking
```

**Un appareil garé porte deux numéros distincts, et confondre les deux met l'avion ailleurs** :
`parking` et `parking_id`, qui valent par exemple 28 et 24 sur le même F-14A dans les fixtures de ce
dépôt. Ce sont les `Term_Index` et `Term_Index_0` du runtime. C'est cette paire qui a fait de
`add_air_group` sur un tarmac une capture de données (ticket 08) puis une écriture (ticket 09) au
lieu d'une seule tâche : aucune donnée livrée ici ne portait ces numéros — les 15 dumps d'aérodromes
ne contiennent que `{id, name, lat, lon, coalition}`.

Le dump garde **toutes** les clés que chaque emplacement porte, aplaties d'un niveau et en chaînes de
caractères : le schéma de l'API livré ici déclare quatre champs alors qu'un fichier de mission en
prouve davantage, donc la forme vient du runtime et non du schéma. Un test épingle qu'un champ futur
inconnu survit à la lecture. Un théâtre qui ne renvoie aucun emplacement est une donnée, pas un
échec.

Pas gardé par la CI, comme les autres tables dépendantes du runtime. Le mode opératoire côté
opérateur est dans [Récupérer les aérodromes d'une carte](capture-airbases.md).

## La table des fréquences d'aérodrome

`src/python/veaf-tools/veaf_libs/data/airfield-frequencies.yaml` donne, **par théâtre et par
id d'aérodrome DCS** (la clé des `warehouses` d'une mission), le nom de l'aérodrome
(`Airbase:getName()`), ses **fréquences ATC** (`uhf`, `vhf`, `fm`, en MHz) et son TACAN. Elle
alimente les collections `airports-<théâtre>` du `presets.yaml` par défaut, la commande
`content airfield-channels` et les actions MCP `describe_airfield_channels` /
`set_airfield_channels`, et `convert-v5` pour remplacer des fréquences en dur par des alias.

**D'où viennent les fréquences.** L'éditeur de mission
(`MissionEditor/modules/Mission/AirdromeData.lua`) demande à DCS les fréquences de chaque radio de
l'aérodrome (`DCS.getATCradiosData`), et DCS en rend **plus que le texte de**
`Mods/terrains/<T>/Radio.lua` : sur Persian Gulf, le fichier donne à Al Dhafra une seule fréquence,
126.5 VHF, et DCS en rend quatre, 39.5 / 126.5 / 251.1 / 4.3, celles qu'affiche le panneau de
l'aérodrome dans l'éditeur ; Bandar-e-Jask n'a aucune fréquence dans le fichier et quatre dans DCS
(mesuré le 2026-10-01 sur les sept théâtres installés). On ne voit pas, dans l'install, où DCS les
complète : lire le fichier est donc faux, seul DCS en marche fait foi. La table se construit en deux
temps.

1. **Capture**, guidée, une carte après l'autre, par le hook fiddle (environnement GUI,
   `dcs-fiddle-server.lua` installé — la commande vérifie sa présence). Pour chaque carte installée
   et pas encore capturée (ou celles nommées par `--theatre`), la commande écrit une mission vide
   dans le dossier `Missions\VEAF-capture-frequencies\` de DCS, dit quoi faire (l'ouvrir, la lancer,
   prendre le slot spectateur), **voit seule** la carte arriver dans DCS, capture, puis nomme la
   suivante ; à la fin, elle dit qu'on peut fermer DCS. Le TACAN est lu au même moment dans le
   `Beacons.lua` de l'install (TACAN et VORTAC). Chaque carte est commitée dans
   `veaf_build/dcs_data/airfield_freq_dumps/<Théâtre>.json` ; interrompue, la commande reprend là
   où elle s'était arrêtée.

   ```bash
   poetry run veaf-build update-dcs-data --airfield-freqs --capture --dcs-path "C:/jeux/DCS World"
   ```

2. **Génération**, hors DCS et reproductible, depuis les captures commitées : la table, et les
   collections `airports-<théâtre>` du `presets.yaml` par défaut, réécrites **entre leurs deux
   balises seulement**. Une seconde exécution ne change rien.

   ```bash
   veaf-build update-dcs-data --airfield-freqs
   ```

Un théâtre jamais capturé sur ce poste garde sa capture commitée : la machine qui lance la
commande ne touche que la carte qu'elle a chargée. Un test recalcule hors ligne la table et les
collections depuis les captures, et échoue si l'une a été modifiée à la main.

## Les villes des théâtres {#cities}

`veafNamedPoints` ajoute les villes du théâtre comme points nommés cachés : un nom de ville
sert alors de destination à un convoi, de position à un raccourci ou de départ à une mission
de transport, et la météo « au point le plus proche » les connaît. Elles viennent de
`Mods/terrains/<dossier>/Map/towns.lua`, rangées sous le nom que le terrain déclare dans son
`entry.lua` (`self_ID`) — celui que porte `env.mission.theatre`, qui n'est pas le nom du
dossier (`GermanyColdWar` → `GermanyCW`, `Sinai` → `SinaiMap`).

Deux fichiers, sur le modèle de la base des unités : `veaf_build/dcs_data/cities.yaml`, la
source, et `src/scripts/veaf/veafCities.lua`, rendu depuis elle (exclu de `stylua` ; un test
échoue s'il dérive du YAML).

```bash
veaf-build update-dcs-data --cities --dcs-path "C:/Program Files/Eagle Dynamics/DCS World"
veaf-build update-dcs-data --cities    # sans install : ne fait que re-rendre le Lua
```

Aucune install n'a toutes les cartes, donc la commande **fusionne** : un théâtre présent dans
l'install est remplacé, un théâtre absent est gardé tel quel. On la relance sur chaque install
qui apporte une carte. Au 2026-09-29, `cities.yaml` couvre Afghanistan, Caucasus, Falklands,
GermanyCW, MarianaIslands, MarianaIslandsWWII, Normandy, PersianGulf, SinaiMap, Syria et
TheChannel ; Falklands vient de l'ancienne table tapée dans `veafNamedPoints.lua`, aucune
install accessible n'ayant cette carte. Kola et Iraq n'ont pas encore de liste : une mission
sur ces cartes le signale au démarrage.

## Les index de contrôles de cockpit {#cockpit-controls}

`src/python/veaf-tools/veaf_libs/data/cockpit-controls/<type>.yaml` décrit, pour un
appareil, chacun de ses **contrôles cliquables** : l'argument d'animation à lire, le
libellé que DCS affiche au survol, les positions nommées, la plage de valeurs, et si le
contrôle a une position **lisible**. C'est ce que le résolveur de checklists guidées lit
pour traduire un `throttle sur idle` écrit par un instructeur en paramètres techniques,
sans que personne n'ouvre une install DCS.

Source : `Mods/aircraft/<Module>/Cockpit/Scripts/clickabledata.lua` (ou `Cockpit/` chez
Heatblur), plus `clickable_defs.lua` pour la plage de valeurs et `draw_args.lua` quand le
module nomme ses arguments. **Dépendant de l'install**, donc **non gardé par la CI** :

```bash
veaf-build update-dcs-data --cockpit-controls --dcs-path "C:/Program Files/Eagle Dynamics/DCS World"
```

`--aircraft F-16C` limite la génération à un module. Un module non installé est
simplement sauté ; le nombre d'éléments que le parseur n'a pas su lire est **affiché**,
jamais avalé en silence.

### Ce que l'index dit, et ce qu'il ne dit pas

Trois pièges, tous mesurés sur des cockpits réels :

- **`positions` est dans l'ordre du libellé, pas l'ordre des valeurs.** Le `MAIN PWR
  Switch, MAIN PWR/BATT/OFF` du F-16C vaut +1 / 0 / −1 dans cet ordre, alors que le
  `DIGITAL BACKUP, OFF/BACKUP` vaut 0 / 1. Déduire une valeur d'un rang est faux une fois
  sur deux, silencieusement.
- **Nommer les positions dans le libellé est une habitude ED récente, pas une règle.**
  Sur les cockpits indexés ici : F-16C 127 contrôles sur 284, AH-64D 123 sur 478, A-10C
  8 sur 470, F-14B **aucun** (Heatblur écrit `Hydraulic Transfer Pump Switch`, sans ses
  positions). Un résolveur qui suppose des positions nommées ne marche que chez ED.
- **`readable: false` n'est pas un défaut de l'index.** Un bouton n'a pas de position, et
  un interrupteur à rappel est revenu au neutre avant qu'on puisse le lire ; une étape sur
  un de ces contrôles doit être confirmée par le pilote.

Chaque module a son dialecte, et chacun a été trouvé en indexant un cockpit réel :
l'AH-64D, biplace, nomme la place avant le libellé (`mpd_button(CREW.PLT, _("…"), …)`) et
utilise des apostrophes ; le clavier UFC de l'A-10C passe un libellé vide ; Heatblur nomme
ses arguments (`cockpit_args.HYD_ISOLATION_Switch`) au lieu de les écrire. Le F-14B(U) n'a
pas de cockpit à lui : son `clickabledata.lua` fait deux lignes de `dofile` vers celui du
F-14B, et les deux appareils partagent donc un seul index.
