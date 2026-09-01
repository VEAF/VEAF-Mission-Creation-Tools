# 03 — Find the Escort task on any waypoint, not only the last

Status: ✅ done — 2026-08-28
Type: fix

Found by running the lot's own in-game check ([DCS-SESSION-TODO](../../../DCS-SESSION-TODO.md)
item 10) on 2026-08-28. The repair ticket 01 shipped could not fire on the mission it was tested
against — nor on the repository's own demo mission.

## The defect

`veafMove.findEscortTask` read the task off the **last** waypoint of the escort's route and nowhere
else:

```lua
-- Last waypoint: where the escort task has to be set up in the editor.
local task2_escort = veaf.findInTable(points_escort[#points_escort], "task")
```

Nothing in DCS puts the `Escort` task on the last waypoint. A mission maker sets it wherever the
escort is meant to join, which is normally *before* the end of the route. Probed in game on the
three escorts of the demo mission this lot is verified against:

| Group | Waypoints | Escort task on |
|---|---:|---|
| `Arco escort` | 3 | **wp2** |
| `Arco-escort1` | 3 | **wp2** |
| `Petrolsky-escort` | 3 | **wp2** |

So every call reported `Arco escort exists but carries no Escort task ; nothing to repair` and
returned false. That line is in `dcs.log` for the 2026-08-28 run.

## Why the tests were green

`test_veafMove_escort.lua` built its fixture to the shape the code expected — the helper's own
docstring said *"with an Escort task on the last waypoint"*, and the test was called
`test_the_escort_task_is_found_on_the_last_waypoint`. The fixture asserted the implementation, not
the data DCS produces. Compare [[assert-the-applied-value-not-the-constant]].

## What was done

- `findEscortTask` walks the whole route, **last waypoint first**, so a mission that does put the
  task on the last waypoint resolves to exactly the same task as before.
- Four tests added, and each was **run against the old implementation first** to prove it fails
  there: task on an intermediate waypoint, task on the first waypoint, last waypoint still preferred
  when two waypoints carry one, and a disabled task late in the route not masking a valid earlier one.
  Three of the four were red before the change; the fourth is the non-regression.
- The ASSETS page said "set the `Escort` task on the **last waypoint**" in both languages. It now
  says **any waypoint**.

## Verified in game, 2026-08-28

The chain runs end to end. Instrumented on the live session, after a respawn of Arco:

```
1. reestablishEscortTask(Arco) called            -> true
2. actualReestablish(Arco -> Arco escort)  escortedGroupExists=true  runtimeId=18  taskIdBefore=1000031
3. replaceMission(group=Arco escort)  hasRoute=true  points=3   -> ok
2. -> taskIdAfter=18
```

The stale id `1000031` is replaced by the runtime id `18`, which is what ticket 01 set out to do.

**The escort still went home**, for a reason that is not this lot's — see
[`FIX-ESCORT-RESPAWN-DISTANCE`](../../FIX-ESCORT-RESPAWN-DISTANCE/PRD.md).

## Definition of done

- [x] The Escort task is found wherever it sits on the route
- [x] Tests proven to fail against the previous implementation
- [x] `stylua --check` clean, Lua suite green (41 suites, 150 tests)
- [x] ASSETS page corrected, both languages, `docs-check` clean
