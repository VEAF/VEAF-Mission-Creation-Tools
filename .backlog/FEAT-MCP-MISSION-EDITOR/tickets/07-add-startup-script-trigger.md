# FEAT-MCP-MISSION-EDITOR-007 — Write action `add_startup_script_trigger`

Status: ✅ done
Type: feat
Files: `veaf_mission_mcp/`, `mission_tools/` or `mission_builder/`, `test/python/`

## What to build

An MCP action adding a **"mission start"** trigger that runs a script — for outfitting a
**vanilla or CTLD** mission with scripting without fighting the DCS editor's Triggers tab.
Modes:

- **Inline Lua** (`DO SCRIPT`): a `lua` string executed at mission start.
- **Script file** (`DO SCRIPT FILE`): load a `.lua` file, either
  - **static** — embed the file into the `.miz` as an `l10n/DEFAULT/<name>.lua` resource, add
    its `mapResource` entry, and reference it from the action; or
  - **dynamic** — a disk path loaded at runtime (no embedding).

Generalizes the existing `inject_dcs_bridge_trigger` (which injects a trigger loading
`dcs-bridge.lua`) and the VEAF static/dynamic loading mechanism
([ADR 0004](../../docs/adr/0004-dynamic-script-loading.md)) into a reusable MCP action.
Goes through the `FEAT-MCP-MISSION-EDITOR-002` backup helper.

## Acceptance criteria

- [ ] Inline-Lua mode: a `triggerStart` trigger with a `DO SCRIPT` action carrying the Lua.
- [ ] Static-file mode: the `.lua` is embedded (`l10n/DEFAULT` + `mapResource`) and referenced
      by a `DO SCRIPT FILE` action.
- [ ] Dynamic-file mode: a runtime disk-path load, no embedding.
- [ ] trig/trigrules indices stay consistent (mirror `inject_dcs_bridge_trigger`'s shifting).
- [ ] Backup runs before the write. No dedup.
- [ ] TDD on trig/trigrules shape + resource embedding; ruff + mypy clean.

## Blocked by

FEAT-MCP-MISSION-EDITOR-002.
