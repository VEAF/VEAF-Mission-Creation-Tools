# Référence CLI — `veaf-tools`

Les **25 commandes** de `veaf-tools`, avec leurs arguments et **toutes** leurs options. C'est une
page de référence : elle dit ce que chaque commande accepte, pas comment mener une mission de bout
en bout. Pour cela, lisez le [guide du créateur de mission](mission-maker/GUIDE.md), qui raconte
l'enchaînement, et la [référence du pipeline](PIPELINE_REFERENCE.md), qui détaille chaque étape du
build.

Les outils qui ne sont **pas** `veaf-tools` — `veaf-tools-updater` pour la mise à jour et
`veaf-build` pour la publication — vivent dans [TOOLS_REFERENCE](TOOLS_REFERENCE.md).

## Comment lire cette page {#how-to-read}

**Les commandes sont groupées par thème** depuis la version 6.13 : `veaf-tools convert v5` plutôt
que `veaf-tools convert-v5`. L'ancienne forme plate reste enregistrée et fonctionne toujours — vos
scripts et vos raccourcis n'ont rien à changer — elle est simplement masquée de `--help`. Chaque
commande indique son alias plat sous son tableau.

Trois choses valent pour **toutes** les commandes :

- **`--lang fr` / `--lang en`** est une option globale, à placer avant la commande :
  `veaf-tools --lang en mission build`. Elle change la langue des messages *et* de l'aide.
- **Tout drapeau booléen a sa forme négative automatique.** `--dev-mode` s'annule avec
  `--no-dev-mode` ; les tableaux ci-dessous ne listent que la forme positive.
- **Une commande appelée sans une option obligatoire ouvre l'assistant interactif** au lieu
  d'échouer, pré-rempli avec ce que vous avez déjà tapé. `--tui` le force, une invocation nue
  aussi.

Enfin, `--verbose`, `--pause` et `--readme` reviennent sur la plupart des commandes et y ont
partout le même sens : afficher le détail de débogage, attendre une touche avant de quitter,
afficher le README de la commande. Elles sont malgré tout listées commande par commande, parce
qu'une référence incomplète oblige à aller vérifier ailleurs.

## Ce que cette page garantit {#coverage}

Les tableaux d'options sont **énumérés depuis les signatures du code**, pas recopiés à la main, et
le contrôle documentaire de la CI refuse une option qui n'apparaîtrait pas ici. C'est ce qui a
manqué à `capture-map --parking`, livrée sans une ligne de documentation avec une CI verte.

---

## Missions — `veaf-tools mission`

### `veaf-tools mission build` {#build}

Construit un fichier mission DCS (.miz) depuis un dossier de mission VEAF.

| Nom | Type | Obligatoire | Description |
|---|---|---|---|
| `MISSION_NAME_OR_FILE` | `str` | non | Nom de mission ; construira la mission avec ce nom et la date du jour ; peut être un fichier .miz. Défaut `mission.miz`. |
| `MISSION_FOLDER` | `str` | non | Dossier contenant les fichiers de mission. Défaut `.`. |

| Options | Type | Défaut | Description |
|---|---|---|---|
| `--readme` | `boolean` | `false` | Affiche le fichier README associé à cette commande. |
| `--verbose` | `boolean` | `false` | Si activé, affiche des informations de débogage détaillées. |
| `--no-veaf-triggers` | `boolean` | `false` | Si activé, les triggers VEAF ne seront pas injectés dans la mission résultante. |
| `--dynamic-mode` | `boolean` | *(aucun)* | Si activé, la mission chargera les scripts dynamiquement depuis l'emplacement fourni (via --scripts-path ou les dossiers locaux published et src/scripts). |
| `--dev-mode` | `boolean` | *(aucun)* | Résout les scripts VEAF depuis un dépôt de développement local (build/veaf-scripts.lua) au lieu de published/. Nécessite --scripts-path pointant vers la racine du dépôt VEAF-Mission-Creation-Tools. Ce paramètre est persisté dans mission.yaml (build.dev_mode). |
| `--scripts-path` | `str` | *(aucun)* | Chemin vers les scripts VEAF et communautaires. Persisté dans mission.yaml (build.scripts_path). |
| `--profile` / `-p` | `str` | *(aucun)* | Applique un profil de build nommé depuis mission.yaml (ex : TEST ou SERVER). Les clés du profil fusionnent en profondeur sur la config de base. |
| `--migrate-from-v5` | `boolean` | `true` | Si activé, le builder analysera la mission pour supprimer les anciens triggers v5. |
| `--log-modules` | `str` | *(aucun)* | Liste de modules séparés par des virgules à conserver au niveau de log complet. Tous les autres modules sont réduits au niveau 'error'. Exemple : --log-modules 'SPAWN,RADIO' |
| `--pause` | `boolean` | `false` | Si activé, le script attend que l'utilisateur appuie sur une touche avant de quitter. |

```bash
veaf-tools mission build MaMission --profile PROD
```

*Alias plat : `veaf-tools build`*

**Voir aussi** : [PIPELINE_REFERENCE.md](PIPELINE_REFERENCE.md)

### `veaf-tools mission export` {#export}

Exporte une mission .miz ou un dossier de mission en JSON/YAML/Markdown (analyse pure-Python, n'exécute jamais de Lua).

| Nom | Type | Obligatoire | Description |
|---|---|---|---|
| `MISSION_NAME_OR_FILE` | `str` | non | Le fichier .miz ou le dossier de mission extrait à exporter. Défaut `mission.miz`. |
| `OUTPUT` | `str` | non | Fichier de sortie ; écrit sur la sortie standard si omis. |

| Options | Type | Défaut | Description |
|---|---|---|---|
| `--format` / `-f` | `str` | `json` | Format de sortie : json (défaut), yaml ou markdown. |
| `--compact` | `boolean` | `false` | Pour JSON, émettre sans indentation. |
| `--extract-dir` | `str` | *(aucun)* | Quand l'entrée est un .miz, extraire ses ressources embarquées (scripts, sons/images l10n) dans ce dossier. |
| `--verbose` | `boolean` | `false` | Si activé, affiche des informations de débogage détaillées. |
| `--pause` | `boolean` | `false` | Si activé, le script attend que l'utilisateur appuie sur une touche avant de quitter. |

```bash
veaf-tools mission export MaMission.miz --format yaml --output mission.yaml
```

*Alias plat : `veaf-tools export`*

**Voir aussi** : [developer/export-json-contract.md](developer/export-json-contract.md)

### `veaf-tools mission extract` {#extract}

Extrait un fichier de mission .miz dans un dossier.

| Nom | Type | Obligatoire | Description |
|---|---|---|---|
| `MISSION_NAME_OR_FILE` | `str` | non | Nom de mission ; extraira depuis la mission portant ce nom (fichier .miz le plus récent) ; peut être un fichier .miz. Défaut `mission.miz`. |
| `MISSION_FOLDER` | `str` | non | Dossier où les fichiers de mission seront extraits. Défaut `.`. |

| Options | Type | Défaut | Description |
|---|---|---|---|
| `--readme` | `boolean` | `false` | Affiche le fichier README associé à cette commande. |
| `--verbose` | `boolean` | `false` | Si activé, affiche des informations de débogage détaillées. |
| `--pause` | `boolean` | `false` | Si activé, le script attend que l'utilisateur appuie sur une touche avant de quitter. |

```bash
veaf-tools mission extract MaMission.miz ./src/mission
```

*Alias plat : `veaf-tools extract`*

### `veaf-tools mission prepare` {#prepare}

Initialise un dossier de mission VEAF avec les modèles par défaut.

| Nom | Type | Obligatoire | Description |
|---|---|---|---|
| `MISSION_FOLDER` | `str` | non | Dossier à initialiser comme dossier de mission VEAF. Défaut `.`. |

| Options | Type | Défaut | Description |
|---|---|---|---|
| `--template` / `-t` | `str` | *(aucun)* | Preset de modules pour le mission.yaml généré : minimal | standard | full | custom (custom = choix interactif). Omettre pour garder le défaut livré. |
| `--list-templates` | `boolean` | `false` | Liste les templates disponibles et quitte. |
| `--theatre` | `str` | *(aucun)* | Génère une mission vierge synthétique pour ce théâtre DCS dans src/mission (sans passer par DCS). Omettre pour laisser src/mission vide. |
| `--list-theatres` | `boolean` | `false` | Liste les théâtres pour lesquels une mission vierge peut être générée, puis quitte. |
| `--readme` | `boolean` | `false` | Affiche le fichier README associé à cette commande. |
| `--verbose` | `boolean` | `false` | Si activé, affiche des informations de débogage détaillées. |
| `--force` | `boolean` | `false` | Ne pas demander de confirmation avant de remplacer les fichiers existants (équivalent à appuyer sur A). |

```bash
veaf-tools mission prepare MaMission --template
```

*Alias plat : `veaf-tools prepare`*

**Voir aussi** : [mission-maker/GUIDE.md](mission-maker/GUIDE.md)

### `veaf-tools mission validate` {#validate}

Valide un dossier de mission avant le build : signale les problèmes de config et de runtime, sort en erreur si besoin.

| Nom | Type | Obligatoire | Description |
|---|---|---|---|
| `MISSION_FOLDER` | `str` | non | Dossier contenant les fichiers de mission à valider. Défaut `.`. |

| Options | Type | Défaut | Description |
|---|---|---|---|
| `--strict` | `boolean` | `false` | Traiter les avertissements comme des erreurs (sortie non nulle si au moins un avertissement). |
| `--verbose` | `boolean` | `false` | Si activé, affiche des informations de débogage détaillées. |
| `--pause` | `boolean` | `false` | Si activé, le script attend que l'utilisateur appuie sur une touche avant de quitter. |

```bash
veaf-tools mission validate .
```

*Alias plat : `veaf-tools validate`*

**Voir aussi** : [mission-maker/GUIDE.md](mission-maker/GUIDE.md)

## Conversion — `veaf-tools convert`

### `veaf-tools convert generate-config` {#generate-config}

Génère un modèle mission.yaml documenté pour un dossier de mission.

| Options | Type | Défaut | Description |
|---|---|---|---|
| `--output` | `str` | `.` | Dossier de sortie pour le modèle mission.yaml généré. |
| `--verbose` | `boolean` | `false` | Si activé, affiche des informations de débogage détaillées. |
| `--pause` | `boolean` | `false` | Si activé, le script attend que l'utilisateur appuie sur une touche avant de quitter. |

```bash
veaf-tools convert generate-config
```

*Alias plat : `veaf-tools generate-config`*

**Voir aussi** : [MISSION_YAML_REFERENCE.md](MISSION_YAML_REFERENCE.md)

### `veaf-tools convert migrate-config` {#migrate-config}

Migre un fichier missionConfig.lua au format v6 (mission-script.lua).

| Nom | Type | Obligatoire | Description |
|---|---|---|---|
| `INPUT_FILE` | `str` | oui | Chemin vers le fichier missionConfig.lua à migrer (v5 → v6). |

| Options | Type | Défaut | Description |
|---|---|---|---|
| `--output` | `str` | *(aucun)* | Chemin du fichier migré. Par défaut : <entrée>_v6.lua à côté du fichier source. |
| `--yaml-output` | `str` | *(aucun)* | Écrire le fragment YAML lua_modules dans ce fichier plutôt que de l'afficher. |
| `--verbose` | `boolean` | `false` | Si activé, affiche des informations de débogage détaillées. |
| `--pause` | `boolean` | `false` | Si activé, le script attend que l'utilisateur appuie sur une touche avant de quitter. |

```bash
veaf-tools convert migrate-config ./src
```

*Alias plat : `veaf-tools migrate-config`*

**Voir aussi** : [mission-maker/MIGRATION_GUIDE.md](mission-maker/MIGRATION_GUIDE.md)

### `veaf-tools convert other` {#convert-other}

Adopte une mission .miz tierce (non-VEAF) sur la chaîne d'outils v6.

| Nom | Type | Obligatoire | Description |
|---|---|---|---|
| `INPUT_MIZ` | `str` | non | Chemin de la mission tierce à adopter : un .miz, ou une archive .zip de release en contenant exactement un (le reste de l'archive est ignoré). Défaut `mission.miz`. |
| `OUTPUT_FOLDER` | `str` | non | Dossier de mission de sortie à créer ou compléter. Défaut `.`. |

| Options | Type | Défaut | Description |
|---|---|---|---|
| `--force` | `boolean` | `false` | Écraser un mission.yaml existant sans demander. |
| `--report-file` | `str` | *(aucun)* | Enregistrer le rapport de conversion dans un fichier Markdown. Par défaut <output_folder>/convert-other-report.md. |
| `--profile` | `str` | *(aucun)* | Profil de conversion adaptant le scaffold (nom fourni, p. ex. « foothold », ou chemin vers un profil .yaml). Sans lui, un scaffold générique « minimal » est produit. |
| `--update` | `boolean` | `false` | Ré-importer un .miz upstream plus récent dans un dossier déjà adopté : rafraîchit les scripts tiers et la base de mission, préserve le mission.yaml réglé, et rapporte les scripts ajoutés/retirés/mis à jour en amont. |
| `--verbose` | `boolean` | `false` | Si activé, affiche des informations de débogage détaillées. |
| `--pause` | `boolean` | `false` | Si activé, le script attend que l'utilisateur appuie sur une touche avant de quitter. |

```bash
veaf-tools convert other Foothold.miz ./foothold
```

*Alias plat : `veaf-tools convert-other`*

**Voir aussi** : [mission-maker/CONVERT_OTHER.md](mission-maker/CONVERT_OTHER.md)

### `veaf-tools convert v5` {#convert-v5}

Convertit un dossier de mission VEAF v5 au format v6.

| Nom | Type | Obligatoire | Description |
|---|---|---|---|
| `MISSION_FOLDER` | `str` | non | Chemin vers le dossier de mission VEAF à convertir (là où mission.yaml sera créé). Défaut `.`. |

| Options | Type | Défaut | Description |
|---|---|---|---|
| `--force` | `boolean` | `false` | Écrase le fichier mission.yaml existant sans confirmation. |
| `--no-backup` | `boolean` | `false` | Ne crée pas de copie .bak de missionConfig.lua avant la migration. |
| `--no-convert-pipeline` | `boolean` | `false` | Ignore la conversion automatique des fichiers de configuration pipeline v5 (préréglages, waypoints, météo, groupes aériens). Ces fichiers seront listés comme nécessitant une conversion manuelle. |
| `--no-promote` | `boolean` | `false` | Ne pas promouvoir src/mission/ en v6 (ignorer le build de base + extraction). |
| `--report-file` | `str` | *(aucun)* | Enregistre le rapport de conversion dans un fichier Markdown. Par défaut : <dossier_mission>/convert-v5-report.md. |
| `--icao` | `str` | `` | Code ICAO de l'aérodrome pour les étapes real-weather du pipeline (ex. UGGG). Évite la saisie interactive. |
| `--verbose` | `boolean` | `false` | Si activé, affiche des informations de débogage détaillées. |
| `--pause` | `boolean` | `false` | Si activé, le script attend que l'utilisateur appuie sur une touche avant de quitter. |

```bash
veaf-tools convert v5 . --icao UGKO
```

*Alias plat : `veaf-tools convert-v5`*

**Voir aussi** : [mission-maker/MIGRATION_GUIDE.md](mission-maker/MIGRATION_GUIDE.md)

## Contenu de mission — `veaf-tools content`

### `veaf-tools content extract-aircraft-groups` {#extract-aircraft-groups}

Extrait les modèles de groupes aériens d'une mission .miz vers un fichier YAML.

| Nom | Type | Obligatoire | Description |
|---|---|---|---|
| `MISSION_NAME_OR_FILE` | `str` | non | Nom de mission ; extraira depuis la mission portant ce nom (fichier .miz le plus récent) ; peut être un fichier .miz. Défaut `mission.miz`. |
| `MISSION_FOLDER` | `str` | non | Dossier contenant les fichiers de mission. Défaut `.`. |

| Options | Type | Défaut | Description |
|---|---|---|---|
| `--readme` | `boolean` | `false` | Affiche le fichier README associé à cette commande. |
| `--verbose` | `boolean` | `false` | Si activé, affiche des informations de débogage détaillées. |
| `--interactive` | `boolean` | `false` | Mode interactif : sélectionner les groupes à inclure. |
| `--kind` | `str` | `both` | Familles à extraire : 'both' (défaut), 'spawnable' ou 'dynamic-template'. |
| `--output-spawnables` | `str` | `src/spawnables.yaml` | Chemin de sortie des groupes avions spawnables (préfixe veafSpawn-). |
| `--output-dynamic-templates` | `str` | `src/dynamic-slot-templates.yaml` | Chemin de sortie des modèles de slot dynamique (dynSpawnTemplate=true). |
| `--group-name-pattern` | `str` | `.*` | Expression régulière pour filtrer les noms de groupes aériens. |
| `--only-airplanes` | `boolean` | `false` | Extraire uniquement les avions. |
| `--only-helicopters` | `boolean` | `false` | Extraire uniquement les hélicoptères. |
| `--lua-input` | `str` | *(aucun)* | Chemin vers un fichier Lua (ex. settings-templates.lua) à utiliser à la place du fichier .miz. |
| `--pause` | `boolean` | `false` | Si activé, le script attend que l'utilisateur appuie sur une touche avant de quitter. |

```bash
veaf-tools content extract-aircraft-groups MaMission.miz aircraft-templates.yaml
```

*Alias plat : `veaf-tools extract-aircraft-groups`*

**Voir aussi** : [PIPELINE_REFERENCE.md](PIPELINE_REFERENCE.md)

### `veaf-tools content inject-aircraft-groups` {#inject-aircraft-groups}

Injecte des modèles de groupes aériens depuis un fichier YAML dans une mission .miz.

| Nom | Type | Obligatoire | Description |
|---|---|---|---|
| `MISSION_NAME_OR_FILE` | `str` | non | Nom de mission ; injectera dans la mission portant ce nom (fichier .miz le plus récent) ; peut être un fichier .miz. Défaut `mission.miz`. |
| `OUTPUT_MISSION` | `str` | non | Fichier de mission de sortie ; par défaut identique au fichier d'entrée. |
| `MISSION_FOLDER` | `str` | non | Dossier contenant les fichiers de mission. Défaut `.`. |

| Options | Type | Défaut | Description |
|---|---|---|---|
| `--readme` | `boolean` | `false` | Affiche le fichier README associé à cette commande. |
| `--verbose` | `boolean` | `false` | Si activé, affiche des informations de débogage détaillées. |
| `--mode` | `str` | `add` | Mode d'injection : 'add' (ajouter de nouveaux groupes) ou 'replace' (remplacer les groupes existants). |
| `--template-file` | `str` | `src/spawnables.yaml` | Chemin vers le fichier YAML contenant les groupes aériens. |
| `--pause` | `boolean` | `false` | Si activé, le script attend que l'utilisateur appuie sur une touche avant de quitter. |

```bash
veaf-tools content inject-aircraft-groups MaMission.miz aircraft-templates.yaml out.miz
```

*Alias plat : `veaf-tools inject-aircraft-groups`*

**Voir aussi** : [PIPELINE_REFERENCE.md](PIPELINE_REFERENCE.md)

### `veaf-tools content inject-presets` {#inject-presets}

Injecte des préréglages radio depuis un fichier YAML dans une mission .miz.

| Nom | Type | Obligatoire | Description |
|---|---|---|---|
| `INPUT_MISSION_NAME_OR_FILE` | `str` | non | Nom de mission ; injectera dans la mission portant ce nom (fichier .miz le plus récent) ; peut être un fichier .miz. Défaut `mission.miz`. |
| `OUTPUT_MISSION` | `str` | non | Fichier de mission de sortie ; par défaut identique au fichier d'entrée. |

| Options | Type | Défaut | Description |
|---|---|---|---|
| `--readme` | `boolean` | `false` | Affiche le fichier README associé à cette commande. |
| `--verbose` | `boolean` | `false` | Si activé, affiche des informations de débogage détaillées. |
| `--presets-file` | `str` | `./src/presets.yaml` | Fichier de configuration contenant les préréglages radio. |
| `--validate-report` | `str` | *(aucun)* | Enregistre un rapport Markdown de validation des fréquences dans ce fichier (signale TOUS les types d'appareils, pas seulement les critiques DCS). |
| `--pause` | `boolean` | `false` | Si activé, le script attend que l'utilisateur appuie sur une touche avant de quitter. |

```bash
veaf-tools content inject-presets MaMission.miz ./src/presets.yaml
```

*Alias plat : `veaf-tools inject-presets`*

**Voir aussi** : [PIPELINE_REFERENCE.md](PIPELINE_REFERENCE.md)

### `veaf-tools content extract-waypoints` {#extract-waypoints}

Extrait les waypoints d'une mission .miz vers un fichier YAML.

| Nom | Type | Obligatoire | Description |
|---|---|---|---|
| `MISSION_NAME_OR_FILE` | `str` | non | Nom de mission ; extraira depuis la mission portant ce nom (fichier .miz le plus récent) ; peut être un fichier .miz. Défaut `mission.miz`. |
| `MISSION_FOLDER` | `str` | non | Dossier contenant les fichiers de mission. Défaut `.`. |

| Options | Type | Défaut | Description |
|---|---|---|---|
| `--readme` | `boolean` | `false` | Affiche le fichier README associé à cette commande. |
| `--verbose` | `boolean` | `false` | Si activé, affiche des informations de débogage détaillées. |
| `--interactive` | `boolean` | `false` | Mode interactif : sélectionner les groupes à extraire. |
| `--output-yaml` | `str` | `waypoints.yaml` | Chemin du fichier YAML de sortie. |
| `--group-name-pattern` | `str` | `.*` | Expression régulière pour filtrer les noms de waypoints/groupes. |
| `--only-airplanes` | `boolean` | `false` | Extraire uniquement les avions. |
| `--only-helicopters` | `boolean` | `false` | Extraire uniquement les hélicoptères. |
| `--lua-input` | `str` | *(aucun)* | Chemin vers un fichier Lua (ex. settings-waypoints.lua) à utiliser à la place du fichier .miz. |
| `--pause` | `boolean` | `false` | Si activé, le script attend que l'utilisateur appuie sur une touche avant de quitter. |

```bash
veaf-tools content extract-waypoints MaMission.miz waypoints.yaml
```

*Alias plat : `veaf-tools extract-waypoints`*

**Voir aussi** : [PIPELINE_REFERENCE.md](PIPELINE_REFERENCE.md)

### `veaf-tools content inject-waypoints` {#inject-waypoints}

Injecte des waypoints depuis un fichier YAML dans une mission .miz.

| Nom | Type | Obligatoire | Description |
|---|---|---|---|
| `MISSION_NAME_OR_FILE` | `str` | non | Nom de mission ; injectera dans la mission portant ce nom (fichier .miz le plus récent) ; peut être un fichier .miz. Défaut `mission.miz`. |
| `OUTPUT_MISSION` | `str` | non | Fichier de mission de sortie ; par défaut identique au fichier d'entrée. |
| `MISSION_FOLDER` | `str` | non | Dossier contenant les fichiers de mission. Défaut `.`. |

| Options | Type | Défaut | Description |
|---|---|---|---|
| `--readme` | `boolean` | `false` | Affiche le fichier README associé à cette commande. |
| `--verbose` | `boolean` | `false` | Si activé, affiche des informations de débogage détaillées. |
| `--waypoints-file` | `str` | `waypoints.yaml` | Chemin vers le fichier YAML contenant les définitions de waypoints. |
| `--pause` | `boolean` | `false` | Si activé, le script attend que l'utilisateur appuie sur une touche avant de quitter. |

```bash
veaf-tools content inject-waypoints MaMission.miz waypoints.yaml out.miz
```

*Alias plat : `veaf-tools inject-waypoints`*

**Voir aussi** : [PIPELINE_REFERENCE.md](PIPELINE_REFERENCE.md)

### `veaf-tools content inject-weather` {#inject-weather}

Injecte des variantes météo depuis une configuration YAML dans des missions .miz.

| Nom | Type | Obligatoire | Description |
|---|---|---|---|
| `MISSION_NAME_OR_FILE` | `str` | non | Nom de mission ou fichier .miz à utiliser comme base pour créer les variantes météo/horaires. Défaut `mission.miz`. |

| Options | Type | Défaut | Description |
|---|---|---|---|
| `--readme` | `boolean` | `false` | Affiche le fichier README associé à cette commande. |
| `--verbose` | `boolean` | `false` | Si activé, affiche des informations de débogage détaillées. |
| `--config-file` | `str` | `versions.yaml` | Chemin vers le fichier de configuration YAML (ou fichier Lua à convertir). |
| `--convert-lua` | `boolean` | `false` | Convertir la configuration Lua legacy en YAML et quitter. |
| `--pause` | `boolean` | `false` | Si activé, le script attend que l'utilisateur appuie sur une touche avant de quitter. |

```bash
veaf-tools content inject-weather MaMission
```

*Alias plat : `veaf-tools inject-weather`*

**Voir aussi** : [PIPELINE_REFERENCE.md](PIPELINE_REFERENCE.md)

## Cockpit — `veaf-tools cockpit`

### `veaf-tools cockpit explore-cockpit` {#explore-cockpit}

Explorer un cockpit : nommez un contrôle pour le voir, ou bougez-en un pour le faire nommer.

| Nom | Type | Obligatoire | Description |
|---|---|---|---|
| `AIRCRAFT` | `str` | oui | Type DCS de l'appareil dans lequel vous êtes, ex. F-14BU. |

| Options | Type | Défaut | Description |
|---|---|---|---|
| `--control` | `str` | *(aucun)* | Encadrer ce contrôle avant de surveiller, décrit en langage courant. |
| `--serve-url` | `str` | `http://127.0.0.1:8080` | URL de base de dcs-serve. |
| `--api-key` | `str` | *(aucun)* | Jeton Bearer superuser de dcs-serve. (variable d'environnement `DCS_BRIDGE_API_KEY`) |
| `--verbose` | `boolean` | `false` | Si activé, affiche des informations de débogage détaillées. |

```bash
veaf-tools cockpit explore-cockpit "main pwr"
```

*Alias plat : `veaf-tools explore-cockpit`*

**Voir aussi** : [mission-maker/scripts/veafAssist.md](mission-maker/scripts/veafAssist.md)

### `veaf-tools cockpit resolve-checklist` {#resolve-checklist}

Complète les champs techniques d'une checklist guidée écrite en langage courant.

| Nom | Type | Obligatoire | Description |
|---|---|---|---|
| `CHECKLIST_FILE` | `str` | oui | Le fichier YAML de checklist à résoudre, sur place. |

| Options | Type | Défaut | Description |
|---|---|---|---|
| `--dry-run` | `boolean` | `false` | Affiche ce qui serait écrit, sans toucher au fichier. |
| `--verbose` | `boolean` | `false` | Si activé, affiche des informations de débogage détaillées. |
| `--pause` | `boolean` | `false` | Si activé, le script attend que l'utilisateur appuie sur une touche avant de quitter. |

```bash
veaf-tools cockpit resolve-checklist checklists/f16c-start.yaml
```

*Alias plat : `veaf-tools resolve-checklist`*

**Voir aussi** : [mission-maker/scripts/veafAssist.md](mission-maker/scripts/veafAssist.md)

### `veaf-tools cockpit verify-checklist` {#verify-checklist}

Vérifie une checklist résolue dans un vrai cockpit (DCS doit tourner ici).

| Nom | Type | Obligatoire | Description |
|---|---|---|---|
| `CHECKLIST_FILE` | `str` | oui | Le fichier YAML de checklist à vérifier. |

| Options | Type | Défaut | Description |
|---|---|---|---|
| `--serve-url` | `str` | `http://127.0.0.1:8080` | URL de base de dcs-serve. |
| `--api-key` | `str` | *(aucun)* | Jeton Bearer superuser de dcs-serve. (variable d'environnement `DCS_BRIDGE_API_KEY`) |
| `--timeout` | `float` | `60.0` | Secondes d'attente du pilote à chaque étape. |
| `--write` | `boolean` | `false` | Marque les étapes confirmées `verified: true` dans le fichier. |
| `--verbose` | `boolean` | `false` | Si activé, affiche des informations de débogage détaillées. |
| `--pause` | `boolean` | `false` | Si activé, le script attend que l'utilisateur appuie sur une touche avant de quitter. |

```bash
veaf-tools cockpit verify-checklist checklists/f16c-start.yaml
```

*Alias plat : `veaf-tools verify-checklist`*

**Voir aussi** : [mission-maker/scripts/veafAssist.md](mission-maker/scripts/veafAssist.md)

## DCS en cours d'exécution — `veaf-tools dcs`

### `veaf-tools dcs capture-map` {#capture-map}

Capture les aérodromes d'un théâtre depuis une mission-pont en cours (via dcs-serve) dans <théâtre>.json.

| Options | Type | Défaut | Description |
|---|---|---|---|
| `--api-key` | `str` | *(aucun)* | Jeton Bearer superuser de dcs-serve (par défaut : lu dans dcs-serve.yaml). (variable d'environnement `DCS_BRIDGE_API_KEY`) |
| `--config` | `str` | *(aucun)* | Chemin d'un dcs-serve.yaml / dcs-client.yaml où lire la clé. |
| `--serve-url` | `str` | `http://127.0.0.1:8080` | URL de base de dcs-serve. |
| `--out-dir` | `str` | `.` | Dossier où écrire <théâtre>.json. |
| `--parking` | `boolean` | `false` | Capture aussi les emplacements de parking de chaque aérodrome dans parking/<théâtre>.json. |
| `--verbose` | `boolean` | `false` | Si activé, affiche des informations de débogage détaillées. |

```bash
veaf-tools dcs capture-map --parking
```

*Alias plat : `veaf-tools capture-map`*

**Voir aussi** : [developer/capture-airbases.md](developer/capture-airbases.md)

### `veaf-tools dcs inject-bridge` {#inject-bridge}

Injecte le dcs-bridge + un trigger de démarrage dans un .miz (mission-pont).

| Nom | Type | Obligatoire | Description |
|---|---|---|---|
| `MISSION` | `str` | oui | Chemin du .miz à transformer en mission-pont (modifié sur place). |

| Options | Type | Défaut | Description |
|---|---|---|---|
| `--bridge-lua` | `str` | *(aucun)* | dcs-bridge.lua local à embarquer (défaut : téléchargement). |
| `--verbose` | `boolean` | `false` | Si activé, affiche des informations de débogage détaillées. |

```bash
veaf-tools dcs inject-bridge MaMission.miz
```

*Alias plat : `veaf-tools inject-bridge`*

**Voir aussi** : [developer/dcs-data.md](developer/dcs-data.md)

### `veaf-tools dcs smoke-test` {#smoke-test}

Vérifie le comportement runtime VEAF dans un DCS en cours d'exécution, via le hook dcs-fiddle.

| Options | Type | Défaut | Description |
|---|---|---|---|
| `--url` | `str` | `http://127.0.0.1:12081` | URL de base du hook dcs-fiddle-server.lua (défaut : http://127.0.0.1:12081). |
| `--timeout` | `float` | `10.0` | Délai d'attente par requête, en secondes. |
| `--probe-only` | `boolean` | `false` | Rapporte seulement ce qu'un DCS en cours autorise, sans lancer de vérification. |
| `--full` | `boolean` | `false` | Lance DCS, charge --mission, vérifie, puis quitte — un run complet sans surveillance. |
| `--mission` | `str` | *(aucun)* | Chemin du .miz à charger pour un run --full. |
| `--dcs-exe` | `str` | *(aucun)* | Chemin de DCS.exe pour un run --full (défaut : déduit du dossier d'installation d'un DCS en cours). |
| `--allow-running` | `boolean` | `false` | Pour --full : utilise un DCS déjà lancé au lieu de refuser (il charge la mission par-dessus la session en cours). |
| `--fiddle-token` | `str` | *(aucun)* | Le mot de passe Basic par session du hook (défaut : lu dans ~/dcs-fiddle-token.txt, ou $DCS_FIDDLE_TOKEN). |
| `--verbose` | `boolean` | `false` | Si activé, affiche des informations de débogage détaillées. |

```bash
veaf-tools dcs smoke-test
```

*Alias plat : `veaf-tools smoke-test`*

**Voir aussi** : [developer/smoke-harness.md](developer/smoke-harness.md)

## L'outil lui-même

### `veaf-tools about` {#about}

Affiche les informations sur VEAF Mission Creation Tools.

| Options | Type | Défaut | Description |
|---|---|---|---|
| `--modules` | `boolean` | `false` | Affiche la liste des modules Lua VEAF embarqués. |

```bash
veaf-tools about
```

### `veaf-tools ask` {#ask}

Pose une question sur la documentation VEAF (assistant IA). Sans question, démarre une session interactive.

| Nom | Type | Obligatoire | Description |
|---|---|---|---|
| `QUESTION` | `str` | non | La question à poser. Omettez-la pour démarrer une session interactive. |

| Options | Type | Défaut | Description |
|---|---|---|---|
| `--verbose` | `boolean` | `false` | Si activé, affiche des informations de débogage détaillées. |

```bash
veaf-tools ask "comment activer une zone de combat au démarrage ?"
```

### `veaf-tools mcp` {#mcp}

Démarre le serveur MCP d'édition de mission assistée par LLM (stdio). Utilisé par le plugin Claude veaf-mission-editor.

```bash
veaf-tools mcp
```

**Voir aussi** : [developer/mission-editing-mcp.md](developer/mission-editing-mcp.md)

### `veaf-tools user-config` {#user-config}

Afficher et gérer la configuration utilisateur globale (~/veafmct.yaml).

| Options | Type | Défaut | Description |
|---|---|---|---|
| `--set` | `str` | *(aucun)* | Définir une clé de configuration (format : clé=valeur, ex. lang=fr). |
| `--unset` | `str` | *(aucun)* | Supprimer une clé de configuration. |
| `--init` | `boolean` | `false` | Créer un fichier ~/veafmct.yaml par défaut s'il n'existe pas. |
| `--verbose` | `boolean` | `false` | Si activé, affiche des informations de débogage détaillées. |
| `--pause` | `boolean` | `false` | Si activé, le script attend que l'utilisateur appuie sur une touche avant de quitter. |

```bash
veaf-tools user-config --show
```
