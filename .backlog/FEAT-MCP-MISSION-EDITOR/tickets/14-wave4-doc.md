# FEAT-MCP-MISSION-EDITOR-014 — Wave-4 documentation

Status: ⬜ ready
Type: docs
Files: `doc/developer/mission-editing-mcp.md`, `doc/developer/mission-editing-mcp.en.md`, `CONTEXT.md`, `CHANGELOG.md`, `pyproject.toml`

## What to build

- Extend `doc/developer/mission-editing-mcp.md` (FR) and `.en.md` (EN) with the wave-4
  actions (`describe_mission_config`, `set_mission_module`) and the **fourth action family**:
  editing the declarative source `mission.yaml` (design-time), distinct from the three
  existing families (editor-parity `.miz` tables, embedded-Lua text, built-`veaf-config.lua`).
- Update the `CONTEXT.md` glossary: `_VMCT action_` now has a concrete implementation
  (previously only the declarative CLI/config path).
- `CHANGELOG.md` entry under `[Unreleased]`.
- Bump the PATCH version in `pyproject.toml`; `poetry install`.
- Amend this lot's PRD `## Out of Scope` (VMCT actions are no longer excluded — already done
  when the wave was opened; confirm it reads correctly at close).

## Acceptance criteria

- [ ] Both language docs describe the two new actions and the four-family model consistently.
- [ ] CONTEXT.md `_VMCT action_` entry updated.
- [ ] CHANGELOG + version bump landed; markdown-lint clean.

## Blocked by

FEAT-MCP-MISSION-EDITOR-013 (documents the shipped actions).
