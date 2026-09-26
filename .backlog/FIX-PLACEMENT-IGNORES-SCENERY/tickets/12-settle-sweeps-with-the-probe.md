# 12 — `settleGroup` sweeps with the probe instead of asking for a clearing

Status: 📋 open — designed and **measured on the live mission**, not yet implemented. David's call,
2026-09-26 evening: *"si la sonde marche mais pas getSimpleZone, pourquoi on n'utilise pas le même
concept que la sonde en jeu avant de spawner des trucs ?"*
Type: fix

## The question, and why it is the right one

Ticket 11 fixed the clearance `settleGroup` asks for, and the numbers moved — 19 group alerts and
76 blocked vehicles to 15 and 69. But it kept `Disposition.getSimpleZones` as the thing that
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

## The measurement that settles it

Run on the live mission, 6.25.0.3, on the 14 groups holding blocked vehicles:

- **13 of 14 solved**, translations of 40 to 200 m. **Including `combatZone_Wittstock`'s S-300**,
  which ticket 11 recorded as having *no way out at any clearance*: the sweep finds a clearing at
  **200 m**. The dead end was a property of the query, not of the terrain.
- **1 genuinely unsolvable**: `combatZone_Wittstock [r] SA15`. Nothing within 720 m **even with the
  halo removed entirely** — so it is the wood that is closed, not the criterion that is too strict.
- Every solution was revalidated independently afterwards: 0 blocked vehicles, 0 without halo.

## Definition of done

- [ ] A failing test first: a group whose neighbourhood `getSimpleZones` refuses to describe is still
      moved to a clear spot found by sweeping
- [ ] A test pinning the halo: an offset clear at the vehicles' own points but not at 40 m around
      them is **rejected**
- [ ] `settleGroup` no longer calls `Disposition.getSimpleZones` with a clearance argument at all;
      `SETTLE_CLEARANCE_ASKED` and `SETTLE_MAX_CANDIDATES_VERIFIED` go with it, or are restated as
      sweep bounds
- [ ] The sweep is **bounded** — probe budget and maximum radius — and the bound is a measurement
      rather than a hunch. A 600-probe budget is 0.23 s, against the 36 ms currently spent for
      nothing; decide whether that is spent in one frame or spread over several
- [ ] The rigid translation is unchanged — inter-unit distances preserved to the metre
- [ ] Verified **in game** on GermanyCW-v6: group alerts, blocked vehicles, and the cost of one
      activation of the 25 zones measured, not estimated
- [ ] `poetry run test-lua` green, `stylua --check` and `luacheck` clean
- [ ] `CHANGELOG.md` entry under `[Unreleased]`
- [ ] `known-limitations.yaml` records that the probe is the usable half of the singleton and the
      large query should not be used to find a clearing at all
