# FIX-COMBATZONE-FIRST-ROUTE — a group a combat zone spawns by command gets its route 5 s after its birth

Status: 🧑 waiting-human

Left over by FIX-SPAWN-GROUP-FIRST-ROUTE (ticket 01, "Not done"): "a combat zone gives the route of the groups its elements spawn from its own hook, in the same frame (`veafCombatZone.lua`, `registerSpawnedGroupsHook`); same defect, outside this ticket." David, 2026-11-22: create the lot.

## Read (2026-11-22)

- `veafCombatZone.lua`, `VeafCombatZone:spawnElement`, the `getVeafCommand()` branch (lines 1953-2001): the zone registers a hook with `veaf.registerSpawnedGroupsHook`, then runs the element's command through `veafInterpreter.execute`. The hook ends with `veaf.goRoute(newGroup, zoneElement:getRoute())` (line 1995).
- `veaf.collectSpawnedGroup` (`veaf.lua` line 5116) calls the hook as soon as the spawn records the group, so in the group's creation frame. Measured by the dcs-cartographie session (2026-11): an order given in that frame is lost, 3 times out of 3; 5 s later it is taken. The group stays where it spawned, with no message.
- The other branch, a Mission Editor group respawned (`VeafGroupSpawn`, `:withRoute(zoneElement:getRoute())`, around line 1910), carries its route in the group's definition: not concerned.
- FIX-SPAWN-GROUP-FIRST-ROUTE added `veafSpawn.giveFirstRoute(groupName, route)` (`veafSpawnCore.lua` line 237): the route `CONVOY_FIRST_ORDER_DELAY_SECONDS` (5 s) later, none when the group is gone, the last order per group name wins.
- Concerned: every mission with combat zones whose elements are VEAF commands with a route (training missions, Open Training), not the dynamic campaign.

## Decided

David, 2026-11-22: one lot, one ticket. The integration branch is `feature/dynamic-campaign`: one branch and one pull request into it.

| # | Ticket |
|---|---|
| 01 | [The zone's route 5 s after the birth](tickets/01-zone-route-after-birth.md) |
