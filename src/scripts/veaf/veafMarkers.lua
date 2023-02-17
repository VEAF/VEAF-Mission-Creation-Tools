------------------------------------------------------------------
-- VEAF markers function library for DCS World
-- By zip (2018)
--
-- Features:
-- ---------
-- * Listen to marker events and execute event handlers.
--
-- See the documentation : https://veaf.github.io/documentation/
------------------------------------------------------------------

veafMarkers = {}

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Global settings. Stores the script constants
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Identifier. All output in DCS.log will start with this.
veafMarkers.Id = "MARKERS"

--- Version.
veafMarkers.Version = "1.1.0"

--- DCS bug regarding wrong marker vector components was fixed. If so, set to true!
veafMarkers.DCSbugfixed = true

-- trace level, specific to this module
--veafMarkers.LogLevel = "trace"

veaf.loggers.new(veafMarkers.Id, veafMarkers.LogLevel)

veafMarkers.MarkerAdd = 1
veafMarkers.MarkerChange = 2
veafMarkers.MarkerRemove = 3

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Do not change anything below unless you know what you are doing!
-------------------------------------------------------------------------------------------------------------------------------------------------------------

veafMarkers.eventHandlerId = 0
veafMarkers.onEventMarkChangeEventHandlers = {}
veafMarkers.onEventMarkAddEventHandlers = {}
veafMarkers.onEventMarkRemoveEventHandlers = {}

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Utility methods
-------------------------------------------------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Event handler.
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Event handler.
veafMarkers.eventHandler = {}

--- Handle world events.
function veafMarkers.eventHandler:onEvent(Event)
    -- Only interested in S_EVENT_MARK_*
    if Event == nil or Event.idx == nil then
        return true
    end

    -- Debug output.
    if Event.id == world.event.S_EVENT_MARK_ADDED then
        veaf.loggers.get(veafMarkers.Id):debug("S_EVENT_MARK_ADDED")
    elseif Event.id == world.event.S_EVENT_MARK_CHANGE then
        veaf.loggers.get(veafMarkers.Id):debug("S_EVENT_MARK_CHANGE")
    elseif Event.id == world.event.S_EVENT_MARK_REMOVED then
        veaf.loggers.get(veafMarkers.Id):debug("S_EVENT_MARK_REMOVED")
    end
    veaf.loggers.get(veafMarkers.Id):trace(string.format("Event id        = %s", tostring(Event.id)))
    veaf.loggers.get(veafMarkers.Id):trace(string.format("Event time      = %s", tostring(Event.time)))
    veaf.loggers.get(veafMarkers.Id):trace(string.format("Event idx       = %s", tostring(Event.idx)))
    veaf.loggers.get(veafMarkers.Id):trace(string.format("Event coalition = %s", tostring(Event.coalition)))
    veaf.loggers.get(veafMarkers.Id):trace(string.format("Event group id  = %s", tostring(Event.groupID)))
    veaf.loggers.get(veafMarkers.Id):trace(string.format("Event pos X     = %s", tostring(Event.pos.x)))
    veaf.loggers.get(veafMarkers.Id):trace(string.format("Event pos Y     = %s", tostring(Event.pos.y)))
    veaf.loggers.get(veafMarkers.Id):trace(string.format("Event pos Z     = %s", tostring(Event.pos.z)))
    if Event.initiator ~= nil then
        local _unitname = Event.initiator:getName()
        veaf.loggers.get(veafMarkers.Id):trace(string.format("Event ini unit  = %s", tostring(_unitname)))
    end
    veaf.loggers.get(veafMarkers.Id):trace(string.format("Event text      = \n%s", tostring(Event.text)))

    -- Call event function when a marker has changed, i.e. text was entered or changed.
    if Event.id == world.event.S_EVENT_MARK_CHANGE then
        veafMarkers.onEvent(Event, veafMarkers.onEventMarkChangeEventHandlers)
    elseif Event.id == world.event.S_EVENT_MARK_ADDED then
        veafMarkers.onEvent(Event, veafMarkers.onEventMarkAddEventHandlers)
    elseif Event.id == world.event.S_EVENT_MARK_REMOVED then
        veafMarkers.onEvent(Event, veafMarkers.onEventMarkRemoveEventHandlers)
    end
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Event handler functions.
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Function executed when a marker event occurs.
function veafMarkers.onEvent(event, eventHandlersTable)
    local vec3 = nil

    -- Check if marker has a text and the veafMarkers.keyphrase keyphrase.
    if event.text ~= nil then
        -- browse all the event handlers registered for this type of event
        for i = 1, #eventHandlersTable do 

            -- compute the event position if not already done
            if vec3 == nil then
                if veafMarkers.DCSbugfixed then
                    vec3 = {x = event.pos.x, y = event.pos.y, z = event.pos.z}
                else
                    -- Convert (wrong x-->z, z-->x) vec3
                    vec3 = {x = event.pos.z, y = event.pos.y, z = event.pos.x}
                end

                -- By default, alt of mark point is always 5 m! Adjust for the correct ASL height.
                vec3.y = veaf.getLandHeight(vec3)
            end

            -- call the event handler
            local eventHandler = eventHandlersTable[i]
            veaf.loggers.get(veafMarkers.Id):debug("Calling eventHandler #" .. eventHandler.id)
            local err, errmsg = pcall(eventHandler.f, vec3, event)
            if not err then
                veaf.loggers.get(veafMarkers.Id):error('Error in event handler #' .. eventHandler.id .. ' : '.. errmsg)
            end
            veaf.loggers.get(veafMarkers.Id):debug("Returning after eventHandler #" .. eventHandler.id)
        end
    end    
end

--- Register an event handler
-- @tparam function f event handling function (the first parameter is always the event position, and the second is the event)
-- @treturn number event handler id.
function veafMarkers.registerEventHandler(eventType, eventHandler)
    --verify correct types
    assert(type(eventHandler) == 'function', 'variable 1, expected function, got ' .. type(eventHandler))
    if not vars then
        vars = {}
    end
    veafMarkers.eventHandlerId = veafMarkers.eventHandlerId + 1
    if eventType == veafMarkers.MarkerAdd then
        table.insert(veafMarkers.onEventMarkAddEventHandlers, {f = eventHandler, id = veafMarkers.eventHandlerId})
    elseif eventType == veafMarkers.MarkerChange then
        table.insert(veafMarkers.onEventMarkChangeEventHandlers, {f = eventHandler, id = veafMarkers.eventHandlerId})
    elseif eventType == veafMarkers.MarkerRemove then
        table.insert(veafMarkers.onEventMarkRemoveEventHandlers, {f = eventHandler, id = veafMarkers.eventHandlerId})
    else
        -- wrong event type
    end
    return veafMarkers.eventHandlerId
end

function veafMarkers.removeItemFromList(list, id)
    local i = 1
    while i <= #list do
        if list[i].id == id then
            table.remove(list, i)
            return true
        else
            i = i + 1
        end
    end
    return false
end

--- Removes an event handler
-- @tparam number id event handler id
-- @treturn boolean true if event handler was successfully removed, false otherwise.
function veafMarkers.unregisterEventHandler(id)
    local result = veafMarkers.removeItemFromList(veafMarkers.onEventMarkAddEventHandlers, id)
    if not(result) then
        result = veafMarkers.removeItemFromList(veafMarkers.onEventMarkChangeEventHandlers, id)
    end
    if not(result) then
        result = veafMarkers.removeItemFromList(veafMarkers.onEventMarkRemoveEventHandlers, id)
    end
    return result
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- initialisation
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Add event handler.
world.addEventHandler(veafMarkers.eventHandler)

--- Enable/Disable error boxes displayed on screen.
env.setErrorMessageBoxEnabled(false)

veaf.loggers.get(veafMarkers.Id):info(string.format("Loading version %s", veafMarkers.Version))
