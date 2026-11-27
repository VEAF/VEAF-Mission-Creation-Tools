# FEAT-CHERRY-AI-SETUP — `ai-setup` declares the VEAF MCP server in Cherry Studio

Status: 🔄 in-progress

Asked by David on 2026-11-26, through the local-model test session: with Inkling-2-Mini (llama.cpp) and Cherry Studio 2.2.3 as the chat client, the VEAF MCP server works end to end (the three blocks of the "Marteau du Golan" trial, PR #1349). A tutorial for non-technical pilots is being prepared on that stack (24 GB cards).
One manual step remains: declare the MCP server in Cherry (Settings → MCP → JSON import, then link it to the assistant).
`veaf-tools ai-setup` (`veaf_libs/ai_clients.py`) already does that for Claude Desktop, Gemini, Antigravity, Codex, OpenCode and Claude Code; Cherry Studio is not in the list.

Its own lot, after PR #1349 (David, 2026-11-26): the two touch different files, and #1349 already carries three review findings to fix. Only ticket 01, the study, writes no code and can start at once; ticket 02 waits for its verdict.

Constraints measured by the test session:
- The MCP command must carry `VEAF_MCP_PROFILE=compact` (the compact profile arrives with PR #1349); without it the 65 536-token context does not hold.
- The friends' convention is `veaf-tools.exe` in `C:\VEAF\` (the updater has no default folder: it installs in the current directory). The starting Cherry backup will point there; a different path is fixed in Cherry. If `ai-setup` removes that manual setting, so much the better: the backup stays useful for the provider, the two assistants and the doc base.
- Never write into the database of a running application without a guard.
- Cherry is open source (`CherryHQ/cherry-studio`, AGPL-3.0): the format can be read in its code, not guessed.

Tickets:
1. Study — where and how Cherry Studio 2.2.x stores its MCP servers, and whether `ai-setup` can reach it safely. Verdict first, nothing coded before it.
2. `setup_cherry` — only if the verdict is "feasible".
3. Documentation (FR and EN) and a line in the tutorial.
