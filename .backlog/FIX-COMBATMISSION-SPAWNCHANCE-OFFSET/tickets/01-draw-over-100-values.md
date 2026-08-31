# 01 — Draw over 100 values, not 101

Status: ⬜ ready

Type: fix · File: `src/scripts/veaf/veafCombatMission.lua`

## The change

One line, at `veafCombatMission.lua:868`: `math.random(0, 100)` becomes `math.random(1, 100)`.

## Definition of done

- [ ] `#spawnchance=0` never spawns — over many activations, not one run
- [ ] `#spawnchance=100` always spawns
- [ ] `#spawnchance=50` lands near half, asserted statistically with a seeded RNG
- [ ] The tests drive `activate()` and observe what was actually spawned, through the DCS mocks —
      not the accessor
- [ ] `poetry run test-lua` green, `stylua --check src/scripts/veaf/ test/lua/` clean

## Reuse rather than reinvent

`test/lua/test_veafCombatZone.lua` grew exactly this kind of test in PR #859: a fixed-seed LCG
replacing `math.random` so the statistics are deterministic and identical under Lua 5.1 and the
5.4 shim. Read it first and follow the same pattern; if the harness is reusable, share it rather
than copying it.

## Do not widen

The combat mission has no retry loop and no forced draw — only the offset is wrong. Resist making
it resemble the zone: the zone's `#spawncount` machinery does not exist here and nothing asks for
it.
