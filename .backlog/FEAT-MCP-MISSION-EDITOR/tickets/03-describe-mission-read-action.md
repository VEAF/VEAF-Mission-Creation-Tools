# FEAT-MCP-MISSION-EDITOR-003 — Read action `describe_mission`

Status: ⬜ ready
Type: feat
Files: `src/python/veaf-tools/veaf_mission_mcp/`, `test/python/`

## What to build

An MCP action `describe_mission(miz_path)` that wraps the existing `export`/
`mission_exporter.py` JSON contract (no new parsing — `FEAT-EXPORT-BFR-PARSER` already
solved this) to return, at minimum, groups (name, coalition, country, category) and
trigger-zone names/positions from the mission's current `.miz`. Gives the calling LLM
situational awareness before it runs a write action — mirroring how a human checks the
Mission Editor's outliner before adding something.

## Acceptance criteria

- [ ] Reuses `mission_exporter.py` output; does not re-implement Lua/JSON parsing.
- [ ] Returns groups and trigger zones at minimum (coalitions/countries as available from
      the export contract).
- [ ] Clear error on a `.miz` that doesn't exist or isn't a valid mission archive.
- [ ] TDD against a real test `.miz`; ruff + mypy clean.

## Blocked by

FEAT-MCP-MISSION-EDITOR-001.
