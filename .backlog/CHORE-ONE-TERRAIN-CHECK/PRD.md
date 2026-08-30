# CHORE-ONE-TERRAIN-CHECK — six places ask DCS the same question about the ground

Status: ⬜ ready

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

## Definition of done

- [ ] One predicate, and no module reads `land.getSurfaceType` directly except it
- [ ] `checkPositionForUnit` keeps its signature and its rule; its callers are untouched
- [ ] `veafSanctuary` names its constants
- [ ] A test per site asserting today's answer, written **before** the rerouting
- [ ] `stylua --check` and `luacheck` clean
