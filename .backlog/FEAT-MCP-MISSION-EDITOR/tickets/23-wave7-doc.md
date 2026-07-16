# FEAT-MCP-MISSION-EDITOR-023 — Wave-7 documentation

Status: ⬜ ready
Type: docs
Files: `doc/developer/mission-editing-mcp.md` (FR/EN), `doc/mission-maker/AI_ASSISTANT_CATALOG.md` (FR/EN), `CHANGELOG.md`, `pyproject.toml`

## What to build

- Developer doc (FR/EN): document the source-side config setters and note the recipe/built
  parity (which setting maps to which `mission.yaml` key vs `veaf-config.lua` line).
- Mission-maker catalogue (FR/EN): the "Modules & settings" theme now has a **recipe** counterpart
  for log level / security / arbitrary setting; update the index + sections.
- CHANGELOG entry; PATCH version bump.

## Acceptance criteria

- [ ] Both language docs describe the source-side setters and the parity.
- [ ] Catalogue updated; anchors resolve.
- [ ] CHANGELOG + version bump landed.

## Blocked by

FEAT-MCP-MISSION-EDITOR-022.
