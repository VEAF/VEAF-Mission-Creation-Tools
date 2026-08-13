# 01 — `veafGroundAI`: the `_ground` marker command nobody can discover

Status: ⬜ ready
Type: feat
Files: new `doc/mission-maker/scripts/veafGroundAI.md` + `.en.md`, README row, `mkdocs.yml`

A registered module (`veafGroundAI.lua:20,865`) with a player-facing marker command `_ground` and
seven verbs `set/unset/order/start/stop/clear/status` (`veafGroundAI.lua:26,715-770`), a dispatcher
handler (`:857`), and a shipped alias `-ai_set` that `veafShortcuts.md:127` already documents —
pointing at a module with no page.

Write the page from the code: keyphrase, verbs with parameters and defaults, security level of the
handler, examples verified against the parser (the audit's lesson: an invalid example now aborts).

## Acceptance criteria

- [ ] Page in both languages, in nav, README row; `docs-check` green.
