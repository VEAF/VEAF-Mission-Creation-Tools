# FEAT-MCP-PLUGIN-002 — Plugin manifest + MCP wiring (+ binary delivery)

Status: ⬜ ready (delivery = (a) bootstrap-on-first-run, decided with David)
Type: feat
Files: `plugin/.claude-plugin/plugin.json`, `plugin/.mcp.json`, `plugin/skills/veaf-mission-authoring/` (existing)

## What to build

Turn `plugin/` into a valid Claude plugin:
- `plugin/.claude-plugin/plugin.json` (name `veaf-mission-editor`, description, version, author, MIT/Apache).
- A `.mcp.json` declaring the `veaf-mission-editor` MCP server, command `veaf-tools mcp`.
- Keep the existing `veaf-mission-authoring` skill under the plugin.

## Open decision — binary delivery

How does `.mcp.json` find the `veaf-tools` binary on the maker's machine?
- **(a) fetch on first run** (like the updater) into the plugin — robust, no committed binaries;
- **(b) assume `veaf-tools` on PATH** — simplest, but not how veaf-tools ships today;
- **(c) wrapper** that ensures-then-runs.

Decide with David before implementing.
