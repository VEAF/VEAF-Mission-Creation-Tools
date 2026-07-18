# FEAT-MCP-MISSION-EDITOR-008 — Wave-2 doc + changelog

Status: ✅ done
Type: docs
Files: `doc/developer/`, `CHANGELOG.md`, `pyproject.toml`

## What to build

- Extend `doc/developer/mission-editing-mcp.md` (+ `.en` mirror) with the wave-2 actions:
  `add_trigger_zone` and `add_startup_script_trigger` (inline / static-file / dynamic-file),
  including the vanilla/CTLD use case.
- CHANGELOG `[Unreleased]` entries for both actions.
- PATCH version bump in `pyproject.toml` + `poetry install`.

## Acceptance criteria

- [ ] Doc updated FR + EN.
- [ ] CHANGELOG + version bump done.

## Blocked by

FEAT-MCP-MISSION-EDITOR-006, FEAT-MCP-MISSION-EDITOR-007.
