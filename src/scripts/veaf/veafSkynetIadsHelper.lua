------------------------------------------------------------------
-- VEAF helper for Skynet-IADS
-- By zip (2021)
--
-- Features:
-- ---------
-- * This module offers support for integrating Skynet-IADS in a mission
--
-- See the documentation : https://veaf.github.io/documentation/
------------------------------------------------------------------

veafSkynet = {}

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Global settings. Stores the script constants
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Identifier. All output in DCS.log will start with this.
veafSkynet.Id = "SKYNET"

--- Version.
veafSkynet.Version = "3.1.1"

-- trace level, specific to this module
--veafSkynet.LogLevel = "trace"

veaf.loggers.new(veafSkynet.Id, veafSkynet.LogLevel)

-- delay before the mission groups are added to the IADS' at start
veafSkynet.DelayForStartup = 1

-- delay before restarting the IADS when adding a single group
veafSkynet.DelayForRestart = 20

-- maximum x or y (z in DCS) between a SAM site and it's point defenses in meters
veafSkynet.MaxPointDefenseDistanceFromSite = 10000

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Do not change anything below unless you know what you are doing!
-------------------------------------------------------------------------------------------------------------------------------------------------------------

veafSkynet.initialized = false
--flag to know if all units present on the map should be loaded at init or not into their team's main IADS network
veafSkynet.loadAllAtInit = {
    [tostring(coalition.side.BLUE)] = true,
    [tostring(coalition.side.RED)] = true
}
--table containing the default IADS network names initialized for each coalition
veafSkynet.defaultIADS = {
    [tostring(coalition.side.BLUE)] = "blue iads",
    [tostring(coalition.side.RED)] = "red iads",
}
veafSkynet.iadsSamUnitsTypes = {}
veafSkynet.iadsEwrUnitsTypes = {}

veafSkynet.GroupIntegrationModes =
{
    Strict = 0, -- groups will only be included in the skynet networks if they contains only units known to skynet
    Lenient = 1 -- groups will be included in the skynet networks even if some units are not known to skynet
}
veafSkynet.GroupIntegrationMode = veafSkynet.GroupIntegrationModes.Lenient -- lenient by default

-- Management of point defences (Flogas)
-- when active, veafSkynet will attempt to set eligible groups as point defence of nearby defencible groups
-- as per Skynet database types :
--  - "single" groups will be eligible to defend "complex" or "ewr" groups
--  - "complex" groups will be eligible to defend "ewr" groups
--  - "single" groups will never be defended
veafSkynet.PointDefenceModes =
{
    None = 0, -- point defences will not be created
    Skynet = 1, -- point defences will be defined with the skynet logic
    Dcs = 2 -- point defences will be defined as not a part of the skynet network and left to the dcs ai
}
veafSkynet.PointDefenceMode = veafSkynet.PointDefenceModes.None -- no point defences by default

veafSkynet.DynamicSpawn = false -- false by default

veafSkynet.SkynetElementStates =
{
    Autonomous = 0,
    Live = 1,
    Dark = 2
}

--table containing the structure of each IADS network, first level is accessed with the IADS name. This contains the .coalitionID of the network, the IADS network (.iads), the groups added to the network (.groups) stored by groupName, 
--wether this network should appear on the radio menu (.includeInRadio) and lastly if this network is in debug mode (.debugFlag). The groups store whether the group was .forceEwr or .pointDefense.
veafSkynet.structure = {}

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Utility methods
-------------------------------------------------------------------------------------------------------------------------------------------------------------
function veafSkynet.getStringSkynetElement(skynetElement)
    local s = skynetElement.dcsName

    if (not skynetElement.dcsRepresentation:isExist()) then
        return s .. " (dcs object does not exist)"    
    end

    local id = skynetElement.dcsRepresentation:getID()
    local category = getmetatable(skynetElement.dcsRepresentation)
    local sCategory = "unknown"
    if (category == Group) then
        sCategory = "group"
    elseif (category == Unit) then
        sCategory = "unit"
    elseif (category == StaticObject) then
        sCategory = "static"
    end

    if (skynetElement.getNatoName) then
        s = s .. " [" .. skynetElement:getNatoName() .. "]"
    else
        s = s .. " [" .. skynetElement.typeName .. "]"
    end

    s = s .. " [id=" .. id .. "]" .. " [" .. sCategory .. "]"
    return s
end

function veafSkynet.getDcsGroupFromSkynetElement(skynetElement)
    if (skynetElement.dcsRepresentation and skynetElement.dcsRepresentation:isExist()) then
        local category = getmetatable(skynetElement.dcsRepresentation)
        if (category == Group) then
            return skynetElement.dcsRepresentation
        elseif (category == Unit) then
            return Unit.getGroup(skynetElement.dcsRepresentation)
        end
    end
    
    return nil
end

function veafSkynet.getSkynetData(skynetElement)
    local function skynetDatabaseMatchType(skynetElementTypeList, skynetDatabaseTypeList)
        if (skynetDatabaseTypeList and skynetElementTypeList and #skynetElementTypeList > 0) then
            for i = 1, #skynetElementTypeList do
                if (skynetDatabaseTypeList[skynetElementTypeList[i].typeName]) then
                    return true
                end
            end
        end

        return false
    end

    for skynetDataName, skynetData in pairs(SkynetIADS.database) do
        -- first check the launchers as they are the most unique thing
        if(skynetDatabaseMatchType(skynetElement.launchers, skynetData["launchers"])) then
            veaf.loggers.get(veafSkynet.Id):trace("Matched by launcher : " .. veafSkynet.getStringSkynetElement(skynetElement) .. " > " .. skynetDataName)
            return skynetData
        end

        -- tracking and search radars can be used by multiple sites
        if(skynetDatabaseMatchType(skynetElement.trackingRadars, skynetData["trackingRadar"])) then
            veaf.loggers.get(veafSkynet.Id):trace("Matched by TR : " .. veafSkynet.getStringSkynetElement(skynetElement) .. " > " .. skynetDataName)
            return skynetData
        end
        if(skynetDatabaseMatchType(skynetElement.searchRadars, skynetData["searchRadar"])) then
            veaf.loggers.get(veafSkynet.Id):trace("Matched by SR : " .. veafSkynet.getStringSkynetElement(skynetElement) .. " > " .. skynetDataName)
            return skynetData
        end
    end

    veaf.loggers.get(veafSkynet.Id):trace("No match : " .. veafSkynet.getStringSkynetElement(skynetElement))
    return nil
end

function veafSkynet.removeSkynetElement(skynetElement, veafSkynetNetwork)
    local iads = veafSkynetNetwork.iads

    veaf.loggers.get(veafSkynet.Id):trace("Remove skynet element [" .. veafSkynet.getStringSkynetElement(skynetElement) .. "]")

    local function _removeSkynetElementFromList(list, skynetElement)
        local iIndex = -1
        if (list and #list > 0) then
            for i = 1, #list do
                if (list[i] == skynetElement) then
                    iIndex = i
                    break
                end
            end
    
            if (iIndex > 0) then
                table.remove(list, iIndex) 
            end
        end
    end

    skynetElement:cleanUp()
    skynetElement:getDCSRepresentation():enableEmission(true)

    local list = iads.samSites
    veaf.loggers.get(veafSkynet.Id):trace("Sam sites count: " .. #list)

    _removeSkynetElementFromList(list, skynetElement)
    --_removeSkynetElementFromList(iads:getEarlyWarningRadars(), skynetElement)

    veaf.loggers.get(veafSkynet.Id):trace("Sam sites count: " .. #list) -- not removed here

    local dcsGroup = veafSkynet.getDcsGroupFromSkynetElement(skynetElement)
    veafSkynetNetwork.groups[dcsGroup:getName()] = nil
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- core functions
-------------------------------------------------------------------------------------------------------------------------------------------------------------

-- get the IADS network for a given name ("blue iads", "red iads"")
function veafSkynet.getNetwork(networkName)
    local network = nil
    if networkName then
        network = veafSkynet.structure[networkName]
    end
    return network
end

-- get the IADS object for a given name ("blue iads", "red iads"")
function veafSkynet.getIADS(networkName)
    local iads = nil
    local network = veafSkynet.getNetwork(networkName)
    if network then
        iads = network.iads
    end
    return iads
end

-- calling SkynetIADS:activate() after a delay, to avoid calling it at each time a group is added to the IADS
function veafSkynet.delayedActivate(networkName)
    veaf.loggers.get(veafSkynet.Id):debug("veafSkynet.delayedActivate(%s)", veaf.p(networkName))
    local network = veafSkynet.structure[networkName]
    if network then
        if network.delayedActivation then
            veaf.loggers.get(veafSkynet.Id):trace(string.format("IADS %s already has a delayed activation", veaf.p(networkName)))
        else
            veaf.loggers.get(veafSkynet.Id):trace(string.format("IADS %s will be activated in %d seconds", veaf.p(networkName), veafSkynet.DelayForRestart))
            network.delayedActivation = mist.scheduleFunction(veafSkynet._activateIADS, {networkName}, timer.getTime() + veafSkynet.DelayForRestart)
        end
    end
end

function veafSkynet._activateIADS(networkName)
    veaf.loggers.get(veafSkynet.Id):debug("veafSkynet._activateIADS(%s)", veaf.p(networkName))

    local network = veafSkynet.structure[networkName]
    if network then
        network.delayedActivation = nil
        local iads = network.iads
        if iads then
            veaf.loggers.get(veafSkynet.Id):debug("calling iads:activate()")
            iads:activate()
        end
    end
end

function veafSkynet.getIadsOfCoalition(networkName, coa)
    local iads = nil
    if veafSkynet.structure[networkName] and coa == veafSkynet.structure[networkName].coalitionID then
        iads = veafSkynet.structure[networkName].iads
    end
    return iads
end

function veafSkynet.getNearestIADSSite(networkName, dcsGroup)
    
    if not dcsGroup then
        veaf.loggers.get(veafSkynet.Id):trace("No group to find the nearest IADS site for")
        return false
    end

    local coa = dcsGroup:getCoalition()
    veaf.loggers.get(veafSkynet.Id):trace(string.format("Ref coalition : %s", veaf.p(coa))) 

    local iads = veafSkynet.getIadsOfCoalition(networkName, coa)
    if not iads then
        veaf.loggers.get(veafSkynet.Id):trace(string.format("IADS named %s for the coalition of the group %s does not exist", veaf.p(networkName), tostring(dcsGroup:getName())))
        return false
    end
    
    local currentGroup = dcsGroup:getName()
    veaf.loggers.get(veafSkynet.Id):trace(string.format("networkName : %s", veaf.p(networkName))) 
    local groupPos = veaf.getAveragePosition(dcsGroup)
    veaf.loggers.get(veafSkynet.Id):debug(string.format("Ref Position : %s", veaf.p(groupPos))) 


    local nearestEWRname = nil
    local minEWRDistance = veafSkynet.MaxPointDefenseDistanceFromSite
    local nearestSAMname = nil
    local minSAMDistance = veafSkynet.MaxPointDefenseDistanceFromSite

    local CoalitionSites = nil

    local searchForGroup = function(CoalitionSites, pos, currentGroupName, ewrFlag)
        local minDistance = veafSkynet.MaxPointDefenseDistanceFromSite
        local FoundGroup = nil

        for site, site_info in pairs(CoalitionSites) do
            local site_name = site_info.dcsName -- For EWRs it looks like this gives the unit's name which would need to be reversed to the group to get position data
            veaf.loggers.get(veafSkynet.Id):trace(string.format("Checked Site groupName : %s and isEWR : %s", veaf.p(site_name), veaf.p(ewrFlag))) 
            
            if site_name and currentGroupName ~= site_name then
                if ewrFlag then
                    local unit = Unit.getByName(site_name)
                    local group = Unit.getGroup(unit)
                    site_name = Group.getName(group)
                end
                veaf.loggers.get(veafSkynet.Id):trace(string.format("Checked Site groupName : %s", veaf.p(site_name)))

                local groupAvgPosition = veaf.getAveragePosition(site_name)
                veaf.loggers.get(veafSkynet.Id):debug(string.format("Checked Site groupAvgPosition : %s", veaf.p(groupAvgPosition)))

                if groupAvgPosition then
                    local distance = math.sqrt((pos.x-groupAvgPosition.x)^2+(pos.z-groupAvgPosition.z)^2)
                    veaf.loggers.get(veafSkynet.Id):trace(string.format("Distance between checked site and pointDefense : %s", veaf.p(distance)))

                    if distance <= minDistance then
                        veaf.loggers.get(veafSkynet.Id):trace("This site is closer")
                        FoundGroup = site_name
                        minDistance = distance
                    end
                end
            end
        end 
       
        return FoundGroup, minDistance
    end

    --start by going through the EWRs
    CoalitionSites = iads:getEarlyWarningRadars()
    nearestEWRname, minEWRDistance = searchForGroup(CoalitionSites, groupPos, currentGroup, true)

    --search for SAM sites
    CoalitionSites = iads:getSAMSites()
    nearestSAMname, minSAMDistance = searchForGroup(CoalitionSites, groupPos, currentGroup)    

    if minEWRDistance <= minSAMDistance then
        return nearestEWRname
    end
    return nearestSAMname
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Management of point defences (Flogas)
-------------------------------------------------------------------------------------------------------------------------------------------------------------
function veafSkynet.canBePointDefence(skynetData)
    if (skynetData == nil) then
        return false
    end
    if (skynetData["can_engage_harm"] ~= true) then
        return false
    end
    if (skynetData["type"] ~= "complex" and skynetData["type"] ~= "single") then
        return false
    end

    return true
end

function veafSkynet.findSkynetElementToDefend(skynetElementPointDefence, skynetDataPointDefence)
    local dcsGroupPointDefence = veafSkynet.getDcsGroupFromSkynetElement(skynetElementPointDefence)
    local iads = skynetElementPointDefence.iads
    local pointDefenceType = skynetDataPointDefence["type"]

    local pointDefencePosition = veaf.getAveragePosition(dcsGroupPointDefence)
    if (pointDefencePosition == nil) then
        return nil
    end

    local function findClosestSkynetElementInList(skynetElementList)
        if (skynetElementList == nil or #skynetElementList <= 0) then
            return nil
        end

        local iMinDistance = veafSkynet.MaxPointDefenseDistanceFromSite
        local foundElement
        for i = 1, #skynetElementList do
            local skynetElement = skynetElementList[i]
            local skynetData = veafSkynet.getSkynetData(skynetElement)
            if (skynetData and (skynetData["type"] == "ewr" or (skynetData["type"] == "complex" and pointDefenceType == "single"))) then
                -- ewr are always defencible, and complex sam sites only defencible by single groups
                local dcsGroup = veafSkynet.getDcsGroupFromSkynetElement(skynetElementList[i])
                local position = veaf.getAveragePosition(dcsGroup)

                if (position) then
                    local iDistance = math.sqrt((position.x - pointDefencePosition.x)^2 + (position.z - pointDefencePosition.z)^2)
             
                    if (iDistance < iMinDistance) then
                        foundElement = skynetElement
                        iMinDistance = iDistance
                    end
                end
            end
        end

        return foundElement
    end

    local elementToDefend = findClosestSkynetElementInList (iads:getEarlyWarningRadars())
    if (elementToDefend == nil and pointDefenceType == "single") then
        elementToDefend = findClosestSkynetElementInList (iads:getSAMSites())
    end

    if (elementToDefend) then
        local sDescriptorPointDefence = veafSkynet.getStringSkynetElement(skynetElementPointDefence)
        local sDescriptorToDefend = veafSkynet.getStringSkynetElement(elementToDefend)
        veaf.loggers.get(veafSkynet.Id):trace("Identified [ " .. sDescriptorToDefend .. " ] to be defended by [ " .. sDescriptorPointDefence .. " ]")
    end

    return elementToDefend
end

function veafSkynet.removePointDefencesFromSkynetElement(skynetElement)
    if(skynetElement and skynetElement.pointDefences and #skynetElement.pointDefences > 0) then
        for i = 1, #skynetElement.pointDefences do
            skynetElement.pointDefences[i]:setIsAPointDefence(false)
        end
        skynetElement.pointDefences = {}
    end

    skynetElement.pointDefences = {}
end

function veafSkynet.removePointDefences(iads)
    -- not tested
    local ewrs = iads:getEarlyWarningRadars()
    if (ewrs and #ewrs > 0) then
        for i = 1, #ewrs do
            veafSkynet.removePointDefencesFromSkynetElement(ewrs[i])
        end
    end
    local samSites = iads:getSAMSites()
    if (samSites and #samSites > 0) then
        for i = 1, #samSites do
            veafSkynet.removePointDefencesFromSkynetElement(samSites[i])
        end
    end
end

function veafSkynet.initializePointDefenceSamSite(samSite, veafSkynetNetwork)
    if (samSite:getIsAPointDefence()) then
        return
    end

    local skynetData = veafSkynet.getSkynetData(samSite)
    if (not veafSkynet.canBePointDefence(skynetData)) then
        return
    end

    local elementToDefend = veafSkynet.findSkynetElementToDefend(samSite, skynetData)
    if (elementToDefend) then
        if (veafSkynet.PointDefenceMode == veafSkynet.PointDefenceModes.Skynet) then
            veaf.loggers.get(veafSkynet.Id):debug("Point defence: add as skynet")
            elementToDefend:addPointDefence(samSite)
        elseif (veafSkynet.PointDefenceMode == veafSkynet.PointDefenceModes.Dcs) then
            veaf.loggers.get(veafSkynet.Id):debug("Point defence: add as dcs")
            veafSkynet.removeSkynetElement(samSite, veafSkynetNetwork)
        end
    end
end

function veafSkynet.initializePointDefences(veafSkynetNetwork)
    if (veafSkynet.PointDefenceMode ~= veafSkynet.PointDefenceModes.Skynet and veafSkynet.PointDefenceMode ~= veafSkynet.PointDefenceModes.Dcs) then
        return
    end
  
    veaf.loggers.get(veafSkynet.Id):debug("Analyzing network to create point defences")

    local iads = veafSkynetNetwork.iads
    local samSites = iads:getSAMSites()
    if (samSites and #samSites > 0) then
        for i = 1, #samSites do
            veafSkynet.initializePointDefenceSamSite(samSites[i], veafSkynetNetwork)
        end
    end
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Management of dynamic group spawns (Flogas)
-- Option to integrate late spawned units into the existing networks
-------------------------------------------------------------------------------------------------------------------------------------------------------------
veafSkynet.monitorDynamicSpawnHandlerId = nil

function veafSkynet.OnDynamicSpawn(event)
    if(not veafSkynet.initialized) then
        return
    end
    if(event.id ~= world.event.S_EVENT_BIRTH) then
        return
    end
    if (event.initiator == nil or Object.getCategory(event.initiator) ~= Object.Category.UNIT) then
        return
    end

    -- birth event will be triggered for each unit of a spawned group, but we want to manage the group, so we only work for for the first unit
    local dcsGroup = Unit.getGroup (event.initiator)
    local firstDcsUnit = dcsGroup:getUnit(1)
    if(firstDcsUnit == nil) then
        return
    end
    if(firstDcsUnit:getID() ~= event.initiator:getID()) then
        return 
    end

    local coalition = dcsGroup:getCoalition()
    local networkName = veafSkynet.defaultIADS[tostring(coalition)]

    veaf.loggers.get(veafSkynet.Id):debug("DYNAMIC SPAWN adding spawned group [" .. dcsGroup:getName() .. "] [id=" .. dcsGroup:getID() .. "] to IADS network [" .. networkName .. "]")
    if (veafSkynet.addGroupToNetwork(networkName, dcsGroup, false, false)) then
        veafSkynet.initializePointDefences(veafSkynet.getNetwork(networkName))
        --iads:buildRadarCoverage()
    end
end

function veafSkynet.monitorDynamicSpawn(bMonitor)
    if (bMonitor) then
        if (veafSkynet.monitorDynamicSpawnHandlerId ~= nil) then
            return -- already active
        end
        veaf.loggers.get(veafSkynet.Id):debug("DYNAMIC SPAWN monitoring ON")
        veafSkynet.monitorDynamicSpawnHandlerId = mist.addEventHandler(veafSkynet.OnDynamicSpawn)
    else
        if (veafSkynet.monitorDynamicSpawnHandlerId == nil) then
            return -- already inactive
        end
        veaf.loggers.get(veafSkynet.Id):debug("DYNAMIC SPAWN monitoring OFF")
        mist.removeEventHandler(veafSkynet.monitorDynamicSpawnHandlerId)
        veafSkynet.monitorDynamicSpawnHandlerId = nil
    end
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- initialisation
-------------------------------------------------------------------------------------------------------------------------------------------------------------
function veafSkynet.isGroupUsable(dcsGroup)
    if (veafSkynet.GroupIntegrationMode == veafSkynet.GroupIntegrationModes.Strict) then
        for _, dcsUnit in pairs(dcsGroup:getUnits()) do
            local dcsUnitType = dcsUnit:getTypeName()
            if (not veafSkynet.iadsEwrUnitsTypes[dcsUnitType] and not veafSkynet.iadsSamUnitsTypes[dcsUnitType]) then
                return false
            end
        end

        return true
    else
        for _, dcsUnit in pairs(dcsGroup:getUnits()) do
            local dcsUnitType = dcsUnit:getTypeName()
            if (veafSkynet.iadsEwrUnitsTypes[dcsUnitType] or veafSkynet.iadsSamUnitsTypes[dcsUnitType]) then
                return true
            end
        end

        return false
    end
end

function veafSkynet.addGroupToNetwork(networkName, dcsGroup, forceEwr, pointDefense, alreadyAddedGroups, silent)
    veaf.loggers.get(veafSkynet.Id):debug("ADD GROUP START [" .. dcsGroup:getName() .. "] [id=" .. dcsGroup:getID() .. "] to IADS network [" .. networkName .. "]")

    if not dcsGroup then
        veaf.loggers.get(veafSkynet.Id):error("No group to find to add to network")
        return false
    end
    
    if (not veafSkynet.isGroupUsable(dcsGroup)) then
        veaf.loggers.get(veafSkynet.Id):trace("Group is not usable for skynet")
        return false        
    end
    
    local forceEwr = false or forceEwr
    local pointDefense = false or pointDefense
    local silent = false or silent

    local batchMode = (alreadyAddedGroups ~= nil)
    local alreadyAddedGroups = alreadyAddedGroups or {}
    local groupName = dcsGroup:getName()
    local coa = dcsGroup:getCoalition()
    local iads = veafSkynet.getIadsOfCoalition(networkName, coa)
    if not(iads) then
        veaf.loggers.get(veafSkynet.Id):debug(string.format("IADS named %s for the coalition of the group %s does not exist", veaf.p(networkName), tostring(groupName)))
        return false
    end
    local didSomething = false

    veaf.loggers.get(veafSkynet.Id):trace(string.format("batchMode=%s forceEwr=%s PointDefense=%s", tostring(batchMode), tostring(forceEwr), tostring(pointDefense)))

    local defended_name = nil
    if pointDefense and not(forceEwr) then
        veaf.loggers.get(veafSkynet.Id):trace(string.format("SAM is requested as pointDefense"))
        
        if pointDefense == true then 
            veaf.loggers.get(veafSkynet.Id):trace(string.format("Find nearest site to defend"))
            defended_name = veafSkynet.getNearestIADSSite(networkName, dcsGroup)
        else
            defended_name = pointDefense
            local defended_SAM = iads:getSAMSiteByGroupName(defended_name)
            local defended_EWR = iads:getEarlyWarningRadars(defended_name)

            local defended_site = defended_EWR
            if defended_SAM then
                defended_site = defended_SAM
            end

            if defended_site then
                local defended_pos = veaf.getAvgGroupPos(defended_name)
                local dcsGroup_pos = veaf.getAvgGroupPos(groupName)
                local distance = math.sqrt((dcsGroup_pos.x-defended_pos.x)^2+(dcsGroup_pos.z-defended_pos.z)^2)
                veaf.loggers.get(veafSkynet.Id):trace(string.format("Distance between requested site and pointDefense : %s", veaf.p(distance)))

                if distance > veafSkynet.MaxPointDefenseDistanceFromSite then
                    defended_name = nil
                    veaf.loggers.get(veafSkynet.Id):info("User requested SAM Site out of reach for point defense")
                end
            else
                defended_name = nil
            end 
        end
    end

    local dcsGroupName = dcsGroup:getName()

    for _, dcsUnit in pairs(dcsGroup:getUnits()) do
        local dcsUnitName = dcsUnit:getName()
        local dcsUnitType = dcsUnit:getTypeName()
        
        local addedSite = nil
        local sLog = string.format(" - iads[%s] unit[%s][%d][%s] group[%s][%d]", iads.name, dcsUnitName, dcsUnit:getID(), dcsUnitType, dcsGroupName, dcsGroup:getID())
    
        if(not veafSkynet.iadsEwrUnitsTypes[dcsUnitType] and not veafSkynet.iadsSamUnitsTypes[dcsUnitType]) then
            veaf.loggers.get(veafSkynet.Id):trace(sLog .. " => unit type is not eligible for skynet")
        elseif(alreadyAddedGroups[groupName]) then
            veaf.loggers.get(veafSkynet.Id):trace(sLog .. " => group as already been marked as added by veafSkynet")
            break -- if group is added no need to go check the other units
        else
            local bShouldBeAdded = true
            local sams = iads:getSAMSites()
            for i = 1, #sams do
                local sam = sams[i]
                if (sam.dcsName == dcsGroupName) then
                    veaf.loggers.get(veafSkynet.Id):trace(sLog .. " => already in network as SAM group")
                    bShouldBeAdded = false
                    break
                end
            end
        
            local ewrs = iads:getEarlyWarningRadars()
            for i = 1, #ewrs do
                local ewr = ewrs[i]
                local dcsGroupEwr = veafSkynet.getDcsGroupFromSkynetElement(ewr)

                if (not dcsGroupEwr) then
                    veaf.loggers.get(veafSkynet.Id):trace(sLog .. " => group not found for skynet ewr " .. veafSkynet.getStringSkynetElement(ewr))
                elseif (dcsGroupEwr:getName() == dcsGroupName) then
                    veaf.loggers.get(veafSkynet.Id):trace(sLog .. " => already in network as EWR group")
                    bShouldBeAdded = false
                    break
                end
            end

            if (not bShouldBeAdded) then
                break -- if group is added no need to go check the other units
            end

            if(veafSkynet.iadsSamUnitsTypes[dcsUnitType]) then
                local samsite = iads:addSAMSite(groupName)
                if (samsite) then
                    addedSite = samsite
                    didSomething = true
                    alreadyAddedGroups[groupName] = true
                    veaf.loggers.get(veafSkynet.Id):trace(sLog .. " => added as SAM")
                end
            end

            local ewrFlag = false
            if (addedSite == nil and veafSkynet.iadsEwrUnitsTypes[dcsUnitType]) then
                local ewr = iads:addEarlyWarningRadar(dcsUnitName)
                if (ewr) then 
                    addedSite = ewr
                    didSomething = true
                    ewrFlag = true
                    veaf.loggers.get(veafSkynet.Id):trace(sLog .. " => added as EWR")
                end
            end

            --user requested configuration
            if addedSite and pointDefense and not(forceEwr) and not(ewrFlag) then
                if defended_name then
                    local text = string.format("Point Defense added to site : %s", string.format(defended_name))
                    veaf.loggers.get(veafSkynet.Id):info(text)
                    if not silent then trigger.action.outText(text,10) end
                    if iads:getSAMSiteByGroupName(defended_name) then
                        veaf.loggers.get(veafSkynet.Id):trace(string.format("adding pointDefense to SAM -> OK"))
                        iads:getSAMSiteByGroupName(defended_name):addPointDefence(addedSite)
                    else
                        veaf.loggers.get(veafSkynet.Id):trace(string.format("adding pointDefense to EWR -> OK"))
                        iads:getEarlyWarningRadars(defended_name):addPointDefence(addedSite)

                        --confirm that the addition of point defenses to the EWR which is gathered through it's group name but only the unit name is stored in the structure
                        --local site_info = iads:getEarlyWarningRadars(defended_name)
                        --veaf.loggers.get(veafSkynet.Id):debug(string.format("Recovered EWR name : %s", veaf.p(site_info[1].dcsName)))
                        --local pointDefenses = site_info[1].pointDefences
                        --veaf.loggers.get(veafSkynet.Id):debug(string.format("Recover pointDefense name : %s", veaf.p(pointDefenses[#pointDefenses].dcsName)))
                    end
                else
                    veaf.loggers.get(veafSkynet.Id):info("Could not find SAM site within range to add point defenses to")
                    if not silent then trigger.action.outText("Could not find SAM site within range to add point defenses to", 15) end
                end
            elseif forceEwr then
                veaf.loggers.get(veafSkynet.Id):trace(string.format("SAM/EWR is forced EWR"))

                if addedSite then
                    veaf.loggers.get(veafSkynet.Id):trace("Unit Forced as EWR")
                    addedSite:setActAsEW(true)
                end
            end

            if (addedSite) then
                break -- if something has been added for this group no need to check the remaining units
            end
        end
    end

    if didSomething then
        if not(batchMode) and not(forceEwr) and not(pointDefense) then
            -- specific configurations, for each SAM type
            veaf.loggers.get(veafSkynet.Id):trace("Specific configuration applied")

            iads:getSAMSitesByNatoName('SA-10'):setActAsEW(false)
            iads:getSAMSitesByNatoName('SA-6'):setActAsEW(false)
            iads:getSAMSitesByNatoName('SA-5'):setActAsEW(false)
            iads:getSAMSitesByNatoName('Patriot'):setActAsEW(false)
            iads:getSAMSitesByNatoName('Hawk'):setActAsEW(false)
        end       

        -- reactivate (rebuild coverage) the IADS
        veaf.loggers.get(veafSkynet.Id):trace("reactivate (rebuild coverage) the IADS")
        veafSkynet.delayedActivate(networkName)

        --add the added site to the structure of the network it was added to
        veafSkynet.structure[networkName].groups[groupName] = { forceEwr = forceEwr, pointDefense = defended_name }
    end

    return didSomething
end

local function initializeIADS(networkName, coa, inRadio, debug)
    local iads = veafSkynet.getIadsOfCoalition(networkName, coa)
    if not(iads) then
        veaf.loggers.get(veafSkynet.Id):trace(string.format("IADS named %s for coalition %s does not exist", veaf.p(networkName), veaf.p(coa)))
        return false
    end
    veaf.loggers.get(veafSkynet.Id):trace(string.format("initializeIADS %s",tostring(iads:getCoalitionString())))

    if debug then
        veaf.loggers.get(veafSkynet.Id):debug("adding debug information")
        local iadsDebug = iads:getDebugSettings()
        iadsDebug.IADSStatus = true
        iadsDebug.radarWentDark = true -- FG iadsDebug.samWentDark = true
        iadsDebug.contacts = true
        iadsDebug.radarWentLive = true
        iadsDebug.noWorkingCommmandCenter = false
        iadsDebug.ewRadarNoConnection = false
        iadsDebug.samNoConnection = false
        iadsDebug.jammerProbability = true
        iadsDebug.addedEWRadar = true
        iadsDebug.hasNoPower = false
        iadsDebug.harmDefence = true
        iadsDebug.samSiteStatusEnvOutput = true
        iadsDebug.earlyWarningRadarStatusEnvOutput = true
    end

    local alreadyAddedGroups = {}
    local dcsGroups = coalition.getGroups(coa)
    for _, dcsGroup in pairs(dcsGroups) do
        if veafSkynet.structure[networkName] then
            local groupName = dcsGroup:getName()
            if groupName then
                local structureData = veafSkynet.structure[networkName].groups[groupName]
                local forceEwr = false
                local pointDefense = false
                if structureData then
                    if structureData.forceEwr then
                        forceEwr = structureData.forceEwr
                    end
                    if structureData.pointDefense then
                        pointDefense = structureData.pointDefense
                    end
                end
                if veafSkynet.loadAllAtInit[tostring(coa)] or structureData then 
                    veafSkynet.addGroupToNetwork(networkName, dcsGroup, forceEwr, pointDefense, alreadyAddedGroups, true)
                end 
            end 
        end
    end

    if veafSkynet.loadAllAtInit[tostring(coa)] then
        veafSkynet.loadAllAtInit[tostring(coa)] = false
    end

    veaf.loggers.get(veafSkynet.Id):trace("Specific configuration applied")
    -- specific configurations, for each SAM type
    iads:getSAMSitesByNatoName('SA-10'):setActAsEW(false)
    iads:getSAMSitesByNatoName('SA-6'):setActAsEW(false)
    iads:getSAMSitesByNatoName('SA-5'):setActAsEW(false)
    iads:getSAMSitesByNatoName('Patriot'):setActAsEW(false)
    iads:getSAMSitesByNatoName('Hawk'):setActAsEW(false)

    veafSkynet.initializePointDefences(veafSkynet.getNetwork(networkName)) -- Management of point defences (Flogas) - initialization

    if inRadio then
        --activate the radio menu to toggle IADS Status output
        iads:addRadioMenu()
    end

    --activate (build coverage) the IADS
	veaf.loggers.get(veafSkynet.Id):debug("activate (build coverage) the IADS")
    veafSkynet.delayedActivate(networkName)
end

local function createNetwork(networkName, coa, loadUnits, UserAdd)
   
    local UserAdd = UserAdd or false
    local loadUnits = loadUnits or false

    local networkName = networkName
    if networkName then 
        networkName = tostring(networkName) 
    else
        veaf.loggers.get(veafSkynet.Id):error("networkName is of invalid format")
        return false
    end
    local coa = coa
    if coa then 
        coa = tonumber(coa) 
    else
        veaf.loggers.get(veafSkynet.Id):error("Coalition specified is of invalid format")
        return false
    end
    veaf.loggers.get(veafSkynet.Id):trace("networkName= %s", veaf.p(networkName))
    veaf.loggers.get(veafSkynet.Id):trace("CoalitionID= %s", veaf.p(coa))
    veaf.loggers.get(veafSkynet.Id):trace("loadUnits= %s", veaf.p(loadUnits))
    veaf.loggers.get(veafSkynet.Id):trace("UserAdd= %s", veaf.p(UserAdd))

    if networkName and coa then
        if (UserAdd and not veafSkynet.structure[networkName]) or not UserAdd then
            local debugFlag = veafSkynet.debugBlue
            local includeInRadio = veafSkynet.includeBlueInRadio

            if coa == coalition.side.RED then
                debugFlag = veafSkynet.debugRed
                includeInRadio = veafSkynet.includeRedInRadio
            end

            veaf.loggers.get(veafSkynet.Id):trace("creating network...")
            local iads = SkynetIADS:create(networkName)
            iads.coalitionID = coa
            if iads then
                if not veafSkynet.structure[networkName] then
                    veaf.loggers.get(veafSkynet.Id):trace("network is new")
                    veafSkynet.structure[networkName] = {}
                    veafSkynet.structure[networkName].coalitionID = coa
                    veafSkynet.structure[networkName].includeInRadio = includeInRadio
                    veafSkynet.structure[networkName].debugFlag = debugFlag
                    veafSkynet.structure[networkName].groups = {}
                end
                veafSkynet.structure[networkName].iads = iads

                if veaf.loggers.get(veafSkynet.Id):wouldLogTrace() then
                    veaf.loggers.get(veafSkynet.Id):trace("Stored structure for network named %s :", veaf.p(networkName))
                    for index,_ in pairs(veafSkynet.structure[networkName]) do
                        veaf.loggers.get(veafSkynet.Id):trace("-> %s", veaf.p(index))
                    end
                    veaf.loggers.get(veafSkynet.Id):trace("Stored IADS structure for network named %s :", veaf.p(networkName))
                    for index,_ in pairs(veafSkynet.structure[networkName].iads) do
                        veaf.loggers.get(veafSkynet.Id):trace("-> %s", veaf.p(index))
                    end
                    veaf.loggers.get(veafSkynet.Id):trace("CoalitionID for network named %s :", veaf.p(networkName))
                    veaf.loggers.get(veafSkynet.Id):trace("-> %s", veaf.p(veafSkynet.structure[networkName].iads.coalitionID))
                    veaf.loggers.get(veafSkynet.Id):trace("-> %s", veaf.p(veafSkynet.structure[networkName].iads:getCoalitionString()))
                end

                if loadUnits then
                    initializeIADS(networkName, coa, includeInRadio, debugFlag)
                end
                return true
            end
        else
            local text = string.format("The network name \"%s\" already exists", veaf.p(networkName))
            veaf.loggers.get(veafSkynet.Id):info(text)
        end
    end
    return false
end

-- reset an IADS network, useful when many additions are made at once to harmonize the structure
function veafSkynet.reinitializeNetwork(networkName)
    if not veafSkynet.initialized then 
        return false 
    end

    if networkName and veafSkynet.structure[networkName] then
        local networkStructure = veafSkynet.structure[networkName]
        if networkStructure.iads then
            veaf.loggers.get(veafSkynet.Id):trace("Stored structure for network named %s has IADS, deactivating", veaf.p(networkName))
            if networkStructure.includeInRadio then 
                veaf.loggers.get(veafSkynet.Id):trace("Removing radio menu...")
                networkStructure.iads:removeRadioMenu()
            end
            networkStructure.iads:deactivate()
        end
        createNetwork(networkName, networkStructure.coalitionID, true)
    end
end

-- reset an IADS networks, useful when many additions/destructions are made at once to harmonize the structures on the skynet side
function veafSkynet.reinitialize()
    if not veafSkynet.initialized then 
        return false 
    end

    for networkName,_ in pairs(veafSkynet.structure) do
        veafSkynet.reinitializeNetwork(networkName)
    end
end

function veafSkynet.initialize(includeRedInRadio, debugRed, includeBlueInRadio, debugBlue)
    veaf.loggers.get(veafSkynet.Id):info(string.format("initializing Skynet in %s seconds", tostring(veafSkynet.DelayForStartup)))
    mist.scheduleFunction(veafSkynet._initialize,{includeRedInRadio, debugRed, includeBlueInRadio, debugBlue}, timer.getTime()+veafSkynet.DelayForStartup)
end

function veafSkynet._initialize(includeRedInRadio, debugRed, includeBlueInRadio, debugBlue)
    veafSkynet.includeRedInRadio = includeRedInRadio or false
    veafSkynet.debugRed = debugRed or false
    veafSkynet.includeBlueInRadio = includeBlueInRadio or false
    veafSkynet.debugBlue = debugBlue or false

    veaf.loggers.get(veafSkynet.Id):info("Initializing module")
    
    veaf.loggers.get(veafSkynet.Id):debug(string.format("includeRedInRadio=%s",veaf.p(includeRedInRadio)))
    veaf.loggers.get(veafSkynet.Id):debug(string.format("debugRed=%s",veaf.p(debugRed)))
    veaf.loggers.get(veafSkynet.Id):debug(string.format("includeBlueInRadio=%s",veaf.p(includeBlueInRadio)))
    veaf.loggers.get(veafSkynet.Id):debug(string.format("debugBlue=%s",veaf.p(debugBlue)))
    
    -- prepare the list of units supported by Skynet IADS
    for _, groupData in pairs(SkynetIADS.database) do
        for _, listName in pairs({ "searchRadar", "trackingRadar", "launchers", "misc" }) do
            if groupData['type'] ~= 'ewr' then
                local list = groupData[listName]
                if list then
                    for unitType, _ in pairs(list) do
                        veaf.loggers.get(veafSkynet.Id):trace(string.format("-> SAM"))
                        veafSkynet.iadsSamUnitsTypes[unitType] = true
                    end
                end
            end
        end
    end
    veaf.loggers.get(veafSkynet.Id):trace(string.format("veafSkynet.iadsSamUnitsTypes=%s",veaf.p(veafSkynet.iadsSamUnitsTypes)))
    
    -- add EWR-capable units
    for _, unit in pairs(dcsUnits.DcsUnitsDatabase) do
        if unit then
            veaf.loggers.get(veafSkynet.Id):trace(string.format("testing unit %s",veaf.p(unit.type)))
            if unit.attribute then
                veaf.loggers.get(veafSkynet.Id):trace(string.format("unit.attribute = %s",veaf.p(unit.attribute)))
                if (unit.attribute["SAM SR"]) then
                    veafSkynet.iadsEwrUnitsTypes[unit.type] = true
                    veaf.loggers.get(veafSkynet.Id):trace(string.format("-> EWR"))
                elseif (unit.attribute["EWR"]) then
                    veafSkynet.iadsEwrUnitsTypes[unit.type] = true
                    veaf.loggers.get(veafSkynet.Id):trace(string.format("-> EWR"))
                elseif (unit.attribute["AWACS"]) then
                    veafSkynet.iadsEwrUnitsTypes[unit.type] = true
                    veaf.loggers.get(veafSkynet.Id):trace(string.format("-> EWR"))
                end
            end
        end
    end
    veaf.loggers.get(veafSkynet.Id):trace(string.format("veafSkynet.iadsEwrUnitsTypes=%s",veaf.p(veafSkynet.iadsEwrUnitsTypes)))
    

    veaf.loggers.get(veafSkynet.Id):info("Creating IADS for BLUE")
    createNetwork(veafSkynet.defaultIADS[tostring(coalition.side.BLUE)], coalition.side.BLUE, true)

    veaf.loggers.get(veafSkynet.Id):info("Creating IADS for RED")
    createNetwork(veafSkynet.defaultIADS[tostring(coalition.side.RED)], coalition.side.RED, true)

    veafSkynet.initialized = true

    if (veafSkynet.CommandCentersPreinitialize and #veafSkynet.CommandCentersPreinitialize > 0) then
        for _, commandCenter in pairs(veafSkynet.CommandCentersPreinitialize) do
            veafSkynet.addCommandCenterOfCoalition(commandCenter.CoalitionId, commandCenter.CommandCenterName) 
        end

        veafSkynet.CommandCentersPreinitialize = {}
    end
    
    if(veafSkynet.DynamicSpawn) then
        veafSkynet.monitorDynamicSpawn(true)
    end

    veaf.loggers.get(veafSkynet.Id):info(string.format("Skynet IADS has been initialized"))
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Command centers and network deactivation
-------------------------------------------------------------------------------------------------------------------------------------------------------------
veafSkynet.CommandCentersPreinitialize = {} -- this is to memorize the command centers requested for a coalition, if the network of the coalition does not exist yet

function veafSkynet.addCommandCenter(veafSkynetNetwork, sCommandCenterName)
    local iads = veafSkynetNetwork.iads
    
    local dcsCommandCenterObject = StaticObject.getByName(sCommandCenterName)
    if (not dcsCommandCenterObject) then
        dcsCommandCenterObject = Unit.getByName(sCommandCenterName)
    end
    if (not dcsCommandCenterObject) then
        local dcsCommandCenterGroup = Group.getByName(sCommandCenterName)
        if (dcsCommandCenterGroup) then
            dcsCommandCenterObject = dcsCommandCenterGroup:getUnit(1)
        end
    end

    if (not dcsCommandCenterObject) then
        veaf.loggers.get(veafSkynet.Id):error("Requested command center not found: " .. sCommandCenterName)
        return
    end
    
    iads:addCommandCenter(dcsCommandCenterObject)
    veaf.loggers.get(veafSkynet.Id):trace("Command center unit added [" .. sCommandCenterName .. "]")
    iads:buildRadarCoverage() -- as command center is added after the network initialisation, coverage should be rebuilt
end

function veafSkynet.addCommandCenterOfCoalition(iCoalitionId, sCommandCenterName)
    if (veafSkynet.initialized) then
        local veafSkynetNetwork = veafSkynet.getNetwork(veafSkynet.defaultIADS[tostring(iCoalitionId)])

        if (veafSkynetNetwork == nil) then
            veaf.loggers.get(veafSkynet.Id):error("Veaf skynet network not found. Please ensure that veafSkynetIadsHelper has been initialized for coalition [" .. iCoalitionId .. "]")
            return    
        end
        
        veafSkynet.addCommandCenter(veafSkynetNetwork, sCommandCenterName)  
    else
        veaf.loggers.get(veafSkynet.Id):trace("Veaf skynet not initialized. Command center [" .. sCommandCenterName .. "] stored to be added later for [" .. iCoalitionId .. "]")
        table.insert (veafSkynet.CommandCentersPreinitialize, {CoalitionId = iCoalitionId, CommandCenterName = sCommandCenterName})
    end
end

function veafSkynet.destroyCommandCenters(veafSkynetNetwork, iExplosionStrength)
    iExplosionStrength = iExplosionStrength or 200 -- default explosion may not be enough to destroy certain bunkers
    local iads = veafSkynetNetwork.iads

    if (not iads:isCommandCenterUsable()) then
        veaf.loggers.get(veafSkynet.Id):trace("Network has no usable command center")
        return
    end

    local ccs = iads:getCommandCenters()

    for i = 1, #ccs do
        local cc = ccs[i]

        local dcsObject = cc.dcsRepresentation

        if (dcsObject:isExist()) then
            local category = getmetatable(dcsObject)
            if (category == Group) then
                for _, dcsUnit in pairs(dcsObject:getUnits()) do
                    veaf.loggers.get(veafSkynet.Id):trace("Command center unit exploded: " .. dcsUnit:getName())
                    trigger.action.explosion(dcsUnit:getPosition().p, iExplosionStrength)
                end
            else
                veaf.loggers.get(veafSkynet.Id):trace("Command center unit exploded: " .. dcsObject:getName())
                trigger.action.explosion(dcsObject:getPosition().p, iExplosionStrength)
            end
        end
    end
end

function veafSkynet.destroyCommandCentersOfCoalition(iCoalitionId, iExplosionStrength)
    local veafSkynetNetwork = veafSkynet.getNetwork(veafSkynet.defaultIADS[tostring(iCoalitionId)])
    veafSkynet.destroyCommandCenters(veafSkynetNetwork, iExplosionStrength)
end

function veafSkynet.deactivateNetwork(veafSkynetNetwork, elementStates)
    local elementState = elementStates or veafSkynet.SkynetElementStates.Live
    local iads = veafSkynetNetwork.iads

    local sElementState = "live"
    if (elementState == veafSkynet.SkynetElementStates.Autonomous) then
        sElementState = "autonomous"
    elseif (elementState == veafSkynet.SkynetElementStates.Dark) then
        sElementState = "dark"
    end
    veaf.loggers.get(veafSkynet.Id):trace("Deactivating network " .. iads:getCoalitionString() .. ". Network elements will go " .. sElementState)

    local function setGroupState(skynetElement)
        skynetElement:finishHarmDefence()
        skynetElement:cleanUp()

        veafSkynet.removePointDefencesFromSkynetElement(skynetElement)
        if (elementState == veafSkynet.SkynetElementStates.Autonomous) then
            skynetElement:resetAutonomousState()
            skynetElement:goAutonomous()
        elseif (elementState == veafSkynet.SkynetElementStates.Dark) then
            skynetElement:goDark() -- goDark will not always turn the radar off - eg an EWR that is tracking targets will stay on
        else
            skynetElement:goLive() -- goLive will not always turn the radar on - eg a SAM site out of ammo will stay off
        end
    end

    veafSkynet.monitorDynamicSpawn(false)
    iads:deactivate()

    local ewrs = iads:getEarlyWarningRadars()
    for i = 1, #ewrs do
        local ewr = ewrs[i]
        setGroupState(ewr)
    end
    local sams = iads:getSAMSites()
    for i = 1, #sams do
        local sam = sams[i]
        setGroupState(sam)        
    end

    -- Copying the elements and emptying the Skynet lists before doing the state switch to ensure that Skynet does not keep controlling the elements after deactivation.
    -- Does not seem necessary after all, and keeping the lists in the Skynet network allows to reactivate it later if needed.
    -- Note that as it is, reactivating will not rebuild point defences, so it is more of a testing thing still.
    -- Code kept here just in case.
    --[[
    local skynetGroups = {}
    for i = 1, #iads.earlyWarningRadars do
        table.insert(skynetGroups, iads.earlyWarningRadars[i])
    end
    for i = 1, #iads.samSites do
        table.insert(skynetGroups, iads.samSites[i])
    end
    
    iads.earlyWarningRadars = {}
    iads.samSites = {}

    for i = 1, #skynetGroups do
        local skynetGroup = skynetGroups[i]
        setGroupState(skynetGroup)
    end
    ]]
end

function veafSkynet.deactivateNetworkOfCoalition(iCoalitionId, elementStates)
    local veafSkynetNetwork = veafSkynet.getNetwork(veafSkynet.defaultIADS[tostring(iCoalitionId)])
    veafSkynet.deactivateNetwork(veafSkynetNetwork, elementStates)
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Load module
-------------------------------------------------------------------------------------------------------------------------------------------------------------
veaf.loggers.get(veafSkynet.Id):info(string.format("Loading version %s", veafSkynet.Version))
