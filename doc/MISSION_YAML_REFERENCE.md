# Référence mission.yaml

`mission.yaml` est le fichier de configuration optionnel de build-time pour veaf-tools. Placez-le à la racine de votre dossier mission, à côté de `veaf-tools-updater.exe`. S'il est absent, `veaf-tools build` fonctionne avec les paramètres par défaut.

Cette page couvre les **sections de premier niveau** de `mission.yaml`. La configuration des modules Lua individuels est documentée dans la page de chaque module (voir l'[index par module](#index-par-module) ci-dessous).

---

## Comprendre le paysage des fichiers YAML

Un dossier de mission VEAF utilise **deux catégories distinctes** de fichiers YAML. Comprendre cette distinction vous aide à savoir quel fichier modifier pour une tâche donnée.

### Catégorie A — Fichiers de pipeline de build

Ces fichiers pilotent les étapes **d'injection au moment du build** que `veaf-tools build` effectue avant d'écrire le `.miz` final. Chaque étape lit son propre fichier YAML et injecte des données dans la mission. Ils sont listés sous la section `pipeline:` de `mission.yaml`.

| Fichier (dans `src/`) | Étape de pipeline | Rôle |
|-----------------------|---------------|------|
| `waypoints.yaml` | `waypoints` | Injecte les waypoints nommés dans la mission |
| `presets.yaml` | `presets` | Configure les presets radio de chaque groupe d'avions |
| `aircraft-templates.yaml` | `aircraft_groups` | Définit les templates de groupes d'avions |
| `versions.yaml` | `weather` | Génère une variante `.miz` par preset météo |

Ces fichiers **ne sont pas** chargés à l'exécution dans DCS — ils sont consommés par `veaf-tools build` puis compilés dans le `.miz`.

### Catégorie B — Configuration des modules runtime (ce fichier)

`mission.yaml` lui-même configure **le comportement des modules Lua VEAF lors de l'exécution dans DCS**. Il est traduit au moment du build en `veaf-config.lua`, injecté dans la mission et exécuté au chargement par DCS.

Les sections `lua_modules:`, `qra:`, `assets:`, `shortcuts:` décrivent toutes le comportement des modules à l'exécution.

```
dossier mission/
├── mission.yaml          ← config des modules runtime (CE FICHIER)
│   └── pipeline:
│       ├── waypoints: true  ──► src/waypoints.yaml       (injection build-time)
│       ├── presets:  true   ──► src/presets.yaml          (injection build-time)
│       ├── aircraft_groups: true  ──► src/aircraft-templates.yaml
│       └── weather:  true   ──► src/versions.yaml
└── src/
    ├── waypoints.yaml
    ├── presets.yaml
    ├── aircraft-templates.yaml
    └── versions.yaml
```

---

## Exemple minimal fonctionnel

```yaml
# mission.yaml — configuration minimale viable
global_log_level: debug           # supprimer avant de déployer aux joueurs

mission:
  name: "Ma-Mission"

security:
  disabled: true

lua_modules:
  RADIO:
    enable: true
  ASSETS:
    enable: true
    assets:
      - sort: 1
        name: "Texaco"
        description: "Texaco (KC-135)"
        information: 'Tacan 51Y\nU251.00 (21)'
```

---

## Erreurs de syntaxe

Si `mission.yaml` contient une erreur de syntaxe YAML (mauvaise indentation, deux-points manquant, caractère de tabulation…), `veaf-tools build` s'arrête immédiatement et affiche un message clair indiquant le nom du fichier, la ligne et la colonne du problème, ainsi qu'une aide en langage courant pour corriger l'erreur :

```
Erreur de syntaxe dans mission.yaml, ligne 81, colonne 4.
  L'erreur débute vers la ligne 34, colonne 3.
  → Vérifiez l'indentation autour de ces lignes. YAML utilise uniquement des espaces (jamais de tabulations).
    Tous les éléments d'un même bloc doivent être alignés à la même colonne.
```

Causes fréquentes :

| Symptôme | Cause | Correction |
|----------|-------|------------|
| astuce `indentation` | Un bloc est indenté différemment du reste | Aligner la clé avec ses voisines |
| astuce `tabulation` | Un caractère de tabulation a été utilisé à la place d'espaces | Remplacer toutes les tabulations par des espaces dans l'éditeur |
| astuce `deux-points` | Il manque le séparateur `:` après une clé | Écrire `clé: valeur` et non `clé valeur` |

!!! tip
    La plupart des éditeurs de texte peuvent visualiser les caractères d'espacement — activez cette option pour repérer rapidement les mélanges tabulations/espaces.

---

## Sections de premier niveau

### `global_log_level`

Force un niveau de log sur tous les modules VEAF. Supprimer avant de déployer aux joueurs.

```yaml
global_log_level: debug     # error | warning | info | debug | trace
```

| Valeur | Description |
|--------|-------------|
| `error` | Erreurs uniquement |
| `warning` | Erreurs et avertissements |
| `info` | Messages opérationnels standard *(défaut en production)* |
| `debug` | Activité détaillée des modules — utiliser pendant le développement |
| `trace` | Extrêmement verbeux — utiliser pour tracer des problèmes spécifiques |

---

### `mission:`

Champs d'identité de la mission utilisés dans les menus radio, les messages de log et les chemins d'export.

```yaml
mission:
  name: "Ma-Mission"          # affiché dans les menus radio et les messages de log
  export_path: null           # null = chemin DCS Saved Games par défaut
  era: MODERN                 # MODERN | COLD_WAR | WW2
  language: fr                # locale pour les messages générés (optionnel)
```

| Champ | Type | Défaut | Requis | Description |
|-------|------|--------|--------|-------------|
| `name` | string | — | Non | Nom de la mission affiché dans les menus et les logs |
| `export_path` | string \| null | `null` | Non | Surcharge le chemin d'export DCS Saved Games |
| `era` | string | `MODERN` | Non | `MODERN` \| `COLD_WAR` \| `WW2` — affecte les groupes disponibles au spawn |
| `language` | string | `en` | Non | Locale pour les messages radio générés |

---

### `security:`

Contrôle le système de sécurité VEAF. Par défaut, la sécurité est désactivée (tous les joueurs ont accès complet).

```yaml
security:
  disabled: true                    # true = aucun mot de passe requis (défaut)
  password_hashes:                  # hashes SHA-256 pour l'accès joueur/JTF
    - "e3b0c44298fc1c149afbf4c8996fb924..."
  password_mm_hashes:               # hashes SHA-256 pour l'accès Mission Master
    - "e3b0c44298fc1c149afbf4c8996fb924..."
```

| Champ | Type | Défaut | Requis | Description |
|-------|------|--------|--------|-------------|
| `disabled` | booléen | `true` | Non | `true` = aucun mot de passe requis |
| `password_hashes` | string[] | `[]` | Non | Hashes SHA-256 pour l'accès joueur |
| `password_mm_hashes` | string[] | `[]` | Non | Hashes SHA-256 pour l'accès Mission Master |

> Pour générer un hash SHA-256 : `echo -n "votremotdepasse" | sha256sum` (Linux/macOS) ou utilisez un outil en ligne.

---

### `settings:`

Paires clé-valeur arbitraires injectées dans la mission sous forme `veaf.config.CLÉ = valeur`. Utilisez ceci pour passer des constantes spécifiques à la mission aux scripts Lua.

```yaml
settings:
  MON_FLAG_MISSION: 42
  ACTIVER_CONVOI: true
  PHASE_MISSION: "alpha"
```

Chaque clé devient `veaf.config.MON_FLAG_MISSION = 42` dans le `veaf-config.lua` généré.

---

### `external_modules:`

Configuration des modules Lua tiers intégrés via VEAF.

```yaml
external_modules:
  skynet:
    enabled: false
    include_red_in_radio: false      # ajouter l'état IADS ROUGE au menu F10
    debug_red: false                 # debug Skynet verbeux pour ROUGE
    include_blue_in_radio: false     # ajouter l'état IADS BLEU au menu F10
    debug_blue: false                # debug Skynet verbeux pour BLEU
  ctld:
    enabled: false
    # toute paire ctld.xxx = valeur peut être ajoutée ici
    # ex: hoverPickup: true
```

#### Champs de `external_modules.skynet`

| Champ | Type | Défaut | Description |
|-------|------|--------|-------------|
| `enabled` | booléen | `false` | Activer l'intégration Skynet IADS |
| `include_red_in_radio` | booléen | `false` | Ajouter l'état IADS ROUGE au menu radio F10 |
| `debug_red` | booléen | `false` | Activer le debug Skynet verbeux pour la coalition ROUGE |
| `include_blue_in_radio` | booléen | `false` | Ajouter l'état IADS BLEU au menu radio F10 |
| `debug_blue` | booléen | `false` | Activer le debug Skynet verbeux pour la coalition BLEU |

#### Champs de `external_modules.ctld`

| Champ | Type | Défaut | Description |
|-------|------|--------|-------------|
| `enabled` | booléen | `false` | Activer l'intégration CTLD |
| *(toute propriété ctld)* | quelconque | — | Toute propriété `ctld.xxx` (ex: `hoverPickup: true`) |

> La configuration CSAR n'est pas encore disponible via `mission.yaml` — configurez-la directement dans `mission-script.lua`.

---

### `veaf_tools:`

Contrainte de compatibilité de version pour `veaf-tools-updater.exe`. Le metteur à jour ignore les versions qui ne correspondent pas.

```yaml
veaf_tools:
  version: "6"          # accepter tout 6.x.x
```

| Format | Exemple | Signification |
|--------|---------|--------------|
| Majeur uniquement | `"6"` | Tout `6.x.x` |
| Majeur.Mineur | `"6.1"` | Tout `6.1.x` |
| Exact | `"6.1.3"` | Exactement `6.1.3` |
| Compatible | `"^6.1.3"` | `>=6.1.3, <7.0.0` |
| Approximatif | `"~6.1.3"` | `>=6.1.3, <6.2.0` |

---

### `lua_modules:`

Activer, désactiver ou configurer les modules Lua VEAF individuels. Les modules non listés sont activés avec leurs paramètres par défaut.

```yaml
lua_modules:
  RADIO:
    enable: true
    logLevel: info            # surcharge optionnelle du niveau de log par module
    init:
      help_menus: true
  SPAWN:
    enable: true
    logLevel: debug
```

Les champs `enable` et `logLevel` sont disponibles pour chaque module. Les champs supplémentaires `init:` ou de données sont spécifiques à chaque module — voir la page de documentation de chaque module.

**Champs communs (tous les modules) :**

| Champ | Type | Défaut | Description |
|-------|------|--------|-------------|
| `enable` | booléen | `true` | Activer ou désactiver ce module |
| `logLevel` | string | *(global)* | Surcharger le niveau de log pour ce module uniquement |

**IDs de modules :**

| ID | Module | Page doc |
|----|--------|----------|
| `RADIO` | veafRadio | [veafRadio](mission-maker/scripts/veafRadio.md) |
| `SHORTCUTS` | veafShortcuts | [veafShortcuts](mission-maker/scripts/veafShortcuts.md) |
| `NAMEDPOINTS` | veafNamedPoints | [veafNamedPoints](mission-maker/scripts/veafNamedPoints.md) |
| `ASSETS` | veafAssets | [veafAssets](mission-maker/scripts/veafAssets.md) |
| `CARRIER` | veafCarrierOperations | [veafCarrierOperations](mission-maker/scripts/veafCarrierOperations.md) |
| `SANCTUARY` | veafSanctuary | [veafSanctuary](mission-maker/scripts/veafSanctuary.md) |
| `COMBATZONE` | veafCombatZone | [veafCombatZone](mission-maker/scripts/veafCombatZone.md) |
| `AIRWAVES` | veafAirWaves | [veafAirWaves](mission-maker/scripts/veafAirWaves.md) |
| `QRA` | veafQraManager | [veafQraManager](mission-maker/scripts/veafQraManager.md) |
| `CASMISSION` | veafCasMission | [veafCasMission](mission-maker/scripts/veafCasMission.md) |
| `SPAWN` | veafSpawn | [veafSpawn](mission-maker/scripts/veafSpawn.md) |
| `MOVE` | veafMove | [veafMove](mission-maker/scripts/veafMove.md) |
| `SECURITY` | veafSecurity | [veafSecurity](mission-maker/scripts/veafSecurity.md) |
| `GRASS` | veafGrass | [veafGrass](mission-maker/scripts/veafGrass.md) |
| `WEATHER` | veafWeather | [veafWeather](mission-maker/scripts/veafWeather.md) |
| `INTERPRETER` | veafInterpreter | [veafInterpreter](mission-maker/scripts/veafInterpreter.md) |
| `MISSILEGUARDIAN` | veafMissileGuardian | [veafMissileGuardian](mission-maker/scripts/veafMissileGuardian.md) |

---

### `qra:`, `cap_missions:`, `combat_missions:`

Sections de premier niveau pour les définitions QRA, missions CAP et missions de combat. Ces sections nécessitent les modules correspondants activés dans `lua_modules:`.

Voir les pages respectives pour le schéma complet :
- [`qra:`](mission-maker/scripts/veafQraManager.md#configuration-missionyaml) — définitions Quick Reaction Alert
- [`cap_missions:` et `combat_missions:`](mission-maker/scripts/veafCasMission.md#configuration-missionyaml) — définitions de missions CAP et de combat

---

### `pipeline:`

Contrôle les étapes optionnelles du pipeline de build. Voir la [Référence Pipeline](PIPELINE_REFERENCE.md) pour le schéma complet des fichiers de configuration de chaque étape.

```yaml
pipeline:
  presets: false
  waypoints: true
  aircraft_groups:
    file: src/my-aircraft.yaml
    mode: replace
  weather: false
```

---

### `build:`

Contrôle la façon dont `veaf-tools build` résout le bundle de scripts VEAF.
Ces paramètres sont normalement définis via la CLI (`--dev-mode`, `--scripts-path`) puis persistés automatiquement.

| Champ | Type | Défaut | Description |
|-------|------|---------|-------------|
| `dev_mode` | `bool` | `false` | Si `true`, les scripts sont chargés depuis `<scripts_path>/build/veaf-scripts.lua` au lieu de la copie publiée |
| `scripts_path` | `string` | *(config utilisateur)* | Chemin vers un clone local de VEAF-Mission-Creation-Tools ; requis quand `dev_mode: true` |

Ordre de résolution de `scripts_path` (premier trouvé appliqué) :
1. Option CLI `--scripts-path <chemin>`
2. `mission.yaml build.scripts_path`
3. `~/veafmct.yaml scripts_path`

```yaml
build:
  dev_mode: true
  scripts_path: C:/dev/VEAF-Mission-Creation-Tools
```

> Voir la section [Mode développeur](developer/GUIDE.fr.md#mode-développeur) du Guide du développeur pour le workflow complet.

---

### `profiles:`

Profils de build nommés. Chaque profil est un ensemble de surcharges qui fusionnent en profondeur sur la `mission.yaml` de base lorsque vous passez `--profile <nom>` à `veaf-tools build`. Les clés absentes du profil conservent leur valeur de base. Les listes sont remplacées intégralement, pas concaténées. La clé `profiles:` elle-même n'est jamais transmise au générateur Lua ni au pipeline.

| Champ | Type | Description |
|-------|------|-------------|
| `profiles.<nom>` | `dict` | N'importe quelle clé de premier niveau de `mission.yaml` (ex : `global_log_level`, `security`, `pipeline`) |

**Règles de fusion**
- Les dicts imbriqués sont fusionnés récursivement (seules les clés spécifiées sont surchargées).
- Les valeurs scalaires et les listes sont remplacées en totalité.
- `profiles:` est retiré de la config effective — il n'est jamais passé au générateur Lua ni au pipeline.

```yaml
profiles:
  TEST:
    global_log_level: debug
    security:
      disabled: true
    pipeline:
      weather: false
  SERVER:
    global_log_level: info
    pipeline:
      weather: true
```

Usage :

```powershell
veaf-tools.exe build --profile TEST
veaf-tools.exe build --profile SERVER
```

> Si le profil nommé n'existe pas dans `mission.yaml`, un avertissement est émis et la config de base est utilisée sans modification.

---

## Index par catégorie

### Essentiel — toute mission

| Section / Champ | Description |
|-----------------|-------------|
| [`global_log_level`](#global_log_level) | Forcer un niveau de log sur tous les modules |
| [`mission:`](#mission) | Nom, ère, chemin d'export |
| [`security:`](#security) | Activer/désactiver la sécurité, hashes de mots de passe |
| `lua_modules.RADIO` | [veafRadio](mission-maker/scripts/veafRadio.md) |
| `lua_modules.ASSETS` | [veafAssets](mission-maker/scripts/veafAssets.md) |
| `pipeline.presets` | [schéma presets.yaml](PIPELINE_REFERENCE.md#étape-1--préréglages-radio-presetsyaml) |
| `pipeline.waypoints` | [schéma waypoints.yaml](PIPELINE_REFERENCE.md#étape-2--points-de-cheminement-waypointsyaml) |

### Courant — la plupart des missions

| Section / Champ | Description |
|-----------------|-------------|
| [`settings:`](#settings) | Constantes mission → `veaf.config.XXX` |
| `lua_modules.SHORTCUTS` | [veafShortcuts](mission-maker/scripts/veafShortcuts.md) |
| `lua_modules.NAMEDPOINTS` | [veafNamedPoints](mission-maker/scripts/veafNamedPoints.md) |
| `lua_modules.QRA` + [`qra:`](#qra-cap_missions-combat_missions) | [veafQraManager](mission-maker/scripts/veafQraManager.md) |
| `lua_modules.COMBATZONE` | [veafCombatZone](mission-maker/scripts/veafCombatZone.md) |
| `lua_modules.CARRIER` | [veafCarrierOperations](mission-maker/scripts/veafCarrierOperations.md) |

### Avancé — cas spécifiques

| Section / Champ | Description |
|-----------------|-------------|
| `lua_modules.AIRWAVES` | [veafAirWaves](mission-maker/scripts/veafAirWaves.md) |
| `lua_modules.SANCTUARY` | [veafSanctuary](mission-maker/scripts/veafSanctuary.md) |
| `lua_modules.MISSILEGUARDIAN` | [veafMissileGuardian](mission-maker/scripts/veafMissileGuardian.md) |
| [`external_modules:`](#external_modules) | Skynet IADS, CTLD |
| [`veaf_tools:`](#veaf_tools) | Contrainte de version |
| `pipeline.aircraft_groups` | [schéma aircraft-templates.yaml](PIPELINE_REFERENCE.md#étape-3--groupes-daéronefs-aircraft-templatesyaml) |
| `pipeline.weather` | [schéma versions.yaml](PIPELINE_REFERENCE.md#étape-4--variantes-météo--horaire-versionsyaml) |
| [`build:`](#build) | Mode développeur et chemin des scripts |
| `build.dev_mode` | Utiliser le bundle Lua local au lieu des scripts publiés |
| `build.scripts_path` | Chemin vers un clone local de VEAF-Mission-Creation-Tools |
| [`profiles:`](#profiles) | Profils de build nommés (surcharges deep-merge pour `--profile`) |

---

## Index par module

| Module | Clé mission.yaml | Page doc |
|--------|-----------------|----------|
| veafRadio | `lua_modules.RADIO` | [veafRadio](mission-maker/scripts/veafRadio.md#configuration-missionyaml) |
| veafShortcuts | `lua_modules.SHORTCUTS` | [veafShortcuts](mission-maker/scripts/veafShortcuts.md#configuration-missionyaml) |
| veafNamedPoints | `lua_modules.NAMEDPOINTS` | [veafNamedPoints](mission-maker/scripts/veafNamedPoints.md#configuration-missionyaml) |
| veafCarrierOperations | `lua_modules.CARRIER` | [veafCarrierOperations](mission-maker/scripts/veafCarrierOperations.md#configuration-missionyaml) |
| veafAssets | `lua_modules.ASSETS` | [veafAssets](mission-maker/scripts/veafAssets.md#configuration-missionyaml) |
| veafSanctuary | `lua_modules.SANCTUARY` | [veafSanctuary](mission-maker/scripts/veafSanctuary.md#configuration-missionyaml) |
| veafCombatZone | `lua_modules.COMBATZONE` | [veafCombatZone](mission-maker/scripts/veafCombatZone.md#configuration-missionyaml) |
| veafAirWaves | `lua_modules.AIRWAVES` | [veafAirWaves](mission-maker/scripts/veafAirWaves.md#configuration-missionyaml) |
| veafQraManager | `lua_modules.QRA` + `qra:` | [veafQraManager](mission-maker/scripts/veafQraManager.md#configuration-missionyaml) |
| veafCasMission | `cap_missions:` + `combat_missions:` | [veafCasMission](mission-maker/scripts/veafCasMission.md#configuration-missionyaml) |

---

## Voir aussi

- [Référence Pipeline](PIPELINE_REFERENCE.md) — schémas YAML pour presets, waypoints, aircraft-templates, versions
- [Guide mission maker](mission-maker/GUIDE.md) — workflow complet
- [Référence API Lua](LUA_API_REFERENCE.md) — API de chaînes de constructeurs Lua pour usage avancé
