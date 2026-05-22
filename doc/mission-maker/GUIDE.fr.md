# Guide du créateur de missions — VEAF Mission Creation Tools

Ce guide s'adresse aux concepteurs de missions DCS World qui souhaitent intégrer le framework VEAF dans leurs missions.

---

## Table des matières

1. [Ce que vous obtenez](#ce-que-vous-obtenez)
2. [Prérequis](#prérequis)
3. [Installation et mises à jour](#installation-et-mises-à-jour)
4. [Créer une nouvelle mission](#créer-une-nouvelle-mission)
5. [Charger les scripts dans DCS](#charger-les-scripts-dans-dcs)
6. [Configurer les modules](#configurer-les-modules)
7. [Outils de conception](#outils-de-conception)
8. [Workflow de build typique](#workflow-de-build-typique)
9. [Référence des scripts](#référence-des-scripts)
10. [Exemples de configuration](#exemples-de-configuration)
11. [Ressources](#ressources)

> **Migration d'une mission existante ?** Consultez le [Guide de migration](MIGRATION_GUIDE.md) — couvre à la fois VEAF MCT v5 → v6 et DCS vanilla → VEAF MCT.

---

## Ce que vous obtenez

Une mission VEAF est un fichier DCS `.miz` standard qui charge le framework Lua VEAF au démarrage. Cela offre aux joueurs et aux contrôleurs :

- **Commandes via marqueurs** — les joueurs tapent des commandes sur la carte F10 (faire apparaître des unités, créer des zones CAS, déplacer des groupes…)
- **Menus radio F10** — menus dynamiques pour chaque fonctionnalité activée
- **Types de missions préconstruits** — CAS, transport, opérations carrier, QRA, vagues aériennes, zones de combat
- **Gestion des actifs** — tankers, AWACS, carriers avec suivi d'état automatique et menus radio
- **Points nommés** — positions cartographiques réutilisables avec services ATC/TACAN optionnels
- **Intégrations** — Skynet IADS, Hound ELINT, CTLD/CSAR

---

## Prérequis

| Outil | Rôle | Obligatoire |
|-------|------|-------------|
| DCS World | Le simulateur | Oui |
| Git | Contrôle de version pour votre projet de mission | Recommandé |
| `veaf-tools-updater.exe` | Télécharge et installe la dernière release VEAF MCT | Oui |
| `veaf-tools.exe` | CLI de manipulation de `.miz` au moment du build | Oui (pour le pipeline de build) |
| VS Code ou similaire | Édition des fichiers Lua/YAML de configuration | Recommandé |

---

## Installation et mises à jour

### Première installation

Téléchargez `veaf-tools-updater.exe` depuis la [dernière release GitHub](https://github.com/VEAF/VEAF-Mission-Creation-Tools/releases/tag/published-latest) et placez-le dans le dossier de votre projet de mission, puis exécutez :

```powershell
.\veaf-tools-updater.exe
```

Cela télécharge `published.zip`, vérifie le checksum SHA256 et extrait tous les scripts et outils dans votre dossier de mission.

### Mises à jour

Exécutez la même commande dès qu'une nouvelle release est disponible :

```powershell
.\veaf-tools-updater.exe
```

La mise à jour n'est effectuée que si la version distante est plus récente. Pour forcer une réinstallation :

```powershell
.\veaf-tools-updater.exe --force
```

Pour épingler une version spécifique :

```powershell
.\veaf-tools-updater.exe --tag published-v6.1.0
```

Référence CLI complète : [Référence des outils](../TOOLS_REFERENCE.md)

---

## Créer une nouvelle mission

### Recommandé : forker la mission de démonstration

La façon la plus rapide de démarrer est de forker [VEAF-Demo-Mission](https://github.com/VEAF/VEAF-Demo-Mission), qui dispose déjà de la structure de dossiers correcte, d'un trigger de chargement de scripts fonctionnel, de configurations d'exemple et de scripts de build.

```powershell
git clone https://github.com/VEAF/VEAF-Demo-Mission.git my-mission
cd my-mission
.\veaf-tools-updater.exe
```

### Depuis zéro

1. Créez un dossier pour votre projet de mission (c'est votre dépôt Git)
2. Copiez votre fichier `.miz` existant dedans
3. Exécutez `veaf-tools-updater.exe` pour récupérer tous les scripts VEAF
4. Ajoutez le trigger de chargement de scripts dans l'éditeur de missions DCS (voir ci-dessous)
5. Créez un `missionconfig.lua` pour la configuration de vos modules

Structure de projet recommandée :

```
MyMission/
├── src/
│   ├── mission.miz               # Source .miz (non buildée)
│   ├── scripts/
│   │   └── missionconfig.lua     # Configuration de vos modules
│   ├── presets.yaml              # Préréglages de fréquences radio
│   ├── spawnables.yaml           # Groupes spawnable prédéfinis
│   └── waypoints.yaml            # Bullseye / points de navigation
├── build-scripts/                # Scripts de build VEAF (auto-installés)
├── veaf-scripts/                 # Scripts Lua VEAF (auto-installés)
├── veaf-tools.exe                # Outil CLI (auto-installé)
├── veaf-tools-updater.exe
└── build.cmd                     # Votre script de build
```

---

## Charger les scripts dans DCS

Les scripts VEAF sont chargés via un trigger `DO SCRIPT FILE` dans l'éditeur de missions DCS.

### Configuration minimale

Dans l'éditeur de missions DCS :

1. Ouvrez **Triggers**
2. Ajoutez un trigger `MISSION START`
3. Ajoutez une action `DO SCRIPT FILE` pointant vers `veaf-scripts.lua` dans votre dossier de mission
4. Ajoutez optionnellement une deuxième action `DO SCRIPT FILE` pour votre `missionconfig.lua`

### Avancé : chargeur inline

Pour un contrôle total de l'ordre de chargement, utilisez une action `DO SCRIPT` avec du Lua inline :

```lua
local basePath = lfs.writedir() .. "Missions\\MyMission\\"
dofile(basePath .. "veaf-scripts.lua")
dofile(basePath .. "scripts\\missionconfig.lua")
```

`veaf-scripts.lua` contient tous les modules VEAF concaténés dans l'ordre de dépendances. Votre `missionconfig.lua` est chargé après, ce qui vous permet de configurer et d'initialiser les modules.

---

## Configurer les modules

Chaque module VEAF expose des constantes de configuration que vous pouvez définir avant d'appeler `initialize()`. C'est dans votre `missionconfig.lua` que vous faites cela.

### Configuration minimale

```lua
-- Activer les marqueurs et le spawn de base
veafMarkers.initialize()
veafSpawn.initialize()
veafRadio.initialize()
veafRadio.refreshRadioMenu()
```

### Exemple de configuration complète

```lua
-- Sécurité : restreindre les commandes spawn aux utilisateurs authentifiés
veafSecurity.initialize()

-- Points nommés : positions prédéfinies
veafNamedPoints.initialize()

-- Marqueurs : intercepter le texte des marqueurs sur la carte F10
veafMarkers.initialize()

-- Spawn : permettre aux joueurs de faire apparaître des unités via les marqueurs
veafSpawn.initialize()

-- Mission CAS : générateur de CAS d'entraînement
veafCasMission.initialize()
veafCasMission.start()

-- Actifs : tankers, AWACS, carriers
veafAssets.Assets = {
  {
    name = "Texaco",
    description = "Texaco (KC-135)",
    groupName = "KC-135 Texaco",
    information = true,
    disposable = false,
  },
  {
    name = "Overlord",
    description = "Overlord (E-3A)",
    groupName = "E-3A Overlord",
    information = true,
    disposable = false,
  },
}
veafAssets.initialize()

-- Menu radio
veafRadio.initialize()
veafRadio.refreshRadioMenu()
```

### Niveaux de sécurité

| Niveau | Constante | Qui peut utiliser |
|--------|-----------|-------------------|
| 0 (public) | `veafSecurity.LEVEL_L0` | Tous les joueurs |
| 1 (pilotes) | `veafSecurity.LEVEL_L1` | Pilotes non-spectateurs |
| 9 (admin) | `veafSecurity.LEVEL_L9` | Admins authentifiés |

Définissez les mots de passe (hachages SHA-1) dans `missionconfig.lua` :

```lua
veafSecurity.password_L9[sha1("votremotdepasse")] = true
```

---

## Outils de conception

`veaf-tools.exe` manipule les fichiers `.miz` au moment du build — avant de les charger dans DCS.

| Commande | Ce qu'elle fait |
|----------|----------------|
| `build` | Construit la mission depuis `src\mission\` et `src\scripts\` — génère un `.miz` daté |
| `extract` | Extrait un `.miz` vers un dossier source (à exécuter une fois pour initialiser votre dépôt) |
| `inject-presets` | Injecte des plans de fréquences radio pour tous les cockpits humains |
| `inject-weather` | Insère des données météo réelles ou configurées |
| `inject-aircraft-groups` | Injecte des templates de groupes d'aéronefs |
| `extract-aircraft-groups` | Extrait les groupes d'aéronefs d'une mission |
| `inject-waypoints` | Injecte des waypoints (bullseye, points de navigation) pour les groupes humains |
| `extract-waypoints` | Extrait les waypoints d'une mission |

Référence complète : [Référence des outils](../TOOLS_REFERENCE.md)

---

## Workflow de build typique

```batch
@echo off
set MISSION_NAME=mission

REM 1. Construire la mission (lit src\mission\ + src\scripts\ → mission_YYYYMMDD.miz)
veaf-tools.exe build %MISSION_NAME% .

REM 2. Injecter les préréglages radio depuis la config YAML (optionnel)
REM veaf-tools.exe inject-presets %MISSION_NAME% --presets-file src\presets.yaml

REM 3. Injecter les waypoints bullseye et de navigation (optionnel)
REM veaf-tools.exe inject-waypoints %MISSION_NAME% --waypoints-file src\waypoints.yaml

REM 4. Injecter des variantes météo (optionnel)
REM veaf-tools.exe inject-weather %MISSION_NAME% --config-file src\missions.yaml
```

Commitez le contenu de `src\mission\` dans Git — pas le `.miz` lui-même. Utilisez `extract` une fois pour initialiser le dossier depuis une mission existante :

```batch
veaf-tools.exe extract my-mission.miz src
```

---

## Référence des scripts

Tous les modules Lua VEAF sont disponibles une fois `veaf-scripts.lua` chargé. Voir [scripts/README.md](scripts/README.md) pour la liste complète avec les guides de configuration.

**Navigation rapide par catégorie :**

| Catégorie | Modules |
|-----------|---------|
| Cœur | [veafSpawn](scripts/veafSpawn.md), [veafMove](scripts/veafMove.md), [veafSecurity](scripts/veafSecurity.md), [veafNamedPoints](scripts/veafNamedPoints.md) |
| Types de missions | [veafCasMission](scripts/veafCasMission.md), [veafCombatZone](scripts/veafCombatZone.md), [veafTransportMission](scripts/veafTransportMission.md), [veafQraManager](scripts/veafQraManager.md), [veafAirWaves](scripts/veafAirWaves.md) |
| Actifs | [veafAssets](scripts/veafAssets.md), [veafCarrierOperations](scripts/veafCarrierOperations.md), [veafGrass](scripts/veafGrass.md), [veafWeather](scripts/veafWeather.md) |
| Protection | [veafSanctuary](scripts/veafSanctuary.md), [veafMissileGuardian](scripts/veafMissileGuardian.md) |
| Intégrations | [veafSkynetIadsHelper](scripts/veafSkynetIadsHelper.md), [veafHoundElintHelper](scripts/veafHoundElintHelper.md) |

---

## Exemples de configuration

### Zone QRA

```lua
local northQra = VeafQRA:new()
  :setName("QRA-North")
  :setZone("ZONE-QRA-NORTH")
  :setCoalition(coalition.side.RED)
  :setGroups({ "MiG-29 QRA" })
  :setRearmTime(600)
  :initialize()
```

### Zone de combat

```lua
local strikeZone = VeafCombatZone:new()
  :setName("Strike Alpha")
  :setZoneName("ZONE-STRIKE-ALPHA")
  :setDescription("Colonne blindée avançant sur Senaki")
  :addElement(VeafCombatZoneElement:new():setGroupName("STRIKE-ALPHA-ARMOR"))
  :addElement(VeafCombatZoneElement:new():setGroupName("STRIKE-ALPHA-AAA"))
  :setBriefing("Détruisez tous les véhicules blindés. Attendez-vous à de la DCA.")
  :initialize()
```

### Zone Air Waves

```lua
local defenseZone = AirWaveZone:new()
  :setName("AW-Defense")
  :setZoneName("ZONE-DEFENSE")
  :setDescription("Zone d'interception")
  :addWave({ "MiG-23 Wave 1", "MiG-23 Wave 1b" })
  :addWave({ "MiG-29 Wave 2" })
  :setMinimumPlayersForWave(1)
  :initialize()
```

---

## Ressources

- [Référence des scripts](scripts/README.md) — tous les scripts avec les détails de configuration
- [Référence des outils](../TOOLS_REFERENCE.md) — référence CLI complète de `veaf-tools.exe`
- [Référence API Lua](../LUA_API_REFERENCE.md) — documentation complète de l'API Lua
- [VEAF Demo Mission](https://github.com/VEAF/VEAF-Demo-Mission) — mission d'exemple fonctionnelle
- [Discord VEAF](https://www.veaf.org/discord) — aide communautaire
