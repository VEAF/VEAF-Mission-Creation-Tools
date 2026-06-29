--- Tests for veafRemote.lua — mark text analysis and user/slot registration.
local _base = debug.getinfo(1, "S").source:match("^@(.+)[\\/]") or "."
luaunit = dofile(_base .. "/luaunit.lua")
dofile(_base .. "/dcs_mocks.lua")
local src = _base .. "/../../src/scripts/veaf"
dofile(src .. "/veaf.lua")
dofile(src .. "/veafRemote.lua")

-- Stub veafSecurity (required by executeRemoteCommand password check)
veafSecurity = {
  checkPassword_L1 = function() return true end,
  checkSecurity_L9 = function() return true end,
}

-- ---------------------------------------------------------------------------
-- TestVeafRemoteConstants
-- ---------------------------------------------------------------------------
TestVeafRemoteConstants = {}

function TestVeafRemoteConstants:test_commandStarter()
  luaunit.assertEquals(veafRemote.CommandStarter, "_remote")
end

function TestVeafRemoteConstants:test_minLevelForMarker()
  luaunit.assertEquals(veafRemote.MIN_LEVEL_FOR_MARKER, 10)
end

function TestVeafRemoteConstants:test_id()
  luaunit.assertIsString(veafRemote.Id)
end

function TestVeafRemoteConstants:test_remoteUsers_table_exists()
  luaunit.assertIsTable(veafRemote.remoteUsers)
end

-- ---------------------------------------------------------------------------
-- TestVeafRemoteMarkTextAnalysis
-- ---------------------------------------------------------------------------
TestVeafRemoteMarkTextAnalysis = {}

function TestVeafRemoteMarkTextAnalysis:test_simple_command()
  local cmd, pwd = veafRemote.markTextAnalysis("_remote some command")
  luaunit.assertEquals(cmd, "some command")
  luaunit.assertEquals(pwd, "")
end

function TestVeafRemoteMarkTextAnalysis:test_command_with_password()
  local cmd, pwd = veafRemote.markTextAnalysis("_remote#myPass doThing arg")
  luaunit.assertEquals(cmd, "doThing arg")
  luaunit.assertEquals(pwd, "myPass")
end

function TestVeafRemoteMarkTextAnalysis:test_command_with_numeric_password()
  local cmd, pwd = veafRemote.markTextAnalysis("_remote#1234 status")
  luaunit.assertEquals(cmd, "status")
  luaunit.assertEquals(pwd, "1234")
end

function TestVeafRemoteMarkTextAnalysis:test_no_match_returns_nil()
  local cmd = veafRemote.markTextAnalysis("hello world")
  luaunit.assertNil(cmd)
end

function TestVeafRemoteMarkTextAnalysis:test_empty_string_returns_nil()
  local cmd = veafRemote.markTextAnalysis("")
  luaunit.assertNil(cmd)
end

function TestVeafRemoteMarkTextAnalysis:test_wrong_starter_returns_nil()
  local cmd = veafRemote.markTextAnalysis("_radio transmit hello")
  luaunit.assertNil(cmd)
end

function TestVeafRemoteMarkTextAnalysis:test_command_multiword()
  local cmd, pwd = veafRemote.markTextAnalysis("_remote activate qra red")
  luaunit.assertEquals(cmd, "activate qra red")
  luaunit.assertEquals(pwd, "")
end

function TestVeafRemoteMarkTextAnalysis:test_password_with_special_chars()
  local cmd, pwd = veafRemote.markTextAnalysis("_remote#p@ss123 exec")
  luaunit.assertEquals(cmd, "exec")
  luaunit.assertEquals(pwd, "p@ss123")
end

-- ---------------------------------------------------------------------------
-- TestVeafRemoteUserRegistration
-- ---------------------------------------------------------------------------
TestVeafRemoteUserRegistration = {}

function TestVeafRemoteUserRegistration:setUp()
  veafRemote.remoteUsers = {}
end

function TestVeafRemoteUserRegistration:test_register_and_get_user()
  veafRemote.registerUser("Alice", 5, "ucid-001")
  local u = veafRemote.getRemoteUser("Alice")
  luaunit.assertNotNil(u)
  luaunit.assertEquals(u.name, "Alice")
end

function TestVeafRemoteUserRegistration:test_lookup_is_case_insensitive()
  veafRemote.registerUser("BOB", 10, "ucid-002")
  local u = veafRemote.getRemoteUser("bob")
  luaunit.assertNotNil(u)
  luaunit.assertEquals(u.name, "BOB")
end

function TestVeafRemoteUserRegistration:test_registered_user_has_level()
  veafRemote.registerUser("Charlie", 7, "ucid-003")
  local u = veafRemote.getRemoteUser("charlie")
  luaunit.assertNotNil(u)
  luaunit.assertEquals(u.level, 7)
end

function TestVeafRemoteUserRegistration:test_registered_user_has_ucid()
  veafRemote.registerUser("Dana", 3, "ucid-004")
  local u = veafRemote.getRemoteUser("dana")
  luaunit.assertNotNil(u)
  luaunit.assertEquals(u.ucid, "ucid-004")
end

function TestVeafRemoteUserRegistration:test_unknown_user_returns_nil()
  local u = veafRemote.getRemoteUser("Nobody")
  luaunit.assertNil(u)
end

function TestVeafRemoteUserRegistration:test_nil_username_safe()
  local u = veafRemote.getRemoteUser(nil)
  luaunit.assertNil(u)
end

function TestVeafRemoteUserRegistration:test_overwrite_user()
  veafRemote.registerUser("Eve", 1, "ucid-005")
  veafRemote.registerUser("Eve", 9, "ucid-005-new")
  local u = veafRemote.getRemoteUser("eve")
  luaunit.assertEquals(u.level, 9)
end

function TestVeafRemoteUserRegistration:test_multiple_users()
  veafRemote.registerUser("P1", 1, "u1")
  veafRemote.registerUser("P2", 2, "u2")
  veafRemote.registerUser("P3", 3, "u3")
  luaunit.assertNotNil(veafRemote.getRemoteUser("p1"))
  luaunit.assertNotNil(veafRemote.getRemoteUser("p2"))
  luaunit.assertNotNil(veafRemote.getRemoteUser("p3"))
end

-- ---------------------------------------------------------------------------
-- TestVeafRemoteUserSlot
-- ---------------------------------------------------------------------------
TestVeafRemoteUserSlot = {}

function TestVeafRemoteUserSlot:setUp()
  veafRemote.remoteUsers = {}
end

function TestVeafRemoteUserSlot:test_register_slot_and_get_user()
  veafRemote.registerUser("Alice", 5, "ucid-001")
  veafRemote.registerUserSlot("Alice", "ucid-001", "UH-1H #001")
  local u = veafRemote.getRemoteUserFromUnit("UH-1H #001")
  luaunit.assertNotNil(u)
  luaunit.assertEquals(u.name, "Alice")
end

function TestVeafRemoteUserSlot:test_unknown_unit_returns_nil()
  local u = veafRemote.getRemoteUserFromUnit("NonExistentUnit")
  luaunit.assertNil(u)
end

function TestVeafRemoteUserSlot:test_nil_unit_returns_nil()
  local u = veafRemote.getRemoteUserFromUnit(nil)
  luaunit.assertNil(u)
end

function TestVeafRemoteUserSlot:test_slot_reassignment()
  veafRemote.registerUser("Pilot1", 5, "u1")
  veafRemote.registerUser("Pilot2", 5, "u2")
  veafRemote.registerUserSlot("Pilot1", "u1", "F-16C #1")
  veafRemote.registerUserSlot("Pilot2", "u2", "F-16C #1")  -- same unit, new pilot
  local u = veafRemote.getRemoteUserFromUnit("F-16C #1")
  luaunit.assertNotNil(u)
  -- Should return the last registered pilot
  luaunit.assertEquals(u.name, "Pilot2")
end

-- ============================================================================
-- TestVeafRemoteBuildDefaultList
-- ============================================================================
TestVeafRemoteBuildDefaultList = {}

function TestVeafRemoteBuildDefaultList:test_buildDefaultList_no_crash()
  -- TEST=false branch → function is essentially a no-op
  veafRemote.buildDefaultList()
  luaunit.assertTrue(true)
end

-- ============================================================================
-- TestVeafRemoteModuleRegistry
-- ============================================================================
TestVeafRemoteModuleRegistry = {}

function TestVeafRemoteModuleRegistry:setUp()
  veafRemote.remoteModuleRegistry = {}
end

function TestVeafRemoteModuleRegistry:test_registerRemoteModule_stores_handler()
  local called = false
  local function handler(unitName, args) called = true; return true end
  veafRemote.registerRemoteModule("testmod", handler)
  luaunit.assertNotNil(veafRemote.remoteModuleRegistry["testmod"])
end

function TestVeafRemoteModuleRegistry:test_executeCommandFromRemote_with_registered_handler()
  local function handler(unitName, args) return true end
  veafRemote.registerRemoteModule("mymod", handler)
  -- executeCommandFromRemote(unitName, coalition, posUnit, module, command, args)
  local result = veafRemote.executeCommandFromRemote("pilot", 2, nil, "mymod", "cmd", {})
  luaunit.assertTrue(result)
end

-- ============================================================================
-- TestVeafRemoteExecuteCommand
-- ============================================================================
TestVeafRemoteExecuteCommand = {}

function TestVeafRemoteExecuteCommand:test_no_remote_prefix_returns_nil()
  -- Text without "_remote" prefix → executeCommand returns nil
  local result = veafRemote.executeCommand(nil, "plain text")
  luaunit.assertNil(result)
end

function TestVeafRemoteExecuteCommand:test_remote_prefix_no_command_returns_nil()
  -- "_remote " with nothing after → returns nil
  local result = veafRemote.executeCommand(nil, "_remote ")
  luaunit.assertNil(result)
end

-- ============================================================================
-- TestVeafRemoteExecuteRemoteCommand
-- ============================================================================
TestVeafRemoteExecuteRemoteCommand = {}

function TestVeafRemoteExecuteRemoteCommand:test_unknown_command_returns_false()
  -- password check passes (stubbed), but command not in registry → returns false
  local result = veafRemote.executeRemoteCommand("unknown-cmd-xyz", "")
  luaunit.assertFalse(result)
end

-- ============================================================================
-- TestVeafRemoteExecuteCommandFromRemote
-- ============================================================================
TestVeafRemoteExecuteCommandFromRemote = {}

function TestVeafRemoteExecuteCommandFromRemote:setUp()
  veafRemote.remoteModules = {}
end

function TestVeafRemoteExecuteCommandFromRemote:test_nil_args_returns_false()
  local result = veafRemote.executeCommandFromRemote(nil, nil, nil, nil, nil, nil)
  luaunit.assertFalse(result)
end

function TestVeafRemoteExecuteCommandFromRemote:test_no_handler_returns_false()
  local result = veafRemote.executeCommandFromRemote("pilot", 2, nil, "nomodule", "cmd", {})
  luaunit.assertFalse(result)
end

os.exit(luaunit.LuaUnit.run())
