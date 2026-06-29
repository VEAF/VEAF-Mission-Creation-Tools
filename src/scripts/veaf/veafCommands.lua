------------------------------------------------------------------
-- VEAF central text command dispatcher for DCS World
-- By Zip (2025)
--
-- Features:
-- ---------
-- * Centralises textual command dispatch (marker events and interpreter)
--   behind a single ordered registry so modules self-register instead
--   of being hardcoded in veafInterpreter and eight separate marker handlers.
--
-- Usage:
-- * In a module's initialize(), call veafCommands.registerCommandHandler(fn, priority)
-- * fn(pos, event, bypassSecurity, fromMarker, spawnedGroups, route) -> bool
--   - pos          : vec3 position
--   - event        : table { text, coalition, idx } (real DCS event or constructed)
--   - bypassSecurity : true when called from the interpreter (trusted context)
--   - fromMarker   : true when dispatched from a DCS marker event
--   - spawnedGroups: may be nil (only provided by the interpreter)
--   - route        : may be nil (only provided by the interpreter)
--
-- See the documentation : https://veaf.github.io/documentation/
------------------------------------------------------------------

veafCommands = {}

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Global settings. Stores the script constants
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Identifier. All output in DCS.log will start with this.
veafCommands.Id = "COMMANDS"

-- trace level, specific to this module (uncomment for debugging)
--veafCommands.LogLevel = "trace"

veaf.loggers.new(veafCommands.Id, veafCommands.LogLevel)

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Dispatch priority constants — lower value = earlier in the chain.
-- Order reproduces the legacy veafInterpreter.execute() if/elseif sequence.
-------------------------------------------------------------------------------------------------------------------------------------------------------------

veafCommands.PRIORITY_SHORTCUTS = 10
veafCommands.PRIORITY_SPAWN = 20
veafCommands.PRIORITY_NAMEDPOINTS = 30
veafCommands.PRIORITY_CASMISSION = 40
veafCommands.PRIORITY_SECURITY = 50
veafCommands.PRIORITY_MOVE = 60
veafCommands.PRIORITY_GROUNDAI = 62
veafCommands.PRIORITY_RADIO = 70
veafCommands.PRIORITY_REMOTE = 80

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Do not change anything below unless you know what you are doing!
-------------------------------------------------------------------------------------------------------------------------------------------------------------

-- Ordered list of registered command handlers.
-- Each entry: { fn = function, priority = number }
veafCommands.commandHandlers = {}

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Public API
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Register a text command handler.
-- @param fn       function(pos, event, bypassSecurity, fromMarker, spawnedGroups, route) -> bool
-- @param priority number — lower values are tried first (use PRIORITY_* constants)
function veafCommands.registerCommandHandler(fn, priority)
  assert(type(fn) == "function", "veafCommands.registerCommandHandler: fn must be a function")
  assert(type(priority) == "number", "veafCommands.registerCommandHandler: priority must be a number")
  local i = 1
  while i <= #veafCommands.commandHandlers and veafCommands.commandHandlers[i].priority <= priority do
    i = i + 1
  end
  table.insert(veafCommands.commandHandlers, i, { fn = fn, priority = priority })
  veaf.loggers.get(veafCommands.Id):debug("registered handler at priority %d (position %d)", priority, i)
end

--- Dispatch a DCS marker event through the registry.
-- Called by the single central veafMarkers handler registered in initialize().
-- @return bool  true if a handler consumed the event (mark will be removed by caller)
function veafCommands.dispatchMarker(eventPos, event)
  veaf.loggers.get(veafCommands.Id):debug("dispatchMarker(text=[%s])", tostring(event.text))
  for _, entry in ipairs(veafCommands.commandHandlers) do
    if entry.fn(eventPos, event, false, true, nil, nil) then
      return true
    end
  end
  return false
end

--- Dispatch a text command from veafInterpreter (unit-name commands at mission start).
-- @param pos      vec3 position
-- @param text     command text
-- @param coalition coalition of the unit carrying the interpreter command
-- @param spawnedGroups optional table accumulating spawned groups
-- @param route    optional route table
-- @return bool
function veafCommands.execute(pos, text, coalition, spawnedGroups, route)
  veaf.loggers.get(veafCommands.Id):debug("execute(text=[%s])", tostring(text))
  local event = { text = text, coalition = coalition, idx = nil }
  for _, entry in ipairs(veafCommands.commandHandlers) do
    if entry.fn(pos, event, true, false, spawnedGroups, route) then
      return true
    end
  end
  return false
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- initialisation
-------------------------------------------------------------------------------------------------------------------------------------------------------------

function veafCommands.initialize()
  veaf.loggers.get(veafCommands.Id):info("Initializing module")
  -- Register the single central marker handler that replaces the eight
  -- per-module onEventMarkChange functions.
  veafMarkers.registerEventHandler(veafMarkers.MarkerChange, function(eventPos, event)
    if veafCommands.dispatchMarker(eventPos, event) then
      veaf.loggers.get(veafCommands.Id):trace("Removing mark #%d", event.idx)
      trigger.action.removeMark(event.idx)
    end
  end)
end

veaf.loggers.get(veafCommands.Id):info(veaf.loggers.get(veafCommands.Id):getVersionInfo())

-- Priority 15: after veafEventHandler (10) and veafMarkers (no explicit order, loads early),
-- before all command modules so they can call registerCommandHandler in their own initialize().
veaf.registerModule(veafCommands.Id, veafCommands.initialize, { enable = true }, 15)
