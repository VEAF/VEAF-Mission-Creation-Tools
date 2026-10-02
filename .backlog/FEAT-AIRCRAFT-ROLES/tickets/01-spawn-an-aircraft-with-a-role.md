# 01 — Spawn an aircraft with a role

Status: ✅ done

Type: feat

A new module, `veafAircraftSpawn`, owns how an aircraft group is spawned and given a job:
`VeafAircraftSpawn:new():fromGroup(template):at(spot):withRole(name, params):spawn()`, and
`veafAircraftSpawn.assignRole(groupName, name, params)` for a group already flying.

A role is three things: the route it flies, the options its first waypoint carries, and what runs
after the spawn (the CAP watchdog for the fighter roles). A group spawned with a role is remembered
by name, so the rest of the framework can ask `veafAircraftSpawn.getRole(groupName)`.

The first role is `cap`: the route and tasking `veafSpawn.spawnCombatAirPatrol` builds today, moved,
not rewritten. `spawnCombatAirPatrol` keeps parsing the `-cap` options and choosing the template.

## Definition of done

- [x] Characterisation test first: what `coalition.addGroup` receives for a `-cap` (three waypoints,
      the template's first-waypoint options, `SwitchWaypoint` 3 → 2), `PROHIBIT_AA` set, the watchdog
      scheduled with the zone between waypoints 2 and 3
- [x] Same test green after the move
- [x] The watchdog reads its zone from a per-group registry, so a role change re-aims it instead of
      starting a second one
