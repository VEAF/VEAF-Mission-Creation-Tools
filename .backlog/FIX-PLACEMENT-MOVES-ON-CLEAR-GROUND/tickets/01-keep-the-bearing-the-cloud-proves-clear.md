# 01 — Keep the requested bearing when the cloud proves it clear

Status: ✅ done
Type: fix

## What exists

[`veafGrass.lua`](../../../src/scripts/veaf/veafGrass.lua), tier 1 of `findClearBearing`, asks
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

## What was ruled out

Testing `allClear(baseAngle, 1)` before consulting the cloud. `allClear` runs the occupancy probe, which
sees units, statics, aprons and buildings but **not forests** — trees are not scenery objects, and
`land.getSurfaceType` answers LAND for a wood exactly as for a meadow. Forests are knowable only through
`Disposition`, which cannot be asked *"is this spot clear?"*; it only proposes points. That asymmetry is
the entire reason tier 1 exists, so probing first would put escorts back in the trees.

## What changed

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

## Tests — proven to fail on both sides

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

## Definition of done

- [x] A requested spot clear of everything keeps its bearing **and** its distance
- [x] A requested spot that is not clear still moves, and still avoids forests
- [x] Both sides covered by tests, each proven to fail when the code is broken
- [x] Lua coverage ratchet honoured (79.52 % measured, CI floor 77 → 78)
- [x] `stylua --check src/scripts/veaf/ test/lua/` clean; `luacheck` not installed on this
      workstation, left to the CI Lua gate
