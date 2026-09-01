# 03 — The FARP escort avoids the scenery too

Status: ✅ done — 2026-08-27
Type: fix

## Delivered

Two criteria, composed, because neither covers the other:

- **Buildings** — `Object.Category.SCENERY` joins `isSpotOccupied`'s existing category loop. One element
  in an `ipairs`, same volume, same callback, same `pcall` guard: an escort clear of every unit, static
  and apron could still stand through a house.
- **Forests** — a new **tier 1** in `findClearBearing`, on David's design: ask `Disposition` **once** for
  a cloud of scenery-clear points, keep those inside the accepted distance band, order them by how near
  they are to the spot actually wanted, and take the first whose whole arc passes the occupancy probe.
  Falls through to the bearing walk when the singleton is absent, raises, or answers nothing usable.

**David's design is what made the forest half possible at all.** The ticket as written assumed the
criterion would come from `findSpawnPoint`'s tier 1, which cannot work — see the measurement below.
Inverting the search (select from a cloud instead of testing our own candidates) also turns the
singleton's radius overshoot from a blocker into a non-issue, because the distance filter becomes ours,
and it costs **one** call to the undocumented API per group instead of one per candidate position.

`veaf.doNotAvoidScenery` silences the new tier as it silences `findSpawnPoint`'s, and ADR 0018 holds:
absent, raising or nonsensical, `Disposition` degrades and never aborts a FARP.

### Two bugs found by the tests, both real

- **A candidate at exactly the requested distance was discarded.** Trigonometry turns 150 m into
  0.9999999999999998 × 150, so a bare `scale >= 1` dropped the *best available* point in silence. The
  failure surfaced as "the nearest candidate did not win", which is how it would have looked in game
  too. Fixed with a named one-metre tolerance (`PLACEMENT_DISTANCE_TOLERANCE`) — noise against a 150 m
  escort distance and a 12 m clearance — and pinned by its own test.
- **`math.atan2` answers in (-180, 180],** so a bearing of 270° came back as −90°. Harmless to the
  geometry (`cos`/`sin` do not care) but wrong in the log a mission maker reads, and wrong as a returned
  bearing. Normalised to 0-360, with its own test.

Also worth recording: the `lua` on this workstation's PATH is **lua55.exe**, where `math.atan2` does not
exist at all — it is the test shim that supplies it. A standalone script written to reproduce the
arithmetic died on that before it could say anything useful.

## What exists

[`veafGrass.findClearBearing`](../../../src/scripts/veaf/veafGrass.lua) is a real clear-ground search,
built by `FIX-FARP-ESCORT-PLACEMENT` and verified in game on 2026-08-24. It tries the requested bearing
first at each distance in `PLACEMENT_DISTANCE_STEPS`, then alternates sides in
`PLACEMENT_BEARING_STEP` increments, so a group with clear ground does not move at all and a nearer
bearing beats a further one. It is used for the escort, the tents, the props and the windsock
(`veafGrass.lua` 1478, 1568, 1631, 1728).

What it tests, through `veafGrass.isSpotOccupied`, is **units and statics** within a clearance, plus
**landing-platform footprints** — the FARP's own 259 m apron included, measured via
`Airbase:getDesc().box`.

What it does not test is the scenery, and the code says so:

> [`veafGrass.lua:258`](../../../src/scripts/veaf/veafGrass.lua): *"`world.searchObjects` is right for
> that, and scenery is **deliberately left** to `veaf.findSpawnPoint`'s Disposition tier."*

**But the FARP layout path never calls `veaf.findSpawnPoint`.** The criterion was delegated to a tier
that is not on this path, so nothing applies it. An escort clear of every unit, static and apron can
still be standing in a forest or through a building.

## What this ticket does

Add the scenery criterion to `allClear` inside `findClearBearing`, so a candidate bearing is rejected
when its positions are not on usable ground.

The mechanism is already available and must be **reused, not reinvented** — `veaf.lua` holds
`acceptableGroundPoint`, which is what `findSpawnPoint`'s own tiers validate with, and the `Disposition`
singleton behind tier 1. Two things to settle before coding, by reading `findSpawnPoint`:

- **Which check to reuse.** `acceptableGroundPoint` is a local in `veaf.lua`; exposing it, or a thin
  `veaf.isAcceptableGroundPoint`, is preferable to a second copy of the same rule. A duplicated
  ground-acceptability rule is how this family of defect got here in the first place.
- **`Disposition` is quality-only, never correctness** ([ADR 0018](../../../docs/adr/0018-undocumented-dcs-api-dependency.md)).
  The guard and the `pcall` are mandatory: a singleton absent on another DCS version or map must degrade,
  never abort a FARP.

## MEASURED 2026-08-27 — the cost is fine, but the mechanism the ticket assumed is wrong

David asked for the cost first. Both answers came out of the same measurement, and the second one
matters more.

### The probe budget is bounded, and smaller than the ticket feared

Counted by instrumenting `isSpotOccupied` around `findClearBearing` for a three-object group
(`test_the_probe_budget_stays_bounded` now pins these):

| Case | Probes per group |
|---|---:|
| Clear ground — the nominal case | **3** |
| Nothing clear anywhere | **75** |
| Theoretical ceiling | 225 |

The abstract product is 3 distances × 25 bearing evaluations × 3 positions = 225, but `allClear`
returns on its **first** occupied position, so a crowded bearing costs one probe rather than three.
The expensive case is not "everything is blocked", it is "almost everything is clear".

Each probe already performs up to **two** `world.searchObjects` calls (`UNIT`, `STATIC`). Adding one
category makes it three — **+50 % on the searches, not a new order of magnitude** — and this runs once
when a FARP is built, not on a tick. Nominal cost of the whole change: 3 extra searches per group, four
groups per FARP. That is nothing.

### `Disposition` cannot do this job at all

The ticket assumed the scenery criterion would come from `veaf.findSpawnPoint`'s tier 1. It cannot:
**`Disposition.getSimpleZones` *proposes* candidate points, it does not test a point you hand it.**
Testing 75 specific positions with a proposal API would mean 75 calls plus matching returned points
against the one asked about — and its radius argument is measured **not** to bound its answers (asked
800 m, returned points 2035-2258 m out), so a tiny-radius probe cannot distinguish "clear" from
"here is somewhere else entirely".

### So the three mechanisms split by what they can see, sourced not assumed

| Mechanism | Buildings | Forests | Can test a given point? |
|---|---|---|---|
| `land.getSurfaceType` | no | **no** — [`FEAT-SCENERY-AWARE-SPAWN`](../../archive/FEAT-SCENERY-AWARE-SPAWN.md) measured that it *"answers LAND for a forest exactly as for a meadow"* | yes, cheap |
| `world.searchObjects(Object.Category.SCENERY, …)` | **yes** | no — trees are not scenery objects | yes, cheap, and `isSpotOccupied` already runs this exact loop for two other categories |
| `Disposition.getSimpleZones` | yes | **yes** — the same probe found *"gaps beside the trees"* and **0 points** in a dense forest | **no** |

`world.searchObjects(Object.Category.SCENERY, …)` is not speculative: two vendored community scripts
already call it (`AIEN.lua`), so the API works.

### The open decision this leaves — buildings now, forests not point-testable

Adding `Object.Category.SCENERY` to `isSpotOccupied`'s existing category loop gives the escort
**building** clearance for a one-element change. It does **not** give forest clearance, and no API we
have can answer "is this spot in a wood?" for a point we choose.

Getting forests in would mean inverting the search: ask `Disposition` **once** per group for clear
candidates and pick the bearing nearest one. That is one call instead of 75 — but its radius overshoot
means the candidates land well outside the escort distance, which fights #232's arbitration that the
escort stays close to the FARP it serves. **Not resolved here; it is David's call.**

### Still not measurable without DCS — and it is ticket 04's gate

How **often** the search exhausts once buildings count. That number is what ticket 04 needs to choose
its refusal threshold, and it cannot come from mocks: it depends on real terrain. Either the smoke
harness answers it or it goes to [`DCS-SESSION-TODO.md`](../../../DCS-SESSION-TODO.md).

### The cost, which is why this needed measuring and not just adding

`findClearBearing`'s own comment warns about the call volume: *"a full turn tries 24 bearings at each
distance, and each bearing tests every position the group would occupy"*. That is why the airbase list
is read once, outside the probe. Adding a per-position scenery test multiplies the same product, and the
per-call cost of `Disposition.getSimpleZones` is recorded as **still unmeasured**.

So: measure it before shipping. If the cost is real, the scenery test belongs at the *bearing* level
rather than per position, or only on the bearings that already passed the cheap tests.

## It applies to both kinds of FARP — unlike the refusal

`findClearBearing` serves both callers of `veafGrass.buildFarpUnits`: the `-farp` command
([`veafSpawnGround.lua:105`](../../../src/scripts/veaf/veafSpawnGround.lua)) and the editor's static FARPs
([`veafGrass.lua:586`](../../../src/scripts/veaf/veafGrass.lua), scheduled at startup). The scenery
criterion applies to **both** — moving an escort out of a forest is an improvement wherever the FARP came
from. David's ruling 3 restricts the **refusal** to the spawned path, not the search.

That said, this ticket **does** change the placement of furniture on editor-placed FARPs in missions that
already work. That is precisely what `FIX-FARP-ESCORT-PLACEMENT`'s PRD warns about — *"a fix that quietly
moved every FARP in every existing mission would have been a worse outcome than the defect"*. So the
non-regression below is not a formality: a FARP whose escort already stands on clear ground must not move
by a metre.

## Definition of done

- [x] Buildings are rejected, by adding one category to the **existing** probe rather than a second copy
      of the rule
- [x] Forests are handled by a cloud tier above the walk, since no API can test a chosen point for them
- [x] `Disposition` stays guarded and `pcall`-wrapped; absent, raising or nonsensical it degrades to the
      bearing walk — three tests, one per failure mode
- [x] `veaf.doNotAvoidScenery` silences the new tier too
- [x] The added call cost is **measured** and recorded above: one `Disposition` call per group, and the
      probe budget is 3 in the nominal case and 75 when nothing is clear — so the per-position test was
      never needed at bearing level
- [x] The probe budget is pinned by a test, so a later change cannot quietly multiply it
- [x] Lua tests: an escort in open ground does not move, a cloud point sets bearing **and** scale, the
      nearest candidate wins, an out-of-band or too-near candidate is ignored, an occupied candidate is
      skipped for the next, and the singleton is asked exactly once
- [x] The 2026-08-24 non-regression still holds — `test_clear_ground_keeps_the_original_bearing` and
      `test_the_probe_budget_stays_bounded` both assert that a FARP with clear ground does not move
- [x] `stylua --check` clean (formatting applied); `luacheck` is not installed on this workstation and
      runs in the CI Lua gate

## Still owed, and it is ticket 04's gate

**How often the search now exhausts on real terrain.** Buildings and forests both counting makes the
search strictly harder to satisfy, and that frequency is what ticket 04 needs to choose its refusal
threshold. It cannot come from mocks. Either the smoke harness answers it or it goes to
[`DCS-SESSION-TODO.md`](../../../DCS-SESSION-TODO.md) — **ticket 04 must not pick a threshold before
that number exists.**
