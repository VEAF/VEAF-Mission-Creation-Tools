--- Tests for veafCasMission.lua — constants and TRANSPORT_TYPES structure.
local _base = debug.getinfo(1, "S").source:match("^@(.+)[\\/]") or "."
luaunit = dofile(_base .. "/luaunit.lua")
dofile(_base .. "/dcs_mocks.lua")
local src = _base .. "/../../src/scripts/veaf"
dofile(src .. "/veaf.lua")
dofile(src .. "/veafCasMission.lua")

-- ---------------------------------------------------------------------------
-- TestVeafCasMissionConstants
-- ---------------------------------------------------------------------------
TestVeafCasMissionConstants = {}

function TestVeafCasMissionConstants:test_keyphrase()
  luaunit.assertEquals(veafCasMission.Keyphrase, "_cas")
end

function TestVeafCasMissionConstants:test_id()
  luaunit.assertEquals(veafCasMission.Id, "CASMISSION")
end

function TestVeafCasMissionConstants:test_secondsBetweenWatchdogChecks()
  luaunit.assertEquals(veafCasMission.SecondsBetweenWatchdogChecks, 15)
end

function TestVeafCasMissionConstants:test_secondsBetweenSmokeRequests()
  luaunit.assertEquals(veafCasMission.SecondsBetweenSmokeRequests, 180)
end

function TestVeafCasMissionConstants:test_secondsBetweenFlareRequests()
  luaunit.assertEquals(veafCasMission.SecondsBetweenFlareRequests, 120)
end

-- ---------------------------------------------------------------------------
-- TestVeafCasTransportTypes
-- ---------------------------------------------------------------------------
TestVeafCasTransportTypes = {}

function TestVeafCasTransportTypes:test_transport_types_is_table()
  luaunit.assertIsTable(veafCasMission.TRANSPORT_TYPES)
end

function TestVeafCasTransportTypes:test_transport_types_has_two_entries()
  luaunit.assertEquals(#veafCasMission.TRANSPORT_TYPES, 2)
end

function TestVeafCasTransportTypes:test_each_entry_has_modern_key()
  for _, entry in ipairs(veafCasMission.TRANSPORT_TYPES) do
    luaunit.assertNotNil(entry.MODERN)
  end
end

function TestVeafCasTransportTypes:test_each_entry_has_ww2_key()
  for _, entry in ipairs(veafCasMission.TRANSPORT_TYPES) do
    luaunit.assertNotNil(entry.WW2)
  end
end

function TestVeafCasTransportTypes:test_each_entry_has_cold_war_key()
  for _, entry in ipairs(veafCasMission.TRANSPORT_TYPES) do
    luaunit.assertNotNil(entry.COLD_WAR)
  end
end

-- ---------------------------------------------------------------------------
-- TestVeafCasMarkTextAnalysis
-- ---------------------------------------------------------------------------
TestVeafCasMarkTextAnalysis = {}

function TestVeafCasMarkTextAnalysis:test_matching_keyphrase_returns_table()
  local r = veafCasMission.markTextAnalysis("_cas")
  luaunit.assertIsTable(r)
end

function TestVeafCasMarkTextAnalysis:test_non_matching_returns_nil()
  local r = veafCasMission.markTextAnalysis("_spawn")
  luaunit.assertNil(r)
end

function TestVeafCasMarkTextAnalysis:test_cas_field_set()
  local r = veafCasMission.markTextAnalysis("_cas")
  luaunit.assertNotNil(r)
  luaunit.assertTrue(r.casmission)
end

-- ---------------------------------------------------------------------------
-- TestVeafCasMarkTextAnalysisKeywords
-- ---------------------------------------------------------------------------
TestVeafCasMarkTextAnalysisKeywords = {}

function TestVeafCasMarkTextAnalysisKeywords:test_password_keyword()
  local r = veafCasMission.markTextAnalysis("_cas, password secret")
  luaunit.assertNotNil(r)
  luaunit.assertEquals(r.password, "secret")
end

function TestVeafCasMarkTextAnalysisKeywords:test_size_keyword()
  local r = veafCasMission.markTextAnalysis("_cas, size 3")
  luaunit.assertNotNil(r)
  luaunit.assertEquals(r.size, 3)
end

function TestVeafCasMarkTextAnalysisKeywords:test_defense_keyword()
  local r = veafCasMission.markTextAnalysis("_cas, defense 2")
  luaunit.assertNotNil(r)
  luaunit.assertEquals(r.defense, 2)
end

function TestVeafCasMarkTextAnalysisKeywords:test_armor_keyword()
  local r = veafCasMission.markTextAnalysis("_cas, armor 4")
  luaunit.assertNotNil(r)
  luaunit.assertEquals(r.armor, 4)
end

function TestVeafCasMarkTextAnalysisKeywords:test_spacing_keyword()
  local r = veafCasMission.markTextAnalysis("_cas, spacing 2")
  luaunit.assertNotNil(r)
  luaunit.assertEquals(r.spacing, 2)
end

function TestVeafCasMarkTextAnalysisKeywords:test_side_blue()
  local r = veafCasMission.markTextAnalysis("_cas, side BLUE")
  luaunit.assertNotNil(r)
  luaunit.assertEquals(r.side, veafCasMission.SIDE_BLUE)
end

function TestVeafCasMarkTextAnalysisKeywords:test_side_non_blue_is_red()
  local r = veafCasMission.markTextAnalysis("_cas, side RED")
  luaunit.assertNotNil(r)
  luaunit.assertEquals(r.side, veafCasMission.SIDE_RED)
end

function TestVeafCasMarkTextAnalysisKeywords:test_disperse_with_value()
  local r = veafCasMission.markTextAnalysis("_cas, disperse 30")
  luaunit.assertNotNil(r)
  luaunit.assertEquals(r.disperseOnAttack, 30)
end

-- ---------------------------------------------------------------------------
-- TestVeafCasMarkTextAnalysisBadParameters
--
-- FIX-MARKER-PARAM-CRASHES: a parameter the pilot mistyped costs that parameter,
-- never the command. `side` was the one site VMR-019 missed here: it fixed the four
-- `string.format("%d", val)` keywords and left this one's `%s`, which raises on nil
-- just the same, with `val:upper()` on the next line waiting behind it.
-- ---------------------------------------------------------------------------
TestVeafCasMarkTextAnalysisBadParameters = {}

function TestVeafCasMarkTextAnalysisBadParameters:test_side_without_value_does_not_raise()
  local r = veafCasMission.markTextAnalysis("_cas, side")
  luaunit.assertNotNil(r)
  luaunit.assertTrue(r.casmission)
end

-- A valueless `side` must leave the field unset, not fall through to RED: executeCommand
-- then derives the side from the marker's own coalition, which is the intended path.
function TestVeafCasMarkTextAnalysisBadParameters:test_side_without_value_leaves_side_unset()
  local r = veafCasMission.markTextAnalysis("_cas, side")
  luaunit.assertNotNil(r)
  luaunit.assertNil(r.side)
end

function TestVeafCasMarkTextAnalysisBadParameters:test_size_without_value_keeps_default()
  local r = veafCasMission.markTextAnalysis("_cas, size")
  luaunit.assertNotNil(r)
  luaunit.assertEquals(r.size, 1)
end

function TestVeafCasMarkTextAnalysisBadParameters:test_size_non_numeric_keeps_default()
  local r = veafCasMission.markTextAnalysis("_cas, size banana")
  luaunit.assertNotNil(r)
  luaunit.assertEquals(r.size, 1)
end

-- ---------------------------------------------------------------------------
-- TestVeafCasCharacterisation
--
-- REFACTOR-MARKER-PARSER ticket 01: what this parser does TODAY, measured against the live
-- parser. Anything here that looks wrong is recorded rather than fixed; the ticket's inventory
-- separates the deliberate quirks from the accidental ones.
-- ---------------------------------------------------------------------------
TestVeafCasCharacterisation = {}

-- Bounds are asymmetric on purpose: size and spacing start at 1, defense and armor at 0.
function TestVeafCasCharacterisation:test_size_and_spacing_reject_zero()
  luaunit.assertEquals(veafCasMission.markTextAnalysis("_cas, size 0").size, 1)
  luaunit.assertEquals(veafCasMission.markTextAnalysis("_cas, spacing 0").spacing, 1)
end

function TestVeafCasCharacterisation:test_defense_and_armor_accept_zero()
  luaunit.assertEquals(veafCasMission.markTextAnalysis("_cas, defense 0").defense, 0)
  luaunit.assertEquals(veafCasMission.markTextAnalysis("_cas, armor 0").armor, 0)
end

-- Out of range is ignored, not clamped — the value stays at its default.
function TestVeafCasCharacterisation:test_above_the_maximum_is_ignored_not_clamped()
  luaunit.assertEquals(veafCasMission.markTextAnalysis("_cas, size 6").size, 1)
end

-- No integer requirement: a decimal inside the bounds is accepted as-is.
function TestVeafCasCharacterisation:test_a_decimal_inside_the_bounds_is_accepted()
  luaunit.assertEquals(veafCasMission.markTextAnalysis("_cas, size 2.5").size, 2.5)
end

-- The keyword loop applies every occurrence in order, so a repeated keyword ends on the last.
function TestVeafCasCharacterisation:test_a_repeated_keyword_keeps_the_last_value()
  luaunit.assertEquals(veafCasMission.markTextAnalysis("_cas, size 3, size 4").size, 4)
end

-- Any value that is not exactly "BLUE" after upper-casing means RED. Deliberate.
function TestVeafCasCharacterisation:test_side_is_case_insensitive()
  luaunit.assertEquals(veafCasMission.markTextAnalysis("_cas, side blue").side, veafCasMission.SIDE_BLUE)
end

function TestVeafCasCharacterisation:test_any_other_side_value_means_red()
  luaunit.assertEquals(veafCasMission.markTextAnalysis("_cas, side banana").side, veafCasMission.SIDE_RED)
end

-- DEFECT, recorded not fixed: only the FIRST space separates key from value, so a second
-- space becomes part of the value — and " BLUE" is not "BLUE", so a pilot who typed two
-- spaces silently gets the enemy side.
function TestVeafCasCharacterisation:test_a_double_space_before_BLUE_silently_yields_red()
  luaunit.assertEquals(veafCasMission.markTextAnalysis("_cas, side  BLUE").side, veafCasMission.SIDE_RED)
end

-- DEFECT, recorded not fixed: `disperse` alone was written to mean "after 15 seconds"
-- (`if val ~= "" then tonumber(val) else 15 end`), but veaf.breakString returns nil for a
-- valueless keyword and never "", so the `else` is unreachable and the option stays false.
function TestVeafCasCharacterisation:test_bare_disperse_never_reaches_its_15_second_default()
  luaunit.assertFalse(veafCasMission.markTextAnalysis("_cas, disperse").disperseOnAttack)
end

function TestVeafCasCharacterisation:test_disperse_accepts_zero()
  luaunit.assertEquals(veafCasMission.markTextAnalysis("_cas, disperse 0").disperseOnAttack, 0)
end

function TestVeafCasCharacterisation:test_non_numeric_disperse_keeps_the_default()
  luaunit.assertFalse(veafCasMission.markTextAnalysis("_cas, disperse banana").disperseOnAttack)
end

-- Whitespace: veaf.trim runs before the split, so a trailing space is not a value, and a
-- missing space after the comma is fine.
function TestVeafCasCharacterisation:test_a_trailing_space_is_not_a_value()
  luaunit.assertNil(veafCasMission.markTextAnalysis("_cas, password ").password)
end

function TestVeafCasCharacterisation:test_a_comma_needs_no_following_space()
  luaunit.assertEquals(veafCasMission.markTextAnalysis("_cas,size 3").size, 3)
end

function TestVeafCasCharacterisation:test_extra_whitespace_around_the_comma_is_tolerated()
  luaunit.assertEquals(veafCasMission.markTextAnalysis("_cas ,  size 3").size, 3)
end

-- The keyphrase is searched anywhere in the text, not anchored, and case-insensitively.
function TestVeafCasCharacterisation:test_the_keyphrase_is_found_mid_sentence()
  luaunit.assertNotNil(veafCasMission.markTextAnalysis("please _cas here"))
end

function TestVeafCasCharacterisation:test_the_keyphrase_is_case_insensitive()
  luaunit.assertNotNil(veafCasMission.markTextAnalysis("_CAS"))
end

-- An unknown keyword is ignored in silence: no report, no effect on the defaults.
function TestVeafCasCharacterisation:test_unknown_keyword_is_ignored_silently()
  local r = veafCasMission.markTextAnalysis("_cas, banana 3")
  luaunit.assertNotNil(r)
  luaunit.assertEquals(r.size, 1)
  luaunit.assertNil(r.unknownParameters)
end

function TestVeafCasCharacterisation:test_empty_text_returns_nil()
  luaunit.assertNil(veafCasMission.markTextAnalysis(""))
end

-- SECREV-007: generateAirDefenseGroup must return nil (not dereference a nil
-- group) when the underlying group definition cannot be found.
TestVeafCasMissionAirDefense = {}

function TestVeafCasMissionAirDefense:test_returns_nil_when_group_not_found()
  local savedVeafUnits = veafUnits
  veafUnits = {
    findGroup = function()
      return nil
    end,
  }
  local result = veafCasMission.generateAirDefenseGroup("AD-1", 1, veafCasMission.SIDE_RED)
  veafUnits = savedVeafUnits
  luaunit.assertNil(result)
end

-------------------------------------------------------------------------------------------------
-- SECREV-2 / VMR-019 — a valueless numeric keyword must not take the handler down
--
-- `_cas, size` (no value) reached `string.format("Keyword size = %d", nil)` and then
-- `tonumber(nil) <= 5`. Either one raises, and the marker handler dies with it -- so a typo
-- silently killed the command instead of ignoring one parameter.
-------------------------------------------------------------------------------------------------

TestVeafCasMissionNumericKeywords = {}

function TestVeafCasMissionNumericKeywords:_analyse(text)
  return veafCasMission.markTextAnalysis(text)
end

function TestVeafCasMissionNumericKeywords:test_valueless_size_does_not_crash()
  local ok, result = pcall(function()
    return self:_analyse("_cas, size")
  end)
  luaunit.assertTrue(ok, "a valueless size keyword must not raise")
  luaunit.assertNotNil(result)
end

function TestVeafCasMissionNumericKeywords:test_valueless_defense_does_not_crash()
  local ok = pcall(function()
    return self:_analyse("_cas, defense")
  end)
  luaunit.assertTrue(ok)
end

function TestVeafCasMissionNumericKeywords:test_valueless_armor_does_not_crash()
  local ok = pcall(function()
    return self:_analyse("_cas, armor")
  end)
  luaunit.assertTrue(ok)
end

function TestVeafCasMissionNumericKeywords:test_valueless_spacing_does_not_crash()
  local ok = pcall(function()
    return self:_analyse("_cas, spacing")
  end)
  luaunit.assertTrue(ok)
end

function TestVeafCasMissionNumericKeywords:test_garbage_size_does_not_crash()
  local ok = pcall(function()
    return self:_analyse("_cas, size banana")
  end)
  luaunit.assertTrue(ok)
end

function TestVeafCasMissionNumericKeywords:test_a_valid_size_is_still_honoured()
  -- Guard: the crash fix must not stop the parameter working.
  local result = self:_analyse("_cas, size 3")
  luaunit.assertEquals(result.size, 3)
end

function TestVeafCasMissionNumericKeywords:test_out_of_range_size_is_still_ignored()
  -- Behaviour deliberately preserved: an out-of-range value is ignored, not clamped.
  local result = self:_analyse("_cas, size 9")
  luaunit.assertNotEquals(result.size, 9)
end

os.exit(luaunit.LuaUnit.run())
