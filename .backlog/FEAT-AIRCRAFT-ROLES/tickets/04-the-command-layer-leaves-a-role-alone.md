# 04 — The command layer leaves an aircraft with a role alone

Status: ✅ done

Type: fix

Two defects found while mapping the spawn sites:

1. `veafSpawn.executeCommand` calls `veaf.readyForCombat` on every group a handler returns, which sets
   ROE weapons free on a CAP the watchdog has just put on `PROHIBIT_AA`.
2. It then calls `veaf.goRoute(group, route)` whenever a route was passed — even when the handler said
   `routeDone` — and `VeafCombatZone`'s command hook does the same with the marker group's route. A
   `-cap` in a combat zone loses its patrol.

An aircraft known to `veafAircraftSpawn.getRole` is skipped by both.

## Definition of done

- [x] Tests on `executeCommand` and on the combat-zone hook
