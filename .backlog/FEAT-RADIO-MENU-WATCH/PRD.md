# FEAT-RADIO-MENU-WATCH — watch the F10 menu in a real multiplayer mission

Status: 🧑 waiting-human

FIX-RADIO-MENU-ID-RECYCLING (#1113) parks every freed menu id on an inert command for group 999999, so a stale click on a removed entry fires nothing.
Those commands are never removed: they pile up for the whole mission.

## What is known — measured 2026-10-10

In single player, 50 000 parked commands cost nothing measurable: DCS memory flat within its ~100 MB noise, 30 fps throughout, ordinary adds and removes no slower, the F10 menu still instant.

| Parked | Creation | DCS private memory | fps | 500 adds + 500 removes | F10 |
|---|---|---|---|---|---|
| 0 | | 29 465 MB | 30.0 | 0.096 s | instant |
| 1 000 | 0.05 s | 29 373 MB | 30.0 | 0.029 s | instant |
| 10 000 | 0.02 s | 29 356 MB | 30.0 | 0.025 s | instant |
| 50 000 | 0.13 s | 29 443 MB | 30.0 | 0.065 s | instant |

## What is not

What a server sends its clients.
David has seen sync problems with large radio menus in the past, with static slots; parked commands, if DCS sends a group's menu to clients outside the group, would grow the menu every client receives.
Nobody knows how big the VEAF menu gets in a real evening, nor how much it changes.

## What the DCS binary adds — read 2026-10-19

DCS's `bin/wRadio.dll` (shipped in the clear) has a group-menu serialiser that caps each node's command, submenu and item counts at **8191**: past it DCS logs `... Count enormous %d` and clamps to 8192 on read, truncating the node over the network.
Parked commands all sit at group 999999's **root node**, so the pool has a **hard ceiling of ~8191** when that menu is serialised to a client.
The single-player test above could not see this: the cap lives in the network serialiser, which single player never runs.
Still open, behind the protected `Inter.dll`: whether group 999999's menu actually reaches clients. Details and the proposed fix in [ticket 04](tickets/04-parking-ceiling.md).

## What the lot delivers

1. **`RADIO.menu_stats`** (ticket 01): a `mission.yaml` option, off by default, that logs to `dcs.log` on every refresh what the menu added and removed, its live size by audience (everyone, coalitions, groups) and the parked total. Turned on temporarily on an OT or another real mission.
2. **Whitepaper** (ticket 02): the DCS behaviour and the generic fix, FR and EN, in `docs/whitepapers/`, with the single-player cost measurement.
3. **The real-mission measurement** (ticket 03): a mission flown with the option on, the server's network output sampled meanwhile; the result goes into the whitepapers.
4. **Page the parked pool under the 8191 node ceiling** (ticket 04): spread parked commands across bounded submenus of group 999999 so no node approaches the serialiser cap.

## Decided (David, 2026-10-10)

- **a)** Measure first; bound the parked pool only if a measurement shows a cost. The single-player one does not.
- **b)** Instrument VMCT behind a `mission.yaml` option and test on real missions, rather than a synthetic multiplayer test mission.
- **c)** The real missions are the three new Open Training missions (Caucasus, GermanyCW, Syria v6), built with the next VMCT release, not with `develop`: they run 6.26.x scripts, which do not park yet.

## Out of scope

- Recycling or purging parked ids (reuse the oldest, bulk purge): rejected in [ticket 04](tickets/04-parking-ceiling.md) — reuse re-opens the recycling hole, and DCS never signals when a screen is closed.

(The earlier "bounding the pool is out of scope, no measured cost" no longer holds: the DCS binary shows an 8191-per-node serialiser ceiling. Ticket 04 pages the pool under it.)
