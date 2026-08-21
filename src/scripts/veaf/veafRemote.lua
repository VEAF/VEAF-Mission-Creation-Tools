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
-- NIOD callbacks
-------------------------------------------------------------------------------------------------------------------------------------------------------------

function veafRemote.addNiodCallback(name, parameters, code)
  if niod then
    veaf.loggers.get(veafRemote.Id):info("Adding NIOD function " .. name)
    niod.functions[name] = function(payload)
      -- start of inline function

      veaf.loggers.get(veafRemote.Id):debug(string.format("niod callback [%s] was called with payload %s", veaf.p(name), veaf.p(payload)))

      local errors = {}

      -- check mandatory parameters presence
      for parameterName, parameterData in pairs(parameters) do
        veaf.loggers.get(veafRemote.Id):trace(string.format("checking if parameter [%s] is mandatory", veaf.p(parameterName)))
        if parameterData and parameterData.mandatory then
          if not (payload and payload[parameterName]) then
            local text = "missing mandatory parameter " .. parameterName
            veaf.loggers.get(veafRemote.Id):trace(text)
            table.insert(errors, text)
          end
        end
      end

      -- check parameters type
      if payload then
        for parameterName, value in pairs(payload) do
          local parameter = parameters[parameterName]
          if not parameter then
            table.insert(errors, "unknown parameter " .. parameterName)
          elseif value and not (type(value) == parameter.type) then
            local text = string.format("parameter %s should have type %s, has %s ", parameterName, parameter.type, type(value))
            veaf.loggers.get(veafRemote.Id):trace(text)
            table.insert(errors, text)
          end
        end
      end

      -- stop on error
      if #errors > 0 then
        local errorMessage = ""
        for _, error in pairs(errors) do
          errorMessage = errorMessage .. "\n" .. error
        end
        veaf.loggers
          .get(veafRemote.Id)
          :error(string.format("niod callback [%s] was called with incorrect parameters :", veaf.p(name), errorMessage))
        return errorMessage
      else
        veaf.loggers.get(veafRemote.Id):trace(string.format("payload = %s", veaf.p(payload)))
        veaf.loggers.get(veafRemote.Id):trace(string.format("unpacked payload = %s", veaf.p(veaf.safeUnpack(payload))))
        local status, retval = pcall(code, veaf.safeUnpack(payload))
        if status then
          return retval
        else
          return "an error occured : " .. veaf.p(status)
        end
      end
    end -- of inline function
  else
    veaf.loggers.get(veafRemote.Id):error("NIOD is not loaded !")
  end
end

function veafRemote.addNiodCommand(name, command)
  veafRemote.addNiodCallback(name, {
    parameters = { mandatory = false, type = "string" },
    x = { mandatory = false, type = "number" },
    y = { mandatory = false, type = "number" },
    z = { mandatory = false, type = "number" },
    silent = { mandatory = false, type = "boolean" },
  }, function(parameters, x, y, z, silent)
    veaf.loggers
      .get(veafRemote.Id)
      :debug(string.format("niod->command %s (%s, %s, %s, %s, %s)", veaf.p(parameters), veaf.p(x), veaf.p(y), veaf.p(z), veaf.p(silent)))
    return veafRemote.executeCommand({ x = x or 0, y = y or 0, z = z or 0 }, command .. parameters)
  end)
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- default endpoints list
-------------------------------------------------------------------------------------------------------------------------------------------------------------

function veafRemote.buildDefaultList()
  local TEST = false
  if TEST then
    -- test
    veafRemote.addNiodCallback("test", {
      param1S_M = { mandatory = true, type = "string" },
      param2S = { mandatory = false, type = "string" },
      param3N = { mandatory = false, type = "number" },
      param4B = { mandatory = false, type = "boolean" },
    }, function(param1S_M, param2S, param3N, param4B)
      local text = string.format("niod.test(%s, %s, %s, %s)", veaf.p(param1S_M), veaf.p(param2S), veaf.p(param3N), veaf.p(param4B))
      veaf.loggers.get(veafRemote.Id):debug(text)
      trigger.action.outText(text, 15)
    end)
    -- login
    veafRemote.addNiodCallback("login", {
      password = { mandatory = true, type = "string" },
      timeout = { mandatory = false, type = "number" },
      silent = { mandatory = false, type = "boolean" },
    }, function(password, timeout, silent)
      veaf.loggers.get(veafRemote.Id):debug(string.format("niod.login(%s, %s, %s)", veaf.p(password), veaf.p(timeout), veaf.p(silent))) -- TODO remove password from log
      if veafSecurity.checkPassword_L1(password) then
        veafSecurity.authenticate(timeout)
        return "Mission is unlocked"
      else
        return "wrong password"
      end
    end)
  end
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
    veaf.loggers.get(veafRemote.Id):error(string.format("Module not found : [%s]", veaf.p(veafModule)))
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

-- register a user from the server
function veafRemote.registerUser(username, userpower, ucid)
  veaf.loggers
    .get(veafRemote.Id)
    :debug(string.format("veafRemote.registerUser([%s], [%s], [%s])", veaf.p(username), veaf.p(userpower), veaf.p(ucid)))
  if not username or not ucid then
    return false
  end
  veafRemote.remoteUsers[username:lower()] = { name = username, level = tonumber(userpower or "-1"), ucid = ucid }
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

-- register a user slot from the server; called when the player changes slot
function veafRemote.registerUserSlot(username, ucid, unitName)
  veaf.loggers
    .get(veafRemote.Id)
    :debug(string.format("veafRemote.registerUserSlot([%s], [%s], [%s])", veaf.p(username), veaf.p(ucid), veaf.p(unitName)))
  if not username then
    return false
  end
  local remoteUser = veafRemote.remoteUsers[username:lower()]
  if not remoteUser then
    remoteUser = { name = username, ucid = ucid }
  end
  -- "occupies nothing" is represented by **absence**, which is what the code always claimed to do
  local occupiedUnit = veafRemote.normalizeUnitName(unitName)
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
  veafRemote.buildDefaultList()
  veafCommands.registerCommandHandler(function(pos, event, bypass, fromMarker, groups, route)
    return veafRemote.executeCommand(pos, event.text)
  end, veafCommands.PRIORITY_REMOTE, veafCommands.SECURITY_HANDLED)
end

veaf.loggers.get(veafRemote.Id):info(veaf.loggers.get(veafRemote.Id):getVersionInfo())

veaf.registerModule(veafRemote.Id, veafRemote.initialize, { enable = true }, 230)
