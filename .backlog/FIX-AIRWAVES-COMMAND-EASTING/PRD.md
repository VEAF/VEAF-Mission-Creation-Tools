# FIX-AIRWAVES-COMMAND-EASTING — a command-driven air wave spawns with no easting

Status: ⬜ ready

Found while porting `mist.getRandPointInCircle` in [`DROP-MIST`](../DROP-MIST/PRD.md) ticket 06, on
2026-08-28. Not fixed there: that ticket removes a dependency and must not also move where things
spawn, or a regression would be indistinguishable from the port going wrong.

## The defect

[`veafAirWaves.lua:1012`](../../src/scripts/veaf/veafAirWaves.lua) — the branch that runs when a wave's
element is a **VEAF command** rather than a DCS group:

```lua
local position = { x = zoneCenter.x - lonDelta, y = zoneCenter.y, z = zoneCenter.z + latDelta }
local randomPosition = veaf.getRandomPointInCircle(position, self.respawnRadius)
veafInterpreter.execute(command, randomPosition, self.coalition, nil, spawnedGroupsNames)
```

`getRandomPointInCircle` answers the **mission-table shape** — `{ x, y }`, where `y` is the easting and
there is no `z`. That is what MiST's `getRandPointInCircle` always returned, and it is the contract the
port kept.

But a command expects a **vec3**. `veafInterpreter.execute`'s own documentation says so, and
[`veafSpawnGround.lua:89`](../../src/scripts/veaf/veafSpawnGround.lua) reads it that way:

```lua
["y"] = spawnPosition.z,
```

So the spawned group's easting is `nil`, and its altitude is whatever the easting happened to be.

**The sibling call twenty lines down does the conversion**, which is what makes this a slip rather
than a misunderstanding:

```lua
vars.point = veaf.getRandomPointInCircle(spawnSpot, self.respawnRadius)
vars.point.z = vars.point.y
vars.point.y = spawnSpot.y
```

## Why nobody saw it

`test_veafAirWaves.lua` covered this path and passed. The stub in `dcs_mocks.lua` answered a **vec3**:

```lua
mist.getRandPointInCircle = function(spot, r)
  return { x = spot.x or 0, y = spot.y or 0, z = spot.z or 0 }
end
```

MiST itself answers a vec2. The test was asserting the mock, and the mock was wrong about the very
thing that matters here. Compare [[assert-the-applied-value-not-the-constant]].

The test now asserts the behaviour as it really is — easting in `y`, `z` nil — with a comment naming
this lot, so the defect stays visible instead of going back into hiding. **Fixing it flips those two
assertions**, which is the check that this lot actually changed something.

## What to do

Convert like the sibling call, and take the altitude from the zone centre:

```lua
local randomPosition = veaf.getRandomPointInCircle(position, self.respawnRadius)
randomPosition.z = randomPosition.y
randomPosition.y = position.y
```

Worth considering rather than assuming: whether `veaf.getRandomPointInCircle` should offer a vec3
variant so this conversion stops being copied by hand at every call site. There are 18 call sites and
two of them convert; the other sixteen hand the vec2 to `veaf.placePointOnLand`, which expects exactly
that shape. A blanket change would be wrong — see `docs/agents/dcs-coordinates.md`.

## Impact

Any air wave whose element is a command in `[lat,lon]cmd` form. A DCS-group element takes the sibling
branch and is unaffected. Unmeasured in game: what a nil easting does to a spawn is worth seeing before
deciding how loudly this should fail.

## Definition of done

- [ ] `veafAirWaves.lua:1012` hands `veafInterpreter.execute` a vec3
- [ ] The two assertions in `test_veafAirWaves.lua` flipped, and the comment naming this lot removed
- [ ] A test that would have caught it: the position reaching the interpreter has a non-nil `z`
- [ ] Checked in game on an air wave with a command element
- [ ] `stylua --check` and `luacheck` clean
