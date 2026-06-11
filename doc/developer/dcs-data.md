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
| **Datamine communautaire** | clone de `Quaggles/dcs-lua-datamine` à un ref pinné | non | table des pays, specs radio |
| **Export in-DCS** | exécuter `src/scripts/veaf/dcsDataExport.lua` depuis l'éditeur, committer le dump | oui | `dcsUnits.lua` (base des unités) |

La voie datamine est reproductible et vérifiable en CI ; l'export in-DCS est une
étape manuelle, réalisée quand DCS ajoute des unités.

## La commande `update-dcs-data`

Les artefacts issus du datamine se régénèrent avec :

```bash
veaf-build update-dcs-data            # tout ce qui est sûr à régénérer (countries)
veaf-build update-dcs-data --countries
veaf-build update-dcs-data --radio
```

Le datamine est cloné à un ref **pinné**
(`veaf_build.dcs_data.datamine.DATAMINE_REF`), donc la génération est
reproductible : relancer sur le même ref produit un artefact identique au
byte près, et la CI peut détecter un artefact committé qui dérive du générateur.
Pour récupérer des données DCS plus récentes, bumpez `DATAMINE_REF`, relancez la
commande et committez le diff.

### Artefacts purs vs hybrides

- **`dcs-countries.yaml`** est un artefact **pur** — 100 % output du générateur.
  Ne jamais l'éditer à la main ; la CI échoue s'il dérive du générateur.
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
