-- START OF VEAF CHANGES
--[[
    VEAF: Changes to the original script: added a way to find out the sanitized modules from the server config
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

local extract = _G.bit32 and _G.bit32.extract -- Lua 5.2/Lua 5.3 in compatibility mode
if not extract then
    if _G.bit then
        -- LuaJIT
        local shl, shr, band = _G.bit.lshift, _G.bit.rshift, _G.bit.band
        extract = function(v, from, width)
            return band(shr(v, from), shl(1, width) - 1)
        end
    elseif _G._VERSION == "Lua 5.1" then
        extract = function(v, from, width)
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
    else
        -- Lua 5.3+
        extract = load [[return function( v, from, width )
			return ( v >> from ) & ((1 << width) - 1)
		end]]()
    end
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
    local message = '[dcs-fiddle-server] - ' .. message
    if (log and log.debug) then
        log.debug(message)
    else
        print('DEBUG - ' .. message)
    end
end

local __info = function(message)
    local message = '[dcs-fiddle-server] - ' .. message
    if (log and log.info) then
        log.info(message)
    else
        print('INFO - ' .. message)
    end
end

local __error = function(message)
    local message = '[dcs-fiddle-server] - ' .. message
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
--- @return string, table Returns the path part alongside a table of parsed parameters
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
--- @param client socket.client LUA Socket Lib Client
--- @return table, number Request table containing method, original_url, protocol, path, parameters, body, headers. Optionally returns a second item representing an error_code from the match_headers failing
local function receive_http(client)
    local request = {}
    __debug("receiving start-line")
    local received, err = client:receive("*l")

    if (err) then
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
--- @param client client @see https://lunarmodules.github.io/luasocket/tcp.html
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
                    response.body = net.lua2json({error=tostring(res)})
                    response.status = INTERNAL_SERVER_ERROR
                else
                    __info("Handled request")
                    response.body = net.lua2json({result=res})
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
    tcp_server:settimeout(0) -- Make non blocking

    if not tcp_server then
        __error("Could not bind socket.")
    end

    local ip, port = tcp_server:getsockname()

    __info("HTTP Server running on " .. ip .. ":" .. port)

    --- Returns function which when called will perform 1 server loop
    --- Note this impl only allows 1 request to be handled at a time
    return function()
        local client = tcp_server:accept()
        if (client) then
            local success, res = handle_client_connection(client)
            if (not success) then
                __error("Failed to run client handler " .. res)
            else
                clients[id].receive_patten = res
            end
        end
    end
end

------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------- MAIN ---------------------------------------------------------------

__info("Checking the DCS environment...")

local isMission = not DCS

if (isMission) then
    __info("Starting fiddle server in the mission scripting environment...")
    local loop = create_server("127.0.0.1", 12080)

    timer.scheduleFunction(function(arg, time)
        local success, err = pcall(loop)
        if not success then
            __info("loop() error: " .. tostring(err))
        end
        return timer.getTime() + .1
    end, nil, timer.getTime() + .1)

    __info("DCS Fiddle server running")
    env.info("DCS Fiddle successfully initialized.\n\nHappy Hacking!!", true)
elseif (not isMission) then
    __info("Starting fiddle server in the Hooks environment...")

    local fiddleFile = lfs.writedir() .. 'Scripts\\Hooks\\dcs-fiddle-server.lua'

    local loop = create_server("127.0.0.1", 12081)

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
