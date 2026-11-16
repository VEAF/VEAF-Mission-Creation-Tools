# 14 — VEAF spawn commands paid in credits or resources

Status: 🔄 in-progress

PRD row "VEAF spawn commands paid in credits" and player experience point 9 (David, 2026-10-08 and 2026-11-16).

## What

In a persistent campaign every VEAF spawn command a person issues — `_spawn`, `-armor`, `-cap`, convoys, crates, by marker or by the interpreter, game masters included — is paid:

- **in credits** when it spawns for the players' side;
- **from the resources** of the side it spawns for otherwise — red, which has no players (David, 2026-11-16);
- **priced by command category**, `dynamic.economy.spawn_prices`, defaults below;
- **refused with an explicit error** when the side cannot pay: what it costs and what is left, to the requester; nothing is charged, nothing is spawned;
- charged only when the command actually spawned something;
- what survives joins its side's resources at the next load (ticket 12).

A spawn a script makes (a combat zone, the campaign's own sorties) is not a person's action and is not charged here; the campaign's sorties pay their own way (ticket 12).
The players' assault order (Campaign → Assault) is a purchase too: `economy.prices.assault` (300 credits).

## Defaults (credits or points)

| command | price | | command | price |
|---|---|---|---|---|
| `unit` | 100 | | `convoy` | 300 |
| `group` | 150 | | `cap` | 400 |
| `infantryGroup` | 50 | | `afac` | 300 |
| `armoredPlatoon` | 150 | | `awacs` | 500 |
| `airDefenseBattery` | 250 | | `escort` | 400 |
| `transportCompany` | 100 | | `farp` | 200 |
| `fullCombatGroup` | 400 | | `fob` | 300 |
| `cargo` | 50 | | `logistic` | 100 |

Everything else (smoke, flares, drawings, destroy, teleport, mission master) stays free: it puts no unit into play.
Values in the shop's scale (a CAP is 400 in both); a category set to 0 is free.

## How

`veafSpawn.executeCommand` asks an optional `veafSpawn.spawnGate(key, options, requester)` before the command's handler runs, and tells `veafSpawn.spawnPaid(...)` what it spawned; outside a persistent campaign nothing is set and nothing changes.

## Done when

Lua tests: a blue spawn charged in credits, a red one from red's resources; refused with the explicit message and nothing spawned when short; a free category; a scripted spawn not charged; a spawn that produced nothing not charged; survivors paid back at load.
