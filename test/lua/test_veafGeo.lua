--- Unit tests for veafGeo.lua — the coordinate output ported off MiST.
---
--- Run:  lua test/lua/test_veafGeo.lua
---
--- Every expectation here is a **literal string**, and every one was produced by running MiST's own
--- `tostringLL` / `tostringMGRS` before the port. These strings reach pilots in F10 reports and
--- briefings that mission makers have been reading for years, so the port was not allowed to improve
--- them. Where MiST was visibly wrong, correcting it is a decision of its own: FIX-DMS-MINUTE-CARRY
--- fixed the minute-to-degree carry, and the hemisphere letter at exactly zero is still MiST's.
---
--- Covers:
---   - Decimal minutes at the three precisions the code base uses (0, 2, 3)
---   - Degrees/minutes/seconds at precision 0 and 2
---   - Both hemispheres, either side of the prime meridian, and a three-digit longitude
---   - The hemisphere letters exactly at zero
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
-- Run
-- ---------------------------------------------------------------------------
os.exit(luaunit.LuaUnit.run())
