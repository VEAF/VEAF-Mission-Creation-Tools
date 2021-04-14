-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- VEAF server hook for DCS World
-- By Zip (2021)
--
-- Features:
-- ---------
-- * This hook is used on the VEAF server. It has multiple features :
-- *   - autorestart at night when no one is connected
-- *   - listen to chat text and extract commands to be run on the server (WIP)
-- *   - open a socket to listen to specific commands and push them on the server (TBD)
-- 
-- Usage:
-- ---------
-- *   - Drop this script in the Scripts/Hooks folder of the server ("saved games" !)
-- *   - Also drop the `veaf-pilots.lua` file in the main server folder ("saved games" !) and edit it
-------------------------------------------------------------------------------------------------------------------------------------------------------------

veafSpecificServerHook = {}

base = _G 
require = base.require 
io = require('io')
lfs = require('lfs')
os = require('os')

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Global settings. Stores the script constants
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- The server name
veafSpecificServerHook.serverName = "SERVER"

--- Identifier. All output in the log will start with this.
veafSpecificServerHook.Id = "VEAFSPECIFICHOOK - "

--- Version.
veafSpecificServerHook.Version = "1.0.1"

-- trace level, specific to this module
veafSpecificServerHook.Trace = false
veafSpecificServerHook.Debug = false

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Do not change anything below unless you know what you are doing!
-------------------------------------------------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Utility methods
-------------------------------------------------------------------------------------------------------------------------------------------------------------

function veafSpecificServerHook.logError(message)
    log.write(veafSpecificServerHook.Id, log.ERROR, message)
end

function veafSpecificServerHook.logWarning(message)
    log.write(veafSpecificServerHook.Id, log.WARNING, message)
end

function veafSpecificServerHook.logInfo(message)
    log.write(veafSpecificServerHook.Id, log.INFO, message)
end

function veafSpecificServerHook.logDebug(message)
    if message and veafSpecificServerHook.Debug then 
        log.write(veafSpecificServerHook.Id, log.DEBUG, message)
    end
end

function veafSpecificServerHook.logTrace(message)
    if message and veafSpecificServerHook.Trace then 
        log.write(veafSpecificServerHook.Id, log.TRACE, message)
    end
end

function p(o, level)
    local MAX_LEVEL = 20
if level == nil then level = 0 end
if level > MAX_LEVEL then 
    veafSpecificServerHook.logError("max depth reached in p : "..tostring(MAX_LEVEL))
    return ""
end
local text = ""
if (type(o) == "table") then
    text = "\n"
    for key,value in pairs(o) do
        for i=0, level do
            text = text .. " "
        end
        text = text .. ".".. key.."="..p(value, level+1) .. "\n";
    end
elseif (type(o) == "function") then
    text = "[function]";
    elseif (type(o) == "boolean") then
        if o == true then 
            text = "[true]";
        else
            text = "[false]";
        end
    else
        if o == nil then
            text = "[nil]";    
        else
            text = tostring(o);
        end
    end
    return text
end

--------------------------------------------------------------------------------------------------------------------------------------
-- DCS events handling
-------------------------------------------------------------------------------------------------------------------------------------------------------------

function veafSpecificServerHook.onSimulationStart()
    veafSpecificServerHook.logDebug(string.format("veafSpecificServerHook.onSimulationStart()"))
    -- set the server name in the mission
    veafSpecificServerHook.logDebug(string.format("set the server name in the mission"))
    local _maxDuration = nil
local _status, _retValue = pcall(net.dostring_in, 'mission', 'return a_do_script(' .. '[===[ if veaf and veaf.setServerName then return veaf.setServerName("'.. veafSpecificServerHook.serverName ..'") else return nil end ]===]' .. ')')
    veafSpecificServerHook.logTrace(string.format("_status=%s",p(_status)))
    veafSpecificServerHook.logTrace(string.format("_retValue=%s",p(_retValue)))
    if not _status then
        veafSpecificServerHook.logWarning(string.format("Code injection failed for veaf.setServerName()"))
    end
end

DCS.setUserCallbacks(veafSpecificServerHook)
