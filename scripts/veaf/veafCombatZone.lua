-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- VEAF combat zone functions for DCS World
-- By zip (2019-20)
--
-- Features:
-- ---------
-- * Zones can be defined in the mission editor that are then managed by this script.
-- * For each zone, a specific radio sub-menu is created, allowing common actions on all specific zone (get coordinates, enemy presence, weather, pop smoke and flares, read a briefing, stop and start dynamic activity on the zone, etc.)
-- * Works with all current and future maps (Caucasus, NTTR, Normandy, PG, ...)
--
-- Prerequisite:
-- ------------
-- * This script requires DCS 2.5.1 or higher and MIST 4.3.74 or higher.
-- * It also requires the base veaf.lua script library (version 1.0 or higher)
-- TODO
--
-- Load the script:
-- ----------------
-- 1.) Download the script and save it anywhere on your hard drive.
-- 2.) Open your mission in the mission editor.
-- 3.) Add a new trigger:
--     * TYPE   "4 MISSION START"
--     * ACTION "DO SCRIPT FILE"
--     * OPEN --> Browse to the location of MIST and click OK.
--     * ACTION "DO SCRIPT FILE"
--     * OPEN --> Browse to the location of veaf.lua and click OK.
-- TODO
--     * ACTION "DO SCRIPT FILE"
--     * OPEN --> Browse to the location of this script and click OK.
--     * ACTION "DO SCRIPT"
--     * set the script command to "veafCombatZone.initialize()" and click OK.
-- 4.) Save the mission and start it.
-- 5.) Have fun :)
--
-- Basic Usage:
-- ------------
-- TODO
--
-------------------------------------------------------------------------------------------------------------------------------------------------------------

veafCombatZone = {}

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Global settings. Stores the script constants
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Identifier. All output in DCS.log will start with this.
veafCombatZone.Id = "COMBAT ZONE - "

--- Version.
veafCombatZone.Version = "0.0.3"

--- Number of seconds between each check of the zone watchdog function
veafCombatZone.SecondsBetweenWatchdogChecks = 15

--- Number of seconds between each smoke request on the zones
veafCombatZone.SecondsBetweenSmokeRequests = 180

--- Number of seconds between each flare request on the zones
veafCombatZone.SecondsBetweenFlareRequests = 120

veafCombatZone.RadioMenuName = "COMBAT ZONES (" .. veafCombatZone.Version .. ")"

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Do not change anything below unless you know what you are doing!
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Radio menus paths
veafCombatZone.rootPath = nil

-- Zones list (table of Zone objects)
veafCombatZone.zonesList = {}

-- Zones dictionary (map of Zone objects by zone name)
veafCombatZone.zonesDict = {}

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Utility methods
-------------------------------------------------------------------------------------------------------------------------------------------------------------

function veafCombatZone.logError(message)
    veaf.logError(veafCombatZone.Id .. message)
end

function veafCombatZone.logInfo(message)
    veaf.logInfo(veafCombatZone.Id .. message)
end

function veafCombatZone.logDebug(message)
    veaf.logDebug(veafCombatZone.Id .. message)
end

function veafCombatZone.logTrace(message)
    veaf.logTrace(veafCombatZone.Id .. message)
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Zone object
-------------------------------------------------------------------------------------------------------------------------------------------------------------

Zone = 
{
    -- zone name (human-friendly)
    friendlyName = nil,
    -- technical zone name (in the mission editor)
    missionEditorZoneName = nil,
    -- technical zone object
    missionEditorZoneObject = nil,
    -- list of defined objectives
    objectives = {},
    -- list of the units defined in the zone
    units = {},
    -- list of the groups defined in the zone
    groupNames = {},
    -- the zone center
    zoneCenter = nil,
    -- zone is active
    active = false,

    --- Radio menus paths
    radioMarkersPath = nil,
    radioTargetInfoPath = nil,
    radioRootPath = nil,

    -- the watchdog function checks for zone objectives completion
    watchdogFunctionId = nil,
    -- "pop smoke" command reset function id
    smokeResetFunctionId = nil,
    -- "pop flare" command reset function id
    flareResetFunctionId = nil
}

function Zone:new (o)
    o = o or {}   -- create object if user does not provide one
    setmetatable(o, self)
    self.__index = self
    return o
end

---
--- setters and getters
---
function Zone:getRadioMenuName()
    return self:getFriendlyName()
end

function Zone:setFriendlyName(value)
    self.friendlyName = value
    return self
end

function Zone:getFriendlyName()
    return self.friendlyName
end

function Zone:setMissionEditorZoneName(value)
    self.missionEditorZoneName = value
    return self
end

function Zone:getMissionEditorZoneName()
    return self.missionEditorZoneName
end

function Zone:isActive()
    return self.active
end

function Zone:setActive(value)
    self.active = value
    return self
end
---
--- other methods
---

function Zone:addObjective(value)
    table.insert(self.objectives, value)
    return self
end

function Zone:addDefaultObjectives()
    -- TODO
    return self
end

function Zone:initialize()
    -- check parameters
    if not self.missionEditorZoneName then 
        return self 
    end
    veafCombatZone.logTrace(string.format("initializing zone [%s]",self.missionEditorZoneName))
    if not self.friendlyName then 
        self:setFriendlyName(self.missionEditorZoneName)
    end
    if #self.objectives == 0 then
        self:addDefaultObjectives()
    end

    -- find the trigger zone center
    self.zoneCenter = mist.utils.zoneToVec3(self.missionEditorZoneName)
    if not self.zoneCenter then 
        local message = string.format("Trigger zone [%s] does not exist in the mission !",self.missionEditorZoneName)
        veafCombatZone.logError(message)
        trigger.action.outText(message,5)
        return self
    end
    veafCombatZone.logTrace(string.format("zone center = [%s]",veaf.vecToString(self.zoneCenter)))
    self.missionEditorZoneObject = trigger.misc.getZone(self.missionEditorZoneName)

    -- find units in the trigger zone
    self.units, self.groupNames = unpack(veaf.findUnitsInTriggerZone(self.missionEditorZoneObject))

    -- deactivate the zone for starters
    veafCombatZone.logTrace("desactivate the zone")
    self:desactivate()

    -- create the radio menu
    self:updateRadioMenu()

    return self
end

function Zone:getInformation()
    -- TODO
    return "info on " .. self.friendlyName
end

-- activate the zone
function Zone:activate()
    self:setActive(true)
    
    -- respawn all logged units
    for _, groupName in pairs(self.groupNames) do
        veafCombatZone.logTrace(string.format("respawning group [%s]",groupName))
        mist.respawnGroup(groupName)
    end

    -- refresh the radio menu
    self:updateRadioMenu()

    return self
end

-- desactivate the zone
function Zone:desactivate()
    self:setActive(false)

    -- find units in the trigger zone (including units not listed in the zone object, as new units may have been spawned in the zone and we want it CLEAN !)
    local units, groupNames = unpack(veaf.findUnitsInTriggerZone(self.missionEditorZoneObject))
    for _, groupName in pairs(groupNames) do

        veafCombatZone.logTrace(string.format("destroying group [%s]",groupName))
        local group = Group.getByName(groupName)
        if not group then 
            veafCombatZone.logTrace(string.format("StaticObject.getByName([%s])",groupName))
            group = StaticObject.getByName(groupName)
        end
        if group then
            veafCombatZone.logTrace(string.format("group[%s]:destroy()",groupName))
            group:destroy()
        end
    end 
       
    -- refresh the radio menu
    self:updateRadioMenu()

    return self
end

-- updates the radio menu according to the zone state
function Zone:updateRadioMenu(inBatch)
    veafCombatZone.logDebug(string.format("updateRadioMenu(%s)",self.missionEditorZoneName or ""))
    
    -- do not update the radio menu if not yet initialized
    if not veafCombatZone.rootPath then
        return self
    end

    -- reset the radio menu
    veafCombatZone.logTrace("reset the radio menu")
    veafRadio.delSubmenu(self.radioRootPath, veafCombatZone.rootPath)
    self.radioRootPath = veafRadio.addSubMenu(self:getRadioMenuName(), veafCombatZone.rootPath)

    -- populate the radio menu
    veafCombatZone.logTrace("populate the radio menu")
    -- global commands
    veafRadio.addCommandToSubmenu("Get info", self.radioRootPath, veafCombatZone.GetInformationOnZone, self.missionEditorZoneName, veafRadio.USAGE_ForGroup)
    if self:isActive() then
        -- zone is active, set up accordingly (desactivate zone, get information, pop smoke, etc.)
        veafCombatZone.logTrace("zone is active")
        veafRadio.addSecuredCommandToSubmenu('Desactivate zone', self.radioRootPath, veafCombatZone.DesactivateZone, self.missionEditorZoneName, veafRadio.USAGE_ForAll)
        -- TODO
    else
        -- zone is not active, set up accordingly (activate zone)
        veafCombatZone.logTrace("zone is not active")
        veafRadio.addSecuredCommandToSubmenu('Activate zone', self.radioRootPath, veafCombatZone.ActivateZone, self.missionEditorZoneName, veafRadio.USAGE_ForAll)
    end

    if not inBatch then veafRadio.refreshRadioMenu() end
    return self
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- global functions
-------------------------------------------------------------------------------------------------------------------------------------------------------------

function veafCombatZone.GetZone(zoneName)
    veafCombatZone.logInfo(string.format("Searching for zone with name [%s]", zoneName))
    local zone = veafCombatZone.zonesDict[zoneName]
    if not zone then 
        local message = string.format("Zone [%s] was not found !",self.missionEditorZoneName)
        veafCombatZone.logError(message)
        trigger.action.outText(message,5)
    end
    return zone
end

-- add a zone
function veafCombatZone.AddZone(zone)
    veafCombatZone.logInfo(string.format("Adding zone [%s]", zone.missionEditorZoneName))
    zone:initialize()
    table.insert(veafCombatZone.zonesList, zone)
    veafCombatZone.zonesDict[zone.missionEditorZoneName] = zone
end

-- activate a zone
function veafCombatZone.ActivateZone(zoneName)
    local zone = veafCombatZone.GetZone(zoneName)
    zone:activate()
end

-- desactivate a zone
function veafCombatZone.DesactivateZone(zoneName)
    local zone = veafCombatZone.GetZone(zoneName)
    zone:desactivate()
end

-- print information about a zone
function veafCombatZone.GetInformationOnZone(parameters)
    local zoneName, unitName = unpack(parameters)
    local zone = veafCombatZone.GetZone(zoneName)
    local text = zone:getInformation()
    veaf.outTextForUnit(unitName, text, 30)
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Radio menu and help
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Build the initial radio menu
function veafCombatZone.buildRadioMenu()
    veafCombatZone.logDebug("buildRadioMenu()")
    veafCombatZone.rootPath = veafRadio.addSubMenu(veafCombatZone.RadioMenuName)
    veafRadio.addCommandToSubmenu("HELP", veafCombatZone.rootPath, veafCombatZone.help, nil, veafRadio.USAGE_ForGroup)
    for _, zone in pairs(veafCombatZone.zonesList) do
        zone:updateRadioMenu(true)
    end
    veafRadio.refreshRadioMenu()
end

function veafCombatZone.help(unitName)
    local text =
        'Combat zones are defined by the mission maker, and listed here\n' ..
        'You can activate and desactivate them at will,\n' ..
        'as well as ask for information, JTAC laser and smoke.'

    veaf.outTextForUnit(unitName, text, 30)
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- initialisation
-------------------------------------------------------------------------------------------------------------------------------------------------------------
function veafCombatZone.initialize()
    veafCombatZone.logInfo("Initializing module")
    veafCombatZone.buildRadioMenu()
end

veafCombatZone.logInfo(string.format("Loading version %s", veafCombatZone.Version))
