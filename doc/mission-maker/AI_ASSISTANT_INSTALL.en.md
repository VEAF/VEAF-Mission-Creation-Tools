# Install the AI mission-editing assistant

> **Audience**: VEAF mission makers who want to create and edit a mission in natural language
> through an AI assistant (Claude Code) wired to the `veaf-mission-mcp` server.

The **veaf-mission-editor** plugin gives Claude Code the VEAF tools (the MCP server — the "hands")
and the authoring know-how (the skill — the "brain"). Once installed, you ask for a mission in
plain language and the assistant runs it end to end: create → edit → validate → build. See
[AI_ASSISTANT_CATALOG.en.md](AI_ASSISTANT_CATALOG.en.md) for what you can ask.

## Requirements

- **Claude Code** installed.
- **Windows** (the plugin is Windows-first; DCS mission makers run Windows).

## Install

In a terminal — or via the `/plugin …` slash commands inside Claude Code:

```powershell
claude plugin marketplace add VEAF/VEAF-Mission-Creation-Tools
claude plugin install veaf-mission-editor@veaf
```

Then **restart Claude Code**. (Public repo: no authentication needed.)

## First launch

On first launch the plugin **installs `veaf-tools` by itself** (via `veaf-tools-updater`) into its
data dir — nothing to copy by hand. The assistant may be **unavailable for a few seconds** while
that first install runs: if so, **restart Claude Code** once. After that, `veaf-tools` refreshes
itself automatically (at most once every 4 h).

> **Windows security**: if Windows blocks a downloaded `.exe`, right-click → **Properties** →
> tick **Unblock** → **OK**.

## Use the assistant

Open Claude Code in your mission folder (or an empty folder to start from scratch) and ask in plain
language, e.g.:

> "Create a Syria mission with a long-range SAM combat zone north of Damascus."

The assistant creates the folder, lays down a blank map for the theatre, places the elements, then
validates and builds the `.miz` — without you leaving the conversation.

## Update the plugin

When a new plugin version ships:

```powershell
claude plugin marketplace update veaf
claude plugin update veaf-mission-editor@veaf
```

(Updating `veaf-tools` itself is **automatic** and independent of the plugin update.)

## Test a pre-release (advanced)

By default the plugin tracks the **stable** version. To exercise a **pre-release**, set an
environment variable **before** launching Claude Code:

```powershell
$env:VEAF_MCP_UPDATER_TAG = "published-v6.9.21-rc1"
```

The plugin then installs that version instead of stable. Remove the variable to return to normal.

## Handy commands

```powershell
claude plugin list                                # installed plugins
claude plugin marketplace list                    # registered marketplaces
claude plugin disable veaf-mission-editor@veaf    # disable without uninstalling
```
