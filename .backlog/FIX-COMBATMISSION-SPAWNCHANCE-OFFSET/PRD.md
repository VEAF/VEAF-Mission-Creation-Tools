# FIX-COMBATMISSION-SPAWNCHANCE-OFFSET — a combat mission's spawn chance is off by one value

Status: ⬜ ready

Origin: found while delivering `FIX-COMBATZONE-SPAWNCHANCE` (PR #859), which fixed the same
arithmetic in the combat **zone**. Verified on `origin/develop` at `917d999e`.

## The defect

`veafCombatMission.lua:868` draws over **101** values and compares inclusively:

```lua
local chance = math.random(0, 100)
if chance <= missionElement:getSpawnChance() then
```

So the percentage is never the percentage:

| Written | Actual |
|---|---|
| `#spawnchance=0` | 1 chance in 101 — **an element that must never spawn, spawns** |
| `#spawnchance=50` | 51/101 ≈ 50.5 % |
| `#spawnchance=100` | 100 %, correct |

The zero case is the one that bites: "never" is the only value a mission maker writes expecting a
guarantee, and it is the only one the code cannot deliver.

## Why it is its own lot

`FIX-COMBATZONE-SPAWNCHANCE` fixed `veafCombatZone.lua` and deliberately did not touch this file:
the two share **no code** — separate class, no `spawnCount`, no retry loop, no forced draw. The
combat mission draws once per element and already honours the probability, at this one offset.

That also makes this a much smaller change than the zone's: there is no retry mechanism to
reason about, only the draw.

## The fix

`math.random(1, 100)`, as in the zone. Values 1..100 compared with `<=` give exactly N chances in
100 for `#spawnchance=N`, and 0 for zero.

## Scope

| # | Ticket | Type |
|---|--------|------|
| 01 | [Draw over 100 values, not 101](tickets/01-draw-over-100-values.md) | fix |
