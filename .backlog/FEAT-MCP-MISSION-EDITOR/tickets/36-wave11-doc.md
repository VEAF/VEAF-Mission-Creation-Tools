# FEAT-MCP-MISSION-EDITOR-036 — Wave 11 doc + catalogue + skill

Status: ✅ done
Type: docs
Files: `doc/developer/mission-editing-mcp.md` (+ `.en.md`), `doc/mission-maker/AI_ASSISTANT_CATALOG.md` (+ `.en.md`), `plugin/skills/veaf-mission-authoring/SKILL.md`, `CHANGELOG.md`, `pyproject.toml`

## What to build

- **Developer doc** (FR + EN): a "Build & validate (wave 11)" section — `validate_mission`,
  `build_mission`, and the full create→edit→**validate→build**→play loop.
- **Mission-maker catalogue** (FR + EN): entries for validating and building a mission.
- **Skill**: validate before building; build to produce the playable `.miz`; surface build errors.
- **CHANGELOG**; version bump.

## Acceptance criteria

- [ ] FR + EN docs in sync.
- [ ] Skill guides validate-then-build.
- [ ] CHANGELOG entry; version bumped.

## Blocked by

FEAT-MCP-MISSION-EDITOR-035.
