# veafSpawn — Apparition dynamique d'unités

**Module ID:** `SPAWN` | **Version:** 1.59.x | **Fichier:** `veafSpawn.lua`

---

## Objectif

Écoute les commandes de marqueur de carte F10 et fait apparaître des unités, groupes, convois, FARP, fumées, fusées éclairantes, cargos et contrôleurs JTAC à la demande. Il s'agit de l'interface de spawn principale côté joueur.

---

## Dépendances

- `veafMarkers` — pour la gestion des événements de marqueur
- `veafRadio` — pour le menu radio
- `veafSecurity` — pour les vérifications de permissions (optionnel)

---

## Activation

```lua
veafSpawn.initialize()
```

À appeler après tous les autres modules dont veafSpawn dépend.

---

## Constantes de configuration clés

| Constante | Valeur par défaut | Description |
|-----------|-------------------|-------------|
| `veafSpawn.SpawnKeyphrase` | `"_spawn"` | Préfixe du marqueur déclencheur de spawn |
| `veafSpawn.DestroyKeyphrase` | `"_destroy"` | Préfixe de la commande de destruction |
| `veafSpawn.TeleportKeyphrase` | `"_teleport"` | Préfixe de la commande de téléportation |
| `veafSpawn.IlluminationFlareAglAltitude` | `1000` | Altitude par défaut des fusées (m AGL) |
| `veafSpawn.ShellingInterval` | `5` | Secondes entre les tirs |
| `veafSpawn.AFAC.maximumAmount` | `8` | Nombre maximum d'AFAC simultanés par coalition |
| `veafSpawn.HideRadioMenu` | `false` | Masquer le sous-menu Spawn dans le F10 |
| `veafSpawn.LogisticUnitType` | `"FARP Ammo Dump Coating"` | Type d'objet statique pour la logistique |

---

## Commandes de marqueur (côté joueur)

### Faire apparaître une unité

```
_spawn unit, name [DCS_TYPE]
_spawn unit, name F-16C, group 2, hdg 180, alt 20000
_spawn unit, name T-80, group 4, hdg 270, spacing 50
```

**Options :**
- `name` — type d'unité
- `group` — nombre d'unités
- `hdg` — cap (degrés)
- `alt` — altitude (pieds)
- `speed` — vitesse (nœuds)
- `side` — coalition
- `country` — pays
- `skill` — niveau de compétence IA
- `spacing` — espacement entre unités (mètres)
- `immortal` — unités invulnérables

### Faire apparaître un groupe prédéfini

```
_spawn group, name [NOM_GROUPE]
```

Le groupe doit être défini dans `spawnables.yaml`.

### Faire apparaître une patrouille CAP

```
_spawn cap, name Su-27, alt 25000, capradius 20000
```

**Options :**
- `name` — type d'avion
- `alt` — altitude de patrouille (pieds)
- `hdg` — cap initial
- `speed` — vitesse de patrouille (nœuds)
- `group` — nombre d'avions
- `capradius` — rayon d'orbite CAP (mètres)
- `distance` — distance depuis le marqueur

### Faire apparaître un AFAC/JTAC

```
_spawn afac, name A-10C, freq 133.0, mod AM, code 1688, alt 15000
```

**Options :**
- `name` — type d'avion
- `freq` — fréquence radio
- `mod` — modulation (`AM` ou `FM`)
- `code` — code laser
- `alt` — altitude d'orbite (pieds)
- `speed` — vitesse d'orbite (nœuds)
- `immortal` — unité invulnérable

### Faire apparaître un convoi

Placer deux marqueurs : un avec la commande (départ), un comme destination.

```
_spawn convoy, dest [NOM_MARQUEUR_DEST], speed 50, defense 2, armor 2, size 3
```

**Options :**
- `dest` — nom du marqueur de destination
- `speed` — vitesse du convoi (km/h)
- `defense [0-5]` — niveau de défense aérienne
- `armor [0-5]` — niveau de blindage
- `size [0-5]` — nombre de véhicules
- `patrol` — retour à la position de départ
- `offroad` — autoriser le déplacement hors route

### Faire apparaître de la fumée

```
_spawn smoke, color red
_spawn smoke, color green, shells 5
```

**Couleurs :** `red`, `green`, `blue`, `white`, `orange`

### Faire apparaître des fusées éclairantes

```
_spawn flare, power 1000000, shells 5, heading 90, distance 500
```

### Faire apparaître des explosions

```
_spawn bomb, power 500, shells 3
```

### Faire apparaître un FARP

```
_spawn farp, name "FARP Alpha", side blue
```

### Détruire des unités

```
_destroy, radius 500
_destroy, name Tank-1
```

### Téléporter un groupe

```
_teleport, name "Viper Flight"
```

---

## Groupes spawnables (spawnables.yaml)

Définir des modèles de groupes réutilisables que les joueurs peuvent faire apparaître avec `_spawn group` :

```yaml
groups:
  - name: "RED-CAP"
    description: "CAP rouge (2 × MiG-29S)"
    coalition: red
    country: Russia
    units:
      - type: MiG-29S
        skill: High
      - type: MiG-29S
        skill: High

  - name: "ARMOR-PLATOON"
    description: "Peloton blindé (4 × T-80)"
    coalition: red
    country: Russia
    units:
      - type: T-80
        count: 4
        skill: Average
```

---

## Voir aussi

- [veafMove](veafMove.md) — déplacer des groupes existants
- [Référence API Lua](../../LUA_API_REFERENCE.md) — API complète de `veafSpawn`
