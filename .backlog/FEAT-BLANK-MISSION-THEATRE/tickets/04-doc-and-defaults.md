# FEAT-BLANK-MISSION-THEATRE-004 — Doc + CHANGELOG + bump

Status: ✅ done
Type: docs
Files: `doc/mission-maker/`, `doc/developer/mission-editing-mcp.md` (+ `.en.md`), `doc/mission-maker/AI_ASSISTANT_CATALOG.md` (+ `.en.md`), `plugin/skills/veaf-mission-authoring/SKILL.md`, `CHANGELOG.md`, `pyproject.toml`

## What to build

- **Mission-maker guide / prepare doc** (FR + EN): document `prepare --theatre` / `--list-theatres`,
  and that a fresh folder no longer needs a hand-made `.miz` for the supported theatres.
- **MCP developer doc + catalogue + skill**: note that `scaffold_mission` accepts a `theatre`, and
  that the assistant should ask the maker which theatre (alongside the template) when starting from
  scratch.
- **CHANGELOG** under the current umbrella section; **bump** `pyproject.toml`.

## Acceptance criteria

- [ ] FR + EN docs in sync.
- [ ] Skill instructs asking theatre + template before scaffolding from scratch.
- [ ] CHANGELOG entry; version bumped; `poetry install` run.

## Blocked by

FEAT-BLANK-MISSION-THEATRE-001, 002, 003.
