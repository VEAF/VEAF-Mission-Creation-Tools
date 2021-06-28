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
veafHoundElint.Id = "HOUND - "

--- Version.
veafHoundElint.Version = "1.0.0"

-- trace level, specific to this module
veafHoundElint.Debug = false
veafHoundElint.Trace = false

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

function veafHoundElint.logError(message)
    veaf.logError(veafHoundElint.Id .. message)
end

function veafHoundElint.logInfo(message)
    veaf.logInfo(veafHoundElint.Id .. message)
end

function veafHoundElint.logDebug(message)
    if message and veafHoundElint.Debug then 
        veaf.logDebug(veafHoundElint.Id .. message)
    end
end

function veafHoundElint.logTrace(message)
    if message and veafHoundElint.Trace then 
        veaf.logTrace(veafHoundElint.Id .. message)
    end
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- HoundElint addon functions
-------------------------------------------------------------------------------------------------------------------------------------------------------------

function HoundElint:removeRadioMenu()
    missionCommands.removeItem(self.radioMenu)
end

function HoundElint:new(coalition)
    local _hound = HoundElint:create()
    if _hound then
        _hound.coalitionId = coalition
    end
    return _hound
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- core functions
-------------------------------------------------------------------------------------------------------------------------------------------------------------

function veafHoundElint.getHoundOfCoalition(coa)
    --veafHoundElint.logTrace(string.format("getHoundOfCoalition(%s)", veaf.p(coa)))
    local hound = nil
    if coa == coalition.side.RED then
        hound = veafHoundElint.redHound
    elseif coa == coalition.side.BLUE then
        hound = veafHoundElint.blueHound
    end
    return hound
end


function veafHoundElint.addPlatformToSystem(dcsGroup, alreadyAddedUnits, atMissionStart)
    local groupName = dcsGroup:getName()
    local coa = dcsGroup:getCoalition()
    local hound = veafHoundElint.getHoundOfCoalition(coa)
    veafHoundElint.logDebug(string.format("addPlatformToSystem(%s) to %s", veaf.p(groupName), veaf.p(veaf.ifnn(hound,"name"))))
    if not veafHoundElint.initialized then 
        return false 
    end
    veafHoundElint.logTrace(string.format("atMissionStart=%s", veaf.p(atMissionStart)))

    
    local batchMode = (alreadyAddedUnits ~= nil)
    local alreadyAddedUnits = alreadyAddedUnits or {}
    if not(hound) then
        veafHoundElint.logError(string.format("no Hound system for the coalition of %s", veaf.p(groupName)))
        return false
    end
    local didSomething = false
    --veafHoundElint.logTrace(string.format("batchMode = %s", veaf.p(batchMode)))
    veafHoundElint.logTrace(string.format("dcsGroup=%s", veaf.p(mist.utils.deepCopy(dcsGroup))))
    for _, dcsUnit in pairs(dcsGroup:getUnits()) do
        veafHoundElint.logTrace(string.format("dcsUnit.getName=%s", veaf.p(veaf.ifnn(dcsUnit, "getName"))))
        veafHoundElint.logTrace(string.format("dcsUnit:isActive()=%s", veaf.p(dcsUnit:isActive())))
        if not(atMissionStart) or dcsUnit:isActive() then
            local unitName = dcsUnit:getName()
            local unitType = dcsUnit:getDesc()["typeName"]
            veafHoundElint.logTrace(string.format("checking unit %s of type %s", veaf.p(unitName), veaf.p(unitType)))

            -- check if the unitType is supported by Hound Elint
            if veafHoundElint.elintUnitsTypes[unitType] then
                veafHoundElint.logTrace(string.format("-> supported elint type"))
                -- check the unit name vs the prefix
                if veafHoundElint.prefix then 
                    local _p1, _p2 = unitName:lower():find(veafHoundElint.prefix:lower())
                    veafHoundElint.logTrace(string.format("_p1=%s", veaf.p(_p1)))
                    veafHoundElint.logTrace(string.format("_p2=%s", veaf.p(_p2)))
                    if _p2 and _p1 == 1 then
                        -- found the prefix at the beginning of the name
                        if not(alreadyAddedUnits[unitName]) then
                            veafHoundElint.logTrace(string.format("adding a platform : %s", unitName))
                            local platform = hound:addPlatform(unitName) -- no actual return value
                            -- todo check if ok when HoundElint will give us a return value
                            if true then 
                                didSomething = true
                                alreadyAddedUnits[unitName] = true
                                veafHoundElint.logTrace(string.format("adding a platform -> OK"))
                            end
                        end
                    end
                end
            end
        end
    end

    if didSomething and not(batchMode) then
        veafHoundElint.logTrace(string.format("reactivating the Elint system"))

        -- reactivate the system
        hound:systemOn()
    end

    return didSomething
end

local function initializeHoundSystem(coa, parameters, atMissionStart)
    local hound = veafHoundElint.getHoundOfCoalition(coa)
    veafHoundElint.logDebug(string.format("initializeHoundSystem %s",tostring(hound.name)))
    veafHoundElint.logDebug(string.format("atMissionStart=%s",veaf.p(atMissionStart)))

    local alreadyAddedUnits = {}
    local dcsGroups = coalition.getGroups(coa)
    for _, dcsGroup in pairs(dcsGroups) do
        veafHoundElint.addPlatformToSystem(dcsGroup, alreadyAddedUnits, atMissionStart)
    end

    if veafHoundElint.hasMarkers(parameters) then
        hound:enableMarkers()
    end

    if veafHoundElint.hasAtis(parameters) then
        hound:enableATIS()
        if type(parameters.atis) == "table" then
            hound:configureAtis(parameters.atis)
        end
    end

    if veafHoundElint.hasAdmin(parameters) then
        --activate the radio menu to administrate the Hound system
        hound:addAdminRadioMenu()
    end

    if veafHoundElint.hasController(parameters) then
        local textMode = not(veafHoundElint.hasControllerVoice(parameters))
        hound:enableController(textMode)
        if type(parameters.controller) == "table" then
            hound:configureController(parameters.controller)
        end
    end

    --activate the Hound system
    hound:systemOn()
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- initialisation
-------------------------------------------------------------------------------------------------------------------------------------------------------------

local function createSystems(loadUnits, atMissionStart)
    veafHoundElint.logDebug(string.format("createSystems(%s, %s)", veaf.p(loadUnits), veaf.p(atMissionStart)))

    veafHoundElint.redHound = HoundElint:new(coalition.side.RED)
    veafHoundElint.redHound.name = "RED Hound"
    veafHoundElint.blueHound = HoundElint:new(coalition.side.BLUE)
    veafHoundElint.blueHound.name = "BLUE Hound"
    if loadUnits then
        initializeHoundSystem(coalition.side.RED, veafHoundElint.redParameters, atMissionStart)
        initializeHoundSystem(coalition.side.BLUE, veafHoundElint.blueParameters, atMissionStart)
    end
end

-- reset the IADS networks and rebuild them. Useful when a dynamic combat zone is deactivated
function veafHoundElint.reinitialize(delay)
    veafHoundElint.logDebug(string.format("reinitialize(%s)", veaf.p(delay)))
    if not veafHoundElint.reinitializeTaskID then
        if delay then
            veafHoundElint.reinitializeTaskID = mist.scheduleFunction(veafHoundElint._reinitialize , nil, veafHoundElint.DelayForStartup)
        end
    end
end

function veafHoundElint._reinitialize()
    veafHoundElint.logDebug(string.format("_reinitialize()"))

    if not veafHoundElint.initialized then 
        return false 
    end

    if veafHoundElint.redHound then
        if veafHoundElint.hasAdmin(veafHoundElint.redParameters) then 
            veafHoundElint.redHound:removeAdminRadioMenu()
        end
        veafHoundElint.redHound:systemOff()
    end
    if veafHoundElint.blueHound then
        if veafHoundElint.hasAdmin(veafHoundElint.blueParameters) then 
            veafHoundElint.blueHound:removeAdminRadioMenu()
        end
        veafHoundElint.blueHound:systemOff()
    end
    createSystems(true, false)

    if veafHoundElint.reinitializeTaskID then
        veafHoundElint.reinitializeTaskID = nil
    end
end

function veafHoundElint.hasAdmin(parameters)
    return parameters and parameters.admin
end

function veafHoundElint.hasMarkers(parameters)
    return parameters and parameters.markers
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

function veafHoundElint.initialize(prefix, red, blue)
    veafHoundElint.prefix = prefix -- if nil, all capable units will be set as Elint platforms
    veafHoundElint.redParameters = red or {}
    veafHoundElint.blueParameters = blue or {}
    
    veafHoundElint.logInfo("Initializing module")
    
    veafHoundElint.logDebug(string.format("red=%s",veaf.p(red)))
    veafHoundElint.logDebug(string.format("blue=%s",veaf.p(blue)))
    
    -- prepare the list of units supported by Hound Elint
    for platformType, platformData in pairs(HoundDB.Platform[Object.Category.STATIC]) do
        veafHoundElint.elintUnitsTypes[platformType] = true
    end
    for platformType, platformData in pairs(HoundDB.Platform[Object.Category.UNIT]) do
        veafHoundElint.elintUnitsTypes[platformType] = true
    end
    veafHoundElint.logTrace(string.format("veafHoundElint.elintUnitsTypes=%s",veaf.p(veafHoundElint.elintUnitsTypes)))
    veafHoundElint.initialized = true

    veafHoundElint.logInfo(string.format("Loading units"))
    createSystems(true, true)

    veafHoundElint.logInfo(string.format("Hound Elint has been initialized"))
end

veafHoundElint.logInfo(string.format("Loading version %s", veafHoundElint.Version))
