# veafMove — Déplacement d'unités et gestion des routes de ravitailleurs

**Module ID:** `MOVE` | **Version:** — | **Fichier:** `veafMove.lua`

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

## Constantes clés

| Constante | Valeur par défaut | Description |
|-----------|-------------------|-------------|
| `veafMove.Keyphrase` | `"_move"` | Préfixe des commandes de marqueur |

---

## Voir aussi

- [veafSpawn](veafSpawn.md) — faire apparaître de nouvelles unités
- [Référence API Lua](../../LUA_API_REFERENCE.md) — API complète de `veafMove`
