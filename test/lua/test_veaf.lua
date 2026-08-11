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
  local changed = veaf.arrayRemoveWhen(t, function(_, _, _)
    return true
  end)
  luaunit.assertFalse(changed)
  luaunit.assertEquals(#t, 3)
end

function TestVeafArrayRemoveWhen:test_removeAllReturnsTrue()
  local t = { 1, 2, 3 }
  local changed = veaf.arrayRemoveWhen(t, function(_, _, _)
    return false
  end)
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
  function obj:getName()
    return "test"
  end
  luaunit.assertEquals(veaf.ifnn(obj, "getName"), "test")
end

function TestVeafIfnn:test_erroringFunctionReturnsNil()
  local obj = {}
  function obj:broken()
    error("oops")
  end
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

-- ===========================================================================
-- veaf.getConfig / veaf.setConfig / veaf.isEnabled
-- ===========================================================================
TestVeafModuleConfig = {}

function TestVeafModuleConfig:setUp()
  veaf.config["__test_module__"] = nil
end

function TestVeafModuleConfig:test_getConfigReturnsEmptyTableForUnknown()
  local cfg = veaf.getConfig("__test_module__")
  luaunit.assertNotNil(cfg)
  luaunit.assertEquals(veaf.length(cfg), 0)
end

function TestVeafModuleConfig:test_setConfigStoresValue()
  veaf.setConfig("__test_module__", "someKey", 42)
  luaunit.assertEquals(veaf.getConfig("__test_module__").someKey, 42)
end

function TestVeafModuleConfig:test_isEnabledTrueByDefault()
  luaunit.assertTrue(veaf.isEnabled("__test_module__"))
end

function TestVeafModuleConfig:test_isEnabledFalseWhenDisabled()
  veaf.setConfig("__test_module__", "enable", false)
  luaunit.assertFalse(veaf.isEnabled("__test_module__"))
end

function TestVeafModuleConfig:tearDown()
  veaf.config["__test_module__"] = nil
end

-- ===========================================================================
-- veaf.registerModule
-- ===========================================================================
TestVeafRegisterModule = {}

function TestVeafRegisterModule:setUp()
  veaf.config["__test_reg__"] = nil
  veaf.modules["__test_reg__"] = nil
end

function TestVeafRegisterModule:test_registersModuleWithDefaults()
  veaf.registerModule("__test_reg__", function() end, { speed = 200 })
  luaunit.assertNotNil(veaf.modules["__test_reg__"])
  luaunit.assertEquals(veaf.getConfig("__test_reg__").speed, 200)
end

function TestVeafRegisterModule:test_existingConfigNotOverwritten()
  veaf.setConfig("__test_reg__", "speed", 300)
  veaf.registerModule("__test_reg__", function() end, { speed = 200 })
  luaunit.assertEquals(veaf.getConfig("__test_reg__").speed, 300)
end

function TestVeafRegisterModule:test_enableDefaultsToTrue()
  veaf.registerModule("__test_reg__", function() end)
  luaunit.assertTrue(veaf.getConfig("__test_reg__").enable)
end

function TestVeafRegisterModule:test_orderStoredInModule()
  veaf.registerModule("__test_reg__", function() end, nil, 50)
  luaunit.assertEquals(veaf.modules["__test_reg__"].order, 50)
end

function TestVeafRegisterModule:test_defaultOrderIs100()
  veaf.registerModule("__test_reg__", function() end)
  luaunit.assertEquals(veaf.modules["__test_reg__"].order, 100)
end

function TestVeafRegisterModule:tearDown()
  veaf.config["__test_reg__"] = nil
  veaf.modules["__test_reg__"] = nil
end

-- ===========================================================================
-- veaf.enumToString
-- ===========================================================================
TestVeafEnumToString = {}

function TestVeafEnumToString:test_knownValue()
  local mapping = { [1] = "ONE", [2] = "TWO", [3] = "THREE" }
  luaunit.assertEquals(veaf.enumToString(1, mapping), "ONE")
  luaunit.assertEquals(veaf.enumToString(3, mapping), "THREE")
end

function TestVeafEnumToString:test_unknownValueReturnsEmpty()
  local mapping = { [1] = "ONE" }
  luaunit.assertEquals(veaf.enumToString(99, mapping), "")
end

function TestVeafEnumToString:test_nilValueReturnsEmpty()
  luaunit.assertEquals(veaf.enumToString(nil, { [1] = "A" }), "")
end

function TestVeafEnumToString:test_nilMappingReturnsEmpty()
  luaunit.assertEquals(veaf.enumToString(1, nil), "")
end

-- ===========================================================================
-- veaf.p / veaf._p / veaf.lp
-- ===========================================================================
TestVeafP = {}

function TestVeafP:test_nil()
  luaunit.assertEquals(veaf.p(nil), "[nil]")
end

function TestVeafP:test_number()
  luaunit.assertEquals(veaf.p(42), "42")
  luaunit.assertEquals(veaf.p(0), "0")
end

function TestVeafP:test_boolTrue()
  luaunit.assertEquals(veaf.p(true), "[true]")
end

function TestVeafP:test_boolFalse()
  luaunit.assertEquals(veaf.p(false), "[false]")
end

function TestVeafP:test_function()
  luaunit.assertEquals(veaf.p(function() end), "[function]")
end

function TestVeafP:test_tableContainsKeyAndValue()
  local s = veaf.p({ hello = "world" })
  luaunit.assertStrContains(s, "hello")
  luaunit.assertStrContains(s, "world")
end

function TestVeafP:test_customTostring()
  local t = setmetatable({}, {
    __tostring = function()
      return "custom_repr"
    end,
  })
  luaunit.assertEquals(veaf.p(t), "custom_repr")
end

function TestVeafP:test_nestedTable()
  local s = veaf.p({ outer = { inner = 99 } })
  luaunit.assertStrContains(s, "outer")
end

TestVeafLp = {}

function TestVeafLp:test_lpReturnsProxyTable()
  local proxy = veaf.lp(42)
  luaunit.assertEquals(type(proxy), "table")
  luaunit.assertEquals(tostring(proxy), "42")
end

function TestVeafLp:test_lpNil()
  local proxy = veaf.lp(nil)
  luaunit.assertEquals(tostring(proxy), "[nil]")
end

function TestVeafLp:test_lpBoolTrue()
  local proxy = veaf.lp(true)
  luaunit.assertEquals(tostring(proxy), "[true]")
end

-- ===========================================================================
-- veaf.shuffle
-- ===========================================================================
TestVeafShuffle = {}

function TestVeafShuffle:test_preservesLength()
  local t = { 1, 2, 3, 4, 5 }
  veaf.shuffle(t)
  luaunit.assertEquals(#t, 5)
end

function TestVeafShuffle:test_containsSameElements()
  local original = { 10, 20, 30, 40, 50 }
  local copy = { 10, 20, 30, 40, 50 }
  veaf.shuffle(copy)
  for _, v in ipairs(original) do
    luaunit.assertTrue(veaf.tableContains(copy, v))
  end
end

function TestVeafShuffle:test_emptyTableDoesNotError()
  local t = {}
  veaf.shuffle(t)
  luaunit.assertEquals(#t, 0)
end

-- ===========================================================================
-- veaf.safeCall
-- ===========================================================================
TestVeafSafeCall = {}

function TestVeafSafeCall:test_successReturnsValue()
  local result = veaf.safeCall(function(a, b)
    return a + b
  end, 3, 4)
  luaunit.assertEquals(result, 7)
end

function TestVeafSafeCall:test_errorReturnsNil()
  local result = veaf.safeCall(function()
    error("boom")
  end)
  luaunit.assertNil(result)
end

function TestVeafSafeCall:test_multipleReturnValues()
  local a, b = veaf.safeCall(function()
    return 1, 2
  end)
  luaunit.assertEquals(a, 1)
  luaunit.assertEquals(b, 2)
end

-- ===========================================================================
-- veaf.serialize
-- ===========================================================================
TestVeafSerialize = {}

function TestVeafSerialize:test_number()
  local s = veaf.serialize("x", 42)
  luaunit.assertStrContains(s, "x")
  luaunit.assertStrContains(s, "42")
end

function TestVeafSerialize:test_string()
  local s = veaf.serialize("name", "hello")
  luaunit.assertStrContains(s, "name")
  luaunit.assertStrContains(s, "hello")
end

function TestVeafSerialize:test_boolean()
  local s = veaf.serialize("flag", true)
  luaunit.assertStrContains(s, "flag")
  luaunit.assertStrContains(s, "true")
end

function TestVeafSerialize:test_table()
  local s = veaf.serialize("t", { alpha = 99 })
  luaunit.assertStrContains(s, "t")
  luaunit.assertStrContains(s, "alpha")
  luaunit.assertStrContains(s, "99")
end

function TestVeafSerialize:test_nilValueSerializesAsEmptyString()
  local s = veaf.serialize("v", nil)
  luaunit.assertStrContains(s, "v")
end

-- ===========================================================================
-- veaf.json.stringify / veaf.json.parse
-- ===========================================================================
TestVeafJson = {}

function TestVeafJson:test_stringifyString()
  luaunit.assertEquals(veaf.json.stringify("hello"), '"hello"')
end

function TestVeafJson:test_stringifyNumber()
  luaunit.assertEquals(veaf.json.stringify(42), "42")
end

function TestVeafJson:test_stringifyBoolTrue()
  luaunit.assertEquals(veaf.json.stringify(true), "true")
end

function TestVeafJson:test_stringifyBoolFalse()
  luaunit.assertEquals(veaf.json.stringify(false), "false")
end

function TestVeafJson:test_stringifyNil()
  luaunit.assertEquals(veaf.json.stringify(nil), "null")
end

function TestVeafJson:test_stringifyArray()
  local s = veaf.json.stringify({ 1, 2, 3 })
  luaunit.assertEquals(s:sub(1, 1), "[")
  luaunit.assertEquals(s:sub(-1), "]")
  luaunit.assertStrContains(s, "1")
  luaunit.assertStrContains(s, "2")
  luaunit.assertStrContains(s, "3")
end

function TestVeafJson:test_stringifyObject()
  local s = veaf.json.stringify({ name = "test" })
  luaunit.assertStrContains(s, '"name"')
  luaunit.assertStrContains(s, '"test"')
  luaunit.assertStrContains(s, ":")
end

function TestVeafJson:test_parseString()
  luaunit.assertEquals(veaf.json.parse('"hello"'), "hello")
end

function TestVeafJson:test_parseNumber()
  luaunit.assertEquals(veaf.json.parse("42"), 42)
end

function TestVeafJson:test_parseNegativeNumber()
  luaunit.assertEquals(veaf.json.parse("-7"), -7)
end

function TestVeafJson:test_parseBoolTrue()
  luaunit.assertEquals(veaf.json.parse("true"), true)
end

function TestVeafJson:test_parseBoolFalse()
  luaunit.assertEquals(veaf.json.parse("false"), false)
end

function TestVeafJson:test_parseNull()
  local result = veaf.json.parse("null")
  luaunit.assertEquals(result, veaf.json.null)
end

function TestVeafJson:test_parseArray()
  local arr = veaf.json.parse("[10, 20, 30]")
  luaunit.assertEquals(arr[1], 10)
  luaunit.assertEquals(arr[2], 20)
  luaunit.assertEquals(arr[3], 30)
end

function TestVeafJson:test_parseObject()
  local obj = veaf.json.parse('{"city":"Paris","pop":2000}')
  luaunit.assertEquals(obj.city, "Paris")
  luaunit.assertEquals(obj.pop, 2000)
end

function TestVeafJson:test_arrayRoundtrip()
  local original = { 10, 20, 30 }
  local parsed = veaf.json.parse(veaf.json.stringify(original))
  luaunit.assertEquals(parsed[1], 10)
  luaunit.assertEquals(parsed[2], 20)
  luaunit.assertEquals(parsed[3], 30)
end

function TestVeafJson:test_stringEscaping()
  -- backslash and quote are escaped
  local s = veaf.json.stringify('say "hi"')
  luaunit.assertStrContains(s, '\\"')
end

-- ===========================================================================
-- veaf.computeLLFromString
-- ===========================================================================
TestVeafComputeLLFromString = {}

function TestVeafComputeLLFromString:test_llDecimal()
  local lat, lon = veaf.computeLLFromString("N10.5E020.5")
  luaunit.assertAlmostEquals(lat, 10.5, 0.001)
  luaunit.assertAlmostEquals(lon, 20.5, 0.001)
end

function TestVeafComputeLLFromString:test_llSouthWest()
  local lat, lon = veaf.computeLLFromString("S10.5W020.5")
  luaunit.assertAlmostEquals(lat, -10.5, 0.001)
  luaunit.assertAlmostEquals(lon, -20.5, 0.001)
end

function TestVeafComputeLLFromString:test_llDMS()
  -- N42:23:45E044:12:00
  local lat, lon = veaf.computeLLFromString("N42:23:45E044:12:00")
  luaunit.assertNotNil(lat)
  luaunit.assertNotNil(lon)
  -- 42° 23' 45" ≈ 42.396 (function has ~1 arcsec offset by design)
  luaunit.assertTrue(lat > 42.39 and lat < 42.40)
  luaunit.assertTrue(lon > 44.19 and lon < 44.21)
end

function TestVeafComputeLLFromString:test_llDMDecimal()
  -- N42-23.5E044-12.5
  local lat, lon = veaf.computeLLFromString("N42-23.5E044-12.5")
  luaunit.assertNotNil(lat)
  luaunit.assertNotNil(lon)
  luaunit.assertTrue(lat > 42 and lat < 43)
  luaunit.assertTrue(lon > 44 and lon < 45)
end

function TestVeafComputeLLFromString:test_utm()
  -- Calls coord.MGRStoLL which is stubbed to return 0, 0
  local lat, lon = veaf.computeLLFromString("U38TMP12345678")
  luaunit.assertNotNil(lat)
  luaunit.assertNotNil(lon)
end

function TestVeafComputeLLFromString:test_unknownFormatReturnsNil()
  luaunit.assertNil(veaf.computeLLFromString("invalid"))
end

function TestVeafComputeLLFromString:test_nilReturnsNil()
  luaunit.assertNil(veaf.computeLLFromString(nil))
end

-- ===========================================================================
-- veaf.compute2dAzimuth / veaf.compute2dMagnitude
-- ===========================================================================
TestVeafCompute2d = {}

function TestVeafCompute2d:test_azimuthNorth()
  -- x=north, z=east in DCS; x=1,z=0 → atan2(0,1) = 0°
  luaunit.assertAlmostEquals(veaf.compute2dAzimuth({ x = 1, z = 0 }), 0, 0.01)
end

function TestVeafCompute2d:test_azimuthEast()
  luaunit.assertAlmostEquals(veaf.compute2dAzimuth({ x = 0, z = 1 }), 90, 0.01)
end

function TestVeafCompute2d:test_azimuthSouth()
  luaunit.assertAlmostEquals(veaf.compute2dAzimuth({ x = -1, z = 0 }), 180, 0.01)
end

function TestVeafCompute2d:test_azimuthWest()
  luaunit.assertAlmostEquals(veaf.compute2dAzimuth({ x = 0, z = -1 }), 270, 0.01)
end

function TestVeafCompute2d:test_azimuthZeroVecReturns0()
  luaunit.assertEquals(veaf.compute2dAzimuth({ x = 0, z = 0 }), 0)
end

function TestVeafCompute2d:test_azimuthNilReturns0()
  luaunit.assertEquals(veaf.compute2dAzimuth(nil), 0)
end

function TestVeafCompute2d:test_magnitude345()
  luaunit.assertAlmostEquals(veaf.compute2dMagnitude({ x = 3, z = 4 }), 5, 0.001)
end

function TestVeafCompute2d:test_magnitudeZero()
  luaunit.assertEquals(veaf.compute2dMagnitude({ x = 0, z = 0 }), 0)
end

function TestVeafCompute2d:test_magnitudeNilReturns0()
  luaunit.assertEquals(veaf.compute2dMagnitude(nil), 0)
end

-- ===========================================================================
-- veaf.convertSpeeds / wrappers
-- ===========================================================================
TestVeafConvertSpeeds = {}

function TestVeafConvertSpeeds:test_fromMachSeaLevel()
  -- Mach 0.5 at sea level: TAS ≈ IAS (same pressure altitude)
  local r = veaf.convertSpeeds(0.5, nil, nil, 0)
  luaunit.assertAlmostEquals(r.Mach, 0.5, 0.001)
  luaunit.assertTrue(r.KTAS > 0)
  luaunit.assertTrue(r.KIAS > 0)
  luaunit.assertAlmostEquals(r.KTAS, r.KIAS, 1)
end

function TestVeafConvertSpeeds:test_fromMachAtAltitudeTasGreaterThanIas()
  -- At cruise altitude, TAS > IAS
  local r = veaf.convertSpeeds(0.8, nil, nil, 10668)
  luaunit.assertAlmostEquals(r.Mach, 0.8, 0.001)
  luaunit.assertTrue(r.KTAS > r.KIAS)
  luaunit.assertTrue(r.KTAS > 400)
end

function TestVeafConvertSpeeds:test_fromKiasRoundtrip()
  local r = veaf.convertSpeeds(nil, 250, nil, 0)
  luaunit.assertAlmostEquals(r.KIAS, 250, 0.1)
  luaunit.assertTrue(r.Mach > 0)
  luaunit.assertTrue(r.KTAS > 0)
end

function TestVeafConvertSpeeds:test_fromKtasRoundtrip()
  local r = veaf.convertSpeeds(nil, nil, 300, 0)
  luaunit.assertAlmostEquals(r.KTAS, 300, 0.1)
  luaunit.assertTrue(r.Mach > 0)
  luaunit.assertTrue(r.KIAS > 0)
end

function TestVeafConvertSpeeds:test_convertMachSpeedWrapper()
  local r = veaf.convertMachSpeed(0.6, 5000)
  luaunit.assertAlmostEquals(r.Mach, 0.6, 0.001)
end

function TestVeafConvertSpeeds:test_convertIndicatedAirSpeedWrapper()
  local r = veaf.convertIndicatedAirSpeed(200, 5000)
  luaunit.assertAlmostEquals(r.KIAS, 200, 0.1)
end

function TestVeafConvertSpeeds:test_convertTrueAirSpeedWrapper()
  local r = veaf.convertTrueAirSpeed(300, 5000)
  luaunit.assertAlmostEquals(r.KTAS, 300, 0.1)
end

function TestVeafConvertSpeeds:test_supersonic()
  -- Mach 1.5 at altitude: should trigger Rayleigh path; KTAS > KIAS in altitude
  local r = veaf.convertSpeeds(1.5, nil, nil, 10668)
  luaunit.assertAlmostEquals(r.Mach, 1.5, 0.001)
  luaunit.assertTrue(r.KTAS > r.KIAS)
end

-- ===========================================================================
-- veaf.getMagneticDeclination (theatres not covered by the existing tests)
-- ===========================================================================
TestVeafMagneticDeclinationExtra = {}

function TestVeafMagneticDeclinationExtra:test_theChannel()
  env.mission.theatre = "TheChannel"
  luaunit.assertEquals(veaf.getMagneticDeclination(), -10)
end

function TestVeafMagneticDeclinationExtra:test_syria()
  env.mission.theatre = "Syria"
  luaunit.assertEquals(veaf.getMagneticDeclination(), 5)
end

function TestVeafMagneticDeclinationExtra:test_marianaIslands()
  env.mission.theatre = "MarianaIslands"
  luaunit.assertEquals(veaf.getMagneticDeclination(), 2)
end

function TestVeafMagneticDeclinationExtra:test_falklands()
  env.mission.theatre = "Falklands"
  luaunit.assertEquals(veaf.getMagneticDeclination(), 12)
end

function TestVeafMagneticDeclinationExtra:test_sinaiMap()
  env.mission.theatre = "SinaiMap"
  luaunit.assertAlmostEquals(veaf.getMagneticDeclination(), 4.8, 0.01)
end

function TestVeafMagneticDeclinationExtra:test_kola()
  env.mission.theatre = "Kola"
  luaunit.assertEquals(veaf.getMagneticDeclination(), 15)
end

function TestVeafMagneticDeclinationExtra:test_afghanistan()
  env.mission.theatre = "Afghanistan"
  luaunit.assertEquals(veaf.getMagneticDeclination(), 3)
end

function TestVeafMagneticDeclinationExtra:tearDown()
  env.mission.theatre = "Caucasus"
end

-- ===========================================================================
-- veaf.getCountryForCoalition / veaf.getCoalitionForCountry
-- ===========================================================================
TestVeafCountryCoalition = {}

function TestVeafCountryCoalition:setUp()
  -- Reset lazy-initialized tables to force re-initialization in each test.
  veaf.countriesByCoalition = nil
  veaf.coalitionByCountry = nil
  veaf.countriesByName = nil
  veaf.countriesNamesById = nil
end

function TestVeafCountryCoalition:test_redCoalitionReturnsRussian()
  -- Mock: country.id.RUSSIA=0 → coalition.side.RED(=1)
  local c = veaf.getCountryForCoalition(1)
  luaunit.assertNotNil(c)
  luaunit.assertEquals(c:lower(), "russia")
end

function TestVeafCountryCoalition:test_blueCoalitionReturnsUSA()
  local c = veaf.getCountryForCoalition(2)
  luaunit.assertNotNil(c)
  luaunit.assertEquals(c:lower(), "usa")
end

function TestVeafCountryCoalition:test_stringCoalitionName()
  local c = veaf.getCountryForCoalition("red")
  luaunit.assertNotNil(c)
  luaunit.assertEquals(c:lower(), "russia")
end

function TestVeafCountryCoalition:test_coalitionForCountryRed()
  local coa = veaf.getCoalitionForCountry("russia", false)
  luaunit.assertEquals(coa, "red")
end

function TestVeafCountryCoalition:test_coalitionForCountryBlue()
  local coa = veaf.getCoalitionForCountry("usa", false)
  luaunit.assertEquals(coa, "blue")
end

function TestVeafCountryCoalition:test_coalitionForCountryAsNumber()
  local coa = veaf.getCoalitionForCountry("russia", true)
  luaunit.assertEquals(coa, 1)
end

function TestVeafCountryCoalition:test_coalitionForCountryUSAAsNumber()
  local coa = veaf.getCoalitionForCountry("usa", true)
  luaunit.assertEquals(coa, 2)
end

function TestVeafCountryCoalition:test_coalitionForCountryNilReturnsNil()
  local coa = veaf.getCoalitionForCountry(nil, false)
  luaunit.assertNil(coa)
end

-- ===========================================================================
-- veaf.Logger
-- ===========================================================================
TestVeafLogger = {}

function TestVeafLogger:test_newLogger()
  local log = veaf.Logger:new("TestLogger", "info")
  luaunit.assertNotNil(log)
  -- Logger:new does not uppercase; loggers.new does
  luaunit.assertEquals(log.name, "TestLogger")
end

function TestVeafLogger:test_setLevelByString()
  local log = veaf.Logger:new("TL", "info")
  -- force=true to bypass BaseLogLevel cap
  log:setLevel("debug", true)
  luaunit.assertEquals(log:getLevel(), veaf.Logger.LEVEL["debug"])
end

function TestVeafLogger:test_setLevelByNumber()
  local log = veaf.Logger:new("TL", 2)
  luaunit.assertEquals(log:getLevel(), 2)
end

function TestVeafLogger:test_setLevelNilDefaultsToInfo()
  local log = veaf.Logger:new("TL", nil)
  luaunit.assertEquals(log:getLevel(), veaf.Logger.LEVEL["info"])
end

function TestVeafLogger:test_getEffectiveLevel()
  local log = veaf.Logger:new("TL", "info")
  luaunit.assertEquals(log:getEffectiveLevel(), veaf.Logger.LEVEL["info"])
end

function TestVeafLogger:test_wouldLogInfo()
  local log = veaf.Logger:new("TL", "info")
  luaunit.assertTrue(log:wouldLogInfo())
  luaunit.assertFalse(log:wouldLogDebug())
  luaunit.assertFalse(log:wouldLogTrace())
end

function TestVeafLogger:test_wouldLogWarn()
  local log = veaf.Logger:new("TL", "warning")
  luaunit.assertTrue(log:wouldLogWarn())
  luaunit.assertFalse(log:wouldLogInfo())
end

function TestVeafLogger:test_wouldLogDebug()
  local log = veaf.Logger:new("TL", "info")
  log:setLevel("debug", true)
  luaunit.assertTrue(log:wouldLogInfo())
  luaunit.assertTrue(log:wouldLogDebug())
  luaunit.assertFalse(log:wouldLogTrace())
end

function TestVeafLogger:test_levelToStringFromString()
  luaunit.assertEquals(veaf.Logger.levelToString("INFO"), "info")
  luaunit.assertEquals(veaf.Logger.levelToString("debug"), "debug")
end

function TestVeafLogger:test_levelToStringFromNumber()
  luaunit.assertEquals(veaf.Logger.levelToString(1), "ERROR")
  luaunit.assertEquals(veaf.Logger.levelToString(3), "INFO")
end

function TestVeafLogger:test_levelToStringUnknown()
  luaunit.assertEquals(veaf.Logger.levelToString(nil), "unknown")
  luaunit.assertEquals(veaf.Logger.levelToString(99), "unknown")
end

function TestVeafLogger:test_getVersionInfo()
  local log = veaf.Logger:new("TL", "info")
  local info = log:getVersionInfo("1.2.3")
  luaunit.assertStrContains(info, "1.2.3")
  -- levelToString from number returns uppercase "INFO"
  luaunit.assertStrContains(info, "INFO")
end

function TestVeafLogger:test_getVersionInfo_noArg_isNumberless()
  -- with no version, modules log a numberless "loaded" line (per-module versions retired)
  local log = veaf.Logger:new("TL", "info")
  local info = log:getVersionInfo()
  luaunit.assertStrContains(info, "loaded")
  luaunit.assertStrContains(info, "INFO")
  luaunit.assertNil(info:find("version"))
end

function TestVeafLogger:test_buildVersion_fallsBackToDev()
  -- unbuilt scripts (hand-copied, or the Lua tests) have no VEAF_BUILD_VERSION global
  luaunit.assertIsString(veaf.BuildVersion)
  luaunit.assertEquals(veaf.BuildVersion, "dev")
end

function TestVeafLogger:test_splitTextShort()
  local tbl = veaf.Logger.splitText("short text")
  luaunit.assertEquals(#tbl, 1)
  luaunit.assertEquals(tbl[1], "short text")
end

function TestVeafLogger:test_splitTextLong()
  local long = string.rep("x", 8001)
  local tbl = veaf.Logger.splitText(long)
  luaunit.assertEquals(#tbl, 3)
end

function TestVeafLogger:test_formatTextNil()
  luaunit.assertEquals(veaf.Logger.formatText(nil), "")
end

function TestVeafLogger:test_formatTextPlain()
  local s = veaf.Logger.formatText("hello world")
  luaunit.assertStrContains(s, "hello world")
end

function TestVeafLogger:test_logDoesNotError()
  local log = veaf.Logger:new("TL", "trace")
  -- These should run without error (env.* is mocked)
  log:info("test info message")
  log:warn("test warn message")
  log:debug("test debug message")
  log:trace("test trace message")
  luaunit.assertTrue(true)
end

function TestVeafLogger:test_errorDoesNotError()
  local log = veaf.Logger:new("TL", "trace")
  log:error("test error message")
  luaunit.assertTrue(true)
end

-- ===========================================================================
-- veaf.loggers.new / veaf.loggers.get / veaf.loggers.setBaseLevel
-- ===========================================================================
TestVeafLoggers = {}

function TestVeafLoggers:test_newAndGet()
  local log = veaf.loggers.new("__testlogger__", "info")
  luaunit.assertNotNil(log)
  local got = veaf.loggers.get("__testlogger__")
  luaunit.assertNotNil(got)
  luaunit.assertEquals(got.name, "__TESTLOGGER__")
end

function TestVeafLoggers:test_getUnknownFallsBackToVeaf()
  local result = veaf.loggers.get("__nonexistent_xyz__")
  luaunit.assertNotNil(result)
end

function TestVeafLoggers:test_newNilReturnsNil()
  local result = veaf.loggers.new(nil, "info")
  luaunit.assertNil(result)
end

function TestVeafLoggers:test_newEmptyReturnsNil()
  local result = veaf.loggers.new("", "info")
  luaunit.assertNil(result)
end

function TestVeafLoggers:test_setBaseLevelUpdatesExistingLoggers()
  local log = veaf.loggers.new("__tbl__", "trace")
  local savedBase = veaf.BaseLogLevel
  veaf.loggers.setBaseLevel(2)
  -- After setBaseLevel, trace logger should be capped to 2
  luaunit.assertEquals(log:getLevel(), 2)
  veaf.loggers.setBaseLevel(savedBase)
end

function TestVeafLoggers:tearDown()
  veaf.loggers.dict["__testlogger__"] = nil
  veaf.loggers.dict["__tbl__"] = nil
end

-- ===========================================================================
-- veaf.getUniqueIdentifier / veaf.generateMilitaryGroupName
-- ===========================================================================
TestVeafMisc = {}

function TestVeafMisc:test_uniqueIdentifierIncreases()
  local a = veaf.getUniqueIdentifier()
  local b = veaf.getUniqueIdentifier()
  luaunit.assertEquals(b, a + 1)
end

function TestVeafMisc:test_uniqueIdentifierIsNumber()
  local id = veaf.getUniqueIdentifier()
  luaunit.assertEquals(type(id), "number")
end

function TestVeafMisc:test_generateMilitaryGroupNameIsString()
  local name = veaf.generateMilitaryGroupName()
  luaunit.assertEquals(type(name), "string")
  luaunit.assertTrue(#name > 0)
end

function TestVeafMisc:test_generateMilitaryGroupNameVaried()
  local names = {}
  for i = 1, 20 do
    names[i] = veaf.generateMilitaryGroupName()
  end
  local unique = {}
  for _, n in ipairs(names) do
    unique[n] = true
  end
  -- With 20 samples, should get at least 3 unique names
  local count = 0
  for _ in pairs(unique) do
    count = count + 1
  end
  luaunit.assertTrue(count > 1)
end

-- ===========================================================================
-- veaf.p — additional edge cases
-- ===========================================================================
TestVeafPExtra = {}

function TestVeafPExtra:test_emptyString()
  luaunit.assertEquals(veaf.p(""), "")
end

function TestVeafPExtra:test_dontRecurse()
  local t = { a = 1, b = { c = 2 } }
  local s = veaf.p(t, nil, nil, nil, true)
  luaunit.assertStrContains(s, "a")
end

function TestVeafPExtra:test_skipKey()
  local t = { visible = "yes", secret = "no" }
  local s = veaf.p(t, nil, { "secret" })
  luaunit.assertStrContains(s, "visible")
  luaunit.assertStrContains(s, "SKIPPED")
end

-- ===========================================================================
-- veaf.json — kind_of edge cases
-- ===========================================================================
TestVeafJsonKindOf = {}

function TestVeafJsonKindOf:test_sparseTableStringifiesAsObject()
  -- A table with non-consecutive keys is treated as object (kind_of = "table")
  local t = { [1] = "a", [3] = "c" }
  local s = veaf.json.stringify(t)
  -- Result is an object (starts with '{') not an array
  luaunit.assertEquals(s:sub(1, 1), "{")
end

function TestVeafJsonKindOf:test_nonNumericKeyIsObject()
  local t = { foo = "bar", baz = 99 }
  local s = veaf.json.stringify(t)
  luaunit.assertStrContains(s, '"foo"')
end

function TestVeafJsonKindOf:test_parseStringWithEscapeSequences()
  local result = veaf.json.parse('"line1\\nline2"')
  luaunit.assertEquals(result, "line1\nline2")
end

function TestVeafJsonKindOf:test_parseStringWithEscapedQuote()
  local result = veaf.json.parse('"say \\"hi\\""')
  luaunit.assertEquals(result, 'say "hi"')
end

function TestVeafJsonKindOf:test_nestedObjectRoundtrip()
  local obj = { level1 = { level2 = { value = 42 } } }
  local parsed = veaf.json.parse(veaf.json.stringify(obj))
  luaunit.assertEquals(parsed.level1.level2.value, 42)
end

function TestVeafJsonKindOf:test_nestedArrayRoundtrip()
  local arr = { { 1, 2 }, { 3, 4 } }
  local parsed = veaf.json.parse(veaf.json.stringify(arr))
  luaunit.assertEquals(parsed[1][1], 1)
  luaunit.assertEquals(parsed[2][2], 4)
end

-- ---------------------------------------------------------------------------
-- TestVeafPilotFeedback (UXPILOT-FEEDBACK)
-- ---------------------------------------------------------------------------
TestVeafPilotFeedback = {}

function TestVeafPilotFeedback:test_reportToPilot_to_all_uses_outText()
  local captured = nil
  local orig = trigger.action.outText
  trigger.action.outText = function(text, duration)
    captured = { text = text, duration = duration }
  end
  veaf.reportToPilot("hello", 12)
  trigger.action.outText = orig
  luaunit.assertEquals(captured.text, "hello")
  luaunit.assertEquals(captured.duration, 12)
end

function TestVeafPilotFeedback:test_reportToPilot_to_coalition()
  local captured = nil
  local orig = trigger.action.outTextForCoalition
  trigger.action.outTextForCoalition = function(side, text, duration)
    captured = { side = side, text = text }
  end
  veaf.reportToPilot("hi", 10, 2)
  trigger.action.outTextForCoalition = orig
  luaunit.assertEquals(captured.side, 2)
  luaunit.assertEquals(captured.text, "hi")
end

function TestVeafPilotFeedback:test_reportToPilot_default_duration()
  local captured = nil
  local orig = trigger.action.outText
  trigger.action.outText = function(text, duration)
    captured = duration
  end
  veaf.reportToPilot("x")
  trigger.action.outText = orig
  luaunit.assertEquals(captured, 15)
end

function TestVeafPilotFeedback:test_levenshtein()
  luaunit.assertEquals(veaf.levenshtein("heading", "heading"), 0)
  luaunit.assertEquals(veaf.levenshtein("headng", "heading"), 1)
  luaunit.assertEquals(veaf.levenshtein("", "abc"), 3)
  luaunit.assertEquals(veaf.levenshtein("abc", ""), 3)
end

function TestVeafPilotFeedback:test_nearestMatch_finds_close()
  luaunit.assertEquals(veaf.nearestMatch("headng", { "heading", "speed", "size" }), "heading")
end

function TestVeafPilotFeedback:test_nearestMatch_returns_nil_when_too_far()
  luaunit.assertNil(veaf.nearestMatch("zzzzzzzz", { "heading", "speed" }, 3))
end

-- ---------------------------------------------------------------------------
-- TestVeafCoalition — requester vs opposite coalition (COALITION-REFACTOR)
-- ---------------------------------------------------------------------------
TestVeafCoalition = {}

function TestVeafCoalition:test_requester_returns_red_blue()
  luaunit.assertEquals(veaf.getRequesterCoalition({ coalition = coalition.side.RED }), coalition.side.RED)
  luaunit.assertEquals(veaf.getRequesterCoalition({ coalition = coalition.side.BLUE }), coalition.side.BLUE)
end

function TestVeafCoalition:test_requester_nil_for_neutral_all_or_missing()
  luaunit.assertNil(veaf.getRequesterCoalition({ coalition = coalition.side.NEUTRAL }))
  luaunit.assertNil(veaf.getRequesterCoalition({ coalition = -1 }))
  luaunit.assertNil(veaf.getRequesterCoalition({}))
  luaunit.assertNil(veaf.getRequesterCoalition(nil))
end

function TestVeafCoalition:test_opposite_swaps_red_blue()
  luaunit.assertEquals(veaf.getOppositeCoalition(coalition.side.RED), coalition.side.BLUE)
  luaunit.assertEquals(veaf.getOppositeCoalition(coalition.side.BLUE), coalition.side.RED)
end

function TestVeafCoalition:test_opposite_defaults_neutral_to_red()
  luaunit.assertEquals(veaf.getOppositeCoalition(coalition.side.NEUTRAL), coalition.side.RED)
  luaunit.assertEquals(veaf.getOppositeCoalition(-1), coalition.side.RED)
end

-- ===========================================================================
-- veaf.isEnabled — the gate behind the community-module integration guards
-- (FIX-VEAF-MODULE-GATING: `if ctld and veaf.isEnabled("ctld") then …`)
-- ===========================================================================
TestVeafIsEnabled = {}

function TestVeafIsEnabled:setUp()
  veaf.config = {}
end

function TestVeafIsEnabled:test_unconfigured_module_is_enabled_by_default()
  luaunit.assertTrue(veaf.isEnabled("ctld"))
end

function TestVeafIsEnabled:test_enable_false_disables()
  veaf.setConfig("ctld", "enable", false)
  luaunit.assertFalse(veaf.isEnabled("ctld"))
end

function TestVeafIsEnabled:test_enable_true_enables()
  veaf.setConfig("stts", "enable", true)
  luaunit.assertTrue(veaf.isEnabled("stts"))
end

function TestVeafIsEnabled:test_other_keys_do_not_affect_enabled()
  veaf.setConfig("ctld", "logLevel", "debug")
  luaunit.assertTrue(veaf.isEnabled("ctld"))
end

-- ---------------------------------------------------------------------------
-- Logger DCSServerBot forwarding
-- Regression: veaf.Logger:print used Sim.getMissionName(), but Sim is a
-- GameGUI/hook global absent from the mission env, so every :error() crashed
-- on servers wired to DCSServerBot. It must use veaf.config.MISSION_NAME.
-- ---------------------------------------------------------------------------
TestVeafLoggerDcsServerBot = {}

function TestVeafLoggerDcsServerBot:setUp()
  self._sent = {}
  dcsbot = {
    sendBotMessage = function(msg, channel)
      table.insert(self._sent, { msg = msg, channel = channel })
    end,
  }
  self._saved = {
    channel = veaf.config.DCS_SERVER_BOT_CHANNEL,
    server = veaf.config.SERVER_NAME,
    mission = veaf.config.MISSION_NAME,
  }
  veaf.config.DCS_SERVER_BOT_CHANNEL = "veaf-channel"
  veaf.config.SERVER_NAME = "TestServer"
end

function TestVeafLoggerDcsServerBot:tearDown()
  dcsbot = nil
  veaf.config.DCS_SERVER_BOT_CHANNEL = self._saved.channel
  veaf.config.SERVER_NAME = self._saved.server
  veaf.config.MISSION_NAME = self._saved.mission
end

function TestVeafLoggerDcsServerBot:test_error_forwards_without_crashing()
  veaf.config.MISSION_NAME = "MyMission"
  local logger = veaf.Logger:new("TEST", "error")
  logger:error("boom") -- must not raise (Sim is nil in the mission env)
  luaunit.assertTrue(#self._sent >= 1)
  luaunit.assertStrContains(self._sent[1].msg, "MyMission")
  luaunit.assertEquals(self._sent[1].channel, "veaf-channel")
end

function TestVeafLoggerDcsServerBot:test_error_uses_unknown_when_mission_name_nil()
  veaf.config.MISSION_NAME = nil
  local logger = veaf.Logger:new("TEST", "error")
  logger:error("boom")
  luaunit.assertTrue(#self._sent >= 1)
  luaunit.assertStrContains(self._sent[1].msg, "unknown")
end

-- ---------------------------------------------------------------------------
-- CTLD 2 integration (FEAT-CTLD2-INTEGRATION ticket 04)
--
-- CTLD 2 has no log level of its own: ctld.utils.log(level, ...) labels the text and
-- sends everything to env.info. Routing that one function into the VEAF logger is what
-- puts CTLD's verbosity — and its startup report — under veaf.config.ctld.logLevel.
-- ---------------------------------------------------------------------------
TestVeafCtldIntegration = {}

function TestVeafCtldIntegration:setUp()
  self._savedLog = ctld.utils.log
  self._savedInit = ctld.initialize
  self._calls = {}
  local calls = self._calls
  self._logger = { captured = {} }
  for _, level in ipairs({ "error", "warn", "info", "debug", "trace" }) do
    self._logger[level] = function(_, message)
      table.insert(calls, { level = level, message = message })
    end
  end
  self._savedGet = veaf.loggers.get
  veaf.loggers.get = function(id)
    if id == veaf.ctldId then
      return self._logger
    end
    return self._savedGet(id)
  end
end

function TestVeafCtldIntegration:tearDown()
  ctld.utils.log = self._savedLog
  ctld.initialize = self._savedInit
  veaf.loggers.get = self._savedGet
end

function TestVeafCtldIntegration:test_registers_itself_as_a_veaf_module()
  -- Registered rather than started on load: the framework then owns its ordering, its
  -- enable flag and its logLevel, like any other module.
  luaunit.assertNotNil(veaf.modules[veaf.ctldId])
  luaunit.assertTrue(veaf.modules[veaf.ctldId].order < 150) -- before veafGrass / veafAssets
end

function TestVeafCtldIntegration:test_log_levels_map_onto_the_veaf_logger()
  veaf.ctld_initialize()
  ctld.utils.log("ERROR", "bad")
  ctld.utils.log("WARN", "careful")
  ctld.utils.log("DEBUG", "noisy")
  luaunit.assertEquals(self._calls[1], { level = "error", message = "bad" })
  luaunit.assertEquals(self._calls[2], { level = "warn", message = "careful" })
  luaunit.assertEquals(self._calls[3], { level = "debug", message = "noisy" })
end

function TestVeafCtldIntegration:test_unknown_level_falls_back_to_info()
  -- Indexing the logger with an unmapped level would be a nil call — inside a log
  -- statement, i.e. exactly where a crash is hardest to read.
  veaf.ctld_initialize()
  ctld.utils.log("VERBOSE", "hello")
  luaunit.assertEquals(self._calls[1].level, "info")
end

function TestVeafCtldIntegration:test_initialize_runs_after_the_override_is_installed()
  local seenOverride = false
  ctld.initialize = function()
    seenOverride = ctld.utils.log ~= self._savedLog
  end
  veaf.ctld_initialize()
  luaunit.assertTrue(seenOverride, "startup report must be logged through the VEAF logger")
end

function TestVeafCtldIntegration:test_missing_engine_is_reported_not_crashed()
  local saved = ctld
  ctld = nil
  local ok = pcall(veaf.ctld_initialize)
  ctld = saved
  luaunit.assertTrue(ok)
end

-- ---------------------------------------------------------------------------
-- ---------------------------------------------------------------------------
-- veaf.outTextForUnit — the floor under every pilot-facing message
--
-- trigger.action.outText* raises on a nil message, so a caller with nothing to say produced a DCS
-- scripting error from a *display* call, reading in dcs.log as a bug in whatever feature was talking.
-- That is how issue #302's crash survived its own fix: the guard went where the value is computed and
-- the nil travelled one level further (FIX-ATIS-NIL-MESSAGE, from MacFlorent's PR #303).
-- ---------------------------------------------------------------------------
TestVeafOutTextFloor = {}

function TestVeafOutTextFloor:setUp()
  dcs_mocks.reset()
end

function TestVeafOutTextFloor:test_a_nil_message_never_reaches_dcs()
  veaf.outTextForUnit(nil, nil, 10)
  luaunit.assertEquals(#dcs_mocks.messages, 0, "a nil message must not be forwarded to DCS")
end

function TestVeafOutTextFloor:test_a_blank_message_never_reaches_dcs()
  -- Whitespace only is the same defect wearing a disguise: the pilot sees an empty box and the caller
  -- looks like it worked.
  veaf.outTextForUnit(nil, "   \n\t ", 10)
  luaunit.assertEquals(#dcs_mocks.messages, 0)
end

function TestVeafOutTextFloor:test_the_group_variant_inherits_the_floor()
  -- It delegates, so one guard covers both — pinned so a future refactor cannot split them apart.
  veaf.outTextForGroup(nil, nil, 10)
  luaunit.assertEquals(#dcs_mocks.messages, 0)
end

function TestVeafOutTextFloor:test_a_real_message_still_gets_through_untouched()
  veaf.outTextForUnit(nil, "ATIS Alpha, wind calm", 30)
  luaunit.assertEquals(#dcs_mocks.messages, 1)
  luaunit.assertEquals(dcs_mocks.messages[1].text, "ATIS Alpha, wind calm")
  luaunit.assertEquals(dcs_mocks.messages[1].duration, 30)
end

function TestVeafOutTextFloor:test_zero_is_a_message_not_an_absence()
  -- The guard must key on nil and blank, not on falsiness or emptiness in general: a caller reporting
  -- a count of 0 has something to say.
  veaf.outTextForUnit(nil, "0", 5)
  luaunit.assertEquals(#dcs_mocks.messages, 1)
end

-- veaf.findSpawnPoint — three-tier search (FEAT-SCENERY-AWARE-SPAWN)
--
-- Tier 1 asks the undocumented Disposition singleton for scenery-clear points,
-- tier 2 jitters with mist.getRandPointInCircle, tier 3 gives up and returns nil.
-- Every degradation path is pinned here, the "singleton absent" one above all:
-- it is what ships to any DCS install that does not expose Disposition.
-- ---------------------------------------------------------------------------
TestVeafFindSpawnPoint = {}

function TestVeafFindSpawnPoint:setUp()
  self._savedDisposition = Disposition
  self._savedGetSurfaceType = land.getSurfaceType
  self._savedGetRandPoint = mist.getRandPointInCircle
  self._savedOptOut = veaf.doNotAvoidScenery
  Disposition = nil
  veaf.doNotAvoidScenery = false
  -- Land everywhere unless a test says otherwise.
  land.getSurfaceType = function()
    return land.SurfaceType.LAND
  end
  self._jitterCalls = 0
end

function TestVeafFindSpawnPoint:tearDown()
  Disposition = self._savedDisposition
  land.getSurfaceType = self._savedGetSurfaceType
  mist.getRandPointInCircle = self._savedGetRandPoint
  veaf.doNotAvoidScenery = self._savedOptOut
end

--- Makes land.getSurfaceType answer WATER for every point whose x is in `waterXs`.
function TestVeafFindSpawnPoint:_waterAt(waterXs)
  local water = {}
  for _, x in ipairs(waterXs) do
    water[x] = true
  end
  land.getSurfaceType = function(vec2)
    if water[vec2.x] then
      return land.SurfaceType.WATER
    end
    return land.SurfaceType.LAND
  end
end

--- Makes the jitter walk a fixed list of x offsets, one per call.
function TestVeafFindSpawnPoint:_jitterSequence(xs)
  local calls = 0
  mist.getRandPointInCircle = function(spot, _r)
    calls = calls + 1
    self._jitterCalls = calls
    local x = xs[calls] or xs[#xs]
    return { x = x, y = 0, z = spot.z or 0 }
  end
end

function TestVeafFindSpawnPoint:test_singleton_absent_falls_through_to_the_jitter()
  self:_jitterSequence({ 500 })
  local point = veaf.findSpawnPoint({ x = 0, y = 0, z = 0 }, 1000)
  luaunit.assertNotNil(point)
  luaunit.assertEquals(point.x, 500)
  luaunit.assertEquals(self._jitterCalls, 1)
end

function TestVeafFindSpawnPoint:test_singleton_absent_result_is_placed_on_land()
  self:_jitterSequence({ 500 })
  local point = veaf.findSpawnPoint({ x = 0, y = 0, z = 0 }, 1000)
  -- placePointOnLand puts the terrain height in y; the mock's getHeight + 1 m margin.
  luaunit.assertEquals(point.y, math.floor(land.getHeight({ x = 500, y = 0 }) + 1))
end

function TestVeafFindSpawnPoint:test_jitter_retries_until_it_finds_land()
  self:_waterAt({ 100, 200 })
  self:_jitterSequence({ 100, 200, 300 })
  local point = veaf.findSpawnPoint({ x = 0, y = 0, z = 0 }, 1000)
  luaunit.assertNotNil(point)
  luaunit.assertEquals(point.x, 300, "must skip the two water candidates")
  luaunit.assertEquals(self._jitterCalls, 3)
end

function TestVeafFindSpawnPoint:test_no_acceptable_point_anywhere_returns_nil()
  land.getSurfaceType = function()
    return land.SurfaceType.WATER
  end
  self:_jitterSequence({ 100 })
  local point = veaf.findSpawnPoint({ x = 0, y = 0, z = 0 }, 1000)
  luaunit.assertNil(point)
  luaunit.assertEquals(self._jitterCalls, veaf.SPAWN_SEARCH_ATTEMPTS, "the jitter tier must be bounded")
end

function TestVeafFindSpawnPoint:test_singleton_proposal_wins_over_the_jitter()
  Disposition = {
    getSimpleZones = function()
      return { { x = 42, y = 0, z = 7 } }
    end,
  }
  self:_jitterSequence({ 999 })
  local point = veaf.findSpawnPoint({ x = 0, y = 0, z = 0 }, 1000)
  luaunit.assertEquals(point.x, 42)
  luaunit.assertEquals(point.z, 7)
  luaunit.assertEquals(self._jitterCalls, 0, "the jitter tier must not run when tier 1 succeeds")
end

function TestVeafFindSpawnPoint:test_singleton_returning_nothing_falls_through()
  Disposition = {
    getSimpleZones = function()
      return {}
    end,
  }
  self:_jitterSequence({ 500 })
  local point = veaf.findSpawnPoint({ x = 0, y = 0, z = 0 }, 1000)
  luaunit.assertEquals(point.x, 500)
end

function TestVeafFindSpawnPoint:test_singleton_throwing_falls_through_without_propagating()
  Disposition = {
    getSimpleZones = function()
      error("undocumented API changed its signature")
    end,
  }
  self:_jitterSequence({ 500 })
  local ok, point = pcall(veaf.findSpawnPoint, { x = 0, y = 0, z = 0 }, 1000)
  luaunit.assertTrue(ok, "a broken singleton must never propagate out of the helper")
  luaunit.assertEquals(point.x, 500)
end

function TestVeafFindSpawnPoint:test_singleton_proposing_water_is_rejected()
  self:_waterAt({ 42 })
  Disposition = {
    getSimpleZones = function()
      return { { x = 42, y = 0, z = 0 } }
    end,
  }
  self:_jitterSequence({ 500 })
  local point = veaf.findSpawnPoint({ x = 0, y = 0, z = 0 }, 1000)
  luaunit.assertEquals(point.x, 500, "Disposition is not guaranteed to respect water")
end

function TestVeafFindSpawnPoint:test_opt_out_skips_the_singleton_entirely()
  local called = false
  Disposition = {
    getSimpleZones = function()
      called = true
      return { { x = 42, y = 0, z = 0 } }
    end,
  }
  veaf.doNotAvoidScenery = true
  self:_jitterSequence({ 500 })
  local point = veaf.findSpawnPoint({ x = 0, y = 0, z = 0 }, 1000)
  luaunit.assertFalse(called)
  luaunit.assertEquals(point.x, 500)
end

function TestVeafFindSpawnPoint:test_singleton_is_asked_for_several_candidates()
  local askedFor
  Disposition = {
    getSimpleZones = function(_centre, _searchRadius, _exclusionRadius, count)
      askedFor = count
      return { { x = 42, y = 0, z = 0 } }
    end,
  }
  veaf.findSpawnPoint({ x = 0, y = 0, z = 0 }, 1000)
  luaunit.assertEquals(askedFor, veaf.SPAWN_SEARCH_ATTEMPTS)
end

-- ---------------------------------------------------------------------------
-- The distance filter (measured in a live DCS, 2026-08-06)
--
-- Disposition's radius argument is NOT a bound. Measured around one centre in wooded
-- terrain: asked for 800 m it returned points 2035-2258 m out, and asked for 1600 m with
-- a count of **one** it still returned a point 2628 m out — so the overshoot is not the
-- count forcing a wider search, the radius simply does not cap anything.
--
-- Tier 1 used to take the first candidate that was on land, with no distance test at all,
-- so `_spawn group, radius 50` in a forest could place the group kilometres away in
-- silence. ADR 0018 requires this dependency to be quality-only and never correctness;
-- moving a group somewhere nobody asked for is a correctness regression.
-- ---------------------------------------------------------------------------

function TestVeafFindSpawnPoint:test_candidate_beyond_the_caller_radius_is_rejected()
  -- 2628 m is the real measurement, not a round number invented for the test.
  Disposition = {
    getSimpleZones = function()
      return { { x = 2628, y = 0, z = 0 } }
    end,
  }
  self:_jitterSequence({ 500 })
  local point = veaf.findSpawnPoint({ x = 0, y = 0, z = 0 }, 1000)
  luaunit.assertEquals(point.x, 500, "a candidate outside the requested radius must not be used")
  luaunit.assertEquals(self._jitterCalls, 1, "it must fall through to the jitter tier")
end

function TestVeafFindSpawnPoint:test_candidate_within_the_caller_radius_is_accepted()
  Disposition = {
    getSimpleZones = function()
      return { { x = 900, y = 0, z = 0 } }
    end,
  }
  self:_jitterSequence({ 500 })
  local point = veaf.findSpawnPoint({ x = 0, y = 0, z = 0 }, 1000)
  luaunit.assertEquals(point.x, 900)
  luaunit.assertEquals(self._jitterCalls, 0)
end

function TestVeafFindSpawnPoint:test_the_nearest_acceptable_candidate_is_not_required_only_a_near_one()
  -- The far one comes first in the array; the filter must keep looking rather than give up.
  Disposition = {
    getSimpleZones = function()
      return { { x = 5000, y = 0, z = 0 }, { x = 300, y = 0, z = 0 } }
    end,
  }
  self:_jitterSequence({ 500 })
  local point = veaf.findSpawnPoint({ x = 0, y = 0, z = 0 }, 1000)
  luaunit.assertEquals(point.x, 300)
end

function TestVeafFindSpawnPoint:test_distance_is_horizontal_so_terrain_height_cannot_defeat_it()
  -- placePointOnLand writes the terrain height into y. Measuring in 3D would let a hill
  -- push a perfectly good candidate out of range.
  Disposition = {
    getSimpleZones = function()
      return { { x = 0, y = 0, z = 999 } }
    end,
  }
  self:_jitterSequence({ 500 })
  local point = veaf.findSpawnPoint({ x = 0, y = 0, z = 0 }, 1000)
  luaunit.assertEquals(point.z, 999)
end

function TestVeafFindSpawnPoint:test_a_zero_radius_keeps_the_singleton_out_of_it()
  -- radius 0 is what veafSpawn passes for farp, cargo, teleport, bomb, smoke and friends:
  -- "exactly here, the mission maker means it". Tier 1 exists to move a point; it must not.
  local called = false
  Disposition = {
    getSimpleZones = function()
      called = true
      return { { x = 42, y = 0, z = 0 } }
    end,
  }
  self:_jitterSequence({ 0 })
  local point = veaf.findSpawnPoint({ x = 0, y = 0, z = 0 }, 0)
  luaunit.assertFalse(called, "a zero radius must not even ask")
  luaunit.assertEquals(point.x, 0)
end

function TestVeafFindSpawnPoint:test_the_singleton_is_asked_within_the_caller_radius()
  -- It used to be asked for math.max(1852, safeRadius * 5) regardless of what the caller
  -- wanted, which is where the silent widening started.
  local askedRadius
  Disposition = {
    getSimpleZones = function(_centre, searchRadius)
      askedRadius = searchRadius
      return {}
    end,
  }
  self:_jitterSequence({ 500 })
  veaf.findSpawnPoint({ x = 0, y = 0, z = 0 }, 250)
  luaunit.assertEquals(askedRadius, 250)
end

function TestVeafFindSpawnPoint:test_the_measured_vec2_shape_is_understood()
  -- What the real API returns, measured: {x, y, course} — a vec2 plus a heading, no z.
  -- Its y is the map's z, so reading it as an altitude would put the group 200 m up and
  -- leave the distance filter comparing the wrong axis.
  Disposition = {
    getSimpleZones = function()
      return { { x = 100, y = 200, course = 1.57 } }
    end,
  }
  self:_jitterSequence({ 500 })
  local point = veaf.findSpawnPoint({ x = 0, y = 0, z = 0 }, 1000)
  luaunit.assertEquals(point.x, 100)
  luaunit.assertEquals(point.z, 200, "the candidate's y is the map's z")
end

function TestVeafFindSpawnPoint:test_a_vec2_centre_is_measured_against_the_right_axis()
  -- Callers do pass vec2 centres. Reading the centre's y as an altitude would make the
  -- distance nonsense in exactly the case the filter matters.
  Disposition = {
    getSimpleZones = function()
      return { { x = 0, y = 900, course = 0 } }
    end,
  }
  self:_jitterSequence({ 500 })
  -- Centre vec2 {x=0, y=1000} means map z=1000; candidate y=900 means map z=900. That is 100 m
  -- apart, inside the 200 m radius, so it must be accepted. Read the centre's y as an altitude
  -- instead and the distance becomes 900 — rejected, and the filter would misfire everywhere.
  local point = veaf.findSpawnPoint({ x = 0, y = 1000 }, 200)
  luaunit.assertEquals(self._jitterCalls, 0, "100 m apart is inside a 200 m radius")
  luaunit.assertEquals(point.z, 900)
end

function TestVeafFindSpawnPoint:test_malformed_candidates_do_not_raise()
  -- The singleton is undocumented and its return shape unmeasured, so a flat array of
  -- numbers has to degrade like an empty one. placePointOnLand would raise on these, and
  -- the pcall only wraps the call to getSimpleZones, not the loop over its result.
  Disposition = {
    getSimpleZones = function()
      return { 1, 2, 3 }
    end,
  }
  self:_jitterSequence({ 500 })
  local ok, point = pcall(veaf.findSpawnPoint, { x = 0, y = 0, z = 0 }, 1000)
  luaunit.assertTrue(ok, "a malformed candidate must not propagate out of the helper")
  luaunit.assertEquals(point.x, 500)
end

function TestVeafFindSpawnPoint:test_first_clear_candidate_of_several_is_taken()
  self:_waterAt({ 10, 20 })
  Disposition = {
    getSimpleZones = function()
      return { { x = 10, y = 0, z = 0 }, { x = 20, y = 0, z = 0 }, { x = 30, y = 0, z = 0 } }
    end,
  }
  self:_jitterSequence({ 500 })
  local point = veaf.findSpawnPoint({ x = 0, y = 0, z = 0 }, 1000)
  luaunit.assertEquals(point.x, 30)
  luaunit.assertEquals(self._jitterCalls, 0)
end

-- ---------------------------------------------------------------------------
-- Trigger-zone properties (FEAT-SCENERY-AWARE-SPAWN ticket 04)
--
-- DCS hands properties over as an array of string pairs, so a caller would otherwise
-- write its own linear scan plus its own tonumber / "true" comparison every time.
-- ---------------------------------------------------------------------------
TestVeafZoneProperties = {}

function TestVeafZoneProperties:setUp()
  self._saved = veaf.triggerZones
  veaf.triggerZones = {
    ["Alpha"] = {
      name = "Alpha",
      properties = {
        { key = "smoke", value = "true" },
        { key = "hidden", value = "FALSE" },
        { key = "radius", value = "800" },
        { key = "ratio", value = "1.5" },
        { key = "label", value = "not a number" },
      },
    },
    ["Bare"] = { name = "Bare" },
  }
end

function TestVeafZoneProperties:tearDown()
  veaf.triggerZones = self._saved
end

function TestVeafZoneProperties:test_raw_property_is_returned_as_a_string()
  luaunit.assertEquals(veaf.getZoneProperty("Alpha", "radius"), "800")
end

function TestVeafZoneProperties:test_missing_key_is_nil()
  luaunit.assertNil(veaf.getZoneProperty("Alpha", "nope"))
end

function TestVeafZoneProperties:test_missing_zone_is_nil()
  luaunit.assertNil(veaf.getZoneProperty("Ghost", "radius"))
end

function TestVeafZoneProperties:test_zone_without_properties_is_nil()
  luaunit.assertNil(veaf.getZoneProperty("Bare", "radius"))
end

function TestVeafZoneProperties:test_boolean_true()
  luaunit.assertTrue(veaf.getZonePropertyBoolean("Alpha", "smoke", false))
end

function TestVeafZoneProperties:test_boolean_is_case_insensitive()
  luaunit.assertFalse(veaf.getZonePropertyBoolean("Alpha", "hidden", true))
end

function TestVeafZoneProperties:test_boolean_junk_falls_back_to_the_default_not_to_false()
  luaunit.assertTrue(veaf.getZonePropertyBoolean("Alpha", "label", true))
end

function TestVeafZoneProperties:test_boolean_missing_key_returns_the_default()
  luaunit.assertTrue(veaf.getZonePropertyBoolean("Alpha", "nope", true))
end

function TestVeafZoneProperties:test_number_is_parsed()
  luaunit.assertEquals(veaf.getZonePropertyNumber("Alpha", "radius", 0), 800)
end

function TestVeafZoneProperties:test_number_accepts_decimals()
  luaunit.assertEquals(veaf.getZonePropertyNumber("Alpha", "ratio", 0), 1.5)
end

function TestVeafZoneProperties:test_number_junk_returns_the_default()
  luaunit.assertEquals(veaf.getZonePropertyNumber("Alpha", "label", 42), 42)
end

function TestVeafZoneProperties:test_number_is_clamped_to_the_upper_bound()
  luaunit.assertEquals(veaf.getZonePropertyNumber("Alpha", "radius", 0, 0, 500), 500)
end

function TestVeafZoneProperties:test_number_is_clamped_to_the_lower_bound()
  luaunit.assertEquals(veaf.getZonePropertyNumber("Alpha", "radius", 0, 1000, 2000), 1000)
end

function TestVeafZoneProperties:test_number_within_bounds_is_untouched()
  luaunit.assertEquals(veaf.getZonePropertyNumber("Alpha", "radius", 0, 0, 1000), 800)
end

-- ---------------------------------------------------------------------------
-- Run
-- ---------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------
-- SECREV-2 group A — marker parameters must not be able to crash their handler
--
-- The review recommended validating in "the shared marker parser". There is none: ten modules
-- carry their own `markTextAnalysis`. Rewriting all ten is a different lot, so the shared piece
-- is the conversion itself -- one tested helper the call sites use -- which is the part that
-- was being written wrong each time.
--
-- The crash shapes seen in the wild: `string.format("%d", nil)` on a valueless keyword, and
-- `tonumber(val) <= 5` comparing nil with a number.
-------------------------------------------------------------------------------------------------

TestVeafSafeNumber = {}

function TestVeafSafeNumber:test_parses_a_plain_number()
  luaunit.assertEquals(veaf.safeNumber("3"), 3)
end

function TestVeafSafeNumber:test_accepts_a_number_as_is()
  luaunit.assertEquals(veaf.safeNumber(4), 4)
end

function TestVeafSafeNumber:test_nil_returns_the_default()
  -- A player writing "size" with no value: the exact VMR-019 shape.
  luaunit.assertEquals(veaf.safeNumber(nil, { default = 2 }), 2)
end

function TestVeafSafeNumber:test_garbage_returns_the_default()
  luaunit.assertEquals(veaf.safeNumber("banana", { default = 2 }), 2)
end

function TestVeafSafeNumber:test_nil_without_a_default_is_nil()
  luaunit.assertNil(veaf.safeNumber(nil))
end

function TestVeafSafeNumber:test_below_the_minimum_is_clamped()
  luaunit.assertEquals(veaf.safeNumber("0", { min = 1, max = 5, default = 1 }), 1)
end

function TestVeafSafeNumber:test_above_the_maximum_is_clamped()
  luaunit.assertEquals(veaf.safeNumber("9", { min = 1, max = 5, default = 1 }), 5)
end

function TestVeafSafeNumber:test_inside_the_range_is_untouched()
  luaunit.assertEquals(veaf.safeNumber("3", { min = 1, max = 5, default = 1 }), 3)
end

function TestVeafSafeNumber:test_boundaries_are_inclusive()
  luaunit.assertEquals(veaf.safeNumber("1", { min = 1, max = 5 }), 1)
  luaunit.assertEquals(veaf.safeNumber("5", { min = 1, max = 5 }), 5)
end

function TestVeafSafeNumber:test_negative_values_survive_when_allowed()
  luaunit.assertEquals(veaf.safeNumber("-20", { min = -50, max = 50 }), -20)
end

function TestVeafSafeNumber:test_decimals_survive()
  luaunit.assertEquals(veaf.safeNumber("2.5", { min = 0, max = 5 }), 2.5)
end

function TestVeafSafeNumber:test_a_table_returns_the_default()
  luaunit.assertEquals(veaf.safeNumber({}, { default = 7 }), 7)
end

function TestVeafSafeNumber:test_boolean_returns_the_default()
  -- `true` is what a valueless keyword often becomes before it reaches the conversion.
  luaunit.assertEquals(veaf.safeNumber(true, { default = 7 }), 7)
end

-------------------------------------------------------------------------------------------------
-- FIX-MARKER-PARAM-CRASHES — safeNumberInRange rejects out-of-range values where safeNumber
-- clamps them. Marker keywords need the rejecting form: an out-of-range `size` keeps the
-- command's default instead of silently becoming the nearest bound.
-------------------------------------------------------------------------------------------------

TestVeafSafeNumberInRange = {}

function TestVeafSafeNumberInRange:test_accepts_a_value_in_range()
  luaunit.assertEquals(veaf.safeNumberInRange("3", 1, 5), 3)
end

function TestVeafSafeNumberInRange:test_bounds_are_inclusive()
  luaunit.assertEquals(veaf.safeNumberInRange("1", 1, 5), 1)
  luaunit.assertEquals(veaf.safeNumberInRange("5", 1, 5), 5)
end

function TestVeafSafeNumberInRange:test_rejects_below_min()
  luaunit.assertNil(veaf.safeNumberInRange("0", 1, 5))
end

function TestVeafSafeNumberInRange:test_rejects_above_max()
  luaunit.assertNil(veaf.safeNumberInRange("42", 1, 5))
end

-- The distinction from safeNumber that justifies a second function.
function TestVeafSafeNumberInRange:test_out_of_range_is_rejected_not_clamped()
  luaunit.assertNil(veaf.safeNumberInRange("42", 1, 5))
  luaunit.assertEquals(veaf.safeNumber("42", { min = 1, max = 5 }), 5)
end

function TestVeafSafeNumberInRange:test_rejects_a_valueless_keyword()
  luaunit.assertNil(veaf.safeNumberInRange(nil, 1, 5))
end

function TestVeafSafeNumberInRange:test_rejects_a_non_numeric_value()
  luaunit.assertNil(veaf.safeNumberInRange("banana", 1, 5))
end

function TestVeafSafeNumberInRange:test_accepts_zero_when_min_is_zero()
  -- `defense` and `blocade` accept 0 where `size` and `spacing` start at 1.
  luaunit.assertEquals(veaf.safeNumberInRange("0", 0, 5), 0)
end

function TestVeafSafeNumberInRange:test_accepts_a_decimal_in_range()
  luaunit.assertEquals(veaf.safeNumberInRange("2.5", 0, 5), 2.5)
end

-------------------------------------------------------------------------------------------------
-- SECREV-2 / VMR-082 — split and breakString built patterns by interpolating the separator
--
--     local regex = ("([^%s]+)"):format(sep)
--
-- puts `sep` straight inside a character class, so a Lua-magic separator changes what the class
-- means: "]" closes it early, "%" starts an escape, "^" negates. Every separator used inside this
-- repository is a comma, a space or a semicolon — all harmless — but both functions are public
-- API a mission can call with anything.
-------------------------------------------------------------------------------------------------

TestVeafSplitMagicSeparators = {}

function TestVeafSplitMagicSeparators:test_split_on_a_comma_still_works()
  local r = veaf.split("a,b,c", ",")
  luaunit.assertEquals(#r, 3)
  luaunit.assertEquals(r[1], "a")
  luaunit.assertEquals(r[3], "c")
end

function TestVeafSplitMagicSeparators:test_split_on_a_space_still_works()
  luaunit.assertEquals(#veaf.split("a b c", " "), 3)
end

function TestVeafSplitMagicSeparators:test_split_on_a_dash()
  local r = veaf.split("a-b-c", "-")
  luaunit.assertEquals(#r, 3)
  luaunit.assertEquals(r[2], "b")
end

function TestVeafSplitMagicSeparators:test_split_on_a_percent()
  local r = veaf.split("a%b%c", "%")
  luaunit.assertEquals(#r, 3)
  luaunit.assertEquals(r[2], "b")
end

function TestVeafSplitMagicSeparators:test_split_on_a_bracket()
  local r = veaf.split("a]b]c", "]")
  luaunit.assertEquals(#r, 3)
  luaunit.assertEquals(r[2], "b")
end

function TestVeafSplitMagicSeparators:test_break_string_on_a_comma_still_works()
  local r = veaf.breakString("key,value", ",")
  luaunit.assertEquals(r[1], "key")
  luaunit.assertEquals(r[2], "value")
end

function TestVeafSplitMagicSeparators:test_break_string_on_a_dash()
  local r = veaf.breakString("key-value", "-")
  luaunit.assertEquals(r[1], "key")
  luaunit.assertEquals(r[2], "value")
end

-------------------------------------------------------------------------------------------------
-- SECREV-2 / VMR-084 — the vec3/vec2 pretty-print in veaf.p could never run
--
--     if o and type(o) == "table" and (o.x and o.z and o.y and #o == 3) then
--
-- `#` counts a table's *sequence* part, so a table holding only the named keys x/y/z has #o == 0.
-- The condition was never true and every vec3 fell through to the generic dump.
-------------------------------------------------------------------------------------------------

TestVeafPrettyPrintVectors = {}

function TestVeafPrettyPrintVectors:test_vec3_is_pretty_printed()
  local s = veaf.p({ x = 1, y = 2, z = 3 })
  luaunit.assertStrContains(s, "x=1")
  luaunit.assertStrContains(s, "y=2")
  luaunit.assertStrContains(s, "z=3")
end

function TestVeafPrettyPrintVectors:test_vec3_is_a_single_line()
  -- The point of the branch: a coordinate should read as one value, not a multi-line dump.
  local s = veaf.p({ x = 1, y = 2, z = 3 })
  luaunit.assertNil(s:find(string.char(10)))
end

function TestVeafPrettyPrintVectors:test_vec2_is_pretty_printed()
  local s = veaf.p({ x = 10, y = 20 })
  luaunit.assertStrContains(s, "x=10")
  luaunit.assertStrContains(s, "y=20")
end

function TestVeafPrettyPrintVectors:test_a_normal_table_is_untouched()
  -- Guard: only coordinate-shaped tables take the short path.
  local s = veaf.p({ name = "test", value = 1 })
  luaunit.assertStrContains(s, "name")
end

-- ============================================================================
-- TestVeafExportAsJsonUnwritablePath -- SECREV-2 / VMR-081
-- ============================================================================
--- The `if file then` guard used to sit *after* three writeln() calls, so an export directory that
--- could not be opened raised "attempt to index a nil value" inside a script running in DCS. io is
--- the real one here, not a mock, so this exercises a genuine open failure.
TestVeafExportAsJsonUnwritablePath = {}

local function jsonifyPair(key, value)
  return '    { "' .. tostring(key) .. '": "' .. tostring(value) .. '" }'
end

function TestVeafExportAsJsonUnwritablePath:test_an_unwritable_directory_is_reported_not_raised()
  local ok, err = pcall(veaf.exportAsJson, { a = 1 }, "things", jsonifyPair, "things.json", "Z:/veaf-no-such-directory/nested/")

  luaunit.assertTrue(ok, "an unwritable export path must be reported, not raised: " .. tostring(err))
end

function TestVeafExportAsJsonUnwritablePath:test_a_writable_directory_still_produces_the_file()
  -- The guard must not have turned the happy path into a silent no-op.
  local dir = os.getenv("TEMP") or os.getenv("TMPDIR") or "."
  local filename = "veaf-test-export.json"
  local path = dir .. "/" .. filename
  os.remove(path)

  veaf.exportAsJson({ a = 1 }, "things", jsonifyPair, filename, dir .. "/")

  local written = io.open(path, "r")
  luaunit.assertNotNil(written, "the export must still be written when the directory is writable")
  local content = written:read("*a")
  written:close()
  os.remove(path)
  luaunit.assertNotNil(string.find(content, "things", 1, true), "the export must name the exported table")
end

os.exit(luaunit.LuaUnit.run())
