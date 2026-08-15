# Lot FEAT-SCENERY-AWARE-SPAWN — scenery-aware ground spawning from TUM's native tier

Status: ✅ done — the in-game probe came back 2026-08-06, avoidance included, and **it found a
correctness bug in what had shipped the day before**.

**Goal**: ground units stopped spawning inside villages and forests. Placement knew only water from
land, so a marker over a hamlet put a platoon in the houses. Three bounded tiers around `Disposition`,
an undocumented native DCS singleton taken from TUM
([ADR 0018](../../docs/adr/0018-undocumented-dcs-api-dependency.md)).

| # | Ticket | Status |
|---|--------|--------|
| 01 | Probe `Disposition` in a running DCS — existence, signature, behaviour | ✅ |
| 02 | `veaf.findSpawnPoint` — three-tier search + i18n key + `.luacheckrc` guard | ✅ |
| 03 | Wire it into the five jittering spawn paths; failure aborts with a message | ✅ |
| 04 | Typed trigger-zone property accessors (independent of 01–03) | ✅ |

## The probe, and why a human was the only possible oracle

`FEAT-DCS-SMOKE-HARNESS` asked ticket 01's questions, and David dropped an F10 marker so the harness
could mark every point `Disposition` proposed. **That marker was the only possible oracle**:
`land.getSurfaceType` answers `LAND` for a forest exactly as for a meadow, so no automated assertion
could ever have judged the avoidance.

- **The avoidance is real.** Marker inside a wooded strip: the whole scatter came back in the open
  ground beside the trees, with one point in a clearing *between* two copses — it finds gaps rather
  than fleeing.
- **The refusal is clean.** Marker in a dense forest: **0 points**, so tier 2 takes over as designed.
- **The signature is measured**: `getSimpleZones(centre, radius, spacing, count)` returns `{x, y,
  course}` — a vec2 **plus a heading**. `count` is exact, `spacing` drives the layout, and
  `spacing > radius` gives 0.

## The bug the probe found in day-old code

**The `radius` argument does not bound the answers.** Asked for 1600 m with a count of one, it returned
a point **2628 m away**. Tier 1 applied no distance test and ignored the caller's radius outright, so a
spawn could move kilometres in silence.

That is exactly the correctness regression ADR 0018 forbids — and **the test suite had been pinning
it**: `test_scenery_aware_point_becomes_the_group_centre` asserted that a candidate 4200 m away became
the centre.

Fixed here rather than deferred, because the code had never been released: 6.13.0 was the last release,
so it should never reach anyone.
