# FEAT-BLANK-MISSION-THEATRE-003 — `scaffold_mission(theatre=...)`

Status: ✅ done
Type: feat
Files: `src/python/veaf-tools/veaf_mission_mcp/scaffold.py`, `veaf_mission_mcp/actions.py`, `test/python/veaf_mission_mcp/test_scaffold.py`

## What to build

Add an optional `theatre` parameter to `scaffold_mission`, forwarded to the `prepare` subprocess as
`--theatre <name>`. When omitted, behaviour is unchanged (empty `src/mission/`, the maker supplies
their own `.miz`). Expose `theatre` in the action's parameter schema (optional).

So a from-scratch flow becomes: the LLM asks the maker for the **theatre** (and template), calls
`scaffold_mission(target_folder, template, theatre)`, and gets a folder that already builds and
accepts the composites.

## Acceptance criteria

- [ ] `theatre` given → `prepare` subprocess receives `--theatre <name>` (asserted in the mocked run).
- [ ] `theatre` omitted → no `--theatre` flag; existing tests still pass unchanged.
- [ ] Schema advertises `theatre` as optional; ruff + mypy clean.

## Blocked by

FEAT-BLANK-MISSION-THEATRE-002, and wave-9 `scaffold_mission` (FEAT-MCP-MISSION-EDITOR-029) merged.
