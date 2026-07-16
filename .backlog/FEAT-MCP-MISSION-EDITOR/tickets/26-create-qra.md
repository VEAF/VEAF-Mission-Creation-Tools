# FEAT-MCP-MISSION-EDITOR-026 — `create_qra` (one pass, both worlds)

Status: ⬜ ready
Type: feat
Files: `src/python/veaf-tools/veaf_mission_mcp/composites.py`, `veaf_mission_mcp/actions.py`, `test/python/`

## What to build

A single action laying down a complete VEAF QRA across both worlds (contrast with the combat
zone: QRA groups are referenced **by exact name**, coalition **matters**, and interceptors are
**Late Activation**):

1. **Trigger zone** (`add_trigger_zone`) — the protected-airspace zone (or accept a `zone_radius`).
2. **Interceptor group(s)** (`add_group` with `late_activation=True`, the definition's coalition,
   coherent names) — the LLM picks the aircraft type (wave-5 oracle).
3. **`mission.yaml` config** (`set_mission_module` on `QRA`) — a `definitions[]` entry with
   `name`, `coalition`, `trigger_zone`, and `simple_groups` listing the interceptor group names
   **verbatim**.

## Acceptance criteria

- [ ] One call produces: the trigger zone, the Late-Activation interceptor group(s) on the right
      coalition, and the `modules.QRA.definitions[]` entry referencing the group name(s) verbatim.
- [ ] The group name in the `.miz` and the name listed in the QRA definition match exactly.
- [ ] TDD against a real mission folder fixture; ruff + mypy clean.
- [ ] Mission-maker catalogue updated.

## Blocked by

FEAT-MCP-MISSION-EDITOR-024 (and shares patterns with 025).
