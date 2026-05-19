# veafHoundElintHelper — Intégration Hound ELINT

**Module ID:** — | **Fichier:** `veafHoundElintHelper.lua`

---

## Objectif

Intègre les unités spawned par VEAF avec le script tiers [Hound ELINT](https://github.com/hounddoglu/DCS-Hound). Quand `veafSpawn` crée de nouvelles unités émettrices (SAM, radars EWR), ce helper les enregistre dans Hound pour qu'elles apparaissent dans l'image ELINT.

---

## Prérequis

- Le script Hound ELINT doit être chargé avant `veafHoundElintHelper`
- Hound doit être initialisé dans votre mission

---

## Activation

```lua
veafHoundElintHelper.initialize()
```

Après cet appel, les unités spawned par `veafSpawn` qui sont des émetteurs radar seront automatiquement ajoutées au réseau ELINT de Hound.

---

## Délai d'enregistrement

Il existe un délai configurable avant la tentative d'ajout des unités nouvellement spawned à Hound ELINT. Ce délai est nécessaire pour les aéronefs spawned dynamiquement :

```lua
veafSpawn.HoundElintAddDelay = 1  -- secondes (par défaut)
```

Augmenter cette valeur si Hound signale des unités introuvables immédiatement après le spawn.

---

## Notes

- Hound ELINT est un script tiers non inclus dans VEAF — à télécharger séparément
- Seules les unités qui sont des émetteurs radar apparaîtront dans l'image ELINT
- L'enregistrement est entièrement automatique une fois le helper initialisé

---

## Voir aussi

- [veafSkynetIadsHelper](veafSkynetIadsHelper.md) — intégration Skynet IADS
- [Référence API Lua](../../../LUA_API_REFERENCE.md) — API complète de `veafHoundElintHelper`
