# FIX-IN-GAME-SESSION-2026-10-03 — what a DCS session flown without a pilot found

Status: ✅ done — merged in #1054 and #1055 (2026-10-03); every ticket done or closed (05, 07 wontfix) · archived 2026-11-24

Origin: the DCS session of 2026-10-03, run without anyone at the controls. Five missions were built
from `develop` (`d333d58a`, dev mode) in `D:\dev\_VEAF\tmp\dcs-session-2026-10-03\`; David loaded
them and took a slot; every check went through the fiddle hook (Lua run inside the mission), with AI
aircraft standing in for players. David looked at four things: a smoke, a map, a slot list and a
radio menu.

## What the session settled

Each line closes or advances the lot named; the lots carry the measurement.

| `DCS-SESSION-TODO` item | Lot | Result |
|---|---|---|
| R1 | `FIX-SKYNET-SITE-GOES-DARK-BEFORE-FIRING` | ✅ both SA-6 light at 25 km, stay lit and fire |
| R2 | `FIX-WAREHOUSES-INCREMENTAL` | ✅ 225 airfields in game, an untouched one keeps its warehouse |
| R3 | `FIX-WAREHOUSES-LIST-FORM` | ✅ the three assigned airfields hold their coalition |
| R5 | `FIX-ESCORT-RESPAWN-DISTANCE` | ✅ the escort comes back with the tanker, 1.0–1.8 km; shot down, it comes back and escorts |
| R7 (wave half) | `FIX-AIRWAVES-COMMAND-EASTING` | ✅ `[5000,0]` lands 5.2 km north, the default offset 4 km N / 7 km W |
| R9 | `FIX-AIR-SPAWN-ALTITUDE-GUARD` | ❌ **DCS does not lift** an aircraft spawned 15 m above the trees: it crashes within a second |
| R11 | `FIX-CAP-ENGAGES-PARACHUTES` | ✅ the CAP fires on a fighter, never lists a parachute |
| R12 | `FIX-TUTORIAL-FIRST-RUN` 05 | ✅ the scheduler runs the shell; the marker path failed for ticket 01 below |
| R13 | `FIX-TRIPACK-FIELD-REPORTS` 01 | ✅ Skynet wakes up, every site fires |
| R14 | `FIX-SKYNET-ADDS-DESTROYED-GROUPS` | ✅ no corpse enrolled at start; ❌ a deactivated zone's site stays (ticket 03 here) |
| R15 (group half) | `FIX-USER-REPORTS-985-989` | ✅ DCS keeps `hidden` on a group recreated by `coalition.addGroup` |
| R16 | `FIX-PLACEMENT-IGNORES-SCENERY` 12 | ✅ 8 vehicles under trees before `settleGroup`, 2 after, worst group 0.317 s |
| R17 | `FIX-IN-GAME-TEST-FINDINGS` | ✅ at start; the weapon-near-a-sanctuary line was not run |
| R18 | `FIX-PER-MODULE-LOGLEVEL-INERT` | ✅ only `VEAF-SPAWN` traces |
| R19 | `FIX-PLACEMENT-MOVES-ON-CLEAR-GROUND` | ❌ on open ground the escort moves: the FARP's own vehicles occupy its spot |
| R21 | `FEAT-AIRCRAFT-ROLES` | ✅ the QRA intercepts and flies a race-track, never lands; the `-cap` has a route |
| R22 | `FIX-USER-REPORTS-985-989` 02 | ✅ CSAR menu in a dynamic-slot UH-1 |
| R32 | `FIX-CAP-SIDE-TEMPLATES` | ✅ ten red `-cap`, ten red templates |
| cloned QRA engages | `FIX-TRIPACK-FIELD-REPORTS` 05 | ✅ an R-27 on the intruder |
| zone SA-6 radar range | `FIX-SKYNET-CZ-RESPAWN-AND-RANGE` (archived) | ✅ 46.8 km, the zone SA-6 fires |
| zone smoke (Paluche) | `FIX-TUTORIAL-FIRST-RUN` 05 | ✅ seen by David |
| CTLD airfield capture | `FEAT-CTLD-AIRBASE-LOGISTICS` | ✅ Kobuleti's capture message seen by David |

## The defects it found

| # | Ticket | Status |
|---|---|---|
| 01 | [Smoke and flare colours are named the way DCS names them](FIX-IN-GAME-SESSION-2026-10-03.md) | ✅ |
| 02 | [`logger:warning` does not exist](FIX-IN-GAME-SESSION-2026-10-03.md) | ✅ |
| 03 | [A deactivated zone's SAM site stays in the IADS](FIX-IN-GAME-SESSION-2026-10-03.md) | ✅ |
| 04 | [The CAP watchdog keeps adding tasks](FIX-IN-GAME-SESSION-2026-10-03.md) | ✅ |
| 05 | [A `-cap` zone drawing outlives its group](FIX-IN-GAME-SESSION-2026-10-03.md) | 🚫 |
| 06 | [The QRA race-track sits beside its zone](FIX-IN-GAME-SESSION-2026-10-03.md) | ✅ |
| 07 | [The editor's DCS stubs teach the wrong colour names](FIX-IN-GAME-SESSION-2026-10-03.md) | 🚫 |
| 08 | [`_spawn signal` fires the smoke colour](FIX-IN-GAME-SESSION-2026-10-03.md) | ✅ |

R9 and R19 are not tickets here: their lots exist, and the measurement goes there.

## One PR

Tickets 01 and 02 ship together, with the backlog, `DCS-SESSION-TODO.md` and
`known-limitations.yaml` brought up to date. 03 to 06 each need their mechanism understood before a
fix is chosen.

## The second PR

Tickets 03 to 08 go in one branch with the two lots the session advanced:
[`FIX-AIR-SPAWN-ALTITUDE-GUARD`](FIX-AIR-SPAWN-ALTITUDE-GUARD.md) (R9, the clearance floor) and
[`FIX-PLACEMENT-MOVES-ON-CLEAR-GROUND`](FIX-PLACEMENT-MOVES-ON-CLEAR-GROUND.md) (R19, the
escort beside its own FARP). David's calls of 2026-10-03, on the plan: every recommendation taken.

## The second pass (2026-10-03 afternoon)

Built from this branch, run without a pilot in `D:\dev\_VEAF\tmp\dcs-session-2026-10-03b\`. Seen
working: every coloured smoke from a marker, the `-farp` green smoke and red flares, the convoy smokes
(David's eyes), the signal flares, a wave whose only element is invalid skipped without freezing its
zone, R7's QRA half (a bracketed command and a bare one, both where they should land), R9's floor,
R17's last line (a FAB-250 dropped over the Holzdorf sanctuary, no error), and tickets 03, 04 and 06.
Two defects found during the run and fixed in the branch: the Skynet sweep fooled by a reused group id
(ticket 03's real cause) and the FARP bearing walk ignoring forests. In passing, David saw Arco's escort
engage the threats and rejoin formation.

## Former index entry

The row this lot had in `.backlog/README.md` until the index was split into short summaries (CHORE-BACKLOG-INDEX-SPLIT, 2026-10-03), kept verbatim.

**what a DCS session flown without a pilot found.** 2026-10-03, five missions built from `develop`, every check driven through the fiddle hook with AI stand-ins. 19 fixes seen working; two defects fixed here — marker smoke and flare colours named `RED` where DCS says `Red`, and a `logger:warning` that froze an AirWaves zone — and, in a second PR, the CAP watchdog that stacked a task per target per tick and could pop its own patrol (fixed), `_spawn signal` firing the smoke colour (fixed), `-cap` drawings (trace markers, wontfix), the editor stubs (not reproduced); a second in-game pass the same afternoon found the zone SAM's real cause — its respawn reuses the group id, so the old site's DCS object answers for the new one — and saw the QRA race-track back on its zone once the watchdog stopped chasing

## Tickets, in full

## 01 — smoke and flare colours are named the way DCS names them

Status: ✅ done
Type: fix

### Measured

`_spawn smoke, color red` asked from a marker on 2026-10-03: the confirmation came, no smoke, and
`dcs.log` read `VEAF-SCHEDULER|E| error in scheduled function: Parameter #2 (color) missed`.
`spawnSmoke` had received `color=[nil]`.

DCS names its colours with a capital and nothing else, read in game the same day:

| enum | keys |
|---|---|
| `trigger.smokeColor` | `Blue=4 Green=0 Orange=3 Red=1 White=2` |
| `trigger.flareColor` | `Green=0 Red=1 White=2 Yellow=3` |

Eleven sites wrote `RED`, `GREEN`, `WHITE`, `ORANGE`, `BLUE` — `nil` in DCS:

- `veafSpawnParser.lua`: every `color` option and the three smoke shortcuts — every coloured smoke
  or flare asked from a marker;
- `veafSpawnObjects.lua`: the green smoke and the red flares of `-farp` and of the FOB/beacon spawn;
- `veafSpawnGround.lua`: the start, end and group smokes of a convoy.

The combat-zone smoke wrote `Red` and worked (seen by David the same day).

### Why nothing caught it

The parser test asserted `r.smokeColor == trigger.smokeColor.RED`: `nil == nil`. The smoke mock was
right; the flare mock was wrong twice over (`RED = 0, GREEN = 1`, upper case and swapped).

### Done

- the sites use the DCS names; the flare mock carries the measured table;
- the parser and flare tests assert the DCS names, so they now compare against a number;
- the mocked `trigger.action.smoke` and `signalFlare` refuse a nil colour, as DCS does, so a colour
  that goes missing at runtime fails the suite too;
- `test/python/test_lua_names_that_exist.py` sweeps `src/scripts/veaf/` for any
  `trigger.smokeColor.X` / `trigger.flareColor.X` whose key DCS does not define. It failed on the 15
  uses before the fix.

### Not done, noted

`spawnSignalFlare` is handed `options.smokeColor`: a smoke colour used as a flare colour. Red, green
and white have the same number in both tables; orange (3) comes out yellow, blue (4) is no flare
colour at all.

## 02 — `logger:warning` does not exist

Status: ✅ done
Type: fix

### Measured

A wave whose element was not a valid command (`-spawn shilka`, the session mission's own mistake)
logged on 2026-10-03:

```
VEAF|E|safeCall: ... veaf-scripts.lua:39176: attempt to call method 'warning' (a nil value)
```

`veaf.Logger` has `warn`. `AirWaveZone._onEnterActive` called `:warning(` in the branch that reports
a failed deployment, so the report raised. The zone then logged no `check()` again: it stayed
`STATUS_ACTIVE` with nothing deployed, for the rest of the mission, until `start()` was called by
hand. One bad wave element froze its zone for good.

The same call sat in `veafSkynetIadsMonitor.lua`.

### Done

Both sites call `warn`. `test/python/test_lua_names_that_exist.py` checks that every
`veaf.loggers.get(...):m(` names a method `veaf.Logger` defines; it found exactly these two.

## 03 — a deactivated zone's SAM site stays in the IADS

Status: ✅ done — measured, fixed and verified in game 2026-10-03
Type: fix

### Measured

Tripack's `Skynet-test` mission (#946), rebuilt from `develop` on 2026-10-03. `TESTCZ` deactivated at
t=74 s and reactivated at t=84 s: the new SA-6 `TESTCZ [r] TESTCZ - SA6#10299` joined the network
(`GOING LIVE`), and the old `#10298` stayed listed by `iads:getSAMSites()` — still there at t=350 s,
although `Group.getByName` returned `nil` for it. Four sites became five.

`FIX-SKYNET-ADDS-DESTROYED-GROUPS` ticket 03 is meant to remove exactly this: a sweep every
`SecondsBetweenVanishedSitesSweeps` (60 s) drops a site whose group is gone and none of whose units
was reported lost. It did not, five sweeps in a row.

### What is already ruled out

The ledger's premise: DCS raises no `S_EVENT_DEAD` / `S_EVENT_UNIT_LOST` for a unit removed by
`Group:destroy()`. Checked the same day in another mission: a blue S-300 destroyed by script while an
event logger listened produced no loss event.

### Suspects, to settle with one instrumented run

1. the sweep was never armed in this configuration (the arming function returns early on a flag);
2. the zone's deactivation removes its groups by another path than `destroy()`, one that raises a
   loss event and so reads as a kill.

A `debug` log level on SKYNET shows the sweep's `removed N despawned element(s)` line, or its absence.

### Read before the run (2026-10-03, afternoon)

Both suspects are ruled out by the code and by `dcs.log` of the morning run:

1. the sweep **is** armed: `_armVanishedSitesSweep` is called just before `Skynet IADS has been
   initialized`, a line the log carries; no `VEAF-SCHEDULER|E|` line in the whole mission;
2. the zone removes its groups with `Group:destroy()` (`VeafCombatZone:destroySpawnedGroup`), and the
   respawn gives new group and unit ids (`veafDcsSpawner.lua`, `data.groupId = nil`).

What is left: either the stale site's `dcsRepresentation:isExist()` still answers `true`, or one of
its unit names is in `veafSkynet.lostUnits`. The log cannot tell: the removal line is at `debug` and
the module ran at `info`. The next run asks both directly, with the fiddle hook, then calls
`removeVanishedSites` by hand.

### Measured in game (2026-10-03, second pass)

`TESTCZ` deactivated and reactivated, then the stale site asked directly through the fiddle hook:

| | old site `#10211` |
|---|---|
| `Group.getByName("…#10211")` | nil |
| its stored object, `isExist()` | **true** |
| its stored object, `getName()` | **`…#10212`** — the new site |
| its stored object, `id_` | 44, the same as the new group |
| `lostUnits` | empty |

Neither suspect: the sweep runs, and no loss was recorded. `VeafGroupSpawn:respawn()` keeps the
template's ids (only `clone` drops them), so the zone's new SA-6 took group id 44 again, and a DCS
object being nothing but its id, the old site's object answered for the new group.

### Fixed

The sweep also counts an element as gone when its object answers a **different name** than the one
it was enrolled under (`_isGone`); an element Skynet named after an id is never compared. Hot-patched
in game before porting: `removeVanishedSites -> 1`, four sites again, the new SA-6 kept. Recorded as
`a-dcs-object-is-its-id` in `known-limitations.yaml`.

Not changed: `respawn()` keeping the template's ids under a new name. Anything else that holds a DCS
object across a zone cycle follows the new group the same way; worth its own look if another symptom
appears.

## 04 — the CAP watchdog keeps adding tasks

Status: ✅ done — verified in game 2026-10-03
Type: fix

### Measured

A `-cap` MiG-29S pair, watchdog traced on 2026-10-03: `numberOfTasksAddedByWatchdog` read 38, 43, 49
on three consecutive passes ten seconds apart, while the CAP kept engaging the same targets. Nothing
seen removes a task the watchdog pushed.

The same passes kept as targets aircraft **105 km** from the CAP zone's centre: intended — a `-cap`'s
zone is 60 NM (111 km) unless the marker says otherwise (`veafSpawnAircraft.lua`, `capRadius or 60`).

### Why

Tasks really accumulated. Every tick pushed an `EngageUnit` for **every** target still tracked, so a
CAP tracking five aircraft stacked five more tasks every ten seconds. Two consequences worse than the
count:

1. no task could be taken back individually — `popTask` only removes the top — so a target leaving the
   zone kept its task and the CAP kept chasing it, weapons safe;
2. the cleanup popped as many tasks as it had counted, but DCS removes a dead target's `EngageUnit` by
   itself: the count ran ahead of the queue and the extra pops removed the **patrol route**.

### Done

- the controller is touched only when the set of targets changes; a change sets the patrol again
  (`veafAircraftSpawn.resumePatrol`: the role's stored route, its first point moved to where the
  leader is) and pushes one `EngageUnit` per target still there;
- a CAP outside its zone with tasks outstanding gets its patrol back the same way;
- nothing is popped any more;
- tests: one task for a target tracked over four ticks, the patrol handed back with nothing popped,
  its first point at the leader, a queue rebuilt around the target that stays, a CAP outside its zone
  giving up — each proven red under a sabotage of the fix.

### To see in game

That `setTask` followed by `pushTask` in the same frame keeps both, and that a CAP whose fight is over
flies its race-track again.

### Seen in game (2026-10-03, second pass)

Three `-cap` watched for seven minutes on the Caucasus mission: on a tick where the targets did not
change, **no** `EngageUnit` was pushed (this morning: five or six more each tick). When the C-130 left
the MiG-31's list, the queue was rebuilt in one go (six tasks) and the MiG-31 came back to 12 km from
its zone's centre. At At Tanf, the Sayqal MiG-29S fired six R-77 and an R-73 at an immortal intruder;
when it was removed, `resumes its patrol` was logged and the pair flew back over the zone centre
(ticket 06). Not seen: a new shot *after* a rebuild — the MiG-31 had most likely emptied its rails.

## 05 — a `-cap` zone drawing outlives its group

Status: 🚫 wontfix — a trace marker, not a drawing of the feature
Type: fix

### Measured

Ten `-cap` spawned on 2026-10-03 each drew its patrol zone on the F10 map, visible to the blue side.
Nine of them were then removed with `Group:destroy()`: their drawings stayed (David's capture, the
same day).

### Why it is not a defect

The circle is `veaf.Logger:marker(…, "CAP", "targetZone", …)` in the `cap` role, which draws only when
the logger's effective level is `trace` (`veaf.lua`, `getEffectiveLevel() >= 5`). The session ran
VEAF-SPAWN at `trace` (R18). At the default level nothing is drawn — so nothing outlives anything, and
no side sees a CAP's zone. Trace markers are never cleaned up, by design of the debug aid. David's call,
2026-10-03.

## 06 — the QRA race-track sits beside its zone

Status: ✅ done — fixed by ticket 04, verified in game 2026-10-03
Type: fix

### Measured

*Ligne rouge d'At Tanf*, rebuilt from `develop` on 2026-10-03, QRA Sayqal triggered: the MiG-29S pair
flew 60 km from Sayqal to the edge of `QRA-Sayqal-Zone` (radius 35 km), intercepted, then flew legs
between **30 and 64 km** from the zone's centre — a race-track of about 35 km (19 NM), as
`zone_defense` intends, but lying on the far side of the zone rather than across it.

### To find out

How `zone_defense` places its two turn points from the group's position and the zone: centred on the
zone, or starting from where the group enters it.

### Read (2026-10-03, afternoon)

`zone_defense` places its turn points **centred** on the zone: `wp2` and `wp3` are the centre minus
and plus half a leg along the approach axis (`veafAircraftSpawn.lua`), and `QRA-Sayqal-Zone` is a
circle with its easting in `y` (read in the `.miz`). A race-track 30 to 64 km from the centre is not
what the route says.

The likely cause is ticket 04: an `EngageUnit` left on the queue for a target outside the zone kept
the CAP chasing it, and the cleanup could pop the route itself. Ticket 04 now hands the patrol back
when the targets change or the CAP leaves its zone. To measure again in game, positions every ten
seconds, before calling this one fixed.

### Verified in game (2026-10-03, second pass)

The Sayqal pair crossed its zone and turned back at 21 km (half a 20 NM leg, plus the turn) — the
race-track centred. Then an intercept: the pair chased out to 40 km while engaging, and once the target
was gone the watchdog handed the patrol back; the leader flew back in and passed **0.1 km** from the
zone's centre. This morning it kept circling 30 to 64 km out.

## 07 — the editor's DCS stubs teach the wrong colour names

Status: 🚫 wontfix — not reproduced (David, 2026-10-03: the editor does not flag the colours)
Type: chore

### Found

By the `pr-code-review` of #1054. The upper-case colour keys of ticket 01 were not an original
mistake: commit `7954b9fe` (2026-05-18, "fix(lint): … smokeColor case … DCS stubs") replaced correct
`Red` / `Green` with `RED` / `GREEN` to silence the editor. Its DCS stubs, the third-party addon in
`.lua-addons/dcs-world/library/mission/trigger.lua` (git-ignored, listed in `.luarc.json`'s
`Lua.workspace.library`), declare:

```lua
trigger.smokeColor = { GREEN = 0, Red = 1, RED = 1, ... }
trigger.flareColor = { GREEN = 0, RED = 1, WHITE = 2, ... }
```

DCS answers `Green`, `Red`, `White`, `Orange`, `Blue` / `Yellow` (measured 2026-10-03). Since #1054
the editor flags `Green`, `White`, `Orange`, `Blue` as undefined fields — against CLAUDE.md §3, "No
warnings or errors must remain in the editor" — and invites the same "fix" again.

### Already covered

A return to upper case fails CI: `test/python/test_lua_names_that_exist.py`.

### To do

Point the editor at the schema the repository already vendors and keeps current,
`src/python/veaf-tools/veaf_libs/data/dcs-schema/dcs-world-api.lua` (right names, lines 3461-3482),
instead of the addon's `mission` library — then check that the editor shows no new warning
elsewhere, since the two stub sets will not declare everything alike.

### Measured (2026-10-03, afternoon) — not reproduced

`lua-language-server --check` (the VS Code extension's own binary, 3.19.1), on this branch, with the
addon copied in: **no** `undefined-field` on `Green`, `White`, `Orange`, `Blue` or `Yellow` anywhere —
the vendored schema is already in `Lua.workspace.library` and declares them. 319 problems in all.

Dropping the addon's `mission` library, as proposed: **344** problems — 94 duplicate and
`inject-field` diagnostics on the schema go away, 119 new ones appear (`log` undefined in the server
hooks, stricter signatures in the schema). Not a gain, so `.luarc.json` is left as it is.

The question: does David's editor underline `trigger.smokeColor.Green` in `veafSpawnParser.lua`? If
not, close as not reproduced.

### Closed

David's answer, 2026-10-03: `trigger.smokeColor.Green` is not underlined in his editor. Not
reproduced, so nothing to fix; `.luarc.json` stays as it is.

## 08 — `_spawn signal` fires the smoke colour

Status: ✅ done — verified in game 2026-10-03
Type: fix

From ticket 01, "not done, noted": `spawnSignalFlare` was handed `options.smokeColor`. Red, green and
white share a number in both tables; orange (smoke 3) came out yellow (flare 3), and blue (smoke 4) is
no flare colour at all.

### Done

The parser keeps the colour name as asked (`options.colorName`); the `signal` handler reads it against
`veafSpawn.SIGNAL_FLARE_COLORS` — `red` (the default), `green`, `white`, `yellow`. `orange` and `blue`
are refused with a message naming the four (David's call, 2026-10-03: a message, not a fallback).
Documented in `doc/mission-maker/scripts/veafSpawn(.en).md`.

### Seen in game (2026-10-03, second pass)

`dcs.log` reads `spawnSignalFlare(color = 1 / 0 / 2 / 3)` for red, green, white, yellow; `orange` and
`blue` each produced the message *« Pas de fusée orange / blue dans DCS »* and nothing in the sky.
David saw the flares go up, several colours, at 400 m (at 1.5 km in daylight he saw none).
