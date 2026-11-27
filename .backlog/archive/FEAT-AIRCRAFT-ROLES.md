# FEAT-AIRCRAFT-ROLES — one way to spawn an aircraft with a job to do

Status: ✅ done — verified in game 2026-10-03 (R21) · archived 2026-11-24

Origin: David, 2026-10-02, from the Tacview of *Ligne rouge d'At Tanf* (2026-10-01).

## What the Tacview showed

The QRA of Sayqal scrambled three times — at 2 700 s, 3 990 s and 5 160 s — and each time the pair of
MiG-29S appeared at 5 262 m over Sayqal, descended in turns, flared on runway heading 090 at 695 m
and vanished, four and a half minutes after appearing. Nobody was intercepted.

The group `QRA-Sayqal-MiG29` has **one waypoint, at its own position, and no task at all** — the shape
`create_qra` builds. `VeafQRACore:deploy` clones it with its editor route, so the AI reaches the end of
its route the moment it exists and does what DCS does then: it lands at the nearest airfield. The QRA
sees no unit in the air (`not qraInAir`), calls `rearm()`, which removes the group, and scrambles again
`delay_before_activating` (900 s) later — 1 020 s and 910 s measured between landing and the next
scramble.

The Open Training Caucasus v5 QRA groups work because their mission maker built what this one lacks:
three waypoints, `EngageTargetsInZone` (`Air`) and a race-track `Orbit` on the second.

## The decision

The QRA module, not the mission maker, makes sure a scrambled interceptor has a job — at clone time, so
a mission picks up every later improvement of the script by being rebuilt:

- the template's route already engages air targets → the mission maker chose his own setup, it is used;
- otherwise → the clone is given a route and tasking.

Narrowed by David on 2026-10-02, once the rule met an air wave of bombers: only a group **tasked `CAP` or
`Intercept`** in the editor is concerned — any other task flies its route, whatever it engages. Ground
starts are included: the take-off point is kept and the patrol follows it at 27 000 ft.

And that tasking is not QRA code. David asked for **one method to spawn aircraft with a role** (CAP,
escort, defensive patrol…) used everywhere in the code. This lot builds it, with the two roles the code
needs today, and moves `-cap` onto it.

## Scope

| # | Ticket | Type | Status |
|---|--------|------|--------|
| 01 | [Spawn an aircraft with a role](FEAT-AIRCRAFT-ROLES.md) | feat | ✅ |
| 02 | [A scrambled group with no air engagement defends its zone](FEAT-AIRCRAFT-ROLES.md) | feat | ✅ |
| 03 | [An aircraft command run by a QRA or a wave defends that zone](FEAT-AIRCRAFT-ROLES.md) | feat | ✅ |
| 04 | [The command layer leaves an aircraft with a role alone](FEAT-AIRCRAFT-ROLES.md) | fix | ✅ |
| 05 | [The build says what a QRA or wave group will do](FEAT-AIRCRAFT-ROLES.md) | feat | ✅ |
| 06 | [Documentation, `create_qra`, the in-game check](FEAT-AIRCRAFT-ROLES.md) | docs | ✅ |

## Out of scope, and why (agreed with David 2026-10-02)

| Site | Why not now |
|---|---|
| `-afac`, the `-cas` AFAC | works today and no test asserts its route: migrating it blind risks a regression nothing would see |
| escort, AWACS | roles that do not exist yet; `FEAT-AWACS-ESCORT-COMMANDS` waits on #101 / #107 and will add its roles here |
| tankers, carrier, `_move` | they rewrite the mission of an aircraft **already flying**, a different call shape |
| OnDemand CAP (combat mission) | an editor group with its own route; can adopt rule (a) later |

`REFACTOR-SPAWN-AIR-TEMPLATES` stays paused: template selection is unchanged here.
`FEAT-AIRWAVES-QRA-MERGE` gains a shared spawn path for both modules.

## Definition of done

- [x] `-cap` spawns the same group, route and tasking as before, proven by a test written first
- [x] A QRA or wave `CAP`/`Intercept` group with no air engagement in its route is cloned with the `zone_defense` role;
      one that engages air keeps its editor route — both asserted on what `coalition.addGroup` receives
- [x] A `-cap` run by a QRA or a wave defends that zone, with a single watchdog
- [x] An aircraft with a role keeps its route and its ROE through the command layer and a combat zone
- [x] The build: empty route → information (given `zone_defense`); route without air engagement →
      non-blocking warning; route that engages air → information
- [x] Docs FR + EN, `create_qra` description, CHANGELOG, `DCS-SESSION-TODO.md` item for the game
- [x] Lua + Python gates green, coverage floors bumped

## In-game check — 2026-10-03

From `FIX-IN-GAME-SESSION-2026-10-03`.

*Ligne rouge d'At Tanf* rebuilt from `develop`, QRA Sayqal triggered by an AI stand-in: `dcs.log`
reads `QRA-Sayqal-MiG29 engages no aircraft by itself: it defends the zone`; the pair flew level to
the zone, shot the intruder down with an R-77, and flew a race-track of about 35 km for ten minutes
without landing. A `-cap` spawned from a marker had a route and turned. The race-track lies beside
the zone rather than across it: `FIX-IN-GAME-SESSION-2026-10-03` ticket 06.

## Former index entry

The row this lot had in `.backlog/README.md` until the index was split into short summaries (CHORE-BACKLOG-INDEX-SPLIT, 2026-10-03), kept verbatim.

**one way to spawn an aircraft with a job to do.** The Tacview of *Ligne rouge d'At Tanf* (2026-10-01): the Sayqal QRA scrambled three times and landed three times, four and a half minutes after appearing — its group, built by `create_qra`, has one waypoint and no task. The QRA (and AirWaves) now give a `CAP`/`Intercept` group whose route engages no aircraft the `zone_defense` role at clone time; the role comes from a new `veafAircraftSpawn` module that `-cap` moves onto, and the build says which groups get it. Waits on the in-game check (`DCS-SESSION-TODO.md` R21).

## Tickets, in full

## 01 — Spawn an aircraft with a role

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

### Definition of done

- [x] Characterisation test first: what `coalition.addGroup` receives for a `-cap` (three waypoints,
      the template's first-waypoint options, `SwitchWaypoint` 3 → 2), `PROHIBIT_AA` set, the watchdog
      scheduled with the zone between waypoints 2 and 3
- [x] Same test green after the move
- [x] The watchdog reads its zone from a per-group registry, so a role change re-aims it instead of
      starting a second one

## 02 — A scrambled group with no air engagement defends its zone

Status: ✅ done

Type: feat

`VeafQRACore:deploy` and `AirWaveZone:deployWaves` clone a DCS group with its editor route. When that
group is tasked `CAP` or `Intercept` in the editor and its route has no air engagement task
(`EngageTargets` / `EngageTargetsInZone` whose target types are aircraft), the clone gets the
`zone_defense` role instead: first waypoint at the spawn spot with the template's own options, a
race-track centred on the zone along the spawn → centre axis, and the CAP watchdog bounded by the zone.
A route that does engage air is used as the mission maker wrote it, and so is the route of any other
task — a bomber or assault wave flies its mission (David, 2026-10-02).

A group that starts on the ground keeps its take-off point as the first waypoint, untouched, and climbs
to 27 000 ft for the leg (David, 2026-10-02: ground starts included).

Ground groups are not concerned.

### Definition of done

- [x] `veafAircraftSpawn.routeEngagesAir(route)` — the rule, tested on the shapes found in real
      missions (Open Training v5 CAP, ME auto task, the `create_qra` single point)
- [x] QRA and AirWaves: what `coalition.addGroup` receives, for a group without and with engagement,
      and for a strike group — each test proven to fail with the wiring removed

## 03 — An aircraft command run by a QRA or a wave defends that zone

Status: ✅ done

Type: feat

A QRA or wave entry such as `-cap mig29` spawns a CAP that patrols around the zone centre with its
own 60 NM zone. After the command, every group it spawned that carries a fighter role is re-assigned
`zone_defense` on the QRA / wave zone — through the watchdog registry, so it keeps one watchdog.

### Definition of done

- [x] Test: a QRA command spawning a CAP ends with the zone_defense route and the QRA zone in the
      registry, and one watchdog scheduled
- [x] Same wiring for an air wave, both tests proven to fail with it removed

## 04 — The command layer leaves an aircraft with a role alone

Status: ✅ done

Type: fix

Two defects found while mapping the spawn sites:

1. `veafSpawn.executeCommand` calls `veaf.readyForCombat` on every group a handler returns, which sets
   ROE weapons free on a CAP the watchdog has just put on `PROHIBIT_AA`.
2. It then calls `veaf.goRoute(group, route)` whenever a route was passed — even when the handler said
   `routeDone` — and `VeafCombatZone`'s command hook does the same with the marker group's route. A
   `-cap` in a combat zone loses its patrol.

An aircraft known to `veafAircraftSpawn.getRole` is skipped by both.

### Definition of done

- [x] Tests on `executeCommand` and on the combat-zone hook

## 05 — The build says what a QRA or wave group will do

Status: ✅ done

Type: feat

For each DCS aircraft group tasked `CAP` or `Intercept` that a QRA or an air wave deploys:

| Route | Message |
|---|---|
| empty: at most one waypoint, carrying nothing but options | information: it is given `zone_defense` — the Sayqal case, which nothing in the editor shows (David, 2026-10-02: "c'est justement l'origine de ce lot") |
| present, without air engagement | non-blocking warning: it will be replaced by `zone_defense` |
| engages air | information: used as written |

Any other task flies its route and is not reported. The rule mirrors `veafAircraftSpawn.routeEngagesAir`
and `needsZoneDefense`; a test reads the Lua tables (air target types, engagement task ids, zone-defense
tasks) and compares them with the Python ones, so the two cannot drift.

The build reports it on its own (`report_deployed_aircraft_routes`), not under the "missing mission.yaml
references" summary; `veaf-tools validate` carries the warning too.

### Definition of done

- [x] `mission_builder/aircraft_roles.py` + tests, wired into the build and `validate`

## 06 — Documentation, `create_qra`, the in-game check

Status: ✅ done — verified in game 2026-10-03

Type: docs

- `doc/mission-maker/scripts/veafQraManager.md` + `.en.md`: what a scrambled group does now
- `create_qra` description: the interceptor is placed airborne and the QRA module gives it its job
- `CHANGELOG.md` under `[Unreleased]`
- `DCS-SESSION-TODO.md`: a QRA built by `create_qra` intercepts instead of landing

Also the `veafAirWaves` pages (same rule for a wave), the plugin's `veaf-mission-authoring` skill, the
`create_qra` section of the MCP developer page, and the `doc/TESTING` suite list.

### Definition of done

- [x] Docs FR + EN, `create_qra` description, CHANGELOG, `DCS-SESSION-TODO.md` R21
- [ ] R21 run in game — the only thing left, and the lot waits on it
