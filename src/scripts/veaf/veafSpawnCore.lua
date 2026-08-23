------------------------------------------------------------------
-- VEAF spawn command and functions for DCS World
-- By zip (2018)
--
-- Features:
-- ---------
-- * Listen to marker change events and execute spawn commands, with optional parameters
-- * Possibilities :
-- *    - spawn a specific ennemy unit or group
-- *    - create a cargo drop to be picked by a helo
--
-- See the documentation : https://veaf.github.io/documentation/
------------------------------------------------------------------

--- veafSpawn Table.
veafSpawn = {}

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Global settings. Stores the script constants
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Identifier. All output in DCS.log will start with this.
veafSpawn.Id = "SPAWN"

-- trace level, specific to this module (uncomment for debugging)
--veafSpawn.LogLevel = "trace"

veaf.loggers.new(veafSpawn.Id, veafSpawn.LogLevel)

--- Key phrase to look for in the mark text which triggers the spawn command.
veafSpawn.SpawnKeyphrase = "_spawn"

--- Key phrase to look for in the mark text which triggers the destroy command.
veafSpawn.DestroyKeyphrase = "_destroy"

--- Key phrase to look for in the mark text which triggers the teleport command.
veafSpawn.TeleportKeyphrase = "_teleport"

--- Key phrase to look for in the mark text which triggers the drawing commands.
veafSpawn.DrawingKeyphrase = "_drawing"

--- Key phrase to look for in the mark text which triggers the mission master commands.
veafSpawn.MissionMasterKeyphrase = "_mm"

--- Illumination flare default initial altitude (in meters AGL)
veafSpawn.IlluminationFlareAglAltitude = 1000

veafSpawn.RadioMenuName = "menu.spawn.root"
veafSpawn.HideRadioMenu = false

--- static object type spawned when using the "logistic" keyword
veafSpawn.LogisticUnitType = "FARP Ammo Dump Coating"
veafSpawn.LogisticUnitCategory = "Fortifications"

veafSpawn.ShellingInterval = 5 -- seconds between shells, randomized by 30%
veafSpawn.FlakingInterval = 2 -- seconds between flak shells, randomized by 30%
veafSpawn.IlluminationShellingInterval = 45 -- seconds between illumination shells, randomized by 30%

veafSpawn.MIN_REPEAT_DELAY = 5

veafSpawn.AirUnitTemplatesPrefix = "veafSpawn-"

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Do not change anything below unless you know what you are doing!
-------------------------------------------------------------------------------------------------------------------------------------------------------------

veafSpawn.rootPath = nil

-- counts the units generated
veafSpawn.spawnedUnitsCounter = 0

-- store all the convoys spawned
veafSpawn.spawnedConvoys = {}

-- store all the air units templates (groups, actually)
veafSpawn.airUnitTemplates = {}

-- all the named groups that have been spawned
veafSpawn.spawnedNamesIndex = {}

-- time delay between the watchdog checks for each CAP
veafSpawn.CAP_WATCHDOG_DELAY = 10

-- range scale of cargo weight biases
veafSpawn.cargoWeightBiasRange = 6

--AFAC related base data
veafSpawn.AFAC = {}
-- number of AFAC spawned
veafSpawn.AFAC.numberSpawned = {}
veafSpawn.AFAC.numberSpawned[coalition.side.BLUE] = nil
veafSpawn.AFAC.numberSpawned[coalition.side.RED] = nil
-- maximum number of AFACs allowed for spawning by players
veafSpawn.AFAC.maximumAmount = 8
-- base frequency for the first AFAC spawned
veafSpawn.AFAC.baseAFACfrequency = {}
veafSpawn.AFAC.baseAFACfrequency[coalition.side.BLUE] = 226300000 -- 226.300000 MHz otherwise known as 226300000 Hz
veafSpawn.AFAC.baseAFACfrequency[coalition.side.RED] = 226300000 -- 226.300000 MHz otherwise known as 226300000 Hz
-- callsign list of the AFACs
veafSpawn.AFAC.callsigns = {}
veafSpawn.AFAC.callsigns[coalition.side.BLUE] = {
  [1] = { name = "Enfield 9 1", taken = false },
  [2] = { name = "Springfield 9 1", taken = false },
  [3] = { name = "Uzi 9 1", taken = false },
  [4] = { name = "Colt 9 1", taken = false },
  [5] = { name = "Dodge 9 1", taken = false },
  [6] = { name = "Ford 9 1", taken = false },
  [7] = { name = "Chevy 9 1", taken = false },
  [8] = { name = "Pontiac 9 1", taken = false },
}
veafSpawn.AFAC.callsigns[coalition.side.RED] = {
  [1] = { name = "181", taken = false },
  [2] = { name = "281", taken = false },
  [3] = { name = "381", taken = false },
  [4] = { name = "481", taken = false },
  [5] = { name = "581", taken = false },
  [6] = { name = "681", taken = false },
  [7] = { name = "781", taken = false },
  [8] = { name = "881", taken = false },
}
-- AFAC mission data as MIST isn't able to recover it from dynamically spawned aircrafts
veafSpawn.AFAC.missionData = {}
veafSpawn.AFAC.missionData[coalition.side.BLUE] = {}
veafSpawn.AFAC.missionData[coalition.side.RED] = {}

veafSpawn.traceMarkerId = 3727

-- Registry mapping option-key strings to handler functions registered by sub-modules.
veafSpawn.commandHandlers = {} -- ordered list: { {key=string, fn=function}, ... }

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Utility methods
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Security levels recognized by the command dispatcher; mapped to a veafSecurity
--- check applied centrally before a handler runs (nil = no check needed).
---
--- The tier names are the ones REVIEW-SECURITY-LAYER decision b settled on (2026-08-08);
--- `KNOWN_PILOT` is the loosest and `ADMIN` the tightest. `MM` and `OPEN` are deliberately not
--- tiers: a Mission Master password carries no level, and OPEN means *no check*.
veafSpawn.SECURITY_CHECKS = {
  KNOWN_PILOT = function(options, markId)
    return veafSecurity.checkSecurity_L9(options.password, markId)
  end,
  SENIOR_PILOT = function(options, markId)
    return veafSecurity.checkSecurity_L1(options.password, markId)
  end,
  ADMIN = function(options, markId)
    return veafSecurity.checkSecurity_L0(options.password, markId)
  end,
  MM = function(options, markId)
    return veafSecurity.checkSecurity_MM(options.password)
  end,
  --- Deliberately available to everyone. Exists so that "open" is something a command
  --- states, rather than something it achieves by leaving the level out.
  OPEN = function()
    return true
  end,
}

--- Deprecated spellings, aliased to the **same** function rather than to a copy of it: two copies
--- is how one of two paths receives tomorrow's fix. Kept for one release. Listed here rather than
--- derived from `veafSecurity.DEPRECATED_LEVEL_NAMES`, which would need that module loaded first.
veafSpawn.SECURITY_CHECKS.L0 = veafSpawn.SECURITY_CHECKS.ADMIN
veafSpawn.SECURITY_CHECKS.L1 = veafSpawn.SECURITY_CHECKS.SENIOR_PILOT
veafSpawn.SECURITY_CHECKS.L9 = veafSpawn.SECURITY_CHECKS.KNOWN_PILOT

--- Register a command handler for executeCommand().
-- @param key       options field name that activates this handler (e.g. "unit", "farp")
-- @param security  REQUIRED level ("KNOWN_PILOT"/"SENIOR_PILOT"/"ADMIN", or the deprecated
--                  "L9"/"L1"/"L0"), "MM" for the Mission Master password, or "OPEN" for a command
--                  deliberately available to everyone. The 2-arg form (key, fn) is no longer
--                  accepted: it meant "no check", so omitting the level and forgetting it looked
--                  the same, which is the shape SECREV-2 set out to remove.
-- @param fn        function(eventPos, options, coalition, markId, bypassSecurity) -> spawnedGroup, routeDone, abort
function veafSpawn.registerCommandHandler(key, security, fn)
  assert(
    type(fn) == "function",
    "veafSpawn.registerCommandHandler("
      .. tostring(key)
      .. "): fn must be a function — the 2-argument form (key, fn) meant 'no security check' and is gone"
  )
  assert(
    veafSpawn.SECURITY_CHECKS[security] ~= nil,
    "veafSpawn.registerCommandHandler("
      .. tostring(key)
      .. "): unknown or missing security level ["
      .. tostring(security)
      .. "] — declare one of KNOWN_PILOT/SENIOR_PILOT/ADMIN/MM/OPEN"
  )
  -- An old spelling still works, and says so once. Guarded on veafSecurity because a handler may
  -- register before that module is loaded, and a missing deprecation notice must never be the
  -- reason a mission fails to load.
  if veafSecurity and veafSecurity.DEPRECATED_LEVEL_NAMES and veafSecurity.DEPRECATED_LEVEL_NAMES[security] then
    veafSecurity.levelForName(security)
  end
  table.insert(veafSpawn.commandHandlers, { key = key, fn = fn, security = security })
end

function veafSpawn.executeCommand(
  eventPos,
  eventText,
  coalition,
  markId,
  bypassSecurity,
  spawnedGroups,
  repeatCount,
  repeatDelay,
  route,
  allowStartDelay,
  requesterCoalition
)
  veaf.loggers.get(veafSpawn.Id):trace("eventPos=%s", eventPos)
  veaf.loggers.get(veafSpawn.Id):debug("eventText=%s", eventText)
  veaf.loggers.get(veafSpawn.Id):trace("coalition=%s", coalition)
  veaf.loggers.get(veafSpawn.Id):trace("markId=%s", markId)
  veaf.loggers.get(veafSpawn.Id):trace("bypassSecurity=%s", bypassSecurity)
  veaf.loggers.get(veafSpawn.Id):trace("repeatCount=%s", repeatCount)
  veaf.loggers.get(veafSpawn.Id):trace("repeatDelay=%s", repeatDelay)
  veaf.loggers.get(veafSpawn.Id):trace("route=%s", route)
  veaf.loggers.get(veafSpawn.Id):trace("allowStartDelay=%s", allowStartDelay)

  -- Check if marker has a text and the veafSpawn.SpawnKeyphrase keyphrase.
  if
    eventText ~= nil
    and (
      eventText:lower():find(veafSpawn.SpawnKeyphrase)
      or eventText:lower():find(veafSpawn.DestroyKeyphrase)
      or eventText:lower():find(veafSpawn.TeleportKeyphrase)
      or eventText:lower():find(veafSpawn.DrawingKeyphrase)
      or eventText:lower():find(veafSpawn.MissionMasterKeyphrase)
    )
  then
    -- Analyse the mark point text and extract the keywords.
    local options = veafSpawn.markTextAnalysis(eventText)

    if options then
      -- A typo aborts rather than spawning something else — see veaf.reportUnknownParameters. The report
      -- goes to the **requester**, not to `coalition`, which is the side the units spawn for.
      if veaf.reportUnknownParameters(options, veafSpawn.Id, requesterCoalition) then
        return false
      end

      local repeatDelay = repeatDelay
      local repeatCount = repeatCount
      local allowStartDelay = allowStartDelay or false
      local startDelay = options.delayedStart

      if allowStartDelay and startDelay and startDelay > 0 then
        veaf.loggers
          .get(veafSpawn.Id)
          :trace(string.format("scheduling veafSpawn.executeCommand for a delayed start in %s seconds", veaf.p(startDelay)))
        mist.scheduleFunction(
          veafSpawn.executeCommand,
          { eventPos, eventText, coalition, markId, bypassSecurity, spawnedGroups, nil, nil, route, false, requesterCoalition },
          timer.getTime() + startDelay
        )
        return true
      end

      if options.repeatCount and not repeatCount then -- only use the parsed repeat options IF the parameter is not set (not during a repeat loop)
        -- set repeatCount and repeatDelay using the parsed options
        repeatCount = options.repeatCount
        repeatDelay = options.repeatDelay or veafSpawn.MIN_REPEAT_DELAY
        veaf.loggers.get(veafSpawn.Id):trace(
          string.format(
            "using parsed repeat options to set repeatCount to %s and repeatDelay to %s",
            veaf.p(repeatCount),
            veaf.p(repeatDelay)
          )
        )
      end

      if repeatCount and repeatCount > 0 then
        repeatDelay = repeatDelay
        if repeatDelay < veafSpawn.MIN_REPEAT_DELAY then
          repeatDelay = veafSpawn.MIN_REPEAT_DELAY
        end
        repeatCount = repeatCount - 1

        -- schedule the next step of the repeated command
        veaf.loggers
          .get(veafSpawn.Id)
          :trace(
            string.format("scheduling veafSpawn.executeCommand for %s repeats in %s seconds", veaf.p(repeatCount), veaf.p(repeatDelay))
          )
        mist.scheduleFunction(veafSpawn.executeCommand, {
          eventPos,
          eventText,
          coalition,
          markId,
          bypassSecurity,
          spawnedGroups,
          repeatCount,
          repeatDelay,
          route,
          false,
          requesterCoalition,
        }, timer.getTime() + repeatDelay)
      end

      if not options.radius then
        if
          options.farp
          or options.cargo
          or options.logistic
          or options.destroy
          or options.teleport
          or options.bomb
          or options.smoke
          or options.flare
          or options.signal
        then
          options.radius = 0
        else
          options.radius = 150
        end
      end

      for i = 1, options.multiplier do
        local spawnedGroup = nil

        if not options.side then
          if options.country then
            -- deduct the side from the country
            options.side = veaf.getCoalitionForCountry(options.country, true)
          else
            options.side = coalition
          end
        end

        if not options.country then
          -- deduct the country from the side
          options.country = veaf.getCountryForCoalition(options.side)
        end

        veaf.loggers.get(veafSpawn.Id):trace(string.format("options.side=%s", tostring(options.side)))
        veaf.loggers.get(veafSpawn.Id):trace(string.format("options.country=%s", tostring(options.country)))

        local routeDone = false

        --indication is the spawn is meant to be a convoy, to adapt it's spawning pattern
        local hasDest = false
        if options.destination ~= nil then
          hasDest = true
        end

        -- Dispatch to registered command handler (ordered list, first match wins)
        local _handler = nil
        local _security = nil
        for _, _entry in ipairs(veafSpawn.commandHandlers) do
          if options[_entry.key] then
            _handler = _entry.fn
            _security = _entry.security
            break
          end
        end
        if _handler then
          -- Centralized security gate (was duplicated in every handler's preamble):
          -- a failed check aborts the command, as the old `return nil, nil, true` did.
          -- Fail-closed: an unknown security level denies rather than silently passing.
          if not bypassSecurity and _security then
            local _check = veafSpawn.SECURITY_CHECKS[_security]
            if not _check or not _check(options, markId) then
              return
            end
          end
          local _g, _done, _abort = _handler(eventPos, options, coalition, markId, bypassSecurity)
          if _abort then
            return
          end
          if _g then
            spawnedGroup = _g
          end
          if _done then
            routeDone = _done
          end
        end
        if spawnedGroup then
          ---@type Group|StaticObject|nil
          local groupObject = Group.getByName(spawnedGroup)
          local isStatic = false
          --group might not have been found because it was a static
          if not groupObject then
            isStatic = true
            groupObject = StaticObject.getByName(spawnedGroup)
          end
          veaf.loggers
            .get(veafSpawn.Id)
            :trace("got groupObject (isStatic=%s) to add group to other platforms : %s", veaf.lp(isStatic), veaf.lp(groupObject))
          if groupObject then
            if not isStatic then
              ---@cast groupObject Group
              --stuff below does not support statics
              -- make the group combat ready ! well except if the user said otherwise, tweak the AlarmState for some scenarios
              --veaf.loggers.get(veafSpawn.Id):trace("options.disperse=%s", veaf.p(options.disperse))
              veaf.readyForCombat(groupObject, options.AlarmState, options.disperse)
              if not route and not routeDone and options.destination then
                --  make the group go to destination
                local actualPosition = groupObject:getUnit(1):getPosition().p
                local route = veaf.generateVehiclesRoute(
                  actualPosition,
                  options.destination,
                  not options.offroad,
                  options.speed,
                  options.patrol,
                  spawnedGroup
                )
                mist.goRoute(groupObject, route)
              elseif route then
                mist.goRoute(groupObject, route)
              end
              -- add the group to the IADS, if there is one
              if veafSkynet then
                -- Tell veafSkynet what this spawn asked for, so that its birth-event handler honours
                -- the `skynet` option instead of integrating every eligible group it sees. Without
                -- this, a convoy spawned with `skynet false` still joined the IADS as soon as dynamic
                -- spawn integration was on — the shortcuts pass `skynet false` on convoys precisely to
                -- avoid that. Declared here because the group name only exists once the handler ran.
                veafSkynet.declareSpawn(spawnedGroup, options.skynet)

                -- Only add static stuff like sam groups and sam batteries, not mobile groups and
                -- convoys. The two integration paths are exclusive: when the target network integrates
                -- dynamic spawns, its birth-event handler does the work (honouring the declaration
                -- above), so doing it here as well would integrate the same group twice. Asking the
                -- *network* rather than the module-level flag, which is only the value a network is
                -- created with and can be changed per network during the mission.
                local networkName = options.skynet
                if type(networkName) == "boolean" then --it means options.skynet is true
                  networkName = veafSkynet.defaultIADS[tostring(options.side)]
                end
                if options.skynet and not veafSkynet.integratesDynamicSpawns(networkName) then
                  veaf.loggers.get(veafSpawn.Id):trace("options.skynet= %s", veaf.lp(options.skynet))
                  options.skynet = networkName
                  veaf.loggers.get(veafSpawn.Id):trace("Adding spawned group to skynet, networkName= %s", veaf.lp(networkName))
                  if
                    veafSkynet.addGroupToNetwork(networkName, groupObject, options.forceEwr, options.pointDefense, nil, bypassSecurity)
                  then
                    veaf.loggers.get(veafSpawn.Id):trace("Group Added to IADS network")
                    if not bypassSecurity then
                      trigger.action.outText(veaf.t("spawn.iads_group_added", options.skynet), 15)
                    end
                  else
                    veaf.loggers.get(veafSpawn.Id):trace("Could not find IADS network or group is not supported by IADS")
                    if not bypassSecurity then
                      trigger.action.outText(veaf.t("spawn.iads_group_not_added", options.skynet), 15)
                    end
                  end
                end
              end
            end
            --might need to specify the if a group was static in here so that people on the other end know
            if spawnedGroups then
              -- Through veaf.collectSpawnedGroup rather than table.insert, so that a caller which
              -- registered a hook hears about this group even when the spawn was deferred and it has
              -- long since stopped reading the table (#66). This is the only insertion point in the
              -- repository, which is why the notification lives here rather than in every signature.
              veaf.collectSpawnedGroup(spawnedGroups, spawnedGroup)
            end
          end
        end
      end
      return true
    end
  end
  return false
end

-- veafSpawn.convertLaserToFreq() and veafSpawn.markTextAnalysis() are defined in veafSpawnParser.lua

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Manage drawings on the map
-------------------------------------------------------------------------------------------------------------------------------------------------------------

veafSpawn.drawings = {}
veafSpawn.drawingsMarkers = {}

--- Add a point to a drawing on the map (or start a new drawing)
function veafSpawn.addPointToDrawing(point, name, color, fillColor, lineType, isArrow)
  veaf.loggers.get(veafSpawn.Id):debug(
    string.format(
      "addPointToDrawing(point=%s, name=%s, color=%s, fillColor=%s, lineType=%s, isArrow=%s)",
      veaf.p(point),
      veaf.p(name),
      veaf.p(color),
      veaf.p(fillColor),
      veaf.p(lineType),
      veaf.p(isArrow)
    )
  )
  if not name then
    veaf.loggers.get(veafSpawn.Id):warn("Name is mandatory for drawing commands")
    return
  end
  local drawing = veafSpawn.drawings[name:lower()]
  if not drawing then
    drawing = VeafDrawingOnMap:new():setName(name)
    veafSpawn.drawings[name:lower()] = drawing
  end
  local drawingMarkerId = veafSpawn.drawingsMarkers[name:lower()]
  if drawingMarkerId then
    trigger.action.removeMark(drawingMarkerId)
  end
  drawingMarkerId = veaf.getUniqueIdentifier()
  trigger.action.markToAll(drawingMarkerId, name, point, true)
  veafSpawn.drawingsMarkers[name:lower()] = drawingMarkerId
  if color then
    drawing:setColor(color)
  end
  if lineType then
    drawing:setLineType(lineType)
  end
  if isArrow then
    drawing:setArrow()
  end
  if fillColor then
    drawing:setFillColor(fillColor)
  end

  drawing:addPoint(point)
  drawing:draw()
end

--- Add a circle to the map
function veafSpawn.drawCircle(point, name, radius, color, fillColor, lineType)
  veaf.loggers.get(veafSpawn.Id):debug(
    string.format(
      "drawCircle(point=%s, name=%s, radius=%s, color=%s, fillColor=%s, lineType=%s)",
      veaf.p(point),
      veaf.p(name),
      veaf.p(radius),
      veaf.p(color),
      veaf.p(fillColor),
      veaf.p(lineType)
    )
  )
  if not name then
    veaf.loggers.get(veafSpawn.Id):warn("Name is mandatory for drawing commands")
    return
  end
  local drawing = veafSpawn.drawings[name:lower()]
  if drawing then
    -- erase the old one first
    drawing:erase()
    veafSpawn.drawings[name:lower()] = nil
  end
  drawing = VeafCircleOnMap:new():setName(name)
  drawing:setCenter(point)
  drawing:setRadius(radius or 5000)
  veafSpawn.drawings[name:lower()] = drawing
  local drawingMarkerId = veafSpawn.drawingsMarkers[name:lower()]
  if drawingMarkerId then
    trigger.action.removeMark(drawingMarkerId)
  end
  drawingMarkerId = veaf.getUniqueIdentifier()
  trigger.action.markToAll(drawingMarkerId, name, point, true)
  veafSpawn.drawingsMarkers[name:lower()] = drawingMarkerId
  if color then
    drawing:setColor(color)
  end
  if lineType then
    drawing:setLineType(lineType)
  end
  if fillColor then
    drawing:setFillColor(fillColor)
  end
  drawing:draw()
end

--- Add a square to the map
function veafSpawn.drawSquare(point, name, side, color, fillColor, lineType)
  veaf.loggers.get(veafSpawn.Id):debug(
    string.format(
      "drawSquare(point=%s, name=%s, side=%s, color=%s, fillColor=%s, lineType=%s)",
      veaf.p(point),
      veaf.p(name),
      veaf.p(side),
      veaf.p(color),
      veaf.p(fillColor),
      veaf.p(lineType)
    )
  )
  if not name then
    veaf.loggers.get(veafSpawn.Id):warn("Name is mandatory for drawing commands")
    return
  end
  local drawing = veafSpawn.drawings[name:lower()]
  if drawing then
    -- erase the old one first
    drawing:erase()
    veafSpawn.drawings[name:lower()] = nil
  end
  drawing = VeafSquareOnMap:new():setName(name)
  drawing:setCenter(point)
  drawing:setSide(side or 5000)
  veafSpawn.drawings[name:lower()] = drawing
  local drawingMarkerId = veafSpawn.drawingsMarkers[name:lower()]
  if drawingMarkerId then
    trigger.action.removeMark(drawingMarkerId)
  end
  drawingMarkerId = veaf.getUniqueIdentifier()
  trigger.action.markToAll(drawingMarkerId, name, point, true)
  veafSpawn.drawingsMarkers[name:lower()] = drawingMarkerId
  if color then
    drawing:setColor(color)
  end
  if lineType then
    drawing:setLineType(lineType)
  end
  if fillColor then
    drawing:setFillColor(fillColor)
  end
  drawing:draw()
end

--- Erase drawing from the map
function veafSpawn.eraseDrawing(name)
  veaf.loggers.get(veafSpawn.Id):debug(string.format("eraseDrawing(name=%s)", veaf.p(name)))
  if not name then
    veaf.loggers.get(veafSpawn.Id):warn("Name is mandatory for drawing commands")
    return
  end
  local drawing = veafSpawn.drawings[name:lower()]
  if not drawing then
    local message = string.format("Could not find a drawing named %s", veaf.p(name))
    veaf.loggers.get(veafSpawn.Id):warn(message)
    trigger.action.outText(veaf.t("spawn.drawing_not_found", veaf.p(name)), 5)
    return
  end
  drawing:erase()
  veafSpawn.drawings[name:lower()] = nil
  local drawingMarkerId = veafSpawn.drawingsMarkers[name:lower()]
  if drawingMarkerId then
    trigger.action.removeMark(drawingMarkerId)
  end
  veafSpawn.drawingsMarkers[name:lower()] = nil
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Group spawn command
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Reports that no acceptable position was found for a whole group, and aborts the spawn
-- Shared by every caller of veaf.findSpawnPoint, in this module and in veafSpawnGround.
-- Before FEAT-SCENERY-AWARE-SPAWN such a spawn ran to completion and dropped its units one
-- by one downstream, emitting one message per unit; it now stops once, with one message.
-- @param silent when true, log only — a scripted spawn must not spam the players
-- @return nil always, so a caller can `return veafSpawn._reportNoGroupPosition(silent)`
function veafSpawn._reportNoGroupPosition(silent)
  veaf.loggers.get(veafSpawn.Id):info("cannot find a suitable position for spawning the group")
  if not silent then
    trigger.action.outText(veaf.t("spawn.no_position_group"), 5)
  end
  return nil
end

--- Spawn a specific group at a specific spot
function veafSpawn.doSpawnGroup(
  spawnSpot,
  radius,
  groupDefinition,
  czName,
  country,
  alt,
  hdg,
  spacing,
  groupName,
  silent,
  hasDest,
  hiddenOnMFD,
  shuffle
)
  veaf.loggers.get(veafSpawn.Id):debug(
    "doSpawnGroup(czName=%s, country=%s, alt=%s, hdg=%s, spacing=%s, groupName=%s, silent=%s, hasDest=%s, hiddenOnMFD=%s, shuffle=%s)",
    czName,
    country,
    alt,
    hdg,
    spacing,
    groupName,
    silent,
    hasDest,
    hiddenOnMFD,
    shuffle
  )

  local spawnSpot = veaf.findSpawnPoint(spawnSpot, radius)
  if not spawnSpot then
    return veafSpawn._reportNoGroupPosition(silent)
  end
  veaf.loggers.get(veafSpawn.Id):trace("spawnSpot=" .. veaf.vecToString(spawnSpot))

  veafSpawn.spawnedUnitsCounter = veafSpawn.spawnedUnitsCounter + 1

  if type(groupDefinition) == "string" then
    local name = groupDefinition
    -- find the desired group in the groups database
    groupDefinition = veafUnits.findGroup(name)
    if not groupDefinition then
      veaf.loggers.get(veafSpawn.Id):info("cannot find group " .. name)
      if not silent then
        trigger.action.outText(veaf.t("spawn.cannot_find_group", name), 5)
      end
      return nil
    end
  end

  veaf.loggers.get(veafSpawn.Id):trace("doSpawnGroup: groupDefinition.description=" .. groupDefinition.description)

  local units = {}

  -- place group units on the map
  local group, cells = veafUnits.placeGroup(groupDefinition, spawnSpot, spacing, hdg, hasDest)
  veafUnits.traceGroup(group, cells)

  if not groupName then
    groupName = group.groupName or "spawned group"
  end
  -- use the centralized group naming function
  groupName = veaf.getNameForSpawnedGroup(veaf.getCoalitionForCountry(country, true), groupName, czName)

  if hasDest then
    mist.scheduleFunction(veafUnits.removePathfindingFixUnit, { groupName }, timer.getTime() + veafUnits.delayBeforePathfindingFix)
  end

  for i = 1, #group.units do
    local unit = group.units[i]
    local unitType = unit.typeName
    local unitName = groupName .. " / " .. unit.displayName .. " #" .. i

    local spawnPoint = unit.spawnPoint
    if alt > 0 then
      spawnPoint.y = alt
    end

    -- check if position is correct for the unit type
    if not veafUnits.checkPositionForUnit(spawnPoint, unit) then
      veaf.loggers.get(veafSpawn.Id):info("cannot find a suitable position for spawning unit " .. unitType)
      if not silent then
        trigger.action.outText(veaf.t("spawn.no_position_unit", unitType), 5)
      end
    else
      local toInsert = {
        ["x"] = spawnPoint.x,
        ["y"] = spawnPoint.z,
        ["alt"] = spawnPoint.y,
        ["type"] = unitType,
        ["name"] = unitName,
        ["speed"] = 0, -- speed in m/s
        ["skill"] = "Random",
        ["heading"] = spawnPoint.hdg,
      }

      veaf.loggers.get(veafSpawn.Id):trace(
        string.format(
          "toInsert x=%.1f y=%.1f, alt=%.1f, type=%s, name=%s, speed=%d, heading=%d, skill=%s, country=%s",
          veaf.p(toInsert.x),
          veaf.p(toInsert.y),
          veaf.p(toInsert.alt),
          veaf.p(toInsert.type),
          veaf.p(toInsert.name),
          veaf.p(toInsert.speed),
          veaf.p(mist.utils.toDegree(toInsert.heading)),
          veaf.p(toInsert.skill),
          veaf.p(country)
        )
      )
      table.insert(units, toInsert)
    end
  end

  -- shuffle the group if needed (useful for randomizing convoys)
  -- counter productive with hasDest which to speed up convoys orders all of the units so that they spawn in order and in a line
  -- the best way to execute this shuffle is to create groups with random cells for each unit, TBD
  if shuffle and not hasDest then
    units = veaf.shuffle(units)
  end

  -- actually spawn the group
  if group.naval then
    mist.dynAdd({ country = country, category = "SHIP", name = groupName, hidden = false, units = units, hiddenOnMFD = hiddenOnMFD })
  elseif group.air then
    mist.dynAdd({ country = country, category = "AIRPLANE", name = groupName, hidden = false, units = units, hiddenOnMFD = hiddenOnMFD })
  else
    mist.dynAdd({ country = country, category = "GROUND_UNIT", name = groupName, hidden = false, units = units, hiddenOnMFD = hiddenOnMFD })
  end

  if not silent then
    -- message the group spawning
    trigger.action.outText(veaf.t("spawn.group_spawned", group.description, country), 5)
  end

  return groupName
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Mission master features
-------------------------------------------------------------------------------------------------------------------------------------------------------------
veafSpawn.missionMasterRunnables = {}
veafSpawn.missionMasterRunnables.__silent = true

function veafSpawn.missionMasterSetMessagingMode(silent, toGroupId)
  veafSpawn.missionMasterRunnables.__silent = silent
  veafSpawn.missionMasterRunnables.__toGroupId = toGroupId
end

function veafSpawn.missionMasterOutText(message)
  -- don't send the message if __silent is true
  if not veafSpawn.missionMasterRunnables.__silent then
    if veafSpawn.missionMasterRunnables.__toGroupId then
      -- send to a group
      trigger.action.outTextForGroup(veafSpawn.missionMasterRunnables.__toGroupId, message, 5)
    else
      -- send to all
      trigger.action.outText(message, 5)
    end
  end
end

function veafSpawn.missionMasterAddRunnable(name, code, parameters)
  veaf.loggers.get(veafSpawn.Id):debug("veafSpawn.missionMasterAddRunnable(name=%s)", name)
  veafSpawn.missionMasterRunnables[veaf.ifnn(name, "upper")] = { code, parameters }
end

function veafSpawn.missionMasterRun(name)
  veaf.loggers.get(veafSpawn.Id):debug("veafSpawn.missionMasterRun(name=%s)", name)
  if not name or #name == 0 then
    local message = "Mission Master, `run` requires the name of the code to be run"
    veaf.loggers.get(veafSpawn.Id):warn(message)
    veafSpawn.missionMasterOutText(message)
    return
  end

  local code, parameters = veaf.safeUnpack(veafSpawn.missionMasterRunnables[veaf.ifnn(name, "upper")])
  if code then
    local sta, res = pcall(code, parameters)
    if sta then
      local message = string.format("Mission Master, the runnable [%s] was successfully run and returned : %s", name, veaf.p(res))
      veaf.loggers.get(veafSpawn.Id):warn(message)
      veafSpawn.missionMasterOutText(message)
    else
      local message = string.format("Mission Master, the runnable [%s] returned an error : %s", name, veaf.p(res))
      veaf.loggers.get(veafSpawn.Id):warn(message)
      veafSpawn.missionMasterOutText(message)
    end
  else
    local message = string.format("Mission Master, the runnable [%s] does not exist", name)
    veaf.loggers.get(veafSpawn.Id):warn(message)
    veafSpawn.missionMasterOutText(message)
  end
end

function veafSpawn.missionMasterSetFlagFromTable(parameters)
  veaf.loggers.get(veafSpawn.Id):debug("veafSpawn.missionMasterSetFlagFromTable(parameters=%s)", parameters)
  local name, value = veaf.safeUnpack(parameters)
  return veafSpawn.missionMasterSetFlag(name, value)
end

function veafSpawn.missionMasterIncrementFlagValue(name)
  veafSpawn.missionMasterAddValueToFlag(name, 1)
end

function veafSpawn.missionMasterDecrementFlagValue(name)
  veafSpawn.missionMasterAddValueToFlag(name, -1)
end

function veafSpawn.missionMasterAddValueToFlag(name, increment)
  veaf.loggers.get(veafSpawn.Id):debug("veafSpawn.missionMasterIncrementFlagValue(name=%s, increment=%s)", name, increment)
  if not name then
    local message = "Mission Master, `setFlag` requires the name or number of the flag"
    veaf.loggers.get(veafSpawn.Id):warn(message)
    veafSpawn.missionMasterOutText(message)
    return
  end
  local value = trigger.misc.getUserFlag(name)
  if not value then
    value = 0
  end
  trigger.action.setUserFlag(name, value + increment)
end

function veafSpawn.missionMasterSetFlag(name, value)
  veaf.loggers.get(veafSpawn.Id):debug("veafSpawn.missionMasterSetFlag(name=%s, value=%s)", name, value)
  if not name then
    local message = "Mission Master, `setFlag` requires the name or number of the flag"
    veaf.loggers.get(veafSpawn.Id):warn(message)
    veafSpawn.missionMasterOutText(message)
    return
  end
  trigger.action.setUserFlag(name, value)
end

function veafSpawn.missionMasterGetFlag(name)
  veaf.loggers.get(veafSpawn.Id):debug("veafSpawn.missionMasterGetFlag(name=%s)", name)
  if not name then
    local message = "Mission Master, `getFlag` requires the name or number of the flag"
    veaf.loggers.get(veafSpawn.Id):warn(message)
    veafSpawn.missionMasterOutText(message)
    return
  end
  local value = trigger.misc.getUserFlag(name)
  local message = string.format("Mission Master, flag [%s] has value [%s]", name, veaf.p(value))
  veaf.loggers.get(veafSpawn.Id):info(message)
  veafSpawn.missionMasterOutText(message)
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Radio menu
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Build the initial radio menu
function veafSpawn.buildRadioMenu()
  veaf.loggers.get(veafSpawn.Id):debug(string.format("veafSpawn.buildRadioMenu() hideMenu%s", veaf.p(veafSpawn.HideRadioMenu)))
  if not veafSpawn.HideRadioMenu then
    veafSpawn.rootPath = veafRadio.addSubMenu(veaf.t(veafSpawn.RadioMenuName))
    veafRadio.addCommandToSubmenu(
      veaf.t("menu.spawn.available_aircraft"),
      veafSpawn.rootPath,
      veafSpawn.listAllCAP,
      nil,
      veafRadio.USAGE_ForAll
    )
    veafRadio.addCommandToSubmenu(
      veaf.t("menu.spawn.convoy_info_all"),
      veafSpawn.rootPath,
      veafSpawn.infoOnAllConvoys,
      nil,
      veafRadio.USAGE_ForGroup
    )
    -- FIX-CONVOY-MENU-NESTING: these six sit **directly** under the spawn root. Each used to get
    -- its own submenu holding a single command of the same name, so a pilot read the same sentence
    -- twice and spent two keystrokes to reach one item. Reported in game 2026-08-22.
    --
    -- Nothing required the nesting: `veafCarrierOperations` puts several `USAGE_ForGroup` commands
    -- in one shared submenu, and `convoy_cleanup` below has always been added straight to the root.
    -- The pattern predates FEAT-CONVOY-WAYPOINTS — `convoy_mark` and `convoy_mark_route` were
    -- already written this way and the itinerary commands copied their neighbour — so all six moved
    -- together rather than leaving the menu half-flat.
    --
    -- The order is deliberate: mark, then the four itinerary verbs as a game master reaches for them
    -- — push it on, park it at the next point, halt it on the spot, send it off again. `hold` and
    -- `stop` stay adjacent because their labels have to be readable *against* one another, which is
    -- where the two get confused.
    veafRadio.addCommandToSubmenu(
      veaf.t("menu.spawn.convoy_mark_route"),
      veafSpawn.rootPath,
      veafSpawn.markClosestConvoyRouteWithSmoke,
      nil,
      veafRadio.USAGE_ForGroup
    )
    veafRadio.addCommandToSubmenu(
      veaf.t("menu.spawn.convoy_mark"),
      veafSpawn.rootPath,
      veafSpawn.markClosestConvoyWithSmoke,
      nil,
      veafRadio.USAGE_ForGroup
    )
    veafRadio.addCommandToSubmenu(
      veaf.t("menu.spawn.convoy_advance"),
      veafSpawn.rootPath,
      veafSpawn.advanceClosestConvoy,
      nil,
      veafRadio.USAGE_ForGroup
    )
    veafRadio.addCommandToSubmenu(
      veaf.t("menu.spawn.convoy_hold"),
      veafSpawn.rootPath,
      veafSpawn.holdClosestConvoy,
      nil,
      veafRadio.USAGE_ForGroup
    )
    veafRadio.addCommandToSubmenu(
      veaf.t("menu.spawn.convoy_stop"),
      veafSpawn.rootPath,
      veafSpawn.stopClosestConvoy,
      nil,
      veafRadio.USAGE_ForGroup
    )
    veafRadio.addCommandToSubmenu(
      veaf.t("menu.spawn.convoy_move"),
      veafSpawn.rootPath,
      veafSpawn.moveClosestConvoy,
      nil,
      veafRadio.USAGE_ForGroup
    )
    veafRadio.addSecuredCommandToSubmenu(veaf.t("menu.spawn.convoy_cleanup"), veafSpawn.rootPath, veafSpawn.cleanupAllConvoys)
    veafRadio.refreshRadioMenu()
  end
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Core command handlers (drawing + mission master) — registered at load time
-------------------------------------------------------------------------------------------------------------------------------------------------------------

veafSpawn.registerCommandHandler("addDrawing", "SENIOR_PILOT", function(eventPos, options, coalition, markId, bypassSecurity)
  veafSpawn.addPointToDrawing(eventPos, options.name, options.drawColor, options.drawFillColor, options.type, options.drawArrow)
  return nil, nil, false
end)

veafSpawn.registerCommandHandler("drawSquare", "SENIOR_PILOT", function(eventPos, options, coalition, markId, bypassSecurity)
  veafSpawn.drawSquare(eventPos, options.name, options.radius, options.drawColor, options.drawFillColor, options.type)
  return nil, nil, false
end)

veafSpawn.registerCommandHandler("drawCircle", "SENIOR_PILOT", function(eventPos, options, coalition, markId, bypassSecurity)
  veafSpawn.drawCircle(eventPos, options.name, options.radius, options.drawColor, options.drawFillColor, options.type)
  return nil, nil, false
end)

veafSpawn.registerCommandHandler("eraseDrawing", "SENIOR_PILOT", function(eventPos, options, coalition, markId, bypassSecurity)
  veafSpawn.eraseDrawing(options.name)
  return nil, nil, false
end)

veafSpawn.registerCommandHandler("mmFlagOn", "MM", function(eventPos, options, coalition, markId, bypassSecurity)
  veafSpawn.missionMasterSetFlag(options.name, 1)
  return nil, nil, false
end)

veafSpawn.registerCommandHandler("mmFlagOff", "MM", function(eventPos, options, coalition, markId, bypassSecurity)
  veafSpawn.missionMasterSetFlag(options.name, 0)
  return nil, nil, false
end)

veafSpawn.registerCommandHandler("mmGetFlag", "MM", function(eventPos, options, coalition, markId, bypassSecurity)
  veafSpawn.missionMasterGetFlag(options.name)
  return nil, nil, false
end)

veafSpawn.registerCommandHandler("mmRun", "MM", function(eventPos, options, coalition, markId, bypassSecurity)
  veafSpawn.missionMasterRun(options.name)
  return nil, nil, false
end)

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- initialisation
-------------------------------------------------------------------------------------------------------------------------------------------------------------

function veafSpawn.initialize()
  veafSpawn.buildRadioMenu()
  veafSpawn.initializeAirUnitTemplates()
  veafCommands.registerCommandHandler(function(pos, event, bypass, fromMarker, groups, route)
    -- Markers spawn for the opposing side by default; interpreter/remote commands
    -- spawn for the issuing unit's own side. Feedback always goes to the requester.
    local spawnSide = fromMarker and veaf.getOppositeCoalition(event.coalition) or event.coalition
    local requesterCoalition = veaf.getRequesterCoalition(event)
    return veafSpawn.executeCommand(pos, event.text, spawnSide, event.idx, bypass, groups, nil, nil, route, true, requesterCoalition)
  end, veafCommands.PRIORITY_SPAWN, veafCommands.SECURITY_HANDLED)
  veafSpawn.dumpSpawnablePlanesList()
end

veaf.loggers.get(veafSpawn.Id):info(veaf.loggers.get(veafSpawn.Id):getVersionInfo())

veaf.registerModule(veafSpawn.Id, veafSpawn.initialize, { enable = true }, 70)
