# FEAT-MCP-MISSION-EDITOR-034 — Wave 10 doc + catalogue + skill

Status: ⬜ ready
Type: docs
Files: `doc/developer/mission-editing-mcp.md` (+ `.en.md`), `doc/mission-maker/AI_ASSISTANT_CATALOG.md` (+ `.en.md`), `plugin/skills/veaf-mission-authoring/SKILL.md`, `CONTEXT.md`, `CHANGELOG.md`, `pyproject.toml`

## What to build

Document wave-10 map reading + human coordinates:

- **Developer doc** (FR + EN): a "Map & coordinates (wave 10)" section — `describe_map`,
  `resolve_coordinates`, human-coordinate input on placement actions, and the design-time projection
  approach (link ADR 0015).
- **Mission-maker catalogue** (FR + EN): entries for `describe_map` / `resolve_coordinates` and a
  note that positions can be given as lat/long, not only DCS x/y.
- **Authoring skill**: guidance to prefer human coordinates and to **ask which system** the maker is
  using when they give a position.
- **CONTEXT.md**: glossary entry for theatre projection / DCS local coordinates.
- **CHANGELOG** under `[Unreleased]`; **bump** `pyproject.toml`.

## Acceptance criteria

- [ ] FR + EN developer doc + catalogue in sync.
- [ ] Skill guides the coordinate-system question.
- [ ] CONTEXT glossary entry added; CHANGELOG entry; version bumped; `poetry install` run.

## Blocked by

FEAT-MCP-MISSION-EDITOR-031, 032, 033.
