# FEAT-MCP-MISSION-EDITOR-002 — Backup-before-write helper

Status: ✅ done
Type: feat
Files: `mission_tools/miz_tools.py` (or a new sibling module), `test/python/`

## What to build

A shared helper, called by every mutating MCP action before it writes, that copies the
target `.miz` to a timestamped sibling (e.g. `mission.miz` → `mission.20260712-143012.miz`,
same directory) before `write_miz` overwrites it. Pure safety net — no retention/cleanup
policy, no configuration; git remains the actual long-term undo.

## Acceptance criteria

- [ ] Backup file is byte-identical to the pre-write `.miz`.
- [ ] Timestamp format is sortable and collision-safe within the same second (or the helper
      errors clearly rather than silently overwriting a same-second backup).
- [ ] Backup happens even if the subsequent write fails (helper runs first, unconditionally).
- [ ] TDD; ruff + mypy clean.
