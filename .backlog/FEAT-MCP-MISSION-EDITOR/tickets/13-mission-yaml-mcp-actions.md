# FEAT-MCP-MISSION-EDITOR-013 — MCP actions on `mission.yaml`

Status: ✅ done
Type: feat
Files: `veaf_mission_mcp/edit_mission_yaml.py`, `veaf_mission_mcp/actions.py`, `test/python/`

## What to build

Two MCP actions editing the declarative **source** `mission.yaml`, both going through the
ticket-012 brick (comment-preserving, backed up first). Registered in the catalog alongside
the wave-3 `set_*` actions.

- **`describe_mission_config`** (read): return the `modules:` block and, per module, its state
  — `mandatory` (bare key), `enabled: bool` (scalar form), or the extended config mapping
  (e.g. a `COMBATZONE`/`CTLD`/`SKYNET` block). Read-only, no backup. Mirrors `describe_mission`
  but for the config source rather than the built `.miz`.
- **`set_mission_module`** (write): given a `module_id` and either
  - a boolean → set/replace the scalar `MODULE: <bool>`, or
  - a mapping → set/replace the module's **extended config block** (e.g.
    `COMBATZONE: { enabled: true, combat_zones: [...] }`),
  preserving surrounding comments. Insert the key if absent, replace if present. No dedup.

## Acceptance criteria

- [x] `describe_mission_config` reports the three module shapes (mandatory / scalar / extended)
      correctly against a representative `mission.yaml`.
- [x] `set_mission_module` scalar toggle flips only the targeted module's value, comments intact.
- [x] `set_mission_module` mapping form writes a well-formed extended block that survives a
      re-load (and would be accepted by the existing `mission_builder` YAML consumer).
- [x] Clear error for a malformed `mission.yaml` path / non-mapping `modules:` block.
- [x] Both actions registered with a JSON-Schema `ActionSpec`; `run_action` dispatches them.
- [x] TDD; ruff + mypy clean. Coverage gate bumped per the ratchet policy.

## Note

Scope is a **generic** module toggle + config-mapping setter — **not** a per-module
schema-aware validator (that stays out of scope). The LLM is responsible for the shape of the
config mapping it passes, the same way it already picks unit types for `add_group`.

## Blocked by

FEAT-MCP-MISSION-EDITOR-012 (the `mission_yaml_editor` brick).
