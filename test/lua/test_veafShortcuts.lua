--- Unit tests for veafShortcuts.lua / VeafAlias class and alias registry.
---
--- Run:  lua test/lua/test_veafShortcuts.lua
---
--- Covers:
---   - VeafAlias:new() constructor — default field values
---   - All setters / getters (fluent chain: setX returns self)
---   - dontEndWithComma()
---   - addRandomParameter / getRandomParameters
---   - setPassword / hasPassword (single-password dict, replacement)
---   - veafShortcuts.AddAlias / GetAlias registry round-trip
---   - veafShortcuts.markTextAnalysis (pattern extraction)

local _base = debug.getinfo(1, "S").source:match("^@(.+)[\\/]") or "."
luaunit = dofile(_base .. "/luaunit.lua")
dofile(_base .. "/dcs_mocks.lua")
local src = _base .. "/../../src/scripts/veaf"
dofile(src .. "/veaf.lua")
dofile(src .. "/veafSecurity.lua") -- veafShortcuts references sha1 / veafSecurity constants
dofile(src .. "/veafShortcuts.lua")

-- ============================================================================
-- Test suite
-- ============================================================================
TestVeafShortcuts = {}

function TestVeafShortcuts:setUp()
  dcs_mocks.reset()
  -- Reset the alias registry between tests
  veafShortcuts.aliases = {}
end

-- -----------------------------------------------------------------------
-- VeafAlias constructor — default values
-- -----------------------------------------------------------------------
function TestVeafShortcuts:test_default_endsWithComma_is_true()
  local a = VeafAlias:new()
  luaunit.assertTrue(a:isEndsWithComma())
end

function TestVeafShortcuts:test_default_bypassSecurity_is_false()
  local a = VeafAlias:new()
  luaunit.assertFalse(a:isBypassSecurity())
end

function TestVeafShortcuts:test_default_hidden_is_false()
  local a = VeafAlias:new()
  luaunit.assertFalse(a:isHidden())
end

function TestVeafShortcuts:test_default_name_is_nil()
  local a = VeafAlias:new()
  luaunit.assertNil(a:getName())
end

function TestVeafShortcuts:test_default_veafCommand_is_nil()
  local a = VeafAlias:new()
  luaunit.assertNil(a:getVeafCommand())
end

function TestVeafShortcuts:test_default_description_is_nil()
  local a = VeafAlias:new()
  luaunit.assertNil(a:getDescription())
end

function TestVeafShortcuts:test_default_randomParameters_is_empty()
  local a = VeafAlias:new()
  local params = a:getRandomParameters()
  luaunit.assertNotNil(params)
  luaunit.assertEquals(#params, 0)
end

-- -----------------------------------------------------------------------
-- setName / getName
-- -----------------------------------------------------------------------
function TestVeafShortcuts:test_setName_getName_round_trip()
  local a = VeafAlias:new():setName("-sa6")
  luaunit.assertEquals(a:getName(), "-sa6")
end

function TestVeafShortcuts:test_setName_returns_self_for_chaining()
  local a = VeafAlias:new()
  local ret = a:setName("-test")
  luaunit.assertEquals(ret, a)
end

-- -----------------------------------------------------------------------
-- setVeafCommand / getVeafCommand
-- -----------------------------------------------------------------------
function TestVeafShortcuts:test_setVeafCommand_getVeafCommand()
  local a = VeafAlias:new():setVeafCommand("_spawn infantry, size 3")
  luaunit.assertEquals(a:getVeafCommand(), "_spawn infantry, size 3")
end

-- -----------------------------------------------------------------------
-- setEndsWithComma / isEndsWithComma / dontEndWithComma
-- -----------------------------------------------------------------------
function TestVeafShortcuts:test_setEndsWithComma_true()
  local a = VeafAlias:new():setEndsWithComma(true)
  luaunit.assertTrue(a:isEndsWithComma())
end

function TestVeafShortcuts:test_setEndsWithComma_false()
  local a = VeafAlias:new():setEndsWithComma(false)
  luaunit.assertFalse(a:isEndsWithComma())
end

function TestVeafShortcuts:test_dontEndWithComma_clears_flag()
  local a = VeafAlias:new():dontEndWithComma()
  luaunit.assertFalse(a:isEndsWithComma())
end

function TestVeafShortcuts:test_dontEndWithComma_returns_self()
  local a = VeafAlias:new()
  local ret = a:dontEndWithComma()
  luaunit.assertEquals(ret, a)
end

-- -----------------------------------------------------------------------
-- setDescription / getDescription
-- -----------------------------------------------------------------------
function TestVeafShortcuts:test_setDescription_getDescription()
  local a = VeafAlias:new():setDescription("A test alias")
  luaunit.assertEquals(a:getDescription(), "A test alias")
end

-- -----------------------------------------------------------------------
-- setBypassSecurity / isBypassSecurity
-- -----------------------------------------------------------------------
function TestVeafShortcuts:test_setBypassSecurity_true()
  local a = VeafAlias:new():setBypassSecurity(true)
  luaunit.assertTrue(a:isBypassSecurity())
end

function TestVeafShortcuts:test_setBypassSecurity_false()
  local a = VeafAlias:new():setBypassSecurity(false)
  luaunit.assertFalse(a:isBypassSecurity())
end

-- -----------------------------------------------------------------------
-- setHidden / isHidden
-- -----------------------------------------------------------------------
function TestVeafShortcuts:test_setHidden_true()
  local a = VeafAlias:new():setHidden(true)
  luaunit.assertTrue(a:isHidden())
end

function TestVeafShortcuts:test_setHidden_false()
  local a = VeafAlias:new():setHidden(false)
  luaunit.assertFalse(a:isHidden())
end

-- -----------------------------------------------------------------------
-- setPassword / hasPassword
-- -----------------------------------------------------------------------
function TestVeafShortcuts:test_hasPassword_returns_truthy_for_correct_hash()
  local a = VeafAlias:new():setPassword("myhash")
  luaunit.assertNotNil(a:hasPassword("myhash"))
end

function TestVeafShortcuts:test_hasPassword_returns_nil_for_wrong_hash()
  local a = VeafAlias:new():setPassword("myhash")
  luaunit.assertNil(a:hasPassword("wronghash"))
end

function TestVeafShortcuts:test_hasPassword_returns_nil_for_original_after_setPassword_replaces()
  -- setPassword creates a fresh dict — previous hash is gone
  local a = VeafAlias:new():setPassword("old"):setPassword("new")
  luaunit.assertNil(a:hasPassword("old"))
  luaunit.assertNotNil(a:hasPassword("new"))
end

function TestVeafShortcuts:test_hasPassword_nil_hash_arg()
  local a = VeafAlias:new():setPassword("myhash")
  luaunit.assertNil(a:hasPassword(nil))
end

-- -----------------------------------------------------------------------
-- addRandomParameter / getRandomParameters
-- -----------------------------------------------------------------------
function TestVeafShortcuts:test_addRandomParameter_single_entry()
  local a = VeafAlias:new()
  a:addRandomParameter("size", 1, 6)
  local params = a:getRandomParameters()
  luaunit.assertEquals(#params, 1)
  luaunit.assertEquals(params[1].name, "size")
  luaunit.assertEquals(params[1].low, 1)
  luaunit.assertEquals(params[1].high, 6)
end

function TestVeafShortcuts:test_addRandomParameter_multiple_entries()
  local a = VeafAlias:new()
  a:addRandomParameter("defense", 2, 5)
  a:addRandomParameter("size", 1, 3)
  luaunit.assertEquals(#a:getRandomParameters(), 2)
end

function TestVeafShortcuts:test_addRandomParameter_returns_self()
  local a = VeafAlias:new()
  local ret = a:addRandomParameter("size", 1, 6)
  luaunit.assertEquals(ret, a)
end

-- -----------------------------------------------------------------------
-- Fluent chain construction
-- -----------------------------------------------------------------------
function TestVeafShortcuts:test_fluent_chain_all_setters()
  local a = VeafAlias:new()
    :setName("-myalias")
    :setVeafCommand("_spawn test")
    :setDescription("A description")
    :setBypassSecurity(true)
    :setHidden(true)
    :dontEndWithComma()

  luaunit.assertEquals(a:getName(), "-myalias")
  luaunit.assertEquals(a:getVeafCommand(), "_spawn test")
  luaunit.assertEquals(a:getDescription(), "A description")
  luaunit.assertTrue(a:isBypassSecurity())
  luaunit.assertTrue(a:isHidden())
  luaunit.assertFalse(a:isEndsWithComma())
end

-- -----------------------------------------------------------------------
-- veafShortcuts.AddAlias / GetAlias registry
-- -----------------------------------------------------------------------
function TestVeafShortcuts:test_AddAlias_GetAlias_round_trip()
  local a = VeafAlias:new():setName("-myalias"):setVeafCommand("_spawn test")
  veafShortcuts.AddAlias(a)
  local found = veafShortcuts.GetAlias("-myalias")
  luaunit.assertNotNil(found)
  luaunit.assertEquals(found:getVeafCommand(), "_spawn test")
end

function TestVeafShortcuts:test_AddAlias_normalises_to_lowercase_key()
  -- Both AddAlias and GetAlias use name:lower() internally
  local a = VeafAlias:new():setName("-MyAlias"):setVeafCommand("_spawn test")
  veafShortcuts.AddAlias(a)
  local found = veafShortcuts.GetAlias("-myalias")
  luaunit.assertNotNil(found)
end

function TestVeafShortcuts:test_AddAlias_returns_alias()
  local a = VeafAlias:new():setName("-ret")
  local ret = veafShortcuts.AddAlias(a)
  luaunit.assertEquals(ret, a)
end

function TestVeafShortcuts:test_GetAlias_not_found_returns_nil()
  -- Alias was never added; GetAlias will call trigger.action.outText (mocked) and return nil
  local found = veafShortcuts.GetAlias("-nonexistent")
  luaunit.assertNil(found)
end

function TestVeafShortcuts:test_multiple_aliases_registered_independently()
  veafShortcuts.AddAlias(VeafAlias:new():setName("-aa"):setVeafCommand("cmd_a"))
  veafShortcuts.AddAlias(VeafAlias:new():setName("-bb"):setVeafCommand("cmd_b"))
  luaunit.assertEquals(veafShortcuts.GetAlias("-aa"):getVeafCommand(), "cmd_a")
  luaunit.assertEquals(veafShortcuts.GetAlias("-bb"):getVeafCommand(), "cmd_b")
end

-- -----------------------------------------------------------------------
-- veafShortcuts.markTextAnalysis
-- Pattern: (-[^#^!^ ^,]+)#?([^!^,^%s]*)!?(%d*)(.*)
-- -----------------------------------------------------------------------
function TestVeafShortcuts:test_markTextAnalysis_alias_with_remainder()
  local alias, coords, delay, remainder = veafShortcuts.markTextAnalysis("-sa6 size 3")
  luaunit.assertEquals(alias, "-sa6")
  luaunit.assertEquals(remainder, " size 3")
end

function TestVeafShortcuts:test_markTextAnalysis_alias_only()
  local alias = veafShortcuts.markTextAnalysis("-samLR")
  luaunit.assertEquals(alias, "-samLR")
end

function TestVeafShortcuts:test_markTextAnalysis_alias_with_coords_and_delay()
  local alias, coords, delay, remainder = veafShortcuts.markTextAnalysis("-sa6#N45E033!30 extra")
  luaunit.assertEquals(alias, "-sa6")
  luaunit.assertEquals(coords, "N45E033")
  luaunit.assertEquals(delay, "30")
  luaunit.assertEquals(remainder, " extra")
end

function TestVeafShortcuts:test_markTextAnalysis_no_alias_starter_returns_nil()
  luaunit.assertNil(veafShortcuts.markTextAnalysis("_spawn infantry"))
end

function TestVeafShortcuts:test_markTextAnalysis_empty_text_returns_nil()
  luaunit.assertNil(veafShortcuts.markTextAnalysis(""))
end

function TestVeafShortcuts:test_markTextAnalysis_nil_text_returns_nil()
  luaunit.assertNil(veafShortcuts.markTextAnalysis(nil))
end

function TestVeafShortcuts:test_markTextAnalysis_comma_in_remainder()
  -- Comma is excluded from alias name by the pattern
  local alias, _, _, remainder = veafShortcuts.markTextAnalysis("-sa6, defense 3")
  luaunit.assertEquals(alias, "-sa6")
  luaunit.assertEquals(remainder, ", defense 3")
end

-- ============================================================================
-- ---------------------------------------------------------------------------
-- TestVeafAliasBatchAndCombat — setBatchAliases, getBatchAliases,
--                               VeafAliasForCombatMission:new,
--                               VeafAliasForCombatZone:new
-- ---------------------------------------------------------------------------
TestVeafAliasBatchAndCombat = {}

function TestVeafAliasBatchAndCombat:test_setBatchAliases_stores_value()
  local a = VeafAlias:new()
  a:setName("-test-batch"):setBatchAliases("a,b,c")
  luaunit.assertEquals(a:getBatchAliases(), "a,b,c")
end

function TestVeafAliasBatchAndCombat:test_setBatchAliases_sets_hidden()
  local a = VeafAlias:new()
  a:setName("-hbatch"):setBatchAliases("x,y")
  luaunit.assertTrue(a:isHidden())
end

function TestVeafAliasBatchAndCombat:test_setBatchAliases_sets_password_L1()
  local a = VeafAlias:new()
  a:setName("-pbatch"):setBatchAliases("x")
  luaunit.assertTrue(a:hasPassword(veafSecurity.PASSWORD_L1))
end

function TestVeafAliasBatchAndCombat:test_setBatchAliases_returns_self()
  local a = VeafAlias:new()
  a:setName("-selfbatch")
  local ret = a:setBatchAliases("x")
  luaunit.assertEquals(ret, a)
end

function TestVeafAliasBatchAndCombat:test_getBatchAliases_nil_default()
  local a = VeafAlias:new()
  a:setName("-nobatch")
  luaunit.assertNil(a:getBatchAliases())
end

function TestVeafAliasBatchAndCombat:test_VeafAliasForCombatMission_new_creates_instance()
  local a = VeafAliasForCombatMission:new()
  luaunit.assertNotNil(a)
end

function TestVeafAliasBatchAndCombat:test_VeafAliasForCombatMission_new_is_hidden()
  local a = VeafAliasForCombatMission:new()
  luaunit.assertTrue(a:isHidden())
end

function TestVeafAliasBatchAndCombat:test_VeafAliasForCombatMission_new_has_password_L1()
  local a = VeafAliasForCombatMission:new()
  luaunit.assertTrue(a:hasPassword(veafSecurity.PASSWORD_L1))
end

function TestVeafAliasBatchAndCombat:test_VeafAliasForCombatMission_new_can_set_name()
  local a = VeafAliasForCombatMission:new():setName("-airstart")
  luaunit.assertEquals(a:getName(), "-airstart")
end

function TestVeafAliasBatchAndCombat:test_VeafAliasForCombatZone_new_creates_instance()
  local a = VeafAliasForCombatZone:new()
  luaunit.assertNotNil(a)
end

function TestVeafAliasBatchAndCombat:test_VeafAliasForCombatZone_new_has_password_L1()
  local a = VeafAliasForCombatZone:new()
  luaunit.assertTrue(a:hasPassword(veafSecurity.PASSWORD_L1))
end

function TestVeafAliasBatchAndCombat:test_VeafAliasForCombatZone_new_can_set_name()
  local a = VeafAliasForCombatZone:new():setName("-zonestart")
  luaunit.assertEquals(a:getName(), "-zonestart")
end

-- ---------------------------------------------------------------------------
-- TestVeafShortcutsDefaultList — buildDefaultList covers ~600 executable lines
-- ---------------------------------------------------------------------------
TestVeafShortcutsDefaultList = {}

function TestVeafShortcutsDefaultList:test_buildDefaultList_runs_without_error()
  veafShortcuts.buildDefaultList()
  luaunit.assertTrue(true)
end

function TestVeafShortcutsDefaultList:test_buildDefaultList_registers_samLR()
  veafShortcuts.buildDefaultList()
  local a = veafShortcuts.GetAlias("-samLR")
  luaunit.assertNotNil(a)
end

function TestVeafShortcutsDefaultList:test_buildDefaultList_registers_sa6()
  veafShortcuts.buildDefaultList()
  local a = veafShortcuts.GetAlias("-sa6")
  luaunit.assertNotNil(a)
end

function TestVeafShortcutsDefaultList:test_buildDefaultList_registers_airstart_hidden()
  veafShortcuts.buildDefaultList()
  local a = veafShortcuts.GetAlias("-airstart")
  luaunit.assertNotNil(a)
  luaunit.assertTrue(a:isHidden())
end

function TestVeafShortcutsDefaultList:test_buildDefaultList_registers_zonestart()
  veafShortcuts.buildDefaultList()
  local a = veafShortcuts.GetAlias("-zonestart")
  luaunit.assertNotNil(a)
end

function TestVeafShortcutsDefaultList:test_buildDefaultList_populates_many_aliases()
  veafShortcuts.buildDefaultList()
  local count = 0
  for _ in pairs(veafShortcuts.aliases) do
    count = count + 1
  end
  luaunit.assertTrue(count > 30)
end

-- ---------------------------------------------------------------------------
-- TestVeafShortcutsExecute — executeCommand, ExecuteBatchAliasesList
-- ---------------------------------------------------------------------------
TestVeafShortcutsExecute = {}

function TestVeafShortcutsExecute:test_executeCommand_nil_text_returns_false()
  luaunit.assertFalse(veafShortcuts.executeCommand(nil, nil, nil, false))
end

function TestVeafShortcutsExecute:test_executeCommand_non_alias_text_returns_false()
  luaunit.assertFalse(veafShortcuts.executeCommand(nil, "hello world", nil, false))
end

function TestVeafShortcutsExecute:test_executeCommand_unknown_alias_returns_false()
  -- "-nonexistent" starts with '-' so markTextAnalysis returns it, but GetAlias returns nil
  luaunit.assertFalse(veafShortcuts.executeCommand(nil, "-nonexistent", nil, false))
end

function TestVeafShortcutsExecute:test_ExecuteBatchAliasesList_nil_returns_false()
  luaunit.assertFalse(veafShortcuts.ExecuteBatchAliasesList(nil))
end

function TestVeafShortcutsExecute:test_ExecuteBatchAliasesList_empty_returns_false()
  luaunit.assertFalse(veafShortcuts.ExecuteBatchAliasesList({}))
end

function TestVeafShortcutsExecute:test_ExecuteBatchAliasesList_non_alias_text_returns_true()
  -- table of non-alias texts: each fails silently, function still returns true
  luaunit.assertTrue(veafShortcuts.ExecuteBatchAliasesList({ "hello", "world" }))
end

function TestVeafShortcutsExecute:test_ExecuteBatchAliasesList_silent_true()
  luaunit.assertTrue(veafShortcuts.ExecuteBatchAliasesList({ "hello" }, nil, nil, true))
end

-- ---------------------------------------------------------------------------
-- TestShortcutsInlineParserCharacterisation
--
-- REFACTOR-MARKER-PARSER ticket 01, GROUP B. Three of the four loops the first inventory
-- missed live here, and unlike every group-A parser they are NOT standalone functions: the
-- loop is a step in the middle of `execute`, which then runs the mission or zone. So they are
-- characterised by what they hand downstream — the only observable the parsing produces —
-- through spies on veafCombatMission / veafCombatZone.
--
-- Two of the three (`VeafAliasForCombatMission:execute` at :288 and
-- `VeafAliasForCombatZone:execute` at :394) are the SAME loop twice, differing only in the
-- name of one local. Ticket 03 collapses them into one call.
-- ---------------------------------------------------------------------------
TestShortcutsInlineParserCharacterisation = {}

function TestShortcutsInlineParserCharacterisation:setUp()
  self.calls = {}
  local record = function(what)
    return function(name, silent)
      table.insert(self.calls, { what = what, name = name, silent = silent })
      return true
    end
  end
  veafCombatMission = {
    GetMission = function(name)
      return { name = name }
    end,
    ActivateMission = record("activateMission"),
    DesactivateMission = record("desactivateMission"),
  }
  veafCombatZone = {
    GetZone = function(name)
      return { name = name }
    end,
    ActivateZone = record("activateZone"),
    DesactivateZone = record("desactivateZone"),
  }
  self.position = { x = 0, y = 0, z = 0 }
end

function TestShortcutsInlineParserCharacterisation:tearDown()
  veafCombatMission = nil
  veafCombatZone = nil
end

local function combatMissionAlias()
  return VeafAliasForCombatMission:new():setName("-testcm"):setVeafCommand("start"):setBypassSecurity(true)
end

local function combatZoneAlias()
  return VeafAliasForCombatZone:new():setName("-testcz"):setVeafCommand("start"):setBypassSecurity(true)
end

-- The loop's `name` reaches the mission layer as the mission to activate.
function TestShortcutsInlineParserCharacterisation:test_combat_mission_name_reaches_the_mission_layer()
  combatMissionAlias():execute(", name Alpha", self.position, coalition.side.BLUE, nil, true, nil)
  luaunit.assertEquals(#self.calls, 1)
  luaunit.assertEquals(self.calls[1].what, "activateMission")
  luaunit.assertEquals(self.calls[1].name, "Alpha")
end

-- `silent` is a flag, and it travels as the second argument.
function TestShortcutsInlineParserCharacterisation:test_combat_mission_silent_flag_travels_downstream()
  combatMissionAlias():execute(", name Alpha, silent", self.position, coalition.side.BLUE, nil, true, nil)
  luaunit.assertEquals(self.calls[1].silent, true)
end

function TestShortcutsInlineParserCharacterisation:test_combat_mission_without_silent_passes_false()
  combatMissionAlias():execute(", name Alpha", self.position, coalition.side.BLUE, nil, true, nil)
  luaunit.assertEquals(self.calls[1].silent, false)
end

-- A missing `name` refuses the command before anything runs — the mandatory-field check that
-- group A performs after its loop, done here after the loop too.
function TestShortcutsInlineParserCharacterisation:test_combat_mission_without_name_runs_nothing()
  local result = combatMissionAlias():execute("", self.position, coalition.side.BLUE, nil, true, nil)
  luaunit.assertFalse(result)
  luaunit.assertEquals(#self.calls, 0)
end

-- A valueless `name` is "" here (`str[2] or ""`), and unlike veafGroundAI the guard DOES catch
-- it, because it tests `#zoneName == 0` as well as nil. Same bug shape, opposite outcome.
function TestShortcutsInlineParserCharacterisation:test_combat_mission_valueless_name_is_refused()
  local result = combatMissionAlias():execute(", name", self.position, coalition.side.BLUE, nil, true, nil)
  luaunit.assertFalse(result)
  luaunit.assertEquals(#self.calls, 0)
end

function TestShortcutsInlineParserCharacterisation:test_combat_mission_unknown_keyword_is_ignored()
  combatMissionAlias():execute(", name Alpha, banana 3", self.position, coalition.side.BLUE, nil, true, nil)
  luaunit.assertEquals(#self.calls, 1)
  luaunit.assertEquals(self.calls[1].name, "Alpha")
end

-- The zone loop is the same code with `zoneName` in place of `missionName`.
function TestShortcutsInlineParserCharacterisation:test_combat_zone_name_reaches_the_zone_layer()
  combatZoneAlias():execute(", name Bravo", self.position, coalition.side.BLUE, nil, true, nil)
  luaunit.assertEquals(#self.calls, 1)
  luaunit.assertEquals(self.calls[1].what, "activateZone")
  luaunit.assertEquals(self.calls[1].name, "Bravo")
end

function TestShortcutsInlineParserCharacterisation:test_combat_zone_silent_flag_travels_downstream()
  combatZoneAlias():execute(", name Bravo, silent", self.position, coalition.side.BLUE, nil, true, nil)
  luaunit.assertEquals(self.calls[1].silent, true)
end

function TestShortcutsInlineParserCharacterisation:test_combat_zone_without_name_runs_nothing()
  luaunit.assertFalse(combatZoneAlias():execute("", self.position, coalition.side.BLUE, nil, true, nil))
  luaunit.assertEquals(#self.calls, 0)
end

-- The `password` the loop extracts is what the security check consumes. With bypassSecurity
-- false and a password set on the alias, a wrong one refuses and the right one proceeds —
-- which is the only way to observe that the loop read it at all.
--
-- Note `setPassword` stores the **hash**, not the clear text: `execute` hashes what the pilot
-- typed and looks that up, so a test passing clear text here would silently never match.
function TestShortcutsInlineParserCharacterisation:test_the_parsed_password_is_the_one_checked()
  local alias = VeafAliasForCombatMission:new():setName("-testcm"):setVeafCommand("start"):setBypassSecurity(false)
  alias:setPassword(sha1.hex("s3cret"))

  luaunit.assertFalse(alias:execute(", name Alpha, password wrong", self.position, coalition.side.BLUE, nil, false, nil))
  luaunit.assertEquals(#self.calls, 0)

  alias:execute(", name Alpha, password s3cret", self.position, coalition.side.BLUE, nil, false, nil)
  luaunit.assertEquals(#self.calls, 1)
  luaunit.assertEquals(self.calls[1].name, "Alpha")
end

-- ============================================================================
-- FEAT-SPAWN-OPTION-VALIDATION deliberately leaves the alias spec OUT
--
-- Measured 2026-08-21 over 228 valid marker texts harvested from the suites: with the flag on, this spec
-- flags **52** distinct keys on correct commands, where the six specs that were switched on flag none.
--
-- The cause is by design. An alias carries the parameters of the command it expands into — `size`,
-- `defense`, `freq`, `speed`, … — and declares only the three it consumes itself. Reporting here would
-- warn a pilot about options that are perfectly valid for the aliased command.
-- ============================================================================
TestVeafShortcutsAliasSpecReportsNothing = {}

function TestVeafShortcutsAliasSpecReportsNothing:test_the_alias_spec_does_not_report_unknown_keys()
  luaunit.assertNotEquals(veafShortcuts.AliasParameterSpec.reportUnknownKeys, true)
end

function TestVeafShortcutsAliasSpecReportsNothing:test_a_target_command_parameter_is_not_flagged()
  -- `size` belongs to the aliased command, not to the alias syntax; it must pass through in silence
  local options = veaf.parseMarkerText("-sa6, size 3, defense 4", veafShortcuts.AliasParameterSpec)
  luaunit.assertNil(options.unknownParameters)
end

function TestVeafShortcutsAliasSpecReportsNothing:test_the_three_alias_keys_still_apply()
  local options = veaf.parseMarkerText("-sa6, name mySam, silent", veafShortcuts.AliasParameterSpec)
  luaunit.assertEquals(options.name, "mySam")
  luaunit.assertTrue(options.silent)
end

-- ===========================================================================
-- FIX-SPAWN-BYPASSSECURITY-AS-SILENT — an alias's bypass flag must not silence a pilot
--
-- This is the test the lot needed most, and the one its own dispatcher tests could not be: reverting the
-- fix in `VeafAlias:execute` left every other test in the repository green. The defect lives in the gap
-- between two variables one letter apart, so the assertion has to look at both arguments at once.
--
-- `-tacan` is the real case. It sets `setBypassSecurity(true)` so a pilot needs no password, and until
-- this lot that same flag reached `spawnUnit`'s `silent` parameter — so dropping a `-tacan` marker
-- produced no confirmation, no channel and no band.
-- ===========================================================================
TestAliasBypassDoesNotSilence = {}

function TestAliasBypassDoesNotSilence:setUp()
  veafShortcuts.buildDefaultList()
  self.call = nil
  -- veafSpawn is not loaded by this suite, which is what makes the stub honest: what is under test is the
  -- arguments veafShortcuts *hands over*, not what veafSpawn does with them.
  local test = self
  veafSpawn = {
    executeCommand = function(position, command, coalition, markId, bypassSecurity, groups, rc, rd, route, asd, req, scripted)
      test.call = { command = command, bypassSecurity = bypassSecurity, scripted = scripted }
      return true
    end,
  }
end

function TestAliasBypassDoesNotSilence:tearDown()
  veafSpawn = nil
end

--- Drive the alias exactly as a marker does: veafCommands hands the marker path `bypassSecurity = false`.
function TestAliasBypassDoesNotSilence:_dropMarker(text)
  veafShortcuts.executeCommand({ x = 0, y = 0, z = 0 }, text, 1, 0, false)
  return self.call
end

function TestAliasBypassDoesNotSilence:test_the_alias_expands_and_reaches_the_spawn()
  -- Guards the two tests below: if the plumbing ever stops reaching veafSpawn, they would both pass on a
  -- nil call rather than on the right behaviour.
  local call = self:_dropMarker("-tacan")
  luaunit.assertNotNil(call, "-tacan must reach veafSpawn.executeCommand")
  luaunit.assertNotNil(call.command:find("tacan", 1, true), "expanded to: " .. tostring(call.command))
end

function TestAliasBypassDoesNotSilence:test_the_alias_still_bypasses_the_password_check()
  -- The half that must NOT change: `-tacan` is deliberately usable without a password.
  luaunit.assertEquals(self:_dropMarker("-tacan").bypassSecurity, true)
end

function TestAliasBypassDoesNotSilence:test_but_it_does_not_silence_the_spawn()
  -- The defect, in one assertion. `false` because a person dropped this marker; the alias's own bypass
  -- flag is about passwords and has no opinion on whether the pilot deserves an answer.
  luaunit.assertEquals(self:_dropMarker("-tacan").scripted, false)
end

function TestAliasBypassDoesNotSilence:test_an_alias_that_needs_a_password_is_also_not_silenced()
  -- The other diagonal: silence must not be derivable from the bypass flag in either direction. `-sa2`
  -- does not set it, so both values differ from the `-tacan` case above.
  local call = self:_dropMarker("-sa2")
  luaunit.assertNotNil(call, "-sa2 must reach veafSpawn.executeCommand")
  luaunit.assertEquals(call.bypassSecurity, false)
  luaunit.assertEquals(call.scripted, false)
end

function TestAliasBypassDoesNotSilence:test_a_scripted_alias_is_silenced()
  -- What a combat zone does: veafCommands passes true on the interpreter path, and that must survive the
  -- alias layer untouched, or every zone would start announcing each group it spawns.
  veafShortcuts.executeCommand({ x = 0, y = 0, z = 0 }, "-tacan", 1, 0, true)
  luaunit.assertEquals(self.call.scripted, true)
end

os.exit(luaunit.LuaUnit.run())
