# VEAF Mission Creation Tools — 6.7.1

Version centrée sur une **migration v5→v6 plus sûre et plus propre** : `convert-v5` fait désormais le ménage des fichiers v5 résiduels, ses messages et ses liens de documentation sont fiabilisés, et la sortie console sous Windows ne tronque plus les réponses.

## ✨ Nouveautés

### `convert-v5` trie les fichiers v5 résiduels d'un dossier de mission

Une mission v5 traîne des fichiers que la chaîne v6 n'utilise plus, et `convert-v5` les ignorait. Il les trie maintenant en trois catégories :

- **Outillage v5 obsolète** (`*.cmd`/`*.ps1`, `package.json`, `package-lock.json`, `yarn.lock`, `configuration.json`, `7za.exe`) → **déplacé dans `backup_v5/`** (réversible). `configuration.json` est en plus signalé comme **porteur de secret** (son ancienne clé `checkwx_apikey` — non migrée, la v6 récupère la vraie météo sans clé d'API).
- **Artefacts régénérables** (`node_modules/`, `build/`, `cache/`, tous gitignorés) → **supprimés** et listés.
- **Fichiers non reconnus** → seulement **listés** dans une section `🧹 Legacy v5 files` pour relecture, **jamais touchés**.

Le scan ne touche jamais `.git/`, `backup_v5/`, `src/mission/`, les fichiers v6 générés ni les dotfiles, et il est idempotent.

## 🐛 Corrections

- **`veaf-tools ask` ne tronque plus sa réponse sous Windows, et l'affiche en direct** — la réponse était coupée en plein milieu : la console héritait du code page hérité (cp1252) et le premier caractère hors table (flèche `→`, cadre d'un bloc de code, emoji) faisait planter l'affichage. La sortie est désormais forcée en **UTF-8** au démarrage (ce qui corrige aussi les emojis/flèches des rapports `convert-v5`), et `ask` rend sa réponse **en streaming**.
- **`convert-v5` ne liste plus les exécutables `veaf-tools` comme « fichiers à supprimer »** — `veaf-tools.exe` / `veaf-tools-updater.exe` (l'outillage v6 lui-même) étaient signalés comme « non gérés, à supprimer ». Ils sont désormais ignorés par le triage.
- **Trois avertissements météo/waypoints de `convert-v5` étaient figés en anglais** — la notice météo réelle (ICAO `TODO`), l'avertissement « fichier météo introuvable » et celui des waypoints vides passent maintenant par la traduction (FR/EN).
- **Les liens `# Doc:` d'un `mission.yaml` généré résolvent enfin** — ils pointaient vers une ancre inexistante (slash final manquant + ancre anglaise sur la doc FR). Les titres de guide concernés ont désormais des **ancres stables FR/EN** et le générateur émet l'URL correcte (et adaptée à la langue).
- **Le rapport `convert-v5` n'embarque plus un « `missionConfig.lua` annoté » trompeur** — ce pseudo-fichier n'était jamais exécuté et donnait l'impression qu'un fichier était édité. Supprimé ; la migration reste tracée par les tables ligne→effet déjà présentes.
- **`--profile` est désormais insensible à la casse, et le faux avertissement « fichier orphelin » a disparu** — `--profile test` ne matchait pas un profil `TEST:` ; et un fichier utilisé par un autre profil était signalé orphelin à tort. Corrigé (le warning n'est levé que si l'étape est désactivée partout).
- **Plus de faux rappel « triggers v5 à migrer » sur une mission déjà promue en v6** — après promotion, chaque `build` affichait encore « 2 trigger(s) v5… lancez `convert-v5` ». La détection des triggers v5 vérifie maintenant aussi la **clé** du dictionnaire, plus seulement la valeur.
- **La notice ICAO vide ne ressemble plus à un échec** — quand on convertit une mission *realweather* sans `--icao`, la conversion **réussit** (avec un `TODO` dans `versions.yaml`) ; le message le dit clairement et propose d'abord le correctif le plus léger.

## 🛠️ Pour les contributeurs / développeurs de scripts

- **`audit-dcs-mocks`** — signale les appels à l'API DCS faits par le Lua VEAF mais non présents dans les mocks de test (avant qu'un test ne casse), à partir d'un schéma DCS vendoré. Job CI non bloquant.
- **`check-vendored` + veille de dérive** — un manifeste `vendored.yaml` recense tous les artefacts tiers vendorés (mist, CTLD, CSAR, AIEN, TUM, Skynet…) ; `check-vendored` compare chaque version épinglée à l'upstream et un workflow hebdomadaire ouvre une issue récap en cas de dérive. **Notification seulement.**
