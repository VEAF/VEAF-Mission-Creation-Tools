------------------------------------------------------------------
-- VEAF Event handler for DCS World
-- By Zip (2023)
--
-- Features:
-- ---------
-- * handles DCS events
-- * can be plugged to objects that react to events
--
-- See the documentation : https://veaf.github.io/documentation/
------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Global settings. Stores the script constants
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Identifier. All output in DCS.log will start with this.
veafEventHandler = {}

--- Identifier. All output in the log will start with this.
veafEventHandler.Id = "EVENTS - "

--- Version.
veafEventHandler.Version = "1.5.3"

-- trace level, specific to this module
--veafEventHandler.LogLevel = "trace"

veafEventHandler.CALLBACK_DELAY = 0.5 -- seconds

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Do not change anything below unless you know what you are doing!
-------------------------------------------------------------------------------------------------------------------------------------------------------------

veaf.loggers.new(veafEventHandler.Id, veafEventHandler.LogLevel)

function veafEventHandler.completeUnit(unit)
  if unit ~= nil and unit.getName then
    local unitName = unit:getName()
    return veafEventHandler.completeUnitFromName(unitName)
  else
    return nil
  end
end

function veafEventHandler.completeUnitFromName(unitName)
  veaf.loggers.get(veafEventHandler.Id):trace("veafEventHandler.completeUnitFromName(unitName=%s)", veaf.p(unitName))
  if unitName ~= nil then
    local unitType = nil
    local unitLifePercent = nil
    local unitLife = 0
    local unitCoalition = coalition.side.NEUTRAL
    local unitCategory = nil
    local unitGroupName = nil
    local unitGroupId = nil
    local unit = Unit.getByName(unitName)
    local unitCallsign = nil
    if unit then
      if unit.getTypeName then
        unitType = unit:getTypeName()
      end
      if unit.getLife then
        unitLife = unit:getLife()
      end
      if unit.getCoalition then
        unitCoalition = unit:getCoalition()
      end
      local unitLife0 = 0
      if unit.getLife0 then -- statics have no life0
        unitLife0 = unit:getLife0()
      end
      unitLifePercent = unitLife
      if unitLife0 > 0 then
        unitLifePercent = 100 * unitLife / unitLife0
      end
      if unit.getCategory then
        unitCategory = unit:getCategory()
      end
      if unit.getGroup then
        local group = unit:getGroup()
        if group then
          unitGroupName = group:getName()
          unitGroupId = group:getID()
        end
      end
      if unit.getCallsign then
        unitCallsign = unit:getCallsign()
        if type(unitCallsign) == "table" then unitCallsign = unitCallsign["name"] end
        if type(unitCallsign) == "number" then unitCallsign = "" .. unitCallsign end
      end
    end
    local unitPilotName = nil
    local unitPilotUcid = nil
    local unitPilot = veafRemote.getRemoteUserFromUnit(unitName)
    if unitPilot then
      veaf.loggers.get(veafEventHandler.Id):trace("unitPilot=%s", veaf.p(unitPilot))
      unitPilotName = unitPilot.name
      unitPilotUcid = unitPilot.ucid
    end
    if unitPilotName then 
      unitCallsign = unitPilotName
    end

    return {
      unitName = unitName,
      unitCallsign = unitCallsign,
      unitType = unitType,
      unitGroupName = unitGroupName,
      unitGroupId = unitGroupId,
      unitCoalition = unitCoalition,
      unitCategory = unitCategory,
      unitPilotName = unitPilotName,
      unitPilotUcid = unitPilotUcid,
      unitLifePercent = unitLifePercent
    }
  else
    return nil
  end
end

--- name self explanatory
--- events the list of event names or ids that your callback is interested into
--- callback the function to be called (we'll pass it an event; the definition of "event" can be found just below)
function veafEventHandler.addCallback(name, events, callback)
  veaf.loggers.get(veafEventHandler.Id):debug("veafEventHandler.addCallback(name=[%s])", name)
  veaf.loggers.get(veafEventHandler.Id):trace("veafEventHandler.addCallback(events=[%s])", events)

  if name == nil then
    veaf.loggers.get(veafEventHandler.Id):error("veafEventHandler.addCallback: parameter `name` is mandatory")
    return false
  end
  if callback == nil then
    veaf.loggers.get(veafEventHandler.Id):error("veafEventHandler.addCallback: parameter `callback` is mandatory")
    return false
  end
  if events ~= nil then
    -- validate all event types
    for _, eventNameOrId in pairs(events) do
      if not(veafEventHandler.checkEventKnown(eventNameOrId)) then
        return false
      end
    end
  end
  table.insert(veafEventHandler.callbacks, {name=name, events=events, call=callback})
  return true
end

veafEventHandler.callbacks = {}

local function transformEvent(event)
  local _event = {
    type = veafEventHandler.knownEvents[event.id],
    time = event.time,
    idx = event.idx,
    coordinates = event.pos,
    text = event.text,
    coalition = event.coalition,
    groupId = event.groupID,
    place = veafEventHandler.completeUnit(event.place),
    birthPlace = event.subPlace,
    initiator = veafEventHandler.completeUnit(event.initiator),
    target = veafEventHandler.completeUnit(event.target),
    weapon = event.weapon,
    weaponName = event.weapon_name,
    comment = event.comment
  }
  return _event
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Main event handler (used for PLAYER ENTER UNIT events)
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Event handler.
veafEventHandler.eventHandler = {}

veafEventHandler.EVENTS = {
  [0] = {
      name = "S_EVENT_INVALID",
      id = 0,
      enabled = false
    },
  [1] = {
      name = "S_EVENT_SHOT",
      id = 1,
      enabled = true
    },
  [2] = {
      name = "S_EVENT_HIT",
      id = 2,
      enabled = true
    },
  [3] = {
      name = "S_EVENT_TAKEOFF",
      id = 3,
      enabled = true
    },
  [4] = {
      name = "S_EVENT_LAND",
      id = 4,
      enabled = true
    },
  [5] = {
      name = "S_EVENT_CRASH",
      id = 5,
      enabled = true
    },
  [6] = {
      name = "S_EVENT_EJECTION",
      id = 6,
      enabled = true
    },
  [7] = {
      name = "S_EVENT_REFUELING",
      id = 7,
      enabled = true
    },
  [8] = {
      name = "S_EVENT_DEAD",
      id = 8,
      enabled = true
    },
  [9] = {
      name = "S_EVENT_PILOT_DEAD",
      id = 9,
      enabled = true
    },
  [10] = {
      name = "S_EVENT_BASE_CAPTURED",
      id = 10,
      enabled = true
    },
  [11] = {
      name = "S_EVENT_MISSION_START",
      id = 11,
      enabled = true
    },
  [12] = {
      name = "S_EVENT_MISSION_END",
      id = 12,
      enabled = true
    },
  [13] = {
      name = "S_EVENT_TOOK_CONTROL",
      id = 13,
      enabled = true
    },
  [14] = {
      name = "S_EVENT_REFUELING_STOP",
      id = 14,
      enabled = true
    },
  [15] = {
      name = "S_EVENT_BIRTH",
      id = 15,
      enabled = true,
      delaycallback = true
    },
  [16] = {
      name = "S_EVENT_HUMAN_FAILURE",
      id = 16,
      enabled = true
    },
  [17] = {
      name = "S_EVENT_DETAILED_FAILURE",
      id = 17,
      enabled = true
    },
  [18] = {
      name = "S_EVENT_ENGINE_STARTUP",
      id = 18,
      enabled = true
    },
  [19] = {
      name = "S_EVENT_ENGINE_SHUTDOWN",
      id = 19,
      enabled = true
    },
  [20] = {
      name = "S_EVENT_PLAYER_ENTER_UNIT",
      id = 20,
      enabled = true,
      delaycallback = true
    },
  [21] = {
      name = "S_EVENT_PLAYER_LEAVE_UNIT",
      id = 21,
      enabled = true
    },
  [22] = {
      name = "S_EVENT_PLAYER_COMMENT",
      id = 22,
      enabled = true
    },
  [23] = {
      name = "S_EVENT_SHOOTING_START",
      id = 23,
      enabled = true
    },
  [24] = {
      name = "S_EVENT_SHOOTING_END",
      id = 24,
      enabled = true
    },
  [25] = {
      name = "S_EVENT_MARK_ADDED",
      id = 25,
      enabled = true
    },
  [26] = {
      name = "S_EVENT_MARK_CHANGE",
      id = 26,
      enabled = true
    },
  [27] = {
      name = "S_EVENT_MARK_REMOVED",
      id = 27,
      enabled = true
    },
  [28] = {
      name = "S_EVENT_KILL",
      id = 28,
      enabled = true
    },
  [29] = {
      name = "S_EVENT_SCORE",
      id = 29,
      enabled = true
    },
  [30] = {
      name = "S_EVENT_UNIT_LOST",
      id = 30,
      enabled = true
    },
  [31] = {
      name = "S_EVENT_LANDING_AFTER_EJECTION",
      id = 31,
      enabled = true
    },
  [32] = {
      name = "S_EVENT_PARATROOPER_LENDING",
      id = 32,
      enabled = true
    },
  [33] = {
      name = "S_EVENT_DISCARD_CHAIR_AFTER_EJECTION",
      id = 33,
      enabled = true
    },
  [34] = {
      name = "S_EVENT_WEAPON_ADD",
      id = 34,
      enabled = true
    },
  [35] = {
      name = "S_EVENT_TRIGGER_ZONE",
      id = 35,
      enabled = true
    },
  [36] = {
      name = "S_EVENT_LANDING_QUALITY_MARK",
      id = 36,
      enabled = true
    },
  [37] = {
      name = "S_EVENT_BDA",
      id = 37,
      enabled = true
    },
  [38] = {
      name = "S_EVENT_AI_ABORT_MISSION",
      id = 38,
      enabled = true
    },
  [39] = {
      name = "S_EVENT_DAYNIGHT",
      id = 39,
      enabled = true
    },
  [40] = {
      name = "S_EVENT_FLIGHT_TIME",
      id = 40,
      enabled = true
    },
  [41] = {
      name = "S_EVENT_PLAYER_SELF_KILL_PILOT",
      id = 41,
      enabled = true
    },
  [42] = {
      name = "S_EVENT_PLAYER_CAPTURE_AIRFIELD",
      id = 42,
      enabled = true
    },
  [43] = {
      name = "S_EVENT_EMERGENCY_LANDING",
      id = 43,
      enabled = true
    },
  [44] = {
      name = "S_EVENT_UNIT_CREATE_TASK",
      id = 44,
      enabled = true
    },
  [45] = {
      name = "S_EVENT_UNIT_DELETE_TASK",
      id = 45,
      enabled = true
    },
  [46] = {
      name = "S_EVENT_SIMULATION_START",
      id = 46,
      enabled = true
    },
  [47] = {
      name = "S_EVENT_WEAPON_REARM",
      id = 47,
      enabled = true
    },
  [48] = {
      name = "S_EVENT_WEAPON_DROP",
      id = 48,
      enabled = true
    },
  [49] = {
      name = "S_EVENT_UNIT_TASK_COMPLETE",
      id = 49,
      enabled = true
    },
  [50] = {
      name = "S_EVENT_UNIT_TASK_STAGE",
      id = 50,
      enabled = true
    },
  [51] = {
      name = "S_EVENT_MAC_EXTRA_SCORE",
      id = 51,
      enabled = true
    },
  [52] = {
      name = "S_EVENT_MISSION_RESTART",
      id = 52,
      enabled = true
    },
  [53] = {
      name = "S_EVENT_MISSION_WINNER",
      id = 53,
      enabled = true
    },
  [54] = {
      name = "S_EVENT_RUNWAY_TAKEOFF",
      id = 54,
      enabled = true
    },
  [55] = {
      name = "S_EVENT_RUNWAY_TOUCH",
      id = 55,
      enabled = true
    },
  [56] = {
      name = "S_EVENT_MAC_LMS_RESTART",
      id = 56,
      enabled = true
    },
  [57] = {
      name = "S_EVENT_SIMULATION_FREEZE",
      id = 57,
      enabled = true
    },
  [58] = {
      name = "S_EVENT_SIMULATION_UNFREEZE",
      id = 58,
      enabled = true
    },
  [59] = {
      name = "S_EVENT_HUMAN_AIRCRAFT_REPAIR_START",
      id = 59,
      enabled = true
    },
  [60] = {
      name = "S_EVENT_HUMAN_AIRCRAFT_REPAIR_FINISH",
      id = 60,
      enabled = true
    },
  [61] = {
      name = "S_EVENT_MAX",
      id = 61,
      enabled = false
    }
}

veafEventHandler.unknownEvents = {} -- will be used to remember already signaled unknown events

function veafEventHandler.checkEventKnown(eventNameOrId, warnOnly)
  veaf.loggers.get(veafEventHandler.Id):trace("veafEventHandler.checkEventKnown(eventNameOrId=%s)", eventNameOrId)

  if veafEventHandler.knownEvents[eventNameOrId] ~= nil then
    return true
  elseif veafEventHandler.unknownEvents[eventNameOrId] == nil then
    veafEventHandler.unknownEvents[eventNameOrId] = true
    local message = string.format("Event is not recognized by veafEventHandler: [%s]", veaf.p(eventNameOrId))
    if warnOnly then
      veaf.loggers.get(veafEventHandler.Id):warn(message)
    else
      veaf.loggers.get(veafEventHandler.Id):error(message)
    end
  end
  return false
end

function veafEventHandler.setEventEnabled(eventNameOrId, enabled)
  if veafEventHandler.checkEventKnown(eventNameOrId) then
    veafEventHandler.knownEvents[eventNameOrId].enabled = enabled
  end
end

function veafEventHandler.isEventEnabled(eventNameOrId)
  if veafEventHandler.checkEventKnown(eventNameOrId) then
    return veafEventHandler.knownEvents[eventNameOrId].enabled
  end
end

function veafEventHandler.isEventDelayedCallback(eventNameOrId)
  if veafEventHandler.checkEventKnown(eventNameOrId) then
    return veafEventHandler.knownEvents[eventNameOrId].delaycallback
  end
end

--- Handle world events.
function veafEventHandler.eventHandler:onEvent(event)

  if event == nil then
    veaf.loggers.get(veafEventHandler.Id):error("Event handler was called with a nil event!")
    return
  end

  -- check that we know the event
  if not(veafEventHandler.checkEventKnown(event.id, true)) then
    return
  end

  -- skip disabled events
  if not(veafEventHandler.isEventEnabled(event.id)) then
      return true
  end

  local _event = transformEvent(event)

  -- Debug output.
  if veaf.loggers.get(veafEventHandler.Id):wouldLogTrace() then
    veaf.loggers.get(veafEventHandler.Id):trace("event = %s", veaf.p(event))
    veaf.loggers.get(veafEventHandler.Id):trace("_event = %s", veaf.p(_event))
  end

  -- process event
  for _, callback in pairs(veafEventHandler.callbacks) do
    local callIt = false
    if callback.events == nil then
      callIt = true
    else
      for _, eventNameOrId in pairs(callback.events) do
        if _event.type.id == eventNameOrId or _event.type.name == eventNameOrId then
          callIt = true
          break
        end
      end
    end
    if callIt then
      if veafEventHandler.isEventDelayedCallback(_event.type.id) then
        veaf.loggers.get(veafEventHandler.Id):debug("delayed callback %s", veaf.p(callback.name))
        timer.scheduleFunction(callback.call, _event, timer.getTime() + veafEventHandler.CALLBACK_DELAY)
      else
        veaf.loggers.get(veafEventHandler.Id):debug("calling callback %s", veaf.p(callback.name))
        callback.call(_event)
      end
    end
  end
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Other functions
-------------------------------------------------------------------------------------------------------------------------------------------------------------

function veafEventHandler.initialize()
  veaf.loggers.get(veafEventHandler.Id):debug("veafEventHandler.initialize()")
  veaf.loggers.get(veafEventHandler.Id):info(veaf.loggers.get(veafEventHandler.Id):getVersionInfo(veafEventHandler.Version))

  -- copy the events maps (add events by name) and add the events by id to the veafEventHandler.knownEventsNames table
  veafEventHandler.knownEventsNames = {}
  veafEventHandler.knownEvents = {}
  for eventId, event in pairs(veafEventHandler.EVENTS) do
    veafEventHandler.knownEvents[event.name] = event
    veafEventHandler.knownEvents[eventId] = event
    veafEventHandler.knownEventsNames[eventId] = event.name
  end

  -- Add event handler.
  world.addEventHandler(veafEventHandler.eventHandler)
end

veafEventHandler.initialize()