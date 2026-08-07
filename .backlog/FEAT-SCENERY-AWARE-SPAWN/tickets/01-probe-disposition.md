# 01 — Probe `Disposition` in a running DCS

Status: ✅ done — **fully answered 2026-08-06 by the smoke harness plus one F10 marker**, avoidance included; it also found a correctness bug in the code that shipped on the assumption
Type: chore
Files: throwaway probe script, then `docs/exploration/TUM-EXPLOIT.md`

## Answered 2026-08-06 — first by the harness, then by a marker on the map

The first thing `FEAT-DCS-SMOKE-HARNESS` measured, in a live mission on David's workstation, was this
singleton. **It exists.**

| Question | Answer |
|---|---|
| Is `Disposition` there? | yes, a `table` |
| Is `getSimpleZones` there? | yes, a `function` |
| Does `getSimpleZones({x=0,y=0,z=0}, 1852, 100, 10)` raise? | no |
| What does it return? | a table of **10** entries — matching the `10` passed fourth, so the assumed signature holds |

So the singleton is real, reachable from the mission scripting state, and the tier-1 code shipped in
tickets 02–05 is not dead weight. That much is now **measured**, and it was measured by a machine, which
is the Definition of Done `FEAT-DCS-SMOKE-HARNESS` set itself.

That much was the *existence*, and it deliberately was not read as more: calling the function at the map
origin proves it answers, not that it answers well, and "returns 10 points" is exactly what a naive
random-point generator would also do. The claim ADR 0018 actually rests on — that the points **avoid
buildings and forests** — needed a separate measurement, which is the next section.

## Fully answered 2026-08-06 — including the avoidance, and it found a shipped bug

David's idea closed the last gap: he dropped an F10 marker, the harness asked `Disposition` for points
around it and **marked every one on the map**. `land.getSurfaceType` cannot help here — a forest is
`LAND` exactly like a meadow, trees have no surface type — so the F10 map was the only available oracle,
and a visual check by a person is what the automated assertion could never be.

**The avoidance is real.** Marker placed inside a wooded strip, 40 points requested within 400 m: the
entire scatter came back in the open ground beside the trees, none among them, with one point sitting in
a clearing *between* two copses — so it finds gaps rather than merely fleeing the area.

**The degradation is clean too.** Marker moved into a large dense forest, same parameters: **0 points**.
It refuses rather than proposing something unusable, which is precisely what tier 2 exists to catch.

### The signature, measured

`getSimpleZones(centre, radius, spacing, count)` → array of **`{x, y, course}`**, a **vec2 plus a
heading**, not a vec3. The ticket predicted this exact risk ("returns vec2 rather than vec3"), and the
shipped code survives it: `veaf.placePointOnLand` moves `y` into `z` when there is no `z`.

- `count` is honoured exactly: 3 → 3, 10 → 10, 25 → 25.
- `spacing` drives the layout: 10 → points 8-21 m out, 50 → 37-146 m, 100 → 89-284 m.
- `spacing` greater than `radius` → 0 points.
- Returned points are on land (`surfaceType 1`) in every sample taken.

### `radius` is **not** a bound, and that is a correctness bug in what shipped

The first reading of this was wrong and is corrected here: a test at the map origin (`radius 300` →
12 points, max 271 m) looked like a hard bound, but it was the function running out of candidates. In
dense terrain it goes far outside the circle asked for. Centre `david` at `x=-155620 z=866560`:

| asked | got | actual distance |
|---|---|---|
| r=200 | 0 | — |
| r=400 | 0 | — |
| r=800 | 29 | **2035 – 2258 m** |
| r=1600 | 22 | 2560 – 2696 m |
| r=3200 | 40 | 2369 – 3416 m |
| r=1600, **count=1** | 1 | **2628 m** |

The last row kills the obvious explanation: asking for a single point does not keep it near, so the
overshoot is not the count forcing a wider search. The radius argument simply does not cap the distance.

**Consequence for `veaf.findSpawnPoint`, shipped 2026-08-05**: tier 1 takes the **first** candidate that
passes `acceptableGroundPoint` and applies **no distance test at all**, while passing
`math.max(1852, safeRadius * 5)` as the radius and ignoring the caller's own `radius` entirely (tier 2
uses it; tier 1 does not). So `_spawn group, radius 50` in wooded terrain can place the group **kilometres
away**, silently. That breaks the property [ADR 0018](../../../docs/adr/0018-undocumented-dcs-api-dependency.md)
requires of this dependency — *quality-only, never correctness*: as written, tier 1 can move a group
somewhere the mission maker did not ask for, which is a correctness regression, not a quality gain.

**Fixed 2026-08-06, in the same lot that found it** (David's call: it is in unreleased code, so it should never ship). Tier 1 now rejects a candidate farther than the caller's `radius` and falls through to tier 2, the documented degradation; it asks `getSimpleZones` for the caller's radius instead of an invented `math.max(1852, safeRadius * 5)`; and a `radius` of 0 — what `veafSpawn` passes for farp, cargo, teleport, bomb, smoke and friends — skips tier 1 entirely, because "exactly here, the mission maker means it" is not a point to move. Distance is measured **horizontally**: `placePointOnLand` writes the terrain height into `y`, so a 3D measure would let a hill push a good candidate out of range. 10 new Lua tests, and one existing test had to change — `test_scenery_aware_point_becomes_the_group_centre` asserted that a candidate **4200 m** away became the centre of a group asked for within 1000 m, so the suite had been pinning the bug.

### Still open

Per-call cost, cross-theatre presence including WWII, and the empty case as a *deliberate* assertion
rather than an incidental observation. None of them gate anything now.

## Deferred — no longer a gate (David, 2026-08-05) — *historical, settled the next day*

> Kept as the record of the call that was made, and it turned out well: deferring cost nothing, because
> the assumption held on every point that mattered. What it did hide for a day is the distance overshoot
> above, which no amount of reading could have found.

**"On sondera plus tard, fais comme si c'était bon et code."** Tickets 02–05 proceed on the
assumption that `Disposition.getSimpleZones` behaves as TUM's call site implies. This ticket stays
open as the outstanding verification, and it needs a human at a DCS install.

The assumption is load-bearing in exactly one direction, which is why coding ahead is safe: if the
singleton is missing, malformed, or no better than `getSurfaceType`, the helper falls through to
tier 2 and ground spawns behave as they do today. What is *not* covered until this ticket runs is the
**per-call cost** and the claim that the returned points genuinely avoid buildings and forests — so
until then, ADR 0018 records the scenery avoidance as **asserted, not measured**.

## Why it was originally first

Everything below depends on a singleton we have **never called**. The whole evidence base is one
unguarded call site in TUM (`TheUniversalMission.lua:3060`) and a Reddit claim by its author. It is
absent from `dcs-world-schema`, so there is no reference to check the signature against. Building
the wrapper first and discovering in flight that the fourth argument is not a count, or that it
returns vec2 rather than vec3, is a wasted ticket.

This is the same shape as ticket 01 of `FEAT-ASSIST-CHECKLISTS`, which proved the cockpit-highlight
functions were reachable before the engine was written on top of them.

## What to measure

Run a probe inside a real DCS mission — the `veaf-tools inject-bridge` / `capture-map` path already
does exactly this kind of runtime interrogation and is the tool to reuse.

- [ ] **Existence.** Is `Disposition` a table in the mission scripting environment? Dump
      `type(Disposition)` and its keys — the author mentions "a few" other undocumented functions,
      so record the whole surface, not just `getSimpleZones`.
- [ ] **Signature.** Confirm `getSimpleZones(centerVec3, searchRadius, exclusionRadius, count)`:
      does it want a vec3 or a vec2? Does it return vec3 or vec2? What does `count` do when more
      points exist than asked for, and when fewer do?
- [ ] **Behaviour, the actual point of the exercise.** Call it centred on a **village** and on a
      **forest** with a known-clear area nearby, and confirm the returned points are genuinely
      clear of both. A function that only avoids water would be worthless here — that is what we
      already have.
- [ ] **Empty case.** Centre it on dense city with a small radius: does it return an empty table, a
      nil, or throw? The wrapper's fallback branch depends on this answer.
- [ ] **Cross-theatre.** At minimum one modern map and one WWII map (Normandy), since scenery data
      differs. Note any theatre where the singleton is missing.
- [ ] **Cost.** Rough timing for one call. Ground spawns can place a dozen groups at once; if a
      call costs tens of milliseconds the wrapper needs to be called once per *group*, not per unit.

## Outcome

Write the measurements into `docs/exploration/TUM-EXPLOIT.md`, replacing the inferred description
with an observed one — including anything that turns out **false**, as the hook-boundaries note did
for two of dcs-sms's claims. Update ADR 0018 to say measured instead of asserted.

Then, since the code already shipped:

- **Positive** → confirm the constants (`SPAWN_SEARCH_ATTEMPTS`, the 1852 m floor) against the
  measured cost, and tune if a call turns out expensive.
- **Negative or unreliable** (missing on common theatres, or avoidance no better than
  `getSurfaceType`) → tier 1 is dead weight, not a bug: delete the tier and the mock, keep tier 2
  (which is an improvement on its own — it validates where nothing validated before), and record the
  dead end in ADR 0018 so nobody re-explores it.

## Notes

No VEAF source changes in this ticket, so no version bump and no CHANGELOG entry.
