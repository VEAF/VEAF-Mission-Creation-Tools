# `veaf-mission-mcp` — LLM-assisted mission-editing MCP server

> **Audience**: developers evolving the mission-editing MCP server, or wiring an MCP client
> (Claude Code, an agent) to it.
>
> 🇫🇷 [`mission-editing-mcp.md`](mission-editing-mcp.md).
>
> 🎯 Mission-Maker side (plain-language catalogue):
> [`mission-maker/AI_ASSISTANT_CATALOG.en.md`](../mission-maker/AI_ASSISTANT_CATALOG.en.md).

## Why this server

First phase of **NL-MISSION-GEN** (see `ROADMAP.md` §4): let an LLM edit a DCS mission on a
Mission Maker's behalf — and, eventually, generate one end-to-end from a detailed prompt. See
[ADR 0014](../adr/0014-mission-editor-mcp-editor-parity-layer.md) for the architecture decision,
and `CONTEXT.md` (section "LLM-assisted mission editing") for the vocabulary.

Two action families, deliberately kept apart:

- **Editor-parity action** — mutates the mission's raw `.miz` Lua tables directly, exactly the
  way a Mission Maker would by hand in the DCS Mission Editor (add a group, a trigger, a zone).
  Never goes through `mission.yaml`. This is the entire scope of this server in v1.
- **VMCT action** — goes through the existing declarative `mission.yaml` pipeline
  (`inject_presets`, `aircraft_groups`...). As of **wave 4** the server exposes a first brick of
  this family: editing the source `mission.yaml` (see below), alongside the usual CLI/config path.

## Running the server locally

```bash
poetry install
poetry run veaf-mission-mcp
```

Starts an MCP server over `stdio` (the `mcp` SDK's default transport). No configuration: every
action receives the `.miz` path to edit as a parameter.

## Action catalog (v1)

The server does **not** expose one MCP tool per business action. It exposes a fixed discovery
surface, mirroring the `dcs-bridge` MCP tool (a bridge to a running mission):

| MCP tool | Role |
|----------|------|
| `capabilities()` | Server identity (name, version). |
| `list_catalog()` | List registered actions (`name`, `description`, `parameters_schema`). |
| `describe_action(name)` | Detail one action's parameter JSON Schema. |
| `run_action(name, params)` | Run a registered action. |

Concrete actions are registered by `veaf_mission_mcp.actions.register_default_actions`
(`src/python/veaf-tools/veaf_mission_mcp/actions.py`).

### `describe_mission`

Read-only. Lists the groups (name, coalition, country, category) and trigger zones (name,
position, radius) already present in the `.miz` — so the caller can check current state before
writing, the same way a human would check the editor's outliner before adding something. Reuses
the existing pure-Python parser (`mission_tools.miz_tools.read_miz`) — no new parsing.

```json
{"miz_path": "path/to/mission.miz"}
```

### `add_group`

Write. Inserts a ground/vehicle group into the source `.miz`, **in place**, with a systematic
timestamped backup before the write (`mission_tools.miz_backup.backup_before_write`, e.g.
`mission.20260712-143012.miz`). A same-second collision is disambiguated (`-2`, `-3`, ...), never
silently overwritten.

```json
{
  "miz_path": "path/to/mission.miz",
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

- `units` — the server does **no** unit-catalog curation: concrete DCS types (`T-72B`,
  `BTR-80`...) are the calling LLM's decision, not this action's.
- `route` — optional; defaults to a single stationary point at `position`. With `patrol: true`
  (and at least 2 points), the last point loops back to the first via a `GoToWaypoint` task — a
  classic DCS ground-unit patrol.
- **No deduplication**: calling this twice with the same parameters creates two distinct groups,
  exactly like two clicks in the DCS Mission Editor.
- `groupId`/`unitId`s are always fresh (`mission_tools.group_insertion.max_ids`), even on a
  mission with gaps in its existing id ranges.

**Naming intents (wave 6).** The caller expresses *intent* and `add_group` produces a
convention-correct name itself (`veaf_mission_mcp.group_naming.resolve_group_name`):

- `for_combat_zone: <zone>` — prefix the name with the trigger-zone name (combat-zone membership
  rule), idempotent and case-insensitive;
- `late_activation: true` — set the DCS `lateActivation` flag (QRA interceptors, CAP templates);
- `as_spawn_template: true` — `veafSpawn-` prefix (spawnable-aircraft template).

`add_group` also returns a `warnings` field (see `validate_group_name`): it **still writes**, but
flags any convention collision for the caller to relay.

### `validate_group_name` (wave 6)

Read-only. Checks a proposed name against the reserved patterns (`veafSpawn-`/`OnDemand-`/
`VEAF-placeholder-` prefixes, `#veafInterpreter[...]`/`#command=` markers, QRA deploy syntax, fixed
CAS names) and, with `miz_path`, the **combat-zone capture trap** (name starting with an existing
trigger-zone). `expected_combat_zone` suppresses the warning for the intended zone. Shares the
`veaf_mission_mcp.group_naming` module with `add_group`.

```json
{"name": "combatZone_North-tanks", "miz_path": "path/to/mission.miz"}
```

### `add_trigger_zone` (wave 2)

Write. Inserts a named **circular** trigger zone into `mission.triggers.zones`, with a fresh
`zoneId`, in place and backed up first. This is the zone a VEAF combat zone references: combined
with `add_group`, it lets you lay down a full combat zone (the trigger zone `group_validation`
requires + the groups inside it). No deduplication.

```json
{
  "miz_path": "path/to/mission.miz",
  "name": "combatZone_North",
  "position": {"x": 1000.0, "y": 2000.0},
  "radius": 3000,
  "hidden": false
}
```

### `add_startup_script_trigger` (wave 2)

Write. Adds a **"mission start"** trigger that runs a script — for outfitting a **vanilla or
CTLD** mission with scripting without the DCS editor's Triggers tab. Generalizes
`inject_dcs_bridge_trigger` and the VEAF static/dynamic loading mechanism
([ADR 0004](../adr/0004-dynamic-script-loading.md)). Unlike that helper (which inserts at index 1
and renumbers everything), this **appends** at the next free index — no existing trigger is
renumbered. Three modes:

- **`inline`** — run supplied Lua (`inline_lua`) via `a_do_script`.
- **`file_static`** — embed a `.lua` file (`source_path`) into the `.miz`
  (`l10n/DEFAULT/<name>.lua` + `mapResource` entry) and load it via `a_do_script_file`.
- **`file_dynamic`** — load a `.lua` from a runtime disk path (`runtime_path`) via `loadfile`,
  nothing embedded.

```json
{
  "miz_path": "path/to/mission.miz",
  "mode": "file_static",
  "comment": "load my script",
  "source_path": "C:/scripts/myscript.lua"
}
```

Timestamped backup before the write; no deduplication.

## Editing embedded Lua files (wave 3)

Third action family: edit the **text** of the `.lua` files embedded in the `.miz`
(`l10n/DEFAULT/**/*.lua`), **without a rebuild** — neither the raw `mission.lua` tables
(editor-parity) nor the `mission.yaml` pipeline (VMCT action). Shared brick:
`mission_tools.rewrite_miz_members` copies the archive through verbatim and swaps only the
targeted members (no Lua-table re-serialization). Timestamped backup before each write.

### `replace_in_mission_files` — generic search-replace

Text or regex replacement, **restricted to `l10n/DEFAULT/**/*.lua`** (never `mission`/
`options` or binaries). `files` is a glob matched against each `.lua`'s path relative to
`l10n/DEFAULT/`.

```json
{
  "miz_path": "path/to/mission.miz",
  "search": "debug",
  "replace": "info",
  "files": "veaf-*.lua",
  "regex": false
}
```

Returns `{files_changed, total_replacements}`.

### VMCT settings (`veaf-config.lua`)

Semantic actions editing `l10n/DEFAULT/veaf-config.lua` (the build-generated VEAF config).
Each **replaces the line if present, else inserts** it at the top (before the modules
initialise):

- `set_log_level(level)` → `veaf.ForcedLogLevel = "<level>"` (error/warning/info/debug/trace).
- `set_module_enabled(module_id, enabled)` → `veaf.setConfig("<MOD>", "enable", <bool>)`.
- `set_security_disabled(disabled)` → `veaf.SecurityDisabled = <bool>`.
- `set_veaf_config(key, value)` → `veaf.config.<key> = <Lua scalar>`.

> Password **hashes** (`veafSecurity.password_L9[...]` / `password_MM[...]`) — a multi-line
> case — are not covered yet: only the `SecurityDisabled` flag is.

## VMCT actions on `mission.yaml` (wave 4)

The fourth family — the first genuinely **VMCT** one: edit the **declarative source**
`mission.yaml` (what the build consumes to *generate* the `.miz`), rather than patching a built
artifact. Shared brick: `mission_tools.mission_yaml_editor` (`ruamel.yaml` round-trip mode)
which **preserves comments, key order and formatting** — essential for a heavily-commented source
file edited by hand and kept in lockstep with the shipped default. Timestamped backup before
every write.

### `describe_mission_config`

Read-only. Lists the `modules:` block and, per module, its state: `mandatory` (bare key),
`scalar` (boolean `MODULE: true/false`) or `extended` (nested config block such as
`COMBATZONE`/`CTLD`). The VMCT counterpart of `describe_mission`.

```json
{"mission_yaml_path": "path/to/mission.yaml"}
```

### `set_mission_module`

Write. Enable/disable a module or set its extended config block, comments preserved. `value` is
either a boolean (scalar form) or an object (extended block). The key is **replaced if present,
inserted otherwise**. No deduplication.

```json
{
  "mission_yaml_path": "path/to/mission.yaml",
  "module_id": "COMBATZONE",
  "value": {"enabled": true, "combat_zones": [{"type": "zone", "zone_name": "CZ-Alpha"}]}
}
```

> Deliberately **generic** (toggle + mapping setter) — no per-module schema validator: the shape
> of the config block passed stays the caller's (LLM's) responsibility, like unit types for
> `add_group`.

## Domain-knowledge oracle (wave 5)

The actions above are the LLM's **hands** (writes) and **eyes** (`describe_*`). Wave 5 gives it a
**brain**: **read-only** actions exposing the DCS + VEAF knowledge needed to author correctly. All
read from the **canonical sources** the build already uses, so they **cannot drift**:

- generated DCS data (`update-dcs-data` → `veaf_libs/data/dcsUnits.yaml`, published on the VEAF
  GitHub);
- VEAF aliases (`veaf_libs/data/veaf-units.yaml`);
- vendored artifacts (`vendored.yaml`, `check-vendored`);
- upstream datamining repos (provenance).

Implementation: `veaf_mission_mcp/oracle.py`. The "prose / how to reason" half lives in the
`veaf-mission-authoring` Claude skill (`plugin/skills/veaf-mission-authoring/SKILL.md`, bundled by
`bfr-claude-plugins`) — the plugin = MCP hands + skill brain.

### `list_unit_types`

Read-only. DCS unit types from the generated database, filterable by `category` and/or
`name_contains`, so the LLM can pick concrete types.

```json
{"category": "Plane", "name_contains": "su-27"}
```

### `list_shortcuts`

Read-only. The VEAF alias vocabulary (`shilka`, `sa8`…) — unit aliases (`_spawn unit <alias>`)
and composite group aliases (`_spawn group <alias>`: SAM sites, convoys). Filterable by
`name_contains`.

### `describe_naming_conventions`

Read-only. The **8 reserved naming patterns** (combat-zone membership, `veafSpawn-`/`OnDemand-`
prefixes, `#veafInterpreter[…]`/`#command=` markers, QRA deploy entries, fixed CAS names…), each
with its rule and the consuming module. Check a proposed name against these before `add_group`.

### `describe_module`

Read-only. A **locator** (not a schema validator): confirms a VEAF module exists (via the
canonical `lua_module_scanner` list), returns its doc page, and — when `mission_yaml_path` is
given — its enabled state. Each module's config keys live in its doc page.

```json
{"module_id": "QRA", "mission_yaml_path": "path/to/mission.yaml"}
```

## Next waves (out of scope)

- Non-circular (quad/polygon) trigger zones — wave 2 covers circular zones only.
- A generic SI/ALORS trigger editor (arbitrary DCS conditions/actions) — wave 2 is limited to
  startup script-loading / Lua-execution triggers.
- A per-module schema validator for `set_mission_module` (wave 4 stays generic).
- Convention-aware `add_group` (wave 6), target symmetry (wave 7), composite
  `create_combat_zone`/`create_qra`/`create_cap_mission` actions (wave 8).

See `.backlog/FEAT-MCP-MISSION-EDITOR/PRD.md` for details.
