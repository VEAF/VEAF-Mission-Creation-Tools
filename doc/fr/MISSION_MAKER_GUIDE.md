# Guide du créateur de missions

Guide pour créer et gérer des missions DCS World avec les scripts VEAF.

> 🌐 [English version](../MISSION_MAKER_GUIDE.md)

## Table des matières

- [Qu'est-ce qu'une mission VEAF ?](#quest-ce-quune-mission-veaf)
- [Prérequis](#prérequis)
- [Obtenir les scripts VEAF](#obtenir-les-scripts-veaf)
- [Créer une nouvelle mission](#créer-une-nouvelle-mission)
- [Charger les scripts dans DCS](#charger-les-scripts-dans-dcs)
- [Modules runtime](#modules-runtime)
- [Outils de conception](#outils-de-conception)
- [Construire votre mission](#construire-votre-mission)
- [Référence de configuration](#référence-de-configuration)

---

## Qu'est-ce qu'une mission VEAF ?

Une mission VEAF est un fichier `.miz` DCS World standard qui charge le framework Lua VEAF au démarrage de la mission. Cela donne aux joueurs et aux contrôleurs accès à :

- **Commandes via marqueurs F10** — saisissez une commande sur la carte et VEAF l'interprète (spawner des unités, créer des missions, marquer des positions…)
- **Menus radio F10** — menus dynamiques pour toutes les fonctionnalités VEAF
- **Types de missions prédéfinis** — CAS, transport, opérations carrier, QRA, air waves, zones de combat
- **Gestion des assets** — tankers, AWACS, carriers avec suivi automatique de l'état
- **Points nommés** — positions réutilisables avec support des fréquences ATC

---

## Prérequis

| Outil | Rôle | Requis |
|-------|------|--------|
| DCS World | Le simulateur | ✅ |
| Git | Contrôle de version pour le dossier de mission | ✅ |
| `veaf-tools-updater.exe` | Télécharge et installe la dernière version VEAF | ✅ |
| `veaf-tools.exe` | CLI de manipulation de mission à la compilation | ✅ |

---

## Obtenir les scripts VEAF

### Installation initiale

Téléchargez `veaf-tools-updater.exe` depuis la [dernière release GitHub](https://github.com/VEAF/VEAF-Mission-Creation-Tools/releases/tag/published-latest), placez-le dans votre dossier de mission, puis exécutez :

```powershell
.\veaf-tools-updater.exe
```

Cette commande télécharge `published.zip`, vérifie le checksum SHA256 et extrait tous les scripts dans votre dossier de mission.

### Rester à jour

Exécutez la même commande à chaque nouvelle release VEAF disponible :

```powershell
.\veaf-tools-updater.exe
```

Pour une version spécifique :

```powershell
.\veaf-tools-updater.exe --tag published-v6.0.5
```

Consultez [TOOLS_REFERENCE.md](../TOOLS_REFERENCE.md) pour la référence complète de `veaf-tools-updater.exe` et `veaf-tools.exe`.

---

## Créer une nouvelle mission

### Recommandé : forker la mission Demo

La façon la plus rapide de démarrer est de forker [VEAF-Demo-Mission](https://github.com/VEAF/VEAF-Demo-Mission), qui dispose déjà de :
- La structure de dossiers correcte
- Un trigger d'injection de scripts fonctionnel
- Des configurations d'exemple pour les modules courants
- Des scripts de build

```powershell
git clone https://github.com/VEAF/VEAF-Demo-Mission.git ma-mission
cd ma-mission
.\veaf-tools-updater.exe
```

### Depuis zéro

Si vous partez d'un fichier mission existant :

1. Créez un dossier pour votre projet de mission (ce sera votre dépôt Git)
2. Copiez-y votre fichier `.miz`
3. Exécutez `veaf-tools-updater.exe` pour récupérer tous les scripts VEAF
4. Ajoutez le trigger de chargement des scripts (voir [Charger les scripts dans DCS](#charger-les-scripts-dans-dcs))
5. Créez un `mission.yaml` à la racine du dossier de mission pour configurer vos modules (ou lancez `veaf-tools.exe generate-config` pour générer un modèle commenté)

---

## Charger les scripts dans DCS

Les scripts VEAF sont chargés via un trigger `DO SCRIPT FILE` dans l'éditeur de mission DCS.

### Configuration minimale du trigger

Dans l'éditeur de mission DCS :

1. Ajoutez un trigger `MISSION START`
2. Ajoutez une action `DO SCRIPT FILE`
3. Pointez-la vers `veaf-scripts.lua` dans votre dossier de mission

### Ordre de chargement des scripts

Pour les missions nécessitant un contrôle plus fin :

```lua
-- Dans une action DO SCRIPT (Lua inline) :
dofile(veaf.LuaUtils.joinPath(basePath, "veaf-scripts.lua"))

-- Puis le code spécifique à la mission (optionnel) :
dofile(veaf.LuaUtils.joinPath(basePath, "mission-script.lua"))
```

Le fichier `veaf-scripts.lua` contient tous les modules concaténés dans l'ordre des dépendances. La configuration des modules est gérée par `veaf-config.lua`, qui est auto-généré par `veaf-tools build` depuis `mission.yaml`. Le code Lua personnalisé (logique non standard qui ne peut pas être exprimée en YAML) va dans `mission-script.lua`.

---

## Modules runtime

Tous ces modules sont disponibles une fois `veaf-scripts.lua` chargé.

### Cœur

| Module | Rôle |
|--------|------|
| `veaf` | Framework central, logging et fonctions utilitaires |
| `veafMarkers` | Intercepte les marqueurs F10 et dispatch les commandes |
| `veafInterpreter` | Analyse le texte des marqueurs en commandes structurées |
| `veafRadio` | Gère les menus radio F10 dynamiques |
| `veafSecurity` | Permissions basées sur les rôles pour les commandes VEAF |
| `veafNamedPoints` | Positions nommées avec services ATC/TACAN |
| `veafShortcuts` | Alias de raccourcis pour les commandes courantes |
| `veafTime` | Utilitaires de temps de mission |
| `veafEventHandler` | Écouteur et dispatcher d'événements DCS |
| `veafCacheManager` | Met en cache les calculs coûteux |

### Spawn

| Module | Rôle |
|--------|------|
| `veafSpawn` | Spawner des avions, unités terrestres, fumée, JTAC, cargo, FARP via marqueurs |
| `veafUnits` | Définitions de templates d'unités (groupes, coalitions, catégories) |
| `veafMove` | Déplacer/téléporter des unités existantes |
| `veafGroundAI` | Comportement IA amélioré pour les unités terrestres |

### Types de missions

| Module | Rôle |
|--------|------|
| `veafCombatMission` | Classe de base pour tous les types de missions |
| `veafCombatZone` | Zones de combat activables/désactivables avec scoring |
| `veafCasMission` | Missions CAS générées avec packages de menaces |
| `veafTransportMission` | Missions d'enlèvement et de livraison en hélicoptère/transport |
| `veafCarrierOperations` | Récupération sur carrier (BRC, TACAN, gestion ICLS) |
| `veafAirWaves` | Vagues d'attaque aériennes répétées avec suivi des vagues |
| `veafQraManager` | Avions en alerte avec machine d'état |
| `veafSanctuary` | Zones protégées qui détruisent les unités en violation |
| `veafMissileGuardian` | Intercepte des missiles entrants spécifiques |

### Assets

| Module | Rôle |
|--------|------|
| `veafAssets` | Tankers, AWACS, carriers — suivi d'état et menus radio |
| `veafAirbases` | Données des bases aériennes et configuration ATC |
| `veafGrass` | Configuration de piste en herbe non préparée |
| `veafWeather` | Météo dynamique et conditions ATC |

### Intégrations

| Module | Rôle |
|--------|------|
| `veafRemote` | Commandes à distance NIOD/SLMOD via socket |
| `veafSkynetIadsHelper` | Configure Skynet IADS depuis les données VEAF |
| `veafSkynetIadsMonitor` | Surveille la santé de Skynet IADS et alerte |
| `veafHoundElintHelper` | Intégration avec Hound ELINT |

### Activer / Désactiver les modules

L'approche recommandée est de déclarer les modules dans `mission.yaml`. `veaf-tools build` génère automatiquement `veaf-config.lua` :

```yaml
# mission.yaml
lua_modules:
  MARKERS:
    enable: true
  SPAWN:
    enable: true
  ASSETS:
    enable: true
  RADIO:
    enable: true
    init:
      help_menus: true
  NAMED_POINTS:
    enable: false   # explicitement désactivé
```

Les modules avec `enable: true` ont leur `initialize()` appelée automatiquement. Les modules avec `enable: false` reçoivent un appel `veaf.setConfig("MODULE", "enable", false)` pour que le runtime puisse ignorer leur initialisation.

Pour une configuration non standard qui ne peut pas être exprimée en YAML, utilisez `mission-script.lua` (chargé après `veaf-config.lua`) :

```lua
-- mission-script.lua — code personnalisé uniquement
if veafSpawn then
  veafSpawn.JTACAutoLase = function(unit)
    return unit:getCoalition() == coalition.side.RED
  end
end
```

---

## Outils de conception

`veaf-tools.exe` manipule les fichiers `.miz` à la compilation, avant de les charger dans DCS. Lancez-le depuis votre dossier de mission.

### Opérations disponibles

| Commande | Rôle |
|---------|------|
| `build` | Construit la mission depuis `src\mission\` et `src\scripts\` — produit un `.miz` daté ; exécute aussi automatiquement les étapes d'injection configurées via `pipeline:` dans `mission.yaml` |
| `extract` | Extrait un `.miz` dans un dossier source (à lancer une fois pour initialiser votre dépôt) |
| `inject-presets` | Injecte les plans de fréquences radio pour tous les groupes humains |
| `inject-weather` | Insère une météo réelle ou configurée |
| `inject-aircraft-groups` | Injecte des templates de groupes aériens |
| `extract-aircraft-groups` | Extrait les groupes aériens d'une mission |
| `inject-waypoints` | Injecte des waypoints (bullseye, etc.) pour les groupes humains |
| `extract-waypoints` | Extrait les waypoints d'une mission |
| `generate-config` | Génère un modèle `mission.yaml` entièrement commenté avec toutes les options disponibles |
| `migrate-config` | Migre un `missionConfig.lua` v5 : supprime les appels `doFile`, entoure les appels `initialize()` nus de gardes, produit un extrait YAML `lua_modules:` |
| `convert-v5` | Conversion complète d'un dossier v5 → v6 : migre `missionConfig.lua` → `mission-script.lua`, extrait les patterns reconnus dans `mission.yaml`, convertit les fichiers de configuration pipeline |

> **Option globale :** `--lang en|fr` force la langue pour toutes les sorties CLI et les commentaires des fichiers générés, en remplaçant la détection automatique depuis la locale de l'OS.

Référence complète des commandes : [TOOLS_REFERENCE.md](../TOOLS_REFERENCE.md)

---

## Construire votre mission

### Script de build typique

La plupart des dépôts de missions basées sur VEAF suivent ce schéma minimal (par exemple `build.cmd`) :

```batch
@echo off
set MISSION_NAME=mission

REM 1. Mettre à jour veaf-tools vers la dernière release
veaf-tools-updater.exe

REM 2. Construire la mission — exécute aussi les étapes d'injection configurées dans mission.yaml
veaf-tools.exe build %MISSION_NAME% .
```

La commande `build` détecte automatiquement et exécute les étapes d'injection optionnelles selon les fichiers présents dans `src\` :

| Fichier présent dans `src\` | Étape exécutée automatiquement |
|-----------------------------|-------------------------------|
| `src\presets.yaml` | `inject-presets` |
| `src\waypoints.yaml` | `inject-waypoints` |
| `src\aircraft-templates.yaml` ou `src\templates.yaml` | `inject-aircraft-groups` |
| `src\missions.yaml` ou `src\versions.yaml` | `inject-weather` |

Pour désactiver ou personnaliser une étape, ajoutez une section `pipeline:` dans `mission.yaml` (voir [Configuration du pipeline](#configuration-du-pipeline)).

### Diffs Git propres

La commande `build` lit depuis `src\mission\` (un dossier de fichiers Lua en texte brut) plutôt qu'un `.miz` binaire. Committez le contenu de `src\mission\` dans Git — pas le `.miz` lui-même — pour des diffs lisibles. Utilisez `extract` une fois pour initialiser le dossier depuis une mission existante :

```batch
veaf-tools.exe extract ma-mission.miz src
```

---

## Référence de configuration

### Configuration des modules via mission.yaml

`mission.yaml` est la source de vérité unique pour la configuration des modules. `veaf-tools build` le lit et génère `veaf-config.lua`, qui est injecté dans le `.miz` et chargé avant `mission-script.lua`.

Lancez `veaf-tools.exe generate-config` dans votre dossier de mission pour obtenir un modèle entièrement commenté avec toutes les options disponibles.

#### Identité de la mission

```yaml
mission:
  name: "OpenTraining_Caucasus"
  era: MODERN            # MODERN | WWII | KOREA | VIETNAM
  export_path: null      # optionnel : chemin pour l'export de données
  language: fr           # en | fr — langue pour les fichiers générés et le CLI (défaut : locale de l'OS)
```

#### Sécurité

```yaml
security:
  disabled: false        # mettre true uniquement pour les tests — jamais en production
```

#### Modules avec options typées

```yaml
lua_modules:
  RADIO:
    enable: true
    init:
      help_menus: true   # afficher les menus d'aide dans F10
  CARRIER:
    enable: true
    init:
      include_carrier_operations_radio: true
  ASSETS:
    enable: true
    assets:              # liste des assets nommés
      - sort: 10
        name: "Tanker-Shell"
        groupName: "TANKER-SHELL"
        unitType: "KC-135"
```

#### Définitions QRA

```yaml
qra:
  silence_all: false
  definitions:
    - name: "QRA-Blue-North"
      coalition: BLUE
      enemy_coalitions: [RED]
      trigger_zone: "ZONE-QRA-NORTH"
      simple_groups: ["F-15C QRA"]
      delay_before_rearming: 120
```

#### Missions CAP

```yaml
cap_missions:
  - group_name: "CAP-NORTH"
    menu_name: "CAP Nord"
```

### Configuration du pipeline

La section `pipeline:` dans `mission.yaml` contrôle les étapes d'injection automatique :

```yaml
pipeline:
  presets: true              # inject-presets depuis src/presets.yaml
  waypoints: true            # inject-waypoints depuis src/waypoints.yaml
  aircraft_groups: true      # inject-aircraft-groups depuis src/aircraft-templates.yaml
  weather: true              # inject-weather depuis src/versions.yaml
```

Chaque étape peut être activée (`true`), désactivée (`false`) ou omise (détection automatique si le fichier source est présent).
