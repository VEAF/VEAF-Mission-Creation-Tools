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
dofile(src .. "/veafSecurity.lua")   -- veafShortcuts references sha1 / veafSecurity constants
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
  local a      = VeafAlias:new()
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
  local a   = VeafAlias:new()
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
  local a   = VeafAlias:new()
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
  luaunit.assertEquals(params[1].low,  1)
  luaunit.assertEquals(params[1].high, 6)
end

function TestVeafShortcuts:test_addRandomParameter_multiple_entries()
  local a = VeafAlias:new()
  a:addRandomParameter("defense", 2, 5)
  a:addRandomParameter("size",    1, 3)
  luaunit.assertEquals(#a:getRandomParameters(), 2)
end

function TestVeafShortcuts:test_addRandomParameter_returns_self()
  local a   = VeafAlias:new()
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

  luaunit.assertEquals(a:getName(),        "-myalias")
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
  local a   = VeafAlias:new():setName("-ret")
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
  luaunit.assertEquals(alias,     "-sa6")
  luaunit.assertEquals(remainder, " size 3")
end

function TestVeafShortcuts:test_markTextAnalysis_alias_only()
  local alias = veafShortcuts.markTextAnalysis("-samLR")
  luaunit.assertEquals(alias, "-samLR")
end

function TestVeafShortcuts:test_markTextAnalysis_alias_with_coords_and_delay()
  local alias, coords, delay, remainder = veafShortcuts.markTextAnalysis("-sa6#N45E033!30 extra")
  luaunit.assertEquals(alias,     "-sa6")
  luaunit.assertEquals(coords,    "N45E033")
  luaunit.assertEquals(delay,     "30")
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
  luaunit.assertEquals(alias,     "-sa6")
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

os.exit(luaunit.LuaUnit.run())
