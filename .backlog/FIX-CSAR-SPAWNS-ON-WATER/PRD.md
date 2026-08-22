# FIX-CSAR-SPAWNS-ON-WATER — the downed pilot is placed 50 m away and nobody checks what is there

Status: ✅ done — shipped in 6.15.28

Follow-up to [`FEAT-SMOKE-CSAR-WATER`](../FEAT-SMOKE-CSAR-WATER/PRD.md), which shipped the assertions
that measure this. Addresses [#245](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/245).

## The defect, read in the code

`csar.spawnGroup` (`src/scripts/community/CSAR.lua:1041`):

```lua
_group.units[1] = csar.createUnit(_pos.x + 50, _pos.z + 50, 120, "Soldier M4")
```

A **fixed +50/+50 offset with no surface test**. A pilot ejecting over water, or 50 m from a shoreline,
is placed wherever that arithmetic lands. `veaf.findSpawnPoint` — which knows about water and scenery
since `FEAT-SCENERY-AWARE-SPAWN` — is never consulted. Same shape as `FIX-FARP-ESCORT-PLACEMENT`.

## Do not edit the vendored file

`CSAR.lua` is vendored `adapted` from `VEAF/DCS-CSAR` (`vendored.yaml`), and its documented update
procedure is *"pull the latest ciribob CSAR.lua, re-apply the VEAF adaptations"*. An edit made here is an
adaptation nobody recorded, and **the next update erases it**.

The clean path: `veaf.csar_initialize_replacement` (`veaf.lua:5467`) already replaces `csar` functions
from VEAF code — `csar.logError`, `csar.logInfo`, `csar.logDebug`, `csar.logTrace`. Replacing
`csar.spawnGroup` there survives a vendored update and touches no third-party file.

## Which pilot, precisely

The **survivor to be rescued**, not the rescue helicopter's crew. The trigger is `S_EVENT_EJECTION`
(`CSAR.lua:517`), player or AI; `csar.addCsar` receives `_unit:getPoint()` — the position of the
*aircraft* at the moment of ejection — and `csar.spawnGroup` then places a "Downed Pilot #N" group at
`+50/+50` from it. So the survivor appears fifty metres north-east of where his aircraft was, and nothing
looks at what is there.

## David's arbitration, 2026-08-22

> **Within 500 m of a beach, teleport him there. Otherwise he counts as dead.**

So there is no raft and no walk inland. Two outcomes, and nothing in between:

| Where the ejection happened | What the mission gets |
|---|---|
| dry ground, or water with dry ground within 500 m | a CSAR at the nearest dry point |
| open water, nothing dry within 500 m | **no CSAR at all** — the pilot is lost |

The second row is the part that needs care: it is not "a CSAR that cannot be reached", it is **no CSAR
object created**. No MAYDAY, no ADF beacon, no wounded group sitting on the seabed for the rest of the
mission.

## Where to intercept, and why not `spawnGroup`

`csar.addCsar` dereferences the spawned group immediately — `addSpecialParametersToGroup(_spawnedGroup)`,
then `_spawnedGroup:getCoalition()` — so returning `nil` from `spawnGroup` **crashes**. (The `if
_spawnedGroup ~= nil` at the end of `addCsar` is the same author having thought about nil *after*
dereferencing it six times.)

So the replacement goes on **`csar.addCsar`**: decide first, then either call the original with a
corrected position or return without creating anything.

One wart to document rather than hide: `spawnGroup` adds its own `+50/+50` after us, so the point handed
to the original has to be **pre-compensated** for that offset. Ugly, and the price of not editing a
vendored file whose next update would erase the edit.

## What shipped

Two functions in `veaf.lua`, and **not a line of `CSAR.lua`**:

- `veaf.resolveCsarSurvivorPoint(point)` — the decision. A dry point comes back unchanged, which matters:
  `veaf.findSpawnPoint` jitters, so searching around every ejection would shift each land rescue by tens
  of metres for nothing. Water triggers a bounded search, and `nil` means lost.
- `veaf.replaceCsarAddCsar()` — the seam, called from `veaf.csar_initialize_replacement` next to the
  seven other things it already replaces in the `csar` table.

`addCsar` rather than `spawnGroup`, where the placement actually happens: `addCsar` dereferences the
spawned group immediately, so returning `nil` from `spawnGroup` raises. Deciding before anything exists
is the only way to honour "otherwise he counts as dead", which means **no CSAR object**: no MAYDAY, no ADF
beacon, no wounded group on the seabed.

Shallow water counts as dry, consistently with `acceptableGroundPoint`, which rejects `WATER` only. A
survivor wading off a beach is rescuable; calling that open sea would declare him dead next to dry land.

## The wart, and the near-miss it produced

`spawnGroup` adds its own `+50/+50` after us, so the point handed to the original is pre-compensated.
Named as `veaf.CSAR_SPAWN_OFFSET_METRES`, and the tests assert the **round trip** rather than the
constant, so a vendored update changing that offset fails loudly.

That compensation nearly shipped a defect. `veaf.csar_initialize_replacement` sets
`veaf.csar_initialized` but **nothing reads it**, so a mission calling it twice stacks the wrapper —
compensating twice, resolving an already-resolved point, and putting the survivor 50 m the wrong way.

The test meant to catch that **passed on the broken code**: its stub resolver returned a fixed point
regardless of input, so the double compensation cancelled itself out. Rewritten so the stub moves the
point it is given, it fails on a stacked wrapper and passes on the guarded one — verified in both
directions by removing the guard.

## Definition of done

- [x] The over-ocean question settled, with David — 500 m or dead
- [x] `csar.addCsar` replaced from `veaf.csar_initialize_replacement`, not patched in the vendored file
- [x] A pilot over water within 500 m of dry ground is placed on it
- [x] A pilot with nothing dry within 500 m produces **no CSAR at all**, and says so to his coalition —
      unless the caller asked for silence, which stays silent
- [x] Lua tests over the placement decision, with the surface and land queries injected — 19 tests
- [ ] Run the two `csar-avoids-water` checks after: they are the in-game confirmation. Item 20 of
      `DCS-SESSION-TODO.md`, and now they should **pass** where the prediction was that both would fail
- [x] Documented, both languages
