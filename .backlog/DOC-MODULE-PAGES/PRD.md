# DOC-MODULE-PAGES — the five shipped modules no page documents

Status: ⬜ ready

Origin: the 2026-08-13 documentation audit, arbitration d (David: "faire un lot pour écrire les
docs manquantes"). Five registered modules under `src/scripts/veaf/` have no page under
`doc/mission-maker/scripts/` and no row in its README — two of them carry **player-facing**
surfaces.

## Scope

| # | Ticket | Status |
|---|--------|--------|
| 01 | [`veafGroundAI` — the `_ground` marker command](tickets/01-veafgroundai.md) | ⬜ |
| 02 | [`veafCombatMission` — the `MISSIONS` menu and `cap_missions:`/`combat_missions:`](tickets/02-veafcombatmission.md) | ⬜ |
| 03 | [`veafCommands`, `veafI18n`, `veafUnits` — the infrastructure trio](tickets/03-infrastructure-trio.md) | ⬜ |

Priorities: 01 and 02 have player-facing surfaces (a marker command with seven verbs; the F10
`MISSIONS` menu) and `veafCombatMission` even owns YAML sections currently documented under
*someone else's page* (`cap_missions:` / `combat_missions:` live in `veafCasMission.md:33-108`).
03 is developer-facing and can be three short pages.

Every page ships FR + EN, goes into `mkdocs.yml` nav with its `nav_translations` entry, gets its
README row, and follows the existing page shape (module ID header, YAML fields, F10 menu, marker
syntax where applicable) — read two good siblings (`veafShortcuts.md`, `veafQraManager.md`) before
writing.

## Rule learned by the audit, to honour here

Document only what the code does **today**, citing the line; where behaviour needs an in-game
answer, say "unverified" rather than guessing. The audit found 45 contradictions born of pages
written from memory.

## Definition of Done

- Five modules documented, linked, navigable; `docs-check` green; README rows added
  (including the missing `veafAssist` and `veafRadio` links if `DOC-AUDIT-FIXES` 03 has not already
  added them).
