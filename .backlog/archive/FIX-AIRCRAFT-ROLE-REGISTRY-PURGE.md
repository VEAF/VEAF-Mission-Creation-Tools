# FIX-AIRCRAFT-ROLE-REGISTRY-PURGE — the aircraft role registry is never purged

Status: ✅ done — merged in #1080 (2026-10-05) · archived 2026-11-24

## Problem

`veafAircraftSpawn` keeps three tables keyed by group name: `groupRoles`, `groupOptions`, `groupRoutes`.
They are written on every spawn or re-tasking with a role and never cleared.
The CAP watchdog, which reads them, purges its own three tables in `forgetCapWatchdog` but not these.
Over a server session, they keep one entry per role group, each carrying a full route.

## What the issue got wrong

Issue #1079 claimed a destroyed group's name is recycled, so a later group without a role could inherit a stale role and be left on the wrong route.
It cannot today: `veaf.isNameTaken` reads the spawned-name registry, not whether the group lives, and only the AFAC releases its name (`veafSpawnAircraft.lua`, `releaseSpawnedName`).
`-cap` names use a counter that only goes up, escorts and QRA or wave clones go through `freeNameFrom`, and the only groups respawned under a fixed name (combat-zone editor groups, AFACs) never have a role.
So what remains is a bounded memory leak, not a misrouted group.

## Decision

David, 2026-10-05: option 1 — a `veafAircraftSpawn.forgetGroup` called from `forgetCapWatchdog`, plus a comment on the issue correcting its premise.

Only `cap` and `zone_defense` start the watchdog (`guardTheZone`).
The other roles — `orbit`, `patrol`, `attack`, `transport`, `escort`, `parked`, `awacs`, `air_escort` — have no point where their group is known to be gone, so `veafAircraftSpawn.forgetGoneGroups` sweeps out every group DCS no longer knows on the next spawn with a role (David, 2026-10-05).

## Tickets

- [01 — forget the role registry with the CAP watchdog](FIX-AIRCRAFT-ROLE-REGISTRY-PURGE.md)

## Tickets, in full

## 01 — forget the role registry with the CAP watchdog

Status: ✅ done — #1080

`veafAircraftSpawn.forgetGroup(groupName)` clears the group's entry in `groupRoles`, `groupOptions` and `groupRoutes`.
`forgetCapWatchdog` (`src/scripts/veaf/veafSpawnAircraft.lua`) calls it, so every path where the watchdog stops watching a group — gone from DCS, no position, landed and destroyed, no controller — also forgets its role.
The other roles have no watchdog: `veafAircraftSpawn.forgetGoneGroups` forgets every group `Group.getByName` no longer answers, and runs on each spawn with a role (`spawnAirplaneGroup`, `spawnHelicopterGroup`, `VeafAircraftSpawn:spawn`).
`dcs_mocks.resetVeafRuntimeState` resets `groupRoutes` along with the other two.

### Acceptance

- Tests through `veafSpawn.startCapWatchdog` (`test/lua/test_veafSpawn.lua`): a CAP that landed and a CAP gone from DCS leave nothing in the three tables; both fail before the fix.
- Test through `spawnCombatAirPatrol` (`test/lua/test_veafAircraftSpawn.lua`): a spawn with a role forgets a group DCS no longer knows and keeps one it does.
- `poetry run test-lua` and `stylua --check` pass; `luacheck` in CI.
