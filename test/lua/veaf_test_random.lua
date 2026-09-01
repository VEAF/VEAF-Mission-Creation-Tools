--- A seeded generator for tests whose assertions are statistical.
---
--- A statistic asserted against the interpreter's own RNG is a test that fails once in a while for no
--- reason. This is a plain Lehmer LCG, so the same sequence comes out of Lua 5.1 and of the 5.4 shim
--- the CI runs on — `math.randomseed` guarantees neither.
---
--- Usage:
---   local seededRandom = dofile(_base .. "/veaf_test_random.lua")
---   function MySuite:setUp()
---     self._random = math.random
---     math.random = seededRandom(20260831)
---   end
---   function MySuite:tearDown()
---     math.random = self._random
---   end
---
--- The returned function honours the three shapes of `math.random`: no argument (a float in [0, 1)),
--- one argument (an integer in [1, m]) and two (an integer in [m, n]).
---
--- Shared rather than copied: `test_veafCombatZone.lua` grew it for FIX-COMBATZONE-SPAWNCHANCE and
--- `test_veafCombatMission.lua` needs exactly the same thing for FIX-COMBATMISSION-SPAWNCHANCE-OFFSET.
--- The file is deliberately **not** named `test_*.lua`: the runner globs that pattern and would treat
--- a helper as a suite with no tests in it.
--- @param seed number
--- @return function a drop-in replacement for `math.random`
local function seededRandom(seed)
  local state = seed % 2147483647
  if state <= 0 then
    state = state + 2147483646
  end
  return function(m, n)
    state = (state * 16807) % 2147483647
    local unit = (state - 1) / 2147483646 -- in [0, 1)
    if m == nil then
      return unit
    end
    if n == nil then
      m, n = 1, m
    end
    return m + math.floor(unit * (n - m + 1))
  end
end

return seededRandom
