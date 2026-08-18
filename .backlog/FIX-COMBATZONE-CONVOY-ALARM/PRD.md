# FIX-COMBATZONE-CONVOY-ALARM — a combat zone puts every group on red alert, so convoys never move

Status: ⬜ ready

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

## The design question the fix has to answer

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
- [ ] The rule that chooses the alarm state written down here, with why the two rejected shapes lost
- [ ] Verified in game on `verify-mission-a`, and the probe block deleted from its `mission-script.lua`
- [ ] Lua tests on the chooser, since the in-game check cannot be automated
