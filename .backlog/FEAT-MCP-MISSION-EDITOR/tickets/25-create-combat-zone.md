# FEAT-MCP-MISSION-EDITOR-025 — `create_combat_zone` (one pass, both worlds)

Status: ⬜ ready
Type: feat
Files: `src/python/veaf-tools/veaf_mission_mcp/composites.py`, `veaf_mission_mcp/actions.py`, `test/python/`

## What to build

A single high-level action that lays down a complete VEAF combat zone across both worlds, by
orchestrating the wave-1..7 primitives on a mission folder (ticket 024):

1. **Trigger zone** (`add_trigger_zone`) — the circular zone `<zone_name>`.
2. **Groups inside it** (`add_group` with `for_combat_zone=<zone_name>`) — placed geometrically
   inside the zone, names prefixed so the zone captures them; coalition-agnostic (VEAF respawns).
   The LLM supplies the `{type,count}` groups (using the wave-5 oracle for types).
3. **`mission.yaml` config** (`set_mission_module`) — a `COMBATZONE` block referencing `zone_name`.

Then (optionally) build. Not deduplicated. Returns a summary of what it created + any
`validate_group_name` warnings.

## Acceptance criteria

- [ ] One call produces: the trigger zone, ≥1 correctly-named group inside it, and the
      `modules.COMBATZONE.combat_zones[]` entry — verifiable by re-reading the folder.
- [ ] Group names satisfy the combat-zone membership rule (zone-name prefix).
- [ ] Idempotency/dedup: documented (calling twice = two zones), matching the primitives.
- [ ] TDD against a real mission folder fixture; ruff + mypy clean.
- [ ] Mission-maker catalogue updated (living-doc rule).

## Blocked by

FEAT-MCP-MISSION-EDITOR-024.
