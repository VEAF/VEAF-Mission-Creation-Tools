# FEAT-AIRCRAFT-ROLES — one way to spawn an aircraft with a job to do

Status: 🔄 in-progress

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

And that tasking is not QRA code. David asked for **one method to spawn aircraft with a role** (CAP,
escort, defensive patrol…) used everywhere in the code. This lot builds it, with the two roles the code
needs today, and moves `-cap` onto it.

## Scope

| # | Ticket | Type | Status |
|---|--------|------|--------|
| 01 | [Spawn an aircraft with a role](tickets/01-spawn-an-aircraft-with-a-role.md) | feat | 🔄 |
| 02 | [A scrambled group with no air engagement defends its zone](tickets/02-a-scrambled-group-defends-its-zone.md) | feat | ✅ |
| 03 | [An aircraft command run by a QRA or a wave defends that zone](tickets/03-an-aircraft-command-defends-the-zone.md) | feat | ✅ |
| 04 | [The command layer leaves an aircraft with a role alone](tickets/04-the-command-layer-leaves-a-role-alone.md) | fix | ✅ |
| 05 | [The build says what a QRA or wave group will do](tickets/05-the-build-says-what-the-group-will-do.md) | feat | ✅ |
| 06 | [Documentation, `create_qra`, the in-game check](tickets/06-documentation-and-in-game-check.md) | docs | ⬜ |

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

- [ ] `-cap` spawns the same group, route and tasking as before, proven by a test written first
- [ ] A QRA or wave group with no air engagement in its route is cloned with the `zone_defense` role;
      one that engages air keeps its editor route — both asserted on what `coalition.addGroup` receives
- [ ] A `-cap` run by a QRA or a wave defends that zone, with a single watchdog
- [ ] An aircraft with a role keeps its route and its ROE through the command layer and a combat zone
- [ ] The build: empty route → nothing; route without air engagement → non-blocking warning; route
      that engages air → information
- [ ] Docs FR + EN, `create_qra` description, CHANGELOG, `DCS-SESSION-TODO.md` item for the game
- [ ] Lua + Python gates green, coverage floors bumped

## Hand-off — 2026-10-02, to the next session

Started from the Syria mission's session and stopped there on purpose: this lot belongs to a VMCT
session. Branch `feature/FEAT-AIRCRAFT-ROLES`, worktree `.claude/worktrees/feat-aircraft-roles`,
**not pushed**. Delete this section once read.

Done:

- `92c42351` — **a real defect, found while pinning `-cap`**: since #842 (2026-08-30)
  `VeafGroupSpawn:withRoute` wrapped the `{ points = … }` table the CAP and AFAC builders hand it, so
  DCS received `route.points.points` and **every `-cap` and `-afac` spawned with no waypoint**.
  `mist.teleportToPoint` used to take the route table as given. Fixed in `withRoute` (both shapes
  accepted, like `veaf.addGroup`), test in `test_veafDcsSpawner.lua`. Worth its own CHANGELOG line.
- `51aab6d3` — ticket 01: `src/scripts/veaf/veafAircraftSpawn.lua` (bundled after
  `veafSpawnAircraft.lua`, loaded by the `veafSpawn.lua` proxy). Roles `cap` (moved unchanged out of
  `spawnCombatAirPatrol`, pinned by `TestAircraftSpawnCapContract`) and `zone_defense` (written, **not
  yet tested**). `veafSpawn.capWatchdogZones[groupName]`: the watchdog reads its zone there every
  tick and clears it when it stops, so `veafAircraftSpawn.assignRole` re-aims a running watchdog
  instead of starting a second. 51 Lua suites green (`python -m veaf_build.lua_tests`; plain `lua`
  from `test/lua` shows 3 pre-existing cwd errors in `test_veafGroundAI.lua`).

Next, in order:

1. Ticket 02 — tests for `routeEngagesAir`, `firstWaypointOptions`, `needsZoneDefense`,
   `zoneToDefend`, the `zone_defense` route; then wire `VeafQRACore:deploy` (`veafQraCore.lua`, DCS-group
   branch) and `AirWaveZone:deployWaves` (`veafAirWaves.lua`): `if zone and
   veafAircraftSpawn.needsZoneDefense(g) then VeafAircraftSpawn:new():fromGroup(g):at(spot)
   :withRadius(r):withRole("zone_defense", { zone = zone }):spawn() else <existing clone>`. Zone from
   `veafAircraftSpawn.zoneToDefend(triggerZone, self.zoneCenter, self.zoneRadius)`. The QRA test
   harness to copy is `TestVeafQraOffsetAxes` (`test_veafQraManager.lua`); its file must also load
   `veafSpawn.lua` + `veafAircraftSpawn.lua`. Note the mock `Group.Category` values differ from DCS.
2. Ticket 03 — after `veafInterpreter.execute` in both command branches: every spawned group whose
   `veafAircraftSpawn.getRole(name) == "cap"` → `assignRole(name, "zone_defense", { zone = zone })`.
3. Ticket 04 — `veafSpawn.executeCommand` (`veafSpawnCore.lua`, ~line 408): skip `readyForCombat`
   and `goRoute` for a group with a role (note `routeDone` does not stop the `elseif route` branch
   today); same skip in the combat-zone command hook (`veafCombatZone.lua`, `veaf.goRoute(newGroup,
   route)`).
4. Ticket 05 — `mission_builder`: classify each QRA/AIRWAVES DCS aircraft group (empty → nothing,
   present without air engagement → warning, engages air → info), wired beside
   `find_missing_declared_groups`; a test compares the Python air target types with
   `veafAircraftSpawn.AIR_TARGET_TYPES`.
5. Ticket 06 — docs FR/EN, `create_qra` description, CHANGELOG, `DCS-SESSION-TODO.md`.
6. Quality gates, PR, `pr-code-review`.
