# FEAT-RADIO-MENU-WATCH — watch the F10 menu in a real multiplayer mission

Status: 🔄 in-progress

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

## What the lot delivers

1. **`RADIO.menu_stats`** (ticket 01): a `mission.yaml` option, off by default, that logs to `dcs.log` on every refresh what the menu added and removed, its live size by audience (everyone, coalitions, groups) and the parked total. Turned on temporarily on an OT or another real mission.
2. **Whitepaper** (ticket 02): the DCS behaviour and the generic fix, FR and EN, in `docs/whitepapers/`, with the single-player cost measurement.
3. **The real-mission measurement** (ticket 03): a mission flown with the option on, the server's network output sampled meanwhile; the result goes into the whitepapers.

## Decided (David, 2026-10-10)

- **a)** Measure first; bound the parked pool only if a measurement shows a cost. The single-player one does not.
- **b)** Instrument VMCT behind a `mission.yaml` option and test on real missions, rather than a synthetic multiplayer test mission.

## Out of scope

- Bounding or recycling parked ids: no measured cost calls for it.
