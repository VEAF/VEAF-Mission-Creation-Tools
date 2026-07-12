# FEAT-MCP-MISSION-EDITOR-004 — Write action `add_group`

Status: ⬜ ready
Type: feat
Files: `mission_builder/coalition_placeholder.py` (or extracted), `src/python/veaf-tools/veaf_mission_mcp/`, `test/python/`

## What to build

Generalize the group-insertion logic already proven in `ensure_coalitions_populated` /
`_find_or_add_country` / `_max_ids` (`mission_builder/coalition_placeholder.py`,
`mission_builder_worker.py`) into a small, reusable public function —
`add_group(mission: DcsMission, coalition, country, group_definition) -> group_id` — and
expose it as the MCP action `add_group`, accepting:

- coalition + country
- a unit list (`{type, count}` per `FEAT-MCP-MISSION-EDITOR` scope decision — the MCP does
  not curate unit types, the caller already decided them)
- a route (waypoints — must support a patrol pattern, the motivating use case)
- position (or the units' individual positions)

Allocates fresh `groupId`/`unitId` (reusing `_max_ids`), deep-copies/builds the group
structure, appends it under the right `country["vehicle"]["group"]` (or the relevant
category), and calls `write_miz` through the `FEAT-MCP-MISSION-EDITOR-002` backup helper.
No deduplication: calling this twice with identical parameters creates two distinct groups
— the tool mirrors the Mission Editor, it doesn't second-guess the caller.

## Acceptance criteria

- [ ] Adds a ground group with units + a patrol route to a real test `.miz`, and DCS/the
      Mission Editor would open the result without complaint (validated at minimum via
      `luadata` round-trip + `mission_content` shape checks; a manual DCS open is a bonus,
      not a gate).
- [ ] Fresh `groupId`/`unitId` never collide with existing ones, including on a mission
      already containing gaps (sparse ids).
- [ ] Backup helper (002) runs before the write, every time.
- [ ] Calling the action twice with the same input produces two groups, not one (explicit
      non-dedup test).
- [ ] TDD incl. patrol-route shape; ruff + mypy clean.

## Blocked by

FEAT-MCP-MISSION-EDITOR-001, FEAT-MCP-MISSION-EDITOR-002.
