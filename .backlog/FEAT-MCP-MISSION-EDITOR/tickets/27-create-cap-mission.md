# FEAT-MCP-MISSION-EDITOR-027 — `create_cap_mission` (one pass, both worlds)

Status: ✅ done
Type: feat
Files: `src/python/veaf-tools/veaf_mission_mcp/composites.py`, `veaf_mission_mcp/actions.py`, `test/python/`

## What to build

A single action laying down an on-demand CAP mission across both worlds:

1. **Template group** (`add_group` with `late_activation=True`, name `OnDemand-<missionName>`
   — the `as_cap_template` intent or explicit prefix) — the CAP template DCS activates on demand.
2. **`mission.yaml` config** — a `cap_missions:` / `combat_missions:` entry referencing
   `<missionName>` (the build resolves it to the `OnDemand-` group via `group_validation`'s
   `ONDEMAND_CAP_PREFIX`).

Confirm the exact `mission.yaml` shape (`cap_missions:` vs `combat_missions:`) against
`MISSION_YAML_REFERENCE` / `group_validation.py` during implementation.

## Acceptance criteria

- [x] One call produces: the `OnDemand-<name>` Late-Activation template group and the matching
      `cap_missions`/`combat_missions` yaml entry.
- [x] The yaml reference resolves to the `OnDemand-`-prefixed group (matches `group_validation`).
- [x] TDD against a real mission folder fixture; ruff + mypy clean.
- [x] Mission-maker catalogue updated.

## Blocked by

FEAT-MCP-MISSION-EDITOR-024.
