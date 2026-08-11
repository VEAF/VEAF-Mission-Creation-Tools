------------------------------------------------------------------
-- VEAF security function library for DCS World
-- By zip (2019)
--
-- Features:
-- ---------
-- * Checks if the user is part of an authorized users shortlist
--
-- See the documentation : https://veaf.github.io/documentation/
------------------------------------------------------------------

veafSecurity = {}

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Global settings. Stores the script constants
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Identifier. All output in DCS.log will start with this.
veafSecurity.Id = "SECURITY"

-- trace level, specific to this module
--veafSecurity.LogLevel = "trace"

veaf.loggers.new(veafSecurity.Id, veafSecurity.LogLevel)

--- Key phrase to look for in the mark text which triggers the command.
veafSecurity.Keyphrase = "_auth"

veafSecurity.authDuration = 10

veafSecurity.RemoteCommandParser = "([[a-zA-Z0-9]+)%s?(.*)"

-- Security tiers, from the loosest to the tightest. A check passes when the pilot's level is
-- **at least** the constant, so a bigger number is a tighter tier.
--
-- The names say what they mean since 2026-08-08 (REVIEW-SECURITY-LAYER ticket 02). The old
-- L0/L1/L9 names read backwards -- L0 was the *tightest* -- and that trap had already caught
-- someone: a proposal read "L0 - all players" off the documentation and would have locked a
-- deliberately public command to administrators. The **values are unchanged**, so no existing
-- mission changes behaviour; only the names people write are new.
veafSecurity.LEVEL_ADMIN = 90 -- server administrators
veafSecurity.LEVEL_SENIOR_PILOT = 10 -- trusted members
veafSecurity.LEVEL_KNOWN_PILOT = 1 -- anyone listed in veaf-pilots.txt (e.g. VEAF members)

-- Deprecated aliases, kept for one release so missions and third-party scripts written against the
-- old names keep working.
--
-- This comment used to claim `veafSecurity.registerCommandHandler` warns when one is used. It does
-- not, and it never could: **there is no such function** — `registerCommandHandler` lives in
-- `veafCommands`. Corrected 2026-08-11 rather than left describing a mechanism that does not exist.
veafSecurity.LEVEL_L0 = veafSecurity.LEVEL_ADMIN
veafSecurity.LEVEL_L1 = veafSecurity.LEVEL_SENIOR_PILOT
veafSecurity.LEVEL_L9 = veafSecurity.LEVEL_KNOWN_PILOT

--- Maps every accepted tier name to its level. "OPEN" is absent on purpose: it means *no check*
--- rather than a level, and the dispatcher treats it separately.
---
--- Resolve a name through `veafSecurity.levelForName`, which is what applies the deprecation
--- warning; reading this table directly bypasses it.
veafSecurity.LEVELS_BY_NAME = {
  ADMIN = veafSecurity.LEVEL_ADMIN,
  SENIOR_PILOT = veafSecurity.LEVEL_SENIOR_PILOT,
  KNOWN_PILOT = veafSecurity.LEVEL_KNOWN_PILOT,
  L0 = veafSecurity.LEVEL_ADMIN,
  L1 = veafSecurity.LEVEL_SENIOR_PILOT,
  L9 = veafSecurity.LEVEL_KNOWN_PILOT,
}

--- Old tier name -> new one, for the deprecation warning.
veafSecurity.DEPRECATED_LEVEL_NAMES = {
  L0 = "ADMIN",
  L1 = "SENIOR_PILOT",
  L9 = "KNOWN_PILOT",
}

--- Deprecated names already warned about, so a flag read on every secured command warns once.
veafSecurity._deprecationWarned = {}

--- Resolve a tier name to its level, warning once when a deprecated name is used.
---
--- `LEVELS_BY_NAME` and `DEPRECATED_LEVEL_NAMES` were both added by ticket 02 and **neither had a
--- single reader** — measured 2026-08-11. The rename shipped and worked, because callers write
--- `veafSecurity.LEVEL_ADMIN` directly, but the by-name path and its warning were declared and never
--- wired up. This is that wiring.
--- @param name a tier name, current or deprecated
--- @return number|nil the level, or nil when the name is not a tier
function veafSecurity.levelForName(name)
  if type(name) ~= "string" then
    return nil
  end
  local _upper = name:upper()
  local _current = veafSecurity.DEPRECATED_LEVEL_NAMES[_upper]
  if _current then
    veafSecurity.warnDeprecated("security level " .. _upper, _current)
  end
  return veafSecurity.LEVELS_BY_NAME[_upper]
end

--- Warn once that `oldName` is deprecated in favour of `newName`.
---
--- Once, not once per read: `isSecurityDisabled` is consulted by every secured gate, so warning on
--- each call would bury the log it is trying to inform.
--- @param oldName the deprecated spelling a mission used
--- @param newName what to write instead
function veafSecurity.warnDeprecated(oldName, newName)
  if veafSecurity._deprecationWarned[oldName] then
    return
  end
  veafSecurity._deprecationWarned[oldName] = true
  veaf.loggers
    .get(veafSecurity.Id)
    :warn(string.format("%s is deprecated and will be removed in a future release; use %s instead", oldName, newName))
end

--- Is security switched off by the mission's configuration?
---
--- REVIEW-SECURITY-LAYER ticket 03. Honours both spellings, because `veafSecurity.SecurityDisabled`
--- is a **mission-facing config knob** and not library state. `SECREV-009` moved the read to
--- `veaf.SecurityDisabled` on the grounds that the old name was "never assigned" — true inside this
--- repository, false outside it, since the only places that assign it are mission configs. Including
--- our own demo mission, at `test/veaf-tools/demo-mission/src/scripts/missionConfig.lua:633`.
---
--- The breakage was fail-safe, which is why three years of it went unnoticed: a mission asking for
--- security **off** got it **on**. Nobody was over-privileged — but every secured command then
--- refused for everyone, and that reads as "the security layer is broken" rather than "your config
--- field was retired".
---
--- For a config field, "nothing in the repository assigns it" is evidence of nothing.
--- @return boolean true when either spelling asks for security to be off
function veafSecurity.isSecurityDisabled()
  if veaf.SecurityDisabled then
    return true
  end
  if veafSecurity.SecurityDisabled then
    veafSecurity.warnDeprecated("veafSecurity.SecurityDisabled", "veaf.SecurityDisabled")
    return true
  end
  return false
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Utility methods
-------------------------------------------------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Do not change anything below unless you know what you are doing!
-------------------------------------------------------------------------------------------------------------------------------------------------------------

veafSecurity.password_L0 = {}
veafSecurity.password_L1 = {}
veafSecurity.password_L9 = {}
veafSecurity.password_MM = {}

-- list the security passwords common to all missions below
veafSecurity.PASSWORD_L0 = "47c7808d1079fd20add322bbd5cf23b93ad1841e"
veafSecurity.PASSWORD_L1 = "bdc82f5ef92369919a3a53515023ce19f68656cc"
veafSecurity.password_L0[veafSecurity.PASSWORD_L0] = true
veafSecurity.password_L1[veafSecurity.PASSWORD_L1] = true

-- Runs at module load, i.e. before any mission config is read, so this can only ever see nil.
-- Harmless, and kept because `initialize()` sets it again once the config has been applied.
veafSecurity.authenticated = veafSecurity.isSecurityDisabled()

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- SHA-1 pure LUA implementation
-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- $Revision: 1.5 $
-- $Date: 2014-09-10 16:54:25 $

-- This module was originally taken from http://cube3d.de/uploads/Main/sha1.txt.

-------------------------------------------------------------------------------
-- SHA-1 secure hash computation, and HMAC-SHA1 signature computation,
-- in pure Lua (tested on Lua 5.1)
-- License: MIT
--
-- Usage:
-- local hashAsHex = sha1.hex(message) -- returns a hex string
-- local hashAsData = sha1.bin(message) -- returns raw bytes
--
-- local hmacAsHex = sha1.hmacHex(key, message) -- hex string
-- local hmacAsData = sha1.hmacBin(key, message) -- raw bytes
--
--
-- Pass sha1.hex() a string, and it returns a hash as a 40-character hex string.
-- For example, the call
--
-- local hash = sha1.hex("iNTERFACEWARE")
--
-- puts the 40-character string
--
-- "e76705ffb88a291a0d2f9710a5471936791b4819"
--
-- into the variable 'hash'
--
-- Pass sha1.hmacHex() a key and a message, and it returns the signature as a
-- 40-byte hex string.
--
--
-- The two "bin" versions do the same, but return the 20-byte string of raw
-- data that the 40-byte hex strings represent.
--
-------------------------------------------------------------------------------
--
-- Description
-- Due to the lack of bitwise operations in 5.1, this version uses numbers to
-- represents the 32bit words that we combine with binary operations. The basic
-- operations of byte based "xor", "or", "and" are all cached in a combination
-- table (several 64k large tables are built on startup, which
-- consumes some memory and time). The caching can be switched off through
-- setting the local cfg_caching variable to false.
-- For all binary operations, the 32 bit numbers are split into 8 bit values
-- that are combined and then merged again.
--
-- Algorithm: http://www.itl.nist.gov/fipspubs/fip180-1.htm
--
-------------------------------------------------------------------------------

sha1 = {}

-- set this to false if you don't want to build several 64k sized tables when
-- loading this file (takes a while but grants a boost of factor 13)
local cfg_caching = false

-- local storing of global functions (minor speedup)
local floor, modf = math.floor, math.modf
local char, format, rep = string.char, string.format, string.rep

-- merge 4 bytes to an 32 bit word
local function bytes_to_w32(a, b, c, d)
  return a * 0x1000000 + b * 0x10000 + c * 0x100 + d
end
-- split a 32 bit word into four 8 bit numbers
local function w32_to_bytes(i)
  return floor(i / 0x1000000) % 0x100, floor(i / 0x10000) % 0x100, floor(i / 0x100) % 0x100, i % 0x100
end

-- shift the bits of a 32 bit word. Don't use negative values for "bits"
local function w32_rot(bits, a)
  local b2 = 2 ^ (32 - bits)
  local a, b = modf(a / b2)
  return a + b * b2 * (2 ^ bits)
end

-- caching function for functions that accept 2 arguments, both of values between
-- 0 and 255. The function to be cached is passed, all values are calculated
-- during loading and a function is returned that returns the cached values (only)
local function cache2arg(fn)
  if not cfg_caching then
    return fn
  end
  local lut = {}
  for i = 0, 0xffff do
    local a, b = floor(i / 0x100), i % 0x100
    lut[i] = fn(a, b)
  end
  return function(a, b)
    return lut[a * 0x100 + b]
  end
end

-- splits an 8-bit number into 8 bits, returning all 8 bits as booleans
local function byte_to_bits(b)
  local b = function(n)
    local b = floor(b / n)
    return b % 2 == 1
  end
  return b(1), b(2), b(4), b(8), b(16), b(32), b(64), b(128)
end

-- builds an 8bit number from 8 booleans
local function bits_to_byte(a, b, c, d, e, f, g, h)
  local function n(b, x)
    return b and x or 0
  end
  return n(a, 1) + n(b, 2) + n(c, 4) + n(d, 8) + n(e, 16) + n(f, 32) + n(g, 64) + n(h, 128)
end

-- debug function for visualizing bits in a string
local function bits_to_string(a, b, c, d, e, f, g, h)
  local function x(b)
    return b and "1" or "0"
  end
  return ("%s%s%s%s %s%s%s%s"):format(x(a), x(b), x(c), x(d), x(e), x(f), x(g), x(h))
end

-- debug function for converting a 8-bit number as bit string
local function byte_to_bit_string(b)
  return bits_to_string(byte_to_bits(b))
end

-- debug function for converting a 32 bit number as bit string
local function w32_to_bit_string(a)
  if type(a) == "string" then
    return a
  end
  local aa, ab, ac, ad = w32_to_bytes(a)
  local s = byte_to_bit_string
  return ("%s %s %s %s"):format(s(aa):reverse(), s(ab):reverse(), s(ac):reverse(), s(ad):reverse()):reverse()
end

-- bitwise "and" function for 2 8bit number
local band = cache2arg(function(a, b)
  local A, B, C, D, E, F, G, H = byte_to_bits(b)
  local a, b, c, d, e, f, g, h = byte_to_bits(a)
  return bits_to_byte(A and a, B and b, C and c, D and d, E and e, F and f, G and g, H and h)
end)

-- bitwise "or" function for 2 8bit numbers
local bor = cache2arg(function(a, b)
  local A, B, C, D, E, F, G, H = byte_to_bits(b)
  local a, b, c, d, e, f, g, h = byte_to_bits(a)
  return bits_to_byte(A or a, B or b, C or c, D or d, E or e, F or f, G or g, H or h)
end)

-- bitwise "xor" function for 2 8bit numbers
local bxor = cache2arg(function(a, b)
  local A, B, C, D, E, F, G, H = byte_to_bits(b)
  local a, b, c, d, e, f, g, h = byte_to_bits(a)
  return bits_to_byte(A ~= a, B ~= b, C ~= c, D ~= d, E ~= e, F ~= f, G ~= g, H ~= h)
end)

-- bitwise complement for one 8bit number
local function bnot(x)
  return 255 - (x % 256)
end

-- creates a function to combine to 32bit numbers using an 8bit combination function
local function w32_comb(fn)
  return function(a, b)
    local aa, ab, ac, ad = w32_to_bytes(a)
    local ba, bb, bc, bd = w32_to_bytes(b)
    return bytes_to_w32(fn(aa, ba), fn(ab, bb), fn(ac, bc), fn(ad, bd))
  end
end

-- create functions for and, xor and or, all for 2 32bit numbers
local w32_and = w32_comb(band)
local w32_xor = w32_comb(bxor)
local w32_or = w32_comb(bor)

-- xor function that may receive a variable number of arguments
local function w32_xor_n(a, ...)
  local aa, ab, ac, ad = w32_to_bytes(a)
  for i = 1, select("#", ...) do
    local ba, bb, bc, bd = w32_to_bytes(select(i, ...))
    aa, ab, ac, ad = bxor(aa, ba), bxor(ab, bb), bxor(ac, bc), bxor(ad, bd)
  end
  return bytes_to_w32(aa, ab, ac, ad)
end

-- combining 3 32bit numbers through binary "or" operation
local function w32_or3(a, b, c)
  local aa, ab, ac, ad = w32_to_bytes(a)
  local ba, bb, bc, bd = w32_to_bytes(b)
  local ca, cb, cc, cd = w32_to_bytes(c)
  return bytes_to_w32(bor(aa, bor(ba, ca)), bor(ab, bor(bb, cb)), bor(ac, bor(bc, cc)), bor(ad, bor(bd, cd)))
end

-- binary complement for 32bit numbers
local function w32_not(a)
  return 4294967295 - (a % 4294967296)
end

-- adding 2 32bit numbers, cutting off the remainder on 33th bit
local function w32_add(a, b)
  return (a + b) % 4294967296
end

-- adding n 32bit numbers, cutting off the remainder (again)
local function w32_add_n(a, ...)
  for i = 1, select("#", ...) do
    a = (a + select(i, ...)) % 4294967296
  end
  return a
end
-- converting the number to a hexadecimal string
local function w32_to_hexstring(w)
  return format("%08x", w)
end

-- calculating the SHA1 for some text
function sha1.hex(msg)
  local H0, H1, H2, H3, H4 = 0x67452301, 0xEFCDAB89, 0x98BADCFE, 0x10325476, 0xC3D2E1F0
  local msg_len_in_bits = #msg * 8

  local first_append = char(0x80) -- append a '1' bit plus seven '0' bits

  local non_zero_message_bytes = #msg + 1 + 8 -- the +1 is the appended bit 1, the +8 are for the final appended length
  local current_mod = non_zero_message_bytes % 64
  local second_append = current_mod > 0 and rep(char(0), 64 - current_mod) or ""

  -- now to append the length as a 64-bit number.
  local B1, R1 = modf(msg_len_in_bits / 0x01000000)
  local B2, R2 = modf(0x01000000 * R1 / 0x00010000)
  local B3, R3 = modf(0x00010000 * R2 / 0x00000100)
  local B4 = 0x00000100 * R3

  local L64 = char(0)
    .. char(0)
    .. char(0)
    .. char(0) -- high 32 bits
    .. char(B1)
    .. char(B2)
    .. char(B3)
    .. char(B4) -- low 32 bits

  msg = msg .. first_append .. second_append .. L64

  assert(#msg % 64 == 0)

  local chunks = #msg / 64

  local W = {}
  local start, A, B, C, D, E, f, K, TEMP
  local chunk = 0

  while chunk < chunks do
    --
    -- break chunk up into W[0] through W[15]
    --
    start, chunk = chunk * 64 + 1, chunk + 1

    for t = 0, 15 do
      W[t] = bytes_to_w32(msg:byte(start, start + 3))
      start = start + 4
    end

    --
    -- build W[16] through W[79]
    --
    for t = 16, 79 do
      -- For t = 16 to 79 let Wt = S1(Wt-3 XOR Wt-8 XOR Wt-14 XOR Wt-16).
      W[t] = w32_rot(1, w32_xor_n(W[t - 3], W[t - 8], W[t - 14], W[t - 16]))
    end

    A, B, C, D, E = H0, H1, H2, H3, H4

    for t = 0, 79 do
      if t <= 19 then
        -- (B AND C) OR ((NOT B) AND D)
        f = w32_or(w32_and(B, C), w32_and(w32_not(B), D))
        K = 0x5A827999
      elseif t <= 39 then
        -- B XOR C XOR D
        f = w32_xor_n(B, C, D)
        K = 0x6ED9EBA1
      elseif t <= 59 then
        -- (B AND C) OR (B AND D) OR (C AND D
        f = w32_or3(w32_and(B, C), w32_and(B, D), w32_and(C, D))
        K = 0x8F1BBCDC
      else
        -- B XOR C XOR D
        f = w32_xor_n(B, C, D)
        K = 0xCA62C1D6
      end

      -- TEMP = S5(A) + ft(B,C,D) + E + Wt + Kt;
      A, B, C, D, E = w32_add_n(w32_rot(5, A), f, E, W[t], K), A, w32_rot(30, B), C, D
    end
    -- Let H0 = H0 + A, H1 = H1 + B, H2 = H2 + C, H3 = H3 + D, H4 = H4 + E.
    H0, H1, H2, H3, H4 = w32_add(H0, A), w32_add(H1, B), w32_add(H2, C), w32_add(H3, D), w32_add(H4, E)
  end
  local f = w32_to_hexstring
  return f(H0) .. f(H1) .. f(H2) .. f(H3) .. f(H4)
end

local function hex_to_binary(hex)
  return hex:gsub("..", function(hexval)
    return string.char(tonumber(hexval, 16))
  end)
end

function sha1.bin(msg)
  return hex_to_binary(sha1.hex(msg))
end

local xor_with_0x5c = {}
local xor_with_0x36 = {}
-- building the lookuptables ahead of time (instead of littering the source code
-- with precalculated values)
for i = 0, 0xff do
  xor_with_0x5c[char(i)] = char(bxor(i, 0x5c))
  xor_with_0x36[char(i)] = char(bxor(i, 0x36))
end

local blocksize = 64 -- 512 bits

function sha1.hmacHex(key, text)
  assert(type(key) == "string", "key passed to hmacHex should be a string")
  assert(type(text) == "string", "text passed to hmacHex should be a string")

  if #key > blocksize then
    key = sha1.bin(key)
  end

  local key_xord_with_0x36 = key:gsub(".", xor_with_0x36) .. string.rep(string.char(0x36), blocksize - #key)
  local key_xord_with_0x5c = key:gsub(".", xor_with_0x5c) .. string.rep(string.char(0x5c), blocksize - #key)

  return sha1.hex(key_xord_with_0x5c .. sha1.bin(key_xord_with_0x36 .. text))
end

function sha1.hmacBin(key, text)
  return hex_to_binary(sha1.hmacHex(key, text))
end
----------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- remote interface
-------------------------------------------------------------------------------------------------------------------------------------------------------------

-- execute command from the remote interface
function veafSecurity.executeCommandFromRemote(parameters)
  veaf.loggers.get(veafSecurity.Id):debug(string.format("veafSecurity.executeCommandFromRemote()"))
  veaf.loggers.get(veafSecurity.Id):trace(string.format("parameters= %s", veaf.p(parameters)))
  local _pilot, _pilotName, _unitName, _command = unpack(parameters)
  veaf.loggers.get(veafSecurity.Id):trace(string.format("_pilot= %s", veaf.p(_pilot)))
  veaf.loggers.get(veafSecurity.Id):trace(string.format("_pilotName= %s", veaf.p(_pilotName)))
  veaf.loggers.get(veafSecurity.Id):trace(string.format("_unitName= %s", veaf.p(_unitName)))
  veaf.loggers.get(veafSecurity.Id):trace(string.format("_command= %s", veaf.p(_command)))
  if not _pilot or not _command then
    return false
  end

  if _command then
    -- parse the command
    local _action, _parameters = _command:match(veafSecurity.RemoteCommandParser)
    veaf.loggers.get(veafSecurity.Id):trace(string.format("_action=%s", veaf.p(_action)))
    veaf.loggers.get(veafSecurity.Id):trace(string.format("_parameters=%s", veaf.p(_parameters)))
    if _action and _action:lower() == "login" then
      if _pilot.level >= veafSecurity.LEVEL_L1 then
        veaf.loggers.get(veafSecurity.Id):info(string.format("[%s] is unlocking the mission", veaf.p(_pilotName)))
        veafSecurity.authenticate(_parameters, _unitName)
        return true
      else
        veaf.loggers.get(veafSecurity.Id):warn(string.format("[%s] has not the required level to unlock the mission", veaf.p(_pilotName)))
        return false
      end
    elseif _action and _action:lower() == "elevate" then
      -- No level gate here beyond having one at all: the elevation is capped at the requester's
      -- own level, so it can never grant more than they already hold.
      return veafSecurity.handleElevationRequest(_pilot, _pilotName, _unitName)
    elseif _action and _action:lower() == "logout" then
      if _pilot.level >= veafSecurity.LEVEL_L1 then
        local _silent = _parameters and _parameters:lower() == "silent"
        veaf.loggers.get(veafSecurity.Id):info(string.format("[%s] is locking the mission", veaf.p(_pilotName)))
        veafSecurity.logout(not _silent, _unitName)
        return true
      else
        veaf.loggers.get(veafSecurity.Id):warn(string.format("[%s] has not the required level to lock the mission", veaf.p(_pilotName)))
        return false
      end
    end
  end
  return false
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Event handler functions.
-------------------------------------------------------------------------------------------------------------------------------------------------------------

function veafSecurity.executeCommand(eventPos, eventText, bypassSecurity, markerAuthor)
  -- Check if marker has a text and the veafCasMission.keyphrase keyphrase.
  if eventText ~= nil and eventText:lower():find(veafSecurity.Keyphrase) then
    -- Analyse the mark point text and extract the keywords.
    local options = veafSecurity.markTextAnalysis(eventText)

    if options then
      -- Check options commands
      if options.login then
        -- check password
        if not (bypassSecurity or veafSecurity.checkPassword_L1(options.password)) then
          trigger.action.outText(veaf.t("security.password_invalid"), 5)
          return false
        end
        veafSecurity.authenticate()
        return true
      elseif options.logout then
        veafSecurity.logout(true)
        return true
      elseif options.elevate then
        -- The marker carries an author, so this channel can identify who is asking — unlike the
        -- F10 menu, which is why the elevation is offered here and not there.
        local _author = markerAuthor
        local _user = _author and veafRemote and veafRemote.getRemoteUser and veafRemote.getRemoteUser(_author)
        if not _user then
          veaf.loggers.get(veafSecurity.Id):warn(string.format("unknown marker author [%s]", veaf.p(_author)))
          return false
        end
        return veafSecurity.handleElevationRequest(_user, _author, veafSecurity.getUnitNameForPlayer(_author))
      end
    end
  end
  return false
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Analyse the mark text and extract keywords.
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Extract keywords from mark text.
function veafSecurity.markTextAnalysis(text)
  -- Option parameters extracted from the mark text.
  local switch = {}

  switch.login = false

  switch.logout = false

  -- password
  switch.password = nil

  -- Check for correct keywords.
  local pos = text:lower():find(veafSecurity.Keyphrase)
  if not pos then
    return nil
  end

  -- the logout command or the password should follow a space
  local text = text:sub(pos + string.len(veafSecurity.Keyphrase) + 1)

  if text and text:lower() == "logout" then
    switch.logout = true
  elseif text and text:lower() == "elevate" then
    -- Temporarily raise this marker author's group to their own level. Offered on the marker and
    -- on chat, never on the F10 menu: both of those carry an author, and the menu does not.
    switch.elevate = true
  else
    switch.password = text
    switch.login = true
    ----veaf.loggers.get(veafSecurity.Id):trace(string.format("switch.password=[%s]",switch.password))
  end

  return switch
end

--- Return the group id of the unit named `unitName`, or nil.
function veafSecurity.getGroupIdForUnit(unitName)
  if not unitName then
    return nil
  end
  local _unit = Unit and Unit.getByName and Unit.getByName(unitName)
  local _group = _unit and _unit.getGroup and _unit:getGroup()
  return _group and _group.getID and _group:getID() or nil
end

--- Find the unit a named player is currently sitting in, or nil.
---
--- The marker channel identifies its author by **name**, while a group is reached through a
--- *unit*, so the two have to be bridged. `veafRemote.remoteUnitsPilots` is already the registry
--- that maps one to the other, kept up to date by the server hook.
function veafSecurity.getUnitNameForPlayer(playerName)
  if not playerName or not veafRemote or not veafRemote.remoteUnitsPilots then
    return nil
  end
  local _wanted = playerName:lower()
  for _unitName, _pilot in pairs(veafRemote.remoteUnitsPilots) do
    local _name = _pilot and (_pilot.name or _pilot.pilotName)
    if _name and _name:lower() == _wanted then
      return _unitName
    end
  end
  return nil
end

--- Handle an elevation request coming from an **identified** channel (chat or marker).
---
--- Raises the requester's group to the requester's own level for
--- `veafSecurity.ELEVATION_DURATION_SECONDS`. The cap is the point: it lets an admin who shares a
--- group get their commands back without letting anyone borrow a rank they do not hold.
---
--- The residual effect is deliberate and worth stating plainly: for those two minutes, the other
--- occupants of that group act at the requester's level too. That is the old global `/login`
--- reduced to one group, for a bounded time, attributable to a named pilot.
---
--- Returns true when an elevation was granted.
function veafSecurity.handleElevationRequest(pilot, pilotName, unitName)
  if not pilot or not pilot.level or pilot.level <= 0 then
    veaf.loggers.get(veafSecurity.Id):warn(string.format("[%s] has no level, refusing to elevate", veaf.p(pilotName)))
    return false
  end
  local _groupId = veafSecurity.getGroupIdForUnit(unitName)
  if not _groupId then
    veaf.loggers.get(veafSecurity.Id):warn(string.format("cannot resolve a group for unit [%s], refusing to elevate", veaf.p(unitName)))
    return false
  end
  local _granted = veafSecurity.elevateGroupForPilot(_groupId, pilot.level, pilotName)
  if not _granted then
    return false
  end
  veaf.outTextForUnit(
    unitName,
    veaf.t("security.group_elevated", veafSecurity.ELEVATION_DURATION_SECONDS),
    veafSecurity.ELEVATION_DURATION_SECONDS > 10 and 10 or 5
  )
  return true
end

function veafSecurity.logout(withMessage, unitName)
  if not veafSecurity.authenticated and withMessage then
    veaf.outTextForUnit(unitName, veaf.t("security.already_locked"), 5)
    return
  end
  veafSecurity.authenticated = false
  if withMessage then
    veaf.outTextForUnit(unitName, veaf.t("security.locked"), 5)
  end
  veafRadio.refreshRadioMenu()
  if veafSecurity.logoutWatchdog then
    mist.removeFunction(veafSecurity.logoutWatchdog)
  end
end

--- authenticate all radios for a short time
function veafSecurity.authenticate(minutes, unitName)
  -- VMR-095: `minutes` arrives as text a pilot typed after `-auth login`, so it is converted
  -- rather than pattern-matched. The old guard was `not actualMinutes:match("%d+")`, unanchored:
  -- "abc5" passed it and `actualMinutes * 60` then raised. A negative or zero value passed too,
  -- and scheduled the logout in the past — the mission unlocked and relocked without a word.
  local actualMinutes = tonumber(minutes)
  if not actualMinutes or actualMinutes <= 0 then
    if minutes ~= nil then
      veaf.loggers.get(veafSecurity.Id):warn(string.format("unusable auth duration [%s], using the default", veaf.p(minutes)))
    end
    actualMinutes = veafSecurity.authDuration
  end
  if not veafSecurity.authenticated then
    veaf.outTextForUnit(unitName, veaf.t("security.authenticated_minutes", actualMinutes), 15)
    veafSecurity.authenticated = true
    veafRadio.refreshRadioMenu()
    if veafSecurity.logoutWatchdog then
      mist.removeFunction(veafSecurity.logoutWatchdog)
    end
    veafSecurity.logoutWatchdog = mist.scheduleFunction(veafSecurity.logout, { true }, timer.getTime() + actualMinutes * 60)
  end
end

function veafSecurity._checkPassword(password, level)
  if password == nil then
    return false
  end
  veaf.loggers.get(veafSecurity.Id):debug("checkPassword(password = <redacted>)")
  local hash = sha1.hex(password)
  veaf.loggers.get(veafSecurity.Id):trace(string.format("hash = [%s]", hash))
  if level[hash] ~= nil then
    veaf.loggers.get(veafSecurity.Id):debug("user authenticated")
    return true
  else
    veaf.loggers.get(veafSecurity.Id):debug("user not found")
    return false
  end
end

function veafSecurity.checkPassword_L0(password)
  return veafSecurity.isSecurityDisabled() or veafSecurity._checkPassword(password, veafSecurity.password_L0)
end

function veafSecurity.checkPassword_L1(password)
  return veafSecurity.isSecurityDisabled()
    or veafSecurity._checkPassword(password, veafSecurity.password_L1)
    or veafSecurity._checkPassword(password, veafSecurity.password_L0)
end

function veafSecurity.checkPassword_L9(password)
  return veafSecurity.isSecurityDisabled()
    or veafSecurity._checkPassword(password, veafSecurity.password_L9)
    or veafSecurity._checkPassword(password, veafSecurity.password_L1)
    or veafSecurity._checkPassword(password, veafSecurity.password_L0)
end

function veafSecurity.checkPassword_MM(password)
  return veafSecurity.isSecurityDisabled() or veafSecurity._checkPassword(password, veafSecurity.password_MM)
end

function veafSecurity.getMarkerSecurityLevel(markId)
  veaf.loggers.get(veafSecurity.Id):trace(string.format("veafSecurity.getMarkerSecurityLevel([%s])", veaf.p(markId)))
  local _author = nil
  for _, panel in pairs(world.getMarkPanels()) do
    veaf.loggers.get(veafSecurity.Id):trace("panel=%s", veaf.lp(panel))
    if panel.idx == markId then
      _author = panel.author
    end
  end
  if _author == nil then
    -- markId may actually be the username if called from veafRemote - yes I know it's ugly
    _author = markId
  end
  veaf.loggers.get(veafSecurity.Id):trace("_author=%s", _author)
  local _user = veafRemote.getRemoteUser(_author)
  veaf.loggers.get(veafSecurity.Id):trace(string.format("_user = [%s]", veaf.p(_user)))
  if _user then
    return _user.level
  end
  return -1
end

-- REVIEW-SECURITY-LAYER ticket 01. These three used to open with
--
--     if veafSecurity.isAuthenticated() then return true end
--
-- a module-level boolean, so one `/login` granted every secured command to **every player on the
-- server** for `authDuration` — and while anyone was logged in the per-pilot path below was never
-- reached, the blunt mechanism disabling the precise one.
--
-- Removing it does not remove password access: `checkPassword_Lx` is still in the condition, so
-- "your own level suffices OR you give the password" holds. What went is the convenience of one
-- login covering everyone, replaced by an elevation scoped to a single group for two minutes
-- (`elevateGroupForPilot`). `veaf.SecurityDisabled` still short-circuits everything, because it is a
-- mission-wide switch and not an authentication path.
function veafSecurity.checkSecurity_L0(password, markId)
  if veafSecurity.getMarkerSecurityLevel(markId) < veafSecurity.LEVEL_L0 and not veafSecurity.checkPassword_L0(password) then
    veaf.loggers.get(veafSecurity.Id):warn("You have to give the correct L0 password to do this")
    trigger.action.outText(veaf.t("security.use_password", "L0"), 5)
    return false
  end
  return true
end

function veafSecurity.checkSecurity_L1(password, markId)
  if veafSecurity.getMarkerSecurityLevel(markId) < veafSecurity.LEVEL_L1 and not veafSecurity.checkPassword_L1(password) then
    veaf.loggers.get(veafSecurity.Id):warn("You have to give the correct L1 password to do this")
    trigger.action.outText(veaf.t("security.use_password", "L1"), 5)
    return false
  end
  return true
end

function veafSecurity.checkSecurity_L9(password, markId)
  if veafSecurity.getMarkerSecurityLevel(markId) < veafSecurity.LEVEL_L9 and not veafSecurity.checkPassword_L9(password) then
    veaf.loggers.get(veafSecurity.Id):warn("You have to give the correct L9 password to do this")
    trigger.action.outText(veaf.t("security.use_password", "L9"), 5)
    return false
  end
  return true
end

function veafSecurity.checkSecurity_MM(password)
  if not veafSecurity.checkPassword_MM(password) then
    veaf.loggers.get(veafSecurity.Id):warn("You have to give the correct Mission Master password to do this")
    trigger.action.outText(veaf.t("security.use_password", "MM"), 5)
    return false
  end
  return true
end

function veafSecurity.isAuthenticated()
  return veafSecurity.authenticated or veafSecurity.isSecurityDisabled()
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Per-group security level (REVIEW-SECURITY-LAYER ticket 01)
--
-- DCS offers no per-unit menu API: `missionCommands` posts to all, to a coalition, or to a
-- **group**, and the callback receives only the argument fixed at registration time. So a secured
-- F10 command cannot know which occupant clicked it, and the group is the finest identity
-- available on that channel.
--
-- The level applied to a group is therefore the **minimum** of its occupants. Taking the maximum
-- would reproduce the very defect this lot fixes — one player acting with another's rights —
-- merely at group scale instead of server scale. The marker channel keeps a finer grain: it
-- carries an author, so it resolves to one player.
--
-- The cost of the minimum is real: an admin sharing a four-slot group loses their admin commands
-- in the menu. Hence the elevation below, which David asked for: an identified request raises the
-- group to the requester's **own** level for two minutes, never higher.
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- How long a temporary elevation lasts, in seconds.
veafSecurity.ELEVATION_DURATION_SECONDS = 120

--- Active elevations, keyed by group id: `{ level = number, expiresAt = number, pilot = string }`.
veafSecurity.groupElevations = {}

--- Return the security level of the pilot flying `unitName`, or nil when unknown.
function veafSecurity.getPilotLevelForUnit(unitName)
  if not unitName then
    return nil
  end
  local _user = veafRemote and veafRemote.getRemoteUserFromUnit and veafRemote.getRemoteUserFromUnit(unitName)
  return _user and _user.level or nil
end

--- Return the unit names currently occupied by a player in `groupId`.
function veafSecurity.getGroupOccupantUnitNames(groupId)
  local _names = {}
  if not groupId then
    return _names
  end
  local _group = Group.getByID and Group.getByID(groupId)
  if not _group or not _group.getUnits then
    return _names
  end
  for _, _unit in pairs(_group:getUnits() or {}) do
    -- Only slots with a human in them matter: an AI wingman has no security level and must not
    -- drag the group to zero.
    if _unit and _unit.getPlayerName and _unit:getPlayerName() and _unit.getName then
      table.insert(_names, _unit:getName())
    end
  end
  return _names
end

--- Return a group's intrinsic level: the **lowest** level among its human occupants.
---
--- An occupant with no known level yields 0, which denies everything — an unlisted player must
--- not be silently ignored, or a group could be raised by leaving out the people in it. An empty
--- group is 0 for the same reason.
function veafSecurity.getGroupLevel(groupId)
  local _names = veafSecurity.getGroupOccupantUnitNames(groupId)
  if #_names == 0 then
    return 0
  end
  local _lowest = nil
  for _, _unitName in ipairs(_names) do
    local _level = veafSecurity.getPilotLevelForUnit(_unitName) or 0
    if _lowest == nil or _level < _lowest then
      _lowest = _level
    end
  end
  return _lowest or 0
end

--- Grant `groupId` a temporary elevation to `level`, attributed to `pilotName`.
function veafSecurity.elevateGroup(groupId, level, pilotName)
  if not groupId or not level then
    return nil
  end
  veafSecurity.groupElevations[groupId] = {
    level = level,
    expiresAt = timer.getTime() + veafSecurity.ELEVATION_DURATION_SECONDS,
    pilot = pilotName,
  }
  veaf.loggers.get(veafSecurity.Id):info(
    string.format(
      "group %s elevated to level %s for %s seconds by [%s]",
      veaf.p(groupId),
      veaf.p(level),
      veaf.p(veafSecurity.ELEVATION_DURATION_SECONDS),
      veaf.p(pilotName)
    )
  )
  return level
end

--- Elevate `groupId` on behalf of a pilot, **capped at that pilot's own level**.
---
--- This cap is the whole safety of the mechanism. Without it, any occupant could raise the group
--- to its most privileged member's level and act with rights they were never granted — the bug
--- this lot exists to remove, rebuilt as a feature.
function veafSecurity.elevateGroupForPilot(groupId, requesterLevel, pilotName)
  if not requesterLevel or requesterLevel <= 0 then
    veaf.loggers.get(veafSecurity.Id):warn(string.format("[%s] has no level, refusing to elevate", veaf.p(pilotName)))
    return nil
  end
  return veafSecurity.elevateGroup(groupId, requesterLevel, pilotName)
end

--- Return the level a group acts with right now: its active elevation if any, else its minimum.
function veafSecurity.getEffectiveGroupLevel(groupId)
  local _elevation = veafSecurity.groupElevations[groupId]
  if _elevation then
    if timer.getTime() < _elevation.expiresAt then
      return _elevation.level
    end
    -- Expired: drop it so the table cannot grow without bound over a long mission.
    veafSecurity.groupElevations[groupId] = nil
  end
  return veafSecurity.getGroupLevel(groupId)
end

function veafSecurity.initialize()
  -- OPEN, necessarily: this handler *is* the login command. Gating it behind a level would
  -- mean needing to be authenticated in order to authenticate.
  veafCommands.registerCommandHandler(function(pos, event, bypass, fromMarker, groups, route)
    -- The author travels with the event; it is what lets the elevation verb identify its
    -- requester on this channel (REVIEW-SECURITY-LAYER ticket 01).
    return veafSecurity.executeCommand(pos, event.text, bypass, event and event.author)
  end, veafCommands.PRIORITY_SECURITY, "OPEN")
  veafRemote.registerRemoteModule("secu", veafSecurity.executeCommandFromRemote)
  -- Read here rather than at module load: the mission config has been applied by now, so this is
  -- where the deprecated spelling can actually be seen (and warned about).
  veafSecurity.authenticated = veafSecurity.isSecurityDisabled()
end

veaf.loggers.get(veafSecurity.Id):info(veaf.loggers.get(veafSecurity.Id):getVersionInfo())

veaf.registerModule(veafSecurity.Id, veafSecurity.initialize, { enable = true }, 20)
