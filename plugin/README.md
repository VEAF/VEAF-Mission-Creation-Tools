# veaf-mission-editor — Claude Code plugin

This directory **is** a self-hosted Claude Code plugin (decision with David: shipped from this repo,
not vendored into `bfr-claude-plugins` — a marketplace can reference it externally). It wraps this
repo's `veaf-mission-mcp` server (the "hands/eyes") with the authoring skill (the "brain").

## What's inside

- `.claude-plugin/plugin.json` — the plugin manifest.
- `.mcp.json` — declares the `veaf-mission-editor` MCP server: runs `veaf-tools mcp` (the server
  ships inside the `veaf-tools` binary — see `FEAT-MCP-PLUGIN-001`).
- `skills/veaf-mission-authoring/` — the authoring skill (auto-discovered): naming conventions,
  combat-zone vs QRA group models, always consulting the oracle actions.

## Install

From this repository as a marketplace (the `veaf` marketplace is `.claude-plugin/marketplace.json`
at the repo root):

```
claude plugin marketplace add VEAF/VEAF-Mission-Creation-Tools
claude plugin install veaf-mission-editor@veaf
```

(Windows-first: DCS mission makers run Windows; a Unix variant can follow.)

## The `veaf-tools` binary

The MCP server is `veaf-tools mcp`, so the plugin needs the `veaf-tools` binary in its persistent
data dir (`${CLAUDE_PLUGIN_DATA}/veaf-tools.exe`). A **SessionStart bootstrap** will fetch/update it
via `veaf-tools-updater` (throttled to once per 4 h) — the same mechanism as a mission folder. That
bootstrap is **FEAT-MCP-PLUGIN-002b** (landing next); until then, drop a `veaf-tools.exe` into the
plugin's data dir manually to exercise the server end-to-end.
