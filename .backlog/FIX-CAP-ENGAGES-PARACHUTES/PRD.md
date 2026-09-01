# FIX-CAP-ENGAGES-PARACHUTES — a spawned CAP hunts ejected pilots and ignores fighters

Status: 🧑 waiting-human

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
[`FIX-PER-MODULE-LOGLEVEL-INERT`](../FIX-PER-MODULE-LOGLEVEL-INERT/PRD.md), found in the same breath.

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
| 01 | [Only aircraft are CAP targets](tickets/01-only-aircraft-are-cap-targets.md) | fix | ✅ |
| 02 | [Nothing worth engaging sends the CAP back on patrol](tickets/02-nothing-worth-engaging-sends-the-cap-back-on-patrol.md) | fix | ✅ |
| 03 | [The commented-out engage task](tickets/03-the-commented-out-engage-task.md) | chore | ✅ |
| 04 | [A template with no first-waypoint task is named](tickets/04-a-template-with-no-first-waypoint-task-is-named.md) | fix | ✅ |

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
