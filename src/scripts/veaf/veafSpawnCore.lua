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

--- Version.
veafSpawn.Version = "1.59.2"

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

veafSpawn.RadioMenuName = "SPAWN"
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

--- Register a command handler for executeCommand().
-- @param key   options field name that activates this handler (e.g. "unit", "farp")
-- @param fn    function(eventPos, options, coalition, markId, bypassSecurity) -> spawnedGroup, routeDone, abort
function veafSpawn.registerCommandHandler(key, fn)
  table.insert(veafSpawn.commandHandlers, { key = key, fn = fn })
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
  allowStartDelay
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
      -- Hint the pilot about unrecognized parameters (likely typos) — UXPILOT-003.
      -- Aggregate into a single message to avoid spamming when several keys are wrong.
      if options.unknownParameters then
        local hints = {}
        for _, p in ipairs(options.unknownParameters) do
          local hint = "'" .. tostring(p.key) .. "'"
          if p.suggestion then
            hint = hint .. " (did you mean '" .. tostring(p.suggestion) .. "'?)"
          end
          table.insert(hints, hint)
        end
        veaf.reportToPilot("VEAF spawn: unknown parameter(s): " .. table.concat(hints, ", "), 15, coalition)
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
          { eventPos, eventText, coalition, markId, bypassSecurity, spawnedGroups, nil, nil, route, false },
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
        mist.scheduleFunction(
          veafSpawn.executeCommand,
          { eventPos, eventText, coalition, markId, bypassSecurity, spawnedGroups, repeatCount, repeatDelay, route, false },
          timer.getTime() + repeatDelay
        )
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
        for _, _entry in ipairs(veafSpawn.commandHandlers) do
          if options[_entry.key] then
            _handler = _entry.fn
            break
          end
        end
        if _handler then
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
              if veafSkynet and not veafSkynet.DynamicSpawn and options.skynet then -- only add static stuff like sam groups and sam batteries, not mobile groups and convoys -- and do not do that if DynamicSpawn is active in VeafSkynet
                veaf.loggers.get(veafSpawn.Id):trace("options.skynet= %s", veaf.lp(options.skynet))
                if type(options.skynet) == "boolean" then --it means options.skynet is true
                  options.skynet = veafSkynet.defaultIADS[tostring(options.side)]
                end
                veaf.loggers.get(veafSpawn.Id):trace("Adding spawned group to skynet, networkName= %s", veaf.lp(options.skynet))
                local networkName = options.skynet
                if veafSkynet.addGroupToNetwork(networkName, groupObject, options.forceEwr, options.pointDefense, nil, bypassSecurity) then
                  veaf.loggers.get(veafSpawn.Id):trace("Group Added to IADS network")
                  if not bypassSecurity then
                    trigger.action.outText(string.format('Group added to the IADS named "%s"', options.skynet), 15)
                  end
                else
                  veaf.loggers.get(veafSpawn.Id):trace("Could not find IADS network or group is not supported by IADS")
                  if not bypassSecurity then
                    trigger.action.outText(
                      string.format('Could not add group to the IADS named "%s", network not found or group not supported', options.skynet),
                      15
                    )
                  end
                end
              end
            end
            --might need to specify the if a group was static in here so that people on the other end know
            if spawnedGroups then
              table.insert(spawnedGroups, spawnedGroup)
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
    trigger.action.outText(message, 5)
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

  local spawnSpot = veaf.placePointOnLand(mist.getRandPointInCircle(spawnSpot, radius))
  veaf.loggers.get(veafSpawn.Id):trace("spawnSpot=" .. veaf.vecToString(spawnSpot))

  veafSpawn.spawnedUnitsCounter = veafSpawn.spawnedUnitsCounter + 1

  if type(groupDefinition) == "string" then
    local name = groupDefinition
    -- find the desired group in the groups database
    groupDefinition = veafUnits.findGroup(name)
    if not groupDefinition then
      veaf.loggers.get(veafSpawn.Id):info("cannot find group " .. name)
      if not silent then
        trigger.action.outText("cannot find group " .. name, 5)
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
        trigger.action.outText("cannot find a suitable position for spawning unit " .. unitType, 5)
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
    trigger.action.outText("A " .. group.description .. "(" .. country .. ") has been spawned", 5)
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
    veafSpawn.rootPath = veafRadio.addSubMenu(veafSpawn.RadioMenuName)
    veafRadio.addCommandToSubmenu("Available Aircraft spawns", veafSpawn.rootPath, veafSpawn.listAllCAP, nil, veafRadio.USAGE_ForAll)
    veafRadio.addCommandToSubmenu("Info on all convoys", veafSpawn.rootPath, veafSpawn.infoOnAllConvoys, nil, veafRadio.USAGE_ForGroup)
    local menuPath = veafRadio.addSubMenu("Mark closest convoy route", veafSpawn.rootPath)
    veafRadio.addCommandToSubmenu(
      "Mark closest convoy route",
      menuPath,
      veafSpawn.markClosestConvoyRouteWithSmoke,
      nil,
      veafRadio.USAGE_ForGroup
    )
    local menuPath = veafRadio.addSubMenu("Mark closest convoy", veafSpawn.rootPath)
    veafRadio.addCommandToSubmenu("Mark closest convoy", menuPath, veafSpawn.markClosestConvoyWithSmoke, nil, veafRadio.USAGE_ForGroup)
    local menuPath = veafRadio.addSubMenu("Stop closest convoy", veafSpawn.rootPath)
    veafRadio.addCommandToSubmenu("Stop closest convoy", menuPath, veafSpawn.stopClosestConvoy, nil, veafRadio.USAGE_ForGroup)
    local menuPath = veafRadio.addSubMenu("Makes closest convoy move", veafSpawn.rootPath)
    veafRadio.addCommandToSubmenu("Make closest convoy move", menuPath, veafSpawn.moveClosestConvoy, nil, veafRadio.USAGE_ForGroup)
    veafRadio.addSecuredCommandToSubmenu("Cleanup all convoys", veafSpawn.rootPath, veafSpawn.cleanupAllConvoys)
    veafRadio.refreshRadioMenu()
  end
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Core command handlers (drawing + mission master) — registered at load time
-------------------------------------------------------------------------------------------------------------------------------------------------------------

veafSpawn.registerCommandHandler("addDrawing", function(eventPos, options, coalition, markId, bypassSecurity)
  if not (bypassSecurity or veafSecurity.checkSecurity_L1(options.password, markId)) then
    return nil, nil, true
  end
  veafSpawn.addPointToDrawing(eventPos, options.name, options.drawColor, options.drawFillColor, options.type, options.drawArrow)
  return nil, nil, false
end)

veafSpawn.registerCommandHandler("drawSquare", function(eventPos, options, coalition, markId, bypassSecurity)
  if not (bypassSecurity or veafSecurity.checkSecurity_L1(options.password, markId)) then
    return nil, nil, true
  end
  veafSpawn.drawSquare(eventPos, options.name, options.radius, options.drawColor, options.drawFillColor, options.type)
  return nil, nil, false
end)

veafSpawn.registerCommandHandler("drawCircle", function(eventPos, options, coalition, markId, bypassSecurity)
  if not (bypassSecurity or veafSecurity.checkSecurity_L1(options.password, markId)) then
    return nil, nil, true
  end
  veafSpawn.drawCircle(eventPos, options.name, options.radius, options.drawColor, options.drawFillColor, options.type)
  return nil, nil, false
end)

veafSpawn.registerCommandHandler("eraseDrawing", function(eventPos, options, coalition, markId, bypassSecurity)
  if not (bypassSecurity or veafSecurity.checkSecurity_L1(options.password, markId)) then
    return nil, nil, true
  end
  veafSpawn.eraseDrawing(options.name)
  return nil, nil, false
end)

veafSpawn.registerCommandHandler("mmFlagOn", function(eventPos, options, coalition, markId, bypassSecurity)
  if not (bypassSecurity or veafSecurity.checkSecurity_MM(options.password)) then
    return nil, nil, true
  end
  veafSpawn.missionMasterSetFlag(options.name, 1)
  return nil, nil, false
end)

veafSpawn.registerCommandHandler("mmFlagOff", function(eventPos, options, coalition, markId, bypassSecurity)
  if not (bypassSecurity or veafSecurity.checkSecurity_MM(options.password)) then
    return nil, nil, true
  end
  veafSpawn.missionMasterSetFlag(options.name, 0)
  return nil, nil, false
end)

veafSpawn.registerCommandHandler("mmGetFlag", function(eventPos, options, coalition, markId, bypassSecurity)
  if not (bypassSecurity or veafSecurity.checkSecurity_MM(options.password)) then
    return nil, nil, true
  end
  veafSpawn.missionMasterGetFlag(options.name)
  return nil, nil, false
end)

veafSpawn.registerCommandHandler("mmRun", function(eventPos, options, coalition, markId, bypassSecurity)
  if not (bypassSecurity or veafSecurity.checkSecurity_MM(options.password)) then
    return nil, nil, true
  end
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
    local coal = fromMarker and ((event.coalition == 1) and 2 or 1) or event.coalition
    return veafSpawn.executeCommand(pos, event.text, coal, event.idx, bypass, groups, nil, nil, route, true)
  end, veafCommands.PRIORITY_SPAWN)
  veafSpawn.dumpSpawnablePlanesList()
end

veaf.loggers.get(veafSpawn.Id):info(veaf.loggers.get(veafSpawn.Id):getVersionInfo(veafSpawn.Version))

veaf.registerModule(veafSpawn.Id, veafSpawn.initialize, { enable = true }, 70)
