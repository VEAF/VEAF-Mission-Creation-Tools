# 03 — The FARP escort avoids the scenery too

Status: ⬜ ready
Type: fix

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

### The cost, which is why this needs measuring and not just adding

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

- [ ] `allClear` rejects a bearing whose positions are unacceptable ground, reusing the existing rule
      rather than a second copy of it
- [ ] `Disposition` remains guarded and `pcall`-wrapped; its absence degrades to the current behaviour
- [ ] The added call cost is **measured** on a FARP, and the result recorded here; if it is significant,
      the test is moved to the bearing level with the reason stated
- [ ] Lua tests: an escort in open ground does not move, an escort whose requested bearing is in scenery
      moves to a clear one, and a missing `Disposition` falls back to today's behaviour
- [ ] The 2026-08-24 non-regression still holds — a FARP far from anything places everything on the
      requested bearing at the requested distance
- [ ] `stylua --check` and `luacheck` clean
