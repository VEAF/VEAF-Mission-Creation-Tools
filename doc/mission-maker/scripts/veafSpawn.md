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
_spawn unit, name F-16C, hdg 180, alt 20000
_spawn unit, name T-80, hdg 270, spacing 50
```

**Options :**

- `name` — type d'unité
- `hdg` — cap (degrés)
- `alt` — altitude (pieds)
- `side` — coalition
- `country` — pays
- `skill` — niveau de compétence IA
- `spacing` — espacement entre unités (mètres)
- `immortal` — unités invulnérables

### Faire apparaître un groupe prédéfini

```
_spawn group, name [NOM_GROUPE]
```

L'alias de groupe doit exister dans la **base de spawn** : celle intégrée (ex. `sa2`, `sa3`, …) ou votre `src/spawn-groups.yaml` optionnel qui l'étend/la surcharge. La base vit en YAML et est injectée dans le `.miz` au build (pas de Lua à éditer). Voir [Référence Pipeline — données de spawn](../../PIPELINE_REFERENCE.md).

> **Une faute de frappe annule la commande.** Si un paramètre n'est pas reconnu (ex. `headng` au lieu de `heading`), le spawn n'est **pas** effectué et le pilote reçoit un indice (*vouliez-vous dire « heading » ?*). Corrigez le texte du marqueur et réessayez.

### Faire apparaître une patrouille CAP

```
_spawn cap, name Su-27, alt 25000, capradius 20000
```

**Options :**

- `name` — type d'avion
- `alt` — altitude de patrouille (pieds)
- `hdg` — cap initial
- `speed` — vitesse de patrouille (nœuds)
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

## Groupes d'avions spawnables (`src/spawnables.yaml`)

> ⚠️ À ne pas confondre avec la commande `_spawn group` (groupes **sol/hélico** de la base `veafUnits`). Ici il s'agit de **groupes d'avions** réels, cachés et en *late activation*, que `veafSpawn` **clone** à la demande en jeu.

Un **groupe d'avion spawnable** est identifié par le **préfixe de nom `veafSpawn-`** (contrat runtime de `veafSpawn`). À la construction, l'étape de pipeline `spawnable_aircrafts` injecte `src/spawnables.yaml` dans le `.miz`.

Le fichier utilise le **schéma DCS complet** des groupes d'aéronefs (`airplanes`/`helicopters` → `coalitions` → pays → groupe), identique à celui décrit dans la [Référence Pipeline — Étape 3](../../PIPELINE_REFERENCE.md#pipeline-step-3-aircraft-groups). On l'obtient en général par extraction depuis une mission :

```bash
veaf-tools extract-aircraft-groups --kind spawnable
```

Les **modèles de slot dynamique** (`dynSpawnTemplate = true`, slots Dynamic Slots DCS) sont une famille distincte, dans `src/dynamic-slot-templates.yaml` (étape `dynamic_slot_templates`) — voir l'[ADR 0002](https://github.com/VEAF/VEAF-Mission-Creation-Tools/blob/develop/docs/adr/0002-aircraft-group-injection-sort-criteria.md).

---

## Voir aussi

- [veafMove](veafMove.md) — déplacer des groupes existants
- [Référence API Lua](../../LUA_API_REFERENCE.md) — API complète de `veafSpawn`
