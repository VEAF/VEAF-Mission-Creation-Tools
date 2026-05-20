# veafNamedPoints — Points nommés sur la carte

**Module ID:** `NAMED POINTS` | **Version:** 1.16.x | **Fichier:** `veafNamedPoints.lua`

---

## Objectif

Permet aux créateurs de missions (et aux joueurs disposant des permissions appropriées) de définir des positions nommées sur la carte. Les points nommés peuvent être référencés par d'autres systèmes (convois, missions, commandes de fumée) et peuvent optionnellement exposer une fréquence ATC ou un canal TACAN.

---

## Dépendances

- `veafMarkers` — pour la commande de marqueur `_name point`
- `veafRadio` — entrée optionnelle dans le menu radio

---

## Activation

```lua
veafNamedPoints.initialize()
```

---

## Constantes clés

| Constante | Valeur par défaut | Description |
|-----------|-------------------|-------------|
| `veafNamedPoints.Keyphrase` | `"_name point"` | Préfixe de la commande de marqueur |
| `veafNamedPoints.RadioMenuName` | `"NAMED POINTS"` | Libellé du sous-menu F10 |

---

## Prédéfinir des points dans missionconfig.lua

Les points nommés peuvent être prédéfinis par programmation :

```lua
veafNamedPoints.initialize()

-- Ajouter un point nommé statique
veafNamedPoints.addNamedPoint({
  name      = "FARP Alpha",
  position  = { x = 123456, y = 0, z = 654321 },  -- vec3 DCS
  atcFreq   = 127500000,  -- Hz
  atcMod    = radio.modulation.AM,
})

-- Ajouter un point à une base aérienne DCS connue
veafNamedPoints.addNamedPointFromAirbase("Senaki-Kolkhi")
```

---

## Commande de marqueur joueur

Les joueurs peuvent créer des points nommés via des marqueurs de carte (si la sécurité le permet) :

```
_name point Alpha
```

Place un point nommé "Alpha" à la position du marqueur.

---

## Référencer les points nommés

Les points nommés peuvent être utilisés comme destinations dans les commandes de spawn :

```
_spawn convoy, dest Alpha, speed 40
```

---

## Voir aussi

- [veafSpawn](veafSpawn.md) — utilise les points nommés pour les destinations de convois
- [Référence API Lua](../../LUA_API_REFERENCE.md) — API complète de `veafNamedPoints`
