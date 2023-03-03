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
veafSkynet.Version = "2.1.1"

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

--table containing the structure of each IADS network, first level is accessed with the IADS name. This contains the .coalitionID of the network, the IADS network (.iads), the groups added to the network (.groups) stored by groupName, 
--wether this network should appear on the radio menu (.includeInRadio) and lastly if this network is in debug mode (.debugFlag). The groups store whether the group was .forceEwr or .pointDefense.
veafSkynet.structure = {}

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Utility methods
-------------------------------------------------------------------------------------------------------------------------------------------------------------

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


function veafSkynet.addGroupToNetwork(networkName, dcsGroup, forceEwr, pointDefense, alreadyAddedGroups, silent)
    veaf.loggers.get(veafSkynet.Id):debug("addGroupToNetwork(%s)", veaf.p(networkName))

    if not dcsGroup then
        veaf.loggers.get(veafSkynet.Id):error("No group to find to add to network")
        return false
    end

    local forceEwr = false or forceEwr
    local pointDefense = false or pointDefense
    local silent = false or silent

    local batchMode = (alreadyAddedGroups ~= nil)
    local alreadyAddedGroups = alreadyAddedGroups or {}
    local groupName = dcsGroup:getName()
    local coa = dcsGroup:getCoalition()
    veaf.loggers.get(veafSkynet.Id):trace(string.format("networkName= %s", tostring(networkName)))
    veaf.loggers.get(veafSkynet.Id):trace(string.format("groupName= %s", tostring(groupName)))
    veaf.loggers.get(veafSkynet.Id):trace(string.format("Coalition= %s", tostring(coa)))
    local iads = veafSkynet.getIadsOfCoalition(networkName, coa)
    if not(iads) then
        veaf.loggers.get(veafSkynet.Id):trace(string.format("IADS named %s for the coalition of the group %s does not exist", veaf.p(networkName), tostring(groupName)))
        return false
    end
    local didSomething = false
    veaf.loggers.get(veafSkynet.Id):trace(string.format("addGroupToNetwork(%s) to %s", tostring(groupName), tostring(iads:getCoalitionString())))
    veaf.loggers.get(veafSkynet.Id):trace(string.format("batchMode = %s", tostring(batchMode)))
    veaf.loggers.get(veafSkynet.Id):trace(string.format("forceEwr = %s", tostring(forceEwr)))
    veaf.loggers.get(veafSkynet.Id):trace(string.format("PointDefense= %s", tostring(pointDefense)))

    local defended_name = nil
    if pointDefense and not(forceEwr) then
        veaf.loggers.get(veafSkynet.Id):trace(string.format("SAM is pointDefense"))
        
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

    for _, dcsUnit in pairs(dcsGroup:getUnits()) do
        local unitName = dcsUnit:getName()
        local unitType = dcsUnit:getDesc()["typeName"]

        local addedSite = nil

        veaf.loggers.get(veafSkynet.Id):trace(string.format("checking unit %s of type %s", tostring(unitName), tostring(unitType)))

        -- check if the unitType is supported by Skynet IADS
        if veafSkynet.iadsSamUnitsTypes[unitType] then
            veaf.loggers.get(veafSkynet.Id):trace(string.format("-> supported SAM type"))
            if not(alreadyAddedGroups[groupName]) then
                veaf.loggers.get(veafSkynet.Id):trace(string.format("adding a SAM group : %s", groupName))
                local samsite = iads:addSAMSite(groupName)
                if samsite then 
                    addedSite = samsite
                    didSomething = true
                    alreadyAddedGroups[groupName] = true
                    veaf.loggers.get(veafSkynet.Id):trace(string.format("adding a SAM -> OK"))
                end
            end
        end

        local ewrFlag = false
        if veafSkynet.iadsEwrUnitsTypes[unitType] then
            if not(alreadyAddedGroups[groupName]) then -- only add EWR for units not belonging to successfully initialized SAM groups
                veaf.loggers.get(veafSkynet.Id):trace(string.format("adding an EWR unit : %s", unitName))
                local ewr = iads:addEarlyWarningRadar(unitName)
                if ewr then 
                    addedSite = ewr
                    didSomething = true
                    ewrFlag = true
                    veaf.loggers.get(veafSkynet.Id):trace(string.format("adding an EWR -> OK"))
                end
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

    if inRadio then
        --activate the radio menu to toggle IADS Status output
        iads:addRadioMenu()
    end

    --activate (build coverage) the IADS
	veaf.loggers.get(veafSkynet.Id):debug("activate (build coverage) the IADS")
    veafSkynet.delayedActivate(networkName)
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- initialisation
-------------------------------------------------------------------------------------------------------------------------------------------------------------

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
    veaf.loggers.get(veafSkynet.Id):info(string.format("Skynet IADS has been initialized"))
end

veaf.loggers.get(veafSkynet.Id):info(string.format("Loading version %s", veafSkynet.Version))
