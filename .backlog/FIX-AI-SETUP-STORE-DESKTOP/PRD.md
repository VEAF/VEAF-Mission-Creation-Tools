# FIX-AI-SETUP-STORE-DESKTOP — `ai-setup` finds Claude Desktop when its data left the Store package

Status: 🔄 in-progress

Origin: FEAT-AI-ZERO-SETUP ticket 08, 2026-10-20. Set up like any user's, David's PC got the server in every client but Claude Desktop, the one the install page calls the simplest to start with.

## What was measured

| | Measure |
|---|---|
| Install | Claude Desktop from the Microsoft Store, version 3.1623, `userDataOutsidePackageAnswer: true` in its settings |
| Where its settings are | `%LOCALAPPDATA%\Claude-Data\claude_pzs8sxrjxfjjc\claude_desktop_config.json` (and `config.json`), rewritten by the app at start-up |
| Where `ai-setup` looks | `%APPDATA%\Claude`, which does not exist outside the package → `not_found` |
| Inside the package | a process sees a virtualized `%APPDATA%\Claude` holding only a `.user-data-left.claude_pzs8sxrjxfjjc` marker |

## Decision (David, 2026-10-20)

- `setup_claude_desktop` takes `%LOCALAPPDATA%` too: a `Claude-Data\claude_*` folder wins when it exists; otherwise `%APPDATA%\Claude` as before, the classic install and the Store install whose `%APPDATA%\Claude` is a link to the package.
- On the way: the updater's first-install message told the user to run `prepare .` in the folder the updater sits in. That is right for the guide, which puts the updater in the mission folder, and wrong for the install page for an AI, which puts it in `%USERPROFILE%\VEAF\outils`. The message now names the mission folder and keeps `.` for the first case.

## Tickets

- [01 — Claude Desktop with its data out of the package](tickets/01-claude-data-folder.md)
- [02 — The updater's first-install message](tickets/02-first-install-message.md)
