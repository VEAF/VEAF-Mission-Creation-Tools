# veafNamedPoints — Points nommés sur la carte

**Module ID:** `NAMEDPOINTS` | **Fichier:** `veafNamedPoints.lua`

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

## Configuration (`mission.yaml`) {#configuration-missionyaml}

```yaml
modules:
  NAMEDPOINTS:
    enabled: true          # défaut : true
    logLevel: info        # surcharge optionnelle du niveau de log
    custom_points:        # points nommés prédéfinis
      - name: "Zone de Combat Alpha"  # nom du point (référencé dans les commandes)
        lat: "41.123456"               # latitude en string (degrés décimaux)
        lon: "44.987654"               # longitude en string (degrés décimaux)
      - name: "FARP Bravo"
        lat: "41.200000"
        lon: "44.100000"
```

| Champ | Type | Défaut | Requis | Description |
|-------|------|--------|--------|-------------|
| `enabled` | booléen | `true` | Non | Activer ou désactiver le module |
| `logLevel` | string | *(global)* | Non | Surcharge du niveau de log par module |
| `custom_points` | objet[] | `[]` | Non | Points nommés prédéfinis |
| `custom_points[].name` | string | — | Oui | Nom du point — référencé dans les commandes de spawn et les menus radio |
| `custom_points[].lat` | string | — | Oui | Latitude en string décimal (ex : `"41.123456"`) |
| `custom_points[].lon` | string | — | Oui | Longitude en string décimal (ex : `"44.987654"`) |

> Les coordonnées sont géographiques (WGS84). Utiliser les degrés décimaux sous forme de strings.

### Exemple minimal

```yaml
modules:
  NAMEDPOINTS:
    enabled: true
    custom_points:
      - name: "BULLSEYE"
        lat: "41.100000"
        lon: "43.850000"
```

---

## Constantes clés

| Constante | Valeur par défaut | Description |
|-----------|-------------------|-------------|
| `veafNamedPoints.Keyphrase` | `"_name point"` | Préfixe de la commande de marqueur |
| `veafNamedPoints.RadioMenuName` | `"NAMED POINTS"` | Libellé du sous-menu F10 |

---

## Prédéfinir des points dans mission-script.lua

Les points nommés peuvent être prédéfinis par programmation. `addPoint(name, point)` prend un vec3 (`{x=…, y=0, z=…}` ; `y` vaut `0` par défaut). Les données ATC/TACAN/ILS/tour de contrôle sont attachées via `addDataToPoint(point, data)` :

```lua
veafNamedPoints.initialize()

-- Ajouter un point nommé statique
local point = veafNamedPoints.addPoint("FARP Alpha", { x = 123456, y = 0, z = 654321 })

-- Attacher des données ATC/TACAN/tour/ILS au point
veafNamedPoints.addDataToPoint(point, {
  atc   = true,
  tower = "V131, U260",
  tacan = "16X BTM",
  ils   = "110.30",
})
```

`addAirbases()` ajoute en bloc toutes les bases aériennes de la carte (appelée automatiquement par `initialize()`) ; il n'existe pas de fonction d'ajout par base aérienne. `addCities()` ajoute de la même façon les villes du théâtre.

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

Un convoi accepte plusieurs `dest` et parcourt les points dans l'ordre écrit, ce qui permet de composer un trajet à partir de points nommés :

```
_spawn convoy, dest Alpha, dest Bravo, dest Charlie, speed 40
```

Voir [veafSpawn](veafSpawn.md#convoy-itinerary).

---

## Voir aussi

- [veafSpawn](veafSpawn.md) — utilise les points nommés pour les destinations de convois
- [Référence API Lua](../../LUA_API_REFERENCE.md) — API complète de `veafNamedPoints`
