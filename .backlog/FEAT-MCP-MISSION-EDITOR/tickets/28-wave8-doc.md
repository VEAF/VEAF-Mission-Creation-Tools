# FEAT-MCP-MISSION-EDITOR-028 — Wave-8 documentation

Status: ⬜ ready
Type: docs
Files: `doc/developer/mission-editing-mcp.md` (FR/EN), `doc/mission-maker/AI_ASSISTANT_CATALOG.md` (FR/EN), `CONTEXT.md`, `CHANGELOG.md`, `pyproject.toml`, `plugin/skills/veaf-mission-authoring/SKILL.md`

## What to build

- Developer doc (FR/EN): document folder-awareness and the composite builders
  (`create_combat_zone`, `create_qra`, `create_cap_mission`) — the "one pass, both worlds" model
  and the extract/build round-trip.
- Mission-maker catalogue (FR/EN): a new **top-of-list** theme for the one-shot builders (this is
  the headline capability — high frequency), with worked example phrases.
- CONTEXT.md glossary: a "composite action" / "one-pass builder" entry if warranted.
- Update the `veaf-mission-authoring` skill: prefer the composite when the user asks for a whole
  feature; fall back to primitives otherwise.
- CHANGELOG entry; PATCH version bump.

## Acceptance criteria

- [ ] Both language docs and the catalogue describe the composites and the both-worlds model.
- [ ] Skill updated to reach for composites first.
- [ ] CHANGELOG + version bump landed.

## Blocked by

FEAT-MCP-MISSION-EDITOR-025 / 026 / 027.
