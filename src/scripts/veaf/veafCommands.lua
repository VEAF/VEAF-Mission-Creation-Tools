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

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Security declarations — every handler states one, and there is no way not to.
--
-- The dispatcher used to delegate the security decision to each handler, which meant a
-- handler that simply did not check was wide open and nothing noticed. Four of the nine
-- had drifted that way (SECREV-2, finding VMR-003 and its three unreported siblings), so
-- the level is now an argument with no default: forgetting it is an error at load time
-- instead of an open door at run time.
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- The handler performs its own security check, from a password in the marker text.
--- The dispatcher must not check as well, because it does not parse the text and so has
--- no password to check with. Declaring this is a claim the handler has to honour; it is
--- deliberately a distinct value from a level, so "checks itself" and "forgot" can never
--- look the same in a diff.
veafCommands.SECURITY_HANDLED = "handled-by-handler"

--- Levels the dispatcher enforces itself, before the handler runs.
---
--- These carry no password: the handlers using them never parsed one, so the check is on
--- identity alone — the pilot level the server hook published for whoever placed the mark
--- (`veaf-pilots.txt` via `veafRemote.registerUser`), or a global `/login`.
---
--- Note the ordering, which is not what the names suggest: `veafSecurity.LEVEL_L9` is 1
--- and `LEVEL_L0` is 90, and a check passes when the pilot's level is **at least** the
--- constant. L9 is therefore the loosest tier (any listed VEAF pilot) and L0 the tightest.
veafCommands.SECURITY_CHECKS = {
  L0 = function(markId)
    return veafSecurity.checkSecurity_L0(nil, markId)
  end,
  L1 = function(markId)
    return veafSecurity.checkSecurity_L1(nil, markId)
  end,
  L9 = function(markId)
    return veafSecurity.checkSecurity_L9(nil, markId)
  end,
  --- Deliberately open to everyone. Says so, rather than saying nothing.
  OPEN = function()
    return true
  end,
}

-- Ordered list of registered command handlers.
-- Each entry: { fn = function, priority = number, security = string }
veafCommands.commandHandlers = {}

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Public API
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Register a text command handler.
-- @param fn       function(pos, event, bypassSecurity, fromMarker, spawnedGroups, route) -> bool
-- @param priority number — lower values are tried first (use PRIORITY_* constants)
-- @param security string — REQUIRED. Either veafCommands.SECURITY_HANDLED, or a key of
--                 veafCommands.SECURITY_CHECKS ("L0"/"L1"/"L9"/"OPEN"). There is no default:
--                 a handler that does not say what it needs does not get registered.
function veafCommands.registerCommandHandler(fn, priority, security)
  assert(type(fn) == "function", "veafCommands.registerCommandHandler: fn must be a function")
  assert(type(priority) == "number", "veafCommands.registerCommandHandler: priority must be a number")
  assert(
    security == veafCommands.SECURITY_HANDLED or veafCommands.SECURITY_CHECKS[security] ~= nil,
    "veafCommands.registerCommandHandler: security must be veafCommands.SECURITY_HANDLED or one of "
      .. "L0/L1/L9/OPEN — a handler with no declared security level is refused, because forgetting "
      .. "one used to mean the command ran for anyone"
  )
  local i = 1
  while i <= #veafCommands.commandHandlers and veafCommands.commandHandlers[i].priority <= priority do
    i = i + 1
  end
  table.insert(veafCommands.commandHandlers, i, { fn = fn, priority = priority, security = security })
  veaf.loggers.get(veafCommands.Id):debug("registered handler at priority %d (position %d), security %s", priority, i, security)
end

--- Is this handler allowed to run for this event?
---
--- Returns true for a handler that checks itself, and for anything on the bypass path —
--- the interpreter runs unit-name commands at mission start, which are authored by the
--- mission maker rather than typed by a player.
---@return boolean
function veafCommands.isAllowed(entry, event, bypassSecurity)
  if bypassSecurity or entry.security == veafCommands.SECURITY_HANDLED then
    return true
  end
  local check = veafCommands.SECURITY_CHECKS[entry.security]
  if not check then
    -- Registration refuses an unknown level, so reaching this means the table was edited
    -- at run time. Deny: an unrecognised level is not a reason to allow.
    veaf.loggers.get(veafCommands.Id):error("unknown security level [%s] — denying", tostring(entry.security))
    return false
  end
  return check(event and event.idx or nil) == true
end

--- Dispatch a DCS marker event through the registry.
-- Called by the single central veafMarkers handler registered in initialize().
-- @return bool  true if a handler consumed the event (mark will be removed by caller)
function veafCommands.dispatchMarker(eventPos, event)
  veaf.loggers.get(veafCommands.Id):debug("dispatchMarker(text=[%s])", tostring(event.text))
  for _, entry in ipairs(veafCommands.commandHandlers) do
    if veafCommands.isAllowed(entry, event, false) and entry.fn(eventPos, event, false, true, nil, nil) then
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
    -- Always true on this path, since the interpreter bypasses security by design. Routed
    -- through the same call anyway so that "every dispatch consults isAllowed" holds without
    -- exception, and a later change to the bypass cannot quietly skip the gate here.
    if veafCommands.isAllowed(entry, event, true) and entry.fn(pos, event, true, false, spawnedGroups, route) then
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
