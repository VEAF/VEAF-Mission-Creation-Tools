# FEAT-MCP-MISSION-EDITOR-021 — Wave-6 documentation

Status: ⬜ ready
Type: docs
Files: `doc/developer/mission-editing-mcp.md` (FR/EN), `doc/mission-maker/AI_ASSISTANT_CATALOG.md` (FR/EN), `CHANGELOG.md`, `pyproject.toml`

## What to build

- Developer doc (FR/EN): document the `add_group` naming intents (`for_combat_zone`,
  `late_activation`, `as_spawn_template`) and the `validate_group_name` action.
- Mission-maker catalogue (FR/EN): reflect that the AI now names groups itself from intent, and
  add `validate_group_name` to the index + a section.
- Update the `veaf-mission-authoring` skill if the guidance shifts.
- CHANGELOG entry; PATCH version bump.

## Acceptance criteria

- [ ] Both language docs describe the intents and validation consistently.
- [ ] Catalogue updated; anchors resolve.
- [ ] CHANGELOG + version bump landed.

## Blocked by

FEAT-MCP-MISSION-EDITOR-019 / 020.
