--- Unit tests for veafSecurity.lua
---
--- Run:  lua test/lua/test_veafSecurity.lua
---
--- Covers:
---   - sha1.hex: FIPS 180-2 test vectors (empty, abc, fox, 448-bit message)
---   - sha1.hmacHex: RFC 2202 test vector
---   - markTextAnalysis: login / logout / no keyphrase / edge cases
---   - _checkPassword / checkPassword_L0 / checkPassword_L1: correct, wrong, nil
---   - isAuthenticated: initial state, manual flag set, SecurityDisabled

local _base = debug.getinfo(1, "S").source:match("^@(.+)[\\/]") or "."
luaunit = dofile(_base .. "/luaunit.lua")
dofile(_base .. "/dcs_mocks.lua")
local src = _base .. "/../../src/scripts/veaf"
dofile(src .. "/veaf.lua")
dofile(src .. "/veafSecurity.lua")

-- ============================================================================
-- Test suite
-- ============================================================================
TestVeafSecurity = {}

function TestVeafSecurity:setUp()
  dcs_mocks.reset()
  -- Ensure a clean authentication state before each test
  veaf.SecurityDisabled = false
  veafSecurity.authenticated = false
  veafSecurity.SecurityDisabled = nil
  -- Restore pristine password dicts (remove any extra entries added by tests)
  veafSecurity.password_L0 = { [veafSecurity.PASSWORD_L0] = true }
  veafSecurity.password_L1 = { [veafSecurity.PASSWORD_L1] = true }
end

-- -----------------------------------------------------------------------
-- sha1.hex — FIPS 180-2 test vectors
-- -----------------------------------------------------------------------
function TestVeafSecurity:test_sha1_empty_string()
  luaunit.assertEquals(sha1.hex(""), "da39a3ee5e6b4b0d3255bfef95601890afd80709")
end

function TestVeafSecurity:test_sha1_abc()
  luaunit.assertEquals(sha1.hex("abc"), "a9993e364706816aba3e25717850c26c9cd0d89d")
end

function TestVeafSecurity:test_sha1_quick_brown_fox()
  luaunit.assertEquals(sha1.hex("The quick brown fox jumps over the lazy dog"), "2fd4e1c67a2d28fced849ee1bb76e7391b93eb12")
end

function TestVeafSecurity:test_sha1_448_bit_message()
  -- FIPS 180-2 § B.2: SHA-1 of a 448-bit (56-byte) message crosses one padding block
  luaunit.assertEquals(sha1.hex("abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq"), "84983e441c3bd26ebaae4aa1f95129e5e54670f1")
end

function TestVeafSecurity:test_sha1_different_inputs_differ()
  -- Sanity: two distinct inputs produce different digests
  luaunit.assertNotEquals(sha1.hex("hello"), sha1.hex("world"))
end

function TestVeafSecurity:test_sha1_deterministic()
  -- Same input always produces the same digest
  luaunit.assertEquals(sha1.hex("hello"), sha1.hex("hello"))
end

function TestVeafSecurity:test_sha1_output_length_is_40_hex_chars()
  luaunit.assertEquals(#sha1.hex("any string"), 40)
end

-- -----------------------------------------------------------------------
-- sha1.hmacHex — RFC 2202 test case #2
-- Key  = "Jefe"
-- Data = "what do ya want for nothing?"
-- Expected = effcdf6ae5eb2fa2d27416d5f184df9c259a7c79
-- -----------------------------------------------------------------------
function TestVeafSecurity:test_hmac_rfc2202_tc2()
  luaunit.assertEquals(sha1.hmacHex("Jefe", "what do ya want for nothing?"), "effcdf6ae5eb2fa2d27416d5f184df9c259a7c79")
end

function TestVeafSecurity:test_hmac_output_length_is_40_hex_chars()
  luaunit.assertEquals(#sha1.hmacHex("key", "message"), 40)
end

-- -----------------------------------------------------------------------
-- markTextAnalysis
-- -----------------------------------------------------------------------
function TestVeafSecurity:test_markTextAnalysis_login()
  local sw = veafSecurity.markTextAnalysis("_auth mypassword")
  luaunit.assertNotNil(sw)
  luaunit.assertTrue(sw.login)
  luaunit.assertFalse(sw.logout)
  luaunit.assertEquals(sw.password, "mypassword")
end

function TestVeafSecurity:test_markTextAnalysis_logout()
  local sw = veafSecurity.markTextAnalysis("_auth logout")
  luaunit.assertNotNil(sw)
  luaunit.assertTrue(sw.logout)
  luaunit.assertFalse(sw.login)
end

function TestVeafSecurity:test_markTextAnalysis_keyphrase_case_insensitive()
  -- text:lower() is used for the keyphrase search
  local sw = veafSecurity.markTextAnalysis("_AUTH mypassword")
  luaunit.assertNotNil(sw)
  luaunit.assertTrue(sw.login)
end

function TestVeafSecurity:test_markTextAnalysis_no_keyphrase_returns_nil()
  luaunit.assertNil(veafSecurity.markTextAnalysis("_spawn infantry, size 3"))
end

function TestVeafSecurity:test_markTextAnalysis_empty_text_returns_nil()
  luaunit.assertNil(veafSecurity.markTextAnalysis(""))
end

function TestVeafSecurity:test_markTextAnalysis_unrelated_text_returns_nil()
  luaunit.assertNil(veafSecurity.markTextAnalysis("hello world"))
end

-- -----------------------------------------------------------------------
-- checkPassword_L0
-- -----------------------------------------------------------------------
function TestVeafSecurity:test_checkPassword_L0_correct_password()
  -- Inject sha1("test") so we can verify with a known plaintext
  local hash = sha1.hex("test")
  veafSecurity.password_L0[hash] = true
  luaunit.assertTrue(veafSecurity.checkPassword_L0("test"))
end

function TestVeafSecurity:test_checkPassword_L0_wrong_password()
  luaunit.assertFalse(veafSecurity.checkPassword_L0("completely_wrong_xyz"))
end

function TestVeafSecurity:test_checkPassword_L0_nil_password()
  luaunit.assertFalse(veafSecurity.checkPassword_L0(nil))
end

function TestVeafSecurity:test_checkPassword_L0_bypassed_when_SecurityDisabled()
  veaf.SecurityDisabled = true
  -- Any password (even nil) should return true when security is disabled
  luaunit.assertTrue(veafSecurity.checkPassword_L0("anything"))
end

-- -----------------------------------------------------------------------
-- checkPassword_L1 (also accepts L0 passwords — escalation chain)
-- -----------------------------------------------------------------------
function TestVeafSecurity:test_checkPassword_L1_accepts_L0_password()
  -- L1 check falls through to L0 check
  local hash = sha1.hex("test")
  veafSecurity.password_L0[hash] = true
  luaunit.assertTrue(veafSecurity.checkPassword_L1("test"))
end

function TestVeafSecurity:test_checkPassword_L1_wrong_password()
  luaunit.assertFalse(veafSecurity.checkPassword_L1("completely_wrong_xyz"))
end

-- -----------------------------------------------------------------------
-- isAuthenticated
-- -----------------------------------------------------------------------
function TestVeafSecurity:test_isAuthenticated_initially_falsy()
  -- isAuthenticated() returns authenticated OR SecurityDisabled;
  -- both are false/nil initially, so the result is falsy (nil in Lua)
  luaunit.assertTrue(not veafSecurity.isAuthenticated())
end

function TestVeafSecurity:test_isAuthenticated_true_when_flag_set()
  veafSecurity.authenticated = true
  luaunit.assertTrue(veafSecurity.isAuthenticated())
end

function TestVeafSecurity:test_isAuthenticated_falsy_after_flag_cleared()
  veafSecurity.authenticated = true
  veafSecurity.authenticated = false
  luaunit.assertTrue(not veafSecurity.isAuthenticated())
end

-- SECREV-009: isAuthenticated must fall back to veaf.SecurityDisabled (the real
-- flag), not the never-assigned veafSecurity.SecurityDisabled.
function TestVeafSecurity:test_isAuthenticated_true_when_security_disabled()
  veafSecurity.authenticated = false
  veaf.SecurityDisabled = true
  luaunit.assertTrue(veafSecurity.isAuthenticated())
end

-- ============================================================================

-------------------------------------------------------------------------------------------------
-- REVIEW-SECURITY-LAYER ticket 01 — a group's level, and the temporary elevation
--
-- DCS offers no per-unit menu API (missionCommands is all/coalition/group), so a secured F10
-- command cannot know which occupant clicked it. The level applied to a group is therefore the
-- **minimum** of its occupants: never permissive, exact in the dominant dynamic-slotting case
-- (1 pilot = 1 unit = 1 group). Taking the maximum would reproduce the very bug being fixed,
-- one player inheriting another's rights, merely at group scale instead of server scale.
--
-- The escape hatch is David's: an identified request elevates the group to the requester's own
-- level for 2 minutes.
-------------------------------------------------------------------------------------------------

TestVeafSecurityGroupLevel = {}

function TestVeafSecurityGroupLevel:setUp()
  veafSecurity.groupElevations = {}
  self.originalGetLevel = veafSecurity.getPilotLevelForUnit
  -- Stand in for the pilot registry: unit name -> level.
  self.levels = {}
  veafSecurity.getPilotLevelForUnit = function(unitName)
    return self.levels[unitName]
  end
  self.originalOccupants = veafSecurity.getGroupOccupantUnitNames
  veafSecurity.getGroupOccupantUnitNames = function(groupId)
    return self.occupants and self.occupants[groupId] or {}
  end
  self.occupants = {}
end

function TestVeafSecurityGroupLevel:tearDown()
  veafSecurity.getPilotLevelForUnit = self.originalGetLevel
  veafSecurity.getGroupOccupantUnitNames = self.originalOccupants
  veafSecurity.groupElevations = {}
end

function TestVeafSecurityGroupLevel:test_single_occupant_gives_their_level()
  self.occupants[1] = { "pilot1" }
  self.levels["pilot1"] = veafSecurity.LEVEL_ADMIN
  luaunit.assertEquals(veafSecurity.getGroupLevel(1), veafSecurity.LEVEL_ADMIN)
end

function TestVeafSecurityGroupLevel:test_mixed_group_takes_the_minimum()
  -- An admin sitting in a four-slot group must not lend their rights to the other three.
  self.occupants[1] = { "admin", "rookie" }
  self.levels["admin"] = veafSecurity.LEVEL_ADMIN
  self.levels["rookie"] = veafSecurity.LEVEL_KNOWN_PILOT
  luaunit.assertEquals(veafSecurity.getGroupLevel(1), veafSecurity.LEVEL_KNOWN_PILOT)
end

function TestVeafSecurityGroupLevel:test_unknown_occupant_drags_the_group_down()
  -- An unlisted player has no level at all; fail closed rather than ignoring them.
  self.occupants[1] = { "admin", "stranger" }
  self.levels["admin"] = veafSecurity.LEVEL_ADMIN
  luaunit.assertEquals(veafSecurity.getGroupLevel(1), 0)
end

function TestVeafSecurityGroupLevel:test_empty_group_is_zero()
  self.occupants[1] = {}
  luaunit.assertEquals(veafSecurity.getGroupLevel(1), 0)
end

function TestVeafSecurityGroupLevel:test_elevation_raises_the_group()
  self.occupants[1] = { "admin", "rookie" }
  self.levels["admin"] = veafSecurity.LEVEL_ADMIN
  self.levels["rookie"] = veafSecurity.LEVEL_KNOWN_PILOT
  veafSecurity.elevateGroup(1, veafSecurity.LEVEL_ADMIN, "admin")
  luaunit.assertEquals(veafSecurity.getEffectiveGroupLevel(1), veafSecurity.LEVEL_ADMIN)
end

function TestVeafSecurityGroupLevel:test_elevation_expires()
  self.occupants[1] = { "admin", "rookie" }
  self.levels["admin"] = veafSecurity.LEVEL_ADMIN
  self.levels["rookie"] = veafSecurity.LEVEL_KNOWN_PILOT
  veafSecurity.elevateGroup(1, veafSecurity.LEVEL_ADMIN, "admin")
  timer.setTime(timer.getTime() + veafSecurity.ELEVATION_DURATION_SECONDS + 1)
  luaunit.assertEquals(veafSecurity.getEffectiveGroupLevel(1), veafSecurity.LEVEL_KNOWN_PILOT)
end

--- Pins the **product decision**, not an implementation detail: David asked for two minutes.
---
--- Every other test here reads the constant instead of the number, so tuning the window breaks
--- only this one -- which is the intent. A shorter or longer elevation changes how long a group
--- carries borrowed privileges, so it should be a deliberate edit with a reviewer, not something
--- that slides through green.
function TestVeafSecurityGroupLevel:test_elevation_lasts_two_minutes()
  luaunit.assertEquals(veafSecurity.ELEVATION_DURATION_SECONDS, 2 * 60)
end

function TestVeafSecurityGroupLevel:test_elevation_is_capped_at_the_requester_level()
  -- The whole safety of the hatch: a rookie cannot elevate their group to admin.
  self.occupants[1] = { "admin", "rookie" }
  self.levels["admin"] = veafSecurity.LEVEL_ADMIN
  self.levels["rookie"] = veafSecurity.LEVEL_KNOWN_PILOT
  local granted = veafSecurity.elevateGroupForPilot(1, veafSecurity.LEVEL_KNOWN_PILOT, "rookie")
  luaunit.assertEquals(granted, veafSecurity.LEVEL_KNOWN_PILOT)
  luaunit.assertEquals(veafSecurity.getEffectiveGroupLevel(1), veafSecurity.LEVEL_KNOWN_PILOT)
end

function TestVeafSecurityGroupLevel:test_effective_level_without_elevation_is_the_minimum()
  self.occupants[1] = { "admin", "rookie" }
  self.levels["admin"] = veafSecurity.LEVEL_ADMIN
  self.levels["rookie"] = veafSecurity.LEVEL_KNOWN_PILOT
  luaunit.assertEquals(veafSecurity.getEffectiveGroupLevel(1), veafSecurity.LEVEL_KNOWN_PILOT)
end

function TestVeafSecurityGroupLevel:test_elevation_is_per_group()
  self.occupants[1] = { "admin" }
  self.occupants[2] = { "rookie" }
  self.levels["admin"] = veafSecurity.LEVEL_ADMIN
  self.levels["rookie"] = veafSecurity.LEVEL_KNOWN_PILOT
  veafSecurity.elevateGroup(1, veafSecurity.LEVEL_ADMIN, "admin")
  luaunit.assertEquals(veafSecurity.getEffectiveGroupLevel(2), veafSecurity.LEVEL_KNOWN_PILOT)
end

-------------------------------------------------------------------------------------------------
-- The elevation command, on both channels (REVIEW-SECURITY-LAYER ticket 01)
--
-- The minimum-of-the-group rule costs an admin sharing a four-slot group their admin commands.
-- David's hatch: an identified request raises the group to the requester's own level for two
-- minutes. Identified is the operative word -- it is offered on the chat/remote channel and on
-- the marker, both of which carry an author, and never on the menu, which does not.
-------------------------------------------------------------------------------------------------

TestVeafSecurityElevationCommand = {}

function TestVeafSecurityElevationCommand:setUp()
  veafSecurity.groupElevations = {}
  self.originalGroupForUnit = veafSecurity.getGroupIdForUnit
  veafSecurity.getGroupIdForUnit = function(unitName)
    return self.groupsByUnit and self.groupsByUnit[unitName]
  end
  self.groupsByUnit = { ["admin unit"] = 42, ["rookie unit"] = 43 }
end

function TestVeafSecurityElevationCommand:tearDown()
  veafSecurity.getGroupIdForUnit = self.originalGroupForUnit
  veafSecurity.groupElevations = {}
end

function TestVeafSecurityElevationCommand:test_chat_elevate_raises_the_requester_group()
  local pilot = { level = veafSecurity.LEVEL_ADMIN, name = "admin" }
  local handled = veafSecurity.handleElevationRequest(pilot, "admin", "admin unit")
  luaunit.assertTrue(handled)
  luaunit.assertEquals(veafSecurity.groupElevations[42].level, veafSecurity.LEVEL_ADMIN)
end

function TestVeafSecurityElevationCommand:test_elevation_is_capped_at_requester_level()
  local pilot = { level = veafSecurity.LEVEL_KNOWN_PILOT, name = "rookie" }
  veafSecurity.handleElevationRequest(pilot, "rookie", "rookie unit")
  luaunit.assertEquals(veafSecurity.groupElevations[43].level, veafSecurity.LEVEL_KNOWN_PILOT)
end

function TestVeafSecurityElevationCommand:test_pilot_without_a_level_is_refused()
  local handled = veafSecurity.handleElevationRequest({ level = 0 }, "nobody", "admin unit")
  luaunit.assertFalse(handled)
  luaunit.assertNil(veafSecurity.groupElevations[42])
end

function TestVeafSecurityElevationCommand:test_unknown_unit_is_refused()
  local pilot = { level = veafSecurity.LEVEL_ADMIN, name = "admin" }
  local handled = veafSecurity.handleElevationRequest(pilot, "admin", "not a slot")
  luaunit.assertFalse(handled)
end

function TestVeafSecurityElevationCommand:test_nil_pilot_is_refused()
  luaunit.assertFalse(veafSecurity.handleElevationRequest(nil, "x", "admin unit"))
end

function TestVeafSecurityElevationCommand:test_marker_keyphrase_is_recognised()
  local options = veafSecurity.markTextAnalysis("_auth elevate")
  luaunit.assertNotNil(options)
  luaunit.assertTrue(options.elevate)
end

function TestVeafSecurityElevationCommand:test_login_still_parses()
  -- Guard: adding a verb must not break the two that exist.
  local options = veafSecurity.markTextAnalysis("_auth login")
  luaunit.assertNotNil(options)
  luaunit.assertTrue(options.login)
end

os.exit(luaunit.LuaUnit.run())
