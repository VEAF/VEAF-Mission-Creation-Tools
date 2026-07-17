# FEAT-MCP-PLUGIN-001 — `veaf-tools mcp` subcommand

Status: ✅ done
Type: feat
Files: `src/python/veaf-tools/veaf_tools/commands/mcp.py`, `veaf_tools/commands/__init__.py`, `veaf_libs/locales/{en,fr}.json`, `test/python/veaf_tools/test_mcp_command.py`

## What was built

`veaf-tools mcp` — a thin CLI command that launches `veaf_mission_mcp.server:main` on stdio, so the
MCP server ships inside the already-built `veaf-tools` binary (no separate binary to build/vendor).
Localized help (`cmd.mcp.help`). A Claude plugin's `.mcp.json` invokes this command.

## Acceptance criteria

- [x] `veaf-tools mcp` registered; delegates to the server (test with the server mocked).
- [x] FR/EN help key; i18n gate green.
- [x] ruff + mypy clean.
