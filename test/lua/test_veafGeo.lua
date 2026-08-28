--- Unit tests for veafGeo.lua — the coordinate output ported off MiST.
---
--- Run:  lua test/lua/test_veafGeo.lua
---
--- Every expectation here is a **literal string**, and every one was produced by running MiST's own
--- `tostringLL` / `tostringMGRS` before the port. These strings reach pilots in F10 reports and
--- briefings that mission makers have been reading for years, so the port is not allowed to improve
--- them — including where MiST is visibly wrong (see the carry tests below).
---
--- Covers:
---   - Decimal minutes at the three precisions the code base uses (0, 2, 3)
---   - Degrees/minutes/seconds at precision 0 and 2
---   - Both hemispheres, either side of the prime meridian, and a three-digit longitude
---   - The hemisphere letters exactly at zero
---   - The minute carry in decimal mode, and its absence in DMS mode — MiST's own asymmetry
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

--- Exactly zero reads as **S** and **W**, because the hemisphere test is `> 0`. Almost certainly not
--- what MiST intended, and pinned here so the port does not quietly "fix" it.
function TestVeafGeo:test_zeroReadsAsSouthAndWest()
  luaunit.assertEquals(veaf.toStringLL(0, 0, 2), "00 00.00'S\t 00 00.00'W")
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

--- In DMS mode it does **not**. Seconds rounding to 60 carry into the minute, and a minute reaching
--- 60 is printed as-is: `41 60' 00"N` where the decimal branch would say `42 00'`.
---
--- This is a defect in MiST, not in the port — the decimal branch three lines away does the carry, so
--- the omission is an oversight rather than a convention. It is reproduced here on purpose: this lot
--- removes a dependency and must not change what a pilot reads. Fixing it is a lot of its own, and
--- this test is what will have to be updated deliberately when that happens.
function TestVeafGeo:test_dmsMinutesDoNotCarryIntoTheDegree()
  luaunit.assertEquals(veaf.toStringLL(41.99999444, 43.0, 0, true), "41 60' 00\"N\t 43 00' 00\"E")
end

--- The same position at precision 2 stays below the boundary, which is why the defect is rare: it
--- needs the rounding to land exactly on a whole minute.
function TestVeafGeo:test_theSamePositionAtPrecision2StaysBelowTheBoundary()
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
-- Run
-- ---------------------------------------------------------------------------
os.exit(luaunit.LuaUnit.run())
