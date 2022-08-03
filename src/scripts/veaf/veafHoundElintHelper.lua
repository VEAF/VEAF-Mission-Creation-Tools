-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- VEAF helper for Hound-Elint
-- By zip (2021)
--
-- Features:
-- ---------
-- * This module offers support for integrating Hound-Elint in a mission
--
-- Prerequisite:
-- ------------
-- * This script requires DCS 2.5.1 or higher and MIST 4.3.74 or higher.
-- * It also requires Hound-Elint !
-- * It also requires all the veaf scripts !
--
-- Basic Usage:
-- ------------
-- TODO
--
-------------------------------------------------------------------------------------------------------------------------------------------------------------

veafHoundElint = {}

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Global settings. Stores the script constants
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Identifier. All output in DCS.log will start with this.
veafHoundElint.Id = "HOUND"

--- Version.
veafHoundElint.Version = "1.1.0"

-- trace level, specific to this module
--veafHoundElint.LogLevel = "trace"

veaf.loggers.new(veafHoundElint.Id, veafHoundElint.LogLevel)

-- delay before the mission groups are added to the Hound system at start
veafHoundElint.DelayForStartup = 1

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Do not change anything below unless you know what you are doing!
-------------------------------------------------------------------------------------------------------------------------------------------------------------

veafHoundElint.initialized = false
veafHoundElint.prefix = nil
veafHoundElint.redParameters = {}
veafHoundElint.blueParameters = {}
veafHoundElint.redHound = nil
veafHoundElint.blueHound = nil
veafHoundElint.elintUnitsTypes = {}

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Utility methods
-------------------------------------------------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- core functions
-------------------------------------------------------------------------------------------------------------------------------------------------------------

function veafHoundElint.getHoundOfCoalition(coa)
    --veaf.loggers.get(veafHoundElint.Id):trace(string.format("getHoundOfCoalition(%s)", veaf.p(coa)))
    local hound = nil
    if coa == coalition.side.RED then
        hound = veafHoundElint.redHound
    elseif coa == coalition.side.BLUE then
        hound = veafHoundElint.blueHound
    end
    return hound
end


function veafHoundElint.addPlatformToSystem(dcsGroup, alreadyAddedUnits, atMissionStart)
    
    if not dcsGroup then
        veaf.loggers.get(veafHoundElint.Id):debug("group cannot exist")
        return false
    end
    
    local groupName = dcsGroup:getName()
    local coa = dcsGroup:getCoalition()
    local hound = veafHoundElint.getHoundOfCoalition(coa)
    veaf.loggers.get(veafHoundElint.Id):debug(string.format("addPlatformToSystem(%s) to %s", veaf.p(groupName), veaf.p(veaf.ifnn(hound,"name"))))
    if not veafHoundElint.initialized then 
        return false 
    end
    veaf.loggers.get(veafHoundElint.Id):trace(string.format("atMissionStart=%s", veaf.p(atMissionStart)))

    
    local batchMode = (alreadyAddedUnits ~= nil)
    local alreadyAddedUnits = alreadyAddedUnits or {}
    if not(hound) then
        veaf.loggers.get(veafHoundElint.Id):error(string.format("no Hound system for the coalition of %s", veaf.p(groupName)))
        return false
    end

    local didSomething = false

    local _addUnitToSystem = function(dcsUnit, isFunctional) 
        if not(atMissionStart) or isFunctional then
            local unitName = dcsUnit:getName()
            local unitType = dcsUnit:getDesc()["typeName"]
            veaf.loggers.get(veafHoundElint.Id):trace(string.format("checking unit %s of type %s", veaf.p(unitName), veaf.p(unitType)))

            -- check if the unitType is supported by Hound Elint
            if veafHoundElint.elintUnitsTypes[unitType] then
                veaf.loggers.get(veafHoundElint.Id):trace(string.format("-> supported elint type"))
                -- check the unit name vs the prefix
                if veafHoundElint.prefix then 
                    local _p1, _p2 = unitName:lower():find(veafHoundElint.prefix:lower())
                    veaf.loggers.get(veafHoundElint.Id):trace(string.format("_p1=%s", veaf.p(_p1)))
                    veaf.loggers.get(veafHoundElint.Id):trace(string.format("_p2=%s", veaf.p(_p2)))
                    if _p2 and _p1 == 1 then
                        -- found the prefix at the beginning of the name
                        if not(alreadyAddedUnits[unitName]) then
                            veaf.loggers.get(veafHoundElint.Id):trace(string.format("adding a platform : %s", unitName))
                            local added = hound:addPlatform(unitName) -- no actual return value
                            -- todo check if ok when HoundElint will give us a return value
                            if added then 
                                didSomething = true
                                alreadyAddedUnits[unitName] = true
                                veaf.loggers.get(veafHoundElint.Id):trace(string.format("adding a platform -> OK"))
                            end
                        end
                    end
                end
            end
        end
    end

    --veaf.loggers.get(veafHoundElint.Id):trace(string.format("batchMode = %s", veaf.p(batchMode)))
    veaf.loggers.get(veafHoundElint.Id):trace(string.format("dcsGroup=%s", veaf.p(mist.utils.deepCopy(dcsGroup))))

    if Group.getByName(groupName) then
        for _, dcsUnit in pairs(dcsGroup:getUnits()) do
            veaf.loggers.get(veafHoundElint.Id):trace(string.format("dcsUnit.getName=%s", veaf.p(veaf.ifnn(dcsUnit, "getName"))))
            veaf.loggers.get(veafHoundElint.Id):trace(string.format("dcsUnit:isActive()=%s", veaf.p(dcsUnit:isActive())))
            _addUnitToSystem(dcsUnit, dcsUnit:isActive())
        end
    elseif StaticObject.getByName(groupName) then
        veaf.loggers.get(veafHoundElint.Id):trace("Group is Static")
        veaf.loggers.get(veafHoundElint.Id):trace(string.format("dcsGroup:isExist()=%s", veaf.p(dcsGroup:isExist())))
        _addUnitToSystem(dcsGroup, dcsGroup:isExist())
    end

    if didSomething and not(batchMode) then
        veaf.loggers.get(veafHoundElint.Id):trace(string.format("reactivating the Elint system"))

        -- reactivate the system
        hound:systemOn()
    end

    return didSomething
end

local function initializeHoundSystem(coa, parameters, atMissionStart)
    local hound = veafHoundElint.getHoundOfCoalition(coa)
    veaf.loggers.get(veafHoundElint.Id):debug(string.format("initializeHoundSystem %s",tostring(hound.name)))
    veaf.loggers.get(veafHoundElint.Id):debug(string.format("atMissionStart=%s",veaf.p(atMissionStart)))

    local alreadyAddedUnits = {}
    local dcsGroups = coalition.getGroups(coa)
    for _, dcsGroup in pairs(dcsGroups) do
        veafHoundElint.addPlatformToSystem(dcsGroup, alreadyAddedUnits, atMissionStart)
    end

    if parameters then
        if parameters.markers then
            hound:enableMarkers(HOUND.MARKER.DIAMOND)
        end

        if parameters.platformPositionErrors then
            hound:enablePlatformPosErrors()
        end

        if parameters.disableBDA then
            hound:disableBDA()
        end

        if parameters.NATO_SectorCallsigns then
            hound:useNATOCallsignes(true)
        end

        if parameters.NATOmessages then
            hound:enableNATO()
        end

        if parameters.ATISinterval and type(parameters.ATISinterval) == 'number' and parameters.ATISinterval > 0 then 
            hound:setAtisUpdateInterval(parameters.ATISinterval) 
        end

        if parameters.preBriefedContacts then
            for name,_ in pairs(parameters.preBriefedContacts) do
                if name and type(name) == 'string' and Group.getByName(name) then
                    hound:preBriefedContact(name)
                end
            end
        end

        if parameters.debug then
            hound:onScreenDebug(true)
        end
    end

    for SectorName, sectorParameters in pairs(parameters.sectors) do
        
        local SectorName = SectorName or "default"
        if SectorName ~= "default" and tostring(SectorName) then
            SectorName = tostring(SectorName)
            local sector = hound:addSector(SectorName)
            if sector then 
                hound:setZone(SectorName) --no actual return value, this may well fail without telling us so meaning and atis and the lot will be put in place for a sector that's not geoconstrained
            else
                SectorName = "default"
            end
        else
            SectorName = "default"
        end

        if veafHoundElint.hasSectorCallsign(sectorParameters) then
            if sectorParameters.callsign == true then
                sectorParameters.callsign = SectorName
            end
            hound:setCallsign(SectorName, tostring(sectorParameters.callsign))
        end

        if veafHoundElint.hasTransmitterUnit(sectorParameters) then
            hound:setTransmitter(SectorName, sectorParameters.transmitterUnit)
        end

        if veafHoundElint.hasAtis(sectorParameters) then
            hound:enableAtis(SectorName, sectorParameters.atis)
            if sectorParameters.atis.reportEWR then hound:reportEWR(SectorName, sectorParameters.atis.reportEWR) end
        end

        if veafHoundElint.hasController(sectorParameters) then
            hound:enableController(SectorName, sectorParameters.controller)
            local textMode = not(veafHoundElint.hasControllerVoice(sectorParameters))
            if textMode then 
                hound:enableText(SectorName)
            end
        end

        if veafHoundElint.hasNotifier(sectorParameters) then
            hound:enableNotifier(SectorName, sectorParameters.notifier)
        end

        if veafHoundElint.hasNoAlerts(sectorParameters) then
            hound:disableAlerts(SectorName)
        end

        if veafHoundElint.hasNoTTS(sectorParameters) then
            hound:disableTTS(SectorName)
        end
    end

    --activate the Hound system
    hound:systemOn()
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- initialisation
-------------------------------------------------------------------------------------------------------------------------------------------------------------

local function createSystems(loadUnits, atMissionStart)
    veaf.loggers.get(veafHoundElint.Id):debug(string.format("createSystems(%s, %s)", veaf.p(loadUnits), veaf.p(atMissionStart)))

    veafHoundElint.redHound = HoundElint:create(coalition.side.RED)
    veafHoundElint.redHound.name = "RED Hound"
    veafHoundElint.blueHound = HoundElint:create(coalition.side.BLUE)
    veafHoundElint.blueHound.name = "BLUE Hound"
    if loadUnits then
        initializeHoundSystem(coalition.side.RED, veafHoundElint.redParameters, atMissionStart)
        initializeHoundSystem(coalition.side.BLUE, veafHoundElint.blueParameters, atMissionStart)
    end
end

-- reset the Hound networks and rebuild them. Useful when a dynamic combat zone is deactivated
function veafHoundElint.reinitialize(delay)
    veaf.loggers.get(veafHoundElint.Id):debug(string.format("reinitialize(%s)", veaf.p(delay)))
    if not veafHoundElint.reinitializeTaskID then
        if delay then
            veafHoundElint.reinitializeTaskID = mist.scheduleFunction(veafHoundElint._reinitialize , nil, veafHoundElint.DelayForStartup)
        end
    end
end

function veafHoundElint._reinitialize()
    veaf.loggers.get(veafHoundElint.Id):debug(string.format("_reinitialize()"))

    if not veafHoundElint.initialized then 
        return false 
    end

    if veafHoundElint.redHound then
        veafHoundElint.redHound:systemOff()
    end
    if veafHoundElint.blueHound then
        veafHoundElint.blueHound:systemOff()
    end
    createSystems(true, false)

    if veafHoundElint.reinitializeTaskID then
        veafHoundElint.reinitializeTaskID = nil
    end
end

function veafHoundElint.hasSectorCallsign(parameters)
    return parameters.callsign and tostring(parameters.callsign)
end

function veafHoundElint.hasTransmitterUnit(parameters)
    return parameters and parameters.transmitterUnit and type(parameters.transmitterUnit) == "string" and Group.getByName(parameters.transmitterUnit)
end

function veafHoundElint.hasAtis(parameters)
    return parameters and parameters.atis
end

function veafHoundElint.hasController(parameters)
    return parameters and parameters.controller
end

function veafHoundElint.hasControllerVoice(parameters)
    return parameters and parameters.controller and parameters.controller.voiceEnabled
end

function veafHoundElint.hasNotifier(parameters)
    return parameters and parameters.notifier
end

function veafHoundElint.hasNoTTS(parameters)
    return parameters and parameters.disableTTS
end

function veafHoundElint.hasNoAlerts(parameters)
    return parameters and parameters.disableAlerts
end

function veafHoundElint.initialize(prefix, red, blue)
    veafHoundElint.prefix = prefix -- if nil, all capable units will be set as Elint platforms
    veafHoundElint.redParameters = red or {}
    veafHoundElint.blueParameters = blue or {}
    
    veaf.loggers.get(veafHoundElint.Id):info("Initializing module")
    
    veaf.loggers.get(veafHoundElint.Id):debug(string.format("red=%s",veaf.p(red)))
    veaf.loggers.get(veafHoundElint.Id):debug(string.format("blue=%s",veaf.p(blue)))
    
    -- prepare the list of units supported by Hound Elint
    for platformType, platformData in pairs(HOUND.DB.Platform[Object.Category.STATIC]) do
        veafHoundElint.elintUnitsTypes[platformType] = true
    end
    for platformType, platformData in pairs(HOUND.DB.Platform[Object.Category.UNIT]) do
        veafHoundElint.elintUnitsTypes[platformType] = true
    end
    veaf.loggers.get(veafHoundElint.Id):trace(string.format("veafHoundElint.elintUnitsTypes=%s",veaf.p(veafHoundElint.elintUnitsTypes)))
    veafHoundElint.initialized = true

    veaf.loggers.get(veafHoundElint.Id):info(string.format("Loading units"))
    createSystems(true, true)

    veaf.loggers.get(veafHoundElint.Id):info(string.format("Hound Elint has been initialized"))
end

veaf.loggers.get(veafHoundElint.Id):info(string.format("Loading version %s", veafHoundElint.Version))
HOUND.Utils.Marker._MarkId = 1235634 -- select a less obvious marker id range that `9999`