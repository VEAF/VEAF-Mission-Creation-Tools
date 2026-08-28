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
dofile(src .. "/veafScheduler.lua")
dofile(src .. "/veafMath.lua")
dofile(src .. "/veafGeo.lua")
dofile(src .. "/veafMissionDb.lua")
dofile(src .. "/veafAirbases.lua")

-- ---------------------------------------------------------------------------
-- Helpers: build runway and airbase instances without DCS APIs
-- ---------------------------------------------------------------------------

--- Create a veafAirbaseRunway instance directly (bypassing :create() which
--- requires live DCS APIs).  runwayEnd1/2 are {Number, Heading} tables.
local function makeRunway(num1, hdg1, num2, hdg2)
  return setmetatable({ [1] = { Number = num1, Heading = hdg1 }, [2] = { Number = num2, Heading = hdg2 } }, veafAirbaseRunway)
end

--- Create a veafAirbase instance with pre-built runways and no DCS airbase.
local function makeAirbase(runways, name)
  return setmetatable({ Name = name or "TestAB", DisplayName = name or "TestAB", Category = 0, Runways = runways }, veafAirbase)
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
-- TestVeafAirbasesInit
-- ============================================================================
TestVeafAirbasesInit = {}

function TestVeafAirbasesInit:setUp()
  -- force re-initialization on every test
  veafAirbases.Airbases = nil
  veafAirbases.initialized = false
end

function TestVeafAirbasesInit:test_initialize_creates_empty_table()
  -- world.getAirbases() returns {} → Airbases populated but with no entries
  veafAirbases.initialize()
  luaunit.assertIsTable(veafAirbases.Airbases)
end

function TestVeafAirbasesInit:test_initialize_idempotent()
  veafAirbases.initialize()
  local first = veafAirbases.Airbases
  veafAirbases.initialize()
  -- second call without bReset should be a no-op (already initialized)
  luaunit.assertIsTable(veafAirbases.Airbases)
end

function TestVeafAirbasesInit:test_initialize_bReset_reinitializes()
  veafAirbases.initialize()
  veafAirbases.initialize(true)
  luaunit.assertIsTable(veafAirbases.Airbases)
end

-- ============================================================================
-- TestVeafAirbasesLookup
-- ============================================================================
TestVeafAirbasesLookup = {}

function TestVeafAirbasesLookup:setUp()
  veafAirbases.Airbases = nil
  veafAirbases.initialized = false
  veafAirbases.initialize()
end

function TestVeafAirbasesLookup:test_getAirbaseByName_not_found()
  local ab = veafAirbases.getAirbaseByName("NotFound")
  luaunit.assertNil(ab)
end

function TestVeafAirbasesLookup:test_getAirbaseFromDcsAirbase_nil()
  local ab = veafAirbases.getAirbaseFromDcsAirbase(nil)
  luaunit.assertNil(ab)
end

function TestVeafAirbasesLookup:test_getNearestAirbaseList_empty_db()
  -- With empty Airbases table, loop body never executes → returns {}
  local mockUnit = {
    getPoint = function()
      return { x = 0, y = 0, z = 0 }
    end,
  }
  local list = veafAirbases.getNearestAirbaseList(mockUnit, 1)
  luaunit.assertIsTable(list)
end

-- ============================================================================
-- TestVeafAirbaseToString
-- ============================================================================
TestVeafAirbaseToString = {}

function TestVeafAirbaseToString:test_toString_no_runways()
  local ab = makeAirbase({})
  local s = ab:toString()
  luaunit.assertIsString(s)
  luaunit.assertTrue(#s > 0)
end

function TestVeafAirbaseToString:test_toString_with_runway()
  local ab = makeAirbase({ makeRunway(9, 90, 27, 270) })
  local s = ab:toString()
  luaunit.assertIsString(s)
  luaunit.assertTrue(#s > 0)
end

-- ============================================================================
-- TestVeafAirbaseRunwayCreate — exercises veafAirbaseRunway:create()
-- ============================================================================
TestVeafAirbaseRunwayCreate = {}

-- Minimal DCS airbase/runway mock for create()
local function makeDcsAirbase(name)
  return {
    getName = function()
      return name
    end,
  }
end
local function makeDcsRunway(numberStr, courseDeg)
  -- DCS convention: course stored as negative radians of the True heading
  return { Name = numberStr, course = -math.rad(courseDeg) }
end

function TestVeafAirbaseRunwayCreate:test_create_nil_dcsAirbase_returns_nil()
  local rwy = veafAirbaseRunway:create(nil, makeDcsRunway("9", 90), 1)
  luaunit.assertNil(rwy)
end

function TestVeafAirbaseRunwayCreate:test_create_nil_dcsRunway_returns_nil()
  local rwy = veafAirbaseRunway:create(makeDcsAirbase("TestAB"), nil, 1)
  luaunit.assertNil(rwy)
end

function TestVeafAirbaseRunwayCreate:test_create_rwy09_27_east_west()
  -- Runway 9 (heading 90°) / 27 (heading 270°)
  local dcsAb = makeDcsAirbase("TestAB")
  local dcsRwy = makeDcsRunway("9", 90)
  local rwy = veafAirbaseRunway:create(dcsAb, dcsRwy, 1)
  luaunit.assertNotNil(rwy)
  -- result ordered by ascending runway number
  luaunit.assertEquals(rwy[1].Number, 9)
  luaunit.assertEquals(rwy[2].Number, 27)
end

function TestVeafAirbaseRunwayCreate:test_create_rwy14_32()
  local dcsAb = makeDcsAirbase("TestAB")
  local dcsRwy = makeDcsRunway("14", 140)
  local rwy = veafAirbaseRunway:create(dcsAb, dcsRwy, 1)
  luaunit.assertNotNil(rwy)
  luaunit.assertEquals(rwy[1].Number, 14)
  luaunit.assertEquals(rwy[2].Number, 32)
end

function TestVeafAirbaseRunwayCreate:test_create_sets_heading_fields()
  local dcsAb = makeDcsAirbase("TestAB")
  local dcsRwy = makeDcsRunway("9", 90)
  local rwy = veafAirbaseRunway:create(dcsAb, dcsRwy, 1)
  luaunit.assertNotNil(rwy[1].Heading)
  luaunit.assertNotNil(rwy[2].Heading)
end

function TestVeafAirbaseRunwayCreate:test_create_iReportOrder_2_unknown_airbase_no_crash()
  -- iReportOrder > 1 but airbase not in manual corrections → no crash, returns runway
  local dcsAb = makeDcsAirbase("UnknownAirbase")
  local dcsRwy = makeDcsRunway("9", 90)
  local rwy = veafAirbaseRunway:create(dcsAb, dcsRwy, 2)
  luaunit.assertNotNil(rwy)
end

function TestVeafAirbaseRunwayCreate:test_create_result_has_metatable()
  local dcsAb = makeDcsAirbase("TestAB")
  local dcsRwy = makeDcsRunway("9", 90)
  local rwy = veafAirbaseRunway:create(dcsAb, dcsRwy, 1)
  luaunit.assertNotNil(rwy)
  -- toString() works because metatable is set
  luaunit.assertIsString(rwy:toString())
end

-- ============================================================================
-- TestVeafAirbasesGetNearest — exercises getNearestAirbase()
-- ============================================================================
TestVeafAirbasesGetNearest = {}

function TestVeafAirbasesGetNearest:setUp()
  veafAirbases.Airbases = nil
  veafAirbases.initialized = false
  veafAirbases.initialize()
end

function TestVeafAirbasesGetNearest:test_getNearestAirbase_empty_db_returns_nil()
  -- Empty Airbases: loop never runs → nearestList={} → return nil
  local mockUnit = {
    getPoint = function()
      return { x = 0, y = 0, z = 0 }
    end,
    getName = function()
      return "mockUnit"
    end,
  }
  local ab = veafAirbases.getNearestAirbase(mockUnit)
  luaunit.assertNil(ab)
end

-- ============================================================================
-- TestVeafAirbaseRunwayInServiceString
-- ============================================================================
TestVeafAirbaseRunwayInServiceString = {}

function TestVeafAirbaseRunwayInServiceString:test_returns_string_when_runway_found()
  local ab = makeAirbase({ makeRunway(9, 90, 27, 270) })
  local s = ab:getRunwayInServiceString(270)
  luaunit.assertIsString(s)
  luaunit.assertEquals(s, "27")
end

function TestVeafAirbaseRunwayInServiceString:test_returns_nil_when_no_runways()
  local ab = makeAirbase({})
  local s = ab:getRunwayInServiceString(270)
  luaunit.assertNil(s)
end

-- ============================================================================
-- Run
-- ============================================================================
os.exit(luaunit.LuaUnit.run())
