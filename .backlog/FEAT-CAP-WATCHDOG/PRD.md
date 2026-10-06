# FEAT-CAP-WATCHDOG — remove a spawned CAP by a handle, and a watchdog that picks its fights

Status: 🧑 waiting-human — done on the mocks, waits on R42 in `DCS-SESSION-TODO.md`

Origin: two 2023 requests left open by the issue triage,
[#178](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/178) (a token to destroy the CAPs a
`-cap` spawned) and [#187](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/187) (watchdog
changes). Both were parked on 2026-08-18 behind Mission B of `CHORE-ISSUE-VERIFY-SESSION`, on the idea
that one CAP lot would cover four issues. Mission B is closed: #209 was not reproducible and #240 was
fixed on its own by `FIX-CAP-SIDE-TEMPLATES`. Nothing was left to wait for, so these two get their own
lot. Opened 2026-10-03 at David's request.

## What the code does today (`develop`, 2026-10-03)

**Removing a CAP.** `veafSpawn.destroy(spawnSpot, radius, unitName)` (`veafSpawnObjects.lua:285`)
already destroys a group by name. What is missing is a name a pilot can type: `spawnCombatAirPatrol`
names the group `<template> #NNNN` (`veafSpawnAircraft.lua`) and its message —
`spawn.cap_spawned` — gives the template and the country, not the group name. The radius form of
`-destroy` (100 m around the marker) cannot reach an aircraft in flight.

**Choosing targets.** `veafSpawn.startCapWatchdog` (`veafSpawnAircraft.lua:1165`):

- the priority of a target is its **type** (fighter, bomber, UAV, AWACS, transport, helicopter…) and
  its **distance** from the CAP group, nothing else;
- the `EngageUnit` tasks are pushed on the **group** controller, sorted by priority, so every aircraft
  of the CAP goes for the same target;
- `isCapEngageableTarget` keeps aircraft only (attribute `Air`), so a cruise missile is never a target;
- there is no notion of an escort, of the target's aspect (hot, cold, flanking), nor of a priority
  beyond which a target is not worth engaging.

## What #187 asks, item by item

| Item | Today |
|---|---|
| Shared targets — not everyone on the same one | not done: tasks go to the group |
| Cruise missiles | not done: aircraft only, by design of the 2026-09-01 parachute fix |
| Escort handling | not done |
| Aspect (hot, cold, flanking) in the priority | not done |
| A max (or min) priority so as not to engage anything, depending on the mission (escort vs CAP) | not done |

## Tickets

| # | Ticket | Status |
|---|---|---|
| 01 | [A handle to remove a spawned CAP (#178)](tickets/01-cap-removal-handle.md) | 🚫 |
| 02 | [The watchdog spreads its CAP over several targets (#187)](tickets/02-watchdog-shared-targets.md) | 🧑 |
| 03 | [Aspect and a priority cut-off in the target ranking (#187)](tickets/03-watchdog-aspect-and-cutoff.md) | 🧑 |
| 04 | [Cruise missiles and escorts — decide first (#187)](tickets/04-watchdog-missiles-and-escort.md) | 🚫 |

## Decisions (David, 2026-10-04)

- **01 dropped**: no handle; `-destroy` is geographic and stays `SENIOR_PILOT`, a radius placed on the CAP removes it. The CAP section of the mission-maker page says how.
- **02 coded before measuring**: each aircraft gets its own target on its own controller; whether DCS honours it is R42.
- **03 reframed**: the escort left the watchdog with #1068, so the cut-off is *a cold target more than 40 km away is not chased*, the same for `cap` and `zone_defense`.
- **04 dropped**: cruise missiles unmeasured and unspecified; escorting a friendly group is `-escort`.

## Related

- `FIX-IN-GAME-SESSION-2026-10-03` ticket 04, *the CAP watchdog keeps adding tasks*: same function,
  measured on 2026-10-03. Reading that one first is cheaper — any change to how tasks are pushed here
  lands on top of it.
- `FEAT-AIRCRAFT-ROLES` gives groups a CAP role whose watchdog this lot changes.

## Definition of done

- [x] Every ticket done or explicitly dropped with its reason.
- [x] Lua tests for each behaviour change, failing without it.
- [x] Mission-maker doc (FR + EN) updated for the new command or option.
- [x] CHANGELOG under `[Unreleased]`.
- [ ] In-game check of the watchdog changes (they cannot be settled by mocks) — R42 in `DCS-SESSION-TODO.md`.
- [x] #178 and #187 closed, pointing here (both closed on 2026-10-03 when the lot was opened).

## Former index entry

The row this lot had in `.backlog/README.md` until the index was split into short summaries (CHORE-BACKLOG-INDEX-SPLIT, 2026-10-03), kept verbatim.

**remove a spawned CAP by a handle, and a watchdog that picks its fights** ([#178](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/178), [#187](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/187)). Both 2023 requests were parked behind Mission B of `CHORE-ISSUE-VERIFY-SESSION`, which is closed: #209 not reproducible, #240 fixed on its own. Today a `-cap` group is named `<template> #NNNN` and nobody is told; the watchdog ranks by type and distance only and tasks the whole group onto one target, aircraft only. Four tickets: a removal handle, shared targets, aspect and a priority cut-off, and a decision on cruise missiles and escorts. Read `FIX-IN-GAME-SESSION-2026-10-03` ticket 04 first — same function
