# 08 — David's PC

Status: ✅ done

Once a release ships `ai-setup`: remove the `poetry` `veaf-mission-mcp` server from `~/.claude.json` and uninstall the `veaf-mission-editor@veaf` plugin, then install with the updater and run `ai-setup`, as any user would.

## Done on 2026-10-20, with 6.31.0

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

## Left: Claude Desktop

The Store install (3.1623, `userDataOutsidePackageAnswer: true` in its settings) keeps its files in `%LOCALAPPDATA%\Claude-Data\claude_pzs8sxrjxfjjc\`, `claude_desktop_config.json` included. Outside the package, `%APPDATA%\Claude` does not exist, so `setup_claude_desktop` answers `not_found`. Inside the package, a process sees a virtualized `%APPDATA%\Claude` that holds only a `.user-data-left.claude_pzs8sxrjxfjjc` marker. The docstring's "a link to that folder (measured 2026-10-20)" holds for another layout, not this one.

Fixed by FIX-AI-SETUP-STORE-DESKTOP (#1160), released in 6.31.1. Updated with the updater (it replaced the running `veaf-tools.exe`), then `ai-setup` run again with Claude Desktop quit: `veaf-mission-editor` → `C:\Users\David\VEAF\outils\veaf-tools.exe mcp` in `Claude-Data\claude_pzs8sxrjxfjjc\claude_desktop_config.json`, and the Store `Claude.exe` starts the server.
