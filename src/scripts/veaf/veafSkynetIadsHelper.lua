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
veafSkynet.Id = "SKYNET - "

--- Version.
veafSkynet.Version = "0.0.1"

-- trace level, specific to this module
veafSkynet.Trace = true

veafSkynet.DelayForStartup = 1

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Do not change anything below unless you know what you are doing!
-------------------------------------------------------------------------------------------------------------------------------------------------------------

veafSkynet.redIADS = nil
veafSkynet.blueIADS = nil
veafSkynet.iadsSamUnitsTypes = {}
veafSkynet.iadsEwrUnitsTypes = {}

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Utility methods
-------------------------------------------------------------------------------------------------------------------------------------------------------------

function veafSkynet.logError(message)
    veaf.logError(veafSkynet.Id .. message)
end

function veafSkynet.logInfo(message)
    veaf.logInfo(veafSkynet.Id .. message)
end

function veafSkynet.logDebug(message)
    veaf.logDebug(veafSkynet.Id .. message)
end

function veafSkynet.logTrace(message)
    if message and veafSkynet.Trace then 
        veaf.logTrace(veafSkynet.Id .. message)
    end
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- core functions
-------------------------------------------------------------------------------------------------------------------------------------------------------------

local function getIadsOfCoalition(coalition)
    local iads = nil
    if coalition == coalition.side.RED then
        iads = veafSkynet.redIADS
    elseif coalition == coalition.side.BLUE then
        iads = veafSkynet.blueIADS
    end
    return iads
end

function veafSkynet.addSamGroupToNetwork(group)
    veafSkynet.logDebug("addSamGroupToNetwork()")

    local groupname = group
    local group = group
    if type(groupname) ~= "string" then
        if group then
            groupname = group:getName()
        else
            groupname = "nil"
        end
    else
        group = Group.getByName(groupname)
        if not group then
            veafSkynet.logError(string.format("cannot find group named %s", groupname))
        end
    end
    veafSkynet.logDebug(string.format("groupname = %s",tostring(groupname)))

    -- find the group's coalition
    local coalition = group:getCoalition()
    veafSkynet.logTrace(string.format("coalition = %s",tostring(coalition)))
    
    -- browse units to find EWRs
    for _, unit in pairs(group:getUnits()) do
        veafSkynet.logTrace(unit:getName())
        veafSkynet.logTrace(veaf.p(unit))
        if unit["type"] == "EWR" then
            veafSkynet.addEWRadarToNetwork(unit)
        end
    end

    local iads = getIadsOfCoalition(coalition)
    if iads then
        iads:addSAMSite(groupname)
        veafSkynet.logDebug(string.format("added SAM group %s to IADS %s", groupname, iads:getCoalitionString()))
    end

end

function veafSkynet.addEWRadarToNetwork(unit)
    veafSkynet.logDebug("addEWRadarToNetwork()")

    local unitname = unit
    local unit = unit
    if type(unitname) ~= "string" then
        if unit then
            unitname = unit:getName()
        else
            unitname = "nil"
        end
    else
        unit = Unit.getByName(unitname)
        if not unit then
            veafSkynet.logError(string.format("cannot find unit named %s", unitname))
        end
    end
    veafSkynet.logDebug(string.format("unitname = %s",tostring(unitname)))

    -- find the unit's coalition
    local coalition = unit:getCoalition()
    veafSkynet.logTrace(string.format("coalition = %s",tostring(coalition)))
    
    local iads = getIadsOfCoalition(coalition)
    if iads then
        iads:addEarlyWarningRadar(unitname)
        veafSkynet.logDebug(string.format("added EWR unit %s to IADS %s", unitname, iads:getCoalitionString()))
    end
end

---
--- lists all EWR units and SAM groups in the world
---
local function findUnitsAndGroups()
    
    veafSkynet.logTrace(string.format("findUnitsAndGroups - listing existing units"))
    
    local coalitionsUnitsAndGroups = {}
    local groupsIdsDone = {}
    coalitionsUnitsAndGroups[coalition.side.BLUE] = {}
    coalitionsUnitsAndGroups[coalition.side.RED] = {}

    for coa, coaData in pairs(coalitionsUnitsAndGroups) do
        coaData.samGroupNames = {}
        coaData.ewrUnitNames = {}
        local dcsGroups = coalition.getGroups(coa)
        for _, dcsGroup in pairs(dcsGroups) do
            local groupName = dcsGroup:getName()
            veafSkynet.logTrace(string.format("checking group %s", tostring(groupName)))
            for _, dcsUnit in pairs(dcsGroup:getUnits()) do
                local unitName = dcsUnit:getName()
                local unitType = dcsUnit:getDesc()["typeName"]
                veafSkynet.logTrace(string.format("checking unit %s of type %s", tostring(unitName), tostring(unitType)))

                -- check if the unitType is supported by Skynet IADS
                if veafSkynet.iadsSamUnitsTypes[unitType] then
                    veafSkynet.logTrace(string.format("-> supported SAM type"))
                    if not(groupsIdsDone[groupName]) then
                        groupsIdsDone[groupName] = true
                        table.insert(coaData.samGroupNames, groupName)
                        veafSkynet.logTrace(string.format("-> added to SAM groups list"))
                    end
                end
                if veafSkynet.iadsEwrUnitsTypes[unitType] then
                    veafSkynet.logTrace(string.format("-> supported EWR type, added to EWR units list"))
                    table.insert(coaData.ewrUnitNames, unitName)
                end
            end
        end
    end
    veafSkynet.logTrace(string.format("coalitionsUnitsAndGroups = %s", veaf.p(coalitionsUnitsAndGroups)))
    return coalitionsUnitsAndGroups
end

local function initializeIADS(iads, coa, actAsEwr, inRadio, debug)
    veafSkynet.logDebug(string.format("initializeIADS %s",tostring(iads:getCoalitionString())))

    if debug then
        veafSkynet.logDebug("adding debug information")
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

    local groupsIdsDone = {}
    local dcsGroups = coalition.getGroups(coa)
    for _, dcsGroup in pairs(dcsGroups) do
        local groupName = dcsGroup:getName()
        veafSkynet.logTrace(string.format("checking group %s", tostring(groupName)))
        for _, dcsUnit in pairs(dcsGroup:getUnits()) do
            local unitName = dcsUnit:getName()
            local unitType = dcsUnit:getDesc()["typeName"]
            veafSkynet.logTrace(string.format("checking unit %s of type %s", tostring(unitName), tostring(unitType)))

            -- check if the unitType is supported by Skynet IADS
            if veafSkynet.iadsSamUnitsTypes[unitType] then
                veafSkynet.logTrace(string.format("-> supported SAM type"))
                if not(groupsIdsDone[groupName]) then
                    veafSkynet.logTrace(string.format("adding a SAM group : %s", groupName))
                    local samsite = iads:addSAMSite(groupName)
                    if samsite then 
                        groupsIdsDone[groupName] = true
                        veafSkynet.logTrace(string.format("adding a SAM -> OK"))
                    end
                end
            end
            if veafSkynet.iadsEwrUnitsTypes[unitType] then
                if not(groupsIdsDone[groupName]) then -- only add EWR for units not belonging to successfully initialized SAM groups
                    veafSkynet.logTrace(string.format("adding an EWR unit : %s", unitName))
                    iads:addEarlyWarningRadar(unitName)
                end        
            end
        end
    end

    -- specific configurations, for each SAM type
    if actAsEwr then
        iads:getSAMSitesByNatoName('SA-10'):setActAsEW(true)
        iads:getSAMSitesByNatoName('SA-6'):setActAsEW(true)
        iads:getSAMSitesByNatoName('Patriot'):setActAsEW(true)
        iads:getSAMSitesByNatoName('Hawk'):setActAsEW(true)
    end

    if inRadio then
        --activate the radio menu to toggle IADS Status output
        iads:addRadioMenu()
    end

    --activate the IADS
    iads:setupSAMSitesAndThenActivate()
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- initialisation
-------------------------------------------------------------------------------------------------------------------------------------------------------------

function veafSkynet.initialize(includeRedInRadio, debugRed, includeBlueInRadio, debugBlue)
    veafSkynet.logInfo(string.format("Initializing module in %s seconds", tostring(veafSkynet.DelayForStartup)))
    mist.scheduleFunction(veafSkynet._initialize,{includeRedInRadio, debugRed, includeBlueInRadio, debugBlue},timer.getTime()+veafSkynet.DelayForStartup)
end

function veafSkynet._initialize(includeRedInRadio, debugRed, includeBlueInRadio, debugBlue)
    local includeRedInRadio = includeRedInRadio or false
    local debugRed = debugRed or false
    local includeBlueInRadio = includeBlueInRadio or false
    local debugBlue = debugBlue or false
    
    veafSkynet.logInfo("Initializing module")
    veafSkynet.logDebug(string.format("includeRedInRadio=%s",veaf.p(includeRedInRadio)))
    veafSkynet.logDebug(string.format("debugRed=%s",veaf.p(debugRed)))
    veafSkynet.logDebug(string.format("includeBlueInRadio=%s",veaf.p(includeBlueInRadio)))
    veafSkynet.logDebug(string.format("debugBlue=%s",veaf.p(debugBlue)))

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
    veafSkynet.logTrace(string.format("veafSkynet.iadsSamUnitsTypes=%s",veaf.p(veafSkynet.iadsSamUnitsTypes)))

    -- add EWR-capable units
    local EWR_attributes = {"EWR", "AWACS" ,"RADAR_BAND1_FOR_ARM", "RADAR_BAND2_FOR_ARM"}
    for _, unit in pairs(dcsUnits.DcsUnitsDatabase) do
        if unit then
            veafSkynet.logTrace(string.format("testing unit %s",veaf.p(unit.type)))
            if unit.attribute then
                veafSkynet.logTrace(string.format("unit.attribute = %s",veaf.p(unit.attribute)))
                if (unit.attribute["SAM SR"]) then
                    veafSkynet.iadsEwrUnitsTypes[unit.type] = true
                    veafSkynet.logTrace(string.format("-> EWR"))
                elseif (unit.attribute["AWACS"]) then
                    veafSkynet.iadsEwrUnitsTypes[unit.type] = true
                    veafSkynet.logTrace(string.format("-> EWR"))
                elseif (unit.attribute["Ships"] and (unit.attribute["RADAR_BAND1_FOR_ARM"] or unit.attribute["RADAR_BAND2_FOR_ARM"])) then
                    veafSkynet.iadsEwrUnitsTypes[unit.type] = true
                    veafSkynet.logTrace(string.format("-> EWR"))
                end
            end
        end
    end
    veafSkynet.logTrace(string.format("veafSkynet.iadsEwrUnitsTypes=%s",veaf.p(veafSkynet.iadsEwrUnitsTypes)))

    -- list all the units and groups in the coalitions
    local coalitionsUnitsAndGroups = findUnitsAndGroups()

    -- create the IADS networks
    veafSkynet.redIADS = SkynetIADS:create("RED IADS")
    veafSkynet.blueIADS = SkynetIADS:create("BLUE IADS")

    initializeIADS(veafSkynet.redIADS, coalition.side.RED, true, includeRedInRadio, debugRed)
    initializeIADS(veafSkynet.blueIADS, coalition.side.BLUE, true, includeBlueInRadio, debugBlue)
end

veafSkynet.logInfo(string.format("Loading version %s", veafSkynet.Version))
