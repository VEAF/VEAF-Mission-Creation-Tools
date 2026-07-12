# FEAT-MCP-MISSION-EDITOR-005 — End-to-end scenario + doc

Status: ✅ done
Type: test+docs
Files: `test/python/`, `doc/developer/`

## What to build

- An integration test driving the full v1 catalog against a real test `.miz`:
  `describe_mission` → `add_group` (two ground sections with a patrol route) →
  `describe_mission` again to confirm the new groups are visible and the backup file
  exists.
- A `doc/developer/` page (`.en` mirror) documenting the v1 action catalog
  (`describe_mission`, `add_group`), the editor-parity/VMCT-action split (link
  [ADR 0013](../../docs/adr/0013-mission-editor-mcp-editor-parity-layer.md) and the
  `CONTEXT.md` glossary entries), and how to run the server locally.

## Acceptance criteria

- [x] Integration test passes against a real (not mocked) test `.miz`.
- [x] Doc page merged, FR + EN, linked from the developer doc index.

## Blocked by

FEAT-MCP-MISSION-EDITOR-003, FEAT-MCP-MISSION-EDITOR-004.
