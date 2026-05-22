# Guide du créateur de missions — VEAF Mission Creation Tools

Ce guide s'adresse aux concepteurs de missions DCS World qui souhaitent intégrer le framework VEAF dans leurs missions.

---

## Table des matières

1. [Ce que vous obtenez](#ce-que-vous-obtenez)
2. [Prérequis](#prérequis)
3. [Installation et mises à jour](#installation-et-mises-à-jour)
4. [Créer une nouvelle mission](#créer-une-nouvelle-mission)
5. [Comment les scripts sont chargés](#comment-les-scripts-sont-chargés)
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

La façon la plus rapide de démarrer est de forker [VEAF-Demo-Mission](https://github.com/VEAF/VEAF-Demo-Mission), qui dispose déjà de la structure de dossiers correcte, de configurations d'exemple et de scripts de build.

```powershell
git clone https://github.com/VEAF/VEAF-Demo-Mission.git my-mission
cd my-mission
.\veaf-tools-updater.exe
```

### Depuis zéro

1. Créez un dossier pour votre projet de mission (c'est votre dépôt Git)
2. Copiez votre fichier `.miz` existant dedans
3. Exécutez `veaf-tools-updater.exe` pour récupérer tous les scripts VEAF
4. Extrayez votre mission : `veaf-tools.exe extract ma-mission.miz`
5. Configurez les modules dans `mission.yaml` et éventuellement `src/scripts/missionConfig.lua`

Structure de projet recommandée :

```
MyMission/
├── src/
│   ├── mission/                  # Données DCS extraites (via extract)
│   ├── scripts/
│   │   └── missionConfig.lua    # Configuration Lua runtime (optionnel)
│   ├── presets.yaml             # Préréglages de fréquences radio
│   ├── spawnables.yaml          # Groupes spawnable prédéfinis
│   └── waypoints.yaml           # Bullseye / points de navigation
├── published/                    # Scripts & outils VEAF (auto-installés)
├── mission.yaml                  # Configuration de build
├── veaf-tools.exe                # Outil CLI (auto-installé)
├── veaf-tools-updater.exe
└── build.cmd                     # Votre script de build
```

---

## Comment les scripts sont chargés

La commande `build` **injecte automatiquement** un trigger `DO SCRIPT FILE` au démarrage de la mission qui charge tous les scripts VEAF. Vous n'avez **pas** besoin d'ajouter manuellement un trigger dans l'éditeur de missions DCS.

Si vous avez un `src/scripts/missionConfig.lua` personnalisé, il est aussi injecté automatiquement par le builder.

### Ce que fait le builder

1. Lit `src/mission/` (les données DCS extraites)
2. Supprime tous les triggers VEAF existants
3. Injecte de nouveaux triggers `DO SCRIPT FILE` pour tous les scripts VEAF + vos scripts personnalisés
4. Écrit le `.miz` final

---

## Configurer les modules

VEAF MCT a deux niveaux de configuration :

- **`mission.yaml`** (à la racine du projet) — configuration de build : quels modules activer/désactiver, niveaux de log, sécurité, déclarations d'assets
- **`src/scripts/missionConfig.lua`** (optionnel) — code Lua runtime exécuté au démarrage de la mission, pour les configurations avancées comme les alias personnalisés, zones QRA, zones de combat, etc.

Pour la plupart des missions, `mission.yaml` suffit. N'utilisez `missionConfig.lua` que lorsque vous avez besoin de contrôle au niveau Lua.

### Exemple mission.yaml

```yaml
mission:
  name: "My-Mission"

lua_modules:
  SECURITY:
    enable: true
  SPAWN:
    logLevel: debug
  ASSETS:
    enable: true
    assets:
      - sort: 1
        name: "T1-Arco-1"
        description: "Arco-1 (KC-135)"
        information: "Tacan 64Y\nU290.50 (20)"
```

### Exemple missionConfig.lua (avancé)

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
veafSecurity.password_L9[sha1.hex("votremotdepasse")] = true
```

---

## Outils de conception

`veaf-tools.exe` manipule les fichiers `.miz` au moment du build — avant de les charger dans DCS.

| Commande | Ce qu'elle fait |
|----------|----------------|
| `build` | Construit la mission depuis `src/` — injecte les triggers VEAF, produit un `.miz` |
| `extract` | Extrait un `.miz` vers un dossier source (à exécuter une fois pour initialiser votre dépôt) |
| `inject-presets` | Injecte des plans de fréquences radio pour tous les cockpits humains |
| `inject-weather` | Crée des variantes météo/heure depuis une config YAML |
| `inject-aircraft-groups` | Injecte des templates de groupes d'aéronefs |
| `extract-aircraft-groups` | Extrait les groupes d'aéronefs d'une mission |
| `inject-waypoints` | Injecte des waypoints (bullseye, points de navigation) pour les groupes humains |
| `extract-waypoints` | Extrait les waypoints d'une mission |
| `convert` | Convertit une mission vanilla au format VEAF MCT |
| `convert-v5` | Migre un dossier mission v5 vers le format v6 |

Référence complète : [Référence des outils](../TOOLS_REFERENCE.md)

---

## Workflow de build typique

```powershell
# 1. Construire la mission (lit src/, injecte les triggers VEAF → .miz de sortie)
veaf-tools.exe build ma-mission.miz

# 2. Injecter les préréglages radio depuis la config YAML (optionnel, opère sur le .miz construit)
veaf-tools.exe inject-presets ma-mission.miz --presets-file src/presets.yaml

# 3. Injecter les waypoints bullseye et de navigation (optionnel)
veaf-tools.exe inject-waypoints ma-mission.miz --waypoints-file src/waypoints.yaml

# 4. Créer des variantes météo/heure (optionnel)
veaf-tools.exe inject-weather ma-mission.miz --config-file missions.yaml
```

Commitez le contenu de `src/` dans Git — pas le `.miz` construit. Utilisez `extract` une fois pour initialiser le dossier source depuis une mission existante :

```powershell
veaf-tools.exe extract ma-mission.miz
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
