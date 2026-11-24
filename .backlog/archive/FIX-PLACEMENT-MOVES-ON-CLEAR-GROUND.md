# FIX-PLACEMENT-MOVES-ON-CLEAR-GROUND — the escort is moved even when the requested spot is free

Status: ✅ done — every ticket verified in game 2026-10-03; merged in #1055 · archived 2026-11-24

Origin: measured in game 2026-08-28 while running
[`DCS-SESSION-TODO`](../../DCS-SESSION-TODO.md) item 21, the exhaustion count for
[`FIX-PLACEMENT-IGNORES-SCENERY`](FIX-PLACEMENT-IGNORES-SCENERY.md) ticket 04. David's call,
same day: a lot of its own.

## What was measured

The item 21 protocol includes an explicit non-regression case: a `-farp` on **open ground, nothing
within a kilometre**. Nothing should move there. Something did:

```
VEAF-GRASS|I|bearingFromSceneryCloud: findClearBearing: scenery-clear bearing 25 at 1.0540926357404x distance
VEAF-GRASS|I|buildFarpUnits: FARP escort: bearing 0 requested, 25 used at 1.0540926357404x distance
```

Bearing 0 was asked for; bearing 25 at 1.12× was used. All four of the item 21 cases moved, including
this one.

## Why

[`veafGrass.findClearBearing`](../../src/scripts/veaf/veafGrass.lua) runs tier 1 — the scenery cloud —
**before testing the requested bearing at all**:

```lua
  local cloudAngle, cloudScale = bearingFromSceneryCloud(baseAngle, positionsFor, own, allClear)
  if cloudAngle then
    return cloudAngle, cloudScale
  end

  -- Tier 2 — walk the bearings, then the distances.
  for _, scale in ipairs(veafGrass.PLACEMENT_DISTANCE_STEPS) do
    -- The original bearing first at every distance, so the group stays where it was aimed when it can.
    if allClear(baseAngle, scale) then
```

`bearingFromSceneryCloud` asks `Disposition` for a cloud of clear points, sorts them by `gap` — their
distance to the spot actually wanted — and returns the nearest one that passes the occupancy probe.
**The wanted spot is never itself a candidate**, so as long as the cloud answers at all, the escort is
moved. Tier 2 states the opposite intent in its own comment, and never gets the chance to act on it.

## Why the obvious fix is wrong

Testing `allClear(baseAngle, 1)` before consulting the cloud would put escorts back in the trees:
`allClear` runs the occupancy probe, which sees units, statics, aprons and buildings — **not forests**.
Forests are only knowable through `Disposition`, and `Disposition` cannot be asked *"is this spot
clear?"*; it only proposes points. That asymmetry is the whole reason tier 1 exists, and it is
documented at length in `findClearBearing`.

## The tenable route

Tier 1 already computes `gap` for every candidate — the distance from the candidate to the wanted spot.
If the best candidate's `gap` is smaller than the clearance the group needs
(`veafGrass.PLACEMENT_CLEARANCE`), then the wanted spot is inside the same clearing that candidate
proves, and it can be kept as-is: `return baseAngle, 1`.

This is a hypothesis with a plausible mechanism, not a verified fix. It needs the same in-game proof
the placement work has always needed.

## Why it matters beyond tidiness

`FIX-PLACEMENT-IGNORES-SCENERY` ticket 04 must prove *"a FARP far from anything is never refused and
**nothing moves**"* before it can ship. That half is currently unprovable, because it is false on
`develop` independently of anything ticket 04 does. **This lot unblocks that proof.**

It also touches the trade `FIX-FARP-ESCORT-PLACEMENT` was careful about: five rounds of changes, four
of them about how aggressively placement refuses ground, and the non-regression — *"c'est bon, rien n'a
bougé"* — mattered more than the reported case. Moving every FARP escort in every existing mission by
a few dozen metres is exactly the outcome that history was guarding against.

## Scope

| # | Ticket | Risk | Status |
|---|---|---|---|
| 01 | Keep the requested bearing when the cloud proves it clear | medium — changes where every FARP escort lands | ✅ |
| 02 | Verify in game that a FARP on open ground does not move | needs DCS | ✅ |
| 03 | [Ask about the wanted spot itself, not its nearest neighbour](FIX-PLACEMENT-MOVES-ON-CLEAR-GROUND.md) | medium — replaces ticket 01's method | ✅ |
| 04 | The escort stands beside its own FARP's props, and the bearing walk stays out of the trees | low — the escort only; a `-farp` in a dense wood is now refused | ✅ |

## What ticket 01 delivered (2026-09-01)

The hypothesis above held, and the geometry behind it is worth stating once: candidates are asked of
`Disposition` with a safe radius of `extent + PLACEMENT_CLEARANCE`, and the group's footprint reaches
`extent` from the wanted spot — so a candidate whose `gap` is at most `PLACEMENT_CLEARANCE` puts every
position the group would occupy inside the clearing that candidate proves. The threshold is not a tuned
number; it is the one the radius was already built from.

The guard is `nearest.gap <= PLACEMENT_CLEARANCE` **and** `allClear(baseAngle, 1)`. Dropping the second
conjunct would place an escort on an apron whenever the ground around it happened to be scenery-clear —
the very defect `FIX-FARP-ESCORT-PLACEMENT` spent five rounds removing — and a test pins it.

Two sides, both proven to fail: reverting the fix turned the two "keeps its bearing" tests red with
`expected: 90, actual: 87.709389957362`, and the two "still moves" tests were red under a deliberate
sabotage of the corrected code (threshold widened tenfold, and the occupancy conjunct removed). The
sabotage table is in [ticket 01](FIX-PLACEMENT-MOVES-ON-CLEAR-GROUND.md).

The PRD's note was applied: `no usable point in Disposition's cloud, walking the bearings instead` is
now at **info**, so no one has to set `veafGrass.LogLevel = "debug"` to find out why a group moved.

## Measured in game 2026-09-01 — the guard never fires

David ran three `-farp` markers, one of them on open ground with nothing within a kilometre. The
escort was moved **every time**, and the guard's own line — `bearing N is inside a scenery-clear
area, keeping it` — does not appear once in the whole session.

The decision was then instrumented (#898) to log both operands before it is taken. Twelve decisions:

| gap (m) | 61.8 | 46.3 | 83.9 | 81.3 | 58.5 | 43.9 | 97.0 | 82.5 | 73.1 | 48.5 | 69.4 | 127.0 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|

Against `PLACEMENT_CLEARANCE = 12`. **The nearest candidate ever seen sits at 43.9 m — nearly four
times the threshold.** The occupancy probe answered `true` on half of them, so it is not what refuses.

### Why the approach cannot work, not just this threshold

`Disposition.getSimpleZones(centre, radius, safeRadius, attempts)` **samples at random** inside the
circle; it does not tessellate it. Nothing makes a sample land near the requested spot, and twelve
measurements say none comes close.

So *"the nearest candidate proves the wanted spot"* is unsound as a method, whatever the constant.
Widening the threshold to 130 m would accept a spot nothing has shown to be clear — the original
defect, mirrored.

### What the tests did not catch, and why

`test_a_candidate_proving_the_wanted_spot_keeps_the_bearing_and_the_distance` builds its `gap` at
`PLACEMENT_CLEARANCE * 0.5` — a value chosen so the branch runs. The geometry it checks is true; the
situation it checks is one the game does not produce. A test that constructs its own input can only
ever confirm the theorem, never the premise.

### The route that remains

Ask about **the wanted spot itself** instead of deducing from a neighbour: `Disposition.getSimpleZones`
centred on `wanted[1]` with a small radius, and read whether DCS offers a free zone there. Same API,
same knowledge of forests, asked at the right place. `Disposition.getPointHeight` and
`getPointWater` exist alongside it and may be cheaper — establish which answers the question before
building on either.

Whatever replaces it must be measured against a **real** `-farp`, not a fabricated gap, before it is
called done.

## Definition of done

- [x] A requested spot that is genuinely clear — of buildings, of forests, of everything — keeps its
      bearing and its distance, with no move at all
- [x] A requested spot that is not clear still moves, and still avoids forests: tier 1 keeps doing what
      it was added for
- [x] Lua tests covering both, driven off the `gap` the cloud returns rather than off the implementation
- [ ] Verified in game: a `-farp` on open ground with nothing within a kilometre produces **no**
      `FARP escort: bearing 0 requested, N used` line with `N ~= 0`
- [x] `stylua --check` clean; `luacheck` is not installed on this workstation and runs in the CI Lua gate

## Note for whoever runs the in-game check

~~`no usable point in Disposition's cloud, walking the bearings instead` is emitted at **debug**
([`veafGrass.lua:439`](../../src/scripts/veaf/veafGrass.lua)) and is therefore invisible at the default
log level~~ — **settled 2026-09-01: that line now logs at info**, so the default log level says why a
group fell through to tier 2. The rest of the protocol is in
[ticket 02](FIX-PLACEMENT-MOVES-ON-CLEAR-GROUND.md), including the two cases that must **still**
move: a run where nothing moves anywhere means the fix went too far.

## In-game check — 2026-10-03

From `FIX-IN-GAME-SESSION-2026-10-03`.

R19, Caucasus, four `-farp`: in a wood the escort left the trees (`scenery probe=false`, 0° → −15°).
On open ground, and beside a static FARP, the first elements kept their bearing and the fourth and
fifth read `occupancy probe=false`, so the escort moved (333° at 1.14×, 38° at 1.16×): **the FARP's
own vehicles, placed first, occupy the escort's wanted spot**. The refusal case was not reached.

## Ticket 04 — the escort beside its own FARP (2026-10-03)

The tents, the props and the windsock are laid out before the escort and on the same bearing, so the
occupancy probe found the FARP's own statics on the escort's wanted spot. David's call: the escort's
search ignores statics named `FARP <group> unit #` — its own layout — and everything else still
occupies. The tents, props and windsock keep avoiding what stands before them.

`isSpotOccupied` now also returns the name of what it found, and `findClearBearing` logs it for the
wanted spot at debug: the 2026-10-03 run read `occupancy probe=false` and nothing said by what, so the
cause above is deduced from the layout's geometry, to be confirmed by that line in the next run.

## Former index entry

The row this lot had in `.backlog/README.md` until the index was split into short summaries (CHORE-BACKLOG-INDEX-SPLIT, 2026-10-03), kept verbatim.

**a FARP escort is moved even when the spot asked for is free.** `findClearBearing` consults the scenery cloud before testing the requested bearing at all, and the wanted spot is never one of the cloud's candidates — so the escort moves whenever the cloud answers. Measured 2026-08-28 on open ground with nothing within a kilometre: bearing 0 requested, 25 used at 1.12×. Testing the requested bearing first is *not* the fix (the occupancy probe cannot see forests); the tenable route is the `gap` tier 1 already computes. **Blocks `FIX-PLACEMENT-IGNORES-SCENERY` ticket 04**, whose definition of done requires proving nothing moves. Fixed and tested 2026-09-01 — a candidate within `PLACEMENT_CLEARANCE` of the wanted spot now proves it, and the wanted spot is kept; only the in-game proof remains **Reopened 2026-09-01: the guard is inert.** Measured in game over twelve decisions, the nearest candidate sits between 43.9 m and 127 m of the wanted spot against a 12 m clearance, so the condition never holds. `Disposition.getSimpleZones` samples at random rather than tessellating, so deducing from the nearest neighbour is unsound whatever the constant — ticket 03 asks about the wanted spot itself, with the small scenery probe `settleGroup` uses; implemented 2026-09-30, waiting on R19. **R19 run 2026-10-03:** the forest case held, but on open ground the escort still moved — its own FARP's props, laid out first on the same bearing, occupied its spot; ticket 04 lets the escort stand beside them

## Tickets, in full

## 01 — Keep the requested bearing when the cloud proves it clear

Status: ✅ done
Type: fix

### What exists

[`veafGrass.lua`](../../src/scripts/veaf/veafGrass.lua), tier 1 of `findClearBearing`, asks
`Disposition` for a cloud of scenery-clear points, orders them by `gap` — their distance to the spot the
caller actually wanted — and returns the nearest one that passes the occupancy probe.

The spot the caller wanted is **never one of those candidates**. So as long as the cloud answered at
all, the group moved. Measured in game 2026-08-28 on open ground with nothing within a kilometre:

```
VEAF-GRASS|I|bearingFromSceneryCloud: findClearBearing: scenery-clear bearing 25 at 1.0540926357404x distance
VEAF-GRASS|I|buildFarpUnits: FARP escort: bearing 0 requested, 25 used at 1.0540926357404x distance
```

Tier 2, immediately below, states the opposite intent in its own comment — *"the original bearing first
at every distance, so the group stays where it was aimed when it can"* — and never got the chance to act
on it.

### What was ruled out

Testing `allClear(baseAngle, 1)` before consulting the cloud. `allClear` runs the occupancy probe, which
sees units, statics, aprons and buildings but **not forests** — trees are not scenery objects, and
`land.getSurfaceType` answers LAND for a wood exactly as for a meadow. Forests are knowable only through
`Disposition`, which cannot be asked *"is this spot clear?"*; it only proposes points. That asymmetry is
the entire reason tier 1 exists, so probing first would put escorts back in the trees.

### What changed

One guard, between the sort and the candidate loop:

```lua
  local nearest = options[1]
  if nearest and nearest.gap <= veafGrass.PLACEMENT_CLEARANCE and allClear(baseAngle, 1) then
    return baseAngle, 1
  end
```

The geometry it rests on, which is why the threshold is `PLACEMENT_CLEARANCE` and not a new constant:
every candidate was asked of `Disposition` with a safe radius of `extent + PLACEMENT_CLEARANCE`, and the
group's footprint reaches `extent` from `wanted[1]`. A candidate whose `gap` is at most
`PLACEMENT_CLEARANCE` therefore puts **every** position the group would occupy inside the clearing that
candidate proves. The wanted spot is out of the trees, and only the occupancy probe is left to
consult — hence the `allClear(baseAngle, 1)` conjunct, which keeps units, statics and the apron
deciding exactly as before.

Also, per the PRD's note to whoever runs the in-game check: *"no usable point in Disposition's cloud,
walking the bearings instead"* moved from **debug** to **info**. It was invisible at the default log
level, which is why the 2026-08-28 run could not tell why the forest case fell through to tier 2. It
fires only when the cloud answered and nothing in it survived — at worst once per group, never in the
nominal case.

### Tests — proven to fail on both sides

Four tests in `TestVeafGrassSceneryCloud`, driven off the `gap` rather than off the shape of the code.

**Red before, green after.** With the fix reverted, two of the four failed with exactly the measured
defect:

```
test_a_candidate_proving_the_wanted_spot_keeps_the_bearing_and_the_distance
  a spot proven clear of scenery must keep its bearing
  expected: 90, actual: 87.709389957362
test_the_nearest_candidate_decides_whatever_order_the_cloud_arrives_in
  expected: 90, actual: 87.709389957362
```

The other two — `test_a_candidate_too_far_to_prove_the_wanted_spot_still_moves_the_group` and
`test_a_proven_wanted_spot_that_is_occupied_is_still_left` — passed before the fix, deliberately: they
pin the behaviour tier 1 was added for, so that keeping a clear spot cannot quietly become "never move".

**Then the corrected code was sabotaged three ways, and each sabotage was caught:**

| Sabotage | Test that went red |
|---|---|
| `nearest.gap <= veafGrass.PLACEMENT_CLEARANCE * 10` — threshold widened tenfold | `test_a_candidate_too_far_to_prove_the_wanted_spot_still_moves_the_group`, plus the pre-existing `test_the_candidate_nearest_the_requested_spot_wins` |
| `and allClear(baseAngle, 1)` removed from the guard | `test_a_proven_wanted_spot_that_is_occupied_is_still_left` |
| `local nearest = options[#options]` — read the farthest candidate | `test_the_nearest_candidate_decides_whatever_order_the_cloud_arrives_in` |

The second one is the one worth keeping in mind: without it the fix would place an escort on an apron
whenever the surrounding ground happened to be scenery-clear, which is precisely the defect
`FIX-FARP-ESCORT-PLACEMENT` spent five rounds removing.

### Definition of done

- [x] A requested spot clear of everything keeps its bearing **and** its distance
- [x] A requested spot that is not clear still moves, and still avoids forests
- [x] Both sides covered by tests, each proven to fail when the code is broken
- [x] Lua coverage ratchet honoured (79.52 % measured, CI floor 77 → 78)
- [x] `stylua --check src/scripts/veaf/ test/lua/` clean; `luacheck` not installed on this
      workstation, left to the CI Lua gate

## 02 — Verify in game that a FARP on open ground does not move

Status: ✅ done — run in game 2026-09-01, and the answer is **negative**: the escort moved on all three markers, open ground included. The twelve measurements are in the PRD; ticket 03 replaces the method.
Type: verification

Nothing here can be done without DCS running. The unit tests prove the rule; only the game can say
whether `Disposition` answers the way the rule assumes, because the whole tier rests on an undocumented
singleton (ADR 0018) whose behaviour has already been measured to differ from its arguments — asked
800 m in game on 2026-08-06, it answered 2035-2258 m.

### What to run

The session mission of `DCS-SESSION-TODO.md` — Caucasus, security off — rebuilt with `--dev-mode`
against this branch so it carries the fix.

1. `-farp` on **open ground, nothing within a kilometre**. This is the non-regression case of item 21.
2. `-farp` **in or beside a wood**, so the requested spot is genuinely in the trees.
3. `-farp` **beside a static FARP**, so the requested spot is on its apron.

### What to look at

`%USERPROFILE%\Saved Games\DCS\Logs\dcs.log`, grep `FARP escort:` and `findClearBearing:`.

| Case | Expected |
|---|---|
| Open ground | `FARP escort: bearing N requested, N used at 1x distance` — the two bearings **equal**, scale 1. Plus `findClearBearing: bearing N is inside a scenery-clear area, keeping it` |
| Wood | the two bearings **differ**, and the escort is visibly out of the trees |
| Beside a static FARP | the two bearings **differ**, or the scale is above 1, and the escort is off the apron |

The middle and last rows are what make this a real check rather than a confirmation: a run where
*nothing* moves in any of the three cases means the fix went too far, and is a failure of this ticket,
not a pass.

`findClearBearing: no usable point in Disposition's cloud, walking the bearings instead` is now at
**info**, so it is readable at the default log level. If it appears in the open-ground case, the cloud
answered nothing usable and tier 2 took over — the outcome is still "nothing moves", but the reason is
not the one this lot implemented, and that is worth recording.

### What it unblocks

[`FIX-PLACEMENT-IGNORES-SCENERY` ticket 04](FIX-PLACEMENT-IGNORES-SCENERY.md)
requires proving *"a FARP far from anything is never refused and **nothing moves**"*. That half was
false on `develop` independently of anything ticket 04 does.

Its exhaustion measurement — `nothing clear at any bearing or distance` fired 0 times out of 4 on
2026-08-28 — is **not** disturbed by this fix, and does not need re-running: the new guard only adds an
earlier way to accept, it never makes the search harder, so a case that did not exhaust before cannot
start exhausting now. What ticket 04's `T1-DEGAGE` row records — *bearing 0 → 25, 1.12x* on open
ground — is what this ticket expects to see change.

## 03 — Ask about the wanted spot itself, not about its nearest neighbour

Status: ✅ done — in game 2026-10-03 the wanted spot in a wood was refused by the scenery probe and the escort left the trees; the open-ground half failed for another reason, carried by ticket 04
`FIX-PLACEMENT-IGNORES-SCENERY` ticket 04); what is left is the in-game check, item R19 of `DCS-SESSION-TODO.md`

Type: fix · Files: `src/scripts/veaf/veafGrass.lua`, `test/lua/test_veafGrass.lua`

Replaces the approach ticket 01 shipped. Ticket 01 is **not** reverted: its occupancy-probe
composition and its logging stay, and its own record of what it delivered stays honest.

### Why ticket 01's guard cannot fire

Measured in game 2026-09-01, twelve instrumented decisions across three `-farp` markers:

```
gap (m):  61.8  46.3  83.9  81.3  58.5  43.9  97.0  82.5  73.1  48.5  69.4  127.0
PLACEMENT_CLEARANCE = 12
```

The nearest candidate ever offered is at **43.9 m**, nearly four times the threshold. The guard's own
log line appears **zero** times in the session.

`Disposition.getSimpleZones(centre, radius, safeRadius, attempts)` **samples at random** inside the
circle rather than tessellating it, so nothing makes a sample land near the requested spot. *"The
nearest candidate proves the wanted spot"* is therefore unsound as a method, whatever constant it
uses — and widening the threshold to ~130 m would accept a spot nothing has shown to be clear, which
is the original defect mirrored.

### What to do instead

Ask DCS about the wanted spot directly. Candidates, in the order worth trying:

1. `Disposition.getSimpleZones(wanted[1], smallRadius, extent + PLACEMENT_CLEARANCE, n)` — same API,
   same knowledge of forests, asked at the right place. A free zone returned within a few metres of
   the centre answers the question.
2. `Disposition.getPointHeight(pos)` / `Disposition.getPointWater(pos, …)` — both exist beside it and
   may be cheaper. **Establish what they actually answer before building on either**; the schema in
   `veaf_libs/data/dcs-schema/dcs-world-api.lua` gives signatures, not semantics.

Whichever is chosen, the reasoning goes in the code: the next reader needs to know why the neighbour
approach was dropped.

### What was built, 2026-09-30

Candidate 1, in its dependable form: the small probe `veafUnits.settleGroup` sweeps with since
`FIX-PLACEMENT-IGNORES-SCENERY` ticket 12 — 5 m free within 20 m, deterministic, 0.38 ms — asked at
**every** position of the escort, not at a single centre. The values are restated in veafGrass
(`SCENERY_PROBE_RADIUS` / `SCENERY_PROBE_CLEARANCE`), since it loads before veafUnits, and a test pins
them. `getPointHeight` / `getPointWater` were not pursued: the probe is already measured to answer the
question. When both probes clear the spot, the large query is **not asked at all** (12 ms saved).

Three sabotages, each caught: probe always blocked → 4 tests red; probe always clear → 3 red, among
them *one truck in the trees moves the group*; exhaustion reported as found → 2 + 2 red.

### Definition of done

- [x] The requested bearing is kept when the wanted spot is itself clear of scenery, with the occupancy
      probe still deciding on top — that composition is ticket 01's and is correct
- [ ] Verified against a **real** `-farp` on open ground, not a fabricated gap: the guard's log line
      appears, and bearings come out equal at `1x` — R19
- [ ] Still moves the escort in or beside a wood, and off a static FARP's apron — the two halves that
      make the check able to fail — R19
- [x] The instrumentation from #898 replaced by a line logging both probes' answers before the decision
      (`wanted spot at bearing N: scenery probe=…, occupancy probe=…`)
- [x] No test builds its own `gap` to make a branch run: the tests drive what the probe answers, and the
      one constructed distance (43.9 m) is the nearest gap measured in game on 2026-09-01

### The lesson this ticket exists to record

Ticket 01's test asserts a true theorem about a situation the game does not produce. It was green,
reviewed, and shipped, and the defect it was written for survived untouched. **A test that constructs
its own input can confirm the theorem but never the premise** — and the premise is where this one
failed.

## 04 — The escort stands beside its own FARP's props

Status: ✅ done — verified in game 2026-10-03
Type: fix

R19 of 2026-10-03: on open ground the escort still moved, `occupancy probe=false` on its wanted spot.
The FARP's own tents, props and windsock are laid out first on the same bearing. The escort's search
now ignores statics named after its own FARP; the probe names what it found. Details in the
[PRD](FIX-PLACEMENT-MOVES-ON-CLEAR-GROUND.md).

### To see in game

A `-farp` on open ground: `FARP escort: bearing 0 requested, 0 used at 1x distance`, and — before the
fix is trusted — the debug line `isSpotOccupied: ignoring FARP … unit #N, part of this FARP`, which
confirms what used to block it. A `-farp` in a wood still moves out of the trees.

### Seen in game (2026-10-03, second pass)

The probe now names what it found: on all four `-farp` the wanted spot was occupied by `FARP … unit
##10` (or `#9` beside the static FARP) — the FARP's own windsock or generator. With them ignored, open
ground, beside a static FARP and the deep-wood case all logged `FARP escort: bearing 0 requested, 0
used at 1x distance`.

It also showed a second defect, fixed in the same branch: in the wood case the escort **stayed in the
trees**. The cloud was empty (`0 cloud candidate(s)`), so the bearing walk decided, and it only asked
the occupancy probe. This morning's run had moved out of the trees by accident, the windsock blocking
bearing 0. The walk now also asks the small scenery probe. Re-run on the rebuilt mission: no free patch
at any of 24 bearings at 150, 225 or 300 m around that spot (measured), and the `-farp` was **refused**
— `no clear ground for its escort`, the first time the refusal case of FIX-PLACEMENT-IGNORES-SCENERY
ticket 04 has been reached in game.
