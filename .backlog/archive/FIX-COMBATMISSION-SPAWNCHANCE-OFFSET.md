# FIX-COMBATMISSION-SPAWNCHANCE-OFFSET — a combat mission's spawn chance is off by one value

Status: ✅ done · archived 2026-09-28

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
| 01 | [Draw over 100 values, not 101](FIX-COMBATMISSION-SPAWNCHANCE-OFFSET.md) | fix |

---

## Tickets, in full

## 01 — Draw over 100 values, not 101

Status: ✅ done

Type: fix · File: `src/scripts/veaf/veafCombatMission.lua`

### The change

One line, at `veafCombatMission.lua:868`: `math.random(0, 100)` becomes `math.random(1, 100)`.

### Definition of done

- [x] `#spawnchance=0` never spawns — over many activations, not one run
- [x] `#spawnchance=100` always spawns
- [x] `#spawnchance=50` lands near half, asserted statistically with a seeded RNG
- [x] The tests drive `activate()` and observe what was actually spawned, through the DCS mocks —
      not the accessor
- [x] `poetry run test-lua` green, `stylua --check src/scripts/veaf/ test/lua/` clean

### Reuse rather than reinvent

`test/lua/test_veafCombatZone.lua` grew exactly this kind of test in PR #859: a fixed-seed LCG
replacing `math.random` so the statistics are deterministic and identical under Lua 5.1 and the
5.4 shim. Read it first and follow the same pattern; if the harness is reusable, share it rather
than copying it.

### Do not widen

The combat mission has no retry loop and no forced draw — only the offset is wrong. Resist making
it resemble the zone: the zone's `#spawncount` machinery does not exist here and nothing asks for
it.

---
