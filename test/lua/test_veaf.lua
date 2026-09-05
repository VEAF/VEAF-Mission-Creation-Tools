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
dofile(_base .. "/../../src/scripts/veaf/veafScheduler.lua")
dofile(_base .. "/../../src/scripts/veaf/veafMath.lua")
dofile(_base .. "/../../src/scripts/veaf/veafGeo.lua")
dofile(_base .. "/../../src/scripts/veaf/veafMissionDb.lua")
-- The i18n catalog: `veaf.reportUnknownParameters` builds a localised message, so the tests below
-- need the entries rather than the raw keys.
dofile(_base .. "/../../src/scripts/veaf/veafI18n.lua")
-- The generated DCS unit database, for the one test that checks the real attributes agree with
-- what veaf.isGroupCombatEffective relies on. Every other test in that class swaps in a minimal
-- stand-in, so this only has to be loadable.
dofile(_base .. "/../../src/scripts/veaf/dcsUnits.lua")

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

-- FEAT-INTERPRETER-PARITY found this while widening the combat-zone tag patterns, but it is not a new
-- defect: an open-ended range raises **today** from any marker command, since the missing upper bound
-- falls back to MAX = 99 and `math.random(100, 99)` is "interval is empty".
--
--   _spawn group, name x, size 100-      →  bad argument #2 to 'random' (interval is empty)
--
-- An upper bound below the lower one now means the lower one, warned about rather than raised on. Same
-- for a reversed range, which is a typo with an obvious intent.
TestVeafRandomizableNumericDegenerateRanges = {}

function TestVeafRandomizableNumericDegenerateRanges:test_an_open_range_above_the_default_max_does_not_raise()
  local v = veaf.getRandomizableNumeric_random("100-")
  luaunit.assertEquals(v, 100, "an absent upper bound cannot mean less than the lower one")
end

function TestVeafRandomizableNumericDegenerateRanges:test_an_open_range_below_the_default_max_still_draws()
  for _ = 1, 20 do
    local v = veaf.getRandomizableNumeric_random("10-")
    luaunit.assertTrue(v >= 10 and v <= 99, "value " .. tostring(v) .. " out of [10,99]")
  end
end

function TestVeafRandomizableNumericDegenerateRanges:test_a_reversed_range_yields_its_lower_bound()
  luaunit.assertEquals(veaf.getRandomizableNumeric_random("5-2"), 5)
end

function TestVeafRandomizableNumericDegenerateRanges:test_a_single_value_range_is_that_value()
  luaunit.assertEquals(veaf.getRandomizableNumeric_random("7-7"), 7)
end

-- The degenerate forms the widened tag pattern can capture, enumerated rather than sampled: every one
-- of them must return a number, because the callers store it and compare it.
function TestVeafRandomizableNumericDegenerateRanges:test_every_dash_only_form_returns_a_number()
  for _, form in ipairs({ "-", "--", "-300", "0-0", "100-", "3-1" }) do
    local v = veaf.getRandomizableNumeric_random(form)
    luaunit.assertIsNumber(v, "form '" .. form .. "' must yield a number, not nil and not an error")
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
  -- 42 + 23/60 + 45/3600 = 42.3958333 exactly.
  --
  -- This test used to say "function has ~1 arcsec offset **by design**" and widen its range to
  -- 42.39 < lat < 42.40 to tolerate it. It was not by design: an accumulator started at -1, so every DMS
  -- coordinate in every VEAF mission since 2021 landed about 31 m north of where it was meant. The
  -- comment was written during a coverage push (2026-05-23) — the defect was measured, then documented
  -- instead of reported. Asserted exactly now, so it cannot come back wearing the same excuse.
  local lat, lon = veaf.computeLLFromString("N42:23:45E044:12:00")
  luaunit.assertAlmostEquals(lat, 42.3958333, 0.0000005)
  luaunit.assertAlmostEquals(lon, 44.2, 0.0000005)
end

function TestVeafComputeLLFromString:test_llDMDecimal()
  -- Degrees and decimal minutes: 42 + 23.5/60 = 42.3916667. Was asserted only as "between 42 and 43",
  -- which a reader off by half a degree would also have passed.
  local lat, lon = veaf.computeLLFromString("N42-23.5E044-12.5")
  luaunit.assertAlmostEquals(lat, 42.3916667, 0.0000005)
  luaunit.assertAlmostEquals(lon, 44.2083333, 0.0000005)
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
  -- This one asserts variety, so it needs Lua's own generator: the mocks make `math.random`
  -- deterministic by default, which is what lets every other suite reason about a drawn point.
  dcs_mocks.useRealRandom()
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
  -- A blank config is this suite's own starting point, and it must be put back: `test_enable_false_disables`
  -- leaves `ctld.enable = false` behind, and `veaf.isCtldReady()` reads exactly that. Walking away from it
  -- silently switches CTLD off for every suite that runs afterwards — `TestVeafCtldSlingloadToggle` then
  -- stops logging anything and its "the change is logged" test fails for a reason of its own.
  self._savedConfig = veaf.config
  veaf.config = {}
end

function TestVeafIsEnabled:tearDown()
  veaf.config = self._savedConfig
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
-- veaf.isCtldReady — the three states a caller has to tell apart
-- (FIX-CTLD-NEVER-INITIALIZED)
--
-- Script absent and module disabled were already handled. The third — script present, module
-- enabled, engine never started — is what a mission built before the fix lands in, and what used
-- to crash inside the vendored CTLD.lua on a configuration that was never loaded.
-- ---------------------------------------------------------------------------
TestVeafIsCtldReady = {}

function TestVeafIsCtldReady:setUp()
  dcs_mocks.reset()
  self._savedCtld = ctld
  self._savedEnable = veaf.config[veaf.ctldId] and veaf.config[veaf.ctldId].enable
  veaf._ctldNotReadyReported = false
end

function TestVeafIsCtldReady:tearDown()
  ctld = self._savedCtld
  CTLDConfig._instance.isLoaded = true
  veaf.setConfig(veaf.ctldId, "enable", self._savedEnable)
end

function TestVeafIsCtldReady:test_ready_when_loaded_enabled_and_started()
  veaf.setConfig(veaf.ctldId, "enable", true)
  luaunit.assertTrue(veaf.isCtldReady())
end

function TestVeafIsCtldReady:test_not_ready_when_the_script_is_absent()
  ctld = nil
  luaunit.assertFalse(veaf.isCtldReady())
end

function TestVeafIsCtldReady:test_not_ready_when_the_module_is_disabled()
  veaf.setConfig(veaf.ctldId, "enable", false)
  luaunit.assertFalse(veaf.isCtldReady())
end

function TestVeafIsCtldReady:test_not_ready_when_the_engine_was_never_started()
  -- The state Tripack's 6.14.0 mission was in: CTLD loaded and enabled, but nothing ever
  -- called veaf.ctld_initialize(), so its configuration is unread and every setting is nil.
  veaf.setConfig(veaf.ctldId, "enable", true)
  CTLDConfig._instance.isLoaded = false
  luaunit.assertFalse(veaf.isCtldReady())
end

function TestVeafIsCtldReady:test_an_unstarted_engine_says_what_to_do_about_it()
  -- A silent false would send the mission maker looking at their mission.yaml. The log line
  -- is the only thing that names the actual cause, so it is part of the contract.
  veaf.setConfig(veaf.ctldId, "enable", true)
  CTLDConfig._instance.isLoaded = false
  veaf.isCtldReady()
  local texts = {}
  for _, entry in ipairs(dcs_mocks.logs) do
    table.insert(texts, entry.text)
  end
  local logs = table.concat(texts, "\n")
  luaunit.assertStrContains(logs, "ctld.initialize() has not run")
  luaunit.assertStrContains(logs, "veaf.ctld_initialize()")
end

function TestVeafIsCtldReady:test_the_unstarted_engine_is_reported_once_not_once_per_call()
  -- veafSpawnAircraft's JTAC paths and veafAssets reach this guard on a timer, so a line per call
  -- would bury the rest of the log while adding nothing: the state cannot change back and forth.
  veaf.setConfig(veaf.ctldId, "enable", true)
  CTLDConfig._instance.isLoaded = false
  for _ = 1, 5 do
    veaf.isCtldReady()
  end
  local reported = 0
  for _, entry in ipairs(dcs_mocks.logs) do
    if entry.text:find("ctld.initialize() has not run", 1, true) then
      reported = reported + 1
    end
  end
  luaunit.assertEquals(reported, 1)
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
-- tier 2 jitters with veaf.getRandomPointInCircle, tier 3 gives up and returns nil.
-- Every degradation path is pinned here, the "singleton absent" one above all:
-- it is what ships to any DCS install that does not expose Disposition.
-- ---------------------------------------------------------------------------
TestVeafFindSpawnPoint = {}

function TestVeafFindSpawnPoint:setUp()
  self._savedDisposition = Disposition
  self._savedGetSurfaceType = land.getSurfaceType
  self._savedGetRandPoint = veaf.getRandomPointInCircle
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
  veaf.getRandomPointInCircle = self._savedGetRandPoint
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
  veaf.getRandomPointInCircle = function(spot, _r)
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

-- CHORE-ONE-TERRAIN-CHECK — what `acceptableGroundPoint` accepts **today**, enumerated.
--
-- It rejects WATER and nothing else, so SHALLOW_WATER passes: the CSAR decision of
-- FIX-CSAR-SPAWNS-ON-WATER, "a survivor wading a few metres off a beach is rescuable". Sampling three
-- surfaces would not catch a rewrite that turned the test into a positive list and forgot one of them,
-- so all five are asked.
function TestVeafFindSpawnPoint:test_every_surface_but_open_water_is_acceptable_ground()
  for _, name in ipairs({ "LAND", "SHALLOW_WATER", "ROAD", "RUNWAY" }) do
    land.getSurfaceType = function()
      return land.SurfaceType[name]
    end
    self:_jitterSequence({ 700 })
    luaunit.assertNotNil(veaf.findSpawnPoint({ x = 0, y = 0, z = 0 }, 1000), name .. " must be acceptable ground")
  end

  land.getSurfaceType = function()
    return land.SurfaceType.WATER
  end
  self:_jitterSequence({ 700 })
  luaunit.assertNil(veaf.findSpawnPoint({ x = 0, y = 0, z = 0 }, 1000), "open water must not be")
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

--- FIX-TRIPACK-FIELD-REPORTS ticket 02 — an explicit surface list, so a naval element can
--- search on water instead of the land-only default.
function TestVeafFindSpawnPoint:test_explicit_surfaces_accept_water_for_a_ship()
  self:_waterAt({ 500 })
  self:_jitterSequence({ 500 })
  local point = veaf.findSpawnPoint({ x = 0, y = 0, z = 0 }, 1000, nil, veaf.WATER_TERRAIN)
  luaunit.assertNotNil(point, "a ship's surface list must accept open water")
  luaunit.assertEquals(point.x, 500)
end

function TestVeafFindSpawnPoint:test_explicit_surfaces_still_reject_what_they_do_not_list()
  -- Land everywhere (setUp default); a water-only surface list must refuse it.
  self:_jitterSequence({ 500 })
  local point = veaf.findSpawnPoint({ x = 0, y = 0, z = 0 }, 1000, nil, veaf.WATER_TERRAIN)
  luaunit.assertNil(point, "land must not satisfy a water-only surface list")
end

function TestVeafFindSpawnPoint:test_omitting_surfaces_keeps_the_land_only_default()
  -- An unconverted caller passes only vec3/radius/safeRadius — the fourth argument must
  -- default to today's land-only behaviour, not be silently required.
  self:_waterAt({ 500 })
  self:_jitterSequence({ 500, 600 })
  local point = veaf.findSpawnPoint({ x = 0, y = 0, z = 0 }, 1000, veaf.DEFAULT_SPAWN_CLEARANCE)
  luaunit.assertNotNil(point)
  luaunit.assertEquals(point.x, 600, "the water candidate at 500 must still be rejected")
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

-------------------------------------------------------------------------------------------------
-- REFACTOR-MARKER-PARSER ticket 02 — veaf.parseMarkerText
--
-- The specification has to be able to express the quirks ticket 01 measured, because several
-- are load-bearing: a migration that silently drops one changes a command in the field. Each
-- test below pins one of those quirks against the shared machine.
-------------------------------------------------------------------------------------------------

TestVeafParseMarkerText = {}

-- A minimal spec: one command, a few parameter kinds.
local function simpleSpec(overrides)
  local spec = {
    defaults = function(options)
      options.size = 1
      options.label = nil
      options.loud = false
    end,
    commands = {
      {
        match = "_probe deep",
        init = function(options)
          options.deep = true
          options.size = 9
        end,
      },
      {
        match = "_probe",
        init = function(options)
          options.shallow = true
        end,
      },
    },
    parameters = {
      { keys = { "size" }, apply = veaf.markerRules.number("size") },
      { keys = { "label", "name" }, apply = veaf.markerRules.text("label") },
      { keys = { "loud" }, apply = veaf.markerRules.flag("loud") },
      { keys = { "floor" }, apply = veaf.markerRules.nonNegativeNumber("floor") },
    },
  }
  for field, value in pairs(overrides or {}) do
    spec[field] = value
  end
  return spec
end

function TestVeafParseMarkerText:test_text_without_any_command_returns_nil()
  luaunit.assertNil(veaf.parseMarkerText("hello world", simpleSpec()))
end

function TestVeafParseMarkerText:test_a_non_string_returns_nil()
  luaunit.assertNil(veaf.parseMarkerText(nil, simpleSpec()))
  luaunit.assertNil(veaf.parseMarkerText(42, simpleSpec()))
end

function TestVeafParseMarkerText:test_defaults_are_seeded()
  local r = veaf.parseMarkerText("_probe", simpleSpec())
  luaunit.assertEquals(r.size, 1)
  luaunit.assertFalse(r.loud)
end

-- Quirk 8: the command descriptor seeds its own defaults, over the common ones.
function TestVeafParseMarkerText:test_a_command_overrides_the_common_defaults()
  luaunit.assertEquals(veaf.parseMarkerText("_probe deep", simpleSpec()).size, 9)
end

-- Quirk 17: FIRST MATCH WINS, decided by the chain's order and not the text's.
function TestVeafParseMarkerText:test_the_first_matching_command_wins()
  local r = veaf.parseMarkerText("_probe deep", simpleSpec())
  luaunit.assertTrue(r.deep)
  luaunit.assertNil(r.shallow)
end

function TestVeafParseMarkerText:test_the_keyphrase_match_is_case_insensitive()
  luaunit.assertNotNil(veaf.parseMarkerText("_PROBE", simpleSpec()))
end

function TestVeafParseMarkerText:test_the_keyphrase_is_found_anywhere_in_the_text()
  luaunit.assertNotNil(veaf.parseMarkerText("please _probe now", simpleSpec()))
end

function TestVeafParseMarkerText:test_parameters_are_applied()
  local r = veaf.parseMarkerText("_probe, size 4, label alpha, loud", simpleSpec())
  luaunit.assertEquals(r.size, 4)
  luaunit.assertEquals(r.label, "alpha")
  luaunit.assertTrue(r.loud)
end

function TestVeafParseMarkerText:test_aliases_share_one_rule()
  luaunit.assertEquals(veaf.parseMarkerText("_probe, name beta", simpleSpec()).label, "beta")
end

-- Quirk 12: every matching rule runs as the loop walks, so the last occurrence wins.
function TestVeafParseMarkerText:test_a_repeated_keyword_keeps_the_last_value()
  luaunit.assertEquals(veaf.parseMarkerText("_probe, size 2, size 5", simpleSpec()).size, 5)
end

-- Quirk 11: the value keeps everything after the FIRST space, untrimmed. Trimming here would
-- change veafCasMission's behaviour, where `side  BLUE` resolves to RED because of it.
function TestVeafParseMarkerText:test_the_value_is_everything_after_the_first_space_untrimmed()
  luaunit.assertEquals(veaf.parseMarkerText("_probe, label two words", simpleSpec()).label, "two words")
  luaunit.assertEquals(veaf.parseMarkerText("_probe, label  padded", simpleSpec()).label, " padded")
end

-- Quirk 1: a valueless keyword is nil by default, and "" for the modules that need it.
function TestVeafParseMarkerText:test_a_valueless_keyword_is_nil_by_default()
  luaunit.assertNil(veaf.parseMarkerText("_probe, label", simpleSpec()).label)
end

function TestVeafParseMarkerText:test_valueWhenAbsent_makes_a_valueless_keyword_an_empty_string()
  local spec = simpleSpec({ valueWhenAbsent = "" })
  luaunit.assertEquals(veaf.parseMarkerText("_probe, label", spec).label, "")
end

-- Quirk 15: a flag discards any value handed to it.
function TestVeafParseMarkerText:test_a_flag_ignores_its_value()
  luaunit.assertTrue(veaf.parseMarkerText("_probe, loud false", simpleSpec()).loud)
end

-- A bad parameter must never take the command down: this is the whole crash family.
function TestVeafParseMarkerText:test_a_valueless_numeric_keyword_keeps_the_default()
  luaunit.assertEquals(veaf.parseMarkerText("_probe, size", simpleSpec()).size, 1)
end

function TestVeafParseMarkerText:test_a_non_numeric_value_keeps_the_default()
  luaunit.assertEquals(veaf.parseMarkerText("_probe, size banana", simpleSpec()).size, 1)
end

function TestVeafParseMarkerText:test_a_valueless_non_negative_keyword_does_not_raise()
  luaunit.assertNotNil(veaf.parseMarkerText("_probe, floor", simpleSpec()))
end

-- Quirk 2 (separator): every module splits on "," except ArtilleryUnitHandler, on ";".
function TestVeafParseMarkerText:test_the_separator_is_configurable()
  local spec = simpleSpec({ separator = ";" })
  luaunit.assertEquals(veaf.parseMarkerText("_probe; size 3", spec).size, 3)
  -- With ";" declared, a comma is no longer a separator.
  luaunit.assertEquals(veaf.parseMarkerText("_probe, size 3", spec).size, 1)
end

-- Quirk 3: unknown keys are silent unless the module asks for the report.
function TestVeafParseMarkerText:test_unknown_keys_are_silent_by_default()
  luaunit.assertNil(veaf.parseMarkerText("_probe, banana 3", simpleSpec()).unknownParameters)
end

function TestVeafParseMarkerText:test_unknown_keys_are_reported_with_a_suggestion_when_asked()
  local r = veaf.parseMarkerText("_probe, labl alpha", simpleSpec({ reportUnknownKeys = true }))
  luaunit.assertIsTable(r.unknownParameters)
  luaunit.assertEquals(#r.unknownParameters, 1)
  luaunit.assertEquals(r.unknownParameters[1].key, "labl")
  luaunit.assertEquals(r.unknownParameters[1].suggestion, "label")
end

-- The command keyphrase itself must not be reported as an unknown parameter.
function TestVeafParseMarkerText:test_the_keyphrase_is_not_reported_as_unknown()
  luaunit.assertNil(veaf.parseMarkerText("_probe, size 3", simpleSpec({ reportUnknownKeys = true })).unknownParameters)
end

-- Quirk 9: mandatory parameters are enforced after the loop, by refusing the command.
function TestVeafParseMarkerText:test_validate_can_refuse_the_command()
  local spec = simpleSpec({
    validate = function(options)
      return options.label ~= nil
    end,
  })
  luaunit.assertNil(veaf.parseMarkerText("_probe", spec))
  luaunit.assertNotNil(veaf.parseMarkerText("_probe, label alpha", spec))
end

-- `when` gates a rule on the options built so far, which is how one key means two things.
function TestVeafParseMarkerText:test_when_gates_a_rule()
  local spec = simpleSpec()
  table.insert(spec.parameters, {
    keys = { "label" },
    when = function(options)
      return options.deep
    end,
    apply = veaf.markerRules.text("deepLabel"),
  })
  luaunit.assertNil(veaf.parseMarkerText("_probe, label alpha", spec).deepLabel)
  luaunit.assertEquals(veaf.parseMarkerText("_probe deep, label alpha", spec).deepLabel, "alpha")
end

-- A keyphrase containing a Lua pattern character must be matched literally, not as a pattern.
function TestVeafParseMarkerText:test_the_command_match_is_literal_not_a_pattern()
  local spec = simpleSpec({ commands = { {
    match = "_a.b",
    init = function(options)
      options.hit = true
    end,
  } } })
  luaunit.assertNotNil(veaf.parseMarkerText("_a.b", spec))
  luaunit.assertNil(veaf.parseMarkerText("_axb", spec))
end

-- On Sourcery's review of #712: keys are stored lower-cased, because the lookup lower-cases the
-- incoming key. A spec declaring "Size" would otherwise never match AND would be reported to the
-- pilot as an unknown parameter — a silent trap for the next module to be migrated.
function TestVeafParseMarkerText:test_a_mixed_case_declared_key_still_matches()
  local spec = simpleSpec({
    parameters = { { keys = { "SiZe" }, apply = veaf.markerRules.number("size") } },
    reportUnknownKeys = true,
  })
  local r = veaf.parseMarkerText("_probe, size 4", spec)
  luaunit.assertEquals(r.size, 4)
  luaunit.assertNil(r.unknownParameters)
end

-- Order is load-bearing (a repeated keyword ends on its last occurrence), so the loop must walk
-- the split result as a sequence. Long input, to make an out-of-order traversal show up.
function TestVeafParseMarkerText:test_keywords_are_applied_in_text_order()
  local text = "_probe"
  for i = 1, 30 do
    text = text .. ", size " .. i
  end
  luaunit.assertEquals(veaf.parseMarkerText(text, simpleSpec()).size, 30)
end

-- On Sourcery's review of #713: the "is this parameter really given?" test is shared, because
-- `""` is truthy in Lua and the module that spelled the check `if not x` shipped the bug twice.
function TestVeafParseMarkerText:test_isBlank_catches_nil_and_the_empty_string()
  luaunit.assertTrue(veaf.isBlank(nil))
  luaunit.assertTrue(veaf.isBlank(""))
  luaunit.assertFalse(veaf.isBlank("a"))
  luaunit.assertFalse(veaf.isBlank(" "), "a space is a value, since nothing is trimmed")
  luaunit.assertFalse(veaf.isBlank(0), "0 is a value, not an absence")
  luaunit.assertFalse(veaf.isBlank(false), "false is a value, not an absence")
end

function TestVeafParseMarkerText:test_requireText_refuses_a_blank_mandatory_field()
  local spec = simpleSpec({ validate = veaf.markerRules.requireText("label") })
  luaunit.assertNil(veaf.parseMarkerText("_probe", spec))
  luaunit.assertNil(veaf.parseMarkerText("_probe, label", spec))
  luaunit.assertNotNil(veaf.parseMarkerText("_probe, label alpha", spec))
end

-- prepareMarkerSpec is idempotent, so a module may call it at load time or not at all.
function TestVeafParseMarkerText:test_prepareMarkerSpec_is_idempotent()
  local spec = simpleSpec()
  veaf.prepareMarkerSpec(spec)
  local firstCount = #spec.knownKeys
  veaf.prepareMarkerSpec(spec)
  luaunit.assertEquals(#spec.knownKeys, firstCount)
end

-- ---------------------------------------------------------------------------
-- CTLD speaks the mission's language (FIX-CTLD-LANGUAGE)
--
-- CTLD 2 hard-codes `ctld.i18n_lang = "en"` and does not read veaf.config.language, so a French
-- mission showed a French VEAF menu next to an English CTLD one — reported in game 2026-08-16.
-- `_activeLang()` inside CTLD reads its config setting FIRST and this global second, so aligning
-- the global changes the DEFAULT while leaving a mission maker's explicit `i18n_lang:` in their
-- ctld-config.yaml the winner.
-- ---------------------------------------------------------------------------
TestVeafCtldLanguage = {}

function TestVeafCtldLanguage:setUp()
  dcs_mocks.reset()
  self._savedLang = veaf.config.language
  self._savedCtldLang = ctld.i18n_lang
  self._savedInit = ctld.initialize
  self._savedI18n = ctld.i18n
end

function TestVeafCtldLanguage:tearDown()
  veaf.config.language = self._savedLang
  ctld.i18n_lang = self._savedCtldLang
  ctld.initialize = self._savedInit
  ctld.i18n = self._savedI18n
end

function TestVeafCtldLanguage:test_ctld_follows_the_mission_language()
  veaf.config.language = "fr"
  ctld.i18n_lang = "en"
  veaf.ctld_initialize()
  luaunit.assertEquals(ctld.i18n_lang, "fr")
end

function TestVeafCtldLanguage:test_the_language_is_set_before_the_engine_starts()
  -- CTLD's startup report is emitted by initialize() and goes through ctld.tr(), so a language
  -- applied afterwards would leave that first output in the wrong one.
  veaf.config.language = "fr"
  local langAtInit
  ctld.initialize = function()
    langAtInit = ctld.i18n_lang
  end
  veaf.ctld_initialize()
  luaunit.assertEquals(langAtInit, "fr")
end

function TestVeafCtldLanguage:test_a_language_ctld_cannot_speak_is_left_alone()
  -- ctld.tr() logs a WARNING for every string in an unknown language, so pointing it at one the
  -- engine has no dictionary for would trade a wrong language for a flooded log.
  veaf.config.language = "de"
  ctld.i18n_lang = "en"
  veaf.ctld_initialize()
  luaunit.assertEquals(ctld.i18n_lang, "en")
end

function TestVeafCtldLanguage:test_no_mission_language_leaves_the_engine_default()
  veaf.config.language = nil
  ctld.i18n_lang = "en"
  veaf.ctld_initialize()
  luaunit.assertEquals(ctld.i18n_lang, "en")
end

-- ===========================================================================
-- veaf.readyForCombat
-- FIX-COMBATZONE-CONVOY-ALARM depends on AUTO (0) surviving the parameter guard: in Lua `0` is
-- truthy, so `if not alarm` does not catch it — but that is subtle enough to be "fixed" by someone
-- reading the guard alone, which would silently restore RED for every combat-zone group.
-- ===========================================================================
TestVeafReadyForCombat = {}

local function _spyGroup(name)
  local calls = {}
  local ctrl = {
    setOnOff = function() end,
    setOption = function(_, id, value)
      calls[id] = value
    end,
  }
  dcs_mocks.addGroup(name, {
    getController = function()
      return ctrl
    end,
  })
  return calls
end

function TestVeafReadyForCombat:test_auto_is_applied_not_swallowed_by_the_nil_guard()
  local calls = _spyGroup("__rfc_auto__")
  veaf.readyForCombat("__rfc_auto__", 0)
  luaunit.assertEquals(calls[AI.Option.Ground.id.ALARM_STATE], 0)
end

function TestVeafReadyForCombat:test_every_valid_state_reaches_the_controller()
  for _, state in ipairs({ 0, 1, 2 }) do
    local calls = _spyGroup("__rfc_state__" .. state)
    veaf.readyForCombat("__rfc_state__" .. state, state)
    luaunit.assertEquals(calls[AI.Option.Ground.id.ALARM_STATE], state)
  end
end

function TestVeafReadyForCombat:test_absent_or_out_of_range_falls_back_to_the_module_default()
  for i, bad in ipairs({ -1, 3, 99 }) do
    local groupName = "__rfc_bad__" .. i
    local calls = _spyGroup(groupName)
    veaf.readyForCombat(groupName, bad)
    luaunit.assertEquals(calls[AI.Option.Ground.id.ALARM_STATE], veaf.defaultAlarmState)
  end
  local calls = _spyGroup("__rfc_nil__")
  veaf.readyForCombat("__rfc_nil__", nil)
  luaunit.assertEquals(calls[AI.Option.Ground.id.ALARM_STATE], veaf.defaultAlarmState)
end

-------------------------------------------------------------------------------------------------
-- FIX-COMBATZONE-DELAYED-COMMAND — #66
--
-- A caller passes a table down to a VEAF command to learn what it created, and reads it on the next
-- line. Three paths defer the spawn — an alias delay (`-samsr!30`), a spawn's `delay` option, and its
-- repeats — and in all three the call returns before anything is spawned. The caller sees an empty
-- table and never looks again: that is how a combat zone ended up unable to destroy a group it had
-- itself spawned.
--
-- So the notification lives at the single insertion point instead: `veaf.collectSpawnedGroup` inserts
-- and tells whoever registered a hook, whether that happens now or in thirty seconds.
-------------------------------------------------------------------------------------------------

TestVeafCollectSpawnedGroup = {}

function TestVeafCollectSpawnedGroup:test_a_group_is_inserted_with_no_hook_registered()
  local t = {}
  veaf.collectSpawnedGroup(t, "Group A")
  luaunit.assertEquals(t[1], "Group A")
end

function TestVeafCollectSpawnedGroup:test_a_hook_is_told_about_the_group()
  local t, seen = {}, {}
  veaf.registerSpawnedGroupsHook(t, function(name)
    table.insert(seen, name)
  end)
  veaf.collectSpawnedGroup(t, "Group A")
  luaunit.assertEquals(seen, { "Group A" })
end

-- The point of the whole fix: the hook fires on an insertion that happens long after the caller
-- stopped reading the table.
function TestVeafCollectSpawnedGroup:test_a_hook_fires_on_a_later_insertion()
  local t, seen = {}, {}
  veaf.registerSpawnedGroupsHook(t, function(name)
    table.insert(seen, name)
  end)
  -- the caller reads nothing here, as a combat zone used to
  luaunit.assertEquals(#t, 0)
  -- ... and the deferred spawn lands afterwards
  veaf.collectSpawnedGroup(t, "DelayedSAM")
  luaunit.assertEquals(seen, { "DelayedSAM" })
end

function TestVeafCollectSpawnedGroup:test_every_group_is_reported()
  local t, seen = {}, {}
  veaf.registerSpawnedGroupsHook(t, function(name)
    table.insert(seen, name)
  end)
  veaf.collectSpawnedGroup(t, "A")
  veaf.collectSpawnedGroup(t, "B")
  veaf.collectSpawnedGroup(t, "C")
  luaunit.assertEquals(seen, { "A", "B", "C" })
  luaunit.assertEquals(#t, 3)
end

-- A hook is mission code. It must not be able to abort a spawn that is already half done.
function TestVeafCollectSpawnedGroup:test_a_raising_hook_does_not_break_the_spawn()
  local t = {}
  veaf.registerSpawnedGroupsHook(t, function()
    error("mission code blew up")
  end)
  local ok = pcall(veaf.collectSpawnedGroup, t, "Group A")
  luaunit.assertTrue(ok, "a raising hook must not propagate out of collectSpawnedGroup")
  luaunit.assertEquals(t[1], "Group A", "the group must still be collected")
end

-- The hook is deliberately NOT a field on the table: eleven call sites iterate group tables with
-- `pairs`, and a field would show up in all of them.
function TestVeafCollectSpawnedGroup:test_the_hook_is_not_visible_in_the_table()
  local t = {}
  veaf.registerSpawnedGroupsHook(t, function() end)
  veaf.collectSpawnedGroup(t, "Group A")
  local count = 0
  for _, v in pairs(t) do
    count = count + 1
    luaunit.assertEquals(type(v), "string", "pairs() must only yield group names")
  end
  luaunit.assertEquals(count, 1)
end

function TestVeafCollectSpawnedGroup:test_hooks_are_per_table()
  local t1, t2, seen = {}, {}, {}
  veaf.registerSpawnedGroupsHook(t1, function(name)
    table.insert(seen, name)
  end)
  veaf.collectSpawnedGroup(t2, "Other")
  luaunit.assertEquals(#seen, 0)
  luaunit.assertEquals(t2[1], "Other")
end

function TestVeafCollectSpawnedGroup:test_a_nil_group_name_is_a_noop()
  local t, called = {}, false
  veaf.registerSpawnedGroupsHook(t, function()
    called = true
  end)
  veaf.collectSpawnedGroup(t, nil)
  luaunit.assertEquals(#t, 0)
  luaunit.assertFalse(called)
end

function TestVeafCollectSpawnedGroup:test_a_missing_table_is_a_noop()
  local ok = pcall(veaf.collectSpawnedGroup, nil, "Group A")
  luaunit.assertTrue(ok)
end

function TestVeafCollectSpawnedGroup:test_registering_rejects_a_non_function()
  luaunit.assertFalse(veaf.registerSpawnedGroupsHook({}, "not a function"))
end

function TestVeafCollectSpawnedGroup:test_registering_rejects_a_non_table()
  luaunit.assertFalse(veaf.registerSpawnedGroupsHook("not a table", function() end))
end

function TestVeafCollectSpawnedGroup:test_registering_returns_true_on_success()
  luaunit.assertTrue(veaf.registerSpawnedGroupsHook({}, function() end))
end

-- ============================================================================
-- FIX-COMBATZONE-ZONE-TYPE-SILENT
--
-- Three modules branched on a trigger zone's type with `if type == 0 ... elseif type == 2 ... end` and
-- no `else`: veafCombatZone, veafAirWaves and veafQraCore. Any other value — **nil included** — left
-- the unit list untouched, so the zone found nobody and nothing said so. Each failure was silent in its
-- own way: a combat zone activated, reported nothing to kill and declared itself won; an air wave never
-- triggered; a QRA never scrambled.
--
-- The branch lives in one place now, and an unexpected type is an error naming the zone and the value.
-- nil rather than an empty table is returned on purpose: "unusable" and "legitimately empty" are
-- different answers, and a caller that cannot tell them apart is how this defect started.
-- ============================================================================
TestVeafGetUnitsInTriggerZone = {}

function TestVeafGetUnitsInTriggerZone:setUp()
  self._savedZones = veaf.triggerZones
  veaf.triggerZones = {
    CIRCLE = { name = "CIRCLE", type = 0, x = 0, y = 0, radius = 1000 },
    QUAD = { name = "QUAD", type = 2, x = 0, y = 0, verticies = { { x = 0, y = 0 }, { x = 1, y = 0 } } },
    ODD = { name = "ODD", type = 7, x = 0, y = 0 },
    TYPELESS = { name = "TYPELESS", x = 0, y = 0 },
  }
  self._savedInZones = veaf.getUnitsInCircularZone
  self._savedInPolygon = veaf.getUnitsInPolygon
  self.calls = {}
  local calls = self.calls
  veaf.getUnitsInCircularZone = function(unitNames, zoneName)
    table.insert(calls, { how = "zones", unitNames = unitNames, zoneName = zoneName })
    return { "unit-from-circle" }
  end
  veaf.getUnitsInPolygon = function(unitNames, verticies)
    table.insert(calls, { how = "polygon", unitNames = unitNames, verticies = verticies })
    return { "unit-from-polygon" }
  end
  self._logger = veaf.loggers.get(veaf.Id)
  self._savedError = self._logger.error
  self.errors = {}
  local errors = self.errors
  self._logger.error = function(_, text, ...)
    table.insert(errors, { text = text, args = { ... } })
  end
end

function TestVeafGetUnitsInTriggerZone:tearDown()
  veaf.triggerZones = self._savedZones
  veaf.getUnitsInCircularZone = self._savedInZones
  veaf.getUnitsInPolygon = self._savedInPolygon
  self._logger.error = self._savedError
end

function TestVeafGetUnitsInTriggerZone:test_a_circular_zone_goes_through_the_circular_lookup()
  local units = veaf.getUnitsInTriggerZone("CIRCLE", { "A", "B" }, veaf.Id)
  luaunit.assertEquals(units, { "unit-from-circle" })
  luaunit.assertEquals(self.calls[1].how, "zones")
  luaunit.assertEquals(self.calls[1].zoneName, "CIRCLE")
  luaunit.assertEquals(self.calls[1].unitNames, { "A", "B" })
  luaunit.assertEquals(#self.errors, 0)
end

function TestVeafGetUnitsInTriggerZone:test_a_quad_zone_goes_through_getUnitsInPolygon()
  local units = veaf.getUnitsInTriggerZone("QUAD", { "A" }, veaf.Id)
  luaunit.assertEquals(units, { "unit-from-polygon" })
  luaunit.assertEquals(self.calls[1].how, "polygon")
  luaunit.assertEquals(self.calls[1].verticies, veaf.triggerZones.QUAD.verticies)
  luaunit.assertEquals(#self.errors, 0)
end

-- The defect, both shapes of it.
function TestVeafGetUnitsInTriggerZone:test_an_unknown_type_is_an_error_not_an_empty_list()
  local units = veaf.getUnitsInTriggerZone("ODD", { "A" }, veaf.Id)
  luaunit.assertNil(units, "nil says unusable; an empty table would say the zone holds nobody")
  luaunit.assertEquals(#self.errors, 1)
  luaunit.assertEquals(#self.calls, 0, "neither MiST call may run on an unknown type")
end

function TestVeafGetUnitsInTriggerZone:test_a_missing_type_is_an_error_too()
  -- the likelier of the two: a hand-edited mission, a zone written by a tool, a renamed DCS field
  local units = veaf.getUnitsInTriggerZone("TYPELESS", { "A" }, veaf.Id)
  luaunit.assertNil(units)
  luaunit.assertEquals(#self.errors, 1)
end

function TestVeafGetUnitsInTriggerZone:test_the_error_names_the_zone_and_the_value()
  -- what makes the log actionable: without the value, the next reader repeats the investigation
  veaf.getUnitsInTriggerZone("ODD", { "A" }, veaf.Id)
  local reported = table.concat({ self.errors[1].text, tostring(self.errors[1].args[1]), tostring(self.errors[1].args[2]) }, " ")
  luaunit.assertNotNil(reported:find("ODD", 1, true), "the zone name must be in the message")
  luaunit.assertNotNil(reported:find("7", 1, true), "the unexpected type must be in the message")
end

function TestVeafGetUnitsInTriggerZone:test_an_unknown_zone_is_an_error()
  local units = veaf.getUnitsInTriggerZone("NO-SUCH-ZONE", { "A" }, veaf.Id)
  luaunit.assertNil(units)
  luaunit.assertEquals(#self.errors, 1)
end

function TestVeafGetUnitsInTriggerZone:test_no_zone_name_is_an_error_rather_than_a_crash()
  local ok, units = pcall(veaf.getUnitsInTriggerZone, nil, { "A" }, veaf.Id)
  luaunit.assertTrue(ok)
  luaunit.assertNil(units)
end

-- The module id is what makes the error land in the log of whoever asked, which is the whole point of
-- sharing the branch instead of copying it three times.
function TestVeafGetUnitsInTriggerZone:test_the_error_goes_to_the_caller_s_logger()
  local combatZoneErrors = {}
  local czLogger = veaf.loggers.get("COMBATZONE")
  local saved = czLogger.error
  czLogger.error = function(_, text, ...)
    table.insert(combatZoneErrors, text)
  end
  veaf.getUnitsInTriggerZone("ODD", { "A" }, "COMBATZONE")
  czLogger.error = saved
  luaunit.assertEquals(#combatZoneErrors, 1)
  luaunit.assertEquals(#self.errors, 0, "nothing may land in veaf's own logger when a module id is given")
end

-- ============================================================================
-- FEAT-SPAWN-OPTION-VALIDATION — #33, open since 2021
--
-- `veaf.parseMarkerText` has collected unrecognised keys with a nearest-match suggestion since
-- UXPILOT-003, but **one** spec out of eight switched it on. The other seven let a misspelt option do
-- nothing at all, so a pilot could not tell a typo from a feature that does not exist.
--
-- Two things had to exist before the flag could be turned on elsewhere:
--   * a command **verb** must not read as an unknown option. `_spawn`-style keyphrases escape because
--     they start with "_", which the collector already skips; the artillery verbs (`aim`, `fire`) are
--     bare words, so all nine valid orders measured were flagged before this.
--   * the report itself had to leave veafSpawnCore, or the block would be copied six times.
-- ============================================================================
TestVeafMarkerSpecCommandVerbs = {}

--- A spec shaped like the artillery one: bare verbs, semicolon separator.
local function verbSpec()
  return {
    defaults = function(options)
      options.verb = nil
    end,
    commands = {
      {
        match = "aim",
        init = function(options)
          options.verb = "aim"
        end,
      },
      {
        match = "fire",
        init = function(options)
          options.verb = "fire"
        end,
      },
    },
    parameters = {
      { keys = { "shells" }, apply = veaf.markerRules.number("shells") },
      { keys = { "radius" }, apply = veaf.markerRules.number("radius") },
    },
    separator = ";",
    valueWhenAbsent = "",
    reportUnknownKeys = true,
  }
end

local function flaggedKeys(options)
  local keys = {}
  for _, p in ipairs((options or {}).unknownParameters or {}) do
    table.insert(keys, p.key)
  end
  return keys
end

function TestVeafMarkerSpecCommandVerbs:test_a_command_verb_is_a_known_key()
  -- the whole point: the verb names the command, so it is not an option the pilot mistyped
  local spec = verbSpec()
  veaf.prepareMarkerSpec(spec)
  luaunit.assertTrue(spec._knownKeySet["aim"])
  luaunit.assertTrue(spec._knownKeySet["fire"])
end

function TestVeafMarkerSpecCommandVerbs:test_a_verb_only_order_flags_nothing()
  for _, text in ipairs({ "aim", "fire", "fire aim" }) do
    luaunit.assertEquals(flaggedKeys(veaf.parseMarkerText(text, verbSpec())), {}, text)
  end
end

function TestVeafMarkerSpecCommandVerbs:test_a_full_order_flags_nothing()
  local options = veaf.parseMarkerText("aim; shells 5; radius 100", verbSpec())
  luaunit.assertEquals(flaggedKeys(options), {})
  luaunit.assertEquals(options.shells, 5)
  luaunit.assertEquals(options.radius, 100)
end

-- The witness the lot's definition of done asks for: a real typo is still caught, with its suggestion.
function TestVeafMarkerSpecCommandVerbs:test_a_typo_is_still_flagged_with_a_suggestion()
  local options = veaf.parseMarkerText("aim; shels 5", verbSpec())
  luaunit.assertEquals(flaggedKeys(options), { "shels" })
  luaunit.assertEquals(options.unknownParameters[1].suggestion, "shells")
end

function TestVeafMarkerSpecCommandVerbs:test_an_unrelated_key_is_flagged_without_a_suggestion()
  local options = veaf.parseMarkerText("aim; banana 3", verbSpec())
  luaunit.assertEquals(flaggedKeys(options), { "banana" })
end

function TestVeafMarkerSpecCommandVerbs:test_an_empty_match_is_not_added_as_a_key()
  -- veafShortcuts' alias spec uses `commands = { { match = "" } }`; the empty string must not become a
  -- known key, which would be meaningless
  local spec = { commands = { { match = "" } }, parameters = { { keys = { "name" }, apply = veaf.markerRules.text("name") } } }
  veaf.prepareMarkerSpec(spec)
  luaunit.assertNil(spec._knownKeySet[""])
end

-- ============================================================================
-- The shared report: it used to live inside veafSpawnCore, so six other modules could not use it.
-- ============================================================================
TestVeafReportUnknownParameters = {}

function TestVeafReportUnknownParameters:setUp()
  self._report = veaf.reportToPilot
  self.reported = {}
  local reported = self.reported
  veaf.reportToPilot = function(message, duration, coalitionSide)
    table.insert(reported, { message = message, duration = duration, coalition = coalitionSide })
  end
  self._lang = veaf.config.language
  veaf.config.language = "en"
end

function TestVeafReportUnknownParameters:tearDown()
  veaf.reportToPilot = self._report
  veaf.config.language = self._lang
end

function TestVeafReportUnknownParameters:test_no_unknown_parameters_reports_nothing()
  luaunit.assertFalse(veaf.reportUnknownParameters({}, "move", nil))
  luaunit.assertEquals(#self.reported, 0)
end

function TestVeafReportUnknownParameters:test_a_nil_options_table_is_tolerated()
  luaunit.assertFalse(veaf.reportUnknownParameters(nil, "move", nil))
end

function TestVeafReportUnknownParameters:test_an_unknown_parameter_is_named_to_the_pilot()
  local options = { unknownParameters = { { key = "banana" } } }
  luaunit.assertTrue(veaf.reportUnknownParameters(options, "move", nil))
  luaunit.assertEquals(#self.reported, 1)
  luaunit.assertNotNil(self.reported[1].message:find("banana", 1, true))
end

function TestVeafReportUnknownParameters:test_the_module_is_named_so_the_pilot_knows_what_refused()
  veaf.reportUnknownParameters({ unknownParameters = { { key = "banana" } } }, "move", nil)
  luaunit.assertNotNil(self.reported[1].message:find("move", 1, true))
end

function TestVeafReportUnknownParameters:test_a_suggestion_is_included()
  veaf.reportUnknownParameters({ unknownParameters = { { key = "shels", suggestion = "shells" } } }, "artillery", nil)
  luaunit.assertNotNil(self.reported[1].message:find("shells", 1, true))
end

-- Aggregated on purpose: three wrong keys must not be three messages on the pilot's screen.
function TestVeafReportUnknownParameters:test_several_unknowns_make_one_message()
  local options = { unknownParameters = { { key = "a" }, { key = "b" }, { key = "c" } } }
  veaf.reportUnknownParameters(options, "spawn", nil)
  luaunit.assertEquals(#self.reported, 1)
  for _, key in ipairs({ "a", "b", "c" }) do
    luaunit.assertNotNil(self.reported[1].message:find("'" .. key .. "'", 1, true))
  end
end

function TestVeafReportUnknownParameters:test_the_requester_coalition_is_honoured()
  veaf.reportUnknownParameters({ unknownParameters = { { key = "banana" } } }, "spawn", coalition.side.BLUE)
  luaunit.assertEquals(self.reported[1].coalition, coalition.side.BLUE)
end

function TestVeafReportUnknownParameters:test_the_message_is_localised()
  veaf.config.language = "fr"
  veaf.reportUnknownParameters({ unknownParameters = { { key = "banana" } } }, "move", nil)
  luaunit.assertNotNil(self.reported[1].message:find("inconnu", 1, true))
end

-- ===========================================================================
-- FEAT-GROUP-COMBAT-INEFFECTIVE — veaf.isGroupCombatEffective
--
-- #177: a group is not only alive or dead. An S-300 whose tracking radar is destroyed still has
-- launchers and crew, counts as alive everywhere in our code, and in play is finished.
--
-- Two paths. A **pattern** in `veaf.ImportantUnitsByGroupPattern` declares which sets of units a group
-- of that kind owns; losing a whole set finishes it. With no pattern, the **DCS attributes** decide: a
-- group carrying a living `SAM LL` or `SAM SR` is a SAM site, and is finished once nothing living
-- carries `SAM TR`.
--
-- The limit is real and pinned below: dead units vanish from `Group:getUnits()`, so the default cannot
-- know a group *had* a radar. The pattern table is what carries that knowledge.
-- ===========================================================================
TestVeafGroupCombatEffective = {}

function TestVeafGroupCombatEffective:setUp()
  self._patterns = veaf.ImportantUnitsByGroupPattern
  self._db = dcsUnits
  self._getByName = Group.getByName
  -- a minimal stand-in for the generated database; a separate test checks the real one agrees
  dcsUnits = {
    DcsUnitsDatabase = {
      ["S-300PS 40B6M tr"] = { attribute = { ["SAM TR"] = true } },
      ["S-300PS 40B6MD sr"] = { attribute = { ["SAM SR"] = true } },
      ["S-300PS 54K6 cp"] = { attribute = {} },
      ["S-300PS 5P85C ln"] = { attribute = { ["SAM LL"] = true } },
      ["2S6 Tunguska"] = { attribute = { ["SAM SR"] = true, ["SAM TR"] = true, ["SAM LL"] = true } },
      ["Ural-375"] = { attribute = { ["Trucks"] = true } },
    },
  }
end

function TestVeafGroupCombatEffective:tearDown()
  veaf.ImportantUnitsByGroupPattern = self._patterns
  dcsUnits = self._db
  Group.getByName = self._getByName
end

--- A unit stub: alive, at full life unless `life` says otherwise.
local function ceUnit(typeName, life)
  return {
    getTypeName = function()
      return typeName
    end,
    isExist = function()
      return true
    end,
    isActive = function()
      return true
    end,
    getLife = function()
      return life or 100
    end,
    getLife0 = function()
      return 100
    end,
  }
end

--- Register a group of the given units under `name`, so Group.getByName finds it.
local function ceGroup(name, units)
  local group = {
    getName = function()
      return name
    end,
    isExist = function()
      return true
    end,
    getUnits = function()
      return units
    end,
  }
  Group.getByName = function(n)
    if n == name then
      return group
    end
    return nil
  end
  return group
end

local S300_PATTERN = {
  [".*s300.*"] = {
    minimumLife = 80,
    importantSets = {
      TR = { "S-300PS 40B6M tr" },
      SR = { "S-300PS 40B6MD sr" },
      CP = { "S-300PS 54K6 cp" },
    },
  },
}

-- ---------------------------------------------------------------------------
-- The pattern path
-- ---------------------------------------------------------------------------
function TestVeafGroupCombatEffective:test_a_complete_s300_is_effective()
  veaf.ImportantUnitsByGroupPattern = S300_PATTERN
  local g = ceGroup("RED-s300-SITE", {
    ceUnit("S-300PS 40B6M tr"),
    ceUnit("S-300PS 40B6MD sr"),
    ceUnit("S-300PS 54K6 cp"),
    ceUnit("S-300PS 5P85C ln"),
  })
  luaunit.assertTrue(veaf.isGroupCombatEffective(g))
end

-- The defect the issue describes: launchers and crew remain, the tracking radar does not.
function TestVeafGroupCombatEffective:test_an_s300_without_its_tracking_radar_is_finished()
  veaf.ImportantUnitsByGroupPattern = S300_PATTERN
  local g = ceGroup("RED-s300-SITE", {
    ceUnit("S-300PS 40B6MD sr"),
    ceUnit("S-300PS 54K6 cp"),
    ceUnit("S-300PS 5P85C ln"),
    ceUnit("S-300PS 5P85C ln"),
  })
  luaunit.assertFalse(veaf.isGroupCombatEffective(g))
end

function TestVeafGroupCombatEffective:test_losing_any_declared_set_finishes_the_group()
  veaf.ImportantUnitsByGroupPattern = S300_PATTERN
  local all = { "S-300PS 40B6M tr", "S-300PS 40B6MD sr", "S-300PS 54K6 cp" }
  for _, missing in ipairs(all) do
    local units = {}
    for _, typeName in ipairs(all) do
      if typeName ~= missing then
        table.insert(units, ceUnit(typeName))
      end
    end
    local g = ceGroup("RED-s300-SITE", units)
    luaunit.assertFalse(veaf.isGroupCombatEffective(g), "losing " .. missing .. " must finish the group")
  end
end

-- minimumLife is a percentage of the unit initial life, read through veaf.getUnitLifeRelative.
function TestVeafGroupCombatEffective:test_a_radar_below_minimum_life_does_not_count()
  veaf.ImportantUnitsByGroupPattern = S300_PATTERN
  local g = ceGroup("RED-s300-SITE", {
    ceUnit("S-300PS 40B6M tr", 50), -- 50% of 100, below the 80 the table asks for
    ceUnit("S-300PS 40B6MD sr"),
    ceUnit("S-300PS 54K6 cp"),
  })
  luaunit.assertFalse(veaf.isGroupCombatEffective(g))
end

function TestVeafGroupCombatEffective:test_a_radar_at_exactly_minimum_life_counts()
  veaf.ImportantUnitsByGroupPattern = S300_PATTERN
  local g = ceGroup("RED-s300-SITE", {
    ceUnit("S-300PS 40B6M tr", 80),
    ceUnit("S-300PS 40B6MD sr"),
    ceUnit("S-300PS 54K6 cp"),
  })
  luaunit.assertTrue(veaf.isGroupCombatEffective(g))
end

-- One survivor per set is enough: a site does not need both of its search radars.
function TestVeafGroupCombatEffective:test_one_survivor_per_set_is_enough()
  veaf.ImportantUnitsByGroupPattern = {
    [".*s300.*"] = { minimumLife = 80, importantSets = { SR = { "S-300PS 40B6MD sr", "S-300PS 64H6E sr" } } },
  }
  local g = ceGroup("RED-s300-SITE", { ceUnit("S-300PS 40B6MD sr") })
  luaunit.assertTrue(veaf.isGroupCombatEffective(g))
end

function TestVeafGroupCombatEffective:test_the_pattern_match_is_case_insensitive()
  veaf.ImportantUnitsByGroupPattern = S300_PATTERN
  local g = ceGroup("RED-S300-SITE", { ceUnit("S-300PS 5P85C ln") })
  luaunit.assertFalse(veaf.isGroupCombatEffective(g), "an uppercase name must match the pattern too")
end

-- ---------------------------------------------------------------------------
-- The attribute default
-- ---------------------------------------------------------------------------
function TestVeafGroupCombatEffective:test_a_sam_site_with_no_tracking_radar_is_finished_by_default()
  veaf.ImportantUnitsByGroupPattern = {}
  local g = ceGroup("RED-SA10", { ceUnit("S-300PS 5P85C ln"), ceUnit("S-300PS 40B6MD sr") })
  luaunit.assertFalse(veaf.isGroupCombatEffective(g))
end

function TestVeafGroupCombatEffective:test_a_sam_site_keeping_a_tracking_radar_is_effective()
  veaf.ImportantUnitsByGroupPattern = {}
  local g = ceGroup("RED-SA10", { ceUnit("S-300PS 5P85C ln"), ceUnit("S-300PS 40B6M tr") })
  luaunit.assertTrue(veaf.isGroupCombatEffective(g))
end

-- A Tunguska is its own radar and launcher, so one vehicle is a working SAM.
function TestVeafGroupCombatEffective:test_a_self_contained_sam_is_effective_alone()
  veaf.ImportantUnitsByGroupPattern = {}
  local g = ceGroup("RED-TUNGUSKA", { ceUnit("2S6 Tunguska") })
  luaunit.assertTrue(veaf.isGroupCombatEffective(g))
end

-- Not everything is a SAM: a convoy has no radars and is a problem as long as it exists.
function TestVeafGroupCombatEffective:test_a_convoy_is_effective_while_it_lives()
  veaf.ImportantUnitsByGroupPattern = {}
  local g = ceGroup("RED-CONVOY", { ceUnit("Ural-375"), ceUnit("Ural-375") })
  luaunit.assertTrue(veaf.isGroupCombatEffective(g))
end

-- ---------------------------------------------------------------------------
-- Degenerate inputs
-- ---------------------------------------------------------------------------
function TestVeafGroupCombatEffective:test_an_empty_group_is_not_effective()
  veaf.ImportantUnitsByGroupPattern = {}
  local g = ceGroup("RED-GONE", {})
  luaunit.assertFalse(veaf.isGroupCombatEffective(g))
end

function TestVeafGroupCombatEffective:test_an_unknown_group_name_is_not_effective_and_does_not_raise()
  veaf.ImportantUnitsByGroupPattern = {}
  Group.getByName = function()
    return nil
  end
  local ok, result = pcall(veaf.isGroupCombatEffective, "NO-SUCH-GROUP")
  luaunit.assertTrue(ok, "an unknown group must not raise")
  luaunit.assertFalse(result)
end

function TestVeafGroupCombatEffective:test_a_nil_argument_is_not_effective()
  luaunit.assertFalse(veaf.isGroupCombatEffective(nil))
end

-- A group name is accepted as well as a group, like veaf.getAveragePosition does.
function TestVeafGroupCombatEffective:test_a_group_name_works_like_a_group()
  veaf.ImportantUnitsByGroupPattern = {}
  ceGroup("RED-BY-NAME", { ceUnit("Ural-375") })
  luaunit.assertTrue(veaf.isGroupCombatEffective("RED-BY-NAME"))
end

-- An unknown unit type must not decide anything: the database is generated from a datamine and can lag
-- a DCS update, so a missing entry means "no attributes", not "not a SAM".
function TestVeafGroupCombatEffective:test_an_unknown_unit_type_is_ignored_rather_than_deciding()
  veaf.ImportantUnitsByGroupPattern = {}
  local g = ceGroup("RED-MYSTERY", { ceUnit("SomeUnitShippedYesterday") })
  luaunit.assertTrue(veaf.isGroupCombatEffective(g))
end

-- The generated database is the predicate's only source of attributes, and it is regenerated from a
-- datamine by a scheduled job. If a regeneration ever dropped the `SAM TR` attribute, the default rule
-- would quietly declare every SAM site finished — a silent, mission-wide behaviour change. This is the
-- test that would go red instead.
TestVeafCombatEffectiveAgainstRealData = {}

function TestVeafCombatEffectiveAgainstRealData:test_the_real_database_carries_the_attributes_the_rule_reads()
  luaunit.assertNotNil(dcsUnits, "the generated database must load")
  luaunit.assertNotNil(dcsUnits.DcsUnitsDatabase, "the generated database must expose DcsUnitsDatabase")
  -- a tracking radar, a search radar, a launcher and a self-contained SAM
  luaunit.assertTrue(veaf.unitTypeHasAttribute("S-300PS 40B6M tr", "SAM TR"), "the S-300 tracking radar")
  luaunit.assertTrue(veaf.unitTypeHasAttribute("S-300PS 40B6MD sr", "SAM SR"), "the S-300 search radar")
  luaunit.assertTrue(veaf.unitTypeHasAttribute("2S6 Tunguska", "SAM TR"), "a Tunguska is its own tracker")
end

function TestVeafCombatEffectiveAgainstRealData:test_the_patterns_name_types_the_database_knows()
  -- a typo in the table would make a set unmatchable, and a group of that kind permanently ineffective
  for pattern, rule in pairs(veaf.ImportantUnitsByGroupPattern) do
    for setName, types in pairs(rule.importantSets or {}) do
      for _, typeName in ipairs(types) do
        luaunit.assertNotNil(
          dcsUnits.DcsUnitsDatabase[typeName],
          "pattern [" .. pattern .. "] set [" .. setName .. "] names an unknown type: " .. typeName
        )
      end
    end
  end
end

function TestVeafCombatEffectiveAgainstRealData:test_an_ordinary_truck_is_not_taken_for_a_sam()
  luaunit.assertFalse(veaf.unitTypeHasAttribute("Ural-375", "SAM TR"))
  luaunit.assertFalse(veaf.unitTypeHasAttribute("Ural-375", "SAM SR"))
  luaunit.assertFalse(veaf.unitTypeHasAttribute("Ural-375", "SAM LL"))
end

-- ===========================================================================
-- FIX-CSAR-SPAWNS-ON-WATER — where a downed pilot ends up (#245)
--
-- The survivor to be rescued, not the rescue helicopter's crew: `S_EVENT_EJECTION` hands CSAR the
-- position of the *aircraft*, and `csar.spawnGroup` places a "Downed Pilot" group at a fixed +50/+50
-- from it with no surface test at all. Ejecting near a shoreline puts him in the water.
--
-- David's arbitration, 2026-08-22: **within 500 m of dry ground, put him there; otherwise he counts as
-- dead.** No raft, and no walk inland — so `nil` here means "no CSAR at all", not "a CSAR far away".
--
-- Nothing in `CSAR.lua` is touched. The decision lives in veaf.lua and is applied by replacing
-- `csar.addCsar` from `veaf.csar_initialize_replacement`, which already replaces seven other things in
-- that table.
-- ===========================================================================
TestVeafCsarSurvivorPoint = {}

function TestVeafCsarSurvivorPoint:setUp()
  self._surface = land.getSurfaceType
  self._findSpawnPoint = veaf.findSpawnPoint
end

function TestVeafCsarSurvivorPoint:tearDown()
  land.getSurfaceType = self._surface
  veaf.findSpawnPoint = self._findSpawnPoint
end

--- Make everything water, or everything land.
function TestVeafCsarSurvivorPoint:_allSurface(surfaceType)
  land.getSurfaceType = function()
    return surfaceType
  end
end

function TestVeafCsarSurvivorPoint:test_a_pilot_on_dry_ground_is_left_exactly_where_he_is()
  -- The common case by far, and it must not move him: `findSpawnPoint` jitters, so calling it
  -- unconditionally would shift every land ejection by tens of metres for no reason.
  self:_allSurface(land.SurfaceType.LAND)
  local moved = false
  veaf.findSpawnPoint = function()
    moved = true
    return { x = 999, y = 0, z = 999 }
  end
  local point = { x = 100, y = 50, z = 200 }
  local resolved = veaf.resolveCsarSurvivorPoint(point)
  luaunit.assertEquals(resolved.x, 100)
  luaunit.assertEquals(resolved.z, 200)
  luaunit.assertFalse(moved, "a dry ejection point must not be searched around")
end

function TestVeafCsarSurvivorPoint:test_a_pilot_over_water_is_moved_to_the_dry_point_found()
  self:_allSurface(land.SurfaceType.WATER)
  veaf.findSpawnPoint = function(centre, radius)
    luaunit.assertEquals(radius, veaf.CSAR_SURVIVOR_SEARCH_RADIUS_METRES)
    return { x = centre.x + 300, y = 0, z = centre.z }
  end
  local resolved = veaf.resolveCsarSurvivorPoint({ x = 0, y = 0, z = 0 })
  luaunit.assertEquals(resolved.x, 300)
end

-- The arbitration's second half: nothing dry within reach means no CSAR at all.
function TestVeafCsarSurvivorPoint:test_a_pilot_with_no_dry_ground_within_range_is_lost()
  self:_allSurface(land.SurfaceType.WATER)
  veaf.findSpawnPoint = function()
    return nil
  end
  luaunit.assertNil(veaf.resolveCsarSurvivorPoint({ x = 0, y = 0, z = 0 }))
end

function TestVeafCsarSurvivorPoint:test_the_search_radius_is_the_500_m_that_was_arbitrated()
  luaunit.assertEquals(veaf.CSAR_SURVIVOR_SEARCH_RADIUS_METRES, 500)
end

-- Shallow water counts as dry here, as it does everywhere else in this codebase
-- (`acceptableGroundPoint` rejects WATER only). A survivor wading a few metres offshore is rescuable;
-- treating it as open sea would declare him dead next to a beach.
function TestVeafCsarSurvivorPoint:test_shallow_water_is_not_treated_as_open_sea()
  self:_allSurface(land.SurfaceType.SHALLOW_WATER)
  local searched = false
  veaf.findSpawnPoint = function()
    searched = true
    return nil
  end
  local resolved = veaf.resolveCsarSurvivorPoint({ x = 10, y = 0, z = 20 })
  luaunit.assertNotNil(resolved, "shallow water must not be a death sentence")
  luaunit.assertFalse(searched)
end

-- The coordinate trap: land.getSurfaceType takes a vec2 whose `y` is the **easting**, while the point
-- handed in is a runtime vec3 whose `y` is the altitude. Reading `y` as the easting asks about a spot a
-- hundred kilometres away and answers cheerfully.
function TestVeafCsarSurvivorPoint:test_the_surface_is_asked_about_the_right_spot()
  local asked = {}
  land.getSurfaceType = function(vec2)
    table.insert(asked, vec2)
    return land.SurfaceType.LAND
  end
  veaf.resolveCsarSurvivorPoint({ x = 1000, y = 4000, z = 2000 })
  luaunit.assertEquals(#asked, 1)
  luaunit.assertEquals(asked[1].x, 1000, "northing")
  luaunit.assertEquals(asked[1].y, 2000, "the easting belongs in the vec2 y, not the altitude")
end

function TestVeafCsarSurvivorPoint:test_a_nil_point_is_refused_rather_than_raising()
  luaunit.assertNil(veaf.resolveCsarSurvivorPoint(nil))
end

-- CHORE-ONE-TERRAIN-CHECK — the same enumeration as `acceptableGroundPoint`, at the site where the
-- answer decides whether a downed pilot exists at all. Only WATER sends the search out; the other four
-- surfaces leave him exactly where he ejected.
function TestVeafCsarSurvivorPoint:test_only_open_water_sends_the_survivor_looking_for_dry_ground()
  for _, name in ipairs({ "LAND", "SHALLOW_WATER", "ROAD", "RUNWAY" }) do
    self:_allSurface(land.SurfaceType[name])
    local searched = false
    veaf.findSpawnPoint = function()
      searched = true
      return nil
    end
    luaunit.assertNotNil(veaf.resolveCsarSurvivorPoint({ x = 10, y = 0, z = 20 }), name .. " is dry ground")
    luaunit.assertFalse(searched, name .. " must not trigger a search")
  end

  self:_allSurface(land.SurfaceType.WATER)
  local searched = false
  veaf.findSpawnPoint = function()
    searched = true
    return nil
  end
  luaunit.assertNil(veaf.resolveCsarSurvivorPoint({ x = 10, y = 0, z = 20 }))
  luaunit.assertTrue(searched, "open water must trigger the search")
end

-- ===========================================================================
-- CHORE-ONE-TERRAIN-CHECK — veaf.findPointInZone, surface by surface
--
-- This site had no test at all, and it carries the rule MiST also had, written out inline: a ship wants
-- WATER, anything else wants LAND / ROAD / RUNWAY. Two details are easy to lose in a deduplication and
-- are pinned here on purpose, because they make this site's list its own:
--   * a ship is refused SHALLOW_WATER, while `veafDcsSpawner.terrainForCategory("ship")` allows it;
--   * a vehicle is refused SHALLOW_WATER, while `acceptableGroundPoint` accepts it.
-- So neither of the other two lists can be substituted here, whatever the surface names suggest.
-- ===========================================================================
TestVeafFindPointInZone = {}

function TestVeafFindPointInZone:setUp()
  self._surface = land.getSurfaceType
  self._rand = veaf.getRandomPointInCircle
  -- `getRandomPointInCircle` lives in veafGeo, which this file does not load. The stub answers the shape
  -- the real one returns — `{ x = <northing>, y = <easting> }`, a mission-table vec2, no `z` — and
  -- records the dispersion it was handed so the widening can be asserted.
  self.draws = {}
  veaf.getRandomPointInCircle = function(spot, dispersion)
    table.insert(self.draws, dispersion)
    return { x = (spot.x or 0) + #self.draws, y = dispersion }
  end
end

function TestVeafFindPointInZone:tearDown()
  land.getSurfaceType = self._surface
  veaf.getRandomPointInCircle = self._rand
end

function TestVeafFindPointInZone:_surfaceIs(name)
  land.getSurfaceType = function()
    return land.SurfaceType[name]
  end
end

--- Does a zone made entirely of `name` yield a point for this kind of group?
function TestVeafFindPointInZone:_accepts(isShip, name)
  self:_surfaceIs(name)
  self.draws = {}
  return veaf.findPointInZone({ x = 0, y = 0, z = 0 }, 10, isShip) ~= nil
end

function TestVeafFindPointInZone:test_a_ground_group_takes_land_road_or_runway_and_no_water_at_all()
  luaunit.assertTrue(self:_accepts(false, "LAND"), "LAND")
  luaunit.assertTrue(self:_accepts(false, "ROAD"), "ROAD")
  luaunit.assertTrue(self:_accepts(false, "RUNWAY"), "RUNWAY")
  luaunit.assertFalse(self:_accepts(false, "SHALLOW_WATER"), "shallow water is dry for CSAR, but not here")
  luaunit.assertFalse(self:_accepts(false, "WATER"), "WATER")
end

function TestVeafFindPointInZone:test_a_ship_takes_open_water_only()
  luaunit.assertTrue(self:_accepts(true, "WATER"), "WATER")
  luaunit.assertFalse(self:_accepts(true, "SHALLOW_WATER"), "a shallow-water draw is refused at this site today")
  luaunit.assertFalse(self:_accepts(true, "LAND"), "LAND")
  luaunit.assertFalse(self:_accepts(true, "ROAD"), "ROAD")
  luaunit.assertFalse(self:_accepts(true, "RUNWAY"), "RUNWAY")
end

function TestVeafFindPointInZone:test_the_drawn_point_is_returned_as_drawn()
  self:_surfaceIs("LAND")
  self.draws = {}
  local point = veaf.findPointInZone({ x = 500, y = 0, z = 0 }, 10, false)
  luaunit.assertEquals(point.x, 501, "the first draw, unmoved — this site does not place on land")
  luaunit.assertEquals(#self.draws, 1)
end

function TestVeafFindPointInZone:test_each_failed_draw_widens_the_circle_by_one_dispersion()
  self:_surfaceIs("WATER")
  self.draws = {}
  veaf.findPointInZone({ x = 0, y = 0, z = 0 }, 10, false)
  luaunit.assertEquals(self.draws[1], 10)
  luaunit.assertEquals(self.draws[2], 20)
  luaunit.assertEquals(self.draws[3], 30)
end

function TestVeafFindPointInZone:test_the_search_gives_up_after_a_thousand_draws()
  self:_surfaceIs("WATER")
  self.draws = {}
  luaunit.assertNil(veaf.findPointInZone({ x = 0, y = 0, z = 0 }, 10, false))
  luaunit.assertEquals(#self.draws, 1000, "the loop must stay bounded")
end

-- ===========================================================================
-- FIX-CSAR-SPAWNS-ON-WATER — the replacement of csar.addCsar
--
-- The subtle half. `csar.spawnGroup` adds its own +50/+50 to whatever position it is given, so the point
-- handed to the original has to be pre-compensated for the survivor to land where we decided. Asserting
-- the **round trip** rather than the constant is what will catch a vendored update changing that offset.
-- ===========================================================================
TestVeafCsarAddCsarReplacement = {}

function TestVeafCsarAddCsarReplacement:setUp()
  self._csar = csar
  self._resolve = veaf.resolveCsarSurvivorPoint
  self._outText = trigger.action.outTextForCoalition

  self.calls = {}
  self.messages = {}
  -- a fresh csar table per test, so the "already replaced" marker does not leak between them
  csar = {
    Id = "CSAR",
    addCsar = function(coa, country, point, typeName, unitName, playerName, freq, noMessage, description)
      table.insert(self.calls, { coalition = coa, point = point, typeName = typeName, noMessage = noMessage })
    end,
  }
  trigger.action.outTextForCoalition = function(coa, text, duration)
    table.insert(self.messages, { coalition = coa, text = text })
  end
end

function TestVeafCsarAddCsarReplacement:tearDown()
  csar = self._csar
  veaf.resolveCsarSurvivorPoint = self._resolve
  trigger.action.outTextForCoalition = self._outText
end

--- Pretend the resolver returns `point` unchanged, or nil for "lost".
function TestVeafCsarAddCsarReplacement:_resolveTo(result)
  veaf.resolveCsarSurvivorPoint = function(intended)
    self.intended = intended
    if result == "same" then
      return intended
    end
    return result
  end
end

function TestVeafCsarAddCsarReplacement:test_the_resolver_is_asked_about_where_the_pilot_would_really_land()
  -- Not the position handed in: the survivor ends up +50/+50 from it, and that is the spot whose surface
  -- matters. Asking about the aircraft's position instead would clear an ejection whose survivor lands
  -- in the water fifty metres away.
  self:_resolveTo("same")
  veaf.replaceCsarAddCsar()
  csar.addCsar(2, "USA", { x = 100, y = 10, z = 200 }, "F-16C")
  luaunit.assertEquals(self.intended.x, 100 + veaf.CSAR_SPAWN_OFFSET_METRES)
  luaunit.assertEquals(self.intended.z, 200 + veaf.CSAR_SPAWN_OFFSET_METRES)
end

function TestVeafCsarAddCsarReplacement:test_the_survivor_lands_where_the_resolver_chose()
  -- The round trip: whatever we pass, `spawnGroup` will add the offset back, so point + offset must
  -- equal the resolved point exactly.
  self:_resolveTo({ x = 4000, y = 12, z = 8000 })
  veaf.replaceCsarAddCsar()
  csar.addCsar(2, "USA", { x = 0, y = 0, z = 0 }, "F-16C")
  luaunit.assertEquals(#self.calls, 1)
  local handed = self.calls[1].point
  luaunit.assertEquals(handed.x + veaf.CSAR_SPAWN_OFFSET_METRES, 4000)
  luaunit.assertEquals(handed.z + veaf.CSAR_SPAWN_OFFSET_METRES, 8000)
end

function TestVeafCsarAddCsarReplacement:test_a_lost_pilot_creates_no_csar_at_all()
  -- The arbitration's second half. Not "a CSAR far away" — nothing: no group, no MAYDAY, no ADF beacon.
  self:_resolveTo(nil)
  veaf.replaceCsarAddCsar()
  csar.addCsar(2, "USA", { x = 0, y = 0, z = 0 }, "F-16C")
  luaunit.assertEquals(#self.calls, 0, "the original must not be called for a lost pilot")
end

function TestVeafCsarAddCsarReplacement:test_a_lost_pilot_is_announced_to_his_coalition()
  -- A silent loss would leave a flight waiting for a rescue mission that does not exist.
  self:_resolveTo(nil)
  veaf.replaceCsarAddCsar()
  csar.addCsar(2, "USA", { x = 0, y = 0, z = 0 }, "F-16C")
  luaunit.assertEquals(#self.messages, 1)
  luaunit.assertEquals(self.messages[1].coalition, 2)
  luaunit.assertStrContains(self.messages[1].text, "F-16C")
end

function TestVeafCsarAddCsarReplacement:test_a_silent_csar_stays_silent_even_when_lost()
  -- `noMessage` is how a mission spawns a CSAR without announcing it; losing the pilot must not become
  -- the one case that talks.
  self:_resolveTo(nil)
  veaf.replaceCsarAddCsar()
  csar.addCsar(2, "USA", { x = 0, y = 0, z = 0 }, "F-16C", nil, nil, nil, true)
  luaunit.assertEquals(#self.messages, 0)
end

function TestVeafCsarAddCsarReplacement:test_every_argument_is_passed_through_untouched()
  self:_resolveTo("same")
  veaf.replaceCsarAddCsar()
  csar.addCsar(1, "RUS", { x = 0, y = 0, z = 0 }, "Su-25", "unit-1", "Zip", 123.45, false, "desc")
  luaunit.assertEquals(self.calls[1].coalition, 1)
  luaunit.assertEquals(self.calls[1].typeName, "Su-25")
  luaunit.assertEquals(self.calls[1].noMessage, false)
end

-- A caller handing something that is not a position must not be second-guessed: pass it on and let the
-- original deal with it, exactly as before.
function TestVeafCsarAddCsarReplacement:test_a_positionless_call_is_forwarded_unchanged()
  local asked = false
  veaf.resolveCsarSurvivorPoint = function()
    asked = true
    return nil
  end
  veaf.replaceCsarAddCsar()
  csar.addCsar(2, "USA", nil, "F-16C")
  luaunit.assertEquals(#self.calls, 1)
  luaunit.assertFalse(asked)
end

-- Replacing twice must not stack wrappers: `csar_initialize_replacement` sets `veaf.csar_initialized`
-- but nothing reads it, so a mission calling it twice is possible — and a doubled wrapper would
-- compensate the offset twice, putting the survivor 50 m the wrong way.
--
-- The first version of this test passed on a **non**-idempotent wrapper: its stub resolver returned a
-- fixed point regardless of input, so the double compensation cancelled itself out. The stub here moves
-- the point it is given, which is what makes the assertion mean anything.
function TestVeafCsarAddCsarReplacement:test_replacing_twice_does_not_double_the_compensation()
  local resolveCalls = 0
  veaf.resolveCsarSurvivorPoint = function(intended)
    resolveCalls = resolveCalls + 1
    return { x = intended.x + 1000, y = intended.y, z = intended.z }
  end
  veaf.replaceCsarAddCsar()
  veaf.replaceCsarAddCsar()
  csar.addCsar(2, "USA", { x = 0, y = 0, z = 0 }, "F-16C")
  luaunit.assertEquals(#self.calls, 1)
  luaunit.assertEquals(resolveCalls, 1, "resolved twice means the wrapper was stacked")
  -- one offset added by the (mocked) original, one resolution of +1000
  luaunit.assertEquals(self.calls[1].point.x + veaf.CSAR_SPAWN_OFFSET_METRES, 1000 + veaf.CSAR_SPAWN_OFFSET_METRES)
end

-- The ejection happened whether or not a CSAR exists, so CSAR's own bookkeeping must still run:
-- `handleEjectOrCrash` disables the aircraft (mode 1) or the pilot (mode 2) for a timeout. Skipping it
-- would make ditching at sea the cheapest way to lose an aircraft, which is the opposite of "he counts as
-- dead". Caught in review (Sourcery, PR #787).
function TestVeafCsarAddCsarReplacement:test_a_lost_pilot_is_still_counted_as_having_ejected()
  local handled = {}
  csar.handleEjectOrCrash = function(unit, crashed)
    table.insert(handled, { unit = unit, crashed = crashed })
  end
  self:_resolveTo(nil)
  veaf.replaceCsarAddCsar()
  csar.addCsar(2, "USA", { x = 0, y = 0, z = 0 }, "F-16C", "unit-1", "Zip")
  luaunit.assertEquals(#handled, 1, "the ejection bookkeeping must run even with no CSAR created")
  luaunit.assertEquals(handled[1].unit, "Zip")
  luaunit.assertEquals(handled[1].crashed, false)
end

-- That call is wrong upstream — `addCsar` hands a player name to a function that indexes a unit — so it
-- raises as soon as a mission sets csarMode to 1 or 2. Reproducing the original call is right; letting
-- our new path be the one that dies from it is not.
function TestVeafCsarAddCsarReplacement:test_a_raising_bookkeeping_call_does_not_take_the_wrapper_down()
  csar.handleEjectOrCrash = function()
    error("attempt to index a string value")
  end
  self:_resolveTo(nil)
  veaf.replaceCsarAddCsar()
  local ok = pcall(csar.addCsar, 2, "USA", { x = 0, y = 0, z = 0 }, "F-16C", "unit-1", "Zip")
  luaunit.assertTrue(ok, "an upstream defect must not surface as a crash on the lost-pilot path")
end

-- And it must not run twice for a rescued pilot: the original does it itself.
function TestVeafCsarAddCsarReplacement:test_a_rescued_pilot_has_the_bookkeeping_done_once_by_the_original()
  local calls = 0
  csar.handleEjectOrCrash = function()
    calls = calls + 1
  end
  self:_resolveTo("same")
  veaf.replaceCsarAddCsar()
  csar.addCsar(2, "USA", { x = 0, y = 0, z = 0 }, "F-16C", "unit-1", "Zip")
  luaunit.assertEquals(calls, 0, "the wrapper must not double what the original already does")
end

function TestVeafCsarAddCsarReplacement:test_no_csar_module_is_not_a_crash()
  csar = nil
  local ok = pcall(veaf.replaceCsarAddCsar)
  luaunit.assertTrue(ok)
end

-- ===========================================================================
-- FIX-CSAR-HANDLE-EJECT-ARGUMENT — the replacement of csar.handleEjectOrCrash
--
-- `csar.addCsar` calls `csar.handleEjectOrCrash(_playerName, false)`, and that function indexes its
-- first argument as a unit. Every other caller passes a unit, so the defect only shows on the path that
-- matters: a mission that sets `csar.csarMode` gets *"attempt to index a string value"* instead of the
-- sanction it configured. What the tests below pin is not just "it stops raising" — it is **which
-- sanction still gets applied when only a name is available**, since mode 3 needs the pilot while modes
-- 1 and 2 need the aircraft.
-- ===========================================================================
TestVeafCsarHandleEjectReplacement = {}

function TestVeafCsarHandleEjectReplacement:setUp()
  self._csar = csar
  self._getPlayers = coalition.getPlayers
  self._savedGet = veaf.loggers.get

  self.handled = {}
  self.logged = {}
  -- A fresh csar table per test: the idempotence marker would otherwise leak between them.
  csar = {
    Id = "CSAR",
    csarMode = 0,
    handleEjectOrCrash = function(unit, crashed)
      -- Faithful to the vendored function in the one way that matters here: it indexes its argument
      -- straight away. A string reaching it must blow up in the test exactly as it does in DCS.
      table.insert(self.handled, { name = unit:getName(), player = unit:getPlayerName(), id = unit:getID(), crashed = crashed })
    end,
  }

  local logger = {}
  for _, level in ipairs({ "error", "warn", "info", "debug", "trace" }) do
    logger[level] = function(_, message, ...)
      table.insert(self.logged, { level = level, message = message })
    end
  end
  veaf.loggers.get = function(id)
    if id == "CSAR" then
      return logger
    end
    return self._savedGet(id)
  end
end

function TestVeafCsarHandleEjectReplacement:tearDown()
  csar = self._csar
  coalition.getPlayers = self._getPlayers
  veaf.loggers.get = self._savedGet
end

--- A unit as DCS hands it over, with only what the vendored function touches.
function TestVeafCsarHandleEjectReplacement:_unit(unitName, playerName, id)
  return {
    getName = function()
      return unitName
    end,
    getPlayerName = function()
      return playerName
    end,
    getID = function()
      return id
    end,
  }
end

--- Put `unit` in the sky, so a player-name lookup can find it.
function TestVeafCsarHandleEjectReplacement:_playerFlying(unit)
  coalition.getPlayers = function(side)
    if side == coalition.side.BLUE then
      return { unit }
    end
    return {}
  end
end

function TestVeafCsarHandleEjectReplacement:_warnings()
  local found = {}
  for _, entry in ipairs(self.logged) do
    if entry.level == "warn" then
      table.insert(found, entry.message)
    end
  end
  return found
end

function TestVeafCsarHandleEjectReplacement:test_a_unit_is_handed_over_untouched()
  -- The regression that would hurt most: every existing caller passes a unit, and none of them may
  -- notice the wrapper is there.
  veaf.replaceCsarHandleEjectOrCrash()
  csar.handleEjectOrCrash(self:_unit("Chevy11", "Zip", 42), true)
  luaunit.assertEquals(#self.handled, 1)
  luaunit.assertEquals(self.handled[1].name, "Chevy11")
  luaunit.assertEquals(self.handled[1].player, "Zip")
  luaunit.assertEquals(self.handled[1].id, 42)
  luaunit.assertTrue(self.handled[1].crashed, "the second argument must survive too")
end

function TestVeafCsarHandleEjectReplacement:test_a_player_name_no_longer_raises()
  -- The defect itself, stated as plainly as it can be: this exact call is what `csar.addCsar` makes.
  veaf.replaceCsarHandleEjectOrCrash()
  local ok, err = pcall(csar.handleEjectOrCrash, "Zip", false)
  luaunit.assertTrue(ok, "a player name must not raise: " .. tostring(err))
end

function TestVeafCsarHandleEjectReplacement:test_a_player_name_is_resolved_to_his_unit()
  -- The good case: the pilot is still in an aircraft, so the full sanction is available and the
  -- vendored function gets the real unit — same behaviour as any other caller.
  self:_playerFlying(self:_unit("Chevy11", "Zip", 42))
  veaf.replaceCsarHandleEjectOrCrash()
  csar.handleEjectOrCrash("Zip", false)
  luaunit.assertEquals(#self.handled, 1)
  luaunit.assertEquals(self.handled[1].name, "Chevy11", "the unit's name, not the player's")
  luaunit.assertEquals(self.handled[1].id, 42)
end

function TestVeafCsarHandleEjectReplacement:test_another_players_unit_is_not_mistaken_for_his()
  -- A lookup that matched on anything but the player name would sanction whoever happened to be
  -- flying, which is worse than sanctioning nobody.
  self:_playerFlying(self:_unit("Chevy21", "Sharko", 77))
  csar.csarMode = 3
  veaf.replaceCsarHandleEjectOrCrash()
  csar.handleEjectOrCrash("Zip", false)
  luaunit.assertEquals(#self.handled, 1)
  luaunit.assertEquals(self.handled[1].player, "Zip", "the pilot who ejected, not the one still flying")
  luaunit.assertNil(self.handled[1].id)
end

function TestVeafCsarHandleEjectReplacement:test_mode_3_is_served_from_the_name_alone()
  -- Mode 3 reduces the *pilot's* lives, so the aircraft's identity is not needed and the sanction the
  -- mission configured is still applied.
  csar.csarMode = 3
  veaf.replaceCsarHandleEjectOrCrash()
  csar.handleEjectOrCrash("Zip", false)
  luaunit.assertEquals(#self.handled, 1)
  luaunit.assertEquals(self.handled[1].player, "Zip")
  luaunit.assertEquals(#self:_warnings(), 0, "nothing was skipped, so nothing to warn about")
end

function TestVeafCsarHandleEjectReplacement:test_mode_1_is_refused_rather_than_guessed()
  -- Mode 1 sets a `CSAR_AIRCRAFT<id>` flag, and there is no id to be had. Inventing one grounds an
  -- aircraft nobody chose; a skipped sanction is recoverable, a misapplied one is not.
  csar.csarMode = 1
  veaf.replaceCsarHandleEjectOrCrash()
  csar.handleEjectOrCrash("Zip", false)
  luaunit.assertEquals(#self.handled, 0, "the vendored function must not be called with a made-up id")
  luaunit.assertEquals(#self:_warnings(), 1, "and skipping it silently would hide a broken mission setting")
end

function TestVeafCsarHandleEjectReplacement:test_mode_2_is_refused_too()
  csar.csarMode = 2
  veaf.replaceCsarHandleEjectOrCrash()
  csar.handleEjectOrCrash("Zip", false)
  luaunit.assertEquals(#self.handled, 0)
  luaunit.assertEquals(#self:_warnings(), 1)
end

function TestVeafCsarHandleEjectReplacement:test_the_default_mode_is_still_a_no_op_and_still_silent()
  -- Mode 0 is the default and does nothing at all, so this path must neither raise nor warn: almost
  -- every mission runs here, and a warning on every ejection would be noise.
  veaf.replaceCsarHandleEjectOrCrash()
  csar.handleEjectOrCrash("Zip", false)
  luaunit.assertEquals(#self.handled, 1, "the call still reaches the original, which decides to do nothing")
  luaunit.assertEquals(#self:_warnings(), 0)
end

function TestVeafCsarHandleEjectReplacement:test_replacing_twice_does_not_stack()
  veaf.replaceCsarHandleEjectOrCrash()
  local once = csar.handleEjectOrCrash
  veaf.replaceCsarHandleEjectOrCrash()
  luaunit.assertIs(csar.handleEjectOrCrash, once, "the second call must be a no-op, like the addCsar guard")
end

function TestVeafCsarHandleEjectReplacement:test_no_csar_module_is_not_a_crash()
  csar = nil
  luaunit.assertTrue(pcall(veaf.replaceCsarHandleEjectOrCrash))
end

function TestVeafCsarHandleEjectReplacement:test_a_csar_without_the_function_is_not_a_crash()
  -- A vendored update renaming it must leave the framework standing rather than take the mission down.
  csar = { Id = "CSAR" }
  luaunit.assertTrue(pcall(veaf.replaceCsarHandleEjectOrCrash))
end

-- ---------------------------------------------------------------------------
-- Where the two CSAR fixes meet: the over-water wrapper calls `handleEjectOrCrash` with a player name,
-- and that call is the reason it needed a `pcall` at all. This is the test that says the guard is no
-- longer the thing keeping the mission alive.
-- ---------------------------------------------------------------------------
function TestVeafCsarHandleEjectReplacement:test_the_lost_at_sea_path_sanctions_the_pilot_for_real()
  local savedResolve = veaf.resolveCsarSurvivorPoint
  local savedOutText = trigger.action.outTextForCoalition
  veaf.resolveCsarSurvivorPoint = function()
    return nil -- nothing but water: the pilot is lost
  end
  trigger.action.outTextForCoalition = function() end
  csar.csarMode = 3
  csar.addCsar = function() end

  veaf.replaceCsarAddCsar()
  veaf.replaceCsarHandleEjectOrCrash()
  csar.addCsar(2, "USA", { x = 0, y = 0, z = 0 }, "F-16C", "Chevy11", "Zip")

  veaf.resolveCsarSurvivorPoint = savedResolve
  trigger.action.outTextForCoalition = savedOutText
  luaunit.assertEquals(#self.handled, 1, "ditching at sea must still cost the pilot what the mode says")
  luaunit.assertEquals(self.handled[1].player, "Zip")
  luaunit.assertEquals(#self:_warnings(), 0, "and it must no longer be the pcall reporting a raise")
end

-- ===========================================================================
-- veaf.findUnitForPlayerName
-- ===========================================================================
TestVeafFindUnitForPlayerName = {}

function TestVeafFindUnitForPlayerName:setUp()
  self._getPlayers = coalition.getPlayers
end

function TestVeafFindUnitForPlayerName:tearDown()
  coalition.getPlayers = self._getPlayers
end

function TestVeafFindUnitForPlayerName:test_finds_a_player_on_any_side()
  -- Red, because iterating blue only is the mistake that looks right in a blue-side test.
  local unit = {
    getPlayerName = function()
      return "Sharko"
    end,
  }
  coalition.getPlayers = function(side)
    if side == coalition.side.RED then
      return { unit }
    end
    return {}
  end
  luaunit.assertIs(veaf.findUnitForPlayerName("Sharko"), unit)
end

function TestVeafFindUnitForPlayerName:test_returns_nil_when_nobody_matches()
  luaunit.assertNil(veaf.findUnitForPlayerName("Zip"))
end

function TestVeafFindUnitForPlayerName:test_refuses_a_nil_or_empty_name()
  luaunit.assertNil(veaf.findUnitForPlayerName(nil))
  luaunit.assertNil(veaf.findUnitForPlayerName(""))
end

function TestVeafFindUnitForPlayerName:test_a_side_that_raises_does_not_take_the_lookup_down()
  -- `coalition.getPlayers` is documented but not guaranteed to answer for every side in every build,
  -- and this runs while a pilot is ejecting: the worst moment to raise.
  local unit = {
    getPlayerName = function()
      return "Zip"
    end,
  }
  coalition.getPlayers = function(side)
    if side == coalition.side.NEUTRAL then
      error("no such coalition")
    end
    if side == coalition.side.BLUE then
      return { unit }
    end
    return {}
  end
  luaunit.assertIs(veaf.findUnitForPlayerName("Zip"), unit)
end

-- ===========================================================================
-- FEAT-CTLD-SLINGLOAD-TOGGLE — a global lever on CTLD's virtual sling loading (#60, 2021)
--
-- The setting under test is `enableHoverSlingload`, and the first thing these tests pin is **which
-- setting**, because the obvious candidate is the wrong one: `slingLoad` kept its CTLD 1 name through the
-- CTLD 2 migration and lost its meaning — it now only picks a crate's 3D model. A toggle wired to it
-- would look correct in every code review and change nothing a helicopter crew notices.
-- ===========================================================================
TestVeafCtldSlingloadToggle = {}

function TestVeafCtldSlingloadToggle:setUp()
  self._savedGet = veaf.loggers.get
  self._savedOutText = trigger.action.outText
  self._savedRefresh = veafRadio.refreshRadioMenu
  self._savedAddSecured = veafRadio.addSecuredCommandToSubmenu
  self._savedAddSubMenu = veafRadio.addSubMenu
  self._savedClear = veafRadio.clearSubmenu
  self._savedRoot = veaf.ctldRootPath

  self.messages = {}
  self.logged = {}
  self.commands = {}
  self.cleared = 0

  local logger = {}
  for _, level in ipairs({ "error", "warn", "info", "debug", "trace" }) do
    logger[level] = function(_, message, ...)
      table.insert(self.logged, { level = level, message = message })
    end
  end
  veaf.loggers.get = function(id)
    if id == veaf.ctldId then
      return logger
    end
    return self._savedGet(id)
  end

  trigger.action.outText = function(text, duration)
    table.insert(self.messages, text)
  end

  -- A radio layer that records rather than renders, so a test can read the menu that was built.
  veaf.ctldRootPath = nil
  veafRadio.addSubMenu = function(title)
    return { title = title }
  end
  veafRadio.clearSubmenu = function()
    self.cleared = self.cleared + 1
  end
  veafRadio.addSecuredCommandToSubmenu = function(title, menu, method, parameters, usage)
    table.insert(self.commands, { title = title, method = method, parameters = parameters, usage = usage })
    return {}
  end
  veafRadio.refreshRadioMenu = function() end

  dcs_mocks.reset()
end

function TestVeafCtldSlingloadToggle:tearDown()
  veaf.loggers.get = self._savedGet
  trigger.action.outText = self._savedOutText
  veafRadio.refreshRadioMenu = self._savedRefresh
  veafRadio.addSecuredCommandToSubmenu = self._savedAddSecured
  veafRadio.addSubMenu = self._savedAddSubMenu
  veafRadio.clearSubmenu = self._savedClear
  veaf.ctldRootPath = self._savedRoot
  dcs_mocks.reset()
end

function TestVeafCtldSlingloadToggle:_setting()
  return CTLDConfig.get().settings.enableHoverSlingload
end

-- ── which setting ──────────────────────────────────────────────────────────

function TestVeafCtldSlingloadToggle:test_the_setting_is_the_hover_one_not_slingLoad()
  -- The whole point. `slingLoad` in CTLD 2 chooses a crate's 3D model; wiring the toggle to it would
  -- ship a radio command that reskins crates and nothing else.
  luaunit.assertEquals(veaf.CTLD_SLINGLOAD_SETTING, "enableHoverSlingload")
end

function TestVeafCtldSlingloadToggle:test_it_reads_ctld_rather_than_remembering()
  -- Read at the point of use, never cached: a cached copy is the one way to make the menu lie about the
  -- engine's actual state.
  luaunit.assertTrue(veaf.isCtldSlingloadEnabled())
  CTLDConfig.get():setSetting("enableHoverSlingload", false)
  luaunit.assertFalse(veaf.isCtldSlingloadEnabled())
end

-- ── the toggle ─────────────────────────────────────────────────────────────

function TestVeafCtldSlingloadToggle:test_switching_off_writes_the_setting()
  luaunit.assertTrue(veaf.setCtldSlingloadEnabled(false))
  luaunit.assertFalse(self:_setting())
end

function TestVeafCtldSlingloadToggle:test_switching_back_on_writes_it_too()
  -- Reversible in both directions, which is what makes it a toggle rather than a one-way switch: CTLD's
  -- hover loop reschedules itself before testing the setting, so it is never torn down.
  veaf.setCtldSlingloadEnabled(false)
  veaf.setCtldSlingloadEnabled(true)
  luaunit.assertTrue(self:_setting())
end

function TestVeafCtldSlingloadToggle:test_a_truthy_value_is_not_enough()
  -- `setSetting` must receive a real boolean: CTLD tests the setting with `== true` in places, so a
  -- string or a number would read as off and the toggle would half-work.
  veaf.setCtldSlingloadEnabled("yes")
  luaunit.assertEquals(self:_setting(), false, "anything but true means false, and explicitly so")
end

-- ── what the player is told ────────────────────────────────────────────────

function TestVeafCtldSlingloadToggle:test_switching_off_says_the_dcs_winch_still_works()
  -- The sentence this test exists for. CTLD checks native DCS cargo *before* it looks at this setting,
  -- and all three crate models are `canCargo: true` — so a crate stays hookable with the game's own
  -- sling whatever the toggle says. Unsaid, the first crew to hook a crate reports the command broken.
  veaf.setCtldSlingloadEnabled(false)
  luaunit.assertEquals(#self.messages, 1)
  local message = self.messages[1]
  luaunit.assertNotNil(message:find("DCS", 1, true), "the message must name DCS's own winch: " .. message)
end

function TestVeafCtldSlingloadToggle:test_switching_on_reports_it_too()
  veaf.setCtldSlingloadEnabled(true)
  luaunit.assertEquals(#self.messages, 1)
end

function TestVeafCtldSlingloadToggle:test_the_change_is_logged()
  -- A game-master lever that changes how everybody plays belongs in the log, whoever pressed it.
  veaf.setCtldSlingloadEnabled(false)
  local infos = 0
  for _, entry in ipairs(self.logged) do
    if entry.level == "info" then
      infos = infos + 1
    end
  end
  luaunit.assertTrue(infos >= 1)
end

-- ── the menu ───────────────────────────────────────────────────────────────

function TestVeafCtldSlingloadToggle:test_the_menu_offers_only_the_command_that_changes_something()
  -- Enabled, so the only entry is "disable". A menu holding both asks the player to work out which of
  -- two entries is the no-op.
  veaf.buildCtldRadioMenu()
  luaunit.assertEquals(#self.commands, 1)
  luaunit.assertEquals(self.commands[1].parameters, false, "pressing it must move to OFF")
end

function TestVeafCtldSlingloadToggle:test_and_the_other_way_round_when_it_is_off()
  CTLDConfig.get():setSetting("enableHoverSlingload", false)
  veaf.buildCtldRadioMenu()
  luaunit.assertEquals(#self.commands, 1)
  luaunit.assertEquals(self.commands[1].parameters, true, "pressing it must move to ON")
end

function TestVeafCtldSlingloadToggle:test_the_label_changes_with_the_state()
  veaf.buildCtldRadioMenu()
  local whenOn = self.commands[1].title
  self.commands = {}
  CTLDConfig.get():setSetting("enableHoverSlingload", false)
  veaf.buildCtldRadioMenu()
  luaunit.assertNotEquals(self.commands[1].title, whenOn)
end

function TestVeafCtldSlingloadToggle:test_the_command_is_secured_and_for_everybody()
  -- Secured because it changes how every crew in the mission plays; ForAll because it is not tied to the
  -- group that pressed it.
  veaf.buildCtldRadioMenu()
  luaunit.assertEquals(self.commands[1].usage, veafRadio.USAGE_ForAll)
end

function TestVeafCtldSlingloadToggle:test_toggling_rebuilds_the_menu_in_place()
  -- Otherwise the entry keeps offering the state the mission is already in. Rebuilt in place rather than
  -- re-added, or the submenu would accumulate a command per press.
  veaf.buildCtldRadioMenu()
  luaunit.assertEquals(self.cleared, 0, "the first build creates the submenu")
  veaf.setCtldSlingloadEnabled(false)
  luaunit.assertEquals(self.cleared, 1, "the toggle clears it before rebuilding")
end

function TestVeafCtldSlingloadToggle:test_the_radio_entry_point_passes_the_state_through()
  veaf.radioToggleCtldSlingload(false)
  luaunit.assertFalse(self:_setting())
  veaf.radioToggleCtldSlingload(true)
  luaunit.assertTrue(self:_setting())
end

-- ── when CTLD is not there ─────────────────────────────────────────────────

function TestVeafCtldSlingloadToggle:test_no_menu_when_ctld_never_started()
  -- The state a mission built before FIX-CTLD-NEVER-INITIALIZED is in: script loaded, configuration
  -- never read. A menu built from it would show a default as though it were the engine's state.
  CTLDConfig._instance.isLoaded = false
  veaf.buildCtldRadioMenu()
  luaunit.assertEquals(#self.commands, 0)
  luaunit.assertNil(veaf.ctldRootPath)
end

function TestVeafCtldSlingloadToggle:test_toggling_refuses_when_ctld_never_started()
  CTLDConfig._instance.isLoaded = false
  luaunit.assertFalse(veaf.setCtldSlingloadEnabled(false))
  luaunit.assertEquals(#self.messages, 0, "and it must not claim to have changed anything")
end

function TestVeafCtldSlingloadToggle:test_reading_the_state_refuses_rather_than_guessing()
  CTLDConfig._instance.isLoaded = false
  luaunit.assertFalse(veaf.isCtldSlingloadEnabled())
end

-- ===========================================================================
-- FEAT-COORDINATE-FORMATS — every coordinate a pilot can read off his own screen
--
-- This is the single coordinate reader for veafAirWaves, veafGroundAI (target and validation),
-- veafNamedPoints, veafQraCore and the aliases. The family is enumerated here rather than sampled: a
-- coordinate that is quietly wrong is worse than one that is refused, and the failure mode is shells in
-- the wrong village.
--
-- `coord.MGRStoLL` is a DCS function and the mock returns 0,0, so the MGRS tests assert what is handed
-- TO it. That is the right boundary anyway: the parsing is ours, the projection is DCS's.
-- ===========================================================================
TestVeafCoordinateFormats = {}

function TestVeafCoordinateFormats:setUp()
  self._savedMGRStoLL = coord.MGRStoLL
  self.mgrs = nil
  local test = self
  coord.MGRStoLL = function(t)
    test.mgrs = t
    return 0, 0
  end
end

function TestVeafCoordinateFormats:tearDown()
  coord.MGRStoLL = self._savedMGRStoLL
end

--- @return table|nil what the MGRS branch handed to DCS, or nil if the string was refused
function TestVeafCoordinateFormats:_mgrs(s)
  self.mgrs = nil
  veaf.computeLLFromString(s)
  return self.mgrs
end

-- ── MGRS, and the digit count is the precision ──────────────────────────────

function TestVeafCoordinateFormats:test_mgrs_four_digits_is_a_kilometre()
  local m = self:_mgrs("u37TGG1234")
  luaunit.assertNotNil(m, "u37TGG1234 must be read")
  luaunit.assertEquals(m.UTMZone, "37T")
  luaunit.assertEquals(m.MGRSDigraph, "GG")
  luaunit.assertEquals(m.Easting, 12000)
  luaunit.assertEquals(m.Northing, 34000)
end

function TestVeafCoordinateFormats:test_mgrs_eight_digits_is_ten_metres()
  local m = self:_mgrs("u37TGG12345678")
  luaunit.assertEquals(m.Easting, 12340)
  luaunit.assertEquals(m.Northing, 56780)
end

function TestVeafCoordinateFormats:test_mgrs_ten_digits_is_one_metre()
  -- The precision David asked for: two groups of five.
  local m = self:_mgrs("u37TGG1234512345")
  luaunit.assertEquals(m.Easting, 12345)
  luaunit.assertEquals(m.Northing, 12345)
end

function TestVeafCoordinateFormats:test_mgrs_without_the_u_prefix()
  -- Nothing on a pilot's screen has a `u` in front of it.
  local m = self:_mgrs("37TGG1234512345")
  luaunit.assertNotNil(m, "the prefix must be optional")
  luaunit.assertEquals(m.Easting, 12345)
end

function TestVeafCoordinateFormats:test_mgrs_exactly_as_dcs_displays_it()
  -- THE case this lot exists for. Making a pilot retype `37T GG 12345 12345` as `u37TGG1234512345` is
  -- the transcription that puts shells in the wrong village.
  local m = self:_mgrs("37T GG 12345 12345")
  luaunit.assertNotNil(m, "the spaced form must be read")
  luaunit.assertEquals(m.UTMZone, "37T")
  luaunit.assertEquals(m.MGRSDigraph, "GG")
  luaunit.assertEquals(m.Easting, 12345)
  luaunit.assertEquals(m.Northing, 12345)
end

function TestVeafCoordinateFormats:test_mgrs_with_a_leading_label()
  local m = self:_mgrs("MGRS 37T GG 12345 12345")
  luaunit.assertNotNil(m)
  luaunit.assertEquals(m.Northing, 12345)
end

function TestVeafCoordinateFormats:test_mgrs_is_case_insensitive()
  local m = self:_mgrs("37t gg 12345 12345")
  luaunit.assertNotNil(m)
  luaunit.assertEquals(m.UTMZone, "37T", "the zone must reach DCS upper-cased")
  luaunit.assertEquals(m.MGRSDigraph, "GG")
end

function TestVeafCoordinateFormats:test_an_odd_digit_count_is_refused()
  -- MGRS digits come in pairs. An odd count used to be halved anyway, producing a position nobody typed.
  luaunit.assertNil(veaf.computeLLFromString("u37TGG12345"))
  luaunit.assertNil(self:_mgrs("37TGG123"))
end

function TestVeafCoordinateFormats:test_too_many_digits_is_refused()
  -- Five digits a side is one metre; there is nothing finer to mean.
  luaunit.assertNil(veaf.computeLLFromString("37TGG123456789012"))
end

-- ── DMS, and the exact value ────────────────────────────────────────────────
-- 42:30:15 is 42 + 30/60 + 15/3600 = 42.5041666..., not 42.5038888. The one arc-second an accumulator
-- starting at -1 used to remove is about 31 metres of northing, and it was on every DMS coordinate in
-- every VEAF mission since 2021.

function TestVeafCoordinateFormats:test_dms_with_colons_is_exact()
  local lat, lon = veaf.computeLLFromString("N42:30:15E041:45:30")
  luaunit.assertAlmostEquals(lat, 42.5041667, 0.0000005)
  luaunit.assertAlmostEquals(lon, 41.7583333, 0.0000005)
end

function TestVeafCoordinateFormats:test_dms_with_dashes_is_exact()
  local lat, lon = veaf.computeLLFromString("N42-30-15E041-45-30")
  luaunit.assertAlmostEquals(lat, 42.5041667, 0.0000005)
end

function TestVeafCoordinateFormats:test_dms_with_spaces()
  -- How a pilot writes it when nobody told him a separator.
  local lat, lon = veaf.computeLLFromString("N42 30 15 E041 45 30")
  luaunit.assertNotNil(lat, "spaces must be accepted")
  luaunit.assertAlmostEquals(lat, 42.5041667, 0.0000005)
  luaunit.assertAlmostEquals(lon, 41.7583333, 0.0000005)
end

function TestVeafCoordinateFormats:test_dms_with_the_symbols()
  local lat, lon = veaf.computeLLFromString("N42°30'15\"E041°45'30\"")
  luaunit.assertNotNil(lat, "degree, minute and second symbols must be accepted")
  luaunit.assertAlmostEquals(lat, 42.5041667, 0.0000005)
end

function TestVeafCoordinateFormats:test_degrees_and_decimal_minutes()
  -- The form a DCS kneeboard and most aviation charts use.
  local lat, lon = veaf.computeLLFromString("N42:30.5E041:45.5")
  luaunit.assertAlmostEquals(lat, 42.5083333, 0.0000005)
  luaunit.assertAlmostEquals(lon, 41.7583333, 0.0000005)
end

function TestVeafCoordinateFormats:test_south_and_west_are_negative()
  local lat, lon = veaf.computeLLFromString("S42:30:15W041:45:30")
  luaunit.assertAlmostEquals(lat, -42.5041667, 0.0000005)
  luaunit.assertAlmostEquals(lon, -41.7583333, 0.0000005)
end

-- ── decimal degrees, which already worked and had no test ───────────────────

function TestVeafCoordinateFormats:test_decimal_degrees()
  local lat, lon = veaf.computeLLFromString("N42.50416E041.75833")
  luaunit.assertAlmostEquals(lat, 42.50416, 0.000005)
  luaunit.assertAlmostEquals(lon, 41.75833, 0.000005)
end

function TestVeafCoordinateFormats:test_whole_degrees_still_work()
  -- Coarse — about 100 km — but a mission maker sketching a zone may mean exactly this.
  local lat, lon = veaf.computeLLFromString("N42E041")
  luaunit.assertAlmostEquals(lat, 42, 0.000001)
  luaunit.assertAlmostEquals(lon, 41, 0.000001)
end

-- ── refusals ────────────────────────────────────────────────────────────────

function TestVeafCoordinateFormats:test_longitude_first_is_refused_rather_than_swapped()
  -- The old reader ACCEPTED this and returned the two values the wrong way round: it took the first
  -- hemisphere letter as the latitude's whatever it was, so `E041N42` came back as lat 41, lon 42. A
  -- coordinate silently transposed is worse than one refused, which is the whole argument of this lot.
  luaunit.assertNil(veaf.computeLLFromString("E041N42"))
  luaunit.assertNil(veaf.computeLLFromString("E041:45:30N42:30:15"))
end

function TestVeafCoordinateFormats:test_two_latitudes_are_refused()
  luaunit.assertNil(veaf.computeLLFromString("N42N41"))
  luaunit.assertNil(veaf.computeLLFromString("E041W040"))
end

function TestVeafCoordinateFormats:test_nonsense_is_refused()
  luaunit.assertNil(veaf.computeLLFromString("somewhere over there"))
  luaunit.assertNil(veaf.computeLLFromString(""))
  luaunit.assertNil(veaf.computeLLFromString(nil))
  luaunit.assertNil(veaf.computeLLFromString("N42"))
  luaunit.assertNil(veaf.computeLLFromString("42N041E"))
end

-- ===========================================================================
-- veaf.findGroupByPartialName — retrouver un groupe par le nom qu'on lui a donne
--
-- `getNameForSpawnedGroup` decore le nom : `-arty, unitname arty-1` sur une batterie bleue produit un
-- groupe reellement appele `[b]-arty-1#7`. Un `Group.getByName("arty-1")` exact ne le trouve jamais.
--
-- L'ambiguite est REFUSEE, pas arbitree : avec `arty-1` et `arty-10` en vol, choisir ferait tirer une
-- batterie que personne n'a designee.
-- ===========================================================================
TestFindGroupByPartialName = {}

function TestFindGroupByPartialName:setUp()
  dcs_mocks.reset()
end

function TestFindGroupByPartialName:test_an_exact_name_wins()
  -- Le groupe pose dans l'editeur : son nom n'est jamais touche, et la recherche exacte reste la
  -- premiere reponse — la seule qui ne puisse pas etre ambigue.
  dcs_mocks.addGroup("ARTY-1")
  local group = veaf.findGroupByPartialName("ARTY-1")
  luaunit.assertNotNil(group)
  luaunit.assertEquals(group:getName(), "ARTY-1")
end

function TestFindGroupByPartialName:test_a_spawned_group_is_found_by_the_name_it_was_given()
  -- LE cas du lot : le nom decore contient celui qu'on a demande.
  dcs_mocks.addGroup("[b]-arty-1#7")
  local group = veaf.findGroupByPartialName("arty-1")
  luaunit.assertNotNil(group, "le nom donne au spawn doit suffire")
  luaunit.assertEquals(group:getName(), "[b]-arty-1#7")
end

function TestFindGroupByPartialName:test_the_case_does_not_matter()
  dcs_mocks.addGroup("[b]-ARTY-1#7")
  luaunit.assertNotNil(veaf.findGroupByPartialName("arty-1"))
end

function TestFindGroupByPartialName:test_a_name_with_magic_characters_is_taken_literally()
  -- `[b]-` porte des caracteres que `find` interpreterait comme un motif : la recherche doit etre
  -- litterale, sinon un nom decore colle depuis le log ne trouve rien.
  dcs_mocks.addGroup("[b]-arty-1#7")
  luaunit.assertNotNil(veaf.findGroupByPartialName("[b]-arty"))
end

function TestFindGroupByPartialName:test_an_ambiguous_name_is_refused()
  dcs_mocks.addGroup("[b]-arty-1#7")
  dcs_mocks.addGroup("[b]-arty-10#8")
  local group, candidats = veaf.findGroupByPartialName("arty-1")
  luaunit.assertNil(group, "l'ambiguite ne se tranche pas au hasard")
  luaunit.assertNotNil(candidats, "et les candidats doivent etre nommes")
  luaunit.assertEquals(#candidats, 2)
  luaunit.assertEquals(candidats[1], "[b]-arty-1#7")
  luaunit.assertEquals(candidats[2], "[b]-arty-10#8")
end

function TestFindGroupByPartialName:test_an_exact_name_beats_an_ambiguity()
  -- `arty-1` existe exactement : plus rien a arbitrer, meme si `arty-10` traine.
  dcs_mocks.addGroup("arty-1")
  dcs_mocks.addGroup("arty-10")
  local group = veaf.findGroupByPartialName("arty-1")
  luaunit.assertNotNil(group)
  luaunit.assertEquals(group:getName(), "arty-1")
end

function TestFindGroupByPartialName:test_an_unknown_name_finds_nothing()
  dcs_mocks.addGroup("[b]-arty-1#7")
  local group, candidats = veaf.findGroupByPartialName("mortier")
  luaunit.assertNil(group)
  luaunit.assertNil(candidats, "rien trouve n'est pas une ambiguite")
end

function TestFindGroupByPartialName:test_a_group_is_not_counted_twice()
  -- L'enumeration passe par les trois coalitions : un groupe qui n'en declare aucune apparait dans les
  -- trois listes, et sans dedoublonnage il se refuserait pour ambiguite avec lui-meme.
  dcs_mocks.addGroup("[b]-arty-1#7")
  local group, candidats = veaf.findGroupByPartialName("arty-1")
  luaunit.assertNotNil(group, "un groupe ne peut pas etre ambigu avec lui-meme")
  luaunit.assertNil(candidats)
end

function TestFindGroupByPartialName:test_nothing_sensible_is_refused_quietly()
  luaunit.assertNil(veaf.findGroupByPartialName(nil))
  luaunit.assertNil(veaf.findGroupByPartialName(""))
  luaunit.assertNil(veaf.findGroupByPartialName(42))
end

function TestFindGroupByPartialName:test_it_survives_a_group_with_no_name()
  -- DCS rend parfois un groupe dont `getName` echoue ; il ne doit pas emporter la recherche.
  dcs_mocks.addGroup("[b]-arty-1#7")
  dcs_mocks.addGroup("sans-nom", {
    getName = function()
      return nil
    end,
  })
  luaunit.assertNotNil(veaf.findGroupByPartialName("arty-1"))
end

os.exit(luaunit.LuaUnit.run())
