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
4. [Dépannage](#dépannage)

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

## Interroger la documentation (assistant IA)

`veaf-tools ask` répond à vos questions sur la documentation VEAF via un assistant IA, en s'appuyant sur la documentation elle-même (RAG). C'est le même assistant que le chatbot du site de documentation.

**Aucune configuration, aucune clé API.** La commande envoie votre question au service de documentation VEAF, qui génère la réponse — pas besoin de clé Google/Gemini. (Des limites d'usage raisonnable s'appliquent par utilisateur.) Une connexion Internet est requise.

### Utilisation

```bash
# Question unique
veaf-tools ask "Comment activer CTLD dans ma mission ?"

# Session interactive (tapez « quit » ou Ctrl-D pour quitter)
veaf-tools ask

# Réponse en anglais (par défaut suit --lang)
veaf-tools --lang en ask "How are radio presets injected?"
```

Disponible aussi depuis le TUI interactif via **« Interroger la documentation »**.

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

## Dépannage

### Problème : « Tag not found on GitHub »

**Cause :** le tag Git a été créé localement mais n'a pas été poussé sur GitHub.

**Solution :**
```bash
# Check if tag exists locally
git tag -l published-v6.0.1

# If it exists, push it
git push origin refs/tags/published-v6.0.1

# If it doesn't exist, create it
git tag -a published-v6.0.1 -m "Release 6.0.1"
git push origin refs/tags/published-v6.0.1
```

### Problème : « Checksum mismatch » lors de la mise à jour

**Cause :** corruption du fichier pendant le téléchargement (rare) ou problème réseau.

**Solution :**
```bash
# Try again (usually fixes it)
veaf-tools-updater.exe

# If persists, check GitHub release:
# https://github.com/VEAF/VEAF-Mission-Creation-Tools/releases
```

### Problème : « GitHub rate limit exceeded »

**Cause :** trop d'appels à l'API en peu de temps.

**Solution :**
```bash
# Option 1: Wait 1 hour (rate limit resets)

# Option 2: Use Personal Access Token (better limits)
veaf-tools-updater.exe --token ghp_xxxxxxxxxxxx

# Get token from: https://github.com/settings/tokens
# Scope: repo (full control)
```

### Problème : « Permission denied » lors de l'installation

**Cause :** écriture impossible dans le dossier mission ou le répertoire courant.

**Solution :**
```bash
# Run as Administrator (Windows)
# Or specify a different directory as a positional argument:
veaf-tools-updater.exe "C:\alternative\path"
```

### Problème : fichier introuvable lors de la publication

**Cause :** `published.zip` n'existe pas ou le chemin est incorrect.

**Solution :**
```bash
# Verify file exists
dir published.zip

# Use correct absolute path
veaf-tools-updater.exe publish 6.0.1 "C:\full\path\to\published.zip" --token ghp_xxx

# Create zip if missing
# (select published/ folder, right-click → Send to → Compressed (zipped))
```

### Problème : « Failed to create GitHub release »

**Cause :** généralement un problème de token ou de réseau.

**Solution :**
```bash
# Check token:
# 1. Verify veaf-tools-config.yaml exists and has correct token
# 2. Go to https://github.com/settings/tokens
# 3. Verify scope includes "repo"
# 4. Create new token if old one expired
# 5. Token must have write permissions

# Update your config file and try again
veaf-tools-updater.exe publish 6.0.1 ./published.zip --verbose
```

### Problème : « Not a git repository »

**Cause :** la commande est lancée depuis le mauvais répertoire ou le dossier `.git` est absent.

**Solution :**
```bash
# Publish command runs from repo root (has .git/)
cd D:\dev\_VEAF\VEAF-Mission-Creation-Tools

# Then run publish
veaf-tools-updater.exe publish 6.0.1 ./published.zip --token ghp_xxx

# Or specify repo path
veaf-tools-updater.exe publish 6.0.1 ./published.zip \
  --token ghp_xxx \
  --repo-path "D:\dev\_VEAF\VEAF-Mission-Creation-Tools"
```

### Problème : « No release found for tag »

**Cause :** le tag de version existe mais aucune Release GitHub n'a été créée pour lui.

**Solution :**
```bash
# The publish command should create the release automatically

# If it didn't:
# 1. Visit https://github.com/VEAF/VEAF-Mission-Creation-Tools/releases
# 2. Find the tag in "Releases" list
# 3. Click "Edit" and re-publish

# Or use publish again (it will detect existing tag)
veaf-tools-updater.exe publish 6.0.1 ./published.zip --token ghp_xxx
```

### Obtenir plus d'aide

Pour des informations de débogage détaillées :

```bash
# Show verbose output
veaf-tools-updater.exe --verbose

# Or for publish
veaf-tools-updater.exe publish 6.0.1 ./published.zip --token ghp_xxx --verbose
```

Consultez le fichier `veaf-tools.log` dans le répertoire courant pour les journaux détaillés.

---

## Référence des commandes

### Commande de mise à jour

```bash
veaf-tools-updater.exe [MISSION_FOLDER] [OPTIONS]

Arguments:
  MISSION_FOLDER                 Mission folder path (default: current directory)

Options:
  --tag TEXT                     Version tag to fetch (default: published-latest)
  --token TEXT                   GitHub token (optional, overrides config file)
  --force                        Ignore version check, install anyway
  --no-verify-checksum           Skip checksum verification (not recommended)
  --lang TEXT                    Force interface language (en, fr); overrides OS locale and ~/veafmct.yaml
  --verbose                      Show detailed debug output
  --pause                        Wait for user input before exiting
  --help                         Show help message
```

**Note :** les réglages de `veaf-tools-config.yaml` sont utilisés automatiquement. Les options en ligne de commande priment sur les valeurs du fichier de configuration.

**Exemples :**
```bash
veaf-tools-updater.exe
veaf-tools-updater.exe --tag published-v6.0.0
veaf-tools-updater.exe --token ghp_xxx --verbose
veaf-tools-updater.exe --force
```

### Commande de publication

```bash
veaf-tools-updater.exe publish VERSION ZIP_FILE [OPTIONS]

Required:
  VERSION                        Version number (6.0.1 or v6.0.1)
  ZIP_FILE                       Path to published.zip

Options:
  --token TEXT                   GitHub token (optional, overrides config file)
  --repo-path TEXT               Repository path (default: current directory)
  --release-notes TEXT           Release notes/changelog
  --draft                        Create as draft (not visible to users)
  --prerelease                   Mark as pre-release
  --skip-tag                     Skip Git tag creation
  --verbose                      Show detailed debug output
  --pause                        Wait for user input before exiting
  --help                         Show help message
```

**Note :** le token et les autres réglages de `veaf-tools-config.yaml` sont utilisés automatiquement. Les options en ligne de commande priment sur les valeurs du fichier de configuration.

**Exemples :**
```bash
# With config file (recommended)
veaf-tools-updater.exe publish 6.0.1 ./published.zip
veaf-tools-updater.exe publish 6.0.1 ./published.zip --release-notes "Version 6.0.1 - Bug fixes"
veaf-tools-updater.exe publish 6.0.1 ./published.zip --draft

# Without config file (token required)
veaf-tools-updater.exe publish 6.0.1 ./published.zip --token ghp_xxx
veaf-tools-updater.exe publish 6.0.1 ./published.zip --token ghp_xxx --release-notes "..."
```

---

## Bonnes pratiques

### Pour les utilisateurs

✅ **À faire :**
- Lancez `veaf-tools update` régulièrement pour rester à jour
- Laissez les checksums vérifier l'intégrité (n'utilisez pas `--no-verify-checksum`)
- Utilisez `--help` en cas de doute sur une option

❌ **À éviter :**
- Ignorer la vérification de checksum
- Modifier manuellement `veaf-tools-updater.exe` ou les scripts de build
- Utiliser d'anciennes versions sans raison valable
- Partager vos Personal Access Tokens (un token = un mot de passe)

### Pour les administrateurs

✅ **À faire :**
- Stockez votre token dans `veaf-tools-config.yaml` (jamais dans git !)
- Utilisez toujours la commande `publish` pour rester cohérent
- Tenez les notes de version à jour
- Testez avant de publier en production
- Utilisez des tokens différents pour des machines différentes
- Régénérez les tokens régulièrement
- Conservez `veaf-tools-config.yaml` dans `.gitignore`

❌ **À éviter :**
- Committer `veaf-tools-config.yaml` dans git
- Committer des Personal Access Tokens où que ce soit
- Partager vos tokens avec d'autres personnes
- Publier des versions non testées
- Réutiliser un même token sur plusieurs machines
- Sauter le processus de vérification

---

## Sécurité

### Sûreté du token

Votre Personal Access Token GitHub est comme un mot de passe :
- ❌ Ne le committez jamais dans git (même dans des fichiers de configuration)
- ❌ Ne le partagez jamais par e-mail ou message
- ❌ Ne le collez jamais sur des forums publics
- ❌ Ne poussez jamais `veaf-tools-config.yaml` dans git
- ✅ Stockez-le dans `veaf-tools-config.yaml` (local uniquement)
- ✅ Assurez-vous que `veaf-tools-config.yaml` figure dans `.gitignore`
- ✅ Régénérez-le régulièrement (chaque mois)
- ✅ Utilisez-le pour une tâche, puis révoquez-le (lorsque c'est possible)

### Vérification par checksum

Les checksums protègent les téléchargements :
- ✅ Détectent la corruption réseau
- ✅ Vérifient que les fichiers n'ont pas été modifiés
- ✅ Préviennent les attaques de l'homme du milieu (man-in-the-middle)
- ✅ Activés par défaut (gardez-les ainsi !)

### HTTPS

Toutes les communications avec GitHub utilisent le chiffrement TLS/SSL :
- ✅ Les données en transit sont protégées
- ✅ L'API GitHub impose HTTPS
- ✅ Votre token est chiffré sur le réseau

---

## FAQ

**Q : Puis-je revenir à une ancienne version ?**
R : Oui ! `veaf-tools update --tag published-v6.0.0`

**Q : Que faire si la publication échoue ?**
R : Consultez la section Dépannage ci-dessus. La plupart des problèmes sont liés au réseau ou au token.

**Q : Ai-je besoin du token pour mettre à jour ?**
R : Non, le token ne sert qu'à publier. La mise à jour fonctionne sans lui (avec des limites de débit).

**Q : À quelle fréquence dois-je publier de nouvelles versions ?**
R : Aussi souvent que vous avez des changements. Les utilisateurs ne les verront que si vous le leur annoncez.

**Q : Puis-je supprimer ou annuler une version publiée ?**
R : Sur GitHub, oui. Mais les utilisateurs l'ont peut-être déjà téléchargée.

**Q : Quelle est la différence entre `--draft` et `--prerelease` ?**
R : Draft = caché, Prerelease = visible mais marqué comme « non final ».

**Q : Puis-je publier sans créer de tag git ?**
R : Oui, avec `--skip-tag`, mais ce n'est pas recommandé.

**Q : Combien de temps les tokens durent-ils ?**
R : Tant que vous ne les révoquez pas. Ils n'expirent pas automatiquement.

**Q : Le checksum est-il obligatoire ?**
R : Non (on peut l'ignorer avec `--no-verify-checksum`), mais il est fortement recommandé.

---

## Obtenir de l'aide

Si vous rencontrez des problèmes :

1. **Consultez la section Dépannage** ci-dessus
2. **Lancez avec `--verbose`** pour voir la sortie détaillée
3. **Vérifiez `veaf-tools.log`** dans le répertoire courant
4. **Visitez la page des releases GitHub** pour confirmer que la release existe
5. **Vérifiez votre connexion Internet** (la plupart des problèmes sont réseau)
6. **Vérifiez les permissions du token** sur https://github.com/settings/tokens

---

## Historique des versions

### Actuelle (6.0.1+)
- ✅ Outil unifié de mise à jour / publication
- ✅ Versionnement basé sur les tags Git
- ✅ Vérification par checksum SHA256
- ✅ Comparaison sémantique des versions
- ✅ Publication entièrement automatisée

### Précédente
- Script de mise à jour basique
- Versionnement basé sur les releases
- Publication manuelle
- Documentation limitée

---

**Bonnes publications !** 🚀

Pour plus de détails techniques, consultez le code source ou le dépôt GitHub.

---

## Détection de la langue

`veaf-tools.exe` et `veaf-tools-updater.exe` affichent leurs messages dans la langue du système automatiquement — aucune configuration requise. L'ordre de détection est :

1. Option CLI `--lang`
2. Variable d'environnement `VEAF_LANG`
3. `~/veafmct.yaml` → clé `lang:`
4. Locale du système (registre Windows / locale système sur Linux–macOS)
5. `en` (repli intégré)

Langues supportées : anglais (`en`), français (`fr`). Voir [Configuration de la langue](mission-maker/GUIDE.md#configuration-globale-utilisateur) pour les détails complets.
