# FEAT-MCP-MISSION-EDITOR-023 — Wave-7 documentation

Status: ✅ done
Type: docs
Files: `doc/developer/mission-editing-mcp.md` (FR/EN), `doc/mission-maker/AI_ASSISTANT_CATALOG.md` (FR/EN), `CHANGELOG.md`, `pyproject.toml`

## What to build

- Developer doc (FR/EN): document the source-side config setters and note the recipe/built
  parity (which setting maps to which `mission.yaml` key vs `veaf-config.lua` line).
- Mission-maker catalogue (FR/EN): the "Modules & settings" theme now has a **recipe** counterpart
  for log level / security / arbitrary setting; update the index + sections.
- CHANGELOG entry; PATCH version bump.

## Acceptance criteria

- [x] Both language docs describe the source-side setters and the parity (recipe/built table).
- [x] Catalogue updated (in 022); anchors resolve.
- [x] CHANGELOG + version bump (6.9.7) landed.

## Blocked by

FEAT-MCP-MISSION-EDITOR-022.
