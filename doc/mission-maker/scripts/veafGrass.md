# veafGrass — Configuration de pistes en herbe

**Module ID:** `GRASS` | **Fichier:** `veafGrass.lua`

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
- Les unités de type FARP (`FARP`, `FARP_SINGLE_01`, `Invisible FARP`, `FARP_T`, `SINGLE_HELIPAD`) dont le **nom d'unité commence par `FARP ` (FARP suivi d'une espace)** reçoivent un décor de FARP.

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
2. Nommez l'**unité** en la faisant commencer par `FARP ` (par exemple `FARP Whiskey`).
3. Appelez `veafGrass.initialize()`.

Au démarrage, `veafGrass.buildFarpsUnits(hiddenOnMFD)` ajoute un décor de FARP autour de chaque unité reconnue (via `veafGrass.buildFarpUnits`).

### Où le décor est posé {#farp-layout}

Le décor (tentes, dépôts, escorte) est placé à distance fixe du FARP, dans la direction de son cap. Depuis la 6.15.11, **si l'emplacement prévu est déjà occupé par une unité ou un objet statique, le module tourne autour du FARP jusqu'à trouver du terrain libre** — il garde la distance et change la direction, pour que l'escorte reste près du FARP qu'elle sert.

C'est le cas courant plus qu'un cas limite : on pose un FARP statique dans la mission (c'est lui qui autorise l'apparition sur ce FARP une fois la zone prise), puis on lance `-farp` par-dessus. Avant, l'escorte se posait sur les plateformes, assez près pour qu'un hélicoptère qui atterrit y trouve un camion.

Quatre précisions :

- **Un FARP dégagé ne bouge pas.** La direction d'origine est essayée en premier, donc une mission qui fonctionne garde exactement son décor.
- **Les forêts sont évitées aussi**, en plus des unités, des objets statiques et des plateformes : DCS ne sait pas répondre « cet endroit est-il dégagé ? » pour des arbres, donc le module lui demande une liste d'emplacements sans arbres et choisit dans cette liste. La promesse ci-dessus tient malgré tout : si l'emplacement demandé se trouve dans la même clairière que le point sans arbres le plus proche, il est conservé tel quel — jusqu'à ce correctif, l'escorte était déplacée de quelques dizaines de mètres même en pleine campagne.
- Le groupe entier est vérifié, pas seulement son premier véhicule : l'escorte occupe une ligne d'une trentaine de mètres, et un emplacement libre dont la queue dépasse bloquerait quand même une plateforme.
- Si aucune direction n'est libre, le FARP est construit quand même, à sa position d'origine. Un FARP qui refuserait d'exister parce que l'endroit est encombré serait pire.

> Les marqueurs des `Invisible FARP` sont volontairement collés au centre pour matérialiser le FARP : ils ne se déplacent pas.

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
