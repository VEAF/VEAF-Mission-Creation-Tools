# 02 — `veaf.findSpawnPoint` — three-tier search + `Disposition` mock

Status: ✅ done
Type: feat
Files: `src/scripts/veaf/veaf.lua`, `src/scripts/veaf/veafI18n.lua`, `test/lua/dcs_mocks.lua`, `test/lua/test_veaf.lua`, `.luacheckrc`

## Behaviour — three tiers, decided by David (2026-08-05)

A new helper next to `veaf.placePointOnLand` (`veaf.lua:1115`), which it complements: that one moves
a point **vertically** onto the terrain, this one **searches** for an acceptable one.

```lua
--- Searches for an acceptable ground spawn point near a centre.
-- @param vec3 centre point
-- @param radius search radius in metres — the "somewhere near here" radius callers already pass
-- @param safeRadius required clearance from scenery (default veaf.DEFAULT_SPAWN_CLEARANCE)
-- @return vec3 placed on land, or nil when no acceptable point was found
function veaf.findSpawnPoint(vec3, radius, safeRadius)
```

The search degrades in three steps, each bounded:

1. **All criteria, scenery included.** Ask `Disposition.getSimpleZones` for
   `veaf.SPAWN_SEARCH_ATTEMPTS` candidates in **one call** — the singleton takes a `count`, so N
   candidates cost one call instead of N, which matters because the per-call cost is *unmeasured*
   (ticket 01 deferred). Return the first candidate that also passes the surface check.
2. **Every criterion except scenery.** Up to `veaf.SPAWN_SEARCH_ATTEMPTS` jittered candidates from
   `mist.getRandPointInCircle(vec3, radius)` — the primitive the callers already use, once, without
   validating it. Return the first that passes the surface check.
3. **Failure.** Return `nil`. The caller reports it and aborts the spawn (ticket 03).

Surface check: `land.getSurfaceType` is not `WATER`, the **same criterion** `checkPositionForUnit`
applies to a ground unit (`veafUnits.lua:411`). Deliberately *not* stricter — `SHALLOW_WATER` passes
today and making it fail here would change behaviour beyond what was asked (RULE N°1).

Guarding: `if Disposition and Disposition.getSimpleZones then`, and the call wrapped in `pcall`. An
undocumented API that changes signature between DCS patches must fall through to tier 2, never crash
a mission at spawn time. Search radius `math.max(1852, safeRadius * 5)` as TUM uses — comment the
1852 (one nautical mile floor).

Opt-out: `veaf.doNotAvoidScenery` (default `false`) skips tier 1 entirely, same shape as
`veafRadio.doNotPaginate` from [ADR 0013](../../../docs/adr/0013-radio-menu-pagination.md). Checked
**inside the helper**, so one check covers every call site.

## This is a behaviour change even without `Disposition` — say so

The first draft of this ticket promised the fallback was byte-identical to today. **It is not**, and
the difference is the point: today a caller jitters **once** and uses the result unvalidated, so a
marker near a coast can put the group centre in the sea, and each unit is then dropped one by one
downstream by `validateSpawnPosition` — a spawn that produces nothing and N messages. Tier 2 retries
until it finds land, so that spawn now succeeds. Tier 3 replaces N per-unit messages with one clear
group-level failure.

Existing tests that pin the old single-jitter path may need updating; each such change must be
justified in the PR as *this* improvement, never to accommodate a regression.

## Tasks

- [x] `veaf.findSpawnPoint` with the three tiers, tier 2 as the default path.
- [x] `veaf.SPAWN_SEARCH_ATTEMPTS` and `veaf.DEFAULT_SPAWN_CLEARANCE` constants, tunable in one place.
- [x] `veaf.doNotAvoidScenery` honoured inside the helper.
- [x] `veafI18n.lua`: `spawn.no_position_group` (FR + EN), beside the existing
      `spawn.no_position_unit`.
- [x] `Disposition` is **deliberately not added to `test/lua/dcs_mocks.lua`.** Putting it there would
      make the singleton *present* in all 35 suites, so every existing spawn test would silently start
      exercising tier 1 — the opposite of what we need pinned. Absent is both the realistic default
      and the branch that ships to any DCS lacking it, so it stays absent globally and each test opts
      in locally, saving and restoring the global the way `TestVeafCtldIntegration` does with `ctld`.
      `poetry run audit-dcs-mocks` stays green: it only requires mocks for calls that are in the DCS
      schema, and an undocumented singleton is not.
- [x] `.luacheckrc`: declare `Disposition` as a global, with a comment stating honestly that it is
      undocumented, sourced from TUM, and **not yet verified in game** — unlike the `a_cockpit_*`
      entries above it, which cite the ticket that proved them.

## Acceptance criteria

- [x] `poetry run test-lua`: 11 new tests, no regression (see ticket 03 for the before/after diff and
      the pre-existing Lua 5.4 failures).
- [x] `luacheck` + `stylua --check` clean.
- [x] Every tier and every degradation path has a test (see ticket 03's test list).
