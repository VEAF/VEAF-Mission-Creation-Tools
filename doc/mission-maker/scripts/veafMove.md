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

### Téléporter un groupe

```
_teleport, name [NOM_GROUPE]
```

Déplace instantanément le groupe vers la position du marqueur. Utile pour les tests.

---

## Gestion des ravitailleurs (API créateur de mission)

### Modifier l'orbite du ravitailleur

`veafMove.changeTanker(groupName, point, altitude, speed)` — déplace le waypoint d'orbite du ravitailleur vers une nouvelle position.

```lua
-- Déplacer Texaco vers une nouvelle position d'orbite
veafMove.changeTanker("KC-135 Texaco", { x=1000, y=7000, z=2000 }, 7000, 430)
```

### Déplacer le ravitailleur sur une nouvelle route

`veafMove.moveTanker(groupName, startPoint, endPoint, altitude, speed)` — définit une nouvelle route d'orbite en circuit.

```lua
veafMove.moveTanker("KC-135 Texaco", startPoint, endPoint, 7000, 430)
```

---

## Constantes clés

| Constante | Valeur par défaut | Description |
|-----------|-------------------|-------------|
| `veafMove.SpawnKeyphrase` | `"_move"` | Préfixe de la commande de marqueur pour déplacer |

---

## Voir aussi

- [veafSpawn](veafSpawn.md) — faire apparaître de nouvelles unités
- [Référence API Lua](../../LUA_API_REFERENCE.md) — API complète de `veafMove`
