# FIX-SPAWN-GROUP-FIRST-ROUTE — a spawned group with a destination gets its route 5 s after its birth, from the road

Status: ⬜ ready

Left over by FIX-GROUNDAI-CLOSE-IN-REACHABLE (ticket 02, "Not done"): "`veafSpawnCore` (`_spawn group` with a destination) also gives a route in the frame of the spawn; it is outside the convoy handler and the campaign, left for a later lot." David, 2026-11-22: create the lot.

## Read (2026-11-22)

- `veafSpawnCore.lua` lines 454-467: a group spawned with `options.destination` (and no role) gets `veaf.goRoute(groupObject, route)` in the frame it was created; a group given a `route` too.
- Measured by the dcs-cartographie session (2026-11, `D:\dev\_dcs-other\dcs-cartographie\docs\15-ia-sol-regles-mission.md`): an order given in the very frame a group is created is lost (3 out of 3); 5 s later it is taken. The group then stays where it spawned, with no message.
- The route comes from `veaf.generateVehiclesRoute(actualPosition, destination, not options.offroad, …)` (`veaf.lua` line 1870): without `offroad` it starts `On Road` at the group's own position. From DCS's code (dcs-cartographie): an `On Road` point far from any road makes the whole route fail, silently.
- FIX-GROUNDAI-CLOSE-IN-REACHABLE already fixed both for the convoys: `veafSpawn.spawnConvoy` gives its first route `veafSpawn.CONVOY_FIRST_ORDER_DELAY_SECONDS` (5 s) later (`veafSpawnGround.lua` line 841), and `veafGroundAI.roadEntry` / `roadRoute` (line 1538) start with an `Off Road` leg to the nearest road.
- Concerned: every VEAF mission, not only the campaign — a marker or command spawn of a ground group with a destination (`_spawn group … destination`, the shortcuts that pass one).

## Decided

David, 2026-11-22: one lot, one ticket. The integration branch is `feature/dynamic-campaign`: one branch and one pull request into it.

| # | Ticket |
|---|---|
| 01 | [The first route 5 s after the birth, from the road](tickets/01-first-route-after-birth-from-the-road.md) |
