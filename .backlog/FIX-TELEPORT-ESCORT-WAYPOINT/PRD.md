# FIX-TELEPORT-ESCORT-WAYPOINT — the teleport path still rewrites the wrong waypoints, and may not work at all

Status: ⬜ ready — **blocked on a measurement in DCS**, which is David's to run

Origin: two things found while sizing option (b) of
[`FIX-ESCORT-RESPAWN-DISTANCE`](../FIX-ESCORT-RESPAWN-DISTANCE/PRD.md) on 2026-08-28, and ruled out
of that lot on 2026-09-01 with the reasons recorded there. Nothing shipped in that lot depends on
either of them: it respawns the escort and repairs the task, and never touches the teleport's
waypoint arithmetic.

Both defects are in one function, `veafMove.teleportEscort`
([`src/scripts/veaf/veafMove.lua`](../../src/scripts/veaf/veafMove.lua)), and they have to be taken
in this order.

## 1. Its author recorded that it does not work — and the repository says the opposite elsewhere

Right after the call that is supposed to make the escort escort:

```lua
  veafMove.replaceMission(unitGroup_escort, EscortData)
  --this method appears to not work very well, the escort just doesn't defend the group
```

[`FIX-ESCORT-RESPAWN-TASK`](../FIX-ESCORT-RESPAWN-TASK/PRD.md) states the opposite — the teleport
path *"works (escort held for 30 min)"* — and used it as the reference the respawn path was ported
from. One of the two is wrong, and until it is settled the repository has a working reference it may
not have.

Note the two statements are **not** actually contradictory: an escort can fly formation for thirty
minutes without ever engaging anything. Which is why this needs a measurement and not a re-reading.

**What to measure**: `_move tanker, name <asset>, teleport`, then whether the escort (a) stays in
formation and (b) engages a threat brought to the pair. Two observables, not one.

## 2. It still assumes the Escort task is on the last waypoint

The rewrite comments the last waypoint as *"where the escort tasking will come into play"*:

```lua
  local point1_escort = points_escort[#points_escort - 1] --second to last waypoint
  local point2_escort = points_escort[#points_escort] --last waypoint where the escort has to be set up in the editor
```

`FIX-ESCORT-RESPAWN-TASK` ticket 03 fixed that assumption in the **lookup** — `findEscortTask` now
searches every waypoint, because the repository's own demo mission puts the task on waypoint 2 of 3,
for all three of its escorts. The **rewrite** never got the same treatment. On the demo mission the
task therefore sits on `point1_escort`, the waypoint this code treats as a mere approach point, and
the waypoint it prepares for the task carries none.

`findEscortTask` already returns the route points it walked; it does **not** return the index of the
waypoint that carried the task, which is what the arithmetic would need.

## Why this is one lot and not two tickets in another

Fixing the arithmetic of a function before knowing whether the function does its job is work in the
wrong order: if finding 1 resolves as *the teleport escort has never worked*, the answer may be to
rebuild this path on the respawn lot's mechanism rather than to correct its waypoints. So the
measurement gates the fix, and both live here.

## Definition of done

- [ ] Measured in game: does the teleported escort hold formation, and does it engage? Both answers
      recorded here, with the mission and the date
- [ ] The repository tells one story — whichever of the two notes is wrong is corrected, in the code
      comment and in `FIX-ESCORT-RESPAWN-TASK`'s PRD
- [ ] If the path is kept: the rewrite targets the waypoint that actually carries the task, with a
      unit test on the demo mission's shape (3 waypoints, task on wp2)
- [ ] If the path is not kept: what replaces it, and the ASSETS / MOVE pages updated
