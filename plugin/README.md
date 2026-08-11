# veaf-mission-editor — Claude Code plugin **and** Gemini CLI extension

This directory **is** a self-hosted Claude Code plugin (decision with David: shipped from this repo,
not vendored into `bfr-claude-plugins` — a marketplace can reference it externally). It wraps this
repo's `veaf-mission-mcp` server (the "hands/eyes") with the authoring skill (the "brain").

Since 6.13.89 it is **also a Gemini CLI extension**, and it is the same directory rather than a second
copy: both agents discover skills at `<root>/skills/<name>/SKILL.md`, with the same `SKILL.md` format
(YAML frontmatter carrying `name` and `description`). So two manifests sit side by side and the
authoring guidance exists **once** — which is the point, since two copies of guidance drift and the
drift is silent because nobody reads both.

## What's inside

- `.claude-plugin/plugin.json` — the **Claude Code** manifest, incl. the `SessionStart` bootstrap hook.
- `gemini-extension.json` — the **Gemini CLI** manifest. Declares the same MCP server under the same
  name, which `test_plugin_version.py` enforces: the shared `SKILL.md` refers to the server's actions,
  so a different name on one side would make the same text wrong there, silently.
- `.mcp.json` — declares the `veaf-mission-editor` MCP server: runs `veaf-tools mcp` (the server
  ships inside the `veaf-tools` binary — see `FEAT-MCP-PLUGIN-001`).
- `scripts/bootstrap.ps1` — installs/refreshes the `veaf-tools` binary (see below).
- `skills/veaf-mission-authoring/` — the authoring skill (auto-discovered): naming conventions,
  combat-zone vs QRA group models, always consulting the oracle actions.

## Install — Claude Code

From this repository as a marketplace (the `veaf` marketplace is `.claude-plugin/marketplace.json`
at the repo root):

```
claude plugin marketplace add VEAF/VEAF-Mission-Creation-Tools
claude plugin install veaf-mission-editor@veaf
```

(Windows-first: DCS mission makers run Windows; a Unix variant can follow.)

## Install — Gemini CLI

`gemini extensions install` takes a GitHub URL **or a local path**, and it expects
`gemini-extension.json` in the root of what it is given. Ours is in `plugin/`, not at the repository
root, so the install is two steps rather than one:

```
git clone https://github.com/VEAF/VEAF-Mission-Creation-Tools.git
gemini extensions install VEAF-Mission-Creation-Tools/plugin
```

Use `gemini extensions link <path>/plugin` instead if you are editing the skill — a link picks changes
up without reinstalling. Either way, **restart the CLI**: Gemini applies extension changes only on a new
session.

**Why not a one-line install from the URL.** Putting the manifest at the repository root would make it
a one-liner, but Gemini has no field to point elsewhere for skills (`name`, `version`, `description`,
`mcpServers`, `contextFileName`, `excludeTools`, … — none of them redirects the `skills/` scan). So a
root manifest would need `skills/` at the root too: either a second copy of the authoring skill, or
moving the folder out from under the Claude plugin. Both cost more than one `git clone`.

### Where the files land, and how to remove them

`gemini extensions install` copies the extension into **your home directory**, under
`~/.gemini/extensions/veaf-mission-editor/` (`%USERPROFILE%\.gemini\extensions\…` on Windows). Nothing
is written anywhere else, and nothing is written by this repository — the copy is Gemini's own doing when
you run the command. To remove it:

```
gemini extensions uninstall veaf-mission-editor
```

### The binary, which Gemini does not install for you

The MCP server is `veaf-tools mcp`, and the Gemini manifest calls plain **`veaf-tools`** — so the
binary must be on your `PATH`, which it is if you installed the VEAF tools normally. The automatic
download described below is a **Claude Code** mechanism (a `SessionStart` hook, whose format Gemini does
not share); it has not been ported, and porting it blind against hooks nobody here has exercised is how
the smoke-harness lot earned three defects.

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
