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
veafCombatZone.Version = "0.0.1"

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
veafCombatZone.zones = {}

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Utility methods
-------------------------------------------------------------------------------------------------------------------------------------------------------------

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
    -- list of defined objectives
    objectives = {},
    -- list of the units defined in the zone
    units = {},
    -- the zone center
    zoneCenter = nil,
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

function Zone:setFriendlyName(value)
    self.friendlyName = value
    return self
end

function Zone:setMissionEditorZoneName(value)
    self.missionEditorZoneName = value
    return self
end

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
        local message = "Trigger zone ["..self.missionEditorZoneName.."] does not exist !"
        veafCombatZone.logInfo(message)
        trigger.action.outText(message,5)
        return self
    end
    veafCombatZone.logTrace(string.format("zone center = [%s]",veaf.vecToString(self.zoneCenter)))

    -- find units in the trigger zone
    self.units = mist.getUnitsInZones(mist.makeUnitTable({'[all]'}), {self.missionEditorZoneName})
    veafCombatZone.logTrace(string.format("found %d units in zone", #self.units))

    return self
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- add a zone
-------------------------------------------------------------------------------------------------------------------------------------------------------------
function veafCombatZone.addZone(zone)
    veafCombatZone.logInfo(string.format("Adding zone [%s]", zone.missionEditorZoneName))
    zone:initialize()
    table.insert(veafCombatZone.zones, zone)
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- initialisation
-------------------------------------------------------------------------------------------------------------------------------------------------------------
function veafCombatZone.initialize()
    --veafCombatZone.buildRadioMenu()
end

veafCombatZone.logInfo(string.format("Loading version %s", veafCombatZone.Version))
