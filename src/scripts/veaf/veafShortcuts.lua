------------------------------------------------------------------
-- VEAF shortcuts supporting functions for DCS World
-- By zip (2020)
--
-- Features:
-- ---------
-- * This module offers support for commands aliases and radio menu shortcuts
--
-- See the documentation : https://veaf.github.io/documentation/
------------------------------------------------------------------

veafShortcuts = {}

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Global settings. Stores the script constants
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Identifier. All output in DCS.log will start with this.
veafShortcuts.Id = "SHORTCUTS"

--- Version.
veafShortcuts.Version = "1.31.0"

-- trace level, specific to this module
--veafShortcuts.LogLevel = "trace"

veaf.loggers.new(veafShortcuts.Id, veafShortcuts.LogLevel)

veafShortcuts.RadioMenuName = "SHORTCUTS"

veafShortcuts.AliasStarter = "-"

veafShortcuts.RemoteCommandParser = "([a-zA-Z0-9:\\.-]+)%s(.*)"

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Do not change anything below unless you know what you are doing!
-------------------------------------------------------------------------------------------------------------------------------------------------------------

-- Aliases list (table of VeafAlias objects)
veafShortcuts.aliases = {}

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Utility methods
-------------------------------------------------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- VeafAlias object
-------------------------------------------------------------------------------------------------------------------------------------------------------------
VeafAlias = {}

function VeafAlias:new(objectToCopy)
    local objectToCreate = objectToCopy or {} -- create object if user does not provide one
    setmetatable(objectToCreate, self)
    self.__index = self
    
    -- init the new object
    
    -- name
    objectToCreate.name = nil
    -- description
    objectToCreate.description = nil
    -- hidden from HELP
    objectToCreate.hidden = false
    -- the command that must be substituted to the alias
    objectToCreate.veafCommand = nil
    -- list of parameters that will be randomized if not present
    objectToCreate.randomParameters = {}
    -- if TRUE, security is bypassed
    objectToCreate.bypassSecurity = false
    -- if set, the alias will actually be a batch of aliases to execute in order
    objectToCreate.batchAliases = nil
    -- if set, the alias is password protected with a specific password
    objectToCreate.password = nil
    -- if set, we'll consider that the alias ends with a comma (to easily add the first parameter)
    objectToCreate.endsWithComma = true

    return objectToCreate
end

---
--- setters and getters
---

function VeafAlias:setName(value)
    veaf.loggers.get(veafShortcuts.Id):trace(string.format("VeafAlias[%s]:setName([%s])", veaf.p(self.name) or "", value or ""))
    self.name = value
    return self
end

function VeafAlias:getName()
    return self.name
end

function VeafAlias:setVeafCommand(value)
    veaf.loggers.get(veafShortcuts.Id):trace(string.format("VeafAlias[%s]:setVeafCommand([%s])", veaf.p(self.name), value or ""))
    self.veafCommand = value
    return self
end

function VeafAlias:getVeafCommand()
    return self.veafCommand
end

function VeafAlias:setEndsWithComma(value)
    veaf.loggers.get(veafShortcuts.Id):trace(string.format("VeafAlias[%s]:setEndsWithComma([%s])", veaf.p(self.name), value or ""))
    self.endsWithComma = value
    return self
end

function VeafAlias:isEndsWithComma()
    return self.endsWithComma
end

function VeafAlias:addRandomParameter(name, low, high)
    veaf.loggers.get(veafShortcuts.Id):trace(string.format("VeafAlias[%s]:addRandomParameter([%s], %s, %s)", veaf.p(self.name), name or "", low or "", high or ""))
    table.insert(self.randomParameters, { name = name, low = low or 1, high = high or 6})
    return self
end

function VeafAlias:getRandomParameters()
    return self.randomParameters
end

function VeafAlias:dontEndWithComma()
    veaf.loggers.get(veafShortcuts.Id):trace(string.format("VeafAlias[%s]:dontEndWithComma()", veaf.p(self.name)))
    self:setEndsWithComma(false)
    return self
end

function VeafAlias:setDescription(value)
    veaf.loggers.get(veafShortcuts.Id):trace(string.format("VeafAlias[%s]:setDescription([%s])", veaf.p(self.name), value or ""))
    self.description = value
    return self
end

function VeafAlias:getDescription()
    return self.description
end

function VeafAlias:setBypassSecurity(value)
    veaf.loggers.get(veafShortcuts.Id):trace(string.format("VeafAlias[%s]:setBypassSecurity([%s])", veaf.p(self.name), tostring(value) or ""))
    self.bypassSecurity = value
    return self
end

function VeafAlias:isBypassSecurity()
    return self.bypassSecurity
end

function VeafAlias:setHidden(value)
    veaf.loggers.get(veafShortcuts.Id):trace(string.format("VeafAlias[%s]:setHidden([%s])", veaf.p(self.name), tostring(value) or ""))
    self.hidden = value
    return self
end

function VeafAlias:isHidden()
    return self.hidden
end

function VeafAlias:setBatchAliases(value)
    veaf.loggers.get(veafShortcuts.Id):trace("VeafAlias[%s]:setBatchAliases([%s])", veaf.p(self.name), veaf.p(value))
    self.batchAliases = value
    -- by default, batches are hidden and have a L1 password
    self:setPassword(veafSecurity.PASSWORD_L1)
    self:setHidden(true)
    return self
end

function VeafAlias:getBatchAliases()
    return self.batchAliases
end

function VeafAlias:setPassword(value)
    veaf.loggers.get(veafShortcuts.Id):trace("VeafAlias[%s]:setPassword([%s])", veaf.p(self.name), veaf.p(value))
    self.password = {}
    self.password[value] = true
    return self
end

function VeafAlias:hasPassword(value)
    return self.password and self.password[value]
end

function VeafAlias:execute(remainingCommand, position, coalition, markId, bypassSecurity, spawnedGroups, route)
    local function logDebug(message)
        veaf.loggers.get(veafShortcuts.Id):debug(message)
        return true
    end

    veaf.loggers.get(veafShortcuts.Id):trace(string.format("markId=[%s]",veaf.p(markId)))

    local command = self:getVeafCommand()
    for _, parameter in pairs(self:getRandomParameters()) do
        veaf.loggers.get(veafShortcuts.Id):trace(string.format("randomizing [%s]",parameter.name or ""))
        local value = math.random(parameter.low, parameter.high)
        veaf.loggers.get(veafShortcuts.Id):trace(string.format("got [%d]",value))
        command = string.format("%s, %s %d",command, parameter.name, value)
    end
    if self:isEndsWithComma() then
        veaf.loggers.get(veafShortcuts.Id):trace("adding a comma")
        command = command .. ", "
    end

    local _bypassSecurity = bypassSecurity or self:isBypassSecurity()

    local command = command .. (remainingCommand or "")
    veaf.loggers.get(veafShortcuts.Id):trace(string.format("command = [%s]",command or ""))

    if logDebug("checking in veafShortcuts") and veafShortcuts.executeCommand(position, command, coalition, markId, _bypassSecurity, spawnedGroups, route) then
        return true
    elseif logDebug("checking in veafSpawn") and veafSpawn.executeCommand(position, command, coalition, markId, _bypassSecurity, spawnedGroups, nil, nil, route) then
        return true
    elseif logDebug("checking in veafNamedPoints") and veafNamedPoints.executeCommand(position, {text=command, coalition=-1}, _bypassSecurity) then
        return true
    elseif logDebug("checking in veafCasMission") and veafCasMission.executeCommand(position, command, coalition, _bypassSecurity) then
        return true
    elseif logDebug("checking in veafSecurity") and veafSecurity.executeCommand(position, command, _bypassSecurity) then
        return true
    elseif logDebug("checking in veafMove") and veafMove.executeCommand(position, command, _bypassSecurity) then
        return true
    elseif logDebug("checking in veafRadio") and veafRadio.executeCommand(position, command, coalition, _bypassSecurity) then
        return true
    elseif logDebug("checking in veafRemote") and veafRemote.executeCommand(position, command) then
        return true
    else
        return false
    end
end

---
--- other methods
---

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- VeafAliasForCombatMission object
-------------------------------------------------------------------------------------------------------------------------------------------------------------
VeafAliasForCombatMission = {}
VeafAliasForCombatMission.__index = VeafAliasForCombatMission

function VeafAliasForCombatMission:new()
    local self = setmetatable(mist.utils.deepCopy(VeafAlias:new()), VeafAliasForCombatMission)
    self:setPassword(veafSecurity.PASSWORD_L1)
    self:setHidden(true)
    return self
end

setmetatable(VeafAliasForCombatMission, {__index = VeafAlias})

---
--- overloaded members
---

function VeafAliasForCombatMission:execute(remainingCommand, position, coalition, markId, bypassSecurity, spawnedGroups)
    veaf.loggers.get(veafShortcuts.Id):trace("VeafAliasForCombatMission[%s]:execute([%s])", veaf.p(self.name), veaf.p(remainingCommand))

    local command = self:getVeafCommand()
    for _, parameter in pairs(self:getRandomParameters()) do
        veaf.loggers.get(veafShortcuts.Id):trace(string.format("randomizing [%s]",parameter.name or ""))
        local value = math.random(parameter.low, parameter.high)
        veaf.loggers.get(veafShortcuts.Id):trace(string.format("got [%d]",value))
        command = string.format("%s, %s %d",command, parameter.name, value)
    end
    if self:isEndsWithComma() then
        veaf.loggers.get(veafShortcuts.Id):trace("adding a comma")
        command = command .. ", "
    end

    local _bypassSecurity = bypassSecurity or self:isBypassSecurity()

    local command = command .. (remainingCommand or "")
    veaf.loggers.get(veafShortcuts.Id):trace("command=%s", veaf.p(command))

    local keywords = veaf.split(command, ",")

    local silent = false
    local missionName = nil
    local password = nil
    for _, keyphrase in pairs(keywords) do
        local str = veaf.breakString(veaf.trim(keyphrase), " ")
        local key = str[1]
        local val = str[2] or ""

        if key:lower() == "silent" then
            silent = true
        end

        if key:lower() == "name" then
            missionName = val
        end

        if key:lower() == "password" then
            password = val
        end
    end

    if not (bypassSecurity or veafSecurity.isAuthenticated()) then
        veaf.loggers.get(veafShortcuts.Id):trace("password=%s", veaf.p(password))
        local hash = nil
        if password then 
            hash = sha1.hex(password)
        end
        if not(self:hasPassword(hash)) then
            veaf.loggers.get(veafShortcuts.Id):warn("You have to give the correct alias password for %s to do this", self:getName())
            trigger.action.outText("Please use the ', password <alias password>' option", 5)
            return false
        end
    end

    veaf.loggers.get(veafShortcuts.Id):trace("missionName=%s", veaf.p(missionName))
    veaf.loggers.get(veafShortcuts.Id):trace("silent=%s", veaf.p(silent))

    if not missionName or #missionName == 0 then
        local msg = string.format("VeafAliasForCombatMission: mission name is mandatory")
        veaf.loggers.get(veafShortcuts.Id):warn(msg)
        trigger.action.outText(msg, 5)
        return false
    end

    local mission = veafCombatMission.GetMission(missionName)
    if not mission then 
        local msg = string.format("VeafAliasForCombatMission: mission %s does not exist", veaf.p(missionName))
        veaf.loggers.get(veafShortcuts.Id):warn(msg)
        trigger.action.outText(msg, 5)
        return false
    end

    --veaf.loggers.get(veafShortcuts.Id):trace("mission=%s", veaf.p(mission))

    if command:lower():sub(1, 5) == "start" then
        local result = veafCombatMission.ActivateMission(missionName, silent)
        return result
    elseif command:lower():sub(1, 4) == "stop" then
        local result = veafCombatMission.DesactivateMission(missionName, silent)
        return result
    end

end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- VeafAliasForCombatZone object
-------------------------------------------------------------------------------------------------------------------------------------------------------------
VeafAliasForCombatZone = VeafAlias:new()

function VeafAliasForCombatZone:new(objectToCopy)
    local objectToCreate = objectToCopy or {} -- create object if user does not provide one
    setmetatable(objectToCreate, self)
    self.__index = self

    -- init the new object
    self:setPassword(veafSecurity.PASSWORD_L1)
    self:setHidden(true)  

    return objectToCreate
  end

---
--- overloaded members
---

function VeafAliasForCombatZone:execute(remainingCommand, position, coalition, markId, bypassSecurity, spawnedGroups)
    veaf.loggers.get(veafShortcuts.Id):trace("VeafAliasForCombatZone[%s]:execute([%s])", veaf.p(self.name), veaf.p(remainingCommand))

    local command = self:getVeafCommand()
    for _, parameter in pairs(self:getRandomParameters()) do
        veaf.loggers.get(veafShortcuts.Id):trace(string.format("randomizing [%s]",parameter.name or ""))
        local value = math.random(parameter.low, parameter.high)
        veaf.loggers.get(veafShortcuts.Id):trace(string.format("got [%d]",value))
        command = string.format("%s, %s %d",command, parameter.name, value)
    end
    if self:isEndsWithComma() then
        veaf.loggers.get(veafShortcuts.Id):trace("adding a comma")
        command = command .. ", "
    end

    local _bypassSecurity = bypassSecurity or self:isBypassSecurity()

    local command = command .. (remainingCommand or "")
    veaf.loggers.get(veafShortcuts.Id):trace("command=%s", veaf.p(command))

    local keywords = veaf.split(command, ",")

    local silent = false
    local zoneName = nil
    local password = nil
    for _, keyphrase in pairs(keywords) do
        local str = veaf.breakString(veaf.trim(keyphrase), " ")
        local key = str[1]
        local val = str[2] or ""

        if key:lower() == "silent" then
            silent = true
        end

        if key:lower() == "name" then
            zoneName = val
        end

        if key:lower() == "password" then
            password = val
        end
    end

    if not (bypassSecurity or veafSecurity.isAuthenticated()) then
        veaf.loggers.get(veafShortcuts.Id):trace("password=%s", veaf.p(password))
        local hash = nil
        if password then 
            hash = sha1.hex(password)
        end
        if not(self:hasPassword(hash)) then
            veaf.loggers.get(veafShortcuts.Id):warn("You have to give the correct alias password for %s to do this", self:getName())
            trigger.action.outText("Please use the ', password <alias password>' option", 5)
            return false
        end
    end

    veaf.loggers.get(veafShortcuts.Id):trace("zoneName=%s", veaf.p(zoneName))
    veaf.loggers.get(veafShortcuts.Id):trace("silent=%s", veaf.p(silent))

    if not zoneName or #zoneName == 0 then
        local msg = string.format("VeafAliasForCombatZone: zone name is mandatory")
        veaf.loggers.get(veafShortcuts.Id):warn(msg)
        trigger.action.outText(msg, 5)
        return false
    end

    local zone = veafCombatZone.GetZone(zoneName)
    if not zone then 
        local msg = string.format("VeafAliasForCombatZone: zone %s does not exist", veaf.p(zoneName))
        veaf.loggers.get(veafShortcuts.Id):warn(msg)
        trigger.action.outText(msg, 5)
        return false
    end

    --veaf.loggers.get(veafShortcuts.Id):trace("zone=%s", veaf.p(zone))

    if command:lower():sub(1, 5) == "start" then
        local result = veafCombatZone.ActivateZone(zoneName, silent)
        return result
    elseif command:lower():sub(1, 4) == "stop" then
        local result = veafCombatZone.DesactivateZone(zoneName, silent)
        return result
    end

end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- global functions
-------------------------------------------------------------------------------------------------------------------------------------------------------------

-- search for an alias
function veafShortcuts.GetAlias(aliasName)
    veaf.loggers.get(veafShortcuts.Id):debug(string.format("veafShortcuts.GetAlias([%s])",aliasName or ""))
    veaf.loggers.get(veafShortcuts.Id):debug(string.format("Searching for alias with name [%s]", aliasName))

    -- find the desired alias in the aliases list
    local alias = nil

    for _, a in pairs(veafShortcuts.aliases) do
        if a:getName():lower() == aliasName:lower() then
            alias = a
            break
        end
    end
    
    if not alias then 
        local message = string.format("VeafAlias [%s] was not found !",aliasName)
        veaf.loggers.get(veafShortcuts.Id):error(message)
        trigger.action.outText(message,5)
    end

    return alias
end

-- add an alias
function veafShortcuts.AddAlias(alias)
    veaf.loggers.get(veafShortcuts.Id):debug(string.format("veafShortcuts.AddAlias([%s])",alias:getName() or ""))
    table.insert(veafShortcuts.aliases, alias)
    return alias
end

-- execute an alias command
function veafShortcuts.ExecuteAlias(aliasName, delay, remainingCommand, position, coalition, markId, bypassSecurity, spawnedGroups, route)
    veaf.loggers.get(veafShortcuts.Id):debug(string.format("veafShortcuts.ExecuteAlias([%s],[%s],[%s],[%s],[%s])", veaf.p(aliasName), veaf.p(delay), veaf.p(remainingCommand), veaf.p(position), veaf.p(coalition)))
    veaf.loggers.get(veafShortcuts.Id):trace(string.format("markId=[%s]",veaf.p(markId)))
    veaf.loggers.get(veafShortcuts.Id):trace(string.format("bypassSecurity=[%s]",veaf.p(bypassSecurity)))
    veaf.loggers.get(veafShortcuts.Id):trace(string.format("route=[%s]",veaf.p(route)))

    local alias = veafShortcuts.GetAlias(aliasName)
    if alias then 
        veaf.loggers.get(veafShortcuts.Id):trace(string.format("found VeafAlias[%s]",alias:getName() or ""))
        if alias:getBatchAliases() then -- no alias to actually execute, but instead run a batch
            -- the batch aliases are always password protected by a Mission Master password, so search for one
            local password = nil
            local keywords = veaf.split(remainingCommand, ",")

            for _, keyphrase in pairs(keywords) do
                local str = veaf.breakString(veaf.trim(keyphrase), " ")
                local key = str[1]
                local val = str[2] or ""

                if key:lower() == "password" then
                    password = val
                end
            end
            
            if not (bypassSecurity or veafSecurity.isAuthenticated()) then
                veaf.loggers.get(veafShortcuts.Id):trace("password=%s", veaf.p(password))
                local hash = nil
                if password then 
                    hash = sha1.hex(password)
                end
                if not(alias:hasPassword(hash)) then
                    veaf.loggers.get(veafShortcuts.Id):warn("You have to give the correct alias password for %s to do this", alias:getName())
                    trigger.action.outText("Please use the ', password <alias password>' option", 5)
                    return false
                end
            end

            local _msg = string.format("running batch alias [%s] : %s", alias:getName(), alias:getDescription())
            veaf.loggers.get(veafShortcuts.Id):info(_msg)
            trigger.action.outText(_msg, 10)
    
            -- run the batch
            for index, textToExecute in ipairs(alias:getBatchAliases()) do
                veafShortcuts.executeCommand(position, textToExecute, coalition, markId, true, spawnedGroups, route)
            end
        else       
            if delay and delay ~= "" then
                mist.scheduleFunction(VeafAlias.execute, {alias, remainingCommand, position, coalition, markId, bypassSecurity, spawnedGroups, route}, timer.getTime() + delay)
            else
                alias:execute(remainingCommand, position, coalition, markId, bypassSecurity, spawnedGroups, route)
            end
        end
        return true
    else
        veaf.loggers.get(veafShortcuts.Id):error(string.format("veafShortcuts.ExecuteAlias : cannot find alias [%s]",aliasName or ""))
    end
    return false
end

-- execute an alias command
function veafShortcuts.ExecuteBatchAliasesList(aliasBatchList, delay, coalition, silent)
    veaf.loggers.get(veafShortcuts.Id):debug(string.format("veafShortcuts.ExecuteBatchAliasesList([%s],[%s],[%s],[%s])", veaf.p(aliasBatchList), veaf.p(delay), veaf.p(coalition), veaf.p(silent)))
    if aliasBatchList and #aliasBatchList > 0 then -- run a batch

        local _msg = string.format("running batch list [%s]", veaf.p(aliasBatchList))
        veaf.loggers.get(veafShortcuts.Id):info(_msg)
        if not(silent) then trigger.action.outText(_msg, 10) end

        -- run the batch
        for index, textToExecute in ipairs(aliasBatchList) do
            veafShortcuts.executeCommand(nil, textToExecute, coalition, nil, true)
        end
        return true
    else
        veaf.loggers.get(veafShortcuts.Id):error(string.format("veafShortcuts.ExecuteBatchAliasesList : batch list is empty"))
    end
    return false
end

function veafShortcuts.GetWeatherAtCurrentPosition(unitName)
    veaf.loggers.get(veafShortcuts.Id):debug(string.format("veafShortcuts.GetWeatherAtCurrentPosition(unitName=%s)",unitName))
    local unit = veafRadio.getHumanUnitOrWingman(unitName)
    if unit then
        local weatherReport = veaf.weatherReport(unit:getPosition().p, nil, true) -- include LASTE
        veaf.outTextForUnit(unitName, weatherReport, 30)
    end
end

function veafShortcuts.GetWeatherAtClosestPoint(unitName)
    veaf.loggers.get(veafShortcuts.Id):debug(string.format("veafShortcuts.GetWeatherAtClosestPoint(unitName=%s)",unitName))
    local unit = veafRadio.getHumanUnitOrWingman(unitName)
    if unit then
        local weatherReport = veaf.weatherReport(unit:getPosition().p, nil, true) -- include LASTE
        veaf.outTextForUnit(unitName, weatherReport, 30)
    end
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Event handler functions.
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Function executed when a mark has changed. This happens when text is entered or changed.
function veafShortcuts.onEventMarkChange(eventPos, event)

    -- choose by default the coalition opposing the player who triggered the event
    local invertedCoalition = 1
    if event.coalition == 1 then
        invertedCoalition = 2
    end

    veaf.loggers.get(veafShortcuts.Id):trace(string.format("event.idx  = %s", veaf.p(event.idx)))

    if veafShortcuts.executeCommand(eventPos, event.text, invertedCoalition, event.idx) then 
        
        -- Delete old mark.
        veaf.loggers.get(veafShortcuts.Id):trace(string.format("Removing mark # %d.", event.idx))
        trigger.action.removeMark(event.idx)

    end
end

function veafShortcuts.executeCommand(eventPos, eventText, eventCoalition, markId, bypassSecurity, spawnedGroups, route)
    veaf.loggers.get(veafShortcuts.Id):debug(string.format("veafShortcuts.executeCommand(eventText=[%s])", eventText))

    -- Check if marker has a text and contains an alias
    if eventText ~= nil then
        
        -- Analyse the mark point text and extract the keywords.
        local alias, coords, delay, remainder = veafShortcuts.markTextAnalysis(eventText)

        if alias then
            local position = eventPos

            if coords and #coords > 0 then
                local _lat, _lon = veaf.computeLLFromString(coords)
                veaf.loggers.get(veafShortcuts.Id):trace(string.format("_lat=%s",veaf.p(_lat)))
                veaf.loggers.get(veafShortcuts.Id):trace(string.format("_lon=%s",veaf.p(_lon)))
                if _lat and _lon then 
                    position = coord.LLtoLO(_lat, _lon)
                    veaf.loggers.get(veafShortcuts.Id):trace(string.format("position=%s",veaf.p(position)))
                else
                    local _msg = string.format("unable to decode coordinates [%s]", veaf.p(coords))
                    veaf.loggers.get(veafShortcuts.Id):warn(_msg)
                    trigger.action.outText(_msg, 5)
                    return
                end
            end
    
            -- do the magic
            return veafShortcuts.ExecuteAlias(alias, delay, remainder, position, eventCoalition, markId, bypassSecurity, spawnedGroups, route)
        end
        return false
    end

    -- None of the keywords matched.
    return false
end

--- Extract keywords from mark text.
function veafShortcuts.markTextAnalysis(text)
    if text then 
  
        veaf.loggers.get(veafShortcuts.Id):trace(string.format("veafShortcuts.markTextAnalysis(text=[%s])", text))
    
        -- check for the alias starter
        if text:sub(1,1) == veafShortcuts.AliasStarter then
            veaf.loggers.get(veafShortcuts.Id):trace("found veafShortcuts.AliasStarter")

            -- extract alias and remainder
            local alias, coords, delay, remainder = text:match("(-[^#^!^ ^,]+)#?([^!^,^%s]*)!?(%d*)(.*)")
            veaf.loggers.get(veafShortcuts.Id):trace(string.format("alias=[%s]", veaf.p(alias)))
            veaf.loggers.get(veafShortcuts.Id):trace(string.format("coords=[%s]", veaf.p(coords)))
            veaf.loggers.get(veafShortcuts.Id):trace(string.format("delay=[%s]", veaf.p(delay)))
            veaf.loggers.get(veafShortcuts.Id):trace(string.format("remainder=[%s]", veaf.p(remainder)))
            if alias then
                veaf.loggers.get(veafShortcuts.Id):trace(string.format("alias = [%s]", alias))
                return alias, coords, delay, remainder
            end
        end

    end
    return nil
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- default aliases list
-------------------------------------------------------------------------------------------------------------------------------------------------------------

function veafShortcuts.buildDefaultList()
    -- generic sam groups
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-samLR")
            :setDescription("Random long range SAM battery")
            :setVeafCommand("_spawn samgroup, skynet true")
            :addRandomParameter("defense", 4, 5)
            :setBypassSecurity(false)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-samSR")
            :setDescription("Random short range SAM battery")
            :setVeafCommand("_spawn samgroup, skynet true")
            :addRandomParameter("defense", 2, 3)
            :setBypassSecurity(false)
    )
    -- specific air defenses groups and units  
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-hq7")
            :setDescription("HQ-7 (Red Banner) battery")
            :setVeafCommand("_spawn group, name hq7, skynet true")
            :setBypassSecurity(false)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-hq7_single")
            :setDescription("HQ-7 (Red Banner) launcher")
            :setVeafCommand("_spawn group, name hq7_single, skynet true")
            :setBypassSecurity(false)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-hq7noew")
            :setDescription("HQ-7 (Red Banner) battery without EWR")
            :setVeafCommand("_spawn group, name hq7-noew, skynet true")
            :setBypassSecurity(false)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-hq7eo")
            :setDescription("HQ-7EO (Red Banner) battery")
            :setVeafCommand("_spawn group, name hq7eo, skynet true")
            :setBypassSecurity(false)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-hq7eo_single")
            :setDescription("HQ-7EO (Red Banner) launcher")
            :setVeafCommand("_spawn group, name hq7eo_single, skynet true")
            :setBypassSecurity(false)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-hq7eo_noew")
            :setDescription("HQ-7EO (Red Banner) battery without EWR")
            :setVeafCommand("_spawn group, name hq7eo-noew, skynet true")
            :setBypassSecurity(false)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-sa2")
            :setDescription("SA-2 Guideline (S-75 Dvina) battery")
            :setVeafCommand("_spawn group, name sa2, skynet true")
            :setBypassSecurity(false)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-sa5")
            :setDescription("SA-5 Gammon (S-200 Dubna) battery")
            :setVeafCommand("_spawn group, name sa5, skynet true")
            :setBypassSecurity(false)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-sa3")
            :setDescription("SA-3 Goa (S-125 Neva/Pechora) battery")
            :setVeafCommand("_spawn group, name sa3, skynet true")
            :setBypassSecurity(false)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-sa6")
            :setDescription("SA-6 Gainful (2K12 Kub) battery")
            :setVeafCommand("_spawn group, name sa6, skynet true")
            :setBypassSecurity(false)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-sa8")
            :setDescription("SA-8 Osa (9K33 Osa) sam vehicle")
            :setVeafCommand("_spawn group, name sa8_squad, skynet true")
            :setBypassSecurity(false)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-sa9")
            :setDescription("SA-9 Strela-1 (9K31 Strela-1) sam vehicle")
            :setVeafCommand("_spawn unit, name Strela-1 9P31")
            :setBypassSecurity(false)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-sa9_squad")
            :setDescription("SA-9 Strela-1 (9K31 Strela-1) sam vehicle and logistic")
            :setVeafCommand("_spawn group, name sa9_squad")
            :setBypassSecurity(false)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-sa10")
            :setDescription("SA-10 Grumble (S-300) battery")
            :setVeafCommand("_spawn group, name sa10, skynet true")
            :setBypassSecurity(false)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-sa11")
            :setDescription("SA-11 Gadfly (9K37 Buk) battery")
            :setVeafCommand("_spawn group, name sa11, skynet true")
            :setBypassSecurity(false)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-sa13")
            :setDescription("SA-13 Strela (9A35M3) sam vehicle")
            :setVeafCommand("_spawn unit, name Strela-10M3")
            :setBypassSecurity(false)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-sa13_squad")
            :setDescription("SA-13 Strela (9A35M3) sam vehicle and logistic")
            :setVeafCommand("_spawn group, name sa13_squad")
            :setBypassSecurity(false)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-sa15")
            :setDescription("SA-15 Gauntlet (9K330 Tor) sam vehicle")
            :setVeafCommand("_spawn group, name sa15_squad, skynet true")
            :setBypassSecurity(false)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-insurgent_manpad")
            :setDescription("Insurgent SA-18 manpad squad")
            :setVeafCommand("_spawn group, name ins_manpad")
            :setBypassSecurity(false)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-sa18")
            :setDescription("SA-18 manpad squad")
            :setVeafCommand("_spawn group, name sa18_squad")
            :setBypassSecurity(false)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-sa18s")
            :setDescription("SA-18S manpad squad")
            :setVeafCommand("_spawn group, name sa18s_squad")
            :setBypassSecurity(false)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-sa19")
            :setDescription("SA-19 Tunguska (2K22 Tunguska) sam vehicle and logistic")
            :setVeafCommand("_spawn group, name sa19_squad, skynet true")
            :setBypassSecurity(false)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-shilka")
            :setDescription("ZSU-23-4 Shilka AAA vehicle")
            :setVeafCommand("_spawn unit, name ZSU-23-4 Shilka")
            :setBypassSecurity(false)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-zu23")
            :setDescription("ZU-23 AAA vehicle")
            :setVeafCommand("_spawn unit, name Ural-375 ZU-23")
            :setBypassSecurity(false)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-manpads")
            :setDescription("mutiple SA-18S manpad soldier peppered in a wide radius")
            :setVeafCommand("_spawn unit, name SA-18 Igla-S manpad, radius 5000")
            :addRandomParameter("multiplier", 3, 6)
            :setBypassSecurity(false)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-roland")
            :setDescription("Roland battery with EWR (US by default)")
            :setVeafCommand("_spawn group, name roland, country USA, skynet true")
            :setBypassSecurity(false)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-rolandnoew")
            :setDescription("Roland battery without EWR (US by default)")
            :setVeafCommand("_spawn group, name roland-noew, country USA, skynet true")
            :setBypassSecurity(false)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-nasams")
            :setDescription("NASAMS battery with 120C (US by default)")
            :setVeafCommand("_spawn group, name nasams_c, country USA, skynet true")
            :setBypassSecurity(false)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-nasams_b")
            :setDescription("NASAMS battery with 120B (US by default)")
            :setVeafCommand("_spawn group, name nasams_b, country USA, skynet true")
            :setBypassSecurity(false)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-hawk")
            :setDescription("Hawk battery (US by default)")
            :setVeafCommand("_spawn group, name hawk, country USA, skynet true")
            :setBypassSecurity(false)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-patriot")
            :setDescription("Patriot battery (US by default)")
            :setVeafCommand("_spawn group, name patriot, country USA, skynet true")
            :setBypassSecurity(false)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-stinger")
            :setDescription("Stinger manpad squad (US by default)")
            :setVeafCommand("_spawn group, name stinger_squad, country USA")
            :setBypassSecurity(false)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-avenger")
            :setDescription("Avenger SAM (US by default)")
            :setVeafCommand("_spawn unit, name avenger, country USA")
            :setBypassSecurity(false)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-avenger_squad")
            :setDescription("Avenger SAM (US by default) and logistic")
            :setVeafCommand("_spawn group, name avenger_squad, country USA")
            :setBypassSecurity(false)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-dogear")
            :setDescription("Dogear Radar")
            :setVeafCommand("_spawn unit, name dogear, skynet true, ewr")
            :setBypassSecurity(false)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-blue_ewr")
            :setDescription("F-117 Domed EWR (US by default)")
            :setVeafCommand("_spawn group, name blue_ewr, country USA, skynet true")
            :setBypassSecurity(false)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-ewr")
            :setDescription("55G6 Mast EWR")
            :setVeafCommand("_spawn group, name ewr, skynet true")
            :setBypassSecurity(false)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-burke")
            :setDescription("USS Arleigh Burke IIa destroyer (US by default)")
            :setVeafCommand("_spawn unit, name USS_Arleigh_Burke_IIa, country USA")
            :setBypassSecurity(false)
    )  
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-perry")
            :setDescription("O.H. Perry destroyer (US by default)")
            :setVeafCommand("_spawn unit, name PERRY, country USA")
            :setBypassSecurity(false)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-ticonderoga")
            :setDescription("Ticonderoga frigate (US by default)")
            :setVeafCommand("_spawn unit, name TICONDEROG, country USA")
            :setBypassSecurity(false)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-rezky")
            :setDescription("FF 1135M Rezky frigate (RU by default)")
            :setVeafCommand("_spawn unit, name REZKY, country RUSSIA")
            :setBypassSecurity(false)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-pyotr")
            :setDescription("CGN 1144.2 Pyotr Velikiy (RU by default)")
            :setVeafCommand("_spawn unit, name PIOTR, country RUSSIA")
            :setBypassSecurity(false)
    )
    -- convoys
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-hv_convoy_red")
            :setDescription("Red High Value Attack convoy")
            :setVeafCommand("_spawn group, name hv_convoy_red, country RUSSIA, skynet false, alarm 0") --Alarm is set to 0, meaning Alarm state 0 (AUTO) for proper movement of the scud
            :setBypassSecurity(false)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-attack_convoy_red")
            :setDescription("Red Attack convoy")
            :setVeafCommand("_spawn group, name convoy_red, country RUSSIA, skynet true")
            :setBypassSecurity(false)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-QRC_red")
            :setDescription("Quick Reaction Convoy red") --it's fast
            :setVeafCommand("_spawn group, name QRC_red, country RUSSIA, skynet true, speed 90, spacing 2")
            :setBypassSecurity(false)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-civilian_convoy_red")
            :setDescription("Red Civilian convoy")
            :setVeafCommand("_spawn group, name civilian_convoy_red, country RUSSIA")
            :setBypassSecurity(false)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-QRC_blue")
            :setDescription("Quick Reaction Convoy blue") --it's fast
            :setVeafCommand("_spawn group, name QRC_blue, country USA, skynet true, speed 90, spacing 2")
            :setBypassSecurity(false)
    )

    -- shortcuts to commands
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-point")
            :setDescription("Name a point on the map")
            :setVeafCommand("_name point")
            :dontEndWithComma() -- !! don't end with a comma, because we'd break setting the point name 
            :setBypassSecurity(true)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-destroy")
            :setDescription("Destroy any unit within 100m")
            :setVeafCommand("_destroy, radius 100")
            :setBypassSecurity(false)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-login")
            :setDescription("Unlock the system")
            :setHidden(true)
            :setVeafCommand("_auth")
            :dontEndWithComma() -- !! don't end with a comma, because we'd break setting the password 
            :setBypassSecurity(false)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-logout")
            :setDescription("Lock the system")
            :setHidden(true)
            :setVeafCommand("_auth logout")
            :dontEndWithComma()
            :setBypassSecurity(false)
    )
    -- shortcuts to specific groups
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-mortar")
            :setDescription("Mortar team")
            :setVeafCommand("_spawn group, name mortar, country USA")
            :setBypassSecurity(false)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-arty")
            :setDescription("M-109 artillery battery")
            :setVeafCommand("_spawn group, name M-109, country USA")
            :setBypassSecurity(false)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-msta")
            :setDescription("Msta artillery battery")
            :setVeafCommand("_spawn group, name msta")
            :setBypassSecurity(false)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-plz05")
            :setDescription("PLZ-05 artillery battery")
            :setVeafCommand("_spawn group, name plz05")
            :setBypassSecurity(false)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-mlrs")
            :setDescription("MLRS artillery battery")
            :setVeafCommand("_spawn group, name mlrs, country USA")
            :setBypassSecurity(false)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-smerch_he")
            :setDescription("Smerch HE artillery battery")
            :setVeafCommand("_spawn group, name smerchhe")
            :setBypassSecurity(false)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-smerch_cm")
            :setDescription("Smerch CM artillery battery")
            :setVeafCommand("_spawn group, name smerchcm")
            :setBypassSecurity(false)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-uragan")
            :setDescription("Uragan artillery battery")
            :setVeafCommand("_spawn group, name uragan")
            :setBypassSecurity(false)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-grad")
            :setDescription("Grad artillery battery")
            :setVeafCommand("_spawn group, name grad")
            :setBypassSecurity(false)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-cargoships")
            :setDescription("Cargo ships")
            :setVeafCommand("_spawn group, name cargoships-nodef, country RUSSIA, offroad, speed 60, skynet true")
            :setBypassSecurity(false)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-escortedcargoships")
            :setDescription("Cargo ships (escorted)")
            :setVeafCommand("_spawn group, name cargoships-escorted, country RUSSIA, offroad, speed 60, skynet true")
            :setBypassSecurity(false)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-combatships")
            :setDescription("Combat ships")
            :setVeafCommand("_spawn group, name combatships, country RUSSIA, offroad, speed 60, skynet true")
            :setBypassSecurity(false)
    )
    -- shortcuts to dynamic groups
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-sam")
            :setDescription("Random SAM battery")
            :setVeafCommand("_spawn samgroup, skynet true")
            :addRandomParameter("defense", 1, 5)
            :setBypassSecurity(false)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-aaa")
            :setDescription("Random AAA battery")
            :setVeafCommand("_spawn samgroup, skynet true, spacing 1")
            :addRandomParameter("defense", 1, 2)
            :setBypassSecurity(false)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-armor")
            :setDescription("Dynamic armor group")
            :setVeafCommand("_spawn armorgroup")
            :addRandomParameter("defense", 1, 3)
            :addRandomParameter("armor", 2, 4)
            :addRandomParameter("size", 4, 8)
            :setBypassSecurity(false)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-infantry")
            :setDescription("Dynamic infantry section")
            :setVeafCommand("_spawn infantrygroup")
            :addRandomParameter("defense", 0, 5)
            :addRandomParameter("armor", 0, 5)
            :addRandomParameter("size", 4, 8)
            :setBypassSecurity(false)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-transport")
            :setDescription("Dynamic transport company")
            :setVeafCommand("_spawn transportgroup")
            :addRandomParameter("defense", 0, 3)
            :addRandomParameter("size", 10, 25)
            :setBypassSecurity(false)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-combat")
            :setDescription("Dynamic combat group")
            :setVeafCommand("_spawn combatgroup")
            :addRandomParameter("defense", 1, 3)
            :addRandomParameter("armor", 2, 4)
            :addRandomParameter("size", 1, 4)
            :setBypassSecurity(false)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-cas")
            :setDescription("Generate a random CAS group for training")
            :setVeafCommand("_cas, disperse")
            :setBypassSecurity(false)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-cargo")
            :setDescription("Generate a cargo for sling loading")
            :setVeafCommand("_spawn cargo, side blue, radius 0")
            :setBypassSecurity(false)
    )
    -- radio shortcuts
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-send")
            :setDescription("Send radio message - needs \"MESSAGE\"")
            :setVeafCommand("_radio transmit, message")
            :dontEndWithComma() -- !! don't end with a comma, because we'd break setting the message content 
            :setBypassSecurity(false)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-play")
            :setDescription("Play sound over radio - needs \"FILENAME\"")
            :setVeafCommand("_radio play, path")
            :dontEndWithComma() -- !! don't end with a comma, because we'd break setting the message content 
            :setBypassSecurity(false)
    )
    -- other shortcuts
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-convoy")
            :setDescription("Convoy - needs \", dest POINTNAME\"")
            :setVeafCommand("_spawn convoy")
            :addRandomParameter("defense", 0, 3)
            :addRandomParameter("armor", 0, 4)
            :addRandomParameter("size", 6, 15)
            :setBypassSecurity(false)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-jtac")
            :setDescription("JTAC humvee")
            :setVeafCommand("_spawn jtac")
            :setBypassSecurity(true)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-afac")
            :setDescription("AFAC MQ-9 Reaper")
            :setVeafCommand("_spawn afac")
            :setBypassSecurity(true)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-afachere")
            :setDescription("move an afac to a specific location ; must follow with the afac group name ; can also set speed, alt and hdg")
            :setVeafCommand("_move afac, name")
            :dontEndWithComma()
            :setBypassSecurity(false)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-cesar")
            :setDescription("Artillery precision shelling of a zone with a few low-yield HE")
            :setVeafCommand("_spawn bomb")
            :addRandomParameter("shells", 2, 5)
            :addRandomParameter("radius", 15, 30)
            :addRandomParameter("power", 10, 50)
            :setHidden(true)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-shell")
            :setDescription("Artillery shelling of a small zone with lots of low-yield HE")
            :setVeafCommand("_spawn bomb")
            :addRandomParameter("shells", 2, 5)
            :addRandomParameter("radius", 100, 300)
            :addRandomParameter("power", 10, 50)
            :addRandomParameter("multiplier", 5, 10)
            :setHidden(true)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-flak")
            :setDescription("Anti-air Artillery shelling of a zone with flak")
            :setVeafCommand("_spawn bomb, alt 6000")
            :addRandomParameter("shells", 10, 15)
            :addRandomParameter("radius", 1000, 1500)
            :addRandomParameter("power", 500, 750)
            :addRandomParameter("altdelta", 800, 1000)
            :addRandomParameter("multiplier", 6, 10)
            :setHidden(true)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-light")
            :setDescription("Illumination by artillery shelling of a zone")
            :setVeafCommand("_spawn flare, radius 1500")
            :addRandomParameter("shells", 10, 15)
            :setBypassSecurity(true)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-smoke")
            :setDescription("Spawn a single white smoke")
            :setVeafCommand("_spawn smoke, color white, shells 1, radius 1")
            :setBypassSecurity(true)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-longsmoke")
            :setDescription("Spawn a single white smoke, renewed every 5 minutes for 30 minutes")
            :setVeafCommand("_spawn smoke, color white, shells 1, radius 1, repeat 5, delay 300")
            :setBypassSecurity(true)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-signal")
            :setDescription("Spawn a single signal flare")
            :setVeafCommand("_spawn signal, color green, shells 1, radius 1")
            :setBypassSecurity(true)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-tankerhere")
            :setDescription("move a tanker to a specific location ; must follow with the tanker group name ; can also set speed, alt, hdg and distance")
            :setVeafCommand("_move tanker, teleport, name")
            :dontEndWithComma()
            :setBypassSecurity(false)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-tanker")
            :setDescription("alias for '-tankerhere'")
            :setVeafCommand("-tankerhere")
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-tankerlow")
            :setDescription("sets the closest tanker to FL120 at 200 KIAS")
            :setVeafCommand("_move tankermission, alt 12000, speed 250")
            :setBypassSecurity(false)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-tankerhigh")
            :setDescription("sets the closest tanker to FL220 at 300 KIAS")
            :setVeafCommand("_move tankermission, alt 22000, speed 450")
            :setBypassSecurity(false)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-tacan")
            :setDescription("create a portable TACAN beacon")
            :setVeafCommand("_spawn tacan, band X, channel 99")
            :setBypassSecurity(true)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-farp")
            :setDescription("create a new FARP")
            :setVeafCommand("_spawn farp, side blue, radius 0")
            :setBypassSecurity(false)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-fob")
            :setDescription("create a new FOB")
            :setVeafCommand("_spawn fob, side blue, radius 0")
            :setBypassSecurity(false)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-draw")
            :setDescription("start a drawing on the map, or add a point to an existing drawing ; name is mandatory")
            :setVeafCommand("_drawing add, name")
            :dontEndWithComma()
            :setBypassSecurity(false)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-arrow")
            :setDescription("start drawing an arrow on the map, or add a point to an existing arrow ; name is mandatory")
            :setVeafCommand("_drawing add, arrow, name")
            :dontEndWithComma()
            :setBypassSecurity(false)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-erasedrawing")
            :setDescription("erase a drawing from the map ; name is mandatory")
            :setVeafCommand("_drawing erase, name")
            :dontEndWithComma()
            :setBypassSecurity(false)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-cap")
            :setDescription("Dynamic combat air patrol")
            :setVeafCommand("_spawn cap, name")
            :dontEndWithComma()
            :setBypassSecurity(false)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-flag")
            :setDescription("Mission Master : get flag value")
            :setVeafCommand("_mm getflag, name")
            :dontEndWithComma()
            :setBypassSecurity(false)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-flagon")
            :setDescription("Mission Master : set flag value to ON")
            :setVeafCommand("_mm flagon, name")
            :dontEndWithComma()
            :setBypassSecurity(false)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-flagoff")
            :setDescription("Mission Master : set flag value to OFF")
            :setVeafCommand("_mm flagoff, name")
            :dontEndWithComma()
            :setBypassSecurity(false)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-run")
            :setDescription("Mission Master : run runnable")
            :setVeafCommand("_mm run, name")
            :dontEndWithComma()
            :setBypassSecurity(false)
    )
    veafShortcuts.AddAlias(
        VeafAliasForCombatMission:new()
            :setName("-airstart")
            :setDescription("Run a combat mission")
            :setVeafCommand("start, name")
            :dontEndWithComma()
            :setBypassSecurity(false)
    )
    veafShortcuts.AddAlias(
        VeafAliasForCombatMission:new()
            :setName("-airstop")
            :setDescription("Stop a combat mission")
            :setVeafCommand("stop, name")
            :dontEndWithComma()
            :setBypassSecurity(false)
    )
    veafShortcuts.AddAlias(
        VeafAliasForCombatZone:new()
            :setName("-zonestart")
            :setDescription("Activate a combat zone")
            :setVeafCommand("start, name")
            :dontEndWithComma()
            :setBypassSecurity(false)
    )
    veafShortcuts.AddAlias(
        VeafAliasForCombatZone:new()
            :setName("-zonestop")
            :setDescription("Desactivate a combat zone")
            :setVeafCommand("stop, name")
            :dontEndWithComma()
            :setBypassSecurity(false)
    )
end

function veafShortcuts.dumpAliasesList(export_path)

    local jsonify = function(key, value)
        veaf.loggers.get(veafShortcuts.Id):trace(string.format("jsonify(%s)", veaf.p(value)))
        if veaf.json then
            return veaf.json.stringify(veafShortcuts.GetAlias(value))
        else
            return ""
        end
    end

    -- sort the aliases alphabetically
    local sortedAliases = {}
    for _, alias in pairs(veafShortcuts.aliases) do
        table.insert(sortedAliases, alias:getName())
    end
    table.sort(sortedAliases)
    veaf.loggers.get(veafShortcuts.Id):trace(string.format("sortedAliases=%s", veaf.p(sortedAliases)))

    local _filename = "AliasesList.json"
    if veaf.config.MISSION_NAME then
        _filename = "AliasesList_" .. veaf.config.MISSION_NAME .. ".json"
    end
    veaf.exportAsJson(sortedAliases, "aliases", jsonify, _filename, export_path or veaf.config.MISSION_EXPORT_PATH)
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- remote interface
-------------------------------------------------------------------------------------------------------------------------------------------------------------

-- execute command from the remote interface
function veafShortcuts.executeCommandFromRemote(parameters)
    veaf.loggers.get(veafShortcuts.Id):debug(string.format("veafShortcuts.executeCommandFromRemote()"))
    veaf.loggers.get(veafShortcuts.Id):trace(string.format("parameters= %s", veaf.p(parameters)))
    local _pilot, _pilotName, _unitName, _command = unpack(parameters)
    veaf.loggers.get(veafShortcuts.Id):trace(string.format("_pilot= %s", veaf.p(_pilot)))
    veaf.loggers.get(veafShortcuts.Id):trace(string.format("_pilotName= %s", veaf.p(_pilotName)))
    veaf.loggers.get(veafShortcuts.Id):trace(string.format("_unitName= %s", veaf.p(_unitName)))
    veaf.loggers.get(veafShortcuts.Id):trace(string.format("_command= %s", veaf.p(_command)))
    if not _pilot or not _command then 
        return false
    end

    if _command then
        local _lat, _lon, _alias = nil, nil, nil
        local _coa = coalition.side.BLUE
        local _unit = Unit.getByName(_unitName)
        if _unit then 
            _coa = _unit:getCoalition()
            veaf.loggers.get(veafShortcuts.Id):trace("_coa=s",veaf.p(_coa))
        end
        -- choose by default the coalition opposing the player who triggered the event
        local invertedCoalition = 1
        if _coa == 1 then
            invertedCoalition = 2
        end
        if _command:sub(1,1) == veafShortcuts.AliasStarter or _command:sub(2,2) == veafShortcuts.AliasStarter then
            -- there is only the command
            _alias = _command
            veaf.loggers.get(veafShortcuts.Id):trace(string.format("_alias=%s",veaf.p(_alias)))
        else
            -- parse the command
            local _coords, __alias = _command:match(veafShortcuts.RemoteCommandParser)
            _alias = __alias
            veaf.loggers.get(veafShortcuts.Id):trace(string.format("_coords=%s",veaf.p(_coords)))
            veaf.loggers.get(veafShortcuts.Id):trace(string.format("_alias=%s",veaf.p(_alias)))
            if _coords then
                _lat, _lon = veaf.computeLLFromString(_coords)
                veaf.loggers.get(veafShortcuts.Id):trace(string.format("_lat=%s",veaf.p(_lat)))
                veaf.loggers.get(veafShortcuts.Id):trace(string.format("_lon=%s",veaf.p(_lon)))
            end
        end
        if _alias then
            if _lat and _lon then 
                local _pos = coord.LLtoLO(_lat, _lon)
                veaf.loggers.get(veafShortcuts.Id):trace(string.format("_pos=%s",veaf.p(_pos)))
                veaf.loggers.get(veafShortcuts.Id):trace(string.format("_coa=%s",veaf.p(_coa)))
                veaf.loggers.get(veafShortcuts.Id):info(string.format("[%s] is running an alias at position [%s] for coalition [%s] : [%s]",veaf.p(_pilot.name), veaf.p(_pos), veaf.p(_coa), veaf.p(_alias)))
                veafShortcuts.executeCommand(_pos, _alias, invertedCoalition, _pilot.name)
                return true
            else
                veaf.loggers.get(veafShortcuts.Id):info(string.format("[%s] is running an alias with no specific position for coalition [%s] : [%s]",veaf.p(_pilot.name), veaf.p(_coa), veaf.p(_alias)))
                veafShortcuts.executeCommand(nil, _alias, invertedCoalition, _pilot.name)
            end
        end
    end
    return false
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- initialisation
-------------------------------------------------------------------------------------------------------------------------------------------------------------

function veafShortcuts.initialize()
    veaf.loggers.get(veafShortcuts.Id):info("Initializing module")
    veafShortcuts.buildDefaultList()
    veafMarkers.registerEventHandler(veafMarkers.MarkerChange, veafShortcuts.onEventMarkChange)
    veafShortcuts.dumpAliasesList()
end

veaf.loggers.get(veafShortcuts.Id):info(string.format("Loading version %s", veafShortcuts.Version))

