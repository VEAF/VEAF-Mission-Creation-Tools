# 01 — The first route 5 s after the birth, from the road

Status: ⬜ ready
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

## In-game check

In a test mission, spawn a group with a destination by marker, away from any road (`_spawn group, name <alias>, dest <...>` or the documented syntax): it leaves within 10 s and reaches the road, then follows it.
