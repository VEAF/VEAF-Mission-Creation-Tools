env.info("DcssbMatchManager - loading script")
---
--- This Lua script defines the DcssbMatchManager class, which is designed to manage player participation in matches within a DCS World mission. 
--- It interacts with a hypothetical "DCSBot" (likely a Discord bot or similar) to register players into matches. 
--- The script supports adding players automatically after a timeout, or when they enter a designated trigger zone. 
--- It leverages DCS World's event system to track player activities, specifically focusing on when players enter units.
--- 
--- Key Components:
---  * DcssbMatchManager Class: The core of the script. It handles match creation, player registration, and event processing.
---  * DcssbMatchManager:new(): Constructor for the DcssbMatchManager class. Initializes a new match manager instance.
---  * DcssbMatchManager:setName(), DcssbMatchManager:setMatchName(), DcssbMatchManager:setCoalition(), DcssbMatchManager:setTriggerZone(), DcssbMatchManager:setTimeout(): Setter methods to configure the match manager's properties (name, match name, coalition, trigger zone, and timeout).
---  * DcssbMatchManager:addPlayerByName(), DcssbMatchManager:addPlayerByUnit(): Methods to register players into a match, either by their player name or by the name of the unit they are controlling. These methods interact with dcsbot.sendBotTable() to communicate the player addition to the external bot.
---  * DcssbMatchManager:onEvent(): Event handler function. It listens for DCS World events, specifically S_EVENT_PLAYER_ENTER_UNIT, to detect when players enter units. Based on the configured coalition and trigger zone/timeout settings, it adds players to the match.
---  * DcssbMatchManager:onSchedule(): A scheduled function that runs repeatedly. It checks if players are waiting to enter a trigger zone and adds them to the match when they do.
---  * DcssbMatchManager.addMatchManager(): A factory function to create and configure a new DcssbMatchManager instance. It also adds the instance as an event handler and schedules the onSchedule function.
---  * DcssbMatchManager.addMatchManagersForZones(): Creates multiple DcssbMatchManager instances, one for each trigger zone defined in the mission.
---  * DcssbMatchManager.knownEvents: A table mapping DCS event IDs and names to event objects. Used for event handling and debugging.
---  * DcssbMatchManager.initialize(): Initializes the DcssbMatchManager.knownEvents table.
--- 
--- The script is designed to be modular and extensible, allowing for easy creation and management of multiple matches within a single mission. 
--- The use of trigger zones and timeouts provides flexibility in how players are added to matches. 
--- 
--- Usage:
--- To use this script, you would typically call DcssbMatchManager.addMatchManager() with the desired parameters (name, match name, coalition, trigger zone, and timeout).
--- You can also call DcssbMatchManager.addMatchManagersForZones() to create match managers for all defined trigger zones in the mission.

---
-- mocking DCSBot (for testing)
--dcsbot = {}
--function dcsbot.sendBotTable(table)
--    env.info(string.format("DcssbMatchManager:dcsbot.sendBotTable->command=[%s]", table and table.command or "NONE"))
--    env.info(string.format("DcssbMatchManager:dcsbot.sendBotTable->match_id=[%s]", table and table.match_id or "NONE"))
--    env.info(string.format("DcssbMatchManager:dcsbot.sendBotTable->player_name=[%s]", table and table.player_name or "NONE"))
--end

DcssbMatchManager = {}
DcssbMatchManager.Id = "DcssbMatchManager"
DcssbMatchManager.LOG = true
DcssbMatchManager.knownEvents = {} -- will be set at initialisation
DcssbMatchManager.knownEventsNames = {
    [00] = "S_EVENT_INVALID",
    [01] = "S_EVENT_SHOT",
    [02] = "S_EVENT_HIT",
    [03] = "S_EVENT_TAKEOFF",
    [04] = "S_EVENT_LAND",
    [05] = "S_EVENT_CRASH",
    [06] = "S_EVENT_EJECTION",
    [07] = "S_EVENT_REFUELING",
    [08] = "S_EVENT_DEAD",
    [09] = "S_EVENT_PILOT_DEAD",
    [10] = "S_EVENT_BASE_CAPTURED",
    [11] = "S_EVENT_MISSION_START",
    [12] = "S_EVENT_MISSION_END",
    [13] = "S_EVENT_TOOK_CONTROL",
    [14] = "S_EVENT_REFUELING_STOP",
    [15] = "S_EVENT_BIRTH",
    [16] = "S_EVENT_HUMAN_FAILURE",
    [17] = "S_EVENT_DETAILED_FAILURE",
    [18] = "S_EVENT_ENGINE_STARTUP",
    [19] = "S_EVENT_ENGINE_SHUTDOWN",
    [20] = "S_EVENT_PLAYER_ENTER_UNIT",
    [21] = "S_EVENT_PLAYER_LEAVE_UNIT",
    [22] = "S_EVENT_PLAYER_COMMENT",
    [23] = "S_EVENT_SHOOTING_START",
    [24] = "S_EVENT_SHOOTING_END",
    [25] = "S_EVENT_MARK_ADDED",
    [26] = "S_EVENT_MARK_CHANGE",
    [27] = "S_EVENT_MARK_REMOVED",
    [28] = "S_EVENT_KILL",
    [29] = "S_EVENT_SCORE",
    [30] = "S_EVENT_UNIT_LOST",
    [31] = "S_EVENT_LANDING_AFTER_EJECTION",
    [32] = "S_EVENT_PARATROOPER_LENDING",
    [33] = "S_EVENT_DISCARD_CHAIR_AFTER_EJECTION",
    [34] = "S_EVENT_WEAPON_ADD",
    [35] = "S_EVENT_TRIGGER_ZONE",
    [36] = "S_EVENT_LANDING_QUALITY_MARK",
    [37] = "S_EVENT_BDA",
    [38] = "S_EVENT_AI_ABORT_MISSION",
    [39] = "S_EVENT_DAYNIGHT",
    [40] = "S_EVENT_FLIGHT_TIME",
    [41] = "S_EVENT_PLAYER_SELF_KILL_PILOT",
    [42] = "S_EVENT_PLAYER_CAPTURE_AIRFIELD",
    [43] = "S_EVENT_EMERGENCY_LANDING",
    [44] = "S_EVENT_UNIT_CREATE_TASK",
    [45] = "S_EVENT_UNIT_DELETE_TASK",
    [46] = "S_EVENT_SIMULATION_START",
    [47] = "S_EVENT_WEAPON_REARM",
    [48] = "S_EVENT_WEAPON_DROP",
    [49] = "S_EVENT_UNIT_TASK_TIMEOUT",
    [50] = "S_EVENT_UNIT_TASK_STAGE",
    [51] = "S_EVENT_MAX",
    [52] = "[UNKNOWN]",                -- ???
    [53] = "[UNKNOWN]",                -- ???
    [54] = "S_EVENT_RUNWAY_TAKEOFF",   -- since 2.9.6
    [55] = "S_EVENT_RUNWAY_TOUCH",     -- since 2.9.6
}
DcssbMatchManager.DEFAULT_TIMEOUT = 15 -- seconds

function DcssbMatchManager.init(object)
    -- technical name (identifier)
    object.name = nil
    -- match name
    object.matchName = nil
    -- coalition
    object.coalition = nil
    -- timeout in seconds
    object.timeout = DcssbMatchManager.DEFAULT_TIMEOUT
    -- trigger zone
    object.triggerZone = nil
    -- already managed player names
    object.playerNames = {}
    -- players waiting to pass in trigger zone
    object.unitsWaitingToPassInTriggerZoneToBeAdded = {}
end

function DcssbMatchManager:new(objectToCopy)
    if DcssbMatchManager.LOG then env.info(string.format("DcssbMatchManager:new()")) end
    local objectToCreate = objectToCopy or {} -- create object if user does not provide one
    setmetatable(objectToCreate, self)
    self.__index = self

    -- init the new object
    DcssbMatchManager.init(objectToCreate)

    return objectToCreate
end

function DcssbMatchManager:setName(value)
    if DcssbMatchManager.LOG then env.info(string.format("DcssbMatchManager[]:setName(%s)", value or "NONE")) end
    self.name = value
    return self
end

function DcssbMatchManager:getName()
    return self.name
end

function DcssbMatchManager:setMatchName(value)
    if DcssbMatchManager.LOG then env.info(string.format("DcssbMatchManager[%s]:setMatchName(%s)", self:getName(), value or "NONE")) end
    self.matchName = value
    return self
end

function DcssbMatchManager:getMatchName()
    return self.matchName
end

function DcssbMatchManager:setCoalition(value)
    if DcssbMatchManager.LOG then env.info(string.format("DcssbMatchManager[%s]:setCoalition(%s)", self:getName(), value or "NONE")) end
    self.coalition = value
    return self
end

function DcssbMatchManager:getCoalition()
    return self.coalition
end

function DcssbMatchManager:setTriggerZone(value)
    if DcssbMatchManager.LOG then env.info(string.format("DcssbMatchManager[%s]:setTriggerZone(%s)", self:getName(), value or "NONE")) end
    if value then
        if type(value) == "string" then
            value = trigger.misc.getZone(value)
            if value then 
                if DcssbMatchManager.LOG then env.info("Zone found") end
            else
                env.error(string.format("DcssbMatchManager[%s]:setTriggerZone(%s) - zone not found", self:getName(), value))
                self.triggerZone = nil
                return self
            end
        end
        self.triggerZone = value
    end
    return self
end

function DcssbMatchManager:getTriggerZone()
    return self.triggerZone
end

function DcssbMatchManager:setTimeout(value)
    if DcssbMatchManager.LOG then env.info(string.format("DcssbMatchManager[%s]:setTimeout(%s)", self:getName(), value or "NONE")) end
    self.timeout = value
    return self
end

function DcssbMatchManager:getTimeout()
    return self.timeout
end

function DcssbMatchManager.addPlayerByNameForScheduler(parameters)
    if DcssbMatchManager.LOG then env.info(string.format("DcssbMatchManager[]:addPlayerByNameForScheduler(%s)", parameters and parameters[2] or "NONE")) end
    if parameters then
        local self = parameters[1]
        local playerName = parameters[2]
        self:addPlayerByName(playerName)
    end
end

function DcssbMatchManager:addPlayerByName(playerName)
    if DcssbMatchManager.LOG then env.info(string.format("DcssbMatchManager[%s]:addPlayerByName(%s)", self:getName(), playerName or "NONE")) end
    if playerName then
        if dcsbot then
            dcsbot.sendBotTable({
                command = "addPlayerToMatch",
                match_id = self:getMatchName(),
                player_name = playerName
            })
        end
        trigger.action.outText("Player " .. playerName .. " added to match " .. self:getMatchName(), 10)
        if DcssbMatchManager.LOG then env.info(string.format("DcssbMatchManager[%s]: Player %s added to match %s", self:getName(), playerName, self:getMatchName())) end
    end
    self.playerNames[playerName] = playerName
    return self
end

function DcssbMatchManager.addPlayerByUnitForScheduler(parameters)
    if DcssbMatchManager.LOG then env.info(string.format("DcssbMatchManager[]:addPlayerByUnitForScheduler(%s)", parameters and parameters[2] or "NONE")) end
    if parameters then
        local self = parameters[1]
        local unitName = parameters[2]
        self:addPlayerByUnit(unitName)
    end
end

function DcssbMatchManager:addPlayerByUnit(unitName)
    if DcssbMatchManager.LOG then env.info(string.format("DcssbMatchManager[%s]:addPlayerByUnit(%s)", self:getName(), unitName or "NONE")) end
    if unitName then
        local unit = Unit.getByName(unitName)
        if unit then
            local playerName = unit:getPlayerName()
            if playerName then
                self:addPlayerByName(playerName)
            end
        end
    end
end

function DcssbMatchManager:onEvent(event)
    local function completeUnitFromName(unitName)
        if DcssbMatchManager.LOG then env.info(string.format("DcssbMatchManager[%s]: completeUnitFromName(unitName=%s)", self:getName(), unitName or "NONE")) end
        if unitName ~= nil then
            local unitType = nil
            local unitLifePercent = nil
            local unit = Unit.getByName(unitName)
            if unit and unit.getTypeName then
                unitType = unit:getTypeName()
                local unitLife = unit:getLife()
                local unitLife0 = 0
                if unit.getLife0 then -- statics have no life0
                    unitLife0 = unit:getLife0()
                end
                unitLifePercent = unitLife
                if unitLife0 > 0 then
                    unitLifePercent = 100 * unitLife / unitLife0
                end
            end
            return {
                unitName = unitName,
                unitType = unitType,
                unitPilotName = (unit and unit:getPlayerName() or "unknown"),
                unitLifePercent = unitLifePercent
            }
        else
            return nil
        end
    end

    local function completeUnit(unit)
        if unit ~= nil and unit.getName then
            local unitName = unit:getName()
            return completeUnitFromName(unitName)
        else
            return nil
        end
    end

    local function transformEvent(event)
        local _event = {
            type = DcssbMatchManager.knownEvents[event.id],
            time = event.time,
            idx = event.idx,
            coordinates = event.pos,
            text = event.text,
            coalition = event.coalition,
            groupId = event.groupID,
            place = completeUnit(event.place),
            birthPlace = event.subPlace,
            initiator = completeUnit(event.initiator),
            target = completeUnit(event.target),
            weapon = event.weapon,
            weaponName = event.weapon_name,
            comment = event.comment
        }
        return _event
    end

    if event == nil then
        env.error(string.format("DcssbMatchManager[%s]:onEvent was called with a nil event!", self:getName()))
        return
    end

    local _event = transformEvent(event)

    -- Debug output.
    if DcssbMatchManager.LOG then env.info(string.format("DcssbMatchManager[%s]:onEvent(id=%s, name=%s)", self:getName(), event and event.id or "NONE", _event and _event.type and _event.type.name or "NONE")) end

    -- process birth event
    local eventId = (event and event.id or 0)
    if DcssbMatchManager.LOG then env.info(string.format("DcssbMatchManager[%s]:onEvent() - eventId=%s", self:getName(), eventId or "NONE")) end
    if eventId == world.event.S_EVENT_PLAYER_ENTER_UNIT then
        -- check the coalition of the event initiator
        if self:getCoalition() then
            if _event.initiator and _event.initiator.unitName then
                local unit = Unit.getByName(_event.initiator.unitName)
                if unit then
                    if unit:getCoalition() ~= self:getCoalition() then
                        return
                    end
                end
            end
        end
        -- if there is a trigger zone, don't add player to the match now
        if self:getTriggerZone() then
            if DcssbMatchManager.LOG then env.info(string.format("DcssbMatchManager[%s]:onEvent() - player %s is waiting to pass in trigger zone", self:getName(), _event.initiator.unitPilotName)) end
            self.unitsWaitingToPassInTriggerZoneToBeAdded[_event.initiator.unitName] = _event.initiator.unitName
            return
        end
        -- if there is a timeout, schedule the player to be added to the match
        if self:getTimeout() then
            if DcssbMatchManager.LOG then env.info(string.format("DcssbMatchManager[%s]:onEvent() - player %s will be added to the match in %s seconds", self:getName(), _event.initiator.unitPilotName, self:getTimeout())) end
            timer.scheduleFunction(DcssbMatchManager.addPlayerByNameForScheduler, {self, _event.initiator.unitPilotName}, timer.getTime() + self:getTimeout())
        else
            if DcssbMatchManager.LOG then env.info(string.format("DcssbMatchManager[%s]:onEvent() - player %s is being added to the match", self:getName(), _event.initiator.unitPilotName)) end
            self:addPlayerByName(_event.initiator.unitPilotName)
        end
    end
end

function DcssbMatchManager:onSchedule()
    if DcssbMatchManager.LOG then env.info(string.format("DcssbMatchManager[%s]:onSchedule()", self:getName())) end

    -- reschedule
    timer.scheduleFunction(DcssbMatchManager.onSchedule, self, timer.getTime() + 1) -- schedule in 1 second
    -- check if players are waiting to pass in trigger zone
    if self:getTriggerZone() then
        for unitName, _ in pairs(self.unitsWaitingToPassInTriggerZoneToBeAdded) do
            if DcssbMatchManager.LOG then env.info(string.format("DcssbMatchManager[%s]:onSchedule() - player in unit %s is waiting to pass in trigger zone", self:getName(), unitName)) end
            local unit = Unit.getByName(unitName)
            if not unit then
                if DcssbMatchManager.LOG then env.info(string.format("DcssbMatchManager[%s]:onSchedule() - player in unit %s is not in game anymore", self:getName(), unitName)) end
                self.unitsWaitingToPassInTriggerZoneToBeAdded[unitName] = nil
            else
                local unitPoint = unit:getPoint()
                local zonePoint = self:getTriggerZone() and self:getTriggerZone().point
                local zoneRadius = self:getTriggerZone() and self:getTriggerZone().radius
                if not zonePoint or not zoneRadius then
                    env.error(string.format("DcssbMatchManager[%s]:onSchedule() - trigger zone is not correctly defined", self:getName()))
                    return
                end
                if ((unitPoint.x - zonePoint.x)^2 + (unitPoint.z - zonePoint.z)^2)^0.5 <= zoneRadius then
                    if DcssbMatchManager.LOG then env.info(string.format("DcssbMatchManager[%s]:onSchedule() - player in unit %s is passing in trigger zone", self:getName(), unitName)) end
                    -- if there is a timeout, schedule the player to be added to the match
                    if self:getTimeout() then
                        if DcssbMatchManager.LOG then env.info(string.format("DcssbMatchManager[%s]:onEvent() - player in unit %s will be added to the match in %s seconds", self:getName(), unitName, self:getTimeout())) end
                        timer.scheduleFunction(DcssbMatchManager.addPlayerByUnitForScheduler, {self, unitName}, timer.getTime() + self:getTimeout())
                    else
                        if DcssbMatchManager.LOG then env.info(string.format("DcssbMatchManager[%s]:onEvent() - player in unit %s is being added to the match", self:getName(), unitName)) end
                        self:addPlayerByUnit(unitName)
                    end
                    self.unitsWaitingToPassInTriggerZoneToBeAdded[unitName] = nil
                end
            end
        end
    end
end

function DcssbMatchManager.addMatchManager(name, matchName, coalition, triggerZone, timeout)
    if DcssbMatchManager.LOG then env.info(string.format("DcssbMatchManager.addMatchManager(%s)", name or "NONE")) end
    local matchManager = DcssbMatchManager:new()
    matchManager:setName(name)
    matchManager:setMatchName(matchName)
    matchManager:setCoalition(coalition)
    matchManager:setTriggerZone(triggerZone)
    matchManager:getTriggerZone()
    matchManager:setTimeout(timeout)

    -- Add event handler.
    world.addEventHandler(matchManager)

    -- schedule the match manager
    matchManager:onSchedule()

    return matchManager
end

function DcssbMatchManager.addMatchManagersForZones(timeout, exclusionList)
    if DcssbMatchManager.LOG then env.info(string.format("DcssbMatchManager.addMatchManagersForZones(%s)", timeout or "NONE")) end
    local matchManagers = {}
    for _, zone in pairs(env.mission.triggers.zones) do
        local name = zone.name
        --veaf.loggers.get(DcssbMatchManager.Id):trace("name=%s)", name)
        --veaf.loggers.get(DcssbMatchManager.Id):trace("zone=%s)", zone)
        if DcssbMatchManager.LOG then env.info(string.format("DcssbMatchManager.addMatchManagersForZones() - testing zone %s", name or "NONE")) end
        local exclude = false
        if exclusionList then
            for _, value in ipairs(exclusionList) do
                if value:upper() == name:upper() then
                    exclude = true
                end
            end
        end
        if not exclude then
            if zone then
                if DcssbMatchManager.LOG then env.info(string.format("DcssbMatchManager.addMatchManagersForZones() - adding zone %s", name or "NONE")) end
                local matchManager = DcssbMatchManager.addMatchManager(name, name, nil, name, timeout)
                table.insert(matchManagers, matchManager)
            end
        else
            if DcssbMatchManager.LOG then env.info(string.format("DcssbMatchManager.addMatchManagersForZones() - zone %s is excluded", name)) end
        end
    end
    return matchManagers
end

function DcssbMatchManager.initialize()
    if DcssbMatchManager.LOG then env.info("DcssbMatchManager.initialize()") end
    -- prepare the events maps
    for eventId, eventName in pairs(DcssbMatchManager.knownEventsNames) do
        local event = {
            name = eventName,
            id = eventId,
            enabled = true --false
        }
        DcssbMatchManager.knownEvents[eventName] = event
        DcssbMatchManager.knownEvents[eventId] = event
    end
end

DcssbMatchManager.initialize()
--veaf.loggers.new(DcssbMatchManager.Id, "trace")

env.info("DcssbMatchManager - script loaded")