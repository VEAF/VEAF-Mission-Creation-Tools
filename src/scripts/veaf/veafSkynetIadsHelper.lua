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
veafSkynet.Version = "1.1.2"

-- trace level, specific to this module
--veafSkynet.LogLevel = "trace"

veaf.loggers.new(veafSkynet.Id, veafSkynet.LogLevel)

-- delay before the mission groups are added to the IADS' at start
veafSkynet.DelayForStartup = 1

-- delay before restarting the IADS when adding a single group
veafSkynet.DelayForRestart = 10

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


function veafSkynet.addGroupToNetwork(dcsGroup, alreadyAddedGroups)
    if not veafSkynet.initialized then 
        return false 
    end

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

    for _, dcsUnit in pairs(dcsGroup:getUnits()) do
        local unitName = dcsUnit:getName()
        local unitType = dcsUnit:getDesc()["typeName"]
        veaf.loggers.get(veafSkynet.Id):trace(string.format("checking unit %s of type %s", tostring(unitName), tostring(unitType)))

        -- check if the unitType is supported by Skynet IADS
        if veafSkynet.iadsSamUnitsTypes[unitType] then
            veaf.loggers.get(veafSkynet.Id):trace(string.format("-> supported SAM type"))
            if not(alreadyAddedGroups[groupName]) then
                veaf.loggers.get(veafSkynet.Id):trace(string.format("adding a SAM group : %s", groupName))
                local samsite = iads:addSAMSite(groupName)
                if samsite then 
                    didSomething = true
                    alreadyAddedGroups[groupName] = true
                    veaf.loggers.get(veafSkynet.Id):trace(string.format("adding a SAM -> OK"))
                end
            end
        end
        if veafSkynet.iadsEwrUnitsTypes[unitType] then
            if not(alreadyAddedGroups[groupName]) then -- only add EWR for units not belonging to successfully initialized SAM groups
                veaf.loggers.get(veafSkynet.Id):trace(string.format("adding an EWR unit : %s", unitName))
                local ewr = iads:addEarlyWarningRadar(unitName)
                if ewr then 
                    didSomething = true
                end
            end        
        end
    end

    if didSomething and not(batchMode) then
        -- specific configurations, for each SAM type
        iads:getSAMSitesByNatoName('SA-10'):setActAsEW(true)
        iads:getSAMSitesByNatoName('SA-6'):setActAsEW(true)
        iads:getSAMSitesByNatoName('Patriot'):setActAsEW(true)
        iads:getSAMSitesByNatoName('Hawk'):setActAsEW(true)

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
    iads:getSAMSitesByNatoName('SA-10'):setActAsEW(true)
    iads:getSAMSitesByNatoName('SA-6'):setActAsEW(true)
    iads:getSAMSitesByNatoName('Patriot'):setActAsEW(true)
    iads:getSAMSitesByNatoName('Hawk'):setActAsEW(true)

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
                elseif (unit.attribute["Ships"] and (unit.attribute["RADAR_BAND1_FOR_ARM"] or unit.attribute["RADAR_BAND2_FOR_ARM"])) then
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
