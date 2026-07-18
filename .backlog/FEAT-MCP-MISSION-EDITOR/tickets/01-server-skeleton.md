# FEAT-MCP-MISSION-EDITOR-001 — MCP server skeleton

Status: ✅ done
Type: feat
Files: `pyproject.toml`, `src/python/veaf-tools/veaf_mission_mcp/`, `test/python/`

## What to build

A new `veaf_mission_mcp` package exposing an MCP server with the same action-discovery
shape as the existing `dcs-bridge` MCP tool (for cross-tool consistency, no protocol reuse
required):

- `capabilities` — static info (server name/version).
- `list_catalog` — enumerate registered actions (initially empty; populated by later
  tickets in this lot).
- `describe_action(name)` — parameters/schema for one action.
- `run_action(name, params)` — dispatch to the registered handler.

Add the MCP SDK dependency to `pyproject.toml` under `[tool.poetry.dependencies]`, and a
new `[tool.poetry.scripts]` entry (e.g. `veaf-mission-mcp = "veaf_mission_mcp.server:main"`).

## Acceptance criteria

- [ ] `poetry run veaf-mission-mcp` starts the server.
- [ ] `list_catalog` returns an empty list before any action is registered.
- [ ] `describe_action`/`run_action` on an unknown name return a clear error, not a crash.
- [ ] TDD; ruff + mypy clean (new package must not be added to the mypy `ignore_errors`
      exclusion list — see the Quality Ratchet Policy in `CLAUDE.md`).
