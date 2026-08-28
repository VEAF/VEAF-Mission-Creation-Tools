# FIX-ESCORT-RESPAWN-DISTANCE — a respawned asset reappears 80 km from its escort

Status: ⬜ ready

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

## Definition of done

- [ ] One of (a)/(b)/(c) chosen, with the reason recorded here
- [ ] Implemented with unit tests covering the distance case
- [ ] Verified in game: respawn the asset, and the escort is with it — not merely tasked with it
- [ ] The ASSETS page says what a respawn does to an escort
