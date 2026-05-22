# Migration d'une mission vers VEAF MCT v6

Ce guide couvre deux scénarios :

1. **[Depuis VEAF MCT v5.xx](#migration-depuis-veaf-mct-v5xx)** — votre mission utilise déjà les scripts VEAF MCT mais est antérieure à la chaîne d'outils v6
2. **[Depuis une mission DCS vanilla](#intégration-de-veaf-mct-dans-une-mission-dcs-vanilla)** — votre mission n'a aucun script VEAF MCT

Dans les deux cas, le résultat final est un **dossier de mission VEAF MCT v6** que vous gérez avec `veaf-tools.exe`.

---

## Avant de commencer

### Terminologie

| Terme | Signification |
|-------|--------------|
| **Dossier de mission** | Le répertoire géré par `veaf-tools` — contient les fichiers source, la config et le `.miz` |
| **Fichier `.miz`** | Le fichier de mission DCS (une archive ZIP) ; le résultat du build |
| **`published/`** | Dossier où `veaf-tools-updater.exe` installe les scripts VEAF |
| **`src/`** | Vos fichiers source spécifiques à la mission (scripts, données) |

### Prérequis

1. Installez `veaf-tools-updater.exe` — téléchargez depuis la [dernière release GitHub](https://github.com/VEAF/VEAF-Mission-Creation-Tools/releases/tag/published-latest)
2. Exécutez l'updater une fois pour installer `veaf-tools.exe` et tous les scripts VEAF :

```powershell
.\veaf-tools-updater.exe
```

3. Ayez votre fichier `.miz` d'origine sous la main

---

## Migration depuis VEAF MCT v5.xx

### Ce qui a changé en v6

| Domaine | v5 | v6 |
|---------|----|----|
| **Livraison des scripts** | Fichiers `.lua` individuels livrés par mission, mis à jour manuellement | Tous les modules concaténés dans un seul `veaf-scripts.lua` géré centralement |
| **Trigger DCS** | Triggers `DO SCRIPT FILE` manuels pointant vers chaque fichier `.lua` | Trigger unique injecté automatiquement par `veaf-tools build` ; aucun travail de trigger manuel |
| **Chaîne de build** | Pas d'étape de build — scripts chargés directement depuis le disque au démarrage de la mission | `veaf-tools.exe build` assemble le `.miz` depuis `src/mission/` + `src/scripts/` |
| **Script de build** | `build.cmd` complexe avec une ligne par commande d'injection | Deux lignes seulement : `veaf-tools-updater.exe` puis `veaf-tools.exe build` — étapes d'injection auto-détectées |
| **Pipeline d'auto-injection** | Chaque commande d'injection devait être ajoutée manuellement à `build.cmd` | `veaf-tools build` auto-détecte et exécute chaque étape quand le fichier correspondant est présent dans `src/` |
| **Mises à jour des outils** | Téléchargement et remplacement manuels des fichiers de scripts | `veaf-tools-updater.exe` — télécharge et vérifie la dernière release en une commande |
| **Config au moment du build** | Pas de fichier de config au moment du build | `mission.yaml` — contrôle les niveaux de log, l'activation/désactivation des modules, les surcharges d'étapes du pipeline |
| **Activation/désactivation de modules** | Éditer `missionConfig.lua` (ou simplement omettre l'appel à `initialize()`) | Section `lua_modules:` dans `mission.yaml` ; génère `veaf-modules-config.lua` automatiquement |
| **Configuration de modules** | Affectation directe : `veafSpawn.SpawnKeyphrase = "_spawn"` dans `missionConfig.lua` | La même affectation directe fonctionne toujours ; ou `veaf.setConfig("MODULE_ID", "key", value)` pour les surcharges pilotées par config |
| **Pattern d'init des modules** | Appels nus `veafXxx.initialize()` | Garde `if veafXxx then veafXxx.initialize() end` (tolère les modules absents) |
| **Emplacement de la config** | Initialisation dispersée dans des scripts de trigger DCS ou un fichier Lua séparé | Centralisée dans `src/scripts/missionConfig.lua` |
| **Migration de la config** | Réécriture manuelle | `veaf-tools.exe migrate-config` automatise les corrections courantes |
| **Niveaux de log des modules** | Définis par module en assignant `veafXxx.LogLevel` avant l'init | Section `lua_modules: → MODULE_ID: logLevel:` dans `mission.yaml` ou option CLI `--log-modules` |
| **Contrôle de version** | `.miz` binaire commité dans Git | Fichiers source (`src/`) commités ; `.miz` est un artefact de build |

### Migration étape par étape

#### 1. Créer le dossier de mission

Créez un dossier vide pour votre projet de mission :

```powershell
mkdir ma-mission
cd ma-mission
```

#### 2. Installer VEAF MCT v6

Copiez `veaf-tools-updater.exe` dans le dossier et exécutez :

```powershell
.\veaf-tools-updater.exe
```

Cela crée le répertoire `published/` avec tous les scripts et outils.

#### 3. Extraire la mission v5

Utilisez `veaf-tools.exe` pour décompresser le `.miz` dans la structure de dossiers :

```powershell
.\veaf-tools.exe extract "C:\chemin\vers\votre-mission-v5.miz" .
```

Cela crée :
```
ma-mission/
├── src/
│   ├── mission/          ← données de mission DCS brutes
│   │   ├── mission       ← dictionnaire Lua principal
│   │   ├── options
│   │   └── warehouses
│   └── scripts/
│       └── missionConfig.lua   ← créé automatiquement depuis les défauts
└── published/
    └── veaf-scripts.lua
```

#### 4. Builder une fois pour supprimer les anciens triggers v5

La commande `build` détecte et supprime automatiquement les anciens triggers `DO SCRIPT FILE` de v5 (activé par défaut via `--migrate-from-v5`) :

```powershell
.\veaf-tools.exe build ma-mission .
```

Le `.miz` de sortie aura :
- Toutes les anciennes actions de trigger v5 supprimées
- Un nouveau trigger v6 injecté qui charge `veaf-scripts.lua`

> Pour conserver les anciens triggers pour inspection d'abord, passez `--no-migrate-from-v5`.

#### 5. Porter votre configuration vers missionConfig.lua

Votre mission v5 avait probablement des appels d'initialisation de modules soit dans des scripts de trigger inline, soit dans un fichier Lua séparé. Déplacez-les tous dans `src/scripts/missionConfig.lua`.

Si vous avez déjà un `missionConfig.lua` d'une version VEAF précédente, exécutez l'outil de migration pour automatiser les corrections les plus courantes :

```batch
veaf-tools.exe migrate-config src\scripts\missionConfig.lua
```

Cela va :
- Commenter tout appel `doFile(...)` chargeant des scripts VEAF (le builder les injecte automatiquement maintenant).
- Envelopper les appels nus `veafXxx.initialize()` dans des gardes `if veafXxx then … end`.
- Afficher un extrait YAML `lua_modules:` que vous pouvez coller dans `mission.yaml` pour documenter (ou affiner) quels modules sont activés.

Le fichier migré est écrit sous `<nom>_v6.lua` à côté de l'original ; vérifiez-le, puis remplacez l'original une fois satisfait.

**Pattern v5 (trigger inline ou fichier séparé) :**
```lua
-- Quelque part dans un trigger DCS "DO SCRIPT" :
veaf.initialize()
veafSpawn.initialize()
veafRadio.initialize(true)
veafAssets.initialize()
-- ... définitions d'actifs inline ...
veafAssets.Assets = {
    { ... }
}
```

**Pattern v6 dans `src/scripts/missionConfig.lua` :**
```lua
veaf.config.MISSION_NAME = "Ma Mission"

-- Initialiser seulement les modules utilisés
if veafRadio then
    veafRadio.initialize(true)
end
if veafSpawn then
    veafSpawn.initialize()
end
if veafAssets then
    veafAssets.initialize()
    veafAssets.Assets = {
        { ... }
    }
end
```

La garde `if veafXxx then ... end` rend la config robuste : si un module n'est pas disponible (par exemple vous passez à une variante de script minimal), aucune erreur n'est levée.

#### 6. Vérifier les patterns v5 supprimés

Certaines constructions v5 n'existent plus ou ont été renommées :

| v5 | v6 |
|----|-----|
| `veaf.SecurityDisabled = true` | `veafSecurity.SecurityDisabled = true` |
| `veafSpawn.Keyphrase` défini au niveau global | Toujours `veafSpawn.Keyphrase` — inchangé |
| Table `veafAssets.Assets` inline | Même format de table — inchangé |
| Chargement de fichiers `.lua` individuels via `DO SCRIPT FILE` | Automatique — ne pas ajouter ces triggers manuellement |
| Scripts `IADS` chargés manuellement | Chargez-les via `src/scripts/` — ils sont pris en charge automatiquement |

#### 7. Vérifier avec un build de test

```powershell
.\veaf-tools.exe build ma-mission .
```

Ouvrez le `.miz` résultant dans DCS, chargez la mission et confirmez :
- Pas de triggers `DO SCRIPT FILE` en double dans l'éditeur de triggers
- Le trigger chargeur VEAF MCT v6 est présent (nommé quelque chose comme `VEAF scripts loader`)
- Les menus radio et les commandes de marqueurs fonctionnent comme prévu

#### 8. Configurer le contrôle de version

```powershell
git init
git add src/ .gitignore
git commit -m "feat: migration de ma-mission vers VEAF MCT v6"
```

Ajoutez `published/` et `*.miz` à `.gitignore` — ce sont des artefacts de build.

---

## Intégration de VEAF MCT dans une mission DCS vanilla

Une mission **vanilla** n'a pas de scripts VEAF MCT, pas de triggers spéciaux, et a été construite entièrement avec l'éditeur de missions DCS.

### Intégration étape par étape

#### 1. Créer le dossier de mission

```powershell
mkdir ma-mission
cd ma-mission
```

#### 2. Installer VEAF MCT v6

```powershell
.\veaf-tools-updater.exe
```

#### 3. Convertir le .miz vanilla

La commande `convert-mission` fait tout en une étape : extraction, injection des scripts VEAF MCT, rebuild.

```powershell
.\veaf-tools.exe convert-mission "C:\chemin\vers\vanilla.miz" .
```

Cela :
1. Extrait `vanilla.miz` dans `src/mission/`
2. Copie le `src/scripts/missionConfig.lua` par défaut
3. Injecte le trigger chargeur VEAF MCT v6
4. Reconstruit un nouveau `.miz` à côté du dossier

#### 4. Optionnel : préparer le dossier avec les défauts seulement

Si vous souhaitez configurer la structure du dossier sans convertir de mission immédiatement, utilisez `prepare` :

```powershell
.\veaf-tools.exe prepare .
```

Puis copiez votre `.miz` sous `mission.miz` et exécutez :

```powershell
.\veaf-tools.exe extract mission.miz .
.\veaf-tools.exe build mission .
```

#### 5. Configurer les modules à activer

Ouvrez `src/scripts/missionConfig.lua`. Par défaut, seuls les modules essentiels (marqueurs, spawn, radio) sont activés. Décommentez les modules que vous souhaitez :

```lua
veaf.config.MISSION_NAME = "Ma Mission Vanilla"

if veafRadio then
    veafRadio.initialize(true)
end
if veafSpawn then
    veafSpawn.initialize()
end

-- Décommenter pour activer les missions CAS :
-- if veafCasMission then
--     veafCasMission.initialize()
-- end

-- Décommenter pour activer les opérations carrier :
-- if veafCarrierOperations then
--     veafCarrierOperations.initialize()
-- end
```

Consultez la [référence missionConfig.lua](#référence-missionconfiglua) ci-dessous et les guides de scripts individuels dans [scripts/](scripts/README.md) pour toutes les options.

#### 6. Conserver votre contenu de mission existant

Tout ce que vous avez construit dans l'éditeur de missions DCS (unités, triggers, waypoints, zones) est préservé. VEAF ne supprime ni n'écrase le contenu de la mission — il se contente de :
- Ajouter un seul trigger de chargeur au démarrage de la mission
- Ajouter des entrées de menu radio F10 au moment de l'exécution
- Répondre aux commandes de marqueurs sur la carte F10

Vos triggers personnalisés, statiques et groupes sont intacts.

#### 7. Tester et itérer

```powershell
# Rebuilder après chaque changement de config
.\veaf-tools.exe build mission .
```

Chaque build produit un fichier `.miz` daté (ex. `mission_20260516.miz`). Ouvrez-le dans DCS et testez.

---

## Référence du dossier de mission

Après la migration, votre dossier devrait ressembler à ceci :

```
ma-mission/
├── src/
│   ├── mission/                ← données de mission DCS extraites (à commiter)
│   │   ├── mission             ← dictionnaire Lua principal de la mission
│   │   ├── options
│   │   └── warehouses
│   ├── scripts/
│   │   ├── missionConfig.lua   ← votre config de modules (à commiter)
│   │   └── veafDynamicConfig.lua   ← config de slots dynamiques (optionnel)
│   ├── presets.yaml            ← config des préréglages radio (optionnel)
│   ├── spawnables.yaml         ← groupes spawnable personnalisés (optionnel)
│   └── waypoints.yaml          ← waypoints personnalisés (optionnel)
├── published/                  ← installé par veaf-tools-updater (NE PAS commiter)
│   ├── veaf-scripts.lua
│   └── ...
├── veaf-tools.exe              ← installé par veaf-tools-updater (NE PAS commiter)
├── veaf-tools-updater.exe      ← à commiter
└── mission_20260516.miz        ← sortie du build (NE PAS commiter)
```

### .gitignore recommandé

```gitignore
published/
*.miz
*.log
__pycache__/
```

---

## Référence missionConfig.lua

Le `missionConfig.lua` minimal fonctionnel :

```lua
veaf.config.MISSION_NAME = "Ma Mission"   -- affiché dans les logs

-- Module radio (requis pour tous les menus F10)
if veafRadio then
    veafRadio.initialize(true)
end

-- Module spawn (requis pour les commandes de marqueurs)
if veafSpawn then
    veafSpawn.initialize()
end

-- Raccourcis (requis pour les alias)
if veafShortcuts then
    veafShortcuts.initialize()
end
```

Pour chaque module supplémentaire, consultez le guide correspondant dans [scripts/](scripts/README.md).

---

## Problèmes courants

### Le trigger "VEAF scripts loader" apparaît deux fois

Vous avez à la fois un ancien trigger `DO SCRIPT FILE` manuel et le nouveau trigger auto-injecté v6. Supprimez le trigger manuel de l'éditeur de missions DCS (ouvrez le `.miz`, éditez les triggers, supprimez l'ancien, enregistrez), puis ré-extrayez et rebuildez.

Alternativement, utilisez `--migrate-from-v5` sur le build pour que les anciens triggers soient supprimés automatiquement (c'est le comportement par défaut).

### Les menus radio n'apparaissent pas

Confirmez que `veafRadio.initialize(true)` est dans `missionConfig.lua` et n'est pas commenté.

### Les commandes de marqueurs ne fonctionnent pas

Confirmez que `veafSpawn.initialize()` est appelé. Vérifiez le log DCS (Saved Games\DCS\Logs\dcs.log) pour les erreurs VEAF.

### Le build échoue avec "VEAF scripts file not found"

Exécutez `veaf-tools-updater.exe` d'abord — le dossier `published/` est manquant ou obsolète.

---

## Voir aussi

- [Guide du créateur de missions](GUIDE.md) — workflow général de création de missions
- [Référence des scripts](scripts/README.md) — tous les modules disponibles
- [Référence des outils](../TOOLS_REFERENCE.md) — référence CLI complète de `veaf-tools.exe`
