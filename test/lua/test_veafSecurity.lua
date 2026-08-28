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
dofile(src .. "/veafScheduler.lua")
dofile(src .. "/veafMath.lua")
dofile(src .. "/veafGeo.lua")
dofile(src .. "/veafMissionDb.lua")
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

-- SECREV-009 moved this fallback from `veafSecurity.SecurityDisabled` to `veaf.SecurityDisabled`,
-- calling the old one "never assigned". That was true inside this repository and false outside it:
-- it is a **mission-facing config knob**, and the only places that assign it are mission configs —
-- including our own demo mission. REVIEW-SECURITY-LAYER ticket 03 honours both spellings again.
function TestVeafSecurity:test_isAuthenticated_true_when_security_disabled()
  veafSecurity.authenticated = false
  veaf.SecurityDisabled = true
  luaunit.assertTrue(veafSecurity.isAuthenticated())
end

-- ---------------------------------------------------------------------------
-- REVIEW-SECURITY-LAYER ticket 03 — the retired config field, honoured again
--
-- A mission written before 2026-06-10 sets `veafSecurity.SecurityDisabled`. SECREV-009 changed the
-- read to `veaf.SecurityDisabled` with no alias and no warning, so those missions silently got
-- security ON while asking for it OFF. Fail-safe, which is why three years went unnoticed — but
-- every secured command then refuses for everyone, and that reads as "the security layer is
-- broken" rather than "your config field was retired".
-- ---------------------------------------------------------------------------
TestVeafSecurityDisabledSpellings = {}

function TestVeafSecurityDisabledSpellings:setUp()
  self.savedVeaf = veaf.SecurityDisabled
  self.savedModule = veafSecurity.SecurityDisabled
  self.savedAuth = veafSecurity.authenticated
  veaf.SecurityDisabled = nil
  veafSecurity.SecurityDisabled = nil
  veafSecurity.authenticated = false
  veafSecurity._deprecationWarned = {}
end

function TestVeafSecurityDisabledSpellings:tearDown()
  veaf.SecurityDisabled = self.savedVeaf
  veafSecurity.SecurityDisabled = self.savedModule
  veafSecurity.authenticated = self.savedAuth
  veafSecurity._deprecationWarned = {}
end

function TestVeafSecurityDisabledSpellings:test_neither_spelling_means_security_on()
  luaunit.assertFalse(veafSecurity.isSecurityDisabled())
end

function TestVeafSecurityDisabledSpellings:test_the_current_spelling_is_honoured()
  veaf.SecurityDisabled = true
  luaunit.assertTrue(veafSecurity.isSecurityDisabled())
end

-- The whole point of the ticket: a v5-era mission gets the state it asked for.
function TestVeafSecurityDisabledSpellings:test_the_deprecated_spelling_is_honoured()
  veafSecurity.SecurityDisabled = true
  luaunit.assertTrue(veafSecurity.isSecurityDisabled())
end

function TestVeafSecurityDisabledSpellings:test_the_deprecated_spelling_reaches_isAuthenticated()
  veafSecurity.SecurityDisabled = true
  luaunit.assertTrue(veafSecurity.isAuthenticated())
end

-- It has to say so in the log, or the mission maker migrates only after discovering it in flight.
function TestVeafSecurityDisabledSpellings:test_the_deprecated_spelling_warns()
  local warnings = {}
  local logger = veaf.loggers.get(veafSecurity.Id)
  local saved = logger.warn
  logger.warn = function(_, message, ...)
    table.insert(warnings, tostring(message))
  end

  veafSecurity.SecurityDisabled = true
  veafSecurity.isSecurityDisabled()

  logger.warn = saved
  luaunit.assertEquals(#warnings, 1, "expected exactly one deprecation warning")
  luaunit.assertStrContains(warnings[1], "veafSecurity.SecurityDisabled")
  luaunit.assertStrContains(warnings[1], "veaf.SecurityDisabled")
end

-- Once, not once per check: the flag is read on every secured command.
function TestVeafSecurityDisabledSpellings:test_the_warning_fires_only_once()
  local count = 0
  local logger = veaf.loggers.get(veafSecurity.Id)
  local saved = logger.warn
  logger.warn = function()
    count = count + 1
  end

  veafSecurity.SecurityDisabled = true
  for _ = 1, 5 do
    veafSecurity.isSecurityDisabled()
  end

  logger.warn = saved
  luaunit.assertEquals(count, 1)
end

-- The current spelling must not warn, or the log tells everyone to migrate away from what they use.
function TestVeafSecurityDisabledSpellings:test_the_current_spelling_does_not_warn()
  local count = 0
  local logger = veaf.loggers.get(veafSecurity.Id)
  local saved = logger.warn
  logger.warn = function()
    count = count + 1
  end

  veaf.SecurityDisabled = true
  veafSecurity.isSecurityDisabled()

  logger.warn = saved
  luaunit.assertEquals(count, 0)
end

-- Every secured gate has to see it, not just isAuthenticated.
function TestVeafSecurityDisabledSpellings:test_the_deprecated_spelling_reaches_the_password_gates()
  veafSecurity.SecurityDisabled = true
  luaunit.assertTrue(veafSecurity.checkPassword_L0(nil))
  luaunit.assertTrue(veafSecurity.checkPassword_L1(nil))
  luaunit.assertTrue(veafSecurity.checkPassword_L9(nil))
end

-- ---------------------------------------------------------------------------
-- REVIEW-SECURITY-LAYER ticket 02, finished — the by-name path had no reader
--
-- Ticket 02 renamed the tiers and shipped `LEVELS_BY_NAME` and `DEPRECATED_LEVEL_NAMES`. Measured
-- 2026-08-11: **neither table had a single reader**. The rename worked anyway, because callers write
-- `veafSecurity.LEVEL_ADMIN` directly — but the by-name resolution and its deprecation warning were
-- declared and never wired up. `levelForName` is that wiring.
-- ---------------------------------------------------------------------------
TestVeafSecurityLevelForName = {}

function TestVeafSecurityLevelForName:setUp()
  veafSecurity._deprecationWarned = {}
end

function TestVeafSecurityLevelForName:tearDown()
  veafSecurity._deprecationWarned = {}
end

function TestVeafSecurityLevelForName:test_current_names_resolve()
  luaunit.assertEquals(veafSecurity.levelForName("ADMIN"), veafSecurity.LEVEL_ADMIN)
  luaunit.assertEquals(veafSecurity.levelForName("SENIOR_PILOT"), veafSecurity.LEVEL_SENIOR_PILOT)
  luaunit.assertEquals(veafSecurity.levelForName("KNOWN_PILOT"), veafSecurity.LEVEL_KNOWN_PILOT)
end

-- The old names keep working; that is what "deprecated, not removed" has to mean.
function TestVeafSecurityLevelForName:test_deprecated_names_still_resolve_to_the_same_level()
  luaunit.assertEquals(veafSecurity.levelForName("L0"), veafSecurity.LEVEL_ADMIN)
  luaunit.assertEquals(veafSecurity.levelForName("L1"), veafSecurity.LEVEL_SENIOR_PILOT)
  luaunit.assertEquals(veafSecurity.levelForName("L9"), veafSecurity.LEVEL_KNOWN_PILOT)
end

function TestVeafSecurityLevelForName:test_names_are_case_insensitive()
  luaunit.assertEquals(veafSecurity.levelForName("admin"), veafSecurity.LEVEL_ADMIN)
  luaunit.assertEquals(veafSecurity.levelForName("l9"), veafSecurity.LEVEL_KNOWN_PILOT)
end

function TestVeafSecurityLevelForName:test_a_deprecated_name_warns_and_names_its_replacement()
  local warnings = {}
  local logger = veaf.loggers.get(veafSecurity.Id)
  local saved = logger.warn
  logger.warn = function(_, message)
    table.insert(warnings, tostring(message))
  end

  veafSecurity.levelForName("L0")

  logger.warn = saved
  luaunit.assertEquals(#warnings, 1)
  luaunit.assertStrContains(warnings[1], "L0")
  luaunit.assertStrContains(warnings[1], "ADMIN")
end

function TestVeafSecurityLevelForName:test_a_current_name_does_not_warn()
  local count = 0
  local logger = veaf.loggers.get(veafSecurity.Id)
  local saved = logger.warn
  logger.warn = function()
    count = count + 1
  end

  veafSecurity.levelForName("ADMIN")

  logger.warn = saved
  luaunit.assertEquals(count, 0)
end

-- "OPEN" means *no check* rather than a level, and the dispatcher treats it separately.
function TestVeafSecurityLevelForName:test_open_is_not_a_level()
  luaunit.assertNil(veafSecurity.levelForName("OPEN"))
end

function TestVeafSecurityLevelForName:test_an_unknown_name_is_nil_rather_than_a_default()
  luaunit.assertNil(veafSecurity.levelForName("BANANA"))
end

function TestVeafSecurityLevelForName:test_a_non_string_is_nil_rather_than_raising()
  luaunit.assertNil(veafSecurity.levelForName(nil))
  luaunit.assertNil(veafSecurity.levelForName(90))
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

-------------------------------------------------------------------------------------------------
-- SECREV-2 / VMR-095 — the auth duration reaches authenticate() as text a pilot typed
--
-- `-auth login <duration>` goes through `RemoteCommandParser`, so `minutes` is a *string*. The
-- guard was `not actualMinutes:match("%d+")` — unanchored, so any string with a digit anywhere
-- passed it, and `actualMinutes * 60` then raised on "abc5". Measured in Lua 5.1: an arithmetic
-- error, from a pilot's typo. "-5" was worse than an error: it scheduled the logout in the past,
-- so the mission unlocked and immediately relocked without saying why.
-------------------------------------------------------------------------------------------------

TestSecrev2AuthDuration = {}

function TestSecrev2AuthDuration:setUp()
  self._savedSchedule = veaf.scheduleFunction
  self._savedRemove = veaf.removeFunction
  self._savedAuthenticated = veafSecurity.authenticated
  self._savedWatchdog = veafSecurity.logoutWatchdog
  self.scheduled = {}
  veaf.scheduleFunction = function(fn, args, t)
    table.insert(self.scheduled, { fn = fn, args = args, time = t })
    return #self.scheduled
  end
  veaf.removeFunction = function(_) end
  veafSecurity.authenticated = false
  veafSecurity.logoutWatchdog = nil
end

function TestSecrev2AuthDuration:tearDown()
  veaf.scheduleFunction = self._savedSchedule
  veaf.removeFunction = self._savedRemove
  veafSecurity.authenticated = self._savedAuthenticated
  veafSecurity.logoutWatchdog = self._savedWatchdog
end

--- Minutes the logout was actually scheduled for, relative to now.
function TestSecrev2AuthDuration:_scheduledMinutes()
  luaunit.assertEquals(#self.scheduled, 1)
  return (self.scheduled[1].time - timer.getTime()) / 60
end

function TestSecrev2AuthDuration:test_a_numeric_string_is_honoured()
  veafSecurity.authenticate("30", nil)
  luaunit.assertEquals(self:_scheduledMinutes(), 30)
end

function TestSecrev2AuthDuration:test_a_number_is_honoured()
  veafSecurity.authenticate(30, nil)
  luaunit.assertEquals(self:_scheduledMinutes(), 30)
end

function TestSecrev2AuthDuration:test_a_digit_buried_in_text_does_not_raise()
  local ok = pcall(veafSecurity.authenticate, "abc5", nil)
  luaunit.assertTrue(ok, "a typo in the auth duration must not raise")
end

function TestSecrev2AuthDuration:test_a_digit_buried_in_text_falls_back_to_the_default()
  veafSecurity.authenticate("abc5", nil)
  luaunit.assertEquals(self:_scheduledMinutes(), veafSecurity.authDuration)
end

function TestSecrev2AuthDuration:test_a_negative_duration_falls_back_to_the_default()
  -- Not merely refused: a negative delay schedules the logout in the past, which unlocks the
  -- mission and relocks it on the next tick.
  veafSecurity.authenticate("-5", nil)
  luaunit.assertEquals(self:_scheduledMinutes(), veafSecurity.authDuration)
end

function TestSecrev2AuthDuration:test_zero_falls_back_to_the_default()
  veafSecurity.authenticate(0, nil)
  luaunit.assertEquals(self:_scheduledMinutes(), veafSecurity.authDuration)
end

function TestSecrev2AuthDuration:test_no_duration_at_all_uses_the_default()
  veafSecurity.authenticate(nil, nil)
  luaunit.assertEquals(self:_scheduledMinutes(), veafSecurity.authDuration)
end

-- ---------------------------------------------------------------------------
-- REVIEW-SECURITY-LAYER ticket 01 — the global short-circuit is gone
--
-- `checkSecurity_L0/L1/L9` each opened with `if veafSecurity.isAuthenticated() then return true end`,
-- a module-level boolean. One `/login` therefore granted every secured command to **every player on
-- the server** for `authDuration`, and while anyone was logged in the per-pilot path — the level the
-- server hook publishes from `veaf-pilots.txt` — was never reached at all: the blunt mechanism
-- disabled the precise one.
--
-- Removing it does not remove password access. `checkPassword_Lx(password)` stays in the condition,
-- so "your level suffices OR you give the password" still holds. What goes is the convenience of one
-- login buying ten minutes for everyone, replaced by an elevation scoped to one group.
-- ---------------------------------------------------------------------------
TestVeafSecurityNoGlobalShortCircuit = {}

function TestVeafSecurityNoGlobalShortCircuit:setUp()
  self.savedAuth = veafSecurity.authenticated
  self.savedDisabled = veaf.SecurityDisabled
  self.savedLevel = veafSecurity.getMarkerSecurityLevel
  veaf.SecurityDisabled = nil
  veafSecurity.SecurityDisabled = nil
  -- An unknown marker author: no level, so only a password can pass.
  veafSecurity.getMarkerSecurityLevel = function()
    return -1
  end
end

function TestVeafSecurityNoGlobalShortCircuit:tearDown()
  veafSecurity.authenticated = self.savedAuth
  veaf.SecurityDisabled = self.savedDisabled
  veafSecurity.SecurityDisabled = self.savedModuleDisabled
  veafSecurity.getMarkerSecurityLevel = self.savedLevel
end

-- The defect itself: a login by somebody else must not let an unidentified marker through.
function TestVeafSecurityNoGlobalShortCircuit:test_a_login_elsewhere_does_not_pass_a_secured_marker()
  veafSecurity.authenticated = true
  luaunit.assertFalse(veafSecurity.checkSecurity_L0(nil, "someone-else"))
  luaunit.assertFalse(veafSecurity.checkSecurity_L1(nil, "someone-else"))
  luaunit.assertFalse(veafSecurity.checkSecurity_L9(nil, "someone-else"))
end

-- Password access is untouched: that is what keeps the change from locking everyone out.
--
-- Registers a hash rather than passing `veafSecurity.PASSWORD_L0`, which is **already a SHA-1
-- digest** — `_checkPassword` hashes what it is given, so handing it the published hash would hash
-- the hash and never match.
function TestVeafSecurityNoGlobalShortCircuit:test_the_password_still_passes()
  veafSecurity.authenticated = false
  local _clear = "a-test-password"
  veafSecurity.password_L0[sha1.hex(_clear)] = true
  veafSecurity.password_L1[sha1.hex(_clear)] = true

  luaunit.assertTrue(veafSecurity.checkSecurity_L0(_clear, "someone"))
  luaunit.assertTrue(veafSecurity.checkSecurity_L1(_clear, "someone"))

  veafSecurity.password_L0[sha1.hex(_clear)] = nil
  veafSecurity.password_L1[sha1.hex(_clear)] = nil
end

-- A wrong password is refused, so the test above is not passing on the absence of a check.
function TestVeafSecurityNoGlobalShortCircuit:test_a_wrong_password_is_refused()
  veafSecurity.authenticated = false
  luaunit.assertFalse(veafSecurity.checkSecurity_L0("not-the-password", "someone"))
end

-- And a pilot whose own level suffices still passes with no password at all.
function TestVeafSecurityNoGlobalShortCircuit:test_a_sufficient_pilot_level_still_passes()
  veafSecurity.authenticated = false
  veafSecurity.getMarkerSecurityLevel = function()
    return veafSecurity.LEVEL_ADMIN
  end
  luaunit.assertTrue(veafSecurity.checkSecurity_L0(nil, "an-admin"))
  luaunit.assertTrue(veafSecurity.checkSecurity_L9(nil, "an-admin"))
end

-- `SecurityDisabled` is a mission-wide switch and must keep working: it is how a solo or test
-- mission turns the whole layer off, and it is not an authentication path.
function TestVeafSecurityNoGlobalShortCircuit:test_security_disabled_still_passes_everything()
  veafSecurity.authenticated = false
  veaf.SecurityDisabled = true
  luaunit.assertTrue(veafSecurity.checkSecurity_L0(nil, "anyone"))
  luaunit.assertTrue(veafSecurity.checkSecurity_L9(nil, "anyone"))
end

-- ---------------------------------------------------------------------------
-- REVIEW-SECURITY-LAYER ticket 01 — checkSecurity_MM has no actor, so it fails closed
--
-- It takes `(password)` and nothing else: no markId, no unit, no group. There is no identity to key
-- on, so the only safe answer for a caller that supplies no password is to refuse.
-- ---------------------------------------------------------------------------
TestVeafSecurityMissionMaster = {}

function TestVeafSecurityMissionMaster:setUp()
  self.savedAuth = veafSecurity.authenticated
  self.savedDisabled = veaf.SecurityDisabled
  -- Saved too, or nilling it here leaks into whatever ran before (Sourcery, #716).
  self.savedModuleDisabled = veafSecurity.SecurityDisabled
  veaf.SecurityDisabled = nil
  veafSecurity.SecurityDisabled = nil
end

function TestVeafSecurityMissionMaster:tearDown()
  veafSecurity.authenticated = self.savedAuth
  veaf.SecurityDisabled = self.savedDisabled
  veafSecurity.SecurityDisabled = self.savedModuleDisabled
end

function TestVeafSecurityMissionMaster:test_no_password_is_refused()
  veafSecurity.authenticated = false
  luaunit.assertFalse(veafSecurity.checkSecurity_MM(nil))
end

-- It never had the short-circuit, and it must not gain one.
function TestVeafSecurityMissionMaster:test_a_login_elsewhere_does_not_pass_it()
  veafSecurity.authenticated = true
  luaunit.assertFalse(veafSecurity.checkSecurity_MM(nil))
end

-- ---------------------------------------------------------------------------
-- REVIEW-SECURITY-LAYER ticket 01 — isKnownPilot, the alias-password gate
--
-- An alias password is a **per-alias secret with no tier attached**, so "which level excuses it?"
-- had no answer in the tier model. David chose option 1: being in `veaf-pilots.txt` at all excuses
-- it, whatever the level. That replaces `isAuthenticated()`, whose global boolean meant one player's
-- login excused the alias password for everybody.
-- ---------------------------------------------------------------------------
TestVeafSecurityIsKnownPilot = {}

function TestVeafSecurityIsKnownPilot:setUp()
  self.savedDisabled = veaf.SecurityDisabled
  self.savedModuleDisabled = veafSecurity.SecurityDisabled
  self.savedLevel = veafSecurity.getMarkerSecurityLevel
  veaf.SecurityDisabled = nil
  veafSecurity.SecurityDisabled = nil
end

function TestVeafSecurityIsKnownPilot:tearDown()
  veaf.SecurityDisabled = self.savedDisabled
  veafSecurity.SecurityDisabled = self.savedModuleDisabled
  veafSecurity.getMarkerSecurityLevel = self.savedLevel
end

-- The lowest tier is enough: the question is "known at all", not "senior enough".
function TestVeafSecurityIsKnownPilot:test_the_lowest_known_level_is_enough()
  veafSecurity.getMarkerSecurityLevel = function()
    return veafSecurity.LEVEL_KNOWN_PILOT
  end
  luaunit.assertTrue(veafSecurity.isKnownPilot("a-pilot"))
end

function TestVeafSecurityIsKnownPilot:test_a_higher_level_is_enough_too()
  veafSecurity.getMarkerSecurityLevel = function()
    return veafSecurity.LEVEL_ADMIN
  end
  luaunit.assertTrue(veafSecurity.isKnownPilot("an-admin"))
end

-- getMarkerSecurityLevel returns -1 for an author the server cannot resolve.
function TestVeafSecurityIsKnownPilot:test_an_unresolvable_author_is_not_known()
  veafSecurity.getMarkerSecurityLevel = function()
    return -1
  end
  luaunit.assertFalse(veafSecurity.isKnownPilot("a-stranger"))
end

-- 0 is what an occupant with no level yields elsewhere in this module; it must not pass either.
function TestVeafSecurityIsKnownPilot:test_level_zero_is_not_known()
  veafSecurity.getMarkerSecurityLevel = function()
    return 0
  end
  luaunit.assertFalse(veafSecurity.isKnownPilot("nobody"))
end

-- A solo or test mission turns the whole layer off, and that includes alias passwords.
function TestVeafSecurityIsKnownPilot:test_security_disabled_makes_everyone_known()
  veafSecurity.getMarkerSecurityLevel = function()
    return -1
  end
  veaf.SecurityDisabled = true
  luaunit.assertTrue(veafSecurity.isKnownPilot("a-stranger"))
end

-- The deprecated spelling has to work here too, or a v5-era mission still demands passwords.
function TestVeafSecurityIsKnownPilot:test_the_deprecated_disabled_spelling_also_applies()
  veafSecurity.getMarkerSecurityLevel = function()
    return -1
  end
  veafSecurity.SecurityDisabled = true
  luaunit.assertTrue(veafSecurity.isKnownPilot("a-stranger"))
end

-- The defect it replaces: another player's login must not excuse the alias password.
function TestVeafSecurityIsKnownPilot:test_a_login_elsewhere_does_not_make_a_stranger_known()
  local savedAuth = veafSecurity.authenticated
  veafSecurity.authenticated = true
  veafSecurity.getMarkerSecurityLevel = function()
    return -1
  end
  luaunit.assertFalse(veafSecurity.isKnownPilot("a-stranger"))
  veafSecurity.authenticated = savedAuth
end

os.exit(luaunit.LuaUnit.run())
