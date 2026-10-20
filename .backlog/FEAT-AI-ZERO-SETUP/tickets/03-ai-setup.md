# 03 — `veaf-tools ai-setup`

Status: ⬜ ready

Declare `<this exe> mcp` as the `veaf-mission-editor` MCP server in every client found: Claude Desktop (`claude_desktop_config.json`, classic and Store installs), Claude Code (`claude mcp add --scope user`), Gemini CLI (`~/.gemini/settings.json`). Merge, never overwrite other settings; re-running is harmless; report what was done and that the client must be restarted. Refuses to run from a non-frozen interpreter. The updater suggests it after a first install.

Done: tests on temporary config files for each client; the TUI exclusion list updated.
