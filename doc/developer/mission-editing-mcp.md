# `veaf-mission-mcp` — serveur MCP d'édition de mission assistée par LLM

> **Public visé** : les développeurs qui font évoluer le serveur MCP d'édition de mission, ou
> qui branchent un client MCP (Claude Code, un agent) dessus.
>
> 🇬🇧 [`mission-editing-mcp.en.md`](mission-editing-mcp.en.md).

## Pourquoi ce serveur

Première phase de **NL-MISSION-GEN** (voir `ROADMAP.md` §4) : permettre à un LLM d'éditer une
mission DCS pour le compte d'un Mission Maker — et à terme, d'en générer une entière depuis un
prompt détaillé. Voir [ADR 0013](../adr/0013-mission-editor-mcp-editor-parity-layer.md) pour la
décision d'architecture, et `CONTEXT.md` (section « LLM-assisted mission editing ») pour le
vocabulaire.

Deux familles d'actions, volontairement séparées :

- **Action editor-parity** — mute directement les tables Lua brutes du `.miz` source, exactement
  comme un Mission Maker le ferait à la main dans l'éditeur DCS (ajouter un groupe, un trigger,
  une zone). Ne passe jamais par `mission.yaml`. C'est tout le périmètre de ce serveur en v1.
- **Action VMCT** — passe par le pipeline déclaratif `mission.yaml` existant (`inject_presets`,
  `aircraft_groups`...). Hors périmètre de ce serveur, inchangée.

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

## Prochaines vagues (hors périmètre)

- Zones non circulaires (quad/polygone) — la vague 2 ne couvre que les zones circulaires.
- Un éditeur de triggers SI/ALORS générique (conditions/actions DCS arbitraires) — la vague 2
  se limite aux triggers de démarrage chargement-de-script / exécution-Lua.
- Toute action VMCT (ex. écrire une entrée `modules.COMBATZONE` dans `mission.yaml`).
- Catalogue/curation de types d'unités.
- Actions composites (ex. un seul appel `create_combat_zone`).

Voir `.backlog/FEAT-MCP-MISSION-EDITOR/PRD.md` pour le détail.
