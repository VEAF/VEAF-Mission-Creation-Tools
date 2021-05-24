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
package.path  = package.path..";"..lfs.currentdir().."/LuaSocket/?.lua"..";"..lfs.writedir() .. "/Mods/services/BufferingSocket/lua/?.lua"
package.cpath = package.cpath..";"..lfs.currentdir().."/LuaSocket/?.dll"..';'.. lfs.writedir()..'/Mods/services/BufferingSocket/bin/' ..'?.dll;'
veafServerHook.config = require "BufferingSocketConfig"
BufferingSocket = require('BufferingSocket') 
DCS_DIR = lfs.writedir()
VEAF_SERVER_DIR = DCS_DIR .. [[scripts\hooks\]]
VEAF_PILOTS_FILE = "veaf-pilots.txt"

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Global settings. Stores the script constants
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Identifier. All output in the log will start with this.
veafServerHook.Id = "VEAFHOOK - "

--- Version.
veafServerHook.Version = "2.0.1"

-- trace level, specific to this module
veafServerHook.Trace = true
veafServerHook.Debug = true

veafServerHook.CommandStarter = "/"
veafServerHook.CommandParser = "/([a-zA-Z0-9]+)%s?(.*)"

veafServerHook.ADMIN_FAKE_UCID = "0123456789ABCDEF012345-AdminVEAF"

-- maximum mission duration before the server is restarted (in minutes, mission model time)
veafServerHook.DEFAULT_MAX_MISSION_DURATION = 4 * 60

-- scripts injected in the mission
REGISTER_PLAYER =  [[ if veafRemote and veafRemote.registerUser then veafRemote.registerUser("%s", "%s", "%s") end ]]
RUN_COMMAND = [[ if veafRemote and veafRemote.executeCommandFromRemote then veafRemote.executeCommandFromRemote("%s", "%s", "%s", "%s", "%s") end ]]
SEND_MESSAGE = [[ if trigger and trigger.action and trigger.action.outText then trigger.action.outText("%s", %s) end ]]

-- marks the end of a data package sent to the API server socket
veafServerHook.EOT_MARKER = ">>EOT"

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Do not change anything below unless you know what you are doing!
-------------------------------------------------------------------------------------------------------------------------------------------------------------

veafServerHook.pilots = {}

veafServerHook.closeServerAtMissionStop = false
veafServerHook.closeServerAtLastDisconnect = true

veafServerHook.lastFrameTime = 0

veafServerHook.maxMissionDuration = veafServerHook.DEFAULT_MAX_MISSION_DURATION

veafServerHook.statisticsTypes = {"ping", "crashes", "vehicules", "aircrafts", "ships", "score", "landings", "ejections"}

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
        log.write(veafServerHook.Id, log.INFO, message)
    end
end

function veafServerHook.logTrace(message)
    if message and veafServerHook.Trace then 
        log.write(veafServerHook.Id, log.INFO, message)
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

    veafServerHook.closeServerAtLastDisconnect = true -- halt the server when the mission stops, by default
end

function veafServerHook.onSimulationStop()
    veafServerHook.logDebug(string.format("veafServerHook.onSimulationStop()"))
    if veafServerHook.closeServerAtMissionStop then
        veafServerHook.logInfo(string.format("veafServerHook.onSimulationStop() - stopping the server"))
        DCS.exitProcess()
    end
end

function veafServerHook.onPlayerConnect(id)
    veafServerHook.logDebug(string.format("veafServerHook.onPlayerConnect([%s])", p(id)))
    local _playerDetails = net.get_player_info( id )
    local playerName = _playerDetails.name
    local ucid = _playerDetails.ucid
    veafServerHook.logTrace(string.format("playerName=%s",p(playerName)))
    veafServerHook.logTrace(string.format("ucid=%s",p(ucid)))
    -- parse the message
    local pilot = veafServerHook.pilots[ucid]
    if pilot then
        veafServerHook.logInfo(string.format("VEAF pilot [%s] connecting", p(playerName)))
        veafServerHook.logTrace(string.format("pilot=%s",p(pilot)))
        local payload = string.format(REGISTER_PLAYER, playerName, pilot.level, ucid)
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

function veafServerHook.onChatMessage(message, from)
    veafServerHook.logDebug(string.format("veafServerHook.onChatMessage([%s], [%s])",p(from), p(message)))
    
    -- try and recognize a command
    if message ~= nil and message:lower():sub(1, #veafServerHook.CommandStarter) == veafServerHook.CommandStarter then
        local _playerDetails = net.get_player_info( from )
        if _playerDetails ~=nil then
            local playerName = _playerDetails.name
            local ucid = _playerDetails.ucid
            local unitName = nil
            if _playerDetails.side ~= 0 and _playerDetails.slot ~= "" and _playerDetails.slot ~= nil then
                unitName = DCS.getUnitProperty(_playerDetails.slot, DCS.UNIT_NAME)
            end
            
            veafServerHook.logTrace(string.format("playerName=%s",p(playerName)))
            veafServerHook.logTrace(string.format("ucid=%s",p(ucid)))
            veafServerHook.logTrace(string.format("unitName=%s",p(unitName)))
            -- parse the message
            local pilot = veafServerHook.pilots[ucid]
            if from == 1 then 
                -- this is the server administrator
                pilot = veafServerHook.pilots[veafServerHook.ADMIN_FAKE_UCID]
            end
            veafServerHook.logTrace(string.format("pilot=%s",p(pilot)))
            if veafServerHook.parse(pilot, playerName, ucid, unitName, message) then
                veafServerHook.logInfo(string.format("Player %s ran command %s", playerName, message))
            else
                veafServerHook.logWarning(string.format("Player %s was denied running command %s", playerName, message))
            end
        end
    end
    return false
end

function veafServerHook.onSimulationFrame()
    --veafServerHook.logTrace(string.format("veafServerHook.onSimulationFrame()"))

    local _now = DCS.getRealTime()

    if _now > veafServerHook.lastFrameTime + veafServerHook.config.refreshDelay then
        veafServerHook.lastFrameTime = _now
        veafServerHook.logTrace(string.format("sending data"))
        veafServerHook.sendData(_now)
    end
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Core methods
-------------------------------------------------------------------------------------------------------------------------------------------------------------

function veafServerHook.sendData(timestamp)
    
    local data_package = { timestamp = _now}

    veafServerHook.logTrace(string.format("get basic server information"))
    data_package.serverData = { 
        frameTime = _now,
        mission = DCS.getMissionFilename(),
        missionTimeInSeconds = DCS.getModelTime(),
        missionMaxTimeInSeconds = veafServerHook.maxMissionDuration * 3600,
        numberOfPlayers = #net.get_player_list() - 1
    }

    -- get list of connected pilots
    data_package.pilots = {}
    veafServerHook.logTrace(string.format("get list of connected pilots"))
    local players = net.get_player_list()
    for playerId, _ in pairs(players) do
        veafServerHook.logTrace(string.format("playerId=%s",playerId))       
        local playerDetails = net.get_player_info(playerId)       
        local playerName = playerDetails.name
        local ucid = playerDetails.ucid
        local pilotData = {
            name = playerName,
            level = 0,
            unit = playerDetails.slot,
            stats = {}
        }
        for key, value in pairs(veafServerHook.statisticsTypes) do
            local stat = net.get_stat(playerId, key)
            pilotData.stats[value] = stat
        end
        local pilot = veafServerHook.pilots[ucid]
        if pilot then
            pilotData.level = pilot.level
        end
        data_package.pilots[ucid] = pilotData
    end

    -- get list of units
    data_package.unitsAsJson = {}
    
    veafServerHook.logTrace(string.format("testing witchcraft code"))
    local code = [[
        serialize = function(val)
            if type(val)=='number' or type(val)=='boolean' then
                return tostring(val)
            elseif type(val)=='string' then
                return string.format("%q", val)
            elseif type(val)=='table' then
                local k,v
                local str = '{'
                for k,v in pairs(val) do
                    str=str..'['..serialize(k)..']='..serialize(v)..','
                end
                str = str..'}'
                return str
            end
            return 'nil'
        end


        p = function(o, level, maxLevel)
            local maxLevel = maxLevel or 20
            if level == nil then level = 0 end
            if level > maxLevel then 
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
    ]]

-- load serializer into mission env
    net.dostring_in('mission', code)
    
    -- parse available slots
    local slot_parser = [[
        local side_parser = function(side)
            local i,v
            local slots = {}
            for i,v in ipairs(side) do
                local u = { unit_id = v.unitId, type = v.type, onboard_num = v.onboard_num }
                local group = v.group
                if group then
                    u.group_name = group.name
                    u.group_task = group.task
                    u.country_name = group.country.name
                end
                table.insert(slots, u)
            end
            return slots
        end
        local res = { red = side_parser(db.clients.red), blue = side_parser(db.clients.blue) }
        return serialize(res)
    ]]
    local val, res = net.dostring_in('mission', slot_parser)
    --net.log(string.format("%s: (%s) %q", 'mission', tostring(res), val))
    local slots = {}
    if res then
        local t = loadstring('return '..val)
        slots = t()
    else
        slots = {}
    end
    veafServerHook.logTrace(string.format("slots=%s",p(slots)))

    veafServerHook.logTrace(string.format("testing"))
    local code = [[
        return veafRemote.getTestValue({"[all]"}, true, true)
    ]]
    local _status, _retValue = pcall(net.dostring_in, 'mission', code)
    veafServerHook.logTrace(string.format("_status=%s",p(_status)))
    veafServerHook.logTrace(string.format("_retValue=%s",p(_retValue)))
    veafServerHook.logTrace(string.format("type(_retValue)=%s",p(type(_retValue))))

    veafServerHook.logTrace(string.format("testing 2"))
    local code = [[
        return "42"
    ]]
    local _status, _retValue = pcall(net.dostring_in, 'mission', code)
    veafServerHook.logTrace(string.format("_status=%s",p(_status)))
    veafServerHook.logTrace(string.format("_retValue=%s",p(_retValue)))
    veafServerHook.logTrace(string.format("type(_retValue)=%s",p(type(_retValue))))

    veafServerHook.logTrace(string.format("testing 3"))
    local code = [[
        local n = 0
        for i, gp in pairs(mission.coalition.getGroups(2)) do
            n = n + 1
        end
        return tostring(n)
    ]]
    local _status, _retValue = pcall(net.dostring_in, 'mission', code)
    veafServerHook.logTrace(string.format("_status=%s",p(_status)))
    veafServerHook.logTrace(string.format("_retValue=%s",p(_retValue)))
    veafServerHook.logTrace(string.format("type(_retValue)=%s",p(type(_retValue))))

    veafServerHook.logTrace(string.format("testing 4"))
    local code = [[
        return mission.theatre
    ]]
    local _status, _retValue = pcall(net.dostring_in, 'mission', code)
    veafServerHook.logTrace(string.format("_status=%s",p(_status)))
    veafServerHook.logTrace(string.format("_retValue=%s",p(_retValue)))
    veafServerHook.logTrace(string.format("type(_retValue)=%s",p(type(_retValue))))

    veafServerHook.logTrace(string.format("testing 5"))
    local code = [[
        return mission.theatre
    ]]
    local _status, _retValue = pcall(net.dostring_in, 'mission', code)
    veafServerHook.logTrace(string.format("_status=%s",p(_status)))
    veafServerHook.logTrace(string.format("_retValue=%s",p(_retValue)))
    veafServerHook.logTrace(string.format("type(_retValue)=%s",p(type(_retValue))))

    veafServerHook.logTrace(string.format("testing 6"))
    local code = [[
        return p(mission, 0, 2)
    ]]
    local _status, _retValue = pcall(net.dostring_in, 'mission', code)
    veafServerHook.logTrace(string.format("_status=%s",p(_status)))
    veafServerHook.logTrace(string.format("_retValue=%s",p(_retValue)))
    veafServerHook.logTrace(string.format("type(_retValue)=%s",p(type(_retValue))))

    veafServerHook.logTrace(string.format("testing 7"))
    local code = [[
        return p("test 7")
    ]]
    local _status, _retValue = pcall(net.dostring_in, 'mission', code)
    veafServerHook.logTrace(string.format("_status=%s",p(_status)))
    veafServerHook.logTrace(string.format("_retValue=%s",p(_retValue)))
    veafServerHook.logTrace(string.format("type(_retValue)=%s",p(type(_retValue))))

    veafServerHook.logTrace(string.format("testing 8"))
    local code = [[
        local keys = {}
        for k, v in pairs(mission) do
        keys[#keys+1] = k  
        end
        return p(keys)
    ]]
    local _status, _retValue = pcall(net.dostring_in, 'mission', code)
    veafServerHook.logTrace(string.format("_status=%s",p(_status)))
    veafServerHook.logTrace(string.format("_retValue=%s",p(_retValue)))
    veafServerHook.logTrace(string.format("type(_retValue)=%s",p(type(_retValue))))

    veafServerHook.logTrace(string.format("testing 9"))
    local code = [[
        local keys = {}
        for k, v in pairs(db) do
        keys[#keys+1] = k  
        end
        return p(keys)
    ]]
    local _status, _retValue = pcall(net.dostring_in, 'mission', code)
    veafServerHook.logTrace(string.format("_status=%s",p(_status)))
    veafServerHook.logTrace(string.format("_retValue=%s",p(_retValue)))
    veafServerHook.logTrace(string.format("type(_retValue)=%s",p(type(_retValue))))

    veafServerHook.logTrace(string.format("testing A"))
    local code = [[
        local keys = {}
        for k, v in pairs(_G) do
        keys[#keys+1] = k  
        end
        return p(keys)
    ]]
    local _status, _retValue = pcall(net.dostring_in, 'mission', code)
    veafServerHook.logTrace(string.format("_status=%s",p(_status)))
    veafServerHook.logTrace(string.format("_retValue=%s",p(_retValue)))
    veafServerHook.logTrace(string.format("type(_retValue)=%s",p(type(_retValue))))

    veafServerHook.logTrace(string.format("get list of units"))
    local code = [[
        if veafRemote and veafRemote.getUnitsListForRemote then 
            return veafRemote.getUnitsListForRemote({"[all]"}, true, true)
        else 
            return nil
        end
    ]]
    local _status, _retValue = pcall(net.dostring_in, 'mission', code)
    veafServerHook.logTrace(string.format("_status=%s",p(_status)))
    veafServerHook.logTrace(string.format("_retValue=%s",p(_retValue)))
    veafServerHook.logTrace(string.format("type(_retValue)=%s",p(type(_retValue))))
    if not _status then
        veafServerHook.logWarning(string.format("Code injection failed for veafRemote.getUnitsListForRemote()"))
    else
        data_package.unitsAsJson = _retValue
    end

    -- prepare the data package
    veafServerHook.logTrace(string.format("prepare the data package"))
    veafServerHook.logTrace(string.format("data_package=%s",p(data_package)))

    local _payload = net.lua2json(data_package);

    veafServerHook.logTrace(string.format("_payload=%s",p(_payload)))

    -- send the payload
    veafServerHook.logTrace(string.format("send the payload"))
    BufferingSocket.send(_payload)

    veafServerHook.logTrace(string.format("send the EOT"))
    BufferingSocket.send(veafServerHook.EOT_MARKER)
end

function veafServerHook.parse(pilot, playerName, ucid, unitName, message)
    veafServerHook.logTrace(string.format("veafServerHook.parse([%s] , [%s])", p(playerName), p(message)))
    veafServerHook.logTrace(string.format("pilot=%s",p(pilot)))
    veafServerHook.logTrace(string.format("unitName=%s",p(unitName)))
    
    if not pilot then
        veafServerHook.logWarning(string.format("Unknown pilot [%s] sent chat message [%s])",p(playerName), p(message)))
    end

    local _module, _command = message:match(veafServerHook.CommandParser)
    veafServerHook.logTrace(string.format("_module=%s",p(_module)))
    veafServerHook.logTrace(string.format("_command=%s",p(_command)))
    if pilot.level > 0 then
        -- register the player
        local payload = string.format(REGISTER_PLAYER, playerName, pilot.level, ucid)
        veafServerHook.logTrace(string.format("payload=%s",p(payload)))
        veafServerHook.injectCode(payload)
    end
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
    elseif _module and _module:lower() == "restartnow" then
        -- only level >= 30 can schedule mission restart without waiting for all to disconnect
        if pilot.level >= 30 then
            veafServerHook.maxMissionDuration = 0
            veafServerHook.closeServerAtLastDisconnect = false
            veafServerHook.stopMissionIfNeeded()
            return true
        end
    elseif _module and _module:lower() == "halt" then
        -- only level >= 10 can schedule server halt (and hopefully autorestart)
        if pilot.level >= 10 then
            veafServerHook.maxMissionDuration = 0
            veafServerHook.closeServerAtLastDisconnect = true
            local _message = string.format("[%s] is asking for server halt when the last pilot disconnects from the server",p(playerName))
            veafServerHook.logInfo(_message)
            veafServerHook.sendMessage(_message, 10)
            veafServerHook.stopMissionIfNeeded()
            return true
        end
    elseif _module and _module:lower() == "haltnow" then
        -- only level >= 50 can trigger server halt without waiting for all to disconnect
        if pilot.level >= 50 then
            veafServerHook.closeServerAtMissionStop = true
            veafServerHook.onSimulationStop()
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
    if _modelTimeInSeconds >= veafServerHook.maxMissionDuration * 60 then
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

-- set up the socket to call the web server
veafServerHook.logDebug(string.format("set up the socket to call the web server; host=%s and port=%s", p(veafServerHook.config.host), p(veafServerHook.config.port)))
BufferingSocket.startSession(veafServerHook.config.host, veafServerHook.config.port)

veafServerHook.logDebug(string.format("registering DCS callbacks"))
DCS.setUserCallbacks(veafServerHook)