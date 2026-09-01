# FIX-ESCORT-RESPAWN-DISTANCE — a respawned asset reappears 80 km from its escort

Status: 🔄 in-progress — option (a) **implemented and unit-tested**; only the in-game check is left

Origin: the in-game verification of [`FIX-ESCORT-RESPAWN-TASK`](../FIX-ESCORT-RESPAWN-TASK/PRD.md),
run 2026-08-28 on `VEAF-session-2026-08-27`. That lot's repair is now proven to work; the escort
still goes home, and this is why.

## What was measured

`veafAssets.respawn` calls `mist.respawnGroup(name, true)`, which recreates the asset **at its
mission start position**. Its escort is not respawned — it keeps flying wherever it had got to. So
the moment the tanker reappears, the two are wherever the elapsed mission time has put them apart.

Measured on the demo mission's tanker, minutes after a respawn from the F10 menu:

```
t+0s  | Arco escort: 78497 m from Arco, alt 14 m   (landed, stationary)
t+20s | Arco escort: 78639 m from Arco, alt 14 m
t+0s  | Arco-escort1: 82750 m from Arco, alt 317 m (descending)
t+20s | Arco-escort1: 81562 m from Arco, alt 207 m
```

**~80 km.** The Escort task's own `engagementDistMax` is **60 000 m**, read off the live task. The
escort is out of range of its charge before the repair has even run.

> One correction to the paragraph above, 2026-09-01: `veafAssets.respawn` no longer calls
> `mist.respawnGroup` — `DROP-MIST` replaced it with
> `VeafGroupSpawn:new():forGroup(name):withRoute(veaf.getGroupRoute(name)):respawn()`. The behaviour
> the measurement describes is unchanged, and the code says why: `mist.respawnGroup(name, true)` was
> a wrapper around the teleport with no point and the group's own route, which is that chain without
> an `at`. Nothing else in this PRD is affected — but do not go looking for MiST here.

The repair itself is not at fault, and that is established rather than assumed — the instrumented
trace in [ticket 03](../FIX-ESCORT-RESPAWN-TASK/tickets/03-find-the-escort-task-on-any-waypoint.md)
shows `reestablishEscortTask` → `actualReestablishEscortTask` → `replaceMission` running to
completion and writing the runtime group id (`1000031` → `18`) into the task.

## Two things tried in game, and ruled out

Both were run through the fiddle bridge against `Arco-escort1`, which was airborne and not escorting:

1. **`airborne = true` on the Mission task.** `veafMove.replaceMission` hands DCS the *whole group
   definition* (`units`, `start_time`, `uncontrolled`, `radioSet`, … 17 keys) as the params of a
   `Mission` task, and never sets `airborne`. Re-applied by hand as a proper Mission task with
   `airborne = true` and the route alone: **no change**.
2. **Pushing the `Escort` task straight onto the controller**, instead of a route whose waypoint 2
   carries it: **no change** within the observation window. Worth noting the window was short and the
   aircraft was 84 km out — this one is *not conclusively* ruled out and should be retried at close
   range before being discarded.

## What to decide

The choice is about what a respawn is supposed to mean, and it is a design call, not a bug fix:

- **(a) Respawn the escort with its charge.** Simple, predictable, and consistent with what `linked`
  already does — but `linked` is explicitly *not* how escorts are found (documented on the ASSETS
  page), so this would blur two mechanisms the documentation separates on purpose.
- **(b) Teleport the escort next to the respawned asset**, then repair the task. The teleport path
  already exists (`veafMove.teleportEscort`), so this is mostly wiring.
- **(c) Leave the escort where it is and let it fly to its charge.** Nothing to write, but it means
  minutes of transit each respawn, and it only works if the Escort task really does make an aircraft
  rally from beyond `engagementDistMax` — which is exactly what test 2 above failed to demonstrate.

## Decision — (a), David, 2026-08-28

**The escort respawns with its charge.** `veafAssets.respawn` already does exactly this for `linked`
groups; the group following the `<asset name> escort` convention gets the same treatment.

Why (a) and not the other two, in the terms the choice was put:

- It is **the only one of the three whose outcome is certain without a further measurement**. A respawn
  already means "put this back the way it started", and the escort is part of that.
- **(b) rests on a component the repository itself says does not work.** `veafMove.teleportEscort`
  carries its author's note that the escort *"just doesn't defend the group"*, and it still assumes the
  Escort task sits on the last waypoint. Its advertised cheapness was the reason to prefer it, and that
  reason does not survive reading it.
- **(c) rests on DCS behaviour nobody has seen.** The Escort task's `engagementDistMax` is 60 km and the
  escort is ~80 km out; that a task makes an aircraft rally from beyond its own engagement distance was
  never demonstrated. The one attempt on 2026-08-28 showed nothing, and was too short to count either
  way.

What (a) costs, stated rather than glossed: an escort that was engaged, damaged or low on fuel is
replaced by a fresh one, and the two mechanisms the ASSETS page separates on purpose — `linked` and the
naming convention — end up doing the same thing at respawn time. The page has to say so.

### What implementing it means

- `veafAssets.respawn` respawns `<asset name> escort` alongside the asset, if such a group exists.
- The task repair still runs afterwards: respawning both does not by itself restore the Escort task,
  since it is the **escorted** group's id changing that breaks it. Both halves are needed.
- The order matters — the asset first, then the escort, then the repair — because the repair reads
  `Group.getID` of the freshly created asset.
- Documented on the ASSETS page, both languages: respawning an asset respawns its escort.
- Tests: an asset with an escort respawns both; an asset without one is unaffected; the repair still
  runs and writes the new id.

## Scope

| # | Ticket | Status |
|---|--------|--------|
| 01 | [Respawn the escort with its charge](tickets/01-respawn-the-escort-with-its-charge.md) | ✅ |

## Definition of done

- [x] One of (a)/(b)/(c) chosen, with the reason recorded here — **(a)**, David, 2026-08-28
- [x] Implemented with unit tests covering the distance case — `veafMove.respawnEscort`, called by
      `veafAssets.respawn` before the task repair; 8 tests, each shown red before the fix and red
      again under a deliberate sabotage of the finished code (ticket 01 lists the three sabotages)
- [ ] Verified in game: respawn the asset, and the escort is with it — not merely tasked with it.
      Written up as item **R5** of [`DCS-SESSION-TODO.md`](../../DCS-SESSION-TODO.md), with what to run
      and what both outcomes mean, so the wait has somewhere to end
- [x] The ASSETS page says what a respawn does to an escort — new section *What a respawn does to an
      escort* in both languages, including the cost: the escort that comes back is a fresh one

### What the unit tests cannot settle, and what to look for in game

The mocks do not model what DCS does with an Escort task, so what is proven here is that the escort
is **put back** and that the repair still runs, in that order. What the in-game check has to add is
the distance itself: respawn the asset from the F10 menu and read the escort's distance to its charge
straight away. The measurement to beat is the one at the top of this page — 78 km and 82 km. Anything
of that order means the escort was not respawned; a few hundred metres means it was.

Worth watching for separately: the escort now comes back **fresh**, so an escort that had been
engaged is replaced mid-fight. That is the cost of (a), accepted when it was chosen; the check is
that it happens, not whether it is liked.

One assumption the mocks cannot exercise, worth a second run: for an escort that had been **shot
down**, `reestablishEscortTask`'s own guard — `Group.getByName(<asset> escort)` — has to resolve the
group `coalition.addGroup` created a few instructions earlier, in the same tick. That is the same
same-tick lookup `teleportEscort` already relies on after its teleport, so the assumption is not a
new one; the mocked `coalition.addGroup` simply does not register the group it is handed, so no unit
test can show it either way. Shoot the escort down, respawn the asset, and check the escort is both
back **and** escorting.

## Two things found in `teleportEscort` while sizing option (b), 2026-08-28

Option (b) was written up as *"mostly wiring"* because the teleport path already exists. Reading it
says otherwise, twice.

**1. Its author recorded that it does not work.** [`veafMove.teleportEscort`](../../src/scripts/veaf/veafMove.lua),
right after the call that is supposed to make the escort escort:

```lua
  veafMove.replaceMission(unitGroup_escort, EscortData)
  --this method appears to not work very well, the escort just doesn't defend the group
```

That contradicts [`FIX-ESCORT-RESPAWN-TASK`](../FIX-ESCORT-RESPAWN-TASK/PRD.md), which states the
teleport path *"works (escort held for 30 min)"* and used it as the reference the respawn path was
ported from. One of the two is wrong, and it matters: option (b) is only cheap if the thing it reuses
does what it claims. **Settle this before choosing (b)** — and note that "held for 30 min" and "does
not defend" are not even contradictory: an escort can fly formation without engaging anything.

**2. It still assumes the Escort task is on the last waypoint.** It rewrites the last two waypoints and
comments the last one as *"Waypoint 1 where the escort tasking will come into play"*:

```lua
  local point1_escort = points_escort[#points_escort - 1] --second to last waypoint
  local point2_escort = points_escort[#points_escort] --last waypoint where the escort has to be set up in the editor
```

`FIX-ESCORT-RESPAWN-TASK` ticket 03 fixed that assumption in the *lookup*; it is still here in the
*rewrite*. On the demo mission (3 waypoints, task on wp2) the task sits on `point1_escort`, the one
this code treats as a mere approach waypoint. Whether that breaks the teleport or merely works by
accident is unmeasured — but it is the same defect, in the same file, and it belongs to whichever lot
touches this path next.

### Verdict, 2026-09-01 — both **out of scope** for this lot, and filed rather than dropped

Both live in `veafMove.teleportEscort`, which this lot does not touch: option (a) respawns the escort
and repairs the task, and neither half goes anywhere near the teleport's waypoint arithmetic. The
reasons are specific, not "it is a different function":

1. **The contradiction about whether the teleport escort works** can only be settled by a
   measurement in DCS, and nothing implemented here depends on the answer — option (b) was the only
   thing that rested on it, and it was not chosen. Deciding it from the code is exactly the mistake
   the note warns against: *"held for 30 min"* and *"does not defend"* are both compatible with an
   escort flying formation without engaging.
2. **The last-waypoint assumption in the rewrite** is a real defect, but repairing it means
   rewriting the waypoint arithmetic around the task's actual index — a design change to a path
   whose author says it does not do its job, which is finding 1 again. Fixing the arithmetic of a
   function before knowing whether the function works is work in the wrong order, and it cannot be
   verified from a workstation either way. Doing it here would also break RULE N°1: it is not
   adjacent to this change, it is a different change in the same file.

Filed as [`FIX-TELEPORT-ESCORT-WAYPOINT`](../FIX-TELEPORT-ESCORT-WAYPOINT/PRD.md), which carries both
in the order they have to be taken: measure first, then fix the arithmetic.
