# FIX-COMBATZONE-SPAWN-ROUTE-OFFSET — a zone drops a group beside its route, not on it

Status: ⬜ ready

Origin: found on 2026-08-19 while instructing `FIX-COMBATZONE-CONVOY-ALARM`, and split out at
David's request so the alarm-state decision shipped on its own.

## What was measured

`VeafCombatZone:spawnElement` hands `mist.teleportToPoint` these vars: `gpName`, `name`,
`newGroupName`, `route`, `action`, `point`, `renameUnitsSequentially`
(`veafCombatZone.lua:1090-1098`). It sets **none** of `offsetRoute`, `offsetWP1` or `initTasks` — and
in MiST, waypoint translation by the teleport delta is gated on exactly those three
(`mist.lua:4561`).

Two consequences, both of which contradict what `FIX-COMBATZONE-CONVOY-ALARM`'s PRD originally
assumed:

1. `vars.route` is `nil` for a mission group, because `setRoute()` is only called in the `#command=`
   branch (`veafCombatZone.lua:831`). MiST therefore falls back to
   `mist.getGroupRoute(gpName, true)` (`mist.lua:4551`) — the group's **original** route, at its
   **original** coordinates.
2. The group is respawned at `vars.point`, which `spawnRadius` scatters (default 50 m for units,
   `veafCombatZone.DefaultSpawnRadiusForUnits`). So the group appears up to 50 m away from a route
   whose waypoint 1 is still at the editor position.

Observed in game on 2026-08-17: the convoy did drive its route once its alarm state let it move — DCS
simply routes the group to waypoint 1 first. So this is **not** a blocking defect; it is a group
walking a leg nobody drew.

## The question this lot has to answer

Setting `offsetRoute = true` translates the whole route by the spawn delta, which is almost certainly
the intent — but it changes where every combat-zone group with a route ends up, so it is a behaviour
change on existing missions and wants its own verification pass.

Also worth deciding: whether a zone with `spawnRadius = 0` (statics) should skip the offset entirely,
since the delta is then zero and the extra work is pointless.

## Definition of done

- [ ] Decide between `offsetRoute` (whole route follows the group) and `offsetWP1` (only the first
      waypoint moves, later ones stay drawn where the designer put them) — they are not the same
      mission-design promise
- [ ] Lua tests over the vars `spawnElement` builds, since the MiST side cannot be exercised here
- [ ] Verified in game: a combat-zone convoy with a scattered spawn drives from where it appeared,
      not back to its editor position first
- [ ] Documented on the `veafCombatZone` page (both languages) if the behaviour visibly changes
