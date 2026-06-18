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
| `spawnables.yaml` | `spawnable_aircrafts` | Groupes d'avions spawnables (préfixe `veafSpawn-`) |
| `dynamic-slot-templates.yaml` | `dynamic_slot_templates` | Modèles de slot dynamique (`dynSpawnTemplate=true`) |
| `warehouses.yaml` | `warehouses` | Warehouses Dynamic-Slot : `dynamicSpawn`, stock, carburant, liens de modèle |
| `versions.yaml` | `weather` | Génère une variante `.miz` par preset météo |

Ces fichiers **ne sont pas** chargés à l'exécution dans DCS — ils sont consommés par `veaf-tools build` puis compilés dans le `.miz`.

### Catégorie B — Configuration des modules runtime (ce fichier)

`mission.yaml` lui-même configure **le comportement des modules Lua VEAF lors de l'exécution dans DCS**. Il est traduit au moment du build en `veaf-config.lua`, injecté dans la mission et exécuté au chargement par DCS.

Les sections `modules:`, `qra:`, `assets:`, `shortcuts:` décrivent toutes le comportement des modules à l'exécution.

```
dossier mission/
├── mission.yaml          ← config des modules runtime (CE FICHIER)
│   └── pipeline:
│       ├── waypoints: true  ──► src/waypoints.yaml       (injection build-time)
│       ├── presets:  true   ──► src/presets.yaml          (injection build-time)
│       ├── spawnable_aircrafts: true     ──► src/spawnables.yaml
│       ├── dynamic_slot_templates: true  ──► src/dynamic-slot-templates.yaml
│       ├── warehouses: true  ──► src/warehouses.yaml
│       └── weather:  true   ──► src/versions.yaml
└── src/
    ├── waypoints.yaml
    ├── presets.yaml
    ├── spawnables.yaml
    ├── dynamic-slot-templates.yaml
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

modules:
  RADIO:
    enabled: true
  ASSETS:
    enabled: true
    assets:
      - sort: 1
        name: "Texaco"
        description: "Texaco (KC-135)"
        information: 'Tacan 51Y\nU251.00 (21)'
```

---

## Erreurs de syntaxe

Si `mission.yaml` contient une erreur de syntaxe YAML (mauvaise indentation, deux-points manquants, caractère de tabulation…), `veaf-tools build` s'arrête immédiatement et affiche un message clair indiquant le nom du fichier, la ligne et la colonne du problème, ainsi qu'une aide en langage courant pour corriger l'erreur :

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
  language: fr                # langue des messages VEAF en jeu : fr | en (défaut : langue des outils)
```

| Champ | Type | Défaut | Requis | Description |
|-------|------|--------|--------|-------------|
| `name` | string | — | Non | Nom de la mission affiché dans les menus et les logs |
| `export_path` | string \| null | `null` | Non | Surcharge le chemin d'export DCS Saved Games |
| `era` | string | `MODERN` | Non | `MODERN` \| `COLD_WAR` \| `WW2` — affecte les groupes disponibles au spawn |
| `language` | string | *langue des outils* | Non | Langue des messages VEAF affichés en jeu (`fr` \| `en`) ; émise dans `veaf-config.lua` comme `veaf.config.language` et lue par `veaf.t()`. Si absent, le build utilise la langue des outils (`--lang` > `VEAF_LANG` > config utilisateur > locale OS > `en`) |

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

### Modules tiers : `SKYNET` / `CTLD` / `CSAR` (sous `modules:`)

> **Changement v6 (rupture)** : les sections `external_modules:` et `qra:` n'existent plus. Toute leur configuration vit désormais sous le bloc `modules:`, source unique de vérité. Voir [ADR 0001](https://github.com/VEAF/VEAF-Mission-Creation-Tools/blob/develop-v6/docs/adr/0001-modules-single-source-of-truth.md).

Skynet IADS, CTLD et CSAR se configurent comme n'importe quel module, directement sous `modules:` :

```yaml
modules:
  SKYNET:
    enabled: true
    include_red_in_radio: false      # ajouter l'état IADS ROUGE au menu F10
    debug_red: false                 # debug Skynet verbeux pour ROUGE
    include_blue_in_radio: false     # ajouter l'état IADS BLEU au menu F10
    debug_blue: false                # debug Skynet verbeux pour BLEU
  CTLD:
    enabled: true
    settings:                        # paires ctld.xxx = valeur
      hoverPickup: true
  CSAR:
    enabled: true
    settings:                        # paires csar.xxx = valeur
      enableAllslots: true
```

#### Champs de `modules.SKYNET`

| Champ | Type | Défaut | Description |
|-------|------|--------|-------------|
| `enabled` | booléen | `false` | Activer l'intégration Skynet IADS |
| `include_red_in_radio` | booléen | `false` | Ajouter l'état IADS ROUGE au menu radio F10 |
| `debug_red` | booléen | `false` | Activer le debug Skynet verbeux pour la coalition ROUGE |
| `include_blue_in_radio` | booléen | `false` | Ajouter l'état IADS BLEU au menu radio F10 |
| `debug_blue` | booléen | `false` | Activer le debug Skynet verbeux pour la coalition BLEU |

#### Champs de `modules.CTLD` / `modules.CSAR`

| Champ | Type | Défaut | Description |
|-------|------|--------|-------------|
| `enabled` | booléen | `false` | Activer l'intégration CTLD / CSAR |
| `settings` | dictionnaire | — | Paires `ctld.xxx` / `csar.xxx` (ex: `hoverPickup: true`, `enableAllslots: true`) |

VEAF génère les affectations `ctld.xxx = value` / `csar.xxx = value` et l'appel `initialize()` dans `veaf-config.lua`. À la conversion `convert-v5`, ces réglages sont extraits automatiquement de `missionConfig.lua`. Pour les réglages complexes comme `aircraftType` (table par appareil), continuez d'utiliser le motif de callback Lua dans `mission-script.lua`. Voir [Intégration CTLD et CSAR](mission-maker/GUIDE.md#intégration-ctld-et-csar).

> **Sons.** CTLD et CSAR jouent leurs sons par nom de fichier au runtime (`beacon.ogg`, `beaconsilent.ogg`, `CSAR.ogg`). Quand CTLD ou CSAR est activé, le build injecte automatiquement les sons requis qu'il embarque (`src/scripts/community/sounds/`) dans le `l10n/DEFAULT/` de la mission, sans écraser un son déjà fourni par votre mission. Un son requis qui n'est fourni ni par les outils ni par votre mission est signalé par un avertissement de build — ajoutez-le dans `src/mission/l10n/DEFAULT/` (ex. `radiobeep.ogg`, le bip de secours JTAC, n'est pas redistribué).

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

### `modules:`

Le bloc unifié `modules:` permet d'activer, de désactiver ou de configurer chaque module Lua VEAF **et** chaque script communautaire au même endroit. Les modules non listés sont activés avec leurs paramètres par défaut.

> **Note de migration.** `modules:` remplace les anciennes clés `lua_modules:` + `community_scripts:`. Les clés héritées fonctionnent toujours mais émettent un avertissement de dépréciation au build. `enabled:` remplace l'ancienne clé `enable:`.

Chaque entrée peut prendre **trois formes** :

```yaml
modules:
  # 1. Raccourci — activer un module optionnel avec ses réglages par défaut :
  RADIO: true

  # 2. Bloc — activer et configurer :
  SPAWN:
    enabled: true
    logLevel: debug           # surcharge optionnelle du niveau de log par module
    init:
      help_menus: true

  # 3. Null nu — module d'infrastructure obligatoire, configuration seule :
  UNITS:
    logLevel: debug
```

> **Les modules d'infrastructure sont toujours actifs.**
> `UNITS`, `TIME`, `CACHE`, `EVENTS`, `MARKERS` et `COMMANDS` sont obligatoires et toujours chargés. Ne définissez **pas** `enabled:` dessus — c'est une erreur de build. Ils peuvent toutefois apparaître dans `modules:` pour configurer d'autres champs comme `logLevel`.

**Champs communs (tous les modules) :**

| Champ | Type | Défaut | Description |
|-------|------|--------|-------------|
| `enabled` | booléen | `true` | Activer ou désactiver ce module *(modules optionnels uniquement — interdit sur les modules d'infrastructure)* |
| `logLevel` | string | *(global)* | Surcharger le niveau de log pour ce module uniquement |

Les champs supplémentaires `init:` ou de données sont spécifiques à chaque module — voir la page de documentation de chaque module.

**Les scripts communautaires** se déclarent dans le même bloc, via leurs IDs en majuscules. Lorsqu'un script est absent de `modules:`, il garde son état par défaut (inclus). Mettez-le à `false` pour l'exclure :

```yaml
modules:
  CTLD: true
  CSAR: true
  SKYNET: false               # exclu de cette mission
```

| ID communautaire | Script |
|----|--------|
| `MIST` | MIST (Mission Scripting Tools) |
| `STTS` | DCS-SimpleTextToSpeech |
| `CTLD` | CTLD (Combat Transport & Logistics Dispatcher) |
| `AIEN` | AIEN (AI Enhancement) |
| `CSAR` | CSAR (Combat Search and Rescue) |
| `HERCULES` | Hercules Cargo |
| `SKYNET` | Skynet IADS |
| `TUM` | The Universal Mission (TUM) |

> Un identifiant inconnu déclenche un avertissement au build et est ignoré.

> **`TUM` (The Universal Mission) — prérequis de mission.** TUM est un générateur de mission PvE autonome (script communautaire tiers) qui prend le contrôle de toute la carte à l'initialisation : il rend tous les aérodromes neutres, puis attribue les zones et aérodromes aux camps d'après les **zones de déclencheur** (*trigger zones*) de l'éditeur de mission. Si vous activez `TUM: true` sur une mission qui n'a pas été conçue pour TUM, le script s'interrompt au démarrage avec une erreur du type :
>
> `Coalition red has no territory zones and/or controls no airfields. Please add zone with a name starting with REDFOR…`
>
> Ce n'est **pas un bug VEAF** : c'est un prérequis de design de TUM. Pour l'utiliser, créez dans l'éditeur de mission une zone dont le nom commence par `BLUFOR` et une autre commençant par `REDFOR`, chacune contenant **au moins un aérodrome**, plus au moins une autre zone de mission. N'activez `TUM` que pour une mission de type TUM.
>
> **Opt-in (contrairement aux autres scripts communautaires).** TUM est le seul script communautaire **désactivé par défaut** : une mission vanilla, une mission fraîchement convertie depuis la v5, ou un bloc `modules:` qui ne mentionne pas `TUM` le laissent **éteint**. Seul un `TUM: true` explicite l'active. Les autres scripts communautaires sont *opt-out* (actifs sauf si vous les passez à `false`). Quand `TUM: true`, le build appelle automatiquement `TUM.initialize()` au démarrage — vous n'avez rien à ajouter dans `mission-script.lua`.

**IDs de modules VEAF :**

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
| `COMBATMISSION` | veafCombatMission | — |
| `SPAWN` | veafSpawn | [veafSpawn](mission-maker/scripts/veafSpawn.md) |
| `MOVE` | veafMove | [veafMove](mission-maker/scripts/veafMove.md) |
| `SECURITY` | veafSecurity | [veafSecurity](mission-maker/scripts/veafSecurity.md) |
| `GRASS` | veafGrass | [veafGrass](mission-maker/scripts/veafGrass.md) |
| `WEATHER` | veafWeather | [veafWeather](mission-maker/scripts/veafWeather.md) |
| `INTERPRETER` | veafInterpreter | [veafInterpreter](mission-maker/scripts/veafInterpreter.md) |
| `MISSILEGUARDIAN` | veafMissileGuardian | [veafMissileGuardian](mission-maker/scripts/veafMissileGuardian.md) |

---

### `modules.QRA`, `cap_missions:`, `combat_missions:`

Les définitions QRA vivent sous `modules.QRA` (`silence_all` + `definitions:`). Les sections `cap_missions:` / `combat_missions:` restent de premier niveau. Toutes nécessitent les modules correspondants activés dans `modules:`.

Voir les pages respectives pour le schéma complet :
- [`modules.QRA`](mission-maker/scripts/veafQraManager.md#configuration-missionyaml) — définitions Quick Reaction Alert
- [`cap_missions:` et `combat_missions:`](mission-maker/scripts/veafCasMission.md#configuration-missionyaml) — définitions de missions CAP et de combat

---

### `community_scripts:` *(hérité)*

> **Déprécié.** Les scripts communautaires se configurent désormais dans le bloc unifié [`modules:`](#modules) via leurs IDs en majuscules (ex. `CTLD: true`). La section séparée `community_scripts:` fonctionne toujours mais émet un avertissement de dépréciation. Voir [`modules:`](#modules) pour la syntaxe actuelle et la liste des IDs communautaires.

---

### `custom_scripts:`

Déclare les scripts Lua custom présents dans `src/scripts/` qui ne font pas partie du jeu standard VEAF v6.  
Un script déclaré ici est inclus dans le `.miz` **sans** déclencher de warning. Par défaut, un trigger DCS de chargement est généré automatiquement pour lui ; positionner `generate_load_trigger: false` désactive ce trigger (utile quand le script est chargé manuellement depuis `mission-script.lua`).

| Champ | Type | Défaut | Description |
|-------|------|---------|-------------|
| `generate_load_trigger` | `bool` | `true` | Défaut global : générer un trigger DCS pour tous les scripts de la liste |
| `scripts[].path` | `string` | *(requis)* | Chemin vers le fichier, relatif au dossier de mission (ex : `src/scripts/FgMission.lua`) |
| `scripts[].generate_load_trigger` | `bool` | *(défaut global)* | Override par script ; si absent, le défaut global s'applique |

**Comportement de chargement**

- `generate_load_trigger: true` (défaut) → le script est chargé au démarrage de la mission, dans les **deux** modes de chargement : en build **statique** il est embarqué dans le `.miz` et chargé par le trigger VEAF de chargement des scripts de mission ; en build **dynamique** il est chargé depuis le disque par le `veafDynamicConfig.lua` généré. Le même flag pilote les deux modes — il n'y a pas de flag par-mode.
- `generate_load_trigger: false` → le script est tout de même injecté dans le `.miz` mais **aucun** chargement n'est généré dans l'un ou l'autre mode ; c'est `mission-script.lua` (ou un autre script) qui doit le charger via `dofile`.

**Ordre de chargement** : les scripts de mission se chargent toujours dans l'ordre `veaf-config.lua` → `mission-script.lua` → vos `custom_scripts` (dans l'ordre de déclaration). Un script custom peut donc compter sur la config VEAF et sur `mission-script.lua` déjà chargés.

```yaml
custom_scripts:
  generate_load_trigger: true       # défaut global pour tous les scripts ci-dessous
  scripts:
    - path: src/scripts/FgMission.lua
    - path: src/scripts/FgTools.lua
      generate_load_trigger: false  # chargé manuellement depuis mission-script.lua
```

> Tout fichier `.lua` présent dans `src/scripts/` mais **absent** de cette section (et ne faisant pas partie des fichiers standards) déclenche un warning au build avec un rappel pour le déclarer ici.

**Un script dans une seule variante (ex. un script de debug dynamique-seul)**

`generate_load_trigger` est un flag unique — il ne distingue pas statique et dynamique. Pour charger un script dans une seule variante (un utilitaire de debug que vous voulez **uniquement** dans votre build dynamique local de dev, jamais dans la distribution statique), utilisez un [profil de build](#profiles) plutôt qu'un flag par script :

```yaml
custom_scripts:
  scripts:
    - path: src/scripts/FgMission.lua   # toujours chargé (les deux variantes)

profiles:
  DEV:
    custom_scripts:
      scripts:
        - path: src/scripts/FgMission.lua    # ⚠️ doit répéter les scripts de base
        - path: src/scripts/FgDebug.lua      # en plus, dev seulement
```

Buildez la variante dev avec `veaf-tools build --profile DEV` (elle charge `FgMission.lua` + `FgDebug.lua`) ; le build par défaut ne charge que `FgMission.lua`.

> ⚠️ **Piège** : le deep-merge des profils **remplace les listes, il ne les concatène pas** (voir [`profiles:`](#profiles)). Le `custom_scripts.scripts` du profil doit donc **répéter** les scripts de base et ajouter celui spécifique à la variante — sinon les scripts de base sont perdus dans ce profil.

---

### `pipeline:`

Contrôle les étapes optionnelles du pipeline de build. Voir la [Référence Pipeline](PIPELINE_REFERENCE.md) pour le schéma complet des fichiers de configuration de chaque étape.

```yaml
pipeline:
  presets: false
  waypoints: true
  spawnable_aircrafts:
    file: src/my-spawnables.yaml
    mode: replace
  dynamic_slot_templates: false
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
| `dynamic_loading` | `bool` | `false` | Si `true`, les scripts VEAF **et** de mission sont chargés depuis le disque au runtime (mode dynamique, dev/test) au lieu d'être embarqués dans le `.miz`. Surchargeable par profil. CLI : `--dynamic-mode` / `--no-dynamic-mode` (prioritaire) |

Ordre de résolution de `scripts_path` (premier trouvé appliqué) :
1. Option CLI `--scripts-path <chemin>`
2. `mission.yaml build.scripts_path`
3. `~/veafmct.yaml scripts_path`

`dynamic_loading` se résout : `--dynamic-mode`/`--no-dynamic-mode` (CLI) > `build.dynamic_loading` (surchargé par profil) > `false`.

**Chargement dynamique — DEV vs PROD.** Quand `dynamic_loading: true`, les scripts sont chargés depuis le disque au runtime (donc non exposés dans le `.miz`/`.trk`) :

- **DEV** (`dev_mode: true`) — `scripts_path` doit pointer vers un clone de VEAF-Mission-Creation-Tools ; le framework charge les `veaf/*.lua` **individuels** via `VeafDynamicLoader.lua` (éditer et retester sans rebuild).
- **PROD** (`dev_mode: false`) — le framework charge le **bundle** concaténé `veaf/veaf-scripts.lua` depuis `scripts_path` (défaut `<mission>/published`, installé par l'updater).

Dans les **deux** modes, les scripts de mission — y compris vos `custom_scripts:` — sont chargés depuis le disque via un `src/scripts/veafDynamicConfig.lua` **généré** (ne pas l'éditer à la main ; déclarez vos scripts dans `custom_scripts:`). Le build échoue avec une erreur claire si le loader framework est absent sous `scripts_path`.

```yaml
build:
  dev_mode: true
  scripts_path: C:/dev/VEAF-Mission-Creation-Tools
  dynamic_loading: false

profiles:
  test:
    build:
      dynamic_loading: true   # chargement dynamique pour le profil de test
```

> Voir la section [Mode développeur](developer/GUIDE.md#mode-développeur) du Guide du développeur pour le workflow complet.

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

### `build_variants:`

Liste de profils de build à **émettre ensemble** : un seul `veaf-tools build` produit alors **un `.miz` par variante** (objectif « moulinette » — typiquement Modern et Cold-War d'un même dossier de mission, la variante n'étant qu'une différence de **config**). Chaque variante construit le pipeline complet avec son profil fusionné (voir [`profiles:`](#profiles)) et son `.miz` est suffixé du nom de variante (`<base>_<VARIANT>.miz`).

| Champ | Type | Description |
|-------|------|-------------|
| `build_variants` | `list[str]` | Noms de profils (déclarés sous `profiles:`) à émettre chacun comme un `.miz` distinct. |

**Règles**
- Sans `build_variants:` (ou liste vide) → un seul `.miz`, comportement inchangé.
- `--profile <nom>` est l'**échappatoire** : il force la construction d'une seule variante (ce profil), sans suffixe — `build_variants:` est ignoré.
- Les variantes sont construites dans l'ordre déclaré ; chaque nom doit correspondre à un profil de `profiles:` (sinon avertissement + config de base, comme `--profile`).

```yaml
profiles:
  MODERN:
    mission:
      era: MODERN
  COLD_WAR:
    mission:
      era: COLD_WAR

build_variants:
  - MODERN
  - COLD_WAR
```

```powershell
veaf-tools.exe build          # produit <base>_MODERN.miz ET <base>_COLD_WAR.miz
veaf-tools.exe build --profile MODERN   # ne produit que la variante MODERN (sans suffixe)
```

---

## Index par catégorie

### Essentiel — toute mission

| Section / Champ | Description |
|-----------------|-------------|
| [`global_log_level`](#global_log_level) | Forcer un niveau de log sur tous les modules |
| [`mission:`](#mission) | Nom, ère, chemin d'export |
| [`security:`](#security) | Activer/désactiver la sécurité, hashes de mots de passe |
| `modules.RADIO` | [veafRadio](mission-maker/scripts/veafRadio.md) |
| `modules.ASSETS` | [veafAssets](mission-maker/scripts/veafAssets.md) |
| `pipeline.presets` | [schéma presets.yaml](PIPELINE_REFERENCE.md#étape-1--préréglages-radio-presetsyaml) |
| `pipeline.waypoints` | [schéma waypoints.yaml](PIPELINE_REFERENCE.md#étape-2--points-de-cheminement-waypointsyaml) |

### Courant — la plupart des missions

| Section / Champ | Description |
|-----------------|-------------|
| [`settings:`](#settings) | Constantes mission → `veaf.config.XXX` |
| `modules.SHORTCUTS` | [veafShortcuts](mission-maker/scripts/veafShortcuts.md) |
| `modules.NAMEDPOINTS` | [veafNamedPoints](mission-maker/scripts/veafNamedPoints.md) |
| [`modules.QRA`](#modulesqra-cap_missions-combat_missions) | [veafQraManager](mission-maker/scripts/veafQraManager.md) |
| `modules.COMBATZONE` | [veafCombatZone](mission-maker/scripts/veafCombatZone.md) |
| `modules.CARRIER` | [veafCarrierOperations](mission-maker/scripts/veafCarrierOperations.md) |

### Avancé — cas spécifiques

| Section / Champ | Description |
|-----------------|-------------|
| `modules.AIRWAVES` | [veafAirWaves](mission-maker/scripts/veafAirWaves.md) |
| `modules.SANCTUARY` | [veafSanctuary](mission-maker/scripts/veafSanctuary.md) |
| `modules.MISSILEGUARDIAN` | [veafMissileGuardian](mission-maker/scripts/veafMissileGuardian.md) |
| [`modules.SKYNET` / `.CTLD` / `.CSAR`](#modules-tiers--skynet--ctld--csar-sous-modules) | Skynet IADS, CTLD, CSAR |
| [`veaf_tools:`](#veaf_tools) | Contrainte de version |
| `pipeline.spawnable_aircrafts` / `pipeline.dynamic_slot_templates` | [schéma groupes d'aéronefs](PIPELINE_REFERENCE.md#étape-3--groupes-daéronefs--spawnables-b-et-modèles-de-slot-dynamique-c) |
| `pipeline.weather` | [schéma versions.yaml](PIPELINE_REFERENCE.md#étape-4--variantes-météo--horaire-versionsyaml) |
| [`custom_scripts:`](#custom_scripts) | Scripts Lua custom à inclure dans la mission |
| [`build:`](#build) | Mode développeur et chemin des scripts |
| `build.dev_mode` | Utiliser le bundle Lua local au lieu des scripts publiés |
| `build.scripts_path` | Chemin vers un clone local de VEAF-Mission-Creation-Tools |
| [`profiles:`](#profiles) | Profils de build nommés (surcharges deep-merge pour `--profile`) |

---

## Index par module

| Module | Clé mission.yaml | Page doc |
|--------|-----------------|----------|
| veafRadio | `modules.RADIO` | [veafRadio](mission-maker/scripts/veafRadio.md#configuration-missionyaml) |
| veafShortcuts | `modules.SHORTCUTS` | [veafShortcuts](mission-maker/scripts/veafShortcuts.md#configuration-missionyaml) |
| veafNamedPoints | `modules.NAMEDPOINTS` | [veafNamedPoints](mission-maker/scripts/veafNamedPoints.md#configuration-missionyaml) |
| veafCarrierOperations | `modules.CARRIER` | [veafCarrierOperations](mission-maker/scripts/veafCarrierOperations.md#configuration-missionyaml) |
| veafAssets | `modules.ASSETS` | [veafAssets](mission-maker/scripts/veafAssets.md#configuration-missionyaml) |
| veafSanctuary | `modules.SANCTUARY` | [veafSanctuary](mission-maker/scripts/veafSanctuary.md#configuration-missionyaml) |
| veafCombatZone | `modules.COMBATZONE` | [veafCombatZone](mission-maker/scripts/veafCombatZone.md#configuration-missionyaml) |
| veafAirWaves | `modules.AIRWAVES` | [veafAirWaves](mission-maker/scripts/veafAirWaves.md#configuration-missionyaml) |
| veafQraManager | `modules.QRA` | [veafQraManager](mission-maker/scripts/veafQraManager.md#configuration-missionyaml) |
| veafCasMission | `cap_missions:` + `combat_missions:` | [veafCasMission](mission-maker/scripts/veafCasMission.md#configuration-missionyaml) |

---

## Voir aussi

- [Référence Pipeline](PIPELINE_REFERENCE.md) — schémas YAML pour presets, waypoints, spawnables, dynamic-slot-templates, warehouses, spawn-groups, versions
- [Guide mission maker](mission-maker/GUIDE.md) — workflow complet
- [Référence API Lua](LUA_API_REFERENCE.md) — API de chaînes de constructeurs Lua pour usage avancé
