-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- VEAF Sanctuary Zone script
-- By zip (2021)
--
-- Features:
-- ---------
-- * This module offers support for creating sanctuary zones in a mission
-- * A sanctuary zone warns and then destroys all the human aircrafts of other coalitions when they loiter in the zone
--
-- Prerequisite:
-- ------------
-- * This script requires DCS 2.5.1 or higher and MIST 4.3.74 or higher.
-- * It also requires all the veaf scripts !
--
-- Basic Usage:
-- ------------
-- TODO
--
-------------------------------------------------------------------------------------------------------------------------------------------------------------

veafSanctuary = {}

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Global settings. Stores the script constants
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Identifier. All output in DCS.log will start with this.
veafSanctuary.Id = "SANCTUARY - "

--- Version.
veafSanctuary.Version = "1.1.0"

-- trace level, specific to this module
veafSanctuary.Debug = false
veafSanctuary.Trace = false

-- delay before the sanctuary zones start reporting
veafSanctuary.DelayForStartup = 0

-- delay between each check of the sanctuary zones
veafSanctuary.DelayBetweenChecks = 15

-- default delay before warning
veafSanctuary.DEFAULT_DELAY_WARNING = 0

-- default message when entering the zone
veafSanctuary.DEFAULT_MESSAGE_WARNING = "Warning, %s : you've entered a sanctuary zone and will be shot in %d seconds if you don't leave IMMEDIATELY"

-- time to display the messages
veafSanctuary.MESSAGE_TIME = 20

-- default delay before instantly killing the offender
veafSanctuary.DEFAULT_DELAY_INSTANT = -1

-- default delay before spawning defenses
veafSanctuary.DEFAULT_DELAY_SPAWN = -1

-- default message when defenses are spawned
veafSanctuary.DEFAULT_MESSAGE_SPAWN = "You've been warned : deploying defense systems"

-- time to start spawning harder defenses
veafSanctuary.HARDER_DEFENSES_AFTER = 75

-- time to start removing the defenses
veafSanctuary.DELETE_DEFENSES_AFTER = 45

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Do not change anything below unless you know what you are doing!
-------------------------------------------------------------------------------------------------------------------------------------------------------------

veafSanctuary.initialized = false
veafSanctuary.spawnedSAMs  = {}
veafSanctuary.humanUnitsToFollow  = {}
veafSanctuary.zonesList  = {}
veafSanctuary.humanUnits = {}

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Utility methods
-------------------------------------------------------------------------------------------------------------------------------------------------------------

function veafSanctuary.logError(message)
    veaf.logError(veafSanctuary.Id .. message)
end

function veafSanctuary.logInfo(message)
    veaf.logInfo(veafSanctuary.Id .. message)
end

function veafSanctuary.logDebug(message)
    if message and veafSanctuary.Debug then 
        veaf.logDebug(veafSanctuary.Id .. message)
    end
end

function veafSanctuary.logTrace(message)
    if message and veafSanctuary.Trace then 
        veaf.logTrace(veafSanctuary.Id .. message)
    end
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- objects
-------------------------------------------------------------------------------------------------------------------------------------------------------------

VeafSanctuaryZone =
{
    -- name
    name,
    -- coalition that is forbidden to enter the zone
    protectFromCoalition,
    -- position on the map
    position,
    -- if set, the zone is a circle of center *position* and of radius *radius*
    radius,
    radiusSquared,
    -- if set, the zone is a polygon - this is a simple list of points
    polygon,
    -- delay before warning - if -1, no warning
    delayWarning,
    -- warning message
    messageWarning,
    -- delay before instant kill - if -1, no instant kill
    delayInstant,
    -- delay before spawn of defense systems - if -1, no spawn
    delaySpawn,
    -- spawn message
    messageSpawn,
}
VeafSanctuaryZone.__index = VeafSanctuaryZone

function VeafSanctuaryZone:new ()
    local self = setmetatable({}, VeafSanctuaryZone)
    self.name = nil
    self.coalition = nil
    self.position = nil
    self.radius = nil
    self.radiusSquared = nil
    self.polygon = nil
    self.delayWarning = veafSanctuary.DEFAULT_DELAY_WARNING
    self.messageWarning = veafSanctuary.DEFAULT_MESSAGE_WARNING
    self.delayInstant = veafSanctuary.DEFAULT_DELAY_INSTANT
    self.delaySpawn = veafSanctuary.DEFAULT_DELAY_SPAWN
    self.messageSpawn = veafSanctuary.DEFAULT_MESSAGE_SPAWN
    self.spawnedGroups = {}
    return self
end

---
--- setters and getters
---

function VeafSanctuaryZone:setName(value)
    self.name = value
    return self
end

function VeafSanctuaryZone:getName()
    return self.name
end

function VeafSanctuaryZone:setCoalition(value)
    self.coalition = value
    return self
end

function VeafSanctuaryZone:getCoalition()
    return self.coalition
end

function VeafSanctuaryZone:setPosition(value)
    self.position = value
    return self
end

function VeafSanctuaryZone:getPosition()
    return self.position
end

function VeafSanctuaryZone:setRadius(value)
    self.radius = value
    if value ~= nil then
        self.radiusSquared = value * value
    else
        self.radiusSquared = nil
    end
    return self
end

function VeafSanctuaryZone:getRadius()
    return self.radius
end

function VeafSanctuaryZone:setPolygon(value)
    self.polygon = value
    return self
end

function VeafSanctuaryZone:setPolygonFromUnits(unitNames)
    veafSanctuary.logTrace(string.format("VeafSanctuaryZone[%s]:setPolygonFromUnits()", veaf.p(self.name)))
    local polygon = {}
    for _, unitName in pairs(unitNames) do
        veafSanctuary.logTrace(string.format("unitName = %s", veaf.p(unitName)))
        local unit = Unit.getByName(unitName)
        if not unit then
            local group = Group.getByName(unitName)
            if group then
                unit = group:getUnit(1)
            end
        end
        if unit then
            -- get position, place tracing marker and remove the unit
            local position = unit:getPosition().p
            unit:destroy()
            veafSanctuary.logTrace(string.format("position = %s", veaf.p(position)))
            table.insert(polygon, mist.utils.deepCopy(position))
        end
    end
    veafSanctuary.logTrace(string.format("polygon = %s", veaf.p(polygon)))
    return self:setPolygon(polygon)
end

function VeafSanctuaryZone:getPolygon()
    return self.polygon
end

function VeafSanctuaryZone:setDelayWarning(value)
    self.delayWarning = value
    return self
end

function VeafSanctuaryZone:getDelayWarning()
    return self.delayWarning
end

function VeafSanctuaryZone:setMessageWarning(value)
    self.messageWarning = value
    return self
end

function VeafSanctuaryZone:getMessageWarning()
    return self.messageWarning
end

function VeafSanctuaryZone:setDelayInstant(value)
    self.delayInstant = value
    return self
end

function VeafSanctuaryZone:getDelayInstant()
    return self.delayInstant
end

function VeafSanctuaryZone:setDelaySpawn(value)
    self.delaySpawn = value
    return self
end

function VeafSanctuaryZone:getDelaySpawn()
    return self.delaySpawn
end

function VeafSanctuaryZone:setMessageSpawn(value)
    self.messageSpawn = value
    return self
end

function VeafSanctuaryZone:getMessageSpawn()
    return self.messageSpawn
end

function VeafSanctuaryZone:addSpawnedGroups(spawnedGroupsNames)
    for _, groupName in pairs(spawnedGroupsNames) do
        self.spawnedGroups[groupName] = timer.getTime()
    end
    return self
end

function VeafSanctuaryZone:getSpawnedGroups()
    return self.spawnedGroups
end

---
--- business methods
---

function VeafSanctuaryZone:deployDefenses(position, timeInZone)
    veafSanctuary.logTrace(string.format("VeafSanctuaryZone[%s]:deployDefenses()", veaf.p(self.name)))
    if veafShortcuts then
        local spawnedGroupsNames = {}
          
        veafShortcuts.ExecuteAlias("-sa15", "radius 4000, multiplier 6", position, self:getCoalition(), nil, spawnedGroupsNames)
        self:addSpawnedGroups(spawnedGroupsNames)
        veafSanctuary.logTrace(string.format("spawnedGroupsNames = %s", veaf.p(spawnedGroupsNames)))
        if timeInZone > veafSanctuary.HARDER_DEFENSES_AFTER then 
            veafShortcuts.ExecuteAlias("-sa10", "radius 6000, multiplier 3", position, self:getCoalition(), nil, spawnedGroupsNames)
            self:addSpawnedGroups(spawnedGroupsNames)
            veafSanctuary.logTrace(string.format("spawnedGroupsNames = %s", veaf.p(spawnedGroupsNames)))
        end
    end
end

function VeafSanctuaryZone:cleanupDefenses()
    veafSanctuary.logTrace(string.format("VeafSanctuaryZone[%s]:cleanupDefenses()", veaf.p(self.name)))
    local oldestTimeToKeep = timer.getTime() - veafSanctuary.DELETE_DEFENSES_AFTER
    for name, time in pairs(self:getSpawnedGroups()) do
        if time < oldestTimeToKeep then
            local group = Group.getByName(name)
            if group then 
                group:destroy()
                self:getSpawnedGroups()[name] = nil
            end
        end
    end
end

function VeafSanctuaryZone:handleUnit(unit, data)
    veafSanctuary.logTrace(string.format("VeafSanctuaryZone[%s]:handleUnit()", veaf.p(self.name)))

    if not(unit) then
        return 
    end

    local coalition = unit:getCoalition()
    if coalition == self:getCoalition() then
        veafSanctuary.logTrace(string.format("We're not concerned by this unit"))
        return -- we're not concerned by this unit
    end
    local position = unit:getPosition().p
    veafSanctuary.logTrace(string.format("position=%s", veaf.p(position)))
    
    local inZone = false
    if self:getPolygon() then
        veafSanctuary.logTrace("polygon mode")
        inZone = mist.pointInPolygon(position, self:getPolygon())
    elseif self:getPosition() then
        veafSanctuary.logTrace("circle and radius mode")
        local distanceFromCenter = ((position.x - self:getPosition().x)^2 + (position.z - self:getPosition().z)^2)^0.5
        veafSanctuary.logTrace(string.format("distanceFromCenter=%d, radius=%d", distanceFromCenter, self:getRadius()))
        inZone = distanceFromCenter < self:getRadius()
    end

    -- let's decide what we do
    if inZone then 
        local firstInZone = data.firstInZone
        if firstInZone < 0 then
            firstInZone = timer.getTime()
            data.firstInZone = firstInZone
        end
        local unitname = unit:getName()
        local playername = unit:getPlayerName()
        local callsign = unit:getCallsign()
        local timeInZone = timer.getTime() - firstInZone
        veafSanctuary.logTrace(string.format("unitname=%s, playername=%s, callsign=%s", veaf.p(unitname), veaf.p(playername), veaf.p(callsign)))

        local message = string.format("Unit %s is in the %s zone since %d seconds", playername, self:getName(), timeInZone)
        trigger.action.outTextForCoalition(self:getCoalition(), message, veafSanctuary.MESSAGE_TIME)
        veafSanctuary.logInfo(message)
        local groupId = unit:getGroup():getID()
        if self:getDelayInstant() > -1 and timeInZone >= self:getDelayInstant() then
            -- insta-death !
            local message = string.format("Instantly killing unit %s, in zone %s since %d seconds", playername, self:getName(), timeInZone)
            trigger.action.outTextForCoalition(self:getCoalition(), message, veafSanctuary.MESSAGE_TIME)
            veafSanctuary.logInfo(message)
            unit:destroy()
        elseif self:getDelaySpawn() > -1 and timeInZone >= self:getDelaySpawn() then
            -- spawn defense systems
            local message = string.format("Spawning defense systems to fend off unit %s, in zone %s since %d seconds", playername, self:getName(), timeInZone)
            trigger.action.outTextForCoalition(self:getCoalition(), message, veafSanctuary.MESSAGE_TIME)
            veafSanctuary.logInfo(message)
            trigger.action.outTextForGroup(groupId, string.format("CRITICAL: %s - %s", playername, self:getMessageSpawn()), veafSanctuary.MESSAGE_TIME)
            -- compute the position of the unit in 5 seconds
            local positionIn5s = mist.vec.add(position, mist.vec.scalarMult(unit:getVelocity(), 5))
            self:deployDefenses(positionIn5s, timeInZone)
        elseif self:getDelayWarning() > -1 and timeInZone >= self:getDelayWarning() then
            -- simple warning
            veafSanctuary.logDebug(string.format("Issuing a warning to unit %s", veaf.p(playername)))
            trigger.action.outTextForGroup(groupId, string.format(self:getMessageWarning(), playername, self:getDelayInstant() - timeInZone), veafSanctuary.MESSAGE_TIME)
        end
    elseif data.firstInZone >= 0 then
        local playername = unit:getPlayerName()
        -- reset the counter
        veafSanctuary.logDebug(string.format("%s got out of the zone", veaf.p(playername)))
        data.firstInZone = -1
    end

end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- core functions
-------------------------------------------------------------------------------------------------------------------------------------------------------------

-- add a zone
function veafSanctuary.addZone(zone)
    veafSanctuary.logTrace(string.format("addZone(%s)", veaf.p(zone:getName())))
    table.insert(veafSanctuary.zonesList, zone)
    return zone
end

-- add a zone from a DCS trigger zone
function veafSanctuary.addZoneFromTriggerZone(triggerZoneName)
    veafSanctuary.logTrace(string.format("addZoneFromTriggerZone(%s)", veaf.p(triggerZoneName)))
    local triggerZone = trigger.misc.getZone(triggerZoneName)
    if triggerZoneName then
        local zone = VeafSanctuaryZone.new():setName(triggerZoneName):setRadius(triggerZone.radius):setPosition(triggerZone.point)
        return veafSanctuary.addZone(zone)
    end
end

-- Handle world events.
veafSanctuary.eventHandler = {}
function veafSanctuary.eventHandler:onEvent(event)   
     
    if event == nil or event.id == nil then
        return 
    end
    
    veafSanctuary.logTrace(string.format("event %s",veaf.p(veaf.EVENTMETA[event.id].Text)))

    if not(
           event.id == world.event.S_EVENT_PLAYER_ENTER_UNIT 
        or event.id == world.event.S_EVENT_PLAYER_LEAVE_UNIT
        or event.id == world.event.S_EVENT_BIRTH
        or event.id == world.event.S_EVENT_DEAD
        ) then
        return 
    end

    if not event.initiator then
        return
    end

    local _unitname = event.initiator:getName()
    veafSanctuary.logTrace(string.format("event initiator unit  = %s", veaf.p(_unitname)))

    if event.id == world.event.S_EVENT_PLAYER_ENTER_UNIT 
    or event.id == world.event.S_EVENT_BIRTH and _unitname and veafSanctuary.humanUnits[_unitname]
    then
        -- register the human unit in the follow-up list when the human gets in the unit
        veafSanctuary.logTrace(string.format("registering human unit to follow: %s", veaf.p(_unitname)))
        veafSanctuary.humanUnitsToFollow[_unitname] = { firstInZone = -1}
    elseif event.id == world.event.S_EVENT_PLAYER_LEAVE_UNIT 
    or     event.id == world.event.S_EVENT_DEAD and _unitname and veafSanctuary.humanUnits[_unitname]
    then
        -- unregister the human unit from the follow-up list when the human gets in the unit
        veafSanctuary.logTrace(string.format("deregistering human unit to follow: %s", veaf.p(_unitname)))
        veafSanctuary.humanUnitsToFollow[_unitname] = nil
    end
end

-- main loop
function veafSanctuary.loop()
    veafSanctuary.logDebug("veafSanctuary.loop()")

    -- process all zones
    for _, zone in pairs(veafSanctuary.zonesList) do
        veafSanctuary.logTrace(string.format("zone:getName()=%s", veaf.p(zone:getName())))

        zone:cleanupDefenses()

        -- browse all the human units and check if they're in a zone
        for name, data in pairs(veafSanctuary.humanUnitsToFollow) do
            veafSanctuary.logTrace(string.format("name=%s", veaf.p(name)))
            local unit = Unit.getByName(name)
            if unit then
                zone:handleUnit(unit, data)
            else 
                -- stop following this unit, it's been destroyed
                veafSanctuary.humanUnitsToFollow[name] = nil
            end
        end
    end

    mist.scheduleFunction(veafSanctuary.loop, {}, timer.getTime() + veafSanctuary.DelayBetweenChecks)
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- initialisation
-------------------------------------------------------------------------------------------------------------------------------------------------------------

function veafSanctuary.initialize()
    veafSanctuary.logInfo("Initializing module")

    -- prepare humans units
    veafSanctuary.humanUnits = {}
    for name, _ in pairs(mist.DBs.humansByName) do
        veafSanctuary.logTrace(string.format("mist.DBs.humansByName[%s]=??", veaf.p(name)))
        veafSanctuary.humanUnits[name] = true
    end

    --- Add the event handler.
    world.addEventHandler(veafSanctuary.eventHandler)

    -- Start the main loop
    mist.scheduleFunction(veafSanctuary.loop, {}, timer.getTime() + veafSanctuary.DelayForStartup)

    veafSanctuary.initialized = true
    veafSanctuary.logInfo(string.format("Sanctuary system has been initialized"))
end

veafSanctuary.logInfo(string.format("Loading version %s", veafSanctuary.Version))
