---
status: accepted
---

# VMCT may depend on an undocumented DCS API, but only to improve quality, never for correctness

The documented DCS scripting API offers exactly one signal about what is on the ground:
`land.getSurfaceType`, which distinguishes water from land and nothing else. It cannot tell a wheat
field from a village. So every VEAF ground spawn has placed units with no knowledge of buildings or
forests — a platoon dropped on a marker over a hamlet ends up inside the houses.

[TUM](../exploration/TUM-EXPLOIT.md) found a way out: **`Disposition`**, a native DCS scripting
singleton that is **not in any published API reference**. Its `getSimpleZones(centre, searchRadius,
exclusionRadius, count)` returns ground points clear of buildings and forests. Adopting it raises a
question bigger than this one function, because TUM's author says there are others: **when may VMCT
build on a DCS API that ED has not documented?**

## Decision

Depend on it, under three conditions:

1. **Guarded and `pcall`-wrapped at every call site.** `if Disposition and Disposition.getSimpleZones
   then`, and the call itself inside `pcall`. A singleton that is absent on this DCS version or this
   map, or whose signature changed under us in a patch, must degrade — never raise inside a mission.
2. **Quality only, never correctness.** No feature may become unavailable, and no mission may fail to
   build or run, because an undocumented API is missing. Here, `veaf.findSpawnPoint` uses it for its
   first tier only; the second tier reaches an acceptable point without it, and that tier is what
   ships to any install that lacks the singleton.
3. **The fallback is the tested default.** `Disposition` is deliberately **absent** from
   `test/lua/dcs_mocks.lua`, so all 35 Lua suites exercise the path that does not need it, and CI
   keeps telling us the degradation still works. Tests that want the singleton set it locally and
   restore it, the way `TestVeafCtldIntegration` does with `ctld`.

## Status of the evidence — measured in game, 2026-08-15

The decision was originally taken on TUM's author's observation. It has since been **measured** by the
smoke harness (`FEAT-DCS-SMOKE-HARNESS`), on Syria, and the assumption holds.

Context that still stands: TUM calls `Disposition.getSimpleZones` at `TheUniversalMission.lua:3060`,
**bare** — no `require`, no guard, not even a `pcall` — which is only reasonable if the author found it
reliably present; the author states on r/hoggit that it is an undocumented DCS API, likely what ED's
own quick-action generator uses.

What the harness measured (Syria, in game):

- **It exists and is callable.** `getSimpleZones(centre_vec3, radius_m, arg3, count)` returns an array
  of `{ x, y, course }` — a 2D point (mission-table convention, `x` northing / `y` easting) plus a
  heading, **not** a vec3.
- **The returned points genuinely avoid scenery.** Centred on the airbase Abu al-Duhur — an area
  carrying **369 scenery objects within 2 km** — all **30** returned points had **zero** scenery within
  10 m and were all on a `land` surface (`getSurfaceType == LAND`). The avoidance is real, not asserted.
- **It returns fewer than requested when clear space is scarce**, which is exactly why tier 1's fallback
  is necessary rather than paranoia: at the airbase, radius 150 m → 2 points, 500 m → 10, 2000 m (req 50)
  → 50; the open desert anchor (2000 m, req 30) → 30. A caller must handle a short count.
- **Cost**: ~43 ms per call.

Not measured: `arg3` (passed 100, meaning unconfirmed) and presence on a WWII map — the current maps
tested are modern. `.backlog/FEAT-SCENERY-AWARE-SPAWN/tickets/01-probe-disposition.md` carries the full
question list; the load-bearing one — does it avoid scenery — is answered.

Coding ahead of the measurement is safe precisely because of condition 2: the assumption is
load-bearing in one direction only. If the probe comes back negative, tier 1 is dead weight to delete,
not a bug to debug — and tier 2 remains an improvement in its own right, since it validates a candidate
point where nothing validated one before.

## Consequences

- A DCS patch can remove `Disposition` silently, and we will not notice from CI — by design, since CI
  tests the absent case. The symptom would be a return to today's placement quality, not a failure.
- The bar is now set for the next undocumented find. TUM's author mentions others; each one gets the
  same three conditions, or it does not go in.
- `.luacheckrc` declares `Disposition` as a global with a comment marking it unverified, distinct from
  the `a_cockpit_*` entries above it which cite the ticket that proved them in game.

## Alternative rejected — hand-rolled scenery avoidance

Compute the clearance ourselves from map objects. Rejected because it is not possible: the mission
scripting environment exposes **no queryable building or forest layer**. `world.searchObjects` finds
units and statics placed by a mission, not terrain scenery. That absence is precisely what makes an
undocumented engine function valuable enough to justify this ADR — if the documented API could answer
the question, there would be no decision to record.
