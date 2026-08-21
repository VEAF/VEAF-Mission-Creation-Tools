# FIX-COMBATZONE-SPAWN-ROUTE-OFFSET — a zone drops a group beside its route, not on it

Status: ✅ done — shipped in 6.15.20

Origin: found on 2026-08-19 while instructing `FIX-COMBATZONE-CONVOY-ALARM`, and split out at
David's request so the alarm-state decision shipped on its own.

## What was measured

`VeafCombatZone:spawnElement` hands `mist.teleportToPoint` these vars: `gpName`, `name`,
`newGroupName`, `route`, `action`, `point`, `renameUnitsSequentially`
(`veafCombatZone.lua:1090-1098`). It sets **none** of `offsetRoute`, `offsetWP1` or `initTasks` — and
in MiST, waypoint translation by the teleport delta is gated on exactly those three
(`mist.lua:4561`).

Two consequences, both of which contradict what `FIX-COMBATZONE-CONVOY-ALARM`'s PRD originally
assumed:

1. `vars.route` is `nil` for a mission group, because `setRoute()` is only called in the `#command=`
   branch (`veafCombatZone.lua:831`). MiST therefore falls back to
   `mist.getGroupRoute(gpName, true)` (`mist.lua:4551`) — the group's **original** route, at its
   **original** coordinates.
2. The group is respawned at `vars.point`, which `spawnRadius` scatters (default 50 m for units,
   `veafCombatZone.DefaultSpawnRadiusForUnits`). So the group appears up to 50 m away from a route
   whose waypoint 1 is still at the editor position.

Observed in game on 2026-08-17: the convoy did drive its route once its alarm state let it move — DCS
simply routes the group to waypoint 1 first. So this is **not** a blocking defect; it is a group
walking a leg nobody drew.

## Latent until 6.15.15, and now it is not

Noted 2026-08-21, after both PRDs were written and neither said it.
[`FIX-COMBATZONE-DEAD-SPAWN-RADIUS-DEFAULT`](../FIX-COMBATZONE-DEAD-SPAWN-RADIUS-DEFAULT/PRD.md) measured
that `DefaultSpawnRadiusForUnits = 50` had been **dead since 2023-03-04**: every group came up at
`spawnRadius = 0`, so the teleport delta was zero and there was **nothing to offset**. The missing
`offsetRoute` could not be seen.

6.15.15 makes the 50 m default apply again — which turns this defect from dormant to observable in the
same release. The 2026-08-17 sighting above happened with an explicit `#spawnradius=`, the one path that
was alive.

**Overstated, corrected the same day** — see the finding below: the delta is not only the dispersion, so
"dormant" only held for groups whose first met unit was also the mission table's unit 1. For the others
the defect has been live since 2023, intermittently.

**Consequence for the DCS session:** item 18 checks the dispersion on `verify-mission-a`, so it is the
first look at a scattered group *with a route*. Expect `SmokeZone-ConvoyBlue` to walk back to an
undisplaced waypoint 1 before starting its leg — that is this lot, not a regression of item 18.

## The question this lot has to answer

Setting `offsetRoute = true` translates the whole route by the spawn delta, which is almost certainly
the intent — but it changes where every combat-zone group with a route ends up, so it is a behaviour
change on existing missions and wants its own verification pass.

Also worth deciding: whether a zone with `spawnRadius = 0` (statics) should skip the offset entirely,
since the delta is then zero and the extra work is pointless.

## Answered: `offsetWP1`, and the PRD's guess above was the wrong one

`offsetRoute` is **not** the intent. The three vars do this (`mist.lua:4561-4570`):

| var | effect |
|---|---|
| `offsetRoute` | every waypoint translated by the delta |
| `offsetWP1` | waypoint 1 translated, the rest left alone |
| `initTasks` | waypoint 1 translated, **every later waypoint deleted** |

The delta here is a **local, random** displacement around the drawn position — 50 m by default, never a
relocation of the group elsewhere. So:

- **The track is a design choice; waypoint 1 is not.** A mission maker places waypoints on roads,
  bridges and passes. Translating them by fifty random metres puts them beside those features. Waypoint
  1 only ever means "where the group starts", so it is the one that must follow the group.
- **`offsetRoute` would draw a different track on every activation**, since the delta is redrawn each
  time. The mission maker drew one track.
- It is also the *smaller* behaviour change, which reverses the PRD's own worry: with `offsetWP1`, where
  a group ends up does not move at all — only the leg it walks first.

Cost of being wrong, either way: a group whose dispersion pushed it away from waypoint 2 may turn back
on itself for the first few metres. That is within the drawn track, unlike the alternative.

## The second question had a different answer than the PRD assumed, and this is the finding

The PRD asked whether to skip the offset when `spawnRadius = 0`, "since the delta is then zero". **It
is not necessarily zero**, and the reason is worth recording:

- `vars.point` comes from `zoneElement:getPosition()`, set in `buildGroupElement(plainUnits[1], …)` —
  the position of **the first unit the zone happened to meet**. `initialize`'s own comment says so:
  *"a group's element takes its position and coalition from the first of its units, as it always has"*.
  (Written here as "order from `pairs()`"; the follow-up lot measured that the order is in fact
  preserved and the real trigger is unit 1 being **filtered out** of the zone — see
  [`FIX-COMBATZONE-SPAWN-REFERENCE-UNIT`](../FIX-COMBATZONE-SPAWN-REFERENCE-UNIT/PRD.md).)
- MiST computes the delta against **the mission table's unit 1**:
  `diff = newCoord - newGroupData.units[1]` (`mist.lua:4470`), `newGroupData` being
  `mist.getGroupData(gpName)`.

When those two units are not the same unit, the delta is the **intra-group spacing** — tens of metres
for a convoy — with no dispersion involved at all. MiST applies it to every unit, so the whole group is
already displaced by it today.

So the offset is set **unconditionally**. Gating it on `spawnRadius > 0` would have been precisely
wrong, and only measuring the delta's real source revealed it.

This also **corrects a claim written in this PRD earlier the same day**: "latent until 6.15.15" is too
strong. It was latent for any group whose first met unit *was* unit 1; for the others the defect has
been live since 2023, intermittently, which is the worst way for one to be.

**Filed, not fixed here:** the reference-unit mismatch is its own defect —
[`FIX-COMBATZONE-SPAWN-REFERENCE-UNIT`](../FIX-COMBATZONE-SPAWN-REFERENCE-UNIT/PRD.md). It moves where
groups appear, which is not what this lot is about.

## Definition of done

- [x] Decide between `offsetRoute` and `offsetWP1` — **`offsetWP1`**, reasoned above
- [x] Lua tests over the vars `spawnElement` builds — 6 tests, and **4 of them fail** with the one line
      removed (verified, not assumed: the fix was written before the tests)
- [ ] Verified in game: a combat-zone convoy with a scattered spawn drives from where it appeared, not
      back to its editor position first — **item 18 of the session sees this for free**
- [x] Documented on the `veafCombatZone` page, both languages, under
      *"Le premier point de passage suit le groupe"* / *"The first waypoint follows the group"*
