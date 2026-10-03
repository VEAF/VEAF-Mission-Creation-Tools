# FEAT-AIRCRAFT-ROLES — one way to spawn an aircraft with a job to do

Status: ✅ done — verified in game 2026-10-03 (R21)

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
| 01 | [Spawn an aircraft with a role](tickets/01-spawn-an-aircraft-with-a-role.md) | feat | ✅ |
| 02 | [A scrambled group with no air engagement defends its zone](tickets/02-a-scrambled-group-defends-its-zone.md) | feat | ✅ |
| 03 | [An aircraft command run by a QRA or a wave defends that zone](tickets/03-an-aircraft-command-defends-the-zone.md) | feat | ✅ |
| 04 | [The command layer leaves an aircraft with a role alone](tickets/04-the-command-layer-leaves-a-role-alone.md) | fix | ✅ |
| 05 | [The build says what a QRA or wave group will do](tickets/05-the-build-says-what-the-group-will-do.md) | feat | ✅ |
| 06 | [Documentation, `create_qra`, the in-game check](tickets/06-documentation-and-in-game-check.md) | docs | ✅ |

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
