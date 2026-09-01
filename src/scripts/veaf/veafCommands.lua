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
--- (`veaf-pilots.txt` via `veafRemote.registerUser`). There is no global `/login` any more:
--- REVIEW-SECURITY-LAYER removed it, because one player's login opened every secured command
--- to everybody on the server for `authDuration` minutes.
---
--- The names are the ones REVIEW-SECURITY-LAYER decision b settled on (2026-08-08). The old
--- L0/L1/L9 spellings read backwards — L0 was the *tightest* tier — and are kept as aliases for
--- one release. `ADMIN` is the tightest, `KNOWN_PILOT` the loosest (any listed VEAF pilot): a
--- check passes when the pilot's level is **at least** the constant, and `LEVEL_ADMIN` is 90
--- against `LEVEL_KNOWN_PILOT`'s 1.
veafCommands.SECURITY_CHECKS = {
  ADMIN = function(markId)
    return veafSecurity.checkSecurity_L0(nil, markId)
  end,
  SENIOR_PILOT = function(markId)
    return veafSecurity.checkSecurity_L1(nil, markId)
  end,
  KNOWN_PILOT = function(markId)
    return veafSecurity.checkSecurity_L9(nil, markId)
  end,
  --- Deliberately open to everyone. Says so, rather than saying nothing.
  OPEN = function()
    return true
  end,
}

--- Deprecated spellings, aliased to the **same** function rather than to a copy of it: two copies
--- is how one of two paths receives tomorrow's fix. Listed here rather than derived from
--- `veafSecurity.DEPRECATED_LEVEL_NAMES` because that table is read at load time, and this file
--- does not require veafSecurity to be loaded first.
veafCommands.SECURITY_CHECKS.L0 = veafCommands.SECURITY_CHECKS.ADMIN
veafCommands.SECURITY_CHECKS.L1 = veafCommands.SECURITY_CHECKS.SENIOR_PILOT
veafCommands.SECURITY_CHECKS.L9 = veafCommands.SECURITY_CHECKS.KNOWN_PILOT

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
--                 veafCommands.SECURITY_CHECKS ("ADMIN"/"SENIOR_PILOT"/"KNOWN_PILOT"/"OPEN", or
--                 the deprecated "L0"/"L1"/"L9"). There is no default: a handler that does not
--                 say what it needs does not get registered.
-- @param keyphrase string — OPTIONAL but strongly advised: the marker text this handler answers to
--                 (e.g. "_move"). Without it the dispatcher must check this handler's security for
--                 **every** marker carrying text, so a pilot annotating the map with "RDV ici" was
--                 told to give the L1 password once per tiered handler. Declaring it lets the
--                 dispatcher skip the handler before checking anything.
function veafCommands.registerCommandHandler(fn, priority, security, keyphrase)
  assert(type(fn) == "function", "veafCommands.registerCommandHandler: fn must be a function")
  assert(type(priority) == "number", "veafCommands.registerCommandHandler: priority must be a number")
  assert(
    security == veafCommands.SECURITY_HANDLED or veafCommands.SECURITY_CHECKS[security] ~= nil,
    "veafCommands.registerCommandHandler: security must be veafCommands.SECURITY_HANDLED or one of "
      .. "ADMIN/SENIOR_PILOT/KNOWN_PILOT/OPEN — a handler with no declared security level is refused, "
      .. "because forgetting one used to mean the command ran for anyone"
  )
  -- An old spelling still works, and says so once. Guarded on veafSecurity because a handler may
  -- register before that module is loaded, and a missing deprecation notice must never be the
  -- reason a mission fails to load.
  if veafSecurity and veafSecurity.DEPRECATED_LEVEL_NAMES and veafSecurity.DEPRECATED_LEVEL_NAMES[security] then
    veafSecurity.levelForName(security)
  end
  local i = 1
  while i <= #veafCommands.commandHandlers and veafCommands.commandHandlers[i].priority <= priority do
    i = i + 1
  end
  table.insert(veafCommands.commandHandlers, i, {
    fn = fn,
    priority = priority,
    security = security,
    -- An empty string is normalised to nil rather than kept: `find("", 1, true)` returns 1, so an
    -- empty keyphrase would match every text while looking like a filter. Same outcome as declaring
    -- none, but said explicitly instead of reached by accident (Sourcery, PR #735).
    keyphrase = (type(keyphrase) == "string" and keyphrase ~= "") and keyphrase:lower() or nil,
  })
  veaf.loggers.get(veafCommands.Id):debug("registered handler at priority %d (position %d), security %s", priority, i, security)
end

--- Does this handler answer to this marker text?
---
--- A handler that declared no keyphrase answers to everything, which is today's behaviour and keeps
--- the change additive while the callers are migrated one at a time.
---@return boolean
function veafCommands.handlesText(entry, text)
  if not entry.keyphrase then
    return true
  end
  if type(text) ~= "string" then
    return false
  end
  return text:lower():find(entry.keyphrase, 1, true) ~= nil
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
    -- Recognition BEFORE security. Checking first meant every handler whose tier the pilot lacked
    -- printed a refusal for a command it would never have handled: a marker reading "RDV ici" earned
    -- two "give the L1 password" messages, and a refused `_transport` three (David, in game
    -- 2026-08-14). Matching mirrors what the modules do themselves: `text:lower():find(Keyphrase)`.
    if
      veafCommands.handlesText(entry, event and event.text)
      and veafCommands.isAllowed(entry, event, false)
      and entry.fn(eventPos, event, false, true, nil, nil)
    then
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

-- Priority 15: after veafMarkers (4) and veafEventHandler (10), before all command modules.
--
-- That is the intent, not what happens. This module has no declared place in the generator's own
-- order (`_MODULE_INIT_ORDER` in `lua_config_generator.py`), so the generated `veaf-config.lua`
-- calls it from the unordered bucket, near-last — after every command module's `initialize()`.
-- Harmless today: a command module registers through `veafCommands.registerCommandHandler`, which
-- only inserts into a table declared at load, and this `initialize()` does nothing but install the
-- central marker handler. Reconciling the two orders belongs to the lot that makes the generated
-- config call `veaf.initialize()`. See docs/agents/module-initialisation.md.
veaf.registerModule(veafCommands.Id, veafCommands.initialize, { enable = true }, 15)
