------------------------------------------------------------------
-- VEAF remote callback functions for DCS World
-- By zip (2020)
--
-- Features:
-- ---------
-- * This module offers support for calling script from a web server or a server hook
--
-- See the documentation : https://veaf.github.io/documentation/
------------------------------------------------------------------

veafRemote = {}

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Global settings. Stores the script constants
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Identifier. All output in DCS.log will start with this.
veafRemote.Id = "REMOTE"

--- Version.
veafRemote.Version = "2.2.0"

-- trace level, specific to this module
--veafRemote.LogLevel = "trace"

veaf.loggers.new(veafRemote.Id, veafRemote.LogLevel)

-- if false, SLMOD will not be called for regular commands
veafRemote.USE_SLMOD = false

-- if false, SLMOD will never be called
veafRemote.USE_SLMOD_FOR_SPECIAL_COMMANDS = false

veafRemote.SecondsBetweenFlagMonitorChecks = 5

veafRemote.CommandStarter = "_remote"

veafRemote.MIN_LEVEL_FOR_MARKER = 10

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Do not change anything below unless you know what you are doing!
-------------------------------------------------------------------------------------------------------------------------------------------------------------

veafRemote.monitoredFlags = {}
veafRemote.monitoredCommands = {}
veafRemote.maxMonitoredFlag = 27000
veafRemote.remoteUsers = {}
veafRemote.remoteUnitsPilots = {}

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Utility methods
-------------------------------------------------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- NIOD callbacks
-------------------------------------------------------------------------------------------------------------------------------------------------------------

function veafRemote.addNiodCallback(name, parameters, code)
    if niod then
        veaf.loggers.get(veafRemote.Id):info("Adding NIOD function "..name)
        niod.functions[name] = function(payload)
        -- start of inline function

            veaf.loggers.get(veafRemote.Id):debug(string.format("niod callback [%s] was called with payload %s", veaf.p(name), veaf.p(payload)))

            local errors = {}

            -- check mandatory parameters presence
            for parameterName, parameterData in pairs(parameters) do
                veaf.loggers.get(veafRemote.Id):trace(string.format("checking if parameter [%s] is mandatory", veaf.p(parameterName)))
                if parameterData and parameterData.mandatory then
                    if not (payload and payload[parameterName]) then
                        local text = "missing mandatory parameter "..parameterName
                        veaf.loggers.get(veafRemote.Id):trace(text)
                        table.insert(errors, text)
                    end
                end
            end

            -- check parameters type
            if payload then
                for parameterName, value in pairs(payload) do
                    local parameter = parameters[parameterName]
                    if not parameter then
                        table.insert(errors, "unknown parameter "..parameterName)
                    elseif value and not(type(value) == parameter.type) then
                        local text =  string.format("parameter %s should have type %s, has %s ", parameterName, parameter.type, type(value))
                        veaf.loggers.get(veafRemote.Id):trace(text)
                        table.insert(errors, text)
                    end
                end
            end

            -- stop on error
            if #errors > 0 then
                local errorMessage = ""
                for _, error in pairs(errors) do
                    errorMessage = errorMessage .. "\n" .. error
                end
                veaf.loggers.get(veafRemote.Id):error(string.format("niod callback [%s] was called with incorrect parameters :", veaf.p(name), errorMessage))
                return errorMessage
            else
                veaf.loggers.get(veafRemote.Id):trace(string.format("payload = %s", veaf.p(payload)))
                veaf.loggers.get(veafRemote.Id):trace(string.format("unpacked payload = %s", veaf.p(veaf.safeUnpack(payload))))
                local status, retval = pcall(code,veaf.safeUnpack(payload))
                if status then
                    return retval
                else
                    return "an error occured : "..veaf.p(status)
                end
            end

        end -- of inline function

    else
        veaf.loggers.get(veafRemote.Id):error("NIOD is not loaded !")
    end
end

function veafRemote.addNiodCommand(name, command)
    veafRemote.addNiodCallback(
        name,
        {
            parameters={   mandatory=false, type="string"},
            x={   mandatory=false, type="number"},
            y={   mandatory=false, type="number"},
            z={   mandatory=false, type="number"},
            silent={    mandatory=false, type="boolean"}
        },
        function(parameters, x, y, z, silent)
            veaf.loggers.get(veafRemote.Id):debug(string.format("niod->command %s (%s, %s, %s, %s, %s)", veaf.p(parameters), veaf.p(x), veaf.p(y), veaf.p(z), veaf.p(silent)))
            return veafRemote.executeCommand({x=x or 0, y=y or 0, z=z or 0}, command..parameters)
        end
    )
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- default endpoints list
-------------------------------------------------------------------------------------------------------------------------------------------------------------

function veafRemote.buildDefaultList()
    local TEST = false
    if TEST then

        -- test
        veafRemote.addNiodCallback(
            "test",
            {
                param1S_M={  mandatory=true, type="string"},
                param2S={  mandatory=false, type="string"},
                param3N={  mandatory=false, type="number"},
                param4B={  mandatory=false, type="boolean"},
            },
            function(param1S_M, param2S, param3N, param4B)
                local text = string.format("niod.test(%s, %s, %s, %s)", veaf.p(param1S_M), veaf.p(param2S), veaf.p(param3N), veaf.p(param4B))
                veaf.loggers.get(veafRemote.Id):debug(text)
                trigger.action.outText(text, 15)
            end
        )
        -- login
        veafRemote.addNiodCallback(
            "login",
            {
                password={  mandatory=true, type="string"},
                timeout={   mandatory=false, type="number"},
                silent={    mandatory=false, type="boolean"}
            },
            function(password, timeout, silent)
                veaf.loggers.get(veafRemote.Id):debug(string.format("niod.login(%s, %s, %s)",veaf.p(password), veaf.p(timeout),veaf.p(silent))) -- TODO remove password from log
                if veafSecurity.checkPassword_L1(password) then
                    veafSecurity.authenticate(timeout)
                    return "Mission is unlocked"
                else
                    return "wrong password"
                end
            end
        )

    end
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Event handler functions.
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Function executed when a mark has changed. This happens when text is entered or changed.
function veafRemote.onEventMarkChange(eventPos, event)
    if veafRemote.executeCommand(eventPos, event.text) then

        -- Delete old mark.
        veaf.loggers.get(veafRemote.Id):trace(string.format("Removing mark # %d.", event.idx))
        trigger.action.removeMark(event.idx)

    end
end


function veafRemote.executeCommand(eventPos, eventText)
    veaf.loggers.get(veafRemote.Id):debug(string.format("veafRemote.executeCommand(eventText=[%s])", tostring(eventText)))

    -- Check if marker has a text and the veafRemote.CommandStarter keyphrase.
    if eventText ~= nil and eventText:lower():find(veafRemote.CommandStarter) then

        -- Analyse the mark point text and extract the keywords.
        local command, password = veafRemote.markTextAnalysis(eventText)

        if command then
            -- do the magic
            return veafRemote.executeRemoteCommand(command, password)
        end
    end
end

--- Extract keywords from mark text.
function veafRemote.markTextAnalysis(text)
    veaf.loggers.get(veafRemote.Id):trace(string.format("veafRemote.markTextAnalysis(text=[%s])", tostring(text)))

    if text then
        -- extract command and password
        local password, command = text:match(veafRemote.CommandStarter.."#?([^%s]*)%s+(.+)")
        if command then
            veaf.loggers.get(veafRemote.Id):trace(string.format("command = [%s]", command))
            return command, password
        end
    end
    return nil
end

-- execute a command
function veafRemote.executeRemoteCommand(command, password)
    local command = command or ""
    local password = password or ""
    veaf.loggers.get(veafRemote.Id):debug(string.format("veafRemote.executeRemoteCommand([%s])",command))
    if not(veafSecurity.checkPassword_L1(password)) then
        veaf.loggers.get(veafRemote.Id):error(string.format("veafRemote.executeRemoteCommand([%s]) - bad or missing password",command))
        trigger.action.outText("Bad or missing password",5)
        return false
    end
    local commandData = veafRemote.monitoredCommands[command:lower()]
    if commandData then
        local scriptToExecute = commandData.script
        veaf.loggers.get(veafRemote.Id):trace(string.format("found script [%s] for command [%s]", scriptToExecute, command))
        local authorized = (not(commandData.requireAdmin)) or (veafSecurity.checkSecurity_L9(password))
        if not authorized then
            return false
        else
            local result, err = mist.utils.dostring(scriptToExecute)
            if result then
                veaf.loggers.get(veafRemote.Id):debug(string.format("veafRemote.executeRemoteCommand() - lua code was successfully called for script [%s]", scriptToExecute))
                return true
            else
                veaf.loggers.get(veafRemote.Id):error(string.format("veafRemote.executeRemoteCommand() - error [%s] calling lua code for script [%s]", err, scriptToExecute))
                return false
            end
        end
    else
        veaf.loggers.get(veafRemote.Id):warn(string.format("veafRemote.executeRemoteCommand : cannot find command [%s]",command or ""))
    end
    return false
end

-- execute command from the remote interface (see VEAF-server-hook.lua)
function veafRemote.executeCommandFromRemote(username, level, unitName, veafModule, command)
    veaf.loggers.get(veafRemote.Id):debug(string.format("veafRemote.executeCommandFromRemote([%s], [%s], [%s], [%s], [%s])", veaf.p(username), veaf.p(level), veaf.p(unitName), veaf.p(veafModule), veaf.p(command)))
    --local _user = veafRemote.getRemoteUser(username)
    --veaf.loggers.get(veafRemote.Id):trace(string.format("_user = [%s]",veaf.p(_user)))
    --if not _user then 
    --    return false
    --end
    if not veafModule or not username or not command then
        return false
    end
    local _user = { name = username, level = tonumber(level or "-1")}
    local _parameters = { _user, username, unitName, command }
    local _status, _retval
    local _module = veafModule:lower()
    if _module == "air" then
        veaf.loggers.get(veafRemote.Id):debug(string.format("running veafCombatMission.executeCommandFromRemote"))
        _status, _retval = pcall(veafCombatMission.executeCommandFromRemote, _parameters)
    elseif _module == "point" then
        veaf.loggers.get(veafRemote.Id):debug(string.format("running veafNamedPoints.executeCommandFromRemote"))
        _status, _retval = pcall(veafNamedPoints.executeCommandFromRemote, _parameters)
    elseif _module == "alias" then
        veaf.loggers.get(veafRemote.Id):debug(string.format("running veafShortcuts.executeCommandFromRemote"))
        _status, _retval = pcall(veafShortcuts.executeCommandFromRemote, _parameters)
    elseif _module == "carrier" then
        veaf.loggers.get(veafRemote.Id):debug(string.format("running veafShortcuts.executeCommandFromRemote"))
        _status, _retval = pcall(veafCarrierOperations.executeCommandFromRemote, _parameters)
    elseif _module == "secu" then
        veaf.loggers.get(veafRemote.Id):debug(string.format("running veafSecurity.executeCommandFromRemote"))
        _status, _retval = pcall(veafSecurity.executeCommandFromRemote, _parameters)
    else
        veaf.loggers.get(veafRemote.Id):error(string.format("Module not found : [%s]", veaf.p(veafModule)))
        return false
    end
    veaf.loggers.get(veafRemote.Id):trace(string.format("_status = [%s]",veaf.p(_status)))
    veaf.loggers.get(veafRemote.Id):trace(string.format("_retval = [%s]",veaf.p(_retval)))
    if not _status then
        veaf.loggers.get(veafRemote.Id):error(string.format("Error when [%s] tried running [%s] in module [%s]; it returned %s", veaf.p(_user.name), veaf.p(_parameters), veaf.p(veafModule), veaf.p(_retval)))
    else
        veaf.loggers.get(veafRemote.Id):info(string.format("[%s] ran [%s] in module [%s]; it returned %s", veaf.p(_user.name), veaf.p(_parameters), veaf.p(veafModule), veaf.p(_retval)))
    end
    return _status
end

-- register a user from the server
function veafRemote.registerUser(username, userpower, ucid)
    veaf.loggers.get(veafRemote.Id):debug(string.format("veafRemote.registerUser([%s], [%s], [%s])",veaf.p(username), veaf.p(userpower), veaf.p(ucid)))
    if not username or not ucid then
        return false
    end
    veafRemote.remoteUsers[username:lower()] = { name = username, level = tonumber(userpower or "-1"), ucid = ucid }
end

-- register a user slot from the server; called when the player changes slot
function veafRemote.registerUserSlot(username, ucid, unitName)
    veaf.loggers.get(veafRemote.Id):debug(string.format("veafRemote.registerUserSlot([%s], [%s], [%s])",veaf.p(username), veaf.p(ucid), veaf.p(unitName)))
    if not username or not unitName then
        return false
    end
    local remoteUser = veafRemote.remoteUsers[username:lower()]
    if not remoteUser then
        remoteUser = { name = username, ucid = ucid}
    end
    local previousUnit = remoteUser.unitName
    remoteUser.unitName = unitName -- can be nil if the player got out of the unit
    -- unregister the previous unit, if any
    if previousUnit then
        veafRemote.remoteUnitsPilots[previousUnit] = nil
    end
    -- register the current unit, if any
    if unitName then
        veafRemote.remoteUnitsPilots[unitName] = remoteUser
    end
end

-- return a user from the server table
function veafRemote.getRemoteUser(username)
    veaf.loggers.get(veafRemote.Id):debug(string.format("veafRemote.getRemoteUser([%s])",veaf.p(username)))
    veaf.loggers.get(veafRemote.Id):trace(string.format("veafRemote.remoteUsers = [%s]",veaf.p(veafRemote.remoteUsers)))
    if not username then
        return nil
    end
    return veafRemote.remoteUsers[username:lower()]
end

-- return a user from the server units table
function veafRemote.getRemoteUserFromUnit(unitName)
    veaf.loggers.get(veafRemote.Id):debug(string.format("veafRemote.getRemoteUserFromUnit([%s])",veaf.p(unitName)))
    veaf.loggers.get(veafRemote.Id):trace(string.format("veafRemote.remoteUnitsPilots = [%s]",veaf.p(veafRemote.remoteUnitsPilots)))
    if not unitName then
        return nil
    end
    return veafRemote.remoteUnitsPilots[unitName]
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- initialisation
-------------------------------------------------------------------------------------------------------------------------------------------------------------

function veafRemote.initialize()
    veaf.loggers.get(veafRemote.Id):info("Initializing module")
    veafRemote.buildDefaultList()
    veafMarkers.registerEventHandler(veafMarkers.MarkerChange, veafRemote.onEventMarkChange)
end

veaf.loggers.get(veafRemote.Id):info(string.format("Loading version %s", veafRemote.Version))
