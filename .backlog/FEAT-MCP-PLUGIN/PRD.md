# Lot FEAT-MCP-PLUGIN — ship veaf-mission-mcp as a self-hosted Claude plugin

Status: ✅ done (001 `veaf-tools mcp` · 002 manifest + `.mcp.json` + marketplace + SessionStart auto-update bootstrap · 003 install doc). The plugin is installable from this repo and keeps `veaf-tools` current on its own.

Branch: `feature/mcp-plugin` → PR → `feature/mcp-mission-editor`

## Context

The MCP server (`veaf_mission_mcp`, 28 actions) + the `veaf-mission-authoring` skill exist in this
repo (`plugin/skills/…`). To let a Mission Maker actually use them from Claude Code, package them as
an installable **Claude plugin**.

**Decision (with David)**: the plugin lives **in this repo**, not in `bfr-claude-plugins`. We own the
binary (our release), the skill is already here, and a marketplace (BFR's or ours) can *reference* an
external plugin via its `source` — no need to vendor into another org's repo. Delivery of the MCP
server: a **`veaf-tools mcp` subcommand** (ships inside the already-built `veaf-tools` binary — no
separate binary to build), which the plugin's `.mcp.json` invokes.

## Tickets

| # | Ticket | Type | Status |
|---|--------|------|--------|
| FEAT-MCP-PLUGIN-001 | **`veaf-tools mcp` subcommand**: thin CLI command launching `veaf_mission_mcp.server:main` on stdio, so the MCP server ships inside the veaf-tools binary. Localized help; test asserts it delegates to the server. | feat | ✅ |
| FEAT-MCP-PLUGIN-002 | **Plugin manifest + MCP wiring + binary bootstrap**: `plugin/.claude-plugin/plugin.json` + `.mcp.json` (server `veaf-mission-editor` → `veaf-tools mcp`) + the skill + `.claude-plugin/marketplace.json`. **Binary delivery** = a `SessionStart` hook running `scripts/bootstrap.ps1` (Windows): first launch installs `veaf-tools` synchronously via `veaf-tools-updater`; later launches refresh it detached, throttled ≤ once per 4 h (deferred replacement when the exe is locked). Tag-configurable via `VEAF_MCP_UPDATER_TAG` (default `published-latest`; set a `published-v*-rc*` tag to test a pre-release). Same updater mechanism as a mission folder, no new one. | feat | ✅ |
| FEAT-MCP-PLUGIN-003 | **Install doc + marketplace**: `doc/mission-maker/AI_ASSISTANT_INSTALL.md` (FR + EN) — how a maker installs the plugin (`claude plugin marketplace add VEAF/VEAF-Mission-Creation-Tools` + `install veaf-mission-editor@veaf`), first-launch auto-install, updating, testing a pre-release via `VEAF_MCP_UPDATER_TAG`. Indexed in the mission-maker README. `plugin.json` bumped to 0.2.0 so an already-installed plugin actually picks up the new bootstrap on update. | docs | ✅ |

## Out of Scope

- Contributing the plugin into `bfr-claude-plugins` (they can reference it externally instead).
- Building a separate `veaf-mission-mcp` binary (the `veaf-tools mcp` subcommand reuses the shipped one).

## Binary delivery + updates (decided)

We do **not** commit binaries (à la dcs-mission-tools) nor invent a new update mechanism. We reuse
**`veaf-tools-updater[.exe]`** — the same tool that manages veaf-tools inside a mission folder:

- The plugin bootstrap fetches the fixed-name updater asset from the release and runs it (exactly
  as `scaffold_mission` does), which installs `veaf-tools` into the plugin dir and, on each run,
  version-checks `published-latest` and updates if newer.
- Cadence: run at first launch, then **throttled to at most once per 4 h** (a small on-disk
  timestamp guard) — avoids a GitHub check on every MCP start while staying current.
- This is a **separate copy** from any per-mission-folder veaf-tools (different purpose); both are
  updater-managed, no conflict.

(Rejected: committing per-OS binaries; assuming `veaf-tools` on PATH; a plugin-version-pinned fetch
— overkill, the updater already does install + update.)
