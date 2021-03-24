
trainingSpawnZone = {}

--- Identifier. All output in the log will start with this.
trainingSpawnZone.Id = "TRAININGZONE - "

--- Version.
trainingSpawnZone.Version = "1.1.0"

-- trace level, specific to this module
trainingSpawnZone.Trace = false
trainingSpawnZone.Debug = false

trainingSpawnZone.MESSAGE_REGISTERED = "Zone [%s] has been registered"
trainingSpawnZone.MESSAGE_ACTIVATED = "Zone [%s] has been activated"
trainingSpawnZone.MESSAGE_DEACTIVATED = "Zone [%s] has been deactivated"
trainingSpawnZone.MESSAGE_DURATION = 10
trainingSpawnZone.CHECK_FREQUENCY = 5


trainingSpawnZone.zones = {}

function trainingSpawnZone.logError(message)
    env.error(trainingSpawnZone.Id, message)
end

function trainingSpawnZone.logWarning(message)
    env.warning(trainingSpawnZone.Id, message)
end

function trainingSpawnZone.logInfo(message)
    env.info(trainingSpawnZone.Id .."I - " ..  message)
end

function trainingSpawnZone.logDebug(message)
    if message and trainingSpawnZone.Debug then 
        env.info(trainingSpawnZone.Id .."D - " ..  message)
    end
end

function trainingSpawnZone.logTrace(message)
    if message and trainingSpawnZone.Trace then 
        env.info(trainingSpawnZone.Id .."T - " ..  message)
    end
end

function trainingSpawnZone.p(o, level)
    local MAX_LEVEL = 20
    if level == nil then 
        level = 0 
    end

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
            text = text .. ".".. key.."="..trainingSpawnZone.p(value, level+1) .. "\n";
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

function trainingSpawnZone.registerZone(zoneName, friendlies, ennemies, message)
    trainingSpawnZone.logDebug(string.format("trainingSpawnZone.registerZone([%s])", trainingSpawnZone.p(zoneName)))
    trainingSpawnZone.logDebug(string.format("friendlies = %s", trainingSpawnZone.p(friendlies)))
    trainingSpawnZone.logDebug(string.format("ennemies = %s", trainingSpawnZone.p(ennemies)))
    trainingSpawnZone.logTrace(string.format("message = %s", trainingSpawnZone.p(message)))
    
    if not zoneName or not friendlies or #friendlies < 1 or not ennemies or #ennemies < 1 then
        return false
    end

    local _zoneName = zoneName:lower()
    trainingSpawnZone.zones[_zoneName] = {}
    trainingSpawnZone.zones[_zoneName].name = zoneName
    trainingSpawnZone.zones[_zoneName].message = message
    trainingSpawnZone.zones[_zoneName].friendlies = friendlies
    trainingSpawnZone.zones[_zoneName].ennemies = ennemies
    trainingSpawnZone.zones[_zoneName].active = false

    if message then
        trigger.action.outText(string.format(trainingSpawnZone.MESSAGE_REGISTERED, zoneName), trainingSpawnZone.MESSAGE_DURATION) 
    end

    trainingSpawnZone.logDebug(string.format("zone [%s] registered", trainingSpawnZone.p(zoneName)))
end

function trainingSpawnZone.activateZone(zoneName)
    trainingSpawnZone.logDebug(string.format("trainingSpawnZone.activateZone([%s])", trainingSpawnZone.p(zoneName)))

    if not zoneName then
        return false
    end

    local _zone = trainingSpawnZone.zones[zoneName:lower()]
    if not _zone.active then
        for _, groupName in pairs(_zone.ennemies) do
            mist.respawnGroup(groupName, true)
        end
        if _zone.message then
            trigger.action.outText(string.format(trainingSpawnZone.MESSAGE_ACTIVATED, zoneName), trainingSpawnZone.MESSAGE_DURATION) 
        end
        _zone.active = true
        trainingSpawnZone.logDebug(string.format("zone [%s] activated", trainingSpawnZone.p(zoneName)))
    else
        trainingSpawnZone.logWarning(string.format("zone [%s] was already active", trainingSpawnZone.p(zoneName)))
    end
end

function trainingSpawnZone.deactivateZone(zoneName)
    trainingSpawnZone.logDebug(string.format("trainingSpawnZone.deactivateZone([%s])", trainingSpawnZone.p(zoneName)))

    if not zoneName then
        return false
    end

    local _zone = trainingSpawnZone.zones[zoneName:lower()]
    if _zone.active then
        for _, groupName in pairs(_zone.ennemies) do
            local _group = Group.getByName(groupName)
            if _group then
                _group:destroy()
            end
        end
        if _zone.message then
            trigger.action.outText(string.format(trainingSpawnZone.MESSAGE_DEACTIVATED, zoneName), trainingSpawnZone.MESSAGE_DURATION) 
        end
        _zone.active = false
        trainingSpawnZone.logDebug(string.format("zone [%s] deactivated", trainingSpawnZone.p(zoneName)))
    else
        trainingSpawnZone.logWarning(string.format("zone [%s] was not active", trainingSpawnZone.p(zoneName)))
    end
end

function trainingSpawnZone.checkZone(zoneName)
    trainingSpawnZone.logTrace(string.format("trainingSpawnZone.checkZone([%s])", trainingSpawnZone.p(zoneName)))

    local function countUnitsInGroups(groupsNames)
        local _result = 0
        for _, groupName in pairs(groupsNames) do
            local _group = Group.getByName(groupName)
            if _group then 
                for _, unit in pairs(_group:getUnits()) do
                    if (unit:isExist() and unit:isActive() and unit:getLife() > 0.01) then
                        _result = _result + 1
                    end
                end
            end
        end
        return _result
    end

    if zoneName then 
        local _zone = trainingSpawnZone.zones[zoneName:lower()]
        if _zone then
            if _zone.active then
                -- check if friendlies or ennemies have been destroyed
                local _remainingFriendlies = countUnitsInGroups(_zone.friendlies)
                trainingSpawnZone.logTrace(string.format("_remainingFriendlies = %s", trainingSpawnZone.p(_remainingFriendlies)))
                local _remainingEnnemies = countUnitsInGroups(_zone.ennemies)
                trainingSpawnZone.logTrace(string.format("_remainingEnnemies = %s", trainingSpawnZone.p(_remainingEnnemies)))
                if _remainingEnnemies == 0 or _remainingFriendlies == 0 then
                    trainingSpawnZone.deactivateZone(zoneName)
                end
            else
                -- check for friendlies in zone
                local _groupsNamesForMist = {}
                for _, groupName in pairs(_zone.friendlies) do
                    table.insert(_groupsNamesForMist, "[g]"..groupName)
                end
                trainingSpawnZone.logTrace(string.format("_groupsNamesForMist = %s", trainingSpawnZone.p(_groupsNamesForMist)))
                local _units = mist.makeUnitTable(_groupsNamesForMist)
                trainingSpawnZone.logTrace(string.format("_units = %s", trainingSpawnZone.p(_units)))
                local _unitsInZone = mist.getUnitsInZones(_units, {zoneName}, 'cylinder')
                trainingSpawnZone.logTrace(string.format("_unitsInZone = %s", trainingSpawnZone.p(_unitsInZone)))
                local _friendliesInZone = (#_unitsInZone > 0)
                if _friendliesInZone then
                    trainingSpawnZone.activateZone(zoneName)
                end
            end
        end
    end

    mist.scheduleFunction(trainingSpawnZone.checkZone, { zoneName }, timer.getTime() + trainingSpawnZone.CHECK_FREQUENCY)

end

function trainingSpawnZone.start()
    trainingSpawnZone.logTrace(string.format("trainingSpawnZone.start()"))

    local _separation = 0
    for _, zone in pairs(trainingSpawnZone.zones) do
        _separation = _separation + 0.3
        trainingSpawnZone.logDebug(string.format("scheduling call to trainingSpawnZone.checkZone([%s])", trainingSpawnZone.p(zone.name)))
        mist.scheduleFunction(trainingSpawnZone.checkZone, { zone.name }, timer.getTime() + _separation)
    end

end
