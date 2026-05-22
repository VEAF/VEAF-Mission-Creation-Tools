# Guide du créateur de missions

Intégrez le framework Lua VEAF dans vos missions DCS World pour offrir à vos joueurs du spawning dynamique, des zones de combat, des assets gérés, et plus — sans placer des centaines d'unités dans l'éditeur.

---

## Démarrage rapide — Votre première mission VEAF

### 1. Installer les outils

```powershell
# Téléchargez veaf-tools-updater.exe depuis la dernière release GitHub, puis :
.\veaf-tools-updater.exe update
```

Ceci télécharge `veaf-tools.exe` et les scripts Lua VEAF dans votre répertoire de travail.

### 2. Créer une mission dans l'éditeur DCS

- Créez une mission `.miz` standard (placez vos unités, triggers, etc.)
- Ajoutez un trigger **DO SCRIPT FILE** au démarrage de la mission qui charge `veaf-scripts.lua`

### 3. Configurer les modules

Créez un fichier `veaf-mission.yaml` pour déclarer quels modules VEAF sont actifs et configurer les assets, zones de combat, sécurité, etc.

### 4. Construire

```powershell
veaf-tools.exe mission-build --source ma-mission.miz --output ma-mission-veaf.miz
```

Le `.miz` de sortie est prêt à voler avec toutes les fonctionnalités VEAF.

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
| [Guide de migration](MIGRATION_GUIDE.md) | Conversion depuis VEAF v5 ou ajout de VEAF à une mission existante |
| [Référence des scripts](scripts/README.md) | Documentation par module avec commandes et exemples de config |
