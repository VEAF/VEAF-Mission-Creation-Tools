# 12 — `settleGroup` sweeps with the probe instead of asking for a clearing

Status: ✅ done — verified in game 2026-10-03
suites green; what is left is the in-game measurement, item R16 of `DCS-SESSION-TODO.md`. David's
call, 2026-09-26 evening: *"si la sonde marche mais pas getSimpleZone, pourquoi on n'utilise pas le même
concept que la sonde en jeu avant de spawner des trucs ?"*
Type: fix

## The question, and why it is the right one

Ticket 11 fixed the clearance `settleGroup` asks for, and the numbers moved — probed before the
spawn, vehicles under trees fall from 17 to 4 after `settleGroup`. But it kept
`Disposition.getSimpleZones` as the thing that
*proposes* candidates, and that is still a lottery: it returns **zero candidates at every clearance,
down to 5 m**, for the places a group most needs moved out of.

The two calls are not the same animal, and the difference was measured on the running mission on
2026-09-26:

| call | cost each | behaviour |
|---|---|---|
| the small probe — 5 m free within 20 m | **0.38 ms** (2 600/s) | **deterministic**: 12 repetitions on the same points gave 0/12 against 12/12, identical counts |
| the large query — a whole clearing at once | **12.0 ms** (32× more) | a lottery, ignores its search radius, and returns nothing where it matters |

So `settleGroup` currently spends **3 large queries per group, 36 ms, to obtain nothing** in 30 calls
out of 31 — 1.1 s of computation per activation of the 25 combat zones, entirely wasted.

## What replaces it

**Sweep the neighbourhood with the probe.** Rings of growing radius around the group's barycentre;
for each offset, translate the group rigidly and test it; stop at the first offset that clears every
unit. `Disposition` is then only ever used the way it is dependable — asked about one point at a
time — and never asked to propose anything.

Two things make the cost acceptable, both measured:

- **Test the extremes first.** Probing the two units that carry the footprint before probing all of
  them rejects a bad offset for 2 probes instead of 15. On the Wittstock S-300 this brought a full
  sweep to **836 probes, 0.32 s**.
- **Groups already in the open never sweep at all.** They leave on the existing `alreadyClear` check,
  one probe per vehicle.

**A halo, not just a point.** Each candidate position is accepted only when every vehicle is clear
**and** the four cardinals at 40 m around it are clear too, because `veafUnits` redraws the internal
layout at every spawn and the footprint moves by **up to 38.8 m** between draws (ticket 11, *The
footprint varies between draws*). Without the halo, a solution validated once is not a solution.

## The measurement that pointed here — and why it has to be redone

> **Measured with the criterion that was later found broken.** The sweep looked for points where
> `getSimpleZones` reported room, and it counts **vehicles** as well as trees, so the sweep was
> fleeing neighbouring vehicles as much as vegetation. The numbers below are what convinced us the
> approach works; **none of them should be quoted until the sweep is rerun probing where no vehicle
> of the group exists yet.** The design is unaffected — a sweep with the small probe is still 32×
> cheaper per call and still deterministic — but its yield is unknown.

Run on the live mission, 6.25.0.3, on the 14 groups holding blocked vehicles:

- **13 of 14 solved**, translations of 40 to 200 m. **Including `combatZone_Wittstock`'s S-300**,
  which ticket 11 recorded as having *no way out at any clearance*: the sweep finds a clearing at
  **200 m**. The dead end was a property of the query, not of the terrain.
- **1 genuinely unsolvable**: `combatZone_Wittstock [r] SA15`. Nothing within 720 m **even with the
  halo removed entirely** — so it is the wood that is closed, not the criterion that is too strict.
- Every solution was revalidated independently afterwards: 0 blocked vehicles, 0 without halo.

## What was built, 2026-09-28

Three decisions, two of them David's, taken before the code:

1. **No halo** (David, 2026-09-28). The halo was justified by the layout being redrawn at every
   spawn, but `settleGroup` runs **after** `placeGroup`, on the layout actually drawn, and runs
   again on every respawn: what it validates is exactly what spawns. The halo came from the live
   trial, which looked for one position valid across draws. One probe per vehicle, the acceptance
   probe's own criterion.
2. **`SETTLE_MAX_TRANSLATION` = 300 m, `SETTLE_SWEEP_PROBE_BUDGET` = 1000** (David, 2026-09-28).
   300 rather than the 240 first proposed, because ticket 10 translated groups by 118 to 278 m and
   ticket 11 moved one by 266 m: a tighter bound would give up on groups the previous code moved.
   At a 20 m step a full sweep is 761 offsets, so a group with no way out costs about 761 probes,
   inside the budget; the budget is a safety bound for tuned values, not the operative limit.
3. **One frame.** Spreading the sweep over frames means deferring the spawn, which empties
   `veafSkynet.declareSpawn` (ticket 11, *Deferring the spawn was tried*). Not an open choice.

The public name `SETTLE_MAX_TRANSLATION` is kept, since `LUA_API_REFERENCE` documents it as a
setting; `SETTLE_CLEARANCE_ASKED`, `SETTLE_DRAWS` and `SETTLE_MAX_CANDIDATES_VERIFIED` are gone, and
`SETTLE_SWEEP_STEP` (20 m) and `SETTLE_SWEEP_PROBE_BUDGET` are new.

## Definition of done

- [x] A failing test first: a group whose neighbourhood `getSimpleZones` refuses to describe is still
      moved to a clear spot found by sweeping
- [x] ~~A test pinning the halo~~ — **dropped** with the halo, decision 1 above. Pinned instead: the outermost units are probed first: an offset clear at the vehicles' own points but not at 40 m around
      them is **rejected**
- [x] `settleGroup` no longer calls `Disposition.getSimpleZones` with a clearance argument at all;
      `SETTLE_CLEARANCE_ASKED` and `SETTLE_MAX_CANDIDATES_VERIFIED` go with it, or are restated as
      sweep bounds
- [x] The sweep is **bounded** — probe budget and maximum radius — and the bound is a measurement
      rather than a hunch. A 600-probe budget is 0.23 s, against the 36 ms currently spent for
      nothing; decide whether that is spent in one frame or spread over several
- [x] The rigid translation is unchanged — inter-unit distances preserved to the metre
- [ ] The sweep's yield is **remeasured** with the corrected criterion — probing before the
      group's units exist — since the figures above were taken with the broken one
- [ ] Verified **in game** on GermanyCW-v6: blocked vehicles and the cost of one activation of the
      25 zones measured, not estimated
- [x] `poetry run test-lua` green (49 suites), `stylua --check` clean; `luacheck` runs in CI
- [x] `CHANGELOG.md` entry under `[Unreleased]`
- [x] `known-limitations.yaml` records that the probe is the usable half of the singleton and the
      large query should not be used to find a clearing at all
