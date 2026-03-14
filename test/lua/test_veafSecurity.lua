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
  veaf.SecurityDisabled          = false
  veafSecurity.authenticated     = false
  veafSecurity.SecurityDisabled  = nil
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
  luaunit.assertEquals(
    sha1.hex("The quick brown fox jumps over the lazy dog"),
    "2fd4e1c67a2d28fced849ee1bb76e7391b93eb12"
  )
end

function TestVeafSecurity:test_sha1_448_bit_message()
  -- FIPS 180-2 § B.2: SHA-1 of a 448-bit (56-byte) message crosses one padding block
  luaunit.assertEquals(
    sha1.hex("abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq"),
    "84983e441c3bd26ebaae4aa1f95129e5e54670f1"
  )
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
  luaunit.assertEquals(
    sha1.hmacHex("Jefe", "what do ya want for nothing?"),
    "effcdf6ae5eb2fa2d27416d5f184df9c259a7c79"
  )
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

-- ============================================================================
os.exit(luaunit.LuaUnit.run())
