# Référence Pipeline

Cette page documente les étapes optionnelles du **pipeline de build** que `veaf-tools build` peut exécuter après la génération de `veaf-config.lua`. Chaque étape injecte des données dans le fichier `.miz` à partir d'un fichier de configuration YAML séparé.

---

## Vue d'ensemble

Le pipeline exécute les étapes optionnelles suivantes, dans cet ordre :

| Étape | Fichier config | Ce qu'elle fait |
|-------|----------------|----------------|
| `presets` | `src/presets.yaml` | Injecte les préréglages de fréquences radio dans les groupes d'avions pilotés par des humains |
| `waypoints` | `src/waypoints.yaml` ou `waypoints.yaml` | Injecte des modèles de points de cheminement dans les groupes d'avions pilotés par des humains |
| `spawnable_aircrafts` | `src/spawnables.yaml` | Injecte les groupes d'avions **spawnables** (préfixe `veafSpawn-`, clonés par `veafSpawn`) |
| `dynamic_slot_templates` | `src/dynamic-slot-templates.yaml` | Injecte les **modèles de slot dynamique** (`dynSpawnTemplate = true`, consommés par DCS) |
| `warehouses` | `src/warehouses.yaml` | Configure les warehouses pour les slots dynamiques (Dynamic Slots) |
| `spawn_data` | `src/spawn-groups.yaml` *(optionnel)* | Injecte la base de données de spawn (`_spawn unit`/`_spawn group`) ; **toujours active** (les données du framework sont embarquées) |
| `weather` | `src/versions.yaml` ou `versions.yaml` | Crée plusieurs variantes de mission avec différentes météos et heures |

Chaque étape est **auto-détectée** : elle s'exécute si son fichier de config par défaut existe. Vous pouvez modifier ce comportement dans `mission.yaml`. **Exception** : `spawn_data` s'exécute toujours (même sans fichier mission) afin d'embarquer la base de spawn du framework ; le fichier `src/spawn-groups.yaml` ne sert qu'à l'étendre.

---

## Contrôle du pipeline (`mission.yaml`)

```yaml
pipeline:
  presets: false                        # ignoré même si src/presets.yaml existe
  waypoints: true                       # auto-détection : exécuté seulement si le fichier existe
  spawnable_aircrafts:
    file: src/my-spawnables.yaml        # chemin de fichier non-standard
    mode: replace                       # add (défaut) | replace
  dynamic_slot_templates: false         # ignorer l'injection des modèles de slot dynamique
  spawn_data: false                     # désactiver l'injection de la base de spawn (framework inclus)
  weather: false                        # ignorer les variantes météo
```

### Champs de `pipeline:`

| Champ | Type | Défaut | Requis | Description |
|-------|------|--------|--------|-------------|
| `presets` | bool \| objet | auto | Non | `true`/non défini = auto-détection (exécuté si fichier trouvé), `false` = toujours ignorer, objet = options personnalisées |
| `waypoints` | bool \| objet | auto | Non | `true`/non défini = auto-détection (exécuté si fichier trouvé), `false` = toujours ignorer, objet = options personnalisées |
| `spawnable_aircrafts` | bool \| objet | auto | Non | `true`/non défini = auto-détection (exécuté si fichier trouvé), `false` = toujours ignorer, objet = options personnalisées |
| `dynamic_slot_templates` | bool \| objet | auto | Non | `true`/non défini = auto-détection (exécuté si fichier trouvé), `false` = toujours ignorer, objet = options personnalisées |
| `spawn_data` | bool \| objet | toujours | Non | `true`/non défini = **toujours exécuté** (données framework embarquées), `false` = désactiver complètement, objet `{file: …}` = fichier mission non-standard |
| `weather` | bool \| objet | auto | Non | `true`/non défini = auto-détection (exécuté si fichier trouvé), `false` = toujours ignorer, objet = options personnalisées |

Quand la valeur est un objet, les sous-champs suivants s'appliquent :

| Sous-champ | Type | Défaut | Description |
|------------|------|--------|-------------|
| `file` | string | *(voir défauts par étape)* | Chemin vers le fichier de config, relatif au dossier mission |
| `mode` | `add` \| `replace` | `add` | *(étapes d'injection de groupes uniquement)* `add` conserve les groupes existants ; `replace` met à jour les groupes de même nom |

**Auto-détection** (quand non défini ou `true`) : l'étape ne s'exécute que si son fichier par défaut est trouvé. L'absence du fichier ignore silencieusement l'étape.

---

## Étape 1 — Préréglages radio (`presets.yaml`)

Injecte des préréglages de fréquences radio dans chaque groupe d'aéronefs contenant au moins un pilote humain (compétence Client/Player). Génère également des images de kneeboard PNG pour chaque préréglage.

### Emplacement par défaut

```
<dossier-mission>/src/presets.yaml
```

### Deux formats d'auteur

Depuis [ADR 0010](https://github.com/VEAF/VEAF-Mission-Creation-Tools/blob/develop-v6/docs/adr/0010-per-type-radio-preset-projection.md), `presets.yaml` accepte deux couches, qui coexistent :

- **`channel_lists`** (recommandé) : le mission-maker déclare une seule fois par coalition ses listes de canaux, par **rôle radio** fonctionnel (UHF principal, VHF principal, FM…), et le build projette automatiquement chaque liste sur les radios physiques de chaque type d'aéronef, en tenant compte de ses particularités matérielles. Une seule modification de fréquence se propage à toute la flotte.
- **`radios_collection` / `presets_collection` / `presets_assignments`** (historique) : le mission-maker définit lui-même, radio par radio, le contenu de chaque préréglage puis l'assigne explicitement par type d'appareil. Ce format reste entièrement supporté et sert désormais de **mécanisme de surcharge manuelle** : une affectation explicite dans `presets_assignments` pour un type donné l'emporte toujours sur la projection automatique de `channel_lists` — y compris la valeur spéciale `none` (aucune injection).

Dans tous les cas, `channels_collection` (les fréquences) reste la source commune aux deux formats.

### Schéma — `channel_lists` (modèle recommandé)

```yaml
# ── Définitions de canaux (commun aux deux formats) ────────────────────────
channels_collection:
  <nom-ensemble>:                       # groupe logique de canaux (ex: airports-caucasus)
    <nom-canal>:                        # identifiant du canal
      title: "Batumi / 16X"            # libellé lisible par l'humain
      freqs:
        uhf: 260                        # fréquence UHF (MHz)
        vhf: 131                        # fréquence VHF-AM (MHz)
        fm: 40.4                        # fréquence FM (MHz)

# ── Listes de canaux par rôle radio ─────────────────────────────────────────
channel_lists:
  <coalition>:                          # blue | red
    primary_1:                          # 1er radio V/UHF (bande uhf)
      01: Guard
      02: Batumi
    primary_2:                          # 2e radio V/UHF (bande vhf) ; aussi le radio unique des warbirds
      01: Guard
      02: Batumi
    fm_supplement:                      # FM en 3e radio, en plus de deux radios primaires (ex: A-10C)
      01: 30
    fm_substitute:                      # FM en 2e radio, à la place d'un 2e radio primaire (ex: hélicoptères)
      01: 30
    fm_secondary:                       # 2e radio FM supplémentaire (ex: OH-58D) ; par défaut, copie de fm_supplement
      01: 31
```

**Rôles radio** (vocabulaire fixe) :

| Rôle | Bande | Usage |
| --- | --- | --- |
| `primary_1` | uhf | 1er radio V/UHF |
| `primary_2` | vhf | 2e radio V/UHF ; radio unique des warbirds |
| `fm_substitute` | fm | FM à la place d'un 2e radio primaire (hélicoptères à un seul radio primaire) |
| `fm_supplement` | fm | FM en plus de deux radios primaires (appareils d'attaque, ex: A-10C) |
| `fm_secondary` | fm | 2e radio FM supplémentaire (ex: OH-58D) ; par défaut, copie de `fm_supplement` si non déclaré |

Le build assigne automatiquement chaque radio physique de chaque type d'aéronef au rôle qui lui correspond (déduit de ses plages de fréquences matérielles), puis y projette la liste de canaux déclarée pour ce rôle. Un canal qui n'a pas de fréquence pour la bande du rôle est ignoré silencieusement (signalé par `validate`).

### Schéma — format historique (surcharge manuelle)

```yaml
# ── Définitions de radios ──────────────────────────────────────────────────
radios_collection:
  <nom-ensemble>:                       # groupe logique de radios (ex: blue_radios)
    <nom-radio>:                        # identifiant référencé dans presets_collection
      title: "UHF"                      # libellé affiché sur le kneeboard
      type: uhf                         # uhf | vhf | fm
      channels:
        01: Guard                       # numéro de canal → nom-canal (depuis channels_collection)
        02: Batumi
        10: Stennis

# ── Définitions de préréglages ────────────────────────────────────────────
presets_collection:
  <nom-ensemble>:                       # groupe logique de préréglages (ex: blue_presets)
    <nom-preréglage>:                   # identifiant référencé dans presets_assignments
      title: "Coalition bleue - UHF/VHF/FM"
      radios:
        radio_1: <nom-radio>            # slot → nom-radio (depuis radios_collection)
        radio_2: <nom-radio>
        radio_3: <nom-radio>

# ── Règles d'affectation (surcharge manuelle des channel_lists) ────────────
presets_assignments:
  <coalition>:                          # blue | red
    <catégorie>:                        # plane | helicopter
      all: <nom-préréglage>            # préréglage par défaut pour tous les aéronefs de ce type
      <type-aéronef>: <nom-préréglage> # surcharge pour un type DCS exact (ex: A-10C_2) ou un pattern regex (ex: A[-]10C.*)
      <type-aéronef>: none              # désactive toute injection pour ce type (aucun équivalent en channel_lists)
```

### Exemple minimal

```yaml
channels_collection:
  common:
    Guard:
      title: Guard
      freqs:
        uhf: 243.0
        vhf: 121.5

channel_lists:
  blue:
    primary_1:
      01: Guard
```

### Valeur d'un canal

Un canal peut être défini de trois façons, dans `channel_lists` comme dans `radios_collection` :

- un **nom de canal** (alias résolu depuis `channels_collection`) : `01: Guard` ;
- une **fréquence** directe (MHz) : `01: 243.0` ;
- un **objet** : `01: { freq: 243.0, mod: 1 }`, où `mod` est la modulation (`0` = AM, `1` = FM). Le champ `mod` est optionnel ; absent, DCS utilise sa valeur par défaut.

### Conversion v5 iso-fonctionnelle (`convert-v5`)

Pour les agencements radio **standards** (canaux 1:1 d'une table de préréglages), `convert-v5` génère une affectation partagée légère. Pour les agencements **sur mesure** — rotation de canaux (Mi-24P canal 0 → préréglage #20), canal factice initial / fréquences en dur / modulations AM-FM par canal (AJS37), ou radios supplémentaires — il génère un **préréglage dédié `{coalition}_{aéronef}`** reproduisant exactement la carte canal → fréquence (y compris les `mod`), pour rester iso-fonctionnel avec la mission v5 (voir ADR 0003).

### Validation des fréquences

Lors de l'injection, chaque fréquence assignée à un aéronef est vérifiée par rapport aux spécifications matérielles de ses radios.

**Comportement par défaut (build normal) :**

- **Appareils critiques** (`dcs_rejects_on_load: true` dans les specs) : si une fréquence est hors plage, un `WARNING` est émis dans le log. Ce sont les appareils pour lesquels DCS lance une erreur au chargement de la mission.
- **Autres appareils** : la validation est silencieuse — DCS stocke les fréquences mais ne les utilise pas pour les radios hors plage, sans crasher.

**Rapport automatique :**

Après chaque injection de presets, un fichier `presets-validation-report.md` est automatiquement créé dans le dossier mission si au moins un appareil (critique ou non) présente des fréquences hors plage. Ce fichier liste tous les problèmes avec les valeurs invalides et un extrait YAML pour les désactiver temporairement. Si aucun problème n'est détecté, le fichier est supprimé.

```
<dossier-mission>/presets-validation-report.md
```

**Désactiver temporairement l'injection pour un appareil :**

Pendant que vous corrigez les presets, vous pouvez désactiver l'injection pour un type d'appareil en lui affectant la valeur `none` dans `presets_assignments` :

```yaml
presets_assignments:
  blue:
    plane:
      MiG-19P: none   # DCS rejetera les fréquences standard — à corriger
```

Une fois les presets corrigés, supprimez la ligne `none` pour réactiver l'injection.

Les specs couvrent 87 aéronefs pilotables et sont issues de [dcs-lua-datamine](https://github.com/Quaggles/dcs-lua-datamine). Si un aéronef n'est pas dans la base, la vérification est silencieusement ignorée.

> **Voir aussi** : [`doc/mission-maker/dcs-radio-specs.md`](mission-maker/dcs-radio-specs.md) — table de référence complète des plages de fréquences valides et liste des appareils critiques.  
> Pour régénérer après une mise à jour DCS : `poetry run update-radio-specs`

---

## Étape 2 — Points de cheminement (`waypoints.yaml`)

Injecte des modèles de points de cheminement dans les groupes d'aéronefs pilotés par des humains. Seuls les groupes avec au moins une unité Client/Player sont modifiés.

### Emplacement par défaut

```
<dossier-mission>/src/waypoints.yaml

Aussi accepté : waypoints.yaml  (racine du dossier mission)
```

### Schéma

```yaml
# ── Définitions de waypoints ───────────────────────────────────────────────
waypoints:
  <NOM_WAYPOINT>:
    type: "Turning Point"               # type de waypoint DCS
    action: "Turning Point"             # action de waypoint DCS
    alt: 6096                           # altitude en mètres
    alt_type: "BARO"                    # BARO | RADIO
    speed: 200                          # vitesse en m/s
    speed_type: "TAS"                   # TAS | IAS
    x: 75869                            # coordonnée X mission
    y: 48674                            # coordonnée Y mission
    name: "BULLSEYE"                    # libellé du waypoint (optionnel)
    ETA: 364.89                         # temps d'arrivée estimé en secondes (optionnel)
    ETA_locked: false                   # verrouiller l'ETA (optionnel)

# ── Affectations de plans de vol ───────────────────────────────────────────
settings:
  <NOM_PLAN>:
    category: "plane"                   # plane | helicopter (filtre optionnel)
    coalition: "blue"                   # blue | red (filtre optionnel)
    type: "F-16C_50"                    # type d'aéronef DCS (filtre optionnel)
    country: "USA"                      # nom du pays (filtre optionnel)
    waypoints:
      <NOM_WAYPOINT>: "<NOM_WAYPOINT>"  # associer la définition du waypoint au slot
```

### Priorité de correspondance

Les plans de vol sont associés aux groupes selon cet ordre de priorité :
1. Type d'aéronef (`type`)
2. Catégorie d'aéronef (`category`)
3. Coalition (`coalition`)
4. Pays (`country`)
5. Tous les autres groupes (sans filtre = joker)

### Exemple minimal

```yaml
waypoints:
  BULLSEYE:
    type: "Turning Point"
    action: "Turning Point"
    alt: 6096
    alt_type: "BARO"
    speed: 999
    speed_type: "TAS"
    x: 75869
    y: 48674
    name: "BULLSEYE"

settings:
  AVIONS_BLEUS:
    category: "plane"
    coalition: "blue"
    waypoints:
      BULLSEYE: "BULLSEYE"
```

---

## Étape 3 — Groupes d'aéronefs : spawnables (B) et modèles de slot dynamique (C)

Deux **usages distincts** de groupes d'aéronefs injectés, gérés par deux étapes indépendantes (voir [ADR 0002](https://github.com/VEAF/VEAF-Mission-Creation-Tools/blob/develop-v6/docs/adr/0002-aircraft-group-injection-sort-criteria.md)) :

- **(B) groupes spawnables** (`src/spawnables.yaml`, étape `spawnable_aircrafts`) : vrais groupes cachés, clonés à la demande en jeu par `veafSpawn`. Marqueur : préfixe de nom `veafSpawn-`.
- **(C) modèles de slot dynamique** (`src/dynamic-slot-templates.yaml`, étape `dynamic_slot_templates`) : groupes servant de **modèle** aux Dynamic Slots DCS, consommés nativement par le moteur. Marqueur : flag DCS `dynSpawnTemplate = true`.

À l'extraction (`extract-aircraft-groups`), chaque groupe est routé vers l'une des deux familles selon ce critère (le flag prime sur le préfixe) ; les autres groupes sont ignorés. Par défaut, l'extraction produit **les deux** fichiers ; l'option `--kind spawnable|dynamic-template` en restreint un seul. L'ancien tri par nom `.*[tT]emplate.*` est abandonné (il misroutait un spawnable nommé « … Template … »).

### Emplacements par défaut

```
<dossier-mission>/src/spawnables.yaml              # (B) spawnable_aircrafts
<dossier-mission>/src/dynamic-slot-templates.yaml  # (C) dynamic_slot_templates
```

> **Rupture v6** : les anciens noms `src/aircraft-templates.yaml` / `src/templates.yaml` et l'étape `aircraft_groups` ne sont plus utilisés. `convert-v5` produit directement les deux nouveaux fichiers.

### Modes d'injection

| Mode | Comportement |
|------|-------------|
| `add` *(défaut)* | Ajoute tous les groupes du fichier ; les groupes existants sont conservés |
| `replace` | Les groupes portant le même nom dans la mission sont mis à jour ; les autres sont conservés |

### Schéma

```yaml
airplanes:
  coalitions:
    <coalition>:                        # blue | red
      <Nom Pays>:                       # nom de pays DCS (ex: "France", "USA")
        <Nom Groupe>:
          name: "Nom Groupe"            # REQUIS — doit correspondre à la clé
          type: "M-2000C"               # REQUIS — type d'aéronef DCS principal
          units:                        # REQUIS — au moins une unité
            - type: "M-2000C"
              name: "Pilote-1"
            - type: "M-2000C"
              name: "Pilote-2"

helicopters:
  coalitions:
    <coalition>:
      <Nom Pays>:
        <Nom Groupe>:
          name: "Nom Groupe"
          type: "UH-1H"
          units:
            - type: "UH-1H"
              name: "Helo-1"
```

### Exemple minimal

```yaml
airplanes:
  coalitions:
    blue:
      France:
        Vol-Mirage:
          name: "Vol-Mirage"
          type: "M-2000C"
          units:
            - type: "M-2000C"
              name: "Mirage-1"
            - type: "M-2000C"
              name: "Mirage-2"
```

---

## Étape 6 — Variantes météo & horaire (`versions.yaml`)

Crée plusieurs variantes `.miz` à partir d'une mission de base, chacune avec une configuration de temps et/ou de météo différente.

### Emplacement par défaut

```
<dossier-mission>/src/versions.yaml

Aussi accepté : versions.yaml  (racine du dossier mission)
```

### Schéma

```yaml
# ── Position géographique pour les calculs solaires ────────────────────────
position:
  latitude: 33.5                        # degrés décimaux, -90 à 90
  longitude: 35.5                       # degrés décimaux, -180 à 180
  timezone: "Asia/Damascus"             # fuseau horaire IANA

# ── Date de base pour toutes les versions ─────────────────────────────────
base_date: "2024-03-15"                 # ISO 8601 (AAAA-MM-JJ)

# ── Variantes de mission ───────────────────────────────────────────────────
versions:
  - name: aube                          # REQUIS — nom du fichier de sortie (sans .miz)
    time: "sunrise+30*60"               # expression horaire (voir ci-dessous)
    date: "today"                       # expression de date (voir ci-dessous, optionnel)
    metar: "METAR OSDI 151420Z 27015G25KT 9999 SKC 15/10 Q1018"  # optionnel

  - name: midi
    time: "12:00"
    weather:                            # météo manuelle (alternative au metar)
      temperature: 25.0                 # °C, plage -50..50
      wind_speed: 8.0                   # m/s
      wind_direction: 270.0             # degrés (0=Nord)
      visibility: 9999                  # mètres
      cloud_type: "clear"               # clear | few | scattered | broken | overcast
      cloud_height: 2000                # base des nuages en mètres
      fog_enabled: false                # activer l'effet de brouillard
```

### Champs de `versions[]`

| Champ | Type | Requis | Description |
|-------|------|--------|-------------|
| `name` | string | Oui | Nom du fichier de sortie (sans `.miz`) ; ex: `aube` → `aube.miz` |
| `time` | string | Non | Expression horaire — voir ci-dessous |
| `date` | string | Non | Expression de date — voir ci-dessous |
| `metar` | string | Non | Chaîne METAR complète — analysée pour les données météo |
| `weather` | objet | Non | Surcharge météo manuelle (utilisée sans `metar`) |

### Expressions horaires

| Format | Exemple | Signification |
|--------|---------|--------------|
| `HH:MM` | `14:30` | Heure absolue (14h30 heure locale) |
| `sunrise` | `sunrise` | Heure du lever du soleil (nécessite `position:`) |
| `sunset` | `sunset` | Heure du coucher du soleil (nécessite `position:`) |
| Expression | `sunrise+30*60` | Arithmétique — décalage en secondes |
| Secondes | `54000` | Secondes brutes depuis minuit |

### Expressions de date

| Format | Exemple | Signification |
|--------|---------|--------------|
| ISO 8601 | `2024-03-15` | Date spécifique |
| Mot-clé | `today`, `tomorrow`, `yesterday` | Relatif à la date d'exécution |
| Relatif | `+1`, `-7` | Jours depuis `base_date` |

### Champs de l'objet `weather`

| Champ | Type | Description |
|-------|------|-------------|
| `temperature` | nombre | Température de l'air en °C |
| `wind_speed` | nombre | Vitesse du vent en m/s |
| `wind_direction` | nombre | Direction du vent en degrés (0 = Nord) |
| `visibility` | nombre | Visibilité en mètres |
| `cloud_type` | string | `clear` \| `few` \| `scattered` \| `broken` \| `overcast` |
| `cloud_height` | nombre | Altitude de la base des nuages en mètres |
| `fog_enabled` | booléen | Activer l'effet de brouillard |

### Exemple minimal

```yaml
position:
  latitude: 42.3
  longitude: 43.4
  timezone: "Asia/Tbilisi"

base_date: "2024-06-01"

versions:
  - name: aube
    time: "sunrise+20*60"
    metar: "METAR UGTB 010500Z 27010KT 9999 FEW030 18/10 Q1016"

  - name: après-midi
    time: "15:00"
    weather:
      temperature: 28.0
      wind_speed: 5.0
      wind_direction: 180.0
      cloud_type: "few"
      cloud_height: 2500
```

---

## Étape 4 — Warehouses Dynamic-Slot (`warehouses.yaml`)

Configure les **Dynamic Slots** DCS par coalition. S'exécute **après** l'injection
des aéronefs (pour que les groupes `dynSpawnTemplate` existent déjà) et modifie les
`warehouses` de la mission : active `dynamicSpawn` sur les aérodromes choisis, fixe
carburant / munitions et le stock d'aéronefs, et lie chaque type d'aéronef proposé
à son groupe-modèle via `linkDynTempl`.

### Emplacement par défaut

`src/warehouses.yaml` (auto-activé si présent ; désactiver avec `pipeline: { warehouses: false }`).

### Schéma

```yaml
<coalition>:                 # blue | red | neutral. Une coalition non déclarée est laissée intacte.
  defaults:                  # appliqué à chaque aérodrome sélectionné
    fuel: unlimited          # optionnel -> unlimitedFuel
    weapons: unlimited       # optionnel -> unlimitedMunitions
    aircrafts:               # types d'aéronefs proposés en slot dynamique
      <type DCS>: { amount: unlimited | <entier>, template: "<nom de groupe>" }
  airports:                  # optionnel. Absent -> TOUS les aérodromes de la coalition reçoivent `defaults`.
    <nom ou id>: { }                        # defaults seuls
    <nom ou id>: { aircrafts: { ... } }     # defaults + override par aérodrome
```

- `template` référence un groupe-modèle par **nom** ; omettez-le pour l'auto-matcher
  à un groupe-modèle du même **type d'aéronef** (même coalition).
- Les aérodromes ne peuvent être nommés que sur les théâtres installés présents dans
  la table committée (`veaf-build update-dcs-data --airdromes`) ; sinon utilisez l'id
  numérique (visible dans les `warehouses` de la mission : `airports[<id>]`).

### Exemple minimal

```yaml
blue:
  defaults:
    fuel: unlimited
    aircrafts:
      UH-1H: { amount: unlimited, template: "DST - UH-1H" }
  airports:
    Senaki-Kolkhi: {}
```

---

## Étape 5 — Données de spawn (`spawn-groups.yaml`)

Les commandes marqueurs `_spawn unit <alias>` et `_spawn group <alias>` s'appuient sur deux tables Lua (`veafUnits.UnitsDatabase` et `veafUnits.GroupsDatabase`). Depuis la v6, ces tables ne sont plus codées en dur dans `veafUnits.lua` : elles proviennent d'un YAML, sont rendues en Lua et **injectées dans le `.miz` au build de la mission** (DCS ne sait pas lire du YAML à l'exécution). Voir [ADR 0005](https://github.com/VEAF/VEAF-Mission-Creation-Tools/blob/develop-v6/docs/adr/0005-spawn-data-externalization.md).

### Toujours active

Contrairement aux autres étapes, `spawn_data` s'exécute **toujours** (même sans fichier mission) car la base de spawn du framework doit être embarquée pour que `_spawn` fonctionne. Pour la désactiver entièrement :

```yaml
pipeline:
  spawn_data: false
```

### Étendre la base (`src/spawn-groups.yaml`)

Un fichier `src/spawn-groups.yaml` (optionnel) permet d'ajouter ou de redéfinir des unités/groupes pour une mission donnée. Il est **fusionné par-dessus** les données du framework :

- un alias inédit est **ajouté** ;
- un alias déjà présent dans le framework **remplace** l'entrée correspondante (override).

### Schéma

```yaml
units:                              # -> _spawn unit <alias>
  - aliases: [myaaa]                # un ou plusieurs alias (insensibles à la casse)
    unitType: ZSU-23-4 Shilka       # un type d'unité DCS

groups:                             # -> _spawn group <alias>
  - aliases: [mysam]
    disposition: {h: 3, w: 3}       # grille de placement en cellules (10m x 10m)
    units:
      - {type: ZSU-23-4 Shilka, cell: 1}
      - {type: Ural-375, random: true}                       # placé aléatoirement dans sa cellule
      - {type: Soldier M4, number: {min: 2, max: 4}, random: true}
    description: Mon site SAM
    groupName: MySAM
```

Champs d'une unité de groupe : `type` (requis), `cell` (cellule préférée), `number` (quantité, ou `{min, max}` aléatoire), `hdg` (cap), `size` (taille de cellule fixe en m), `random` (placement aléatoire dans la cellule), `fitToUnit` (cellule ajustée à l'emprise exacte de l'unité).

La base du framework est définie dans `veaf_libs/data/veaf-units.yaml` (embarqué dans l'outil).

---

## Voir aussi

- [Référence mission.yaml](MISSION_YAML_REFERENCE.md) — configuration top-level de la mission
- [Guide mission maker](mission-maker/GUIDE.md) — workflow complet
