# Install the AI mission-editing assistant

> **Audience**: VEAF mission makers who want to create and edit a mission in natural language with an AI assistant (Claude, Gemini or another AI), connected to the `veaf-mission-mcp` server.

The VEAF tools hold everything the assistant needs: the MCP server that acts on your missions (the "hands"), the authoring guide that tells it how to go about it (the "brain"), the known limitations of the tools and of DCS, and the instructions to build a complete mission.
Nothing to fetch elsewhere, neither on GitHub nor in the documentation: once the tools are installed and the assistant connected, just ask it to "create a mission".
What you can ask it is listed in [AI_ASSISTANT_CATALOG.md](AI_ASSISTANT_CATALOG.en.md).

> **In five steps**
>
> 1. Choose an AI in the table [Which AI to choose?](#which-ai), OpenCode for instance.
> 2. Install it on your PC, open an account with it if it asks for one, and [choose a model in it](#which-model): the model does the work.
> 3. Start it and tell it: "install the VEAF AI tools: https://veaf.github.io/documentation/latest/en/mission-maker/AI_ASSISTANT_INSTALL/".
>    With Claude Desktop in chat mode, which runs no command, type [the five commands](#for-an-ai-assistant) in PowerShell yourself instead.
> 4. When it tells you to, quit it completely and start it again: it reads its tools only at start-up.
> 5. Tell it: "create a DCS mission".

## The demo video {#demo-video}

The five steps, done on an empty Windows PC with a free AI: the install, then a complete mission with its briefing.
Six minutes; building the mission, half an hour in reality, is sped up.

<iframe src="https://www.youtube-nocookie.com/embed/X3tJr130jSU?cc_load_policy=1&cc_lang_pref=en" title="Create a DCS World mission with a free AI" style="width:100%;aspect-ratio:4/3;border:0" allow="accelerometer; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" referrerpolicy="strict-origin-when-cross-origin" allowfullscreen loading="lazy"></iframe>

## Which AI to choose? {#which-ai}

It takes an application that can start an MCP server **on your PC**: chats in the browser (ChatGPT web, Le Chat, the Gemini app) cannot.
Free offers change often; this table dates from October 2026, and no vendor publishes its exact free quota.

| Application | Free | What it does with VMCT |
|---|---|---|
| **Claude Desktop** (chat mode) | free plan, limited quota; Anthropic does not say whether that plan takes a local server (to be checked) | the simplest to start with: it builds the mission and its briefing with the VEAF actions, but runs no program on your PC — neither the install nor an Open Training's maps and README |
| **ChatGPT Desktop, Codex tab** | included in the free plan, limited quota | everything, install included; a developer-oriented interface |
| **OpenCode** | free models offered for a limited time | everything, install included, with a [well-chosen](#which-model) model; used in a terminal |
| **Antigravity** (Google) | free, weekly quotas | everything, install included; it is a code editor |
| **Claude Code** | paid Claude subscription | everything; the tool VMCT is developed with |

**Gemini CLI** is still connected by `ai-setup`, but it no longer serves free Google accounts since June 2026: Google replaces it with Antigravity.

### Choosing the model {#which-model}

In OpenCode, Codex or Antigravity the application can run commands, but the **model** chosen in it decides whether it uses them well: understanding the instruction, picking the right tool, keeping track over twenty steps or so.
Two free models of the same OpenCode, with the same tools, gave one a successful install in three minutes and the other nothing after seven.
Nothing in a model's description says which will succeed; three rules are enough:

1. **The install is the test.** If after five minutes the AI has not run the VEAF tools' updater, it will not get there: stop it, change the model and start again.
   An AI that opens the page in a browser and scrolls through it instead of running the commands is off to a bad start.
2. **Prefer a model that does not keep your data.** OpenCode says so for each of its free models; during their free period, some are improved with what you send them.
3. **A model that managed the install usually manages the mission**: it is the same work, longer.

In our tests of October 2026, on OpenCode, **DeepSeek v4.1 Flash** (free, no data retention) installed the tools in two to three minutes and then built a complete mission; **Big Pickle**, the model offered by default, did not manage the install.
One test each, and the list of free models changes often: take it as a starting point, and rule 1 as the judge.

## For an AI assistant: installing everything {#for-an-ai-assistant}

This section is also read by the AI itself: tell it "install the VEAF tools following https://veaf.github.io/documentation/latest/en/mission-maker/AI_ASSISTANT_INSTALL/" and it does what follows.
That takes an AI that can run commands on your PC, such as Codex, OpenCode, Antigravity or Claude Code.
**Claude Desktop in chat mode cannot**: then type these commands yourself, in PowerShell (Start menu → "PowerShell"):

```powershell
New-Item -ItemType Directory -Force "$env:USERPROFILE\VEAF\tools" | Out-Null
Set-Location "$env:USERPROFILE\VEAF\tools"
Invoke-WebRequest https://github.com/VEAF/VEAF-Mission-Creation-Tools/releases/download/published-latest/veaf-tools-updater.exe -OutFile veaf-tools-updater.exe -UseBasicParsing
.\veaf-tools-updater.exe
.\veaf-tools.exe ai-setup
```

1. The `%USERPROFILE%\VEAF\tools` folder receives the tools: it is their permanent place, apart from your missions.
2. `veaf-tools-updater.exe` downloads the latest version and installs `veaf-tools.exe` next to it.
3. `veaf-tools.exe ai-setup` connects the server to every AI assistant installed on the PC — Claude Desktop, Claude Code, Codex, Antigravity, Gemini CLI, OpenCode — and says for each what it did.

Then **quit the AI assistant completely and start it again**: it reads its servers only at start-up.
If you type the commands yourself for Claude Desktop, quit it **before** `ai-setup`: it keeps its settings in the same file, and could write its own copy back over it.

> **Windows security**: if Windows blocks a downloaded `.exe`, right-click → **Properties** → tick **Unblock** → **OK**.

**How to tell it works**: ask the assistant "which version of veaf-tools are you using?".
It must answer with the installed version, the one `.\veaf-tools.exe about` shows.

## Using the assistant {#use}

Ask in natural language.
For a new mission, "create a mission" is enough: the assistant asks which of the two kinds you want, then loads the instructions that go with it.

- **An objective mission, played in one session**: a package, one or more objectives, a threat, a way home.
  The assistant asks for the map, the aircraft and the number of pilots, the length of the session and the kind of mission, then **proposes a scenario**.
  Ask for others as often as you like, ask your questions; nothing is written until you have approved a scenario.
  Then it builds the mission and its briefing.
- **An Open Training mission**: a VEAF training mission on a whole map — airfields, support, air defence, graded training zones, combat zones, QRA, CAP, weather.
  The assistant asks only four or five questions: the map, the era, the template, a mission to take after if any, the escorts.

It also asks where to create the mission folder, if it has none yet.
An objective mission's briefing — document, maps, DCS briefing pictures — is produced by the tools themselves, even with Claude Desktop in chat mode; an Open Training's maps and README, and the PDF, still take an AI that runs programs, and one that cannot tells you what it could not produce.
To change an existing mission, give it the path of its folder and describe what you want:

> "In my mission `Documents\VEAF\Missions\Syria`, add a long-range SAM combat zone north of Damascus."

The assistant places the elements, validates and builds the `.miz` without you leaving the conversation.

## Updates {#updates}

The server updates itself: when the assistant starts, at most once every 4 hours, it checks whether a newer version is out and then starts the updater in the background, in its folder.
The updater only downloads it: the new version waits beside the installed one, as `veaf-tools.exe.staged`, and takes over at the next start of an assistant, once no other `veaf-tools.exe` is running.
Until then every running assistant keeps working on its version: replacing the executable under a running server broke its next actions (`Error -3 while decompressing data`), and up to 6.31.1 the update did exactly that.
If you keep an assistant open for days, close them all and start one again to take the update.
To turn this off, the same setting also turns off the new-version notice in the terminal: `.\veaf-tools.exe user-config --set check_updates=false`.
You can always update by hand, by running `.\veaf-tools-updater.exe` again in the tools folder: it puts a waiting version in place too, and warns you when a `veaf-tools.exe` is running — close the assistants first.

If you move the tools folder, run `.\veaf-tools.exe ai-setup` again from its new place: the assistant starts the executable by its full path.

## Another MCP-capable AI {#other-mcp-client}

`ai-setup` knows Claude Desktop, Claude Code, Codex, Antigravity, Gemini CLI and OpenCode.
The VEAF server is a standard program: any other AI that can start a **local MCP server** can use it, once declared by hand.
All of them ask for the same two facts: the **command** (the full path of `veaf-tools.exe`) and its **arguments** (`mcp`).
Most read them from a JSON file of this shape:

```json
{
  "mcpServers": {
    "veaf-mission-editor": {
      "command": "C:\\Users\\<you>\\VEAF\\tools\\veaf-tools.exe",
      "args": ["mcp"]
    }
  }
}
```

> **The backslashes are doubled**: that is the JSON rule, a single `\` is a special character there.
> Writing the path as the file explorer shows it makes the file unreadable.

Look for "MCP" in your AI's documentation: the file name changes, the two facts stay the same.
The server asks the AI to read its authoring guide before any action, but not every AI honours that request; if yours starts guessing, open the conversation with:

> "Before anything else, read the VEAF authoring guide with the `describe_authoring_guide` action, then the known limitations with `describe_known_limitations`."

## An AI without MCP {#no-mcp}

A chat AI in the browser cannot run a program on your PC: it does not read your mission, change it or build it.
It is still useful to **understand** and **write**: explain an option, propose a `mission.yaml` block, read an error message.
So that it does not answer from memory, give it the page that is authoritative — the [`mission.yaml` reference](../MISSION_YAML_REFERENCE.en.md), the page of the script concerned — by pasting it into the conversation or giving it its address.
Then check what it proposes with `.\veaf-tools.exe validate` before building: you are the one running the tools.

## Trying a pre-release (advanced) {#pre-release}

To try a **pre-release**, install it instead of the stable version by passing its tag to the updater:

```powershell
.\veaf-tools-updater.exe --tag published-v6.9.21-rc1
```

The missions the assistant creates afterwards get the same version if the `VEAF_MCP_UPDATER_TAG` variable holds that tag when the assistant starts: `$env:VEAF_MCP_UPDATER_TAG = "published-v6.9.21-rc1"`.
As long as this variable is set, the server does not update itself: it stays on the pre-release the missions get.
