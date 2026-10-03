# veafSpawn — Apparition dynamique d'unités

**Module ID:** `SPAWN` | **Fichier:** `veafSpawn.lua`

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
_spawn unit, name T-80, hdg 270, spacing 50
```

Un **avion** ne peut pas être créé ainsi (la commande le refuse) : passez par une patrouille CAP. Un
**hélicoptère**, si : voir [Faire apparaître un hélicoptère](#helicopters).

**Options :**

- `name` — type d'unité
- `hdg` — cap (degrés)
- `alt` — altitude (pieds) ; pour un hélicoptère, la hauteur de sa tâche
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

### Faire apparaître un hélicoptère {#helicopters}

```
_spawn unit, name mi8
_spawn unit, name mi24, task orbit
_spawn unit, name uh1, task transport, dest FOB-NORD
_spawn group, name [GROUPE_D_HELICOPTERES], task orbit, alt 800
```

L'hélicoptère apparaît **posé** à l'endroit du marqueur, puis fait ce que dit `task` :

| `task` | Ce qu'il fait |
|---|---|
| *(rien)* | reste posé, moteur coupé : une cible |
| `orbit` | décolle et tourne au-dessus du marqueur ; tire sur ce qui passe s'il est armé, ne tire pas sinon |
| `transport` | décolle, va à `dest` et se pose dans la clairière la plus proche (jusqu'à 300 m), en ne faisant que riposter ; refusé sans `dest`. Visez un terrain dégagé : au bord d'une forêt, il reste en vol stationnaire sans se poser |
| `patrol` | armé : boucle de 1 km autour du marqueur (ou aller-retour jusqu'à `dest`), engage le sol et les hélicoptères à portée ; non armé : navette marqueur ↔ `dest`, 5 min au sol à chaque bout, sans fin (refusée sans `dest`) |
| `attack` | armé seulement : va à `dest`, engage le sol et les hélicoptères à portée, puis tourne sur place |
| `escort` | armé seulement : `dest` est le **nom d'un groupe au sol**, qu'il rejoint et couvre |

`alt` est la hauteur au-dessus du sol (pieds, 500 par défaut), `speed` la vitesse (nœuds, 80 par
défaut). `dest` est un point nommé ou des coordonnées, comme pour un convoi. `capradius` est la portée
d'engagement d'un hélicoptère armé (mètres, 3 000 par défaut).

**Armé ou non, c'est l'alias qui le dit**, pas le type : DCS range le Mi-8 à la fois parmi les
hélicoptères d'attaque et de transport.

| Non armés | Armés (armement du slot dynamique livré) |
|---|---|
| `mi8` (Mi-8MTV2), `mi26` (Mi-26), `uh1` (UH-1H), `ch47` (CH-47F) | `mi24` (Mi-24P), `ka50` (Ka-50 III), `ah64` (AH-64D), `gazelle` (SA342M) |

Un type DCS écrit directement (`name Mi-8MT`) vole non armé. Un `src/spawn-groups.yaml` peut ajouter
ses propres alias, avec des `pylons`, et des groupes de plusieurs hélicoptères.

> Vérifié en jeu le 2026-10-02 : `orbit` tourne à 1,5–2 km de son point, `transport` se pose à 30 m du sien sur terrain dégagé. `patrol`, `attack` et `escort` aussi (l'escorte tourne à moins de 3 km de son groupe).

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

**Ce que la patrouille attaque.** Elle reste en patrouille, tir interdit contre les avions, tant
qu'elle n'a rien vu qui vaille l'engagement. Toutes les dix secondes elle regarde ce que son radar lui
renvoie et ne retient que des **aéronefs ennemis, en vol, à l'intérieur de son rayon de patrouille** :
ni un navire, ni un véhicule, ni un bâtiment, ni un pilote éjecté sous son parachute — même si celui-ci
appartient toujours au groupe de son avion. Les cibles retenues sont classées par priorité (chasseurs
d'abord, puis bombardiers, drones, AWACS, transports, hélicoptères), et la patrouille les engage. Dès
qu'il n'y a plus rien à engager, elle reprend sa route et repasse en riposte seulement.

Une patrouille faite à partir d'un modèle de groupe dont le premier point de route ne porte aucune
consigne vole sans les réglages voulus par l'auteur du modèle (radar, ECM, règles d'engagement). Le cas
est signalé dans le journal DCS, avec le nom du modèle en cause.

### Faire apparaître un AFAC/JTAC

```
_spawn afac, name A-10C, freq 133.0, mod AM, laser 1688, alt 15000
```

**Options :**

- `name` — type d'avion
- `freq` — fréquence radio
- `mod` — modulation (`AM` ou `FM`)
- `laser` — code laser, entre `1111` et `1688`. Les trois derniers chiffres valent chacun de 1 à 8 (pas de `0`, pas de `9`) : `1688` convient, `1690` non. Un code impossible est ignoré et le code par défaut (`1688`) reste en vigueur.
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
- `size` — nombre de véhicules (défaut : 10 ; l'alias `-convoy` tire une taille aléatoire entre 6 et 15)
- `patrol` — retour à la position de départ
- `offroad` — autoriser le déplacement hors route

#### Plusieurs étapes : écrire `dest` autant de fois qu'il faut {#convoy-itinerary}

`dest` peut être répété. Le convoi parcourt les points **dans l'ordre où vous les écrivez**, et repart de lui-même à chaque arrivée :

```
_spawn convoy, dest KOBULETI, dest BATUMI, dest POTI, speed 40
```

Un seul `dest` reste un trajet à une étape : rien ne change pour les marqueurs que vous utilisez déjà.

Deux précisions utiles :

- **`patrol` ne s'applique qu'à la dernière étape.** Patrouiller entre deux points d'un trajet contredirait le trajet lui-même.
- **Une étape part de l'endroit où le convoi se trouve**, pas de son point d'apparition — il a roulé entre-temps.

#### Les quatre commandes radio {#convoy-radio-commands}

Le menu F10 propose quatre commandes, qui font quatre choses différentes. Les deux freins en particulier ne sont pas interchangeables :

| Commande | Effet | Quand s'en servir |
|---|---|---|
| **Envoyer au point suivant** | passe à l'étape suivante immédiatement, sans attendre l'arrivée | pour accélérer une mission qui traîne |
| **Faire attendre les ordres (au point suivant)** | laisse le convoi **terminer son étape**, puis il se gare au point d'arrivée et attend | pour cadencer une mission : le convoi s'arrête à un endroit choisi |
| **Arrêter sur place** | le convoi s'immobilise **là où il est**, au milieu de la route s'il le faut | pour rattraper une mission qui part de travers |
| **Faire repartir (après un arrêt)** | reprend l'étape en cours, là où elle avait été interrompue | après un arrêt sur place |

« Faire attendre les ordres » et « Arrêter sur place » se ressemblent de loin et ne se remplacent pas : le premier choisit **où** le convoi s'arrête, le second choisit **quand**. Chaque commande annonce ce qu'elle a fait, en nommant le point concerné.

Sur la dernière étape, « Faire attendre les ordres » vous répond qu'il n'y a pas de point suivant, plutôt que de ne rien faire.

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

### Tirer une fusée de signal

```
_spawn signal, color green
```

**Couleurs :** `red` (par défaut), `green`, `white`, `yellow`. Une fusée n'a pas les couleurs de la fumée : `orange` et `blue` n'existent pas dans DCS, la commande le dit et ne tire rien.

### Faire apparaître des explosions

```
_spawn bomb, power 500, shells 3
```

### Faire apparaître un FARP

```
_spawn farp, name "FARP Alpha", side blue
```

### Faire apparaître une balise radio {#beacon}

```
_spawn beacon
_spawn beacon, name "Balise Alpha", side red
-beacon
```

Une seule commande pose **trois** balises au même endroit — ADF (VHF), UHF et **FM** — et le message
affiché vous donne les trois fréquences :

```
Balise radio en place — ADF 245.00 kHz · UHF 251.00 MHz · FM 40.50 MHz
```

La balise est posée **exactement là où vous avez déposé le marqueur**, sans dispersion, contrairement aux
commandes qui font apparaître des groupes.

!!! note "Les fréquences sont choisies par CTLD, pas par vous"
    CTLD les tire de ses propres réserves pour éviter les collisions entre balises, et n'expose aucun
    moyen d'en demander une précise. C'est pourquoi la commande **vous les annonce** au lieu de les
    accepter en paramètre : une balise dont personne ne connaît la fréquence ne sert à rien.

    Une option pour demander une fréquence est proposée en amont
    ([VEAF/CTLD#128](https://github.com/VEAF/CTLD/pull/128)) ; le jour où elle arrive, un paramètre
    `freq` sera ajouté ici.

Il faut que **CTLD soit démarré** dans la mission (`modules: CTLD: true`) : sinon la commande vous le dit
au lieu de ne rien faire.

| Option | Défaut | Description |
|--------|--------|-------------|
| `name` | CTLD numérote lui-même (« Beacon #1 ») | nom affiché de la balise |
| `side` | bleu | coalition qui entend la balise |
| `radius` | 0 | dispersion autour du marqueur, en mètres |

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

## Véhicules chauds à l'apparition {#warm-start}

Tout véhicule sol que les scripts VEAF font apparaître — commande de marqueur, zone de combat, convoi, réapparition d'un groupe de l'éditeur — part **moteur chaud** : il a une signature infrarouge dès sa première seconde et se voit au pod de désignation. C'est l'option **COLD AT START** de l'éditeur, laissée décochée, comme l'éditeur la laisse par défaut.

Pour un véhicule froid, cochez **COLD AT START** sur l'unité dans l'éditeur de mission : une réapparition garde ce choix.

Un **objet statique**, lui, n'a pas de moteur : il reste froid quoi qu'il arrive. Une cible qui doit se voir au pod doit être un groupe, pas un statique.

---

## Groupes d'avions spawnables (`src/spawnables.yaml`)

> ⚠️ À ne pas confondre avec la commande `_spawn group` (groupes **sol/hélico** de la base `veafUnits`). Ici il s'agit de **groupes d'avions** réels, cachés et en *late activation*, que `veafSpawn` **clone** à la demande en jeu.

Un **groupe d'avion spawnable** est identifié par le **préfixe de nom `veafSpawn-`** (contrat runtime de `veafSpawn`). À la construction, l'étape de pipeline `spawnable_aircrafts` injecte `src/spawnables.yaml` dans le `.miz`.

Le fichier utilise le **schéma DCS complet** des groupes d'aéronefs (`airplanes`/`helicopters` → `coalitions` → pays → groupe), identique à celui décrit dans la [Référence Pipeline — Étape 3](../../PIPELINE_REFERENCE.md#pipeline-step-3-aircraft-groups). On l'obtient en général par extraction depuis une mission :

```bash
veaf-tools content extract-aircraft-groups --kind spawnable
```

Les **modèles de slot dynamique** (`dynSpawnTemplate = true`, slots Dynamic Slots DCS) sont une famille distincte, dans `src/dynamic-slot-templates.yaml` (étape `dynamic_slot_templates`) — voir l'[ADR 0002](https://github.com/VEAF/VEAF-Mission-Creation-Tools/blob/develop/docs/adr/0002-aircraft-group-injection-sort-criteria.md).

---

## Voir aussi

- [veafMove](veafMove.md) — déplacer des groupes existants
- [Référence API Lua](../../LUA_API_REFERENCE.md) — API complète de `veafSpawn`
