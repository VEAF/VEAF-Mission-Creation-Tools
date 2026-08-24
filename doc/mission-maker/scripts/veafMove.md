# veafMove — Déplacement d'unités et gestion des routes de ravitailleurs

**Module ID:** `MOVE` | **Fichier:** `veafMove.lua`

---

## Objectif

Fournit des commandes pour déplacer ou téléporter des groupes DCS existants, et gère les routes d'orbite des ravitailleurs. Inclut des helpers pour modifier la position d'orbite (`changeTanker`) et l'altitude/vitesse d'un ravitailleur, ou pour le faire suivre une nouvelle route (`moveTanker`).

---

## Dépendances

- `veafMarkers` — pour les commandes de marqueur
- `veafRadio` — pour les entrées du menu radio
- `mist` — pour la gestion des routes

---

## Activation

```lua
veafMove.initialize()
```

---

## Commandes de marqueur (côté joueur)

### Déplacer un groupe

```
_move group, name [NOM_GROUPE]
```

Déplace le groupe nommé vers la position du marqueur. Les unités terrestres traceront un itinéraire vers la destination ; les aéronefs voleront directement.

### Déplacer un ravitailleur

```
_move tanker, name [NOM_GROUPE]
```

Recalcule la route d'orbite du ravitailleur nommé pour qu'elle commence à la position du marqueur. Accepte les mots-clés optionnels `speed`/`spd`, `alt`/`altitude`, `heading`/`hdg`, `distance`/`dist`, `teleport` (téléporte le ravitailleur près de la nouvelle orbite plutôt que de l'y faire voler) et `silent` (ne crée pas de points nommés `refuel start`/`refuel end`).

### Modifier l'orbite d'un ravitailleur

```
_move tankermission, name [NOM_GROUPE]
```

Trouve le ravitailleur le plus proche du marqueur et modifie sa vitesse (`speed`/`spd`) et son altitude (`alt`/`altitude`) sans déplacer l'orbite.

### Déplacer un AFAC

```
_move afac, name [NOM_GROUPE]
```

Déplace l'orbite de l'AFAC nommé vers la position du marqueur. Accepte les mots-clés optionnels `speed`/`spd`, `alt`/`altitude`, `heading`/`hdg` et `immortal`.

---

## Gestion des ravitailleurs (API créateur de mission)

### Modifier l'orbite d'un ravitailleur

`veafMove.changeTanker(eventPos, speed, alt)` — trouve le ravitailleur proche de `eventPos` et change sa vitesse (nœuds) et son altitude (pieds) sans déplacer l'orbite.

```lua
-- Régler le ravitailleur proche du marqueur à 430 kn / 7000 ft
veafMove.changeTanker(eventPos, 430, 7000)
```

### Déplacer un ravitailleur sur une nouvelle route

`veafMove.moveTanker(eventPos, groupName, speed, alt, hdg, distance, teleport, silent)` — recalcule la route d'orbite du ravitailleur nommé à partir de `eventPos`.

```lua
veafMove.moveTanker(eventPos, "KC-135 Texaco", 430, 7000, 270, 30, false, false)
```

---

## Comment l'orbite est trouvée {#orbit-search}

Les deux commandes de ravitailleur travaillent sur le point de route qui porte la tâche **ORBIT**. Depuis la 6.15.12, ce point est **cherché dans toute la route**. Avant, il était supposé être l'avant-dernier : vrai pour les modèles VEAF, dont la route est [approche, orbite, fin de branche], faux pour un ravitailleur généré par DCS-Liberation, dont la route est plus longue et finit par un point d'atterrissage — les deux commandes refusaient alors avec « aucune tâche ORBIT définie ».

- **Si la route porte plusieurs orbites, la première gagne** : c'est celle que le ravitailleur atteint d'abord, donc celle qui est en cours ou imminente.
- **Sans aucune tâche ORBIT, la commande refuse** et le dit. Déplacer un ravitailleur au mauvais endroit est pire que de dire que ce n'est pas possible.
- L'orbite peut être le **premier** ou le **dernier** point de la route ; ces routes sont valides et ne sont plus refusées.

Le point qui **suit** l'orbite est l'autre extrémité de la branche de ravitaillement — c'est la sémantique DCS d'une orbite `Race-Track`, qui fait voler l'appareil entre le point portant la tâche et le suivant. C'est pourquoi `_move tanker` le repositionne.

> Exception : une orbite `Circle` tourne autour d'un seul point et ne donne aucun rôle au point suivant. Il n'est donc pas touché — sur une route Liberation, ce serait peut-être l'atterrissage. Dans ce cas `_move tanker` ne peut pas déduire la branche : précisez `distance` et `hdg`.

---

## Constantes clés

| Constante | Valeur par défaut | Description |
|-----------|-------------------|-------------|
| `veafMove.Keyphrase` | `"_move"` | Préfixe des commandes de marqueur |

---

## Voir aussi

- [veafSpawn](veafSpawn.md) — faire apparaître de nouvelles unités
- [Référence API Lua](../../LUA_API_REFERENCE.md) — API complète de `veafMove`
