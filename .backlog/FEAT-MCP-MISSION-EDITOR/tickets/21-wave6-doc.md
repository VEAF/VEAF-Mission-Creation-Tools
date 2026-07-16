# FEAT-MCP-MISSION-EDITOR-021 — Wave-6 documentation

Status: ✅ done
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

- [x] Both language docs describe the intents and validation consistently.
- [x] Catalogue updated (in 019/020); anchors resolve.
- [x] CHANGELOG + version bump (6.9.6) landed. `veaf-mission-authoring` skill updated to point at
      the intents + `validate_group_name`.

## Blocked by

FEAT-MCP-MISSION-EDITOR-019 / 020.
