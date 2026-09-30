--- Tests for veafRemote.lua — mark text analysis and user/slot registration.
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
dofile(src .. "/veafI18n.lua")
dofile(src .. "/veafRemote.lua")

veaf.config.language = "en"

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
-- FIX-REMOTE-SLOT-NIL-UNIT — a player in no unit must leave no trace, whatever the hook sent
--
-- Every shape of "no unit" is swept rather than sampled, because an old hook and a new one send
-- different ones and both reach this code: the hook is deployed by hand, server by server. Why the
-- literal "nil" has to be accepted, and what that costs, is on `veafRemote.normalizeUnitName`.
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

-- Sourcery's review point: anything that is not a string used to be read as "no unit" in silence, which
-- is the same shape of defect as the one this lot fixes. It is reported now, and still answered safely.
function TestVeafRemoteSlotWithNoUnit:test_an_unexpected_type_is_reported_and_read_as_absence()
  local logger = veaf.loggers.get(veafRemote.Id)
  local saved = logger.warn
  local warned = {}
  logger.warn = function(_, text, ...)
    table.insert(warned, text)
  end
  for _, bad in ipairs({ 42, true, {}, print }) do
    luaunit.assertNil(veafRemote.normalizeUnitName(bad))
  end
  logger.warn = saved
  luaunit.assertEquals(#warned, 4)
end

function TestVeafRemoteSlotWithNoUnit:test_nil_and_the_empty_string_are_not_reported()
  -- they are the ordinary "no unit" payloads, not mistakes: warning on them would make every slot
  -- change of every spectator noisy
  local logger = veaf.loggers.get(veafRemote.Id)
  local saved = logger.warn
  local warned = {}
  logger.warn = function(_, text, ...)
    table.insert(warned, text)
  end
  veafRemote.normalizeUnitName(nil)
  veafRemote.normalizeUnitName("")
  veafRemote.normalizeUnitName("nil")
  logger.warn = saved
  luaunit.assertEquals(#warned, 0)
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

-- ---------------------------------------------------------------------------
-- FIX-REMOTE-DEAD-MARKER-HANDLER — the module answers no marker text any more
--
-- `veafRemote.executeCommand` was deleted on 2026-08-11 with the shared-password marker mechanism
-- (9a20c50c, the security review), but two references survived it. The one in `initialize` registered
-- a marker command handler, and `veafMarkers.onEvent` calls every registered handler under `pcall`,
-- so from that day **any** marker carrying text answered "VEAF: your marker command failed" —
-- eleven days, reported in game on 2026-08-22 by a pilot dropping a plain annotation.
--
-- These pin the absence rather than the presence, which is unusual and deliberate: the supported
-- path is `registerRemoteModule` / `executeCommandFromRemote`, authenticating a named user instead
-- of trusting a string typed on the map. Re-adding either symbol would be a security regression, not
-- a feature. The repo-wide sweep that catches this class lives in
-- `test/python/test_lua_module_calls_resolve.py`.
-- ---------------------------------------------------------------------------
TestVeafRemoteNoMarkerCommands = {}

function TestVeafRemoteNoMarkerCommands:test_executeCommand_is_gone_and_must_stay_gone()
  luaunit.assertNil(veafRemote.executeCommand, "removed with the shared-password mechanism")
end

function TestVeafRemoteNoMarkerCommands:test_addNiodCommand_is_gone_too()
  -- It had no caller, so it never raised; it was the other half of the same unfinished removal.
  luaunit.assertNil(veafRemote.addNiodCommand, "it only existed to call executeCommand")
end

-- NIOD support was removed: the NIOD script left the repository on 2025-09-25, nothing defined the
-- `niod` global since, and the only callbacks were declared under `local TEST = false`.
function TestVeafRemoteNoMarkerCommands:test_niod_support_is_gone()
  luaunit.assertNil(veafRemote.addNiodCallback, "NIOD itself is no longer shipped")
  luaunit.assertNil(veafRemote.buildDefaultList, "its whole body was a dead `if TEST` block")
end

function TestVeafRemoteNoMarkerCommands:test_initialize_registers_no_command_handler()
  local registered = 0
  local originalRegister = veafCommands and veafCommands.registerCommandHandler
  if not veafCommands then
    veafCommands = {}
  end
  veafCommands.registerCommandHandler = function()
    registered = registered + 1
  end
  veafRemote.initialize()

  veafCommands.registerCommandHandler = originalRegister
  luaunit.assertEquals(registered, 0, "a handler here means marker text is being answered again")
end

-- ---------------------------------------------------------------------------
-- FIX-SECU-VERB-AND-LOG-NOISE ticket 01 — a listed pilot's level must reach the unit he sits in
--
-- private1, 2026-09-29: a pilot at level 99 in `veaf-pilots.txt` was refused a level-10 radio command.
-- `registerUserSlot` met a player the mission did not know yet (no `onPlayerConnect` reaches a mission
-- loaded while he stays connected) and registered his unit with a user carrying no level at all. A chat
-- command then re-registered him with his level, but as a **new** table, so the unit kept pointing at the
-- level-less one: nothing ever repaired it.
-- ---------------------------------------------------------------------------
TestVeafRemoteSlotCarriesTheLevel = {}

function TestVeafRemoteSlotCarriesTheLevel:setUp()
  veafRemote.remoteUsers = {}
  veafRemote.remoteUnitsPilots = {}
end

function TestVeafRemoteSlotCarriesTheLevel:test_the_level_sent_with_the_slot_reaches_the_unit()
  -- the mission reloaded under a connected pilot: the slot payload is the first thing it hears of him
  veafRemote.registerUserSlot("Zip", "ucid-zip", "Ninja-1-1", "99")
  luaunit.assertEquals(veafRemote.getRemoteUserFromUnit("Ninja-1-1").level, 99)
end

function TestVeafRemoteSlotCarriesTheLevel:test_the_slot_level_refreshes_a_known_user()
  veafRemote.registerUser("Zip", 10, "ucid-zip")
  veafRemote.registerUserSlot("Zip", "ucid-zip", "Ninja-1-1", "99")
  luaunit.assertEquals(veafRemote.getRemoteUserFromUnit("Ninja-1-1").level, 99)
end

function TestVeafRemoteSlotCarriesTheLevel:test_a_slot_without_a_level_keeps_the_known_one()
  -- an older hook sends three values; the level already registered must survive it
  veafRemote.registerUser("Zip", 99, "ucid-zip")
  veafRemote.registerUserSlot("Zip", "ucid-zip", "Ninja-1-1")
  luaunit.assertEquals(veafRemote.getRemoteUserFromUnit("Ninja-1-1").level, 99)
end

-- The repair that never happened on private1: the chat registration must reach the unit's entry.
function TestVeafRemoteSlotCarriesTheLevel:test_a_later_registration_repairs_the_unit()
  veafRemote.registerUserSlot("Zip", "ucid-zip", "Ninja-1-1") -- old hook, unknown player: no level
  veafRemote.registerUser("Zip", 99, "ucid-zip") -- any chat command of a listed pilot
  luaunit.assertEquals(veafRemote.getRemoteUserFromUnit("Ninja-1-1").level, 99)
end

function TestVeafRemoteSlotCarriesTheLevel:test_registering_again_keeps_the_unit_the_player_sits_in()
  veafRemote.registerUser("Zip", 10, "ucid-zip")
  veafRemote.registerUserSlot("Zip", "ucid-zip", "Ninja-1-1")
  veafRemote.registerUser("Zip", 99, "ucid-zip")
  luaunit.assertEquals(veafRemote.getRemoteUser("Zip").unitName, "Ninja-1-1")
  luaunit.assertIs(veafRemote.getRemoteUserFromUnit("Ninja-1-1"), veafRemote.getRemoteUser("Zip"))
end

-- Updating in place keeps `unitName` across a reconnection, and DCS sends no usable slot change when a
-- player leaves: the unit they left may belong to someone else by the time they take a new one. Releasing
-- it then would drop that other pilot to level 0 (found by the PR review of #1032).
function TestVeafRemoteSlotCarriesTheLevel:test_a_returning_player_does_not_release_a_unit_someone_else_took()
  veafRemote.registerUser("Zip", 99, "ucid-zip")
  veafRemote.registerUserSlot("Zip", "ucid-zip", "Ninja-1-1")
  -- Zip disconnects: no slot change reaches the mission; Bob takes the same unit
  veafRemote.registerUser("Bob", 50, "ucid-bob")
  veafRemote.registerUserSlot("Bob", "ucid-bob", "Ninja-1-1")
  -- Zip reconnects and takes another unit
  veafRemote.registerUser("Zip", 99, "ucid-zip")
  veafRemote.registerUserSlot("Zip", "ucid-zip", "Ninja-2-1")
  luaunit.assertEquals(veafRemote.getRemoteUserFromUnit("Ninja-1-1").name, "Bob")
  luaunit.assertEquals(veafRemote.getRemoteUserFromUnit("Ninja-2-1").name, "Zip")
end

function TestVeafRemoteSlotCarriesTheLevel:test_a_slot_with_no_level_known_anywhere_is_reported()
  local logger = veaf.loggers.get(veafRemote.Id)
  local saved = logger.warn
  local warned = {}
  logger.warn = function(_, text, ...)
    table.insert(warned, string.format(text, ...))
  end
  veafRemote.registerUserSlot("Zip", "ucid-zip", "Ninja-1-1")
  logger.warn = saved
  luaunit.assertEquals(#warned, 1)
  luaunit.assertStrContains(warned[1], "Zip")
end

function TestVeafRemoteSlotCarriesTheLevel:test_a_slot_with_a_level_is_not_reported()
  local logger = veaf.loggers.get(veafRemote.Id)
  local saved = logger.warn
  local warned = 0
  logger.warn = function()
    warned = warned + 1
  end
  veafRemote.registerUserSlot("Zip", "ucid-zip", "Ninja-1-1", "99")
  veafRemote.registerUserSlot("Zip", "ucid-zip", "") -- and leaving the slot is no reason either
  logger.warn = saved
  luaunit.assertEquals(warned, 0)
end

function TestVeafRemoteSlotCarriesTheLevel:test_an_unusable_slot_level_is_ignored()
  veafRemote.registerUser("Zip", 99, "ucid-zip")
  veafRemote.registerUserSlot("Zip", "ucid-zip", "Ninja-1-1", "")
  luaunit.assertEquals(veafRemote.getRemoteUserFromUnit("Ninja-1-1").level, 99)
end

-- ---------------------------------------------------------------------------
-- FIX-SECU-VERB-AND-LOG-NOISE ticket 02 — a mistyped chat command is answered, never raised
--
-- private1, 2026-09-29: `/sec`, `/se cu login`, `/veaf login`, `/veaflogin` in 90 minutes, three pilots
-- hunting for `/secu`. Each one logged an ERROR with a stack traceback and told the pilot nothing, so he
-- tried the next spelling.
-- ---------------------------------------------------------------------------
TestVeafRemoteUnknownModule = {}

function TestVeafRemoteUnknownModule:setUp()
  self.savedRegistry = veafRemote.remoteModuleRegistry
  veafRemote.remoteModuleRegistry = {}
  veafRemote.registerRemoteModule("secu", function()
    return true
  end)
  veafRemote.registerRemoteModule("point", function()
    return true
  end)
  self.answers = {}
  self.savedOut = veaf.outTextForUnit
  veaf.outTextForUnit = function(unitName, message)
    table.insert(self.answers, { unitName = unitName, message = message })
  end
  local logger = veaf.loggers.get(veafRemote.Id)
  self.savedError = logger.error
  self.errors = 0
  logger.error = function()
    self.errors = self.errors + 1
  end
  -- the unit has to exist for the answer to have somewhere to go
  dcs_mocks.addUnit("Ninja-1-1")
end

function TestVeafRemoteUnknownModule:tearDown()
  veafRemote.remoteModuleRegistry = self.savedRegistry
  veaf.outTextForUnit = self.savedOut
  veaf.loggers.get(veafRemote.Id).error = self.savedError
end

function TestVeafRemoteUnknownModule:test_an_unknown_module_answers_the_pilot()
  local ok = pcall(veafRemote.executeCommandFromRemote, "Zip", "99", "Ninja-1-1", "veaflogin", "")
  luaunit.assertTrue(ok)
  luaunit.assertEquals(#self.answers, 1)
  luaunit.assertEquals(self.answers[1].unitName, "Ninja-1-1")
  -- the answer lists what exists, which is what the pilot was looking for
  luaunit.assertStrContains(self.answers[1].message, "/secu")
  luaunit.assertStrContains(self.answers[1].message, "/point")
end

function TestVeafRemoteUnknownModule:test_an_unknown_module_logs_no_error()
  veafRemote.executeCommandFromRemote("Zip", "99", "Ninja-1-1", "veaf", "login")
  luaunit.assertEquals(self.errors, 0, "a typing mistake is not a programming fault")
end

function TestVeafRemoteUnknownModule:test_an_unknown_module_still_returns_false()
  luaunit.assertFalse(veafRemote.executeCommandFromRemote("Zip", "99", "Ninja-1-1", "sec", "login"))
end

function TestVeafRemoteUnknownModule:test_a_prefix_of_one_module_names_it()
  veafRemote.executeCommandFromRemote("Zip", "99", "Ninja-1-1", "sec", "login")
  luaunit.assertStrContains(self.answers[1].message, "/secu login")
end

function TestVeafRemoteUnknownModule:test_a_prefix_is_suggested_never_run()
  local ran = false
  veafRemote.registerRemoteModule("secu", function()
    ran = true
    return true
  end)
  veafRemote.executeCommandFromRemote("Zip", "99", "Ninja-1-1", "sec", "login")
  luaunit.assertFalse(ran, "a secured verb must be typed in full, not guessed")
end

-- A spectator has no unit, and `veaf.outTextForUnit` falls back to a message for everybody: a typo must
-- not be broadcast to the whole server. The hook used to send the literal "nil" in that case.
function TestVeafRemoteUnknownModule:test_a_player_in_no_unit_is_not_answered_in_public()
  for _, noUnit in ipairs({ "nil", "" }) do
    self.answers = {}
    veafRemote.executeCommandFromRemote("Zip", "99", noUnit, "veaf", "login")
    luaunit.assertEquals(#self.answers, 0, noUnit)
  end
end

function TestVeafRemoteUnknownModule:test_a_known_module_still_runs()
  luaunit.assertTrue(veafRemote.executeCommandFromRemote("Zip", "99", "Ninja-1-1", "SECU", "login"))
  luaunit.assertEquals(#self.answers, 0)
end

os.exit(luaunit.LuaUnit.run())
