# FIX-AIRWAVES-COMMAND-EASTING — a command-driven air wave spawns with no easting

Status: 🧑 waiting-human

Code shipped; the in-game look is ticket 02 and needs DCS started.

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

> **Correction, 2026-09-01 — that sibling no longer exists.** The DCS-group branch was rewritten to
> go through the `VeafGroupSpawn` chain, whose own comment says so: *"The scatter is the chain's
> business now, which is what removes the three lines of point.z/point.y juggling this used to copy
> from its twin in veafQraCore."* So the three quoted lines are gone from `develop` and the branch
> below the defect no longer converts anything — the *contrast* the PRD rested on is stale, though
> the defect itself is exactly as described. The evidence that it is a slip and not a
> misunderstanding is now the twin instead: `veafQraCore.lua` carries the same branch, word for word.

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

> **Correction, 2026-09-01 — both numbers in that paragraph are wrong.** 18 call sites is right.
> **Eleven** hand the vec2 to `veaf.placePointOnLand`, not sixteen; **three** convert, not two, the
> third being `veafSpawnAircraft:1037`. The remaining four read the vec2 themselves and are correct.
> The conclusion stands and gets firmer — see point 4 above for why the third converter is what
> actually rules the variant out.

## Impact

Any air wave whose element is a command in `[lat,lon]cmd` form — **and, found on implementation, any
QRA with such an element too**. A DCS-group element takes the sibling branch and is unaffected.
Unmeasured in game: what a nil easting does to a spawn is worth seeing before deciding how loudly this
should fail — that is ticket 02.

## Scope

| # | Ticket | Risk | Status |
|---|---|---|---|
| 01 | A command element is handed a vec3, in both modules that run one | low — two lines per site, covered by tests that fail two ways | ✅ |
| 02 | See a command-driven wave arrive where it should | needs DCS | 🧑 |

## What implementation found that this document did not say

Written down rather than folded in silently, because a PRD is a dated note and this one was three
days old:

1. **A second site, same defect.** `veafQraCore.lua:994` — `VeafQRACore:deploy` — hands
   `veafInterpreter.execute` the same unconverted draw. Found by enumerating the three callers of
   `veafInterpreter.execute` instead of trusting the PRD's list of one. `veafCombatZone.lua:1608`,
   the third, builds its vec3 by hand and is correct. Both defective sites are fixed under ticket 01.
2. **The "sibling call twenty lines down" is gone**, see the correction above. The PRD's supporting
   argument is stale; its diagnosis is not.
3. **The counts in "What to do" below are both wrong.** Enumerated from `src/scripts/veaf/`: there are
   indeed 18 call sites, but **eleven** hand the vec2 to `veaf.placePointOnLand` (not sixteen) and
   **three** convert to a vec3 (not two) — `veafSpawnAircraft:1037` has been doing it all along. Four
   more read the vec2 themselves and are correct, so fifteen of eighteen want it as it comes. Full
   table in ticket 01.
4. **The vec3 variant is declined**, and the corrected numbers are what decide it rather than the
   headcount: `veafSpawnAircraft:1037` converts with a **computed** altitude, not the zone centre's,
   so the three converting sites have no common altitude source and no single helper can serve them
   without being handed the altitude anyway — at which point it saves nothing over the two lines it
   would replace. On top of that, a second shape to pick between is the exact hazard
   `docs/agents/dcs-coordinates.md` exists to describe.

## Definition of done

- [x] `veafAirWaves.lua` hands `veafInterpreter.execute` a vec3
- [x] `veafQraCore.lua` does too — its twin, outside the scope written above
- [x] The two assertions in `test_veafAirWaves.lua` flipped, and the comment naming this lot removed
- [x] A test that would have caught it, telling *correct*, *zero* and *absent* apart, in both modules
- [x] Each new test proven able to fail, by two sabotages of the fixed code
- [ ] Checked in game on an air wave with a command element — ticket 02
- [x] `stylua --check` clean locally; `luacheck` is not installed on this workstation and **passed on
      the CI Lua gate** (PR #884), so the gate is met rather than merely deferred
