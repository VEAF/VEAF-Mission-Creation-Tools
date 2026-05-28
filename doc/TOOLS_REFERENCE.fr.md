# VEAF Tools — Guide utilisateur et administrateur

## Vue d'ensemble

**VEAF Tools** (`veaf-tools-updater.exe`) est un outil en ligne de commande tout-en-un pour gérer les releases et mises à jour des VEAF Mission Creation Tools. Il offre deux fonctions principales :

- **`update`** — Pour les utilisateurs finaux : télécharger et installer la dernière version
- **`publish`** — Pour les administrateurs : créer et publier de nouvelles versions

---

## Table des matières

1. [Pour les utilisateurs : Mise à jour](#pour-les-utilisateurs--mise-à-jour)
2. [Pour les administrateurs : Publication](#pour-les-administrateurs--publication)
3. [Architecture du système](#architecture-du-système)

---

## Fichier de configuration (optionnel mais recommandé)

Vous pouvez stocker votre token GitHub et d'autres paramètres dans un fichier de configuration au lieu de les passer en arguments de ligne de commande.

### Installation

1. **Copier l'exemple de configuration :**
   ```bash
   copy veaf-tools-config.example.yaml veaf-tools-config.yaml
   ```

2. **Éditer `veaf-tools-config.yaml` :**
   ```yaml
   github:
     token: "ghp_votre_token_ici"
     owner: "VEAF"
     repo: "VEAF-Mission-Creation-Tools"
   ```

3. **Garder le fichier sécurisé :**
   - ⚠️ Ne jamais commiter `veaf-tools-config.yaml` dans git
   - Il est déjà dans `.gitignore` (par défaut)
   - Le token est votre mot de passe — gardez-le secret !

### Avantages

✅ Plus besoin de taper `--token` à chaque fois  
✅ Lignes de commande plus propres  
✅ Gestion centralisée des paramètres  
✅ Moins de risque d'exposition du token dans l'historique du shell  

Une fois configuré, tous les outils utiliseront automatiquement ces paramètres.

---

## Pour les utilisateurs : Mise à jour

### Mise à jour simple (recommandée)

Pour mettre à jour vos VEAF Tools à la dernière version :

```bash
veaf-tools-updater.exe
```

Cela va :
1. ✅ Vérifier quelle version est actuellement installée
2. ✅ Récupérer la dernière version depuis GitHub (tag `published-latest`)
3. ✅ Comparer les versions (ne met à jour que si la version est plus récente)
4. ✅ Télécharger `published.zip` depuis la Release GitHub
5. ✅ **Vérifier le checksum SHA256** (garantit l'intégrité du fichier)
6. ✅ Extraire et installer dans votre dossier de mission
7. ✅ Copier les fichiers clés (`veaf-tools-updater.exe`, scripts de build) dans le répertoire courant

**Résultat :** Vos outils sont à jour avec vérification d'intégrité

### Mise à jour vers une version spécifique

Si vous avez besoin d'une version précédente ou voulez être explicite :

```bash
veaf-tools-updater.exe --tag published-v6.0.0
```

Les tags de version disponibles apparaissent sur GitHub :
- `published-v6.0.1` — Version 6.0.1
- `published-v6.0.0` — Version 6.0.0
- `published-latest` — Toujours la version courante (par défaut)

### Forcer la mise à jour (ignorer la vérification de version)

Pour réinstaller la même version ou forcer la mise à jour :

```bash
veaf-tools-updater.exe --force
```

Cela ignore la vérification « est-ce plus récent ? » et installe quand même. Utile pour :
- Réparer une installation corrompue
- Réinstaller après des modifications manuelles
- Tester des versions spécifiques

### Mise à jour avec token GitHub (meilleures limites de débit)

Si vous atteignez les limites de débit de l'API GitHub (rare), vous pouvez fournir un Personal Access Token :

**Option 1 : Utiliser le fichier de configuration (recommandé)**
```yaml
# Dans veaf-tools-config.yaml
github:
  token: "ghp_xxxxxxxxxxxx"
```

Puis exécuter :
```bash
veaf-tools-updater.exe
```

**Option 2 : Ligne de commande (sans fichier de config)**
```bash
veaf-tools-updater.exe --token ghp_xxxxxxxxxxxx
```

Avantages :
- Augmente la limite de débit API : 60 → 5000 requêtes/heure
- Recommandé pour les scripts automatisés
- Optionnel mais utile dans certains scénarios

**Obtenir un token :**
1. Aller sur https://github.com/settings/tokens
2. Cliquer sur "Generate new token (classic)"
3. Sélectionner le scope : `repo` (contrôle total)
4. Copier le token (vous ne le reverrez plus !)

### Ignorer la vérification de checksum (non recommandé)

```bash
veaf-tools-updater.exe --no-verify-checksum
```

⚠️ **Non recommandé** — Les checksums protègent contre :
- La corruption réseau
- La falsification de fichiers
- Les téléchargements incomplets

À n'utiliser qu'en dernier recours.

### Langue de l'interface

La langue des messages est détectée automatiquement — aucune configuration requise :

1. Option CLI `--lang` (priorité maximale)
2. Variable d'environnement `VEAF_LANG`
3. `~/veafmct.yaml` → clé `lang:`
4. Locale du système (registre Windows / locale système sur Linux–macOS)
5. `en` (repli intégré)

Pour forcer la langue sur une seule exécution :

```bash
veaf-tools-updater.exe --lang fr
```

Pour définir une préférence persistante :

```bash
veaf-tools.exe user-config --set lang=fr
```

Valeurs supportées : `en`, `fr`.

### Sortie verbeuse (débogage)

Pour un dépannage détaillé :

```bash
veaf-tools-updater.exe --verbose
```

Affiche :
- Les étapes détaillées de l'opération
- Les réponses de l'API
- Les informations de débogage
- Le contexte complet des erreurs

### Toutes les options combinées

```bash
veaf-tools-updater.exe \
  --tag published-v6.0.1 \
  --token ghp_xxxxxxxxxxxx \
  --verbose \
  --force
```

### Obtenir de l'aide

```bash
veaf-tools-updater.exe --help
```

Affiche toutes les options disponibles et leurs descriptions.

---

## Pour les administrateurs : Publication

### Prérequis

Avant de publier, vous avez besoin de :

1. **Un fichier de configuration avec votre token GitHub :**
   ```bash
   copy veaf-tools-config.example.yaml veaf-tools-config.yaml
   ```

   Éditez `veaf-tools-config.yaml` et ajoutez votre token :
   ```yaml
   github:
     token: "ghp_votre_token_ici"
     owner: "VEAF"
     repo: "VEAF-Mission-Creation-Tools"
   ```

   **Obtenir un token :**
   - Aller sur https://github.com/settings/tokens
   - Cliquer sur "Generate new token (classic)"
   - Sélectionner le scope : `repo` (contrôle total des dépôts publics/privés)
   - Copier le token en sécurité (ne jamais le commiter dans git !)
   - ⚠️ Ne jamais commiter `veaf-tools-config.yaml` dans git !

2. **Les outils compilés** dans un répertoire `published/` :
   ```
   published/
   ├── veaf-tools-updater.exe      (exécutable compilé)
   ├── package.json                (avec le champ "version")
   ├── build-scripts/
   │   ├── buildDemoMission.cmd
   │   ├── buildHelicopterTrainingMission.cmd
   │   ├── buildTRADMission.cmd
   │   ├── buildOTMission.cmd
   │   └── ... autres scripts ...
   └── ... autres fichiers ...
   ```

3. **Créer une archive ZIP :**
   ```bash
   # Créer published.zip à partir du répertoire published/
   # Outils : 7-Zip, WinRAR, ou tout utilitaire zip
   # Résultat : published.zip contenant la structure ci-dessus
   ```

### Publication simple

Pour publier une nouvelle release :

**Avec fichier de configuration (recommandé) :**
```bash
veaf-tools-updater.exe publish 6.0.1 ./published.zip
```

**Sans fichier de configuration :**
```bash
veaf-tools-updater.exe publish 6.0.1 ./published.zip --token ghp_xxxxxxxxxxxx
```

**Arguments :**
- `6.0.1` — Numéro de version
- `./published.zip` — Chemin vers votre fichier zip
- Le token est lu depuis `veaf-tools-config.yaml` (s'il existe) ou le paramètre `--token`

**Ce qui se passe :**
1. ✅ Crée un tag Git : `published-v6.0.1`
2. ✅ Génère le checksum SHA256 du zip
3. ✅ Crée une Release GitHub pour ce tag
4. ✅ Upload `published.zip` comme asset
5. ✅ Upload les métadonnées de checksum (`published-metadata.json`)
6. ✅ Déplace le tag `published-latest` pour pointer ici
7. ✅ Pousse tout sur GitHub

**Résultat :** Les utilisateurs peuvent maintenant se mettre à jour avec `veaf-tools-updater`

### Ajouter des notes de version

```bash
veaf-tools-updater.exe publish 6.0.1 ./published.zip \
  --release-notes "Corrections : #123, #124. Nouveautés : améliorations de l'éditeur de mission"
```

Les notes de version apparaissent sur GitHub et aident les utilisateurs à comprendre ce qui a changé.

### Créer en brouillon (non publié)

```bash
veaf-tools-updater.exe publish 6.0.1 ./published.zip --draft
```

Les releases en brouillon :
- Ne sont pas visibles par les utilisateurs classiques
- Ne peuvent être modifiées que par vous
- Utiles pour tester avant la release officielle
- Visibles dans la liste des releases GitHub avec le label "Draft"

### Marquer comme pré-release

```bash
veaf-tools-updater.exe publish 6.0.1 ./published.zip --prerelease
```

Les pré-releases :
- Sont visibles par les utilisateurs mais marquées comme pré-release
- Idéales pour les versions beta/test
- Les utilisateurs ne se mettront pas automatiquement à jour vers elles
- Utiles pour `6.0.1-beta`, `6.1.0-rc1`, etc.

### Ignorer la création du tag

```bash
veaf-tools-updater.exe publish 6.0.1 ./published.zip --skip-tag
```

À utiliser quand :
- Vous avez déjà créé le tag Git manuellement
- Vous publiez sur un tag existant
- Vous déboguez le processus de release

### Sortie verbeuse

```bash
veaf-tools-updater.exe publish 6.0.1 ./published.zip --verbose
```

Affiche les informations de débogage détaillées pour le dépannage.

### Toutes les options combinées

```bash
veaf-tools-updater.exe publish 6.0.1 ./published.zip \
  --release-notes "Version 6.0.1 - Corrections et améliorations" \
  --verbose
```

### Obtenir de l'aide

```bash
veaf-tools-updater.exe publish --help
```

Affiche toutes les options disponibles.

---

## Pas à pas : Publier une release

### 1. Compiler votre code

```powershell
./compile.cmd
```

Crée :
- `./build/` — Scripts Lua
- `./published/` — Outils compilés

### 2. Vérifier la structure du répertoire

```
published/
├── veaf-tools-updater.exe
├── package.json              # Vérifier : a un champ "version"
├── build-scripts/
│   ├── buildDemoMission.cmd
│   ├── buildHelicopterTrainingMission.cmd
│   ├── buildTRADMission.cmd
│   ├── buildOTMission.cmd
│   └── ... plus de scripts ...
└── ... autres fichiers ...
```

### 3. Mettre à jour la version dans package.json

```json
{
  "version": "6.0.1",
  "name": "veaf-tools",
  ...
}
```

Assurez-vous que le champ version est présent et correct.

### 4. Créer published.zip

Utilisez n'importe quel outil zip (7-Zip, WinRAR, Explorateur Windows) :
```bash
# Résultat : published.zip contenant l'intégralité du répertoire published/
```

### 5. Configurer (première fois uniquement)

Créez et configurez `veaf-tools-config.yaml` :
```bash
copy veaf-tools-config.example.yaml veaf-tools-config.yaml
```

Éditez-le avec votre token GitHub :
```yaml
github:
  token: "ghp_votre_token_ici"
  owner: "VEAF"
  repo: "VEAF-Mission-Creation-Tools"
```

⚠️ **Important :** Ne jamais commiter `veaf-tools-config.yaml` dans git !

### 6. Publier sur GitHub

```bash
veaf-tools-updater.exe publish 6.0.1 ./published.zip \
  --release-notes "Version 6.0.1 - [vos notes de version]"
```

### 7. Vérifier sur GitHub

Visitez : https://github.com/VEAF/VEAF-Mission-Creation-Tools/releases

Vérifiez :
- ✅ La release apparaît pour la version 6.0.1
- ✅ Assets uploadés : `published.zip`, `published-metadata.json`
- ✅ Tag Git créé : `published-v6.0.1`
- ✅ Tag latest déplacé : `published-latest`

### 8. Annoncer aux utilisateurs

Informez les utilisateurs qu'ils peuvent se mettre à jour :
```bash
veaf-tools-updater.exe
```

---

## Architecture du système

### Système de versionnement

Le système utilise des **tags Git** pour gérer les versions :

```
Dépôt Git
├── published-v6.0.1   ──► Release GitHub avec assets
├── published-v6.0.0   ──► Release GitHub avec assets
├── published-v5.9.9   ──► Release GitHub avec assets
└── published-latest   ──► Pointe vers la version courante (mobile)
```

**Avantages :**
- ✅ Historique de versions clair dans Git
- ✅ Facile de revenir à n'importe quelle version précédente
- ✅ `published-latest` toujours disponible pour les utilisateurs
- ✅ Snapshots de versions immuables

### Vérification d'intégrité

Chaque release inclut une vérification de checksum :

```
L'utilisateur télécharge :
  published.zip              (outils compilés)
  published-metadata.json    (contient le SHA256)

Processus de mise à jour :
  1. Calculer SHA256(published.zip)
  2. Comparer avec published-metadata.json
  3. Si correspondance ✓ → Installer
  4. Si différence ✗ → Erreur (abandon, réessayer)
```

**Protection contre :**
- La corruption réseau
- Les téléchargements incomplets
- La falsification de fichiers

### Comparaison de versions

Le système compare correctement les versions sémantiques :

```
Installée : 6.0.0
Disponible : 6.0.1
Résultat :    6.0.1 > 6.0.0 → Mise à jour disponible ✓

(Les anciens systèmes faisaient une comparaison de chaînes et échouaient)
```

---

## Structure des fichiers

### Ce que les utilisateurs ont

Après mise à jour, les utilisateurs ont :

```
Répertoire courant :
├── veaf-tools-updater.exe            (exécutable)
├── buildDemoMission.cmd              (script)
├── buildHelicopterTrainingMission.cmd (script)
├── buildTRADMission.cmd              (script)
├── buildOTMission.cmd                (script)
└── ... autres scripts de build ...

Dossier mission (spécifié lors de la mise à jour) :
└── published/
    ├── veaf-tools-updater.exe
    ├── package.json                  (info version)
    ├── build-scripts/
    │   ├── buildDemoMission.cmd
    │   └── ... scripts ...
    └── ... autres fichiers ...
```

### Ce que GitHub affiche

Après publication :

```
Release : published-v6.0.1
├── Asset : published.zip              (outils compilés)
├── Asset : published-metadata.json    (checksums)
└── Notes de version

Tags Git :
├── published-v6.0.1 ──► commit abc123def...
├── published-latest ──► commit abc123def... (identique)
└── published-v6.0.0 ──► commit xyz789uvw...
```

---

## Détection de la langue

`veaf-tools.exe` et `veaf-tools-updater.exe` affichent leurs messages dans la langue du système automatiquement — aucune configuration requise. L'ordre de détection est :

1. Option CLI `--lang`
2. Variable d'environnement `VEAF_LANG`
3. `~/veafmct.yaml` → clé `lang:`
4. Locale du système (registre Windows / locale système sur Linux–macOS)
5. `en` (repli intégré)

Langues supportées : anglais (`en`), français (`fr`). Voir [Configuration de la langue](mission-maker/GUIDE.fr.md#configuration-globale-utilisateur) pour les détails complets.
