--- Unit tests for veafAirbases.lua
---
--- Run:  lua test/lua/test_veafAirbases.lua
---
--- Covers:
---   - veafAirbaseRunway:toString       (display format: "RWY xx(hhh.hhT) / yy(hhh.hhT)")
---   - veafAirbase:getRunwayInService   (wind-based runway selection via headwind component)
---   - getRunwayInService with multiple runways (best headwind wins)
---   - Edge cases: crosswind (tie) and calm (both directions equal)

local _base = debug.getinfo(1, "S").source:match("^@(.+)[\\/]") or "."
luaunit = dofile(_base .. "/luaunit.lua")
dofile(_base .. "/dcs_mocks.lua")
local src = _base .. "/../../src/scripts/veaf"
dofile(src .. "/veaf.lua")
dofile(src .. "/veafAirbases.lua")

-- ---------------------------------------------------------------------------
-- Helpers: build runway and airbase instances without DCS APIs
-- ---------------------------------------------------------------------------

--- Create a veafAirbaseRunway instance directly (bypassing :create() which
--- requires live DCS APIs).  runwayEnd1/2 are {Number, Heading} tables.
local function makeRunway(num1, hdg1, num2, hdg2)
  return setmetatable(
    { [1] = { Number = num1, Heading = hdg1 }, [2] = { Number = num2, Heading = hdg2 } },
    veafAirbaseRunway
  )
end

--- Create a veafAirbase instance with pre-built runways and no DCS airbase.
local function makeAirbase(runways, name)
  return setmetatable(
    { Name = name or "TestAB", DisplayName = name or "TestAB", Category = 0, Runways = runways },
    veafAirbase
  )
end

-- ============================================================================
-- TestVeafAirbaseRunwayToString
-- ============================================================================
TestVeafAirbaseRunwayToString = {}

function TestVeafAirbaseRunwayToString:test_format_contains_rwy_numbers()
  local rwy = makeRunway(9, 90, 27, 270)
  local s = rwy:toString()
  luaunit.assertStrContains(s, "09")
  luaunit.assertStrContains(s, "27")
end

function TestVeafAirbaseRunwayToString:test_format_contains_headings()
  local rwy = makeRunway(9, 90, 27, 270)
  local s = rwy:toString()
  luaunit.assertStrContains(s, "90.00T")
  luaunit.assertStrContains(s, "270.00T")
end

function TestVeafAirbaseRunwayToString:test_format_two_digit_runway_number()
  local rwy = makeRunway(14, 140, 32, 320)
  local s = rwy:toString()
  luaunit.assertStrContains(s, "14")
  luaunit.assertStrContains(s, "32")
end

-- ============================================================================
-- TestVeafAirbaseRunwayInService  — single runway 09/27
-- ============================================================================
TestVeafAirbaseRunwayInService = {}

function TestVeafAirbaseRunwayInService:setUp()
  -- Single runway aligned east-west; runway ends: 09 (hdg 90) and 27 (hdg 270)
  local runways = { makeRunway(9, 90, 27, 270) }
  self.ab = makeAirbase(runways, "TestAB_EW")
end

function TestVeafAirbaseRunwayInService:test_wind_from_west_uses_rwy27()
  -- Wind from 270° → into RWY 27 (best headwind)
  local end_ = self.ab:getRunwayInService(270)
  luaunit.assertNotNil(end_)
  luaunit.assertEquals(end_.Number, 27)
end

function TestVeafAirbaseRunwayInService:test_wind_from_east_uses_rwy09()
  -- Wind from 090° → into RWY 09
  local end_ = self.ab:getRunwayInService(90)
  luaunit.assertNotNil(end_)
  luaunit.assertEquals(end_.Number, 9)
end

function TestVeafAirbaseRunwayInService:test_wind_from_south_returns_a_runway()
  -- Crosswind (180°): headwind = 0 for both; tie goes to first encountered (09)
  local end_ = self.ab:getRunwayInService(180)
  luaunit.assertNotNil(end_)
  -- Either is acceptable; just verify we get a result
  luaunit.assertTrue(end_.Number == 9 or end_.Number == 27)
end

function TestVeafAirbaseRunwayInService:test_wind_roughly_from_west_uses_rwy27()
  -- 250° is closer to 270 than to 090
  local end_ = self.ab:getRunwayInService(250)
  luaunit.assertEquals(end_.Number, 27)
end

function TestVeafAirbaseRunwayInService:test_wind_from_360_uses_rwy09_or_27()
  -- Wind from north: both ends have equal headwind. Not an error.
  local end_ = self.ab:getRunwayInService(360)
  luaunit.assertNotNil(end_)
end

-- ============================================================================
-- TestVeafAirbaseRunwayInServiceMultiRunway — two crossing runways
-- ============================================================================
TestVeafAirbaseRunwayInServiceMultiRunway = {}

function TestVeafAirbaseRunwayInServiceMultiRunway:setUp()
  -- Two runways: 09/27 (E-W, hdg 090/270) and 14/32 (SE-NW, hdg 140/320)
  local runways = {
    makeRunway(9, 90, 27, 270),
    makeRunway(14, 140, 32, 320),
  }
  self.ab = makeAirbase(runways, "TestAB_2RWY")
end

function TestVeafAirbaseRunwayInServiceMultiRunway:test_wind_from_west_uses_rwy27()
  local end_ = self.ab:getRunwayInService(270)
  luaunit.assertNotNil(end_)
  luaunit.assertEquals(end_.Number, 27)
end

function TestVeafAirbaseRunwayInServiceMultiRunway:test_wind_from_south_uses_rwy14()
  -- Wind from ~180°: cos(180-90)=0, cos(180-270)=0, cos(180-140)=cos(40)≈0.766, cos(180-320)=cos(-140)≈-0.766
  -- Best headwind is for rwy14 end (heading 140)
  local end_ = self.ab:getRunwayInService(180)
  luaunit.assertNotNil(end_)
  luaunit.assertEquals(end_.Number, 14)
end

function TestVeafAirbaseRunwayInServiceMultiRunway:test_wind_from_north_uses_rwy32()
  -- Wind from 000/360°: cos(0-090)=0, cos(0-270)=0, cos(0-140)=cos(-140)≈-0.766, cos(0-320)=cos(-320)=cos(320)≈0.766
  -- Best headwind is rwy32 end (heading 320)
  local end_ = self.ab:getRunwayInService(0)
  luaunit.assertNotNil(end_)
  luaunit.assertEquals(end_.Number, 32)
end

function TestVeafAirbaseRunwayInServiceMultiRunway:test_returns_end_with_number_field()
  local end_ = self.ab:getRunwayInService(270)
  luaunit.assertNotNil(end_.Number)
  luaunit.assertNotNil(end_.Heading)
end

-- ============================================================================
-- TestVeafAirbaseNoRunway
-- ============================================================================
TestVeafAirbaseNoRunway = {}

function TestVeafAirbaseNoRunway:test_no_runways_returns_nil()
  local ab = makeAirbase({})
  local end_ = ab:getRunwayInService(270)
  luaunit.assertNil(end_)
end

-- ============================================================================
-- Run
-- ============================================================================
os.exit(luaunit.LuaUnit.run())
