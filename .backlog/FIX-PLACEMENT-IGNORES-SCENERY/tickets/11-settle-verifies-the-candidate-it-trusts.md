# 11 — `settleGroup` verifies the candidate it trusts, and draws more than once

Status: 🔄 in-progress — the verification below is written and green, **and it is not enough**: measured
in game on 2026-09-26 it changed nothing (20 group alerts, 75 blocked units). The reason is under it
and is now the heart of this ticket — see *The verification is blind where it runs*. What remains to
build is the pre-computation described at the end.
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

**The caveat on the comparison, stated rather than smoothed over:** the reference figures come from
the 2026-09-25 session and the parks were not pinned side by side, so 19-versus-16 is not a
regression measurement. What the run does establish without reservation is that the number is **not
near zero**, and that its order of magnitude did not move.

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

## What this ticket does

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

## The verification is blind where it runs

Everything above is built and green, and it moved nothing: 20 group alerts and 75 blocked units,
against 19 and 66 before it. The verification always answers "clear", because **`Disposition` is
blind inside `settleGroup`'s call stack**.

The measurement that shows it uses **witness points**: fixed coordinates, unrelated to the group
being placed, whose truth is 9 blocked out of 15.

| the same witness points, probed from | answer |
|---|---|
| inside `settleGroup` | **0 / 15** |
| one second later | 9 / 15 |

Units land exactly on the coordinates examined — largest displacement **0.0 m** over 15 units — so
this is not a coordinate mix-up, and it is not local to the group: it is global and it is brief.

**Ruled out, each one measured. Do not revisit these:**

| hypothesis | measurement |
|---|---|
| a burst of calls exhausts it | 12 consecutive passes when quiet: 9, 9, 9… identical |
| it needs warming up | 5 consecutive passes *inside* `settleGroup`: all 0 |
| creating a group blinds it | creating one in the same frame: no effect |
| destroying units blinds it | no effect |
| the units block their own test | destroying the group leaves the count at 9 — the alerts really are trees |
| the shape of the table passed | `{x,y,z}`, extra fields, no `y`, `y=0`: identical |
| a large-radius call poisons it | one, then ten, then a real `veaf.findSpawnPoint`: no effect |
| an exception swallowed as "clear" | no — all 15 calls **succeed** and return candidates |

**The cause is unknown**, and that is a conclusion rather than a pause. What matters is that
`Disposition` is dependable everywhere except in that call stack.

### Deferring the spawn was tried, and must not be retried as such

Delaying the whole spawn by one second does make the probe truthful — 16 groups out of 16, with all
25 combat zones firing at once. It also breaks the mission: the group name a spawn returns feeds
`Group.getByName`, and with it `veaf.readyForCombat`, convoy routing and **`veafSkynet.declareSpawn`**
([`veafSpawnCore.lua:417-460`](../../src/scripts/veaf/veafSpawnCore.lua)). Defer the creation and that
whole block runs on nothing — which is precisely the regression that removed all nine SAM batteries
on the morning of the same day. Four tests in `test_veafSpawn.lua` catch it, since they assert on the
returned group name.

## What is left to build: compute the clearings outside the spawn

David's call, and the measurement backs it: **ask `Disposition` first, in a phase of its own, and let
the spawn use an answer that is already settled** — never querying it from inside the spawn flow.

Replayed from a quiet frame on the 16 offending groups, the selection built above (per-unit
verification, three merged draws) gives:

- **9 groups solved**, translations of 131 to 470 m, **every large S-300 among them** (11/14, 12/15
  and 9/14 vehicles blocked);
- **7 not solved**, and never because verification refused: **zero candidates offered** every time.
  Three are convoys (footprint around 400 m) and exempt anyway; the remaining four are genuinely
  hemmed in, `combatZone_Wittstock [r] SA15` being the known one.

So the approach works; what is left is where to put the phase. Simplest shape: when a combat zone
activates, one pass asks for the clearings around the zone, then the spawns draw from that list.

**Open question to settle before writing code:** a group's internal layout is drawn at random *at
spawn time*, so the exact footprint is not known in advance. The measurement above starts from the
real footprint of already-spawned groups, so it suggests strongly — but does not prove — that a
clearing sized generously enough still fits whatever layout comes out. Measure that first.

## Definition of done

- [x] A failing test first: a candidate that is clear on terrain but stands in scenery is **rejected**,
      and a further candidate that is genuinely clear is retained instead
- [x] A test pinning that several draws are merged: a clearing only the second draw returns is found
- [ ] The clearings are obtained outside the spawn flow, and `settleGroup` never calls `Disposition`
      from inside it
- [ ] Measured first, before the code: a clearing sized from an estimated footprint still fits the
      layout the spawn actually draws
- [ ] The rigid translation is unchanged — inter-unit distances still preserved to the metre
- [ ] The docstring no longer claims a candidate is scenery-free by construction, and records the
      2026-09-26 measurements instead
- [ ] Verified **in game** on GermanyCW-v6, not only in tests: group alerts near zero, and spacings
      unchanged. Ticket 10 was green in CI and inert in game; this one does not ship on tests alone
- [ ] `poetry run test-lua` green, `stylua --check` and `luacheck` clean
- [ ] `CHANGELOG.md` entry under `[Unreleased]`
