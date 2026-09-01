# FIX-CAP-ENGAGES-PARACHUTES — a spawned CAP hunts ejected pilots and ignores fighters

Status: ⬜ ready

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

## Definition of done

- [ ] An ejected pilot is never a CAP target — driven by a test, since the group category cannot tell
      them apart
- [ ] Something else that is *not* worth engaging is checked too: enumerate what a CAP's radar can see
      and route through this filter, rather than special-casing pilots
- [ ] When nothing worth engaging is listed, the CAP goes back to `PROHIBIT_AA` and its patrol —
      the existing branch does this, so the test is that it is now reached
- [ ] Verified in game: spawn a CAP with a CSAR pilot in the air nearby, and it must ignore him and
      engage the fighter
- [ ] The commented-out `EngageTargetsInZone` block is either restored or deleted with the reason —
      leaving a commented task in place says nothing about whether the watchdog is meant to be the
      only mechanism

## Worth knowing

12 of the mission's 117 `veafSpawn-` templates carry **no first-waypoint task at all** (Mig-21,
Mig-23S, Mig-25, F-14A, F-5, M-2000), so a CAP spawned from those has neither ROE nor engage task even
before the watchdog runs. Not the cause of what was seen — `f15` and `mig29` are not among them — but
it is the same family and worth folding in.
