# Lot FEAT-MCP-PLUGIN — ship veaf-mission-mcp as a self-hosted Claude plugin

Status: 🔄 in-progress (001 done — `veaf-tools mcp` subcommand; 002/003 ready — the plugin itself + delivery, one open decision below)

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
| FEAT-MCP-PLUGIN-002 | **Plugin manifest + MCP wiring**: turn `plugin/` into a valid Claude plugin — `plugin/.claude-plugin/plugin.json` + a `.mcp.json` declaring the `veaf-mission-editor` server (`veaf-tools mcp`) + the existing `veaf-mission-authoring` skill. **Binary delivery = the existing updater**: a bootstrap downloads `veaf-tools-updater[.exe]` into the plugin dir and runs it (exactly like `scaffold_mission`), which installs `veaf-tools` and keeps it current. It runs at first launch, then **at most once per 4 h** (throttled) — same update mechanism as a mission folder, no new one. | feat | ⬜ |
| FEAT-MCP-PLUGIN-003 | **Install doc + (optional) marketplace**: how a maker installs the plugin (from this repo); optionally a `marketplace.json` so `claude plugin marketplace add VEAF/VEAF-Mission-Creation-Tools` works, and/or ask BFR to list it. CHANGELOG. | docs | ⬜ |

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
