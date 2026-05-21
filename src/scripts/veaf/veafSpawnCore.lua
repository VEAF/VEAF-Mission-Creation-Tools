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

veafSpawn.HoundElintAddDelay = 1 --delay before attempting to add a unit to Hound Elint, required for aircrafts spawned dynamically at least

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

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Utility methods
-------------------------------------------------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Event handler functions.
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Function executed when a mark has changed. This happens when text is entered or changed.
function veafSpawn.onEventMarkChange(eventPos, event)
  veaf.loggers.get(veafSpawn.Id):trace(string.format("event  = %s", veaf.p(event)))

  -- choose by default the coalition opposing the player who triggered the event
  local invertedCoalition = 1
  if event.coalition == 1 then
    invertedCoalition = 2
  end

  veaf.loggers.get(veafSpawn.Id):trace(string.format("event.idx  = %s", veaf.p(event.idx)))

  if veafSpawn.executeCommand(eventPos, event.text, invertedCoalition, event.idx, nil, nil, nil, nil, nil, true) then
    -- Delete old mark.
    veaf.loggers.get(veafSpawn.Id):trace(string.format("Removing mark # %d.", event.idx))
    trigger.action.removeMark(event.idx)
  end
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

        -- Check options commands
        if options.unit then
          -- check security
          if not (bypassSecurity or veafSecurity.checkSecurity_L9(options.password, markId)) then
            return
          end
          ---@type string|number|nil
          local code = options.laserCode
          ---@type string|number|nil
          local channel = options.freq
          local band = options.mod
          if options.role == "tacan" then
            channel = options.tacanChannel or 99
            code = options.tacanCode or ("T" .. tostring(channel))
            band = options.tacanBand or "X"
          end
          spawnedGroup = veafSpawn.spawnUnit(
            eventPos,
            options.radius,
            options.name,
            options.czName,
            options.country,
            options.altitude,
            options.heading,
            options.unitName,
            options.role,
            options.forceStatic,
            code,
            channel,
            band,
            bypassSecurity,
            not options.showMFD
          )
        elseif options.farp then
          -- check security
          if not (bypassSecurity or veafSecurity.checkSecurity_L9(options.password, markId)) then
            return
          end
          if not options.type then
            options.type = "invisible"
          end
          local channel = options.tacanChannel
          local code = options.tacanCode
          local mod = options.tacanBand
          spawnedGroup = veafSpawn.spawnFarp(
            eventPos,
            options.radius,
            options.name,
            options.country,
            options.type,
            options.side,
            options.heading,
            options.spacing,
            bypassSecurity,
            not options.showMFD,
            options.noFarpMarkers,
            code,
            channel,
            mod
          )
        elseif options.fob then
          -- check security
          if not (bypassSecurity or veafSecurity.checkSecurity_L9(options.password, markId)) then
            return
          end
          spawnedGroup = veafSpawn.spawnFob(
            eventPos,
            options.radius,
            options.name,
            options.country,
            options.type,
            options.side,
            options.heading,
            options.spacing,
            bypassSecurity,
            not options.showMFD
          )
        elseif options.cap then
          -- check security
          if not (bypassSecurity or veafSecurity.checkSecurity_L9(options.password, markId)) then
            return
          end
          spawnedGroup = veafSpawn.spawnCombatAirPatrol(
            eventPos,
            options.radius,
            options.name,
            options.country,
            options.altitude,
            options.altitudedelta,
            options.heading,
            options.distance,
            options.speed,
            options.capradius,
            options.skill,
            bypassSecurity,
            options.showMFD
          )
        elseif options.afac then
          --check security
          if not (bypassSecurity or veafSecurity.checkSecurity_L9(options.password, markId)) then
            return
          end
          spawnedGroup = veafSpawn.spawnAFAC(
            eventPos,
            options.name,
            options.country,
            options.altitude,
            options.speed,
            options.heading,
            options.freq,
            options.mod,
            options.laserCode,
            options.immortal,
            false,
            options.showMFD
          )
        elseif options.group then
          -- check security
          if not (bypassSecurity or veafSecurity.checkSecurity_L9(options.password, markId)) then
            return
          end
          spawnedGroup = veafSpawn.spawnGroup(
            eventPos,
            options.radius,
            options.name,
            options.czName,
            options.country,
            options.altitude,
            options.heading,
            options.spacing,
            options.unitName,
            bypassSecurity,
            hasDest,
            not options.showMFD
          )
        elseif options.infantryGroup then
          -- check security
          if not (bypassSecurity or veafSecurity.checkSecurity_L9(options.password, markId)) then
            return
          end
          spawnedGroup = veafSpawn.spawnInfantryGroup(
            eventPos,
            options.radius,
            options.czName,
            options.country,
            options.side,
            options.heading,
            options.spacing,
            options.defense,
            options.armor,
            options.size,
            bypassSecurity,
            not options.showMFD
          )
        elseif options.armoredPlatoon then
          -- check security
          if not (bypassSecurity or veafSecurity.checkSecurity_L9(options.password, markId)) then
            return
          end
          spawnedGroup = veafSpawn.spawnArmoredPlatoon(
            eventPos,
            options.radius,
            options.czName,
            options.country,
            options.side,
            options.heading,
            options.spacing,
            options.defense,
            options.armor,
            options.size,
            bypassSecurity,
            hasDest,
            not options.showMFD
          )
        elseif options.airDefenseBattery then
          -- check security
          if not (bypassSecurity or veafSecurity.checkSecurity_L9(options.password, markId)) then
            return
          end
          spawnedGroup = veafSpawn.spawnAirDefenseBattery(
            eventPos,
            options.radius,
            options.czName,
            options.country,
            options.side,
            options.heading,
            options.spacing,
            options.defense,
            bypassSecurity,
            hasDest,
            not options.showMFD
          )
        elseif options.transportCompany then
          -- check security
          if not (bypassSecurity or veafSecurity.checkSecurity_L9(options.password, markId)) then
            return
          end
          spawnedGroup = veafSpawn.spawnTransportCompany(
            eventPos,
            options.radius,
            options.czName,
            options.country,
            options.side,
            options.heading,
            options.spacing,
            options.defense,
            options.size,
            bypassSecurity,
            hasDest,
            not options.showMFD
          )
        elseif options.fullCombatGroup then
          -- check security
          if not (bypassSecurity or veafSecurity.checkSecurity_L9(options.password, markId)) then
            return
          end
          spawnedGroup = veafSpawn.spawnFullCombatGroup(
            eventPos,
            options.radius,
            options.czName,
            options.country,
            options.side,
            options.heading,
            options.spacing,
            options.defense,
            options.armor,
            options.size,
            bypassSecurity,
            not options.showMFD
          )
        elseif options.convoy then
          -- check security
          if not (bypassSecurity or veafSecurity.checkSecurity_L9(options.password, markId)) then
            return
          end
          spawnedGroup = veafSpawn.spawnConvoy(
            eventPos,
            options.name,
            options.czName,
            options.radius,
            options.country,
            options.side,
            options.heading,
            options.spacing,
            options.speed,
            options.patrol,
            options.offroad,
            options.destination,
            options.defense,
            options.size,
            options.armor,
            bypassSecurity,
            not options.showMFD
          )
          routeDone = true
        elseif options.cargo then
          -- check security
          if not (bypassSecurity or veafSecurity.checkSecurity_L9(options.password, markId)) then
            return
          end
          spawnedGroup = veafSpawn.spawnCargo(
            eventPos,
            options.radius,
            options.cargoType,
            options.country,
            options.cargoWeightBias,
            options.cargoSmoke,
            options.unitName,
            bypassSecurity,
            not options.showMFD
          )
        elseif options.logistic then
          -- check security
          if not (bypassSecurity or veafSecurity.checkSecurity_L9(options.password, markId)) then
            return
          end
          spawnedGroup = veafSpawn.spawnLogistic(eventPos, options.radius, options.country, bypassSecurity, not options.showMFD)
        elseif options.destroy then
          -- check security
          if not (bypassSecurity or veafSecurity.checkSecurity_L1(options.password, markId)) then
            return
          end
          veafSpawn.destroy(eventPos, options.radius, options.unitName)
        elseif options.teleport then
          -- check security
          if not (bypassSecurity or veafSecurity.checkSecurity_L1(options.password, markId)) then
            return
          end
          veafSpawn.teleport(eventPos, options.name, bypassSecurity)
        elseif options.bomb then
          -- check security
          if not (bypassSecurity or veafSecurity.checkSecurity_L1(options.password, markId)) then
            return
          end
          veafSpawn.spawnBomb(
            eventPos,
            options.radius,
            options.shells,
            options.power,
            options.altitude,
            options.altitudedelta,
            options.password
          )
        elseif options.smoke then
          veafSpawn.spawnSmoke(eventPos, options.smokeColor, options.radius, options.shells)
        elseif options.flare then
          if not options.altitude or options.altitude == 0 then
            options.altitude = 1000
          end
          if not options.power or options.power == 0 then
            options.power = 500
          end
          options.power = options.power * 1000
          veafSpawn.spawnIlluminationFlare(
            eventPos,
            options.radius,
            options.shells,
            options.power,
            options.altitude,
            options.heading,
            options.distance,
            options.speed
          )
        elseif options.signal then
          veafSpawn.spawnSignalFlare(eventPos, options.radius, options.shells, options.smokeColor)
        elseif options.addDrawing then
          -- check security
          if not (bypassSecurity or veafSecurity.checkSecurity_L1(options.password, markId)) then
            return
          end
          veafSpawn.addPointToDrawing(eventPos, options.name, options.drawColor, options.drawFillColor, options.type, options.drawArrow)
        elseif options.drawSquare then
          -- check security
          if not (bypassSecurity or veafSecurity.checkSecurity_L1(options.password, markId)) then
            return
          end
          veafSpawn.drawSquare(eventPos, options.name, options.radius, options.drawColor, options.drawFillColor, options.type)
        elseif options.drawCircle then
          -- check security
          if not (bypassSecurity or veafSecurity.checkSecurity_L1(options.password, markId)) then
            return
          end
          veafSpawn.drawCircle(eventPos, options.name, options.radius, options.drawColor, options.drawFillColor, options.type)
        elseif options.eraseDrawing then
          -- check security
          if not (bypassSecurity or veafSecurity.checkSecurity_L1(options.password, markId)) then
            return
          end
          veafSpawn.eraseDrawing(options.name)
        elseif options.mmFlagOn then
          -- check security
          if not (bypassSecurity or veafSecurity.checkSecurity_MM(options.password)) then
            return
          end
          veafSpawn.missionMasterSetFlag(options.name, 1)
        elseif options.mmFlagOff then
          -- check security
          if not (bypassSecurity or veafSecurity.checkSecurity_MM(options.password)) then
            return
          end
          veafSpawn.missionMasterSetFlag(options.name, 0)
        elseif options.mmGetFlag then
          -- check security
          if not (bypassSecurity or veafSecurity.checkSecurity_MM(options.password)) then
            return
          end
          veafSpawn.missionMasterGetFlag(options.name)
        elseif options.mmRun then
          -- check security
          if not (bypassSecurity or veafSecurity.checkSecurity_MM(options.password)) then
            return
          end
          veafSpawn.missionMasterRun(options.name)
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
            --but houndElint for example does support statics
            -- reset the Hound Elint system, if the module is active
            if veafHoundElint then
              mist.scheduleFunction(
                veafHoundElint.addPlatformToSystem,
                { groupObject, nil, false },
                timer.getTime() + veafSpawn.HoundElintAddDelay
              )
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

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Analyse the mark text and extract keywords.
-------------------------------------------------------------------------------------------------------------------------------------------------------------

function veafSpawn.convertLaserToFreq(laser)
  veaf.loggers.get(veafSpawn.Id):trace(string.format("convertLaserToFreq(laser=%s)", tostring(laser)))
  local laser = tonumber(laser)
  if laser and laser >= 1111 and laser <= 1688 then
    local laserB = math.floor((laser - 1000) / 100)
    local laserCD = laser - 1000 - laserB * 100
    local frequency = tostring(30 + laserB + laserCD * 0.05)
    veaf.loggers.get(veafSpawn.Id):trace(string.format("laserB=%s", tostring(laserB)))
    veaf.loggers.get(veafSpawn.Id):trace(string.format("laserCD=%s", tostring(laserCD)))
    veaf.loggers.get(veafSpawn.Id):trace(string.format("frequency=%s", tostring(frequency)))
    return frequency
  else
    return nil
  end
end

--- Extract keywords from mark text.
function veafSpawn.markTextAnalysis(text)
  veaf.loggers.get(veafSpawn.Id):trace(string.format("veafSpawn.markTextAnalysis(text=%s)", text))

  -- Option parameters extracted from the mark text.
  local options = {}
  options.czName = nil -- name of the CZ to add to the group name, if any
  options.unit = false
  options.forceStatic = false -- if true, will force the spawned unit to be a static
  options.group = false
  options.cap = false
  options.farp = false
  options.noFarpMarkers = false
  options.fob = false
  options.type = nil
  options.cargo = false
  options.logistic = false
  options.smoke = false
  options.flare = false
  options.signal = false
  options.bomb = false
  options.destroy = false
  options.teleport = false
  options.convoy = false
  options.role = nil
  options.laserCode = 1688
  options.infantryGroup = false
  options.armoredPlatoon = false
  options.airDefenseBattery = false
  options.transportCompany = false
  options.fullCombatGroup = false
  options.speed = nil
  options.capradius = nil
  options.shells = 1
  options.multiplier = 1
  options.skynet = false -- if true, add to skynet
  options.forceEwr = false -- if true, unit will be added as an IADS EWR
  options.pointDefense = false -- if true, unit will be added as point defense to the closest IADS SAM site
  options.AlarmState = 2 -- Alarm state of the convoy to be spawned, 0 is AUTO, 1 is GREEN, 2 is RED. Note: This option is useful for some vehicules which behave badly in Alarm State RED when spawned such as the Scud or Sa-11 (they deploy and can't drive anywhere). Auto is better suited
  options.disperse = 15 --disperse time of groups if under attack, by default is set to 20s
  options.showMFD = false --option to enable groups to be seen on MFDs
  options.addDrawing = false -- draw a polygon on the map
  options.drawSquare = false -- draw a square on the map
  options.drawCircle = false -- draw a circle on the map
  options.eraseDrawing = false -- erase a polygon from the map
  options.stopDrawing = false -- close a polygon started on the map

  options.drawColor = nil
  options.drawFillColor = nil
  options.drawArrow = nil

  -- spawned group/unit type/alias
  options.name = ""

  -- spawned unit name
  options.unitName = nil

  -- spawned group units spacing
  options.spacing = 5

  options.country = nil
  options.side = nil
  options.altitude = 0
  options.altitudedelta = 0
  options.heading = 0
  options.distance = nil
  options.skill = nil

  -- if true, group is part of a road convoy
  options.isConvoy = false

  -- if true, group is patroling between its spawn point and its destination named point
  options.patrol = false

  -- if true, group is set to not follow roads
  options.offroad = false

  -- if set and convoy is true, send the group to the named point
  options.destination = nil

  -- the size of the generated dynamic groups (platoons, convoys, etc.)
  options.size = math.random(7) + 8

  -- defenses force ; ranges from 1 to 5, 5 being the toughest.
  options.defense = math.random(5)

  -- armor force ; ranges from 1 to 5, 5 being the strongest and most modern.
  options.armor = math.random(5)

  -- bomb power
  options.power = 100

  -- smoke color
  options.smokeColor = trigger.smokeColor.RED

  -- optional cargo smoke
  options.cargoSmoke = false

  -- cargo type
  options.cargoType = "container_cargo"
  options.cargoWeightBias = 2 --weight bias of the cargo, if equal to 0, cargo will be very close to minimum weight, if equal to 5, cargo will be close to maximum

  options.password = nil

  --AFAC spawn option
  options.afac = false
  options.immortal = false

  -- JTAC radio comms
  options.freq = veafSpawn.convertLaserToFreq(options.laserCode)
  options.mod = "fm"

  -- TACAN name and channel
  options.tacanChannel = nil
  options.tacanBand = nil

  -- repeat options
  options.repeatCount = nil
  options.repeatDelay = nil

  -- delayed start option
  options.delayedStart = 0

  -- Check for correct keywords.
  if text:lower():find(veafSpawn.SpawnKeyphrase .. " unit") then
    options.unit = true
  elseif text:lower():find(veafSpawn.SpawnKeyphrase .. " afac") then
    options.afac = true
    --default country for the AFAC
    options.country = "USA"
    --default AFAC spawned
    options.name = "mq-9"
  elseif text:lower():find(veafSpawn.SpawnKeyphrase .. " cap") then
    options.cap = true
  elseif text:lower():find(veafSpawn.SpawnKeyphrase .. " group") then
    options.group = true
  elseif text:lower():find(veafSpawn.SpawnKeyphrase .. " farp") then
    options.farp = true
  elseif text:lower():find(veafSpawn.SpawnKeyphrase .. " fob") then
    options.fob = true
  elseif text:lower():find(veafSpawn.SpawnKeyphrase .. " convoy") then
    options.convoy = true
    options.size = 10 -- default the size parameter to 10
  elseif text:lower():find(veafSpawn.SpawnKeyphrase .. " infantrygroup") then
    options.infantryGroup = true
  elseif text:lower():find(veafSpawn.SpawnKeyphrase .. " armorgroup") then
    options.armoredPlatoon = true
  elseif text:lower():find(veafSpawn.SpawnKeyphrase .. " samgroup") then
    options.airDefenseBattery = true
  elseif text:lower():find(veafSpawn.SpawnKeyphrase .. " transportgroup") then
    options.transportCompany = true
    options.size = math.random(2, 5)
  elseif text:lower():find(veafSpawn.SpawnKeyphrase .. " combatgroup") then
    options.fullCombatGroup = true
    options.size = 1 -- default the size parameter to 1
  elseif text:lower():find(veafSpawn.SpawnKeyphrase .. " smoke") then
    options.smoke = true
  elseif text:lower():find(veafSpawn.SpawnKeyphrase .. " flare") then
    options.flare = true
  elseif text:lower():find(veafSpawn.SpawnKeyphrase .. " signal") then
    options.signal = true
  elseif text:lower():find(veafSpawn.SpawnKeyphrase .. " cargo") then
    options.cargo = true
  elseif text:lower():find(veafSpawn.SpawnKeyphrase .. " logistic") then
    options.logistic = true
  elseif text:lower():find(veafSpawn.SpawnKeyphrase .. " bomb") then
    options.bomb = true
  elseif text:lower():find(veafSpawn.SpawnKeyphrase .. " jtac") then
    options.role = "jtac"
    options.unit = true
    -- default country for friendly JTAC: USA
    options.country = "USA"
    -- default name for JTAC
    options.name = "LUV HMMWV Jeep"
    -- default JTAC name (will overwrite previous unit with same name)
    options.unitName = "JTAC1"
  elseif text:lower():find(veafSpawn.SpawnKeyphrase .. " tacan") then
    options.role = "tacan"
    options.unit = true
    -- default country for friendly tacan: USA
    options.country = "USA"
    -- default name for tacan
    options.name = "TACAN_beacon"
    -- default name (will overwrite previous unit with same name)
    options.unitName = "TACAN TCN"
  elseif text:lower():find(veafSpawn.DestroyKeyphrase) then
    options.destroy = true
  elseif text:lower():find(veafSpawn.TeleportKeyphrase) then
    options.teleport = true
  elseif text:lower():find(veafSpawn.DrawingKeyphrase .. " add") then
    options.addDrawing = true
  elseif text:lower():find(veafSpawn.DrawingKeyphrase .. " erase") then
    options.eraseDrawing = true
  elseif text:lower():find(veafSpawn.DrawingKeyphrase .. " square") then
    options.drawSquare = true
  elseif text:lower():find(veafSpawn.DrawingKeyphrase .. " circle") then
    options.drawCircle = true
  elseif text:lower():find(veafSpawn.MissionMasterKeyphrase .. " flagon") then
    options.mmFlagOn = true
  elseif text:lower():find(veafSpawn.MissionMasterKeyphrase .. " flagoff") then
    options.mmFlagOff = true
  elseif text:lower():find(veafSpawn.MissionMasterKeyphrase .. " getflag") then
    options.mmGetFlag = true
  elseif text:lower():find(veafSpawn.MissionMasterKeyphrase .. " run") then
    options.mmRun = true
  else
    return nil
  end

  -- keywords are split by ","
  local keywords = veaf.split(text, ",")

  for _, keyphrase in pairs(keywords) do
    -- Split keyphrase by space. First one is the key and second, ... the parameter(s) until the next comma.
    local str = veaf.breakString(veaf.trim(keyphrase), " ")
    local key = str[1]
    local val = str[2] or ""

    if key:lower() == "unitname" then
      -- Set name.
      veaf.loggers.get(veafSpawn.Id):trace(string.format("Keyword unitname = %s", tostring(val)))
      options.unitName = val
    end

    if key:lower() == "name" then
      -- Set name.
      veaf.loggers.get(veafSpawn.Id):trace(string.format("Keyword name = %s", tostring(val)))
      options.name = val
    end

    if key:lower() == "czname" then
      -- Set name.
      veaf.loggers.get(veafSpawn.Id):trace(string.format("Keyword czname = %s", tostring(val)))
      options.czName = val
    end

    if key:lower() == "destination" or key:lower() == "dest" then
      -- Set destination.
      veaf.loggers.get(veafSpawn.Id):trace(string.format("Keyword destination = %s", tostring(val)))
      options.destination = val
      options.AlarmState = 0 --since some units will not move when they are told to have an alarm state red, it's best to by default leave it on auto. AI is pretty all knowing anyways, it knows when it should go to red state
      options.spacing = 1 --compress the convoy to not make it extremely long at departure
      options.radius = 1 --convoy spawns on the marker exactly to not have them spawn in trees etc.
    end

    if key:lower() == "isconvoy" then
      veaf.loggers.get(veafSpawn.Id):trace("Keyword isconvoy found")
      options.convoy = true
    end

    if key:lower() == "patrol" then
      veaf.loggers.get(veafSpawn.Id):trace("Keyword patrol found")
      options.patrol = true
    end

    if key:lower() == "offroad" then
      veaf.loggers.get(veafSpawn.Id):trace("Keyword offroad found")
      options.offroad = true
    end

    if key:lower() == "skynet" then
      -- Retreive the name of the IADS you wish to add the spawned group to
      veaf.loggers.get(veafSpawn.Id):trace(string.format("Keyword skynet = %s", tostring(val)))
      options.skynet = val:lower()
      if options.skynet == "" or options.skynet == "true" then
        options.skynet = true
      elseif options.skynet == "false" then
        options.skynet = false
      end
    end

    if key:lower() == "ewr" then
      -- Set force IADS EWR toggle for unit spawn
      veaf.loggers.get(veafSpawn.Id):trace(string.format("Keyword ewr found"))
      options.forceEwr = true
    end

    if key:lower() == "pointdefense" then
      -- Tells IADS to add the spawned SAM to the point defenses of the specified site or to the nearest site
      veaf.loggers.get(veafSpawn.Id):trace(string.format("Keyword pointdefense found"))
      options.pointDefense = true
      if val ~= "" then
        veaf.loggers.get(veafSpawn.Id):trace(string.format("groupName specified : %s", tostring(val)))
        options.pointDefense = tostring(val)
      end
    end

    --to be placed after the skynet input, SAMs in the skynet network work better if set to AlarmState RED, so AlarmState is equal to 2 if skynet is enabled
    if key:lower() == "alarm" then
      -- Set Alarm State of the unit to be spawned
      veaf.loggers.get(veafSpawn.Id):trace(string.format("Keyword alarm = %s", tostring(val)))
      if (val == "0" or val == "2" or val == "1") and not options.skynet then
        options.AlarmState = tonumber(val)
      end
    end

    if key:lower() == "radius" then
      -- Set name.
      veaf.loggers.get(veafSpawn.Id):trace(string.format("Keyword radius = %s", tostring(val)))
      local nVal = veaf.getRandomizableNumeric(val)
      options.radius = nVal
    end

    if key:lower() == "spacing" then
      -- Set spacing.
      veaf.loggers.get(veafSpawn.Id):trace(string.format("Keyword spacing = %s", tostring(val)))
      local nVal = veaf.getRandomizableNumeric(val)
      options.spacing = nVal
    end

    if key:lower() == "multiplier" then
      -- Set multiplier.
      veaf.loggers.get(veafSpawn.Id):trace(string.format("Keyword multiplier = %s", tostring(val)))
      local nVal = veaf.getRandomizableNumeric(val)
      options.multiplier = nVal
    end

    if key:lower() == "alt" then
      -- Set altitude.
      veaf.loggers.get(veafSpawn.Id):trace(string.format("Keyword alt = %s", tostring(val)))
      local nVal = veaf.getRandomizableNumeric(val)
      options.altitude = nVal
    end

    if key:lower() == "altdelta" then
      -- Set altitude delta.
      veaf.loggers.get(veafSpawn.Id):trace(string.format("Keyword altdelta = %s", tostring(val)))
      local nVal = veaf.getRandomizableNumeric(val)
      options.altitudedelta = nVal
    end

    if key:lower() == "speed" then
      -- Set speed.
      veaf.loggers.get(veafSpawn.Id):trace(string.format("Keyword speed = %s", tostring(val)))
      local nVal = veaf.getRandomizableNumeric(val)
      options.speed = nVal
    end

    if key:lower() == "capradius" then
      -- Set capradius.
      veaf.loggers.get(veafSpawn.Id):trace(string.format("Keyword capradius = %s", tostring(val)))
      local nVal = veaf.getRandomizableNumeric(val)
      options.capradius = nVal
    end

    if key:lower() == "shells" then
      -- Set altitude.
      veaf.loggers.get(veafSpawn.Id):trace(string.format("Keyword shells = %s", tostring(val)))
      local nVal = veaf.getRandomizableNumeric(val)
      options.shells = nVal
    end

    if key:lower() == "hdg" then
      -- Set heading.
      veaf.loggers.get(veafSpawn.Id):trace(string.format("Keyword hdg = %s", tostring(val)))
      local nVal = veaf.getRandomizableNumeric(val)
      options.heading = nVal
    end

    if key:lower() == "heading" then
      -- Set heading.
      veaf.loggers.get(veafSpawn.Id):trace(string.format("Keyword heading = %s", tostring(val)))
      local nVal = veaf.getRandomizableNumeric(val)
      options.heading = nVal
    end

    if key:lower() == "country" then
      -- Set country
      veaf.loggers.get(veafSpawn.Id):trace(string.format("Keyword country = %s", tostring(val)))
      options.country = val:upper()
    end

    if key:lower() == "side" then
      -- Set side
      veaf.loggers.get(veafSpawn.Id):trace(string.format("Keyword side = %s", tostring(val)))
      if val:upper() == "BLUE" then
        options.side = veafCasMission.SIDE_BLUE
      else
        options.side = veafCasMission.SIDE_RED
      end
    end

    if key:lower() == "password" then
      -- Unlock the command
      veaf.loggers.get(veafSpawn.Id):trace(string.format("Keyword password", tostring(val)))
      options.password = val
    end

    if key:lower() == "power" then
      -- Set bomb power.
      veaf.loggers.get(veafSpawn.Id):trace(string.format("Keyword power = %s", tostring(val)))
      local nVal = veaf.getRandomizableNumeric(val)
      options.power = nVal
    end

    if key:lower() == "laser" then
      -- Set laser code.
      veaf.loggers.get(veafSpawn.Id):trace(string.format("laser code = %s", tostring(val)))
      local nVal = veaf.getRandomizableNumeric(val)
      options.freq = veafSpawn.convertLaserToFreq(nVal)
      options.laserCode = nVal
    end

    if key:lower() == "freq" then
      -- Set JTAC/AFAC frequency.
      veaf.loggers.get(veafSpawn.Id):trace(string.format("freq = %s", tostring(val)))
      options.freq = val
    end

    if key:lower() == "mod" then
      -- Set JTAC/AFAC modulation.
      veaf.loggers.get(veafSpawn.Id):trace(string.format("mod = %s", tostring(val)))
      options.mod = val
    end

    if key:lower() == "band" then
      -- Set TACAN band
      veaf.loggers.get(veafSpawn.Id):trace(string.format("band = %s", tostring(val)))
      options.tacanBand = val
    end

    if key:lower() == "code" then
      -- Set TACAN code
      veaf.loggers.get(veafSpawn.Id):trace(string.format("code = %s", tostring(val)))
      options.tacanCode = val
    end

    if key:lower() == "channel" then
      -- Set TACAN channel.
      veaf.loggers.get(veafSpawn.Id):trace(string.format("channel = %s", tostring(val)))
      local nVal = veaf.getRandomizableNumeric(val)
      options.tacanChannel = nVal
    end

    if key:lower() == "arrow" then
      veaf.loggers.get(veafSpawn.Id):trace(string.format("Keyword arrow = %s", tostring(val)))
      options.drawArrow = true
    end
    if key:lower() == "fill" then
      veaf.loggers.get(veafSpawn.Id):trace(string.format("Keyword fill = %s", tostring(val)))
      options.drawFillColor = val
    end

    if key:lower() == "color" then
      veaf.loggers.get(veafSpawn.Id):trace(string.format("Keyword color = %s", tostring(val)))
      options.drawColor = val
      -- Set smoke color.
      if val:lower() == "red" then
        options.smokeColor = trigger.smokeColor.RED
      elseif val:lower() == "green" then
        options.smokeColor = trigger.smokeColor.GREEN
      elseif val:lower() == "orange" then
        options.smokeColor = trigger.smokeColor.ORANGE
      elseif val:lower() == "blue" then
        options.smokeColor = trigger.smokeColor.BLUE
      elseif val:lower() == "white" then
        options.smokeColor = trigger.smokeColor.WHITE
      end
    end

    if key:lower() == "skill" then
      veaf.loggers.get(veafSpawn.Id):trace(string.format("Keyword skill = %s", tostring(val)))
      options.skill = val
    end

    if key:lower() == "dist" or key:lower() == "distance" then
      -- Set distance.
      veaf.loggers.get(veafSpawn.Id):trace(string.format("Keyword distance = %s", tostring(val)))
      local nVal = veaf.getRandomizableNumeric(val)
      options.distance = nVal
    end

    if options.cargo and key:lower() == "name" then
      -- Set cargo type.
      veaf.loggers.get(veafSpawn.Id):trace(string.format("Keyword name = %s", tostring(val)))
      options.cargoType = val
    end

    if options.cargo and key:lower() == "weight" then
      -- Set cargo type.
      veaf.loggers.get(veafSpawn.Id):trace(string.format("Keyword weight = %s", tostring(val)))
      local nVal = veaf.getRandomizableNumeric(val)
      if nVal >= 0 and nVal <= veafSpawn.cargoWeightBiasRange then
        options.cargoWeightBias = nVal
      elseif nVal > veafSpawn.cargoWeightBiasRange then
        options.cargoWeightBias = veafSpawn.cargoWeightBiasRange
      elseif nVal < 0 then
        options.cargoWeightBias = 0
      end
    end

    if key:lower() == "type" then
      -- Set farp type.
      veaf.loggers.get(veafSpawn.Id):trace(string.format("Keyword type = %s", tostring(val)))
      options.type = val
    end

    if options.farp and key:lower() == "nofarpmarkers" then
      -- Skip the invisible FARP special vehicles that mark the position of the FARP
      veaf.loggers.get(veafSpawn.Id):trace("Keyword noFarpMarkers is set")
      options.noFarpMarkers = true
    end

    if options.cargo and key:lower() == "smoke" then
      -- Mark with green smoke.
      veaf.loggers.get(veafSpawn.Id):trace("Keyword smoke is set")
      options.cargoSmoke = true
    end

    if key:lower() == "size" then
      -- Set size.
      veaf.loggers.get(veafSpawn.Id):trace(string.format("Keyword size = %s", tostring(val)))
      local nVal = veaf.getRandomizableNumeric(val)
      options.size = nVal
    end

    if key:lower() == "defense" then
      -- Set defense.
      veaf.loggers.get(veafSpawn.Id):trace(string.format("Keyword defense = %s", tostring(val)))
      local nVal = veaf.getRandomizableNumeric(val)
      if nVal >= 0 then
        options.defense = nVal
      end
    end

    if key:lower() == "armor" then
      -- Set armor.
      veaf.loggers.get(veafSpawn.Id):trace(string.format("Keyword armor = %s", tostring(val)))
      local nVal = veaf.getRandomizableNumeric(val)
      if nVal >= 0 then
        options.armor = nVal
      end
    end

    if key:lower() == "repeat" then
      -- Set repeat count.
      veaf.loggers.get(veafSpawn.Id):trace(string.format("Keyword repeat = %s", tostring(val)))
      local nVal = veaf.getRandomizableNumeric(val)
      options.repeatCount = nVal
    end

    if key:lower() == "delay" then
      -- Set delay.
      veaf.loggers.get(veafSpawn.Id):trace(string.format("Keyword delay = %s", tostring(val)))
      local nVal = veaf.getRandomizableNumeric(val)
      options.repeatDelay = nVal
    end

    if key:lower() == "static" then
      -- Set static unit spawn toggle
      veaf.loggers.get(veafSpawn.Id):trace(string.format("Keyword static found"))
      options.forceStatic = true
    end

    if key:lower() == "immortal" then
      -- Set spawned unit to invisible and immortal
      veaf.loggers.get(veafSpawn.Id):trace(string.format("Keyword immortal found"))
      options.immortal = true
    end

    if key:lower() == "delayed" then
      -- Set delayed start on first spawn occurence
      veaf.loggers.get(veafSpawn.Id):trace(string.format("Keyword delayed = %s", tostring(val)))
      local nVal = veaf.getRandomizableNumeric(val)
      if nVal >= 0 then
        options.delayedStart = nVal
      else
        options.delayedStart = veafSpawn.MIN_REPEAT_DELAY
      end
    end

    if key:lower() == "showmfd" then
      -- Set hiddenOnMFD option or not
      veaf.loggers.get(veafSpawn.Id):trace(string.format("Keyword showmfd found"))
      options.showMFD = true
    end

    if key:lower() == "disperse" then
      -- Set hiddenOnMFD option or not
      veaf.loggers.get(veafSpawn.Id):trace(string.format("Keyword disperse = %s", tostring(val)))
      local nVal = veaf.getRandomizableNumeric(val)
      if nVal >= 0 then
        options.disperse = nVal
      end
    end
  end

  -- check mandatory parameter "name" for command "group"
  if options.group and not options.name then
    return nil
  end

  -- check mandatory parameter "name" for command "unit"
  if options.unit and not options.name then
    return nil
  end

  -- check mandatory parameter "name" for all mission master commands
  if (options.mmFlagOff or options.mmFlagOn or options.mmRun) and not options.name then
    return nil
  end

  return options
end

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
    veaf.loggers.getSpawn(veaf.Id):warn(message)
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
-- initialisation
-------------------------------------------------------------------------------------------------------------------------------------------------------------

function veafSpawn.initialize()
  veafSpawn.buildRadioMenu()
  veafSpawn.initializeAirUnitTemplates()
  veafMarkers.registerEventHandler(veafMarkers.MarkerChange, veafSpawn.onEventMarkChange)
  veafSpawn.dumpSpawnablePlanesList()
end

veaf.loggers.get(veafSpawn.Id):info(veaf.loggers.get(veafSpawn.Id):getVersionInfo(veafSpawn.Version))

veaf.registerModule(veafSpawn.Id, veafSpawn.initialize, { enable = true }, 70)
