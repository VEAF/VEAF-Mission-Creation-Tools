------------------------------------------------------------------
-- VEAF transport mission command and functions for DCS World
-- By zip (2018)
--
-- Features:
-- ---------
-- * Listen to marker change events and creates a transport training mission, with optional parameters
-- * Possibilities :
-- *    - create a zone with cargo to pick up, another with friendly troops awaiting their cargo, and optionaly enemy units on the way
--
-- See the documentation : https://veaf.github.io/documentation/
------------------------------------------------------------------

veafTransportMission = {}

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Global settings. Stores the script constants
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Identifier. All output in DCS.log will start with this.
veafTransportMission.Id = "TRANSPORTMISSION"

-- trace level, specific to this module
--veafTransportMission.LogLevel = "trace"

veaf.loggers.new(veafTransportMission.Id, veafTransportMission.LogLevel)

--- Key phrase to look for in the mark text which triggers the command.
veafTransportMission.Keyphrase = "_transport"

veafTransportMission.CargoTypes = { "ammo_cargo", "barrels_cargo", "m117_cargo", "oiltank_cargo", "uh1h_cargo" } --, "container_cargo", "fueltank_cargo" }

--- Number of seconds between each check of the friendly group ADF loop function
veafTransportMission.SecondsBetweenAdfLoops = 30

--- Number of seconds between each check of the friendly group watchdog function
veafTransportMission.SecondsBetweenWatchdogChecks = 15

--- Number of seconds between each smoke request on the target
veafTransportMission.SecondsBetweenSmokeRequests = 180

--- Number of seconds between each flare request on the target
veafTransportMission.SecondsBetweenFlareRequests = 120

--- Name of the friendly group that waits for the cargo
veafTransportMission.BlueGroupName = "Transport - Allied Group"

--- Name of the cargo units
veafTransportMission.BlueCargoName = "Cargo - Cargo unit"

--- Name of the enemy group that defends the way to the friendlies
veafTransportMission.RedDefenseGroupName = "Cargo - Enemy Air Defense Group"

--- Name of the enemy group that blocades the friendlies
veafTransportMission.RedBlocadeGroupName = "Cargo - Enemy Blocade Group"

veafTransportMission.RadioMenuName = "menu.transportmission.root"

veafTransportMission.AdfRadioSound = "l10n/DEFAULT/beacon.ogg"

veafTransportMission.AdfFrequency = 550000 -- in hz

veafTransportMission.AdfPower = 1000 -- in Watt

veafTransportMission.DoRadioTransmission = false -- set to true when radio transmissions will work

-- minimum authorized route distance ; missions shorter than this will not be authorized
veafTransportMission.MinimumRouteDistance = 15000 -- 15 km

-- size of the safe zone (no enemy group before this distance, in % of the total distance)
veafTransportMission.SafeZoneDistance = 0.6 -- 60%

-- size of the sqfe zone near drop zone (no enemy group after this distance from the drop zone)
veafTransportMission.DropZoneSafeZoneDistance = 5000 -- 5 km

-- an enemy group every xxx meters of the way (randomized)
veafTransportMission.EnemyDefenseDistanceStep = 3000

-- enemies groups generated along the way are offset to xxx meters max (left or right, randomized)
veafTransportMission.LeftOrRightMaxOffset = 1500

-- enemies groups generated along the way are offset to xxx meters min (left or right, randomized)
veafTransportMission.LeftOrRightMinOffset = 500

-- enemies groups generated far from the way are offset to xxx meters max (left or right, randomized)
veafTransportMission.LeftOrRightMaxFarOffset = 7000

-- enemies groups generated far from the way are offset to xxx meters min (left or right, randomized)
veafTransportMission.LeftOrRightMinFarOffset = 3000

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Do not change anything below unless you know what you are doing!
-------------------------------------------------------------------------------------------------------------------------------------------------------------

-- Friendly group watchdog function id
veafTransportMission.friendlyGroupAliveCheckTaskID = "none"

-- Friendly group ADF transmission loop function id
veafTransportMission.friendlyGroupAdfLoopTaskID = "none"

--- Radio menus paths
veafTransportMission.targetMarkersPath = nil
veafTransportMission.targetInfoPath = nil
veafTransportMission.rootPath = nil

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Utility methods
-------------------------------------------------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Event handler functions.
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Function executed when a mark has changed. This happens when text is entered or changed.
function veafTransportMission.onEventMarkChange(eventPos, event)
  -- Check if marker has a text and the veafTransportMission.keyphrase keyphrase.
  if event.text ~= nil and event.text:lower():find(veafTransportMission.Keyphrase) then
    -- Analyse the mark point text and extract the keywords.
    local options = veafTransportMission.markTextAnalysis(event.text)

    if options then
      -- A typo aborts — see veaf.reportUnknownParameters. nil: this handler is not given the requester.
      if veaf.reportUnknownParameters(options, veafTransportMission.Id, nil) then
        return false
      end
      -- Check options commands
      if options.transportmission then
        -- Check security. The marker id is what identifies the author, so a listed pilot's own
        -- level can grant the command; without it `getMarkerSecurityLevel` returns -1 and the
        -- password is the only way through, whoever asks.
        if not veafSecurity.checkSecurity_L1(options.password, event.idx) then
          return
        end
        -- create the mission
        veafTransportMission.generateTransportMission(eventPos, options.size, options.defense, options.blocade, options.from)
      end
    else
      -- None of the keywords matched.
      return
    end

    -- Delete old mark.
    veaf.loggers.get(veafTransportMission.Id):trace(string.format("Removing mark # %d.", event.idx))
    trigger.action.removeMark(event.idx)
  end
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Analyse the mark text and extract keywords.
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- The transport module's marker specification, read by `veaf.parseMarkerText`.
---
--- REFACTOR-MARKER-PARSER ticket 03. The bounds are asymmetric on purpose and unchanged: `size`
--- counts cargo so it starts at 1, while `defense` and `blocade` describe cover and blockade
--- strength where 0 means none. Out-of-range values stay *ignored* rather than clamped, which is
--- what `veaf.markerRules.boundedNumber` provides and what `VMR-019` settled on for the twin
--- parameters in veafCasMission.
---
--- The four `if switch.transportmission and ...` guards the old loop carried are gone rather than
--- translated into `when` predicates: the flag is set before the loop and the function returns nil
--- when the keyphrase is absent, so all four were always true.
veafTransportMission.MarkerSpec = {
  reportUnknownKeys = true,

  defaults = function(options)
    options.transportmission = false
    options.size = 1 -- number of cargo to be transported
    options.defense = 0 -- air defense cover on the way (1 = light, 5 = heavy)
    options.blocade = 0 -- enemy blocade around the drop zone (1 = light, 5 = heavy)
    options.from = nil -- start position, named point
    options.password = nil
  end,
  commands = {
    {
      match = veafTransportMission.Keyphrase,
      init = function(options)
        options.transportmission = true
      end,
    },
  },
  parameters = {
    { keys = { "password" }, apply = veaf.markerRules.text("password") },
    { keys = { "size" }, apply = veaf.markerRules.boundedNumber("size", 1, 5) },
    { keys = { "defense" }, apply = veaf.markerRules.boundedNumber("defense", 0, 5) },
    { keys = { "blocade" }, apply = veaf.markerRules.boundedNumber("blocade", 0, 5) },
    { keys = { "from" }, apply = veaf.markerRules.text("from") },
  },
  valueWhenAbsent = nil,
}

--- Extract keywords from mark text.
function veafTransportMission.markTextAnalysis(text)
  return veaf.parseMarkerText(text, veafTransportMission.MarkerSpec)
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- CAS target group generation and management
-------------------------------------------------------------------------------------------------------------------------------------------------------------

function veafTransportMission.doRadioTransmission(groupName)
  veaf.loggers.get(veafTransportMission.Id):trace("doRadioTransmission(" .. groupName .. ")")
  local group = Group.getByName(groupName)
  if group then
    veaf.loggers.get(veafTransportMission.Id):trace("Group is transmitting")
    local averageGroupPosition = veaf.getAveragePosition(groupName)
    ---@cast averageGroupPosition vec3
    veaf.loggers.get(veafTransportMission.Id):trace("averageGroupPosition=" .. veaf.vecToString(averageGroupPosition))
    ---@diagnostic disable-next-line: param-type-mismatch
    trigger.action.radioTransmission(
      veafTransportMission.AdfRadioSound,
      averageGroupPosition,
      0,
      false,
      veafTransportMission.AdfFrequency,
      veafTransportMission.AdfPower
    )
  end

  veafTransportMission.friendlyGroupAdfLoopTaskID = veaf.scheduleFunction(
    veafTransportMission.doRadioTransmission,
    { groupName },
    timer.getTime() + veafTransportMission.SecondsBetweenAdfLoops
  )
end

function veafTransportMission.generateFriendlyGroup(groupPosition)
  veafSpawn.doSpawnGroup(groupPosition, 0, "US infgroup", nil, "USA", 0, 0, 0, veafTransportMission.BlueGroupName, true, false, true, true)

  if veafTransportMission.DoRadioTransmission then
    veafTransportMission.doRadioTransmission(veafTransportMission.BlueGroupName)
  end
end

--- Generates an enemy defense group on the way to the drop zone
--- defenseLevel = 1 : 3-7 soldiers, GAZ-3308 transport
--- defenseLevel = 2 : 3-7 soldiers, BTR-80 APC
--- defenseLevel = 3 : 3-7 soldiers, chance of BMP-1 IFV, chance of Igla manpad
--- defenseLevel = 4 : 3-7 soldiers, big chance of BMP-1 IFV, big chance of Igla-S manpad, chance of ZU-23 on a truck
--- defenseLevel = 5 : 3-7 soldiers, BMP-1 IFV, big chance of Igla-S manpad, chance of ZSU-23-4 Shilka
function veafTransportMission.generateEnemyDefenseGroup(groupPosition, groupName, defenseLevel)
  local groupDefinition = {
    disposition = { h = 6, w = 6 },
    units = {},
    description = groupName,
    groupName = groupName,
  }

  -- generate an infantry group
  local groupCount = math.random(3, 7)
  for _ = 1, groupCount do
    local rand = math.random(3)
    local unitType = nil
    if rand == 1 then
      unitType = "Soldier RPG"
    elseif rand == 2 then
      unitType = "Soldier AK"
    else
      unitType = "Infantry AK"
    end
    table.insert(groupDefinition.units, { unitType })
  end

  -- add a transport vehicle or an APC/IFV
  if defenseLevel > 4 or (defenseLevel > 3 and math.random(100) > 33) or (defenseLevel > 2 and math.random(100) > 66) then
    table.insert(groupDefinition.units, { "BMP-1", cell = 11, random = true })
  elseif defenseLevel > 1 then
    table.insert(groupDefinition.units, { "BTR-80", cell = 11, random = true })
  else
    table.insert(groupDefinition.units, { "GAZ-3308", cell = 11, random = true })
  end

  -- add manpads if needed
  if defenseLevel > 3 and math.random(100) > 33 then
    -- for defenseLevel = 4-5, spawn a modern Igla-S team
    table.insert(groupDefinition.units, { "SA-18 Igla-S comm", random = true })
    table.insert(groupDefinition.units, { "SA-18 Igla-S manpad", random = true })
  elseif defenseLevel > 2 and math.random(100) > 66 then
    -- for defenseLevel = 3, spawn an older Igla team
    table.insert(groupDefinition.units, { "SA-18 Igla comm", random = true })
    table.insert(groupDefinition.units, { "SA-18 Igla manpad", random = true })
  else
    -- for defenseLevel = 0, don't spawn any manpad
  end

  -- add an air defenseLevel vehicle
  if defenseLevel > 4 and math.random(100) > 66 then
    -- defenseLevel = 3-5 : add a Shilka
    table.insert(groupDefinition.units, { "ZSU-23-4 Shilka", cell = 3, random = true })
  elseif defenseLevel > 3 and math.random(100) > 66 then
    -- defenseLevel = 1 : add a ZU23 on a truck
    table.insert(groupDefinition.units, { "Ural-375 ZU-23", cell = 3, random = true })
  end

  groupDefinition = veafUnits.processGroup(groupDefinition)
  veafSpawn.doSpawnGroup(
    groupPosition,
    0,
    groupDefinition,
    nil,
    "RUSSIA",
    0,
    math.random(359),
    math.random(3, 6),
    groupName,
    true,
    false,
    true,
    true
  )
end

--- Generates a transport mission
function veafTransportMission.generateTransportMission(targetSpot, size, defense, blocade, from)
  veaf.loggers.get(veafTransportMission.Id):debug(
    "generateTransportMission(size = %s, defense=%s, blocade=%d, from=%s)",
    veaf.lp(size),
    veaf.lp(defense),
    veaf.lp(blocade),
    veaf.lp(from)
  )
  veaf.loggers.get(veafTransportMission.Id):debug("generateTransportMission: targetSpot ", veaf.lp(targetSpot))

  if veafTransportMission.friendlyGroupAliveCheckTaskID ~= "none" then
    trigger.action.outText(veaf.t("transport.exists"), 5)
    return
  end

  if not from then
    trigger.action.outText(veaf.t("transport.from_mandatory"), 5)
    return
  end

  local startPoint = veafNamedPoints.getPoint(from)
  if not startPoint then
    trigger.action.outText(veaf.t("transport.point_not_found", from), 5)
    return
  end

  local friendlyUnits = {}
  local routeDistance = 0

  -- generate a friendly group around the target target spot
  local groupPosition = veaf.findPointInZone(targetSpot, 100, false)
  if groupPosition ~= nil then
    veaf.loggers.get(veafTransportMission.Id):trace("groupPosition=" .. veaf.vecToString(groupPosition))
    groupPosition = { x = groupPosition.x, z = groupPosition.y, y = 0 }
    groupPosition = veaf.placePointOnLand(groupPosition)
    veaf.loggers.get(veafTransportMission.Id):trace("groupPosition on land=" .. veaf.vecToString(groupPosition))

    -- compute player route to friendly group
    local vecAB = { x = groupPosition.x + -startPoint.x, y = 0, z = groupPosition.z - startPoint.z }
    routeDistance = veaf.vecMag(vecAB)
    veaf.loggers.get(veafTransportMission.Id):trace("routeDistance=" .. routeDistance)
    if routeDistance < veafTransportMission.MinimumRouteDistance then
      trigger.action.outText(veaf.t("transport.dropzone_too_close", veafTransportMission.MinimumRouteDistance / 1000, from), 5)
      return
    end

    veafTransportMission.generateFriendlyGroup(groupPosition)
  else
    veaf.loggers.get(veafTransportMission.Id):info("cannot find a suitable position for friendly group")
    return
  end

  -- generate cargo to be picked up near the player helo
  veaf.loggers.get(veafTransportMission.Id):debug("Generating cargo")
  local startPosition = veaf.placePointOnLand(startPoint)
  veaf.loggers.get(veafTransportMission.Id):trace("startPosition=" .. veaf.vecToString(startPosition))
  for i = 1, size do
    local spawnSpot = { x = startPosition.x + 50, z = startPosition.z + i * 10, y = startPosition.y }
    veaf.loggers.get(veafTransportMission.Id):trace("spawnSpot=" .. veaf.vecToString(spawnSpot))
    local cargoType = veafTransportMission.CargoTypes[math.random(#veafTransportMission.CargoTypes)]
    local cargoName = veafTransportMission.BlueCargoName .. " #" .. i
    veafSpawn.doSpawnCargo(spawnSpot, 0, cargoType, "USA")
  end
  veaf.loggers.get(veafTransportMission.Id):debug("Done generating cargo")

  -- generate enemy air defense on the way
  if defense > 0 then
    veaf.loggers.get(veafTransportMission.Id):debug("Generating air defense")

    -- place groups on the way
    local startingDistance = routeDistance * veafTransportMission.SafeZoneDistance -- enemy presence start after the safe zone
    local defendedDistance = routeDistance - veafTransportMission.DropZoneSafeZoneDistance - startingDistance
    local distanceStep = veafTransportMission.EnemyDefenseDistanceStep
    local nbSteps = math.floor(defendedDistance / distanceStep)
    local groupNum = 1
    for stepNum = 1, nbSteps do
      local distanceFromStartingPoint = startingDistance + stepNum * distanceStep + math.random(distanceStep / 5, 4 * distanceStep / 5)
      veaf.loggers.get(veafTransportMission.Id):trace("distanceFromStartingPoint=" .. distanceFromStartingPoint)

      -- place an enemy defense group along the way
      local offset = math.random(veafTransportMission.LeftOrRightMinOffset, veafTransportMission.LeftOrRightMaxOffset)
      if math.random(100) < 51 then
        offset = -offset
      end
      veaf.loggers.get(veafTransportMission.Id):trace("offset=" .. offset)
      local spawnPoint = veaf.computeCoordinatesOffsetFromRoute(startPoint, groupPosition, distanceFromStartingPoint, offset)
      local groupName = veafTransportMission.RedDefenseGroupName .. " #" .. groupNum
      veafTransportMission.generateEnemyDefenseGroup(spawnPoint, groupName, defense)
      groupNum = groupNum + 1

      -- place a random number of defense groups further away
      local nbFarGroups = math.random(0, 1)
      if defense > 4 then
        nbFarGroups = math.random(1, 3)
      end
      for _ = 1, nbFarGroups do
        local offset = math.random(veafTransportMission.LeftOrRightMinFarOffset, veafTransportMission.LeftOrRightMaxFarOffset)
        if math.random(100) < 51 then
          offset = -offset
        end
        veaf.loggers.get(veafTransportMission.Id):trace("offset=" .. offset)
        local spawnPoint = veaf.computeCoordinatesOffsetFromRoute(startPoint, groupPosition, distanceFromStartingPoint, offset)
        local groupName = veafTransportMission.RedDefenseGroupName .. " #" .. groupNum
        veafTransportMission.generateEnemyDefenseGroup(spawnPoint, groupName, defense)
        groupNum = groupNum + 1
      end
    end

    veaf.loggers.get(veafTransportMission.Id):debug("Done generating air defense")
  end

  -- generate enemy blocade forces
  if blocade > 0 then
    veaf.loggers.get(veafTransportMission.Id):debug("Generating blocade")
    -- TODO
    veaf.loggers.get(veafTransportMission.Id):debug("Done generating blocade")
  end

  -- add radio menu for drop zone information (by player group)
  veafRadio.addCommandToSubmenu(
    veaf.t("menu.transportmission.info"),
    veafTransportMission.rootPath,
    veafTransportMission.reportTargetInformation,
    nil,
    veafRadio.USAGE_ForGroup
  )

  -- add radio menus for commands
  veafRadio.addSecuredCommandToSubmenu(veaf.t("menu.transportmission.skip"), veafTransportMission.rootPath, veafTransportMission.skip)
  veafTransportMission.targetMarkersPath = veafRadio.addSubMenu(veaf.t("menu.transportmission.markers"), veafTransportMission.rootPath)
  veafRadio.addCommandToSubmenu(
    veaf.t("menu.transportmission.request_smoke"),
    veafTransportMission.targetMarkersPath,
    veafTransportMission.smokeTarget
  )
  veafRadio.addCommandToSubmenu(
    veaf.t("menu.transportmission.request_flare"),
    veafTransportMission.targetMarkersPath,
    veafTransportMission.flareTarget
  )

  local message = veaf.t("transport.see_f10") -- TODO
  trigger.action.outText(message, 5)

  veafRadio.refreshRadioMenu()

  -- start checking for targets destruction
  veafTransportMission.friendlyGroupWatchdog()
end

--- Checks if the friendly group is still alive, and if not announces the failure of the transport mission
function veafTransportMission.friendlyGroupWatchdog()
  local nbVehicles, nbInfantry = veafUnits.countInfantryAndVehicles(veafTransportMission.BlueGroupName)
  if nbVehicles + nbInfantry > 0 then
    ----veaf.loggers.get(veafTransportMission.Id):trace("Group is still alive with "..nbVehicles.." vehicles and "..nbInfantry.." soldiers")
    veafTransportMission.friendlyGroupAliveCheckTaskID = veaf.scheduleFunction(
      veafTransportMission.friendlyGroupWatchdog,
      {},
      timer.getTime() + veafTransportMission.SecondsBetweenWatchdogChecks
    )
  else
    trigger.action.outText(veaf.t("transport.failure"), 5)
    veafTransportMission.cleanupAfterMission()
  end
end

function veafTransportMission.reportTargetInformation(unitName)
  -- generate information dispatch
  local nbVehicles, nbInfantry = veafUnits.countInfantryAndVehicles(veafTransportMission.BlueGroupName)

  local message = veaf.t("transport.report_dropzone", nbVehicles, nbInfantry)
  message = message .. "\n"
  if veafTransportMission.DoRadioTransmission then
    message = message .. veaf.t("transport.report_navigation", veafTransportMission.SecondsBetweenAdfLoops)
  end

  -- add coordinates and position from bullseye
  local averageGroupPosition = veaf.getAveragePosition(veafTransportMission.BlueGroupName)
  ---@cast averageGroupPosition vec3
  local lat, lon = coord.LOtoLL(averageGroupPosition)
  local mgrsString = veaf.toStringMGRS(coord.LLtoMGRS(lat, lon), 3)
  local bullseye = veaf.makeVec3(veaf.getBullseye("blue"), 0)
  local vec = { x = averageGroupPosition.x - bullseye.x, y = averageGroupPosition.y - bullseye.y, z = averageGroupPosition.z - bullseye.z }
  local dir = veaf.round(math.deg(veaf.getDir(vec, bullseye)), 0)
  local dist = veaf.get2DDist(averageGroupPosition, bullseye)
  local distMetric = veaf.round(dist / 1000, 0)
  local distImperial = veaf.round(veaf.metersToNM(dist), 0)
  local fromBullseye = veaf.t("report.bullseye_value", dir, distMetric, distImperial)

  message = message .. veaf.t("report.latlon_decimal", veaf.toStringLL(lat, lon, 2))
  message = message .. veaf.t("report.latlon_dms", veaf.toStringLL(lat, lon, 0, true))
  message = message .. veaf.t("report.mgrs", mgrsString)
  message = message .. veaf.t("report.from_bullseye", fromBullseye)
  message = message .. "\n"

  -- get altitude, qfe and wind information
  local altitude = veaf.getLandHeight(averageGroupPosition)
  --local qfeHp = mist.utils.getQFE(averageGroupPosition, false)
  --local qfeinHg = mist.utils.getQFE(averageGroupPosition, true)
  local windDirection, windStrength = veaf.getWind(veaf.placePointOnLand(averageGroupPosition))

  message = message .. veaf.t("transport.report_alt", altitude)
  --message = message .. 'TARGET QFW       : ' .. qfeHp .. " hPa / " .. qfeinHg .. " inHg.\n"
  local windText = veaf.t("transport.wind_none")
  if windStrength > 0 then
    windText = veaf.t("transport.wind_from", windDirection, windStrength)
  end
  message = message .. veaf.t("transport.report_wind", windText)

  -- send message only for the unit
  veaf.outTextForUnit(unitName, message, 30)
end

--- add a smoke marker over the drop zone
function veafTransportMission.smokeTarget()
  veaf.loggers.get(veafTransportMission.Id):debug("smokeTarget()")
  veafSpawn.spawnSmoke(veaf.getAveragePosition(veafTransportMission.BlueGroupName), trigger.smokeColor.Green)
  trigger.action.outText(veaf.t("transport.smoke_requested"), 5)
  veafRadio.delCommand(veafTransportMission.targetMarkersPath, "Request smoke on drop zone")
  veafRadio.addCommandToSubmenu(veaf.t("menu.transportmission.smoke_done"), veafTransportMission.targetMarkersPath, veaf.emptyFunction)
  veafTransportMission.smokeResetTaskID =
    veaf.scheduleFunction(veafTransportMission.smokeReset, {}, timer.getTime() + veafTransportMission.SecondsBetweenSmokeRequests)
  veafRadio.refreshRadioMenu()
end

--- Reset the smoke request radio menu
function veafTransportMission.smokeReset()
  veaf.loggers.get(veafTransportMission.Id):debug("smokeReset()")
  veafRadio.delCommand(veafTransportMission.targetMarkersPath, "Drop zone is marked with GREEN smoke")
  veafRadio.addCommandToSubmenu(
    veaf.t("menu.transportmission.request_smoke"),
    veafTransportMission.targetMarkersPath,
    veafTransportMission.smokeTarget
  )
  trigger.action.outText(veaf.t("transport.smoke_available"), 5)
  veafRadio.refreshRadioMenu()
end

--- add an illumination flare over the target area
function veafTransportMission.flareTarget()
  veaf.loggers.get(veafTransportMission.Id):debug("flareTarget()")
  veafSpawn.spawnIlluminationFlare(veaf.getAveragePosition(veafTransportMission.BlueGroupName))
  trigger.action.outText(veaf.t("transport.illum_requested"), 5)
  veafRadio.delCommand(veafTransportMission.targetMarkersPath, "Request illumination flare over drop zone")
  veafRadio.addCommandToSubmenu(veaf.t("menu.transportmission.flare_done"), veafTransportMission.targetMarkersPath, veaf.emptyFunction)
  veafTransportMission.flareResetTaskID =
    veaf.scheduleFunction(veafTransportMission.flareReset, {}, timer.getTime() + veafTransportMission.SecondsBetweenFlareRequests)
  veafRadio.refreshRadioMenu()
end

--- Reset the flare request radio menu
function veafTransportMission.flareReset()
  veaf.loggers.get(veafTransportMission.Id):debug("flareReset()")
  veafRadio.delCommand(veafTransportMission.targetMarkersPath, "Drop zone is lit with illumination flare")
  veafRadio.addCommandToSubmenu(
    veaf.t("menu.transportmission.request_flare"),
    veafTransportMission.targetMarkersPath,
    veafTransportMission.flareTarget
  )
  trigger.action.outText(veaf.t("transport.illum_available"), 5)
  veafRadio.refreshRadioMenu()
end

--- Called from the "Skip delivery" radio menu : remove the current transport mission
function veafTransportMission.skip()
  veafTransportMission.cleanupAfterMission()
  trigger.action.outText(veaf.t("transport.cleaned"), 5)
end

--- Cleanup after either mission is ended or aborted
function veafTransportMission.cleanupAfterMission()
  veaf.loggers.get(veafTransportMission.Id):trace("cleanupAfterMission()")

  -- destroy groups
  veaf.loggers.get(veafTransportMission.Id):trace("destroy friendly group")
  local group = Group.getByName(veafTransportMission.BlueGroupName)
  if group and group:isExist() == true then
    group:destroy()
  end

  veaf.loggers.get(veafTransportMission.Id):trace("destroy cargos")
  local unitNum = 1
  local doIt = true
  while doIt do
    local cargo = StaticObject.getByName(veafTransportMission.BlueCargoName .. " #" .. unitNum)
    if cargo and cargo:isExist() == true then
      cargo:destroy()
      unitNum = unitNum + 1
    else
      doIt = false
    end
  end

  veaf.loggers.get(veafTransportMission.Id):trace("destroy enemy defense group")
  local groupNum = 1
  local doIt = true
  while doIt do
    group = Group.getByName(veafTransportMission.RedDefenseGroupName .. " #" .. groupNum)
    if group and group:isExist() == true then
      group:destroy()
      groupNum = groupNum + 1
    else
      doIt = false
    end
  end

  veaf.loggers.get(veafTransportMission.Id):trace("destroy enemy blocade group")
  group = Group.getByName(veafTransportMission.RedBlocadeGroupName)
  if group and group:isExist() == true then
    group:destroy()
  end

  -- remove the watchdog function
  veaf.loggers.get(veafTransportMission.Id):trace("remove the watchdog function")
  if veafTransportMission.friendlyGroupAliveCheckTaskID ~= "none" then
    veaf.removeFunction(veafTransportMission.friendlyGroupAliveCheckTaskID)
  end
  veafTransportMission.friendlyGroupAliveCheckTaskID = "none"

  -- remove the watchdog function
  veaf.loggers.get(veafTransportMission.Id):trace("remove the adf loop function")
  if veafTransportMission.friendlyGroupAdfLoopTaskID ~= "none" then
    veaf.removeFunction(veafTransportMission.friendlyGroupAdfLoopTaskID)
  end
  veafTransportMission.friendlyGroupAdfLoopTaskID = "none"

  veafRadio.delCommand(veafTransportMission.rootPath, "Skip current objective")
  veafRadio.delCommand(veafTransportMission.rootPath, "Get current objective situation")
  veafRadio.delCommand(veafTransportMission.rootPath, "Drop zone markers")
  veafRadio.delSubmenu(veafTransportMission.targetMarkersPath, veafTransportMission.rootPath)

  veafRadio.refreshRadioMenu()
  veaf.loggers.get(veafTransportMission.Id):trace("cleanupAfterMission DONE")
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Radio menu and help
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Build the initial radio menu
function veafTransportMission.buildRadioMenu()
  veafTransportMission.rootPath = veafRadio.addSubMenu(veaf.t(veafTransportMission.RadioMenuName))
  veafRadio.addCommandToSubmenu(
    veaf.t("menu.common.help"),
    veafTransportMission.rootPath,
    veafTransportMission.help,
    nil,
    veafRadio.USAGE_ForGroup
  )
end

function veafTransportMission.help(unitName)
  veaf.outTextForUnit(unitName, veaf.t("transport.help"), 30)
end

function veafTransportMission.endTransportOfCargo(cargoName)
  trigger.action.outText(veaf.t("transport.cargo_delivered", cargoName), 15)
  -- TODO reset cargo position
  -- mist.respawnGroup(cargoName, 15)
  -- does not work yet because 1. the unit name is changed by mist and 2. the trigger zone condition does not work with the new unit (maybe bc of 1. ?)
end

-- initializeAllHelosInCTLD pointed at a CTLD v1 helper (ctld.autoInitializeAllHumanTransports)
-- that VEAF defined and CTLD 2 does not have. It is kept as a deprecation stub for mission
-- scripts that still call it, and names the replacement: a transport is any aircraft type with
-- a capabilitiesByType entry, declared in the mission's ctld-config.yaml — nothing to run.
--
-- initializeAllLogisticInCTLD is no longer a stub. CTLD 2 does discover the logistic zones a
-- maker declares — LGZ_ trigger zones, logisticUnits, logisticUnitTypes — but none of those
-- three routes can carry an airbase, and the fourth (registerFOBAsLogistic) is runtime-only:
-- airfields are outside CTLD's logistic system, and always were (FEAT-CTLD-AIRBASE-LOGISTICS,
-- answering #1007). So VEAF registers every airdrome of
-- the theatre itself, through that public API, below.

function veafTransportMission.initializeAllHelosInCTLD()
  veaf.loggers
    .get(veafTransportMission.Id)
    :warn("Obsolete: CTLD 2 recognises a transport by its capabilitiesByType entry in ctld-config.yaml")
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Airbase logistics (FEAT-CTLD-AIRBASE-LOGISTICS)
-------------------------------------------------------------------------------------------------------------------------------------------------------------

-- The three numbers this lot exposes in mission.yaml under modules.CTLD, read from veaf.config —
-- the generator emits any the maker sets there — with these defaults as the fallback. They are
-- RESOLVED IN initializeAllLogisticInCTLD, never at file load: veaf-config.lua populates veaf.config
-- only after every module file has been loaded, so a top-level read here would always see nil and
-- silently keep the default. Each name below is a plain upvalue the whole section shares; the
-- resolver reassigns them once per initialisation and every function then reads the resolved value,
-- so none of the three is a constant at its call site.
local AIRBASE_LOGISTICS_RADIUS_DEFAULT = 250 -- metres of logistic zone around each airfield's stand
local AIRBASE_OCCUPATION_RADIUS_DEFAULT = 2000 -- metres a class-B field probes for ground units; class A never probes
local AIRBASE_LOGISTICS_TICK_SECONDS_DEFAULT = 30 -- seconds between two evaluations of every airfield

local AIRBASE_LOGISTICS_RADIUS = AIRBASE_LOGISTICS_RADIUS_DEFAULT
local AIRBASE_OCCUPATION_RADIUS = AIRBASE_OCCUPATION_RADIUS_DEFAULT
local AIRBASE_LOGISTICS_TICK_SECONDS = AIRBASE_LOGISTICS_TICK_SECONDS_DEFAULT

-- Continuous seconds ground troops must hold a class-B airfield before it becomes a logistic point,
-- and the hysteresis that keeps a contested field from flapping. This one is NOT a setting: two
-- minutes is the rule, not a tunable. It is measured on the mission clock (`timer.getTime()`), from
-- the first tick that saw the occupier to the tick that opens the zone — never as a count of ticks,
-- which would only equal two minutes when the interval divides 120 exactly (a 45 s tick floored to
-- two ticks opened after 45 s, and any tick above 120 s opened on the first sighting). A tick that
-- finds nobody clears the clock rather than pausing it, because the two minutes must be continuous.
local AIRBASE_OCCUPATION_SECONDS = 120

--- Pull the three CTLD airbase-logistics numbers out of veaf.config, falling back to the defaults.
--- Called at the top of initializeAllLogisticInCTLD so the values are in place before any zone is
--- registered, probed or scheduled. `or` is a safe fallback for all three: none is meaningful at 0
--- or false, so an unset key can only mean "use the default".
local function resolveAirbaseLogisticsSettings()
  AIRBASE_LOGISTICS_RADIUS = veaf.config.airbase_logistics_radius or AIRBASE_LOGISTICS_RADIUS_DEFAULT
  AIRBASE_OCCUPATION_RADIUS = veaf.config.airbase_occupation_radius or AIRBASE_OCCUPATION_RADIUS_DEFAULT
  AIRBASE_LOGISTICS_TICK_SECONDS = veaf.config.airbase_logistics_tick or AIRBASE_LOGISTICS_TICK_SECONDS_DEFAULT
end

--- Per-airfield state this lot keeps, keyed by airbase name:
--- `{ zoneName, coalition, class, point, registered, registeredCoalition, active, holder, displayName, dcsAirbase, homeCoalition, leftClassA, occupationCoalition, occupationSince, circle }`.
---
--- `coalition` is the LAST KNOWN holder, the value the class-A tick compares each read against;
--- `homeCoalition` is the one the zone was first registered under and never changes — the tick
--- needs both to tell a field coming home (reactivated, still class A) from one taken by the
--- other side (leaves class A, owes the two minutes). `registeredCoalition` is the coalition the
--- zone is registered under RIGHT NOW (a class-B field captured from the other side is
--- re-registered under its new holder); `active` is whether it is live in CTLD; `holder` is the
--- coalition it currently serves, nil when dark. Together they let a transition never re-issue an
--- activation for a zone already active, and never leave a zone serving a coalition that no longer
--- holds the field. `leftClassA` records the A→B reclassification so the class-B path knows the
--- field already has a (deactivated) zone of its own rather than a fresh neutral one.
---
--- Class B only: `occupationCoalition` and `occupationSince` are the continuous-hold clock —
--- which side's ground units are inside the probe radius, and the mission time (`timer.getTime()`)
--- of the first tick that saw them there uninterrupted, so a tick that finds nobody (or a contest)
--- clears the clock rather than pausing it. `circle` holds
--- the one VeafCircleOnMap per airfield ticket 04 draws, created once and reused.
---
--- `class` is snapshotted on the FIRST evaluation and only the tick moves it, A→B: "A" for a
--- field held by a coalition (blue or red) at mission start, "B" for the rest. Tickets 02 and
--- 03 read that snapshot to follow the field through the mission, and at first evaluation
--- nothing can have been captured yet — on GermanyCW v6, CTLD is ready eleven seconds before
--- the first FOB registers. The snapshot is whatever `getCoalition()` answers at that moment, so a
--- field a mission script hands to a side AFTER it is class B and owes the two minutes of ticket
--- 03; known watch-out, not designed around, and listed in known-limitations.yaml
--- (`airfield-logistics-class-is-decided-when-ctld-starts`).
veafTransportMission.airbaseLogisticState = {}

--- Id of the recurring tick task, nil until `initializeAllLogisticInCTLD` has scheduled it.
--- The guard keeps a second initialisation from stacking a second tick on the first.
veafTransportMission.airbaseLogisticsTaskId = nil

--- Pick the stand the logistic zone is centred on: the real parking stand nearest the centroid
--- of all the stands.
---
--- Not `Airbase:getPoint()` — it sits near the middle of the field, where 250 m covers grass and
--- runway. Not the centroid itself either: an average of parking positions is not a parking
--- position and can land on a taxiway, and DCS exposes no taxiway geometry to check against. A
--- stand from `getParking()` is off the runway and off the taxiways by construction, and the
--- centroid only ever chooses which one.
---
--- @param dcsAirbase DcsAirbase the live handle from veafAirbases
--- @return vec3|nil a copy of the chosen stand's position, nil when the airbase has no usable parking
function veafTransportMission.findAirbaseLogisticsPoint(dcsAirbase)
  local stands = {}
  pcall(function()
    for _, spot in pairs(dcsAirbase:getParking() or {}) do
      local position = spot.vTerminalPos or spot.v_terminal_pos
      if position then
        table.insert(stands, position)
      end
    end
  end)
  if #stands == 0 then
    return nil
  end

  local sumX, sumZ = 0, 0
  for _, position in ipairs(stands) do
    sumX = sumX + position.x
    sumZ = sumZ + position.z
  end
  local centroidX, centroidZ = sumX / #stands, sumZ / #stands

  local nearest, nearestSquareDistance = stands[1], nil
  for _, position in ipairs(stands) do
    local dx, dz = position.x - centroidX, position.z - centroidZ
    local squareDistance = dx * dx + dz * dz
    if nearestSquareDistance == nil or squareDistance < nearestSquareDistance then
      nearest, nearestSquareDistance = position, squareDistance
    end
  end
  return { x = nearest.x, y = nearest.y, z = nearest.z }
end

--- Announce an airfield's logistic transition to one coalition, in its own language.
---
--- Two calls, never one: `outTextForCoalition` takes a single side, and the losing side must not
--- receive the gaining side's wording. The airfield's DISPLAY name is the argument, so the pilot
--- reads which field changed and not our internal `AB_…` zone name.
---
--- @param side number a `coalition.side.*` value; a non-side (neutral, nil) announces nothing
--- @param key string the `transport.airbase_logistics_*` i18n key
--- @param state table the per-airfield state, for its `displayName`
local function announceLogisticTransition(side, key, state)
  if side ~= coalition.side.BLUE and side ~= coalition.side.RED then
    return
  end
  trigger.action.outTextForCoalition(side, veaf.t(key, state.displayName), 10)
end

--- Draw (or redraw) the airfield's green logistic circle, visible to `forCoalition` alone.
---
--- One VeafCircleOnMap per airfield, created once and kept beside its state: `circleToAll`'s first
--- argument is the coalition that can SEE the circle, so redrawing the same object under a new holder
--- is what keeps green meaning "ours" — and `draw()` erases before it redraws, so a change of hands
--- moves the one circle rather than leaving two at the same stand. The fill is the named translucent
--- green, never raw RGBA at the call site; the outline is solid, since `lineType` styles the border
--- and there is no hatch to fake.
local function drawLogisticCircle(state, forCoalition)
  if not state.point then
    return
  end
  if not state.circle then
    state.circle = VeafCircleOnMap:new()
      :setName(state.zoneName)
      :setRadius(AIRBASE_LOGISTICS_RADIUS)
      :setColor("green")
      :setFillColor("green_transparent")
      :setLineType("solid")
  end
  state.circle:setCenter(state.point):setCoalition(forCoalition):draw()
end

--- Erase the airfield's logistic circle, leaving the object beside the state for a later activation
--- to reuse. A second erase re-issues removeMark for an id already gone — harmless to DCS, and the
--- reason the tests assert on the recorded markup rather than on an erase call count.
local function eraseLogisticCircle(state)
  if state.circle then
    state.circle:erase()
  end
end

--- Put an airfield's zone in service for `forCoalition`: make sure it is registered under that
--- coalition — re-registering when it was under another — and active. Answers true when the zone
--- serves `forCoalition` on return, false when it could not (no point, or CTLD refused).
---
--- Shared by both classes. A class-A field coming home is already registered under `forCoalition`,
--- so this only activates it. A class-B field captured from the other side is registered under the
--- other coalition (or not at all), and CTLD binds a zone's coalition at registration, so a change
--- of hands goes through unregister → register — the only way to move a zone between coalitions.
--- That is one WARN at most per real change of hands, never one per tick, which is what the
--- deactivate/activate pair alone cannot do. Announcements are the caller's, not this function's,
--- so exactly one message per side per transition is the caller's to guarantee.
local function serveLogisticZone(state, forCoalition)
  if not state.point then
    return false
  end
  local zoneManager = CTLDZoneManager.getInstance()
  if state.registered and state.registeredCoalition ~= forCoalition then
    zoneManager:unregisterLogistic(state.zoneName)
    state.registered = false
  end
  if not state.registered then
    if not zoneManager:registerFOBAsLogistic(state.zoneName, state.point, AIRBASE_LOGISTICS_RADIUS, forCoalition) then
      return false
    end
    state.registered = true
    state.registeredCoalition = forCoalition
    state.active = true -- a freshly registered zone is born active; no separate activation
  elseif not state.active then
    zoneManager:activateLogisticZone(state.zoneName)
    state.active = true
  end
  state.holder = forCoalition
  drawLogisticCircle(state, forCoalition)
  return true
end

--- Take an airfield's zone out of service: deactivate it, keeping it registered so the same
--- coalition coming back reactivates without re-registering, and clear the holder. Does nothing
--- when it is already dark. Announcements are the caller's.
local function releaseLogisticZone(state)
  if state.active then
    CTLDZoneManager.getInstance():deactivateLogisticZone(state.zoneName)
    state.active = false
  end
  eraseLogisticCircle(state)
  state.holder = nil
end

--- Probe a sphere of `AIRBASE_OCCUPATION_RADIUS` around `point` for GROUND units, and report which
--- coalitions are present. Answers `presence, ok`; when `ok` is false the probe was unusable and
--- the caller must leave the zone exactly as it was.
---
--- `world.searchObjects` is queried for `Object.Category.UNIT` alone, once — never STATIC (a FARP
--- or FOB built in flight near the field is a static, and counting it would let one installation
--- qualify the airfield beside it, or let a maker's own crate hold a zone open) and never SCENERY
--- (scenery has no coalition, so a "held by" test over it is meaningless). The coalition and the
--- ground-unit test happen IN the callback, since searchObjects does not filter on either, and
--- `getCategoryEx()` — not `getCategory()` — is what answers AIRPLANE/GROUND_UNIT: `getCategory()`
--- answers an `Object.Category`, which is the FIX-EVENTHANDLER-UNITCATEGORY trap. A transport that
--- lands here is an AIRPLANE, so it never counts, which is the case a pilot actually hits.
---
--- @param point vec3 the airfield's logistic point
--- @return table|nil presence `{ blue = <bool>, red = <bool> }`, nil when unusable
--- @return boolean ok false when world.searchObjects raised
function veafTransportMission.probeGroundPresence(point)
  local presence = { blue = false, red = false }
  local volume = {
    id = world.VolumeType.SPHERE,
    params = { point = point, radius = AIRBASE_OCCUPATION_RADIUS },
  }
  local function found(object)
    -- An object can cease to exist between DCS handing it over and us asking; a raise on one must
    -- not abort the whole probe, so each object is read under its own pcall (as isSpotOccupied does).
    pcall(function()
      if object and object:isExist() and object:getCategoryEx() == Unit.Category.GROUND_UNIT then
        local objectCoalition = object:getCoalition()
        if objectCoalition == coalition.side.BLUE then
          presence.blue = true
        elseif objectCoalition == coalition.side.RED then
          presence.red = true
        end
      end
    end)
  end
  local ok = pcall(world.searchObjects, Object.Category.UNIT, volume, found)
  if not ok then
    return nil, false
  end
  return presence, true
end

--- Class A: the whole test is `getCoalition()`, no spatial query. Act only on a difference from
--- the last known coalition, so a tick where nothing moved calls nothing and says nothing. A field
--- that returns to the coalition its zone belongs to is served again; one that turns neutral is
--- released and stays class A (a later return reactivates); one taken by the OTHER side is
--- released and leaves class A for B, owing the two minutes. A read that raises leaves the zone.
local function updateClassALogistics(state, logger)
  if not state.registered then
    return -- a class-A field we skipped (no parking, already covered, CTLD refused) has no zone of ours
  end
  local ok, current = pcall(function()
    return state.dcsAirbase:getCoalition()
  end)
  if not ok then
    logger:warn(
      "updateAirbaseLogisticsZones: %s could not be read (%s), leaving %s as it was",
      state.displayName,
      tostring(current),
      state.zoneName
    )
    return
  end
  if current == state.coalition then
    return -- unchanged: no CTLD call, no message, no log line
  end

  local previous = state.coalition
  state.coalition = current

  if current == state.homeCoalition then
    -- Back to the coalition the zone belongs to: serve it again.
    if serveLogisticZone(state, current) then
      announceLogisticTransition(current, "transport.airbase_logistics_gained", state)
      logger:info(
        "updateAirbaseLogisticsZones: %s is back to coalition %s, activated %s",
        state.displayName,
        veaf.p(current),
        state.zoneName
      )
    end
  else
    -- Lost, to neutral or to the other side alike: the zone stops serving the home coalition.
    if state.active then
      releaseLogisticZone(state)
      announceLogisticTransition(previous, "transport.airbase_logistics_lost", state)
      logger:info("updateAirbaseLogisticsZones: %s left coalition %s, deactivated %s", state.displayName, veaf.p(previous), state.zoneName)
    end
    if current == coalition.side.BLUE or current == coalition.side.RED then
      -- Taken by the OTHER side (not neutral): leave class A and re-enter through B, owing the two
      -- continuous minutes like any capture. No "gained" here — the zone is dark for the taker
      -- until ticket 03 actually opens it, and telling it "you can load now" would be a lie the
      -- very next activation contradicts; the taker is announced when the field really opens.
      state.class = "B"
      state.leftClassA = true
      logger:info("updateAirbaseLogisticsZones: %s was taken by coalition %s, reclassified A→B", state.displayName, veaf.p(current))
    end
  end
end

--- Class B: the only class that costs a spatial query. Ground troops of one coalition, unopposed,
--- inside the probe radius for two continuous minutes make the field a logistic point for them; the
--- moment the last of them withdraws or dies it stops being one. Red is mirrored. The holder keeps
--- the zone only while its own troops are still there, so a field does not linger two minutes past
--- a withdrawal. An unusable probe leaves the zone exactly as it was and says so — fail CLOSED,
--- unlike veafGrass.isSpotOccupied, because a logistic point flickering out on a DCS quirk is the
--- symptom this lot exists to remove.
local function updateClassBLogistics(state, logger)
  if not state.point then
    -- A neutral-at-start field was never given a point in 01; compute it on first need. No usable
    -- parking means no zone we can hold or probe here, so the field is simply left alone.
    state.point = veafTransportMission.findAirbaseLogisticsPoint(state.dcsAirbase)
    if not state.point then
      return
    end
  end

  local presence, ok = veafTransportMission.probeGroundPresence(state.point)
  if not ok then
    logger:warn(
      "updateAirbaseLogisticsZones: the occupation probe for %s is unusable, leaving %s as it was",
      state.displayName,
      state.zoneName
    )
    return
  end

  -- 1. The current holder keeps the zone only while its own ground troops are still inside.
  if state.active and state.holder then
    local holderStillThere = (state.holder == coalition.side.BLUE and presence.blue)
      or (state.holder == coalition.side.RED and presence.red)
    if not holderStillThere then
      local previous = state.holder
      releaseLogisticZone(state)
      announceLogisticTransition(previous, "transport.airbase_logistics_lost", state)
      logger:info("updateAirbaseLogisticsZones: the last ground unit left %s, deactivated %s", state.displayName, state.zoneName)
    end
  end

  -- 2. A single unopposed occupier accrues toward the two-minute hold; a contest or an empty field
  --    clears the clock rather than pausing it.
  local occupier = nil
  if presence.blue and not presence.red then
    occupier = coalition.side.BLUE
  elseif presence.red and not presence.blue then
    occupier = coalition.side.RED
  end

  if not occupier then
    state.occupationCoalition = nil
    state.occupationSince = nil
    return
  end

  local now = timer.getTime()
  if state.occupationCoalition ~= occupier then
    state.occupationCoalition = occupier
    state.occupationSince = now
  end

  if now - state.occupationSince >= AIRBASE_OCCUPATION_SECONDS and state.holder ~= occupier then
    local previous = state.holder
    if serveLogisticZone(state, occupier) then
      if previous and previous ~= occupier then
        announceLogisticTransition(previous, "transport.airbase_logistics_lost", state)
      end
      announceLogisticTransition(occupier, "transport.airbase_logistics_gained", state)
      logger:info(
        "updateAirbaseLogisticsZones: %s held by coalition %s for two minutes, activated %s",
        state.displayName,
        veaf.p(occupier),
        state.zoneName
      )
    end
  end
end

--- One 30-second evaluation of every airfield this module keeps state for.
---
--- Class A is decided by `getCoalition()` alone and acts only on a difference, so a tick where
--- nothing moved sends no message, writes no log line and calls no CTLD method — the guard that
--- keeps a captured field from rebuilding every player's Request Equipment menu each half minute.
--- Class B is the only class that runs the ground-unit probe, and only for its own handful of
--- fields, never the whole theatre.
function veafTransportMission.updateAirbaseLogisticsZones()
  local logger = veaf.loggers.get(veafTransportMission.Id)
  for _, state in pairs(veafTransportMission.airbaseLogisticState) do
    if state.class == "A" then
      updateClassALogistics(state, logger)
    elseif state.class == "B" then
      updateClassBLogistics(state, logger)
    end
  end
end

--- Register every airdrome of the theatre as a CTLD logistic zone.
---
--- Called by `veaf.ctld_initialize()` once CTLD has read its configuration; a mission script that
--- still calls it as well finds the state already built and the tick already scheduled.
---
--- Ships are out — carriers already have their route since FEAT-CTLD-AUTO-LOGISTICS — and so are
--- helipads, FARPs going through veafSpawn.spawnLogistic → registerFOBAsLogistic already. Each
--- zone is registered under the airfield's OWN coalition, never 0: CTLD's getLogisticZonesAtPoint
--- serves a coalition-0 zone to both sides. A maker's hand-placed LGZ_ zone covering the chosen
--- stand wins, and nothing is spawned into the simulation to mark ours.
function veafTransportMission.initializeAllLogisticInCTLD()
  local logger = veaf.loggers.get(veafTransportMission.Id)

  -- The maker's opt-out, read before anything else: an explicit false in
  -- modules.CTLD.manage_airbase_logistics means none of this runs — no zone registered, no tick
  -- scheduled, no circle drawn. nil (the key absent) is the default, ON, so the test is `== false`
  -- and not `~= true`. The generator emits a real Lua boolean, never the string "false" (truthy, and
  -- it would silently enable the feature for a maker who typed the word); the validator rejects a
  -- non-boolean in YAML. The line says the feature was ASKED to stay off, which reads nothing like
  -- the "no airfields" summary a maker debugging a mission would otherwise mistake it for.
  if veaf.config.manage_airbase_logistics == false then
    logger:info(
      "initializeAllLogisticInCTLD: airbase logistics was asked to stay off (modules.CTLD.manage_airbase_logistics is false), no airfield will be registered"
    )
    return
  end

  resolveAirbaseLogisticsSettings()

  if not veaf.isCtldReady() then
    -- isCtldReady has already said why, once; this line says what it cost us.
    logger:info("initializeAllLogisticInCTLD: CTLD is not ready, no airfield will be registered as a logistic zone")
    return
  end

  veafAirbases.initialize()

  local zoneManager = CTLDZoneManager.getInstance()
  local registeredCount, skippedCount = 0, 0

  -- A re-initialisation must not leave a circle whose zone is gone: erase every circle this module
  -- drew, then let the loop redraw the ones whose field is still live. draw() erases before it
  -- redraws, so an active field reconciles to exactly one circle and a dark one stays dark.
  for _, state in pairs(veafTransportMission.airbaseLogisticState) do
    eraseLogisticCircle(state)
  end

  for _, airbase in pairs(veafAirbases.Airbases or {}) do
    if airbase.Category == Airbase.Category.AIRDROME and airbase.DcsAirbase then
      if veafTransportMission.airbaseLogisticState[airbase.Name] then
        -- Already evaluated: the class snapshot survives a re-initialisation rather than
        -- reclassifying a field that was captured while nobody was looking. Its circle was erased
        -- with all the others above; redraw it if the zone is still live, so the map matches state.
        local state = veafTransportMission.airbaseLogisticState[airbase.Name]
        if state.active and state.holder then
          drawLogisticCircle(state, state.holder)
        end
        logger:debug("initializeAllLogisticInCTLD: %s was already evaluated, leaving its state alone", airbase.Name)
      else
        -- `airbaseCoalition`, not `coalition`: the local would shadow the global enum table.
        local airbaseCoalition = airbase.DcsAirbase:getCoalition()
        local state = {
          zoneName = "AB_" .. airbase.Name,
          coalition = airbaseCoalition,
          homeCoalition = airbaseCoalition,
          class = (airbaseCoalition == coalition.side.BLUE or airbaseCoalition == coalition.side.RED) and "A" or "B",
          point = nil,
          registered = false,
          registeredCoalition = nil,
          active = false,
          holder = nil,
          displayName = airbase.DisplayName or airbase.Name,
          dcsAirbase = airbase.DcsAirbase,
          leftClassA = false,
          occupationCoalition = nil,
          occupationSince = nil,
          circle = nil,
        }
        veafTransportMission.airbaseLogisticState[airbase.Name] = state

        if state.class == "B" then
          -- Neutral at mission start: there is no coalition to register the zone for, and a
          -- coalition-0 zone would serve both sides. Ticket 03 registers the field once ground
          -- troops have held it for two continuous minutes, and computes its point on first need.
          logger:debug("initializeAllLogisticInCTLD: %s is neutral, class B — it will become a logistic zone when captured", airbase.Name)
        else
          local point = veafTransportMission.findAirbaseLogisticsPoint(airbase.DcsAirbase)
          if not point then
            skippedCount = skippedCount + 1
            logger:warn(
              "initializeAllLogisticInCTLD: %s has no usable parking data, skipped — a zone on the reference point could sit on the runway",
              airbase.Name
            )
          else
            state.point = point
            local coveringZones = zoneManager:getLogisticZonesAtPoint(point, airbaseCoalition)
            if coveringZones and #coveringZones > 0 then
              skippedCount = skippedCount + 1
              logger:debug(
                "initializeAllLogisticInCTLD: %s (class %s) already has a logistic zone covering its stand, leaving that one in charge",
                airbase.Name,
                state.class
              )
            elseif zoneManager:registerFOBAsLogistic(state.zoneName, point, AIRBASE_LOGISTICS_RADIUS, airbaseCoalition) then
              registeredCount = registeredCount + 1
              state.registered = true
              state.registeredCoalition = airbaseCoalition
              state.active = true
              state.holder = airbaseCoalition
              drawLogisticCircle(state, airbaseCoalition)
              logger:debug(
                "initializeAllLogisticInCTLD: registered %s (class %s) at stand %s, r=%dm",
                state.zoneName,
                state.class,
                veaf.vecToString(point),
                AIRBASE_LOGISTICS_RADIUS
              )
            else
              -- CTLD WARNs on its side, but its line does not say who asked.
              skippedCount = skippedCount + 1
              logger:warn(
                "initializeAllLogisticInCTLD: CTLD refused to register %s for %s — a logistic zone with that name already exists",
                state.zoneName,
                airbase.Name
              )
            end
          end
        end
      end
    end
  end

  logger:info("initializeAllLogisticInCTLD: %d airdrome(s) registered as CTLD logistic zones, %d skipped", registeredCount, skippedCount)

  -- One recurring tick holds every class-A field through the mission. The interval comes from the
  -- module setting, never written into the loop; the guard keeps a re-initialisation from stacking
  -- a second tick on the one already running.
  if not veafTransportMission.airbaseLogisticsTaskId then
    veafTransportMission.airbaseLogisticsTaskId = veaf.scheduleFunction(
      veafTransportMission.updateAirbaseLogisticsZones,
      {},
      timer.getTime() + AIRBASE_LOGISTICS_TICK_SECONDS,
      AIRBASE_LOGISTICS_TICK_SECONDS
    )
    logger:debug("initializeAllLogisticInCTLD: airbase logistics tick scheduled every %ss", veaf.p(AIRBASE_LOGISTICS_TICK_SECONDS))
  end
end
-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- initialisation
-------------------------------------------------------------------------------------------------------------------------------------------------------------

function veafTransportMission.initialize()
  veafTransportMission.buildRadioMenu()
  veafMarkers.registerEventHandler(veafMarkers.MarkerChange, veafTransportMission.onEventMarkChange)
end

veaf.loggers.get(veafTransportMission.Id):info(veaf.loggers.get(veafTransportMission.Id):getVersionInfo())

--- Enable/Disable error boxes displayed on screen.
env.setErrorMessageBoxEnabled(false)

veaf.registerModule(veafTransportMission.Id, veafTransportMission.initialize, { enable = true }, 120)
