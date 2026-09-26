# 11 — `settleGroup` verifies the candidate it trusts, and draws more than once

Status: ✅ ready for review, **with its limit stated rather than smoothed over**. The per-unit
verification was built first and measured inert twice; the cause was a **parameter**, not an
architecture — the clearance `settleGroup` asked for was large enough to silence `Disposition`
entirely, so the verification never had a candidate to judge. Two constants carry the fix, and it
works: 19 alerts / 76 units → **15 / 69**, 4 of 31 groups translated against 1, and 4 of the 7
groups it saw in trouble fully repaired, formations preserved to 0.0000 m. It is **not** near zero,
and the reason is measured: **62 % of the blocked vehicles belong to groups `settleGroup` is never
given** — editor content, not dynamic spawns. That is a separate question and a ruling rather than
a bug. The pre-computation phase this ticket planned is **dropped**: the spawn flow was measured not
to affect `Disposition` at all.
Type: fix

## Problem — ticket 10 translates groups, and the metric does not move

Ticket 10 shipped and merged (PR #1005, released in 6.25.0). Measured in game on GermanyCW-v6,
2026-09-26, with the released build actually loaded — `veafUnits.settleGroup` present,
`settlePosition` gone:

| measure | before ticket 10 | ticket 10's target | **measured after** |
|---|---|---|---|
| alerts on groups | 16-18 | ~0 | **19** |
| units standing in scenery | ~81 | a handful | **66** |
| inter-unit spacing | intact | intact | **intact** |

The one promise ticket 10 kept is the formation: spacing stays at its natural 20 m and no group is
pulled apart. Everything else is unchanged.

**The caveat on the comparison, and how it was removed.** The 2026-09-25 reference figures were
taken without pinning the park, so 19-versus-16 was not a regression measurement. It is now: the
2026-09-26 evening run, on 6.25.0.2 with the deferral removed, probed **102 ground groups and 593
units** — the same park as the reference, unit for unit — and found **19 groups in alert, 76 units
blocked**. Ticket 10 and the per-unit verification both leave the number where it was. What the runs
establish without reservation is that it is **not near zero**.

## The function works. What it stands on does not.

Each step was measured separately, because the interesting part is that none of the obvious suspects
is guilty.

1. **The fix runs.** 55 groups translated in one activation of the 25 zones (118 to 278 m), 11
   reported `no clearing wide enough within 1000m`. `no candidate clears every unit` never fired.

2. **DCS obeys to the metre.** `settleGroup` was wrapped to record the barycentre it commands, one
   zone was cycled, and the units' real positions were read back: **0 m of error** between the
   commanded centre and the actual one. Nothing downstream loses the decision — not the caller, not
   `_createDcsUnits`, not the spawn itself.

3. **The group lands in the trees anyway.** That same group — the Wittstock S-300, translated 217 m —
   has **6 of its 14 units blocked**. Probing the arrival point in a ring: blocked in **12 directions
   out of 12 at 10 m**, and only fully clear at 183 m. The group was moved into the middle of a wood
   that happens to have a clearing 183 m further out.

4. **`Disposition.getSimpleZones` is not deterministic.** Five consecutive calls, same point, same
   parameters (`searchRadius 1000`, `posRadius 180`, 10 attempts), nearest candidate:
   **1335, 1476, 1404, 1355, 1293 m**. And a call moments earlier, from inside `settleGroup` on the
   same centre, retained a candidate at **153 m** while an identical call made right after it saw
   nothing closer than **212 m**.

   The scatter is not noise around a value, it is the difference between "a clearing exists 150 m
   away" and "nothing within 1200 m". It also ignores its own search radius: asked 1000 m, it returns
   candidates at 2769 m.

This is the same mistake ticket 10 was written to correct, moved one parameter across. Ticket 10's
finding was *"DCS does not honour the radius it is asked for"*. Ticket 10's own code then assumed DCS
honours the **clearance** it is asked for, and says so in a comment that is simply not true:

> *"A candidate is scenery-free by construction, so nothing here has to test a forest."*

It was never verified. The arrival point measured above is the counter-example.

## What this ticket built first — the verification

**The function proposes, we test.** Two changes, both of them on the selection, none on the rigid
translation — that part works and is not touched.

1. **Verify every candidate before retaining it.** Today a candidate is accepted when every
   translated unit sits on `veaf.DRIVABLE_TERRAIN`, which says nothing about vegetation. Add the
   scenery test, per unit, using the same criterion the acceptance probe uses — is there a free spot
   within a short radius of where this unit would stand. Aligning the acceptance criterion with the
   measurement criterion is the point: the two disagreeing is exactly how ticket 10 came out green
   and inert.

2. **Draw more than once.** A single draw misses clearings that a second draw finds 150 m away. Ask
   `getSimpleZones` a few times and merge the candidates before sorting by distance, so one unlucky
   draw no longer decides that a group stays under trees.

Bound the cost: candidates are tested closest-first and the search stops at the first one that clears
every unit, so the common case — a group already in the open, or one clearing nearby — pays for one
candidate.

Also delete the "scenery-free by construction" claim from the docstring and put the measurement in
its place. A comment asserting something nobody measured is what made this lot cost three rounds.

## Why it stayed inert: the clearance it asks for silences `Disposition`

Everything above is built and green, and it moved nothing: 19 group alerts and 76 blocked units on
a **pinned park** (102 ground groups, 593 units), against 19 and 66 before it. The cause was found
on the evening of 2026-09-26, and it is not the one this ticket carried all day.

**It is the clearance argument.** `settleGroup` asked `Disposition.getSimpleZones` for the group's
own footprint plus 50 m, which is the obvious thing to ask for and is exactly what makes the
singleton answer nothing. Same point, same everything, varying only that one argument:

| clearance asked | 5 | 10 | 20 | 40 | 80 | 120 | 200 | 300 |
|---|---|---|---|---|---|---|---|---|
| candidates over 3 draws | 30 | 30 | 30 | 30 | 30 | 30 | 21 | **0** |

Real groups carry footprints of 8 to 436 m, so the call asked for 58 to 486 m and landed in the
zero column. Instrumented over one activation of the 25 combat zones: **31 calls, one group
translated, 30 giving up** — and the one that moved was repaired correctly (1 of 8 vehicles
blocked, 0 after, 266 m). The verification this ticket built was never wrong; it was never given
anything to verify.

**Second bound, measured the same evening.** `SETTLE_MAX_CANDIDATES_VERIFIED = 10` cuts the list
before the answer. On the five groups that actually held blocked units, asking for a constant 40 m:
verifying the 10 nearest solved **1 of 5**, verifying all of them solved **3 of 5**, the working
candidates coming back at ranks 15 and 22. At 80 m they came back **first** in all three cases —
same outcome, a fraction of the probing — which is why the constant is 80 and the bound is 30.

The two remaining groups are out of reach and no setting will save them: `Disposition` returns
**zero candidates at every clearance, down to 5 m**, for those locations.

## The blindness of the call stack is not reproducible

This ticket spent a day on a different explanation — that `Disposition` goes blind inside
`settleGroup`'s call stack — and it does not survive remeasurement. Witness points at fixed
coordinates, truth 10 blocked out of 15, probed across one reactivation of all 25 zones:

| probed from | answer |
|---|---|
| a quiet frame (reference) | 10 / 15 |
| `ActivateZone`, one second before the spawn | 10 / 15 |
| the top of `activate()`, 25 zones in the same frame | 10 / 15 |
| **inside `settleGroup`**, before and after its own large draws | **10 / 15** |

And the control that settles it: over 20 groups, `getSimpleZones` returned candidates **in flight**
in 17 cases, and replaying the identical queries from a quiet frame recovered **none** — two cases
returned *fewer* when quiet. For the five genuinely faulty groups, in flight and quiet both return
zero.

**So computing the clearings outside the spawn flow buys nothing**, and the pre-computation phase
this ticket planned is dropped. What was measured on 2026-09-26 in the afternoon — 9 of 16 groups
solved from a quiet frame — was a difference of parameters, not of timing.

### Deferring the spawn was tried, and must not be retried as such

Delaying the whole spawn by one second does make the probe truthful, and it breaks the mission: the
group name a spawn returns feeds `Group.getByName`, and with it `veaf.readyForCombat`, convoy
routing and **`veafSkynet.declareSpawn`**
([`veafSpawnCore.lua:417-460`](../../../src/scripts/veaf/veafSpawnCore.lua)). Defer the creation and
that whole block runs on nothing — which is precisely the regression that removed all nine SAM
batteries on the morning of the same day. Four tests in `test_veafSpawn.lua` catch it, since they
assert on the returned group name. This stays closed whatever the reason for wanting it.

## What this ticket now does

Two constants, and the query that uses them.

1. **`SETTLE_CLEARANCE_ASKED = 80`** replaces `footprint + SETTLE_MARGIN`. What is asked for is a
   **coarse filter**, not a guarantee — a candidate does not have the clearance it was asked for,
   which is the whole reason `isPointClearOfScenery` exists. The guarantee comes afterwards, unit
   by unit. `SETTLE_MARGIN` and the footprint computation are gone with it.
2. **`SETTLE_MAX_CANDIDATES_VERIFIED` goes from 10 to 30**, covering the ranks measured while still
   bounding the group that has no solution at all.


### The footprint varies between draws, and by how much — measured 2026-09-26

Kept because it closes the question this ticket carried, and because it argues *against* the idea it
was measured to support. The open question was whether a clearing could be sized from the group's
footprint before the spawn draws its layout. It could — the margin is bounded — but the fix no longer
needs it: what is asked for is a constant, and the footprint is not asked for at all. What the table
adds now is a second reason never to ask for it, since it moves by up to 38.8 m from one draw to the
next.

Thirty draws per group from a quiet frame, through the real chain `findGroup` → `processGroup` →
`placeGroup`, with **the alias and spacing the combat zones actually pass** (`veafShortcuts`, not a
guess: `-sa15` means `name sa15_squad, spacing 1, radius 0`). `Disposition` is not consulted at all
here, so nothing in this table is exposed to the blindness above. The radius is half the diagonal of
the units' bounding box.

| alias | spacing | radius, min – max | spread | units |
|---|---|---|---|---|
| `sa10` | 1 | 114.0 – 146.7 m | **32.6 m** (+29 %) | 14 – 15 |
| `sa11` | 1 | 69.4 – 108.1 m | **38.8 m** (+56 %) | 11 – 13 |
| `ewr` | 1 | 15.3 – 32.6 m | 17.3 m (+113 %) | 3 |
| `sa22_squad` | 1 | 5.3 – 22.3 m | 17.0 m (+320 %) | 2 |
| `sa15_squad` | 1 | 4.9 – 18.9 m | 13.9 m (+283 %) | 2 |
| `sa18_squad` | default | 11.0 – 18.7 m | 7.7 m (+70 %) | 4 – 7 |
| `smerchhe` | default | 14.1 – 20.2 m | 6.0 m (+43 %) | 7 |
| `msta` | default | 9.3 – 15.4 m | 6.1 m (+66 %) | 5 |
| `sa19_squad` | default | 2.5 – 11.3 m | 8.8 m (+353 %) | 2 |

Two readings, and the second is the one that matters:

- **In absolute terms the spread is bounded and small**: 38.8 m at worst, against translations of
  131 to 470 m. A clearing sized with a fixed margin of ~40 m absorbs every case measured.
- **In relative terms it is brutal for small groups** — `sa15_squad` holds two vehicles in every
  draw and its radius still varies by a factor of 3.9. So the variation is **not** driven by the
  unit count: it is the per-cell jitter (`veafUnits.placeGroup` picks each unit's offset inside its
  cell at random). Sizing a clearing on one observed draw would therefore be wrong even for a group
  whose composition never changes.

**The design rule this fixes:** size the clearing on the group's **worst-case** footprint, never on
a drawn one. The worst case is computable without any randomness — the maximum unit count times the
cell geometry — and a forfait margin of 40 m covers the measured residue.

## Measured in game, 6.25.0.3, 2026-09-26 evening

Mission loaded fresh, the 25 combat zones activated in one go, park pinned at 102 ground groups and
594 units — the same park as every figure above.

| measure | before ticket 10 | ticket 11, verification only | **ticket 11 + the parameters** |
|---|---|---|---|
| groups in alert | 16-18 | 19 | **15** |
| units standing in scenery | ~81 | 76 | **69** |
| groups `settleGroup` translates | — | 1 of 31 | **4 of 31** |

Of the seven groups `settleGroup` saw holding blocked vehicles, **four were fully repaired** —
1/2 → 0/2 at 113 m, 1/9 → 0/9 at 68 m, 2/10 → 0/10 at 102 m, 1/18 → 0/18 at 229 m. The parameters
work. A second activation translated six groups rather than four, which is `Disposition`'s
non-determinism showing through and is expected.

**The formation is untouched, measured rather than asserted:** 209 pairwise distances across the
translated groups, largest change **0.0000 m**.

### The remaining ceiling is coverage, not the fix

This is the finding that decides what comes next, and it is new. Matching the alerting groups
against the ones `settleGroup` actually received:

| the 15 groups still in alert | groups | blocked units |
|---|---|---|
| seen by `settleGroup` and not solved | 6 | 30 |
| **never presented to `settleGroup`** | **9** | **43 (62 %)** |

`settleGroup` is called 31 times for 102 ground groups, and **not one call is turned away** — no
declared position honoured, no exempt unit. The other 71 groups simply never reach it: they are
editor content respawned as-is, and `veafCommand` is nil for 170 of the 234 zone elements. Among
the nine never seen are the three loose `S300` groups (8/15, 10/14, 10/14) and three `Red EWR`
(3/3, 3/3, 2/3) — 36 blocked vehicles on their own.

The six that were seen and not solved are the known dead ends: `Disposition` returns **zero
candidates at every clearance, down to 5 m**, for those locations — `combatZone_Wittstock`'s S-300
(14/14) and SA-15 (2/2) among them.

So the ceiling for this ticket is reached. Raising it further is a separate question: whether
editor content should be settled at all, which is a ruling rather than a bug — David's arbitration
of 2026-08-27 says a mission maker's declared position is kept.

## Definition of done

- [x] A failing test first: a candidate that is clear on terrain but stands in scenery is **rejected**,
      and a further candidate that is genuinely clear is retained instead
- [x] A test pinning that several draws are merged: a clearing only the second draw returns is found
- [x] The clearance asked of `Disposition` no longer grows with the group, and a failing test pins it:
      a 200 m group and a 5 m group ask for the same constant. Verified red against the old code —
      it asked 250 m and 50 m
- [x] `SETTLE_MAX_CANDIDATES_VERIFIED` covers the ranks the working candidates actually come back at
- [x] Measured, and it removes the planned phase: the spawn flow does not affect `Disposition`
      (17 of 20 groups get candidates in flight, and a quiet replay recovers none)
- [x] Measured: the footprint moves by up to 38.8 m between draws, so it could not be asked for
      safely even if the singleton answered — see *The footprint varies between draws*
- [x] The rigid translation is unchanged — measured in game: 209 pairwise distances, largest
      change 0.0000 m
- [x] The docstring no longer claims a candidate is scenery-free by construction, and records the
      2026-09-26 measurements instead
- [x] Verified **in game** on GermanyCW-v6, not only in tests: 19 alerts / 76 units → **15 / 69**,
      and 4 of the 7 groups it saw in trouble fully repaired. **Not** near zero, and the reason is
      measured rather than guessed: 62 % of the blocked vehicles belong to groups `settleGroup` is
      never given — see *The remaining ceiling is coverage*
- [x] `poetry run test-lua` green (49 suites), `stylua --check` clean. `luacheck` is not installed on
      this workstation and runs in CI
- [x] `CHANGELOG.md` entry under `[Unreleased]` updated to describe the parameter fix
