# Publier les données de terrain

Les grilles d'altitude du sol que `veaf-tools dcs terrain-sweep` relève dans DCS servent à l'assistant IA (`terrain_elevation`, `describe_terrain`) et aux contrôles de placement, **sans DCS**.
Un PC sans DCS ouvert — une sandbox de démo, le poste d'un autre mission maker — n'en a pas : on publie donc celles relevées par la VEAF, et veaf-tools les télécharge.

## Comment veaf-tools s'en sert {#download}

- Les grilles sont les assets de la release GitHub [`terrain-data`](https://github.com/VEAF/VEAF-Mission-Creation-Tools/releases/tag/terrain-data), une par théâtre (`<Theatre>.terrain`), avec un manifeste `terrain-data.json` qui donne pour chacune sa taille et son SHA-256.
- Cette release est **à part** des releases des outils : les quelque 26 Mo ne sont pas republiés à chaque version, et elle est créée **non latest**, pour que la page des releases continue de mettre en avant les outils.
- Quand un théâtre n'a pas de grille dans `<VEAF home>/terrain/`, veaf-tools télécharge la sienne au premier usage, vérifie sa taille, son SHA-256 et qu'elle se charge bien comme la grille de ce théâtre, puis l'écrit à côté des grilles relevées.
- Une grille déjà présente — relevée sur le poste ou téléchargée avant — est utilisée telle quelle, jamais remplacée. Pour reprendre une grille republiée, on supprime le fichier.
- Hors ligne, ou si un contrôle échoue, la réponse reste celle d'avant : « relève-la dans DCS ». Un seul essai par processus, pour ne pas payer un délai d'attente à chaque placement ; la raison est écrite dans le journal de veaf-tools.
- Le téléchargement passe par les mêmes contrôles que l'updater (`veaf_libs/github_download.py`) : https sur un hôte GitHub seulement, chaque redirection vérifiée, taille plafonnée.

## Publier {#publish}

1. Relève le théâtre dans DCS : [`veaf-tools dcs terrain-sweep`](../CLI_REFERENCE.md#terrain-sweep).
2. Vérifie ce qui partirait, depuis la racine du dépôt :

   ```powershell
   poetry run veaf-build terrain-data
   ```

   La commande charge chaque `*.terrain` de `<VEAF home>/terrain/` (ou du dossier passé en argument), refuse un fichier dont la grille est celle d'un autre théâtre, écrit `dist/terrain-data.json` et liste les fichiers avec leur taille. Rien ne part.
3. Publie :

   ```powershell
   poetry run veaf-build terrain-data --publish
   ```

   Il faut `gh` connecté avec le droit d'écrire sur le dépôt.
   La release est créée si elle manque, puis les grilles sont téléversées (`--clobber`), et le manifeste en dernier, pour qu'il ne nomme jamais une grille pas encore là.

Le manifeste est remplacé à chaque publication : publie depuis un dossier qui contient toutes les grilles publiées, pas seulement la nouvelle.
La commande refuse sinon, en nommant les théâtres qu'elle retirerait.
