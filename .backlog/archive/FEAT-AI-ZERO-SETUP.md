# FEAT-AI-ZERO-SETUP — installing veaf-tools is all an AI needs

Status: ✅ done — merged in #1155, released in 6.31.0; David's PC set up with 6.31.1, which finds the Store install of Claude Desktop (FIX-AI-SETUP-STORE-DESKTOP, #1160). · archived 2026-11-24

Origin: David, 2026-10-20, recording a demo video in a clean Windows sandbox. The assistant there did not behave as it does on his PC, and the question was what the PC had that the sandbox did not. Goal, in his words: a very short prompt — "install the VEAF tools", then "create a mission" — and nothing the AI has to fetch from the repository or the Internet.

## What was measured on David's PC (2026-10-20)

| Finding | Measure |
|---|---|
| Two VEAF MCP servers in one session | `veaf-mission-mcp` run by `poetry` from the dev checkout answered **6.30.0**; the plugin's `veaf-mission-editor` answered **6.22.1** |
| The plugin's binary had not updated since 2026-09-12 | `published\veaf-tools.exe` held 6.30.0 (2026-10-16); `veaf-tools.exe`, the file the server runs, was dated 2026-09-12. `.last-update` is written whether the updater succeeds or not, so every session believed it updated |
| Cause | `_install_windows_binaries` moves `published\veaf-tools.exe` over `veaf-tools.exe`, which the running MCP server holds open. Overwriting a running exe: `PermissionError [WinError 5]`. **Renaming** it: allowed; the renamed file can be deleted seconds after the process exits |
| The two mission prompts are not shipped | `.prompts/new-objective-mission.*.md` and `.prompts/new-open-training-mission.*.md` exist only in the repository; the install page told the user to paste them |
| Connecting an AI is manual and different per client | plugin marketplace (clones the repository, long-path trap), `git clone` for Gemini, JSON edited by hand for Claude Desktop |

## Decisions (David, 2026-10-20)

- **The plugin and the Gemini extension are removed.** David is their only user; one install path for every client is worth breaking his.
- **`veaf-tools ai-setup`** declares the MCP server in every AI client found on the PC: Claude Desktop, Claude Code, Codex, Antigravity, Gemini CLI, OpenCode. A separate command the updater suggests at the end of a first install, so it can be re-run.
- **The server updates itself**: at start-up, at most once every 4 hours, if a newer release exists it launches the updater in the background, in its own folder. This was the plugin's `SessionStart` hook, which only Claude Code had.
- **The two mission prompts ship in the executable**, served by an action, and the authoring guide sends the AI to them when the user asks for a mission. Named *mission prompts*: *recipe* is FEAT-MISSION-RECIPES, closed.
- **The authoring guide leaves `plugin/`** for the package data, next to what serves it.
- The install page and the repository README open with a short section for an AI assistant: the commands that install everything.
- David's own PC is set up by `ai-setup` like anyone else's: the `poetry` server and the plugin are removed from his configuration.

## Tickets

- [01 — Updater: replace a running veaf-tools.exe](FEAT-AI-ZERO-SETUP.md)
- [02 — Ship the authoring guide and the mission prompts](FEAT-AI-ZERO-SETUP.md)
- [03 — `veaf-tools ai-setup`](FEAT-AI-ZERO-SETUP.md)
- [04 — The MCP server updates itself](FEAT-AI-ZERO-SETUP.md)
- [05 — Remove the plugin and the Gemini extension](FEAT-AI-ZERO-SETUP.md)
- [06 — Known limitations from the project memory](FEAT-AI-ZERO-SETUP.md)
- [07 — Documentation](FEAT-AI-ZERO-SETUP.md)
- [08 — David's PC](FEAT-AI-ZERO-SETUP.md)

## Tickets, in full

## 01 — Updater: replace a running veaf-tools.exe

Status: ✅ done

`_install_windows_binaries` moves the new `veaf-tools.exe` over the old one; when an MCP server runs it, the move fails and the install is reported failed in a window nobody sees. Rename the running file aside (`veaf-tools.exe.old`, allowed by Windows), put the new one in place, and delete leftover `.old` files on the next run.

Done: a test where the destination cannot be overwritten but can be renamed installs the new binary.

## 02 — Ship the authoring guide and the mission prompts

Status: ✅ done

Move `plugin/skills/veaf-mission-authoring/SKILL.md` and the four `.prompts/new-*-mission.{fr,en}.md` into `veaf_mission_mcp/data/`, bundled by the build. New action `describe_mission_prompt(kind, lang)`. The guide tells the AI: a user who asks for a mission gets asked which of the two kinds, then the prompt is loaded and followed.

Done: the action returns each of the four texts, from the package data; the guide names the action.

## 03 — `veaf-tools ai-setup`

Status: ✅ done

Declare `<this exe> mcp` as the `veaf-mission-editor` MCP server in every client found: Claude Desktop (`claude_desktop_config.json`, classic and Store installs), Claude Code (`claude mcp add --scope user`), Gemini CLI (`~/.gemini/settings.json`). Merge, never overwrite other settings; re-running is harmless; report what was done and that the client must be restarted. Refuses to run from a non-frozen interpreter. The updater suggests it after a first install.

Done: tests on temporary config files for each client; the TUI exclusion list updated.

## 04 — The MCP server updates itself

Status: ✅ done

At server start, in the background, at most once every 4 hours and only when update checks are enabled: if the latest release is newer than the running version, start `veaf-tools-updater.exe` detached and hidden, in the server's folder, with `VEAF_UPDATER_NO_PAUSE=1`. Never writes to stdout (the MCP channel); every failure is silent. The new version is used from the next client start.

Done: tests for the throttle, the version comparison and the launch command.

## 05 — Remove the plugin and the Gemini extension

Status: ✅ done

Delete `plugin/` and `.claude-plugin/marketplace.json`, `test_plugin_version.py`, and every reference: CI paths, release command, CLAUDE.md §9 item 5, locales, the build's bundle list.

Done: `git grep` finds no live reference to the plugin.

## 06 — Known limitations from the project memory

Status: ✅ done

Three traps lived only in an assistant's private memory on David's PC: a hole in a numbered table of `src/mission/mission` breaks the build; a slot whose module is disabled shows but cannot be taken; `veaf-tools` resolves `published/` and writes its output relative to the current directory, and `convert-v5` is not idempotent. Add them to `known-limitations.yaml` and regenerate `docs/agents/dcs-runtime-traps.md`.

## 07 — Documentation

Status: ✅ done

`AI_ASSISTANT_INSTALL` (fr/en) rewritten around the updater + `ai-setup`, opening with a section for an AI assistant; `AI_ASSISTANT_CATALOG` gains the new action; `CLI_REFERENCE` gains `ai-setup`; the repository README opens with the AI section; every page that pointed at the plugin or at `.prompts/` updated. CHANGELOG.

## 08 — David's PC

Status: ✅ done

Once a release ships `ai-setup`: remove the `poetry` `veaf-mission-mcp` server from `~/.claude.json` and uninstall the `veaf-mission-editor@veaf` plugin, then install with the updater and run `ai-setup`, as any user would.

### Done on 2026-10-20, with 6.31.0

- Installed with `veaf-tools-updater.exe` into `%USERPROFILE%\VEAF\outils`, as `AI_ASSISTANT_INSTALL.md#for-an-ai-assistant` says.
- Removed with Claude Code's own commands: the `veaf-mission-mcp` server (`claude mcp remove --scope user`), the `veaf-mission-editor@veaf` plugin and the `veaf` marketplace. The central configuration repository declared both for this machine too (`machines/DAVID-BUREAU/settings.patch.json`); removed there, or the next install would have brought them back.
- `ai-setup` run by David with Claude Desktop quit. Measured in each file afterwards:

| Client | Result |
|---|---|
| Claude Code | `veaf-mission-editor` → `C:\Users\David\VEAF\outils\veaf-tools.exe mcp`; the session's `capabilities` answers 6.31.0, and every running `veaf-tools.exe` is the installed one |
| Gemini CLI | same entry in `~/.gemini/settings.json` |
| Antigravity | same entry in `~/.gemini/config/mcp_config.json` |
| OpenCode | same entry in `~/.config/opencode/opencode.jsonc` |
| Codex | not installed |
| Claude Desktop | **not configured** — see below |

### Left: Claude Desktop

The Store install (3.1623, `userDataOutsidePackageAnswer: true` in its settings) keeps its files in `%LOCALAPPDATA%\Claude-Data\claude_pzs8sxrjxfjjc\`, `claude_desktop_config.json` included. Outside the package, `%APPDATA%\Claude` does not exist, so `setup_claude_desktop` answers `not_found`. Inside the package, a process sees a virtualized `%APPDATA%\Claude` that holds only a `.user-data-left.claude_pzs8sxrjxfjjc` marker. The docstring's "a link to that folder (measured 2026-10-20)" holds for another layout, not this one.

Fixed by FIX-AI-SETUP-STORE-DESKTOP (#1160), released in 6.31.1. Updated with the updater (it replaced the running `veaf-tools.exe`), then `ai-setup` run again with Claude Desktop quit: `veaf-mission-editor` → `C:\Users\David\VEAF\outils\veaf-tools.exe mcp` in `Claude-Data\claude_pzs8sxrjxfjjc\claude_desktop_config.json`, and the Store `Claude.exe` starts the server.
