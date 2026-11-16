# 14 — VEAF spawn commands paid in credits or resources

Status: 🧑 waiting-human — built and tested outside DCS in #1282 (2026-11-16); the in-game check of the test mission is David's

PRD row "VEAF spawn commands paid in credits" and player experience point 9 (David, 2026-10-08 and 2026-11-16).

## What

In a persistent campaign every VEAF spawn command a person issues — `_spawn`, `-armor`, `-cap`, convoys, crates, dropped as a marker, game masters included — is paid:

- **in credits** when it spawns for the players' side;
- **from the resources** of the side it spawns for otherwise — red, which has no players (David, 2026-11-16);
- **priced by the units it made**, below;
- **refused with an explicit error** when the side cannot pay: what it costs and what is left, to the requester; nothing is charged, nothing is spawned;
- charged only when the command actually spawned something;
- what survives joins its side's resources at the next load (ticket 12).

A spawn a script makes (a combat zone, a command the interpreter reads from a name placed in the editor — veafCommands calls it trusted —, the campaign's own sorties) is not a person's action and is not charged here; the campaign's sorties pay their own way (ticket 12).
The interpreter's commands are not paid, and do not belong in a persistent campaign at all (David, 2026-11-16): they spawn afresh at every restart, outside the save. What the MCP or a mission maker places goes into `campaign.yaml` as zones and garrisons; `campaign next` reports any interpreter command it finds in the mission.
The players' assault order (Campaign → Assault) is a purchase too: `economy.prices.assault` (300 credits).

## Price: the units the spawn made (David, 2026-11-16)

A random group draws its units, so a spawn is priced once it exists: the sum of its units' prices on the resources' scale (`veafCampaign.unitPrice`, ticket 12), in resource points for the other side, and `economy.credits_per_point` (6) credits a point for the players' side — a CAP of two fighters, 60 points, is 360 credits, near the shop's 400.
A side that cannot pay sees the units taken away at once and is told the price and what it has; a side with nothing left at all is refused before the spawn.
Free: the commands that put no unit into play (smoke, flares, drawings, destroy, teleport, mission master).

A batch alias (`-arty1`) bypasses the password it has already checked for the pilot who dropped it; until this lot, that bypass also meant "a script asked", so its battery was free. `scripted` now travels through `veafShortcuts` apart from the bypass (David, 2026-11-16).

## How

`veafSpawn.executeCommand` asks an optional `veafSpawn.spawnGate(key, options, requester)` before the command's handler runs, and tells `veafSpawn.spawnPaid(...)` what it spawned; outside a persistent campaign nothing is set and nothing changes.

## Done when

Lua tests: a blue spawn charged in credits, a red one from red's resources; refused with the explicit message and nothing spawned when short; a free category; a scripted spawn not charged; a spawn that produced nothing not charged; survivors paid back at load.
