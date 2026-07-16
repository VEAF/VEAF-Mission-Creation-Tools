# FEAT-MCP-MISSION-EDITOR-020 — Group-name validation & warnings

Status: ⬜ ready
Type: feat
Files: `src/python/veaf-tools/veaf_mission_mcp/group_naming.py`, `veaf_mission_mcp/add_group.py`, `veaf_mission_mcp/actions.py`, `test/python/`

## What to build

Surface convention collisions so the calling LLM can warn/ask the user (the server itself does
not converse):

- **`validate_group_name`** action — given a proposed name (and optionally the target `.miz`),
  return the reserved-convention matches it triggers: `veafSpawn-`, `OnDemand-`,
  `VEAF-placeholder-`, `#veafInterpreter[...]`, combat-zone unit markers, and — if a `.miz` is
  given — the **combat-zone capture trap** (name starts with an existing combat-zone trigger-zone
  name → would be captured/despawned).
- **Warnings in `add_group`'s return** — `add_group` runs the same check and includes any
  `warnings` in its result (it still performs the write; the LLM relays the warning).

Encodes the same 8 conventions the wave-5 `describe_naming_conventions` reports (shared helper).

## Acceptance criteria

- [ ] `validate_group_name` flags each reserved pattern with a clear reason.
- [ ] With a `.miz`, it detects the combat-zone prefix-capture trap against real trigger zones.
- [ ] `add_group` returns non-empty `warnings` for a colliding name, and still writes.
- [ ] A clean name yields no warnings.
- [ ] TDD; ruff + mypy clean. Coverage gate per the ratchet.
- [ ] Mission-maker catalogue updated.

## Blocked by

FEAT-MCP-MISSION-EDITOR-019 (shares the naming helper).
