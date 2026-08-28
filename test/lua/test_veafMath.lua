--- Unit tests for veafMath.lua — the arithmetic, vectors and unit conversions ported off MiST.
---
--- Run:  lua test/lua/test_veafMath.lua
---
--- Covers:
---   - The five unit conversions, both ways where MiST offered both
---   - vecAdd, vecScalarMult, vecMag, including a zero vector and a negative multiplier
---   - get2DDist ignores altitude, is symmetric, and answers zero for a point to itself
---   - makeVec3 / makeVec2 against a known triplet, in both coordinate conventions
---   - getDir with and without a reference point, and its wrap into [0, 2pi)
---   - getNorthCorrection over the native coord.* calls
---   - deepCopy: nesting, independence from the original, a self-referencing table, metatables

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

TestVeafMath = {}

function TestVeafMath:setUp()
  dcs_mocks.reset()
end

-- ---------------------------------------------------------------------------
-- Unit conversions
-- ---------------------------------------------------------------------------

function TestVeafMath:test_metersToNM()
  luaunit.assertAlmostEquals(veaf.metersToNM(1852), 1, 1e-9)
  luaunit.assertAlmostEquals(veaf.metersToNM(0), 0, 1e-9)
end

function TestVeafMath:test_NMToMeters()
  luaunit.assertAlmostEquals(veaf.NMToMeters(1), 1852, 1e-9)
end

function TestVeafMath:test_nauticalMilesRoundTrip()
  luaunit.assertAlmostEquals(veaf.metersToNM(veaf.NMToMeters(7.5)), 7.5, 1e-9)
end

function TestVeafMath:test_metersToFeet()
  luaunit.assertAlmostEquals(veaf.metersToFeet(0.3048), 1, 1e-9)
  luaunit.assertAlmostEquals(veaf.metersToFeet(3048), 10000, 1e-6)
end

function TestVeafMath:test_feetToMeters()
  luaunit.assertAlmostEquals(veaf.feetToMeters(1), 0.3048, 1e-9)
end

function TestVeafMath:test_feetRoundTrip()
  luaunit.assertAlmostEquals(veaf.feetToMeters(veaf.metersToFeet(1234.5)), 1234.5, 1e-6)
end

function TestVeafMath:test_mpsToKnots()
  luaunit.assertAlmostEquals(veaf.mpsToKnots(1852 / 3600), 1, 1e-9)
  luaunit.assertAlmostEquals(veaf.mpsToKnots(0), 0, 1e-9)
end

function TestVeafMath:test_conversionsAcceptNegatives()
  -- A rate of climb is a signed number; nothing here may clamp.
  luaunit.assertAlmostEquals(veaf.metersToFeet(-100), -328.0839895, 1e-6)
end

-- ---------------------------------------------------------------------------
-- Vectors
-- ---------------------------------------------------------------------------

function TestVeafMath:test_vecAdd()
  local sum = veaf.vecAdd({ x = 1, y = 2, z = 3 }, { x = 10, y = 20, z = 30 })
  luaunit.assertEquals(sum, { x = 11, y = 22, z = 33 })
end

function TestVeafMath:test_vecAddDoesNotMutateItsArguments()
  local a = { x = 1, y = 2, z = 3 }
  local b = { x = 1, y = 1, z = 1 }
  veaf.vecAdd(a, b)
  luaunit.assertEquals(a, { x = 1, y = 2, z = 3 })
  luaunit.assertEquals(b, { x = 1, y = 1, z = 1 })
end

function TestVeafMath:test_vecScalarMult()
  luaunit.assertEquals(veaf.vecScalarMult({ x = 1, y = 2, z = 3 }, 2), { x = 2, y = 4, z = 6 })
end

function TestVeafMath:test_vecScalarMultByZeroAndNegative()
  luaunit.assertEquals(veaf.vecScalarMult({ x = 1, y = 2, z = 3 }, 0), { x = 0, y = 0, z = 0 })
  luaunit.assertEquals(veaf.vecScalarMult({ x = 1, y = -2, z = 3 }, -1), { x = -1, y = 2, z = -3 })
end

function TestVeafMath:test_vecMag()
  luaunit.assertAlmostEquals(veaf.vecMag({ x = 3, y = 0, z = 4 }), 5, 1e-9)
  luaunit.assertAlmostEquals(veaf.vecMag({ x = 1, y = 2, z = 2 }), 3, 1e-9)
end

function TestVeafMath:test_vecMagOfZeroVector()
  luaunit.assertAlmostEquals(veaf.vecMag({ x = 0, y = 0, z = 0 }), 0, 1e-9)
end

function TestVeafMath:test_vecMagIgnoresSign()
  luaunit.assertAlmostEquals(veaf.vecMag({ x = -3, y = 0, z = -4 }), 5, 1e-9)
end

-- ---------------------------------------------------------------------------
-- Distance
-- ---------------------------------------------------------------------------

--- A 3-4-5 triangle laid out on the ground, with the two points at wildly different altitudes:
--- a 2D distance that noticed `y` would answer something else.
function TestVeafMath:test_get2DDistIgnoresAltitude()
  local a = { x = 0, y = 0, z = 0 }
  local b = { x = 3, y = 10000, z = 4 }
  luaunit.assertAlmostEquals(veaf.get2DDist(a, b), 5, 1e-9)
end

function TestVeafMath:test_get2DDistIsSymmetric()
  local a = { x = 100, y = 5, z = 200 }
  local b = { x = -50, y = 900, z = 80 }
  luaunit.assertAlmostEquals(veaf.get2DDist(a, b), veaf.get2DDist(b, a), 1e-9)
end

function TestVeafMath:test_get2DDistToItselfIsZero()
  local a = { x = 42, y = 7, z = -13 }
  luaunit.assertAlmostEquals(veaf.get2DDist(a, a), 0, 1e-9)
end

--- Mission-table points are `{ x, y }` with `y` as the easting, and `get2DDist` is handed both shapes
--- across the code base — a vec2 must be read as a ground position, not as x plus an altitude.
function TestVeafMath:test_get2DDistAcceptsAMissionTableVec2()
  luaunit.assertAlmostEquals(veaf.get2DDist({ x = 0, y = 0 }, { x = 3, y = 4 }), 5, 1e-9)
end

-- ---------------------------------------------------------------------------
-- Coordinate shapes — see docs/agents/dcs-coordinates.md
-- ---------------------------------------------------------------------------

--- A mission-table vec2 is `{ x = northing, y = easting }`; a runtime vec3 is
--- `{ x = northing, y = altitude, z = easting }`. So the easting must move from `y` to `z`, and the
--- altitude comes from the second argument. Getting this backwards raises no error, only a position
--- a hundred kilometres away.
function TestVeafMath:test_makeVec3MovesTheEastingFromYToZ()
  local vec3 = veaf.makeVec3({ x = 1000, y = 2000 }, 300)
  luaunit.assertEquals(vec3, { x = 1000, y = 300, z = 2000 })
end

function TestVeafMath:test_makeVec3DefaultsAltitudeToZero()
  luaunit.assertEquals(veaf.makeVec3({ x = 1000, y = 2000 }), { x = 1000, y = 0, z = 2000 })
end

--- A point carrying `alt` supplies the altitude when the caller passes none, which is how a named
--- point or a mission record reaches a spawn.
function TestVeafMath:test_makeVec3ReadsAltFromThePoint()
  luaunit.assertEquals(veaf.makeVec3({ x = 1, y = 2, alt = 55 }), { x = 1, y = 55, z = 2 })
end

function TestVeafMath:test_makeVec3PrefersAnExplicitAltitudeOverAlt()
  luaunit.assertEquals(veaf.makeVec3({ x = 1, y = 2, alt = 55 }, 900), { x = 1, y = 900, z = 2 })
end

function TestVeafMath:test_makeVec3OnAVec3IsACopy()
  local original = { x = 1, y = 2, z = 3 }
  local copy = veaf.makeVec3(original)
  luaunit.assertEquals(copy, { x = 1, y = 2, z = 3 })
  copy.x = 99
  luaunit.assertEquals(original.x, 1) -- a fresh table, not the same one
end

function TestVeafMath:test_makeVec2MovesTheEastingFromZToY()
  luaunit.assertEquals(veaf.makeVec2({ x = 1000, y = 300, z = 2000 }), { x = 1000, y = 2000 })
end

function TestVeafMath:test_makeVec2OnAVec2IsACopy()
  local original = { x = 1, y = 2 }
  local copy = veaf.makeVec2(original)
  luaunit.assertEquals(copy, { x = 1, y = 2 })
  copy.y = 99
  luaunit.assertEquals(original.y, 2)
end

-- ---------------------------------------------------------------------------
-- Direction
-- ---------------------------------------------------------------------------

--- `x` is the northing and `z` the easting, so a vector pointing due east is a quarter turn.
function TestVeafMath:test_getDirOfDueEast()
  luaunit.assertAlmostEquals(veaf.getDir({ x = 0, y = 0, z = 1 }), math.pi / 2, 1e-9)
end

function TestVeafMath:test_getDirOfDueNorth()
  luaunit.assertAlmostEquals(veaf.getDir({ x = 1, y = 0, z = 0 }), 0, 1e-9)
end

--- atan2 answers a negative angle for a westerly vector; the result is wrapped into [0, 2pi) so
--- callers can convert straight to a 0-359 heading.
function TestVeafMath:test_getDirWrapsNegativeAnglesIntoTheFullTurn()
  local dir = veaf.getDir({ x = 0, y = 0, z = -1 })
  luaunit.assertAlmostEquals(dir, 3 * math.pi / 2, 1e-9)
  luaunit.assertTrue(dir >= 0 and dir < 2 * math.pi)
end

function TestVeafMath:test_getDirWithAReferencePointAddsTheNorthCorrection()
  -- A point far from the origin, so the correction is not zero and the assertion can actually fail
  -- if the reference point is ignored.
  local point = { x = 1000, y = 0, z = 2000 }
  local correction = veaf.getNorthCorrection(point)
  luaunit.assertTrue(math.abs(correction) > 1e-6)

  local without = veaf.getDir({ x = 0, y = 0, z = 1 })
  local with = veaf.getDir({ x = 0, y = 0, z = 1 }, point)

  local expected = without + correction
  if expected < 0 then
    expected = expected + 2 * math.pi
  end
  luaunit.assertAlmostEquals(with, expected, 1e-9)
end

function TestVeafMath:test_getNorthCorrectionAcceptsAMissionTableVec2()
  -- It must not read the easting as an altitude: both shapes answer the same correction.
  local fromVec2 = veaf.getNorthCorrection({ x = 1000, y = 2000 })
  local fromVec3 = veaf.getNorthCorrection({ x = 1000, y = 0, z = 2000 })
  luaunit.assertAlmostEquals(fromVec2, fromVec3, 1e-9)
end

function TestVeafMath:test_getNorthCorrectionDoesNotMutateItsArgument()
  local point = { x = 1000, y = 2000 }
  veaf.getNorthCorrection(point)
  luaunit.assertEquals(point, { x = 1000, y = 2000 })
end

-- ---------------------------------------------------------------------------
-- deepCopy
-- ---------------------------------------------------------------------------

function TestVeafMath:test_deepCopyOfANestedTable()
  local original = { a = 1, b = { c = 2, d = { e = 3 } }, [1] = "one" }
  local copy = veaf.deepCopy(original)
  luaunit.assertEquals(copy, original)
end

function TestVeafMath:test_deepCopyIsIndependentOfTheOriginal()
  local original = { outer = { inner = { value = 1 } } }
  local copy = veaf.deepCopy(original)
  copy.outer.inner.value = 99
  luaunit.assertEquals(original.outer.inner.value, 1)
end

function TestVeafMath:test_deepCopyOfANonTableIsTheValue()
  luaunit.assertEquals(veaf.deepCopy(42), 42)
  luaunit.assertEquals(veaf.deepCopy("text"), "text")
  luaunit.assertNil(veaf.deepCopy(nil))
end

--- A group's route table can reference its own group, and MiST's copy survived that. Ours must too,
--- or the first cycle is an infinite recursion.
function TestVeafMath:test_deepCopyOfASelfReferencingTable()
  local original = { name = "loop" }
  original.self = original
  local copy = veaf.deepCopy(original)
  luaunit.assertEquals(copy.name, "loop")
  luaunit.assertIs(copy.self, copy) -- the cycle points at the copy, not at the original
  luaunit.assertNotIs(copy.self, original)
end

function TestVeafMath:test_deepCopyKeepsSharingShared()
  local shared = { value = 1 }
  local original = { first = shared, second = shared }
  local copy = veaf.deepCopy(original)
  luaunit.assertIs(copy.first, copy.second) -- one table copied once, not twice
end

function TestVeafMath:test_deepCopyCarriesTheMetatable()
  local meta = { __index = { inherited = "yes" } }
  local original = setmetatable({ own = 1 }, meta)
  local copy = veaf.deepCopy(original)
  luaunit.assertEquals(copy.own, 1)
  luaunit.assertEquals(copy.inherited, "yes")
  luaunit.assertIs(getmetatable(copy), meta)
end

function TestVeafMath:test_deepCopyCopiesTableKeysToo()
  local key = { id = "k" }
  local original = { [key] = "value" }
  local copy = veaf.deepCopy(original)
  luaunit.assertNil(copy[key]) -- the key was copied, so the original key no longer indexes it
  local copiedKey = next(copy)
  luaunit.assertEquals(copiedKey.id, "k")
  luaunit.assertEquals(copy[copiedKey], "value")
end

-- ---------------------------------------------------------------------------
-- Run
-- ---------------------------------------------------------------------------
os.exit(luaunit.LuaUnit.run())
