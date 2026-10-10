# 05 — Documentation, skill, known limitations

Status: ⬜ ready

- A page `doc/.../game-master-live.md` and its `.en.md`, in the `nav`: for whoever runs a session — start `dcs-serve`, give Claude the operator token, what the three actions do, what they cannot do (no raw Lua, no autonomous loop), how to read the journal; commands in PowerShell, `.\` form.
- The support bot's page index refreshed (`refresh_doc_pages.py`).
- The `veaf-mission-authoring` skill (plugin) gains a short section: during a flight, read with `live_situation` before acting, give the coalition explicitly, say where things were put.
  And which side Claude plays (D3): playing red, nothing is shown to the players; playing blue, Claude judges whether the players concerned need warning, and warns them by text and voice (ticket 07).
- The page says how to give Claude a free hand (D2): allowing the live actions in Claude Code's permissions, for the session or for good.
- `known-limitations.yaml`: ticket 01's finding if a shipped version is affected, ticket 04's measurement; then `docs/agents/dcs-runtime-traps.md` regenerated.
- `CHANGELOG.md`, `[Unreleased]`, one entry at the end.
