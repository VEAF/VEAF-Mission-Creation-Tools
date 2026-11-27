# 14 — VEAF spawn commands paid in credits or resources

Status: ✅ done

PRD row "VEAF spawn commands paid in credits" and player experience point 9 (David, 2026-10-08 and 2026-11-16).

## What

In a persistent campaign every VEAF spawn command a person issues — `_spawn`, `-armor`, `-cap`, convoys, crates, dropped as a marker, game masters included — is paid:

- **in credits** when it spawns for the players' side;
- **from the resources** of the side it spawns for otherwise — red, which has no players (David, 2026-11-16);
- **priced by the units it made**, below;
- **refused with an explicit error** when the side is at zero or in debt: its balance, to the requester; nothing is charged, nothing is spawned;
- charged only when the command actually spawned something;
- what survives joins its side's resources at the next load (ticket 12).

A spawn a script makes (a combat zone, a command the interpreter reads from a name placed in the editor — veafCommands calls it trusted —, the campaign's own sorties) is not a person's action and is not charged here; the campaign's sorties pay their own way (ticket 12).
The interpreter's commands are not paid, and do not belong in a persistent campaign at all (David, 2026-11-16): they spawn afresh at every restart, outside the save. What the MCP or a mission maker places goes into `campaign.yaml` as zones and garrisons; `campaign next` reports any interpreter command it finds in the mission.
The players' assault order (Campaign → Assault) is a purchase too: `economy.prices.assault` (300 credits).

## Price: the units the spawn made (David, 2026-11-16)

A random group draws its units, so a spawn is priced once it exists: the sum of its units' prices on the resources' scale (`veafCampaign.unitPrice`, ticket 12), in resource points for the other side, and `economy.credits_per_point` (6) credits a point for the players' side — a CAP of two fighters, 60 points, is 360 credits, near the shop's 400.
A spawn is never cut in part (David, 2026-11-16): the balance is asked once, before the first copy of a multiplied command, and each copy is then charged its exact price, into debt if need be. A side at zero or in debt spawns nothing more — refused before the spawn, with its balance — until it is above zero again; a gain pays the debt off first, and a side's resources in debt pay for no sortie either.
Free: the commands that put no unit into play (smoke, flares, drawings, destroy, teleport, mission master).

A batch alias (`-arty1`) bypasses the password it has already checked for the pilot who dropped it; until this lot, that bypass also meant "a script asked", so its battery was free. `scripted` now travels through `veafShortcuts` apart from the bypass (David, 2026-11-16).

## Reserved and disabled commands (David, 2026-11-16)

What would be cheating in a persistent campaign is reserved to admins there, through a marker policy the campaign sets on `veafCommands` (`markerPolicy`, asked for a player's marker only): `-shell`, `-cesar`, `-flak`, `_spawn bomb`, `-destroy`, `_destroy`, `-tanker`, `-tankerhere`, `_teleport`, `_move … teleport`, `-zonestart`, `-zonestop`, `-airstart`, `-airstop`, `-send`, `-play`, `_radio`, `-light`, `_spawn flare`. `-cas` and `_cas` are turned off: a dynamic CAS training zone makes no sense in a campaign. Other missions keep their levels.

## How

`veafSpawn.executeCommand` asks an optional `veafSpawn.spawnGate(key, options, requester)` before the command's handler runs, and tells `veafSpawn.spawnPaid(...)` what it spawned; outside a persistent campaign nothing is set and nothing changes.

## Done when

Lua tests: a blue spawn charged in credits, a red one from red's resources; refused with the explicit message and nothing spawned when short; a free category; a scripted spawn not charged; a spawn that produced nothing not charged; survivors paid back at load.
