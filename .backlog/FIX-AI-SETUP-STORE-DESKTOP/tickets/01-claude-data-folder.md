# 01 — Claude Desktop with its data out of the package

Status: ✅ done

`setup_claude_desktop(exe, appdata=..., localappdata=...)`: write into `%LOCALAPPDATA%\Claude-Data\claude_*\claude_desktop_config.json` when that folder exists, else `%APPDATA%\Claude` as before. `ai-setup` passes `%LOCALAPPDATA%`.

Done when: tests cover the `Claude-Data` folder alone, both folders (the `Claude-Data` one wins, the other is not written), and neither; David's PC gets the entry from a released `ai-setup`.
