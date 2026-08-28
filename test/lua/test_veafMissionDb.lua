--- Unit tests for veafMissionDb.lua — the mission-side services VEAF needs at runtime.
---
--- Run:  lua test/lua/test_veafMissionDb.lua
---
--- Covers:
---   - Unit ids are unique, increasing, and start above everything else that allocates them

-- ---------------------------------------------------------------------------
-- Bootstrap: load the test framework, DCS mocks, and modules under test.
-- ---------------------------------------------------------------------------
local _base = debug.getinfo(1, "S").source:match("^@(.+)[\\/]") or "."
luaunit = dofile(_base .. "/luaunit.lua") -- exported as global for test methods
dofile(_base .. "/dcs_mocks.lua")
dofile(_base .. "/../../src/scripts/veaf/veaf.lua")
dofile(_base .. "/../../src/scripts/veaf/veafScheduler.lua")
dofile(_base .. "/../../src/scripts/veaf/veafMath.lua")
dofile(_base .. "/../../src/scripts/veaf/veafGeo.lua")
dofile(_base .. "/../../src/scripts/veaf/veafMissionDb.lua")

TestVeafMissionDb = {}

function TestVeafMissionDb:setUp()
  dcs_mocks.reset()
  veafMissionDb.lastUnitId = veafMissionDb.FIRST_UNIT_ID - 1
end

function TestVeafMissionDb:test_idsAreUniqueAndIncreasing()
  local first = veaf.getNextUnitId()
  local second = veaf.getNextUnitId()
  local third = veaf.getNextUnitId()
  luaunit.assertEquals(second, first + 1)
  luaunit.assertEquals(third, second + 1)
end

function TestVeafMissionDb:test_theFirstIdIsTheConfiguredBase()
  luaunit.assertEquals(veaf.getNextUnitId(), veafMissionDb.FIRST_UNIT_ID)
end

--- DCS reserves 6900–30000, and MiST — still injected alongside us for the rest of this campaign —
--- allocates from 30000 upwards once it passes 6900. Our ids have to start clear of both.
function TestVeafMissionDb:test_idsStartClearOfTheReservedBandAndOfMist()
  luaunit.assertTrue(veafMissionDb.FIRST_UNIT_ID > 30000)
  luaunit.assertTrue(veaf.getNextUnitId() > 30000)
end

function TestVeafMissionDb:test_athousandIdsAreAllDistinct()
  local seen = {}
  for _ = 1, 1000 do
    local id = veaf.getNextUnitId()
    luaunit.assertNil(seen[id])
    seen[id] = true
  end
end

-- ---------------------------------------------------------------------------
-- Run
-- ---------------------------------------------------------------------------
os.exit(luaunit.LuaUnit.run())
