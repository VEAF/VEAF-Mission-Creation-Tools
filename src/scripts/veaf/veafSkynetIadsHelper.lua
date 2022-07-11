-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- VEAF helper for Skynet-IADS
-- By zip (2021)
--
-- Features:
-- ---------
-- * This module offers support for integrating Skynet-IADS in a mission
--
-- Prerequisite:
-- ------------
-- * This script requires DCS 2.5.1 or higher and MIST 4.3.74 or higher.
-- * It also requires Skynet-IADS !
-- * It also requires all the veaf scripts !
--
-- Basic Usage:
-- ------------
-- TODO
--
-------------------------------------------------------------------------------------------------------------------------------------------------------------

veafSkynet = {}

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Global settings. Stores the script constants
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Identifier. All output in DCS.log will start with this.
veafSkynet.Id = "SKYNET"

--- Version.
veafSkynet.Version = "1.2.1"

-- trace level, specific to this module
veafSkynet.LogLevel = "trace"

veaf.loggers.new(veafSkynet.Id, veafSkynet.LogLevel)

-- delay before the mission groups are added to the IADS' at start
veafSkynet.DelayForStartup = 1

-- delay before restarting the IADS when adding a single group
veafSkynet.DelayForRestart = 10

-- maximum x or y (z in DCS) between a SAM site and it's point defenses in meters
veafSkynet.MaxPointDefenseDistanceFromSite = 10000

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Do not change anything below unless you know what you are doing!
-------------------------------------------------------------------------------------------------------------------------------------------------------------

veafSkynet.initialized = false
veafSkynet.redIADS = nil
veafSkynet.blueIADS = nil
veafSkynet.iadsSamUnitsTypes = {}
veafSkynet.iadsEwrUnitsTypes = {}

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Utility methods
-------------------------------------------------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- core functions
-------------------------------------------------------------------------------------------------------------------------------------------------------------

function veafSkynet.getIadsOfCoalition(coa)
    local iads = nil
    if coa == coalition.side.RED then
        iads = veafSkynet.redIADS
    elseif coa == coalition.side.BLUE then
        iads = veafSkynet.blueIADS
    end
    return iads
end

function veafSkynet.getNearestIADSSite(dcsUnit, currentGroup)
    local coa = dcsUnit:getCoalition()
    veaf.loggers.get(veafSkynet.Id):trace(string.format("coalition of pointDefense : %s", veaf.p(coa))) 
    local defensePos = dcsUnit:getPosition()
    veaf.loggers.get(veafSkynet.Id):debug(string.format("pointDefense Position : %s", veaf.p(defensePos))) 
    local iads = veafSkynet.getIadsOfCoalition(coa)
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
                    local distance = math.sqrt((pos.p.x-groupAvgPosition.x)^2+(pos.p.z-groupAvgPosition.z)^2)
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
    nearestEWRname, minEWRDistance = searchForGroup(CoalitionSites, defensePos, currentGroup, true)

    --search for SAM sites
    CoalitionSites = iads:getSAMSites()
    nearestSAMname, minSAMDistance = searchForGroup(CoalitionSites, defensePos, currentGroup)    

    if minEWRDistance <= minSAMDistance then
        return nearestEWRname
    end
    return nearestSAMname
end


function veafSkynet.addGroupToNetwork(dcsGroup, forceEwr, pointDefense, alreadyAddedGroups)
    if not veafSkynet.initialized then 
        return false 
    end

    local forceEwr = false or forceEwr
    local pointDefense = false or pointDefense

    local batchMode = (alreadyAddedGroups ~= nil)
    local alreadyAddedGroups = alreadyAddedGroups or {}
    local groupName = dcsGroup:getName()
    local coa = dcsGroup:getCoalition()
    local iads = veafSkynet.getIadsOfCoalition(coa)
    if not(iads) then
        veaf.loggers.get(veafSkynet.Id):trace(string.format("no IADS for the coalition of %s", tostring(groupName)))
        return false
    end
    local didSomething = false
    veaf.loggers.get(veafSkynet.Id):trace(string.format("addGroupToNetwork(%s) to %s", tostring(groupName), tostring(iads:getCoalitionString())))
    veaf.loggers.get(veafSkynet.Id):trace(string.format("batchMode = %s", tostring(batchMode)))
    veaf.loggers.get(veafSkynet.Id):trace(string.format("forceEwr = %s", tostring(forceEwr)))
    veaf.loggers.get(veafSkynet.Id):trace(string.format("PointDefense= %s", tostring(pointDefense)))

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
            veaf.loggers.get(veafSkynet.Id):trace(string.format("SAM is pointDefense"))

            local defended_name = nil
            if pointDefense == true then 
                veaf.loggers.get(veafSkynet.Id):trace(string.format("Find nearest site to defend"))
                defended_name = veafSkynet.getNearestIADSSite(dcsUnit, groupName)
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
                    local dcsUnit_pos = dcsUnit:getPosition()
                    local distance = math.sqrt((dcsUnit_pos.p.x-defended_pos.x)^2+(dcsUnit_pos.p.z-defended_pos.z)^2)
                    veaf.loggers.get(veafSkynet.Id):trace(string.format("Distance between requested site and pointDefense : %s", veaf.p(distance)))

                    if distance > veafSkynet.MaxPointDefenseDistanceFromSite then
                        defended_name = nil
                        veaf.loggers.get(veafSkynet.Id):info("User requested SAM Site out of reach for point defense")
                    end
                else
                    defended_name = nil
                end 
            end
            
            if defended_name then
                local text = string.format("Point Defense added to site : %s", string.format(defended_name))
                veaf.loggers.get(veafSkynet.Id):info(text)
                trigger.action.outText(text,10)
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
                trigger.action.outText("Could not find SAM site within range to add point defenses to", 15)
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
            iads:getSAMSitesByNatoName('Dog Ear'):setActAsEW(false)
            iads:getSAMSitesByNatoName('Tall Rack'):setActAsEW(true) --55G6 EWR
        end       
        -- reactivate the IADS after a warmup delay
        iads:setupSAMSitesAndThenActivate(veafSkynet.DelayForRestart)
    end

    return didSomething
end

local function initializeIADS(coa, inRadio, debug)
    local iads = veafSkynet.getIadsOfCoalition(coa)
    veaf.loggers.get(veafSkynet.Id):debug(string.format("initializeIADS %s",tostring(iads:getCoalitionString())))

    if debug then
        veaf.loggers.get(veafSkynet.Id):debug("adding debug information")
        local iadsDebug = iads:getDebugSettings()
        iadsDebug.IADSStatus = true
        iadsDebug.samWentDark = true
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
        veafSkynet.addGroupToNetwork(dcsGroup, alreadyAddedGroups)
    end

    -- specific configurations, for each SAM type
    iads:getSAMSitesByNatoName('SA-10'):setActAsEW(false)
    iads:getSAMSitesByNatoName('SA-6'):setActAsEW(false)
    iads:getSAMSitesByNatoName('SA-5'):setActAsEW(false)
    iads:getSAMSitesByNatoName('Patriot'):setActAsEW(false)
    iads:getSAMSitesByNatoName('Hawk'):setActAsEW(false)
	iads:getSAMSitesByNatoName('Dog Ear'):setActAsEW(false)  
	iads:getSAMSitesByNatoName('Tall Rack'):setActAsEW(true) --55G6 EWR

    if inRadio then
        --activate the radio menu to toggle IADS Status output
        iads:addRadioMenu()
    end

    --activate the IADS after a 60s warmup delay (default value)
    iads:setupSAMSitesAndThenActivate()
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- initialisation
-------------------------------------------------------------------------------------------------------------------------------------------------------------

local function createNetworks(loadUnits)
    veafSkynet.redIADS = SkynetIADS:create("RED IADS")
    veafSkynet.redIADS.coalitionID = coalition.side.RED
    veafSkynet.blueIADS = SkynetIADS:create("BLUE IADS")
    veafSkynet.blueIADS.coalitionID = coalition.side.BLUE
    if loadUnits then
        initializeIADS(coalition.side.RED, veafSkynet.includeRedInRadio, veafSkynet.debugRed)
        initializeIADS(coalition.side.BLUE, veafSkynet.includeBlueInRadio, veafSkynet.debugBlue)
    end
end

-- reset the IADS networks and rebuild them. Useful when a dynamic combat zone is deactivated
function veafSkynet.reinitialize()
    if not veafSkynet.initialized then 
        return false 
    end

    if veafSkynet.redIADS then
        if veafSkynet.includeRedInRadio then 
            veafSkynet.redIADS:removeRadioMenu()
        end
        veafSkynet.redIADS:deactivate()
    end
    if veafSkynet.blueIADS then
        if veafSkynet.includeBlueInRadio then 
            veafSkynet.blueIADS:removeRadioMenu()
        end
        veafSkynet.blueIADS:deactivate()
    end
    createNetworks(true)
end

function veafSkynet.initialize(includeRedInRadio, debugRed, includeBlueInRadio, debugBlue)
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
    for groupName, groupData in pairs(SkynetIADS.database) do
        for _, listName in pairs({ "searchRadar", "trackingRadar", "launchers", "misc" }) do
            if groupData['type'] ~= 'ewr' then
                local list = groupData[listName]
                if list then 
                    for unitType, _ in pairs(list) do
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
    
    createNetworks(false)

    veaf.loggers.get(veafSkynet.Id):info(string.format("Loading units in %s seconds", tostring(veafSkynet.DelayForStartup)))
    mist.scheduleFunction(veafSkynet.reinitialize,{}, timer.getTime()+veafSkynet.DelayForStartup)

    veafSkynet.initialized = true
    veaf.loggers.get(veafSkynet.Id):info(string.format("Skynet IADS has been initialized"))
end

veaf.loggers.get(veafSkynet.Id):info(string.format("Loading version %s", veafSkynet.Version))
