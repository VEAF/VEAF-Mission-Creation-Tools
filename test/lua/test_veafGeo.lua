--- Unit tests for veafGeo.lua — the coordinate output ported off MiST.
---
--- Run:  lua test/lua/test_veafGeo.lua
---
--- Every expectation here is a **literal string**, and every one was produced by running MiST's own
--- `tostringLL` / `tostringMGRS` before the port. These strings reach pilots in F10 reports and
--- briefings that mission makers have been reading for years, so the port was not allowed to improve
--- them. Where MiST was visibly wrong, correcting it was a decision of its own: FIX-DMS-MINUTE-CARRY
--- fixed the minute-to-degree carry, and FIX-ZERO-HEMISPHERE the hemisphere letter at exactly zero.
---
--- Covers:
---   - Decimal minutes at the three precisions the code base uses (0, 2, 3)
---   - Degrees/minutes/seconds at precision 0 and 2
---   - Both hemispheres, either side of the prime meridian, and a three-digit longitude
---   - The hemisphere letters at exactly zero, and just below it
---   - The minute carry into the degree, in decimal and in DMS, on either axis and on both at once
---   - MGRS at every precision used (0, 3, 5) plus the digit overflow its rounding can produce

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

TestVeafGeo = {}

function TestVeafGeo:setUp()
  dcs_mocks.reset()
end

-- ---------------------------------------------------------------------------
-- Latitude and longitude, decimal minutes
-- ---------------------------------------------------------------------------

--- The separator between the two coordinates is a **tab followed by a space**, not two spaces.
--- `veafNamedPoints` also indexes into the result to insert a degree sign, so the leading field
--- widths are load-bearing too.
function TestVeafGeo:test_decimalMinutesAtPrecision2()
  luaunit.assertEquals(veaf.toStringLL(42.35, 43.5678, 2), "42 21.00'N\t 43 34.07'E")
end

function TestVeafGeo:test_decimalMinutesAtPrecision3()
  luaunit.assertEquals(veaf.toStringLL(42.35, 43.5678, 3), "42 21.000'N\t 43 34.068'E")
end

function TestVeafGeo:test_decimalMinutesAtPrecision0DropsTheDecimalPoint()
  luaunit.assertEquals(veaf.toStringLL(41.99999, 43.0, 0), "42 00'N\t 43 00'E")
end

function TestVeafGeo:test_southernAndEasternHemispheres()
  luaunit.assertEquals(veaf.toStringLL(-33.865, 151.2094, 2), "33 51.90'S\t 151 12.56'E")
end

function TestVeafGeo:test_westOfThePrimeMeridian()
  luaunit.assertEquals(veaf.toStringLL(51.4778, -0.0015, 2), "51 28.67'N\t 00 00.09'W")
end

--- A longitude past 100° takes three digits while the latitude keeps two: the format pads to a
--- minimum width, it does not truncate.
function TestVeafGeo:test_threeDigitLongitude()
  luaunit.assertEquals(veaf.toStringLL(42.35, 143.5678, 2), "42 21.00'N\t 143 34.07'E")
end

--- Exactly zero reads as **N** and **E** — since FIX-ZERO-HEMISPHERE. MiST tested `> 0` and so put
--- the equator and the prime meridian on the negative side; zero is the positive side of both axes
--- everywhere else, so this is the reading that matches the rest.
function TestVeafGeo:test_zeroReadsAsNorthAndEast()
  luaunit.assertEquals(veaf.toStringLL(0, 0, 2), "00 00.00'N\t 00 00.00'E")
end

--- The two letters are chosen independently, so a fix applied to one axis only would still satisfy a
--- both-axes test. These two catch that.
function TestVeafGeo:test_zeroLatitudeWithANegativeLongitude()
  luaunit.assertEquals(veaf.toStringLL(0, -12.5, 2), "00 00.00'N\t 12 30.00'W")
end

function TestVeafGeo:test_zeroLongitudeWithANegativeLatitude()
  luaunit.assertEquals(veaf.toStringLL(-12.5, 0, 2), "12 30.00'S\t 00 00.00'E")
end

--- And just below zero still reads S and W: the negative side did not lose its letter, zero changed
--- sides.
function TestVeafGeo:test_justBelowZeroStillReadsSouthAndWest()
  luaunit.assertEquals(veaf.toStringLL(-0.0001, -0.0001, 2), "00 00.01'S\t 00 00.01'W")
end

-- ---------------------------------------------------------------------------
-- Latitude and longitude, degrees / minutes / seconds
-- ---------------------------------------------------------------------------

function TestVeafGeo:test_dmsAtPrecision0()
  luaunit.assertEquals(veaf.toStringLL(42.35, 43.5678, 0, true), "42 21' 00\"N\t 43 34' 04\"E")
end

function TestVeafGeo:test_dmsAtPrecision2KeepsFractionalSeconds()
  luaunit.assertEquals(veaf.toStringLL(42.35, 43.5678, 2, true), "42 21' 00.00\"N\t 43 34' 04.08\"E")
end

function TestVeafGeo:test_dmsInTheSouthernHemisphere()
  luaunit.assertEquals(veaf.toStringLL(-33.865, 151.2094, 0, true), "33 51' 54\"S\t 151 12' 34\"E")
end

function TestVeafGeo:test_dmsWestOfThePrimeMeridian()
  luaunit.assertEquals(veaf.toStringLL(51.4778, -0.0015, 0, true), "51 28' 40\"N\t 00 00' 05\"W")
end

-- ---------------------------------------------------------------------------
-- The carry, and MiST's asymmetry about it
-- ---------------------------------------------------------------------------

--- In decimal mode, minutes rounding up to 60 carry into the degree: 41.99999 reads as 42° 00.00'.
function TestVeafGeo:test_decimalMinutesCarryIntoTheDegree()
  luaunit.assertEquals(veaf.toStringLL(41.99999, 43.0, 2), "42 00.00'N\t 43 00.00'E")
end

--- In DMS it carries too — since FIX-DMS-MINUTE-CARRY. MiST stopped after the seconds and printed
--- `41 60' 00"N` here, which DROP-MIST ticket 03 reproduced on purpose before this lot corrected it.
--- The two layouts now agree: 41.99999444 is 42 degrees exactly, however it is written.
function TestVeafGeo:test_dmsMinutesCarryIntoTheDegree()
  luaunit.assertEquals(veaf.toStringLL(41.99999444, 43.0, 0, true), "42 00' 00\"N\t 43 00' 00\"E")
end

--- The carry has to fire on the longitude too: a separate code path from the latitude, and MiST got
--- both halves wrong in the same way.
function TestVeafGeo:test_dmsCarriesOnTheLongitudeAsWell()
  luaunit.assertEquals(veaf.toStringLL(42.0, 43.99999444, 0, true), "42 00' 00\"N\t 44 00' 00\"E")
end

--- Both axes at once, south and west, so the sign handling is exercised together with the carry
--- rather than separately from it.
function TestVeafGeo:test_dmsCarriesOnBothAxesAtOnce()
  luaunit.assertEquals(veaf.toStringLL(-41.99999444, -43.99999444, 0, true), "42 00' 00\"S\t 44 00' 00\"W")
end

--- 59' 59.7" at precision 0: the seconds round up to 60, the minute reaches 60, and the whole thing
--- lands on the next degree in a single pass.
---
--- Not 59.5" — that is the rounding threshold itself, and the double closest to
--- `41 + 59/60 + 59.5/3600` falls just under it, so such a test would be measuring floating-point
--- representation rather than the carry.
function TestVeafGeo:test_dmsCarriesFromTheLastSecondOfTheLastMinute()
  local lat = 41 + 59 / 60 + 59.7 / 3600
  luaunit.assertEquals(veaf.toStringLL(lat, 43.0, 0, true), "42 00' 00\"N\t 43 00' 00\"E")
end

--- And it must not fire when it should not: at precision 2 the same position keeps its fractional
--- seconds and stays at 41 degrees. A carry that triggered early would round positions that are
--- merely close to a boundary.
function TestVeafGeo:test_dmsDoesNotCarryWhenTheSecondsStayBelow60()
  luaunit.assertEquals(veaf.toStringLL(41.99999444, 43.0, 2, true), "41 59' 59.98\"N\t 43 00' 00.00\"E")
end

-- ---------------------------------------------------------------------------
-- MGRS
-- ---------------------------------------------------------------------------

local function mgrs(zone, digraph, easting, northing)
  return { UTMZone = zone, MGRSDigraph = digraph, Easting = easting, Northing = northing }
end

function TestVeafGeo:test_mgrsAtPrecision0IsTheSquareAlone()
  luaunit.assertEquals(veaf.toStringMGRS(mgrs("38T", "KM", 12345, 67890), 0), "38T KM")
end

function TestVeafGeo:test_mgrsAtPrecision3()
  luaunit.assertEquals(veaf.toStringMGRS(mgrs("38T", "KM", 12345, 67890), 3), "38T KM 123 679")
end

function TestVeafGeo:test_mgrsAtPrecision5IsTheFullGrid()
  luaunit.assertEquals(veaf.toStringMGRS(mgrs("38T", "KM", 12345, 67890), 5), "38T KM 12345 67890")
end

function TestVeafGeo:test_mgrsAtPrecision1()
  luaunit.assertEquals(veaf.toStringMGRS(mgrs("38T", "KM", 12345, 67890), 1), "38T KM 1 7")
end

--- Precision 3 divides by 100 and rounds, so an easting of 99999 becomes 1000 — one digit more than
--- the requested three. MiST pads to a minimum width and never truncates, so the extra digit is
--- printed. Pinned rather than corrected, for the same reason as the DMS carry above.
function TestVeafGeo:test_mgrsRoundingCanOverflowTheRequestedWidth()
  luaunit.assertEquals(veaf.toStringMGRS(mgrs("37T", "CJ", 99999, 5), 3), "37T CJ 1000 000")
  luaunit.assertEquals(veaf.toStringMGRS(mgrs("37T", "CJ", 99999, 5), 1), "37T CJ 10 0")
end

-- ---------------------------------------------------------------------------
-- Zones and positions
-- ---------------------------------------------------------------------------

TestVeafGeoZones = {}

function TestVeafGeoZones:setUp()
  dcs_mocks.reset()
end

function TestVeafGeoZones:test_zoneToVec3ReturnsTheCentre()
  dcs_mocks.addZone("BULLSEYE", 1000, 2000, 300)
  luaunit.assertEquals(veaf.zoneToVec3("BULLSEYE"), { x = 1000, y = 0, z = 2000 })
end

--- Nil, not an empty table. MiST answered `{}`, which is truthy, so `veafCombatZone`'s guard against a
--- missing trigger zone could never fire — it has been dead code since it was written.
function TestVeafGeoZones:test_zoneToVec3OnAnUnknownZoneIsNil()
  luaunit.assertNil(veaf.zoneToVec3("NO SUCH ZONE"))
end

function TestVeafGeoZones:test_getAvgPosOfTwoUnits()
  dcs_mocks.addUnit("one", {
    getPoint = function()
      return { x = 0, y = 0, z = 0 }
    end,
  })
  dcs_mocks.addUnit("two", {
    getPoint = function()
      return { x = 100, y = 50, z = 200 }
    end,
  })
  luaunit.assertEquals(veaf.getAvgPos({ "one", "two" }), { x = 50, y = 25, z = 100 })
end

--- A name nobody answers to must be skipped, not counted as the origin: averaging in {0,0,0} would
--- drag the answer towards the corner of the map.
function TestVeafGeoZones:test_getAvgPosSkipsNamesThatDoNotResolve()
  dcs_mocks.addUnit("real", {
    getPoint = function()
      return { x = 100, y = 0, z = 200 }
    end,
  })
  luaunit.assertEquals(veaf.getAvgPos({ "real", "ghost" }), { x = 100, y = 0, z = 200 })
end

function TestVeafGeoZones:test_getAvgPosOfNothingIsNil()
  luaunit.assertNil(veaf.getAvgPos({}))
  luaunit.assertNil(veaf.getAvgPos({ "ghost" }))
end

function TestVeafGeoZones:test_getAvgGroupPosAveragesTheGroupsUnits()
  dcs_mocks.addUnit("g1", {
    getPoint = function()
      return { x = 0, y = 0, z = 0 }
    end,
  })
  dcs_mocks.addUnit("g2", {
    getPoint = function()
      return { x = 200, y = 0, z = 400 }
    end,
  })
  dcs_mocks.addGroup("pair", {
    getUnits = function()
      return { Unit.getByName("g1"), Unit.getByName("g2") }
    end,
  })
  luaunit.assertEquals(veaf.getAvgGroupPos("pair"), { x = 100, y = 0, z = 200 })
end

function TestVeafGeoZones:test_getAvgGroupPosOfAMissingGroupIsNil()
  luaunit.assertNil(veaf.getAvgGroupPos("no such group"))
end

-- FIX-UNGUARDED-DCS-LOOKUPS. veaf.lua carried a second `getAvgGroupPos` of its own, "stolen from Mist
-- and corrected", whose fallback kept the **string** when `Group.getByName` came back empty and then
-- called `group:getSize()` on it. It was dead -- veafGeo.lua loads right after veaf.lua everywhere and
-- assigned over it -- and it has been removed. This pins that: `veaf.getAvgGroupPos` is the geometry
-- module's implementation and nothing else, so a copy reappearing upstream fails here instead of
-- silently winning the assignment race.
function TestVeafGeoZones:test_veafGetAvgGroupPosIsTheGeoOne()
  luaunit.assertIs(veaf.getAvgGroupPos, veafGeo.getAvgGroupPos)
end

-- The behaviour the removed copy got wrong: handed the name of a group DCS does not know, it must
-- answer nil rather than call a method on the name it was given.
function TestVeafGeoZones:test_getAvgGroupPosOfAMissingGroupDoesNotRaise()
  local ok, result = pcall(veaf.getAvgGroupPos, "no such group")
  luaunit.assertTrue(ok, string.format("getAvgGroupPos raised on a group that does not exist: %s", tostring(result)))
  luaunit.assertNil(result)
end

-- ---------------------------------------------------------------------------
-- Polygons
-- ---------------------------------------------------------------------------

--- A 1000 m square, given the way the Mission Editor gives them: vec2 corners whose `y` is the
--- easting.
local SQUARE = {
  { x = 0, y = 0 },
  { x = 1000, y = 0 },
  { x = 1000, y = 1000 },
  { x = 0, y = 1000 },
}

function TestVeafGeoZones:test_aPointInsideTheSquare()
  luaunit.assertTrue(veaf.pointInPolygon({ x = 500, y = 0, z = 500 }, SQUARE))
end

function TestVeafGeoZones:test_aPointOutsideTheSquare()
  luaunit.assertFalse(veaf.pointInPolygon({ x = 1500, y = 0, z = 500 }, SQUARE))
  luaunit.assertFalse(veaf.pointInPolygon({ x = 500, y = 0, z = -10 }, SQUARE))
end

--- The polygon closes itself: a point that is only inside because of the edge joining the last
--- corner back to the first must be found.
function TestVeafGeoZones:test_thePolygonClosesItself()
  local triangle = { { x = 0, y = 0 }, { x = 1000, y = 0 }, { x = 0, y = 1000 } }
  luaunit.assertTrue(veaf.pointInPolygon({ x = 100, y = 0, z = 100 }, triangle))
  luaunit.assertFalse(veaf.pointInPolygon({ x = 900, y = 0, z = 900 }, triangle))
end

--- A concave shape is where an even-odd rule earns its place: the notch is outside even though it
--- sits between two parts of the polygon.
function TestVeafGeoZones:test_aConcavePolygon()
  local uShape = {
    { x = 0, y = 0 },
    { x = 1000, y = 0 },
    { x = 1000, y = 1000 },
    { x = 700, y = 1000 },
    { x = 700, y = 300 },
    { x = 300, y = 300 },
    { x = 300, y = 1000 },
    { x = 0, y = 1000 },
  }
  luaunit.assertTrue(veaf.pointInPolygon({ x = 500, y = 0, z = 100 }, uShape)) -- in the base
  luaunit.assertFalse(veaf.pointInPolygon({ x = 500, y = 0, z = 700 }, uShape)) -- in the notch
end

function TestVeafGeoZones:test_theAltitudeCeilingExcludesAPointAbove()
  local point = { x = 500, y = 5000, z = 500 }
  luaunit.assertTrue(veaf.pointInPolygon(point, SQUARE))
  luaunit.assertFalse(veaf.pointInPolygon(point, SQUARE, 1000))
  luaunit.assertTrue(veaf.pointInPolygon(point, SQUARE, 6000))
end

function TestVeafGeoZones:test_getUnitsInPolygonKeepsOnlyThoseInside()
  dcs_mocks.addUnit("inside", {
    getPoint = function()
      return { x = 500, y = 0, z = 500 }
    end,
  })
  dcs_mocks.addUnit("outside", {
    getPoint = function()
      return { x = 5000, y = 0, z = 5000 }
    end,
  })
  local found = veaf.getUnitsInPolygon({ "inside", "outside" }, SQUARE)
  luaunit.assertEquals(#found, 1)
  luaunit.assertEquals(found[1]:getName(), "inside")
end

--- A unit that has not been activated yet is on the map but not in play, and does not count as
--- present.
function TestVeafGeoZones:test_getUnitsInPolygonSkipsAnInactiveUnit()
  dcs_mocks.addUnit("asleep", {
    getPoint = function()
      return { x = 500, y = 0, z = 500 }
    end,
    isActive = function()
      return false
    end,
  })
  luaunit.assertEquals(#veaf.getUnitsInPolygon({ "asleep" }, SQUARE), 0)
end

function TestVeafGeoZones:test_getUnitsInPolygonIgnoresNamesThatDoNotResolve()
  luaunit.assertEquals(#veaf.getUnitsInPolygon({ "ghost" }, SQUARE), 0)
end

-- ---------------------------------------------------------------------------
-- Run
-- ---------------------------------------------------------------------------
os.exit(luaunit.LuaUnit.run())
