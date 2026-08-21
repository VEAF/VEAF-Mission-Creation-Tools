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

-- ============================================================================
-- FIX-REMOTE-SLOT-NIL-UNIT — a player who leaves his slot was registered in a unit called "nil"
--
-- Two halves, each written correctly, and neither doing what its comment says. The server hook sent
-- `tostring(unitName or "nil")` — the four-character **string** — and this side guarded with
-- `if not unitName`, which never fires for a truthy string. So a spectator or a game master was
-- registered as occupying a unit named `nil`:
--
--     veafRemote.remoteUnitsPilots["nil"] = remoteUser
--
-- Costs: `veafSecurity.getUnitNameForPlayer` returned the string "nil" for him, the elevation refusal
-- then logged "cannot resolve a group for unit [nil]" — a correct refusal with a fictional reason —
-- and two players in the same state disagreed, since one table slot held one of them.
--
-- The hook sends "" now, but the mission must accept the old payload too: the hook is deployed by hand,
-- server by server, so a new mission meeting an old hook is the normal state of affairs here.
-- ============================================================================
TestVeafRemoteSlotWithNoUnit = {}

function TestVeafRemoteSlotWithNoUnit:setUp()
  veafRemote.remoteUsers = {}
  veafRemote.remoteUnitsPilots = {}
  veafRemote.registerUser("Zip", 10, "ucid-zip")
  veafRemote.registerUser("Sharko", 10, "ucid-sharko")
end

--- Every shape that means "this player occupies no unit", including the two an old hook can send.
--- A real `nil` cannot live in a table, so it is asserted separately everywhere below.
local NO_UNIT = { empty = "", blank = "   ", legacy_literal = "nil", legacy_upper = "NIL" }

function TestVeafRemoteSlotWithNoUnit:test_normalizeUnitName_reads_a_real_name()
  luaunit.assertEquals(veafRemote.normalizeUnitName("Bandit-1-1"), "Bandit-1-1")
end

function TestVeafRemoteSlotWithNoUnit:test_normalizeUnitName_reads_every_absence_as_absence()
  for label, value in pairs(NO_UNIT) do
    luaunit.assertNil(veafRemote.normalizeUnitName(value), label)
  end
  luaunit.assertNil(veafRemote.normalizeUnitName(nil))
end

function TestVeafRemoteSlotWithNoUnit:test_a_player_taking_a_slot_is_registered()
  veafRemote.registerUserSlot("Zip", "ucid-zip", "Bandit-1-1")
  luaunit.assertEquals(veafRemote.remoteUnitsPilots["Bandit-1-1"].name, "Zip")
end

-- The defect itself, over every shape of "no unit".
function TestVeafRemoteSlotWithNoUnit:test_leaving_a_slot_leaves_no_entry_behind()
  for label, value in pairs(NO_UNIT) do
    veafRemote.remoteUnitsPilots = {}
    veafRemote.registerUserSlot("Zip", "ucid-zip", "Bandit-1-1")
    veafRemote.registerUserSlot("Zip", "ucid-zip", value)
    luaunit.assertEquals(veafRemote.remoteUnitsPilots, {}, label)
  end
end

function TestVeafRemoteSlotWithNoUnit:test_leaving_a_slot_with_a_real_nil_leaves_no_entry_behind()
  veafRemote.registerUserSlot("Zip", "ucid-zip", "Bandit-1-1")
  veafRemote.registerUserSlot("Zip", "ucid-zip", nil)
  luaunit.assertEquals(veafRemote.remoteUnitsPilots, {})
end

function TestVeafRemoteSlotWithNoUnit:test_no_unit_is_ever_registered_under_the_string_nil()
  -- the assertion that would have caught this on day one
  veafRemote.registerUserSlot("Zip", "ucid-zip", "nil")
  luaunit.assertNil(veafRemote.remoteUnitsPilots["nil"])
end

function TestVeafRemoteSlotWithNoUnit:test_the_user_no_longer_claims_a_unit()
  veafRemote.registerUserSlot("Zip", "ucid-zip", "Bandit-1-1")
  veafRemote.registerUserSlot("Zip", "ucid-zip", "nil")
  luaunit.assertNil(veafRemote.getRemoteUser("Zip").unitName)
end

-- "Two players in the same state disagree": with one table slot holding whoever moved last, the first
-- of them stopped being findable. Both must be equally absent.
function TestVeafRemoteSlotWithNoUnit:test_two_players_leaving_in_sequence_behave_identically()
  veafRemote.registerUserSlot("Zip", "ucid-zip", "Bandit-1-1")
  veafRemote.registerUserSlot("Sharko", "ucid-sharko", "Bandit-1-2")
  veafRemote.registerUserSlot("Zip", "ucid-zip", "nil")
  veafRemote.registerUserSlot("Sharko", "ucid-sharko", "nil")
  luaunit.assertEquals(veafRemote.remoteUnitsPilots, {})
  luaunit.assertNil(veafRemote.getRemoteUser("Zip").unitName)
  luaunit.assertNil(veafRemote.getRemoteUser("Sharko").unitName)
end

function TestVeafRemoteSlotWithNoUnit:test_changing_slot_releases_the_previous_unit()
  -- non-regression: the mechanism that already worked
  veafRemote.registerUserSlot("Zip", "ucid-zip", "Bandit-1-1")
  veafRemote.registerUserSlot("Zip", "ucid-zip", "Bandit-2-1")
  luaunit.assertNil(veafRemote.remoteUnitsPilots["Bandit-1-1"])
  luaunit.assertEquals(veafRemote.remoteUnitsPilots["Bandit-2-1"].name, "Zip")
end

function TestVeafRemoteSlotWithNoUnit:test_a_player_returning_to_a_slot_is_registered_again()
  veafRemote.registerUserSlot("Zip", "ucid-zip", "Bandit-1-1")
  veafRemote.registerUserSlot("Zip", "ucid-zip", "")
  veafRemote.registerUserSlot("Zip", "ucid-zip", "Bandit-1-1")
  luaunit.assertEquals(veafRemote.remoteUnitsPilots["Bandit-1-1"].name, "Zip")
end

function TestVeafRemoteSlotWithNoUnit:test_no_username_is_still_refused()
  luaunit.assertFalse(veafRemote.registerUserSlot(nil, "ucid", "Bandit-1-1"))
end

-- A unit genuinely named `nil` is indistinguishable from absence, and that is the price of accepting
-- the old payload. Pinned so the trade is visible rather than discovered.
function TestVeafRemoteSlotWithNoUnit:test_a_unit_actually_named_nil_is_read_as_absence()
  veafRemote.registerUserSlot("Zip", "ucid-zip", "nil")
  luaunit.assertEquals(veafRemote.remoteUnitsPilots, {})
end

os.exit(luaunit.LuaUnit.run())
