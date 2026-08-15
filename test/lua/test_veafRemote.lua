--- Tests for veafRemote.lua — mark text analysis and user/slot registration.
local _base = debug.getinfo(1, "S").source:match("^@(.+)[\\/]") or "."
luaunit = dofile(_base .. "/luaunit.lua")
dofile(_base .. "/dcs_mocks.lua")
local src = _base .. "/../../src/scripts/veaf"
dofile(src .. "/veaf.lua")
dofile(src .. "/veafRemote.lua")

-- Stub veafSecurity (required by executeRemoteCommand password check)
veafSecurity = {
  checkPassword_L1 = function()
    return true
  end,
  checkSecurity_L9 = function()
    return true
  end,
}

-- ---------------------------------------------------------------------------
-- TestVeafRemoteConstants
-- ---------------------------------------------------------------------------
TestVeafRemoteConstants = {}

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
  veafRemote.registerUserSlot("Pilot2", "u2", "F-16C #1") -- same unit, new pilot
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
  local function handler(unitName, args)
    called = true
    return true
  end
  veafRemote.registerRemoteModule("testmod", handler)
  luaunit.assertNotNil(veafRemote.remoteModuleRegistry["testmod"])
end

function TestVeafRemoteModuleRegistry:test_executeCommandFromRemote_with_registered_handler()
  local function handler(unitName, args)
    return true
  end
  veafRemote.registerRemoteModule("mymod", handler)
  -- executeCommandFromRemote(unitName, coalition, posUnit, module, command, args)
  local result = veafRemote.executeCommandFromRemote("pilot", 2, nil, "mymod", "cmd", {})
  luaunit.assertTrue(result)
end

-- ============================================================================
-- The `_remote` marker command and executeRemoteCommand were removed (VMR-130):
-- they read a `monitoredCommands` table nothing had filled since the SLMOD bridge
-- was deleted in 2021. Their tests go with them; the two below assert they are gone.
-- ============================================================================
TestVeafRemoteDeadPathIsGone = {}

function TestVeafRemoteDeadPathIsGone:test_executeRemoteCommand_no_longer_exists()
  luaunit.assertNil(veafRemote.executeRemoteCommand)
end

function TestVeafRemoteDeadPathIsGone:test_monitoredCommands_no_longer_exists()
  luaunit.assertNil(veafRemote.monitoredCommands)
end

function TestVeafRemoteDeadPathIsGone:test_the_marker_entry_point_no_longer_exists()
  -- veafShortcuts no longer routes markers here either.
  luaunit.assertNil(veafRemote.executeCommand)
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
