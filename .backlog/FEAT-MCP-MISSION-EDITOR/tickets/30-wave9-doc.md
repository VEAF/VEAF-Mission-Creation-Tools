# FEAT-MCP-MISSION-EDITOR-030 — Wave 9 doc + catalogue + skill

Status: ⬜ ready
Type: docs
Files: `doc/developer/mission-editing-mcp.md`, `doc/developer/mission-editing-mcp.en.md`, `doc/mission-maker/AI_ASSISTANT_CATALOG.md` (+ `.en.md`), `plugin/skills/veaf-mission-authoring/SKILL.md`, `CHANGELOG.md`, `pyproject.toml`

## What to build

Document the wave-9 scaffolding action across the same surfaces every prior wave updated:

- **Developer doc** (FR + EN): a "Scaffolding (wave 9)" section describing `scaffold_mission`, the
  drive-the-real-binaries decision, the download-updater → run-updater → `prepare` sequence, the
  empty-folder guard, and the `minimal`/`standard`/`full` templates (`custom` unsupported).
- **Mission-maker catalogue** (FR + EN): a `scaffold_mission` entry presented as **step 0** of a
  from-scratch mission (before the wave-8 composites).
- **Authoring skill** (`veaf-mission-authoring`): a "step 0 — create the folder" note, and that the
  assistant must **ask the maker which template** (coverage tier) before calling `scaffold_mission`.
- **CHANGELOG** under `[Unreleased]`; **bump** `pyproject.toml` → 6.9.9.

## Acceptance criteria

- [ ] FR + EN developer doc sections in sync (parity is enforced elsewhere in the repo).
- [ ] Catalogue lists `scaffold_mission` with the step-0 framing, FR + EN.
- [ ] Skill instructs asking the template question before scaffolding.
- [ ] CHANGELOG entry; version bumped; `poetry install` run.

## Blocked by

FEAT-MCP-MISSION-EDITOR-029.
