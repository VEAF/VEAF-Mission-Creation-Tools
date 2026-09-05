# 02 — A zone's naval element looks for water, not for dry land

Status: ⬜ ready

Type: fix

## The finding

Not a report — this came out of reading Tripack's log while looking for report 2. Thirteen calls
fail identically on both 6.19.0 loads:

```
VEAF|I|findSpawnPoint|1361: findSpawnPoint: no acceptable spawn point within 50m of  x=-162000.2 y=0.0 z=70144.9
```

They are mechanical, not accidental. [`VeafCombatZone:spawnElement`](../../../src/scripts/veaf/veafCombatZone.lua)
calls `veaf.findSpawnPoint` for **every** element whose `spawnRadius > 0`, and all three of that
function's tiers accept a candidate only through
[`acceptableGroundPoint`](../../../src/scripts/veaf/veaf.lua), which rejects anything on
`veaf.OPEN_WATER`. A ship, a submarine or a cargo hull can never satisfy it, so its element burns
ten draws per tier and falls back on its declared position every single activation.

The framework already holds the right vocabulary and uses it two files away:

| Constant | Contents | Used by |
|---|---|---|
| `veaf.DRIVABLE_TERRAIN` | `LAND`, `ROAD`, `RUNWAY` | `veafDcsSpawner.TERRAIN_BY_CATEGORY.vehicle` |
| `veaf.WATER_TERRAIN` | `SHALLOW_WATER`, `WATER` | `veafDcsSpawner.TERRAIN_BY_CATEGORY.ship` |

So the same spawn decides *where* with a land-only criterion and then validates *whether* with a
per-category one. The two disagree for every naval element, and the disagreement is silent: the
element keeps its declared position and the mission maker sees a ship that simply never moved.

## Why it matters beyond the noise

On its own this is a wasted search and a scattering that never happens for ships. It becomes a
missing group when the terrain check downstream also refuses — which is what ticket 03 measures.
Fixing the criterion here may or may not fix that; the two are kept apart on purpose so the
measurement is not made against a moving target.

## The fix

`findSpawnPoint` takes the surfaces it must accept, defaulting to today's land-only behaviour so no
existing caller changes. `spawnElement` passes the surfaces its element's category calls for, read
from the same table `veafDcsSpawner` already uses — one source for "what can this thing stand on",
not two.

The scenery-clearance tier stays quality-only per ADR 0018: a hull that finds no scenery-free water
still gets a point, it just gets it from tier 2.

## Definition of done

- [ ] `findSpawnPoint` accepts a surface list and defaults to the current land-only criterion
- [ ] A combat zone's naval element searches on water; a ground element is unchanged
- [ ] Unit tests: a ship element finds a point at sea, a vehicle element still refuses the sea, and
      the default-argument path is asserted so an unconverted caller cannot silently change behaviour
- [ ] The thirteen `findSpawnPoint` failures do not reappear on a mission of the same shape
- [ ] `luacheck` + `stylua --check` clean; Lua coverage floor bumped per the ratchet policy
