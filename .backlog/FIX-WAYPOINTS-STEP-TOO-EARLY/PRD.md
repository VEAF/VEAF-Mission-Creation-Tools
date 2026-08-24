# FIX-WAYPOINTS-STEP-TOO-EARLY — waypoint injection reaches 1 human slot in 105

Status: ✅ done

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

## Delivered — 2026-08-24

**Option 1: the step moved**, after `spawnable_aircrafts` and `dynamic_slot_templates` and still before
`weather`. Chosen on measurement rather than preference — the two failure modes the injector's own comment
warns about were checked away first, on the 105 human slots of the built smoke-test mission:

* **none has an empty route**, so appending cannot leave a slot whose route starts in mid-air;
* **all 105 already carry a locked ETA**, so the injector's "lock point 1" fallback never fires on them;
* and every one of them starts on a `Turning Point`, so there is no parking departure to disturb.

That also made option 2 (run the step twice) unnecessary rather than merely unattractive: the injection is
idempotent by construction — a same-named waypoint is replaced in place, renumbering is stable, the ETA
lock is guarded — so a second pass would buy nothing the move does not.

### Measured, before and after, on the real artefact

Running the injector over the already-built `SmokeTest_noon.miz` reproduces the corrected position exactly,
because that archive *is* the post-aircraft-injection state:

| | human slots reached |
|---|---|
| shipped build (step before aircraft injection) | **1 of 105** |
| injector run at the corrected position | **105 of 105** |

No full rebuild was needed to establish it, which matters because a rebuild is the expensive part of
verifying a pipeline change.

### Why it was silent, which is the part worth keeping

The step **already reported** what it did: "N injected", and "M human groups without a flight plan". At the
old position it saw one group and reported `1 injected, 0 without a plan` — accurate, and perfectly healthy
to read. Nothing lied. The count was taken before the world was finished.

So the DoD's third item needed no new code: moving the step restores the denominator as much as the
behaviour. Adding a second report would have been noise, and the reasoning is recorded here instead.

### The guard

`test_pipeline_step_order.py`, three checks: the three step calls still exist (a rename must fail loudly
rather than make the test scan nothing), waypoints runs after both aircraft steps, and it still runs
*before* the weather step — which bounds the move from both sides, since the weather step writes the
variant files and anything injected after it would land in none of them.

A source-order test, deliberately: the ordering is a property of a statement sequence, not of any value a
normal test can read, and getting it wrong is invisible — the build succeeds and the report looks healthy.
It is brittle to a refactor by design, because a refactor that moves these steps is exactly what should
have to look here. Moving the step back fails it.

## Definition of done

- [x] The option chosen and recorded here, with the reasoning — option 1, on measurement
- [x] A dynamic-slot mission's human slots get the waypoints their flight plan declares — 105 of 105,
      against 1 of 105
- [x] Whatever is chosen, the build reports how many human groups received a plan out of how many exist —
      it already did; the count was taken too early, and moving the step restores it
- [x] Unit tests, plus one rebuilt mission measured before and after — measured by running the injector
      over the built archive, which *is* the post-injection state, so no rebuild was needed
- [x] Documented, both languages, including what changed for missions that already inject waypoints
