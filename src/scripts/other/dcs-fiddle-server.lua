-- Note: This is a modified version of the DCS Fiddle Server to add authentication for public servers.
-- All credit goes to the original authors of DCS Fiddle: JonathanTurnock and john681611
-- Base: omltcat/dcs-lua-runner (adds HTTP Basic auth + a local bypass).
-- License: MIT (https://github.com/JonathanTurnock/dcsfiddle)

-- START OF VEAF CHANGES
---@diagnostic disable -- third-party file; suppress all LuaLS diagnostics
--[[
    VEAF: Changes to the original script:
    - a way to find out the sanitized modules from the server config (veaf.sanitizedModule);
    - a per-session Basic-auth password, generated at launch and written to a file the harness client
      reads, with the local bypass turned off (FIX-SECREV2-EXPIRED-DEFERRALS ticket 02 / VMR-013).
]]
veaf = {}
function veaf.sanitizedModule(moduleName)
  local result = nil
  if not result and SERVER_CONFIG and SERVER_CONFIG.getModule then
    result = SERVER_CONFIG.getModule(moduleName)
  end
  return result
end

local require = veaf.sanitizedModule("require") or require
local package = veaf.sanitizedModule("package") or package
-- END OF VEAF CHANGES

FIDDLE = {}
--=============================================================================
-- Congiguration
--=============================================================================

-- By default, mission env is on port 12080 and GUI env on 12081 (mission +1)
-- This is what access from https://dcsfiddle.pages.dev/ uses.

FIDDLE.PORT = 12080             -- keep this at 12080 if you also want to use the DCS Fiddle website.
FIDDLE.BIND_IP = '127.0.0.1'    -- Use '0.0.0.0' for remote access, default is '127.0.0.1'
FIDDLE.AUTH = true              -- set to true to enable basic auth, recommended for public servers.
FIDDLE.USERNAME = 'veaf'        -- username for basic auth
-- VEAF (FIX-SECREV2 / VMR-013): PASSWORD is a placeholder — it is overwritten at launch with a fresh
-- per-session secret (see the "VEAF token" section below), so nothing usable is committed here.
FIDDLE.PASSWORD = 'placeholder-overwritten-per-session'
-- VEAF (FIX-SECREV2 / VMR-013): the local bypass is OFF. It let any web page a developer visited while
-- DCS was running reach this port without auth — it keys off the (spoofable) Host header, so "loopback
-- only" was no protection: the browser is already on loopback. The harness client authenticates with
-- the per-session password instead. Leaving it off also means the upstream DCS Fiddle web UI, which
-- relied on the bypass, is unsupported by this build.
FIDDLE.BYPASS_LOCAL = false

_G.FIDDLE_LOG_LEVEL = _G.FIDDLE_LOG_LEVEL or 0    -- 0 = debug, 1 = info, 2 = errors only

--=============================================================================
-- End of Configuration
--=============================================================================

--=============================================================================
-- VEAF token (FIX-SECREV2 / VMR-013)
--
-- With BYPASS_LOCAL off, every request needs Basic auth. So the client can authenticate without a
-- human configuring anything, the hook environment generates a fresh password at launch and writes it
-- to a fixed file; the harness client (which shares the filesystem) reads it. The mission environment
-- reads the same file so both ports check the same password. A browser cannot read a local file, which
-- is exactly why this closes the exposure the bypass left open.
--=============================================================================

-- Fixed path in the user's home, not under a Saved Games write directory: a workstation can carry
-- several write dirs (one per aircraft profile) and only the running DCS knows which is live, so a
-- writedir-relative path would leave the client guessing. The Python client computes the same path
-- from the home directory. Falls back to the write dir when os.getenv is unavailable.
function veaf.tokenFilePath()
  local home = os and os.getenv and os.getenv("USERPROFILE")
  if home and home ~= "" then
    return home .. "\\dcs-fiddle-token.txt"
  end
  return lfs.writedir() .. "dcs-fiddle-token.txt"
end

-- A 40-hex-character secret. Its strength is not the point — the file is unreadable to a browser, and
-- that is what it protects against — but it is seeded from time so it differs per launch.
function veaf.generateToken()
  math.randomseed(os.time() + math.floor((os.clock() or 0) * 1000000))
  local chars = "0123456789abcdef"
  local out = {}
  for i = 1, 40 do
    local n = math.random(1, #chars)
    out[i] = string.sub(chars, n, n)
  end
  return table.concat(out)
end

function veaf.writeToken(tok)
  local f = io.open(veaf.tokenFilePath(), "w")
  if not f then
    return false
  end
  f:write(tok)
  f:close()
  return true
end

function veaf.readToken()
  local f = io.open(veaf.tokenFilePath(), "r")
  if not f then
    return nil
  end
  local tok = f:read("*a")
  f:close()
  if not tok then
    return nil
  end
  return (tok:gsub("%s+$", ""))
end



-------------------------------------------------------------------------------
-- JSON Module
-------------------------------------------------------------------------------
--[[
Custom JSON Serialization Module that handles DCS' usage of integers as table keys such as {[1]=1, ["name"]="Enfield11", [2]=1, [3]=1} which is not valid json

This is handled by encoding tables with mixed key types as objects so the above example would be

{
  "_1": 1,
  "_2": 1,
  "name": "Enfield11",
  "_3": 1
}

Anything that is clearly a table is still converted to a table

]]--

fiddlejson = { _version = "0.2.0" }

-------------------------------------------------------------------------------
-- Encode
-------------------------------------------------------------------------------

local encode

local escape_char_map = {
    [ "\\" ] = "\\",
    [ "\"" ] = "\"",
    [ "\b" ] = "b",
    [ "\f" ] = "f",
    [ "\n" ] = "n",
    [ "\r" ] = "r",
    [ "\t" ] = "t",
}

local escape_char_map_inv = { [ "/" ] = "/" }
for k, v in pairs(escape_char_map) do
    escape_char_map_inv[v] = k
end


local function escape_char(c)
    return "\\" .. (escape_char_map[c] or string.format("u%04x", c:byte()))
end


local function encode_nil(val)
    return "null"
end

--- Checks if a given table is an array.
-- The function verifies that all keys are numeric and sequential starting from 1.
-- @param val Table to be checked.
-- @return boolean Returns true if the table is an array, otherwise false.
local function is_table_array(val)
    -- Check if the first element of the table is not nil or the table is empty.
    -- These are two signs that the table might be an array.
    if rawget(val, 1) ~= nil or next(val) == nil then
        -- Extract all numeric keys and sort them.
        local keys = {}
        for k in pairs(val) do
            if type(k) == "number" then
                table.insert(keys, k)
            else
                -- If any key is not a number, the table is not an array.
                return false
            end
        end
        table.sort(keys)

        -- Check the sorted keys to see if they form a continuous sequence starting from 1.
        for i, k in ipairs(keys) do
            if i ~= k then
                return false
            end
        end

        -- If all keys were numeric and in sequence, then the table is an array.
        return true
    else
        -- If the first element of the table is nil and the table isn't empty,
        -- then it's not an array.
        return false
    end
end


local function encode_table(val, stack)
    local res = {}
    stack = stack or {}

    -- Circular reference?
    if stack[val] then return '"<error: circular reference>"' end

    stack[val] = true



    if is_table_array(val) then
        -- Treat as array -- check keys are valid and it is not sparse
        -- Encode
        for i, v in ipairs(val) do
            table.insert(res, encode(v, stack))
        end
        stack[val] = nil
        return "[" .. table.concat(res, ",") .. "]"

    else
        -- Treat as an object
        for k, v in pairs(val) do
            if type(k) ~= "string" then
                table.insert(res, encode("_"..k, stack) .. ":" .. encode(v, stack))
            else
                table.insert(res, encode(k, stack) .. ":" .. encode(v, stack))
            end
        end
        stack[val] = nil
        return "{" .. table.concat(res, ",") .. "}"
    end
end


local function encode_string(val)
    return '"' .. val:gsub('[%z\1-\31\\"]', escape_char) .. '"'
end


local function encode_number(val)
    -- Check for NaN, -inf and inf
    if val ~= val or val <= -math.huge or val >= math.huge then
        error("unexpected number value '" .. tostring(val) .. "'")
    end
    return string.format("%.14g", val)
end

local function encode_function(val)
    return string.format('"<%s>"', tostring(val))
end

local type_func_map = {
    [ "nil"     ] = encode_nil,
    [ "table"   ] = encode_table,
    [ "string"  ] = encode_string,
    [ "number"  ] = encode_number,
    [ "boolean" ] = tostring,
    [ "function"] = encode_function,
}


encode = function(val, stack)
    local t = type(val)
    local f = type_func_map[t]
    if f then
        return f(val, stack)
    end
    error("unexpected type '" .. t .. "'")
end


function fiddlejson.encode(val)
    return ( encode(val) )
end


-------------------------------------------------------------------------------
-- Decode
-------------------------------------------------------------------------------

local parse

local function create_set(...)
    local res = {}
    for i = 1, select("#", ...) do
        res[ select(i, ...) ] = true
    end
    return res
end

local space_chars   = create_set(" ", "\t", "\r", "\n")
local delim_chars   = create_set(" ", "\t", "\r", "\n", "]", "}", ",")
local escape_chars  = create_set("\\", "/", '"', "b", "f", "n", "r", "t", "u")
local literals      = create_set("true", "false", "null")

local literal_map = {
    [ "true"  ] = true,
    [ "false" ] = false,
    [ "null"  ] = nil,
}


local function next_char(str, idx, set, negate)
    for i = idx, #str do
        if set[str:sub(i, i)] ~= negate then
            return i
        end
    end
    return #str + 1
end


local function decode_error(str, idx, msg)
    local line_count = 1
    local col_count = 1
    for i = 1, idx - 1 do
        col_count = col_count + 1
        if str:sub(i, i) == "\n" then
            line_count = line_count + 1
            col_count = 1
        end
    end
    error( string.format("%s at line %d col %d", msg, line_count, col_count) )
end


local function codepoint_to_utf8(n)
    -- http://scripts.sil.org/cms/scripts/page.php?site_id=nrsi&id=iws-appendixa
    local f = math.floor
    if n <= 0x7f then
        return string.char(n)
    elseif n <= 0x7ff then
        return string.char(f(n / 64) + 192, n % 64 + 128)
    elseif n <= 0xffff then
        return string.char(f(n / 4096) + 224, f(n % 4096 / 64) + 128, n % 64 + 128)
    elseif n <= 0x10ffff then
        return string.char(f(n / 262144) + 240, f(n % 262144 / 4096) + 128,
                f(n % 4096 / 64) + 128, n % 64 + 128)
    end
    error( string.format("invalid unicode codepoint '%x'", n) )
end


local function parse_unicode_escape(s)
    local n1 = tonumber( s:sub(1, 4),  16 )
    local n2 = tonumber( s:sub(7, 10), 16 )
    -- Surrogate pair?
    if n2 then
        return codepoint_to_utf8((n1 - 0xd800) * 0x400 + (n2 - 0xdc00) + 0x10000)
    else
        return codepoint_to_utf8(n1)
    end
end


local function parse_string(str, i)
    local res = ""
    local j = i + 1
    local k = j

    while j <= #str do
        local x = str:byte(j)

        if x < 32 then
            decode_error(str, j, "control character in string")

        elseif x == 92 then -- `\`: Escape
            res = res .. str:sub(k, j - 1)
            j = j + 1
            local c = str:sub(j, j)
            if c == "u" then
                local hex = str:match("^[dD][89aAbB]%x%x\\u%x%x%x%x", j + 1)
                        or str:match("^%x%x%x%x", j + 1)
                        or decode_error(str, j - 1, "invalid unicode escape in string")
                res = res .. parse_unicode_escape(hex)
                j = j + #hex
            else
                if not escape_chars[c] then
                    decode_error(str, j - 1, "invalid escape char '" .. c .. "' in string")
                end
                res = res .. escape_char_map_inv[c]
            end
            k = j + 1

        elseif x == 34 then -- `"`: End of string
            res = res .. str:sub(k, j - 1)
            return res, j + 1
        end

        j = j + 1
    end

    decode_error(str, i, "expected closing quote for string")
end


local function parse_number(str, i)
    local x = next_char(str, i, delim_chars)
    local s = str:sub(i, x - 1)
    local n = tonumber(s)
    if not n then
        decode_error(str, i, "invalid number '" .. s .. "'")
    end
    return n, x
end


local function parse_literal(str, i)
    local x = next_char(str, i, delim_chars)
    local word = str:sub(i, x - 1)
    if not literals[word] then
        decode_error(str, i, "invalid literal '" .. word .. "'")
    end
    return literal_map[word], x
end


local function parse_array(str, i)
    local res = {}
    local n = 1
    i = i + 1
    while 1 do
        local x
        i = next_char(str, i, space_chars, true)
        -- Empty / end of array?
        if str:sub(i, i) == "]" then
            i = i + 1
            break
        end
        -- Read token
        x, i = parse(str, i)
        res[n] = x
        n = n + 1
        -- Next token
        i = next_char(str, i, space_chars, true)
        local chr = str:sub(i, i)
        i = i + 1
        if chr == "]" then break end
        if chr ~= "," then decode_error(str, i, "expected ']' or ','") end
    end
    return res, i
end

local function set_table(res, key, val)
    -- Check if the key starts with an underscore
    if string.sub(key, 1, 1) == "_" then
        -- Remove the underscore and try to convert the rest to a number
        local numKey = tonumber(string.sub(key, 2))

        -- If the result is not nil, meaning the conversion was successful
        if numKey then
            -- Update the table with the number key instead of the string key
            res[numKey] = val
        end
    else
        -- If the key does not start with an underscore, just use it as is
        res[key] = val
    end
end

local function parse_object(str, i)
    local res = {}
    i = i + 1
    while 1 do
        local key, val
        i = next_char(str, i, space_chars, true)
        -- Empty / end of object?
        if str:sub(i, i) == "}" then
            i = i + 1
            break
        end
        -- Read key
        if str:sub(i, i) ~= '"' then
            decode_error(str, i, "expected string for key")
        end
        key, i = parse(str, i)
        -- Read ':' delimiter
        i = next_char(str, i, space_chars, true)
        if str:sub(i, i) ~= ":" then
            decode_error(str, i, "expected ':' after key")
        end
        i = next_char(str, i + 1, space_chars, true)
        -- Read value
        val, i = parse(str, i)
        -- Set
        --res[key] = val
        set_table(res, key, val)
        -- Next token
        i = next_char(str, i, space_chars, true)
        local chr = str:sub(i, i)
        i = i + 1
        if chr == "}" then break end
        if chr ~= "," then decode_error(str, i, "expected '}' or ','") end
    end
    return res, i
end


local char_func_map = {
    [ '"' ] = parse_string,
    [ "0" ] = parse_number,
    [ "1" ] = parse_number,
    [ "2" ] = parse_number,
    [ "3" ] = parse_number,
    [ "4" ] = parse_number,
    [ "5" ] = parse_number,
    [ "6" ] = parse_number,
    [ "7" ] = parse_number,
    [ "8" ] = parse_number,
    [ "9" ] = parse_number,
    [ "-" ] = parse_number,
    [ "t" ] = parse_literal,
    [ "f" ] = parse_literal,
    [ "n" ] = parse_literal,
    [ "[" ] = parse_array,
    [ "{" ] = parse_object,
}


parse = function(str, idx)
    local chr = str:sub(idx, idx)
    local f = char_func_map[chr]
    if f then
        return f(str, idx)
    end
    decode_error(str, idx, "unexpected character '" .. chr .. "'")
end


function fiddlejson.decode(str)
    if type(str) ~= "string" then
        error("expected argument of type string, got " .. type(str))
    end
    local res, idx = parse(str, next_char(str, 1, space_chars, true))
    idx = next_char(str, idx, space_chars, true)
    if idx <= #str then
        decode_error(str, idx, "trailing garbage")
    end
    return res
end

--[[
 base64 -- v1.5.3 public domain Lua base64 encoder/decoder
 no warranty implied; use at your own risk
 Needs bit32.extract function. If not present it's implemented using BitOp
 or Lua 5.3 native bit operators. For Lua 5.1 fallbacks to pure Lua
 implementation inspired by Rici Lake's post:
   http://ricilake.blogspot.co.uk/2007/10/iterating-bits-in-lua.html
 author: Ilya Kolbin (iskolbin@gmail.com)
 url: github.com/iskolbin/lbase64
 COMPATIBILITY
 Lua 5.1+, LuaJIT
 LICENSE
 See end of file for license information.
--]]

local base64 = {}

-- local extract = _G.bit32 and _G.bit32.extract -- Lua 5.2/Lua 5.3 in compatibility mode
-- if not extract then
--     if _G.bit then
--         -- LuaJIT
--         local shl, shr, band = _G.bit.lshift, _G.bit.rshift, _G.bit.band
--         extract = function(v, from, width)
--             return band(shr(v, from), shl(1, width) - 1)
--         end
--     elseif _G._VERSION == "Lua 5.1" then
--         extract = function(v, from, width)
--             local w = 0
--             local flag = 2 ^ from
--             for i = 0, width - 1 do
--                 local flag2 = flag + flag
--                 if v % flag2 >= flag then
--                     w = w + 2 ^ i
--                 end
--                 flag = flag2
--             end
--             return w
--         end
--     else
--         -- Lua 5.3+
--         extract = load [[return function( v, from, width )
-- 			return ( v >> from ) & ((1 << width) - 1)
-- 		end]]()
--     end
-- end

local extract = function(v, from, width)
    local w = 0
    local flag = 2 ^ from
    for i = 0, width - 1 do
        local flag2 = flag + flag
        if v % flag2 >= flag then
            w = w + 2 ^ i
        end
        flag = flag2
    end
    return w
end

function base64.makeencoder(s62, s63, spad)
    local encoder = {}
    for b64code, char in pairs { [0] = 'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J',
                                 'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y',
                                 'Z', 'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n',
                                 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z', '0', '1', '2',
                                 '3', '4', '5', '6', '7', '8', '9', s62 or '+', s63 or '/', spad or '=' } do
        encoder[b64code] = char:byte()
    end
    return encoder
end

function base64.makedecoder(s62, s63, spad)
    local decoder = {}
    for b64code, charcode in pairs(base64.makeencoder(s62, s63, spad)) do
        decoder[charcode] = b64code
    end
    return decoder
end

local DEFAULT_ENCODER = base64.makeencoder()
local DEFAULT_DECODER = base64.makedecoder()

local char, concat = string.char, table.concat

function base64.encode(str, encoder, usecaching)
    encoder = encoder or DEFAULT_ENCODER
    local t, k, n = {}, 1, #str
    local lastn = n % 3
    local cache = {}
    for i = 1, n - lastn, 3 do
        local a, b, c = str:byte(i, i + 2)
        local v = a * 0x10000 + b * 0x100 + c
        local s
        if usecaching then
            s = cache[v]
            if not s then
                s = char(encoder[extract(v, 18, 6)], encoder[extract(v, 12, 6)], encoder[extract(v, 6, 6)], encoder[extract(v, 0, 6)])
                cache[v] = s
            end
        else
            s = char(encoder[extract(v, 18, 6)], encoder[extract(v, 12, 6)], encoder[extract(v, 6, 6)], encoder[extract(v, 0, 6)])
        end
        t[k] = s
        k = k + 1
    end
    if lastn == 2 then
        local a, b = str:byte(n - 1, n)
        local v = a * 0x10000 + b * 0x100
        t[k] = char(encoder[extract(v, 18, 6)], encoder[extract(v, 12, 6)], encoder[extract(v, 6, 6)], encoder[64])
    elseif lastn == 1 then
        local v = str:byte(n) * 0x10000
        t[k] = char(encoder[extract(v, 18, 6)], encoder[extract(v, 12, 6)], encoder[64], encoder[64])
    end
    return concat(t)
end

function base64.decode(b64, decoder, usecaching)
    decoder = decoder or DEFAULT_DECODER
    local pattern = '[^%w%+%/%=]'
    if decoder then
        local s62, s63
        for charcode, b64code in pairs(decoder) do
            if b64code == 62 then
                s62 = charcode
            elseif b64code == 63 then
                s63 = charcode
            end
        end
        pattern = ('[^%%w%%%s%%%s%%=]'):format(char(s62), char(s63))
    end
    b64 = b64:gsub(pattern, '')
    local cache = usecaching and {}
    local t, k = {}, 1
    local n = #b64
    local padding = b64:sub(-2) == '==' and 2 or b64:sub(-1) == '=' and 1 or 0
    for i = 1, padding > 0 and n - 4 or n, 4 do
        local a, b, c, d = b64:byte(i, i + 3)
        local s
        if usecaching then
            local v0 = a * 0x1000000 + b * 0x10000 + c * 0x100 + d
            s = cache[v0]
            if not s then
                local v = decoder[a] * 0x40000 + decoder[b] * 0x1000 + decoder[c] * 0x40 + decoder[d]
                s = char(extract(v, 16, 8), extract(v, 8, 8), extract(v, 0, 8))
                cache[v0] = s
            end
        else
            local v = decoder[a] * 0x40000 + decoder[b] * 0x1000 + decoder[c] * 0x40 + decoder[d]
            s = char(extract(v, 16, 8), extract(v, 8, 8), extract(v, 0, 8))
        end
        t[k] = s
        k = k + 1
    end
    if padding == 1 then
        local a, b, c = b64:byte(n - 3, n - 1)
        local v = decoder[a] * 0x40000 + decoder[b] * 0x1000 + decoder[c] * 0x40
        t[k] = char(extract(v, 16, 8), extract(v, 8, 8))
    elseif padding == 2 then
        local a, b = b64:byte(n - 3, n - 2)
        local v = decoder[a] * 0x40000 + decoder[b] * 0x1000
        t[k] = char(extract(v, 16, 8))
    end
    return concat(t)
end

--[[
------------------------------------------------------------------------------
This software is available under 2 licenses -- choose whichever you prefer.
------------------------------------------------------------------------------
ALTERNATIVE A - MIT License
Copyright (c) 2018 Ilya Kolbin
Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
of the Software, and to permit persons to whom the Software is furnished to do
so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
------------------------------------------------------------------------------
ALTERNATIVE B - Public Domain (www.unlicense.org)
This is free and unencumbered software released into the public domain.
Anyone is free to copy, modify, publish, use, compile, sell, or distribute this
software, either in source code form or as a compiled binary, for any purpose,
commercial or non-commercial, and by any means.
In jurisdictions that recognize copyright laws, the author or authors of this
software dedicate any and all copyright interest in the software to the public
domain. We make this dedication for the benefit of the public at large and to
the detriment of our heirs and successors. We intend this dedication to be an
overt act of relinquishment in perpetuity of all present and future rights to
this software under copyright law.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
------------------------------------------------------------------------------
--]]

local function dumpt(t)
    if type(t) == 'table' then
        local s = '{ '
        for k, v in pairs(t) do
            if type(k) ~= 'number' then
                k = '"' .. k .. '"'
            end
            s = s .. '[' .. k .. '] = ' .. dumpt(v) .. ','
        end
        return s .. '} '
    else
        return tostring(t)
    end
end


------------------------------------------------------------------------------------------------------------------------
--- Logger
------------------------------------------------------------------------------------------------------------------------

local __debug = function(message)
    if FIDDLE_LOG_LEVEL > 0 then return end
    message = '[dcs-fiddle-server] - ' .. message
    if (log and log.debug) then
        log.debug(message)
    else
        print('DEBUG - ' .. message)
    end
end

local __info = function(message)
    if FIDDLE_LOG_LEVEL > 1 then return end
    message = '[dcs-fiddle-server] - ' .. message
    if (log and log.info) then
        log.info(message)
    else
        print('INFO - ' .. message)
    end
end

local __error = function(message)
    message = '[dcs-fiddle-server] - ' .. message
    if (log and log.error) then
        log.error(message)
    else
        print('ERROR - ' .. message)
    end
end

------------------------------------------------------------------------------------------------------------------------
--- DCS Instruction Handler
------------------------------------------------------------------------------------------------------------------------

local IS_DCS = false

------------------------------------------------------------------------------------------------------------------------
--- Takes a LUA string, executes it and returns the result as a JSON string
---@param env string Environment to run the lua string within
---
local function handle_request(luastring, env)
    __info("[handle_request] - Handling request to execute string in " .. env)

    if (env ~= "default") then
        __info("[handle_request] - Executing string via dostring_in")
        local str, err = net.dostring_in(env, luastring)
        if (err) then
            __error(string.format("Error while executing string in %s\n%s", env, str))
        end
        return str
    else
        __info("[handle_request] - Loading LUA String...")
        local loaded = assert(loadstring(luastring))

        __info("[handle_request] - Executing LUA String...")
        local result = loaded()

        __info("[handle_request] - Processing result...")
        return result
    end
end
------------------------------------------------------------------------------------------------------------------------
--- Url
--- https://developer.mozilla.org/en-US/docs/Learn/Common_questions/What_is_a_URL
------------------------------------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------------------------------------
--- Parses the given url and returns a URL table
---
--- `{ parameters={sort="asc", size=20}, path="/employees" }`
---
--- @param original_url string - The Original Request URL i.e. `/employees?sort=asc&size=20`
--- @return string, table? - Returns the path part alongside a table of parsed parameters
---
local function parse_url(original_url)
    local resource_path, parameters = original_url:match('(.+)?(.*)')
    if (parameters) then
        local params = {}
        for parameter in string.gmatch(parameters, "[^&]+") do
            local name, value = parameter:match('(.+)=(.+)')
            params[name] = value
        end

        return resource_path, params
    end
    return original_url
end

------------------------------------------------------------------------------------------------------------------------
--- HTTP Receiver
------------------------------------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------------------------------------
--- Reads HTTP Message from the given connection
---
--- @see https://developer.mozilla.org/en-US/docs/Web/HTTP/Messages
--- @see https://lunarmodules.github.io/luasocket/tcp.html#accept
--- @param client TCPSocket LUA Socket Lib Client
--- @return table?, number? Request - table containing method, original_url, protocol, path, parameters, body, headers. Optionally returns a second item representing an error_code from the match_headers failing
local function receive_http(client)
    local request = {}
    __debug("receiving start-line")
    local received, err = client:receive("*l")

    if err or not received then
        __error("Failed to get start-line due to " .. err)
        return
    end

    __debug("parsing start-line")
    local method, original_url, protocol = string.match(received, "(%S+) (%S+) (%S+)")
    request.method = method
    request.original_url = original_url
    request.protocol = protocol

    __debug("parsing url")
    local path, parameters = parse_url(original_url)
    request.path = path
    request.parameters = parameters

    request.authOK = false
    if FIDDLE.AUTH then
        __debug("parsing headers for auth")
        local headers = {}
        while true do
            local line = client:receive()
            if not line or line == "" then break end
            local name, value = line:match("^([^:]+):%s*(.*)$")
            headers[name] = value
        end
        local auth_header = headers["Authorization"]
        local host_header = headers['X-Forwarded-Host'] or headers["Host"]
        if FIDDLE.BYPASS_LOCAL and (host_header == '127.0.0.1:12080' or host_header == '127.0.0.1:12081') then
            request.authOK = true
        elseif auth_header then
            local encoded_username_password = auth_header:match("^Basic%s+(.*)$")
            if encoded_username_password then
                local decoded_username_password = base64.decode(encoded_username_password)
                local username, password = decoded_username_password:match("^(.*):(.*)$")
                -- __info(decoded_username_password)
                if username == FIDDLE.USERNAME and password == FIDDLE.PASSWORD then
                    -- __info("Auth Passed")
                    request.authOK = true
                end
            end
        end
    else
        request.authOK = true
    end

    __debug("request completed")
    return request
end

------------------------------------------------------------------------------------------------------------------------
--- HTTP Sender
------------------------------------------------------------------------------------------------------------------------

local EMPTY_LINE = ""
local CRLF = "\r\n"

local status_text = {
    [100] = "Continue",
    [101] = "Switching protocols",
    [102] = "Processing",
    [103] = "Early Hints",
    [200] = "OK",
    [201] = "Created",
    [202] = "Accepted",
    [203] = "Non-Authoritative Information",
    [204] = "No Content",
    [205] = "Reset Content",
    [206] = "Partial Content",
    [207] = "Multi-Status",
    [208] = "Already Reported",
    [226] = "IM Used",
    [300] = "Multiple Choices",
    [301] = "Moved Permanently",
    [302] = "Found (Previously \"Moved Temporarily\")",
    [303] = "See Other",
    [304] = "Not Modified",
    [305] = "Use Proxy",
    [306] = "Switch Proxy",
    [307] = "Temporary Redirect",
    [308] = "Permanent Redirect",
    [400] = "Bad Request",
    [401] = "Unauthorized",
    [402] = "Payment Required",
    [403] = "Forbidden",
    [404] = "Not Found",
    [405] = "Method Not Allowed",
    [406] = "Not Acceptable",
    [407] = "Proxy Authentication Required",
    [408] = "Request Timeout",
    [409] = "Conflict",
    [410] = "Gone",
    [411] = "Length Required",
    [412] = "Precondition Failed",
    [413] = "Payload Too Large",
    [414] = "URI Too Long",
    [415] = "Unsupported Media Type",
    [416] = "Range Not Satisfiable",
    [417] = "Expectation Failed",
    [418] = "I'm a Teapot",
    [421] = "Misdirected Request",
    [422] = "Unprocessable Entity",
    [423] = "Locked",
    [424] = "Failed Dependency",
    [425] = "Too Early",
    [426] = "Upgrade Required",
    [428] = "Precondition Required",
    [429] = "Too Many Requests",
    [431] = "Request Header Fields Too Large",
    [451] = "Unavailable For Legal Reasons",
    [500] = "Internal Server Error",
    [501] = "Not Implemented",
    [502] = "Bad Gateway",
    [503] = "Service Unavailable",
    [504] = "Gateway Timeout",
    [505] = "HTTP Version Not Supported",
    [506] = "Variant Also Negotiates",
    [507] = "Insufficient Storage",
    [508] = "Loop Detected",
    [510] = "Not Extended",
    [511] = "Network Authentication Required"
}

------------------------------------------------------------------------------------------------------------------------
--- Writes HTTP Message to the given connection using the given response object
---
--- @see https://developer.mozilla.org/en-US/docs/Web/HTTP/Messages
--- @param client TCPSocket @see https://lunarmodules.github.io/luasocket/tcp.html
--- @param response table response table containing 'status' and 'body'
local function send_http(client, response)
    local start_line = table.concat({ "HTTP/1.1", response.status, status_text[response.status] }, " ")

    local headers = { "Server: DCS Fiddle Server HTTP/1.1" }

    for name, value in pairs(response.headers) do
        table.insert(headers, name .. ": " .. value)
    end

    local response_string
    if (response.body) then
        response_string = table.concat({ start_line, table.concat(headers, CRLF), EMPTY_LINE, response.body }, CRLF)
    else
        response_string = table.concat({ start_line, table.concat(headers, CRLF), EMPTY_LINE, EMPTY_LINE }, CRLF)
    end

    __info("Sending HTTP Response")
    --__debug(">> " .. response_string)
    local index, err = client:send(response_string)
    if (err) then
        __error("Failed to fully send due to: " .. err)
    else
        __info("Successfully sent response")
    end
end

------------------------------------------------------------------------------------------------------------------------
--- HTTP Server
------------------------------------------------------------------------------------------------------------------------
if (not require or not package) then
    if (env and env.error) then
        env.error("DCS Fiddle failed to inject into the mission scripting environment as require or package was not found.\n\nPlease follow the installation docs to de-sanitize the mission scripting environment\nhttps://dcsfiddle.pages.dev/docs", true)
        return
    end
end

package.path = package.path .. ";.\\LuaSocket\\?.lua"
package.cpath = package.cpath .. ";.\\LuaSocket\\?.dll"

local socket = require("socket")

local clients = {}
local tcp_server

local server_config = { cors = "*" }

local client_id_seq = 1

local OK = 200

local BAD_REQUEST = 400

local INTERNAL_SERVER_ERROR = 500
local METHOD_NOT_ALLOWED = 405
local UNAUTHORIZED = 401

-----------------------------------------------------------------------------------------------------------------------
--- Gets and returns a client id incrementing the sequence
local function get_client_id()
    local id = client_id_seq
    client_id_seq = client_id_seq + 1
    return id
end

local function handle_client_connection(client)
    -- Dictionary of Headers that need to match, failure to match fails the read operation and returns the error code
    local response = { status = INTERNAL_SERVER_ERROR, headers = { ["Content-Type"] = "application/json"} }

    local request = receive_http(client)

    if (request) then
        if (request.method ~= "GET") then
            response.status = METHOD_NOT_ALLOWED
        elseif not request.authOK then
            __info("Request Unauthorized")
            response.status = UNAUTHORIZED
        else
            __info("Handling Request")
            local success, res = pcall(base64.decode, string.sub(request.path, 2))
            if (not success) then
                __error("Failed to read input due to " .. res)
                response.status = BAD_REQUEST
            else
                local env = request.parameters and request.parameters.env
                __info("Processing Command " .. res)
                local success, res = pcall(handle_request, res, env)
                if (not success) then
                    __error("Failed to handle request due to \n" .. res)
                    response.body = fiddlejson.encode({error=tostring(res)})
                    response.status = INTERNAL_SERVER_ERROR
                else
                    __info("Handled request")
                    response.body = fiddlejson.encode({result=res})
                    response.status = OK
                end
            end
        end
    end

    if (server_config.cors) then
        response.headers["Access-Control-Allow-Origin"] = server_config.cors
    end

    send_http(client, response)

    __info("Connection Completed")
    client:close()
end


local function create_server(address, port)
    tcp_server = socket.bind(address, port)
    if not tcp_server then
        __error("Could not bind socket.")
        return
    end
    tcp_server:settimeout(0) -- Make non blocking

    local ip, port = tcp_server:getsockname()

    __info("HTTP Server running on " .. ip .. ":" .. port)

    --- Returns function which when called will perform 1 server loop
    --- Note this impl only allows 1 request to be handled at a time
    return function()
        local client = tcp_server:accept()
        if (client) then
            handle_client_connection(client) -- This function has no return value
            -- local success, res = handle_client_connection(client)
            -- if (not success) then
            --     __error("Failed to run client handler " .. res)
            -- else
            --     clients[ip].receive_patten = res
            -- end
        end
    end
end

------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------- MAIN ---------------------------------------------------------------

__info("Checking the DCS environment...")

local isMission = not DCS
local port =  FIDDLE.PORT or 12080
local bind_ip = FIDDLE.BIND_IP or '127.0.0.1'

if (isMission) then
    __info("Starting fiddle server in the mission scripting environment...")
    -- VEAF (FIX-SECREV2): the hook environment generated the password and wrote the file first (it runs
    -- at the main menu, before any mission), so read it here. A read failure leaves the placeholder,
    -- which no client knows — so every request is rejected, which is the safe outcome.
    FIDDLE.PASSWORD = veaf.readToken() or FIDDLE.PASSWORD
    local loop = create_server(bind_ip, port)

    if (not loop) then
        __error("Failed to start server in the mission scripting environment")
        return
    end

    timer.scheduleFunction(function(arg, time)
        local success, err = pcall(loop)
        if not success then
            __info("loop() error: " .. tostring(err))
        end
        return timer.getTime() + .1
    end, nil, timer.getTime() + .1)

    __info("DCS Fiddle server running")
    env.info("DCS Fiddle successfully initialized.\n\nHappy Hacking!!", false)
elseif (not isMission) then
    __info("Starting fiddle server in the Hooks environment...")

    -- VEAF (FIX-SECREV2): generate a fresh per-session password and write it where the harness client
    -- reads it. This runs at the main menu, before any mission, so the mission environment can read it
    -- when it bootstraps at onSimulationStart.
    FIDDLE.PASSWORD = veaf.generateToken()
    if veaf.writeToken(FIDDLE.PASSWORD) then
        __info("Fiddle session password written to " .. veaf.tokenFilePath())
    else
        __error("Could not write the fiddle token to " .. veaf.tokenFilePath() .. " — clients will be rejected")
    end

    local fiddleFile = lfs.writedir() .. 'Scripts\\Hooks\\dcs-fiddle-server.lua'

    local loop = create_server(bind_ip, port+1)

    if (not loop) then
        __error("Failed to start server in the Hooks environment")
        return
    end

    local callbacks = {}

    function callbacks.onSimulationStart()
        __info("Bootstrapping DCS Fiddle inside the mission using file " .. fiddleFile)
        net.dostring_in("mission", string.format([[a_do_script("dofile('%s')")]], fiddleFile:gsub("\\","/")))
    end

    function callbacks.onSimulationFrame()
        loop()
    end

    DCS.setUserCallbacks(callbacks)

    __info("DCS Fiddle server running")
else
    __info("Failed to start DCS fiddle, unknown environment")
end
