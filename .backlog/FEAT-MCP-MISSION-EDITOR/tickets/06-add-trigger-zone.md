# FEAT-MCP-MISSION-EDITOR-006 — Write action `add_trigger_zone`

Status: ✅ done
Type: feat
Files: `veaf_mission_mcp/`, `test/python/`

## What to build

An MCP action `add_trigger_zone` inserting a **circular** trigger zone into
`mission.triggers.zones`:

- Parameters: `miz_path`, `name`, `position` (`{x, y}`), `radius`, optional `hidden`
  (default false) and `color` (`[r, g, b, a]`, default a neutral translucent).
- Zone shape: `{name, x, y, radius, zoneId, type: 0, hidden, color, properties: {}}`
  (matches the DCS circular-zone shape).
- Fresh `zoneId` past the highest existing one. Handle `triggers.zones` being either a
  list or an id-keyed dict.
- Goes through the `FEAT-MCP-MISSION-EDITOR-002` backup helper. No dedup.

Unblocks the full combat-zone scenario: this trigger zone is what `group_validation`
requires for a `modules.COMBATZONE` entry, and `add_group` (v1) drops the units inside it.

## Acceptance criteria

- [ ] Adds a circular zone visible via `describe_mission` afterwards.
- [ ] Fresh `zoneId` never collides with existing ones (incl. sparse ids).
- [ ] Backup runs before the write.
- [ ] Two calls create two zones (explicit non-dedup test).
- [ ] TDD; ruff + mypy clean.
