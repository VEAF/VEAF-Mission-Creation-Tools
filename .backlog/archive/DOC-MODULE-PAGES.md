# DOC-MODULE-PAGES — the five shipped modules no page documents

Status: ✅ done — 2026-08-13, all three tickets

Origin: the 2026-08-13 documentation audit, arbitration d (David: "faire un lot pour écrire les
docs manquantes"). Five registered modules under `src/scripts/veaf/` have no page under
`doc/mission-maker/scripts/` and no row in its README — two of them carry **player-facing**
surfaces.

## Scope

| # | Ticket | Status |
|---|--------|--------|
| 01 | `veafGroundAI` — the `_ground` marker command | ✅ |
| 02 | `veafCombatMission` — the `MISSIONS` menu and `cap_missions:`/`combat_missions:` | ✅ |
| 03 | `veafCommands`, `veafI18n`, `veafUnits` — the infrastructure trio | ✅ |

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

## What writing the pages found in the code

The lot's rule — document what the code does today, citing the line — turned up three things no
reader could have known:

- **`veafGroundAI`'s order text is separated by semicolons**, not by the commas the rest of the
  marker uses (`ArtilleryUnitHandler.OrderSpec.separator = ";"`). An order written with commas is
  split by the marker before the artillery ever sees it.
- **A `_ground set` without `groupname` searches 250 metres and no further**, then does nothing at
  all. The radius is not configurable.
- **The F10 menu labels are hard-coded English strings**, so the pilot guide's French menu paths
  ("Zones de combat → [Zone] → Activer") named entries that do not exist on screen. Nine paths
  corrected in the French guide, eight in the English one, which abbreviated them instead
  (`Info` for `Get info`, `Deactivate` for `Desactivate zone` — the typo is in the game).

## Left for a code lot, stated rather than fixed

**The F10 menu labels are not localised.** `veafCombatMission` and `veafCombatZone` build their menus
from literal English strings while every player-facing *message* goes through `veaf.t`. Documenting
the real labels is the honest fix for a documentation lot; making them follow the mission's language
is a change to Lua, in at least two modules, and belongs to its own lot.

---

## 01 — `veafGroundAI`: the `_ground` marker command nobody can discover

Status: ✅ done 2026-08-13 — page in both languages, in nav, README row; the two traps only a code read reveals are written down (semicolon-separated orders, the 250 m search)
Type: feat
Files: new `doc/mission-maker/scripts/veafGroundAI.md` + `.en.md`, README row, `mkdocs.yml`

A registered module (`veafGroundAI.lua:20,865`) with a player-facing marker command `_ground` and
seven verbs `set/unset/order/start/stop/clear/status` (`veafGroundAI.lua:26,715-770`), a dispatcher
handler (`:857`), and a shipped alias `-ai_set` that `veafShortcuts.md:127` already documents —
pointing at a module with no page.

Write the page from the code: keyphrase, verbs with parameters and defaults, security level of the
handler, examples verified against the parser (the audit's lesson: an invalid example now aborts).

### Acceptance criteria

- [ ] Page in both languages, in nav, README row; `docs-check` green.

---

## 02 — `veafCombatMission`: the MISSIONS menu, documented under someone else's page

Status: ✅ done 2026-08-13 — page in both languages; the YAML sections moved out of veafCasMission with a pointer left behind; menu labels quoted verbatim from the code, which is how the pilot guide's invented labels were found
Type: feat
Files: new `doc/mission-maker/scripts/veafCombatMission.md` + `.en.md`, a move out of
`veafCasMission.md`, README row, `mkdocs.yml`

A registered module (`veafCombatMission.lua:21,1596`) owning the F10 `MISSIONS` menu (`:31,1347`),
the `/air` remote module (`:1591`), the `-airstart`/`-airstop` aliases (`veafShortcuts.lua:1581,
1589`) — and the `cap_missions:` / `combat_missions:` YAML sections currently documented inside
`veafCasMission.md:33-108`, a page about a different module.

Write the page; move (not duplicate) the YAML sections; leave a pointer in veafCasMission.md.
Cross-check the menu labels against the code (the audit found the README's claims wrong here).

### Acceptance criteria

- [ ] Page in both languages, in nav, README row; the YAML sections live with their owner;
      `docs-check` green (watch the cross-page anchors when moving sections).

---

## 03 — `veafCommands`, `veafI18n`, `veafUnits`: the infrastructure trio

Status: ✅ done 2026-08-13 — three developer-facing pages in both languages, in nav, folded into the README's Foundation row
Type: feat
Files: three new page pairs under `doc/mission-maker/scripts/`, README rows, `mkdocs.yml`

- `veafCommands` — the central marker/text dispatcher: priorities, the mandatory per-handler
  security declaration (`veafCommands.lua:43-51,72-97,113-128`) — the mechanism `veafSecurity.md`
  describes without naming. Developer-facing; short.
- `veafI18n` — `veaf.i18nCatalog` consumed by `veaf.t()`; every player-visible string flows through
  it. Belongs beside `veafCacheManager`/`veafEventHandler` in the "Fondation" list.
- `veafUnits` — the group/unit database behind `_spawn group` (`veafUnits.Id = "UNITS"`); the
  README's data-modules table lists `dcsUnits.lua` but not this one.

Three short pages: what it is, who calls it, the two or three things a mission maker can configure
or must not touch. No verb tables to invent — cite the code.

### Acceptance criteria

- [ ] Three page pairs, in nav, README rows; `docs-check` green.
