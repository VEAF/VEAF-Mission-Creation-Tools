# `veaf-mission-mcp` — serveur MCP d'édition de mission assistée par LLM

> **Public visé** : les développeurs qui font évoluer le serveur MCP d'édition de mission, ou
> qui branchent un client MCP (Claude Code, un agent) dessus.
>
> 🇬🇧 [`mission-editing-mcp.en.md`](mission-editing-mcp.en.md).
>
> 🎯 Côté Mission Maker (catalogue en langage courant) :
> [`mission-maker/AI_ASSISTANT_CATALOG.md`](../mission-maker/AI_ASSISTANT_CATALOG.md).

## Pourquoi ce serveur

Première phase de **NL-MISSION-GEN** (voir `ROADMAP.md` §4) : permettre à un LLM d'éditer une
mission DCS pour le compte d'un Mission Maker — et à terme, d'en générer une entière depuis un
prompt détaillé. Voir [ADR 0014](../adr/0014-mission-editor-mcp-editor-parity-layer.md) pour la
décision d'architecture, et `CONTEXT.md` (section « LLM-assisted mission editing ») pour le
vocabulaire.

Deux familles d'actions, volontairement séparées :

- **Action editor-parity** — mute directement les tables Lua brutes du `.miz` source, exactement
  comme un Mission Maker le ferait à la main dans l'éditeur DCS (ajouter un groupe, un trigger,
  une zone). Ne passe jamais par `mission.yaml`. C'est tout le périmètre de ce serveur en v1.
- **Action VMCT** — passe par le pipeline déclaratif `mission.yaml` existant (`inject_presets`,
  `aircraft_groups`...). Depuis la **vague 4**, le serveur en expose une première brique : éditer
  le `mission.yaml` source (voir plus bas), en plus du pipeline CLI/config habituel.

## Lancer le serveur localement

```bash
poetry install
poetry run veaf-mission-mcp
```

Démarre un serveur MCP sur `stdio` (transport par défaut du SDK `mcp`). Aucune configuration :
chaque action reçoit le chemin du `.miz` à éditer en paramètre.

## Catalogue d'actions (v1)

Le serveur n'expose **pas** un outil MCP par action métier. Il expose une surface de découverte
fixe, à l'image du serveur MCP `dcs-bridge` (pont vers une mission qui tourne) :

| Outil MCP | Rôle |
|-----------|------|
| `capabilities()` | Identité du serveur (nom, version). |
| `list_catalog()` | Liste les actions enregistrées (`name`, `description`, `parameters_schema`). |
| `describe_action(name)` | Détaille le schéma JSON des paramètres d'une action. |
| `run_action(name, params)` | Exécute une action enregistrée. |

Les actions elles-mêmes sont enregistrées par
`veaf_mission_mcp.actions.register_default_actions` (`src/python/veaf-tools/veaf_mission_mcp/actions.py`).

### `describe_mission`

Lecture seule. Liste les groupes (nom, coalition, pays, catégorie) et zones de déclenchement
(nom, position, rayon) déjà présents dans le `.miz` — pour que l'appelant vérifie l'état courant
avant d'écrire, comme un humain consulterait l'arborescence de l'éditeur avant d'ajouter quelque
chose. Réutilise le parseur pur-Python existant (`mission_tools.miz_tools.read_miz`) — aucun
nouveau parsing.

```json
{"miz_path": "chemin/vers/mission.miz"}
```

### `add_group`

Écriture. Insère un groupe terrestre/véhicule dans le `.miz` source, **en place**, avec une
sauvegarde horodatée systématique avant l'écriture
(`mission_tools.miz_backup.backup_before_write`, ex. `mission.20260712-143012.miz`). Une
collision sur la même seconde est désambiguïsée (`-2`, `-3`, ...), jamais silencieusement
écrasée.

```json
{
  "miz_path": "chemin/vers/mission.miz",
  "coalition": "red",
  "country_id": 0,
  "country_name": "Russia",
  "category": "vehicle",
  "name": "Red Armor Section",
  "position": {"x": 1000.0, "y": 2000.0},
  "units": [{"type": "T-72B", "count": 2}],
  "route": [{"x": 1000.0, "y": 2000.0}, {"x": 1200.0, "y": 2000.0}],
  "patrol": true
}
```

- `units` — le serveur ne fait **aucune** curation de catalogue d'unités : les types DCS
  concrets (`T-72B`, `BTR-80`...) sont la décision de l'appelant (LLM), pas de cette action.
- `route` — optionnelle ; par défaut un unique point stationnaire à `position`. Avec
  `patrol: true` (et au moins 2 points), le dernier point boucle sur le premier via une tâche
  `GoToWaypoint` — une patrouille terrestre DCS classique.
- **Pas de déduplication** : appeler deux fois avec les mêmes paramètres crée deux groupes
  distincts, exactement comme deux clics dans l'éditeur DCS.
- Les `groupId`/`unitId` sont toujours frais (`mission_tools.group_insertion.max_ids`), y compris
  sur une mission aux plages d'ids déjà trouées.

**Intentions de nommage (vague 6).** L'appelant exprime l'*intention* et `add_group` produit un
nom conforme aux conventions VEAF lui-même (`veaf_mission_mcp.group_naming.resolve_group_name`) :

- `for_combat_zone: <zone>` — préfixe le nom par le nom de la trigger-zone (règle d'appartenance
  combat zone), idempotent et insensible à la casse ;
- `late_activation: true` — pose le drapeau DCS `lateActivation` (intercepteurs QRA, templates CAP) ;
- `as_spawn_template: true` — préfixe `veafSpawn-` (template d'avion spawnable).

`add_group` renvoie aussi un champ `warnings` (voir `validate_group_name` ci-dessous) : il **écrit
quand même**, mais signale toute collision de convention pour que l'appelant la relaie.

### `validate_group_name` (vague 6)

Lecture seule. Contrôle un nom proposé contre les motifs réservés (préfixes
`veafSpawn-`/`OnDemand-`/`VEAF-placeholder-`, marqueurs `#veafInterpreter[...]`/`#command=`,
syntaxe de déploiement QRA, noms CAS fixes) et, avec `miz_path`, le **piège de capture combat
zone** (nom commençant par une trigger-zone existante). `expected_combat_zone` supprime
l'avertissement pour la zone intentionnellement visée. Partage le module
`veaf_mission_mcp.group_naming` avec `add_group`.

```json
{"name": "combatZone_North-tanks", "miz_path": "chemin/vers/mission.miz"}
```

### `add_trigger_zone` (vague 2)

Écriture. Insère une **zone de déclenchement circulaire** nommée dans `mission.triggers.zones`,
avec un `zoneId` frais, en place et sauvegardée d'abord. C'est la zone qu'une combat zone VEAF
référence : combinée à `add_group`, elle permet de poser une combat zone complète (la trigger
zone que `group_validation` exige + les groupes à l'intérieur). Pas de déduplication.

```json
{
  "miz_path": "chemin/vers/mission.miz",
  "name": "combatZone_North",
  "position": {"x": 1000.0, "y": 2000.0},
  "radius": 3000,
  "hidden": false
}
```

### `add_startup_script_trigger` (vague 2)

Écriture. Ajoute un trigger **« au démarrage de la mission »** qui exécute un script — pour
outiller une mission **vanilla ou CTLD** avec du scripting sans passer par l'onglet Triggers de
l'éditeur DCS. Généralise `inject_dcs_bridge_trigger` et le chargement static/dynamic VEAF
([ADR 0004](../adr/0004-dynamic-script-loading.md)). Contrairement à ce helper (qui insère en
position 1 et renumérote tout), cette action **ajoute à la fin** (index libre suivant) — aucun
trigger existant n'est renuméroté. Trois modes :

- **`inline`** — exécute du Lua fourni (`inline_lua`) via `a_do_script`.
- **`file_static`** — embarque un fichier `.lua` (`source_path`) dans le `.miz`
  (`l10n/DEFAULT/<nom>.lua` + entrée `mapResource`) et le charge via `a_do_script_file`.
- **`file_dynamic`** — charge un `.lua` depuis un chemin disque à l'exécution (`runtime_path`)
  via `loadfile`, sans rien embarquer.

```json
{
  "miz_path": "chemin/vers/mission.miz",
  "mode": "file_static",
  "comment": "load my script",
  "source_path": "C:/scripts/myscript.lua"
}
```

Sauvegarde horodatée avant écriture ; pas de déduplication.

## Édition des fichiers Lua embarqués (vague 3)

Troisième famille d'actions : éditer le **texte** des fichiers `.lua` embarqués dans le
`.miz` (`l10n/DEFAULT/**/*.lua`), **sans rebuild** — ni les tables brutes `mission.lua`
(editor-parity), ni le pipeline `mission.yaml` (action VMCT). Brique commune :
`mission_tools.rewrite_miz_members` recopie l'archive verbatim et ne remplace que les membres
ciblés (aucune re-sérialisation des tables Lua). Sauvegarde horodatée avant chaque écriture.

### `replace_in_mission_files` — search/replace générique

Remplacement texte ou regexp, **restreint à `l10n/DEFAULT/**/*.lua`** (jamais `mission`/
`options` ni les binaires). `files` est un glob appliqué au chemin relatif sous
`l10n/DEFAULT/`.

```json
{
  "miz_path": "chemin/vers/mission.miz",
  "search": "debug",
  "replace": "info",
  "files": "veaf-*.lua",
  "regex": false
}
```

Retourne `{files_changed, total_replacements}`.

### Réglages VMCT (`veaf-config.lua`)

Actions sémantiques qui éditent `l10n/DEFAULT/veaf-config.lua` (config VEAF générée au build).
Chacune **remplace la ligne si elle existe, sinon l'insère** en tête (avant l'init des
modules) :

- `set_log_level(level)` → `veaf.ForcedLogLevel = "<level>"` (parmi error/warning/info/debug/trace).
- `set_module_enabled(module_id, enabled)` → `veaf.setConfig("<MOD>", "enable", <bool>)`.
- `set_security_disabled(disabled)` → `veaf.SecurityDisabled = <bool>`.
- `set_veaf_config(key, value)` → `veaf.config.<key> = <scalaire Lua>`.

> Les **hashes de mot de passe** (`veafSecurity.password_L9[...]` / `password_MM[...]`) — un cas
> multi-lignes — ne sont pas couverts pour l'instant : seul le drapeau `SecurityDisabled` l'est.

## Actions VMCT sur `mission.yaml` (vague 4)

Quatrième famille — la première vraiment **VMCT** : éditer le **source déclaratif**
`mission.yaml` (ce que le build consomme pour *générer* le `.miz`), au lieu de patcher un
artefact déjà construit. Brique commune : `mission_tools.mission_yaml_editor` (mode round-trip
`ruamel.yaml`) qui **préserve commentaires, ordre des clés et mise en forme** — indispensable
pour un fichier source très commenté, édité à la main et tenu en lockstep avec le défaut livré.
Sauvegarde horodatée avant chaque écriture.

### `describe_mission_config`

Lecture seule. Liste le bloc `modules:` et, par module, son état : `mandatory` (clé nue),
`scalar` (booléen `MODULE: true/false`) ou `extended` (bloc de config imbriqué type
`COMBATZONE`/`CTLD`). Le pendant VMCT de `describe_mission`.

```json
{"mission_yaml_path": "chemin/vers/mission.yaml"}
```

### `set_mission_module`

Écriture. Active/désactive un module ou pose son bloc de config étendu, en préservant les
commentaires. `value` est soit un booléen (forme scalaire), soit un objet (bloc étendu). La clé
est **remplacée si présente, insérée sinon**. Pas de déduplication.

```json
{
  "mission_yaml_path": "chemin/vers/mission.yaml",
  "module_id": "COMBATZONE",
  "value": {"enabled": true, "combat_zones": [{"type": "zone", "zone_name": "CZ-Alpha"}]}
}
```

> Périmètre volontairement **générique** (toggle + pose de mapping) — pas de validateur de
> schéma par module : la forme du bloc de config passé reste la responsabilité de l'appelant
> (LLM), comme les types d'unités pour `add_group`.

### Parité recette / construit (vague 7)

Chaque réglage éditable sur le `veaf-config.lua` construit (vague 3) a son pendant **source**
`mission.yaml`, pour que les deux cibles soient joignables. Actions séparées (cohérent avec
`set_mission_module`), sur la brique `mission_yaml_editor` :

| Réglage | Recette (`mission.yaml`) | Construit (`veaf-config.lua`) |
|---------|--------------------------|-------------------------------|
| Niveau de log | `set_mission_log_level` → `global_log_level` | `set_log_level` |
| Sécurité | `set_mission_security` → bloc `security:` (**+ hash de mots de passe**) | `set_security_disabled` |
| Paramètre arbitraire | `set_mission_setting` → `settings.<clé>` | `set_veaf_config` → `veaf.config.<clé>` |
| Activation de module | `set_mission_module` (vague 4) | `set_module_enabled` |

## Oracle de connaissance métier (vague 5)

Les actions ci-dessus sont les **mains** (écriture) et les **yeux** (`describe_*`) du LLM. La
vague 5 lui donne un **cerveau** : des actions de **lecture seule** exposant la connaissance
DCS + VEAF nécessaire pour éditer correctement. Toutes lisent depuis les **sources canoniques**
que le build utilise déjà, donc **sans dérive possible** :

- Données DCS générées (`update-dcs-data` → `veaf_libs/data/dcsUnits.yaml`, publiées sur le
  GitHub VEAF) ;
- alias VEAF (`veaf_libs/data/veaf-units.yaml`) ;
- artefacts vendorisés (`vendored.yaml`, `check-vendored`) ;
- repos de datamining en amont (provenance).

Implémentation : `veaf_mission_mcp/oracle.py`. Le pendant « prose / comment raisonner » vit dans
le skill Claude `veaf-mission-authoring` (`plugin/skills/veaf-mission-authoring/SKILL.md`, bundlé
par `bfr-claude-plugins`) — le plugin = mains MCP + cerveau skill.

### `list_unit_types`

Lecture seule. Types d'unités DCS depuis la base générée, filtrables par `category` et/ou
`name_contains`. Pour que le LLM choisisse des types concrets.

```json
{"category": "Plane", "name_contains": "su-27"}
```

### `list_shortcuts`

Lecture seule. Le vocabulaire d'alias VEAF (`shilka`, `sa8`…) — alias d'unités
(`_spawn unit <alias>`) et de groupes composites (`_spawn group <alias>` : sites SAM, convois).
Filtrable par `name_contains`.

### `describe_naming_conventions`

Lecture seule. Les **8 motifs de nommage réservés** (appartenance combat zone, préfixes
`veafSpawn-`/`OnDemand-`, marqueurs `#veafInterpreter[…]`/`#command=`, entrées de déploiement
QRA, noms CAS fixes…) avec, pour chacun, la règle et le module qui la consomme. À vérifier avant
un `add_group`.

### `describe_module`

Lecture seule. **Localisateur** (pas un validateur de schéma) : vérifie qu'un module VEAF existe
(via la liste canonique `lua_module_scanner`), renvoie sa page de doc, et — si `mission_yaml_path`
est fourni — son état activé. Les clés de config de chaque module vivent dans sa page de doc.

```json
{"module_id": "QRA", "mission_yaml_path": "chemin/vers/mission.yaml"}
```

## Composites — une passe, deux mondes (vague 8)

Actions haut niveau qui posent une **fonctionnalité complète** en un appel, sur un **dossier de
mission** : elles éditent la **source durable** (le `src/mission/` exploité — zones/groupes — via
`mission_folder`, **et** `mission.yaml`), sans déclencher de build (un `veaf-tools build` ultérieur
produit le `.miz`). Elles orchestrent les primitives des vagues 1-7 (`insert_trigger_zone`,
`insert_group_into_content`, l'éditeur `mission.yaml`). Implémentation : `veaf_mission_mcp/composites.py`.

### `create_combat_zone`

Zone de déclenchement + groupes placés dedans (noms auto-préfixés par la zone → capturés au
runtime, coalition indifférente) + bloc `modules.COMBATZONE.combat_zones[]` **ajouté** au yaml.

### `create_qra`

Zone + intercepteurs **Late Activation** (coalition significative) + entrée
`modules.QRA.definitions[]` référençant les groupes **par nom exact** (`simple_groups`). La
coalition est passée en minuscule pour le placement, majuscule dans la définition YAML.

### `create_cap_mission`

Groupe template **Late Activation** nommé `OnDemand-<nom>` + entrée `cap_missions[]`
(`group_name: <nom>`, sans préfixe — le build résout vers le groupe `OnDemand-`).

## Scaffolding d'un dossier de mission (vague 9)

Toutes les actions ci-dessus supposent qu'un dossier de mission **existe déjà**. La vague 9 fournit
l'amont : créer ce dossier depuis un **dossier vide**, en pilotant les vrais binaires VEAF comme le
ferait un Mission Maker à sa première installation.

### `scaffold_mission`

Écriture. Sur un dossier cible **vide** :

1. Résout l'asset updater de l'OS courant (`veaf-tools-updater.exe` sous Windows,
   `veaf-tools-updater-<os>-<arch>` sous Unix) et le télécharge depuis l'**URL de release stable**
   (`…/releases/download/<tag>/<asset>` — pas d'API GitHub, donc pas de rate-limit).
2. Lance l'updater dans le dossier (il télécharge et installe les outils VEAF + `published/`).
3. Lance `veaf-tools prepare --template <tier> --force` dans le dossier.

```json
{
  "target_folder": "chemin/vers/dossier-vide",
  "template": "standard",
  "github_token": "…",
  "tag": "published-latest"
}
```

- **Refuse un dossier non vide** — le scaffolding n'initialise qu'un dossier vide.
- `template` — `minimal` / `standard` / `full`. Le tier interactif `custom` n'est **pas** supporté
  ici (son sélecteur TUI n'a pas de TTY sous un sous-processus) ; c'est au LLM appelant de **poser
  la question du template** au Mission Maker et de le passer en paramètre.
- `github_token` — optionnel, relayé à l'updater (`--token`) pour contourner la limite de débit de l'API.
- Un code retour non nul de l'updater ou de `prepare`, ou l'absence de `veaf-tools`/`published/`
  après l'updater, remonte comme une erreur explicite.

C'est l'**étape 0** d'une mission créée de zéro, avant les composites de la vague 8.

## Prochaines vagues (hors périmètre)

- Zones non circulaires (quad/polygone) — la vague 2 ne couvre que les zones circulaires.
- Un éditeur de triggers SI/ALORS générique (conditions/actions DCS arbitraires) — la vague 2
  se limite aux triggers de démarrage chargement-de-script / exécution-Lua.
- Un validateur de schéma par module pour `set_mission_module` (la vague 4 reste générique).
- Composites CAS (pur runtime, pas d'écriture), zones non-circulaires, et génération end-to-end
  depuis un prompt (l'objectif NL-MISSION-GEN au-delà de ce lot).

Voir `.backlog/FEAT-MCP-MISSION-EDITOR/PRD.md` pour le détail.
