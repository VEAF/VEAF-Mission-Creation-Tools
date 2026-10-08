# 03 — The game master's journal

Status: ⬜ ready

Every live action leaves a trace someone can read without Claude: who asked is the conversation, what was done is the mission.

- In `dcs.log`: one line per action, with one prefix (`VEAF-LIVE`), the action, its arguments, its position and its result.
  Written from the Lua side, so the line exists even when the MCP side crashes after sending.
- In game: a radio menu entry for admins (`USAGE_ForAll`, behind the security level of the other admin entries, since the game master slot sees no `ForGroup` commands) listing the last actions with their mission time.
- The journal is for admins only, whatever side Claude plays (D3): playing red, a player must not learn from it what is coming.

## Done when

A Lua test drives three actions through the same entry the bridge snippet uses and reads them back from the menu's text and from the logger; the `dcs.log` line format is in the doc page of ticket 05, so an admin can grep it.
