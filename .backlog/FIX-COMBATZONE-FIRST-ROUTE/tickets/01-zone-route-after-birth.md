# 01 — The zone's route 5 s after the birth

Status: 🔄 in-progress
Type: fix

## To do

- First, a failing test (TDD, `test/lua/test_veafCombatZone.lua`): a combat zone element that is a VEAF command spawns a group; the group gets no `goRoute` in its creation frame, and gets the element's route 5 s later.
- `veafCombatZone.lua` line 1995: replace `veaf.goRoute(newGroup, route)` with `veafSpawn.giveFirstRoute(newGroup, route)`, so the delay, the "group gone" check and the "last order wins" rule are the ones `veafSpawnCore` uses, not a copy.
- Check the order between the two schedules: when the command itself passed a route, `executeCommand` already scheduled it with `giveFirstRoute`; the zone's call comes after, in the same frame, so the zone's route wins, as today. Pin it with a test.
- The deactivation check stays where it is (the hook destroys a group spawned after its zone was deactivated). Check that a zone deactivated during the 5 s gives no route to a destroyed group: `giveFirstRoute` skips a group that no longer exists.
- An aircraft with a role keeps its role's route, as today (the `getRole` early return stays before).
- Tests: the route 5 s after the birth, not before; none when the group was destroyed meanwhile; the zone's route wins over a route passed with the command; an aircraft with a role gets none.
- Docs: none expected (behaviour fix); CHANGELOG entry.

## Done when

A group a combat zone spawns from a VEAF command drives its route within seconds of the zone's activation; with tests.

## In-game check

In a test mission, a combat zone with a command element that has a route (a convoy or an armour group drawn with waypoints): activate the zone, the group leaves within 10 s and follows its waypoints.
