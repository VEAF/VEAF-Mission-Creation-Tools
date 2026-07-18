# FEAT-MCP-MISSION-EDITOR-038 — Wave 12 doc + catalogue + skill

Status: ✅ done
Type: docs
Files: `doc/developer/mission-editing-mcp.md` (+ `.en.md`), `doc/mission-maker/AI_ASSISTANT_CATALOG.md` (+ `.en.md`), `plugin/skills/veaf-mission-authoring/SKILL.md`, `CHANGELOG.md`, `pyproject.toml`

## What to build

- **Developer doc** (FR + EN): note that an `add_group`/composite unit can carry an explicit `name`,
  and that this is how the combat-zone `#command`/`#spawn*` markers are set (they live in the unit
  name). Worked `create_combat_zone` example with a `#command="-armor ..."` fake unit.
- **Catalogue** (FR + EN): mention the `#command` fake-unit idiom is now buildable.
- **Skill**: reinforce reaching for the `#command` fake-unit pattern for combat zones now that the
  action supports it (unit `name`).
- **CHANGELOG**; version bump.

## Blocked by

FEAT-MCP-MISSION-EDITOR-037.
