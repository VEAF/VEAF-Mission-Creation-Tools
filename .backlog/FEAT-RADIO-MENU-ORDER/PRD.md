# FEAT-RADIO-MENU-ORDER — The VEAF F10 menus in the order pilots use them

Status: ✅ done

David, 2026-11-10: "some menus are used more often than others, like the combat zones or the weather, and they are not always at the top. Typically the combat zones are the last menu in the list. That's really bad."

## The defect

The entries of a VEAF F10 menu are sorted **alphabetically by their label** (`veafRadio.RadioMenuBuilder:_buildChildren`, `veafRadio.lua` around line 895), and a page holds 10 entries (`MENU_PAGE_SIZE`).
In French, "ZONES DE COMBAT" starts with Z and comes last. An Open Training has more than ten root menus, so it can even end up on page 2.
The order also differs by language: "COMBAT ZONES" comes early in English.
The way out already exists: an entry with a `sortKey` sorts by it instead of its title. Only `veafAssist` uses it.

## Decisions — 2026-11-10

| # | Question | Decision |
|---|---|---|
| D1 | The mechanism | An order fixed in VMCT: each module gives its **root** menu a `sortKey`, the same in every language and every mission. Sub-menus keep sorting alphabetically. No per-mission override (`mission.yaml`): nobody asked for one |
| D2 | The order | The table below (David: "ça me va") |
| D3 | The CAS menu | It **stays forever**, last in the order, so on page 2 once the root paginates. With no CAS mission running it says so in one line ("No CAS mission: place `-cas` on the F10 map") next to its help. David turned down "show it only while a CAS mission runs": deleting and recreating menu entries is what the parking of menu ids (FIX-RADIO-MENU-ID-RECYCLING) works around, and doing it often grows the parking |
| D4 | The CAS mission's own entries | Same reason, by default: the entries the CAS mission adds and removes today (target information, situation, skip, the markers sub-menu, and the smoke and flare labels swapped after each request) become **fixed** entries that answer "no CAS mission running" or "smoke already requested" when they cannot act, instead of being deleted and recreated. Recorded as the default from David's reasoning; tell him if an entry cannot stay fixed |

## The order (D2)

| Rank | Menu (key) | FR label | Why |
|---|---|---|---|
| 1 | `menu.campaign.root` | Campagne | absent from the OTs; the heart of a campaign mission |
| 2 | `menu.combatzone.root` | ZONES DE COMBAT | what an OT is for |
| 3 | `menu.weather.root` | MÉTÉO ET ATC | read on every flight: departure, arrival, QNH |
| 4 | `menu.assets.root` | MOYENS | tankers, AWACS |
| 5 | `menu.combatmission.root` | MISSIONS | scripted combat missions, CAP |
| 6 | `menu.carrier.root` (and `_blue` / `_red`) | OPS PORTE-AVIONS | |
| 7 | `menu.transportmission.root` | MISSION DE TRANSPORT | |
| 8 | `menu.spawn.root` | APPARITION | escort and the like |
| 9 | `menu.skynet.root` | RÉSEAU DE GUETTEURS | |
| 10 | `menu.move.root` | DÉPLACER | |
| 11 | `menu.namedpoints.root` | POINTS NOMMÉS | |
| 12 | `menu.missileguardian.root` | GUARDIAN | |
| 13 | `menu.opposition.root` | Opposition | |
| last | `menu.casmission.root` | MISSION CAS | D3 |

Any other root entry (a command added straight under VEAF, a module not listed here) sorts after rank 13 and before MISSION CAS, alphabetically among themselves.
Read every root menu and root command from the code before fixing the keys: this list comes from the i18n keys, not from a menu seen in game.

## To check while implementing

- `veafCasMission` removes its entries by **English literal** titles (`delCommand(..., "Target information")`, around line 1359), while it adds them with `veaf.t(...)` labels, French in a French mission. If `delCommand` matches the displayed title, those removals never happened in French: D4 removes the question, but say what was measured.
- The order seen in game on an OT: the root's real list and which entries land on page 2 (the demo mission or an OT, with `RADIO.menu_stats` if useful).

## Outcome — 2026-11-10

- **The mechanism.** `veafRadio.ROOT_MENU_ORDER` lists the i18n keys in the order of D2; each module adds its root menu with `veafRadio.addRootMenu(key)`, which sets a numeric `rootRank` on the node. The rank is a field of its own rather than the `sortKey`, because `veafAssist` already gives its two top-level commands a textual `sortKey` ("Assistance 1", "Assistance 2"). At the root only, commands and menus sort together, by rank, then by `sortKey` or title: an unlisted entry (CTLD, Assistance and its two commands, a command added straight under VEAF) comes after rank 13, the CAS menu after everything.
- **The root read from the code** matches the PRD's table, plus four unlisted entries: `menu.ctld.root`, `assist.menu.root`, and the two `assist.menu.confirm` / `assist.menu.skip` commands. The spotter network adds one root menu per coalition, same key, same rank.
- **The CAS menu (D3, D4).** Built once: help, target information, skip, and the markers sub-menu with smoke and flare. "A CAS mission runs" is its watchdog being scheduled. Every entry answers "No CAS mission: place a -cas marker on the F10 map" with no mission; smoke and flare answer "already requested" until their reset; the end of a mission cancels the resets. A whole mission makes no DCS menu call (test). The "no CAS mission" line of D3 is the answer of each entry rather than an entry of its own: a line shown only with no mission running would be the one entry still created and deleted at every mission.
- **Measured: the English-literal `delCommand`.** Run under DCS's `luae.exe` on the pre-lot code, with the real `veafRadio`: in English the removals work; in French none happens. After a smoke request the markers menu shows both "Demander de la fumée sur l'objectif" and "Objectif marqué à la fumée rouge"; after the reset a second "Demander de la fumée…" is added; after the mission ends "Infos sur l'objectif" and "Passer l'objectif en cours" stay, and the next `-cas` adds them again. `"Get current objective situation"` matched no entry in any language: none was ever added. `veafTransportMission` has the same defect, left as is and recorded in `known-limitations.yaml` (`transport-mission-menu-piles-up-in-french`).
- **Not done here:** the demo mission's tour step (CLAUDE.md §9 item 9) lives in `VEAF/VEAF-Demo-Mission-v6`, a repository of its own; it is left as a follow-up. The order was not checked in game.

## Tickets

| # | Ticket | Status |
|---|---|---|
| 01 | [Root menus sort by a fixed key](tickets/01-root-sort-keys.md) | ✅ |
| 02 | [The CAS menu stays, its entries stay](tickets/02-cas-menu-fixed.md) | ✅ |
| 03 | [Doc, CHANGELOG, demo step](tickets/03-doc.md) | ✅ |

Lua runtime (`src/scripts/veaf/`), luaunit tests with the DCS mocks; read the F10 menu id recycling trap (`docs/agents/dcs-runtime-traps.md`) before touching menus. One branch, one PR.
