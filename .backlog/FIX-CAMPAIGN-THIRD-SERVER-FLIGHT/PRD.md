# FIX-CAMPAIGN-THIRD-SERVER-FLIGHT — what the third evening on the server taught

Status: 🧑 waiting-human — ticket 08: the redraw of the Oronte red garrisons (live server, server empty, David's go), then its in-game check

Flight check: tickets 01 to 07, 09 and 10 on the Campagne server: a slot on every campaign airfield including a captured one, the sitac's players, ranking, ejected pilots, tasks and support aircraft, a convoy under fire that keeps its place, revived units paid at their spawn price, and the air defence prices to tune after an evening (its `ECONOMY SUMMARY`).

The persistent campaign "Bouclier de l'Oronte" (Northern Syria), restarted from scratch on 2026-11-18 with FIX-CAMPAIGN-SECOND-SERVER-FLIGHT, the sitac block (FEAT-CAMPAIGN-SITAC-STATE) and the fixed file name `Campagne_Oronte.miz` (FEAT-CAMPAIGN-MISSION-FILE), flown on the Campagne server (`foothold2`) on 2026-11-19.
The integration branch is `feature/dynamic-campaign`: one branch and one pull request into it for the whole lot.

| # | Ticket | Weight |
|---|---|---|
| 01 | [A captured airfield offers no slot](tickets/01-captured-airfield-has-no-slot.md) | blocking: capturing an airfield gains nothing for the players |
| 02 | [The sitac shows the players, as Foothold's does](tickets/02-sitac-players.md) | asked by David |
| 03 | [The sitac ranks the pilots, as Foothold's does](tickets/03-sitac-player-stats.md) | Foothold parity |
| 04 | [The sitac shows the ejected pilots](tickets/04-sitac-ejected-pilots.md) | Foothold parity, helps the rescue |
| 05 | [The sitac lists the task board](tickets/05-sitac-tasks.md) | Foothold parity |
| 06 | [The sitac shows the AWACS and the tankers](tickets/06-sitac-support-assets.md) | Foothold parity, more than Foothold |
| 07 | [An assault convoy vanishes in front of the players when it is attacked](tickets/07-assault-convoy-vanishes-under-fire.md) | added by David on 2026-11-19: the players lose their target |
| 08 | [One air defence group per garrison, up to level 5](tickets/08-one-air-defence-group-per-garrison.md) | added by David on 2026-11-19 (option b): Aleppo had 32 air defence units |
| 09 | [Units revived by a delivery are paid at their spawn price](tickets/09-revived-units-paid-at-spawn-price.md) | added by David on 2026-11-19: 7 units back at Aleppo for nothing |
| 10 | [Air defence costs more](tickets/10-air-defence-prices.md) | added by David on 2026-11-19: a Tor was worth a BMP |

Decided by David on 2026-11-19, following the recos of the comparison below: tickets 02 to 06; the shop on the sitac later; the units zone by zone never (the intelligence rule). Each sitac ticket has a VMCT half (the `sitac` block) and a foothold-sitac half (the reader and the page): one PR per repository for the whole lot.

## What Foothold's save gives its sitac that ours does not

David, 2026-11-19: "s'il manque des fonctionnalités dans notre fichier de statut, liste-les en comparant avec Foothold".
Compared: Foothold 3.2.2's `zonePersistance` as `foothold-sitac/docs/lua-file-format.md` describes it, against `veafCampaign.sitacTable()` (`src/scripts/veaf/veafCampaign.lua`).

| Foothold key | What the sitac shows with it | Ours | Proposed |
|---|---|---|---|
| `players` | connected players: side, aircraft type, name, position | absent | ticket 02 |
| `playerStats` | the ranking page: points, deaths, kills by category (air, SAM, ground, infantry, helicopter, structure), captures, rescues, flight time, deliveries | absent; ticket 10 of the second lot keeps credit totals per pilot in the save, not in the sitac block | to discuss: the per-pilot credit totals, plus kills by category from `[CAMPAIGN FLIGHT]` |
| `ejectedPilots` | ejected pilots on the map, position and credits at stake | absent | to discuss: the CSAR pilots on the ground, from `veafCSAR` |
| `missions` | the active missions | absent | to discuss: the task board (V1 "3 or 4 tasks with a map mark") |
| `shops` | each side's shop | absent | to discuss: the shop items and their prices |
| `tankers` | tanker settings | absent | to discuss: the AWACS and tankers that `veafSupport` places, with their position and frequency |
| `zonesDetails.flavorText` | a label per zone (`WPT 8`) | `waypoint` | covered |
| `zones.level`, `upgrades…` | the zone's upgrade level | `garrison` alive/total | covered differently (counts only, the intelligence rule) |
| `zones.remainingUnits`, `destroyed` | unit by unit | absent | on purpose: a garrison stays hidden until reconnoitred, and the map is public |
| `accounts` | each side's credits | `sides.<side>.credits`, player side only | covered |
| `connections` | the supply links | `connections` | covered |
| — | — | `convoys`, `capture`, `structures`, `awake`, `sides.<side>.resources` | ours only |

Updated how often: our block is written with the state, every `state_write_seconds` (60 s) of simulation, and not while the server is paused. Players' positions need the same rhythm at least; to measure against Foothold's.
