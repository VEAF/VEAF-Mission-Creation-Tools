# 01 — The first route 5 s after the birth, from the road

Status: 🧑 waiting-human
Type: fix

## To do

- First, a failing test (TDD): a ground group spawned by `veafSpawnCore` with a destination gets no `goRoute` in its creation frame; it gets one 5 s later.
- `veafSpawnCore.lua` lines 454-467: give the route (generated or passed) `veafSpawn.CONVOY_FIRST_ORDER_DELAY_SECONDS` after the spawn, with `timer.scheduleFunction`, as `spawnConvoy` does; skip it when the group no longer exists or was given another route meanwhile (the convoy handler's "last order wins").
- `veaf.generateVehiclesRoute` with `onRoad`: when the start point is more than `veafGroundAI.ON_ROAD_TOLERANCE` from the nearest road, start with an `Off Road` leg to the road (`veafGroundAI.roadEntry`), then `On Road`; same for the destination if it lies off the road (`roadExit`). If `veafGroundAI` is not loaded, keep today's route and say so in a comment. Check the other callers of `generateVehiclesRoute` (`git grep -n generateVehiclesRoute src/scripts/veaf/`) get the same benefit without a change of behaviour they rely on.
- Aircraft and ships are not concerned (their spawn passes the route in the group's definition, or a role); leave them, and say so in the code.
- Tests: the route given 5 s after the birth, not before; none when the group is gone; an off-road start gets an `Off Road` leg first, an on-road start does not; an `offroad` spawn unchanged.
- Docs: none expected (behaviour fix); CHANGELOG entry.

## Done when

A ground group spawned with a destination drives off within seconds, from wherever it spawned; with tests.

## Done

- `veafSpawn.giveFirstRoute` (`veafSpawnCore.lua`): the route of a group `executeCommand` spawned, generated from `options.destination` or passed with the command (a shortcut's `route`), is given `CONVOY_FIRST_ORDER_DELAY_SECONDS` (5 s) after the spawn instead of in its creation frame. Not when the group no longer exists by then (gone, or `isExist()` false), nor when a group spawned again under the same name meanwhile scheduled its own (the last order wins, by an id per group name). `veafGroundAI.noteBirth` is called when the module is loaded, so a ground-control order (`_gc`) given to the group within 5 s waits too. An aircraft with a role keeps its route, as before; aircraft and ships otherwise get their route in their definition.
- The road entry was already there: `veaf.generateVehiclesRoute` with `onRoad` starts `Off Road` at the group's own position (`T_STA`), then `On Road` at the nearest road point (`STA`), drives on the road to the road point nearest the destination (`END`) and off it to the destination (`T_END`, `Diamond`) — the shape of `veafGroundAI.roadEntry` / `roadExit`. The PRD's reading ("`On Road` at the group's own position") was wrong. `generateVehiclesRoute` is not changed, so its other callers (`spawnConvoy`, `advanceConvoy`) and the `offroad` spawns are untouched; a test pins the shape.
- Not done: a combat zone gives the route of the groups its elements spawn from its own hook, in the same frame (`veafCombatZone.lua`, `registerSpawnedGroupsHook`); same defect, outside this ticket.
- Tests (`test_veafSpawn.lua`): the route to the destination 5 s after the birth and not before, generated from where the group stands and on the road; a passed route 5 s after too; none when the group is gone or destroyed; a group spawned again under its name gets only its own route; an `offroad` spawn still asks for an off-road route; an on-road route starts off road to the road and ends off road at the destination, an off-road route has no `On Road` point. The role tests now advance past the delay before asserting.

## In-game check

In a test mission, spawn a group with a destination by marker, away from any road (`_spawn group, name <alias>, dest <...>` or the documented syntax): it leaves within 10 s and reaches the road, then follows it.
