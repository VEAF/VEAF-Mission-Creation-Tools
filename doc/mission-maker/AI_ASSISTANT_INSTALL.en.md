# Install the AI mission-editing assistant

> **Audience**: VEAF mission makers who want to create and edit a mission in natural language
> through an AI assistant (Claude, Gemini or another AI) wired to the `veaf-mission-mcp` server.

The **veaf-mission-editor** plugin gives your assistant the VEAF tools (the MCP server — the "hands")
and the authoring know-how (the skill — the "brain"). Once installed, you ask for a mission in
plain language and the assistant runs it end to end: create → edit → validate → build. See
[AI_ASSISTANT_CATALOG.en.md](AI_ASSISTANT_CATALOG.en.md) for what you can ask.

The know-how is the same whatever the AI — one instruction file, not a copy per assistant.
Pick the row that matches yours:

| Your AI | What it can do | Section |
|---|---|---|
| **Claude Code** (in a terminal, or the **Code** tab of the Claude app) | everything, and it installs `veaf-tools` by itself | [Install with Claude Code](#install-claude-code) |
| **Gemini CLI** | everything, once `veaf-tools` is installed | [Install with Gemini CLI](#install-gemini-cli) |
| Another AI that can start an **MCP server** on your PC (Claude Desktop in chat mode, code editors with an assistant…) | everything, once wired by hand | [Another MCP-capable AI](#other-mcp-client) |
| A chat AI in the browser (ChatGPT, Le Chat, Gemini web…) | advise, not act on your files | [An AI without MCP](#no-mcp) |

## Requirements

- **Claude Code**, **Gemini CLI** or another MCP-capable AI installed.
- **Windows** (the plugin is Windows-first; DCS mission makers run Windows).

## Install with Claude Code {#install-claude-code}

In a terminal — or via the `/plugin …` slash commands inside Claude Code:

```powershell
git config --global core.longpaths true   # Windows: allow long paths when the marketplace is cloned
claude plugin marketplace add VEAF/VEAF-Mission-Creation-Tools
claude plugin install veaf-mission-editor@veaf
```

Then **restart Claude Code**. (Public repo: no authentication needed.)

> **Windows:** the first line avoids a "Filename too long" clone failure (the 260-char limit). If
> `add` already failed for that reason, delete the partial clone under
> `~/.claude/plugins/marketplaces/` and retry. On a fresh machine that refuses the SSH host key,
> force HTTPS: `git config --global url."https://github.com/".insteadOf "git@github.com:"`.

## Install with Gemini CLI {#install-gemini-cli}

Gemini installs an extension from a folder on your disk, and it expects to find the extension file at
the root of that folder — ours lives in the `plugin` subfolder. Hence: clone first, install second:

```powershell
git clone https://github.com/VEAF/VEAF-Mission-Creation-Tools.git
gemini extensions install VEAF-Mission-Creation-Tools/plugin
```

Then **restart Gemini CLI**: extensions are only picked up when a new session starts.

Gemini copies the extension **into your home folder**, under
`%USERPROFILE%\.gemini\extensions\veaf-mission-editor\`. Nothing is written anywhere else. To remove
it:

```powershell
gemini extensions uninstall veaf-mission-editor
```

> **One difference worth knowing**: with Claude Code, the `veaf-tools` tool installs and updates
> itself (see the next section). **With Gemini it does not**: `veaf-tools` must already be installed on
> your machine and reachable from a terminal — run `veaf-tools --help` to check. If the command is not
> recognised, install the VEAF tools before using the assistant.

## Another MCP-capable AI {#other-mcp-client}

The VEAF server is a standard program: any AI that can start a **local MCP server** can use it.
The plugin, however, exists only for Claude Code and Gemini CLI, so two things are done by hand: installing `veaf-tools`, and declaring the server.

**1. Install `veaf-tools`.**
Follow [step 0 of the tutorial](TUTORIAL.en.md#step-0-install) in a folder that will not move, for instance `C:\VEAF\tools` — the step talks about a mission folder; here it is the tools folder, apart from your missions.
Write down the full path of `veaf-tools.exe`: the AI starts it by itself, not from a terminal opened in that folder.
This `veaf-tools.exe` is the server; every mission the AI then creates gets its own tools in its own folder, as in the tutorial.
Run `veaf-tools-updater.exe` in `C:\VEAF\tools` now and then: with Claude Code the plugin does it for you; here, nobody does.

**2. Declare the server.**
All these AIs ask for the same two pieces of information: the **command** (the path of `veaf-tools.exe`) and its **arguments** (`mcp`).
Most read them from a JSON file of this shape:

```json
{
  "mcpServers": {
    "veaf-mission-editor": {
      "command": "C:\\VEAF\\tools\\veaf-tools.exe",
      "args": ["mcp"]
    }
  }
}
```

> **The backslashes are doubled**: that is the JSON rule, a single `\` is a special character there.
> Writing `C:\VEAF\tools\veaf-tools.exe` as is makes the file unreadable.

With **Claude Desktop** (the Claude app, in chat mode): **Settings** → **Developer** → **Edit Config**.
The file that opens is `%APPDATA%\Claude\claude_desktop_config.json`; add the `mcpServers` block above — if it already holds other settings, keep them and add only the key — then **quit the app completely** and start it again.
For another AI, look up "MCP" in its documentation: the file name changes, the two pieces of information stay the same.

**3. Give it the know-how.**
That is what the plugin brings and what is missing here: the naming conventions, the order of work, what to check rather than guess.
Without them, the AI builds missions that look right and do not work in DCS, with no visible error.
The server serves them itself — the `describe_authoring_guide` action returns the same text as the plugin — and asks the AI to read them first.
Not every AI honours that request, so start every conversation with:

> "Before anything else, read the VEAF authoring guide with the `describe_authoring_guide` action, then the known limitations with `describe_known_limitations`."

**How to tell it works**: ask "which version of veaf-tools are you using?".
The AI must answer with the installed version, the one `.\veaf-tools.exe about` prints.

## An AI without MCP {#no-mcp}

A chat AI in the browser cannot start a program on your PC: it does not read your mission, change it, or build it.
It is still useful to **understand** and **write**: explain an option, suggest a `mission.yaml` block, read an error message.
So that it does not answer from memory, give it the page that is authoritative — the [`mission.yaml` reference](../MISSION_YAML_REFERENCE.en.md), the page of the script concerned — by pasting it into the conversation or giving it its address.
Then check what it suggests with `.\veaf-tools.exe validate` before building: you are the one running the tools.

## First launch (Claude Code)

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

### A complete Open Training mission

For a whole VEAF training mission — airbases, support, air defense, graded training ranges, combat
zones, QRA, CAP, weather — paste the prompt
[`.prompts/new-open-training-mission.en.md`](../../.prompts/new-open-training-mission.en.md) at the
start of the session, in an empty folder (French version:
[`new-open-training-mission.fr.md`](../../.prompts/new-open-training-mission.fr.md)). It sets the
design rules (which bases, how many zones, what air defense for the size of the front) and asks only
four or five questions: the map, the era, the template, a mission to draw on if any, the escorts. The
assistant answers in English, but writes the mission in French, the VEAF servers' language, unless you
ask otherwise.

### An objective mission, played in one session

For a mission a group flies once — a package, one or more objectives, a threat, a way home — paste
the prompt [`.prompts/new-objective-mission.en.md`](../../.prompts/new-objective-mission.en.md) in an
empty folder (French version:
[`new-objective-mission.fr.md`](../../.prompts/new-objective-mission.fr.md)). It asks for the map,
the aircraft and number of pilots (named or dynamic slots), the session length and the kind of mission, then **proposes a
scenario**: ask for as many others as you want, ask your questions, have the briefing shown in the
conversation. Nothing is written until you approve a scenario; the assistant then builds the mission
and its briefing as PPTX (to import as Google Slides) and/or PDF, in the VEAF briefing format.

## Update the plugin

When a new plugin version ships, with Claude Code:

```powershell
claude plugin marketplace update veaf
claude plugin update veaf-mission-editor@veaf
```

(Updating `veaf-tools` itself is **automatic** and independent of the plugin update.)

With Gemini CLI, update the clone then the extension:

```powershell
git -C VEAF-Mission-Creation-Tools pull
gemini extensions update veaf-mission-editor
```

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

On the Gemini CLI side:

```powershell
gemini extensions list                            # installed extensions
gemini extensions uninstall veaf-mission-editor   # remove the extension
```
