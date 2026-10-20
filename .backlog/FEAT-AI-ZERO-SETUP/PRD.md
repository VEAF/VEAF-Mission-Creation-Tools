# FEAT-AI-ZERO-SETUP — installing veaf-tools is all an AI needs

Status: 🔄 in-progress

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

- [01 — Updater: replace a running veaf-tools.exe](tickets/01-updater-running-exe.md)
- [02 — Ship the authoring guide and the mission prompts](tickets/02-ship-guide-and-prompts.md)
- [03 — `veaf-tools ai-setup`](tickets/03-ai-setup.md)
- [04 — The MCP server updates itself](tickets/04-server-self-update.md)
- [05 — Remove the plugin and the Gemini extension](tickets/05-remove-plugin.md)
- [06 — Known limitations from the project memory](tickets/06-known-limitations.md)
- [07 — Documentation](tickets/07-docs.md)
- [08 — David's PC](tickets/08-davids-pc.md)
