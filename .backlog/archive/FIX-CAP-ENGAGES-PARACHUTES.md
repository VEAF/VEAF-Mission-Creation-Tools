# FIX-CAP-ENGAGES-PARACHUTES — a spawned CAP hunts ejected pilots and ignores fighters

Status: ✅ done — verified in game 2026-10-03 (R11) · archived 2026-11-24

Found in game 2026-09-01: *"les `-cap` fonctionnent, mais les appareils spawnés n'engagent pas le
combat ; j'en ai spawné 14 et les 3 escortes d'Arco les ont tous détruits."*

## What was measured, with trace on

A spawned CAP has **no engagement task of its own**: the `EngageTargetsInZone` block of its patrol
waypoint is commented out in full (`veafSpawnAircraft.lua:968-991`). Everything depends on
`startCapWatchdog`, which runs every ten seconds, keeps `PROHIBIT_AA` on by default, and lifts it only
for the targets it has listed.

The watchdog **works**. Over the last run: 4 detections, 3 `Allowing AA for CAP`, **3
`Engaging target!`**, each pushing an `EngageUnit` task.

What it lists is the defect. Every single target, without exception:

```
detection of targetName=Pilot #006
detection of targetName=Pilot #007
detection of targetName=Pilot #008-1
detection of targetName=Pilot #009
```

**Ejected pilots**, under parachute, from the session's CSAR.

## Why they pass the filter

```lua
targetGroupCategory == Group.Category.AIRPLANE or targetGroupCategory == Group.Category.HELICOPTER
```

An ejected pilot still belongs to **its aircraft's group**, so the group category says AIRPLANE. And
the second condition — `target:inAir()` — is true under a parachute. The "outdated, landed or gone"
branch was taken **zero** times.

So the CAP is told to attack parachutes, spends its time doing that, and is shot down by the escorts
without ever returning fire: `PROHIBIT_AA` is lifted only for the listed targets, and the list holds
nothing but pilots.

## Two defects, not one

1. **The filter admits ejected pilots.** Group category is not enough; the unit's own attributes or
   type must be consulted.
2. **Four parachutes are enough to make the patrol "busy".** There is no notion of *nothing worth
   engaging*: any listed target lifts the air-air prohibition and consumes the watchdog's attention.

## A correction to the first diagnosis, recorded on purpose

The first reading of the log said the watchdog **never pushed** an engage task — `Engaging target` at
zero. That was wrong: the line is `trace`, and the module was not at trace. The repair would have gone
to the wrong place entirely.

The reason the module could not be put at trace on its own is
[`FIX-PER-MODULE-LOGLEVEL-INERT`](FIX-PER-MODULE-LOGLEVEL-INERT.md), found in the same breath.

## A second correction, recorded on purpose: they were not parachutes

Written 2026-09-01 during implementation, from the same `dcs.log`. **The targets the watchdog listed
were not ejected pilots.** `Pilot #006` … `Pilot #009` are DCS's own **default unit names for
aircraft** in the Mission Editor, and the log says exactly what they were:

```
Checking targetGroupName=Arco,        targetName=Pilot #006 … targetType=KC-135, .Air=[true]
Checking targetGroupName=Arco escort, targetName=Pilot #009 … targetType=F-14B,  .Fighters=[true]
```

Their positions move 2.4 km per ten seconds at 6 000 m and climbing. That is the tanker Arco and its
F-14B escorts, flying — not a parachute in the list. Nothing in the session ejected: the mission's
CSAR names its own downed pilots `Downed Pilot #<n>` (`CSAR.lua:1035`), a name that appears nowhere.

**And the branch this PRD says was taken zero times was in fact taken for every target.** DCS collapses
repeated log lines (`WARNING LOG: 3 duplicate message(s) skipped`), so the four removals of one tick
show as one line. The real sequence, tick after tick, is: four F-14s detected → *"Watchdog has targets !
Allowing AA"* → all four discarded as *"outdated, landed or doesn't exist"* → **no `EngageUnit` pushed
at all**, and no cleanup either. The CAP flew weapons free with nothing tasked. That, not a parachute,
is what David watched.

The PRD's prescription survives its diagnosis, which is why the lot was done as written: the group
category genuinely cannot tell an ejected pilot from a fighter, and the fix for it — route by what the
object *is*, not by what its group is — is the same filter that would have refused the static object
that killed two watchdogs outright in the same session. What changed is the emphasis: the defect that
cost the fourteen CAPs is **ticket 02**, not ticket 01.

## Scope

| # | Ticket | Type | Status |
|---|--------|------|--------|
| 01 | [Only aircraft are CAP targets](FIX-CAP-ENGAGES-PARACHUTES.md) | fix | ✅ |
| 02 | [Nothing worth engaging sends the CAP back on patrol](FIX-CAP-ENGAGES-PARACHUTES.md) | fix | ✅ |
| 03 | [The commented-out engage task](FIX-CAP-ENGAGES-PARACHUTES.md) | chore | ✅ |
| 04 | [A template with no first-waypoint task is named](FIX-CAP-ENGAGES-PARACHUTES.md) | fix | ✅ |

## Definition of done

- [x] An ejected pilot is never a CAP target — driven by a test, since the group category cannot tell
      them apart
- [x] Something else that is *not* worth engaging is checked too: enumerate what a CAP's radar can see
      and route through this filter, rather than special-casing pilots
- [x] When nothing worth engaging is listed, the CAP goes back to `PROHIBIT_AA` and its patrol —
      the existing branch does this, so the test is that it is now reached
- [ ] Verified in game: spawn a CAP with a CSAR pilot in the air nearby, and it must ignore him and
      engage the fighter — [`DCS-SESSION-TODO.md` item **R11**](../../DCS-SESSION-TODO.md)
- [x] The commented-out `EngageTargetsInZone` block is either restored or deleted with the reason —
      leaving a commented task in place says nothing about whether the watchdog is meant to be the
      only mechanism

## Worth knowing

12 of the mission's 117 `veafSpawn-` templates carry **no first-waypoint task at all** (Mig-21,
Mig-23S, Mig-25, F-14A, F-5, M-2000), so a CAP spawned from those has neither ROE nor engage task even
before the watchdog runs. Not the cause of what was seen — `f15` and `mig29` are not among them — but
it is the same family and worth folding in. Folded in as ticket 04.

## Found on the way, and not fixed here

Two things the same log shows, neither of them this lot's subject:

- **`veaf.lp` cannot render a table holding DCS objects usefully.** The watchdog's `targetsList=` trace
  prints each entry's `unit` as `{ id_ = 16867840 }` and nothing more, which is what made the four
  identical ids visible — a lucky break rather than a designed one.
- **The 2026-09-01 session ran under time acceleration**, so the watchdog's ten model seconds land
  2.5 s apart on the wall clock in the middle of the log and 1.43 s apart later. Worth knowing before
  anyone reads a cadence out of that file as a defect.

## In-game check — 2026-10-03

From `FIX-IN-GAME-SESSION-2026-10-03`.

Part one: a `-cap` MiG-29S turned on an unarmed F-15C inside its zone and fired an R-27 (t=800 s).
Part two: an F-15C damaged into ejecting inside the zone; on the three watchdog passes that followed,
the parachute never appeared in the target list. Two side findings went to
`FIX-IN-GAME-SESSION-2026-10-03` ticket 04.

## Former index entry

The row this lot had in `.backlog/README.md` until the index was split into short summaries (CHORE-BACKLOG-INDEX-SPLIT, 2026-10-03), kept verbatim.

**a spawned CAP flew weapons free with nothing tasked, and was shot down without returning fire.** Found in game 2026-09-01: fourteen CAPs spawned, all destroyed by Arco's escorts. The report read the watchdog's targets as **parachutes**; re-reading the same log during implementation, they were not — `Pilot #006` … `Pilot #009` are DCS's own default *aircraft* unit names in the Mission Editor, and the log gives their types: a KC-135 and three F-14Bs, at 6 000 m and climbing. The PRD's second recorded correction has the detail. What actually happened is that every one of those four fresh contacts was thrown out in the tick that registered it — the freshness check interrogated the CAP's **own** aeroplane, because the list stored the detecting unit instead of the target — while `foundTargets`, set before the check, still lifted `PROHIBIT_AA` and skipped the branch that hands the patrol back its route. DCS's log deduplication (`3 duplicate message(s) skipped`) is what hid three of the four removals and made the branch look untaken. Also repaired on the way: `seenAt` never refreshed, so a target tracked without interruption expired under the CAP's nose; `table.sort` on a map, so the whole priority ladder ordered nothing; `resetTask` where `popTask` was meant, which ED documents as clearing the patrol route too; and a detected **static** that raised *"Static doesn't exist"* and stopped two watchdogs for the rest of the mission. The filter the PRD asked for is in and is the right one anyway — routed on the `Air` attribute, checked against all 883 entries of the shipped unit database, and on nothing that reads a name. The commented `EngageTargetsInZone` block is **deleted** with the reason in the source: it cannot coexist with a watchdog that pops the queue it would live in. 12 templates with no first-waypoint task are now named in the log. **Left at 🧑** for `DCS-SESSION-TODO.md` item R11 — nothing off DCS can say what descriptor the game really hands back for a man under a parachute

## Tickets, in full

## 01 — Only aircraft are CAP targets

Status: ✅ done

Type: fix · Files: `src/scripts/veaf/veafSpawnAircraft.lua`, `test/lua/test_veafSpawn.lua`,
`test/lua/dcs_mocks.lua`

### What was wrong

`startCapWatchdog` decided what to engage from the **group** a detected object belongs to:

```lua
targetGroupCategory == Group.Category.AIRPLANE or targetGroupCategory == Group.Category.HELICOPTER
```

An ejected pilot keeps his aircraft's group, so the group category still says AIRPLANE, and
`target:inAir()` is true under a canopy. Neither test can tell a fighter from a man on a parachute.

Two other things were wrong on the same lines, and both were reachable in the same session:

- the object was **dereferenced four times before being filtered** (`getID`, `getGroup`,
  `getName`, `getCategory`). `getDetectedTargets` returns *objects*, not aircraft, and on 2026-09-01
  one of them raised *"Static doesn't exist"* — twice. The watchdog re-arms itself from its own tail,
  so the raise did not cost a tick, it stopped that CAP's watchdog for the rest of the mission;
- the priority ladder ended in an `else` branch — *"Target has unknown attributes"* — which gave
  anything unrecognised a priority and a place in the list rather than refusing it.

### What was done

One named predicate, `veafSpawn.isCapEngageableTarget(target, capCoalition)`, called **before** anything
is read off the object, and called again by the engage loop so that a target that has gone is dropped.

It refuses, in this order: an object whose `Object.Category` is not `UNIT`; one that is not active or
not airborne; one whose coalition is unknown or friendly; one whose group is not an aircraft group; and
finally one **whose own descriptor does not carry the `Air` attribute**. Every accessor goes through a
guarded call, so an object that raises is refused rather than propagated.

#### Why the `Air` attribute, and why nothing that reads a name

Enumerated from the shipped DCS unit database rather than picked: of its **883 entries, all 170
aircraft carry `Air`, and not one vehicle, ship, static or infantry entry does**. The test sweeps the
whole table, so the day ED ships an aircraft without it, the suite says so.

A name match would have been worse than useless. A mission maker names his units in his own language —
and DCS's *own* default unit name for an aircraft is `Pilot #001`, which is exactly what the
2026-09-01 log was full of (see the PRD's second recorded correction). An ED attribute is the same
string in every mission, whatever language it is written in.

### Definition of done

- [x] An object that is not an aircraft is never listed, whatever its group says
- [x] The enumeration is over the whole shipped unit database, not over chosen cases
- [x] An object that raises costs neither its neighbour on the radar nor the watchdog
- [x] Tests red before the change, green after

## 02 — Nothing worth engaging sends the CAP back on patrol

Status: ✅ done

Type: fix · Files: `src/scripts/veaf/veafSpawnAircraft.lua`, `test/lua/test_veafSpawn.lua`,
`test/lua/dcs_mocks.lua`

### What was wrong

The watchdog had no notion of *nothing worth engaging*. Four separate defects made the branch that
hands the CAP back its patrol either unreachable or wrong, and together they are what "the patrol never
returned fire" looked like from the cockpit.

**1. The list held the wrong object.** A detection was registered as
`{ …, unit = unit }` where `unit` is the CAP's **own** aeroplane, the one whose radar saw the target.
So the freshness check —

```lua
not Unit.isExist(targetData.unit) or not targetData.unit:inAir()
```

— asked whether the patrol was still flying, not whether the enemy was still there. Visible in the
2026-09-01 log: a watchdog dumped its list of four freshly detected F-14s, every entry carrying the
same `unit.id_`, and threw all four away in the same tick it registered them.

**2. `foundTargets` was set before the entry was checked.** So a list holding nothing but stale
contacts still reported *"Watchdog has targets ! Allowing AA for CAP"*, lifted `PROHIBIT_AA`, went
weapons free, pushed **no** task at all, and skipped the cleanup. In the log that pattern —
"has targets" with no "Engaging target!" — repeats tick after tick for the same group.

**3. `seenAt` was never refreshed.** The redetection branch marked a contact old and left its first
sighting time in place, so a target tracked without interruption expired `CAP_WATCHDOG_DELAY * 2` after
it was first seen and came back as brand new on the next tick — the wall of "new detection of
targetName=Pilot #009" in the log — pushing a fresh `EngageUnit` onto an AI that was already attacking
it.

**4. The cleanup used `resetTask`.** Its own comment says *"taking care not to remove the original
task, which is to fly along the route"*, and it counted the tasks it had pushed for exactly that
reason. Then it called the one that removes everything. ED's own descriptions, from the vendored API
reference:

| Call | ED's description |
|---|---|
| `pushTask` | adds a task to the **front** of the queue |
| `popTask` | removes the **highest priority** task from the queue |
| `resetTask` | clears **all** tasks from the queue, causing controlled units to cease their current activity |

`resetTask` was never reached in the 2026-09-01 session (`numberOfTasksAddedByWatchdog` was 0 on every
cleanup), so this one is latent — but it sits in the branch this ticket exists to make reachable.

**5. The sort sorted nothing.** `targetsList` is keyed by DCS unit id, so it is a map: `#targetsList`
is 0 and `table.sort` on it returns immediately. The whole priority ladder above it — fighters first,
then bombers, drones, AWACS, transports, helicopters — decided the *value* of each target and then
never ordered anything by it.

### What was done

- the list holds the **target**, and the engage loop re-runs ticket 01's predicate on it;
- `seenAt` is refreshed on every redetection, along with the priority and the object;
- `engagedTargets` counts targets actually engaged. `PROHIBIT_AA` is lifted and weapons go free on the
  **first task actually pushed**, and when the count is zero the CAP gets its tasks back and returns to
  `PROHIBIT_AA` + return fire;
- the cleanup calls `popTask`, the inverse of the `pushTask` it is undoing;
- the entries are copied into a real array before being sorted, which is also what makes it safe to
  delete from the map while walking it.

### Definition of done

- [x] A sky holding nothing but parachutes leaves the CAP on patrol, air-to-air prohibited
- [x] A target still on radar is engaged on every tick and never expires under the CAP's nose
- [x] A target that is gone is dropped, and the CAP goes back on patrol
- [x] The cleanup takes back its own tasks and never clears the queue
- [x] Tests go through `startCapWatchdog`, not through the predicate alone
- [x] Tests red before the change, green after

## 03 — The commented-out engage task: deleted, with the reason

Status: ✅ done

Type: chore · Files: `src/scripts/veaf/veafSpawnAircraft.lua`

### What was wrong

A full `EngageTargetsInZone` task sat commented out inside the patrol waypoint's `ComboTask`. Twenty
lines of dead configuration that said nothing about whether the watchdog was meant to **replace** it or
to **complement** it — which is precisely the question anyone reading this code arrives with.

### The decision: deleted

It cannot complement the watchdog. The two mechanisms are incompatible by construction, on two counts:

- the group is spawned with `PROHIBIT_AA = true`, and the watchdog owns that option from then on. A
  route task telling the group to engage air targets is **inert for exactly as long as the watchdog is
  silent, and redundant the moment it speaks**;
- the watchdog undoes its own tasking through the controller's task queue — the queue this route task
  would live in. Even the narrower `popTask` this lot moved to (ticket 02) pops whatever is on top. A
  route-level engage task in that queue is something the watchdog would eventually remove without ever
  knowing it was there.

So the watchdog is the single mechanism, deliberately, and it is the one that can do what the route
task cannot: weigh targets by priority, refuse what is not an aircraft, and hand the group back its
patrol when there is nothing worth engaging.

The reason is written where the block was, not in this ticket alone — a comment in a backlog file does
not reach the next reader of `veafSpawnAircraft.lua`.

### Definition of done

- [x] The commented block is gone
- [x] The reason it is gone is in the source, at the place it was

## 04 — A template with no first-waypoint task is named

Status: ✅ done

Type: fix · Files: `src/scripts/veaf/veafSpawnAircraft.lua`, `test/lua/test_veafSpawn.lua`,
`doc/mission-maker/scripts/veafSpawn.md`, `doc/mission-maker/scripts/veafSpawn.en.md`

### What was wrong

`spawnCombatAirPatrol` copies the template's first-waypoint `ComboTask` onto the spawned patrol — that
is where the template's author put his radar setting, his ECM setting and his rules of engagement. When
the template has no such task, `chosenTemplateWp1Task` came back nil and the CAP spawned **in silence**
without any of it.

**12 of the reference mission's 117 `veafSpawn-` templates** are in that state: Mig-21, Mig-23S,
Mig-25, F-14A, F-5, M-2000. Not the cause of what was seen on 2026-09-01 — `f15` and `mig29` are not
among them — but the same family, and invisible until someone went looking.

### What was done

A warning naming the template, and a paragraph in the mission maker's page saying what it means.

**Deliberately not a fabricated default task.** Air-to-air behaviour is set on the *controller* by the
watchdog on every tick — `PROHIBIT_AA` and the rules of engagement both — so a synthesised waypoint task
would add nothing the CAP does not already get. What is actually missing is the template author's own
options, and only he can supply them. Naming the template is what lets him.

### Definition of done

- [x] A template with nothing usable on its first waypoint is named in the DCS log
- [x] Nothing is invented in the template author's place
- [x] The mission maker's page says what the warning means
- [x] Test red before the change, green after
