# Lot FIX-MCP-STDOUT-POLLUTION — the MCP server pollutes its stdio JSON-RPC stream

Status: ✅ done (PR pending → `feature/mcp-mission-editor`)

Branch: `fix/mcp-stdout-pollution` → PR → `feature/mcp-mission-editor`

## Context

Testing the plugin in a clean environment, the `veaf-mission-editor` MCP server showed up as
**connected but with no tools** (`Server "…" not found` / empty tool list; `plugin:veaf-mission-editor:veaf-mission-editor`
present but exposing nothing).

Root cause, reproduced locally: `server.main()` calls `logger.info("Starting veaf-mission-mcp …")`
**before** `mcp.run()`, and the VEAF logger prints through a Rich `Console()` whose default stream
is **stdout**. A stdio MCP server carries the JSON-RPC protocol on **stdout**, so that log line
(captured: `Starting veaf-mission-mcp v6.9.25` on stdout) corrupts the handshake — the client
connects but never negotiates any tools. (It happened to survive with some lenient clients, e.g. in
earlier Claude Code sessions, but broke under Claude Desktop — it was always fragile.)

## Change

- `veaf_libs/logger.py` — new `Logger.mute_console()`: drops the Rich console (and status line) so
  logging goes only to the log file / logging handlers (stderr), never stdout.
- `veaf_mission_mcp/server.py` — `main()` calls `logger.mute_console()` before the first log and
  `mcp.run()`, so stdout carries JSON-RPC only.
- Tests: `mute_console()` nulls the console/status and a subsequent `info()` prints nothing to the
  (recording) console. Verified end-to-end: launching the server now leaves **stdout empty** (log
  on stderr only).

## Out of Scope

- Broader logger routing (other CLI commands intentionally print to stdout via Rich); only the MCP
  server needs a silent stdout.
