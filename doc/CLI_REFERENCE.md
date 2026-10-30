# Référence CLI — `veaf-tools`

Les **44 commandes** de `veaf-tools`, avec leurs arguments et **toutes** leurs options. C'est une
page de référence : elle dit ce que chaque commande accepte, pas comment mener une mission de bout
en bout. Pour cela, lisez le [guide du créateur de mission](mission-maker/GUIDE.md), qui raconte
l'enchaînement, et la [référence du pipeline](PIPELINE_REFERENCE.md), qui détaille chaque étape du
build.

Les outils qui ne sont **pas** `veaf-tools` — `veaf-tools-updater` pour la mise à jour et
`veaf-build` pour la publication — vivent dans [TOOLS_REFERENCE](TOOLS_REFERENCE.md).

## Comment lire cette page {#how-to-read}

**Les commandes sont groupées par thème** : `veaf-tools convert v5` plutôt
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

**Sans terminal, aucune commande ne pose de question.** Dans un job d'intégration continue, un
fichier de commandes ou une invocation dont la sortie est capturée, les confirmations sont sautées
et la commande va jusqu'au bout : `veaf-tools about` affiche ses informations et sort en `0` (elle
affichait `Aborted.` et sortait en `1`), `--readme` affiche bien le README, et une confirmation
d'écrasement répond « non » — passez `--force` quand vous voulez vraiment écraser.

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
| `--profile` / `-p` | `str` | *(aucun)* | Applique un profil de build nommé depuis mission.yaml (ex : TEST ou SERVER). Les clés du profil fusionnent en profondeur sur la config de base. Le `.miz` est suffixé du nom du profil (`_TEST`). |
| `--migrate-from-v5` | `boolean` | `true` | Si activé, le builder analysera la mission pour supprimer les anciens triggers v5. |
| `--log-modules` | `str` | *(aucun)* | Liste de modules séparés par des virgules à conserver au niveau de log complet. Tous les autres modules sont réduits au niveau 'error'. Exemple : --log-modules 'SPAWN,RADIO' |
| `--pause` | `boolean` | `false` | Si activé, le script attend que l'utilisateur appuie sur une touche avant de quitter. |

```bash
veaf-tools mission build MaMission --profile PROD
```

*Alias plat : `veaf-tools build`*

**Voir aussi** : [PIPELINE_REFERENCE.md](PIPELINE_REFERENCE.md)

### `veaf-tools mission ctld-upgrade` {#ctld-upgrade}

Met ctld-config.yaml au niveau du catalogue CTLD livré avec les outils : ajoute les réglages absents à leur valeur par défaut, ne change rien d'autre.

| Nom | Type | Obligatoire | Description |
|---|---|---|---|
| `MISSION_FOLDER` | `str` | non | Dossier contenant mission.yaml et ctld-config.yaml. Défaut `.`. |

| Options | Type | Défaut | Description |
|---|---|---|---|
| `--verbose` | `boolean` | `false` | Si activé, affiche des informations de débogage détaillées. |
| `--pause` | `boolean` | `false` | Si activé, le script attend que l'utilisateur appuie sur une touche avant de quitter. |

```bash
veaf-tools mission ctld-upgrade .
```

*Alias plat : `veaf-tools ctld-upgrade`*

**Voir aussi** : [mission-maker/build-messages/modules.md](mission-maker/build-messages/modules.md#validate-ctld-catalogue-gap)

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

### `veaf-tools mission password-hash` {#password-hash}

Transforme un mot de passe en hash SHA-1, la forme que `security.password_hashes` attend dans `mission.yaml`.
Elle demande le mot de passe deux fois, en saisie masquée, et n'affiche que le hash : le mot de passe n'est jamais affiché ni écrit.
Lancez-la vous-même, et donnez le hash, jamais le mot de passe, à un assistant IA qui écrit `mission.yaml`.
`password_hashes` reçoit le mot de passe SENIOR_PILOT (qui ouvre aussi KNOWN_PILOT), `password_mm_hashes` celui du Mission Master.
Ni argument, ni option.

```powershell
.\veaf-tools.exe mission password-hash
```

*Alias plat : `veaf-tools password-hash`*

**Voir aussi** : [veafSecurity](mission-maker/scripts/veafSecurity.md)

### `veaf-tools mission prepare` {#prepare}

Initialise un dossier de mission VEAF avec les modèles par défaut.

| Nom | Type | Obligatoire | Description |
|---|---|---|---|
| `MISSION_FOLDER` | `str` | non | Dossier à initialiser comme dossier de mission VEAF. Défaut `.`. |

| Options | Type | Défaut | Description |
|---|---|---|---|
| `--template` / `-t` | `str` | *(aucun)* | Preset de modules pour le mission.yaml généré : minimal | standard | full | custom (custom = choix interactif). Omettre pour garder le défaut livré. Sur un dossier où `mission.yaml` existe déjà, le template n'est appliqué que si vous acceptez de remplacer ce fichier (ou avec `--force`) : garder le vôtre le laisse intact, et la commande le signale. |
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
| `--merge` | `boolean` | `false` | Fusionner dans les fichiers de sortie au lieu de les remplacer : les groupes absents de la mission sont conservés, un groupe de même nom est remplacé par la version de la mission et nommé dans le compte rendu. |
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

### `veaf-tools content pull-aircraft-groups` {#pull-aircraft-groups}

Liste ce que le catalogue de groupes d'aéronefs livré avec veaf-tools contient et que votre dossier de mission n'a pas, et recopie les entrées que vous choisissez. Sans `--add` ni `--add-new`, la commande n'écrit rien : elle affiche seulement le compte rendu. **Une entrée que vous avez déjà n'est jamais remplacée**, même si la version livrée diffère ; elle est signalée comme conservée.

| Nom | Type | Obligatoire | Description |
|---|---|---|---|
| `MISSION_FOLDER` | `str` | non | Dossier contenant les fichiers de mission. Défaut `.`. |

| Options | Type | Défaut | Description |
|---|---|---|---|
| `--verbose` | `boolean` | `false` | Si activé, affiche des informations de débogage détaillées ; nomme aussi les entrées conservées au lieu de seulement les compter. |
| `--kind` | `str` | `both` | Catalogue à traiter : 'both' (défaut), 'spawnable' ou 'dynamic-template'. |
| `--add` | `str` | *(aucun)* | Nom d'un groupe à recopier depuis le catalogue livré. Répétable. Un nom absent du catalogue livré arrête la commande sans rien écrire. |
| `--add-new` | `boolean` | `false` | Recopie toutes les entrées que le catalogue livré a et que le vôtre n'a pas. |
| `--pause` | `boolean` | `false` | Si activé, le script attend que l'utilisateur appuie sur une touche avant de quitter. |

```bash
veaf-tools content pull-aircraft-groups
veaf-tools content pull-aircraft-groups --kind dynamic-template --add "F-14BU Template"
veaf-tools content pull-aircraft-groups --add-new
```

*Alias plat : `veaf-tools pull-aircraft-groups`*

**Voir aussi** : [Slots dynamiques](mission-maker/concepts/dynamic-slots.md#shipped-catalogue)

### `veaf-tools content airfield-channels` {#airfield-channels}

Liste les aérodromes qu'utilise la mission, du plus utile au moins utile, avec les fréquences ATC et le TACAN que DCS leur donne : le camp qui les tient (`warehouses`), s'ils offrent des slots dynamiques une fois `src/warehouses.yaml` appliqué, combien de slots sont posés au parking, et le canal qu'ils ont déjà dans la collection `bases`. Une radio DCS tient une vingtaine de canaux : c'est la liste dans laquelle choisir. Sans `--apply`, la commande n'écrit rien.

Avec `--apply`, elle écrit les aérodromes choisis dans la collection `bases` de `src/presets.yaml`, avec les fréquences de DCS. Un aérodrome qui y est déjà garde son alias (les `channel_lists` le nomment) et l'orthographe de son titre (`Büchel` reste `Büchel` même si DCS écrit `Buchel` ; seul l'indicatif TACAN est mis à jour) ; un nouveau prend l'alias `Base-<nom DCS>`. Une entrée qui ne correspond à aucun aérodrome choisi (un FARP, un navire) est laissée telle quelle et signalée. Rien d'autre ne change : ni les canaux tactiques et de patrouille, ni les `channel_lists`. La commande signale les canaux écrits qui ne sont encore sur aucune radio. Un aérodrome que DCS ne déclare pas est refusé : **une fréquence d'aérodrome ne se tape jamais à la main**.

| Nom | Type | Obligatoire | Description |
|---|---|---|---|
| `MISSION_FOLDER` | `str` | non | Dossier de mission (contient `src/mission/` et `src/presets.yaml`). Défaut `.`. |

| Options | Type | Défaut | Description |
|---|---|---|---|
| `--apply` | `str` | *(aucun)* | Aérodrome (nom DCS ou id) à écrire dans la collection `bases`, dans l'ordre voulu. Répétable. |
| `--neutral` | `boolean` | `false` | Liste aussi les aérodromes qu'aucun camp ne tient. |
| `--verbose` | `boolean` | `false` | Si activé, affiche des informations de débogage détaillées. |
| `--pause` | `boolean` | `false` | Si activé, le script attend que l'utilisateur appuie sur une touche avant de quitter. |

```bash
.\veaf-tools.exe content airfield-channels
.\veaf-tools.exe content airfield-channels --apply "Batumi" --apply "Kutaisi" --apply "Vaziani"
```

*Alias plat : `veaf-tools airfield-channels`*

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

## Campagne — `veaf-tools campaign`

Une [campagne multi-missions](mission-maker/CAMPAIGN.md) se mène avec ces quatre commandes, dans l'ordre `init`, puis `next` et `apply` à chaque mission.

### `veaf-tools campaign init` {#campaign-init}

Démarre une campagne : crée son état à partir de campaign.yaml.

| Nom | Type | Obligatoire | Description |
|---|---|---|---|
| `CAMPAIGN_FOLDER` | `str` | non | Dossier de campagne, qui contient campaign.yaml. Défaut `.`. |

| Options | Type | Défaut | Description |
|---|---|---|---|
| `--verbose` | `boolean` | `false` | Si activé, affiche des informations de débogage détaillées. |
| `--pause` | `boolean` | `false` | Si activé, le script attend que l'utilisateur appuie sur une touche avant de quitter. |

Un état existant n'est jamais écrasé : il porte les missions déjà jouées.

```powershell
.\veaf-tools.exe campaign init C:\Campagnes\Caucase
```

*Alias plat : `veaf-tools campaign-init`*

### `veaf-tools campaign validate` {#campaign-validate}

Vérifie un dossier de campagne : campaign.yaml, et l'état de campagne par rapport à lui.

| Nom | Type | Obligatoire | Description |
|---|---|---|---|
| `CAMPAIGN_FOLDER` | `str` | non | Dossier de campagne, qui contient campaign.yaml. Défaut `.`. |

| Options | Type | Défaut | Description |
|---|---|---|---|
| `--verbose` | `boolean` | `false` | Si activé, affiche des informations de débogage détaillées. |
| `--pause` | `boolean` | `false` | Si activé, le script attend que l'utilisateur appuie sur une touche avant de quitter. |

```powershell
.\veaf-tools.exe campaign validate C:\Campagnes\Caucase
```

*Alias plat : `veaf-tools campaign-validate`*

### `veaf-tools campaign apply` {#campaign-apply}

Applique à la campagne le fichier d'état d'une mission jouée, puis joue le tour entre les missions.

| Nom | Type | Obligatoire | Description |
|---|---|---|---|
| `STATE_FILE` | `str` | oui | Le fichier d'état écrit par la mission (Saved Games/DCS/Missions/Saves/<campagne>/mission-NN.state). |
| `CAMPAIGN_FOLDER` | `str` | non | Dossier de campagne, qui contient campaign.yaml. Défaut `.`. |

| Options | Type | Défaut | Description |
|---|---|---|---|
| `--verbose` | `boolean` | `false` | Si activé, affiche des informations de débogage détaillées. |
| `--pause` | `boolean` | `false` | Si activé, le script attend que l'utilisateur appuie sur une touche avant de quitter. |

Refuse un fichier déjà appliqué, celui d'une autre campagne ou celui qui saute une mission ; rien n'est écrit dans ce cas.

```powershell
.\veaf-tools.exe campaign apply mission-01.state C:\Campagnes\Caucase
```

*Alias plat : `veaf-tools campaign-apply`*

### `veaf-tools campaign next` {#campaign-next}

Crée, ou rafraîchit, le dossier de la mission suivante à partir de l'état de la campagne.

| Nom | Type | Obligatoire | Description |
|---|---|---|---|
| `CAMPAIGN_FOLDER` | `str` | non | Dossier de campagne, qui contient campaign.yaml. Défaut `.`. |

| Options | Type | Défaut | Description |
|---|---|---|---|
| `--players` | `str` | — | Combien de joueurs sont attendus ce soir : un nombre (`6`) ou une fourchette (`5-7`). Dimensionne l'opposition aérienne de la mission ([bloc `opposition:`](mission-maker/scripts/veafQraManager.md#opposition-level)), et prime sur le `players` de `campaign.yaml`. |
| `--verbose` | `boolean` | `false` | Si activé, affiche des informations de débogage détaillées. |
| `--pause` | `boolean` | `false` | Si activé, le script attend que l'utilisateur appuie sur une touche avant de quitter. |

Le dossier est copié depuis `template/` la première fois, et seulement rafraîchi ensuite : ce qui y a été conçu survit.

```powershell
.\veaf-tools.exe campaign next C:\Campagnes\Caucase
```

*Alias plat : `veaf-tools campaign-next`*

### `veaf-tools campaign briefing` {#campaign-briefing}

Écrit le document de briefing stratégique de la prochaine mission (PPTX), à partir de la campagne et de son briefing.yaml.

| Nom | Type | Obligatoire | Description |
|---|---|---|---|
| `CAMPAIGN_FOLDER` | `str` | non | Dossier de campagne, qui contient campaign.yaml. Défaut `.`. |

| Options | Type | Défaut | Description |
|---|---|---|---|
| `--verbose` | `boolean` | `false` | Si activé, affiche des informations de débogage détaillées. |
| `--pause` | `boolean` | `false` | Si activé, le script attend que l'utilisateur appuie sur une touche avant de quitter. |

Écrit `missions/mission-NN/briefing-campagne.pptx` et sa carte ; `campaign next` le fait aussi. La prose vient de `briefing.yaml`, les faits de la campagne.

```powershell
.\veaf-tools.exe campaign briefing C:\Campagnes\Caucase
```

*Alias plat : `veaf-tools campaign-briefing`*

**Voir aussi** : [mission-maker/CAMPAIGN.md](mission-maker/CAMPAIGN.md)

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

### `veaf-tools dcs clear-ground-sweep` {#clear-ground-sweep}

Sonde le terrain dégagé d'un théâtre, pas à pas, et écrit son catalogue. La commande :

1. écrit une mission d'arpentage **vide** dans le dossier `Missions` de votre DCS. Elle doit rester vide :
   la sonde de DCS compte les véhicules comme des obstacles, et une unité posée sur la carte serait
   prise pour de la forêt ;
2. s'assure que `dcs-serve` tourne : c'est le petit serveur local auquel le script dcs-bridge de la mission
   se connecte, et par lequel passe le balayage. S'il ne répond pas, la commande le lance elle-même (trouvé
   à côté de `veaf-tools.exe`, dans le `PATH`, ou via `--dcs-serve`), dans un dossier à elle, avec une clé
   d'accès générée et une écoute limitée à cet ordinateur, et l'arrête à la fin ;
3. affiche quoi faire : autoriser une fois les scripts de mission à communiquer (`MissionScripting.lua`),
   ouvrir et lancer la mission, prendre le slot spectateur ;
4. attend que vous appuyiez sur Entrée, puis que la mission réponde ;
5. sonde le terrain autour des aérodromes (et, sur demande, des combat zones d'une mission ou de
   points donnés) en affichant la progression. Un balayage interrompu reprend là où il s'était arrêté ;
6. écrit le catalogue et indique que DCS peut être fermé.

Les 21 aérodromes du Caucase prennent environ 4 minutes, une combat zone une dizaine de secondes. DCS
gèle environ 1,5 s à chaque lot, sans conséquence sur une mission que personne ne pilote.

| Nom | Type | Obligatoire | Description |
|---|---|---|---|
| `THEATRE` | `str` | oui | Nom du théâtre DCS, tel qu'une mission l'écrit. |

| Options | Type | Défaut | Description |
|---|---|---|---|
| `--zones-from` | `str` | *(aucun)* | Sonder aussi autour des zones de déclenchement `combatZone...` de ce .miz. |
| `--around` | `str` | *(aucun)* | Sonder aussi autour de ce point, en coordonnées de mission `x,y` (répétable). |
| `--airfields` | `boolean` | `true` | Sonder autour de chaque aérodrome du théâtre. |
| `--out` | `str` | `<VEAF home>/clear-ground/<théâtre>.clear-ground.json` | Le catalogue à écrire. |
| `--survey-mission` | `str` | `<Saved Games>/DCS/Missions/veaf-survey-<théâtre>.miz` | Où écrire la mission d'arpentage. |
| `--bridge-lua` | `str` | *(aucun)* | dcs-bridge.lua local à embarquer (défaut : téléchargement). |
| `--state-dir` | `str` | `<VEAF home>/clear-ground/sweep-<théâtre>` | Où le balayage garde sa progression. |
| `--restart` | `boolean` | `false` | Jeter la progression d'un autre plan au lieu de refuser. |
| `--batch` | `int` | `10000` | Cellules sondées par appel à DCS. |
| `--wait` | `int` | `900` | Combien de secondes attendre que la mission d'arpentage réponde. |
| `--api-key` | `str` | *(aucun)* | Jeton Bearer superuser de dcs-serve (par défaut : lu dans dcs-serve.yaml). (variable d'environnement `DCS_BRIDGE_API_KEY`) |
| `--config` | `str` | *(aucun)* | Chemin d'un dcs-serve.yaml / dcs-client.yaml où lire la clé. |
| `--serve-url` | `str` | `http://127.0.0.1:8080` | URL de base de dcs-serve. |
| `--dcs-serve` | `str` | *(aucun)* | L'exécutable dcs-serve à lancer quand aucun ne tourne (par défaut : à côté de veaf-tools, ou dans le PATH). |
| `--verbose` | `boolean` | `false` | Si activé, affiche des informations de débogage détaillées. |

```bash
.\veaf-tools.exe dcs clear-ground-sweep Caucasus --zones-from MaMission.miz
```

*Alias plat : `veaf-tools clear-ground-sweep`*

### `veaf-tools dcs clear-ground-check` {#clear-ground-check}

Vérifie dans DCS si les véhicules au sol d'une mission construite sont dans les arbres ou les
bâtiments, **sans les faire apparaître**. Leur position est lue dans le `.miz`, puis sondée sur la mission
d'arpentage vide : aucun véhicule n'y existe, donc aucun n'est compté comme bloqué par ses voisins — ce
qui arrive dès qu'on sonde une batterie déjà apparue. Chaque réponse est comparée à ce que le catalogue
de terrain dégagé prédisait, et un désaccord est signalé comme une question sur le catalogue. Les
marqueurs de combat zone (`#command`) ne sont pas vérifiés : leur groupe est dessiné au runtime, qui le
déplace lui-même hors du décor. Même déroulé que `clear-ground-sweep` : `dcs-serve`, mission d'arpentage,
consignes, attente.

| Nom | Type | Obligatoire | Description |
|---|---|---|---|
| `MISSION` | `str` | oui | Le .miz à vérifier. Il est lu, jamais chargé dans DCS. |

| Options | Type | Défaut | Description |
|---|---|---|---|
| `--survey-mission` | `str` | `<Saved Games>/DCS/Missions/veaf-survey-<théâtre>.miz` | Où écrire la mission d'arpentage. |
| `--bridge-lua` | `str` | *(aucun)* | dcs-bridge.lua local à embarquer (défaut : téléchargement). |
| `--wait` | `int` | `900` | Combien de secondes attendre que la mission d'arpentage réponde. |
| `--report` | `str` | *(aucun)* | Écrire aussi le rapport en JSON dans ce fichier. |
| `--api-key` | `str` | *(aucun)* | Jeton Bearer superuser de dcs-serve (par défaut : lu dans dcs-serve.yaml). (variable d'environnement `DCS_BRIDGE_API_KEY`) |
| `--config` | `str` | *(aucun)* | Chemin d'un dcs-serve.yaml / dcs-client.yaml où lire la clé. |
| `--serve-url` | `str` | `http://127.0.0.1:8080` | URL de base de dcs-serve. |
| `--dcs-serve` | `str` | *(aucun)* | L'exécutable dcs-serve à lancer quand aucun ne tourne. |
| `--verbose` | `boolean` | `false` | Si activé, affiche des informations de débogage détaillées. |

```bash
.\veaf-tools.exe dcs clear-ground-check build\MaMission.miz
```

*Alias plat : `veaf-tools clear-ground-check`*

### `veaf-tools dcs scenery-objects` {#scenery-objects}

Liste les **objets de la carte** — ponts, bâtiments qui font partie de la carte elle-même — autour d'un
ou plusieurs points, avec leur identifiant DCS, leur type et leur distance au point, du plus proche au
plus loin. C'est l'identifiant que prend le
[`scenery_targets`](mission-maker/scripts/veafCombatZone.md#scenery-targets) d'une zone de combat : un
objet de la carte n'est pas créé par la zone, elle ne peut donc le reconnaître que par son numéro, et ce
numéro n'existe que dans DCS. Même déroulé que `clear-ground-check` : `dcs-serve`, mission d'arpentage
vide, consignes, attente. Les points sont en coordonnées de mission (`x` vers le nord, `y` vers l'est,
en mètres).

| Nom | Type | Obligatoire | Description |
|---|---|---|---|
| `THEATRE` | `str` | oui | Le théâtre, tel que DCS l'écrit (Caucasus, Syria…). |

| Options | Type | Défaut | Description |
|---|---|---|---|
| `--around` | `str` | *(aucun)* | Un point autour duquel chercher, en `x,y` ou `x,y,rayon` (rayon 150 m par défaut). Répétable. |
| `--report` | `str` | *(aucun)* | Écrire aussi les objets en JSON dans ce fichier. |
| `--survey-mission` | `str` | `<Saved Games>/DCS/Missions/veaf-survey-<théâtre>.miz` | Où écrire la mission d'arpentage. |
| `--bridge-lua` | `str` | *(aucun)* | dcs-bridge.lua local à embarquer (défaut : téléchargement). |
| `--wait` | `int` | `900` | Combien de secondes attendre que la mission d'arpentage réponde. |
| `--api-key` | `str` | *(aucun)* | Jeton Bearer superuser de dcs-serve (par défaut : lu dans dcs-serve.yaml). (variable d'environnement `DCS_BRIDGE_API_KEY`) |
| `--config` | `str` | *(aucun)* | Chemin d'un dcs-serve.yaml / dcs-client.yaml où lire la clé. |
| `--serve-url` | `str` | `http://127.0.0.1:8080` | URL de base de dcs-serve. |
| `--dcs-serve` | `str` | *(aucun)* | L'exécutable dcs-serve à lancer quand aucun ne tourne. |
| `--verbose` | `boolean` | `false` | Si activé, affiche des informations de débogage détaillées. |

```bash
.\veaf-tools.exe dcs scenery-objects Syria --around -64230,352140,100
```

*Alias plat : `veaf-tools scenery-objects`*

### `veaf-tools dcs farp-spot` {#farp-spot}

Cherche les **places plates et dégagées d'arbres et de bâtiments** près d'un point, où poser un FARP, et les liste de la plus proche à la plus lointaine avec leur distance et leur dénivelé. C'est la commande à lancer quand `add_farp` prévient qu'il n'a pas pu vérifier les arbres ou la pente (un théâtre sans catalogue de sol dégagé ni grille d'altitude, comme MarianaIslands), ou que le pad est en pente : l'avertissement donne la commande, point compris.

Une place est retenue quand le sol y est de la terre (ni eau, ni route, ni piste), quand DCS trouve une place de 5 m libre à 20 m sur la place **et** en 8 points à 40 m autour, et quand le dénivelé entre ces 9 points ne dépasse pas `--max-drop` mètres. La recherche parcourt une grille de 50 m, par bandes de 300 m pour que chaque appel à `dcs-serve` reste court. Une place listée est dégagée ; une place écartée n'est pas forcément boisée — la requête DCS sur laquelle la commande repose peut répondre « pas de place » sur de l'herbe dégagée (limitation connue `disposition-small-query-blocks-open-grass`) : regardez en jeu avant de renoncer à un endroit. Même déroulé que `clear-ground-check` : `dcs-serve`, mission d'arpentage vide, consignes, attente. Le point est en coordonnées de mission (`x` vers le nord, `y` vers l'est, en mètres).

| Nom | Type | Obligatoire | Description |
|---|---|---|---|
| `THEATRE` | `str` | oui | Le théâtre, tel que DCS l'écrit (Caucasus, MarianaIslands…). |

| Options | Type | Défaut | Description |
|---|---|---|---|
| `--at` | `str` | *(obligatoire)* | Le point autour duquel chercher, en `x,y`. |
| `--radius` | `float` | `1200` | Jusqu'où chercher autour du point, en mètres. |
| `--max-drop` | `float` | `3` | Le plus grand dénivelé accepté sur une place (son centre et l'anneau de 40 m), en mètres. |
| `--limit` | `int` | `10` | Combien de places afficher. |
| `--report` | `str` | *(aucun)* | Écrire aussi toutes les places trouvées en JSON dans ce fichier. |
| `--survey-mission` | `str` | `<Saved Games>/DCS/Missions/veaf-survey-<théâtre>.miz` | Où écrire la mission d'arpentage. |
| `--bridge-lua` | `str` | *(aucun)* | dcs-bridge.lua local à embarquer (défaut : téléchargement). |
| `--wait` | `int` | `900` | Combien de secondes attendre que la mission d'arpentage réponde. |
| `--api-key` | `str` | *(aucun)* | Jeton Bearer superuser de dcs-serve (par défaut : lu dans dcs-serve.yaml). (variable d'environnement `DCS_BRIDGE_API_KEY`) |
| `--config` | `str` | *(aucun)* | Chemin d'un dcs-serve.yaml / dcs-client.yaml où lire la clé. |
| `--serve-url` | `str` | `http://127.0.0.1:8080` | URL de base de dcs-serve. |
| `--dcs-serve` | `str` | *(aucun)* | L'exécutable dcs-serve à lancer quand aucun ne tourne. |
| `--verbose` | `boolean` | `false` | Si activé, affiche des informations de débogage détaillées. |

```bash
.\veaf-tools.exe dcs farp-spot MarianaIslands --at -22300,-12450
```

Le point se donne avec `--at` plutôt qu'en deux arguments : un nombre négatif en deuxième position serait lu comme une option.

*Alias plat : `veaf-tools farp-spot`*

### `veaf-tools dcs terrain-sweep` {#terrain-sweep}

Relève l'**altitude du sol** de tout un théâtre (`land.getHeight`, tous les 250 m par défaut) et l'écrit
dans `<VEAF home>/terrain/<théâtre>.terrain`. L'action MCP `terrain_elevation` lit ensuite cette
grille sans DCS : altitude d'une cible, sol le plus haut le long d'une route, masquage par le relief
entre une route et un site SAM. Même déroulé que `clear-ground-sweep` : `dcs-serve`, mission
d'arpentage vide, consignes, attente ; un relevé interrompu reprend où il s'est arrêté. L'étendue
relevée est celle de la carte, demandée à DCS ; s'il ne la donne pas, celle des aérodromes plus 50 km,
et la commande le dit. **Relief seul** : ni bâtiments, ni pylônes, ni arbres.

Un théâtre déjà relevé par la VEAF n'a pas besoin de relevé : sa grille est publiée sur GitHub (release [`terrain-data`](https://github.com/VEAF/VEAF-Mission-Creation-Tools/releases/tag/terrain-data)), et veaf-tools la télécharge au premier usage, dans le même dossier.
Une grille déjà présente — relevée ici ou téléchargée — est utilisée telle quelle.
Relève un théâtre quand il n'est pas publié, ou pour remplacer une grille téléchargée.

| Nom | Type | Obligatoire | Description |
|---|---|---|---|
| `THEATRE` | `str` | oui | Le théâtre, tel que DCS l'écrit (Caucasus, Syria…). |

| Options | Type | Défaut | Description |
|---|---|---|---|
| `--spacing` | `float` | `250` | Distance entre deux échantillons, en mètres. |
| `--bounds` | `str` | *(celle de la carte)* | L'étendue à relever, en `min_x,min_y,max_x,max_y` (coordonnées de mission). |
| `--measure-at` | `str` | *(aucun)* | Au lieu de relever la carte, relève finement (50 m) un carré de 20 km autour de ce point `x,y` et dit, pour chaque pas candidat (100, 250, 500, 1000 m), l'erreur en un point et l'écart du maximum d'un carré de 10 km. Répétable. |
| `--out` | `str` | `<VEAF home>/terrain/` | La grille (ou, avec `--measure-at`, le rapport) à écrire. |
| `--survey-mission` | `str` | `<Saved Games>/DCS/Missions/veaf-survey-<théâtre>.miz` | Où écrire la mission d'arpentage. |
| `--bridge-lua` | `str` | *(aucun)* | dcs-bridge.lua local à embarquer (défaut : téléchargement). |
| `--state-dir` | `str` | `<VEAF home>/terrain/sweep-<théâtre>` | Où le relevé garde sa progression. |
| `--restart` | `boolean` | `false` | Jeter la progression d'un autre plan au lieu de refuser. |
| `--batch` | `int` | `20000` | Altitudes lues par appel à DCS. |
| `--wait` | `int` | `900` | Combien de secondes attendre que la mission d'arpentage réponde. |
| `--api-key` | `str` | *(aucun)* | Jeton Bearer superuser de dcs-serve (par défaut : lu dans dcs-serve.yaml). (variable d'environnement `DCS_BRIDGE_API_KEY`) |
| `--config` | `str` | *(aucun)* | Chemin d'un dcs-serve.yaml / dcs-client.yaml où lire la clé. |
| `--serve-url` | `str` | `http://127.0.0.1:8080` | URL de base de dcs-serve. |
| `--dcs-serve` | `str` | *(aucun)* | L'exécutable dcs-serve à lancer quand aucun ne tourne. |
| `--verbose` | `boolean` | `false` | Si activé, affiche des informations de débogage détaillées. |

```bash
.\veaf-tools.exe dcs terrain-sweep Caucasus
```

*Alias plat : `veaf-tools terrain-sweep`*

### Parler à une mission lancée dans DCS : le bridge VEAF {#dcs-bridge}

`smoke-test`, `mission-check`, `recon-plan` et `recon-shoot` parlent à la mission que **vous** avez lancée dans DCS, sur cet ordinateur, par un seul chemin : le **bridge VEAF**. C'est le script `dcs-bridge.lua`, embarqué dans la mission, qui se connecte à `dcs-serve`, le petit serveur local par lequel passent les commandes.

- **La mission doit porter le bridge.** `recon-prepare` et `mission-check-prepare` l'embarquent dans la copie qu'elles écrivent ; pour `smoke-test`, bâtissez la mission avec la section `dcs_bridge` du `mission.yaml` activée, ou passez-la par [`inject-bridge`](#inject-bridge).
- **`dcs-serve` est démarré pour vous.** S'il ne répond pas, la commande le lance comme [`clear-ground-sweep`](#clear-ground-sweep) : trouvé à côté de `veaf-tools.exe`, dans le `PATH`, ou via `--dcs-serve`, avec une clé générée et une écoute limitée à cet ordinateur, et arrêté à la fin.
- **Une manip à faire une fois sur votre DCS** : autoriser les scripts de mission à communiquer, en modifiant `Scripts\MissionScripting.lua` de l'installation DCS. C'est la même que pour `clear-ground-sweep` et la capture des aérodromes ; elle est décrite pas à pas dans [Récupérer les aérodromes d'une carte](developer/capture-airbases.md), étape 0, et se refait après chaque mise à jour de DCS.
- **Le bridge se reconnecte à son rythme** : jusqu'à une minute de temps de mission quand `dcs-serve` démarre après la mission. La commande attend (`--wait`, 180 s par défaut) et dit ce qu'elle attend. La mission doit tourner **hors pause** : en pause, le bridge ne répond pas.

Ces quatre commandes partagent ces options :

| Options | Type | Défaut | Description |
|---|---|---|---|
| `--serve-url` | `str` | `http://127.0.0.1:8080` | URL de base de dcs-serve. |
| `--dcs-serve` | `str` | *(aucun)* | L'exécutable dcs-serve à démarrer quand aucun ne tourne ; par défaut : à côté de veaf-tools.exe, puis dans le PATH. |
| `--api-key` | `str` | *(aucun)* | La clé d'un dcs-serve que vous avez démarré vous-même. (variable d'environnement `DCS_BRIDGE_API_KEY`) |
| `--config` | `str` | *(aucun)* | Le dcs-serve.yaml d'un dcs-serve que vous avez démarré vous-même, pour y lire sa clé. |
| `--wait` | `int` | `180` | Secondes d'attente de la connexion du bridge de la mission. |

### `veaf-tools dcs smoke-test` {#smoke-test}

Vérifie le comportement runtime VEAF dans la mission lancée dans DCS, par le [bridge VEAF](#dcs-bridge) : la mission doit être bâtie avec `dcs_bridge`. Une ligne par vérification ; code de sortie 1 si l'une échoue.

| Options | Type | Défaut | Description |
|---|---|---|---|
| `--suite` | `str` | `default` | Quelle série de contrôles lancer : `default` (toute mission) ou `spotter` (uniquement le banc demo-spotter-network). |
| `--timeout` | `float` | `10.0` | Délai d'attente par vérification, en secondes. |
| `--verbose` | `boolean` | `false` | Si activé, affiche des informations de débogage détaillées. |

Plus les [options du bridge](#dcs-bridge).

```powershell
.\veaf-tools.exe dcs smoke-test
```

*Alias plat : `veaf-tools smoke-test`*

**Voir aussi** : [developer/smoke-harness.md](developer/smoke-harness.md)

### `veaf-tools dcs mission-check-prepare` {#mission-check-prepare}

Écrit la copie de test sur laquelle tourne `mission-check` : la mission bâtie, le [bridge VEAF](#dcs-bridge) embarqué, rien d'autre de changé. La mission d'origine n'est pas touchée.

| Arguments | Type | Description |
|---|---|---|
| `MISSION` | `Path` | La mission bâtie (.miz) ; elle n'est pas modifiée. |

| Options | Type | Défaut | Description |
|---|---|---|---|
| `--out` | `Path` | *(à côté, suffixe `_CHECK`)* | Où écrire la copie. |
| `--bridge-lua` | `str` | *(aucun)* | Un dcs-bridge.lua local à embarquer ; téléchargé depuis le dépôt VEAF-dcs-bridge sinon. |
| `--verbose` | `boolean` | `false` | Si activé, affiche des informations de débogage détaillées. |

```powershell
.\veaf-tools.exe dcs mission-check-prepare MaMission.miz
```

*Alias plat : `veaf-tools mission-check-prepare`*

### `veaf-tools dcs mission-check` {#mission-check}

Vérifie la mission **lancée dans DCS** — la copie écrite par [`mission-check-prepare`](#mission-check-prepare), que vous avez lancée vous-même — par le [bridge VEAF](#dcs-bridge), et écrit une ligne par vérification puis un verdict :

- **menus F10** : chaque entrée du menu radio VEAF a un libellé ; une entrée vide est signalée avec son chemin (`VEAF > Zones > ∅`) ;
- **zones et missions de combat** : chacune est activée puis désactivée, ses unités comptées à chaque fois, et elle est **laissée comme elle était** ; une CAP est vérifiée sous chacun de ses noms de variante (`<nom>/<niveau>/<échelle>`) ; une *opération* est signalée mais pas basculée (elle entraînerait ses zones) ;
- **colonnes** : chaque groupe au sol qui a une route de plus d'un point — de la mission ou tiré par une zone — doit rouler dans les 60 secondes. C'est ce contrôle qui trouve une colonne figée par un tronçon « On Road » sans route à suivre.

Laissez DCS tourner **sans pause** pendant la vérification : en pause, rien n'apparaît et rien ne roule. Compter quelques minutes (la commande l'annonce). Code de sortie 1 si une vérification échoue.

| Options | Type | Défaut | Description |
|---|---|---|---|
| `--only` | `str` | *(toutes)* | Nom d'une zone ou mission de combat à vérifier ; répétez pour plusieurs. Les menus et les colonnes de la mission sont vérifiés dans tous les cas. |
| `--verbose` | `boolean` | `false` | Si activé, affiche des informations de débogage détaillées. |

Plus les [options du bridge](#dcs-bridge).

```powershell
.\veaf-tools.exe dcs mission-check
```

*Alias plat : `veaf-tools mission-check`*

### Photos de reconnaissance — `recon-prepare`, `recon-plan`, `recon-shoot`, `recon-render` {#recon-photos}

Quatre commandes, une par étape, parce que vous intervenez entre chacune : elles produisent une photo de reco par objectif, prise **dans DCS** dans l'axe d'engagement prévu, au rendu « photo de reconnaissance » (noir et blanc contrasté, grain, bandeau, rose de cap) avec les cibles entourées **au feutre rouge**. Les unités sont placées là où DCS les a vraiment mises, tirages au hasard des zones compris. Le résultat (JPEG + JSON par prise, et un index `recon.json`) s'intègre au briefing.

Le déroulé complet :

1. `.\veaf-tools.exe dcs recon-prepare MaMission.miz` écrit `MaMission_RECON.miz` à côté : ciel dégagé, heure choisie, toutes les zones de combat actives au démarrage, noms de groupes lisibles, et le [bridge VEAF](#dcs-bridge) embarqué, par lequel `recon-plan` et `recon-shoot` parlent à la mission. La mission d'origine n'est pas touchée.
2. Dans DCS : ouvrez `MaMission_RECON.miz`, prenez un slot **spectateur**, appuyez sur **F11** (caméra libre). Laissez la fenêtre DCS sur l'**écran principal**.
3. `.\veaf-tools.exe dcs recon-plan --operation "Marteau du Golan"` écrit `shots.yaml` : une prise par zone, avec les noms des groupes présents.
4. Complétez `shots.yaml` : pour chaque prise, le `heading` d'engagement (la direction dans laquelle regarde l'attaquant, en degrés sur la grille de la mission, comme DCS tourne sa caméra : le bandeau de la photo et le briefing l'impriment en magnétique), et si besoin `pitch` (degrés sous l'horizon), `slant` (distance en mètres), `mark: units` pour entourer chaque véhicule, `labels` pour nommer les cibles.
5. `.\veaf-tools.exe dcs recon-shoot` : la commande place la caméra sur chaque prise et capture la fenêtre. Ne touchez ni la souris ni le clavier avant la fin.
6. `.\veaf-tools.exe dcs recon-render` écrit les photos dans `docs\recon\`, là où le briefing (`build_mission_briefing`) les cherche.
   Une prise rattachée à un préfixe de groupe nu (`Sasa [r]`) rejoint sa zone (`Sasa`) quand on relance `recon-render` : inutile de la refaire.

Lancez les commandes depuis le dossier de la mission : les prises brutes vont dans `docs\build\recon\raw\`, les photos finies dans `docs\recon\`.

Un `shots.yaml` complété :

```yaml
operation: Marteau du Golan
coalition: red
shots:
  - name: 03-sa11
    title: Batterie SA-11 de Kiswah
    groups: [SA11Kiswah]
    heading: 70
    pitch: 30
    slant: 1100
    mark: units
    labels: {"SA-11 Buk SR": "RADAR 9S18", "SA-11 Buk LN": "TEL"}
```

La caméra est placée à `slant` mètres de la cible, `pitch` degrés au-dessus de l'horizon, en regardant au cap `heading`. Les marques sont posées par projection avec un champ horizontal de 80°, mesuré : les six véhicules d'un SA-11 tombent à quelques pixels de leur projection.

**Une prise par objectif, deux au plus** : le briefing garde les deux premières et ignore les autres. **Un groupe de véhicules qui se déplacent** — chars, blindés légers, camions, 4x4 — **n'est jamais entouré**, quoi que dise `mark` : la photo montre sa zone, pas la place de chaque véhicule, qui aura bougé. Un groupe qui porte un SAM, un radar ou de l'artillerie est un site, et il est entouré. Le bandeau donne la position de la cible en DDM et en MGRS.

#### `veaf-tools dcs recon-prepare` {#recon-prepare}

| Arguments | Type | Description |
|---|---|---|
| `MISSION` | `Path` | La mission construite (.miz) ; elle n'est pas modifiée. |

| Options | Type | Défaut | Description |
|---|---|---|---|
| `--time` | `str` | `11:30` | Heure des photos, HH:MM à l'heure du théâtre. |
| `--out` | `Path` | *(à côté, suffixe `_RECON`)* | Où écrire la copie. |
| `--bridge-lua` | `str` | *(aucun)* | Un dcs-bridge.lua local à embarquer ; téléchargé depuis le dépôt VEAF-dcs-bridge sinon. |
| `--verbose` | `boolean` | `false` | Si activé, affiche des informations de débogage détaillées. |

*Alias plat : `veaf-tools recon-prepare`*

#### `veaf-tools dcs recon-plan` {#recon-plan}

| Options | Type | Défaut | Description |
|---|---|---|---|
| `--out` | `Path` | `shots.yaml` | Le fichier de prises à écrire. |
| `--coalition` | `str` | `red` | Le camp à photographier : `red` ou `blue`. |
| `--operation` | `str` | *(aucun)* | Le nom de l'opération, imprimé sur chaque photo. |
| `--force` | `boolean` | `false` | Écrase un fichier de prises existant. |
| `--verbose` | `boolean` | `false` | Si activé, affiche des informations de débogage détaillées. |

Plus les [options du bridge](#dcs-bridge).

*Alias plat : `veaf-tools recon-plan`*

#### `veaf-tools dcs recon-shoot` {#recon-shoot}

| Options | Type | Défaut | Description |
|---|---|---|---|
| `--shots` | `Path` | `shots.yaml` | Le fichier de prises. |
| `--raw-dir` | `Path` | `docs\build\recon\raw` | Dossier des prises brutes (PNG + JSON). |
| `--only` | `str` | *(toutes)* | Nom d'une prise à faire ; répétez pour plusieurs. |
| `--verbose` | `boolean` | `false` | Si activé, affiche des informations de débogage détaillées. |

Plus les [options du bridge](#dcs-bridge).

La caméra F11 est déplacée depuis l'état `export` de DCS, que le bridge atteint par `net.dostring_in` ; la capture de la fenêtre se fait sur cet ordinateur. La fenêtre DCS doit être sur l'écran principal et visible : une capture de tous les écrans rend la fenêtre DirectX noire, et une image noire est recommencée jusqu'à huit fois.

*Alias plat : `veaf-tools recon-shoot`*

#### `veaf-tools dcs recon-render` {#recon-render}

| Options | Type | Défaut | Description |
|---|---|---|---|
| `--shots` | `Path` | `shots.yaml` | Le fichier de prises (l'ordre et le nom de l'opération). |
| `--raw-dir` | `Path` | `docs\build\recon\raw` | Dossier des prises brutes. |
| `--out-dir` | `Path` | `docs\recon` | Dossier des photos finies. |
| `--verbose` | `boolean` | `false` | Si activé, affiche des informations de débogage détaillées. |

Écrit `<prise>.jpg`, `<prise>.json` et `recon.json`, la liste ordonnée des prises. Le JSON porte ce que le briefing lit — `zone` (la zone de combat de l'objectif : la clé `zone` de la prise, sinon celle du premier préfixe de `groups`), `title`, `heading`, `pitch` (négatif vers le bas), `x`/`y` et `altitude_m` (la caméra, en coordonnées de mission), `order` — puis le reste de la prise : caméra, cible en coordonnées DCS, latitude/longitude et DMS, heure, unités.

*Alias plat : `veaf-tools recon-render`*

## L'outil lui-même

### `veaf-tools about` {#about}

Affiche les informations sur VEAF Mission Creation Tools.

| Options | Type | Défaut | Description |
|---|---|---|---|
| `--modules` | `boolean` | `false` | Affiche la liste des modules Lua VEAF embarqués. |

```bash
veaf-tools about
```

### `veaf-tools doctor` {#doctor}

Rassemble les versions, chemins et erreurs récentes qu'un rapport de bug exige : version de l'outil, version de DCS, système, emplacement des journaux. La commande affiche d'abord un tableau lisible, puis un **bloc à coller** tel quel dans un signalement.

Les chemins Windows contiennent votre nom de compte : le bloc est **caviardé avant d'être affiché** (`C:\Users\<user>\…`), ainsi que les adresses IP et tout ce qui ressemble à un jeton. Il est donc sûr à publier.

| Options | Type | Défaut | Description |
|---|---|---|---|
| `--paste` | `boolean` | `false` | N'affiche que le bloc à coller, sans le tableau lisible. |
| `--errors` | `integer` | `3` | Nombre d'erreurs récentes du journal de l'outil à inclure (0 pour aucune). |

```powershell
.\veaf-tools.exe doctor
```

La commande fonctionne même sans DCS installé, sans `VEAF_HOME` défini et sans journal : les faits qu'elle ne peut pas lire valent `unknown`, le reste est produit quand même.

**Voir aussi** : [Obtenir de l'aide](SUPPORT.md), et [le format du bloc](developer/diagnostic-block.md) pour ceux qui l'exploitent.

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

L'assistant tourne sur une allocation gratuite partagée avec le chatbot du site : un jour chargé,
elle peut s'épuiser, et la commande le dit alors clairement. Voir
[l'assistant de documentation](SUPPORT.md#assistant).

### `veaf-tools ai-setup` {#ai-setup}

Branche sur les outils VEAF les assistants IA installés sur ce PC : **Claude Desktop**, **Claude Code**, **Codex** (ChatGPT Desktop), **Antigravity**, **Gemini CLI** et **OpenCode**.
La commande déclare l'exécutable qui la lance comme serveur MCP `veaf-mission-editor` dans la configuration de chacun, sans toucher à leurs autres réglages, et dit pour chacun s'il est branché, absent ou en échec.
On peut la relancer sans risque, par exemple après avoir déplacé le dossier des outils.

```powershell
.\veaf-tools.exe ai-setup
```

Elle n'a pas d'option. Quittez ensuite complètement l'assistant IA et relancez-le : il ne lit ses serveurs qu'au démarrage.
Elle sort en erreur (code 1) quand aucun assistant n'est trouvé ou qu'un réglage n'a pas pu être écrit, sans rien modifier dans le fichier en cause.

**Voir aussi** : [Créer avec une IA](mission-maker/AI_ASSISTANT_INSTALL.md)

### `veaf-tools mcp` {#mcp}

Démarre le serveur MCP d'édition de mission assistée par LLM (stdio). Déclaré dans votre assistant IA par [`ai-setup`](#ai-setup).

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
