--- Tests for veafCasMission.lua — constants and TRANSPORT_TYPES structure.
local _base = debug.getinfo(1, "S").source:match("^@(.+)[\\/]") or "."
luaunit = dofile(_base .. "/luaunit.lua")
dofile(_base .. "/dcs_mocks.lua")
local src = _base .. "/../../src/scripts/veaf"
dofile(src .. "/veaf.lua")
dofile(src .. "/veafScheduler.lua")
dofile(src .. "/veafMath.lua")
dofile(src .. "/veafGeo.lua")
dofile(src .. "/veafMissionDb.lua")
dofile(src .. "/veafDcsSpawner.lua")
-- FIX-PLATOON-UNITS: the type tables below are hand-written, and the point of the sweep at the end
-- of this file is to check every entry against the generated DCS database. That needs the real
-- databases, not stubs.
dofile(src .. "/dcsUnits.lua")
dofile(src .. "/veafUnits.lua")
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

-- FIXED (ticket 03): `disperse` alone was written to mean "after 15 seconds"
-- (`if val ~= "" then tonumber(val) else 15 end`), but veaf.breakString returns nil for a
-- valueless keyword and never "", so the `else` was unreachable and the option stayed false.
-- The declared parameter now treats both nil and "" as "the pilot asked for the default".
function TestVeafCasCharacterisation:test_bare_disperse_means_15_seconds()
  luaunit.assertEquals(veafCasMission.markTextAnalysis("_cas, disperse").disperseOnAttack, 15)
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

-- FEAT-SPAWN-OPTION-VALIDATION renamed this: an unknown keyword is no longer ignored, it is
-- collected so the caller can name it to the pilot and abort. What the original test proved and
-- this one still proves: the **recognised** options are untouched by the presence of a bad one.
function TestVeafCasCharacterisation:test_an_unknown_keyword_is_collected_not_ignored()
  local r = veafCasMission.markTextAnalysis("_cas, banana 3")
  luaunit.assertNotNil(r)
  luaunit.assertEquals(r.size, 1)
  luaunit.assertEquals(r.unknownParameters[1].key, "banana")
  luaunit.assertEquals(#r.unknownParameters, 1)
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

-- ============================================================================
-- FIX-PLATOON-UNITS — every hand-written type must exist in the generated database
--
-- #296: the Currenthill units live in `dcsUnits`, kept fresh by `update-dcs-data`, while a platoon
-- composition is a hand-written table here. So the data pipeline gains units and the spawner never sees
-- them — and, worse, an entry can rot without anyone noticing: a type DCS renames or drops simply stops
-- spawning, silently, because `veafUnits.findUnit` logs and returns nil.
--
-- This sweep is **enumerated, not sampled**: every entry of every table, so a typo cannot hide behind
-- the ones that happen to be checked. It is the part of this lot that stops the problem recurring —
-- adding units fixes today, this fails the build tomorrow.
-- ============================================================================
TestVeafCasMissionTypesExist = {}

local TYPE_TABLES = {
  TRANSPORT_TYPES = veafCasMission.TRANSPORT_TYPES,
  ARMOR_TYPES = veafCasMission.ARMOR_TYPES,
  INFANTRY_TYPES = veafCasMission.INFANTRY_TYPES,
  INFANTRY_IFV_TYPES = veafCasMission.INFANTRY_IFV_TYPES,
}

--- Walk a nested table of type-name lists, calling `visit(typeName, path)` on every string leaf.
local function walkTypes(node, path, visit)
  if type(node) == "string" then
    visit(node, path)
    return
  end
  if type(node) ~= "table" then
    return
  end
  for key, child in pairs(node) do
    walkTypes(child, path .. "[" .. tostring(key) .. "]", visit)
  end
end

function TestVeafCasMissionTypesExist:test_every_type_in_every_table_is_known_to_the_database()
  local missing = {}
  local checked = 0
  for tableName, tbl in pairs(TYPE_TABLES) do
    walkTypes(tbl, tableName, function(typeName, path)
      checked = checked + 1
      if not veafUnits.findDcsUnit(typeName) then
        table.insert(missing, path .. " = " .. typeName)
      end
    end)
  end
  luaunit.assertTrue(checked > 100, "the sweep found only " .. checked .. " types; it is not reaching the tables")
  luaunit.assertEquals(missing, {}, "types no unit database knows:\n  " .. table.concat(missing, "\n  "))
end

-- The units #296 asked for, named rather than assumed present: this is what the lot promised.
function TestVeafCasMissionTypesExist:test_the_units_296_asked_for_can_be_spawned()
  local wanted = { "CHAP_T84OplotM", "CHAP_T90M", "CHAP_BMPT" }
  for _, typeName in ipairs(wanted) do
    luaunit.assertNotNil(veafUnits.findDcsUnit(typeName), typeName .. " must exist in the database")
    local found = false
    walkTypes(veafCasMission.ARMOR_TYPES, "ARMOR_TYPES", function(candidate)
      if candidate == typeName then
        found = true
      end
    end)
    luaunit.assertTrue(found, typeName .. " must appear in an armour tier, or it can never be spawned")
  end
end

--- Is this node a flat list of type names, rather than a table of tiers?
---
--- The two shapes coexist on purpose: `INFANTRY_TYPES` is side → era → names, while the other three are
--- side → era → tier → names. Telling them apart matters more than it looks — a traversal that assumed
--- tiers everywhere did **not** raise on the flat one (Lua's `#` on a string is its length, so
--- `#"Soldier RPG" > 0` is happily true) and quietly asserted nothing at all about infantry.
local function isFlatTypeList(node)
  if type(node) ~= "table" or #node == 0 then
    return false
  end
  for _, value in ipairs(node) do
    if type(value) ~= "string" then
      return false
    end
  end
  return true
end

-- A tier is drawn from at random, so an empty one above tier 0 would spawn nothing at all. The flat
-- shape has the same requirement without the tier: an empty list spawns nothing either.
function TestVeafCasMissionTypesExist:test_no_list_a_spawn_draws_from_is_empty()
  local checkedTiers, checkedFlat = 0, 0
  for tableName, tbl in pairs(TYPE_TABLES) do
    for side, byEra in pairs(tbl) do
      for era, node in pairs(byEra) do
        local where = string.format("%s[%s][%s]", tableName, tostring(side), tostring(era))
        if isFlatTypeList(node) then
          checkedFlat = checkedFlat + 1
          luaunit.assertTrue(#node > 0, where .. " is empty: it would spawn nothing")
        else
          for tier, types in pairs(node) do
            if type(tier) == "number" and tier > 0 then
              checkedTiers = checkedTiers + 1
              luaunit.assertEquals(type(types), "table", string.format("%s[%d] is not a list of types", where, tier))
              luaunit.assertTrue(#types > 0, string.format("%s[%d] is empty: it would spawn nothing", where, tier))
            end
          end
        end
      end
    end
  end
  -- Both shapes must actually have been visited, or this test passes by never looking. Which is what it
  -- used to do for the flat one.
  luaunit.assertTrue(checkedTiers > 20, "only " .. checkedTiers .. " tiers visited")
  luaunit.assertTrue(checkedFlat >= 6, "only " .. checkedFlat .. " flat lists visited; INFANTRY_TYPES has 6")
end

-- The guard in `veafUnits.findDcsUnit` exists because DCS ships two units whose display name has a
-- trailing space. If a regeneration ever cleaned them up, that guard would become dead code rather than
-- wrong — better to be told than to keep carrying it for no reason.
function TestVeafCasMissionTypesExist:test_the_database_still_has_the_padded_names_the_lookup_guards()
  local padded = {}
  for _, u in pairs(dcsUnits.DcsUnitsDatabase) do
    if type(u) == "table" and type(u.name) == "string" and u.name ~= veaf.trim(u.name) then
      table.insert(padded, u.type)
    end
  end
  luaunit.assertTrue(#padded > 0, "no padded name left in the database; the trim in findDcsUnit can go")
end

-- ============================================================================
-- FIX-UNGUARDED-DCS-LOOKUPS — the CAS mission that crashed on its own spawn
--
-- `generateCasMission` submitted the target group and then wrote
--
--     local controller = Group.getByName(veafCasMission.casGroupName):getController()
--
-- with the return of `veaf.addGroup` right above it **discarded** — yet that function answers `false`
-- on an unknown country or an empty unit list, which is precisely when the lookup below it comes back
-- empty. Two ways to reach the same nil, neither checked.
--
-- The mocks reproduce it exactly as DCS does: `coalition.addGroup` does not put anything into the
-- registry `Group.getByName` reads, so a group that was just submitted is not found — the same
-- situation that forced #872's tests to register their clone by hand.
-- ============================================================================
TestVeafCasMissionUnfoundGroup = {}

function TestVeafCasMissionUnfoundGroup:setUp()
  dcs_mocks.reset()
  veafCasMission.groupAliveCheckTaskID = "none"
  self._logger = veaf.loggers.get(veafCasMission.Id)
  self._originalWarn = self._logger.warn
  self.warned = {}
  local warned = self.warned
  self._logger.warn = function(_, text, ...)
    table.insert(warned, tostring(text))
  end
  -- Everything past the lookup belongs to other modules, absent from this suite's minimal load. If the
  -- guard ever stops stopping, these stubs are what turns that into a plain failure rather than a
  -- confusing "attempt to index a nil value" three modules away.
  self._reached = false
  local test = self
  veafSpawn = veafSpawn or {}
  self._savedSpawnAfac = veafSpawn.spawnAFAC
  veafSpawn.spawnAFAC = function()
    test._reached = true
    return nil
  end
end

function TestVeafCasMissionUnfoundGroup:tearDown()
  self._logger.warn = self._originalWarn
  veafSpawn.spawnAFAC = self._savedSpawnAfac
  veafCasMission.groupAliveCheckTaskID = "none"
  dcs_mocks.reset()
end

--- Run a CAS mission generation over a spot the mocks accept, red side, smallest size.
function TestVeafCasMissionUnfoundGroup:_generate()
  return pcall(veafCasMission.generateCasMission, { x = 0, y = 0, z = 0 }, 1, 1, 1, 100, false, coalition.side.RED)
end

-- The defect itself: without the guard this raises on `:getController()`.
function TestVeafCasMissionUnfoundGroup:test_a_group_dcs_does_not_answer_for_does_not_raise()
  local ok, err = self:_generate()
  luaunit.assertTrue(ok, string.format("generateCasMission raised when DCS did not answer for the group: %s", tostring(err)))
end

-- And it stops there. Everything after that line — the AFAC, the radio menus, the watchdog — is built
-- around a group that does not exist, so carrying on would only move the crash.
function TestVeafCasMissionUnfoundGroup:test_nothing_is_built_around_a_group_that_is_not_there()
  self:_generate()
  luaunit.assertFalse(self._reached, "the mission must stop at the failed lookup, not spawn an AFAC for it")
end

function TestVeafCasMissionUnfoundGroup:test_the_warning_names_the_group()
  self:_generate()
  local named = false
  for _, warning in ipairs(self.warned) do
    if warning:find(veafCasMission.casGroupName, 1, true) then
      named = true
    end
  end
  luaunit.assertTrue(named, "the warning must name the CAS group that could not be created")
end

-- The other half of the same defect: `veaf.addGroup` refusing the group outright. Its return was
-- discarded, so the code walked straight into the lookup that could not possibly succeed.
function TestVeafCasMissionUnfoundGroup:test_a_refused_spawn_stops_the_mission_too()
  local saved = veaf.addGroup
  veaf.addGroup = function()
    return false
  end
  local ok = self:_generate()
  veaf.addGroup = saved
  luaunit.assertTrue(ok, "a refused spawn must not raise")
  luaunit.assertFalse(self._reached, "a refused spawn must not go on to build the rest of the mission")
end

-- ============================================================================
-- FIX-UNGUARDED-DCS-LOOKUPS — the target report and the missing bullseye
--
-- `reportTargetInformation` read the coalition's bullseye out of the mission and handed it to
-- `veaf.makeVec3`, which indexes `vec.z` on its first line. `veaf.getBullseye` answers nil for a side
-- the mission declares no bullseye for, so the report raised there — one line *before* the
-- `---@diagnostic disable-next-line: need-check-nil` that was silencing the linter about it.
--
-- The mocks define no `env.mission`, so the bullseye is absent here exactly as it would be in such a
-- mission. The other three lines of the report — lat/lon, DMS, MGRS — need no bullseye, and the fix is
-- that only the bullseye line is dropped.
-- ============================================================================
TestVeafCasMissionReportWithoutBullseye = {}

local REPORTED_GROUP = "CAS-REPORT-GROUP"

function TestVeafCasMissionReportWithoutBullseye:setUp()
  dcs_mocks.reset()
  self._savedGroupName = veafCasMission.casGroupName
  veafCasMission.casGroupName = REPORTED_GROUP
  veafCasMission.afacName = nil

  dcs_mocks.addUnit(REPORTED_GROUP .. "-1", {
    getPosition = function()
      return { p = { x = 1000, y = 0, z = 2000 } }
    end,
    -- `countInfantryAndVehicles`, the first thing the report does, asks every unit its type.
    getTypeName = function()
      return "BTR-80"
    end,
  })
  dcs_mocks.addGroup(REPORTED_GROUP, {
    getUnits = function()
      return { Unit.getByName(REPORTED_GROUP .. "-1") }
    end,
  })

  -- veafWeatherData belongs to a module this suite does not load; the report appends its string at the
  -- end, well past the line under test.
  self._hadWeather = veafWeatherData ~= nil
  self._savedWeather = veafWeatherData
  veafWeatherData = {
    getWeatherString = function()
      return "WEATHER: test"
    end,
  }

  self.messages = {}
  local messages = self.messages
  self._savedOutForGroup = veaf.outTextForGroup
  veaf.outTextForGroup = function(_, text, _)
    table.insert(messages, tostring(text))
  end
end

function TestVeafCasMissionReportWithoutBullseye:tearDown()
  veaf.outTextForGroup = self._savedOutForGroup
  veafWeatherData = self._savedWeather
  veafCasMission.casGroupName = self._savedGroupName
  dcs_mocks.reset()
end

-- The defect itself: without the guard this raises inside `veaf.makeVec3`.
function TestVeafCasMissionReportWithoutBullseye:test_the_report_does_not_raise()
  local ok, err = pcall(veafCasMission.reportTargetInformation, REPORTED_GROUP .. "-1")
  luaunit.assertTrue(ok, string.format("reportTargetInformation raised with no bullseye declared: %s", tostring(err)))
end

-- The pilot still gets his report: only the bullseye line is gone.
function TestVeafCasMissionReportWithoutBullseye:test_the_pilot_still_gets_the_rest_of_the_report()
  veafCasMission.reportTargetInformation(REPORTED_GROUP .. "-1")
  luaunit.assertEquals(#self.messages, 1, "the report must still be sent")
  luaunit.assertNotNil(self.messages[1]:find("mgrs", 1, true), "the MGRS line must survive the missing bullseye")
  luaunit.assertNil(self.messages[1]:find("bullseye_value", 1, true), "the bullseye line has nothing to say and is dropped")
end

os.exit(luaunit.LuaUnit.run())
