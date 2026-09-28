# CHORE-ONE-TERRAIN-CHECK — six places ask DCS the same question about the ground

Status: ✅ done — 2026-09-01. One predicate in `veaf.lua`, three named surface lists, and · archived 2026-09-28
`land.getSurfaceType` now appears exactly once in `src/scripts/veaf/`. Every answer verified unchanged
by sweeps written first; see *What implementation found that this document did not say*.

Origin: David, 2026-08-28, on the `DROP-MIST` ticket 07 port of `mist.isTerrainValid` — *"on a déjà des
trucs pour ça dans notre code, non ?"*. Yes: five of them, and the port made a sixth.

## The six

| Where | What it decides | How |
|---|---|---|
| [`veafUnits.checkPositionForUnit`](../../src/scripts/veaf/veafUnits.lua) | **the real business rule**: a naval unit wants water, a ground unit wants anything else, an aircraft wants more than 10 m | reasons about a **unit** (`unit.naval`, `unit.air`, `NavalStatics`) |
| `acceptableGroundPoint` ([`veaf.lua:1192`](../../src/scripts/veaf/veaf.lua)) | not water | `~= WATER`, for `findSpawnPoint`'s draw |
| [`veaf.resolveCsarSurvivorPoint`](../../src/scripts/veaf/veaf.lua) | not water | `~= WATER`, for an ejected pilot |
| [`veaf.findPointInZone`](../../src/scripts/veaf/veaf.lua) | ship → water, otherwise `LAND`/`ROAD`/`RUNWAY` | **the same rule MiST had**, written out inline |
| [`veafSanctuary`](../../src/scripts/veaf/veafSanctuary.lua) | water or not, to pick a ship or a SAM | `surfaceType == 2 or surfaceType == 3` — **raw numbers** |
| `veafDcsSpawner.isTerrainValid` | any list of surfaces | ported from MiST for the teleport, 2026-08-28 |

None of them calls another. `veafGrass` mentions surfaces twice but only in comments, so it is not a
seventh.

## Two things found while listing them

**1. `veaf.findPointInZone` already had MiST's rule**, independently: ship → `WATER`, otherwise
`LAND` / `ROAD` / `RUNWAY`. So "a runway is valid ground for a vehicle" was VEAF's own conclusion as
well as MiST's — which makes it a rule worth stating once, in one place, rather than a MiST quirk we
inherited.

**2. `veafSanctuary` compares raw numbers.** `surfaceType == 2 or surfaceType == 3` means shallow water
or water *today*. It is right for the wrong reason: nothing pins those values, the comment beside them
says "this is water" rather than naming the constants, and a renumbering upstream would flip a ship
spawn into a SAM spawn with no error anywhere. This is the one entry that is a latent defect rather
than a duplication.

## Why they diverged

Five of the six answer **"not water"**, with shallow water counted as dry — a deliberate CSAR decision
(*"a survivor wading a few metres off a beach is rescuable"*). MiST's answers **"is it one of these
surfaces"**, which is the only form that can express the opposite — a ship that *requires* water — and
the `RUNWAY` case.

`checkPositionForUnit` is the only one covering both directions, but it reasons about a unit rather
than a surface list, so the teleport cannot call it as it stands.

## The move

One predicate, `veaf.isTerrainValid(point, surfaces)` — the shape the port already has, because it is
the only one general enough to express all six. Then:

- `checkPositionForUnit` keeps its **unit** signature and its business rule, and calls the predicate
  instead of reading `land.getSurfaceType` itself;
- the three "not water" sites call it with the shallow-water-is-dry list, so that decision is written
  once instead of being re-derived at each site;
- `findPointInZone`'s inline rule becomes `veafDcsSpawner.terrainForCategory`, which already holds it;
- `veafSanctuary`'s raw numbers become named constants — that part is worth doing whatever else happens.

## What this must not do

Change where anything spawns. Five call sites decide placement, and the CSAR one decides whether a
downed pilot is reachable. A unification that shifts one surface decision by one case is
indistinguishable from a bug, and `FIX-CSAR-SPAWNS-ON-WATER` exists because that exact area was already
wrong once. Each site keeps its current answer, asserted by a test **before** the call is rerouted.

## Sequencing

**After `DROP-MIST` ticket 07 and 08.** The port must stay iso-behaviour; folding a six-way
deduplication into it would make a regression indistinguishable from a porting mistake. That is the
same reason `FIX-AIRWAVES-COMMAND-EASTING` was left out of the geometry port.

## Scope

| # | Ticket | Risk | Status |
|---|---|---|---|
| 01 | Pin today's answer at all six sites, before anything is rerouted | none — tests only, green against the unchanged code | ✅ |
| 02 | One predicate, in `veaf.lua`, and five sites routed through it | medium — five of the six decide placement; guarded by ticket 01 | ✅ |
| 03 | `veafSanctuary` stops comparing raw surface numbers | low — same verdict, proven by a renumbering test | ✅ |

## Definition of done

- [x] One predicate, and no module reads `land.getSurfaceType` directly except it
- [x] `checkPositionForUnit` keeps its signature and its rule; its callers are untouched
- [x] `veafSanctuary` names its constants
- [x] A test per site asserting today's answer, written **before** the rerouting
- [x] `stylua --check` clean; `luacheck` left to CI (no Windows binary on this machine)

## What implementation found that this document did not say

Written down rather than folded in silently: this PRD is dated 2026-08-28 and `DROP-MIST` closed on
2026-08-31 in between.

**1. `veaf.isTerrainValid` already existed — in the wrong place.** `veafDcsSpawner.lua` ended with
`veaf.isTerrainValid = veafDcsSpawner.isTerrainValid`, a façade assignment made *after* `veaf.lua` has
loaded. Three of the six sites live in `veaf.lua`, and `test_veaf.lua` loads nothing else, so the name
was unreachable from exactly the sites that needed it. The body moved into `veaf.lua`; `veafDcsSpawner`
now borrows the name instead of owning it, and the façade line is gone.

**2. `findPointInZone` cannot call `terrainForCategory`, and doing so would have moved a spawn.**
`veafDcsSpawner.terrainForCategory("ship")` answers `{ SHALLOW_WATER, WATER }`; `findPointInZone`
accepts `WATER` alone for a ship. The move described above would therefore have let a ship draw a
shallow-water point that is refused today — the precise thing *What this must not do* forbids. Only its
ground half is genuinely the shared list (`veaf.DRIVABLE_TERRAIN`); its ship half keeps `veaf.OPEN_WATER`.

**3. "Five of the six answer *not water*, with shallow water counted as dry" is wrong about
`veafSanctuary`.** It counts shallow water as **water** (`== 2 or == 3`), the opposite of the CSAR
decision, and it is right to: a sanctuary over the shallows wants ships. There are two pure "not water"
sites, not three — `acceptableGroundPoint` and `resolveCsarSurvivorPoint` — plus the ground branch of
`checkPositionForUnit`, which is inside the site this document says keeps its own rule. Hence three
named lists rather than one.

**4. `veaf.findPointInZone` had no test whatsoever** before ticket 01. It is called from four modules.

**5. Found in passing, deliberately not fixed: `checkPositionForUnit`'s aircraft rule reads the
easting.** Two lines above, `spawnPosition.z` is used as the easting to query the surface; the height
test then reads the same field as an altitude (`spawnPosition.z <= 10`). Every caller hands in a
`veaf.placePointOnLand` result, whose height is in `y` — `veafSpawnAircraft` even writes
`spawnSpot.y = alt` just before calling. So *"an aircraft wants more than 10 m"* actually tests whether
the spawn point is more than 10 m east of the theatre's origin, and no error is raised either way
(`docs/agents/dcs-coordinates.md`). This lot is forbidden from moving any of these answers, so the
behaviour is pinned by a test that says what it does, and the defect is left for its own ticket.

---

## Tickets, in full

## 01 — Pin today's answer at all six sites, before anything is rerouted

Status: ✅ done — 2026-09-01. 24 assertions across four suites, all green against the **unchanged**
code, then still green after the rerouting.
Type: test

The lot's own prohibition — *"a unification that shifts one surface decision by one case is
indistinguishable from a bug"* — is only enforceable if the current answers are written down first.
So this ticket comes before any code change, and its tests are expected to pass **immediately**.

### What each site is asked

Enumerated from `land.SurfaceType` rather than sampled, one row per surface DCS can report. The
repository has already paid for the sampled version: thirteen hand-picked cases once supported the
claim that a whole family of crashes was fixed while three remained.

| Site | Suite | What the sweep pins |
|---|---|---|
| `veafUnits.checkPositionForUnit` | `test_veafUnits.lua` | ground / naval / offshore-static / non-naval-static / aircraft, each against all five surfaces |
| `acceptableGroundPoint` (via `veaf.findSpawnPoint`) | `test_veaf.lua` | four surfaces are acceptable ground, `WATER` alone is not |
| `veaf.resolveCsarSurvivorPoint` | `test_veaf.lua` | only `WATER` sends the survivor search out |
| `veaf.findPointInZone` | `test_veaf.lua` | **had no test at all**: ship → `WATER`, otherwise `LAND`/`ROAD`/`RUNWAY`, plus the widening and the 1000-draw bound |
| `veafSanctuary:deployDefenses` | `test_veafSanctuary.lua` | water → ships, land/road/runway → SAMs, on both waves |
| `veafDcsSpawner.isTerrainValid` | `test_veafDcsSpawner.lua` | the full 5×5 truth table |

### The one case that separates the two directions

`SHALLOW_WATER`. It is **dry** for a ground unit, for the spawn search and for a downed pilot
(FIX-CSAR-SPAWNS-ON-WATER: *"a survivor wading a few metres off a beach is rescuable"*), and it is
**not water enough** for a naval unit or for a ship in `findPointInZone`. The two directions are not
each other's mirror image, so a single "wet" list would have flipped one of them silently. That is
exactly what the sweeps refuse.

### Proof the tests can fail

Sabotaging the shared predicate afterwards, one change at a time:

| Sabotage | Suites that went red |
|---|---|
| `== actual` → `~= actual` in the match loop | all six sites, 39 tests |
| `point.z or point.y` → `point.y or point.z` (the coordinate trap) | the two sites that assert which spot is asked about |
| `veaf.OPEN_WATER` gains `SHALLOW_WATER` | the four sites that treat shallow water as dry |
| `veaf.DRIVABLE_TERRAIN` loses `RUNWAY` | `findPointInZone` and `terrainForCategory` |

---

## 02 — One predicate, in `veaf.lua`, and five sites routed through it

Status: ✅ done — 2026-09-01. `land.getSurfaceType` now appears once in `src/scripts/veaf/`.
Type: refactor

### Where it had to live, and why not where the PRD said

The PRD names the predicate `veaf.isTerrainValid`, and that name **already existed** — as a façade
assignment at the bottom of `veafDcsSpawner.lua`, pointing at the ported body. Unusable from three of
the six sites: `acceptableGroundPoint`, `findPointInZone` and `resolveCsarSurvivorPoint` all live in
`veaf.lua`, which loads first, and `test_veaf.lua` loads nothing else.

So the body moved into `veaf.lua`, unchanged, and `veafDcsSpawner.isTerrainValid` became the borrowed
name rather than the owner. The façade line was removed, since the function is no longer somebody
else's to lend.

### The three named lists

Written once, beside the predicate, each with the reason it has the shape it has:

| Constant | Surfaces | Used by |
|---|---|---|
| `veaf.OPEN_WATER` | `WATER` | `acceptableGroundPoint`, `resolveCsarSurvivorPoint`, `checkPositionForUnit`, `findPointInZone` (ship) |
| `veaf.WATER_TERRAIN` | `SHALLOW_WATER`, `WATER` | `veafSanctuary`, `veafDcsSpawner.TERRAIN_BY_CATEGORY.ship` |
| `veaf.DRIVABLE_TERRAIN` | `LAND`, `ROAD`, `RUNWAY` | `findPointInZone` (ground), `TERRAIN_BY_CATEGORY.vehicle` and `.ground_unit` |

`OPEN_WATER` is asked **negatively** at the three "not water" sites — `not veaf.isTerrainValid(p,
veaf.OPEN_WATER)` — rather than as a positive list of the four dry surfaces. Not a stylistic choice:
`~= WATER` accepts a surface value the enumeration does not know, and a positive list rejects it. The
two forms differ only for a value DCS does not document today, which is precisely the kind of
one-case shift the PRD forbids.

### `checkPositionForUnit` keeps everything it had

Its signature, its unit-based rule and its callers are untouched. It stops reading the surface itself
and asks the predicate once, keeping the single query it always made and its trace line.

### `findPointInZone` does **not** call `terrainForCategory`

The PRD's plan for this site would have changed a spawn. `veafDcsSpawner.terrainForCategory("ship")`
answers `{ SHALLOW_WATER, WATER }`, while `findPointInZone` accepts `WATER` alone for a ship — so
routing it through that helper would have let a ship draw a shallow-water point that is refused today.
Its ground half genuinely is the shared list and now uses it; its ship half keeps `veaf.OPEN_WATER`.

---

## 03 — `veafSanctuary` stops comparing raw surface numbers

Status: ✅ done — 2026-09-01. Proven by a test that fails while the numbers are literal.
Type: fix

The one entry of the six that was a latent defect rather than a duplication.

### What it was

```lua
local surfaceType = land.getSurfaceType(veaf.makeVec2(position))
if surfaceType == 2 or surfaceType == 3 then
  -- this is water
```

Twice, once per defence wave. Right today — 2 and 3 are what `land.SurfaceType` gives
`SHALLOW_WATER` and `WATER` — and right for a reason nothing in the repository holds. `land.SurfaceType`
is DCS's table. Renumber it upstream and a sanctuary answers a speedboat with a Patriot: the branch
still runs, the aliases still resolve, the groups still spawn, and nothing raises.

The comment beside it said *"this is water"* instead of naming the constants, which is the tell.

### What it is now

One `isOverWater`, computed from `veaf.isTerrainValid(veaf.makeVec2(position), veaf.WATER_TERRAIN)` and
reused by both waves. The trace line reports the verdict rather than the number.

Note that `veaf.WATER_TERRAIN` includes `SHALLOW_WATER`, so this site does **not** share the
shallow-water-is-dry decision of the CSAR and ground-spawn sites — contrary to the PRD's reading that
five of the six answer "not water". Its verdict is unchanged: shallow water gets ships, as it did.

### The test that could not pass before

`TestSanctuaryDeployDefensesSurface.test_the_choice_survives_a_renumbering_of_land_SurfaceType`
replaces `land.SurfaceType` with `{ LAND = 11, SHALLOW_WATER = 12, WATER = 13, ROAD = 14, RUNWAY = 15 }`
and asks the same three questions. It was written before the fix and observed red — a renumbered
`WATER` produced `{ "-roland", "-roland" }`, the Patriot at sea, exactly the failure described above.

The two sibling tests (`WATER`/`SHALLOW_WATER` → ships, `LAND`/`ROAD`/`RUNWAY` → SAMs, on both waves)
were green before and after: naming the constants changed the code's exposure, not its answer.

---
