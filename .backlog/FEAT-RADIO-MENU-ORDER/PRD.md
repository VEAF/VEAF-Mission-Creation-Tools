# FEAT-RADIO-MENU-ORDER — The VEAF F10 menus in the order pilots use them

Status: 🔄 in-progress

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

## Tickets

| # | Ticket | Status |
|---|---|---|
| 01 | [Root menus sort by a fixed key](tickets/01-root-sort-keys.md) | ⬜ |
| 02 | [The CAS menu stays, its entries stay](tickets/02-cas-menu-fixed.md) | ⬜ |
| 03 | [Doc, CHANGELOG, demo step](tickets/03-doc.md) | ⬜ |

Lua runtime (`src/scripts/veaf/`), luaunit tests with the DCS mocks; read the F10 menu id recycling trap (`docs/agents/dcs-runtime-traps.md`) before touching menus. One branch, one PR.
