# Guide du créateur de missions

Intégrez le framework Lua VEAF dans vos missions DCS World pour offrir à vos joueurs du spawning dynamique, des zones de combat, des assets gérés, et plus — sans placer des centaines d'unités dans l'éditeur.

---

## Démarrage rapide — Votre première mission VEAF

### 1. Installer les outils

```powershell
# Téléchargez veaf-tools-updater.exe depuis la dernière release GitHub et placez-le dans le dossier de votre projet de mission.
.\veaf-tools-updater.exe
```

> **Sécurité Windows :** Windows peut bloquer les fichiers `.exe` téléchargés depuis Internet. Si le fichier ne s'exécute pas, cliquez droit dessus → **Propriétés** → onglet **Général** → cochez **Débloquer** en bas de la fenêtre → **OK**.

Ceci télécharge `veaf-tools.exe` et les scripts Lua VEAF dans votre répertoire de travail.

> **Langue :** Les messages s'affichent dans la langue du système automatiquement (anglais ou français). Pour changer la langue : `veaf-tools.exe user-config --set lang=fr`. Voir [Configuration de la langue](GUIDE.md#global-user-configuration).

### 2. Créer une mission dans l'éditeur DCS

Créez une mission `.miz` standard (placez vos unités, waypoints, météo, etc.). Pas besoin d'ajouter de trigger VEAF — l'outil de build s'en charge.

### 3. Extraire la mission

```powershell
veaf-tools.exe extract ma-mission.miz
```

Ceci extrait le `.miz` dans un dossier mission (répertoire courant par défaut) que vous pouvez versionner et configurer.

### 4. Configurer les modules

Éditez `mission.yaml` à la racine de votre dossier mission pour déclarer quels modules VEAF sont actifs et configurer les assets, zones de combat, raccourcis, sécurité, etc.

### 5. Construire

```powershell
veaf-tools.exe build ma-mission.miz
```

L'outil de build lit le dossier mission, **injecte automatiquement** le trigger chargeur VEAF, et produit un `.miz` prêt à voler avec toutes les fonctionnalités VEAF MCT.

---

## Ce que vous offrez à vos joueurs

| Module | Expérience joueur |
|--------|-------------------|
| [veafSpawn](scripts/veafSpawn.md) | Spawner n'importe quelle unité via les marqueurs F10 |
| [veafCasMission](scripts/veafCasMission.md) | Entraînement CAS procédural avec niveaux de difficulté |
| [veafCombatZone](scripts/veafCombatZone.md) | Zones de combat prédéfinies, activables à la demande |
| [veafAssets](scripts/veafAssets.md) | Ravitailleurs, AWACS, porte-avions gérés avec auto-respawn |
| [veafCarrierOperations](scripts/veafCarrierOperations.md) | Workflow complet de recovery porte-avions |
| [veafQraManager](scripts/veafQraManager.md) | Scramble QRA automatique en cas d'intrusion |
| [veafAirWaves](scripts/veafAirWaves.md) | Missions de combat aérien par vagues |
| [veafSecurity](scripts/veafSecurity.md) | Protection par mot de passe pour serveurs multijoueur |

Voir le [catalogue complet des scripts](scripts/README.md) pour les 17+ modules.

---

## Pour aller plus loin

| Document | Quand le lire |
|----------|---------------|
| [Guide complet](GUIDE.md) | Setup détaillé, configuration, et workflow de build |
| [Guide de migration](MIGRATION_GUIDE.md) | Conversion depuis VEAF MCT v5 ou ajout de VEAF MCT à une mission existante |
| [Référence des scripts](scripts/README.md) | Documentation par module avec commandes et exemples de config |
| [Assistant IA — installation](AI_ASSISTANT_INSTALL.md) | Installer le plugin Claude Code pour créer/éditer une mission en langage naturel |
| [Assistant IA — catalogue](AI_ASSISTANT_CATALOG.md) | Ce que vous pouvez demander à l'assistant IA, en langage clair |
