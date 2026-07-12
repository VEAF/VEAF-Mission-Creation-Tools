# `veaf-mission-mcp` — LLM-assisted mission-editing MCP server

> **Audience**: developers evolving the mission-editing MCP server, or wiring an MCP client
> (Claude Code, an agent) to it.
>
> 🇫🇷 [`mission-editing-mcp.md`](mission-editing-mcp.md).

## Why this server

First phase of **NL-MISSION-GEN** (see `ROADMAP.md` §4): let an LLM edit a DCS mission on a
Mission Maker's behalf — and, eventually, generate one end-to-end from a detailed prompt. See
[ADR 0013](../adr/0013-mission-editor-mcp-editor-parity-layer.md) for the architecture decision,
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

## Next waves (out of scope for v1)

- Zone and trigger/trigrule editor-parity actions.
- Any VMCT action (e.g. writing a `modules.COMBATZONE` entry into `mission.yaml`).
- Unit-type catalog/curation.
- Composite actions (e.g. a single `create_combat_zone` call).

See `.backlog/FEAT-MCP-MISSION-EDITOR/PRD.md` for details.
