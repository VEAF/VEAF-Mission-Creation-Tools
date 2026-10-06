# FIX-AIRCRAFT-ROLE-REGISTRY-PURGE — the aircraft role registry is never purged

Status: ✅ done — merged in #1080 (2026-10-05)

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

- [01 — forget the role registry with the CAP watchdog](tickets/01-forget-role-registry.md)
