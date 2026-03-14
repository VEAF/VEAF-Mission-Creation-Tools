--- Unit tests for veaf.lua utility functions.
---
--- Run:  lua test/lua/test_veaf.lua
---
--- Covers (pure / near-pure functions only — no DCS state required):
---   round, trim, split, splitWithPattern, breakString,
---   isNullOrEmpty, tableContains, length, arrayRemoveWhen,
---   escapeRegex, vecToString, invertHeading, laserCodeToDigit,
---   startsWith, safeUnpack, getMagneticDeclination,
---   getRandomizableNumeric_norandom, getRandomizableNumeric_random,
---   ifnn, ifnns

-- ---------------------------------------------------------------------------
-- Bootstrap
-- ---------------------------------------------------------------------------
local _base = debug.getinfo(1, "S").source:match("^@(.+)[\\/]") or "."
luaunit = dofile(_base .. "/luaunit.lua")
dofile(_base .. "/dcs_mocks.lua")
dofile(_base .. "/../../src/scripts/veaf/veaf.lua")

-- ---------------------------------------------------------------------------
-- Helper
-- ---------------------------------------------------------------------------
local function assertTableEquals(actual, expected, msg)
  luaunit.assertEquals(#actual, #expected, (msg or "") .. " (length mismatch)")
  for i, v in ipairs(expected) do
    luaunit.assertEquals(actual[i], v, (msg or "") .. " [" .. i .. "]")
  end
end

-- ===========================================================================
-- veaf.round
-- ===========================================================================
TestVeafRound = {}

function TestVeafRound:test_roundToInteger()
  luaunit.assertEquals(veaf.round(3.7), 4)
  luaunit.assertEquals(veaf.round(3.4), 3)
end

function TestVeafRound:test_roundHalfUp()
  luaunit.assertEquals(veaf.round(3.5), 4)
  luaunit.assertEquals(veaf.round(2.5), 3)
end

function TestVeafRound:test_roundDecimalPlaces()
  luaunit.assertEquals(veaf.round(3.14159, 2), 3.14)
  luaunit.assertEquals(veaf.round(3.14559, 2), 3.15)
  luaunit.assertEquals(veaf.round(3.14159, 4), 3.1416)
end

function TestVeafRound:test_roundNegative()
  luaunit.assertEquals(veaf.round(-2.5), -2)
  luaunit.assertEquals(veaf.round(-3.7), -4)
end

function TestVeafRound:test_roundInteger()
  luaunit.assertEquals(veaf.round(5), 5)
  luaunit.assertEquals(veaf.round(5, 0), 5)
end

-- ===========================================================================
-- veaf.trim
-- ===========================================================================
TestVeafTrim = {}

function TestVeafTrim:test_trimLeadingAndTrailing()
  luaunit.assertEquals(veaf.trim("  hello  "), "hello")
end

function TestVeafTrim:test_trimLeadingOnly()
  luaunit.assertEquals(veaf.trim("   hello"), "hello")
end

function TestVeafTrim:test_trimTrailingOnly()
  luaunit.assertEquals(veaf.trim("hello   "), "hello")
end

function TestVeafTrim:test_trimNoSpaces()
  luaunit.assertEquals(veaf.trim("hello"), "hello")
end

function TestVeafTrim:test_trimOnlySpaces()
  luaunit.assertEquals(veaf.trim("   "), "")
end

function TestVeafTrim:test_trimEmpty()
  luaunit.assertEquals(veaf.trim(""), "")
end

function TestVeafTrim:test_trimTabs()
  luaunit.assertEquals(veaf.trim("\thello\t"), "hello")
end

function TestVeafTrim:test_trimPreservesInternalSpaces()
  luaunit.assertEquals(veaf.trim("  hello world  "), "hello world")
end

-- ===========================================================================
-- veaf.split
-- ===========================================================================
TestVeafSplit = {}

function TestVeafSplit:test_splitBasic()
  assertTableEquals(veaf.split("a,b,c", ","), { "a", "b", "c" })
end

function TestVeafSplit:test_splitSingle()
  assertTableEquals(veaf.split("one", ","), { "one" })
end

function TestVeafSplit:test_splitEmpty()
  assertTableEquals(veaf.split("", ","), {})
end

function TestVeafSplit:test_splitConsecutiveSepsAreSkipped()
  -- veaf.split skips empty tokens between consecutive separators
  assertTableEquals(veaf.split("a,,b", ","), { "a", "b" })
end

-- ===========================================================================
-- veaf.splitWithPattern
-- ===========================================================================
TestVeafSplitWithPattern = {}

function TestVeafSplitWithPattern:test_basicSplit()
  assertTableEquals(veaf.splitWithPattern("a:b:c", ":"), { "a", "b", "c" })
end

function TestVeafSplitWithPattern:test_multiCharPattern()
  -- split on one-or-more colons
  assertTableEquals(veaf.splitWithPattern("a::b:::c", ":+"), { "a", "b", "c" })
end

function TestVeafSplitWithPattern:test_splitPreservesNumbers()
  local result = veaf.splitWithPattern("42:23:45", ":")
  luaunit.assertEquals(result[1], "42")
  luaunit.assertEquals(result[2], "23")
  luaunit.assertEquals(result[3], "45")
end

function TestVeafSplitWithPattern:test_singleToken()
  assertTableEquals(veaf.splitWithPattern("hello", ":"), { "hello" })
end

-- ===========================================================================
-- veaf.breakString
-- ===========================================================================
TestVeafBreakString = {}

function TestVeafBreakString:test_breakAtSeparator()
  local result = veaf.breakString("key=value", "=")
  luaunit.assertEquals(result[1], "key")
  luaunit.assertEquals(result[2], "value")
end

function TestVeafBreakString:test_noSeparatorReturnsWholeString()
  local result = veaf.breakString("noequal", "=")
  luaunit.assertEquals(result[1], "noequal")
  luaunit.assertNil(result[2])
end

function TestVeafBreakString:test_onlyFirstSeparatorUsed()
  -- everything after the first separator goes into [2]
  local result = veaf.breakString("key=val=extra", "=")
  luaunit.assertEquals(result[1], "key")
  luaunit.assertEquals(result[2], "val=extra")
end

-- ===========================================================================
-- veaf.isNullOrEmpty
-- ===========================================================================
TestVeafIsNullOrEmpty = {}

function TestVeafIsNullOrEmpty:test_nilIsEmpty()
  luaunit.assertTrue(veaf.isNullOrEmpty(nil))
end

function TestVeafIsNullOrEmpty:test_emptyStringIsEmpty()
  luaunit.assertTrue(veaf.isNullOrEmpty(""))
end

function TestVeafIsNullOrEmpty:test_nonEmptyStringIsNotEmpty()
  luaunit.assertFalse(veaf.isNullOrEmpty("hello"))
  luaunit.assertFalse(veaf.isNullOrEmpty(" "))
end

function TestVeafIsNullOrEmpty:test_numberIsNotEmpty()
  luaunit.assertFalse(veaf.isNullOrEmpty(0))
  luaunit.assertFalse(veaf.isNullOrEmpty(42))
end

function TestVeafIsNullOrEmpty:test_tableIsNotEmpty()
  luaunit.assertFalse(veaf.isNullOrEmpty({}))
end

-- ===========================================================================
-- veaf.tableContains
-- ===========================================================================
TestVeafTableContains = {}

function TestVeafTableContains:test_containsElement()
  luaunit.assertTrue(veaf.tableContains({ "a", "b", "c" }, "b"))
end

function TestVeafTableContains:test_doesNotContainElement()
  luaunit.assertFalse(veaf.tableContains({ "a", "b", "c" }, "z"))
end

function TestVeafTableContains:test_nilTableReturnsFalse()
  luaunit.assertFalse(veaf.tableContains(nil, "b"))
end

function TestVeafTableContains:test_nilElementReturnsFalse()
  luaunit.assertFalse(veaf.tableContains({ "a", "b" }, nil))
end

function TestVeafTableContains:test_worksWithHashTable()
  luaunit.assertTrue(veaf.tableContains({ x = 1, y = 2 }, 1))
  luaunit.assertFalse(veaf.tableContains({ x = 1, y = 2 }, 3))
end

-- ===========================================================================
-- veaf.length
-- ===========================================================================
TestVeafLength = {}

function TestVeafLength:test_emptyTableReturnsZero()
  luaunit.assertEquals(veaf.length({}), 0)
end

function TestVeafLength:test_arrayLength()
  luaunit.assertEquals(veaf.length({ "a", "b", "c" }), 3)
end

function TestVeafLength:test_hashTableLength()
  luaunit.assertEquals(veaf.length({ x = 1, y = 2, z = 3 }), 3)
end

function TestVeafLength:test_nilReturnsZero()
  luaunit.assertEquals(veaf.length(nil), 0)
end

-- ===========================================================================
-- veaf.arrayRemoveWhen
-- ===========================================================================
TestVeafArrayRemoveWhen = {}

function TestVeafArrayRemoveWhen:test_removeNothingReturnsFalse()
  local t = { 1, 2, 3 }
  local changed = veaf.arrayRemoveWhen(t, function(_, _, _) return true end)
  luaunit.assertFalse(changed)
  luaunit.assertEquals(#t, 3)
end

function TestVeafArrayRemoveWhen:test_removeAllReturnsTrue()
  local t = { 1, 2, 3 }
  local changed = veaf.arrayRemoveWhen(t, function(_, _, _) return false end)
  luaunit.assertTrue(changed)
  luaunit.assertEquals(#t, 0)
end

function TestVeafArrayRemoveWhen:test_removeEvenNumbers()
  local t = { 1, 2, 3, 4, 5 }
  veaf.arrayRemoveWhen(t, function(tbl, i, _)
    return tbl[i] % 2 ~= 0
  end)
  assertTableEquals(t, { 1, 3, 5 })
end

-- ===========================================================================
-- veaf.escapeRegex
-- ===========================================================================
TestVeafEscapeRegex = {}

function TestVeafEscapeRegex:test_noSpecialChars()
  luaunit.assertEquals(veaf.escapeRegex("hello"), "hello")
end

function TestVeafEscapeRegex:test_escapeDot()
  luaunit.assertEquals(veaf.escapeRegex("a.b"), "a%.b")
end

function TestVeafEscapeRegex:test_escapePlus()
  luaunit.assertEquals(veaf.escapeRegex("a+b"), "a%+b")
end

function TestVeafEscapeRegex:test_escapeStar()
  luaunit.assertEquals(veaf.escapeRegex("a*b"), "a%*b")
end

function TestVeafEscapeRegex:test_escapeDollar()
  luaunit.assertEquals(veaf.escapeRegex("end$"), "end%$")
end

function TestVeafEscapeRegex:test_escapeParens()
  luaunit.assertEquals(veaf.escapeRegex("f(x)"), "f%(x%)")
end

function TestVeafEscapeRegex:test_nilReturnsEmpty()
  luaunit.assertEquals(veaf.escapeRegex(nil), "")
end

function TestVeafEscapeRegex:test_escapedStringWorksInPattern()
  -- The escaped string should be usable as a literal Lua pattern.
  local raw = "1.0.0"
  local escaped = veaf.escapeRegex(raw)
  local str = "version 1.0.0 release"
  luaunit.assertNotNil(str:find(escaped))
  -- Make sure dots are not treated as wildcards: "1X0Y0" must NOT match.
  luaunit.assertNil(("1X0Y0"):find(escaped))
end

-- ===========================================================================
-- veaf.invertHeading
-- ===========================================================================
TestVeafInvertHeading = {}

function TestVeafInvertHeading:test_north()
  -- Reciprocal of 0° is 180°
  luaunit.assertEquals(veaf.invertHeading(0), 180)
end

function TestVeafInvertHeading:test_east()
  luaunit.assertEquals(veaf.invertHeading(90), 270)
end

function TestVeafInvertHeading:test_south()
  -- Reciprocal of 180° is 360 (same as 0°; function returns 360 by design)
  luaunit.assertEquals(veaf.invertHeading(180), 360)
end

function TestVeafInvertHeading:test_west()
  luaunit.assertEquals(veaf.invertHeading(270), 90)
end

function TestVeafInvertHeading:test_360()
  luaunit.assertEquals(veaf.invertHeading(360), 180)
end

function TestVeafInvertHeading:test_arbitrary()
  luaunit.assertEquals(veaf.invertHeading(45), 225)
  luaunit.assertEquals(veaf.invertHeading(225), 45)
end

-- ===========================================================================
-- veaf.laserCodeToDigit
-- ===========================================================================
TestVeafLaserCodeToDigit = {}

function TestVeafLaserCodeToDigit:test_1688()
  local d = veaf.laserCodeToDigit(1688)
  luaunit.assertEquals(d.thousands, 1)
  luaunit.assertEquals(d.hundreds, 6)
  luaunit.assertEquals(d.tens, 8)
  luaunit.assertEquals(d.units, 8)
end

function TestVeafLaserCodeToDigit:test_1111()
  local d = veaf.laserCodeToDigit(1111)
  luaunit.assertEquals(d.thousands, 1)
  luaunit.assertEquals(d.hundreds, 1)
  luaunit.assertEquals(d.tens, 1)
  luaunit.assertEquals(d.units, 1)
end

function TestVeafLaserCodeToDigit:test_1000()
  local d = veaf.laserCodeToDigit(1000)
  luaunit.assertEquals(d.thousands, 1)
  luaunit.assertEquals(d.hundreds, 0)
  luaunit.assertEquals(d.tens, 0)
  luaunit.assertEquals(d.units, 0)
end

function TestVeafLaserCodeToDigit:test_sumReconstitutesCode()
  local code = 1337
  local d = veaf.laserCodeToDigit(code)
  local reconstructed = d.thousands * 1000 + d.hundreds * 100 + d.tens * 10 + d.units
  luaunit.assertEquals(reconstructed, code)
end

-- ===========================================================================
-- veaf.startsWith
-- ===========================================================================
TestVeafStartsWith = {}

function TestVeafStartsWith:test_basicMatch()
  luaunit.assertTrue(veaf.startsWith("Hello World", "Hello"))
end

function TestVeafStartsWith:test_caseInsensitiveByDefault()
  luaunit.assertTrue(veaf.startsWith("Hello World", "hello"))
  luaunit.assertTrue(veaf.startsWith("hello world", "HELLO"))
end

function TestVeafStartsWith:test_caseSensitiveMatch()
  luaunit.assertTrue(veaf.startsWith("Hello World", "Hello", true))
end

function TestVeafStartsWith:test_caseSensitiveNoMatch()
  luaunit.assertFalse(veaf.startsWith("Hello World", "hello", true))
end

function TestVeafStartsWith:test_noMatch()
  luaunit.assertFalse(veaf.startsWith("Hello World", "World"))
end

function TestVeafStartsWith:test_emptyPrefix()
  luaunit.assertTrue(veaf.startsWith("Hello", ""))
end

function TestVeafStartsWith:test_nilStringReturnsFalse()
  luaunit.assertFalse(veaf.startsWith(nil, "Hello"))
end

function TestVeafStartsWith:test_nilPrefixReturnsFalse()
  luaunit.assertFalse(veaf.startsWith("Hello", nil))
end

-- ===========================================================================
-- veaf.safeUnpack
-- ===========================================================================
TestVeafSafeUnpack = {}

function TestVeafSafeUnpack:test_unpacksTable()
  local a, b, c = veaf.safeUnpack({ 10, 20, 30 })
  luaunit.assertEquals(a, 10)
  luaunit.assertEquals(b, 20)
  luaunit.assertEquals(c, 30)
end

function TestVeafSafeUnpack:test_nonTableReturnedAsIs()
  local v = veaf.safeUnpack(42)
  luaunit.assertEquals(v, 42)
end

function TestVeafSafeUnpack:test_stringReturnedAsIs()
  local v = veaf.safeUnpack("hello")
  luaunit.assertEquals(v, "hello")
end

-- ===========================================================================
-- veaf.vecToString
-- ===========================================================================
TestVeafVecToString = {}

function TestVeafVecToString:test_fullVec3()
  local s = veaf.vecToString({ x = 1, y = 2, z = 3 })
  luaunit.assertStrContains(s, "x=1.0")
  luaunit.assertStrContains(s, "y=2.0")
  luaunit.assertStrContains(s, "z=3.0")
end

function TestVeafVecToString:test_partialVec()
  local s = veaf.vecToString({ x = 5, z = 7 })
  luaunit.assertStrContains(s, "x=5.0")
  luaunit.assertStrContains(s, "z=7.0")
  luaunit.assertNotStrContains(s, "y=")
end

function TestVeafVecToString:test_emptyVec()
  local s = veaf.vecToString({})
  luaunit.assertEquals(s, "")
end

-- ===========================================================================
-- veaf.getMagneticDeclination
-- ===========================================================================
TestVeafMagneticDeclination = {}

function TestVeafMagneticDeclination:test_caucasus()
  env.mission.theatre = "Caucasus"
  luaunit.assertEquals(veaf.getMagneticDeclination(), 6)
end

function TestVeafMagneticDeclination:test_persianGulf()
  env.mission.theatre = "PersianGulf"
  luaunit.assertEquals(veaf.getMagneticDeclination(), 2)
end

function TestVeafMagneticDeclination:test_nevada()
  env.mission.theatre = "Nevada"
  luaunit.assertEquals(veaf.getMagneticDeclination(), 12)
end

function TestVeafMagneticDeclination:test_normandy()
  env.mission.theatre = "Normandy"
  luaunit.assertEquals(veaf.getMagneticDeclination(), -10)
end

function TestVeafMagneticDeclination:test_unknownTheatreReturnsZero()
  env.mission.theatre = "Unknown_Theatre"
  luaunit.assertEquals(veaf.getMagneticDeclination(), 0)
end

function TestVeafMagneticDeclination:tearDown()
  env.mission.theatre = "Caucasus" -- restore default mock value
end

-- ===========================================================================
-- veaf.getRandomizableNumeric_norandom  (deterministic mid-point table)
-- ===========================================================================
TestVeafGetRandomizableNumericNorandom = {}

function TestVeafGetRandomizableNumericNorandom:test_plainNumber()
  luaunit.assertEquals(veaf.getRandomizableNumeric_norandom("42"), 42)
  luaunit.assertEquals(veaf.getRandomizableNumeric_norandom("0"), 0)
end

function TestVeafGetRandomizableNumericNorandom:test_knownRanges()
  luaunit.assertEquals(veaf.getRandomizableNumeric_norandom("1-5"), 3)
  luaunit.assertEquals(veaf.getRandomizableNumeric_norandom("5-10"), 7)
  luaunit.assertEquals(veaf.getRandomizableNumeric_norandom("10-15"), 12)
  luaunit.assertEquals(veaf.getRandomizableNumeric_norandom("1-2"), 2)
  luaunit.assertEquals(veaf.getRandomizableNumeric_norandom("4-5"), 4)
end

function TestVeafGetRandomizableNumericNorandom:test_unknownRangeReturnsNil()
  luaunit.assertNil(veaf.getRandomizableNumeric_norandom("1-7"))
  luaunit.assertNil(veaf.getRandomizableNumeric_norandom("0-100"))
end

-- ===========================================================================
-- veaf.getRandomizableNumeric_random  (stochastic — tests bounds only)
-- ===========================================================================
TestVeafGetRandomizableNumericRandom = {}

function TestVeafGetRandomizableNumericRandom:test_plainNumberIsReturnedAsIs()
  luaunit.assertEquals(veaf.getRandomizableNumeric_random("7"), 7)
  luaunit.assertEquals(veaf.getRandomizableNumeric_random("0"), 0)
end

function TestVeafGetRandomizableNumericRandom:test_rangeBoundsAreRespected()
  -- Run many times and make sure every result is within [1,5].
  for _ = 1, 20 do
    local v = veaf.getRandomizableNumeric_random("1-5")
    luaunit.assertNotNil(v)
    luaunit.assertTrue(v >= 1 and v <= 5, "value " .. tostring(v) .. " out of [1,5]")
  end
end

function TestVeafGetRandomizableNumericRandom:test_rangeUpperBound()
  for _ = 1, 20 do
    local v = veaf.getRandomizableNumeric_random("10-20")
    luaunit.assertTrue(v >= 10 and v <= 20)
  end
end

-- ===========================================================================
-- veaf.ifnn (safe field accessor)
-- ===========================================================================
TestVeafIfnn = {}

function TestVeafIfnn:test_nilObjectReturnsNil()
  luaunit.assertNil(veaf.ifnn(nil, "field"))
end

function TestVeafIfnn:test_missingFieldReturnsNil()
  luaunit.assertNil(veaf.ifnn({}, "missing"))
end

function TestVeafIfnn:test_plainField()
  luaunit.assertEquals(veaf.ifnn({ x = 42 }, "x"), 42)
end

function TestVeafIfnn:test_functionField()
  local obj = {}
  function obj:getName() return "test" end
  luaunit.assertEquals(veaf.ifnn(obj, "getName"), "test")
end

function TestVeafIfnn:test_erroringFunctionReturnsNil()
  local obj = {}
  function obj:broken() error("oops") end
  luaunit.assertNil(veaf.ifnn(obj, "broken"))
end

-- ===========================================================================
-- veaf.ifnns (safe multi-field accessor)
-- ===========================================================================
TestVeafIfnns = {}

function TestVeafIfnns:test_nilObjectReturnsNil()
  luaunit.assertNil(veaf.ifnns(nil, { "a", "b" }))
end

function TestVeafIfnns:test_extractsExistingFields()
  local result = veaf.ifnns({ x = 1, y = 2, z = 3 }, { "x", "z" })
  luaunit.assertNotNil(result)
  luaunit.assertEquals(result.x, 1)
  luaunit.assertEquals(result.z, 3)
  luaunit.assertNil(result.y) -- not requested
end

function TestVeafIfnns:test_singleFieldAsString()
  local result = veaf.ifnns({ name = "alpha" }, "name")
  luaunit.assertNotNil(result)
  luaunit.assertEquals(result.name, "alpha")
end

function TestVeafIfnns:test_missingFieldsAreOmitted()
  local result = veaf.ifnns({ x = 10 }, { "x", "missing" })
  luaunit.assertEquals(result.x, 10)
  luaunit.assertNil(result.missing)
end

-- ---------------------------------------------------------------------------
-- Run
-- ---------------------------------------------------------------------------
os.exit(luaunit.LuaUnit.run())
