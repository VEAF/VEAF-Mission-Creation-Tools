# `veaf-mission-mcp` — LLM-assisted mission-editing MCP server

> **Audience**: developers evolving the mission-editing MCP server, or wiring an MCP client
> (Claude Code, an agent) to it.
>
> 🇫🇷 [`mission-editing-mcp.md`](mission-editing-mcp.md).

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
  (`inject_presets`, `aircraft_groups`...). Out of scope for this server, unchanged.

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

## Next waves (out of scope)

- Non-circular (quad/polygon) trigger zones — wave 2 covers circular zones only.
- A generic SI/ALORS trigger editor (arbitrary DCS conditions/actions) — wave 2 is limited to
  startup script-loading / Lua-execution triggers.
- Any VMCT action (e.g. writing a `modules.COMBATZONE` entry into `mission.yaml`).
- Unit-type catalog/curation.
- Composite actions (e.g. a single `create_combat_zone` call).

See `.backlog/FEAT-MCP-MISSION-EDITOR/PRD.md` for details.
