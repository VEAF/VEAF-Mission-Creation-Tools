# 02 — `veafCombatMission`: the MISSIONS menu, documented under someone else's page

Status: ⬜ ready
Type: feat
Files: new `doc/mission-maker/scripts/veafCombatMission.md` + `.en.md`, a move out of
`veafCasMission.md`, README row, `mkdocs.yml`

A registered module (`veafCombatMission.lua:21,1596`) owning the F10 `MISSIONS` menu (`:31,1347`),
the `/air` remote module (`:1591`), the `-airstart`/`-airstop` aliases (`veafShortcuts.lua:1581,
1589`) — and the `cap_missions:` / `combat_missions:` YAML sections currently documented inside
`veafCasMission.md:33-108`, a page about a different module.

Write the page; move (not duplicate) the YAML sections; leave a pointer in veafCasMission.md.
Cross-check the menu labels against the code (the audit found the README's claims wrong here).

## Acceptance criteria

- [ ] Page in both languages, in nav, README row; the YAML sections live with their owner;
      `docs-check` green (watch the cross-page anchors when moving sections).
