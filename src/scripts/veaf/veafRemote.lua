------------------------------------------------------------------
-- VEAF remote callback functions for DCS World
-- By zip (2020)
--
-- Features:
-- ---------
-- * This module offers support for calling script from a web server or a server hook
--
-- See the documentation : https://veaf.github.io/documentation/
------------------------------------------------------------------

veafRemote = {}

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Global settings. Stores the script constants
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Identifier. All output in DCS.log will start with this.
veafRemote.Id = "REMOTE"

-- trace level, specific to this module
--veafRemote.LogLevel = "trace"

veaf.loggers.new(veafRemote.Id, veafRemote.LogLevel)

veafRemote.MIN_LEVEL_FOR_MARKER = 10

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Do not change anything below unless you know what you are doing!
-------------------------------------------------------------------------------------------------------------------------------------------------------------

veafRemote.remoteUsers = {}
veafRemote.remoteUnitsPilots = {}
-- Registry for executeCommandFromRemote() — maps lowercase module name to handler function.
-- Modules register via veafRemote.registerRemoteModule(name, fn).
veafRemote.remoteModuleRegistry = {}

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Utility methods
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Register a remote module handler for executeCommandFromRemote().
-- @param name  lowercase module key (e.g. "air", "point"); may be called multiple times for aliases
-- @param fn    function(parameters) to dispatch to
function veafRemote.registerRemoteModule(name, fn)
  assert(type(name) == "string", "veafRemote.registerRemoteModule: name must be a string")
  assert(type(fn) == "function", "veafRemote.registerRemoteModule: fn must be a function")
  veafRemote.remoteModuleRegistry[name:lower()] = fn
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Remote command execution
-------------------------------------------------------------------------------------------------------------------------------------------------------------

-- VMR-130: the `_remote` marker command, `markTextAnalysis`, `executeRemoteCommand` and the
-- `monitoredCommands` table it read are gone. They were the mission-facing half of the SLMOD
-- bridge: `veafRemote.monitorWithSlMod(command, script, …)` registered a command with SLMOD *and*
-- filled `monitoredCommands` so the script could be run. That registration API was deleted in
-- August 2021 ("removed slmod monitoring altogether"), which left a table nothing could fill, a
-- consumer that could only ever warn, and a `mist.utils.dostring` of arbitrary Lua behind a
-- shared password. `registerRemoteModule` / `executeCommandFromRemote` below is the supported
-- route, and the only one the server hook calls.

-- execute command from the remote interface (see VEAF-server-hook.lua)
function veafRemote.executeCommandFromRemote(username, level, unitName, veafModule, command)
  veaf.loggers.get(veafRemote.Id):debug(
    string.format(
      "veafRemote.executeCommandFromRemote([%s], [%s], [%s], [%s], [%s])",
      veaf.p(username),
      veaf.p(level),
      veaf.p(unitName),
      veaf.p(veafModule),
      veaf.p(command)
    )
  )
  --local _user = veafRemote.getRemoteUser(username)
  --veaf.loggers.get(veafRemote.Id):trace(string.format("_user = [%s]",veaf.p(_user)))
  --if not _user then
  --    return false
  --end
  if not veafModule or not username or not command then
    return false
  end
  local _user = { name = username, level = tonumber(level or "-1") }
  local _parameters = { _user, username, unitName, command }
  local _status, _retval
  local _module = veafModule:lower()
  local handler = veafRemote.remoteModuleRegistry[_module]
  if not handler then
    -- A typing mistake over chat, not a programming fault: `warn` without a traceback, and an answer
    -- to the pilot. Silence made three pilots try four spellings in 90 minutes on private1
    -- (FIX-SECU-VERB-AND-LOG-NOISE ticket 02).
    veaf.loggers.get(veafRemote.Id):warn("[%s] typed an unknown command: [%s]", veaf.p(username), veaf.p(veafModule))
    veafRemote.answerPilot(unitName, veafRemote.describeUnknownModule(_module, command))
    return false
  end
  veaf.loggers.get(veafRemote.Id):debug(string.format("running remote module [%s]", _module))
  _status, _retval = pcall(handler, _parameters)
  veaf.loggers.get(veafRemote.Id):trace(string.format("_status = [%s]", veaf.p(_status)))
  veaf.loggers.get(veafRemote.Id):trace(string.format("_retval = [%s]", veaf.p(_retval)))
  if not _status then
    veaf.loggers.get(veafRemote.Id):error(
      string.format(
        "Error when [%s] tried running [%s] in module [%s]; it returned %s",
        veaf.p(_user.name),
        veaf.p(_parameters),
        veaf.p(veafModule),
        veaf.p(_retval)
      )
    )
  else
    veaf.loggers.get(veafRemote.Id):info(
      string.format(
        "[%s] ran [%s] in module [%s]; it returned %s",
        veaf.p(_user.name),
        veaf.p(_parameters),
        veaf.p(veafModule),
        veaf.p(_retval)
      )
    )
  end
  return _status
end

--- The answer to an unknown chat module: what exists, and the full command when what was typed is the
--- beginning of exactly one module name (`/sec login` → `/secu login`).
---
--- The prefix is suggested, never run: a secured verb reached by a guess would be a verb nobody typed.
--- @param module string the lowercase module the pilot typed
--- @param command string|nil the rest of the pilot's line
--- @return string the message for the pilot
function veafRemote.describeUnknownModule(module, command)
  local names = {}
  local matches = {}
  for name, _ in pairs(veafRemote.remoteModuleRegistry) do
    table.insert(names, name)
    if module ~= "" and name:sub(1, #module) == module then
      table.insert(matches, name)
    end
  end
  table.sort(names)
  local known = "/" .. table.concat(names, ", /")
  if #matches == 1 then
    local suggestion = "/" .. matches[1]
    if command and command ~= "" then
      suggestion = suggestion .. " " .. command
    end
    return veaf.t("remote.unknown_module_suggest", "/" .. module, suggestion, known)
  end
  return veaf.t("remote.unknown_module", "/" .. module, known)
end

--- Show `message` to the pilot in `unitName`, and to nobody else.
---
--- `veaf.outTextForUnit` falls back to a message for **everybody** when the unit does not resolve, which
--- is right for its other callers and wrong for an answer to one pilot's chat line: a spectator's typo
--- would be broadcast to the whole server. A player in no unit is therefore not answered on screen.
--- @param unitName string|nil the unit the hook reported, in any of the shapes `normalizeUnitName` reads
--- @param message string
--- @return boolean true when the message was shown
function veafRemote.answerPilot(unitName, message)
  local unit = veafRemote.normalizeUnitName(unitName)
  if not unit or not Unit.getByName(unit) then
    veaf.loggers.get(veafRemote.Id):debug("no unit to answer [%s] in; not shown", veaf.p(unitName))
    return false
  end
  veaf.outTextForUnit(unit, message, 15)
  return true
end

-- register a user from the server
function veafRemote.registerUser(username, userpower, ucid)
  veaf.loggers
    .get(veafRemote.Id)
    :debug(string.format("veafRemote.registerUser([%s], [%s], [%s])", veaf.p(username), veaf.p(userpower), veaf.p(ucid)))
  if not username or not ucid then
    return false
  end
  local level = tonumber(userpower or "-1")
  local remoteUser = veafRemote.remoteUsers[username:lower()]
  if remoteUser then
    -- Updated in place, never replaced: `remoteUnitsPilots` holds this same table for the unit the player
    -- sits in, and a new one left that entry with the old level — which is how a listed pilot stayed at
    -- level 0 on private1 whatever they typed (FIX-SECU-VERB-AND-LOG-NOISE ticket 01).
    remoteUser.name = username
    remoteUser.level = level
    remoteUser.ucid = ucid
  else
    veafRemote.remoteUsers[username:lower()] = { name = username, level = level, ucid = ucid }
  end
end

--- The unit a slot payload actually names, or nil when it names none.
---
--- The server hook used to send `tostring(unitName or "nil")` for a player in no unit — the
--- four-character **string**, which is truthy in Lua, so a guard reading `if not unitName` never fired
--- and the player was registered as occupying a unit called `nil`
--- (FIX-REMOTE-SLOT-NIL-UNIT). The hook sends an empty string now, but this has to keep reading the old
--- payload: the hook is deployed **by hand**, server by server, with no pipeline, so a mission built
--- from a newer framework meets an older hook for as long as it takes someone to copy a file.
---
--- The trade, stated rather than hidden: a unit genuinely named `nil` is indistinguishable from absence.
--- That is the price of accepting the old payload, and no mission has ever been seen to pay it.
---
--- A value that is neither nil nor a string is reported: the hook always sends a string through `%q`, so
--- anything else is a caller's mistake, and reading it as "no unit" in silence would be the same shape of
--- defect this whole lot is about. It still answers nil, which is the safe conduct.
---
--- @param unitName the third value of a slot payload; nil is tolerated
--- @return the unit name, or nil for nil, an empty or blank string, or the literal "nil"
function veafRemote.normalizeUnitName(unitName)
  if unitName ~= nil and type(unitName) ~= "string" then
    veaf.loggers.get(veafRemote.Id):warn("normalizeUnitName got a %s instead of a unit name; reading it as no unit", veaf.p(type(unitName)))
    return nil
  end
  if unitName == nil then
    return nil
  end
  local trimmed = unitName:match("^%s*(.-)%s*$")
  if trimmed == "" or trimmed:lower() == "nil" then
    return nil
  end
  return trimmed
end

--- Register a user slot from the server; called when the player changes slot.
---
--- `level` is the pilot's level from `veaf-pilots.txt`, sent by the hook with the slot since
--- FIX-SECU-VERB-AND-LOG-NOISE: a mission loaded while a player stays connected never hears their
--- `onPlayerConnect`, so the slot is the first thing it learns of them. An older hook sends three values,
--- and then the level already registered, if any, is kept.
--- @param username string the player name
--- @param ucid string|nil the player's UCID
--- @param unitName string|nil the unit the player now occupies, in any shape `normalizeUnitName` reads
--- @param level string|number|nil the player's level, when the hook sends it
function veafRemote.registerUserSlot(username, ucid, unitName, level)
  veaf.loggers.get(veafRemote.Id):debug(
    string.format("veafRemote.registerUserSlot([%s], [%s], [%s], [%s])", veaf.p(username), veaf.p(ucid), veaf.p(unitName), veaf.p(level))
  )
  if not username then
    return false
  end
  local remoteUser = veafRemote.remoteUsers[username:lower()]
  if not remoteUser then
    -- Kept in `remoteUsers`, so that a later `registerUser` updates this very table — the one the unit
    -- entry below points to. It used to be a throwaway, and nothing could repair the unit afterwards.
    remoteUser = { name = username, ucid = ucid }
    veafRemote.remoteUsers[username:lower()] = remoteUser
  end
  local slotLevel = tonumber(level)
  if slotLevel then
    remoteUser.level = slotLevel
  end
  -- "occupies nothing" is represented by **absence**, which is what the code always claimed to do
  local occupiedUnit = veafRemote.normalizeUnitName(unitName)
  if occupiedUnit and remoteUser.level == nil then
    veaf.loggers.get(veafRemote.Id):warn(
      "[%s] took [%s] with no known level; secured commands are refused until the server hook sends one",
      veaf.p(username),
      veaf.p(occupiedUnit)
    )
  end
  local previousUnit = remoteUser.unitName
  remoteUser.unitName = occupiedUnit -- nil when the player got out of his unit
  -- unregister the previous unit, if any
  if previousUnit then
    veafRemote.remoteUnitsPilots[previousUnit] = nil
  end
  -- register the current unit, if any
  if occupiedUnit then
    veafRemote.remoteUnitsPilots[occupiedUnit] = remoteUser
  end
end

-- return a user from the server table
function veafRemote.getRemoteUser(username)
  veaf.loggers.get(veafRemote.Id):debug(string.format("veafRemote.getRemoteUser([%s])", veaf.p(username)))
  veaf.loggers.get(veafRemote.Id):trace(string.format("veafRemote.remoteUsers = [%s]", veaf.p(veafRemote.remoteUsers)))
  if not username then
    return nil
  end
  return veafRemote.remoteUsers[username:lower()]
end

-- return a user from the server units table
function veafRemote.getRemoteUserFromUnit(unitName)
  veaf.loggers.get(veafRemote.Id):debug(string.format("veafRemote.getRemoteUserFromUnit([%s])", veaf.p(unitName)))
  veaf.loggers.get(veafRemote.Id):trace(string.format("veafRemote.remoteUnitsPilots = [%s]", veaf.p(veafRemote.remoteUnitsPilots)))
  if not unitName then
    return nil
  end
  return veafRemote.remoteUnitsPilots[unitName]
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- initialisation
-------------------------------------------------------------------------------------------------------------------------------------------------------------

function veafRemote.initialize()
  veaf.loggers.get(veafRemote.Id):info("Initializing module")
  -- No marker command handler is registered any more, and that is deliberate.
  --
  -- This module used to answer marker text carrying a shared password, through
  -- `veafRemote.executeCommand`. That mechanism was removed on 2026-08-11 (9a20c50c, the security
  -- review) in favour of `registerRemoteModule` / `executeCommandFromRemote`, which authenticates a
  -- named user instead of trusting a string typed on the map. The handler registration was left
  -- behind, so from that day every marker carrying any text at all raised
  -- "attempt to call field 'executeCommand' (a nil value)": `veafMarkers.onEvent` calls every
  -- registered handler under `pcall`, so a pilot dropping a plain annotation was told
  -- "VEAF: your marker command failed". Eleven days, reported in game on 2026-08-22.
end

veaf.loggers.get(veafRemote.Id):info(veaf.loggers.get(veafRemote.Id):getVersionInfo())

veaf.registerModule(veafRemote.Id, veafRemote.initialize, { enable = true }, 230)
