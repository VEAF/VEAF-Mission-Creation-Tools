# veafGrass — Configuration de pistes en herbe

**Module ID:** — | **Fichier:** `veafGrass.lua`

---

## Objectif

Configure des pistes en herbe non préparées pour une utilisation dans les missions DCS. Fournit des données de positionnement, des fréquences radio et des aides à l'atterrissage pour les zones d'atterrissage en campagne qui ne sont pas des bases aériennes DCS standard.

---

## Activation

```lua
veafGrass.initialize()
```

`veafGrass.initialize()` programme `veafGrass.buildFarpsUnits` quelques secondes après le démarrage de la mission (le temps que les autres modules soient chargés) et enregistre un gestionnaire d'événement de naissance. Il n'y a **pas de classe builder** : tout est piloté par les noms donnés aux objets dans l'éditeur de mission DCS.

---

## Fonctionnement

Au démarrage, le module parcourt toutes les unités de la mission et agit selon leur nom :

- Les objets statiques dont le **nom contient `GRASS_RUNWAY`** (insensible à la casse) servent d'origine à une piste en herbe.
- Les unités de type FARP (`FARP`, `FARP_SINGLE_01`, `Invisible FARP`, `FARP_T`, `SINGLE_HELIPAD`) dont le **nom de groupe commence par `FARP ` (FARP suivi d'une espace)** reçoivent un décor de FARP.

---

## Pistes en herbe

Pour créer une piste en herbe :

1. Placez un objet statique dans l'éditeur de mission DCS, à l'extrémité droite de la future piste, orienté dans l'axe de la piste.
2. Nommez-le de façon à ce que son nom **contienne `GRASS_RUNWAY`** (par exemple `GRASS_RUNWAY_WHISKEY`).
3. Appelez `veafGrass.initialize()` au niveau du module.

Au démarrage, `veafGrass.buildGrassRunway(grassRunwayUnit, hiddenOnMFD)` construit le décor de la piste (rangées de plots de chaque côté, tour) à partir de la position et du cap de cet objet.

---

## FARP

Pour habiller un FARP :

1. Placez une unité de type FARP (`FARP`, `FARP_SINGLE_01`, `Invisible FARP`, `FARP_T` ou `SINGLE_HELIPAD`).
2. Nommez son **groupe** en le faisant commencer par `FARP ` (par exemple `FARP Whiskey`).
3. Appelez `veafGrass.initialize()`.

Au démarrage, `veafGrass.buildFarpsUnits(hiddenOnMFD)` ajoute un décor de FARP autour de chaque unité reconnue (via `veafGrass.buildFarpUnits`).

### Réapprovisionnement des entrepôts

Depuis DCS 2.8, les FARP créés apparaissent avec un entrepôt vide. Le module fournit des fonctions pour les réapprovisionner :

- `veafGrass.fillAllFarpWarehouses()` — parcourt tous les FARP et pistes en herbe valides et remplit leurs entrepôts.
- `veafGrass.fillFarpWarehouse(farp)` — remplit l'entrepôt d'un FARP donné.

Le contenu déposé est défini par la table `veafGrass.WAREHOUSE_ITEMS`. La table `veafGrass.helicoptersOnFARPs` liste les types d'hélicoptères ajoutés aux entrepôts des FARP pour être disponibles dans le mécanisme de slots dynamiques.

---

## Notes

- La position et le cap de la piste en herbe sont lus depuis l'objet statique nommé `...GRASS_RUNWAY...`.
- Les unités de décor générées sont masquées sur les MFD pour éviter d'encombrer l'affichage.

---

## Voir aussi

- [veafAssets](veafAssets.md) — pour les ravitailleurs et AWACS gérés aux bases régulières
- [Référence API Lua](../../LUA_API_REFERENCE.md) — API complète de `veafGrass`
