# Référence Pipeline

Cette page documente les étapes optionnelles du **pipeline de build** que `veaf-tools build` peut exécuter après la génération de `veaf-config.lua`. Chaque étape injecte des données dans le fichier `.miz` à partir d'un fichier de configuration YAML séparé.

---

## Vue d'ensemble

Le pipeline exécute quatre étapes optionnelles, dans cet ordre :

| Étape | Fichier config | Ce qu'elle fait |
|-------|----------------|----------------|
| `presets` | `src/presets.yaml` | Injecte les préréglages de fréquences radio dans les groupes d'avions pilotés par des humains |
| `waypoints` | `src/waypoints.yaml` ou `waypoints.yaml` | Injecte des modèles de points de cheminement dans les groupes d'avions pilotés par des humains |
| `aircraft_groups` | `src/aircraft-templates.yaml`, `src/templates.yaml` ou `aircraft-templates.yaml` | Injecte des définitions de groupes d'aéronefs (slots/groupes à spawner) |
| `weather` | `src/missions.yaml` (legacy, prioritaire), `src/versions.yaml` ou `missions.yaml` | Crée plusieurs variantes de mission avec différentes météos et heures |

Chaque étape est **auto-détectée** : elle s'exécute si son fichier de config par défaut existe. Vous pouvez modifier ce comportement dans `mission.yaml`.

---

## Contrôle du pipeline (`mission.yaml`)

```yaml
pipeline:
  presets: false                        # ignoré même si src/presets.yaml existe
  waypoints: true                       # auto-détection : exécuté seulement si le fichier existe
  aircraft_groups:
    file: src/my-aircraft.yaml          # chemin de fichier non-standard
    mode: replace                       # add (défaut) | replace
  weather: false                        # ignorer les variantes météo
```

### Champs de `pipeline:`

| Champ | Type | Défaut | Requis | Description |
|-------|------|--------|--------|-------------|
| `presets` | bool \| objet | auto | Non | `true`/non défini = auto-détection (exécuté si fichier trouvé), `false` = toujours ignorer, objet = options personnalisées |
| `waypoints` | bool \| objet | auto | Non | `true`/non défini = auto-détection (exécuté si fichier trouvé), `false` = toujours ignorer, objet = options personnalisées |
| `aircraft_groups` | bool \| objet | auto | Non | `true`/non défini = auto-détection (exécuté si fichier trouvé), `false` = toujours ignorer, objet = options personnalisées |
| `weather` | bool \| objet | auto | Non | `true`/non défini = auto-détection (exécuté si fichier trouvé), `false` = toujours ignorer, objet = options personnalisées |

Quand la valeur est un objet, les sous-champs suivants s'appliquent :

| Sous-champ | Type | Défaut | Description |
|------------|------|--------|-------------|
| `file` | string | *(voir défauts par étape)* | Chemin vers le fichier de config, relatif au dossier mission |
| `mode` | `add` \| `replace` | `add` | *(aircraft_groups uniquement)* `add` conserve les groupes existants ; `replace` met à jour les groupes de même nom |

**Auto-détection** (quand non défini ou `true`) : l'étape ne s'exécute que si son fichier par défaut est trouvé. L'absence du fichier ignore silencieusement l'étape.

---

## Étape 1 — Préréglages radio (`presets.yaml`)

Injecte des préréglages de fréquences radio dans chaque groupe d'aéronefs contenant au moins un pilote humain (compétence Client/Player). Génère également des images de kneeboard PNG pour chaque préréglage.

### Emplacement par défaut

```
<dossier-mission>/src/presets.yaml
```

### Schéma

```yaml
# ── Définitions de canaux ──────────────────────────────────────────────────
channels_collection:
  <nom-ensemble>:                       # groupe logique de canaux (ex: airports-caucasus)
    <nom-canal>:                        # identifiant du canal
      title: "Batumi / 16X"            # libellé lisible par l'humain
      freqs:
        uhf: 260                        # fréquence UHF (MHz)
        vhf: 131                        # fréquence VHF-AM (MHz)
        fm: 40.4                        # fréquence FM (MHz)

# ── Définitions de radios ──────────────────────────────────────────────────
radios_collection:
  <nom-ensemble>:                       # groupe logique de radios (ex: blue_radios)
    <nom-radio>:                        # identifiant référencé dans presets_collection
      title: "UHF"                      # libellé affiché sur le kneeboard
      type: uhf                         # uhf | vhf | fm
      channels:
        01: Guard                       # numéro de canal → nom-canal (depuis channels_collection)
        02: Batumi

# ── Définitions de préréglages ────────────────────────────────────────────
presets_collection:
  <nom-ensemble>:                       # groupe logique de préréglages (ex: blue_presets)
    <nom-preréglage>:                   # identifiant référencé dans presets_assignments
      title: "Coalition bleue - UHF/VHF/FM"
      radios:
        radio_1: <nom-radio>            # slot → nom-radio (depuis radios_collection)
        radio_2: <nom-radio>

# ── Règles d'affectation ──────────────────────────────────────────────────
presets_assignments:
  <coalition>:                          # blue | red
    <catégorie>:                        # plane | helicopter
      all: <nom-préréglage>            # préréglage par défaut pour tous les aéronefs de ce type
      <type-aéronef>: <nom-préréglage> # surcharge pour un type DCS spécifique (ex: A-10C_2)
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

radios_collection:
  blue_radios:
    radio_uhf:
      title: UHF
      type: uhf
      channels:
        01: Guard

presets_collection:
  blue_presets:
    blue_default:
      title: Bleu par défaut
      radios:
        radio_1: radio_uhf

presets_assignments:
  blue:
    plane:
      all: blue_default
    helicopter:
      all: blue_default
```

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

Les specs couvrent 85 aéronefs pilotables et sont issues de [dcs-lua-datamine](https://github.com/Quaggles/dcs-lua-datamine). Si un aéronef n'est pas dans la base, la vérification est silencieusement ignorée.

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

## Étape 3 — Groupes d'aéronefs (`aircraft-templates.yaml`)

Injecte des définitions de groupes d'aéronefs dans la mission. Utilisé pour les groupes à spawner et les modèles de slots joueurs.

### Emplacement par défaut

```
<dossier-mission>/src/aircraft-templates.yaml

Aussi accepté : src/templates.yaml
                aircraft-templates.yaml  (racine du dossier mission)
```

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

## Étape 4 — Variantes météo & horaire (`versions.yaml`)

Crée plusieurs variantes `.miz` à partir d'une mission de base, chacune avec une configuration de temps et/ou de météo différente.

### Emplacement par défaut

```
<dossier-mission>/src/missions.yaml  (legacy, vérifié en premier)
<dossier-mission>/src/versions.yaml

Aussi accepté : missions.yaml  (racine du dossier mission)
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

## Voir aussi

- [Référence mission.yaml](MISSION_YAML_REFERENCE.md) — configuration top-level de la mission
- [Guide mission maker](mission-maker/GUIDE.md) — workflow complet
