# FIX-WAYPOINTS-STEP-TOO-EARLY — waypoint injection reaches 1 human slot in 105

Status: ⬜ ready

Found on 2026-08-24 while starting [`FEAT-WAYPOINT-BULLSEYE`](../FEAT-WAYPOINT-BULLSEYE/PRD.md), which
cannot be delivered in a useful form until this is settled.

## Measured

The build pipeline runs its steps in this order (`veaf_tools/commands/build.py`):

```
presets → waypoints → spawnable_aircrafts → dynamic_slot_templates → warehouses → spawn_data → weather
```

The waypoints step injects into groups that have a **human pilot**. But the groups a VEAF mission mostly
consists of are created by the two aircraft-injection steps, which run **after** it. So they do not exist
when the waypoints are injected.

Counted in the built `SmokeTest_noon.miz`, by walking the mission table rather than reasoning about it:

| | |
|---|---|
| human-piloted groups | **105** |
| of which carry any waypoint from the flight plan | **1** |

The one is `SmokePlayer`, the base mission's own slot — present in `src/mission/` before the pipeline
runs. The other 104 come from `spawnables.yaml` and `dynamic-slot-templates.yaml`.

## Why this is not a bullseye problem

It applies to **declared** waypoints exactly as much as to an automatic bullseye. A mission maker who
writes a flight plan today, for a mission using dynamic slots or spawnable aircraft, gets it applied to
the handful of slots that were in the source `.miz` and to nothing else — with no warning, because
nothing counts what it reached.

So `FEAT-WAYPOINT-BULLSEYE` built on top of this would satisfy its own definition of done — "a flight
gets a BULLSEYE waypoint without declaring one" — while reaching one slot in a hundred. That is a hollow
completion, which is why this is a lot of its own and a prerequisite rather than a footnote.

## Options, to settle before writing

1. **Move the waypoints step after aircraft injection.** Smallest change, and it fixes the declared case
   too. What has to be checked first: the step does not only add waypoints, it **renumbers the route and
   force-locks `ETA_locked` on point 1** (`waypoints_injector_worker.py`), and the code comment there
   records the bug that behaviour exists to avoid — a flight "delayed to start", i.e. a slot that cannot
   be taken. Running that over freshly injected groups is a bigger blast radius than running it over the
   two or three slots it currently reaches, and it wants measuring on a real built mission.
2. **Run the step twice**, before and after. Keeps today's behaviour intact for the source mission's own
   slots and extends it to the injected ones. Costs a second pass over the whole mission table, and needs
   the injection to be idempotent — which it may already be, since it replaces a same-named waypoint in
   place rather than appending.
3. **Leave the order and say so.** Warn at build time, naming how many human groups were reached out of
   how many exist, so a mission maker learns the limit instead of discovering it in the cockpit. Cheapest
   and safest, fixes nothing.

Option 1 or 2 needs a rebuild of a real mission to confirm, since the failure mode option 1 risks — a
slot nobody can take — is exactly the kind that unit tests do not see.

## Definition of done

- [ ] The option chosen and recorded here, with the reasoning
- [ ] A dynamic-slot mission's human slots get the waypoints their flight plan declares
- [ ] Whatever is chosen, the build reports how many human groups received a plan out of how many exist —
      the silence is half the defect
- [ ] Unit tests, plus one rebuilt mission measured before and after
- [ ] Documented, both languages, including what changed for missions that already inject waypoints
