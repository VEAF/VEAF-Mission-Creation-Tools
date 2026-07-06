# Générateurs de données de référence DCS

Certains outils de build ont besoin de données de la base DCS absentes du
fichier mission — l'**id numérique de pays** correspondant à un nom de pays, les
**plages de fréquences radio** valides d'un appareil, la liste des **types
d'unités** connus. Ces données sont générées dans des artefacts committés, pour
que le build n'ait jamais besoin d'une installation DCS.

## Stratégies de sourcing

Les données DCS entrent dans le dépôt de **deux** façons, non interchangeables :

| Source | Comment | Besoin de DCS ? | Exemples |
|--------|---------|-----------------|----------|
| **Datamine communautaire** | clone de `Quaggles/dcs-lua-datamine` à un ref pinné | non | table des pays, **base des unités**, specs radio |
| **Export in-DCS** | exécuter `src/scripts/veaf/dcsDataExport.lua` depuis l'éditeur, committer le dump | oui | airbases, armements |
| **Fichiers d'install DCS** | lire les fichiers terrain d'une install locale (`--dcs-path`) | install seule (pas lancé) | table nom→id des aérodromes |

La voie datamine est reproductible et vérifiable en CI ; c'est la voie par défaut
pour toutes les données dont VEAF a besoin au build/runtime. L'export in-DCS ne
couvre plus que ce que le datamine n'expose pas (aérodromes, armements) et reste
une rare étape manuelle.

## La commande `update-dcs-data`

Les artefacts issus du datamine se régénèrent avec :

```bash
veaf-build update-dcs-data            # tous les artefacts purs (countries + units)
veaf-build update-dcs-data --countries
veaf-build update-dcs-data --units    # régénère dcsUnits.yaml ET dcsUnits.lua
veaf-build update-dcs-data --radio
veaf-build update-dcs-data --airdromes --dcs-path "C:/Program Files/Eagle Dynamics/DCS World"
```

`--radio`, `--airdromes` et `--airfield-freqs` sont exclus du run sans flag / `--all` :
radio a des overlays manuels, et airdromes / airfield-freqs nécessitent le chemin
d'une install DCS locale.

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

Elle est **dépendante de l'install**, pas du datamine : la donnée n'existe que dans
le `Mods/terrains/<Théâtre>/Beacons.lua` de chaque carte (les beacons d'aérodrome
portent un `display_name` et un `beaconId = 'airfield<ID>_<n>'`). Elle est donc
générée depuis une install DCS locale et **non gardée par la CI** (un runner CI
n'a pas d'install DCS) :

```bash
veaf-build update-dcs-data --airdromes --dcs-path "C:/Program Files/Eagle Dynamics/DCS World"
```

`veaf_libs.dcs_airdromes.airdrome_id_for_name(theatre, name)` la lit. Limites : la
table ne couvre que les théâtres **installés**, et les cartes sans beacons (ex.
Normandy, WW2) ne donnent aucune entrée — l'appelant retombe alors sur les ids. La
résolution est insensible à la casse.

## La table des fréquences d'aérodrome

`src/python/veaf-tools/veaf_libs/data/airfield-frequencies.yaml` associe, **par
théâtre**, un nom d'aérodrome à ses **fréquences ATC** (`uhf`, `vhf`, `fm`, en MHz).
Elle sert à `convert-v5` pour remplacer les fréquences en dur des presets par des
alias lisibles (ex. `Gudauta`).

Comme la table des aérodromes, elle est **dépendante de l'install** (source :
`Mods/terrains/<Théâtre>/Radio.lua`, bloc `frequency` — `UHF`→`uhf`, `VHF_HI`→`vhf`,
`VHF_LOW`→`fm`, HF ignoré) et **non gardée par la CI** :

```bash
veaf-build update-dcs-data --airfield-freqs --dcs-path "C:/Program Files/Eagle Dynamics/DCS World"
```

Elle ne couvre que les théâtres **installés**.
