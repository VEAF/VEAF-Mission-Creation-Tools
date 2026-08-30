# Référence mission.yaml

`mission.yaml` est le fichier de configuration optionnel de build-time pour veaf-tools. Placez-le à la racine de votre dossier mission, à côté de `veaf-tools-updater.exe`. S'il est absent, `veaf-tools mission build` fonctionne avec les paramètres par défaut.

Cette page couvre les **sections de premier niveau** de `mission.yaml`. La configuration des modules Lua individuels est documentée dans la page de chaque module (voir l'[index par module](#index-par-module) ci-dessous).

---

## Comprendre le paysage des fichiers YAML

Un dossier de mission VEAF utilise **deux catégories distinctes** de fichiers YAML. Comprendre cette distinction vous aide à savoir quel fichier modifier pour une tâche donnée.

### Catégorie A — Fichiers de pipeline de build

Ces fichiers pilotent les étapes **d'injection au moment du build** que `veaf-tools mission build` effectue avant d'écrire le `.miz` final. Chaque étape lit son propre fichier YAML et injecte des données dans la mission. Ils sont listés sous la section `pipeline:` de `mission.yaml`.

| Fichier (dans `src/`) | Étape de pipeline | Rôle |
|-----------------------|---------------|------|
| `waypoints.yaml` | `waypoints` | Injecte les waypoints nommés dans la mission |
| `presets.yaml` | `presets` | Configure les presets radio de chaque groupe d'avions |
| `spawnables.yaml` | `spawnable_aircrafts` | Groupes d'avions spawnables (préfixe `veafSpawn-`) |
| `dynamic-slot-templates.yaml` | `dynamic_slot_templates` | Modèles de slot dynamique (`dynSpawnTemplate=true`) |
| `warehouses.yaml` | `warehouses` | Warehouses Dynamic-Slot : `dynamicSpawn`, stock, carburant, liens de modèle |
| `spawn-groups.yaml` | `spawn_data` | Base de données de spawn pour `_spawn unit` / `_spawn group` — **optionnel** : l'étape s'exécute toujours, les données du framework étant embarquées, et ce fichier ne fait que les compléter |
| `versions.yaml` | `weather` | Génère une variante `.miz` par preset météo |

Ces fichiers **ne sont pas** chargés à l'exécution dans DCS — ils sont consommés par `veaf-tools mission build` puis compilés dans le `.miz`.

### Catégorie B — Configuration des modules runtime (ce fichier)

`mission.yaml` lui-même configure **le comportement des modules Lua VEAF lors de l'exécution dans DCS**. Il est traduit au moment du build en `veaf-config.lua`, injecté dans la mission et exécuté au chargement par DCS.

La section `modules:` décrit le comportement des modules à l'exécution (la configuration QRA, assets ou shortcuts vit sous le module concerné, ex. `modules.QRA`).

```
dossier mission/
├── mission.yaml          ← config des modules runtime (CE FICHIER)
│   └── pipeline:
│       ├── waypoints: true  ──► src/waypoints.yaml       (injection build-time)
│       ├── presets:  true   ──► src/presets.yaml          (injection build-time)
│       ├── spawnable_aircrafts: true     ──► src/spawnables.yaml
│       ├── dynamic_slot_templates: true  ──► src/dynamic-slot-templates.yaml
│       ├── warehouses: true  ──► src/warehouses.yaml
│       ├── spawn_data: true  ──► src/spawn-groups.yaml  (optionnel)
│       └── weather:  true   ──► src/versions.yaml
└── src/
    ├── waypoints.yaml
    ├── presets.yaml
    ├── spawnables.yaml
    ├── dynamic-slot-templates.yaml
    ├── warehouses.yaml
    ├── spawn-groups.yaml
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

Si `mission.yaml` contient une erreur de syntaxe YAML (mauvaise indentation, deux-points manquants, caractère de tabulation…), `veaf-tools mission build` s'arrête immédiatement et affiche un message clair indiquant le nom du fichier, la ligne et la colonne du problème, ainsi qu'une aide en langage courant pour corriger l'erreur :

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

Identité de la mission (nom, chemin d'export, ère) **et** options globales de la mission (ex. `silence_atc_on_all_airbases`) — utilisées dans les menus radio, les messages de log et les chemins d'export. Ce bloc regroupe les réglages de niveau mission, pas seulement l'identité.

```yaml
mission:
  name: "Ma-Mission"          # affiché dans les menus radio et les messages de log
  export_path: null           # null = chemin DCS Saved Games par défaut
  era: MODERN                 # MODERN | COLD_WAR | WW2
  language: fr                # langue des messages VEAF en jeu : fr | en (défaut : langue des outils)
  silence_atc_on_all_airbases: false  # option globale : coupe l'ATC DCS sur tous les aérodromes
  third_party_mods: []        # mods DCS tiers à rendre non bloquants (voir ci-dessous)
```

| Champ | Type | Défaut | Requis | Description |
|-------|------|--------|--------|-------------|
| `name` | string | — | Non | Nom de la mission affiché dans les menus et les logs, **et nom du `.miz` construit** — voir la note de nommage ci-dessous |
| `export_path` | string \| null | `null` | Non | Surcharge le chemin d'export DCS Saved Games |
| `era` | string | *déduit* | Non | `MODERN` \| `COLD_WAR` \| `WW2` — affecte les groupes disponibles au spawn. **Absent, il est déduit à chaque build** depuis le contenu de la mission de base : un type d'unité WW2 ou une année ≤ 1945 donne `WW2`, une année ≤ 1991 `COLD_WAR`, sinon `MODERN` (`era_detector.py`). La valeur déduite n'est **pas** écrite dans votre `mission.yaml` — elle est recalculée ; renseignez la clé pour la figer. |
| `silence_atc_on_all_airbases` | booléen | `false` | Non | Option globale : coupe l'ATC DCS sur tous les aérodromes (émet `veaf.silenceAtcOnAllAirbases()`). `convert-v5` la migre depuis un appel actif et annote sa provenance |
| `language` | string | *langue des outils* | Non | Langue des messages VEAF affichés en jeu (`fr` \| `en`) ; émise dans `veaf-config.lua` comme `veaf.config.language` et lue par `veaf.t()`. Si absent, le build utilise la langue des outils (`--lang` > `VEAF_LANG` > config utilisateur > locale OS > `en`) |
| `third_party_mods` | liste de strings | `[]` | Non | Mods DCS **tiers** (avions payants/communautaires) à rendre **non bloquants** : leurs identifiants sont retirés de la table `requiredModules` du `.miz` au build, si bien qu'un pilote qui ne possède pas le mod peut quand même **charger** la mission (le slot correspondant est simplement indisponible). La liste est **unie** à une liste VEAF par défaut couvrant les mods courants (Hercules, UH-60L, A-4E-C, T-45, AM2, SU-30/FlankerEx, Bronco-OV-10A) — n'y déclarer que les mods non déjà pris en charge. À ne pas confondre avec les *Modules* VEAF (bloc `modules:`, qui sont des capacités, pas des add-ons DCS) |

#### Le nom du `.miz` est une interface — `_ICAO_<code>` et la météo réelle {#icao-naming}

`mission.name` devient le nom du fichier construit : `<nom>_<AAAAMMJJ>.miz`, plus un suffixe
`_<VARIANTE>` si [`build_variants:`](#build-variants) est utilisé. Donnez plutôt un nom
terminé par `.miz` et il est repris **tel quel**, sans date.

C'est important parce que **l'outillage serveur lit le nom du fichier**. Sur les serveurs VEAF,
l'extension RealWeather de [DCSServerBot](https://github.com/Special-K-s-Flightsim-Bots/DCSServerBot)
cherche **`_ICAO_<code>`** dans le nom du `.miz` et récupère le METAR réel de cet aérodrome au
démarrage de la mission — la météo suit donc la réalité sans reconstruire. Nommez la mission en
conséquence :

```yaml
mission:
  name: VEAF_Foothold_Caucasus_ICAO_URSS   # -> VEAF_Foothold_Caucasus_ICAO_URSS_20260728.miz
```

Deux règles pour choisir le code :

- ce doit être **un aérodrome du théâtre** (n'importe lequel ; un grand vaut mieux) ;
- il doit avoir une **station METAR vivante**. Vérifiez-le avant de vous y fier : une station peut
  exister *et* être périmée, ce qui est pire que pas de météo réelle du tout, puisque la mission
  annonce alors une météo « réelle » vieille de plusieurs jours. Contrôle en une ligne :

```bash
curl -s https://tgftp.nws.noaa.gov/data/observations/metar/stations/URSS.TXT
```

Les deux premiers chiffres du groupe `JJHHMMZ` sont le jour de l'observation — comparez-les à la
date du jour.

Quand tout un théâtre est dégradé, deux réponses se défendent, et le choix revient à qui exploite
le serveur. Mesuré sur l'Afghanistan, **toutes** les stations retardent (Kaboul un mois, Herat
seize jours, Bagram un jour ; six aérodromes n'ont aucune station) : soit on **omet** le marqueur,
ce qui laisse RealWeather tranquille et conserve la météo choisie, soit on **prend la moins
mauvaise** en sachant ce qu'on obtient. Le Foothold Afghanistan de VEAF utilise `OAIX` (Bagram,
environ un jour de retard) — un choix assumé, pas un oubli.

---

### `security:`

Contrôle le système de sécurité VEAF. **La sécurité est active par défaut** (`veaf.SecurityDisabled = false` dans `veaf.lua`) : sans bloc `security:`, rien n'est émis et les commandes sensibles exigent un niveau de pilote ou un mot de passe. `disabled: true` la coupe pour toute la mission.

```yaml
security:
  disabled: false                   # false = un mot de passe est requis
  password_hashes:                  # hashes SHA-1 donnant l'accès joueur/JTF
    - "2a4efd2397e081bcacb82b3e447c584c65cc83ee"
  password_mm_hashes:               # hashes SHA-1 donnant l'accès Mission Master
    - "99685b3c7cb1fb08a829fc97d4a8564fc5f9435a"
```

| Champ | Type | Défaut | Requis | Description |
|-------|------|--------|--------|-------------|
| `disabled` | booléen | `false` | Non | `true` = aucun mot de passe requis |
| `password_hashes` | string[] | `[]` | Non | Hashes **SHA-1** donnant l'accès joueur. Émis aux niveaux **L1 et L9**, pour que le mot de passe ouvre l'authentification par marqueur et les spawns sensibles, pas seulement les portes L9 |
| `password_mm_hashes` | string[] | `[]` | Non | Hashes **SHA-1** donnant l'accès Mission Master (table dédiée, sans cascade de niveaux) |

> **SHA-1, pas SHA-256.** `veafSecurity._checkPassword` hashe ce que tape le joueur avec
> `sha1.hex(password)` puis cherche le résultat dans la table : un hash SHA-256 ne correspondra
> donc jamais et le mot de passe ne fonctionnera **jamais**, en silence.
>
> Pour en générer un : `echo -n "votremotdepasse" | sha1sum` (Linux/macOS), ou
> `python -c "import hashlib,sys; print(hashlib.sha1(sys.argv[1].encode()).hexdigest())" votremotdepasse`.

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

### `module_settings:` {#module-settings}

Réglages scalaires posés **directement sur la table d'un module VEAF**, écrits tels quels dans le `veaf-config.lua` généré. Là où `settings:` ne sait écrire que `veaf.config.CLÉ`, cette section vise n'importe quelle table VEAF.

```yaml
module_settings:
  veafSkynet.DelayForStartup: 150     # temporisation de démarrage de l'IADS
  veafSkynet.DynamicSpawn: true
  veafRadio.RadioMenuName: "BFR"      # nom du menu radio racine, visible par les joueurs
  veaf.DEFAULT_GROUND_SPEED_KPH: 25
```

Chaque entrée devient l'affectation Lua correspondante, ici `veafSkynet.DelayForStartup = 150`.

| Champ | Type | Défaut | Requis | Description |
|-------|------|--------|--------|-------------|
| *(clé)* | string | — | — | La cible Lua complète, `veafXxx.Champ`. Une clé qui ne commence pas par `veaf` est **refusée à la génération** : cette section est un chemin de migration pour les réglages VEAF, pas une trappe permettant d'écrire n'importe où dans le runtime |
| *(valeur)* | booléen \| nombre \| string | — | — | Un scalaire. Les tables et les fonctions ne sont pas exprimables ici |

> **Un champ documenté l'emporte sur un reliquat de migration.** Si un réglage a désormais son propre
> champ dans `mission.yaml` **et** qu'une entrée de `module_settings:` vise la même variable Lua,
> c'est le **champ documenté** qui s'applique : l'entrée `module_settings:` est ignorée, et le build
> vous le dit en nommant les deux. Cette section est un chemin de migration, pas une surcharge
> permanente — retirez la ligne devenue inutile.
>
> Aujourd'hui, un seul réglage est dans ce cas : `veaf.HideNamesFromSpawnedGroups`, remplacé par
> `mission.hide_names_from_spawned_groups`.

> **D'où ça vient.** `convert-v5` remplit cette section automatiquement : en v5, la moitié de ces
> réglages n'arrivaient ni dans `mission.yaml` ni dans le Lua généré, et rien ne le signalait.
> Ce que la conversion ne sait toujours pas porter — une table, une fonction — est désormais listé
> en commentaire dans le `mission-script.lua` généré, sous « Settings NOT migrated ».

---

### Modules tiers : `SKYNET` / `CTLD` / `CSAR` (sous `modules:`) {#third-party-modules}

> **Changement v6 (rupture)** : les sections `external_modules:` et `qra:` n'existent plus. Toute leur configuration vit désormais sous le bloc `modules:`, source unique de vérité. Voir [ADR 0001](https://github.com/VEAF/VEAF-Mission-Creation-Tools/blob/develop/docs/adr/0001-modules-single-source-of-truth.md).

Skynet IADS, CTLD et CSAR se configurent comme n'importe quel module, directement sous `modules:` :

```yaml
modules:
  SKYNET:
    enabled: true
    include_red_in_radio: false      # ajouter l'état IADS ROUGE au menu F10
    debug_red: false                 # debug Skynet verbeux pour ROUGE
    include_blue_in_radio: false     # ajouter l'état IADS BLEU au menu F10
    debug_blue: false                # debug Skynet verbeux pour BLEU
  CTLD: true                         # configuré dans ctld-config.yaml, pas ici
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

#### Champs de `modules.CSAR`

| Champ | Type | Défaut | Description |
|-------|------|--------|-------------|
| `enabled` | booléen | `false` | Activer l'intégration CSAR |
| `settings` | dictionnaire | — | Paires `csar.xxx` (ex: `enableAllslots: true`) |

VEAF génère les affectations `csar.xxx = value` et l'appel `csar.initialize()` dans `veaf-config.lua`. À la conversion `convert-v5`, ces réglages sont extraits automatiquement de `missionConfig.lua`. Pour les réglages complexes comme `aircraftType` (table par appareil), continuez d'utiliser le motif de callback Lua dans `mission-script.lua`.

#### `modules.CTLD` : un booléen, et rien d'autre

CTLD 2 se configure **hors de `mission.yaml`**, dans un fichier `ctld-config.yaml` placé à côté et édité avec `ctld-tools.exe`. Un bloc `settings:` sous `CTLD` est **refusé par `validate`** : il n'était plus lu, et le laisser passer en silence est précisément le défaut que ce changement supprime. Une seule clé est lue ici en plus de l'interrupteur : `manage_logistics` (booléen, défaut `true`). Avec elle active, le build **ajoute** les porte-avions et dépôts de munitions FARP que VEAF a toujours reconnus aux listes `logisticUnitTypes` / `troopZoneShipTypes` de votre `ctld-config.yaml` — il ajoute, il ne remplace pas.

```yaml
modules:
  CTLD:
    enabled: true
    manage_logistics: true
```

Voir [Intégration CTLD et CSAR](mission-maker/GUIDE.md#ctld-and-csar-integration) — dont [où récupérer `ctld-tools`](mission-maker/GUIDE.md#getting-ctld-tools), qui n'est pas livré avec VEAF MCT, et [les FARP posées dans l'éditeur](mission-maker/GUIDE.md#ctld-manage-logistics).

> **Sons.** CTLD et CSAR jouent leurs sons par nom de fichier au runtime (`beacon.ogg`, `beaconsilent.ogg`, `CSAR.ogg`). Quand CTLD ou CSAR est activé, le build injecte automatiquement les sons requis qu'il embarque (`src/scripts/community/sounds/`) dans le `l10n/DEFAULT/` de la mission, sans écraser un son déjà fourni par votre mission. Un son requis qui n'est fourni ni par les outils ni par votre mission est signalé par un avertissement de build — ajoutez-le dans `src/mission/l10n/DEFAULT/` (ex. `radiobeep.ogg`, le bip de secours JTAC, n'est pas redistribué).
>
> Le build **déclare** ensuite chaque son de la mission dans le `mapResource`, via un déclencheur « Declare mission sounds » qui le joue vers un pays qu'aucune coalition n'utilise — donc inaudible. Sans cette déclaration, l'éditeur de mission DCS considère ces fichiers comme orphelins (il ne peut pas savoir qu'un script les joue par leur nom) et **les supprime dès que vous enregistrez la mission dans l'éditeur**, sans le moindre message.

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

### `modules:` {#modules}

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

**Champs `init:` du module `RADIO` :**

| Champ | Type | Défaut | Description |
|-------|------|--------|-------------|
| `help_menus` | booléen | `true` | Transmis à `veafRadio.initialize` en tant que `skipHelpMenus` |
| `create_menus` | booléen | `true` | `false` ne construit **aucun menu F10 VEAF** (`dontCreateMenus`). Combiné à `security:`, c'est ainsi qu'une mission publique garde les commandes VEAF accessibles uniquement via des marqueurs protégés par mot de passe. Omettez la clé pour conserver le comportement actuel |

```yaml
modules:
  RADIO:
    enabled: true
    init:
      create_menus: false       # pas de menu radio VEAF ; commandes via marqueurs
```

**Les scripts communautaires** se déclarent dans le même bloc, via leurs IDs (la casse est indifférente : `CTLD:` et `ctld:` sont équivalents). Lorsqu'un script est absent de `modules:`, il garde son état par défaut (inclus). Mettez-le à `false` pour l'exclure — sauf `MIST`, dépendance obligatoire des scripts VEAF : un `MIST: false` explicite est ignoré avec un avertissement au build, le script est injecté quand même.

```yaml
modules:
  CTLD: true
  CSAR: true
  SKYNET: false               # exclu de cette mission
```

| ID communautaire | Script |
|----|--------|
| `MIST` | MIST (Mission Scripting Tools) — **obligatoire, non désactivable** |
| `STTS` | DCS-SimpleTextToSpeech |
| `CTLD` | CTLD (Combat Transport & Logistics Dispatcher) |
| `AIEN` | AIEN (AI Enhancement) |
| `CSAR` | CSAR (Combat Search and Rescue) |
| `SKYNET` | Skynet IADS |
| `TUM` | The Universal Mission (TUM) |

> Un identifiant inconnu dans `modules:` est une **erreur bloquante** : le build s'arrête avec un message indiquant la clé fautive.

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
| `ASSIST` | veafAssist | [veafAssist](mission-maker/scripts/veafAssist.md) |
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
| `TRANSPORTMISSION` | veafTransportMission | [veafTransportMission](mission-maker/scripts/veafTransportMission.md) |
| `AIRBASES` | veafAirbases | [veafAirbases](mission-maker/scripts/veafAirbases.md) |
| `GROUNDAI` | veafGroundAI | — |
| `REMOTE` | veafRemote | — |
| `SKYNET_MONITOR` | veafSkynetMonitor | — |
| `I18N` | veafI18n | — |

---

### `modules.RADIO.user_menus` — menus radio F10 en YAML

Depuis ADR 0011, un créateur de mission peut déclarer un menu radio F10 personnalisé (notamment pour le Mission Master) **entièrement en YAML**, sans écrire de Lua, sous `modules.RADIO.user_menus`.

```yaml
modules:
  RADIO:
    user_menus:
      restrict_to_group: "MM Ctrl"   # optionnel : nom d'un groupe DCS ; menu réservé à ce groupe. Absent = global.
      tree:
        - menu: "Contrôle QRA"
          items:
            - { command: "Démarrer QRA Nord", action: qra.start, qra: "QRA-Nord" }
            - { command: "Arrêter QRA Nord",  action: qra.stop,  qra: "QRA-Nord" }
        - { command: "Message global", action: message, text: "La mission commence !" }
        - { command: "Fonction custom", action: lua, function: "maMission.demarrerTout", args: ["alpha", 3] }
```

Chaque nœud de `tree` est soit un sous-menu (`{ menu: "...", items: [...] }`, récursif) soit une commande (`{ command: "...", action: <verbe>, <clés> }`). Le vocabulaire d'actions est fermé (`qra.start`/`qra.stop`, `airwave.start`/`airwave.stop`/`airwave.reset`, `flag.on`/`flag.off`/`flag.set`/`flag.increment`/`flag.decrement`, `message`, `lua`). Une action `lua` référence une fonction définie dans `mission-script.lua` : si la fonction est absente, le build échoue.

Voir le schéma complet, le tableau des actions et un exemple détaillé dans [veafRadio → Menus radio en YAML](mission-maker/scripts/veafRadio.md#radio-menus-in-yaml).

---

### `modules.QRA`, `cap_missions:`, `combat_missions:`

Les définitions QRA vivent sous `modules.QRA` (`silence_all` + `definitions:`). Les sections `cap_missions:` / `combat_missions:` restent de premier niveau. Toutes nécessitent les modules correspondants activés dans `modules:`.

Voir les pages respectives pour le schéma complet :
- [`modules.QRA`](mission-maker/scripts/veafQraManager.md#configuration-missionyaml) — définitions Quick Reaction Alert
- [`cap_missions:` et `combat_missions:`](mission-maker/scripts/veafCasMission.md#configuration-missionyaml) — définitions de missions CAP et de combat

> **Raccourci menu radio (QRA / AirWaves).** Une définition QRA (`modules.QRA.definitions[]`) ou une zone AirWave (`modules.AIRWAVES.airwave_zones[]`) accepte `radio_menu: true` (et l'option `radio_menu_restrict_to_group: "<groupe DCS>"`) pour générer automatiquement un sous-menu F10 de contrôle (démarrer/arrêter, plus réinitialiser pour AirWaves). Voir [veafQraManager](mission-maker/scripts/veafQraManager.md#configuration-missionyaml) et [veafAirWaves](mission-maker/scripts/veafAirWaves.md#configuration-missionyaml).

---

### `community_scripts:` *(hérité)* {#community-scripts}

> **Déprécié.** Les scripts communautaires se configurent désormais dans le bloc unifié [`modules:`](#modules) via leurs IDs en majuscules (ex. `CTLD: true`). La section séparée `community_scripts:` fonctionne toujours mais émet un avertissement de dépréciation. Voir [`modules:`](#modules) pour la syntaxe actuelle et la liste des IDs communautaires.

---

### `custom_scripts:` {#custom-scripts}

Déclare les scripts Lua custom présents dans `src/scripts/` qui ne font pas partie du jeu standard VEAF v6.  
Un script déclaré ici est inclus dans le `.miz` **sans** déclencher de warning. Par défaut, un trigger DCS de chargement est généré automatiquement pour lui ; positionner `generate_load_trigger: false` désactive ce trigger (utile quand le script est chargé manuellement depuis `mission-script.lua`).

| Champ | Type | Défaut | Description |
|-------|------|---------|-------------|
| `generate_load_trigger` | `bool` | `true` | Défaut global : générer un trigger DCS pour tous les scripts de la liste |
| `scripts[].path` | `string` | *(requis)* | Chemin vers le fichier, relatif au dossier de mission (ex : `src/scripts/FgMission.lua`) |
| `scripts[].generate_load_trigger` | `bool` | *(défaut global)* | Override par script ; si absent, le défaut global s'applique |
| `scripts[].delay_seconds` | `number` | *(aucun)* | Charge ce script **après** ce délai (en secondes) au lieu du chargement groupé. Voir ci-dessous |

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

**Charger un script après un délai : `delay_seconds`**

Par défaut, tous les scripts de mission sont chargés d'un bloc au démarrage. Certains scripts ont besoin
qu'un délai s'écoule avant de démarrer — typiquement parce qu'ils **inventorient le monde une seule
fois** et doivent laisser aux scripts précédents le temps de créer leurs unités. C'est le cas d'AIEN dans
Foothold, chargé 12 secondes après les autres.

```yaml
custom_scripts:
  scripts:
    - path: src/scripts/Moose.lua
    - path: src/scripts/zoneCommander.lua
    - path: src/scripts/AIEN.lua
      delay_seconds: 12          # son propre déclencheur, 12 s après le début
```

- **Absent** (le défaut) → chargement groupé, exactement comme avant.
- **Présent** → le script quitte le déclencheur commun pour un déclencheur `triggerOnce` qui lui est
  propre, conditionné à `c_time_after`. Les scripts partageant le **même** délai partagent un
  déclencheur, dans leur ordre de déclaration.
- Le délai doit être **strictement positif**. Une valeur nulle, négative ou non numérique est refusée
  avec un avertissement au build, et le script est alors chargé dans le déclencheur commun — il n'est
  jamais perdu.

> **C'est le délai qui décide de l'ordre, pas la position dans la liste.** Un script à `delay_seconds: 12`
> se charge après **tous** les scripts sans délai, où qu'il soit écrit. Si un script différé est déclaré
> avant un script non différé, le build vous avertit — la liste se lit alors dans un ordre différent de
> celui d'exécution.

Le comportement est **le même en build dynamique** : `veafDynamicConfig.lua` planifie le chargement au
lieu de le faire immédiatement. `generate_load_trigger` pilotant les deux modes, un délai ne pouvait pas
n'exister que dans l'un des deux.

`convert-other` **détecte** ces délais dans la mission d'origine et écrit `delay_seconds:` tout seul :
une mission adoptée reproduit donc l'étalement de l'amont sans que vous ayez à le remarquer.

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

Buildez la variante dev avec `veaf-tools mission build --profile DEV` (elle charge `FgMission.lua` + `FgDebug.lua`) ; le build par défaut ne charge que `FgMission.lua`.

> ⚠️ **Piège** : le deep-merge des profils **remplace les listes, il ne les concatène pas** (voir [`profiles:`](#profiles)). Le `custom_scripts.scripts` du profil doit donc **répéter** les scripts de base et ajouter celui spécifique à la variante — sinon les scripts de base sont perdus dans ce profil.

---

### `pipeline:` {#pipeline}

Contrôle les étapes optionnelles du pipeline de build. Voir la [Référence Pipeline](PIPELINE_REFERENCE.md) pour le schéma complet des fichiers de configuration de chaque étape.

Chaque étape accepte soit une valeur **scalaire** (`true`/`false` pour activer ou ignorer l'étape), soit un **mapping** d'options détaillées.

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

L'étape `presets` accepte, en plus de la forme scalaire, un mapping permettant de conserver l'injection radio tout en supprimant les planchettes (kneeboards) PNG globalement :

```yaml
pipeline:
  presets:
    enabled: true       # défaut true — injecte les préréglages radio ; false = désactive toute l'étape
    kneeboards: false   # défaut true — si false, aucune planchette PNG (KNEEBOARD/<type>/IMAGES/presets[-<coalition>].png) n'est générée
```

L'étape `waypoints` accepte le même genre de mapping, pour l'injection automatique du bullseye de la
mission (voir [Le bullseye, injecté tout seul](mission-maker/GUIDE.md#automatic-bullseye)) :

```yaml
pipeline:
  waypoints:
    enabled: true       # défaut true — injecte les plans de vol ; false = désactive toute l'étape
    bullseye: false     # défaut true — si false, aucun waypoint BULLSEYE n'est ajouté automatiquement
```

---

### `build:`

Contrôle la façon dont `veaf-tools mission build` résout le bundle de scripts VEAF.
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

> Voir la section [Mode développeur](developer/GUIDE.md#developer-mode) du Guide du développeur pour le workflow complet.

---

### `profiles:` {#profiles}

Profils de build nommés. Chaque profil est un ensemble de surcharges qui fusionnent en profondeur sur la `mission.yaml` de base lorsque vous passez `--profile <nom>` à `veaf-tools mission build`. Les clés absentes du profil conservent leur valeur de base. Les listes sont remplacées intégralement, pas concaténées. La clé `profiles:` elle-même n'est jamais transmise au générateur Lua ni au pipeline.

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
veaf-tools.exe mission build --profile TEST
veaf-tools.exe mission build --profile SERVER
```

> Si le profil nommé n'existe pas dans `mission.yaml`, un avertissement est émis et la config de base est utilisée sans modification.

---

### `build_variants:` {#build-variants}

Liste de profils de build à **émettre ensemble** : un seul `veaf-tools mission build` produit alors **un `.miz` par variante** (objectif « moulinette » — typiquement Modern et Cold-War d'un même dossier de mission, la variante n'étant qu'une différence de **config**). Chaque variante construit le pipeline complet avec son profil fusionné (voir [`profiles:`](#profiles)) et son `.miz` est suffixé du nom de variante (`<base>_<VARIANT>.miz`).

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
veaf-tools.exe mission build          # produit <base>_MODERN.miz ET <base>_COLD_WAR.miz
veaf-tools.exe mission build --profile MODERN   # ne produit que la variante MODERN (sans suffixe)
```

---

## Clés documentées ailleurs {#keys-documented-elsewhere}

Quatre clés de premier niveau sont lues par le build mais expliquées sur la page qui les a
introduites. Elles sont listées ici pour qu'une lecture de cette référence ne les manque pas.

| Clé | Ce qu'elle fait | Page qui la documente |
|-----|-----------------|-----------------------|
| `conversion_profile` | Nomme le profil d'adoption appliqué à une mission tierce (modules imposés, incompatibilités refusées à la validation) | [`convert-other`](mission-maker/CONVERT_OTHER.md) |
| `config_override` | Injecte des valeurs de configuration brutes par-dessus celles que le profil a décidées | [`convert-other`](mission-maker/CONVERT_OTHER.md) |
| `strip_native_triggers` | Liste les triggers de chargement de la mission d'origine à retirer, pour que les scripts VEAF ne soient pas chargés deux fois | [`convert-other`](mission-maker/CONVERT_OTHER.md) |
| `dcs_bridge` | Injecte le pont `dcs-bridge.lua` dans le `.miz` (`enabled`, `lua_path`) — c'est ce qui permet la capture de données depuis un DCS en cours | [Guide du créateur de mission](mission-maker/GUIDE.md) |

---

## Index par catégorie

Les six domaines sont les mêmes que dans la version anglaise, et chaque section de premier niveau de
cette page y figure exactement une fois.

### Cœur

| Section / Champ | Description |
|-----------------|-------------|
| [`global_log_level`](#global_log_level) | Forcer un niveau de log sur tous les modules |
| [`mission:`](#mission) | Nom, ère, chemin d'export |
| [`settings:`](#settings) | Constantes mission → `veaf.config.XXX` |
| [`veaf_tools:`](#veaf_tools) | Contrainte de version |
| [`modules:`](#modules) | Activer, désactiver et configurer chaque module Lua |
| [Clés documentées ailleurs](#keys-documented-elsewhere) | `conversion_profile`, `config_override`, `strip_native_triggers`, `dcs_bridge` |

### Sécurité

| Section / Champ | Description |
|-----------------|-------------|
| [`security:`](#security) | Activer/désactiver la sécurité, hashes de mots de passe |
| `modules.SECURITY` | [veafSecurity](mission-maker/scripts/veafSecurity.md) |

### Combat

| Section / Champ | Description |
|-----------------|-------------|
| [`modules.QRA`](#modulesqra-cap_missions-combat_missions) | Définitions de QRA |
| [`cap_missions:`](#modulesqra-cap_missions-combat_missions) | Définitions de missions CAP |
| [`combat_missions:`](#modulesqra-cap_missions-combat_missions) | Définitions de missions de combat |
| `modules.COMBATZONE` | [veafCombatZone](mission-maker/scripts/veafCombatZone.md) |
| `modules.AIRWAVES` | [veafAirWaves](mission-maker/scripts/veafAirWaves.md) |
| `modules.CASMISSION` | [veafCasMission](mission-maker/scripts/veafCasMission.md) |

### Défense aérienne

| Section / Champ | Description |
|-----------------|-------------|
| [`modules.SKYNET`](#third-party-modules) | Intégration Skynet IADS |
| `modules.SANCTUARY` | [veafSanctuary](mission-maker/scripts/veafSanctuary.md) |
| `modules.MISSILEGUARDIAN` | [veafMissileGuardian](mission-maker/scripts/veafMissileGuardian.md) |

### Assets & soutien

| Section / Champ | Description |
|-----------------|-------------|
| `modules.ASSETS` | [veafAssets](mission-maker/scripts/veafAssets.md) |
| `modules.CARRIER` | [veafCarrierOperations](mission-maker/scripts/veafCarrierOperations.md) |
| `modules.NAMEDPOINTS` | [veafNamedPoints](mission-maker/scripts/veafNamedPoints.md) |
| `modules.RADIO` | [veafRadio](mission-maker/scripts/veafRadio.md) |
| [`modules.RADIO.user_menus`](#modulesradiouser_menus--menus-radio-f10-en-yaml) | Menus radio F10 déclarés en YAML |
| `modules.SHORTCUTS` | [veafShortcuts](mission-maker/scripts/veafShortcuts.md) |
| `modules.ASSIST` | [veafAssist](mission-maker/scripts/veafAssist.md) |
| [`modules.CTLD` / `modules.CSAR`](#third-party-modules) | Transport de cargaison et récupération de pilote (sidecars tiers) |

### Pipeline de build

| Section / Champ | Description |
|-----------------|-------------|
| [`pipeline:`](#pipeline) | Contrôle des étapes du pipeline |
| `pipeline.presets` | [schéma presets.yaml](PIPELINE_REFERENCE.md#pipeline-step-1-presets) |
| `pipeline.waypoints` | [schéma waypoints.yaml](PIPELINE_REFERENCE.md#pipeline-step-2-waypoints) |
| `pipeline.spawnable_aircrafts` / `pipeline.dynamic_slot_templates` | [schéma groupes d'aéronefs](PIPELINE_REFERENCE.md#pipeline-step-3-aircraft-groups) |
| `pipeline.weather` | [schéma versions.yaml](PIPELINE_REFERENCE.md#pipeline-step-6-versions) |
| [`custom_scripts:`](#custom-scripts) | Scripts Lua custom à inclure dans la mission |
| [`community_scripts:`](#community-scripts) | Scripts communautaires embarqués *(forme héritée)* |
| [`build:`](#build) | Mode développeur et chemin des scripts |
| `build.dev_mode` | Utiliser le bundle Lua local au lieu des scripts publiés |
| `build.scripts_path` | Chemin vers un clone local de VEAF-Mission-Creation-Tools |
| [`profiles:`](#profiles) | Profils de build nommés (surcharges deep-merge pour `--profile`) |
| [`build_variants:`](#build-variants) | Produire une variante `.miz` par profil nommé |

---

## Index par module

| Module | Clé mission.yaml | Page doc |
|--------|-----------------|----------|
| veafRadio | `modules.RADIO` | [veafRadio](mission-maker/scripts/veafRadio.md#configuration-missionyaml) |
| veafShortcuts | `modules.SHORTCUTS` | [veafShortcuts](mission-maker/scripts/veafShortcuts.md#configuration-missionyaml) |
| veafNamedPoints | `modules.NAMEDPOINTS` | [veafNamedPoints](mission-maker/scripts/veafNamedPoints.md#configuration-missionyaml) |
| veafCarrierOperations | `modules.CARRIER` | [veafCarrierOperations](mission-maker/scripts/veafCarrierOperations.md#configuration-missionyaml) |
| veafAssets | `modules.ASSETS` | [veafAssets](mission-maker/scripts/veafAssets.md#configuration-missionyaml) |
| veafAssist | `modules.ASSIST` | [veafAssist](mission-maker/scripts/veafAssist.md#enable) |
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
