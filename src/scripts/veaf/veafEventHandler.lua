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
veafEventHandler.Version = "1.0.1"

-- trace level, specific to this module
--veafEventHandler.LogLevel = "trace"

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Do not change anything below unless you know what you are doing!
-------------------------------------------------------------------------------------------------------------------------------------------------------------

veaf.loggers.new(veafEventHandler.Id, veafEventHandler.LogLevel)

function veafEventHandler.completeUnit(unit)
  if unit ~= nil then
    local unitName = unit:getName()
    return veafEventHandler.completeUnitFromName(unitName)
  else
    return nil
  end
end

function veafEventHandler.completeUnitFromName(unitName)
  if unitName ~= nil then
    local unitType = nil
    local unit = Unit.getByName(unitName)
    if unit then
      unitType = unit:getTypeName()
    end
    local unitPilotName = nil
    local unitPilotUcid = nil
    local unitPilot = veafRemote.getRemoteUserFromUnit(unitName)
    if unitPilot then
      veaf.loggers.get(veafEventHandler.Id):trace("unitPilot=%s", veaf.p(unitPilot))
      unitPilotName = unitPilot.name
      unitPilotUcid = unitPilot.ucid
    end
    return {
      unitName = unitName,
      unitType = unitType,
      unitPilotName = unitPilotName,
      unitPilotUcid = unitPilotUcid,
    }
  else
    return nil
  end
end

--- name self explanatory
--- events the list of event names or ids that your callback is interested into
--- callback the function to be called (we'll pass it an event; the definition of "event" can be found just below)
function veafEventHandler.addCallback(name, events, callback)
  veaf.loggers.get(veafEventHandler.Id):debug("veafEventHandler.addCallback(name=[%s])", veaf.p(name))

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

veafEventHandler.knownEventsNames = {
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
}

veafEventHandler.knownEvents = {} -- will be set at initialisation

function veafEventHandler.checkEventKnown(eventNameOrId, warnOnly)
  if veafEventHandler.knownEvents[eventNameOrId] ~= nil then
    return true
  else
    local message = string.format("Event is not recognized by the VEAF Recorder: [%s]", veaf.p(eventNameOrId))
    if warnOnly then
      veaf.loggers.get(veafEventHandler.Id):warning(message)
    else
      veaf.loggers.get(veafEventHandler.Id):error(message)
    end
    return false
  end
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
  veaf.loggers.get(veafEventHandler.Id):trace("event = %s", veaf.p(event))
  veaf.loggers.get(veafEventHandler.Id):trace("_event = %s", veaf.p(_event))

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
      veaf.loggers.get(veafEventHandler.Id):trace("calling callback %s", veaf.p(callback.name))
      callback.call(_event)
    end
  end
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Other functions
-------------------------------------------------------------------------------------------------------------------------------------------------------------

function veafEventHandler.initialize()
  veaf.loggers.get(veafEventHandler.Id):debug("veafEventHandler.initialize()")

  -- prepare the events maps
  for eventId, eventName in pairs(veafEventHandler.knownEventsNames) do
    local event = {
      name = eventName,
      id = eventId,
      enabled = true --false
    }
    veafEventHandler.knownEvents[eventName] = event
    veafEventHandler.knownEvents[eventId] = event
  end

  -- Add event handler.
  world.addEventHandler(veafEventHandler.eventHandler)
end

veafEventHandler.initialize()