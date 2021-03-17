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

veafServerHook = {}

base = _G 
require = base.require 
io = require('io')
lfs = require('lfs')
os = require('os')
VEAF_SERVER_DIR = lfs.writedir() .. [[scripts\hooks\]]
VEAF_PILOTS_FILE = "veaf-pilots.txt"
DCS_DIR = lfs.writedir()

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Global settings. Stores the script constants
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Identifier. All output in the log will start with this.
veafServerHook.Id = "VEAFHOOK - "

--- Version.
veafServerHook.Version = "1.0.1"

-- trace level, specific to this module
veafServerHook.Trace = true
veafServerHook.Debug = true

veafServerHook.CommandStarter = "/"
veafServerHook.CommandParser = "/([a-zA-Z0-9]+)%s?(.*)"

-- maximum mission duration before the server is restarted (in minutes, mission model time)
veafServerHook.DEFAULT_MAX_MISSION_DURATION = 4 * 60

-- scripts injected in the mission
REGISTER_PLAYER =  [[ if veafRemote and veafRemote.registerUser then veafRemote.registerUser("%s", "%s", "%s") end ]]
RUN_COMMAND = [[ if veafRemote and veafRemote.executeCommandFromRemote then veafRemote.executeCommandFromRemote("%s", "%s", "%s", "%s", "%s") end ]]
SEND_MESSAGE = [[ if trigger and trigger.action and trigger.action.outText then trigger.action.outText("%s", %s) end ]]
-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Do not change anything below unless you know what you are doing!
-------------------------------------------------------------------------------------------------------------------------------------------------------------

veafServerHook.pilots = {}

veafServerHook.closeServerAtMissionStop = false
veafServerHook.closeServerAtLastDisconnect = false

veafServerHook.lastFrameTime = 0

veafServerHook.maxMissionDuration = veafServerHook.DEFAULT_MAX_MISSION_DURATION

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Utility methods
-------------------------------------------------------------------------------------------------------------------------------------------------------------

function veafServerHook.logError(message)
    log.write(veafServerHook.Id, log.ERROR, message)
end

function veafServerHook.logWarning(message)
    log.write(veafServerHook.Id, log.WARNING, message)
end

function veafServerHook.logInfo(message)
    log.write(veafServerHook.Id, log.INFO, message)
end

function veafServerHook.logDebug(message)
    if message and veafServerHook.Debug then 
        log.write(veafServerHook.Id, log.DEBUG, message)
    end
end

function veafServerHook.logTrace(message)
    if message and veafServerHook.Trace then 
        log.write(veafServerHook.Id, log.TRACE, message)
    end
end

function p(o, level)
    local MAX_LEVEL = 20
if level == nil then level = 0 end
if level > MAX_LEVEL then 
    veafServerHook.logError("max depth reached in p : "..tostring(MAX_LEVEL))
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

function veafServerHook.onSimulationStart()
    veafServerHook.logDebug(string.format("veafServerHook.onSimulationStart()"))
    veafServerHook.initialize()
    -- ask the mission for its maximum runtime
    veafServerHook.logDebug(string.format("ask the mission for its maximum runtime"))
    local _maxDuration = nil
local _status, _retValue = pcall(net.dostring_in, 'mission', 'return a_do_script(' .. '[===[ if veaf and veaf.getMissionMaxRuntime then return veaf.getMissionMaxRuntime() else return nil end ]===]' .. ')')
    veafServerHook.logTrace(string.format("_status=%s",p(_status)))
    veafServerHook.logTrace(string.format("_retValue=%s",p(_retValue)))
    if not _status then
        veafServerHook.logWarning(string.format("Code injection failed for veaf.getMissionMaxRuntime()"))
    else
        if type(_retValue) == "string" and _retValue:match("%d+") then
            _maxDuration = tonumber(_retValue)
        end
    end
    veafServerHook.maxMissionDuration = _maxDuration
    if veafServerHook.maxMissionDuration == nil then
        veafServerHook.maxMissionDuration = veafServerHook.DEFAULT_MAX_MISSION_DURATION
        veafServerHook.logInfo(string.format("Maximum mission duration is set to its default value (%s)", p(veafServerHook.maxMissionDuration)))
    else
        veafServerHook.logInfo(string.format("Maximum mission duration is set to %s", p(veafServerHook.maxMissionDuration)))
    end
end

function veafServerHook.onSimulationStop()
    veafServerHook.logDebug(string.format("veafServerHook.onSimulationStop()"))
    veafServerHook.stopMissionIfNeeded()
    if veafServerHook.closeServerAtMissionStop then
        veafServerHook.logInfo(string.format("veafServerHook.onSimulationStop() - stopping the server"))
        DCS.exitProcess()
    end
end

function veafServerHook.onTriggerMessage(message)	
    veafServerHook.logDebug(string.format("veafServerHook.onTriggerMessage([%s])", p(message)))
end

function veafServerHook.onPlayerConnect(id)
    veafServerHook.logDebug(string.format("veafServerHook.onPlayerConnect([%s])", p(id)))
    local _playerDetails = net.get_player_info( id )
    local playerInfo = {}
    local playerName = _playerDetails.name
    local ucid = _playerDetails.ucid
    veafServerHook.logTrace(string.format("playerInfo=%s",p(playerInfo)))
    veafServerHook.logTrace(string.format("playerName=%s",p(playerName)))
    veafServerHook.logTrace(string.format("ucid=%s",p(ucid)))
    -- parse the message
    local pilot = veafServerHook.pilots[ucid]
    if pilot then
        veafServerHook.logInfo(string.format("VEAF pilot [%s] connecting", p(playerName)))
        veafServerHook.logTrace(string.format("pilot=%s",p(pilot)))
        local payload = string.format(REGISTER_PLAYER, playerName, pilot.level, ucid, uni)
        veafServerHook.logTrace(string.format("payload=%s",p(payload)))
        veafServerHook.injectCode(payload)
    else
        veafServerHook.logInfo(string.format("Unknown pilot [%s] connecting", p(playerName)))
    end
end

function veafServerHook.onPlayerDisconnect(id, err_code)
    veafServerHook.logDebug(string.format("veafServerHook.onPlayerDisconnect([%s], [%s])", p(id), p(err_code)))
    veafServerHook.stopMissionIfNeeded()
end    

function veafServerHook.onRadioMessage(message, duration)
    veafServerHook.logDebug(string.format("veafServerHook.onRadioMessage([%s], [%s])", p(duration), p(message)))
end

function veafServerHook.onShowGameMenu()
    veafServerHook.logDebug(string.format("veafServerHook.onShowGameMenu()"))
end

function veafServerHook.onChatMessage(message, from)
    veafServerHook.logDebug(string.format("veafServerHook.onChatMessage([%s], [%s])",p(from), p(message)))
    
    -- try and recognize a command
    if message ~= nil and message:lower():find(veafServerHook.CommandStarter) then
        local _playerDetails = net.get_player_info( from )
        if _playerDetails ~=nil then
            local playerInfo = {}
            local playerName = _playerDetails.name
            local ucid = _playerDetails.ucid
            local unitName = nil
            if _playerDetails.side ~= 0 and _playerDetails.slot ~= "" and _playerDetails.slot ~= nil then
                unitName = DCS.getUnitProperty(_playerDetails.slot, DCS.UNIT_NAME)
            end

            veafServerHook.logTrace(string.format("playerInfo=%s",p(playerInfo)))
            veafServerHook.logTrace(string.format("playerName=%s",p(playerName)))
            veafServerHook.logTrace(string.format("ucid=%s",p(ucid)))
            veafServerHook.logTrace(string.format("unitName=%s",p(unitName)))
            -- parse the message
            local pilot = veafServerHook.pilots[ucid]
            veafServerHook.logTrace(string.format("pilot=%s",p(pilot)))
            if veafServerHook.parse(pilot, playerName, unitName, message) then
                veafServerHook.logInfo(string.format("Player %s ran command %s", playerName, message))
            else
                veafServerHook.logWarning(string.format("Player %s was denied running command %s", playerName, message))
            end
        end
    end
    return false
end

function veafServerHook.onSimulationFrame()
    --let's not pollute the log 
    --veafServerHook.logDebug(string.format("veafServerHook.onSimulationFrame()"))
    
    --local now = DCS.getRealTime()
    
    -- log every 15 seconds
    --[[
    if now > veafServerHook.lastFrameTime + 15.0 then
        veafServerHook.lastFrameTime = now 
        veafServerHook.logDebug(string.format("veafServerHook.onSimulationFrame() - tick"))
    end
    ]]
    
    --veafServerHook.stopMissionIfNeeded()
end

function veafServerHook.onShowRadioMenu(a_h)
    veafServerHook.logDebug(string.format("veafServerHook.onShowRadioMenu([%s])",p(a_h)))
end

function veafServerHook.onShowPool()
    veafServerHook.logDebug(string.format("veafServerHook.onShowPool()"))
end

function veafServerHook.onShowBriefing()
    veafServerHook.logDebug(string.format("veafServerHook.onShowBriefing()"))
end

function veafServerHook.onShowChatAll()
    veafServerHook.logDebug(string.format("veafServerHook.onShowChatAll()"))
end

function veafServerHook.onShowChatTeam()
    veafServerHook.logDebug(string.format("veafServerHook.onShowChatTeam()"))
end

function veafServerHook.onShowChatRead()
    veafServerHook.logDebug(string.format("veafServerHook.onShowChatRead()"))
end

function veafServerHook.onShowMessage(a_text, a_duration)
    veafServerHook.logDebug(string.format("veafServerHook.onShowMessage([%s], [%s])",p(a_text), p(a_duration)))
end

function veafServerHook.onTriggerMessage(message, duration, clearView)
    veafServerHook.logDebug(string.format("veafServerHook.onTriggerMessage([%s], [%s], [%s])",p(message), p(duration), p(clearView)))
end

function veafServerHook.onRadioMessage(message, duration)
    veafServerHook.logDebug(string.format("veafServerHook.onRadioMessage([%s], [%s])",p(message), p(duration)))
end

function veafServerHook.onRadioCommand(command_message)
    veafServerHook.logDebug(string.format("veafServerHook.onRadioCommand([%s])",p(command_message)))
end
-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Core methods
-------------------------------------------------------------------------------------------------------------------------------------------------------------
function veafServerHook.parse(pilot, playerName, unitName, message)
    veafServerHook.logTrace(string.format("veafServerHook.parse([%s] , [%s])", p(playerName), p(message)))
    veafServerHook.logTrace(string.format("pilot=%s",p(pilot)))
    veafServerHook.logTrace(string.format("unitName=%s",p(unitName)))
    
    if not pilot then
        veafServerHook.logWarning(string.format("Unknown pilot [%s] sent chat message [%s])",p(playerName), p(message)))
    end

    local _module, _command = message:match(veafServerHook.CommandParser)
    veafServerHook.logTrace(string.format("_module=%s",p(_module)))
    veafServerHook.logTrace(string.format("_command=%s",p(_command)))
    if _module and _module:lower() == "send" then
        -- any registered pilot can call the TEST commands
        if pilot.level >= 0 then
            local _command = _command or "this is a test message from the VEAF server hook"
            veafServerHook.logInfo(string.format("[%s] is sending message [%s])",p(playerName), p(_command)))
            veafServerHook.sendMessage(_command, 10)
            return true
        end
    elseif _module and _module:lower() == "code" then
        -- only level >= 90 can execute code
        if pilot.level >= 90 then
            return veafServerHook.injectCode(_command)
        end
    elseif _module and _module:lower() == "restart" then
        -- only level >= 10 can schedule mission restart
        if pilot.level >= 10 then
            veafServerHook.maxMissionDuration = 0
            veafServerHook.closeServerAtLastDisconnect = false
            local _message = string.format("[%s] is asking for mission restart when the last pilot disconnects from the server",p(playerName))
            veafServerHook.logInfo(_message)
            veafServerHook.sendMessage(_message, 10)
            return true
        end
    elseif _module and _module:lower() == "halt" then
        -- only level >= 90 can schedule server halt (and hopefully autorestart)
        if pilot.level >= 90 then
            veafServerHook.maxMissionDuration = 0
            veafServerHook.closeServerAtLastDisconnect = true
            local _message = string.format("[%s] is asking for server halt the last pilot disconnects from the server",p(playerName))
            veafServerHook.logInfo(_message)
            veafServerHook.sendMessage(_message, 10)
            return true
        end
    else
        -- only level >= 1 can call commands
        if pilot.level >= 1 then
            local payload = string.format(RUN_COMMAND, tostring(playerName), tostring(pilot.level), tostring(unitName), tostring(_module), tostring(_command))
            veafServerHook.logTrace(string.format("payload=%s",p(payload)))
            return veafServerHook.injectCode(payload)
        end
    end
    return false
end

function veafServerHook.stopMissionIfNeeded()
    veafServerHook.logDebug(string.format("veafServerHook.stopMissionIfNeeded()"))
    local _modelTimeInSeconds = DCS.getModelTime()
    veafServerHook.logTrace(string.format("_modelTimeInSeconds=%s",p(_modelTimeInSeconds)))
    if _modelTimeInSeconds > veafServerHook.maxMissionDuration * 60 then
        -- check if no one is connected (triggered on last disconnect)
        local _players = net.get_player_list()
        veafServerHook.logTrace(string.format("_players=%s",p(_players)))
        local _nPlayers = #_players
        veafServerHook.logTrace(string.format("_nPlayers=%s",p(_nPlayers)))
        if _nPlayers <= 1 then -- only the administrator remains           
            -- restart the server
            veafServerHook.logInfo(string.format("veafServerHook.stopMissionIfNeeded() - stopping the mission"))
            if veafServerHook.closeServerAtLastDisconnect then
                veafServerHook.closeServerAtMissionStop = true
                DCS.stopMission()
            else
                -- just restart the mission
                veafServerHook.closeServerAtMissionStop = false
                local _missionFilename = DCS.getMissionFilename()
                veafServerHook.logInfo(string.format("reloading mission [%s]", _missionFilename))
                net.load_mission(_missionFilename)
            end
        end
    else
        veafServerHook.logInfo(string.format("veafServerHook.stopMissionIfNeeded() - no need to stop the mission"))
    end
end

function veafServerHook.injectCode(payload)
    veafServerHook.logDebug(string.format("veafServerHook.injectCode([%s])",p(payload)))
    local _status, _retValue = pcall(net.dostring_in, 'mission', 'return a_do_script(' .. '[===[' .. payload .. ']===]' .. ')')
    veafServerHook.logTrace(string.format("_status=%s",p(_status)))
    veafServerHook.logTrace(string.format("_retValue=%s",p(_retValue)))
    if not _status then
        veafServerHook.logError(string.format("Code injection failed for [%s]",p(payload)))
        veafServerHook.logError(string.format("_retValue=[%s], _status=[%s]",p(_retValue), p(_status)))
    end
    return _retValue
end

function veafServerHook.sendMessage(message, duration)
    veafServerHook.logDebug(string.format("veafServerHook.sendMessage([%s, %s])",p(message), p(duration)))
    veafServerHook.injectCode(string.format(SEND_MESSAGE, message, tostring(duration)))
end

-- Load the list of VEAF pilots
function veafServerHook.loadPilots()
    veafServerHook.logDebug(string.format("veafServerHook.loadPilots()"))
    veafServerHook.logInfo(string.format("loading pilots"))
    local filepath = VEAF_SERVER_DIR .. VEAF_PILOTS_FILE
    local file = assert(loadfile(filepath))
    if not file then
        veafServerHook.logError(string.format("Error while loading pilots list file [%s]",p(filePath)))
        return
    end
    
    file()
    returner = loadstring("return pilots")
    veafServerHook.pilots = returner()
    veafServerHook.logInfo(string.format("pilots loaded"))
    veafServerHook.logTrace(string.format("pilots=%s",p(veafServerHook.pilots)))
end

function veafServerHook.initialize()
    veafServerHook.logDebug(string.format("veafServerHook.initialize"))
    veafServerHook.logInfo(string.format("initializing module"))
    veafServerHook.loadPilots()
end

DCS.setUserCallbacks(veafServerHook)
