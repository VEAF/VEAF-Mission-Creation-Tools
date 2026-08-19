# FIX-COMBATZONE-CONVOY-ALARM — a combat zone puts every group on red alert, so convoys never move

Status: 🧑 waiting-human — code shipped, awaiting the in-game check on `verify-mission-a`

Origin: [#290](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/290), David, 2025-04.
**Cause proven in game on 2026-08-17**, on `test/veaf-tools/verify-mission-a`.

## The cause, and how it was proven

`veafCombatZone:activate()` calls `veaf.readyForCombat()` on every group it spawns
(`veafCombatZone.lua:1105`), which applies `veaf.defaultAlarmState = 2` — **RED** — to the group's
controller (`veaf.lua:2095` and `:2117`):

```lua
cont:setOption(AI.Option.Ground.id.ALARM_STATE, alarm)   -- alarm = 2
```

A DCS ground group on red alert **holds position and deploys**. That is exactly right for a SAM
battery and exactly wrong for a convoy.

**The proof**: a probe in the test mission forced `ALARM_STATE` back to `0` (AUTO) on the convoy once,
after the zone activated it. The convoy then **set off in full** — three trucks, the whole route. With
the probe removed, it does not move at all, while its route is present and visible on the F10 map.

That also explains the issue's "in certain conditions" and why it stayed open for over a year: the
**other** branch of `activate()`, the one spawning from a VEAF command, does *not* call
`readyForCombat` — so a convoy launched by `#command=` moves, and one declared as a mission group does
not. Same function, two paths, one of them immobilising.

## Two wrong tracks, recorded so nobody re-walks them

- **`mist.goRoute` is not missing.** The two branches of `activate()` look asymmetric — the command
  branch pushes the route explicitly, the group branch does not — and that looked like the bug.
  `mist.teleportToPoint` was then read end to end: it deep-copies `vars.route`, **translates every
  waypoint by the teleport delta**, and hands the group to `dynAdd` with its route attached
  (`mist.lua:4550-4574`). MiST does its job. The asymmetry is explained: the interpreter branch has no
  route of its own, hence its `goRoute`.
- **The units are not stacked.** An earlier run showed one truck leaving and the others staying, which
  looked like collision. The `.miz` has them 20 m apart, and the real culprit was **the probe itself**:
  its first version rescheduled every 5 s, and re-applying `setOption` on a moving ground group
  interrupts the task in progress. A measuring instrument that changes what it measures. Fixed by
  touching each group once.

## What the fix is *not*

The issue proposes a **watchdog**: check speed after 30 s, rebuild the route if everything is
stationary. That treats the symptom. The convoy is not lost — it is under orders to hold.

## The rule, decided by David on 2026-08-19

**The zone spawns every group on AUTO (0). `#alarm=N` on the unit name is the only override.** No
inference of any kind.

| | |
|---|---|
| Default | `AUTO` — `veafCombatZone.DefaultAlarmState = 0`, passed explicitly to `veaf.readyForCombat`. `veaf.defaultAlarmState` is left at RED, since the marker path relies on it. |
| Override | `#alarm=0\|1\|2` in the unit name, read alongside the six existing tags. Out-of-range or unparsable falls back to AUTO. |
| Not implemented | Any rule deriving the state from the route, the unit category, or anything else. |

### Why the two other shapes lost

- **Per group category** (weapon carriers RED, transports AUTO) — killed by measurement: of the **588
  distinct ground groups** in this repository's missions, **109 (19%) mix transport and armed
  vehicles**. A `bluePATRIOT` group holds its launchers *and* its `M 818` truck; `blueHAWK-Coldwar`
  likewise. The rule has no answer for them.
- **Inferred from the route** — the PRD's own favourite, and it survives the first measurement but not
  the second. In `verify-mission-a` it separates the two groups perfectly (`SmokeZone-SmokeArmor` 1
  waypoint, `SmokeZone-ConvoyBlue` 2). But the repository also holds SAM groups carrying long
  waypoint lists — `Red SAM SHORAD SA-15 Fixed Bravo` has **21 waypoints** over 574 m, `Red SAM
  SHORAD SA-8 Fixed SAM-Lima` 17 over 726 m — which the rule would put on AUTO. And **no distance
  threshold rescues it**: a SHORAD's local patrol reaches 726 m while a combat-zone BTR patrol that
  *should* move reaches 926 m. The two populations overlap. (Those SAM groups sit in a Foothold
  mission rather than a combat zone, so the false positive is not live today — but nothing stops the
  same hand from doing it in a zone.)

Both measurements are reproducible over `test/**/*.miz` by reading each ground group's
`route.points`.

### The precedent this follows

`veafSpawnParser` already solved the same problem for the marker path, and the `#alarm=` tag mirrors
its `alarm=` parameter deliberately: a mission maker who knows one knows the other.
`veafCombatZone` was the only one of `veaf.readyForCombat`'s two callers passing no state at all
([veafSpawnCore.lua:412](../../src/scripts/veaf/veafSpawnCore.lua) passes `options.AlarmState`).

### The Skynet lock this lot deliberately does *not* add

The marker path forces RED when `skynet` is enabled and **ignores** an explicit `alarm=`, so the
obvious worry was: a combat-zone SAM *does* join the IADS when `veafSkynet.DynamicSpawn` is on
(measured 2026-08-18, see `FIX-SKYNET-DYNAMICSPAWN-SCOPE`), and with AUTO as the zone default it
would come up cold. A matching lock was proposed, then **dropped after reading Skynet itself**:

```lua
-- skynet-iads-compiled.lua:2794, SkynetIADSAbstractRadarElement:goLive()
cont:setOnOff(true)
cont:setOption(AI.Option.Ground.id.ALARM_STATE, AI.Option.Ground.val.ALARM_STATE.RED)
cont:setOption(AI.Option.Air.id.ROE, AI.Option.Air.val.ROE.WEAPON_FREE)
self:getDCSRepresentation():enableEmission(true)
```

**Skynet sets RED itself** when it brings a site live, and `goDark()` handles the other direction. For
an integrated SAM the state set at spawn is therefore transient — the network rewrites it. A lock here
would have duplicated the work of the module that owns the decision.

What genuinely remains is a **20-second window** (`veafSkynet.DelayForRestart`) between the group
joining and the network reactivating, during which the SAM sits on AUTO. A SAM battery is a
single-waypoint group, so it does not move either way; only its reactivity differs, and `#alarm=2`
covers the mission maker who cares. For SAMs **outside** any network — the common case, the flag
being off by default — `#alarm=2` was always the answer.

**Do not reopen this** without new evidence: the question was instructed on 2026-08-19 and answered by
Skynet's own code, not by preference.

## Two corrections to the analysis above, found while verifying it

- **The route is not on the element at decision time.** `setRoute()` is called only in the
  `#command=` branch (`veafCombatZone.lua:831`); for a mission group `getRoute()` returns `nil`, so
  `vars.route` is nil and it is `mist.getGroupRoute` **inside** `teleportToPoint` that supplies the
  route (`mist.lua:4551`) — not the `deepCopy` described below. The conclusion (MiST does its job)
  stands.
- **The waypoints are not translated.** The translation by the teleport delta is gated on
  `vars.offsetRoute` / `offsetWP1` / `initTasks` (`mist.lua:4561`), and `veafCombatZone` sets none of
  them. With a non-zero `spawnRadius`, the group is therefore dropped beside its original waypoint 1
  and has to drive to it first. Split out as its own lot at David's request:
  `FIX-COMBATZONE-SPAWN-ROUTE-OFFSET`.

## The design question the fix had to answer

**A convoy and a SAM battery do not want the same alarm state, and the zone applies one to all.** So
"set it to 0" is not the fix either — it would leave every SAM in a combat zone passive. Who decides?

Three shapes, to be weighed and one chosen in writing:

- **Per group, declared** — a `combat_zones:` key or a naming convention. Explicit, but it asks the
  mission maker to know what an alarm state is.
- **Inferred from the route** — a group whose route has more than one point is meant to travel, so it
  gets AUTO. No new syntax, and it matches intent rather than asking for it. Cheapest to get right,
  and the one to beat.
- **Per group category** — vehicles that carry weapons get RED, transports get AUTO. Reads well and
  fails on an armoured convoy, which is both.

Whatever wins: `veaf.readyForCombat` already takes an `alarm` parameter and defaults it when absent
(`veaf.lua:2106-2108`), so the plumbing is there — only the caller needs to decide.

## Definition of done

- [ ] A convoy spawned by a combat zone drives its route
- [ ] A SAM group spawned by the same zone still comes up on red alert (regression — this is what the
      current default protects)
- [x] The rule that chooses the alarm state written down here, with why the two rejected shapes lost
- [ ] Verified in game on `verify-mission-a`, and the probe block deleted from its `mission-script.lua`
- [x] Lua tests on the chooser, since the in-game check cannot be automated
