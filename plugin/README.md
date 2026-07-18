# veaf-mission-editor — Claude Code plugin

This directory **is** a self-hosted Claude Code plugin (decision with David: shipped from this repo,
not vendored into `bfr-claude-plugins` — a marketplace can reference it externally). It wraps this
repo's `veaf-mission-mcp` server (the "hands/eyes") with the authoring skill (the "brain").

## What's inside

- `.claude-plugin/plugin.json` — the plugin manifest, incl. the `SessionStart` bootstrap hook.
- `.mcp.json` — declares the `veaf-mission-editor` MCP server: runs `veaf-tools mcp` (the server
  ships inside the `veaf-tools` binary — see `FEAT-MCP-PLUGIN-001`).
- `scripts/bootstrap.ps1` — installs/refreshes the `veaf-tools` binary (see below).
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

## The `veaf-tools` binary (auto-installed)

The MCP server is `veaf-tools mcp`, so the plugin needs the `veaf-tools` binary in its persistent
data dir (`${CLAUDE_PLUGIN_DATA}/veaf-tools.exe`). The **`SessionStart` bootstrap** (`scripts/bootstrap.ps1`,
Windows) handles this — no manual copy:

- **First launch** (no binary yet): downloads `veaf-tools-updater` and runs it synchronously so the
  binary exists. The MCP may be unavailable on that very first session while it installs; it is ready
  on the next one.
- **Later launches**: throttled to once per 4 h; when due, runs the updater **detached** in the
  background. It version-checks the release and replaces `veaf-tools.exe` — deferred if the current
  session still holds it locked, so the refresh takes effect on the **next** session (a running exe
  cannot replace itself).

By default it tracks `published-latest` (the stable production pointer). **Test-only:** to try a
**pre-release**, set the environment variable `VEAF_MCP_UPDATER_TAG` before launching Claude, e.g.
`VEAF_MCP_UPDATER_TAG=published-v6.9.21-rc1` — the bootstrap (and `scaffold_mission`) then install
that tag instead. Not needed once the tools ship to `published-latest`.

Bootstrap failures are non-fatal: the hook exits 0 so a network hiccup never blocks the session.

(Windows-first: DCS mission makers run Windows. A Unix `bootstrap.sh` variant can follow; on non-Windows
the hook simply no-ops if PowerShell is absent.)
